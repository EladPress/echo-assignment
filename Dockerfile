FROM debian:bookworm-slim as fixer 

WORKDIR /tmp

RUN echo "deb-src http://deb.debian.org/debian bookworm main" >> /etc/apt/sources.list
RUN echo "deb-src http://security.debian.org bookworm-security main" >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y dpkg-dev devscripts

RUN apt-get source libfreetype6=2.12.1+dfsg-5+deb12u4
WORKDIR /tmp/freetype-2.12.1+dfsg
RUN apt-get build-dep libfreetype6 -y
RUN dpkg-buildpackage -us -uc -b

WORKDIR /tmp

# RUN dget -u https://snapshot.debian.org/archive/debian/20221027T213940Z/pool/main/e/expat/expat_2.5.0-1.dsc
# WORKDIR /tmp/expat-2.5.0
# RUN apt-get build-dep libexpat1 -y
# RUN dpkg-buildpackage -us -uc -b
###########################################
FROM debian:bookworm-slim as expat-patch

RUN apt-get update
RUN apt-get install -y dpkg-dev devscripts

WORKDIR /tmp/old
RUN dget -u https://snapshot.debian.org/archive/debian/20221027T213940Z/pool/main/e/expat/expat_2.5.0-1.dsc

WORKDIR /tmp/new
RUN echo "deb-src http://deb.debian.org/debian bookworm main" >> /etc/apt/sources.list
RUN apt-get update
## apt-get has the patched version (2.5.0-1+deb12u2), so we can just get the source.
RUN apt-get source libexpat1=2.5.0

WORKDIR /tmp
RUN cp new/expat-2.5.0/debian/patches/CVE-2024-45491.patch old/expat-2.5.0/debian/patches/
RUN echo "CVE-2024-45491.patch" >> old/expat-2.5.0/debian/patches/series
WORKDIR /tmp/old/expat-2.5.0
RUN patch -p1 < debian/patches/CVE-2024-45491.patch
RUN apt build-dep -y expat
RUN dpkg-buildpackage -us -uc
## Result: a libexpat1_2.5.0-1_arm64.deb file in /old

##########################################
FROM nginx:1.25-bookworm as nginx


##########################################
FROM debian:bookworm-slim as post

RUN apt-get update

COPY --from=fixer /tmp/libfreetype6_2.12.1+dfsg-5+deb12u4_arm64.deb /tmp
COPY --from=expat-patch /tmp/old/expat_2.5.0-1_arm64.deb /tmp
COPY --from=expat-patch /tmp/old/libexpat1_2.5.0-1_arm64.deb /tmp
RUN dpkg -i /tmp/libfreetype6_2.12.1+dfsg-5+deb12u4_arm64.deb || true
RUN dpkg -i /tmp/expat_2.5.0-1_arm64.deb || true
RUN dpkg -i /tmp/libexpat1_2.5.0-1_arm64.deb || true

RUN apt --fix-broken  -y install
RUN apt-get install -y nginx ##|| true && apt-get install -f -y
RUN groupadd --system --gid 101 nginx \
    && useradd --system --gid nginx --no-create-home --home /nonexistent --comment "nginx user" --shell /bin/false --uid 101 nginx \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY --from=nginx /docker-entrypoint.sh /docker-entrypoint.sh
COPY --from=nginx /docker-entrypoint.d/ /docker-entrypoint.d/
COPY --from=nginx /etc/nginx/conf.d/ /etc/nginx/conf.d/
COPY --from=nginx /etc/nginx/nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

# COPY --chmod=777 nginx-image/ /
ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]
# RUN apt-get install -f -y


FROM debian:bookworm-slim as libfreetype6-patch 

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
FROM debian:bookworm-slim as final

LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"

ENV PKG_RELEASE=1~bookworm
ENV NJS_RELEASE=3~bookworm
ENV NJS_VERSION=0.8.4
ENV NGINX_VERSION=1.25.5

RUN apt-get update

COPY --from=libfreetype6-patch /tmp/libfreetype6_2.12.1+dfsg-5+deb12u4_arm64.deb /tmp
COPY --from=expat-patch /tmp/old/expat_2.5.0-1_arm64.deb /tmp
COPY --from=expat-patch /tmp/old/libexpat1_2.5.0-1_arm64.deb /tmp
RUN dpkg -i /tmp/libfreetype6_2.12.1+dfsg-5+deb12u4_arm64.deb || true
RUN dpkg -i /tmp/expat_2.5.0-1_arm64.deb || true
RUN dpkg -i /tmp/libexpat1_2.5.0-1_arm64.deb || true

RUN apt --fix-broken  -y install

RUN apt-get update && \
    apt-get install -y curl gnupg2 ca-certificates lsb-release debian-archive-keyring

RUN curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | tee /usr/share/keyrings/nginx-archive-keyring.gpg > /dev/null

RUN echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    http://nginx.org/packages/mainline/debian $(lsb_release -cs) nginx" \
    | tee /etc/apt/sources.list.d/nginx.list

RUN printf 'Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n' \
    | tee /etc/apt/preferences.d/99nginx

RUN apt-get update && \
    apt-get install -y nginx=1.25.5-1~$(lsb_release -cs)

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY --from=nginx /docker-entrypoint.sh /docker-entrypoint.sh
COPY --from=nginx /docker-entrypoint.d/ /docker-entrypoint.d/
COPY --from=nginx /etc/nginx/conf.d/ /etc/nginx/conf.d/
COPY --from=nginx /etc/nginx/nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
STOPSIGNAL SIGQUIT
CMD ["nginx", "-g", "daemon off;"]
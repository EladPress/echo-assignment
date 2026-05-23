## This dockerfile creates our .debs
FROM debian:bookworm-slim AS libfreetype6-patch 

WORKDIR /tmp

RUN echo "deb-src http://deb.debian.org/debian bookworm main" >> /etc/apt/sources.list
RUN echo "deb-src http://security.debian.org bookworm-security main" >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y dpkg-dev devscripts

RUN apt-get source libfreetype6=2.12.1+dfsg-5+deb12u4
WORKDIR /tmp/freetype-2.12.1+dfsg
RUN apt-get build-dep libfreetype6 -y
RUN dpkg-buildpackage -us -uc -b

###########################################
FROM debian:bookworm-slim AS expat-patch

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
## Result: a libexpat1_2.5.0-1_*.deb file in /old

FROM debian:bookworm-slim AS collect-debs

WORKDIR /debs
COPY --from=libfreetype6-patch /tmp/libfreetype6_*.deb ./
COPY --from=expat-patch /tmp/old/libexpat1_*.deb ./
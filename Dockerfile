FROM acgrid/multi-stage-builder AS builder

ARG PCRE_VERSION=8.43
ARG LIBRESSL_VERSION=2.8.3
ARG NPS_VERSION=1.13.35.2
ARG NGINX_VERSION=1.15.12
ARG WITH_PAGESPEED=true

RUN yum install -y zlib-devel GeoIP-devel libuuid-devel

COPY build.sh ./
RUN bash build.sh

FROM centos
MAINTAINER acgrid

ARG TZ
ENV TZ ${TZ:-Asia/Shanghai}
ENV TERM=linux

ENV NGINX_USER=nginx \
    NGINX_SITECONF_DIR=/etc/nginx/conf.d \
    NGINX_LOG_DIR=/var/log/nginx \
    NGINX_TEMP_DIR=/var/lib/nginx

COPY --from=builder /var/lib/builder/rootfs /

RUN groupadd -r nginx && useradd -r -m -d /var/cache/nginx -s /sbin/nologin -g nginx nginx && mkdir /etc/nginx/conf.d && ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log
RUN yum update -y && yum install -y vim bzip2 GeoIP && yum clean all && rm -rf /var/cache/yum

WORKDIR /etc/nginx
COPY nginx.conf .
COPY default.conf ./conf.d/default.conf

STOPSIGNAL SIGTERM
CMD ["nginx", "-g", "daemon off;"]

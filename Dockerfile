FROM centos AS builder

ARG PCRE_VERSION=8.42
ARG LIBRESSL_VERSION=2.8.1
ARG NPS_VERSION=1.13.35.2
ARG NGINX_VERSION=1.15.4
ARG WITH_PAGESPEED=true

ENV NGINX_BUILD_ASSETS_DIR=/var/lib/docker-nginx \
    NGINX_BUILD_ROOT_DIR=/var/lib/docker-nginx/rootfs

RUN yum update -y
RUN yum install -y gcc gcc-c++ make automake autoconf wget tar bzip2 libtool zlib-devel GeoIP-devel libuuid-devel

COPY build.sh ${NGINX_BUILD_ASSETS_DIR}/
RUN chmod +x ${NGINX_BUILD_ASSETS_DIR}/build.sh
RUN ${NGINX_BUILD_ASSETS_DIR}/build.sh

FROM centos
MAINTAINER acgrid

ARG TZ
ENV TZ ${TZ:-Asia/Shanghai}
ENV TERM=linux

ENV NGINX_USER=nginx \
    NGINX_SITECONF_DIR=/etc/nginx/conf.d \
    NGINX_LOG_DIR=/var/log/nginx \
    NGINX_TEMP_DIR=/var/lib/nginx

COPY --from=builder /var/lib/docker-nginx/rootfs /

RUN groupadd -r nginx && useradd -r -m -d /var/cache/nginx -s /sbin/nologin -g nginx nginx && mkdir /etc/nginx/conf.d && ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log
RUN yum update -y && yum install -y vim bzip2 GeoIP && yum clean all && rm -rf /var/cache/yum

COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

STOPSIGNAL SIGTERM
CMD ["nginx", "-g", "daemon off;"]
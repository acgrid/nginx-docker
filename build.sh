#!/bin/bash
source /etc/profile.d/build-env.sh
BUILD_ASSETS_DIR=${BUILD_ASSETS_DIR}
BUILD_ROOT_DIR=${BUILD_ROOT_DIR}
BUILD_PREFIX_DIR=${BUILD_PREFIX_DIR}

NPS_VERSION=${NPS_VERSION}
PCRE_VERSION=${PCRE_VERSION}
LIBRESSL_VERSION=${LIBRESSL_VERSION}
NGINX_VERSION=${NGINX_VERSION}
WITH_PAGESPEED=${WITH_PAGESPEED}

set -e

cd ${BUILD_ASSETS_DIR}

${WITH_PAGESPEED} && {
  download_and_extract "https://github.com/apache/incubator-pagespeed-ngx/archive/v${NPS_VERSION}-stable.tar.gz" ngx_pagespeed
  download_and_extract "https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}-x64.tar.gz" ngx_pagespeed/psol
  EXTRA_ARGS+=" --add-module=${BUILD_ASSETS_DIR}/ngx_pagespeed"
}

download_and_extract "http://iweb.dl.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.bz2" pcre
download_and_extract http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz libressl

download_and_extract "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" nginx
cd nginx

./configure \
    --user=nginx \
    --group=nginx \
    --prefix=/usr \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/lock/nginx.lock \
    --with-pcre=${BUILD_ASSETS_DIR}/pcre \
    --with-openssl=${BUILD_ASSETS_DIR}/libressl \
    --with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_sub_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
    --with-http_geoip_module \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --with-pcre-jit \
    --with-cc-opt='-O2 -fstack-protector-strong -Wformat -Werror=format-security -fPIC -D_FORTIFY_SOURCE=2' \
    --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -fPIC' \
    ${EXTRA_ARGS}

make -j$(nproc) && make DESTDIR=${BUILD_ROOT_DIR} install

set +e

strip_debug "${BUILD_PREFIX_DIR}/bin/" "*"
strip_debug "${BUILD_PREFIX_DIR}/sbin/" "*"
strip_debug "${BUILD_PREFIX_DIR}/lib/" "*.so"
strip_debug "${BUILD_PREFIX_DIR}/lib/" "*.so.*"

rm -rf ${BUILD_PREFIX_DIR}/share/man
rm -rf ${BUILD_PREFIX_DIR}/share/include
rm -rf ${BUILD_PREFIX_DIR}/lib/pkgconfig
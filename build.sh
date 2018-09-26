#!/bin/bash
set -e

install_packages() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

download_and_extract() {
  src=${1}
  dest=${2}
  tarball=$(basename ${src})

  if [[ ! -f ${NGINX_BUILD_ASSETS_DIR}/${tarball} ]]; then
    echo "Downloading ${1}..."
    wget ${src} -O ${NGINX_BUILD_ASSETS_DIR}/${tarball}
  fi

  echo "Extracting ${tarball}..."
  mkdir ${dest}
  tar xf ${NGINX_BUILD_ASSETS_DIR}/${tarball} --strip=1 -C ${dest}
}

strip_debug() {
  local dir=${1}
  local filter=${2}
  for f in $(find "${dir}" -name "${filter}")
  do
    if [[ -f ${f} ]]; then
      strip --strip-all ${f}
    fi
  done
}

${WITH_PAGESPEED} && {
  download_and_extract "https://github.com/apache/incubator-pagespeed-ngx/archive/v${NPS_VERSION}-stable.tar.gz" ${NGINX_BUILD_ASSETS_DIR}/ngx_pagespeed
  download_and_extract "https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}-x64.tar.gz" ${NGINX_BUILD_ASSETS_DIR}/ngx_pagespeed/psol
  EXTRA_ARGS+=" --add-module=${NGINX_BUILD_ASSETS_DIR}/ngx_pagespeed"
}

download_and_extract "http://iweb.dl.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.bz2" ${NGINX_BUILD_ASSETS_DIR}/pcre
download_and_extract http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz ${NGINX_BUILD_ASSETS_DIR}/libressl

download_and_extract "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" ${NGINX_BUILD_ASSETS_DIR}/nginx
cd ${NGINX_BUILD_ASSETS_DIR}/nginx

./configure \
    --user=nginx \
    --group=nginx \
    --prefix=/usr \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/lock/nginx.lock \
    --with-pcre=${NGINX_BUILD_ASSETS_DIR}/pcre \
    --with-openssl=${NGINX_BUILD_ASSETS_DIR}/libressl \
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

make -j$(nproc)
make DESTDIR=${NGINX_BUILD_ROOT_DIR} install

strip_debug "${NGINX_BUILD_ROOT_DIR}/usr/bin/" "*"
strip_debug "${NGINX_BUILD_ROOT_DIR}/usr/sbin/" "*"
strip_debug "${NGINX_BUILD_ROOT_DIR}/usr/lib/" "*.so"
strip_debug "${NGINX_BUILD_ROOT_DIR}/usr/lib/" "*.so.*"

rm -rf ${NGINX_BUILD_ROOT_DIR}/usr/share/man
rm -rf ${NGINX_BUILD_ROOT_DIR}/usr/share/include
rm -rf ${NGINX_BUILD_ROOT_DIR}/usr/lib/pkgconfig
#!/bin/bash
echo "Cleaning Build-cURL-nghttp2-quiche-android"
rm -fr openssl/openssl nghttp2/nghttp2-1* quiche/{quiche,quiche-build} curl/curl-7* \
       {nghttp2,curl}/{arm,arm64,x86,x86_64} \
       /tmp/openssl-* /tmp/nghttp2-* /tmp/curl-* all

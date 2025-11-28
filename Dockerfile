FROM alpine:3.19 AS build

WORKDIR /src

# Install build dependencies
RUN apk add --no-cache make gcc musl-dev linux-headers wget perl zlib-static upx

# Download and build minimal OpenSSL 3.3 (latest stable)
# Only enable crypto features needed by MTProxy, disable everything else
RUN wget https://www.openssl.org/source/openssl-3.3.2.tar.gz && \
    tar -xzf openssl-3.3.2.tar.gz && \
    cd openssl-3.3.2 && \
    ./Configure linux-generic64 \
        -O3 -flto -ffunction-sections -fdata-sections \
        no-shared \
        no-module \
        no-ssl no-tls no-dtls \
        no-ssl3 no-ssl3-method \
        no-tls1 no-tls1-method no-tls1_1 no-tls1_1-method no-tls1_2 no-tls1_2-method no-tls1_3 \
        no-dtls1 no-dtls1-method no-dtls1_2 no-dtls1_2-method \
        no-psk no-srp no-gost no-cms no-ts no-ocsp no-ct no-sm2 no-sm3 no-sm4 \
        no-ec no-ec2m no-ecdh no-ecdsa \
        no-camellia no-seed no-aria no-idea no-mdc2 no-rc2 no-rc4 no-rc5 no-bf no-cast no-des \
        no-blake2 no-siphash no-whirlpool \
        no-chacha no-poly1305 \
        no-ocb no-siv \
        no-dsa no-dh no-cmac \
        no-md2 no-md4 no-rmd160 \
        no-cmp \
        no-engine no-async no-deprecated no-comp \
        no-ktls no-padlockeng no-devcryptoeng no-afalgeng \
        no-dso no-apps no-autoload-config \
        no-sock no-dgram no-sctp no-nextprotoneg no-rfc3779 \
        no-uplink no-weak-ssl-ciphers no-legacy \
        no-http no-srtp no-quic \
        no-autoalginit no-autoerrinit no-cached-fetch \
        no-bulk no-multiblock no-static-engine \
        no-ui-console no-filenames no-atexit \
        no-argon2 no-scrypt \
        no-rdrand no-sse2 no-ssl-trace \
        no-pinshared no-thread-pool no-default-thread-pool \
        no-tests no-docs no-fips no-external-tests no-unit-test no-buildtest-c++ no-makedepend \
        --prefix=/usr/local/openssl-static && \
    make -j$(nproc) && \
    make install_sw && \
    cd .. && rm -rf openssl-3.3.2*

# Copy source code
COPY . .

# Build MTProxy with minimal OpenSSL and strip debug symbols
RUN make -j$(nproc) && \
    strip --strip-all objs/bin/mtproto-proxy && \
    upx --lzma objs/bin/mtproto-proxy

# Verify binary
RUN test -f /src/objs/bin/mtproto-proxy && \
    chmod +x /src/objs/bin/mtproto-proxy && \
    ls -lh /src/objs/bin/mtproto-proxy

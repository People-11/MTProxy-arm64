FROM alpine:3.24 AS build

RUN apk add --no-cache gcc make musl-dev linux-headers perl upx

# Minimal static OpenSSL: MTProxy only needs EVP (AES-256-CBC/CTR, SHA1/SHA256, HMAC), BN and RAND.
# linux-aarch64 keeps the ARMv8 Crypto Extensions assembly (hardware AES/SHA, constant-time).
ARG OPENSSL_VERSION=3.5.9
ARG OPENSSL_SHA256=603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a
WORKDIR /openssl
RUN wget -q https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz && \
    echo "${OPENSSL_SHA256}  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c - && \
    tar -xzf openssl-${OPENSSL_VERSION}.tar.gz --strip-components=1 && \
    ./Configure linux-aarch64 --prefix=/usr/local --libdir=lib \
        -O3 -ffunction-sections -fdata-sections -fno-asynchronous-unwind-tables -fno-unwind-tables \
        no-shared no-module no-dso no-engine no-static-engine no-apps no-tests no-docs no-fips \
        no-ssl no-tls no-dtls no-ssl3 no-tls1 no-tls1_1 no-tls1_2 no-tls1_3 no-dtls1 no-dtls1_2 \
        no-sock no-dgram no-sctp no-ktls no-quic no-http no-srtp no-nextprotoneg no-psk no-srp no-ssl-trace \
        no-ec no-ec2m no-ecdh no-ecdsa no-ecx no-dh no-dsa no-sm2 no-sm2-precomp no-sm3 no-sm4 no-gost \
        no-ml-kem no-ml-dsa no-slh-dsa \
        no-camellia no-seed no-aria no-idea no-mdc2 no-rc2 no-rc4 no-rc5 no-bf no-cast no-des \
        no-chacha no-poly1305 no-blake2 no-siphash no-whirlpool no-md2 no-md4 no-rmd160 \
        no-ocb no-siv no-cmac no-scrypt no-argon2 \
        no-cms no-ts no-ocsp no-ct no-cmp no-rfc3779 \
        no-async no-comp no-deprecated no-legacy no-weak-ssl-ciphers no-uplink \
        no-padlockeng no-devcryptoeng no-afalgeng no-multiblock no-bulk \
        no-autoload-config no-autoalginit no-autoerrinit no-ui-console no-filenames no-atexit \
        no-pinshared no-thread-pool no-default-thread-pool no-err no-stdio no-secure-memory && \
    make -j$(nproc) build_libs && \
    make install_dev && \
    cd / && rm -rf /openssl

WORKDIR /src
COPY . .
ARG COMMIT=unknown
RUN make -j$(nproc) COMMIT=${COMMIT} && \
    size objs/bin/mtproto-proxy && ls -l objs/bin/mtproto-proxy && \
    upx --ultra-brute objs/bin/mtproto-proxy && \
    ls -l objs/bin/mtproto-proxy

FROM scratch
COPY --from=build /src/objs/bin/mtproto-proxy /mtproto-proxy
ENTRYPOINT ["/mtproto-proxy"]

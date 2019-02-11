#include "api.h"
#include "randombytes.h"
#include <stdio.h>
#include <string.h>

#define NTESTS 15
#define MLEN 32

const unsigned char canary[8] = {0x01, 0x23, 0x45, 0x67,
                                 0x89, 0xAB, 0xCD, 0xEF};

/* allocate a bit more for all keys and messages and
 * make sure it is not touched by the implementations.
 */
static void write_canary(unsigned char *d) {
    for (int i = 0; i < 8; i++) {
        d[i] = canary[i];
    }
}

static int check_canary(const unsigned char *d) {
    for (int i = 0; i < 8; i++) {
        if (d[i] != canary[i])
            return -1;
    }
    return 0;
}

// https://stackoverflow.com/a/1489985/1711232
#define PASTER(x, y) x##_##y
#define EVALUATOR(x, y) PASTER(x, y)
#define NAMESPACE(fun) EVALUATOR(PQCLEAN_NAMESPACE, fun)

#define crypto_sign_keypair NAMESPACE(crypto_sign_keypair)
#define crypto_sign NAMESPACE(crypto_sign)
#define crypto_sign_open NAMESPACE(crypto_sign_open)

#define RETURNS_ZERO(f) \
    if ((f) != 0) { \
        puts("(f) returned non-zero returncode"); \
        return -1; \
    }


static int test_sign(void) {
    unsigned char pk[CRYPTO_PUBLICKEYBYTES + 16];
    unsigned char sk[CRYPTO_SECRETKEYBYTES + 16];
    unsigned char sm[MLEN + CRYPTO_BYTES + 16];
    unsigned char m[MLEN + 16];

    unsigned long long mlen;
    unsigned long long smlen;
    int returncode;

    int i;
    write_canary(pk);
    write_canary(pk + sizeof(pk) - 8);
    write_canary(sk);
    write_canary(sk + sizeof(sk) - 8);
    write_canary(sm);
    write_canary(sm + sizeof(sm) - 8);
    write_canary(m);
    write_canary(m + sizeof(m) - 8);

    for (i = 0; i < NTESTS; i++) {
        RETURNS_ZERO(crypto_sign_keypair(pk + 8, sk + 8));

        randombytes(m + 8, MLEN);
        RETURNS_ZERO(crypto_sign(sm + 8, &smlen, m + 8, MLEN, sk + 8));

        // By relying on m == sm we prevent having to allocate CRYPTO_BYTES
        // twice
        if ((returncode = crypto_sign_open(sm + 8, &mlen, sm + 8, smlen, pk + 8)) != 0) {
            printf("ERROR Signature did not verify correctly!\n");
            if (returncode > 0) {
                puts("ERROR return code should be < 0 on failure");
            }
            return 1;
        }
        if (check_canary(pk) || check_canary(pk + sizeof(pk) - 8) ||
            check_canary(sk) || check_canary(sk + sizeof(sk) - 8) ||
            check_canary(sm) || check_canary(sm + sizeof(sm) - 8) ||
            check_canary(m) || check_canary(m + sizeof(m) - 8)) {
            printf("ERROR canary overwritten\n");
            return 1;
        }
    }

    return 0;
}

static int test_wrong_pk(void) {
    unsigned char pk[CRYPTO_PUBLICKEYBYTES];
    unsigned char pk2[CRYPTO_PUBLICKEYBYTES];
    unsigned char sk[CRYPTO_SECRETKEYBYTES];
    unsigned char sm[MLEN + CRYPTO_BYTES];
    unsigned char m[MLEN];

    unsigned long long mlen;
    unsigned long long smlen;

    int returncode;

    int i;

    for (i = 0; i < NTESTS; i++) {
        RETURNS_ZERO(crypto_sign_keypair(pk2, sk));

        RETURNS_ZERO(crypto_sign_keypair(pk, sk));

        randombytes(m, MLEN);
        RETURNS_ZERO(crypto_sign(sm, &smlen, m, MLEN, sk));

        // By relying on m == sm we prevent having to allocate CRYPTO_BYTES
        // twice
        if (!(returncode = crypto_sign_open(sm, &mlen, sm, smlen, pk2))) {
            printf("ERROR Signature did verify correctly under wrong public "
                   "key!\n");
            if (returncode > 0) {
                puts("ERROR return code should be < 0");
            }
            return 1;
        }
    }

    return 0;
}

int main(void) {
    int result = 0;
    result += test_sign();
    result += test_wrong_pk();

    return result;
}

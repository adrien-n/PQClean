#ifndef PQCLEAN_KYBER1024_AVX2_VERIFY_H
#define PQCLEAN_KYBER1024_AVX2_VERIFY_H
#include "params.h"
#include <stddef.h>
#include <stdint.h>

int PQCLEAN_KYBER1024_AVX2_verify(const uint8_t *a, const uint8_t *b, size_t len);

void PQCLEAN_KYBER1024_AVX2_cmov(uint8_t *r, const uint8_t *x, size_t len, uint8_t b);

void PQCLEAN_KYBER1024_AVX2_cmov_int16(int16_t *r, int16_t v, uint16_t b);

#endif

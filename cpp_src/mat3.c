// Clean-room 3x3 matrix operations.
// These are standard linear algebra primitives implemented from their
// mathematical definitions — no external library code was referenced.

#include "mat3.h"
#include <math.h>

// rp = r * p  (3x3 matrix times 3-vector)
// From the definition: rp[i] = sum_j r[i][j] * p[j]
// Supports aliasing (p and rp may point to the same array).
//
// Uses explicit fma() calls to guarantee fused multiply-add on all
// platforms. This matches numpy's vectorized multiply behavior and
// is required for bit-exact Skyfield parity.
void mat3_vec3_mul(const double r[3][3], const double p[3], double rp[3]) {
    double tmp[3];
    for (int i = 0; i < 3; i++) {
        double sum = r[i][0] * p[0];
        sum = fma(r[i][1], p[1], sum);
        sum = fma(r[i][2], p[2], sum);
        tmp[i] = sum;
    }
    rp[0] = tmp[0];
    rp[1] = tmp[1];
    rp[2] = tmp[2];
}

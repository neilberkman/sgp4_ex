#ifndef MAT3_H
#define MAT3_H

#ifdef __cplusplus
extern "C" {
#endif

void mat3_vec3_mul(const double r[3][3], const double p[3], double rp[3]);

#ifdef __cplusplus
}
#endif

#endif

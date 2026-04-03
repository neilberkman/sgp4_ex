// SGP4 propagation and TEME→GCRS coordinate transformation NIF.
// Uses sgp4init for orbit propagation and a native Skyfield-compatible
// pipeline for the inertial frame rotation.
//
// Disable FMA contractions for the entire file so that floating-point
// rounding matches Python/Skyfield (clang-compiled numpy, no FMA).
#pragma GCC optimize("fp-contract=off")

#include <erl_nif.h>
#include <cmath>
#include <cstdio>
#include <clocale>
#include "SGP4.h"
#include "precise_time.h"
#include "iau2000a_nutation_data.hpp"

extern "C" {
#include "mat3.h"
}

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace {

constexpr double TAU = 2.0 * M_PI;
constexpr double DAY_S = 86400.0;
constexpr double AU_KM = 149597870.700;
constexpr double T0 = 2451545.0;
constexpr double ASEC2RAD = 4.848136811095359935899141e-6;
constexpr double ASEC360 = 1296000.0;
constexpr double TENTH_USEC_2_RAD = ASEC2RAD / 1.0e7;

double positive_fmod(double value, double modulus) {
    double result = fmod(value, modulus);
    if (result < 0.0) {
        result += modulus;
    }
    return result;
}

double earth_rotation_angle(double jd_whole, double ut1_fraction) {
    const double days_since_j2000 = jd_whole - T0 + ut1_fraction;
    // Keep the multiply and add as separate rounded double operations so the
    // result matches Skyfield/Python's float evaluation path.
    volatile double spins_since_j2000 = 0.00273781191135448 * days_since_j2000;
    const double th = 0.7790572732640 + spins_since_j2000;
    double result = fmod(fmod(th, 1.0) + fmod(jd_whole, 1.0) + ut1_fraction, 1.0);
    if (result < 0.0) {
        result += 1.0;
    }
    return result;
}

double compute_theta_gmst1982(double jd_whole, double ut1_fraction) {
    const double t = (jd_whole - T0 + ut1_fraction) / 36525.0;
    const double g = 67310.54841 + (8640184.812866 + (0.093104 + (-6.2e-6) * t) * t) * t;
    double theta = fmod(fmod(jd_whole, 1.0) + ut1_fraction + fmod(g / DAY_S, 1.0), 1.0) * TAU;
    if (theta < 0.0) {
        theta += TAU;
    }
    return theta;
}

double skyfield_mean_obliquity_radians(double jd_tdb) {
    const double t = (jd_tdb - T0) / 36525.0;
    const double epsilon =
        (((( -  0.0000000434   * t
             -  0.000000576  ) * t
             +  0.00200340   ) * t
             -  0.0001831    ) * t
             - 46.836769     ) * t + 84381.406;
    return epsilon * ASEC2RAD;
}

double skyfield_sidereal_time_hours(double jd_whole, double ut1_fraction, double tdb_fraction) {
    const double theta = earth_rotation_angle(jd_whole, ut1_fraction);
    const double t = (jd_whole - T0 + tdb_fraction) / 36525.0;
    const double st =
               ( 0.014506 +
        (((( -    0.0000000368   * t
             -    0.000029956  ) * t
             -    0.00000044   ) * t
             +    1.3915817    ) * t
             + 4612.156534     ) * t);
    double result = fmod(st / 54000.0 + theta * 24.0, 24.0);
    if (result < 0.0) {
        result += 24.0;
    }
    return result;
}

double skyfield_equation_of_the_equinoxes_complimentary_terms(double jd_tt) {
    static const int ke1[14] = {0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    static const int ke0_t[33][14] = {
        {0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 2, -2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 2, -2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 2, -2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 2, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {1, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 1, 2, -2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 1, 2, -2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 4, -4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 1, -1, 1, 0, -8, 12, 0, 0, 0, 0, 0, 0},
        {0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {1, 0, 2, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {1, 0, 2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 2, -2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 1, -2, 2, -3, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 1, -2, 2, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 8, -13, 0, 0, 0, 0, 0, -1},
        {0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {2, 0, -2, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {1, 0, 0, -2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 1, 2, -2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {1, 0, 0, -2, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 4, -2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 2, -2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {1, 0, -2, 0, -3, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {1, 0, -2, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    };
    static const double se0_t_0[33] = {
        0.00264096, 0.00006352, 0.00001175, 0.00001121, -0.00000455, 0.00000202,
        0.00000198, -0.00000172, -0.00000141, -0.00000126, -0.00000063, -0.00000063,
        0.00000046, 0.00000045, 0.00000036, -0.00000024, 0.00000032, 0.00000028,
        0.00000027, 0.00000026, -0.00000021, 0.00000019, 0.00000018, -0.00000010,
        0.00000015, -0.00000014, 0.00000014, -0.00000014, 0.00000014, 0.00000013,
        -0.00000011, 0.00000011, 0.00000011,
    };
    static const double se0_t_1[33] = {
        -0.00000039, -0.00000002, 0.00000001, 0.00000001, 0.0, 0.0,
        0.0, 0.0, -0.00000001, -0.00000001, 0.0, 0.0,
        0.0, 0.0, 0.0, -0.00000012, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.00000005,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
    };
    static constexpr double se1_0 = -0.00000087;

    const double t = (jd_tt - T0) / 36525.0;
    double fa[14];

    fa[0] = ((485868.249036 +
             (715923.2178 +
             (31.8792 +
             (0.051635 +
             (-0.00024470) * t) * t) * t) * t) * ASEC2RAD
             + positive_fmod(1325.0 * t, 1.0) * TAU);

    fa[1] = ((1287104.793048 +
             (1292581.0481 +
             (-0.5532 +
             (0.000136 +
             (-0.00001149) * t) * t) * t) * t) * ASEC2RAD
             + positive_fmod(99.0 * t, 1.0) * TAU);

    fa[2] = ((335779.526232 +
             (295262.8478 +
             (-12.7512 +
             (-0.001037 +
             (0.00000417) * t) * t) * t) * t) * ASEC2RAD
             + positive_fmod(1342.0 * t, 1.0) * TAU);

    fa[3] = ((1072260.703692 +
             (1105601.2090 +
             (-6.3706 +
             (0.006593 +
             (-0.00003169) * t) * t) * t) * t) * ASEC2RAD
             + positive_fmod(1236.0 * t, 1.0) * TAU);

    fa[4] = ((450160.398036 +
             (-482890.5431 +
             (7.4722 +
             (0.007702 +
             (-0.00005939) * t) * t) * t) * t) * ASEC2RAD
             + positive_fmod(-5.0 * t, 1.0) * TAU);

    fa[5] = 4.402608842 + 2608.7903141574 * t;
    fa[6] = 3.176146697 + 1021.3285546211 * t;
    fa[7] = 1.753470314 + 628.3075849991 * t;
    fa[8] = 6.203480913 + 334.0612426700 * t;
    fa[9] = 0.599546497 + 52.9690962641 * t;
    fa[10] = 0.874016757 + 21.3299104960 * t;
    fa[11] = 5.481293872 + 7.4781598567 * t;
    fa[12] = 5.311886287 + 3.8133035638 * t;
    fa[13] = (0.024381750 + 0.00000538691 * t) * t;

    for (double& angle : fa) {
        angle = positive_fmod(angle, TAU);
    }

    double a = 0.0;
    for (int i = 0; i < 14; ++i) {
        a += ke1[i] * fa[i];
    }
    double c_terms = se1_0 * sin(a);
    c_terms *= t;

    for (int row = 0; row < 33; ++row) {
        double arg = 0.0;
        for (int i = 0; i < 14; ++i) {
            arg += ke0_t[row][i] * fa[i];
        }
        c_terms += se0_t_0[row] * sin(arg);
        c_terms += se0_t_1[row] * cos(arg);
    }

    return c_terms * ASEC2RAD;
}

void skyfield_fundamental_arguments(double t, double arguments[5]) {
    static const double fa0[5] = {
        485868.249036,
        1287104.79305,
        335779.526232,
        1072260.70369,
        450160.398036,
    };
    static const double fa1[5] = {
        1717915923.2178,
        129596581.0481,
        1739527262.8478,
        1602961601.2090,
        -6962890.5431,
    };
    static const double fa2[5] = {
        31.8792,
        -0.5532,
        -12.7512,
        -6.3706,
        7.4722,
    };
    static const double fa3[5] = {
        0.051635,
        0.000136,
        -0.001037,
        0.006593,
        0.007702,
    };
    static const double fa4[5] = {
        -0.00024470,
        -0.00001149,
        0.00000417,
        -0.00003169,
        -0.00005939,
    };

    for (int i = 0; i < 5; ++i) {
        double value = fa4[i] * t;
        value += fa3[i];
        value *= t;
        value += fa2[i];
        value *= t;
        value += fa1[i];
        value *= t;
        value += fa0[i];
        value = fmod(value, ASEC360);
        arguments[i] = value * ASEC2RAD;
    }
}

void skyfield_iau2000a_radians(double jd_tt, double& dpsi_radians, double& deps_radians) {
    using namespace iau2000a_nutation_data;

    static const double anomaly_constant[14] = {
        2.35555598,
        6.24006013,
        1.627905234,
        5.198466741,
        2.18243920,
        4.402608842,
        3.176146697,
        1.753470314,
        6.203480913,
        0.599546497,
        0.874016757,
        5.481293871,
        5.321159000,
        0.02438175,
    };
    static const double anomaly_coefficient[14] = {
        8328.6914269554,
        628.301955,
        8433.466158131,
        7771.3771468121,
        -33.757045,
        2608.7903141574,
        1021.3285546211,
        628.3075849991,
        334.0612426700,
        52.9690962641,
        21.3299104960,
        7.4781598567,
        3.8127774000,
        0.00000538691,
    };

    const double t = (jd_tt - T0) / 36525.0;

    double fundamental_args[5];
    skyfield_fundamental_arguments(t, fundamental_args);

    double dpsi = 0.0;
    double deps = 0.0;

    for (int row = 0; row < 678; ++row) {
        double arg = 0.0;
        for (int i = 0; i < 5; ++i) {
            arg += NALS_T[row][i] * fundamental_args[i];
        }

        const double sarg = sin(arg);
        const double carg = cos(arg);

        dpsi += sarg * LUNISOLAR_LONGITUDE_COEFFICIENTS[row][0];
        dpsi += sarg * LUNISOLAR_LONGITUDE_COEFFICIENTS[row][1] * t;
        dpsi += carg * LUNISOLAR_LONGITUDE_COEFFICIENTS[row][2];

        deps += carg * LUNISOLAR_OBLIQUITY_COEFFICIENTS[row][0];
        deps += carg * LUNISOLAR_OBLIQUITY_COEFFICIENTS[row][1] * t;
        deps += sarg * LUNISOLAR_OBLIQUITY_COEFFICIENTS[row][2];
    }

    double planetary_args[14];
    for (int i = 0; i < 14; ++i) {
        planetary_args[i] = anomaly_constant[i] + anomaly_coefficient[i] * t;
    }
    planetary_args[13] *= t;

    for (int row = 0; row < 687; ++row) {
        double arg = 0.0;
        for (int i = 0; i < 14; ++i) {
            arg += NAPL_T[row][i] * planetary_args[i];
        }

        const double sarg = sin(arg);
        const double carg = cos(arg);

        dpsi += sarg * NUTATION_COEFFICIENTS_LONGITUDE[row][0];
        dpsi += carg * NUTATION_COEFFICIENTS_LONGITUDE[row][1];

        deps += sarg * NUTATION_COEFFICIENTS_OBLIQUITY[row][0];
        deps += carg * NUTATION_COEFFICIENTS_OBLIQUITY[row][1];
    }

    dpsi_radians = dpsi * TENTH_USEC_2_RAD;
    deps_radians = deps * TENTH_USEC_2_RAD;
}

void build_icrs_to_j2000(double B[3][3]) {
    const double xi0 = -0.0166170 * ASEC2RAD;
    const double eta0 = -0.0068192 * ASEC2RAD;
    const double da0 = -0.01460 * ASEC2RAD;

    const double yx = -da0;
    const double zx = xi0;
    const double xy = da0;
    const double zy = eta0;
    const double xz = -xi0;
    const double yz = -eta0;

    B[0][0] = 1.0 - 0.5 * (yx * yx + zx * zx);
    B[0][1] = xy;
    B[0][2] = xz;
    B[1][0] = yx;
    B[1][1] = 1.0 - 0.5 * (yx * yx + zy * zy);
    B[1][2] = yz;
    B[2][0] = zx;
    B[2][1] = zy;
    B[2][2] = 1.0 - 0.5 * (zy * zy + zx * zx);
}

void build_skyfield_nutation_matrix(
    double mean_obliquity_radians,
    double true_obliquity_radians,
    double psi_radians,
    double N[3][3]
) {
    const double cobm = cos(mean_obliquity_radians);
    const double sobm = sin(mean_obliquity_radians);
    const double cobt = cos(true_obliquity_radians);
    const double sobt = sin(true_obliquity_radians);
    const double cpsi = cos(psi_radians);
    const double spsi = sin(psi_radians);

    N[0][0] = cpsi;
    N[0][1] = -spsi * cobm;
    N[0][2] = -spsi * sobm;
    N[1][0] = spsi * cobt;
    N[1][1] = cpsi * cobm * cobt + sobm * sobt;
    N[1][2] = cpsi * sobm * cobt - cobm * sobt;
    N[2][0] = spsi * sobt;
    N[2][1] = cpsi * cobm * sobt - sobm * cobt;
    N[2][2] = cpsi * sobm * sobt + cobm * cobt;
}

void compute_skyfield_precession_matrix(double jd_tdb, double P[3][3]) {
    const double eps0_arcsec = 84381.406;
    const double t = (jd_tdb - T0) / 36525.0;

    const double psia =
        ((((-0.0000000951 * t
            + 0.000132851) * t
            - 0.00114045) * t
            - 1.0790069) * t
            + 5038.481507) * t;

    const double omegaa =
        ((((0.0000003337 * t
            - 0.000000467) * t
            - 0.00772503) * t
            + 0.0512623) * t
            - 0.025754) * t + eps0_arcsec;

    const double chia =
        ((((-0.0000000560 * t
            + 0.000170663) * t
            - 0.00121197) * t
            - 2.3814292) * t
            + 10.556403) * t;

    const double eps0 = eps0_arcsec * ASEC2RAD;
    const double psia_rad = psia * ASEC2RAD;
    const double omegaa_rad = omegaa * ASEC2RAD;
    const double chia_rad = chia * ASEC2RAD;

    const double sa = sin(eps0);
    const double ca = cos(eps0);
    const double sb = sin(-psia_rad);
    const double cb = cos(-psia_rad);
    const double sc = sin(-omegaa_rad);
    const double cc = cos(-omegaa_rad);
    const double sd = sin(chia_rad);
    const double cd = cos(chia_rad);

    P[0][0] = cd * cb - sb * sd * cc;
    P[0][1] = cd * sb * ca + sd * cc * cb * ca - sa * sd * sc;
    P[0][2] = cd * sb * sa + sd * cc * cb * sa + ca * sd * sc;
    P[1][0] = -sd * cb - sb * cd * cc;
    P[1][1] = -sd * sb * ca + cd * cc * cb * ca - sa * cd * sc;
    P[1][2] = -sd * sb * sa + cd * cc * cb * sa + ca * cd * sc;
    P[2][0] = sb * sc;
    P[2][1] = -sc * cb * ca - sa * cc;
    P[2][2] = -sc * cb * sa + cc * ca;
}

void build_skyfield_rot_z(double angle, double R[3][3]) {
    const double c = cos(angle);
    const double s = sin(angle);
    R[0][0] = c;
    R[0][1] = -s;
    R[0][2] = 0.0;
    R[1][0] = s;
    R[1][1] = c;
    R[1][2] = 0.0;
    R[2][0] = 0.0;
    R[2][1] = 0.0;
    R[2][2] = 1.0;
}

double skyfield_gast_radians(
    const PreciseTimeCalculator::TimeScales& time_scales,
    double dpsi_radians
) {
    const double gmst_hours = skyfield_sidereal_time_hours(
        time_scales.jd_whole,
        time_scales.ut1_fraction,
        time_scales.tdb_fraction
    );
    const double mean_obliquity = skyfield_mean_obliquity_radians(time_scales.jd_tdb);
    const double c_terms = skyfield_equation_of_the_equinoxes_complimentary_terms(time_scales.jd_tt);
    const double eq_eq = dpsi_radians * cos(mean_obliquity) + c_terms;
    double gast_hours = fmod(gmst_hours + eq_eq / TAU * 24.0, 24.0);
    if (gast_hours < 0.0) {
        gast_hours += 24.0;
    }
    return gast_hours / 24.0 * TAU;
}

// Inline matrix operations under the file-level fp-contract=off pragma.
// mat3.c is compiled separately with default flags (FMA enabled).

void inline_rxr(double a[3][3], double b[3][3], double atb[3][3]) {
    double w[3][3];
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            double s = 0.0;
            for (int k = 0; k < 3; k++) {
                s += a[i][k] * b[k][j];
            }
            w[i][j] = s;
        }
    }
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
            atb[i][j] = w[i][j];
}


// Triple matrix product with Kahan compensated summation.
// Accumulates all 9 terms per entry (matching numpy einsum('ij,jk,kl->il'))
// without materializing the intermediate A×B matrix.
void inline_mxmxm(double A[3][3], double B[3][3], double C[3][3], double result[3][3]) {
    double w[3][3];
    for (int i = 0; i < 3; i++) {
        for (int l = 0; l < 3; l++) {
            double s = 0.0;
            double c = 0.0;  // Kahan compensation
            for (int j = 0; j < 3; j++) {
                for (int k = 0; k < 3; k++) {
                    double term = A[i][j] * B[j][k] * C[k][l];
                    double y = term - c;
                    double t = s + y;
                    c = (t - s) - y;
                    s = t;
                }
            }
            w[i][l] = s;
        }
    }
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
            result[i][j] = w[i][j];
}

void inline_tr(double r[3][3], double rt[3][3]) {
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
            rt[i][j] = r[j][i];
}

}  // namespace

// Helper struct to pass datetime components from Elixir to C++
struct DateTimeComponents {
    int year;
    int month;
    int day;
    int hour;
    int minute;
    int second;
    int microsecond;
};

// Helper function to parse the datetime tuple from Elixir
static bool extract_datetime_components(ErlNifEnv* env, ERL_NIF_TERM datetime_term, DateTimeComponents& dt) {
    const ERL_NIF_TERM* tuple;
    int arity;
    if (!enif_get_tuple(env, datetime_term, &arity, &tuple) || arity != 2) return false;

    const ERL_NIF_TERM* date_tuple;
    const ERL_NIF_TERM* time_tuple;
    int date_arity, time_arity;

    if (!enif_get_tuple(env, tuple[0], &date_arity, &date_tuple) || date_arity != 3 ||
        !enif_get_tuple(env, tuple[1], &time_arity, &time_tuple) || (time_arity != 3 && time_arity != 4)) {
        return false;
    }

    if (!enif_get_int(env, date_tuple[0], &dt.year) ||
        !enif_get_int(env, date_tuple[1], &dt.month) ||
        !enif_get_int(env, date_tuple[2], &dt.day) ||
        !enif_get_int(env, time_tuple[0], &dt.hour) ||
        !enif_get_int(env, time_tuple[1], &dt.minute) ||
        !enif_get_int(env, time_tuple[2], &dt.second)) {
        return false;
    }

    dt.microsecond = 0;
    if (time_arity == 4) {
        enif_get_int(env, time_tuple[3], &dt.microsecond);
    }
    return true;
}

// The single, correct propagation function.
// It takes pre-parsed elements from Elixir and uses sgp4init.
static ERL_NIF_TERM propagate_with_elements(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    // Arguments: tle_map, datetime_tuple
    if (argc != 2) {
        return enif_make_badarg(env);
    }

    // Extract orbital elements from the Elixir map
    ERL_NIF_TERM map = argv[0];
    char catalog_str[10];
    double bstar, ndot, nddot, ecco, argpo, inclo, mo, no_kozai, nodeo;
    int epochyr;
    double epochdays;

    ERL_NIF_TERM value;
    
    // catalog_number is a string - use enif_get_string directly
    if (!enif_get_map_value(env, map, enif_make_atom(env, "catalog_number"), &value)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to get catalog_number from map", ERL_NIF_LATIN1));
    }
    
    // Try as binary first (Elixir strings are binaries)
    ErlNifBinary catalog_bin;
    if (enif_inspect_binary(env, value, &catalog_bin)) {
        if (catalog_bin.size >= sizeof(catalog_str)) {
            return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "catalog_number too long", ERL_NIF_LATIN1));
        }
        memcpy(catalog_str, catalog_bin.data, catalog_bin.size);
        catalog_str[catalog_bin.size] = '\0';
    } else if (enif_is_list(env, value)) {
        // Try as list (Erlang string)
        int str_len = enif_get_string(env, value, catalog_str, sizeof(catalog_str), ERL_NIF_LATIN1);
        if (str_len == 0) {
            return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to convert catalog_number list to C string", ERL_NIF_LATIN1));
        }
    } else {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "catalog_number is neither binary nor list", ERL_NIF_LATIN1));
    }

    if (!enif_get_map_value(env, map, enif_make_atom(env, "bstar"), &value) ||
        !enif_get_double(env, value, &bstar)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to extract bstar", ERL_NIF_LATIN1));
    }
    if (!enif_get_map_value(env, map, enif_make_atom(env, "mean_motion_dot"), &value) ||
        !enif_get_double(env, value, &ndot)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to extract mean_motion_dot", ERL_NIF_LATIN1));
    }
    if (!enif_get_map_value(env, map, enif_make_atom(env, "mean_motion_double_dot"), &value) ||
        !enif_get_double(env, value, &nddot)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to extract mean_motion_double_dot", ERL_NIF_LATIN1));
    }
    if (!enif_get_map_value(env, map, enif_make_atom(env, "eccentricity"), &value) ||
        !enif_get_double(env, value, &ecco)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to extract eccentricity", ERL_NIF_LATIN1));
    }
    if (!enif_get_map_value(env, map, enif_make_atom(env, "arg_perigee_deg"), &value) ||
        !enif_get_double(env, value, &argpo)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to extract arg_perigee_deg", ERL_NIF_LATIN1));
    }
    if (!enif_get_map_value(env, map, enif_make_atom(env, "inclination_deg"), &value) ||
        !enif_get_double(env, value, &inclo)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to extract inclination_deg", ERL_NIF_LATIN1));
    }
    if (!enif_get_map_value(env, map, enif_make_atom(env, "mean_anomaly_deg"), &value) ||
        !enif_get_double(env, value, &mo)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to extract mean_anomaly_deg", ERL_NIF_LATIN1));
    }
    if (!enif_get_map_value(env, map, enif_make_atom(env, "mean_motion"), &value) ||
        !enif_get_double(env, value, &no_kozai)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to extract mean_motion", ERL_NIF_LATIN1));
    }
    if (!enif_get_map_value(env, map, enif_make_atom(env, "raan_deg"), &value) ||
        !enif_get_double(env, value, &nodeo)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to extract raan_deg", ERL_NIF_LATIN1));
    }
    if (!enif_get_map_value(env, map, enif_make_atom(env, "epochyr"), &value) ||
        !enif_get_int(env, value, &epochyr)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to extract epochyr", ERL_NIF_LATIN1));
    }
    if (!enif_get_map_value(env, map, enif_make_atom(env, "epochdays"), &value) ||
        !enif_get_double(env, value, &epochdays)) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, "Failed to extract epochdays", ERL_NIF_LATIN1));
    }

    // Extract datetime components
    DateTimeComponents dt;
    if (!extract_datetime_components(env, argv[1], dt)) {
        return enif_make_badarg(env);
    }

    // Initialize satellite record using sgp4init
    elsetrec satrec;
    memset(&satrec, 0, sizeof(satrec));  // Zero-initialize the structure
    gravconsttype whichconst = wgs72;
    char opsmode = 'i';

    // Convert epoch year and days to SGP4 epoch format (days from 1949 Dec 31)
    int year_full = (epochyr < 57) ? epochyr + 2000 : epochyr + 1900;
    double jd, jdfrac;
    int mon, day, hr, minute;
    double sec;
    SGP4Funcs::days2mdhms_SGP4(year_full, epochdays, mon, day, hr, minute, sec);
    SGP4Funcs::jday_SGP4(year_full, mon, day, hr, minute, sec, jd, jdfrac);
    
    // Skyfield passes UTC (not TT) to SGP4, per AIAA 2006-6753.
    
    double epoch_sgp4 = jd + jdfrac - 2433281.5;
    
    // Set the epoch fields
    satrec.epochyr = epochyr;
    satrec.epochdays = epochdays;
    satrec.jdsatepoch = jd;
    satrec.jdsatepochF = jdfrac;
    

    // Convert angles to radians for sgp4init
    const double deg2rad = M_PI / 180.0;
    inclo *= deg2rad;
    nodeo *= deg2rad;
    argpo *= deg2rad;
    mo *= deg2rad;

    // Convert mean motion to rad/minute
    const double xpdotp = 1440.0 / (2.0 * M_PI);
    no_kozai /= xpdotp;

    
    bool init_result = SGP4Funcs::sgp4init(
        whichconst, opsmode, catalog_str, epoch_sgp4, bstar,
        ndot, nddot, ecco, argpo, inclo, mo, no_kozai, nodeo, satrec
    );

    if (!init_result || satrec.error != 0) {
        char error_msg[200];
        snprintf(error_msg, sizeof(error_msg), "SGP4 initialization failed (init_result=%d, error=%d)", init_result, satrec.error);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, error_msg, ERL_NIF_LATIN1));
    }
    
    // sgp4init doesn't set these fields - they're only set by twoline2rv
    // Since we're bypassing twoline2rv, we need to set them manually
    satrec.epochyr = epochyr;
    satrec.epochdays = epochdays;
    satrec.jdsatepoch = jd;
    satrec.jdsatepochF = jdfrac;
    
    
    // Calculate target time in UTC
    double target_jd_utc, target_jdfrac_utc;
    SGP4Funcs::jday_SGP4(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second + dt.microsecond / 1000000.0, target_jd_utc, target_jdfrac_utc);

    // Calculate tsince using UTC to match Skyfield's actual behavior
    // Skyfield passes UTC times to SGP4, not TT
    double target_utc = target_jd_utc + target_jdfrac_utc;
    double epoch_jd = satrec.jdsatepoch + satrec.jdsatepochF;
    double tsince = (target_utc - epoch_jd) * 1440.0;

    // Propagate
    double r[3], v[3];
    SGP4Funcs::sgp4(satrec, tsince, r, v);

    if (satrec.error != 0) {
        char error_msg[200];
        snprintf(error_msg, sizeof(error_msg), "SGP4 propagation failed with error code %d", satrec.error);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, error_msg, ERL_NIF_LATIN1));
    }

    // Return TEME state in km and km/s
    ERL_NIF_TERM pos = enif_make_tuple3(env, enif_make_double(env, r[0]), enif_make_double(env, r[1]), enif_make_double(env, r[2]));
    ERL_NIF_TERM vel = enif_make_tuple3(env, enif_make_double(env, v[0]), enif_make_double(env, v[1]), enif_make_double(env, v[2]));
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_tuple2(env, pos, vel));
}


static ERL_NIF_TERM teme_to_gcrs(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    double x_teme, y_teme, z_teme, vx_teme, vy_teme, vz_teme;
    DateTimeComponents dt;

    if (argc != 7 ||
        !enif_get_double(env, argv[0], &x_teme) || !enif_get_double(env, argv[1], &y_teme) ||
        !enif_get_double(env, argv[2], &z_teme) || !enif_get_double(env, argv[3], &vx_teme) ||
        !enif_get_double(env, argv[4], &vy_teme) || !enif_get_double(env, argv[5], &vz_teme) ||
        !extract_datetime_components(env, argv[6], dt)) {
        return enif_make_badarg(env);
    }

    auto time_scales = PreciseTimeCalculator::from_utc(
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second + dt.microsecond / 1000000.0
    );

    double dpsi, deps;
    skyfield_iau2000a_radians(time_scales.jd_tt, dpsi, deps);
    const double mean_obliquity = skyfield_mean_obliquity_radians(time_scales.jd_tdb);
    const double true_obliquity = mean_obliquity + deps;

    double N[3][3], P[3][3], B[3][3], M[3][3];
    build_skyfield_nutation_matrix(mean_obliquity, true_obliquity, dpsi, N);
    compute_skyfield_precession_matrix(time_scales.jd_tdb, P);
    build_icrs_to_j2000(B);
    // Use Kahan-compensated triple product (matching Skyfield's mxmxm)
    inline_mxmxm(N, P, B, M);
    double gast = skyfield_gast_radians(time_scales, dpsi);

    const double theta_gmst1982 = compute_theta_gmst1982(
        time_scales.jd_whole,
        time_scales.ut1_fraction
    );
    double angle = theta_gmst1982 - gast;

    double R[3][3], G_gcrs_to_teme[3][3], T[3][3];
    build_skyfield_rot_z(angle, R);
    inline_rxr(R, M, G_gcrs_to_teme);
    inline_tr(G_gcrs_to_teme, T);

    // Match Skyfield's _at() pipeline: scale to AU / AU/day, rotate, scale back.
    double r_au[3] = {x_teme / AU_KM, y_teme / AU_KM, z_teme / AU_KM};
    double r_gcrs_au[3];
    mat3_vec3_mul(T, r_au, r_gcrs_au);
    double r_gcrs[3] = {r_gcrs_au[0] * AU_KM, r_gcrs_au[1] * AU_KM, r_gcrs_au[2] * AU_KM};

    double v_au_d[3];
    v_au_d[0] = vx_teme / AU_KM * DAY_S;
    v_au_d[1] = vy_teme / AU_KM * DAY_S;
    v_au_d[2] = vz_teme / AU_KM * DAY_S;
    double v_gcrs_au_d[3];
    mat3_vec3_mul(T, v_au_d, v_gcrs_au_d);
    double v_gcrs[3];
    v_gcrs[0] = v_gcrs_au_d[0] * AU_KM / DAY_S;
    v_gcrs[1] = v_gcrs_au_d[1] * AU_KM / DAY_S;
    v_gcrs[2] = v_gcrs_au_d[2] * AU_KM / DAY_S;

    ERL_NIF_TERM pos = enif_make_tuple3(env, enif_make_double(env, r_gcrs[0]), enif_make_double(env, r_gcrs[1]), enif_make_double(env, r_gcrs[2]));
    ERL_NIF_TERM vel = enif_make_tuple3(env, enif_make_double(env, v_gcrs[0]), enif_make_double(env, v_gcrs[1]), enif_make_double(env, v_gcrs[2]));
    return enif_make_tuple2(env, pos, vel);
}

// NIF initialization
static ErlNifFunc nif_funcs[] = {
    {"propagate_with_elements", 2, propagate_with_elements},
    {"teme_to_gcrs", 7, teme_to_gcrs}
};

ERL_NIF_INIT(Elixir.SGP4NIF, nif_funcs, NULL, NULL, NULL, NULL)

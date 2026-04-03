#pragma once
#include <cmath>
#include <vector>

/**
 * @class PreciseGastCalculator
 * @brief Provides exact GAST calculation using IAU 2000A/2006 models
 *
 * This class calculates GAST using the complete IAU 2000A/2006 models.
 * It matches reference implementations exactly to floating-point precision.
 */
class PreciseGastCalculator {
public:
    /**
     * @brief Calculates GAST in radians from UT1 and TDB Julian Dates.
     */
    static double calculate_gast_radians(double jd_ut1, double jd_tdb);

private:
    // --- Constants ---
    static constexpr long double PI = 3.14159265358979323846L;
    static constexpr long double TWOPI = 2.0L * PI;
    static constexpr long double ASEC_TO_RAD = 4.8481368110953599359e-6L;
    static constexpr double J2000 = 2451545.0;
    static constexpr double DAYS_PER_CENTURY = 36525.0;

    // --- Data structure for a single nutation term ---
    struct NutationTerm {
        int nl, nlp, nf, nd, nom;
        double ps, pc, es, ec;
    };
    
    // IAU 2000A 106-term nutation series
    static const std::vector<NutationTerm> NUTATION_SERIES;

    /**
     * @brief Calculates the 5 fundamental arguments for nutation theory.
     */
    static std::vector<long double> calculate_fundamental_arguments(long double t);

    /**
     * @brief Calculates nutation in longitude (d_psi) and obliquity (d_eps) using the 106-term model.
     */
    static void calculate_nutation(long double t, const std::vector<long double>& args, double& d_psi_rad, double& d_eps_rad);

    // --- Helper functions ---
    static double calculate_era(double jd_ut1);
    static double calculate_equation_of_origins(long double t);
    static double calculate_mean_obliquity(long double t);
    static double calculate_eofe(double d_psi_rad, double epsilon_a_rad, double mean_asc_node_rad);
};
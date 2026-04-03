#pragma once
#include <vector>

// Forward declaration for the data struct in the iers namespace
namespace iers { struct Ut1Data; }

/**
 * @class PreciseTimeCalculator
 * @brief Handles dynamic UTC -> UT1/TDB time scale conversions using IERS data.
 */
class PreciseTimeCalculator {
public:
    struct TimeScales {
        double jd_whole;
        double ut1_fraction;
        double tt_fraction;
        double tdb_fraction;
        double jd_ut1;
        double jd_tt;
        double jd_tdb;
    };

    /**
     * @brief Converts a UTC calendar date to UT1 and TDB Julian Dates.
     */
    static TimeScales from_utc(int year, int month, int day, int hour, int minute, double second);

private:
    struct LeapSecondData { int mjd; double tai_utc; };
    static const std::vector<LeapSecondData> LEAP_SECOND_DATA;

    static void utc_to_jd(int y, int m, int d, int h, int min, double sec, double& jd1, double& jd2);
    static double find_leap_seconds(double jd_utc);
    static double interpolate_ut1_utc(double jd_utc);
    static double interpolate_delta_t(double jd_tt);
};

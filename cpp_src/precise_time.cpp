#include "precise_time.h"
#include "iers_ut1_data.hpp" // The data file you generated
#include <stdexcept>
#include <cmath>
#include <algorithm>

namespace {

constexpr double DAY_S = 86400.0;
constexpr double T0 = 2451545.0;
constexpr double TT_MINUS_TAI_S = 32.184;
constexpr double ROUND_1E7 = 10000000.0;

long julian_day_number(int year, int month, int day) {
    const bool janfeb = month <= 2;
    const long g = static_cast<long>(year) + 4716L - (janfeb ? 1L : 0L);
    const long f = static_cast<long>((month + 9) % 12);
    const long e = 1461L * g / 4L + day - 1402L;
    long j = e + (153L * f + 2L) / 5L;
    j += 38L - ((g + 184L) / 100L) * 3L / 4L;
    return j;
}

}  // namespace

// --- Leap Second Data Definition ---
const std::vector<PreciseTimeCalculator::LeapSecondData> PreciseTimeCalculator::LEAP_SECOND_DATA = {
    {41317, 10.0}, {41499, 11.0}, {41683, 12.0}, {42048, 13.0}, {42413, 14.0},
    {42778, 15.0}, {43144, 16.0}, {43509, 17.0}, {43874, 18.0}, {44239, 19.0},
    {44786, 20.0}, {45151, 21.0}, {45516, 22.0}, {46247, 23.0}, {47161, 24.0},
    {47892, 25.0}, {48257, 26.0}, {48804, 27.0}, {49169, 28.0}, {49534, 29.0},
    {50083, 30.0}, {50448, 31.0}, {50813, 32.0}, {53736, 33.0}, {54832, 34.0},
    {56109, 35.0}, {57204, 36.0}, {57754, 37.0}
};

// --- Method Implementations ---

PreciseTimeCalculator::TimeScales PreciseTimeCalculator::from_utc(int year, int month, int day, int hour, int minute, double second) {
    double jd_utc_d1, jd_utc_d2;
    utc_to_jd(year, month, day, hour, minute, second, jd_utc_d1, jd_utc_d2);
    const double jd_utc_total = jd_utc_d1 + jd_utc_d2;
    const double leap_seconds = find_leap_seconds(jd_utc_total);
    const double utc_seconds_of_day = hour * 3600.0 + minute * 60.0 + second;
    const double utc_seconds_at_midnight = jd_utc_d1 * DAY_S;

    double utc_subsecond = 0.0;
    double utc_whole_seconds_of_day = 0.0;
    utc_subsecond = std::modf(utc_seconds_of_day, &utc_whole_seconds_of_day);

    // Mirror Skyfield's _utc() path: convert UTC midnight to integer TAI
    // seconds, add the whole seconds of the current time, then keep the
    // remaining sub-second separately until the final day/fraction split.
    const double tai_seconds = utc_seconds_at_midnight + leap_seconds + utc_whole_seconds_of_day;
    const double jd_whole = std::floor(tai_seconds / DAY_S);
    const double tai_fraction = (tai_seconds - jd_whole * DAY_S + utc_subsecond) / DAY_S;
    const double tt_offset_days = TT_MINUS_TAI_S / DAY_S;

    TimeScales result;
    result.jd_whole = jd_whole;
    result.tt_fraction = tai_fraction + tt_offset_days;
    result.jd_tt = result.jd_whole + result.tt_fraction;

    const double delta_t = interpolate_delta_t(result.jd_tt);
    result.ut1_fraction = result.tt_fraction - delta_t / DAY_S;
    result.jd_ut1 = result.jd_whole + result.ut1_fraction;

    // Skyfield computes TDB from the same split TT representation.
    const double t = (result.jd_whole - T0 + result.tt_fraction) / 36525.0;
    const double tdb_minus_tt_seconds = (0.001657 * sin(628.3076 * t + 6.2401)
                                       + 0.000022 * sin(575.3385 * t + 4.2970)
                                       + 0.000014 * sin(1256.6152 * t + 6.1969)
                                       + 0.000005 * sin(606.9777 * t + 4.0212)
                                       + 0.000005 * sin(52.9691 * t + 0.4444)
                                       + 0.000002 * sin(21.3299 * t + 5.5431)
                                       + 0.000010 * t * sin(628.3076 * t + 4.2490));

    const double tdb_minus_tt_days = tdb_minus_tt_seconds / DAY_S;
    result.tdb_fraction = result.tt_fraction + tdb_minus_tt_days;
    result.jd_tdb = result.jd_whole + result.tdb_fraction;

    return result;
}

void PreciseTimeCalculator::utc_to_jd(int y, int m, int d, int h, int min, double sec, double& jd1, double& jd2) {
    const long jd_day = julian_day_number(y, m, d);
    jd1 = static_cast<double>(jd_day) - 0.5;
    jd2 = (sec + min * 60.0 + h * 3600.0) / DAY_S;
}

double PreciseTimeCalculator::find_leap_seconds(double jd_utc) {
    const int mjd = static_cast<int>(jd_utc - 2400000.5);
    double ls = 10.0;
    for (const auto& entry : LEAP_SECOND_DATA) {
        if (mjd >= entry.mjd) { ls = entry.tai_utc; } else { break; }
    }
    return ls;
}

double PreciseTimeCalculator::interpolate_ut1_utc(double jd_utc) {
    const double mjd = jd_utc - 2400000.5;
    const iers::Ut1Data* p1 = nullptr;
    const iers::Ut1Data* p2 = nullptr;

    if (mjd < iers::UT1_DATA.front().mjd || mjd > iers::UT1_DATA.back().mjd) {
        throw std::runtime_error("UTC date is outside the bounds of the embedded IERS data table.");
    }

    for (size_t i = 0; i < iers::UT1_DATA.size() - 1; ++i) {
        if (mjd >= iers::UT1_DATA[i].mjd && mjd < iers::UT1_DATA[i+1].mjd) {
            p1 = &iers::UT1_DATA[i]; p2 = &iers::UT1_DATA[i+1]; break;
        }
    }
    if (!p1) { p1 = &iers::UT1_DATA.back() - 1; p2 = &iers::UT1_DATA.back(); }
    
    const double x = mjd;
    const double x1 = p1->mjd; const double y1 = p1->ut1_utc;
    const double x2 = p2->mjd; const double y2 = p2->ut1_utc;
    const double ut1_utc_seconds = y1 + (x - x1) * (y2 - y1) / (x2 - x1);
    return ut1_utc_seconds / 86400.0;
}

double PreciseTimeCalculator::interpolate_delta_t(double jd_tt) {
    struct DeltaTRow {
        double jd_tt;
        double delta_t;
    };

    static const std::vector<DeltaTRow> table = []() {
        std::vector<DeltaTRow> rows;
        rows.reserve(iers::UT1_DATA.size());

        for (const auto& entry : iers::UT1_DATA) {
            const double jd_utc = entry.mjd + 2400000.5;
            const double leap_seconds = find_leap_seconds(jd_utc);
            const double tt_minus_utc = leap_seconds + TT_MINUS_TAI_S;
            const double delta_t =
                std::nearbyint((tt_minus_utc - entry.ut1_utc) * ROUND_1E7) / ROUND_1E7;
            rows.push_back({jd_utc + tt_minus_utc / DAY_S, delta_t});
        }

        return rows;
    }();

    if (jd_tt < table.front().jd_tt || jd_tt > table.back().jd_tt) {
        throw std::runtime_error("TT date is outside the bounds of the embedded Delta T table.");
    }

    auto it = std::lower_bound(
        table.begin(),
        table.end(),
        jd_tt,
        [](const DeltaTRow& row, double value) { return row.jd_tt < value; }
    );

    if (it == table.begin()) {
        return it->delta_t;
    }

    if (it == table.end()) {
        return table.back().delta_t;
    }

    if (it->jd_tt == jd_tt) {
        return it->delta_t;
    }

    const auto& p2 = *it;
    const auto& p1 = *(it - 1);
    return p1.delta_t + (jd_tt - p1.jd_tt) * (p2.delta_t - p1.delta_t) / (p2.jd_tt - p1.jd_tt);
}

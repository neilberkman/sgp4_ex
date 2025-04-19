#include <erl_nif.h>
#include "SGP4.h"

static ERL_NIF_TERM propagate_tle(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ErlNifBinary line1, line2;
    double tsince;

    // Validate input arguments: two binaries (TLE lines) and a float (time since epoch)
    if (argc != 3 ||
        !enif_inspect_binary(env, argv[0], &line1) ||
        !enif_inspect_binary(env, argv[1], &line2) ||
        !enif_get_double(env, argv[2], &tsince)) {
        return enif_make_badarg(env);
    }

    // Ensure TLE lines are null-terminated strings
    char tle1[70], tle2[70];
    if (line1.size >= 70 || line2.size >= 70) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "TLE lines too long", ERL_NIF_LATIN1));
    }
    memcpy(tle1, line1.data, line1.size);
    tle1[line1.size] = '\0';
    memcpy(tle2, line2.data, line2.size);
    tle2[line2.size] = '\0';

    // Initialize satellite record
    elsetrec satrec;
    char typerun = 'c'; // Catalog mode
    char typeinput = 's'; // Seconds from epoch
    char opsmode = 'i'; // Improved mode
    gravconsttype whichconst = wgs72; // WGS-72 constants

    double startmfe, stopmfe, deltamin;
    SGP4Funcs::twoline2rv(tle1, tle2, typerun, typeinput, opsmode, whichconst,
               startmfe, stopmfe, deltamin, satrec);

    if (satrec.error != 0) {
        char error_msg[50];
        snprintf(error_msg, sizeof(error_msg), "TLE initialization error: %d", satrec.error);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, error_msg, ERL_NIF_LATIN1));
    }

    // Propagate to specified time
    double r[3], v[3]; // Position (km) and velocity (km/s) in TEME
    bool result = SGP4Funcs::sgp4(satrec, tsince, r, v);

    if (!result || satrec.error != 0) {
        char error_msg[50];
        snprintf(error_msg, sizeof(error_msg), "Propagation error: %d", satrec.error);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, error_msg, ERL_NIF_LATIN1));
    }

    // Create return tuple: {:ok, {position, velocity}} (return in base SI units)
    ERL_NIF_TERM pos = enif_make_tuple3(env,
        enif_make_double(env, r[0] * 1000),
        enif_make_double(env, r[1] * 1000),
        enif_make_double(env, r[2] * 1000));
    ERL_NIF_TERM vel = enif_make_tuple3(env,
        enif_make_double(env, v[0] * 1000),
        enif_make_double(env, v[1] * 1000),
        enif_make_double(env, v[2] * 1000));
    ERL_NIF_TERM state = enif_make_tuple2(env, pos, vel);
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), state);
}

// NIF initialization
static ErlNifFunc nif_funcs[] = {
    {"propagate_tle", 3, propagate_tle}
};

ERL_NIF_INIT(Elixir.SGP4NIF, nif_funcs, NULL, NULL, NULL, NULL)
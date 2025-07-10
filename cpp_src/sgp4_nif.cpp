#include <erl_nif.h>
#include "SGP4.h"
#include <vector>
#include <memory>
#ifdef _OPENMP
#include <omp.h>
#endif

// Resource type for satellite handles (stateful API)
static ErlNifResourceType* satellite_resource_type = nullptr;

// Structure to hold an initialized satellite
struct SatelliteResource {
    elsetrec satrec;
    std::string line1;
    std::string line2;
    bool initialized;
    
    SatelliteResource() : initialized(false) {}
};

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

// Batch propagation with OpenMP parallelization
static ERL_NIF_TERM propagate_tle_batch(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ErlNifBinary line1, line2;
    
    // Validate input arguments: two binaries (TLE lines) and a list of times
    if (argc != 3 ||
        !enif_inspect_binary(env, argv[0], &line1) ||
        !enif_inspect_binary(env, argv[1], &line2) ||
        !enif_is_list(env, argv[2])) {
        return enif_make_badarg(env);
    }

    // Get list length
    unsigned int length;
    if (!enif_get_list_length(env, argv[2], &length) || length == 0) {
        return enif_make_badarg(env);
    }

    // Extract times from list
    std::vector<double> times(length);
    ERL_NIF_TERM list = argv[2];
    ERL_NIF_TERM head, tail;
    
    for (unsigned int i = 0; i < length; i++) {
        if (!enif_get_list_cell(env, list, &head, &tail) ||
            !enif_get_double(env, head, &times[i])) {
            return enif_make_badarg(env);
        }
        list = tail;
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

    // Initialize satellite record once
    elsetrec satrec;
    char typerun = 'c';
    char typeinput = 's';
    char opsmode = 'i';
    gravconsttype whichconst = wgs72;
    
    double startmfe, stopmfe, deltamin;
    SGP4Funcs::twoline2rv(tle1, tle2, typerun, typeinput, opsmode, whichconst,
               startmfe, stopmfe, deltamin, satrec);

    if (satrec.error != 0) {
        char error_msg[50];
        snprintf(error_msg, sizeof(error_msg), "TLE initialization error: %d", satrec.error);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, error_msg, ERL_NIF_LATIN1));
    }

    // Pre-allocate result vectors
    std::vector<double> r_results(length * 3);
    std::vector<double> v_results(length * 3);
    std::vector<bool> success(length);

    // Parallel propagation using OpenMP (if available)
    #ifdef _OPENMP
    #pragma omp parallel for
    #endif
    for (unsigned int i = 0; i < length; i++) {
        // Create a copy of satrec for thread safety
        elsetrec local_satrec = satrec;
        
        double r[3], v[3];
        bool result = SGP4Funcs::sgp4(local_satrec, times[i], r, v);
        
        success[i] = result && (local_satrec.error == 0);
        
        if (success[i]) {
            // Store results in km and km/s (SGP4 outputs are already in km)
            r_results[i * 3] = r[0];
            r_results[i * 3 + 1] = r[1];
            r_results[i * 3 + 2] = r[2];
            v_results[i * 3] = v[0]; 
            v_results[i * 3 + 1] = v[1];
            v_results[i * 3 + 2] = v[2];
        }
    }

    // Build result list
    ERL_NIF_TERM* results = (ERL_NIF_TERM*)enif_alloc(sizeof(ERL_NIF_TERM) * length);
    
    for (unsigned int i = 0; i < length; i++) {
        if (success[i]) {
            // Convert km to m and km/s to m/s to match single propagation
            ERL_NIF_TERM pos = enif_make_tuple3(env,
                enif_make_double(env, r_results[i * 3] * 1000),
                enif_make_double(env, r_results[i * 3 + 1] * 1000),
                enif_make_double(env, r_results[i * 3 + 2] * 1000));
            
            ERL_NIF_TERM vel = enif_make_tuple3(env,
                enif_make_double(env, v_results[i * 3] * 1000),
                enif_make_double(env, v_results[i * 3 + 1] * 1000),
                enif_make_double(env, v_results[i * 3 + 2] * 1000));
            
            ERL_NIF_TERM state = enif_make_tuple2(env, pos, vel);
            results[i] = enif_make_tuple2(env, enif_make_atom(env, "ok"), state);
        } else {
            results[i] = enif_make_tuple2(env, enif_make_atom(env, "error"),
                                         enif_make_string(env, "Propagation failed", ERL_NIF_LATIN1));
        }
    }
    
    ERL_NIF_TERM result_list = enif_make_list_from_array(env, results, length);
    enif_free(results);
    
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), result_list);
}

// ============================================================================
// Stateful API functions
// ============================================================================

// Initialize a satellite from TLE lines
static ERL_NIF_TERM init_satellite(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ErlNifBinary line1, line2;
    
    // Validate input arguments: two binaries (TLE lines)
    if (argc != 2 ||
        !enif_inspect_binary(env, argv[0], &line1) ||
        !enif_inspect_binary(env, argv[1], &line2)) {
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
    
    // Allocate resource for satellite
    SatelliteResource* sat_res = (SatelliteResource*)enif_alloc_resource(
        satellite_resource_type, sizeof(SatelliteResource));
    
    if (sat_res == nullptr) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Failed to allocate satellite resource", ERL_NIF_LATIN1));
    }
    
    // Initialize satellite using placement new
    new (sat_res) SatelliteResource();
    
    // Store TLE lines for reference
    sat_res->line1 = std::string(tle1);
    sat_res->line2 = std::string(tle2);
    
    // Initialize satellite record
    char typerun = 'c'; // Catalog mode
    char typeinput = 's'; // Seconds from epoch  
    char opsmode = 'i'; // Improved mode
    gravconsttype whichconst = wgs72; // WGS-72 constants
    
    double startmfe, stopmfe, deltamin;
    SGP4Funcs::twoline2rv(tle1, tle2, typerun, typeinput, opsmode, whichconst,
               startmfe, stopmfe, deltamin, sat_res->satrec);
    
    if (sat_res->satrec.error != 0) {
        char error_msg[50];
        snprintf(error_msg, sizeof(error_msg), "TLE initialization error: %d", sat_res->satrec.error);
        enif_release_resource(sat_res);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, error_msg, ERL_NIF_LATIN1));
    }
    
    sat_res->initialized = true;
    
    // Create reference to the resource
    ERL_NIF_TERM sat_term = enif_make_resource(env, sat_res);
    enif_release_resource(sat_res); // Release our reference, Erlang now owns it
    
    // Return {:ok, satellite_ref}
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), sat_term);
}

// Propagate an initialized satellite to a specific time
static ERL_NIF_TERM propagate_satellite(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    SatelliteResource* sat_res;
    double tsince;
    
    // Validate input arguments: satellite reference and time
    if (argc != 2 ||
        !enif_get_resource(env, argv[0], satellite_resource_type, (void**)&sat_res) ||
        !enif_get_double(env, argv[1], &tsince)) {
        return enif_make_badarg(env);
    }
    
    // Check if satellite is initialized
    if (!sat_res->initialized) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Satellite not initialized", ERL_NIF_LATIN1));
    }
    
    // Make a copy of the satellite record for thread safety
    elsetrec local_satrec = sat_res->satrec;
    
    // Propagate to specified time
    double r[3], v[3]; // Position (km) and velocity (km/s) in TEME
    bool result = SGP4Funcs::sgp4(local_satrec, tsince, r, v);
    
    if (!result || local_satrec.error != 0) {
        char error_msg[50];
        snprintf(error_msg, sizeof(error_msg), "Propagation error: %d", local_satrec.error);
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

// Get satellite info (for debugging/testing)
static ERL_NIF_TERM get_satellite_info(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    SatelliteResource* sat_res;
    
    if (argc != 1 ||
        !enif_get_resource(env, argv[0], satellite_resource_type, (void**)&sat_res)) {
        return enif_make_badarg(env);
    }
    
    if (!sat_res->initialized) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Satellite not initialized", ERL_NIF_LATIN1));
    }
    
    // Return satellite info as a map
    ERL_NIF_TERM keys[] = {
        enif_make_atom(env, "satnum"),
        enif_make_atom(env, "epochyr"),
        enif_make_atom(env, "epochdays"),
        enif_make_atom(env, "ecco"),
        enif_make_atom(env, "inclo"),
        enif_make_atom(env, "nodeo"),
        enif_make_atom(env, "argpo"),
        enif_make_atom(env, "mo"),
        enif_make_atom(env, "no_kozai"),
        enif_make_atom(env, "line1"),
        enif_make_atom(env, "line2")
    };
    
    ERL_NIF_TERM values[] = {
        enif_make_string(env, sat_res->satrec.satnum, ERL_NIF_LATIN1),
        enif_make_int(env, sat_res->satrec.epochyr),
        enif_make_double(env, sat_res->satrec.epochdays),
        enif_make_double(env, sat_res->satrec.ecco),
        enif_make_double(env, sat_res->satrec.inclo),
        enif_make_double(env, sat_res->satrec.nodeo),
        enif_make_double(env, sat_res->satrec.argpo),
        enif_make_double(env, sat_res->satrec.mo),
        enif_make_double(env, sat_res->satrec.no_kozai),
        enif_make_string(env, sat_res->line1.c_str(), ERL_NIF_LATIN1),
        enif_make_string(env, sat_res->line2.c_str(), ERL_NIF_LATIN1)
    };
    
    ERL_NIF_TERM map;
    enif_make_map_from_arrays(env, keys, values, 11, &map);
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), map);
}

// Resource destructor
static void satellite_destructor(ErlNifEnv* env, void* obj) {
    SatelliteResource* sat_res = (SatelliteResource*)obj;
    sat_res->~SatelliteResource();
}

// NIF initialization
static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
    satellite_resource_type = enif_open_resource_type(env, NULL, "satellite",
                                                      satellite_destructor,
                                                      ERL_NIF_RT_CREATE, NULL);
    if (satellite_resource_type == NULL) {
        return -1;
    }
    return 0;
}

static ErlNifFunc nif_funcs[] = {
    // Legacy/batch API
    {"propagate_tle", 3, propagate_tle},
    {"propagate_tle_batch", 3, propagate_tle_batch},
    
    // Stateful API
    {"init_satellite", 2, init_satellite},
    {"propagate_satellite", 2, propagate_satellite},
    {"get_satellite_info", 1, get_satellite_info}
};

ERL_NIF_INIT(Elixir.SGP4NIF, nif_funcs, load, NULL, NULL, NULL)
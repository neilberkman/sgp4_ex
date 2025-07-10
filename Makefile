# Basic variables
CC = gcc
CXX = g++
CFLAGS = -fPIC -Wall -O3 -march=native -ffloat-store
CXXFLAGS = -fPIC -Wall -O3 -march=native -ffloat-store -std=c++11

# Check for OpenMP support
HAS_OPENMP = false

ifeq ($(shell uname -s), Darwin)
    # On macOS, check for various gcc versions from Homebrew
    GCC_VERSIONS := 15 14 13 12 11
    GCC_FOUND := $(foreach ver,$(GCC_VERSIONS),$(shell command -v g++-$(ver) 2> /dev/null))
    
    ifneq ($(strip $(GCC_FOUND)),)
        # Use the first gcc found
        CXX := $(word 1,$(GCC_FOUND))
        CXXFLAGS += -fopenmp
        LDFLAGS = -shared -undefined dynamic_lookup -fopenmp
        HAS_OPENMP = true
        $(info Using $(CXX) with OpenMP support for parallel batch operations)
    else
        # Fall back to clang without OpenMP
        LDFLAGS = -shared -undefined dynamic_lookup
        $(warning ========================================================================)
        $(warning OpenMP not available on macOS. Batch operations will run sequentially.)
        $(warning Install gcc from Homebrew for 4-8x speedup on batch operations:)
        $(warning   brew install gcc)
        $(warning ========================================================================)
    endif
else
    # Linux - check if compiler supports OpenMP
    OPENMP_TEST := $(shell echo | $(CXX) -fopenmp -x c++ -E - 2>/dev/null && echo "yes")
    ifeq ($(OPENMP_TEST), yes)
        CXXFLAGS += -fopenmp
        LDFLAGS = -shared -fopenmp
        HAS_OPENMP = true
        $(info OpenMP support detected for parallel batch operations)
    else
        LDFLAGS = -shared
        $(warning OpenMP not available. Batch operations will run sequentially.)
    endif
endif

# Pass OpenMP availability to C++ code
ifeq ($(HAS_OPENMP), true)
    CXXFLAGS += -D_OPENMP
endif

# Erlang paths - dynamically find the correct include path
ERL_INCLUDE_PATH = $(shell erl -eval 'io:format("~s~n", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)

# Output directories
PRIV_DIR = priv
BUILD_DIR = build

# Create directories if they don't exist
$(shell mkdir -p $(PRIV_DIR) $(BUILD_DIR))

# Source files - single NIF with all functions
CPP_SRC = cpp_src/SGP4.cpp cpp_src/sgp4_nif.cpp
CPP_OBJ = $(BUILD_DIR)/SGP4.o $(BUILD_DIR)/sgp4_nif.o

# Target shared object
TARGET_SO = $(PRIV_DIR)/sgp4_nif.so

# Compile flags with includes
CXXFLAGS += -I$(ERL_INCLUDE_PATH) -Icpp_src

# Rules
all: $(TARGET_SO)

# Object files
$(BUILD_DIR)/SGP4.o: cpp_src/SGP4.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/sgp4_nif.o: cpp_src/sgp4_nif.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Link target
$(TARGET_SO): $(CPP_OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^

clean:
	rm -rf $(BUILD_DIR)/* $(TARGET_SO)

.PHONY: all clean
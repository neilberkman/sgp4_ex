# Use versioned GCC if available, fall back to system default.
# Override with: make CC=clang CXX=clang++
CC := $(shell command -v gcc-15 2>/dev/null || command -v gcc-14 2>/dev/null || echo cc)
CXX := $(shell command -v g++-15 2>/dev/null || command -v g++-14 2>/dev/null || echo c++)
CFLAGS = -fPIC -Wall -O2
CXXFLAGS = -fPIC -Wall -O2 -std=c++11
ifeq ($(shell uname -s), Darwin)
LDFLAGS = -shared -undefined dynamic_lookup
else
LDFLAGS = -shared
endif

# Erlang paths - dynamically find the correct include path
ERL_INCLUDE_PATH = $(shell erl -eval 'io:format("~s~n", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)

# Output directories
PRIV_DIR = priv
BUILD_DIR = build

# Create directories if they don't exist
$(shell mkdir -p $(PRIV_DIR) $(BUILD_DIR))

# Source files
CPP_SRC = $(wildcard cpp_src/*.cpp)
CPP_OBJ = $(CPP_SRC:cpp_src/%.cpp=$(BUILD_DIR)/%.o)

# mat3.c is compiled with FMA enabled (via -ffp-contract=fast) so the
# matrix-vector multiply matches numpy's vectorized rounding behavior.
C_SRC = cpp_src/mat3.c
C_OBJ = $(C_SRC:cpp_src/%.c=$(BUILD_DIR)/%.o)
MAT3_CFLAGS = $(CFLAGS) -ffp-contract=fast

# Compile flags with includes
CXXFLAGS += -I$(ERL_INCLUDE_PATH) -Icpp_src
CFLAGS += -I$(ERL_INCLUDE_PATH) -Icpp_src

# Target shared object
TARGET_SO = $(PRIV_DIR)/sgp4_nif.so

# Rules
all: $(TARGET_SO)

$(BUILD_DIR)/%.o: cpp_src/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/mat3.o: cpp_src/mat3.c
	$(CC) $(MAT3_CFLAGS) -c $< -o $@

$(TARGET_SO): $(CPP_OBJ) $(C_OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^

clean:
	rm -rf $(BUILD_DIR)/* $(TARGET_SO)

.PHONY: all clean

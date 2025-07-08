# Basic variables
CC = gcc
CXX = g++
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

# Target shared object
TARGET_SO = $(PRIV_DIR)/sgp4_nif.so

# Compile flags with includes
CXXFLAGS += -I$(ERL_INCLUDE_PATH) -Icpp_src

# Rules
all: $(TARGET_SO)

$(BUILD_DIR)/%.o: cpp_src/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(TARGET_SO): $(CPP_OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^

clean:
	rm -rf $(BUILD_DIR)/* $(TARGET_SO)

.PHONY: all clean
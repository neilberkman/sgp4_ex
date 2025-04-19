ERTS_INCLUDE_DIR ?= $(shell erl -eval 'io:format("~s~n", [code:lib_dir(erts, include)])' -s init stop -noshell)
CFLAGS = -fPIC -I$(ERTS_INCLUDE_DIR) -I./c_src -Wall -O2
LDFLAGS = -shared
CXX = g++

SOURCES = cpp_src/sgp4_nif.cpp cpp_src/SGP4.cpp
OBJECTS = $(patsubst cpp_src/%.cpp,build/%.o,$(SOURCES))
TARGET = sgp4_nif.so

all: $(TARGET)

$(TARGET): $(OBJECTS)
	@mkdir -p priv
	$(CXX) $(OBJECTS) -o $@ $(LDFLAGS)

build/%.o: cpp_src/%.cpp
	@mkdir -p build
	$(CXX) $(CFLAGS) -c $< -o $@

clean:
	rm -rf build priv

.PHONY: all clean
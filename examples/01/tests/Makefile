PROJECT = TutorialMyMakefile
TARGET = HelloWorld01-UnitTests
DESCRIPTION = Unit Tests for the Hello World project

# Compile useing coverage
USE_COVERAGE = 1

# Activate cassert
BUILD_TYPE = debug

# foo.o is compiled object of ../src/foo.c
OBJS += unit-tests.o

# For allowing #include "src/foo.cpp"
INCLUDES += -I..

.PHONY: all
all: $(TARGET)

P := ../../..
M := $(P)
include $(M)/MyMakefile

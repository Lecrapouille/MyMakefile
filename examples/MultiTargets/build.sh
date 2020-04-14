#! /bin/bash
. .makefile/Maker.sh

####################################################
PROJECT=SimTaDyn
TARGET=SimForth
DESCRIPTION="A basic Forth1 for SimTaDyn"
COMPIL_FLAGS="-W -Wall -Wextra"
BUILD_TYPE=debug
BUILD=build
OBJS=main.o
BUILD_EXECUTABLE

####################################################
PROJECT=SimTaDyn
TARGET=SimTaDyn
DESCRIPTION="SimTaDyn"
COMPIL_FLAGS="-W -Wall -Wextra"
BUILD_TYPE=debug
BUILD=build
OBJS=main.o
BUILD_EXECUTABLE

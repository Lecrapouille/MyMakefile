PROJECT = TutorialMyMakefile
TARGET = HelloWorld00
DESCRIPTION = Tutorial 00 for MyMakefile: Hello World project
BUILD_TYPE = release

OBJS += main.o

DEFINES += -DFOO -UBAR
VPATH += src
INCLUDES += -I/src

.PHONY: all
all: $(TARGET)

P := ../..
M := $(P)
include $(M)/MyMakefile

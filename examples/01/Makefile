PROJECT = TutorialMyMakefile
TARGET = HelloWorld01
DESCRIPTION = Tutorial 01 for MyMakefile: Hello World project with unit tests
BUILD_TYPE = release

OBJS += foo.o main.o

VPATH += src
INCLUDES += -I/src

.PHONY: all
all: $(TARGET)

.PHONY: check
check:
	@$(call print-simple,"Compiling unit tests")
	@$(MAKE) -C tests coverage

.PHONY: veryclean
veryclean: clean
	@(cd tests && $(MAKE) -s clean)

P := ../..
M := $(P)
include $(M)/MyMakefile

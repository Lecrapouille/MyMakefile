# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
#
# Colored messages, in the style of MyMakefile 2:
#   *** Compiling C++: OpenGlassBox <= src/City.cpp
#   *** Linking: OpenGlassBox-demo => build/linux-gcc-normal/bin/OpenGlassBox-demo
#
# Colors are on when make writes to a terminal, off otherwise (CI logs, pipes)
# and with cmd.exe. COLORS=1 or COLORS=0 forces them; NO_COLOR (no-color.org)
# turns them off.

ifneq ($(filter 0 no off false,$(COLORS)),)
    _mm_colors :=
else ifneq ($(COLORS),)
    _mm_colors := 1
else ifneq ($(NO_COLOR),)
    _mm_colors :=
else ifeq ($(HOST_SHELL),cmd)
    _mm_colors :=
else
    _mm_colors := $(if $(MAKE_TERMOUT),1)
endif

# The escape character itself, since make has no way to write it.
_mm_esc := 

ifneq ($(_mm_colors),)
    COLOR_DEFAULT := $(_mm_esc)[00m
    RED := $(_mm_esc)[31m
    GREEN := $(_mm_esc)[32m
    YELLOW := $(_mm_esc)[33m
    BLUE := $(_mm_esc)[34m
    PURPLE := $(_mm_esc)[35m
    CYAN := $(_mm_esc)[36m
    COLOR_INFO := $(_mm_esc)[42m
    COLOR_WARNING := $(_mm_esc)[43m
    COLOR_ERROR := $(_mm_esc)[41m
else
    COLOR_DEFAULT :=
    RED :=
    GREEN :=
    YELLOW :=
    BLUE :=
    PURPLE :=
    CYAN :=
    COLOR_INFO :=
    COLOR_WARNING :=
    COLOR_ERROR :=
endif

###############################################################################
# Messages printed by make itself ($(info)): no process is started. In a
# recipe they come out when the recipe starts, before its first command.
###############################################################################

# $1: action, $2: target, $3: file read ($(call _mm_say_from,...)) or written
_mm_say_simple = $(info $(PURPLE)*** $1: $(CYAN)$2$(COLOR_DEFAULT)$3)
_mm_say_from = $(info $(PURPLE)*** $1: $(CYAN)$2$(COLOR_DEFAULT) <= $(YELLOW)$3$(COLOR_DEFAULT))
_mm_say_to = $(info $(PURPLE)*** $1: $(CYAN)$2$(COLOR_DEFAULT) => $(YELLOW)$3$(COLOR_DEFAULT))
_mm_say_ok = $(info $(GREEN)*** $1$(COLOR_DEFAULT))
_mm_say_warning = $(info $(COLOR_WARNING)!!! $1 !!!$(COLOR_DEFAULT))
_mm_fail = $(error $(RED)MyMakefile: $1$(COLOR_DEFAULT))

###############################################################################
# The same, as a command: for a message between two commands of a recipe.
###############################################################################

ifeq ($(HOST_SHELL),cmd)
    _mm_echo = echo $(subst >,^>,$(subst <,^<,$(subst |,^|,$(subst &,^&,$1))))
else
    _mm_echo = echo '$(subst ','\'',$1)'
endif
_mm_echo_simple = $(call _mm_echo,$(PURPLE)*** $1: $(CYAN)$2$(COLOR_DEFAULT)$3)

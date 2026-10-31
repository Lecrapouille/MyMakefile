# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat

TARGETS += bar
bar.TYPE := library
bar.SOURCES := *.cpp
bar.PUBLIC_INCLUDES := ../../include

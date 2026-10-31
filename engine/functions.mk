###############################################################################
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
###############################################################################
#
# Pure GNU Make functions: none of them starts a shell, so that they behave
# the same with sh, bash and cmd.exe.
#
# Naming of MyMakefile: functions called with $(call ...) are written in lower
# case with dashes (rwildcard, print-to); macros (define ... endef: templates
# of rules and of files) and variables in upper case (TARGET_RULES, BUILD).

EMPTY :=
SPACE := $(EMPTY) $(EMPTY)
COMMA := ,
OPEN_PAREN := (
define NEWLINE


endef

###############################################################################
# Strings
###############################################################################

LETTERS := a b c d e f g h i j k l m n o p q r s t u v w x y z \
           A B C D E F G H I J K L M N O P Q R S T U V W X Y Z

lower = $(subst A,a,$(subst B,b,$(subst C,c,$(subst D,d,$(subst E,e,$(subst \
F,f,$(subst G,g,$(subst H,h,$(subst I,i,$(subst J,j,$(subst K,k,$(subst \
L,l,$(subst M,m,$(subst N,n,$(subst O,o,$(subst P,p,$(subst Q,q,$(subst \
R,r,$(subst S,s,$(subst T,t,$(subst U,u,$(subst V,v,$(subst W,w,$(subst \
X,x,$(subst Y,y,$(subst Z,z,$1))))))))))))))))))))))))))

upper = $(subst a,A,$(subst b,B,$(subst c,C,$(subst d,D,$(subst e,E,$(subst \
f,F,$(subst g,G,$(subst h,H,$(subst i,I,$(subst j,J,$(subst k,K,$(subst \
l,L,$(subst m,M,$(subst n,N,$(subst o,O,$(subst p,P,$(subst q,Q,$(subst \
r,R,$(subst s,S,$(subst t,T,$(subst u,U,$(subst v,V,$(subst w,W,$(subst \
x,X,$(subst y,Y,$(subst z,Z,$1))))))))))))))))))))))))))

# Identifier usable as a C macro: MY_PROJECT_V1
c-identifier = $(call upper,$(subst -,_,$(subst .,_,$(subst /,_,$1))))

# Field $1 of a dotted version $2: $(call version-field,2,1.4.7) -> 4
version-field = $(or $(word $1,$(subst ., ,$2)),0)

###############################################################################
# Numbers: $(call ge,A,B) is not empty when A >= B (integers in 1..200)
###############################################################################

NUMBERS := 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 \
25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 \
51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 \
77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 \
102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 \
121 122 123 124 125 126 127 128 129 130 131 132 133 134 135 136 137 138 139 \
140 141 142 143 144 145 146 147 148 149 150 151 152 153 154 155 156 157 158 \
159 160 161 162 163 164 165 166 167 168 169 170 171 172 173 174 175 176 177 \
178 179 180 181 182 183 184 185 186 187 188 189 190 191 192 193 194 195 196 \
197 198 199 200

ge = $(if $(filter $1,$(NUMBERS)),$(if $(filter $2,$(wordlist 1,$1,$(NUMBERS))),1))

###############################################################################
# Lists
###############################################################################

reverse = $(strip $(if $1,$(call reverse,$(wordlist 2,$(words $1),$1)) $(firstword $1)))

# Remove duplicates, keeping the first occurrence (sort would reorder).
uniq = $(strip $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1))))

# Remove duplicates, keeping the last occurrence: the link order of libraries.
uniq-last = $(call reverse,$(call uniq,$(call reverse,$1)))

###############################################################################
# Paths. A project path is relative to the root of the project ($(CURDIR)) and
# never contains '..'; a path outside of the project stays absolute.
###############################################################################

is-absolute = $(or $(filter /%,$1),$(filter $(addsuffix :%,$(LETTERS)),$1))
normalize-one = $(if $(filter $(CURDIR),$1),.,$(patsubst $(CURDIR)/%,%,$1))
normalize = $(foreach p,$1,$(call normalize-one,$(abspath $p)))

# Paths $1 written relatively to the directory $2 (empty or ending with '/').
resolve = $(call normalize,$(foreach p,$1,$(if $(call is-absolute,$p),$p,$2$p)))

# Recursive wildcard, as in MyMakefile 2: $(call rwildcard,src,*.cpp)
rwildcard = $(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))

# Glob of one pattern: 'src/**/*.cpp' recursive, 'src/*.cpp' flat, anything
# else is taken as a file name, even if it does not exist yet.
rglob = $(call rwildcard,$(or $(patsubst %/,%,$(subst |,,$(firstword $1))),.),$(patsubst /%,%,$(lastword $1)))
glob-one = $(if $(findstring **,$1),$(call rglob,$(subst **,| ,$1)),$(if $(call is-pattern,$1),$(sort $(wildcard $1)),$1))
is-pattern = $(or $(findstring *,$1),$(findstring ?,$1))

# Patterns $1 written relatively to the directory $2, expanded and normalized.
glob = $(call normalize,$(foreach p,$1,$(call glob-one,$(if $(call is-absolute,$p),$p,$2$p))))

# '..' for each directory of the relative path $1: lib/pkgconfig -> ../..
up-path = $(subst $(SPACE),/,$(foreach d,$(subst /, ,$1),..))

###############################################################################
# Stamps: plain text files, read with $(file <) and never included, since make
# would not see a file created after it looked for it.
###############################################################################

read-stamp = $(file <$1)
write-stamp = $(shell $(call make-dir,$(patsubst %/,%,$(dir $1))))$(file >$1,$2)

###############################################################################
# An executable of the PATH, found without a shell: $(call which,ccache)
###############################################################################

which = $(firstword $(wildcard $(addsuffix /$1$(HOST_EXE),$(subst $(PATH_SEP), ,$(subst \,/,$(PATH))))))

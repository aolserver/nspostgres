#
# $Header$
#
# nspostgres --
#
#      PostgreSQL Database Driver for AOLserver/OpenNSD
#

ifdef INST
    NSHOME ?= $(INST)
else
    NSHOME ?= ../aolserver
endif

#
# Manage to find PostgreSQL components in the system, or where you specify
#
ifeq ($(POSTGRES),LSB)
    PGLIB = /usr/lib
    PGINC = /usr
else
    PGLIB = $(POSTGRES)/lib
    PGINC = $(POSTGRES)
endif
 
#
# Module name
# 
MOD       = nspostgres.so

#
# Objects to build
#
OBJS      = nspostgres.o

#
# Header files for this module
# 
HDRS      = nspostgres.h

#
# Libraries required by this module
#
MODLIBS   = -L$(PGLIB) -lpq
CFLAGS   += -DBIND_EMULATION -I$(PGINC)/include

#
# ACS users should set ACS=1
#
ifdef ACS
    CFLAGS   +=  -DFOR_ACS_USE
endif

include  $(NSHOME)/include/Makefile.module

nspostgres.c: check-env

.PHONY: check-env
check-env:
	@if [ "$(POSTGRES)" = "" ]; then \
	    echo "** "; \
	    echo "** POSTGRES variable not set."; \
	    echo "** nspostgres.so will not be built."; \
	    echo "** "; \
	    echo "** Usage: make POSTGRES=/path/to/postgresql"; \
	    echo "**        make POSTGRES=LSB"; \
	    echo "** Usage: make install POSTGRES=/path/to/postgresql INST=/path/to/aolserver"; \
	    echo "**        make install POSTGRES=LSB INST=/path/to/aolserver"; \
	    echo "** "; \
	    echo "** OpenACS users should also set ACS=1"; \
	    echo "** "; \
	    exit 1; \
	fi


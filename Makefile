# Copyright 1994-1996 America Online, Inc. 

#
# Makefile for nspostgres.so module.
#
# -DFOR_ACS_USE required for ACS/pg use!

# To compile the postgres.so loadable AOLserver module, edit the NSHOME
# variable (below) to the directory where the AOLserver files are located,
# edit the PGLIB and PGINC variables to the directories where the PostgreSQL
# libraries and includes are (the RPM installation is different from default), 
# and uncomment the CC, COPTS, and LDFLAGS variables for your platform and
# compiler.  Then type "make install" to compile and install the module
# in the AOLserver bin directory.  To have the AOLserver load the
# postgres.so module at runtime, you will need to add the following
# entry in the [ns\server\godzilla\modules] section of your nsd.ini file
# (where 'godzilla' is the name of a virtual server):
#
#	nspostgres=nspostgres.so
#
#
# NOTE:  This code is unsupported and for example purposes only.

ifdef INST
NSHOME ?= $(INST)
else
NSHOME ?= ../aolserver
endif

PGLIB       = $(POSTGRES)/lib
PGINC       = $(POSTGRES)/include

MOD      = nspostgres.so
OBJS        = nspostgres.o
EXTRA_OBJS  = $(PGLIB)/libpq.so
HDRS        =

CC=gcc
COPTS=-fPIC -shared -I$(PGINC) -I$(NSHOME)/include -I-/usr/include
#CFLAGS=-DFOR_ACS_USE -DBIND_EMULATION -I$(NSHOME)/include $(COPTS)
CFLAGS= -DBIND_EMULATION -I$(NSHOME)/include $(COPTS)
LDFLAGS=-shared -I$(PGINC) -I$(NSHOME)/include -I-/usr/include

include  $(NSHOME)/include/Makefile.module

#all: $(MOD)
#
#$(MOD): $(OBJS)
	#gcc $(LDFLAGS) -o $(MOD) $(OBJS) $(EXTRA_OBJS)
#
#install: $(MOD)
#	cp $(MOD) $(INSTALL)/bin/
#	chmod +x $(INSTALL)/bin/$(MOD)
#
#clean:
#	rm -f *.o *.so

# Extra stuff to make sure that POSTGRES is set.

nspostgres.c: check-env

.PHONY: check-env
check-env:
	@if [ "$(POSTGRES)" = "" ]; then \
	    echo "** "; \
	    echo "** POSTGRES variable not set."; \
	    echo "** nspostgres.so will not be built."; \
	    echo "** "; \
	    exit 1; \
	fi

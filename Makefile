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

MOD       = nspostgres.so
OBJS      = nspostgres.o
HDRS      =
MODLIBS   = -L$(POSTGRES)/lib -lpq
CFLAGS   += -DBIND_EMULATION -I$(POSTGRES)/include

include  $(NSHOME)/include/Makefile.module

nspostgres.c: check-env

.PHONY: check-env
check-env:
	@if [ "$(POSTGRES)" = "" ]; then \
	    echo "** "; \
	    echo "** POSTGRES variable not set."; \
	    echo "** nspostgres.so will not be built."; \
	    echo "** Usage: make POSTGRES=/path/to/postgresql"; \
	    echo "** Usage: make install POSTGRES=/path/to/postgresql INST=/path/to/aolserver"; \
	    echo "** "; \
	    exit 1; \
	fi



### OLD CRUFT:

#LDFLAGS=-shared -I$(PGINC) -I$(NSHOME)/include -I-/usr/include
#EXTRA_OBJS  = $(PGLIB)/libpq.so
#CC=gcc
#COPTS=-fPIC -shared -I$(PGINC) -I$(NSHOME)/include -I-/usr/include
#CFLAGS=-DFOR_ACS_USE -DBIND_EMULATION -I$(NSHOME)/include $(COPTS)
# old: CFLAGS  += -DBIND_EMULATION -I$(NSHOME)/include $(COPTS)

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
# -DFOR_ACS_USE required for ACS/pg use!


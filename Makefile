#
# The contents of this file are subject to the AOLserver Public License
# Version 1.1 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://aolserver.com.
#
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
#
# The Original Code is AOLserver Code and related documentation
# distributed by AOL.
#
# The Initial Developer of the Original Code is America Online,
# Inc. Portions created by AOL are Copyright (C) 1999 America Online,
# Inc. All Rights Reserved.
#
# Alternatively, the contents of this file may be used under the terms
# of the GNU General Public License (the "GPL"), in which case the
# provisions of GPL are applicable instead of those above.  If you wish
# to allow use of your version of this file only under the terms of the
# GPL and not to allow others to use your version of this file under the
# License, indicate your decision by deleting the provisions above and
# replace them with the notice and other provisions required by the GPL.
# If you do not delete the provisions above, a recipient may use your
# version of this file under either the License or the GPL.
#
# Copyright (C) 2001,2002 Scott S. Goodwin
#
# $Header$
#
# nspostgres --
#
#      PostgreSQL Database Driver for AOLserver
#

#
# Version number used in release tags. Valid VERs are "1.1c", "2.1", 
# "2.2beta7". VER "1.1c" will be translated into "v1_1c" by this Makefile.
#
VER_ = $(subst .,_,$(VER))

# if POSTGRES does not receive a value, print message showing choices.
# 
# the best choice for POSTGRES should be PG_CONFIG, but there has to be
# a way to show the choices: so do NOT set POSTGRES here.

#
# Manage to find PostgreSQL components in the system, or where you specify
#
ifndef PG_CONFIG
    PG_CONFIG = pg_config
endif

ifeq ($(POSTGRES),LSB)
    PGLIB = /usr/lib
    PGINC = /usr/include/pgsql
else
    ifeq ($(POSTGRES),PG_CONFIG)
        PGLIB = $(shell $(PG_CONFIG) --libdir)
        PGINC = $(shell $(PG_CONFIG) --includedir)
    else
        ifneq ($(POSTGRES),SEPARATELY)
            PGLIB = $(POSTGRES)/lib
            PGINC = $(POSTGRES)/include
        endif
        # otherwise, it is assumed PGINC and PGLIB set on commandline
    endif
endif
 
#
# Where is AOLserver source?
#
AOLSERVER ?= ../aolserver

#
# Module name
# 
MOD       = nspostgres.so

#
# Objects to build
#
MODOBJS   = nspostgres.o

#
# Header files for this module
# 
HDRS      = nspostgres.h

#
# Libraries required by this module
#
MODLIBS  += -L$(PGLIB) -lpq

#
# If PostgreSQL was compiled with OpenSSL support, you'll need to point the
# OpenSSL installation.
#
ifdef OPENSSL
    MODLIBS += -L$(OPENSSL)/lib -lssl -lcrypto
endif

#
# Compiler flags
#
CFLAGS   += -DBIND_EMULATION -I$(PGINC)

#
# ACS users should set ACS=1
#
ifeq ($(ACS),1)
    CFLAGS   +=  -DFOR_ACS_USE
endif


include  $(AOLSERVER)/include/Makefile.module

#
# Help the poor developer
#
help:
	@echo "**" 
	@echo "** DEVELOPER HELP FOR THIS MODULE"
	@echo "**"
	@echo "** make tag VER=X.Y"
	@echo "**     Tags the module CVS code with the given tag."
	@echo "**     You can tag the CVS copy at any time, but follow the rules."
	@echo "**     VER must be of the form:"
	@echo "**         X.Y"
	@echo "**         X.YbetaN"
	@echo "**     You should browse CVS at SF to find the latest tag."
	@echo "**"
	@echo "** make file-release VER=X.Y"
	@echo "**     Checks out the code for the given tag from CVS."
	@echo "**     The result will be a releaseable tar.gz file of"
	@echo "**     the form: module-X.Y.tar.gz."
	@echo "**"

#
# Tag the code in CVS right now
#
tag:
	@if [ "$$VER" = "" ]; then echo 1>&2 "VER must be set to version number!"; exit 1; fi
	cvs rtag v$(VER_) nspostgres

#
# Create a distribution file release
#
file-release:
	@if [ "$$VER" = "" ]; then echo 1>&2 "VER must be set to version number!"; exit 1; fi
	rm -rf work
	mkdir work
	cd work && cvs -d :pserver:anonymous@cvs.aolserver.sourceforge.net:/cvsroot/aolserver co -r v$(VER_) nspostgres
	mv work/nspostgres work/nspostgres-$(VER)
	(cd work && tar cvf - nspostgres-$(VER)) | gzip -9 > nspostgres-$(VER).tar.gz
	rm -rf work

nspostgres.c: check-env

.PHONY: check-env
check-env:
	@if [ "$(POSTGRES)" = "" ]; then \
	    echo "** "; \
	    echo "** POSTGRES variable not set."; \
	    echo "** nspostgres.so will not be built."; \
	    echo "** "; \
	    echo "** Usage: make POSTGRES=PG_CONFIG"; \
	    echo "**        make POSTGRES=PG_CONFIG PG_CONFIG=/path/to/pg_config"; \
	    echo "**        make POSTGRES=LSB"; \
	    echo "**        make POSTGRES=/path/to/postgresql"; \
	    echo "**        make POSTGRES=SEPARATELY \\"; \
	    echo "               PGLIB=/path/to/libs \\"; \
	    echo "               PGINC=/wheres/the/includes"; \
	    echo "** "; \
	    echo "** Usage: make install POSTGRES=PG_CONFIG"; \
	    echo "**        make install POSTGRES=PG_CONFIG PG_CONFIG=/path/to/pg_config"; \
	    echo "**        make install POSTGRES=LSB"; \
	    echo "**        make install POSTGRES=/path/to/postgresql"; \
	    echo "**        make install POSTGRES=SEPARATELY \\"; \
	    echo "                       PGLIB=/path/to/libs \\"; \
	    echo "                       PGINC=/wheres/the/includes"; \
	    echo "** "; \
	    echo "** if this dir is not at root of aolserver source tree,"; \
	    echo "**   then you need to add INST=/path/to/aolserver--prefix"; \
	    echo "**   and that dir must have aolserver installed in it"; \
	    echo "** "; \
	    echo "** OpenACS users should also set ACS=1"; \
	    echo "** "; \
	    echo "** AOLserver 3.x users should set AS3=1"; \
	    echo "** "; \
	    echo "** If PostgreSQL was compiled with SSL support, you also need:"; \
	    echo "**        OPENSSL=/path/to/openssl"; \
	    echo "** "; \
	    exit 1; \
	fi


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

POSTGRES=/usr/local/pgsql
ifneq ($(shell [ -f $(POSTGRES)/include/libpq-fe.h ] && echo ok),ok)
  POSTGRES = LSB
endif

ifdef INST
  NSHOME ?= $(INST)
else
  ifeq ($(shell [ -f ../include/Makefile.module ] && echo ok),ok)
    NSHOME = ..
    NSBUILD = 1
  else
    NSHOME=/usr/local/aolserver
    ifneq ($(shell [ -f $(NSHOME)/include/Makefile.module ] && echo ok),ok)
      NSHOME = ../aolserver
    endif
  endif
endif

#
# Version number used in release tags. Valid VERs are "1.1c", "2.1", 
# "2.2beta7". VER "1.1c" will be translated into "v1_1c" by this Makefile.
#
VER_ = $(subst .,_,$(VER))

#
# Manage to find PostgreSQL components in the system, or where you specify
#
ifeq ($(POSTGRES),LSB)
    PGLIB = /usr/lib
    PGINC = /usr/include/pgsql
else
    PGLIB = $(POSTGRES)/lib
    PGINC = $(POSTGRES)/include
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

ifndef AS3
    MODLIBS  +=  -lnsdb
endif

#
# If PostgreSQL was compiled with OpenSSL support, you'll need to point the
# OpenSSL installation.
#
ifdef OPENSSL
    MODLIBS += -L$(OPENSSL)/lib -lssl -lcrypto
endif

CFLAGS   += -DBIND_EMULATION -I$(PGINC)

#
# ACS users should set ACS=1
#
ifdef ACS
ifeq ($(ACS),1)
    CFLAGS   +=  -DFOR_ACS_USE
endif
endif

include  $(NSHOME)/include/Makefile.module

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
	    echo "** Usage: make POSTGRES=/path/to/postgresql"; \
	    echo "**        make POSTGRES=LSB"; \
	    echo "** "; \
	    echo "** Usage: make install POSTGRES=/path/to/postgresql INST=/path/to/aolserver"; \
	    echo "**        make install POSTGRES=LSB INST=/path/to/aolserver"; \
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


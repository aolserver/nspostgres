/*
 * The contents of this file are subject to the AOLserver Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://aolserver.lcs.mit.edu/.
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.
 *
 * The Original Code is AOLserver Code and related documentation
 * distributed by AOL.
 *
 * The Initial Developer of the Original Code is America Online,
 * Inc. Portions created by AOL are Copyright (C) 1999 America Online,
 * Inc. All Rights Reserved.
 *
 * Alternatively, the contents of this file may be used under the terms
 * of the GNU General Public License (the "GPL"), in which case the
 * provisions of GPL are applicable instead of those above.  If you wish
 * to allow use of your version of this file only under the terms of the
 * GPL and not to allow others to use your version of this file under the
 * License, indicate your decision by deleting the provisions above and
 * replace them with the notice and other provisions required by the GPL.
 * If you do not delete the provisions above, a recipient may use your
 * version of this file under either the License or the GPL.
 *
 * $Header$
 */

/* NOTE: for ACS/pg use, you need to define FOR_ACS_USE! */

#include "ns.h"
/* If we're under AOLserver 3, we don't need some things.
   the constant NS_AOLSERVER_3_PLUS is defined in AOLserver 3 and greater's
   ns.h */

#ifndef NS_AOLSERVER_3_PLUS

#include "nsdb.h"
#include "nstcl.h"
#endif /* NS_AOLSERVER_3_PLUS */

#include "libpq-fe.h"
#include <string.h>
#include <stdio.h>
#include <ctype.h>

/*-

What is this?
------------

This module implements a simple AOLserver database services driver.  A
database driver is a module which interfaces between the AOLserver
database-independent nsdb module and the API of a particular DBMS.  A
database driver's job is to open connections, send SQL statements, and
translate the results into the form used by nsdb.  In this case, the
driver is for the PostgreSQL ORDBMS from The PostgreSQL Global Development
Group.  This is the official driver for the ACS-PG project. PostgreSQL can be
downloaded and installed on most Unix systems.  To use this driver, you
must have PostgreSQL installed on your system.  For more information on
PostgreSQL or to download the code, open:

        http://www.postgresql.org


How does it work?
----------------

Driver modules look much like ordinary AOLserver modules but are
loaded differently.  Instead of being listed with other modules in the
[ns\server\<server-name>\modules] configuration section, a database
driver is listed in the [ns\db\drivers] section and nsdb does
the loading.  The database driver initialization function normally does
little more than call the nsdb Ns_DbRegisterDriver() function with an
array of pointers to functions.  The functions are then later used by
nsdb to open database connections and send and process queries.  This
architecture is much like ODBC on Windows.  In addition to open,
select, and getrow functions, the driver also provides system catalog
functions and a function for initializing a virtual server.  The
virtual server initialization function is called each time nsdb is
loaded into a virtual server.  In this case, the server initialization
function, Ns_PgServerInit, adds the "ns_pg" Tcl command to the server's
Tcl interpreters which can be used to fetch information about an active
PostgreSQL connection in a Tcl script.

Don Baccus (DRB) added the following improvements in December, 1999:

1. When a handle's returned to the pool and the handle's in
   transaction mode, the driver rolls back the transaction.

2. Reopens crashed backends, retrying query if told to by postmaster.

3. ns_db ntuples now returns the number of tuples affected by "insert",
   "update", and "delete" queries (only worked for select before).

4. Supports the following, assuming you've named your driver "postgres" in
   your .ini file:

   [ns/db/driver/postgres]
   datestyle=iso

   (or any legal Postgres datestyle)

5. The driver's name's been changed from "Postgre95" to "PostgreSQL", the
   current official name of the database software.

*/

/* Added reimplementation of ns_column and ns_table commands -- adapted
   the code in the ArsDigita Oracle driver to work in the PostgreSQL driver's
   skeleton.  Will revisit this implementation for cleanup once functionality
   fully verified.  Lamar Owen <lamar.owen@wgcr.org> Feb 6, 2000. */

/* Merge with AOLserver 3.0rc1's nspostgres.c -- more error checking from
   Jan Wieck.

   Also, changed behavior: if the datestyle parameter is not set in config
   file, set it to be 'iso' by default -- it was not getting correctly set.

   Wrapped ACS stuff inside FOR_ACS_USE #ifdef's.

   3-21-2000 lamar.owen@wgcr.org */

/* 2000-03-28: added check for the existence of the PGDATESTYLE envvar
   and do no setting of datestyle if it exists.  lamar.owen@wgcr.org */

/* 2000-03-28: take two: make datestyle parameter override envvar, and make 
   the default go away. LRO */

/* 2000-05-04: Added blob_select_file command.  Needed an inverse to
   blob_dml_file to support porting of webmail. danw@rtp.ericsson.se*/

/* 2000-12-30: Added bind variable emulation to support acs 4.0 porting.
   dcwickstrom@earthlink.net*/

/* 2001-03-??: Added automatic quoting of emulated bind variables in order
   to make it compatible with the analogous routine in the Oracle driver.
   dhogaza@pacifier.com*/

/* 2001-04-14: Added Henry Minsky's patch which echoes changes in the
   Oracle driver to stream blob data directly to the connection 
   rather than first spool to a temp file.  Since the call to return
   the file to the user doesn't return until after the operation is
   complete, spooling was a waste of time and resource.
   dhogaza@pacifier.com*/

/* Contributors to this file include:

	Don Baccus		<dhogaza@pacifier.com>
	Lamar Owen		<lamar.owen@wgcr.org>
	Jan Wieck		<wieck@debis.com>
	Keith Pasket		(SDL/USU)
	Scott Cannon, Jr.	(SDL/USU)
        Dan Wickstrom           <danw@rtp.ericsson.se>

	Original example driver by Jim Davidson */

#define DRIVER_NAME             "PostgreSQL"
#define OID_QUOTED_STRING       " oid = '"
#define STRING_BUF_LEN          256

#ifndef FALSE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE 1
#endif

static void 	Ns_PgUnQuoteOidString(Ns_DString *sql);
static char    *Ns_PgName(Ns_DbHandle *handle);
static char    *Ns_PgDbType(Ns_DbHandle *handle);
static int      Ns_PgOpenDb(Ns_DbHandle *dbhandle);
static int      Ns_PgCloseDb(Ns_DbHandle *dbhandle);
static int      Ns_PgGetRow(Ns_DbHandle *handle, Ns_Set *row);
static int      Ns_PgFlush(Ns_DbHandle *handle);

/* Clunky construct follows :-) We want these statics for either AS 2.3
   OR for ACS/pg under AS3 -- plain AS3 doesn't get these */

/* Hack out the extended_table_info stuff if AOLserver 3, and add in our
   driver's reimplement of ns_table and ns_column */

#ifdef NS_AOLSERVER_3_PLUS
#ifdef FOR_ACS_USE

/* So that we don't have to do this clunky thing again, set a define */
#define NOT_AS3_PLAIN

/* A linked list to use when parsing SQL. */

typedef struct _string_list_elt {
  char *string;
  struct _string_list_elt *next;
} string_list_elt_t;


static Ns_DbTableInfo *Ns_PgGetTableInfo(Ns_DbHandle *handle, char *table);
static char    *Ns_PgTableList(Ns_DString *pds, Ns_DbHandle *handle, int includesystem);

static int pg_column_command (ClientData dummy, Tcl_Interp *interp, 
			       int argc, char *argv[]);
static int pg_table_command (ClientData dummy, Tcl_Interp *interp, 
			       int argc, char *argv[]);

static Ns_DbTableInfo *Ns_DbNewTableInfo (char *table);
static void Ns_DbFreeTableInfo (Ns_DbTableInfo *tinfo);
static void Ns_DbAddColumnInfo (Ns_DbTableInfo *tinfo, Ns_Set *column_info);
static int Ns_DbColumnIndex (Ns_DbTableInfo *tinfo, char *name);

#endif /* FOR_ACS_USE */

/* PLAIN AS 3! */
#define AS3_PLAIN  /* that is, AS3 without the ACS extensions */

#else /* NS_AOLSERVER_3_PLUS */

/* define NOT_AS3_PLAIN here as well, so that a single ifdef can be used */
#define NOT_AS3_PLAIN

static Ns_DbTableInfo *Ns_PgGetTableInfo(Ns_DbHandle *handle, char *table);
static char    *Ns_PgTableList(Ns_DString *pds, Ns_DbHandle *handle, int includesystem);

static char    *Ns_PgBestRowId(Ns_DString *pds, Ns_DbHandle *handle, char *table);

#endif /* NS_AOLSERVER_3_PLUS */

static int	Ns_PgServerInit(char *hServer, char *hModule, char *hDriver);
static void	Ns_PgSetErrorstate(Ns_DbHandle *handle);
static int      Ns_PgExec(Ns_DbHandle *handle, char *sql);
static Ns_Set  *Ns_PgBindRow(Ns_DbHandle *handle);
static int      Ns_PgResetHandle(Ns_DbHandle *handle);

static char	     *pgName = DRIVER_NAME;
static unsigned int   pgCNum = 0;

/*-
 * 
 * The NULL-terminated PgProcs[] array of Ns_DbProc structures is the
 * method by which the function pointers are passed to the nsdb module
 * through the Ns_DbRegisterDriver() function.  Each Ns_DbProc includes
 * the function id (i.e., DbFn_OpenDb, DbFn_CloseDb, etc.) and the
 * cooresponding driver function pointer (i.e., Ns_PgOpendb, Ns_PgCloseDb,
 * etc.).  See nsdb.h for a complete list of function ids.
 */
static Ns_DbProc PgProcs[] = {
    {DbFn_Name, (void *) Ns_PgName},
    {DbFn_DbType, (void *) Ns_PgDbType},
    {DbFn_OpenDb, (void *) Ns_PgOpenDb},
    {DbFn_CloseDb, (void *) Ns_PgCloseDb},
    {DbFn_BindRow, (void *) Ns_PgBindRow},
    {DbFn_Exec, (void *) Ns_PgExec},
    {DbFn_GetRow, (void *) Ns_PgGetRow},
    {DbFn_Flush, (void *) Ns_PgFlush},
    {DbFn_Cancel, (void *) Ns_PgFlush},

/* Excise for AS 3 */
#ifndef NS_AOLSERVER_3_PLUS
    {DbFn_GetTableInfo, (void *) Ns_PgGetTableInfo},
    {DbFn_TableList, (void *) Ns_PgTableList},
    {DbFn_BestRowId, (void *) Ns_PgBestRowId},
#endif /* NS_AOLSERVER_3_PLUS */

    {DbFn_ServerInit, (void *) Ns_PgServerInit},
    {DbFn_ResetHandle, (void *) Ns_PgResetHandle },
    {0, NULL}
};


/*
 * The NsPgConn structure is connection data specific
 * to PostgreSQL. 
 */ 
typedef struct NsPgConn {
    PGconn         *conn;
    unsigned int    cNum;
    PGresult       *res;
    int             nCols;
    int             nTuples;
    int             curTuple;
    int             in_transaction;
}               NsPgConn;



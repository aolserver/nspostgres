/*
 * The contents of this file are subject to the AOLserver Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://aolserver.com/.
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

/* NOTE: for OpenACS use, you need to define FOR_ACS_USE! */

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
   OR for OpenACS under AS3 -- plain AS3 doesn't get these */

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



SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* Store Procedure:  dbo.isp_ArchiveTable2_Generic                        */
/* Creation Date:  2-August-2016                                          */
/* Copyright: IDS                                                         */
/* Written by: JayLim                                                     */
/*                                                                        */
/* Purpose:  Archive records WITH ArchiveCop column for more than         */
/*           by specific condition - WITH dynamic schema                  */
/*                                                                        */
/* Input Parameters:  @cSourceDB     - Exceed DB                          */
/*                    @cArchiveDB    - Archive DB                         */
/*                    @cTableName    - Table                              */
/*                    @cCondition    - Filter Criteria, etc               */
/*                    @cPK1          - 1st Primary Key                    */
/*                    @cPK2          - 2nd Primary Key                    */
/*                    @cPK3          - 3rd Primary Key                    */
/*                    @cPK4          - 4th Primary Key                    */
/*                    @cPK5          - 5th Primary Key                    */
/*                    @cPKdate       - Primary Key WITH DATETIME format   */
/*                                                                        */
/* Usage: Derive from dbo.isp_archiveTable to allow multiple Primary Keys */
/*                                                                        */
/* Called By:  Set under Scheduler Jobs.                                  */
/*                                                                        */
/* PVCS Version: 1.0                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author    Purposes                                        */
/* 24-Jul-2017  JayLim    Performance Tune -reduce cache log (jay01)      */
/* 08-Aug-2018  Leong     Move @b_debug as pass in parameter.             */
/**************************************************************************/

CREATE PROC [dbo].[isp_ArchiveTable2_Generic]
    @cSourceDB  NVARCHAR(128),
    @cArchiveDB NVARCHAR(128),
    @cSchema    NVARCHAR(10) ,
    @cTableName NVARCHAR(128),
    @cCondition NVARCHAR(MAX),
    @cPK1       NVARCHAR(128),
    @cPK2       NVARCHAR(128) = '',
    @cPK3       NVARCHAR(128) = '',
    @cPK4       NVARCHAR(128) = '',
    @cPK5       NVARCHAR(128) = '',
    @cPKdate    NVARCHAR(128) = ''
  , @b_debug    INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success             INT,
           @n_archive_tbl_records INT,
           @n_err                 INT,
           @c_errmsg              NVARCHAR(250),
           @local_n_err           INT,
           @local_c_errmsg        NVARCHAR(250),
           @c_temp                NVARCHAR(254),
           @n_cnt                 INT,
           @c_SchemaName          NVARCHAR(5)

   SET @c_SchemaName = LTRIM(RTRIM(@cSchema))

   --DECLARE  @b_debug INT
   --SELECT   @b_debug = 0

   DECLARE @n_starttcnt     INT, -- Holds the current transaction count
           @n_continue      INT,
           @cExecStatements NVARCHAR(MAX), --(jay01)
           @cExecStmtArg    NVARCHAR(MAX)  --(jay01)

   SELECT  @n_starttcnt = @@TRANCOUNT,
           @n_continue  = 1,
           @b_success   = 0,
           @n_err       = 0,
           @c_errmsg    = '',
           @cExecStatements = ''

   DECLARE @cPKvalue1 NVARCHAR(30),
           @cPKvalue2 NVARCHAR(30),
           @cPKvalue3 NVARCHAR(30),
           @cPKvalue4 NVARCHAR(30),
           @cPKvalue5 NVARCHAR(30),
           @dPKvalue  DATETIME

   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''
   BEGIN
      SELECT @b_success = 1
      EXEC dbo.nsp_Build_Archive_Table_Generic
            @c_SchemaName,
            @cSourceDB,
            @cArchiveDB,
            @cTableName,
            @b_success OUTPUT,
            @n_err     OUTPUT,
            @c_errmsg  OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END

      IF (@b_debug = 1)
      BEGIN
         PRINT 'building alter table string for '+@c_SchemaName+'.'+ @cTableName
      END

      EXECUTE dbo.nspBuildAlterTableString_Generic
            @c_SchemaName,
            @cArchiveDB,
            @cTableName,
            @b_success OUTPUT,
            @n_err     OUTPUT,
            @c_errmsg  OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END

   SELECT @n_archive_tbl_records = 0

   SET @cExecStatements = N'DECLARE C_ITEM CURSOR FAST_FORWARD READ_ONLY FOR '
                           + 'SELECT DISTINCT ' + LTRIM(RTRIM(@cPK1))
                           + CASE LTRIM(RTRIM(ISNULL(@cPK2   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK2 END
                           + CASE LTRIM(RTRIM(ISNULL(@cPK3   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK3 END
                           + CASE LTRIM(RTRIM(ISNULL(@cPK4   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK4 END
                           + CASE LTRIM(RTRIM(ISNULL(@cPK5   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK5 END
                           + CASE LTRIM(RTRIM(ISNULL(@cPKdate,''))) WHEN '' THEN ',''1900-01-01T00:00:00.000'' ' ELSE ', ' + @cPKdate END
                           + ' FROM '+@c_SchemaName+ '.' + LTRIM(RTRIM(@cTableName)) + ' WITH (NOLOCK) '
                           + ' WHERE ' + @cCondition

   IF (@b_debug = 1)
   BEGIN
      PRINT @cExecStatements
   END
   EXEC sp_ExecuteSql @cExecStatements

   OPEN C_ITEM
   FETCH NEXT FROM C_ITEM INTO @cPKvalue1, @cPKvalue2, @cPKvalue3, @cPKvalue4, @cPKvalue5, @dPKvalue

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            PRINT 'building Update ArchiveCop for '+@c_SchemaName+'.'+ @cTableName
         END
         SELECT @b_success = 1

         SET @cPKvalue1 = ISNULL(RTRIM(@cPKvalue1),'') --(jay01)

         SET @cExecStatements = N'UPDATE '+ LTRIM(RTRIM(@c_SchemaName))+'.' + LTRIM(RTRIM(@cTableName)) + ' WITH (ROWLOCK) '
                              + ' SET ArchiveCop = ''9'' '
                              + ' WHERE '  + LTRIM(RTRIM(@cPK1)) + ' =  @cPKvalue1  '  --(jay01)
         IF @cPKvalue2 <> ''
         BEGIN
            SET @cPKvalue2 = ISNULL(RTRIM(@cPKvalue2),'') --(jay01)

            SET @cExecStatements = @cExecStatements
                                 + ' AND ' + LTRIM(RTRIM(@cPK2)) + ' = @cPKvalue2  '    --(jay01)
         END
         IF @cPKvalue3 <> ''
         BEGIN
            SET @cPKvalue3 = ISNULL(RTRIM(@cPKvalue3),'') --(jay01)

            SET @cExecStatements = @cExecStatements
                                 + ' AND ' + LTRIM(RTRIM(@cPK3)) + ' = @cPKvalue3 '  --(jay01)
         END

         IF @cPKvalue4 <> ''
         BEGIN
            SET @cPKvalue4 = ISNULL(RTRIM(@cPKvalue4),'') --(jay01)

            SET @cExecStatements = @cExecStatements
                                 + ' AND ' + LTRIM(RTRIM(@cPK4)) + ' = @cPKvalue4  '    --(jay01)
         END

         IF @cPKvalue5 <> ''
         BEGIN
            SET @cPKvalue5 = ISNULL(RTRIM(@cPKvalue5),'') --(jay01)

            SET @cExecStatements = @cExecStatements
                                 + ' AND ' + LTRIM(RTRIM(@cPK5)) + ' = @cPKvalue5  '   --(jay01)
         END

         IF @dPKvalue <> '1900-01-01T00:00:00.000'
         BEGIN
            SET @cExecStatements = @cExecStatements
                                 + ' AND ' + LTRIM(RTRIM(@cPKdate)) + ' =  CONVERT(CHAR(23),@dPKvalue,126)  '    --(jay01)
         END

         IF (@b_debug = 1)
         BEGIN
            PRINT @cExecStatements
         END
         BEGIN TRAN

         SET @cExecStmtArg = N'@cPKvalue1 NVARCHAR(30), '
                             +'@cPKvalue2 NVARCHAR(30), '
                             +'@cPKvalue3 NVARCHAR(30), '
                             +'@cPKvalue4 NVARCHAR(30), '
                             +'@cPKvalue5 NVARCHAR(30), '
                             +'@dPKvalue  DATETIME '

         EXEC sp_ExecuteSql @cExecStatements, @cExecStmtArg, @cPKvalue1, @cPKvalue2, @cPKvalue3, @cPKvalue4, @cPKvalue5, @dPKvalue      --(jay01)

         SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT

         SELECT @n_archive_tbl_records = @n_archive_tbl_records + 1

         IF @local_n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @local_n_err = 73702
            SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
            SELECT @local_c_errmsg =
               ': Update of Archivecop failed - '+@c_SchemaName+'.' + @cTableName + '. (dbo.isp_ArchiveTable2_Generic) ( ' +
               ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
          ROLLBACK TRAN
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END
      END

      FETCH NEXT FROM C_ITEM INTO @cPKvalue1, @cPKvalue2, @cPKvalue3, @cPKvalue4, @cPKvalue5, @dPKvalue
   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE C_ITEM
   DEALLOCATE C_ITEM

   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''
   BEGIN
      SELECT @c_temp = 'attempting to archive ' + convert(varchar(9), @n_archive_tbl_records) +
                       ' FROM ' +@c_SchemaName+'.'+ @cTableName + ' records'
      EXECUTE nspLogAlert
         @c_modulename   = 'dbo.isp_ArchiveTable2_Generic',
         @c_alertmessage = @c_temp ,
         @n_severity     = 0,
         @b_success      = @b_success OUTPUT,
         @n_err          = @n_err OUTPUT,
         @c_errmsg       = @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END

   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''
   BEGIN
      IF (@b_debug = 1)
      BEGIN
         PRINT 'building insert for '+@c_SchemaName+'.'+@cTableName
      END
      SELECT @b_success = 1
      EXEC dbo.nsp_Build_Insert_Generic
         @c_SchemaName,
         @cArchiveDB,
         @cTableName,
         1,
         @b_success OUTPUT,
         @n_err     OUTPUT,
         @c_errmsg  OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END

   /* #INCLUDE <SPTPA01_2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'dbo.isp_ArchiveTable2_Generic'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- procedure

GO
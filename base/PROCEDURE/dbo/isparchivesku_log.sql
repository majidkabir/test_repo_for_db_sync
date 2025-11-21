SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : ispArchiveSku_Log                                      */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters: NONE                                               */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 28-Apr-2015  Leong     Use 112 date format.                          */
/************************************************************************/

CREATE PROC [dbo].[ispArchiveSku_Log]
   @c_copyFROM_db  NVARCHAR(55),
   @c_copyto_db    NVARCHAR(55),
   @n_daysretain   INT,
   @b_debug        INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue  INT ,
            @n_starttcnt INT , -- Holds the current Transaction count
            @n_cnt       INT   -- Holds @@ROWCOUNT after certain operations

   DECLARE  @n_retain_days     INT         , -- days to hold data
            @d_result          DATETIME    , -- date Tran_date - (GETDATE() - noofdaystoretain
            @c_datetype        NVARCHAR(10), -- 1=TranDate, 2=EditDate, 3=AddDate
            @n_archive_records INT           -- # of POD records to be archived

   DECLARE  @local_n_err    INT,
            @local_c_errmsg NVARCHAR(254),
            @b_success      INT,
            @n_err          INT,
            @c_errmsg       NVARCHAR(256)

   DECLARE  @c_WhereClause  NVARCHAR(2048), -- June01
            @c_temp         NVARCHAR(2048), -- June01
            @n_RowRef       INT

   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 0, @n_err = 0, @c_errmsg = '',
          @local_n_err = 0, @local_c_errmsg = ''

   SELECT @d_result = DATEADD(DAY, -@n_daysretain, GETDATE())
   SELECT @d_result = DATEADD(DAY, 1, @d_result)

   IF @b_debug = 1
   BEGIN
      SELECT @d_result '@d_result'
   END

   IF DB_ID(@c_copyto_db) IS NULL
   BEGIN
      SELECT @n_continue = 3
      SELECT @local_n_err = 73701
      SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)
      SELECT @local_c_errmsg = ": Target Database " + @c_copyto_db + " Does NOT exist " + " ( " +
                               " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + " (ispArchiveSku_Log)"
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      SELECT @c_temp = 'Archive Of Sku_Log Started with Parms; Retain Days = ' + CONVERT(CHAR(6), @n_daysretain)

      EXECUTE nspLogAlert
            @c_ModuleName   = 'ispArchiveSku_Log',
            @c_AlertMessage = @c_temp,
            @n_Severity     = 0,
            @b_success      = @b_success OUTPUT,
            @n_err          = @n_err OUTPUT,
            @c_errmsg       = @c_errmsg OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      EXECUTE nsp_BUILD_ARCHIVE_TABLE
            @c_copyfrom_db,
            @c_copyto_db,
            'SKU_Log',
            @b_success OUTPUT,
            @n_err OUTPUT,
            @c_errmsg OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @b_debug = 1
      BEGIN
         PRINT 'building alter table string for Sku_Log...'
      END

      EXECUTE nspBuildAlterTableString
            @c_copyto_db,
            'SKU_Log',
            @b_success OUTPUT,
            @n_err OUTPUT,
            @c_errmsg OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --SELECT @c_temp = ' '
      --SET @c_WhereClause = (dbo.fnc_RTrim(@c_WhereClause) + dbo.fnc_RTrim(@c_temp))

      SELECT @c_WhereClause = ''
      SELECT @c_WhereClause = ' WHERE CONVERT(CHAR(8), Sku_Log.EditDate, 112) <= ''' + CONVERT(CHAR(8), @d_result, 112) + ''''

      WHILE @@TranCount > @n_starttcnt
      COMMIT TRAN

      SET @n_archive_records = 0

      SELECT @c_WhereClause = ' DECLARE C_Archive_SKU_Log CURSOR FAST_FORWARD READ_ONLY FOR ' +
                              ' SELECT RowRef FROM Sku_Log WITH (NOLOCK) ' +
                              ISNULL(RTRIM(@c_WhereClause),'')

      IF @b_debug = 1
      BEGIN
         SELECT @c_WhereClause '@c_WhereClause'
      END

      EXECUTE (@c_WhereClause)

      OPEN C_Archive_SKU_Log
      FETCH NEXT FROM C_Archive_SKU_Log INTO @n_RowRef

      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         BEGIN TRAN
         UPDATE Sku_Log WITH (ROWLOCK)
         SET ArchiveCop = '9'
         WHERE RowRef = @n_RowRef

         SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT

         IF @local_n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @local_n_err = 73702
            SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)
            SELECT @local_c_errmsg = ": Update of Archivecop failed - Sku_Log. (ispArchiveSku_Log) " + " ( " +
                                     " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            SELECT @n_archive_records = @n_archive_records + 1
            COMMIT TRAN
         END
         FETCH NEXT FROM C_Archive_SKU_Log INTO @n_RowRef
      END
      CLOSE C_Archive_SKU_Log
      DEALLOCATE C_Archive_SKU_Log
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(CONVERT(CHAR(6),@n_archive_records )) + " Sku_Log records"
      EXECUTE nspLogAlert
            @c_ModuleName   = 'ispArchiveSku_Log',
            @c_AlertMessage = @c_Temp ,
            @n_Severity     = 0,
            @b_success      = @b_success OUTPUT,
            @n_err          = @n_err OUTPUT,
            @c_errmsg       = @c_errmsg OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      EXEC nsp_BUILD_INSERT
         @c_copyto_db,
         'SKU_Log',
         1,
         @b_success OUTPUT,
         @n_err OUTPUT,
         @c_errmsg OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      EXECUTE nspLogAlert
            @c_ModuleName   = 'ispArchiveSku_Log',
            @c_AlertMessage = 'Archive Of Sku_Log Ended Normally.',
            @n_Severity     = 0,
            @b_success      = @b_success OUTPUT,
            @n_err          = @n_err OUTPUT,
            @c_errmsg       = @c_errmsg OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   ELSE
   BEGIN
      IF @n_continue = 3
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspLogAlert
               @c_ModuleName   = 'ispArchiveSku_Log',
               @c_AlertMessage = 'Archive Of Sku_Log Ended Abnormally - Check This Log For Additional Messages.',
               @n_Severity     = 0,
               @b_success      = @b_success OUTPUT,
               @n_err          = @n_err OUTPUT,
               @c_errmsg       = @c_errmsg OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
   END

   /* #INCLUDE <SPATran2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process AND Return
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

      SELECT @n_err = @local_n_err
      SELECT @c_errmsg = @local_c_errmsg

      IF @b_debug = 1
      BEGIN
         SELECT @n_err, @c_errmsg, 'before putting in nsp_logerr at the bottom'
      END

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispArchiveSku_Log'
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
END

GO
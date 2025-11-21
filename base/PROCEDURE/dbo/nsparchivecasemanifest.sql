SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspArchiveCaseManifest                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspArchiveCaseManifest]
@c_copyfrom_db  NVARCHAR(55)
,              @c_copyto_db    NVARCHAR(55)
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @b_debug int             -- Debug On Or Off
   /* #INCLUDE <SPARPO1.SQL> */
   DECLARE        @n_retain_days int      , -- days to hold data
   @d_CaseMdate  datetime     , -- CaseM Date from CaseM header table
   @d_result  datetime     , -- date CaseM_date - (getdate() - noofdaystoretain
   @c_datetype NVARCHAR(10),      -- 1=CaseMDATE, 2=EditDate, 3=AddDate
   @n_archive_CaseM_records   int -- # of CaseM records to be archived
   DECLARE        @local_n_err         int,
   @local_c_errmsg    NVARCHAR(254)
   DECLARE        @c_CaseMActive NVARCHAR(2),
   @c_CaseMStorerKeyStart NVARCHAR(15),
   @c_CaseMStorerKeyEnd NVARCHAR(15),
   @c_CaseMStart NVARCHAR(20),
   @c_CaseMEnd NVARCHAR(20),
   @c_whereclause NVARCHAR(254),
   @c_temp NVARCHAR(254),
   @CopyRowsToArchiveDatabase NVARCHAR(1)
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
   @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
   IF db_id(@c_copyto_db) is NULL
   BEGIN
      SELECT @n_continue = 3
      SELECT @local_n_err = 74401
      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
      SELECT @local_c_errmsg =
      ": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
      " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nspArchiveCaseManifest)'
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT  @n_retain_days = CaseMNumberofDaysToRetain,
      @c_datetype = CaseMdatetype,
      @c_CaseMActive = CaseMActive,
      @c_CaseMStorerKeyStart = CaseMStorerKeyStart,
      @c_CaseMStorerKeyEnd = CaseMStorerKeyEnd,
      @c_CaseMStart = CaseMStart,
      @c_CaseMEnd = CaseMEnd,
      @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
      FROM ArchiveParameters
      SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
      SELECT @d_result = dateadd(day,1,@d_result)
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      SELECT @c_temp = "Archive Of CaseManifest Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
      ' ; Active = '+ dbo.fnc_RTrim(@c_CaseMActive)+ ' ; Storer = '+ dbo.fnc_RTrim(@c_CaseMStorerKeyStart)+'-'+
      dbo.fnc_RTrim(@c_CaseMStorerKeyEnd) + ' ; CaseID = '+dbo.fnc_RTrim(@c_CaseMStart)+'-'+dbo.fnc_RTrim(@c_CaseMEnd)+
      ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ convert(char(6),@n_retain_days)
      EXECUTE nspLogAlert
      @c_ModuleName   = "nspArchiveCaseManifest",
      @c_AlertMessage = @c_Temp ,
      @n_Severity     = 0,
      @b_success       = @b_success OUTPUT,
      @n_err          = @n_err OUTPUT,
      @c_errmsg       = @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN
      SELECT @c_whereclause = ' '
      IF (dbo.fnc_RTrim(@c_CaseMStorerKeyStart) IS NOT NULL and dbo.fnc_RTrim(@c_CaseMStorerKeyEnd) IS NOT NULL)
      BEGIN
         SELECT @c_temp = 'AND CaseManifest.StorerKey BETWEEN '+ 'N'''+dbo.fnc_RTrim(@c_CaseMStorerKeyStart) + ''''+ ' AND '+
         'N'''+dbo.fnc_RTrim(@c_CaseMStorerKeyEnd)+''''
      END
      IF (dbo.fnc_RTrim(@c_CaseMStart) IS NOT NULL and dbo.fnc_RTrim(@c_CaseMEnd) IS NOT NULL)
      BEGIN
         SELECT @c_temp = @c_temp + ' AND CaseManifest.CaseId BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_CaseMStart) + '''' +' AND '+
         'N'''+dbo.fnc_RTrim(@c_CaseMEnd)+''''
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         select @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'CaseManifest',@b_success OUTPUT , @n_err OUTPUT , @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for CaseM..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"CaseManifest",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         BEGIN TRAN
            IF @c_datetype = "1" -- CaseMDATE
            BEGIN
               SELECT @c_whereclause = "UPDATE CaseManifest SET Archivecop = '9' WHERE CaseManifest.ReceiptDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and CaseManifest.Status = '9' and CaseManifest.ShipStatus = '9' "
               EXECUTE (@c_whereclause+ @c_temp)
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               SELECT @n_archive_CaseM_records = @n_cnt
            END
            IF @c_datetype = "2" -- EditDate
            BEGIN
               SELECT @c_whereclause = "UPDATE CaseManifest SET Archivecop = '9' WHERE CaseManifest.EditDate <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and CaseManifest.Status = '9' and CaseManifest.ShipStatus = '9' "
               EXECUTE (@c_whereclause+ @c_temp)
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               SELECT @n_archive_CaseM_records = @n_cnt
            END
            IF @c_datetype = "3" -- AddDate
            BEGIN
               SELECT @c_whereclause = "UPDATE CaseManifest SET Archivecop = '9' WHERE CaseManifest.AddDate <= " +'"'+ convert(char(10),@d_result,101)+'"' + " and CaseManifest.Status = '9' and CaseManifest.ShipStatus = '9' "
               EXECUTE (@c_whereclause+ @c_temp)
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               SELECT @n_archive_CaseM_records = @n_cnt
            END
            IF @local_n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @local_n_err = 74401
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
               SELECT @local_c_errmsg =
               ": Update of Archivecop failed - CaseManifest. (nspArchiveCaseManifest) " + " ( " +
               " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
            END
            IF (@b_debug = 1)
            BEGIN
               print "After creation of @c_whereclause"
               SELECT 'execute clause ', @c_whereclause
               select datalength(@c_whereclause)
               SELECT '@c_temp ', @c_temp
               select datalength(@c_temp)
            END
            IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
            BEGIN
               SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_CaseM_records )) +
               " CaseManifest records "
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchiveCaseManifest",
               @c_AlertMessage = @c_Temp ,
               @n_Severity     = 0,
               @b_success       = @b_success OUTPUT,
               @n_err          = @n_err OUTPUT,
               @c_errmsg       = @c_errmsg OUTPUT
               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 1)
               BEGIN
                  print "Building INSERT for CaseManifest..."
               END
               SELECT @b_success = 1
               EXEC nsp_BUILD_INSERT  @c_copyto_db, 'CaseManifest',1,@b_success OUTPUT , @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 0)
               BEGIN
                  DELETE FROM CaseManifest
                  WHERE ARCHIVECOP = '9'
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               END
               IF (@b_debug = 1)
               BEGIN
                  SELECT * FROM CaseManifest
                  WHERE ARCHIVECOP = '9'
                  print "DELETE for CaseManifest..."
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74403
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ":  CaseManifest delete failed. (nspArchiveCaseManifest) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               COMMIT TRAN
            END
         ELSE
            BEGIN
               ROLLBACK TRAN
            END
         END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspLogAlert
         @c_ModuleName   = "nspArchiveCaseManifest",
         @c_AlertMessage = "Archive Of CaseManifest Ended Normally.",
         @n_Severity     = 0,
         @b_success       = @b_success OUTPUT,
         @n_err     = @n_err OUTPUT,
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
            @c_ModuleName   = "nspArchiveCaseManifest",
            @c_AlertMessage = "Archive Of CaseManifest Ended Abnormally - Check This Log For Additional Messages.",
            @n_Severity     = 0,
            @b_success       = @b_success OUTPUT ,
            @n_err          = @n_err OUTPUT,
            @c_errmsg       = @c_errmsg OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
         END
      END
      /* #INCLUDE <SPARPO2.SQL> */
      IF @n_continue=3  -- Error Occured - Process And Return
      BEGIN
         SELECT @b_success = 0
         IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
         IF (@b_debug = 1)
         BEGIN
            SELECT @n_err,@c_errmsg, 'before putting in nsp_logerr at the bottom'
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, "nspArchiveCaseManifest"
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
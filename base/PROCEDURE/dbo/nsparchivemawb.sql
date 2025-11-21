SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspArchiveMawb                                     */
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

CREATE PROC    [dbo].[nspArchiveMawb]
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
   @b_debug int              -- Debug On Or Off
   /* #INCLUDE <SPAMawb1.SQL> */
   DECLARE        @n_retain_days int      , -- days to hold data
   @d_Mawbdate  datetime     , -- Mawb Date from Mawb header table
   @d_result  datetime     , -- date Mawb_date - (getdate() - noofdaystoretain
   @c_datetype NVARCHAR(10),      -- 1=MawbDATE, 2=EditDate, 3=AddDate
   @n_archive_Mawb_records   int, -- # of Mawb records to be archived
   @n_archive_Mawb_detail_records   int -- # of Mawb_detail records to be archived
   DECLARE        @local_n_err         int,
   @local_c_errmsg    NVARCHAR(254)
   DECLARE        @c_MawbActive NVARCHAR(2),
   @c_MawbStart NVARCHAR(15),
   @c_MawbEnd NVARCHAR(15),
   @c_whereclause NVARCHAR(254),
   @c_temp NVARCHAR(254),
   @CopyRowsToArchiveDatabase NVARCHAR(1)
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
   @b_debug = 0 , @local_n_err = 0, @local_c_errmsg = ' '
   IF db_id(@c_copyto_db) is NULL
   BEGIN
      SELECT @n_continue = 3
      SELECT @local_n_err = 73701
      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
      SELECT @local_c_errmsg =
      ": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
      " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nspArchiveMawb)'
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT  @n_retain_days = MAWBnumberofdaystoretain,
      @c_datetype = Mawbdatetype,
      @c_MawbActive = MawbActive,
      @c_MawbStart = MawbStart,
      @c_MawbEnd = MawbEnd,
      @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
      FROM ArchiveParameters
      SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
      SELECT @d_result = dateadd(day,1,@d_result)
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      SELECT @c_temp = "Archive Of MAWB Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
      ' ; Active = '+ dbo.fnc_RTrim(@c_MawbActive)+ ' ; MAWB = '+dbo.fnc_RTrim(@c_MawbStart)+'-'+dbo.fnc_RTrim(@c_MawbEnd)+
      ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ convert(char(6),@n_retain_days)
      EXECUTE nspLogAlert
      @c_ModuleName   = "nspArchiveMawb",
      @c_AlertMessage = @c_temp,
      @n_Severity     = 0,
      @b_success       = @b_success OUTPUT,
      @n_err          = @n_err OUTPUT,
      @c_errmsg       = @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF  (@n_continue = 1 or @n_continue = 2)
   BEGIN
      IF (dbo.fnc_RTrim(@c_MawbStart) IS NOT NULL and dbo.fnc_RTrim(@c_MawbEnd) IS NOT NULL)
      BEGIN
         SELECT @c_temp =  ' AND MasterAirwayBill.MawbKey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_MawbStart) + '''' +' AND '+
         'N'''+dbo.fnc_RTrim(@c_MawbEnd)+''''
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         select @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'MasterAirwayBill',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         SELECT @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'MasterAirwayBillDetail',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for MasterAirwayBill..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"MasterAirwayBill",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for MasterAirwayBillDetail..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"MasterAirwayBillDetail",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2 ) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         BEGIN TRAN
            IF @c_datetype = "1" -- MawbDate
            BEGIN
               SELECT @b_success = 1
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchiveMawb",
               @c_AlertMessage = "Archiving MAWB Based on MawbDate is Not Active - Aborting...",
               @n_Severity     = 0,
               @b_success       = @b_success OUTPUT,
               @n_err          = @n_err OUTPUT,
               @c_errmsg       = @c_errmsg OUTPUT
               SELECT @local_n_err =  73900
               SELECT @local_c_errmsg = "Archiving MAWB Based on MawbDate is Not Active - Aborting..."
               SELECT @n_continue = 3
            END
            IF (@n_continue = 1 or @n_continue = 2 )
            BEGIN
               IF @c_datetype = "2" -- EditDate
               BEGIN
                  SELECT @c_whereclause = "UPDATE MasterAirwayBill SET Archivecop = '9' WHERE MasterAirwayBill.EditDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and MasterAirwayBill.Status = '9' " +  @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  SELECT @n_archive_Mawb_records = @n_cnt
               END
               IF @c_datetype = "3" -- AddDate
               BEGIN
                  SELECT @c_whereclause = "UPDATE MasterAirwayBill SET Archivecop = '9' WHERE MasterAirwayBill.AddDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and MasterAirwayBill.Status = '9' " +  @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  SELECT @n_archive_Mawb_records = @n_cnt
               END
               IF @c_datetype = "4" -- Effectivedate
               BEGIN
                  SELECT @c_whereclause = "UPDATE MasterAirwayBill SET Archivecop = '9' WHERE MasterAirwayBill.EffectiveDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and MasterAirwayBill.Status = '9' " +  @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  SELECT @n_archive_Mawb_records = @n_cnt
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 73901
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ": Update of Archivecop failed - MAWB. (nspArchiveMawb) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN
               UPDATE MasterAirwayBillDetail
               Set MasterAirwayBillDetail.Archivecop = '9'
               FROM MasterAirwayBillDetail, MasterAirwayBill
               Where ((MasterAirwayBillDetail.Mawbkey = MasterAirwayBill.Mawbkey) and (MasterAirwayBill.archivecop = '9'))
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               SELECT @n_archive_Mawb_Detail_records = @n_cnt
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 73902
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ": Update of Archivecop failed - MasterAirwayBillDetail. (nspArchiveMawb) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
            BEGIN
               SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_Mawb_records )) +
               " MasterAirwayBillDetail records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_Mawb_detail_records )) + " MasterAirwayBillDetail records"
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchiveMawb",
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
               SELECT @b_success = 1
               EXEC nsp_BUILD_INSERT  @c_copyto_db, 'MasterAirwayBill',1,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @b_success = 1
               EXEC nsp_BUILD_INSERT   @c_copyto_db, 'MasterAirwayBillDetail',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 0)
               BEGIN
                  DELETE FROM MasterAirwayBill
                  WHERE ARCHIVECOP = '9'
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               END
               IF (@b_debug = 1)
               BEGIN
                  SELECT * FROM MasterAirwayBill
                  WHERE ARCHIVECOP = '9'
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 73903
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ":  MAWB delete failed. (nspArchiveMawb) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 0)
               BEGIN
                  DELETE FROM MasterAirwayBillDetail
                  WHERE ARCHIVECOP = '9'
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               END
               IF (@b_debug = 1)
               BEGIN
                  SELECT * FROM MasterAirwayBillDetail
                  WHERE ARCHIVECOP = '9'
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 73904
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ":  MasterAirwayBillDetail delete failed. (nspArchiveMawb) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF @n_continue = 3
            BEGIN
               ROLLBACK TRAN
            END
         ELSE
            BEGIN
               COMMIT TRAN
            END
         END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspLogAlert
         @c_ModuleName   = "nspArchiveMawb",
         @c_AlertMessage = "Archive Of MAWB Ended Normally.",
         @n_Severity     = 0,
         @b_success       = @b_success OUTPUT,
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
            @c_ModuleName   = "nspArchiveMawb",
            @c_AlertMessage = "Archive Of MAWB Ended Abnormally - Check This Log For Additional Messages.",
            @n_Severity     = 0,
            @b_success       = @b_success OUTPUT,
            @n_err          = @n_err OUTPUT,
            @c_errmsg       = @c_errmsg OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
         END
      END
      /* #INCLUDE <SPAMawb2.SQL> */
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, "nspArchiveMawb"
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
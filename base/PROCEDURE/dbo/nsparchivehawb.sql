SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspArchiveHAWB                                     */
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

CREATE PROC    [dbo].[nspArchiveHAWB]
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
   /* #INCLUDE <SPAHAWB1.SQL> */
   DECLARE        @n_retain_days int      , -- days to hold data
   @d_HAWBdate  datetime     , -- HAWB Date from HAWB header table
   @d_result  datetime     , -- date HAWB_date - (getdate() - noofdaystoretain
   @c_datetype NVARCHAR(10),      -- 1=HAWBDATE, 2=EditDate, 3=AddDate
   @n_archive_HAWB_records   int, -- # of HAWB records to be archived
   @n_archive_HAWB_detail_records   int -- # of HAWB_detail records to be archived
   DECLARE        @local_n_err         int,
   @local_c_errmsg    NVARCHAR(254)
   DECLARE        @c_HawbActive NVARCHAR(2),
   @c_HawbStart NVARCHAR(15),
   @c_HawbEnd NVARCHAR(15),
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
      " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nspArchiveHAWB)'
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT  @n_retain_days = Hawbnumberofdaystoretain,
      @c_datetype = HAWBdatetype,
      @c_HAWBActive = HAWBActive,
      @c_HAWBStart = HAWBStart,
      @c_HAWBEnd = HAWBEnd,
      @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
      FROM ArchiveParameters
      SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
      SELECT @d_result = dateadd(day,1,@d_result)
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      SELECT @c_temp = "Archive Of Hawb Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
      ' ; Active = '+ dbo.fnc_RTrim(@c_HAWBActive)+ ' ; HAWB = '+dbo.fnc_RTrim(@c_HAWBStart)+'-'+dbo.fnc_RTrim(@c_HAWBEnd)+
      ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ convert(char(6),@n_retain_days)
      EXECUTE nspLogAlert
      @c_ModuleName   = "nspArchiveHAWB",
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
      IF (dbo.fnc_RTrim(@c_HAWBStart) IS NOT NULL and dbo.fnc_RTrim(@c_HAWBEnd) IS NOT NULL)
      BEGIN
         SELECT @c_temp =  ' AND HOUSEAIRWAYBILL.HAWBKey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_HAWBStart) + '''' +' AND '+
         'N'''+dbo.fnc_RTrim(@c_HAWBEnd)+''''
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         select @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'HouseAirwaybill',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         SELECT @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'HouseAirwaybillDetail',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for HouseAirwaybill..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"HouseAirwaybill",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for HouseAirwaybillDetail..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"HouseAirwaybillDetail",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2 ) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         BEGIN TRAN
            IF @c_datetype = "1" -- HAWBDate
            BEGIN
               SELECT @b_success = 1
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchiveHAWB",
               @c_AlertMessage = "Archiving HAWBs Based on HAWBDate is Not Active - Aborting...",
               @n_Severity     = 0,
               @b_success       = @b_success OUTPUT,
               @n_err          = @n_err OUTPUT,
               @c_errmsg       = @c_errmsg OUTPUT
               SELECT @local_n_err =  73800
               SELECT @local_c_errmsg = "Archiving HAWBs Based on HAWBDate is Not Active - Aborting..."
               SELECT @n_continue = 3
            END
            IF (@n_continue = 1 or @n_continue = 2 )
            BEGIN
               IF @c_datetype = "2" -- EditDate
               BEGIN
                  SELECT @c_whereclause = "UPDATE HOUSEAIRWAYBILL SET Archivecop = '9' WHERE HOUSEAIRWAYBILL.EditDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and HOUSEAIRWAYBILL.Status = '9' " +  @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  SELECT @n_archive_HAWB_records = @n_cnt
               END
               IF @c_datetype = "3" -- AddDate
               BEGIN
                  SELECT @c_whereclause = "UPDATE HOUSEAIRWAYBILL SET Archivecop = '9' WHERE HOUSEAIRWAYBILL.AddDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and HOUSEAIRWAYBILL.Status = '9' " +  @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  SELECT @n_archive_HAWB_records = @n_cnt
               END
               IF @c_datetype = "4" -- Effectivedate
               BEGIN
                  SELECT @c_whereclause = "UPDATE HOUSEAIRWAYBILL SET Archivecop = '9' WHERE HOUSEAIRWAYBILL.EffectiveDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and HOUSEAIRWAYBILL.Status = '9' " +  @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  SELECT @n_archive_HAWB_records = @n_cnt
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 73801
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ": Update of Archivecop failed - HAWB. (nspArchiveHAWB) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN
               UPDATE HouseAirwaybillDetail
               Set HouseAirwaybillDetail.Archivecop = '9'
               FROM HouseAirwaybill , HouseAirwaybillDetail
               Where ((HouseAirwaybillDetail.HAWBkey = HouseAirwaybill.HAWBkey) and (HouseAirwaybill.archivecop = '9'))
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               SELECT @n_archive_HAWB_Detail_records = @n_cnt
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 73802
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ": Update of Archivecop failed - HouseAirwaybillDetail. (nspArchiveHAWB) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
            BEGIN
               SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_HAWB_records )) +
               " HouseAirwayBill records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_HAWB_detail_records )) + " HouseAirwaybillDetail records"
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchiveHAWB",
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
               EXEC nsp_BUILD_INSERT  @c_copyto_db, 'HouseAirwaybill',1,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @b_success = 1
               EXEC nsp_BUILD_INSERT   @c_copyto_db, 'HouseAirwaybillDetail',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 0)
               BEGIN
                  DELETE FROM HouseAirwaybill
                  WHERE ARCHIVECOP = '9'
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               END
               IF (@b_debug = 1)
               BEGIN
                  SELECT * FROM HouseAirwaybill
                  WHERE ARCHIVECOP = '9'
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 73803
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ":  HAWB delete failed. (nspArchiveHAWB) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 0)
               BEGIN
                  DELETE FROM HouseAirwaybillDetail
                  WHERE ARCHIVECOP = '9'
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               END
               IF (@b_debug = 1)
               BEGIN
                  SELECT * FROM HouseAirwaybillDetail
                  WHERE ARCHIVECOP = '9'
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 73804
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ":  HouseAirwayBillDetail delete failed. (nspArchiveHAWB) " + " ( " +
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
         @c_ModuleName   = "nspArchiveHAWB",
         @c_AlertMessage = "Archive Of HAWB Ended Normally.",
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
            @c_ModuleName   = "nspArchiveHAWB",
            @c_AlertMessage = "Archive Of HAWB Ended Abnormally - Check This Log For Additional Messages.",
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
      /* #INCLUDE <SPAHAWB2.SQL> */
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, "nspArchiveHAWB"
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
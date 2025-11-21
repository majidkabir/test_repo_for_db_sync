SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspArchivePallet                                   */
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

CREATE PROC    [dbo].[nspArchivePallet]
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
   @b_debug int            , -- Debug On Or Off
   @n_retain_days int      , -- days to hold data
   @d_result  datetime     , -- date  - (getdate() - noofdaystoretain
   @c_datetype NVARCHAR(10),     -- 1=palletDATE, 2=EditDate, 3=AddDate, 4=EffectiveDate
   @n_archive_pallet_records   int, -- # of cont records to be archived
   @n_arc_pallet_detail_records   int -- # of cont_detail records to be archived
   DECLARE        @local_n_err         int,
   @local_c_errmsg    NVARCHAR(254)
   DECLARE   @palletNumberofDaysToRetain  int ,
   @c_palletActive NVARCHAR(2),
   @c_palletStart NVARCHAR(10),
   @c_palletEnd   NVARCHAR(10),
   @c_palletDateType  NVARCHAR(10),
   @c_whereclause NVARCHAR(254),
   @c_temp NVARCHAR(254),
   @CopyRowsToArchiveDatabase NVARCHAR(2)
   /* #INCLUDE <SPARCON1.SQL> */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
   @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
   IF db_id(@c_copyto_db) is NULL
   BEGIN
      SELECT @n_continue = 3
      SELECT @local_n_err = 73701
      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
      SELECT @local_c_errmsg  =
      ": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
      " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nspArchivePallet)'
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @n_retain_days = palletnumberofdaystoretain,
      @c_palletActive = palletActive ,
      @c_palletStart = palletStart ,
      @c_palletEnd = palletEnd ,
      @c_palletDateType =  palletDateType,
      @c_datetype = palletdatetype,
      @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
      FROM ArchiveParameters
      SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
      SELECT @d_result = dateadd(day,1,@d_result)
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      SELECT @c_temp = "Archive Of pallet Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
      ' ; Active = '+ dbo.fnc_RTrim(@c_palletActive)+ ' ; PalletKey = '+dbo.fnc_RTrim(@c_palletStart)+'-'+dbo.fnc_RTrim(@c_palletEnd)+
      ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ convert(char(6),@n_retain_days)
      EXECUTE nspLogAlert
      @c_ModuleName   = "nspArchivePallet",
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
   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN
      SELECT @c_temp = ' '
      IF (dbo.fnc_RTrim(@c_palletStart) IS NOT NULL and dbo.fnc_RTrim(@c_palletEnd) IS NOT NULL)
      BEGIN
         SELECT @c_temp =  ' AND pallet.palletKey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_palletStart) + '''' +' AND '+
         'N'''+dbo.fnc_RTrim(@c_palletEnd)+''''
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         select @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'pallet',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'palletDetail',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for pallet..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"pallet",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for palletDetail..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"palletDetail",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         BEGIN TRAN
            IF @c_datetype = "1" --palletDate
            BEGIN
               SELECT @b_success = 1
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchivePallet",
               @c_AlertMessage = "Archiveing pallet Based on palletDATE is Not Active - Aborting...",
               @n_Severity     = 0,
               @b_success       = @b_success OUTPUT,
               @n_err          = @n_err OUTPUT,
               @c_errmsg       = @c_errmsg OUTPUT
               SELECT @local_n_err =  74300
               SELECT @local_c_errmsg = "Archiveing pallet Based on palletDATE is Not Active - Aborting..."
               SELECT @n_continue = 3
            END
            IF (@n_continue = 1 or @n_continue = 2 )
            BEGIN
               IF @c_datetype = "2" --EditDate
               BEGIN
                  SELECT @c_whereclause = "UPDATE pallet SET Archivecop = '9' WHERE pallet.EditDate <= "+ '"'+ convert(char(10),@d_result,101)+ '"'+" and pallet.Status = '9' " + @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  SELECT @n_archive_pallet_records = @n_cnt
               END
               IF @c_datetype = "3" --AddDate
               BEGIN
                  SELECT @c_whereclause = "UPDATE pallet SET Archivecop = '9' WHERE pallet.AddDate <= "+ '"'+convert(char(10),@d_result,101)+ '"'+ " and pallet.Status = '9' " + @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  SELECT @n_archive_pallet_records = @n_cnt
               END
               IF @c_datetype = "4" --EffectiveDate
               BEGIN
                  SELECT @c_whereclause = "UPDATE pallet SET Archivecop = '9' WHERE pallet.EffectiveDate <="+ '"'+convert(char(10),@d_result,101)+'"'+ " and pallet.Status = '9'" + @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @n_cnt
                  SELECT @n_archive_pallet_records = @n_cnt
               END
               IF (@b_debug = 1)
               BEGIN
                  SELECT @c_whereclause
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74301
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg  =
                  ": Update of Archivecop failed - pallet. (NspArchivepallet) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN
               UPDATE palletDetail
               Set palletDetail.Archivecop = '9'
               FROM pallet
               Where ((palletDetail.palletkey = pallet.palletkey) and (pallet.archivecop = '9'))
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               SELECT @n_arc_pallet_detail_records = @n_cnt
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74302
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ": Update of Archivecop failed - palletDetail. (NspArchivepallet) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
            BEGIN
               SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_pallet_records )) +
               " Pallet records and " + dbo.fnc_RTrim(convert(char(6),@n_arc_pallet_detail_records )) + " PalletDetail records"
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchivePallet",
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
               EXEC nsp_BUILD_INSERT  @c_copyto_db, 'pallet',1,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @b_success = 1
               EXEC nsp_BUILD_INSERT   @c_copyto_db, 'palletDetail',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 0)
               BEGIN
                  DELETE FROM pallet
                  WHERE ARCHIVECOP = '9'
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               END
               IF (@b_debug = 1)
               BEGIN
                  SELECT * FROM pallet
                  WHERE ARCHIVECOP = '9'
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74303
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg  =
                  ":  pallet delete failed. (NspArchivepallet) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
               IF (@local_n_err > 0)
               BEGIN
                  SELECT 'just after deleting pallet rowcount = ', @local_n_err, @local_c_errmsg
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 0)
               BEGIN
                  DELETE FROM palletDetail
                  WHERE ARCHIVECOP = '9'
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               END
               IF (@b_debug = 1)
               BEGIN
                  SELECT * FROM palletDetail
                  WHERE ARCHIVECOP = '9'
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74304
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ":  PalletDetail delete failed. (NspArchivepallet) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               End
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
         @c_ModuleName   = "nspArchivePallet",
         @c_AlertMessage = "Archive Of pallet Ended Normally.",
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
            @c_ModuleName   = "nspArchivePallet",
            @c_AlertMessage = "Archive Of pallet Ended Abnormally - Check This Log For Additional Messages.",
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
      /* #INCLUDE <SPARCON2.SQL> */
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, "NspArchivepallet"
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspArchiveMBOL                                     */
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

CREATE PROC    [dbo].[nspArchiveMBOL]
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
   @d_podate  datetime     , -- Mbol Date from PO header table
   @d_result  datetime     , -- date po_date - (getdate() - noofdaystoretain
   @c_datetype NVARCHAR(10),      -- 1=MbolDATE, 2=EditDate, 3=AddDate
   @n_archive_mbol_records   int, -- # of mbol records to be archived
   @n_archive_mbol_detail_records   int, -- # of mbol_detail records to be archived
   @n_default_id int,
   @n_strlen int
   DECLARE        @local_n_err         int,
   @local_c_errmsg    NVARCHAR(254)
   DECLARE        @c_mbolactive NVARCHAR(2),
   @c_mbolstart NVARCHAR(10),
   @c_MbolEnd NVARCHAR(10),
   @d_MbolDepDateStart Datetime,
   @d_MbolDepDateEnd Datetime,
   @d_MbolDelDateStart Datetime,
   @d_MbolDelDateEnd Datetime,
   @c_MbolVoyageStart NVARCHAR(30),
   @c_MbolVoyageEnd NVARCHAR(30),
   @c_def_MbolStart NVARCHAR(254),
   @c_def_MbolEnd NVARCHAR(254),
   @d_def_MbolDepDateStart NVARCHAR(254),
   @d_def_MbolDepDateEnd NVARCHAR(254),
   @d_def_MbolDelDateStart NVARCHAR(254),
   @d_def_MbolDelDateEnd NVARCHAR(254),
   @c_def_MbolVoyageStart NVARCHAR(254),
   @c_def_MbolVoyageEnd NVARCHAR(254),
   @c_whereclause NVARCHAR(254),
   @c_temp NVARCHAR(254),
   @c_temp1 NVARCHAR(254),
   @CopyRowsToArchiveDatabase NVARCHAR(1),
   @TempDateBegin datetime,
   @TempDateEnd datetime
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
   @b_debug = 0 , @local_n_err = 0, @local_c_errmsg = ' '
   IF db_id(@c_copyto_db) is NULL
   BEGIN
      SELECT @n_continue = 3
      SELECT @local_n_err = 74501
      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
      SELECT @local_c_errmsg =
      ": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
      " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nspArchiveMBOL)'
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT  @n_retain_days = MbolNumberofDaysToRetain,
      @c_datetype = Mboldatetype,
      @c_MbolActive = MbolActive,
      @c_Mbolstart = Mbolstart,
      @c_MbolEnd = MbolEnd,
      @d_MbolDepDateStart = MbolDepDateStart ,
      @d_MbolDepDateEnd = MbolDepDateEnd,
      @d_MbolDelDateStart = MbolDelDateStart,
      @d_MbolDelDateEnd = MbolDelDateEnd,
      @c_MbolVoyageStart  = MbolVoyageStart,
      @c_MbolVoyageEnd  = MbolVoyageEnd,
      @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
      FROM ArchiveParameters
      SELECT @n_default_id = (SELECT cdefault FROM syscolumns a, dbo.sysobjects b
      where b.name = 'ArchiveParameters' and a.id = b.id
      and a.name = 'MbolStart')
      SELECT @c_temp = (select text from syscomments where id = @n_default_id)
      SELECT @c_temp1 = dbo.fnc_RTrim(@c_temp)
      SELECT @n_strlen = datalength(@c_temp1)
      SELECT @c_def_mbolstart = substring(@c_temp1,3,(@n_strlen-4))
      SELECT @n_default_id = (SELECT cdefault FROM syscolumns a, dbo.sysobjects b
      where b.name = 'ArchiveParameters' and a.id = b.id
      and a.name = 'MbolEnd')
      SELECT @c_temp = (select text from syscomments where id = @n_default_id)
      SELECT @c_temp1 = dbo.fnc_RTrim(@c_temp)
      SELECT @n_strlen = datalength(@c_temp1)
      SELECT @c_def_MbolEnd = substring(@c_temp1,3,(@n_strlen-4))
      SELECT @n_default_id = (SELECT cdefault FROM syscolumns a, dbo.sysobjects b
      where b.name = 'ArchiveParameters' and a.id = b.id
      and a.name = 'MbolDepDateStart')
      SELECT @c_temp = (select text from syscomments where id = @n_default_id)
      SELECT @c_temp1 = dbo.fnc_RTrim(@c_temp)
      SELECT @n_strlen = datalength(@c_temp1)
      IF ( CHARINDEX('getdate()',@c_temp1) > 0)
      BEGIN
         SELECT @d_def_MbolDepDateStart = convert(char(10),getdate(),101)
      END
   ELSE
      BEGIN
         SELECT @d_def_MbolDepDateStart = substring(@c_temp1,3,(@n_strlen-4))
      END
      SELECT @n_default_id = (SELECT cdefault FROM syscolumns a, dbo.sysobjects b
      where b.name = 'ArchiveParameters' and a.id = b.id
      and a.name = 'MbolDepDateEnd')
      SELECT @c_temp = (select text from syscomments where id = @n_default_id)
      SELECT @c_temp1 = dbo.fnc_RTrim(@c_temp)
      SELECT @n_strlen = datalength(@c_temp1)
      IF ( CHARINDEX('getdate()',@c_temp1) > 0)
      BEGIN
         SELECT @d_def_MbolDepDateEnd = convert(char(10),getdate(),101)
      END
   ELSE
      BEGIN
         SELECT @d_def_MbolDepDateEnd = substring(@c_temp1,3,(@n_strlen-4))
      END
      SELECT @n_default_id = (SELECT cdefault FROM syscolumns a, dbo.sysobjects b
      where b.name = 'ArchiveParameters' and a.id = b.id
      and a.name = 'MbolDelDateStart')
      SELECT @c_temp = (select text from syscomments where id = @n_default_id)
      SELECT @c_temp1 = dbo.fnc_RTrim(@c_temp)
      SELECT @n_strlen = datalength(@c_temp1)
      IF ( CHARINDEX('getdate()',@c_temp1) > 0)
      BEGIN
         SELECT @d_def_MbolDelDateStart = convert(char(10),getdate(),101)
      END
   ELSE
      BEGIN
         SELECT @d_def_MbolDelDateStart = substring(@c_temp1,4,(@n_strlen-4))
      END
      SELECT @n_default_id = (SELECT cdefault FROM syscolumns a, dbo.sysobjects b
      where b.name = 'ArchiveParameters' and a.id = b.id
      and a.name = 'MbolDelDateEnd')
      SELECT @c_temp = (select text from syscomments where id = @n_default_id)
      SELECT @c_temp1 = dbo.fnc_RTrim(@c_temp)
      SELECT @n_strlen = datalength(@c_temp1)
      IF ( CHARINDEX('getdate()',@c_temp1) > 0)
      BEGIN
         SELECT @d_def_MbolDelDateEnd = convert(char(10),getdate(),101)
      END
   ELSE
      BEGIN
         SELECT @d_def_MbolDelDateEnd = substring(@c_temp1,3,(@n_strlen-4))
      END
      SELECT @n_default_id = (SELECT cdefault FROM syscolumns a, dbo.sysobjects b
      where b.name = 'ArchiveParameters' and a.id = b.id
      and a.name = 'MbolVoyageStart')
      SELECT @c_temp = (select text from syscomments where id = @n_default_id)
      SELECT @c_temp1 = dbo.fnc_RTrim(@c_temp)
      SELECT @n_strlen = datalength(@c_temp1)
      SELECT @c_def_MbolVoyageStart = substring(@c_temp1,3,(@n_strlen-4))
      SELECT @n_default_id = (SELECT cdefault FROM syscolumns a, dbo.sysobjects b
      where b.name = 'ArchiveParameters' and a.id = b.id
      and a.name = 'MbolVoyageEnd')
      SELECT @c_temp = (select text from syscomments where id = @n_default_id)
      SELECT @c_temp1 = dbo.fnc_RTrim(@c_temp)
      SELECT @n_strlen = datalength(@c_temp1)
      SELECT @c_def_MbolVoyageEnd = substring(@c_temp1,3,(@n_strlen-4))
      SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
      SELECT @d_result = dateadd(day,1,@d_result)
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      SELECT @c_temp = "Archive Of Shipment MBOL Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
      ' ; Active = '+ dbo.fnc_RTrim(@c_mbolactive)+
      ' ; MBOL Range = '+dbo.fnc_RTrim(@c_mbolstart)+'-'+dbo.fnc_RTrim(@c_MbolEnd)+
      ' ; Voyage Range = '+ dbo.fnc_RTrim(@c_MbolVoyageStart)+'-'+ dbo.fnc_RTrim(@c_MbolVoyageEnd) +
      ' ; Departure Date Range = '+convert(char(10),@d_MbolDepDateStart)+'-'+convert(char(10),@d_MbolDepDateEnd)+
      ' ; Delivery Date Range = '+convert(char(10),@d_MbolDelDateStart)+'-'+convert(char(10),@d_MbolDelDateEnd)+
      ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ convert(char(6),@n_retain_days)
      EXECUTE nspLogAlert
      @c_ModuleName   = "nspArchiveMBOL",
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
      SELECT @c_temp = ' '
      SELECT @c_temp1 = ' '
      IF ((dbo.fnc_RTrim(@c_mbolstart) <> dbo.fnc_RTrim(@c_def_mbolstart)) or
      (dbo.fnc_RTrim(@c_MbolEnd) <> dbo.fnc_RTrim(@c_def_MbolEnd)) )
      BEGIN
         SELECT @c_temp = @c_temp + ' AND MBOL.MBOLKEY BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_mbolstart) + '''' +' AND '+
         'N'''+dbo.fnc_RTrim(@c_MbolEnd)+''''
      END
      IF (@b_debug = 1)
      BEGIN
         SELECT '@d_def_MbolDepDateStart = ', @d_def_MbolDepDateStart
         SELECT '@d_MbolDepDateStart after date conv = ' , convert(char(10),@d_MbolDepDateStart,101)
      END
      IF ((@d_def_MbolDepDateStart <> convert(char(10),@d_MbolDepDateStart,101)  ) or
      (@d_def_MbolDepDateEnd <> convert(char(10),@d_MbolDepDateEnd,101) ))
      BEGIN
         SELECT @TempDateBegin = dateadd(day,-1,@d_MbolDepDateStart)
         SELECT @TempDateEnd = @d_MbolDepDateEnd
         SELECT @c_temp1 =  ' AND MBOL.DepartureDate  BETWEEN '+ '"' + convert(char(10),@tempdatebegin,101) + '"' +' AND '+
         '"'+convert(char(10),@TempDateEnd,101)+'"'
      END
      IF ( (@d_def_MbolDelDateStart <> convert(char(10),@d_MbolDelDateStart,101) ) or
      (dbo.fnc_RTrim(@d_def_MbolDelDateEnd) <> convert(char(10),@d_MbolDelDateEnd  ,101)) )
      BEGIN
         SELECT @TempDateBegin = dateadd(day,-1,@d_MbolDelDateStart)
         SELECT @TempDateEnd = @d_MbolDelDateEnd
         SELECT @c_temp1 =  @c_temp1 + ' AND MBOL.ArrivalDate  BETWEEN '+ '"' + convert(char(10),@TempDateBegin,101) + '"' +' AND '+
         '"'+convert(char(10),@TempDateEnd,101)+'"'
      END
      IF ((dbo.fnc_RTrim(@c_MbolVoyageStart)<> dbo.fnc_RTrim(@c_def_MbolVoyageStart)) or
      (dbo.fnc_RTrim(@c_MbolVoyageEnd) <> dbo.fnc_RTrim(@c_def_MbolVoyageEnd)))
      BEGIN
         SELECT @c_temp1 = @c_temp1 + ' AND MBOL.VoyageNumber BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_MbolVoyageStart) + '''' +' AND '+
         'N'''+dbo.fnc_RTrim(@c_MbolVoyageEnd)+''''
      END
      SELECT @d_MbolDepDateStart = dateadd(day,-1,@d_MbolDepDateStart)
      SELECT @d_MbolDepDateEnd = dateadd(day,1,@d_MbolDepDateEnd)
      SELECT @d_MbolDelDateStart = dateadd(day,-1,@d_MbolDelDateStart)
      SELECT @d_MbolDelDateEnd = dateadd(day,1,@d_MbolDelDateEnd)
      IF (@b_debug = 1)
      BEGIN
         select 'before execute '
         select '@ctemp ',@c_temp
         select '@ctemp1', @c_temp1
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "starting Table Existence Check For Mbol..."
            SELECT 'execute clause ', @c_whereclause
         END
         select @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'MBOL',@b_success OUTPUT , @n_err OUTPUT , @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "starting Table Existence Check For MbolDETAIL..."
         END
         SELECT @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'MBOLdetail',@b_success OUTPUT , @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for MBOL..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"MBOL",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for MBOLdetail..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"MBOLdetail",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         BEGIN TRAN
            IF @c_datetype = "1" -- MBOLDATE
            BEGIN
               SELECT @c_whereclause = "UPDATE MBOL SET Archivecop = '9' WHERE MBOL.DepartureDate   <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and MBOL.Status = '9' "
               EXECUTE (@c_whereclause + @c_temp + @c_temp1)
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               SELECT @n_archive_mbol_records = @n_cnt
            END
            IF @c_datetype = "2" -- EditDate
            BEGIN
               SELECT @c_whereclause = "UPDATE MBOL SET Archivecop = '9' WHERE MBOL.EditDate <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and MBOL.Status = '9' "
               EXECUTE (@c_whereclause+ @c_temp + @c_temp1)
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               SELECT @n_archive_mbol_records = @n_cnt
            END
            IF @c_datetype = "3" -- AddDate
            BEGIN
               SELECT @c_whereclause = "UPDATE MBOL SET Archivecop = '9' WHERE MBOL.AddDate <= " +'"'+ convert(char(10),@d_result,101)+'"' + " and MBOL.Status = '9' "
               EXECUTE (@c_whereclause + @c_temp + @c_temp1)
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               SELECT @n_archive_mbol_records = @n_cnt
            END
            IF @local_n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @local_n_err = 74501
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
               SELECT @local_c_errmsg =
               ": Update of Archivecop failed - Shipping MBOL (nspArchiveMBOL) " + " ( " +
               " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
            END
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN
               UPDATE MBOLdetail
               Set MBOLdetail.Archivecop = '9'
               FROM MBOL , MBOLdetail
               Where ((MBOLdetail.MbolKey = MBOL.MbolKey) and (MBOL.archivecop = '9'))
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               SELECT @n_archive_mbol_detail_records = @n_cnt
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74502
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ": Update of Archivecop failed - MBOLdetail. (nspArchiveMBOL) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
            BEGIN
               SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_mbol_records )) +
               " MBOL records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_mbol_detail_records )) + " MBOLdetail records"
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchiveMBOL",
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
                  print "Building INSERT for mbol..."
               END
               SELECT @b_success = 1
               EXEC nsp_BUILD_INSERT  @c_copyto_db, 'MBOL',1,@b_success OUTPUT , @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
            BEGIN
               IF (@b_debug = 1)
               BEGIN
                  print "Building INSERT for MBOLdetail..."
               END
               SELECT @b_success = 1
               EXEC nsp_BUILD_INSERT   @c_copyto_db, 'MBOLdetail',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 0)
               BEGIN
                  DELETE FROM MBOL
                  WHERE ARCHIVECOP = '9'
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               END
               IF (@b_debug = 1)
               BEGIN
                  print "DELETE for MBOL..."
                  SELECT * FROM MBOL
                  WHERE ARCHIVECOP = '9'
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74503
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ":  MBOL delete failed. (nspArchiveMBOL) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 0)
               BEGIN
                  DELETE FROM MBOLdetail
                  WHERE ARCHIVECOP = '9'
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               END
               IF (@b_debug = 1)
               BEGIN
                  print "DELETE from MBOLdetail..."
                  SELECT * FROM MBOLdetail
                  WHERE ARCHIVECOP = '9'
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74504
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ":  MBOLdetail delete failed. (nspArchiveMBOL) " + " ( " +
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
         @c_ModuleName   = "nspArchiveMBOL",
         @c_AlertMessage = "Archive Of SHIPPING MBOL Ended Normally.",
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
            @c_ModuleName   = "nspArchiveMBOL",
            @c_AlertMessage = "Archive Of SHIPPING MBOL Ended Abnormally - Check This Log For Additional Messages.",
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, "nspArchiveMBOL"
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
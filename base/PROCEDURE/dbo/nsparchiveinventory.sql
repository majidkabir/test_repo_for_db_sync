SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspArchiveInventory                                */
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

CREATE PROC    [dbo].[nspArchiveInventory]
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
   @d_Itrndate  datetime     , -- Itrn Date from Itrn header table
   @d_result  datetime     , -- date Itrn_date - (getdate() - noofdaystoretain
   @c_datetype NVARCHAR(10),      -- 1=ItrnDATE, 2=EditDate, 3=AddDate
   @n_archive_Itrn_records   int -- # of Itrn records to be archived
   DECLARE        @c_ItrnActive NVARCHAR(2),
   @c_ItrnStorerKeyStart NVARCHAR(15),
   @c_ItrnStorerKeyEnd NVARCHAR(15),
   @c_ItrnSkuStart NVARCHAR(20),
   @c_ItrnSkuEnd NVARCHAR(20),
   @c_ItrnLotStart NVARCHAR(10),
   @c_ItrnLotEnd NVARCHAR(10),
   @c_whereclause NVARCHAR(254),
   @c_temp NVARCHAR(254),
   @CopyRowsToArchiveDatabase NVARCHAR(1)
   DECLARE @d_cutoffdate DATETIME
   DECLARE @d_HistBegin datetime
   DECLARE        @local_n_err         int,
   @local_c_errmsg    NVARCHAR(254)
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
   @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
   IF db_id(@c_copyto_db) is NULL
   BEGIN
      SELECT @n_continue = 3
      SELECT @local_n_err = 74001
      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
      + ": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
      " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nspArchiveInventory)'
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT  @n_retain_days = ItrnNumberofDaysToRetain,
      @c_datetype = Itrndatetype,
      @c_ItrnActive = ItrnActive,
      @c_ItrnStorerKeyStart = ItrnStorerKeyStart,
      @c_ItrnStorerKeyEnd = ItrnStorerKeyEnd,
      @c_ItrnSkuStart = ItrnSkuStart,
      @c_ItrnSkuEnd = ItrnSkuEnd,
      @c_ItrnLotStart = ItrnLotStart,
      @c_ItrnLotEnd = ItrnLotEnd,
      @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
      FROM ArchiveParameters
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      SELECT @c_temp = "Archive Of Inventory Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
      ' ; Active = '+ dbo.fnc_RTrim(@c_ItrnActive)+ ' ; Storer = '+ dbo.fnc_RTrim(@c_ItrnStorerKeyStart)+'-'+
      dbo.fnc_RTrim(@c_ItrnStorerKeyEnd) + ' ; SKU  = '+dbo.fnc_RTrim(@c_ItrnSkuStart)+'-'+dbo.fnc_RTrim(@c_ItrnSkuEnd)+
      ' ; Lot  = '+dbo.fnc_RTrim(@c_ItrnLotStart)+'-'+dbo.fnc_RTrim(@c_ItrnLotEnd)+
      ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase)+
      ' ; Retain Days = '+ convert(char(6),@n_retain_days)
      EXECUTE nspLogAlert
      @c_ModuleName   = "nspArchiveInventory",
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
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ItrnStorerKeyEnd)) is NULL
   BEGIN
      SELECT @c_ItrnStorerKeyEnd = @c_ItrnStorerKeyStart
   END
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ItrnSkuEnd)) is NULL
   BEGIN
      SELECT @c_ItrnSkuEnd = @c_ItrnSkuStart
   END
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ItrnLotEnd)) is NULL
   BEGIN
      SELECT @c_ItrnLotEnd = @c_ItrnLotStart
   END
   DECLARE @d_today datetime
   SELECT @d_today = convert(datetime,convert(char(10),getdate(),101))
   SELECT @d_cutoffdate = DATEADD(day, (-@n_retain_days + 1), @d_today)
   SELECT @d_histBegin = convert(datetime,'01/01/1901',101)
   IF (@b_debug =1 )
   BEGIN
      SELECT  '@n_retain_days = ',  @n_retain_days
      SELECT  '@c_datetype = ', @c_datetype
      SELECT  '@c_ItrnActive =',     @c_ItrnActive
      SELECT  'StKey =',     @c_ItrnStorerKeyStart
      SELECT        @c_ItrnStorerKeyEnd
      SELECT  'SkuKey =',      @c_ItrnSkuStart
      SELECT        @c_ItrnSkuEnd
      SELECT  'LotKey =',       @c_ItrnLotStart
      SELECT        @c_ItrnLotEnd
      SELECT  'copy rows to arch database',      @CopyRowsToArchiveDatabase
      SELECT @d_cutoffdate
      SELECT @d_histbegin
   END
   DECLARE @n_num_recs int
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT @n_num_recs = -100
      SELECT
      Itrnkey
      , StorerKey
      , Sku
      , Lot
      , FromLoc
      , FromID
      , ToLoc
      , ToID
      , qty
      , EffectiveDate
      , TranType
      , RunningTotal = 0
      INTO #INVENTORY_CUT
      FROM ITRN
      WHERE
      StorerKey BETWEEN @c_ItrnStorerKeyStart AND @c_ItrnStorerKeyEnd
      AND Sku BETWEEN @c_ItrnSkuStart AND @c_ItrnSkuEnd
      AND Lot BETWEEN @c_ItrnLotStart AND @c_ItrnLotEnd
      AND EffectiveDate BETWEEN @d_histbegin and @d_cutoffdate
      SELECT @local_n_err = @@ERROR
      SELECT @n_num_recs = (SELECT count(*) FROM #INVENTORY_CUT)
      IF (@b_debug = 1)
      BEGIN
         SELECT 'number of records after filter', @n_num_recs
      END
      IF NOT @local_n_err = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @local_n_err = 74002
         SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)    -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+": Summary Insert Failed On #INVENTORY_CUT (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT
      StorerKey
      , Sku
      , Lot
      , Loc = FromLoc
      , ID = FromID
      , ArchiveQty = 0
      , ArchiveDate = @d_cutoffdate
      INTO #ARCHIVE_LOTxLOCxID
      FROM #INVENTORY_CUT
      WHERE FromLoc = 'ZZZZZZZZ '
      SELECT @local_n_err = @@ERROR
      IF NOT @local_n_err = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @local_n_err=74003
         SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)    -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+": Summary Insert Failed On #ARCHIVE_LOTxLOCxID (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF (@b_debug = 1)
      BEGIN
         SELECT  DISTINCT
         StorerKey
         , Sku
         , Lot
         , FromLoc
         , FromID
         ,0
         ,@d_CutOffDate
         FROM #INVENTORY_CUT
         SELECT  DISTINCT
         StorerKey
         , Sku
         , Lot
         , ToLoc
         , ToID
         ,0
         ,@d_CutOffDate
         FROM #INVENTORY_CUT
      END
      INSERT INTO #ARCHIVE_LOTxLOCxID
      SELECT  DISTINCT
      StorerKey
      , Sku
      , Lot
      , FromLoc
      , FromID
      ,0
      ,@d_CutOffDate
      FROM #INVENTORY_CUT
      UNION
      SELECT  DISTINCT
      StorerKey
      , Sku
      , Lot
      , ToLoc
      , ToID
      ,0
      ,@d_CutOffDate
      FROM #INVENTORY_CUT
      SELECT @local_n_err = @@ERROR
      IF NOT @local_n_err = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @local_n_err=74004
         SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+": Distinct Insert Failed On #ARCHIVE_LOTxLOCxID (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      DELETE #ARCHIVE_LOTxLOCxID
      WHERE LOC = '         '
      SELECT @local_n_err = @@ERROR
      IF NOT @local_n_err = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @local_n_err=74005
         SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+": Deletion of Blank LOCs failed On #ARCHIVE_LOTxLOCxID (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      UPDATE #ARCHIVE_LOTxLOCxID
      SET #ARCHIVE_LOTxLOCxID.ArchiveQty = LOTxLOCxID.ArchiveQty
      FROM #ARCHIVE_LOTxLOCxID, LOTxLOCxID
      WHERE #ARCHIVE_LOTxLOCxID.lot = LOTxLOCxID.lot
      AND   #ARCHIVE_LOTxLOCxID.LOC = LOTxLOCxID.LOC
      AND   #ARCHIVE_LOTxLOCxID.ID = LOTxLOCxID.ID
      AND   LOTxLOCxID.ARCHIVEQTY is NOT NULL
      SELECT @local_n_err = @@ERROR
      IF NOT @local_n_err = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @local_n_err=74006
         SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+": Update Failed On #ARCHIVE_LOTxLOCxID (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
      END
   END
   IF (@b_debug = 1)
   BEGIN
      SELECT '#ARCHIVE_LOTxLOCxID before going into the cursor '
      SELECT lot,loc,id, storerkey, sku, Archiveqty from #ARCHIVE_LOTxLOCxID
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @StorerKey NVARCHAR(15)
      DECLARE @Sku NVARCHAR(20)
      DECLARE @Lot NVARCHAR(10)
      DECLARE @FromLoc NVARCHAR(10)
      DECLARE @FromId NVARCHAR(18)
      DECLARE @ToLoc NVARCHAR(10)
      DECLARE @ToId NVARCHAR(18)
      DECLARE @Qty int
      DECLARE @EffectiveDate datetime
      DECLARE @TranType NVARCHAR(10)
      DECLARE @RunningTotal int
      DECLARE @rowcount int
      select @rowcount = (select count(*) from #ARCHIVE_LOTxLOCxID)
      IF (@rowcount > 0)
      BEGIN
         EXECUTE('DECLARE cursor_inventory_adjustment CURSOR
         FOR  SELECT
         StorerKey
         , Sku
         , Lot
         , FromLoc
         , FromID
         , ToLoc
         , ToID
         , qty
         , EffectiveDate
         , TranType
         FROM #INVENTORY_CUT
         ORDER BY Lot, EffectiveDate')
      END
      IF (@rowcount = 0)
      BEGIN
         SELECT @n_continue = 4
      END
      SELECT @local_n_err = @@error
      IF NOT @local_n_err = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @local_n_err=74007
         SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+": declaration of cursor failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      OPEN cursor_inventory_adjustment
      SELECT @local_n_err = @@cursor_rows
      IF @local_n_err = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @local_n_err=74008
         SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err) -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+": open of cursor failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      FETCH NEXT FROM cursor_inventory_adjustment
      INTO
      @StorerKey,
      @Sku,
      @Lot,
      @FromLoc,
      @FromId,
      @ToLoc,
      @ToId,
      @Qty,
      @EffectiveDate,
      @TranType
      SELECT @local_n_err = @@FETCH_STATUS
      IF  @local_n_err = -2
      BEGIN
         SELECT @n_continue = 3
         SELECT @local_n_err=74009
         SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err) -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+":First Fetch of cursor failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      WHILE (@@fetch_status <> -1)
      BEGIN
         IF @n_continue=1 or @n_continue=2
         BEGIN
            IF (@b_debug = 1)
            BEGIN
               PRINT ' ******************'
               SELECT 'Trantype ',@TranType,  'FromLOC ', dbo.fnc_RTrim(@Fromloc), 'FromID ', dbo.fnc_RTrim(@FromID )
               SELECT 'ToLOC ', @Toloc , 'ToID' , @ToID, 'QTY ', @qty
               SELECT 'StorerKey ', @StorerKey, 'Sku ', @sku, 'LOT ', @Lot
               PRINT ' ******************'
               PRINT ' ******************'
            END
            IF (dbo.fnc_RTrim(@TranType) = 'DP' OR dbo.fnc_RTrim(@TranType) = 'AJ' OR dbo.fnc_RTrim(@TranType) = 'WD')
            BEGIN
               UPDATE #ARCHIVE_LOTxLOCxID
               SET ArchiveQty = ArchiveQty + @QTY
               WHERE StorerKey = @StorerKey AND
               SKU = @Sku AND
               LOT = @Lot AND
               LOC = @TOLoc AND
               Id = @TOId
               SELECT @local_n_err = @@error
               IF NOT @local_n_err  = 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err=74010
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err) -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+": Update (DP,AJ,WD) in cursor failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
               END
            END
            IF (dbo.fnc_RTrim(@TranType) = 'MV' )
            BEGIN
               UPDATE #ARCHIVE_LOTxLOCxID
               SET ArchiveQty = ArchiveQty - @QTY
               WHERE StorerKey = @StorerKey AND
               SKU = @Sku  AND
               LOT = @Lot AND
               LOC = @FromLoc AND
               Id = @FromId
               SELECT @local_n_err = @@error
               IF NOT @local_n_err  = 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err=74011
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+": Update MV From Loc failed in cursor failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
               END
               UPDATE #ARCHIVE_LOTxLOCxID
               SET ArchiveQty = ArchiveQty + @QTY
               WHERE StorerKey = @StorerKey AND
               SKU = @Sku  AND
               LOT = @Lot AND
               LOC = @ToLoc AND
               Id = @ToId
               SELECT @local_n_err = @@error
               IF NOT @local_n_err  = 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err=74012
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err) -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+": Update MV To Loc failed in cursor failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
               END
            END
            IF (@b_debug = 1 )
            BEGIN
               print 'after update of each record on #ARCHIVE_LOTxLOCxID '
               SELECT * from #ARCHIVE_LOTxLOCxID
            END
         END
         IF @n_continue=1 or @n_continue=2
         BEGIN
            FETCH NEXT FROM cursor_inventory_adjustment
            INTO
            @StorerKey,
            @Sku,
            @Lot,
            @FromLoc,
            @FromId,
            @ToLoc,
            @ToId,
            @Qty,
            @EffectiveDate,
            @TranType
            SELECT @local_n_err = @@Fetch_status
            IF @local_n_err = -2
            BEGIN
               SELECT @n_continue = 3
               SELECT @local_n_err=74013
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err) -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+":Loop Fetch of Cursor (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
            END
         END
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF NOT @@CURSOR_ROWS  = 0
      BEGIN
         CLOSE cursor_inventory_adjustment
         DEALLOCATE cursor_inventory_adjustment
         SELECT @local_n_err = @@error
         IF NOT @local_n_err = 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @local_n_err=74014
            SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err) -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+":Close and Dealloc of Cursor failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
         END
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT LOT, ArchiveQty INTO #ARCHIVE_LOT
      FROM LOTxLOCxID
      WHERE LOT is NULL
      SELECT @local_n_err = @@error
      IF NOT @local_n_err = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @local_n_err=74015
         SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err) -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+":Creation of #Archive_Lot table failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
      END
   END
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
   BEGIN
      IF (@b_debug = 1)
      BEGIN
         print "starting Table Existence Check For Inventory..."
         SELECT 'execute clause ', @c_whereclause
      END
      select @b_success = 1
      EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'Itrn',@b_success OUTPUT , @n_err OUTPUT , @c_errmsg OUTPUT
      IF not @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
   BEGIN
      IF (@b_debug = 1)
      BEGIN
         print "building alter table string for Itrn..."
      END
      EXECUTE nspBuildAlterTableString @c_copyto_db,"Itrn",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
      IF not @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
   BEGIN
      BEGIN TRAN
         IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
         BEGIN
            UPDATE ITRN
            SET ARCHIVECOP = '9'
            FROM #INVENTORY_CUT, ITRN
            WHERE #INVENTORY_CUT.itrnkey = ITRN.itrnkey
            SELECT @local_n_err = @@error, @n_cnt = @@rowcount
            SELECT @n_archive_Itrn_records  = @n_cnt
            IF NOT @local_n_err = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @local_n_err=74016
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err) -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+":Itrn Archivecop update failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
            END
         END
         IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
         BEGIN
            SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_Itrn_records )) +
            " Inventory records "
            EXECUTE nspLogAlert
            @c_ModuleName   = "nspArchiveInventory",
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
               print "Building INSERT for Inventory..."
            END
            SELECT @b_success = 1
            EXEC nsp_BUILD_INSERT  @c_copyto_db, 'Itrn',1,@b_success OUTPUT , @n_err OUTPUT, @c_errmsg OUTPUT
            IF not @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
         END
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            IF (@b_debug = 1)
            BEGIN
               print "updating LOTxLOCxId table..."
            END
            UPDATE LOTxLOCxID
            SET LOTxLOCxID.ARCHIVEQTY = #ARCHIVE_LOTxLOCxID.ArchiveQty ,
            LOTxLOCxID.ArchiveDate = @d_cutoffdate
            FROM #ARCHIVE_LOTxLOCxID, LOTxLOCxID
            WHERE #ARCHIVE_LOTxLOCxID.LOT = LOTxLOCxID.LOT
            AND #ARCHIVE_LOTxLOCxID.LOC = LOTxLOCxID.LOC
            AND #ARCHIVE_LOTxLOCxID.ID = LOTxLOCxID.ID
            SELECT @local_n_err = @@error
            IF @local_n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @local_n_err=74017
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err) -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+":LotxLocxId ArchiveQty update failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
            END
         END
         IF @n_continue=1 or @n_continue=2
         BEGIN
            INSERT  #ARCHIVE_LOT
            SELECT LOT, ArchiveQty = sum(ArchiveQty)
            FROM LOTxLOCxID
            GROUP BY LOT
            SELECT @local_n_err = @@error
            IF NOT @local_n_err = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @local_n_err=74018
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err) -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+":Summation of #Archive_Lot table failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
            END
         END
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            IF (@b_debug = 1)
            BEGIN
               print "updating LOT table..."
            END
            UPDATE LOT
            SET LOT.ARCHIVEQTY = #ARCHIVE_LOT.ArchiveQty,
            LOT.ArchiveDate = @d_cutoffdate
            FROM #ARCHIVE_LOT, LOT
            WHERE #ARCHIVE_LOT.LOT = LOT.LOT
            SELECT @local_n_err = @@error
            IF @local_n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @local_n_err=74019
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err) -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @local_c_errmsg="NSQL"+CONVERT(char(5),@local_n_err)+":Lot ArchiveQty update failed (nspArchiveInventory)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + " ) "
            END
         END
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            IF (@b_debug = 1)
            BEGIN
               print "DELETE for Inventory..."
            END
            IF (@b_debug = 0)
            BEGIN
               DELETE FROM Itrn
               WHERE ARCHIVECOP = '9'
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            END
            IF (@b_debug = 1)
            BEGIN
               SELECT * FROM Itrn
               WHERE ARCHIVECOP = '9'
            END
            IF @local_n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @local_n_err = 74020
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
               SELECT @local_c_errmsg =
               ":  Inventory delete failed. (nspArchiveInventory) " + " ( " +
               " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
            END
         END
         IF (@b_debug = 1)
         BEGIN
            print 'final output in nspArchiveInventory'
            SELECT lot,loc,id, storerkey, sku, Archiveqty from #ARCHIVE_LOTxLOCxID
            ORDER by lot, loc, id
            SELECT * FROM #ARCHIVE_LOT
            SELECT * from #INVENTORY_CUT
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
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspLogAlert
         @c_ModuleName   = "nspArchiveInventory",
         @c_AlertMessage = "Archive Of Inventory Ended Normally.",
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
            @c_ModuleName   = "nspArchiveInventory",
            @c_AlertMessage = "Archive Of Inventory Ended Abnormally - Check This Log For Additional Messages.",
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, "nspArchiveInventory"
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* SP: nspOrderProcessingByCase_UCC                                        */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose: Special Allocation Request by China (Not refer to Strategy)    */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: Power Builder Allocation from Load Plan                      */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver Purposes                                     */
/* 23-Jul-2004  Shong         Initial Version (SOS# 25496)                 */
/* 20-Aug-2004  YTWan         FBR001: allocation                           */
/* 09-Jun-2005  June          S36686, sort by balance qty instead of       */
/*                            hand qty                                     */
/* 13-Jun-2005  SHONG         Preventing Brake carton in bulk location     */
/* 23-Sep-2005  SHONG         SOS#41039 - Exclude Holded LOT, ID           */
/* 02-Nov-2005  SHONG         SOS#42319 - Lot Specific Allocation          */
/* 08-Dec-2005  MaryVong      S43971 Add in locationflag checking for      */
/*                            ckface location                              */
/* 14-Nov-2005  Shong         SOS#42319 - Lot Specific Allocation          */
/* 17-May-2006  YokeBeen      SOS#51099 - Expended the length of ID from   */
/*                            NVARCHAR(10) to NVARCHAR(18) max. - (YokeBeen01)     */
/* 29-Dec-2006  Shong         Don't allow over allocate for B grade stock  */
/* 13-May-2008  June          SOS104768 - Remove hardcode checking of      */
/*                            Lottable02 <> '02000'                        */
/* 09-May-2008  SHONG         SOS# 105520 Shoule not allocate Wave's       */
/*                            Orders                                       */
/*                            Qty Available should minus qty pending to    */
/*                            move in Wave Dynamic Picking Process         */
/* 08-June-2008 James         In LP alloc, if found wavekey then error     */
/* 29-July-2008 Shong         Bug Fixing - To prevent Wave's Allocated     */
/*                            Stock taken by Wave plan SHONG20080729       */
/* 12-Aug-2008  James         Added checking inventory status (James01)    */
/* 06-Jan-2009  Shong    1.1  SOS126009 Add StorerConfig NonGradedProduct  */
/*                            To allow Over Allocation in Pick Location.   */
/* 19-Mar-2010  Leong    1.2  Bug Fix: Change GetKey from REPLENISHMENT to */
/*                                     REPLENISHKEY (Leong01)              */
/*                            Commented SOS126009 for future reference     */
/*                            -- @cNonGradedProduct                        */
/* 12-Jul-2017  TLTING   1.3  missing (NOLOCK)                          */
/***************************************************************************/
CREATE PROC  [dbo].[nspOrderProcessingByCase_UCC]
               @c_OrderKey     NVARCHAR(10)
,              @c_oskey        NVARCHAR(10)
,              @c_docarton     NVARCHAR(1)
,              @c_doroute      NVARCHAR(1)
,              @c_tblprefix    NVARCHAR(10)
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN

   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue    int       ,
                  @n_starttcnt   int       , -- Holds the current transaction count
                  @n_cnt         int       , -- Holds @@ROWCOUNT after certain operations
                  @c_preprocess  NVARCHAR(250) , -- preprocess
                  @c_pstprocess  NVARCHAR(250) , -- post process
                  @n_err2        int       , -- For Additional Error Detection
                  @c_fromloc     NVARCHAR(10),
                  @b_debug       int         -- Debug 0 - OFF, 1 - Show ALL, 2 - Map

   -- Added By SHONG - Performance Tuning Rev 1.0
   DECLARE  @c_PHeaderKey        NVARCHAR(18),
            @c_CaseId            NVARCHAR(18),     -- (YokeBeen01)
            @c_PickLooseFromBulk int,
            @nLotQty             int,
            @b_Cursor_Opened     int,
            @nUCCQtyAvailable    int,
            @nQtyFullCaseRemain  int

   -- SOS#42319
   DECLARE @cLottable02  NVARCHAR(18)

   -- SOS126009
   -- DECLARE @cNonGradedProduct NVARCHAR(1)

   -- SHONG20080729
   DECLARE @nQtyPendingMoveOut   int,
           @nQtyPendingMoveIn    int,
           @nQtyOnHand           int,
           @cUCCNo               NVARCHAR(20),
           @nUCCQty              int,
           @cUOM                 NVARCHAR(10),
           @nQtyPendingReplenQty int


   SELECT @c_PickLooseFromBulk = 0
   SELECT @b_Cursor_Opened = 0

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0,@n_cnt = 0
   SELECT @c_errmsg='',@n_err2=0
   SELECT @b_debug = 0

   IF @c_tblprefix = 'DS1' or @c_tblprefix = 'DS2'
   BEGIN
      SELECT @b_debug = Convert(Int, Right(@c_tblprefix, 1))
   END

   DECLARE @n_cnt_sql     int  -- Additional holds for @@ROWCOUNT to try catch a wrong processing

   /* #INCLUDE <SPOP1.SQL> */

   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF (dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_oskey)) IS NULL or dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_oskey))='')
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63500
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Parameters Passed (nspOrderProcessingByCase_UCC)'
      END
   END -- @n_continue =1 or @n_continue = 2

   --Added by James 08/06/2008
   --In LP alloc, if found wavekey then error
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
              JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
              JOIN LoadPlanDetail WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
              WHERE ORDERS.Status < '9'
              AND LoadPlanDetail.LoadKey = @c_oskey
              AND ( ORDERS.UserDefine09 IS NOT NULL AND ORDERS.UserDefine09 <> '' ) )
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63500
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Cannot allocate Loadplan with Orders contain wavekey (nspOrderProcessingByCase_UCC)'
   END

   ---- Start Here Case Pick
   DECLARE  @cLOT               NVARCHAR(10)
   ,        @cOrderKey          NVARCHAR(10)
   ,        @cFacility          NVARCHAR(5)
   ,        @cLOC               NVARCHAR(10)
   ,        @nQtyAvailable      int
   ,        @nQty               int
   ,        @nQtyToTake         int
   ,        @cPickDetailKey     NVARCHAR(10)
   ,        @cStorerKey         NVARCHAR(15)
   ,        @cOrderLineNumber   NVARCHAR(5)
   ,        @cSKU               NVARCHAR(20)
   ,        @cID                NVARCHAR(18)  -- (YokeBeen01)
   ,        @nOpenQty           int
   ,        @cPackKey           NVARCHAR(10)
   ,        @nCaseCnt           int
   ,        @bPickUpdateSuccess int
   ,        @nCount             int
   ,        @cPreAllocPickKey   NVARCHAR(10)
   ,        @nBatchQty          int
   ,        @cPickLOC           NVARCHAR(10)
   ,        @nQtyMoveinProgress int
   ,        @cReplenishmentKey  NVARCHAR(10)
   ,        @nQtyToReplenish    int
   ,        @nWavePendingMoveIn int
   ,        @nLoadPendingMoveIn int
   ,        @nRplLOT            NVARCHAR(10)
   ,        @nRplLOC            NVARCHAR(10)
   ,        @nRplID             NVARCHAR(18)
   ,        @nRplQty            int
   ,        @cUCCRemainQty      int
   ,        @nRowCount          int

   DECLARE @tPICKDETAIL TABLE
        ( PickDetailKey    int IDENTITY (1,1),
          OrderKey         NVARCHAR(10),
          OrderLineNumber  NVARCHAR(5),
          Lot              NVARCHAR(10),
          Loc              NVARCHAR(10),
          ID               NVARCHAR(18),
          Storerkey        NVARCHAR(15),
          Sku              NVARCHAR(20),
          Qty              int )

   DECLARE @tORDERDETAIL TABLE
        ( OrderKey         NVARCHAR(10),
          OrderLineNumber  NVARCHAR(5),
          OpenQty          int )

   DECLARE @cAllowOverAllocations NVARCHAR(1),
           @nPickDetKey           int

   IF @c_tblprefix = 'DS1' or @c_tblprefix = 'DS2'
   BEGIN
      SELECT @b_debug = Convert(Int, Right(dbo.fnc_RTRIM(@c_tblprefix), 1))
      SELECT @b_debug 'debug'
   END

   CREATE TABLE #TempBatchPick
     (Facility     NVARCHAR(5),
      StorerKey    NVARCHAR(15),
      SKU          NVARCHAR(20),
      Qty          int,
      Lottable02   NVARCHAR(18)
      )

   INSERT INTO #TempBatchPick
   SELECT ORDERS.Facility,
          ORDERDETAIL.StorerKey,
          ORDERDETAIL.Sku,
          SUM(ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked) as QTY,
          ISNULL(ORDERDETAIL.Lottable02, '') -- SOS#42319
   FROM ORDERS (NOLOCK)
   JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   JOIN LoadPlanDetail (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
   WHERE ORDERS.Status < '9'
   AND LoadPlanDetail.LoadKey = @c_oskey
   -- Added By SHONG on 09-May-2008, Shoule not allocate Wave's Orders
   AND ( ORDERS.UserDefine09 IS NULL OR ORDERS.UserDefine09 = '' )
   GROUP BY ORDERS.Facility, ORDERDETAIL.StorerKey, ORDERDETAIL.Sku, ISNULL(ORDERDETAIL.Lottable02, '') -- SOS#42319
   HAVING SUM(ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked) > 0


   IF @b_debug = 2
   BEGIN
      SELECT * FROM #TempBatchPick
   END

   SELECT @nCount = COUNT(1)
   FROM   #TempBatchPick

   IF @nCount = 0
      RETURN

   SELECT @cSKU = ''

   IF @b_debug = 1
   BEGIN
      SELECT 'FCP Orders'
      SELECT T.SKU, T.StorerKey, T.Qty - (T.Qty % Cast(PACK.CaseCnt as int)),
             Pack.PackKey, PACK.CaseCnt, T.Facility,
             T.Lottable02 -- SOS#42319
      FROM   #TempBatchPick T
      JOIN   SKU (NOLOCK) ON (SKU.StorerKey = T.StorerKey AND SKU.SKU = T.SKU)
      JOIN   PACK (NOLOCk) ON (PACK.PackKey = SKU.PackKey)
      WHERE  PACK.CaseCnt > 0
      AND    T.Qty - ( T.Qty % Cast(PACK.CaseCnt as int) ) >= PACK.CaseCnt
      ORDER BY T.StorerKey, T.SKU, T.Lottable02
   END

   DECLARE C_Carton_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT T.SKU, T.StorerKey, T.Qty - (T.Qty % Cast(PACK.CaseCnt as int)),
             Pack.PackKey, PACK.CaseCnt, T.Facility,
             T.Lottable02 -- SOS#42319
      FROM   #TempBatchPick T
      JOIN   SKU (NOLOCK) ON (SKU.StorerKey = T.StorerKey AND SKU.SKU = T.SKU)
      JOIN   PACK (NOLOCk) ON (PACK.PackKey = SKU.PackKey)
      WHERE  PACK.CaseCnt > 0
      AND    T.Qty - ( T.Qty % Cast(PACK.CaseCnt as int) ) >= PACK.CaseCnt
      ORDER BY T.StorerKey, T.SKU, T.Lottable02

   OPEN C_Carton_PICK

   SET @nBatchQty = 0
   SET @nCaseCnt = 0

   FETCH NEXT FROM C_Carton_PICK INTO
             @cSKU,              @cStorerKey,             @nBatchQty,
             @cPackKey,          @nCaseCnt,               @cFacility,
             @cLottable02 -- SOS#42319

   WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
   BEGIN
      DELETE @tOrderDetail

      INSERT INTO @tORDERDETAIL
      SELECT OrderDetail.OrderKey,
             OrderDetail.OrderLineNumber,
             ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked as Qty
      FROM   OrderDetail (NOLOCK)
      JOIN   LoadPlanDetail (NOLOCK) ON (LoadPlanDetail.OrderKey = OrderDetail.OrderKey)
      JOIN   ORDERS (NOLOCK) ON (ORDERS.OrderKey = OrderDetail.OrderKey)
      WHERE  OrderDetail.StorerKey = @cStorerKey
      AND    OrderDetail.SKU = @cSKU
      AND    LoadPlanDetail.LoadKey = @c_oskey
      AND    ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked > 0
      AND    ORDERS.Facility = @cFacility
      AND    ORDERDETAIL.Lottable02 = @cLottable02
      ORDER BY ORDERDETAIL.OrderKey, ORDERDETAIL.OrderLineNumber

      IF @b_debug = 1
      BEGIN
        SELECT 'BULK -', 'Cursor Result', @cStorerKey '@cStorerKey', @cSKU '@cSKU', @cLottable02 '@cLottable02'
        SELECT LLL.LOT,
               LLL.LOC,
               LLL.ID,
               CASE WHEN (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED - ISNULL(LLIMoveOut.Qty,0) )
                      > (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated - ISNULL(LOTMoveOut.Qty,0))
                    THEN (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated - ISNULL(LOTMoveOut.Qty,0)) -
                         (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated - ISNULL(LOTMoveOut.Qty,0)) % CAST(PACK.CaseCnt as int)
                    ELSE (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED - ISNULL(LLIMoveOut.Qty,0)) -
                         (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED - ISNULL(LLIMoveOut.Qty,0)) % CAST(PACK.CaseCnt as int)
               END As QtyAvailable,
               CAST(PACK.CaseCnt as int) as CaseCnt,
               PACK.PACKUOM3
         FROM LOTxLOCxID  LLL (NOLOCK)
         JOIN LOC (NOLOCK) ON (LLL.Loc = LOC.LOC)
         JOIN SKUxLOC (NOLOCK) ON (LLL.Storerkey = SKUxLOC.Storerkey
                  AND LLL.Sku = SKUxLOC.Sku
                  AND LLL.Loc = SKUxLOC.Loc
                  AND SKUxLOC.Locationtype NOT IN ('CASE', 'PICK'))
         JOIN SKU (NOLOCK) ON (LLL.Storerkey = SKU.Storerkey
                  AND LLL.Sku = SKU.Sku
                  AND SKU.Storerkey = @cStorerKey
                  AND SKU.Sku = @cSKU )
         JOIN PACK (NOLOCK) ON (PACK.PackKey = SKU.PackKey)
         JOIN LOT (NOLOCK) ON (LOT.LOT = LLL.LOT)
         -- SOS#41039 By SHONG
         JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.LOT = LLL.LOT
         JOIN ID (NOLOCK) ON ( LLL.ID = ID.ID )
         LEFT OUTER JOIN ( SELECT LOT, FromLOC, ID,  ISNULL(SUM(Qty), 0) As Qty
                           FROM REPLENISHMENT (NOLOCK )
                           WHERE Confirmed IN ('W', 'S')
                           AND   StorerKey = @cStorerKey
                           AND   SKU = @cSKU
                           AND   TOLOC <> 'PICK'
                           GROUP BY LOT, FromLOC, ID)
                           AS LLIMoveOut ON LLIMoveOut.LOT = LLL.LOT AND LLIMoveOut.FromLOC = LLL.LOC
                                        AND LLIMoveOut.ID = LLL.ID
         LEFT OUTER JOIN ( SELECT LOT, ISNULL(SUM(Qty), 0) As Qty
                           FROM REPLENISHMENT (NOLOCK )
                           WHERE Confirmed IN ('W', 'S')
                           AND   StorerKey = @cStorerKey
                           AND   SKU = @cSKU
                           AND   TOLOC <> 'PICK'
                           AND   Remark In ('Bulk to DP', 'PP to DP')
                           GROUP BY LOT, FromLOC, ID)
                           AS LOTMoveOut ON LOTMoveOut.LOT = LLL.LOT
         WHERE LOC.Facility = @cFacility
         AND LOC.Locationflag <>'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOT.Status = 'OK'
         AND ID.Status = 'OK'
         AND LOC.LocationType NOT IN ('DYNAMICPK')
         AND (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED) >= PACK.CaseCnt
         AND LLL.Storerkey = @cStorerKey
         AND LLL.Sku = @cSKU
         AND LOTATTRIBUTE.Lottable02 = @cLottable02
         AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated - LOT.QtyOnHold) >=  0
         ORDER BY CASE LOC.Locationtype   WHEN 'BBA'  -- 7 Dec 2004 - YTWAN FBR010 - Allocation from BBA
                THEN 5
                ELSE 99
                END,
                CASE Loc.LocationHandling   WHEN '2'
                THEN 5
                WHEN '1'
                THEN 10
                WHEN '9'
                THEN 15
                ELSE 99
           END,
          (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED), LLL.LOC, LLL.LOT, LLL.ID
      END -- @b_debug = 1

      IF @b_Cursor_Opened = 1
      BEGIN
         CLOSE Bulk_Lot_Cursor
         DEALLOCATE Bulk_Lot_Cursor
         SELECT @b_Cursor_Opened = 0
      END
      -- 20-Aug-2004 YTWan FBR001: allocation - Sort By LocHandling, Qty, Loc, Lot, id
      DECLARE Bulk_Lot_Cursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT LLL.LOT,
               LLL.LOC,
               LLL.ID,
               CASE WHEN (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED - ISNULL(LLIMoveOut.Qty,0) )
                      > (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated - ISNULL(LOTMoveOut.Qty,0))
                    THEN (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated - ISNULL(LOTMoveOut.Qty,0)) -
                         (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated - ISNULL(LOTMoveOut.Qty,0)) % CAST(PACK.CaseCnt as int)
                    ELSE (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED - ISNULL(LLIMoveOut.Qty,0)) -
                         (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED - ISNULL(LLIMoveOut.Qty,0)) % CAST(PACK.CaseCnt as int)
               END As QtyAvailable,
               CAST(PACK.CaseCnt as int) as CaseCnt,
               PACK.PACKUOM3
         FROM LOTxLOCxID  LLL (NOLOCK)
         JOIN LOC (NOLOCK) ON (LLL.Loc = LOC.LOC)
         JOIN SKUxLOC (NOLOCK) ON (LLL.Storerkey = SKUxLOC.Storerkey
                  AND LLL.Sku = SKUxLOC.Sku
                  AND LLL.Loc = SKUxLOC.Loc
                  AND SKUxLOC.Locationtype NOT IN ('CASE', 'PICK'))
         JOIN SKU (NOLOCK) ON (LLL.Storerkey = SKU.Storerkey
                  AND LLL.Sku = SKU.Sku
                  AND SKU.Storerkey = @cStorerKey
                  AND SKU.Sku = @cSKU )
         JOIN PACK (NOLOCK) ON (PACK.PackKey = SKU.PackKey)
         JOIN LOT (NOLOCK) ON (LOT.LOT = LLL.LOT)
         -- SOS#41039 By SHONG
         JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.LOT = LLL.LOT
         JOIN ID (NOLOCK) ON ( LLL.ID = ID.ID )
         LEFT OUTER JOIN ( SELECT LOT, FromLOC, ID,  ISNULL(SUM(Qty), 0) As Qty
                           FROM REPLENISHMENT (NOLOCK )
                           WHERE Confirmed IN ('W', 'S')
                           AND   StorerKey = @cStorerKey
                           AND   SKU = @cSKU
                           AND   TOLOC <> 'PICK'
                           GROUP BY LOT, FromLOC, ID)
                           AS LLIMoveOut ON LLIMoveOut.LOT = LLL.LOT AND LLIMoveOut.FromLOC = LLL.LOC
                                        AND LLIMoveOut.ID = LLL.ID
         LEFT OUTER JOIN ( SELECT LOT, ISNULL(SUM(Qty), 0) As Qty
                           FROM REPLENISHMENT (NOLOCK )
                           WHERE Confirmed IN ('W', 'S')
                           AND   StorerKey = @cStorerKey
                           AND   SKU = @cSKU
                           AND   TOLOC <> 'PICK'
                           AND   Remark In ('Bulk to DP', 'PP to DP')
     GROUP BY LOT, FromLOC, ID)
                           AS LOTMoveOut ON LOTMoveOut.LOT = LLL.LOT
         WHERE LOC.Facility = @cFacility
         AND LOC.Locationflag <>'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOT.Status = 'OK'
         AND ID.Status = 'OK'
         AND LOC.LocationType NOT IN ('DYNAMICPK')
         AND (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED) >= PACK.CaseCnt
         AND LLL.Storerkey = @cStorerKey
         AND LLL.Sku = @cSKU
         AND LOTATTRIBUTE.Lottable02 = @cLottable02
         AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated - Lot.QtyOnHold) >=  0
         ORDER BY CASE LOC.Locationtype   WHEN 'BBA'  -- 7 Dec 2004 - YTWAN FBR010 - Allocation from BBA
                THEN 5
                ELSE 99
                END,
                CASE Loc.LocationHandling   WHEN '2'
                THEN 5
                WHEN '1'
                THEN 10
                WHEN '9'
                THEN 15
                ELSE 99
           END,
          (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED), LLL.LOC, LLL.LOT, LLL.ID

      SELECT @b_Cursor_Opened = 1

      OPEN Bulk_Lot_Cursor

      --IF @@CURSOR_ROWS = 0
      --   CONTINUE

      SET ROWCOUNT 0

      WHILE 1=1 AND (@n_continue = 1 or @n_continue = 2) AND @nBatchQty > 0
      BEGIN
         Fetxh_Next_Bulk_Lot_Cursor:

         FETCH NEXT FROM Bulk_Lot_Cursor INTO @cLOT, @cLOC, @cID, @nQtyAvailable, @nCaseCnt, @cUOM

         IF @@Fetch_Status = -1
         BEGIN
            SET @nBatchQty = 0

            IF @b_debug = 1
            BEGIN
               SELECT 'Break - ', @cLOT '@cLOT', @cLOC '@cLOC', @cID '@cID', @cStorerKey '@cStorerKey',
                      @cSKU '@cSKU', @nQtyAvailable '@nQtyAvailable'
            END

            BREAK
         END

         -- Qty Available should minus qty pending to move in Wave Dynamic Picking Process
         SET @nQtyPendingMoveOut = 0

--         SELECT @nQtyPendingMoveOut = ISNULL(SUM(Qty), 0)
--         FROM REPLENISHMENT (NOLOCK )
--         WHERE Confirmed IN ('W', 'S')
--         AND   LOT     = @cLOT
--         AND   FromLOC = @cLOC
--         AND   ID      = @cID
--         AND   ToLoc <> 'PICK'

         SET  @nQtyAvailable = @nQtyAvailable - @nQtyPendingMoveOut

         SET  @nQtyFullCaseRemain = @nQtyAvailable % CAST(@nCaseCnt as int)

         IF @nQtyFullCaseRemain > 0
            SET  @nQtyAvailable =  @nQtyAvailable - @nQtyFullCaseRemain

         IF @b_debug = 1
         BEGIN
            SELECT 'After minus reserved UCC: ', @cLOT '@cLOT', @cLOC '@cLOC',
                   @cID '@cID', @nQtyAvailable '@nQtyAvailable', @nBatchQty '@nBatchQty'

            SELECT 'BULK -',  UCCNo, Qty
            FROM   UCC WITH (NOLOCK)
            WHERE  LOT = @cLOT
            AND  LOC = @cLOC
            AND  ID  = @cID
            AND  Status = '1'
         END

------- Loop UCC Cursor Here
        DECLARE CUR_UCCAllocate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT UCCNo, Qty
         FROM   UCC WITH (NOLOCK)
         WHERE  LOT = @cLOT
           AND  LOC = @cLOC
           AND  ID  = @cID
           AND  Status = '1'
           AND  Qty = @nCaseCnt

        OPEN CUR_UCCAllocate

        FETCH NEXT FROM CUR_UCCAllocate INTO @cUCCNo, @nUCCQty

        WHILE @@FETCH_STATUS <> -1 AND @nBatchQty > 0 AND @nQtyAvailable > 0
        BEGIN
           IF @b_debug = 1
           BEGIN
              SELECT 'BULK -', @cUCCNo '@cUCCNo', @nUCCQty '@nUCCQty'
              SELECT 'BULK -', 'OrderDetail Result'
              SELECT * FROM @tORDERDETAIL
           END
           SET @cUCCRemainQty = @nUCCQty

           WHILE 1=1 AND @cUCCRemainQty > 0
           BEGIN
              SET ROWCOUNT 1
              SELECT @cOrderKey        = OrderKey,
                     @cOrderLineNumber = OrderLineNumber,
                     @nOpenQty         = OpenQty
              FROM @tORDERDETAIL
              WHERE OpenQty > 0
              ORDER BY OrderKey, OrderLineNumber

              IF @@ROWCOUNT = 0
              BEGIN
                 SET ROWCOUNT 0
                 BREAK
              END
              SET ROWCOUNT 0

              IF @b_debug = 1
              BEGIN
                 SELECT 'BULK -', @cOrderKey '@cOrderKey', @cOrderLineNumber '@cOrderLineNumber', @nOpenQty '@nOpenQty'
              END

              WHILE 1=1 and @nOpenQty > 0 and @cUCCRemainQty > 0
              BEGIN
                 IF dbo.fnc_RTRIM(@cLOC) IS NOT NULL AND dbo.fnc_RTRIM(@cLOC) <> ''
                 BEGIN
                    GET_NEXT_BULK_LOT:


                    IF @cUCCRemainQty > @nOpenQty
                       SELECT @nQtyToTake = @nOpenQty
                    ELSE
                       SELECT @nQtyToTake = @cUCCRemainQty

                    INSERT INTO @tPICKDETAIL (
                             OrderKey,    OrderLineNumber,
                             Lot,               Loc,         ID,
                             Storerkey,         Sku,         Qty)
                    VALUES (@cOrderKey,    @cOrderLineNumber,
                            @cLOT,         @cLOC,            @cID,
                            @cStorerKey,   @cSKU,            @nQtyToTake)

                    SELECT @nOpenQty = @nOpenQty - @nQtyToTake
                    SELECT @cUCCRemainQty = @cUCCRemainQty - @nQtyToTake
                    SELECT @nQtyAvailable = @nQtyAvailable - @nQtyToTake
                    SELECT @nBatchQty = @nBatchQty - @nQtyToTake

                    UPDATE #TempBatchPick
                       SET Qty = Qty - @nQtyToTake
                     WHERE StorerKey = @cStorerKey
                       AND SKU = @cSKU
                       AND Lottable02 = @cLottable02
                       AND Qty > 0

                    UPDATE @tOrderDetail
                       SET OpenQty = OpenQty - @nQtyToTake
                     WHERE OrderKey = @cOrderKey
                     AND   OrderLineNumber = @cOrderLineNumber

                    IF @b_debug = 1
                    BEGIN
                       select @nOpenQty '@nOpenQty', @nQtyToTake '@nQtyToTake',
                              @nBatchQty '@nBatchQty', @nUCCQty '@nUCCQty',
                              @cUCCNo '@cUCCNo', @cUCCRemainQty '@cUCCRemainQty'
                    END

                    IF @nBatchQty <= 0 -- OR @nQtyAvailable <= 0
                    BEGIN
                       BREAK
                    END
                 END -- if loc is not null
              END -- While Looking for Location
           END -- While @tOrderDetail

           UPDATE UCC WITH (ROWLOCK)
             SET Status = '3', UserDefined01 = @c_oskey
           WHERE UCCNO = @cUCCNo

-------- Insert Replenishment
            EXECUTE nspg_GetKey
               @keyname       = 'REPLENISHKEY', --Leong01
               @fieldlength   = 10,
               @keystring     = @cReplenishmentKey  OUTPUT,
               @b_success     = @b_success   OUTPUT,
               @n_err         = @n_err       OUTPUT,
               @c_errmsg      = @c_errmsg    OUTPUT

            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
            ELSE
            BEGIN
               INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                   StorerKey,      SKU,       FromLOC,      ToLOC,
                   Lot,      Id,        Qty,          UOM,
                   PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                   RefNo,          Confirmed, ReplenNo,     Remark,
                   LoadKey,        DropID )
               VALUES (
                   @cReplenishmentKey,       @c_oskey,
                   @cStorerKey,   @cSKU,     @cLOC,           'PICK',
                   @cLOT,         @cID,      @nUCCQty,        @cUOM,
                   @cPackkey,     '1',        0,              0,
                   @cUCCNo,       'Y',        '',             'FCP',
                   @c_oskey,      'L'  )

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63507   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                  GOTO SP_RETURN
               END

            END -- Insert Replenishment
-------- End Insert Replenishment
           FETCH NEXT FROM CUR_UCCAllocate INTO @cUCCNo, @nUCCQty
        END -- While Loop Cur_UCCAllocate
        CLOSE CUR_UCCAllocate
        DEALLOCATE CUR_UCCAllocate
---- End UCC Loop
---- Insert PickDetail Here
        IF @n_continue = 1 or @n_continue = 2
        BEGIN
           IF CURSOR_STATUS('LOCAL', 'CUR_TempPickDetail') = 1
           BEGIN
              CLOSE CUR_TempPickDetail
              DEALLOCATE CUR_TempPickDetail
           END

           DECLARE CUR_TempPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
              SELECT P.OrderKey,    P.OrderLineNumber, SKU.PackKey,
                     P.Lot,         P.Loc,         P.ID,
                     P.Storerkey,   P.Sku,         SUM(P.Qty) As Qty
              FROM @tPICKDETAIL P
              JOIN SKU (NOLOCK) ON SKU.StorerKey = P.StorerKey AND SKU.SKU = P.SKU
              GROUP BY P.OrderKey,    P.OrderLineNumber,  SKU.PackKey,
                       P.Lot,         P.Loc,              P.ID,
                       P.Storerkey,   P.Sku


          OPEN CUR_TempPickDetail

          FETCH NEXT FROM CUR_TempPickDetail INTO
             @cOrderKey,    @cOrderLineNumber,   @cPackKey,
             @cLot,         @cLoc,         @cID,
             @cStorerkey,   @cSku,         @nQtyToTake

          WHILE @@FETCH_STATUS <> -1
          BEGIN
            SELECT @b_success = 0
            EXECUTE   nspg_getkey
            'PickDetailKey'
            , 10
            , @cPickDetailKey OUTPUT
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT

            IF @b_success = 1
            BEGIN
               IF @b_debug = 1
               BEGIN
                  select 'Insert PickDetail (Carton):', @cPickDetailKey '@cPickDetailKey',  @cOrderKey '@cOrderKey',
                         @cOrderLineNumber '@cOrderLineNumber',
                         @cLot '@cLot',   @cStorerkey '@cStorerkey',
                         @cSKU '@cSKU',   @cPackKey '@cPackKey',
                         @nQtyToTake '@nQtyToTake',
                         @cLoc '@cLoc',   @cID '@cID'
               END

               INSERT PICKDETAIL ( PickDetailKey, Caseid,     PickHeaderkey, OrderKey,      OrderLineNumber, Lot, Storerkey,
                                   Sku,           PackKey,    UOM,           UOMQty,        Qty,             Loc, ID,
                                   Cartongroup,   Cartontype, DoReplenish,   ReplenishZone, DoCartonize,     Trafficcop,
                                   PickMethod) VALUES
                               (@cPickDetailKey,   '',          '',             @cOrderKey,    @cOrderLineNumber,   @cLot,   @cStorerkey,
                                  @cSKU,             @cPackKey,   '2',            @nQtyToTake,   @nQtyToTake,         @cLoc,  @cID,
                                  '',                'FCP',       '',             '',            'N',                 'C',    '8' )

               SELECT @n_err = @@ERROR, @n_cnt_sql = @@ROWCOUNT

               SELECT @n_cnt = COUNT(1) FROM PICKDETAIL with (NOLOCK) WHERE PICKDETAILKEY = @cPickDetailKey

               if (@b_debug = 1 or @b_debug = 2) and (@n_cnt_sql <> @n_cnt)
               begin
                  print 'INSERT PickDetail @@ROWCOUNT gets wrong'
                  select '@@ROWCOUNT' = @n_cnt_sql, 'COUNT(*)' = @n_cnt
               end

               DELETE @tPickDetail
               WHERE OrderKey = @cOrderKey
               AND   OrderLineNumber = @cOrderLineNumber
               AND   Lot = @cLot
               AND   Loc = @cLoc
               AND   ID  = @cID

            END -- IF @b_success = 1
            FETCH NEXT FROM CUR_TempPickDetail INTO
                  @cOrderKey,    @cOrderLineNumber,   @cPackKey,
                  @cLot,         @cLoc,         @cID,
                  @cStorerkey,   @cSku,         @nQtyToTake
          END
          CLOSE CUR_TempPickDetail
          DEALLOCATE CUR_TempPickDetail
        END -- @n_continue = 1 or @n_continue = 2  Insert PickDetail

---- End Insert PickDetail
      END -- Loop Lot
      CLOSE Bulk_Lot_Cursor
      DEALLOCATE Bulk_Lot_Cursor
      SELECT @b_Cursor_Opened = 0

      SET @nBatchQty = 0
      SET @nCaseCnt = 0

      FETCH NEXT FROM C_Carton_PICK INTO
                @cSKU,              @cStorerKey,             @nBatchQty,
                @cPackKey,          @nCaseCnt,               @cFacility,
                @cLottable02 -- SOS#42319
   END -- Loop SKU
   CLOSE C_Carton_PICK
   DEALLOCATE C_Carton_PICK

   IF @b_Cursor_Opened = 1
   BEGIN
      CLOSE Bulk_Lot_Cursor
      DEALLOCATE Bulk_Lot_Cursor
      SELECT @b_Cursor_Opened = 0
   END

--------------------------------------------------------------------------------------------------
TakeFromPickLocation:
--------------------------------------------------------------------------------------------------
   CREATE TABLE #ExcludeLot  (LOT NVARCHAR(10))
   CREATE TABLE #ExcludeLoc  (LOC NVARCHAR(10))

   WHILE 1=1 AND (@n_continue = 1 or @n_continue = 2)
   BEGIN
      SET ROWCOUNT 1

      SELECT @nQty       = SUM(T.Qty),
             @cStorerKey = T.StorerKey,
             @cSKU       = T.SKU,
             @cPackKey   = SKU.PackKey,
             @cFacility  = T.Facility,
             @cLottable02 = T.Lottable02
      FROM   #TempBatchPick T
      JOIN   SKU (NOLOCK) ON (SKU.StorerKey = T.StorerKey AND SKU.SKU = T.SKU)
      WHERE  T.Qty > 0
      GROUP BY T.StorerKey, T.SKU, SKU.PackKey, T.Facility, T.Lottable02
      ORDER BY T.Facility, T.StorerKey, T.SKU, T.Lottable02

      IF @@ROWCOUNT = 0
      BEGIN
         SET ROWCOUNT 0
         BREAK
      END

      SET ROWCOUNT 0

      IF @b_debug = 1
      BEGIN
         SELECT 'PICK - ',
                @nQty       AS QTY,
                @cStorerKey AS StorerKey,
                @cSKU       AS SKU,
                @cPackKey   as PackKey,
                @cLottable02 as Lottable02
      END

      IF @b_debug = 1
      BEGIN
         SELECT 'PICK - ', OrderDetail.OrderKey,
                OrderDetail.OrderLineNumber,
                ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked as Qty
         FROM   OrderDetail (NOLOCK)
         JOIN   LoadPlanDetail (NOLOCK) ON (LoadPlanDetail.OrderKey = OrderDetail.OrderKey)
         WHERE  OrderDetail.StorerKey = @cStorerKey
         AND    OrderDetail.SKU = @cSKU
         AND    LoadPlanDetail.LoadKey = @c_oskey
         AND    ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked > 0
         AND    ORDERDETAIL.Lottable02 = @cLottable02
         ORDER BY ORDERDETAIL.OrderKey, ORDERDETAIL.OrderLineNumber
      END

      DECLARE OrderDetCur Cursor LOCAL FAST_FORWARD READ_ONLY For
         SELECT OrderDetail.OrderKey,
                OrderDetail.OrderLineNumber,
                ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked as Qty
         FROM   OrderDetail (NOLOCK)
         JOIN   LoadPlanDetail (NOLOCK) ON (LoadPlanDetail.OrderKey = OrderDetail.OrderKey)
         JOIN   ORDERS (NOLOCK) ON (ORDERS.OrderKey = OrderDetail.OrderKey)
         WHERE  OrderDetail.StorerKey = @cStorerKey
         AND    OrderDetail.SKU = @cSKU
         AND    LoadPlanDetail.LoadKey = @c_oskey
         AND    ORDERS.Facility = @cFacility
         AND    ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked > 0
         AND    ORDERDETAIL.Lottable02 = @cLottable02
         ORDER BY ORDERDETAIL.OrderKey, ORDERDETAIL.OrderLineNumber


      OPEN OrderDetCur

      FETCH NEXT FROM OrderDetCur INTO @cOrderKey, @cOrderLineNumber, @nOpenQty

      WHILE @@FETCH_STATUS <> -1 and @nQty > 0
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT 'PICK - ', @cOrderKey '@cOrderKey', @cOrderLineNumber '@cOrderLineNumber', @nOpenQty '@nOpenQty'
         END

         -- SOS126009
         --SET    @cNonGradedProduct = '0'
         --SELECT @cNonGradedProduct = ISNULL(sValue, '0')
         --FROM   StorerConfig WITH (NOLOCK)
         --WHERE  StorerKey = @cStorerKey
         --  AND  ConfigKey = 'NonGradedProduct'

         --IF ISNULL( RTRIM(@cNonGradedProduct), '') = ''
         --   SET @cNonGradedProduct = '0'

         SELECT @b_success = 0
         Execute nspGetRight @cFacility,   -- facility
                           @cStorerKey,    -- Storerkey
                           @cSKU,          -- Sku
                           'ALLOWOVERALLOCATIONS', -- Configkey
                           @b_success     output,
                           @cAllowOverAllocations output,
                           @n_err         output,
                           @c_errmsg      output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'nsporderprocessing' + dbo.fnc_RTRIM(@c_errmsg)
         END
         ELSE
         BEGIN
            IF @cAllowOverAllocations is null
            BEGIN
               SELECT @cAllowOverAllocations = '0'
            END
            IF @b_debug = 1
            BEGIN
               SELECT 'PICK - ', 'ALLOWOVERALLOCATIONS' = @cAllowOverAllocations
            END
         END

         SELECT @cLOT = ''
         WHILE 1=1 and @nOpenQty > 0 and @nQty > 0
         BEGIN
            GET_NEXT_PICK_LOT:

            -- Get From CASE/PICK Location
            SET ROWCOUNT 1

            SET @nQtyAvailable = 0
            SELECT @cLOT = LOTxLOCxID.Lot,
                   @cLOC = LOTxLOCxID.LOC,
                   @cID  = LOTxLOCxID.ID,
                   @nQtyAvailable = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED)
            FROM LOTxLOCxID (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
            JOIN SKUxLOC WITH (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
                                          AND LOTxLOCxID.Sku = SKUxLOC.Sku
                                          AND LOTxLOCxID.Loc = SKUxLOC.Loc
            JOIN LOT WITH (NOLOCK) ON LOT.LOT = LOTxLOCxID.LOT
            JOIN ID WITH (NOLOCK) ON ID.ID = LOTxLOCxID.ID
            JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
            WHERE SKUxLOC.Locationtype IN ('CASE', 'PICK')
            AND LOC.Facility = @cFacility
            AND LOC.Locationflag <>'HOLD'
            AND LOC.Locationflag <> 'DAMAGE'
            AND LOC.Status <> 'HOLD'
            -- SOS#41039 By SHONG
            AND LOT.Status = 'OK'
            AND ID.Status = 'OK'
            -- SOS#41039
            AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0
            AND LOTxLOCxID.Storerkey = @cStorerkey
            AND LOTxLOCxID.Sku = @cSku
            AND LOTxLOCxID.LOT NOT IN (SELECT LOT FROM #ExcludeLot)
            AND LOTxLOCxID.LOC NOT IN (SELECT LOC FROM #ExcludeLoc)
            AND LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated - LOT.QtyOnHold > 0
            AND LOTATTRIBUTE.Lottable02 = @cLottable02
            ORDER BY LOTxLOCxID.LOT, LOTxLOCxID.Qty, LOTxLOCxID.LOC, LOTxLOCxID.ID


            IF @@ROWCOUNT = 0  -- if Record not found in Pick Location
            BEGIN  -- Get from Bulk Location
               IF @b_debug = 1
                  SELECT 'PICK -', 'Get From BULK'

               -- Select any LOT available
               SET ROWCOUNT 1

               SELECT @cLOT = LOTxLOCxID.Lot,
                      @cLOC = LOTxLOCxID.LOC,
                      @cID  = LOTxLOCxID.ID,
                      --@nQtyAvailable = (LOTxLOCxID.Qty + ISNULL(MoveInLLL.Qty,0) )
                      @nQtyAvailable = (LOTxLOCxID.Qty )
                                 - ( LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked + ISNULL(MoveOutLLL.Qty,0) )
               FROM LOTxLOCxID (NOLOCK)
               JOIN  LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
               JOIN  SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
                                       AND LOTxLOCxID.Sku = SKUxLOC.Sku
                                       AND LOTxLOCxID.Loc = SKUxLOC.Loc
               JOIN  LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
               JOIN  ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID
               JOIN  LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
               LEFT OUTER JOIN (SELECT LOT, FromLOC, ID, SUM(Qty) As Qty
                               FROM REPLENISHMENT (NOLOCK )
                               WHERE Confirmed in ('W','S') AND Toloc <> 'PICK'
                                 AND REPLENISHMENT.Storerkey = @cStorerkey
                                 AND REPLENISHMENT.Sku = @cSku
                               GROUP BY LOT, FromLOC, ID) AS MoveOutLLL
                                    ON MoveOutLLL.LOT = LOTxLOCxID.LOT AND
                                       MoveOutLLL.FromLOC = LOTxLOCxID.LOC AND
                                       MoveOutLLL.ID = LOTxLOCxID.ID
               WHERE LOC.Facility = @cFacility
               AND LOC.Locationflag <>'HOLD'
               AND LOC.Locationflag <> 'DAMAGE'
               AND LOC.Status <> 'HOLD'
               -- AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0
               AND LOTxLOCxID.Storerkey = @cStorerkey
               AND LOTxLOCxID.Sku = @cSku
               AND LOTxLOCxID.LOT NOT IN (SELECT LOT FROM #ExcludeLot)
               AND LOT.Status = 'OK'
               AND ID.Status = 'OK'
               AND LOTATTRIBUTE.Lottable02 = @cLottable02
               AND SKUxLOC.Locationtype NOT IN ('CASE', 'PICK')
               -- AND (LOTxLOCxID.Qty + ISNULL(MoveInLLL.Qty,0) )
               AND (LOTxLOCxID.Qty ) - ( LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked + ISNULL(MoveOutLLL.Qty,0) ) > 0
               ORDER BY CASE Loc.LocationHandling WHEN '2'
                 THEN 5
                 WHEN '1'
                 THEN 10
                 WHEN '9'
                 THEN 15
                 ELSE 99
               END,
               (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), LOTxLOCxID.LOC, LOTxLOCxID.LOT, LOTxLOCxID.ID

               SET @nRowCount = @@ROWCOUNT

               IF @nRowCount = 0
               BEGIN
                  if @b_debug = 1
                     select 'PICK - (No Qty Available in BULK)', @cSKU '@cSKU'

                  -- Check is there any Qty Available for Pending Move In (Wave)
-----------------
                  if @b_debug = 1
                     select 'PICK - (Get Wave Pending Move Qty)', @cSKU '@cSKU'

                  SET @nQtyAvailable = 0
                  SELECT @cLOT = LOTxLOCxID.Lot,
                         @cLOC = LOTxLOCxID.LOC,
                         @cID  = LOTxLOCxID.ID,
                         @nQtyAvailable = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) +
                                          ( ISNULL(QtyPendingMoveIn, 0) - ISNULL(QtyPendingMoveOut, 0) )
                  FROM LOTxLOCxID (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
                  JOIN SKUxLOC WITH (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
                                                AND LOTxLOCxID.Sku = SKUxLOC.Sku
                                                AND LOTxLOCxID.Loc = SKUxLOC.Loc
                  JOIN LOT WITH (NOLOCK) ON LOT.LOT = LOTxLOCxID.LOT
                  JOIN ID WITH (NOLOCK) ON ID.ID = LOTxLOCxID.ID
                  JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
                  LEFT OUTER JOIN (SELECT LOT, FromLOC, ID, ISNULL(SUM(Qty), 0) as QtyPendingMoveOut
                                   FROM REPLENISHMENT (NOLOCK )
                                   WHERE Confirmed IN ('W', 'S')
                                   AND   StorerKey = @cStorerkey
                                   AND   SKU       = @cSku
                                   GROUP By LOT, FromLOC, ID) AS LLI_OUT
                                   ON LLI_OUT.LOT = LOTxLOCxID.LOT AND LLI_OUT.FromLOC = LOTxLOCxID.LOC
                                      AND LLI_OUT.ID = LOTxLOCxID.ID
                  LEFT OUTER JOIN (SELECT LOT, ToLOC, ID, ISNULL(SUM(Qty), 0) as QtyPendingMoveIn
                                   FROM REPLENISHMENT (NOLOCK )
                                   WHERE Confirmed IN ('W', 'S')
                                   AND   StorerKey = @cStorerkey
                                   AND   SKU       = @cSku
                                   GROUP By LOT, ToLOC, ID) AS LLI_IN
                                   ON LLI_IN.LOT = LOTxLOCxID.LOT AND LLI_IN.ToLOC = LOTxLOCxID.LOC
                                      AND LLI_IN.ID = LOTxLOCxID.ID
                  WHERE SKUxLOC.Locationtype IN ('CASE', 'PICK')
                  AND LOC.Facility = @cFacility
                  AND LOC.Locationflag <>'HOLD'
                  AND LOC.Locationflag <> 'DAMAGE'
                  AND LOC.Status <> 'HOLD'
                  AND LOT.Status = 'OK'
                  AND ID.Status = 'OK'
                  AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) +
                      ( ISNULL(QtyPendingMoveIn, 0) - ISNULL(QtyPendingMoveOut, 0) ) > 0
                  AND LOTxLOCxID.Storerkey = @cStorerkey
                  AND LOTxLOCxID.Sku = @cSku
                  -- AND LOTxLOCxID.LOT NOT IN (SELECT LOT FROM #ExcludeLot)
                  -- AND LOTxLOCxID.LOC NOT IN (SELECT LOC FROM #ExcludeLoc)
                  AND LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated - LOT.QtyOnHold > 0
                  AND LOTATTRIBUTE.Lottable02 = @cLottable02
                  ORDER BY LOTxLOCxID.LOT, LOTxLOCxID.Qty, LOTxLOCxID.LOC, LOTxLOCxID.ID

                  SET @nRowCount = @@ROWCOUNT

                  -- 20080815
                  IF @nRowCount = 0
                  BEGIN
                     if @b_debug = 1
                        select 'PICK - (Get Wave Pending Move In Qty Where LOT not in Pick Loc)', @cSKU '@cSKU'


                     SELECT @cLOT = REPLENISHMENT.Lot,
                            @cLOC = REPLENISHMENT.ToLOC,
                            @cID  = REPLENISHMENT.ID,
                            @nQtyAvailable = SUM(REPLENISHMENT.Qty) - SUM(ISNULL(LLI_OUT.QtyPendingMoveOut,0))
                     FROM REPLENISHMENT (NOLOCK)
                     JOIN SKUxLOC WITH (NOLOCK) ON REPLENISHMENT.Storerkey = SKUxLOC.Storerkey
                                                   AND REPLENISHMENT.Sku = SKUxLOC.Sku
                                                   AND REPLENISHMENT.ToLoc = SKUxLOC.Loc
                                                   AND SKUxLOC.Locationtype IN ('CASE', 'PICK')
                                                   AND SKUxLOC.StorerKey = @cStorerKey
                                                   AND SKUxLOC.SKU       = @cSKU
                     JOIN LOC WITH (NOLOCK) ON LOC.LOC = SKUxLOC.LOC
                     JOIN (SELECT LOT, FromLOC, ID, Qty as QtyPendingMoveOut
                                      FROM REPLENISHMENT (NOLOCK )
                                      WHERE Confirmed IN ('W', 'S')
                                      AND   ToLOC <> 'PICK'
                                      AND   StorerKey = @cStorerKey
                                      AND   SKU       = @cSKU) AS LLI_OUT
                                      ON LLI_OUT.LOT = REPLENISHMENT.LOT
                                         AND LLI_OUT.FromLOC = REPLENISHMENT.ToLOC
                                         AND LLI_OUT.ID = REPLENISHMENT.ID
                     LEFT OUTER JOIN LOTxLOCxID LLI (NOLOCK) ON REPLENISHMENT.LOT = LLI.LOT
                                                   AND REPLENISHMENT.ToLOC = LLI.LOC
                                                   AND REPLENISHMENT.ID = LLI.ID
                                                   AND LLI.StorerKey = @cStorerKey
                                                   AND LLI.SKU       = @cSKU
                     WHERE REPLENISHMENT.Confirmed IN ('W', 'S')
                     AND   REPLENISHMENT.ToLOC <> 'PICK'
                     AND   REPLENISHMENT.StorerKey = @cStorerKey
                     AND   REPLENISHMENT.SKU       = @cSKU
                     AND   LOC.Facility = @cFacility
                     AND   LLI.LOT IS NULL
                     GROUP BY REPLENISHMENT.Lot,
                               REPLENISHMENT.ToLOC,
                               REPLENISHMENT.ID

                     SET @nRowCount = @@ROWCOUNT

                  END
-----------------
                  IF @nRowCount = 0
                  BEGIN
                     -- Teminate
                     if @b_debug = 1
                        select 'PICK - BREAK', @cSKU '@cSKU', @cFacility '@cFacility'

                     SET ROWCOUNT 0
                     SELECT @nQty = 0

                     DELETE FROM   #TempBatchPick
                     WHERE  SKU = @cSKU
                     AND    StorerKey = @cStorerKey
                     AND    Lottable02 = @cLottable02

                     BREAK
                  END
               END

               -- IF @@ROWCOUNT = 0
               if @b_debug = 1
                  select 'PICK -', @cSKU '@cSKU', @cLOT '@cLOT',
                            @cLOC '@cLOC',
                            @cID  '@cID',
                            @nQtyAvailable '@nQtyAvailable'

               BEGIN
                  SET ROWCOUNT 0
                  IF @cAllowOverAllocations = '1'
                  -- SOS126009
                  AND ( EXISTS(SELECT 1
                                 FROM  CODELKUP (NOLOCK)
                                 WHERE Listname = 'GRADE_A'
                                 AND   Code = @cLottable02))
                        --OR @cNonGradedProduct = '1' )
                  BEGIN
                     -- If OverAllocation Turn On, Force to get from Pick Location
                     SELECT @cPickLOC = MIN(SKUxLOC.LOC)
                     FROM   SKUxLOC (NOLOCK)
                     JOIN   LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC)
                     WHERE  SKUxLOC.StorerKey = @cStorerKey
                     AND    SKUxLOC.SKU       = @cSKU
                     AND    SKUxLOC.LocationType IN ('CASE', 'PICK')
                     AND    SKUxLOC.LOC > ''
                     AND    LOC.Facility = @cFacility
         -- SOS43971 In case user setup pickface as damange/hold location
                     AND LOC.Locationflag <>'HOLD'
                     AND LOC.Locationflag <> 'DAMAGE'
                     AND LOC.Status <> 'HOLD'

                     IF dbo.fnc_RTRIM(@cPickLOC) IS NOT NULL AND dbo.fnc_RTRIM(@cPickLOC) <> ''
                     BEGIN
                        -- if Pick Location Available and Overallocation is turn on
                        -- Force to pick from Pick Location
                        SELECT @cID = ''
                        SELECT @cLOC = @cPickLOC

                        -- Get the Qty Avaliable from LOT becuase, cause it's not in Pick Location
                        SELECT @nQtyPendingMoveOut = ISNULL(SUM(Qty), 0)
                        FROM REPLENISHMENT (NOLOCK )
                        WHERE Confirmed IN ('W', 'S')
                        AND   LOT     = @cLOT
                        AND   TOLOC <> 'PICK'
                        AND   Remark In ('Bulk to DP', 'PP to DP')

                        SELECT @nLotQty = ( LOT.Qty ) - (QTYALLOCATED + QTYPICKED + QTYPREALLOCATED + QtyOnHold )
                        FROM   LOT (NOLOCK)
                        WHERE  LOT = @cLOT

                       if @b_debug = 1
                           select 'PICK - ', @nLotQty '@nLotQty', @nQtyAvailable '@nQtyAvailable' ,
                                  @nQtyPendingMoveIn '@nQtyPendingMoveIn', @nQtyPendingMoveOut '@nQtyPendingMoveOut'

                       SET  @nLotQty = @nLotQty - @nQtyPendingMoveOut

                        IF @nLotQty < @nQtyAvailable
                           SELECT @nQtyAvailable = @nLotQty

                        IF @nLotQty <= 0
                        BEGIN
                           INSERT INTO #ExcludeLot VALUES (@cLOT)

                           GOTO GET_NEXT_PICK_LOT
                        END

                        -- if location not in LOTxLOCxID, Insert a row into LOTxLOCxID
                        IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE LOT = @cLOT and LOC = @cLOC and ID = '')
                        BEGIN
                           INSERT INTO LOTxLOCxID (StorerKey, SKU, LOT, LOC, ID, Qty)
                                VALUES (@cStorerKey, @cSKU, @cLOT, @cLOC, @cID, 0)
                        END
                     END -- dbo.fnc_RTRIM(@cPickLOC) IS NOT NULL AND dbo.fnc_RTRIM(@cPickLOC) <> ''
                     ELSE
                     BEGIN
                        IF @c_PickLooseFromBulk <> 1
                        BEGIN
                           SELECT @nQtyAvailable = 0
                           SELECT @cLOC = ''

                           DELETE FROM   #TempBatchPick
                           WHERE  SKU = @cSKU
                           AND    StorerKey = @cStorerKey
                           AND    Lottable02 = @cLottable02

                           BREAK
                        END
                     END
                  END --  @cAllowOverAllocations = '1'
               END -- @@ROWCOUNT > 0 (select any lot)
            END -- @@ROWCOUNT > 0 (Lot in Pick Location)
            ELSE
            BEGIN -- If Records Found in Pick Location
               -- SHONG20080729
               -- Pick Loc Have Qty, check whether it reserved by Wave's Allocation or not.
               SELECT @nQtyPendingMoveOut = ISNULL(SUM(Qty), 0)
               FROM REPLENISHMENT (NOLOCK )
               WHERE Confirmed IN ('W', 'S')
               AND   LOT     = @cLOT
               AND   FromLOC = @cLOC
               AND   ID      = @cID

               SELECT @nQtyPendingMoveIn = ISNULL(SUM(Qty),0)
               FROM REPLENISHMENT (NOLOCK )
               WHERE Confirmed IN ('W', 'S')
     AND   LOT     = @cLOT
               AND   ToLOC   = @cLOC
               AND   ID      = @cID

               if @b_debug = 1
                  select 'PICK - ', @nQtyPendingMoveIn '@nQtyPendingMoveIn', @nQtyPendingMoveOut '@nQtyPendingMoveOut',
                         @nQtyAvailable '@nQtyAvailable'

               IF @nQtyPendingMoveIn < @nQtyPendingMoveOut
                  SET @nQtyAvailable = @nQtyAvailable - (@nQtyPendingMoveOut - @nQtyPendingMoveIn)

               IF @nQtyAvailable <= 0
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT 'PICK - ', 'Get Next, Exclude Loc' = @cLOC
                  END

                  INSERT INTO #ExcludeLoc VALUES (@cLOC)
                  GOTO GET_NEXT_PICK_LOT
               END
            END

            SET ROWCOUNT 0

            IF dbo.fnc_RTRIM(@cLOC) IS NOT NULL AND dbo.fnc_RTRIM(@cLOC) <> '' AND @nQtyAvailable > 0
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT 'PICK - ', @cLOC as [LOC],
                         @cID  as [ID],
                         @nQtyAvailable as [QtyAvailable]
               END

               IF @nQtyAvailable > @nOpenQty
               BEGIN
                  IF @nOpenQty <= @nQty
                     SELECT @nQtyToTake = @nOpenQty
                  ELSE
                     SELECT @nQtyToTake = @nQty
               END
               ELSE
               BEGIN
                  IF @nQtyAvailable = 0
                     AND @cAllowOverAllocations = '1'
                     AND ( EXISTS(SELECT 1
                                 FROM  CODELKUP (NOLOCK)
                                 WHERE Listname = 'GRADE_A'
                                 AND   Code = @cLottable02))
                           -- OR @cNonGradedProduct = '1' )
                  BEGIN
                     SELECT @nQtyToTake = @nOpenQty
                  END
                  ELSE
                  BEGIN
                     IF @nQtyAvailable <= @nQty
                        SELECT @nQtyToTake = @nQtyAvailable
                     ELSE
                        SELECT @nQtyToTake = @nQty
                  END
               END


               IF @n_continue = 1 or @n_continue = 2 AND @nQtyToTake > 0
               BEGIN
                  SELECT @b_success = 0
                  EXECUTE   nspg_getkey
                  'PickDetailKey'
                  , 10
                  , @cPickDetailKey OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

                  IF @b_success = 1
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'PICK - ', 'Insert PickDetail :', @cPickDetailKey '@cPickDetailKey',  @cOrderKey '@cOrderKey',
                               @cOrderLineNumber '@cOrderLineNumber',
                               @cLot '@cLot',   @cStorerkey '@cStorerkey',
                               @cSKU '@cSKU',   @cPackKey '@cPackKey',
                               @nQtyToTake '@nQtyToTake',
                               @cLoc '@cLoc',   @cID '@cID'
                     END

                     INSERT PICKDETAIL ( PickDetailKey, Caseid,     PickHeaderkey, OrderKey,      OrderLineNumber, Lot, Storerkey,
                                         Sku,           PackKey,    UOM,           UOMQty,        Qty,             Loc, ID,
                                         Cartongroup,   Cartontype, DoReplenish,   replenishzone, docartonize,     Trafficcop,
                                         PickMethod) VALUES
                            (@cPickDetailKey,  '',          '',             @cOrderKey,    @cOrderLineNumber,   @cLot,   @cStorerkey,
                             @cSKU,             @cPackKey,   '6',            @nQtyToTake,   @nQtyToTake,         @cLoc,  @cID,
                '',                '',          '',             '',            'N',                 'C',    '8' )

                     SELECT @n_err = @@ERROR, @n_cnt_sql = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        GOTO SP_RETURN
                     END

                     SET @n_cnt = 0
                     SELECT @n_cnt = COUNT(1) FROM PICKDETAIL with (NOLOCK) WHERE PICKDETAILKEY = @cPickDetailKey

                     if (@b_debug = 1 or @b_debug = 2) and (@n_cnt_sql <> @n_cnt)
                     begin
                        print 'PICK - INSERT PickDetail @@ROWCOUNT gets wrong'
                        select '@@ROWCOUNT' = @n_cnt_sql, 'COUNT(*)' = @n_cnt
                        GOTO SP_Return
                     end

                     IF @n_cnt <> 1
                     BEGIN
                        SELECT @bPickUpdateSuccess = 0
                     END
                     ELSE
                     BEGIN
                        SELECT @bPickUpdateSuccess = 1
                     END

                     IF @bPickUpdateSuccess = 1
                     BEGIN
                        SELECT @nQty = @nQty - @nQtyToTake
                        SELECT @nOpenQty = @nOpenQty - @nQtyToTake

                        UPDATE #TempBatchPick
                           SET Qty = Qty - @nQtyToTake
                         WHERE StorerKey = @cStorerKey
                           AND SKU = @cSKU
                           AND Lottable02 = @cLottable02
                           AND Qty > 0

                        IF @b_debug = 1
                        BEGIN
                           SELECT 'PICK - ', @nOpenQty '@nOpenQty', @nQty '@nQty', @nQtyToTake '@nQtyToTake'
                        END

--------- Check Any Replenishment Needed
                        SELECT @nQtyOnHand =  Qty - (QtyAllocated + QtyPicked)
                          FROM SKUxLOC WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                           AND SKU = @cSKU AND LOC = @cLOC
                           AND LocationType IN ('PICK', 'CASE')

                        SELECT @nQtyPendingReplenQty = ISNULL(SUM(Qty), 0)
                        FROM REPLENISHMENT (NOLOCK )
                        WHERE Confirmed = 'L'
                          AND ToLOC <> 'PICK'
                          AND StorerKey = @cStorerKey
                          AND SKU = @cSKU AND ToLOC = @cLOC

                        IF @nQtyPendingReplenQty > 0
                           SET @nQtyOnHand = @nQtyOnHand + @nQtyPendingReplenQty

                        SELECT @nQtyPendingMoveOut = ISNULL(SUM(Qty), 0)
                        FROM REPLENISHMENT (NOLOCK )
                        WHERE Confirmed IN ('W', 'S')
                          AND StorerKey = @cStorerKey
                          AND SKU = @cSKU AND FromLOC = @cLOC

                        SELECT @nQtyPendingMoveIn = ISNULL(SUM(Qty),0)
                        FROM REPLENISHMENT (NOLOCK )
                        WHERE Confirmed IN ('W', 'S')
                          AND StorerKey = @cStorerKey
                          AND SKU = @cSKU AND ToLOC = @cLOC

                        IF @nQtyPendingMoveOut > @nQtyPendingMoveIn
                        BEGIN
                           IF @nQtyOnHand < 0
                              SET @nQtyOnHand = @nQtyOnHand + (@nQtyPendingMoveIn - @nQtyPendingMoveOut)
                           ELSE
                              SET @nQtyOnHand = @nQtyOnHand - (@nQtyPendingMoveOut - @nQtyPendingMoveIn )
                        END

                        IF @nQtyOnHand < 0
                        BEGIN
                           SELECT @nQtyToReplenish = @nQtyOnHand * -1

              IF @b_Debug = 1
                              SELECT 'REPLEN -   Start', @cStorerKey '@cStorerKey', @cSKU '@cSKU', @cLOC '@cLOC',
                                     @nQtyToReplenish '@nQtyToReplenish'

                           IF @nQtyToReplenish > 0
                           BEGIN
                              SELECT @nWavePendingMoveIn = ISNULL(SUM(CASE WHEN Confirmed IN ('W','S') Then Qty ELSE 0 END),0),
                                     @nLoadPendingMoveIn = ISNULL(SUM(CASE WHEN Confirmed = 'L' Then Qty ELSE 0 END),0)
                              FROM   Replenishment WITH (NOLOCK)
                              WHERE  StorerKey = @cStorerKey
                              AND    SKU = @cSKU
                              AND    ToLoc = @cLOC

                              -- If Load Replenishment Qty not enought to cover the overallocated qty
                              -- Generate replenishment
                              -- IF ISNULL(@nLoadPendingMoveIn, 0) < @nQtyToReplenish
                              IF @nQtyToReplenish > 0
                              BEGIN
--------------UCC
                                   DECLARE CUR_UCCAllocate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                                    SELECT UCC.LOC, UCC.ID, UCCNo, UCC.Qty
                                    FROM   UCC WITH (NOLOCK)
                                    JOIN   SKUxLOC WITH (NOLOCK) ON SKUxLOC.StorerKey = UCC.StorerKey
                                                                AND SKUxLOC.SKU = UCC.SKU
                                                                AND SKUxLOC.LOC = UCC.LOC
                                    JOIN   LOTxLOCxID LLL WITH (NOLOCK) ON
                                               LLL.LOT = UCC.LOT AND LLL.LOC = UCC.LOC AND LLL.ID = UCC.ID
                                    JOIN   LOC LOC WITH (NOLOCK) ON LLL.Loc = LOC.LOC
                                    JOIN   LOT LOT WITH (NOLOCK) ON LLL.LOT = LOT.LOT
                                    JOIN   ID  ID WITH (NOLOCK) ON LLL.ID = ID.ID
                                    WHERE  SKUxLOC.StorerKey = @cStorerKey
                                      AND  SKUxLOC.SKU = @cSKU
                                      AND  SKUxLOC.LocationType NOT IN ('CASE','PICK')
                                      AND  UCC.Status = '1'
                                      AND  LLL.Qty - LLL.QtyAllocated - LLL.QtyPicked > 0
                                      AND  LLL.LOT = @cLOT
                                      AND  LOC.Facility = @cFacility
                                      AND  LOC.Locationflag <>'HOLD'  --(James01)
                                      AND  LOC.Locationflag <> 'DAMAGE'
                                      AND  LOC.Status <> 'HOLD'
                                      AND  LOT.Status = 'OK'
                                      AND  ID.Status = 'OK'
                                     -- ORDER BY UCC.Qty

                                   OPEN CUR_UCCAllocate

                                   FETCH NEXT FROM CUR_UCCAllocate INTO @nRplLOC, @nRplID, @cUCCNo, @nUCCQty

                                   WHILE @@FETCH_STATUS <> -1 AND @nQtyToReplenish > 0
                                   BEGIN
                                      IF @b_Debug = 1
                                         SELECT 'REPLEN -   Start', @cUCCNo '@cUCCNo', @nUCCQty '@nUCCQty'

                                      IF @nUCCQty > @nQtyToReplenish
                                         SET @nQtyToReplenish = @nUCCQty

                                      UPDATE UCC WITH (ROWLOCK)
                                        SET Status = '3', UserDefined01 = @c_oskey
                                      WHERE UCCNO = @cUCCNo

                                      EXECUTE nspg_GetKey
                                          @keyname       = 'REPLENISHKEY', --Leong01
                                          @fieldlength   = 10,
                                          @keystring     = @cReplenishmentKey  OUTPUT,
                                          @b_success     = @b_success   OUTPUT,
                                          @n_err         = @n_err       OUTPUT,
                                          @c_errmsg      = @c_errmsg    OUTPUT

                                       IF NOT @b_success = 1
                                       BEGIN
                                          SELECT @n_continue = 3
                                       END
                                       ELSE
                                       BEGIN
                                          SELECT @cUOM = PACKUOM3
                                          FROM   PACK WITH (NOLOCK)
                                          WHERE  PackKey = @cPackkey

                                          INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                                              StorerKey,      SKU,       FromLOC,      ToLOC,
                                              Lot,            Id,        Qty,          UOM,
                                              PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                                              RefNo,          Confirmed, ReplenNo,     Remark,
                                              LoadKey )
                                          VALUES (
                                              @cReplenishmentKey,        '',
                                              @cStorerKey,   @cSKU,      @nRplLOC,        @cLOC,
                                              @cLOT,         @nRplID,    @nUCCQty,        @cUOM,
                                              @cPackkey,     '1',        0,              0,
                                              @cUCCNo,       'L',        '',             'BULK to PP',
                                              @c_oskey  )

                                          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                                          IF @n_err <> 0
                                          BEGIN
                                             SELECT @n_continue = 3
                                             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63507   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                                             GOTO SP_RETURN
                                          END

                                          SET @nQtyToReplenish = @nQtyToReplenish - @nUCCQty

                                       END -- Insert Replenishment
                                       FETCH NEXT FROM CUR_UCCAllocate INTO @nRplLOC, @nRplID, @cUCCNo, @nUCCQty
                                   END -- While Loop Cur_UCCAllocate
                                   CLOSE CUR_UCCAllocate
                                   DEALLOCATE CUR_UCCAllocate
------------- UCC
                             END -- IF ISNULL(@nLoadPendingMoveIn, 0) < @nQtyToReplenish
                           END --IF @nQtyToReplenish > 0
                        END -- IF EXISTS

--------- End Replenishment

                        IF @nQty <= 0 OR @nOpenQty <= 0
                        BEGIN
                           BREAK
       END
                     END -- @bPickUpdateSuccess = 1
                  END -- @b_success = 1
               END -- Insert PickDetail
            END -- if loc is not null
         END -- While Looking for Location

         FETCH NEXT FROM OrderDetCur INTO @cOrderKey, @cOrderLineNumber, @nOpenQty
      END -- While OrderDetCur

      CLOSE OrderDetCur
      DEALLOCATE OrderDetCur
   END

   SP_RETURN:
END

GO
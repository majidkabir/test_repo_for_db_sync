SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* SP: nspOrderProcessingByCase                                           */
/* Creation Date:                                                         */
/* Copyright: IDS                                                         */
/* Written by: Shong                                                      */
/*                                                                        */
/* Purpose: Special Allocation Request by China (Not refer to Strategy)   */
/*                                                                        */
/* Usage:                                                                 */
/*                                                                        */
/* Called By: Power Builder Allocation from Load Plan                     */
/*                                                                        */
/* PVCS Version: 1.13                                                     */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author    Ver Purposes                                    */
/* 23-Jul-2004  Shong         Initial Version (SOS# 25496)                */
/* 20-Aug-2004  YTWan         FBR001: allocation                          */
/* 09-Jun-2005  June          S36686, sort by balance qty instead of      */
/*                            hand qty                                    */
/* 13-Jun-2005  SHONG         Preventing Brake carton in bulk location    */ 
/* 23-Sep-2005  SHONG         SOS#41039 - Exclude Holded LOT, ID          */ 
/* 02-Nov-2005  SHONG         SOS#42319 - Lot Specific Allocation         */ 
/* 08-Dec-2005  MaryVong      S43971 Add in locationflag checking for     */
/*                            ckface location                             */ 
/* 14-Nov-2005  Shong         SOS#42319 - Lot Specific Allocation         */
/* 17-May-2006  YokeBeen      SOS#51099 - Expended the length of ID from  */
/*                            NVARCHAR(10) to NVARCHAR(18) max. - (YokeBeen01)    */
/* 29-Dec-2006  Shong         Don't allow over allocate for B grade stock */
/* 13-May-2008  June          SOS104768 - Remove hardcode checking of     */
/*                            Lottable02 <> '02000'                       */
/* 09-May-2008  SHONG         SOS# 105520 Shoule not allocate Wave's      */
/*                            Orders                                      */
/*                            Qty Available should minus qty pending to   */
/*                            move in Wave Dynamic Picking Process        */
/* 08-Jun-2008  James    1.1  In LP alloc, if found wavekey then error    */
/* 06-Jan-2009  Shong    1.2  SOS126009 Add StorerConfig NonGradedProduct */
/*                            To allow Over Allocation in Pick Location.  */
/* 12-Jul-2017  TLTING   1.3  missing (NOLOCK)                            */
/**************************************************************************/
CREATE PROC  [dbo].[nspOrderProcessingByCase]
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
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   
   
   DECLARE        @n_continue int        ,  
                  @n_starttcnt   int      , -- Holds the current transaction count
     @n_cnt         int      , -- Holds @@ROWCOUNT after certain operations
                  @c_preprocess NVARCHAR(250) , -- preprocess
                  @c_pstprocess NVARCHAR(250) , -- post process
                  @n_err2 int             , -- For Additional Error Detection
                  @c_fromloc  NVARCHAR(10),
                  @b_debug int              -- Debug 0 - OFF, 1 - Show ALL, 2 - Map

   -- Added By SHONG - Performance Tuning Rev 1.0
   DECLARE  @c_PHeaderKey        NVARCHAR(18),
            @c_CaseId            NVARCHAR(18),     -- (YokeBeen01)
            @c_PickLooseFromBulk int,
            @nLotQty             int, 
            @b_Cursor_Opened     int 

   -- SOS#42319
   DECLARE @cLottable02       NVARCHAR(18) 

   -- SOS126009
   DECLARE @cNonGradedProduct NVARCHAR(1), 
           @cTrackUCC         NVARCHAR(1) 
   
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
      IF (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_oskey)) IS NULL or dbo.fnc_LTrim(dbo.fnc_RTrim(@c_oskey))='')
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63500
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Parameters Passed (nspOrderProcessingByCase)'
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
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Cannot allocate Loadplan with Orders contain wavekey (nspOrderProcessingByCase)'
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

   DECLARE @cAllowOverAllocations NVARCHAR(1)

   IF @c_tblprefix = 'DS1' or @c_tblprefix = 'DS2'  
   BEGIN
      SELECT @b_debug = Convert(Int, Right(dbo.fnc_RTrim(@c_tblprefix), 1))
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

   SELECT TOP 1 @cStorerKey = StorerKey 
   FROM   #TempBatchPick 

   SET @cTrackUCC = '0'
   SELECT @cTrackUCC = ISNULL(RTRIm(sValue), '0')
   FROM   StorerConfig WITH (NOLOCK)
   WHERE  StorerKey = @cStorerKey 
     AND  ConfigKey = 'UCC' 
   

   IF @b_debug = 1
   BEGIN
      SELECT * 
      FROM   #TempBatchPick
   END

   SELECT @nCount = COUNT(1)
   FROM   #TempBatchPick
   
   IF @nCount = 0 
      RETURN

   SELECT @cSKU = ''

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
      IF @b_debug = 1
      BEGIN
         SELECT @cSKU    as SKU, 
             @cStorerKey as StorerKey,
             @nBatchQty  As Qty, 
             @cPackKey   AS PackKey,
             @nCaseCnt   As CaseCnt, 
             @cFacility  as Facility,
             @cLottable02 as Lottable02 

        --Print 'Declare Bulk Cursor' 
        SELECT LLL.LOT, 
               LLL.LOC, 
               LLL.ID,
               CASE WHEN (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED) > (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated) 
                    THEN (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated) - 
                         (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated) % CAST(PACK.CaseCnt as int)
                    ELSE (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED) - 
                         (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED) % CAST(PACK.CaseCnt as int)
               END, 
               CAST(PACK.CaseCnt as int) as CaseCnt 
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
         JOIN LOT (NOLOCK) ON (LOT.LOT = LLL.LOT AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated) >=  0)
         -- SOS#41039 By SHONG
         JOIN ID (NOLOCK) ON ( LLL.ID = ID.ID ) 
         WHERE LOC.Facility = @cFacility 
         AND LOC.Locationflag <>'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         -- SOS#41039 By SHONG 
         AND LOT.Status = 'OK'
         AND ID.Status = 'OK'
         -- SOS#41039 (End) 
         AND (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED) >= PACK.CaseCnt 
         AND LLL.Storerkey = @cStorerKey 
         AND LLL.Sku = @cSKU 
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
                       -- SOS36686
                       -- LLL.Qty, LLL.LOC, LLL.LOT, LLL.ID
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
               CASE WHEN (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED) > (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated) 
                    THEN (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated) - 
                         (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated) % CAST(PACK.CaseCnt as int)
                    ELSE (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED) - 
                         (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED) % CAST(PACK.CaseCnt as int)
               END, 
               CAST(PACK.CaseCnt as int) as CaseCnt 
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
         JOIN LOT (NOLOCK) ON (LOT.LOT = LLL.LOT AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated) >=  0)
         -- SOS#41039 By SHONG  
         JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.LOT = LLL.LOT 
         JOIN ID (NOLOCK) ON ( LLL.ID = ID.ID )  
         WHERE LOC.Facility = @cFacility 
         AND LOC.Locationflag <>'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         -- SOS#41039 By SHONG 
         AND LOT.Status = 'OK'
         AND ID.Status = 'OK' 
         -- SOS#41039 (End) 
         AND (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED) >= PACK.CaseCnt 
         AND LLL.Storerkey = @cStorerKey 
         AND LLL.Sku = @cSKU 
         AND LOTATTRIBUTE.Lottable02 = @cLottable02 
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
                       -- SOS36686
                       -- LLL.Qty, LLL.LOC, LLL.LOT, LLL.ID
                       (LLL.QTY - LLL.QTYALLOCATED - LLL.QTYPICKED), LLL.LOC, LLL.LOT, LLL.ID

      SELECT @b_Cursor_Opened = 1      
      OPEN Bulk_Lot_Cursor

      IF @@CURSOR_ROWS = 0 
         CONTINUE  

      SET ROWCOUNT 0

      WHILE 1=1 AND (@n_continue = 1 or @n_continue = 2) AND @nBatchQty > 0  
      BEGIN
         FETCH NEXT FROM Bulk_Lot_Cursor INTO @cLOT, @cLOC, @cID, @nQtyAvailable, @nCaseCnt
         
         IF @@Fetch_Status = -1
         BEGIN
            -- Qty Available should minus qty pending to move in Wave Dynamic Picking Process
            SET @nQtyMoveinProgress = 0 

            IF @cTrackUCC = '1'
            BEGIN 
               SELECT @nQtyMoveinProgress =  ISNULL(SUM(Qty), 0) 
               FROM   UCC WITH (NOLOCK, INDEX(IDX_UCC_LOTxLOCxID)) 
               WHERE  LOT = @cLOT
                 AND  LOC = @cLOC
                 AND  ID  = @cID 
                 AND  Status = '3' 
            END

            SET  @nQtyAvailable = @nQtyAvailable - @nQtyMoveinProgress 

            SELECT @nBatchQty = 0 

            IF @b_debug = 1
            BEGIN
               select 'Break - ', @cLOT '@cLOT', @cStorerKey '@cStorerKey',
                      @cSKU '@cSKU', @nQtyAvailable '@nQtyAvailable' 
            END 

            BREAK
         END

         IF @b_debug = 1
         BEGIN
            select @cLOT '@cLOT', @cLOC '@cLOC', 
                   @cID '@cID', @nQtyAvailable '@nQtyAvailable', @nBatchQty '@nBatchQty'
         END 

         IF @b_debug = 1
         BEGIN   
            SELECT OrderDetail.OrderKey, 
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
   
         DECLARE OrderDetCur Cursor LOCAL FAST_FORWARD READ_ONLY FOR 
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
   
   
         OPEN OrderDetCur
   
         FETCH NEXT FROM OrderDetCur INTO @cOrderKey, @cOrderLineNumber, @nOpenQty 

         WHILE @@FETCH_STATUS <> -1 and @nBatchQty > 0 AND @nQtyAvailable > 0 
         BEGIN 
            IF @b_debug = 1
            BEGIN
               SELECT @cOrderKey '@cOrderKey', @cOrderLineNumber '@cOrderLineNumber', @nOpenQty '@nOpenQty'
            END 

            WHILE 1=1 and @nOpenQty > 0 and @nBatchQty > 0 
            BEGIN
               IF dbo.fnc_RTrim(@cLOC) IS NOT NULL AND dbo.fnc_RTrim(@cLOC) <> '' 
               BEGIN
                  GET_NEXT_BULK_LOT:

                  SELECT @nLotQty = LOT.Qty - QTYALLOCATED - QTYPICKED - QTYPREALLOCATED
                  FROM   LOT (NOLOCK)
                  WHERE  LOT = @cLOT 

                  IF @nLotQty < @nQtyAvailable 
                     SELECT @nQtyAvailable = @nLotQty 
                  
                  -- SET @nQtyAvailable = @nQtyAvailable - ( @nQtyAvailable % @nCaseCnt )

                  IF @nLotQty <= 0  OR @nQtyAvailable = 0 -- OR @nQtyAvailable < @nCaseCnt 
                  BEGIN
                     SELECT @nQtyAvailable = 0 

                     FETCH NEXT FROM Bulk_Lot_Cursor INTO @cLOT, @cLOC, @cID, @nQtyAvailable, @nCaseCnt
         
                     IF @@Fetch_Status = -1
                     BEGIN
                        BREAK 
                     END 

                     GOTO GET_NEXT_BULK_LOT 
                  END 
                  

                  IF @b_debug = 1
                  BEGIN
                     SELECT @cLOC as [LOTxLOCxID.LOC], 
                            @cID  as [LOTxLOCxID.ID],
                            @nQtyAvailable as [QtyAvailable]
                  END
   
                  IF @nQtyAvailable > @nOpenQty
                     IF @nOpenQty <= @nBatchQty
                        SELECT @nQtyToTake = @nOpenQty
                     ELSE
                        SELECT @nQtyToTake = @nBatchQty
                  ELSE
                     IF @nQtyAvailable <= @nBatchQty
                        SELECT @nQtyToTake = @nQtyAvailable
                     ELSE
                        SELECT @nQtyToTake = @nBatchQty 
   
   
                  IF @n_continue = 1 or @n_continue = 2
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
                                            Cartongroup,   Cartontype, DoReplenish,   replenishzone, docartonize,     Trafficcop,
                                            PickMethod) VALUES
                               (@cPickDetailKey,  '',          '',             @cOrderKey,    @cOrderLineNumber,   @cLot,   @cStorerkey,
                                @cSKU,             @cPackKey,   '2',            @nQtyToTake,   @nQtyToTake,         @cLoc,  @cID,
                                '',                '',          '',             '',            'N',                 'C',    '8' )
      
                        SELECT @n_err = @@ERROR, @n_cnt_sql = @@ROWCOUNT
   
                        SELECT @n_cnt = COUNT(1) FROM PICKDETAIL with (NOLOCK) WHERE PICKDETAILKEY = @cPickDetailKey
   
                        if (@b_debug = 1 or @b_debug = 2) and (@n_cnt_sql <> @n_cnt)
                        begin
                           print 'INSERT PickDetail @@ROWCOUNT gets wrong'
                           select '@@ROWCOUNT' = @n_cnt_sql, 'COUNT(*)' = @n_cnt
                        end
   
                        IF not (@n_err = 0 AND @n_cnt = 1)
                        BEGIN
                           SELECT @bPickUpdateSuccess = 0
                        END
                        ELSE
                        BEGIN
                           SELECT @bPickUpdateSuccess = 1
                       END
   
   
                        IF @bPickUpdateSuccess = 1
                        BEGIN
                           -- SELECT @nQty = @nQty - @nQtyToTake
                           SELECT @nOpenQty = @nOpenQty - @nQtyToTake 
                           SELECT @nBatchQty = @nBatchQty - @nQtyToTake 
                           SELECT @nQtyAvailable = @nQtyAvailable - @nQtyToTake 
   
                           UPDATE #TempBatchPick
                              SET Qty = Qty - @nQtyToTake
                            WHERE StorerKey = @cStorerKey 
                              AND SKU = @cSKU
                              AND Lottable02 = @cLottable02 
                              AND Qty > 0 
   
                           IF @b_debug = 1
                           BEGIN
                              select @nOpenQty '@nOpenQty', @nQtyToTake '@nQtyToTake',
                                     @nBatchQty '@nBatchQty' 
                           END 
   
                           IF @nBatchQty <= 0 -- OR @nQtyAvailable <= 0 
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
         SELECT @nQty       AS QTY,
                @cStorerKey AS StorerKey,
                @cSKU       AS SKU,
                @cPackKey   as PackKey,
                @cLottable02 as Lottable02 
      END 

      IF @b_debug = 1
      BEGIN   
         SELECT OrderDetail.OrderKey, 
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
            SELECT @cOrderKey '@cOrderKey', @cOrderLineNumber '@cOrderLineNumber', @nOpenQty '@nOpenQty'
         END 

         -- SOS126009
         SET    @cNonGradedProduct = '0'
         SELECT @cNonGradedProduct = ISNULL(sValue, '0') 
         FROM   StorerConfig WITH (NOLOCK) 
         WHERE  StorerKey = @cStorerKey 
           AND  ConfigKey = 'NonGradedProduct' 
           
         IF ISNULL( RTRIM(@cNonGradedProduct), '') = ''
            SET @cNonGradedProduct = '0'
            
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
            SELECT @n_continue = 3, @c_errmsg = 'nsporderprocessing' + dbo.fnc_RTrim(@c_errmsg)
         END            
         ELSE
         BEGIN
            IF @cAllowOverAllocations is null
            BEGIN
               SELECT @cAllowOverAllocations = '0'
            END
            IF @b_debug = 1
            BEGIN
               SELECT 'ALLOWOVERALLOCATIONS' = @cAllowOverAllocations
            END            
         END

         SELECT @cLOT = ''
         WHILE 1=1 and @nOpenQty > 0 and @nQty > 0 
         BEGIN
            GET_NEXT_PICK_LOT:

            -- Get From CASE/PICK Location
            SET ROWCOUNT 1

            SELECT @cLOT = LOTxLOCxID.Lot,
                   @cLOC = LOTxLOCxID.LOC, 
                   @cID  = LOTxLOCxID.ID,
                   @nQtyAvailable = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED)
            FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), LOT (NOLOCK), ID (NOLOCK) -- SOS#41039
                 ,LOTATTRIBUTE (NOLOCK) 
            WHERE LOTxLOCxID.Loc = LOC.LOC
            AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
            AND LOTxLOCxID.Sku = SKUxLOC.Sku
            AND LOTxLOCxID.Loc = SKUxLOC.Loc
            AND SKUxLOC.Locationtype IN ('CASE', 'PICK')
            AND LOC.Facility = @cFacility 
            AND LOC.Locationflag <>'HOLD'
            AND LOC.Locationflag <> 'DAMAGE'
            AND LOC.Status <> 'HOLD'
            -- SOS#41039 By SHONG 
            AND LOT.Status = 'OK'
            AND ID.Status = 'OK' 
            AND ID.ID = LOTxLOCxID.ID 
            -- SOS#41039 
            AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 
            AND LOTxLOCxID.Storerkey = @cStorerkey
            AND LOTxLOCxID.Sku = @cSku
            AND LOTxLOCxID.LOT NOT IN (SELECT LOT FROM #ExcludeLot) 
            AND LOT.LOT = LOTxLOCxID.LOT 
            AND LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated > 0 
            AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
            AND LOTATTRIBUTE.Lottable02 = @cLottable02 
            ORDER BY LOTxLOCxID.LOT, LOTxLOCxID.Qty, LOTxLOCxID.LOC, LOTxLOCxID.ID
            
            IF @@ROWCOUNT = 0 
            BEGIN
               -- Select any LOT available 
               SET ROWCOUNT 1

               -- 20-Aug-2004 YTWan FBR001: allocation - Sort By LocHandling, Qty, Loc, Lot, id
               SELECT @cLOT = LOTxLOCxID.Lot, 
                      @cLOC = LOTxLOCxID.LOC, 
                      @cID  = LOTxLOCxID.ID,
                      @nQtyAvailable = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED)
               FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), LOT (NOLOCK), ID (NOLOCK)
                    ,LOTATTRIBUTE (NOLOCK)  
               WHERE LOTxLOCxID.Loc = LOC.LOC
               AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
               AND LOTxLOCxID.Sku = SKUxLOC.Sku
               AND LOTxLOCxID.Loc = SKUxLOC.Loc
               AND LOC.Facility = @cFacility 
               AND LOC.Locationflag <>'HOLD'
               AND LOC.Locationflag <> 'DAMAGE'
               AND LOC.Status <> 'HOLD'
               AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 
               AND LOTxLOCxID.Storerkey = @cStorerkey
               AND LOTxLOCxID.Sku = @cSku
               AND LOTxLOCxID.LOT NOT IN (SELECT LOT FROM #ExcludeLot) 
               -- SOS#41039 By SHONG 
               AND LOTxLOCxID.LOT = LOT.LOT 
               AND LOTxLOCxID.ID = ID.ID 
               AND LOT.Status = 'OK'
               AND ID.Status = 'OK'
               -- SOS#41039 (End)
               AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
               AND LOTATTRIBUTE.Lottable02 = @cLottable02                
               ORDER BY CASE Loc.LocationHandling WHEN '2'
                                                 THEN 5
                                                 WHEN '1'
                                                 THEN 10
                                                 WHEN '9'
                                                 THEN 15
                                                 ELSE 99
                       END, 
                       -- SOS36686
                       -- LOTxLOCxID.Qty, LOTxLOCxID.LOC, LOTxLOCxID.LOT, LOTxLOCxID.ID
                       (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), LOTxLOCxID.LOC, LOTxLOCxID.LOT, LOTxLOCxID.ID

               IF @@ROWCOUNT = 0 
               BEGIN
                  
                  -- Teminate
                  SET ROWCOUNT 0
                  SELECT @nQty = 0

                  DELETE FROM   #TempBatchPick 
                  WHERE  SKU = @cSKU
                  AND    StorerKey = @cStorerKey
                  AND    Lottable02 = @cLottable02 

                  BREAK                  
               END
               ELSE
               BEGIN
                  SET ROWCOUNT 0
                  IF @cAllowOverAllocations = '1' 
                  -- SOS104768, SOS126009
                  AND ( EXISTS(SELECT 1 
                                 FROM  CODELKUP (NOLOCK) 
                                 WHERE Listname = 'GRADE_A'
                                 AND   Code = @cLottable02)
                        OR @cNonGradedProduct = '1' )
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
   
                     IF dbo.fnc_RTrim(@cPickLOC) IS NOT NULL AND dbo.fnc_RTrim(@cPickLOC) <> ''
                     BEGIN
                        -- if Pick Location Available and Overallocation is turn on
                        -- Force to pick from Pick Location
                        SELECT @cID = ''
                        SELECT @cLOC = @cPickLOC

                        -- Get the Qty Avaliable from LOT becuase, cause it's not in Pick Location
                        SELECT @nQtyAvailable = LOT.Qty - QTYALLOCATED - QTYPICKED - QTYPREALLOCATED
                        FROM   LOT (NOLOCK)
                        WHERE  LOT = @cLOT 

                        IF @nQtyAvailable <= 0 
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
                     END -- dbo.fnc_RTrim(@cPickLOC) IS NOT NULL AND dbo.fnc_RTrim(@cPickLOC) <> ''
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

            SET ROWCOUNT 0

            IF dbo.fnc_RTrim(@cLOC) IS NOT NULL AND dbo.fnc_RTrim(@cLOC) <> '' AND @nQtyAvailable > 0 
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @cLOC as [LOC], 
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
                  -- SOS104768, SOS126009
                    AND @cAllowOverAllocations = '1' 
                    AND ( EXISTS(SELECT 1 
      FROM  CODELKUP (NOLOCK) 
                                 WHERE Listname = 'GRADE_A'
                                 AND   Code = @cLottable02) 
                          OR @cNonGradedProduct = '1' )
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
                        select 'Insert PickDetail :', @cPickDetailKey '@cPickDetailKey',  @cOrderKey '@cOrderKey',    
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

                     SELECT @n_cnt = COUNT(1) FROM PICKDETAIL with (NOLOCK) WHERE PICKDETAILKEY = @cPickDetailKey

                     if (@b_debug = 1 or @b_debug = 2) and (@n_cnt_sql <> @n_cnt)
                     begin
                        print 'INSERT PickDetail @@ROWCOUNT gets wrong'
                        select '@@ROWCOUNT' = @n_cnt_sql, 'COUNT(*)' = @n_cnt
                        GOTO SP_Return 
                     end

                     IF not (@n_err = 0 AND @n_cnt = 1)
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
                           select @nOpenQty '@nOpenQty', @nQty '@nQty', @nQtyToTake '@nQtyToTake' 
                        END 


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
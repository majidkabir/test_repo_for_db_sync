SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Procedure: ispWaveDynamicPickUCCAlloc                               */
/* Creation Date: 18-Oct-2007                                                 */
/* Copyright: IDS                                                             */
/* Written by: Shong                                                          */
/*                                                                            */
/* Purpose: Initial Design for NIKE China Dynamic Pick Project                */
/*                                                                            */
/*                                                                            */
/* Called By: From Wave Maintenance Screen                                    */
/*                                                                            */
/* PVCS Version: 1.8                                                          */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author     Ver   Purposes                                     */
/* 22-06-2008   SHONG            Fixing Allocation Bug Tag# SHONG20080622     */
/* 23-06-2008   SHONG            Fixing Allocation Bug Tag# SHONG20080623     */
/* 29-07-2008   SHONG            Bug Fixing  SHONG20080729                    */
/* 30-07-2008   MaryVong         Bug Fix Tag# 20080730                        */
/*                               1) FCP: Reset CartonNo for diff PSNo or Load#*/
/*                               2) BULK To PP, PP To DP: Exclude FCP QTY in  */
/*                                  Replenishment checking                    */
/* 04-Aug-2008  MaryVong         Added Start DynamicPick Location checking    */
/* 01-Sep-2008  Shong            Filter WaveOrderLn by WaveKey                */
/* 13-Nov-2008  James            SOS120350 - Break BulkToDP/BulkToPP into 2   */
/*                               replenishment group (james01)                */
/* 13-Jan-2009  James            SOS123961 - Get the MAX Carton No for FCP    */
/*                               if reallocate  (james02)                     */
/* 15-Jan-2009  James            SOS125308 - Allocate based on orderdetail.   */
/*                               lottable (james03)                           */
/* 15-Jan-2009  James            SOS124584 - If already reach MAX DP LOC      */
/*                               then go back to first DP LOC (james04)       */
/* 17-Apr-2009  Shong            SOS134253 - Revise logic for ToLoc update in */
/*                                           sequence                         */
/* 01-Jul-2009  Shong            SOS140790 - Trigger Allocate CMS interface   */
/*                               Record into CMSLog Table.                    */
/* 19-Mar-2010  Leong      1.8   Bug Fix: Change GetKey from REPLENISHMENT to */
/*                                        REPLENISHKEY (Leong01)              */
/* 21-Mar-2014  TLTING     1.9   Bug fix SQL2012                              */
/* 21-May-2014  TKLIM      1.10  Change dbo.fnc_RTRIM to RTRIM                */
/* 21-May-2014  TKLIM      1.10  Added Lottables 06-15                        */
/* 15-Dec-2018  TLTING01   1.11  Missing nolock                          */
/******************************************************************************/

CREATE PROCEDURE [dbo].[ispWaveDynamicPickUCCAlloc]
      @c_WaveKey     NVARCHAR(10),
      @c_DPLoc_Start NVARCHAR(10),
      @b_Success     int OUTPUT,
      @n_err         int OUTPUT,
      @c_errmsg      NVARCHAR(250) OUTPUT
AS
   DECLARE  @n_continue int,              /* continuation flag
                                          1=Continue
                                          2=failed but continue processsing
                                          3=failed do not continue processing
                                          4=successful but skip furthur processing */
            @n_starttcnt int,             -- Holds the current transaction count
            @n_cnt int,                   -- Holds @@ROWCOUNT after certain operations
            @c_preprocess NVARCHAR(250),  -- preprocess
            @c_pstprocess NVARCHAR(250),  -- post process
            @n_err2 int,                  -- For Additional Error Detection
            @b_debug int                  -- Debug Flag

   SET NOCOUNT ON         -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @b_Success = 2
      SET @b_debug = 1
   ELSE
      SET @b_debug = 0

   /* Declare RF Specific Variables */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_err2=0


   DECLARE  @c_FCP_ReplenGrp      NVARCHAR(25),
            @c_B2D_ReplenGrp      NVARCHAR(25),
            @c_P2D_ReplenGrp      NVARCHAR(25),
            @c_B2P_ReplenGrp  NVARCHAR(25),   -- (james01)
            @cZipCodeTo           NVARCHAR(15),
            @cTransmitlogKey      NVARCHAR(10),
            @c_country            NVARCHAR(30),
            @nQtyRepleInProgress  int,
            @n_QtyToTake          int,     -- SHONG20080622
            @c_DynPickLOC         NVARCHAR(10),-- SHONG20080622
            @cGetReplenishmentKey NVARCHAR(10),-- SHONG20080623
            @nLotQty              int,
            @c_Ex_FCP_ReplenGrp   NVARCHAR(25) -- (james03)


   /* Calculate next Task ID */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      -- SOS123961 Reuse the replenishmentgroup if already exists (james03)
      SELECT TOP 1 @c_Ex_FCP_ReplenGrp = ReplenishmentGroup
      FROM Replenishment WITH (NOLOCK)
      WHERE Replenno = @c_WaveKey
         AND Remark = 'FCP'

      IF ISNULL(@c_Ex_FCP_ReplenGrp, '') <> ''
         SET @c_FCP_ReplenGrp = @c_Ex_FCP_ReplenGrp
      ELSE
      BEGIN
         EXECUTE nspg_GetKey
             @keyname       = 'REPLENISHGROUP',
             @fieldlength   = 10,
             @keystring     = @c_FCP_ReplenGrp OUTPUT,
             @b_success     = @b_success       OUTPUT,
             @n_err         = @n_err           OUTPUT,
             @c_errmsg      = @c_errmsg        OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            GOTO RETURN_SP
         END
      END
   END
   /* Calculate next Task ID */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      EXECUTE nspg_GetKey
            @keyname       = 'REPLENISHGROUP',
            @fieldlength   = 10,
            @keystring     = @c_B2D_ReplenGrp OUTPUT,
            @b_success     = @b_success       OUTPUT,
            @n_err         = @n_err           OUTPUT,
            @c_errmsg      = @c_errmsg        OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         GOTO RETURN_SP
      END
   END

   -- (james02)
   /* Calculate next Task ID */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      EXECUTE nspg_GetKey
            @keyname       = 'REPLENISHGROUP',
            @fieldlength   = 10,
            @keystring     = @c_B2P_ReplenGrp OUTPUT,
            @b_success     = @b_success       OUTPUT,
            @n_err         = @n_err           OUTPUT,
            @c_errmsg      = @c_errmsg        OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         GOTO RETURN_SP
      END
   END

   /* Calculate next Task ID */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        EXECUTE nspg_GetKey
             @keyname       = 'REPLENISHGROUP',
             @fieldlength   = 10,
             @keystring     = @c_P2D_ReplenGrp OUTPUT,
             @b_success     = @b_success       OUTPUT,
             @n_err         = @n_err           OUTPUT,
             @c_errmsg      = @c_errmsg        OUTPUT
        IF NOT @b_success = 1
        BEGIN
            SELECT @n_continue = 3
            GOTO RETURN_SP
        END
   END

   -- Start inserting the records into Temp WaveOrderLine
   IF @n_continue=1 OR @n_continue=2
   BEGIN

      DECLARE @c_Facility           NVARCHAR(5)
            , @c_Sku                NVARCHAR(20)
            , @c_StorerKey          NVARCHAR(15)
            , @n_OpenQty            int
            , @n_QtyAllocated       int
            , @n_QtyPicked          int
            , @n_QtyReplenish       int
            , @c_UOM                NVARCHAR(5)
            , @c_PackKey            NVARCHAR(10)
            , @c_Status             NVARCHAR(1)
            , @c_Lottable01         NVARCHAR(18)
            , @c_Lottable02         NVARCHAR(18)
            , @c_Sys_Lottable02     NVARCHAR(18)
            , @c_Lottable03         NVARCHAR(18)
            , @d_Lottable04         DATETIME
            , @d_Lottable05         DATETIME
      ,        @c_Lottable06        NVARCHAR(30)
      ,        @c_Lottable07        NVARCHAR(30)
      ,        @c_Lottable08        NVARCHAR(30)
      ,        @c_Lottable09        NVARCHAR(30)
      ,        @c_Lottable10        NVARCHAR(30)
      ,        @c_Lottable11        NVARCHAR(30)
      ,        @c_Lottable12        NVARCHAR(30)
      ,        @d_Lottable13        DATETIME
      ,        @d_Lottable14        DATETIME
      ,        @d_Lottable15        DATETIME
            , @c_Lottable01Label    NVARCHAR(18)
            , @c_Lottable02Label    NVARCHAR(18)
            , @c_Lottable03Label    NVARCHAR(18)
            , @c_Lottable04Label    NVARCHAR(18)
            , @c_Lottable05Label    NVARCHAR(18)
            , @c_Lottable06Label    NVARCHAR(18)
            , @c_Lottable07Label    NVARCHAR(18)
            , @c_Lottable08Label    NVARCHAR(18)
            , @c_Lottable09Label    NVARCHAR(18)
            , @c_Lottable10Label    NVARCHAR(18)
            , @c_Lottable11Label    NVARCHAR(18)
            , @c_Lottable12Label    NVARCHAR(18)
            , @c_Lottable13Label    NVARCHAR(18)
            , @c_Lottable14Label    NVARCHAR(18)
            , @c_Lottable15Label    NVARCHAR(18)
            , @c_OrderLineIdx       NVARCHAR(15)
            , @c_OrderKey           NVARCHAR(10)
            , @c_OrderLineNumber    NVARCHAR(5)
            , @cExecStatement       NVARCHAR(3000)
            , @n_CursorOpen         int
            , @c_UCCNo              NVARCHAR(20)
            , @c_LOT                NVARCHAR(10)
            , @c_LOC                NVARCHAR(10)
            , @c_ID                 NVARCHAR(18)
            , @n_UCC_Qty            int
            , @n_Orig_UCC_Qty       int
            , @n_QtyLeftToFulfill   int
            , @c_PickDetailKey      NVARCHAR(10)
            , @n_Cnt_SQL            int
            , @b_PickInsertSuccess  int
            , @c_ReplenishmentKey   NVARCHAR(10)
            , @c_PutawayZone        NVARCHAR(10)
            , @c_ToLoc              NVARCHAR(10)
            , @n_LOT_Qty            int
            , @n_AllocateQty        int
            , @c_PrevOrderkey       NVARCHAR(10)
            , @c_PickSlipNo         NVARCHAR(10)
            , @c_LabelNo            NVARCHAR(20)
            , @c_LabelLine          NVARCHAR(5)
            , @n_CartonNo           int
            , @c_Zone               NVARCHAR(10)
   -- Added by Shong on 27-Jul-2004
   -- Reuse Dynamic Pick Location if Fully occupied
            , @c_DynamicLocLoop     NVARCHAR(2)
            , @n_QtyInPickLOC       int -- SOS38467
            , @c_PickLOC            NVARCHAR(10)
            , @n_CaseCnt            int
            , @n_LLI_Qty            int
   -- By LoadKey
            , @c_LoadKey            NVARCHAR(10)
            , @n_QtyToAllocate      int
            , @n_QtyToReplen        int
            , @c_PrevPickSlipNo     NVARCHAR(10)

      SET @n_QtyToReplen = 0
      SET @c_ToLOC = ''
      SET @c_PickSlipNo = ''
      SET @c_PrevPickSlipNo = ''

      DELETE WaveOrderLn WHERE WaveOrderLn.WaveKey = @c_WaveKey
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue=3
         SELECT @n_err = 68001
         SELECT @c_errMsg = 'DELETE WaveOrderLn Failed (ispWaveDynamicPickUCCAlloc)'
         GOTO RETURN_SP
      END

      -- Added by SHONG on 22nd Jul 2008
      -- User Must generate Load# before allocation
      -- tlting01
      IF EXISTS(SELECT 1 FROM WAVEDETAIL WITH (NOLOCK)
                INNER JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = WAVEDETAIL.OrderKey)
                WHERE WAVEDETAIL.WaveKey = @c_WaveKey
                AND ISNULL(ORDERS.LoadKey, '') = '' )
      BEGIN
         SELECT @n_continue=3
         SELECT @n_err = 68002
         SELECT @c_errMsg = 'LoadKey not Found, Please Generate Load 1st (ispWaveDynamicPickUCCAlloc)'
         GOTO RETURN_SP
      END

     -- Added by MaryVong on 04-Aug-2008
     -- At least one DynamicPick Location exists
       
      SELECT TOP 1 @c_Facility = ORDERS.Facility
      FROM   WAVEDETAIL WITH (NOLOCK)
      INNER JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = WAVEDETAIL.OrderKey)  --tlting01
      WHERE WAVEDETAIL.WaveKey = @c_WaveKey

       

      IF NOT EXISTS(SELECT 1 FROM LOC WITH (NOLOCK)
                     WHERE LocationType = 'DYNAMICPK'
                     AND Facility = @c_Facility
                     AND LOC >= @c_DPLoc_Start )
      BEGIN
         SELECT @n_continue=3
         SELECT @n_err = 68003
         SELECT @c_errMsg = @c_DPLoc_Start + ', DynamicPick Location Not Found (ispWaveDynamicPickUCCAlloc)'
         GOTO RETURN_SP
      END

      UPDATE UCC WITH (ROWLOCK)
      SET Status = '1',
         WaveKey = ''
      FROM UCC
      JOIN REPLENISHMENT WITH (NOLOCK) ON UCC.uccno = REPLENISHMENT.refno
      WHERE REPLENISHMENT.replenno = @c_WaveKey
         AND REPLENISHMENT.Confirmed = 'W'
         AND REPLENISHMENT.ToLoc <> 'PICK'
         AND (UCC.status = '3')
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue=3
         SELECT @n_err = 68004
         SELECT @c_errMsg = 'Update UCC Failed (ispWaveDynamicPickUCCAlloc)'
         GOTO RETURN_SP
      END

      DELETE Replenishment
      WHERE ReplenNo = @c_WaveKey
         AND Confirmed = 'W'
         AND ToLoc <> 'PICK'
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue=3
         SELECT @n_err = 68005
         SELECT @c_errMsg = 'Delete Replenishment Failed (ispWaveDynamicPickUCCAlloc)'
         GOTO RETURN_SP
      END

      INSERT INTO WaveOrderLn (Facility, WaveKey, OrderKey, OrderLineNumber, Sku, StorerKey, 
                               OpenQty, QtyAllocated, QtyPicked, QtyReplenish, UOM, PackKey, Status,
                               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
                               Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
                               LoadKey)
      SELECT  ORDERS.Facility
            , WAVEDETAIL.WaveKey
            , ORDERS.OrderKey
            , ORDERDETAIL.OrderLineNumber
            , ORDERDETAIL.Sku
            , ORDERDETAIL.StorerKey
            , (ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked)
            , 0
            , 0
            , 0
            , ORDERDETAIL.UOM
            , SKU.PackKey
            , ORDERDETAIL.Status
            , ORDERDETAIL.Lottable01
            , ORDERDETAIL.Lottable02
            , ORDERDETAIL.Lottable03
            , ORDERDETAIL.Lottable04
            , ORDERDETAIL.Lottable05
            , ORDERDETAIL.Lottable06
            , ORDERDETAIL.Lottable07
            , ORDERDETAIL.Lottable08
            , ORDERDETAIL.Lottable09
            , ORDERDETAIL.Lottable10
            , ORDERDETAIL.Lottable11
            , ORDERDETAIL.Lottable12
            , ORDERDETAIL.Lottable13
            , ORDERDETAIL.Lottable14
            , ORDERDETAIL.Lottable15
            , ORDERS.LoadKey
      FROM  WAVEDETAIL (NOLOCK)
      JOIN  ORDERS WITH (NOLOCK) ON (WAVEDETAIL.OrderKey = ORDERS.OrderKey)
      JOIN  ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = WAVEDETAIL.OrderKey AND ORDERDETAIL.OrderKey = ORDERS.OrderKey)
      JOIN  SKU WITH (NOLOCK) ON  (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.SKU = SKU.SKU)
      WHERE WAVEDETAIL.WaveKey = @c_WaveKey
      AND   ORDERS.Status <> '9'
      AND   ORDERS.Type NOT IN ('M', 'I')
      AND   OrderDetail.OpenQty - ( OrderDetail.QtyAllocated + OrderDetail.QtyPreAllocated + OrderDetail.QtyPicked) > 0
      -- AND ORDERDETAIL.SKU = '288514010AL'
      -- Loop 1 Lottable02
      -- 1. Full case allocation (FCP)
      -- Retriver all the Order Lines where open Qty >= Case Qty and this Allocated Carton will going to pick from BULK
      IF (@b_debug = 1 or @b_debug = 2)
      BEGIN
         Print 'Start Allocate Full Carton (UCC)..'
      END

      IF @b_debug = 1
         select * from WaveOrderLn (nolock) where wavekey = @c_wavekey

      SET @c_Lottable01 = ''
      SET @c_Lottable03 = ''

      -- Sum QTY at Loadplan level
      DECLARE Cur_FCP_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT WOL.Loadkey, WOL.Facility, WOL.StorerKey, WOL.SKU, WOL.Lottable02,
         SUM(WOL.OpenQty) as Qty, PACK.CaseCnt, WOL.PackKey, WOL.UOM
         FROM   WaveOrderLn WOL WITH (NOLOCK)
         JOIN   SKU WITH (NOLOCK) ON WOL.StorerKey = SKU.StorerKey
                                 AND WOL.SKU = SKU.SKU
         JOIN   PACK WITH (NOLOCK) ON PACK.PackKey = SKU.PackKey
         WHERE  WOL.WaveKey = @c_WaveKey
           AND  WOL.OpenQty >= 0
         GROUP BY WOL.Loadkey, WOL.Facility, WOL.StorerKey, WOL.SKU, WOL.Lottable02, PACK.CaseCnt, WOL.PackKey, WOL.UOM
         HAVING SUM(WOL.OpenQty) >= PACK.CaseCnt
         ORDER BY WOL.Loadkey, WOL.Facility, WOL.StorerKey, WOL.SKU, WOL.Lottable02 DESC

      OPEN Cur_FCP_Pick

      FETCH NEXT FROM Cur_FCP_Pick INTO
         @c_LoadKey, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable02, @n_OpenQty, @n_CaseCnt, @c_PackKey, @c_UOM

      WHILE @@FETCH_STATUS <> -1
      BEGIN
       IF NOT EXISTS(SELECT 1 FROM UCC (NOLOCK)
                       WHERE UCC.StorerKey = @c_StorerKey
                       AND   UCC.SKU = @c_SKU
                       AND   UCC.Status BETWEEN '1' AND '2'
                       AND   UCC.Qty <= @n_OpenQty
                       AND   UCC.Qty = @n_CaseCnt)
         BEGIN
            GOTO FETCH_NEXT_FCP_CURSOR
         END

         IF @b_debug = 1
            SELECT 'LP level', @c_LoadKey '@c_LoadKey', @c_Facility '@c_Facility', @c_StorerKey '@c_StorerKey',
                   @c_SKU '@c_SKU', @c_Lottable02 '@c_Lottable02', @n_OpenQty '@n_OpenQty', @n_CaseCnt '@n_CaseCnt'

         -- Get PickSlipNo
         SELECT @c_PickSlipNo = PickHeaderKey
         FROM   PICKHEADER WITH (NOLOCK)
         WHERE  ExternOrderKey = @c_LoadKey
         AND    OrderKey = ''

         IF @b_debug = 1
            SELECT @c_PickSlipNo '@c_PickSlipNo'

         -- 20080730 Initialize CartonNo for diff PSNo or Load#
   --      IF @c_PickSlipNo <> @c_PrevPickSlipNo
   --         SET @n_CartonNo = 0
         IF (@c_PickSlipNo <> @c_PrevPickSlipNo) AND ISNULL(@c_PrevPickSlipNo, '') <> ''
            SET @n_CartonNo = 0
         ELSE  -- Added by James on 09/12/2008 SOS123961 (james02)
            SELECT @n_CartonNo = MAX(CartonNo)
            FROM PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
            AND StorerKey = @c_StorerKey

         IF ISNULL(@n_CartonNo, '') = ''
            SET @n_CartonNo = 0

         SELECT @cExecStatement =
            'DECLARE Cur_LLI CURSOR FAST_FORWARD READ_ONLY FOR  ' +
            'SELECT LLI.Lot, LLI.Loc, LLI.ID, ' +
            '(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - ISNULL(LLIMoveOut.Qty,0) ) Qty ' +
            'FROM LOTxLOCxID LLI (NOLOCK) ' +
            'JOIN LotAttribute (NOLOCK) ON (LotAttribute.LOT = LLI.LOT) ' +
            'JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = LLI.StorerKey AND SKUxLOC.SKU = LLI.SKU AND SKUxLOC.LOC = LLI.Loc) ' +
            'JOIN LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC) ' +
            'JOIN LOT (NOLOCK) ON (LOT.LOT = LLI.LOT) ' +
            'JOIN ID  (NOLOCK) ON (ID.ID = LLI.ID) ' +
            'LEFT OUTER JOIN ( SELECT LOT, FromLOC, ID,  ISNULL(SUM(Qty), 0) As Qty ' +
            '                  FROM REPLENISHMENT (NOLOCK ) ' +
            '                  WHERE Confirmed IN (''W'', ''S'') ' +
            '                  AND   StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
            '    AND   SKU = N''' + RTRIM(@c_SKU) + ''' ' +
            '                  AND   TOLOC <> ''PICK'' ' +
            '                  GROUP BY LOT, FromLOC, ID) ' +
            '                  AS LLIMoveOut ON LLIMoveOut.LOT = LLI.LOT AND LLIMoveOut.FromLOC = LLI.LOC  ' +
            '                               AND LLIMoveOut.ID = LLI.ID ' +
            'LEFT OUTER JOIN ( SELECT LOT, ISNULL(SUM(Qty), 0) As Qty ' +
            '                  FROM REPLENISHMENT (NOLOCK )  ' +
            '                  WHERE Confirmed IN (''W'', ''S'') ' +
            '                  AND   StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
            '                  AND   SKU = N''' + RTRIM(@c_SKU) + ''' ' +
            '                  AND   TOLOC <> ''PICK'' ' +
            '                  AND   Remark In (''Bulk to DP'', ''PP to DP'') ' +
            '                  GROUP BY LOT, FromLOC, ID) ' +
            '                  AS LOTMoveOut ON LOTMoveOut.LOT = LLI.LOT ' +
            'WHERE LLI.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
            'AND   LLI.SKU = N''' + RTRIM(@c_SKU) + ''' ' +
            'AND   SKUxLOC.LocationType NOT IN (''CASE'', ''PICK'') ' +
            'AND   LOC.LocationType NOT IN (''DYNAMICPK'') ' +
            'AND   LOC.LocationFlag <> ''HOLD'' ' +
            'AND   LOC.Facility =N'''+ RTRIM(@c_Facility) + ''' ' +
            'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
            'AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - ISNULL(LLIMoveOut.Qty,0) > 0 '

         --IF RTRIM(@c_Lottable01) IS NOT NULL AND RTRIM(@c_Lottable01) <> ''
         --BEGIN
         --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
         --      ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
         --END
         --IF RTRIM(@c_Lottable02) IS NOT NULL AND RTRIM(@c_Lottable02) <> ''
         --BEGIN
         --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
         --      ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '
         --END
         --IF RTRIM(@c_Lottable03) IS NOT NULL AND RTRIM(@c_Lottable03) <> ''
         --BEGIN
         --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
         --      ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '
         --END

         IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '

         IF RTRIM(ISNULL(@c_Lottable02,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '

         IF RTRIM(ISNULL(@c_Lottable03,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '

         IF RTRIM(ISNULL(@c_Lottable06,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable06 = N''' + RTRIM(@c_Lottable06) + ''' '

         IF RTRIM(ISNULL(@c_Lottable07,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable07 = N''' + RTRIM(@c_Lottable07) + ''' '

         IF RTRIM(ISNULL(@c_Lottable08,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable08 = N''' + RTRIM(@c_Lottable08) + ''' '

         IF RTRIM(ISNULL(@c_Lottable09,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable09 = N''' + RTRIM(@c_Lottable09) + ''' '

         IF RTRIM(ISNULL(@c_Lottable10,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable10 = N''' + RTRIM(@c_Lottable10) + ''' '

         IF RTRIM(ISNULL(@c_Lottable11,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable11 = N''' + RTRIM(@c_Lottable11) + ''' '

         IF RTRIM(ISNULL(@c_Lottable12,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable12 = N''' + RTRIM(@c_Lottable12) + ''' '

         SELECT @cExecStatement = RTRIM(@cExecStatement) +
            ' ORDER By LotAttribute.Lottable02 DESC, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc '


         IF (@b_debug = 2)
         BEGIN
            Print @cExecStatement
         END

         EXEC sp_executesql @cExecStatement -- AA

         OPEN Cur_LLI

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err = 16905
         BEGIN
            CLOSE Cur_LLI
            DEALLOCATE Cur_LLI
         END
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63501   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
            GOTO RETURN_SP
         END
         ELSE
         BEGIN
            SELECT @n_CursorOpen = 1
         END

         SELECT @n_QtyLeftToFulfill = @n_OpenQty

         FETCH NEXT FROM Cur_LLI INTO
            @c_Lot, @c_Loc, @c_ID, @n_LLI_Qty

         WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
         BEGIN
            -- If available LLI qty > demand qty
            IF @n_LLI_Qty >= @n_CaseCnt AND @n_QtyLeftToFulfill >= @n_CaseCnt --james m1
            BEGIN
               -- Get those unallocated UCC and Qty = CaseCnt
               DECLARE Cur_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT UCCNo, Qty
               FROM UCC with (NOLOCK, INDEX(IDX_UCC_LOTxLOCxID))
               WHERE LOT = @c_Lot
               AND   LOC = @c_Loc
               AND   ID = @c_ID
               AND   StorerKey = @c_StorerKey
               AND   SKU = @c_SKU
               AND   Status = '1'
               AND   Qty = @n_CaseCnt

               IF @b_debug  = 1
               BEGIN
                  SELECT UCCNo, Qty
                  FROM UCC with (NOLOCK, INDEX(IDX_UCC_LOTxLOCxID))
                  WHERE LOT = @c_Lot
                  AND   LOC = @c_Loc
                  AND   ID  = @c_ID
                  AND   StorerKey = @c_StorerKey
                  AND   SKU = @c_SKU
                  AND   Status = '1'
                  AND   Qty = @n_CaseCnt
               END

               OPEN Cur_UCC
               FETCH NEXT FROM Cur_UCC INTO @c_UCCNo, @n_UCC_Qty

               WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT '----- Cur_UCC LEVEL ---------------'
                     SELECT @c_SKU '@c_SKU', @c_UCCNo '@c_UCCNo', @n_UCC_Qty '@n_UCC_Qty', @n_CaseCnt '@n_CaseCnt',
                     @n_LLI_Qty '@n_LLI_Qty', @n_QtyLeftToFulfill '@n_QtyLeftToFulfill'
                  END

                  -- No more qty to allocate then exit
                  IF @n_LLI_Qty <= 0 OR @n_QtyLeftToFulfill <= 0
                     BREAK

                  -- Qty left less than a case then exit
                  IF @n_LLI_Qty < @n_CaseCnt OR @n_QtyLeftToFulfill < @n_CaseCnt
                     BREAK

                  IF @b_debug = 1
                  SELECT @n_UCC_Qty '@n_UCC_Qty', @n_LLI_Qty '@n_LLI_Qty', @n_QtyLeftToFulfill '@n_QtyLeftToFulfill',
                  @n_CaseCnt '@n_CaseCnt'

                  -- Set Orig_UCC_QTY
                  SET @n_Orig_UCC_Qty = @n_UCC_Qty

   -------- Check the LOT Qty here
                  SELECT @nLotQty = ( LOT.Qty ) - (QTYALLOCATED + QTYPICKED + QTYPREALLOCATED + QtyOnHold )
                  FROM   LOT (NOLOCK)
                  WHERE  LOT = @c_LOT

                 IF @nLotQty < @n_UCC_Qty
                 BEGIN
                     IF @b_debug = 1
                        SELECT 'BREAK -', @n_UCC_Qty '@n_UCC_Qty', @n_LLI_Qty '@n_LLI_Qty', @nLotQty '@nLotQty'

                     BREAK
                 END

   --------------------------------
                  -- Loop to Allocate Order Line for each UCC
                  WHILE 1=1 AND @n_UCC_Qty > 0
                  BEGIN
                   

                     SELECT TOP 1 @c_OrderKey        = OrderKey,
                            @c_OrderLineNumber = OrderLineNumber,
                            @n_QtyToAllocate   = OpenQty
                     FROM WaveOrderLn WITH (NOLOCK)
                     WHERE WaveKey    = @c_WaveKey
                     AND   LoadKey    = @c_LoadKey
                     AND   Facility   = @c_Facility
                     AND   StorerKey  = @c_StorerKey
                     AND   SKU      = @c_SKU
                     AND   Lottable02 = @c_Lottable02
                     AND   OpenQty > 0
                     ORDER BY OrderKey, OrderLineNumber

                     IF @@ROWCOUNT = 0
                     BEGIN
                   
                        BREAK
                     END
                      

                     IF @n_QtyToAllocate > @n_UCC_Qty
                        SET @n_QtyToAllocate = @n_UCC_Qty

                     SET @n_UCC_Qty = @n_UCC_Qty - @n_QtyToAllocate

                     IF @b_debug = 1
                        SELECT @c_OrderKey '@c_OrderKey', @c_OrderLineNumber '@c_OrderLineNumber', @c_SKU '@c_SKU',
                               @n_QtyToAllocate '@n_QtyToAllocate', @n_UCC_Qty '@n_UCC_Qty', @n_Orig_UCC_Qty '@n_Orig_UCC_Qty'

                     SELECT @b_success = 0
                     EXECUTE   nspg_getkey
                     'PickDetailKey'
                     , 10
                     , @c_PickDetailKey OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                     IF @b_debug = 1 or @b_debug = 2
                     BEGIN
                        SELECT '----- ORDERLINE LEVEL ---------------'
                        SELECT  @c_PickDetailKey '@c_PickDetailKey',
                                @c_OrderKey '@c_OrderKey',
                                @c_OrderLineNumber '@c_OrderLineNumber',
                                @c_LOT '@c_LOT',
                                @c_Storerkey '@c_Storerkey',
                                @c_SKU '@c_SKU',
                                @c_PackKey '@c_PackKey',
                                @n_UCC_Qty '@n_UCC_Qty',
                                @n_QtyToAllocate '@n_QtyToAllocate',
                                @n_QtyLeftToFulfill '@n_QtyLeftToFulfill',
                                @c_Loc '@c_Loc',
                                @c_ID '@c_ID',
                                @c_PickSlipNo '@c_PickSlipNo'
                     END

                     -- Start allocate FCP
                     IF @b_success = 1
                     BEGIN

                        INSERT INTO PICKDETAIL ( PickDetailKey,    Caseid,        PickHeaderkey,    OrderKey,
                                                 OrderLineNumber,  Lot,           Storerkey,        Sku,
                                                 PackKey,          UOM,           UOMQty,           Qty,
                                                 Loc,              ID,            Cartongroup,      Cartontype,
                                                 DoReplenish,      replenishzone, docartonize,      Trafficcop,
                                   PickMethod,       PickSlipNo,    WaveKey)
                        VALUES (@c_PickDetailKey,       '',        '',                  @c_OrderKey,
                                @c_OrderLineNumber,     @c_LOT,    @c_Storerkey,        @c_Sku,
                                @c_PackKey,             '6',       @n_QtyToAllocate,    @n_QtyToAllocate,
                                @c_Loc,                 @c_ID,     '',                  'FCP',
                                '',                     '',        'N',                 'U',
                                '8',                    @c_PickSlipNo,                  @c_WaveKey)

                        SELECT @n_err = @@ERROR, @n_cnt_sql = @@ROWCOUNT

                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63502   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert PickDetail Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
                           CLOSE Cur_LLI
                           DEALLOCATE Cur_LLI
                           GOTO RETURN_SP
                        END

                        -- Making sure the PickDetail was inserted
                        SELECT @n_cnt = COUNT(1) FROM PICKDETAIL WITH (NOLOCK)
                        WHERE  PickDetailKey = @c_PickDetailKey

                        IF (@b_debug = 1 or @b_debug = 2) and (@n_cnt_sql <> @n_cnt)
                        BEGIN
                           print 'INSERT PickDetail @@ROWCOUNT gets wrong'
                           select '@@ROWCOUNT' = @n_cnt_sql, 'COUNT(1)' = @n_cnt
                        END

                        IF NOT (@n_err = 0 AND @n_cnt = 1)
                        BEGIN
                           SELECT @b_PickInsertSuccess = 0
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63505   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert PickDetail Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '

                           CLOSE Cur_LLI
                           DEALLOCATE Cur_LLI
                           GOTO RETURN_SP
                        END
                     END -- @b_success = 1, Get PickDetail Key

                     IF @n_continue = 1 OR @n_continue = 2
                     BEGIN
                        UPDATE WaveOrderLn WITH (ROWLOCK)
                        SET OpenQty = OpenQty - @n_QtyToAllocate,
                            QtyAllocated = QtyAllocated + @n_QtyToAllocate
                        WHERE OrderKey = @c_OrderKey
                        AND   OrderLineNumber = @c_OrderLineNumber
                        AND   WaveKey = @c_WaveKey
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue=3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63509
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update WaveOrderLn Failed (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
                           CLOSE Cur_LII
                           DEALLOCATE Cur_LII
                           GOTO RETURN_SP
                        END
                     END
                  END -- While 1=1, Order Line Loop

                  -- Create PackDetail
                  -- Get Carton No
                  SET @n_CartonNo = @n_CartonNo + 1

                  -- Get Label No
                  SET @c_LabelNo = ''

                  EXECUTE nsp_genlabelno
                     @c_OrderKey,
                     @c_StorerKey  ,
                     @c_Labelno     = @c_LabelNo OUTPUT,
                     @n_Cartonno    = @n_CartonNo OUTPUT,
                     @c_button      = '',
                     @b_success     = @b_success OUTPUT,
                     @n_err         = @n_err     OUTPUT,
                     @c_errmsg      = @c_errmsg  OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     GOTO RETURN_SP
                  END

                  -- 20080730 FCP: 1 carton 1 LabelLine
                  SET @c_LabelLine = '00001'

                  IF @b_debug = 1
                  BEGIN
                     SELECT 'INSERT PACKDETAIL: ', @c_SKU '@c_SKU', @n_CartonNo '@n_CartonNo', @c_LabelNo '@c_LabelNo',
                           @c_LabelLine '@c_LabelLine', @c_UCCNo '@c_UCCNo', @n_Orig_UCC_Qty '@n_Orig_UCC_Qty'
                  END

                  INSERT INTO PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, RefNo)
                  VALUES
                  (@c_PickSlipNo, @n_CartonNo, @c_LabelNo, @c_LabelLine, @c_StorerKey, @c_SKU, 0, @c_UCCNo)
                  -- Eunice need to change to ZERO
                  --(@c_PickSlipNo, @n_CartonNo, @c_LabelNo, @c_LabelLine, @c_StorerKey, @c_SKU, @n_Orig_UCC_Qty, @c_UCCNo)

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 63501
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PACKDETAIL Failed. (ispWaveDynamicPickUCCAlloc)'
                     CLOSE Cur_LII
                     DEALLOCATE Cur_LII
                     GOTO RETURN_SP
                  END

                  -- Update UCC Status
                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
                     UPDATE UCC WITH (ROWLOCK)
                        SET Status = '3', WaveKey = @c_WaveKey
                     WHERE UCCNo = @c_UCCNo

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue=3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63506
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Failed (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
                        CLOSE Cur_LII
                        DEALLOCATE Cur_LII
                        GOTO RETURN_SP
                     END

                     EXECUTE nspg_GetKey
                        @keyname       = 'REPLENISHKEY', --Leong01
                        @fieldlength   = 10,
                        @keystring     = @c_ReplenishmentKey  OUTPUT,
                        @b_success     = @b_success   OUTPUT,
                        @n_err         = @n_err       OUTPUT,
                        @c_errmsg      = @c_errmsg    OUTPUT

                     IF NOT @b_success = 1
                     BEGIN
                      SELECT @n_continue = 3
                     END
                     ELSE
                     BEGIN
                        If @b_debug = 1
                           SELECT 'INSERT REPLEN -', 'FCP', @c_ToLOC '@c_ToLOC'

                        INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                            StorerKey,      SKU,       FromLOC,      ToLOC,
                            Lot,            Id,        Qty,          UOM,
                            PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                            RefNo,          Confirmed, ReplenNo,     Remark )
                        VALUES (
                          @c_ReplenishmentKey,        @c_FCP_ReplenGrp,
                            @c_StorerKey,   @c_SKU,     @c_LOC,           'PICK',
                            @c_LOT,         @c_ID,      @n_Orig_UCC_Qty,   @c_UOM,
                            @c_Packkey,     '1',        0,                 0,
                            @c_UCCNo,       'W',        @c_WaveKey,        'FCP'  )

                        IF @b_debug  = 1
                        BEGIN
                           SELECT '---INSERT REPLEN ---------'
                           SELECT @c_SKU '@c_SKU',
                           @c_UCCNo '@c_UCCNo',
                           @n_UCC_Qty '@n_UCC_Qty',
                           @n_Orig_UCC_Qty '@n_Orig_UCC_Qty',
                           @c_LOT '@c_LOT',
                           @c_LOC '@c_LOC'
                        END

                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63507   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
                           CLOSE Cur_LII
                           DEALLOCATE Cur_LII
                           GOTO RETURN_SP
                        END

                        IF @b_debug = 1
                           SELECT 'BEFORE', @n_UCC_Qty '@n_UCC_Qty', @n_Orig_UCC_Qty 'n_Orig_UCC_Qty',
                           @n_QtyLeftToFulfill '@n_QtyLeftToFulfill', @n_LLI_Qty '@n_LLI_Qty'

                        SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_Orig_UCC_Qty
                        SELECT @n_LLI_Qty = @n_LLI_Qty - @n_Orig_UCC_Qty

                        IF @b_debug = 1
                           SELECT 'AFTER', @n_QtyLeftToFulfill '@n_QtyLeftToFulfill', @n_LLI_Qty '@n_LLI_Qty'

                     END -- Insert Replenishment
                  END -- @n_continue = 1 OR @n_continue = 2

                FETCH NEXT FROM Cur_UCC INTO @c_UCCNo, @n_UCC_Qty
             END -- Cur_UCC Fetch Status <> 1
            CLOSE Cur_UCC
            DEALLOCATE Cur_UCC

            END -- If available LLI qty > demand qty

            GET_NEXT_LLI_RECORD:
               FETCH NEXT FROM Cur_LLI INTO @c_Lot, @c_Loc, @c_ID, @n_LLI_Qty

         END -- while  cursor
         CLOSE Cur_LLI
         DEALLOCATE Cur_LLI

         FETCH_NEXT_FCP_CURSOR:
      -- Set PrevPickSlipNo
            SET @c_PrevPickSlipNo = @c_PickSlipNo

            FETCH NEXT FROM Cur_FCP_Pick INTO
               @c_LoadKey, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable02, @n_OpenQty, @n_CaseCnt, @c_PackKey, @c_UOM

      END -- While Cur_FCP_Pick
      CLOSE Cur_FCP_Pick
      DEALLOCATE Cur_FCP_Pick

   --   IF @b_debug = 1
   --   BEGIN
   --     SELECT * FROM WaveOrderLn (NOLOCK)
   --    WHERE WaveKey = @c_WaveKey
   --    AND  OpenQty = 0
   --
   --     SELECT * FROM WaveOrderLn (NOLOCK)
   --    WHERE WaveKey = @c_WaveKey
   --   END

      -- Delete record with No QTY
      DELETE FROM WaveOrderLn
      WHERE WaveKey = @c_WaveKey
      AND  OpenQty = 0

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue=3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63508
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete WaveOrderLn Failed (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
         GOTO RETURN_SP
      END

      IF @b_debug = 1
      BEGIN
         Print 'End Allocate Full Carton (UCC)..'
         Print ''
         Print 'Start Dynamic Pick Face Replenishment...'
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- 2. Dynamic allocation (DP)
      -- Dynamic Pick Face Replenishment
      -- Dynamic Pick Location is used temporary to stored the consolidated qty by SKU with full case for same Wave.
      DECLARE @n_PickSeq int
      IF EXISTS(SELECT 1 FROM WaveOrderLn (NOLOCK) WHERE  WaveKey = @c_WaveKey AND OpenQty > 0 )
      BEGIN
         DECLARE @TempDynamicPick TABLE
         (PickSeq      smallint IDENTITY(1,1),
          Facility     NVARCHAR(5),
          StorerKey    NVARCHAR(15),
          SKU          NVARCHAR(20),
          Lottable02   NVARCHAR(18),
          UOM          NVARCHAR(10),
          Qty          int)

         DECLARE @TempDynamicLoc TABLE
            (LocSeq      smallint IDENTITY(1,1),
             PutawayZone  NVARCHAR(10),
             SKU          NVARCHAR(20),
             LOC          NVARCHAR(10),
             Status       NVARCHAR(1),
             NewLOC       NVARCHAR(10))

         INSERT INTO @TempDynamicPick (Facility, StorerKey, SKU, Lottable02, UOM, Qty)
         SELECT Facility, StorerKey, SKU, Lottable02, UOM, SUM(OpenQty) as Qty
         FROM   WaveOrderLn (NOLOCK)
         WHERE  WaveKey = @c_WaveKey and OpenQty > 0
         GROUP BY Facility, StorerKey, SKU, Lottable02, UOM
         ORDER BY Facility, StorerKey, SKU, Lottable02 DESC

         --IF @b_debug = 1 or @b_debug = 2
         --BEGIN
         --   SELECT '@TempDynamicPick', * FROM @TempDynamicPick
         --END

         SELECT @c_DynamicLocLoop = '0'

         INSERT INTO @TempDynamicLoc (PutawayZone, SKU, LOC, Status, NEWLOC)
         SELECT DISTINCT SKU.PutawayZone, WaveOrderLn.SKU, '', '0', ''
         FROM   WaveOrderLn (NOLOCK)
         JOIN   SKU (NOLOCK) ON (WaveOrderLn.StorerKey = SKU.StorerKey and WaveOrderLn.SKU = SKU.SKU)
         WHERE  WaveKey = @c_WaveKey AND OpenQty > 0
         ORDER BY WaveOrderLn.SKU

         IF EXISTS(SELECT 1 FROM @TempDynamicPick)
         BEGIN
            SELECT @n_PickSeq = 0

            WHILE 1=1 and (@n_continue = 1 or @n_continue = 2)
            BEGIN
               SELECT @n_PickSeq = MIN(PickSeq)
               FROM   @TempDynamicPick
               WHERE  PickSeq > @n_PickSeq

               IF @n_PickSeq IS NULL OR @n_PickSeq = 0
                  BREAK

               SELECT @c_StorerKey        = SKU.StorerKey,
                      @c_SKU              = SKU.SKU,
                      @c_Lottable02       = TDP.Lottable02,
                      @n_OpenQty          = TDP.Qty,
                      @c_Lottable01Label  = SKU.Lottable01Label,
                      @c_Lottable02Label  = SKU.Lottable02Label,
                      @c_Lottable03Label  = SKU.Lottable03Label,
                      @c_Lottable04Label  = SKU.Lottable04Label,
                      @c_Lottable05Label  = SKU.Lottable05Label,
                      @c_Lottable06Label  = SKU.Lottable06Label,
                      @c_Lottable07Label  = SKU.Lottable07Label,
                      @c_Lottable08Label  = SKU.Lottable08Label,
                      @c_Lottable09Label  = SKU.Lottable09Label,
                      @c_Lottable10Label  = SKU.Lottable10Label,
                      @c_Lottable11Label  = SKU.Lottable11Label,
                      @c_Lottable12Label  = SKU.Lottable12Label,
                      @c_Lottable13Label  = SKU.Lottable13Label,
                      @c_Lottable14Label  = SKU.Lottable14Label,
                      @c_Lottable15Label  = SKU.Lottable15Label,
                      @c_PutawayZone      = SKU.PutawayZone,
                      @c_PackKey          = SKU.PackKey,
                      @n_CaseCnt          = PACK.CaseCnt,
                      @c_Facility         = TDP.Facility,
                      @c_UOM              = TDP.UOM
               FROM @TempDynamicPick TDP
               JOIN  SKU (NOLOCK) ON (SKU.StorerKey = TDP.StorerKey AND SKU.SKU = TDP.SKU)
               JOIN  PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
               WHERE TDP.PickSeq = @n_PickSeq

               SELECT @cExecStatement =
                  'DECLARE DynPickCursor CURSOR FAST_FORWARD READ_ONLY FOR  ' +
                  'SELECT LLI.Lot, LLI.Loc, LLI.ID, ' +
                  '(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - ISNULL(LLIMoveOut.Qty,0) ) Qty ' +
                  'FROM LOTxLOCxID LLI (NOLOCK) ' +
                  'JOIN LotAttribute (NOLOCK) ON (LotAttribute.LOT = LLI.LOT) ' +
                  'JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = LLI.StorerKey AND SKUxLOC.SKU = LLI.SKU AND SKUxLOC.LOC = LLI.Loc) ' +
                  'JOIN LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC) ' +
                  'JOIN LOT (NOLOCK) ON (LOT.LOT = LLI.LOT) ' +
                  'JOIN ID  (NOLOCK) ON (ID.ID = LLI.ID) ' +
                  'LEFT OUTER JOIN ( SELECT LOT, FromLOC, ID,  ISNULL(SUM(Qty), 0) As Qty ' +
                  '                  FROM REPLENISHMENT (NOLOCK ) ' +
                  '                  WHERE Confirmed IN (''W'', ''S'') ' +
                  '                  AND   StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
                  '                  AND   SKU = N''' + RTRIM(@c_SKU) + ''' ' +
                  '                  AND   TOLOC <> ''PICK'' ' +
                  '                  GROUP BY LOT, FromLOC, ID) ' +
                  '                  AS LLIMoveOut ON LLIMoveOut.LOT = LLI.LOT AND LLIMoveOut.FromLOC = LLI.LOC  ' +
                  '                               AND LLIMoveOut.ID = LLI.ID ' +
                  'LEFT OUTER JOIN ( SELECT LOT, ISNULL(SUM(Qty), 0) As Qty ' +
                  '                  FROM REPLENISHMENT (NOLOCK )  ' +
                  '                  WHERE Confirmed IN (''W'', ''S'') ' +
                  '                  AND   StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
                  '                  AND   SKU = N''' + RTRIM(@c_SKU) + ''' ' +
                  '                  AND   TOLOC <> ''PICK'' ' +
                  '                  AND   Remark In (''Bulk to DP'', ''PP to DP'') ' +
                  '                  GROUP BY LOT, FromLOC, ID) ' +
                  '                  AS LOTMoveOut ON LOTMoveOut.LOT = LLI.LOT ' +
                  'WHERE LLI.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
                  'AND   LLI.SKU = N''' + RTRIM(@c_SKU) + ''' ' +
                  'AND   SKUxLOC.LocationType NOT IN (''CASE'', ''PICK'') ' +
                  'AND   LOC.LocationType NOT IN (''DYNAMICPK'') ' +
                  'AND   LOC.LocationFlag <> ''HOLD'' ' +
                  'AND   LOC.Facility =N'''+ RTRIM(@c_Facility) + ''' ' +
                  'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
                  'AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - ISNULL(LLIMoveOut.Qty,0) > 0 '

               --IF RTRIM(@c_Lottable01) IS NOT NULL AND RTRIM(@c_Lottable01) <> ''
               --BEGIN
               --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
               --      ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
               --END
               --IF RTRIM(@c_Lottable02) IS NOT NULL AND RTRIM(@c_Lottable02) <> ''
               --BEGIN
               --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
               --      ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '
               --END
               --IF RTRIM(@c_Lottable03) IS NOT NULL AND RTRIM(@c_Lottable03) <> ''
               --BEGIN
               --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
               --      ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '
               --END

               IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '

               IF RTRIM(ISNULL(@c_Lottable02,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '

               IF RTRIM(ISNULL(@c_Lottable03,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '

               IF RTRIM(ISNULL(@c_Lottable06,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable06 = N''' + RTRIM(@c_Lottable06) + ''' '

               IF RTRIM(ISNULL(@c_Lottable07,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable07 = N''' + RTRIM(@c_Lottable07) + ''' '

               IF RTRIM(ISNULL(@c_Lottable08,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable08 = N''' + RTRIM(@c_Lottable08) + ''' '

               IF RTRIM(ISNULL(@c_Lottable09,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable09 = N''' + RTRIM(@c_Lottable09) + ''' '

               IF RTRIM(ISNULL(@c_Lottable10,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable10 = N''' + RTRIM(@c_Lottable10) + ''' '

               IF RTRIM(ISNULL(@c_Lottable11,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable11 = N''' + RTRIM(@c_Lottable11) + ''' '

               IF RTRIM(ISNULL(@c_Lottable12,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable12 = N''' + RTRIM(@c_Lottable12) + ''' '

               IF RTRIM(@c_Lottable02Label) IS NOT NULL AND RTRIM(@c_Lottable02Label) <> ''
               BEGIN
                  SELECT @cExecStatement = RTRIM(@cExecStatement) +
                     ' ORDER By LotAttribute.Lottable02 DESC, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc '
               END
               ELSE
               BEGIN
                  SELECT @cExecStatement = RTRIM(@cExecStatement) +
                     ' ORDER By LotAttribute.Lottable05,LOC.LogicalLocation, SKUxLOC.Loc '
               END

               IF (@b_debug = 1)
               BEGIN
                  Print @cExecStatement
               END

               EXEC sp_executesql @cExecStatement -- BB

               OPEN DynPickCursor
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err = 16905
               BEGIN
                  CLOSE DynPickCursor
                  DEALLOCATE DynPickCursor
               END
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63510   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
                  GOTO RETURN_SP
               END
               ELSE
               BEGIN
                  SELECT @n_CursorOpen = 1
               END

               SELECT @n_QtyLeftToFulfill = @n_OpenQty

               FETCH NEXT FROM DynPickCursor INTO
                  @c_Lot, @c_Loc, @c_ID, @n_LLI_Qty

               WHILE @@FETCH_STATUS <> -1 AND @n_QtyLeftToFulfill > 0 AND (@n_continue=1 OR @n_continue=2)
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT 'BULK To DP', @c_Lot '@c_Lot', @c_Loc '@c_Loc', @c_ID '@c_ID',
                       @n_LLI_Qty '@n_LLI_Qty', @n_QtyLeftToFulfill '@n_QtyLeftToFulfill'
                  END

                  -- Get those unallocated UCC
                  DECLARE Cur_UCC CURSOR FAST_FORWARD READ_ONLY FOR
                  SELECT UCCNo, Qty
                  FROM UCC with (NOLOCK, INDEX(IDX_UCC_LOTxLOCxID))
                  WHERE LOT = @c_Lot
                     AND LOC = @c_Loc
                     AND ID = @c_ID
                     AND StorerKey = @c_StorerKey
                     AND Status = '1'

                  OPEN Cur_UCC
                  FETCH NEXT FROM Cur_UCC INTO @c_UCCNo, @n_UCC_Qty
                  WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
                  BEGIN
                     IF @n_LLI_Qty >= @n_UCC_Qty
                     BEGIN
                        -- If UCC QTY more than enough to fulfill the balance
                        IF @n_UCC_Qty > @n_QtyLeftToFulfill
                        BEGIN
                           SET @n_QtyToReplen = 0 -- don't take the UCC
                        END
                        ELSE
                        BEGIN
                           -- UCC QTY not enough to fulfill the balance
                           SET @n_QtyToReplen = @n_UCC_Qty  -- take the whole UCC anyway
                           SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_UCC_Qty -- Reduce balance
                        END

                        IF @n_QtyToReplen > 0
                        BEGIN
                            -- Lock UCC
                           UPDATE UCC
                            SET Status = '3', WaveKey = @c_WaveKey
                           WHERE UCCNo = @c_UCCNo
                           SELECT @n_err = @@ERROR
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_continue=3
                              SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63511
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Failed (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
                              CLOSE DynPickCursor
                              DEALLOCATE DynPickCursor
                              GOTO RETURN_SP
                           END

                           -- Insert Replenishment record
                           EXECUTE nspg_GetKey
                              @keyname       = 'REPLENISHKEY', --Leong01
                              @fieldlength   = 10,
                              @keystring     = @c_ReplenishmentKey  OUTPUT,
                              @b_success     = @b_success   OUTPUT,
                              @n_err         = @n_err       OUTPUT,
                              @c_errmsg      = @c_errmsg    OUTPUT

                           IF @b_success <> 1
                           BEGIN
                              SELECT @n_continue = 3
                              CLOSE DynPickCursor
                              DEALLOCATE DynPickCursor
                              GOTO RETURN_SP
                           END

                           IF @n_continue=1 OR @n_continue=2
                           BEGIN
                              -- Replen# = Wave key, RefNo = UCC No
                              If @b_debug = 1
                                 SELECT 'INSERT REPLEN -', 'BULK to DP', @c_ToLOC '@c_ToLOC'

                              INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                                  StorerKey,      SKU,       FromLOC,      ToLOC,
                                  Lot,            Id,        Qty,          UOM,
                                  PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                              RefNo,          Confirmed, ReplenNo,     Remark )
                              VALUES (
                                  @c_ReplenishmentKey,       @c_B2D_ReplenGrp,
                                  @c_StorerKey,   @c_SKU,    @c_LOC,          @c_ToLOC,
                                  @c_LOT,         @c_ID,     @n_UCC_Qty,  @c_UOM,
                                  @c_Packkey,     '1',       0,               0,
                                  @c_UCCNo, 'W',       @c_WaveKey,      'BULK to DP')

                              SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                              IF @n_err <> 0
                              BEGIN
                                 SELECT @n_continue = 3
                                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63513   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
                                 CLOSE DynPickCursor
                                 DEALLOCATE DynPickCursor
                                 GOTO RETURN_SP
                              END
                           END   -- @n_continue=1 OR @n_continue=2

                           IF @n_continue <> 1 AND @n_continue <> 2
                           BREAK

                           -- Update @TempDynamicPick record
                           IF (@n_continue = 1 OR @n_continue = 2)
                           BEGIN
                              UPDATE @TempDynamicPick
                              SET Qty = Qty - @n_UCC_Qty
                              WHERE PickSeq = @n_PickSeq

                              EXEC ispAllocateWaveOrderLn @c_WaveKey, @c_StorerKey, @c_SKU,
                                    @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06, @c_Lottable07, 
                                    @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, 
                                    @n_UCC_Qty
                           END
                        END

                        IF @n_QtyLeftToFulfill = 0  BREAK

                        SET @n_LLI_Qty = @n_LLI_Qty - @n_UCC_Qty

                        IF @b_debug = 1
                        SELECT @c_UCCNo '@c_UCCNo', @n_UCC_Qty '@n_UCC_Qty', @n_QtyLeftToFulfill '@n_QtyLeftToFulfill'

                     END -- @n_LLI_Qty >= @n_UCC_Qty

                     FETCH NEXT FROM Cur_UCC INTO @c_UCCNo, @n_UCC_QTY
                  END
                  CLOSE Cur_UCC
                  DEALLOCATE Cur_UCC

                  FETCH NEXT FROM DynPickCursor INTO
                  @c_Lot, @c_Loc, @c_ID, @n_LLI_Qty
               END -- while  cursor
               CLOSE DynPickCursor
               DEALLOCATE DynPickCursor
            END
         END -- IF EXISTS(SELECT 1 FROM @TempDynamicPick)
      END -- Select OpenQty > 0
   END -- @n_continue=1 OR @n_continue=2


   -- DROP TABLE @TempDynamicPick
   -- Dynamic Pick Allocation Completed
   IF @b_debug = 1
   BEGIN
      select 'continue value : ', @n_continue
      SELECT * FROM WaveOrderLn
   END
   IF @b_debug = 1
   BEGIN
      Print 'End Dynamic Pick Face Replenishment...'
      PRint ''
      Print 'Start Allocate from Pick Location...'
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_OrderLineIdx = ''

      DECLARE CUR_WaveOrderLine CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT WaveOrderLn.OrderKey, WaveOrderLn.OrderLineNumber
      FROM   WaveOrderLn WITH (NOLOCK)
      WHERE  WaveKey    = @c_WaveKey
      ORDER  BY StorerKey, SKU

      OPEN CUR_WaveOrderLine

      WHILE 1=1 AND (@n_continue=1 OR @n_continue=2)
      BEGIN
         FETCH NEXT FROM CUR_WaveOrderLine INTO @c_OrderKey, @c_OrderLineNumber

         IF @@FETCH_STATUS <> 0
            BREAK

         SELECT @c_Facility         = WaveOrderLn.Facility,
                @c_WaveKey          = WaveOrderLn.WaveKey,
                @c_Sku              = WaveOrderLn.SKU,
                @c_StorerKey        = WaveOrderLn.StorerKey,
                @n_OpenQty          = WaveOrderLn.OpenQty,
                @n_QtyAllocated     = WaveOrderLn.QtyAllocated,
                @n_QtyPicked        = WaveOrderLn.QtyPicked,
                @n_QtyReplenish     = WaveOrderLn.QtyReplenish,
                @c_UOM              = WaveOrderLn.UOM,
                @c_PackKey          = WaveOrderLn.PackKey,
                @c_Status           = WaveOrderLn.Status,
                @c_Lottable01       = WaveOrderLn.Lottable01,
                @c_Lottable02       = WaveOrderLn.Lottable02,
                @c_Lottable03       = WaveOrderLn.Lottable03,
                @d_Lottable04       = WaveOrderLn.Lottable04,
                @d_Lottable05       = WaveOrderLn.Lottable05,
                @c_Lottable06       = WaveOrderLn.Lottable06,
                @c_Lottable07       = WaveOrderLn.Lottable07,
                @c_Lottable08       = WaveOrderLn.Lottable08,
                @c_Lottable09       = WaveOrderLn.Lottable09,
                @c_Lottable10       = WaveOrderLn.Lottable10,
                @c_Lottable11       = WaveOrderLn.Lottable11,
                @c_Lottable12       = WaveOrderLn.Lottable12,
                @d_Lottable13       = WaveOrderLn.Lottable13,
                @d_Lottable14       = WaveOrderLn.Lottable14,
                @d_Lottable15       = WaveOrderLn.Lottable15,
                @c_Lottable01Label  = SKU.Lottable01Label,
                @c_Lottable02Label  = SKU.Lottable02Label,
                @c_Lottable03Label  = SKU.Lottable03Label,
                @c_Lottable04Label  = SKU.Lottable04Label,
                @c_Lottable05Label  = SKU.Lottable05Label,
                @c_Lottable06Label  = SKU.Lottable06Label,
                @c_Lottable07Label  = SKU.Lottable07Label,
                @c_Lottable08Label  = SKU.Lottable08Label,
                @c_Lottable09Label  = SKU.Lottable09Label,
                @c_Lottable10Label  = SKU.Lottable10Label,
                @c_Lottable11Label  = SKU.Lottable11Label,
                @c_Lottable12Label  = SKU.Lottable12Label,
                @c_Lottable13Label  = SKU.Lottable13Label,
                @c_Lottable14Label  = SKU.Lottable14Label,
                @c_Lottable15Label  = SKU.Lottable15Label,
                @c_PutawayZone      = SKU.PutawayZone
         FROM WaveOrderLn WITH (NOLOCK)
         JOIN  SKU (NOLOCK) ON (SKU.StorerKey = WaveOrderLn.StorerKey AND SKU.SKU = WaveOrderLn.SKU)
         WHERE OrderKey = @c_OrderKey
         AND   OrderLineNumber = @c_OrderLineNumber
         AND   WaveKey    = @c_WaveKey

         SELECT @c_country = c_country
         FROM ORDERS (NOLOCK)
         WHERE OrderKey = @c_OrderKey

         SELECT @cExecStatement =
            'DECLARE PickCursor CURSOR FAST_FORWARD READ_ONLY FOR  ' +
            'SELECT LOTxLOCxID.Lot, LOTxLOCxID.Loc, LOTxLOCxID.ID, ' +
            '(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - ISNULL(RP.Qty,0) ' +
            'FROM LOTxLOCxID (NOLOCK) ' +
            'JOIN LotAttribute (NOLOCK) ON (LOTxLOCxID.LOT = LotAttribute.LOT) ' +
            'JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = LOTxLOCxID.StorerKey AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.Loc) ' +
            'JOIN LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC) ' +
            'JOIN LOT (NOLOCK) ON (LOT.LOT = LOTxLOCxID.LOT) ' +
            'JOIN ID  (NOLOCK) ON (ID.ID = LOTxLOCxID.ID) ' +
            'LEFT OUTER JOIN (SELECT LOT, FromLOC, ID, SUM(QTY) AS Qty ' +
            '                 FROM REPLENISHMENT (NOLOCK) ' +
            '                 WHERE Confirmed IN (''W'',''S'') ' +
            '                 AND   ToLOC <> ''PICK'' ' + -- 20080730 Need to exclude FCP bcos FCP already allocated
            '                 AND   StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
            '                 AND   SKU = N''' + RTRIM(@c_SKU) + ''' ' +
            '                 GROUP BY LOT, FromLOC, ID) AS RP ' +
            '                 ON (RP.LOT = LOTxLOCxID.LOT AND RP.FromLOC = LOTxLOCxID.LOC AND RP.ID = LOTxLOCxID.ID) ' +
            'WHERE LOTxLOCxID.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
            'AND   LOTxLOCxID.SKU = N''' + RTRIM(@c_SKU) + ''' ' +
            'AND   (SKUxLOC.LocationType IN (''CASE'', ''PICK'') OR LOC.LocationType = ''CASE'') ' +
            'AND   LOC.LocationFlag <> ''HOLD'' ' +
            'AND   LOC.Facility =N'''+ RTRIM(@c_Facility) + ''' ' +
            'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
            'AND  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - ISNULL(RP.Qty,0) > 0 '

         --IF RTRIM(@c_Lottable01) IS NOT NULL AND RTRIM(@c_Lottable01) <> ''
         --BEGIN
         --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
         --      ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
         --END
         --IF RTRIM(@c_Lottable02) IS NOT NULL AND RTRIM(@c_Lottable02) <> ''
         --BEGIN
         --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
         --      ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '
         --END
         --IF RTRIM(@c_Lottable03) IS NOT NULL AND RTRIM(@c_Lottable03) <> ''
         --BEGIN
         --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
         --      ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '
         --END


         IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '

         IF RTRIM(ISNULL(@c_Lottable02,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '

         IF RTRIM(ISNULL(@c_Lottable03,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '

         IF RTRIM(ISNULL(@c_Lottable06,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable06 = N''' + RTRIM(@c_Lottable06) + ''' '

         IF RTRIM(ISNULL(@c_Lottable07,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable07 = N''' + RTRIM(@c_Lottable07) + ''' '

         IF RTRIM(ISNULL(@c_Lottable08,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable08 = N''' + RTRIM(@c_Lottable08) + ''' '

         IF RTRIM(ISNULL(@c_Lottable09,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable09 = N''' + RTRIM(@c_Lottable09) + ''' '

         IF RTRIM(ISNULL(@c_Lottable10,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable10 = N''' + RTRIM(@c_Lottable10) + ''' '

         IF RTRIM(ISNULL(@c_Lottable11,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable11 = N''' + RTRIM(@c_Lottable11) + ''' '

         IF RTRIM(ISNULL(@c_Lottable12,'')) <> ''
            SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable12 = N''' + RTRIM(@c_Lottable12) + ''' '

         IF RTRIM(@c_Lottable02Label) IS NOT NULL AND RTRIM(@c_Lottable02Label) <> ''
         BEGIN
            SELECT @cExecStatement = RTRIM(@cExecStatement) +
               ' ORDER By LotAttribute.Lottable02 DESC, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc '
         END
         ELSE
         BEGIN
            SELECT @cExecStatement = RTRIM(@cExecStatement) +
               ' ORDER By LotAttribute.Lottable05, SKUxLOC.LocationType, LOC.LogicalLocation, SKUxLOC.Loc '
         END

         IF @b_debug = 1
         BEGIN
            Print @cExecStatement
         END

         EXEC sp_executesql @cExecStatement -- CC

         OPEN PickCursor
         SELECT @n_err = @@ERROR --, @n_cnt = @@CURSOR_ROWS
         IF @n_err = 16905 -- OR @n_cnt = 0
         BEGIN
            -- SELECT @n_continue = 4
            CLOSE PickCursor
            DEALLOCATE PickCursor
            BREAK
         END
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63514   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
            GOTO RETURN_SP
         END
         ELSE
         BEGIN
            SELECT @n_CursorOpen = 1
         END

         SELECT @n_QtyLeftToFulfill = @n_OpenQty
         SELECT @n_AllocateQty = 0

         FETCH NEXT FROM PickCursor INTO
            @c_Lot, @c_Loc, @c_ID, @n_LOT_Qty

         WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
         BEGIN

            IF @n_LOT_Qty > 0 AND @n_QtyLeftToFulfill > 0
            BEGIN

               IF @n_LOT_Qty > @n_QtyLeftToFulfill
                  SELECT @n_AllocateQty = @n_QtyLeftToFulfill
               ELSE
                  SELECT @n_AllocateQty = @n_LOT_Qty

    --           select @c_sku '@c_sku', @n_LOT_Qty '@n_LOT_Qty', @n_QtyLeftToFulfill '@n_QtyLeftToFulfill', @n_AllocateQty '@n_AllocateQty'

               -- Insert into Replenishment
               EXECUTE nspg_GetKey
                   @keyname       = 'REPLENISHKEY', --Leong01
                   @fieldlength   = 10,
                   @keystring     = @c_ReplenishmentKey  OUTPUT,
                   @b_success     = @b_success   OUTPUT,
                   @n_err         = @n_err       OUTPUT,
                   @c_errmsg      = @c_errmsg    OUTPUT

               IF @b_success = 1
               BEGIN
                  SELECT @c_ToLOC = LOC
                  FROM   @TempDynamicLoc
                  WHERE  PutawayZone = @c_PutawayZone
                  AND    SKU = @c_SKU

                  IF ISNULL(RTRIM(@c_ToLOC), '') = ''
                  BEGIN
                     SELECT @c_ToLoc = MAX(LOC) FROM @TempDynamicLoc

                     SELECT @c_ToLOC = MIN(LOC.LOC)
                     FROM   LOC (NOLOCK)
                     WHERE  LOC.LocationType = 'DYNAMICPK'
                     AND    LOC.LocationFlag <> 'HOLD'
                     AND    LOC.PutawayZone = @c_PutawayZone
                     AND    LOC.Loc > @c_ToLoc
                     AND    LOC.Facility = @c_Facility

                  END

                  IF @b_debug = 1
                  BEGIN
                     SELECT '@TempDynamicLoc', * FROM @TempDynamicLoc
                     SELECT '@c_PutawayZone', @c_PutawayZone
                     SELECT '@c_ToLoc', @c_ToLoc
                     SELECT '@c_Facility', @c_Facility
                  END

                  IF RTRIM(@c_ToLOC) IS NULL
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = '', @n_err = 63512   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Dynamic Pick Location Not Found or FULL ! (ispWaveDynamicPickUCCAlloc)'
                     CLOSE PickCursor
                     DEALLOCATE PickCursor
                    GOTO RETURN_SP
                  END
                  ELSE
                  BEGIN
                     UPDATE @TempDynamicLoc
                     SET LOC = @c_ToLOC
                     WHERE SKU = @c_SKU AND PutawayZone = @c_PutawayZone

                  END

                  IF @n_continue=1 OR @n_continue=2
                  BEGIN
                     -- Replen# = Wave key
                     -- RefNo = UCC No
                     If @b_debug = 1
                        SELECT 'INSERT REPLEN -', 'PP to DP', @c_ToLOC '@c_ToLOC'

                     INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                         StorerKey,      SKU,       FromLOC,      ToLOC,
                         Lot,            Id,        Qty,          UOM,
                         PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                         RefNo,          Confirmed, ReplenNo,     Remark )
                     VALUES (
                         @c_ReplenishmentKey,       @c_P2D_ReplenGrp,
                         @c_StorerKey,   @c_SKU,    @c_LOC,         @c_ToLOC,
                         @c_LOT,         @c_ID,     @n_AllocateQty, @c_UOM,
                         @c_Packkey,     '1',       0,    0,
                         '',             'W',       @c_WaveKey,     'PP to DP')

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63513   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
                        CLOSE PickCursor
                        DEALLOCATE PickCursor
                        GOTO RETURN_SP

                     END
                     ELSE
                     BEGIN
                        IF @n_AllocateQty = @n_QtyLeftToFulfill
                        BEGIN
                           DELETE FROM WaveOrderLn
                           WHERE OrderKey = @c_OrderKey
                           AND   OrderLineNumber = @c_OrderLineNumber
                           AND   WaveKey    = @c_WaveKey

                           SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_AllocateQty
                        END -- @n_LOT_Qty = @n_QtyLeftToFulfill
                        ELSE IF @n_AllocateQty < @n_QtyLeftToFulfill
                        BEGIN
                           UPDATE WaveOrderLn
                           SET OpenQty = OpenQty - @n_LOT_Qty,
                               QtyAllocated = QtyAllocated + @n_AllocateQty
                           WHERE OrderKey = @c_OrderKey
                           AND   OrderLineNumber = @c_OrderLineNumber
                           AND   WaveKey    = @c_WaveKey

                           SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_AllocateQty
                        END -- IF @n_LOT_Qty < @n_QtyLeftToFulfill

                     END
                  END
               END -- @b_success = 1
            END -- @n_LOT_Qty <= @n_QtyLeftToFulfill
            ELSE
            BEGIN
               BREAK
            END

            FETCH NEXT FROM PickCursor INTO
               @c_Lot, @c_Loc, @c_ID, @n_LOT_Qty
         END -- while  cursor
         CLOSE PickCursor
         DEALLOCATE PickCursor
      END -- While CUR_WaveOrderLine
      CLOSE CUR_WaveOrderLine
      DEALLOCATE CUR_WaveOrderLine
   END

   IF @b_debug = 1
   BEGIN
      Print 'End Allocate from Pick Location...'
      Print ''
      Print 'Start Replenisment from Bulk to Pick Loc...'
   END
   -- Completed Pick Location allocation

   -- If still have outstanding in Order Detail.....
   -- Create Replenishment to Move Stock to Dynamic Pick Location for Left over open Qty
   -- and remaining qty will move to Pick Location...
   --
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM WaveOrderLn (NOLOCK) WHERE  WaveKey = @c_WaveKey and OpenQty > 0 )
      BEGIN
         DECLARE @TempReplen TABLE
         (PickSeq      smallint IDENTITY(1,1),
          Facility     NVARCHAR(5),
          StorerKey    NVARCHAR(15),
          SKU          NVARCHAR(20),
          Lottable02   NVARCHAR(18),
          UOM          NVARCHAR(10),
          Qty          int )

         DECLARE @TempPickLoc TABLE
         (Sku          NVARCHAR(20),
          LOC     NVARCHAR(10),
          Status       NVARCHAR(1) )

         INSERT INTO @TempReplen (Facility, StorerKey, SKU, Lottable02, UOM, Qty)
         SELECT Facility, StorerKey, SKU, Lottable02, UOM, SUM(OpenQty) as Qty
         FROM   WaveOrderLn (NOLOCK)
         WHERE  WaveKey = @c_WaveKey and OpenQty > 0
         GROUP BY Facility,StorerKey, SKU, Lottable02, UOM
         ORDER BY Facility,StorerKey, SKU, Lottable02

         IF (@b_debug = 1 or @b_debug = 3)
         BEGIN
            Print 'Bulk to Pick Loc - @TempReplen'
            SELECT * FROM @TempReplen
         END

         INSERT INTO @TempPickLoc (Sku, LOC, Status)
         SELECT DISTINCT SKUxLOC.Sku, SKUxLOC.LOC, '0'
         FROM   WaveOrderLn (NOLOCK)
         JOIN   SKUxLOC (NOLOCK) ON (WaveOrderLn.StorerKey = SKUxLOC.StorerKey AND WaveOrderLn.SKU = SKUxLOC.SKU)
         JOIN   LOC (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC AND LOC.Facility = WaveOrderLn.Facility)
         WHERE  WaveKey = @c_WaveKey
         and    OpenQty > 0
         AND    SKUxLOC.LocationType IN ('PICK', 'CASE')

         IF (@b_debug = 1 or @b_debug = 3)
         BEGIN
            Print ' Table: @TempPickLoc'
            SELECT * FROM @TempPickLoc

            Print ' Table: @TempReplen'
            SELECT * FROM @TempReplen
         END

         IF EXISTS(SELECT 1 FROM @TempReplen)
         BEGIN
            SELECT @n_PickSeq = 0

            WHILE 1=1 AND (@n_continue=1 OR @n_continue=2)
            BEGIN
               READ_NEXT_REPLEN:

               SELECT @n_PickSeq = MIN(PickSeq)
               FROM   @TempReplen
               WHERE  PickSeq > @n_PickSeq

               IF @n_PickSeq IS NULL OR @n_PickSeq = 0
                  BREAK

               SELECT @c_StorerKey        = SKU.StorerKey,
                      @c_SKU              = SKU.SKU,
                      @c_Lottable02       = TR.Lottable02,
                      @n_OpenQty          = TR.Qty,
                      @c_Lottable01Label  = SKU.Lottable01Label,
                      @c_Lottable02Label  = SKU.Lottable02Label,
                      @c_Lottable03Label  = SKU.Lottable03Label,
                      @c_Lottable04Label  = SKU.Lottable04Label,
                      @c_Lottable05Label  = SKU.Lottable05Label,
                      @c_Lottable06Label  = SKU.Lottable06Label,
                      @c_Lottable07Label  = SKU.Lottable07Label,
                      @c_Lottable08Label  = SKU.Lottable08Label,
                      @c_Lottable09Label  = SKU.Lottable09Label,
                      @c_Lottable10Label  = SKU.Lottable10Label,
                      @c_Lottable11Label  = SKU.Lottable11Label,
                      @c_Lottable12Label  = SKU.Lottable12Label,
                      @c_Lottable13Label  = SKU.Lottable13Label,
                      @c_Lottable14Label  = SKU.Lottable14Label,
                      @c_Lottable15Label  = SKU.Lottable15Label,
                      @c_PutawayZone      = SKU.PutawayZone,
                      @c_PackKey          = SKU.PackKey,
                      @n_CaseCnt          = PACK.CaseCnt,
                      @c_Facility         = TR.Facility,
                      @c_UOM              = TR.UOM
               FROM @TempReplen TR
               JOIN  SKU (NOLOCK) ON (SKU.StorerKey = TR.StorerKey AND SKU.SKU = TR.SKU)
               JOIN  PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
               WHERE TR.PickSeq = @n_PickSeq

               SELECT @n_QtyLeftToFulfill = @n_OpenQty

              SELECT @c_ToLOC = MIN(TP.LOC)
              FROM   @TempPickLoc TP
              JOIN LOTxLOCxID (NOLOCK)
                  ON TP.Loc = LOTxLOCxID.Loc
                     AND TP.Sku = LOTxLOCxID.Sku
                     AND LOTxLOCxID.Lot = @c_LOT
                     AND LOTxLOCxID.Qty > 0
               JOIN LOC (NOLOCK) ON LOC.LOC = LOTxLOCxID.Loc AND LOC.Facility = @c_Facility
               WHERE  TP.Status = '0'
               AND    TP.Sku = @c_sku

               IF ISNULL(RTRIM(@c_ToLOC),'') = ''
               BEGIN -- look for empty pick loc
                  SELECT @c_ToLOC = MIN(TP.LOC)
                  FROM   @TempPickLoc TP
                  JOIN SKUxLOC (NOLOCK)
                     ON TP.Loc = SKUxLOC.Loc
                        AND TP.Sku = SKUxLOC.Sku
                        AND SKUxLOC.Qty = 0
                  JOIN LOC (NOLOCK) ON LOC.LOC = SKUxLOC.Loc AND LOC.Facility = @c_Facility
                  WHERE  TP.Status = '0'
                  AND    TP.Sku = @c_sku
               END

               IF ISNULL(RTRIM(@c_ToLOC),'') = ''
               BEGIN
                  SELECT @c_ToLOC = MIN(TP.LOC)
                  FROM   @TempPickLoc TP
                  WHERE  TP.Status = '0'
                  AND TP.Sku = @c_sku
               END

               IF ISNULL(RTRIM(@c_ToLOC),'') = ''
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = '', @n_err = 63516   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Permanent Pick Location Not Setup For SKU: ' + RTRIM(@c_SKu) + '! (ispWaveDynamicPickUCCAlloc)'
                  GOTO RETURN_SP
               END

               -- To Cater the parallel wave dynamic pick
               -- Need to check how many UCC replenishment already created in other Wave
               SET    @nQtyRepleInProgress = 0
               /* SOS125308 - Allocate based on lottable specify in orderdetail.lottable (james03)

               -- SHONG20080729 Pervious Select Statement result is wrong!
               DECLARE CurOutstandingReplen CURSOR LOCAL FAST_FORWARD READ_ONLY
               FOR
               SELECT LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID,
                      (LOTxLOCxID.Qty + ISNULL(MoveInLLL.Qty,0) ) - ( LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked + ISNULL(MoveOutLLL.Qty,0) )
                      AS Available
               FROM   LOTxLOCxID WITH (NOLOCK)
               LEFT OUTER JOIN (SELECT LOT, FromLOC, ID, SUM(Qty) As Qty
                      FROM REPLENISHMENT (NOLOCK )
                      WHERE Confirmed in ('W','S')
                      AND   Toloc <> 'PICK'
                      AND   StorerKey = @c_StorerKey
                      AND   SKU       = @c_SKU
                      AND   FromLOC   = @c_ToLOC
               GROUP BY LOT, FromLOC, ID) AS MoveOutLLL
                           ON MoveOutLLL.LOT = LOTxLOCxID.LOT AND
                              MoveOutLLL.FromLOC = LOTxLOCxID.LOC AND
                              MoveOutLLL.ID = LOTxLOCxID.ID
               LEFT OUTER JOIN (SELECT LOT, ToLOC, ID, SUM(Qty) As Qty
                      FROM REPLENISHMENT (NOLOCK )
                      WHERE Confirmed in ('W','S')
                      AND   Toloc <> 'PICK'
                      AND   StorerKey = @c_StorerKey
                      AND   SKU       = @c_SKU
                      AND   ToLOC     = @c_ToLOC
                      GROUP BY LOT, ToLOC, ID) AS MoveInLLL
                           ON MoveInLLL.LOT = LOTxLOCxID.LOT AND
                              MoveInLLL.ToLOC = LOTxLOCxID.LOC AND
                              MoveInLLL.ID = LOTxLOCxID.ID
               JOIN   LOTATTRIBUTE LA WITH (NOLOCK) ON LA.LOT = LOTxLOCxID.LOT
               WHERE  LOTxLOCxID.StorerKey = @c_StorerKey
      AND    LOTxLOCxID.SKU       = @c_SKU
               AND    LOTxLOCxID.LOC       = @c_ToLOC
               AND   (LOTxLOCxID.Qty + ISNULL(MoveInLLL.Qty,0) ) - ( LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked + ISNULL(MoveOutLLL.Qty,0) ) > 0
   */
               SELECT @cExecStatement =
               'DECLARE CurOutstandingReplen CURSOR FAST_FORWARD READ_ONLY  FOR ' +
               'SELECT LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID,  ' +
               '(LOTxLOCxID.Qty + ISNULL(MoveInLLL.Qty,0) ) - ( LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked + ISNULL(MoveOutLLL.Qty,0) ) AS Available ' +
               'FROM   LOTxLOCxID WITH (NOLOCK) ' +
               'LEFT OUTER JOIN (SELECT LOT, FromLOC, ID, SUM(Qty) As Qty ' +
               '       FROM REPLENISHMENT (NOLOCK ) ' +
               '       WHERE Confirmed in (''W'',''S'') ' +
               '       AND   Toloc <> ''PICK'' ' +
               '       AND   StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
               '       AND   SKU       = N''' + RTRIM(@c_SKU) + ''' ' +
               '       AND   FromLOC   = N''' + RTRIM(@c_TOLOC) + ''' ' +
               '       GROUP BY LOT, FromLOC, ID) AS MoveOutLLL ' +
               '            ON MoveOutLLL.LOT = LOTxLOCxID.LOT AND' +
               '               MoveOutLLL.FromLOC = LOTxLOCxID.LOC AND' +
               '               MoveOutLLL.ID = LOTxLOCxID.ID ' +
               'LEFT OUTER JOIN (SELECT LOT, ToLOC, ID, SUM(Qty) As Qty ' +
               '       FROM REPLENISHMENT (NOLOCK ) ' +
               '       WHERE Confirmed in (''W'',''S'') ' +
               '       AND   Toloc <> ''PICK'' ' +
               '       AND   StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
               '       AND   SKU       = N''' + RTRIM(@c_SKu) + ''' ' +
               '       AND  ToLOC     = N''' + RTRIM(@c_toloc) + ''' ' +
               '       GROUP BY LOT, ToLOC, ID) AS MoveInLLL ' +
               '            ON MoveInLLL.LOT = LOTxLOCxID.LOT AND ' +
               '               MoveInLLL.ToLOC = LOTxLOCxID.LOC AND ' +
               '               MoveInLLL.ID = LOTxLOCxID.ID ' +
               'JOIN   LOTATTRIBUTE LA WITH (NOLOCK) ON LA.LOT = LOTxLOCxID.LOT  ' +
               'WHERE  LOTxLOCxID.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
               'AND    LOTxLOCxID.SKU       = N''' + RTRIM(@c_SKu) + ''' ' +
               'AND    LOTxLOCxID.LOC       = N''' + RTRIM(@c_toloc) + ''' ' +
               'AND   (LOTxLOCxID.Qty + ISNULL(MoveInLLL.Qty,0) ) - ( LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked + ISNULL(MoveOutLLL.Qty,0) ) > 0 '

               --IF RTRIM(@c_Lottable01) IS NOT NULL AND RTRIM(@c_Lottable01) <> ''
               --BEGIN
               --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
               --      ' AND LA.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
               --END
               --IF RTRIM(@c_Lottable02) IS NOT NULL AND RTRIM(@c_Lottable02) <> ''
               --BEGIN
               --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
               --      ' AND LA.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '
               --END
               --IF RTRIM(@c_Lottable03) IS NOT NULL AND RTRIM(@c_Lottable03) <> ''
               --BEGIN
               --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
               --      ' AND LA.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '
               --END

               IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LA.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
               
               IF RTRIM(ISNULL(@c_Lottable02,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LA.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '

               IF RTRIM(ISNULL(@c_Lottable03,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LA.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '

               IF RTRIM(ISNULL(@c_Lottable06,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LA.Lottable06 = N''' + RTRIM(@c_Lottable06) + ''' '

               IF RTRIM(ISNULL(@c_Lottable07,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LA.Lottable07 = N''' + RTRIM(@c_Lottable07) + ''' '

               IF RTRIM(ISNULL(@c_Lottable08,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LA.Lottable08 = N''' + RTRIM(@c_Lottable08) + ''' '

               IF RTRIM(ISNULL(@c_Lottable09,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LA.Lottable09 = N''' + RTRIM(@c_Lottable09) + ''' '

               IF RTRIM(ISNULL(@c_Lottable10,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LA.Lottable10 = N''' + RTRIM(@c_Lottable10) + ''' '

               IF RTRIM(ISNULL(@c_Lottable11,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LA.Lottable11 = N''' + RTRIM(@c_Lottable11) + ''' '

               IF RTRIM(ISNULL(@c_Lottable12,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LA.Lottable12 = N''' + RTRIM(@c_Lottable12) + ''' '


               IF RTRIM(@c_Lottable02Label) IS NOT NULL AND RTRIM(@c_Lottable02Label) <> ''
               BEGIN
                  SELECT @cExecStatement = RTRIM(@cExecStatement) +
                     ' ORDER By LA.Lottable02 DESC, LA.Lottable05 '
               END
               ELSE
               BEGIN
                  SELECT @cExecStatement = RTRIM(@cExecStatement) +
                     ' ORDER By LA.Lottable05 '
               END

               EXEC sp_executesql @cExecStatement

               OPEN CurOutstandingReplen

               FETCH NEXT FROM CurOutstandingReplen INTO @c_LOT, @c_ToLOC, @c_ID, @nQtyRepleInProgress

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF  @n_QtyLeftToFulfill = 0
                     BREAK

                  if @b_debug = 1
                  begin
                     select @c_LOT '@c_LOT', @nQtyRepleInProgress '@nQtyRepleInProgress', @n_QtyLeftToFulfill '@n_QtyLeftToFulfill',
                     @n_QtyToTake '@n_QtyToTake'
                  end

                  IF @n_QtyLeftToFulfill > @nQtyRepleInProgress
                  BEGIN
                     SET @n_QtyToTake        = @nQtyRepleInProgress
                     SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @nQtyRepleInProgress
                  END
                  ELSE
                  BEGIN
                     DELETE FROM @TempReplen
                     WHERE PickSeq = @n_PickSeq

                     SET @n_QtyToTake        = @n_QtyLeftToFulfill
                     SET @n_QtyLeftToFulfill = 0
                  END

                  EXECUTE nspg_GetKey
                      @keyname       = 'REPLENISHKEY', --Leong01
                      @fieldlength   = 10,
                      @keystring     = @c_ReplenishmentKey  OUTPUT,
                      @b_success     = @b_success   OUTPUT,
                      @n_err         = @n_err       OUTPUT,
                      @c_errmsg      = @c_errmsg    OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                     GOTO RETURN_SP
                  END
                  ELSE
                  BEGIN
                     SELECT @c_DynPickLOC = LOC
                     FROM   @TempDynamicLoc
                     WHERE  PutawayZone = @c_PutawayZone
                     AND    SKU = @c_SKU

                     IF ISNULL(RTRIM(@c_DynPickLOC), '') = ''
                     BEGIN
                        SELECT @c_DynPickLOC = MAX(LOC) FROM @TempDynamicLoc

                        SELECT @c_DynPickLOC = MIN(LOC.LOC)
                        FROM   LOC (NOLOCK)
                        WHERE  LOC.LocationType = 'DYNAMICPK'
                        AND    LOC.LocationFlag <> 'HOLD'
                        AND    LOC.Facility = @c_Facility
                        AND    LOC.PutawayZone = @c_PutawayZone
                        AND    LOC.Loc > @c_DynPickLOC

                     END

                     IF @b_debug = 1
                     BEGIN
                        SELECT '@TempDynamicLoc', * FROM @TempDynamicLoc
                        SELECT '@c_PutawayZone', @c_PutawayZone
                        SELECT '@c_ToLoc', @c_ToLoc
                        SELECT '@c_Facility', @c_Facility
                     END

                     IF RTRIM(@c_DynPickLOC) IS NULL
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = '', @n_err = 63512   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Dynamic Pick Location Not Found or FULL ! (ispWaveDynamicPickUCCAlloc)'
                        CLOSE PickCursor
                        DEALLOCATE PickCursor
                        GOTO RETURN_SP
                     END
                     ELSE
                     BEGIN
                        UPDATE @TempDynamicLoc
                        SET LOC = @c_DynPickLOC
                        WHERE SKU = @c_SKU AND PutawayZone = @c_PutawayZone

                     END
                     If @b_debug = 1
                        SELECT 'INSERT REPLEN -', 'PP to DP 2', @c_ToLOC '@c_ToLOC'

                     INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                         StorerKey,      SKU,       FromLOC,      ToLOC,
                         Lot,            Id,        Qty,          UOM,
                         PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                         RefNo,          Confirmed, ReplenNo,     Remark )
                     VALUES (
                         @c_ReplenishmentKey,       @c_P2D_ReplenGrp,
                         @c_StorerKey,   @c_SKU,    @c_ToLOC,        @c_DynPickLOC,
                         @c_LOT,         @c_ID,     @n_QtyToTake,    @c_UOM,
                         @c_Packkey,     '1',       0,               0,
                         '',             'W',       @c_WaveKey,      'PP to DP')

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63513   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
                        CLOSE PickCursor
                        DEALLOCATE PickCursor
                        GOTO RETURN_SP

                     END
                  END

                  FETCH NEXT FROM CurOutstandingReplen INTO @c_LOT, @c_ToLOC, @c_ID, @nQtyRepleInProgress
               END -- @@FETCH_STATUS <> -1
               CLOSE CurOutstandingReplen
               DEALLOCATE CurOutstandingReplen

               IF @n_QtyLeftToFulfill = 0
                  GOTO READ_NEXT_REPLEN

               IF @b_debug = 1
               begin
                  select @c_SKU '@c_SKU', @nQtyRepleInProgress '@nQtyRepleInProgress', @n_QtyLeftToFulfill '@n_QtyLeftToFulfill'
               end

               SELECT @cExecStatement =
                  'DECLARE PickCursor CURSOR READ_ONLY FOR  ' +
                  'SELECT LOTxLOCxID.Lot, LOTxLOCxID.Loc, LOTxLOCxID.ID, ' +
                  '(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - ISNULL(RP.Qty,0) AS Qty, LotAttribute.Lottable02 ' +
                  'FROM LOTxLOCxID (NOLOCK) ' +
                  'JOIN LotAttribute (NOLOCK) ON (LotAttribute.LOT = LOTxLOCxID.LOT) ' +
                  'JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = LOTxLOCxID.StorerKey AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.Loc) ' +
                  'JOIN LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC) ' +
                  'JOIN LOT (NOLOCK) ON (LOT.LOT = LOTxLOCxID.LOT) ' +
                  'JOIN ID  (NOLOCK) ON (ID.ID = LOTxLOCxID.ID) ' +
                  'LEFT OUTER JOIN (SELECT LOT, FromLOC, ID, SUM(QTY) AS Qty ' +
                  '                 FROM REPLENISHMENT (NOLOCK) ' +
                  '                 WHERE Confirmed <> ''Y'' ' +
                  '                 AND   ToLOC <> ''PICK'' ' +  -- 20080730 Need to exclude FCP bcos FCP already allocated
                  '                 AND   StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
                  '                 AND   SKU = N''' + RTRIM(@c_SKU) + ''' ' +
                  '                 GROUP BY LOT, FromLOC, ID) AS RP ' +
                  '                 ON (RP.LOT = LOTxLOCxID.LOT AND RP.FromLOC = LOTxLOCxID.LOC AND RP.ID = LOTxLOCxID.ID) ' +
                  'WHERE LOTxLOCxID.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
                  'AND   LOTxLOCxID.SKU = N''' + RTRIM(@c_SKU) + ''' ' +
                  'AND   SKUxLOC.LocationType NOT IN (''CASE'', ''PICK'') ' +
                  'AND   LOC.LocationType NOT IN (''DYNAMICPK'') ' +
                  'AND   LOC.LocationFlag <> ''HOLD'' ' +
                  'AND   LOC.Facility =N'''+ RTRIM(@c_Facility) + ''' ' +
                  'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
                  'AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - ISNULL(RP.Qty,0) > 0 '

               --IF RTRIM(@c_Lottable01) IS NOT NULL AND RTRIM(@c_Lottable01) <> ''
               --BEGIN
               --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
               --      ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
               --END
               --IF RTRIM(@c_Lottable02) IS NOT NULL AND RTRIM(@c_Lottable02) <> ''
               --BEGIN
               --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
               --      ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '
               --END
               --IF RTRIM(@c_Lottable03) IS NOT NULL AND RTRIM(@c_Lottable03) <> ''
               --BEGIN
               --   SELECT @cExecStatement = RTRIM(@cExecStatement) +
               --         ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '
               --END
               
               IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
               
               IF RTRIM(ISNULL(@c_Lottable02,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '

               IF RTRIM(ISNULL(@c_Lottable03,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '

               IF RTRIM(ISNULL(@c_Lottable06,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable06 = N''' + RTRIM(@c_Lottable06) + ''' '

               IF RTRIM(ISNULL(@c_Lottable07,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable07 = N''' + RTRIM(@c_Lottable07) + ''' '

               IF RTRIM(ISNULL(@c_Lottable08,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable08 = N''' + RTRIM(@c_Lottable08) + ''' '

               IF RTRIM(ISNULL(@c_Lottable09,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable09 = N''' + RTRIM(@c_Lottable09) + ''' '

               IF RTRIM(ISNULL(@c_Lottable10,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable10 = N''' + RTRIM(@c_Lottable10) + ''' '

               IF RTRIM(ISNULL(@c_Lottable11,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable11 = N''' + RTRIM(@c_Lottable11) + ''' '

               IF RTRIM(ISNULL(@c_Lottable12,'')) <> ''
                  SELECT @cExecStatement = RTRIM(@cExecStatement) + ' AND LotAttribute.Lottable12 = N''' + RTRIM(@c_Lottable12) + ''' '

               IF RTRIM(@c_Lottable02Label) IS NOT NULL AND RTRIM(@c_Lottable02Label) <> ''
               BEGIN
                  SELECT @cExecStatement = RTRIM(@cExecStatement) +
                     ' ORDER By LotAttribute.Lottable02, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc '
               END
               ELSE
               BEGIN
                  SELECT @cExecStatement = RTRIM(@cExecStatement) +
                     ' ORDER By LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc '
               END

               IF @b_debug = 1
               BEGIN
                  Print @cExecStatement
               END

               EXEC sp_executesql @cExecStatement -- DD

               OPEN PickCursor

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err = 16905
               BEGIN
                  CLOSE PickCursor
                  DEALLOCATE PickCursor
               END
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
               END
               ELSE
               BEGIN
                  SELECT @n_CursorOpen = 1
               END

               FETCH NEXT FROM PickCursor INTO
                  @c_Lot, @c_Loc, @c_ID, @n_LLI_Qty, @c_Sys_Lottable02

               WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
               BEGIN
                  IF @n_LLI_Qty > 0 AND @n_QtyLeftToFulfill > 0
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT @n_QtyLeftToFulfill '@n_QtyLeftToFulfill'
                     END

                     -- Get those unallocated UCC and Qty = available LLI Qty
                     DECLARE Cur_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT UCCNo, Qty
                     FROM UCC with (NOLOCK, INDEX(IDX_UCC_LOTxLOCxID))
                     WHERE LOT = @c_Lot
                        AND LOC = @c_Loc
                        AND ID = @c_ID
                        AND StorerKey = @c_StorerKey
                        AND Status = '1'
                        AND Qty <= @n_LLI_Qty

                     OPEN Cur_UCC
                     FETCH NEXT FROM Cur_UCC INTO @c_UCCNo, @n_UCC_Qty
                     WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
                     BEGIN
                        -- Lock UCC
                        UPDATE UCC
                           SET Status = '3', WaveKey = @c_WaveKey
                        WHERE UCCNo = @c_UCCNo

                        EXECUTE nspg_GetKey
                            @keyname       = 'REPLENISHKEY', --Leong01
                            @fieldlength   = 10,
                             @keystring     = @c_ReplenishmentKey  OUTPUT,
                            @b_success     = @b_success   OUTPUT,
                            @n_err         = @n_err       OUTPUT,
                            @c_errmsg      = @c_errmsg    OUTPUT

                        IF NOT @b_success = 1
                        BEGIN
                           SELECT @n_continue = 3
                        END
                        ELSE
                        BEGIN
                           IF @n_continue=1 OR @n_continue=2
                           BEGIN
                              IF @n_UCC_Qty < @n_QtyLeftToFulfill
                                  SELECT @n_QtyInPickLOC = @n_UCC_Qty
                              ELSE
                                  SELECT @n_QtyInPickLOC = @n_QtyLeftToFulfill

                                 If @b_debug = 1
                                    SELECT 'INSERT REPLEN -', 'BULK to PP', @c_ToLOC '@c_ToLOC'

                      INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                                   StorerKey,      SKU,       FromLOC,      ToLOC,
                                     Lot,            Id,        Qty,          UOM,
                                     PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                                     RefNo,          Confirmed, ReplenNo,     Remark)
                                 VALUES (
                                     @c_ReplenishmentKey,       @c_B2P_ReplenGrp,  -- (james02)
                                     @c_StorerKey,   @c_SKU,    @c_LOC,       @c_ToLOC,
                                     @c_LOT,         @c_ID,     @n_UCC_Qty,   @c_UOM,
                                     @c_Packkey,     '1',       0,            @n_QtyInPickLOC,
                                     @c_UCCNo,       'W',       @c_WaveKey,   'BULK to PP')

                                 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                                 IF @n_err <> 0
                                 BEGIN
                                    SELECT @n_continue = 3
                                    SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63517   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
                                    GOTO RETURN_SP
                                 END
                                 ELSE
                                 BEGIN
                                    IF @n_QtyInPickLOC > 0
                                    BEGIN
                                       SET @c_PickLOC = @c_ToLOC

                                       EXECUTE nspg_GetKey
                                           @keyname       = 'REPLENISHKEY', --Leong01
                                           @fieldlength   = 10,
                                           @keystring     = @c_ReplenishmentKey  OUTPUT,
                                           @b_success     = @b_success   OUTPUT,
                                           @n_err         = @n_err       OUTPUT,
                                           @c_errmsg      = @c_errmsg    OUTPUT

                                       SELECT @c_ToLOC = LOC
                                       FROM   @TempDynamicLoc
                                       WHERE  PutawayZone = @c_PutawayZone
                                       AND    SKU = @c_SKU

                                       IF ISNULL(RTRIM(@c_ToLOC), '') = ''
                                       BEGIN
                                          SELECT @c_ToLoc = MAX(LOC) FROM @TempDynamicLoc

                                         SELECT @c_ToLOC = MIN(LOC.LOC)
                                          FROM   LOC (NOLOCK)
                                          WHERE  LOC.LocationType = 'DYNAMICPK'
                                          AND    LOC.LocationFlag <> 'HOLD'
                                          AND    LOC.Facility = @c_Facility
                                          AND    LOC.PutawayZone = @c_PutawayZone
                                          AND    LOC.Loc > @c_ToLoc
                                       END   -- ISNULL(RTRIM(@c_ToLOC), '') = ''
                                       IF RTRIM(@c_ToLOC) IS NULL
                                       BEGIN
                                          SELECT @n_continue = 3
                                          SELECT @c_errmsg = '', @n_err = 63512   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                                                +': Dynamic Pick Location Not Found or FULL ! (ispWaveDynamicPickUCCAlloc)'
                                          CLOSE PickCursor
                                          DEALLOCATE PickCursor
                                          GOTO RETURN_SP
                                       END
                                       ELSE
                                       BEGIN
                                          UPDATE @TempDynamicLoc
                                          SET LOC = @c_ToLOC
                                          WHERE SKU = @c_SKU AND PutawayZone = @c_PutawayZone

                                       END

                                       IF @n_continue=1 OR @n_continue=2
                                       BEGIN
                                          If @b_debug = 1
                                             SELECT 'INSERT REPLEN -', 'PP to DP 3', @c_ToLOC '@c_ToLOC'
                                          -- Replen# = Wave key
                                          -- RefNo = UCC No
                                          INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                                              StorerKey,      SKU,       FromLOC,      ToLOC,
                                              Lot,            Id,        Qty,          UOM,
                                              PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                                              RefNo,          Confirmed, ReplenNo,     Remark )
                                          VALUES (
                                             @c_ReplenishmentKey,       @c_P2D_ReplenGrp,
                                              @c_StorerKey,   @c_SKU,    @c_PickLOC,      @c_ToLOC,
                                              @c_LOT,         @c_ID,     @n_QtyInPickLOC, @c_UOM,
                                              @c_Packkey,     '1',       0,               0,
                                              '',             'W',       @c_WaveKey,      'PP to DP')

                                          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                                          IF @n_err <> 0
                                          BEGIN
                                             SELECT @n_continue = 3
                                             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63513   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWaveDynamicPickUCCAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(RTRIM(@c_errmsg)) + ' ) '
                                             CLOSE PickCursor
                                             DEALLOCATE PickCursor
                                             GOTO RETURN_SP

                                          END
                                       END   -- @n_continue=1 OR @n_continue=2
                                    END   -- IF @n_QtyInPickLOC > 0
                                 END
                           END
                        END

                        IF @n_continue=1 OR @n_continue=2
                        BEGIN
                           IF @n_UCC_Qty >= @n_QtyLeftToFulfill
                           BEGIN
                              DELETE FROM @TempReplen
                              WHERE PickSeq = @n_PickSeq

                              SELECT @n_QtyLeftToFulfill = 0
                              BREAK
                           END -- @n_UCC_Qty = @n_QtyLeftToFulfill
                           ELSE IF @n_UCC_Qty < @n_QtyLeftToFulfill
                           BEGIN
                              UPDATE @TempReplen
                                 SET Qty = Qty - @n_UCC_Qty
                              WHERE PickSeq = @n_PickSeq

                              SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_UCC_Qty
                              SELECT @n_LLI_Qty = @n_LLI_Qty - @n_UCC_Qty

                           END -- IF @n_UCC_Qty < @n_QtyLeftToFulfill
                        END   -- @n_continue=1 OR @n_continue=2
                        FETCH NEXT FROM Cur_UCC INTO @c_UCCNo, @n_UCC_Qty
                     END
                     CLOSE Cur_UCC
                     DEALLOCATE Cur_UCC
                     END -- @n_UCC_Qty <= @n_QtyLeftToFulfill
                     ELSE
                     BEGIN
                        BREAK
                     END
                  FETCH NEXT FROM PickCursor INTO
                     @c_Lot, @c_Loc, @c_ID, @n_LLI_Qty, @c_Sys_Lottable02
               END -- while  cursor
               CLOSE PickCursor
               DEALLOCATE PickCursor
            END
         END -- IF EXISTS(SELECT 1 FROM @TempReplen)
      END -- Select OpenQty > 0
   END -- @n_continue=1 OR @n_continue=2
   IF @b_debug = 1
   BEGIN
      PRint ''
      Print 'End Replenisment from Bulk to Pick Loc...'
   END
   -- Last Replenishment

   -- clean up waveorderln table
   DELETE WaveOrderLn WHERE WaveOrderLn.WaveKey = @c_WaveKey

   -- SOS134253 Start
   -- Reassign ToLOC (Start)
   /*
      DECLARE @cTempLoc NVARCHAR(10)
      DECLARE @TempDynamicRPL TABLE
            (SKU          NVARCHAR(20),
             LOC          NVARCHAR(10))

      INSERT INTO @TempDynamicRPL (SKU)
      SELECT DISTINCT SKU FROM REPLENISHMENT WITH (NOLOCK)
      WHERE REPLENNO = @c_WaveKey
         AND REMARK IN ('PP to DP', 'BULK to DP')

      SET @cTempLoc = ''
      SELECT @cTempLoc = MIN( LOC)
      FROM LOC WITH (NOLOCK)
      WHERE LocationType = 'DYNAMICPK'
         AND Facility = @c_Facility
         AND LOC >= @c_DPLoc_Start
         AND LOC > @cTempLOC

      DECLARE CUR_SwapLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SKU FROM @TempDynamicRPL ORDER BY SKU
      OPEN CUR_SwapLOC
      FETCH NEXT FROM CUR_SwapLOC INTO @c_SKU
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE @TempDynamicRPL SET LOC = @cTempLoc WHERE SKU = @c_SKU

         SELECT @cTempLoc = MIN( LOC)
         FROM LOC WITH (NOLOCK)
         WHERE LocationType = 'DYNAMICPK'
            AND Facility = @c_Facility
            AND LOC >= CASE WHEN @c_DPLoc_Start = '' THEN LOC ELSE @c_DPLoc_Start END  -- SOS124584 If already reach MAX DP LOC then can forget about the start LOC (james04)
            AND LOC > @cTempLOC
         IF @cTempLoc IS NULL
         BEGIN
            SET @cTempLoc = ''
            SELECT @cTempLoc = MIN( LOC)
            FROM LOC WITH (NOLOCK)
            WHERE LocationType = 'DYNAMICPK'
               AND Facility = @c_Facility
   --            AND LOC >= @c_DPLoc_Start  -- SOS124584 If already reach MAX DP LOC then go back to first DP LOC (james04)
               AND LOC > @cTempLOC

            SET @c_DPLoc_Start = '' -- SOS124584 If already reach MAX DP LOC then can forget about the start LOC (james04)
         END
         FETCH NEXT FROM CUR_SwapLOC INTO @c_SKU
      END
      CLOSE CUR_SwapLOC
      DEALLOCATE CUR_SwapLOC

      UPDATE RPL WITH (ROWLOCK) SET
        TOLOC = LOC
      FROM REPLENISHMENT RPL
      JOIN @TempDynamicRPL TDL ON RPL.SKU = TDL.SKU
      WHERE RPL.ReplenNo = @c_WaveKey
         AND REMARK IN ('PP to DP', 'BULK to DP')
   */
      DECLARE @cTempLoc NVARCHAR(10),
              @nIdx     int,
              @nTotSKU  int

      DECLARE @TempDynamicRPL TABLE
            (SeqNo        int IDENTITY(1,1),
             SKU          NVARCHAR(20),
             LOC          NVARCHAR(10))

      INSERT INTO @TempDynamicRPL (SKU, LOC)
      SELECT DISTINCT SKU, ''
      FROM   REPLENISHMENT WITH (NOLOCK)
      WHERE  REPLENNO = @c_WaveKey
         AND REMARK IN ('PP to DP', 'BULK to DP')
      ORDER BY SKU

      SELECT @nTotSKU = COUNT(*) FROM @TempDynamicRPL
      SET    @nIdx    = 0

      DECLARE CUR_LOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LOC
      FROM LOC WITH (NOLOCK)
      WHERE LocationType = 'DYNAMICPK'
         AND Facility = @c_Facility
         AND LOC >= @c_DPLoc_Start
      ORDER BY LOC

      OPEN CUR_LOC

      FETCH NEXT FROM CUR_LOC INTO @cTempLoc

      WHILE 1=1
      BEGIN
         IF @nTotSKU = @nIdx
            BREAK

         SET @nIdx = @nIdx + 1

         UPDATE @TempDynamicRPL
                SET LOC = @cTempLoc
         WHERE  SeqNo = @nIdx

         FETCH NEXT FROM CUR_LOC INTO @cTempLoc
         IF @@FETCH_STATUS = -1 AND @nTotSKU > @nIdx
         BEGIN
            CLOSE CUR_LOC
            DEALLOCATE CUR_LOC

            DECLARE CUR_LOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOC
            FROM LOC WITH (NOLOCK)
            WHERE LocationType = 'DYNAMICPK'
               AND Facility = @c_Facility
               AND LOC >= ''
            ORDER BY LOC

            OPEN CUR_LOC
         END
   --      ELSE
   --      BEGIN
   --         BREAK
   --      END
      END
      CLOSE CUR_LOC
      DEALLOCATE CUR_LOC

      UPDATE RPL WITH (ROWLOCK) SET
        TOLOC = LOC
      FROM REPLENISHMENT RPL
      JOIN @TempDynamicRPL TDL ON RPL.SKU = TDL.SKU
      WHERE RPL.ReplenNo = @c_WaveKey
         AND REMARK IN ('PP to DP', 'BULK to DP')
   -- Reassign toLOC (End)
   -- SOS134253 End
   -- SOS140790 - Trigger CMSLOG
   DECLARE @c_Auth_LPALLOCCMS      NVARCHAR(1)

   DECLARE CUR_CMSLOG_LOADKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT LOADPLANDETAIL.LoadKey, ORDERS.StorerKey
   FROM LOADPLANDETAIL WITH (NOLOCK)
   JOIN WAVEDETAIL WITH (NOLOCK) ON (WAVEDETAIL.OrderKey = LOADPLANDETAIL.OrderKey)
   JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = LOADPLANDETAIL.OrderKey)
   WHERE WAVEDETAIL.WaveKey = @c_WaveKey

   OPEN  CUR_CMSLOG_LOADKEY

   FETCH NEXT FROM CUR_CMSLOG_LOADKEY INTO @c_LoadKey, @c_StorerKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_Auth_LPALLOCCMS = 0
      SELECT @b_success = 0

      EXEC nspGetRight
            NULL,           -- Facility
            @c_StorerKey,   -- Storer
            NULL,           -- No Sku in this Case
            'LPALLOCCMS',   -- ConfigKey
            @b_success           OUTPUT,
            @c_auth_LPALLOCCMS   OUTPUT,
            @n_err               OUTPUT,
            @c_errmsg            OUTPUT

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'ispWaveDynamicPickUCCAlloc' + ISNULL(RTRIM(@c_errmsg),'')
         GOTO RETURN_SP
      END

      IF @b_success = 1 AND @c_auth_LPALLOCCMS = '1'
      BEGIN
         IF ISNULL(RTRIM(@c_LoadKey),'') <> ''
         BEGIN
            EXEC ispGenCMSLOG 'LPALLOCCMS', @c_LoadKey, 'L', @c_StorerKey, 'DP'
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(@n_err,0)), @n_err=68001
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Insert into CMSLOG Failed (ispWaveDynamicPickUCCAlloc) ( SQLSvr MESSAGE='
                                + ISNULL(dbo.fnc_LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               GOTO RETURN_SP
            END
         END -- IF ISNULL(RTRIM(@c_LoadKey),'') <> ''
      END -- if @b_success = 1 AND @c_auth_LPALLOCCMS = '1'

      FETCH NEXT FROM CUR_CMSLOG_LOADKEY INTO @c_LoadKey, @c_StorerKey
   END
   CLOSE CUR_CMSLOG_LOADKEY
   DEALLOCATE CUR_CMSLOG_LOADKEY
   -- SOS140790 -End
   RETURN_SP:

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
      execute nsp_logerror @n_err, @c_errmsg, 'ispWaveDynamicPickUCCAlloc'
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

GO
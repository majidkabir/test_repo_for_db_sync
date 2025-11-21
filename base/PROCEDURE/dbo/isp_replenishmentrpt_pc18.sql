SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ReplenishmentRpt_PC18                             */
/* Creation Date:  14-OCT-2013                                             */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#318396 - FBR - Replenishment (No Mix Batch)                */
/*        : modify from nsp_ReplenishmentRpt_PC17                          */
/*                                                                         */
/* Called By: Replenishment Report                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 27-Oct-2014  Audrey  1.1   SOS324118 - Bug fixed                 (ang01)*/
/* 15-Sep-2015  NJOW01  1.2   352424 - Change sorting by lot4 & 5          */
/* 12-Jul-2017  NJOW02  1.3   WMS-2324 Add pendingmovein,qtyreplen checking*/
/*                            ,replenishmentgroup & refno for working with */
/*                            release task                                 */
/* 22-Feb-2018  NJOW03  1.4   WMS-4043 Add stock filtering.                */
/* 05-MAR-2018  Wan01   1.5   WM - Add Functype                            */
/* 18-JAN-2021  Wan02   1.6   Follow Parameters to follow Datawindow Seq   */
/* 02-JUN-2023  NJOW04  1.7   WMS-22642 add nomixlottable04-15 and exclude */
/*                            replenish partial allocated pallet           */
/* 02-JUN-2023  NJOW04  1.7   DEVOPS Combine Script                        */
/***************************************************************************/

CREATE PROC [dbo].[isp_ReplenishmentRpt_PC18]
               @c_zone01           NVARCHAR(10)
,              @c_zone02           NVARCHAR(10)
,              @c_zone03           NVARCHAR(10)
,              @c_zone04           NVARCHAR(10)
,              @c_zone05           NVARCHAR(10)
,              @c_zone06           NVARCHAR(10)
,              @c_zone07           NVARCHAR(10)
,              @c_zone08           NVARCHAR(10)
,              @c_zone09           NVARCHAR(10)
,              @c_zone10           NVARCHAR(10)
,              @c_zone11           NVARCHAR(10)
,              @c_zone12           NVARCHAR(10)
,              @c_storerkey        NVARCHAR(15)
,              @c_ReplGrp          NVARCHAR(30)       --PickZone
,              @c_Functype         NCHAR(1) = ''      --(Wan01)   --Wan02
,              @c_backendjob       NVARCHAR(10) = 'N' --NJOW02    --Wan02
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE        @n_continue int          /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   DECLARE @b_debug           INT
         , @b_Success         INT
         , @n_Err             INT
         , @c_ErrMsg          NVARCHAR(255)
         , @c_SQL             NVARCHAR(MAX)=''
         , @c_SQLParm         NVARCHAR(MAX)=''
         , @c_Packkey         NVARCHAR(10)
         , @c_UOM             NVARCHAR(10)
         , @c_ToLocationType  NVARCHAR(10)
         , @n_CaseCnt         FLOAT
         , @n_Pallet          FLOAT
         , @c_ReplenishmentGroup NVARCHAR(10)  --NJOW02

   DECLARE @c_priority        NVARCHAR(5)
         , @c_ReplLottable01  NVARCHAR(18) --NJOW03
         , @c_ReplLottable02  NVARCHAR(18)
         , @c_ReplLottable03  NVARCHAR(18) --NJOW03
         , @d_ReplLottable04  DATETIME     --NJOW04
         , @d_ReplLottable05  DATETIME     --NJOW04
         , @c_ReplLottable06  NVARCHAR(30) --NJOW04
         , @c_ReplLottable07  NVARCHAR(30) --NJOW04
         , @c_ReplLottable08  NVARCHAR(30) --NJOW04
         , @c_ReplLottable09  NVARCHAR(30) --NJOW04
         , @c_ReplLottable10  NVARCHAR(30) --NJOW04
         , @c_ReplLottable11  NVARCHAR(30) --NJOW04
         , @c_ReplLottable12  NVARCHAR(30) --NJOW04
         , @d_ReplLottable13  DATETIME     --NJOW04
         , @d_ReplLottable14  DATETIME     --NJOW04
         , @d_ReplLottable15  DATETIME     --NJOW04
         , @c_NoReplenAlloPlt NVARCHAR(10)='N' --NJOW04

   SET @n_continue=1
   SET @b_debug = 0

   IF @c_zone12 = '1'
   BEGIN
      SET @b_debug = CAST( @c_zone12 AS int)
      SET @c_zone12 = ''
   END

   --(Wan01) - START
   IF RTRIM(@c_ReplGrp) = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END

   IF @c_FuncType IN ( 'P' )
   BEGIN
      GOTO QUIT_SP
   END
   --(Wan01) - END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
   	  --NJOW04
   	  CREATE TABLE #REPLENISHMENT (Storerkey      NVARCHAR(15),
   	                               Sku            NVARCHAR(20),
   	                               FromLoc        NVARCHAR(10),
   	                               ToLoc          NVARCHAR(10),
   	                               Lot            NVARCHAR(10),
   	                               ID             NVARCHAR(18),
   	                               Qty            INT,
   	                               QtyMoved       INT,
   	                               QtyInPickLoc   INT,
   	                               Priority       NVARCHAR(5),
   	                               UOM            NVARCHAR(10),
   	                               Packkey        NVARCHAR(10),
   	                               ReplLottable01 NVARCHAR(18) NULL,
                                   ReplLottable02 NVARCHAR(18) NULL,
                                   ReplLottable03 NVARCHAR(18) NULL,
                                   ReplLottable04 DATETIME     NULL,
                                   ReplLottable05 DATETIME     NULL,
                                   ReplLottable06 NVARCHAR(30) NULL,
                                   ReplLottable07 NVARCHAR(30) NULL,
                                   ReplLottable08 NVARCHAR(30) NULL,
                                   ReplLottable09 NVARCHAR(30) NULL,
                                   ReplLottable10 NVARCHAR(30) NULL,
                                   ReplLottable11 NVARCHAR(30) NULL,
                                   ReplLottable12 NVARCHAR(30) NULL,
                                   ReplLottable13 DATETIME     NULL,
                                   ReplLottable14 DATETIME     NULL,
                                   ReplLottable15 DATETIME     NULL)
   	  /*
      SELECT StorerKey
            ,SKU
            ,FromLOC      = LOC
            ,ToLOC        = LOC
            ,Lot
            ,Id
            ,Qty
            ,QtyMoved     = Qty
            ,QtyInPickLOC = Qty
            ,Priority     = @c_priority
            ,UOM          = Lot
            ,PackKey      = Lot
            ,ReplLottable01  = @c_ReplLottable01  --NJOW03
            ,ReplLottable02  = @c_ReplLottable02
            ,ReplLottable03  = @c_ReplLottable03  --NJOW03
            ,ReplLottable04  = @d_ReplLottable04  --NJOW04
            ,ReplLottable05  = @d_ReplLottable05  --NJOW04
            ,ReplLottable06  = @c_ReplLottable06  --NJOW04
            ,ReplLottable07  = @c_ReplLottable07  --NJOW04
            ,ReplLottable08  = @c_ReplLottable08  --NJOW04
            ,ReplLottable09  = @c_ReplLottable09  --NJOW04
            ,ReplLottable10  = @c_ReplLottable10  --NJOW04
            ,ReplLottable11  = @c_ReplLottable11  --NJOW04
            ,ReplLottable12  = @c_ReplLottable12  --NJOW04
            ,ReplLottable13  = @d_ReplLottable13  --NJOW04
            ,ReplLottable14  = @d_ReplLottable14  --NJOW04
            ,ReplLottable15  = @d_ReplLottable15  --NJOW04
      INTO #REPLENISHMENT
      FROM LOTXLOCXID (NOLOCK)
      WHERE 1 = 2
      */
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @n_InvCnt                      INT
            , @n_InvCnt1                     INT      --NJOW03
            , @n_InvCnt3                     INT      --NJOW03
            , @n_InvCnt4                     INT      --NJOW04
            , @n_InvCnt5                     INT      --NJOW04
            , @n_InvCnt6                     INT      --NJOW04
            , @n_InvCnt7                     INT      --NJOW04
            , @n_InvCnt8                     INT      --NJOW04
            , @n_InvCnt9                     INT      --NJOW04
            , @n_InvCnt10                    INT      --NJOW04
            , @n_InvCnt11                    INT      --NJOW04
            , @n_InvCnt12                    INT      --NJOW04
            , @n_InvCnt13                    INT      --NJOW04
            , @n_InvCnt14                    INT      --NJOW04
            , @n_InvCnt15                    INT      --NJOW04
            , @c_CurrentStorer               NVARCHAR(15)
            , @c_CurrentSKU                  NVARCHAR(20)
            , @c_CurrentLoc                  NVARCHAR(10)
            , @c_CurrentPriority             NVARCHAR(5)
            , @n_Currentfullcase             INT
            , @n_CurrentSeverity             INT
            , @c_FromLOC                     NVARCHAR(10)
            , @c_Fromlot                     NVARCHAR(10)
            , @c_Fromid                      NVARCHAR(18)
            , @n_FromQty                     INT
            , @n_QtyAllocated                INT
            , @n_QtyPicked                   INT
            , @n_RemainingQty                INT
            , @n_numberofrecs                INT
            , @c_ReplenishmentKey            NVARCHAR(10)
            , @c_NoMixLottable02             NVARCHAR(10)
            , @c_Lottable02                  NVARCHAR(18)
            , @c_ReplValidationRules         NVARCHAR(10)
            , @c_NoMixLottable01             NVARCHAR(10)  --NJOW03
            , @c_Lottable01                  NVARCHAR(18)  --NJOW03
            , @c_NoMixLottable03             NVARCHAR(10)  --NJOW03
            , @c_Lottable03                  NVARCHAR(18)  --NJOW03
            , @c_NoMixLottable04             NVARCHAR(10)='0'  --NJOW04
            , @d_Lottable04                  DATETIME          --NJOW04
            , @c_NoMixLottable05             NVARCHAR(10)='0'  --NJOW04
            , @d_Lottable05                  DATETIME          --NJOW04
            , @c_NoMixLottable06             NVARCHAR(10)='0'  --NJOW04
            , @c_Lottable06                  NVARCHAR(18)=''   --NJOW04
            , @c_NoMixLottable07             NVARCHAR(10)='0'  --NJOW04
            , @c_Lottable07                  NVARCHAR(18)=' '  --NJOW04
            , @c_NoMixLottable08             NVARCHAR(10)='0'  --NJOW04
            , @c_Lottable08                  NVARCHAR(18)=''   --NJOW04
            , @c_NoMixLottable09             NVARCHAR(10)='0'  --NJOW04
            , @c_Lottable09                  NVARCHAR(18)=''   --NJOW04
            , @c_NoMixLottable10             NVARCHAR(10)='0'  --NJOW04
            , @c_Lottable10                  NVARCHAR(18)=''   --NJOW04
            , @c_NoMixLottable11             NVARCHAR(10)='0'  --NJOW04
            , @c_Lottable11                  NVARCHAR(18)=''   --NJOW04
            , @c_NoMixLottable12             NVARCHAR(10)='0'  --NJOW04
            , @c_Lottable12                  NVARCHAR(18)=''   --NJOW04
            , @c_NoMixLottable13             NVARCHAR(10)='0'  --NJOW04
            , @d_Lottable13                  DATETIME          --NJOW04
            , @c_NoMixLottable14             NVARCHAR(10)='0'  --NJOW04
            , @d_Lottable14                  DATETIME          --NJOW04
            , @c_NoMixLottable15             NVARCHAR(10)='0'  --NJOW04
            , @d_Lottable15                  DATETIME          --NJOW04

      SET @c_CurrentStorer    = ''
      SET @c_CurrentSKU       = ''
      SET @c_CurrentLoc       = ''
      SET @c_CurrentPriority  = ''
      SET @n_currentfullcase  = 0
      SET @n_CurrentSeverity  = 9999999
      SET @n_FromQty          = 0
      SET @n_RemainingQty     = 0
      SET @n_numberofrecs     = 0
      SET @c_ReplenishmentGroup = '' --NJOW02
      SET @c_NoMixLottable01  = '0'  --NJOW03
      SET @c_Lottable01       = ''   --NJOW03
      SET @c_NoMixLottable02  = '0'
      SET @c_Lottable02       = ''
      SET @c_NoMixLottable03  = '0'  --NJOW03
      SET @c_Lottable03       = ''   --NJOW03
      
      --NJOW04
      IF EXISTS(SELECT 1 
                FROM CODELKUP (NOLOCK)
                WHERE Code =  'NoReplenAlloPlt'
                AND ListName = 'REPORTCFG'
                AND Long = 'r_replenishment_report_pc18'
                AND Storerkey = @c_storerkey
                AND ISNULL(Short,'') <> 'N')
      BEGIN
         SET @c_NoReplenAlloPlt = 'Y'
      END
      ELSE
      BEGIN
      	 SET @c_NoReplenAlloPlt = 'N'
      END        

      /* Make a temp version of SKUxLOC */
      SELECT ReplenishmentPriority
            ,ReplenishmentSeverity
            ,StorerKey
            ,SKU
            ,LOC
            ,ReplenishmentCasecnt
            ,LocationType
      INTO #TempSKUxLOC
      FROM SKUxLOC (NOLOCK)
      WHERE 1=2

      INSERT #TempSKUxLOC
      SELECT ISNULL(SKUxLOC.ReplenishmentPriority, '')
            --,ReplenishmentSeverity = SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked)
            ,ReplenishmentSeverity = ISNULL(SKUxLOC.QtyLocationLimit,0) - ISNULL(SUM((LOTXLOCXID.Qty - LOTXLOCXID.QtyPicked) + LOTXLOCXID.PendingMoveIN),0) --NJOW02
            ,ISNULL(SKUxLOC.StorerKey,'')
            ,ISNULL(SKUxLOC.SKU, '')
            ,ISNULL(SKUxLOC.LOC,'')
            ,ISNULL(SKUxLOC.QtyLocationLimit,0)
            ,ISNULL(LOC.Locationtype,'')
      FROM SKUxLOC    WITH (NOLOCK)
      JOIN LOC        WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)
      LEFT JOIN LOTXLOCXID WITH (NOLOCK) ON (SKUxLOC.Storerkey = LOTXLOCXID.Storerkey AND SKUxLOC.Sku = LOTXLOCXID.Sku AND SKUxLOC.Loc = LOTXLOCXID.Loc) --NJOW02
      WHERE (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')
      AND   (SKUxLOC.LOCationtype = 'CASE' or SKUxLOC.LOCationtype = 'PALLET' or SKUxLOC.LOCationtype = 'PICK')
      AND   SKUxLOC.ReplenishmentCasecnt > 0
      AND   SKUxLOC.QtyExpected <= 0
      AND   SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtyLocationMinimum
      AND   (LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
      OR    @c_zone02 = 'ALL')
      AND   LOC.FACILITY = @c_Zone01
      AND   (LOC.PickZone= @c_ReplGrp OR @c_ReplGrp = 'ALL')
      AND   LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
      AND   LOC.Status <> 'HOLD'
      GROUP BY SKUxLOC.ReplenishmentPriority
             , SKUxLOC.StorerKey
             , SKUxLOC.SKU
             , SKUxLOC.LOC
             , SKUxLOC.Qty
             , SKUxLOC.QtyPicked
             , SKUxLOC.QtyAllocated
             , SKUxLOC.QtyLocationMinimum
             , SKUxLOC.QtyLocationLimit
             , LOC.Locationtype
      HAVING  ISNULL(SKUxLOC.Qty,0)- ISNULL(SKUxLOC.QtyPicked,0) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) <= ISNULL(SKUxLOC.QtyLocationMinimum,0) --NJOW02
      --HAVING SKUxLOC.QtyLocationLimit - ISNULL(SUM((LOTXLOCXID.Qty - LOTXLOCXID.QtyPicked) + LOTXLOCXID.PendingMoveIN),0) <= SKUxLOC.QtyLocationMinimum --NJOW02
      ORDER  By SKUxLOC.StorerKey
             , SKUxLOC.SKU
             , SKUxLOC.LOC

      IF @@ROWCOUNT > 0  AND ISNULL(@c_ReplGrp,'') IN ('ALL','') --NJOW02
      BEGIN
         EXECUTE nspg_GetKey
            'REPLENGROUP',
            9,
            @c_ReplenishmentGroup OUTPUT,
            @b_success OUTPUT,
            @n_err OUTPUT,
            @c_errmsg OUTPUT

         IF @b_success = 1
            SELECT @c_ReplenishmentGroup = 'T' + @c_ReplenishmentGroup
      END
      ELSE
         SET @c_ReplenishmentGroup = @c_ReplGrp

      /* Loop through SKUxLOC for the currentSKU, current storer */
      /* to pickup the next severity */
      DECLARE CUR_SKUxLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT CurrentStorer = StorerKey
            ,CurrentSKU = SKU
            ,CurrentLoc = LOC
            ,CurrentSeverity = ReplenishmentSeverity
            ,ReplenishmentPriority = ReplenishmentPriority
            ,ToLocationType        = LocationType
      FROM #TempSKUxLOC
      ORDER BY SKU

      OPEN CUR_SKUxLOC

      FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentStorer
                                    ,  @c_CurrentSKU
                                    ,  @c_CurrentLoc
                                    ,  @n_CurrentSeverity
                                    ,  @c_CurrentPriority
                                    ,  @c_ToLocationType
      WHILE @@Fetch_Status <> -1
      BEGIN
         /* We now have a pickLOCation that needs to be replenished! */
         /* Figure out which LOCations in the warehouse to pull this product from */
         /* End figure out which LOCations in the warehouse to pull this product from */
         SET @c_FromLOC = ''
         SET @c_FromLot = ''
         SET @c_FromId  = ''
         SET @n_FromQty = 0

         SET @n_RemainingQty  = @n_CurrentSeverity

         SET @n_Pallet = 0.00
         SET @n_CaseCnt = 0.00
         SELECT @n_Pallet = ISNULL(Pallet,0)
               ,@n_CaseCnt= ISNULL(CaseCnt,0)
               ,@c_Packkey = P.PackKey
               ,@c_UOM = P.PackUOM3
         FROM SKU  S WITH (NOLOCK)
         JOIN PACK P WITH (NOLOCK) ON (S.Packkey = P.Packkey)
         WHERE S.StorerKey = @c_CurrentStorer
         AND   S.Sku = @c_CurrentSku

         IF @c_ToLocationType = 'PALLET' AND @n_Pallet = 0
         BEGIN
            GOTO NEXT_SKUxLOC
         END

         IF @c_ToLocationType = 'CASE' AND @n_CaseCnt = 0
         BEGIN
            GOTO NEXT_SKUxLOC
         END

         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            --NJOW03 Start
            SET @c_NoMixLottable01  = '0'
            SELECT @c_NoMixLottable01 = ISNULL(RTRIM(NoMixLottable01),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt1 = 0
            SET @c_Lottable01 = ''
            SELECT TOP 1 @n_InvCnt1 = 1
                  , @c_Lottable01 = ISNULL(RTRIM(LA.lottable01),'')
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  --NJOW04
            --NJOW03 End

            SET @c_NoMixLottable02  = '0'
            SELECT @c_NoMixLottable02 = ISNULL(RTRIM(NoMixLottable02),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt = 0
            SET @c_Lottable02 = ''
            SELECT TOP 1 @n_InvCnt = 1
                  , @c_Lottable02 = ISNULL(RTRIM(LA.lottable02),'')
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  --NJOW04

            --NJOW03 Start
            SET @c_NoMixLottable03  = '0'
            SELECT @c_NoMixLottable03 = ISNULL(RTRIM(NoMixLottable03),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt3 = 0
            SET @c_Lottable03 = ''
            SELECT TOP 1 @n_InvCnt3 = 1
                  , @c_Lottable03 = ISNULL(RTRIM(LA.lottable03),'')
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  --NJOW04
            --NJOW03 End

            --NJOW04 Start
            SET @c_NoMixLottable04  = '0'
            SELECT @c_NoMixLottable04 = ISNULL(RTRIM(NoMixLottable04),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt4 = 0
            SET @d_Lottable04 = NULL
            SELECT TOP 1 @n_InvCnt4 = 1
                  , @d_Lottable04 = LA.lottable04
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  

            SET @c_NoMixLottable05  = '0'
            SELECT @c_NoMixLottable05 = ISNULL(RTRIM(NoMixLottable05),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt5 = 0
            SET @d_Lottable05 = NULL
            SELECT TOP 1 @n_InvCnt5 = 1
                  , @d_Lottable05 = LA.lottable05
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  

            SET @c_NoMixLottable06  = '0'
            SELECT @c_NoMixLottable06 = ISNULL(RTRIM(NoMixLottable06),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt6 = 0
            SET @c_Lottable06 = ''
            SELECT TOP 1 @n_InvCnt6 = 1
                  , @c_Lottable06 = ISNULL(RTRIM(LA.lottable06),'')
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  

            SET @c_NoMixLottable07  = '0'
            SELECT @c_NoMixLottable07 = ISNULL(RTRIM(NoMixLottable07),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt7 = 0
            SET @c_Lottable07 = ''
            SELECT TOP 1 @n_InvCnt7 = 1
                  , @c_Lottable07 = ISNULL(RTRIM(LA.lottable07),'')
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  

            SET @c_NoMixLottable08  = '0'
            SELECT @c_NoMixLottable08 = ISNULL(RTRIM(NoMixLottable08),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt8 = 0
            SET @c_Lottable08 = ''
            SELECT TOP 1 @n_InvCnt8 = 1
                  , @c_Lottable08 = ISNULL(RTRIM(LA.lottable08),'')
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  

            SET @c_NoMixLottable09  = '0'
            SELECT @c_NoMixLottable09 = ISNULL(RTRIM(NoMixLottable09),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt9 = 0
            SET @c_Lottable09 = ''
            SELECT TOP 1 @n_InvCnt9 = 1
                  , @c_Lottable09 = ISNULL(RTRIM(LA.lottable09),'')
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0 

            SET @c_NoMixLottable10  = '0'
            SELECT @c_NoMixLottable10 = ISNULL(RTRIM(NoMixLottable10),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt10 = 0
            SET @c_Lottable10 = ''
            SELECT TOP 1 @n_InvCnt10 = 1
                  , @c_Lottable10 = ISNULL(RTRIM(LA.lottable10),'')
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  

            SET @c_NoMixLottable11  = '0'
            SELECT @c_NoMixLottable11 = ISNULL(RTRIM(NoMixLottable11),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt11 = 0
            SET @c_Lottable11 = ''
            SELECT TOP 1 @n_InvCnt11 = 1
                  , @c_Lottable11 = ISNULL(RTRIM(LA.lottable11),'')
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  

            SET @c_NoMixLottable12  = '0'
            SELECT @c_NoMixLottable12 = ISNULL(RTRIM(NoMixLottable12),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt12 = 0
            SET @c_Lottable12 = ''
            SELECT TOP 1 @n_InvCnt12 = 1
                  , @c_Lottable12 = ISNULL(RTRIM(LA.lottable12),'')
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  

            SET @c_NoMixLottable13  = '0'
            SELECT @c_NoMixLottable13 = ISNULL(RTRIM(NoMixLottable13),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt13 = 0
            SET @d_Lottable13 = NULL
            SELECT TOP 1 @n_InvCnt5 = 1
                  , @d_Lottable13 = LA.lottable13
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  

            SET @c_NoMixLottable14  = '0'
            SELECT @c_NoMixLottable14 = ISNULL(RTRIM(NoMixLottable14),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt14 = 0
            SET @d_Lottable14 = NULL
            SELECT TOP 1 @n_InvCnt14 = 1
                  , @d_Lottable14 = LA.lottable14
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  

            SET @c_NoMixLottable15  = '0'
            SELECT @c_NoMixLottable15 = ISNULL(RTRIM(NoMixLottable15),'0')
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_CurrentLoc

            SET @n_InvCnt15 = 0
            SET @d_Lottable15 = NULL
            SELECT TOP 1 @n_InvCnt15 = 1
                  , @d_Lottable15 = LA.lottable15
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
            WHERE LLI.Storerkey = @c_CurrentStorer
            AND LLI.Sku = @c_CurrentSku
            AND LLI.Loc = @c_CurrentLoc
            AND (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn > 0  
            --NJOW04 End
         END
          
         --NJOW04 S
         SET @c_SQL = N'
         DECLARE CUR_REPL CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOT
               ,LOTxLOCxID.Loc
               ,LOTxLOCxID.ID
               ,LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen   -- (ang01)  --NJOW02
               ,LOTxLOCxID.QtyAllocated
               ,LOTxLOCxID.QtyPicked
               ,LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02 ,LOTATTRIBUTE.Lottable03 ,LOTATTRIBUTE.Lottable04 ,LOTATTRIBUTE.Lottable05
               ,LOTATTRIBUTE.Lottable06 ,LOTATTRIBUTE.Lottable07 ,LOTATTRIBUTE.Lottable08 ,LOTATTRIBUTE.Lottable09 ,LOTATTRIBUTE.Lottable10
               ,LOTATTRIBUTE.Lottable11 ,LOTATTRIBUTE.Lottable12 ,LOTATTRIBUTE.Lottable13 ,LOTATTRIBUTE.Lottable14 ,LOTATTRIBUTE.Lottable15
         FROM LOT          WITH (NOLOCK)
         JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.Lot        = LOTATTRIBUTE.LOT)
         JOIN LOTxLOCxID   WITH (NOLOCK) ON (LOT.Lot        = LOTxLOCxID.Lot)
         JOIN LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
         WHERE LOTxLOCxID.LOC <> @c_CurrentLoc
         AND LOTxLOCxID.StorerKey = @c_CurrentStorer
         AND LOTxLOCxID.SKU = @c_CurrentSku
         AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen > 0  --NJOW02
         AND LOTxLOCxID.QtyExpected = 0 -- make sure we are not going to try to pull from a LOCation that needs stuff to satisfy existing demand
         AND LOC.LocationFlag NOT IN (''DAMAGE'', ''HOLD'')
         AND LOC.LocationType NOT IN (CASE WHEN @c_ReplGrp = ''CASE'' THEN @c_ReplGrp ELSE ''PALLET'' END
                                    ,''CASE'',''PICK'')
         AND LOC.Status <> ''HOLD''
         AND LOC.Facility = @c_Zone01
         AND(LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         OR  @c_zone02 = ''ALL'')
         AND LOT.Status = ''OK'' ' +
         CASE WHEN @c_NoMixLottable01 = '1' AND @n_InvCnt1 > 0 THEN ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable02 = '1' AND @n_InvCnt > 0 THEN  ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable03 = '1' AND @n_InvCnt3 > 0 THEN ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable04 = '1' AND @n_InvCnt4 > 0  AND CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL
              THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable05 = '1' AND @n_InvCnt5 > 0  AND CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL
              THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable06 = '1' AND @n_InvCnt6 > 0 THEN ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable07 = '1' AND @n_InvCnt7 > 0 THEN ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable08 = '1' AND @n_InvCnt8 > 0 THEN ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable09 = '1' AND @n_InvCnt9 > 0 THEN ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable10 = '1' AND @n_InvCnt10 > 0 THEN ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable11 = '1' AND @n_InvCnt11 > 0 THEN ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable12 = '1' AND @n_InvCnt12 > 0 THEN ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable13 = '1' AND @n_InvCnt13 > 0  AND CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL
              THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable14 = '1' AND @n_InvCnt14 > 0  AND CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL
              THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
         CASE WHEN @c_NoMixLottable15 = '1' AND @n_InvCnt15 > 0  AND CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL
              THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
       ' AND LOC.LocationType NOT IN(''DAMAGE'') --NJOW03
         AND LOC.LocationCategory NOT IN (''BL'',''QI'') --NJOW03
         AND LOTATTRIBUTE.Lottable01 NOT IN (''BL'',''QI'') --NJOW03
         ORDER BY ISNULL(LOTATTRIBUTE.LOTTABLE04, ''1900-01-01'')  --NJOW01
               ,  ISNULL(LOTATTRIBUTE.LOTTABLE05, ''1900-01-01'')
               ,  CASE WHEN (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) < @n_Pallet THEN 1   --NJOW02
                       ELSE 2
                       END
               ,  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked)
               ,  LOTxLOCxID.LOT
               ,  LOTxLOCxID.ID'
               
         SET @c_SQLParm =  N'@c_CurrentLoc NVARCHAR(10), @c_CurrentStorer NVARCHAR(15), @c_CurrentSku NVARCHAR(20), @c_ReplGrp NVARCHAR(30),
                             @c_Zone01 NVARCHAR(10), @c_Zone02 NVARCHAR(10), @c_Zone03 NVARCHAR(10), @c_Zone04 NVARCHAR(10), @c_Zone05 NVARCHAR(10), @c_Zone06 NVARCHAR(10),  
                             @c_Zone07 NVARCHAR(10), @c_Zone08 NVARCHAR(10), @c_Zone09 NVARCHAR(10), @c_Zone10 NVARCHAR(10), @c_Zone11 NVARCHAR(10), @c_Zone12 NVARCHAR(10),  
                             @c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME,
                             @c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30),
                             @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME, @n_Pallet INT'
                                                          
         
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_CurrentLoc, @c_CurrentStorer, @c_CurrentSku, @c_ReplGrp, @c_Zone01, @c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06,
                            @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                            @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @n_Pallet         
         --NJOW04 E
 
         OPEN CUR_REPL

         FETCH NEXT FROM CUR_REPL INTO @c_FromLot
                                    ,  @c_FromLoc
                                    ,  @c_FromID
                                    ,  @n_FromQty
                                    ,  @n_QtyAllocated
                                    ,  @n_QtyPicked
                                    ,  @c_ReplLottable01 --NJOW04
                                    ,  @c_ReplLottable02
                                    ,  @c_ReplLottable03 --NJOW04
                                    ,  @d_ReplLottable04 --NJOW04
                                    ,  @d_ReplLottable05 --NJOW04
                                    ,  @c_ReplLottable06 --NJOW04
                                    ,  @c_ReplLottable07 --NJOW04
                                    ,  @c_ReplLottable08 --NJOW04
                                    ,  @c_ReplLottable09 --NJOW04
                                    ,  @c_ReplLottable10 --NJOW04
                                    ,  @c_ReplLottable11 --NJOW04
                                    ,  @c_ReplLottable12 --NJOW04
                                    ,  @d_ReplLottable13 --NJOW04
                                    ,  @d_ReplLottable14 --NJOW04
                                    ,  @d_ReplLottable15 --NJOW04

         WHILE @@Fetch_Status <> -1 AND @n_RemainingQty > 0
         BEGIN
            IF @n_continue IN(1,2)
            BEGIN
               IF @c_NoMixLottable01 = '1' AND @n_InvCnt1 = 0 --NJOW04
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable01 <> @c_ReplLottable01
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END

               IF @c_NoMixLottable02 = '1' AND @n_InvCnt = 0
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable02 <> @c_ReplLottable02
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END

               --NJOW04 S
               IF @c_NoMixLottable03 = '1' AND @n_InvCnt3 = 0 
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable03 <> @c_ReplLottable03
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END   
               
               IF @c_NoMixLottable04 = '1' AND @n_InvCnt4 = 0 AND CONVERT(NVARCHAR(8) ,@d_ReplLottable04 ,112) <> '19000101' AND @d_ReplLottable04 IS NOT NULL
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable04 <> @d_ReplLottable04
                              AND CONVERT(NVARCHAR(8) ,ReplLottable04 ,112) <> '19000101' 
                              AND ReplLottable04 IS NOT NULL
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END   

               IF @c_NoMixLottable05 = '1' AND @n_InvCnt5 = 0 AND CONVERT(NVARCHAR(8) ,@d_ReplLottable05 ,112) <> '19000101' AND @d_ReplLottable05 IS NOT NULL
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable05 <> @d_ReplLottable05
                              AND CONVERT(NVARCHAR(8) ,ReplLottable05 ,112) <> '19000101' 
                              AND ReplLottable05 IS NOT NULL
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END                  

               IF @c_NoMixLottable06 = '1' AND @n_InvCnt6 = 0 
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable06 <> @c_ReplLottable06
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END   


               IF @c_NoMixLottable07 = '1' AND @n_InvCnt7 = 0 
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable07 <> @c_ReplLottable07
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END   

               IF @c_NoMixLottable08 = '1' AND @n_InvCnt8 = 0 
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable08 <> @c_ReplLottable08
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END   

               IF @c_NoMixLottable09 = '1' AND @n_InvCnt9 = 0 
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable09 <> @c_ReplLottable09
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END   

               IF @c_NoMixLottable10 = '1' AND @n_InvCnt10 = 0 
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable10 <> @c_ReplLottable10
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END   

               IF @c_NoMixLottable11 = '1' AND @n_InvCnt11 = 0 
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable11 <> @c_ReplLottable11
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END   

               IF @c_NoMixLottable12 = '1' AND @n_InvCnt12 = 0 
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable12 <> @c_ReplLottable12
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END   

               IF @c_NoMixLottable13 = '1' AND @n_InvCnt13 = 0 AND CONVERT(NVARCHAR(8) ,@d_ReplLottable13 ,112) <> '19000101' AND @d_ReplLottable13 IS NOT NULL
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable13 <> @d_ReplLottable13
                              AND CONVERT(NVARCHAR(8) ,ReplLottable13 ,112) <> '19000101' 
                              AND ReplLottable13 IS NOT NULL
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END                  

               IF @c_NoMixLottable14 = '1' AND @n_InvCnt14 = 0 AND CONVERT(NVARCHAR(8) ,@d_ReplLottable14 ,112) <> '19000101' AND @d_ReplLottable14 IS NOT NULL
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable14 <> @d_ReplLottable14
                              AND CONVERT(NVARCHAR(8) ,ReplLottable14 ,112) <> '19000101' 
                              AND ReplLottable14 IS NOT NULL
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END                  

               IF @c_NoMixLottable15 = '1' AND @n_InvCnt15 = 0 AND CONVERT(NVARCHAR(8) ,@d_ReplLottable15 ,112) <> '19000101' AND @d_ReplLottable15 IS NOT NULL
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                              WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                              AND ReplLottable15 <> @d_ReplLottable15
                              AND CONVERT(NVARCHAR(8) ,ReplLottable15 ,112) <> '19000101' 
                              AND ReplLottable15 IS NOT NULL
                              GROUP BY Storerkey, Sku, ToLoc
                              HAVING COUNT(1) > 0)
                  BEGIN
                     GOTO NEXT_CANDIDATE
                  END
               END                  
               --NJOW04 E            
            END

            IF EXISTS(SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_FromID AND STATUS = 'HOLD')
            BEGIN
               GOTO NEXT_CANDIDATE
            END

            IF EXISTS(SELECT 1 FROM #REPLENISHMENT
                      WHERE LOT =  @c_fromlot AND FromLOC = @c_FromLOC AND ID = @c_fromid)
            BEGIN
               GOTO NEXT_CANDIDATE
            END

            SELECT @c_ReplValidationRules = SC.sValue
            FROM STORERCONFIG SC (NOLOCK)
            JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
            WHERE SC.StorerKey = @c_StorerKey
            AND SC.Configkey = 'ReplenValidation'

            IF ISNULL(@c_ReplValidationRules,'') <> ''
            BEGIN
               EXEC isp_REPL_ExtendedValidation @c_fromlot = @c_fromlot
                                             ,  @c_FromLOC = @c_FromLOC
                                             ,  @c_fromid  = @c_fromid
                                             ,  @c_ReplValidationRules=@c_ReplValidationRules
                                             ,  @b_Success = @b_Success OUTPUT
                                             ,  @c_ErrMsg  = @c_ErrMsg OUTPUT


               IF @b_Success = 0
               BEGIN
                  GOTO NEXT_CANDIDATE
               END
            END                               
            
            IF @n_QtyAllocated > 0 AND @c_NoReplenAlloPlt = 'Y' --NJOW04
               GOTO NEXT_CANDIDATE  

            IF @c_ToLocationType = 'PALLET'
            BEGIN
               IF @n_FromQty < @n_Pallet
               BEGIN
                  GOTO NEXT_CANDIDATE
               END

               IF @n_FromQty > @n_RemainingQty
               BEGIN
                  SET @n_FromQty = FLOOR(@n_RemainingQty/@n_Pallet) * @n_Pallet
               END
               ELSE
               BEGIN
                  SET @n_FromQty = FLOOR(@n_FromQty/@n_Pallet) * @n_Pallet
               END
            END
            ELSE IF @c_ToLocationType = 'CASE'
            BEGIN
               IF @n_FromQty < @n_CaseCnt
               BEGIN
                  GOTO NEXT_CANDIDATE
               END

               IF @n_FromQty > @n_RemainingQty
               BEGIN
                  SET @n_FromQty = 0
               END
               ELSE
               BEGIN
                  IF @n_FromQty < @n_Pallet
                  BEGIN
                     SET @n_FromQty = FLOOR(@n_FromQty/@n_CaseCnt) * @n_CaseCnt
                  END
                  ELSE
                  BEGIN
                     SET @n_FromQty = FLOOR(@n_FromQty/@n_Pallet) * @n_Pallet
                  END
               END
            END

            SET @n_RemainingQty = @n_RemainingQty - @n_FromQty

            IF @n_FromQty > 0 --AND @n_RemainingQty >= 0
            BEGIN
               INSERT #REPLENISHMENT
                     (
                        StorerKey
                            ,  SKU
                     ,  FromLOC
                     ,  ToLOC
                     ,  Lot
                     ,  Id
                     ,  Qty
                     ,  UOM
                     ,  PackKey
                     ,  Priority
                     ,  QtyMoved
                     ,  QtyInPickLOC
                     ,  ReplLottable01
                     ,  ReplLottable02
                     ,  ReplLottable03
                     ,  ReplLottable04
                     ,  ReplLottable05
                     ,  ReplLottable06
                     ,  ReplLottable07
                     ,  ReplLottable08
                     ,  ReplLottable09
                     ,  ReplLottable10
                     ,  ReplLottable11
                     ,  ReplLottable12
                     ,  ReplLottable13
                     ,  ReplLottable14
                     ,  ReplLottable15
                     )
                        VALUES
                     (
                        @c_CurrentStorer
                     ,  @c_CurrentSKU
                     ,  @c_FromLOC
                     ,  @c_CurrentLoc
                     ,  @c_FromLot
                     ,  @c_Fromid
                     ,  @n_FromQty
                     ,  @c_UOM
                     ,  @c_Packkey
                     ,  @c_CurrentPriority
                     ,  @n_QtyAllocated
                     ,  @n_QtyPicked
                     ,  @c_ReplLottable01 --NJOW04
                     ,  @c_ReplLottable02
                     ,  @c_ReplLottable03 --NJOW04
                     ,  @d_ReplLottable04 --NJOW04
                     ,  @d_ReplLottable05 --NJOW04
                     ,  @c_ReplLottable06 --NJOW04
                     ,  @c_ReplLottable07 --NJOW04
                     ,  @c_ReplLottable08 --NJOW04
                     ,  @c_ReplLottable09 --NJOW04
                     ,  @c_ReplLottable10 --NJOW04
                     ,  @c_ReplLottable11 --NJOW04
                     ,  @c_ReplLottable12 --NJOW04
                     ,  @d_ReplLottable13 --NJOW04
                     ,  @d_ReplLottable14 --NJOW04
                     ,  @d_ReplLottable15 --NJOW04
                     )

               SET @n_numberofrecs = @n_numberofrecs + 1

               IF @b_debug = 1
               BEGIN
                  SELECT 'INSERTED : ' as Title, @c_CurrentSKU ' SKU', @c_fromlot 'LOT',  @c_CurrentLoc 'LOC', @c_fromid 'ID',
                         @n_FromQty 'Qty'
               END
            END

            IF @b_debug = 1
            BEGIN
               select @c_CurrentSKU ' SKU', @c_CurrentLoc 'LOC', @c_CurrentPriority 'priority', @n_currentfullcase 'full case', @n_CurrentSeverity 'severity'
               select @n_RemainingQty '@n_RemainingQty', @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU, @c_fromlot 'from lot', @c_fromid
            END

            NEXT_CANDIDATE:
            FETCH NEXT FROM CUR_REPL INTO @c_FromLot
                                       ,  @c_FromLoc
                                       ,  @c_FromID
                                       ,  @n_FromQty
                                       ,  @n_QtyAllocated
                                       ,  @n_QtyPicked
                                       ,  @c_ReplLottable01 --NJOW04
                                       ,  @c_ReplLottable02
                                       ,  @c_ReplLottable03 --NJOW04
                                       ,  @d_ReplLottable04 --NJOW04
                                       ,  @d_ReplLottable05 --NJOW04
                                       ,  @c_ReplLottable06 --NJOW04
                                       ,  @c_ReplLottable07 --NJOW04
                                       ,  @c_ReplLottable08 --NJOW04
                                       ,  @c_ReplLottable09 --NJOW04
                                       ,  @c_ReplLottable10 --NJOW04
                                       ,  @c_ReplLottable11 --NJOW04
                                       ,  @c_ReplLottable12 --NJOW04
                                       ,  @d_ReplLottable13 --NJOW04
                                       ,  @d_ReplLottable14 --NJOW04
                                       ,  @d_ReplLottable15 --NJOW04
         END -- LOT
         CLOSE CUR_REPL
         DEALLOCATE CUR_REPL

         NEXT_SKUxLOC:
         FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentStorer
                                       ,  @c_CurrentSKU
                                       ,  @c_CurrentLoc
                                       ,  @n_CurrentSeverity
                                       ,  @c_CurrentPriority
                                       ,  @c_ToLocationtype

      END -- -- FOR SKUxLOC

      CLOSE CUR_SKUxLOC
      DEALLOCATE CUR_SKUxLOC
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      /* Update the column QtyInPickLOC in the Replenishment Table */
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         UPDATE #REPLENISHMENT SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked
         FROM SKUxLOC WITH (NOLOCK)
         WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey AND
         #REPLENISHMENT.SKU = SKUxLOC.SKU AND
         #REPLENISHMENT.toLOC = SKUxLOC.LOC
      END
   END
   /* Insert Into Replenishment Table Now */
--   DECLARE @b_success   INT
--         , @n_err       INT
--         , @c_errmsg    NVARCHAR(255)

   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT R.FromLoc
         ,R.Id
         ,R.ToLoc
         ,R.Sku
         ,R.Qty
         ,R.StorerKey
         ,R.Lot
         ,R.PackKey
         ,R.Priority
         ,R.UOM
   FROM #REPLENISHMENT R

   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_FromLOC
                           , @c_FromID
                           , @c_CurrentLoc
                           , @c_CurrentSKU
                           , @n_FromQty
                           , @c_CurrentStorer
                           , @c_FromLot
                           , @c_PackKey
                           , @c_Priority
                           , @c_UOM
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXECUTE nspg_GetKey
            'REPLENISHKEY'
         ,  10
         ,  @c_ReplenishmentKey  OUTPUT
         ,   @b_success          OUTPUT
         ,   @n_err              OUTPUT
         ,   @c_errmsg           OUTPUT

      IF NOT @b_success = 1
      BEGIN
         BREAK
      END

      IF @b_success = 1
      BEGIN
         INSERT REPLENISHMENT
            (
               replenishmentgroup
            ,  ReplenishmentKey
            ,  StorerKey
            ,  Sku
            ,  FromLoc
            ,  ToLoc
            ,  Lot
            ,  Id
            ,  Qty
            ,  UOM
            ,  PackKey
            ,  Confirmed
            ,  RefNo  --NJOW02
            )
               VALUES (
               @c_ReplenishmentGroup  --@c_ReplGrp  NJOW02
            ,  @c_ReplenishmentKey
            ,  @c_CurrentStorer
            ,  @c_CurrentSKU
            ,  @c_FromLOC
            ,  @c_CurrentLoc
            ,  @c_FromLot
            ,  @c_FromId
            ,  @n_FromQty
            ,  @c_UOM
            ,  @c_PackKey
            ,  'N'
            , 'PC18'  --NJOW02
            )
         SET @n_err = @@ERROR

      END -- IF @b_success = 1

      FETCH NEXT FROM CUR1 INTO @c_FromLOC
                              , @c_FromID
                              , @c_CurrentLoc
                              , @c_CurrentSKU
                              , @n_FromQty
                              , @c_CurrentStorer
                              , @c_FromLot
                              , @c_PackKey
                              , @c_Priority
                              , @c_UOM
   END -- While
   CLOSE CUR1
   DEALLOCATE CUR1
   -- End Insert Replenishment

   QUIT_SP:

   IF @c_backendjob <> 'Y' --NJOW02
   BEGIN
      --(Wan01) - START
      IF @c_FuncType IN ( 'G' )
      BEGIN
         RETURN
      END
      --(Wan01) - END

      --(Wan02) - START
      IF @c_FuncType IN ( 'P' )
      BEGIN
         SET @c_ReplenishmentGroup = @c_ReplGrp
      END
      --(Wan02) - END

      SELECT R.FromLoc
            ,R.Id
            ,R.ToLoc
            ,R.Sku
            ,R.Qty
            ,R.StorerKey
            ,R.Lot
            ,R.PackKey
            ,SKU.Descr
            ,R.Priority
            ,LOC.PutawayZone
            ,PACK.CaseCnt
            ,PACK.Pallet
            ,NoOfCSInPL = CASE WHEN PACK.CaseCnt > 0 THEN PACK.Pallet / PACK.CaseCnt ELSE 0 END
            ,SuggestPL  = CASE WHEN PACK.Pallet  > 0 THEN FLOOR(R.Qty / PACK.Pallet) ELSE 0 END
            ,SuggestCS  = CASE WHEN PACK.CaseCnt > 0 THEN FLOOR((R.Qty % CONVERT(INT, PACK.Pallet)) / PACK.CaseCnt) ELSE 0 END
            ,TotalCS    = CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(R.Qty / PACK.CaseCnt) ELSE 0 END
            ,PACK.PackUOM1
            ,PACK.PackUOM3
            ,R.ReplenishmentKey
            ,LA.Lottable02
      FROM  REPLENISHMENT R WITH (NOLOCK)
      JOIN  SKU             WITH (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)
      JOIN  LOC             WITH (NOLOCK) ON (LOC.Loc = R.ToLoc)
      JOIN  PACK            WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (R.Lot = LA.Lot)
      WHERE (R.Replenishmentgroup = @c_ReplenishmentGroup OR @c_ReplenishmentGroup = 'ALL')  --(Wan01) --(Wan02)
      --WHERE R.ReplenishmentGroup = @c_ReplenishmentGroup --@c_ReplGrp NJOW02   --(Wan02)
      AND  (LOC.PickZone = @c_ReplGrp OR @c_ReplGrp = 'ALL')
      AND   LOC.facility = @c_zone01
      AND  (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')
      AND  (LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
      OR  @c_zone02 = 'ALL')
      AND R.Confirmed = 'N'

      ORDER BY LOC.PutawayZone
            ,  R.FromLoc
            ,  R.Id
            ,  LA.Lottable02
            ,  R.Sku
   END
END

GO
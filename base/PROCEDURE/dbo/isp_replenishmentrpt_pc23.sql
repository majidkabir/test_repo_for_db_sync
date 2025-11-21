SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ReplenishmentRpt_PC23                             */
/* Creation Date:  04-JUL-2017                                             */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-1040 PH Green Cross replenishment report                   */
/*        : modify from nsp_ReplenishmentRpt_PC18                          */
/*                                                                         */
/* Called By: Replenishment Report                                         */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 20-Dec-2017 NJOW01  1.0   WMS-2324 Add pendingmovein,qtyreplen checking */
/*                            ,replenishmentgroup & refno for working with */
/*                            release task                                 */
/* 05-MAR-2018  Wan01   1.1   WM - Add Functype                            */
/* 14-AUG-2019  Wan02   1.2   WMS-10260 - [PH] Unilever Replenishment      */
/*                            Strategy                                     */
/* 20-AUG-2019  Wan02   1.3   WMS-10309 - [PH] Unilever Replenishment      */
/*                            Strategy - CR                                */
/* 03-JUN-2022  LZG     1.4   JSM-71223 - Follow Parameters to follow      */
/*                            Datawindow Seq (ZG01)                        */
/***************************************************************************/
CREATE PROC [dbo].[isp_ReplenishmentRpt_PC23]
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
,              @c_ReplGrp          NVARCHAR(30)    --PickZone
--,              @c_backendjob       NVARCHAR(10) = 'N' --NJOW01
--,              @c_Functype         NCHAR(1) = ''        --(Wan01)
,              @c_Functype         NCHAR(1) = ''      -- ZG01
,              @c_backendjob       NVARCHAR(10) = 'N' -- ZG01
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
         , @c_Sql             NVARCHAR(4000)

         , @c_Packkey         NVARCHAR(10)
         , @c_UOM             NVARCHAR(10)
         , @c_ToLocationType  NVARCHAR(10)
         , @n_CaseCnt         FLOAT
         , @n_Pallet          FLOAT

         , @n_FilterQty       INT          = 0  --(Wan02)
         , @c_ReplFullPallet  NVARCHAR(10) = 'N'--(Wan02)
         , @c_Storerkey_CL    NVARCHAR(15) = '' --(Wan02)
         , @c_ReplFreshStock  NVARCHAR(10) = 'N'--(Wan03)
         , @c_SUSR2           NVARCHAR(18) = '' --(Wan03)
         , @n_shelflife       INT          = 0  --(Wan03)
         , @d_today           DATETIME          --(Wan03)

   DECLARE @c_priority        NVARCHAR(5)
         , @c_ReplLottable02  NVARCHAR(18)
         , @c_ReplenishmentGroup NVARCHAR(10)  --NJOW01

   SET @n_continue=1
   SET @b_debug = 0
   SET @c_ReplenishmentGroup = '' --NJOW01

   IF @c_zone12 = '1'
   BEGIN
      SET @b_debug = CAST( @c_zone12 AS int)
      SET @c_zone12 = ''
   END

   --(Wan01) - START
   IF @c_FuncType IN ( 'P' )
   BEGIN
      GOTO QUIT_SP
   END
   --(Wan01) - END

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
         ,ReplLottable02  = @c_ReplLottable02
   INTO #REPLENISHMENT
   FROM LOTXLOCXID (NOLOCK)
   WHERE 1 = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @n_InvCnt          INT
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
            , @c_CaseToPick                  NVARCHAR(10) --NJOW02

      SET @c_CurrentStorer    = ''
      SET @c_CurrentSKU       = ''
      SET @c_CurrentLoc       = ''
      SET @c_CurrentPriority  = ''
      SET @n_currentfullcase  = 0
      SET @n_CurrentSeverity  = 9999999
      SET @n_FromQty          = 0
      SET @n_RemainingQty     = 0
      SET @n_numberofrecs     = 0

      SET @c_NoMixLottable02  = '0'
      SET @c_Lottable02       = ''
      /* Make a temp version of SKUxLOC */
      SELECT ReplenishmentPriority
            ,ReplenishmentSeverity
            ,StorerKey
            ,SKU
            ,LOC
            ,ReplenishmentCasecnt
            ,LocationType
            ,' ' AS CaseToPick --NJOW02
      INTO #TempSKUxLOC
      FROM SKUxLOC (NOLOCK)
      WHERE 1=2

      INSERT #TempSKUxLOC
      SELECT SKUxLOC.ReplenishmentPriority
            --,ReplenishmentSeverity = SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked)
            ,ReplenishmentSeverity = SKUxLOC.QtyLocationLimit - ISNULL(SUM((LOTXLOCXID.Qty - LOTXLOCXID.QtyPicked) + LOTXLOCXID.PendingMoveIN),0) --NJOW01
            ,SKUxLOC.StorerKey
            ,SKUxLOC.SKU
            ,SKUxLOC.LOC
            ,SKUxLOC.QtyLocationLimit
            ,LOC.Locationtype
            ,CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS CaseToPick  --NJOW02
      FROM SKUxLOC    WITH (NOLOCK)
      JOIN LOC        WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)
      LEFT JOIN LOTXLOCXID WITH (NOLOCK) ON (SKUxLOC.Storerkey = LOTXLOCXID.Storerkey AND SKUxLOC.Sku = LOTXLOCXID.Sku AND SKUxLOC.Loc = LOTXLOCXID.Loc) --NJOW01
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (SKUxLOC.Storerkey = CLR.Storerkey AND CLR.Code = 'REPLCASETOPICK'
                                          AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_replenishment_report_pc23' AND ISNULL(CLR.Short,'') <> 'N')  --NJOW02
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
             , CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END --NJOW02
      HAVING (SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) <= SKUxLOC.QtyLocationMinimum --NJOW01
      --HAVING SUM((LOTXLOCXID.Qty - LOTXLOCXID.QtyPicked) + LOTXLOCXID.PendingMoveIN) <= SKUxLOC.QtyLocationMinimum --NJOW01
      ORDER  By SKUxLOC.StorerKey
             , SKUxLOC.SKU
             , SKUxLOC.LOC

      IF @@ROWCOUNT > 0  AND ISNULL(@c_ReplGrp,'') IN ('ALL','') --NJOW01
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
            ,CaseToPick = CaseToPick --NJOW02
      FROM #TempSKUxLOC
      ORDER BY SKU

      OPEN CUR_SKUxLOC

      FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentStorer
                                    ,  @c_CurrentSKU
                                    ,  @c_CurrentLoc
                                    ,  @n_CurrentSeverity
                                    ,  @c_CurrentPriority
                                                ,  @c_ToLocationType
                                                ,  @c_CaseToPick --NJOW02
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
               ,@c_SUSR2 = ISNULL(S.SUSR2,'')         --(Wan03)
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
         AND LLI.Qty - LLI.QtyPicked > 0

         --(Wan02) - START
         IF @c_Storerkey_CL <> @c_Storerkey
         BEGIN
            SET @c_ReplFullPallet = 'N'
            --(Wan03) - START
            SET @c_ReplFreshStock = 'N'
            --SELECT @c_ReplFullPallet = CASE WHEN IsNull(CL.Short, 'N') <> 'N' THEN 'Y' ELSE 'N' END
            --FROM CODELKUP CL WITH (NOLOCK)
            --WHERE CL.ListName = 'REPORTCFG'
            --AND CL.Code = 'ReplFullPallet'
            --AND CL.Long = 'r_replenishment_report_pc23'
            --AND CL.Storerkey = @c_Storerkey

            SELECT @c_ReplFullPallet = ISNULL(MAX(CASE WHEN CL.Code ='ReplFullPallet' THEN 'Y' ELSE 'N' END),'N')
                  ,@c_ReplFreshStock = ISNULL(MAX(CASE WHEN CL.Code ='ReplFreshStock' THEN 'Y' ELSE 'N' END),'N')
            FROM CODELKUP CL WITH (NOLOCK)
            WHERE CL.ListName = 'REPORTCFG'
            AND CL.Long = 'r_replenishment_report_pc23'
            AND CL.Storerkey = @c_Storerkey
            AND CL.Short = 'Y'
            --(Wan03) - END

            SET @c_Storerkey_CL = @c_Storerkey
         END

         SET @n_FilterQty = 1
         IF @c_ReplFullPallet = 'Y'
         BEGIN
            IF @n_Pallet = 0
            BEGIN
               GOTO NEXT_SKUxLOC
            END
            SET @n_FilterQty = @n_Pallet
         END
         --(Wan02) - END

         --(Wan03) - START
         SET @n_ShelfLife = 0
         SET @d_today = CONVERT(DATETIME,'1900-01-01')
         IF @c_ReplFreshStock = 'Y'
         BEGIN
            IF ISNUMERIC(@c_SUSR2) = 1
            BEGIN
               SET @n_ShelfLife = CONVERT(INT, @c_SUSR2)
            END
            SET @d_today = CONVERT(NVARCHAR(10), GETDATE(),120)
         END
         --(Wan03) - END

         DECLARE CUR_REPL CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOT
               ,LOTxLOCxID.Loc
               ,LOTxLOCxID.ID
               ,LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen  -- (ang01)  --NJOW01
               ,LOTxLOCxID.QtyAllocated
               ,LOTxLOCxID.QtyPicked
               ,LOTATTRIBUTE.Lottable02
         FROM LOT          WITH (NOLOCK)
         JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.Lot        = LOTATTRIBUTE.LOT)
         JOIN LOTxLOCxID   WITH (NOLOCK) ON (LOT.Lot        = LOTxLOCxID.Lot)
         JOIN LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
         WHERE LOTxLOCxID.LOC <> @c_CurrentLoc
         AND LOTxLOCxID.StorerKey = @c_CurrentStorer
         AND LOTxLOCxID.SKU = @c_CurrentSku
         --AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen > 0 --NJOW01   --(Wan02)
         AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen >= @n_FilterQty  --(Wan02)
         AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demand
         AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
         --AND LOC.LocationType NOT IN (CASE WHEN @c_ReplGrp = 'CASE' THEN @c_ReplGrp ELSE 'PALLET' END
         --                           ,'CASE'
         --                           ,'PICK')
         AND LOC.LocationType NOT IN (CASE WHEN @c_ReplGrp = 'CASE' THEN '' ELSE 'PALLET' END   --NJOW02
                                    , CASE WHEN @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y' THEN '' ELSE 'CASE' END --NJOW02
                                    ,'PICK')
         AND LOC.LocationType = CASE WHEN @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y' THEN 'CASE' ELSE LOC.LocationType END --NJOW02
         AND LOC.Status     <> 'HOLD'
         AND LOC.Facility   = @c_Zone01
         AND(LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         OR  @c_zone02 = 'ALL')
         AND LOT.Status     = 'OK'
         AND LOTATTRIBUTE.Lottable02= CASE WHEN @c_NoMixLottable02 = '1' AND @n_InvCnt > 0 THEN @c_Lottable02 ELSE LOTATTRIBUTE.Lottable02 END
         AND ( @c_ReplFreshStock = 'N' OR                                                                --(Wan03)
              (@c_ReplFreshStock = 'Y' AND LOTATTRIBUTE.Lottable04 > DATEADD(d, @n_shelfLife, @d_today)))--(Wan03)
         ORDER BY --CASE WHEN LOC.LocationType = 'CASE'   THEN 1
                  --     WHEN LOC.LocationType = 'PALLET' THEN 2
                  --     ELSE 3
                  --     END
                  ISNULL(LOTATTRIBUTE.LOTTABLE04, '1900-01-01')  --NJOW01
               ,  ISNULL(LOTATTRIBUTE.LOTTABLE05, '1900-01-01')
               ,  CASE WHEN (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) < @n_Pallet THEN 1 --NJOW01
                       ELSE 2
                       END
               ,  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked)
               ,  LOTxLOCxID.LOT
               ,  LOTxLOCxID.ID
         OPEN CUR_REPL

         FETCH NEXT FROM CUR_REPL INTO @c_FromLot
                                    ,  @c_FromLoc
                                    ,  @c_FromID
                                    ,  @n_FromQty
                                    ,  @n_QtyAllocated
                                    ,  @n_QtyPicked
                                    ,  @c_ReplLottable02

         WHILE @@Fetch_Status <> -1 AND @n_RemainingQty > 0
         BEGIN

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
                  IF @c_CaseToPick = 'Y'  --NJOW02
                  BEGIN
                     IF CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt > @n_FromQty
                        SET @n_FromQty = FLOOR(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt
                     ELSE
                        SET @n_FromQty = CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt
                  END
                  ELSE
                  -- (Wan02) - START
                  --   SET @n_FromQty = 0
                  BEGIN
                     IF @c_ReplFullPallet = 'Y'
                     BEGIN
                        IF @n_RemainingQty >= @n_Pallet
                        BEGIN
                           SET @n_FromQty = FLOOR(@n_RemainingQty/@n_Pallet) * @n_Pallet
                        END
                        ELSE
                        BEGIN
                           SET @n_FromQty = 0
                        END
                     END
                     ELSE
                     BEGIN
                        SET @n_FromQty = 0
                     END
                  END
                  -- (Wan02) - END
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
            ELSE IF @c_ToLocationType = 'PICK' AND  @c_CaseToPick = 'Y'  --NJOW02
            BEGIN
               IF @n_FromQty > @n_RemainingQty
                  IF CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt > @n_FromQty
                     SET @n_FromQty = FLOOR(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt
                  ELSE
                     SET @n_FromQty = CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt
               ELSE
                  SET @n_FromQty = FLOOR(@n_FromQty/@n_CaseCnt) * @n_CaseCnt
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
                     ,  ReplLottable02
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
                     ,  @c_ReplLottable02
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
                                       ,  @c_ReplLottable02
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
                                                 ,  @c_CaseToPick --NJOW02
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
            ,  RefNo  --NJOW01

            )
               VALUES (
               @c_ReplenishmentGroup  --@c_ReplGrp  NJOW01
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
            , 'PC23'  --NJOW01
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

   IF @c_backendjob <> 'Y' --NJOW01
   BEGIN
      --(Wan01) - START
      IF @c_FuncType IN ( 'G' )
      BEGIN
         RETURN
      END
      --(Wan01) - END

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
            ,CASE WHEN ISNULL(CLR.Code,'') = '' THEN
               LOC.PutawayZone ELSE '' END AS Putawayzone --NJOW02
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
            ,CASE WHEN ISNULL(CLR.Code,'') <> '' THEN
               FRLOC.LocationGroup ELSE '' END AS LocationGroup --NJOW02
            ,CASE WHEN ISNULL(CLR.Code,'') <> '' THEN
                CASE WHEN LOC.LocationType = 'CASE' THEN 'Pick-Case'
                     wHEN LOC.LocationType = 'PICK' THEN 'Pick-Piece'
                     ELSE LOC.LocationType END
             ELSE '' END AS LocationType --NJOW02
      FROM  REPLENISHMENT R WITH (NOLOCK)
      JOIN  SKU             WITH (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)
      JOIN  LOC             WITH (NOLOCK) ON (LOC.Loc = R.ToLoc)
      JOIN  LOC FRLOC       WITH (NOLOCK) ON (R.FromLoc = FRLOC.Loc) --NJOW02
      JOIN  PACK            WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      JOIN  LOTATTRIBUTE LA  WITH (NOLOCK) ON (R.Lot = LA.Lot)
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (R.Storerkey = CLR.Storerkey AND CLR.Code = 'REPLCASETOPICK'
                                            AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_replenishment_report_pc18' AND ISNULL(CLR.Short,'') <> 'N')   --NJOW02
      WHERE R.ReplenishmentGroup = @c_ReplenishmentGroup --@c_ReplGrp NJOW01
      AND  (LOC.PickZone = @c_ReplGrp OR @c_ReplGrp = 'ALL')
      AND   LOC.facility = @c_zone01
      AND  (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')
      AND  (LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
      OR  @c_zone02 = 'ALL')
      AND R.Confirmed = 'N'
      ORDER BY CASE WHEN ISNULL(CLR.Code,'') <> '' THEN
               FRLOC.LocationGroup ELSE LOC.PutawayZone END  --NJOW02
            ,  CASE WHEN ISNULL(CLR.Code,'') <> '' THEN
                    LOC.LocationType ELSE '' END  --NJOW02
            ,  FRLOC.LogicalLocation --NJOW02
            ,  R.FromLoc
            ,  R.Id
            ,  LA.Lottable02
            ,  R.Sku
   END

END

GO
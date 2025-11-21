SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ReplenishmentRpt_PC34                             */
/* Creation Date:  01-Jun-2021                                             */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-17098 - PH_PH02_ReplenishmentReport_Modification           */
/*        : modify from isp_ReplenishmentRpt_PC18                          */
/*                                                                         */
/* Called By: r_replenishment_report_pc34                                  */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 01-Jun-2021  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/

CREATE PROC [dbo].[isp_ReplenishmentRpt_PC34]
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
,              @c_Functype         NCHAR(1) = ''    
,              @c_backendjob       NVARCHAR(10) = 'N'
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
   DECLARE @b_debug               INT
         , @b_Success             INT
         , @n_Err                 INT
         , @c_ErrMsg              NVARCHAR(255)
         , @c_Sql                 NVARCHAR(4000)
         , @c_OrderBy             NVARCHAR(4000)
                                  
         , @c_Packkey             NVARCHAR(10)
         , @c_UOM                 NVARCHAR(10)
         , @c_ToLocationType      NVARCHAR(10)
         , @n_CaseCnt             FLOAT
         , @n_Pallet              FLOAT
         , @c_ReplenishmentGroup  NVARCHAR(10)  

   DECLARE @c_priority            NVARCHAR(5)
         , @c_ReplLottable01      NVARCHAR(18) 
         , @c_ReplLottable02      NVARCHAR(18)
         , @c_ReplLottable03      NVARCHAR(18)

   SET @n_continue=1
   SET @b_debug = 0

   IF @c_zone12 = '1'
   BEGIN
      SET @b_debug = CAST( @c_zone12 AS int)
      SET @c_zone12 = ''
   END
   
   IF RTRIM(@c_ReplGrp) = '' 
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END

   IF @c_FuncType IN ( 'P' )                                     
   BEGIN
      GOTO QUIT_SP    
   END

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
         ,ReplLottable01  = @c_ReplLottable01  
         ,ReplLottable02  = @c_ReplLottable02
         ,ReplLottable03  = @c_ReplLottable03  
   INTO #REPLENISHMENT
   FROM LOTXLOCXID (NOLOCK)
   WHERE 1 = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @n_InvCnt                      INT
            , @n_InvCnt1                     INT 
            , @n_InvCnt3                     INT 
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
            , @c_NoMixLottable01             NVARCHAR(10) 
            , @c_Lottable01                  NVARCHAR(18) 
            , @c_NoMixLottable03             NVARCHAR(10) 
            , @c_Lottable03                  NVARCHAR(18) 

      SET @c_CurrentStorer    = ''
      SET @c_CurrentSKU       = ''
      SET @c_CurrentLoc       = ''
      SET @c_CurrentPriority  = ''
      SET @n_currentfullcase  = 0
      SET @n_CurrentSeverity  = 9999999
      SET @n_FromQty          = 0
      SET @n_RemainingQty     = 0
      SET @n_numberofrecs     = 0
      SET @c_ReplenishmentGroup = '' 
      SET @c_NoMixLottable01  = '0'  
      SET @c_Lottable01       = ''   
      SET @c_NoMixLottable02  = '0'
      SET @c_Lottable02       = ''
      SET @c_NoMixLottable03  = '0'  
      SET @c_Lottable03       = ''   

      SELECT @c_OrderBy = ISNULL(CL.Notes,'')
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'REPORTCFG'
      AND CL.Storerkey = @c_Storerkey
      AND CL.Code = 'SortingOrder'
      AND CL.Long = 'r_replenishment_report_pc34'

      IF ISNULL(@c_OrderBy,'') = ''
      BEGIN
         SET @c_OrderBy = N'ORDER BY LOC.LocAisle, REPLENISHMENT.FromLoc, REPLENISHMENT.ID, LOTATTRIBUTE.Lottable04, REPLENISHMENT.SKU'
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
            ,ReplenishmentSeverity = ISNULL(SKUxLOC.QtyLocationLimit,0) - ISNULL(SUM((LOTXLOCXID.Qty - LOTXLOCXID.QtyPicked) + LOTXLOCXID.PendingMoveIN),0)  
            ,ISNULL(SKUxLOC.StorerKey,'')  
            ,ISNULL(SKUxLOC.SKU, '')  
            ,ISNULL(SKUxLOC.LOC,'')  
            ,ISNULL(SKUxLOC.QtyLocationLimit,0)  
            ,ISNULL(LOC.Locationtype,'')
      FROM SKUxLOC    WITH (NOLOCK)
      JOIN LOC        WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)
      LEFT JOIN LOTXLOCXID WITH (NOLOCK) ON (SKUxLOC.Storerkey = LOTXLOCXID.Storerkey AND SKUxLOC.Sku = LOTXLOCXID.Sku AND SKUxLOC.Loc = LOTXLOCXID.Loc)
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
      HAVING  ISNULL(SKUxLOC.Qty,0)- ISNULL(SKUxLOC.QtyPicked,0) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) <= ISNULL(SKUxLOC.QtyLocationMinimum,0)            
      --HAVING SKUxLOC.QtyLocationLimit - ISNULL(SUM((LOTXLOCXID.Qty - LOTXLOCXID.QtyPicked) + LOTXLOCXID.PendingMoveIN),0) <= SKUxLOC.QtyLocationMinimum             
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
         AND LLI.Qty - LLI.QtyPicked > 0

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
         AND LLI.Qty - LLI.QtyPicked > 0       

         DECLARE CUR_REPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOT
               ,LOTxLOCxID.Loc
               ,LOTxLOCxID.ID
               ,LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen
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
         AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen > 0 
         AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demand
         AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
         AND LOC.LocationType NOT IN (CASE WHEN @c_ReplGrp = 'CASE' THEN @c_ReplGrp ELSE 'PALLET' END
                                    ,'CASE'
                                    ,'PICK')
         AND LOC.Status     <> 'HOLD'
         AND LOC.Facility   = @c_Zone01
         AND(LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         OR  @c_zone02 = 'ALL')
         AND LOT.Status     = 'OK'
         AND LOTATTRIBUTE.Lottable01= CASE WHEN @c_NoMixLottable01 = '1' AND @n_InvCnt1 > 0 THEN @c_Lottable01 ELSE LOTATTRIBUTE.Lottable01 END 
         AND LOTATTRIBUTE.Lottable02= CASE WHEN @c_NoMixLottable02 = '1' AND @n_InvCnt > 0 THEN @c_Lottable02 ELSE LOTATTRIBUTE.Lottable02 END
         AND LOTATTRIBUTE.Lottable03= CASE WHEN @c_NoMixLottable03 = '1' AND @n_InvCnt3 > 0 THEN @c_Lottable03 ELSE LOTATTRIBUTE.Lottable03 END 
         AND LOC.LocationType NOT IN('DAMAGE')
         AND LOC.LocationCategory NOT IN ('BL','QI')
         AND LOTATTRIBUTE.Lottable01 NOT IN ('BL','QI')
         ORDER BY --CASE WHEN LOC.LocationType = 'CASE'   THEN 1
                  --     WHEN LOC.LocationType = 'PALLET' THEN 2
                  --     ELSE 3
                  --     END
                  ISNULL(LOTATTRIBUTE.LOTTABLE04, '1900-01-01') 
               ,  ISNULL(LOTATTRIBUTE.LOTTABLE05, '1900-01-01')
               ,  CASE WHEN (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) < @n_Pallet THEN 1
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
         ,  @b_success           OUTPUT
         ,  @n_err               OUTPUT
         ,  @c_errmsg            OUTPUT

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
            ,  RefNo 
            )
               VALUES (                               
               @c_ReplenishmentGroup
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
            ,  'PC34'
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

   IF @c_backendjob <> 'Y'
   BEGIN
      IF @c_FuncType IN ( 'G' )                                     
      BEGIN
         RETURN
      END

      IF @c_FuncType IN ( 'P' )                                     
      BEGIN
         SET @c_ReplenishmentGroup = @c_ReplGrp 
      END
      
      SET @c_Sql = N'SELECT  REPLENISHMENT.FromLoc '
                 +  '       ,REPLENISHMENT.Id '
                 +  '       ,REPLENISHMENT.ToLoc '
                 +  '       ,REPLENISHMENT.Sku '
                 +  '       ,REPLENISHMENT.Qty '
                 +  '       ,REPLENISHMENT.StorerKey '
                 +  '       ,REPLENISHMENT.Lot '
                 +  '       ,REPLENISHMENT.PackKey '
                 +  '       ,SKU.Descr '
                 +  '       ,REPLENISHMENT.Priority '
                 +  '       ,LOC.PutawayZone '
                 +  '       ,PACK.CaseCnt '
                 +  '       ,PACK.Pallet '
                 +  '       ,NoOfCSInPL = CASE WHEN PACK.CaseCnt > 0 THEN PACK.Pallet / PACK.CaseCnt ELSE 0 END '
                 +  '       ,SuggestPL  = CASE WHEN PACK.Pallet  > 0 THEN FLOOR(REPLENISHMENT.Qty / PACK.Pallet) ELSE 0 END '
                 +  '       ,SuggestCS  = CASE WHEN PACK.CaseCnt > 0 THEN FLOOR((REPLENISHMENT.Qty % CONVERT(INT, PACK.Pallet)) / PACK.CaseCnt) ELSE 0 END '
                 +  '       ,TotalCS    = CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(REPLENISHMENT.Qty / PACK.CaseCnt) ELSE 0 END '
                 +  '       ,PACK.PackUOM1 '
                 +  '       ,PACK.PackUOM3 '
                 +  '       ,REPLENISHMENT.ReplenishmentKey '
                 +  '       ,LOTATTRIBUTE.Lottable02 '
                 +  '       ,LOC.LocAisle '
                 +  '       ,LOTATTRIBUTE.Lottable04 ' + CHAR(13)
                 +  ' FROM  REPLENISHMENT   WITH (NOLOCK) ' + CHAR(13)
                 +  ' JOIN  SKU             WITH (NOLOCK) ON (SKU.Sku = REPLENISHMENT.Sku AND  SKU.StorerKey = REPLENISHMENT.StorerKey) ' + CHAR(13)
                 +  ' JOIN  LOC             WITH (NOLOCK) ON (LOC.Loc = REPLENISHMENT.ToLoc) '  + CHAR(13)
                 +  ' JOIN  PACK            WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey) '  + CHAR(13)
                 +  ' JOIN LOTATTRIBUTE     WITH (NOLOCK) ON (REPLENISHMENT.Lot = LOTATTRIBUTE.Lot) ' + CHAR(13)
                 +  ' WHERE (REPLENISHMENT.Replenishmentgroup = @c_ReplenishmentGroup OR @c_ReplenishmentGroup = ''ALL'') '  + CHAR(13)
                 +  ' AND  (LOC.PickZone = @c_ReplGrp OR @c_ReplGrp = ''ALL'') '  + CHAR(13)
                 +  ' AND   LOC.facility = @c_zone01 '  + CHAR(13)
                 +  ' AND  (REPLENISHMENT.Storerkey = @c_Storerkey OR @c_Storerkey = ''ALL'') '  + CHAR(13)
                 +  ' AND  (LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12) '  + CHAR(13)
                 +  ' OR  @c_zone02 = ''ALL'') '  + CHAR(13)
                 +  ' AND REPLENISHMENT.Confirmed = ''N'' '  + CHAR(13)
                 +  RTRIM(ISNULL(@c_OrderBy,''))

      EXEC sp_executesql @c_SQL
         , N'@c_ReplenishmentGroup  NVARCHAR(10), 
             @c_ReplGrp             NVARCHAR(30), 
             @c_Storerkey           NVARCHAR(15), 
             @c_zone01 NVARCHAR(10), @c_zone02 NVARCHAR(10), @c_zone03 NVARCHAR(10),
             @c_zone04 NVARCHAR(10), @c_zone05 NVARCHAR(10), @c_zone06 NVARCHAR(10), 
             @c_zone07 NVARCHAR(10), @c_zone08 NVARCHAR(10), @c_zone09 NVARCHAR(10), 
             @c_zone10 NVARCHAR(10), @c_zone11 NVARCHAR(10), @c_zone12 NVARCHAR(10)'
         , @c_ReplenishmentGroup
         , @c_ReplGrp
         , @c_Storerkey
         , @c_zone01
         , @c_zone02
         , @c_zone03
         , @c_zone04
         , @c_zone05
         , @c_zone06
         , @c_zone07
         , @c_zone08
         , @c_zone09
         , @c_zone10
         , @c_zone11
         , @c_zone12

      IF @b_debug = 1
      BEGIN
         PRINT @c_Sql
      END

      --ORDER BY LOC.PutawayZone
      --      ,  R.FromLoc
      --      ,  R.Id
      --      ,  LA.Lottable02
      --      ,  R.Sku
   END
END

GO
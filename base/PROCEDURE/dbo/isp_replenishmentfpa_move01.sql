SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: isp_ReplenishmentFPA_Move01                           */
/* Creation Date:  27-AUG-2017                                             */
/* Copyright: LFL                                                          */
/* Written by:Wan                                                          */
/*                                                                         */
/* Purpose: WMS-10378 - [PH] Unilever Wave Replenishment                   */
/*        : modify from nsp_ReplenishmentRpt_PC23                          */
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
/* 31-Aug-2019  SHONG   1.1   Bug Fixing                                   */
/* 04-Sep-2019  SHONG   1.2   Bug Fixing 2                                 */
/* 15-Nov-2019  Leong   1.3   INC0934078 - Bug Fix.                        */
/* 23-Mar-2020  CSCHONG 1.4   WMS-12435 revised replen logic (CS01)        */
/* 04-Jun-2020  NJOW01  1.5   WMS-13603 Custom sorting by config           */
/***************************************************************************/

CREATE PROC [dbo].[isp_ReplenishmentFPA_Move01]
     @c_Key_Type  NVARCHAR(15)
   , @c_Functype  NCHAR(1) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt             INT            = @@TRANCOUNT
         , @n_Continue              INT            = 1
         , @b_Success               INT            = 1
         , @n_Err                   INT            = 0
         , @c_ErrMsg                NVARCHAR(255)  = ''
         , @b_debug                 INT            = 0

         , @c_Wavekey               NVARCHAR(10)   = ''
         , @c_Storerkey             NVARCHAR(15)   = ''
         , @c_Facility              NVARCHAR(5)    = ''
         , @c_ReplenishmentKey      NVARCHAR(10)   = ''
         , @c_ReplenishmentGroup    NVARCHAR(10)   = ''
         , @c_Priority              NVARCHAR(5)    = ''

         , @n_InvCnt                INT
         , @c_CurrentStorer         NVARCHAR(15)   = ''
         , @c_CurrentSKU            NVARCHAR(20)   = ''
         , @c_CurrentLoc            NVARCHAR(10)   = ''
         , @c_CurrentPriority       NVARCHAR(5)    = ''
         , @n_Currentfullcase       INT            = 0
         , @n_CurrentSeverity       INT            = 9999999
         , @c_FromLOC               NVARCHAR(10)   = ''
         , @c_Fromlot               NVARCHAR(10)   = ''
         , @c_FromID                NVARCHAR(18)   = ''
         , @c_ToID                  NVARCHAR(18)   = ''
         , @n_FromQty               INT            = 0
         , @n_QtyPreAllocated       INT            = 0
         , @n_QtyAllocated          INT            = 0
         , @n_QtyPicked             INT            = 0
         , @n_RemainingQty          INT            = 0

         , @c_NoMixLottable02       NVARCHAR(10)   = '0'
         , @c_ReplLottable02        NVARCHAR(18)   = ''

         , @c_ReplValidationRules   NVARCHAR(10)   = ''

         , @c_Packkey               NVARCHAR(10)   = ''
         , @c_UOM                   NVARCHAR(10)   = ''
         , @c_ToLocationType        NVARCHAR(10)   = ''
         , @n_CaseCnt               FLOAT          = 0.00
         , @n_Pallet                FLOAT          = 0.00

         , @n_FilterQty             INT            = 0
         , @c_ReplFullPallet        NVARCHAR(10)   = 'N'
         , @c_ReplAllPalletQty      NVARCHAR(10)   = 'N'
         , @c_CaseToPick            NVARCHAR(10)   = 'N'
         , @c_ReplOverFlow          NVARCHAR(10)   = 'Y'

         , @n_RowID                 INT            = 0
         , @CUR_REPEN               CURSOR

         , @n_MaxCapacity           INT            = 0
         , @n_QtyReplen             INT            = 0
         , @c_NextLOC               NVARCHAR(10)   = ''
         , @n_TotReplenQty          INT            = 0
         , @c_LottableName          NVARCHAR(30)   = ''  --(CS01)
         , @c_LottableValue         NVARCHAR(30)   = ''  --(CS01)
         , @c_SQL                   NVARCHAR(MAX)  = ''  --(CS01) 


   SET @c_Wavekey = LEFT(@c_Key_Type,10)

   IF @c_Functype = '1'
      SET @b_debug = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   BEGIN TRAN
   SELECT TOP 1 @c_Storerkey = OH.Storerkey
            ,   @c_Facility  = OH.Facility
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
   WHERE WD.Wavekey = @c_Wavekey

   IF @n_continue = 1
   BEGIN
      SET @c_ReplenishmentKey = ''
      SET @c_ReplFullPallet = 'N'
      SET @c_ReplAllPalletQty = 'N'
      SET @c_CaseToPick = 'N'
      SELECT @c_ReplFullPallet  = ISNULL(MAX(CASE WHEN CL.Code ='ReplFullPallet'   THEN 'Y' ELSE 'N' END),'N')
            ,@c_ReplAllPalletQty= ISNULL(MAX(CASE WHEN CL.Code ='ReplAllPalletQty' THEN 'Y' ELSE 'N' END),'N')
            ,@c_CaseToPick      = ISNULL(MAX(CASE WHEN CL.Code ='REPLCASETOPICK' THEN 'Y' ELSE 'N' END),'N')
      FROM CODELKUP CL WITH (NOLOCK)
      WHERE CL.ListName = 'REPORTCFG'
      AND CL.Long = 'r_Replenishment_fpa_move01'
      AND CL.Storerkey = @c_Storerkey
      AND CL.Short = 'Y'

      IF @c_ReplAllPalletQty = 'Y'
      BEGIN
         SET @c_ReplFullPallet = 'N'
      END

      IF OBJECT_ID('tempdb..#Replenishment','u') IS NOT NULL
      BEGIN
         DROP TABLE #Replenishment;
      END

      CREATE TABLE #Replenishment
         (     RowID                   INT   IDENTITY(1,1)  PRIMARY KEY
            ,  StorerKey               NVARCHAR(15)   NOT NULL DEFAULT('')
            ,  SKU                     NVARCHAR(20)   NOT NULL DEFAULT('')
            ,  FromLOC                 NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  ToLOC                   NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  Lot                     NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  ID                      NVARCHAR(18)   NOT NULL DEFAULT('')
            ,  LocationType            NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  Qty                     INT            NOT NULL DEFAULT(0)
            ,  QtyMoved                INT            NOT NULL DEFAULT(0)
            ,  QtyInPickLOC            INT            NOT NULL DEFAULT(0)
            ,  [Priority]              NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  UOM                     NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  Packkey                 NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  ReplLottable02          NVARCHAR(18)   NOT NULL DEFAULT('')
         )

      IF OBJECT_ID('tempdb..#TempSKUxLOC','u') IS NOT NULL
      BEGIN
         DROP TABLE #TempSKUxLOC;
      END

      CREATE TABLE #TempSKUxLOC
         (     RowID                   INT   IDENTITY(1,1)  PRIMARY KEY
            ,  StorerKey               NVARCHAR(15)   NOT NULL DEFAULT('')
            ,  SKU                     NVARCHAR(20)   NOT NULL DEFAULT('')
            ,  LOC                     NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  ReplenishmentPriority   NVARCHAR(5)    NOT NULL DEFAULT('')
            ,  ReplenishmentSeverity   INT            NOT NULL DEFAULT(0)
            ,  ReplenishmentCasecnt    INT            NOT NULL DEFAULT(0)
            ,  LocationType            NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  NoMixLottable02         NVARCHAR(1)    NOT NULL DEFAULT('')
            ,  Packkey                 NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  LOT                     NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  Selected                BIT            NOT NULL DEFAULT(0)
            ,  QtyReplen               INT            NOT NULL DEFAULT(0)
         )

      IF OBJECT_ID('tempdb..#PreAllocateSku','u') IS NOT NULL
      BEGIN
         DROP TABLE #PreAllocateSku;
      END

      CREATE TABLE #PreAllocateSku
         (     RowID                   INT   IDENTITY(1,1)  PRIMARY KEY
            ,  Wavekey                 NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  StorerKey               NVARCHAR(15)   NOT NULL DEFAULT('')
            ,  SKU                     NVARCHAR(20)   NOT NULL DEFAULT('')
            ,  Lot                     NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  UOM                     NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  Qty                     INT            NOT NULL DEFAULT(0)
         )

      IF OBJECT_ID('tempdb..#SkipSku','u') IS NOT NULL
      BEGIN
         DROP TABLE #SkipSku;
      END

      CREATE TABLE #SkipSku (SKU NVARCHAR(20))

      IF EXISTS(SELECT 1
                FROM CODELKUP CL (NOLOCK)
                WHERE CL.Listname = 'REPORTCFG'
                AND CL.Code = 'UNISORT'
                AND CL.Long = 'r_replenishment_fpa_move01'
                AND CL.Storerkey = @c_CurrentStorer
                AND ISNULL(CL.Short,'') <> 'N') --NJOW01        
      BEGIN
         INSERT INTO #PreAllocateSku
            (     Wavekey
               ,  StorerKey
               ,  SKU
               ,  Lot
             --,  UOM -- INC0934078
               ,  Qty
            )
         SELECT
               @c_Wavekey
            ,  PAL.Storerkey
            ,  PAL.Sku
            ,  PAL.Lot
          --,  PAL.UOM -- INC0934078
            ,  ISNULL(SUM(PAL.Qty),0)
         FROM PREALLOCATEPICKDETAIL PAL WITH (NOLOCK)
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON PAL.Lot = LA.Lot
         OUTER APPLY (SELECT MIN(L.LogicalLocation) AS LogicalLocation, MIN(L.Loc) AS Loc 
                      FROM LOTXLOCXID LLI (NOLOCK) 
                      JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey 	AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
                      JOIN LOC L (NOLOCK) ON LLI.Loc = L.Loc
                      WHERE PAL.Lot = LLI.Lot
                      AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen > 0
                      AND SL.LOCationtype NOT IN ( 'CASE','PALLET','PICK')) AS IL
         WHERE EXISTS ( SELECT 1
                        FROM WAVEDETAIL WD WITH (NOLOCK)
                        JOIN PREALLOCATEPICKDETAIL P WITH (NOLOCK) ON WD.Orderkey = P.Orderkey
                        WHERE WD.Wavekey = @c_Wavekey
                        --AND   P.UOM = '2'
                        AND   P.Qty > 0
                        AND   PAL.Storerkey = P.Storerkey
                        AND   PAL.Sku = P.Sku
                        AND   PAL.Lot = P.Lot
                      )
         AND PAL.Storerkey = @c_Storerkey
         --AND   PAL.UOM = '2'
         AND   PAL.Qty > 0
         GROUP BY PAL.Storerkey
               ,  PAL.Sku
               ,  PAL.Lot
               ,  LA.LOTTABLE04
               ,  LA.LOTTABLE02
               ,  CASE WHEN LA.LOTTABLE04 IS NULL OR LA.LOTTABLE04 = '1900-01-01' THEN LA.LOTTABLE05 ELSE NULL END               
               ,  ISNULL(IL.LogicalLocation,'')
               ,  ISNULL(IL.Loc,'')               
         ORDER BY PAL.Storerkey
               ,  PAL.Sku
               ,  LA.LOTTABLE04
               ,  LA.LOTTABLE02 
               ,  CASE WHEN LA.LOTTABLE04 IS NULL OR LA.LOTTABLE04 = '1900-01-01' THEN LA.LOTTABLE05 ELSE NULL END               
               ,  ISNULL(IL.LogicalLocation,'')
               ,  ISNULL(IL.Loc,'')
               ,  PAL.Lot
             --,  PAL.UOM -- INC0934078      	
      END
      ELSE          
      BEGIN                                 
         INSERT INTO #PreAllocateSku
            (     Wavekey
               ,  StorerKey
               ,  SKU
               ,  Lot
             --,  UOM -- INC0934078
               ,  Qty
            )
         SELECT
               @c_Wavekey
            ,  PAL.Storerkey
            ,  PAL.Sku
            ,  PAL.Lot
          --,  PAL.UOM -- INC0934078
            ,  ISNULL(SUM(PAL.Qty),0)
         FROM PREALLOCATEPICKDETAIL PAL WITH (NOLOCK)
         WHERE EXISTS ( SELECT 1
                        FROM WAVEDETAIL WD WITH (NOLOCK)
                        JOIN PREALLOCATEPICKDETAIL P WITH (NOLOCK) ON WD.Orderkey = P.Orderkey
                        WHERE WD.Wavekey = @c_Wavekey
                        --AND   P.UOM = '2'
                        AND   P.Qty > 0
                        AND   PAL.Storerkey = P.Storerkey
                        AND   PAL.Sku = P.Sku
                        AND   PAL.Lot = P.Lot
                      )
         AND PAL.Storerkey = @c_Storerkey
         --AND   PAL.UOM = '2'
         AND   PAL.Qty > 0
         GROUP BY PAL.Storerkey
               ,  PAL.Sku
               ,  PAL.Lot
             --,  PAL.UOM -- INC0934078
      END       

      -- Do not replenish where replen qty enought for pre-allocate
      DECLARE @c_RowID INT

      DECLARE CUR_CHECK_PREALLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowID, Lot, Qty, SKU
      FROM #PreAllocateSku

      OPEN CUR_CHECK_PREALLOC
      FETCH FROM CUR_CHECK_PREALLOC INTO @c_RowID, @c_Fromlot, @n_QtyPreAllocated, @c_CurrentSKU
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @n_TotReplenQty = 0

         SELECT @n_TotReplenQty = ISNULL(SUM(Qty),0)
         FROM Replenishment AS r WITH(NOLOCK)
         WHERE r.Lot = @c_Fromlot
         AND r.Confirmed = 'N'
         AND r.Wavekey IS NOT NULL

         IF @n_TotReplenQty >= @n_QtyPreAllocated
         BEGIN
            IF @b_debug = 1
            BEGIN
               PRINT '>>> LOT ' + @c_Fromlot + ' with sufficient qty, ignore this lot. SKU:' + @c_CurrentSKU
            END

            DELETE FROM #PreAllocateSku
            WHERE Lot = @c_Fromlot
         END
         ELSE
         BEGIN
            IF @b_debug = 1
            BEGIN
               PRINT '>>> LOT ' + @c_Fromlot + ' Required: ' + CAST(@n_QtyPreAllocated AS VARCHAR(10))
                   + ' Replen Qty: ' + CAST(@n_TotReplenQty AS VARCHAR(10)) + ' . SKU:' +  @c_CurrentSKU
            END

            SET @n_QtyPreAllocated = @n_QtyPreAllocated - @n_TotReplenQty

            UPDATE #PreAllocateSku
               SET Qty = @n_QtyPreAllocated -- INC0934078
             WHERE RowId = @c_RowID
               AND Lot = @c_Fromlot
         END
         FETCH FROM CUR_CHECK_PREALLOC INTO @c_RowID, @c_Fromlot, @n_QtyPreAllocated, @c_CurrentSKU
      END
      CLOSE CUR_CHECK_PREALLOC
      DEALLOCATE CUR_CHECK_PREALLOC

      INSERT INTO #TempSKUxLOC
         (     StorerKey
            ,  SKU
            ,  LOC
            ,  ReplenishmentPriority
            ,  ReplenishmentSeverity
            ,  ReplenishmentCasecnt
            ,  LocationType
            ,  NoMixLottable02
            ,  Packkey
            ,  LOT
            ,  Selected
            ,  QtyReplen
            )
      SELECT SKUxLOC.StorerKey
         ,  SKUxLOC.SKU
         ,  SKUxLOC.LOC
         ,  SKUxLOC.ReplenishmentPriority
         ,  ReplenishmentSeverity = PAL.Qty - ((SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) + ISNULL(SUM(RP.Qty),0))
         ,  SKUxLOC.QtyLocationLimit
         ,  LOC.Locationtype
         ,  NoMixLottable02 = ISNULL(RTRIM(NoMixLottable02),'0')
         ,  SKU.Packkey
         ,  PAL.LOT
         ,  0
         ,  SUM(ISNULL(LOTXLOCXID.QtyReplen,0))
      FROM #PreAllocateSku PAL
      JOIN SKUxLOC            WITH (NOLOCK) ON (PAL.Storerkey = SKUxLOC.Storerkey AND PAL.Sku = SKUxLOC.Sku)
      JOIN LOC                WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)
      JOIN SKU                WITH (NOLOCK) ON (SKUxLOC.Storerkey = SKU.Storerkey AND SKUxLOC.Sku = SKU.Sku)
      LEFT JOIN LOTXLOCXID    WITH (NOLOCK) ON (SKUxLOC.Storerkey = LOTXLOCXID.Storerkey AND SKUxLOC.Sku = LOTXLOCXID.Sku AND SKUxLOC.Loc = LOTXLOCXID.Loc)
      LEFT JOIN Replenishment RP WITH (NOLOCK) ON (SKUxLOC.Storerkey = RP.Storerkey AND SKUxLOC.Sku = RP.Sku AND SKUxLOC.Loc = RP.ToLoc)
                                              AND (RP.Confirmed = 'N')
                                              AND (RP.Wavekey <> '' and RP.Wavekey IS NOT NULL)
      WHERE SKUxLOC.LOCationtype IN ( 'CASE','PALLET','PICK')
      AND   LOC.FACILITY = @c_Facility
      AND   LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
      AND   LOC.Status <> 'HOLD'
      GROUP BY SKUxLOC.ReplenishmentPriority
            ,  SKUxLOC.StorerKey
            ,  SKUxLOC.SKU
            ,  SKUxLOC.LOC
            ,  SKUxLOC.Qty
            ,  SKUxLOC.QtyPicked
            ,  SKUxLOC.QtyAllocated
            ,  SKUxLOC.QtyLocationLimit
            ,  LOC.Locationtype
            ,  ISNULL(RTRIM(NoMixLottable02),'0')
            ,  SKU.Packkey
            ,  PAL.Lot
            ,  PAL.Qty
      HAVING  PAL.Qty - ((SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) + ISNULL(SUM(RP.Qty),0)) > 0
      ORDER BY SKUxLOC.StorerKey
            ,  SKUxLOC.SKU
            ,  SKUxLOC.LOC

      IF @@ROWCOUNT > 0
      BEGIN
         EXECUTE nspg_GetKey
            'REPLENGROUP',
            9,
            @c_ReplenishmentGroup OUTPUT,
            @b_success OUTPUT,
            @n_err OUTPUT,
            @c_errmsg OUTPUT

         IF @b_success = 1
            SET @c_ReplenishmentGroup = 'T' + @c_ReplenishmentGroup
         END


      IF @b_debug = 1
      BEGIN
         SELECT SKUxLOC.StorerKey
            ,  SKUxLOC.SKU
            ,  SKUxLOC.LOC
            ,  SKUxLOC.ReplenishmentPriority
            ,  ReplenishmentSeverity = PAL.Qty - ((SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) + ISNULL(SUM(RP.Qty),0))
            ,  SKUxLOC.QtyLocationLimit
            ,  LOC.Locationtype
            ,  NoMixLottable02 = ISNULL(RTRIM(NoMixLottable02),'0')
            ,  SKU.Packkey
            ,  PAL.LOT
            , (SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) QtyAvailable
            ,  SUM(ISNULL(LOTXLOCXID.QtyReplen,0)) 'QtyReplen'
            ,  ISNULL(SUM(RP.Qty),0) GenReplenQty
            ,  PAL.Qty PreAllocateQty
         FROM #PreAllocateSku PAL
         JOIN SKUxLOC            WITH (NOLOCK) ON (PAL.Storerkey = SKUxLOC.Storerkey AND PAL.Sku = SKUxLOC.Sku)
         JOIN LOC                WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)
         JOIN SKU                WITH (NOLOCK) ON (SKUxLOC.Storerkey = SKU.Storerkey AND SKUxLOC.Sku = SKU.Sku)
         LEFT JOIN LOTXLOCXID    WITH (NOLOCK) ON (SKUxLOC.Storerkey = LOTXLOCXID.Storerkey AND SKUxLOC.Sku = LOTXLOCXID.Sku AND SKUxLOC.Loc = LOTXLOCXID.Loc)
         LEFT JOIN Replenishment RP WITH (NOLOCK) ON (SKUxLOC.Storerkey = RP.Storerkey AND SKUxLOC.Sku = RP.Sku AND SKUxLOC.Loc = RP.ToLoc)
                                                 AND (RP.Confirmed = 'N')
                                                 AND (RP.Wavekey <> '' and RP.Wavekey IS NOT NULL)
         WHERE SKUxLOC.LOCationtype IN ( 'CASE','PALLET','PICK')
         AND   LOC.FACILITY = @c_Facility
         AND   LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
         AND   LOC.Status <> 'HOLD'
         GROUP BY SKUxLOC.ReplenishmentPriority
               ,  SKUxLOC.StorerKey
               ,  SKUxLOC.SKU
               ,  SKUxLOC.LOC
               ,  SKUxLOC.Qty
               ,  SKUxLOC.QtyPicked
               ,  SKUxLOC.QtyAllocated
               ,  SKUxLOC.QtyLocationLimit
               ,  LOC.Locationtype
               ,  ISNULL(RTRIM(NoMixLottable02),'0')
               ,  SKU.Packkey
               ,  PAL.Lot
               ,  PAL.Qty
         ORDER BY SKUxLOC.StorerKey
               ,  SKUxLOC.SKU
               ,  SKUxLOC.LOC

         PRINT '>>>>>> #TempSKUxLOC'
         SELECT * FROM #TempSKUxLOC

         PRINT '>>>>> #PreAllocateSku'
         SELECT * FROM #PreAllocateSku
      END

      /* Loop through SKUxLOC for the currentSKU, current storer */
      /* to pickup the next severity */
      -- (SWT01)
      DECLARE CUR_SKUxLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT CurrentStorer = StorerKey
            ,CurrentSKU = SKU
            ,CurrentLoc = LOC
            ,CurrentSeverity        = ISNULL(SUM(ReplenishmentSeverity),0)
            ,ReplenishmentPriority  = ReplenishmentPriority
            ,ToLocationType         = LocationType
            ,Packkey          = Packkey
            ,NoMixLottable02  = NoMixLottable02
      FROM #TempSKUxLOC
      GROUP BY StorerKey
            ,  SKU
            ,  LOC
            ,  ReplenishmentPriority
            ,  LocationType
            ,  Packkey
            ,  NoMixLottable02
      ORDER BY StorerKey
              ,Sku
              ,ReplenishmentPriority
              ,Loc

      OPEN CUR_SKUxLOC

      FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentStorer
                                    ,  @c_CurrentSKU
                                    ,  @c_CurrentLoc
                                    ,  @n_CurrentSeverity
                                    ,  @c_CurrentPriority
                                    ,  @c_ToLocationType
                                    ,  @c_Packkey
                                    ,  @c_NoMixLottable02
      WHILE @@Fetch_Status <> -1
      BEGIN
         IF EXISTS(SELECT 1 FROM #SkipSKU WHERE SKU = @c_CurrentSKU)
         BEGIN
            GOTO NEXT_SKUxLOC
         END
         /* We now have a pickLOCation that needs to be replenished! */
         /* Figure out which LOCations in the warehouse to pull this product from */
         /* End figure out which LOCations in the warehouse to pull this product from */
         SET @c_FromLOC = ''
         SET @c_FromLot = ''
         SET @c_FromID  = ''
         SET @n_FromQty = 0
         SET @c_ToID    = ''

         SET @n_RemainingQty  = @n_CurrentSeverity

         SET @n_Pallet = 0.00
         SET @n_CaseCnt = 0.00
         SELECT @n_Pallet = ISNULL(Pallet,0)
               ,@n_CaseCnt= ISNULL(CaseCnt,0)
               ,@c_UOM    = P.PackUOM3
         FROM PACK P WITH (NOLOCK)
         WHERE P.Packkey = @c_Packkey

         IF @c_ToLocationType = 'PALLET' AND @n_Pallet = 0
         BEGIN
          IF @b_debug = 1
             PRINT '<<< To Loc Type = Pallet by Pack.Pallet = 0 '

            GOTO NEXT_SKUxLOC
         END

         IF @c_ToLocationType = 'CASE' AND @n_CaseCnt = 0
         BEGIN
          IF @b_debug = 1
             PRINT '<<< To Loc Type = CASE by Pack.CaseCnt = 0 '

            GOTO NEXT_SKUxLOC
         END

         IF @c_NoMixLottable02 = ''
         BEGIN
            SET @c_NoMixLottable02 = '0'
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

         SET @n_RowID = 0
         WHILE 1 = 1 AND (@n_RemainingQty > 0 OR @c_ReplOverflow = 'Y')
         BEGIN
            SET @c_FromLot = ''
            SELECT TOP 1 @n_RowID = PAL.RowID
                     , @c_FromLot = PAL.Lot
                     , @n_QtyPreAllocated = PAL.Qty
            FROM #PreAllocateSku PAL
            WHERE PAL.Storerkey = @c_CurrentStorer
            AND   PAL.Sku = @c_CurrentSku
            AND   PAL.RowID > @n_RowID
            ORDER BY RowID

            IF @@ROWCOUNT = 0 OR @c_FromLot = ''
            BEGIN
               BREAK
            END

            IF @c_ReplOverflow = 'Y' AND @n_RemainingQty <= 0
            BEGIN
               SET @n_RemainingQty = @n_QtyPreAllocated
            END

            IF @b_debug = 1
            BEGIN
               PRINT '>>> FromLot: ' + @c_FromLot + ' Qty PreAllocated: ' + CAST(@n_QtyPreAllocated AS VARCHAR)
               PRINT '>>> CaseToPick: ' + @c_CaseToPick + ' ToLocationType: ' + @c_ToLocationType
            END

            IF EXISTS(SELECT 1
                      FROM CODELKUP CL (NOLOCK)
                      WHERE CL.Listname = 'REPORTCFG'
                      AND CL.Code = 'UNISORT'
                      AND CL.Long = 'r_replenishment_fpa_move01'
                      AND CL.Storerkey = @c_CurrentStorer
                      AND ISNULL(CL.Short,'') <> 'N') --NJOW01        
            BEGIN                             
               DECLARE CUR_REPL CURSOR FAST_FORWARD READ_ONLY FOR
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
               AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen >= 1
               AND LOTxLOCxID.QtyExpected = 0
               AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
               AND LOC.LocationType NOT IN ('CASE','PICK')
               --AND LOC.LocationType NOT IN ('PALLET'
                                          --, CASE WHEN @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y' THEN '' ELSE 'CASE' END
                                          --,'PICK')
               --AND LOC.LocationType = CASE WHEN @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y' THEN 'CASE' ELSE LOC.LocationType END
               AND LOC.Facility= @c_Facility
               AND LOC.Status  <>'HOLD'
               AND LOT.Status  = 'OK'
               AND LOT.Lot     = @c_FromLot
               --AND LOTxLOCxID.QtyAllocated = 0
               ORDER BY
                     LOC.LogicalLocation,
                     LOC.Loc,
                     CASE WHEN (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) < @n_Pallet
                              THEN 1
                              ELSE 2
                              END
                     ,  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked)
                     ,  LOTxLOCxID.LOT
                     ,  LOTxLOCxID.ID
            END
            ELSE
            BEGIN
               DECLARE CUR_REPL CURSOR FAST_FORWARD READ_ONLY FOR
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
               AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen >= 1
               AND LOTxLOCxID.QtyExpected = 0
               AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
               AND LOC.LocationType NOT IN ('CASE','PICK')
               --AND LOC.LocationType NOT IN ('PALLET'
                                          --, CASE WHEN @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y' THEN '' ELSE 'CASE' END
                                          --,'PICK')
               --AND LOC.LocationType = CASE WHEN @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y' THEN 'CASE' ELSE LOC.LocationType END
               AND LOC.Facility= @c_Facility
               AND LOC.Status  <>'HOLD'
               AND LOT.Status  = 'OK'
               AND LOT.Lot     = @c_FromLot
               --AND LOTxLOCxID.QtyAllocated = 0
               ORDER BY CASE WHEN (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) < @n_Pallet
                              THEN 1
                              ELSE 2
                              END
                     ,  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked)
                     ,  LOTxLOCxID.LOT
                     ,  LOTxLOCxID.ID
            END

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
               IF EXISTS( SELECT 1 FROM #Replenishment AS r WITH(NOLOCK)
                        WHERE r.Lot = @c_Fromlot
                        AND   r.FromLOC = @c_FromLOC
                        AND   r.ID = @c_FromID)
               BEGIN
                  GOTO NEXT_CANDIDATE
               END

               IF @c_NoMixLottable02 = '1' AND @n_InvCnt = 0
               BEGIN
                  IF EXISTS ( SELECT 1 FROM #Replenishment
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

               SELECT @c_ReplValidationRules = SC.sValue
               FROM STORERCONFIG SC (NOLOCK)
               JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
               WHERE SC.StorerKey = @c_StorerKey
               AND SC.Configkey = 'ReplenValidation'

               IF ISNULL(@c_ReplValidationRules,'') <> ''
               BEGIN
                  EXEC isp_REPL_ExtendedValidation @c_fromlot = @c_fromlot
                                                ,  @c_FromLOC = @c_FromLOC
                                                ,  @c_FromID  = @c_FromID
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
                  IF @b_debug = 1
                  BEGIN
                     PRINT '>>> ToLocationType = PALLET'
                  END

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
                  IF @b_debug = 1
                  BEGIN
                     PRINT '>>> ToLocationType = CASE'
                  END

                  IF @c_ReplAllPalletQty = 'N'
                  BEGIN
                     IF @n_FromQty < @n_CaseCnt
                     BEGIN
                        GOTO NEXT_CANDIDATE
                     END
                  END

              --CS0- START
             SELECT @c_LottableName = ''
               SELECT TOP 1 @c_LottableName = Code
               FROM CODELKUP (NOLOCK)  
               WHERE Listname = 'REPLENLOT'  
               AND Storerkey = @c_StorerKey  
            --AND Short = 'Y'  
              ORDER BY Code  

     SET @c_LottableValue = ''
     IF ISNULL(@c_LottableName,'') <> ''
     BEGIN

     
    SET @c_SQL = N'SELECT TOP 1 @c_LottableValue = LA.' + RTRIM(LTRIM(@c_LottableName))  +  
           ' FROM LOTATTRIBUTE LA (NOLOCK)      
            WHERE LA.StorerKey = @c_Storerkey     
            AND LA.lot = @c_FromLot  '   
           -- AND LLI.Loc = @c_CurrentLoc''    
           
            EXEC sp_executesql @c_SQL,  
            N'@c_LottableValue NVARCHAR(30) OUTPUT, @c_Storerkey NVARCHAR(15), @c_FromLot NVARCHAR(20)',   
            @c_LottableValue OUTPUT,  
            @c_Storerkey,  
            @c_FromLot
    END
   --    print @c_SQL
   --select @c_SQL
   --select @c_Storerkey'@c_Storerkey', @c_FromLot '@c_FromLot',@c_LottableName '@c_LottableName',@c_LottableValue 'c_LottableValue'

   
       IF ISNULL(@c_LottableValue,'') <> ''   
         BEGIN  
              GOTO NEXT_CANDIDATE    
         END  

       --CS01 END

                  IF @n_FromQty > @n_RemainingQty
                  BEGIN
                     IF @c_CaseToPick = 'Y'
                     BEGIN
                        IF CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt > @n_FromQty
                           SET @n_FromQty = FLOOR(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt
                        ELSE
                           SET @n_FromQty = CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt
                     END
                     ELSE
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
                           IF @c_ReplAllPalletQty = 'N'
                           BEGIN
                              SET @n_FromQty = 0
                           END
                        END
                     END
                  END
                  ELSE
                  BEGIN
                     IF @c_ReplAllPalletQty = 'N'
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
               END
               ELSE IF @c_ToLocationType = 'PICK' AND  @c_CaseToPick = 'Y'
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     PRINT '>>> ToLocationType = PICK'
                  END

                  IF @n_FromQty > @n_RemainingQty
                     IF CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt > @n_FromQty
                        SET @n_FromQty = FLOOR(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt
                     ELSE
                        SET @n_FromQty = CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt
                  ELSE
                     SET @n_FromQty = FLOOR(@n_FromQty/@n_CaseCnt) * @n_CaseCnt
               END

               IF @n_FromQty > 0
               BEGIN
                  SELECT @n_MaxCapacity = 0,
                         @n_QtyReplen   = 0

                  SELECT @n_MaxCapacity = tsl.ReplenishmentCasecnt,
                         @n_QtyReplen   = SUM(tsl.QtyReplen)
                  FROM #TempSKUxLOC AS tsl WITH(NOLOCK)
                  WHERE StorerKey = @c_CurrentStorer
                  AND   SKU = @c_CurrentSKU
                  AND   LOC = @c_CurrentLoc
                  GROUP BY tsl.ReplenishmentCasecnt

                  IF @b_debug = 1
                  BEGIN
                     PRINT '>>> @c_CurrentLoc: ' + @c_CurrentLoc
                     PRINT '>>> @n_MaxCapacity: ' + CAST(@n_MaxCapacity AS VARCHAR) + ', @n_QtyReplen: ' + CAST(@n_QtyReplen AS VARCHAR)
                  END

                  IF (@n_QtyReplen + @n_FromQty > @n_MaxCapacity) AND (@n_QtyReplen > 0)
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        PRINT '>>> ' + CAST((@n_QtyReplen + @n_FromQty) AS VARCHAR) +
                              ' Exceeded MaxCapacity. Get Next Location '
                     END

                     -- SELECT Other Location can fit the qty
                     SET @c_NextLOC = ''
                     SELECT TOP 1
                            @c_NextLOC = ISNULL(tsl.LOC,'')
                     FROM #TempSKUxLOC AS tsl WITH(NOLOCK)
                     WHERE StorerKey = @c_CurrentStorer
                     AND   SKU = @c_CurrentSKU
                     AND   LOC <> @c_CurrentLoc
                     GROUP BY SKU, LOC
                     HAVING SUM(@n_QtyReplen) + @n_FromQty > @n_MaxCapacity
                     ORDER BY SUM(@n_QtyReplen), LOC

                     IF @b_debug = 1
                     BEGIN
                        PRINT '>>> @c_NextLOC: ' + @c_NextLOC
                     END

                     -- If found, suggest to replen to this location. Otherwise do nothing
                     IF @c_NextLOC <> ''
                        SET @c_CurrentLoc = @c_NextLOC
                  END
               END

               --SET @n_RemainingQty = @n_RemainingQty - @n_FromQty -- (SWT01)
               IF @n_FromQty > @n_RemainingQty
                  SET @n_RemainingQty = 0
               ELSE
                  SET @n_RemainingQty = @n_RemainingQty - @n_FromQty

               IF @n_FromQty > 0
               BEGIN
                  INSERT #Replenishment
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
                        ,  @c_FromID
                        ,  @n_FromQty
                        ,  @c_UOM
                        ,  @c_Packkey
                        ,  @c_CurrentPriority
                        ,  @n_QtyAllocated
                        ,  @n_QtyPicked
                        ,  @c_ReplLottable02
                        )
                  IF @b_debug = 1
                  BEGIN
                     SELECT 'INSERTED : ' as Title, @c_CurrentSKU ' SKU', @c_fromlot 'LOT',  @c_CurrentLoc 'LOC', @c_FromID 'ID',
                             @n_FromQty 'Qty'
                  END

                  UPDATE #TempSKUxLOC
                     SET SELECTED = 1, QtyReplen = QtyReplen + @n_FromQty
                  WHERE StorerKey = @c_CurrentStorer
                  AND   SKU = @c_CurrentSKU
                  AND   LOC = @c_CurrentLoc
                  AND   LOT = @c_FromLot

               END -- IF @n_FromQty > 0

               IF @b_debug = 1
               BEGIN
                  SELECT @c_CurrentSKU ' SKU', @c_CurrentLoc 'LOC', @c_CurrentPriority 'priority', @n_currentfullcase 'full case', @n_CurrentSeverity 'severity'
                  SELECT @n_RemainingQty '@n_RemainingQty', @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU, @c_fromlot 'from lot', @c_FromID
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
         END -- WHILE LOOP For Preallocated Lot

         NEXT_SKUxLOC:
         -- (SWT01)
         IF @n_RemainingQty <= 0 AND NOT EXISTS(SELECT 1 FROM #SkipSKU WHERE SKU = @c_CurrentSKU)
         BEGIN
            INSERT INTO #SkipSKU (SKU) VALUES (@c_CurrentSKU)
         END

         FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentStorer
                                       ,  @c_CurrentSKU
                                       ,  @c_CurrentLoc
                                       ,  @n_CurrentSeverity
                                       ,  @c_CurrentPriority
                                       ,  @c_ToLocationtype
                                       ,  @c_Packkey
                                       ,  @c_NoMixLottable02
      END -- -- FOR SKUxLOC
      CLOSE CUR_SKUxLOC
      DEALLOCATE CUR_SKUxLOC

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
      FROM #Replenishment R

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
            ,  @c_ReplenishmentKey OUTPUT
            ,  @b_success          OUTPUT
            ,  @n_err              OUTPUT
            ,  @c_errmsg           OUTPUT

         IF NOT @b_success = 1
         BEGIN
            BREAK
         END

         IF @b_success = 1
         BEGIN
            IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK)
                       WHERE Loc = @c_CurrentLoc
                       AND LoseId = '1' )
            BEGIN
               SET @c_ToID = ''
            END
            ELSE
            BEGIN
               SET @c_ToID = @c_FromID
            END

            INSERT INTO REPLENISHMENT
               (
                  Replenishmentgroup
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
               ,  QtyReplen
               ,  Wavekey
               ,  PendingMoveIn
               ,  ToID
               )
                  VALUES (
                  @c_ReplenishmentGroup
               ,  @c_ReplenishmentKey
               ,  @c_CurrentStorer
               ,  @c_CurrentSKU
               ,  @c_FromLOC
               ,  @c_CurrentLoc
               ,  @c_FromLot
               ,  @c_FromID
               ,  @n_FromQty
               ,  @c_UOM
               ,  @c_PackKey
               ,  'N'
               ,  'PC27'
               ,  @n_FromQty
               ,  @c_Wavekey
               ,  @n_FromQty
               ,  @c_ToID
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
   END

   QUIT_SP:

   IF @n_continue = 3
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

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
         ,CASE WHEN ISNULL(CLR.Code,'') = ''
               THEN LOC.PutawayZone ELSE '' END AS Putawayzone
         ,PACK.CaseCnt
         ,PACK.Pallet
         ,NoOfCSInPL = CASE WHEN PACK.CaseCnt > 0 THEN PACK.Pallet / PACK.CaseCnt ELSE 0 END
         ,SuggestPL  = CASE WHEN PACK.Pallet  > 0 THEN FLOOR(R.Qty / PACK.Pallet) ELSE 0 END
         ,SuggestCS  = CASE WHEN PACK.CaseCnt > 0 AND  PACK.Pallet > 0
                            THEN FLOOR((R.Qty % CONVERT(INT, PACK.Pallet)) / PACK.CaseCnt) ELSE 0
                       END
         ,TotalCS    = CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(R.Qty / PACK.CaseCnt) ELSE 0 END
         ,PACK.PackUOM1
         ,PACK.PackUOM3
         ,R.ReplenishmentKey
         ,LA.Lottable02
         ,CASE WHEN ISNULL(CLR.Code,'') <> ''
               THEN FRLOC.LocationGroup ELSE '' END AS LocationGroup
         ,CASE WHEN ISNULL(CLR.Code,'') <> '' THEN
               CASE  WHEN LOC.LocationType = 'CASE' THEN 'Pick-Case'
                     WHEN LOC.LocationType = 'PICK' THEN 'Pick-Piece'
                     ELSE LOC.LocationType END
               ELSE '' END AS LocationType
         ,R.Wavekey
   FROM  Replenishment R WITH (NOLOCK)
   JOIN  SKU             WITH (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)
   JOIN  LOC             WITH (NOLOCK) ON (LOC.Loc = R.ToLoc)
   JOIN  LOC FRLOC       WITH (NOLOCK) ON (R.FromLoc = FRLOC.Loc)
   JOIN  PACK            WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   JOIN  LOTATTRIBUTE LA WITH (NOLOCK) ON (R.Lot = LA.Lot)
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (R.Storerkey = CLR.Storerkey AND CLR.Code = 'REPLCASETOPICK'
                                          AND CLR.Listname = 'REPORTCFG' AND CLR.Long  = 'r_Replenishment_report_wave01' AND ISNULL(CLR.Short,'') <> 'N')   --NJOW02
   WHERE R.Wavekey   = @c_Wavekey
   AND  LOC.facility = @c_Facility
   AND R.Confirmed   = 'N'
   ORDER BY CASE WHEN ISNULL(CLR.Code,'') <> '' THEN
            FRLOC.LocationGroup ELSE LOC.PutawayZone END
         ,  CASE WHEN ISNULL(CLR.Code,'') <> '' THEN
                      LOC.LocationType ELSE '' END
         ,  FRLOC.LogicalLocation
         ,  R.FromLoc
         ,  R.Id
         ,  LA.Lottable02
         ,  R.Sku

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ODMRPL01                                          */
/* Creation Date:  27-Mar-2024                                             */
/* Copyright: Maersk                                                       */
/* Written by:Shong                                                        */
/*                                                                         */
/* Purpose: This Stored procedure include Replenishment logic and          */
/*        : Task creation as well as Replenishment record generation       */
/*                                                                         */
/* Called By: RDT and SCE Generate Report Stored Procedure                 */
/*                                                                         */
/* PVCS Version: 1.9                                                       */
/*                                                                         */
/* Version: MWMS V2                                                        */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 24-Mar-2024 SHONG    1.0   Create UWP-14725                             */
/* 27-Mar-2024 Wan01    1.1   Change Task Priority                         */
/* 18-Apr-2024 Wan02    1.2   Fix 1)Repl for 1st setup empty loc           */
/*                            2)Exclude Repl from STAGING                  */
/* 13-May-2024 PPA371   1.3   UWP-19048: Added condition to Exclude        */
/*                            lottable06=1 from the inventory              */
/* 02-AUG-2024 Wan03    1.4   UWP-21574 -MPL Disallow Different Lottables  */
/*                            to same PickFace                             */
/* 16-OCT-2024 Wan04    1.5   UWP-24391 [FCR-837] Unilever Replenishment for*/
/*                            Flowrack                                     */
/* 05-NOV-2024 Wan05    1.6   UWP-24391 Fixed. Insert SkuxLoc If BackLoc is*/
/*                            new loc                                      */
/* 07-NOV-2024 SSA01    1.7   UWP-26065 updated priority to 1 for VNAOUT   */
/*                            task                                         */
/* 12-NOV-2024 WAN06    1.8   UWP-26935 Prerequisite to create assign loc  */
/*                            for BackLoc. remove auto create              */
/* 12-NOV-2024 WAN07    1.9   UWP-26935 BACK Loc setup MaxPallet, Replenish*/
/*                            break when MaxPallet meet                    */
/* 09-JAN-2025 WTS01    2.0   FCR-2214 call auto replen job based on Config*/
/***************************************************************************/
CREATE     PROC [dbo].[isp_ODMRPL01]
   @c_Facility   NVARCHAR(5)    = '',
   @c_Storerkey  NVARCHAR(15)   = '',
   @c_SKU        NVARCHAR(20)   = '',
   @c_LOC        NVARCHAR(10)   = '',
   @c_ReplenType NVARCHAR(50)   = 'T', -- T=TaskManager/R-Replenishment
   @c_ReplenishmentGroup NVARCHAR(10)   = '', 
   @b_Success    INT OUTPUT,
   @n_Err        INT OUTPUT,
   @c_ErrMsg     NVARCHAR(255) OUTPUT,
   @b_Debug      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt          INT            = @@TRANCOUNT
      , @n_Continue              INT            = 1

      , @c_Wavekey               NVARCHAR(10)   = ''
      
      , @c_ReplenishmentKey      NVARCHAR(10)   = ''

      , @c_Priority              NVARCHAR(5)    = ''
      , @c_TaskPriority          NVARCHAR(10)   = '5'                            --(Wan01)

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
      , @n_PendingMoveIn         INT            = 0                              --(Wan03)
      , @c_NoMixLottable01       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable02       NVARCHAR(1)    = '0'                            --(Wan03) 
      , @c_NoMixLottable03       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable04       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable05       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable06       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable07       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable08       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable09       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable10       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable11       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable12       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable13       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable14       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_NoMixLottable15       NVARCHAR(1)    = '0'                            --(Wan03)
      , @c_CommingleLot          NVARCHAR(1)    = '0'                            --(Wan03)
      , @n_LotCnt                INT            = 0                              --(Wan03)
      , @n_Lot01Cnt              INT            = 0                              --(Wan03)
      , @n_Lot02Cnt              INT            = 0                              --(Wan03)
      , @n_Lot03Cnt              INT            = 0                              --(Wan03)
      , @n_Lot04Cnt              INT            = 0                              --(Wan03)
      , @n_Lot05Cnt              INT            = 0                              --(Wan03)
      , @n_Lot06Cnt              INT            = 0                              --(Wan03)
      , @n_Lot07Cnt              INT            = 0                              --(Wan03)
      , @n_Lot08Cnt              INT            = 0                              --(Wan03)
      , @n_Lot09Cnt              INT            = 0                              --(Wan03)
      , @n_Lot10Cnt              INT            = 0                              --(Wan03)
      , @n_Lot11Cnt              INT            = 0                              --(Wan03)
      , @n_Lot12Cnt              INT            = 0                              --(Wan03)
      , @n_Lot13Cnt              INT            = 0                              --(Wan03)
      , @n_Lot14Cnt              INT            = 0                              --(Wan03)
      , @n_Lot15Cnt              INT            = 0                              --(Wan03)
      , @c_Lot_SL                NVARCHAR(10)   = ''                             --(Wan03) 
      , @c_Lottable01            NVARCHAR(18)   = ''                             --(Wan03)   
      , @c_Lottable02            NVARCHAR(18)   = ''                             --(Wan03)
      , @c_Lottable03            NVARCHAR(18)   = ''                             --(Wan03)
      , @dt_Lottable04           DATETIME                                        --(Wan03)
      , @dt_Lottable05           DATETIME                                        --(Wan03)
      , @c_Lottable06            NVARCHAR(30)   = ''                             --(Wan03)
      , @c_Lottable07            NVARCHAR(30)   = ''                             --(Wan03)
      , @c_Lottable08            NVARCHAR(30)   = ''                             --(Wan03)
      , @c_Lottable09            NVARCHAR(30)   = ''                             --(Wan03)
      , @c_Lottable10            NVARCHAR(30)   = ''                             --(Wan03)
      , @c_Lottable11            NVARCHAR(30)   = ''                             --(Wan03)
      , @c_Lottable12            NVARCHAR(30)   = ''                             --(Wan03)
      , @dt_Lottable13           DATETIME                                        --(Wan03) 
      , @dt_Lottable14           DATETIME                                        --(Wan03)
      , @dt_Lottable15           DATETIME                                        --(Wan03)
      , @dt_Lottable04_2         DATETIME                                        --(Wan03)
      , @dt_Lottable05_2         DATETIME                                        --(Wan03)
      , @dt_Lottable13_2         DATETIME                                        --(Wan03) 
      , @dt_Lottable14_2         DATETIME                                        --(Wan03)
      , @dt_Lottable15_2         DATETIME                                        --(Wan03)
      , @c_SQLAddCond            NVARCHAR(MAX)                                   --(Wan03)
      , @c_ReplLottable01        NVARCHAR(18)   = ''                             --(Wan03)
      , @c_ReplLottable02        NVARCHAR(18)   = ''
      , @c_ReplLottable03        NVARCHAR(18)   = ''                             --(Wan03)
      , @dt_ReplLottable04       DATETIME                                        --(Wan03)
      , @dt_ReplLottable05       DATETIME                                        --(Wan03)
      , @c_ReplLottable06        NVARCHAR(30)   = ''                             --(Wan03)
      , @c_ReplLottable07        NVARCHAR(30)   = ''                             --(Wan03)
      , @c_ReplLottable08        NVARCHAR(30)   = ''                             --(Wan03)
      , @c_ReplLottable09        NVARCHAR(30)   = ''                             --(Wan03)
      , @c_ReplLottable10        NVARCHAR(30)   = ''                             --(Wan03)
      , @c_ReplLottable11        NVARCHAR(30)   = ''                             --(Wan03)
      , @c_ReplLottable12        NVARCHAR(30)   = ''                             --(Wan03)
      , @dt_ReplLottable13       DATETIME                                        --(Wan03)
      , @dt_ReplLottable14       DATETIME                                        --(Wan03)
      , @dt_ReplLottable15       DATETIME                                        --(Wan03)

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
      , @c_LottableName          NVARCHAR(30)   = ''  
      , @c_LottableValue         NVARCHAR(30)   = ''  
      , @c_SQL                   NVARCHAR(MAX)  = ''
      , @c_SQLParms              NVARCHAR(1000) = ''                             --(Wan04)
      , @n_CursorRows            INT            = 0 

      , @c_TaskDetailKey         NVARCHAR(10)   = '' 
      , @c_FromLogicalLoc        NVARCHAR(10)   = '' 
      , @c_FromAreaKey           NVARCHAR(10)   = ''  
      , @c_ToLogicalLoc          NVARCHAR(10)   = '' 
      , @c_ToAreaKey             NVARCHAR(10)   = '' 
      , @n_IsRDT                 INT            = 0                              --(Wan01)
      , @c_condition             NVARCHAR(MAX)  =''                              --(ppa371)
      , @SQL_QUERY               NVARCHAR(MAX)  =''                              --(ppa371)
      , @SQL_Parms               NVARCHAR(MAX)  =''                              --(ppa371)

      , @c_REPLCond              NVARCHAR(MAX)  = ''                             --(Wan04)
      , @c_REPLB2F               NVARCHAR(10)   = 'N'                            --(Wan04)      
      , @c_B2FLocType            NVARCHAR(10)   = ''                             --(Wan04)
      , @c_AutoReplB2F           NVARCHAR(10)   = 'N'                            --(Wan04)
      , @c_loc_F                 NVARCHAR(10)   = ''                             --(Wan04)
      , @c_LocationGroup         NVARCHAR(10)   = ''                             --(Wan04)
      , @n_MaxPallet             INT            = 0                              --(Wan07)
      , @c_GenerateReplenTask    NVARCHAR(10)   = 'N'                            --(SWT01)

   WHILE @@TRANCOUNT > 0
   BEGIN
     COMMIT TRAN
   END

   BEGIN TRAN
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT                                             --(Wan01) - START

   IF @n_IsRDT = 1
   BEGIN
      SET @c_TaskPriority = '3'
   END                                                                              --(Wan01) - END

   IF ISNULL(RTRIM(@c_LOC), '') = ''
   BEGIN
      IF @b_debug = 1
      PRINT '<<< Location Paramater Blank! '
       
      GOTO QUIT_SP
   END 

   SELECT TOP 1
      @c_Facility  = LOC.Facility
   FROM LOC WITH (NOLOCK)
   WHERE LOC.LOC = @c_LOC

   IF @n_continue = 1                                                               --(Wan04) - START
   BEGIN
      SET @c_loc_F = ''
      SELECT @c_LocationGroup = l.LocationGroup
            ,@c_loc_F = @c_Loc
      FROM   SKUxLOC sl WITH (NOLOCK)
      JOIN   Loc l WITH (NOLOCK) ON  sl.Loc = l.Loc
      WHERE  sl.Storerkey = @c_Storerkey
      AND    sl.Sku       = @c_Sku
      AND    sl.Loc       = @c_Loc
      AND    sl.LocationType IN ('CASE', 'PICK')

      --Check if valid loc to continue repl
      IF @c_loc_F = ''        --If @c_Loc is pickface, @c_loc_F is not empty
      BEGIN 
         GOTO QUIT_SP
      END

      SELECT @c_AutoReplB2F= MAX(CASE WHEN cl.Code = 'AutoReplB2F' THEN cl.UDF01 ELSE 'N' END) 
            ,@c_REPLCond   = MAX(CASE WHEN cl.Code = 'Condition' THEN cl.Notes ELSE '' END)
            ,@c_REPLB2F    = MAX(CASE WHEN cl.Code = 'BackToFront' THEN cl.UDF01 ELSE 'N' END)
            ,@c_B2FLocType = MAX(CASE WHEN cl.Code = 'BackToFront' AND cl.UDF01 = 'Y' THEN cl.UDF02 ELSE '' END)
            ,@c_GenerateReplenTask = MAX(CASE WHEN cl.Code = 'EnableAutoRepln' AND cl.UDF01 = 'Y' THEN 'Y' ELSE 'N' END)
      FROM dbo.CODELKUP cl (NOLOCK) 
      WHERE cl.ListName = 'REPLENCFG'
      AND   cl.code2 = 'isp_ODMRPL01'
      AND   cl.Storerkey = @c_Storerkey
 
      SET @c_loc_F = @c_loc

      IF @c_REPLB2F = 'Y'
      BEGIN
         IF @c_LocationGroup <> ''
         BEGIN
             --Find Back Loc
            SET @c_SQL = N'SELECT TOP 1 @c_Loc = l.Loc'                             --(Wan05) - START   
                       +           ',   @n_MaxPallet = l.MaxPallet'                 --(Wan07)                
                       + ' FROM LOC l (NOLOCK)' 
                       + ' WHERE l.LocationGroup = @c_LocationGroup'
                       + ' AND   l.Facility = @c_Facility'
                       + CASE WHEN @c_B2FLocType <> '' THEN 
                         ' AND   l.LocationType  = @c_B2FLocType' ELSE '' END
                       + ' ORDER BY l.Loc'
                           
            SET @c_SQLParms = N'@c_LocationGroup   NVARCHAR(10)
                              , @c_B2FLocType      NVARCHAR(10)
                              , @c_Facility        NVARCHAR(5)
                              , @c_Loc             NVARCHAR(10) OUTPUT 
                              , @n_MaxPallet       INT OUTPUT'                      --(Wan07)                                      
                              
            EXECUTE sp_ExecuteSQL @c_SQL 
                                 ,@c_SQLParms
                                 ,@c_LocationGroup
                                 ,@c_B2FLocType   
                                 ,@c_Facility     
                                 ,@c_Loc           OUTPUT                           --(Wan05) - END  
                                 ,@n_MaxPallet     OUTPUT                           --(Wan07)                                         

            IF @c_Loc <> ''                                                         --(Wan06) - START
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM SKUxLOC sl(NOLOCK)                         
                              WHERE sl.Storerkey = @c_Storerkey
                              AND   sl.Sku = @c_Sku
                              AND   sl.Loc = @c_Loc
                              )
               BEGIN
                  SET @c_Loc = ''
               END                                                                  
            END                                                                     --(Wan06) - END

            IF @c_Loc <> '' AND @c_AutoReplB2F = 'Y'
            BEGIN
               EXEC msp_ReplBack2Front
                  @c_Facility   = @c_Facility 
               ,  @c_Storerkey  = @c_Storerkey
               ,  @c_SKU        = @c_SKU
               ,  @c_LOC_Back   = @c_LOC  
               ,  @c_LOC_Front  = @c_loc_F  
               ,  @b_Success    = @b_Success  OUTPUT
               ,  @n_Err        = @n_Err      OUTPUT
               ,  @c_ErrMsg     = @c_ErrMsg   OUTPUT 
               ,  @b_Debug      = @b_Debug 
               
               IF @b_Success = 0
               BEGIN
                  SET @n_Continue = 3
               END
            END    
            
            --IF @n_Continue = 1 AND @c_Loc <> ''                                   --(Wan06)(Wan05) - START
            --BEGIN
            --   IF NOT EXISTS (SELECT 1 FROM SKUxLOC sl(NOLOCK)
            --                  WHERE sl.Storerkey = @c_Storerkey
            --                  AND   sl.Sku = @c_Sku
            --                  AND   sl.Loc = @c_Loc
            --                  )
            --   BEGIN
            --      INSERT INTO SKUxLOC (Storerkey, Sku, Loc, LocationType, Qty) 
            --      VALUES (@c_Storerkey, @c_Sku, @c_Loc, '', 0)
            --   END                                                                
            --END                                                                   --(Wan06)(Wan05) - END
         END
      END                                                                           
   END                                                                              --(Wan04) - END
   
   IF @c_GenerateReplenTask = 'N' -- (SWT01)
      GOTO QUIT_SP

   IF @n_continue = 1 AND @c_GenerateReplenTask = 'Y'
   BEGIN
      SET @c_ReplenishmentKey = ''
      SET @c_ReplFullPallet = 'Y'
      SET @c_ReplAllPalletQty = 'Y'
      SET @c_CaseToPick = 'N'

      IF @c_ReplAllPalletQty = 'Y'
      BEGIN
         SET @c_ReplFullPallet = 'N'
      END

      IF OBJECT_ID('tempdb..#Replenishment','u') IS NOT NULL
      BEGIN
         DROP TABLE #Replenishment;
      END

      CREATE TABLE #Replenishment
      (
         RowID INT IDENTITY(1,1) PRIMARY KEY,
         StorerKey NVARCHAR(15) NOT NULL DEFAULT(''),
         SKU NVARCHAR(20) NOT NULL DEFAULT(''),
         FromLOC NVARCHAR(10) NOT NULL DEFAULT(''),
         ToLOC NVARCHAR(10) NOT NULL DEFAULT(''),
         Lot NVARCHAR(10) NOT NULL DEFAULT(''),
         ID NVARCHAR(18) NOT NULL DEFAULT(''),
         LocationType NVARCHAR(10) NOT NULL DEFAULT(''),
         Qty INT NOT NULL DEFAULT(0),
         QtyMoved INT NOT NULL DEFAULT(0),
         QtyInPickLOC INT NOT NULL DEFAULT(0),
         [Priority] NVARCHAR(10) NOT NULL DEFAULT(''),
         UOM NVARCHAR(10) NOT NULL DEFAULT(''),
         Packkey NVARCHAR(10) NOT NULL DEFAULT(''),
         ReplLottable01 NVARCHAR(18) NOT NULL DEFAULT('')                           --(Wan03)
      ,   ReplLottable02 NVARCHAR(18) NOT NULL DEFAULT('')                           
      ,   ReplLottable03 NVARCHAR(18) NOT NULL DEFAULT('')                          --(Wan03)
      ,   ReplLottable04 DATETIME NULL                                              --(Wan03)
      ,   ReplLottable05 DATETIME NULL                                              --(Wan03)
      ,   ReplLottable06 NVARCHAR(30) NOT NULL DEFAULT('')                          --(Wan03)
      ,   ReplLottable07 NVARCHAR(30) NOT NULL DEFAULT('')                          --(Wan03)
      ,   ReplLottable08 NVARCHAR(30) NOT NULL DEFAULT('')                          --(Wan03)
      ,   ReplLottable09 NVARCHAR(30) NOT NULL DEFAULT('')                          --(Wan03)
      ,   ReplLottable10 NVARCHAR(30) NOT NULL DEFAULT('')                          --(Wan03)
      ,   ReplLottable11 NVARCHAR(30) NOT NULL DEFAULT('')                          --(Wan03)
      ,   ReplLottable12 NVARCHAR(30) NOT NULL DEFAULT('')                          --(Wan03)
      ,   ReplLottable13 DATETIME NULL                                              --(Wan03)
      ,   ReplLottable14 DATETIME NULL                                              --(Wan03)
      ,   ReplLottable15 DATETIME NULL                                              --(Wan03)
      )

      IF OBJECT_ID('tempdb..#TempSKUxLOC','u') IS NOT NULL
      BEGIN
         DROP TABLE #TempSKUxLOC;
      END

      CREATE TABLE #TempSKUxLOC
      (
         RowID INT IDENTITY(1,1) PRIMARY KEY,
         StorerKey NVARCHAR(15) NOT NULL DEFAULT(''),
         SKU NVARCHAR(20) NOT NULL DEFAULT(''),
         LOC NVARCHAR(10) NOT NULL DEFAULT(''),
         ReplenishmentPriority NVARCHAR(5) NOT NULL DEFAULT(''),
         ReplenishmentSeverity INT NOT NULL DEFAULT(0),
         ReplenishmentCasecnt INT NOT NULL DEFAULT(0),
         LocationType NVARCHAR(10) NOT NULL DEFAULT(''),                          
         NoMixLottable01 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable02 NVARCHAR(1) NOT NULL DEFAULT('')                           
      ,  NoMixLottable03 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable04 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable05 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable06 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable07 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable08 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable09 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable10 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable11 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable12 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable13 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable14 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  NoMixLottable15 NVARCHAR(1) NOT NULL DEFAULT('')                           --(Wan03)
      ,  CommingleLot    NVARCHAR(1) NOT NULL DEFAULT(''),                          --(Wan03)
         Packkey NVARCHAR(10) NOT NULL DEFAULT(''),
         LOT NVARCHAR(10) NOT NULL DEFAULT(''),
         Selected BIT NOT NULL DEFAULT(0),
         QtyReplen INT NOT NULL DEFAULT(0)
      )

      IF OBJECT_ID('tempdb..#SkipSku','u') IS NOT NULL
      BEGIN
         DROP TABLE #SkipSku;
      END

      CREATE TABLE #SkipSku
      (
         SKU NVARCHAR(20)
      )

      IF OBJECT_ID('tempdb..#OverAllocLot','u') IS NOT NULL                         --(Wan04) - START
      BEGIN
         DROP TABLE #OverAllocLot;
      END

      CREATE TABLE #OverAllocLot
      (
         Lot            NVARCHAR(10)   NOT NULL PRIMARY KEY
      )                                                                             --(Wan04) - END  
      


      -- Do not execute it Replenishment Task not done yet       
      IF @c_ReplenType = 'R'
      BEGIN        
        IF EXISTS(SELECT 1
                  FROM Replenishment RP WITH (NOLOCK)
                  WHERE (RP.Storerkey = @c_Storerkey 
                  AND RP.Sku = @c_SKU 
                  AND RP.ToLoc = @c_LOC)
                  AND (RP.Confirmed = 'N') ) 
        BEGIN
            PRINT '>>>>>> Replenishment Exists, Do nothing'
            GOTO QUIT_SP
        END
      END 

      IF @c_ReplenType = 'T'
      BEGIN
        IF EXISTS(SELECT 1
                  FROM TaskDetail TD WITH (NOLOCK)
                  WHERE (TD.Storerkey = @c_Storerkey 
                  AND TD.Sku = @c_SKU 
                  AND TD.ToLoc = @c_LOC)
                  AND (TD.Status IN ('Q', '0','1', '3'))
                  AND TD.TaskType = 'VNAOUT')
        BEGIN
            PRINT '>>>>>> Replenishment Task Exists, Do nothing'
            GOTO QUIT_SP
        END
      END 	 

        IF NOT EXISTS (SELECT 1
                       FROM SKUxLOC SL (NOLOCK) 
                       LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON SL.StorerKey = LLI.StorerKey--(Wan02) 
                                                                    AND SL.SKU = LLI.SKU 
                                                                    AND SL.LOC = LLI.LOC 
                       WHERE SL.StorerKey = @c_StorerKey
                           AND SL.SKU = @c_SKU
                           AND SL.LOC = @c_LOC                           
                       --    AND SL.LocationType IN ( 'CASE','PALLET','PICK')       --(Wan04)
                       GROUP BY 
                          SL.StorerKey, 
                          SL.SKU, 
                          SL.LOC,
                          SL.QtyLocationMinimum
                       HAVING (SUM(ISNULL(LLI.Qty,0)) - SUM(ISNULL(LLI.QtyPicked,0))               --(Wan02)
                             + SUM(ISNULL(LLI.PendingMoveIn,0))) <= SL.QtyLocationMinimum          --(Wan02)
                       )
        BEGIN
            PRINT '>>>>>> No Replenishment required, Do nothing'
            GOTO QUIT_SP
        END

        TRUNCATE TABLE #OverAllocLot;                                               --(Wan04) - START
                                                
        INSERT INTO #OverAllocLot (Lot)                              
        SELECT l1.Lot 
        FROM LOTxLOCxID l1 WITH (NOLOCK)
        WHERE l1.Storerkey = @c_Storerkey
        AND   l1.Sku  = @c_SKU
        AND   l1.Loc  = @c_Loc_F
        AND   l1.Qty - l1.QtyAllocated - l1.QtyPicked < 0
        GROUP BY l1.Lot                                                             --(Wan04) - END        
                
        SET @n_PendingMoveIn = 0                                                    --(Wan03) - START
        SELECT @n_PendingMoveIn = ISNULL(SUM(l1.PendingMoveIn),0)
        FROM LOTxLOCxID l1 WITH (NOLOCK)
        WHERE l1.Storerkey = @c_Storerkey
        AND   l1.Sku  = @c_SKU
        AND   l1.Loc  = @c_Loc                                                      --(Wan03) - END
        
        INSERT INTO #TempSKUxLOC
            ( StorerKey
            , SKU
            , LOC
            , ReplenishmentPriority
            , ReplenishmentSeverity
            , ReplenishmentCasecnt
            , LocationType
            , NoMixLottable01                                                       --(Wan03)
            , NoMixLottable02                                                       
            , NoMixLottable03                                                       --(Wan03)
            , NoMixLottable04                                                       --(Wan03)
            , NoMixLottable05                                                       --(Wan03)
            , NoMixLottable06                                                       --(Wan03)
            , NoMixLottable07                                                       --(Wan03)
            , NoMixLottable08                                                       --(Wan03)
            , NoMixLottable09                                                       --(Wan03)
            , NoMixLottable10                                                       --(Wan03)
            , NoMixLottable11                                                       --(Wan03)
            , NoMixLottable12                                                       --(Wan03)
            , NoMixLottable13                                                       --(Wan03)
            , NoMixLottable14                                                       --(Wan03)
            , NoMixLottable15                                                       --(Wan03)
            , CommingleLot                                                          --(Wan03)
            , Packkey
            , LOT
            , Selected
            , QtyReplen
            )
        SELECT SKUxLOC.StorerKey
         , SKUxLOC.SKU
         , SKUxLOC.LOC
         , SKUxLOC.ReplenishmentPriority
         , ReplenishmentSeverity = SKUxLOC.QtyLocationLimit - ((SKUxLOC.Qty - SKUxLOC.QtyPicked))
                                 + @n_PendingMoveIn                                 --(Wan03)
         , SKUxLOC.QtyLocationLimit
         , LOC.Locationtype
         , LOC.NoMixLottable01                                                      --(Wan03)
         , NoMixLottable02 = ISNULL(RTRIM(NoMixLottable02),'0')
         , LOC.NoMixLottable03                                                      --(Wan03)
         , LOC.NoMixLottable04                                                      --(Wan03)
         , LOC.NoMixLottable05                                                      --(Wan03)
         , LOC.NoMixLottable06                                                      --(Wan03)
         , LOC.NoMixLottable07                                                      --(Wan03)
         , LOC.NoMixLottable08                                                      --(Wan03)
         , LOC.NoMixLottable09                                                      --(Wan03)
         , LOC.NoMixLottable10                                                      --(Wan03)
         , LOC.NoMixLottable11                                                      --(Wan03)
         , LOC.NoMixLottable12                                                      --(Wan03)
         , LOC.NoMixLottable13                                                      --(Wan03)
         , LOC.NoMixLottable14                                                      --(Wan03)
         , LOC.NoMixLottable15                                                      --(Wan03)
         , LOC.CommingleLot                                                         --(Wan03)
         , SKU.Packkey
         , LOT=''
         , Selected=0
         , QtyReplen=0
        FROM SKUxLOC  WITH (NOLOCK)
        JOIN LOC  WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)
        JOIN SKU  WITH (NOLOCK) ON (SKUxLOC.Storerkey = SKU.Storerkey AND SKUxLOC.Sku = SKU.Sku)
        WHERE SKUxLOC.StorerKey = @c_Storerkey
            AND LOC.FACILITY = @c_Facility
            AND SKUxLOC.Sku = @c_SKU   
            AND SKUxLOC.LOC = @c_LOC     
            AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
            AND LOC.Status <> 'HOLD'            
            --AND SKUxLOC.LOCationtype IN ( 'CASE','PALLET','PICK')                 --(Wan04)   
            AND ((SKUxLOC.Qty - SKUxLOC.QtyPicked) + @n_PendingMoveIn) <= SKUxLOC.QtyLocationMinimum  --(Wan03)
        ORDER BY SKUxLOC.StorerKey
            ,  SKUxLOC.SKU
            ,  SKUxLOC.LOC

        IF @@ROWCOUNT > 0
        BEGIN
            IF ISNULL(RTRIM(@c_ReplenishmentGroup), '') <> ''
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
        END

        IF @b_debug = 1
        BEGIN
            PRINT '>>>>>> #TempSKUxLOC'
            SELECT *
            FROM #TempSKUxLOC
        END

        /* Loop through SKUxLOC for the currentSKU, current storer */
        /* to pickup the next severity */
        DECLARE CUR_SKUxLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT CurrentStorer = StorerKey
            , CurrentSKU = SKU
            , CurrentLoc = LOC
            , CurrentSeverity        = ISNULL(SUM(ReplenishmentSeverity),0)
            , ReplenishmentPriority  = ReplenishmentPriority
            , ToLocationType         = LocationType
            , Packkey          = Packkey
            , NoMixLottable01                                                       --(Wan03)
            , NoMixLottable02                                                         
            , NoMixLottable03                                                       --(Wan03)
            , NoMixLottable04                                                       --(Wan03)
            , NoMixLottable05                                                       --(Wan03)
            , NoMixLottable06                                                       --(Wan03)
            , NoMixLottable07                                                       --(Wan03)
            , NoMixLottable08                                                       --(Wan03)
            , NoMixLottable09                                                       --(Wan03)
            , NoMixLottable10                                                       --(Wan03)
            , NoMixLottable11                                                       --(Wan03)
            , NoMixLottable12                                                       --(Wan03)
            , NoMixLottable13                                                       --(Wan03)
            , NoMixLottable14                                                       --(Wan03)
            , NoMixLottable15                                                       --(Wan03)
            , CommingleLot                                                          --(Wan03)
        FROM #TempSKUxLOC
        GROUP BY StorerKey
            ,  SKU
            ,  LOC
            ,  ReplenishmentPriority
            ,  LocationType
            ,  Packkey
            ,  NoMixLottable01                                                       --(Wan03)
            ,  NoMixLottable02                                                         
            ,  NoMixLottable03                                                       --(Wan03)
            ,  NoMixLottable04                                                       --(Wan03)
            ,  NoMixLottable05                                                       --(Wan03)
            ,  NoMixLottable06                                                       --(Wan03)
            ,  NoMixLottable07                                                       --(Wan03)
            ,  NoMixLottable08                                                       --(Wan03)
            ,  NoMixLottable09                                                       --(Wan03)
            ,  NoMixLottable10                                                       --(Wan03)
            ,  NoMixLottable11                                                       --(Wan03)
            ,  NoMixLottable12                                                       --(Wan03)
            ,  NoMixLottable13                                                       --(Wan03)
            ,  NoMixLottable14                                                       --(Wan03)
            ,  NoMixLottable15                                                       --(Wan03)
            ,  CommingleLot                                                          --(Wan03)
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
                                    ,  @c_NoMixLottable01                           --(Wan03)
                                    ,  @c_NoMixLottable02                             
                                    ,  @c_NoMixLottable03                           --(Wan03)
                                    ,  @c_NoMixLottable04                           --(Wan03)
                                    ,  @c_NoMixLottable05                           --(Wan03)
                                    ,  @c_NoMixLottable06                           --(Wan03)
                                    ,  @c_NoMixLottable07                           --(Wan03)
                                    ,  @c_NoMixLottable08                           --(Wan03)
                                    ,  @c_NoMixLottable09                           --(Wan03)
                                    ,  @c_NoMixLottable10                           --(Wan03)
                                    ,  @c_NoMixLottable11                           --(Wan03)
                                    ,  @c_NoMixLottable12                           --(Wan03)
                                    ,  @c_NoMixLottable13                           --(Wan03)
                                    ,  @c_NoMixLottable14                           --(Wan03)
                                    ,  @c_NoMixLottable15                           --(Wan03)
                                    ,  @c_CommingleLot                              --(Wan03)
        WHILE @@Fetch_Status <> -1
        BEGIN
            IF EXISTS(SELECT 1
            FROM #SkipSKU
            WHERE SKU = @c_CurrentSKU)
            BEGIN
                GOTO NEXT_SKUxLOC
            END

            SET @n_LotCnt     = 0
            SET @n_Lot01Cnt   = 0
            SET @n_Lot02Cnt   = 0
            SET @n_Lot03Cnt   = 0
            SET @n_Lot04Cnt   = 0
            SET @n_Lot05Cnt   = 0
            SET @n_Lot06Cnt   = 0
            SET @n_Lot07Cnt   = 0
            SET @n_Lot08Cnt   = 0
            SET @n_Lot09Cnt   = 0
            SET @n_Lot10Cnt   = 0
            SET @n_Lot11Cnt   = 0
            SET @n_Lot12Cnt   = 0
            SET @n_Lot13Cnt   = 0
            SET @n_Lot14Cnt   = 0
            SET @n_Lot15Cnt   = 0
            SET @c_Lot_SL     = ''
            SET @c_Lottable01 = ''
            SET @c_Lottable02 = ''
            SET @c_Lottable03 = ''
            SET @dt_Lottable04= NULL
            SET @dt_Lottable05= NULL
            SET @c_Lottable06 = ''
            SET @c_Lottable07 = ''
            SET @c_Lottable08 = ''
            SET @c_Lottable09 = ''
            SET @c_Lottable10 = ''
            SET @c_Lottable11 = ''
            SET @c_Lottable12 = ''
            SET @dt_Lottable13= NULL
            SET @dt_Lottable14= NULL
            SET @dt_Lottable15= NULL

            SELECT @n_LotCnt     = COUNT(DISTINCT l1.Lot)
                 , @n_Lot01Cnt   = COUNT(DISTINCT ISNULL(la.Lottable01,''))
                 , @n_Lot02Cnt   = COUNT(DISTINCT ISNULL(la.Lottable02,''))
                 , @n_Lot03Cnt   = COUNT(DISTINCT ISNULL(la.Lottable03,''))
                 , @n_Lot04Cnt   = COUNT(DISTINCT ISNULL(la.Lottable04,'1900-01-01'))
                 , @n_Lot05Cnt   = COUNT(DISTINCT ISNULL(la.Lottable05,'1900-01-01'))
                 , @n_Lot06Cnt   = COUNT(DISTINCT ISNULL(la.Lottable06,''))
                 , @n_Lot07Cnt   = COUNT(DISTINCT ISNULL(la.Lottable07,''))
                 , @n_Lot08Cnt   = COUNT(DISTINCT ISNULL(la.Lottable08,''))
                 , @n_Lot09Cnt   = COUNT(DISTINCT ISNULL(la.Lottable09,''))
                 , @n_Lot10Cnt   = COUNT(DISTINCT ISNULL(la.Lottable10,''))
                 , @n_Lot11Cnt   = COUNT(DISTINCT ISNULL(la.Lottable11,''))
                 , @n_Lot12Cnt   = COUNT(DISTINCT ISNULL(la.Lottable12,''))
                 , @n_Lot13Cnt   = COUNT(DISTINCT ISNULL(la.Lottable13,'1900-01-01'))
                 , @n_Lot14Cnt   = COUNT(DISTINCT ISNULL(la.Lottable14,'1900-01-01'))
                 , @n_Lot15Cnt   = COUNT(DISTINCT ISNULL(la.Lottable15,'1900-01-01'))
                 , @c_Lot_SL     = ISNULL(MIN(l1.Lot),'')
                 , @c_Lottable01 = MIN(ISNULL(la.Lottable01,''))
                 , @c_Lottable02 = MIN(ISNULL(la.Lottable02,''))
                 , @c_Lottable03 = MIN(ISNULL(la.Lottable03,''))
                 , @dt_Lottable04= MIN(la.Lottable04)
                 , @dt_Lottable05= MIN(la.Lottable05)
                 , @c_Lottable06 = MIN(ISNULL(la.Lottable06,''))
                 , @c_Lottable07 = MIN(ISNULL(la.Lottable07,''))
                 , @c_Lottable08 = MIN(ISNULL(la.Lottable08,''))
                 , @c_Lottable09 = MIN(ISNULL(la.Lottable09,''))
                 , @c_Lottable10 = MIN(ISNULL(la.Lottable10,''))
                 , @c_Lottable11 = MIN(ISNULL(la.Lottable11,''))
                 , @c_Lottable12 = MIN(ISNULL(la.Lottable12,''))
                 , @dt_Lottable13= MIN(la.Lottable13)
                 , @dt_Lottable14= MIN(la.Lottable14)
                 , @dt_Lottable15= MIN(la.Lottable15)
            FROM LOTxLOCxID l1   (NOLOCK)
            JOIN LOTATTRIBUTE la (NOLOCK) ON la.Lot = L1.Lot
            WHERE l1.Storerkey = @c_CurrentStorer                                   --(Wan04)
            AND l1.Sku  = @c_CurrentSku                                             --(Wan04)
            AND l1.Loc  = @c_CurrentLoc                                             --(Wan04)
            AND l1.Qty - l1.QtyPicked + l1.PendingMoveIn  + l1.QtyExpected > 0      --(Wan04)
            GROUP BY l1.Storerkey, l1.Sku, l1.Loc

            SET @c_SQLAddCond = ''
            IF @c_Lot_SL <> ''
            BEGIN
               IF @c_CommingleLot = '0'  
               BEGIN
                  IF @n_LotCnt > 1 
                  BEGIN
                     PRINT '>>>>>> Multiple Lot on No ConmingleLot Loc, Do nothing'
                     GOTO NEXT_SKUxLOC
                  END
                  SET @c_SQLAddCond = @c_SQLAddCond + ' AND LOTxLOCxID.Lot = @c_Lot_SL' 
               END
               ELSE
               BEGIN
                  IF @c_NoMixLottable01 = '1' 
                  BEGIN
                     IF @n_Lot01Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable01 on NoMixLottable01 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @c_SQLAddCond = @c_SQLAddCond + ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01' 
                  END
                  IF @c_NoMixLottable02 = '1' 
                  BEGIN
                     IF @n_Lot02Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable02 on NoMixLottable02 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @c_SQLAddCond = @c_SQLAddCond + ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02' 
                  END
                  IF @c_NoMixLottable03 = '1' 
                  BEGIN
                     IF @n_Lot03Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable03 on NoMixLottable03 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @c_SQLAddCond = @c_SQLAddCond + ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03' 
                  END
                  IF @c_NoMixLottable04 = '1' 
                  BEGIN
                     IF @n_Lot04Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable04 on NoMixLottable04 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @dt_Lottable04_2 = @dt_Lottable14
                     IF @dt_Lottable04 IS NULL SET @dt_Lottable04_2 = '1900-01-01'   
                     SET @c_SQLAddCond = @c_SQLAddCond 
                                       + ' AND LOTATTRIBUTE.Lottable04 IN (@dt_Lottable04_2, @dt_Lottable04)' 
                  END
                  IF @c_NoMixLottable05 = '1' 
                  BEGIN
                     IF @n_Lot05Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable05 on NoMixLottable05 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @dt_Lottable05_2 = NULL
                     IF @dt_Lottable05 IS NULL SET @dt_Lottable05_2 = '1900-01-01' 
                        SET @c_SQLAddCond = @c_SQLAddCond 
                                       + ' AND LOTATTRIBUTE.Lottable05 IN (@dt_Lottable05_2, @dt_Lottable05)' 
                  END
                  IF @c_NoMixLottable06 = '1' 
                  BEGIN
                     IF @n_Lot06Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable06 on NoMixLottable06 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @c_SQLAddCond = @c_SQLAddCond + ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06' 
                  END
                  IF @c_NoMixLottable07 = '1' 
                  BEGIN
                     IF @n_Lot07Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable07 on NoMixLottable07 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @c_SQLAddCond = @c_SQLAddCond + ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07' 
                  END
                  IF @c_NoMixLottable08 = '1' 
                  BEGIN
                     IF @n_Lot08Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable08 on NoMixLottable08 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @c_SQLAddCond = @c_SQLAddCond + ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08' 
                  END
                  IF @c_NoMixLottable09 = '1' 
                  BEGIN
                     IF @n_Lot09Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable09 on NoMixLottable09 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @c_SQLAddCond = @c_SQLAddCond + ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09' 
                  END
                  IF @c_NoMixLottable10 = '1' 
                  BEGIN
                     IF @n_Lot10Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable10 on NoMixLottable10 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @c_SQLAddCond = @c_SQLAddCond + ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10' 
                  END
                  IF @c_NoMixLottable11 = '1' 
                  BEGIN
                     IF @n_Lot11Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable11 on NoMixLottable11 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @c_SQLAddCond = @c_SQLAddCond + ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11' 
                  END
                  IF @c_NoMixLottable12 = '1' 
                  BEGIN
                     IF @n_Lot12Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable12 on NoMixLottable12 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @c_SQLAddCond = @c_SQLAddCond + ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12' 
                  END
                  IF @c_NoMixLottable13 = '1' 
                  BEGIN
                     IF @n_Lot13Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable13 on NoMixLottable13 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @dt_Lottable13_2 = @dt_Lottable13
                     IF @dt_Lottable13 IS NULL SET @dt_Lottable13_2 = '1900-01-01'                     
                     SET @c_SQLAddCond = @c_SQLAddCond 
                                       + ' AND LOTATTRIBUTE.Lottable13 IN (@dt_Lottable13_2, @dt_Lottable13)' 
                  END
                  IF @c_NoMixLottable14 = '1' 
                  BEGIN
                     IF @n_Lot14Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable14 on NoMixLottable14 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @dt_Lottable14_2 = @dt_Lottable14
                     IF @dt_Lottable14 IS NULL SET @dt_Lottable14_2 = '1900-01-01'                     
                     SET @c_SQLAddCond = @c_SQLAddCond 
                                       + ' AND LOTATTRIBUTE.Lottable14 IN (@dt_Lottable14_2, @dt_Lottable14)' 
                  END
                  IF @c_NoMixLottable15 = '1' 
                  BEGIN
                     IF @n_Lot15Cnt > 1
                     BEGIN
                        PRINT '>>>>>> Multiple Lottable15 on NoMixLottable15 Loc, Do nothing'
                        GOTO NEXT_SKUxLOC
                     END
                     SET @dt_Lottable15_2 = @dt_Lottable15
                     IF @dt_Lottable15 IS NULL SET @dt_Lottable15_2 = '1900-01-01'
                     SET @c_SQLAddCond = @c_SQLAddCond 
                                       + ' AND LOTATTRIBUTE.Lottable15 IN (@dt_Lottable15_2, @dt_Lottable15)' 
                  END
               END
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
               , @n_CaseCnt= ISNULL(CaseCnt,0)
               , @c_UOM    = P.PackUOM3
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

            SET @n_FilterQty    = 1
            IF @c_ReplFullPallet = 'Y'
            BEGIN
                IF @n_Pallet = 0
                BEGIN
                    GOTO NEXT_SKUxLOC
                END
                SET @n_FilterQty = @n_Pallet
            END

            SET @n_RowID = 0
            SET @c_FromLot = ''

            IF @c_ReplOverflow = 'Y' AND @n_RemainingQty <= 0
            BEGIN
               SET @n_RemainingQty = @n_QtyPreAllocated
            END

            IF @b_debug = 1
            BEGIN
               PRINT '>>> CaseToPick: ' + @c_CaseToPick + ' ToLocationType: ' + @c_ToLocationType
            END
            --(Wan04) - START
            --IF @c_condition=''                                                                           --(ppa371)--start
            --BEGIN
            --  Select @c_condition = Codelkup.Notes from CODELKUP (NOLOCK) 
            --  where Codelkup.Code = 'CONDITION' 
            --  and Codelkup.Code2 = 'isp_ODMRPL01' and Codelkup.ListName = 'REPLENCFG'
            --END
            --(Wan04) - END

            SET @c_condition = @c_REPLCond
            IF @c_condition <> '' AND CHARINDEX('AND',upper(@c_condition)) = 0
            BEGIN
               SET @c_condition= ' AND '+ @c_condition
            END

            SET @SQL_QUERY=N'DECLARE CUR_REPL CURSOR FAST_FORWARD READ_ONLY FOR'
               + ' SELECT LOTxLOCxID.LOT'
               + ' , LOTxLOCxID.Loc'
               + ' , LOTxLOCxID.ID'
               + ' , LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen'
               + ' , LOTxLOCxID.QtyAllocated'
               + ' , LOTxLOCxID.QtyPicked'
               + ' , LOTATTRIBUTE.Lottable01'                                       --(Wan03)
               + ' , LOTATTRIBUTE.Lottable02'                                       
               + ' , LOTATTRIBUTE.Lottable03'                                       --(Wan03)
               + ' , ISNULL(LOTATTRIBUTE.Lottable04,''1900-01-01'')'                --(Wan03)
               + ' , ISNULL(LOTATTRIBUTE.Lottable05,''1900-01-01'')'                --(Wan03)
               + ' , LOTATTRIBUTE.Lottable06'                                       --(Wan03)
               + ' , LOTATTRIBUTE.Lottable07'                                       --(Wan03)
               + ' , LOTATTRIBUTE.Lottable08'                                       --(Wan03)
               + ' , LOTATTRIBUTE.Lottable09'                                       --(Wan03)
               + ' , LOTATTRIBUTE.Lottable10'                                       --(Wan03)
               + ' , LOTATTRIBUTE.Lottable11'                                       --(Wan03)
               + ' , LOTATTRIBUTE.Lottable12'                                       --(Wan03)
               + ' , ISNULL(LOTATTRIBUTE.Lottable13,''1900-01-01'')'                --(Wan03)
               + ' , ISNULL(LOTATTRIBUTE.Lottable14,''1900-01-01'')'                --(Wan03)
               + ' , ISNULL(LOTATTRIBUTE.Lottable15,''1900-01-01'')'                --(Wan03)
               + ' FROM LOT          WITH (NOLOCK) '
               + ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.Lot        = LOTATTRIBUTE.LOT)'
               + ' JOIN LOTxLOCxID   WITH (NOLOCK) ON (LOT.Lot        = LOTxLOCxID.Lot)'
               + ' JOIN LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)'
               + ' LEFT OUTER JOIN #OverAllocLot oal ON oal.LOT = LOT.LOT '         --(Wan04)               
               + ' WHERE LOTxLOCxID.LOC <>  @c_CurrentLoc'
               + ' AND LOTxLOCxID.StorerKey = @c_CurrentStorer'
               + ' AND LOTxLOCxID.SKU = @c_CurrentSku'
               + ' AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen >= 1'
               + ' AND LOTxLOCxID.QtyExpected = 0'
               + ' AND LOC.LocationFlag NOT IN (''DAMAGE'', ''HOLD'')'
               + ' AND LOC.LocationType NOT IN (''CASE'',''PICK'',''PALLET'',''STAGING'', @c_B2FLocType)'   --(Wan06)
               + ' AND LOC.Facility= @c_Facility'
               + ' AND LOC.Status  = ''OK'' AND LOT.Status  = ''OK'' '
               + @c_condition  
               + @c_SQLAddCond
                + ' ORDER BY CASE WHEN oal.lot IS NOT NULL THEN 1'                  --(Wan04)
               +               ' ELSE 9'                                            --(Wan04)                     
               +               ' END,'                                              --(Wan04)
               +'LOTATTRIBUTE.Lottable04,
               LOTATTRIBUTE.Lottable05,
               CASE WHEN (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) < @n_Pallet
                        THEN 1
                        ELSE 2
               END
               ,  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked)
               ,  LOTATTRIBUTE.Lottable02'
               set @SQL_Parms = N'@c_CurrentLoc NVARCHAR(10), @c_CurrentStorer NVARCHAR(15), @c_CurrentSku NVARCHAR(20)'
                              + ', @c_Facility NVARCHAR(5), @n_Pallet FLOAT'
                              + ', @c_Lot_SL          NVARCHAR(10)'
                              + ', @c_Lottable01      NVARCHAR(18)'                             --(Wan03)   
                              + ', @c_Lottable02      NVARCHAR(18)'                             --(Wan03)
                              + ', @c_Lottable03      NVARCHAR(18)'                             --(Wan03)
                              + ', @dt_Lottable04     DATETIME'                                 --(Wan03)
                              + ', @dt_Lottable04_2   DATETIME'                                 --(Wan03) 
                              + ', @dt_Lottable05     DATETIME'                                 --(Wan03)
                              + ', @dt_Lottable05_2   DATETIME'                                 --(Wan03) 
                              + ', @c_Lottable06      NVARCHAR(30)'                             --(Wan03)
                              + ', @c_Lottable07      NVARCHAR(30)'                             --(Wan03)
                              + ', @c_Lottable08      NVARCHAR(30)'                             --(Wan03)
                              + ', @c_Lottable09      NVARCHAR(30)'                             --(Wan03)
                              + ', @c_Lottable10      NVARCHAR(30)'                             --(Wan03)
                              + ', @c_Lottable11      NVARCHAR(30)'                             --(Wan03)
                              + ', @c_Lottable12      NVARCHAR(30)'                             --(Wan03)
                              + ', @dt_Lottable13     DATETIME'                                 --(Wan03) 
                              + ', @dt_Lottable13_2   DATETIME'                                 --(Wan03) 
                              + ', @dt_Lottable14     DATETIME'                                 --(Wan03)
                              + ', @dt_Lottable14_2   DATETIME'                                 --(Wan03) 
                              + ', @dt_Lottable15     DATETIME'                                 --(Wan03)
                              + ', @dt_Lottable15_2   DATETIME'                                 --(Wan03) 
                              + ', @c_B2FLocType      NVARCHAR(10)'                             --(Wan06)

               Execute SP_ExecuteSQL @SQL_QUERY, @SQL_Parms, @c_CurrentLoc , @c_CurrentStorer, @c_CurrentSku , @c_Facility, @n_Pallet        --(ppa371)--end
                                    ,@c_Lot_SL                                                  --(Wan03)
                                    ,@c_Lottable01                                              --(Wan03)
                                    ,@c_Lottable02                                              --(Wan03)
                                    ,@c_Lottable03                                              --(Wan03)
                                    ,@dt_Lottable04                                             --(Wan03)
                                    ,@dt_Lottable04_2                                           --(Wan03)
                                    ,@dt_Lottable05                                             --(Wan03)
                                    ,@dt_Lottable05_2                                           --(Wan03)
                                    ,@c_Lottable06                                              --(Wan03)
                                    ,@c_Lottable07                                              --(Wan03)
                                    ,@c_Lottable08                                              --(Wan03)
                                    ,@c_Lottable09                                              --(Wan03)
                                    ,@c_Lottable10                                              --(Wan03)
                                    ,@c_Lottable11                                              --(Wan03)
                                    ,@c_Lottable12                                              --(Wan03)
                                    ,@dt_Lottable13                                             --(Wan03)
                                    ,@dt_Lottable13_2                                           --(Wan03)
                                    ,@dt_Lottable14                                             --(Wan03)
                                    ,@dt_Lottable14_2                                           --(Wan03)
                                    ,@dt_Lottable15                                             --(Wan03)
                                    ,@dt_Lottable15_2                                           --(Wan03)
                                    ,@c_B2FLocType                                              --(Wan06)

         OPEN CUR_REPL

         SELECT @n_CursorRows = @@CURSOR_ROWS  
         IF @n_CursorRows = -1
         BEGIN
            PRINT '>>> No Available LOT'
         END 

         FETCH NEXT FROM CUR_REPL INTO @c_FromLot
                                    ,  @c_FromLoc
                                    ,  @c_FromID
                                    ,  @n_FromQty
                                    ,  @n_QtyAllocated
                                    ,  @n_QtyPicked
                                    ,  @c_ReplLottable01                            --(Wan03)
                                    ,  @c_ReplLottable02
                                    ,  @c_ReplLottable03                            --(Wan03)
                                    ,  @dt_ReplLottable04                           --(Wan03)
                                    ,  @dt_ReplLottable05                           --(Wan03)
                                    ,  @c_ReplLottable06                            --(Wan03)
                                    ,  @c_ReplLottable07                            --(Wan03)
                                    ,  @c_ReplLottable08                            --(Wan03)
                                    ,  @c_ReplLottable09                            --(Wan03)
                                    ,  @c_ReplLottable10                            --(Wan03)
                                    ,  @c_ReplLottable11                            --(Wan03)
                                    ,  @c_ReplLottable12                            --(Wan03)
                                    ,  @dt_ReplLottable13                           --(Wan03)
                                    ,  @dt_ReplLottable14                           --(Wan03)
                                    ,  @dt_ReplLottable15                           --(Wan03)


         WHILE @@Fetch_Status <> -1 AND @n_RemainingQty > 0
         BEGIN
            
            IF @c_REPLB2F = 'Y' AND  @n_MaxPallet > 0                               --(Wan07) - START
            BEGIN
             print @n_MaxPallet
               IF EXISTS(  SELECT 1
                           FROM #Replenishment AS r WITH(NOLOCK)
                           WHERE r.Storerkey = @c_CurrentStorer
                           AND   r.Sku       = @c_CurrentSKU
                           AND   r.ToLOC     = @c_CurrentLoc
                           AND   r.ID        <> ''
                           GROUP BY r.Storerkey, r.Sku, r.ToLOC
                           HAVING COUNT(DISTINCT r.ID) >= @n_MaxPallet
                           )
               BEGIN
                  BREAK
               END
            END                                                                     --(Wan07) - END

            IF EXISTS( SELECT 1
            FROM #Replenishment AS r WITH(NOLOCK)
            WHERE r.Lot = @c_Fromlot
               AND r.FromLOC = @c_FromLOC
               AND r.ID = @c_FromID)
            BEGIN
               GOTO NEXT_CANDIDATE
            END

            SET @n_LotCnt     = 0                                                   --(Wan03) - START
            SET @n_Lot01Cnt   = 0
            SET @n_Lot02Cnt   = 0
            SET @n_Lot03Cnt   = 0
            SET @n_Lot04Cnt   = 0
            SET @n_Lot05Cnt   = 0
            SET @n_Lot06Cnt   = 0
            SET @n_Lot07Cnt   = 0
            SET @n_Lot08Cnt   = 0
            SET @n_Lot09Cnt   = 0
            SET @n_Lot10Cnt   = 0
            SET @n_Lot11Cnt   = 0
            SET @n_Lot12Cnt   = 0
            SET @n_Lot13Cnt   = 0
            SET @n_Lot14Cnt   = 0
            SET @n_Lot15Cnt   = 0

            SELECT @n_LotCnt   = ISNULL(MAX(CASE WHEN @c_CommingleLot = '0' AND Lot <> @c_FromLot THEN 1 ELSE 0 END),0)
                  ,@n_Lot01Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable01 = '1' AND ReplLottable01 <> @c_ReplLottable01  
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot02Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable02 = '1' AND ReplLottable02 <> @c_ReplLottable02  
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot03Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable03 = '1' AND ReplLottable03 <> @c_ReplLottable03  
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot04Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable04 = '1' AND ReplLottable04 <> @dt_ReplLottable04 
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot05Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable05 = '1' AND ReplLottable05 <> @dt_ReplLottable05 
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot06Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable06 = '1' AND ReplLottable06 <> @c_ReplLottable06  
                                          THEN 1 ELSE 0 END),0)
                  ,@n_Lot07Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable07 = '1' AND ReplLottable07 <> @c_ReplLottable07  
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot08Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable08 = '1' AND ReplLottable08 <> @c_ReplLottable08  
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot09Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable09 = '1' AND ReplLottable09 <> @c_ReplLottable09  
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot10Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable10 = '1' AND ReplLottable10 <> @c_ReplLottable10  
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot11Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable11 = '1' AND ReplLottable11 <> @c_ReplLottable11  
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot12Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable12 = '1' AND ReplLottable12 <> @c_ReplLottable12  
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot13Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable13 = '1' AND ReplLottable13 <> @dt_ReplLottable13 
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot14Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable14 = '1' AND ReplLottable14 <> @dt_ReplLottable14 
                                          THEN 1 ELSE 0 END),0) 
                  ,@n_Lot15Cnt = ISNULL(MAX(CASE WHEN @c_NoMixLottable15 = '1' AND ReplLottable15 <> @dt_ReplLottable15 
                                          THEN 1 ELSE 0 END),0) 
            FROM #Replenishment
            WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
            GROUP BY Storerkey, Sku, ToLoc

            IF @n_LotCnt = 1 OR 
               @n_Lot01Cnt = 1 OR @n_Lot02Cnt = 1 OR @n_Lot03Cnt = 1 OR @n_Lot04Cnt = 1 OR @n_Lot05Cnt = 1 OR
               @n_Lot06Cnt = 1 OR @n_Lot07Cnt = 1 OR @n_Lot08Cnt = 1 OR @n_Lot09Cnt = 1 OR @n_Lot10Cnt = 1 OR
               @n_Lot11Cnt = 1 OR @n_Lot12Cnt = 1 OR @n_Lot13Cnt = 1 OR @n_Lot14Cnt = 1 OR @n_Lot15Cnt = 1 
            BEGIN
               GOTO NEXT_CANDIDATE
            END                                                                     --(Wan03) - END
            
            IF @c_NoMixLottable02 = '1' AND @n_InvCnt = 0
            BEGIN
               IF EXISTS ( SELECT 1
               FROM #Replenishment
               WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                  AND ReplLottable02 <> @c_ReplLottable02
               GROUP BY Storerkey, Sku, ToLoc
               HAVING COUNT(1) > 0)
               BEGIN
                  GOTO NEXT_CANDIDATE
               END
            END

            IF EXISTS(SELECT 1
                     FROM ID (NOLOCK)
                     WHERE ID = @c_FromID AND STATUS = 'HOLD')
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

            IF @c_REPLB2F = 'Y'                                                     --(Wan07) - START
            BEGIN
               IF @n_FromQty > @n_RemainingQty AND @c_ReplAllPalletQty = 'Y'
               BEGIN
                  SET @n_FromQty = 0
               END
            END                                                                     --(Wan07) - END
            ELSE IF @c_ToLocationType = 'PALLET'
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

               SELECT @c_LottableName = ''
               SELECT TOP 1
                  @c_LottableName = Code
               FROM CODELKUP (NOLOCK)
               WHERE Listname = 'REPLENLOT'
                  AND Storerkey = @c_StorerKey
               ORDER BY Code

               SET @c_LottableValue = ''
               IF ISNULL(@c_LottableName,'') <> ''
               BEGIN
                  SET @c_SQL = N'SELECT TOP 1 @c_LottableValue = LA.' + RTRIM(LTRIM(@c_LottableName))  +
                              N' FROM LOTATTRIBUTE LA (NOLOCK) ' + 
                              N' WHERE LA.StorerKey = @c_Storerkey ' + 
                              N' AND LA.lot = @c_FromLot  '

                  EXEC sp_executesql @c_SQL,
                  N'@c_LottableValue NVARCHAR(30) OUTPUT, @c_Storerkey NVARCHAR(15), @c_FromLot NVARCHAR(20)',
                  @c_LottableValue OUTPUT,
                  @c_Storerkey,
                  @c_FromLot
               END

               IF @b_debug = 1
               BEGIN
                  PRINT '>>> SQL: ' + @c_SQL
               END 

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
            ELSE IF @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y'
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
            END -- IF @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y'

            IF @n_FromQty > 0                                                     --(Wan04) - START 
            BEGIN                                                                 --use loop to get next loc for inv due to CommingleLot 
               SELECT @n_MaxCapacity = 0,                                         --& NotMixLottables Setup 
                  @n_QtyReplen   = 0
            
               SELECT @n_MaxCapacity = tsl.ReplenishmentCasecnt,
                      @n_QtyReplen   = SUM(tsl.QtyReplen)
               FROM #TempSKUxLOC AS tsl WITH(NOLOCK)
               WHERE StorerKey = @c_CurrentStorer
                  AND SKU = @c_CurrentSKU
                  AND LOC = @c_CurrentLoc
               GROUP BY tsl.ReplenishmentCasecnt
            
               IF @b_debug = 1
               BEGIN
                  PRINT '>>> @c_CurrentLoc: ' + @c_CurrentLoc
                  PRINT '>>> @n_MaxCapacity: ' + CAST(@n_MaxCapacity AS VARCHAR) + ', @n_QtyReplen: ' + CAST(@n_QtyReplen AS VARCHAR) + ', @n_FromQty: ' + CAST(@n_FromQty AS VARCHAR)
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
                        AND SKU = @c_CurrentSKU
                        AND LOC <> @c_CurrentLoc
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
            END -- @n_FromQty > 0                                                 

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
                  , SKU
                  , FromLOC
                  , ToLOC
                  , Lot
                  , Id
                  , Qty
                  , UOM
                  , PackKey
                  , Priority
                  , QtyMoved
                  , QtyInPickLOC
                  , ReplLottable01                                               --(Wan03)
                  , ReplLottable02
                  , ReplLottable03                                               --(Wan03)
                  , ReplLottable04                                               --(Wan03)
                  , ReplLottable05                                               --(Wan03)
                  , ReplLottable06                                               --(Wan03)
                  , ReplLottable07                                               --(Wan03)
                  , ReplLottable08                                               --(Wan03)
                  , ReplLottable09                                               --(Wan03)
                  , ReplLottable10                                               --(Wan03)
                  , ReplLottable11                                               --(Wan03)
                  , ReplLottable12                                               --(Wan03)
                  , ReplLottable13                                               --(Wan03)
                  , ReplLottable14                                               --(Wan03)
                  , ReplLottable15                                               --(Wan03)
                  )
               VALUES
                  (
                    @c_CurrentStorer
                  , @c_CurrentSKU
                  , @c_FromLOC
                  , @c_CurrentLoc
                  , @c_FromLot
                  , @c_FromID
                  , @n_FromQty
                  , @c_UOM
                  , @c_Packkey
                  , @c_CurrentPriority
                  , @n_QtyAllocated
                  , @n_QtyPicked
                  , @c_ReplLottable01                                            --(Wan03)
                  , @c_ReplLottable02
                  , @c_ReplLottable03                                            --(Wan03)
                  , @dt_ReplLottable04                                           --(Wan03)
                  , @dt_ReplLottable05                                           --(Wan03)
                  , @c_ReplLottable06                                            --(Wan03)
                  , @c_ReplLottable07                                            --(Wan03)
                  , @c_ReplLottable08                                            --(Wan03)
                  , @c_ReplLottable09                                            --(Wan03)
                  , @c_ReplLottable10                                            --(Wan03)
                  , @c_ReplLottable11                                            --(Wan03)
                  , @c_ReplLottable12                                            --(Wan03)
                  , @dt_ReplLottable13                                           --(Wan03)
                  , @dt_ReplLottable14                                           --(Wan03)
                  , @dt_ReplLottable15                                           --(Wan03)
                  )
               IF @b_debug = 1
               BEGIN
                  SELECT 'INSERTED : ' as Title, @c_CurrentSKU ' SKU', @c_fromlot 'LOT', @c_CurrentLoc 'LOC', @c_FromID 'ID',
                        @n_FromQty 'Qty'
               END

               UPDATE #TempSKUxLOC
               SET SELECTED = 1, QtyReplen = QtyReplen + @n_FromQty
                  WHERE StorerKey = @c_CurrentStorer
                  AND SKU = @c_CurrentSKU
                  AND LOC = @c_CurrentLoc
                  AND LOT = @c_FromLot

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
                                       ,  @c_ReplLottable01                         --(Wan03)
                                       ,  @c_ReplLottable02
                                       ,  @c_ReplLottable03                         --(Wan03)
                                       ,  @dt_ReplLottable04                        --(Wan03)
                                       ,  @dt_ReplLottable05                        --(Wan03)
                                       ,  @c_ReplLottable06                         --(Wan03)
                                       ,  @c_ReplLottable07                         --(Wan03)
                                       ,  @c_ReplLottable08                         --(Wan03)
                                       ,  @c_ReplLottable09                         --(Wan03)
                                       ,  @c_ReplLottable10                         --(Wan03)
                                       ,  @c_ReplLottable11                         --(Wan03)
                                       ,  @c_ReplLottable12                         --(Wan03)
                                       ,  @dt_ReplLottable13                        --(Wan03)
                                       ,  @dt_ReplLottable14                        --(Wan03)
                                       ,  @dt_ReplLottable15                        --(Wan03)
         END
         -- LOT
         CLOSE CUR_REPL
         DEALLOCATE CUR_REPL

         NEXT_SKUxLOC:
         -- (SWT01)
         IF @n_RemainingQty <= 0 AND NOT EXISTS(SELECT 1
            FROM #SkipSKU
            WHERE SKU = @c_CurrentSKU)
         BEGIN
            INSERT INTO #SkipSKU
                (SKU)
            VALUES
                (@c_CurrentSKU)
        END

        FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentStorer
                                       ,  @c_CurrentSKU
                                       ,  @c_CurrentLoc
                                       ,  @n_CurrentSeverity
                                       ,  @c_CurrentPriority
                                       ,  @c_ToLocationtype
                                       ,  @c_Packkey
                                       ,  @c_NoMixLottable01                        --(Wan03)
                                       ,  @c_NoMixLottable02                          
                                       ,  @c_NoMixLottable03                        --(Wan03)
                                       ,  @c_NoMixLottable04                        --(Wan03)
                                       ,  @c_NoMixLottable05                        --(Wan03)
                                       ,  @c_NoMixLottable06                        --(Wan03)
                                       ,  @c_NoMixLottable07                        --(Wan03)
                                       ,  @c_NoMixLottable08                        --(Wan03)
                                       ,  @c_NoMixLottable09                        --(Wan03)
                                       ,  @c_NoMixLottable10                        --(Wan03)
                                       ,  @c_NoMixLottable11                        --(Wan03)
                                       ,  @c_NoMixLottable12                        --(Wan03)
                                       ,  @c_NoMixLottable13                        --(Wan03)
                                       ,  @c_NoMixLottable14                        --(Wan03)
                                       ,  @c_NoMixLottable15                        --(Wan03)
                                       ,  @c_CommingleLot                           --(Wan03)
    END
    -- -- FOR SKUxLOC
    CLOSE CUR_SKUxLOC
    DEALLOCATE CUR_SKUxLOC

    IF @b_Debug = 1
    BEGIN
      SELECT * FROM #Replenishment R
    END 
    /* Insert Into Replenishment Table Now */
    DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT R.FromLoc
            , R.Id
            , R.ToLoc
            , R.Sku
            , R.Qty
            , R.StorerKey
            , R.Lot
            , R.PackKey
            , R.Priority
            , R.UOM
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
         IF @c_ReplenType = 'R'  
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
               IF EXISTS( SELECT 1
               FROM LOC WITH (NOLOCK)
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
                   , ReplenishmentKey
                   , StorerKey
                   , Sku
                   , FromLoc
                   , ToLoc
                   , Lot
                   , Id
                   , Qty
                   , UOM
                   , PackKey
                   , Confirmed
                   , RefNo
                   , QtyReplen
                   , Wavekey
                   , PendingMoveIn
                   , ToID
                   )
               VALUES
                   (
                    @c_ReplenishmentGroup
                  , @c_ReplenishmentKey
                  , @c_CurrentStorer
                  , @c_CurrentSKU
                  , @c_FromLOC
                  , @c_CurrentLoc
                  , @c_FromLot
                  , @c_FromID
                  , @n_FromQty
                  , @c_UOM
                  , @c_PackKey
                  , 'N'
                  , ''
                  , @n_FromQty
                  , @c_Wavekey
                  , @n_FromQty
                  , @c_ToID
                  )
                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err),@n_err = 62081       
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                              ': Insert Into Replenishment Failed (isp_ODMRPL01)'   
                           +' ( '+' SQLSvr MESSAGE='+ TRIM(@c_ErrMsg) +' ) '  
            END  
            END -- IF @b_success = 1
         END -- IF @c_ReplenType = 'R'  
         IF @c_ReplenType = 'T'
         BEGIN
            SELECT @c_FromLogicalLoc = LOC.LogicalLocation 
            FROM LOC WITH (NOLOCK)
            WHERE LOC = @c_FromLOC

            SELECT @c_ToLogicalLoc = LOC.LogicalLocation 
            FROM LOC WITH (NOLOCK)
            WHERE LOC = @c_CurrentLoc
            
            SELECT TOP 1 @c_FromAreaKey = AREADETAIL.Areakey  
            FROM LOC (NOLOCK)  
            JOIN AREADETAIL ON (LOC.PutawayZone = AREADETAIL.PutawayZone)  
            WHERE LOC.Loc = @c_FromLOC  

            SELECT @b_success = 1  
            EXECUTE nspg_getkey  
            'TaskDetailKey'  
            , 10  
            , @c_TaskDetailKey OUTPUT  
            , @b_success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT  
            IF NOT @b_success = 1  
            BEGIN  
               SELECT @n_continue = 3           
               SELECT @n_err = 62080  
               SELECT @c_errmsg = 'isp_ODMRPL01: ' + Trim(@c_errmsg)  
            END  

            INSERT INTO TASKDETAIL  
            (  
               TaskDetailKey
               ,TaskType
               ,Storerkey
               ,Sku
               ,Lot
               ,UOM
               ,UOMQty
               ,Qty
               ,FromLoc
               ,LogicalFromLoc
               ,FromID
               ,ToLoc
               ,LogicalToLoc
               ,ToID
               ,Caseid
               ,PickMethod
               ,Status
               ,StatusMsg
               ,Priority
               ,SourcePriority
               ,Holdkey
               ,UserKey
               ,UserPosition
               ,UserKeyOverRide
               ,SourceType
               ,SourceKey
               ,Message03
               ,SystemQty
               ,RefTaskKey
               ,AreaKey
               ,FinalLOC
               ,FinalID
               ,Groupkey
               ,QtyReplen
            )  
            VALUES  
            (  
                @c_TaskDetailKey  
               ,'VNAOUT'
               ,@c_CurrentStorer
               ,@c_CurrentSKU
               ,@c_FromLot
               ,1
               ,@n_FromQty
               ,@n_FromQty
               ,@c_FromLOC
               ,@c_FromLogicalLoc
               ,@c_FromID
               ,@c_CurrentLoc
               ,@c_ToLogicalLoc
               ,@c_FromID
               ,'' -- Case ID
               ,'FP' -- PickMethod
               ,'Q' -- Status
               , '' -- StatusMsg
               ,'1' -- Priority                                        --(Wan01)(SSA01)
               ,'' -- Source Priority
               ,'' -- Hold Key
               ,'' -- UserKey
               ,'1' -- User Position
               ,'' -- UserKeyOverRide
               ,'isp_ODMRPL01'
               , @c_ReplenishmentKey -- SourceKey
               ,'RPF'
               ,@n_FromQty
               ,'' -- RefTaskKey
               ,@c_FromAreaKey
               ,@c_CurrentLoc
               ,@c_FromID
               ,@c_TaskDetailKey -- Groupkey
               ,@n_FromQty -- Qty Replen, set to Zero, otherwise will double the qty since replenishment add trigger already calculated.
            )    
        
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err),@n_err = 62081       
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                        ': Insert Into TaskDetail Failed (isp_ODMRPL01)'   
                     +' ( '+' SQLSvr MESSAGE='+ TRIM(@c_ErrMsg) +' ) '  
            END  

            -- Force Calculated Pending Move In Qty
            SET @n_Err = 0 
            EXEC rdt.rdt_Putaway_PendingMoveIn   
                   @cUserName = ''  
                  ,@cType = 'LOCK'  
                  ,@cFromLoc = @c_FromLOC  
                  ,@cFromID = @c_FromID  
                  ,@cSuggestedLOC = @c_CurrentLoc  
                  ,@cStorerKey = @c_CurrentStorer  
                  ,@nErrNo = @n_Err OUTPUT  
                  ,@cErrMsg = @c_Errmsg OUTPUT  
                  ,@cSKU = @c_CurrentSKU  
                  ,@nPutawayQTY    = @n_FromQty  
                  ,@cFromLOT       = @c_FromLot  
                  ,@cTaskDetailKey = @c_TaskdetailKey  
                  ,@nFunc = 0  
                  ,@nPABookingKey = 0  
                  ,@cMoveQTYAlloc = '1'  
                  ,@cMoveQTYReplen='1'
                                                                                                                     
            IF @n_err <> 0                                                                                     
            BEGIN                                                                                              
               SELECT @n_continue = 3  
                     ,@n_err = 67994   
               SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                        ':  Execute rdt.rdt_Putaway_PendingMoveIn Failed! (isp_ODMRPL01)'  
            END                                             

         END -- IF @c_ReplenType = 'T'

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
    END
    -- While
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

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO
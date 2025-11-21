SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_WOInvReserveProcessing                              */
/* Creation Date: 13-DEC-2012                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: VAS Reserve Inv Processing                                  */
/*                                                                      */
/* Called By: isp_WOJobInvReserve                                       */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */ 
/* 28-May-2014  TKLIM   1.1   Added Lottables 06-15                     */
/* 12-Jan-2016  Wan01   1.2   Reserved Mix SKu on 1 Pallet              */
/* 12-Jan-2016  Wan02   1.21  Manual Reserved                           */ 
/* 04-FEB-2016  Wan03   1.1   SOS#361353 - Project Merlion -SKU         */
/*                            Reservation Pallet Selection              */   
/************************************************************************/
CREATE PROC  [dbo].[isp_WOInvReserveProcessing]  
               @c_JobKey   NVARCHAR(10)
,              @b_Success  INT            OUTPUT
,              @n_err      INT            OUTPUT
,              @c_errmsg   NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue                 INT
         , @n_StartTCnt                INT -- Holds the current transaction count
         , @n_cnt                      INT -- Holds @@ROWCOUNT after certain operations
         , @b_debug                    INT -- Debug: 0 - OFF, 1 - show all, 2 - map

   DECLARE @c_MinShelfLife60Mth        NVARCHAR(10)
         , @c_ShelfLifeInDays          NVARCHAR(10)       

   DECLARE @c_aFacility                NVARCHAR(5)
         , @c_aStorerkey               NVARCHAR(15)
         , @c_aSku                     NVARCHAR(20)
         , @c_aPackKey                 NVARCHAR(10)
         , @c_aUOM                     NVARCHAR(10)
         , @n_aUOMQty                  INT 
         , @n_aQtyLeftToFulfill        INT
         , @c_aLot                     NVARCHAR(10)
         , @c_aStrategyKey             NVARCHAR(10)

         , @c_MoveRefKey               NVARCHAR(10)
         , @c_Storerkey                NVARCHAR(15)
         , @c_Sku                      NVARCHAR(20)
         , @c_Lot                      NVARCHAR(10)
         , @n_Qty                      INT 
         , @n_NotToMove                INT

         , @n_MinShelfLife             INT
         , @c_JobLineNo                NVARCHAR(5)
         , @c_PackKey                  NVARCHAR(10)
         , @c_UOM                      NVARCHAR(10)
         , @c_PullUOM                  NVARCHAR(10)
         , @c_TmpLoc                   NVARCHAR(10)
         , @c_Lottable01               NVARCHAR(18)
         , @c_Lottable02               NVARCHAR(18)
         , @c_Lottable03               NVARCHAR(18)
         , @dt_Lottable04              DATETIME
         , @dt_Lottable05              DATETIME
         , @c_Lottable06               NVARCHAR(30)
         , @c_Lottable07               NVARCHAR(30)
         , @c_Lottable08               NVARCHAR(30)
         , @c_Lottable09               NVARCHAR(30)
         , @c_Lottable10               NVARCHAR(30)
         , @c_Lottable11               NVARCHAR(30)
         , @c_Lottable12               NVARCHAR(30)
         , @dt_Lottable13              DATETIME
         , @dt_Lottable14              DATETIME
         , @dt_Lottable15              DATETIME

   DECLARE @n_Caseqty                  INT
         , @n_Palletqty                INT
         , @n_Innerpackqty             INT
         , @n_Otherunit1               INT 
         , @n_Otherunit2               INT
         , @n_PackQty                  INT

   DECLARE @n_SeqNo                    INT
         , @n_CursorCandidates_Open    INT
         , @n_OriginUOMQty             INT
         , @c_OriginUOM                NVARCHAR(10)
         , @c_PStorerkey               NVARCHAR(15)
         
   DECLARE @n_NumberOfRetries          INT
         , @c_ALLineNo                 NVARCHAR(5)
         , @c_AAllocateStrategyKey     NVARCHAR(10)
         , @c_AllocatePickCode         NVARCHAR(10)
         , @c_HostWHCode               NVARCHAR(10)
         , @c_EndString                NVARCHAR(50)
         , @c_OtherParms               NVARCHAR(255)
         , @c_Loc                      NVARCHAR(10)
         , @c_ID                       NVARCHAR(18)
         , @n_Available                INT  
         , @n_QtyAvailable             INT
         , @n_QtyToTake                INT

   DECLARE @b_JobMoveInsertSuccess     INT
         , @n_QtyToInsert              INT
         , @n_MoveQty                  INT
         , @n_QtyToMove                INT
         , @c_JobReserveKey            NVARCHAR(10)         --(Wan03)         
         , @c_PTmpLoc                  NVARCHAR(10)
         , @c_Sourcekey                NVARCHAR(20)

   DECLARE @c_ExecuteSP                NVARCHAR(MAX)
         , @c_ParmName                 NVARCHAR(255)
         , @c_LocType                  NVARCHAR(20)

   SET @n_StartTCnt              =  @@TRANCOUNT 
   SET @n_continue               =  1           
   SET @b_success                =  0           
   SET @n_err                    =  0           
   SET @c_errmsg                 =  ''          
   SET @b_debug                  =  0          
        
   SET @c_MinShelfLife60Mth      = ''
   SET @c_ShelfLifeInDays        = ''

   SET @c_aFacility              = ''                         
   SET @c_aStorerkey             = ''  
   SET @c_aSku                   = ''     
   SET @c_aPackKey               = ''
   SET @c_aUOM                   = '' 
   SET @n_aUOMQty                = 0  
   SET @n_aQtyLeftToFulfill      = 0       
   SET @c_aLot                   = ''
   SET @c_aStrategyKey           = ''
 
   SET @c_JobLineNo              = '' 
   SET @c_Packkey                = ''
   SET @c_UOM                    = ''
   SET @c_PullUOM                = ''
   SET @c_TmpLoc                 = ''    
   SET @n_MinShelfLife           = 0      
   SET @c_Lottable01             = ''     
   SET @c_Lottable02             = ''     
   SET @c_Lottable03             = ''     
   SET @dt_Lottable04             = ''   
   SET @dt_Lottable05             = '' 
   SET @c_Lottable06             = ''
   SET @c_Lottable07             = ''
   SET @c_Lottable08             = ''
   SET @c_Lottable09             = ''
   SET @c_Lottable10             = ''
   SET @c_Lottable11             = ''
   SET @c_Lottable12             = ''
   SET @dt_Lottable13             = ''
   SET @dt_Lottable14             = ''
   SET @dt_Lottable15             = ''

   SET @n_Caseqty                = 0
   SET @n_Palletqty              = 0
   SET @n_Innerpackqty           = 0
   SET @n_Otherunit1             = 0
   SET @n_Otherunit2             = 0

   SET @n_PackQty                = 0

   SET @n_SeqNo                  = 0
   SET @n_CursorCandidates_Open  = 0
   SET @n_OriginUOMQty           = 0
   SET @c_OriginUOM              = ''
   SET @c_PStorerkey             = ''

   SET @n_NumberOfRetries        = 0
   SET @c_ALLineNo               = ''
   SET @c_AAllocateStrategyKey   = ''
   SET @c_AllocatePickCode       = ''
   SET @c_HostWHCode             = ''
   SET @c_ENDString              = ''
   SET @c_OtherParms             = ''

   SET @c_Loc                    = ''
   SET @c_ID                     = ''

   SET @n_Available              = 0           
   SET @n_QtyAvailable           = 0
   SET @n_QtyToTake              = 0

   SET @b_JobMoveInsertSuccess   = 0
   SET @n_QtyToInsert            = 0
   SET @n_MoveQty                = 0
   SET @n_QtyToMove              = 0
   SET @c_PTmpLoc                = 0
   SET @c_Sourcekey              = 0

   CREATE TABLE #OPJOBLINES 
         (  [SeqNo]                    [INT] IDENTITY(1, 1)
         ,  [PreAllocatePickDetailKey] [NVARCHAR](10) NOT NULL
         ,  [Facility]                 [NVARCHAR](5)  NOT NULL
         ,  [JobKey]                   [NVARCHAR](10) NOT NULL
         ,  [JobLine]                  [NVARCHAR](5)  NOT NULL
         ,  [Storerkey]                [NVARCHAR](15) NOT NULL
         ,  [Sku]                      [NVARCHAR](20) NOT NULL
         ,  [Lot]                      [NVARCHAR](10) NOT NULL
         ,  [UOM]                      [NVARCHAR](5)  NOT NULL
         ,  [UOMQty]                   [INT]          NOT NULL
         ,  [Qty]                      [INT]          NOT NULL
         ,  [Packkey]                  [NVARCHAR](10) NOT NULL
         ,  [PreAllocateStrategyKey]   [NVARCHAR](10) NOT NULL
         ,  [PreAllocatePickCode]      [NVARCHAR](10) NOT NULL
         ,  [StrategyKey]              [NVARCHAR](10) NOT NULL
         ,  [PullUOM]                  [NVARCHAR](10) NOT NULL
         ,  [TmpLoc]                   [NVARCHAR](10) NOT NULL
         ,  [MinShelf]                 [INT]          NOT NULL
         ,  [Lottable01]               [NVARCHAR](18) NOT NULL
         ,  [Lottable02]               [NVARCHAR](18) NOT NULL
         ,  [Lottable03]               [NVARCHAR](18) NOT NULL
         ,  [Lottable04]               [DATETIME]     NOT NULL
         ,  [Lottable05]               [DATETIME]     NOT NULL
         ,  [Lottable06]               [NVARCHAR](30) NOT NULL
         ,  [Lottable07]               [NVARCHAR](30) NOT NULL
         ,  [Lottable08]               [NVARCHAR](30) NOT NULL
         ,  [Lottable09]               [NVARCHAR](30) NOT NULL
         ,  [Lottable10]               [NVARCHAR](30) NOT NULL
         ,  [Lottable11]               [NVARCHAR](30) NOT NULL
         ,  [Lottable12]               [NVARCHAR](30) NOT NULL
         ,  [Lottable13]               [DATETIME]     NOT NULL
         ,  [Lottable14]               [DATETIME]     NOT NULL
         ,  [Lottable15]               [DATETIME]     NOT NULL
         )

   INSERT INTO #OPJOBLINES
         (  [PreAllocatePickDetailKey]
         ,  [Facility]                  
         ,  [JobKey]                    
         ,  [JobLine]                   
         ,  [Storerkey]                 
         ,  [Sku] 
         ,  [Lot] 
         ,  [UOM]                       
         ,  [UOMQty]                    
         ,  [Qty]                       
         ,  [Packkey]                   
         ,  [PreAllocateStrategyKey]    
         ,  [PreAllocatePickCode]       
         ,  [StrategyKey]
         ,  [PullUOM] 
         ,  [TmpLoc]
         ,  [MinShelf]  
         ,  [Lottable01] 
         ,  [Lottable02] 
         ,  [Lottable03] 
         ,  [Lottable04] 
         ,  [Lottable05] 
         ,  [Lottable06] 
         ,  [Lottable07] 
         ,  [Lottable08] 
         ,  [Lottable09] 
         ,  [Lottable10] 
         ,  [Lottable11] 
         ,  [Lottable12] 
         ,  [Lottable13] 
         ,  [Lottable14] 
         ,  [Lottable15] 
            
         )
   SELECT   PreAllocatePickDetailKey = '' 
         ,  Facility = ISNULL(RTRIM(WOJD.Facility),'')
         ,  JobKey   = ISNULL(RTRIM(WOJO.JobKey),'')
         ,  JobLine  = ISNULL(RTRIM(WOJO.JobLine),'')
         ,  Storerkey= ISNULL(RTRIM(WOJO.Storerkey),'')
         ,  Sku      = ISNULL(RTRIM(WOJO.Sku),'')
         ,  LOT      = ''
         ,  UOM      = ''
         ,  UOMQty   = '1'
         ,  Qty      = ISNULL(WOJO.StepQty - (WOJO.QtyReserved + WOJO.QtyCompleted),0)
         ,  Packkey  = ISNULL(RTRIM(SKU.Packkey),'')
         ,  PreAllocateStrategyKey = ''
         ,  PreAllocatePickCode    = ''
         ,  StrategyKey = ISNULL(RTRIM(STGY.VASStrategyKey),'')
         ,  PullUOM     = CASE WOJO.PullUOM  WHEN ''            THEN '6'
                                             WHEN PACK.PackUOM4 THEN '1'
                                             WHEN PACK.PackUOM1 THEN '2'
                                             WHEN PACK.PackUOM2 THEN '3'
                                             WHEN PACK.PackUOM8 THEN '4'
                                             WHEN PACK.PackUOM9 THEN '5'
                                             WHEN PACK.PackUOM3 THEN '6'
                                             ELSE '7'
                                             END
         ,  TmpLoc      = ISNULL(RTRIM(WOJO.FromLoc),'')
         ,  MinShelf    = ISNULL(WOJO.MinShelf,0)
         ,  Lottable01  = ISNULL(RTRIM(WOJO.Lottable01),'')
         ,  Lottable02  = ISNULL(RTRIM(WOJO.Lottable02),'')
         ,  Lottable03  = ISNULL(RTRIM(WOJO.Lottable03),'')
         ,  Lottable04  = ISNULL(WOJO.Lottable04, '19000101')
         ,  Lottable05  = ISNULL(WOJO.Lottable05, '19000101')
         ,  Lottable06  = ISNULL(RTRIM(WOJO.Lottable06),'')
         ,  Lottable07  = ISNULL(RTRIM(WOJO.Lottable07),'')
         ,  Lottable08  = ISNULL(RTRIM(WOJO.Lottable08),'')
         ,  Lottable09  = ISNULL(RTRIM(WOJO.Lottable09),'')
         ,  Lottable10  = ISNULL(RTRIM(WOJO.Lottable10),'')
         ,  Lottable11  = ISNULL(RTRIM(WOJO.Lottable11),'')
         ,  Lottable12  = ISNULL(RTRIM(WOJO.Lottable12),'')
         ,  Lottable13  = ISNULL(WOJO.Lottable13, '19000101')
         ,  Lottable14  = ISNULL(WOJO.Lottable14, '19000101')
         ,  Lottable15  = ISNULL(WOJO.Lottable15, '19000101')
      FROM  WORKORDERJOBDETAIL    WOJD WITH (NOLOCK)
      JOIN  WORKORDERJOBOPERATION WOJO WITH (NOLOCK) ON (WOJD.JobKey = WOJO.JobKey)
      JOIN  STRATEGY              STGY WITH (NOLOCK) ON (WOJO.Rotation = STGY.StrategyKey)
      JOIN  SKU                   SKU  WITH (NOLOCK) ON (SKU.StorerKey = WOJO.StorerKey) AND (SKU.Sku = WOJO.Sku)
      JOIN  PACK                  PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
      WHERE WOJD.Jobkey = @c_jobKey
      AND   WOJO.WOOperation IN ( 'asrs pull', 'vas pick')
      AND   (WOJO.Storerkey <> '' AND WOJO.Sku <> '') 
      AND   ISNULL(WOJO.StepQty - WOJO.QtyReserved,0) > 0
      ORDER BY JobLine

   --DELETE FROM WORKORDERJOBMOVE WITH (ROWLOCK)
   --WHERE JobKey = @c_JobKey
   --AND   Status = '0'

   DECLARE JOBLINES_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   #OPJOBLINES.JobKey
         ,  #OPJOBLINES.JobLine
         ,  #OPJOBLINES.Facility
         ,  #OPJOBLINES.StorerKey
         ,  #OPJOBLINES.SKU
         ,  #OPJOBLINES.PackKey
         ,  #OPJOBLINES.UOM
         ,  #OPJOBLINES.LOT
         ,  #OPJOBLINES.UOMQty 
         ,  #OPJOBLINES.Qty
         ,  #OPJOBLINES.StrategyKey
         ,  #OPJOBLINES.MinShelf 
         ,  #OPJOBLINES.PullUOM   
         ,  #OPJOBLINES.TmpLoc
         --,  CASE WHEN #OPJOBLINES.PullUOM = 1 THEN ISNULL(RTRIM(#OPJOBLINES.TmpLoc),'') ELSE '<TMPLOC>' END
         ,  #OPJOBLINES.Lottable01 
         ,  #OPJOBLINES.Lottable02
         ,  #OPJOBLINES.Lottable03 
         ,  #OPJOBLINES.Lottable04 
         ,  #OPJOBLINES.Lottable05 
         ,  #OPJOBLINES.Lottable06 
         ,  #OPJOBLINES.Lottable07 
         ,  #OPJOBLINES.Lottable08 
         ,  #OPJOBLINES.Lottable09 
         ,  #OPJOBLINES.Lottable10 
         ,  #OPJOBLINES.Lottable11 
         ,  #OPJOBLINES.Lottable12 
         ,  #OPJOBLINES.Lottable13 
         ,  #OPJOBLINES.Lottable14 
         ,  #OPJOBLINES.Lottable15
     FROM #OPJOBLINES 
     JOIN WORKORDERJOBOPERATION WOJO WITH (NOLOCK) ON (#OPJOBLINES.JobKey = WOJO.JobKey) AND (#OPJOBLINES.JobLine = WOJO.JobLine)            

   OPEN JOBLINES_CUR
   FETCH NEXT FROM JOBLINES_CUR INTO @c_JobKey
                                    ,@c_JobLineNo
                                    ,@c_aFacility
                                    ,@c_aStorerkey
                                    ,@c_aSku
                                    ,@c_aPackKey  
                                    ,@c_aUOM
                                    ,@c_aLot
                                    ,@n_aUOMQty 
                                    ,@n_aQtyLeftToFulfill 
                                    ,@c_aStrategyKey
                                    ,@n_MinShelfLife
                                    ,@c_PullUOM
                                    ,@c_TmpLoc
                                    ,@c_Lottable01
                                    ,@c_Lottable02
                                    ,@c_Lottable03
                                    ,@dt_Lottable04
                                    ,@dt_Lottable05  
                                    ,@c_Lottable06
                                    ,@c_Lottable07
                                    ,@c_Lottable08
                                    ,@c_Lottable09
                                    ,@c_Lottable10
                                    ,@c_Lottable11
                                    ,@c_Lottable12
                                    ,@dt_Lottable13
                                    ,@dt_Lottable14
                                    ,@dt_Lottable15

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SET @c_OriginUOM    = @c_aUOM
      SET @n_OriginUOMQty = @n_aUOMQty

      IF @c_aStorerkey <> @c_PStorerkey 
      BEGIN
         SET @b_success = 0
         EXECUTE nspGetRight null            -- facility
               , @c_aStorerkey               -- StorerKey
               , null                        -- Sku
               , 'MinShelfLife60Mth'         -- Configkey
               , @b_success                  OUTPUT 
               , @c_MinShelfLife60Mth        OUTPUT 
               , @n_err                      OUTPUT 
               , @c_errmsg                   OUTPUT

         If @b_success = 0
         BEGIN
             SET @n_continue = 3
             SET @c_errmsg = 'isp_WOInvReserveProcessing : ' + RTRIM(@c_errmsg) 
             GOTO EXIT_SP
         END
      
         SET @b_success = 0
         EXECUTE nspGetRight null            -- facility
               , @c_aStorerkey                -- StorerKey
               , null                        -- Sku
               , 'ShelfLifeInDays'           -- Configkey
               , @b_success                  OUTPUT 
               , @c_ShelfLifeInDays          OUTPUT 
               , @n_err                      OUTPUT 
               , @c_errmsg                   OUTPUT

         If @b_success = 0
         BEGIN
             SET @n_continue = 3
             SET @c_errmsg = 'isp_WOInvReserveProcessing : ' + RTRIM(@c_errmsg) 
             GOTO EXIT_SP
         END
      END

      IF @n_MinShelfLife IS NULL OR @n_MinShelfLife = 0
      BEGIN     
         SET @n_MinShelfLife = 0   
      END 
      ELSE IF @c_MinShelfLife60Mth = '1' 
      BEGIN
         IF @n_MinShelfLife < 61    
            SET @n_MinShelfLife = @n_MinShelfLife * 30 
      END
      ELSE IF @c_ShelfLifeInDays = '1'            
      BEGIN
         SET @n_MinShelfLife = @n_MinShelfLife   
      END                                           
      ELSE IF @n_MinShelfLife < 13  
      BEGIN  
         SET @n_MinShelfLife = @n_MinShelfLife * 30    
      END 
 
      IF @n_MinShelfLife <> 0  
      BEGIN
         SET @c_aLot = '*' + CONVERT(NVARCHAR(5), @n_MinShelfLife)
      END

      SET @c_ALLineNo = ''
      SET @n_NumberOfRetries = 0

      LOOPPICKSTRATEGY:
      WHILE @n_NumberOfRetries <= 7 and @c_aUOM <= 9 and @n_aQtyLeftToFulfill > 0
      BEGIN
         GET_NEXT_STRATEGY:

         SELECT TOP 1
                @c_ALLineNo = AllocateStrategyLineNumber 
               ,@c_AllocatePickCode = Pickcode
               ,@c_AUOM     = UOM  
         FROM ALLOCATESTRATEGYDETAIL WITH (NOLOCK)
         WHERE AllocateStrategyLineNumber > @c_ALLineNo
         AND AllocateStrategyKey = @c_aStrategyKey
         ORDER BY AllocateStrategyLineNumber
 

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         SELECT @n_PalletQty = Pallet 
              , @n_CaseQty = CaseCnt 
              , @n_InnerPackQty = InnerPack 
              , @n_OtherUnit1 = CONVERT(INT,OtherUnit1) 
              , @n_OtherUnit2 = CONVERT(INT,OtherUnit2) 
         FROM PACK (NOLOCK)
         WHERE PackKey = @c_aPackKey

         SET @n_aUOMQty = CASE @c_aUOM WHEN '1' THEN @n_PalletQty
                                       WHEN '2' THEN @n_CaseQty
                                       WHEN '3' THEN @n_InnerPackQty
                                       WHEN '4' THEN @n_OtherUnit1
                                       WHEN '5' THEN @n_OtherUnit2
                                       WHEN '6' THEN 1
                                       WHEN '7' THEN 1
                                       ELSE 0
                                       END

         SET @n_PackQty = @n_aUOMQty

         IF @b_debug = 1 OR @b_debug = 2
         BEGIN
            PRINT ''
            PRINT '********** GET_NEXT_STRATEGY **********'
            PRINT '--> @c_aUOM: ' + @c_aUOM
            PRINT '--> @n_PackQty: ' + CAST(@n_PackQty AS VARCHAR(10))
            PRINT '--> @n_aQtyLeftToFulfill: ' +  CAST(@n_aQtyLeftToFulfill AS VARCHAR(10))
            PRINT '--> @c_TmpLoc: ' + @c_TmpLoc
         END

         IF @n_PackQty > @n_aQtyLeftToFulfill 
            GOTO GET_NEXT_STRATEGY

         DECLARECURSOR_CANDIDATES:
         --SET @c_endstring = CONVERT(NVARCHAR(10),@n_PackQty) + ',' + CONVERT(NVARCHAR(10), @n_aQtyLeftToFulfill)
                         -- + ',N''' + SPACE(15) + @c_TmpLoc + ''''

         SET @c_OtherParms = RTRIM(@c_JobKey) + RTRIM(@c_JobLineNo) + RTRIM(@c_TmpLoc)    --(Wan01)
         SET @c_ExecuteSP = ''

         DECLARE CUR_PARM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PARAMETER_NAME
         FROM [INFORMATION_SCHEMA].[PARAMETERS] 
         WHERE SPECIFIC_NAME = @c_AllocatePickCode 
         ORDER BY ORDINAL_POSITION

         OPEN CUR_PARM
         FETCH NEXT FROM CUR_PARM INTO @c_ParmName

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_ExecuteSP = RTRIM(@c_ExecuteSP) + 
            CASE @c_ParmName
               WHEN '@c_Lot'        THEN ',@c_Lot        = N''' + RTRIM(@c_aLot) + ''''
               WHEN '@c_Facility'   THEN ',@c_Facility   = N''' + RTRIM(@c_aFacility) + ''''
               WHEN '@c_StorerKey'  THEN ',@c_StorerKey  = N''' + RTRIM(@c_aStorerKey) + ''''
               WHEN '@c_SKU'        THEN ',@c_SKU        = N''' + RTRIM(@c_aSKU) + '''' 
               WHEN '@c_Lottable01' THEN ',@c_Lottable01 = N''' + RTRIM(@c_Lottable01) + '''' 
               WHEN '@c_Lottable02' THEN ',@c_Lottable02 = N''' + RTRIM(@c_Lottable02) + '''' 
               WHEN '@c_Lottable03' THEN ',@c_Lottable03 = N''' + RTRIM(@c_Lottable03) + '''' 
               WHEN '@d_Lottable04' THEN ',@d_Lottable04 = N''' + ISNULL(CONVERT(NVARCHAR(20), @dt_Lottable04),'') + ''''  
               WHEN '@c_Lottable04' THEN ',@c_Lottable04 = N''' + ISNULL(CONVERT(NVARCHAR(20), @dt_Lottable04),'') + ''''  
               WHEN '@d_Lottable05' THEN ',@d_Lottable05 = N''' + ISNULL(CONVERT(NVARCHAR(20), @dt_Lottable05),'') + ''''  
               WHEN '@c_Lottable05' THEN ',@c_Lottable05 = N''' + ISNULL(CONVERT(NVARCHAR(20), @dt_Lottable05),'') + ''''  
               WHEN '@c_Lottable06' THEN ',@c_Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
               WHEN '@c_Lottable07' THEN ',@c_Lottable07 = N''' + RTRIM(@c_Lottable07) + '''' 
               WHEN '@c_Lottable08' THEN ',@c_Lottable08 = N''' + RTRIM(@c_Lottable08) + '''' 
               WHEN '@c_Lottable09' THEN ',@c_Lottable09 = N''' + RTRIM(@c_Lottable09) + ''''  
               WHEN '@c_Lottable10' THEN ',@c_Lottable10 = N''' + RTRIM(@c_Lottable10) + ''''  
               WHEN '@c_Lottable11' THEN ',@c_Lottable11 = N''' + RTRIM(@c_Lottable11) + '''' 
               WHEN '@c_Lottable12' THEN ',@c_Lottable12 = N''' + RTRIM(@c_Lottable12) + '''' 
               WHEN '@d_Lottable13' THEN ',@d_Lottable13 = N''' + ISNULL(CONVERT(NVARCHAR(20), @dt_Lottable13),'') + ''''    
               WHEN '@d_Lottable14' THEN ',@d_Lottable14 = N''' + ISNULL(CONVERT(NVARCHAR(20), @dt_Lottable14),'') + ''''    
               WHEN '@d_Lottable15' THEN ',@d_Lottable15 = N''' + ISNULL(CONVERT(NVARCHAR(20), @dt_Lottable15),'') + ''''    
               WHEN '@c_UOM'        THEN ',@c_UOM = N''' + RTRIM(@c_aUOM) + '''' 
               WHEN '@c_HostWHCode' THEN ',@c_HostWHCode = N''' + RTRIM(@c_HostWHCode) + '''' 
               WHEN '@n_UOMBase'    THEN ',@n_UOMBase= ' + CONVERT(NVARCHAR(10),@n_PackQty) 
               WHEN '@n_QtyLeftToFulfill' THEN ',@n_QtyLeftToFulfill=' + CONVERT(NVARCHAR(10), @n_aQtyLeftToFulfill) 
               WHEN '@c_OtherParms' THEN ',@c_OtherParms=''' + @c_OtherParms + ''''       --(Wan01)
            END 

            FETCH NEXT FROM CUR_PARM INTO @c_ParmName
         END 
         CLOSE CUR_PARM
         DEALLOCATE CUR_PARM   


         IF RTRIM(@c_ExecuteSP) = ''
         BEGIN
            GOTO EXIT_SP
         END

         SET @c_ExecuteSP = @c_AllocatePickCode + ' ' + RIGHT(@c_ExecuteSP, LEN(@c_ExecuteSP) - 1)
 
         EXEC (@c_ExecuteSP)

         SET @n_err = @@ERROR
         SET @n_cnt = @@ROWCOUNT

         IF @n_err = 16915
         BEGIN
            CLOSE CURSOR_CANDIDATES
            DEALLOCATE CURSOR_CANDIDATES
            GOTO DECLARECURSOR_CANDIDATES
         END

         OPEN CURSOR_CANDIDATES
         SET @n_err = @@ERROR
         SET @n_cnt = @@ROWCOUNT

         IF @n_err = 16905
         BEGIN
            CLOSE CURSOR_CANDIDATES
            DEALLOCATE CURSOR_CANDIDATES
            GOTO DECLARECURSOR_CANDIDATES
         END

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (nspOrderProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
            GOTO EXIT_SP
         END
         ELSE
         BEGIN
            SET @n_CursorCandidates_Open = 1
         END

         IF @n_CursorCandidates_Open = 1 
         BEGIN
            WHILE @n_aQtyLeftToFulfill > 0
            BEGIN
               FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_aLOT
                                                   ,  @c_loc
                                                   ,  @c_id
                                                   ,  @n_QtyAvailable
                                                   ,  @c_LocType
               IF @@FETCH_STATUS = -1
               BEGIN
                  BREAK
               END

               IF @@FETCH_STATUS = 0
               BEGIN
                  IF @n_PackQty > 0
                  BEGIN
                     SET @n_Available = FLOOR(@n_QtyAvailable / @n_PackQty) * @n_PackQty
                  END
                  ELSE
                  BEGIN
                     SET @n_Available = 0
                  END

                  IF @n_Available >= @n_aQtyLeftToFulfill
                  BEGIN
                     SET @n_QtyToTake = @n_aQtyLeftToFulfill
                  END
                  ELSE
                  BEGIN
                     SET @n_QtyToTake = @n_Available
                  END

                  IF @n_PackQty > 0
                  BEGIN
                     SET @n_QtyToTake = FLOOR(@n_QtyToTake / @n_PackQty) * @n_PackQty 
                  END

                  IF @b_debug = 1 or @b_debug = 2
                  BEGIN
                     PRINT 'Available:' + CAST(@n_Available AS NVARCHAR(10))
                     PRINT 'Qty To Take: ' + CAST(@n_QtyToTake AS NVARCHAR(10))
                     PRINT 'PullUOM:' + @c_PullUOM
                  END
               
                  IF @b_debug = 1
                  BEGIN
                     select @n_QtyAvailable, @n_Available, @c_aLot, @c_loc,  @c_id, @n_PackQty
                  END

--                  IF @c_PullUOM = '1'  -- if PullUOM is Pallet then all qty in the loc to take
--                  BEGIN
--                     IF @n_QtyAvailable >= @n_Available
--                     BEGIN
--                        SET @n_QtyToTake = @n_QtyAvailable
--                     END
--                  END

                  IF @b_debug = 1
                  BEGIN
                     select @n_QtyToTake
                  END

                  IF @n_QtyToTake > 0
                  BEGIN
                     GOTO UPDATEINV
                     RETURNFROMUPDATEINV:
                  END--@n_QtyToTake > 0
               END --@@FETCH_STATUS = 0
            END -- WHILE @n_aQtyLeftToFulfill > 0
         END 
        
         IF CURSOR_STATUS('GLOBAL', 'CURSOR_CANDIDATES') IN (0 , 1)
         BEGIN
            CLOSE CURSOR_CANDIDATES
            DEALLOCATE CURSOR_CANDIDATES
         END
      END -- END WHILE LOOPPICKSTRATEGY

      FETCH NEXT FROM JOBLINES_CUR INTO @c_JobKey
                                       ,@c_JobLineNo
                                       ,@c_aFacility
                                       ,@c_aStorerkey
                                       ,@c_aSku
                                       ,@c_aPackKey  
                                       ,@c_aUOM
                                       ,@c_aLot
                                       ,@n_aUOMQty  
                                       ,@n_aQtyLeftToFulfill 
                                       ,@c_aStrategyKey
                                       ,@n_MinShelfLife
                                       ,@c_PullUOM
                                       ,@c_TmpLoc
                                       ,@c_Lottable01
                                       ,@c_Lottable02
                                       ,@c_Lottable03
                                       ,@dt_Lottable04
                                       ,@dt_Lottable05  
                                       ,@c_Lottable06
                                       ,@c_Lottable07
                                       ,@c_Lottable08
                                       ,@c_Lottable09
                                       ,@c_Lottable10  
                                       ,@c_Lottable11
                                       ,@c_Lottable12
                                       ,@dt_Lottable13
                                       ,@dt_Lottable14
                                       ,@dt_Lottable15  
   END
   CLOSE JOBLINES_CUR
   DEALLOCATE JOBLINES_CUR

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL', 'CURSOR_CANDIDATES') IN (0 , 1)
   BEGIN
      CLOSE CURSOR_CANDIDATES
      DEALLOCATE CURSOR_CANDIDATES
   END

   /* #INCLUDE <SPPREOP2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
   ELSE 
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   RETURN
   END
   ELSE BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

   UPDATEINV:

   SET @b_JobMoveInsertSuccess = 1
   IF @b_JobMoveInsertSuccess = 1
   BEGIN
      --SET @n_NotToMove = 0
      SET @n_QtyToInsert = @n_QtyToTake

      IF (@b_debug = 1 OR @b_debug = 2)
      BEGIN
         PRINT ' '
         PRINT 'n_PickQty : ' + CAST(@n_MoveQty as varchar) + '  n_QtyToInsert : ' + Cast( @n_QtyToInsert as varchar)
      END

      IF @b_debug = 1
      BEGIN
         select @n_MoveQty '@n_MoveQty',@n_QtyToInsert '@n_QtyToInsert'
      END

      SET @n_aQtyLeftToFulfill = @n_aQtyLeftToFulfill - @n_QtyToInsert

      IF @b_debug = 1
      BEGIN
         select @n_aQtyLeftToFulfill '@n_aQtyLeftToFulfill'
      END

      IF @b_JobMoveInsertSuccess = 1
      BEGIN
         BEGIN TRANSACTION TROUTERLOOP

         SELECT @c_UOM = PackUOM3
         FROM PACK WITH (NOLOCK)
         WHERE Packkey = @c_aPackKey

         SET @c_JobReserveKey = ''
         SET @b_success = 0
         EXECUTE nspg_getkey
                'JOBRESERVEKEY'
               , 10
               , @c_JobReserveKey   OUTPUT
               , @b_success         OUTPUT
               , @n_err             OUTPUT
               , @c_ErrMsg          OUTPUT

         IF @b_success = 1 
         BEGIN
    
            INSERT INTO WORKORDERJOBMOVE 
                  (  JobReserveKey                 --(Wan03)
                  ,  JobKey
                  ,  JobLine
                  ,  Storerkey
                  ,  Sku
                  ,  Packkey
                  ,  UOM
                  ,  Lot
                  ,  FromLoc
                  ,  ToLoc
                  ,  ID
                  ,  Qty
                  ,  PickMethod
                  ,  Status
                  )
            VALUES(  @c_JobReserveKey              --(Wan03)
                  ,  @c_JobKey
                  ,  @c_JobLineNo
                  ,  @c_aStorerkey
                  ,  @c_aSku
                  ,  @c_aPackKey
                  ,  @c_UOM
                  ,  @c_aLot
                  ,  @c_Loc
                  ,  @c_TmpLoc
                  ,  @c_ID
                  ,  @n_QtyToInsert
                  ,  @c_PullUOM
                  ,  '0'
                  )

            SET @n_err = @@ERROR
            SET @n_cnt = @@ROWCOUNT
            IF NOT (@n_Err = 0 AND @n_cnt = 1)
            BEGIN
               SET @b_JobMoveInsertSuccess = 0
            END

            IF @b_JobMoveInsertSuccess = 1
            BEGIN                
               UPDATE #OPJOBLINES
                  SET Qty = Qty - @n_QtyToInsert
               WHERE SeqNo = @n_SeqNo

               COMMIT TRAN TROUTERLOOP

               IF @b_debug = 3 --@b_debug = 1
               BEGIN
                  PRINT ''  
                  PRINT '**** Succeed - Insert Job Pick Detail ****'
                  PRINT ' Qty: ' + CAST(@n_MoveQty AS VARCHAR(10))
               END
            END -- @b_JobMoveInsertSuccess = 1
            ELSE
            BEGIN
               ROLLBACK TRAN TROUTERLOOP
            END  -- @b_JobMoveInsertSuccess <> 1
         END
      END

      SET @c_Sourcekey = CONVERT( NCHAR(10), @c_JobKey) + CONVERT( NCHAR(5), @c_JobLineNo)

      --GOTO MOVEINV          --(Wan02)

      RETURNFROMMOVEINV:

   END -- @b_JobMoveInsertSuccess = 1

   GOTO RETURNFROMUPDATEINV 

   /* (Wan02) - START
   MOVEINV:

   IF @c_PullUOM = '1'
   BEGIN
      DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Storerkey
            ,Sku
            ,Lot
            ,Qty
      FROM LOTxLOCxID WITH (NOLOCK)
      WHERE Loc = @c_Loc
      AND   ID  = @c_ID
      AND   Qty > 0
   END
   ELSE
   BEGIN
      DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Storerkey
            ,Sku
            ,Lot
            ,@n_QtyToInsert
      FROM LOTxLOCxID WITH (NOLOCK)
      WHERE Lot = @c_aLot
      AND   Loc = @c_Loc
      AND   ID  = @c_ID
      AND   Qty > 0
   END

   OPEN CUR_ID
   FETCH NEXT FROM CUR_ID INTO @c_Storerkey
                              ,@c_Sku
                              ,@c_Lot
                              ,@n_Qty

   WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)
   BEGIN
      SELECT @c_Packkey = Packkey
      FROM SKU WITH (NOLOCK) 
      WHERE Storerkey = @c_Storerkey
      AND   Sku = @c_Sku

      SELECT @c_UOM = PACKUOM3
      FROM PACK WITH (NOLOCK)
      WHERE Packkey = @c_Packkey

      SET @c_MoveRefKey = ''

      IF @c_PullUOM = '1'
      BEGIN
        IF NOT EXISTS ( SELECT 1
                         FROM ID WITH (NOLOCK)
                         WHERE Id = @c_ID
                         AND Status = 'HOLD'
                       )
         BEGIN  
            EXEC nspInventoryHoldWrapper
               '',               -- lot
               '',               -- loc
               @c_ID,            -- id
               '',               -- storerkey
               '',               -- sku
               '',               -- lottable01
               '',               -- lottable02
               '',               -- lottable03
               NULL,             -- lottable04
               NULL,             -- lottable05
               '',               -- lottable06
               '',               -- lottable07    
               '',               -- lottable08
               '',               -- lottable09
               '',               -- lottable10
               '',               -- lottable11
               '',               -- lottable12
               NULL,             -- lottable13
               NULL,             -- lottable14
               NULL,             -- lottable15
               'VASIDHOLD',      -- status  
               '1',              -- hold
               @b_success OUTPUT,
               @n_err OUTPUT,
               @c_errmsg OUTPUT,
               'VAS ASRS ID'     -- remark

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 63715
               SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Hold ID Fail. (isp_WOJobInvReserve)' 
                                   + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
            END
         END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM PICKDETAIL WITH (NOLOCK)
                        WHERE Lot = @c_Lot
                        AND   Loc = @c_Loc
                        AND   ID  = @c_ID
                        AND   Status < '9'
                        AND   ShipFlag <> 'Y'
                      )
            BEGIN

               SET @b_success = 1    
               EXECUTE   nspg_getkey    
                     'MoveRefKey'    
                    , 10    
                    , @c_MoveRefKey       OUTPUT    
                    , @b_success          OUTPUT    
                    , @n_err              OUTPUT    
                    , @c_errmsg           OUTPUT 

               IF NOT @b_success = 1    
               BEGIN    
                  SET @n_continue = 3    
                  SET @n_err = 63708  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get MoveRefKey Failed. (isp_WOJobInvReserve)' 
               END 
         

               IF @n_continue = 1 OR @n_continue = 2
               BEGIN
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET MoveRefKey = @c_MoveRefKey
                     ,EditWho    = SUSER_NAME()
                     ,EditDate   = GETDATE()
                     ,Trafficcop = NULL
                  WHERE LOT = @c_Lot
                  AND   Loc = @c_Loc
                  AND   ID  = @c_ID
                  AND   Status < '9'
                  AND   ShipFlag <> 'Y'

                  SET @n_err = @@ERROR 
                  IF @n_err <> 0    
                  BEGIN  
                     SET @n_continue = 3    
                     SET @n_err = 63709   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table PICKDETIAL. (isp_WOJobInvReserve)' 
                  END 
               END
            END
         END
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         EXEC nspItrnAddMove
                NULL
            ,   @c_StorerKey
            ,   @c_Sku
            ,   @c_Lot
            ,   @c_Loc
            ,   @c_ID
            ,   @c_TmpLoc
            ,   @c_ID
            ,   ''         --Status
            ,   ''         --lottable01
            ,   ''         --lottable02
            ,   ''         --lottable03
            ,   NULL       --lottable04
            ,   NULL       --lottable05
            ,   ''         --lottable06
            ,   ''         --lottable07
            ,   ''         --lottable08
            ,   ''         --lottable09
            ,   ''         --lottable10
            ,   ''         --lottable11
            ,   ''         --lottable12
            ,   NULL       --lottable13
            ,   NULL       --lottable14
            ,   NULL       --lottable15
            ,   0
            ,   0
            ,   @n_Qty
            ,   0
            ,   0.00
            ,   0.00
            ,   0.00
            ,   0.00
            ,   0.00
            ,   @c_SourceKey
            ,   'isp_WOJobInvReserve'
            ,   @c_PackKey
            ,   @c_UOM
            ,   1
            ,   NULL
            ,   ''
            ,   @b_Success        OUTPUT
            ,   @n_err            OUTPUT
            ,   @c_errmsg         OUTPUT
            ,   @c_MoveRefKey     = @c_MoveRefKey 

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63710  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Moving Stock to Virtual Location. (isp_WOJobInvReserve)' 
         END
         IF @b_debug = 1
         BEGIN
            select 'itrnmove', @c_aLot, @c_ID, @c_Loc, @c_PTmpLoc,@n_Qty 
         END
      END

      FETCH NEXT FROM CUR_ID INTO @c_Storerkey
                                 ,@c_Sku
                                 ,@c_Lot
                                 ,@n_Qty

   END 

   CLOSE CUR_ID
   DEALLOCATE CUR_ID
   GOTO RETURNFROMMOVEINV
   (Wan02) - END */
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_TRF_PopulateLLI_Wrapper                         */                                                                                  
/* Creation Date: 2023-03-23                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3965 - [CN] SCE populate all for Transfer population   */
/*                                                                      */
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */
/* 2023-03-23  Wan      1.0   Created & DevOps Combine Script           */
/* 2024-09-25  Wan01    1.1   LFWM-4446 - RG[GIT] Serial Number Solution*/
/*                            - Transfer by Serial Number               */
/************************************************************************/
CREATE   PROC [WM].[lsp_TRF_PopulateLLI_Wrapper]                                                                                                                     
   @c_TransferKey          NVARCHAR(10)         
,  @c_LotxLocxID           NVARCHAR(MAX)    --Eacg set of Lot,Loc,ID seperated by '|'. Eg 0000000001,STAGE,ID1|0000000002,STAGE,ID2
,  @b_Success              INT            = 1  OUTPUT  
,  @n_Err                  INT            = 0  OUTPUT                                                                                                             
,  @c_ErrMsg               NVARCHAR(255)  = '' OUTPUT
,  @c_UserName             NVARCHAR(128)  = '' 
,  @n_ErrGroupKey          INT            = 0  OUTPUT
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt                  INT = @@TRANCOUNT  
         ,  @n_Continue                   INT = 1

         ,  @n_TRFCOPYL3_cnt              INT = 0

         ,  @n_RowID                      INT = 0
         ,  @n_FromQty                    INT = 0
         ,  @n_ToQty                      INT = 0

         ,  @n_TotalSelected              INT = 0                                   --(Wan01)
         ,  @n_TotalInserted              INT = 0                                   --(Wan01)

         ,  @c_DefaultUOM                 NVARCHAR(10)   = ''
         ,  @c_UOM1                       NVARCHAR(10)   = ''
         ,  @c_UOM2                       NVARCHAR(10)   = ''
         ,  @c_UOM3                       NVARCHAR(10)   = ''
         ,  @c_UOM4                       NVARCHAR(10)   = ''

         ,  @c_FromFacility               NVARCHAR(5)    = ''
         ,  @c_FromStorerkey              NVARCHAR(15)   = ''
         ,  @c_ToFacility                 NVARCHAR(5)    = ''
         ,  @c_ToStorerkey                NVARCHAR(15)   = '' 
         ,  @c_Type                       NVARCHAR(12)   = ''
         ,  @c_TransferLineNumber         NVARCHAR(5)    = ''
         ,  @c_FromSku                    NVARCHAR(20)   = ''
         ,  @c_FromPackkey                NVARCHAR(10)   = ''
         ,  @c_FromUOM                    NVARCHAR(10)   = ''
         ,  @c_FromLot                    NVARCHAR(10)   = ''
         ,  @c_FromLoc                    NVARCHAR(10)   = ''
         ,  @c_FromID                     NVARCHAR(18)   = ''         
         ,  @c_FromLottable01             NVARCHAR(18)   = ''
         ,  @c_FromLottable02             NVARCHAR(18)   = ''
         ,  @c_FromLottable03             NVARCHAR(18)   = ''
         ,  @dt_FromLottable04            DATETIME       = NULL
         ,  @dt_FromLottable05            DATETIME       = NULL
         ,  @c_FromLottable06             NVARCHAR(30)   = ''
         ,  @c_FromLottable07             NVARCHAR(30)   = ''
         ,  @c_FromLottable08             NVARCHAR(30)   = ''
         ,  @c_FromLottable09             NVARCHAR(30)   = ''
         ,  @c_FromLottable10             NVARCHAR(30)   = ''
         ,  @c_FromLottable11             NVARCHAR(30)   = ''
         ,  @c_FromLottable12             NVARCHAR(30)   = ''
         ,  @dt_FromLottable13            DATETIME       = NULL
         ,  @dt_FromLottable14            DATETIME       = NULL
         ,  @dt_FromLottable15            DATETIME       = NULL
         ,  @c_ToSku                      NVARCHAR(20)   = ''                
         ,  @c_ToPackkey                  NVARCHAR(10)   = ''
         ,  @c_ToUOM                      NVARCHAR(10)   = ''
         ,  @c_ToLoc                      NVARCHAR(10)   = ''
         ,  @c_ToID                       NVARCHAR(18)   = ''
         ,  @c_ToLottable01               NVARCHAR(18)   = ''
         ,  @c_ToLottable02               NVARCHAR(18)   = ''
         ,  @c_ToLottable03               NVARCHAR(18)   = ''
         ,  @dt_ToLottable04              DATETIME       = NULL
         ,  @dt_ToLottable05              DATETIME       = NULL
         ,  @c_ToLottable06               NVARCHAR(30)   = ''
         ,  @c_ToLottable07               NVARCHAR(30)   = ''
         ,  @c_ToLottable08               NVARCHAR(30)   = ''
         ,  @c_ToLottable09               NVARCHAR(30)   = ''
         ,  @c_ToLottable10               NVARCHAR(30)   = ''
         ,  @c_ToLottable11               NVARCHAR(30)   = ''
         ,  @c_ToLottable12               NVARCHAR(30)   = ''
         ,  @dt_ToLottable13              DATETIME       = NULL
         ,  @dt_ToLottable14              DATETIME       = NULL
         ,  @dt_ToLottable15              DATETIME       = NULL
         
         ,  @c_Channel_From               NVARCHAR(20)   = ''                        
         ,  @c_Channel_To                 NVARCHAR(20)   = ''   
         
         ,  @c_Channel_FromDefault        NVARCHAR(20)   = ''   
         ,  @c_Channel_ToDefault          NVARCHAR(20)   = ''                
                                                                                     
         ,  @c_TRFCOPYL3                  NVARCHAR(10)   = ''

         ,  @c_INVTRFITF                  NVARCHAR(10)   = ''

         ,  @c_ASNFizUpdLotToSerialNo     NVARCHAR(10)   = ''                       --(Wan01)
         ,  @c_ChannelInventoryMgmt_From  NVARCHAR(10)   = ''                         
         ,  @c_ChannelInventoryMgmt_To    NVARCHAR(10)   = ''                        

         ,  @c_TableName      NVARCHAR(50)   = 'TransferDetail'
         ,  @c_SourceType     NVARCHAR(50)   = 'lsp_TRF_PopulateLLI_Wrapper' 
         ,  @c_Refkey1        NVARCHAR(20)   = ''
         ,  @c_Refkey2        NVARCHAR(20)   = ''
         ,  @c_Refkey3        NVARCHAR(20)   = ''
         ,  @c_WriteType      NVARCHAR(50)   = ''
         ,  @n_LogWarningNo   INT            = 0

         ,  @CUR_ERRLIST      CURSOR        
         
   DECLARE  @t_WMSErrorList   TABLE
         (  RowID             INT            IDENTITY(1,1)
         ,  TableName         NVARCHAR(50)   NOT NULL DEFAULT('')                   --(Wan01)
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')
         )         

   SET @b_Success = 1
   SET @n_Err     = 0
   SET @c_ErrMsg  = ''
   
   SET @n_ErrGroupKey = 0
               
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName        
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
                
      EXECUTE AS LOGIN = @c_UserName        
   END                                    

   BEGIN TRY  
      BEGIN TRAN                           
      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - START               */
      /*-------------------------------------------------------*/
      IF OBJECT_ID('tempdb..#tLLI', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tLLI
      END

      CREATE TABLE #tLLI 
         (  RowID                INT            NOT NULL IDENTITY(1,1)    PRIMARY KEY
         ,  LotxLocxID           NVARCHAR(38)   NOT NULL DEFAULT('')
         ,  Lot                  NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  Loc                  NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  ID                   NVARCHAR(18)   NOT NULL DEFAULT('')
         ,  CommaIdx1            INT            NOT NULL DEFAULT(0)
         ,  CommaIdx2            INT            NOT NULL DEFAULT(0)
         ,  SkuSerialNoCapture   NVARCHAR(1)    NOT NULL DEFAULT('')
         )
   
      INSERT INTO #tLLI (LotxLocxID, Lot, CommaIdx1)
      SELECT T.[Value]
            ,Lot = SUBSTRING(T.[Value],1,CHARINDEX(',',T.[Value],1) - 1) 
            ,CommaIdx1 = CHARINDEX(',',T.[Value],1)
      FROM string_split (@c_LotxLocxID, '|') T
      GROUP BY T.[Value]
      
      SET @n_TotalSelected = @@ROWCOUNT                                             --(Wan01)

      UPDATE #tLLI
          SET Loc = SUBSTRING(LotxLocxID
                            ,CommaIdx1+1
                            ,CHARINDEX(',', LotxLocxID, CommaIdx1+1) - 1 - CommaIdx1)  
            ,CommaIdx2 = CHARINDEX(',', LotxLocxID, CommaIdx1+1) 

      UPDATE #tLLI
          SET ID = SUBSTRING(LotxLocxID,CommaIdx2+1, LEN(LotxLocxID) - CommaIdx2) 

      UPDATE #tLLI                                                                  --(Wan01)
         SET SkuSerialNoCapture = SKU.SerialNoCapture
      FROM #tLLI
      JOIN Lot (NOLOCK) ON Lot.lot = #tLLI.lot
      JOIN Sku (NOLOCK) ON  Sku.Storerkey = Lot.Storerkey
                        AND Sku.Sku = Lot.Sku
      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - END                 */
      /*-------------------------------------------------------*/

      SET @c_FromFacility = ''
      SET @c_FromStorerkey= ''
      SET @c_ToFacility = ''
      SET @c_ToStorerkey= ''
      SELECT @c_FromFacility = TH.Facility
            ,@c_ToFacility   = TH.ToFacility
            ,@c_FromStorerkey= TH.FromStorerkey
            ,@c_ToStorerkey  = TH.ToStorerkey
            ,@c_Type         = TH.[Type]
      FROM TRANSFER TH WITH (NOLOCK)
      WHERE TH.TransferKey = @c_TransferKey
      
      -- Get Storerconfig 
      SELECT @c_ASNFizUpdLotToSerialNo = fsgr.Authority                             --(Wan01)
      FROM dbo.fnc_SelectGetRight(@c_FromFacility, @c_FromStorerkey, '', 'ASNFizUpdLotToSerialNo')AS fsgr
      SELECT @c_ChannelInventoryMgmt_From = fsgr.Authority FROM dbo.fnc_SelectGetRight (@c_FromFacility, @c_FromStorerkey,'','ChannelInventoryMgmt') AS fsgr
      SELECT @c_ChannelInventoryMgmt_To   = fsgr.Authority FROM dbo.fnc_SelectGetRight (@c_ToFacility, @c_ToStorerkey,'','ChannelInventoryMgmt') AS fsgr
 
      IF @c_ChannelInventoryMgmt_From = '1'
      BEGIN
         SELECT TOP 1 @c_Channel_FromDefault = c.Code
         FROM dbo.CODELKUP AS c WITH (NOLOCK)
         WHERE c.ListName = 'Channel'
         AND c.Storerkey IN ('', @c_FromStorerkey)
         ORDER BY CASE WHEN c.Storerkey = @c_FromStorerkey THEN 1
                        ELSE 9
                        END
               ,  c.Code               
      END
      
      IF @c_ChannelInventoryMgmt_To = '1'
      BEGIN
         SELECT TOP 1 @c_Channel_ToDefault = c.Code
         FROM dbo.CODELKUP AS c WITH (NOLOCK)
         WHERE c.ListName = 'Channel'
         AND c.Storerkey IN ('', @c_ToStorerkey)
         ORDER BY CASE WHEN c.Storerkey = @c_ToStorerkey THEN 1
                        ELSE 9
                        END
               ,  c.Code               
      END
      
      SELECT @c_INVTRFITF = dbo.fnc_GetRight(@c_FromFacility, @c_FromStorerkey, '', 'INVTRFITF')  

      IF @c_INVTRFITF = '1'
      BEGIN
         SELECT TOP 1 
               @c_TRFCOPYL3 = IIF(C.Storerkey IN ('', @c_FromStorerkey), UPPER(ISNULL(c.Short,'')), '') 
            ,  @n_TRFCOPYL3_cnt = IIF(C.Storerkey IN ('', @c_FromStorerkey), 1, 0)     
         FROM dbo.CODELKUP AS c (NOLOCK)
         WHERE c.LISTNAME = 'TRFCOPYL3'
         AND c.Code = @c_Type
         ORDER BY CASE WHEN C.Storerkey = @c_FromStorerkey THEN 1 
                       WHEN C.Storerkey = '' THEN 2
                       ELSE 3 END  
      END
                 
      SET @c_TransferLineNumber = '00000'  
    
      SELECT TOP 1 @c_TransferLineNumber = TD.TransferLineNumber
      FROM TRANSFERDETAIL TD WITH (NOLOCK)
      WHERE TD.Transferkey = @c_Transferkey
      ORDER BY TD.TransferLineNumber DESC

      SET @n_RowID = 0                    
      WHILE 1 = 1
      BEGIN
         SET @c_FromSku = ''
         SET @c_FromLot = ''
         SET @c_FromLoc = ''
         SET @c_FromID  = ''
         SET @n_FromQty = 0

         SELECT Top 1
             @n_RowID      = tl.RowID
            ,@c_FromSku    = ltlci.Sku
            ,@c_FromLot    = ltlci.Lot
            ,@c_FromLoc    = ltlci.Loc  
            ,@c_FromID     = ltlci.ID 
            ,@n_FromQty    = ltlci.Qty - ltlci.QtyAllocated - ltlci.QtyPicked
            ,@c_ToSku      = ltlci.Sku                          
         FROM #tLLI AS tl
         JOIN dbo.LOTxLOCxID AS ltlci WITH (NOLOCK) ON  ltlci.Lot = tl.Lot 
                                                    AND ltlci.Loc = tl.Loc 
                                                    AND ltlci.Id = tl.ID
         WHERE tl.RowID > @n_RowID 
         AND ltlci.Qty - ltlci.QtyAllocated - ltlci.QtyPicked > 0 
         AND NOT (tl.SkuSerialNoCapture IN ('1','2') AND @c_ASNFizUpdLotToSerialNo = '1') --(Wan01)
         ORDER BY tl.RowID

         IF @@ROWCOUNT = 0 OR @c_FromSku = ''
         BEGIN
            BREAK
         END

         SET @c_UOM1 = ''
         SET @c_UOM2 = ''
         SET @c_UOM3 = ''
         SET @c_UOM4 = ''
         SET @c_FromPackkey = ''
         SELECT @c_FromPackkey = FS.Packkey
         FROM SKU  FS WITH (NOLOCK)
         WHERE FS.Storerkey = @c_FromStorerkey
         AND   FS.Sku = @c_FromSku

         SELECT @c_UOM1 = FP.PackUOM1
            ,   @c_UOM2 = FP.PackUOM2
            ,   @c_UOM3 = FP.PackUOM3
            ,   @c_UOM4 = FP.PackUOM4
         FROM PACK FP WITH (NOLOCK) 
         WHERE FP.Packkey = @c_FromPackkey

         SET @c_FromUOM  = @c_UOM3
         SET @c_ToUOM    = @c_FromUOM
         SET @c_ToPackkey= @c_FromPackkey
         SET @c_ToLoc    = @c_FromLoc
         SET @c_ToID     = @c_FromID
         SET @n_ToQty    = @n_FromQty
         
         SET @c_FromLottable01 = ''  
         SET @c_FromLottable02 = ''  
         SET @c_FromLottable03 = ''  
         SET @dt_FromLottable04= NULL  
         SET @dt_FromLottable05= NULL  
         SET @c_FromLottable06 = ''  
         SET @c_FromLottable07 = ''  
         SET @c_FromLottable08 = ''  
         SET @c_FromLottable09 = ''  
         SET @c_FromLottable10 = ''  
         SET @c_FromLottable11 = ''  
         SET @c_FromLottable12 = ''  
         SET @dt_FromLottable13= NULL  
         SET @dt_FromLottable14= NULL  
         SET @dt_FromLottable15= NULL

         SELECT @c_FromLottable01  = LA.Lottable01
            ,   @c_FromLottable02  = LA.Lottable02
            ,   @c_FromLottable03  = LA.Lottable03
            ,   @dt_FromLottable04 = LA.Lottable04
            ,   @dt_FromLottable05 = LA.Lottable05
            ,   @c_FromLottable06  = LA.Lottable06
            ,   @c_FromLottable07  = LA.Lottable07
            ,   @c_FromLottable08  = LA.Lottable08
            ,   @c_FromLottable09  = LA.Lottable09
            ,   @c_FromLottable10  = LA.Lottable10
            ,   @c_FromLottable11  = LA.Lottable11
            ,   @c_FromLottable12  = LA.Lottable12
            ,   @dt_FromLottable13 = LA.Lottable13
            ,   @dt_FromLottable14 = LA.Lottable14
            ,   @dt_FromLottable15 = LA.Lottable15
         FROM LOTATTRIBUTE LA WITH (NOLOCK)
         WHERE LA.Lot = @c_FromLot

         SET @c_ToLottable01 = @c_FromLottable01 
         SET @c_ToLottable02 = @c_FromLottable02 
         SET @c_ToLottable03 = IIF(@n_TRFCOPYL3_cnt= 0, @c_FromLottable03, @c_TRFCOPYL3)
         SET @dt_ToLottable04= @dt_FromLottable04 
         SET @dt_ToLottable05= @dt_FromLottable05 
         SET @c_ToLottable06 = @c_FromLottable06 
         SET @c_ToLottable07 = @c_FromLottable07 
         SET @c_ToLottable08 = @c_FromLottable08 
         SET @c_ToLottable09 = @c_FromLottable09 
         SET @c_ToLottable10 = @c_FromLottable10 
         SET @c_ToLottable11 = @c_FromLottable11 
         SET @c_ToLottable12 = @c_FromLottable12 
         SET @dt_ToLottable13= @dt_FromLottable13 
         SET @dt_ToLottable14= @dt_FromLottable14 
         SET @dt_ToLottable15= @dt_FromLottable15
         
         IF @c_ChannelInventoryMgmt_From = '1'                                       
         BEGIN
            SET @c_Channel_From = ''
            SELECT @c_Channel_From = fsci.Channel
            FROM dbo.fnc_SelectChannelInv(@c_FromFacility, @c_FromStorerkey, @c_FromSku, @c_Channel_From
                                         ,@c_FromLot, @n_FromQty
                                          ) AS fsci
                                          
            IF @c_Channel_From = ''
            BEGIN
               SET @c_Channel_From = @c_Channel_FromDefault
            END                              
         END
         
         IF @c_ChannelInventoryMgmt_To = '1'
         BEGIN
            SET @c_Channel_To = @c_Channel_ToDefault
            IF @c_ToStorerkey = @c_FromStorerkey
            BEGIN 
               SET @c_Channel_To = @c_Channel_From
            END   
         END
         
         SET @n_TotalInserted = @n_TotalInserted + 1                                --(Wan01)
         SET @c_TransferLineNumber = RIGHT( '00000' + CONVERT(NVARCHAR(5), CONVERT(INT, @c_TransferLineNumber) + 1), 5 )
         INSERT INTO TRANSFERDETAIL
               (  TransferKey
               ,  TransferLineNumber
               ,  FromStorerkey  
               ,  FromSku
               ,  FromPackkey  
               ,  FromUOM
               ,  FromQty
               ,  FromLot
               ,  FromLoc
               ,  FromID
               ,  Lottable01
               ,  Lottable02
               ,  Lottable03
               ,  Lottable04
               ,  Lottable05
               ,  Lottable06
               ,  Lottable07
               ,  Lottable08
               ,  Lottable09
               ,  Lottable10
               ,  Lottable11
               ,  Lottable12
               ,  Lottable13
               ,  Lottable14
               ,  Lottable15
               ,  ToStorerkey  
               ,  ToSku
               ,  ToPackkey  
               ,  ToUOM
               ,  ToQty
               ,  ToLot
               ,  ToLoc
               ,  ToID
               ,  ToLottable01
               ,  ToLottable02
               ,  ToLottable03
               ,  ToLottable04
               ,  ToLottable05
               ,  ToLottable06
               ,  ToLottable07
               ,  ToLottable08
               ,  ToLottable09
               ,  ToLottable10
               ,  ToLottable11
               ,  ToLottable12
               ,  ToLottable13
               ,  ToLottable14
               ,  ToLottable15
               ,  FromChannel                                                     
               ,  ToChannel                                                       
               )
         VALUES(  @c_TransferKey
               ,  @c_TransferLineNumber
               ,  @c_FromStorerkey  
               ,  @c_FromSku
               ,  @c_FromPackkey  
               ,  @c_FromUOM
               ,  @n_FromQty
               ,  @c_FromLot
               ,  @c_FromLoc
               ,  @c_FromID
               ,  @c_FromLottable01
               ,  @c_FromLottable02
               ,  @c_FromLottable03
               ,  @dt_FromLottable04
               ,  @dt_FromLottable05
               ,  @c_FromLottable06
               ,  @c_FromLottable07
               ,  @c_FromLottable08
               ,  @c_FromLottable09
               ,  @c_FromLottable10
               ,  @c_FromLottable11
               ,  @c_FromLottable12
               ,  @dt_FromLottable13
               ,  @dt_FromLottable14
               ,  @dt_FromLottable15
               ,  @c_ToStorerkey  
               ,  @c_ToSku
               ,  @c_ToPackkey  
               ,  @c_ToUOM
               ,  @n_ToQty
               , ''
               ,  @c_ToLoc
               ,  @c_ToID
               ,  @c_ToLottable01
               ,  @c_ToLottable02
               ,  @c_ToLottable03
               ,  @dt_ToLottable04
               ,  @dt_ToLottable05
               ,  @c_ToLottable06
               ,  @c_ToLottable07
               ,  @c_ToLottable08
               ,  @c_ToLottable09
               ,  @c_ToLottable10
               ,  @c_ToLottable11
               ,  @c_ToLottable12
               ,  @dt_ToLottable13
               ,  @dt_ToLottable14
               ,  @dt_ToLottable15
               ,  @c_Channel_From                                                 
               ,  @c_Channel_To                                                   
               )

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP
         END
      END

      IF @c_ASNFizUpdLotToSerialNo = 1 AND @n_TotalSelected > @n_TotalInserted
      BEGIN
         IF EXISTS (SELECT 1 FROM #tLLI WHERE SkuSerialNoCapture IN ('1','2'))
         BEGIN
            SET @n_Err    = 0
            SET @c_ErrMsg = N'Warning: There are Inventories with mandatory SerialNo not populated!!!'
                           + '. (lsp_TRF_PopulateLLI_Wrapper)'

            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_TransferKey, '', '', 'WARNING', 0, @n_Err, @c_Errmsg)
         END
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg   = ERROR_MESSAGE() 
      
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
      VALUES (@c_TableName, @c_SourceType, @c_TransferKey, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)
      GOTO EXIT_SP   
   END CATCH                              
EXIT_SP:
   IF (XACT_STATE()) = -1  
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END  
    
   IF OBJECT_ID('tempdb..#tLLI', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #tLLI
   END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0                                                      --(Wan01)
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_TRF_PopulateLLI_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > 0                                                         --(Wan01)
      BEGIN
         COMMIT TRAN
      END
   END
      
   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   twl.TableName
         ,  twl.SourceType
         ,  twl.Refkey1
         ,  twl.Refkey2
         ,  twl.Refkey3
         ,  twl.WriteType
         ,  twl.LogWarningNo
         ,  twl.ErrCode
         ,  twl.Errmsg
   FROM @t_WMSErrorList AS twl
   ORDER BY twl.RowID

   OPEN @CUR_ERRLIST

   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName
                                     , @c_SourceType
                                     , @c_Refkey1
                                     , @c_Refkey2
                                     , @c_Refkey3
                                     , @c_WriteType
                                     , @n_LogWarningNo
                                     , @n_Err
                                     , @c_Errmsg

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC [WM].[lsp_WriteError_List]
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
      ,  @c_TableName   = @c_TableName
      ,  @c_SourceType  = @c_SourceType
      ,  @c_Refkey1     = @c_Refkey1
      ,  @c_Refkey2     = @c_Refkey2
      ,  @c_Refkey3     = @c_Refkey3
      ,  @n_LogWarningNo= @n_LogWarningNo
      ,  @c_WriteType   = @c_WriteType
      ,  @n_err2        = @n_err
      ,  @c_errmsg2     = @c_errmsg
      ,  @b_Success     = @b_Success
      ,  @n_err         = @n_err
      ,  @c_errmsg      = @c_errmsg

      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName
                                        , @c_SourceType
                                        , @c_Refkey1
                                        , @c_Refkey2
                                        , @c_Refkey3
                                        , @c_WriteType
                                        , @n_LogWarningNo
                                        , @n_Err
                                        , @c_Errmsg
   END
   CLOSE @CUR_ERRLIST
   DEALLOCATE @CUR_ERRLIST

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END  
         
   REVERT
END

GO
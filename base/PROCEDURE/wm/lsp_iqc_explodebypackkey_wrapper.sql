SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************************/
/* Store procedure: lsp_IQC_ExplodeByPackKey_Wrapper                                      */
/* Creation Date  : Unknown                                                               */  
/* Copyright      : LFLogistics                                                           */
/* Written by     : Unknown                                                               */  
/*                                                                                        */
/* Purpose: Dynamic lottable                                                              */                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
/*                                                                                        */ 
/* Version: 1.3                                                                           */  
/*                                                                                        */  
/* Data Modifications:                                                                    */  
/*                                                                                        */  
/* Updates:                                                                               */  
/* Date        Author   Ver   Purposes                                                    */ 
/* 17-DEC-2018 CZTENG   1.0   1)Return Error Message for Pallet = 0 => @n_PalletCnt =0    */
/*                                 and terminate processing                               */
/*                            2)Add BEGIN TRY - END CATCH on insert and update            */
/*                                 statement                                              */
/* 18-DEC-2020 Wan01    1.1   LFWM-2420 - UAT - TW Getting Quantity should be Greater than*/
/*                            1000 to Explode error in Inventory QC when Explore by Packkey*/
/* 25-MAY-2021 Wan02    1.2   LFWM-2806 - UAT - TW  Inventory QC  Explode by Packkey      */
/*                            Original Qty not updated                                    */
/* 28-OCT-2021 Wan03    1.3   LFWM-2944 - UAT - TW  Not able to 'Explode by PackKey' when */
/*                            quantity is less than Pallet quantity in Inventory QC module*/
/* 28-OCT-2021 Wan03    1.3   DevOps Combine Script                                       */
/******************************************************************************************/
CREATE PROCEDURE [WM].[lsp_IQC_ExplodeByPackKey_Wrapper]
    @c_QC_Key NVARCHAR(10) 
   ,@c_QCLineNo NVARCHAR(5)=''  
   ,@b_Success INT=1 OUTPUT 
   ,@n_Err INT=0 OUTPUT
   ,@c_ErrMsg NVARCHAR(250)='' OUTPUT
   ,@c_UserName NVARCHAR(128)=''
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @n_StartTCnt                  INT  = @@TRANCOUNT
         ,  @n_continue                   INT  = 1                --(Wan01)
    
    DECLARE @c_Facility                   NVARCHAR(5)
         ,  @c_ToFacility                 NVARCHAR(5)
         ,  @c_StorerKey                  NVARCHAR(15) = ''
         ,  @c_Sku                        NVARCHAR(20) = ''
         ,  @c_UOM                        NVARCHAR(10) = ''
         ,  @c_PackKey                    NVARCHAR(10) = ''
         ,  @n_OriginalQty                INT          = 0
         ,  @n_Qty                        INT          = 0
         ,  @c_CustomisedSplitLine        NVARCHAR(30) = ''
         ,  @n_PalletCnt                  INT = 0 
         ,  @b_ZeroOriginal               BIT = 0 
         ,  @b_ByOriginal                 BIT = 0 
         ,  @n_QtyToBeSplitted            INT = 0 
         ,  @n_RemainQty                  INT = 0
         ,  @c_Last_IQC_LineNo            NVARCHAR(5) = ''
         ,  @c_Next_IQC_LineNo            NVARCHAR(5) = ''
         ,  @n_RemainingQty               INT = 0 
         ,  @n_InsertOriginalQty          INT = 0 
         ,  @n_InsertQty                  INT = 0 
         ,  @n_RemainOriginalQty          INT = 0
         ,  @n_RemainQtyEntered           INT = 0     --(Wan02)

         ,  @b_GenID                      BIT          = 0
         ,  @b_exploded                   BIT          = 0

         ,  @n_AvailableQty               INT          = 0

         ,  @c_Reason                     NVARCHAR(10) = ''
         ,  @c_FromLot                    NVARCHAR(10) = ''
         ,  @c_FromLoc                    NVARCHAR(10) = ''
         ,  @c_FromID                     NVARCHAR(20) = ''
         ,  @c_ToLoc                      NVARCHAR(10) = ''
         ,  @c_ToId                       NVARCHAR(20) = ''

         ,  @c_GenID                      NVARCHAR(30) = ''
         ,  @c_GEN_ID_DURING_EXPLODE_PACK NVARCHAR(30) = ''
         ,  @c_FinalizeIQC                NVARCHAR(10) = ''
         
         ,  @c_AlertMsg                   NVARCHAR(255)= ''             --(Wan03)

   SET @b_Success = 1
   SET @c_ErrMsg =''

   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      SET @n_Err = 0 
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END  
                      
      EXECUTE AS LOGIN = @c_UserName
   END
   
   BEGIN TRAN
   BEGIN TRY
      SELECT @c_Facility   = IQC.From_Facility
            ,@c_ToFacility = IQC.to_Facility
            ,@c_Storerkey  = IQC.StorerKey
      FROM   InventoryQC IQC WITH (NOLOCK) 
      WHERE  IQC.QC_Key = @c_QC_Key

      SELECT @c_GenID = dbo.fnc_GetRight(@c_ToFacility, @c_Storerkey, '', 'GenID')
  
      SELECT @c_GEN_ID_DURING_EXPLODE_PACK = dbo.fnc_GetRight(@c_ToFacility, @c_Storerkey, '', 'GEN_ID_DURING_EXPLODE_PACK') --Get from NSQLConfig

      SELECT @c_FinalizeIQC = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'FinalizeIQC')
    
      IF @c_QCLineNo<>''
      BEGIN
         DECLARE CUR_InventoryQC_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY 
         FOR
            SELECT IQCD.QC_Key
                  ,IQCD.QCLineNo
                  ,IQCD.StorerKey
                  ,IQCD.Sku
                  ,IQCD.UOM
                  ,IQCD.PackKey
                  ,IQCD.OriginalQty
                  ,IQCD.Qty
                  ,IQCD.Reason
                  ,IQCD.FromLot
                  ,IQCD.FromLoc
                  ,IQCD.FromID
                  ,IQCD.ToLoc
                  ,IQCD.ToID
            FROM   InventoryQCDetail IQCD WITH (NOLOCK) 
            WHERE  IQCD.QC_Key = @c_QC_Key
               AND IQCD.QCLineNo = @c_QCLineNo
      END
      ELSE
      BEGIN
         DECLARE CUR_InventoryQC_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY 
         FOR
            SELECT IQCD.QC_Key
                  ,IQCD.QCLineNo
                  ,IQCD.StorerKey
                  ,IQCD.Sku
                  ,IQCD.UOM
                  ,IQCD.PackKey
                  ,IQCD.OriginalQty
                  ,IQCD.Qty
                  ,IQCD.Reason
                  ,IQCD.FromLot
                  ,IQCD.FromLoc
                  ,IQCD.FromID
                  ,IQCD.ToLoc
                  ,IQCD.ToID
            FROM   InventoryQCDetail IQCD WITH (NOLOCK) 
            WHERE  IQCD.QC_Key = @c_QC_Key
      END
    
      OPEN CUR_InventoryQC_LINES
    
      FETCH FROM CUR_InventoryQC_LINES INTO @c_QC_Key, @c_QCLineNo, @c_StorerKey 
                                       ,  @c_Sku, @c_UOM, @c_PackKey, @n_OriginalQty, @n_Qty, @c_Reason
                                       ,  @c_FromLot, @c_FromLoc, @c_FromID, @c_ToLoc, @c_ToID

    
      WHILE @@FETCH_STATUS=0
      BEGIN
         SET @c_CustomisedSplitLine = '0'
         SET @b_ZeroOriginal = 0 
         SET @n_QtyToBeSplitted = 0 
         SET @b_ByOriginal = 0 
       
         IF @n_OriginalQty = 0 
         BEGIN
            SET @n_OriginalQty = @n_Qty
            SET @b_ZeroOriginal = 1 
         END
   
         IF @n_Qty > 0 
         BEGIN
            SET @b_ByOriginal = 0
            SET @n_QtyToBeSplitted = @n_Qty     
         END
         ELSE
         BEGIN
            SET @b_ByOriginal = 1
            SET @n_QtyToBeSplitted = 0    
         END
 
         SET @n_RemainQty = @n_QtyToBeSplitted
         SET @n_RemainOriginalQty = @n_OriginalQty    --(Wan02)
         SET @n_RemainQtyEntered  = @n_Qty            --(Wan02)
        
         IF @n_QtyToBeSplitted > 0  
         BEGIN
            --(Wan03) - START
            SET @b_GenID = 0  
            IF @c_GenID = '1' AND @c_GEN_ID_DURING_EXPLODE_PACK = '1'  
            BEGIN  
               SET @b_GenID = 1  
            END       
            --(Wan03) - END
            
            SELECT @n_PalletCnt = PACK.Pallet            
            FROM PACK (NOLOCK)                                                                                                                                                                                                                                                                                                                                                                        
            WHERE PackKey = @c_PackKey
         
            IF @n_PalletCnt = 0 
               --GOTO FETCH_NEXT
            BEGIN   
               IF @b_GenID = 0               --(Wan03) 
               BEGIN
                  SET @b_Success = 0                                                                  -- CZTENG01 (START)
                  SET @n_Err     = 555151
                  SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                                 + ': Pallet Quantity Not Setup Properly in Pack Key: ' + @c_Packkey 
                                 + ' (lsp_IQC_ExplodeByPackKey_Wrapper)'
                                 + ' |' + @c_Packkey 
                  GOTO EXIT_SP                                                                        -- CZTENG01 (END)
               END
               
               SET @c_AlertMsg =  'Pallet Quantity Not Setup Properly in Pack Key: ' + @c_Packkey              --(Wan03)  
            END                                                                                                                                                                     

            --(Wan03) - END
            IF @n_QtyToBeSplitted <= @n_PalletCnt OR @n_PalletCnt = 0 
            BEGIN 
               IF @b_GenID = 1  
               BEGIN
                  SET @c_ToID = ''
                  EXEC dbo.nspg_GetKey                 
                        @KeyName = 'ID'      
                     ,  @fieldlength = 10  
                     ,  @keystring = @c_ToID OUTPUT      
                     ,  @b_Success = @b_Success OUTPUT      
                     ,  @n_err     = @n_err OUTPUT      
                     ,  @c_errmsg  = @c_errmsg OUTPUT 
                     
                  IF @b_Success = 0 
                  BEGIN
                     SET @b_Success = 0                                                                   
                     GOTO EXIT_SP  
                  END
                    
                  UPDATE InventoryQCDetail   
                  SET ToID = @c_ToId                   
                     , EditDate = GETDATE()  
                     , EditWho = @c_UserName   
                  WHERE QC_Key = @c_QC_Key  
                  AND   QCLineNo = @c_QCLineNo   
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @b_Success = 0
                     SET @c_ErrMsg = ERROR_MESSAGE()
                     SET @c_ErrMsg  = 'Update InventoryQCDetail Fial. (lsp_IQC_ExplodeByPackKey_Wrapper)'   
                                    + '( ' + @c_ErrMsg + ' )'   
                     GOTO EXIT_SP    
                  END        
               END                                                    
               GOTO FETCH_NEXT                              
            END
            -- (Wan03) - END
            -- Checking - START
            SET @c_FromLot= ISNULL(RTRIM(@c_FromLot),'')
            SET @c_FromLoc= ISNULL(RTRIM(@c_FromLoc),'')
            SET @c_FromID = ISNULL(RTRIM(@c_FromID),'')
            SET @c_ToLoc  = ISNULL(RTRIM(@c_ToLoc),'')

            IF @c_FromLot = ''
            BEGIN
               SET @b_Success = 0                                                                 
               SET @n_Err     = 555154
               SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                              + ': From Lot is Requied. (lsp_IQC_ExplodeByPackKey_Wrapper)'
               GOTO EXIT_SP  
            END

            IF @c_FromLoc = ''
            BEGIN
               SET @b_Success = 0                                                                 
               SET @n_Err     = 555155
               SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                              + ': From Loc is Requied. (lsp_IQC_ExplodeByPackKey_Wrapper)'
               GOTO EXIT_SP
            END

            IF @c_ToLoc = ''
            BEGIN
               SET @b_Success = 0                                                                 
               SET @n_Err     = 555156
               SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                              + ': To Loc is Requied. (lsp_IQC_ExplodeByPackKey_Wrapper)'
               GOTO EXIT_SP
            END

            IF @c_FromLoc = @c_ToLoc 
            BEGIN
               SET @b_Success = 0                                                                 
               SET @n_Err     = 555157
               SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                              + ': To Loc should be different from From Loc. (lsp_IQC_ExplodeByPackKey_Wrapper)'
               GOTO EXIT_SP
            END

            --(Wan03) - START - Move Up
            --SET @b_GenID = 0
            --IF @c_GenID = '1' AND @c_GEN_ID_DURING_EXPLODE_PACK = '1'
            --BEGIN
            --   SET @b_GenID = 1
            --END
            --(Wan03) - END
            
            IF ISNULL(RTRIM(@c_Reason),'') = '' AND @b_GenID = 0
            BEGIN
               SET @b_Success = 0                                                                 
               SET @n_Err     = 555158
               SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                              + ': Reason is Requied. (lsp_IQC_ExplodeByPackKey_Wrapper)'
               GOTO EXIT_SP  
            END 

            IF @c_FinalizeIQC = '0' 
            BEGIN 
               SET @n_AvailableQty = 0
               SELECT @n_AvailableQty = LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked 
               FROM LOTxLOCxID LLI WITH (NOLOCK)
               WHERE LLI.Lot = @c_FromLot
               AND   LLI.Loc = @c_FromLoc
               AND   LLI.ID  = @c_FromID
               AND   Qty - QtyAllocated - QtyPicked >= @n_Qty

               IF @n_AvailableQty < @n_Qty 
               BEGIN 
                  SET @b_Success = 0                                                                 
                  SET @n_Err     = 555159
                  SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                                 + ': System Qty Not Available. LOT#: ' + @c_FromLot  
                                 + ', LOC#: ' + @c_FromLoc  
                                 + ', ID#: '  + @c_FromID  
                                 + '. Quantity to Move: ' + CONVERT(NVARCHAR(10), @n_Qty) 
                                 + ', Available Qty: ' + CONVERT(NVARCHAR(10), @n_AvailableQty) 
                                 + '. (lsp_IQC_ExplodeByPackKey_Wrapper)' 
                                 + ' |' + @c_FromLot + '|' + @c_FromLoc + '|' + @c_FromID + '|'
                                 + CONVERT(NVARCHAR(10), @n_Qty) + '|'
                                 + CONVERT(NVARCHAR(10), @n_AvailableQty) 
                  GOTO EXIT_SP  
               END                            
            END

            WHILE @n_RemainQty > 0  
            BEGIN 
               SET @c_Last_IQC_LineNo = ''
         
               SELECT TOP 1 
                     @c_Last_IQC_LineNo = r.QCLineNo  
               FROM InventoryQCDetail AS r WITH(NOLOCK) 
               WHERE r.QC_Key = @c_QC_Key 
               ORDER BY r.QCLineNo DESC
         
               IF @c_Last_IQC_LineNo = ''
                  SET @c_Next_IQC_LineNo = '00001'
               ELSE 
               BEGIN
                  IF ISNUMERIC(@c_Last_IQC_LineNo) = 1             
                     SET @c_Next_IQC_LineNo = RIGHT( '0000' + CONVERT(varchar(5), CAST(@c_Last_IQC_LineNo AS INT) + 1) , 5)
                  ELSE 
                     GOTO FETCH_NEXT 
               END

               --(Wan02) - START
               --IF @b_ByOriginal = 1 
               -- BEGIN
               --   SET @n_InsertOriginalQty = @n_PalletCnt 
               --   SET @n_RemainQty = @n_RemainQty - @n_PalletCnt
               --END
                   
               IF @b_ZeroOriginal = 0 
               BEGIN
                  IF @n_RemainOriginalQty >= @n_PalletCnt 
                  BEGIN
                     SET @n_InsertOriginalQty = @n_PalletCnt
                     SET @n_RemainOriginalQty = @n_RemainOriginalQty - @n_PalletCnt
                  END               
                  ELSE IF @n_RemainOriginalQty <= 0 
                     SET @n_InsertOriginalQty = 0 
                  ELSE 
                  BEGIN
                     SET @n_InsertOriginalQty = @n_RemainOriginalQty
                     SET @n_RemainOriginalQty = 0
                  END                
               END
               ELSE 
                  SET @n_InsertOriginalQty = 0 
                   
               --(Wan02) - END

               IF @n_RemainQty - @n_PalletCnt > 0           
               BEGIN
                  SET @n_RemainQty = @n_RemainQty - @n_PalletCnt               
                  SET @n_InsertQty = @n_PalletCnt
               END
               ELSE
               BEGIN
                  SET @n_InsertQty = @n_RemainQty               
                  SET @n_RemainQty =0               
               END

               IF @n_InsertQty <= 0 BREAK
         
               SET @c_ToID = ''

               IF @b_GenID = 1
               BEGIN
                  BEGIN TRY
                     EXEC dbo.nspg_GetKey               
                           @KeyName = 'ID'    
                        ,  @fieldlength = 10
                        ,  @keystring = @c_ToID OUTPUT    
                        ,  @b_Success = @b_Success OUTPUT    
                        ,  @n_err     = @n_err OUTPUT    
                        ,  @c_errmsg  = @c_errmsg OUTPUT 
                     
                  END TRY
                  BEGIN CATCH
                     SET @b_Success = 0     
                     SET @n_err     = 555160
                     SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                                    + ': Error Executing nspg_GetKey - ID. (lsp_IQC_ExplodeByPackKey_Wrapper)' 
                                    + '( ' + @c_ErrMsg + ' )'   
                  END CATCH
                           
                  IF @b_Success = 0 OR @n_err <> 0
                  BEGIN
                     GOTO EXIT_SP
                  END                                             
               END

               IF @n_RemainQty > 0    --(Wan01) START -- Insert if not Last Insert Qty ELSE Update Original Line
               BEGIN
                  BEGIN TRY 
                     INSERT INTO InventoryQCDetail (QC_Key, QCLineNo, StorerKey, SKU,
                                 PackKey, UOM, OriginalQty, Qty, FromLoc, FromLot,
                                 FromID, ToQty, ToID, ToLoc, Reason, [Status],
                                 UserDefine01, UserDefine02, UserDefine03, UserDefine04,
                                 UserDefine05, UserDefine06, UserDefine07, UserDefine08,
                                 UserDefine09, UserDefine10, FinalizeFlag)
                     SELECT 
                        QC_Key, @c_Next_IQC_LineNo, StorerKey, SKU,
                        PackKey, UOM, @n_InsertOriginalQty, @n_InsertQty, FromLoc, FromLot,
                        FromID, @n_InsertQty, @c_ToID, ToLoc, Reason, '0',
                        UserDefine01, UserDefine02, UserDefine03, UserDefine04,
                        UserDefine05, UserDefine06, UserDefine07, UserDefine08,
                        UserDefine09, UserDefine10, 'N'
                     FROM InventoryQCDetail AS r WITH(NOLOCK)
                     WHERE r.QC_Key = @c_QC_Key 
                     AND   r.QCLineNo = @c_QCLineNo 

                     SET @b_exploded = 1
                  END TRY

                  BEGIN CATCH          
                     SET @b_Success = 0                                                               -- CZTENG01 (START)
                     SET @n_err     = 555152
                     SET @c_ErrMsg  = ERROR_MESSAGE()
                     SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                                    + ': Insert into InventoryQCDetail Fail. (lsp_IQC_ExplodeByPackKey_Wrapper)' 
                                    + '( ' + @c_ErrMsg + ' )'   

                     IF (XACT_STATE()) = -1  
                     BEGIN
                        ROLLBACK TRAN

                        WHILE @@TRANCOUNT < @n_StartTCnt
                        BEGIN
                           BEGIN TRAN
                        END
                     END  
                  END CATCH                                                                           -- CZTENG01 (END) 

                  IF @n_Err <> 0 
                  BEGIN
                     GOTO EXIT_SP
                  END 
               END
               ELSE
               BEGIN
                  -- Update Original Line
                  BEGIN TRY
                     UPDATE InventoryQCDetail 
                     SET Qty = @n_InsertQty                       --(Wan02) --Qty -  @n_InsertQty 
                       , ToQty = @n_InsertQty                     --(Wan02) 
                       , OriginalQty = @n_InsertOriginalQty       --(Wan02) 
                       , ToID = @c_ToId                           --(Wan02) 
                       , EditDate = GETDATE()
                       , EditWho = @c_UserName 
                     WHERE QC_Key = @c_QC_Key
                     AND   QCLineNo = @c_QCLineNo 
                  END TRY

                  BEGIN CATCH        
                     SET @b_Success = 0                                                                   -- CZTENG01 (START)
                     SET @n_err     = 555153
                     SET @c_ErrMsg  = ERROR_MESSAGE()
                     SET @c_errmsg  = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                                    + ': Update InventoryQCDetail Fail. (lsp_IQC_ExplodeByPackKey_Wrapper)'
                                    + '( ' + @c_ErrMsg + ' )'

                     IF (XACT_STATE()) = -1  
                     BEGIN
                        ROLLBACK TRAN

                        WHILE @@TRANCOUNT < @n_StartTCnt
                        BEGIN
                           BEGIN TRAN
                        END
                     END  
                  END CATCH                                                                              -- CZTENG01 (END)    

                  IF @n_Err <> 0 
                  BEGIN
                     GOTO EXIT_SP
                  END  
               END                              --(Wan01) START -- Insert if not Last Insert Qty ELSE Update Original Line                                                                          
            END -- @n_RemainQty >= @n_PalletCnt       
         END       
                         
         FETCH_NEXT:                       
         FETCH FROM CUR_InventoryQC_LINES INTO @c_QC_Key, @c_QCLineNo, @c_StorerKey 
                                          ,  @c_Sku, @c_UOM, @c_PackKey, @n_OriginalQty, @n_Qty, @c_Reason  
                                          ,  @c_FromLot, @c_FromLoc, @c_FromID, @c_ToLoc, @c_ToID
      END
    
      CLOSE CUR_InventoryQC_LINES
      DEALLOCATE CUR_InventoryQC_LINES    
   END TRY
   BEGIN CATCH
      SET @b_Success = 0         --(Wan03)
      SET @c_ErrMsg = 'IQC Explode Packkey fail. (lsp_IQC_ExplodeByPackKey_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH 
      
   EXIT_SP: 

   --(Wan03) - START
   IF (XACT_STATE()) = -1        
   BEGIN  
      SET @b_Success = 0
      ROLLBACK TRAN  
   END                           
   
   IF @b_Success = 0            
   BEGIN   
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > 0 
      BEGIN
         ROLLBACK TRAN
      END
      
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_IQC_ExplodeByPackKey_Wrapper'
   END
   ELSE 
   IF @b_Success = 1 
   BEGIN
      IF @b_exploded = 1 
      BEGIN
         SET @c_ErrMsg = 'IQC packkey exploded successfully' + CASE WHEN @c_AlertMsg = '' THEN '.' ELSE ' WITH Alert : ' + @c_AlertMsg END
      END
      ELSE
      IF @b_GenID = 1
      BEGIN
         SET @c_ErrMsg = 'IQC Explode-Pack Gen Pallet ID Successfully' + CASE WHEN @c_AlertMsg = '' THEN '.' ELSE ' WITH Alert : ' + @c_AlertMsg END
      END
      
      IF @c_AlertMsg <> ''
      BEGIN
         SET @b_Success = 2
      END
      
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   --(Wan03) - END
   
   REVERT
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_IQC_PopulateTradeReturn_Wrapper                 */                                                                                  
/* Creation Date: 2021-07-29                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2855 - UAT - TW  Populate from Receipt in Inventory QC */
/*          module does not map Receipt.Receiptkey to                   */
/*          InventoryQC.TradeReturnKey                                  */
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
/* 2021-07-29  Wan      1.0   Created.                                  */
/* 2021-09-22  Wan      1.0   DevOps Script Combine                      */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_IQC_PopulateTradeReturn_Wrapper]                                                                                                                     
      @c_QC_Key               NVARCHAR(10)         
   ,  @c_ReceiptKey           NVARCHAR(10) = '' 
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= '' OUTPUT   
   ,  @c_UserName             NVARCHAR(128)= ''  
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT                                                                                                                          
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt               INT = @@TRANCOUNT  
         ,  @n_Continue                INT = 1

         ,  @n_QCLineno                INT            = 0
         
         ,  @c_Facility_ASN            NVARCHAR(5)    = ''
         ,  @c_Facility_Fr             NVARCHAR(5)    = ''
         ,  @c_Storerkey               NVARCHAR(15)   = ''
         ,  @c_TradeReturnKey          NVARCHAR(20)   = ''
         ,  @c_QCLineno                NVARCHAR(5)    = ''
         
         ,  @c_TableName               NVARCHAR(50)   = 'InventoryQCDetail'
         ,  @c_SourceType              NVARCHAR(50)   = 'lsp_IQC_PopulateTradeReturn_Wrapper'
         
         ,  @c_Refkey1        NVARCHAR(20)   = ''                    
         ,  @c_Refkey2        NVARCHAR(20)   = ''                    
         ,  @c_Refkey3        NVARCHAR(20)   = ''                    
         ,  @c_WriteType      NVARCHAR(50)   = ''                    
         ,  @n_LogWarningNo   INT            = 0                     
         
         ,  @CUR_ERRLIST      CURSOR                                 
         
   DECLARE  @t_WMSErrorList   TABLE                                  
         (  RowID             INT            IDENTITY(1,1) 
         ,  TableName         NVARCHAR(10)   NOT NULL DEFAULT('')
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
               
   IF SUSER_SNAME() <> @c_UserName       
   BEGIN
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
   
   BEGIN TRY 
   
      SET @n_ErrGroupKey = 0

      --------------------------------------------------------
      -- Validation Start
      --------------------------------------------------------
      SET @c_Facility_ASN = ''
      SELECT @c_Facility_ASN = r.Facility
      FROM dbo.RECEIPT AS r WITH (NOLOCK)
      WHERE r.ReceiptKey = @c_Receiptkey

      SET @c_Facility_Fr = ''
      SET @c_Storerkey= ''
      SELECT @c_Facility_Fr = iq.from_facility
            ,@c_Storerkey= iq.Storerkey
            ,@c_TradeReturnKey = ISNULL(iq.TradeReturnKey,'')
      FROM dbo.InventoryQC AS iq WITH (NOLOCK)
      WHERE iq.QC_Key = @c_QC_key

      IF @c_Facility_Fr <> @c_Facility_ASN
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 559651
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_err) + ': ASN Facility does not same as IQC From Facility: ' + @c_Facility_Fr
                       + '(lsp_IQC_PopulateTradeReturn_Wrapper)' + ' |' + @c_Facility_Fr

         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_QC_Key, @c_Receiptkey, '', 'ERROR', 0, @n_err, @c_errmsg)   
            --EXEC [WM].[lsp_WriteError_List] 
            --   @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            --,  @c_TableName   = @c_TableName
            --,  @c_SourceType  = @c_SourceType
            --,  @c_Refkey1     = @c_QC_Key
            --,  @c_Refkey2     = @c_Receiptkey
            --,  @c_Refkey3     = ''
            --,  @c_WriteType   = 'ERROR' 
            --,  @n_err2        = @n_err 
            --,  @c_errmsg2     = @c_errmsg 
            --,  @b_Success     = @b_Success    
            --,  @n_err         = @n_err        
            --,  @c_errmsg      = @c_errmsg   
      END
      
      IF @c_TradeReturnKey <> ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 559652
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_err) + ': Trade Return had been populated to this IQC Document. '
                       + '(lsp_IQC_PopulateTradeReturn_Wrapper)'
          
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_QC_Key, @c_Receiptkey, '', 'ERROR', 0, @n_err, @c_errmsg)                 
         --EXEC [WM].[lsp_WriteError_List] 
         --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         --   ,  @c_TableName   = @c_TableName
         --   ,  @c_SourceType  = @c_SourceType
         --   ,  @c_Refkey1     = @c_QC_Key
         --   ,  @c_Refkey2     = @c_Receiptkey
         --   ,  @c_Refkey3     = ''
         --   ,  @c_WriteType   = 'ERROR' 
         --   ,  @n_err2        = @n_err 
         --   ,  @c_errmsg2     = @c_errmsg 
         --   ,  @b_Success     = @b_Success    
         --   ,  @n_err         = @n_err        
         --   ,  @c_errmsg      = @c_errmsg                        
      END
    
      IF @n_Continue = 3
      BEGIN
         GOTO EXIT_SP
      END
      --------------------------------------------------------
      -- Validation End
      --------------------------------------------------------
      
      BEGIN TRAN
      SELECT TOP 1 @c_QCLineno = iqd.QCLineNo
      FROM dbo.InventoryQCDetail AS iqd WITH (NOLOCK)
      WHERE iqd.QC_Key = @c_QC_Key
      ORDER BY iqd.QCLineNo DESC
      
      SET @n_QCLineno = CONVERT(INT, @c_QCLineno)
      
      INSERT INTO dbo.InventoryQCDetail
          (
              QC_Key
          ,   QCLineNo
          ,   StorerKey
          ,   SKU
          ,   PackKey
          ,   UOM
          ,   OriginalQty
          ,   FromLoc
          ,   FromLot
          ,   FromID
          )
      SELECT
            QC_Key = @c_QC_Key
          , QCLineNo = RIGHT('00000' + CONVERT(NVARCHAR(5), @n_QCLineno + ROW_NUMBER() OVER (ORDER BY r2.ReceiptLineNumber)) , 5) 
          , r2.StorerKey
          , r2.Sku   
          , s.PackKey   
          , p.PackUOM3
          , r2.QtyReceived
          , r2.Toloc 
          , i.Lot           
          , r2.ToID
      FROM dbo.RECEIPT AS r WITH (NOLOCK)
      JOIN dbo.RECEIPTDETAIL AS r2 WITH (NOLOCK) ON r2.ReceiptKey = r.ReceiptKey
      JOIN dbo.SKU AS s  WITH (NOLOCK) ON s.StorerKey = r2.StorerKey AND s.Sku = r2.Sku
      JOIN dbo.PACK AS p WITH (NOLOCK) ON s.PACKKey = p.PackKey 
      JOIN dbo.ITRN AS i WITH (NOLOCK) ON  i.TranType = 'DP'
                                       AND i.SourceKey = r2.ReceiptKey + r2.ReceiptLineNumber
                                       AND i.SourceType IN ('ntrReceiptDetailAdd', 'ntrReceiptDetailUpdate')
      WHERE  r.ReceiptKey = @c_ReceiptKey
      AND r2.QtyReceived > 0
      AND r2.FinalizeFlag = 'Y'
      
      IF @@ROWCOUNT = 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 559653
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_err) + ': Unable to populate to QC#: ' + @c_QC_Key
                       + ' from Trade Return#: ' + @c_ReceiptKey 
                       + '(lsp_IQC_PopulateTradeReturn_Wrapper) |' + @c_QC_Key + '|' + @c_ReceiptKey
                       
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_QC_Key, @c_Receiptkey, '', 'ERROR', 0, @n_err, @c_errmsg)                 
         --EXEC [WM].[lsp_WriteError_List] 
         --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         --   ,  @c_TableName   = @c_TableName
         --   ,  @c_SourceType  = @c_SourceType
         --   ,  @c_Refkey1     = @c_QC_Key
         --   ,  @c_Refkey2     = @c_Receiptkey
         --   ,  @c_Refkey3     = ''
         --   ,  @c_WriteType   = 'ERROR' 
         --   ,  @n_err2        = @n_err 
         --   ,  @c_errmsg2     = @c_errmsg 
         --   ,  @b_Success     = @b_Success    
         --   ,  @n_err         = @n_err        
         --   ,  @c_errmsg      = @c_errmsg                        
         GOTO EXIT_SP         
      END
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 559654
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_err) + ': Error insert into InventoryQCDetail. (lsp_IQC_PopulateTradeReturn_Wrapper)' 
                       + ' (' + @c_ErrMsg + ')'
         
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_QC_Key, @c_Receiptkey, '', 'ERROR', 0, @n_err, @c_errmsg)                 
         --EXEC [WM].[lsp_WriteError_List] 
         --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         --   ,  @c_TableName   = @c_TableName
         --   ,  @c_SourceType  = @c_SourceType
         --   ,  @c_Refkey1     = @c_QC_Key
         --   ,  @c_Refkey2     = @c_Receiptkey
         --   ,  @c_Refkey3     = ''
         --   ,  @c_WriteType   = 'ERROR' 
         --   ,  @n_err2        = @n_err 
         --   ,  @c_errmsg2     = @c_errmsg 
         --   ,  @b_Success     = @b_Success    
         --   ,  @n_err         = @n_err        
         --   ,  @c_errmsg      = @c_errmsg  
         GOTO EXIT_SP   
      END
      
      UPDATE iq WITH (ROWLOCK)
         SET iq.TradeReturnKey = @c_Receiptkey
            ,iq.EditWho = SUSER_SNAME()
            ,iq.EditDate= GETDATE()
      FROM dbo.InventoryQC AS iq
      WHERE iq.QC_Key = @c_QC_Key
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 559655
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_err) + ': Error Update InventoryQC Table. (lsp_IQC_PopulateTradeReturn_Wrapper)' 
                       + ' (' + @c_ErrMsg + ')'
              
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_QC_Key, @c_Receiptkey, '', 'ERROR', 0, @n_err, @c_errmsg)                
         --EXEC [WM].[lsp_WriteError_List] 
         --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         --   ,  @c_TableName   = @c_TableName
         --   ,  @c_SourceType  = @c_SourceType
         --   ,  @c_Refkey1     = @c_QC_Key
         --   ,  @c_Refkey2     = @c_Receiptkey
         --   ,  @c_Refkey3     = ''
         --   ,  @c_WriteType   = 'ERROR' 
         --   ,  @n_err2        = @n_err 
         --   ,  @c_errmsg2     = @c_errmsg 
         --   ,  @b_Success     = @b_Success    
         --   ,  @n_err         = @n_err        
         --   ,  @c_errmsg      = @c_errmsg  
         GOTO EXIT_SP   
      END
   END TRY  
  
   BEGIN CATCH 
      SET @n_Continue = 3                 
      SET @c_ErrMsg   = ERROR_MESSAGE()   
      
      --Log Error to WMS_Error_List
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
      VALUES (@c_TableName, @c_SourceType, @c_QC_Key, @c_Receiptkey, '', 'ERROR', 0, @n_err, @c_errmsg)   
      --EXEC [WM].[lsp_WriteError_List] 
      --         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
      --      ,  @c_TableName   = @c_TableName
      --      ,  @c_SourceType  = @c_SourceType
      --      ,  @c_Refkey1     = @c_QC_Key
      --      ,  @c_Refkey2     = @c_Receiptkey
      --      ,  @c_Refkey3     = ''
      --      ,  @c_WriteType   = 'ERROR' 
      --      ,  @n_err2        = @n_err 
      --      ,  @c_errmsg2     = @c_errmsg 
      --      ,  @b_Success     = @b_Success    
      --      ,  @n_err         = @n_err        
      --      ,  @c_errmsg      = @c_errmsg      
      GOTO EXIT_SP  
   END CATCH 
EXIT_SP:
   IF (XACT_STATE()) = -1  
   BEGIN
      ROLLBACK TRAN
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
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_IQC_PopulateTradeReturn_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
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
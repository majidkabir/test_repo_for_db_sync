SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_ASN_RCM_NikeSECPA                            */                                                                                  
/* Creation Date: 2023-02-24                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3699 - CLONE - [CN]NIKE_TRADE RETURN_Suggest PA loc    */
/*        : (Pre-finalize)by batch ASN                                  */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.1                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2023-02-24  Wan01    1.0   Created & DevOps Combine Script.          */
/* 2023-04-20  NJOW01   1.1   WMS-22388 Include Calloff PA and determine*/
/*                            the execution by warehouserefernece='Y'   */
/************************************************************************/ 
CREATE   PROC [WM].[lsp_ASN_RCM_NikeSECPA] 
   @c_ReceiptKey     NVARCHAR(MAX)              
,  @b_Success        INT          = 1   OUTPUT   
,  @n_Err            INT          = 0   OUTPUT
,  @c_Errmsg         NVARCHAR(255)= ''  OUTPUT
,  @c_UserName       NVARCHAR(128)= ''
,  @c_Code           NVARCHAR(30) = ''         
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt          INT  
         , @n_Continue           INT
         
         , @c_Storerkey          NVARCHAR(15)  = ''
         , @c_ProcessType        NVARCHAR(10)  = 'PUTAWAY'
         , @c_DocumentKey1       NVARCHAR(50)  = ''
         , @c_SourceType         NVARCHAR(50)  = 'lsp_ASN_RCM_NikeSECPA'
         , @c_CallType           NVARCHAR(50)  = ''
         , @c_ExecCmd            NVARCHAR(MAX) = ''   
         , @c_WarehouseReference NVARCHAR(18)  = '' --NJOW01
         , @n_Cnt                INT           = 0  --NJOW01
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
  
   BEGIN TRY
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
      
      SELECT @c_Storerkey = r.StorerKey
      FROM dbo.RECEIPT AS r WITH (NOLOCK)
      WHERE r.ReceiptKey = LEFT(@c_ReceiptKey,10)
      
      SET @c_DocumentKey1 = LEFT(@c_ReceiptKey,10)
      IF LEN(@c_ReceiptKey) > 10
      BEGIN
         SET @c_DocumentKey1 = @c_DocumentKey1 + ' (1st key of multikey)'
      END
      
      --NJOW01 S
      SELECT @c_WarehouseReference = MAX(R.WarehouseReference),
             @n_Cnt = COUNT(DISTINCT ISNULL(R.WarehouseReference,''))
      FROM RECEIPT R (NOLOCK)
      WHERE R.Receiptkey IN (SELECT Value FROM STRING_SPLIT(@c_ReceiptKey, ','))   
      
      IF @c_WarehouseReference IS NULL
         SET @c_WarehouseReference = ''
      
      IF @n_Cnt > 1
      BEGIN                                                                                	
         SET @n_continue = 3  
         SET @n_Err = 561601 
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Not allow to select the ASN with multiple Warehousereference values.'
                       + ' (lsp_ASN_RCM_NikeSECPA)'  
         GOTO EXIT_SP   
      END      
      ELSE IF @c_WarehouseReference NOT IN ('','Y')
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 561602 
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Warehousereference value must be Y or blank.'
                       + ' (lsp_ASN_RCM_NikeSECPA)'  
         GOTO EXIT_SP         	
      END
      ELSE IF @c_WarehouseReference = 'Y'  --Calloff PA
      BEGIN
         SET @c_CallType = 'ispBatPA04'
         SET @c_ExecCmd = 'dbo.ispBatPA04'
                        + ' @c_ReceiptKey = ''' + @c_Receiptkey + ''''
                        + ',@b_Success = @b_Success OUTPUT'
                        + ',@n_Err = @n_Err OUTPUT'
                        + ',@c_ErrMsg = @c_Errmsg OUTPUT'
                                          
      END  --NJOW01 E
      ELSE 
      BEGIN
         SET @c_CallType = 'ispBatPA03'
         SET @c_ExecCmd = 'dbo.ispBatPA03'
                        + ' @c_ReceiptKey = ''' + @c_Receiptkey + ''''
                        + ',@b_Success = @b_Success OUTPUT'
                        + ',@n_Err = @n_Err OUTPUT'
                        + ',@c_ErrMsg = @c_Errmsg OUTPUT'
      END                     
    
      EXEC [WM].[lsp_BackEndProcess_Submit]                                                                                                                     
            @c_Storerkey      = @c_Storerkey
         ,  @c_ModuleID       = 'Receipt' 
         ,  @c_DocumentKey1   = @c_DocumentKey1  
         ,  @c_DocumentKey2   = ''      
         ,  @c_DocumentKey3   = ''      
         ,  @c_ProcessType    = @c_ProcessType   
         ,  @c_SourceType     = @c_SourceType    
         ,  @c_CallType       = @c_CallType
         ,  @c_RefKey1        = ''      
         ,  @c_RefKey2        = ''      
         ,  @c_RefKey3        = ''   
         ,  @c_ExecCmd        = @c_ExecCmd  
         ,  @c_StatusMsg      = 'Submitted to BackEndProcessQueue.'
         ,  @b_Success        = @b_Success   OUTPUT  
         ,  @n_err            = @n_err       OUTPUT                                                                                                             
         ,  @c_ErrMsg         = @c_ErrMsg    OUTPUT  
         ,  @c_UserName       = ''
   END TRY
   BEGIN CATCH
        SET @n_Continue = 3  
   END CATCH
EXIT_SP:  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ASN_RCM_NikeSECPA'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END
   REVERT  
END -- procedure  

GO
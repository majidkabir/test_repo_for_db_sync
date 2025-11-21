SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_ASNStatus_Close_Wrapper                         */  
/* Creation Date: 04-MAY-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-730 - Stored Procedure fro ASNReceipt Close             */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 2021-02-05   mingle01 1.1  Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/  
CREATE PROCEDURE [WM].[lsp_ASNStatus_Close_Wrapper]  
   @c_ReceiptKey     NVARCHAR(15)
,  @b_Success        INT          = 1   OUTPUT   
,  @n_Err            INT          = 0   OUTPUT
,  @c_Errmsg         NVARCHAR(255)= ''  OUTPUT
,  @c_UserName       NVARCHAR(128)= ''
,  @n_ErrGroupKey    INT = 0 OUTPUT
,  @n_WarningNo      INT = 0       OUTPUT
,  @c_ProceedWithWarning CHAR(1) = 'N'
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @c_TableName       NVARCHAR(50)
         , @c_SourceType      NVARCHAR(30)

         , @c_Facility        NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15)

         , @c_OWITF           NVARCHAR(30)

   SET @b_Success = 1
   SET @c_ErrMsg = ''
   SET @c_TableName = 'RECEIPT'
   SET @c_SourceType= 'lsp_ASNStatus_Close_Wrapper'
   SET @n_ErrGroupKey = 0

   SET @n_Err = 0 
      
   --(mingle01) - START
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
   
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END
   --(mingle01) - END

   --(mingle01) - START
   BEGIN TRY
      IF ( @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1 ) 
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM RECEIPTDETAIL RD WITH (NOLOCK) 
                     WHERE RD.ReceiptKey = @c_ReceiptKey
                     AND RD.Finalizeflag <> 'Y'
                   )
         BEGIN
            SET @n_continue  = 3
            SET @c_ErrMsg= 'There is Receiptdetail not finalized. Are you sure you want to proceed to close ASN?'
            SET @n_WarningNo = 1
            GOTO EXIT_SP
         END 
      END


      SET @c_Facility = ''
      SET @c_Storerkey= ''
      SELECT @c_Facility = Facility
            ,@c_Storerkey= Storerkey
      FROM RECEIPT WITH (NOLOCK)
      WHERE Receiptkey = @c_Receiptkey

      BEGIN TRY
         EXECUTE dbo.nspGetRight 
               @c_facility  = @c_Facility
            ,  @c_storerkey = @c_Storerkey 
            ,  @c_sku       = NULL
            ,  @c_configkey = 'OWITF'
            ,  @b_Success   = @b_Success  OUTPUT
            ,  @c_authority = @c_OWITF    OUTPUT
            ,  @n_err       = @n_err      OUTPUT
            ,  @c_errmsg    = @c_errmsg   OUTPUT 
      END TRY

      BEGIN CATCH
         SET @n_err = 550201
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nspGetRight'
                        + '. (lsp_ASNStatus_Close_Wrapper)'
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
      END 

      --IF @c_OWITF = '1'
      --BEGIN
      --   IF ( SELECT ISNULL(SUM(RD.QtyReceived),0)
      --        FROM   RECEIPTDETAIL RD (NOLOCK)
      --        WHERE  RD.Receiptkey = @c_Receiptkey
      --        AND    RD.FinalizeFlag = 'Y'
      --        GROUP BY RD.Receiptkey
      --       ) = 0
      --   BEGIN
      --      SET @n_continue = 3   
      --      SET @n_err = 550202
      --      SET @c_ErrMsg = ERROR_MESSAGE()
      --      SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Not Allow to CLOSE before Finalized the receipt'
      --                    + '. (lsp_ASNStatus_Close_Wrapper)'

      --      EXEC [WM].[lsp_WriteError_List] 
      --            @i_iErrGroupKey  = @n_ErrGroupKey OUTPUT
      --            , @c_TableName   = @c_TableName
      --            , @c_SourceType  = @c_SourceType
      --            , @c_Refkey1     = @c_ReceiptKey
      --            , @c_Refkey2     = ''
      --            , @c_Refkey3     = ''
      --            , @n_err2        = @n_err
      --            , @c_errmsg2     = @c_errmsg
      --            , @b_Success     = @b_Success   OUTPUT
      --            , @n_err         = @n_err       OUTPUT
      --            , @c_errmsg      = @c_errmsg    OUTPUT
      --   END
      --END
   
      IF @n_continue IN (1,2)
      BEGIN
         BEGIN TRY

            UPDATE RECEIPT WITH (ROWLOCK)
               SET ASNStatus ='9'
            WHERE ReceiptKey = @c_Receiptkey 
         END TRY
 
         BEGIN CATCH
            SET @n_err = 550203
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Update Receipt Fail. (lsp_ASNStatus_Close_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
         END CATCH    

         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END  
      END
   END TRY

   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ASNStatus_Close_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      SET @n_WarningNo = 0
   END

   REVERT      
END  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_QCGenTNITF_Wrapper                              */  
/* Creation Date: 09-OCT-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-1253 - Stored Procedures for Feature ¿C Inventory        */
/*        : Inventory QC                                                 */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 2021-02-09   mingle01 1.1  Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_QCGenTNITF_Wrapper]  
   @c_QC_key         NVARCHAR(10)
,  @b_Success        INT          = 1  OUTPUT   
,  @n_Err            INT          = 0  OUTPUT
,  @c_Errmsg         NVARCHAR(255)= '' OUTPUT
,  @c_UserName       NVARCHAR(128)= ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @c_Storerkey       NVARCHAR(15)
         , @c_Type            NVARCHAR(10)  = ''
         
         , @c_TNITF           NVARCHAR(20)  = ''
         , @c_ITFSetupType    NVARCHAR(60)  = ''

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 
   
   --(mingle01) - START   
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
   --(mingle01) - END
   
   --(mingle01) - START
   BEGIN TRY
      SELECT @c_Storerkey  = IQC.Storerkey
            ,@c_Type       = ISNULL(RTRIM(IQC.Reason),'')
      FROM INVENTORYQC IQC WITH (NOLOCK)
      WHERE QC_key = @c_QC_key

      BEGIN TRY
         SET @b_Success = 1
         EXEC nspGetRight 
               @c_Facility = ''
            ,  @c_Storerkey = @c_Storerkey
            ,  @c_sku       = ''
            ,  @c_ConfigKey = 'TNITF'       
            ,  @b_Success   = @b_Success  OUTPUT
            ,  @c_authority = @c_TNITF    OUTPUT
            ,  @n_err       = @n_err      OUTPUT
            ,  @c_errmsg    = @c_errmsg   OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 554401
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                        + ': Error Executing nspGetRight - TNITF. (lsp_QCGenTNITF_Wrapper)'
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
      END   

      IF @c_TNITF <> '1'
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 554402
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                       + ': No interface generated, TNITF Storer configkey not enable! (lsp_QCGenTNITF_Wrapper)'
                       + ' (' + @c_ErrMsg + ')'
         GOTO EXIT_SP
      END

      SELECT @c_ITFSetupType = ISNULL(RTRIM(Long), '')
      FROM  CODELKUP WITH (NOLOCK)
      WHERE Listname = 'IQCType'
      AND   CODE = @c_Type

      IF @c_ITFSetupType <> 'TNITF'
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 554403
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                       + ': No interface generated, QCType Codelkup.Long Isn''t TNITF! (lsp_QCGenTNITF_Wrapper)'
         GOTO EXIT_SP
      END

      BEGIN TRY
         SET @b_success = 1
         EXEC ispGenTransmitLog3
               @c_TableName      = 'TNIQC'  
            ,  @c_Key1           = @c_QC_key
            ,  @c_Key2           = ''
            ,  @c_Key3           = @c_Storerkey
            ,  @c_TransmitBatch  = ''
            ,  @b_success        = @b_success   OUTPUT 
            ,  @n_err            = @n_err       OUTPUT 
            ,  @c_errmsg         = @c_errmsg    OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 554404
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                        + ': Error Executing ispGenTransmitLog3 - TableName: TNIQC. (lsp_QCGenTNITF_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_QCGenTNITF_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN 
      BEGIN TRAN
   END

   REVERT      
END  

GO
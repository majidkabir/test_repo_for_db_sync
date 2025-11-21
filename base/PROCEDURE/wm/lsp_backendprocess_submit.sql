SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_BackEndProcess_Submit                        */                                                                                  
/* Creation Date: 2023-02-24                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose:                                                             */
/*                                                                      */                                                                                  
/* Purpose: LFWM-3699 - CLONE - [CN]NIKE_TRADE RETURN_Suggest PA loc    */
/*        : (Pre-finalize)by batch ASN                                  */                                                                               
/* PVCS Version: 1.1                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2022-12-12  Wan      1.0   Created & DevOps Combine Script           */
/* 2023-04-11  Wan01    1.1   LFWM-4153 - UAT - CN  All Generating Ecom */
/*                            Replenishment                             */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_BackEndProcess_Submit]                                                                                                                     
   @c_Storerkey            NVARCHAR(10)
,  @c_ModuleID             NVARCHAR(30)   = ''
,  @c_DocumentKey1         NVARCHAR(50)   = ''      
,  @c_DocumentKey2         NVARCHAR(30)   = ''      
,  @c_DocumentKey3         NVARCHAR(30)   = ''      
,  @c_ProcessType          NVARCHAR(30)       
,  @c_SourceType           NVARCHAR(50)               --(Wan01) fix to follow table column length      
,  @c_CallType             NVARCHAR(50)               --(Wan01) fix to follow table column length
,  @c_RefKey1              NVARCHAR(30)   = ''      
,  @c_RefKey2              NVARCHAR(30)   = ''      
,  @c_RefKey3              NVARCHAR(30)   = ''   
,  @c_ExecCmd              NVARCHAR(MAX)
,  @c_StatusMsg            NVARCHAR(250)  = ''
,  @b_Success              INT            = 1  OUTPUT  
,  @n_err                  INT            = 0  OUTPUT                                                                                                             
,  @c_ErrMsg               NVARCHAR(255)  = '' OUTPUT  
,  @c_UserName             NVARCHAR(128)  = ''
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       
     
   DECLARE  @n_StartTCnt                  INT            = @@TRANCOUNT 
         ,  @n_Continue                   INT            = 1

   BEGIN TRY  
      IF SUSER_SNAME() <> @c_UserName AND @c_UserName <> ''
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

      INSERT INTO dbo.BackEndProcessQueue
         (  Storerkey 
         ,  ModuleID                 
         ,  DocumentKey1               
         ,  DocumentKey2               
         ,  DocumentKey3               
         ,  ProcessType                
         ,  SourceType                 
         ,  CallType                   
         ,  RefKey1                    
         ,  RefKey2                    
         ,  RefKey3                    
         ,  ExecCmd                    
         ,  [Status]                   
         ,  StatusMsg                  
         )
      VALUES
         (
            @c_Storerkey 
         ,  @c_ModuleID                     
         ,  @c_DocumentKey1               
         ,  @c_DocumentKey2               
         ,  @c_DocumentKey3               
         ,  @c_ProcessType                
         ,  @c_SourceType                 
         ,  @c_CallType 
         ,  @c_RefKey1      
         ,  @c_RefKey2      
         ,  @c_RefKey3                                                
         ,  @c_ExecCmd                    
         ,  '0'  
         ,  @c_StatusMsg                
         )

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
      END
   END TRY
   BEGIN CATCH 
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP 
   END CATCH   
EXIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'WM.lsp_BackEndProcess_Submit'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @n_StartTCnt > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
      
   REVERT
END

GO
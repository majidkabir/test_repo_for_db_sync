SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.[lsp_BackEndProcess_ExecCmd]                     */                                                                                  
/* Creation Date: 2023-02-24                                            */                                                                                  
/* Copyright: Maersk                                                    */                                                                                  
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
/* 2023-05-12  Wan02    1.1   LFWM-4184 - PROD - CN  Lululemon ECOM     */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_BackEndProcess_ExecCmd]                                                                                                                     
   @c_Storerkey   NVARCHAR(15)   = ''
,  @c_ProcessType NVARCHAR(1000) = '' -- Multiple Types seperated by '|'
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt   INT            = @@TRANCOUNT  
         ,  @n_Continue    INT            = 1
         ,  @b_Success     INT            = 1    
         ,  @n_Err         INT            = 0                                                                                                               
         ,  @c_ErrMsg      NVARCHAR(255)  = '' 
         
         ,  @n_ProcessID   BIGINT         = 0
         ,  @c_Status      NVARCHAR(10)   = '9'
         ,  @c_StatusMsg   NVARCHAR(255)  = ''
         ,  @c_UserName    NVARCHAR(128)  = ''

         ,  @c_SQL         NVARCHAR(MAX)  = ''
         ,  @c_SQLParms    NVARCHAR(1000) = ''

         ,  @CUR_PROC      CURSOR

   SET @CUR_PROC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT bepq.ProcessID
         ,bepq.ExecCmd
         ,UserName = REPLACE(bepq.Addwho, 'alpha\', '')
   FROM dbo.BackEndProcessQueue bepq WITH (NOLOCK)
   WHERE bepq.Storerkey = @c_Storerkey
   AND bepq.ProcessType = @c_ProcessType
   AND bepq.[Status] = '1'
      
   OPEN @CUR_PROC
      
   FETCH NEXT FROM @CUR_PROC INTO @n_ProcessID, @c_SQL, @c_UserName
      
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      BEGIN TRY 
         BEGIN TRAN
 
         SET @n_Continue = 1
         SET @c_Status   = ''
         SET @c_StatusMsg= ''
         
         IF SUSER_SNAME() <> @c_UserName AND @c_UserName <> ''
         BEGIN
            EXEC [WM].[lsp_SetUser] 
                  @c_UserName = @c_UserName  OUTPUT
               ,  @n_Err      = @n_Err       OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
            IF @n_Err <> 0 
            BEGIN
               SET @n_Continue = 3
            END
    
            EXECUTE AS LOGIN = @c_UserName
         END

         IF @n_Continue IN (1,2)
         BEGIN
            SET @b_Success = 1
            SET @n_Err     = 0
            SET @c_ErrMsg  = ''
            EXEC [WM].[lsp_BackEndProcess_StatusUpd]                                                                                                                     
               @n_ProcessID   = @n_ProcessID
            ,  @c_Status      = '3'          -- in progress
            ,  @c_StatusMsg   = 'Back End Process Execution In Progress.'
            ,  @b_Success     = @b_Success   OUTPUT
            ,  @n_Err         = @n_Err       OUTPUT
            ,  @c_ErrMsg      = @c_ErrMsg    OUTPUT
              
            IF @b_Success = 0 
            BEGIN
               SET @n_Continue = 3
            END
         END
              
         IF @n_Continue IN (1,2)
         BEGIN  
            SET @b_Success = 1
            SET @n_Err     = 0
            SET @c_ErrMsg  = '' 
            SET @c_SQLParms = N'@b_Success     INT            OUTPUT' 
                            + ',@n_Err         INT            OUTPUT' 
                            + ',@c_ErrMsg      NVARCHAR(255)  OUTPUT' 

            EXEC sp_ExecuteSQL @c_SQL 
                              ,@c_SQLParms
                              ,@b_Success    OUTPUT  
                              ,@n_Err        OUTPUT                                                                                                             
                              ,@c_ErrMsg     OUTPUT 

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
            END
         END 
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3                                                        --Wan02
         IF (XACT_STATE()) = -1                                     
         BEGIN
            ROLLBACK TRAN
         END 
         SET @c_ErrMsg = ERROR_MESSAGE()     
      END CATCH
         IF @n_Continue=3  
         BEGIN
            IF @@TRANCOUNT > 0 
            BEGIN
               ROLLBACK TRAN
            END
            SET @c_Status = '5'
            SET @c_StatusMsg = @c_ErrMsg
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0 
            BEGIN
               COMMIT TRAN
            END
            SET @c_Status = '9'
            SET @c_StatusMsg = ''  
         END
         
         EXEC [WM].[lsp_BackEndProcess_StatusUpd]                                                                                                                     
            @n_ProcessID   = @n_ProcessID
         ,  @c_Status      = @c_Status   
         ,  @c_StatusMsg   = @c_StatusMsg
         ,  @b_Success     = @b_Success   OUTPUT
         ,  @n_Err         = @n_Err       OUTPUT
         ,  @c_ErrMsg      = @c_ErrMsg    OUTPUT

      REVERT 
      FETCH NEXT FROM @CUR_PROC INTO @n_ProcessID, @c_SQL, @c_UserName
   END
   CLOSE @CUR_PROC
   DEALLOCATE @CUR_PROC   
EXIT_SP:         

END

GO
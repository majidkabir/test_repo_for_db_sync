SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_CopyValue_Wrapper                               */  
/* Creation Date: 2023-02-12                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-3648 - [CN]NIKE_TradeReturnASNReceipt_Ã­â–’Copy value to    */
/*          support all details in one receiptkey                        */                                                       
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.1                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date       Author   Ver   Purposes                                    */ 
/* 2023-02-12 Wan      1.0   Created & DevOps Combine Script             */
/* 2023-05-22 Wan01    1.1   LFWM-3964: Fix Where Clause Issue- SP SQL   */
/*                           vary from SQL search button                 */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_CopyValue_Wrapper]  
   @c_TableName            NVARCHAR(50)         --TableName To Copy From and To
,  @c_ColumnName           NVARCHAR(50)         --Table Column name to from and To
,  @c_CopyFromKey1         NVARCHAR(30)         --Copy Column Value from record's Primarykey 1
,  @c_CopyFromKey2         NVARCHAR(30)   = ''  --Copy Column Value from record's Primarykey 2 if any
,  @c_CopyFromKey3         NVARCHAR(30)   = ''  --Copy Column Value from record's Primarykey 3 if any
,  @c_SearchSQL            NVARCHAR(MAX)  = ''  --Search SQL For Copy from Master Table and To  --Wan01
,  @b_Success              INT            = 1   OUTPUT    
,  @n_Err                  INT            = 0   OUTPUT
,  @c_Errmsg               NVARCHAR(255)  = ''  OUTPUT
,  @c_UserName             NVARCHAR(128)  = ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
           @n_StartTCnt INT            = @@TRANCOUNT
         , @n_Continue  INT            = 1
         
         , @c_CopyValue NVARCHAR(4000) = ''
         , @c_SQL       NVARCHAR(4000) = ''
         , @c_SQLParms  NVARCHAR(4000) = ''
         
         , @c_SPName    NVARCHAR(50)   = ''
         
   SET @n_Err = 0 

   BEGIN TRY
      SET @b_Success = 1
      SET @n_Err = 0 
      SET @c_Errmsg = ''
      
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
      
      SET @c_SPName = 'WM.lsp_CopyValue_' + RTRIM(@c_TableName) + '_Std'

      IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects so WHERE id = OBJECT_ID(@c_SPName) AND TYPE= 'P')
      BEGIN
         GOTO EXIT_SP
      END 
     
      SET @c_SQL = N'EXEC ' + @c_SPName
                 + ' @c_TableName   = @c_TableName '
                 + ',@c_ColumnName  = @c_ColumnName'
                 + ',@c_CopyFromKey1= @c_CopyFromKey1'
                 + ',@c_CopyFromKey2= @c_CopyFromKey2'
                 + ',@c_CopyFromKey3= @c_CopyFromKey3'
                 + ',@c_SearchSQL   = @c_SearchSQL'                                 --(Wan01)        
                 --+ ',@c_SearchCondition=@c_SearchCondition'                       --(Wan01)               
                 + ',@b_Success     = @b_Success   OUTPUT'    
                 + ',@n_Err         = @n_Err       OUTPUT'
                 + ',@c_Errmsg      = @c_Errmsg    OUTPUT'
  
      SET @c_SQLParms = N'@c_TableName       NVARCHAR(50)' 
                      + ',@c_ColumnName      NVARCHAR(50)'
                      + ',@c_CopyFromKey1    NVARCHAR(30)'
                      + ',@c_CopyFromKey2    NVARCHAR(30)'
                      + ',@c_CopyFromKey3    NVARCHAR(30)'
                      + ',@c_SearchSQL       NVARCHAR(MAX)'                         --(Wan01)                    
                      --+ ',@c_SearchCondition NVARCHAR(MAX)'                       --(Wan01)
                      + ',@b_Success         INT             OUTPUT'    
                      + ',@n_Err             INT             OUTPUT'
                      + ',@c_Errmsg          NVARCHAR(255)   OUTPUT'

      SET @b_Success = 1   
      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_TableName     
                        ,@c_ColumnName    
                        ,@c_CopyFromKey1  
                        ,@c_CopyFromKey2  
                        ,@c_CopyFromKey3 
                        ,@c_SearchSQL                                               --(Wan01)                    
                        --,@c_SearchCondition                                       --(Wan01)
                        ,@b_Success       OUTPUT    
                        ,@n_Err           OUTPUT
                        ,@c_Errmsg        OUTPUT
        
      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_SP
      END
   END TRY

   BEGIN CATCH
      SET @n_continue = 3 
      SET @c_errmsg = ERROR_MESSAGE()
      GOTO EXIT_SP      
   END CATCH 
        
   EXIT_SP:  

   IF (XACT_STATE()) = -1  
   BEGIN
      SET @n_Continue = 3 
      ROLLBACK TRAN
   END  
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, '[lsp_CopyValue_Wrapper]'
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
 END

GO
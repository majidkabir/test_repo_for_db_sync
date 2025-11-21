SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_ASRSCallOutIDInsp_Wrapper                       */  
/* Creation Date: 05-APR-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-505 - ASRS  ID Inspection & Pack and Hold               */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.1                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver  Purposes                                    */ 
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                     */
/* 2021-01-15  Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_ASRSCallOutIDInsp_Wrapper]  
   @c_PalletIDList   NVARCHAR(MAX)
,  @c_FinalLoc       NVARCHAR(10)
,  @c_ReasonCode     NVARCHAR(30)
,  @c_Remarks        NVARCHAR(255)
,  @b_Success        INT          = 1  OUTPUT   
,  @n_Err            INT          = 0  OUTPUT
,  @c_Errmsg         NVARCHAR(255)= '' OUTPUT
,  @c_UserName       NVARCHAR(128)= ''
,  @n_ErrGroupKey    INT = 0           OUTPUT
AS  
BEGIN  
   SET ANSI_NULLS ON
   SET ANSI_PADDING ON
   SET ANSI_WARNINGS ON
   SET QUOTED_IDENTIFIER ON
   SET CONCAT_NULL_YIELDS_NULL ON
   SET ARITHABORT ON

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @c_ID              NVARCHAR(18)
         , @c_SourceType      NVARCHAR(50)  =  'lsp_ASRSCallOutIDInsp_Wrapper'

         , @CUR_ID            CURSOR

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 
   
   IF SUSER_SNAME() <> @c_UserName        --(Wan01) - START
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
   END                                    --(Wan01) - END

   
   BEGIN TRY -- SWT01 - Begin Outer Begin Try
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   
      IF ISNULL(RTRIM(@c_FinalLoc),'') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 550451
         SET @c_errmsg = 'NSQL' + CONVERT(NCHAR(6),@n_err) + ': Workstation is required.' 

         EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = ''
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_PalletIDList
                  ,  @c_Refkey2     = ''
                  ,  @c_Refkey3     = ''
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg    OUTPUT

         GOTO EXIT_SP      
      END 

      IF ISNULL(RTRIM(@c_ReasonCode),'') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 550452
         SET @c_errmsg = 'NSQL' + CONVERT(NCHAR(6),@n_err) + ': Reason Code is required.' 
  
         EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = ''
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_PalletIDList
                  ,  @c_Refkey2     = ''
                  ,  @c_Refkey3     = ''
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg    OUTPUT
         GOTO EXIT_SP  
      END

      IF LEN(RTRIM(@c_ReasonCode)) > 10
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 550453
         SET @c_errmsg = 'NSQL' + CONVERT(NCHAR(6),@n_err) + ': Reason Code is more than 10 characters. ' 
                       + 'Please check codelkup setup.'

         EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = ''
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_PalletIDList
                  ,  @c_Refkey2     = ''
                  ,  @c_Refkey3     = ''
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg    OUTPUT

         GOTO EXIT_SP  
      END

      SET @CUR_ID = CURSOR  FAST_FORWARD READ_ONLY FOR
      SELECT ID = ColValue
      FROM fnc_DelimSplit ('|', @c_PalletIDList) 

      OPEN @CUR_ID
   
      FETCH NEXT FROM @CUR_ID INTO @c_ID
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         BEGIN TRAN
         BEGIN TRY      
            EXEC isp_InspectionCallOut 
                  @c_ID          = @c_ID
               ,  @c_Finalloc    = @c_Finalloc
               ,  @c_Reasoncode  = @c_Reasoncode
               ,  @c_Remarks     = @c_Remarks
               ,  @b_Success     = @b_Success   OUTPUT 
               ,  @n_err         = @n_err       OUTPUT 
               ,  @c_errmsg      = @c_errmsg    OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_err = 550454
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(6),@n_err) + ': Call out ID: ' + @c_ID + ' fail. ' +  @c_ErrMsg 

            ROLLBACK TRAN

            EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = ''
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_ID
                  ,  @c_Refkey2     = ''
                  ,  @c_Refkey3     = ''
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg    OUTPUT

         END CATCH  

         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END  

         FETCH NEXT FROM @CUR_ID INTO @c_ID
      END
      CLOSE @CUR_ID 
      DEALLOCATE @CUR_ID
   END TRY  
  
   BEGIN CATCH 
      SET @n_Continue = 3                          --(Wan01)
      SET @c_Errmsg = ERROR_MESSAGE()              --(Wan01) 
      GOTO EXIT_SP  
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch 
             --       
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ASRSCallOutIDInsp_Wrapper'
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
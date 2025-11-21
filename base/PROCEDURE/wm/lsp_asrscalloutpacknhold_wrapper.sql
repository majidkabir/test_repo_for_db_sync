SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_ASRSCallOutPackNHold_Wrapper                    */  
/* Creation Date: 05-APR-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-505 - ASRS  ID Inspection & Pack and Hold               */
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
CREATE PROCEDURE [WM].[lsp_ASRSCallOutPackNHold_Wrapper]  
   @c_MBOLKeyList    NVARCHAR(MAX)
,  @c_PalletIDList   NVARCHAR(MAX)
,  @b_Success        INT          = 1  OUTPUT   
,  @n_Err            INT          = 0  OUTPUT
,  @c_Errmsg         NVARCHAR(MAX)= '' OUTPUT
,  @c_UserName       NVARCHAR(128)= ''
,  @n_ErrGroupKey    INT = 0           OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @c_MBOLKey         NVARCHAR(10)
         , @c_ID              NVARCHAR(18)
         , @c_SourceType      NVARCHAR(50)  =  'lsp_ASRSCallOutPackNHold_Wrapper'

         , @CUR_ID            CURSOR

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
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      SET @CUR_ID = CURSOR  FAST_FORWARD READ_ONLY FOR
      SELECT   MBOLKey = MB.ColValue 
            ,  ID = PL.ColValue
      FROM dbo.fnc_DelimSplit ('|', @c_MBOLKeyList)  MB
      JOIN dbo.fnc_DelimSplit ('|', @c_PalletIDList) PL ON (MB.SeqNo = PL.SeqNo)

      OPEN @CUR_ID
   
      FETCH NEXT FROM @CUR_ID INTO @c_MBOLKey, @c_ID
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         BEGIN TRAN
         BEGIN TRY      
            EXEC isp_PackNHoldCallOut
                  @c_MBOLKey     = @c_MBOLKey 
               ,  @c_ID          = @c_ID
               ,  @b_Success     = @b_Success   OUTPUT 
               ,  @n_err         = @n_err       OUTPUT 
               ,  @c_errmsg      = @c_errmsg    OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_err = 550551
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(6),@n_err) + ': Call out ID: ' + @c_ID + ' fail. ' +  @c_ErrMsg 
            ROLLBACK TRAN

            EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = ''
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_MBOLKey
                  ,  @c_Refkey2     = @c_ID
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

         FETCH NEXT FROM @CUR_ID INTO @c_MBOLKey, @c_ID
      END
      CLOSE @CUR_ID 
      DEALLOCATE @CUR_ID
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ASRSCallOutPackNHold_Wrapper'
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
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_ScanCartonLabelNo]             */              
/* Creation Date: 13-FEB-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: SCEAPI                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes                                     */
/* 15-Feb-2023    Alex     #JIRA PAC-4 Initial                          */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_API_ScanCartonLabelNo](
     @b_Debug           INT            = 0
   , @c_Format          VARCHAR(10)    = ''
   , @c_UserID          NVARCHAR(256)  = ''
   , @c_OperationType   NVARCHAR(60)   = ''
   , @c_RequestString   NVARCHAR(MAX)  = ''
   , @b_Success         INT            = 0   OUTPUT
   , @n_ErrNo           INT            = 0   OUTPUT
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT
   , @c_ResponseString  NVARCHAR(MAX)  = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT            = 1
         , @n_StartCnt                    INT            = @@TRANCOUNT

         , @n_IsExists                    INT            = 0
         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)  = ''

         , @c_LabelNo                     NVARCHAR(60)   = ''
         , @c_PickSlipNo                  NVARCHAR(10)   = ''
         , @n_CtnNo                       INT            = 0
         , @c_FieldName                   NVARCHAR(30)   = ''

         , @c_UpdateSetFields             NVARCHAR(2000) = ''
         , @c_SQLQuery                    NVARCHAR(2000) = ''
         , @c_SQLParam                    NVARCHAR(200)  = ''

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''


   DECLARE @t_ToFields AS TABLE(
      [FieldName]    NVARCHAR(30)   NULL
   )
   --Change Login User
   SET @n_sp_err = 0     
   EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserID OUTPUT, @n_Err = @n_sp_err OUTPUT, @c_ErrMsg = @c_sp_errmsg OUTPUT    
       
   EXECUTE AS LOGIN = @c_UserID    
       
   IF @n_sp_err <> 0     
   BEGIN      
      SET @n_Continue = 3      
      SET @n_ErrNo = @n_sp_err      
      SET @c_ErrMsg = @c_sp_errmsg     
      GOTO QUIT      
   END  

   SELECT @c_LabelNo       = ISNULL(RTRIM(LabelNo       ), '')
         ,@c_PickSlipNo    = ISNULL(RTRIM(PickSlipNo    ), '')
         ,@n_CtnNo         = ISNULL(CartonNo, 1)
   FROM OPENJSON (@c_RequestString)
   WITH ( 
       LabelNo          NVARCHAR(60)   '$.LabelNo' 
      ,PickSlipNo       NVARCHAR(10)   '$.PickSlipNo'
      ,CartonNo         INT            '$.CartonNo'
   )

   INSERT INTO @t_ToFields
   SELECT ISNULL(RTRIM([value]), '')
   FROM OPENJSON (@c_RequestString, '$.ToFields')

   IF EXISTS ( SELECT 1 FROM @t_ToFields WHERE ISNULL(RTRIM([FieldName]), '') <> '')
   BEGIN
      DECLARE CUR_ECOMP_TOFIELDS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT [FieldName] FROM @t_ToFields 
      WHERE ISNULL(RTRIM([FieldName]), '') <> ''

      OPEN CUR_ECOMP_TOFIELDS
      FETCH NEXT FROM CUR_ECOMP_TOFIELDS INTO @c_FieldName

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_UpdateSetFields = @c_UpdateSetFields
                                + CASE WHEN @c_UpdateSetFields <> '' THEN ',' ELSE '' END
                                + ' ' + @c_FieldName + ' = @c_LabelNo '

         FETCH NEXT FROM CUR_ECOMP_TOFIELDS INTO @c_FieldName
      END
      CLOSE CUR_ECOMP_TOFIELDS
      DEALLOCATE CUR_ECOMP_TOFIELDS
   END
   ELSE 
   BEGIN
      SET @c_UpdateSetFields = ' DropID = @c_LabelNo '
   END

   SET @c_SQLQuery = 'UPDATE [dbo].[PackDetail] WITH (ROWLOCK) ' + CHAR(13) +
                   + '  SET ' + @c_UpdateSetFields
                   + '  WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CtnNo '

   SET @c_SQLParam = '@c_LabelNo NVARCHAR(60), @c_PickSlipNo NVARCHAR(10), @n_CtnNo INT '

   BEGIN TRY
      EXECUTE sp_ExecuteSql @c_SQLQuery, @c_SQLParam, @c_LabelNo, @c_PickSlipNo, @n_CtnNo
   END TRY
   BEGIN CATCH 
      SET @n_Continue = 3      
      SET @n_ErrNo = 51470      
      SET @c_ErrMsg = 'Update PackDetail Failed! SQLMSG: ' + ERROR_MESSAGE()
      GOTO QUIT  
   END CATCH


   SET @c_ResponseString = ISNULL(( 
                              SELECT CAST ( 1 AS BIT ) AS 'Success' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                           ), '')

   QUIT:
   IF @n_Continue= 3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_Success = 0      
      IF @@TRANCOUNT > @n_StartCnt AND @@TRANCOUNT = 1 
      BEGIN               
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END   
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END
END -- Procedure  

GO
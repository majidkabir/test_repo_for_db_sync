SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_Redo]                          */              
/* Creation Date: 08-MAR-2023                                           */
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
/* 08-MAR-2023    Alex     #JIRA PAC-4 Initial                          */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_API_Redo](
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

         , @c_ComputerName                NVARCHAR(30)   = ''

         , @c_PickSlipNo                  NVARCHAR(10)   = ''

         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_SKU                         NVARCHAR(20)   = ''
         , @c_Facility                    NVARCHAR(15)   = ''

         , @c_OrderKey                    NVARCHAR(15)   = ''
         , @c_TaskBatchID                 NVARCHAR(10)   = ''
         , @c_OrderMode                   NVARCHAR(1)    = ''
         , @c_InProgOrderKey              NVARCHAR(10)   = ''
         , @c_MultiPackResponse           NVARCHAR(MAX)  = ''

         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)  = ''

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''

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

   SELECT @c_PickSlipNo    = ISNULL(RTRIM(PickSlipNo), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      PickSlipNo       NVARCHAR(10)   '$.PickSlipNo'
   )

   IF @c_PickSlipNo <> ''
   BEGIN
      SET @b_sp_Success = 0
      SET @n_sp_err     = 0
      SET @c_sp_errmsg  = ''

      SELECT @c_OrderKey = ISNULL(RTRIM(OrderKey), '')
            ,@c_TaskBatchID = ISNULL(RTRIM(TaskBatchNo), '')
      FROM [dbo].[PackHeader] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      EXEC [API].[isp_ECOMP_GetOrderMode]
            @b_Debug                   = 0
          , @c_TaskBatchID             = @c_TaskBatchID  OUTPUT
          , @c_DropID                  = ''
          , @c_OrderKey                = @c_OrderKey
          , @b_Success                 = @b_sp_Success   OUTPUT
          , @n_ErrNo                   = @n_sp_err       OUTPUT
          , @c_ErrMsg                  = @c_sp_errmsg    OUTPUT
          , @c_OrderMode               = @c_OrderMode    OUTPUT

      SET @b_sp_Success = 0
      SET @n_sp_err     = 0
      SET @c_sp_errmsg  = ''

      EXEC [API].[isp_ECOMP_RedoPack]   
            @c_PickSlipNo     = @c_PickSlipNo        
         ,  @b_Success        = @b_sp_Success   OUTPUT   
         ,  @n_err            = @n_sp_err       OUTPUT   
         ,  @c_errmsg         = @c_sp_errmsg    OUTPUT  

      IF @b_sp_Success <> 1
      BEGIN
         SET @n_Continue = 3      
         SET @n_ErrNo = 51900      
         SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                       + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
         GOTO QUIT  
      END
   END

   IF @c_OrderMode = 'M'
   BEGIN
      EXEC [API].[isp_ECOMP_GetMultiPackTaskResponse] 
           @c_PickSlipNo            = ''  
         , @c_TaskBatchID           = @c_TaskBatchID 
         , @c_OrderKey              = ''    
         , @c_DropID                = ''
         , @c_MultiPackResponse     = @c_MultiPackResponse     OUTPUT
         , @c_InProgOrderKey        = @c_InProgOrderKey        OUTPUT

      SET @c_ResponseString = ISNULL((
                              SELECT CAST ( 1 AS BIT ) AS 'Success'
                                    ,(
                                       JSON_QUERY(@c_MultiPackResponse)
                                     ) As 'MultiPackTask'
                              FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                           ), '')
   END
   ELSE 
   BEGIN
      SET @c_ResponseString = ISNULL(( 
                                 SELECT CAST ( 1 AS BIT ) AS 'Success' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                              ), '')
   END
   

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
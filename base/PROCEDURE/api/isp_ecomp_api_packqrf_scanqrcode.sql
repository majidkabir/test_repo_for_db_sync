SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_PackQRF_ScanQRCode]            */              
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
/* Date           Author   Purposes										*/
/* 15-Feb-2023    Alex     #JIRA PAC-4 Initial                          */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_API_PackQRF_ScanQRCode](
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
         
         , @c_TaskBatchID                 NVARCHAR(10)   = ''
         , @c_DropID                      NVARCHAR(20)   = ''
         , @c_OrderKey                    NVARCHAR(10)   = ''
         , @c_ComputerName                NVARCHAR(30)   = ''

         , @c_QRCode                      NVARCHAR(150)  = ''
         , @c_PackQRF_RegEx               NVARCHAR(200)  = ''
         , @c_PickSlipNo                  NVARCHAR(10)   = ''

         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_SKU                         NVARCHAR(20)   = ''
         , @c_Facility                    NVARCHAR(15)   = ''

         , @c_LabelLineNo                 NVARCHAR(5)    = ''
         , @n_CartonNo                    INT            = 0

         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)= ''
         , @c_sp_PackQRF_RegEx            NVARCHAR(200)  = ''

         , @c_OrderMode                   NVARCHAR(1)    = ''
         , @n_QRFGroupKey                 INT            = 0

         , @b_IsOrderMatch                INT            = 0
         , @c_PHOrderKey                  NVARCHAR(10)   = ''
         , @c_TrackingNumber              NVARCHAR(40)   = ''

         , @c_MultiPackResponse           NVARCHAR(MAX)  = ''
         , @b_AutoCloseCarton             INT            = 0

   DECLARE @c_AutoCartonType              NVARCHAR(10)   = ''
         , @c_AutoCartonGroup             NVARCHAR(10)   = ''
         , @f_AutoCartonWeight            INT            = 0

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

   SELECT @c_StorerKey     = ISNULL(RTRIM(StorerKey   ), '')
         ,@c_Facility      = ISNULL(RTRIM(Facility    ), '')
         ,@c_ComputerName  = ISNULL(RTRIM(ComputerName), '')
         ,@c_PickSlipNo    = ISNULL(RTRIM(PickSlipNo), '')
         ,@c_QRCode        = ISNULL(RTRIM(QRCode), '')
         ,@c_PackQRF_RegEx = ISNULL(RTRIM(PackQRF_RegEx), '')
         ,@n_CartonNo      = ISNULL(CartonNo, 1)
         ,@c_SKU           = ISNULL(RTRIM(SKU), '')
         ,@c_TaskBatchID   = ISNULL(RTRIM(TaskBatchID ), '')
         ,@c_DropID        = ISNULL(RTRIM(DropID      ), '')
         ,@c_OrderKey      = ISNULL(RTRIM(OrderKey    ), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
       StorerKey        NVARCHAR(15)   '$.StorerKey' 
      ,Facility         NVARCHAR(15)   '$.Facility'
      ,ComputerName     NVARCHAR(30)   '$.ComputerName'
      ,PickSlipNo       NVARCHAR(10)   '$.PickSlipNo'
      ,QRCode           NVARCHAR(150)  '$.QRCode'
      ,PackQRF_RegEx    NVARCHAR(200)  '$.PackQRF_RegEx'
      ,SKU              NVARCHAR(20)   '$.SKU'
      ,CartonNo         INT            '$.CartonNo'
      ,TaskBatchID      NVARCHAR(10)   '$.TaskBatchID'
      ,DropID           NVARCHAR(20)   '$.DropID'     
      ,OrderKey         NVARCHAR(10)   '$.OrderKey' 
   )

   IF @c_TaskBatchID <> '' OR @c_DropID <> '' OR @c_OrderKey <> ''
   BEGIN
      EXEC [API].[isp_ECOMP_GetOrderMode]
         @b_Debug                   = 1
       , @c_TaskBatchID             = @c_TaskBatchID     OUTPUT
       , @c_DropID                  = @c_DropID
       , @c_OrderKey                = @c_OrderKey
       , @b_Success                 = @b_sp_Success      OUTPUT
       , @n_ErrNo                   = @n_sp_err          OUTPUT
       , @c_ErrMsg                  = @c_sp_errmsg       OUTPUT
       , @c_OrderMode               = @c_OrderMode       OUTPUT
   END

   IF @c_OrderMode = 'M'
   BEGIN
      SELECT @c_LabelLineNo   = ISNULL(MAX(LabelLine), '00001')
            --,@n_CartonNo      = ISNULL(MAX(CartonNo), 0)
      FROM [dbo].[PackDetail] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
      AND SKU = @c_SKU

      SELECT @n_QRFGroupKey = (ISNULL(MAX(QRFGroupKey), 0) + 1)
      FROM [dbo].[PackQRF] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
      AND CartonNo = @n_CartonNo
      AND LabelLine = @c_LabelLineNo

      SET @b_sp_Success    = 0
      SET @n_sp_err        = 0     
      SET @c_sp_errmsg     = ''

      EXEC [API].[isp_ECOMP_Validate_QRCode]  
              @c_PickSlipNo   = @c_PickSlipNo
            , @n_CartonNo     = @n_CartonNo  
            , @c_LabelLine    = @c_LabelLineNo
            , @c_QRCode       = @c_QRCode     
            , @c_RegExp       = @c_sp_PackQRF_RegEx      OUTPUT  
            , @b_Success      = @b_sp_Success            OUTPUT  
            , @n_Err          = @n_sp_err                OUTPUT  
            , @c_ErrMsg       = @c_sp_errmsg             OUTPUT

      IF @b_sp_Success = 0 
      BEGIN
         SET @n_Continue = 3      
         SET @n_ErrNo = 51401      
         SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                       + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
         GOTO QUIT  
      END

      INSERT INTO [dbo].[PackQRF] (PickSlipNo, CartonNo, LabelLine, QRCode, QRFGroupKey)
      VALUES(@c_PickSlipNo, @n_CartonNo, @c_LabelLineNo, @c_QRCode, @n_QRFGroupKey)

      EXEC [API].[isp_ECOMP_PackSKU_M]
        @b_Debug                    = @b_Debug
      , @c_ProcessName              = 'INPUT_QRF'
      , @c_TaskBatchID              = @c_TaskBatchID
      , @c_DropID                   = @c_DropID
      , @c_OrderKey                 = @c_OrderKey
      , @c_OrderMode                = @c_OrderMode
      , @c_PickSlipNo               = @c_PickSlipNo
      , @c_StorerKey                = @c_StorerKey
      , @c_Facility                 = @c_Facility
      , @c_SKU                      = @c_SKU
      , @n_CartonNo                 = @n_CartonNo
      , @b_IsOrderMatch             = @b_IsOrderMatch        OUTPUT
      , @c_PackHeaderOrderKey       = @c_PHOrderKey          OUTPUT
      , @b_Success                  = @b_sp_Success          OUTPUT
      , @n_ErrNo                    = @n_sp_err              OUTPUT
      , @c_ErrMsg                   = @c_sp_errmsg           OUTPUT

      IF @b_sp_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 51402
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sp_err) + '. Failed to insert/update pack detail: ' + @c_sp_errmsg
         GOTO QUIT
      END

      EXEC [API].[isp_ECOMP_GetMultiPackTaskResponse] 
           @c_PickSlipNo            = @c_PickSlipNo  
         , @c_TaskBatchID           = @c_TaskBatchID 
         , @c_OrderKey              = @c_Orderkey    
         , @c_DropID                = @c_DropID
         , @c_MultiPackResponse     = @c_MultiPackResponse OUTPUT

      SET @c_TrackingNumber = ''

      --Get Tracking Number For Next Carton If ANY
      EXEC [API].[isp_ECOMP_GetTrackingNumber]
            @b_Debug                   = @b_Debug
          , @c_PickSlipNo              = @c_PickSlipNo
          , @n_CartonNo                = @n_CartonNo
          , @b_Success                 = @b_sp_Success         OUTPUT
          , @n_ErrNo                   = @n_sp_err             OUTPUT
          , @c_ErrMsg                  = @c_sp_errmsg          OUTPUT
          , @c_TrackingNo              = @c_TrackingNumber     OUTPUT

      IF @b_sp_Success <> 1
      BEGIN
         SET @n_Continue = 3 
         SET @n_ErrNo = 51403
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sp_err) + ' : ' + CONVERT(CHAR(5),@n_ErrNo)
                       + '. Failed to get tracking number - ' + @c_sp_errmsg
         GOTO QUIT
      END

      --Get Default CartonType
      EXEC [API].[isp_ECOMP_GetDefaultCartonType]
            @c_Facility             = @c_Facility
         ,  @c_PickSlipNo           = @c_PickSlipNo
         ,  @n_CartonNo             = @n_CartonNo
         ,  @c_DefaultCartonType    = @c_AutoCartonType     OUTPUT
         ,  @c_DefaultCartonGroup   = @c_AutoCartonGroup    OUTPUT
         ,  @b_AutoCloseCarton      = @b_AutoCloseCarton    OUTPUT
         ,  @c_Storerkey            = @c_StorerKey
         ,  @c_Sku                  = @c_SKU
         
      IF @c_AutoCartonType <> '' AND @c_AutoCartonGroup <> ''
      BEGIN
         SELECT @f_AutoCartonWeight = ISNULL([CartonWeight], 0)
         FROM [dbo].[Cartonization] WITH (NOLOCK) 
         WHERE CartonizationGroup = @c_AutoCartonGroup AND CartonType = @c_AutoCartonType
      END

      SET @c_ResponseString = ISNULL(( 
                                 SELECT CAST ( 1 AS BIT ) AS 'Success' 
                                       ,@c_PickSlipNo             As 'PackQRF_M.PickSlipNo'
                                       ,@c_TrackingNumber         As 'PackQRF_M.TrackingNumber'
                                       ,(
                                          JSON_QUERY((
                                             SELECT @b_AutoCloseCarton   As 'CloseCarton'
                                                   ,@c_AutoCartonType    As 'CartonType'
                                                   ,@f_AutoCartonWeight  As 'CartonWeight'
                                             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER))
                                        ) As 'PackQRF_M.CartonInfo'
                                       ,(
                                          JSON_QUERY(@c_MultiPackResponse)
                                        ) AS 'PackQRF_M.MultiPackTask'
                                 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                              ), '')
   END
   --Single Mode (Begin)
   ELSE
   BEGIN
      SELECT @c_LabelLineNo   = ISNULL(MAX(LabelLine), '00001')
            ,@n_CartonNo      = ISNULL(MAX(CartonNo), 0)
            ,@n_QRFGroupKey   = 1
      FROM [dbo].[PackDetail] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      SET @b_sp_Success    = 0
      SET @n_sp_err        = 0     
      SET @c_sp_errmsg     = ''

      EXEC [API].[isp_ECOMP_Validate_QRCode]  
              @c_PickSlipNo   = @c_PickSlipNo
            , @n_CartonNo     = @n_CartonNo  
            , @c_LabelLine    = @c_LabelLineNo
            , @c_QRCode       = @c_QRCode     
            , @c_RegExp       = @c_sp_PackQRF_RegEx      OUTPUT  
            , @b_Success      = @b_sp_Success            OUTPUT  
            , @n_Err          = @n_sp_err                OUTPUT  
            , @c_ErrMsg       = @c_sp_errmsg             OUTPUT

      IF @b_sp_Success = 0 
      BEGIN
         SET @n_Continue = 3      
         SET @n_ErrNo = 51404      
         SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                       + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
         GOTO QUIT  
      END

      INSERT INTO [dbo].[PackQRF] (PickSlipNo, CartonNo, LabelLine, QRCode)
      VALUES(@c_PickSlipNo, @n_CartonNo, @c_LabelLineNo, @c_QRCode)

      SET @c_ResponseString = ISNULL(( 
                                 SELECT CAST ( 1 AS BIT ) AS 'Success' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                              ), '')
   END   
   --Single Mode (End)

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
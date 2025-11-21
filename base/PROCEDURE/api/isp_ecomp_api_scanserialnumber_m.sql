SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_ScanSerialNumber_M]            */              
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
/* Date           Author   Purposes	                                    */
/* 05-Jul-2023    Alex     #JIRA PAC-7 Initial                          */
/* 09-JUL-2024    Alex01   #JIRA PAC-344 & PAC-350                      */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_API_ScanSerialNumber_M](
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
         
         , @c_SQLQuery                    NVARCHAR(2000) = ''
         , @c_SQLParams                   NVARCHAR(500)  = ''

         , @n_IsExists                    INT            = 0

         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_Facility                    NVARCHAR(15)   = ''

         , @c_TaskBatchID                 NVARCHAR(10)   = ''
         , @c_DropID                      NVARCHAR(20)   = ''
         , @c_OrderKey                    NVARCHAR(10)   = ''
         , @c_ComputerName                NVARCHAR(30)   = ''

         , @c_PickSlipNo                  NVARCHAR(10)   = ''
         , @c_SKU                         NVARCHAR(20)   = ''
         , @c_SerialNumber                NVARCHAR(500)   = ''
         
         , @n_CartonNo                    INT            = 0
                  
         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)= ''

         , @c_OrderMode                   NVARCHAR(1)    = ''
         , @b_IsOrderMatch                INT            = 0

         , @c_PHOrderKey                  NVARCHAR(10)   = ''
         , @n_PackSerialNoKey             BIGINT         = 0

   DECLARE @n_sc_Success                  INT            = 0
         , @n_sc_err                      INT            = 0
         , @c_sc_errmsg                   NVARCHAR(250)  = ''
         , @c_sc_Option1                  NVARCHAR(50)   = ''
         , @c_sc_Option2                  NVARCHAR(50)   = ''
         , @c_sc_Option3                  NVARCHAR(50)   = ''
         , @c_sc_Option4                  NVARCHAR(50)   = ''
         , @c_sc_Option5                  NVARCHAR(50)   = ''

         , @c_MultiPackResponse           NVARCHAR(MAX)  = ''

         , @c_TrackingNumber              NVARCHAR(40)   = ''
   --DECLARE @c_PackTaskOrdersJson          NVARCHAR(MAX)  = ''
   --      , @c_OrderStatusJson             NVARCHAR(MAX)  = ''
   --      , @c_OrderInfoJson               NVARCHAR(MAX)  = ''
         
         --Alex01 Begin
         , @c_QRCode                      NVARCHAR(500)  = ''
         , @c_DecodeSerialNoSP            NVARCHAR(30)   = ''
         --Alex01 End

   DECLARE @c_AutoCartonType              NVARCHAR(10)   = ''
         , @c_AutoCartonGroup             NVARCHAR(10)   = ''
         , @f_AutoCartonWeight            INT            = 0
         , @b_AutoCloseCarton             INT            = 0

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''
   
   DECLARE @t_PackTaskOrder AS TABLE (
         TaskBatchNo          NVARCHAR(10)      NULL
      ,  OrderKey             NVARCHAR(10)      NULL
      ,  DeviceOrderkey       NVARCHAR(20)      NULL
      ,  [Status]             NVARCHAR(10)      NULL
      ,  INProgOrderkey       NVARCHAR(20)      NULL
      ,  Color                NVARCHAR(10)      NULL
   )

   DECLARE @t_OrderInfo AS TABLE (
         Orderkey          NVARCHAR(10)   NULL
      ,  ExternOrderkey    NVARCHAR(50)   NULL
      ,  LoadKey           NVARCHAR(10)   NULL
      ,  ConsigneeKey      NVARCHAR(15)   NULL
      ,  ShipperKey        NVARCHAR(15)   NULL
      ,  SalesMan          NVARCHAR(30)   NULL
      ,  [Route]           NVARCHAR(10)   NULL
      ,  UserDefine03      NVARCHAR(20)   NULL
      ,  UserDefine04      NVARCHAR(40)   NULL
      ,  UserDefine05      NVARCHAR(20)   NULL
      ,  [Status]          NVARCHAR(10)   NULL
      ,  SOStatus          NVARCHAR(10)   NULL
      ,  TrackingNo        NVARCHAR(40)   NULL
   )

   DECLARE @t_PackingRules AS TABLE (
         RuleName          NVARCHAR(60)   NULL
      ,  [Value]           NVARCHAR(120)  NULL
   )

   --Change Login User
   SET @n_sp_err = 0     
   EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserID OUTPUT, @n_Err = @n_sp_err OUTPUT, @c_ErrMsg = @c_sp_errmsg OUTPUT    

   EXECUTE AS LOGIN = @c_UserID    
       
   IF @n_sp_err <> 0     
   BEGIN      
      SET @b_Success = 0      
      SET @n_ErrNo = @n_sp_err      
      SET @c_ErrMsg = @c_sp_errmsg     
      GOTO QUIT      
   END

   SELECT @c_StorerKey     = ISNULL(RTRIM(StorerKey   ), '')
         ,@c_Facility      = ISNULL(RTRIM(Facility    ), '')
         ,@c_TaskBatchID   = ISNULL(RTRIM(TaskBatchID ), '')
         ,@c_DropID        = ISNULL(RTRIM(DropID      ), '')
         ,@c_OrderKey      = ISNULL(RTRIM(OrderKey    ), '')
         ,@c_ComputerName  = ISNULL(RTRIM(ComputerName), '')
         ,@c_SKU           = ISNULL(RTRIM(SKU         ), '')
         ,@c_SerialNumber  = ISNULL(RTRIM(SerialNumber), '')
         ,@n_CartonNo      = ISNULL(CartonNo, 1)
         ,@c_PickSlipNo    = ISNULL(RTRIM(PickSlipNo  ), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
       StorerKey     NVARCHAR(15)   '$.StorerKey' 
      ,Facility      NVARCHAR(15)   '$.Facility'
      ,TaskBatchID   NVARCHAR(10)   '$.TaskBatchID'
      ,DropID        NVARCHAR(20)   '$.DropID'     
      ,OrderKey      NVARCHAR(10)   '$.OrderKey'  
      ,ComputerName  NVARCHAR(30)   '$.ComputerName'  
      ,SKU           NVARCHAR(20)   '$.SKU'
      ,SerialNumber  NVARCHAR(500)  '$.SerialNumber'
      ,CartonNo      INT            '$.CartonNo'
      ,PickSlipNo    NVARCHAR(10)   '$.PickSlipNo'
   )

   IF @b_Debug = 1
   BEGIN
     PRINT ' @c_PickSlipNo: ' + @c_PickSlipNo
     PRINT ' @n_CartonNo: ' + CONVERT(NVARCHAR(10), @n_CartonNo)
     PRINT ' @c_SKU: ' + @c_SKU
     --PRINT @c_SQLQuery
   END

   EXEC [API].[isp_ECOMP_GetOrderMode]
      @b_Debug                   = 1
    , @c_TaskBatchID             = @c_TaskBatchID
    , @c_DropID                  = @c_DropID
    , @c_OrderKey                = @c_OrderKey
    , @b_Success                 = @n_sc_Success      OUTPUT
    , @n_ErrNo                   = @n_sc_err          OUTPUT
    , @c_ErrMsg                  = @c_sc_errmsg       OUTPUT
    , @c_OrderMode               = @c_OrderMode       OUTPUT

   IF @n_sc_Success <> 1 OR @c_OrderMode <> 'M'
   BEGIN   
     SET @n_Continue = 3 
     SET @n_ErrNo = 51550
     SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) 
                   + '. TaskBatchID(' + @c_TaskBatchID + ')/OrderKey(' + @c_OrderKey +  ')/DropID(' + @c_DropID + ') - Invalid Order Mode (' + @c_OrderMode + '). '
     GOTO QUIT
   END

   IF @c_PickSlipNo = '' OR @c_StorerKey = '' OR @c_SKU = '' OR @c_SerialNumber = ''
   BEGIN
      SET @n_Continue = 3      
      SET @n_ErrNo = 51551      
      SET @c_ErrMsg = @c_sp_errmsg   
      GOTO QUIT 
   END

   --Alex01 Begin
   SET @c_DecodeSerialNoSP = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'SerialNoDecode')

   IF ISNULL(RTRIM(@c_DecodeSerialNoSP), '') <> ''
   BEGIN
      IF EXISTS ( SELECT * FROM dbo.sysobjects WHERE name = RTRIM(@c_DecodeSerialNoSP) AND type = 'P' )
      BEGIN
         SET @c_SQLQuery = 'EXEC [API].[' + @c_DecodeSerialNoSP + '] '     + CHAR(13) + 
                         + ' @c_PickSlipNo     = @c_PickSlipNo   '         + CHAR(13) +
                         + ',@c_Storerkey      = @c_Storerkey    '         + CHAR(13) + 
                         + ',@c_Sku            = @c_Sku          '         + CHAR(13) + 
                         + ',@c_SerialNumber   = @c_SerialNumber  OUTPUT ' + CHAR(13) + 
                         + ',@c_QRCode         = @c_QRCode        OUTPUT ' + CHAR(13) + 
                         + ',@b_Success        = @b_sp_Success    OUTPUT ' + CHAR(13) + 
                         + ',@n_Err            = @n_sp_err        OUTPUT ' + CHAR(13) + 
                         + ',@c_ErrMsg         = @c_sp_errmsg     OUTPUT '

         SET @c_SQLParams = ' @c_PickSlipNo     NVARCHAR(10) '             + CHAR(13) +
                          + ',@c_Storerkey      NVARCHAR(15) '             + CHAR(13) +
                          + ',@c_Sku            NVARCHAR(60) '             + CHAR(13) +
                          + ',@c_SerialNumber   NVARCHAR(500)     OUTPUT ' + CHAR(13) +
                          + ',@c_QRCode         NVARCHAR(500)     OUTPUT ' + CHAR(13) +
                          + ',@b_sp_Success     INT               OUTPUT ' + CHAR(13) +
                          + ',@n_sp_err         INT               OUTPUT ' + CHAR(13) +
                          + ',@c_sp_errmsg      NVARCHAR(255)     OUTPUT '

         EXEC sp_ExecuteSQL @c_SQLQuery
                          , @c_SQLParams       
                          , @c_PickSlipNo
                          , @c_Storerkey        
                          , @c_Sku               
                          , @c_SerialNumber  OUTPUT
                          , @c_QRCode        OUTPUT
                          , @b_sp_Success    OUTPUT
                          , @n_sp_err        OUTPUT
                          , @c_sp_errmsg     OUTPUT

         IF @b_sp_Success <> 1
         BEGIN
            SET @n_Continue = 3      
            SET @n_ErrNo = 51553     
            SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                          + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
            GOTO QUIT
         END
      END
   END

   SET @b_sp_Success = 0
   SET @n_sp_err = 0
   SET @c_sp_errmsg = ''
   --Alex01 End

   EXEC [API].[isp_ECOMP_PackValidateSerialNo]
           @c_PickSlipNo         = @c_PickSlipNo
         , @c_Storerkey          = @c_StorerKey
         , @c_Sku                = @c_SKU
         , @c_SerialNo           = @c_SerialNumber
         , @b_Success            = @b_sp_Success      OUTPUT  
         , @n_Err                = @n_sp_err          OUTPUT  
         , @c_ErrMsg             = @c_sp_errmsg       OUTPUT  

   IF @b_sp_Success <> 1
   BEGIN
      SET @n_Continue = 3      
      SET @n_ErrNo = 51552      
      SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                    + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
      GOTO QUIT
   END

   SET @n_sc_Success = 0
   SET @n_sc_err = 0
   SET @c_sc_errmsg = ''

   EXEC [API].[isp_ECOMP_PackSKU_M]
        @b_Debug                    = @b_Debug
      , @c_ProcessName              = 'INPUT_SERIALNUMBER'
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
      , @b_Success                  = @n_sc_Success          OUTPUT
      , @n_ErrNo                    = @n_sc_err              OUTPUT
      , @c_ErrMsg                   = @c_sc_errmsg           OUTPUT

   IF @n_sc_Success <> 1   
   BEGIN   
      SET @n_Continue = 3 
      SET @n_ErrNo = 51553
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Failed to insert/update pack detail: ' + @c_sc_errmsg
      GOTO QUIT
   END

   IF @b_Debug = 1 
   BEGIN
      PRINT ' >>>>>>>>>>>>>>>> After PackSKU_M'
      PRINT ' @c_PHOrderKey      = ' + @c_PHOrderKey 
      PRINT ' @b_IsOrderMatch     = ' + CONVERT(NVARCHAR(1), @b_IsOrderMatch)
   END
   
   SET @n_IsExists = 0

   SELECT @n_IsExists = (1)
         ,@n_PackSerialNoKey = PSN.PackSerialNoKey
   FROM [dbo].[PackSerialNo] PSN WITH (NOLOCK) 
   WHERE PickSlipNo = @c_PickSlipNo 
   AND CartonNo = @n_CartonNo
   AND StorerKey = @c_StorerKey
   AND SKU = @c_SKU
   AND SerialNo = @c_SerialNumber  
   AND EXISTS ( SELECT 1 FROM [dbo].[PackDetail] PD WITH (NOLOCK) 
      WHERE PD.PickSlipNo = PSN.PickSlipNo
      AND PD.CartonNo = PSN.CartonNo
      AND PD.LabelLine = PSN.LabelLine
      AND PD.StorerKey = PSN.StorerKey
      AND PD.SKU = PSN.SKU )

   IF @n_IsExists = 0
   BEGIN
      INSERT INTO [dbo].[PackSerialNo] (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY, Barcode) --Alex01
      SELECT TOP 1 
         PickSlipNo, CartonNo, '', LabelLine, StorerKey, SKU, @c_SerialNumber, 1, @c_QRCode
      FROM [dbo].[PackDetail] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo 
      AND CartonNo = @n_CartonNo
      AND StorerKey = @c_StorerKey
      AND SKU = @c_SKU
   END
   ELSE 
   BEGIN 
      UPDATE [dbo].[PackSerialNo] WITH (ROWLOCK) 
      SET QTY = (QTY + 1)
      WHERE PackSerialNoKey = @n_PackSerialNoKey
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

   ----get order info
   --EXEC [API].[isp_ECOMP_GetOrderInfo_v2] @c_Orderkey = @c_PHOrderKey, @c_OrderInfoJson = @c_OrderInfoJson OUTPUT
   ----get order status
   --EXEC [API].[isp_ECOMP_GetOrderStatus] @c_Orderkey = @c_PHOrderKey, @c_OrderStatusJson = @c_OrderStatusJson OUTPUT

   --INSERT INTO @t_PackTaskOrder( TaskBatchNo, OrderKey, DeviceOrderkey, [Status], INProgOrderkey, Color )
   --EXEC [API].[isp_ECOMP_GetPackTaskOrders_M]  
   --      @c_TaskBatchNo    = @c_TaskBatchID
   --   ,  @c_PickSlipNo     = @c_PickSlipNo
   --   ,  @c_Orderkey       = @c_PHOrderKey   OUTPUT  
   --   ,  @b_packcomfirm    = 0
   --   ,  @c_DropID         = @c_DropID

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
      SET @n_ErrNo = 51554
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_sp_err) + ' : ' + CONVERT(CHAR(5),@n_ErrNo)
                    + '. Failed to get tracking number - ' + @c_sp_errmsg
      GOTO QUIT
   END

   SET @c_ResponseString = ISNULL(( 
                              SELECT
                                     @c_PickSlipNo             As 'PickSlipNo'
                                    ,@c_TrackingNumber         As 'TrackingNumber'
                                    ,(
                                       JSON_QUERY((
                                          SELECT @b_AutoCloseCarton   As 'CloseCarton'
                                                ,@c_AutoCartonType    As 'CartonType'
                                                ,@f_AutoCartonWeight  As 'CartonWeight'
                                          FOR JSON PATH, WITHOUT_ARRAY_WRAPPER))
                                     ) As 'CartonInfo'
                                    ,(
                                       JSON_QUERY(@c_MultiPackResponse)
                                     ) AS 'MultiPackTask'
                              FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
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
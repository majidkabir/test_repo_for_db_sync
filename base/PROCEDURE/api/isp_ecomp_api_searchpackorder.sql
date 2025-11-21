SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_SearchPackOrder]               */              
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
CREATE   PROC [API].[isp_ECOMP_API_SearchPackOrder](
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
         
         , @c_TaskBatchID                 NVARCHAR(10)   = ''
         , @c_DropID                      NVARCHAR(20)   = ''
         , @c_OrderKey                    NVARCHAR(10)   = ''
         , @c_ComputerName                NVARCHAR(30)   = ''
         , @n_IsExists                    INT            = 0

         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_SKU                         NVARCHAR(20)   = ''
         , @c_Facility                    NVARCHAR(15)   = ''

         , @c_PHOrderKey                  NVARCHAR(10)   = ''

         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)= ''

         , @c_PickSlipNo                  NVARCHAR(10)   = ''

         , @c_DefaultCartonType           NVARCHAR(10)   = ''
         , @c_DefaultCartonGroup          NVARCHAR(10)   = ''
         , @b_AutoCloseCarton             INT            = 0
         , @f_CartonWeight                FLOAT          = 0

         , @c_SerialNo                    NVARCHAR(60)   = ''

   DECLARE @c_Route                       NVARCHAR(10)   = '' 
         , @c_OrderRefNo                  NVARCHAR(50)   = '' 
         , @c_LoadKey                     NVARCHAR(10)   = '' 
         , @c_CartonGroup                 NVARCHAR(10)   = '' 
         , @c_ConsigneeKey                NVARCHAR(15)   = '' 

         , @c_TrackingNo                  NVARCHAR(40)   = ''
         , @c_SOStatus                    NVARCHAR(60)   = ''
         , @c_Status                      NVARCHAR(60)   = ''

   DECLARE @n_CartonNo                    INT            = 0

   DECLARE @n_sc_Success                  INT            = 0
         , @n_sc_err                      INT            = 0
         , @c_sc_AutoCalcWeight           NVARCHAR(1)    = ''
         , @c_sc_errmsg                   NVARCHAR(250)  = ''
         , @c_sc_Option1                  NVARCHAR(50)   = ''
         , @c_sc_Option2                  NVARCHAR(50)   = ''
         , @c_sc_Option3                  NVARCHAR(50)   = ''
         , @c_sc_Option4                  NVARCHAR(50)   = ''
         , @c_sc_Option5                  NVARCHAR(50)   = ''

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''
   
   DECLARE @t_PackTaskOrderSts AS TABLE (
         TaskBatchNo          NVARCHAR(10)      NULL
      ,  OrderKey             NVARCHAR(10)      NULL
      ,  TotalOrder           INT               NULL
      ,  PackedOrder          INT               NULL
      ,  PendingOrder         INT               NULL
      ,  CancelledOrder       INT               NULL
      ,  InProgOrderKey       NVARCHAR(10)      NULL
      ,  NonEPackSO           NVARCHAR(150)     NULL
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
      ,  M_Company         NVARCHAR(100)  NULL
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

   --SET @n_Continue = 3 
   --SET @n_ErrNo = 51201
   --SET @c_ErrMsg = 'Test Return Error'
   --GOTO QUIT


   SELECT @c_StorerKey     = ISNULL(RTRIM(StorerKey   ), '')
         ,@c_Facility      = ISNULL(RTRIM(Facility    ), '')
         ,@c_TaskBatchID   = ISNULL(RTRIM(TaskBatchID ), '')
         ,@c_DropID        = ISNULL(RTRIM(DropID      ), '')
         ,@c_OrderKey      = ISNULL(RTRIM(OrderKey    ), '')
         ,@c_ComputerName  = ISNULL(RTRIM(ComputerName), '')
         ,@c_SKU           = ISNULL(RTRIM(SKU), '')
         ,@n_CartonNo      = ISNULL(CartonNo, 1)
         ,@c_PickSlipNo    = ISNULL(RTRIM(PickSlipNo), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
       StorerKey     NVARCHAR(15)   '$.StorerKey' 
      ,Facility      NVARCHAR(15)   '$.Facility'
      ,TaskBatchID   NVARCHAR(10)   '$.TaskBatchID'
      ,DropID        NVARCHAR(20)   '$.DropID'     
      ,OrderKey      NVARCHAR(10)   '$.OrderKey'  
      ,ComputerName  NVARCHAR(30)   '$.ComputerName'  
      ,SKU           NVARCHAR(20)   '$.SKU'
      ,CartonNo      INT            '$.CartonNo'
      ,PickSlipNo    NVARCHAR(10)   '$.PickSlipNo'
   )
   
   SELECT @n_IsExists = (1)
         ,@c_PHOrderKey = ISNULL(RTRIM(OrderKey), '')
   FROM [dbo].[PackHeader] WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   IF @n_IsExists = 1
   BEGIN
      IF @c_PHOrderKey <> ''
      BEGIN
         SET @c_Orderkey = @c_PHOrderKey
         GOTO GET_ORDER_INFO
      END
   END

   IF @c_TaskBatchID <> '' AND @c_OrderKey <> ''
      AND EXISTS ( SELECT 1 FROM [dbo].[PackTaskDetail] WITH (NOLOCK) 
         WHERE TaskBatchNO = @c_TaskBatchID AND OrderKey = @c_OrderKey AND [Status] = '9' )
   BEGIN
      SET @c_Orderkey = ''
   END

   --Search For OrderKey
   INSERT INTO @t_PackTaskOrderSts
   EXEC [API].[isp_ECOMP_GetPackTaskOrders_S]  
      @c_TaskBatchNo    = @c_TaskBatchID  
   ,  @c_PickSlipNo     = @c_PickSlipNo   
   ,  @c_Orderkey       = @c_Orderkey    OUTPUT  
   ,  @b_packcomfirm    = 0  
   ,  @c_DropID         = @c_DropID       
   ,  @c_FindSku        = ''      
   ,  @c_PackByLA01     = ''   
   ,  @c_PackByLA02     = ''   
   ,  @c_PackByLA03     = ''   
   ,  @c_PackByLA04     = ''   
   ,  @c_PackByLA05     = ''
   ,  @c_SourceApp      = 'SCE'


   SELECT @c_OrderKey      = ISNULL(RTRIM(InProgOrderKey), '')
   FROM @t_PackTaskOrderSts
   
   IF @b_Debug = 1
   BEGIN
      SELECT * FROM @t_PackTaskOrderSts
      PRINT '@c_OrderKey = ' + @c_OrderKey
   END 

   IF @c_OrderKey = ''
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 51201
      SET @c_ErrMsg = 'No orderkey found.'
      GOTO QUIT
   END


   SELECT @c_Route         = ISNULL(RTRIM([Route]), '')
         ,@c_OrderRefNo    = ISNULL(RTRIM([ExternOrderKey]), '')
         ,@c_LoadKey       = ISNULL(RTRIM([LoadKey]), '')
         ,@c_ConsigneeKey  = ISNULL(RTRIM([ConsigneeKey]), '')
   FROM [dbo].[ORDERS] WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey

   --update orderkey into packheader
   UPDATE [dbo].[PackHeader] WITH (ROWLOCK)
   SET [Route]        = @c_Route       
      ,[OrderKey]     = @c_OrderKey
      ,[OrderRefNo]   = @c_OrderRefNo
      ,[LoadKey]      = @c_LoadKey
      ,[ConsigneeKey] = @c_ConsigneeKey
   WHERE PickSlipNo = @c_PickSlipNo

   GET_ORDER_INFO:
   --Get Order Information
   INSERT INTO @t_OrderInfo 
   EXEC [API].[isp_ECOMP_GetOrderInfo]
      @c_OrderKey = @c_OrderKey
    , @c_SourceApp = 'SCE'

   --Get Default CartonType
   EXEC [API].[isp_ECOMP_GetDefaultCartonType]
         @c_Facility             = @c_Facility
      ,  @c_PickSlipNo           = @c_PickSlipNo
      ,  @n_CartonNo             = @n_CartonNo
      ,  @c_DefaultCartonType    = @c_DefaultCartonType  OUTPUT
      ,  @c_DefaultCartonGroup   = @c_DefaultCartonGroup OUTPUT
      ,  @b_AutoCloseCarton      = @b_AutoCloseCarton    OUTPUT
      ,  @c_Storerkey            = @c_StorerKey
      ,  @c_Sku                  = @c_SKU
      
   IF @c_DefaultCartonType <> '' AND @c_DefaultCartonGroup <> ''
   BEGIN
      SELECT @f_CartonWeight = ISNULL([CartonWeight], 0)
      FROM [dbo].[Cartonization] WITH (NOLOCK) 
      WHERE CartonizationGroup = @c_DefaultCartonGroup AND CartonType = @c_DefaultCartonType
   END

   SELECT TOP 1 @c_TrackingNo = ISNULL(RTRIM(TrackingNo), '')
               ,@c_SOStatus   = ISNULL(RTRIM([SOStatus]), '')
               ,@c_Status     = ISNULL(RTRIM([Status]),   '')
   FROM @t_OrderInfo

   --Convert SOStatus and Status (BEGIN)

   IF EXISTS ( SELECT 1 FROM dbo.[Codelkup] WITH (NOLOCK) 
      WHERE ListName = 'SOStatus' AND Code = @c_SOStatus AND StorerKey = @c_StorerKey )
   BEGIN
      SELECT @c_SOStatus = ISNULL(RTRIM([Description]), '') 
      FROM [dbo].[Codelkup] WITH (NOLOCK) 
      WHERE ListName = 'SOSTATUS' 
      AND Code = @c_SOStatus 
      AND StorerKey = @c_StorerKey 
   END
   ELSE IF EXISTS ( SELECT 1 FROM dbo.[Codelkup] WITH (NOLOCK) 
      WHERE ListName = 'SOSTATUS' AND Code = @c_SOStatus AND StorerKey = '' )
   BEGIN
      SELECT @c_SOStatus = ISNULL(RTRIM([Description]), '') 
      FROM [dbo].[Codelkup] WITH (NOLOCK) 
      WHERE ListName = 'SOSTATUS' 
      AND Code = @c_SOStatus 
      AND StorerKey = ''
   END
   
   IF EXISTS ( SELECT 1 FROM dbo.[Codelkup] WITH (NOLOCK) 
      WHERE ListName = 'ORDRSTATUS' AND Code = @c_Status AND StorerKey = @c_StorerKey )
   BEGIN
      SELECT @c_Status = ISNULL(RTRIM([Description]), '') 
      FROM [dbo].[Codelkup] WITH (NOLOCK) 
      WHERE ListName = 'ORDRSTATUS' 
      AND Code = @c_Status 
      AND StorerKey = @c_StorerKey 
   END
   ELSE IF EXISTS ( SELECT 1 FROM dbo.[Codelkup] WITH (NOLOCK) 
      WHERE ListName = 'ORDRSTATUS' AND Code = @c_Status AND StorerKey = '' )
   BEGIN
      SELECT @c_Status = ISNULL(RTRIM([Description]), '') 
      FROM [dbo].[Codelkup] WITH (NOLOCK) 
      WHERE ListName = 'ORDRSTATUS' 
      AND Code = @c_Status 
      AND StorerKey = ''
   END
   --Convert SOStatus and Status (END)

   --when qr code display?
   SET @c_ResponseString = ISNULL(( 
                              SELECT @c_DefaultCartonType                  As 'PackTask.CartonType'
                                    ,@f_CartonWeight                       As 'PackTask.CartonWeight'
                                    ,@c_TrackingNo                         As 'PackTask.TrackingNumber'
                                    ,(
                                       JSON_QUERY((SELECT TOP 1
                                           Orderkey                        As 'SO'
                                          ,ExternOrderkey                  As 'ExternSO'
                                          ,@c_SOStatus                     As 'SOStatus'
                                          ,ShipperKey                      As 'ShipperKey'
                                          ,UserDefine03                    As 'Store'
                                          ,SalesMan                        As 'Platform'
                                          ,@c_Status                       As 'Status'
                                          ,0                               As 'PackStatus'
                                          ,M_Company                       As 'M_Company'
                                       FROM @t_OrderInfo
                                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER))
                                     ) As 'PackTask.OrderInfo'
                                    ,(
                                       SELECT PTD.Orderkey As 'OrderKey'
                                             ,PTD.Storerkey As 'StorerKey'
                                             ,PTD.Sku  As 'SKU'
                                             ,PTD.QtyAllocated As 'QtyAllocated' 
                                             ,ISNULL(SUM(PD.Qty),0) As 'QtyPacked'
                                             ,CASE WHEN  PTD.QtyAllocated = ISNULL(SUM(PD.Qty),0) THEN 1 ELSE 0 END As 'Packed'
                                             ,S.Descr As 'Description' 
                                       FROM PACKTASKDETAIL  PTD WITH (NOLOCK)   
                                       LEFT JOIN PACKDETAIL PD  WITH (NOLOCK) ON  (PTD.PickSlipNo = PD.PickSlipNo)   
                                                                              AND (PTD.Storerkey = PD.Storerkey)  
                                                                              AND (PTD.Sku = PD.Sku)  
                                       JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PTD.Storerkey AND S.SKU = PTD.SKU   
                                       WHERE PTD.TaskBatchNo = @c_TaskBatchID  
                                       AND   PTD.Orderkey = @c_Orderkey    
                                       GROUP  BY PTD.Orderkey  
                                             ,PTD.Storerkey  
                                             ,PTD.Sku  
                                             ,PTD.QtyAllocated  
                                             ,S.Descr
                                       FOR JSON PATH 
                                     ) As 'PackTask.OrderStatusList'
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
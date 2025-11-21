SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_Undo]                          */              
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
CREATE   PROC [API].[isp_ECOMP_API_Undo](
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

         , @c_TaskBatchID                 NVARCHAR(10)   = ''
         , @c_DropID                      NVARCHAR(20)   = ''
         , @c_OrderKey                    NVARCHAR(10)   = ''

         , @c_PickSlipNo                  NVARCHAR(10)   = ''

         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_SKU                         NVARCHAR(20)   = ''
         , @c_Facility                    NVARCHAR(15)   = ''
         , @c_SOStatus                    NVARCHAR(60)   = ''
         , @c_Status                      NVARCHAR(60)   = ''

         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)= ''

   DECLARE @c_PH_TaskBatchID              NVARCHAR(10)   = ''
         , @c_PH_OrderKey                 NVARCHAR(10)   = ''
         , @c_OrderMode                   NVARCHAR(1)    = ''
         , @c_PackStatus                  NVARCHAR(1)    = ''

   DECLARE @c_MultiPackResponse           NVARCHAR(MAX)  = ''
         , @c_InProgOrderKey              NVARCHAR(10)   = ''

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

   SELECT @c_PickSlipNo       = ISNULL(RTRIM(PickSlipNo     ), '')
         ,@c_TaskBatchID      = ISNULL(RTRIM(TaskBatchID    ), '')
         ,@c_DropID           = ISNULL(RTRIM(DropID         ), '')
         ,@c_OrderKey         = ISNULL(RTRIM(OrderKey       ), '')
         ,@c_StorerKey        = ISNULL(RTRIM(StorerKey      ), '')
         ,@c_Facility         = ISNULL(RTRIM(Facility       ), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      PickSlipNo        NVARCHAR(10)       '$.PickSlipNo',
      TaskBatchID       NVARCHAR(10)       '$.TaskBatchID',
      DropID            NVARCHAR(20)       '$.DropID',
      OrderKey          NVARCHAR(10)       '$.OrderKey',
      StorerKey         NVARCHAR(15)       '$.StorerKey',
      Facility          NVARCHAR(15)       '$.Facility'
   )

   IF @c_PickSlipNo <> ''
   BEGIN
      SELECT @c_PH_TaskBatchID   = ISNULL(RTRIM(TaskBatchNo), '')
            ,@c_PH_OrderKey      = ISNULL(RTRIM(OrderKey), '')
      FROM [dbo].[PackHeader] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      EXEC [API].[isp_ECOMP_GetOrderMode]
        @b_Debug            = @b_Debug
      , @c_TaskBatchID      = @c_PH_TaskBatchID OUTPUT
      , @c_DropID           = ''
      , @c_OrderKey         = @c_PH_OrderKey
      , @b_Success          = @b_sp_Success     OUTPUT
      , @n_ErrNo            = @n_sp_err         OUTPUT
      , @c_ErrMsg           = @c_sp_errmsg      OUTPUT
      , @c_OrderMode        = @c_OrderMode      OUTPUT

      SET @b_sp_Success = 0
      SET @n_sp_err     = 0
      SET @c_sp_errmsg  = ''

      EXEC [API].[isp_ECOMP_UndoPackConfirm]
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

      --TaskBatchID input is blank, get TaskBatchID from PackTask table for counting orders
      IF @c_TaskBatchID = ''
      BEGIN
         SELECT @c_TaskBatchID = ISNULL(RTRIM(TaskBatchNo), '')
         FROM [dbo].[PackTask] WITH (NOLOCK) 
         WHERE OrderKey = @c_PH_OrderKey
      END

      IF @c_OrderMode = 'S'
      BEGIN
         INSERT INTO @t_PackTaskOrderSts (TaskBatchNo, OrderKey, TotalOrder, PackedOrder, PendingOrder, CancelledOrder, InProgOrderKey, NonEPackSO)
         EXEC [API].[isp_ECOMP_GetPackTaskOrders_S]  
            @c_TaskBatchNo    = @c_TaskBatchID  
         ,  @c_PickSlipNo     = ''   
         ,  @c_Orderkey       = @c_OrderKey     OUTPUT 
         ,  @b_packcomfirm    = 0  
         ,  @c_DropID         = @c_DropID       
         ,  @c_FindSku        = ''   
         ,  @c_PackByLA01     = ''   
         ,  @c_PackByLA02     = ''   
         ,  @c_PackByLA03     = ''   
         ,  @c_PackByLA04     = ''   
         ,  @c_PackByLA05     = ''
         ,  @c_SourceApp      = 'SCE'
         
         --Get Order Information
         INSERT INTO @t_OrderInfo 
         EXEC [API].[isp_ECOMP_GetOrderInfo] 
            @c_OrderKey = @c_OrderKey
          , @c_SourceApp = 'SCE'

         SELECT TOP 1 @c_SOStatus   = ISNULL(RTRIM([SOStatus]), '')
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

         SET @c_ResponseString = ISNULL(( 
                                    SELECT CAST ( 1 AS BIT )   AS 'Success',
                                    (
                                       JSON_QUERY((
                                          SELECT TotalOrder       As 'TotalOrders'
                                                ,PendingOrder     As 'TotalPendingOrders'
                                                ,PackedOrder      As 'TotalPackedOrders'
                                                ,CancelledOrder   As 'TotalCancOrders'
                                                ,InProgOrderKey   As 'LastOrderID'
                                          FROM @t_PackTaskOrderSts
                                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                                       ))
                                    ) As 'PackTaskOrdersCount',
                                    (
                                       JSON_QUERY((SELECT TOP 1
                                           Orderkey               As 'SO'
                                          ,ExternOrderkey         As 'ExternSO'
                                          ,@c_SOStatus            As 'SOStatus'
                                          ,ShipperKey             As 'ShipperKey'
                                          ,UserDefine03           As 'Store'
                                          ,SalesMan               As 'Platform'
                                          ,@c_Status              As 'Status'
                                          ,M_Company              As 'M_Company'
                                       FROM @t_OrderInfo
                                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER))
                                    ) As 'PackTask.OrderInfo'
                                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                                 ), '')
      END
      ELSE IF @c_OrderMode = 'M'
      BEGIN
         EXEC [API].[isp_ECOMP_GetMultiPackTaskResponse] 
           @c_PickSlipNo            = @c_PickSlipNo
         , @c_TaskBatchID           = @c_TaskBatchID 
         , @c_OrderKey              = @c_OrderKey
         , @c_DropID                = @c_DropID
         , @c_MultiPackResponse     = @c_MultiPackResponse     OUTPUT
         , @c_InProgOrderKey        = @c_InProgOrderKey        OUTPUT

         SET @c_ResponseString = ISNULL(( 
                                    SELECT CAST ( 1 AS BIT )         AS 'Success'
                                          --,@c_NewPickSlipNo          AS 'PickSlipNo'
                                          --,@c_InProgOrderKey         AS 'LastOrderID'
                                          ,(
                                             JSON_QUERY(@c_MultiPackResponse)
                                           ) As 'MultiPackTask'
                                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                                 ), '')
      END
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
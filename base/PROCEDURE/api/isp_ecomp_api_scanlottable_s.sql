SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_ScanLottable_S]                */              
/* Creation Date: 04-Oct-2023                                           */
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
/* 04-Oct-2023    Alex     #JIRA PAC-142 Initial                        */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_API_ScanLottable_S](
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
         
         , @c_SQLQuery                    NVARCHAR(MAX)  = ''
         , @c_SQLParams                   NVARCHAR(2000) = ''

         , @n_IsExists                    INT            = 0

         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_Facility                    NVARCHAR(15)   = ''

         , @c_TaskBatchID                 NVARCHAR(10)   = ''
         , @c_DropID                      NVARCHAR(20)   = ''
         , @c_OrderKey                    NVARCHAR(10)   = ''
         , @c_ComputerName                NVARCHAR(30)   = ''

         , @c_PickSlipNo                  NVARCHAR(10)   = ''
         , @c_SKU                         NVARCHAR(20)   = ''
         , @c_SerialNumber                NVARCHAR(30)   = ''
         
         , @n_CartonNo                    INT            = 0
                  
         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)  = ''

         , @c_OrderMode                   NVARCHAR(1)    = ''
         , @b_IsOrderMatch                INT            = 0

         , @c_PHOrderKey                  NVARCHAR(10)   = ''
         , @n_PackSerialNoKey             BIGINT         = 0

         , @c_MultiPackResponse           NVARCHAR(MAX)  = ''
         , @c_TrackingNumber              NVARCHAR(40)   = ''

   DECLARE @c_LottableValue               NVARCHAR(60)   = ''
         , @b_RespSuccess                 INT            = 0

   DECLARE @n_sc_Success                  INT            = 0
         , @n_sc_err                      INT            = 0
         , @c_sc_errmsg                   NVARCHAR(250)  = ''
         , @c_sc_Option1                  NVARCHAR(50)   = ''
         , @c_sc_Option2                  NVARCHAR(50)   = ''
         , @c_sc_Option3                  NVARCHAR(50)   = ''
         , @c_sc_Option4                  NVARCHAR(50)   = ''
         , @c_sc_Option5                  NVARCHAR(50)   = ''

   DECLARE @c_PackTaskOrdersJson          NVARCHAR(MAX)  = ''
         , @c_OrderStatusJson             NVARCHAR(MAX)  = ''
         , @c_OrderInfoJson               NVARCHAR(MAX)  = ''

    DECLARE @c_Route                       NVARCHAR(10)   = '' 
         , @c_OrderRefNo                  NVARCHAR(50)   = '' 
         , @c_LoadKey                     NVARCHAR(10)   = '' 
         , @c_CartonGroup                 NVARCHAR(10)   = '' 
         , @c_ConsigneeKey                NVARCHAR(15)   = '' 

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

   SELECT @c_TaskBatchID   = ISNULL(RTRIM(TaskBatchID  ), '')
         ,@c_DropID        = ISNULL(RTRIM(DropID       ), '')
         ,@c_OrderKey      = ISNULL(RTRIM(OrderKey     ), '')
         ,@c_ComputerName  = ISNULL(RTRIM(ComputerName ), '')
         ,@c_SKU           = ISNULL(RTRIM(SKU          ), '')
         ,@c_LottableValue = ISNULL(RTRIM(LottableValue), '')
         ,@c_PickSlipNo    = ISNULL(RTRIM(PickSlipNo   ), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
       TaskBatchID   NVARCHAR(10)   '$.TaskBatchID'
      ,DropID        NVARCHAR(20)   '$.DropID'     
      ,OrderKey      NVARCHAR(10)   '$.OrderKey'  
      ,ComputerName  NVARCHAR(30)   '$.ComputerName'  
      ,SKU           NVARCHAR(20)   '$.SKU'
      ,LottableValue NVARCHAR(60)   '$.LottableValue'
      ,PickSlipNo    NVARCHAR(10)   '$.PickSlipNo'
   )

   IF @b_Debug = 1
   BEGIN
     PRINT ' @c_PickSlipNo: ' + @c_PickSlipNo
     PRINT ' @c_SKU: ' + @c_SKU
   END

   EXEC [API].[isp_ECOMP_GetOrderMode]
      @b_Debug                   = 1
    , @c_TaskBatchID             = @c_TaskBatchID     OUTPUT
    , @c_DropID                  = @c_DropID
    , @c_OrderKey                = @c_OrderKey
    , @b_Success                 = @n_sc_Success      OUTPUT
    , @n_ErrNo                   = @n_sc_err          OUTPUT
    , @c_ErrMsg                  = @c_sc_errmsg       OUTPUT
    , @c_OrderMode               = @c_OrderMode       OUTPUT

   IF @n_sc_Success <> 1 OR @c_OrderMode <> 'S'
   BEGIN   
     SET @n_Continue = 3 
     SET @n_ErrNo = 51910
     SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) 
                   + '. TaskBatchID(' + @c_TaskBatchID + ')/OrderKey(' + @c_OrderKey +  ')/DropID(' + @c_DropID + ') - Invalid Order Mode (' + @c_OrderMode + '). '
     GOTO QUIT
   END

   SELECT @c_StorerKey = ISNULL(RTRIM(StorerKey), '')
   FROM [dbo].[PackHeader] WITH (NOLOCK) 
   WHERE PickSlipNo = @c_PickSlipNo

   IF @c_PickSlipNo = '' OR @c_StorerKey = '' OR @c_SKU = ''
   BEGIN
      SET @n_Continue = 3      
      SET @n_ErrNo = 51911      
      SET @c_ErrMsg = 'PickSlipNo/StorerKey/SKU cannot be blank.'   
      GOTO QUIT
   END

   EXEC [dbo].[isp_PackLAValidate_Wrapper]
           @c_PickSlipNo         = @c_PickSlipNo
         , @c_Storerkey          = @c_StorerKey
         , @c_Sku                = @c_SKU
         , @c_TaskBatchNo        = @c_TaskBatchID
         , @c_DropID             = @c_DropID
         , @c_PackByLA01         = @c_LottableValue
         , @c_PackByLA02         = ''
         , @c_PackByLA03         = ''
         , @c_PackByLA04         = ''
         , @c_PackByLA05         = ''
         , @c_SourceCol          = 'packbyla01'
         , @c_Orderkey           = @c_Orderkey        OUTPUT
         , @b_Success            = @b_sp_Success      OUTPUT  
         , @n_Err                = @n_sp_err          OUTPUT  
         , @c_ErrMsg             = @c_sp_errmsg       OUTPUT  

   IF @b_sp_Success <> 1
   BEGIN
      SET @n_Continue = 3      
      SET @n_ErrNo = 51912      
      SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                    + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
      GOTO QUIT
   END

   INSERT INTO [dbo].[PackDetail] (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, Qty, DropId, LOTTABLEVALUE)
   VALUES(@c_PickSlipNo, @n_CartonNo, '', '00001', @c_StorerKey, @c_SKU, 1, '', @c_LottableValue)
   
   IF @c_Orderkey <> ''
   BEGIN
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
   END

   SET @b_RespSuccess = 1

   SET @c_ResponseString = ISNULL(( 
                              SELECT CAST ( @b_RespSuccess AS BIT )   AS 'Success'
                                    ,( 
                                       SELECT PD.SKU                 As 'SKU'
                                             ,PD.QTY                 As 'QTY'
                                             ,PD.LOTTABLEVALUE       As 'LottableValue'
                                             ,S.STDGROSSWGT          As 'STDGrossWeight'
                                       FROM [dbo].[PackDetail] PD WITH (NOLOCK)
                                       JOIN [dbo].[SKU] S WITH (NOLOCK) 
                                       ON (PD.PickSlipNo = @c_PickSlipNo 
                                          AND S.StorerKey = PD.StorerKey
                                          AND S.SKU = PD.SKU )
                                       WHERE PickSlipNo = @c_PickSlipNo
                                       FOR JSON PATH 
                                     ) AS 'PackTask.CartonPackedSKU'
                              FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                           ), '')

   --SET @c_ResponseString = ISNULL(( 
   --                           SELECT
   --                                  @c_PickSlipNo             As 'PickSlipNo'
   --                                 ,@c_TrackingNumber         As 'TrackingNumber'
   --                                 ,(
   --                                    JSON_QUERY((
   --                                       SELECT @b_AutoCloseCarton   As 'CloseCarton'
   --                                             ,@c_AutoCartonType    As 'CartonType'
   --                                             ,@f_AutoCartonWeight  As 'CartonWeight'
   --                                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER))
   --                                  ) As 'CartonInfo'
   --                                 ,(
   --                                    JSON_QUERY(@c_MultiPackResponse)
   --                                  ) AS 'MultiPackTask'
   --                           FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
   --                        ), '')

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
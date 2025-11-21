SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_ScanSKU]                       */              
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
/* 16-Jan-2024    Alex01   #JIRA PAC-316 @c_SerialNoInQR change         */
/*                         variable to 60                               */
/* 29-Jan-2024    Alex02   #PAC-322 - Scan QRCode in Serial# insert     */
/*                         PackSerialNo                                 */
/* 25-Feb-2025    CSC166   #FCR-3165 - Save UserID Into                 */
/*                         PackHeader.AddWho                            */
/************************************************************************/    
CREATE PROC [API].[isp_ECOMP_API_ScanSKU](
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

         , @c_ScanField                   NVARCHAR(30)   = ''
         , @c_TaskBatchID                 NVARCHAR(10)   = ''
         , @c_DropID                      NVARCHAR(20)   = ''
         , @c_OrderKey                    NVARCHAR(10)   = ''
         , @c_ComputerName                NVARCHAR(30)   = ''
         , @n_IsExists                    INT            = 0

         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_ScanSKULabel                NVARCHAR(200)  = ''
         , @c_SKU                         NVARCHAR(200)  = ''
         , @c_NewSKU                      NVARCHAR(20)   = ''
         , @c_Facility                    NVARCHAR(15)   = ''
                  
         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)= ''

         , @c_PackStationName             NVARCHAR(30)   = ''
         , @c_PackUserID                  NVARCHAR(256)  = ''

         , @c_PickSlipNo                  NVARCHAR(10)   = ''
         , @n_PackingQty                  INT            = 0 
         , @b_ValidQtyPacked              INT            = 0
         , @f_SKUGrossWeight              FLOAT          = 0

         , @c_IsSerialNoMandatory         NVARCHAR(1)    = 0
         , @c_IsLottableMandatory         NVARCHAR(1)    = 0

         , @c_PackQRF_RegEx               NVARCHAR(200)  = ''

         , @c_SerialNo                    NVARCHAR(60)   = ''
         , @c_SerialNoInQR                NVARCHAR(60)   = ''

   DECLARE @c_Route                       NVARCHAR(10)   = '' 
         , @c_OrderRefNo                  NVARCHAR(50)   = '' 
         , @c_LoadKey                     NVARCHAR(10)   = '' 
         , @c_CartonGroup                 NVARCHAR(10)   = '' 
         , @c_ConsigneeKey                NVARCHAR(15)   = '' 


   DECLARE @n_CartonNo                    INT            = 0
         , @n_SKUCnt                      INT            = 0 
         , @c_AutoCartonType              NVARCHAR(10)   = ''
         , @c_AutoCartonGroup             NVARCHAR(10)   = ''
         , @b_AutoCloseCarton             INT            = 0
         , @f_AutoCartonWeight            FLOAT          = 0

   DECLARE @n_sc_Success                  INT            = 0
         , @n_sc_err                      INT            = 0
         , @c_sc_errmsg                   NVARCHAR(250)  = ''
         , @c_sc_Option1                  NVARCHAR(50)   = ''
         , @c_sc_Option2                  NVARCHAR(50)   = ''
         , @c_sc_Option3                  NVARCHAR(50)   = ''
         , @c_sc_Option4                  NVARCHAR(50)   = ''
         , @c_sc_Option5                  NVARCHAR(50)   = ''
         , @c_sc_SKUDECODE                NVARCHAR(30)   = ''
         , @c_sc_GetSNFromScanLabel       NVARCHAR(30)   = ''

         , @c_OrderMode                   NVARCHAR(1)    = ''
         , @b_ScanQRInSKULabel            BIT            = 0         --Alex02

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
   )

   DECLARE @t_PackingRules AS TABLE (
         RuleName          NVARCHAR(60)   NULL
      ,  [Value]           NVARCHAR(120)  NULL
   )

   DECLARE @DBUserName NVARCHAR(100)	--#FCR-3165
   SET @DBUserName = @c_UserID			--#FCR-3165

   --Change Login User
   SET @n_sp_err = 0     
   EXEC [WM].[lsp_SetUser] @c_UserName = @DBUserName OUTPUT, @n_Err = @n_sp_err OUTPUT, @c_ErrMsg = @c_sp_errmsg OUTPUT    

   --#FCR-3165
   IF @DBUserName LIKE '%' + @c_UserID + '%'
   BEGIN
    EXECUTE AS LOGIN = @DBUserName    --@c_UserID 
    SET @c_UserID = @DBUserName
   END
   
       
   IF @n_sp_err <> 0     
   BEGIN      
      SET @b_Success = 0      
      SET @n_ErrNo = @n_sp_err      
      SET @c_ErrMsg = @c_sp_errmsg     
      GOTO QUIT      
   END  

   SELECT @c_StorerKey     = ISNULL(RTRIM(StorerKey   ), '')
         ,@c_Facility      = ISNULL(RTRIM(Facility    ), '')
         ,@c_ScanField     = ISNULL(RTRIM(ScanField   ), '')
         ,@c_TaskBatchID   = ISNULL(RTRIM(TaskBatchID ), '')
         ,@c_DropID        = ISNULL(RTRIM(DropID      ), '')
         ,@c_OrderKey      = ISNULL(RTRIM(OrderKey    ), '')
         ,@c_ComputerName  = ISNULL(RTRIM(ComputerName), '')
         ,@c_ScanSKULabel  = ISNULL(RTRIM(SKU), '')
         ,@n_CartonNo      = ISNULL(CartonNo, 1)
         ,@c_PickSlipNo    = ISNULL(RTRIM(PickSlipNo  ), '')
         --,@n_Qty           = ISNULL(QTY, 1)
   FROM OPENJSON (@c_RequestString)
   WITH ( 
       StorerKey     NVARCHAR(15)   '$.StorerKey' 
      ,Facility      NVARCHAR(15)   '$.Facility'
      ,ScanField     NVARCHAR(30)   '$.ScanField'
      ,TaskBatchID   NVARCHAR(10)   '$.TaskBatchID'
      ,DropID        NVARCHAR(20)   '$.DropID'     
      ,OrderKey      NVARCHAR(10)   '$.OrderKey'  
      ,ComputerName  NVARCHAR(30)   '$.ComputerName'  
      ,SKU           NVARCHAR(200)  '$.SKU'
      ,CartonNo      INT            '$.CartonNo'
      ,PickSlipNo    NVARCHAR(10)   '$.PickSlipNo'
      --,QTY           INT            '$.QTY'
   )

   SET @n_CartonNo = IIF(@n_CartonNo = 0, 1, @n_CartonNo)

   IF @b_Debug = 1
   BEGIN
     PRINT ' @c_TaskBatchID: ' + @c_TaskBatchID
     PRINT ' @c_PickSlipNo: ' + @c_PickSlipNo
     PRINT ' @n_CartonNo: ' + CONVERT(NVARCHAR(10), @n_CartonNo)
     PRINT ' @c_ScanSKULabel: ' + @c_ScanSKULabel
     PRINT @c_SQLQuery
   END

   --Validate SKU
   BEGIN TRY
      SET @c_SKU           = @c_ScanSKULabel
      SET @b_sp_Success    = 1
      SET @n_sp_err        = 0
      SET @c_sp_errmsg     = ''

      EXEC [dbo].[isp_Ecom_GetPackSku]
         @c_OrderKey    = @c_OrderKey   
      ,  @c_StorerKey   = @c_StorerKey  
      ,  @c_Sku         = @c_SKU             OUTPUT
      ,  @b_Success     = @b_sp_Success      OUTPUT
      ,  @n_err         = @n_sp_err          OUTPUT
      ,  @c_errmsg      = @c_sp_errmsg       OUTPUT
      ,  @c_SerialNo    = @c_SerialNo        OUTPUT
      ,  @c_TaskBatchNo = @c_TaskBatchID 

      IF @b_sp_Success <> 1
      BEGIN
         SET @n_Continue = 3 
         SET @n_ErrNo = 51103
         SET @c_ErrMsg = @c_sp_errmsg
         GOTO QUIT
      END

      IF @b_Debug = 1
      BEGIN
        PRINT ' @c_SKU: ' + @c_SKU
        PRINT ' @c_SerialNo: ' + @c_SerialNo
        PRINT @c_SQLQuery
      END

      IF @c_ScanSKULabel <> @c_SKU AND ISNULL(RTRIM(@c_SerialNo), '') <> ''
      BEGIN
         SET @b_ScanQRInSKULabel = 1
      END
      --IF ISNULL(RTRIM(@c_sc_GetSNFromScanLabel), '') <> '' AND @c_sc_GetSNFromScanLabel <> '0'
      --BEGIN
      --   SET @c_SerialNo = @c_SerialNoInQR
      --END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3 
      SET @n_ErrNo = 51104
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO QUIT
   END CATCH

   IF @c_PickSlipNo = '' 
   BEGIN
      SET @n_PackingQty = 1
   END
   ELSE
   BEGIN 
      SELECT @n_PackingQty = ISNULL(MAX(Qty),0) + 1
      FROM dbo.PackDetail (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
      AND SKU = @c_SKU

      --Get OrderKey From PackHeader if Order has matched. (Single)
      SELECT @c_OrderKey = ISNULL(RTRIM(OrderKey), '')
      FROM dbo.PackHeader (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
   END

   IF @b_Debug = 1
   BEGIN
     PRINT ' @c_PickSlipNo: ' + @c_PickSlipNo
     PRINT ' @c_StorerKey: ' + @c_StorerKey
     PRINT ' @n_PackingQty: ' + CONVERT(NVARCHAR(5), @n_PackingQty)
     PRINT @c_SQLQuery
   END

   SET @b_ValidQtyPacked = 0
   EXEC [dbo].[isp_Ecom_GetValidQtyPacked]
         @c_PickSlipNo      = @c_PickSlipNo  
      ,  @c_TaskBatchNo     = @c_TaskBatchID 
      ,  @c_Storerkey       = @c_StorerKey   
      ,  @c_Sku             = @c_SKU         
      ,  @n_Qty             = @n_PackingQty         
      ,  @c_UserID          = @c_UserID      
      ,  @c_ComputerName    = @c_ComputerName
      ,  @b_ValidQtyPacked  = @b_ValidQtyPacked OUTPUT

   IF @b_ValidQtyPacked <> 1
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 51105
      SET @c_ErrMsg = 'Qty Packed > Qty Picked' 
      GOTO QUIT
   END

   --Get sku.stdgrosswgt 
   SELECT @f_SKUGrossWeight = STDGROSSWGT
   FROM [dbo].[SKU] WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey 
   AND SKU = @c_SKU

   IF @c_PickSlipNo = ''
   BEGIN
      SET @b_sp_Success = 1
      SET @n_sp_err = 0
      SET @c_sp_errmsg = ''

      EXECUTE [dbo].[nspg_getkey]                 
            @KeyName       = 'PickSlip'               
         ,  @fieldlength   = 9                  
         ,  @KeyString     = @c_PickSlipNo      OUTPUT               
         ,  @b_success     = @b_sp_Success      OUTPUT               
         ,  @n_err         = @n_sp_err          OUTPUT               
         ,  @c_errmsg      = @c_sp_errmsg       OUTPUT             
         ,  @n_Batch       = 0

      IF @b_sp_Success <> 1
      BEGIN
         SET @n_Continue = 3 
         SET @n_ErrNo = 51106
         SET @c_ErrMsg = @c_sp_errmsg
         GOTO QUIT
      END

      SET @c_PickSlipNo = 'T' + @c_PickSlipNo

      SELECT @c_CartonGroup   = ISNULL(RTRIM([CartonGroup]), '')
      FROM [dbo].[STORER] WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey

      --Insert Pack Header & Detail
      INSERT INTO [dbo].[PackHeader] (PickSlipNo, StorerKey, [Route], OrderKey, OrderRefNo, LoadKey, ConsigneeKey, [Status], CartonGroup, TaskBatchNo, ComputerName, PackStatus, EstimateTotalCtn, AddWho)
      VALUES(@c_PickSlipNo, @c_StorerKey, @c_Route, '', @c_OrderRefNo, @c_LoadKey, @c_ConsigneeKey, '0', @c_CartonGroup, @c_TaskBatchID, @c_ComputerName, '0', 0, @c_UserID)
   END
   
   INSERT INTO @t_PackingRules
   EXEC [API].[isp_ECOMP_GetPackingRules]
        @c_StorerKey                = @c_StorerKey
      , @c_Facility                 = @c_Facility
      , @c_SKU                      = @c_SKU
      , @c_PickSlipNo               = @c_PickSlipNo
      , @c_TaskBatchID              = @c_TaskBatchID
      , @b_Success                  = @n_sc_Success               OUTPUT
      , @n_ErrNo                    = @n_sc_err                   OUTPUT
      , @c_ErrMsg                   = @c_sc_errmsg                OUTPUT

   IF @n_sc_Success <> 1   
   BEGIN   
      SET @n_Continue = 3 
      SET @n_ErrNo = 51107
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. ' + ISNULL(RTRIM(@c_sc_errmsg), '')
      GOTO QUIT
   END

   SELECT @c_IsSerialNoMandatory = [Value]
   FROM @t_PackingRules
   WHERE RuleName = 'IsSerialNoMandatory'

   SELECT @c_IsLottableMandatory = [Value]
   FROM @t_PackingRules
   WHERE RuleName = 'IsLottableMandatory'
   
   IF @b_Debug = 1
   BEGIN
      PRINT '@c_IsSerialNoMandatory = ' + @c_IsSerialNoMandatory
      PRINT '@c_IsLottableMandatory = ' + @c_IsLottableMandatory
      PRINT '@b_ScanQRInSKULabel = ' + CONVERT(NVARCHAR(2), @b_ScanQRInSKULabel)
   END

   --Insert/Update PackDetail ONLY after Scan serial number/lottable.
   IF NOT (@c_IsSerialNoMandatory = '1' OR @c_IsLottableMandatory = '1') OR @b_ScanQRInSKULabel = 1
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM [dbo].[PackDetail] WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND StorerKey = @c_StorerKey AND SKU = @c_SKU AND CartonNo = @n_CartonNo)
      BEGIN
         INSERT INTO [dbo].[PackDetail] (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, Qty, DropId)
         VALUES(@c_PickSlipNo, @n_CartonNo, '', '00001', @c_StorerKey, @c_SKU, 1, '')
      END
      ELSE
      BEGIN
         UPDATE [dbo].[PackDetail] WITH (ROWLOCK)
         SET Qty = (Qty + 1)
         WHERE PickSlipNo = @c_PickSlipNo
         AND StorerKey = @c_StorerKey
         AND SKU = @c_SKU
      END

      IF @b_ScanQRInSKULabel = 1
      BEGIN
         INSERT INTO [dbo].[PackSerialNo] (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY)
         VALUES (@c_PickSlipNo, @n_CartonNo, '', '00001', @c_StorerKey, @c_SKU, @c_SerialNo, 1)
      END
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

   IF @b_Debug = 1
   BEGIN
      SELECT * FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo
      SELECT * FROM dbo.PackSerialNo WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo
   END
 
   --when qr code display?
   SET @c_ResponseString = ISNULL(( 
                              SELECT TOP 1
                                     @c_PickSlipNo             As 'PackTask.PickSlipNo'
                                    ,'0'                       As 'PackTask.PackStatus'
                                    ,@c_SKU                    As 'PackTask.SKU'
                                    ,@c_SerialNo               As 'PackTask.SerialNumber'
                                    ,@b_ScanQRInSKULabel       As 'PackTask.ScanQRInSKULabel'
                                    ,@n_PackingQty             As 'PackTask.PackingQTY'
                                    ,@f_SKUGrossWeight         As 'PackTask.SKUGrossWeight'
                                    ,@c_AutoCartonType         As 'PackTask.CartonType'
                                    ,@f_AutoCartonWeight       As 'PackTask.CartonWeight'
                                    ,(
                                       SELECT ISNULL(RTRIM(RuleName), '')  As 'RuleName'
                                             ,ISNULL(RTRIM([Value]), '')   As 'Value'
                                       FROM @t_PackingRules
                                       FOR JSON PATH
                                     ) AS 'PackTask.PackingRules'
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
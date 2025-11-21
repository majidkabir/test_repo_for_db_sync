SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_GetPackTask_S]                     */              
/* Creation Date: 3-Jul-2023                                            */
/* Copyright: Maersk                                                    */
/* Written by: Allen                                                    */
/* Copy from: [API].[isp_ECOMP_API_GetPackTask] Version 1.0             */
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
/* 15-Feb-2023    Alex     #JIRA PAC-4 Initial                          */
/* 15-Nov-2023    Alex02   #JIRA PAC-140 Gift Wrapping                  */
/* 10-Oct-2024    Alex03   #JIRA PAC-355 CCTV Integration               */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_GetPackTask_S](
     @b_Debug            INT            = 0
   , @c_UserID           NVARCHAR(256)  = ''
   , @c_PackIsExists     INT            = ''
   , @c_PackStatus       NVARCHAR(1)    = ''
   , @c_PackOrderKey     NVARCHAR(10)   = ''
   , @c_PackAddWho       NVARCHAR(128)  = ''
   , @c_StorerKey        NVARCHAR(15)   = ''
   , @c_Facility         NVARCHAR(15)   = ''
   , @c_PickSlipNo       NVARCHAR(10)   = ''
   , @c_DropID           NVARCHAR(20)   = ''
   , @c_OrderKey         NVARCHAR(10)   = '' 
   , @c_1stOrderKey      NVARCHAR(10)   = ''
   , @c_TaskBatchID      NVARCHAR(10)   = ''
   , @c_PackComputerName NVARCHAR(30)   = ''
   , @c_ComputerName     NVARCHAR(30)   = ''
   , @c_OrderMode        NVARCHAR(1)    = '' 
   , @b_Success          INT            = 0   OUTPUT
   , @n_ErrNo            INT            = 0   OUTPUT
   , @c_ErrMsg           NVARCHAR(250)  = ''  OUTPUT
   , @c_ResponseString   NVARCHAR(MAX)  = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT            = 1
         , @n_StartCnt                    INT            = @@TRANCOUNT
         
         , @c_SKU                         NVARCHAR(20)   = ''

         , @n_TotalCarton                 INT            = 1
         , @n_CartonNo                    INT            = 1
         
         , @c_PackNotes                   NVARCHAR(4000) = ''
         
         , @c_sc_EPackTakeOver            NVARCHAR(5)    = ''
         , @c_sc_MultiPackMode            NVARCHAR(5)    = ''
         , @c_sc_CtnTypeInput             NVARCHAR(5)    = ''

         , @n_sc_Success                  INT
         , @n_sc_err                      INT
         , @c_sc_errmsg                   NVARCHAR(250)= ''
         , @c_sc_Option1                  NVARCHAR(50) = ''
         , @c_sc_Option2                  NVARCHAR(50) = ''
         , @c_sc_Option3                  NVARCHAR(50) = ''
         , @c_sc_Option4                  NVARCHAR(50) = ''
         , @c_sc_Option5                  NVARCHAR(50) = ''

         , @c_sc_ToOption1                NVARCHAR(50) = ''
         , @c_sc_ToOption2                NVARCHAR(50) = ''
         , @c_sc_ToOption3                NVARCHAR(50) = ''
         , @c_sc_ToOption4                NVARCHAR(50) = ''
         , @c_sc_ToOption5                NVARCHAR(50) = ''

   DECLARE @c_InnerJson                   NVARCHAR(MAX)  = NULL
         , @c_OrderStatusJson             NVARCHAR(MAX)  = NULL
         , @c_EPACKConfigJSON             NVARCHAR(4000) = ''        --Alex03
         , @c_DefaultCartonType           NVARCHAR(10)   = ''
         , @c_DefaultCartonGroup          NVARCHAR(10)   = ''
         , @b_AutoCloseCarton             INT            = 0
         , @f_CartonWeight                FLOAT          = 0

         , @b_IsLabelNoCaptured           INT            = 0
         , @c_PackQRF_QRCode              NVARCHAR(100)  = ''
         , @c_TaskBatchID_ToDisplay       NVARCHAR(10)   = ''
         , @c_OrderKey_ToDisplay          NVARCHAR(10)   = ''
         , @n_EstTotalCtn                 INT            = 0 

   DECLARE @c_SerialNo                    NVARCHAR(30)   = ''
         , @c_TrackingNo                  NVARCHAR(40)   = ''
         , @f_Weight                      FLOAT          = 0
         , @c_CartonType                  NVARCHAR(10)   = ''

         , @c_SOStatus                    NVARCHAR(60)   = ''
         , @c_Status                      NVARCHAR(60)   = ''

         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)= ''


         , @c_SQLQuery                    NVARCHAR(MAX)  = ''
         , @c_SQLWhereClause              NVARCHAR(2000) = ''
         , @c_SQLParams                   NVARCHAR(2000) = ''

         , @c_PrePackMsgOrder             NVARCHAR(10)   = ''
         , @c_PrePackMsgSP                NVARCHAR(200)  = ''
         , @c_PrePackMsg                  NVARCHAR(MAX)  = ''
         , @c_PrePackMsgSuccess           NVARCHAR(4000) = ''

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''

   DECLARE @t_Carton As Table (
         CartonizationKey     NVARCHAR(10)      NULL
      ,  CartonType           NVARCHAR(10)      NULL
      ,  [Cube]               FLOAT             NULL
      ,  MaxWeight            FLOAT             NULL
      ,  MaxCount             INT               NULL
      ,  CartonWeight         FLOAT             NULL
      ,  CartonLength         FLOAT             NULL
      ,  CartonWidth          FLOAT             NULL
      ,  CartonHeight         FLOAT             NULL
      ,  AlertMsg             NVARCHAR(255)     NULL
   )

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

   DECLARE @t_PackingRules AS TABLE (
         RuleName          NVARCHAR(60)   NULL
      ,  [Value]           NVARCHAR(120)  NULL
   )

   --Delete packheader&detail if order not match yet
   --This could be due to front-end failed in calling searchorder API
   IF @c_PackIsExists = 1 AND @c_PackStatus = '0' AND @c_PackOrderKey = '' AND @c_PackAddWho = @c_UserID
   BEGIN
      DELETE FROM [dbo].[PackDetail]
      WHERE PickSlipNo = @c_PickSlipNo
      AND StorerKey = @c_StorerKey

      DELETE FROM [dbo].[PackHeader]
      WHERE PickSlipNo = @c_PickSlipNo
      AND StorerKey = @c_StorerKey

      DELETE FROM [dbo].[PackSerialNo]
      WHERE PickSlipNo = @c_PickSlipNo

      GOTO QUERYRULES
   END

   -- If Pack by Drop ID
   IF @c_DropID <> '' AND @c_TaskBatchID <> ''
   BEGIN
      SET @c_TaskBatchID_ToDisplay = @c_TaskBatchID
   END

   IF @c_PackIsExists = 1
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT '>>>>>> @c_PackIsExists = 1'
         PRINT '>>>>>> @c_PickSlipNo = ' + @c_PickSlipNo
         PRINT '>>>>>> @c_PackOrderKey = ' + @c_PackOrderKey
         PRINT '>>>>>> @c_PackComputerName = ' + @c_PackComputerName
         PRINT '>>>>>> @c_PackAddWho = ' + @c_PackAddWho
         PRINT '>>>>>> @c_PackStatus = ' + @c_PackStatus
      END

      SELECT @n_EstTotalCtn = ISNULL(EstimateTotalCtn, 0)
      FROM [dbo].[PackHeader] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      --Get StorerConfig (EPackTakeOver)
      SET @c_sc_EPackTakeOver = ''
      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''
      SET @c_sc_ToOption1 = ''
      SET @c_sc_ToOption5 = ''

      EXEC [dbo].[nspGetRight]
            @c_Facility      = @c_Facility
         ,  @c_StorerKey     = @c_StorerKey
         ,  @c_sku           = ''
         ,  @c_ConfigKey     = 'EPackTakeOver'
         ,  @b_Success       = @n_sc_Success       OUTPUT     
         ,  @c_authority     = @c_sc_EPackTakeOver OUTPUT    
         ,  @n_err           = @n_sc_err           OUTPUT    
         ,  @c_errmsg        = @c_sc_errmsg        OUTPUT  
         ,  @c_Option1       = @c_sc_ToOption1     OUTPUT   
         ,  @c_Option5       = @c_sc_ToOption5     OUTPUT

      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 51007
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight. '  
         GOTO QUIT
      END

      --Get StorerConfig (MultiPackMode)
      SET @c_sc_MultiPackMode = ''
      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''
      SET @c_sc_Option1 = ''
      SET @c_sc_Option5 = ''

      EXEC [dbo].[nspGetRight]
            @c_Facility      = @c_Facility
         ,  @c_StorerKey     = @c_StorerKey
         ,  @c_sku           = ''
         ,  @c_ConfigKey     = 'MultiPackMode'
         ,  @b_Success       = @n_sc_Success       OUTPUT     
         ,  @c_authority     = @c_sc_MultiPackMode OUTPUT    
         ,  @n_err           = @n_sc_err           OUTPUT    
         ,  @c_errmsg        = @c_sc_errmsg        OUTPUT  
         ,  @c_Option1       = @c_sc_Option1       OUTPUT   
         ,  @c_Option5       = @c_sc_Option5       OUTPUT

      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 51008
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight. '  
         GOTO QUIT
      END

      IF @b_Debug = 1
      BEGIN
         PRINT 'PackTakeOver & MultiPackMode '
         PRINT '>>>>>> @c_sc_EPackTakeOver = ' + @c_sc_EPackTakeOver
         PRINT '>>>>>> @c_sc_ToOption1 = ' + @c_sc_ToOption1
         PRINT '>>>>>> @c_sc_ToOption5 = ' + @c_sc_ToOption5
         PRINT '>>>>>> @c_sc_MultiPackMode = ' + @c_sc_MultiPackMode
         PRINT '>>>>>> @c_sc_ToOption1 = ' + @c_sc_Option1
         PRINT '>>>>>> @c_sc_ToOption5 = ' + @c_sc_Option5
      END

      IF @c_sc_Option1 <> ''  
      BEGIN
         IF @c_sc_Option1 = 'userid' AND @c_UserID <> @c_PackAddWho AND NOT (@c_sc_EPackTakeOver = '1' AND @c_sc_ToOption1 = 'USERID' AND CHARINDEX(@c_UserId, @c_sc_ToOption5) > 0)  
            SET @c_PackIsExists = 0   
         IF @c_sc_Option1 = 'computer' AND @c_ComputerName <> @c_PackComputerName AND NOT (@c_sc_EPackTakeOver = '1' AND @c_sc_ToOption1 = 'COMPUTER' AND CHARINDEX(@c_ComputerName, @c_sc_ToOption5) > 0)   
            SET @c_PackIsExists = 0
         
         IF @c_PackIsExists = 0  
         BEGIN  
            IF @b_Debug = 1 PRINT '>>>>>> Changed @c_PackIsExists = 0'
            GOTO QUERYRULES
         END
      END      

      SELECT TOP 1 
          @c_SKU = PD.SKU
      FROM PACKDETAIL PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @c_PickSlipNo      AND PD.CartonNo = 1

      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''

      --EXEC [API].[isp_ECOMP_GetPackRules]
      --     @c_StorerKey                = @c_StorerKey
      --   , @c_Facility                 = @c_Facility
      --   , @c_SKU                      = @c_SKU
      --   , @b_IsSerialNoMandatory      = @b_IsSerialNoMandatory      OUTPUT
      --   , @b_IsPackQRFMandatory       = @b_IsPackQRFMandatory       OUTPUT
      --   , @c_PackQRF_RegEx            = @c_PackQRF_RegEx            OUTPUT
      --   , @b_IsTrackingNoMandatory    = @b_IsTrackingNoMandatory    OUTPUT
      --   , @b_IsCartonTypeMandatory    = @b_IsCartonTypeMandatory    OUTPUT
      --   , @b_IsWeightMandatory        = @b_IsWeightMandatory        OUTPUT
      --   , @b_IsAutoWeightCalc         = @b_IsAutoWeightCalc         OUTPUT
      --   , @b_IsAutoPackConfirm        = @b_IsAutoPackConfirm        OUTPUT
      --   , @b_Success                  = @n_sc_Success               OUTPUT
      --   , @n_ErrNo                    = @n_sc_err                   OUTPUT
      --   , @c_ErrMsg                   = @c_sc_errmsg                OUTPUT

      INSERT INTO @t_PackingRules
      EXEC [API].[isp_ECOMP_GetPackingRules]
           @c_StorerKey                = @c_StorerKey
         , @c_Facility                 = @c_Facility
         , @c_SKU                      = @c_SKU
         , @b_Success                  = @n_sc_Success               OUTPUT
         , @n_ErrNo                    = @n_sc_err                   OUTPUT
         , @c_ErrMsg                   = @c_sc_errmsg                OUTPUT

      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 51009
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. ' + ISNULL(RTRIM(@c_sc_errmsg), '')
         GOTO QUIT
      END

      IF @c_PackOrderKey <> ''
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT 'Getting Order Info.'
         END

         --Get Order Information
         INSERT INTO @t_OrderInfo 
         EXEC [API].[isp_ECOMP_GetOrderInfo] 
            @c_OrderKey = @c_PackOrderKey
          , @c_SourceApp = 'SCE'

         SELECT 
            @c_SerialNo = ISNULL(SerialNo, '')
         FROM dbo.PACKSERIALNO WITH (NOLOCK) 
         WHERE PickSlipNo = @c_PickSlipNo 
         AND SKU = @c_SKU 
         AND CartonNo = 1

         SELECT TOP 1 @c_TrackingNo = ISNULL(RTRIM(TrackingNo), '')
                     ,@c_SOStatus   = ISNULL(RTRIM([SOStatus]), '')
                     ,@c_Status     = ISNULL(RTRIM([Status]),   '')
         FROM @t_OrderInfo

         IF @c_PackStatus = '9'
         BEGIN
            SELECT @c_TrackingNo = ISNULL(RTRIM(TrackingNo), '')
                  ,@c_CartonType = ISNULL(RTRIM(CartonType), '')
                  ,@f_Weight = [Weight]
            FROM [dbo].[PackInfo] WITH (NOLOCK) 
            WHERE PickSlipNo = @c_PickSlipNo
         END
         ELSE 
         BEGIN
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
               SELECT @c_CartonType = @c_DefaultCartonType

               SELECT @f_CartonWeight = ISNULL([CartonWeight], 0)
               FROM [dbo].[Cartonization] WITH (NOLOCK) 
               WHERE CartonizationGroup = @c_DefaultCartonGroup AND CartonType = @c_DefaultCartonType
            END
         END

         EXEC [API].[isp_ECOMP_CheckCartonLabelNo]
              @c_StorerKey                = @c_StorerKey        
            , @c_Facility                 = @c_Facility         
            , @c_SKU                      = @c_SKU              
            , @c_PickSlipNo               = @c_PickSlipNo       
            , @b_IsLabelNoCaptured        = @b_IsLabelNoCaptured  OUTPUT

         SET @c_OrderStatusJson = (
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
                                    WHERE PTD.TaskBatchNo = CASE WHEN @c_TaskBatchID = '' THEN PTD.TaskBatchNo ELSE @c_TaskBatchID END
                                    AND   PTD.Orderkey = @c_PackOrderKey    
                                    GROUP  BY PTD.Orderkey  
                                          ,PTD.Storerkey  
                                          ,PTD.Sku  
                                          ,PTD.QtyAllocated  
                                          ,S.Descr
                                    FOR JSON PATH
                                  )
         
         SELECT @c_PackQRF_QRCode = ISNULL([QRCode], '')
         FROM [dbo].[PACKQRF] WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo 
      END

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

      SET @c_InnerJson = ISNULL(( 
                           SELECT @c_PackStatus                As 'PackStatus'
                                 ,@n_EstTotalCtn               As 'EstimateTotalCarton'
                                 --Scanning columns
                                 ,@c_PickSlipNo                AS 'PickSlipNo'
                                 ,@c_SKU                       As 'SKU'
                                 ,@c_SerialNo                  As 'SerialNumber'
                                 ,@c_TrackingNo                As 'TrackingNumber'
                                 ,@c_CartonType                As 'CartonType'
                                 ,@f_CartonWeight              As 'CartonWeight'
                                 ,@f_Weight                    As 'Weight'
                                 ,@c_PackQRF_QRCode            As 'PackQRF_QRCode'
                                 ,@b_IsLabelNoCaptured         As 'IsLabelNoCaptured'
                                 ,(
                                    SELECT ISNULL(RTRIM(RuleName), '')  As 'RuleName'
                                          ,ISNULL(RTRIM([Value]), '')   As 'Value'
                                    FROM @t_PackingRules
                                    FOR JSON PATH
                                 ) AS 'PackingRules'
                                 ,( 
                                    SELECT PD.SKU
                                          ,PD.QTY
                                          ,PD.LOTTABLEVALUE    As 'LottableValue'
                                          ,SKU.STDGROSSWGT     As 'STDGrossWeight'
                                    FROM [dbo].[PackDetail] PD WITH (NOLOCK)
                                    JOIN [dbo].[SKU] SKU WITH (NOLOCK) 
                                    ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                                    WHERE PickSlipNo = @c_PickSlipNo
                                    FOR JSON PATH 
                                  ) AS 'CartonPackedSKU'
                                 ,(
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
                                  ) As 'OrderInfo'
                                 ,(
                                    JSON_QUERY(@c_OrderStatusJson)
                                  ) As 'OrderStatusList'
                           FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                         ), '')

      IF @b_Debug = 1
      BEGIN
         PRINT '@c_InnerJson ='
         PRINT ISNULL(@c_InnerJson, 'ISNULL')
      END

   END
   --Get Pending PackHeader/Detail (End)

   QUERYRULES:
   
   --Alex02 Begin
   --Get EcomPrePackMsg(gift Wrapping)
   
   SET @c_PrePackMsgOrder = @c_OrderKey 
   
   IF @c_PrePackMsgOrder = ''
   BEGIN
      SELECT TOP 1 @c_PrePackMsgOrder = ISNULL(OrderKey, '')
      FROM [dbo].[PackTaskDetail] PTD WITH (NOLOCK) 
      WHERE TaskBatchNo = @c_TaskBatchID
      --AND [Status] = '0'
      AND EXISTS ( SELECT 1 FROM [dbo].[OrderDetail] ORD WITH (NOLOCK) 
         WHERE ORD.OrderKey = PTD.OrderKey AND ORD.Notes = 'Y' )
      ORDER BY RowRef
      
      --IF @c_PrePackMsgOrder = ''
      --BEGIN
      --   SELECT TOP 1 @c_PrePackMsgOrder = ISNULL(OrderKey, '')
      --   FROM [dbo].[PackTaskDetail] PTD WITH (NOLOCK) 
      --   WHERE TaskBatchNo = @c_TaskBatchID
      --   AND EXISTS ( SELECT 1 FROM [dbo].[OrderDetail] ORD WITH (NOLOCK) 
      --      WHERE ORD.OrderKey = PTD.OrderKey AND ORD.Notes = 'Y' )
      --   ORDER BY RowRef
      --END
   END
   
   IF @b_Debug = 1
   BEGIN
      PRINT '@c_PrePackMsgOrder = ' + @c_PrePackMsgOrder
   END
   
   IF @c_PrePackMsgOrder <> '' 
      AND EXISTS ( SELECT 1 FROM [dbo].[ORDERDETAIL] WITH (NOLOCK) 
         WHERE OrderKey = @c_PrePackMsgOrder AND Notes = 'Y')
   BEGIN
      SET @c_PrePackMsg = ''
      SET @c_PrePackMsgSP = ''
      
      EXEC [dbo].[nspGetRight]
               @c_Facility      = @c_Facility
            ,  @c_StorerKey     = @c_StorerKey
            ,  @c_sku           = ''
            ,  @c_ConfigKey     = 'EcomPrePackMsg'
            ,  @b_Success       = @n_sc_Success       OUTPUT     
            ,  @c_authority     = @c_PrePackMsgSP     OUTPUT    
            ,  @n_err           = @n_sc_err           OUTPUT    
            ,  @c_errmsg        = @c_sc_errmsg        OUTPUT
      
      IF ISNULL(RTRIM(@c_PrePackMsgSP), '') <> '' AND @c_PrePackMsgSP <> '0'
      BEGIN
         SET @c_SQLQuery = 'EXEC [dbo].[' + @c_PrePackMsgSP + '] ' + CHAR(13) + 
                         + '      @c_TaskBatchNo   = @c_TaskBatchID               ' + CHAR(13) +
                         + '   ,  @c_Orderkey      = @c_OrderKey                  ' + CHAR(13) +
                         + '   ,  @b_Success       = @c_PrePackMsgSuccess  OUTPUT ' + CHAR(13) +
                         + '   ,  @c_ErrMsg        = @c_PrePackMsg         OUTPUT ' + CHAR(13) 
      
         SET @c_SQLParams = '@c_TaskBatchID NVARCHAR(10), @c_Orderkey NVARCHAR(40), @c_PrePackMsgSuccess NVARCHAR(4000) OUTPUT, @c_PrePackMsg NVARCHAR(4000) OUTPUT '
      
         BEGIN TRY
            EXECUTE sp_ExecuteSql 
                  @c_SQLQuery
                 ,@c_SQLParams
                 ,@c_TaskBatchID
                 ,@c_PrePackMsgOrder
                 ,@c_PrePackMsgSuccess    OUTPUT
                 ,@c_PrePackMsg           OUTPUT
         END TRY
         BEGIN CATCH
            SET @n_Continue = 3 
            SET @n_ErrNo = 51010
            SET @c_ErrMsg = ERROR_MESSAGE()
            GOTO QUIT
         END CATCH
         
         --Replace <CR> with newline (\r\n)
         SET @c_PrePackMsg = REPLACE(@c_PrePackMsg, N'<CR>', CHAR(13) + CHAR(10))
      
         --Alex02 End
      END 
   END      
   --Get EcomPrePackMsg(gift Wrapping) -E

   -- Get Pack Description
   SELECT TOP 1 @c_PackNotes = ISNULL(Notes, '')
   FROM dbo.PICKDETAIL WITH (NOLOCK) 
   WHERE OrderKey = @c_1stOrderKey

   SET @n_sc_Success = 0
   SET @n_sc_err = 0
   SET @c_sc_errmsg = ''

   EXEC [dbo].[nspGetRight]
      @c_Facility      = @c_Facility
   ,  @c_StorerKey     = @c_StorerKey
   ,  @c_sku           = ''
   ,  @c_ConfigKey     = 'CtnTypeInput'
   ,  @b_Success       = @n_sc_Success       OUTPUT     
   ,  @c_authority     = @c_sc_CtnTypeInput  OUTPUT    
   ,  @n_err           = @n_sc_err           OUTPUT    
   ,  @c_errmsg        = @c_sc_errmsg        OUTPUT  

   IF @n_sc_Success <> 1   
   BEGIN   
      SET @n_Continue = 3 
      SET @n_ErrNo = 51010
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight. '  
      GOTO QUIT
   END

   IF @c_sc_CtnTypeInput = '1'
   BEGIN
      INSERT INTO @t_Carton ( CartonizationKey, CartonType, [Cube], MaxWeight, MaxCount, CartonWeight, CartonLength, CartonWidth, CartonHeight, AlertMsg )
      EXEC [API].[isp_ECOMP_GetPackCartonType]
         @c_Facility    = @c_Facility
      ,  @c_Storerkey   = @c_StorerKey
      ,  @c_CartonType  = ''
      ,  @c_CartonGroup = ''
      ,  @c_PickSlipNo  = ''
      ,  @n_CartonNo    = ''
      ,  @c_SourceApp   = 'SCE'
   END

   --TaskBatchID input is blank, get TaskBatchID from PackTask table for counting orders
   IF @c_TaskBatchID = ''
   BEGIN
      SELECT @c_TaskBatchID = ISNULL(RTRIM(TaskBatchNo), '')
      FROM [dbo].[PackTask] WITH (NOLOCK) 
      WHERE OrderKey = @c_OrderKey
   END

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

   --Alex03 Begin
   EXEC [API].[isp_ECOMP_GetEPackConfigs]
     @c_StorerKey       = @c_StorerKey   
   , @c_Facility        = @c_Facility    
   , @c_UserId          = @c_UserId      
   , @c_ComputerName    = @c_ComputerName
   , @c_PackMode        = @c_OrderMode    
   , @c_TaskBatchID     = @c_TaskBatchID 
   , @c_OrderKey        = @c_OrderKey    
   , @c_DropID          = @c_DropID      
   , @c_EPACKConfigJSON = @c_EPACKConfigJSON OUTPUT
   --Alex03 End

   SET @c_ResponseString = ISNULL(( 
                              SELECT TOP 1
                                     @c_PackNotes As 'PackNotes'
                                    ,@c_TaskBatchID_ToDisplay As 'TaskBatchID_ToDisplay'
                                    ,@c_OrderKey_ToDisplay As 'OrderKey_ToDisplay'
                                    ,@c_OrderMode As 'OrderMode'
                                    ,@n_TotalCarton As 'TotalCarton'
                                    ,@n_CartonNo As 'CartonNo'
                                    ,TotalOrder As 'TotalOrders'
                                    ,PendingOrder As 'TotalPendingOrders'
                                    ,PackedOrder As 'TotalPackedOrders'
                                    ,CancelledOrder As 'TotalCancOrders'
                                    ,NonEPackSO     As 'NonEPackSO'
                                    ,InProgOrderKey As 'LastOrderID'
                                    ,@c_PrePackMsg  As 'PrePackMeassage'
                                    ,( 
                                       SELECT CartonType, CartonWeight FROM @t_Carton
                                       FOR JSON PATH 
                                     ) As 'CartonTypeList'
                                    ,(
                                       JSON_QUERY(@c_InnerJson)
                                     ) As 'PackTask'
                                    ,(
                                       JSON_QUERY(@c_EPACKConfigJSON)
                                     ) As 'EPACKConfig'
                              FROM @t_PackTaskOrderSts
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
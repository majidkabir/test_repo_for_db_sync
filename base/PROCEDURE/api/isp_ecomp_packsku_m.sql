SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_PackSKU_M]                         */              
/* Creation Date: 13-FEB-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes                                     */
/* 05-Jul-2023    Alex     #JIRA PAC-7 Initial                          */
/* 29-Jan-2024    Alex02   #PAC-322 - Scan QRCode in Serial# direct     */
/*                         insert packdetail                            */
/* 10-Sep-2024    Alex03   #PAC-353 - Bundle Packing validation         */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_PackSKU_M](
     @b_Debug                    INT            = 0
   , @c_ProcessName              NVARCHAR(30)   = ''
   , @c_TaskBatchID              NVARCHAR(10)   = ''
   , @c_DropID                   NVARCHAR(20)   = ''
   , @c_OrderKey                 NVARCHAR(10)   = ''
   , @c_OrderMode                NVARCHAR(1)    = ''
   , @c_PickSlipNo               NVARCHAR(10)   = ''
   , @c_StorerKey                NVARCHAR(15)   = ''
   , @c_Facility                 NVARCHAR(15)   = ''
   , @c_SKU                      NVARCHAR(20)   = ''
   , @c_LottableValue            NVARCHAR(60)   = ''
   , @n_CartonNo                 INT            = 1
   , @b_IsOrderMatch             INT            = 0   OUTPUT
   , @b_IsSKUPacked              INT            = 0   OUTPUT
   , @c_PackHeaderOrderKey       NVARCHAR(10)   = ''  OUTPUT
   , @b_Success                  INT            = 0   OUTPUT
   , @n_ErrNo                    INT            = 0   OUTPUT
   , @c_ErrMsg                   NVARCHAR(250)  = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_SQLQuery                    NVARCHAR(MAX)  = ''
         , @c_SQLWhereClause              NVARCHAR(2000) = ''
         , @c_SQLParams                   NVARCHAR(2000) = ''

   DECLARE @n_Continue                    INT            = 1
         , @n_StartCnt                    INT            = @@TRANCOUNT
        
         , @n_LabelLineNo                 INT            = 0
         , @n_IsExists                    INT            = 0 
         , @c_PHOrderKey                  NVARCHAR(10)   = ''
         --, @b_InsUpdPackDetail            INT            = 0 
         , @c_TrackingNumber              NVARCHAR(40)   = ''
         , @n_IsPIExists                  INT            = 0
         , @c_PITrackingNumber            NVARCHAR(40)   = ''

         , @c_CTNTrackNoSP                NVARCHAR(40)   = ''

   DECLARE @c_Route                       NVARCHAR(10)   = '' 
         , @c_OrderRefNo                  NVARCHAR(50)   = '' 
         , @c_LoadKey                     NVARCHAR(10)   = '' 
         , @c_CartonGroup                 NVARCHAR(10)   = '' 
         , @c_ConsigneeKey                NVARCHAR(15)   = '' 

         , @b_IsSerialNoMandatory         INT            = 0
         , @b_IsLottableMandatory         INT            = 0
         , @b_IsPackQRFMandatory          INT            = 0 

         --, @b_IsSKUPacked                 INT            = 0  
         , @n_CurCtnNo                    INT            = 0

   DECLARE @n_sp_Success                  INT            = 0
         , @n_sp_err                      INT            = 0
         , @c_sp_errmsg                   NVARCHAR(255)  = ''

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ProcessName                     = ISNULL(RTRIM(@c_ProcessName), '')

   SET @b_IsOrderMatch                    = 0
   --SET @b_IsSKUPacked                     = 0

   DECLARE @t_SKUPackingRules AS TABLE (
         RuleName          NVARCHAR(60)   NULL
      ,  [Value]           NVARCHAR(120)  NULL
   )

   DECLARE @t_PackTaskOrder AS TABLE (
         TaskBatchNo          NVARCHAR(10)      NULL
      ,  OrderKey             NVARCHAR(10)      NULL
      ,  DeviceOrderkey       NVARCHAR(20)      NULL
      ,  [Status]             NVARCHAR(10)      NULL
      ,  INProgOrderkey       NVARCHAR(20)      NULL
      ,  Color                NVARCHAR(10)      NULL
   )

   IF @c_ProcessName NOT IN ('INPUT_SKU', 'INPUT_SERIALNUMBER', 'INPUT_LOTTABLE', 'INPUT_QRF')
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 53101
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_ErrNo) + '. Invalid @c_ProcessName = ' + @c_ProcessName + '. '  
      GOTO QUIT
   END

   IF @b_IsSKUPacked = 1
   BEGIN
      GOTO INS_UPD_PACK_DETAIL
   END

   --INSERT INTO @t_PackingRules
   --EXEC [API].[isp_ECOMP_GetPackingRules]
   --     @c_StorerKey                = @c_StorerKey
   --   , @c_Facility                 = @c_Facility
   --   , @c_SKU                      = @c_SKU
   --   , @c_PackMode                 = @c_OrderMode
   --   , @b_Success                  = @n_sp_Success               OUTPUT
   --   , @n_ErrNo                    = @n_sp_err                   OUTPUT
   --   , @c_ErrMsg                   = @c_sp_errmsg                OUTPUT

   INSERT INTO @t_SKUPackingRules
   EXEC [API].[isp_ECOMP_GetSKUPackingRules]
     @b_Debug                    = @b_Debug
   , @c_PickSlipNo               = @c_PickSlipNo
   , @c_TaskBatchID              = @c_TaskBatchID
   , @c_DropID                   = @c_DropID
   , @c_OrderKey                 = @c_OrderKey
   , @c_StorerKey                = @c_StorerKey
   , @c_Facility                 = @c_Facility
   , @c_SKU                      = @c_SKU
   , @c_PackMode                 = @c_OrderMode
   , @b_Success                  = @n_sp_Success  OUTPUT
   , @n_ErrNo                    = @n_sp_err      OUTPUT
   , @c_ErrMsg                   = @c_sp_errmsg   OUTPUT

   IF @n_sp_Success <> 1   
   BEGIN   
      SET @n_Continue = 3 
      SET @n_ErrNo = 53102
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_sp_err) + '. ' + ISNULL(RTRIM(@c_sp_errmsg), '')
      GOTO QUIT
   END

   SET @b_IsSerialNoMandatory = CASE WHEN EXISTS(SELECT 1 FROM @t_SKUPackingRules WHERE RuleName = 'IsSerialNoMandatory' AND [Value] = '1') THEN 1 ELSE 0 END
   SET @b_IsLottableMandatory = CASE WHEN EXISTS(SELECT 1 FROM @t_SKUPackingRules WHERE RuleName = 'IsLottableMandatory' AND [Value] = '1') THEN 1 ELSE 0 END
   SET @b_IsPackQRFMandatory = CASE WHEN dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKQRF')  IN ('1','3') THEN 1 ELSE 0 END

   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>>>>>>>>>>>>>>> [API].[isp_ECOMP_PackSKU_M] '
      PRINT 'IsSerialNoMandatory = ' + CONVERT(NVARCHAR(1), @b_IsSerialNoMandatory)
      PRINT 'IsLottableMandatory = ' + CONVERT(NVARCHAR(1), @b_IsLottableMandatory)
   END

   IF @c_ProcessName = 'INPUT_SKU'
   BEGIN
      IF @b_IsSerialNoMandatory = 0 AND @b_IsLottableMandatory = 0 AND @b_IsPackQRFMandatory = 0
      BEGIN
         SET @b_IsSKUPacked = 1
         GOTO INS_UPD_PACK_DETAIL
      END

      ----PreCheckLA
      --IF @b_IsLottableMandatory = 1
      --BEGIN
      --   --SELECT @c_PickSlipNo, @c_Storerkey, @c_Sku, @c_TaskBatchID

      --   EXEC [dbo].[isp_PackLAPreCheck_Wrapper]
      --      @c_PickSlipNo  = @c_PickSlipNo
      --     ,@c_Storerkey   = @c_Storerkey
      --     ,@c_Sku         = @c_Sku
      --     ,@c_TaskBatchNo = @c_TaskBatchID
      --     ,@b_Success     = @n_sp_Success   OUTPUT
      --     ,@n_Err         = @n_sp_err       OUTPUT
      --     ,@c_ErrMsg      = @c_sp_errmsg    OUTPUT

      --   --SELECT @n_sp_Success
      --   --SELECT @n_sp_Success, @n_sp_err, @c_sp_errmsg
      --   IF @n_sp_Success <> 1 AND @n_sp_err > 0
      --   BEGIN   
      --      SET @n_Continue = 3 
      --      SET @n_ErrNo = 53103
      --      SET @c_ErrMsg = CONVERT(CHAR(5),@n_sp_err) + '. ' + ISNULL(RTRIM(@c_sp_errmsg), '')
      --      GOTO QUIT
      --   END
      --END
      GOTO QUIT
   END

   IF @c_ProcessName = 'INPUT_SERIALNUMBER'
   BEGIN
      --to check if serial number is required.
      IF @b_IsSerialNoMandatory = 1
      BEGIN
         SET @b_IsSKUPacked = 1
         GOTO INS_UPD_PACK_DETAIL
      END

      IF @b_IsLottableMandatory = 0
      BEGIN
         SET @b_IsSKUPacked = 1
         GOTO INS_UPD_PACK_DETAIL
      END

      GOTO QUIT
   END

   IF @c_ProcessName = 'INPUT_LOTTABLE'
   BEGIN
      IF @b_IsLottableMandatory = 1
      BEGIN
         SET @b_IsSKUPacked = 1
         GOTO INS_UPD_PACK_DETAIL
      END
   END

   IF @c_ProcessName = 'INPUT_QRF'
   BEGIN
      IF @b_IsPackQRFMandatory = 1
      BEGIN
         SET @b_IsSKUPacked = 1
         GOTO INS_UPD_PACK_DETAIL
      END
   END

   INS_UPD_PACK_DETAIL:
   IF @b_IsSKUPacked = 1
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT '>>>>> Bundle Packing Validation'
         PRINT '@c_OrderKey = ' + @c_OrderKey
         PRINT '@c_SKU = ' + @c_SKU
      END

      --Alex03 S
      SET @n_sp_Success = 0
      EXEC [API].[isp_ECOMP_BundlePackingValidation_Wrapper]
            @b_Debug          = @b_Debug
         ,  @c_PickSlipNo     = @c_PickSlipNo
         ,  @n_CartonNo       = @n_CartonNo
         ,  @c_OrderKey       = @c_OrderKey
         ,  @c_Storerkey      = @c_Storerkey
         ,  @c_SKU            = @c_SKU
         ,  @c_Type           = 'VERIFYSKU'
         ,  @b_Success        = @n_sp_Success   OUTPUT  
         ,  @n_Err            = @n_sp_err       OUTPUT  
         ,  @c_ErrMsg         = @c_sp_errmsg    OUTPUT  

      IF @n_sp_Success = 0
      BEGIN
         SET @n_Continue = 3 
         SET @n_ErrNo = @n_sp_err
         SET @c_ErrMsg = @c_sp_errmsg
         GOTO QUIT
      END
      --Alex03 E

      --SELECT @n_CartonNo [@n_CartonNo]
      IF NOT EXISTS ( 
         SELECT 1 FROM [dbo].[PackDetail] WITH (NOLOCK) 
         WHERE PickSlipNo = @c_PickSlipNo AND StorerKey = @c_StorerKey AND SKU = @c_SKU AND CartonNo = @n_CartonNo AND LOTTABLEVALUE = @c_LottableValue)
      BEGIN
         SELECT @n_LabelLineNo = (COUNT(1) + 1)
         FROM [dbo].[PackDetail](NOLOCK) 
         WHERE PickSlipNo = @c_PickSlipNo 
         AND StorerKey = @c_StorerKey
         AND CartonNo = @n_CartonNo

         --SELECT @c_PickSlipNo [@c_PickSlipNo], @n_LabelLineNo [@n_LabelLineNo], @c_StorerKey [@c_StorerKey], @n_CartonNo [@n_CartonNo]

         INSERT INTO [dbo].[PackDetail] (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, Qty, DropId, LOTTABLEVALUE)
         VALUES(@c_PickSlipNo, @n_CartonNo, '', RIGHT('0000'+CONVERT(NVARCHAR, @n_LabelLineNo),5), @c_StorerKey, @c_SKU, 1, '', @c_LottableValue)
      END
      ELSE
      BEGIN
         UPDATE [dbo].[PackDetail] WITH (ROWLOCK)
         SET Qty = (Qty + 1)
         WHERE PickSlipNo = @c_PickSlipNo
         AND StorerKey = @c_StorerKey
         AND SKU = @c_SKU
         AND CartonNo = @n_CartonNo
         AND LottableValue = @c_LottableValue
      END

      --Assign Order (Begin)
      SELECT @n_IsExists = (1)
            , @c_PHOrderKey = ISNULL(RTRIM(OrderKey), '')
      FROM [dbo].[PackHeader] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      --SELECT @c_PHOrderKey [@c_PHOrderKey], @c_TaskBatchID [@c_TaskBatchID]
      IF @c_PHOrderKey = ''
      BEGIN
         EXEC [API].[isp_ECOMP_MatchingOrder_M]
              @b_Debug                    = @b_Debug
            , @c_PickSlipNo               = @c_PickSlipNo
            , @b_IsPackConfirm            = 0
            , @c_TaskBatchID              = @c_TaskBatchID
            , @c_DropID                   = @c_DropID
            , @c_OrderKey                 = ''
            , @b_IsOrderMatch             = @b_IsOrderMatch    OUTPUT
            , @c_AssignedOrderKey         = @c_PHOrderKey      OUTPUT
         
         --INSERT INTO @t_PackTaskOrder( TaskBatchNo, OrderKey, DeviceOrderkey, [Status], INProgOrderkey, Color )
         --EXEC [API].[isp_ECOMP_GetPackTaskOrders_M]  
         --      @c_TaskBatchNo    = @c_TaskBatchID
         --   ,  @c_PickSlipNo     = @c_PickSlipNo
         --   ,  @c_Orderkey       = @c_PHOrderKey   OUTPUT  
         --   ,  @b_packcomfirm    = 1
         --   ,  @c_DropID         = @c_DropID

         --IF @c_PHOrderKey <> ''
         --BEGIN
         --   SET @b_IsOrderMatch = 1

         --   SELECT @c_Route         = ISNULL(RTRIM([Route]), '')
         --         ,@c_OrderRefNo    = ISNULL(RTRIM([ExternOrderKey]), '')
         --         ,@c_LoadKey       = ISNULL(RTRIM([LoadKey]), '')
         --         ,@c_ConsigneeKey  = ISNULL(RTRIM([ConsigneeKey]), '')
         --   FROM [dbo].[ORDERS] WITH (NOLOCK)
         --   WHERE OrderKey = @c_PHOrderKey

         --   UPDATE [dbo].[PackHeader] WITH (ROWLOCK)
         --   SET [Route]        = @c_Route       
         --      ,[OrderKey]     = @c_PHOrderKey
         --      ,[OrderRefNo]   = @c_OrderRefNo
         --      ,[LoadKey]      = @c_LoadKey
         --      ,[ConsigneeKey] = @c_ConsigneeKey
         --   WHERE PickSlipNo = @c_PickSlipNo

         --   IF EXISTS ( SELECT 1 FROM [dbo].[PackInfo] WITH (NOLOCK) 
         --      WHERE PickSlipNo = @c_PickSlipNo )
         --   BEGIN
         --      --Assign Tracking Number to Each Carton Packed.
         --      DECLARE C_LOOP_PI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         --      SELECT CartonNo
         --      FROM [dbo].[PackInfo] WITH (NOLOCK) 
         --      WHERE PickSlipNo = @c_PickSlipNo
         --      OPEN C_LOOP_PI
         --      FETCH NEXT FROM C_LOOP_PI INTO @n_CurCtnNo
         --      WHILE @@FETCH_STATUS <> -1   
         --      BEGIN
         --         SET @c_TrackingNumber = ''
         --         EXEC [API].[isp_ECOMP_GetTrackingNumber]
         --              @b_Debug                   = @b_Debug
         --            , @c_PickSlipNo              = @c_PickSlipNo
         --            , @n_CartonNo                = @n_CurCtnNo
         --            , @c_TrackingNo              = @c_TrackingNumber     OUTPUT

         --         IF @c_TrackingNumber <> '' 
         --         BEGIN
         --            UPDATE [dbo].[PackInfo] WITH (ROWLOCK)
         --            SET TrackingNo = @c_TrackingNumber
         --            WHERE PickSlipNo = @c_PickSlipNo
         --            AND CartonNo = @n_CurCtnNo
         --         END

         --         FETCH NEXT FROM C_LOOP_PI INTO @n_CurCtnNo
         --      END -- WHILE @@FETCH_STATUS <> -1   
         --      CLOSE C_LOOP_PI  
         --      DEALLOCATE C_LOOP_PI
         --   END
         --END
      END
      SET @c_PackHeaderOrderKey = @c_PHOrderKey
      --Assign Order (End)
   END

   QUIT:
   IF @b_Debug = 1
   BEGIN
      PRINT '@b_IsSKUPacked = ' + CONVERT(NVARCHAR(1), @b_IsSKUPacked)
   END
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
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/    
/* Stored Proc: [API].[isp_ECOMP_GetMultiPackTaskResponse]              */    
/* Creation Date: 18-JUL-2019                                           */    
/* Copyright: Maersk                                                    */    
/* Written by: Alex Keoh                                                */    
/*                                                                      */    
/* Purpose: Performance Tune                                            */    
/*          :                                                           */    
/* Called By:                                                           */    
/*          :                                                           */      
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date           Author   Ver   Purposes                               */    
/* 18-JUL-2023    Alex01   1.0   Initial                                */     
/* 17-MAY-2024    Alex02   1.4   PAC-342 bug fixed                      */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_GetMultiPackTaskResponse] (
     @c_PickSlipNo            NVARCHAR(10)      = ''
   , @c_TaskBatchID           NVARCHAR(10)      = ''
   , @c_OrderKey              NVARCHAR(10)      = ''
   , @c_DropID                NVARCHAR(20)      = ''
   , @b_SkipOrderOutput       INT               = 0
   , @c_MultiPackResponse     NVARCHAR(MAX)     = ''     OUTPUT
   , @c_InProgOrderKey        NVARCHAR(10)      = ''     OUTPUT
   , @b_Success               INT               = 0      OUTPUT
   , @n_ErrNo                 INT               = 0      OUTPUT
   , @c_ErrMsg                NVARCHAR(250)     = ''     OUTPUT
)
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_StartTCnt          INT               = @@TRANCOUNT    
         , @n_Continue           INT               = 1    
         
         , @c_PHOrderKey         NVARCHAR(10)      = ''
         , @c_PHTaskBatchID      NVARCHAR(10)      = ''
         , @c_OrderInfoJson      NVARCHAR(MAX)     = NULL
         , @c_OrderStatusJson    NVARCHAR(MAX)     = NULL

   DECLARE @c_ExternOrderkey     NVARCHAR(50)      = ''
         , @c_LoadKey            NVARCHAR(10)      = ''
         , @c_ConsigneeKey       NVARCHAR(15)      = ''
         , @c_ShipperKey         NVARCHAR(15)      = ''
         , @c_SalesMan           NVARCHAR(30)      = ''
         , @c_Route              NVARCHAR(10)      = ''
         , @c_UserDefine03       NVARCHAR(20)      = ''
         , @c_UserDefine04       NVARCHAR(40)      = ''
         , @c_UserDefine05       NVARCHAR(20)      = ''
         , @c_Status             NVARCHAR(10)      = ''
         , @c_SOStatus           NVARCHAR(10)      = ''
         , @c_TrackingNumber     NVARCHAR(40)      = ''
         , @c_StorerKey          NVARCHAR(15)      = ''
         , @c_PackStatus         NVARCHAR(1)       = ''

         , @n_EstTotalCtn        INT               = 0 
         , @n_LastCartonNo       INT               = 0
         , @b_IsLastCartonClose  INT               = 0

         , @c_PTOJson            NVARCHAR(MAX)     = ''

         , @b_sp_Success         INT               = 0
         , @n_sp_err             INT               = 0
         , @c_sp_errmsg          NVARCHAR(250)     = ''

   --DECLARE @t_PackTaskOrder AS TABLE (
   --      TaskBatchNo          NVARCHAR(10)      NULL
   --   ,  OrderKey             NVARCHAR(10)      NULL
   --   ,  DeviceOrderkey       NVARCHAR(20)      NULL
   --   ,  [Status]             NVARCHAR(10)      NULL
   --   ,  INProgOrderkey       NVARCHAR(20)      NULL
   --   ,  Color                NVARCHAR(10)      NULL
   --)

   IF @c_PickSlipNo <> ''
   BEGIN
      SELECT @c_PHOrderKey = ISNULL(RTRIM(OrderKey), '')
            ,@c_PackStatus = [Status]
            ,@n_EstTotalCtn = ISNULL(EstimateTotalCtn, 0)
            ,@c_PHTaskBatchID = ISNULL(RTRIM(TaskBatchNo), '')
      FROM [dbo].[PackHeader] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      SELECT @n_LastCartonNo = ISNULL(MAX(CartonNo), 1)
      FROM [dbo].[PackDetail] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      SET @c_TaskBatchID = CASE WHEN @c_TaskBatchID = '' THEN @c_PHTaskBatchID ELSE @c_TaskBatchID END
      IF @c_PackStatus = '0' AND @c_PHOrderKey <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM [dbo].[PackInfo] WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_LastCartonNo )
         BEGIN
            SET @c_TrackingNumber = ''
            --Get Tracking Number For Next Carton If ANY
            EXEC [API].[isp_ECOMP_GetTrackingNumber]
                  @b_Debug                   = 0
                , @c_PickSlipNo              = @c_PickSlipNo
                , @n_CartonNo                = @n_LastCartonNo
                , @b_Success                 = @b_sp_Success         OUTPUT
                , @n_ErrNo                   = @n_sp_err             OUTPUT
                , @c_ErrMsg                  = @c_sp_errmsg          OUTPUT
                , @c_TrackingNo              = @c_TrackingNumber     OUTPUT

            IF @b_sp_Success <> 1
            BEGIN
               SET @n_Continue = 3 
               SET @n_ErrNo = 53001
               SET @c_ErrMsg = CONVERT(CHAR(5),@n_sp_err) + ' : ' + CONVERT(CHAR(5),@n_ErrNo)
                             + '. Failed to get tracking number - ' + @c_sp_errmsg
               GOTO QUIT_SP
            END
         END
      END
   END
   ELSE IF @c_PickSlipNo = '' AND @c_OrderKey <> ''
   BEGIN
      SET @c_PHOrderKey = @c_OrderKey

      IF @c_TaskBatchID = ''
      BEGIN
         SELECT TOP 1 @c_TaskBatchID = ISNULL(RTRIM(TaskBatchNo), '')
         FROM [dbo].[PackTask] WITH (NOLOCK) 
         WHERE OrderKey = @c_PHOrderKey
      END

      --Get Tracking Number For First Carton
      EXEC [API].[isp_ECOMP_GetTrackingNumber]
            @b_Debug                   = 0
          , @c_PickSlipNo              = @c_PickSlipNo
          , @c_OrderKey                = @c_PHOrderKey
          , @n_CartonNo                = 1
          , @b_Success                 = @b_sp_Success         OUTPUT
          , @n_ErrNo                   = @n_sp_err             OUTPUT
          , @c_ErrMsg                  = @c_sp_errmsg          OUTPUT
          , @c_TrackingNo              = @c_TrackingNumber     OUTPUT

      IF @b_sp_Success <> 1
      BEGIN
         SET @n_Continue = 3 
         SET @n_ErrNo = 53002
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sp_err) + ' : ' + CONVERT(CHAR(5),@n_ErrNo)
                       + '. Failed to get tracking number - ' + @c_sp_errmsg
         GOTO QUIT_SP
      END
   END

   IF @b_SkipOrderOutput <> 1
   BEGIN
      --INSERT INTO @t_PackTaskOrder( TaskBatchNo, OrderKey, DeviceOrderkey, [Status], INProgOrderkey, Color )
      EXEC [API].[isp_ECOMP_GetPackTaskOrders_M]  
            @c_TaskBatchNo    = @c_TaskBatchID
         ,  @c_PickSlipNo     = @c_PickSlipNo
         ,  @c_Orderkey       = @c_PHOrderKey      OUTPUT  
         ,  @b_packcomfirm    = 0
         ,  @c_DropID         = @c_DropID
         ,  @c_PTOJson        = @c_PTOJson         OUTPUT

      --SELECT TOP 1 
      --   @c_InProgOrderKey = ISNULL(RTRIM(INProgOrderkey), '')
      --FROM @t_PackTaskOrder
      --SELECT @c_PTOJson [@c_PTOJson]

      SELECT TOP 1 @c_InProgOrderKey = ISNULL(RTRIM(INProgOrderkey), '')  
      FROM OPENJSON(@c_PTOJson)
      WITH ( 
          INProgOrderkey    NVARCHAR(10)   '$.INProgOrderkey' 
      )
      --WHERE INProgOrderkey <> ''

      IF @c_PHOrderKey <> ''
      BEGIN
         --Get OrderInfo (BEGIN)
         EXEC [API].[isp_ECOMP_GetOrderInfo_v2] @c_Orderkey = @c_PHOrderKey, @c_OrderInfoJson = @c_OrderInfoJson OUTPUT
         --Get OrderInfo (END)
         EXEC [API].[isp_ECOMP_GetOrderStatus] 
              @c_Orderkey = @c_PHOrderKey
            , @c_OrderStatusJson = @c_OrderStatusJson OUTPUT
            , @c_PickSlipNo = @c_PickSlipNo  --Alex02
      END
   END

   SET @c_MultiPackResponse = ISNULL(( 
                                 SELECT @c_PickSlipNo          As 'PickSlipNo'
                                       ,@c_PackStatus          As 'PackStatus'
                                       ,@n_EstTotalCtn         As 'EstimateTotalCarton'
                                       ,@c_TrackingNumber      As 'TrackingNumber'
                                       ,(
                                          JSON_QUERY(@c_OrderInfoJson)
                                        ) AS 'OrderInfo'
                                       ,(
                                          JSON_QUERY(@c_OrderStatusJson)
                                        ) AS 'OrderStatusList'
                                       ,( 
                                          SELECT [PD].PickSlipNo                                As 'PickSlipNo'
                                                ,[PD].CartonNo                                  As 'CartonNo'
                                                ,CASE WHEN ([PI].[CartonNo] Is NULL) 
                                                      OR ([PI].[CartonNo] Is NULL AND [PD].CartonNo = 1)
                                                  THEN @c_TrackingNumber 
                                                  ELSE ISNULL(RTRIM([PI].TrackingNo), '') END   As 'TrackingNumber'
                                                ,ISNULL(RTRIM([PI].CartonType), '')             As 'CartonType'
                                                ,ISNULL(RTRIM([PI].[Weight]), '')               As 'Weight'
                                                ,CASE 
                                                   WHEN ISNULL([PI].PickSlipNo, '') <> '' THEN 1 
                                                   ELSE 0 
                                                 END                                            As 'CartonClosed'
                                                ,(
                                                   SELECT PD2.SKU                               As 'SKU'
                                                         ,PD2.QTY                               As 'QTY'
                                                         ,PD2.LOTTABLEVALUE                     As 'LottableValue'
                                                         ,S.STDGROSSWGT                         As 'STDGrossWeight'
                                                   FROM [dbo].[PackDetail] PD2 WITH (NOLOCK)
                                                   JOIN [dbo].[SKU] S WITH (NOLOCK) 
                                                   ON (PD2.PickSlipNo = [PD].PickSlipNo 
                                                      AND PD2.CartonNo = [PD].CartonNo
                                                      AND S.StorerKey = PD2.StorerKey
                                                      AND S.SKU = PD2.SKU )
                                                   WHERE PD2.PickSlipNo = [PD].PickSlipNo
                                                   AND [PD2].PickSlipNo <> ''
                                                   FOR JSON PATH
                                                 ) As 'CartonPackedSKU'
                                          FROM [dbo].[PackDetail] [PD] WITH (NOLOCK) 
                                          LEFT OUTER JOIN [dbo].[PackInfo] [PI] WITH (NOLOCK) 
                                          ON ([PI].PickSlipNo = [PD].PickSlipNo AND [PI].CartonNo = [PD].CartonNo)
                                          WHERE PD.PickSlipNo = @c_PickSlipNo
                                          AND PD.PickSlipNo <> ''
                                          GROUP BY [PD].PickSlipNo, [PD].CartonNo, [PI].TrackingNo, [PI].CartonType, [PI].[Weight], [PI].PickSlipNo, [PI].CartonNo
                                          FOR JSON PATH
                                        ) AS 'CartonPackedList'
                                       ,(
                                          --SELECT TaskBatchNo
                                          --      ,OrderKey
                                          --      ,DeviceOrderkey
                                          --      ,[Status]
                                          --      ,Color            As 'ColorCode'
                                          --FROM @t_PackTaskOrder
                                          --FOR JSON PATH 
                                          JSON_QUERY(@c_PTOJson)
                                        ) AS 'PackTaskOrders'
                                 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                              ), '')
   QUIT_SP:  
   IF @n_Continue= 3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_Success = 0      
      IF @@TRANCOUNT > @n_StartTCnt AND @@TRANCOUNT = 1 
      BEGIN               
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartTCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END   
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END
END -- procedure 
GO
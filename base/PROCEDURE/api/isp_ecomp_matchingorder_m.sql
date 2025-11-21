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
/* 5-Jul-2023     Alex     #JIRA PAC-7 Initial                          */  
/************************************************************************/      
CREATE   PROC [API].[isp_ECOMP_MatchingOrder_M](  
     @b_Debug                    INT            = 0  
   , @c_PickSlipNo               NVARCHAR(10)   = ''  
   , @b_IsPackConfirm            INT            = 0  
   , @c_TaskBatchID              NVARCHAR(10)   = ''  
   , @c_DropID                   NVARCHAR(20)   = ''  
   , @c_OrderKey                 NVARCHAR(10)   = ''  
   , @b_IsOrderMatch             INT            = 0   OUTPUT  
   , @c_AssignedOrderKey         NVARCHAR(10)   = ''  OUTPUT  
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
  
   DECLARE @c_Route                       NVARCHAR(10)   = ''   
         , @c_OrderRefNo                  NVARCHAR(50)   = ''   
         , @c_LoadKey                     NVARCHAR(10)   = ''   
         , @c_CartonGroup                 NVARCHAR(10)   = ''   
         , @c_ConsigneeKey                NVARCHAR(15)   = ''   
         , @n_CurCtnNo                    INT            = 0   
  
         , @c_PTOJson                     NVARCHAR(MAX)  = ''
      
   DECLARE @n_sp_Success                  INT            = 0  
         , @n_sp_err                      INT            = 0  
         , @c_sp_errmsg                   NVARCHAR(255)  = ''  
  
   --DECLARE @t_PackTaskOrder AS TABLE (  
   --      TaskBatchNo          NVARCHAR(10)      NULL  
   --   ,  OrderKey             NVARCHAR(10)      NULL  
   --   ,  DeviceOrderkey       NVARCHAR(20)      NULL  
   --   ,  [Status]             NVARCHAR(10)      NULL  
   --   ,  INProgOrderkey       NVARCHAR(20)      NULL  
   --   ,  Color                NVARCHAR(10)      NULL  
   --)  
  
   --SET @b_Success                         = 0  
   --SET @n_ErrNo                           = 0  
   --SET @c_ErrMsg                      = ''  
  
   --Matching Order (Begin)  
   SELECT @n_IsExists = (1)  
         , @c_PHOrderKey = ISNULL(RTRIM(OrderKey), '')  
   FROM [dbo].[PackHeader] WITH (NOLOCK)   
   WHERE PickSlipNo = @c_PickSlipNo  
  
   --SELECT @c_PHOrderKey [@c_PHOrderKey], @c_TaskBatchID [@c_TaskBatchID]  
   IF @c_PHOrderKey = ''  
   BEGIN  
      --INSERT INTO @t_PackTaskOrder (TaskBatchNo, OrderKey, DeviceOrderkey, [Status], INProgOrderkey, Color)  
      EXEC [API].[isp_ECOMP_GetPackTaskOrders_M]    
            @c_TaskBatchNo    = @c_TaskBatchID  
         ,  @c_PickSlipNo     = @c_PickSlipNo  
         ,  @c_Orderkey       = @c_PHOrderKey      OUTPUT    
         ,  @b_packcomfirm    = @b_IsPackConfirm  
         ,  @c_DropID         = @c_DropID  
         ,  @c_PTOJson        = @c_PTOJson         OUTPUT
  
      --match order after scan sku  
      IF @b_IsPackConfirm = 0  
      BEGIN  
         --SELECT @c_PHOrderKey = ISNULL(RTRIM(INProgOrderkey), '')  
         --FROM @t_PackTaskOrder  
         --WHERE INProgOrderkey <> ''  

         SELECT TOP 1 @c_PHOrderKey = ISNULL(RTRIM(INProgOrderkey), '')  
         FROM OPENJSON(@c_PTOJson)
         WITH ( 
             INProgOrderkey    NVARCHAR(10)   '$.InProgOrderkey' 
         )
         WHERE INProgOrderkey <> ''
      END  
  
      IF @c_PHOrderKey <> ''  
      BEGIN  
         SET @b_IsOrderMatch = 1  
  
         SELECT @c_Route         = ISNULL(RTRIM([Route]), '')  
               ,@c_OrderRefNo    = ISNULL(RTRIM([ExternOrderKey]), '')  
               ,@c_LoadKey       = ISNULL(RTRIM([LoadKey]), '')  
               ,@c_ConsigneeKey  = ISNULL(RTRIM([ConsigneeKey]), '')  
         FROM [dbo].[ORDERS] WITH (NOLOCK)  
         WHERE OrderKey = @c_PHOrderKey  
  
         UPDATE [dbo].[PackHeader] WITH (ROWLOCK)  
         SET [Route]        = @c_Route         
            ,[OrderKey]     = @c_PHOrderKey  
            ,[OrderRefNo]   = @c_OrderRefNo  
            ,[LoadKey]      = @c_LoadKey  
            ,[ConsigneeKey] = @c_ConsigneeKey  
         WHERE PickSlipNo = @c_PickSlipNo  
  
         IF EXISTS ( SELECT 1 FROM [dbo].[PackInfo] WITH (NOLOCK)   
            WHERE PickSlipNo = @c_PickSlipNo )  
         BEGIN  
            --Assign Tracking Number to Each Carton Packed.  
            DECLARE C_LOOP_PI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT CartonNo  
            FROM [dbo].[PackInfo] WITH (NOLOCK)   
            WHERE PickSlipNo = @c_PickSlipNo  
            OPEN C_LOOP_PI  
            FETCH NEXT FROM C_LOOP_PI INTO @n_CurCtnNo  
            WHILE @@FETCH_STATUS <> -1     
            BEGIN  
               SET @c_TrackingNumber = ''  
               EXEC [API].[isp_ECOMP_GetTrackingNumber]  
                    @b_Debug                   = @b_Debug  
                  , @c_PickSlipNo              = @c_PickSlipNo  
                  , @n_CartonNo                = @n_CurCtnNo  
                  , @c_TrackingNo              = @c_TrackingNumber     OUTPUT  
  
               IF @c_TrackingNumber <> ''   
               BEGIN  
                  UPDATE [dbo].[PackInfo] WITH (ROWLOCK)  
                  SET TrackingNo = @c_TrackingNumber  
                  WHERE PickSlipNo = @c_PickSlipNo  
                  AND CartonNo = @n_CurCtnNo  
               END  
  
               FETCH NEXT FROM C_LOOP_PI INTO @n_CurCtnNo  
            END -- WHILE @@FETCH_STATUS <> -1     
            CLOSE C_LOOP_PI    
            DEALLOCATE C_LOOP_PI  
         END  
      END  
   END  
   SET @c_AssignedOrderKey = @c_PHOrderKey  
   --Assign Order (End)  
  
   QUIT:  
   IF @n_Continue= 3  -- Error Occured - Process And Return        
   BEGIN        
      --SET @b_Success = 0        
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
      --SELECT @b_Success = 1        
      WHILE @@TRANCOUNT > @n_StartCnt        
      BEGIN        
         COMMIT TRAN        
      END        
      RETURN        
   END  
END -- Procedure    
GO
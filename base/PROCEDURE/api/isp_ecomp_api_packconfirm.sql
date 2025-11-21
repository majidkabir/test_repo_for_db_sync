SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_PackConfirm]                   */              
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
CREATE   PROC [API].[isp_ECOMP_API_PackConfirm](
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
         , @c_NewPickSlipNo               NVARCHAR(10)   = ''

         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_SKU                         NVARCHAR(20)   = ''
         , @c_Facility                    NVARCHAR(15)   = ''

   DECLARE 
           @n_CartonNo                    INT            = 0
         , @c_TrackingNumber              NVARCHAR(40)   = ''
         , @n_SumQty                      INT            = 0
         , @f_Weight                      FLOAT          = 0
         , @c_CartonGroup                 NVARCHAR(10)   = ''
         , @c_CartonType                  NVARCHAR(10)   = ''
         , @f_Cube                        FLOAT
         , @f_CartonLength                FLOAT
         , @f_CartonWidth                 FLOAT
         , @f_CartonHeight                FLOAT 

         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)  = ''

   DECLARE @c_PH_TaskBatchID              NVARCHAR(10)   = ''
         , @c_PH_OrderKey                 NVARCHAR(10)   = ''
         , @c_OrderMode                   NVARCHAR(1)    = ''
         , @c_PackStatus                  NVARCHAR(1)    = ''

         , @b_IsOrderMatch                INT            = 0

   DECLARE @c_MultiPackResponse           NVARCHAR(MAX)  = ''
         , @c_InProgOrderKey              NVARCHAR(10)   = ''

         , @b_AnyPendingBatchTasks        BIT            = 0

         , @c_PackUpdateEstTotalCtn       NVARCHAR(1)    = ''
         , @n_EstimateTotalCtn            INT            = 0
         , @n_TotalCarton                 INT            = 0
         , @b_ReprintCtnLabel             BIT            = 0

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

   DECLARE @t_CartonTypes AS TABLE (
      CartonizationKey  NVARCHAR(10)   NULL,
      CartonType        NVARCHAR(10)   NULL,
      [Cube]            FLOAT          NULL,
      MaxWeight         INT            NULL,
      MaxCount          INT            NULL,
      CartonWeight      FLOAT          NULL,
      CartonLength      FLOAT          NULL, 
      CartonWidth       FLOAT          NULL,
      CartonHeight      FLOAT          NULL,
      Alert             NVARCHAR(255)  NULL
   )

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = '{}'

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
         --,@c_StorerKey        = ISNULL(RTRIM(StorerKey      ), '')
         ,@n_CartonNo         = ISNULL(RTRIM(CartonNo       ), '')
         ,@c_TrackingNumber   = ISNULL(RTRIM(TrackingNumber ), '')
         ,@c_CartonType       = ISNULL(RTRIM(CartonType     ), '')
         ,@f_Weight           = ISNULL(RTRIM([Weight]       ), 0)
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      PickSlipNo        NVARCHAR(10)       '$.PickSlipNo',
      TaskBatchID       NVARCHAR(10)       '$.TaskBatchID',
      DropID            NVARCHAR(20)       '$.DropID',
      OrderKey          NVARCHAR(10)       '$.OrderKey',
      --StorerKey         NVARCHAR(15)       '$.StorerKey',
      CartonNo          INT                '$.CartonNo',
      TrackingNumber    NVARCHAR(40)       '$.TrackingNumber',
      CartonType        NVARCHAR(10)       '$.CartonType',
      [Weight]          FLOAT              '$.Weight'
   )

   IF @c_PickSlipNo <> ''
   BEGIN
      SELECT @c_PH_TaskBatchID   = ISNULL(RTRIM(TaskBatchNo), '')
            ,@c_PH_OrderKey      = ISNULL(RTRIM(OrderKey), '')
            ,@c_StorerKey        = ISNULL(RTRIM(StorerKey), '')
            ,@n_EstimateTotalCtn = ISNULL(EstimateTotalCtn, 0)
      FROM [dbo].[PackHeader] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      SELECT @c_Facility = ISNULL(RTRIM(Facility), '')
      FROM [dbo].[ORDERS] WITH (NOLOCK) 
      WHERE OrderKey = @c_PH_OrderKey

      EXEC [API].[isp_ECOMP_GetOrderMode]
        @b_Debug            = @b_Debug
      , @c_TaskBatchID      = @c_PH_TaskBatchID OUTPUT
      , @c_DropID           = ''
      , @c_OrderKey         = @c_PH_OrderKey
      , @b_Success          = @b_sp_Success     OUTPUT
      , @n_ErrNo            = @n_sp_err         OUTPUT
      , @c_ErrMsg           = @c_sp_errmsg      OUTPUT
      , @c_OrderMode        = @c_OrderMode      OUTPUT


      IF @c_OrderMode = 'S'
      BEGIN
         SELECT @n_SumQty = SUM(Qty) 
         FROM dbo.PackDetail (NOLOCK) 
         WHERE PickSlipNo = @c_PickSlipNo 
         AND CartonNo = @n_CartonNo

         IF @c_CartonType <> ''
         BEGIN
            --SELECT @c_CartonGroup = CartonGroup 
            --FROM dbo.STORER WITH (NOLOCK) 
            --WHERE StorerKey = @c_StorerKey

            --SELECT @f_Cube = [Cube]
            --      ,@f_CartonLength = CartonLength
            --      ,@f_CartonWidth = CartonWidth
            --      ,@f_CartonHeight = CartonHeight
            --FROM [dbo].[Cartonization] ctn WITH (NOLOCK)
            --WHERE CartonizationGroup = @c_CartonGroup
            --AND CartonType = @c_CartonType
            INSERT INTO @t_CartonTypes
            EXEC [API].[isp_ECOMP_GetPackCartonType]
                 @c_Facility     = @c_Facility
               , @c_Storerkey    = @c_Storerkey
               , @c_CartonType   = @c_CartonType
               , @c_CartonGroup  = ''
               , @c_PickSlipNo   = @c_PickSlipNo
               , @n_CartonNo     = @n_CartonNo
               , @c_SourceApp    = 'SCE'

            SELECT @f_Cube = [Cube]
                  ,@f_CartonLength = CartonLength
                  ,@f_CartonWidth = CartonWidth
                  ,@f_CartonHeight = CartonHeight
            FROM @t_CartonTypes
         END

         IF NOT EXISTS ( SELECT 1 FROM [dbo].[PackInfo] WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CartonNo)
         BEGIN
            INSERT INTO [dbo].[PackInfo] (PickSlipNo, CartonNo, Qty, TrackingNo, CartonType, [Cube], [Length], [Weight], Width, Height)
            VALUES (@c_PickSlipNo, @n_CartonNo, @n_SumQty, @c_TrackingNumber, @c_CartonType, @f_Cube, @f_CartonLength, @f_Weight, @f_CartonWidth, @f_CartonHeight)
         END
         ELSE
         BEGIN
            UPDATE [dbo].[PackInfo] WITH (ROWLOCK)
            SET [Qty] = @n_SumQty
               ,[TrackingNo] = @c_TrackingNumber
               ,CartonType = @c_CartonType
               ,[Cube] = @f_Cube
               ,[Length] = @f_CartonLength
               ,[Weight] = @f_Weight
               ,Width = @f_CartonWidth
               ,Height = @f_CartonHeight
            WHERE PickSlipNo = @c_PickSlipNo 
            AND CartonNo = @n_CartonNo
         END

         SET @b_sp_Success = 0
         SET @n_sp_err     = 0
         SET @c_sp_errmsg  = ''

         EXEC [API].[isp_ECOMP_PackSaveEnd]
              @c_PickSlipNo         = @c_PickSlipNo        
            , @c_Orderkey           = @c_OrderKey
            , @n_SaveResult         = '1'                   
            , @c_SaveEndValidation  = 'Y'         
            , @b_Success            = @b_sp_Success  OUTPUT        
            , @n_Err                = @n_sp_err      OUTPUT        
            , @c_ErrMsg             = @c_sp_errmsg   OUTPUT

         IF @b_sp_Success <> 1
         BEGIN
            SET @n_Continue = 3      
            SET @n_ErrNo = 51910      
            SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                          + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
            GOTO QUIT  
         END
            
         SET @b_sp_Success = 0
         SET @n_sp_err     = 0
         SET @c_sp_errmsg  = ''
         SET @c_NewPickSlipNo = @c_PickSlipNo

         EXEC [API].[isp_ECOMP_PackConfirm]
               @c_PickSlipNo     = @c_NewPickSlipNo   OUTPUT        
            ,  @b_Success        = @b_sp_Success      OUTPUT   
            ,  @n_err            = @n_sp_err          OUTPUT   
            ,  @c_errmsg         = @c_sp_errmsg       OUTPUT  

         IF @b_sp_Success <> 1
         BEGIN
            SET @n_Continue = 3      
            SET @n_ErrNo = 51911      
            SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                          + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
            GOTO QUIT  
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

         SET @c_ResponseString = ISNULL(( 
                                    SELECT CAST ( 1 AS BIT )         AS 'Success',
                                       @c_NewPickSlipNo              AS 'PickSlipNo',
                                       (
                                          JSON_QUERY((
                                             SELECT TotalOrder       AS 'TotalOrders'
                                                   ,PendingOrder     AS 'TotalPendingOrders'
                                                   ,PackedOrder      AS 'TotalPackedOrders'
                                                   ,CancelledOrder   AS 'TotalCancOrders'
                                                   ,InProgOrderKey   AS 'LastOrderID'
                                             FROM @t_PackTaskOrderSts
                                          FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                                          ))
                                       ) As 'PackTaskOrdersCount' 
                                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                                 ), '')
      END -- @c_OrderMode = 'S' end
      ELSE IF @c_OrderMode = 'M'
      BEGIN
         SET @b_sp_Success = 0
         SET @n_sp_err     = 0
         SET @c_sp_errmsg  = ''

         EXEC [API].[isp_ECOMP_PackSaveEnd]
              @c_PickSlipNo         = @c_PickSlipNo        
            , @c_Orderkey           = @c_OrderKey
            , @n_SaveResult         = '1'                   
            , @c_SaveEndValidation  = 'Y'         
            , @b_Success            = @b_sp_Success  OUTPUT        
            , @n_Err                = @n_sp_err      OUTPUT        
            , @c_ErrMsg             = @c_sp_errmsg   OUTPUT

         IF @b_sp_Success <> 1
         BEGIN
            SET @n_Continue = 3      
            SET @n_ErrNo = 51911      
            SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                          + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
            GOTO QUIT  
         END
            
         SET @b_sp_Success = 0
         SET @n_sp_err     = 0
         SET @c_sp_errmsg  = ''
         SET @c_NewPickSlipNo = @c_PickSlipNo

         EXEC [API].[isp_ECOMP_PackConfirm]
               @c_PickSlipNo     = @c_NewPickSlipNo   OUTPUT        
            ,  @b_Success        = @b_sp_Success      OUTPUT   
            ,  @n_err            = @n_sp_err          OUTPUT   
            ,  @c_errmsg         = @c_sp_errmsg       OUTPUT  

         IF @b_sp_Success <> 1
         BEGIN
            SET @n_Continue = 3      
            SET @n_ErrNo = 51912      
            SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                          + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
            GOTO QUIT  
         END

         SET @c_PackUpdateEstTotalCtn = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PackUpdateEstTotalCtn')

         IF @c_PackUpdateEstTotalCtn = '1'
         BEGIN
            SELECT @n_TotalCarton = ISNULL(MAX(CartonNo), 0)
            FROM [dbo].[PackDetail] WITH (NOLOCK) 
            WHERE PickSlipNo = @c_NewPickSlipNo

            IF @n_TotalCarton <> @n_EstimateTotalCtn
            BEGIN
               UPDATE [dbo].[PackHeader] WITH (ROWLOCK)
               SET EstimateTotalCtn = @n_TotalCarton
               WHERE PickSlipNo = @c_NewPickSlipNo

               SET @b_ReprintCtnLabel = 1
            END
         END

         EXEC [API].[isp_ECOMP_GetMultiPackTaskResponse] 
           @c_PickSlipNo            = @c_NewPickSlipNo
         , @c_TaskBatchID           = @c_PH_TaskBatchID 
         , @c_OrderKey              = @c_OrderKey
         , @c_DropID                = @c_DropID
         , @c_MultiPackResponse     = @c_MultiPackResponse     OUTPUT
         , @c_InProgOrderKey        = @c_InProgOrderKey        OUTPUT

         -- If got scan task batch no, check if any pending task leftover
         IF @c_TaskBatchID <> ''
         BEGIN
            IF EXISTS ( SELECT 1 FROM [dbo].[PackTaskDetail] WITH (NOLOCK) WHERE TaskBatchNo = @c_TaskBatchID AND [Status] = '0')
            BEGIN
               SET @b_AnyPendingBatchTasks = 1
            END
         END

         SET @c_ResponseString = ISNULL(( 
                                    SELECT CAST ( 1 AS BIT )         AS 'Success'
                                          --,@c_NewPickSlipNo          AS 'PickSlipNo'
                                          --,@c_InProgOrderKey         AS 'LastOrderID'
                                          , @b_AnyPendingBatchTasks  As 'AnyPendingBatchTasks'
                                          , @b_ReprintCtnLabel       As 'ReprintCtnLabel'
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
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_AssignOrder_M]                 */              
/* Creation Date: 05-Jul-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: Allen                                                    */
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
/* 05-Jul-2023    Allen    #JIRA PAC-7 Initial                          */
/* 09-Jul-2024    Alex01   #PAC-353 Bundle Packing Validation           */
/************************************************************************/
CREATE   PROC [API].[isp_ECOMP_API_AssignOrder_M](
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
         , @c_IsSelectOrderKey            NVARCHAR(10)   = ''
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
         , @c_NewOrderKey                 NVARCHAR(10)   = ''
         , @c_ExistingOrderKey            NVARCHAR(10)   = ''

         , @c_NewTaskBatchID              NVARCHAR(10)   = ''
         , @c_ExistingTaskBatchID         NVARCHAR(10)   = ''

         , @n_LastCartonNo                INT            = 0
         , @n_CurCtnNo                    INT            = 0
         , @c_PackStatus                  NVARCHAR(1)    = ''

         , @c_EpackForceMultiPackByOrd    NVARCHAR(1)    = ''
         , @c_TrackingNumber              NVARCHAR(40)   = ''

         , @c_DefaultCartonType           NVARCHAR(10)   = ''
         , @c_DefaultCartonGroup          NVARCHAR(10)   = ''
         , @b_AutoCloseCarton             INT            = 0
         , @f_CartonWeight                FLOAT          = 0

         , @c_SerialNo                    NVARCHAR(60)   = ''
         , @c_InPickSlipNo                NVARCHAR(10)   = ''

   DECLARE @c_MultiPackResponse           NVARCHAR(MAX)  = NULL
         , @c_InProgOrderKey              NVARCHAR(10)   = ''  

   DECLARE @c_Route                       NVARCHAR(10)   = '' 
         , @c_OrderRefNo                  NVARCHAR(50)   = '' 
         , @c_LoadKey                     NVARCHAR(10)   = '' 
         , @c_CartonGroup                 NVARCHAR(10)   = '' 
         , @c_ConsigneeKey                NVARCHAR(15)   = '' 
         , @b_PackConfirm                 INT            = 0

         , @c_TrackingNo                  NVARCHAR(40)   = ''
         , @c_SOStatus                    NVARCHAR(60)   = ''
         , @c_Status                      NVARCHAR(60)   = ''

         , @b_IsOrderMatch                INT            = 0

   DECLARE @n_sc_Success                  INT            = 0
         , @n_sc_err                      INT            = 0
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

   SELECT @c_PickSlipNo       = ISNULL(RTRIM(PickSlipNo  ), '')
         ,@c_StorerKey        = ISNULL(RTRIM(StorerKey   ), '')
         ,@c_Facility         = ISNULL(RTRIM(Facility    ), '')
         ,@c_NewOrderKey      = ISNULL(RTRIM(NewOrderKey ), '')
         ,@c_ComputerName     = ISNULL(RTRIM(ComputerName), '')
         ,@b_PackConfirm      = ISNULL(IsPackConfirm      , 0)
   FROM OPENJSON (@c_RequestString)
   WITH ( 
       PickSlipNo          NVARCHAR(10)   '$.PickSlipNo'
      ,StorerKey           NVARCHAR(15)   '$.StorerKey' 
      ,Facility            NVARCHAR(15)   '$.Facility'
      ,NewOrderKey         NVARCHAR(10)   '$.NewOrderKey'
      ,ComputerName        NVARCHAR(30)   '$.ComputerName'  
      ,IsPackConfirm       INT            '$.IsPackConfirm'  
   )
   
   IF @b_Debug = 1
   BEGIN
       PRINT 'AssignOrder_M Start......... '
       PRINT '>>>>>>>>> Request data '
       PRINT '@c_PickSlipNo      = ' + @c_PickSlipNo
       PRINT '@c_StorerKey       = ' + @c_StorerKey
       PRINT '@c_Facility        = ' + @c_Facility
       PRINT '@c_NewOrderKey     = ' + @c_NewOrderKey
       PRINT '@c_ComputerName    = ' + @c_ComputerName
       PRINT '@b_PackConfirm     = ' + CONVERT(NVARCHAR(1), @b_PackConfirm)
   END

   SET @c_InPickSlipNo = @c_PickSlipNo

   IF @c_NewOrderKey = '' AND @b_PackConfirm = 0
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 51801
      SET @c_ErrMsg = 'No OrderKey found.'
      GOTO QUIT
   END

   

   IF @c_PickSlipNo <> ''
   BEGIN
      SELECT @n_IsExists = (1)
            ,@c_PackStatus = ISNULL(RTRIM([Status]), '')
            ,@c_ExistingOrderKey = ISNULL(RTRIM(OrderKey), '')
            ,@c_ExistingTaskBatchID = ISNULL(RTRIM(TaskBatchNo), '')
      FROM [dbo].[PackHeader] WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
   END
   ELSE 
   BEGIN
      SELECT @c_PickSlipNo = ISNULL(RTRIM(PickSlipNo), '')
      FROM [dbo].PACKTASKDETAIL WITH (NOLOCK)
      WHERE OrderKey = @c_NewOrderKey

      IF @c_PickSlipNo <> ''
      BEGIN
         SELECT @n_IsExists = (1)
               ,@c_PackStatus = ISNULL(RTRIM([Status]), '')
               ,@c_ExistingOrderKey = ISNULL(RTRIM(OrderKey), '')
               ,@c_ExistingTaskBatchID = ISNULL(RTRIM(TaskBatchNo), '')
         FROM [dbo].[PackHeader] WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
      END
   END

   SELECT TOP 1
      @c_NewTaskBatchID = ISNULL(RTRIM(TaskBatchNo), '')
   FROM [dbo].[PACKTASKDETAIL] WITH (NOLOCK) 
   WHERE OrderKey = @c_NewOrderKey

   IF @b_Debug = 1
   BEGIN
       PRINT '>>>>>>>>> PackHeader'
       PRINT '@n_IsExists              = ' + CAST(@n_IsExists AS NVARCHAR(5))
       PRINT '@c_PickSlipNo            = ' + @c_PickSlipNo
       PRINT '@c_PackStatus            = ' + @c_PackStatus
       PRINT '@c_ExistingOrderKey      = ' + @c_ExistingOrderKey
       PRINT '@c_ExistingTaskBatchID   = ' + @c_ExistingTaskBatchID
       PRINT '@c_NewTaskBatchID        = ' + @c_NewTaskBatchID
   END

   --IF @n_IsExists = 0
   --BEGIN
   --   SET @n_Continue = 3 
   --   SET @n_ErrNo = 51802
   --   SET @c_ErrMsg = 'Invalid PickSlipNo - ' + @c_PickSlipNo
   --   GOTO QUIT
   --END

   IF @n_IsExists = 1
   BEGIN
      --IF @c_PackStatus <> '0'
      --BEGIN
      --   SET @n_Continue = 3 
      --   SET @n_ErrNo = 51803
      --   SET @c_ErrMsg = 'Not allowed to change PackHeader with Status(' + @c_PackStatus + ')..'
      --   GOTO QUIT
      --END

      IF @c_PackStatus = '0'
      BEGIN
         IF @b_PackConfirm = 1 AND @c_ExistingOrderKey = ''
         BEGIN
            --Auto Match OrderKey
            EXEC [API].[isp_ECOMP_MatchingOrder_M]
                 @b_Debug                    = @b_Debug
               , @c_PickSlipNo               = @c_PickSlipNo
               , @b_IsPackConfirm            = 1
               , @c_TaskBatchID              = @c_ExistingTaskBatchID
               , @c_DropID                   = @c_DropID
               , @c_OrderKey                 = ''
               , @b_IsOrderMatch             = @b_IsOrderMatch         OUTPUT
               , @c_AssignedOrderKey         = @c_NewOrderKey          OUTPUT
            
            IF @b_IsOrderMatch = 0
            BEGIN
               SET @n_Continue = 3      
               SET @n_ErrNo = 51805      
               SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': No orderkey can be match.'  
               GOTO QUIT  
            END

            SELECT TOP 1
               @c_NewTaskBatchID = ISNULL(RTRIM(TaskBatchNo), '')
            FROM [dbo].[PACKTASKDETAIL] WITH (NOLOCK) 
            WHERE OrderKey = @c_NewOrderKey
         END
         --IF @c_NewOrderKey = @c_ExistingOrderKey
         --BEGIN
         --   SET @n_Continue = 3 
         --   SET @n_ErrNo = 51804
         --   SET @c_ErrMsg = 'Unable to assign existing orderkey.'
         --   GOTO QUIT
         --END
      
         SELECT @c_StorerKey = [StorerKey] 
               ,@c_Facility = Facility
         FROM [dbo].[ORDERS] WITH (NOLOCK) 
         WHERE OrderKey = CASE WHEN @c_ExistingOrderKey = '' THEN @c_ExistingOrderKey ELSE @c_NewOrderKey END
      
         SET @c_EpackForceMultiPackByOrd = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EpackForceMultiPackByOrd')  
      
         IF @c_EpackForceMultiPackByOrd = '1' AND @c_InPickSlipNo <> ''
         BEGIN
            SET @n_Continue = 3 
            SET @n_ErrNo = 51806
            SET @c_ErrMsg = 'You are not allowed to switch other order key..'
            GOTO QUIT
         END

         IF @c_ExistingTaskBatchID <> @c_NewTaskBatchID
         BEGIN
            SET @n_Continue = 3 
            SET @n_ErrNo = 51807
            SET @c_ErrMsg = 'You are not allowed to switch other task batch no..'
            GOTO QUIT
         END
      
         IF @c_NewOrderKey <> @c_ExistingOrderKey AND NOT ( @b_PackConfirm = 1 AND @b_IsOrderMatch = 1)
         BEGIN
            --Alex01 Start
            SET @b_sp_Success = 0
            EXEC [API].[isp_ECOMP_BundlePackingValidation_Wrapper]
                  @b_Debug          = @b_Debug
               ,  @c_PickSlipNo     = @c_PickSlipNo
               ,  @n_CartonNo       = 1
               ,  @c_OrderKey       = @c_ExistingOrderKey
               ,  @c_Storerkey      = @c_Storerkey
               ,  @c_SKU            = ''
               ,  @c_Type           = 'CHANGEORDER'
               ,  @b_Success        = @b_sp_Success   OUTPUT  
               ,  @n_Err            = @n_sp_err       OUTPUT  
               ,  @c_ErrMsg         = @c_sp_errmsg    OUTPUT  

            IF @b_sp_Success = 0
            BEGIN
               SET @n_Continue = 3 
               SET @n_ErrNo = 51810
               SET @c_ErrMsg = CONVERT(CHAR(5),@n_sp_err) + ' : ' + @c_sp_errmsg
               GOTO QUIT
            END
            --Alex01 End
            
            EXEC [API].[isp_ECOMP_QueryRules]   
               @c_TaskID         = @c_NewTaskBatchID     OUTPUT 
            ,  @c_PickSlipNo     = @c_PickSlipNo  
            ,  @c_Orderkey       = @c_NewOrderKey        OUTPUT 
            ,  @c_UserID         = @c_UserID
            ,  @c_ComputerName   = @c_ComputerName
            ,  @b_Success        = @b_sp_Success         OUTPUT -- -1:Fail, 0:No Work, 1:Perform Search/addnew, 2:Set Orderkey  
            ,  @c_ErrMsg         = @c_sp_errmsg          OUTPUT  
      
            IF @b_sp_Success < 1
            BEGIN
               SET @n_Continue = 3 
               SET @n_ErrNo = 51808
               SET @c_ErrMsg = CONVERT(CHAR(5),@n_sp_err) + ' : ' + CONVERT(CHAR(5),@n_ErrNo)
                             + '. Failed to get validate query rules - ' + @c_sp_errmsg
               GOTO QUIT
            END
      
            SELECT @c_Route         = ISNULL(RTRIM([Route]), '')
                  ,@c_OrderRefNo    = ISNULL(RTRIM([ExternOrderKey]), '')
                  ,@c_LoadKey       = ISNULL(RTRIM([LoadKey]), '')
                  ,@c_ConsigneeKey  = ISNULL(RTRIM([ConsigneeKey]), '')
            FROM [dbo].[ORDERS] WITH (NOLOCK)
            WHERE OrderKey = @c_NewOrderKey
      
            --update orderkey into packheader
            UPDATE [dbo].[PackHeader] WITH (ROWLOCK)
            SET [Route]        = @c_Route       
               ,[OrderKey]     = @c_NewOrderKey
               ,[OrderRefNo]   = @c_OrderRefNo
               ,[LoadKey]      = @c_LoadKey
               ,[ConsigneeKey] = @c_ConsigneeKey
            WHERE PickSlipNo = @c_PickSlipNo

            IF EXISTS ( SELECT 1 FROM [dbo].[PackInfo] WITH (NOLOCK) 
               WHERE PickSlipNo = @c_PickSlipNo )
            BEGIN
               --Assign Tracking Number to Each Carton Packed.
               DECLARE C_LOOP_AORD_PI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT CartonNo
               FROM [dbo].[PackInfo] WITH (NOLOCK) 
               WHERE PickSlipNo = @c_PickSlipNo
               OPEN C_LOOP_AORD_PI
               FETCH NEXT FROM C_LOOP_AORD_PI INTO @n_CurCtnNo
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

                  FETCH NEXT FROM C_LOOP_AORD_PI INTO @n_CurCtnNo
               END -- WHILE @@FETCH_STATUS <> -1   
               CLOSE C_LOOP_AORD_PI  
               DEALLOCATE C_LOOP_AORD_PI
            END

            SET @c_TrackingNumber = ''
            SELECT @n_LastCartonNo = ISNULL(MAX(CartonNo), 1)
            FROM [dbo].[PackInfo] WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo

            --Get Tracking Number For Next Carton If ANY
            EXEC [API].[isp_ECOMP_GetTrackingNumber]
                 @b_Debug                   = @b_Debug
               , @c_PickSlipNo              = @c_PickSlipNo
               , @n_CartonNo                = @n_LastCartonNo
               , @b_Success                 = @b_sp_Success         OUTPUT
               , @n_ErrNo                   = @n_sp_err             OUTPUT
               , @c_ErrMsg                  = @c_sp_errmsg          OUTPUT
               , @c_TrackingNo              = @c_TrackingNumber     OUTPUT

            IF @b_sp_Success <> 1
            BEGIN
               SET @n_Continue = 3 
               SET @n_ErrNo = 51809
               SET @c_ErrMsg = CONVERT(CHAR(5),@n_sp_err) + ' : ' + CONVERT(CHAR(5),@n_ErrNo)
                             + '. Failed to get tracking number - ' + @c_sp_errmsg
               GOTO QUIT
            END
         END -- IF @c_NewOrderKey = @c_ExistingOrderKey
      END -- IF @c_PackStatus = '0'
   END --IF @n_IsExists = 1

   EXEC [API].[isp_ECOMP_GetMultiPackTaskResponse] 
           @c_PickSlipNo            = @c_PickSlipNo  
         , @c_TaskBatchID           = @c_NewTaskBatchID 
         , @c_OrderKey              = @c_NewOrderKey    
         , @c_DropID                = @c_DropID
         , @c_MultiPackResponse     = @c_MultiPackResponse     OUTPUT
         , @c_InProgOrderKey        = @c_InProgOrderKey        OUTPUT

   SET @c_ResponseString = ISNULL(( 
                              SELECT @c_PickSlipNo             As 'PickSlipNo'
                                    ,@c_TrackingNumber         As 'TrackingNumber'
                                    ,@c_InProgOrderKey         As 'LastOrderID'
                                    ,(
                                       JSON_QUERY(@c_MultiPackResponse)
                                     ) As 'MultiPackTask'
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
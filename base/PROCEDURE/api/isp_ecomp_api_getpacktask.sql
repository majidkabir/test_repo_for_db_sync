SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_GetPackTask]                   */              
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
/* 26-Dec-2023    Alex01   #PAC-308                                     */  
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_API_GetPackTask](
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
         
         
         , @c_UR_StorerKey                NVARCHAR(15)   = ''
         , @c_UR_Facility                 NVARCHAR(15)   = ''
         , @c_SKU                         NVARCHAR(20)   = ''
         , @c_TaskBatchID                 NVARCHAR(10)   = ''
         , @c_DropID                      NVARCHAR(20)   = ''
         , @c_OrderKey                    NVARCHAR(10)   = ''
         , @c_ComputerName                NVARCHAR(30)   = ''
         , @n_IsExists                    INT            = 0

         , @n_TotalCarton                 INT            = 0
         , @n_CartonNo                    INT            = 0
         
         , @c_1stOrderKey                 NVARCHAR(10)   = ''
         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_Facility                    NVARCHAR(15)   = ''

         , @c_OrderMode                   NVARCHAR(1)    = ''
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


         , @c_SQLQuery                    NVARCHAR(MAX)  = ''
         , @c_SQLWhereClause              NVARCHAR(2000) = ''
         , @c_SQLParams                   NVARCHAR(2000) = ''

         , @b_IsWhereClauseExists         INT            = 0

         , @b_SearchBatchIDOnly           INT            = 0

   DECLARE @c_PickSlipNo                  NVARCHAR(10)   = ''
         , @c_PackOrderKey                NVARCHAR(10)   = ''
         , @c_PackAddWho                  NVARCHAR(128)  = ''
         , @c_PackComputerName            NVARCHAR(30)   = ''
         , @c_PackIsExists                INT            = 0
         , @c_PackStatus                  NVARCHAR(1)    = ''

         , @b_IsSerialNoMandatory         INT            = 0
         , @b_IsPackQRFMandatory          INT            = 0
         , @b_IsTrackingNoMandatory       INT            = 0
         , @b_IsCartonTypeMandatory       INT            = 0
         , @b_IsWeightMandatory           INT            = 0
         , @b_IsAutoWeightCalc            INT            = 0
         , @b_IsAutoPackConfirm           INT            = 0

         , @c_PackQRF_RegEx               NVARCHAR(200)  = ''

         , @c_InnerJson                   NVARCHAR(MAX)  = NULL
         , @c_OrderStatusJson             NVARCHAR(MAX)  = NULL
         
         , @c_DefaultCartonType           NVARCHAR(10)   = ''
         , @c_DefaultCartonGroup          NVARCHAR(10)   = ''
         , @b_AutoCloseCarton             INT            = 0
         , @f_CartonWeight                FLOAT          = 0

         , @b_IsLabelNoCaptured           INT            = 0
         , @c_PackQRF_QRCode              NVARCHAR(100)  = ''
         , @c_TaskBatchID_ToDisplay       NVARCHAR(10)   = ''
         , @c_OrderKey_ToDisplay          NVARCHAR(10)   = ''

   DECLARE @c_SerialNo                    NVARCHAR(30)   = ''
         , @c_TrackingNo                  NVARCHAR(40)   = ''
         , @f_Weight                      FLOAT          = 0
         , @c_CartonType                  NVARCHAR(10)   = ''

         , @c_SOStatus                    NVARCHAR(60)   = ''
         , @c_Status                      NVARCHAR(60)   = ''

         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)= ''

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
   )

   DECLARE @t_PackingRules AS TABLE (
         RuleName          NVARCHAR(60)   NULL
      ,  [Value]           NVARCHAR(120)  NULL
   )

   DECLARE @t_PendingTasks AS TABLE (
         PackIsExists                INT            NULL
      ,  PickSlipNo                  NVARCHAR(10)   NULL
      ,  PackOrderKey                NVARCHAR(10)   NULL
      ,  PackComputerName            NVARCHAR(30)   NULL
      ,  PackAddWho                  NVARCHAR(128)  NULL 
      ,  PackStatus                  NVARCHAR(1)    NULL
   )

   DECLARE @t_SkipTasks AS TABLE (
         PickSlipNo                  NVARCHAR(10)   NULL
   )

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

   SELECT @c_UR_StorerKey  = ISNULL(RTRIM(StorerKey   ), '')
         ,@c_UR_Facility   = ISNULL(RTRIM(Facility    ), '')
         ,@c_TaskBatchID   = ISNULL(RTRIM(TaskBatchID ), '')
         ,@c_DropID        = ISNULL(RTRIM(DropID      ), '')
         ,@c_OrderKey      = ISNULL(RTRIM(OrderKey    ), '')
         ,@c_ComputerName  = ISNULL(RTRIM(ComputerName), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
       StorerKey     NVARCHAR(15)   '$.StorerKey' 
      ,Facility      NVARCHAR(15)   '$.Facility'
      ,TaskBatchID   NVARCHAR(10)   '$.TaskBatchID'
      ,DropID        NVARCHAR(20)   '$.DropID'     
      ,OrderKey      NVARCHAR(10)   '$.OrderKey'  
      ,ComputerName  NVARCHAR(30)   '$.ComputerName'  
   )

   IF @c_TaskBatchID = '' AND @c_OrderKey = '' AND @c_DropID = ''
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 51002
      SET @c_ErrMsg = 'TaskBatchID/OrderKey/DropID cannot be null'
      GOTO QUIT
   END

   EXEC [API].[isp_ECOMP_QueryRules]   
         @c_PickSlipNo     = @c_PickSlipNo   
        ,@c_UserID         = @c_UserID       
        ,@c_ComputerName   = @c_ComputerName 
        ,@b_Success        = @b_Success       OUTPUT 
        ,@c_ErrMsg         = @c_ErrMsg        OUTPUT  
        ,@c_TaskID         = @c_TaskBatchID   OUTPUT   
        ,@c_Orderkey       = @c_Orderkey      OUTPUT 
        ,@c_DropID         = @c_DropID 

   IF @b_Success < 1
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 51003
      GOTO QUIT
   END

   SET @n_IsExists = 0
   SET @b_IsWhereClauseExists = 0

   --Search For PackTask (Begin)
   IF @c_TaskBatchID <> ''
   BEGIN
      SET @c_SQLWhereClause = @c_SQLWhereClause 
                            + 'WHERE TaskBatchNo = @c_TaskBatchID ' + CHAR(13)
      SET @b_IsWhereClauseExists = 1
   END
   
   IF @c_OrderKey <> ''
   BEGIN
      SET @c_SQLWhereClause =  @c_SQLWhereClause
                      + CASE WHEN @b_IsWhereClauseExists = 0 THEN 'WHERE' ELSE 'AND' END
                      + ' OrderKey = @c_OrderKey ' + CHAR(13)
      SET @b_IsWhereClauseExists = 1
   END

   IF @c_DropID <> ''
   BEGIN
       IF @c_TaskBatchID = ''   
       BEGIN
          SET @c_SQLWhereClause = @c_SQLWhereClause 
                          + CASE WHEN @b_IsWhereClauseExists = 0 THEN 'WHERE' ELSE 'AND' END
                          + ' EXISTS ( SELECT 1  ' + CHAR(13) 
                          + '    FROM [dbo].[PickDetail] pic WITH (NOLOCK) ' + CHAR(13) 
                          + '    WHERE pic.DropID = @c_DropID ' + CHAR(13) 
                          + '    AND pic.OrderKey = m.OrderKey) ' + CHAR(13) 
      END

      SELECT @c_TaskBatchID_ToDisplay = ISNULL(RTRIM(PTD.TaskBatchNo), '')
      FROM dbo.PACKTASKDETAIL PTD (NOLOCK) 
      WHERE EXISTS ( SELECT 1  
          FROM [dbo].[PickDetail] pic WITH (NOLOCK) 
          WHERE pic.DropID = @c_DropID
          AND pic.OrderKey = PTD.OrderKey)

      SET @c_OrderKey_ToDisplay = ''

   END

   SET @c_SQLQuery = 'SELECT TOP 1 ' + CHAR(13) + 
                   + '       @n_IsExists = (1) '  + CHAR(13) + 
                   + '      ,@c_OrderMode = Left(UPPER(OrderMode),1) '  + CHAR(13) + 
                   + '      ,@c_1stOrderKey = OrderKey '  + CHAR(13) + 
                   + 'FROM [dbo].[PackTask] m WITH (NOLOCK) '  + CHAR(13) +
                   + @c_SQLWhereClause

   SET @c_SQLParams = '@c_TaskBatchID NVARCHAR(10), @c_OrderKey NVARCHAR(10), @c_DropID NVARCHAR(20), @n_IsExists INT OUTPUT, @c_OrderMode NVARCHAR(1) OUTPUT, @c_1stOrderKey NVARCHAR(10) OUTPUT'


   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>>>>>>>>>>>>> @c_SQLQuery'
      PRINT @c_SQLQuery
   END

   EXECUTE sp_ExecuteSql @c_SQLQuery
                        ,@c_SQLParams
                        ,@c_TaskBatchID
                        ,@c_OrderKey
                        ,@c_DropID
                        ,@n_IsExists      OUTPUT
                        ,@c_OrderMode     OUTPUT
                        ,@c_1stOrderKey   OUTPUT

   IF @n_IsExists = 0
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 51004
      SET @c_ErrMsg = 'PackTask not found.'
      GOTO QUIT
   END
   --Search For PackTask (End)

   SELECT TOP 1 
          @c_StorerKey = StorerKey
         ,@c_Facility = Facility
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE OrderKey = @c_1stOrderKey

   IF @b_Debug = 1
   BEGIN
      PRINT '@c_1stOrderKey: ' + @c_1stOrderKey
      PRINT '@c_UR_StorerKey: ' + @c_UR_StorerKey
      PRINT '@c_StorerKey: ' + @c_StorerKey
   END

   IF @c_UR_StorerKey <> @c_StorerKey
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 51005
      SET @c_ErrMsg = 'Not allow to pack task for Storer(' + @c_StorerKey + ')'
      GOTO QUIT
   END

   IF @c_UR_Facility <> @c_Facility
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 51006
      SET @c_ErrMsg = 'Not allow to pack task for Facility(' + @c_Facility + ')'
      GOTO QUIT
   END

   IF @c_OrderMode = 'S'
   BEGIN
      SET @n_TotalCarton = 1
      SET @n_CartonNo = 1 
   END
   --Get Order Mode (End)
   
   
   --SET @b_SearchBatchIDOnly = IIF(@c_TaskBatchID <> '' AND @c_OrderKey = '' AND @c_DropID = '', 1, 0)
  SET @b_SearchBatchIDOnly = CASE WHEN (@c_TaskBatchID <> '' AND @c_OrderKey = '' AND @c_DropID = '')   
                                          OR (@c_TaskBatchID <> '' AND @c_OrderKey = '' AND @c_DropID <> '' ) THEN 1 ELSE 0 END  
  
   --Get Pending PackHeader/Detail (Begin)
   --SET @c_PackIsExists = 0
   --SET @c_SQLQuery = 'SELECT TOP 1 ' + CHAR(13) +
   --                + '       @c_PackIsExists = (1) ' + CHAR(13) +
   --                + '      ,@c_PickSlipNo = m.PickSlipNo ' + CHAR(13) +
   --                + '      ,@c_PackOrderKey = m.Orderkey ' + CHAR(13) +
   --                + '      ,@c_PackComputerName = m.ComputerName ' + CHAR(13) +
   --                + '      ,@c_PackAddWho = m.AddWho ' + CHAR(13) +
   --                + '      ,@c_PackStatus = m.[Status] ' + CHAR(13) +
   --                + 'FROM [dbo].[PACKHEADER] m WITH (NOLOCK) ' + CHAR(13) +
   --                + @c_SQLWhereClause
   --                + CASE WHEN @b_SearchBatchIDOnly = 1 THEN ' AND m.[Status] <''9'' ' ELSE '' END
   --                + CASE WHEN EXISTS (SELECT 1 FROM @t_SkipPickSlipNo) THEN ' AND m.PickSlipNo NOT IN ( SELECT PickSlipNo FROM @t_SkipPickSlipNo ) ' ELSE '' END

   --SET @c_SQLParams = '@c_TaskBatchID NVARCHAR(10), @c_OrderKey NVARCHAR(10), @c_DropID NVARCHAR(20), @c_PackIsExists INT OUTPUT, @c_PickSlipNo NVARCHAR(10) OUTPUT, @c_PackOrderKey NVARCHAR(10) OUTPUT, '
   --                 + '@c_PackComputerName NVARCHAR(30) OUTPUT, @c_PackAddWho NVARCHAR(128) OUTPUT, @c_PackStatus NVARCHAR(1) OUTPUT'

   
   --EXECUTE sp_ExecuteSql @c_SQLQuery
   --                     ,@c_SQLParams
   --                     ,@c_TaskBatchID
   --                     ,@c_OrderKey
   --                     ,@c_DropID
   --                     ,@c_PackIsExists        OUTPUT
   --                     ,@c_PickSlipNo          OUTPUT
   --                     ,@c_PackOrderKey        OUTPUT
   --                     ,@c_PackComputerName    OUTPUT
   --                     ,@c_PackAddWho          OUTPUT
   --                     ,@c_PackStatus          OUTPUT

   SET @c_SQLQuery = 'SELECT TOP 10 ' + CHAR(13) +
                   + '       (1) ' + CHAR(13) +
                   + '      ,m.PickSlipNo ' + CHAR(13) +
                   + '      ,m.Orderkey ' + CHAR(13) +
                   + '      ,m.ComputerName ' + CHAR(13) +
                   + '      ,m.AddWho ' + CHAR(13) +
                   + '      ,m.[Status] ' + CHAR(13) +
                   + 'FROM [dbo].[PACKHEADER] m WITH (NOLOCK) ' + CHAR(13) +
                   + @c_SQLWhereClause
                   + CASE WHEN @b_SearchBatchIDOnly = 1 THEN ' AND m.[Status] <''9'' ' ELSE '' END

   SET @c_SQLParams = '@c_TaskBatchID NVARCHAR(10), @c_OrderKey NVARCHAR(10), @c_DropID NVARCHAR(20)'
   

   INSERT INTO @t_PendingTasks
   EXECUTE sp_ExecuteSql @c_SQLQuery
                        ,@c_SQLParams
                        ,@c_TaskBatchID
                        ,@c_OrderKey
                        ,@c_DropID


   IF @b_Debug = '1'
   BEGIN
      SELECT * FROM @t_PendingTasks
      PRINT '>>>>>>>>>>>>> SQL QUERY FOR INSERT PENDING TASK' 
      PRINT @c_SQLQuery
   END

   SEARCH_PENDING_TASK:
   SET @c_PackIsExists     = 0
   SET @c_PickSlipNo       = ''
   SET @c_PackOrderKey     = ''
   SET @c_PackComputerName = ''
   SET @c_PackAddWho       = ''
   SET @c_PackStatus       = ''

   SELECT TOP 1 
       @c_PackIsExists     = PackIsExists  
      ,@c_PickSlipNo       = PickSlipNo      
      ,@c_PackOrderKey     = PackOrderKey    
      ,@c_PackComputerName = PackComputerName
      ,@c_PackAddWho       = PackAddWho      
      ,@c_PackStatus       = PackStatus      
   FROM @t_PendingTasks
   WHERE PickSlipNo NOT IN ( SELECT PickSlipNo FROM @t_SkipTasks )

   IF @b_Debug = '1'
   BEGIN
      SELECT 
       @c_PackIsExists    
      ,@c_PickSlipNo      
      ,@c_PackOrderKey    
      ,@c_PackComputerName
      ,@c_PackAddWho      
      ,@c_PackStatus      
   END

   IF @b_Debug = '1'
   BEGIN
       PRINT '>>>>>>>>>>>>>>>> @c_SQLQuery : ' + @c_SQLQuery
       PRINT 'GetPackTask >>>>>>>>>>>>>>>> @c_UserID = ' + @c_UserID +
          CHAR(13) + ', @c_PackIsExists = ' + CAST(@c_PackIsExists AS NVARCHAR(5)) +
          CHAR(13) + ', @c_PackOrderKey = ' + @c_PackOrderKey + 
          CHAR(13) + ', @c_PackAddWho = ' + @c_PackAddWho +
          CHAR(13) + ', @c_StorerKey = ' + @c_StorerKey +
          CHAR(13) + ', @c_Facility = ' + @c_Facility +
          CHAR(13) + ', @c_PickSlipNo = ' + @c_PickSlipNo +
          CHAR(13) + ', @c_PackComputerName = ' + @c_PackComputerName +
          CHAR(13) + ', @c_ComputerName = ' + @c_ComputerName +
          CHAR(13) + ', @c_OrderMode = ' + @c_OrderMode +
          CHAR(13) + ', @c_TaskBatchID = ' + @c_TaskBatchID + 
          CHAR(13) + ', @b_SearchBatchIDOnly = ' + CONVERT(NVARCHAR(1), @b_SearchBatchIDOnly)

   END
   
   IF @b_SearchBatchIDOnly = 1 AND @c_PackIsExists = 1 AND @c_OrderKey = '' AND @c_OrderMode IN ('S', 'M')
   BEGIN
      SET @c_OrderKey = @c_PackOrderKey

      EXEC [API].[isp_ECOMP_QueryRules]   
         @c_PickSlipNo     = @c_PickSlipNo   
        ,@c_UserID         = @c_UserID       
        ,@c_ComputerName   = @c_ComputerName 
        ,@b_Success        = @b_Success       OUTPUT 
        ,@c_ErrMsg         = @c_ErrMsg        OUTPUT  
        ,@c_TaskID         = @c_TaskBatchID   OUTPUT   
        ,@c_Orderkey       = @c_Orderkey      OUTPUT 
        ,@c_DropID         = @c_DropID 

      IF @b_Success < 0
      BEGIN
         IF @b_Debug = '1'
         BEGIN
            PRINT '>>>>>>>>>>>>>>>> [API].[isp_ECOMP_QueryRules] @b_Success = ' + CONVERT(NVARCHAR, @b_Success)
         END
         INSERT INTO @t_SkipTasks VALUES(@c_PickSlipNo)
         SET @c_OrderKey = ''
         GOTO SEARCH_PENDING_TASK
      END
   END

   IF @b_Debug = '1'  
   BEGIN  
       PRINT '>>>>>>>>>>>>>>>> GetPackTask_S OR GetPackTask_M = ' +  
          CHAR(13) + ' @c_TaskBatchID = ' + @c_TaskBatchID   
   END  
   IF @c_OrderMode = 'M'
   BEGIN
      EXEC [API].[isp_ECOMP_GetPackTask_M] @b_Debug = @b_Debug,                        -- int
                                          @c_UserID = @c_UserID,                       -- nvarchar(256)
                                          @c_PackIsExists = @c_PackIsExists,           -- int
                                          @c_PackStatus = @c_PackStatus,               -- nvarchar(1)
                                          @c_PackOrderKey = @c_PackOrderKey,           -- nvarchar(10)
                                          @c_PackAddWho = @c_PackAddWho,               -- nvarchar(128)
                                          @c_StorerKey = @c_StorerKey,                 -- nvarchar(15)
                                          @c_Facility = @c_Facility,                   -- nvarchar(15)
                                          @c_PickSlipNo = @c_PickSlipNo,               -- nvarchar(10)
                                          @c_DropID = @c_DropID,                       -- nvarchar(10) 
                                          @c_OrderKey = @c_OrderKey,                   -- nvarchar(20) 
                                          @c_1stOrderKey = @c_1stOrderKey,             -- nvarchar(20) 
                                          @c_TaskBatchID = @c_TaskBatchID,             -- nvarchar(10) 
                                          @c_PackComputerName = @c_PackComputerName,   -- nvarchar(30)
                                          @c_ComputerName = @c_ComputerName,           -- nvarchar(30)
                                          @c_OrderMode = @c_OrderMode,                 -- nvarchar(1)
                                          @b_Success = @b_Success OUTPUT,              -- int
                                          @n_ErrNo = @n_ErrNo OUTPUT,                  -- int
                                          @c_ErrMsg = @c_ErrMsg OUTPUT,                -- nvarchar(250)
                                          @c_ResponseString = @c_ResponseString OUTPUT -- nvarchar(max)
   
   END
   ELSE
   BEGIN
      EXEC [API].[isp_ECOMP_GetPackTask_S] @b_Debug = @b_Debug,                        -- int
                                          @c_UserID = @c_UserID,                       -- nvarchar(256)
                                          @c_PackIsExists = @c_PackIsExists,           -- int
                                          @c_PackStatus = @c_PackStatus,               -- nvarchar(1)
                                          @c_PackOrderKey = @c_PackOrderKey,           -- nvarchar(10)
                                          @c_PackAddWho = @c_PackAddWho,               -- nvarchar(128)
                                          @c_StorerKey = @c_StorerKey,                 -- nvarchar(15)
                                          @c_Facility = @c_Facility,                   -- nvarchar(15)
                                          @c_PickSlipNo = @c_PickSlipNo,               -- nvarchar(10)
                                          @c_DropID = @c_DropID,                       -- nvarchar(10) 
                                          @c_OrderKey = @c_OrderKey,                   -- nvarchar(20) 
                                          @c_1stOrderKey = @c_1stOrderKey,             -- nvarchar(20) 
                                          @c_TaskBatchID = @c_TaskBatchID,             -- nvarchar(10) 
                                          @c_PackComputerName = @c_PackComputerName,   -- nvarchar(30)
                                          @c_ComputerName = @c_ComputerName,           -- nvarchar(30)
                                          @c_OrderMode = @c_OrderMode,                 -- nvarchar(1)
                                          @b_Success = @b_Success OUTPUT,              -- int
                                          @n_ErrNo = @n_ErrNo OUTPUT,                  -- int
                                          @c_ErrMsg = @c_ErrMsg OUTPUT,                -- nvarchar(250)
                                          @c_ResponseString = @c_ResponseString OUTPUT -- nvarchar(max)
       
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
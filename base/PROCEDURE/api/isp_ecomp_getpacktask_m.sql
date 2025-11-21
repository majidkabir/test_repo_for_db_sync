SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_GetPackTask_M]                     */              
/* Creation Date: 03-Jul-2023                                           */
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
/* 03-Jul-2023    Allen    #JIRA PAC-4 Initial                          */
/* 20-Jul-2023    Alex01   removed hardcoded GiftWrapping SP            */
/* 10-Oct-2024    Alex02   #JIRA PAC-358 CCTV Integration               */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_GetPackTask_M](
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
         
         
         , @c_UR_StorerKey                NVARCHAR(15)   = ''
         , @c_UR_Facility                 NVARCHAR(15)   = ''
         , @c_SKU                         NVARCHAR(20)   = ''
         , @n_IsExists                    INT            = 0

         , @n_TotalCarton                 INT            = 1
         , @n_CartonNo                    INT            = 1
         
         , @c_PackNotes                   NVARCHAR(4000) = ''
         
         , @c_sc_EPackTakeOver            NVARCHAR(5)    = ''
         , @c_sc_MultiPackMode            NVARCHAR(5)    = ''
         , @c_sc_CtnTypeInput             NVARCHAR(5)    = ''

         , @c_InProgOrderKey              NVARCHAR(10)   = ''  

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

         , @c_EPACKConfigJSON             NVARCHAR(4000) = ''        --Alex02

   DECLARE @c_MultiPackResponse           NVARCHAR(MAX)  = NULL
         , @c_DefaultCartonType           NVARCHAR(10)   = ''
         , @c_DefaultCartonGroup          NVARCHAR(10)   = ''
         , @b_AutoCloseCarton             INT            = 0
         , @f_CartonWeight                FLOAT          = 0

         , @b_IsLabelNoCaptured           INT            = 0
         , @c_PackQRF_QRCode              NVARCHAR(100)  = ''
         , @c_TaskBatchID_ToDisplay       NVARCHAR(10)   = ''
         , @c_OrderKey_ToDisplay          NVARCHAR(10)   = ''

         , @c_PrePackMsgSP                NVARCHAR(200)  = ''
         , @c_PrePackMsg                  NVARCHAR(MAX)  = ''
         , @c_PrePackMsgSuccess           NVARCHAR(4000) = ''

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

   --DECLARE @t_PackTaskOrderSts AS TABLE (
   --      TaskBatchNo          NVARCHAR(10)      NULL
   --   ,  OrderKey             NVARCHAR(10)      NULL
   --   ,  TotalOrder           INT               NULL
   --   ,  PackedOrder          INT               NULL
   --   ,  PendingOrder         INT               NULL
   --   ,  CancelledOrder       INT               NULL
   --   ,  InProgOrderKey       NVARCHAR(10)      NULL
   --   ,  NonEPackSO           NVARCHAR(150)     NULL
   --)

   --DECLARE @t_OrderInfo AS TABLE (
   --      Orderkey          NVARCHAR(10)   NULL
   --   ,  ExternOrderkey    NVARCHAR(50)   NULL
   --   ,  LoadKey           NVARCHAR(10)   NULL
   --   ,  ConsigneeKey      NVARCHAR(15)   NULL
   --   ,  ShipperKey        NVARCHAR(15)   NULL
   --   ,  SalesMan          NVARCHAR(30)   NULL
   --   ,  [Route]           NVARCHAR(10)   NULL
   --   ,  UserDefine03      NVARCHAR(20)   NULL
   --   ,  UserDefine04      NVARCHAR(40)   NULL
   --   ,  UserDefine05      NVARCHAR(20)   NULL
   --   ,  [Status]          NVARCHAR(10)   NULL
   --   ,  SOStatus          NVARCHAR(10)   NULL
   --   ,  TrackingNo        NVARCHAR(40)   NULL
   --)

   DECLARE @t_PackingRules AS TABLE (
         RuleName          NVARCHAR(60)   NULL
      ,  [Value]           NVARCHAR(120)  NULL
   )
   --DeviceOrderkey,Status,INProgOrderkey,Color
   DECLARE @t_PackTaskOrder AS TABLE (
         TaskBatchNo          NVARCHAR(10)      NULL
      ,  OrderKey             NVARCHAR(10)      NULL
      ,  DeviceOrderkey       NVARCHAR(20)      NULL
      ,  [Status]             NVARCHAR(10)      NULL
      ,  INProgOrderkey       NVARCHAR(20)      NULL
      ,  Color                NVARCHAR(10)      NULL
   )

   -- If Pack by Drop ID
   IF @c_DropID <> '' AND @c_OrderKey <> ''
   BEGIN
      SET @c_OrderKey_ToDisplay = @c_OrderKey
   END

   IF @c_PackIsExists = 1
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT 'GetMultiPackTask >>>>>> @c_PackIsExists = 1'
         PRINT 'GetMultiPackTask >>>>>> @c_PickSlipNo = ' + @c_PickSlipNo
         PRINT 'GetMultiPackTask >>>>>> @c_PackOrderKey = ' + @c_PackOrderKey
         PRINT 'GetMultiPackTask >>>>>> @c_PackComputerName = ' + @c_PackComputerName
         PRINT 'GetMultiPackTask >>>>>> @c_PackAddWho = ' + @c_PackAddWho
         PRINT 'GetMultiPackTask >>>>>> @c_PackStatus = ' + @c_PackStatus
      END

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
            IF @b_Debug = 1 PRINT 'GetMultiPackTask >>>>>> Changed @c_PackIsExists = 0'
            GOTO QUERYRULES
         END
      END      
   END
   --Get Pending PackHeader/Detail (End)

   QUERYRULES:

   -- Get Pack Description
   SELECT TOP 1 @c_PackNotes = ISNULL(Notes, '')
   FROM dbo.PICKDETAIL WITH (NOLOCK) 
   WHERE OrderKey = @c_1stOrderKey

   IF @b_Debug = '1'
   BEGIN
      PRINT 'GetMultiPackTask Get Pack Description '
      PRINT '@c_PackNotes = ' + @c_PackNotes 
      PRINT '@c_1stOrderKey = ' + @c_1stOrderKey 
   END

   SET @c_sc_CtnTypeInput = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'CtnTypeInput')  

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

   --Alex01 Begin
   --Get EcomPrePackMsg(gift Wrapping)
   
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
              ,@c_Orderkey
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

      --Alex01 End
   END 
   --Get EcomPrePackMsg(gift Wrapping) -E

   SET @n_sc_Success = 0
   SET @n_sc_err = 0
   SET @c_sc_errmsg = ''
   
   INSERT INTO @t_PackingRules
   EXEC [API].[isp_ECOMP_GetPackingRules]
        @c_StorerKey                = @c_StorerKey
      , @c_Facility                 = @c_Facility
      , @c_SKU                      = ''
      , @c_PackMode                 = 'M'
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
   
   --Carton Packed List (START)
   IF @b_Debug = 1
   BEGIN
      PRINT 'GetMultiPackTask Getting CartonPacked Info start... '
      PRINT '@c_PickSlipNo = ' + @c_PickSlipNo 
      PRINT ' @c_TaskBatchID = ' + @c_TaskBatchID 
      PRINT ' @c_DropID = ' + @c_DropID 
      PRINT ' @c_Orderkey = ' + @c_Orderkey
   END
   
   --Alex01 CAll SP to retrieve MultiPackTask JSON
   EXEC [API].[isp_ECOMP_GetMultiPackTaskResponse] 
        @c_PickSlipNo            = @c_PickSlipNo  
      , @c_TaskBatchID           = @c_TaskBatchID 
      , @c_OrderKey              = @c_Orderkey    
      , @c_DropID                = @c_DropID
      , @c_MultiPackResponse     = @c_MultiPackResponse     OUTPUT
      , @c_InProgOrderKey        = @c_InProgOrderKey        OUTPUT

   --Alex02 Begin
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
   --Alex02 End

   SET @c_ResponseString = ISNULL(( 
                              SELECT TOP 1
                                     @c_PackNotes              As 'PackNotes'
                                    ,@c_TaskBatchID_ToDisplay  As 'TaskBatchID_ToDisplay'
                                    ,@c_OrderKey_ToDisplay     As 'OrderKey_ToDisplay'
                                    ,@c_OrderMode              As 'OrderMode'
                                    ,@c_InProgOrderKey         As 'LastOrderID'
                                    ,@c_PrePackMsg             As 'PrePackMeassage'
                                    ,( 
                                       SELECT CartonType, CartonWeight FROM @t_Carton
                                       FOR JSON PATH 
                                     ) As 'CartonTypeList'
                                    ,(
                                       JSON_QUERY(@c_MultiPackResponse)
                                     ) As 'MultiPackTask'
                                    ,(
                                       SELECT ISNULL(RTRIM(RuleName), '')  As 'RuleName'
                                             ,ISNULL(RTRIM([Value]), '')   As 'Value'
                                       FROM @t_PackingRules
                                       FOR JSON PATH
                                     ) As 'PackingRules'
                                    ,(
                                       JSON_QUERY(@c_EPACKConfigJSON)
                                     ) As 'EPACKConfig'
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
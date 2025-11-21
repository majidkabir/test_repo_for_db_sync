SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_WSITF_GeekPlusRBT_INVENTORY_Outbound            */
/* Creation Date: 04-JUL-2018                                           */
/* Copyright: LFL                                                       */
/* Written by: TKLIM                                                    */
/*                                                                      */
/* Purpose: Pass Incoming Request String For Interface                  */
/*                                                                      */
/* Input Parameters:  @c_StorerKey        - 'STORER'                    */
/*                    @b_Debug            - 0/1                         */
/*                    @c_TransmitLogKey   - 'Transmitlogkey'            */
/*                                                                      */
/* Output Parameters: @b_Success          - Success Flag  = 0           */
/*                    @n_Err              - Error No      = 0           */
/*                    @c_ErrMsg           - Error Message = ''          */
/*                                                                      */
/* Called By: LeafAPIServer - WMSAPI                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author         Purposes											*/
/* 2018-07-27     Alex           Insert facility for WMSCustSOH (Alex)  */
/************************************************************************/
CREATE PROC [dbo].[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound](
      @c_StorerKey               NVARCHAR(15)
    , @c_Facility                NVARCHAR(10)
    , @b_Debug                   INT               = 0
    , @b_Success                 INT               = 0  OUTPUT  
    , @n_Err                     INT               = 0  OUTPUT  
    , @c_ErrMsg                  NVARCHAR(250)     = '' OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT
         , @n_StartCnt                    INT

         , @c_Application                 NVARCHAR(50)
         , @c_MessageType                 NVARCHAR(10)
         , @c_Status                      NVARCHAR(5)
         , @c_Status0                     NVARCHAR(1)
         , @c_Status1                     NVARCHAR(1)
         , @c_Status5                     NVARCHAR(1)
         , @c_Status9                     NVARCHAR(1)
         , @c_ListName_WebService         NVARCHAR(10)           
         , @c_ListName_ROBOTFAC           NVARCHAR(10)
         , @c_ListName_ROBOTSTR           NVARCHAR(10)

         , @c_FullRequestString           NVARCHAR(MAX)
         , @c_ResponseString              NVARCHAR(MAX)
         , @c_vbErrMsg                    NVARCHAR(MAX)
         , @c_TargetDB                    NVARCHAR(30)
         , @n_Exists                      INT

         , @c_IniFilePath                 VARCHAR(225) 
         , @c_WebRequestMethod            VARCHAR(10)
         , @c_ContentType                 VARCHAR(100)
         , @c_WebRequestEncoding          VARCHAR(30)
         , @c_WS_url                      NVARCHAR(250)

         -- Req message
         , @c_WarehouseCode               NVARCHAR(16)
         , @c_UserId                      NVARCHAR(16)
         , @c_UserKey                     NVARCHAR(16)
         , @n_AuditType                   NVARCHAR(5)
         , @n_SkuAmount                   INT
         , @n_CurrentPage                 INT 
         , @n_PageSize                    INT
         , @n_TotalPage                   INT

         --Resp Msg
         , @c_Resp_MsgCode                NVARCHAR(10)
         , @c_Resp_Message                NVARCHAR(60)
         , @n_Resp_SkuAmount              INT
         , @n_Resp_TotalPageNum           INT
         , @n_Resp_CurrentPage            INT
         , @n_Resp_PageSize               INT

         --Email Alert
         , @c_ListName_GeekAlert          NVARCHAR(10)
         , @b_SendAlert                   INT
         , @n_EmailGroupId                INT
         , @c_EmailTitle                  NVARCHAR(100)


         , @c_ExecStatements              NVARCHAR(4000)
         , @c_ExecArguments               NVARCHAR(4000)
         , @c_TranID                      NVARCHAR(30)
         , @n_Retry                       INT


   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT

   SET @c_Application                     = 'GEEK+_INV_OUT'
   SET @c_MessageType                     = 'WS_OUT'
   SET @c_Status                          = ''
   SET @c_Status0                         = '0'
   SET @c_Status1                         = '1'
   SET @c_Status5                         = '5'
   SET @c_Status9                         = '9'
   SET @c_ListName_WebService             = 'WebService'
   SET @c_ListName_ROBOTFAC               = 'ROBOTFAC'
   SET @c_ListName_ROBOTSTR               = 'ROBOTSTR'

   SET @c_FullRequestString               = ''
   SET @c_ResponseString                  = ''
   SET @c_vbErrMsg                        = ''
   SET @c_TargetDB                        = '' 
   SET @n_Exists                          = 0
   
   SET @c_IniFilePath                     = ''           
   SET @c_WebRequestMethod                = 'POST'
   SET @c_ContentType                     = 'application/json'
   SET @c_WebRequestEncoding              = 'UTF-8'
   SET @c_WS_url                          = ''

   -- Req message
   SET @c_WarehouseCode                   = '' 
   SET @c_UserId                          = ''
   SET @c_UserKey                         = ''
   SET @n_AuditType                       = 0
   SET @n_SkuAmount                       = 0
   SET @n_CurrentPage                     = 1
   SET @n_PageSize                        = 1000
   SET @n_TotalPage                       = 1

   -- Resp Msg
   SET @c_Resp_MsgCode                    = ''
   SET @c_Resp_Message                    = ''
   SET @n_Resp_SkuAmount                  = 0
   SET @n_Resp_TotalPageNum               = 0
   SET @n_Resp_CurrentPage                = 0
   SET @n_Resp_PageSize                   = 1000

   --Email Alert
   SET @c_ListName_GeekAlert              = 'GEEK+ALERT'
   SET @b_SendAlert                       = 0
   SET @n_EmailGroupId                    = 0
   SET @c_EmailTitle                      = ''   
   
   SET @c_ExecStatements                  = ''
   SET @c_ExecArguments                   = ''
   SET @c_TranID                          = ''
   SET @n_Retry                           = 1

   SET @c_StorerKey                       = ISNULL(RTRIM(@c_StorerKey), '')
   SET @c_Facility                        = ISNULL(RTRIM(@c_Facility), '')


   --IF OBJECT_ID('tempdb..#TEMP_Geek_InvBal') IS NOT NULL
   --DROP TABLE #TEMP_Geek_InvBal

   --CREATE TABLE #TEMP_Geek_InvBal(
   --   ID               INT IDENTITY(1,1),
   --   container_id      NVARCHAR(32) NOT NULL,
   --   transaction_id    NVARCHAR(10) NULL
   --)

   --IF @b_Debug = 1
   --BEGIN
   --   PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_INVENTORY_Outbound - INITAL BEGIN'
   --   PRINT '@c_StorerKey: ' + @c_StorerKey + ', @c_Facility: ' + @c_Facility
   --   PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_INVENTORY_Outbound - INITAL END'
   --END 

   IF ISNULL(RTRIM(@c_StorerKey), '') = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68001
      SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                  + ':Input param @c_StorerKey cannot be null or empty. (isp_WSITF_GeekPlusRBT_INVENTORY_Outbound) ' 
      GOTO QUIT
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN

      --GET DTSITF DBName and Email Group
      SELECT @c_TargetDB = ISNULL(RTRIM(UDF01), '')
            , @n_EmailGroupId = ISNULL(TRY_CONVERT(INT, ISNULL(RTRIM(Short), '0')), 0)
            , @c_EmailTitle = ISNULL(RTRIM([Description]), '')
      FROM dbo.Codelkup WITH (NOLOCK)
      WHERE ListName = @c_ListName_GeekAlert
      AND Code = @c_Application
      AND StorerKey = @c_StorerKey

      --GET Robot WarehouseCode by storer & facility
      SET @n_Exists = 0
      SELECT @n_Exists = (1)
            ,@c_WarehouseCode = ISNULL(RTRIM(Short), '')
      FROM dbo.Codelkup WITH (NOLOCK)
      WHERE ListName = @c_ListName_ROBOTFAC
      AND Code = @c_Facility
      AND StorerKey = @c_StorerKey
         
      IF @c_WarehouseCode = '' OR @n_Exists = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 68003
         SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                  + ': Robot Warehouse Code not setup (codelkup, listname=ROBOTFAC). (isp_WSITF_GeekPlusRBT_INVENTORY_Outbound) ' 
         GOTO QUIT
      END
         
      --GET Robot Webservice data
      SELECT  @n_Exists = (1)
            , @c_WS_url = ISNULL(RTRIM(Long), '') 
            , @c_UserId = ISNULL(RTRIM(UDF01), '') 
            , @c_UserKey = ISNULL(RTRIM(UDF02), '') 
            , @c_IniFilePath = ISNULL(RTRIM(Notes), '') 
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE Listname = @c_ListName_WebService
      AND Code = @c_WarehouseCode 
      AND StorerKey = @c_StorerKey
      AND Code2 = 'INV'
         
      IF @n_Exists = 0 OR @c_WS_url = '' OR @c_IniFilePath = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 68004
         SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                     + ': Webservice Config not setup in (Codelkup, Listname = ' + @c_ListName_WebService + '; Code2 = INV). (isp_WSITF_GeekPlusRBT_INVENTORY_Outbound) ' 
         GOTO QUIT
      END

      --GET key once for every schedule run. Used to track/group 
      EXEC [dbo].[nspg_GetKey]     
            'geek_invbal_id'   
         , 10 
         , @c_TranID    OUTPUT    
         , @b_Success   OUTPUT    
         , @n_Err       OUTPUT    
         , @c_ErrMsg    OUTPUT
         
      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 68002
         SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                  + ': Failed to GetKey - geek_invbal_id. ' + @c_ErrMsg + '.(isp_WSITF_GeekPlusRBT_INVENTORY_Outbound) ' 
         GOTO QUIT
      END

      --Loop every page. @n_TotalPage will start with 1, but will updated by WS response during the loop.
      WHILE(@n_CurrentPage <= @n_TotalPage)
      BEGIN

         SET @c_Status = @c_Status9
         SET @n_Retry = 1

         RESTART_WS:
         SET @n_Err = 0
         SET @c_ErrMsg = ''

         --Construct RequestString
         SET @c_FullRequestString = (ISNULL(RTRIM((
                                       SELECT 
                                          @c_WarehouseCode As 'header.warehouse_code'
                                        , @c_UserId As 'header.user_id'
                                        , @c_UserKey As 'header.user_key'
                                        , @n_AuditType As 'body.audit_type'
                                        , @n_SkuAmount As 'body.sku_amount'
                                        , @n_CurrentPage As 'body.current_page'
                                        , @n_PageSize As 'body.page_size'
                                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                                    )), ''))
         
         BEGIN TRY
            IF @b_Debug = 1
            BEGIN
               PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: @n_Retry = ' + CONVERT(VARCHAR(5),@n_Retry)
               PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: @c_WS_url = ' + @c_WS_url
               PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: @c_FullRequestString = ' + @c_FullRequestString    
            END

            EXEC master.dbo.isp_GenericWebServiceClient 
                       @c_IniFilePath                = @c_IniFilePath
		   	         , @c_WebRequestURL              = @c_WS_url
		   	         , @c_WebRequestMethod           = @c_WebRequestMethod    --@c_WebRequestMethod
		   	         , @c_ContentType                = @c_ContentType         --@c_ContentType
		   	         , @c_WebRequestEncoding         = @c_WebRequestEncoding  --@c_WebRequestEncoding
		   	         , @c_RequestString              = @c_FullRequestString   --@c_FullRequestString
		   	         , @c_ResponseString             = @c_ResponseString      OUTPUT      
		   	         , @c_vbErrMsg                   = @c_vbErrMsg            OUTPUT		      														 
                     , @n_WebRequestTimeout          = 180000                 --@n_WebRequestTimeout -- Miliseconds
		   	         , @c_NetworkCredentialUserName  = ''                     --@c_NetworkCredentialUserName -- leave blank if no network credential
		   	         , @c_NetworkCredentialPassword  = ''                     --@c_NetworkCredentialPassword -- leave blank if no network credential
		   	         , @b_IsSoapRequest              = 0                      --@b_IsSoapRequest  -- 1 = Add SoapAction in HTTPRequestHeader
		   	         , @c_RequestHeaderSoapAction    = ''                     --@c_RequestHeaderSoapAction -- HTTPRequestHeader SoapAction value
		   	         , @c_HeaderAuthorization        = ''                     --@c_HeaderAuthorization
		   	         , @c_ProxyByPass                = '0'                    --@c_ProxyByPass, 1 >> Set Ip & Port, 0 >> Set Nothing, '' >> Skip Setup

                 
            IF @b_Debug = 1
            BEGIN
               PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: @c_ResponseString = ' + @c_ResponseString    
               PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: @c_vbErrMsg = ' + @c_vbErrMsg    
            END

            IF @@ERROR <> 0 OR ISNULL(RTRIM(@c_vbErrMsg),'') <> ''
            BEGIN
               SET @c_Status = @c_Status5
               SET @n_Err = 68005
               SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                              + ' Failed to EXEC isp_GenericWebServiceClient. @c_vbErrMsg = ' + @c_vbErrMsg + '(isp_WSITF_GeekPlusRBT_INVENTORY_Outbound)'
               GOTO END_LOOP
            END

         END TRY
         BEGIN CATCH
            SET @c_Status = @c_Status5
            SET @n_Err = 68006
            SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                           + ' - ' + CONVERT(NVARCHAR(5),ISNULL(ERROR_NUMBER() ,0)) + ' - ' + ERROR_MESSAGE() + ' (isp_WSITF_GeekPlusRBT_INVENTORY_Outbound)'
            GOTO END_LOOP

         END CATCH

         IF ISNULL(RTRIM(@c_ResponseString), '') = ''
         BEGIN
            SET @c_Status = @c_Status5
            SET @n_Err = 68007
            SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                           + ' GEEK+ server responded empty string. (isp_WSITF_GeekPlusRBT_INVENTORY_Outbound)'
            GOTO END_LOOP
         END

         --Extract Header & Body data from response message
         SELECT  @c_Resp_MsgCode       = MsgCode
               , @c_Resp_Message       = [Message]
               , @n_Resp_SkuAmount     = SkuAmount
               , @n_Resp_TotalPageNum  = TotalPageNum
               , @n_Resp_CurrentPage   = CurrentPage
               , @n_Resp_PageSize      = PageSize
         FROM OPENJSON(@c_ResponseString)
         WITH ( MsgCode          NVARCHAR(10)   '$.header.msgCode'
               ,[Message]        NVARCHAR(60)   '$.header.message'
               ,SkuAmount        INT            '$.body.sku_amount'
               ,TotalPageNum     INT            '$.body.total_page_num'
               ,CurrentPage      INT            '$.body.current_page'
               ,PageSize         INT            '$.body.page_size'
         )

         IF @@ERROR <> 0
         BEGIN
            SET @c_Status = @c_Status5
            SET @n_Err = 68008
            SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                           + ' Failed to query JSON header and body. (isp_WSITF_GeekPlusRBT_INVENTORY_Outbound)'
            GOTO END_LOOP
         END

         IF ISNULL(RTRIM(@c_Resp_MsgCode), '') <> '200'
         BEGIN
            SET @c_Status = @c_Status5
            SET @n_Err = 68009
            SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                           + ' GEEK+ server responded MsgCode ' + @c_Resp_MsgCode + '. (isp_WSITF_GeekPlusRBT_INVENTORY_Outbound)'
            GOTO END_LOOP
         END

         --Insert GeekPlusRBT_InvSync for later processing.
         INSERT INTO GeekPlusRBT_InvSync (TranID, MsgCode, [Message], SkuAmount, TotalPageNum, CurrentPage, PageSize, OwnerCode, SkuCode, SkuLevel, Amount, AuditDate, AddDate)
         SELECT  @c_TranID
               , @c_Resp_MsgCode
               , @c_Resp_Message
               , @n_Resp_SkuAmount
               , @n_Resp_TotalPageNum
               , @n_Resp_CurrentPage
               , @n_Resp_PageSize
               , OwnerCode
               , SkuCode
               , SkuLevel
               , Amount
               , AuditDate
               , GETDATE()
         FROM OPENJSON(@c_ResponseString, '$.body."sku_list"')
         WITH ( OwnerCode       NVARCHAR(16)    '$.owner_code'
               ,SkuCode         NVARCHAR(64)    '$.sku_code'
               ,SkuLevel        INT             '$.sku_level'
               ,Amount          INT             '$.amount'
               ,AuditDate       NVARCHAR(16)    '$.audit_date'
         )

         IF @@ERROR <> 0
         BEGIN
            SET @c_Status = @c_Status5
            SET @n_Err = 68010
            SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                           + ' Failed to Insert Into GeekPlusRBT_INVENTORY. (isp_WSITF_GeekPlusRBT_INVENTORY_Outbound)'
            GOTO END_LOOP
         END

         END_LOOP:

         IF @b_Debug = 1
         BEGIN
            PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: @c_ErrMsg = ' + @c_ErrMsg    
         END

         --INSERT LOG
         INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status], NoOfTry )
         VALUES ( @c_Application, @c_WS_url, @c_MessageType, @c_VBErrMsg, @c_FullRequestString, @c_TranID, @c_StorerKey, @c_ResponseString, @c_Status, @n_Retry)

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 68011
            SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                           + ' Failed to insert into dbo.TCPSocket_OUTLog. (isp_WSITF_GeekPlusRBT_INVENTORY_Outbound)'
         END


         IF @c_ErrMsg <> ''
         BEGIN
            SET @n_Retry = @n_Retry + 1

            IF @n_Retry <= 3
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: ######### RESTART_WS #########' 
                  PRINT ' ' 
               END

               GOTO RESTART_WS
            END
            ELSE
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: ######### FORCE EXIT LOOP #########'
                  PRINT ' ' 
               END

               SET @n_CurrentPage = @n_TotalPage + 1        --SET CurrentPage out of scope to quit while loop
            END
         END
         ELSE
         BEGIN --Success
            SET @n_CurrentPage = @n_Resp_CurrentPage + 1    --Increase @n_CurrentPage by 1 to loop next page
            SET @n_TotalPage = @n_Resp_TotalPageNum         --Update @n_TotalPage from ResponseMsg
         END

      END   --WHILE(@n_CurrentPage <= @n_TotalPage)

      IF @c_Status = @c_Status9
      BEGIN

         --Convert AuditDate from Miliseconds to Seconds
         Update GeekPlusRBT_InvSync SET AuditDate = AuditDate / 1000 WHERE TranID = @c_TranID AND ISNUMERIC(AuditDate) = 1
         --Alex - add facility
         SET @c_ExecStatements = N'INSERT INTO ' + @c_TargetDB + '.dbo.WMSCustSOH (Datastream, File_key, StorerKey, Facility, Sku, UserDefine01, TotalSOH, SnapShotDate)'
                               + ' SELECT ''GEEK+INV'''
                               + ', @c_TranID'
                               + ', @c_StorerKey'
                               + ', @c_Facility'
                               + ', SkuCode'
                               + ', SkuLevel'
                               + ', Amount'
                               + ', DATEADD(HOUR, 8, DATEADD(SECOND, AuditDate, ''19700101''))'
                               + ' FROM GeekPlusRBT_InvSync WITH (NOLOCK)'
                               + ' WHERE TranID = @c_TranID'
                               + ' ORDER BY TranID, CurrentPage, SkuCode ASC'

         SET @c_ExecArguments = ' @c_TranID     NVARCHAR(30)'
                              + ',@c_Storerkey  NVARCHAR(15)'
                              + ',@c_Facility   NVARCHAR(10)'

         EXEC sp_ExecuteSql @c_ExecStatements
                           , @c_ExecArguments
                           , @c_TranID
                           , @c_Storerkey
                           , @c_Facility

         IF @@ERROR <> 0
         BEGIN
            SET @n_Err = 68012
            SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)
                           + ' Failed to Insert Into WMSCustSOH. (isp_WSITF_GeekPlusRBT_INVENTORY_Outbound)'
            GOTO QUIT
         END

      END

   END --IF @n_Continue = 1 OR @n_Continue = 2

   QUIT:
   --Send Error Notification
   --IF @b_SendAlert = 1 AND ISNULL(RTRIM(@c_ErrMsg), '') <> ''
   --BEGIN
   --   SELECT @n_EmailGroupId = ISNULL(TRY_CONVERT(INT, ISNULL(RTRIM(Short), '0')), 0)
   --        , @c_EmailTitle = ISNULL(RTRIM([Description]), '')
   --   FROM dbo.Codelkup WITH (NOLOCK)
   --   WHERE ListName = @c_ListName_GeekAlert 
   --   AND Code = @c_Application
   --   AND StorerKey = @c_StorerKey

   --   IF @n_EmailGroupId > 0
   --   BEGIN
   --      EXEC [dbo].[isp_Geek+_SendEmailAlert]
   --        @c_DTSITF_DBName               --@c_DTSITF_DBName
   --      , @n_EmailGroupId                --@n_EmailTo
   --      , @c_EmailTitle                  --@c_Subject
   --      , @c_ErrMsg                      --@c_EmailBody
   --      , @b_Success           OUTPUT
   --   END
   --END

   IF ISNULL(RTRIM(@c_ErrMsg),'') <> ''
      SET @b_Success = 0

   IF @b_Debug = 1
   BEGIN
      PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: @n_Err: ' + CONVERT(NVARCHAR, @n_Err) 
      PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: @c_ErrMsg: ' + @c_ErrMsg 
      PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: @b_Success: ' + CONVERT(NVARCHAR, @b_Success)
      PRINT '[isp_WSITF_GeekPlusRBT_INVENTORY_Outbound]: END'
   END 
   
END -- Procedure  

GO
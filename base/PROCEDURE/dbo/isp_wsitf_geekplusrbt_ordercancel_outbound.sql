SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_WSITF_GeekPlusRBT_ORDERCANCEL_Outbound          */
/* Creation Date: 21-Jun-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: AlexKeoh                                                 */
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
/* 2018-06-21     Alex           Initial - Jira #WMS-5243               */
/************************************************************************/
CREATE PROC [dbo].[isp_WSITF_GeekPlusRBT_ORDERCANCEL_Outbound](
      @c_TransmitlogKey          NVARCHAR(10)      = ''
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
         , @c_flag                        NVARCHAR(5)
         , @c_flag0                       NVARCHAR(1)
         , @c_flag1                       NVARCHAR(1)
         , @c_flag5                       NVARCHAR(1)
         , @c_flag9                       NVARCHAR(1)
         , @c_ListName_WebService         NVARCHAR(10)           
         , @c_ListName_ROBOTFAC           NVARCHAR(10)
         , @c_ListName_ROBOTSTR           NVARCHAR(10)

         , @n_LOGSerialNo                 INT
         , @c_FullRequestString           NVARCHAR(MAX)
         , @c_ResponseString              NVARCHAR(MAX)
         , @c_vbErrMsg                    NVARCHAR(MAX)

         , @n_Exists                      INT

         , @c_IniFilePath                 VARCHAR(225) 
         , @c_WebRequestMethod            VARCHAR(10)
         , @c_ContentType                 VARCHAR(100)
         , @c_WebRequestEncoding          VARCHAR(30)
         , @c_WS_url                      NVARCHAR(250)

         
         --ORDERS
         , @c_StorerKey                   NVARCHAR(15)
         , @c_Facility                    NVARCHAR(5)
         , @c_DocType                     NVARCHAR(1)
         , @c_ConsigneeKey                NVARCHAR(15)
         , @c_ECOM_SINGLE_FLAG            NCHAR(1)

         --TL3
         , @c_TableName                   NVARCHAR(30)
         , @c_Key1                        NVARCHAR(10)

         --header
         , @c_warehouse_code              NVARCHAR(16)
         , @c_user_id                     NVARCHAR(16)
         , @c_user_key                    NVARCHAR(16)

         --body
         , @n_OrdCount                    INT

         --body.order_list
         , @c_cancel_date                 NVARCHAR(20) = CONVERT(NVARCHAR, CONVERT(BIGINT ,DATEDIFF(SECOND ,'1970-01-01 00:00:00.000', GETUTCDATE())) * 1000)

         , @c_Resp_MsgCode                NVARCHAR(10)
         , @c_Resp_Msg                    NVARCHAR(200)
         , @b_Resp_Success                BIT


         --, @c_ListName_GeekAlert          NVARCHAR(10)
         --, @b_SendAlert                   INT
         --, @n_EmailGroupId                INT
         --, @c_EmailTitle                  NVARCHAR(100)


   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT

   SET @b_Success                         = 0
   SET @n_Err                             = 0
   SET @c_ErrMsg                          = ''

   SET @c_Application                     = 'GEEK+_ORDCANC_OUT'
   SET @c_MessageType                     = 'RBTWS_OUT'
   SET @c_flag                            = ''
   SET @c_flag0                           = '0'
   SET @c_flag1                           = '1'
   SET @c_flag5                           = '5'
   SET @c_flag9                           = '9'
   SET @c_ListName_WebService             = 'WebService'
   SET @c_ListName_ROBOTFAC               = 'ROBOTFAC'
   SET @c_ListName_ROBOTSTR               = 'ROBOTSTR'

   SET @n_LOGSerialNo                     = 0
   SET @c_FullRequestString               = ''
   SET @c_ResponseString                  = ''
   SET @c_vbErrMsg                        = ''

   SET @c_WebRequestMethod                = 'POST'
   SET @c_ContentType                     = 'application/json'
   SET @c_WebRequestEncoding              = 'UTF-8'
   SET @c_WS_url                          = ''
   
   SET @n_OrdCount                        = 1
   --ORDERS
   SET @c_StorerKey                       = ''
   SET @c_Facility                        = ''
   SET @c_DocType                         = ''
   SET @c_ConsigneeKey                    = ''
   SET @c_ECOM_SINGLE_FLAG                = ''

   --header
   SET @c_warehouse_code                  = ''
   SET @c_user_id                         = ''
   SET @c_user_key                        = ''

   --body.order_list
   SET @c_cancel_date                     = CONVERT(NVARCHAR, CONVERT(BIGINT ,DATEDIFF(SECOND ,'1970-01-01 00:00:00.000', GETUTCDATE())) * 1000)

   SET @c_vbErrMsg                        = ''
   SET @c_Resp_MsgCode                    = ''
   SET @c_Resp_Msg                        = ''
   SET @b_Resp_Success                    = 0

   --SET @c_ListName_GeekAlert              = 'GEEK+ALERT'
   --SET @b_SendAlert                       = 0
   --SET @n_EmailGroupId                    = 0
   --SET @c_EmailTitle                      = ''

   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_ORDERCANCEL_Outbound - INITAL BEGIN'
      PRINT '@c_TransmitlogKey: ' + @c_TransmitlogKey
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_ORDERCANCEL_Outbound - INITAL END'
   END 

   SET @n_Exists = 0
   SELECT @n_Exists = (1)
         ,@c_TableName = ISNULL(RTRIM(TableName), '')
         ,@c_Key1 = ISNULL(RTRIM(Key1), '')
         ,@c_StorerKey = ISNULL(RTRIM(Key3), '')
   FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
   WHERE transmitlogkey = @c_TransmitlogKey 
   AND transmitflag = @c_flag0

   IF @n_Exists = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 230300
      SET @c_ErrMsg = 'NSQL' 
                    + CONVERT(NVARCHAR(6),@n_Err) 
                    + ': No records found in TRANSMITLOG3 table.(isp_WSITF_GeekPlusRBT_ORDERCANCEL_Outbound)'
      GOTO QUIT
   END

   IF @c_TableName <> 'RBTORDCANC_OUT'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 230301
      SET @c_ErrMsg = 'NSQL' 
                    + CONVERT(NVARCHAR(6),@n_Err) 
                    + ': Invalid TransmitLog3 TableName.(isp_WSITF_GeekPlusRBT_ORDERCANCEL_Outbound)'
      GOTO QUIT
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SET @n_Exists = 0
      SELECT @n_Exists = (1)
            ,@c_Facility = ISNULL(RTRIM(Facility), '')
            ,@c_DocType = ISNULL(RTRIM(DocType), '')
            ,@c_ConsigneeKey = ISNULL(RTRIM(ConsigneeKey), '')
            ,@c_ECOM_SINGLE_FLAG = ISNULL(RTRIM(ECOM_SINGLE_Flag), '')
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE OrderKey = @c_Key1

      IF @n_Exists = 0
      BEGIN
         SET @c_flag = 'IGNOR'
         GOTO UPD_TL3_FLAG
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.Codelkup C WITH (NOLOCK)
         WHERE ListName = 'RBTORDTYPE' AND StorerKey = @c_StorerKey
         AND Short = 'ORDER' AND UDF01 = @c_DocType
         AND UDF02 = CASE WHEN @c_DocType = 'N' AND @c_ConsigneeKey IN ( 
               SELECT C2.Code FROM dbo.Codelkup C2 WITH (NOLOCK) 
               WHERE C2.ListName = 'VIPLIST' AND C2.StorerKey = @c_StorerKey )
            THEN 'VIP' ELSE 'NORMAL' END
         AND UDF03 = IIF(@c_DocType = 'E', @c_ECOM_SINGLE_FLAG, '*'))
      BEGIN
         SET @c_flag = 'IGNOR'
         GOTO UPD_TL3_FLAG
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
         WHERE OrderKey = @c_Key1
         AND EXISTS ( SELECT 1 FROM dbo.LOC L WITH (NOLOCK) 
         WHERE L.Facility = @c_Facility AND PD.Loc = L.Loc AND L.LocationCategory = 'ROBOT' )
      )
      BEGIN
         SET @c_flag = 'IGNOR'
         GOTO UPD_TL3_FLAG
      END

      SET @n_Exists = 0
      SELECT @n_Exists = (1)
            ,@c_warehouse_code = ISNULL(RTRIM(Short), '')
      FROM dbo.Codelkup WITH (NOLOCK)
      WHERE ListName = @c_ListName_ROBOTFAC
      AND Code = @c_Facility
      AND StorerKey = @c_StorerKey
      
      IF @c_warehouse_code = '' OR @n_Exists = 0
      BEGIN
         SET @c_flag = 'IGNOR'
         GOTO UPD_TL3_FLAG
      END

      SET @n_Exists = 0
      SELECT 
         @n_Exists = (1)
       , @c_WS_url = ISNULL(RTRIM(Long), '') 
       , @c_user_id = ISNULL(RTRIM(UDF01), '') 
       , @c_user_key = ISNULL(RTRIM(UDF02), '') 
       , @c_IniFilePath = ISNULL(RTRIM(Notes), '') 
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE Listname = @c_ListName_WebService
      AND Code = @c_warehouse_code 
      AND StorerKey = @c_StorerKey
      AND Code2 = 'ORDC'
      
      IF @n_Exists = 0 OR @c_WS_url = '' OR @c_IniFilePath = ''
      BEGIN
         SET @c_flag = '5'
         GOTO UPD_TL3_FLAG
      END

      --Update TL3 TransmitFlag - 1
      UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
      SET transmitflag = @c_flag1
      WHERE transmitlogkey = @c_TransmitlogKey

      --Construct JSON String
      SET @c_FullRequestString = (ISNULL(RTRIM((
         SELECT 
            @c_warehouse_code As 'header.warehouse_code'
          , @c_user_id As 'header.user_id'
          , @c_user_key As 'header.user_key'
          , @n_OrdCount As 'body.order_amount'
          , ( 
               SELECT 
                  @c_Key1 As 'out_order_code'
                , @c_cancel_date As 'cancel_date'
               FOR JSON PATH 
            ) as 'body.order_list'
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      )), ''))

      BEGIN TRY
         IF @b_Debug = 1
         BEGIN
            PRINT '>>> Sending WS Request - ' + @c_WS_url
            PRINT '>>> Display Full Request String - Begin'
            PRINT @c_FullRequestString
            PRINT '>>> Display Full Request String - End'
         END
      
         EXEC master.dbo.isp_GenericWebServiceClient 
              @c_IniFilePath = @c_IniFilePath
      	   , @c_WebRequestURL = @c_WS_url
      	   , @c_WebRequestMethod = @c_WebRequestMethod              --@c_WebRequestMethod
      	   , @c_ContentType = @c_ContentType                        --@c_ContentType
      	   , @c_WebRequestEncoding = @c_WebRequestEncoding          --@c_WebRequestEncoding
      	   , @c_RequestString = @c_FullRequestString                --@c_FullRequestString
      	   , @c_ResponseString = @c_ResponseString         OUTPUT      
      	   , @c_vbErrMsg = @c_vbErrMsg                     OUTPUT		      														 
            , @n_WebRequestTimeout = 120000                          --@n_WebRequestTimeout -- Miliseconds
      	   , @c_NetworkCredentialUserName = ''                      --@c_NetworkCredentialUserName -- leave blank if no network credential
      	   , @c_NetworkCredentialPassword = ''                      --@c_NetworkCredentialPassword -- leave blank if no network credential
      	   , @b_IsSoapRequest = 0                                   --@b_IsSoapRequest  -- 1 = Add SoapAction in HTTPRequestHeader
      	   , @c_RequestHeaderSoapAction = ''                        --@c_RequestHeaderSoapAction -- HTTPRequestHeader SoapAction value
      	   , @c_HeaderAuthorization = ''                            --@c_HeaderAuthorization
      	   , @c_ProxyByPass = '0'                                   --@c_ProxyByPass, 1 >> Set Ip & Port, 0 >> Set Nothing, '' >> Skip Setup
      
      END TRY
      BEGIN CATCH
         SET @c_vbErrMsg = CONVERT(NVARCHAR(5),ISNULL(ERROR_NUMBER() ,0)) + ' - ' + ERROR_MESSAGE()
      
         IF @b_Debug = 1
            PRINT '>>> WS CALL CATCH EXCEPTION - ' + @c_vbErrMsg
      END CATCH
      
      --INSERT LOG
      INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
      VALUES ( @c_Application, @c_WS_url, @c_MessageType, @c_VBErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 230302
         SET @c_ErrMsg = 'NSQL' 
                       + CONVERT(NVARCHAR(6),@n_Err) 
                       + ': failed to get dbo.TCPSocket_OUTLog.(isp_WSITF_GeekPlusRBT_ORDERCANCEL_Outbound)'
         GOTO QUIT
      END
      
      SET @n_LOGSerialNo = SCOPE_IDENTITY()
      
      IF @b_Debug = 1
      BEGIN
         PRINT '>>> @c_VBErrMsg - ' + @c_VBErrMsg
         PRINT '>>> ResponseString - Begin'
         PRINT @c_ResponseString
         PRINT '>>> ResponseString - END'
      END

      IF ISNULL(RTRIM(@c_VBErrMsg), '') <> '' OR ISNULL(RTRIM(@c_ResponseString), '') = ''
      BEGIN
         SET @c_flag = '5'
      END
      ELSE
      BEGIN
         SET @c_flag = '9'
      END

      UPD_TL3_FLAG:
      IF @b_Debug = 1
      BEGIN
         PRINT '>>>>> UPD_TL3_FLAG'
         PRINT '@c_flag: ' + @c_flag
      END

      UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
      SET transmitflag = @c_flag
      WHERE transmitlogkey = @c_TransmitlogKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 230303
         SET @c_ErrMsg = 'NSQL' 
                       + CONVERT(NVARCHAR(6),@n_Err) 
                       + ': failed to update TRANSMITLOG3 - flag(' + @c_flag + ').(isp_WSITF_GeekPlusRBT_ORDERCANCEL_Outbound)'
         GOTO QUIT
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

   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>> EXIT SP'
      PRINT '@n_Err: ' + CONVERT(NVARCHAR, @n_Err) + ', @c_ErrMsg: ' + @c_ErrMsg + ', @b_Success: ' + CONVERT(NVARCHAR, @b_Success)
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_ORDERCANCEL_Outbound - END'
   END 
   
   WHILE @@TRANCOUNT < @n_StartCnt      
      BEGIN TRAN

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
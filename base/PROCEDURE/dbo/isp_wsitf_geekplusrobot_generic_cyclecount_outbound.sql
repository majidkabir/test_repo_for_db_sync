SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Store procedure: isp_WSITF_GeekPlusRobot_Generic_CycleCount_Outbound  */
/* Creation Date: 15-JUN-2020                                            */
/* Copyright: IDS                                                        */
/* Written by: AlexKeoh                                                  */
/*                                                                       */
/* Purpose: Pass Incoming Request String For Interface                   */
/*                                                                       */
/* Input Parameters:                                                     */
/*                                                                       */
/* Output Parameters: @b_Success          - Success Flag  = 0            */
/*                    @n_Err              - Error No      = 0            */
/*                    @c_ErrMsg           - Error Message = ''           */
/*                                                                       */
/* Called By: QueueCommander                                             */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 1.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date           Author         Purposes											 */
/* 2020-06-15     Alex           Initial - Jira #WMS-13305               */
/*************************************************************************/
CREATE PROC [dbo].[isp_WSITF_GeekPlusRobot_Generic_CycleCount_Outbound](         
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
   
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT
         , @n_StartCnt                    INT

         , @c_Application                 NVARCHAR(50)
         , @c_MessageType                 NVARCHAR(10)
         , @c_flag                        NVARCHAR(10)
         , @c_flag0                       NVARCHAR(1)
         , @c_flag1                       NVARCHAR(1)
         , @c_flag5                       NVARCHAR(1)
         , @c_flag9                       NVARCHAR(1)

         , @n_Exists                      INT

         , @c_TLKey1                      NVARCHAR(30)
         , @c_TLKey2                      NVARCHAR(30)
         , @c_TLKey3                      NVARCHAR(30)
         , @c_TableName                   NVARCHAR(30)
         , @c_StorerKey                   NVARCHAR(15)

         , @c_Facility                    NVARCHAR(5)
         , @c_Key1                        NVARCHAR(60)

         , @c_IniFilePath                 VARCHAR(225) 
         , @c_WebRequestMethod            VARCHAR(10)
         , @c_ContentType                 VARCHAR(100)
         , @c_WebRequestEncoding          VARCHAR(30)
         , @c_WS_url                      NVARCHAR(250)

         , @n_IsExists                    INT
         , @c_ReservedSQLQuery1             NVARCHAR(MAX)
         , @c_SQLQuery                    NVARCHAR(MAX)
         , @c_SQLParams                   NVARCHAR(2000)

         , @c_transaction_id              NVARCHAR(10)
         , @c_FullRequestString           NVARCHAR(MAX)

         , @n_LOGSerialNo                 INT
         , @c_ResponseString              NVARCHAR(MAX)
         , @c_vbErrMsg                    NVARCHAR(MAX)
         , @c_Resp_MsgCode                NVARCHAR(10)
         , @c_Resp_Msg                    NVARCHAR(200)
         , @b_Resp_Success                BIT

         , @c_ListName_GeekAlert          NVARCHAR(10)
         , @b_SendAlert                   INT
         , @n_EmailGroupId                INT
         , @c_EmailTitle                  NVARCHAR(100)


   DECLARE @c_warehouse_code              NVARCHAR(16)
         , @c_user_id                     NVARCHAR(16)
         , @c_user_key                    NVARCHAR(16)         
         , @c_owner_code                  NVARCHAR(16)

         , @c_DocType                     NVARCHAR(10)
         , @c_DocNo                       NVARCHAR(32)
         , @c_ConsigneeKey                NVARCHAR(32)      
         , @c_DTSITF_DBName               NVARCHAR(50)

         , @n_type                        INT

   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT
   SET @c_VBErrMsg                        = ''

   SET @b_Success                         = 0
   SET @n_Err                             = 0
   SET @c_ErrMsg                          = ''
   --SET @c_InTransmitLogKey                = ISNULL(RTRIM(@c_InTransmitLogKey), '')

   SET @c_Application                     = 'GEEK+_CYCLECOUNT_OUT'
   SET @c_MessageType                     = 'WS_OUT'
   SET @c_flag                            = ''
   SET @c_flag0                           = '0'
   SET @c_flag1                           = '1'
   SET @c_flag5                           = '5'
   SET @c_flag9                           = '9'

   SET @c_SQLQuery                        = ''
   SET @c_SQLParams                       = ''

   SET @c_WebRequestMethod                = 'POST'
   SET @c_ContentType                     = 'application/json'
   SET @c_WebRequestEncoding              = 'UTF-8'
   SET @c_WS_url                          = ''

   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRobot_Generic_CycleCount_Outbound - INITAL BEGIN'
      PRINT '@c_TransmitlogKey: ' + @c_TransmitlogKey
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRobot_Generic_CycleCount_Outbound - INITAL END'
   END 

   SET @n_Exists = 0
   SELECT @n_Exists = (1)
         ,@c_TableName = ISNULL(RTRIM(TableName), '')
         ,@c_TLKey1 = ISNULL(RTRIM(Key1), '')
         ,@c_TLKey2 = ISNULL(RTRIM(Key2), '')
         ,@c_StorerKey = ISNULL(RTRIM(Key3), '')
   FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
   WHERE transmitlogkey = @c_TransmitlogKey 
   AND transmitflag = @c_flag0

   IF @n_Exists = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 230500
      SET @c_ErrMsg = 'No records found in TRANSMITLOG3 table..'
      GOTO QUIT
   END

   IF @c_TableName <> 'RBTCYCLECOUNT'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 230501
      SET @c_ErrMsg = 'Invalid TransmitLog3 TableName..'
      GOTO QUIT
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT '>>>>>>>> isp_WSITF_GeekPlusRobot_Generic_CycleCount_Outbound - BEGIN'
         PRINT '@c_StorerKey: ' + @c_StorerKey 
         PRINT '@c_TLKey1: ' + @c_TLKey1 + ', @c_TLKey2: ' + @c_TLKey2
      END 

      SET @n_IsExists = 0
      SELECT 
         @n_IsExists = (1),
         @c_owner_code = ISNULL(RTRIM(Short), '') 
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE Listname = 'ROBOTSTR'
      AND Code = @c_StorerKey 
      AND StorerKey = @c_StorerKey

      IF @n_IsExists = 0
      BEGIN
         SET @c_flag = 'IGNOR'
         GOTO UPD_TL_AFTER_PROCESS
      END

      SET @n_IsExists = 0
      SELECT @n_IsExists = (1)
           , @c_Facility = Facility
      FROM dbo.WorkOrder WITH (NOLOCK) 
      WHERE WorkOrderKey = @c_TLKey1

      IF @n_IsExists = 0
      BEGIN
         SET @c_ErrMsg = 'WorkOrder Record Not found! WorkOrderKey: ' + @c_TLKey1
      
         INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
         VALUES ( @c_Application, @c_WS_url, 'TRACE_ERR', @c_ErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )
         
         SET @c_flag = 'IGNOR'
         GOTO UPD_TL_AFTER_PROCESS
      END

      SET @n_IsExists = 0
      SELECT 
         @n_IsExists = (1),
         @c_warehouse_code = ISNULL(RTRIM(Short), '') 
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE Listname = 'ROBOTFAC'
      AND Code = @c_Facility 
      AND StorerKey = @c_StorerKey

      IF @n_IsExists = 0
      BEGIN
         SET @c_ErrMsg = 'ROBOTFAC is not setup in Codelkup! WMSFacility=' + @c_Facility
      
         INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
         VALUES ( @c_Application, @c_WS_url, 'TRACE_ERR', @c_ErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )

         SET @c_flag = 'IGNOR'
         GOTO UPD_TL_AFTER_PROCESS
      END

      SET @n_Exists = 0
      SELECT 
         @n_Exists = (1),
         @c_WS_url = Long,
         @c_user_id = UDF01,
         @c_user_key = UDF02,
         @c_IniFilePath = Notes
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE Listname = 'WebService'
      AND Code = @c_warehouse_code 
      AND StorerKey = @c_StorerKey
      AND Code2 = 'CYLECOUNT'

      IF ISNULL(RTRIM(@c_WS_url), '') = '' OR @n_Exists = 0
      BEGIN
         SET @c_flag = 'IGNOR'
         GOTO UPD_TL_AFTER_PROCESS
      END

      SET @n_Exists = 0
      SELECT @n_IsExists = (1)
            ,@c_ReservedSQLQuery1 = ISNULL(RTRIM(ReservedSQLQuery1), '')
      FROM [dbo].[GEEKPBOT_INTEG_CONFIG] WITH (NOLOCK)
      WHERE InterfaceName = 'CYCLECOUNT_OUTBOUND' AND StorerKey = @c_StorerKey
      
      IF @n_IsExists = 0 OR @c_ReservedSQLQuery1 = ''
      BEGIN
         SET @c_ErrMsg = '[dbo].[GEEKPBOT_INTEG_CONFIG](InterfaceName=CYCLECOUNT_OUTBOUND, StorerKey='
                       + @c_StorerKey + ') is not setup.(isp_WSITF_GeekPlusRobot_Generic_CycleCount_Outbound)'
      
         INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
         VALUES ( @c_Application, @c_WS_url, 'TRACE_ERR', @c_ErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )
                     
         SET @c_flag = 'IGNOR'
         GOTO UPD_TL_AFTER_PROCESS
      END

      --Execute Dynamic ReservedSQLQuery1 (BEGIN)
      BEGIN TRY
         SET @c_SQLQuery = N'SELECT @c_FullRequestString = (ISNULL(RTRIM(( ' 
                    + @c_ReservedSQLQuery1 
                    + N')),''''))'
      
         SET @c_SQLParams = N'@c_TLKey1 NVARCHAR(30), @c_TLKey2 NVARCHAR(30), @c_StorerKey NVARCHAR(15),'
                          + N'@c_warehouse_code NVARCHAR(16), @c_user_id NVARCHAR(16), @c_user_key NVARCHAR(16), '
                          + N'@c_owner_code NVARCHAR(16), @c_FullRequestString NVARCHAR(MAX) OUTPUT'
      
         IF @b_Debug = 1
         BEGIN
            PRINT '>==================================================>'
            PRINT '>>>> Full ReservedSQLQuery1 (BEGIN)'
            PRINT @c_SQLQuery
            PRINT '>>>> Full ReservedSQLQuery1 (END)'
            PRINT '>==================================================>'
         END
      
         EXEC sp_ExecuteSql @c_SQLQuery
                          , @c_SQLParams
                          , @c_TLKey1, @c_TLKey2, @c_StorerKey
                          , @c_warehouse_code, @c_user_id, @c_user_key
                          , @c_owner_code, @c_FullRequestString OUTPUT
      END TRY
      BEGIN CATCH
         SET @c_ErrMsg = 'Execute ReservedSQLQuery1 Error - ' + ERROR_MESSAGE()
      
         INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
         VALUES ( @c_Application, @c_WS_url, 'TRACE_ERR', @c_ErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )
      
         IF @b_Debug = 1
         BEGIN
            PRINT '>>> GEN REQUEST QUERY CATCH EXCEPTION - ' + @c_ErrMsg
         END
         GOTO QUIT
      END CATCH
      --Execute Dynamic ReservedSQLQuery1 (END)

      --Send Request (BEGIN)
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
            , @n_WebRequestTimeout = 180000                          --@n_WebRequestTimeout -- Miliseconds
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
         SET @n_Err = 100004
         SET @c_ErrMsg = 'failed to get dbo.TCPSocket_OUTLog'
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
      
      --Unexpected error from Geek+ API server
      --Quit cursor and send alert notification
      
      IF ISNULL(RTRIM(@c_VBErrMsg), '') <> ''
      BEGIN
         SET @b_SendAlert = 1
         SET @c_flag = @c_flag5
         SET @c_ErrMsg = IIF(@n_LOGSerialNo > 0, ('Log Serial No (' + CONVERT(NVARCHAR, @n_LOGSerialNo) + ') - '), '') 
                        + @c_VBErrMsg
         GOTO UPD_TL_AFTER_PROCESS
      END
      
      IF ISNULL(RTRIM(@c_ResponseString), '') = ''
      BEGIN
         SET @b_SendAlert = 1
         SET @c_flag = @c_flag5
         SET @c_ErrMsg = IIF(@n_LOGSerialNo > 0, ('Log Serial No (' + CONVERT(NVARCHAR, @n_LOGSerialNo) + ' - '), '') 
                        + 'Response String returned from GEEK+ server is empty..'
         GOTO UPD_TL_AFTER_PROCESS
      END
      
      SELECT 
         @c_Resp_MsgCode = MsgCode, 
         @c_Resp_Msg = Msg, 
         @b_Resp_Success = Success
      FROM OPENJSON(@c_ResponseString)
      WITH (
         MsgCode     NVARCHAR(10)    '$.header.msgCode',
         Msg         NVARCHAR(60)    '$.header.message',
         Success     BIT             '$.body.success'
      )
      
      IF @b_Debug = 1
      BEGIN
         PRINT '>>> Response JSON Body'
         PRINT 'Success - ' + CONVERT(NVARCHAR, @b_Resp_Success) + ', MsgCode - ' + @c_Resp_MsgCode + ', Message - ' + @c_Resp_Msg
      END
      
      --Unexpected error from Geek+ API server
      --Quit cursor and send alert notification
      IF @b_Resp_Success <> 1
      BEGIN
         SET @c_flag = @c_flag5
         SET @c_ErrMsg = (@c_Resp_MsgCode + ': ' + @c_Resp_Msg)
      END
      ELSE 
      BEGIN
         SET @c_flag = @c_flag9
      END

      --Send Request (END)

      UPD_TL_AFTER_PROCESS:
      UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
      SET transmitflag = @c_flag
      WHERE transmitlogkey =  @c_TransmitLogKey
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 230301
         SET @c_ErrMsg = 'failed to update transmitflag of transmitlog3.'
         GOTO QUIT
      END
   END

QUIT:
   --Send Error Notification
   IF @b_SendAlert = 1 AND ISNULL(RTRIM(@c_ErrMsg), '') <> ''
   BEGIN
      SELECT @n_EmailGroupId = ISNULL(TRY_CONVERT(INT, ISNULL(RTRIM(Short), '0')), 0)
           , @c_EmailTitle = ISNULL(RTRIM([Description]), '')
           , @c_DTSITF_DBName = ISNULL(RTRIM(UDF03), '')
      FROM dbo.Codelkup WITH (NOLOCK)
      WHERE ListName = 'GEEK+ALERT' AND Code = @c_Application
      AND StorerKey = @c_StorerKey

      IF @n_EmailGroupId > 0 AND @c_DTSITF_DBName <> ''
      BEGIN
         EXEC [dbo].[isp_GeekPlusRBT_SendEmailAlert]
           @c_DTSITF_DBName               --@c_DTSITF_DBName
         , @n_EmailGroupId                --@n_EmailTo
         , @c_EmailTitle                  --@c_Subject
         , @c_ErrMsg                      --@c_EmailBody
         , @b_Success           OUTPUT
      END
   END

   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>> EXIT SP'
      PRINT '@n_Err: ' + CONVERT(NVARCHAR, @n_Err) + ', @c_ErrMsg: ' + @c_ErrMsg + ', @b_Success: ' + CONVERT(NVARCHAR, @b_Success)
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRobot_Generic_CycleCount_Outbound - END'
   END 

   IF OBJECT_ID('tempdb..#TEMP_Geek_ORD_List') IS NOT NULL
      DROP TABLE #TEMP_Geek_ORD_List

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_ORDOUT_LOOPORD') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_ORDOUT_LOOPORD  
      DEALLOCATE GEEKPLUS_ORDOUT_LOOPORD  
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
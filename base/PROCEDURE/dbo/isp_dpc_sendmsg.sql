SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: BondDPC Integration SP                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2013-02-15 1.0  Shong      Created                                         */
/* 2014-05-15 1.1  Shong      Add Device Type                                 */
/* 2014-06-10 1.2  Chee       Add DeviceID (Chee01)                           */
/* 2014-05-27 1.3  James      Bypass calling isp_GenericTCPSocketClient       */
/*                            when config turn on (james01)                   */
/* 2015-07-07 1.4  Ung        Update EditDate, EditWho                        */
/* 2017-02-27 1.5  TLTING     Variable Nvarchar                               */
/******************************************************************************/

CREATE PROC [dbo].[isp_DPC_SendMsg]
(
   @c_StorerKey  NVARCHAR(15)
  ,@c_Message    NVARCHAR(2000)
  ,@b_Success    INT           OUTPUT
  ,@n_Err        INT           OUTPUT
  ,@c_ErrMsg     NVARCHAR(215) OUTPUT
  ,@c_DeviceType NVARCHAR(20) = ''
  ,@c_DeviceID   NVARCHAR(20) = ''

)
AS
BEGIN
   SET NOCOUNT ON

   DECLARE
      @c_IniFilePath        NVARCHAR(100),
      @c_RemoteEndPoint     NVARCHAR(50),
      @c_SendMessage        VARCHAR(4000),
      @c_LocalEndPoint      VARCHAR(50) ,
      @c_ReceiveMessage     VARCHAR(4000),
      @c_vbErrMsg           VARCHAR(4000),
      @n_DataLength           INT,
      @c_DPC_MessageNo        NVARCHAR(20),
      @c_MessageNum_Out       VARCHAR(20),
      @n_Continue             INT,
      @n_SerialNo_Out         INT,
      @n_Status_Out           INT,
      @c_DPC_RtnMessage       VARCHAR(1000),
      @c_DPC_RtnStatus        VARCHAR(10),
      @n_StartTCnt            INT,
      @n_IsRDT                INT,
      @c_DPC_RefNo            VARCHAR(20),
      @c_BypassTCPSocketClient NVARCHAR(1)

      SET @n_StartTCnt = @@TRANCOUNT
      SET @n_Err = 0

      BEGIN TRANSACTION

      SET @n_Continue = 1

      -- (Chee01)
      IF ISNULL(RTRIM(@c_DeviceID),'') <> ''
      BEGIN
         SELECT TOP 1
                @c_IniFilePath = c.UDF01,
                @c_RemoteEndPoint = c.Long
         FROM CODELKUP c WITH (NOLOCK)
         WHERE ListName    = 'TCPClient'
         AND   c.Short     = 'LIGHT'
         AND   c.StorerKey = @c_StorerKey
         AND   c.Code      = @c_DeviceID
      END

      -- (Chee01)
      IF ISNULL(RTRIM(@c_IniFilePath),'') = ''
      BEGIN
         IF ISNULL(RTRIM(@c_DeviceType),'') = ''
         BEGIN
            SELECT TOP 1
                   @c_IniFilePath = c.UDF01,
                   @c_RemoteEndPoint = c.Long
            FROM CODELKUP c WITH (NOLOCK)
            WHERE ListName = 'TCPClient'
            AND   c.Short  = 'LIGHT'
            AND   c.StorerKey = @c_StorerKey
         END
         ELSE
         BEGIN
            SELECT TOP 1
                   @c_IniFilePath = c.UDF01,
                   @c_RemoteEndPoint = c.Long
            FROM CODELKUP c WITH (NOLOCK)
            WHERE ListName = 'TCPClient'
            AND   c.Code   = @c_DeviceType
            AND   c.Short  = 'LIGHT'
            AND   c.StorerKey = @c_StorerKey
         END
      END

      IF ISNULL(RTRIM(@c_IniFilePath),'') = ''
      BEGIN
         SET @b_Success = 0
         SET @n_Err = 80451
         SET @c_ErrMsg = 'File Path (UDF01) - TCPClientSetup Record Not Found CodeLkUp Table'
         SET @n_Continue = 3
         GOTO EXIT_SP
      END

      IF LEN(@c_RemoteEndPoint) < 15
      BEGIN
         SET @b_Success = 0
         SET @n_Err = 80452
         SET @c_ErrMsg = 'Communication IP & Port (Long) Not Found CodeLkUp Table'
         SET @n_Continue = 3
         GOTO EXIT_SP
      END

      SET @b_Success = 0

      EXECUTE nspg_GetKey
         'TCPOUTLog',
         9,
         @c_MessageNum_Out OUTPUT,
         @b_Success        OUTPUT,
         @n_Err            OUTPUT,
         @c_ErrMsg         OUTPUT

      IF @b_Success = 1
      BEGIN
         SET @c_DPC_MessageNo = 'C' + @c_MessageNum_Out
      END

   SET @n_DataLength = 0
   --SET @c_IniFilePath = 'C:\COMObject\GenericTCPSocketClient\config.ini'
   --SET @c_RemoteEndPoint = '172.26.193.39:5003'
   SET @n_DataLength = [dbo].[fnc_DPC_GetMsgLength](@c_DPC_MessageNo + '<TAB>' + @c_Message)

   SET @c_SendMessage = 'STX<TAB>' + CAST(@n_DataLength AS VARCHAR(10)) + '<TAB>' + @c_DPC_MessageNo + '<TAB>' +
                        @c_Message + '<TAB>ETX'


   INSERT INTO TCPSocket_OUTLog
      (MessageNum, MessageType, [Application], Data, Status, StorerKey, LabelNo, BatchNo, RemoteEndPoint)
   VALUES
      (@c_DPC_MessageNo, 'SEND', 'DPC_Interface', @c_SendMessage, '0', @c_StorerKey, '', '', @c_RemoteEndPoint)


   SELECT @n_SerialNo_Out = SerialNo
   FROM   dbo.TCPSocket_OUTLog WITH (NOLOCK)
   WHERE  MessageNum    = @c_DPC_MessageNo
   AND    MessageType   = 'SEND'
   AND    Status        = '0'

   SET @b_Success = 0

   EXECUTE nspg_GetKey
      'TCPOUTLog',
      9,
      @c_MessageNum_Out OUTPUT,
      @b_Success        OUTPUT,
      @n_Err            OUTPUT,
      @c_ErrMsg         OUTPUT

   IF @b_Success = 1
   BEGIN
      SET @c_DPC_MessageNo = 'C' + @c_MessageNum_Out
   END

   SET @c_BypassTCPSocketClient = ''
   EXECUTE nspGetRight
      NULL,
      @c_StorerKey,
      NULL,
      'BypassTCPSocketClient',
      @b_success                 OUTPUT,
      @c_BypassTCPSocketClient   OUTPUT,
      @n_Err                     OUTPUT,
      @c_errmsg                  OUTPUT

   SET @c_vbErrMsg = ''
   SET @c_ReceiveMessage = ''

   IF @c_BypassTCPSocketClient <> '1'
   BEGIN
      EXEC [master].[dbo].[isp_GenericTCPSocketClient]        
       @c_IniFilePath,        
       @c_RemoteEndPoint,        
       @c_SendMessage,        
       @c_LocalEndPoint     OUTPUT,        
       @c_ReceiveMessage    OUTPUT,        
       @c_vbErrMsg          OUTPUT        
   END

--   SELECT         
--      @c_SendMessage '@c_SendMessage',          
--    @c_LocalEndPoint '@c_LocalEndPoint',      
--    @c_ReceiveMessage '@c_ReceiveMessage',          
--    @c_vbErrMsg '@c_vbErrMsg'        
        
   IF ISNULL(RTRIM(@c_vbErrMsg),'') <> ''        
   BEGIN        
      SET @n_Status_Out = 5        
              
      UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)           
      SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)           
           , ErrMsg = ISNULL(@c_vbErrMsg, '')           
           , LocalEndPoint = @c_LocalEndPoint
           , EditDate = GETDATE()
           , EditWho = SUSER_SNAME()
      WHERE  SerialNo = @n_SerialNo_Out

      SET @b_Success=0
      SET @n_Err = 80453
      SET @c_ErrMsg = @c_vbErrMsg
   END
   ELSE
   IF ISNULL(RTRIM(@c_ReceiveMessage),'') <> ''
   BEGIN
      EXEC [dbo].[isp_DPC_GetRtnStatus] @c_ReceiveMessage, @c_DPC_RtnStatus OUTPUT,@c_DPC_RtnMessage OUTPUT, @c_DPC_RefNo OUTPUT

      IF @c_DPC_RtnStatus = 'NO'
      BEGIN
         SET @n_Status_Out = 5

         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)
         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)
              , ErrMsg = ISNULL(@c_DPC_RtnMessage, '')
              , LocalEndPoint = @c_LocalEndPoint
              , EditDate = GETDATE()
              , EditWho = SUSER_SNAME()
         WHERE  SerialNo = @n_SerialNo_Out

         SET @b_Success=0
         SET @n_Err = 80454
         SET @c_ErrMsg = @c_DPC_RtnMessage

      END
      ELSE
      BEGIN
          SET @n_Status_Out = 9

         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)
         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)
              , ErrMsg = ISNULL(@c_ReceiveMessage, '')
              , LocalEndPoint = @c_LocalEndPoint
              , EditDate = GETDATE()
              , EditWho = SUSER_SNAME()
         WHERE  SerialNo = @n_SerialNo_Out

         SET @b_Success=1
         SET @n_Err = 0
         SET @c_ErrMsg = ''
      END
   END


EXIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
       --DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1 -- (ChewKP01)
      BEGIN
          -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
          -- Instead we commit and raise an error back to parent, let the parent decide

          -- Commit until the level we begin with
          WHILE @@TRANCOUNT > @n_StartTCnt
             COMMIT TRAN

          -- Raise error with severity = 10, instead of the default severity 16.
          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
          RAISERROR (@n_err, 10, 1) WITH SETERROR

          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         ROLLBACK TRAN


         WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
         COMMIT TRAN

         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_DPC_SendMsg'

         RETURN
      END

   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
         COMMIT TRAN

      RETURN
   END
END -- procedure

GO
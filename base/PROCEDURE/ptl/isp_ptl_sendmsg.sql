SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Stored Procedure: isp_PTL_SendMsg                                          */
/* Copyright: IDS                                                             */
/* Purpose: BondDPC Integration SP                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2013-02-15 1.0  Shong      Created                                         */
/* 2019-01-22 1.1  ChewKP     Add Error Message                               */
/* 2019-07-06 1.2  YeeKung    Add storerconfigure fro multiple junction box   */
/*                            with one storer doing PTS   (yeekung01)         */
/* 2023-04-06 1.3  yeekung    WMS-22163 Merge all lightup                     */ 
/******************************************************************************/
CREATE   PROC [PTL].[isp_PTL_SendMsg]
(
   @c_StorerKey  NVARCHAR(15)
  ,@c_Message    NVARCHAR(2000)
  ,@b_Success    INT           OUTPUT
  ,@n_Err        INT           OUTPUT
  ,@c_ErrMsg     NVARCHAR(215) OUTPUT
  ,@c_DeviceType NVARCHAR(20) = ''
  ,@c_DeviceID   NVARCHAR(20) = ''
  ,@n_Func       INT = ''
  ,@cPTSZone     NVARCHAR(10) = ''
  ,@cLightcmd    NVARCHAR(MAX) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @c_IniFilePath        NVARCHAR(100),
      @c_RemoteEndPoint     NVARCHAR(50),
      @c_SendMessage        VARCHAR(4000),
      @c_LocalEndPoint      VARCHAR(50) ,
      @c_ReceiveMessage     VARCHAR(4000),
      @c_vbErrMsg           VARCHAR(4000),
      @n_DataLength           INT,
      @c_PTL_MessageNo        VARCHAR(20),
      --@c_MessageNum_Out       VARCHAR(20),
      @n_Continue             INT,
      @n_SerialNo_Out         INT,
      @n_Status_Out           INT,
      @c_PTL_RtnMessage       VARCHAR(1000),
      @c_PTL_RtnStatus        VARCHAR(10),
      @n_StartTCnt            INT,
      @n_IsRDT                INT,
      @c_PTL_RefNo            VARCHAR(20),
      @c_BypassTCPSocketClient NVARCHAR(1),
      @n_LightLinkLogKey      INT,
      @cMultiJuncBox          INT

      SET @n_StartTCnt = @@TRANCOUNT
      SET @n_Err = 0

      BEGIN TRANSACTION
      SAVE TRAN isp_PTL_SendMsg

      SET @n_Continue = 1

      SET @cMultiJuncBox = rdt.RDTGetConfig( @n_Func, 'StorerMultiJuncBox', @c_StorerKey)

      -- (Chee01)
      IF ISNULL(RTRIM(@c_DeviceID),'') <> ''
      BEGIN
         SELECT TOP 1
                @c_IniFilePath = c.UDF01,
                @c_RemoteEndPoint = c.Long
         FROM CODELKUP c WITH (NOLOCK)
         WHERE ListName    = 'TCPClient'
         AND   c.Short     = 'LIGHT'
         AND   c.Code      = @c_DeviceID
      END

      -- (Chee01)
      IF ISNULL(RTRIM(@c_IniFilePath),'') = ''
      BEGIN
         SET @cMultiJuncBox='1'
         SET @c_DeviceType=''
         --yeekung01
         IF @cMultiJuncBox = 1
         BEGIN
            IF ISNULL(RTRIM(@c_DeviceType),'') = ''
            BEGIN
               SELECT TOP 1
                      @c_IniFilePath = c.UDF01,
                      @c_RemoteEndPoint = c.Long
               FROM CODELKUP c WITH (NOLOCK)
               WHERE ListName = 'TCPClient'
               AND   c.Short  = 'LIGHT'
               AND   c.code2  = @cPTSZone
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
               AND   c.code2  = @cPTSZone
            END
         END
         ELSE
         BEGIN
            IF ISNULL(RTRIM(@c_DeviceType),'') = ''
            BEGIN
               SELECT TOP 1
                      @c_IniFilePath = c.UDF01,
                      @c_RemoteEndPoint = c.Long
               FROM CODELKUP c WITH (NOLOCK)
               WHERE ListName = 'TCPClient'
               AND   c.Short  = 'LIGHT'


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
            END
         END
      END

      IF ISNULL(RTRIM(@c_IniFilePath),'') = ''
      BEGIN
         SET @b_Success = 0
         SET @n_Err = 94001
         SET @c_ErrMsg = 'File Path (UDF01) - TCPClientSetup Record Not Found CodeLkUp Table'
         SET @n_Continue = 3
         GOTO RollBackTran
      END

      IF LEN(@c_RemoteEndPoint) < 15
      BEGIN
         SET @b_Success = 0
         SET @n_Err = 94002
         SET @c_ErrMsg = 'Communication IP & Port (Long) Not Found CodeLkUp Table'
         SET @n_Continue = 3
         GOTO RollBackTran
      END

      SET @b_Success = 0


   SET @n_LightLinkLogKey = CAST(@c_Message AS INT)

   IF ISNULL (@cLightcmd,'')<>''
      SET @c_SendMessage = @cLightcmd
   ELSE
   SET @c_SendMessage = '<STX>' + RTRIM(@c_Message) + '<ETX>'




   INSERT INTO TCPSocket_OUTLog
      (MessageNum, MessageType, [Application], Data, Status, StorerKey, LabelNo, BatchNo, RemoteEndPoint)
   VALUES
      ('', 'SEND', 'LF_LightLink', @c_SendMessage, '0', @c_StorerKey, '', '', @c_RemoteEndPoint)

   SET @n_SerialNo_Out = @@identity
   SET @b_Success = 0

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

   IF ISNULL(RTRIM(@c_vbErrMsg),'') <> ''
   BEGIN
      SET @n_Status_Out = 5

      SET @n_Err = 94009
      SET @c_ErrMsg = @c_vbErrMsg

      UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)
      SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)
           , ErrMsg = ISNULL(@c_vbErrMsg, '')
           , LocalEndPoint = @c_LocalEndPoint
           --, EndTime = GetDate()
      WHERE  SerialNo = @n_SerialNo_Out

      IF @@ERROR <> 0
      BEGIN
         SET @b_Success=0
         SET @n_Err = 94003
         SET @c_ErrMsg = @c_vbErrMsg
         SET @n_Continue = 3
         GOTO RollBackTran
      END

      UPDATE PTL.LFLightLinkLOG WITH (ROWLOCK)
      SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)
           , ErrMsg = ISNULL(@c_vbErrMsg, '')
           , LocalEndPoint = @c_LocalEndPoint
           , EndTime = GetDate()
      WHERE  SerialNo = @n_LightLinkLogKey

      IF @@ERROR <> 0
      BEGIN
         SET @b_Success=0
         SET @n_Err = 94004
         SET @c_ErrMsg = @c_vbErrMsg
         SET @n_Continue = 3
         GOTO RollBackTran
      END
   END
   ELSE
   IF ISNULL(RTRIM(@cLightcmd),'') = ''
   BEGIN
      EXEC [PTL].[isp_PTL_GetRtnStatus] @c_ReceiveMessage, @c_PTL_RtnStatus OUTPUT,@c_PTL_RtnMessage OUTPUT, @c_PTL_RefNo OUTPUT

      IF @c_PTL_RtnStatus = 'NO'
      BEGIN
         SET @n_Status_Out = 5

         SET @n_Err = 94010
         SET @c_ErrMsg = 'TCPSocketError'

         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)
         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)
              , ErrMsg = ISNULL(@c_PTL_RtnMessage, '')
              , LocalEndPoint = @c_LocalEndPoint
              --, EndTime = GetDate()
         WHERE  SerialNo = @n_SerialNo_Out

         IF @@ERROR <> 0
         BEGIN
            SET @b_Success=0
            SET @n_Err = 94005
            SET @c_ErrMsg = @c_PTL_RtnMessage
         END

         UPDATE PTL.LFLightLinkLOG WITH (ROWLOCK)
         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)
              , ErrMsg = ISNULL(@c_vbErrMsg, '')
              , LocalEndPoint = @c_LocalEndPoint
              , EndTime = GetDate()
         WHERE  SerialNo = @n_LightLinkLogKey

         IF @@ERROR <> 0
         BEGIN
            SET @b_Success=0
            SET @n_Err = 94006
            SET @c_ErrMsg = @c_vbErrMsg
         END
      END
      ELSE
      BEGIN
         SET @n_Status_Out = 9



         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)
         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)
              , ErrMsg = ISNULL(@c_ReceiveMessage, '')
              , LocalEndPoint = @c_LocalEndPoint
              --, EndTime = GetDate()
         WHERE  SerialNo = @n_SerialNo_Out

         IF @@ERROR <> 0
         BEGIN
            SET @b_Success=0
            SET @n_Err = 94007
            SET @c_ErrMsg = @c_vbErrMsg
            SET @n_Continue = 3
            GOTO RollBackTran
         END



         UPDATE PTL.LFLightLinkLOG WITH (ROWLOCK)
         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)
              , ErrMsg = ISNULL(@c_vbErrMsg, '')
              , LocalEndPoint = @c_LocalEndPoint
              , EndTime = GetDate()
         WHERE  SerialNo = @n_LightLinkLogKey

         IF @@ERROR <> 0
         BEGIN
            SET @b_Success=0
            SET @n_Err = 94008
            SET @c_ErrMsg = @c_vbErrMsg
            SET @n_Continue = 3
            GOTO RollBackTran
         END


      END
   END


--EXIT_SP:

GOTO EXIT_SP

RollBackTran:
   ROLLBACK TRAN isp_PTL_SendMsg -- Only rollback change made here

EXIT_SP:
   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
      COMMIT TRAN isp_PTL_SendMsg


--   IF @n_Continue=3  -- Error Occured - Process And Return
--   BEGIN
--       --DECLARE @n_IsRDT INT
--      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
--
--      IF @n_IsRDT = 1 -- (ChewKP01)
--      BEGIN
--          -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
--          -- Instead we commit and raise an error back to parent, let the parent decide
--
--          -- Commit until the level we begin with
--          WHILE @@TRANCOUNT > @n_StartTCnt
--             COMMIT TRAN
--
--          -- Raise error with severity = 10, instead of the default severity 16.
--          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
--          RAISERROR (@n_err, 10, 1) WITH SETERROR
--
--          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
--      END
--      ELSE
--      BEGIN
--         ROLLBACK TRAN
--
--
--         WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
--         COMMIT TRAN
--
--         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_PTL_SendMsg'
--
--         RETURN
--      END
--
--   END
--   ELSE
--   BEGIN
--      WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
--         COMMIT TRAN
--
--      RETURN
--   END
END -- procedure

GO
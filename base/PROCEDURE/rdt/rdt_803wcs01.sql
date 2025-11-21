SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_803WCS01                                        */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Send carton to WCS                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2023-05-02   Ung       1.0   WMS-22221 Created                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_803WCS01]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cStation      NVARCHAR( 10),
   @cMethod       NVARCHAR( 1),
   @cSKU          NVARCHAR( 20),
   @cIPAddress    NVARCHAR( 40),
   @cPosition     NVARCHAR( 10),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess          INT
   DECLARE @cWaveKey          NVARCHAR( 10)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cCartonID         NVARCHAR( 20)

   DECLARE @cMessageID        NVARCHAR( 10)
   DECLARE @nSerialNo         BIGINT
   DECLARE @cIniFilePath      NVARCHAR( 200)
   DECLARE @cLocalEndPoint    NVARCHAR( 50)
   DECLARE @cRemoteEndPoint   NVARCHAR( 50)
   DECLARE @cApplication      NVARCHAR( 50) = 'GenericTCPSocketClient_WCS'
   DECLARE @cSendMessage      NVARCHAR( MAX)
   DECLARE @cReceiveMessage   NVARCHAR( MAX)
   DECLARE @cStatus           NVARCHAR( 1) = '9'
   DECLARE @nNoOfTry          INT = 0
   DECLARE @cVBErrMsg         NVARCHAR( MAX)

   -- Get carton info
   SELECT
      @cOrderKey = OrderKey,
      @cCartonID = CartonID
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
   WHERE Station = @cStation
      AND Position = @cPosition

   -- Get order info
   SELECT @cWaveKey = UserDefine09
   FROM dbo.Orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   -- Get interface info
   SELECT
      @cRemoteEndPoint = Long,
      @cIniFilePath = UDF01
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'TCPClient'
      AND Code = 'WCS'
      AND Short = 'OUT'
      AND Storerkey = @cStorerKey  

   -- Get new PickDetailkey
   EXECUTE dbo.nspg_GetKey
      @KeyName       = 'MessageID',
      @fieldlength   = 10 ,
      @keystring     = @cMessageID  OUTPUT,
      @b_Success     = @bSuccess    OUTPUT,
      @n_err         = @nErrNo      OUTPUT,
      @c_errmsg      = @cErrMsg     OUTPUT
   IF @bSuccess <> 1
   BEGIN
      SET @nErrNo = 200501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
      GOTO Quit
   END

   -- Construct message to send
   SET @cSendMessage =
      '<STX>' + '|' +
      @cMessageID + '|' +
      'CARTONINFOR' + '|' +
      @cStorerKey + '|' +
      @cWaveKey + '|' +
      @cCartonID + '|' +
      @cStation + '|' +
      @cStorerKey + '|' +
      SUSER_SNAME() + '|' +
      FORMAT( getdate(), 'yyyyMMddHHmmss') + '|' +
      '<ETX>'

   SET @nNoOfTry = 1
   WHILE @nNoOfTry <= 5
   BEGIN
      SET @cVBErrMsg = ''
      SET @cReceiveMessage = ''

      -- Insert TCPSocket_OUTLog
      INSERT INTO dbo.TCPSocket_OUTLog ([Application], LocalEndPoint, RemoteEndPoint, MessageNum, MessageType, Data, Status, StorerKey, NoOfTry, ErrMsg, ACKData )
      VALUES (@cApplication, @cLocalEndPoint, @cRemoteEndPoint, @cMessageID, 'SEND', @cSendMessage, @cStatus, @cStorerKey, @nNoOfTry, '', '')
      SELECT @nSerialNo = SCOPE_IDENTITY(), @nErrNo = @@ERROR

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 200502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TCPOUT Err
         GOTO Quit
      END

      EXEC [master].[dbo].[isp_GenericTCPSocketClient]
           @cIniFilePath
         , @cRemoteEndPoint
         , @cSendMessage
         , @cLocalEndPoint     OUTPUT
         , @cReceiveMessage    OUTPUT
         , @cVBErrMsg          OUTPUT

      UPDATE TCPSocket_OUTLog WITH (ROWLOCK) SET
         LocalEndPoint = @cLocalEndPoint,
         ErrMsg = @cVBErrMsg,
         ACKData = @cReceiveMessage,
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE SerialNo = @nSerialNo

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 200503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TCPOUT Err
         GOTO Quit
      END

      IF CHARINDEX( 'failure', @cReceiveMessage) > 0 OR @cVBErrMsg <> ''
         SET @nNoOfTry = @nNoOfTry + 1
      ELSE
         BREAK
   END

   IF @nNoOfTry > 5
   BEGIN
      SET @nErrNo = 200504
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WCS Send Fail
   END

Quit:

END
SET QUOTED_IDENTIFIER OFF

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* SP: isp_ValidateTCPMessage_CPVImageScan2WMS_Format_Format                  */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: SG Cooper Vision image scanner will send TCPSocket message to WMS */
/*          listener, and call this SP to check format and reply to sender.   */
/*          It then trigger QCommander to process the message                 */
/*                                                                            */
/* Date         Author   Ver      Purposes                                    */
/* 2019-08-06   Ung      1.0      WMS-10026 Created                           */
/******************************************************************************/

CREATE PROC [dbo].[isp_ValidateTCPMessage_CPVImageScan2WMS_Format](
     @n_SerialNo        INT
    ,@b_Debug           INT
    ,@c_MessageNum      NVARCHAR(10)   OUTPUT
    ,@c_SprocName       NVARCHAR(30)   OUTPUT
  --,@c_Status          NVARCHAR(1)    OUTPUT -- WCS listener ver
  --,@c_RespondMsg      NVARCHAR(500)  OUTPUT -- WCS listener ver
    ,@b_Success         INT            OUTPUT
    ,@n_Err             INT            OUTPUT
    ,@c_ErrMsg          NVARCHAR(250)  OUTPUT
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_DataString NVARCHAR( MAX)
   DECLARE @c_StorerKey  NVARCHAR( 15)
   DECLARE @cStart       NVARCHAR( 3)
   DECLARE @cEnd         NVARCHAR( 3)
   DECLARE @cScannerMsgNo NVARCHAR( 10)
   DECLARE @cCount       NVARCHAR( 10)
   DECLARE @nMaxRow      INT
   DECLARE @nCount       INT
   DECLARE @nErrNo       INT
   DECLARE @cErrMsg      NVARCHAR( 20)

   DECLARE @tSplit TABLE 
   (
      RowRef INT IDENTITY( 1, 1),
      Value  NVARCHAR( 255), 
      PRIMARY KEY CLUSTERED (RowRef)
   )

   -- Init
   SELECT 
       @c_MessageNum = ''
      ,@c_SprocName = ''
      ,@b_Success = '1'
      ,@n_Err = 0
      ,@c_ErrMsg = ''         -- Must remain blank, so that ACK not stamp with error
      ,@c_StorerKey = 'CPV'

   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get TCP message
   SET @c_DataString = ''
   SELECT @c_DataString = ISNULL( RTRIM( DATA) ,'')
   FROM dbo.TCPSocket_INLog WITH (NOLOCK)
   WHERE SerialNo = @n_SerialNo
      AND Status = '0'

   /***********************************************************************************************
                                                Check format
   ***********************************************************************************************/
   -- Check blank data
   IF @c_DataString = ''
   BEGIN
       SET @nErrNo = 142501
       SET @cErrMsg = 'TCPSocket Error: Nothing to process. (SerialNo = ' + CONVERT(NVARCHAR, @n_SerialNo) + ')'
       GOTO Fail
   END

   -- Parse by comma
   INSERT INTO @tSplit (Value)
   SELECT Value FROM STRING_SPLIT( @c_DataString, ',')
   
   SET @nMaxRow = @@ROWCOUNT

   -- Get fix param value
   /*
   SELECT @cStart = Value FROM @tSplit WHERE RowRef = 1
   SELECT @cScannerMsgNo = Value FROM @tSplit WHERE RowRef = 2
   SELECT @cCount = Value FROM @tSplit WHERE RowRef = 5 -- No of master LOT
   SELECT @cEnd = Value FROM @tSplit WHERE RowRef = @nMaxRow
   */

   SELECT @cScannerMsgNo = Value FROM @tSplit WHERE RowRef = 1
   SELECT @cCount = Value FROM @tSplit WHERE RowRef = 4 -- No of master LOT

   -- Check blank
   IF EXISTS( SELECT TOP 1 1 
      FROM @tSplit 
      WHERE (Value = '' OR Value IS NULL))
   BEGIN
      SET @nErrNo = 142502
      SET @cErrMsg = 'blank parameter'
      GOTO Fail
   END   
   
   /*
   -- Check message start
   IF @cStart <> '' -- 'ST'
   BEGIN
      SET @nErrNo = 142503
      SET @cErrMsg = 'Invalid header'
      GOTO Fail
   END

   -- Check message end
   IF @cEnd <> '' -- 'EN'
   BEGIN
      SET @nErrNo = 142504
      SET @cErrMsg = 'Invalid header'
      GOTO Fail
   END
   */
   
   -- Check total master LOT
   IF rdt.rdtIsValidQTY( @cCount, 0) = 0
   BEGIN
      SET @nErrNo = 142505
      SET @cErrMsg = 'Invalid count'
      GOTO Fail
   END
   SET @nCount = CAST( @cCount AS INT)

   -- Check total master LOT tally with count
   IF @nCount <> (@nMaxRow - 4) -- 4 are fixed params
   BEGIN
      SET @nErrNo = 142506
      SET @cErrMsg = 'No of master LOT not match count'
      GOTO Fail
   END

Fail:

   /***********************************************************************************************
                                             Reply message
   ***********************************************************************************************/
   SET @c_MessageNum = @cScannerMsgNo

   IF @nErrNo = 0
   BEGIN
      SET @b_Success = 1
      UPDATE TCPSocket_INLog WITH (ROWLOCK) SET
          MessageNum = @c_MessageNum
         ,ACKData    = 'ST,' + @cScannerMsgNo + ',OK,EN'
      WHERE SerialNo = @n_SerialNo
   END
   ELSE
   BEGIN
      SET @b_Success = 0      
      UPDATE TCPSocket_INLog WITH (ROWLOCK) SET
          MessageNum = @c_MessageNum
         ,ACKData    = 'ST,' + @cScannerMsgNo + ',ERROR,EN'
         ,Status     = '5'
         ,ErrMsg     = CAST( @nErrNo AS NVARCHAR(6)) + ' ' + @c_ErrMsg
      WHERE SerialNo = @n_SerialNo
      
      GOTO Quit
   END


   /***********************************************************************************************
                                             Trigger QCommander
   ***********************************************************************************************/

   DECLARE @n_ThreadPerAcct         INT 
         , @n_ThreadPerStream       INT 
         , @n_MilisecondDelay       INT
         , @c_Port                  NVARCHAR(5)   
         , @c_IP                    NVARCHAR(20)         
         , @c_IniFilePath           NVARCHAR(200)   
         , @c_APP_DB_Name           NVARCHAR(20)   
         , @c_CmdType               NVARCHAR(10)     
         , @c_ExecStatements        NVARCHAR(4000) 

   SET @n_ThreadPerAcct    = 0
   SET @n_ThreadPerStream  = 0 
   SET @n_MilisecondDelay  = 0 
   SET @c_Port             = '' 
   SET @c_IP               = ''        
   SET @c_IniFilePath      = ''  
   SET @c_APP_DB_Name      = ''
   SET @c_CmdType          = ''

   SELECT @n_ThreadPerAcct       = ThreadPerAcct 
        , @n_ThreadPerStream     = ThreadPerStream 
        , @n_MilisecondDelay     = MilisecondDelay 
        , @c_IP                  = IP                   
        , @c_Port                = Port                  
        , @c_IniFilePath         = IniFilePath           
        , @c_APP_DB_Name         = APP_DB_Name           
        , @c_CmdType             = CmdType               
   FROM  QCmd_TransmitlogConfig WITH (NOLOCK)
   WHERE StorerKey               = @c_StorerKey 
   AND   DataStream              = ''
   AND   [App_Name]              = 'ScanImage2WMS'

   SET @c_ExecStatements = 
      'EXEC dbo.isp_ValidateTCPMessage_CPVImageScan2WMS_Process ' + 
         ' @nSerialNo = ' + CAST( @n_SerialNo AS NVARCHAR( 10))

   EXEC isp_QCmd_SubmitTaskToQCommander
        @cTaskType            = 'T'                -- 'T' - TransmitlogKey, 'D' - Data Stream 
      , @cStorerKey           = @c_StorerKey 
      , @cDataStream          = ''
      , @cCmdType             = @c_CmdType 
      , @cCommand             = @c_ExecStatements
      , @cTransmitlogKey      = @n_SerialNo 
      , @nThreadPerAcct       = @n_ThreadPerAcct 
      , @nThreadPerStream     = @n_ThreadPerStream 
      , @nMilisecondDelay     = @n_MilisecondDelay
      , @nSeq                 = 1            
      , @cIP                  = @c_IP              
      , @cPORT                = @c_Port            
      , @cIniFilePath         = @c_IniFilePath     
      , @cAPPDBName           = @c_APP_DB_Name     
      , @bSuccess             = @b_Success     OUTPUT
      , @nErr                 = @nErrNo        OUTPUT 
      , @cErrMsg              = @cErrMsg       OUTPUT            


Quit:

END

GO
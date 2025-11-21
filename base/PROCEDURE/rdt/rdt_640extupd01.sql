SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_640ExtUpd01                                     */      
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Purpose: Send picked interface to WCS                                */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date         Author    Ver.  Purposes                                */      
/* 2021-10-18   James     1.0   WMS-18084 Created                       */      
/* 2023-04-26   James     1.1   JSM-145569 Codelkup added filter by     */
/*                              storerkey (james01)                     */  
/************************************************************************/      
      
CREATE   PROCEDURE [RDT].[rdt_640ExtUpd01]      
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @nStep          INT,             
   @nInputKey      INT,             
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cGroupKey      NVARCHAR( 10),    
   @cTaskDetailKey NVARCHAR( 10),    
   @cCartId        NVARCHAR( 10),    
   @cFromLoc       NVARCHAR( 10),    
   @cCartonId      NVARCHAR( 20),    
   @cSKU           NVARCHAR( 20),    
   @nQty           INT,             
   @cOption        NVARCHAR( 1),    
   @tExtUpdate     VariableTable READONLY,     
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
       
   DECLARE @nTranCount     INT    
   DECLARE @bSuccess       INT    
   DECLARE @nSerialNo      BIGINT    
   DECLARE @cCommand       NVARCHAR( MAX) = ''    
   DECLARE @cIPAddress     NVARCHAR( 20) = ''      
   DECLARE @cPortNo        NVARCHAR( 5)  = ''      
   DECLARE @cMessageID     NVARCHAR( 10)    
   DECLARE @cWaveKey       NVARCHAR( 10)    
   DECLARE @cTaskKey       NVARCHAR( 10)    
   DECLARE @cCaseID        NVARCHAR( 20)    
   DECLARE @cDropID        NVARCHAR( 20)    
   DECLARE @cAreaKey       NVARCHAR( 10)    
   DECLARE @cLoc           NVARCHAR( 10)    
   DECLARE @cToloc         NVARCHAR( 10)    
   DECLARE @cPickerID      NVARCHAR( 18)    
   DECLARE @cPickedDate    NVARCHAR( 20)    
   DECLARE @cIniFilePath   NVARCHAR( 200)      
   DECLARE @cResult        NVARCHAR( 10)    
   DECLARE @cLocalEndPoint    NVARCHAR( 50)     
   DECLARE @cRemoteEndPoint   NVARCHAR( 50)    
   DECLARE @cApplication      NVARCHAR( 50) = 'GenericTCPSocketClient_WCS'    
   DECLARE @cSendMessage      NVARCHAR( MAX)    
   DECLARE @cReceiveMessage   NVARCHAR( MAX)    
   DECLARE @cStatus           NVARCHAR( 1) = '9'    
   DECLARE @nNoOfTry          INT = 0    
   DECLARE @cvbErrMsg         NVARCHAR( MAX)    
   DECLARE @cRecipient        NVARCHAR( MAX)    
       
   -- Handling transaction                
   --SET @nTranCount = @@TRANCOUNT                
   --BEGIN TRAN  -- Begin our own transaction                
   --SAVE TRAN rdt_640ExtUpd01 -- For rollback or commit only our own transaction                
                
   IF @nStep = 8    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         SELECT     
            @cRemoteEndPoint = Long,     
            @cIniFilePath = UDF01    
         FROM dbo.CODELKUP WITH (NOLOCK)    
         WHERE LISTNAME = 'TCPClient'    
         AND   Code     = 'WCS'    
         AND   Short    = 'OUT'    
         AND   Storerkey = @cStorerKey  
           
         DECLARE @cur_WCS  CURSOR    
         SET @cur_WCS = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
         SELECT DISTINCT Caseid    
         FROM dbo.TaskDetail WITH (NOLOCK)    
         WHERE Storerkey = @cStorerKey    
         AND   TaskType = 'CPK'    
         AND   [STATUS] = '9'    
         AND   Groupkey = @cGroupKey    
         AND   DeviceID = @cCartID    
         ORDER BY 1    
         OPEN @cur_WCS    
         FETCH NEXT FROM @cur_WCS INTO @cCaseID    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            SET @bSuccess = 1        
            EXEC ispGenTransmitLog2        
                @c_TableName        = 'WMSCPK2WCS'        
               ,@c_Key1             = @cGroupKey        
               ,@c_Key2             = @cCaseID        
               ,@c_Key3             = @cStorerkey        
               ,@c_TransmitBatch    = ''        
               ,@b_Success          = @bSuccess    OUTPUT        
               ,@n_err              = @nErrNo      OUTPUT        
               ,@c_errmsg           = @cErrMsg     OUTPUT        
        
            IF @bSuccess <> 1        
            BEGIN    
               SET @nErrNo = 177251      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsTL2Log Err'      
               GOTO Quit        
            END    
    
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
               SET @nErrNo = 177252              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetKey Fail              
               GOTO Quit              
            END    
    
            SELECT TOP 1     
                  @cWaveKey = WaveKey,     
                  @cCaseID = CaseID,     
                  @cDropID = DropID,     
                  @cAreaKey = AreaKey,     
                  @cToloc = ToLoc,     
                  @cPickerID = EditWho    
            FROM dbo.TaskDetail WITH (NOLOCK)    
            WHERE Storerkey = @cStorerKey    
            AND   TaskType = 'CPK'    
            AND   [STATUS] = '9'    
            AND   Groupkey = @cGroupKey    
            AND   DeviceID = @cCartID    
            AND   Caseid = @cCaseID    
            ORDER BY 1    
                
            SELECT @cLoc = Short    
            FROM dbo.CODELKUP WITH (NOLOCK)    
            WHERE ListName = 'ADCONLANE'    
            AND   Code = @cToloc    
            AND   Storerkey = @cStorerKey  
              
            SET @cPickedDate = CONVERT(VARCHAR, GETDATE(),112) + REPLACE(CONVERT(VARCHAR, GETDATE(),8),':','')    
             
            SET @cSendMessage =       
               '<STX>' + '|' +     
               @cMessageID + '|' +    
               'CARTONINFOR' + '|' +    
               @cWaveKey + '|' +    
               @cCaseID + '|' +    
               @cAreaKey + '|' +    
               @cLoc + '|' +    
               @cPickerID + '|' +    
               @cPickedDate + '|' +       
               '<ETX>'      
    
            SET @nNoOfTry = 1    
                
            WHILE @nNoOfTry <= 5    
            BEGIN    
               SET @cvbErrMsg = ''    
               SET @cReceiveMessage = ''    
                   
               -- Insert TCPSocket_OUTLog    
               INSERT INTO dbo.TCPSocket_OUTLog ([Application], LocalEndPoint, RemoteEndPoint, MessageNum, MessageType, Data, Status, StorerKey, NoOfTry, ErrMsg, ACKData )    
               VALUES (@cApplication, @cLocalEndPoint, @cRemoteEndPoint, @cMessageID, 'SEND', @cSendMessage, @cStatus, @cStorerKey, @nNoOfTry, '', '')    
               SELECT @nSerialNo = SCOPE_IDENTITY(), @nErrNo = @@ERROR      
                
               IF @nErrNo <> 0      
               BEGIN      
                  SET @nErrNo = 177253      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TCPOUT Err      
                  GOTO Quit      
               END      
    
               EXEC [master].[dbo].[isp_GenericTCPSocketClient]    
                    @cIniFilePath    
                  , @cRemoteEndPoint    
                  , @cSendMessage    
                  , @cLocalEndPoint     OUTPUT    
                  , @cReceiveMessage    OUTPUT    
                  , @cvbErrMsg          OUTPUT    
    
               UPDATE TCPSocket_OUTLog WITH (ROWLOCK) SET     
                  LocalEndPoint = @cLocalEndPoint,     
                  ErrMsg = @cvbErrMsg,     
                  ACKData = @cReceiveMessage,     
                  EditDate = GETDATE(),     
                  EditWho = SUSER_SNAME()    
               WHERE SerialNo = @nSerialNo    
    
               IF @@ERROR <> 0    
               BEGIN      
                  SET @nErrNo = 177254      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TCPOUT Err      
                  GOTO Quit    
               END      
    
               IF NOT ( CHARINDEX( 'failure', @cReceiveMessage) > 0 OR     
                  LEFT( ISNULL( @cvbErrMsg,''), 74) = 'No connection could be made because the target machine actively refused it')    
               BEGIN    
                  SET @nNoOfTry = 5    
                  SET @cResult = 'success'    
               END    
               ELSE    
               BEGIN    
                  SET @cResult = 'failure'     
               END    
    
               SET @nNoOfTry = @nNoOfTry + 1    
            END   --WHILE @nNoOfTry <= 5    
                
            IF @cResult = 'failure'     
            BEGIN      
               UPDATE dbo.TRANSMITLOG2 SET     
                  transmitflag = 'X',      
                  EditDate = GETDATE(),       
                  EditWho = SUSER_SNAME()      
               WHERE tablename = 'WMSACP2WCS'     
               AND   key1 = @cGroupKey    
               AND   key2 = @cDropID    
               AND   key3 = @cStorerKey    
    
               IF @@ERROR <> 0      
               BEGIN      
                  SET @nErrNo = 177255      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TL2 Fail      
                  GOTO Quit    
               END      
    
               SELECT @cRecipient = Notes    
               FROM dbo.CODELKUP (NOLOCK)     
               WHERE LISTNAME = 'EMAILALERT'    
               AND   Code = 'WCSSNDFAIL'    
               AND   Storerkey = @cStorerKey    
                   
               EXEC msdb.dbo.sp_send_dbmail     
                  @recipients      = @cRecipient,    
                  @copy_recipients = NULL,    
                  @subject         = 'WCS Send Fail',    
                  @body            = @cReceiveMessage,    
                  @body_format     = 'HTML'    
                
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 177256      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SendEmailErr      
                  GOTO Quit    
               END    
             
               SET @nErrNo = 177257      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WCS Send Fail      
               GOTO Quit    
            END      
            ELSE    
            BEGIN    
               UPDATE dbo.TRANSMITLOG2 SET     
                  transmitflag = '9',      
                  EditDate = GETDATE(),       
                  EditWho = SUSER_SNAME()      
               WHERE tablename = 'WMSCPK2WCS'     
               AND   key1 = @cGroupKey    
               AND   key2 = @cCaseID    
               AND   key3 = @cStorerKey    
    
               IF @@ERROR <> 0      
               BEGIN      
                  SET @nErrNo = 177258      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TL2 Fail      
                  GOTO Quit    
               END      
            END    
                
            FETCH NEXT FROM @cur_WCS INTO @cCaseID    
         END    
      END    
   END    
    
   --COMMIT TRAN rdt_640ExtUpd01    
    
   --GOTO Commit_Tran    
    
   --RollBackTran:    
   --   ROLLBACK TRAN rdt_640ExtUpd01 -- Only rollback change made here    
   --Commit_Tran:    
   --   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
   --      COMMIT TRAN    
   Quit:                   
   IF @nErrNo <> 0    
      SET @nErrNo = -1    
END      
SET QUOTED_IDENTIFIER OFF 

GO
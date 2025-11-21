SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_839ExtUpd05                                           */
/* Purpose: TM Replen From, Extended Update for KR                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2023-04-20   yeekung   1.0   WMS-22219 Created                             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_839ExtUpd05]
    @nMobile         INT                   
   ,@nFunc           INT                    
   ,@cLangCode       NVARCHAR( 3)           
   ,@nStep           INT                    
   ,@nInputKey       INT                    
   ,@cFacility       NVARCHAR( 5)           
   ,@cStorerKey      NVARCHAR( 15)          
   ,@cPickSlipNo     NVARCHAR( 10)          
   ,@cPickZone       NVARCHAR( 10)          
   ,@cDropID         NVARCHAR( 20)          
   ,@cLOC            NVARCHAR( 10)          
   ,@cSKU            NVARCHAR( 20)          
   ,@nQTY            INT                    
   ,@cOption         NVARCHAR( 1)           
   ,@cLottableCode   NVARCHAR( 30)          
   ,@cLottable01     NVARCHAR( 18)          
   ,@cLottable02     NVARCHAR( 18)          
   ,@cLottable03     NVARCHAR( 18)          
   ,@dLottable04     DATETIME               
   ,@dLottable05     DATETIME               
   ,@cLottable06     NVARCHAR( 30)          
   ,@cLottable07     NVARCHAR( 30)          
   ,@cLottable08     NVARCHAR( 30)          
   ,@cLottable09     NVARCHAR( 30)          
   ,@cLottable10     NVARCHAR( 30)          
   ,@cLottable11     NVARCHAR( 30)          
   ,@cLottable12     NVARCHAR( 30)          
   ,@dLottable13     DATETIME               
   ,@dLottable14     DATETIME               
   ,@dLottable15     DATETIME
   ,@cPackData1      NVARCHAR( 30)
   ,@cPackData2      NVARCHAR( 30)
   ,@cPackData3      NVARCHAR( 30)  
   ,@nErrNo          INT           OUTPUT   
   ,@cErrMsg         NVARCHAR(250) OUTPUT   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess INT   
   DECLARE @nExists  INT
   DECLARE @cShort   NVARCHAR(20)
   DECLARE @cWCS     NVARCHAR(1)
   DECLARE @cOrderKey      NVARCHAR( 10)    
   DECLARE @cLoadKey       NVARCHAR( 10)    
   DECLARE @cZone          NVARCHAR( 18) 
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
   DECLARE @cPickerID         NVARCHAR( 20)
   DECLARE @dPickerTime       DATETIME
   DECLARE @cAreakey          NVARCHAR( 20)
   DECLARE @cWavekey          NVARCHAR( 20)
   DECLARE @cMessageID        NVARCHAR( 20)
   DECLARE @cToLOC            NVARCHAR( 20)
   DECLARE @nSerialNo         INT
   DECLARE @cUserdefined01    NVARCHAR( 20)
   
   
   -- TM Replen From
   IF @nFunc = 839
   BEGIN      
      IF @nInputKey = 1 
      BEGIN
         DECLARE @RowCOUNT INT = 0
         DECLARE @cPickConfirmStatus NVARCHAR( 1)

         -- Get storer config    
         SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
         IF @cPickConfirmStatus = '0'    
            SET @cPickConfirmStatus = '5'    
   
         SELECT TOP 1    
            @cOrderKey = OrderKey,    
            @cLoadKey = ExternOrderKey,    
            @cZone = Zone    
         FROM dbo.PickHeader WITH (NOLOCK)    
         WHERE PickHeaderKey = @cPickSlipNo    

         IF @cZone IN ('XD', 'LB', 'LP') 
         BEGIN
            SELECT @RowCOUNT = COUNT(1)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)    
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)       
            WHERE RKL.PickSlipNo = @cPickSlipNo 
               AND PD.Storerkey = @cStorerKey
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
         END
         ELSE IF @cOrderKey <> ''
         BEGIN
            SELECT @RowCOUNT = COUNT(1)   
            FROM dbo.PickDetail PD WITH (NOLOCK)     
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) 
            WHERE PD.OrderKey = @cOrderKey 
               AND PD.Storerkey = @cStorerKey
               AND PD.Status <> '4' 
               AND PD.Status < @cPickConfirmStatus  
         END
         ELSE IF @cLoadKey <> ''   
         BEGIN
            SELECT @RowCOUNT = COUNT(1)   
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)  
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) 
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) 
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.Storerkey = @cStorerKey
               AND PD.Status <> '4' 
               AND PD.Status < @cPickConfirmStatus  
         END
         ELSE 
         BEGIN
            SELECT @RowCOUNT = COUNT(1) 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.Storerkey = @cStorerKey
               AND PD.Status <> '4' 
               AND PD.Status < @cPickConfirmStatus  
         END

         IF @RowCOUNT = 0
         BEGIN
            SELECT   
               @cRemoteEndPoint = Long,   
               @cIniFilePath = UDF01  
            FROM dbo.CODELKUP WITH (NOLOCK)  
            WHERE LISTNAME = 'TCPClient'  
            AND   Code     = 'WCS'  
            AND   Short    = 'OUT' 
            AND   storerkey = @cStorerKey

            DECLARE @cur_WCS  CURSOR  
            SET @cur_WCS = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            SELECT DISTINCT DropID  
            FROM dbo.pickdetail PD WITH (NOLOCK)  
            WHERE Storerkey = @cStorerKey  
               AND   pickslipno = @cPickSlipNo   
               AND   PD.Status = @cPickConfirmStatus    
            ORDER BY 1  
            OPEN @cur_WCS  
            FETCH NEXT FROM @cur_WCS INTO @cDropID  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
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
                  SET @nErrNo = 199852            
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetKey Fail            
                  GOTO Quit            
               END 

               SELECT  @cWavekey =  O.userdefine09,
                        @cAreakey = LOC.PickZone,
                        @cPickerID = pd.editwho,
                        @dPickerTime = pd.editdate,
                        @cUserdefined01 = W.userdefine01
               FROM PICKDETAIL PD (NOLOCK)
               JOIN Orders O (NOLOCK) ON PD.Orderkey = O.Orderkey AND PD.storerkey=O.Storerkey
               JOIN WAVE W (NOLOCK) ON W.Wavekey = O.userdefine09
               JOIN LOC LOC (NOLOCK) ON PD.LOC = LOC.LOC
               WHERE O.Storerkey = @cStorerKey  
                  AND   pickslipno = PickSlipNo   
                  AND   PD.Status = @cPickConfirmStatus
                  AND   DROPID = @cDropID

               IF SUBSTRING(@cDropID,1,1) = 'S'
               BEGIN
                  SET @cToLOC = @cStorerKey
               END
               ELSE
               BEGIN
                  SELECT @cToLOC = short
                  FROM CODELKUP (NOLOCK)
                  WHERE LISTNAME = 'FACONLANE'
                     AND Storerkey = 'ECOM'
                     AND code = @cUserdefined01
               END

               SET @cSendMessage =   
               '<STX>' + '|' + 
               @cMessageID + '|' +
               'CARTONINFOR' + '|' +
               @cStorerkey + '|' +
               @cWaveKey + '|' +
               @cDropID + '|' +
               @cAreaKey + '|' +
               @cToLOC + '|' +
               @cPickerID + '|' +
               CONVERT(nvarchar(20),@dPickerTime,112)+ format(@dPickerTime,'HHmmss') + '|' +   
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
                     SET @nErrNo = 199853  
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
                     SET @nErrNo = 199854  
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
                     SET @nErrNo = 199856  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SendEmailErr  
                     GOTO Quit
                  END
         
                  --SET @nErrNo = 199857  
                  --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WCS Send Fail  
                  --GOTO Quit
               END  

               FETCH NEXT FROM @cur_WCS INTO @cDropID 
            END 
         END
      END
   END

Quit:


END

GO
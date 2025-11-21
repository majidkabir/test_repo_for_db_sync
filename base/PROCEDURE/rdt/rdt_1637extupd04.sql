SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1637ExtUpd04                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2018-09-05 1.0  Ung        WMS-6115 Created                          */  
/* 2019-07-09 1.1  Ung        Check MBOL shipped                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1637ExtUpd04] (
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,           
   @nInputKey                 INT,           
   @cStorerkey                NVARCHAR( 15), 
   @cContainerKey             NVARCHAR( 10), 
   @cMBOLKey                  NVARCHAR( 10), 
   @cSSCCNo                   NVARCHAR( 20), 
   @cPalletKey                NVARCHAR( 18), 
   @cTrackNo                  NVARCHAR( 20), 
   @cOption                   NVARCHAR( 1), 
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount INT
   
   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 1637 -- Scan to container
   BEGIN
      IF @nStep = 3 -- PalletKey
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get MBOL info
            DECLARE @cUDF10 NVARCHAR(10)
            DECLARE @cStatus NVARCHAR(10)
            SELECT 
               @cMBOLKey = MBOLKey, 
               @cUDF10 = UserDefine10, 
               @cStatus = Status
            FROM MBOL WITH (NOLOCK)
            WHERE ExternMBOLKey = @cPalletKey
            
            -- Check MBOL valid
            IF @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 128951
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No MBOLKEY
               GOTO Quit
            END
            
            -- Check MBOL status
            IF @cStatus = '9'
            BEGIN
               SET @nErrNo = 128952
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
               GOTO Quit
            END

            -- Update MBOL (indicate cannot cancel order already, interface will check, for ECOM process)
            IF @cUDF10 <> 'FINAL'
            BEGIN
               BEGIN TRAN
               SAVE TRAN rdt_1637ExtUpd04

               UPDATE MBOL SET
                  UserDefine10 = 'FINAL', 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE MBOLKey = @cMBOLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 128953
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBOL Fail
                  GOTO RollBackTran
               END

               COMMIT TRAN rdt_1637ExtUpd04
            END
         END         
      END         
   END

   GOTO Quit
   
RollBackTran:  
      ROLLBACK TRAN rdt_1637ExtUpd04  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  

GO
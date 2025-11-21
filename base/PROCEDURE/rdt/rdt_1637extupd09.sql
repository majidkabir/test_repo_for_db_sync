SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1637ExtUpd09                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-03-17 1.0  yeekung    WMS-19024 Created                         */  
/************************************************************************/

CREATE PROC [RDT].[rdt_1637ExtUpd09] (
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

   DECLARE @cLabelPrinter     NVARCHAR(10)      
          ,@cPaperPrinter     NVARCHAR(10) 
          ,@cPalletLbl        NVARCHAR(20)
          ,@cFacility         NVARCHAR(20)

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
               SET @nErrNo = 184301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No MBOLKEY
               GOTO Quit
            END
            
            -- Check MBOL status
            IF @cStatus = '9'
            BEGIN
               SET @nErrNo = 184302
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
               GOTO Quit
            END

            -- Update MBOL (indicate cannot cancel order already, interface will check, for ECOM process)
            IF @cUDF10 <> 'FINAL'
            BEGIN
               BEGIN TRAN
               SAVE TRAN rdt_1637ExtUpd09

               UPDATE MBOL SET
                  UserDefine10 = 'FINAL', 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE MBOLKey = @cMBOLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 184303
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBOL Fail
                  GOTO RollBackTran
               END

               COMMIT TRAN rdt_1637ExtUpd09
            END

            SET @cPalletLbl = rdt.RDTGetConfig( @nFunc, 'PalletLbl', @cStorerKey)  

            IF ISNULL(@cPalletLbl,'')<>''
            BEGIN
               SELECT @cLabelPrinter = Printer    
                     ,@cPaperPrinter = Printer_Paper 
                     ,@cFacility = Facility
               FROM rdt.rdtMobRec WITH (NOLOCK)    
               WHERE Mobile = @nMobile    

               DECLARE @tConLabel AS VariableTable  --(yeekung02)
               INSERT INTO @tConLabel (Variable, Value) VALUES ( '@cPalletID', @cPalletKey)    

               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, @cPaperPrinter,   
                  @cPalletLbl, -- Report type  
                  @tConLabel, -- Report params  
                  'rdt_1637ExtUpd09',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
               
               IF @nErrNo<>0
                  GOTO Rollbacktran
            END
         END         
      END         
   END

   GOTO Quit
   
RollBackTran:  
      ROLLBACK TRAN rdt_1637ExtUpd09  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  

GO
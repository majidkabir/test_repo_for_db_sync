SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_855ExtUpd03                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 30-10-2017 1.0  Ung         WMS-6842 Created                               */
/* 13-12-2017 1.1  Ung         WMS-6842 Change CartonManifest trigger point   */  
/* 19-11-2018 1.2  Ung         WMS-6932 Add ID param                          */
/* 29-03-2019 1.1  James       WMS-8002 Add TaskDetailKey param (james01)     */
/* 06-07-2021 1.4  YeeKung     WMS-17278 Add Reasonkey (yeekung01)            */
/******************************************************************************/

CREATE PROC [RDT].[rdt_855ExtUpd03] (
   @nMobile      INT, 
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT, 
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR( 15),  
   @cRefNo       NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cLoadKey     NVARCHAR( 10), 
   @cOrderKey    NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cSKU         NVARCHAR( 20),  
   @nQty         INT,  
   @cOption      NVARCHAR( 1),  
   @nErrNo       INT OUTPUT,  
   @cErrMsg      NVARCHAR( 20) OUTPUT, 
   @cID          NVARCHAR( 18) = '',
   @cTaskDetailKey   NVARCHAR( 10) = '',
   @cReasonCode  NVARCHAR(20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @nCartonNo      INT
   DECLARE @cPaperPrinter  NVARCHAR( 10)
   DECLARE @cLabelPrinter  NVARCHAR( 10) 
   DECLARE @cFacility      NVARCHAR( 5) 

   
   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 855 -- PPA by DropID
   BEGIN
      IF @nStep = 3 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @nExpQTY    INT
            DECLARE @nPDQTY     INT
            DECLARE @cLabelLine NVARCHAR(5)
            
            -- Get PackDetail info
            SELECT 
               @nExpQTY = ExpQTY, 
               @nPDQTY = QTY, 
               @cPickSlipNo = PickSlipNo, 
               @nCartonNo = CartonNo, 
               @cLabelLine = LabelLine
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE LabelNo = @cDropID 
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
            
            -- Check SKU in carton
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 131251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInCarton
               GOTO Quit
            END

            -- Check over pack
            IF (@nExpQTY - @nPDQTY) < @nQTY
            BEGIN
               SET @nErrNo = 131252
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over packed
               GOTO Quit
            END

            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_855ExtUpd03 -- For rollback or commit only our own transaction

            -- Update PackDetail
            UPDATE dbo.PackDetail SET
               QTY = QTY + @nQTY,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cDropID
               AND LabelLine = @cLabelLine
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 131253
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail
               GOTO RollBackTran
            END
            
            COMMIT TRAN rdt_855ExtUpd03
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
         
            -- Get order info
            DECLARE @cOrderType NVARCHAR(10)
            SET @cOrderType = ''
            SELECT TOP 1 
               @cOrderType = O.Type 
            FROM PickDetail PD WITH (NOLOCK) 
               JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE PD.StorerKey = @cStorerKey 
               AND PD.SKU = @cSKU 
               AND PD.CaseID = @cDropID
            
            IF @cOrderType = 'NSO'
            BEGIN
               -- Storer configure
               DECLARE @cSKULabel NVARCHAR(10)
               SET @cSKULabel = rdt.rdtGetConfig( @nFunc, 'SKULabel', @cStorerKey)

               IF @cSKULabel <> ''
               BEGIN
                  DECLARE @nPrice MONEY
                  SELECT @nPrice = Price FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
                  
                  IF @nPrice IS NOT NULL
                  BEGIN
                     -- Get session info
                     SELECT  
                        @cFacility = Facility, 
                        @cLabelPrinter = Printer, 
                        @cPaperPrinter = Printer_Paper
                     FROM rdt.rdtMobRec WITH (NOLOCK)
                     WHERE Mobile = @nMobile
                     
                     -- Report params
                     DECLARE @tSKULabel AS VariableTable
                     INSERT INTO @tSKULabel (Variable, Value) VALUES 
                        ( '@cStorerKey',     @cStorerKey), 
                        ( '@cSKU',           @cSKU), 
                        ( '@nPrice',         CAST( @nPrice AS NVARCHAR( 10)))

                     -- Print label
                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                        @cSKULabel, -- Report type
                        @tSKULabel, -- Report params
                        'rdt_855ExtUpd03', 
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT, 
                        @nNoOfCopy = @nQTY
                     IF @nErrNo <> 0
                        SET @nErrNo = 0 -- Surpress error
                  END
               END
            END
         END

         IF @nInputKey = 0 -- ESC
         BEGIN
            DECLARE @cCartonManifest NVARCHAR(20)
            SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)
            IF @cCartonManifest = '0'
               SET @cCartonManifest = ''
            
            -- Carton manifest
            IF @cCartonManifest <> '' 
            BEGIN
               -- Check if carton fully pack
               IF NOT EXISTS( SELECT TOP 1 1
                  FROM dbo.PackDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND LabelNo = @cDropID 
                     AND ExpQTY <> QTY) 
               BEGIN
                  -- Get carton info
                  DECLARE @cLabelNo NVARCHAR(20)
                  DECLARE @cSite    NVARCHAR( 20)
                  SELECT TOP 1 
                     @cPickSlipNo = PickSlipNo, 
                     @nCartonNo = CartonNo,
                     @cLabelNo = LabelNo, 
                     @cSite = RefNo
                  FROM dbo.PackDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND LabelNo = @cDropID
      
                  -- Get session info
                  SELECT 
                     @cPaperPrinter = Printer_Paper, 
                     @cLabelPrinter = Printer, 
                     @cStorerKey = StorerKey
                  FROM rdt.rdtMobRec WITH (NOLOCK)
                  WHERE Mobile = @nMobile   

                  DECLARE @tCartonManifest AS VariableTable
                  INSERT INTO @tCartonManifest (Variable, Value) VALUES 
                     ( '@cPickSlipNo',    @cPickSlipNo), 
                     ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10))), 
                     ( '@cLabelNo',       @cLabelNo), 
                     ( '@cPackDtlDropID', @cSite)

                  -- Print Carton manifest
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cCartonManifest, -- Report type
                     @tCartonManifest, -- Report params
                     'rdt_855ExtUpd03', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     SET @nErrNo = 0 -- Bypass error to prevent stuck in screen cannot ESC
               END
            END
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_855ExtUpd03
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
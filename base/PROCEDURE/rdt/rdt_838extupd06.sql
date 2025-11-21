SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtUpd06                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Print price label for entire carton (1 QTY 1 Label)         */
/*          without sticking on stock and send to VAS                   */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 30-09-2019 1.0  Ung         WMS-10729 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtUpd06] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20), 
   @cPackDtlRefNo2   NVARCHAR( 20), 
   @cPackDtlUPC      NVARCHAR( 30), 
   @cPackDtlDropID   NVARCHAR( 20), 
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30), 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 5 -- Print label
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cOption = 1 -- Yes
            BEGIN
               -- Get storer config
               DECLARE @cSKULabel NVARCHAR( 10)
               SET @cSKULabel = rdt.RDTGetConfig( @nFunc, 'SKULabel', @cStorerKey)
               IF @cSKULabel = '0'
                  SET @cSKULabel = ''
               
               -- SKU label
               IF @cSKULabel <> ''
               BEGIN
                  DECLARE @tSKULabel AS VariableTable
                  DECLARE @cLabelPrinter NVARCHAR( 10)
                  DECLARE @cPaperPrinter NVARCHAR( 10)
                  DECLARE @cPDSKU NVARCHAR( 20)
                  DECLARE @nPDQTY INT
                  
                  -- Get session info
                  SELECT 
                     @cLabelPrinter = Printer, 
                     @cPaperPrinter = Printer_Paper
                  FROM rdt.rdtMobRec WITH (NOLOCK)
                  WHERE Mobile = @nMobile 
                  
                  -- Loop SKU in carton
                  DECLARE @curPD CURSOR
                  SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                     SELECT SKU, QTY
                     FROM PackDetail WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                        AND CartonNo = @nCartonNo
                        AND LabelNo = @cLabelNo
                  OPEN @curPD
                  FETCH NEXT FROM @curPD INTO @cPDSKU, @nPDQTY
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Common params
                     DELETE @tSKULabel
                     INSERT INTO @tSKULabel (Variable, Value) VALUES 
                        ( '@cStorerKey',     @cStorerKey), 
                        ( '@cSKU',           @cPDSKU), 
                        ( '@cLabelNo',       @cLabelNo), 
                        ( '@cQTY',           CAST( @nPDQTY AS NVARCHAR(10)))

                     -- Print label
                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                        @cSKULabel, -- Report type
                        @tSKULabel, -- Report params
                        'rdt_838ExtUpd06', 
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT 
                     IF @nErrNo <> 0
                        GOTO Quit
                        
                     FETCH NEXT FROM @curPD INTO @cPDSKU, @nPDQTY
                  END
               END
            END
         END
      END
   END

Quit:

END

GO
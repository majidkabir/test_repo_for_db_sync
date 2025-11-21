SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtUpd09                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: rdt_838ExtUpd06-> rdt_838ExtUpd09                           */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 01-04-2021 1.0  yeekung     WMS-16591 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtUpd09] (
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

                  -- Common params
                  DELETE @tSKULabel
                  INSERT INTO @tSKULabel (Variable, Value) VALUES 
                     ( '@cStorerKey',     @cStorerKey), 
                     ( '@cLabelNo',       @cLabelNo)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cSKULabel, -- Report type
                     @tSKULabel, -- Report params
                     'rdt_838ExtUpd09', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT 
                  IF @nErrNo <> 0
                     GOTO Quit
               END

            END
         END
      END
   END

Quit:

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_838ExtUpd14                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 22-03-2023 1.0  Ung        WMS-21830 Created                               */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_838ExtUpd14] (
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
      IF @nStep = 6 -- Print pack list
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cOption = '1'
            BEGIN
               DECLARE @cDeliveryNote NVARCHAR( 10)
               SET @cDeliveryNote = rdt.RDTGetConfig( @nFunc, 'DeliveryNote', @cStorerKey)
               IF @cDeliveryNote = '0'
                  SET @cDeliveryNote = ''

               -- Delivery Note
               IF @cDeliveryNote <> ''
               BEGIN
                  -- Get session info
                  DECLARE @cLabelPrinter NVARCHAR( 10)
                  DECLARE @cPaperPrinter NVARCHAR( 10)
                  SELECT
                     @cLabelPrinter = Printer, 
                     @cPaperPrinter = Printer_Paper
                  FROM rdt.rdtMobRec WITH (NOLOCK)
                  WHERE Mobile = @nMobile
                  
                  -- Get report param
                  DECLARE @tDeliveryNote AS VariableTable
                  INSERT INTO @tDeliveryNote (Variable, Value) VALUES
                     ( '@cPickSlipNo',    @cPickSlipNo)

                  -- Print packing list
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                     @cDeliveryNote, -- Report type
                     @tDeliveryNote, -- Report params
                     'rdt_838ExtUpd14',
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_838PntShipLbl03                                       */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2024-07-05 1.0  JACKC      FCR-392 Print VAS labels                        */
/******************************************************************************/

CREATE   PROC rdt.rdt_838PntShipLbl03 (
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

   IF @nStep = 5 -- Print label
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cOption = 1 -- Yes
         BEGIN
            DECLARE  @curLabel         CURSOR,
                     @cLabelName       NVARCHAR( 10),
                     @cLblSKU          NVARCHAR( 20),
                     @cLblVASCode      NVARCHAR( 12)  

            SELECT 'Print Label'     
            /*
            SET @curLabel = Cursor LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT 
                  --pkd.CaseID, 
                  --pkd.OrderKey, 
                  --pkd.OrderLineNumber, 
                  pkd.Sku, 
                  wod.Type
               FROM PickDetail pkd WITH (NOLOCK) 
                  INNER JOIN PackDetail pad WITH (NOLOCK)
                     ON pkd.Storerkey = pad.StorerKey AND pkd.CaseID = pad.LabelNo
                  INNER JOIN WorkOrderDetail wod WITH (NOLOCK)
                     ON pkd.Storerkey = wod.Storerkey AND pkd.OrderKey = wod.ExternWorkOrderKey AND pkd.OrderLineNumber = wod.ExternLineNO
               WHERE pkd.Storerkey = @cStorerKey AND pkd.CaseID = @cLabelNo

               OPEN @curLabel
               FETCH NEXT FROM @curLabel INTO @cLblSKU, @cLblVASCode
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  SELECT 'Print Label', @cLblSKU, @cLblVASCode
                  break
                  DECLARE @tVasLabel AS VariableTable
                  
                  INSERT INTO @tVasLabel (Variable, Value) VALUES
                  ( '@cStorerKey',     @cStorerKey),
                  ( '@cPickSlipNo',    @cPickSlipNo),
                  ( '@cFromDropID',    @cFromDropID),
                  ( '@cPackDtlDropID', @cPackDtlDropID),
                  ( '@cLabelNo',       @cLabelNo),
                  ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))


                  
                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 201807
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC fail
                     GOTO RollBackTran
                  END
               END





            -- Common params
            INSERT INTO @tMultiLbl (Variable, Value) VALUES
               ( '@cStorerKey',     @cStorerKey),
               ( '@cPickSlipNo',    @cPickSlipNo),
               ( '@cFromDropID',    @cFromDropID), -->
               ( '@cPackDtlDropID', @cPackDtlDropID),
               ( '@cLabelNo',       @cLabelNo),
               ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

            -- Print label
            EXEC RDT.rdt_Print 
               @nMobile, 
               @nFunc, 
               @cLangCode, 
               @nStep, 
               @nInputKey, 
               @cFacility, 
               @cStorerKey, 
               @cLabelPrinter, 
               @cPaperPrinter,
               @cShipLabel, -- Report type
               @tMultiLbl, -- Report params
               'rdtfnc_Pack',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
            */
         END
      END
   END

Quit:

END

GO
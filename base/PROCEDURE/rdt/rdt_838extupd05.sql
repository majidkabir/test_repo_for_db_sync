SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtUpd05                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 13-08-2019 1.0  James       WMS10030. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtUpd05] (
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

   DECLARE @cLabelLine     NVARCHAR(5)
   DECLARE @nTranCount     INT
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cZone          NVARCHAR( 18)
   DECLARE @cPackConfirm   NVARCHAR( 1)
   DECLARE @cPickStatus    NVARCHAR( 1)
   DECLARE @cDelNotes      NVARCHAR( 10)
   DECLARE @cPaperPrinter  NVARCHAR( 10)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @nPackQTY       INT
   DECLARE @nPickQTY       INT


   SET @nTranCount = @@TRANCOUNT

   SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey)

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 3
      BEGIN
         IF @nInputKey = 0
         BEGIN
            -- Get PickHeader info
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cLoadKey = ExternOrderKey,
               @cZone = Zone
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            -- Calc pack QTY
            SET @nPackQTY = 0
            SELECT @nPackQTY = ISNULL( SUM( QTY), 0) FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

            -- Cross dock PickSlip
            IF @cZone IN ('XD', 'LB', 'LP')
            BEGIN
               -- Check outstanding PickDetail
               IF EXISTS( SELECT TOP 1 1
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                     AND PD.Status < '5'
                     AND PD.QTY > 0
                     AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick
                  SET @cPackConfirm = 'N'
               ELSE
                  SET @cPackConfirm = 'Y'
      
               -- Check fully packed
               IF @cPackConfirm = 'Y'
               BEGIN
                  SELECT @nPickQTY = SUM( QTY) 
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
         
                  IF @nPickQTY <> @nPackQTY
                     SET @cPackConfirm = 'N'
               END
            END

            -- Discrete PickSlip
            ELSE IF @cOrderKey <> ''
            BEGIN
               -- Check outstanding PickDetail
               IF EXISTS( SELECT TOP 1 1
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  WHERE PD.OrderKey = @cOrderKey
                     AND PD.Status < '5'
                     AND PD.QTY > 0
                     AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick
                  SET @cPackConfirm = 'N'
               ELSE
                  SET @cPackConfirm = 'Y'
      
               -- Check fully packed
               IF @cPackConfirm = 'Y'
               BEGIN
                  SELECT @nPickQTY = SUM( PD.QTY) 
                  FROM dbo.PickDetail PD WITH (NOLOCK) 
                  WHERE PD.OrderKey = @cOrderKey
         
                  IF @nPickQTY <> @nPackQTY
                     SET @cPackConfirm = 'N'
               END
            END
   
            -- Conso PickSlip
            ELSE IF @cLoadKey <> ''
            BEGIN
               -- Check outstanding PickDetail
               IF EXISTS( SELECT TOP 1 1 
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                  WHERE LPD.LoadKey = @cLoadKey
                     AND PD.Status < '5'
                     AND PD.QTY > 0
                     AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick
                  SET @cPackConfirm = 'N'
               ELSE
                  SET @cPackConfirm = 'Y'
      
               -- Check fully packed
               IF @cPackConfirm = 'Y'
               BEGIN
                  SELECT @nPickQTY = SUM( PD.QTY) 
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                  WHERE LPD.LoadKey = @cLoadKey
         
                  IF @nPickQTY <> @nPackQTY
                     SET @cPackConfirm = 'N'
               END
            END

            -- Custom PickSlip
            ELSE
            BEGIN
               -- Check outstanding PickDetail
               IF EXISTS( SELECT TOP 1 1 
                  FROM PickDetail PD WITH (NOLOCK) 
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND PD.Status < '5'
                     AND PD.QTY > 0
                     AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick
                  SET @cPackConfirm = 'N'
               ELSE
                  SET @cPackConfirm = 'Y'

               -- Check fully packed
               IF @cPackConfirm = 'Y'
               BEGIN
                  SELECT @nPickQTY = SUM( PD.QTY) 
                  FROM PickDetail PD WITH (NOLOCK) 
                  WHERE PD.PickSlipNo = @cPickSlipNo
         
                  IF @nPickQTY <> @nPackQTY
                     SET @cPackConfirm = 'N'
               END
            END

            IF @cPackConfirm = 'Y'
            BEGIN
               SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'DelNotes', @cStorerKey)
               IF @cDelNotes = '0'
                  SET @cDelNotes = ''

               IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                               WHERE OrderKey = @cOrderKey 
                               AND   Type = 'D2R')
                  SET @cDelNotes = ''

               IF @cDelNotes <> ''
               BEGIN
                  SELECT @cLabelPrinter = Printer
                  FROM rdt.RDTMOBREC WITH (NOLOCK)
                  WHERE Mobile = @nMobile

                  DECLARE @tDELNOTES AS VariableTable
                  INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)
                  INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)
                  INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                     @cDelNotes, -- Report type
                     @tDELNOTES, -- Report params
                     'rdt_838ExtUpd05', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT 

                  IF @nErrNo <> 0
                     GOTO Quit                 
               END
            END
         END
      END

      IF @nStep = 4 -- Carton type
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT TOP 1 @cDropID = DropID, 
                         @cLabelNo = LabelNo,
                         @cLabelLine = LabelLine
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo
            ORDER BY 1

            UPDATE dbo.PackDetail WITH (ROWLOCK) SET 
               RefNo = @cRefNo
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo
            AND   LabelNo = @cLabelNo
            AND   LabelLine = @cLabelLine

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 142851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
               GOTO RollBackTran
            END

            SELECT @cOrderKey = OrderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            DECLARE @curPD CURSOR
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR         
            SELECT PickDetailKey
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey
            AND   PD.StorerKey = @cStorerKey
            AND   PD.SKU = @cSKU
            AND   PD.Status <> '4'
            AND   PD.DropID = @cDropID
            OPEN @curPD 
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE PickDetail WITH ( ROWLOCK) SET 
                  CaseID = @cRefNo
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 142852
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curPD INTO @cPickDetailKey
            END
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_838ExtUpd05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
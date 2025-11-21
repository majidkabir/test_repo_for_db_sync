SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal08                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Check pick=pack only can print label. DW 1 pickslip=1 carton*/
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2020-01-08 1.0  James       WMS-11655. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtVal08] (
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

   DECLARE @cOrderKey NVARCHAR( 10)
   DECLARE @cLoadKey  NVARCHAR( 10)
   DECLARE @cZone     NVARCHAR( 18)
   DECLARE @cPickStatus    NVARCHAR(1)
   DECLARE @nPackQTY       INT = 0
   DECLARE @nPickQTY       INT = 0
   DECLARE @cPackConfirm   NVARCHAR( 1) = ''
   
   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 5 -- Print label
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Storer config
            SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey)

            -- Get PickHeader info
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cLoadKey = ExternOrderKey,
               @cZone = Zone
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            -- Calc pack QTY
            SET @nPackQTY = 0
            SELECT @nPackQTY = ISNULL( SUM( QTY), 0) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

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

            IF @cPackConfirm <> 'Y' AND @cOption = '1'
            BEGIN
               SET @nErrNo = 147501
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Pick <> Pack
               GOTO Quit
            END
         END
      END  
   END

Quit:

END

GO
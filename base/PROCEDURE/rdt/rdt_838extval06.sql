SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal06                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 01-10-2019 1.0  Ung         WMS-10729 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtVal06] (
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
   DECLARE @cPickStatus NVARCHAR(1)
   
   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 3 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            /***********************************************************************************************
                                         Check different group of SKU pack together
            ***********************************************************************************************/
            DECLARE @cCurrGroup NVARCHAR(10) = ''
            DECLARE @cPrevGroup NVARCHAR(10) = ''

            -- Packed or repack
            IF @cLabelNo <> ''
            BEGIN
               -- Get current carton group
               SELECT TOP 1 
                  @cPrevGroup = Notes
               FROM PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND CaseID = @cLabelNo
            
               -- Current carton packed some SKU
               IF @@ROWCOUNT > 0
               BEGIN
                  -- Storer configure
                  SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerkey)

                  -- Get PickHeader info
                  SELECT TOP 1
                     @cOrderKey = OrderKey,
                     @cLoadKey = ExternOrderKey,
                     @cZone = Zone
                  FROM dbo.PickHeader WITH (NOLOCK)
                  WHERE PickHeaderKey = @cPickSlipNo

                  -- Cross dock PickSlip
                  IF @cZone IN ('XD', 'LB', 'LP')
                  BEGIN
                     SELECT TOP 1 
                        @cCurrGroup = Notes
                     FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                        JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                     WHERE RKL.PickSlipNo = @cPickSlipNo
                        AND PD.StorerKey = @cStorerKey
                        AND PD.SKU = @cSKU
                        AND PD.QTY > 0
                        AND PD.Status = @cPickStatus
                        AND PD.Status <> '4'
                        AND PD.CaseID = ''
                  END
                  
                  -- Discrete PickSlip
                  ELSE IF @cOrderKey <> ''
                  BEGIN
                     SELECT TOP 1 
                        @cCurrGroup = Notes
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                        JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                     WHERE PD.OrderKey = @cOrderKey
                        AND PD.StorerKey = @cStorerKey
                        AND PD.SKU = @cSKU
                        AND PD.QTY > 0
                        AND PD.Status = @cPickStatus
                        AND PD.Status <> '4'
                        AND PD.CaseID = ''
                  END
                              
                  -- Conso PickSlip
                  ELSE IF @cLoadKey <> ''
                  BEGIN
                     SELECT TOP 1 
                        @cCurrGroup = Notes
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                        JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                     WHERE LPD.LoadKey = @cLoadKey  
                        AND PD.StorerKey = @cStorerKey
                        AND PD.SKU = @cSKU
                        AND PD.QTY > 0
                        AND PD.Status = @cPickStatus
                        AND PD.Status <> '4'
                        AND PD.CaseID = ''
                  END
                  
                  -- Custom PickSlip
                  ELSE
                  BEGIN
                     SELECT TOP 1 
                        @cCurrGroup = Notes
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                        JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                     WHERE PD.PickSlipNo = @cPickSlipNo
                        AND PD.StorerKey = @cStorerKey
                        AND PD.SKU = @cSKU
                        AND PD.QTY > 0
                        AND PD.Status = @cPickStatus
                        AND PD.Status <> '4'
                        AND PD.CaseID = ''
                  END
                  
                  -- Different group
                  IF @cPrevGroup <> @cCurrGroup
                  BEGIN
                     SET @nErrNo = 144551
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU diff group
                     EXEC rdt.rdtSetFocusField @nMobile, 3  -- SKU
                     GOTO Quit
                  END
               END
            END
            
            /***********************************************************************************************
                                    Check last SKU not finish packing and start new SKU
            ***********************************************************************************************/
            DECLARE @cPrevSKU NVARCHAR(20) = ''
            DECLARE @nPrevSKUPickQTY INT
            DECLARE @nPrevSKUPAckQTY INT

            -- Get last packed SKU
            SELECT TOP 1 
               @cPrevSKU = PD.SKU
            FROM PackDetail PD WITH (NOLOCK) 
            WHERE PD.PickSlipNo = @cPickSlipNo 
               AND PD.QTY > 0
            ORDER BY PD.EditDate DESC

            -- Different SKU
            IF @cPrevSKU <> '' AND @cPrevSKU <> @cSKU
            BEGIN
               DECLARE @nRowCount INT = 0
               
               -- Storer configure
               SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerkey)

               -- Get PickHeader info
               SELECT TOP 1
                  @cOrderKey = OrderKey,
                  @cLoadKey = ExternOrderKey,
                  @cZone = Zone
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickSlipNo

               -- Cross dock PickSlip
               IF @cZone IN ('XD', 'LB', 'LP')
               BEGIN
                  SELECT @nPrevSKUPickQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cPrevSKU
                     AND PD.QTY > 0
                     AND PD.Status = @cPickStatus
                     AND PD.Status <> '4'
               END
               
               -- Discrete PickSlip
               ELSE IF @cOrderKey <> ''
               BEGIN
                  SELECT @nPrevSKUPickQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                  WHERE PD.OrderKey = @cOrderKey
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cPrevSKU
                     AND PD.QTY > 0
                     AND PD.Status = @cPickStatus
                     AND PD.Status <> '4'
               END
                           
               -- Conso PickSlip
               ELSE IF @cLoadKey <> ''
               BEGIN
                  SELECT @nPrevSKUPickQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                     JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                  WHERE LPD.LoadKey = @cLoadKey  
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cPrevSKU
                     AND PD.QTY > 0
                     AND PD.Status = @cPickStatus
                     AND PD.Status <> '4'
               END
               
               -- Custom PickSlip
               ELSE
               BEGIN
                  SELECT @nPrevSKUPickQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cPrevSKU
                     AND PD.QTY > 0
                     AND PD.Status = @cPickStatus
                     AND PD.Status <> '4'
               END               

               -- Get packed QTY
               SELECT @nPrevSKUPackQTY = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cPrevSKU

               -- Previous SKU not yet finish pack 
               IF @nPrevSKUPickQTY <> @nPrevSKUPackQTY
               BEGIN
                  DECLARE @cMsg1 NVARCHAR(20) = ''
                  DECLARE @cMsg2 NVARCHAR(20) = ''
                  DECLARE @cMsg3 NVARCHAR(20) = ''
                  DECLARE @cMsg4 NVARCHAR(20) = ''
                  DECLARE @cSKUDesc1 NVARCHAR(20)
                  DECLARE @cSKUDesc2 NVARCHAR(20)
                  
                  -- Get SKU info
                  SELECT 
                     @cSKUDesc1 = rdt.rdtFormatString( Descr, 1, 20), 
                     @cSKUDesc2 = rdt.rdtFormatString( Descr, 21, 20)
                  FROM SKU WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND SKU = @cPrevSKU

                  SET @cMsg1 = rdt.rdtgetmessage( 144552, @cLangCode, 'DSP') --PREVIOUS SKU
                  SET @cMsg2 = rdt.rdtgetmessage( 144553, @cLangCode, 'DSP') --NOT YET FINISH
                  SET @cMsg3 = rdt.rdtgetmessage( 144554, @cLangCode, 'DSP') --PICK QTY:
                  SET @cMsg4 = rdt.rdtgetmessage( 144555, @cLangCode, 'DSP') --PACK QTY:
                  
                  SET @cMsg3 = RTRIM( @cMsg3) + ' ' + CAST( @nPrevSKUPickQTY AS NVARCHAR(5))
                  SET @cMsg4 = RTRIM( @cMsg4) + ' ' + CAST( @nPrevSKUPackQTY AS NVARCHAR(5))

                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cMsg1, @cMsg2, '', @cPrevSKU, @cSKUDesc1, @cSKUDesc2, '', @cMsg3, @cMsg4
                  SET @nErrNo = -1

                  -- EXEC rdt.rdtSetFocusField @nMobile, 3  -- SKU
                  GOTO Quit
               END
            END
         END
      END  

      IF @nStep = 10 -- Pack data
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check COO is blank
            IF @cPackData1 = ''
            BEGIN
               SET @nErrNo = 144556
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need COO
               EXEC rdt.rdtSetFocusField @nMobile, 1  -- COO
               GOTO Quit
            END

            SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerkey)

            -- Get PickHeader info
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cLoadKey = ExternOrderKey,
               @cZone = Zone
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            -- Cross dock PickSlip
            IF @cZone IN ('XD', 'LB', 'LP')
            BEGIN
               -- Check COO in pick slip
               IF NOT EXISTS( SELECT TOP 1 1
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                     JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.QTY > 0
                     AND PD.Status = @cPickStatus
                     AND PD.Status <> '4'
                     AND LA.Lottable01 = @cPackData1)
               BEGIN
                  SET @nErrNo = 144557
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO NotIn PSNO
                  EXEC rdt.rdtSetFocusField @nMobile, 1  -- COO
                  GOTO Quit
               END
            END
            
            -- Discrete PickSlip
            ELSE IF @cOrderKey <> ''
            BEGIN
               -- Check COO in pick slip
               IF NOT EXISTS( SELECT TOP 1 1
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                  WHERE PD.OrderKey = @cOrderKey
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.QTY > 0
                     AND PD.Status = @cPickStatus
                     AND PD.Status <> '4'
                     AND LA.Lottable01 = @cPackData1)
               BEGIN
                  SET @nErrNo = 144558
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO NotIn PSNO
                  EXEC rdt.rdtSetFocusField @nMobile, 1  -- COO
                  GOTO Quit
               END
            END
                        
            -- Conso PickSlip
            ELSE IF @cLoadKey <> ''
            BEGIN
               -- Check COO in pick slip
               IF NOT EXISTS( SELECT TOP 1 1
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                     JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                  WHERE LPD.LoadKey = @cLoadKey  
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.QTY > 0
                     AND PD.Status = @cPickStatus
                     AND PD.Status <> '4'
                     AND LA.Lottable01 = @cPackData1)
               BEGIN
                  SET @nErrNo = 144559
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO NotIn PSNO
                  EXEC rdt.rdtSetFocusField @nMobile, 1  -- COO
                  GOTO Quit
               END
            END
            
            -- Custom PickSlip
            ELSE
            BEGIN
               -- Check COO in pick slip
               IF NOT EXISTS( SELECT TOP 1 1
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.QTY > 0
                     AND PD.Status = @cPickStatus
                     AND PD.Status <> '4'
                     AND LA.Lottable01 = @cPackData1)
               BEGIN
                  SET @nErrNo = 144560
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO NotIn PSNO
                  EXEC rdt.rdtSetFocusField @nMobile, 1  -- COO
                  GOTO Quit
               END
            END
         END
      END    
   END

Quit:

END

GO
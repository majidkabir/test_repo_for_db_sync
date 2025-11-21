SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_838ValidateSP02                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 05-04-2019 1.0  Ung         WMS-8134 PickDetail.UOM = 7 only         */
/* 08-08-2019 1.1  James       WMS-10030 Remove filter uom (james01)    */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ValidateSP02] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cType           NVARCHAR( 10)  -- PICKSLIPNO/SKU/QTY
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cFromDropID     NVARCHAR( 20)
   ,@cPackDtlDropID  NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT 
   ,@nCartonNo       INT
   ,@nErrNo          INT   OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)
   DECLARE @cPickStatus NVARCHAR( 1)
   DECLARE @nPackQTY    INT
   DECLARE @nPickQTY    INT

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''
   SET @nPackQTY = 0
   SET @nPickQTY = 0
   
   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Check QTY
   IF @cType = 'QTY'
   BEGIN
      -- Get PickStatus
      SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey)

      -- Calc pack QTY
      SET @nPackQTY = 0
      SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0) 
      FROM PackDetail PD WITH (NOLOCK) 
         JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
         JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.QTY <> Pack.CaseCNT
         AND (@cFromDropID = '' OR PD.DropID = @cFromDropID)
         
      -- Add QTY
      SET @nPackQTY = @nPackQTY + @nQTY
   END

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      IF @cType = 'PickSlipNo'
      BEGIN
         -- Check PickSlipNo valid 
         IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.RefKeyLookup RKL WITH (NOLOCK) WHERE RKL.PickSlipNo = @cPickSlipNo)
         BEGIN
            SET @nErrNo = 137451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
            GOTO Quit
         END

         -- Check diff storer
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = RKL.Orderkey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND O.StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 137452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO Quit
         END
      END
      
      ELSE IF @cType = 'SKU'
      BEGIN
         IF @cFromDropID = '' 
         BEGIN
            -- Check SKU in PickSlipNo
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  --AND (PD.UOM = '7' OR
                  --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 137453
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Check SKU in DropID
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  --AND (PD.UOM = '7' OR
                  --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
                  AND PD.QTY > 0
                  AND PD.DropID = @cFromDropID)
            BEGIN
               SET @nErrNo = 137469
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
               GOTO Quit
            END
         END
      END
      
      ELSE IF @cType = 'QTY'
      BEGIN
         SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            --AND (PD.UOM = '7' OR
            --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
            --AND (PD.Status = '5' OR PD.Status = @cPickStatus)
            AND PD.Status = @cPickStatus 
            AND (@cFromDropID = '' OR PD.DropID = @cFromDropID)
      
         IF @nPackQTY > @nPickQTY
         BEGIN
            SET @nErrNo = 137454
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
            GOTO Quit
         END
      END
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      IF @cType = 'PickSlipNo'
      BEGIN
         DECLARE @cChkStorerKey NVARCHAR( 15)
         DECLARE @cChkStatus    NVARCHAR( 10)
         DECLARE @cChkSOStatus  NVARCHAR( 10)

         -- Get Order info
         SELECT 
            @cChkStorerKey = StorerKey, 
            @cChkStatus = Status, 
            @cChkSOStatus = SOStatus
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         -- Check PickSlipNo valid 
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 137455
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
            GOTO Quit
         END
         
         -- Check storer
         IF @cChkStorerKey <> @cStorerKey
         BEGIN
            SET @nErrNo = 137457
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO Quit
         END
         
         -- Check order shipped
         IF @cChkStatus > '5'
         BEGIN
            SET @nErrNo = 137456
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order shipped
            GOTO Quit
         END
         
         -- Check order cancel
         IF @cChkSOStatus = 'CANC'
         BEGIN
            SET @nErrNo = 137468
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
            GOTO Quit
         END
      END

      ELSE IF @cType = 'SKU'
      BEGIN
         IF @cFromDropID = '' 
         BEGIN
            -- Check SKU in PickSlipNo
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
               WHERE PD.OrderKey = @cOrderKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  --AND (PD.UOM = '7' OR
                  --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 137458
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Check SKU in PickSlipNo
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
               WHERE PD.OrderKey = @cOrderKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  --AND (PD.UOM = '7' OR
                  --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
                  AND PD.QTY > 0
                  AND PD.DropID = @cFromDropID)
            BEGIN
               SET @nErrNo = 137470
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
               GOTO Quit
            END
         END
      END
      
      ELSE IF @cType = 'QTY'
      BEGIN
         SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            --AND (PD.UOM = '7' OR
            --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
            --AND (PD.Status = '5' OR PD.Status = @cPickStatus)
            AND PD.Status = @cPickStatus 
            AND (@cFromDropID = '' OR PD.DropID = @cFromDropID)

         IF @nPackQTY > @nPickQTY
         BEGIN
            SET @nErrNo = 137459
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
            GOTO Quit
         END
      END
   END
               
   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      IF @cType = 'PickSlipNo'
      BEGIN
         -- Check PickSlip valid
         IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) WHERE LPD.LoadKey = @cLoadKey)
         BEGIN
            SET @nErrNo = 137460
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
            GOTO Quit
         END
        
         -- Check diff storer
         IF EXISTS( SELECT TOP 1 1 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)    
            WHERE LPD.LoadKey = @cLoadKey
               AND O.StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 137461
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO Quit
         END
      END
      
      ELSE IF @cType = 'SKU'
      BEGIN
         IF @cFromDropID = '' 
         BEGIN
            -- Check SKU in PickSlipNo
            IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                  JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
               WHERE LPD.LoadKey = @cLoadKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  --AND (PD.UOM = '7' OR
                  --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 137462
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Check SKU in PickSlipNo
            IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                  JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
               WHERE LPD.LoadKey = @cLoadKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  --AND (PD.UOM = '7' OR
                  --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
                  AND PD.QTY > 0
                  AND PD.DropID = @cFromDropID)
            BEGIN
               SET @nErrNo = 137471
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
               GOTO Quit
            END
         END
      END
      
      ELSE IF @cType = 'QTY'
      BEGIN
         SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            --AND (PD.UOM = '7' OR
            --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
            --AND (PD.Status = '5' OR PD.Status = @cPickStatus)
            AND PD.Status = @cPickStatus 
            AND (@cFromDropID = '' OR PD.DropID = @cFromDropID)

         IF @nPackQTY > @nPickQTY
         BEGIN
            SET @nErrNo = 137463
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
            GOTO Quit
         END
      END
   END
   
   -- Custom PickSlip
   ELSE
   BEGIN
      IF @cType = 'PickSlipNo'
      BEGIN
         -- Check PickSlip valid 
         IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            SET @nErrNo = 137464
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
            GOTO Quit
         END

         -- Check diff storer
         IF EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 137465
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO Quit
         END
      END

      ELSE IF @cType = 'SKU'
      BEGIN
         IF @cFromDropID = '' 
         BEGIN
            -- Check SKU in PickSlipNo
            IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.PickDetail PD (NOLOCK) 
                  JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  --AND (PD.UOM = '7' OR
                  --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 137466
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Check SKU in PickSlipNo
            IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.PickDetail PD (NOLOCK) 
                  JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  --AND (PD.UOM = '7' OR
                  --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
                  AND PD.QTY > 0
                  AND PD.DropID = @cFromDropID)
            BEGIN
               SET @nErrNo = 137472
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
               GOTO Quit
            END
         END
      END
      
      ELSE IF @cType = 'QTY'
      BEGIN
         SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK) 
            JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            --AND (PD.UOM = '7' OR
            --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
            --AND (PD.Status = '5' OR PD.Status = @cPickStatus)
            AND PD.Status = @cPickStatus 
            AND (@cFromDropID = '' OR PD.DropID = @cFromDropID)

         IF @nPackQTY > @nPickQTY
         BEGIN
            SET @nErrNo = 137467
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
            GOTO Quit
         END
      END
   END

Quit:

END

GO
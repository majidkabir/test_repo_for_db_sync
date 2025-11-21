SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ValidateSP03                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 24-05-2021 1.0  yeekung     WMS-16963 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ValidateSP03] (
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
   DECLARE @cPacklot02  NVARCHAR(30)
   DECLARE @cPackUpc    NVARCHAR(30)

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''
   SET @nPackQTY = 0
   SET @nPickQTY = 0
   
   SELECT @cPackUpc =V_String41
   FROM rdt.rdtmobrec (NOLOCK)
   WHERE mobile=@nMobile

   SET @cPacklot02=SUBSTRING(@cPackUpc,16,12)+ '-' +SUBSTRING(@cPackUpc,28,2)

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
      IF @cFromDropID = 'SORTED'
         SET @cPickStatus = '5'
      ELSE IF @cFromDropID = ''
         SET @cPickStatus = '0'
      ELSE
         SET @cPickStatus = '5'

      -- Calc pack QTY
      SET @nPackQTY = 0
      SELECT @nPackQTY = ISNULL( SUM( QTY), 0)
      FROM PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND RefNo = @cPackDtlDropID -- Site
         AND DropID = @cFromDropID
         AND Upc=@cPackUpc
         
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
            SET @nErrNo = 168401
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
            SET @nErrNo = 168402
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
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 168403
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
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.DropID = @cFromDropID)
            BEGIN
               SET @nErrNo = 168404
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
               GOTO Quit
            END
         END
      END
      
      ELSE IF @cType = 'QTY'
      BEGIN
         SELECT @nPickQTY = ISNULL( SUM( pd.QTY), 0)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN dbo.LOTxLOCxID LLI (NOLOCK) ON (PD.lot=LLI.lot AND pd.sku=lli.sku AND pd.loc=lli.loc)
            JOIN dbo.LOTATTRIBUTE LA(NOLOCK) ON (LA.lot=lli.lot)
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status >= @cPickStatus
            AND PD.DropID = @cFromDropID
            AND LA.Lottable02=@cPacklot02
      
         IF @nPackQTY > @nPickQTY
         BEGIN
            SET @nErrNo = 168405
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
            SET @nErrNo = 168406
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
            GOTO Quit
         END
         
         -- Check storer
         IF @cChkStorerKey <> @cStorerKey
         BEGIN
            SET @nErrNo = 168407
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO Quit
         END
         
         -- Check order shipped
         IF @cChkStatus > '5'
         BEGIN
            SET @nErrNo = 168408
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order shipped
            GOTO Quit
         END
         
         -- Check order cancel
         IF @cChkSOStatus = 'CANC'
         BEGIN
            SET @nErrNo = 168409
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
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE PD.OrderKey = @cOrderKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 168410
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Check SKU in PickSlipNo
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE PD.OrderKey = @cOrderKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.DropID = @cFromDropID)
            BEGIN
               SET @nErrNo = 168411
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
               GOTO Quit
            END
         END
      END
      
      ELSE IF @cType = 'QTY'
      BEGIN
         SELECT @nPickQTY = ISNULL( SUM( pd.QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN dbo.LOTxLOCxID LLD WITH (NOLOCK) ON (LLD.Lot=PD.Lot AND LLD.sku=pd.Sku AND lld.loc=pd.Loc)
            JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.lot=lld.Lot)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status >= @cPickStatus
            --AND PD.DropID = ''
            AND la.Lottable02=CASE WHEN ISNULL(@cPacklot02,'')='' THEN la.Lottable02 ELSE @cPacklot02 end

         IF @nPackQTY > @nPickQTY
         BEGIN
            SET @nErrNo = 168412
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
            SET @nErrNo = 168413
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
            SET @nErrNo = 168414
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
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                  JOIN dbo.LOTxLOCxID LLI (NOLOCK) ON (PD.lot=LLI.lot AND pd.sku=lli.sku AND pd.loc=lli.loc)
                  JOIN dbo.LOTATTRIBUTE LA(NOLOCK) ON (LA.lot=lli.lot)
               WHERE LPD.LoadKey = @cLoadKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  --AND LA.Lottable02=@cPacklot02
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 168415
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
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE LPD.LoadKey = @cLoadKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.DropID = @cFromDropID)
            BEGIN
               SET @nErrNo = 168416
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
               GOTO Quit
            END
         END
      END
      
      ELSE IF @cType = 'QTY'
      BEGIN
         IF @cFromDropID = ''  --(JH01)
			BEGIN
			   SELECT @nPickQTY = ISNULL( SUM( pd.QTY), 0)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN dbo.LOTxLOCxID LLI (NOLOCK) ON (PD.lot=LLI.lot AND pd.sku=lli.sku AND pd.loc=lli.loc)
            JOIN dbo.LOTATTRIBUTE LA(NOLOCK) ON (LA.lot=lli.lot)
            WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND la.Lottable02=CASE WHEN ISNULL(@cPacklot02,'')='' THEN la.Lottable02 ELSE @cPacklot02 end
            AND PD.Status >= @cPickStatus
            AND PD.DropID = ''
			END
			ELSE
			BEGIN
			   SELECT @nPickQTY = ISNULL( SUM( pd.QTY), 0)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN dbo.LOTxLOCxID LLI (NOLOCK) ON (PD.lot=LLI.lot AND pd.sku=lli.sku AND pd.loc=lli.loc)
            JOIN dbo.LOTATTRIBUTE LA(NOLOCK) ON (LA.lot=lli.lot)
            WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status >= @cPickStatus
            AND PD.DropID = @cFromDropID
             AND la.Lottable02=CASE WHEN ISNULL(@cPacklot02,'')='' THEN la.Lottable02 ELSE @cPacklot02 end
			END         --(JH01)

         IF @nPackQTY > @nPickQTY
         BEGIN
            SET @nErrNo = 168417
            SET @cErrMsg =rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
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
            SET @nErrNo = 168418
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
            GOTO Quit
         END

         -- Check diff storer
         IF EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 168419
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
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 168420
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Check SKU in PickSlipNo
            IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.PickDetail PD (NOLOCK) 
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.DropID = @cFromDropID)
            BEGIN
               SET @nErrNo = 168421
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
               GOTO Quit
            END
         END
      END
      
      ELSE IF @cType = 'QTY'
      BEGIN
         SELECT @nPickQTY = ISNULL( SUM( pd.QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN dbo.LOTxLOCxID LLI (NOLOCK) ON (PD.lot=LLI.lot AND pd.sku=lli.sku AND pd.loc=lli.loc)
            JOIN dbo.LOTATTRIBUTE LA(NOLOCK) ON (LA.lot=lli.lot)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status >= @cPickStatus
            AND PD.DropID = @cFromDropID
            AND LA.Lottable02=@cPacklot02

         IF @nPackQTY > @nPickQTY
         BEGIN
            SET @nErrNo = 168422
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
            GOTO Quit
         END
      END
   END

Quit:

END

GO
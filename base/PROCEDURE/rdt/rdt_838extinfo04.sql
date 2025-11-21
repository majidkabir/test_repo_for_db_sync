SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtInfo04                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 2019-11-04 1.0 James       WMS-10890. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtInfo04] (
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tVar           VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU           NVARCHAR( 20),
           @cPickSlipNo    NVARCHAR( 10),
           @cPackDtlDropID NVARCHAR( 20),
           @nTTL_Picked    INT = 0,
           @nTTL_Packed    INT = 0,
           @cOrderKey      NVARCHAR( 10) = '',
           @cLoadKey       NVARCHAR( 10) = '',
           @cZone          NVARCHAR( 10) = '',
           @cPSType        NVARCHAR( 10) = ''
   
   -- Table mapping
   SELECT @cPackDtlDropID = Value FROM @tVar WHERE Variable = '@cPackDtlDropID'
   SELECT @cPickSlipNo = Value FROM @tVar WHERE Variable = '@cPickSlipNo'
   SELECT @cSKU = Value FROM @tVar WHERE Variable = '@cSKU'

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 1 -- PKSlip, From/To DropID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SET @cExtendedInfo = @cPackDtlDropID
         END
      END

      IF @nAfterStep = 3 -- SKU/Qty
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cZone = Zone, 
                   @cLoadKey = ExternOrderKey,
                   @cOrderKey = OrderKey
            FROM dbo.PickHeader WITH (NOLOCK)     
            WHERE PickHeaderKey = @cPickSlipNo

            -- Get PickSlip type
            IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
               SET @cPSType = 'XD'
            ELSE IF @cOrderKey = ''
               SET @cPSType = 'CONSO'
            ELSE 
               SET @cPSType = 'DISCRETE'

            -- conso picklist   
            IF @cPSType = 'XD'
            BEGIN
               SELECT @nTTL_Picked = ISNULL( SUM( Qty), 0) 
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK) 
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.PickDetailKey = RKL.PickDetailKey) 
               WHERE RKL.PickSlipNo = @cPickSlipNo 
               AND   PD.Storerkey = @cStorerKey 
               AND   PD.SKU = @cSKU
               AND   PD.[Status] <> '4'
            END
            -- Discrete PickSlip
            ELSE IF @cPSType = 'DISCRETE' 
            BEGIN
               SELECT @nTTL_Picked = ISNULL( SUM( Qty), 0) 
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE Storerkey = @cStorerKey 
               AND   OrderKey = @cOrderKey 
               AND   SKU = @cSKU
               AND   [Status] <> '4'
            END
            -- CONSO PickSlip
            ELSE IF @cPSType = 'CONSO' 
            BEGIN
               SELECT @nTTL_Picked = ISNULL( SUM( Qty), 0) 
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON ( LPD.OrderKey = PD.OrderKey) 
               WHERE LPD.LoadKey = @cLoadKey 
               AND   PD.StorerKey = @cStorerKey 
               AND   PD.SKU = @cSKU
               AND   PD.[Status] <> '4'   
            END
            -- Custom PickSlip
            ELSE
            BEGIN
               SELECT @nTTL_Picked = ISNULL( SUM( Qty), 0) 
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE Storerkey = @cStorerKey 
               AND   PickSlipNo = @cPickSlipNo 
               AND   SKU = @cSKU
               AND   [Status] <> '4'
            END
         
            SELECT @nTTL_Packed = ISNULL( SUM(Qty), 0) 
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
            AND   PickSlipNo = @cPickSlipNo 
            AND   SKU = @cSKU
            
            SET @cExtendedInfo = 'PICK/PACK: ' + 
            RTRIM( CAST( @nTTL_Picked AS NVARCHAR( 5))) + 
            '/' + 
            CAST( @nTTL_Packed AS NVARCHAR( 5))
         END
      END
   END

Quit:

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_862ExtInfo02                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2016-02-22 1.0  Ung     SOS363736 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_862ExtInfo02] (
    @nMobile         INT 
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nAfterStep      INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5) 
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cSuggestedLOC   NVARCHAR( 10)
   ,@cLOC            NVARCHAR( 10)
   ,@cID             NVARCHAR( 18)
   ,@cDropID         NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME     
   ,@nTaskQTY        INT          
   ,@nPQTY           INT          
   ,@cUCC            NVARCHAR( 20)
   ,@cOption         NVARCHAR( 1) 
   ,@cExtendedInfo   NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 862 -- Pick by ID
   BEGIN
      IF @nAfterStep = 6 -- ID
      BEGIN
         DECLARE @nTotal    INT
         DECLARE @nPicked   INT
         DECLARE @cZone     NVARCHAR( 18)
         DECLARE @cOrderKey NVARCHAR( 10)
         
         -- Get PickHeader info
         SELECT 
            @cZone = Zone, 
            @cOrderKey = OrderKey
         FROM dbo.PickHeader WITH (NOLOCK)     
         WHERE PickHeaderKey = @cPickSlipNo   
      
         IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP' 
         BEGIN
            SET @cExtendedInfo = ''
            GOTO Quit
         END

         IF @cOrderKey <> '' 
         BEGIN
            -- Discrete PickSlip
            -- Get total QTY for that LOC, SKU
            SELECT @nTotal = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickHeader PH (NOLOCK)
               JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            WHERE PH.PickHeaderKey = @cPickSlipNo
               AND PD.Status <> '4' -- Short
               AND PD.LOC = @cLOC
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
   
            -- Get picked QTY for that LOC, SKU
            SELECT @nPicked = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickHeader PH (NOLOCK)
               JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            WHERE PH.PickHeaderKey = @cPickSlipNo
               AND PD.Status = '5' -- Not yet picked
               AND PD.LOC = @cLOC
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
         END
         ELSE
         BEGIN
            -- Conso PickSlip
            -- Get total QTY for that LOC, SKU
            SELECT @nTotal = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickHeader PH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            WHERE PH.PickHeaderKey = @cPickSlipNo
               AND PD.Status <> '4' -- Short
               AND PD.LOC = @cLOC
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
   
            -- Get picked QTY for that LOC, SKU
            SELECT @nPicked = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickHeader PH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            WHERE PH.PickHeaderKey = @cPickSlipNo
               AND PD.Status = '5' -- Not yet picked
               AND PD.LOC = @cLOC
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
         END
         
         SET @cExtendedInfo = RTRIM( CAST( @nPicked AS NVARCHAR(10))) + '/' + RTRIM( CAST( @nTotal AS NVARCHAR(10)))
      END
   END

Quit:


GO
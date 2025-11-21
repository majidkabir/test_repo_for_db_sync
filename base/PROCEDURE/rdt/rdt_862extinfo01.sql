SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_862ExtInfo01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2014-08-28 1.0  Ung     SOS307606 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_862ExtInfo01] (
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
         DECLARE @cRatio    NVARCHAR(10)
         DECLARE @cBalance  NVARCHAR(20)
         DECLARE @cPickType NVARCHAR(10)
         DECLARE @cPackKey  NVARCHAR(10)
         DECLARE @nTotal    INT
         DECLARE @nPicked   INT
         
         -- Get pick type
         SELECT @cPickType =
            CASE BUSR2
               WHEN 'PALLET' THEN 'RM-PALLET' -- Raw material, pick by pallet
               WHEN 'CRTID'  THEN 'RM-CARTON' -- Raw material, pick by carton
               ELSE 'FG'                      -- Finish good,  pick by pallet
            END, 
            @cPackKey = PackKey
         FROM SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

         -- Get ratio
         SELECT @cRatio = 
            CASE WHEN @cPickType = 'RM-PALLET' THEN '1:' + CAST( CAST( Pallet AS BIGINT) AS NVARCHAR(10))
                 WHEN @cPickType = 'RM-CARTON' THEN '1:' + CAST( CaseCnt AS NVARCHAR(10))
                 ELSE '' -- FG
            END
         FROM Pack WITH (NOLOCK)
         WHERE PackKey = @cPackKey

         IF @cPickType = 'FG' 
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
         ELSE
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
         SET @cBalance = RTRIM( CAST( @nPicked AS NVARCHAR(10))) + '/' + RTRIM( CAST( @nTotal AS NVARCHAR(10)))
         
         DECLARE @nTotalLen INT
         SET @nTotalLen = LEN( @cRatio) + LEN( @cBalance)
         IF @nTotalLen > 20
            SET @cExtendedInfo = RIGHT( SPACE( 20) + @cBalance, 20)
         ELSE
            SET @cExtendedInfo = @cRatio + SPACE( 20-@nTotalLen) + @cBalance
            
      END
   END

GO
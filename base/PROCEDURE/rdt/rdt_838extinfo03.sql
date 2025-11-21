SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtInfo03                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 28-03-2018 1.0 James       WMS4231 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtInfo03] (
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

   DECLARE @cSKU           NVARCHAR( 10),
           @cPickSlipNo    NVARCHAR( 10),
           @cOrderKey      NVARCHAR( 10),
           @cLoadKey       NVARCHAR( 10),
           @cZone          NVARCHAR( 10),
           @cPickStatus    NVARCHAR( 1),
           @nTTL_Picked    INT,
           @nTTL_Packed    INT



   IF @nFunc = 838 -- Pack
   BEGIN
      IF 3 IN (@nStep, @nAfterStep) -- SKU QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Variable mapping
            SELECT @cSKU = Value FROM @tVar WHERE Variable = '@cSKU'
            SELECT @cPickSlipNo = Value FROM @tVar WHERE Variable = '@cPickSlipNo'

            SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey)

            SELECT @nTTL_Picked = ISNULL( SUM( PD.Qty), 0)
            FROM dbo.PickHeader PH (NOLOCK)     
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
            JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
            WHERE PH.PickHeaderKey = @cPickSlipNo    
            AND  (PD.Status = '5' OR PD.Status = @cPickStatus)
            AND   PD.SKU = @cSKU

            SELECT @nTTL_Packed = ISNULL( SUM( Qty), 0)
            FROM dbo.PackDetail PD WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   SKU = @cSKU

            SET @cExtendedInfo = 'PACK/TTL:' + 
            CAST( IsNULL( @nTTL_Packed, 0) AS NVARCHAR( 5)) + 
            '/' +
            CAST( IsNULL( @nTTL_Picked, 0) AS NVARCHAR( 5)) 
         END
      END
   END

Quit:

END

GO
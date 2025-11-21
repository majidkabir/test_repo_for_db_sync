SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_903DecodeSP01                                   */  
/* Purpose: decode altsku to SKU                                        */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2021-11-19 1.0  yeekung   WMS-18412 Created                           */  																		   
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_903DecodeSP01] (  
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nInputKey      INT,          
   @cStorerKey     NVARCHAR( 15),
   @cBarcode       NVARCHAR( 60),
   @cRefno         NVARCHAR( 10)  OUTPUT,
   @cPickSlipNo    NVARCHAR( 10)  OUTPUT,
   @cLoadKey       NVARCHAR( 10)  OUTPUT,
   @cOrderKey      NVARCHAR( 10)  OUTPUT,
   @cDropID        NVARCHAR( 20)  OUTPUT,
   @cUPC           NVARCHAR( 20)  OUTPUT,
   @nQTY           INT            OUTPUT,
   @cLottable01    NVARCHAR( 18)  OUTPUT,
   @cLottable02    NVARCHAR( 18)  OUTPUT,
   @cLottable03    NVARCHAR( 18)  OUTPUT,
   @dLottable04    DATETIME       OUTPUT,
   @dLottable05    DATETIME       OUTPUT,
   @cLottable06    NVARCHAR( 30)  OUTPUT,
   @cLottable07    NVARCHAR( 30)  OUTPUT,
   @cLottable08    NVARCHAR( 30)  OUTPUT,
   @cLottable09    NVARCHAR( 30)  OUTPUT,
   @cLottable10    NVARCHAR( 30)  OUTPUT,
   @cLottable11    NVARCHAR( 30)  OUTPUT,
   @cLottable12    NVARCHAR( 30)  OUTPUT,
   @dLottable13    DATETIME       OUTPUT,
   @dLottable14    DATETIME       OUTPUT,
   @dLottable15    DATETIME       OUTPUT,
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPPACartonIDByPickDetailCaseID NVARCHAR(20)

   SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorerKey)  

   IF ISNULL(@cPickSlipNo,'')<>''
   BEGIN
      SELECT TOP 1   
         @cUPC = SKU.SKU  
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
      WHERE PD.StorerKey = @cStorerKey  
         AND PD.Status <= '5'  
         AND ShipFlag <> 'Y'
         AND PD.PickSlipNo=@cPickSlipNo
         AND PD.QTY > 0  
         AND @cBarcode in (SKU.ALTSKU, SKU.ManufacturerSKU, SKU.RetailSKU, SKU.SKU) 
   END
   ELSE IF ISNULL(@cDropID,'')<>''
   BEGIN
      -- Validate drop ID status  
      IF @cPPACartonIDByPickDetailCaseID = '1'  
      BEGIN  
         SELECT TOP 1   
            @cUPC = SKU.SKU  
         FROM PickDetail PD WITH (NOLOCK) 
            JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
         WHERE PD.StorerKey = @cStorerKey  
            AND PD.Status <= '5'  
            AND ShipFlag <> 'Y'
            AND PD.CaseID=@cDropID
            AND PD.QTY > 0  
            AND @cBarcode in (SKU.ALTSKU, SKU.ManufacturerSKU, SKU.RetailSKU, SKU.SKU)
      END 
      ELSE 
      BEGIN  
         SELECT TOP 1   
            @cUPC = SKU.SKU  
         FROM PickDetail PD WITH (NOLOCK) 
            JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
         WHERE PD.StorerKey = @cStorerKey  
            AND PD.Status <= '5'  
            AND ShipFlag <> 'Y'
            AND PD.dropid=@cDropID
            AND PD.QTY > 0  
            AND @cBarcode in (SKU.ALTSKU, SKU.ManufacturerSKU, SKU.RetailSKU, SKU.SKU)
      END 
   END
 
   IF ISNULL(@cUPC,'')=''
   BEGIN
      SET @cUPC=@cBarcode
   END
Quit:  

END

GO
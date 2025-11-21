SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_839DecodeSP01                                         */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2019-07-02   1.0  Ung        WMS-9548 Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_839DecodeSP01] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cBarcode     NVARCHAR( 60), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cPickZone    NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cUPC         NVARCHAR( 30)  OUTPUT, 
   @nQTY         INT            OUTPUT, 
   @cLottable01  NVARCHAR( 18)  OUTPUT, 
   @cLottable02  NVARCHAR( 18)  OUTPUT, 
   @cLottable03  NVARCHAR( 18)  OUTPUT, 
   @dLottable04  DATETIME       OUTPUT, 
   @dLottable05  DATETIME       OUTPUT, 
   @cLottable06  NVARCHAR( 30)  OUTPUT, 
   @cLottable07  NVARCHAR( 30)  OUTPUT, 
   @cLottable08  NVARCHAR( 30)  OUTPUT, 
   @cLottable09  NVARCHAR( 30)  OUTPUT, 
   @cLottable10  NVARCHAR( 30)  OUTPUT, 
   @cLottable11  NVARCHAR( 30)  OUTPUT, 
   @cLottable12  NVARCHAR( 30)  OUTPUT, 
   @dLottable13  DATETIME       OUTPUT, 
   @dLottable14  DATETIME       OUTPUT, 
   @dLottable15  DATETIME       OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSuggSKU NVARCHAR( 20)
   SELECT @cSuggSKU = V_SKU FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
   
   -- Check if UPC
   IF EXISTS( SELECT 1 FROM UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSuggSKU AND UPC = @cBarcode)
   BEGIN
      DECLARE @cDefaultInnerQTY NVARCHAR(5)
      SET @cDefaultInnerQTY = rdt.RDTGetConfig( @nFunc, 'DefaultInnerQTY', @cStorerKey)  

      SET @nQTY = @cDefaultInnerQTY
   END   
END

GO
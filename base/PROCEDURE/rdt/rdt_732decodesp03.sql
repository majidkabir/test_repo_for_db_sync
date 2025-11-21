SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_732DecodeSP03                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode barcode and read sku.sku only                              */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2019-10-07  James     1.0   WMS-10272 Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_732DecodeSP03] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15), 
   @cCCKey         NVARCHAR( 10), 
   @cCCSheetNo     NVARCHAR( 10), 
   @cCountNo       NVARCHAR( 1), 
   @cBarcode       NVARCHAR( 60),
   @cLOC           NVARCHAR( 10)  OUTPUT, 
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
   @cUserDefine01  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine02  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine03  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine04  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine05  NVARCHAR( 60)  OUTPUT, 
   @nErrNo         INT            OUTPUT, 
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKUStatus NVARCHAR(10) = ''
   
   IF @nFunc = 732 -- Simple CC (assisted)
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               -- MATA has sku exists in manufacturersku, retailsku which the skustatus = inactive
               -- SKU A | SKU B (manufacturersku = SKU A, skustatus = inactive)
               SET @cSKUStatus = rdt.RDTGetConfig( @nFunc, 'SKUStatus', @cStorerkey)      
               IF @cSKUStatus = '0'    
                SET @cSKUStatus = '' 

               IF NOT EXISTS ( SELECT 1 
                  FROM  dbo.SKU SKU WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey 
                  AND   Sku = @cBarcode 
                  AND   ((@cSKUStatus = '') OR ( SkuStatus = @cSKUStatus)))
               BEGIN
                  SET @nErrNo = 144951   
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Inactive 
                  GOTO Quit
               END                                       
               ELSE
                  SET @cUPC = @cBarcode
            END
         END
      END
   END

Quit:

END

GO
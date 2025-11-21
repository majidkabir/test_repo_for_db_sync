SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_655DecodeSP01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode SKU by loc                                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 23-Mar-2023 yeekung   1.0   WMS-21873 Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_655DecodeSP01] ( 
 @nMobile      INT,            
 @nFunc        INT,            
 @cLangCode    NVARCHAR( 3),   
 @nStep        INT,            
 @nInputKey    INT,            
 @cStorerKey   NVARCHAR( 15),  
 @cFacility    NVARCHAR( 20),  
 @cOrderKey    NVARCHAR( 20),  
 @cBarcode     NVARCHAR( 60)  OUTPUT, 
 @cSKU         NVARCHAR( 20)  OUTPUT,
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
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess INT

   DECLARE @cUPC NVARCHAR(MAX)

   SET @cUPC = @cBarcode

   EXEC [RDT].[rdt_GETSKU]     
      @cStorerKey   = @cStorerKey      ,
      @cSKU         = @cUPC      OUTPUT,
      @bSuccess     = @bSuccess  OUTPUT,
      @nErr         = @nErrNo    OUTPUT,
      @cErrMsg      = @cErrMsg   OUTPUT,
      @cSKUStatus   = ''

   IF ISNULL(@cUPC,'')  = '' and @nErrNo <>''
   BEGIN
      SET @nErrNo = ''
      SET @cErrMsg = ''
      GOTO QUIT
   END
   ELSE
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM Orderdetail (nolock)
                     WHERE SKU = @cUPC
                        AND Storerkey = @cStorerKey
                        AND Orderkey = @cOrderKey)
      BEGIN
         SET @nErrNo = 199201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pick
         GOTO Quit
      END
      ELSE IF  EXISTS (SELECT 1 FROM SKU (NOLOCK)
                      WHERE SKU = @cUPC
                      AND skugroup ='RX'
                      AND Storerkey = @cStorerKey)
      BEGIN
         SET @nErrNo = 199202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pick
         GOTO Quit
      END
      ELSE
      BEGIN
         SELECT TOP 1 @cLottable07 = Lottable07
         FROM PICKDETAIL PD (NOLOCK)
         JOIN Lotattribute LOT ON PD.Lot = LOT.Lot AND PD.Storerkey = LOT.Storerkey
         WHERE Orderkey = @cOrderKey
            AND PD.SKU = @cUPC
            AND PD.Storerkey = @cStorerKey

         SET @cSKU = @cUPC
         SET @cBarcode = @cLottable07
      END
   END


Quit:

END

GO
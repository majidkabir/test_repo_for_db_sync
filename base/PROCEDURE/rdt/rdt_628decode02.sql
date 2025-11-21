SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_628Decode02                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: User scan Altsku, return Sku to bypass Multiskubarcode check   */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2022-01-05 1.0  James   WMS-18568 Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_628Decode02](
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cBarcode       NVARCHAR( 60),
   @cLOC           NVARCHAR( 10)  OUTPUT,
   @cID            NVARCHAR( 18)  OUTPUT,
   @cSKU           NVARCHAR( 20)  OUTPUT,
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
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cInquiry_SKU   NVARCHAR( 20)

   SELECT @cInquiry_SKU = I_Field03
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF ISNULL( @cInquiry_SKU, '') <> ''
   BEGIN
      SELECT TOP 1 @cSKU = SKU
      FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku))
      WHERE StorerKey = @cStorerKey
      AND   ALTSKU = @cInquiry_SKU
      ORDER BY 1

      IF @@ROWCOUNT = 0
         SET @cSKU = @cInquiry_SKU
   END
Quit:


END

GO
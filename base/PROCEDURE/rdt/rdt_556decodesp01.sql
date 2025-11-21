SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_556DecodeSP01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode for SKU Inquiry                                            */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 11-08-2016  James     1.0   SOS375234 Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_556DecodeSP01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15), 
   @cBarcode       NVARCHAR( 60),
   @cSKU           NVARCHAR( 20)  OUTPUT, 
   @cLOC           NVARCHAR( 10)  OUTPUT, 
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

   DECLARE @nLblLength     INT

   IF @nFunc = 556 -- Pick To Drop ID
   BEGIN
      IF @nStep IN ( 1, 2) -- SKU/LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SET @cSKU   = ''
               SET @nLblLength = 0

               SET @nLblLength = LEN(ISNULL(RTRIM(@cBarcode),''))

               IF (@nLblLength >= 20)
                  SET @cSKU = LEFT(ISNULL(RTRIM(@cBarcode), ''), (@nLblLength - 6))
               ELSE
                  SET @cSKU = @cBarcode          
            END
         END
      END   -- @nStep = 1
   END

Quit:

END

GO
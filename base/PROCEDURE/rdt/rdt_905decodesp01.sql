SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_905DecodeSP01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode externorderkey, sku                                        */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 10-10-2016  James     1.0   WMS344 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_905DecodeSP01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cBarcode         NVARCHAR( 60),
   @cRefNo           NVARCHAR( 20)  OUTPUT,
   @cStore           NVARCHAR( 15)  OUTPUT,
   @cUPC             NVARCHAR( 20)  OUTPUT,
   @nQTY             INT            OUTPUT,
   @cLottable01      NVARCHAR( 18)  OUTPUT,
   @cLottable02      NVARCHAR( 18)  OUTPUT,
   @cLottable03      NVARCHAR( 18)  OUTPUT,
   @dLottable04      DATETIME       OUTPUT,
   @dLottable05      DATETIME       OUTPUT,
   @cLottable06      NVARCHAR( 30)  OUTPUT,
   @cLottable07      NVARCHAR( 30)  OUTPUT,
   @cLottable08      NVARCHAR( 30)  OUTPUT,
   @cLottable09      NVARCHAR( 30)  OUTPUT,
   @cLottable10      NVARCHAR( 30)  OUTPUT,
   @cLottable11      NVARCHAR( 30)  OUTPUT,
   @cLottable12      NVARCHAR( 30)  OUTPUT,
   @dLottable13      DATETIME       OUTPUT,
   @dLottable14      DATETIME       OUTPUT,
   @dLottable15      DATETIME       OUTPUT,
   @cUserDefine01    NVARCHAR( 60)  OUTPUT,
   @cUserDefine02    NVARCHAR( 60)  OUTPUT,
   @cUserDefine03    NVARCHAR( 60)  OUTPUT,
   @cUserDefine04    NVARCHAR( 60)  OUTPUT,
   @cUserDefine05    NVARCHAR( 60)  OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nPos     INT

   IF ISNULL( @cBarcode, '') = ''
      GOTO Quit

   IF @nFunc = 905 -- PPA
   BEGIN
      IF @nStep = 1 -- REFNO (EXTERNORDERKEY)
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF LEN( RTRIM( @cBarcode)) >= 12
               SET @cRefNo = SUBSTRING( @cBarcode, 1, 12)
            ELSE
               SET @cRefNo = SUBSTRING( @cBarcode, 1, LEN( @cRefNo))
         END
      END

      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SET @nPos = CHARINDEX( ',', @cBarcode)

            IF @nPos > 0
               SET @cUPC = SUBSTRING( @cBarcode, 1, @nPos - 1)
         END
      END
   END

Quit:

END

GO
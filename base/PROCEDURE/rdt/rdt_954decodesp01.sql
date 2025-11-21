SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_954DecodeSP01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode sku label Return sku, Lottable02                           */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 17-Oct-2016  James     1.0   WMS506 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_954DecodeSP01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cBarcode         NVARCHAR( 60),
   @cPickSlipNo      NVARCHAR( 20),
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18)  OUTPUT,
   @cUPC             NVARCHAR( 20)  OUTPUT,
   @nQTY             INT            OUTPUT,
   @cDropID          NVARCHAR( 20)  OUTPUT,
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

   DECLARE @nSKU_StartPos     INT,
           @nL02_StartPos     INT

   IF ISNULL( @cBarcode, '') = ''
      GOTO Quit

   IF @nFunc = 954 -- Pick Swap Lot
   BEGIN
      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @nSKU_StartPos = CHARINDEX( 'L', @cBarcode)

            SELECT @nL02_StartPos = CHARINDEX( 'S', @cBarcode)
--            SELECT '@nSKU_StartPos', @nSKU_StartPos
--            SELECT '@nL02_StartPos', @nL02_StartPos

            -- Invalid data
            IF @nSKU_StartPos = 0 OR @nL02_StartPos = 0
            BEGIN
               SET @cUPC = @cBarcode
               SET @cLottable02 = ''
               GOTO Quit
            END

            SELECT @cUPC = SUBSTRING( @cBarcode, @nSKU_StartPos + 1, ( @nL02_StartPos - 1) - @nSKU_StartPos)

            SELECT @cLottable02 = SUBSTRING( @cBarcode, @nL02_StartPos + 1, LEN( RTRIM( @cBarcode)) - @nL02_StartPos)
         END
      END
   END

Quit:

END

GO
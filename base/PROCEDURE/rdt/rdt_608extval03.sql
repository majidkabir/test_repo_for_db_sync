SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtVal03                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Validate 1 pallet 1 sku                                           */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 16-Mar-2018  James     1.0   WMS2605. Created                              */
/* 08-Sep-2022  Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtVal03]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cPOKey        NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60),
   @cID           NVARCHAR( 18),
   @cLOC          NVARCHAR( 10),
   @cMethod       NVARCHAR( 1),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @cRDLineNo     NVARCHAR( 10),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess    INT,
           @cID_SKU     NVARCHAR( 20)

   IF @nFunc = 608 -- Piece return
   BEGIN
      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check if the sku received b4
            SELECT @cID_SKU = ToID 
            FROM dbo.ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey
            AND   SKU = @cSKU
            AND   BeforeReceivedQty > 0

            -- SKU not yet received then no need further checking
            IF ISNULL(@cID_SKU, '') = ''
                  GOTO Quit
            ELSE
            BEGIN
               -- Check if received sku exists in other pallet
               -- one sku cannot appear in 2 id
               IF @cID_SKU <> @cID
               BEGIN
                  SET @nErrNo = 121201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Palletmixsku
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO
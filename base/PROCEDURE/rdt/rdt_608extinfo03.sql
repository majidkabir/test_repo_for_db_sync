SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_608ExtInfo03                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2018-04-18  1.0  Ung      WMS-4675 Created                           */
/* 2022-09-08  1.1  Ung      WMS-20348 Expand RefNo to 60 chars         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_608ExtInfo03] (
  @nMobile       INT,
  @nFunc         INT,
  @cLangCode     NVARCHAR( 3),
  @nStep         INT,
  @nAfterStep    INT,
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
  @cExtendedInfo NVARCHAR(20)  OUTPUT,
  @nErrNo        INT           OUTPUT,
  @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 608 -- Piece return
   BEGIN
      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get SKU on ID
            DECLARE @nSKU INT
            SELECT @nSKU = COUNT( DISTINCT SKU)
            FROM ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND ToLOC = @cLOC
               AND ToID = @cID
               AND BeforeReceivedQTY > 0

            SET @cExtendedInfo = 'TOID SKU: ' +  CAST( @nSKU AS NVARCHAR(5))
         END
      END
   END
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtUpd10                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Print pallet label                                                */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 04-Aug-2022  yeekung   1.0   WMS-20273 Created                             */
/* 15-Mar-2023  yeekung   1.1   WMS-21377 Change step (yeekung01)             */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600ExtUpd10] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,
   @nQTY         INT,
   @cReasonCode  NVARCHAR( 10),
   @cSuggToLOC   NVARCHAR( 10),
   @cFinalLOC    NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 15 -- ID --(yeekung01)
      BEGIN
         
         IF @nInputKey = 1  -- ENTER
         BEGIN
            DECLARE @cCurRD Cursor

            SET @cCurRD = CURSOR FOR
            SELECT ReceiptLineNumber
            FROM RECEIPTDETAIL RD (NOLOCK)
            WHERE RD.ReceiptKey = @cReceiptKey
               AND TOID = @cID
               AND Storerkey = @cStorerkey

            OPEN @cCurRD
            FETCH NEXT FROM @cCurRD INTO @cReceiptLineNumber
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
                  QTYReceived = RD.BeforeReceivedQTY,
                  FinalizeFlag = 'Y',
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               FROM dbo.ReceiptDetail RD
               WHERE RD.ReceiptKey = @cReceiptKey
                  AND receiptlinenumber = @cReceiptLineNumber

               FETCH NEXT FROM @cCurRD INTO @cReceiptLineNumber
            END
         END
      END
   END

Quit:

END

GO
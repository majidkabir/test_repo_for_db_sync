SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtVal04                                           */
/* Copyright      : MAERSK                                                    */
/*                                                                            */
/* Purpose: Validate if all qty received. Compare by sku                      */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 05-Mar-2019  James     1.0   WMS8215. Created                              */
/* 2022-09-08   Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */   
/* 2023-09-21   James     1.2   WMS-23653 Block user if overreceive (james01) */   
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtVal04]
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

   DECLARE @nQTYExpected_Total         INT
   DECLARE @nBeforeReceivedQTY_Total   INT
   DECLARE @cErrMsg1                   NVARCHAR(20)
   DECLARE @cErrMsg2                   NVARCHAR(20)


   IF @nFunc = 608 -- Piece return
   BEGIN
      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
             IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
                         WHERE ReceiptKey = @cReceiptKey 
                         AND   QtyExpected <> BeforeReceivedQty ) 
             BEGIN
               SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 135501, @cLangCode, 'DSP'), 7, 14) --EXCESS STOCK:
               SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 135502, @cLangCode, 'DSP'), 7, 14) --TO ID:
            
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2

               SET @nErrNo = 0   -- Prompt msgqueue only and allow to proceed ESC
               SET @cErrMsg = ''
               --SET @nErrNo = 135501
               --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not All Rcved
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO
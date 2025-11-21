SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtVal01                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Calc suggest location, booking                                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 23-Feb-2016  Ung       1.0   WMS-835 Created                               */
/* 27-Nov-2017  Ung       1.1   Fix set option                                */
/* 08-Sep-2022  Ung       1.2   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtVal01]
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

   DECLARE @bSuccess    INT
   DECLARE @nTranCount  INT

   IF @nFunc = 608 -- Piece return
   BEGIN
      IF @nStep = 1 -- ASN
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cReceiptKey <> '' -- ASN
            BEGIN
               -- Check if store is setup
               IF EXISTS( SELECT 1 FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND UserDefine02 = '')
               BEGIN
                  SET @nErrNo = 105501
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stor Not Set
                  GOTO Quit
               END
            END
         END
      END
      
      IF @nStep = 2 -- ID, LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cMethod <> '1' -- Pre-lottable
            BEGIN
               SET @nErrNo = 105502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedPreOption
               GOTO Quit
            END
         END
      END
      
      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get SKU info
            DECLARE @cBUSR9 NVARCHAR(30)
            SELECT @cBUSR9 = BUSR9 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
            
            IF @cBUSR9 = 'BEAUTY'
            BEGIN
               -- Check 1 SKU 1 carton (lottable09)
               IF EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND Lottable09 = @cLottable09 AND SKU <> @cSKU)
               BEGIN
                  SET @nErrNo = 105503
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BeautyNoMixSKU
                  GOTO Quit
               END
            END
            ELSE
            BEGIN
               -- Check mix beauty and non-beauty
               IF EXISTS( SELECT 1 
                  FROM ReceiptDetail RD WITH (NOLOCK) 
                     JOIN SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
                  WHERE RD.ReceiptKey = @cReceiptKey 
                     AND RD.Lottable09 = @cLottable09 
                     AND BUSR9 = 'BEAUTY')
               BEGIN
                  SET @nErrNo = 105504
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MixWithBeauty
                  GOTO Quit
               END
            END
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_608ExtVal01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
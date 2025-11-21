SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_608ExtVal06                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID only can have 1 sku                          */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2019-10-14  1.0  Ung         WMS-10643 Created                       */
/* 2020-06-12  1.1  YeeKung     WMS-13610 Add PopUp Msg  (yeekung01)    */
/* 2022-09-08  1.2  Ung         WMS-20348 Expand RefNo to 60 chars      */   
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtVal06]
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

   DECLARE  @cErrMsg1    NVARCHAR( 20),  --(yeekung01)
            @cErrMsg2    NVARCHAR( 20),
            @cErrMsg3    NVARCHAR( 20),
            @cErrMsg4    NVARCHAR( 20),
            @cErrMsg5    NVARCHAR( 20),
            @cErrMsg6    NVARCHAR( 20),
            @cErrMsg7    NVARCHAR( 20),
            @cErrMsg8    NVARCHAR( 20),
            @cErrMsg9    NVARCHAR( 20),
            @cSKUClass   NVARCHAR( 20),
            @cSKUBUSR5   NVARCHAR( 20),
            @cSKUDECODE  NVARCHAR( 60)

   IF @nFunc = 608 -- Piece return
   BEGIN
      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check ID only 1 SKU
            IF EXISTS( SELECT 1
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND ReceiptKey = @cReceiptKey
                  AND ToID = @cID
                  AND BeforeReceivedQty > 0
                  AND SKU <> @cSKU)
            BEGIN
               SET @nErrNo = 145201
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUinID
               GOTO Quit
            END

            SELECT @cSKUClass=TRIM(class) --(yeekung01)
                  ,@cSKUBUSR5=TRIM(BUSR5)
            FROM SKU (NOLOCK)
            WHERE SKU=@cSKU

            SET @cSKUDECODE=@cSKUClass +' '+@cSKUBUSR5

            IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE LISTNAME='POPUPDtl' --(yeekung01)
                        AND long=@cSKUDECODE
                        AND storerkey=@cStorerKey
                        AND code2=@nFunc)
                        AND NOT EXISTS (SELECT 1 FROM DBO.RECEIPTDETAIL WITH (NOLOCK)
                                    WHERE receiptkey =@cReceiptKey
                                       AND sku=@cSKU
                                       AND beforereceivedqty<>0)
            BEGIN

               SELECT @cErrMsg1=description
               FROM CODELKUP (NOLOCK)
               WHERE LISTNAME='POPUPDtl'
                  AND long=@cSKUDECODE
                  AND code2=@nFunc

               IF LEN(@cErrMsg1)>20
               BEGIN
                  SET @cErrMsg2 = CASE WHEN LEN(@cErrMsg1) between 21 and 40 THEN SUBSTRING(@cErrMsg1,21,40) ELSE '' END
                  SET @cErrMsg3 = CASE WHEN LEN(@cErrMsg1) between 41 and 60 THEN SUBSTRING(@cErrMsg1,41,60) ELSE '' END
               END

               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                  @cErrMsg1,
                  @cErrMsg2,
                  @cErrMsg3,
                  @cErrMsg4,
                  @cErrMsg5,
                  @cErrMsg6,
                  @cErrMsg7,
                  @cErrMsg8,
                  @cErrMsg9

               SET @nErrNo=0

            END
         END
      END

      IF @nStep = 5 -- Lottable after
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check ID only 1 SKU + 1 L01
            IF EXISTS( SELECT 1
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND ReceiptKey = @cReceiptKey
                  AND ToID = @cID
                  AND BeforeReceivedQty > 0
                  AND ((SKU <> @cSKU) OR (Lottable01 <> @cLottable01)))
            BEGIN
               SET @nErrNo = 145202
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixL01inID
               GOTO Quit
            END




         END
      END
   END

Quit:

END

GO
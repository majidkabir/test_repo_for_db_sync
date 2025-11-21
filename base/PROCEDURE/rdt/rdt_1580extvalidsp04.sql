SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtValidSP04                                */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called from: rdtfnc_PieceReceiving                                   */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 29-02-2016  1.0  ChewKP      SOS#364495. Created                     */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtValidSP04]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQtyExpected INT 
         , @nTotalScanQty INT
         , @cReceiptLineNumber NVARCHAR(5) 
 
         
   
   SET @nErrNo = 0 
   
   IF @nStep = 5 -- SKU QTY screen
   BEGIN

      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey 
                         AND ReceiptKey = @cReceiptKey 
                         AND SKU = @cSKU )
         BEGIN
               IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReceiptLog WITH (NOLOCK) 
                               WHERE ReceiptKey = @cReceiptKey
                               AND SKU = @cSKU ) 
               BEGIN
                  INSERT INTO rdt.rdtReceiptLog ( ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternPOKey, ExternLineNo, StorerKey, POKey, Sku, AltSku, Id, 
                                                  Status, QtyExpected, QtyReceived, UOM, PackKey, ToLoc, ToLot, ToId, DropID, ConditionCode, Lottable01, Lottable02,
                                                  Lottable03, Lottable04, Lottable05, PutawayLoc, RefNo)
                  SELECT  TOP 1 ReceiptKey, '', ExternReceiptKey, ExternPOKey, ExternLineNo, StorerKey, POKey, @cSku, '', '', 
                          '0', '0', @nQTY, '', '', @cToLoc, '', @cToId, '', '', @cLottable01, @cLottable02,
                          @cLottable03, @dLottable04, '', '', ''
                  FROM dbo.ReceiptDetail WITH (NOLOCK) 
                  WHERE ReceiptKey = @cReceiptKey
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 96451
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsLogFail
                     GOTO Quit
                  END
               END
               ELSE
               BEGIN
                  UPDATE rdt.rdtReceiptLog WITH (ROWLOCK) 
                  SET QtyReceived = QtyReceived + @nQty 
                  WHERE ReceiptKey = @cReceiptKey
                  AND SKU = @cSKU
                  
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 96456
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdLogFail
                     GOTO Quit
                  END
               END

               
               SET @nErrNo = 96452
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInASN
               GOTO Quit
         END

         SELECT
            @nQtyExpected = ISNULL( SUM(QtyExpected), 0),
            @nTotalScanQty = ISNULL( SUM(BeforeReceivedQty), 0)
         FROM dbo.Receiptdetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND Receiptkey = @cReceiptKey

         INSERT INTO TraceInfo (TraceName , TimeIn, Col1, col2, Col3, Col4,Col5 ) 
         VALUES ( 'rdt_1580ExtValidSP04' , Getdate(), @cReceiptKey, @cSKU, @nQTY, @nTotalScanQty, @nQtyExpected )
         

         IF @nTotalScanQty + @nQTY > @nQtyExpected
         BEGIN
            SELECT TOP 1 @cReceiptLineNumber = ReceiptLineNumber
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            GROUP BY ReceiptKey, ReceiptLineNumber, SKU 
            HAVING ReceiptKey = @cReceiptKey
            AND SKU = @cSKU
            AND SUM(QtyExpected) + @nQTY >  SUM(BeforeReceivedQty)  
            
            
            IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReceiptLog WITH (NOLOCK) 
                            WHERE ReceiptKey = @cReceiptKey
                            AND ReceiptLineNumber = @cReceiptLineNumber
                            AND SKU = @cSKU ) 
            BEGIN
            
               INSERT INTO rdt.rdtReceiptLog ( ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternPOKey, ExternLineNo, StorerKey, POKey, Sku, AltSku, Id, 
                                                  Status, QtyExpected, QtyReceived, UOM, PackKey, ToLoc, ToLot, ToId, DropID, ConditionCode, Lottable01, Lottable02,
                                                  Lottable03, Lottable04, Lottable05, PutawayLoc, RefNo)
               SELECT  TOP 1 ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternPOKey, ExternLineNo, StorerKey, POKey, @cSku, '', '', 
                       '0', '0', @nQTY, '', '', @cToLoc, '', @cToId, '', '', @cLottable01, @cLottable02,
                       @cLottable03, @dLottable04, '', '', ''
               FROM dbo.ReceiptDetail WITH (NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey
               AND SKU = @cSKU
               AND ReceiptLineNumber = @cReceiptLineNumber
               ORDER BY ReceiptLineNumber 
               
               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 96454
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsLogFail
                  GOTO Quit
               END
            END
            ELSE 
            BEGIN
               
                  UPDATE rdt.rdtReceiptLog WITH (ROWLOCK) 
                  SET QtyReceived = QtyReceived + @nQty 
                  WHERE ReceiptKey = @cReceiptKey
                  AND SKU = @cSKU
                  AND ReceiptLineNumber = @cReceiptLineNumber
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 96455
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdLogFail
                     GOTO Quit
                  END
                  
               
            END
            

            SET @nErrNo = 96453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OverReceive
            GOTO Quit
         END

      END
   END

Quit:
END

GO
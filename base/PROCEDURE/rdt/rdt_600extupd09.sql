SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtUpd09                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Print pallet label                                                */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 04-Aug-2022  yeekung   1.0   WMS-20273 Created                             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_600ExtUpd09] (
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
      IF @nStep = 4 -- SKU
      BEGIN
         DECLARE  @cRDSKU   NVARCHAR(20),
                  @cSKUUOM    NVARCHAR(20),
                  @cReceiptLineNumberOutput NVARCHAR(20),
                  @nRDQTY  INT,
                  @nCounter INT 

         IF @nInputKey = 0 -- ENTER
         BEGIN

            UPDATE receiptdetail WITH (ROWLOCK) 
            SET beforereceivedqty=0
            WHERE receiptkey=@cReceiptKey  

            IF @@ERROR<>0
            BEGIN
               GOTO QUIT
            END

            DECLARE C_Receiptdetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT sku,SUM(qtyexpected),UOM 
            FROM receiptdetail WITH (NOLOCK)    
            WHERE receiptkey=@cReceiptKey  
            AND   storerkey=@cStorerKey
            group by   sku,UOM
            
            OPEN C_Receiptdetail          
            FETCH NEXT FROM C_Receiptdetail INTO  @cRDSKU ,@nRDQTY,@cSKUUOM  
            WHILE (@@FETCH_STATUS <> -1)    
            BEGIN    

               EXEC rdt.rdt_Receive_V7
                  @nFunc         = @nFunc,
                  @nMobile       = @nMobile,
                  @cLangCode     = @cLangCode,
                  @nErrNo        = @nErrNo OUTPUT,
                  @cErrMsg       = @cErrMsg OUTPUT,
                  @cStorerKey    = @cStorerKey,
                  @cFacility     = @cFacility,
                  @cReceiptKey   = @cReceiptKey,
                  @cPOKey        = @cPOKey,
                  @cToLOC        = @cLOC,
                  @cToID         = @cID,
                  @cSKUCode      = @cRDSKU,
                  @cSKUUOM       = @cSKUUOM,
                  @nSKUQTY       = @nRDQTY,
                  @cUCC          = '',
                  @cUCCSKU       = '',
                  @nUCCQTY       = '',
                  @cCreateUCC    = '',
                  @cLottable01   = @cLottable01,
                  @cLottable02   = @cLottable02,
                  @cLottable03   = @cLottable03,
                  @dLottable04   = @dLottable04,
                  @dLottable05   = NULL,
                  @cLottable06   = @cLottable06,
                  @cLottable07   = @cLottable07,
                  @cLottable08   = @cLottable08,
                  @cLottable09   = @cLottable09,
                  @cLottable10   = @cLottable10,
                  @cLottable11   = @cLottable11,
                  @cLottable12   = @cLottable12,
                  @dLottable13   = @dLottable13,
                  @dLottable14   = @dLottable14,
                  @dLottable15   = @dLottable15,
                  @nNOPOFlag     = '',
                  @cConditionCode = '',
                  @cSubreasonCode = '',
                  @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT

               FETCH NEXT FROM C_Receiptdetail INTO  @cRDSKU ,@nRDQTY,@cSKUUOM 
            END

         END
      END
   END

Quit:

END

GO
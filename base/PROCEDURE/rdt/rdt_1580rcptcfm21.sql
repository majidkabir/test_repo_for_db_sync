SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm21                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2020-12-23 1.0  Chermaine  WMS-15872 Created                            */
/***************************************************************************/
CREATE PROC [RDT].[rdt_1580RcptCfm21](
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18),
   @cSKUCode       NVARCHAR( 20),
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,
   @cCreateUCC     NVARCHAR( 1),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @cSerialNo      NVARCHAR( 30) = '', 
   @nSerialQTY     INT = 0, 
   @nBulkSNO       INT = 0,
   @nBulkSNOQTY    INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cLottable06    NVARCHAR( 30)
          ,@cLottable07    NVARCHAR( 30)
          ,@cLottable08    NVARCHAR( 30)
          ,@cLottable09    NVARCHAR( 30)
          ,@cLottable10    NVARCHAR( 30)
          ,@cLottable11    NVARCHAR( 30)
          ,@cLottable12    NVARCHAR( 30)
          ,@dLottable13    DATETIME
          ,@dLottable14    DATETIME
          ,@dLottable15    DATETIME
   
   
   
   -- Get ASN
   SELECT TOP 1 
       --@cLottable01 = RD.Lottable01
      @cLottable02 = RD.Lottable02
      --,@cLottable03 = RD.Lottable03
      --,@dLottable04 = RD.Lottable04
      ,@dLottable05 = RD.Lottable05
      ,@cLottable06 = RD.Lottable06
      ,@cLottable07 = RD.Lottable07
      ,@cLottable08 = RD.Lottable08
      ,@cLottable09 = RD.Lottable09
      ,@cLottable10 = RD.Lottable10
      ,@cLottable11 = RD.Lottable11
      ,@cLottable12 = RD.Lottable12
      ,@dLottable13 = RD.Lottable13
      ,@dLottable14 = RD.Lottable14
      ,@dLottable15 = RD.Lottable15
   FROM Receipt R WITH (NOLOCK)
      JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
   WHERE R.StorerKey = @cStorerKey
      AND R.Facility = @cFacility
      AND RD.ReceiptKey = @cReceiptKey
      AND RD.SKU     = @cSKUCode 
   ORDER BY RD.ExternReceiptKey, RD.ExternLineNo      
      --AND RD.ReceiptLineNumber = @cUCCLineNumber
      --AND RD.POKey = @cUCCPOKey
      --AND RD.POLineNumber = @cUCCPOLineNumber


         
   EXEC rdt.rdt_Receive_v7  
      @nFunc          = @nFunc,
      @nMobile        = @nMobile,
      @cLangCode      = @cLangCode,
      @nErrNo         = @nErrNo  OUTPUT,
      @cErrMsg        = @cErrMsg OUTPUT,
      @cStorerKey     = @cStorerKey,
      @cFacility      = @cFacility,
      @cReceiptKey    = @cReceiptKey,
      @cPOKey         = @cPOKey,
      @cToLOC         = @cToLOC,
      @cToID          = @cToID,
      @cSKUCode       = @cSKUCode,
      @cSKUUOM        = @cSKUUOM,
      @nSKUQTY        = @nSKUQTY,
      @cUCC           = @cUCC,
      @cUCCSKU        = @cUCCSKU,
      @nUCCQTY        = @nUCCQTY,
      @cCreateUCC     = @cCreateUCC,
      @cLottable01    = @cLottable01,
      @cLottable02    = @cLottable02,   
      @cLottable03    = @cLottable03,
      @dLottable04    = @dLottable04,
      @dLottable05    = @dLottable05,
      @cLottable06    = @cLottable06,
      @cLottable07    = @cLottable07,
      @cLottable08    = @cLottable08,
      @cLottable09    = @cLottable09,
      @cLottable10    = @cLottable10,
      @cLottable11    = @cLottable11,
      @cLottable12    = @cLottable12,
      @dLottable13    = @dLottable13,
      @dLottable14    = @dLottable14,
      @dLottable15    = @dLottable15,
      @nNOPOFlag      = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = @cSubreasonCode
         
Quit:

END

GO
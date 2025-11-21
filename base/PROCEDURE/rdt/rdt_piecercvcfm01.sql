SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PieceRcvCfm01                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Force to show case count field for every sku received       */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 26-08-2015  1.0  James        SOS350478. Created                     */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_PieceRcvCfm01]
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10), -- Blank = receive to ReceiptDetail with blank POKey
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18), -- Blank = receive to blank ToID
   @cSKUCode       NVARCHAR( 20), -- SKU code. Not SKU barcode
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,       -- In master unit
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,       -- In master unit. Pass in the QTY for UCCWithDynamicCaseCNT
   @cCreateUCC     NVARCHAR( 1),  -- Create UCC. 1=Yes, the rest=No
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,
   @dLottable14    DATETIME,
   @dLottable15    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10),
   @cReceiptLineNumberOutput NVARCHAR( 5) = '' OUTPUT, 
   @cDebug         NVARCHAR( 1) = '0'
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT @cLottable06 = V_LoadKey
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Receive
   EXEC rdt.rdt_Receive_V7
      @nFunc          = @nFunc,
      @nMobile        = @nMobile,
      @cLangCode      = @cLangCode,
      @nErrNo         = @nErrNo     OUTPUT,
      @cErrMsg        = @cErrMsg    OUTPUT,
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
      @cSubreasonCode = @cSubreasonCode,
      @cReceiptLineNumberOutput = @cReceiptLineNumberOutput, 
      @cDebug = @cDebug
   
Fail:
   
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_608RcvCfm11                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Check return lottable05 exists, if yes use back old lottable05 */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2021-09-23 1.0  James   WMS-17764 Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_608RcvCfm11](
    @nFunc          INT,              
    @nMobile        INT,              
    @cLangCode      NVARCHAR( 3),     
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
    @cRDLineNo      NVARCHAR( 5)  OUTPUT,    
    @nErrNo         INT           OUTPUT,   
    @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @dTempLottable05      DATETIME
   
   IF ISNULL( @cLottable01, '') <> ''
   BEGIN
      SELECT TOP 1 @dTempLottable05 = Lottable05
      FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   Sku = @cSKUCode
      AND   Lottable01 = @cLottable01
      ORDER BY 1
      
      IF ISNULL( @dTempLottable05, 0) = 0
         SELECT TOP 1 @dTempLottable05 = Lottable05
         FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   Sku = @cSKUCode
         ORDER BY 1

      IF ISNULL( @dTempLottable05, 0) = 0
         SET @dTempLottable05 = NULL
         
      SET @dLottable05 = @dTempLottable05
   END

     -- Receive  
   EXEC rdt.rdt_Receive_V7_L05  
      @nFunc         = @nFunc,  
      @nMobile       = @nMobile,  
      @cLangCode     = @cLangCode,  
      @nErrNo        = @nErrNo OUTPUT,  
      @cErrMsg       = @cErrMsg OUTPUT,  
      @cStorerKey    = @cStorerKey,  
      @cFacility     = @cFacility,  
      @cReceiptKey   = @cReceiptKey,  
      @cPOKey        = @cPOKey,  
      @cToLOC        = @cToLOC,  
      @cToID         = @cToID,  
      @cSKUCode      = @cSKUCode,  
      @cSKUUOM       = @cSKUUOM,  
      @nSKUQTY       = @nSKUQTY,  
      @cUCC          = '',  
      @cUCCSKU       = '',  
      @nUCCQTY       = '',  
      @cCreateUCC    = '',  
      @cLottable01   = @cLottable01,  
      @cLottable02   = @cLottable02,  
      @cLottable03   = @cLottable03,  
      @dLottable04   = @dLottable04,  
      @dLottable05   = @dLottable05, 
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
      @nNOPOFlag     = @nNOPOFlag,  
      @cConditionCode = 'OK',  
      @cSubreasonCode = '',   
      @cReceiptLineNumberOutput = @cRDLineNo OUTPUT    
END
QUIT:

GO
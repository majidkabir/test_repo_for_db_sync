SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580DupFrMatch01                                */
/* Copyright      : LF Logistic                                         */
/*                                                                      */
/* Purpose: Determine copy value from which ReceiptDetail line          */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-09-04  1.0  James       WMS-14064 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580DupFrMatch01]
    @nMobile     INT  
   ,@nFunc       INT  
   ,@cLangCode   NVARCHAR(  3)  
   ,@cReceiptKey NVARCHAR( 10)  
   ,@cPOKey      NVARCHAR( 10)  
   ,@cToLOC      NVARCHAR( 10)  
   ,@cToID       NVARCHAR( 18)  
   ,@cSKU        NVARCHAR( 20)  
   ,@cUCC        NVARCHAR( 20)  
   ,@nQTY        INT            
   ,@cLottable01 NVARCHAR( 18)  
   ,@cLottable02 NVARCHAR( 18)  
   ,@cLottable03 NVARCHAR( 18)  
   ,@dLottable04 DATETIME       
   ,@dLottable05 DATETIME       
   ,@cLottable06 NVARCHAR( 30)  
   ,@cLottable07 NVARCHAR( 30)  
   ,@cLottable08 NVARCHAR( 30)  
   ,@cLottable09 NVARCHAR( 30)  
   ,@cLottable10 NVARCHAR( 30)  
   ,@cLottable11 NVARCHAR( 30)  
   ,@cLottable12 NVARCHAR( 30)  
   ,@dLottable13 DATETIME       
   ,@dLottable14 DATETIME       
   ,@dLottable15 DATETIME       
   ,@cOrg_ReceiptLineNumber       NVARCHAR( 5)  
   ,@nOrg_QTYExpected             INT           
   ,@nOrg_BeforeReceivedQTY       INT            
   ,@cReceiptLineNumber           NVARCHAR( 5)  
   ,@nQTYExpected                 INT            
   ,@nBeforeReceivedQTY           INT            
   ,@cReceiptLineNumber_Borrowed  NVARCHAR( 5)  
   ,@cDuplicateFromLineNo         NVARCHAR( 5) OUTPUT  
   ,@nErrNo      INT              OUTPUT  
   ,@cErrMsg     NVARCHAR( 20)    OUTPUT   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   -- New line
   IF ISNULL( @cReceiptLineNumber_Borrowed, '') = '' AND @nQTYExpected = 0 AND @nBeforeReceivedQTY = 1 -- Piece receiving
      SELECT TOP 1
         @cDuplicateFromLineNo = ReceiptLineNumber
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cSKU
         AND Lottable01 = @cLottable01
         AND Lottable02 = @cLottable02
      ORDER BY ExternReceiptKey, ExternLineNo

QUIT:
END -- End Procedure


GO
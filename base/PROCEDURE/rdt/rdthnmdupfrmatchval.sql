SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtHNMDupFrMatchVal                                 */
/* Copyright      : LF Logistic                                         */
/*                                                                      */
/* Purpose: Determine copy value from which ReceiptDetail line          */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 16-04-2014  1.0  Ung         SOS301005 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtHNMDupFrMatchVal]
    @nMobile     INT
   ,@nFunc       INT
   ,@cLangCode   NVARCHAR(  3)
   ,@cReceiptKey NVARCHAR( 10)
   ,@cPOKey      NVARCHAR( 10)
   ,@cToLOC      NVARCHAR( 10)
   ,@cToID       NVARCHAR( 18)
   ,@cLottable01 NVARCHAR( 18)
   ,@cLottable02 NVARCHAR( 18)
   ,@cLottable03 NVARCHAR( 18)
   ,@dLottable04 DATETIME 
   ,@cSKU        NVARCHAR( 20)
   ,@cUCC        NVARCHAR( 20)
   ,@nQTY        INT
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
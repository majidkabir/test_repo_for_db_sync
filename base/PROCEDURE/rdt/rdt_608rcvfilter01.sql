SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_608RcvFilter01                                  */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: ReceiptDetail sort order                                    */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2019-08-13  1.0  James       WMS-10122  Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_608RcvFilter01]
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
   ,@cCustomSQL  NVARCHAR( MAX) OUTPUT 
   ,@nErrNo      INT            OUTPUT 
   ,@cErrMsg     NVARCHAR( 20)  OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cReceiptLineNumber NVARCHAR(5)
   DECLARE @cExternLineNo NVARCHAR(20)

   SET @cReceiptLineNumber = ''

   -- KIT Type
   SELECT TOP 1 @cReceiptLineNumber = ReceiptLineNumber 
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   SKU = @cSKU
   AND   UserDefine01 = 'KIT'
   GROUP BY ReceiptLineNumber
   HAVING ISNULL( SUM( QTYExpected), 0) > ISNULL( SUM( BeforeReceivedQTY), 0)
   ORDER BY 1

   IF @cReceiptLineNumber = ''
   BEGIN
      -- KOF Type
      SELECT TOP 1 @cReceiptLineNumber = ReceiptLineNumber 
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   SKU = @cSKU
      AND   UserDefine01 = 'NORMAL'
      AND   ExternLineNo <> ''
      GROUP BY ReceiptLineNumber
      HAVING ISNULL( SUM( QTYExpected), 0) > ISNULL( SUM( BeforeReceivedQTY), 0)
      AND   COUNT( ExternLineNo ) > 1
      ORDER BY 1
   END

   IF @cReceiptLineNumber = ''
   BEGIN
      -- Normal Type
      SELECT TOP 1 @cReceiptLineNumber = ReceiptLineNumber 
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   SKU = @cSKU
      AND   UserDefine01 = 'NORMAL'
      GROUP BY ReceiptLineNumber
      HAVING ISNULL( SUM( QTYExpected), 0) > ISNULL( SUM( BeforeReceivedQTY), 0)
      ORDER BY 1
   END

   -- Piece return, everytime only receive 1 qty. So filter by receiptline
   IF @cReceiptLineNumber <> ''
      SET @cCustomSQL = @cCustomSQL + 
         '     AND ReceiptLineNumber = ''' + @cReceiptLineNumber + ''''  

QUIT:
END -- End Procedure

GO
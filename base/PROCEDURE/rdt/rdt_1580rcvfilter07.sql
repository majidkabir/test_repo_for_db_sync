SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1580RcvFilter07                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 22-03-2019  1.0  Ung         WMS-7837 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580RcvFilter07]
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

   DECLARE @cStorerKey NVARCHAR(15)
   
   -- Get receipt info
   SELECT @cStorerKey = StorerKey FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
   
   -- Check serial SKU
   IF EXISTS( SELECT TOP 1 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND SerialNoCapture IN ('1', '2'))
   BEGIN
      SET @cCustomSQL = @cCustomSQL + 
         ' AND Lottable06 <> '''' '
   END

Quit:

END

GO
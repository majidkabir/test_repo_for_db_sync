SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtHNMRcvFilter                                     */
/* Copyright      : IDS                                                 */
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
/* 26-02-2014  1.0  Ung         SOS301005 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtHNMRcvFilter]
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
   ,@cCustomSQL  NVARCHAR( MAX) OUTPUT
   ,@nErrNo      INT            OUTPUT
   ,@cErrMsg     NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cExternReceiptKey NVARCHAR(20)
   DECLARE @cExternLineNo NVARCHAR(20)
   
   SET @cExternReceiptKey = ''
   SET @cExternLineNo = ''
   
   SELECT TOP 1
      @cExternReceiptKey = ExternReceiptKey, 
      @cExternLineNo = ExternLineNo 
   FROM ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND SKU = @cSKU
      AND ExternReceiptKey <> ''
      AND ExternLineNo <> ''
      AND Lottable01 = @cLottable01
      AND Lottable02 = @cLottable02
      AND (QTYExpected - BeforeReceivedQTY) > 0
   ORDER BY ExternReceiptKey, ExternLineNo
   
   IF @cExternReceiptKey <> '' 
      SET @cCustomSQL = @cCustomSQL + 
      '     AND ExternReceiptKey = '''  + @cExternReceiptKey + '''' + 
      '     AND ExternLineNo = '''  + @cExternLineNo + ''''

   SET @cCustomSQL = @cCustomSQL + 
      '     AND Lottable01 = ''' + @cLottable01 + '''' + 
      '     AND Lottable02 = ''' + @cLottable02 + '''' + 
      ' ORDER BY ExternReceiptKey, ExternLineNo '      

QUIT:
END -- End Procedure


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_897RcvFilter01                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: ReceiptDetail filter polinenumber using ucc# (sourcekey)    */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 29-Jan-2018  1.0  James       WMS3779. Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_897RcvFilter01]
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
   
   DECLARE @cStorerKey     NVARCHAR(15)
   DECLARE @cPOLineNumber  NVARCHAR( 5)

   SELECT @cUCC = I_Field01, 
          @cStorerKey = StorerKey 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SELECT TOP 1 @cPOLineNumber = SUBSTRING( SourceKey, 11, 5)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   UCCNo = @cUCC
   AND   [Status] = '0'
   AND   SKU = @cSKU
   AND   Qty = @nQty -- (XX) 
   AND   SUBSTRING( SourceKey, 1, 10) = @cPOKey
   ORDER BY 1 

   

   SET @cCustomSQL = @cCustomSQL + 
   '     AND POLineNumber = ''' + @cPOLineNumber + ''' AND FinalizeFlag <> ''Y''' -- (XX) 

QUIT:
END -- End Procedure


GO
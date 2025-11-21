SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_609RcvFilter01                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: ReceiptDetail filter same userdefine04 (same loc)           */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 05-Oct-2016  1.0  James       WMS288 Created                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_609RcvFilter01]
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
   
   DECLARE @cExternReceiptKey NVARCHAR(20)
   DECLARE @cExternLineNo NVARCHAR(20)
   
   SET @cCustomSQL = @cCustomSQL + 
   '     AND UserDefine04 = ''' + @cToLOC + '''' 

QUIT:
END -- End Procedure


GO
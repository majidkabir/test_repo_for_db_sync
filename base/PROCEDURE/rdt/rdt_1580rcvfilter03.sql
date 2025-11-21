SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580RcvFilter03                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: ReceiptDetail sort order. Lottable02 = ECOM come first      */
/*          then the rest.                                              */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 05-Apr-2016  1.0  James       SOS367156 Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580RcvFilter03]
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
   

   IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey
               AND   Lottable02 = @cLottable02
               AND   SKU = @cSKU
               AND  (QTYExpected - BeforeReceivedQTY) > 0)  -- NOT FULLY RECEIPT
   BEGIN
      SET @cCustomSQL = @cCustomSQL + 
      '     AND Lottable02 = ''' + @cLottable02 + '''' 
   END

QUIT:
END -- End Procedure


GO
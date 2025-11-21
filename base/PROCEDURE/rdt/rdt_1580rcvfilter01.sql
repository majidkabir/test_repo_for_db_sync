SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580RcvFilter01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Link UCC and ReceiptDetail by POKey and POLineNo            */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 29-07-2015  1.0  Ung         SOS347745. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580RcvFilter01]
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
   
   -- Get Receipt info
   DECLARE @cStorerKey NVARCHAR(15)
   DECLARE @cPOLineNumber NVARCHAR(5) 
   DECLARE @cExternKey NVARCHAR( 20)
   
   SET @cExternKey = ''
   SET @cPOKey     = ''
   SET @cPOLineNumber = ''

   -- Get session info
   SELECT 
      @cStorerKey = StorerKey, 
      @cUCC = I_Field02 -- UCC
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE UserName = SUSER_SNAME()
   
   -- Get UCC info
   SELECT 
       @cExternKey    = ExternKey
      ,@cPOKey        = SUBSTRING(UCC.Sourcekey, 1, 10)   
      ,@cPOLineNumber = SUBSTRING(UCC.Sourcekey, 11, 5)   
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE UCCNo = @cUCC 
      AND StorerKey = @cStorerKey 
      AND SKU = @cSKU 

   -- Build custom SQL
   IF @cExternKey <> ''
   BEGIN
      SET @cCustomSQL = @cCustomSQL + 
      ' AND RTRIM( ExternReceiptKey) = ' + QUOTENAME( RTRIM( @cExternKey), '''') + 
      ' AND RTRIM( POKey) = ' + QUOTENAME( RTRIM( @cPOKey), '''') + 
      ' AND RTRIM( POLineNumber) = ' + QUOTENAME( RTRIM( @cPOLineNumber), '''')
   END
QUIT:
END -- End Procedure


GO
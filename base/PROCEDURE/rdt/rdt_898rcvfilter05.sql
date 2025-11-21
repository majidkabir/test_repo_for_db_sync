SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_898RcvFilter05                                  */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: ReceiptDetail filter                                        */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 19-08-2022  1.0  yeekung     WMS-19671 Created                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_898RcvFilter05]
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

   
   DECLARE @cUserDefined03 NVARCHAR(20)
   DECLARE @cExterKey      NVARCHAR(20)
   DECLARE @cStorerKey     NVARCHAR(15)

   -- Get Receipt info
   SELECT @cStorerKey = StorerKey FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

   -- Get UCC info
   SET @cUserDefined03 = ''
   SET @cExterKey = ''
   SELECT
      @cUserDefined03 = UserDefined03,
      @cExterKey = ExternKey
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cUCC
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Build custom SQL
   IF @cExterKey <> ''
      SET @cCustomSQL = @cCustomSQL + ' AND ExternReceiptKey = ''' + RTRIM( @cExterKey) + ''''
   IF @cUserDefined03 <> ''
      SET @cCustomSQL = @cCustomSQL +
         ' AND (RTRIM( UserDefine03) + RTRIM( UserDefine02) = ''' + RTRIM( @cUserDefined03) + '''' +
         '   OR RTRIM( UserDefine03) = ''' + RTRIM( @cUserDefined03) + ''')'


QUIT:
END -- End Procedure

GO
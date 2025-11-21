SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_608RcvFilter04                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Filter by RD.UDF08                                          */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2023-08-24  1.0  yeekung     WMS-23405 Created                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608RcvFilter04]
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
   ,@cLottable05 DATETIME
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

   IF @nFunc = 608
   BEGIN
      IF EXISTS ( SELECT 1
                  FROM Receipt R(Nolock)
                  WHERE Receiptkey = @cReceiptKey
                     AND R.ReceiptGroup = 'AFS'
                     AND R.DOCTYPE = 'R')
      BEGIN
         SET @cCustomSQL = @cCustomSQL +
            '     AND Subreasoncode ='''' '
      END
   END
END


GO
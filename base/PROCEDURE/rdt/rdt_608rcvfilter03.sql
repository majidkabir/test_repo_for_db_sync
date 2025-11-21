SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_608RcvFilter03                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Filter by RD.UDF08                                          */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2022-08-01  1.0  Ung         WMS-20251 Created                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608RcvFilter03]
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
      -- Get session info
      DECLARE @cRefNo NVARCHAR( 30)
      SELECT @cRefNo = V_String41
      FROM rdt.rdtMobRec WITH (NOLOCK) 
      WHERE Mobile = @nMobile
      
      -- Check carton ID scanned
      IF EXISTS( SELECT TOP 1 1 
         FROM dbo.Receipt R WITH (NOLOCK) 
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.ReceiptKey = @cReceiptKey
            AND RD.UserDefine08 = @cRefNo) -- Carton ID
      BEGIN
         SET @cCustomSQL = @cCustomSQL +
            '     AND UserDefine08 = ' + QUOTENAME( @cRefNo, '''')
      END
   END
END


GO
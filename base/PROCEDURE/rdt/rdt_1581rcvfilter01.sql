SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1581RcvFilter01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Filter by Lot01                                             */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 21-11-2018  1.0  James       WMS6749 Created                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1581RcvFilter01]
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
   
   SET @cCustomSQL = @cCustomSQL + 
      '     AND Lottable01 = ' + QUOTENAME( @cLottable01, '''')

QUIT:
END -- End Procedure


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1580RcvFilter04                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Filter by ToID                                              */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 01-06-2018  1.0  Ung         WMS-5288 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580RcvFilter04]
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
      '     AND ToID = ' + QUOTENAME( @cToID, '''')

QUIT:
END -- End Procedure


GO
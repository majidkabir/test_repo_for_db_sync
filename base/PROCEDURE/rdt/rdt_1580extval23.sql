SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal23                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID                                              */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 30-09-2021  1.0  Chermaine   WMS-18001 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtVal23]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   
   IF @nStep = 4 -- Lottable
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
      	DECLARE @cHostwhcode NVARCHAR(10)
      	SELECT  @cHostwhcode = Hostwhcode FROM Loc WITH (NOLOCK) WHERE Loc = @cToLOC 

         IF @cLottable03 <> @cHostwhcode
         BEGIN
            SET @nErrNo = 176301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lot03<>HostWh
            GOTO Quit
         END
      END
   END

Quit:
END

GO
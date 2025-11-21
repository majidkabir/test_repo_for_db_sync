SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal20                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID                                              */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 08-01-2021  1.0  Chermaine   WMS-15775 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtVal20]
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
   
   IF @nStep = 4 -- lottable
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF EXISTS (SELECT 1 FROM receiptDetail WITH (NOLOCK) WHERE storerKey = @cStorerKey AND receiptKey = @cReceiptKey AND lottable02 = @cLottable02)
         BEGIN
   	      SET @nErrNo = 162101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate Value
            GOTO Quit
         END
      END
   END

Quit:
END

GO
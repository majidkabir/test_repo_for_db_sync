SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal06                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID only can have 1 sku                          */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 14-04-2016  1.0  James       SOS367156. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtVal06]
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

   DECLARE @cErrMsg1    NVARCHAR( 20),
           @cErrMsg2    NVARCHAR( 20),
           @cErrMsg3    NVARCHAR( 20),
           @cErrMsg4    NVARCHAR( 20),
           @cErrMsg5    NVARCHAR( 20)
               
   IF @nStep = 3 -- To ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- To ID is mandatory
         IF ISNULL( @cToID, '') = ''
         BEGIN
            SET @nErrNo = 98801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet ID req
            GOTO Quit
         END
         
         -- Check valid format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TOID', @cToID) = 0
         BEGIN
            SET @nErrNo = 98802
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv pallet id
            GOTO Quit
         END
      END
   END


Quit:
END

GO
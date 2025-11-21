SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal04                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID only can have 1 sku                          */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 14-04-2016  1.0  James       SOS367156. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtVal04]
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

   IF @nStep = 5 -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- 1 pallet only allow 1 sku
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   ReceiptKey = @cReceiptKey
                     AND   ToID = @cToID
                     AND   BeforeReceivedQty > 0
                     AND   SKU <> @cSKU)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = rdt.rdtgetmessage( 98803, @cLangCode, 'DSP') --One pallet only 
            SET @cErrMsg2 = rdt.rdtgetmessage( 98804, @cLangCode, 'DSP') --Allow one sku 

            SET @cErrMsg1 = SUBSTRING( @cErrMsg1, 7, 14)
            SET @cErrMsg2 = SUBSTRING( @cErrMsg2, 7, 14)
            
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END
            
            SET @nErrNo = 98803
            GOTO Quit
         END

      END
   END

Quit:
END

GO
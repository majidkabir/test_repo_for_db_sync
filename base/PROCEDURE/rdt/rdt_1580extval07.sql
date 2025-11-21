SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal07                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID only can have 1 sku                          */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 23-02-2018  1.0  ChewK       WMS-4904. Created                       */
/************************************************************************/


CREATE PROCEDURE [RDT].[rdt_1580ExtVal07]
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
            SET @nErrNo = 119851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDReq
            GOTO Quit
         END
         
        
      END
   END

   IF @nStep = 5 -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- 1 pallet only allow 1 sku
--         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
--                     WHERE StorerKey = @cStorerKey
--                     AND   ReceiptKey = @cReceiptKey
--                     AND   ToID = @cToID
--                     AND   BeforeReceivedQty > 0
--                     AND   SKU <> @cSKU)
--         BEGIN
--            SET @nErrNo = 119852
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUinID
--            GOTO Quit
--         END
         
         IF EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                    WHERE StorerKey = @cStorerKey
                    AND   ReceiptKey = @cReceiptKey
                    AND   ToID = @cToID
                    --AND   BeforeReceivedQty > 0
                    AND   SKU <> @cSKU)
         BEGIN
            SET @nErrNo = 119852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUinID
            GOTO Quit
         END
         
         
         IF EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK) 
                    WHERE StorerKey = @cStorerKey
                    AND ID = @cToID
                    AND SKU <> @cSKU
                    AND Loc = @cToLoc
                    AND Qty > 0 )
         BEGIN
            SET @nErrNo = 119853
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUinID
            GOTO Quit
         END

      END
   END

Quit:
END

GO
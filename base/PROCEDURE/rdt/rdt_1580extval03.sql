SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal03                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID cannot mix sku per pallet based on rdt config*/
/*                                                                      */
/* Called from: rdtfnc_PieceReceiving                                   */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 27-01-2015  1.0  James       SOS331716. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtVal03]
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

   DECLARE @cDisAllowMixPalletSKU   NVARCHAR( 1)
   
   IF @nStep = 5 -- SKU QTY screen
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cDisAllowMixPalletSKU = rdt.RDTGetConfig( @nFunc, 'DisAllowMixPalletSKU', @cStorerKey)
         IF @cDisAllowMixPalletSKU IN ('', '0')
         BEGIN
            SET @cDisAllowMixPalletSKU = '0'
            GOTO Quit
         END

         IF @cDisAllowMixPalletSKU = '1'
         BEGIN
            IF EXISTS( SELECT TOP 1 1 
               FROM ReceiptDetail WITH (NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey 
                  AND ToID = @cToID 
                  AND SKU <> @cSKU
                  AND BeforeReceivedQTY > 0)
            BEGIN
               SET @nErrNo = 51601
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mix SKU on ID
               GOTO Quit
            END
            
         END
      END
   END

Quit:
END

GO
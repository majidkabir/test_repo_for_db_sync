SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1581ExtVal04                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: check mix SKU on carton (L01)                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 11-09-2022  1.0  yeekung    WMS-21053-Add insertmsgqueue             */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1581ExtVal04]
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

   DECLARE @cIVAS NVARCHAR(20)
   DECLARE @cMode NVARCHAR(20)


   IF @nStep = 5 -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN

         
         SET @cMode =  rdt.rdtGetConfig( @nFunc, 'PopUpMode', @cStorerKey) 

         IF @cMode='1'
         BEGIn
            -- Check UserDefine10 in OriLine ASN
            IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK)
                       WHERE SKU = @cSKU
                       AND IVAS <>''
                       AND storerkey=@cStorerKey
                       )
            BEGIN
               SELECT @cIVAS=IVAS FROM SKU WITH (NOLOCK)
               WHERE SKU = @cSKU
               AND IVAS <>''
               AND storerkey=@cStorerKey

               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,  --(yeekung05)  
               'IVAS:',  
               @cIVAS,
               '%I_Field',
               '',
               '',
               '',
               '',
               '',
               '',
               '',
               '',
               '',
               '',
               @cMode

               SET @nErrNo=0
            END
         END
      END
   END
Quit:
END

GO
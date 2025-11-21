SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1580ExtVal26                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID only can have 1 sku                          */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 31-03-2023  1.0  yeekung      WMS-22166. Created                     */
/************************************************************************/


CREATE   PROCEDURE [RDT].[rdt_1580ExtVal26]
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
            SET @nErrNo = 198651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDReq
            GOTO Quit
         END


      END
   END

   IF @nStep = 5 -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN

         IF EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                    WHERE StorerKey = @cStorerKey
                    AND   ReceiptKey = @cReceiptKey
                    AND   ToID = @cToID
                    --AND   BeforeReceivedQty > 0
                    AND   SKU <> @cSKU)
         BEGIN
            SET @nErrNo = 198652
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
            SET @nErrNo = 198653
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUinID
            GOTO Quit
         END

         DECLARE @fWeight         FLOAT
         DECLARE @fCube           FLOAT
         DECLARE @fLength         FLOAT
         DECLARE @fWidth          FLOAT
         DECLARE @fHeight         FLOAT

         -- Get SKU info
         SELECT
            @fWeight      = SKU.STDGrossWGT,
            @fCube        = SKU.STDCube,
            @fLength      = SKU.Length,
            @fWidth       = sku.Width,
            @fHeight      = sku.Height
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

         IF @fWeight = 0 
         BEGIN
            SET @nErrNo = 198654
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupWeight
            SET @cErrMsg1 = @cErrMsg
         END

         IF @fCube = 0 
         BEGIN
            SET @nErrNo = 198655
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupCube
            SET @cErrMsg2 = @cErrMsg
         END

         IF @fLength = 0 
         BEGIN
            SET @nErrNo = 198656
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupLength
            SET @cErrMsg3 = @cErrMsg
         END

         IF @fWidth = 0 
         BEGIN
            SET @nErrNo = 198657
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupWidth
            SET @cErrMsg4 = @cErrMsg
         END

         IF @fHeight = 0 
         BEGIN
            SET @nErrNo = 198658
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupHeight
            SET @cErrMsg5 = @cErrMsg
         END

         IF ISNULL(@cErrMsg1,'')<>'' OR ISNULL(@cErrMsg2,'')<>'' OR ISNULL(@cErrMsg3,'')<>'' OR ISNULL(@cErrMsg4,'')<>'' OR ISNULL(@cErrMsg5,'')<>''
         BEGIN
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5,
            '', '', '', '', '',
            '', '', '', ''
         END

      END
   END

Quit:
END

GO
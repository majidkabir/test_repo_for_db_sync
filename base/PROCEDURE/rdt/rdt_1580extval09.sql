SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal09                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID only can have 1 sku                          */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 10-04-2018  1.0  ChewKP      WMS-4126. Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtVal09]
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
           @cErrMsg5    NVARCHAR( 20),
           @cLoadKey    NVARCHAR( 10),
           @cUserName   NVARCHAR( 18) 
           
   SELECT @cUserName = UserName 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
               
   IF @nStep = 3 -- To ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- To ID is mandatory
         IF ISNULL( @cToID, '') = ''
         BEGIN
            SET @nErrNo = 122601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet ID req
            GOTO Quit
         END
         
         SELECT @cLoadKey = UserDefine03
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND ReceiptKey = @cReceiptKey 
         
         -- Check valid format
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                     INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
                     WHERE RD.StorerKey = @cStorerKey
                     AND R.UserDefine03 = @cLoadKey
                     AND RD.ToID <> @cToID
                     AND RD.BeforeReceivedQty > 0 
                     AND FinalizeFlag <> 'Y' 
                     AND RD.EditWho = @cUserName )
         BEGIN
            SET @nErrNo = 122602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ClosePrevID
            GOTO Quit
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                     INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
                     WHERE RD.StorerKey = @cStorerKey
                     AND R.UserDefine03 = @cLoadKey
                     AND RD.ToID = @cToID
                     AND FinalizeFlag = 'Y' )
         BEGIN
            SET @nErrNo = 122603
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDClosed
            GOTO Quit
         END
      END
   END


Quit:
END

GO
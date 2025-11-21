SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_898ExtVal02                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2018-11-13 1.0  ChewKP  WMS-6931 Created                             */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898ExtVal02]
   @nMobile     INT      
  ,@nFunc       INT      
  ,@cLangCode   NVARCHAR(  3) 
  ,@cReceiptKey NVARCHAR( 10) 
  ,@cPOKey      NVARCHAR( 10) 
  ,@cLOC        NVARCHAR( 10) 
  ,@cToID       NVARCHAR( 18) 
  ,@cLottable01 NVARCHAR( 18) 
  ,@cLottable02 NVARCHAR( 18) 
  ,@cLottable03 NVARCHAR( 18) 
  ,@dLottable04 DATETIME  
  ,@cUCC        NVARCHAR( 20)
  ,@nErrNo      INT       OUTPUT 
  ,@cErrMsg     NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cExternKey     NVARCHAR(20)
          ,@cUserDefine09  NVARCHAR (30) 
          ,@cStorerKey     NVARCHAR(15)

   SELECT @cStorerKey = StorerKey
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile 

   
   IF @nFunc = 898 -- UCC receiving
   BEGIN
      --IF @nStep = 6 
      --BEGIN
         --IF @nInputKey = 1 -- ENTER
         --BEGIN
           
           SELECT 
               @cUserDefine09 = UserDefined09  
              ,@cExternKey    = ExternKey 
           FROM UCC WITH (NOLOCK) 
           WHERE StorerKey = @cStorerKey
           AND UCCNo = @cUCC 
           
           IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey
                           AND ReceiptKey = @cReceiptKey
                           AND ExternReceiptKey = @cExternKey
                           AND ExternLineNo = @cUserDefine09 )
           BEGIN
              SET @nErrNo = 131701
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidUCC
           END
           
           IF EXISTS ( SELECT 1 FROM rdt.rdtUCCReceive2Log WITH (NOLOCK) 
                       WHERE StorerKey = @cStorerKey
                       AND ReceiptKey = @cReceiptKey
                       AND UCCNo = @cUCC
                       AND Status = '9')
           BEGIN
              SET @nErrNo = 131702
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCScanned
           END
           
         --END
      --END
   END
   
Quit:

END

GO
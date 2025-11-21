SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_898ExtUpd07                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Extended Upd for Levis                                      */
/*          Changes in UCC Receive to process for returns               */
/*                                                                      */
/* Date        Rev   Author       Purposes                              */
/* 18-11-2024  1.0   ShaoAn       FCR-1103 Created                      */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_898ExtUpd07
    @nMobile     INT
   ,@nFunc       INT
   ,@nStep       INT
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
   ,@cSKU        NVARCHAR( 20)
   ,@nQTY        INT
   ,@cParam1     NVARCHAR( 20) OUTPUT
   ,@cParam2     NVARCHAR( 20) OUTPUT
   ,@cParam3     NVARCHAR( 20) OUTPUT
   ,@cParam4     NVARCHAR( 20) OUTPUT
   ,@cParam5     NVARCHAR( 20) OUTPUT
   ,@cOption     NVARCHAR( 1)
   ,@nErrNo      INT       OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @cStorerKey NVARCHAR( 15)
            

   -- Get Receipt info
   SELECT @cStorerKey = StorerKey
   FROM rdt.RDTMOBREC WITH (NOLOCK) where mobile= @nMobile

   IF @nFunc = 898
   BEGIN
      IF @nStep = 99 OR @nStep = 10 
      BEGIN
         IF ISNULL(@cUCC,'') <> ''
         BEGIN
            UPDATE dbo.ReceiptDetail SET UserDefine01 = @cUCC WHERE ReceiptKey = @cReceiptKey AND StorerKey=@cStorerKey AND Sku=@cSKU
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 229153
               SET @cErrMsg = [rdt].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP') --'UpdUDF01Fail'
               GOTO Quit
            END
         END 
      END
   END

QUIT:
END 


GO
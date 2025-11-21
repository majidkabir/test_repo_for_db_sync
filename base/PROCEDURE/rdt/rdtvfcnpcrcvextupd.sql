SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtVFCNPCRcvExtUpd                                  */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID                                              */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 14-11-2013  1.0  Ung         SOS288143. Created                      */
/* 02-01-2015  1.1  Ung         SOS328774. Send WCS msg 4 retail return */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFCNPCRcvExtUpd]
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
   ,@nAfterStep   INT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nStep = 3 -- ToID
   BEGIN
      -- Check blank
      IF @cToID = ''
      BEGIN
         SET @nErrNo = 83501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToID
         GOTO Quit
      END

      -- Check format
      IF LEFT( @cToID, 2) <> 'VF' OR @cToID = @cToLOC
      BEGIN
         SET @nErrNo = 83502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
         GOTO Quit
      END
   END

   IF @nStep = 4 -- Lottables
   BEGIN
      IF @nInputKey = 0 -- ESC
      BEGIN
         -- Get Receipt info  
         DECLARE @cDocType NVARCHAR(1)  
         DECLARE @cRecType NVARCHAR(10)  
         SELECT   
            @cDocType = DocType,   
            @cRecType = RecType  
         FROM Receipt WITH (NOLOCK)   
         WHERE ReceiptKey = @cReceiptKey
           
         -- Return and retail  
         IF @cDocType = 'R' AND @cRecType IN (SELECT Code FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RECTYPE' AND Short = 'R' AND StorerKey = @cStorerKey)  
         BEGIN  
            -- Case ID received stock 
            IF @cToID <> '' AND EXISTS( SELECT TOP 1 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ToID = @cToID AND BeforeReceivedQTY > 0)
               EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, '', @nErrNo OUTPUT, @cErrMsg OUTPUT, @cReceiptKey, @cToID
         END
      END
   END

QUIT:
END

GO
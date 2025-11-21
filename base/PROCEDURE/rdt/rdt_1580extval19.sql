SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/    
/* Store procedure: rdt_1580ExtVal19                                    */    
/* Copyright      : LF logistics                                        */    
/*                                                                      */    
/* Purpose: Validate lottable must have value if setup                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author      Purposes                                */    
/* 2021-01-08  1.0  James       WMS-16029. Created                      */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1580ExtVal19]    
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
    
   DECLARE @cLottable01Required NVARCHAR( 20) = ''
   DECLARE @cLottable02Required NVARCHAR( 20) = ''
   DECLARE @cLottable03Required NVARCHAR( 20) = ''
   DECLARE @cLottable04Required NVARCHAR( 20) = ''
   
   IF @nStep = 4 -- Lottable    
   BEGIN    
      IF @nInputKey = 1 -- ENTER    
      BEGIN    
         SET @cLottable01Required = rdt.rdtGetConfig( @nFunc, 'Lottable01', @cStorerKey)
         SET @cLottable02Required = rdt.rdtGetConfig( @nFunc, 'Lottable02', @cStorerKey)
         SET @cLottable03Required = rdt.rdtGetConfig( @nFunc, 'Lottable03', @cStorerKey)
         SET @cLottable04Required = rdt.rdtGetConfig( @nFunc, 'Lottable04', @cStorerKey)
         
         IF @cLottable01Required NOT IN ('', '0') AND ISNULL( @cLottable01, '') = ''
         BEGIN
            SET @nErrNo = 162051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable01 req'
            GOTO Quit
         END

         IF @cLottable02Required NOT IN ('', '0') AND ISNULL( @cLottable02, '') = ''
         BEGIN
            SET @nErrNo = 162052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable02 req'
            GOTO Quit
         END

         IF @cLottable03Required NOT IN ('', '0') AND ISNULL( @cLottable03, '') = ''
         BEGIN
            SET @nErrNo = 162053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable03 req'
            GOTO Quit
         END

         IF @cLottable04Required NOT IN ('', '0') AND ISNULL( @dLottable04, '') = ''
         BEGIN
            SET @nErrNo = 162054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable04 req'
            GOTO Quit
         END
      END    
   END    
    
Quit:    
END     

GO
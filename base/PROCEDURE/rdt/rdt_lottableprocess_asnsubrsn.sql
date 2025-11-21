SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_LottableProcess_ASNSubRSN                             */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Check price tag                                                   */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 26-08-2020  Ung       1.0   WMS-14617 Created                              */ 
/* 01-12-2020  YeeKung   1.1   WMS-15444 Add receipttype     (yeekung01)      */ 
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_LottableProcess_ASNSubRSN]  
    @nMobile          INT  
   ,@nFunc            INT  
   ,@cLangCode        NVARCHAR( 3)  
   ,@nInputKey        INT  
   ,@cStorerKey       NVARCHAR( 15)  
   ,@cSKU             NVARCHAR( 20)  
   ,@cLottableCode    NVARCHAR( 30)  
   ,@nLottableNo      INT  
   ,@cLottable        NVARCHAR( 30)  
   ,@cType            NVARCHAR( 10)  
   ,@cSourceKey       NVARCHAR( 15)  
   ,@cLottable01Value NVARCHAR( 18)  
   ,@cLottable02Value NVARCHAR( 18)  
   ,@cLottable03Value NVARCHAR( 18)  
   ,@dLottable04Value DATETIME  
   ,@dLottable05Value DATETIME  
   ,@cLottable06Value NVARCHAR( 30)  
   ,@cLottable07Value NVARCHAR( 30)  
   ,@cLottable08Value NVARCHAR( 30)  
   ,@cLottable09Value NVARCHAR( 30)  
   ,@cLottable10Value NVARCHAR( 30)  
   ,@cLottable11Value NVARCHAR( 30)  
   ,@cLottable12Value NVARCHAR( 30)  
   ,@dLottable13Value DATETIME  
   ,@dLottable14Value DATETIME  
   ,@dLottable15Value DATETIME  
   ,@cLottable01      NVARCHAR( 18) OUTPUT  
   ,@cLottable02      NVARCHAR( 18) OUTPUT  
   ,@cLottable03      NVARCHAR( 18) OUTPUT  
   ,@dLottable04      DATETIME      OUTPUT  
   ,@dLottable05      DATETIME      OUTPUT  
   ,@cLottable06      NVARCHAR( 30) OUTPUT  
   ,@cLottable07      NVARCHAR( 30) OUTPUT  
   ,@cLottable08      NVARCHAR( 30) OUTPUT  
   ,@cLottable09      NVARCHAR( 30) OUTPUT  
   ,@cLottable10      NVARCHAR( 30) OUTPUT  
   ,@cLottable11      NVARCHAR( 30) OUTPUT  
   ,@cLottable12      NVARCHAR( 30) OUTPUT  
   ,@dLottable13      DATETIME      OUTPUT  
   ,@dLottable14      DATETIME      OUTPUT  
   ,@dLottable15      DATETIME      OUTPUT  
   ,@nErrNo           INT           OUTPUT  
   ,@cErrMsg          NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cMsg NVARCHAR(20),
           @cReceiptkey NVARCHAR(20),
           @cReceiptType NVARCHAR(20)

   SELECT @cReceiptkey=V_ReceiptKey  from rdt.RDTMOBREC (nolock) where Mobile=@nMobile

   SELECT @cReceiptType=RECType from RECEIPT (NOLOCK) where receiptkey=@cReceiptkey and storerkey=@cStorerKey
   
   IF @cReceiptType='HM_R'
   BEGIN
      -- Check valid sub reason  
      IF NOT EXISTS( SELECT 1 FROM CodeLKUP (NOLOCK) WHERE StorerKey = @cStorerKey AND ListName = 'ASNSUBRSN' AND Code = @cLottable)  
      BEGIN  
         SET @nErrNo = 158001  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SubRSN  
         GOTO Quit  
      END  
   END
   ELSE IF  @cReceiptType IN ('HM_F','HM_U')
   BEGIN
      IF (ISNULL(@cLottable,'')<>'')
      BEGIN
         -- Check valid sub reason  
         IF NOT EXISTS( SELECT 1 FROM CodeLKUP (NOLOCK) WHERE StorerKey = @cStorerKey AND ListName = 'ASNSUBRSN' AND Code = @cLottable)  
         BEGIN  
            SET @nErrNo = 158002 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SubRSN  
            GOTO Quit  
         END
      END
   END
Quit:  
     
END  

GO
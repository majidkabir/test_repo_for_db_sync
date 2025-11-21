SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_LottableProcess_AESOPValidateLottable                 */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Validate lottable01 entered                                       */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 2023-04-27  James     1.0   WMS-22265 Created                              */  
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_LottableProcess_AESOPValidateLottable]  
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
  
   DECLARE @cReceiptKey       NVARCHAR( 10) = ''
   DECLARE @cTempLottable01   NVARCHAR( 18) = ''
   DECLARE @cID               NVARCHAR( 18) = ''
   
   SET @cReceiptKey = @cSourceKey  
     
   IF @cType = 'PRE'  
      GOTO Quit  
     
   IF @cType = 'POST'  
   BEGIN  
      -- Check blank  
      IF ISNULL(@cLottable01Value,'') = ''  
      BEGIN  
       SET @nErrNo = 200301  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lot01  
         GOTO Quit  
      END  


      IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
                      WHERE ReceiptKey = @cReceiptKey  
                      AND   Lottable01 = @cLottable01Value)  
      BEGIN  
         SET @nErrNo = 200302  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Data Not Found  
         GOTO Quit  
      END  

      SELECT @cID = V_ID
      FROM rdt.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile
      
      SELECT TOP 1 @cTempLottable01 = Lottable01
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND  ReceiptKey = @cReceiptKey
      AND  Sku = @cSKU
      AND   ToId = @cID
      AND   BeforeReceivedQty > 0
      ORDER BY 1
      
      IF ISNULL( @cTempLottable01, '') <> ''
      BEGIN
      	IF @cTempLottable01 <> @cLottable01Value
         BEGIN  
            SET @nErrNo = 200303  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Mix Lot01  
            GOTO Quit  
         END  

      END
      
      IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
                  WHERE StorerKey = @cStorerKey
                  AND   ReceiptKey = @cReceiptKey  
                  AND   Sku = @cSKU  
                  AND   Lottable01 = @cLottable01Value  
                  AND   QtyExpected < BeforeReceivedQty)  
      BEGIN  
         SET @nErrNo = 200304  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lot01 OverRcv  
         GOTO Quit  
      END  
   END  
    
Quit:  
     
END  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_LottableProcess_RCValidateLottable                    */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Check price tag                                                   */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 2021-03-11  James     1.0   WMS-16529 Created                              */  
/* 2021-06-11  yeekung   1.1   WMS-17153 Add Overreceive (yeekung01)          */  
/* 2022-12-08  James     1.2   INC1972485 Decode lottable06 (james01)         */  
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_LottableProcess_RCValidateLottable]  
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
  
   DECLARE @cReceiptKey NVARCHAR( 10)  
     
   SET @cReceiptKey = @cSourceKey  
     
   IF @cType = 'PRE'  
   BEGIN  
      SET @cLottable01 = ''  
      SET @cLottable02 = ''  
      SET @cLottable03 = ''  
      SET @dLottable04 = ''  
      SET @cLottable06 = ''  
      SET @cLottable07 = ''  
      SET @cLottable08 = ''  
      GOTO Quit  
   END  
     
   IF @cType = 'POST'  
   BEGIN  
      -- substring @cLottable06Value  --rmt    
      SET @cLottable06Value = SUBSTRING( @cLottable06Value, 3, 18)  
            
      -- Check blank  
      IF ISNULL(@cLottable06Value,'') = ''  
      BEGIN  
       SET @nErrNo = 164751  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lot06  
         GOTO Quit  
      END  
     
      IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
                      WHERE ReceiptKey = @cReceiptKey  
                      AND   Sku = @cSKU  
                      AND   Lottable06 = @cLottable06Value)  
      BEGIN  
       SET @nErrNo = 164752  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Data Not Found  
         GOTO Quit  
      END  
  
      IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
                  WHERE ReceiptKey = @cReceiptKey  
                  AND   Sku = @cSKU  
                  AND   Lottable06 = @cLottable06Value  
                  AND   QtyExpected<=BeforeReceivedQty)  
      BEGIN  
       SET @nErrNo = 164753  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --overreceive  
         GOTO Quit  
      END  
  
      SELECT @cLottable01 = Lottable01,  
               @cLottable02 = Lottable02,  
               @cLottable03 = Lottable03,  
               @dLottable04 = Lottable04,  
               @cLottable06 = Lottable06,  
               @cLottable07 = Lottable07,  
               @cLottable08 = Lottable08  
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
      WHERE ReceiptKey = @cReceiptKey  
      AND   Sku = @cSKU  
      AND   Lottable06 = @cLottable06Value  
   END  
    
Quit:  
     
END  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Store procedure: rdt_LottableProcess_DecodeL2toL15                   */        
/* Copyright      : LF                                                  */        
/*                                                                      */        
/* Purpose: decode lottable02 to lottable15 and lottable01              */        
/*                                                                      */        
/* Date        Rev  Author      Purposes                                */        
/* 17-11-2015  1.0  YeeKung     WMS-12309 Decode lot2 to lot15          */            
/************************************************************************/   

CREATE PROCEDURE [RDT].[rdt_LottableProcess_DecodeL2toL15]        
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

   DECLARE   
      @nBatchYear         NVARCHAR(1),  
      @nDaysInYear        NVARCHAR(3),
      @cYear              NVARCHAR(4), 
      @cJulianDate        NVARCHAR(20),
      @cFormatDate        DATETIME
   
   IF  @cLottable02Value = ''
   BEGIN
      SELECT TOP 1 @dlottable15=lottable15
      FROM lotattribute WITH (NOLOCK)
      WHERE storerkey=@cStorerKey
         AND SKU=@cSKU
         AND ISNULL(lottable15,'')<>''
      Order by lottable15

      SELECT TOP 1 @dLottable05=lottable05
      FROM lotattribute WITH (NOLOCK)
      WHERE storerkey=@cStorerKey
         AND SKU=@cSKU
         AND ISNULL(lottable05,'')<>''
      Order by lottable05

      SET @cLottable01 = rdt.rdtformatdate(@dlottable15)
   END
   ELSE
   BEGIN

      IF (LEN(@cLottable02Value)<>8)
      BEGIN
         SET @nErrNo = 149053
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidLot2
         GOTO FAIL
      END

      IF (ISNUMERIC(SUBSTRING(@cLottable02Value,3,4))=0)
      BEGIN
         SET @nErrNo = 149054
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidLot2
         GOTO FAIL
      END

      -- EG XX9312XX
      SELECT @nBatchYear = SUBSTRING(@cLottable02Value,3,1) -- 9
      SELECT @nDaysInYear = SUBSTRING (@cLottable02Value,4,3) --312

      /*************************************************/
      /* Set a first digit as a year                   */
      /* 9 as year 2019                                */
      /* 0 as year 2020                                */
      /*************************************************/

      SELECT @cYear= CASE @nBatchYear 
         WHEN '0' THEN '2020'
         WHEN '1' THEN '2021'
         WHEN '2' THEN '2022'
         WHEN '3' THEN '2023'
         WHEN '4' THEN '2024'
         WHEN '5' THEN '2025'  
         WHEN '6' THEN '2026'
         WHEN '7' THEN '2027'
         WHEN '8' THEN '2028'
         WHEN '9' THEN '2019'  
         END;

      -- EG 2019312
      SET @cJulianDate = @cYear + @nDaysInYear

      IF ((@cYear % 4 = 0 AND @cYear % 100 <> 0) OR @cYear % 400 = 0)
      BEGIN
         IF (CAST(@nDaysInYear AS INT) > 366 or CAST(@nDaysInYear AS INT) = 0)
         BEGIN 
            SET @nErrNo = 149051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidDay
            GOTO FAIL
         END
      END
      ELSE
      BEGIN
         IF (CAST(@nDaysInYear AS INT) > 365 or CAST(@nDaysInYear AS INT) = 0)
         BEGIN 
            SET @nErrNo = 149052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidDay
            GOTO FAIL
         END
      END


      --  EG 2019-11-08
      SET @cFormatDate = (dateadd(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, dateadd(yy, @cJulianDate/1000 - 1900, 0)) )

      SELECT TOP 1 
      @dLottable05 =Lottable05
      FROM lotattribute WITH (NOLOCK)
      WHERE storerkey=@cStorerKey
         AND SKU=@cSKU
         AND ISNULL(Lottable05,'')<>''
      Order by Lottable05

      SET @dlottable15 = @cFormatDate
      SET @cLottable01 = rdt.rdtformatdate(@cFormatDate)
      SET @cLottable02 = SUBSTRING(@cLottable02Value,3,4) --9312

   END
        
Fail:  
END    

GO
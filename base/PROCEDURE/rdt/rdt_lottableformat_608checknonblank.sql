SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_LottableFormat_608CheckNonBlank                      */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Check lottable received                                           */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 13-06-2022  yeekung   1.0   WMS-19959 Created                              */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_LottableFormat_608CheckNonBlank]    
   @nMobile          INT,      
   @nFunc            INT,      
   @cLangCode        NVARCHAR( 3),      
   @nInputKey        INT,      
   @cStorerKey       NVARCHAR( 15),      
   @cSKU             NVARCHAR( 20),      
   @cLottableCode    NVARCHAR( 30),       
   @nLottableNo      INT,      
   @cFormatSP        NVARCHAR( 50),       
   @cLottableValue   NVARCHAR( 60),       
   @cLottable        NVARCHAR( 60) OUTPUT,      
   @nErrNo           INT           OUTPUT,      
   @cErrMsg          NVARCHAR( 20) OUTPUT      
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   --INSERT INTO traceInfo (TraceName,timein,col1,col2)
   --   VALUES ('ccnikeph1841A',GETDATE(),@cLottableValue ,@cLottable)
  
   DECLARE @nExist INT = 0  
   DECLARE 
   	@cLottableVal01 NVARCHAR( 60),@cLottableVal06 NVARCHAR( 60),@cLottableVal11 NVARCHAR( 60),
   	@cLottableVal02 NVARCHAR( 60),@cLottableVal07 NVARCHAR( 60),@cLottableVal12 NVARCHAR( 60),
   	@cLottableVal03 NVARCHAR( 60),@cLottableVal08 NVARCHAR( 60),@dLottableVal13 DATETIME,
   	@dLottableVal04 DATETIME     ,@cLottableVal09 NVARCHAR( 60),@dLottableVal14 DATETIME,
   	@dLottableVal05 DATETIME     ,@cLottableVal10 NVARCHAR( 60),@dLottableVal15 DATETIME
     
   IF @nFunc = 608  
   BEGIN       
      -- Get lottable  
      IF @nLottableNo =  1 SELECT @cLottable = @cLottableValue, @cLottableVal01 = @cLottableValue ELSE   
      IF @nLottableNo =  2 SELECT @cLottable = @cLottableValue, @cLottableVal02 = @cLottableValue ELSE   
      IF @nLottableNo =  3 SELECT @cLottable = @cLottableValue, @cLottableVal03 = @cLottableValue ELSE
      IF @nLottableNo =  4 SELECT @cLottable = rdt.rdtFormatDate( @cLottableValue),@dLottableVal04 = rdt.rdtFormatDate( @cLottableValue) ELSE   
      IF @nLottableNo =  5 SELECT @cLottable = rdt.rdtFormatDate( @cLottableValue),@dLottableVal05 = rdt.rdtFormatDate( @cLottableValue) ELSE    
      IF @nLottableNo =  6 SELECT @cLottable = @cLottableValue, @cLottableVal06 = @cLottableValue ELSE
      IF @nLottableNo =  7 SELECT @cLottable = @cLottableValue, @cLottableVal07 = @cLottableValue ELSE
      IF @nLottableNo =  8 SELECT @cLottable = @cLottableValue, @cLottableVal08 = @cLottableValue ELSE
      IF @nLottableNo =  9 SELECT @cLottable = @cLottableValue, @cLottableVal09 = @cLottableValue ELSE
      IF @nLottableNo = 10 SELECT @cLottable = @cLottableValue, @cLottableVal10 = @cLottableValue ELSE
      IF @nLottableNo = 11 SELECT @cLottable = @cLottableValue, @cLottableVal11 = @cLottableValue ELSE  
      IF @nLottableNo = 12 SELECT @cLottable = @cLottableValue, @cLottableVal12 = @cLottableValue ELSE 
      IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @cLottableValue),@dLottableVal13 = rdt.rdtFormatDate( @cLottableValue) ELSE  
      IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @cLottableValue),@dLottableVal14 = rdt.rdtFormatDate( @cLottableValue) ELSE   
      IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @cLottableValue),@dLottableVal15 = rdt.rdtFormatDate( @cLottableValue)     
      
      -- Check blank  
      IF @cLottable = ''  
      BEGIN  
         SET @nErrNo = 187251   
         SET @cErrMsg = RTRIM( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')) + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2) --NeedLottable99  
         GOTO Quit  
      END  
  
      -- Check date  
      IF @nLottableNo IN (4, 5, 13, 14, 15) -- Date fields  
      BEGIN  
         -- Check valid date  
         IF @cLottable <> '' AND rdt.rdtIsValidDate( @cLottable) = 0  
         BEGIN  
            SET @nErrNo = 187252  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid date  
            GOTO Quit  
         END  
      END  
   END  
Quit:  
     
END


GO
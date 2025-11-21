SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
         
			
/************************************************************************/  
/* Store procedure: rdt_LottableFormat_PARIS                            */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-06-20 1.0  YeeKung    WMS-13456 Created                         */  
/* 2021-09-13 1.1  YeeKung    WMS 16535 - SG - PRESTIGE Batch Decoding 5*/
/* 2022-02-14 1.2  YeeKung    Fix quit After END								*/
/************************************************************************/  
  
             
CREATE PROCEDURE [RDT].[rdt_LottableFormat_PARIS](             
    @nMobile          INT                
   ,@nFunc            INT                
   ,@cLangCode        NVARCHAR( 3)                
   ,@nInputKey        INT                
   ,@cStorerKey       NVARCHAR( 15)                
   ,@cSKU             NVARCHAR( 20)  
   ,@cLottableCode    NVARCHAR( 30)  
   , @nLottableNo     INT            
   , @cFormatSP       NVARCHAR( 20)  
   , @cLottableValue  NVARCHAR( 20)  
   , @cLottable       NVARCHAR( 30)  OUTPUT    
   , @nErrNo           INT           OUTPUT                
   , @cErrMsg          NVARCHAR( 20) OUTPUT  
)                
AS                
BEGIN                
   SET NOCOUNT ON                
   SET QUOTED_IDENTIFIER OFF                
   SET ANSI_NULLS OFF                
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
   DECLARE @cYearCode NVARCHAR(20),
           @nYear INT,  
           @nDay INT,
           @cJulianDate NVARCHAR(20)  
  
   SET @cLottable= REPLACE(@cLottable,' ','')  

   
   IF ISNUMERIC(SUBSTRING(@cLottable,1,1))='0'
   BEGIN 
      SET @cLottable = SUBSTRING(@cLottable,2,LEN(@cLottable))

      IF ISNUMERIC(SUBSTRING(@cLottable,1,1))='0'
         SET @cLottable = SUBSTRING(@cLottable,2,LEN(@cLottable))
   END
  
   IF (LEN(@cLottable)NOT BETWEEN 5 AND 8)      
   BEGIN      
      SET @nErrNo = 154101              
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                  
      GOTO Quit        
   END 

   SET @cYearCode ='20'+(SUBSTRING(@cLottable,1,2))  
   SET @nYear = @cYearCode
   SET @nDay = (SUBSTRING(@cLottable,3,3))
   
             
   IF ((@nYear % 4 = 0 AND @nYear % 100 <> 0) OR @nYear % 400 = 0)          
   BEGIN          
      IF (@nDay > 366 or @nDay = 0)          
      BEGIN           
         SET @nErrNo = 58317          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidDay                 
         GOTO Quit          
      END          
   END          
   ELSE          
   BEGIN          
      IF (@nDay > 365 or @nDay = 0)          
      BEGIN           
         SET @nErrNo = 58318          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidDay                  
         GOTO Quit          
      END          
   END       
 
   SET @cJulianDate=@cYearCode+(SUBSTRING(@cLottable,3,3))  
   SET @cLottable = convert(varchar,(dateadd(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, dateadd(yy, @cJulianDate/1000 - 1900, 0)) ),103)      
   GOTO QUIT  

QUIT:  
END  
  

GO
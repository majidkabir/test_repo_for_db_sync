SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_LottableFormat_MFK                              */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-06-20 1.0  YeeKung    WMS-16535 Created                         */ 
/* 2022-02-14 1.1  YeeKung    Fix quit After END								*/
/************************************************************************/  
  
             
CREATE PROCEDURE [RDT].[rdt_LottableFormat_MFK](             
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
           @cJulianDate NVARCHAR(20),
           @nYear INT  
  
   SET @cLottable= REPLACE(@cLottable,' ','')  
  
   IF (LEN(@cLottable)<5)      
   BEGIN      
      SET @nErrNo = 174651              
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                  
      GOTO Quit        
   END    
   
   IF rdt.rdtIsValidQty(SUBSTRING(@cLottable,1,2),1)=0
   begin 
      SET @nErrNo = 174652              
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                  
      GOTO Quit       
   END

   SET @cYearCode ='20'+(SUBSTRING(@cLottable,1,2))  
   SET @cJulianDate=@cYearCode+(SUBSTRING(@cLottable,3,3))   

   SET @nYear = CAST (@cYearCode AS INT)
   
   IF ((@nYear % 4 = 0 AND @nYear % 100 <> 0) OR @nYear % 400 = 0)          
   BEGIN          
      IF (CAST(SUBSTRING(@cLottable,3,3) AS INT) > 366 or CAST(SUBSTRING(@cLottable,3,3) AS INT) = 0)          
      BEGIN           
         SET @nErrNo = 174653          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidDay                  
         GOTO Quit          
      END          
   END          
   ELSE          
   BEGIN          
      IF (CAST(SUBSTRING(@cLottable,3,3) AS INT) > 365 or CAST(SUBSTRING(@cLottable,3,3) AS INT) = 0)          
      BEGIN           
         SET @nErrNo = 174654          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidDay                
         GOTO Quit     
      END          
   END        

   SET @cLottable = convert(varchar,(dateadd(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, dateadd(yy, @cJulianDate/1000 - 1900, 0)) ),103)      
   GOTO QUIT  
  
QUIT:
END  

GO
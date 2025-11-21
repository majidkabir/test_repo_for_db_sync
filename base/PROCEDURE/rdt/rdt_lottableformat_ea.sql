SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_LottableFormat_EA                               */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-07-21 1.0  YeeKung    WMS-16535 Created                         */ 
/* 2022-02-14 1.1  YeeKung    Fix quit After END								*/
/************************************************************************/  
  
             
CREATE PROCEDURE [RDT].[rdt_LottableFormat_EA](             
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
           @cJulianDate NVARCHAR(20)  
  
   SET @cLottable= REPLACE(@cLottable,' ','')  
  
   IF (LEN(@cLottable) NOT BETWEEN 3 and 7)      
   BEGIN      
      SET @nErrNo = 174851              
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                  
      GOTO Quit        
   END    

   DECLARE @nMonth NVARCHAR(2)
   DECLARE @nDay NVARCHAR(2)
   
   IF (LEN(@cLottable) IN (3,4)) OR (LEN(@cLottable) =5 AND (ISNUMERIC(SUBSTRING(@cLottable,2,1))=0))
   BEGIN
      SELECT @cYearCode=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='John VarvatosAY'
      AND code2 =SUBSTRING(@cLottable,1,1)

      SELECT @nMonth=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='John VarvatosAM'
      AND code2 =SUBSTRING(@cLottable,2,1)

      SET @cLottable='01'+'/'+@nMonth+'/'+@cYearCode
   END
   ELSE IF ( LEN(@cLottable) =5 AND (ISNUMERIC(SUBSTRING(@cLottable,2,1))=1))
   BEGIN
      SELECT @cYearCode=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='John VarvatosBY'
      AND code2 =SUBSTRING(@cLottable,2,1)

      SELECT @nMonth=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='John VarvatosBM'
      AND code2 =SUBSTRING(@cLottable,3,1)

      SET @cLottable='01'+'/'+@nMonth+'/'+@cYearCode
   END

   ELSE IF LEN(@cLottable) ='7'
   BEGIN
      SELECT @cYearCode=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='John VarvatosCY'
      AND code2 =SUBSTRING(@cLottable,2,2)

      SELECT @nMonth=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='John VarvatosCM'
      AND code2 =SUBSTRING(@cLottable,4,1)

      SELECT @nDay=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='John VarvatosCD'
      AND code2 =SUBSTRING(@cLottable,5,2)

      SET @cLottable=@nDay+'/'+@nMonth+'/'+@cYearCode

   END
   
 
   GOTO QUIT  
  
QUIT:
END  

GO
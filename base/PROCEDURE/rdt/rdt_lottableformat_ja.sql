SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_LottableFormat_JA                               */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-06-20 1.0  YeeKung    WMS-16535 Created                         */ 
/* 2022-02-14 1.1  YeeKung    Fix quit After END								*/
/************************************************************************/  
       
CREATE PROCEDURE [RDT].[rdt_LottableFormat_JA](             
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
   SET @cLottable= REPLACE(@cLottable,'/','')  
   SET @cLottable= REPLACE(@cLottable,'-','')  
  
   IF (LEN(@cLottable)<>4)      
   BEGIN      
      SET @nErrNo = 174901              
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                  
      GOTO Quit        
   END    

   DECLARE @nMonth NVARCHAR(2)
   
   IF (ISNUMERIC(SUBSTRING(@cLottable,1,1))=1)
   BEGIN
      SELECT @nMonth=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='JEANNE ARTHESBM'
      AND code2 =SUBSTRING(@cLottable,1,2 )

      SELECT @cYearCode=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='JEANNE ARTHESBY'
      AND code2 =SUBSTRING(@cLottable,3,2)

      SET @cLottable='01'+'/'+@nMonth+'/'+@cYearCode

   END

   ELSE IF (ISNUMERIC(SUBSTRING(@cLottable,1,1))=0)
   BEGIN
      SELECT @cYearCode=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='JEANNE ARTHESA'
      AND code2 =SUBSTRING(@cLottable,1,1)

      SET @nMonth=MONTH(GETDATE())

      SET @nMonth = CASE WHEN len(@nMonth)=1 THEN '0'+@nMonth ELSE @nMonth END   

      SET @cLottable='01'+'/'+@nMonth+'/'+@cYearCode

  
      SET @cLottable=convert(varchar,DATEADD( month, -3, rdt.rdtformatdate(@cLottable)),103) 
        
   END
   
 
   GOTO QUIT  
  
QUIT:
END 

GO
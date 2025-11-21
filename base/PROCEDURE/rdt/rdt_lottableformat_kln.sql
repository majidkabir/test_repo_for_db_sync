SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
           
/************************************************************************/  
/* Store procedure: rdt_LottableFormat_KLN                              */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-06-20 1.0  YeeKung    WMS-16535 Created                         */ 
/* 2022-02-14 1.1  YeeKung    Fix quit After END								*/
/************************************************************************/  
  
             
CREATE PROCEDURE [RDT].[rdt_LottableFormat_KLN](             
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
  
   SET @cLottable = REPLACE(@cLottable,' ','') 
   
   SET @cLottable = REPLACE(@cLottable,'/','')  
   SET @cLottable = REPLACE(@cLottable,'-','')  
  
   IF (LEN(@cLottable)NOT BETWEEN 3 AND 8)      
   BEGIN      
      SET @nErrNo = 174951              
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                  
      GOTO Quit        
   END    

   DECLARE @nMonth NVARCHAR(2), @nyear INT
      
   IF(LEN(@cLottable) BETWEEN  3 AND 7) OR (LEN(@cLottable)=8 AND (ISNUMERIC(SUBSTRING(@cLottable,4,1))=1))
   BEGIN
      SELECT @nMonth=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='KILIANAM'
      AND code2 =SUBSTRING(@cLottable,2,1)

      SELECT @nyear=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='KILIANAY'
      AND code2 =SUBSTRING(@cLottable,3,1)

      SET @cLottable='01'+'/'+CAST(@nMonth AS NVARCHAR(2))+'/'+CAST(@nyear AS NVARCHAR)

   END

   ELSE IF ISNUMERIC(SUBSTRING(@cLottable,4,1))=0
   BEGIN
      SELECT @nMonth=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='KILIANBM'
      AND code2 =SUBSTRING(@cLottable,4,1)

      SELECT @nyear=short
      FROM codelkup (NOLOCK) 
      WHERE listname='RDTDecode'
      AND code='KILIANBY'
      AND code2 =SUBSTRING(@cLottable,5,1)

      SET @cLottable='01'+'/'+CAST(@nMonth AS NVARCHAR(2))+'/'+CAST(@nyear AS NVARCHAR)
   END
 
 
   GOTO QUIT  
  
  
QUIT:
END 

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_LottableFormat_CREED                           */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-06-20 1.0  YeeKung    WMS-16535 Created                         */    
/* 2022-02-14 1.1  YeeKung    Fix quit After END								*/
/************************************************************************/  
         
CREATE PROCEDURE [RDT].[rdt_LottableFormat_CREED](             
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
           @cJulianDate NVARCHAR(20) ,
           @cMonth NVARCHAR(2) 
  
   SET @cLottable= REPLACE(@cLottable,' ','')  
  
   IF (LEN(@cLottable) NOT IN (8,9))      
   BEGIN      
      SET @nErrNo = 174801              
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                  
      GOTO Quit        
   END    

   DECLARE @nyear INT, @cMonthCode nvarchar(5), @cYear int
   
   IF LEN(@cLottable) ='8' OR ( LEN(@cLottable) ='9' AND  (ISNUMERIC(SUBSTRING(@cLottable,2,1))=1) AND (ISNUMERIC(SUBSTRING(@cLottable,6,1))=0))
   BEGIN 
     
      SET @cYearCode = SUBSTRING( @cLottable, 4, 2)                
      SET @cMonthCode = SUBSTRING( @cLottable, 6, 1)       
      SET @cYear = '20'+ @cYearCode               
    
      IF EXISTS (SELECT 1 FROM CodeLKUP WITH (NOLOCK)                
                  WHERE ListName = 'RDTDecode'                
                     AND Code = 'CREEDE'                
                     AND Code2 = @cMonthCode                
                     AND StorerKey = @cStorerKey) AND (@cYear%2=0)       
      BEGIN      
         SELECT  @cMonth = LEFT( Short, 2)       
         FROM CodeLKUP WITH (NOLOCK)                
         WHERE ListName = 'RDTDecode'                
            AND Code = 'CREEDE'                
            AND Code2 = @cMonthCode                
            AND StorerKey = @cStorerKey      
      END       
      ELSE IF EXISTS (SELECT 1 FROM CodeLKUP WITH (NOLOCK)                
            WHERE ListName = 'RDTDecode'                
               AND Code = 'CREEDO'                
               AND Code2 = @cMonthCode                
               AND StorerKey = @cStorerKey) AND (@cYear%2<>0)    
      BEGIN      
         SELECT  @cMonth = LEFT( Short, 2)       
         FROM CodeLKUP WITH (NOLOCK)                
         WHERE ListName = 'RDTDecode'                
            AND Code = 'CREEDO'                
            AND Code2 = @cMonthCode                
            AND StorerKey = @cStorerKey      
      END       
      ELSE      
      BEGIN      
         SET @nErrNo = 174803              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                 
         GOTO Quit        
      END      
      
      -- Generate expiry date                
      SET @cLottable = '01/' + @cMonth + '/' + CAST(@cYear  AS NVARCHAR(4))


   END

   ELSE IF ( LEN(@cLottable) ='9' AND (ISNUMERIC(SUBSTRING(@cLottable,2,1))=0))
   BEGIN
      SET @cYearCode = SUBSTRING( @cLottable, 5, 2)                
      SET @cMonthCode = SUBSTRING( @cLottable, 7, 1)       
      SET @cYear = '20'+ @cYearCode    

      IF EXISTS (SELECT 1 FROM CodeLKUP WITH (NOLOCK)                
            WHERE ListName = 'RDTDecode'                
               AND Code = 'CREEDE'                
               AND Code2 = @cMonthCode                
               AND StorerKey = @cStorerKey) AND (@cYear%2=0)       
      BEGIN      
         SELECT  @cMonth = LEFT( Short, 2)       
         FROM CodeLKUP WITH (NOLOCK)                
         WHERE ListName = 'RDTDecode'                
            AND Code = 'CREEDE'                
            AND Code2 = @cMonthCode                
            AND StorerKey = @cStorerKey      
      END       
      ELSE IF EXISTS (SELECT 1 FROM CodeLKUP WITH (NOLOCK)                
            WHERE ListName = 'RDTDecode'                
               AND Code = 'CREEDO'                
               AND Code2 = @cMonthCode                
               AND StorerKey = @cStorerKey) AND (@cYear%2<>0)    
      BEGIN      
         SELECT  @cMonth = LEFT( Short, 2)       
         FROM CodeLKUP WITH (NOLOCK)                
         WHERE ListName = 'RDTDecode'                
            AND Code = 'CREEDO'                
            AND Code2 = @cMonthCode                
            AND StorerKey = @cStorerKey      
      END       
      ELSE      
      BEGIN      
         SET @nErrNo = 174802              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                
         GOTO Quit        
      END      
      
      -- Generate expiry date                
      SET @cLottable = '01/' + @cMonth + '/' + CAST(@cYear  AS NVARCHAR(4))  
   END

   ELSE IF ( LEN(@cLottable) ='9' AND (ISNUMERIC(SUBSTRING(@cLottable,2,1))=1) AND (ISNUMERIC(SUBSTRING(@cLottable,6,1))=1))
   BEGIN
      SET @cYearCode = SUBSTRING( @cLottable, 7, 2)                
      SET @cMonthCode = SUBSTRING( @cLottable, 9, 1)       
      SET @cYear = '20'+ @cYearCode    

      IF EXISTS (SELECT 1 FROM CodeLKUP WITH (NOLOCK)                
            WHERE ListName = 'RDTDecode'                
               AND Code = 'CREEDE'                
               AND Code2 = @cMonthCode                
               AND StorerKey = @cStorerKey) AND (@cYear%2=0)       
      BEGIN      
         SELECT  @cMonth = LEFT( Short, 2)       
         FROM CodeLKUP WITH (NOLOCK)                
         WHERE ListName = 'RDTDecode'                
            AND Code = 'CREEDE'                
            AND Code2 = @cMonthCode                
            AND StorerKey = @cStorerKey      
      END       
      ELSE IF EXISTS (SELECT 1 FROM CodeLKUP WITH (NOLOCK)                
            WHERE ListName = 'RDTDecode'                
               AND Code = 'CREEDO'                
               AND Code2 = @cMonthCode                
               AND StorerKey = @cStorerKey) AND (@cYear%2<>0)    
      BEGIN      
         SELECT  @cMonth = LEFT( Short, 2)       
         FROM CodeLKUP WITH (NOLOCK)                
         WHERE ListName = 'RDTDecode'                
            AND Code = 'CREEDO'                
            AND Code2 = @cMonthCode                
            AND StorerKey = @cStorerKey      
      END       
      ELSE      
      BEGIN      
         SET @nErrNo = 174804              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                
         GOTO Quit        
      END      
      
      -- Generate expiry date                
      SET @cLottable = '01/' + @cMonth + '/' + CAST(@cYear  AS NVARCHAR(4))  
   END
 
   GOTO QUIT  
  
QUIT:
END 

GO
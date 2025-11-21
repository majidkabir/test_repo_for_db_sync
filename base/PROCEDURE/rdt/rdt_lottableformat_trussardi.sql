SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
         
/************************************************************************/
/* Store procedure: rdt_LottableFormat_TRUSSARDI                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-06-20 1.0  YeeKung    WMS-13456 Created                         */
/* 2022-02-14 1.1  YeeKung    Fix quit After END								*/
/************************************************************************/

           
CREATE PROCEDURE [RDT].[rdt_LottableFormat_TRUSSARDI](           
     @nMobile          INT              
   , @nFunc            INT              
   , @cLangCode        NVARCHAR( 3)              
   , @nInputKey        INT              
   , @cStorerKey       NVARCHAR( 15)              
   , @cSKU             NVARCHAR( 20)
   , @cLottableCode    NVARCHAR( 30)
   , @nLottableNo      INT          
   , @cFormatSP        NVARCHAR( 20)
   , @cLottableValue   NVARCHAR( 20)
   , @cLottable        NVARCHAR( 30)  OUTPUT  
   , @nErrNo           INT           OUTPUT              
   , @cErrMsg          NVARCHAR( 20) OUTPUT
)              
AS              
BEGIN              
   SET NOCOUNT ON              
   SET QUOTED_IDENTIFIER OFF              
   SET ANSI_NULLS OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @cYearCode NVARCHAR(5),
           @cDayCode  NVARCHAR(5),
           @cMonthCode NVARCHAR(5),
           @cJulianDate NVARCHAR(20),
           @nYear       INT


   IF (LEN(@cLottable)NOT BETWEEN 7 AND 8)    
   BEGIN    
      SET @nErrNo = 154451            
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                
      GOTO Quit      
   END  

   SET @cDayCode =(SUBSTRING(@cLottable,1,1)) +(SUBSTRING(@cLottable,5,1)) 
   SET @cMonthCode =(SUBSTRING(@cLottable,2,1)) +(SUBSTRING(@cLottable,4,1))
   SET @cYearCode=(SUBSTRING(@cLottable,3,1))

   SELECT @nYear=short
   FROM codelkup (NOLOCK)
   WHERE LISTNAME='RDTDECODE'
      AND code = 'TRUSSARDIY'
      AND code2=@cYearCode

   IF ISNULL(@nYear,'')=''
   BEGIN    
      SET @nErrNo = 154452            
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                
      GOTO Quit      
   END  


   SET @cLottable = @cDayCode+'/'+@cMonthCode+'/'+CAST(@nYear AS nvarchar(4))
   GOTO QUIT

QUIT:
END

GO
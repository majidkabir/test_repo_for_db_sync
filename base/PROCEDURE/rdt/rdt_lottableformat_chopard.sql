SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
         
/************************************************************************/
/* Store procedure: rdt_LottableFormat_CHOPARD                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-06-20 1.0  YeeKung    WMS-13456 Created                         */
/* 2022-02-14 1.1  YeeKung    Fix quit After END								*/
/************************************************************************/

           
CREATE PROCEDURE [RDT].[rdt_LottableFormat_CHOPARD](           
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
           @cDayMonthCode NVARCHAR(10),
           @cMonthCode NVARCHAR(5),
           @cJulianDate NVARCHAR(20),
           @nYear       INT,
           @cDayMonth NVARCHAR(10)



   IF (LEN(@cLottable)NOT IN (4,7,8))    
   BEGIN    
      SET @nErrNo = 154401            
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                
      GOTO Quit      
   END  

   IF (LEN(@cLottable)=4)
   BEGIN
      SET @cDayMonthCode=SUBSTRING(@cLottable,1,2)

      SELECT @cDayMonth=(UDF01+'/'+UDF02)
      FROM codelkup (NOLOCK)
      WHERE  LISTNAME='RDTDECODE'
         AND code = 'PFCHDM'
         AND code2=@cDayMonthCode
      
      IF ISNULL(@cDayMonth,'')=''
      BEGIN    
         SET @nErrNo = 154402            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                
         GOTO Quit      
      END 
      
      SET @cYearCode=(SUBSTRING(@cLottable,3,4))   

      SET @cLottable=@cDayMonth+'/'+'20'+@cYearCode

      GOTO QUIT
   END

   ELSE IF (LEN(@cLottable)=7)
   BEGIN
      SET @cYearCode=(SUBSTRING(@cLottable,1,2))  
      
      IF  SUBSTRING(@cLottable,3,3)>366 OR SUBSTRING(@cLottable,3,3)=0
      BEGIN    
         SET @nErrNo = 154404            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                
         GOTO Quit      
      END 

      SET @cJulianDate='20'+@cYearCode+(SUBSTRING(@cLottable,3,3))
      SET @cLottable = convert(varchar,(dateadd(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, dateadd(yy, @cJulianDate/1000 - 1900, 0)) ),103)       

      GOTO QUIT
   END

   IF (LEN(@cLottable)=8)
   BEGIN
      SET @cDayCode=(SUBSTRING(@cLottable,1,1)) + (SUBSTRING(@cLottable,5,1))  
      SET @cMonthCode=(SUBSTRING(@cLottable,2,1)) + (SUBSTRING(@cLottable,4,1)) 
      SET @cYearCode=(SUBSTRING(@cLottable,3,1)) 

      SELECT @nYear=SHORT
      FROM codelkup (NOLOCK)
      WHERE  LISTNAME='RDTDECODE'
         AND code = 'PFCH'
         AND code2=@cYearCode

      IF ISNULL(@nYear,'')='' OR @nYear=0
      BEGIN    
         SET @nErrNo = 154403            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch                                
         GOTO Quit      
      END 

      SET @cLottable = @cDayCode+'/'+@cMonthCode+'/'+CAST(@nYear AS NVARCHAR(10))

      GOTO QUIT
   END

   GOTO QUIT

QUIT:

END


GO
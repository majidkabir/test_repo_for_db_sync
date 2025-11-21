SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_GenLot04_EAT01                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 29-11-2015   ChewKP    1.0   WMS-3551 Created                              */
/* 25-03-2020   James     1.1   WMS-12614 Change lot03, 04 retrival (james01) */
/* 14-04-2022   YeeKung   1.2   WMS-19436 Add new Change (yeekung01)          */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_GenLot04_EAT01]
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nShelfLife           INT
   DECLARE @cProductYear         NVARCHAR(1) 
          ,@cCurrentYear         NVARCHAR(3) 
          ,@cManufactureYear     NVARCHAR(4) 
          ,@nProductYearPosition INT
          ,@cMonthAlpha          NVARCHAR(1) 
          ,@cManufactureMonth    NVARCHAR(2) 
          ,@cManufactureDate     NVARCHAR(10) 
          ,@dComputeDate         DATETIME
          ,@cFinalDate           NVARCHAR(10) 
          ,@dComputeDate2        DATETIME
          ,@nExpiryYear          INT
          ,@nExpiryMonth         INT
          ,@cPATIndex1           NVARCHAR(10) 
          ,@nPATIndex2           INT
         
          
   --PRINT @cLottable03Value
   -- Check empty
   IF ISNULL(@cLottable02Value,'' ) <> '' 
   BEGIN
      IF LEN( @cLottable02Value) < 7
      BEGIN
         SET @cPATIndex1 =  SUBSTRING(@cLottable02Value, PATINDEX('%[0-9]%', @cLottable02Value), LEN(@cLottable02Value))
         SET @nPATIndex2 = PATINDEX('%[^0-9]%', @cPATIndex1)
      
         IF @nPATIndex2 = 0 
         BEGIN
            SET @dLottable04 = NULL
            GOTO QUIT
         END

         SELECT @cProductYear = LEFT(S, PATINDEX('%[^0-9]%', S) - 1)
         FROM (SELECT SUBSTRING(@cLottable02Value, PATINDEX('%[0-9]%', @cLottable02Value), LEN(@cLottable02Value)) AS S) T 
      
         SET @cCurrentYear = LEFT (Year(GetDate()) , 3 ) 
      
         SET @cManufactureYear = @cCurrentYear + @cProductYear
      
         SET @nProductYearPosition = CHARINDEX(@cProductYear, @cLottable02Value ) 
      
         SET @cMonthAlpha = SUBSTRING ( @cLottable02Value, @nProductYearPosition + 1 , 1 ) 

         SELECT @cManufactureMonth = Short
         FROM dbo.Codelkup WITH (NOLOCK) 
         WHERE ListName = 'EATLOT4'
         AND StorerKey = @cStorerKey 
         AND Code = @cMonthAlpha
      
         SET @cManufactureDate = @cManufactureYear + '/' + @cManufactureMonth + '/01'
         SET @cLottable03 = @cManufactureDate
      END
      ELSE
      BEGIN
         DECLARE @nY1      INT
         DECLARE @nY2      INT
         DECLARE @cM1      NVARCHAR( 1)
         DECLARE @cM2      NVARCHAR( 2) = ''
         DECLARE @cYY      NVARCHAR( 4)

         IF RDT.rdtIsValidQTY( SUBSTRING( @cLottable02Value, 2, 2), 1) <> 1    
         BEGIN      
            SET @nErrNo = 150152      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format      
            GOTO Quit      
         END      

         SET @nY1 = LEFT ( YEAR( GETDATE()), 2 )

         IF LEN( @cLottable02Value) >= 7
            SET @nY2 = SUBSTRING( @cLottable02Value, 2, 2)

         SET @cYY = CAST( @nY1 AS NVARCHAR( 2)) + CAST( @nY2 AS NVARCHAR( 2))

         IF LEN( @cLottable02Value) >= 7
            SET @cM1 = SUBSTRING( @cLottable02Value, 4, 1)
      
         --IF LEN( @cLottable02Value) = 8
         --   SET @cM1 = SUBSTRING( @cLottable02Value, 5, 1)

         IF RDT.rdtIsValidQTY( @cM1, 1) = 1
            SET @cM2 = '0' + @cM1
      
         IF @cM1 = 'X'
            SET @cM2 = '10'

         IF @cM1 = 'Y'
            SET @cM2 = '11'

         IF @cM1 = 'Z'
            SET @cM2 = '12'

         IF @cM2 = ''
         BEGIN
            SET @nErrNo = 150151
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Month
            SET @dLottable04 = CONVERT( NVARCHAR(10), '1911/01/01', 112)
            GOTO Quit
         END
      
         SET @cManufactureDate = @cYY + '/' + @cM2 + '/01'
         SET @cLottable03 = @cManufactureDate
      END

      IF rdt.rdtIsValidDate(@cManufactureDate) = 0    
      BEGIN      
         SET @nErrNo = 155056      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format      
         GOTO Quit      
      END 

      -- Get Shelf life info
      SELECT @nShelfLife = ShelfLife
      FROM SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
        AND SKU = @cSKU
      
      SET @nExpiryYear = Floor(@nShelfLife/365)  
      SET @nExpiryMonth = Floor((@nShelfLife%365)/30)
      
      IF @nShelfLife > 0 
      BEGIN
         SET @dComputeDate= DATEADD( year, @nExpiryYear, @cManufactureDate)
         SET @dComputeDate2 = DATEADD( month, @nExpiryMonth, @dComputeDate)
         SET @cFinalDate   = CAST(Year(@dComputeDate2) AS NVARCHAR(4))  + '-' + CAST(Month(@dComputeDate2) AS NVARCHAR(2))  + '-' + '01' 
         SET @dLottable04 = CONVERT( NVARCHAR(10), @cFinalDate, 112)
      END
      ELSE
      BEGIN
         SET @dLottable04 = NULL
      END

         --delete from traceinfo where tracename = '598'
         --insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5, step1, Step2) 
         --values ('598', getdate(), @nY1, @nY2, @cM1, @cM2, @cLottable02Value, @cLottable03, @dLottable04)
         
      --SELECT @cManufactureYear '@cManufactureYear' , @cManufactureMonth '@cManufactureMonth' , @cMonthAlpha '@cMonthAlpha' , @cLottable02Value '@cLottable02Value' , @cLottable02 '@cLottable02' , @cManufactureDate '@cManufactureDate' , @dLottable04 '@dLottable04' 
      
   END

Quit:

END

GO
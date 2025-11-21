SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

          
/************************************************************************/          
/* Store procedure: rdt_LottableProcess_PNGGenL3L4ByL2                  */          
/* Copyright      : LF                                                  */          
/*                                                                      */          
/* Purpose: Generate Lottable03 & 04 by decoding Lottable02 (batch code)*/          
/*                                                                      */          
/* Date        Rev  Author      Purposes                                */          
/* 2021-08-13  1.0  James       WMS-17692 Created                       */  
/************************************************************************/          
          
CREATE PROCEDURE [RDT].[rdt_LottableProcess_PNGGenL3L4ByL2]          
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
   SET ANSI_NULLS OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF          

   DECLARE @nShelflife  INT
   DECLARE @cTempYear   NVARCHAR( 1) 
   DECLARE @cTempDay    NVARCHAR( 3) 
   DECLARE @cDay        NVARCHAR( 2) 
   DECLARE @cMonth      NVARCHAR( 2)
   DECLARE @cYear       NVARCHAR( 4)
   
   IF @cLottable02Value <> ''
   BEGIN
      SET @cTempYear = SUBSTRING( @cLottable02Value, 1, 1)
      SET @cTempDay = SUBSTRING( @cLottable02Value, 2, 3)
      SET @cYear = SUBSTRING( CONVERT( NVARCHAR( 10), GETDATE(), 112), 1, 3) + @cTempYear
      SET @cMonth = SUBSTRING( CONVERT( NVARCHAR( 10), DATEADD( DAY, @cTempDay - 1, 0), 112), 5, 2)
      SET @cDay = SUBSTRING( CONVERT( NVARCHAR( 10), DATEADD( DAY, @cTempDay - 1, 0), 112), 7, 2)

      IF CAST( @cYear AS INT) > CAST( SUBSTRING( CONVERT( NVARCHAR( 10), GETDATE(), 112), 1, 4) AS INT)
         SET @cYear = CAST( @cYear AS INT) - 10
         
      SET @cLottable03 = @cMonth + '/' + @cDay + '/' + @cYear
      --SELECT @cLottable03 '@cLottable03'

      SELECT @nShelflife = ShelfLife
      FROM dbo.SKU WITH (NOLOCK)
      WHERE SKU = @cSKU
      AND   StorerKey = @cStorerKey
      --SELECT @cLottable03 '@cLottable03', @nShelflife '@nShelflife'
      SET @dLottable04 = DATEADD ( DAY, @nShelflife, @cLottable03)
   END
END -- End Procedure 

GO
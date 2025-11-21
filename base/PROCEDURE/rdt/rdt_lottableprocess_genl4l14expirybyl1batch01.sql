SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_GenL4L14ExpiryByL1Batch01             */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Generate expiry date base on code                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 17-11-2015  Ung       1.0   SOS356691 Created                              */
/* 09-09-2017  Ung       1.1   WMS-2963 New decode logic                      */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_GenL4L14ExpiryByL1Batch01]
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

   DECLARE @cClass      NVARCHAR(10)
   DECLARE @cItemClass  NVARCHAR(10)
   DECLARE @nShelfLife  INT
   DECLARE @dLottable   DATETIME
   DECLARE @cFormatSP   NVARCHAR(50)
   DECLARE @cLottableValue NVARCHAR(60)
   
   DECLARE @cUDF01      NVARCHAR(60)
   DECLARE @cUDF02      NVARCHAR(60)
   DECLARE @cUDF03      NVARCHAR(60)
   DECLARE @cUDF04      NVARCHAR(60)
   DECLARE @cUDF05      NVARCHAR(60)
   
   -- Get SKU info
   SELECT 
      @cClass = Class, 
      @cItemClass = ItemClass, 
      @nShelfLife = ShelfLife
   FROM SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND SKU = @cSKU
   
   -- Get decode method
   SELECT 
      @cUDF01 = UDF01, 
      @cUDF02 = UDF02, 
      @cUDF03 = UDF03, 
      @cUDF04 = UDF04, 
      @cUDF05 = UDF05  
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = @cClass
      AND Code2 = @cItemClass
      AND StorerKey = @cStorerKey

   -- Initial value
   SET @cLottableValue = @cLottable
   SET @cLottable = ''

   -- Decode Roman 
   IF @cLottable = '' AND 'Roman' IN (@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05)
   BEGIN
      EXEC rdt.rdt_LottableFormat_Roman @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, @cLottableValue, 
         @cLottable  OUTPUT, 
         @nErrNo     OUTPUT, 
         @cErrMsg    OUTPUT
   END
   
   -- Decode Julian 
   IF @cLottable = '' AND 'Julian' IN (@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05)
   BEGIN
      EXEC rdt.rdt_LottableFormat_Julian @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, @cLottableValue, 
         @cLottable  OUTPUT, 
         @nErrNo     OUTPUT, 
         @cErrMsg    OUTPUT
   END

   -- Decode Type B 
   IF @cLottable = '' AND 'TypeB' IN (@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05)
   BEGIN
      EXEC rdt.rdt_LottableFormat_TypeB @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, @cLottableValue,
         @cLottable  OUTPUT, 
         @nErrNo     OUTPUT, 
         @cErrMsg    OUTPUT
   END

   -- Decode Type A 
   IF @cLottable = '' AND 'TypeA' IN (@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05)
   BEGIN
      EXEC rdt.rdt_LottableFormat_TypeA @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, @cLottableValue,
         @cLottable  OUTPUT, 
         @nErrNo     OUTPUT, 
         @cErrMsg    OUTPUT
   END

   -- Decode NARS
   IF @cLottable = '' AND 'NARS' IN (@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05)
   BEGIN
      EXEC rdt.rdt_LottableFormat_NARS @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, @cLottableValue,
         @cLottable  OUTPUT, 
         @nErrNo     OUTPUT, 
         @cErrMsg    OUTPUT
   END

   -- Decode France
   IF @cLottable = '' AND 'France' IN (@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05)
   BEGIN
      EXEC rdt.rdt_LottableFormat_France @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, @cLottableValue,
         @cLottable  OUTPUT, 
         @nErrNo     OUTPUT, 
         @cErrMsg    OUTPUT
   END

   -- Decode ZOTOS
   IF @cLottable = '' AND 'ZOTOS' IN (@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05)
   BEGIN
      EXEC rdt.rdt_LottableFormat_ZOTOS @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, @cLottableValue,
         @cLottable  OUTPUT, 
         @nErrNo     OUTPUT, 
         @cErrMsg    OUTPUT
   END

   -- Convert to date
   IF @cLottable = '' 
      SET @dLottable14 = CONVERT( DATETIME, CONVERT( NVARCHAR(10), GETDATE(), 103), 103) --DD/MM/YYYY
   ELSE 
      SET @dLottable14 = CONVERT( DATETIME, @cLottable, 103) --DD/MM/YYYY

   -- Set expiry date
   SET @dLottable04 = @dLottable14
   
   -- Add shelf life
   IF @nShelfLife > 0
      SET @dLottable04 = DATEADD( dd, @nShelfLife, @dLottable14)

END

GO
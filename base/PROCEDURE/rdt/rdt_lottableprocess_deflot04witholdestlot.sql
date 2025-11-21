SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************************************/
/* Store procedure: rdt_LottableProcess_DefLot04WithOldestLot                                          */
/* Copyright      : LF Logistics                                                                       */
/*                                                                                                     */
/* Purpose: Default lottable04 with date from oldest lot                                               */
/*                                                                                                     */
/* Date         Author    Ver.  Purposes                                                               */
/* 2020-10-15   Chermaine 1.0   WMS-15454. Created                                                     */
/*******************************************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_DefLot04WithOldestLot]
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
   
   DECLARE @nShelfLife INT

      --Get the oldest LOT with QTY  
      SELECT @dLottable04 = MIN( LA.Lottable04)  
      FROM dbo.LOTATTRIBUTE LA WITH (NOLOCK)  
      JOIN dbo.LOTXLOCXID LLI WITH (NOLOCK)   
         ON LA.Lot = LLI.Lot AND LA.Storerkey = LLI.Storerkey AND LA.Sku = LLI.Sku  
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.Loc = LOC.Loc  
      WHERE LA.StorerKey = @cStorerKey  
      AND   LA.Sku = @cSKU  
      AND   LLI.Qty > 0  
      
      SELECT @nShelfLife = ShelfLife FROM dbo.SKU with (NOLOCK) WHERE StorerKey = @cStorerKey AND sku = @cSKU
 
      --If such LOT not exist, return today date  
      IF ISNULL(@dLottable04,'') = ''  
      BEGIN
      	SET @dLottable05 = CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 112))   
         SET @dLottable04 = CONVERT(DATETIME, CONVERT(CHAR(20), DATEADD(dd,@nShelfLife,@dLottable05), 112))  
         --INSERT INTO traceInfo (tracename,col1,col2,col3)
         --VALUES ('cc60804-1',@dLottable05,@dLottable04,@nShelfLife)
      END
      ELSE
      BEGIN
      	-- Minus 1 day to not get the same receive day from previous receipt ( for sku with stock only)  
         -- If 2 receipt date same then allocation might not allocate from return stock  
         SET @dLottable05 = CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 112))  
         SET @dLottable04 = CONVERT(DATETIME, CONVERT(CHAR(20), @dLottable04, 112))  
         --INSERT INTO traceInfo (tracename,col1,col2,Col3)
         --VALUES ('cc60804-2',@dLottable05,@dLottable04,@nShelfLife)
      END
         
Fail:

END

GO
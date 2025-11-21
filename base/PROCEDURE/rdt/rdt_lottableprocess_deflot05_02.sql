SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************************************/
/* Store procedure: rdt_LottableProcess_DefLot05_02                                                    */
/* Copyright      : LF Logistics                                                                       */
/*                                                                                                     */
/* Purpose:                                                                                            */
/*                                                                                                     */
/* Date         Author    Ver.  Purposes                                                               */
/* 03-Jul-2017  ChewKP    1.0   WMS-2465 Created                                                       */
/*******************************************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_DefLot05_02]
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

   IF @dLottable05Value = 0     
      SET @dLottable05Value = NULL

   IF EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND RecType IN ( 'ERR','RGR', 'GRN') )
   BEGIN
      IF @dLottable05Value IS NULL  
      BEGIN
         --SET @dLottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), GETDATE(), 120), 120)
         
         SELECT TOP 1 @dLottable05 = MIN(Lotattribute.Lottable05)
         FROM Lotattribute Lotattribute WITH (NOLOCK)
            JOIN LOTXLOCXID LLI WITH (NOLOCK) 
            ON Lotattribute.Lot = LLI.Lot AND Lotattribute.Storerkey = LLI.Storerkey AND Lotattribute.Sku = LLI.Sku
         WHERE Lotattribute.Sku = @cSKU
            AND Lotattribute.Storerkey = @cStorerKey
            AND Lotattribute.Lottable01 = CASE WHEN ISNULL(@cLottable01Value,'') = '' THEN Lotattribute.Lottable01 ELSE '' END 
            AND Lotattribute.Lottable02 = CASE WHEN ISNULL(@cLottable02Value,'') = '' THEN Lotattribute.Lottable02 ELSE '' END 
            AND Lotattribute.Lottable03 = CASE WHEN ISNULL(@cLottable03Value,'') = '' THEN Lotattribute.Lottable03 ELSE '' END 
            AND Lotattribute.Lottable04 = CASE WHEN ISNULL(@dLottable04Value,'') = '' THEN Lotattribute.Lottable04 ELSE '' END 
            AND Lotattribute.Lottable06 = CASE WHEN ISNULL(@cLottable06Value,'') = '' THEN Lotattribute.Lottable06 ELSE '' END 
            AND Lotattribute.Lottable07 = CASE WHEN ISNULL(@cLottable07Value,'') = '' THEN Lotattribute.Lottable07 ELSE '' END 
            AND Lotattribute.Lottable08 = CASE WHEN ISNULL(@cLottable08Value,'') = '' THEN Lotattribute.Lottable08 ELSE '' END 
            AND Lotattribute.Lottable09 = CASE WHEN ISNULL(@cLottable09Value,'') = '' THEN Lotattribute.Lottable09 ELSE '' END 
            AND Lotattribute.Lottable10 = CASE WHEN ISNULL(@cLottable10Value,'') = '' THEN Lotattribute.Lottable10 ELSE '' END 
            AND Lotattribute.Lottable11 = CASE WHEN ISNULL(@cLottable11Value,'') = '' THEN Lotattribute.Lottable11 ELSE '' END 
            AND Lotattribute.Lottable12 = CASE WHEN ISNULL(@cLottable12Value,'') = '' THEN Lotattribute.Lottable12 ELSE '' END 
            AND ISNULL(Lotattribute.Lottable13,'') = CASE WHEN ISNULL(@dLottable13Value,'') = '' THEN ISNULL(Lotattribute.Lottable13,'') ELSE '' END 
            AND ISNULL(Lotattribute.Lottable14,'') = CASE WHEN ISNULL(@dLottable14Value,'') = '' THEN ISNULL(Lotattribute.Lottable14,'') ELSE '' END 
            AND ISNULL(Lotattribute.Lottable15,'') = CASE WHEN ISNULL(@dLottable15Value,'') = '' THEN ISNULL(Lotattribute.Lottable15,'') ELSE '' END 
            AND LLI.Qty > 0
         
         IF ISNULL(@dLottable05,'') = ''
         BEGIN
            SELECT TOP 1 @dLottable05 = MIN(Lotattribute.Lottable05)
            FROM Lotattribute Lotattribute WITH (NOLOCK)
               JOIN LOTXLOCXID LLI WITH (NOLOCK) 
               ON Lotattribute.Lot = LLI.Lot AND Lotattribute.Storerkey = LLI.Storerkey AND Lotattribute.Sku = LLI.Sku
            WHERE Lotattribute.Sku = @cSKU
               AND Lotattribute.Storerkey = @cStorerKey
               AND Lotattribute.Lottable01 = CASE WHEN ISNULL(@cLottable01Value,'') = '' THEN Lotattribute.Lottable01 ELSE '' END 
               AND Lotattribute.Lottable02 = CASE WHEN ISNULL(@cLottable02Value,'') = '' THEN Lotattribute.Lottable02 ELSE '' END 
               AND Lotattribute.Lottable03 = CASE WHEN ISNULL(@cLottable03Value,'') = '' THEN Lotattribute.Lottable03 ELSE '' END 
               AND Lotattribute.Lottable04 = CASE WHEN ISNULL(@dLottable04Value,'') = '' THEN Lotattribute.Lottable04 ELSE '' END 
               AND Lotattribute.Lottable06 = CASE WHEN ISNULL(@cLottable06Value,'') = '' THEN Lotattribute.Lottable06 ELSE '' END 
               AND Lotattribute.Lottable07 = CASE WHEN ISNULL(@cLottable07Value,'') = '' THEN Lotattribute.Lottable07 ELSE '' END 
               AND Lotattribute.Lottable08 = CASE WHEN ISNULL(@cLottable08Value,'') = '' THEN Lotattribute.Lottable08 ELSE '' END 
               AND Lotattribute.Lottable09 = CASE WHEN ISNULL(@cLottable09Value,'') = '' THEN Lotattribute.Lottable09 ELSE '' END 
               AND Lotattribute.Lottable10 = CASE WHEN ISNULL(@cLottable10Value,'') = '' THEN Lotattribute.Lottable10 ELSE '' END 
               AND Lotattribute.Lottable11 = CASE WHEN ISNULL(@cLottable11Value,'') = '' THEN Lotattribute.Lottable11 ELSE '' END 
               AND Lotattribute.Lottable12 = CASE WHEN ISNULL(@cLottable12Value,'') = '' THEN Lotattribute.Lottable12 ELSE '' END 
               AND ISNULL(Lotattribute.Lottable13,'') = CASE WHEN ISNULL(@dLottable13Value,'') = '' THEN ISNULL(Lotattribute.Lottable13,'') ELSE '' END 
               AND ISNULL(Lotattribute.Lottable14,'') = CASE WHEN ISNULL(@dLottable14Value,'') = '' THEN ISNULL(Lotattribute.Lottable14,'') ELSE '' END 
               AND ISNULL(Lotattribute.Lottable15,'') = CASE WHEN ISNULL(@dLottable15Value,'') = '' THEN ISNULL(Lotattribute.Lottable15,'') ELSE '' END 
            
            IF ISNULL(@dLottable05,'') = ''
            BEGIN
               SET @dLottable05 = GETDATE() 
            END
         END
      
      END
   END
  
Fail:

END

GO
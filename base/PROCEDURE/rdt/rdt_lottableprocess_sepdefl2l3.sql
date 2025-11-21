SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: rdt_LottableProcess_SEPDefL2L3                        */
/* Copyright      : LF                                                    */
/*                                                                        */
/* Purpose: Default L02 & L03. 1 ASN 1 L02. Default L03 as NA             */
/*          production date (L13)                                         */
/*                                                                        */
/* Date        Rev  Author      Purposes                                  */
/* 2020-07-08  1.0  James       WMS13257. Created                         */
/* 2023-04-18  1.1  James       WMS-22263 Add logic to determine whether  */
/*                              need default the Lottable03 (james01)     */
/**************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_SEPDefL2L3]
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

   DECLARE @cLong    NVARCHAR( 250)
   DECLARE @cShort   NVARCHAR( 10)
   SET @nErrNo = 0

   SELECT TOP 1 @cLottable02 = Lottable02
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cSourceKey
   AND   Sku = @cSKU
   ORDER BY 1 
   
   SELECT @cShort = Short,
          @cLong = Long 
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'SEPDefL2L3'
   AND   Code = 'Lottable03'
   AND   Storerkey = @cStorerKey
   
   IF @cShort = '1'
   BEGIN
      IF ISNULL( @cLong, '') <> ''
         SET @cLottable03 = SUBSTRING( @cLong, 1, 18)
   END
   
   Quit:

END -- End Procedure


GO
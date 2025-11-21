SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_DefL11ReturnStock                     */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Use L11 to track return stock                                     */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 01-Dec-2016  Ung       1.0   WMS-723 Created                               */
/* 13-Jul-2021  Chermaine 1.1   WMS-16119 Add codelkup (cc01)                 */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_DefL11ReturnStock]
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
   
   DECLARE @cReceiptKey NVARCHAR( 10)
   DECLARE @cRecType    NVARCHAR(10) 
   DECLARE @cUDF03      NVARCHAR(60)    

   SELECT @cReceiptKey = V_ReceiptKey FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
   SELECT @cRecType = Rectype FROM Receipt WITH (NOLOCK) WHERE storerKey = @cStorerKey AND ReceiptKey = @cReceiptKey
   SELECT @cUDF03 = UDF03 FROM  Codelkup WITH(nolock) WHERE Listname='RecType' AND Storerkey=@cStorerKey AND Code= @cRecType
               
   IF @cUDF03 = ''
   BEGIN
      SET @cUDF03 = @cRecType
   END
            
   SET @cLottable11 = @cUDF03

   --IF @cLottable11 = ''
   --   SET @cLottable11 = 'R' -- Return stock
END

GO
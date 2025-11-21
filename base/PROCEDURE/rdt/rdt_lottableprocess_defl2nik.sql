SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_DefL2NIK                              */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 14-Sep-2015  Ung       1.0   SOS352968 Created                             */
/* 13-Jul-2021  Chermaine 1.1   WMS-16119 Add codelkup (cc01)                 */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_DefL2NIK]
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
   DECLARE @cLOC        NVARCHAR( 10)
   DECLARE @cLong       NVARCHAR( 18)
   DECLARE @cExtRecKey  NVARCHAR(20)
   DECLARE @cUDF02      NVARCHAR(60)   

   SELECT @cReceiptKey = V_ReceiptKey, @cLOC = V_LOC FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
   SELECT @cExtRecKey = ExternReceiptKey FROM Receipt WITH (NOLOCK) WHERE storerKey = @cStorerKey AND ReceiptKey = @cReceiptKey
   SELECT @cUDF02 = UDF02, @cLong = Long FROM  Codelkup WITH(nolock) WHERE Listname='RTNLOC2L10' AND Storerkey=@cStorerKey AND Code= @cLOC 
           
   SET @cLottable02 = @cLong
   SET @cLottable12 = @cUDF02
   SET @cLottable09 = @cExtRecKey
              
   --IF @cLottable02 = ''
   --   SET @cLottable02 = '01000'
END

GO
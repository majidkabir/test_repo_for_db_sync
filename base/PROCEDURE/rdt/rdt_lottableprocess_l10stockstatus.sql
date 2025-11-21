SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_L10StockStatus                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 14-Sep-2015  Ung       1.0   SOS352968 Created                             */
/* 18-Jan-2017  Ung       1.1   WMS-947 Change default L10=C logic            */
/* 06-Jun-2017  Ung       1.2   WMS-2014 Use CodeLKUP get L10 base on LOC     */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_L10StockStatus]
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

   IF @cType = 'PRE'
   BEGIN
      IF @cLottable10 = ''
      BEGIN
         -- Get ASN reason
         DECLARE @cASNReason NVARCHAR( 10)
         SELECT @cASNReason = ASNReason FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey
   
         -- Get TOLOC
         DECLARE @cToLOC NVARCHAR(10)
         SELECT 
            @cToLOC = CASE WHEN Step = 2 THEN I_Field04 ELSE V_LOC END
         FROM rdt.rdtMobRec WITH (NOLOCK) 
         WHERE Mobile = @nMobile

         -- Get stock grade
         DECLARE @cShort NVARCHAR( 10)
         SET @cShort = ''
         SELECT @cShort = ISNULL( Short, '')
         FROM CodeLKUP WITH (NOLOCK)
         WHERE CodeLKUP.ListName = 'RTNLOC2L10' 
            AND CodeLKUP.CODE = @cToLOC
            AND StorerKey = @cStorerKey
            AND Code2 = @nFunc
         
         IF @@ROWCOUNT <> 0
            SET @cLottable10 = @cShort
         ELSE
            SET @cLottable10 = ''
      END
   END
   
   IF @cType = 'POST'
   BEGIN
      IF @cLottable10 = ''
      BEGIN
         SET @nErrNo = 57701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadStockStatus
      END
   END
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_TMCCDefaultLottable                   */
/* Copyright      : MAERSK                                                    */
/*                                                                            */
/* Purpose: Task Manager Cycle Count show default lottable value by task + sku*/
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2024-07-11   James     1.0   WMS-23113. Created                            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_TMCCDefaultLottable]
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

   DECLARE @cLOC  NVARCHAR( 10)
   DECLARE @cID   NVARCHAR( 18)

   DECLARE @cCCLottable01        NVARCHAR( 18),
           @cCCLottable02        NVARCHAR( 18) ,
           @cCCLottable03        NVARCHAR( 18),
           @dCCLottable04        DATETIME,
           @dCCLottable05        DATETIME,
           @cCCLottable06        NVARCHAR( 30),
           @cCCLottable07        NVARCHAR( 30),
           @cCCLottable08        NVARCHAR( 30),
           @cCCLottable09        NVARCHAR( 30),
           @cCCLottable10        NVARCHAR( 30),
           @cCCLottable11        NVARCHAR( 30),
           @cCCLottable12        NVARCHAR( 30),
           @dCCLottable13        DATETIME,
           @dCCLottable14        DATETIME,
           @dCCLottable15        DATETIME

   DECLARE @cTakDetailKey NVARCHAR(10)
   
   SELECT @cTakDetailKey = @cSourceKey

   SELECT 
      @cLOC = V_Loc,
      @cID = V_ID
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT TOP 1
      @cCCLottable01 = Lottable01,
      @cCCLottable02 = Lottable02,
      @cCCLottable03 = Lottable03,
      @dCCLottable04 = Lottable04,
      @dCCLottable05 = Lottable05,
      @cCCLottable06 = Lottable06,
      @cCCLottable07 = Lottable07,
      @cCCLottable08 = Lottable08,
      @cCCLottable09 = Lottable09,
      @cCCLottable10 = Lottable10,
      @cCCLottable11 = Lottable11,
      @cCCLottable12 = Lottable12,
      @dCCLottable13 = Lottable13,
      @dCCLottable14 = Lottable14,
      @dCCLottable15 = Lottable15
   FROM dbo.CCDetail WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
   AND   CCSheetNo = @cTakDetailKey
   AND   Loc = @cLoc
   AND   ID = CASE WHEN ISNULL( @cID, '') = '' THEN ID ELSE @cID END
   AND   SKU = @cSKU
   AND   [Status] = '0'
   ORDER BY 1

   IF @nLottableNo = 1   SET @cLottable01 = @cCCLottable01
   IF @nLottableNo = 2   SET @cLottable02 = @cCCLottable02
   IF @nLottableNo = 3   SET @cLottable03 = @cCCLottable03
   IF @nLottableNo = 4   SET @dLottable04 = @dCCLottable04
   IF @nLottableNo = 5   SET @dLottable05 = @dCCLottable05
   IF @nLottableNo = 6   SET @cLottable06 = @cCCLottable06
   IF @nLottableNo = 7   SET @cLottable07 = @cCCLottable07
   IF @nLottableNo = 8   SET @cLottable08 = @cCCLottable08
   IF @nLottableNo = 9   SET @cLottable09 = @cCCLottable09
   IF @nLottableNo = 10  SET @cLottable10 = @cCCLottable10
   IF @nLottableNo = 11  SET @cLottable11 = @cCCLottable11
   IF @nLottableNo = 12  SET @cLottable12 = @cCCLottable12
   IF @nLottableNo = 13  SET @dLottable13 = @dCCLottable13
   IF @nLottableNo = 14  SET @dLottable14 = @dCCLottable14
   IF @nLottableNo = 15  SET @dLottable15 = @dCCLottable15

   
END

GO
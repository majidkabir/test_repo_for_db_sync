SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: rdt_Lottable02chk_VLT                                 */
/*                                                                        */
/* Purpose: Instead of "required" flag for lot 05                         */
/*                                                                        */
/*                                                                        */
/* Date        Author                                                     */
/* 14/06/2024   PPA374                                                    */
/**************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_Lottable05chk_VLT]
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

   DECLARE @cYearCode   NVARCHAR(2)
   DECLARE @cWeekCode   NVARCHAR(2)
   DECLARE @cDayCode    NVARCHAR(1)
   DECLARE @nShelfLife  INT
   DECLARE @nYearNum    INT
   DECLARE @nWeekNum    INT
   DECLARE @nDayNum     INT
   DECLARE @cYear       NVARCHAR(4)
   DECLARE @cMonth      NVARCHAR(2)
   DECLARE @cProdDate   NVARCHAR(30)
   DECLARE @dProdDate   DATETIME
   DECLARE @cTempLottable04   NVARCHAR( 60)
   DECLARE @cTempLottable13   NVARCHAR( 60)
   DECLARE @cSUSR2            NVARCHAR( 18)
   DECLARE @cErrMessage       NVARCHAR( 20)
   DECLARE @IVASCode        NVARCHAR( MAX)
   DECLARE @IVAS           NVARCHAR( MAX)

   SET @nErrNo = 0

   IF ISNULL( @dLottable05Value , '') <> '' and @cStorerKey = 'HUSQ'
   BEGIN
      SET @dLottable05 = @dLottable05Value
   END

   IF @nLottableNo = 5 and ISNULL( @dLottable05Value, '') = '' and @cStorerKey = 'HUSQ'
   BEGIN
      
     IF ISNULL( @dLottable05Value, '') = ''
     BEGIN
         SET @nErrNo = 217949
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lot05Needed
         SET @nErrNo = -1  -- Make it display value on screen. next ENTER will proceed next screen
     END
   END
   
   Quit:
END -- End Procedure

GO
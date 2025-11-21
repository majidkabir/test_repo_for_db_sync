SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_608NonBlank                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 14-Sep-2015  Ung       1.0   SOS352968 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_608NonBlank]
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

   IF @nFunc = 608
   BEGIN
      -- Get method
      DECLARE @cMethod NVARCHAR( 1)
      SELECT @cMethod = V_String17 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
      
      -- Cannot setup rdt.rdtLottable.Required = 1, due to Required is shared with both method 1 and 2
      -- The requirement is don't need it when method 1, but need in when method = 2
      IF @cMethod = '2' AND (@cType = 'POST' OR @cType = 'BOTH')
      BEGIN
         -- Get lottable
         IF @nLottableNo =  1 SELECT @cLottable = @cLottable01                     ELSE 
         IF @nLottableNo =  2 SELECT @cLottable = @cLottable02                     ELSE 
         IF @nLottableNo =  3 SELECT @cLottable = @cLottable03                     ELSE 
         IF @nLottableNo =  4 SELECT @cLottable = rdt.rdtFormatDate( @dLottable04) ELSE 
         IF @nLottableNo =  5 SELECT @cLottable = rdt.rdtFormatDate( @dLottable05) ELSE 
         IF @nLottableNo =  6 SELECT @cLottable = @cLottable06                     ELSE 
         IF @nLottableNo =  7 SELECT @cLottable = @cLottable07                     ELSE 
         IF @nLottableNo =  8 SELECT @cLottable = @cLottable08                     ELSE 
         IF @nLottableNo =  9 SELECT @cLottable = @cLottable09                     ELSE 
         IF @nLottableNo = 10 SELECT @cLottable = @cLottable10                     ELSE 
         IF @nLottableNo = 11 SELECT @cLottable = @cLottable11                     ELSE 
         IF @nLottableNo = 12 SELECT @cLottable = @cLottable12                     ELSE 
         IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @dLottable13) ELSE 
         IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @dLottable14) ELSE 
         IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @dLottable15)

         -- Check blank
         IF @cLottable = ''
         BEGIN
            SET @nErrNo = 58251
            SET @cErrMsg = RTRIM( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')) + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2) --NeedLottable99
            GOTO Quit
         END

         -- Check date
         IF @nLottableNo IN (4, 5, 13, 14, 15) -- Date fields
         BEGIN
            -- Check valid date
            IF @cLottable <> '' AND rdt.rdtIsValidDate( @cLottable) = 0
            BEGIN
               SET @nErrNo = 58252
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid date
               GOTO Quit
            END
         END
      END
   END
   
Quit:
   
END

GO
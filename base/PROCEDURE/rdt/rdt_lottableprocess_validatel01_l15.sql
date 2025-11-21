SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_ValidateL01_L15                       */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 18-Jan-2019  James     1.0   WMS7684 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_ValidateL01_L15]
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

   DECLARE @cCode    NVARCHAR( 10)
   DECLARE @cNotes   NVARCHAR( 4000)

   IF @cType = 'POST'
   BEGIN

      SELECT @cNotes = Notes
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE ListName = 'TRNCHKLOTR'
      AND   Code = @nLottableNo
      AND   Short = '1' -- turn on; the rest is off
      AND   StorerKey = @cStorerKey
      AND   code2 = @cLottableCode

      IF @@ROWCOUNT = 0
         GOTO Quit

      IF @nLottableNo = 1 
      BEGIN
         IF ISNULL( @cLottable01Value, '') = ''
         BEGIN
            SET @nErrNo = 133901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable01 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT01', @cLottable01Value) = 0
            BEGIN
               SET @nErrNo = 133902
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot01
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 2 
      BEGIN
         IF ISNULL( @cLottable02Value, '') = ''
         BEGIN
            SET @nErrNo = 133903
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable02 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT02', @cLottable02Value) = 0
            BEGIN
               SET @nErrNo = 133904
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot02
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 3 
      BEGIN
         IF ISNULL( @cLottable03Value, '') = ''
         BEGIN
            SET @nErrNo = 133905
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable03 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT03', @cLottable03Value) = 0
            BEGIN
               SET @nErrNo = 133906
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot03
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 4 
      BEGIN
         IF ISNULL( @dLottable04Value, 0) = 0
         BEGIN
            SET @nErrNo = 133907
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable04 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT04', @dLottable04Value) = 0
            BEGIN
               SET @nErrNo = 133908
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot04
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 6 
      BEGIN
         IF ISNULL( @cLottable06Value, '') = ''
         BEGIN
            SET @nErrNo = 133909
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable06 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT06', @cLottable06Value) = 0
            BEGIN
               SET @nErrNo = 133910
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot06
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 7 
      BEGIN
         IF ISNULL( @cLottable07Value, '') = ''
         BEGIN
            SET @nErrNo = 133911
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable07 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT07', @cLottable07Value) = 0
            BEGIN
               SET @nErrNo = 133912
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot07
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 8 
      BEGIN
         IF ISNULL( @cLottable08Value, '') = ''
         BEGIN
            SET @nErrNo = 133913
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable08 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT08', @cLottable08Value) = 0
            BEGIN
               SET @nErrNo = 133914
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot08
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 9 
      BEGIN
         IF ISNULL( @cLottable09Value, '') = ''
         BEGIN
            SET @nErrNo = 133915
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable09 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT09', @cLottable09Value) = 0
            BEGIN
               SET @nErrNo = 133916
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot09
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 10 
      BEGIN
         IF ISNULL( @cLottable10Value, '') = ''
         BEGIN
            SET @nErrNo = 133917
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable10 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT10', @cLottable10Value) = 0
            BEGIN
               SET @nErrNo = 133918
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot10
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 11 
      BEGIN
         IF ISNULL( @cLottable11Value, '') = ''
         BEGIN
            SET @nErrNo = 133919
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable11 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT11', @cLottable11Value) = 0
            BEGIN
               SET @nErrNo = 133920
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot11
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 12 
      BEGIN
         IF ISNULL( @cLottable12Value, '') = ''
         BEGIN
            SET @nErrNo = 133921
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable12 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT12', @cLottable12Value) = 0
            BEGIN
               SET @nErrNo = 133922
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot12
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 13 
      BEGIN
         IF ISNULL( @dLottable13Value, 0) = 0
         BEGIN
            SET @nErrNo = 133923
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable13 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT13', @dLottable13Value) = 0
            BEGIN
               SET @nErrNo = 133924
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot13
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 14 
      BEGIN
         IF ISNULL( @dLottable14Value, 0) = 0
         BEGIN
            SET @nErrNo = 133925
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable14 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT14', @dLottable14Value) = 0
            BEGIN
               SET @nErrNo = 133926
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot14
               GOTO Quit
            END
         END
      END

      IF @nLottableNo = 15 
      BEGIN
         IF ISNULL( @dLottable15Value, 0) = 0
         BEGIN
            SET @nErrNo = 133927
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable15 req
            GOTO Quit
         END

         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOT15', @dLottable15Value) = 0
            BEGIN
               SET @nErrNo = 133928
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot15
               GOTO Quit
            END
         END
      END
   END

   Quit:
END

GO
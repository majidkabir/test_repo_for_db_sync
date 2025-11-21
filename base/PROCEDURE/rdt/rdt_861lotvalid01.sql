SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: rdt_861LotValid01                                    */
/* Copyright      : Maersk WMS                                            */
/* Customer       : PMI                                                   */
/*                                                                        */
/* Date       Rev    Author  Purposes                                     */
/* 2025-02-24 1.0.0  NLT013  FCR-2519 Create                              */
/**************************************************************************/

CREATE   PROCEDURE rdt.rdt_861LotValid01 (
    @nMobile               INT
   ,@nFunc                 INT
   ,@cLangCode             NVARCHAR(  3)
   ,@cStorerKey            NVARCHAR( 15)
   ,@cFacility             NVARCHAR(  5)
   ,@nStep                 INT
   ,@nInputKey             INT
   ,@cUCCLottable1         NVARCHAR( 18)
   ,@cUCCLottable2         NVARCHAR( 18)
   ,@cUCCLottable3         NVARCHAR( 18)
   ,@dUCCLottable4         DATETIME
   ,@cLottable01           NVARCHAR( 18)
   ,@cLottable02           NVARCHAR( 18)
   ,@cLottable03           NVARCHAR( 18)
   ,@dLottable04           DATETIME     
   ,@tValidationData       VariableTable READONLY
   ,@nErrNo                INT           OUTPUT   
   ,@cErrMsg               NVARCHAR( 50) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cMatchUCCLottable      NVARCHAR(20)

   SET @nErrNo = 0
   SET @cErrMsg = ''

   IF @nFunc = 861
   BEGIN
      DECLARE @tLottableList TABLE
      (
         LottableNo     NVARCHAR(5)
      )
      SET @cMatchUCCLottable = rdt.rdtGetConfig( @nFunc, 'MATCHUCCLOTTABLE', @cStorerKey)
      
      INSERT INTO @tLottableList ( LottableNo) 
      SELECT VALUE FROM STRING_SPLIT(@cMatchUCCLottable, ',')

      IF EXISTS(SELECT 1 FROM @tLottableList WHERE LottableNo IN ('01', '02', '03', '04'))
      BEGIN
         IF EXISTS(SELECT 1 FROM @tLottableList WHERE TRIM(LottableNo) = '01')
         BEGIN
            IF @cUCCLottable1 <> @cLottable01
            BEGIN
               SET @nErrNo = 233751
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --233751 Diff Lottable01
               GOTO Fail
            END
         END
         
         IF EXISTS(SELECT 1 FROM @tLottableList WHERE TRIM(LottableNo) = '02')
         BEGIN
            IF @cUCCLottable2 <> @cLottable02
            BEGIN
               SET @nErrNo = 233752
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --233752 Diff Lottable02
               GOTO Fail
            END
         END

         IF EXISTS(SELECT 1 FROM @tLottableList WHERE TRIM(LottableNo) = '03')
         BEGIN
            IF @cUCCLottable3 <> @cLottable03
            BEGIN
               SET @nErrNo = 233753
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --233753 Diff Lottable03
               GOTO Fail
            END
         END

         IF EXISTS(SELECT 1 FROM @tLottableList WHERE TRIM(LottableNo) = '04')
         BEGIN
            IF IsNULL(@dUCCLottable4, 0) <> IsNULL(@dLottable04, 0)
            BEGIN
               SET @nErrNo = 233754
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --233754 Diff Lottable04
               GOTO Fail
            END
         END
      END
   END

END
Fail:

GO
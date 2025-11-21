SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CycleCountValidAllLottable                     */
/* Copyright      :  Maersk                                             */
/*                                                                      */
/* Purpose: Check lottable format                                       */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 15-01-2025  1.0  CYU027      FCR-1759 Created                        */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_CycleCountValidAllLottable
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cLottable01      NVARCHAR( 30),
   @cLottable02      NVARCHAR( 30),
   @cLottable03      NVARCHAR( 30),
   @cLottable04      NVARCHAR( 30),
   @cLottable05      NVARCHAR( 30),
   @nSetFocusField   INT       OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   --Validation 5 lottables
   DECLARE @LottableMap TABLE
   (
      ID INT IDENTITY(1,1) NOT NULL,
      LottableNo INT,
      InField NVARCHAR(50),
      Focus INT
   )

   DECLARE  @currentId INT = 1 ,
            @currentLotNo INT ,
            @currentLotVal NVARCHAR( 18),
            @currentFocus INT

   INSERT INTO @LottableMap (LottableNo, InField, Focus)
   VALUES
      (1, @cLottable01, 2),
      (2, @cLottable02, 4),
      (3, @cLottable03, 6),
      (4, @cLottable04, 8),
      (5, @cLottable05, 10)

   WHILE @currentId <= 5
   BEGIN
      -- Get the current lottable number and field value
      SELECT @currentLotNo = LottableNo,
             @currentLotVal = InField,
             @currentFocus = Focus
      FROM @LottableMap
      WHERE ID = @currentId

      IF @currentLotVal <> ''
      BEGIN
         EXEC rdt.rdt_LottableFormat_RDTFormat
              @nMobile        = @nMobile,
              @nFunc          = @nFunc,
              @cLangCode      = @cLangCode,
              @nInputKey      = @nInputKey,
              @cStorerKey     = @cStorerKey,
              @cSKU           = '',
              @cLottableCode  = '',
              @nLottableNo    = @currentLotNo,
              @cFormatSP      = '',
              @cLottableValue = @currentLotVal,
              @cLottable      = '',
              @nErrNo         = @nErrNo OUTPUT,
              @cErrMsg        = @cErrMsg OUTPUT

         IF ISNULL(@cErrMsg, '') <> ''
         BEGIN
            SET @nSetFocusField = @currentFocus
            GOTO Quit
         END
      END

      SET @currentId = @currentId + 1
   END

END

Quit:

GO
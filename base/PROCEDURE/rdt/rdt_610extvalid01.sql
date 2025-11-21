SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_610ExtValid01                                   */
/*                                                                      */  
/* Purpose: Ext Validation                                              */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */
/* 15-01-2025  1.0  CYU027      FCR-1759 Created                        */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_610ExtValid01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cCCRefNo       NVARCHAR( 10),
   @cCCSheetNo     NVARCHAR( 10),
   @nCCCountNo     INT,
   @cZone1         NVARCHAR( 10),
   @cZone2         NVARCHAR( 10),
   @cZone3         NVARCHAR( 10),
   @cZone4         NVARCHAR( 10),
   @cZone5         NVARCHAR( 10),
   @cAisle         NVARCHAR( 10),
   @cLevel         NVARCHAR( 10),
   @cLOC           NVARCHAR( 10),
   @cID            NVARCHAR( 18),
   @cUCC           NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @nQty           INT,
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @cLottable04    NVARCHAR( 18),
   @cLottable05    NVARCHAR( 18),
   @tExtUpdate     VariableTable READONLY,
   @nSetFocusField INT           OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nStep = 12 or @nStep = 16
   BEGIN
      IF @nInputKey = 1
      BEGIN

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
   END
  
   Quit:  
  
END  

GO
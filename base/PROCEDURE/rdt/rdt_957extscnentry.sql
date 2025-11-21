SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_957ExtScnEntry                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:       For Unilever                                          */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-02-26 1.0  Dennis   Draft                                       */
/************************************************************************/

CREATE   PROC [rdt].[rdt_957ExtScnEntry] (
   @cExtendedScreenSP  NVARCHAR( 20)
	,@nMobile         INT          
   ,@nFunc           INT          
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT          
   ,@nInputKey       INT          
   ,@cFacility       NVARCHAR( 5) 
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cPickZone       NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@cSuggLOC        NVARCHAR( 10)
   ,@cSuggID         NVARCHAR( 18)
   ,@cSuggSKU        NVARCHAR( 20)
   ,@nSuggQTY        INT          
   ,@cOption         NVARCHAR( 1) 
   ,@cLottableCode   NVARCHAR( 30)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME     
   ,@dLottable05     DATETIME     
   ,@cLottable06     NVARCHAR( 30)
   ,@cLottable07     NVARCHAR( 30)
   ,@cLottable08     NVARCHAR( 30)
   ,@cLottable09     NVARCHAR( 30)
   ,@cLottable10     NVARCHAR( 30)
   ,@cLottable11     NVARCHAR( 30)
   ,@cLottable12     NVARCHAR( 30)
   ,@dLottable13     DATETIME     
   ,@dLottable14     DATETIME     
   ,@dLottable15     DATETIME     
   ,@cBarcode        NVARCHAR( 60)
   ,@nAction         INT --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
	,@nAfterScn       INT OUTPUT
   ,@nAfterStep      INT OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE  
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX)

   SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedScreenSP ) +
      ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
      ' @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC, @cSuggID, @cSuggSKU, @nSuggQTY, @cOption, @cLottableCode, ' +
      ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
      ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
      ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
      ' @cBarcode,
         @nAction, @nAfterScn OUTPUT, @nAfterStep OUTPUT, 
         @nErrNo   OUTPUT, @cErrMsg  OUTPUT'

   SET @cSQLParam =
      ' @nMobile         INT                      ' +
      ',@nFunc           INT                      ' +
      ',@cLangCode       NVARCHAR( 3)             ' +
      ',@nStep           INT                      ' +
      ',@nInputKey       INT                      ' +
      ',@cFacility       NVARCHAR( 5)             ' +
      ',@cStorerKey      NVARCHAR( 15)            ' +
      ',@cPickSlipNo     NVARCHAR( 10)            ' +
      ',@cPickZone       NVARCHAR( 10)            ' +
      ',@cDropID         NVARCHAR( 20)            ' +
      ',@cSuggLOC        NVARCHAR( 10)            ' +
      ',@cSuggID         NVARCHAR( 18)            ' +
      ',@cSuggSKU        NVARCHAR( 20)            ' +
      ',@nSuggQTY        INT                      ' +
      ',@cOption         NVARCHAR( 1)             ' +
      ',@cLottableCode   NVARCHAR( 30)   ' +
      ',@cLottable01     NVARCHAR( 18)   ' +
      ',@cLottable02     NVARCHAR( 18)   ' +
      ',@cLottable03     NVARCHAR( 18)   ' +
      ',@dLottable04     DATETIME        ' +
      ',@dLottable05     DATETIME        ' +
      ',@cLottable06     NVARCHAR( 30)   ' +
      ',@cLottable07     NVARCHAR( 30)   ' +
      ',@cLottable08     NVARCHAR( 30)   ' +
      ',@cLottable09     NVARCHAR( 30)   ' +
      ',@cLottable10     NVARCHAR( 30)   ' +
      ',@cLottable11     NVARCHAR( 30)   ' +
      ',@cLottable12     NVARCHAR( 30)   ' +
      ',@dLottable13     DATETIME        ' +
      ',@dLottable14     DATETIME        ' +
      ',@dLottable15     DATETIME        ' +
      ',@cBarcode        NVARCHAR( 60)   ' +
      ',@nAction         INT,
      @nAfterScn    INT OUTPUT, @nAfterStep    INT OUTPUT, 
      @nErrNo             INT            OUTPUT, 
      @cErrMsg            NVARCHAR( 20)  OUTPUT'

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
      @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC, @cSuggID, @cSuggSKU, @nSuggQTY, @cOption, @cLottableCode, 
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
      @cBarcode,
      @nAction, 
      @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
      @nErrNo   OUTPUT, 
      @cErrMsg  OUTPUT

END

SET QUOTED_IDENTIFIER OFF 

GO
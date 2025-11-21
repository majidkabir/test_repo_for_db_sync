SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_957ExtScn01                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-02-26 1.0  Dennis   Draft                                       */
/*                                                                      */
/************************************************************************/

CREATE    PROC [RDT].[rdt_957ExtScn01] (
	@nMobile         INT          
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
   DECLARE @nShelfLife FLOAT
   DECLARE @cResultCode NVARCHAR( 60)
   DECLARE
   @nRowCount            INT,
   @cexternReceiptKey    NVARCHAR( 30), 
   @cexternLineNo        NVARCHAR( 30),    
   @nLotNum              INT,
   @cListName            NVARCHAR( 30),
   @cLotValue            NVARCHAR( 30),     
   @cStorerConfig        NVARCHAR( 50),  
   @SQL                  NVARCHAR( MAX),
   @cUserDefine08        NVARCHAR( 30),  
   @nSQLResult           INT,
   @nCheckDigit          INT,
   @cActLoc              NVARCHAR( 20),
   @cPalletTypeInUse     NVARCHAR( 5),
   @cPalletTypeSave      NVARCHAR( 10),
   @cLott10              NVARCHAR( 30)

/*   SELECT
   @cLott10 = C_String1,
   @cPalletTypeSave = C_String2
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
*/

   IF @nAction = 1 --Validation
   BEGIN
	   IF @nFunc = 957 
	   BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @nStep = 5 -- Close DropID or Short pick
            BEGIN
               IF @cOption IN ('1', '3') -- ENTER and close drop ID --NLT013 option = 1 is short pick, need trigger msg to WCS
               BEGIN
                  -- Using drop ID, send tote to WCS
                  IF @cBarcode <> ''
                  BEGIN
                     --Trigger MSG to WCS 
                     EXEC rdt.rdt_839SendMsgToWCS @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                        ,@cPickSlipNo
                        ,@cBarcode
                        ,@nErrNo       OUTPUT
                        ,@cErrMsg      OUTPUT
                     IF @nErrNo <> 0
                        GOTO Quit
                  END
               END
            END
            IF @nStep = 7 -- Confirm pick loc
            BEGIN
            IF @nInputKey = 0 --Esc
            BEGIN
               -- Using drop ID, send tote to WCS
               IF @cBarcode <> ''
               BEGIN
                  --Trigger MSG to WCS 
                  EXEC rdt.rdt_839SendMsgToWCS @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                     ,@cPickSlipNo
                     ,@cBarcode
                     ,@nErrNo       OUTPUT
                     ,@cErrMsg      OUTPUT
                  IF @nErrNo <> 0
                     GOTO Quit
               END 
            END
            END
         END
		END
      GOTO Quit
	END

Exception:
   ROLLBACK TRANSACTION

Quit:
/*
UPDATE RDT.RDTMOBREC SET
   C_String1 = @cLott10,
   C_String2 = @cPalletTypeSave
   WHERE Mobile = @nMobile
*/

END; 

SET QUOTED_IDENTIFIER OFF 

GO
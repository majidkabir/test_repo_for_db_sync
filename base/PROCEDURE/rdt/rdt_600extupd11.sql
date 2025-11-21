SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtUpd11                                           */
/* Copyright    Maersk                                                        */
/* Customer     HUDA                                                          */
/*                                                                            */
/* Purpose: save or clear count into rdt.RDTMOBREC.C_String1                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 26-Sep-2024  yys027    1.0   FCR-827 Created (Batch No)                    */
/******************************************************************************/

CREATE   PROC rdt.rdt_600ExtUpd11 (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,
   @nQTY         INT,            --pass in decode count
   @cReasonCode  NVARCHAR( 10),
   @cSuggToLOC   NVARCHAR( 10),
   @cFinalLOC    NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cBatchCheck NVARCHAR(20)
   SELECT  @cBatchCheck= rdt.rdtGetConfig(@nFunc,'BatchCheck',@cStorerKey)
   IF ISNULL(@cBatchCheck,'')=''
   BEGIN
      GOTO Quit
   END   
   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4 AND @nInputKey = 1 -- Scan SKU  && Enter
      BEGIN
         -- use field rdt.RDTMOBREC.C_String1
         UPDATE rdt.RDTMOBREC SET C_String1='0' WHERE Mobile = @nMobile
         EXEC rdt.rdtSetFocusField @nMobile,2
      END
      ELSE IF @nStep = 6 AND @nInputKey = 0    -- ESC when input qty
      BEGIN
         UPDATE rdt.RDTMOBREC SET C_String1='0' WHERE Mobile = @nMobile
      END
   END

Quit:

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1580ExtUpd05                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Print variance label                                        */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 25-05-2018  1.0  Ung         WMS-5175 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtUpd05]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@nAfterStep   INT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 1581 -- Piece receiving
   BEGIN
      IF @nStep = 4 AND -- Lottable
         @nAfterStep = 3 -- ID
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            -- Get ToID, due to it is overwrite by AutoID
            SELECT @cToID = V_ID FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
            
            IF @cToID <> ''
            BEGIN
               -- Check variance
               IF EXISTS( SELECT TOP 1 1 
                  FROM ReceiptDetail WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                     AND ToID = @cToID
                     AND QTYExpected <> BeforeReceivedQTY)
               BEGIN
                  -- Get storer config
                  DECLARE @cPalletVarianceLabel NVARCHAR(10)
                  DECLARE @cFacility NVARCHAR(5)
                  DECLARE @cLabelPrinter NVARCHAR(10)
                  DECLARE @cPaperPrinter NVARCHAR(10)
                  
                  SET @cPalletVarianceLabel = rdt.RDTGetConfig( @nFunc, 'PalletVarianceLabel', @cStorerKey)
                  IF @cPalletVarianceLabel = '0'
                     SET @cPalletVarianceLabel = ''
                  
                     -- Print pallet variance label
                  IF @cPalletVarianceLabel <> ''
                  BEGIN
                     -- Get session info
                     SELECT 
                        @cFacility = Facility,
                        @cLabelPrinter = Printer,  
                        @cPaperPrinter = Printer_Paper
                     FROM rdt.rdtMobrec WITH (NOLOCK)
                     WHERE Mobile = @nMobile 
                     
                     -- Common params
                     DECLARE @tPalletVarianceLabel AS VariableTable
                     INSERT INTO @tPalletVarianceLabel (Variable, Value) VALUES 
                        ( '@cStorerKey',     @cStorerKey), 
                        ( '@cReceiptKey',    @cReceiptKey), 
                        ( '@cToID',          @cToID)

                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                        @cPalletVarianceLabel, -- Report type
                        @tPalletVarianceLabel, -- Report params
                        'rdt_1580ExtUpd05', 
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT
                     
                     -- Ignore printing error
                     SET @nErrNo = 0
                  END
               END
            END
         END
      END
   END
   
Quit:

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExtPA02                                            */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 16-Nov-2016  Ung       1.0   WMS-632 Created                               */
/* 10-Jul-2017  Ung       1.1   WMS-2369 Change suggested ID logic            */
/* 11-Dec-2017  Ung       1.2   WMS-3539 Add ExcessStockIDLOC                 */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607ExtPA02]
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cRefNo       NVARCHAR( 20),
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,
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
   @cReasonCode  NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cLOC         NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @cSuggID      NVARCHAR( 18)  OUTPUT,
   @cSuggLOC     NVARCHAR( 10)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   DECLARE @cExcessStockIDLOC NVARCHAR( 20)

   -- Storer config
   SET @cExcessStockIDLOC = rdt.rdtGetConfig( @nFunc, 'ExcessStockIDLOC', @cStorerKey)
   IF @cExcessStockIDLOC = '0'
      SET @cExcessStockIDLOC = ''

   IF @nFunc = 607 -- Return v7
   BEGIN
      /*
      -- Get suggested LOC, ID
      EXEC rdt.rdt_607ExtPA02_IDLOC
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cReasonCode, @cID, @cLOC, @cReceiptLineNumber,
         @cSuggID    OUTPUT,
         @cSuggLOC   OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
      */
      
      IF @cExcessStockIDLOC <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExcessStockIDLOC AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExcessStockIDLOC) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' + 
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' + 
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' + 
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' + 
               ' @cReasonCode, @cID, @cLOC, @cReceiptLineNumber, ' + 
               ' @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT ' 
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cReceiptKey  NVARCHAR( 10), ' +
               ' @cPOKey       NVARCHAR( 10), ' +
               ' @cRefNo       NVARCHAR( 20), ' +
               ' @cSKU         NVARCHAR( 20), ' +
               ' @nQTY         INT          , ' +
               ' @cLottable01  NVARCHAR( 18), ' +
               ' @cLottable02  NVARCHAR( 18), ' +
               ' @cLottable03  NVARCHAR( 18), ' +
               ' @dLottable04  DATETIME     , ' +
               ' @dLottable05  DATETIME     , ' +
               ' @cLottable06  NVARCHAR( 30), ' +
               ' @cLottable07  NVARCHAR( 30), ' +
               ' @cLottable08  NVARCHAR( 30), ' +
               ' @cLottable09  NVARCHAR( 30), ' +
               ' @cLottable10  NVARCHAR( 30), ' +
               ' @cLottable11  NVARCHAR( 30), ' +
               ' @cLottable12  NVARCHAR( 30), ' +
               ' @dLottable13  DATETIME     , ' +
               ' @dLottable14  DATETIME     , ' +
               ' @dLottable15  DATETIME     , ' +
               ' @cReasonCode  NVARCHAR( 10), ' + 
               ' @cID          NVARCHAR( 18), ' +
               ' @cLOC         NVARCHAR( 10), ' +  
               ' @cReceiptLineNumber NVARCHAR( 5),    ' + 
               ' @cSuggID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cSuggLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cID, @cLOC, @cReceiptLineNumber,
               @cSuggID    OUTPUT,
               @cSuggLOC   OUTPUT,
               @nErrNo     OUTPUT,
               @cErrMsg    OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END


      /********************************************************************************************
                                             Excess stock to PO
      ********************************************************************************************/
      DECLARE @nExcessQTY INT
      DECLARE @nActQTY INT

      -- Check whether is excess stock
      EXEC rdt.rdt_607ExcessStockToPO01
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cReasonCode, @cID, @cLOC, @cReceiptLineNumber, 'CALCULATE',
         @nExcessQTY OUTPUT,
         @nActQTY    OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
         
      -- Excess stock
      IF @nExcessQTY > 0
      BEGIN
         -- Insert PO
         EXEC rdt.rdt_607ExcessStockToPO01
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cReasonCode, @cID, @cLOC, @cReceiptLineNumber, 'POHEADER',
            @nExcessQTY OUTPUT,
            @nActQTY    OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prompt excess stock
         DECLARE @cMsg1 NVARCHAR(20)
         DECLARE @cMsg2 NVARCHAR(20)
         DECLARE @cMsg3 NVARCHAR(20)

         SET @cMsg1 = rdt.rdtgetmessage( 113451, @cLangCode, 'DSP') --EXCESS STOCK:
         SET @cMsg1 = RTRIM( @cMsg1) + CAST( @nExcessQTY AS NVARCHAR(5))
         SET @cMsg2 = rdt.rdtgetmessage( 113452, @cLangCode, 'DSP') --TO ID:
         SET @cMsg3 = rdt.rdtgetmessage( 113453, @cLangCode, 'DSP') --TO LOC:

         SET @cSuggID = 'V' + @cSuggID

         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cMsg1,
            '',
            @cMsg2,
            @cSuggID,
            '',
            @cMsg3,
            @cSuggLOC
      END
   END

Quit:

END

GO
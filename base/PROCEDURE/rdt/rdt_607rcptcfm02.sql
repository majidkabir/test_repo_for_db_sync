SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607RcptCfm02                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author   Ver.  Purposes                                        */
/* 04-08-2017  Ung      1.0   WMS-2369 Created                                */
/* 11-Dec-2017 Ung      1.1   WMS-3539 Add ExcessStockIDLOC                   */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607RcptCfm02]
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),  
   @cToID          NVARCHAR( 18),
   @cSKUCode       NVARCHAR( 20),
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,
   @cCreateUCC     NVARCHAR( 1),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,
   @dLottable14    DATETIME,
   @dLottable15    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
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
      /********************************************************************************************
                                             Excess stock to PO
      ********************************************************************************************/
      DECLARE @nExcessQTY INT
      DECLARE @nActQTY INT
      DECLARE @cSuggID NVARCHAR( 18)
      DECLARE @cSuggLOC NVARCHAR( 10)
      
      -- Check whether is excess stock
      EXEC rdt.rdt_607ExcessStockToPO01 
         @nMobile, @nFunc, @cLangCode, 0, 0, @cStorerKey, @cReceiptKey, @cPOKey, '', @cSKUCode, @nSKUQTY,           
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,      
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
         @cConditionCode, @cToID, @cToLOC, @cReceiptLineNumber, 'CALCULATE', 
         @nExcessQTY OUTPUT, 
         @nActQTY    OUTPUT, 
         @nErrNo     OUTPUT, 
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Excess stock
      IF @nExcessQTY > 0
      BEGIN
         -- Get suggested LOC, ID
         SET @cSuggID = ''
         SET @cSuggLOC = ''
         /*
         EXEC rdt.rdt_607ExtPA02_IDLOC
            @nMobile, @nFunc, @cLangCode, 0, 0, @cStorerKey, @cReceiptKey, @cPOKey, '', @cSKUCode, @nSKUQTY,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cConditionCode, @cToID, @cToLOC, @cReceiptLineNumber,
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
                  @nMobile, @nFunc, @cLangCode, 0, 0, @cStorerKey, @cReceiptKey, @cPOKey, '', @cSKUCode, @nSKUQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cConditionCode, @cToID, @cToLOC, @cReceiptLineNumber,
                  @cSuggID    OUTPUT,
                  @cSuggLOC   OUTPUT,
                  @nErrNo     OUTPUT,
                  @cErrMsg    OUTPUT
   
               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
           
         SET @cSuggID = 'V' + @cSuggID
         
         -- Insert or update PODetail
         EXEC rdt.rdt_607ExcessStockToPO01 
            @nMobile, @nFunc, @cLangCode, 0, 0, @cStorerKey, @cReceiptKey, @cPOKey, '', @cSKUCode, @nSKUQTY,           
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,      
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
            @cConditionCode, @cSuggID, @cSuggLOC, @cReceiptLineNumber, 'PODETAIL', 
            @nExcessQTY OUTPUT, 
            @nActQTY    OUTPUT, 
            @nErrNo     OUTPUT, 
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
      
      IF @nActQTY > 0
      BEGIN
         -- Receive
         EXEC rdt.rdt_Receive_V7
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cReceiptKey   = @cReceiptKey,
            @cPOKey        = @cPoKey,  -- (ChewKP01)
            @cToLOC        = @cToLOC,
            @cToID         = @cToID,
            @cSKUCode      = @cSKUCode,
            @cSKUUOM       = @cSKUUOM,
            @nSKUQTY       = @nActQTY,
            @cUCC          = '',
            @cUCCSKU       = '',
            @nUCCQTY       = '',
            @cCreateUCC    = '',
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = NULL,
            @cLottable06   = @cLottable06,
            @cLottable07   = @cLottable07,
            @cLottable08   = @cLottable08,
            @cLottable09   = @cLottable09,
            @cLottable10   = @cLottable10,
            @cLottable11   = @cLottable11,
            @cLottable12   = @cLottable12,
            @dLottable13   = @dLottable13,
            @dLottable14   = @dLottable14,
            @dLottable15   = @dLottable15,
            @nNOPOFlag     = @nNOPOFlag,
            @cConditionCode = @cConditionCode,
            @cSubreasonCode = '', 
            @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      END
   END

Quit:

END

SET QUOTED_IDENTIFIER OFF

GO
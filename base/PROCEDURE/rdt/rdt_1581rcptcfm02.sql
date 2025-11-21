SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1581RcptCfm02                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Receive piece by piece and print label after receive 1 piece      */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2017-08-16 1.0  James      WMS2584. Created                                */
/* 2018-06-11 1.1  Ung        WMS-4695 Change to receive by L01               */
/* 2018-09-25 1.2  Ung        WMS-5722 Add param                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1581RcptCfm02] (
   @nFunc            INT,  
   @nMobile          INT,  
   @cLangCode        NVARCHAR( 3), 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cReceiptKey      NVARCHAR( 10), 
   @cPOKey           NVARCHAR( 10),	
   @cToLOC           NVARCHAR( 10), 
   @cToID            NVARCHAR( 18), 
   @cSKUCode         NVARCHAR( 20), 
   @cSKUUOM          NVARCHAR( 10), 
   @nSKUQTY          INT, 
   @cUCC             NVARCHAR( 20), 
   @cUCCSKU          NVARCHAR( 20), 
   @nUCCQTY          INT, 
   @cCreateUCC       NVARCHAR( 1),  
   @cLottable01      NVARCHAR( 18), 
   @cLottable02      NVARCHAR( 18), 
   @cLottable03      NVARCHAR( 18), 
   @dLottable04      DATETIME, 
   @dLottable05      DATETIME, 
   @nNOPOFlag        INT, 
   @cConditionCode   NVARCHAR( 10),
   @cSubreasonCode   NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @cSerialNo        NVARCHAR( 30) = '', 
   @nSerialQTY       INT = 0, 
   @nBulkSNO         INT = 0,
   @nBulkSNOQTY      INT = 0
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @nTranCount           INT,
        @nNoOfCopy            INT,
        @cLabelPrinter        NVARCHAR( 10),
        @cExtASN              NVARCHAR( 20),
        @cLottable01ToRCV     NVARCHAR( 18),
        @cLottable02ToRCV     NVARCHAR( 18),
        @cLottable03ToRCV     NVARCHAR( 18),
        @dLottable04ToRCV     DATETIME,
        @cSkipLottable01      NVARCHAR( 1),
        @cSkipLottable02      NVARCHAR( 1),
        @cSkipLottable03      NVARCHAR( 1),
        @cSkipLottable04      NVARCHAR( 1)

      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN rdt_1581RcptCfm02

      -- ToID & ToLOC is pre calculated before receiving take place.
      -- Look for correct receiptdetail line to receive. Take the 1st 
      -- not fully receive line

      IF NOT EXISTS( SELECT TOP 1 1
         FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
         JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
         WHERE R.ReceiptKey = @cReceiptKey
            AND R.StorerKey = @cStorerKey
            AND RD.SKU = @cSKUCode
            AND RD.BeforeReceivedQty < RD.QtyExpected
            AND RD.Lottable01 = @cLottable01)
      BEGIN
         SET @nErrNo = 113851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Line To Rcv
         GOTO RollBackTran
      END

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
         @cPOKey        = @cPOKey,  
         @cToLOC        = @cToLOC,
         @cToID         = @cToID, 
         @cSKUCode      = @cSKUCode,
         @cSKUUOM       = @cSKUUOM,
         @nSKUQTY       = @nSKUQTY,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
         @cCreateUCC    = '',
         @cLottable01   = @cLottable01, --ToRCV,
         @cLottable02   = @cLottable02, --ToRCV,
         @cLottable03   = @cLottable03, --ToRCV,
         @dLottable04   = @dLottable04, --ToRCV,
         @dLottable05   = NULL,
         @cLottable06   = '',
         @cLottable07   = '',
         @cLottable08   = '',
         @cLottable09   = '',
         @cLottable10   = '',
         @cLottable11   = '',
         @cLottable12   = '',
         @dLottable13   = NULL,
         @dLottable14   = NULL,
         @dLottable15   = NULL,
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = '', 
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT   

      IF @nErrNo <> 0
         GOTO RollBackTran

      DECLARE @cSKULabel NVARCHAR(20)
      SET @cSKULabel = rdt.RDTGetConfig( @nFunc, 'SKULabel', @cStorerKey)
      IF @cSKULabel = '0'
         SET @cSKULabel = ''

      IF @cSKULabel <> ''
      BEGIN
         -- Get login info
         SELECT @cLabelPrinter = Printer FROM rdt.rdtMobrec WITH (NOLOCK) WHERE Mobile = @nMobile

         -- Common params
         DECLARE @tSKULabel AS VariableTable
         INSERT INTO @tSKULabel (Variable, Value) VALUES ( '@cReceiptKey', @cReceiptKey)
         INSERT INTO @tSKULabel (Variable, Value) VALUES ( '@cReceiptLineNumber', @cReceiptLineNumber)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
            @cSKULabel, -- Report type
            @tSKULabel, -- Report params
            'rdt_1581RcptCfm02', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT, 
            @nNoOfCopy = @nSKUQTY
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

   GOTO Quit

   RollBackTran:  
      ROLLBACK TRAN rdt_1581RcptCfm02 

   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  


GO
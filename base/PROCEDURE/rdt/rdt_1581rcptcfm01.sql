SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1581RcptCfm01                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Use rdt_Receive_v7 to do receiving                                */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2016-09-08 1.0  James      Created                                         */
/* 2018-09-25 1.1  Ung        WMS-5722 Add param                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1581RcptCfm01] (
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

DECLARE @nQTY_Bal             INT,
        @nQTY                 INT,
        @nTranCount           INT,
        @bSuccess             INT,
        @cLabelPrinter        NVARCHAR( 10),
        @cReportType          NVARCHAR( 10),
        @cPrintJobName        NVARCHAR( 60),
        @cDataWindow          NVARCHAR( 50),
        @cTargetDB            NVARCHAR( 20),
        @cNewUCC              NVARCHAR( 20),
        @cCounter             NVARCHAR( 20),
        @cLOT                 NVARCHAR( 10)
        
      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN rdt_1581RcptCfm01

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
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
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

   GOTO Quit

   RollBackTran:  
      ROLLBACK TRAN rdt_1581RcptCfm01 

   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  


GO
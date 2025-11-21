SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1581RcptCfm04                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Use rdt_Receive_v7 to do receiving                                */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2017-09-15 1.0  James      WMS1895.Created                                 */
/* 2018-09-25 1.1  Ung        WMS-5722 Add param                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1581RcptCfm04] (
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
        @cLOT                 NVARCHAR( 10),
        @cExternReceiptKey    NVARCHAR( 20),
        @cLottable06          NVARCHAR( 30), 
        @cLottable07          NVARCHAR( 30), 
        @cLottable08          NVARCHAR( 30), 
        @cLottable09          NVARCHAR( 30), 
        @cLottable10          NVARCHAR( 30), 
        @cLottable11          NVARCHAR( 30), 
        @cLottable12          NVARCHAR( 30), 
        @dLottable13          DATETIME, 
        @dLottable14          DATETIME, 
        @dLottable15          DATETIME, 
        @cUserDefine01        NVARCHAR( 30), 
        @cUserDefine02        NVARCHAR( 30), 
        @cUserDefine03        NVARCHAR( 30), 
        @cUserDefine04        NVARCHAR( 30),
        @nNewLine             INT
        
      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN rdt_1581RcptCfm04

      SET @nNewLine = 0

      IF ISNULL( @cLottable01, '') = ''
      BEGIN
         SET @nErrNo = 115551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LOT01 Required
         GOTO RollBackTran
      END

      -- SKU not exists in ASN then get top 1 receiptdetail line to copy the details
      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                      WHERE ReceiptKey = @cReceiptKey
                      AND   SKU = @cSKUCode)
      BEGIN
         SET @nNewLine = 1

         SELECT TOP 1 
            @cExternReceiptKey = ExternReceiptKey,
            @cLottable02 = Lottable02, 
            @cLottable03 = Lottable03, 
            @dLottable04 = Lottable04, 
            @cLottable06 = Lottable06, 
            @cLottable07 = Lottable07, 
            @cLottable08 = Lottable08, 
            @cLottable09 = Lottable09, 
            @cLottable10 = Lottable10, 
            @cUserDefine01 = UserDefine01, 
            @cUserDefine02 = UserDefine02, 
            @cUserDefine03 = UserDefine03, 
            @cUserDefine04 = UserDefine04
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
         ORDER BY ReceiptLineNUmber
      END

      IF @nNewLine = 0
      BEGIN
         -- SKU+Grade not exists in ASN then get top 1 receiptdetail line to copy the details
         IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                     WHERE ReceiptKey = @cReceiptKey
                     AND   SKU = @cSKUCode
                     AND   Lottable01 = @cLottable01)
            SET @nNewLine = 2 

         SELECT TOP 1 
            @cExternReceiptKey = ExternReceiptKey,
            @cLottable02 = Lottable02, 
            @cLottable03 = Lottable03, 
            @dLottable04 = Lottable04, 
            @cLottable06 = Lottable06, 
            @cLottable07 = Lottable07, 
            @cLottable08 = Lottable08, 
            @cLottable09 = Lottable09, 
            @cLottable10 = Lottable10, 
            @cLottable11 = Lottable11, 
            @cLottable12 = Lottable12, 
            @dLottable13 = Lottable13, 
            @dLottable14 = Lottable14, 
            @dLottable15 = Lottable15, 
            @cUserDefine01 = UserDefine01, 
            @cUserDefine02 = UserDefine02, 
            @cUserDefine03 = UserDefine03, 
            @cUserDefine04 = UserDefine04
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
         ORDER BY ReceiptLineNUmber
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

      IF @nErrNo <> 0
         GOTO RollBackTran

      IF @nNewLine > 0
      BEGIN
         UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK) SET 
            ExternReceiptKey = @cExternReceiptKey,
            UserDefine01 = @cUserDefine01, 
            UserDefine02 = @cUserDefine02, 
            UserDefine03 = @cUserDefine03, 
            UserDefine04 = @cUserDefine04
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cReceiptLineNumber

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 115552
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD RDTL FAIL
            GOTO RollBackTran
         END
      END

   GOTO Quit

   RollBackTran:  
      ROLLBACK TRAN rdt_1581RcptCfm04 

   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  


GO
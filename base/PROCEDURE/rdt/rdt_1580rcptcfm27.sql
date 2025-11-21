SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580RcptCfm27                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: When insert new receiptdetail line, copy lottable & userdefine    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2023-01-04 1.0  James      WMS-21441. Created                              */
/* 2023-02-14 1.1  James      Bug fix (james01)                               */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1580RcptCfm27] (
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

   DECLARE @nCopyFromASNLine     INT,
           @cOri_Lottable01      NVARCHAR( 18),
           @cOri_Lottable02      NVARCHAR( 18),
           @cOri_Lottable03      NVARCHAR( 18),
           @dOri_Lottable04      DATETIME,
           @dOri_Lottable05      DATETIME,
           @cOri_Lottable06      NVARCHAR( 30),
           @cOri_Lottable07      NVARCHAR( 30),
           @cOri_Lottable08      NVARCHAR( 30),
           @cOri_Lottable09      NVARCHAR( 30),
           @cOri_Lottable10      NVARCHAR( 30), 
           @cOri_Lottable11      NVARCHAR( 30),
           @cOri_Lottable12      NVARCHAR( 30),
           @dOri_Lottable13      DATETIME,
           @dOri_Lottable14      DATETIME,
           @dOri_Lottable15      DATETIME,
           @cOri_Userdefine01    NVARCHAR( 30),
           @cOri_Userdefine02    NVARCHAR( 30),
           @cOri_Userdefine03    NVARCHAR( 30),
           @cOri_Userdefine04    NVARCHAR( 30),
           @cOri_Userdefine05    NVARCHAR( 30),
           @dOri_Userdefine06    DATETIME,
           @dOri_Userdefine07    DATETIME,
           @cOri_Userdefine08    NVARCHAR( 30),
           @cOri_Userdefine09    NVARCHAR( 30),
           @cOri_Userdefine10    NVARCHAR( 30),
           @cExternReceiptKey    NVARCHAR( 20),
           @cRecType             NVARCHAR( 10),
           @cDuplicatedFrom      NVARCHAR( 5)
           
   DECLARE @cNotFinalizeRD NVARCHAR(1)    
   SET @cNotFinalizeRD = rdt.RDTGetConfig( 0, 'RDT_NotFinalizeReceiptDetail', @cStorerKey)     
    
   IF @cNotFinalizeRD = '1'  -- 1=Not finalize   
   BEGIN   	
   	-- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1580RcptCfm27 -- For rollback or commit only our own transaction

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
         
      SELECT 
         @cDuplicatedFrom = DuplicateFrom
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey
      AND   ReceiptLineNumber = @cReceiptLineNumber

      -- No duplicatefrom stamped, try any line with same sku
      IF ISNULL( @cDuplicatedFrom, '') = ''
      BEGIN
         SELECT TOP 1 	
            @cDuplicatedFrom = ReceiptLineNumber
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber <> @cReceiptLineNumber -- exclude current received line
         AND   Sku = @cSKUCode
         ORDER BY 1
      END
      
      IF ISNULL( @cDuplicatedFrom, '') <> ''
      BEGIN
         -- Get original line values
         SELECT 
            @cOri_Lottable01 = Lottable01,
            @cOri_Lottable02 = Lottable02,
            @cOri_Lottable03 = Lottable03,
            @dOri_Lottable04 = Lottable04,
            @dOri_Lottable05 = Lottable05,
            @cOri_Lottable06 = Lottable06,
            @cOri_Lottable07 = Lottable07,
            @cOri_Lottable08 = Lottable08,
            @cOri_Lottable09 = Lottable09,
            @cOri_Lottable10 = Lottable10,
            @cOri_Lottable11 = Lottable11,
            @cOri_Lottable12 = Lottable12,
            @dOri_Lottable13 = Lottable13,
            @dOri_Lottable14 = Lottable14,
            @dOri_Lottable15 = Lottable15,
            @cOri_Userdefine01 = Userdefine01,
            @cOri_Userdefine02 = Userdefine02,
            @cOri_Userdefine03 = Userdefine03,
            @cOri_Userdefine04 = Userdefine04,
            @cOri_Userdefine05 = Userdefine05,
            @dOri_Userdefine06 = Userdefine06,
            @dOri_Userdefine07 = Userdefine07,
            @cOri_Userdefine08 = Userdefine08,
            @cOri_Userdefine09 = Userdefine09,
            @cOri_Userdefine10 = Userdefine10
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cDuplicatedFrom
      
         -- Update values to new lines
         UPDATE dbo.RECEIPTDETAIL SET
            Lottable01 = @cOri_Lottable01,
            Lottable02 = @cOri_Lottable02,
            Lottable03 = @cOri_Lottable03,
            Lottable04 = @dOri_Lottable04,
            Lottable05 = @dOri_Lottable05,
            Lottable06 = @cOri_Lottable06,
            Lottable07 = @cOri_Lottable07,
            Lottable08 = @cOri_Lottable08,
            Lottable09 = @cOri_Lottable09,
            Lottable10 = @cOri_Lottable10,
            Lottable11 = @cOri_Lottable11,
            Lottable12 = @cOri_Lottable12,
            Lottable13 = @dOri_Lottable13,
            Lottable14 = @dOri_Lottable14,
            Lottable15 = @dOri_Lottable15,
            Userdefine01 = @cOri_Userdefine01,
            Userdefine02 = @cOri_Userdefine02,
            Userdefine03 = @cOri_Userdefine03,
            Userdefine04 = @cOri_Userdefine04,
            Userdefine05 = @cOri_Userdefine05,
            Userdefine06 = @dOri_Userdefine06,
            Userdefine07 = @dOri_Userdefine07,
            Userdefine08 = @cOri_Userdefine08,
            Userdefine09 = @cOri_Userdefine09,
            Userdefine10 = @cOri_Userdefine10,
            --QtyExpected = 0,
            TrafficCop = NULL
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cReceiptLineNumber

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 195451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Unexpt SKU Err
            GOTO RollBackTran
         END
      END
      
      GOTO Quit
      
      RollBackTran:  
         ROLLBACK TRAN rdt_1580RcptCfm27 
      Quit:  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  
   END

   

GO
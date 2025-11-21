SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1581RcvCfm05                                          */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: One ToID 1 channel                                                */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 01-11-2018  Ung       1.0   WMS-6867 Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1581RcvCfm05] (
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
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1581RcvCfm05 -- For rollback or commit only our own transaction

   IF @nFunc = 1581 -- Piece receiving
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
         @cSubreasonCode = @cSubreasonCode, 
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT   
      IF @nErrNo <> 0
         GOTO RollBackTran

      IF @cToID <> ''
      BEGIN
         DECLARE @nRowCount INT
         DECLARE @cChannel NVARCHAR( 20)
         DECLARE @nChannel_ID BIGINT
         
         -- Get ID info
         SELECT 
            @cChannel = Channel, 
            @nChannel_ID = Channel_ID 
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND ToID = @cToID
            AND BeforeReceivedQTY > 0
            
         -- Check ID have other channel
         IF @@ROWCOUNT > 1
         BEGIN
            IF EXISTS( SELECT TOP 1 1
               FROM ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  AND ToID = @cToID
                  AND BeforeReceivedQTY > 0
                  AND (Channel <> @cChannel OR Channel_ID <> @nChannel_ID))
            BEGIN
               SET @nErrNo = 131401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Channel
               GOTO RollBackTran
            END
         END
      END
   END
   
   COMMIT TRAN rdt_1581RcvCfm05 -- Only commit change made in here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1581RcvCfm05
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
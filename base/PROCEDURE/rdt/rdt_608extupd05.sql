SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtUpd05                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Calc suggest location, booking                                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 07-Dec-2016  Ung       1.0   Copy from rdt_608ExtUpd01                     */
/*                              WMS-751 Remove booking                        */
/* 08-Sep-2022  Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtUpd05]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nAfterStep    INT,            
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15), 
   @cReceiptKey   NVARCHAR( 10), 
   @cPOKey        NVARCHAR( 10), 
   @cRefNo        NVARCHAR( 60), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
   @cMethod       NVARCHAR( 1), 
   @cSKU          NVARCHAR( 20), 
   @nQTY          INT,           
   @cLottable01   NVARCHAR( 18), 
   @cLottable02   NVARCHAR( 18), 
   @cLottable03   NVARCHAR( 18), 
   @dLottable04   DATETIME,      
   @dLottable05   DATETIME,      
   @cLottable06   NVARCHAR( 30), 
   @cLottable07   NVARCHAR( 30), 
   @cLottable08   NVARCHAR( 30), 
   @cLottable09   NVARCHAR( 30), 
   @cLottable10   NVARCHAR( 30), 
   @cLottable11   NVARCHAR( 30), 
   @cLottable12   NVARCHAR( 30), 
   @dLottable13   DATETIME,      
   @dLottable14   DATETIME,      
   @dLottable15   DATETIME, 
   @cRDLineNo     NVARCHAR( 5), 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess    INT
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 608 -- Piece return
   BEGIN  
      IF (@nStep = 4 AND @nInputKey = 1 AND @cMethod = '1') OR  -- lottable before method, received at SKU QTY screen 
         (@nStep = 5 AND @nInputKey = 1 AND @cMethod = '2')     -- lottable after  method, received at POST lottable screen
      BEGIN
         /*
            User turn on OverReceiptToMatchLine (it only match ID and lottables) to avoid initial split line due to 
            default ToLOC (interface/populate) is different from actual ToLOC 
         */
         IF EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ReceiptLineNumber = @cRDLineNo AND ToLOC <> @cLOC)
         BEGIN
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_608ExtUpd05 -- For rollback or commit only our own transaction
            
            UPDATE ReceiptDetail SET
               ToLOC = @cLOC
            WHERE ReceiptKey = @cReceiptKey
               AND ReceiptLineNumber = @cRDLineNo
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            
            COMMIT TRAN rdt_608ExtUpd05 -- Only commit change made here
         END
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_608ExtUpd05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

SET QUOTED_IDENTIFIER OFF

GO
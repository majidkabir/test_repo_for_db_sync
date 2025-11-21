SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_1580RcptCfm22                                      */  
/* Copyright      : LF Logistics                                           */  
/*                                                                         */  
/* Date       Rev  Author     Purposes                                     */  
/* 2020-03-24 1.0  Chermiane  WMS-16328 Created (dup rdt_1580RcptCfm11)    */  
/* 2022-09-21 1.1  Ung        WMS-19596 Add LocationGroup                  */
/*                            Fix reduct from closed pallet record         */
/***************************************************************************/  
CREATE   PROC [RDT].[rdt_1580RcptCfm22](  
   @nFunc          INT,  
   @nMobile        INT,  
   @cLangCode      NVARCHAR( 3),  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT,  
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
   @nNOPOFlag      INT,  
   @cConditionCode NVARCHAR( 10),  
   @cSubreasonCode NVARCHAR( 10),  
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT,  
   @cSerialNo      NVARCHAR( 30) = '',  
   @nSerialQTY     INT = 0,  
   @nBulkSNO       INT = 0,  
   @nBulkSNOQTY    INT = 0  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   -- Handling transaction  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_1580RcptCfm22 -- For rollback or commit only our own transaction  
  
   DECLARE @cLottable06    NVARCHAR( 30)  
          ,@cLottable07    NVARCHAR( 30)  
          ,@cLottable08    NVARCHAR( 30)  
          ,@cLottable09    NVARCHAR( 30)  
          ,@cLottable10    NVARCHAR( 30)  
          ,@cLottable11    NVARCHAR( 30)  
          ,@cLottable12    NVARCHAR( 30)  
          ,@dLottable13    DATETIME  
          ,@dLottable14    DATETIME  
          ,@dLottable15    DATETIME  
  
   -- Get ASN  
   SELECT TOP 1  
      --@cUCCPOKey = RD.POKey  
       @cLottable01 = RD.Lottable01  
      ,@cLottable02 = RD.Lottable02  
      --,@cLottable03 = RD.Lottable03  
      ,@dLottable04 = RD.Lottable04  
      --,@dLottable05 = RD.Lottable05  
      ,@cLottable06 = RD.Lottable06  
      ,@cLottable07 = RD.Lottable07  
      ,@cLottable08 = RD.Lottable08  
      ,@cLottable09 = RD.Lottable09  
      ,@cLottable10 = RD.Lottable10  
      ,@cLottable11 = 'H'--RD.Lottable11  
      ,@cLottable12 = RD.Lottable12  
      ,@dLottable13 = RD.Lottable13  
      ,@dLottable14 = RD.Lottable14  
      ,@dLottable15 = RD.Lottable15  
   FROM Receipt R WITH (NOLOCK)  
      JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)  
   WHERE R.StorerKey = @cStorerKey  
      AND R.Facility = @cFacility  
      AND RD.ReceiptKey = @cReceiptKey  
      AND RD.SKU = @cSKUCode  
      AND RD.DuplicateFrom IS NULL -- look for ori line  
   ORDER BY RD.ExternReceiptKey, RD.receiptlinenumber      
  
   EXEC rdt.rdt_Receive_v7  
      @nFunc          = @nFunc,  
      @nMobile        = @nMobile,  
      @cLangCode      = @cLangCode,  
      @nErrNo         = @nErrNo  OUTPUT,  
      @cErrMsg        = @cErrMsg OUTPUT,  
      @cStorerKey     = @cStorerKey,  
      @cFacility      = @cFacility,  
      @cReceiptKey    = @cReceiptKey,  
      @cPOKey         = @cPOKey,  
      @cToLOC         = @cToLOC,  
      @cToID          = @cToID,  
      @cSKUCode       = @cSKUCode,  
      @cSKUUOM        = @cSKUUOM,  
      @nSKUQTY        = @nSKUQTY,  
      @cUCC           = @cUCC,  
      @cUCCSKU        = @cUCCSKU,  
      @nUCCQTY        = @nUCCQTY,  
      @cCreateUCC     = @cCreateUCC,  
      @cLottable01    = @cLottable01,  
      @cLottable02    = @cLottable02,  
      @cLottable03    = @cLottable03,  
      @dLottable04    = @dLottable04,  
      @dLottable05    = @dLottable05,  
      @cLottable06    = @cLottable06,  
      @cLottable07    = @cLottable07,  
      @cLottable08    = @cLottable08,  
      @cLottable09    = @cLottable09,  
      @cLottable10    = @cLottable10,  
      @cLottable11    = @cLottable11,  
      @cLottable12    = @cLottable12,  
      @dLottable13    = @dLottable13,  
      @dLottable14    = @dLottable14,  
      @dLottable15    = @dLottable15,  
      @nNOPOFlag      = @nNOPOFlag,  
      @cConditionCode = @cConditionCode,  
      @cSubreasonCode = @cSubreasonCode,  
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT  
   IF @nErrNo <> 0  
      GOTO RollbackTran  
  
   -- ASN that need to print putaway label (1 piece 1 putaway label)  
   IF EXISTS( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ProcessType = 'N' AND UserDefine03 = '')  
   BEGIN  
      DECLARE @nRowCount      INT  
      DECLARE @cPABookingKey  NVARCHAR(20)  
      DECLARE @nFromRowRef    INT  
      DECLARE @nToRowRef      INT  
      DECLARE @cSuggestedLOC  NVARCHAR(10)  
      DECLARE @cLOT           NVARCHAR(10)  
      DECLARE @nOriginalQTY   INT  
  
      -- Get ReceiptDetail info  
      SELECT @cPABookingKey = UserDefine10  
      FROM  dbo.ReceiptDetail WITH (NOLOCK)  
      WHERE ReceiptKey = @cReceiptKey  
         AND ReceiptLineNumber = @cReceiptLineNumber  
  
      -- Get FROM RFPutaway  
      SELECT TOP 1  
         @nFromRowRef = RowRef,  
         @cSuggestedLOC = SuggestedLOC,  
         @cLOT = LOT,  
         @nOriginalQTY = QTY  
      FROM dbo.RFPutaway WITH (NOLOCK)  
         JOIN LOC WITH (NOLOCK) ON (RFPutaway.SuggestedLOC = LOC.LOC)  --zoe  
      WHERE PABookingKey = @cPABookingKey  
         AND StorerKey = @cStorerKey  
         AND SKU = @cSKUCode  
         AND FromLOC = @cToLOC  
         AND FromID = ''     -- Original Exceed booking, without pallet ID  
         AND QTY >= @nSKUQTY -- Still have balance  (yeekung)    
         AND CaseID <> 'Close Pallet'
      ORDER BY LOC.LocationGroup, RowRef     --zoe              
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 184501  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No booking  
         GOTO RollbackTran  
      END  
  
      -- Reduce FROM RFPutaway first (to minimize others getting its balance and also lock the record)  
      UPDATE dbo.RFPutaway SET  
         QTY = QTY - @nSKUQTY,  
         PTCID = SUSER_SNAME()  
      WHERE RowRef = @nFromRowRef --(yeekung)      
         AND QTY = @nOriginalQTY -- Make sure no others had changed it  
      SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT  
      IF @nErrNo <> 0 OR @nRowCount <> 1  
      BEGIN  
         SET @nErrNo = 184502  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RF Fail  
         GOTO RollbackTran  
      END  
  
      -- Get TO RFputaway  
      SELECT TOP 1  
         @nToRowRef = RowRef  
      FROM dbo.RFPutaway WITH (NOLOCK)  
         JOIN LOC WITH (NOLOCK) ON (RFPutaway.SuggestedLOC = LOC.LOC)  --zoe  
      WHERE PABookingKey = @cPABookingKey  
         AND StorerKey = @cStorerKey  
         AND SKU = @cSKUCode  
         AND LOT = @cLOT                   -- Same LOT  
         AND FromLOC = @cToLOC             -- Same LOC  
         AND FromID = @cToID               -- Same ID  
         AND SuggestedLOC = @cSuggestedLOC -- Going to same place  
         AND CaseID <> 'Close Pallet'
      ORDER BY LOC.LocationGroup, RowRef     --zoe          
  
      -- Increase TO RFputaway  
      IF @@ROWCOUNT = 0  
      BEGIN  
         -- No existing record to top up, create new record to contain it  
         INSERT INTO dbo.RFPutaway (  
            Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, PTCID, CaseID, TaskDetailKey, Func, PABookingKey,  
            QTY, QTYPrinted)  
         VALUES (  
            @cStorerkey, @cSKUCode, @cLOT, @cToLOC, @cToID, @cSuggestedLOC, @cToID, SUSER_SNAME(), '', '', @nFunc, @cPABookingKey,  
            @nSKUQTY, @nSKUQTY)  
         SELECT @nErrNo = @@ERROR, @nToRowRef = SCOPE_IDENTITY()  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 184503  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RF Fail  
            GOTO RollbackTran  
         END  
      END  
      ELSE  
      BEGIN  
         -- Top up TO RFPutaway  
         UPDATE dbo.RFPutaway SET  
            QTY = QTY + @nSKUQTY,  
            QTYPrinted = QTYPrinted + @nSKUQTY,  
            PTCID = SUSER_SNAME()  
         WHERE RowRef = @nToRowRef  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 184504  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RF Fail  
            GOTO RollbackTran  
         END  
      END  
  
      -- Reduce FROM LOTxLOCxID  
      UPDATE dbo.LOTxLOCxID SET  
         PendingMoveIn = PendingMoveIn - @nSKUQTY,  
         EditDate = GETDATE(),  
         EditWho = SUSER_SNAME()  
      WHERE LOT = @cLOT  
         AND LOC = @cSuggestedLOC --(yeekung01)      
         AND ID = ''  
         AND PendingMoveIn >= @nSKUQTY -- Just in case... (yeekung01)     
      SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT  
      IF @nErrNo <> 0 OR @nRowCount <> 1  
      BEGIN  
         SET @nErrNo = 184505  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail  
         GOTO RollbackTran  
      END  
  
      -- Increase TO LOTxLOCxID  
      IF EXISTS( SELECT 1  
         FROM dbo.LOTxLOCxID WITH (NOLOCK)  
         WHERE LOT = @cLOT  
            AND LOC = @cSuggestedLOC  
            AND ID = @cToID)  
      BEGIN  
         -- Top up TO LOTxLOCxID  
         UPDATE dbo.LOTxLOCxID SET  
            PendingMoveIn = PendingMoveIn + @nSKUQTY,  
            EditDate = GETDATE(),  
            EditWho = SUSER_SNAME()  
         WHERE LOT = @cLOT  
            AND LOC = @cSuggestedLOC  
            AND ID = @cToID  
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT  
         IF @nErrNo <> 0 OR @nRowCount <> 1  
         BEGIN  
            SET @nErrNo = 184506  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail  
            GOTO RollbackTran  
         END  
      END  
      ELSE  
      BEGIN  
         -- Check ID  
         IF NOT EXISTS( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cToID)  
         BEGIN  
            INSERT INTO ID (ID) VALUES (@cToID)  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 184507  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ID Fail  
               GOTO RollbackTran  
            END  
         END  
  
         -- No existing record to top up, create new record to contain it  
         INSERT into dbo.LOTxLOCxID (LOT, LOC, ID, SKU, StorerKey, PendingMoveIn)  
         VALUES (@cLOT, @cSuggestedLOC, @cToID, @cSKUCode, @cStorerKey, @nSKUQTY)  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 184508  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LLI Fail  
            GOTO RollbackTran  
         END  
      END 
   END  
  
   /*  
      Print SKULabel workaround.  
      Reason:  
         rdt_PieceReceiving_SKULabel still not yet have @cReceiptLineNumber param  
         It re-retrieve ReceiptLineNumber base on LOC, ID, SKU, Lottable1..4 in that SP  
         But for NIKE that returns many records, so it got the wrong receipt line number to print.  
      workaround:  
         Rename SKULABEL to SKULABEL01 (so PieceReceiving main SP won't pick it up)  
         Treat is as custom report to print  
   */  
   -- Get report info  
   DECLARE @cDataWindow NVARCHAR( 50)  
   DECLARE @cTargetDB   NVARCHAR( 20)  
   SELECT  
      @cDataWindow = DataWindow,  
      @cTargetDB = TargetDB  
   FROM RDT.RDTReport WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND ReportType = 'SKULABEL01'  
  
   -- Get session info  
   DECLARE @cPrinter NVARCHAR( 10)  
   SELECT @cPrinter = Printer  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
   -- Print  
   EXEC RDT.rdt_BuiltPrintJob  
      @nMobile,  
      @cStorerKey,  
      'SKULABEL01',     -- ReportType  
      'PRINT_SKULABEL', -- PrintJobName  
      @cDataWindow,  
      @cPrinter,  
      @cTargetDB,  
      @cLangCode,  
      @nErrNo  OUTPUT,  
      @cErrMsg OUTPUT,  
      @cReceiptKey,  
      @cReceiptLineNumber,  
      @nSKUQTY  

   SET @nErrNo = 0    
  
   COMMIT TRAN rdt_1580RcptCfm22  
   GOTO Quit  
  
RollbackTran:  
   ROLLBACK TRAN rdt_1580RcptCfm22  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO
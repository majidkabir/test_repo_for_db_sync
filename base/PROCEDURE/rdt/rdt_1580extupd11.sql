SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtUpd11                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Purpose: Finalize by ID                                                    */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 24-03-2021  1.1  Chermaine   WMS-16328 Created (dup rdt_1580ExtUpd09)      */
/******************************************************************************/
CREATE PROCEDURE [RDT].[rdt_1580ExtUpd11]
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

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      IF @nStep = 10 -- Close pallet
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cToID <> ''
            BEGIN
               DECLARE @bSuccess       INT
               DECLARE @cRD_LineNo     NVARCHAR(5)
               DECLARE @nQTY_Bal       INT
               DECLARE @nQTY_Book      INT

               DECLARE @cRD_LOT        NVARCHAR( 10)
               DECLARE @cRD_LOC        NVARCHAR( 10)
               DECLARE @cRD_ID         NVARCHAR( 18)
               DECLARE @cRD_SKU        NVARCHAR( 20)
               DECLARE @nRD_QTYExp     INT
               DECLARE @nRD_QTY        INT
               DECLARE @dRD_Lottable05 DATETIME
               DECLARE @cRD_SuggLOC    NVARCHAR(10)
               DECLARE @nRD_PABookingKey  INT
               
               DECLARE @nRowRef        INT
               DECLARE @nPABookingKey  INT
               DECLARE @cRF_LOT        NVARCHAR( 10)
               DECLARE @cRF_LOC        NVARCHAR( 10)
               DECLARE @cRF_ID         NVARCHAR( 18)
               DECLARE @nRF_QTY        INT
               DECLARE @cRF_SuggLOC    NVARCHAR(10)

               -- Handling transaction
               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdt_1580ExtUpd11 -- For rollback or commit only our own transaction

               -- Loop ReceiptDetail of pallet
               DECLARE @curRD CURSOR
               SET @curRD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT RD.ReceiptLineNumber, RD.ToLOC, RD.ToID, RD.SKU, RD.QTYExpected, RD.BeforeReceivedQTY, RD.UserDefine09, RD.UserDefine10, RD.Lottable05
                  FROM dbo.Receipt R WITH (NOLOCK)
                     JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
                  WHERE R.ReceiptKey = @cReceiptKey
                     AND RD.ToID = @cToID
                     AND RD.FinalizeFlag <> 'Y'
                     AND RD.BeforeReceivedQty > 0
                  ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber
               OPEN @curRD
               FETCH NEXT FROM @curRD INTO @cRD_LineNo, @cRD_LOC, @cRD_ID, @cRD_SKU, @nRD_QTYExp, @nRD_QTY, @cRD_SuggLOC, @nRD_PABookingKey, @dRD_Lottable05
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  IF @dRD_Lottable05 IS NOT NULL
                  BEGIN
                     -- Exceed L05 is different from today, need to overwrite
                     IF CAST( @dRD_Lottable05 AS DATE) <> CAST( GETDATE() AS DATE)
                     BEGIN
                        UPDATE dbo.ReceiptDetail SET
                           Lottable05 = CAST( GETDATE() AS DATE),
                           EditWho = SUSER_SNAME(),
                           EditDate = GETDATE(),
                           TrafficCop = NULL
                        WHERE ReceiptKey = @cReceiptKey
                           AND ReceiptLineNumber = @cRD_LineNo
                        SET @nErrNo = @@ERROR
                        IF @nErrNo <> 0
                        BEGIN
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                           GOTO RollbackTran
                        END
                     END
                  END

                  /*
                  Lose ID:
                     Operation is not using actual pallet ID. They use it for finalize "pallet", so putaway can be carry out earlier.  
                     Each piece received is stick with a putaway label (with suggested LOC printed)
                     Operator look at the suggested LOC, pre-sort it and drop into different tote box, representing different zone/aisle
                     The tote is then taken to pick faces, using FN513 move by SKU to putaway
                     Operator carry the FROM LOC barcode, scan SKU, scan suggested LOC. There is no pallet ID
                  */
                  
                  /* Exceed pre finalize ASN had taken over backup of pallet ID
                  UPDATE dbo.ReceiptDetail SET
                     ToID = '', 
                     ID = @cToID, -- Backup for easy checking data later
                     EditDate = GETDATE(), 
                     EditWho = SUSER_SNAME(), 
                     TrafficCop = NULL
                  WHERE ReceiptKey = @cReceiptKey
                     AND ReceiptLineNumber = @cRD_LineNo
                  SET @nErrNo = @@ERROR
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollbackTran
                  END
                  */
                  
                  -- Finalize by line
                  EXEC dbo.ispFinalizeReceipt
                      @c_ReceiptKey        = @cReceiptKey
                     ,@b_Success           = @bSuccess   OUTPUT
                     ,@n_err               = @nErrNo     OUTPUT
                     ,@c_ErrMsg            = @cErrMsg    OUTPUT
                     ,@c_ReceiptLineNumber = @cRD_LineNo
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FinalizeRDFail
                     GOTO RollBackTran
                  END

                  -- Get actual LOT
                  SELECT @cRD_LOT = LOT
                  FROM ITrn WITH (NOLOCK)
                  WHERE SourceKey = @cReceiptKey + @cRD_LineNo
                     AND TranType = 'DP'

                  -- Initial balance
                  SET @nQTY_Bal = @nRD_QTY 

                  -- Loop RFPutaway (one ReceiptDetail could match multiple RFPutaway, for putaway to different suggested LOC)
                  DECLARE @curRF CURSOR
                  SET @curRF = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                     SELECT RowRef, FromLOC, FromID, QTY, SuggestedLOC
                     FROM dbo.RFPutaway WITH (NOLOCK)
                     WHERE PABookingKey = @nRD_PABookingKey
                        AND FromID = @cToID
                        AND StorerKey = @cStorerKey
                        AND SKU = @cRD_SKU
                        AND CaseID <> 'Close Pallet'
                  OPEN @curRF
                  FETCH NEXT FROM @curRF INTO @nRowRef, @cRF_LOC, @cRF_ID, @nRF_QTY, @cRF_SuggLOC
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- RFPutaway has more, split line
                     IF @nRF_QTY > @nQTY_Bal 
                     BEGIN
                        -- Insert balance into new line
                        INSERT INTO dbo.RFPutaway (
                           Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, CaseID, TaskDetailKey, Func, PABookingKey, 
                           QTY, QTYPrinted)
                        SELECT 
                           Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, CaseID, TaskDetailKey, Func, PABookingKey, 
                           @nRF_QTY - @nQTY_Bal, @nRF_QTY - @nQTY_Bal
                        FROM dbo.RFPutaway WITH (NOLOCK)
                        WHERE RowRef = @nRowRef
                        SET @nErrNo = @@ERROR
                        IF @nErrNo <> 0
                        BEGIN
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                           GOTO RollbackTran
                        END

                        -- Reduce current balance
                        UPDATE dbo.RFPutaway SET
                           QTY = @nQTY_Bal, 
                           QTYPrinted = @nQTY_Bal
                        WHERE RowRef = @nRowRef
                        SET @nErrNo = @@ERROR
                        IF @nErrNo <> 0
                        BEGIN
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                           GOTO RollbackTran
                        END

                        SET @nQTY_Book = @nQTY_Bal
                     END
                     ELSE
                        SET @nQTY_Book = @nRF_QTY
                     
                     -- Exceed booking criteria (LOT, LOC, ID) and RDT actual receive is different, need to unbook and rebook
                     IF @cRD_LOC <> @cRF_LOC OR
                        @cRD_ID  <> @cRF_ID OR
                        @cRD_LOT <> @cRF_LOT
                     BEGIN
                        -- Unbook that line
                        EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
                           ,'' --FromLOC
                           ,'' --FromID
                           ,'' --SuggLOC
                           ,@cStorerKey    = @cStorerKey
                           ,@nErrNo        = @nErrNo  OUTPUT
                           ,@cErrMsg       = @cErrMsg OUTPUT
                           ,@nRowRef       = @nRowRef
                        IF @nErrNo <> 0
                           GOTO RollBackTran

                        -- Rebook as new line
                        SET @nPABookingKey = 0
                        EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'
                           ,@cFromLOC       = @cRD_LOC
                           ,@cFromID        = '' -- @cRD_ID. Had lose ID earlier
                           ,@cSuggestedLOC  = @cRF_SuggLOC
                           ,@cStorerKey     = @cStorerKey
                           ,@nErrNo         = @nErrNo  OUTPUT
                           ,@cErrMsg        = @cErrMsg OUTPUT
                           ,@cSKU           = @cRD_SKU
                           ,@nPutawayQTY    = @nQTY_Book
                           ,@nQTYPrinted    = @nQTY_Book
                           ,@cFromLOT       = @cRD_LOT
                           ,@nPABookingKey  = @nPABookingKey OUTPUT
                        IF @nErrNo <> 0 OR @nPABookingKey = 0
                           GOTO RollbackTran
                           
                        -- Point to new RF line
                        SET @nRowRef = @nPABookingKey
                     END

                     -- Mark RFPutaway as taken
                     UPDATE RFPutaway SET
                        PABookingKey = @nRD_PABookingKey, -- for rebook, stamp back original PABookingKey
                        CaseID = 'Close Pallet'
                     WHERE RowRef = @nRowRef
                     SET @nErrNo = @@ERROR
                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                        GOTO RollbackTran
                     END

                     -- Reduce balance
                     SET @nQTY_Bal = @nQTY_Bal - @nQTY_Book
                     IF @nQTY_Bal = 0
                        BREAK
                        
                     FETCH NEXT FROM @curRF INTO @nRowRef, @cRF_LOC, @cRF_ID, @nRF_QTY, @cRF_SuggLOC
                  END

                  FETCH NEXT FROM @curRD INTO @cRD_LineNo, @cRD_LOC, @cRD_ID, @cRD_SKU, @nRD_QTYExp, @nRD_QTY, @cRD_SuggLOC, @nRD_PABookingKey, @dRD_Lottable05
               END

               COMMIT TRAN rdt_1580ExtUpd11
               GOTO Quit
            END
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1580ExtUpd11 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
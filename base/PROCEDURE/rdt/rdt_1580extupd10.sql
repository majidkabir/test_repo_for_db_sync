SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtUpd10                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Purpose: Finalize by ID                                                    */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 06-05-2020  1.0  Ung         WMS-13066 Created                             */
/* 04-09-2020  1.1  Ung         LWP-79 Reduce deadlock                        */
/******************************************************************************/
CREATE PROCEDURE [RDT].[rdt_1580ExtUpd10]
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
               DECLARE @bSuccess INT
               DECLARE @cLOT     NVARCHAR( 10) 
               DECLARE @cUDF09   NVARCHAR( 10) 
               DECLARE @cRDSKU   NVARCHAR( 20) 
               DECLARE @cReceiptLineNumber NVARCHAR(5)
               DECLARE @nPABookingKey INT

               -- Handling transaction
               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdt_1580ExtUpd10 -- For rollback or commit only our own transaction

               -- Loop ReceiptDetail of pallet
               DECLARE @curRD CURSOR
               SET @curRD = CURSOR FOR 
                  SELECT RD.ReceiptLineNumber, RD.SKU, RD.UserDefine09
                  FROM dbo.Receipt R WITH (NOLOCK) 
                     JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
                  WHERE R.ReceiptKey = @cReceiptKey 
                     AND RD.ToID = @cToID 
                     AND RD.FinalizeFlag <> 'Y'
                     AND RD.BeforeReceivedQty > 0 
                  -- ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber
                  ORDER BY RD.StorerKey, RD.SKU -- Reduce deadlock
               OPEN @curRD
               FETCH NEXT FROM @curRD INTO @cReceiptLineNumber, @cRDSKU, @cUDF09
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  EXEC dbo.ispFinalizeReceipt    
                      @c_ReceiptKey        = @cReceiptKey    
                     ,@b_Success           = @bSuccess  OUTPUT    
                     ,@n_err               = @nErrNo     OUTPUT    
                     ,@c_ErrMsg            = @cErrMsg    OUTPUT    
                     ,@c_ReceiptLineNumber = @cReceiptLineNumber    
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FinalizeRDFail
                     GOTO RollBackTran
                  END
                  
                  -- Get LOT
                  SELECT 
                     @cLOT = LOT, 
                     @cToLOC = ToLOC, 
                     @nQTY = QTY
                  FROM ITrn WITH (NOLOCK) 
                  WHERE SourceKey = @cReceiptKey + @cReceiptLineNumber
                     AND TranType = 'DP'
                  
                  -- Suggest LOC
                  IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cUDF09)
                  BEGIN
                     SET @nPABookingKey = 0
                     EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'
                        ,@cFromLOC       = @cToLOC
                        ,@cFromID        = @cToID
                        ,@cSuggestedLOC  = @cUDF09
                        ,@cStorerKey     = @cStorerKey
                        ,@nErrNo         = @nErrNo  OUTPUT
                        ,@cErrMsg        = @cErrMsg OUTPUT
                        ,@cSKU           = @cRDSKU
                        ,@nPutawayQTY    = @nQTY
                        ,@cFromLOT       = @cLOT
                        ,@cTaskDetailKey = 'FORLOSEID'
                        ,@nPABookingKey  = @nPABookingKey OUTPUT
                     IF @nErrNo <> 0
                        GOTO RollbackTran
                        
                     IF @nPABookingKey > 0
                     BEGIN
                        -- Get LOC info
                        DECLARE @cFromLOCLoseID NVARCHAR(1)
                        SELECT @cFromLOCLoseID = LoseID FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
                        
                        /*
                           FromID need to manually lose ID, if FromLOC is lose ID. 
                           Itrn deposit does not lose ID. It rely on a backend scheduler runs every min calling isp_LostID to do that.
                           
                           QTYPrinted need to update as SKU label was printed earlier in step 5 
                           It is check in next step, move by SKU (for putaway), only allow move if QTYPrinted > 0
                        */
                        UPDATE RFPutaway SET
                           FromID = CASE WHEN @cFromLOCLoseID = '1' THEN '' ELSE FromID END, 
                           QTYPrinted = QTY
                        WHERE PABookingKey = @nPABookingKey
                        SET @nErrNo = @@ERROR 
                        IF @nErrNo <> 0
                        BEGIN
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                           GOTO RollbackTran
                        END
                     END
                  END
                  
                  FETCH NEXT FROM @curRD INTO  @cReceiptLineNumber, @cRDSKU, @cUDF09
               END
               
               COMMIT TRAN rdt_1580ExtUpd10
               GOTO Quit
            END
         END
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_1580ExtUpd10 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
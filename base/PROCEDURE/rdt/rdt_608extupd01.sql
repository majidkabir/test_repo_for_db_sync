SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtUpd01                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Calc suggest location, booking                                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 25-Sep-2015  Ung       1.0   SOS352968 Created                             */
/* 23-Feb-2016  Ung       1.1   SOS364101 Fix lot not created                 */
/* 08-Sep-2022  Ung       1.2   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtUpd01]
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
            UPDATE ReceiptDetail SET
               ToLOC = @cLOC
            WHERE ReceiptKey = @cReceiptKey
               AND ReceiptLineNumber = @cRDLineNo
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Quit
            END
         END
         
         /*
            L10 is return stock grade:
               A = A grade
               B = B grade
               C = C grade
               D = D grade
         */
         IF @cLottable10 = 'A'
         BEGIN
            -- Get Signatory
            DECLARE @cSignatory NVARCHAR( 18)
            SELECT @cSignatory = Signatory FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
            
            IF @cSignatory = '10' OR
               @cSignatory = '20' OR
               @cSignatory = '30' 
            BEGIN
               
               /*-------------------------------------------------------------------------------
               
                                               Find suggested location
            
               -------------------------------------------------------------------------------*/
               DECLARE @cSuggToLOC NVARCHAR( 10)
               DECLARE @cSuggToID  NVARCHAR( 18)
               DECLARE @tPutawayZone TABLE
               (
                  PAZoneSeq   INT           NOT NULL IDENTITY( 1, 1), 
                  PutawayZone NVARCHAR( 10) NOT NULL
               )
   
               -- Zone in particular sequence
               INSERT INTO @tPutawayZone ( PutawayZone) VALUES ( 'MEZ2_BASKT')
               INSERT INTO @tPutawayZone ( PutawayZone) VALUES ( 'MEZ2_750')
               INSERT INTO @tPutawayZone ( PutawayZone) VALUES ( 'GF2_1500')
   
               SET @cSuggToLOC = ''
               SET @cSuggToID = ''
               
               -- Find same SKU
               IF @cSignatory = '10' 
                  SELECT TOP 1
                     @cSuggToLOC = SL.LOC
                  FROM SKUxLOC SL WITH (NOLOCK)
                     JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
                     JOIN @tPutawayZone t ON (LOC.PutawayZone = t.PutawayZone)
                  WHERE SL.StorerKey = @cStorerKey
                     AND SL.SKU = @cSKU
                     AND (SL.QTY - SL.QTYPicked) > 0
                  ORDER BY 
                     t.PAZoneSeq, 
                     SL.QTY - SL.QTYPicked, 
                     LOC.LOC
   
               -- Find same material
               IF @cSuggToLOC = ''
                  SELECT TOP 1
                     @cSuggToLOC = SL.LOC
                  FROM SKUxLOC SL WITH (NOLOCK)
                     JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
                     JOIN @tPutawayZone t ON (LOC.PutawayZone = t.PutawayZone)
                  WHERE SL.StorerKey = @cStorerKey
                     AND SUBSTRING( SL.SKU, 1, 9) = SUBSTRING( @cSKU, 1, 9)
                     AND (SL.QTY - SL.QTYPicked) > 0
                  ORDER BY 
                     t.PAZoneSeq,
                     SL.QTY - SL.QTYPicked, 
                     LOC.LOC

               /*-------------------------------------------------------------------------------
               
                                          Create LOT if not yet receive
            
               -------------------------------------------------------------------------------*/
               IF @cSuggToLOC <> ''
               BEGIN
                  -- Handling transaction
                  SET @nTranCount = @@TRANCOUNT
                  BEGIN TRAN  -- Begin our own transaction
                  SAVE TRAN rdt_608ExtUpd01 -- For rollback or commit only our own transaction
                  
                  -- Stamp receiving date (to get LOT in below)
                  IF ISNULL( @dLottable05, 0) = 0
                  BEGIN
                     -- NULL and 1900-01-01 generate different LOT, use NULL
                     SET @dLottable05 = NULL
                     
                     -- Get SKU info
                     IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND Lottable05Label = 'RCP_DATE')
                     BEGIN
                        SET @dLottable05 = CAST( CONVERT( NVARCHAR( 10), GETDATE(), 120) AS DATETIME)
                        UPDATE ReceiptDetail SET
                           Lottable05 = @dLottable05
                        WHERE ReceiptKey = @cReceiptKey
                           AND ReceiptLineNumber = @cRDLineNo
                        SET @nErrNo = @@ERROR
                        IF @nErrNo <> 0
                        BEGIN
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                           GOTO RollbackTran
                        END
                     END
                  END
                  
                  -- LOT lookup
                  DECLARE @cLOT NVARCHAR( 10)
                  SET @cLOT = ''
                  EXECUTE dbo.nsp_LotLookUp @cStorerKey, @cSKU
                    , @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05
                    , @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10
                    , @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
                    , @cLOT      OUTPUT
                    , @bSuccess  OUTPUT
                    , @nErrNo    OUTPUT
                    , @cErrMsg   OUTPUT
            
                  -- Create LOT if not exist
                  IF @cLOT IS NULL
                  BEGIN
                     EXECUTE dbo.nsp_LotGen @cStorerKey, @cSKU
                        , @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05
                        , @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10
                        , @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
                        , @cLOT     OUTPUT
                        , @bSuccess OUTPUT
                        , @nErrNo   OUTPUT
                        , @cErrMsg  OUTPUT
                     IF @bSuccess <> 1
                        GOTO RollbackTran
                  END

                  -- Recreate LOT record (LOT record is purged when QTY=0, but LOTAttribute exists)
                  IF NOT EXISTS( SELECT 1 FROM LOT (NOLOCK) WHERE LOT = @cLOT)
                  BEGIN
                     INSERT INTO LOT (LOT, StorerKey, SKU) VALUES (@cLOT, @cStorerKey, @cSKU)
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 56901
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOT Fail
                        GOTO RollbackTran
                     END
                  END
            
                  -- Create ToID if not exist
                  IF @cID <> ''
                  BEGIN
                     IF NOT EXISTS( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cID)
                     BEGIN
                        INSERT INTO ID (ID) VALUES (@cID)
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 56902
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ID Fail
                           GOTO RollbackTran
                        END
                     END
                  END
         
         
                  /*-------------------------------------------------------------------------------
                  
                                                Book suggested location
               
                  -------------------------------------------------------------------------------*/
                  -- Location conversion
                  -- NIKE return process is after receive, need to get approval then only finalize. 
                  -- NIKE return interface is trigger from transfer and to location need to be 8STAGE
                  -- Receiving LOC changed to 8STAGE, but LOT and ID remain no change. 
                  -- So booking had to be from 8STAGE (after transferred LOC), to final LOC
                  IF @cLottable10 = 'A'
                     SET @cLOC = '8STAGE'
                  
                  SET @cSuggToID = @cID
                  
                  -- Book location in RFPutaway
                  IF EXISTS( SELECT TOP 1 1 
                     FROM RFPutaway WITH (NOLOCK) 
                     WHERE LOT = @cLOT
                        AND FromLOC = @cLOC
                        AND FromID = @cID
                        AND SuggestedLOC = @cSuggToLOC
                        AND ID = @cSuggToID)
                  BEGIN
                     UPDATE RFPutaway SET
                        QTY = QTY + @nQTY
                     WHERE LOT = @cLOT
                        AND FromLOC = @cLOC
                        AND FromID = @cID
                        AND SuggestedLOC = @cSuggToLOC
                        AND ID = @cSuggToID
                     SET @nErrNo = @@ERROR
                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                        GOTO RollbackTran
                     END
                  END
                  ELSE
                  BEGIN
                     -- Update RFPutaway
                     INSERT INTO RFPutaway (Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, QTY, CaseID)
                     VALUES (@cStorerKey, @cSKU, @cLOT, @cLOC, @cID, @cSuggToLOC, @cSuggToID, SUSER_SNAME(), @nQTY, '')
                     SET @nErrNo = @@ERROR
                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                        GOTO RollbackTran
                     END
                  END
                     
                  -- Book location in LOTxLOCxID
                  IF EXISTS (SELECT 1 
                     FROM dbo.LOTxLOCxID WITH (NOLOCK)
                     WHERE LOT = @cLOT
                        AND LOC = @cSuggToLOC
                        AND ID = @cSuggToID)
                  BEGIN
                     UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET 
                        PendingMoveIn = CASE WHEN PendingMoveIn >= 0 THEN PendingMoveIn + @nQTY ELSE 0 END
                     WHERE LOT = @cLOT
                        AND LOC = @cSuggToLOC
                        AND ID  = @cSuggToID
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 56903
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
                        GOTO RollbackTran
                     END
                  END
                  ELSE
                  BEGIN
                     INSERT dbo.LOTxLOCxID (LOT, LOC, ID, Storerkey, SKU, PendingMoveIn)
                     VALUES (@cLOT, @cSuggToLOC, @cSuggToID, @cStorerKey, @cSKU, @nQTY)
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 56904
                        SET @cErrMsg = @cSuggToLOC -- rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LLI Fail
                        GOTO RollbackTran
                     END
                  END
                  
                  COMMIT TRAN rdt_608ExtUpd01
               END
            END
         END
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_608ExtUpd01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

SET QUOTED_IDENTIFIER OFF

GO
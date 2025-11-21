SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CPVAdjustment_Alloc                             */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 03-10-2018 1.0  Ung       WMS-6149 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_CPVAdjustment_Alloc] (
   @cStorerKey  NVARCHAR(15)
) AS                                   
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_err             INT = 0
   DECLARE @c_ErrMsg          NVARCHAR (255) = ''
                              
   DECLARE @nTranCount        INT
   DECLARE @nRowRef           INT
   DECLARE @cADJKey           NVARCHAR(10)
   DECLARE @cADJLineNo        NVARCHAR(5)
   DECLARE @cNewADJLineNo     NVARCHAR(10)
   DECLARE @cParentSKU        NVARCHAR(20)
   DECLARE @cLottable07       NVARCHAR(30)
   DECLARE @cLottable08       NVARCHAR(30)
   DECLARE @cLOT              NVARCHAR(10)
   DECLARE @cLOC              NVARCHAR(10)
   DECLARE @cID               NVARCHAR(18)
   DECLARE @cMasterLOT        NVARCHAR(60)
   DECLARE @dExternLottable04 DATETIME
   DECLARE @nQTY_ADJ          INT
   DECLARE @nQTY_LLI          INT
   DECLARE @curDTL CURSOR
   DECLARE @curADJ CURSOR

   -- Loop Adjustment
   SET @curADJ = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT AdjustmentKey
      FROM Adjustment WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND FinalizedFlag = 'N' -- Open
         AND UserDefine10 = 'PENDALLOC'
      ORDER BY AdjustmentKey
   OPEN @curADJ 
   FETCH NEXT FROM @curADJ INTO @cADJKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_Alloc -- For rollback or commit only our own transaction

      -- Get parent SKU
      SELECT TOP 1 
         @cParentSKU = SKU
      FROM AdjustmentDetail WITH (NOLOCK)
      WHERE AdjustmentKey = @cADJKey
         AND StorerKey = @cStorerKey
      ORDER BY AdjustmentLineNumber

      -- Loop AdjustmentDetail
      SET @curDTL = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT AdjustmentLineNumber, ABS( QTY), Lottable07, Lottable08
         FROM AdjustmentDetail WITH (NOLOCK)
         WHERE AdjustmentKey = @cADJKey
            AND StorerKey = @cStorerKey
            AND SKU = @cParentSKU
            AND LOT = ''
         ORDER BY AdjustmentLineNumber
      OPEN @curDTL 
      FETCH NEXT FROM @curDTL INTO @cADJLineNo, @nQTY_ADJ, @cLottable07, @cLottable08
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get extern expiry date
         SET @cMasterLOT = @cLottable07 + @cLottable08
         SELECT @dExternLottable04 = ExternLottable04
         FROM ExternLotAttribute WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cParentSKU
            AND ExternLOT = @cMasterLOT
         
         -- Find stock
         WHILE @nQTY_ADJ > 0
         BEGIN
            -- Get available stock
            SELECT TOP 1 
               @cLOT = LLI.LOT, 
               @cLOC = LLI.LOC,  
               @cID  = LLI.ID, 
               @nQTY_LLI = LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QTYReplen
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @cStorerKey
               AND LLI.SKU = @cParentSKU
               AND LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QTYReplen > 0
               AND LA.Lottable04 = @dExternLottable04
               AND LA.Lottable07 = @cLottable07
               AND LA.Lottable08 = @cLottable08
               AND LOC.LocationFlag <> 'HOLD'

            IF @@ROWCOUNT = 0
            BEGIN
               SET @n_err = 127303
               SET @c_ErrMsg = 'NO stock'
               GOTO RollbackTran
            END  

            -- Adj is exact match or less
            IF @nQTY_ADJ <= @nQTY_LLI
            BEGIN
               UPDATE AdjustmentDetail SET
                  LOT = @cLOT, 
                  LOC = @cLOC, 
                  ID = @cID, 
                  Lottable04 = @dExternLottable04, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE AdjustmentKey = @cADJKey
                  AND AdjustmentLineNumber = @cADJLineNo
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Err = 127303
                  SET @c_ErrMsg = 'UPD ADJ Fail'
                  GOTO RollbackTran
               END
               
               -- Book the stock
               UPDATE LOTxLOCxID SET
                  QTYReplen = QTYReplen + @nQTY_ADJ, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Err = 127303
                  SET @c_ErrMsg = 'UPD LLI Fail'
                  GOTO RollbackTran
               END
               
               SET @nQTY_ADJ = 0
            END
            
            -- Adj have more
            ELSE IF @nQTY_ADJ > @nQTY_LLI
            BEGIN
               -- Get new AdjustmentLineNumber
               SELECT @cNewADJLineNo = RIGHT( '00000' + CAST( CAST( MAX( AdjustmentLineNumber) AS INT) + 1 AS NVARCHAR(5)), 5)
               FROM AdjustmentDetail WITH (NOLOCK)
               WHERE AdjustmentKey = @cADJKey
               
               -- Split new AdjustmentDetail to hold the balance
               INSERT INTO AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber, StorerKey, SKU, LOC, LOT, ID, ReasonCode, UOM, PackKey, Lottable07, Lottable08, QTY)
               SELECT AdjustmentKey, @cNewADJLineNo, StorerKey, SKU, LOC, LOT, ID, ReasonCode, UOM, PackKey, Lottable07, Lottable08, -(@nQTY_ADJ - @nQTY_LLI)
               FROM AdjustmentDetail WITH (NOLOCK)
               WHERE AdjustmentKey = @cADJKey
                  AND AdjustmentLineNumber = @cADJLineNo
               IF @@ERROR = 0
               BEGIN
                  SET @n_Err = 127303
                  SET @c_ErrMsg = 'UPD ADJ Fail'
                  GOTO RollbackTran
               END
               
               -- Reduce original
               UPDATE AdjustmentDetail SET
                  QTY = -@nQTY_LLI, 
                  Lottable04 = @dExternLottable04, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE AdjustmentKey = @cADJKey
                  AND AdjustmentLineNumber = @cADJLineNo
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Err = 127303
                  SET @c_ErrMsg = 'UPD ADJ Fail'
                  GOTO RollbackTran
               END

               SET @nQTY_ADJ = @nQTY_ADJ - @nQTY_LLI
            END
         END
         
         -- Update child expiry date
         SET @cADJLineNo = ''
         SELECT @cADJLineNo = AdjustmentLineNumber
         FROM AdjustmentDetail WITH (NOLOCK)
         WHERE AdjustmentKey = @cADJKey
            AND Lottable10 = @cLottable07
            AND Lottable11 = @cLottable08
            AND Lottable04 IS NULL
         IF @cADJLineNo <> ''
         BEGIN
            UPDATE AdjustmentDetail SET
               Lottable04 = @dExternLottable04, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               TrafficCop = NULL
            WHERE AdjustmentKey = @cADJKey
               AND AdjustmentLineNumber = @cADJLineNo
            IF @@ERROR <> 0
               GOTO RollbackTran
         END
         
         FETCH NEXT FROM @curDTL INTO @cADJLineNo, @nQTY_ADJ, @cLottable07, @cLottable08
      END

      -- Check adjustment allocated
      IF NOT EXISTS( SELECT TOP 1 1
         FROM AdjustmentDetail WITH (NOLOCK)
         WHERE AdjustmentKey = @cADJKey
            AND SKU = @cParentSKU
            AND LOT = '') 
      BEGIN
         -- Finalize adjustment
         UPDATE Adjustment SET 
            -- FinalizedFlag = 'Y', 
            UserDefine10 = '',  
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE() 
         WHERE AdjustmentKey = @cADJKey
         IF @@ERROR <> 0
            GOTO RollbackTran
      END
      
      COMMIT TRAN rdt_Alloc
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
      
      FETCH NEXT FROM @curADJ INTO @cADJKey
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Alloc -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

select @n_err '@n_err', @c_ErrMsg '@c_ErrMsg'
END

GO
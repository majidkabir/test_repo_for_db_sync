SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CPVKit_Alloc                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 02-08-2018 1.0  Ung       WMS-5380 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_CPVKit_Alloc] (
   @cStorerKey  NVARCHAR(15)
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_success         INT = 0
   DECLARE @n_err             INT = 0
   DECLARE @c_ErrMsg          NVARCHAR (255) = ''
                              
   DECLARE @nRowRef           INT
   DECLARE @nTranCount        INT

   DECLARE @cKitKey           NVARCHAR(10)
   DECLARE @cKitLineNumber    NVARCHAR(5)
   DECLARE @cNewKitLineNumber NVARCHAR(5)
   DECLARE @cSKU              NVARCHAR(20)
   DECLARE @cPackKey          NVARCHAR(10)
   DECLARE @cUOM              NVARCHAR(10)
   DECLARE @cLottable07       NVARCHAR(30)
   DECLARE @cLottable08       NVARCHAR(30)
   DECLARE @cLOT              NVARCHAR(10)
   DECLARE @cLOC              NVARCHAR(10)
   DECLARE @cID               NVARCHAR(18)
   DECLARE @nQTY_KD           INT
   DECLARE @nQTY_LLI          INT
   DECLARE @curLog CURSOR
   DECLARE @curKD  CURSOR
   DECLARE @curKit CURSOR

   -- Loop kit
   SET @curKit = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT KitKey
      FROM Kit WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND Status = '0' -- Open
         AND USRDEF3 IN ('PENDALLOC')
      ORDER BY KitKey
   OPEN @curKit 
   FETCH NEXT FROM @curKit INTO @cKitKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdt_CPVKit_Alloc
      
      -- Loop KitDetail (stamp LOT)
      SET @curKD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT KitLineNumber, SKU, QTY, PackKey, UOM, Lottable07, Lottable08
         FROM KitDetail WITH (NOLOCK)
         WHERE KitKey = @cKitKey
            AND Type = 'F' -- Child
            AND LOT = ''
         ORDER BY KitLineNumber
      OPEN @curKD 
      FETCH NEXT FROM @curKD INTO @cKitLineNumber, @cSKU, @nQTY_KD, @cPackKey, @cUOM, @cLottable07, @cLottable08
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Find stock
         WHILE @nQTY_KD > 0
         BEGIN
            -- Get available stock
            SELECT TOP 1 
               @cLOT = LLI.LOT, 
               @cLOC = LLI.LOC, 
               @cID = LLI.ID, 
               @nQTY_LLI = LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QTYReplen
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @cStorerKey
               AND LLI.SKU = @cSKU
               AND LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QTYReplen > 0
               AND LA.Lottable07 = @cLottable07
               AND LA.Lottable08 = @cLottable08
               AND LOC.LocationFlag <> 'HOLD'
            
            IF @@ROWCOUNT = 0
            BEGIN
               SET @n_err = 127303
               SET @c_ErrMsg = 'NO stock'
               GOTO RollbackTran
            END               

            -- Kit is exact match or less
            IF @nQTY_KD <= @nQTY_LLI
            BEGIN
               UPDATE KitDetail SET
                  LOT = @cLOT, 
                  LOC = @cLOC, 
                  ID = @cID, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE KitKey = @cKitKey
                  AND KitLineNumber = @cKitLineNumber
                  AND Type = 'F' -- Child
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Err = 127303
                  SET @c_ErrMsg = 'UPD LLI Fail'
                  GOTO RollbackTran
               END
               
               -- Book the stock
               UPDATE LOTxLOCxID SET
                  QTYReplen = QTYReplen + @nQTY_KD, 
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
               
               SET @nQTY_KD = 0
            END

            -- Kit have more
            IF @nQTY_KD > @nQTY_LLI
            BEGIN
               -- Get new KitLineNumber
               SELECT @cNewKitLineNumber = RIGHT( '00000' + CAST( CAST( MAX( KitLineNumber) AS INT) + 1 AS NVARCHAR(5)), 5)
               FROM KitDetail WITH (NOLOCK)
               WHERE KitKey = @cKitKey
                  AND Type = 'F' -- Child
               
               -- Split new KitDetail to hold the balance
               INSERT INTO KitDetail (KitKey, KitLineNumber, Type, StorerKey, SKU, PackKey, UOM, Lottable07, Lottable08, ExpectedQTY, QTY)
               SELECT KitKey, @cNewKitLineNumber, Type, StorerKey, SKU, PackKey, UOM, Lottable07, Lottable08, 
                  ExpectedQTY - @nQTY_LLI, 
                  QTY - @nQTY_LLI
               FROM KitDetail WITH (NOLOCK)
               WHERE KitKey = @cKitKey
                  AND KitLineNumber = @cKitLineNumber
               IF @@ERROR = 0
               BEGIN
                  SET @n_Err = 127303
                  SET @c_ErrMsg = 'UPD LLI Fail'
                  GOTO RollbackTran
               END
               
               -- Reduce original
               UPDATE KitDetail SET
                  ExpectedQTY = @nQTY_LLI, 
                  QTY = @nQTY_LLI, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE KitKey = @cKitKey
                  AND KitLineNumber = @cKitLineNumber
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Err = 127303
                  SET @c_ErrMsg = 'UPD LLI Fail'
                  GOTO RollbackTran
               END

               SET @nQTY_KD = @nQTY_KD - @nQTY_LLI
            END
         END

         FETCH NEXT FROM @curKD INTO @cKitLineNumber, @cSKU, @nQTY_KD, @cPackKey, @cUOM, @cLottable07, @cLottable08
      END
/*
      -- Loop KitDetail (ship)
      SET @curKD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT KitLineNumber
         FROM KitDetail WITH (NOLOCK)
         WHERE KitKey = @cKitKey
            AND Status <> '9'
            AND LOT <> ''
      OPEN @curKD 
      FETCH NEXT FROM @curKD INTO @cKitLineNumber
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE KitDetail SET
            Status = '9', 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE KitKey = @cKitKey
            AND KitLineNumber = @cKitLineNumber
         IF @@ERROR <> 0
         BEGIN
            SET @n_Err = 127303
            SET @c_ErrMsg = 'NO stock'
            GOTO RollbackTran
         END
         FETCH NEXT FROM @curKD INTO @cKitLineNumber
      END
*/
      -- Reset flag
      UPDATE Kit SET 
         USRDEF3 = '',  
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE() 
      WHERE KitKey = @cKitKey

      COMMIT TRAN rdt_CPVKit_Alloc
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN
      
      FETCH NEXT FROM @curKit INTO @cKitKey
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_CPVKit_Alloc -- Only rollback change made here
   SELECT @c_ErrMsg '@c_ErrMsg', @cKitLineNumber '@cKitLineNumber', @cSKU '@cSKU'

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

   IF @c_ErrMsg <> ''
      UPDATE KIT SET
         Remarks = 'KitLineNumber=' + @cKitLineNumber + '. ErrMsg=' + @c_ErrMsg, 
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE()
      WHERE KitKey = @cKitKey
END

GO
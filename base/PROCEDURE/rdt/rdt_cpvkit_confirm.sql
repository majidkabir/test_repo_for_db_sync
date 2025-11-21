SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_CPVKit_Confirm                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-07-31 1.0  Ung      WMS-5380 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_CPVKit_Confirm] (
   @nMobile           INT,           
   @nFunc             INT,           
   @cLangCode         NVARCHAR( 3),  
   @nStep             INT,           
   @nInputKey         INT,           
   @cFacility         NVARCHAR( 5),   
   @cStorerKey        NVARCHAR( 15), 
   @cType             NVARCHAR( 10), --PARENT/CHILD/PARENTSNO 
   @cKitKey           NVARCHAR( 10), 
   @cParentSKU        NVARCHAR( 20) = '', 
   @nParentInner      INT           = 0, 
   @cParentSNO        NVARCHAR( 60) = '', 
   @cChildSKU         NVARCHAR( 20) = '', 
   @nChildInner       INT           = 0, 
   @cChildSNO         NVARCHAR( 60) = '', 
   @cLottable07       NVARCHAR( 30) = '',
   @cLottable08       NVARCHAR( 30) = '',
   @nQTY              INT           = 1, 
   @nErrNo            INT           = 0  OUTPUT,
   @cErrMsg           NVARCHAR( 20) = '' OUTPUT, 
   @cDebug            NVARCHAR( 1)  = ''
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount    INT
   DECLARE @nRowRef       INT
   DECLARE @nExpectedQTY  INT

   SET @nTranCount = @@TRANCOUNT
   
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_CPVKit_Confirm -- For rollback or commit only our own transaction

   -- Populate parent and child, from KitDetail
   IF @cType = 'PARENT'
   BEGIN
      -- Get parent info
      DECLARE @nParentTotal INT
      SELECT @nParentTotal = SUM( ExpectedQTY)
      FROM KitDetail WITH (NOLOCK) 
      WHERE KitKey = @cKitKey
         AND Type = 'T' -- Parent

      IF @nParentInner > 0
         SET @nQTY = @nQTY * @nParentInner 

      -- Parent
      INSERT INTO rdt.rdtCPVKitLog (Mobile, KitKey, Type, StorerKey, SKU, ExpectedQTY, QTY, Barcode)
      SELECT @nMobile, KitKey, Type, StorerKey, SKU, @nQTY, 0, ''
      FROM KitDetail WITH (NOLOCK) 
      WHERE KitKey = @cKitKey
         AND Type = 'T' -- Parent
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 127801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
         GOTO RollbackTran
      END

      -- Child
      INSERT INTO rdt.rdtCPVKitLog (Mobile, KitKey, Type, StorerKey, SKU, ExpectedQTY, QTY, Barcode)
      SELECT @nMobile, KD.KitKey, KD.Type, KD.StorerKey, KD.SKU, 
         CEILING( KD.ExpectedQTY * ( @nQTY * 1.0 / @nParentTotal)), 0, ''
      FROM KitDetail KD WITH (NOLOCK) 
         JOIN SKU WITH (NOLOCK) ON (KD.StorerKey = SKU.StorerKey AND KD.SKU = SKU.SKU)
      WHERE KD.KitKey = @cKitKey
         AND KD.Type = 'F' -- Child
         AND SKU.SerialNoCapture = '3' -- 3 = Outbound
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 127802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
         GOTO RollbackTran
      END
   END
   
   -- Split child line, update SNO and QTY
   ELSE IF @cType = 'CHILD'
   BEGIN
      IF @nChildInner > 0
         SET @nQTY = @nQTY * @nChildInner
      
      -- Get child info
      SET @nRowRef = 0
      SELECT 
         @nRowRef = RowRef, 
         @nExpectedQTY = ExpectedQTY
      FROM rdt.rdtCPVKitLog WITH (NOLOCK)
      WHERE Mobile = @nMobile
         AND KitKey = @cKitKey
         AND StorerKey = @cStorerKey
         AND SKU = @cChildSKU
         AND ExpectedQTY > QTY
      
      IF @nRowRef = 0
      BEGIN
         SET @nErrNo = 127803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over kit
         GOTO RollbackTran
      END
      
      IF @nExpectedQTY > @nQTY
      BEGIN
         -- Insert new
         INSERT INTO rdt.rdtCPVKitLog (
            Mobile, KitKey, Type, StorerKey, SKU, ExpectedQTY, QTY, Barcode, Lottable07, Lottable08) 
         VALUES (
            @nMobile, @cKitKey, 'F', @cStorerKey, @cChildSKU, @nQTY, @nQTY, @cChildSNO, @cLottable07, @cLottable08) 
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 127804
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
            GOTO RollbackTran
         END
         
         -- Reduce original
         UPDATE rdt.rdtCPVKitLog SET
            ExpectedQTY = ExpectedQTY - @nQTY, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE RowRef = @nRowRef
         IF @nRowRef = 0
         BEGIN
            SET @nErrNo = 127805
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
            GOTO RollbackTran
         END
      END
      ELSE
      BEGIN   
         UPDATE rdt.rdtCPVKitLog SET
            QTY = QTY + @nQTY,
            Barcode = @cChildSNO, 
            Lottable07 = @cLottable07, 
            Lottable08 = @cLottable08, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE RowRef = @nRowRef
         IF @nRowRef = 0
         BEGIN
            SET @nErrNo = 127806
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
            GOTO RollbackTran
         END
      END
   END
   
   -- Update parent SNO
   IF @cType = 'PARENTSNO'
   BEGIN
      IF @nParentInner > 0                   
         SET @nQTY = @nQTY * @nParentInner         

      -- Get parent info
      SET @nRowRef = 0
      SELECT 
         @nRowRef = RowRef, 
         @nExpectedQTY = ExpectedQTY
      FROM rdt.rdtCPVKitLog WITH (NOLOCK)
      WHERE Mobile = @nMobile
         AND KitKey = @cKitKey
         AND Type = 'T' -- Parent
         AND StorerKey = @cStorerKey
         AND SKU = @cParentSKU
         AND (ExpectedQTY - QTY) >= @nQTY

      IF @nRowRef = 0
      BEGIN
         SET @nErrNo = 127807
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
         GOTO RollbackTran
      END

      UPDATE rdt.rdtCPVKitLog SET
         QTY = QTY + @nQTY, 
         Lottable07 = @cLottable07, 
         Lottable08 = @cLottable08, 
         Barcode = @cParentSNO,
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE()
      WHERE RowRef = @nRowRef
      IF @nRowRef = 0
      BEGIN
         SET @nErrNo = 127810
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
         GOTO RollbackTran
      END

      DECLARE @cKDType        NVARCHAR( 5)
      DECLARE @cSKU           NVARCHAR( 20)
      DECLARE @cKitLineNumber NVARCHAR( 5)

      -- Update KitDetail
      DECLARE @curLog CURSOR
      SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef, Type, SKU, QTY, Lottable07, Lottable08
         FROM rdt.rdtCPVKitLog WITH (NOLOCK) 
         WHERE Mobile = @nMobile
            AND KitKey = @cKitKey
            AND Barcode <> ''
         -- ORDER BY Type DESC -- Parent(T) follow by child (F) sequence, to set GroupKey = parent's KitSerialNoKey
      OPEN @curLog 
      FETCH NEXT FROM @curLog INTO @nRowRef, @cKDType, @cSKU, @nQTY, @cLottable07, @cLottable08
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get KitDetail (exact match L7, L8)
         SET @cKitLineNumber = ''
         SELECT @cKitLineNumber = KitLineNumber
         FROM KitDetail WITH (NOLOCK)
         WHERE KitKey = @cKitKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND Type = @cKDType
            AND Lottable07 = @cLottable07 
            AND Lottable08 = @cLottable08
            AND (ExpectedQTY - QTY) >= @nQTY

         -- Get KitDetail (blank L7, L8)
         IF @cKitLineNumber = ''
            SELECT @cKitLineNumber = KitLineNumber
            FROM KitDetail WITH (NOLOCK)
            WHERE KitKey = @cKitKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND Type = @cKDType
               AND Lottable07 = '' 
               AND Lottable08 = ''
               AND (ExpectedQTY - QTY) >= @nQTY

         -- Found
         IF @cKitLineNumber <> ''
         BEGIN
            -- Update KitDetail
            UPDATE KitDetail SET
               QTY = QTY + @nQTY, 
               Lottable07 = CASE WHEN Lottable07 = '' THEN @cLottable07 ELSE Lottable07 END, 
               Lottable08 = CASE WHEN Lottable08 = '' THEN @cLottable08 ELSE Lottable08 END, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE KitKey = @cKitKey
               AND KitLineNumber = @cKitLineNumber
               AND Type = @cKDType
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 127811
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD KDTL Fail
               GOTO RollbackTran
            END
         END

         -- Borrow from other
         ELSE
         BEGIN

            -- Find borrower
            DECLARE @cBorrowKitLineNumber NVARCHAR(5)
            SET @cBorrowKitLineNumber = ''

            SELECT @cBorrowKitLineNumber = KitLineNumber 
            FROM KitDetail WITH (NOLOCK)
            WHERE KitKey = @cKitKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND Type = @cKDType
               AND (ExpectedQTY - QTY) >= @nQTY

            -- No borrower
            IF @cBorrowKitLineNumber = ''
            BEGIN
               SET @nErrNo = 127812
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FIND KDTL Fail
               GOTO RollbackTran
            END

            -- Reduce borrower
            UPDATE KitDetail SET
               ExpectedQTY = ExpectedQTY - @nQTY, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE KitKey = @cKitKey
               AND KitLineNumber = @cBorrowKitLineNumber
               AND Type = @cKDType
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 127813
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD KDTL Fail
               GOTO RollbackTran
            END
         
            -- Find same L07, L08
            SELECT @cKitLineNumber = KitLineNumber
            FROM KitDetail WITH (NOLOCK)
            WHERE KitKey = @cKitKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND Type = @cKDType
               AND Lottable07 = @cLottable07 
               AND Lottable08 = @cLottable08
               AND ExpectedQTY = QTY

            IF @cKitLineNumber <> ''
            BEGIN
               -- Top up KitDetail
               UPDATE KitDetail SET
                  ExpectedQTY = ExpectedQTY + @nQTY, 
                  QTY = QTY + 1, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE KitKey = @cKitKey
                  AND KitLineNumber = @cKitLineNumber
                  AND Type = @cKDType
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 127814
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD KDTL Fail
                  GOTO RollbackTran
               END
            END
            ELSE
            BEGIN
               -- Get new KitLineNumber 
               DECLARE @cNewKitLineNumber NVARCHAR(5)
               SELECT @cNewKitLineNumber = RIGHT( '00000' + CAST( CAST( MAX( KitLineNumber) AS INT) + 1 AS NVARCHAR(5)), 5)
               FROM KitDetail WITH (NOLOCK)
               WHERE KitKey = @cKitKey
                  AND Type = @cKDType
            
               -- Insert new KitDetail
               INSERT INTO KitDetail 
                  (KitKey, KitLineNumber, Type, StorerKey, SKU, LOT, LOC, ID, PackKey, UOM, ExpectedQTY, QTY, Lottable07, Lottable08)
               SELECT KitKey, @cNewKitLineNumber, Type, StorerKey, SKU, LOT, LOC, ID, PackKey, UOM, @nQTY, @nQTY, @cLottable07, @cLottable08
               FROM KitDetail WITH (NOLOCK)
               WHERE KitKey = @cKitKey
                  AND KitLineNumber = @cBorrowKitLineNumber
                  AND Type = @cKDType

               SET @cKitLineNumber = @cNewKitLineNumber
            END
         END

         -- Delete rdtKitSerialNoLog
         DELETE rdt.rdtCPVKitLog WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 127817
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL KLOG Fail
            GOTO RollbackTran
         END

         FETCH NEXT FROM @curLog INTO @nRowRef, @cKDType, @cSKU, @nQTY, @cLottable07, @cLottable08
      END

   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_CPVKit_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
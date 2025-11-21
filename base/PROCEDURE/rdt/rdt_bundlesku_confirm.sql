SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_BundleSKU_Confirm                                     */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-02-08 1.0  Ung      WMS-18861 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_BundleSKU_Confirm] (
   @nMobile           INT,           
   @nFunc             INT,           
   @cLangCode         NVARCHAR( 3),  
   @nStep             INT,           
   @nInputKey         INT,           
   @cFacility         NVARCHAR( 5),   
   @cStorerKey        NVARCHAR( 15), 
   @cWorkOrderKey     NVARCHAR( 10), 
   @cParentSKU        NVARCHAR( 20) = '', 
   @cParentSNO        NVARCHAR( 60) = '', 
   @cChildSKU         NVARCHAR( 20) = '', 
   @cChildSNO         NVARCHAR( 60) = '', 
   @cUserDefine01     NVARCHAR( 18) = '', 
   @cUserDefine02     NVARCHAR( 18) = '', 
   @nChildTotal       INT           = 0, 
   @nChildScan        INT           = 0  OUTPUT, 
   @nGroupKey         INT           = 0  OUTPUT, 
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
   DECLARE @curLog        CURSOR

   SET @nTranCount = @@TRANCOUNT
   
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_BundleSKU_Confirm -- For rollback or commit only our own transaction

   /***********************************************************************************************
                                    Add parent and child serial no
   ***********************************************************************************************/
   IF @nGroupKey = 0
   BEGIN
      -- Parent
      INSERT INTO rdt.rdtBundleSKULog (Mobile, WorkOrderKey, Type, StorerKey, SKU, QTY, SerialNo)
      VALUES (@nMobile, @cWorkOrderKey, 'P', @cStorerKey, @cParentSKU, 1, @cParentSNO)
      SELECT @nGroupKey = SCOPE_IDENTITY(), @nErrNo = @@ERROR 
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 181901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS BLog Fail
         GOTO RollbackTran
      END
      
      -- Stamp the group
      UPDATE rdt.rdtBundleSKULog SET
         GroupKey = @nGroupKey
      WHERE RowRef = @nGroupKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 181902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD BLog Fail
         GOTO RollbackTran
      END
   END

   -- Child
   INSERT INTO rdt.rdtBundleSKULog (Mobile, WorkOrderKey, Type, GroupKey, StorerKey, SKU, QTY, SerialNo, UserDefine01, UserDefine02)
   VALUES (@nMobile, @cWorkOrderKey, 'C', @nGroupKey, @cStorerKey, @cChildSKU, 1, @cChildSNO, @cUserDefine01, @cUserDefine02)
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 181903
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS BLog Fail
      GOTO RollbackTran
   END
   

   /***********************************************************************************************
                                Posting into WorkOrderDetail, MasterSerialNo
   ***********************************************************************************************/
   -- Posting into WorkOrderDetail, MasterSerialNo
   IF (@nChildScan + 1) = @nChildTotal
   BEGIN
      DECLARE @cSKU NVARCHAR( 20) 
      DECLARE @cSNO NVARCHAR( 50)
      DECLARE @cBalLineNo   NVARCHAR( 5)
      DECLARE @cTopUpLineNo NVARCHAR( 5)
      DECLARE @cNewLineNo   NVARCHAR( 5)
      DECLARE @nQTY INT

      -- Get LOC info
      DECLARE @cLOCCode NVARCHAR(10)
      SELECT @cLOCCode = ISNULL( Short, '') 
      FROM CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'LOGILOC' 
         AND Code = @cFacility

      -- Loop rdtBundleSKULog
      SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef, GroupKey, SKU, SerialNo, UserDefine01, UserDefine02
         FROM rdt.rdtBundleSKULog WITH (NOLOCK) 
         WHERE WorkOrderKey = @cWorkOrderKey
            AND GroupKey = @nGroupKey
         ORDER BY GroupKey, RowRef
      OPEN @curLog 
      FETCH NEXT FROM @curLog INTO @nRowRef, @nGroupKey, @cSKU, @cSNO, @cUserDefine01, @cUserDefine02
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- 1st record in the group is parent
         IF @nRowRef = @nGroupKey
         BEGIN
            SET @cParentSKU = @cSKU
            SET @cParentSNO = @cSNO
         END
         ELSE
         BEGIN
            SET @cChildSKU = @cSKU
            SET @cChildSNO = @cSNO

            -- Posting to MasterSerialNo
            IF @cChildSNO <> ''
            BEGIN
               INSERT INTO MasterSerialNo (LocationCode, UnitType, SerialNo, Storerkey, SKU, ChildQty, ParentSerialNo, ParentSKU, UserDefine01, Revision, Source)
               VALUES (@cLOCCode, 'K', @cChildSNO, @cStorerKey, @cChildSKU, 1, @cParentSNO, @cParentSKU, 'NEW', @nFunc, @cWorkOrderKey)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 181904
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MSO Fail
                  GOTO RollbackTran
               END
            END
            
            /*
            find line with balance
            find line can be top up
            if top up
               deduct from balance line
               add to top up line 
            else
               split new line to carry balance
               update balance line
            */
            
            -- Find line with balance
            SELECT TOP 1 
               @cBalLineNo = WorkOrderLineNumber, 
               @nQTY = QTY
            FROM dbo.WorkOrderDetail WITH (NOLOCK)
            WHERE WorkOrderKey = @cWorkOrderKey
               AND StorerKey = @cStorerKey
               AND SKU = @cChildSKU
               AND ExternLineNo <> '001'
               AND WkOrdUdef4 = '' 
               AND QTY > 0
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 181905
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get WOD Fail
               GOTO RollbackTran
            END

            -- Find line can be top up (for non serial SKU only)
            SET @cTopUPLineNo = ''
            IF @cChildSNO = ''
               SELECT @cTopUPLineNo = WorkOrderLineNumber
               FROM dbo.WorkOrderDetail WITH (NOLOCK)
               WHERE WorkOrderKey = @cWorkOrderKey
                  AND StorerKey = @cStorerKey
                  AND SKU = @cChildSKU
                  AND ExternLineNo <> '001'
                  AND WkOrdUdef4 = @cParentSNO

            -- Top up
            IF @cTopUPLineNo <> ''
            BEGIN
               -- Deduct from balance line
               IF @nQTY = 1
               BEGIN
                  DELETE dbo.WorkOrderDetail
                  WHERE WorkOrderKey = @cWorkOrderKey
                     AND WorkOrderLineNumber = @cBalLineNo 
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 181906
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL WOD Fail
                     GOTO RollbackTran
                  END
               END
               BEGIN
                  UPDATE dbo.WorkOrderDetail SET
                     QTY = QTY - 1, 
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE()
                  WHERE WorkOrderKey = @cWorkOrderKey
                     AND WorkOrderLineNumber = @cBalLineNo 
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 181907
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD WOD Fail
                     GOTO RollbackTran
                  END
               END

               -- Add to top up line
               UPDATE dbo.WorkOrderDetail SET
                  QTY = QTY + 1, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE WorkOrderKey = @cWorkOrderKey
                  AND WorkOrderLineNumber = @cTopUpLineNo 
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 181908
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD WOD Fail
                  GOTO RollbackTran
               END
            END
            ELSE
            BEGIN
               -- Have balance, need to split line
               IF @nQTY > 1
               BEGIN
                  -- Get new line number
                  SELECT @cNewLineNo =  
                     RIGHT( '00000' + CAST( CAST( IsNULL( MAX( WorkOrderLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
                  FROM dbo.WorkOrderDetail (NOLOCK)
                  WHERE WorkOrderKey = @cWorkOrderKey
                  
                  -- Create new line to hold the balance
                  INSERT INTO dbo.WorkOrderDetail (
                     WorkOrderKey, ExternWorkOrderKey, ExternLineNo, 
                     Type, Reason, Unit, Price, LineValue, Remarks, Status, StorerKey, SKU, 
                     WkOrdUdef1, WkOrdUdef2, WkOrdUdef3, WkOrdUdef4, WkOrdUdef5, 
                     WkOrdUdef6, WkOrdUdef7, WkOrdUdef8, WkOrdUdef9, WkOrdUdef10, 
                     WorkOrderLineNumber, 
                     QTY)
                  SELECT
                     WorkOrderKey, ExternWorkOrderKey, ExternLineNo, 
                     Type, Reason, Unit, Price, LineValue, Remarks, Status, StorerKey, SKU, 
                     WkOrdUdef1, WkOrdUdef2, WkOrdUdef3, WkOrdUdef4, WkOrdUdef5, 
                     WkOrdUdef6, WkOrdUdef7, WkOrdUdef8, WkOrdUdef9, WkOrdUdef10, 
                     @cNewLineNo, 
                     @nQTY - 1
                  FROM dbo.WorkOrderDetail (NOLOCK)
                  WHERE WorkOrderKey = @cWorkOrderKey
                     AND WorkOrderLineNumber = @cBalLineNo 
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 181909
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS WOD Fail
                     GOTO RollbackTran
                  END
               END
                  
               -- Update balance line
               UPDATE dbo.WorkOrderDetail SET
                  QTY = 1, 
                  WkOrdUdef1 = @cChildSNO, 
                  WkOrdUdef2 = @cUserDefine01, 
                  WkOrdUdef3 = @cUserDefine02, 
                  WkOrdUdef4 = @cParentSNO,
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE WorkOrderKey = @cWorkOrderKey
                  AND WorkOrderLineNumber = @cBalLineNo 
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 181910
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD WOD Fail
                  GOTO RollbackTran
               END
            END
         END

         FETCH NEXT FROM @curLog INTO @nRowRef, @nGroupKey, @cSKU, @cSNO, @cUserDefine01, @cUserDefine02
      END
      
      -- Delete log
      SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef
         FROM rdt.rdtBundleSKULog WITH (NOLOCK) 
         WHERE WorkOrderKey = @cWorkOrderKey
            AND GroupKey = @nGroupKey
         ORDER BY RowRef
      OPEN @curLog 
      FETCH NEXT FROM @curLog INTO @nRowRef
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE rdt.rdtBundleSKULog WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 181911
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL BLOG Fail
            GOTO RollbackTran
         END
         FETCH NEXT FROM @curLog INTO @nRowRef
      END
   END

   -- Update stat
   SET @nChildScan += 1

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_BundleSKU_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
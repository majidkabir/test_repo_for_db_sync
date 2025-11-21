SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_ECOMQABatch_Confirm                                   */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-03-24 1.0  Ung      WMS-19222 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_ECOMQABatch_Confirm] (
   @nMobile    INT,
   @nFunc      INT,
   @cLangCode  NVARCHAR( 3),
   @nStep      INT, 
   @nInputKey  INT,
   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cType      NVARCHAR( 10), --UPDATE/CLOSE/RESET
   @cBatchNo   NVARCHAR( 10),
   @cStation   NVARCHAR( 10),
   @cSKU       NVARCHAR( 20),
   @nQTY       INT,
   @nTotalSKU  INT           OUTPUT, 
   @nTotalQTY  INT           OUTPUT, 
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL       NVARCHAR( MAX)
   DECLARE @cSQLParam  NVARCHAR( MAX)
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   -- Get RDT storer configure
   DECLARE @cConfirmSP NVARCHAR(20)
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''
   
   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   -- Custom confirm
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cType, ' + 
            ' @cBatchNo, @cStation, @cSKU, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR(  5), ' +
            '@cType           NVARCHAR( 10), ' +
            '@cBatchNo        NVARCHAR( 10), ' +
            '@cStation        NVARCHAR( 10), ' +
            '@cSKU            NVARCHAR( 20), ' +
            '@nQTY            INT,           ' +
            '@nErrNo          INT OUTPUT,    ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cType, 
            @cBatchNo, @cStation, @cSKU, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
	DECLARE @nRowRef  INT = 0

   -- Update log table
   IF @cType = 'UPDATE' 
   BEGIN
      -- Find the line with same SKU
      SELECT @nRowRef = RowRef
      FROM rdt.rdtECOMQABatchLog WITH (NOLOCK)
      WHERE BatchNo = @cBatchNo
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND QTYExpected - QTY >= @nQTY 
      IF @nRowRef = 0
      BEGIN
         SET @nErrNo = 185001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Find Log Fail
         GOTO Quit
      END

      -- Top up QTY
      UPDATE rdt.rdtECOMQABatchLog SET
         QTY = QTY + @nQTY, 
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE()
      WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 185002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
         GOTO Quit
      END
      
      -- Get statistics
      SELECT
         @nTotalSKU = COUNT( DISTINCT SKU), 
         @nTotalQTY = SUM( QTY)
      FROM rdt.rdtECOMQABatchLog WITH (NOLOCK)
      WHERE BatchNo = @cBatchNo
         AND QTY > 0
      
      GOTO Quit
   END

   -- Close
   ELSE IF @cType = 'CLOSE' 
   BEGIN
      DECLARE @bSuccess       INT
      DECLARE @cOrderKey      NVARCHAR( 10)
      DECLARE @cPickDetailKey NVARCHAR( 10)

      BEGIN TRAN
      SAVE TRAN rdt_ECOMQABatch_Confirm

      -- Loop PackTask
      DECLARE @curPT CURSOR
      SET @curPT = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef, OrderKey
         FROM dbo.PackTask WITH (NOLOCK)
         WHERE TaskBatchNo = @cBatchNo
         ORDER BY RowRef
      OPEN @curPT
      FETCH NEXT FROM @curPT INTO @nRowRef, @cOrderKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Outstanding order
         IF EXISTS( SELECT TOP 1 1 FROM rdt.rdtECOMQABatchLog WITH (NOLOCK) WHERE BatchNo = @cBatchNo AND OrderKey = @cOrderKey AND QTYExpected > QTY)
         BEGIN
            -- Remove from PackTask
            DELETE dbo.PackTask WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 185003
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PTask Fail
               GOTO RollBackTran
            END
            
            -- Remove pickslip
            DECLARE @curPD CURSOR
            SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT PickDetailKey 
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE OrderKey = @cOrderKey
                  AND PickSlipNo <> ''
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.PickDetail SET
                  PickSlipNo = '', 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 185004
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
            END
         END
         
         -- Completed order, and not cancel
         ELSE IF NOT EXISTS( SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND (Status = 'CANC' OR SOStatus IN ('PENDCANC', 'CANC')))
         BEGIN
            -- Update PackTask
            UPDATE dbo.PackTask SET
               UDF01 = @cStation, 
               UDF02 = SUSER_SNAME(), 
               UDF03 = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               EditDate = GETDATE()
            WHERE RowRef = @nRowRef
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
               
            -- Update Order
            UPDATE dbo.Orders SET 
               UserDefine03 = 'QA', 
               EditWho = SUSER_SNAME(), 
               EditDate = GETDATE()
            WHERE OrderKey = @cOrderKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            
            -- Send QA confirm 
            EXEC dbo.ispGenTransmitLog2
                'WSPICKCFMBZ' -- TableName
               , @cOrderKey   -- Key1
               , ''           -- Key2
               , @cStorerKey  -- Key3
               , ''           -- Batch
               , @bSuccess  OUTPUT
               , @nErrNo    OUTPUT
               , @cErrMsg   OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 185003
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG3 Fail
               GOTO Quit
            END
         END

         FETCH NEXT FROM @curPT INTO @nRowRef, @cOrderKey
      END      

      COMMIT TRAN rdt_ECOMQABatch_Confirm
      GOTO Quit
   END
   
   -- Delete log table
   ELSE IF @cType = 'RESET' 
   BEGIN
      BEGIN TRAN
      SAVE TRAN rdt_ECOMQABatch_Confirm
      
      -- Loop rdtECOMQABatchLog
      DECLARE @curLog CURSOR
      SET @curLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Rowref
         FROM rdt.rdtECOMQABatchLog WITH (NOLOCK)
         WHERE BatchNo = @cBatchNo
      OPEN @curLog
      FETCH NEXT FROM @curLog INTO @nRowRef
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE rdt.rdtECOMQABatchLog WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 185004
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail
            GOTO RollBackTran
         END

         FETCH NEXT FROM @curLog INTO @nRowRef
      END
      
      COMMIT TRAN rdt_ECOMQABatch_Confirm
      GOTO Quit
   END
   ELSE
      GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_ECOMQABatch_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO
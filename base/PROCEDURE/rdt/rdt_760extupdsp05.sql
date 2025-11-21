SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_760ExtUpdSP05                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2018-04-11  1.0  Ung      WMS-4300 Created                           */
/* 2018-06-14  1.1  Ung      WMS-5408 Allow short pick                  */
/* 2018-07-24  1.2  Ung      WMS-5913 Short pick delete PackDetail      */
/************************************************************************/
CREATE PROC [RDT].[rdt_760ExtUpdSP05] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR(3),
   @nStep          INT,
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cDropID        NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @nQty           INT,
   @cLabelNo       NVARCHAR( 20),
   @cPTSLogKey     NVARCHAR( 20),
   @cShort         NVARCHAR(1),
   @cSuggLabelNo   NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @cConsigneeKey  NVARCHAR(15)
   DECLARE @cCaseID        NVARCHAR(20)
   DECLARE @cPosition      NVARCHAR(20)
   DECLARE @cPickStatus    NVARCHAR(1)
   DECLARE @nExpectedQty   INT
   DECLARE @curPD          CURSOR

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 760 -- Sort and pack
   BEGIN
      IF @nStep = 1 --- Drop ID
      BEGIN
         -- IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Storer configure
            SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)
            IF @cPickStatus NOT IN ('3', '5')
               SET @cPickStatus = '5'

            -- Check drop ID valid
            IF NOT EXISTS ( SELECT 1
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND DropID = @cDropID
                  AND Status = @cPickStatus
                  AND Status <> '4'
                  AND QTY > 0)
            BEGIN
               SET @nErrNo = 122651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid DropID
               GOTO RollBackTran
            END

            BEGIN TRAN
            SAVE TRAN rdt_760ExtUpdSP05

            -- Loop PickDetail
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.ToLoc, O.ConsigneeKey, PD.CaseID, PD.SKU, SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
                  AND PD.Status = @cPickStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
               GROUP BY PD.ToLoc, O.ConsigneeKey, PD.CaseID, PD.SKU
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPosition, @cConsigneeKey, @cCaseID, @cSKU, @nExpectedQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Insert tasks
               INSERT INTO rdt.rdtPTSLog (
                  PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM, ExpectedQty, Qty, Remarks, Func, AddDate, AddWho )
               VALUES (
                  @cPosition, '0', @cDropID, @cCaseID, @cStorerKey, @cConsigneeKey, '', @cSKU, '', '', '6', @nExpectedQTY, '0', '', @nFunc, GETDATE(), SUSER_SNAME())
               IF @@ERROR <> 0
               BEGIN
                   SET @nErrNo = 122652
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Log Fail
                   GOTO RollBackTran
               END

               FETCH NEXT FROM @curPD INTO @cPosition, @cConsigneeKey, @cCaseID, @cSKU, @nExpectedQTY
             END

             COMMIT TRAN rdt_760ExtUpdSP05
         END
      END

      IF @nStep = 3 -- SKU, QTY
      BEGIN
         -- IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get task info
            SELECT @nExpectedQTY = ExpectedQTY FROM rdt.rdtPTSLog WITH (NOLOCK) WHERE PTSLogKey = @cPTSLogKey

            -- Check QTY different
            IF @nQTY > @nExpectedQTY
            BEGIN
               SET @nErrNo = 122653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Over pick
               GOTO Quit
            END
         END
      END

      IF @nStep = 4 -- To LabelNo
      BEGIN
         -- IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cPickDetailKey    NVARCHAR(10)
            DECLARE @cNewPickDetailKey NVARCHAR(10)
            DECLARE @nQTY_PD           INT
            DECLARE @nQTY_Bal          INT
            DECLARE @nQTY_Short        INT

            -- Storer configure
            SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)
            IF @cPickStatus NOT IN ('3', '5')
               SET @cPickStatus = '5'

            -- Get task info
            SELECT
               @cCaseID = LabelNo,
               @cConsigneeKey = ConsigneeKey
            FROM rdt.rdtPTSLog WITH (NOLOCK)
            WHERE PTSLogKey = @cPTSLogKey

            -- Check case ID
            IF @cCaseID <> @cLabelNo
            BEGIN
               SET @nErrNo = 122663
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Label NotMatch
               GOTO Quit
            END


/*
insert into a (field, value) values
   ('@cPTSLogKey',   isnull( @cPTSLogKey, '')),
   ('@cStorerKey',   isnull( @cStorerKey, '')),
   ('@cConsigneeKey', isnull( @cConsigneeKey, '')),
   ('@cDropID',      isnull( @cDropID, '')),
   ('@cCaseID',      isnull( @cCaseID, '')),
   ('@cSKU',         isnull( @cSKU, '')),
   ('@cPickStatus',  isnull( @cPickStatus, '')),
   ('@nQTY',         isnull( cast( @nQTY as nvarchar(10)), ''))
*/

            BEGIN TRAN
            SAVE TRAN rdt_760ExtUpdSP05

            SET @nQTY_Bal = @nQTY

            -- Loop PickDetail
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.PickDetailKey, PD.QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.StorerKey = @cStorerKey
                  AND O.ConsigneeKey = @cConsigneeKey
                  AND PD.DropID = @cDropID
                  AND PD.CaseID = @cCaseID
                  AND PD.SKU = @cSKU
                  AND PD.Status = @cPickStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Exact match
               IF @nQTY_PD = @nQTY_Bal
               BEGIN
                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     Status = '5',
                     EditDate = GETDATE(),
                     EditWho = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 122654
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END

                  SET @nQTY_Bal = 0 -- Reduce balance
               END

               -- PickDetail have less
               ELSE IF @nQTY_PD < @nQTY_Bal
               BEGIN
                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     Status = '5',
                     EditDate = GETDATE(),
                     EditWho = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 122655
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END

                  SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
               END

               -- PickDetail have more
               ELSE IF @nQTY_PD > @nQTY_Bal
               BEGIN
                  -- Short pick
                  IF @nQTY_Bal = 0 -- Don't need to split
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                        Status = '4',
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME(),
                        TrafficCop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 122664
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     
                     -- Delete PackDetail
                     SET @nQTY_Short = @nQTY_PD - @nQTY_Bal
                     EXEC rdt.rdt_760ExtUpdSP05_DelPack @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, 
                        @cCaseID, 
                        @cSKU, 
                        @nQTY_Short, 
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT
                     IF @nErrNo <> 0
                        GOTO RollBackTran
                  END
                  ELSE
                  BEGIN -- Have balance, need to split
                     -- Get new PickDetailkey
                     EXECUTE dbo.nspg_GetKey
                        'PICKDETAILKEY',
                        10 ,
                        @cNewPickDetailKey OUTPUT,
                        @bSuccess          OUTPUT,
                        @nErrNo            OUTPUT,
                        @cErrMsg           OUTPUT
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 122656
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetKey Fail
                        GOTO RollBackTran
                     END

                     -- Create new a PickDetail to hold the balance
                     INSERT INTO dbo.PickDetail (
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                        UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                        PickDetailKey,
                        Status,
                        QTY,
                        TrafficCop,
                        OptimizeCop)
                     SELECT
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                        UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                        CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                        @cNewPickDetailKey,
                        Status,
                        @nQTY_PD - @nQTY_Bal, -- QTY
                        NULL, -- TrafficCop
                        '1'   -- OptimizeCop
                     FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 122657
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                        GOTO RollBackTran
                     END

                     -- Split RefKeyLookup
                     IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
                     BEGIN
                        -- Insert into
                        INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                        SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                        FROM RefKeyLookup WITH (NOLOCK)
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 122658
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                           GOTO RollBackTran
                        END
                     END

                     -- Change orginal PickDetail with exact QTY (with TrafficCop)
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                        QTY = @nQTY_Bal,
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME(),
                        Trafficcop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 122659
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END

                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                        Status = '5',
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 122660
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END

                     -- Short balance PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        Status = '4',
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME(),
                        TrafficCop = NULL
                     WHERE PickDetailKey = @cNewPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 125822
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END

                     -- Delete PackDetail
                     SET @nQTY_Short = @nQTY_PD - @nQTY_Bal
                     EXEC rdt.rdt_760ExtUpdSP05_DelPack @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, 
                        @cCaseID, 
                        @cSKU, 
                        @nQTY_Short, 
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT
                     IF @nErrNo <> 0
                        GOTO RollBackTran

                     SET @nQTY_Bal = 0 -- Reduce balance
                  END
               END

               -- Remark to loop all PickDetail to short
               -- IF @nQTY_Bal = 0
               --    BREAK

               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
            END

            -- Check balance
            IF @nQTY_Bal <> 0
            BEGIN
               SET @nErrNo = 122661
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Offset error
               GOTO RollBackTran
            END

            -- Close task
            UPDATE rdt.rdtPTSLog SET
               Status = '9', -- Closed
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PTSLogKey = @cPTSLogKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 122662
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail
               GOTO RollBackTran
            END

            COMMIT TRAN rdt_760ExtUpdSP05
         END
      END
   END
   GOTO QUIT

RollBackTran:
   ROLLBACK TRAN rdt_760ExtUpdSP05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_760ExtUpdSP05
END

GO
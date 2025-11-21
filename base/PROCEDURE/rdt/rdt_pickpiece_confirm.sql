SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_PickPiece_Confirm                                     */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 26-04-2016 1.0  Ung        SOS368792 Created                               */
/* 26-07-2016 1.1  Ung        SOS374283 Add DropID                            */
/* 01-11-2016 1.2  Ung        SOS374283 close DropID                          */
/* 25-06-2018 1.3  James      WMS5057-Add lot01-lot15 (james01)               */
/* 24-01-2019 1.4  ChewKP     WMS-4542 - Bug Fix                              */
/* 12-10-2020 1.5  YeeKung    Bug Fix (Change Alter to Create)                */
/* 30-04-2021 1.6  Chermaine  WMS-16868 Add Channel_ID (cc01)                 */
/* 13-12-2021 1.7  YeeKung    WMS-17489 Change pickzone to 1->10 (yeekung01)  */
/* 16-04-2022 1.8  YeeKung    WMS-19311 Add Data capture (yeekung02)          */
/* 25-07-2023 1.9  Ung        WMS-23002 Add serial no                         */
/******************************************************************************/

CREATE   PROC rdt.rdt_PickPiece_Confirm (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cType           NVARCHAR( 10) -- CONFIRM/SHORT/CLOSE
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cPickZone       NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@cLOC            NVARCHAR( 10)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cLottableCode   NVARCHAR( 30)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME
   ,@dLottable05     DATETIME
   ,@cLottable06     NVARCHAR( 30)
   ,@cLottable07     NVARCHAR( 30)
   ,@cLottable08     NVARCHAR( 30)
   ,@cLottable09     NVARCHAR( 30)
   ,@cLottable10     NVARCHAR( 30)
   ,@cLottable11     NVARCHAR( 30)
   ,@cLottable12     NVARCHAR( 30)
   ,@dLottable13     DATETIME
   ,@dLottable14     DATETIME
   ,@dLottable15     DATETIME
   ,@cPackData1      NVARCHAR( 30)
   ,@cPackData2      NVARCHAR( 30)
   ,@cPackData3      NVARCHAR( 30)
   ,@cID             NVARCHAR( 18)
   ,@cSerialNo       NVARCHAR( 30)
   ,@nSerialQTY      INT
   ,@nBulkSNO        INT
   ,@nBulkSNOQTY     INT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @nTranCount  INT
   DECLARE @cConfirmSP  NVARCHAR( 20)

   -- Get storer config
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''

   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cConfirmSP <> ''
   BEGIN
      -- Confirm SP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, ' +
         ' @cPickSlipNo, @cPickZone, @cDropID, @cLOC, @cSKU, @nQTY, @cLottableCode, ' +
         ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
         ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
         ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
         ' @cPackData1,  @cPackData2,  @cPackData3, ' +
         ' @cID, @cSerialNo, @nSerialQTY, @nBulkSNO, @nBulkSNOQTY, ' + 
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
      SET @cSQLParam =
         ' @nMobile        INT,           ' +
         ' @nFunc          INT,           ' +
         ' @cLangCode      NVARCHAR( 3),  ' +
         ' @nStep          INT,           ' +
         ' @nInputKey      INT,           ' +
         ' @cFacility      NVARCHAR( 5) , ' +
         ' @cStorerKey     NVARCHAR( 15), ' +
         ' @cType          NVARCHAR( 10), ' +
         ' @cPickSlipNo    NVARCHAR( 10), ' +
         ' @cPickZone      NVARCHAR( 10),  ' +
         ' @cDropID        NVARCHAR( 20), ' +
         ' @cLOC           NVARCHAR( 10), ' +
         ' @cSKU           NVARCHAR( 20), ' +
         ' @nQTY           INT,           ' +
         ' @cLottableCode  NVARCHAR( 20), ' +
         ' @cLottable01    NVARCHAR( 18), ' +
         ' @cLottable02    NVARCHAR( 18), ' +
         ' @cLottable03    NVARCHAR( 18), ' +
         ' @dLottable04    DATETIME,      ' +
         ' @dLottable05    DATETIME,      ' +
         ' @cLottable06    NVARCHAR( 30), ' +
         ' @cLottable07    NVARCHAR( 30), ' +
         ' @cLottable08    NVARCHAR( 30), ' +
         ' @cLottable09    NVARCHAR( 30), ' +
         ' @cLottable10    NVARCHAR( 30), ' +
         ' @cLottable11    NVARCHAR( 30), ' +
         ' @cLottable12    NVARCHAR( 30), ' +
         ' @dLottable13    DATETIME,      ' +
         ' @dLottable14    DATETIME,      ' +
         ' @dLottable15    DATETIME,      ' +
         ' @cPackData1     NVARCHAR( 30), ' +
         ' @cPackData2     NVARCHAR( 30), ' +
         ' @cPackData3     NVARCHAR( 30), ' +
         ' @cID            NVARCHAR( 18), ' +
         ' @cSerialNo      NVARCHAR( 30), ' +
         ' @nSerialQTY     INT,           ' +
         ' @nBulkSNO       INT,           ' +
         ' @nBulkSNOQTY    INT,           ' +
         ' @nErrNo         INT           OUTPUT, ' +
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType,
         @cPickSlipNo, @cPickZone, @cDropID, @cLOC, @cSKU, @nQTY, @cLottableCode,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cPackData1,  @cPackData2,  @cPackData3,
         @cID, @cSerialNo, @nSerialQTY, @nBulkSNO, @nBulkSNOQTY, 
         @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit
   END

   /***********************************************************************************************
                                              Standard confirm
   ***********************************************************************************************/
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cZone          NVARCHAR( 18)
   DECLARE @cPickDetailKey NVARCHAR( 18)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @nQTY_Bal       INT
   DECLARE @nQTY_PD        INT
   DECLARE @bSuccess       INT
   DECLARE @nSerialNoAdded INT = 0
   DECLARE @curPD          CURSOR
   DECLARE @cWhere         NVARCHAR( MAX)

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   -- For calculation
   SET @nQTY_Bal = @nQTY

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Get lottable filter
   EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 4, 'LA',
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
      @cWhere   OUTPUT,
      @nErrNo   OUTPUT,
      @cErrMsg  OUTPUT

   -- Open cursor
   BEGIN
      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
         SET @cSQL =
            ' SELECT PD.PickDetailKey, PD.QTY ' +
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +
            '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +
            '   AND PD.LOC = @cLOC ' +
            '   AND PD.SKU = @cSKU ' +
            '   AND PD.QTY > 0 ' +
            '   AND PD.Status <> ''4'' ' +
            '   AND PD.Status < @cPickConfirmStatus ' +
              CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
         SET @cSQL =
            ' SELECT PD.PickDetailKey, PD.QTY ' +
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
            ' WHERE PD.OrderKey = @cOrderKey ' +
            '    AND PD.LOC = @cLOC ' +
            '    AND PD.SKU = @cSKU ' +
            '    AND PD.QTY > 0 ' +
            '    AND PD.Status <> ''4'' ' +
            '    AND PD.Status < @cPickConfirmStatus ' +
              CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
         SET @cSQL =
            ' SELECT PD.PickDetailKey, PD.QTY ' +
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
            '    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
            ' WHERE LPD.LoadKey = @cLoadKey ' +
            '    AND PD.LOC = @cLOC ' +
            '    AND PD.SKU = @cSKU ' +
            '    AND PD.QTY > 0 ' +
            '    AND PD.Status <> ''4'' ' +
            '    AND PD.Status < @cPickConfirmStatus ' +
              CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END

      -- Custom PickSlip
      ELSE
         SET @cSQL =
            ' SELECT PD.PickDetailKey, PD.QTY ' +
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
            ' WHERE PD.PickSlipNo = @cPickSlipNo ' +
            '    AND PD.LOC = @cLOC ' +
            '    AND PD.SKU = @cSKU ' +
            '    AND PD.QTY > 0 ' +
            '    AND PD.Status <> ''4'' ' +
            '    AND PD.Status < @cPickConfirmStatus ' +
              CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END

      -- Open cursor
      SET @cSQL =
         ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +
            @cSQL +
         ' OPEN @curPD '

      SET @cSQLParam =
         ' @curPD       CURSOR OUTPUT, ' +
         ' @cPickSlipNo NVARCHAR( 10), ' +
         ' @cOrderKey   NVARCHAR( 10), ' +
         ' @cLoadKey    NVARCHAR( 10), ' +
         ' @cLOC        NVARCHAR( 10), ' +
         ' @cDropID     NVARCHAR( 20), ' +
         ' @cSKU        NVARCHAR( 20), ' +
         ' @cPickConfirmStatus NVARCHAR( 1), ' +
         ' @cLottable01 NVARCHAR( 18), ' +
         ' @cLottable02 NVARCHAR( 18), ' +
         ' @cLottable03 NVARCHAR( 18), ' +
         ' @dLottable04 DATETIME,      ' +
         ' @dLottable05 DATETIME,      ' +
         ' @cLottable06 NVARCHAR( 30), ' +
         ' @cLottable07 NVARCHAR( 30), ' +
         ' @cLottable08 NVARCHAR( 30), ' +
         ' @cLottable09 NVARCHAR( 30), ' +
         ' @cLottable10 NVARCHAR( 30), ' +
         ' @cLottable11 NVARCHAR( 30), ' +
         ' @cLottable12 NVARCHAR( 30), ' +
         ' @dLottable13 DATETIME,      ' +
         ' @dLottable14 DATETIME,      ' +
         ' @dLottable15 DATETIME       '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @curPD OUTPUT, @cPickSlipNo, @cOrderKey, @cLoadKey, @cLOC, @cDropID, @cSKU, @cPickConfirmStatus,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
   END

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PickPiece_Confirm -- For rollback or commit only our own transaction

   -- Loop PickDetail
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Exact match
      IF @nQTY_PD = @nQTY_Bal
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            Status = @cPickConfirmStatus,
            DropID = @cDropID,
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 100101
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
            Status = @cPickConfirmStatus,
            DropID = @cDropID,
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 100102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END

         SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
      END

      -- PickDetail have more
      ELSE IF @nQTY_PD > @nQTY_Bal
      BEGIN
         -- Don't need to split
         IF @nQTY_Bal = 0
         BEGIN
            -- Short pick
            IF @cType = 'SHORT' -- Don't need to split
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
                  SET @nErrNo = 100103
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END
            END
         END
         ELSE
         BEGIN -- Have balance, need to split

            -- Get new PickDetailkey
            DECLARE @cNewPickDetailKey NVARCHAR( 10)
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @nErrNo            OUTPUT,
               @cErrMsg           OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 100104
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
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
               OptimizeCop,
               Channel_ID )      --(cc01)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               @cNewPickDetailKey,
               Status,
               @nQTY_PD - @nQTY_Bal, -- QTY
               NULL, -- TrafficCop
               '1',   -- OptimizeCop
               Channel_ID --(cc01)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 100105
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
                  SET @nErrNo = 100106
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
               SET @nErrNo = 100107
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END

            -- Confirm orginal PickDetail with exact QTY
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus,
               DropID = @cDropID,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 100108
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END

            -- Short pick
            IF @cType = 'SHORT'
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = '4',
                  DropID = '',
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  TrafficCop = NULL
               WHERE PickDetailKey = @cNewPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 100109
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END
            END

            SET @nQTY_Bal = 0 -- Reduce balance
         END
      END

      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
   END

   COMMIT TRAN rdt_PickPiece_Confirm

   DECLARE @cUserName NVARCHAR( 18)
   SET @cUserName = SUSER_SNAME()

   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '3', -- Picking
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cLocation     = @cLOC,
      @cSKU          = @cSKU,
      @nQTY          = @nQTY,
      @cRefNo1       = @cType,
      @cPickSlipNo   = @cPickSlipNo,
      @cPickZone     = @cPickZone,
      @cDropID       = @cDropID

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PickPiece_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
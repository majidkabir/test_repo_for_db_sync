SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_839Confirm13                                          */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 04-08-2023 1.0  Ung        WMS-23002 Created                               */
/******************************************************************************/

CREATE   PROC rdt.rdt_839Confirm13 (
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

   DECLARE @nTranCount  INT
   DECLARE @bSuccess    INT
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cWhere      NVARCHAR( MAX)
   DECLARE @curPD       CURSOR

   DECLARE @cOrderKey            NVARCHAR( 10)
   DECLARE @cLoadKey             NVARCHAR( 10)
   DECLARE @cZone                NVARCHAR( 18)
   DECLARE @cPickDetailKey       NVARCHAR( 18) = ''
   DECLARE @cNewPickDetailKey    NVARCHAR( 10)
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)

   SET @nTranCount = @@TRANCOUNT
   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

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

/*--------------------------------------------------------------------------------------------------
                                                Serial SKU
--------------------------------------------------------------------------------------------------*/
   IF @cSerialNo <> ''
   BEGIN
      DECLARE @cSerialNoKey   NVARCHAR( 10) = ''
      DECLARE @cSerial_ID     NVARCHAR( 18)
      DECLARE @cSerial_LOT    NVARCHAR( 10)
      DECLARE @cPD_ID         NVARCHAR( 18)
      DECLARE @cPD_LOT        NVARCHAR( 10)
      DECLARE @nPD_QTY        INT

      -- Get serial no info
      SELECT 
         @cSerialNoKey = SerialNoKey, 
         @cSerial_LOT = LOT, 
         @cSerial_ID = ID
      FROM dbo.SerialNo WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND SerialNo = @cSerialNo
         
      -- Check serial LOT
      IF @cSerial_LOT = ''
      BEGIN
         SET @nErrNo = 204801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SNO no LOT
         GOTO Quit
      END

      -- Check serial ID
      IF @cSerial_ID = ''
      BEGIN
         SET @nErrNo = 204802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SNO no ID
         GOTO Quit
      END

      -- Check SN ID not in LOC
      IF NOT EXISTS( SELECT 1
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND LOC = @cLOC
            AND ID = @cSerial_ID
            AND QTY - QTYPicked >= @nSerialQTY)
      BEGIN
         SET @nErrNo = 204803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID not in LOC
         GOTO Quit
      END

      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_839Confirm13 -- For rollback or commit only our own transaction         

      -- Get a PickDetail (try match SN LOT, ID)
      BEGIN
         -- Cross dock PickSlip
         IF @cZone IN ('XD', 'LB', 'LP')
            SET @cSQL =
               ' SELECT TOP 1 ' + 
                  ' @cPickDetailKey = PD.PickDetailKey, ' + 
                  ' @cPD_ID = PD.ID, ' + 
                  ' @cPD_LOT = PD.LOT, ' + 
                  ' @nPD_QTY = PD.QTY ' +
               ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +
               '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +
               '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +
               '   AND PD.LOC = @cLOC ' +
               '   AND PD.SKU = @cSKU ' +
               '   AND PD.QTY > 0 ' +
               '   AND PD.Status <> ''4'' ' +
               '   AND PD.Status < @cPickConfirmStatus ' +
                 CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END + 
            ' ORDER BY CASE WHEN PD.LOT = @cSerial_LOT AND PD.ID = @cSerial_ID THEN 1 ELSE 2 END '

         -- Discrete PickSlip
         ELSE IF @cOrderKey <> ''
            SET @cSQL =
               ' SELECT TOP 1 ' + 
                  ' @cPickDetailKey = PD.PickDetailKey, ' + 
                  ' @cPD_ID = PD.ID, ' + 
                  ' @cPD_LOT = PD.LOT, ' + 
                  ' @nPD_QTY = PD.QTY ' +
               ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
               '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
               '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
               ' WHERE PD.OrderKey = @cOrderKey ' +
               '    AND PD.LOC = @cLOC ' +
               '    AND PD.SKU = @cSKU ' +
               '    AND PD.QTY > 0 ' +
               '    AND PD.Status <> ''4'' ' +
               '    AND PD.Status < @cPickConfirmStatus ' +
                 CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END + 
            ' ORDER BY CASE WHEN PD.LOT = @cSerial_LOT AND PD.ID = @cSerial_ID THEN 1 ELSE 2 END '

         -- Conso PickSlip
         ELSE IF @cLoadKey <> ''
            SET @cSQL =
               ' SELECT TOP 1 ' + 
                  ' @cPickDetailKey = PD.PickDetailKey, ' + 
                  ' @cPD_ID = PD.ID, ' + 
                  ' @cPD_LOT = PD.LOT, ' + 
                  ' @nPD_QTY = PD.QTY ' +
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
                 CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END + 
            ' ORDER BY CASE WHEN PD.LOT = @cSerial_LOT AND PD.ID = @cSerial_ID THEN 1 ELSE 2 END '

         -- Custom PickSlip
         ELSE
            SET @cSQL =
               ' SELECT TOP 1 ' + 
                  ' @cPickDetailKey = PD.PickDetailKey, ' + 
                  ' @cPD_ID = PD.ID, ' + 
                  ' @cPD_LOT = PD.LOT, ' + 
                  ' @nPD_QTY = PD.QTY ' +
               ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
               '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
               '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
               ' WHERE PD.PickSlipNo = @cPickSlipNo ' +
               '    AND PD.LOC = @cLOC ' +
               '    AND PD.SKU = @cSKU ' +
               '    AND PD.QTY > 0 ' +
               '    AND PD.Status <> ''4'' ' +
               '    AND PD.Status < @cPickConfirmStatus ' +
                 CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END + 
            ' ORDER BY CASE WHEN PD.LOT = @cSerial_LOT AND PD.ID = @cSerial_ID THEN 1 ELSE 2 END '

         SET @cSQLParam =
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
            ' @dLottable15 DATETIME,      ' +
            ' @cSerial_LOT NVARCHAR( 10), ' +
            ' @cSerial_ID  NVARCHAR( 18), ' +  
            ' @cPickDetailKey NVARCHAR( 10) OUTPUT, ' +
            ' @cPD_ID      NVARCHAR( 18)    OUTPUT, ' + 
            ' @cPD_LOT     NVARCHAR( 10)    OUTPUT, ' + 
            ' @nPD_QTY     INT              OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cPickSlipNo, @cOrderKey, @cLoadKey, @cLOC, @cDropID, @cSKU, @cPickConfirmStatus,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
            @cSerial_LOT, @cSerial_ID, 
            @cPickDetailKey OUTPUT, @cPD_ID OUTPUT, @cPD_LOT OUTPUT, @nPD_QTY OUTPUT
            
         -- Check pick task
         IF @cPickDetailKey = ''
         BEGIN
            SET @nErrNo = 204804
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No pick task
            GOTO RollBackTran
         END

         -- Split PickDetail
         IF @nPD_QTY > @nSerialQTY
         BEGIN
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
               SET @nErrNo = 204805
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
               @nPD_QTY - @nSerialQTY, -- QTY
               NULL, -- TrafficCop
               '1',   -- OptimizeCop
               Channel_ID --(cc01)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204806
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
                  SET @nErrNo = 204807
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                  GOTO RollBackTran
               END
            END

            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nSerialQTY,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204808
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
         END
      END     
      
      -- Swap serial no (if LOT or ID different)
      IF @cPD_ID <> @cSerial_ID OR
         @cPD_LOT <> @cSerial_LOT
      BEGIN
         -- Check swap serial no allow
         IF rdt.RDTGetConfig( @nFunc, 'SwapSerialNo', @cStorerKey) = '0'
         BEGIN
            SET @nErrNo = 204832
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SN ID LOT Diff
            GOTO RollBackTran
         END
         
         /*
            1. Task swap with free SN
            2. Task swap with alloc SN
         */
         
         DECLARE @nQTYAvail INT
         SELECT @nQTYAvail = ISNULL( SUM( QTY-QTYAllocated-QTYPicked), 0)
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE LOT = @cSerial_LOT
            AND LOC = @cLOC
            AND ID = @cSerial_ID
         
         -- 1. Task swap with free SN
         IF @nQTYAvail >= @nSerialQTY
         BEGIN
            -- Unalloc
            UPDATE dbo.PickDetail SET
               QTY = 0, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 204809
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
            
            -- Realloc
            UPDATE dbo.PickDetail SET
               LOT = @cSerial_LOT,
               ID = @cSerial_ID, 
               QTY = @nSerialQTY, 
               -- Status = @cPickConfirmStatus, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 204810
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
         END
         
         -- 2. Task swap with alloc SN
         ELSE
         BEGIN
            -- Get SN PickDetail (Actual)
            DECLARE @cActPickDetailKey NVARCHAR( 10) = ''
            DECLARE @nActQTY INT
            SELECT TOP 1 
               @cActPickDetailKey = PickDetailKey, 
               @nActQTY = QTY
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE LOT = @cSerial_LOT
               AND LOC = @cLOC
               AND ID = @cSerial_ID
               AND QTY >= @nSerialQTY
               AND Status < @cPickConfirmStatus
            
            IF @cActPickDetailKey = ''
            BEGIN
               SET @nErrNo = 204811
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SN No PKDtl
               GOTO RollBackTran
            END
            
            -- Split actual PickDetail
            IF @nActQTY > @nSerialQTY
            BEGIN
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
                  SET @nErrNo = 204812
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
                  @nActQTY - @nSerialQTY, -- QTY
                  NULL, -- TrafficCop
                  '1',   -- OptimizeCop
                  Channel_ID --(cc01)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cActPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 204813
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                  GOTO RollBackTran
               END

               -- Split RefKeyLookup
               IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cActPickDetailKey)
               BEGIN
                  -- Insert into
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                  SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                  FROM RefKeyLookup WITH (NOLOCK)
                  WHERE PickDetailKey = @cActPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 204814
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                     GOTO RollBackTran
                  END
               END

               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nSerialQTY,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  Trafficcop = NULL
               WHERE PickDetailKey = @cActPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 204815
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END
            END
            
            -- Unalloc
            -- Task
            UPDATE dbo.PickDetail SET
               QTY = 0, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 204816
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
            
            -- Actual
            UPDATE dbo.PickDetail SET
               QTY = 0, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cActPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 204817
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
            
            -- Realloc
            -- Task
            UPDATE dbo.PickDetail SET
               LOT = @cSerial_LOT,
               ID = @cSerial_ID, 
               QTY = @nSerialQTY, 
               -- Status = @cPickConfirmStatus, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 204818
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
            
            -- Actual
            UPDATE dbo.PickDetail SET
               LOT = @cPD_LOT,
               ID = @cPD_ID, 
               QTY = @nSerialQTY, 
               -- Status = @cPickConfirmStatus, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cActPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 204819
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
         END
      END
      
      -- Confirm PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         Status = @cPickConfirmStatus,
         DropID = @cDropID,
         EditDate = GETDATE(),
         EditWho  = SUSER_SNAME()
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 204820
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
         GOTO RollBackTran
      END
      
      -- Insert PickSerialNo
      INSERT INTO PickSerialNo (PickDetailKey, StorerKey, SKU, SerialNo, QTY)
      VALUES (@cPickDetailKey, @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 204821
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RDSNo Fail
         GOTO RollBackTran
      END
      
      -- Posting to serial no
      UPDATE dbo.SerialNo SET
         Status = '5', 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND SerialNo = @cSerialNo
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 204822
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD SNO Fail
         GOTO RollBackTran
      END      
   END

/*--------------------------------------------------------------------------------------------------
                                                Non serial SKU
--------------------------------------------------------------------------------------------------*/
   ELSE
   BEGIN
      DECLARE @nQTY_Bal INT
      DECLARE @nQTY_PD  INT

      -- For calculation
      SET @nQTY_Bal = @nQTY

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
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_839Confirm13 -- For rollback or commit only our own transaction

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
               SET @nErrNo = 204823
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
               SET @nErrNo = 204824
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
                     SET @nErrNo = 204825
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END
               END
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
                  SET @nErrNo = 204826
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
                  SET @nErrNo = 204827
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
                     SET @nErrNo = 204828
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
                  SET @nErrNo = 204829
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
                  SET @nErrNo = 204830
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
                     SET @nErrNo = 204831
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END
               END

               SET @nQTY_Bal = 0 -- Reduce balance
            END
         END

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      END
   END
   
   COMMIT TRAN rdt_839Confirm13

   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '3', -- Picking
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
      @cDropID       = @cDropID, 
      @cSerialNo     = @cSerialNo

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_839Confirm13 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
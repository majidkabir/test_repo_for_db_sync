SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: [rdt_830PickVLT]                                    */
/* Copyright: Maersk                                                    */
/*                                                                      */
/*                                                                      */
/* Date         Author     Purposes                                     */
/* 21/03/2024   PPA374     Checks that "TO LOC" is as expected          */
/* 11/07/2024   PPA374     Captures the location that pick is done from */
/* 02/07/2025   PPA374     UWP-29797 PE Code Review                     */
/************************************************************************/

CREATE   PROC [RDT].[rdt_830PickVLT] (
   @nMobile       INT,            
   @nFunc         INT,            
   @cLangCode     NVARCHAR( 3),   
   @nStep         INT,            
   @nInputKey     INT,            
   @cFacility     NVARCHAR( 5),    
   @cStorerKey    NVARCHAR( 15),  
   @cType         NVARCHAR( 10),   
   @cPickSlipNo   NVARCHAR( 10),  
   @cPickZone     NVARCHAR( 10),  
   @cLOC          NVARCHAR( 10),  
   @cDropID       NVARCHAR( 20),  
   @cID           NVARCHAR( 18),  
   @cSKU          NVARCHAR( 20),  
   @nQTY          INT,            
   @cToLOC        NVARCHAR( 10),  
   @cLottableCode NVARCHAR( 20),   
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
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   IF @nstep = 5 AND @nFunc = 830 AND @cStorerKey = @cStorerKey
   BEGIN

         IF EXISTS 
         (SELECT TOP 1 loc FROM loc (NOLOCK) WHERE facility = @cFacility
         AND PutawayZone in 
         (SELECT code FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'VNAZONHUSQ' and Storerkey = @cStorerKey) 
         AND LocationType = 'OTHER' AND loc = @cLOC)
         AND @cToLOC <> (SELECT TOP 1 loc FROM loc (NOLOCK) WHERE facility = @cFacility AND LocAisle = (SELECT TOP 1 LocAisle FROM loc (NOLOCK) WHERE loc = @cLOC and Facility = @cFacility) AND loc like 'B_999%' AND LocationCategory = 'PND_OUT')
         BEGIN
            SET @nErrNo = -1
            SET @cErrMsg = 'Pick to '+reverse(substring(REVERSE((SELECT TOP 1 loc FROM loc (NOLOCK) WHERE facility = @cFacility AND LocAisle = (SELECT TOP 1 LocAisle FROM loc (NOLOCK) WHERE loc = @cLOC and Facility = @cFacility) AND loc like 'B_999%' AND LocationCategory = 'PND_OUT')),4,10))
            GOTO QUIT
         END
         ELSE IF NOT EXISTS
         (SELECT TOP 1 loc FROM loc (NOLOCK) WHERE facility = @cFacility AND PutawayZone in 
         (SELECT code FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'VNAZONHUSQ' and Storerkey = @cStorerKey) AND LocationType = 'OTHER' AND loc = @cLOC)
         AND @cToLOC <> (SELECT TOP 1 OtherReference FROM mbol (NOLOCK) WHERE facility = @cFacility and mbolkey = (SELECT TOP 1 mbolkey FROM ORDERS (NOLOCK) WHERE StorerKey = @cStorerKey and orderkey = (SELECT TOP 1 orderkey FROM PICKHEADER (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)))
         BEGIN
            SET @nErrNo = -1
            SET @cErrMsg = 'Pick to '+reverse(substring(REVERSE((SELECT TOP 1 OtherReference FROM mbol (NOLOCK) WHERE Facility = @cFacility and mbolkey = (SELECT TOP 1 mbolkey FROM ORDERS (NOLOCK) WHERE StorerKey = @cStorerKey and orderkey = (SELECT TOP 1 orderkey FROM PICKHEADER (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)))),4,10))
            GOTO QUIT
         END
            
   END

   BEGIN
   /***********************************************************************************************
                                                Standard confirm
      ***********************************************************************************************/
      DECLARE @cSQL      NVARCHAR( MAX)
      DECLARE @cSQLParam NVARCHAR( MAX)
      DECLARE @cUserName NVARCHAR(18)  
      DECLARE @bSuccess       INT
      DECLARE @cOrderKey      NVARCHAR( 10)
      DECLARE @cLoadKey       NVARCHAR( 10)
      DECLARE @cZone          NVARCHAR( 18)
      DECLARE @cPickDetailKey NVARCHAR( 18)
      DECLARE @cPickConfirmStatus NVARCHAR( 1)
      DECLARE @cShortStatus   NVARCHAR( 1)
      DECLARE @cSourceType    NVARCHAR( 30)
      DECLARE @cMoveRefKey    NVARCHAR( 10)
      DECLARE @cLOT           NVARCHAR( 10)
      DECLARE @cPackKey       NVARCHAR( 10)
      DECLARE @cPackUOM3      NVARCHAR( 10)
      DECLARE @nQTY_Move      INT
      DECLARE @nQTY_Bal       INT
      DECLARE @nQTY_PD        INT
      DECLARE @cWhere         NVARCHAR( MAX)
      DECLARE @curPD          CURSOR
      DECLARE @cToID          NVARCHAR( 18)

      DECLARE @cMoveToDropID     NVARCHAR( 1)
      DECLARE @cUpdatePackDetail NVARCHAR( 1)
      DECLARE @cVerifyID         NVARCHAR( 1)

      SET @cSourceType = 'rdt_PickSKU_Confirm'
      SET @cOrderKey = ''
      SET @cLoadKey = ''
      SET @cZone = ''
      
      -- Balance status
      IF @cType = 'SHORT' 
         SET @cShortStatus = '4'
      ELSE
         SET @cShortStatus = '0'
      
      -- Get storer config
      SET @cMoveToDropID = rdt.RDTGetConfig( @nFunc, 'MoveToDropID', @cStorerKey)
      SET @cUpdatePackDetail = rdt.RDTGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey) 
      SET @cVerifyID = rdt.RDTGetConfig( @nFunc, 'VerifyID', @cStorerKey)

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

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
         SET @cSQL = 
            ' SELECT PD.PickDetailKey, PD.QTY ' + 
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK)' + 
               ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)' + 
               ' JOIN dbo.Loc LOC WITH (NOLOCK) ON (LOC.LOC=PD.LOC)'+ --(yeekung03)
               ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' + 
               ' AND PD.LOC = @cLOC ' + 
               CASE WHEN @cVerifyID = '1' THEN ' AND PD.ID = @cID ' ELSE '' END + 
               ' AND PD.SKU = @cSKU ' + 
               ' AND PD.QTY > 0' + 
               ' AND PD.Status <> ''4''' + 
               ' AND PD.Status < @cPickConfirmStatus ' + 
               CASE WHEN @cPickZone <>'' THEN ' AND LOC.PickZone = @cPickZone ' ELSE '' END + 
               CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
         SET @cSQL = 
            ' SELECT PD.PickDetailKey, PD.QTY ' + 
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
               ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' + 
               ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
            ' WHERE PD.OrderKey = @cOrderKey ' + 
               ' AND PD.LOC = @cLOC ' + 
               CASE WHEN @cVerifyID = '1' THEN ' AND PD.ID = @cID ' ELSE '' END + 
               ' AND PD.SKU = @cSKU ' + 
               ' AND PD.QTY > 0' + 
               ' AND PD.Status <> ''4''' + 
               ' AND PD.Status < @cPickConfirmStatus ' + 
               CASE WHEN @cPickZone <>'' THEN ' AND LOC.PickZone = @cPickZone ' ELSE '' END + 
               CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
         SET @cSQL = 
            ' SELECT PD.PickDetailKey, PD.QTY ' + 
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
               ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' + 
               ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' + 
               ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
            ' WHERE LPD.LoadKey = @cLoadKey ' + 
               ' AND PD.LOC = @cLOC ' + 
               CASE WHEN @cVerifyID = '1' THEN ' AND PD.ID = @cID ' ELSE '' END + 
               ' AND PD.SKU = @cSKU ' + 
               ' AND PD.QTY > 0' + 
               ' AND PD.Status <> ''4''' + 
               ' AND PD.Status < @cPickConfirmStatus ' + 
               CASE WHEN @cPickZone <>'' THEN ' AND LOC.PickZone = @cPickZone ' ELSE '' END + 
               CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END

      -- Custom PickSlip
      ELSE
         SET @cSQL = 
            ' SELECT PD.PickDetailKey, PD.QTY ' + 
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
               ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' + 
               ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
            ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
               ' AND PD.LOC = @cLOC ' + 
               CASE WHEN @cVerifyID = '1' THEN ' AND PD.ID = @cID ' ELSE '' END + 
               ' AND PD.SKU = @cSKU ' + 
               ' AND PD.QTY > 0' + 
               ' AND PD.Status <> ''4''' + 
               ' AND PD.Status < @cPickConfirmStatus ' + 
               CASE WHEN @cPickZone <>'' THEN ' AND LOC.PickZone = @cPickZone ' ELSE '' END + 
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
         ' @cPickZone   NVARCHAR( 10), ' + 
         ' @cLOC        NVARCHAR( 10), ' + 
         ' @cID         NVARCHAR( 18), ' +  
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

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @curPD OUTPUT, @cPickSlipNo, @cOrderKey, @cLoadKey, @cPickZone, @cLOC, @cID, @cSKU, @cPickConfirmStatus, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
            
      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_PickSKU_Confirm -- For rollback or commit only our own transaction

      -- Loop PickDetail
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @cToLOC <> '' AND @nQTY > 0
         BEGIN
            -- Get new MoveRefKey
            EXECUTE dbo.nspg_GetKey
               'MOVEREFKEY',
               10 ,
               @cMoveRefKey OUTPUT,
               @bSuccess    OUTPUT,
               @nErrNo      OUTPUT,
               @cErrMsg     OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 217918
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKeyFail
               GOTO RollBackTran
            END
         END

         -- Exact match
         IF @nQTY_PD = @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus,
               MoveRefKey = @cMoveRefKey, 
               DropID = @cDropID, 
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
			and Storerkey = @cStorerKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 217919
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDPKDtlFail
               GOTO RollBackTran
            END
            
            SET @nQTY_Move = @nQTY_PD
            SET @nQTY_Bal = 0 -- Reduce balance

         END

         -- PickDetail have less
         ELSE IF @nQTY_PD < @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus,
               MoveRefKey = @cMoveRefKey, 
               DropID = @cDropID, 
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
			and Storerkey = @cStorerKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 217920
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDPKDtlFail
               GOTO RollBackTran
            END
            
            SET @nQTY_Move = @nQTY_PD
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
                  Status = @cShortStatus,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
			   AND Storerkey = @cStorerKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 217921
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDPKDtlFail
                  GOTO RollBackTran
               END
               SET @nQTY_Move = 0

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
                  SET @nErrNo = 217922
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetKeyFail
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
                  CaseID, @cPickSlipNo--PickHeaderKey
               , OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, 
                  CASE WHEN DropID = '' THEN Notes ELSE @cLOC END,--Notes,
                  @cNewPickDetailKey,
                  Status, 
                  @nQTY_PD - @nQTY_Bal, -- QTY
                  NULL, -- TrafficCop
                  '1'   -- OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 217923
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INSPKDtlFail
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
                     SET @nErrNo = 217924
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INSRefKeyFail
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
                  SET @nErrNo = 217925
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDPKDtlFail
                  GOTO RollBackTran
               END
      
               -- Confirm orginal PickDetail with exact QTY
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = @cPickConfirmStatus,
                  MoveRefKey = @cMoveRefKey, 
                  DropID = @cDropID, 
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 217926
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDPKDtlFail
                  GOTO RollBackTran
               END
      
               SET @nQTY_Move = @nQTY_Bal
               SET @nQTY_Bal = 0 -- Reduce balance

            END
         END

         -- Move PickDetail
         IF @cToLOC <> '' AND @nQTY_Move > 0
         BEGIN
            -- Get PickDetail info
            SELECT 
               @cLOT = LOT, 
               @cID = CASE WHEN @cVerifyID = '1' THEN @cID ELSE ID END
            FROM PickDetail WITH (NOLOCK) 
            WHERE PickDetailKey = @cPickDetailKey

            -- (james01)
            IF @cMoveToDropID = '1' AND ISNULL( @cMoveToDropID, '') <> ''
               SET @cToID = @cDropID
            ELSE
               SET @cToID = @cID
                        
            -- Get SKU info
            SELECT 
               @cPackKey = SKU.PackKey, 
               @cPackUOM3 = Pack.PackUOM3
            FROM SKU WITH (NOLOCK)
               JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
            
            -- Move LOTxLOCxID
            EXEC dbo.nspItrnAddMove
               @n_ItrnSysId     = NULL          -- int
               , @c_StorerKey     = @cStorerKey   -- NVARCHAR(15)
               , @c_Sku           = @cSKU         -- NVARCHAR(20)
               , @c_Lot           = @cLOT         -- NVARCHAR(10)
               , @c_FromLoc       = @cLOC         -- NVARCHAR(10)
               , @c_FromID        = @cID          -- NVARCHAR(18)
               , @c_ToLoc         = @cToLOC       -- NVARCHAR(10)
               , @c_ToID          = @cToID        -- NVARCHAR(18)
               , @c_Status        = ''            -- NVARCHAR(10)
               , @c_lottable01    = ''            -- NVARCHAR(18)
               , @c_lottable02    = ''            -- NVARCHAR(18)
               , @c_lottable03    = ''            -- NVARCHAR(18)
               , @d_lottable04    = ''            -- datetime
               , @d_lottable05    = ''            -- datetime
               , @n_casecnt       = 0             -- int
               , @n_innerpack     = 0             -- int
               , @n_qty           = @nQTY_Move    -- int
               , @n_pallet        = 0             -- int
               , @f_cube          = 0             -- float
               , @f_grosswgt      = 0             -- float
               , @f_netwgt        = 0             -- float
               , @f_otherunit1    = 0             -- float
               , @f_otherunit2    = 0             -- float
               , @c_SourceKey     = ''            -- NVARCHAR(20)
               , @c_SourceType    = @cSourceType  -- NVARCHAR(30)
               , @c_PackKey       = @cPackKey     -- NVARCHAR(10)
               , @c_UOM           = @cPackUOM3    -- NVARCHAR(10)
               , @b_UOMCalc       = 1             -- int
               , @d_EffectiveDate = ''            -- datetime
               , @c_itrnkey       = ''            -- NVARCHAR(10)   OUTPUT
               , @b_Success       = @bSuccess     -- int        OUTPUT
               , @n_err           = @nErrNo       -- int        OUTPUT
               , @c_errmsg        = @cErrMsg      -- NVARCHAR(250)  OUTPUT
               , @c_MoveRefKey    = @cMoveRefKey
      
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
         END

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      END
      
      CLOSE @curPD  --(yeekung02)
      DEALLOCATE @curPD
      
     UPDATE dbo.PickDetail WITH (ROWLOCK) SET
     Notes = @cLOC,
     Pickheaderkey = @cPickSlipNo
     WHERE DropID = @cDropID and DropID <> ''
	 and Storerkey = @cStorerKey
     and ISNULL(notes,'')=''

      /***********************************************************************************************
                                                PackDetail
      ***********************************************************************************************/
      IF @cUpdatePackDetail = '1' AND @cDropID <> '' -- 1 drop ID = 1 carton
      BEGIN
         DECLARE @nCartonNo   INT = 0
         DECLARE @cLabelLine  NVARCHAR(5) = ''
         DECLARE @cNewLine    NVARCHAR(1) = 'N'
         
         -- PackHeader
         IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            DECLARE @cConsigneeKey NVARCHAR( 15) = ''
            IF @cOrderKey <> ''
               SELECT @cConsigneeKey = ConsigneeKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey and StorerKey = @cStorerKey

            INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, ConsigneeKey, LoadKey)
            VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cConsigneeKey, @cLoadKey)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 217927
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPHdrFail
               GOTO RollBackTran
            END
         END
         
         -- Get CartonNo, LabelLine
         BEGIN
            SELECT 
               @nCartonNo = CartonNo, 
               @cLabelLine = LabelLine
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo 
               AND LabelNo = @cDropID
               AND SKU = @cSKU
			   AND StorerKey = @cStorerKey
            
            IF @cLabelLine = ''
            BEGIN
               SELECT @nCartonNo = CartonNo
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo 
                  AND LabelNo = @cDropID 
				  AND StorerKey = @cStorerKey
            
               IF @nCartonNo = 0
                  SET @cLabelLine = '00000'
               ELSE
                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5) 
                  FROM dbo.PackDetail (NOLOCK)
                  WHERE Pickslipno = @cPickSlipNo
                     AND LabelNo = @cDropID
					 AND StorerKey = @cStorerKey

               SET @cNewLine = 'Y'
            END
         END
         
         -- PackDetail
         IF @cNewLine = 'Y'
         BEGIN
            -- Insert PackDetail
            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, 
               AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cDropID, @cLabelLine, @cStorerKey, @cSKU, @nQTY, 
               'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 217928
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackDtlFail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            -- Update Packdetail
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET   
               SKU = @cSKU, 
               QTY = QTY + @nQTY, 
               EditWho = 'rdt.' + SUSER_SNAME(), 
               EditDate = GETDATE(), 
               ArchiveCop = NULL
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cDropID
               AND LabelLine = @cLabelLine
			   AND StorerKey = @cStorerKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 217929
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail
               GOTO RollBackTran
            END
         END

         -- PackInfo
         IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
         BEGIN
            INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, QTY)
            VALUES (@cPickSlipNo, @nCartonNo, @nQTY)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 217929
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            UPDATE dbo.PackInfo SET
               QTY = QTY + @nQTY, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               TrafficCop = NULL
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 217930
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
               GOTO RollBackTran
            END
         END
      END
      
      -- EventLog
      EXEC RDT.rdt_STD_EventLog      
         @cActionType   = '3', -- Picking      
         @nMobileNo     = @nMobile,      
         @nFunctionID   = @nFunc,     
         @cFacility     = @cFacility,      
         @cStorerKey    = @cStorerkey,      
         @cPickSlipNo   = @cPickSlipNo, 
         @cLocation     = @cLOC,      
         @cSKU          = @cSKU ,      
         @cUOM          = @cPackUOM3,      
         @nQTY          = @nQTY,      
         @cOrderKey     = @cOrderKey,
         @cRefNo1       = @cOrderKey,  -- Retain for backward compatible      
         @cRefNo2       = @cPickSlipNo -- Retain For backward compatible 
   
      COMMIT TRAN rdt_PickSKU_Confirm
      GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_PickSKU_Confirm -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END
END

GO
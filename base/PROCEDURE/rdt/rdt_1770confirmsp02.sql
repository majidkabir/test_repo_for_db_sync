SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1770ConfirmSP02                                    */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Date        Rev   Author    Purposes                                    */
/* 2014-08-21  1.0   Ung       WMS-26055 base rdt_TM_PalletPick_Confirm    */
/* 2024-10-15  1.1   CheeMun   INC7331096 - Insert PalletDetail for        */
/*                                         multiple lines of caseID        */
/* 2024-12-09  1.2   PXL009    FCR-1124 Merged 1.0,1.1 from v0 branch      */
/***************************************************************************/

CREATE   PROC [rdt].[rdt_1770ConfirmSP02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTaskDetailKey NVARCHAR( 10),
   @cDropID        NVARCHAR( 20),
   @nQTY           INT,
   @cFinalLOC      NVARCHAR( 10),
   @cReasonKey     NVARCHAR( 10),
   @cListKey       NVARCHAR( 10),
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT,
   @cDebug         NVARCHAR( 1) = NULL
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @cTaskType      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cMoveRefKey    NVARCHAR( 10)
   DECLARE @cStatus        NVARCHAR( 10)
   DECLARE @nTaskQTY       INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Move      INT
   DECLARE @cMoveQTYAlloc  NVARCHAR( 1)
   DECLARE @cMoveQTYPick   NVARCHAR( 1)
   DECLARE @nQTYAlloc      INT
   DECLARE @nQTYPick       INT
   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cSKU           NVARCHAR( 15)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cPalletLineNumber NVARCHAR( 5)  --INC7331096

   -- Init var
   SET @nQTY_Move = 0
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get task info
   SELECT
      @cTaskType = TaskType,
      @nTaskQTY = QTY,
      @cStatus = Status,
      @cFromLOC = FromLOC,
      @cLOT = LOT,
      @cPickMethod = PickMethod
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Check task already SKIP/CANCEL
   IF @cStatus IN ('0', 'X')
      RETURN

   -- Get storer config
   SET @cMoveQTYAlloc = rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   -- Check move alloc, but picked
   IF @cMoveQTYAlloc = '1' AND @cPickConfirmStatus = '5'
   BEGIN
      SET @nErrNo = 221451
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IncorrectSetup
      GOTO Quit
   END

   -- Check move picked, but not pick confirm
   IF @cMoveQTYPick = '1' AND @cPickConfirmStatus < '5'
   BEGIN
      SET @nErrNo = 221452
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IncorrectSetup
      GOTO Quit
   END

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1770ConfirmSP02 -- For rollback or commit only our own transaction

   IF @cTaskType = 'FPK' -- need to update PickDetail
   BEGIN
      -- For calculation
      SET @nQTY_Bal = @nQTY

      -- Get PickDetail candidate
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey, QTY, LOC, ID, SKU
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cFromLOC, @cFromID, @cSKU
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Exact match
         IF @nQTY_PD = @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus,
               DropID = CASE WHEN @cDropID = '' THEN DropID ELSE @cDropID END,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 221453
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
               GOTO RollBackTran
            END

            SET @nQTY_Move = @nQTY_Move + @nQTY_PD
            SET @nQTY_Bal = 0 -- Reduce balance
         END

         -- PickDetail have less
         ELSE IF @nQTY_PD < @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus,
               DropID = CASE WHEN @cDropID = '' THEN DropID ELSE @cDropID END,
               -- TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 221454
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
               GOTO RollBackTran
            END

            SET @nQTY_Move = @nQTY_Move + @nQTY_PD
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
                  TaskDetailKey = '',
                  TrafficCop = NULL,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 221455
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
                  GOTO RollBackTran
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
                  SET @nErrNo = 221456
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetDetKey Fail
                  GOTO RollBackTran
               END

               -- Create new a PickDetail to hold the balance
               INSERT INTO dbo.PICKDETAIL (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,
                  PickDetailKey,
                  QTY,
                  Status,
                  TrafficCop,
                  OptimizeCop)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,
                  @cNewPickDetailKey,
                  @nQTY_PD - @nQTY_Bal, -- QTY
                  -- CASE WHEN @cShort = 'Y' THEN '4' ELSE '0' END, -- Status
                  '4', -- Short
                  NULL, --TrafficCop,
                  '1'  --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 221457
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PDtl Fail
                  GOTO RollBackTran
               END

               -- Split RefKeyLookup
               IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
               BEGIN
                  -- Insert RefKeyLookup
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                  SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                  FROM RefKeyLookup WITH (NOLOCK)
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 221458
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsRefKeyFail
                     GOTO RollBackTran
                  END
               END

               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nQTY_Bal,
                  DropID = CASE WHEN @cDropID = '' THEN DropID ELSE @cDropID END,
                  Trafficcop = NULL,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 221459
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
                  GOTO RollBackTran
               END

               -- Confirm orginal PickDetail with exact QTY
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = @cPickConfirmStatus,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 221460
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
                  GOTO RollBackTran
               END

               -- Short pick
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = '4',
                  TaskDetailKey = '',
                  TrafficCop = NULL,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
               WHERE PickDetailKey = @cNewPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 221461
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
                  GOTO RollBackTran
               END

               SET @nQTY_Move = @nQTY_Move + @nQTY_Bal
               SET @nQTY_Bal = 0 -- Reduce balance
            END
         END

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cFromLOC, @cFromID, @cSKU
      END

      -- Check offset
      IF @nQTY_Bal <> 0
      BEGIN
         SET @nErrNo = 221462
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error
         GOTO RollBackTran
      END

      -- Move PickDetail
      IF (@cMoveQTYAlloc = '1' OR @cMoveQTYPick = '1') AND @nQTY_Move > 0
      BEGIN
         -- Calc alloc or pick
         IF @cPickConfirmStatus = '5'
         BEGIN
            SET @nQTYAlloc = 0
            SET @nQTYPick = @nQTY_Move
         END
         ELSE
         BEGIN
            SET @nQTYAlloc = @nQTY_Move
            SET @nQTYPick = 0
         END

         IF @cLOT = ''
            SET @cLOT = NULL

         IF @nTaskQTY = @nQTY AND @cPickMethod = 'FP'
            -- Move by ID
            EXECUTE rdt.rdt_Move
               @nMobile        = @nMobile,
               @cLangCode      = @cLangCode,
               @nErrNo         = @nErrNo  OUTPUT,
               @cErrMsg        = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType    = 'rdt_1770ConfirmSP02',
               @cStorerKey     = @cStorerKey,
               @cFacility      = @cFacility,
               @cFromLOC       = @cFromLOC,
               @cToLOC         = @cFinalLOC,
               @cFromID        = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID          = @cFromID,     -- NULL means not changing ID. Blank consider a valid ID
               @nQTYAlloc      = @nQTYAlloc,
               @nQTYPick       = @nQTYPick,
               @cTaskDetailKey = @cTaskDetailKey,
               @nFunc          = @nFunc
         ELSE
            -- Move by SKU
            EXECUTE rdt.rdt_Move
               @nMobile        = @nMobile,
               @cLangCode      = @cLangCode,
               @nErrNo         = @nErrNo  OUTPUT,
               @cErrMsg        = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType    = 'rdt_1770ConfirmSP02',
               @cStorerKey     = @cStorerKey,
               @cFacility      = @cFacility,
               @cFromLOC       = @cFromLOC,
               @cToLOC         = @cFinalLOC,
               @cFromID        = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID          = @cFromID,     -- NULL means not changing ID. Blank consider a valid ID
               @cSKU           = @cSKU,
               @nQTY           = @nQTY,
               @cFromLOT       = @cLOT,
               @nQTYAlloc      = @nQTYAlloc,
               @nQTYPick       = @nQTYPick,
               @cTaskDetailKey = @cTaskDetailKey,
               @nFunc          = @nFunc
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Update Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         Status = '9', -- Closed
         DropID = @cDropID,
         QTY = @nQTY,
         ToLOC = @cFinalLOC,
         ReasonKey = @cReasonKey,
         EndTime = GETDATE(),
         EditDate = GETDATE(),
         EditWho  = @cUserName,
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 221463
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail
         GOTO RollBackTran
      END
   END

   -- TaskType = FPK1 (don't need to update PickDetail)
   ELSE
   BEGIN
      IF (@cMoveQTYAlloc = '1' OR @cMoveQTYPick = '1')
      BEGIN
         -- Move PickDetail
         EXECUTE rdt.rdt_Move
            @nMobile        = @nMobile,
            @cLangCode      = @cLangCode,
            @nErrNo         = @nErrNo  OUTPUT,
            @cErrMsg        = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
            @cSourceType    = 'rdt_1770ConfirmSP02',
            @cStorerKey     = @cStorerKey,
            @cFacility      = @cFacility,
            @cFromLOC       = @cFromLOC,
            @cToLOC         = @cFinalLOC,
            @cFromID        = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
            @cToID          = @cFromID,     -- NULL means not changing ID. Blank consider a valid ID
            @nFunc          = @nFunc
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Update Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         Status = '9', -- Closed
         ToLOC = @cFinalLOC,
         ReasonKey = @cReasonKey,
         EndTime = GETDATE(),
         EditDate = GETDATE(),
         EditWho  = @cUserName,
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 221464
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail
         GOTO RollBackTran
      END
   END

   /***********************************************************************************************
                                              Customization
   ***********************************************************************************************/
   IF @cTaskType = 'FPK'
   BEGIN
      DECLARE @cPickSlipNo NVARCHAR( 10)
      DECLARE @nCartonNo   INT
      DECLARE @cLabelNo    NVARCHAR( 20)
      DECLARE @cOrderKey   NVARCHAR( 10)
      DECLARE @nPackQTY INT

      -- Get pallet info
      DECLARE @cPalletType NVARCHAR( 30)
      DECLARE @nLength FLOAT
      DECLARE @nWidth FLOAT
      DECLARE @nHeight FLOAT
      SELECT
         @cPalletType = ISNULL( PalletType, ''),
         @nLength = Length,
         @nWidth = Width,
         @nHeight = Height
      FROM dbo.Pallet WITH (NOLOCK)
      WHERE PalletKey = @cFromID

      -- Pallet
      IF @@ROWCOUNT = 0
      BEGIN
         INSERT dbo.Pallet (PalletKey, StorerKey, PalletType, GrossWgt)
         SELECT TOP 1
            @cFromID, @cStorerKey, Pallet_Type, MaxWgt
         FROM dbo.PalletMaster WITH (NOLOCK)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 221465
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPLTHdrFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         IF @nLength = 0 AND
            @nWidth = 0 AND
            @nHeight = 0
         BEGIN
            -- Get pallet type info
            DECLARE @cUDF01 NVARCHAR( 60)
            DECLARE @cUDF02 NVARCHAR( 60)
            DECLARE @cUDF03 NVARCHAR( 60)
            SELECT
               @cUDF01 = ISNULL( UDF01, ''),
               @cUDF02 = ISNULL( UDF02, ''),
               @cUDF03 = ISNULL( UDF03, '')
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'PALLETDIMS'
               AND Code = @cPalletType
               AND StorerKey = @cStorerKey

            UPDATE dbo.Pallet SET
               Length = TRY_CAST( @cUDF01 AS FLOAT),
               Width = TRY_CAST( @cUDF02 AS FLOAT),
               Height = TRY_CAST( @cUDF03 AS FLOAT),
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME(),
               TrafficCop = NULL
            WHERE PalletKey = @cFromID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 221466
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPLTHdrFail
               GOTO RollBackTran
            END
         END
      END

      -- Loop order in pallet
      SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT OrderKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cOrderKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- PackHeader
         SET @cPickSlipNo = ''
         SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         -- Get new pick slip no
         IF @cPickSlipNo = ''
         BEGIN
            EXECUTE dbo.nspg_GetKey
               'PICKSLIP',
               9,
               @cPickSlipNo   OUTPUT,
               @bSuccess      OUTPUT,
               @nErrNo        OUTPUT,
               @cErrMsg       OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran

            SET @cPickSlipNo = 'P' + @cPickSlipNo

            INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, Status)
            VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, '0')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 221467
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackHdrFail
               GOTO RollBackTran
            END
         END

         -- PackDetail
         BEGIN
            SET @nCartonNo = 0
            SET @cLabelNo  = ''

            -- New carton, generate labelNo
            DECLARE @cGenLabelNo_SP NVARCHAR( 20)
            SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)
            IF @cGenLabelNo_SP = '0'
               SET @cGenLabelNo_SP = ''

            IF @cGenLabelNo_SP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')
               BEGIN
                  DECLARE @cSQL NVARCHAR( MAX)
                  DECLARE @cSQLParam NVARCHAR( MAX)

                  SET @cSQL = 'EXEC dbo.' + RTRIM( @cGenLabelNo_SP) +
                     ' @cPickslipNo, ' +
                     ' @nCartonNo,   ' +
                     ' @cLabelNo     OUTPUT '
                  SET @cSQLParam =
                     ' @cPickslipNo  NVARCHAR(10),       ' +
                     ' @nCartonNo    INT,                ' +
                     ' @cLabelNo     NVARCHAR(20) OUTPUT '
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @cPickslipNo,
                     @nCartonNo,
                     @cLabelNo OUTPUT
               END
            END
            ELSE
            BEGIN
               EXEC isp_GenUCCLabelNo
                  @cStorerKey,
                  @cLabelNo      OUTPUT,
                  @bSuccess      OUTPUT,
                  @nErrNo        OUTPUT,
                  @cErrMsg       OUTPUT
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 221468
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
                  GOTO RollBackTran
               END
            END

            IF @cLabelNo = ''
            BEGIN
               SET @nErrNo = 221469
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No LabelNo
               GOTO RollBackTran
            END

            DECLARE @nLabelLine INT = 1
            DECLARE @cLabelLine NVARCHAR( 5)
            DECLARE @curSKU CURSOR
            SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD (NOLOCK)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.OrderKey = @cOrderKey
                  AND PD.Status <= '5'
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND PD.TaskDetailKey = @cTaskDetailKey
               GROUP BY PD.SKU
            OPEN @curSKU
            FETCH NEXT FROM @curSKU INTO @cSKU, @nQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF @nCartonNo = 0
                  SET @cLabelLine = '00000'
               ELSE
                  SET @cLabelLine = FORMAT( @nLabelLine, '00000')

               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, RefNo, RefNo2, UPC,
                  AddWho, AddDate, EditWho, EditDate)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cDropID, '', '', '',
                  'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 221470
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackDtlFail
                  GOTO RollBackTran
               END

               SET @nLabelLine += 1

               -- Get system assigned CartonoNo
               IF @nCartonNo = 0
               BEGIN
                  -- If insert cartonno = 0, system will auto assign max cartonno
                  SELECT TOP 1
                     @nCartonNo = CartonNo
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                     AND AddWho = 'rdt.' + SUSER_SNAME()
                  ORDER BY CartonNo DESC -- max cartonno
               END

               FETCH NEXT FROM @curSKU INTO @cSKU, @nQTY
            END
         END

         -- Get PackDetail info
         SELECT @nPackQTY = SUM( QTY)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo

         -- PackInfo
         IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
         BEGIN
            INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, QTY, CartonType)
            VALUES (@cPickSlipNo, @nCartonNo, @nPackQTY, 'PALLET')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 221471
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
               GOTO RollBackTran
            END
         END

         -- PackInfo
         IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
         BEGIN
            INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, QTY, CartonType)
            VALUES (@cPickSlipNo, @nCartonNo, @nPackQTY, 'PALLET')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 221472
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
               GOTO RollBackTran
            END
         END

         -- PalletDetail
         IF NOT EXISTS( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK) WHERE PalletKey = @cFromID)
         BEGIN
            /*INC7331096 (START)*/
            SELECT @cPalletLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.PalletDetail WITH (NOLOCK)
            WHERE PalletKey = @cFromID

            INSERT INTO dbo.PalletDetail (PalletKey, PalletLineNumber, CaseID, StorerKey, SKU, LOC, Qty, Status, UserDefine01, UserDefine03, ArchiveCop)
            VALUES (@cFromID, @cPalletLineNumber, @cLabelNo, @cStorerKey, @cSKU, @cFinalLOC, @nPackQTY, '9', @cOrderKey, @cDropID, '9')
            /*INC7331096 (END)*/

            /*
            INSERT INTO dbo.PalletDetail (PalletKey, PalletLineNumber, CaseID, StorerKey, SKU, LOC, QTY, Status, UserDefine01, UserDefine03, ArchiveCop)
            VALUES (@cFromID, '00001', @cLabelNo, @cStorerKey, @cSKU, @cFinalLOC, @nPackQTY, '9', @cOrderKey, @cDropID, '9')
            */
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 221473
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPLTDtlFail
               GOTO RollBackTran
            END
         END

         FETCH NEXT FROM @curPD INTO @cOrderKey
      END

      -- PickDetail
      SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PickDetailKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            CaseID = @cLabelNo,
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME(),
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 221474
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END

      -- Pallet weight
      IF EXISTS( SELECT 1
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey
            AND LOC = @cFromLOC
            AND ID = @cFromID)
      BEGIN
         DECLARE @nGrossWgt FLOAT
         SELECT @nGrossWgt = SUM( A.UDF04)
         FROM
         (
            SELECT MAX( ISNULL( TRY_CAST( UserDefined04 AS FLOAT), 0)) AS UDF04
            FROM dbo.UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND LOC = @cFromLOC
               AND ID = @cFromID
            GROUP BY UCCNo
         ) A

         UPDATE dbo.Pallet SET
            GrossWgt = @nGrossWgt,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME(),
            TrafficCop = NULL
         WHERE PalletKey = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 221475
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPLTHdrFail
            GOTO RollBackTran
         END
      END

      -- Close pallet
      IF EXISTS( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cFromID AND Status = '0')
      BEGIN
         UPDATE dbo.Pallet SET
            Status = '9',
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PalletKey = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 221476
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPLTHdrFail
            GOTO RollBackTran
         END
      END

      -- Get MBOL info
      DECLARE @cMBOLKey NVARCHAR( 10) = ''
      SELECT @cMBOLKey = MBOLKey
      FROM dbo.MBOL WITH (NOLOCK)
      WHERE Facility = @cFacility
         AND Status < '9'
         AND ExternMBOLKey = @cDropID

      -- MBOL
      IF @cMBOLKey = ''
      BEGIN
         DECLARE @nSuccess INT = 1
         EXECUTE dbo.nspg_getkey
            'MBOL'
            , 10
            , @cMBOLKey    OUTPUT
            , @nSuccess    OUTPUT
            , @nErrNo      OUTPUT
            , @cErrMsg     OUTPUT

         INSERT INTO dbo.MBOL (
            MBOLKey, ExternMBOLKey, Facility, Status, AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cMBOLKey, @cDropID, @cFacility, '0', 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 221477
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBOL Fail
            GOTO RollBackTran
         END
      END

      -- Loop order in pallet
      SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT OrderKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cOrderKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- MBOLDetail
         IF NOT EXISTS( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
         BEGIN
            INSERT INTO dbo.MBOLDetail
               (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cMBOLKey, '00000', @cOrderKey, '', 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 221478
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBDtl Fail
               GOTO RollbackTran
            END
         END
         FETCH NEXT FROM @curPD INTO @cOrderKey
      END

      -- Interface
      EXEC isp_Carrier_Middleware_Interface
          '' -- @cOrderKey
         ,@cMBOLKey
         ,@nFunc
         ,'' -- @nCartonNo
         ,4  -- @nStep
         ,@bSuccess  OUTPUT
         ,@nErrNo    OUTPUT
         ,@cErrMsg   OUTPUT
      IF @bSuccess = 0
      BEGIN
         SET @nErrNo = 221479
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShipLabel fail
         GOTO RollBackTran
      END
   END

   EXEC RDT.rdt_STD_EventLog
      @cActionType    = '3', -- Picking
      @cUserID        = @cUserName,
      @nMobileNo      = @nMobile,
      @nFunctionID    = @nFunc,
      @cFacility      = @cFacility,
      @cStorerKey     = @cStorerKey,
      @cLocation      = @cFromLOC,
      @cToLocation    = @cFinalLOC,
      @cID            = @cFromID,
      @cToID          = @cFromID,
      @cDropID        = @cDropID,
      @cTaskDetailKey = @cTaskDetailKey,
      @cSKU           = @cSKU,
      @nQTY           = @nQTY

   -- Create next task
   EXEC rdt.rdt_TM_PalletPick_CreateNextTask @nMobile, @nFunc, @cLangCode,
      @cUserName,
      @cListKey,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   COMMIT TRAN rdt_1770ConfirmSP02 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1770ConfirmSP02 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
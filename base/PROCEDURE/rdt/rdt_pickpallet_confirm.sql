SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PickPallet_Confirm                                    */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2023-05-30 1.0  Ung      WMS-22370 Created                                 */
/* 2023-10-24 1.1  Ung      WMS-23891 Add CheckPalletStatus                   */
/*                          UpdatePickDetailDropID, UpdatePickDetailCaseID    */
/* 2025-02-26 1.2.0 NLT013  UWP-30204 ToLoc is Missing  while executing ConfirmSP  */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_PickPallet_Confirm] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 18),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cToLOC        NVARCHAR( 10),
   @cLottableCode NVARCHAR( 30),
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)

   -- Get RDT storer configure
   DECLARE @cConfirmSP NVARCHAR(20)
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''

   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cPickSlipNo, @cLOC, @cID, @cSKU, @nQTY, @cToLOC, @cLottableCode, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            ' @nMobile       INT,           ' +
            ' @nFunc         INT,           ' +
            ' @cLangCode     NVARCHAR( 18), ' +
            ' @nStep         INT,           ' +
            ' @nInputKey     INT,           ' +
            ' @cFacility     NVARCHAR( 5),  ' +
            ' @cStorerKey    NVARCHAR( 15), ' +
            ' @cPickSlipNo   NVARCHAR( 10), ' +
            ' @cLOC          NVARCHAR( 10), ' +
            ' @cID           NVARCHAR( 18), ' +
            ' @cSKU          NVARCHAR( 20), ' +
            ' @nQTY          INT,           ' +
            ' @cToLOC        NVARCHAR( 10), ' +
            ' @cLottableCode NVARCHAR( 30), ' +
            ' @cLottable01   NVARCHAR( 18), ' +
            ' @cLottable02   NVARCHAR( 18), ' +
            ' @cLottable03   NVARCHAR( 18), ' +
            ' @dLottable04   DATETIME,      ' +
            ' @dLottable05   DATETIME,      ' +
            ' @cLottable06   NVARCHAR( 30), ' +
            ' @cLottable07   NVARCHAR( 30), ' +
            ' @cLottable08   NVARCHAR( 30), ' +
            ' @cLottable09   NVARCHAR( 30), ' +
            ' @cLottable10   NVARCHAR( 30), ' +
            ' @cLottable11   NVARCHAR( 30), ' +
            ' @cLottable12   NVARCHAR( 30), ' +
            ' @dLottable13   DATETIME,      ' +
            ' @dLottable14   DATETIME,      ' +
            ' @dLottable15   DATETIME,      ' +
            ' @nErrNo        INT           OUTPUT, ' +
            ' @cErrMsg       NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cPickSlipNo, @cLOC, @cID, @cSKU, @nQTY, @cToLOC, @cLottableCode,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   DECLARE @cOrderKey            NVARCHAR( 10)
   DECLARE @cLoadKey             NVARCHAR( 10)
   DECLARE @cZone                NVARCHAR( 18)
   DECLARE @cPickFilter          NVARCHAR( MAX) = ''
   DECLARE @cPickDetailKey       NVARCHAR( 10)
   DECLARE @cSerialNoKey         NVARCHAR( 10)
   DECLARE @curPD                CURSOR
   DECLARE @nQTY_Move            INT = 0
   DECLARE @nQTY_Bal             INT
   DECLARE @nQTY_PD              INT
   DECLARE @nQTYAlloc            INT
   DECLARE @nQTYPick             INT
   DECLARE @cMoveQTYAlloc        NVARCHAR( 1)
   DECLARE @cMoveQTYPick         NVARCHAR( 1)
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @cSerialNoCapture     NVARCHAR( 1)
   DECLARE @cSerialNo            NVARCHAR( 30)
   DECLARE @cCheckPalletStatus   NVARCHAR( 1)
   DECLARE @cUpdatePickDetailCaseID NVARCHAR( 1)
   DECLARE @cUpdatePickDetailDropID NVARCHAR( 1)
   DECLARE @nSerialQTY           INT
   
   -- Get storer config
   SET @cMoveQTYAlloc = rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
   SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey) 
   SET @cUpdatePickDetailCaseID = rdt.RDTGetConfig( @nFunc, 'UpdatePickDetailCaseID', @cStorerKey) 
   SET @cUpdatePickDetailDropID = rdt.RDTGetConfig( @nFunc, 'UpdatePickDetailDropID', @cStorerKey) 
   SET @cCheckPalletStatus = rdt.RDTGetConfig( @nFunc, 'CheckPalletStatus', @cStorerKey) 

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   -- Check move alloc, but picked
   IF @cMoveQTYAlloc = '1' AND @cPickConfirmStatus = '5'
   BEGIN
      SET @nErrNo = 201801
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IncorrectSetup
      GOTO Quit
   END

   -- Check move picked, but not pick confirm
   IF @cMoveQTYPick = '1' AND @cPickConfirmStatus < '5'
   BEGIN
      SET @nErrNo = 201802
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IncorrectSetup
      GOTO Quit
   END

   -- Check pallet status, like HOLD
   IF @cCheckPalletStatus = '1'
   BEGIN
      DECLARE @cIDStatus NVARCHAR( 10)
      SELECT @cIDStatus = Status FROM dbo.ID WITH (NOLOCK) WHERE ID = @cID 

      IF @cIDStatus <> 'OK'
      BEGIN
         SET @nErrNo = 201808
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID:
         SET @cErrMsg = RTRIM( @cErrMsg) + ' ' + @cIDStatus
         GOTO Quit
      END
   END

   -- Get pick filter
   SELECT @cPickFilter = ISNULL( Long, '')
   FROM CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'PickFilter'
      AND Code = @nFunc 
      AND StorerKey = @cStorerKey
      AND Code2 = @cFacility

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- PickDetail cursor
   BEGIN      
      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
         SET @cSQL =
            ' SELECT PD.PickDetailKey, PD.QTY, PD.SKU ' +
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK)' +
               ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +
               ' JOIN dbo.Loc LOC WITH (NOLOCK) ON (PD.LOC = PD.LOC) ' +
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +
               ' AND PD.LOC = @cLOC ' +
               ' AND PD.ID = @cID ' +
               ' AND PD.QTY > 0 ' +
               ' AND PD.Status <> ''4'' ' +
               ' AND PD.Status < @cPickConfirmStatus ' + 
               CASE WHEN @cPickFilter = '' THEN '' ELSE @cPickFilter END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
         SET @cSQL =
            ' SELECT PD.PickDetailKey, PD.QTY, PD.SKU ' +
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
               ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            ' WHERE PD.OrderKey = @cOrderKey ' +
               ' AND PD.LOC = @cLOC ' +
               ' AND PD.ID = @cID ' +
               ' AND PD.QTY > 0' +
               ' AND PD.Status <> ''4'' ' +
               ' AND PD.Status < @cPickConfirmStatus ' + 
               CASE WHEN @cPickFilter = '' THEN '' ELSE @cPickFilter END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
         SET @cSQL =
            ' SELECT PD.PickDetailKey, PD.QTY, PD.SKU ' +
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
               ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
               ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            ' WHERE LPD.LoadKey = @cLoadKey ' +
               ' AND PD.LOC = @cLOC ' +
               ' AND PD.ID = @cID ' +
               ' AND PD.QTY > 0' +
               ' AND PD.Status <> ''4'' ' +
               ' AND PD.Status < @cPickConfirmStatus ' + 
               CASE WHEN @cPickFilter = '' THEN '' ELSE @cPickFilter END

      -- Custom PickSlip
      ELSE
         SET @cSQL =
            ' SELECT PD.PickDetailKey, PD.QTY, PD.SKU ' +
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
               ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            ' WHERE PD.PickSlipNo = @cPickSlipNo ' +
               ' AND PD.LOC = @cLOC ' +
               ' AND PD.ID = @cID ' +
               ' AND PD.QTY > 0' +
               ' AND PD.Status <> ''4'' ' +
               ' AND PD.Status < @cPickConfirmStatus ' + 
               CASE WHEN @cPickFilter = '' THEN '' ELSE @cPickFilter END

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
         ' @cID         NVARCHAR( 18), ' +
         ' @cSKU        NVARCHAR( 20), ' +
         ' @cPickConfirmStatus NVARCHAR( 1) '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @curPD OUTPUT,
         @cPickSlipNo,
         @cOrderKey,
         @cLoadKey,
         @cLOC,
         @cID,
         @cSKU,
         @cPickConfirmStatus
   END

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PickPallet_Confirm -- For rollback or commit only our own transaction

   -- Loop PickDetail
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cSKU
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Confirm PickDetail
      UPDATE dbo.PickDetail SET
         Status = @cPickConfirmStatus,
         CaseID = CASE WHEN @cUpdatePickDetailCaseID = '1' THEN ID ELSE CaseID END,
         DropID = CASE WHEN @cUpdatePickDetailDropID = '1' THEN ID ELSE DropID END, 
         EditDate = GETDATE(),
         EditWho  = SUSER_SNAME()
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 201803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
         GOTO RollBackTran
      END

      -- Serial no
      IF @cSerialNoCapture IN ('1', '3') -- 1=inboud and outbound, 2=inbound only, 3=outbound only
      BEGIN   
         -- Serial no SKU
         IF (SELECT SerialNoCapture FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU) IN ('1', '3')
         BEGIN
            SET @nQTY_Bal = @nQTY_PD
            WHILE @nQTY_Bal > 0
            BEGIN
               -- Find a serial no on the pallet
               SELECT TOP 1 
                  @cSerialNoKey = SerialNoKey,
                  @cSerialNo = SerialNo, 
                  @nSerialQTY = QTY
               FROM dbo.SerialNo WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
                  AND ID = @cID
                  AND Status = '1'
               
               IF @@ROWCOUNT = 0
                  BREAK
               
               -- Insert PickSerilNo
               IF @cSerialNo <> ''
               BEGIN
                  INSERT INTO PickSerialNo (PickDetailKey, StorerKey, SKU, SerialNo, QTY)
                  VALUES (@cPickDetailKey, @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 201804
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKSNO Fail
                     GOTO RollBackTran
                  END
               END
               
               -- Update serial no
               UPDATE dbo.SerialNo SET
                  Status = '5', -- Pick
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL -- Awaiting trigger to make the changes
               WHERE SerialNoKey = @cSerialNoKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 201805
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD SNO Fail
                  GOTO RollBackTran
               END
               
               -- Reduce balance
               SET @nQTY_Bal -= @nSerialQTY
            END
         
            -- Check balance
            IF @nQTY_Bal > 0
            BEGIN
               SET @nErrNo = 201806
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO NOT TALLY
               GOTO RollBackTran
            END
         END
      END

      SET @nQTY_Move += @nQTY_PD

      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cSKU
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

      -- Move by ID
      EXECUTE rdt.rdt_Move
         @nMobile        = @nMobile,
         @cLangCode      = @cLangCode,
         @nErrNo         = @nErrNo  OUTPUT,
         @cErrMsg        = @cErrMsg OUTPUT,
         @cSourceType    = 'rdt_PickPallet_Confirm',
         @cStorerKey     = @cStorerKey,
         @cFacility      = @cFacility,
         @cFromLOC       = @cLOC,
         @cToLOC         = @cToLOC,
         @cFromID        = @cID,
         @cToID          = @cID,
         @nQTYAlloc      = @nQTYAlloc,
         @nQTYPick       = @nQTYPick,
         @nFunc          = @nFunc
      IF @nErrNo <> 0
         GOTO RollBackTran
   END

   -- Update UCC (rdt_Move does not update UCC if PickDetail.Status = 5)
   IF @cToLOC <> '' AND @cMoveQTYPick = '1'
   BEGIN
      DECLARE @cUCCNo NVARCHAR( 20)
      DECLARE @curUCC CURSOR
      SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT UCCNo
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cLOC
            AND ID = @cID
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCCNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE dbo.UCC SET
            Status = '5', -- Pick
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCCNo
         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 201807
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC fail
            GOTO RollBackTran
         END
      END
   END

   -- Event log
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '3', -- Picking
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cPickSlipNo   = @cPickSlipNo, 
      @cLocation     = @cLOC,
      @cID           = @cID,
      @cSKU          = @cSKU,
      @nQTY          = @nQTY_Move,
      @cLottable01   = @cLottable01,
      @cLottable02   = @cLottable02,
      @cLottable03   = @cLottable03,
      @dLottable04   = @dLottable04,
      @dLottable05   = @dLottable05,
      @cLottable06   = @cLottable06,
      @cLottable07   = @cLottable07,
      @cLottable08   = @cLottable08,
      @cLottable09   = @cLottable09,
      @cLottable10   = @cLottable10,
      @cLottable11   = @cLottable11,
      @cLottable12   = @cLottable12,
      @dLottable13   = @dLottable13,
      @dLottable14   = @dLottable14,
      @dLottable15   = @dLottable15,
      @cToLocation   = @cToLOC

   COMMIT TRAN rdt_PickPallet_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PickPallet_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_PTLPiece_Confirm_Order12                           */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Confirm by order                                               */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 16-02-2021 1.0  yeekung  WMS-18729 Created                              */
/* 12-11-2022 1.0  yeekung  performance tune (yeekung01)                   */ 
/***************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Confirm_Order12] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cLight       NVARCHAR( 1)
   ,@cStation     NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1)
   ,@cSKU         NVARCHAR( 20)
   ,@cIPAddress   NVARCHAR( 40) OUTPUT
   ,@cPosition    NVARCHAR( 10) OUTPUT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cResult01    NVARCHAR( 20) OUTPUT
   ,@cResult02    NVARCHAR( 20) OUTPUT
   ,@cResult03    NVARCHAR( 20) OUTPUT
   ,@cResult04    NVARCHAR( 20) OUTPUT
   ,@cResult05    NVARCHAR( 20) OUTPUT
   ,@cResult06    NVARCHAR( 20) OUTPUT
   ,@cResult07    NVARCHAR( 20) OUTPUT
   ,@cResult08    NVARCHAR( 20) OUTPUT
   ,@cResult09    NVARCHAR( 20) OUTPUT
   ,@cResult10    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess          INT
   DECLARE @nTranCount        INT
   DECLARE @nQTY_PD           INT

   DECLARE @cWaveKey          NVARCHAR( 10)
   DECLARE @cCartonID         NVARCHAR( 20)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cOrderLineNumber  NVARCHAR( 5)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @cLoadkey          NVARCHAR( 10)
   DECLARE @cLightMode        NVARCHAR( 4)
   DECLARE @cDisplay          NVARCHAR( 5)
   DECLARE @cdropid           NVARCHAR(20)
   DECLARE @cUpdatePackDetail NVARCHAR(1)
   DECLARE @nCartonNo         INT
   DECLARE @nRowRef           INT
   DECLARE @cPrevSKU          NVARCHAR( 20)

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLPiece_Confirm_Order12 -- For rollback or commit only our own transaction

   SET @cDisplay = ''

   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)

   -- Check light not yet press
   IF EXISTS( SELECT 1 FROM deviceprofile DP(NOLOCK)
               JOIN PTL.LightStatus PTL WITH (NOLOCK)
               ON DP.deviceposition=PTL.deviceposition
                  AND dp.deviceid=ptl.deviceid
               WHERE PTL.DeviceID = @cStation
                  AND DisplayValue <> ''
                  AND DP.logicalname NOT IN('BATCH','PACK'))
   BEGIN
      SET @nErrNo = 182901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Light NotPress
      GOTO Quit
   END

   -- Get assign info
   SET @cLoadkey = ''
   SELECT TOP 1 @cLoadkey = loadkey
         ,@cdropid=dropid
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
   WHERE Station = @cStation
   order by editdate desc;

   -- Find PickDetail to offset
   SET @cOrderKey = ''
   SELECT TOP 1
      @cOrderKey = O.OrderKey,
      @cPickDetailKey = PD.PickDetailKey,
      @nQTY_PD = QTY
   FROM  Orders O WITH (NOLOCK)
      JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.loadkey = o.loadkey AND L.Station = @cStation)
   WHERE o.loadkey=@cLoadkey
      AND PD.SKU = @cSKU
      AND PD.Status <= '5'
      AND PD.CaseID = ''
      AND PD.dropid = @cdropid
      AND PD.QTY > 0
      AND PD.Status <> '4'
      AND O.Status <> 'CANC'
      AND O.SOStatus <> 'CANC'
   ORDER BY L.RowRef DESC -- Match order with position first

   -- Check blank
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 182902
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No order
      GOTO Quit
   END

   -- Get assign info
   SET @cCartonID = ''
   SET @cIPAddress = ''
   SET @cPosition = ''
   SELECT
      @nRowRef = RowRef, 
      @cIPAddress = IPAddress,
      @cPosition = Position, 
      @cPrevSKU = SKU
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
   WHERE Station = @cStation
      AND OrderKey = @cOrderKey

   IF @cLight <> '1' -- light spoil do confirm here
   BEGIN
       /***********************************************************************************************

                                              CONFIRM ORDER

      ***********************************************************************************************/
      -- Exact match
      IF @nQTY_PD = 1
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            -- Status = '5',
            CaseID = 'SORTED',
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME(),
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 182904
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
      
      -- PickDetail have more
      ELSE IF @nQTY_PD > 1
      BEGIN
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
            SET @nErrNo = 182905
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
            GOTO RollBackTran
         END

         -- Create new a PickDetail to hold the balance
         INSERT INTO dbo.PickDetail (
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
            PickDetailKey,
            QTY,
            TrafficCop,
            OptimizeCop, Channel_ID)
         SELECT
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
            CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
            @cNewPickDetailKey,
            @nQTY_PD - 1, -- QTY
            NULL, -- TrafficCop
            '1'   -- OptimizeCop
            , Channel_ID
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 182906
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
            GOTO RollBackTran
         END

         -- Get RefKeyLookup info
         SELECT
            @cPickSlipNo = PickSlipNo,
            @cOrderLineNumber = OrderLineNumber,
            @cLoadkey = Loadkey
         FROM RefKeyLookup WITH (NOLOCK)
         WHERE PickDetailKey = @cPickDetailKey

         -- Split RefKeyLookup
         IF @@ROWCOUNT > 0
         BEGIN
            -- Insert into
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickslipNo, OrderKey, OrderLineNumber, Loadkey)
            VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 182907
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
               GOTO RollBackTran
            END
         END

         -- Change orginal PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            QTY = 1,
            CaseID = 'SORTED',
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME(),
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 182908
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
   END

   -- Update current SKU
   IF @cPrevSKU <> @cSKU
   BEGIN
      UPDATE rdt.rdtPTLPieceLog SET
         SKU = @cSKU
      WHERE RowRef = @nRowRef 
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 182909
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLog Fail
         GOTO Quit
      END
   END

    -- EventLog - Sign In Function
   -- (ChewKP02)
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '3', -- Sign in function
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @cOrderKey   = @cOrderKey,
     @cSKU        = @cSKU,
     @nQTY        = @nQTY_PD,
     @cCaseID     = @cCartonID

   -- Draw matrix (and light up)
   EXEC rdt.rdt_PTLPiece_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,@cLight
      ,@cStation
      ,@cMethod
      ,@cSKU
      ,@cIPAddress
      ,@cPosition
      ,@cDisplay
      ,@nErrNo     OUTPUT
      ,@cErrMsg    OUTPUT
      ,@cResult01  OUTPUT
      ,@cResult02  OUTPUT
      ,@cResult03  OUTPUT
      ,@cResult04  OUTPUT
      ,@cResult05  OUTPUT
      ,@cResult06  OUTPUT
      ,@cResult07  OUTPUT
      ,@cResult08  OUTPUT
      ,@cResult09  OUTPUT
      ,@cResult10  OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   COMMIT TRAN rdt_PTLPiece_Confirm_Order12
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_Confirm_Order12 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
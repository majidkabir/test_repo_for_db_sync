SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: isp_803PTL_Confirm05                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Accept QTY in CS-PCS, format 9-999                          */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 23-07-2021 1.0  Chermaine  WMS-17331 Created                         */
/* 13-12-2022 1.1  YeeKung    WMS-21338 Upd orders status (yeekung01)   */
/************************************************************************/

CREATE   PROC [PTL].[isp_803PTL_Confirm05] (
   @cIPAddress    NVARCHAR(30),
   @cPosition     NVARCHAR(20),
   @cFuncKey      NVARCHAR(2),
   @nSerialNo     INT,
   @cInputValue   NVARCHAR(20),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR(125) OUTPUT,
   @cDebug        NVARCHAR( 1) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLangCode      NVARCHAR( 3)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @nFunc          INT
   DECLARE @nQTY           INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
   DECLARE @nGroupKey      INT
   DECLARE @nCartonNo      INT
   DECLARE @cStation       NVARCHAR( 10)
   DECLARE @cCartonID      NVARCHAR( 20)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cType          NVARCHAR( 10)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cLightMode     NVARCHAR( 4)
   DECLARE @cPackLight     NVARCHAR( 4)
   DECLARE @cOrderLineNumber NVARCHAR( 5)
   DECLARE @cBatchKey      NVARCHAR( 10)
   DECLARE @cLoc           NVARCHAR(18)

   DECLARE @curPTL CURSOR
   DECLARE @curPD  CURSOR

   SET @nTranCount = @@TRANCOUNT
   SET @nFunc = 803 -- PTL piece (rdt.rdtfnc_PTLPiece)
   SET @cInputValue = RTRIM( LTRIM( @cInputValue))

   -- Get light info
   DECLARE @cStorerKey NVARCHAR(15)
   SELECT TOP 1
      @cStation = DeviceID,
      @cStorerKey = StorerKey
   FROM PTL.LightStatus WITH (NOLOCK)
   WHERE IPAddress = @cIPAddress
      AND DevicePosition = @cPosition

   SELECT TOP 1
      @cLoc = Loc
   FROM DeviceProfile WITH (NOLOCK)
   WHERE IPAddress = @cIPAddress
      AND DevicePosition = @cPosition
      AND DeviceID = @cStation
      AND DeviceType = 'station'

   -- Get storer config
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

   /***********************************************************************************************
                                               END TOTE
   ***********************************************************************************************/
   IF @cInputValue = 'END'
   BEGIN
      -- Unassign position if fully sorted
      DELETE rdt.rdtPTLPieceLog
      WHERE Station = @cStation
         AND IPAddress = @cIPAddress
         AND Position = @cPosition
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 171751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL Log Fail
         GOTO Quit
      END

      -- Off all lights
      EXEC PTL.isp_PTL_TerminateModule
          @cStorerKey
         ,@nFunc
         ,@cStation
         ,'STATION'
         ,@bSuccess    OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      GOTO Quit
   END

   /***********************************************************************************************
                                              ASSIGN TOTE
   ***********************************************************************************************/
   ELSE IF @cInputValue = 'TOTE'
   BEGIN
      -- Check carton ID assigned
      IF EXISTS( SELECT 1
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
         WHERE Station = @cStation
            AND IPAddress = @cIPAddress
            AND Position = @cPosition
            AND CartonID = '')
      BEGIN
         -- Relight if not yet assign
         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
           ,@n_PTLKey         = 0
           ,@c_DisplayValue   = 'TOTE'
           ,@b_Success        = @bSuccess    OUTPUT
           ,@n_Err            = @nErrNo      OUTPUT
           ,@c_ErrMsg         = @cErrMsg     OUTPUT
           ,@c_DeviceID       = @cStation
           ,@c_DevicePos      = @cPosition
           ,@c_DeviceIP       = @cIPAddress
           ,@c_LModMode       = @cLightMode
         IF @nErrNo <> 0
            GOTO Quit
      END
      ELSE
      BEGIN

         -- Off all lights
         EXEC PTL.isp_PTL_TerminateModule
             @cStorerKey
            ,@nFunc
            ,@cStation
            ,'STATION'
            ,@bSuccess    OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Quit


         ---- Relight
         --EXEC PTL.isp_PTL_LightUpLoc
         --   @n_Func           = @nFunc
         --  ,@n_PTLKey         = 0
         --  ,@c_DisplayValue   = '1'
         --  ,@b_Success        = @bSuccess    OUTPUT
         --  ,@n_Err            = @nErrNo      OUTPUT
         --  ,@c_ErrMsg         = @cErrMsg     OUTPUT
         --  ,@c_DeviceID       = @cStation
         --  ,@c_DevicePos      = @cPosition
         --  ,@c_DeviceIP       = @cIPAddress
         --  ,@c_LModMode       = @cLightMode
         --IF @nErrNo <> 0
         --   GOTO Quit
      END

      GOTO Quit
   END

   /***********************************************************************************************
                                              CONFIRM ORDER
   ***********************************************************************************************/
   ELSE IF @cInputValue = '1'
   BEGIN
      -- Get booking info
      SELECT
         @cDropID = DropID,
         @cOrderKey = OrderKey,
         @cBatchKey = BatchKey,
         @cSKU = SKU,
         @cCartonID = CartonID
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
      WHERE IPAddress = @cIPAddress
         AND Position = @cPosition
/*
      -- Get PTLTran info
      SELECT TOP 1
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE IPAddress = @cIPAddress
         AND DevicePosition = @cPosition
         AND Func = @nFunc
         AND Status = '1' -- Lighted up
*/
      -- Calc QTY
      IF @cInputValue = ''
         SET @nQTY = 0
      ELSE
         SET @nQTY = CAST( @cInputValue AS INT)

      -- For calc balance
      SET @nQTY_Bal = @nQTY

      -- Find PickDetail to offset
      SET @cPickDetailKey = ''
      SELECT TOP 1
         @cPickDetailKey = PD.PickDetailKey,
         @nQTY_PD = QTY
      FROM PickDetail PD WITH (NOLOCK)
         JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE PD.dropID = @cDropID
         AND O.OrderKey = @cOrderKey
         AND PD.SKU = @cSKU
         AND PD.Status <= '5'
         AND PD.CaseID <> 'SORTED'
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'

      -- Check blank
      IF @cPickDetailKey = ''
      BEGIN
         SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightModeError', @cStorerKey)

         -- Relight up
         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
           ,@n_PTLKey         = 0
           ,@c_DisplayValue   = '1'
           ,@b_Success        = @bSuccess    OUTPUT
           ,@n_Err            = @nErrNo      OUTPUT
           ,@c_ErrMsg         = @cErrMsg     OUTPUT
           ,@c_DeviceID       = @cStation
           ,@c_DevicePos      = @cPosition
           ,@c_DeviceIP       = @cIPAddress
           ,@c_LModMode       = @cLightMode
         IF @nErrNo <> 0
            GOTO Quit

         SET @nErrNo = 171752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No order
         GOTO Quit
      END

      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN isp_803PTL_Confirm05 -- For rollback or commit only our own transaction

      UPDATE  PTL.PTLTran WITH (ROWLOCK) SET
         STATUS = '9',
         DropID = @cCartonID
      WHERE storerKey = @cStorerKey
      AND IPAddress = @cIPAddress
      AND DevicePosition = @cPosition
      AND dropID = @cDropID
      AND OrderKey = @cOrderKey
      AND SKU = @cSKU

      IF @@ERROR <> ''
      BEGIN
         SET @nErrNo = 171760
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
         GOTO RollBackTran
      END

      -- Exact match
      IF @nQTY_PD = 1
      BEGIN
      	IF @cCartonID = ''
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
               SET @nErrNo = 171753
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
      	END
      	ELSE
      	BEGIN
      		-- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               -- Status = '5',
               CaseID = 'SORTED',
               dropID = @cCartonID,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 171758
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
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
            SET @nErrNo = 171754
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
   			SET @nErrNo = 171755
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
               SET @nErrNo = 171756
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
               GOTO RollBackTran
            END
         END

         IF @cCartonID = ''
         BEGIN
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
               SET @nErrNo = 171757
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
         	-- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = 1,
               CaseID = 'SORTED',
               dropID = @cCartonID,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 171759
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
         END
      END

      -- End order if fully sorted
      IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND CaseID <> 'SORTED')
      BEGIN
           --(yeekung01)
         UPDATE orders  WITH (ROWLOCK)
         set status='3'
         where orderkey=@cOrderKey
         AND storerkey=@cstorerkey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 171761
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrdersFail
            GOTO RollBackTran
         END
         
         --(yeekung01)
         UPDATE orderdetail  WITH (ROWLOCK)
         set status='3'
         where orderkey=@cOrderKey
         AND storerkey=@cstorerkey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 171762
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdODFail
            GOTO RollBackTran
         END

      	SET @cPackLight = rdt.RDTGetConfig( @nFunc, 'PackLight', @cStorerKey)

         SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightModeEnd', @cStorerKey)

         IF @cPackLight = '1'
         BEGIN
         	SELECT
         	   @cPosition = DevicePosition,
         	   @cIPAddress = IPAddress
         	FROM deviceProfile WITH (NOLOCK)
         	WHERE deviceID = @cStation
         	AND loc = @cLoc
         	AND DevicePosition <> @cPosition
         	AND DeviceType = 'station'
         	AND logicalName = 'Pack'
         END

         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
           ,@n_PTLKey         = 0
           ,@c_DisplayValue   = 'END'
           ,@b_Success        = @bSuccess    OUTPUT
           ,@n_Err            = @nErrNo      OUTPUT
           ,@c_ErrMsg         = @cErrMsg     OUTPUT
           ,@c_DeviceID       = @cStation
           ,@c_DevicePos      = @cPosition
           ,@c_DeviceIP       = @cIPAddress
           ,@c_LModMode       = @cLightMode
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
      ELSE
      BEGIN
         -- Off all lights
         EXEC PTL.isp_PTL_TerminateModule
             @cStorerKey
            ,@nFunc
            ,@cStation
            ,'STATION'
            ,@bSuccess    OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END

      COMMIT TRAN isp_803PTL_Confirm05
      GOTO Quit
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN isp_803PTL_Confirm05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
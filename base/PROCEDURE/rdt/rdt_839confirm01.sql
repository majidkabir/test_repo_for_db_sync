SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_839Confirm01                                       */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2018-03-06 1.0  ChewKP  WMS-4093 Created                                */
/* 2019-02-27 1.1  James   WMS-5057 Add lottable params (james01)          */
/* 2018-10-18 1.2  ChewKP  WMS-5156 Standardize SP                         */
/* 2019-07-11 1.3  James   WMS-9683 Add StdEventLog (james02)              */
/* 2022-04-20 1.4  YeeKung WMS-19311 Add Data capture (yeekung01)          */
/* 2023-07-25 1.5  Ung     WMS-23002 Add serial no                         */
/***************************************************************************/
CREATE    PROC [RDT].[rdt_839Confirm01](
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5) ,
   @cStorerKey     NVARCHAR( 15),
   @cType          NVARCHAR( 10),
   @cPickSlipNo    NVARCHAR( 10),
   @cPickZone      NVARCHAR( 1),
   @cDropID        NVARCHAR( 20),
   @cLOC           NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @nQTY           INT,
   @cLottableCode  NVARCHAR( 20),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,
   @dLottable14    DATETIME,
   @dLottable15    DATETIME,
   @cPackData1     NVARCHAR( 30),
   @cPackData2     NVARCHAR( 30),
   @cPackData3     NVARCHAR( 30),
   @cID            NVARCHAR( 18),
   @cSerialNo      NVARCHAR( 30),
   @nSerialQTY     INT,
   @nBulkSNO       INT,
   @nBulkSNOQTY    INT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR(250) OUTPUT  
   
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cZone          NVARCHAR( 18)
   DECLARE @cPickDetailKey NVARCHAR( 18)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @nQTY_Bal       INT
   DECLARE @nQTY_PD        INT
   DECLARE @bSuccess       INT
   DECLARE @curPD          CURSOR
          ,@cOption        NVARCHAR(1)
          ,@cNewPickDetailKey NVARCHAR( 10)

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_839Confirm01   

   
   
   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   
   IF @nFunc = 839 
   BEGIN
      
      IF @nStep = 3
      BEGIN
         
         SET @cOrderKey = ''
         SET @cLoadKey = ''
         SET @cZone = ''
         
         

         -- For calculation
         SET @nQTY_Bal = @nQTY

         -- Get PickHeader info
         SELECT TOP 1
            @cOrderKey = OrderKey,
            @cLoadKey = ExternOrderKey,
            @cZone = Zone
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         -- Cross dock PickSlip
         IF @cZone IN ('XD', 'LB', 'LP')
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.PickDetailKey, PD.QTY
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus

         -- Discrete PickSlip
         ELSE IF @cOrderKey <> ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.PickDetailKey, PD.QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE PD.OrderKey = @cOrderKey
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus

         -- Conso PickSlip
         ELSE IF @cLoadKey <> ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.PickDetailKey, PD.QTY
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE LPD.LoadKey = @cLoadKey  
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus

         -- Custom PickSlip
         ELSE
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.PickDetailKey, PD.QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus

         -- Handling transaction
         --SET @nTranCount = @@TRANCOUNT
         

         -- Loop PickDetail
         OPEN @curPD
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
                  SET @nErrNo = 120501
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
                  SET @nErrNo = 120502
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
                     SET @nErrNo = 120503
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END
               END
               ELSE
               BEGIN -- Have balance, need to split
               
                  -- Get new PickDetailkey
                  --DECLARE @cNewPickDetailKey NVARCHAR( 10)
                  EXECUTE dbo.nspg_GetKey
                     'PICKDETAILKEY',
                     10 ,
                     @cNewPickDetailKey OUTPUT,
                     @bSuccess          OUTPUT,
                     @nErrNo            OUTPUT,
                     @cErrMsg           OUTPUT
                  IF @bSuccess <> 1
                  BEGIN
                     SET @nErrNo = 120504
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
         				SET @nErrNo = 120505
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
                        SET @nErrNo = 120506
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
                     SET @nErrNo = 120507
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
                     SET @nErrNo = 120508
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = 0 -- Reduce balance
               END
            END

            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
         END

         --COMMIT TRAN rdt_PickPiece_Confirm
         GOTO Quit
      END
      
      IF @nStep = 5 
      BEGIN
         -- Option 1 = Short , 3 = Close DropID
         SELECT @cOption = I_Field01
         FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile 
         
         SET @cOrderKey = ''
         SET @cLoadKey = ''
         SET @cZone = ''
         
         

         -- For calculation
         SET @nQTY_Bal = @nQTY

         -- Get PickHeader info
         SELECT TOP 1
            @cOrderKey = OrderKey,
            @cLoadKey = ExternOrderKey,
            @cZone = Zone
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         -- Cross dock PickSlip
         IF @cZone IN ('XD', 'LB', 'LP')
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.PickDetailKey, PD.QTY
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus

         -- Discrete PickSlip
         ELSE IF @cOrderKey <> ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.PickDetailKey, PD.QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE PD.OrderKey = @cOrderKey
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus

         -- Conso PickSlip
         ELSE IF @cLoadKey <> ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.PickDetailKey, PD.QTY
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE LPD.LoadKey = @cLoadKey  
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus

         -- Custom PickSlip
         ELSE
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.PickDetailKey, PD.QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus

         -- Handling transaction
         --SET @nTranCount = @@TRANCOUNT
         

         -- Loop PickDetail
         OPEN @curPD
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
                  SET @nErrNo = 120509
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
                  SET @nErrNo = 120510
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
                  IF @cOption = '1' 
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
                        SET @nErrNo = 120511
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
                     SET @nErrNo = 120512
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
         				SET @nErrNo = 120513
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
                        SET @nErrNo = 120514
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
                     SET @nErrNo = 120515
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
                     SET @nErrNo = 120516
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = 0 -- Reduce balance
               END
            END

            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
         END

         --COMMIT TRAN rdt_PickPiece_Confirm
         GOTO Quit
      END
      
   END


RollBackTran:
   ROLLBACK TRAN rdt_839Confirm01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_839Confirm01  


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
        
END

GO
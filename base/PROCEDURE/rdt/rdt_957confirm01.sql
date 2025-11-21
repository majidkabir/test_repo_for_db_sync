SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_957Confirm01                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Purpose:                                                                   */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 07-11-2018  1.0  ChewKP      WMS-6666 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_957Confirm01]
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 10) -- CONFIRM/SHORT/CLOSE
   ,@cPickSlipNo  NVARCHAR( 10)
   ,@cPickZone    NVARCHAR( 10)
   ,@cDropID      NVARCHAR( 20)
   ,@cLOC         NVARCHAR( 10)
   ,@cID          NVARCHAR( 18) 
   ,@cBarcode     NVARCHAR( 60) 
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount INT

   DECLARE 
           @cOrderKey      NVARCHAR(10) 
          ,@bSuccess       INT
          ,@cTaskDetailKey NVARCHAR(10) 
          ,@cUCCID         NVARCHAR(18)
          ,@cUCCSKU        NVARCHAR(20)

   
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cZone          NVARCHAR( 18)
   DECLARE @cPickDetailKey NVARCHAR( 18)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @nQTY_Bal       INT
   DECLARE @nQTY_PD        INT
   
   DECLARE @curPD          CURSOR
   DECLARE @curPDUCC       CURSOR
   
   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   SET @nTranCount = @@TRANCOUNT

 

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_957Confirm01 -- For rollback or commit only our own transaction
   
   IF @nFunc = 957
   BEGIN
      IF @nStep = 3 
      BEGIN
            IF @nInputKey = 1 -- ENTER
            BEGIN
               
               SET @cUCCID = RIGHT(@cBarcode,18) 

               
               IF ISNULL(@cUCCID,'')  <> @cID
               BEGIN
                  SET @nErrNo = 131451
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidUCC
                  GOTO RollBackTran
               END
               
               -- For calculation
               --SET @nQTY_Bal = @nQTY

               -- Get PickHeader info
               SELECT TOP 1
                  @cOrderKey = OrderKey,
                  @cLoadKey = ExternOrderKey,
                  @cZone = Zone
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickSlipNo

               
               SET @curPDUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT SKU, Qty
               FROM dbo.UCC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND UCCNo = @cBarcode

               -- Loop PickDetail
               OPEN @curPDUCC
               FETCH NEXT FROM @curPDUCC INTO @cUCCSKU, @nQTY_Bal
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  
                  SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PD.PickDetailKey, PD.QTY
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
                     JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.Lot = PD.Lot AND LA.StorerKey = PD.StorerKey)
                  WHERE PD.OrderKey = @cOrderKey
                     AND PD.LOC = @cLOC
                     AND PD.SKU = @cUCCSKU
                     AND PD.ID  = @cID 
                     AND PD.QTY > 0
                     AND PD.Status <> '4'
                     AND PD.Status < @cPickConfirmStatus
                     AND LA.Lottable03 = @cUCCID
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
                           SET @nErrNo = 131452
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
                           SET @nErrNo = 131453
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
                                 SET @nErrNo = 131454
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
                              SET @nErrNo = 131455
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
                  				SET @nErrNo = 131456
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
                                 SET @nErrNo = 131457
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
                              SET @nErrNo = 131458
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
                              SET @nErrNo = 131459
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                              GOTO RollBackTran
                           END

                           SET @nQTY_Bal = 0 -- Reduce balance
                        END
                     END

                     FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
                  END

                  --COMMIT TRAN rdt_PickCase_Confirm

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
                     @cSKU          = @cUCCSKU,
                     @nQTY          = @nQTY,
                     @cRefNo1       = @cType,
                     @cPickSlipNo   = @cPickSlipNo,
                     @cPickZone     = @cPickZone, 
                     @cDropID       = @cDropID

                     FETCH NEXT FROM @curPDUCC INTO @cUCCSKU, @nQTY_Bal

               END  
               
            END
      END

      

    
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_957Confirm01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_957Confirm01

END

GO
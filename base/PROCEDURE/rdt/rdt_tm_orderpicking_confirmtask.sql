SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_OrderPicking_ConfirmTask                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: rdtfnc_TM_Picking                                       */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2010-05-20 1.0  ChewKP   Created                                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_OrderPicking_ConfirmTask] (
   @nMobile          INT, 
   @nFunc            INT,
   @cStorerKey       NVARCHAR( 15),
   @cUserName        NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cTaskDetailKey   NVARCHAR( 10),
   @cLoadKey         NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @cAltSKU          NVARCHAR( 20),
   @cLOC             NVARCHAR( 10),
   @cToLOC           NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cDropID          NVARCHAR( 18),
   @nPickQty         INT,
   @cStatus          NVARCHAR( 1),   -- 4 = PickInProgress ; 5 = Picked
   @cLangCode        NVARCHAR( 3),
	@cTaskDetailKeySHT NVARCHAR( 10),
   @nErrNo           INT          OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT,  -- screen limitation, 20 char max
	@cAreakey         NVARCHAR(10) = '',
	@cFlag            NVARCHAR(1) = ''
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @b_success  INT,
   @n_err              INT,
   @c_errmsg           NVARCHAR( 250),
   @cPickDetailKey     NVARCHAR( 10),
   @cComponentSKU      NVARCHAR( 20),
   @cNewPickDetailKey  NVARCHAR( 10),
   @nQTY_PD            INT,
   @nRowRef            INT,
   @nTranCount         INT,
   @nBOM_Qty           INT,
   @nBOM_PickQty       INT,
   @nSUMBOM_Qty        INT,
   @nNoOfCase          INT,
   @nNoOfLoose         INT,
   @nTotalPickQty      INT,
   @cLOT               NVARCHAR( 10),
   @cToID              NVARCHAR( 18),   
   @cPD_SKU            NVARCHAR( 20),
   @cReasonKey         NVARCHAR( 10) 

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN TM_Picking_ConfirmTask

   SET @nTotalPickQty = @nPickQty

   --IF ISNULL(@cToLOC, '') = ''
   --SELECT @cToLOC = ToLOC FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey

   -- Get PickDetail candidate to offset for non prepack bom
   IF ISNULL(@cAltSKU, '') = ''
   BEGIN
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey, PD.QTY, PD.LOT
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      WHERE O.LoadKey  = @cLoadKey
         AND PD.StorerKey  = @cStorerKey
--         AND PD.SKU = @cSKU
         AND PD.LOC = @cLOC
         AND PD.ID = @cID
         AND PD.Status = '0'
         AND PD.TaskDetailKey = @cTaskDetailKey -- (ChewKP01)
      ORDER BY PickDetailKey
      OPEN curPD
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD, @cLOT
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nPickQty < 0    
            SET @nPickQty = 0

         Continue_Offset1:    
         IF @nPickQty = 0
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
--               DropID = @cDropID,    (james04)   if short picked then no need to stamp drop id
               Status = @cStatus,
               TaskDetailKey = CASE WHEN @cStatus = '4' AND ISNULL(TaskDetailKey, '') <> '' 
                               THEN '' ELSE TaskDetailKey END  
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69391
               SET @cErrMsg = rdt.rdtgetmessage( 69391, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- EventLog - QTY 
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '3', -- Picking
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerKey,
               @cLocation     = @cLoc,
               @cToLocation   = @cToLOC,
               @cID           = @cID,     -- Sugg FromID
               @cToID         = @cDropID, -- DropID
               @cSKU          = @cSKU,
               @nQTY          = @nQTY_PD,
               @cRefNo1       = @cLoadKey,   
               @cRefNo2       = @cTaskDetailKey,   
               @cRefNo3       = @cAreakey, 
               @cRefNo4       = @cAltSKU 

            
            -- Continue to offset the rest of the pickdetail line, if any
            FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD, @cLOT
            IF @@FETCH_STATUS = 0
               GOTO Continue_Offset1
            ELSE
               BREAK -- Exit
         END

         -- Exact match
         IF @nQTY_PD = @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
--               Status = @cStatus
               Status = '5'   
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69392
               SET @cErrMsg = rdt.rdtgetmessage( 69392, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- EventLog - QTY 
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '3', -- Picking
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerKey,
               @cLocation     = @cLoc,
               @cToLocation   = @cToLOC,
               @cID           = @cID,     -- Sugg FromID
               @cToID         = @cDropID, -- DropID
               @cSKU          = @cSKU,
               @nQTY          = @nQTY_PD,
               @cRefNo1       = @cLoadKey,   
               @cRefNo2       = @cTaskDetailKey,   
               @cRefNo3       = @cAreakey, 
               @cRefNo4       = @cAltSKU 
         END
         -- PickDetail have less
         ELSE IF @nQTY_PD < @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
--               Status = @cStatus
               Status = '5'   
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69393
               SET @cErrMsg = rdt.rdtgetmessage( 69393, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- EventLog - QTY 
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '3', -- Picking
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerKey,
               @cLocation     = @cLoc,
               @cToLocation   = @cToLOC,
               @cID           = @cID,     -- Sugg FromID
               @cToID         = @cDropID, -- DropID
               @cSKU          = @cSKU,
               @nQTY          = @nQTY_PD,
               @cRefNo1       = @cLoadKey,   
               @cRefNo2       = @cTaskDetailKey,   
               @cRefNo3       = @cAreakey, 
               @cRefNo4       = @cAltSKU 

            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance
         END
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nPickQty
         BEGIN
            -- If Status = '5' (full pick), split line if neccessary
            -- If Status = '4' (short pick), no need to split line if already last RPL line to update,
            -- just have to update the pickdetail.qty = short pick qty
            -- Get new PickDetailkey
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @b_success         OUTPUT,
               @n_err             OUTPUT,
               @c_errmsg          OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 69394
               SET @cErrMsg = rdt.rdtgetmessage( 69394, @cLangCode, 'DSP') -- 'GetDetKeyFail'
               GOTO RollBackTran
            END

            -- Create a new PickDetail to hold the balance
            IF @cFlag = '2'
            BEGIN
               INSERT INTO dbo.PICKDETAIL (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                  Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
                  QTY,
                  TrafficCop,
                  OptimizeCop,
   					TaskDetailkey)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
                  '0',
                  --'0',
                  DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                  @nQTY_PD - @nPickQty, -- QTY
                  NULL, --TrafficCop,
                  '1',  --OptimizeCop,
   					@cTaskDetailKeySHT
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
            END
            ELSE
            BEGIN
               INSERT INTO dbo.PICKDETAIL (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                  Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
                  QTY,
                  TrafficCop,
                  OptimizeCop,
   					TaskDetailkey)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
                  CASE WHEN @cStatus = '4' THEN '4' ELSE '0' END,
                  --'0',
                  DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                  @nQTY_PD - @nPickQty, -- QTY
                  NULL, --TrafficCop,
                  '1',  --OptimizeCop,
   					@cTaskDetailKeySHT
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
            END
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69395
               SET @cErrMsg = rdt.rdtgetmessage( 69395, @cLangCode, 'DSP') --'Ins PDtl Fail'
               GOTO RollBackTran
            END

            -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nPickQty,
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69396
               SET @cErrMsg = rdt.rdtgetmessage( 69396, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- Confirm orginal PickDetail with exact QTY
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               Status = '5'
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69397
               SET @cErrMsg = rdt.rdtgetmessage( 69397, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- EventLog - QTY 
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '3', -- Picking
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerKey,
               @cLocation     = @cLoc,
               @cToLocation   = @cToLOC,
               @cID           = @cID,     -- Sugg FromID
               @cToID         = @cDropID, -- DropID
               @cSKU          = @cSKU,
               @nQTY          = @nPickQty,   -- Only insert confirmed qty
               @cRefNo1       = @cLoadKey,   
               @cRefNo2       = @cTaskDetailKey,   
               @cRefNo3       = @cAreakey, 
               @cRefNo4       = @cAltSKU 

--            SET @nPickQty = 0 -- Reduce balance     
               IF @cStatus = '5'    
                  SET @nPickQty = 0 -- Reduce balance
               ELSE
                  SET @nPickQty = @nPickQty - @nQTY_PD
         END

         --IF @nPickQty = 0 BREAK -- Exit

         FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD, @cLOT
      END
      CLOSE curPD
      DEALLOCATE curPD

      -- If short picked then the PendingMoveIn for ToLoc need to be deducted
--      IF @cStatus = '4'
--      BEGIN
--         SELECT @cToLOC = ToLOC, @cToID = ToID FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
--
--         UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET 
--            PendingMoveIN = CASE WHEN PendingMoveIN - (PendingMoveIN - @nTotalPickQty) < 0 THEN 0 
--                              ELSE PendingMoveIN - (PendingMoveIN - @nTotalPickQty) END
--         WHERE StorerKey = @cStorerKey
--            AND SKU = @cSKU
----            AND LOT = @cLOT
--            AND LOC = @cToLOC
--            AND ID = @cToID
--
--         IF @@ERROR <> 0
--         BEGIN
--            SET @nErrNo = 68832
--            SET @cErrMsg = rdt.rdtgetmessage( 68832, @cLangCode, 'DSP') --'UpdPenMVInFail'
--            GOTO RollBackTran
--         END
--      END
   END
   ELSE
   BEGIN
   

		
      -- Not support prepack allocated in loose qty, eg:
      -- BOM 1 (ComponentSKU A QTY = 1, B QTY = 2, C QTY = 1); CaseCnt = 1
      -- PickDetail (A QTY = 2, B QTY = *5*, C QTY = 2), should be
      -- PickDetail (A QTY = 2, B QTY = 4, C QTY = 2)
      SELECT @nSUMBOM_Qty = ISNULL(SUM(Qty), 0) FROM dbo.BillOfMaterial WITH (NOLOCK) WHERE SKU = @cAltSKU And Storerkey = @cStorerKey

      SELECT @nNoOfLoose = 0, @nNoOfCase = 0
      SET @nNoOfCase = @nPickQty / @nSUMBOM_Qty
      SET @nNoOfLoose = @nPickQty % @nSUMBOM_Qty



      DECLARE CUR_BOM CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT ComponentSKU, Qty FROM dbo.BillOfMaterial WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cAltSKU
      Order BY Sequence
      OPEN CUR_BOM
      FETCH NEXT FROM CUR_BOM INTO @cComponentSKU, @nBOM_Qty
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nNoOfLoose > 0 
            SET @nBOM_PickQty = @nPickQty
         ELSE
            SET @nBOM_PickQty = @nNoOfCase * @nBOM_Qty


			

         DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey, PD.QTY
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         WHERE O.LoadKey  = @cLoadKey
            AND PD.StorerKey  = @cStorerKey
            AND PD.SKU = @cComponentSKU
            AND PD.LOC = @cLOC
            AND PD.ID = @cID
            AND PD.Status = '0'
            AND PD.TaskDetailKey = @cTaskDetailKey -- (ChewKP01)
         ORDER BY PickDetailKey
         OPEN curPD
         FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @nBOM_PickQty < 0   
               SET @nBOM_PickQty = 0

            Continue_Offset2:    

            IF @nBOM_PickQty = 0
            BEGIN
					
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
--                  DropID = @cDropID,  if short picked then no need to stamp drop id
                  Status = @cStatus, 
                  TaskDetailKey = CASE WHEN @cStatus = '4' AND ISNULL(TaskDetailKey, '') <> '' 
                                  THEN '' ELSE TaskDetailKey END  
                    --Status = '0'
                    --TaskDetailkey = @cTaskDetailKeySHT
               WHERE PickDetailKey = @cPickDetailKey

            
--					IF @cStatus = '4'
--					BEGIN
--						UPDATE dbo.PickDetail WITH (ROWLOCK) SET
--	--                  DropID = @cDropID,  if short picked then no need to stamp drop id
--							Status = '0',
--							--TaskDetailKey = CASE WHEN @cStatus = '4' AND ISNULL(TaskDetailKey, '') <> '' 
--							--                THEN '' ELSE TaskDetailKey END  
--							TaskDetailkey = @cTaskDetailKeySHT
--							  --Status = '0'
--							  --TaskDetailkey = @cTaskDetailKeySHT
--						WHERE PickDetailKey = @cPickDetailKey
--					END
--					ELSE
--					BEGIN
--						UPDATE dbo.PickDetail WITH (ROWLOCK) SET
--	--                  DropID = @cDropID,  if short picked then no need to stamp drop id
--							Status = @cStatus ,
--							TaskDetailkey = @cTaskDetailKeySHT
--							--TaskDetailKey = CASE WHEN @cStatus = '4' AND ISNULL(TaskDetailKey, '') <> '' 
--							--                THEN '' ELSE TaskDetailKey END  
--							  --Status = '0'
--							  --TaskDetailkey = @cTaskDetailKeySHT
--
--						WHERE PickDetailKey = @cPickDetailKey
--					END
--
--               IF @@ERROR <> 0
--               BEGIN
--                  SET @nErrNo = 69398
--                  SET @cErrMsg = rdt.rdtgetmessage( 69398, @cLangCode, 'DSP') --'OffSetPDtlFail'
--                  GOTO RollBackTran
--               END
--
--               -- EventLog - QTY 
--               EXEC RDT.rdt_STD_EventLog
--                  @cActionType   = '3', -- Picking
--                  @cUserID       = @cUserName,
--                  @nMobileNo     = @nMobile,
--                  @nFunctionID   = @nFunc,
--                  @cFacility     = @cFacility,
--                  @cStorerKey    = @cStorerKey,
--                  @cLocation     = @cLoc,
--                  @cToLocation   = @cToLOC,
--                  @cID           = @cID,     -- Sugg FromID
--                  @cToID         = @cDropID, -- DropID
--                  @cSKU          = @cSKU,
--                  @nQTY          = 0,
--                  @cRefNo1       = @cLoadKey,   
--                  @cRefNo2       = @cTaskDetailKey,   
--                  @cRefNo3       = @cAreakey, 
--                  @cRefNo4       = @cAltSKU 
--
--               
--               -- Continue to offset the rest of the pickdetail line, if any
--               FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
--               IF @@FETCH_STATUS = 0
--                  GOTO Continue_Offset2
--               ELSE
--                  BREAK -- Exit
--            END
            END
            -- Exact match
            IF @nQTY_PD = @nBOM_PickQty
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cDropID,
                  Status = '5'
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 69399
                  SET @cErrMsg = rdt.rdtgetmessage( 69399, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               SET @nBOM_PickQty = @nBOM_PickQty - @nQTY_PD -- Reduce balance -- 

               -- EventLog - QTY 
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '3', -- Picking
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerKey,
                  @cLocation     = @cLoc,
                  @cToLocation   = @cToLOC,
                  @cID           = @cID,     -- Sugg FromID
                  @cToID         = @cDropID, -- DropID
                  @cSKU          = @cSKU,
                  @nQTY          = @nQTY_PD,
                  @cRefNo1       = @cLoadKey,   
                  @cRefNo2       = @cTaskDetailKey,   
                  @cRefNo3       = @cAreakey, 
                  @cRefNo4       = @cAltSKU 

            END
            -- PickDetail have less
            ELSE IF @nQTY_PD < @nBOM_PickQty
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cDropID,
                  Status = '5'
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 69400
                  SET @cErrMsg = rdt.rdtgetmessage( 69400, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               -- EventLog - QTY 
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '3', -- Picking
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerKey,
                  @cLocation     = @cLoc,
                  @cToLocation   = @cToLOC,
                  @cID           = @cID,     -- Sugg FromID
                  @cToID         = @cDropID, -- DropID
                  @cSKU          = @cSKU,
                  @nQTY          = @nQTY_PD,
                  @cRefNo1       = @cLoadKey,   
                  @cRefNo2       = @cTaskDetailKey,   
                  @cRefNo3       = @cAreakey, 
                  @cRefNo4       = @cAltSKU 

               SET @nBOM_PickQty = @nBOM_PickQty - @nQTY_PD -- Reduce balance
            END
            -- PickDetail have more, need to split
            ELSE IF @nQTY_PD > @nBOM_PickQty
            BEGIN
               -- If Status = '5' (full pick), split line if neccessary
               -- If Status = '4' (short pick), no need to split line if already last RPL line to update,
               -- just have to update the pickdetail.qty = short pick qty
              IF @nBOM_PickQty > 0 -- 
              BEGIN
                  -- Get new PickDetailkey
                  EXECUTE dbo.nspg_GetKey
                     'PICKDETAILKEY',
                     10 ,
                     @cNewPickDetailKey OUTPUT,
                     @b_success         OUTPUT,
                     @n_err             OUTPUT,
                     @c_errmsg          OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SET @nErrNo = 69401
                     SET @cErrMsg = rdt.rdtgetmessage( 69401, @cLangCode, 'DSP') -- 'GetDetKeyFail'
                     GOTO RollBackTran
                  END
                  
                  IF @cFlag = '2'
                  BEGIN
                     -- Create a new PickDetail to hold the balance
                     INSERT INTO dbo.PICKDETAIL (
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                        Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                        DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
                        QTY,
   							TrafficCop,
                        OptimizeCop,
   							TaskDetailkey)
                     SELECT
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
                        '0',
                        DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                        DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                        @nQTY_PD - @nBOM_PickQty, -- QTY
   							NULL, --TrafficCop,
                        '1', --OptimizeCop
   							@cTaskDetailKeySHT
                     FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE PickDetailKey = @cPickDetailKey
                  END
                  ELSE
                  BEGIN
                     -- Create a new PickDetail to hold the balance
                     INSERT INTO dbo.PICKDETAIL (
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                        Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                        DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
                        QTY,
   							TrafficCop,
                        OptimizeCop,
   							TaskDetailkey)
                     SELECT
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
                        CASE WHEN @cStatus = '4' THEN '4' ELSE '0' END,
                        DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                        DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                        @nQTY_PD - @nBOM_PickQty, -- QTY
   							NULL, --TrafficCop,
                        '1', --OptimizeCop
   							@cTaskDetailKeySHT
                     FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE PickDetailKey = @cPickDetailKey
                  END
               
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 69402
                     SET @cErrMsg = rdt.rdtgetmessage( 69402, @cLangCode, 'DSP') --'Ins PDtl Fail'
                     GOTO RollBackTran
                  END

                  -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
                  -- Change orginal PickDetail with exact QTY (with TrafficCop)
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     QTY = @nBOM_PickQty,
                     Trafficcop = NULL
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 69403
                     SET @cErrMsg = rdt.rdtgetmessage( 69403, @cLangCode, 'DSP') --'OffSetPDtlFail'
                     GOTO RollBackTran
                  END

                  -- Confirm orginal PickDetail with exact QTY
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     DropID = @cDropID,
                     Status = '5'
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 69404
                     SET @cErrMsg = rdt.rdtgetmessage( 69404, @cLangCode, 'DSP') --'OffSetPDtlFail'
                     GOTO RollBackTran
                  END

                  -- EventLog - QTY 
                  EXEC RDT.rdt_STD_EventLog
                     @cActionType   = '3', -- Picking
                     @cUserID       = @cUserName,
                     @nMobileNo     = @nMobile,
                     @nFunctionID   = @nFunc,
                     @cFacility     = @cFacility,
                     @cStorerKey    = @cStorerKey,
                     @cLocation     = @cLoc,
                     @cToLocation   = @cToLOC,
                     @cID           = @cID,     -- Sugg FromID
                     @cToID         = @cDropID, -- DropID
                     @cSKU          = @cSKU,
                     @nQTY          = @nBOM_PickQty,  -- Only insert confirmed qty
                     @cRefNo1       = @cLoadKey,   
                     @cRefNo2       = @cTaskDetailKey,   
                     @cRefNo3       = @cAreakey, 
                     @cRefNo4       = @cAltSKU 

                  IF @cStatus = '5'
                  BEGIN
                     SET @nBOM_PickQty = 0 -- Reduce balance
                  END
                  ELSE
                  BEGIN
                     SET @nBOM_PickQty = @nBOM_PickQty - @nQTY_PD
                  END
               END
            END
            
            --IF @nBOM_PickQty = 0 BREAK -- Exit -- (ChewKP01)

            FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
         END
         CLOSE curPD
         DEALLOCATE curPD

         FETCH NEXT FROM CUR_BOM INTO @cComponentSKU, @nBOM_Qty
      END
      CLOSE CUR_BOM
      DEALLOCATE CUR_BOM


   END

   -- Insert DropID table
   IF @nTotalPickQty > 0 
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID) 
         AND ISNULL(RTRIM(@cDropID), '') <> '' 
      BEGIN
         INSERT INTO dbo.DropID
         (Dropid, Droploc, DropIDType, Status, Loadkey, AddDate, AddWho, EditDate, EditWho)
         VALUES
         (@cDropID, @cToLOC, 'C', '0', @cLoadKey, GETDATE(), @cUserName, GETDATE(), @cUserName)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 69405
            SET @cErrMsg = rdt.rdtgetmessage( 69405, @cLangCode, 'DSP') --'InsDropID Fail'
            GOTO RollBackTran
         END
      END
   END 


   --End


--   -- Confirm PK task
--   UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
--      Status = '9',
--      EditDate = GETDATE(), 
--      EditWho = @cUserName
--   WHERE TaskDetailKey = @cTaskDetailKey
--
--   IF @@ERROR <> 0
--   BEGIN
--      SET @nErrNo = 69346
--      SET @cErrMsg = rdt.rdtgetmessage( 69346, @cLangCode, 'DSP') --'UpdTaskDtl Fail'
--      GOTO RollBackTran
--   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN TM_Picking_ConfirmTask

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN TM_Picking_ConfirmTask
END


GO
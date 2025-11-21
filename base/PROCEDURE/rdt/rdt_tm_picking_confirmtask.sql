SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* Store procedure: rdt_TM_Picking_ConfirmTask                            */
/* Copyright      : IDS                                                   */
/*                                                                        */
/* Purpose: Comfirm Pick                                                  */
/*                                                                        */
/* Called from: rdtfnc_TM_Picking                                         */
/*                                                                        */
/* Exceed version: 5.4                                                    */
/*                                                                        */
/* Modifications log:                                                     */
/*                                                                        */
/* Date        Rev   Author   Purposes                                    */
/* 01-02-2009  1.0   James    Created                                     */
/* 25-02-2010  1.1   James    Bug fix on comfirm status (james01)         */
/* 26-02-2010  1.2   Vicky    Add @cAreakey to as a parameter and update  */
/*                            NMV with Areakey (Vicky01)                  */
/* 02-03-2010  1.3   James    Add in EventLog (james02)                   */
/* 02-03-2010  1.3   James    Swap Refno in EventLog (james03)            */
/* 03-03-2010  1.4   James    Misc bug fix (james04)                      */
/* 24-03-2010  1.5   Vicky    Modify: (Vicky02)                           */
/*                            1. For QtyPicked = 0, do not insert DropID  */
/*                               and update NMV task                      */
/* 25-03-2010  1.6   James    When short pick need to clear taskdetailkey */
/*                            to allow task release again (james05)       */
/* 01-05-2010  1.7   Vicky    Update Areakey of FromLOC of NMV task to    */
/*                            TaskDetail.Areakey for TaskType = NMV       */
/*                            (Vicky03)                                   */
/* 08-05-2010  1.8   Vicky    Bug fix - When PDQTY = BOMPickQTY, should   */
/*                            do an offset (Vicky04)                      */
/* 16-06-2010  1.9   Leong    SOS# 176725 - Update EndTime when status 9  */
/*                                          And StartTime when status 0   */
/* 21-07-2010  2.0   James    SOS182663 - Bug fix (james06)               */
/* 20-08-2010  2.1   Vicky    Bug fix on PendingMoveIn deduction (Vicky05)*/
/* 24-08-2010  2.1   Leong    SOS# 187017 - Use TM_PickLog to log data    */
/* 26-08-2010  2.2   ChewKP   Bug Fix (ChewKP01)                          */
/* 16-02-2011  2.3   ChewKP   PendingMoveIn Update By PickDetail.Lot      */
/*                            (ChewKP02)                                  */
/* 21-02-2011  2.3   Leong    SOS# 205459 - Reset @cAltSKU to non-prepack */
/*                                          sku when PickDetail.Sku <>    */
/*                                          BillOfMaterial.ComponentSKU   */
/*                                          And @nPickQty = 0 for BOM sku */
/*                                          short pick purpose only       */
/* 07-07-2011  2.4   Leong    SOS# 220413 - Capture NMV task status before*/
/*                                          release                       */
/**************************************************************************/

CREATE PROC [RDT].[rdt_TM_Picking_ConfirmTask] (
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
   @nErrNo           INT          OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT,  -- screen limitation, 20 char max
   @cAreakey         NVARCHAR(10) = '' -- (Vicky01)
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success         INT,
           @n_err             INT,
           @c_errmsg          NVARCHAR( 250),
           @cPickDetailKey    NVARCHAR( 10),
           @cComponentSKU     NVARCHAR( 20),
           @cNewPickDetailKey NVARCHAR( 10),
           @nQTY_PD           INT,
           @nRowRef           INT,
           @nTranCount        INT,
           @nBOM_Qty          INT,
           @nBOM_PickQty      INT,
           @nSUMBOM_Qty       INT,
           @nNoOfCase         INT,
           @nNoOfLoose        INT,
           @nTotalPickQty     INT,
           @cLOT              NVARCHAR( 10),
           @cToID             NVARCHAR( 18),
           @cPD_SKU           NVARCHAR( 20),
           @cReasonKey        NVARCHAR( 10), -- (Vicky02)
           @nTaskQTY          INT        -- (Vicky05)

   SET @nTranCount = @@TRANCOUNT

   SET @cPD_SKU = '' -- SOS# 205459

   BEGIN TRAN
   SAVE TRAN TM_Picking_ConfirmTask

   SET @nTotalPickQty = @nPickQty

   IF ISNULL(RTRIM(@cToLOC), '') = ''
   BEGIN
      SELECT @cToLOC = ToLOC FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
   END

   INSERT INTO dbo.TM_PickLog
         ( Mobile, Func, StorerKey, UserName, Facility, TaskDetailKey
         , PickDetailKey, LoadKey, SKU, AltSKU, LOC, ToLOC, ID
         , DropID, PickQty, PDQty, Status, Areakey
         , Col1, Col2, Col3, Col4, Col5
         , Col6, Col7, Col8, Col9, Col10 )
   VALUES( @nMobile, @nFunc, @cStorerKey, @cUserName, @cFacility, @cTaskDetailKey
         , '', @cLoadKey, @cSKU, @cAltSKU, @cLOC, @cToLOC, @cID
         , @cDropID, @nPickQty, '', @cStatus, @cAreakey
         , '', '', '', '', ''
         , '', '', '', '', 'CFMTASK' )

   -- SOS# 205459 (Start)
   IF ISNULL(RTRIM(@cAltSKU), '') <> ''
   BEGIN
      IF EXISTS ( SELECT PD.StorerKey, PD.Sku, PD.Qty, BOM.ComponentSKU, BOM.Sku
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND BOM.Sku = @cAltSKU)
                  WHERE O.LoadKey = @cLoadKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.LOC = @cLOC
                  AND PD.ID = @cID
                  AND PD.Status = '0'
                  AND PD.TaskDetailKey = @cTaskDetailKey
                  AND BOM.Sku = @cAltSKU
                  AND PD.SKU <> BOM.ComponentSKU )
      BEGIN
         SELECT @cPD_SKU = MIN(PD.Sku)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND BOM.Sku = @cAltSKU)
         WHERE O.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey
         AND PD.LOC = @cLOC
         AND PD.ID = @cID
         AND PD.Status = '0'
         AND PD.TaskDetailKey = @cTaskDetailKey
         AND BOM.Sku = @cAltSKU
         AND PD.SKU <> BOM.ComponentSKU

         SET @cAltSKU = '' -- Treat BOM Sku as normal sku to short pick it when PickDetail.SKU <> BillOfMaterial.ComponentSKU
         SET @cSKU = ISNULL(RTRIM(@cPD_SKU),'') -- Get PickDetail.SKU to offset PendingMoveIn qty
         SET @nPickQty = 0
      END
   END
   -- SOS# 205459 (End)

   -- Get PickDetail candidate to offset for non prepack bom
   IF ISNULL(RTRIM(@cAltSKU), '') = ''
   BEGIN
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey, PD.QTY, PD.LOT
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      WHERE O.LoadKey  = @cLoadKey
         AND PD.StorerKey  = @cStorerKey
      -- AND PD.SKU = @cSKU
         AND PD.LOC = @cLOC
         AND PD.ID = @cID
         AND PD.Status = '0'
         AND PD.TaskDetailKey = @cTaskDetailKey -- (ChewKP01)
      ORDER BY PickDetailKey
      OPEN curPD
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD, @cLOT
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         INSERT INTO dbo.TM_PickLog
               ( Mobile, Func, StorerKey, UserName, Facility, TaskDetailKey
               , PickDetailKey, LoadKey, SKU, AltSKU, LOC, ToLOC, ID
               , DropID, PickQty, PDQty, Status, Areakey
               , Col1, Col2, Col3, Col4, Col5
               , Col6, Col7, Col8, Col9, Col10 )
         VALUES( @nMobile, @nFunc, @cStorerKey, @cUserName, @cFacility, @cTaskDetailKey
               , @cPickDetailKey, @cLoadKey, @cSKU, @cAltSKU, @cLOC, @cToLOC, @cID
               , @cDropID, @nPickQty, @nQTY_PD, @cStatus, @cAreakey
               , '', '', '', '', ''
               , '', '', '', '', 'CFMTASK-PD' )

         IF @nPickQty < 0    -- (james04)
            SET @nPickQty = 0

         Continue_Offset1:    -- (james04)
         IF @nPickQty = 0
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            -- DropID = @cDropID,    (james04)   if short picked then no need to stamp drop id
               Status = @cStatus,
               OptimizeCop = 'N', -- SOS# 187017
               TaskDetailKey = CASE WHEN @cStatus = '4' AND ISNULL(TaskDetailKey, '') <> ''
                               THEN NULL ELSE TaskDetailKey END  -- (james05)
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 68832
               SET @cErrMsg = rdt.rdtgetmessage( 68832, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- (ChewKP02)
            UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET
               PendingMoveIN = CASE WHEN PendingMoveIN - @nQTY_PD < 0 THEN 0
                               ELSE PendingMoveIN - @nQTY_PD END
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND LOT = @cLOT
               AND LOC = @cToLOC
               AND ID = @cID

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 68837
               SET @cErrMsg = rdt.rdtgetmessage(68837, @cLangCode, 'DSP') --'UpdPenMVInFail'
               GOTO RollBackTran
            END

            -- EventLog - QTY (james02)
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
               @cRefNo1       = @cLoadKey,   -- (james03)
               @cRefNo2       = @cTaskDetailKey,   -- (james03)
               @cRefNo3       = @cAreakey,
               @cRefNo4       = @cAltSKU

            -- (james04)
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
          Status = '5'   -- (james04)
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 68816
               SET @cErrMsg = rdt.rdtgetmessage( 68816, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- EventLog - QTY (james02)
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
               @cRefNo1       = @cLoadKey,   --(james03)
               @cRefNo2       = @cTaskDetailKey,   --(james03)
               @cRefNo3       = @cAreakey,
               @cRefNo4       = @cAltSKU

            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance  -- (ChewKP02)

         END
         -- PickDetail have less
         ELSE IF @nQTY_PD < @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
--               Status = @cStatus
               Status = '5'   -- (james04)
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 68817
               SET @cErrMsg = rdt.rdtgetmessage( 68817, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- EventLog - QTY (james02)
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
               @cRefNo1       = @cLoadKey,   --(james03)
               @cRefNo2       = @cTaskDetailKey,   --(james03)
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
               SET @nErrNo = 68818
               SET @cErrMsg = rdt.rdtgetmessage( 68818, @cLangCode, 'DSP') -- 'GetDetKeyFail'
               GOTO RollBackTran
            END

            -- Create a new PickDetail to hold the balance
            INSERT INTO dbo.PICKDETAIL (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
               Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
               QTY,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
               CASE WHEN @cStatus = '4' THEN '4' ELSE '0' END,
               DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
               @nQTY_PD - @nPickQty, -- QTY
               NULL, --TrafficCop,
               '1'  --OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 68819
               SET @cErrMsg = rdt.rdtgetmessage( 68819, @cLangCode, 'DSP') --'Ins PDtl Fail'
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
               SET @nErrNo = 68820
               SET @cErrMsg = rdt.rdtgetmessage( 68820, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- Confirm orginal PickDetail with exact QTY
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               Status = '5'
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 68821
               SET @cErrMsg = rdt.rdtgetmessage( 68821, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

             -- (ChewKP02)
            UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET
               PendingMoveIN = CASE WHEN PendingMoveIN - (@nQTY_PD - @nPickQty) < 0 THEN 0
                                 ELSE PendingMoveIN - (@nQTY_PD - @nPickQty) END
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND LOT = @cLOT
               AND LOC = @cToLOC
               AND ID = @cID

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 68837
               SET @cErrMsg = rdt.rdtgetmessage(68837, @cLangCode, 'DSP') --'UpdPenMVInFail'
               GOTO RollBackTran
            END

            -- EventLog - QTY (james02)
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
               @cRefNo1       = @cLoadKey,   --(james03)
               @cRefNo2       = @cTaskDetailKey,   --(james03)
               @cRefNo3       = @cAreakey,
               @cRefNo4       = @cAltSKU

--            SET @nPickQty = 0 -- Reduce balance    -- (james04)
               IF @cStatus = '5'    -- (james04)
                  SET @nPickQty = 0 -- Reduce balance
               ELSE
                  SET @nPickQty = @nPickQty - @nQTY_PD
         END

         --IF @nPickQty = 0 BREAK -- Exit  (ChewKP02)

         FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD, @cLOT
      END
      CLOSE curPD
      DEALLOCATE curPD

      -- If short picked then the PendingMoveIn for ToLoc need to be deducted
--      IF @cStatus = '4'
--      BEGIN
--         SELECT @cToLOC = ToLOC,
--                @cToID = ToID,
--                @nTaskQTY = QTY -- (Vicky05)
--         FROM dbo.TaskDetail WITH (NOLOCK)
--         WHERE TaskDetailKey = @cTaskDetailKey
--
--         INSERT INTO dbo.TM_PickLog
--               ( Mobile, Func, StorerKey, UserName, Facility, TaskDetailKey
--               , PickDetailKey, LoadKey, SKU, AltSKU, LOC, ToLOC, ID
--               , DropID, PickQty, PDQty, Status, Areakey
--               , Col1, Col2, Col3, Col4, Col5
--               , Col6, Col7, Col8, Col9, Col10 )
--         SELECT  @nMobile, @nFunc, @cStorerKey, @cUserName, @cFacility, @cTaskDetailKey
--               , '', '', @cSKU, '', '', @cToLOC, @cToID
--               , '', '', '', @cStatus, ''
--               , @nTaskQTY, @nTotalPickQty, PendingMoveIn, Lot, Loc
--               , Id, Sku, '', '', 'CFMTASK-PMI-PD'
--         FROM dbo.LotxLocxID WITH (NOLOCK)
--         WHERE StorerKey = @cStorerKey
--         AND SKU = @cSKU
--         AND LOC = @cToLOC
--         AND ID = @cToID
--
--         UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET
----            PendingMoveIN = CASE WHEN PendingMoveIN - (PendingMoveIN - @nTotalPickQty) < 0 THEN 0
----                              ELSE PendingMoveIN - (PendingMoveIN - @nTotalPickQty) END
--            -- (Vicky05)
--            PendingMoveIN = CASE WHEN PendingMoveIN - (@nTaskQTY - @nTotalPickQty) < 0 THEN 0
--                              ELSE PendingMoveIN - (@nTaskQTY - @nTotalPickQty) END
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
      SELECT @nSUMBOM_Qty = ISNULL(SUM(Qty), 0) FROM dbo.BillOfMaterial WITH (NOLOCK) WHERE SKU = @cAltSKU
      AND StorerKey = @cStorerKey   -- (james06)

      SELECT @nNoOfLoose = 0, @nNoOfCase = 0
      SET @nNoOfCase = @nPickQty / @nSUMBOM_Qty
      SET @nNoOfLoose = @nPickQty % @nSUMBOM_Qty

      INSERT INTO dbo.TM_PickLog
            ( Mobile, Func, StorerKey, UserName, Facility, TaskDetailKey
            , PickDetailKey, LoadKey, SKU, AltSKU, LOC, ToLOC, ID
            , DropID, PickQty, PDQty, Status, Areakey
            , Col1, Col2, Col3, Col4, Col5
            , Col6, Col7, Col8, Col9, Col10 )
      VALUES( @nMobile, @nFunc, @cStorerKey, @cUserName, @cFacility, @cTaskDetailKey
            , @cPickDetailKey, @cLoadKey, @cSKU, @cAltSKU, @cLOC, @cToLOC, @cID
            , @cDropID, @nPickQty, @nQTY_PD, @cStatus, @cAreakey
            , @nNoOfCase, @nNoOfLoose, @nSUMBOM_Qty, '', ''
            , '', '', '', '', 'CFMTASK-B4BOM-1' )

      DECLARE CUR_BOM CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT ComponentSKU, Qty FROM dbo.BillOfMaterial WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cAltSKU
      Order BY Sequence
      OPEN CUR_BOM
      FETCH NEXT FROM CUR_BOM INTO @cComponentSKU, @nBOM_Qty
      WHILE @@FETCH_STATUS <> -1
      BEGIN

      INSERT INTO dbo.TM_PickLog
               ( Mobile, Func, StorerKey, UserName, Facility, TaskDetailKey
               , PickDetailKey, LoadKey, SKU, AltSKU, LOC, ToLOC, ID
               , DropID, PickQty, PDQty, Status, Areakey
               , Col1, Col2, Col3, Col4, Col5
               , Col6, Col7, Col8, Col9, Col10 )
         VALUES( @nMobile, @nFunc, @cStorerKey, @cUserName, @cFacility, @cTaskDetailKey
               , @cPickDetailKey, @cLoadKey, @cSKU, @cAltSKU, @cLOC, @cToLOC, @cID
               , @cDropID, @nPickQty, @nQTY_PD, @cStatus, @cAreakey
               , @cComponentSKU, @nBOM_Qty, '', '', ''
               , '', '', '', '', 'CFMTASK-B4BOM-2' )

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

            INSERT INTO dbo.TM_PickLog
                  ( Mobile, Func, StorerKey, UserName, Facility, TaskDetailKey
                  , PickDetailKey, LoadKey, SKU, AltSKU, LOC, ToLOC, ID
                  , DropID, PickQty, PDQty, Status, Areakey
                  , Col1, Col2, Col3, Col4, Col5
                  , Col6, Col7, Col8, Col9, Col10 )
            VALUES( @nMobile, @nFunc, @cStorerKey, @cUserName, @cFacility, @cTaskDetailKey
                  , @cPickDetailKey, @cLoadKey, @cSKU, @cAltSKU, @cLOC, @cToLOC, @cID
                  , @cDropID, @nPickQty, @nQTY_PD, @cStatus, @cAreakey
                  , @nNoOfCase, @nBOM_Qty, @nBOM_PickQty, '', ''
                  , '', '', '', '', 'CFMTASK-BOM' )

            IF @nBOM_PickQty < 0   -- (james04)
               SET @nBOM_PickQty = 0

            Continue_Offset2:    -- (james04)
            IF @nBOM_PickQty = 0
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
--                  DropID = @cDropID, -- (james04) if short picked then no need to stamp drop id
                  Status = @cStatus,
                  OptimizeCop = 'B', -- SOS# 187017
                  TaskDetailKey = CASE WHEN @cStatus = '4' AND ISNULL(TaskDetailKey, '') <> ''
                                  THEN NULL ELSE TaskDetailKey END  -- (james05)
               WHERE PickDetailKey = @cPickDetailKey


               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 68833
                  SET @cErrMsg = rdt.rdtgetmessage( 68833, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               -- EventLog - QTY (james02)
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
                  @nQTY          = 0,
                  @cRefNo1       = @cLoadKey,   --(james03)
                  @cRefNo2       = @cTaskDetailKey,   --(james03)
                  @cRefNo3       = @cAreakey,
                  @cRefNo4       = @cAltSKU

               -- (james04)
               -- Continue to offset the rest of the pickdetail line, if any
               FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
               IF @@FETCH_STATUS = 0
                  GOTO Continue_Offset2
               ELSE
                  BREAK -- Exit
            END

            -- Exact match
            IF @nQTY_PD = @nBOM_PickQty
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cDropID,
--                  Status = @cStatus  (james01)
                  Status = '5'
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 68822
                  SET @cErrMsg = rdt.rdtgetmessage( 68822, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               SET @nBOM_PickQty = @nBOM_PickQty - @nQTY_PD -- Reduce balance -- (Vicky04)

               -- EventLog - QTY (james02)
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
                  @cRefNo1       = @cLoadKey,   --(james03)
                  @cRefNo2       = @cTaskDetailKey,   --(james03)
                  @cRefNo3       = @cAreakey,
                  @cRefNo4       = @cAltSKU

            END
            -- PickDetail have less
            ELSE IF @nQTY_PD < @nBOM_PickQty
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cDropID,
--                  Status = @cStatus  (james01)
                  Status = '5'
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 68823
                  SET @cErrMsg = rdt.rdtgetmessage( 68823, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               -- EventLog - QTY (james02)
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
                  @cRefNo1       = @cLoadKey,   --(james03)
                  @cRefNo2       = @cTaskDetailKey,   --(james03)
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
              IF @nBOM_PickQty > 0 -- (Vicky04)
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
                     SET @nErrNo = 68824
                     SET @cErrMsg = rdt.rdtgetmessage( 68824, @cLangCode, 'DSP') -- 'GetDetKeyFail'
                     GOTO RollBackTran
                  END

                  -- Create a new PickDetail to hold the balance
                  INSERT INTO dbo.PICKDETAIL (
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                     Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
                     QTY,
                     TrafficCop,
                     OptimizeCop)
                  SELECT
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
                     CASE WHEN @cStatus = '4' THEN '4' ELSE '0' END,
                     DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                     @nQTY_PD - @nBOM_PickQty, -- QTY
                     NULL, --TrafficCop,
                     '1'  --OptimizeCop
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 68825
                     SET @cErrMsg = rdt.rdtgetmessage( 68825, @cLangCode, 'DSP') --'Ins PDtl Fail'
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
                     SET @nErrNo = 68826
                     SET @cErrMsg = rdt.rdtgetmessage( 68826, @cLangCode, 'DSP') --'OffSetPDtlFail'
                     GOTO RollBackTran
                  END

                  -- Confirm orginal PickDetail with exact QTY
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     DropID = @cDropID,
                     Status = '5'
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 68827
                     SET @cErrMsg = rdt.rdtgetmessage( 68827, @cLangCode, 'DSP') --'OffSetPDtlFail'
                     GOTO RollBackTran
                  END

                  -- EventLog - QTY (james02)
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
                     @cRefNo1       = @cLoadKey,   --(james03)
                     @cRefNo2       = @cTaskDetailKey,   --(james03)
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

          --  IF @nBOM_PickQty = 0 BREAK -- Exit -- Comment By (Vicky04)

            FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
         END
         CLOSE curPD
         DEALLOCATE curPD

         FETCH NEXT FROM CUR_BOM INTO @cComponentSKU, @nBOM_Qty
      END
      CLOSE CUR_BOM
      DEALLOCATE CUR_BOM

      -- If short picked then the PendingMoveIn for ToLoc need to be deducted
      IF @cStatus = '4'
      BEGIN
         SELECT @cToLOC = ToLOC,
                @cToID = ToID,
                @nTaskQTY = QTY -- (Vicky05)
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         INSERT INTO dbo.TM_PickLog
               ( Mobile, Func, StorerKey, UserName, Facility, TaskDetailKey
               , PickDetailKey, LoadKey, SKU, AltSKU, LOC, ToLOC, ID
               , DropID, PickQty, PDQty, Status, Areakey
               , Col1, Col2, Col3, Col4, Col5
               , Col6, Col7, Col8, Col9, Col10 )
         SELECT  @nMobile, @nFunc, @cStorerKey, @cUserName, @cFacility, @cTaskDetailKey
               , '', '', '', '', '', @cToLOC, @cToID
               , '', '', '', @cStatus, ''
               , @nTaskQTY, @nTotalPickQty, PendingMoveIn, Lot, Loc
               , Id, Sku, '', '', 'CFMTASK-PMI-BOM'
         FROM dbo.LotxLocxID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND LOC = @cToLOC
         AND ID = @cToID

--         DECLARE CUR_UPDPENDINGMVIN CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
--         SELECT ComponentSKU FROM dbo.BillOfMaterial WITH (NOLOCK) WHERE SKU = @cAltSKU
--         OPEN CUR_UPDPENDINGMVIN
--         FETCH NEXT FROM CUR_UPDPENDINGMVIN INTO @cComponentSKU
--         WHILE @@FETCH_STATUS <> -1
--         BEGIN
            UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET
--               PendingMoveIN = CASE WHEN PendingMoveIN - (PendingMoveIN - @nTotalPickQty) < 0 THEN 0
--                                 ELSE PendingMoveIN - (PendingMoveIN - @nTotalPickQty) END
               -- (Vicky05)
               PendingMoveIN = CASE WHEN PendingMoveIN - (@nTaskQTY - @nTotalPickQty) < 0 THEN 0
                                 ELSE PendingMoveIN - (@nTaskQTY - @nTotalPickQty) END
            WHERE StorerKey = @cStorerKey
               --AND SKU = @cComponentSKU
               AND LOC = @cToLOC
               AND ID = @cToID

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 68833
               SET @cErrMsg = rdt.rdtgetmessage( 68833, @cLangCode, 'DSP') --'UpdPenMVInFail'
               GOTO RollBackTran
            END
--
--            FETCH NEXT FROM CUR_UPDPENDINGMVIN INTO @cComponentSKU
--         END
--         CLOSE CUR_UPDPENDINGMVIN
--         DEALLOCATE CUR_UPDPENDINGMVIN
      END
   END

   -- Insert DropID table
   IF @nTotalPickQty > 0 --- (Vicky02)
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)
         AND ISNULL(RTRIM(@cDropID), '') <> '' -- (Vicky02)
      BEGIN
         INSERT INTO dbo.DropID
         (Dropid, Droploc, DropIDType, Status, Loadkey, AddDate, AddWho, EditDate, EditWho)
         VALUES
         (@cDropID, @cToLOC, 'C', '0', @cLoadKey, GETDATE(), @cUserName, GETDATE(), @cUserName)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 68828
            SET @cErrMsg = rdt.rdtgetmessage( 68828, @cLangCode, 'DSP') --'InsDropID Fail'
            GOTO RollBackTran
         END
      END
   END -- (Vicky02)

   -- Activate non-inventory move task
   IF @nTotalPickQty > 0 -- (Vicky02)
   BEGIN
      IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE RefTaskKey = @cTaskDetailKey AND TaskType = 'NMV')
      BEGIN
         -- (Vicky03) - Start
         DECLARE @cNMV_Areakey NVARCHAR(10)
               , @cNMV_PAZone  NVARCHAR(10)
               , @cNMV_Status  NVARCHAR(10) -- SOS# 220413

         SELECT @cNMV_PAZone = ISNULL(RTRIM(LOC.PutawayZone), '')
         FROM dbo.TaskDetail TD WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.Loc = TD.FromLOC)
         WHERE TD.RefTaskKey = @cTaskDetailKey
            AND TD.TaskType = 'NMV'
            AND TD.Status = 'W'

         SELECT TOP 1 @cNMV_Areakey = ISNULL(RTRIM(AreaKey), '')
         FROM dbo.AreaDetail WITH (NOLOCK)
         WHERE PutawayZone = @cNMV_PAZone
         -- (Vicky03) - End

         SET @cNMV_Status = ''
         SELECT @cNMV_Status = ISNULL(RTRIM(Status), '') -- SOS# 220413
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE RefTaskKey = @cTaskDetailKey

         INSERT INTO dbo.TM_PickLog
               ( Mobile, Func, StorerKey, UserName, Facility, TaskDetailKey
               , DropID, Col1, Col2, Col3, Col4, Col10 )
         VALUES( @nMobile, @nFunc, @cStorerKey, @cUserName, @cFacility, @cTaskDetailKey
               , @cDropID, @nTotalPickQty, @cNMV_PAZone, @cNMV_Areakey, @cNMV_Status, 'CFMTASK-NMV-0' )

         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            ToID = @cDropID,
            Qty = @nTotalPickQty,
            Status = '0',
            Trafficcop = NULL,
            EditDate = GETDATE(),
            EditWho = @cUserName,
            StartTime = GETDATE(),  -- SOS# 176725
            --AreaKey = ISNULL(RTRIM(@cAreakey), '') -- (Vicky01)
            Areakey = ISNULL(RTRIM(@cNMV_Areakey), '') -- (Vicky03)
          , Message03 = 'CFMTASK-NMV-0' -- SOS# 220413
         WHERE RefTaskKey = @cTaskDetailKey
            AND TaskType = 'NMV'
            AND Status = 'W' -- (Vicky02)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 68829
            SET @cErrMsg = rdt.rdtgetmessage( 68829, @cLangCode, 'DSP') --'Upd NMV fail'
          GOTO RollBackTran
         END
      END

      -- Update TaskManagerUser with current DropID, LoadKey, Loc
      UPDATE dbo.TaskManagerUser WITH (ROWLOCK) SET
         LastDropID = @cDropID,
         LastLoadKey = @cLoadKey,
         LastLoc = @cToLOC,
         EditDate = GETDATE(),
         EditWho = @cUserName,
         TrafficCop = NULL
      WHERE UserKey = @cUserName

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 68830
         SET @cErrMsg = rdt.rdtgetmessage( 68830, @cLangCode, 'DSP') --'UpdTMUser Fail'
         GOTO RollBackTran
      END
    -- (Vicky02) - Start
   END
   ELSE
   BEGIN
      IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE RefTaskKey = @cTaskDetailKey AND TaskType = 'NMV')
      BEGIN
         SELECT @cReasonKey = RTRIM(ReasonKey)
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            Qty = @nTotalPickQty,
            Status = '9',
            Trafficcop = NULL,
            EditDate = GETDATE(),
            EditWho = @cUserName,
            ReasonKey = @cReasonKey,
            Message01 = 'NMVCFM',   -- SOS# 176725
            EndTime   = GETDATE()   -- SOS# 176725
         WHERE RefTaskKey = @cTaskDetailKey
            AND TaskType = 'NMV'
            AND Status = 'W'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 68835
            SET @cErrMsg = rdt.rdtgetmessage( 68835, @cLangCode, 'DSP') --'Upd NMV fail'
            GOTO RollBackTran
         END
      END

      -- Update TaskManagerUser with current LoadKey, Loc
      UPDATE dbo.TaskManagerUser WITH (ROWLOCK) SET
         LastLoadKey = @cLoadKey,
         LastLoc = @cLOC, -- VNA
         EditDate = GETDATE(),
         EditWho = @cUserName,
         TrafficCop = NULL
      WHERE UserKey = @cUserName

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 68836
         SET @cErrMsg = rdt.rdtgetmessage( 68836, @cLangCode, 'DSP') --'UpdTMUser Fail'
         GOTO RollBackTran
      END
   END
   -- (Vicky02) - End

   -- Confirm PK task
   UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
      Status    = '9',
      Message01 = 'PKCFM',   -- SOS# 176725
      EndTime   = GETDATE(), -- SOS# 176725
      EditDate  = GETDATE(),
      EditWho   = @cUserName
   WHERE TaskDetailKey = @cTaskDetailKey
     AND TaskType = 'PK'     -- SOS# 176725

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 68831
      SET @cErrMsg = rdt.rdtgetmessage( 68831, @cLangCode, 'DSP') --'UpdTaskDtl Fail'
      GOTO RollBackTran
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN TM_Picking_ConfirmTask

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN TM_Picking_ConfirmTask
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdt_TM_DyLogPickJW01                                     */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#175740 - Jack Will TM Dynamic Picking                        */
/*                     - Called By rdtfnc_TM_DynamicPick                     */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2014-07-24 1.0  James    Modified from rdt_TMDynamicPick_LogPick (james01)*/
/* 2014-12-02 1.1  James    SOS326850 - Clear pending route (james02)        */
/* 2015-04-01 1.2  James    SOS337577 - Add pkkslipno into eventlog (james03)*/
/* 2015-06-25 1.3  James    SOS332896 - Allow create PA qty (james04)        */
/* 2015-09-30 1.4  TLTING   Deadlock Tune                                    */
/* 2015-11-26 1.5  James    Deadlock Tune (james04)                          */
/* 2017-04-25 1.6  Leong    IN00321283 - Bug Fix.                            */
/*****************************************************************************/

CREATE PROC [RDT].[rdt_TM_DyLogPickJW01](
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cDropID         NVARCHAR( 20),
   @cToToteno       NVARCHAR( 20),
   @cLoadkey        NVARCHAR( 10),
   @cTaskStorer     NVARCHAR( 15),
   @cSKU            NVARCHAR( 20),
   @cFromLoc        NVARCHAR( 10),
   @cID             NVARCHAR( 18),
   @cLot            NVARCHAR( 10),
   @cTaskdetailkey  NVARCHAR( 10),
   @nPrevTotQty     INT,
   @nBoxQty         INT,
   @nTaskQty        INT,
   @nTotPickQty     INT   OUTPUT,
   @nErrNo          INT   OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
     @nCaseRemainQty INT
   , @nAvailQty      INT
   , @nMoveQty       INT
   , @nPKQty         INT
   , @nPAQty         INT
   , @nPickRemainQty INT
   , @nTranCount     INT
   , @b_Success      INT
   , @cPickdetailkey       NVARCHAR( 10)
   , @cNewpickdetailkey    NVARCHAR( 10)
   , @cOrderkey            NVARCHAR( 10)
   , @cPickSlipNo          NVARCHAR( 10)
   , @cUOM                 NVARCHAR( 10)
   , @nQtyToPicked         INT
   , @cPTS_LOC             NVARCHAR( 10)
   , @cNextLOT             NVARCHAR( 10)
   , @cUserName            NVARCHAR( 15)
   , @cFacility            NVARCHAR( 5)
   , @nRowRef              INT

   DECLARE
      @cInit_Final_Zone    NVARCHAR( 10),  -- (james02)
      @cFinalWCSZone       NVARCHAR( 10),  -- (james02)
      @cWCSKey             NVARCHAR( 10),  -- (james02)
      @c_curWCSkey         NVARCHAR( 10)

   SET @c_curWCSkey = ''
   SET @nCaseRemainQty = 0 -- IN00321283

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TM_DyLogPickJW01 -- For rollback or commit only our own transaction

   SELECT @cUserName = UserName, @cFacility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @nTotPickQty = @nPrevTotQty + @nBoxQty

   IF ISNULL(@cLOT, '') = ''
   BEGIN
      SELECT @cLOT = LOT
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey
   END

   DECLARE C_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PK.Pickdetailkey, PK.Qty, PK.Lot, PK.Orderkey
   FROM   dbo.PICKDETAIL PK WITH (NOLOCK)
   JOIN   dbo.ORDERS ORDERS WITH (NOLOCK) ON (Orders.Orderkey = PK.Orderkey)
   JOIN   dbo.LOC L WITH (NOLOCK) ON PK.Loc = L.LOC -- (SHONG01)
   LEFT OUTER JOIN (SELECT ConsigneeKey, MIN(LOC) As LOC
                    FROM StoreToLocDetail WITH (NOLOCK)
                    WHERE [Status] = '1'
                    GROUP BY ConsigneeKey ) As stld ON stld.ConsigneeKey = ORDERS.ConsigneeKey
   WHERE  Orders.Loadkey = @cLoadkey
   AND    PK.Status = '0'
   AND    PK.CaseID = ''
   AND    PK.Sku    = @cSKU
   AND    PK.ToLoc  = @cFromLoc
   AND    PK.Taskdetailkey = @cTaskdetailkey    --(Kc03)
   ORDER BY L.PutawayZone, stld.LOC, Orders.Priority, Orders.Orderkey -- (SHONG01)

   OPEN C_PICKDETAIL
   FETCH NEXT FROM C_PICKDETAIL INTO  @cPickdetailkey , @nPKQty, @cLot, @cOrderkey
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                     Where UCCNo = RTRIM( @cToToteno)
                     AND SKU = RTRIM( @cSKU)
                     AND Sourcekey = RTRIM( @cTaskdetailkey))
      BEGIN
         INSERT dbo.UCC (UCCNO,     Storerkey,        SKU,     Qty,        Sourcekey,    SourceType,
                        Status,     Lot,              Loc,     Id,         Orderkey,         Orderlinenumber,
                        Wavekey,    Pickdetailkey,    Externkey)
         SELECT @cToToteno,  Storerkey,  Sku,  @nBoxQty,  @cTaskdetailkey,  'RDTDynamicPick',
                '0',       Lot,        Loc,  ID,         Orderkey,         Orderlinenumber,
                Wavekey,   Pickdetailkey,    Pickdetailkey
         FROM  dbo.PICKDETAIL WITH (NOLOCK)
         WHERE PICKDETAILKey = @cPickdetailkey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50212
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsertUCCFail
            GOTO ROLLBACKTRAN
         END
      END -- UCC not exists

      --create pickheader
      SET @cPickSlipno = ''
      SELECT @cPickSlipno = PickheaderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
       -- Create Pickheader
      IF ISNULL(@cPickSlipno, '') = ''
      BEGIN
         EXECUTE dbo.nspg_GetKey
         'PICKSLIP',
         9,
         @cPickslipno   OUTPUT,
         @b_success     OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 50203
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenPickSlipNoFail
            GOTO ROLLBACKTRAN
         END

         SELECT @cPickslipno = 'P' + @cPickslipno

         INSERT INTO dbo.PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)
         VALUES (@cPickslipno, @cLoadKey, @cOrderKey, '0', 'D', '')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50204
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickHdrFail
            GOTO ROLLBACKTRAN
         END
      END --ISNULL(@cPickSlipno, '') = ''


      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         INSERT INTO dbo.PickingInfo
         (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)
         VALUES
         (@cPickSlipNo, GETDATE(), @cUserName, NULL, @cUserName)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50205
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ScanInFail
            GOTO RollBackTran
         END
      END

      SELECT @cUOM = RTRIM(PACK.PACKUOM3)
      FROM dbo.PACK PACK WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE SKU.Storerkey = @cTaskStorer
      AND   SKU.SKU = @cSKU

      -- pickdetail
      UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
      SET   CASEID = @cToToteno
           ,DROPID = @cDropID
           ,PickSlipNo = @cPickSlipNo
           ,STATUS = '3'
           ,EditDate = GETDATE()
           ,EditWho = SUSER_SNAME()
           ,TRAFFICCOP = NULL
      WHERE Pickdetailkey = @cPickdetailkey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 50206
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail
         GOTO ROLLBACKTRAN
      END

      IF @nPKQty = @nBoxQty
      BEGIN
         -- case fulfill exactly 1 pickdetail required qty
         SET @nMoveQty = @nBoxQty
         SET @nBoxQty = 0
      END
      ELSE IF @nPKQty > @nBoxQty
      BEGIN
         -- case can fully fulfill 1 pickdetail and pickdetail has remaining qty to fulfill
         -- need to split the pickdetail
         SET @nMoveQty        = @nBoxQty
         SET @nPickRemainQty  = @nPKQty - @nBoxQty
         SET @nBoxQty  = 0

         -- generate new pickdetail
         EXECUTE dbo.nspg_GetKey
         'PICKDETAILKEY',
         10,
         @cNewpickdetailkey OUTPUT,
         @b_Success         OUTPUT,
         @nErrNo            OUTPUT,
         @cErrMsg           OUTPUT

         IF @b_Success = 0
         BEGIN
            SET @nErrNo = 50207
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GenPickkeyErr
            GOTO ROLLBACKTRAN
         END

         UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
         SET   QTY         = @nMoveQty,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME(),
               TRAFFICCOP  = NULL
         WHERE Pickdetailkey = @cPickdetailkey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50208     --(KC04)
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail
            GOTO ROLLBACKTRAN
         END

         INSERT dbo.PICKDETAIL
            (  PickDetailKey,    PickHeaderKey, OrderKey,      OrderLineNumber,  Lot,           Status,
               Storerkey,        Sku,           UOM,              UOMQty,        Qty,              QtyMoved,
               Loc,              ID,            PackKey,       UpdateSource,     CartonGroup,   CartonType,
               ToLoc,            DoReplenish,   ReplenishZone, DoCartonize,      PickMethod,
               WaveKey,          EffectiveDate, ShipFlag,         PickSlipNo,    Taskdetailkey,
               ArchiveCOP,       TrafficCop,    OptimizeCop)
         SELECT @cNewpickdetailkey,  PickHeaderKey,    OrderKey,     OrderLineNumber,  Lot,     '0',
               Storerkey,           Sku,              UOM,           @nPickRemainQty,  @nPickRemainQty,  QtyMoved,
               Loc,                 ID,               PackKey,       UpdateSource,     CartonGroup,      CartonType,
               ToLoc,               DoReplenish,      ReplenishZone, DoCartonize,      PickMethod,
               WaveKey,             EffectiveDate,    ShipFlag,         PickSlipNo,    Taskdetailkey,
               ArchiveCOP,          NULL,             '1'               --(KC01)
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE PICKDETAILKey = @cPickdetailkey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50209
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPickDetailFail
            GOTO ROLLBACKTRAN
         END

      END --@nPKQty > @nBoxQty
      ELSE IF @nPKQty < @nBoxQty
      BEGIN
      -- case can fully fulfill 1 pickdetail and has remaining to fulfill another pickdetail
         SET @nMoveQty = @nPKQty
         SET @nBoxQty = @nBoxQty - @nPKQty
      END

      --keep log of inventory to move later during pallet close
      --the last caseid always stamped to rdt.rdtDPKLog so when overpicked it is always last caseid
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtDPKLog WITH (NOLOCK)
                     WHERE DropID = @cDropID
                     AND SKU = @cSKU
                     AND FromLoc = @cFromLoc
                     AND FromID = @cID
                     AND FromLot = @cLot)
      BEGIN
         INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromID, Fromlot, QtyMove, PAQty, CaseID, BOMSKU, Taskdetailkey, UserKey)
             VALUES (@cDropID, @cSKU, @cFromLoc, @cID, @cLot, @nMoveQty, 0, @cToToteno, @cSKU, @cTaskdetailkey, @cUserName)

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 50213
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDPKLogFail
            GOTO ROLLBACKTRAN
         END
      END
      ELSE
      BEGIN
         -- Update using primary key (james04)
         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef FROM rdt.rdtDPKLog WITH (NOLOCK)
         WHERE CaseID  = @cToToteno
         AND   SKU     = @cSKU
         AND   FromLoc = @cFromLoc
         AND   FromID  = @cID
         AND   FromLot = @cLot
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @nRowRef
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE rdt.rdtDPKLog WITH (ROWLOCK) SET
               QtyMove = QtyMove + @nMoveQty,
               BOMSKU  = @cSku,
               CaseID  = @cToToteno
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 50214
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdDPKLogFai
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               GOTO ROLLBACKTRAN
            END

            FETCH NEXT FROM CUR_UPD INTO @nRowRef
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD
      END

      --(Kc05) - start
      EXEC RDT.rdt_STD_EventLog
           @cActionType    = '3', -- Picking
           @cUserID        = @cUserName,
           @nMobileNo      = @nMobile,
           @nFunctionID    = @nFunc,
           @cFacility      = @cFacility,
           @cStorerKey     = @cTaskStorer,
           @cLocation      = @cFromLoc,
           @cID            = @cID,
           @cSKU           = @cSKU,
           @cUOM           = @cUOM,
           @nQTY           = @nMoveQty,
           @cLot           = @cLOT,
           @cRefNo1        = @cOrderKey,
           @cRefNo2        = @cDropID,
           @cRefNo3        = @cPickSlipNo,
           @cPickSlipNo    = @cPickSlipNo
         , @cTaskDetailKey = @cTaskdetailkey
         , @cRefNo4        = @nBoxQty
      --(Kc05) - end

      IF @nBoxQty = 0
      BEGIN
         BREAK
      END
      FETCH NEXT FROM C_PICKDETAIL INTO  @cPickdetailkey , @nPKQty, @cLot, @cOrderkey
   END --while
   CLOSE C_PICKDETAIL
   DEALLOCATE C_PICKDETAIL

   --Handle overpicking  (james04)
   IF @nBoxQty > 0
   BEGIN
      /***********************
      * STEP 1               *
      ***********************/
      -- use the pickdetail defined lot as 1st priority for overpicking
      -- taking QtyReplen into consideration for calculation of AvailQty
      -- as we do not want to take from lot that has been promised for other DPK and DRP tasks
      SET @nAvailQty = 0
      SET @nPAQty = 0

      --SELECT  @nAvailQty = ISNULL((LLI.QTY - LLI.QtyAllocated - LLI.QTYPICKED - LLI.QTYREPLEN),0)
      SELECT  @nAvailQty = ISNULL((LLI.QTY - LLI.QTYPICKED),0)
      FROM  dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN  dbo.LOT WITH (NOLOCK) ON LOT.Lot = lli.Lot AND lot.Status = 'OK'
      WHERE LLI.SKU        = @cSKU
      AND   LLI.Storerkey  = @cTaskStorer
      AND   LLI.LOC        = @cFromLoc
      AND   LLI.ID         = @cID
      AND   LLI.Lot        = @cLot

      IF @nAvailQty > 0
      BEGIN
         IF @nAvailQty >= @nBoxQty -- 1 lot able to fulfill case qty
         BEGIN
            SET @nPAQty = @nBoxQty
         END
         ELSE IF @nAvailQty < @nBoxQty
         BEGIN
            SET @nPAQty = @nAvailQty
         END

         SET @nBoxQty = @nBoxQty - @nPAQty
         SET @nCaseRemainQty = @nBoxQty -- IN00321283

         -- log case qty for putaway
         INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromID, Fromlot, QtyMove, PAQty, CaseID, BOMSku, Taskdetailkey, UserKey)
             VALUES (@cDropID, @cSKU, @cFromLoc, @cID, @cLot, @nPAQty, @nPAQty, @cToToteno, @cSku,  @cTaskdetailkey, @cUserName)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50219     --(Kc04)
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDPKLogFai
            GOTO ROLLBACKTRAN
         END

         UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)
         SET   QtyReplen   = QtyReplen + @nPAQty
         WHERE SKU         = @cSKU
         AND   Storerkey   = @cTaskStorer
         AND   LOC         = @cFromLoc
         AND   ID          = @cID
         AND   LOT         = @cLot

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50220     --(Kc04)
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdLotLocIDFail
            GOTO ROLLBACKTRAN
         END
      END -- @nAvailQty > 0

      IF @nCaseRemainQty > 0
      BEGIN
         /***********************
         * STEP 2               *
         ***********************/
         -- retrieve other lots to use
         SET @nPAQty = 0
         DECLARE C_LOTxLOCxID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT  LOT, (QTY - QTYPICKED)
         FROM  dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE SKU = @cSKU
         AND   Storerkey = @cTaskStorer
         AND   LOC = @cFromLoc
         AND   ID  = @cID
         AND   LOT <> @cLot
         AND   (QTY - QTYPICKED)  > 0
         ORDER BY LOT
         OPEN C_LOTxLOCxID

         FETCH NEXT FROM C_LOTxLOCxID INTO  @cLot, @nAvailQty
         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            IF @nBoxQty >= @nAvailQty
            BEGIN
               SET @nPAQty =  @nAvailQty
            END
            ELSE
            BEGIN
               SET @nPAQty =  @nBoxQty
            END

            INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromID, Fromlot, QtyMove, PAQty, CaseID, BOMSKU, Taskdetailkey, UserKey)
                VALUES (@cDropID, @cSKU, @cFromLoc, @cID, @cLot, @nPAQty, @nPAQty, @cToToteno, @cSku, @cTaskdetailkey, @cUserName)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 50221     --(Kc04)
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDPKLogFai
               GOTO ROLLBACKTRAN
            END

            UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)
            SET   QtyReplen = QtyReplen + @nPAQty
            WHERE SKU = @cSKU
            AND   Storerkey = @cTaskStorer
            AND   LOC = @cFromLoc
            AND   ID  = @cID
            AND   LOT = @cLot

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 50222     --(Kc04)
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdLotLocIDFail
               GOTO ROLLBACKTRAN
            END

            SET @nCaseRemainQty = @nCaseRemainQty - @nPAQty
            IF @nCaseRemainQty = 0
            BEGIN
               BREAK
            END

            FETCH NEXT FROM C_LOTxLOCxID INTO  @cLot, @nAvailQty
         END
         CLOSE C_LOTxLOCxID
         DEALLOCATE C_LOTxLOCxID
      END --@nCaseRemainQty > 0

      IF @nCaseRemainQty > 0
      BEGIN
         SET @nErrNo = 50223
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FailToFindINV
         GOTO ROLLBACKTRAN
      END
   END --@nBoxQty > 0

   IF ISNULL( @cPickSlipNo, '') = ''
      SELECT @cPickSlipNo = PickHeaderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE ExternOrderKey = @cLoadkey

   --DropID
   IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) Where DropID = @cDropID)
   BEGIN
      INSERT INTO dbo.DROPID
      (DropID, DropLoc, DropIDType, Status,  Loadkey, PickSlipNo)
      Values
      (@cDropID, '', 'C', '0', @cLoadkey, @cPickSlipNo)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 50201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDropIDFail
         GOTO ROLLBACKTRAN
      END
   END

   --DropIDDetail
   IF NOT EXISTS (SELECT 1 FROM dbo.DROPIDDETAIL WITH (NOLOCK) Where DropID = @cDropID And ChildID = @cToToteno)
   BEGIN
      INSERT INTO dbo.DROPIDDETAIL (DropID, ChildID)
      VALUES (@cDropID, @cToToteno)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 50201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDpIDDetFail
         GOTO ROLLBACKTRAN
      END

      IF EXISTS ( SELECT 1 FROM dbo.Dropid WITH (NOLOCK) WHERE DropID = @cToToteno)
      BEGIN
         DELETE FROM dbo.DROPIDDETAIL
         WHERE DropID = @cToToteno

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50210
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelDIDDetFail
            GOTO ROLLBACKTRAN
         END

         DELETE FROM dbo.DROPID
         WHERE DropID = @cToToteno

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50211
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelDropIDFail
            GOTO ROLLBACKTRAN
         END
      END

      -- (james02)
      -- Cancel all pending route for tote
      SET @cInit_Final_Zone = ''
      SET @cFinalWCSZone = ''

      SELECT TOP 1
         @cFinalWCSZone = Final_Zone,
         @cInit_Final_Zone = Initial_Final_Zone
      FROM dbo.WCSRouting WITH (NOLOCK)
      WHERE ToteNo = @cToToteno
      AND ActionFlag = 'I'
      ORDER BY WCSKey Desc

      SET @cWCSKey = ''
      EXECUTE nspg_GetKey
         'WCSKey',
         10,
         @cWCSKey   OUTPUT,
         @b_Success OUTPUT,
         @nErrNo    OUTPUT,
         @cErrMsg   OUTPUT

      IF @nErrNo<>0
      BEGIN
         SET @nErrNo = 50215
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetWCSKey Fail
         GOTO ROLLBACKTRAN
      END

      INSERT INTO WCSRouting
      (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)
      VALUES
      ( @cWCSKey, @cToToteno, ISNULL(@cInit_Final_Zone,''), ISNULL(@cFinalWCSZone,''), 'D', @cTaskStorer, @cFacility, '', 'PK')

      SELECT @nErrNo = @@ERROR

      IF @nErrNo<>0
      BEGIN
         SET @nErrNo = 50216
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrtRouteFail
         GOTO ROLLBACKTRAN
      END

      DECLARE Item_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         Select  WCSKey
         FROM WCSRouting WITH (NOLOCK)
         WHERE  ToteNo = @cToToteno

      OPEN Item_cur
      FETCH NEXT FROM Item_cur INTO @c_curWCSkey
      WHILE @@FETCH_STATUS = 0
      BEGIN

         -- Update WCSRouting.Status = '5' When Delete
         UPDATE WCSRouting WITH (ROWLOCK)
         SET    STATUS = '5',
         EditDate = GETDATE(),
         EditWho =SUSER_SNAME()
         WHERE  WCSkey = @c_curWCSkey

         SELECT @nErrNo = @@ERROR
         IF @nErrNo<>0
         BEGIN
            SET @nErrNo = 50217
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdRouteFail
            GOTO ROLLBACKTRAN
         END

         FETCH NEXT FROM Item_cur INTO @c_curWCSkey
      END
      CLOSE Item_cur
      DEALLOCATE Item_cur

      EXEC dbo.isp_WMS2WCSRouting
           @cWCSKey,
           @cTaskStorer,
           @b_Success   OUTPUT,
           @nErrNo      OUTPUT,
           @cErrMsg     OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 50218
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrtWCSRECFail
         GOTO ROLLBACKTRAN
      END
   END

   COMMIT TRAN rdt_TM_DyLogPickJW01 -- Only commit change made in here
   GOTO Quit

   ROLLBACKTRAN:
      ROLLBACK TRAN rdt_TM_DyLogPickJW01
      SET @nTotPickQty = @nPrevTotQty              --(Kc07)

   QUIT:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN


GO
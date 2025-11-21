SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdt_PTS_ConfirmTote                                      */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#175741 - PTS Store Sort                                      */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date        Rev  Author   Purposes                                        */
/* 28-Jul-2010 1.0  Shong    Creation                                        */
/* 09-Aug-2010 1.1  Vicky    Bug Fix - Confirm Pack (Vicky01)                */
/* 17-Aug-2010 1.2  Vicky    Additional Parameter (Vicky02)                  */
/* 30-Aug-2010 1.3  Shong    Store ToToteNo to AltSKU Column (Shong01)       */
/* 14-Oct-2010 1.4  Shong    Swap LOT (Shongxx)                              */
/* 12-Jan-2010 1.5  James    Bug fix (james01)                               */
/* 28-Jun-2012 1.6  TLTING   Remove Traceinfo                                */
/* 24-Apr-2013 1.8  James    SOS273234 - Fix logic on getting lot (james02)  */
/*****************************************************************************/

CREATE PROC [RDT].[rdt_PTS_ConfirmTote](
     @nMobile         INT
   , @cStorerKey      NVARCHAR(15)
   , @cCaseID         NVARCHAR(20)
   , @cLOC            NVARCHAR(10)
   , @cSKU            NVARCHAR(20)
   , @cConsigneeKey   NVARCHAR(15)
   , @nQtyEnter       INT
   , @cToToteNo       NVARCHAR(20)
   , @cShortPick      NVARCHAR(1) = 'N'
   , @bSuccess        INT OUTPUT
   , @nErrNo          INT OUTPUT
   , @cErrMsg         NVARCHAR(1024) OUTPUT
   , @cSuggLOC        NVARCHAR(10) -- (Vicky02)

)
AS
BEGIN

SET NOCOUNT ON
SET ANSI_DEFAULTS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

SET @bSuccess = 1

BEGIN TRAN

DECLARE @cPickDetailKey    NVARCHAR(10)
      , @cID               NVARCHAR(18)
      , @nPickedQty        INT
      , @nQtyTake          INT
      , @cLOT              NVARCHAR(10)
      , @cNewPickDetailKey NVARCHAR(10)
      , @cPackkey          NVARCHAR(10)
      , @cLangCode         NVARCHAR(3)
      , @cTaksDetailKey    NVARCHAR(10)
      , @cFromLOC          NVARCHAR(10)
      , @cPickSlipNo       NVARCHAR(10)
      , @cOrderKey         NVARCHAR(10)
      , @cUOM              NVARCHAR(10)
      , @nQtyAvailable     INT
      , @cLoadKey          NVARCHAR(10)
      , @cPDOrderkey       NVARCHAR(10) -- (Vicky01)
      , @cPDPickSlipNo     NVARCHAR(10) -- (Vicky01)
      , @nSumPackQTY       INT  -- (Vicky01)
      , @nSumPickQTY       INT  -- (Vicky01)
      , @nLotQty           INT
      , @nQtyToMove        INT
      , @nSameLot          INT  -- (james02)

   SELECT @cLangCode        = Lang_code
   FROM   rdt.RDTMOBREC r WITH (NOLOCK)
   WHERE  r.Mobile = @nMobile

   -- Short sort. Update pickdetail status to '4' and split line if necessary
   DECLARE Cursor_OffSetPickDetail CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PD.PickDetailKey, PD.LOT, PD.ID, PD.Qty, PD.OrderKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      WHERE PD.StorerKey = @cStorerKey
      AND PD.CaseID = @cCaseID
      AND PD.LOC = @cSuggLOC -- @cLOC -- (Vicky02)
      AND PD.SKU = @cSKU
      AND PD.Status = '3'
      AND O.ConsigneeKey = @cConsigneeKey

   OPEN Cursor_OffSetPickDetail
   FETCH NEXT FROM Cursor_OffSetPickDetail INTO @cPickDetailKey, @cLOT, @cID, @nPickedQty, @cOrderKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @nQtyEnter = 0
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                Status = '4', TrafficCop=NULL
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 70525
            SET @cErrMsg = rdt.rdtgetmessage( 70525, @cLangCode, 'DSP') --'OffSetPDtlFail'
            GOTO Confirm_Tote_Failed
         END

         SET @nQtyTake = 0
         GOTO GET_NEXT
      END
      ELSE
      -- Exact match
      IF @nPickedQty = @nQtyEnter
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                Status = '5', AltSKU = @cToToteNo
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 70526
            SET @cErrMsg = rdt.rdtgetmessage( 70526, @cLangCode, 'DSP') --'OffSetPDtlFail'
            GOTO Confirm_Tote_Failed
         END

         SET @nQtyTake = @nQtyEnter
      END
      -- PickDetail have less
      ELSE IF @nPickedQty < @nQtyEnter
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                Status = '5', AltSKU = @cToToteNo
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 70527
            SET @cErrMsg = rdt.rdtgetmessage( 70526, @cLangCode, 'DSP') --'OffSetPDtlFail'
            GOTO Confirm_Tote_Failed
         END

         SET @nQtyTake = @nPickedQty
      END
      -- PickDetail have more, need to split
      ELSE
      IF @nPickedQty > @nQtyEnter
      BEGIN
         -- Get new PickDetailkey
         EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @nErrNo            OUTPUT,
               @cErrMsg           OUTPUT

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 70528
            SET @cErrMsg = rdt.rdtgetmessage( 70528, @cLangCode, 'DSP') -- 'GetDetKeyFail'
            GOTO Confirm_Tote_Failed
         END
         -- Create a new PickDetail to hold the balance
         INSERT INTO dbo.PICKDETAIL (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
               Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
               QTY, TrafficCop, OptimizeCop, TaskDetailKey)
         SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, @nPickedQty, QTYMoved,
               CASE WHEN @cShortPick = 'Y' THEN '4' ELSE [Status] END,
               DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
               @nPickedQty - @nQtyEnter, -- QTY
               NULL, --TrafficCop,
               '1',  --OptimizeCop
               TaskDetailKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 70529
            SET @cErrMsg = rdt.rdtgetmessage( 70529, @cLangCode, 'DSP') --'Ins PDtl Fail'
            GOTO Confirm_Tote_Failed
         END

         -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
         -- Change orginal PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nQtyEnter,
               Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 70530
            SET @cErrMsg = rdt.rdtgetmessage( 70530, @cLangCode, 'DSP') --'OffSetPDtlFail'
            GOTO Confirm_Tote_Failed
         END

         -- Confirm orginal PickDetail with exact QTY
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                Status = '5', AltSKU = @cToToteNo
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 70531
            SET @cErrMsg = rdt.rdtgetmessage( 70531, @cLangCode, 'DSP') --'OffSetPDtlFail'
            GOTO Confirm_Tote_Failed
         END

         SET @nQtyTake = @nQtyEnter
      END -- IF @nPickedQty > @nQtyEnter

      -- Get PackKey
      SELECT @cPackkey = S.PackKey,
             @cUOM     = P.PackUOM3
      FROM dbo.SKU S WITH (NOLOCK)
      JOIN dbo.PACK P WITH (NOLOCK) ON P.PACKKey = S.PACKKey
      WHERE S.StorerKey = @cStorerKey
      AND S.SKU = @cSKU

      -- Get TaksDetailKey
      SELECT @cTaksDetailKey = Sourcekey
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND UCCNo = @cCaseID

      -- Get FromLOC (which is ToLOC for DPK)
      SELECT @cFromLOC = ToLOC
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND TaskDetailKey = @cTaksDetailKey

      SET @bSuccess = 1

      -- Increase Qty in LotxLocxID
      SET @nQtyAvailable = 0
      SET @nSameLot = 0
--      comment by james02
--      SELECT @nQtyAvailable = ISNULL(SUM(QTY),0)
--      FROM   dbo.LOTxLOCxID lli WITH (NOLOCK)
--      WHERE  LOC = @cFromLOC
--      AND    lli.StorerKey = @cStorerKey
--      AND    lli.Sku = @cSKU
--      AND    ID  = ''
      
      -- Try to get the qty from same lot (same as pickdetail.lot) to minimize the swap lot scenario
      SELECT @nQtyAvailable = ISNULL(SUM(QTY - QTYALLOCATED - QTYPICKED - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)),0)
      FROM   dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE  LOC = @cFromLOC
      AND    StorerKey = @cStorerKey
      AND    Sku = @cSKU
      AND    ID  = ''
      AND    Lot = @cLOT   -- (james02)

      -- Check if same lot from pickdetail has enough qty
      -- if not then take other lot from same loc. 
      IF @nQtyAvailable < @nQtyTake
      BEGIN
         SET @nQtyAvailable = 0
         SELECT @nQtyAvailable = ISNULL(SUM(QTY - QTYALLOCATED - QTYPICKED - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)),0)
         FROM   dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE  LOC = @cFromLOC
         AND    StorerKey = @cStorerKey
         AND    Sku = @cSKU
         AND    ID  = ''
         
         IF @nQtyAvailable < @nQtyTake
         BEGIN
            SET @nErrNo = 70594
            SET @cErrMsg = rdt.rdtgetmessage( 70594, @cLangCode, 'DSP') --'Qty'
            GOTO Confirm_Tote_Failed
         END
         
         SET @nSameLot = 0
      END
      ELSE
      BEGIN
         SET @nSameLot = 1
      END
      
      DECLARE CUR_LOTxLOCxID_Induction CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LOT, Qty
         FROM  LOTxLOCxID WITH (NOLOCK)
         WHERE  LOC = @cFromLOC
         AND    StorerKey = @cStorerKey
         AND    Sku = @cSKU
         AND    ID  = ''
         AND    Qty > 0
         AND    Lot = CASE WHEN @nSameLot = 1 THEN @cLOT ELSE Lot END -- (james02)

         SET @nQtyToMove = @nQtyTake

      OPEN CUR_LOTxLOCxID_Induction
      FETCH NEXT FROM CUR_LOTxLOCxID_Induction INTO @cLOT, @nLotQty

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nQtyToMove < @nLotQty
            SET @nLotQty = @nQtyToMove

         SET @bSuccess = 0
         --SELECT @cLot '@cLot', @cSuggLOC '@cSuggLOC', @cFromLOC '@cFromLOC', @nLotQty '@nLotQty'
         EXECUTE nspItrnAddMove
            @n_ItrnSysId    = NULL,
            @c_itrnkey      = NULL,
            @c_StorerKey    = @cStorerKey,
            @c_SKU          = @cSKU,
            @c_Lot          = @cLOT,
            @c_FromLoc      = @cFromLOC,
            @c_FromID       = '',
            @c_ToLoc        = @cSuggLOC, --@cLOC,    -- (Vicky02)
            @c_ToID         = @cID,
            @c_Status       = '',
            @c_Lottable01   = '',
            @c_Lottable02   = '',
            @c_Lottable03   = '',
            @d_Lottable04   = NULL,
            @d_Lottable05   = NULL,
            @n_casecnt      = 0,
            @n_innerpack    = 0,
            @n_Qty          = @nLotQty,
            @n_Pallet       = 0,
            @f_Cube         = 0,
            @f_GrossWgt     = 0,
            @f_NetWgt       = 0,
            @f_OtherUnit1   = 0,
            @f_OtherUnit2   = 0,
            @c_SourceKey    = @cPickDetailKey,
            @c_SourceType   = 'rdt_PTS_ConfirmTote',
            @c_PackKey      = @cPackkey,
            @c_UOM          = @cUOM,
            @b_UOMCalc      = 1,
            @d_EffectiveDate = NULL,
            @b_Success      = @bSuccess   OUTPUT,
            @n_Err          = @nErrNo     OUTPUT,
            @c_ErrMsg       = @cErrmsg    OUTPUT

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = @nErrNo
            SET @cErrMsg = @cErrmsg
            GOTO Confirm_Tote_Failed
         END

         -- Reduce pendingmovein and increase qty in LotxLocxID
         UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET
               PendingMoveIn = CASE WHEN (PendingMoveIn - @nLotQty) <= 0 THEN 0
                               ELSE PendingMoveIn - @nLotQty END
         WHERE StorerKey = @cStorerKey
            AND LOC = @cSuggLOC --@cLOC -- (Vicky02)
            AND SKU = @cSKU

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 69844
            SET @cErrMsg = rdt.rdtgetmessage( 69844, @cLangCode, 'DSP') --'UPD LLI FAIL'
            GOTO Confirm_Tote_Failed
         END

         SET @nQtyToMove = @nQtyToMove - @nLotQty

         IF @nQtyToMove <= 0   -- (james01)
            BREAK

         FETCH NEXT FROM CUR_LOTxLOCxID_Induction INTO @cLOT, @nLotQty
      END
      CLOSE CUR_LOTxLOCxID_Induction
      DEALLOCATE CUR_LOTxLOCxID_Induction

      SELECT @cPickSlipNo = PickHeaderKey,
             @cLoadKey    = ExternOrderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      IF ISNULL(@cPickSlipNo, '') = ''
      BEGIN
         SET @nErrNo = 69823
         SET @cErrMsg = rdt.rdtgetmessage( 69823, @cLangCode, 'DSP') --PKSLIP REQ
         GOTO Confirm_Tote_Failed
      END

      -- Create packheader if not exists
      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cOrderKey)
      BEGIN
         INSERT INTO dbo.PackHeader
               (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
         SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo
         FROM  dbo.PickHeader PH WITH (NOLOCK)
         JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
         WHERE PH.PickHeaderKey = @cPickSlipNo

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 69824
            SET @cErrMsg = rdt.rdtgetmessage( 69824, @cLangCode, 'DSP') --INS PAHDR FAIL
            GOTO Confirm_Tote_Failed
         END
      END

      -- Create packdetail
      -- CartonNo and LabelLineNo will be inserted by trigger
      IF NOT EXISTS( SELECT 1 FROM dbo.PackDetail pd WITH (NOLOCK)
                     WHERE pd.PickSlipNo = @cPickSlipNo
                     AND   pd.LabelNo = @cToToteNo
                     AND   pd.StorerKey = @cStorerKey
                     AND   pd.sku = @cSKU )
      BEGIN
         INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, DropID)
         VALUES
               (@cPickSlipNo, 0, @cToToteNo, '00000', @cStorerKey, @cSKU, @nQtyTake, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cToToteNo) -- (james02)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 69825
            SET @cErrMsg = rdt.rdtgetmessage( 69825, @cLangCode, 'DSP') --INS PADET FAIL
            GOTO Confirm_Tote_Failed
         END
      END
      ELSE
      BEGIN
         UPDATE PackDetail
         SET Qty = Qty + @nQtyTake
         WHERE PickSlipNo = @cPickSlipNo
         AND LabelNo = @cToToteNo
         AND StorerKey = @cStorerKey
         AND sku = @cSKU

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 70593
            SET @cErrMsg = rdt.rdtgetmessage( 70593, @cLangCode, 'DSP') --upd PADET FAIL
            GOTO Confirm_Tote_Failed
         END
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                     WHERE DropID = @cToToteNo)
      BEGIN
         INSERT INTO dbo.DropID
               (Dropid, Droploc, LabelPrinted, [Status], ManifestPrinted, Loadkey, PickSlipNo)
         VALUES(@cToToteNo, @cLOC, 'N', '0', 'N', ISNULL(@cLoadKey,''), @cPickSlipNo)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 70595
            SET @cErrMsg = rdt.rdtgetmessage( 70595, @cLangCode, 'DSP') --InsDropIdFail
            GOTO Confirm_Tote_Failed
         END
      END

      SET @nQtyEnter = @nQtyEnter - @nPickedQty

      IF @nQtyEnter <= 0
         BREAK -- Exit

      GET_NEXT:
      FETCH NEXT FROM Cursor_OffSetPickDetail INTO @cPickDetailKey, @cLOT, @cID, @nPickedQty, @cOrderKey
   END
   CLOSE Cursor_OffSetPickDetail
   DEALLOCATE Cursor_OffSetPickDetail

   -- (Vicky01) - Pack Confirmation - Start
   DECLARE Cursor_PackConf CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT PD.OrderKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      WHERE PD.StorerKey = @cStorerKey
      AND PD.CaseID = @cCaseID
      AND PD.LOC = @cSuggLOC -- @cLOC  -- (Vicky02)
      AND PD.SKU = @cSKU
      AND PD.Status = '5'
      AND O.ConsigneeKey = @cConsigneeKey

   OPEN Cursor_PackConf
   FETCH NEXT FROM Cursor_PackConf INTO @cPDOrderkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @cPDPickSlipNo = PickSlipNo
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE OrderKey = @cPDOrderkey

      SELECT @nSumPackQTY = SUM(QTY)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPDPickSlipNo

      SELECT @nSumPickQTY = SUM(QTY)
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE Orderkey = @cPDOrderkey
      AND   Status = '5'

      IF @nSumPackQTY = @nSumPickQTY
      BEGIN
         -- Confirm Packheader
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET
               STATUS = '9',
               ArchiveCop = NULL
         WHERE PickSlipNo = @cPDPickSlipNo

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 69863
            SET @cErrMsg = rdt.rdtgetmessage( 69863, @cLangCode, 'DSP') --'Upd PaHdr Fail'
            GOTO Confirm_Tote_Failed
         END
      END

      FETCH NEXT FROM Cursor_PackConf INTO @cPDOrderkey
   END
   CLOSE Cursor_PackConf
   DEALLOCATE Cursor_PackConf
      -- (Vicky01) - Pack Confirmation - End

   UPDATE dbo.UCC WITH (ROWLOCK) SET 
      [Status] =  '6'
   WHERE StorerKey = @cStorerKey
   AND   UccNo = @cCaseID
   
   COMMIT TRAN
   RETURN

   Confirm_Tote_Failed:
   ROLLBACK TRAN
   SET @bSuccess = 0
 END -- procedure

GO
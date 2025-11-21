SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/
/* Copyright: LF Logistics                                              */
/* Purpose: Stamp CaseID on PickDetail.DropID                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2014-03-14 1.0  Ung      SOS305459 Created                           */
/* 2017-03-27 1.1  Ung      WMS-1373 Add pallet ID                      */
/* 2018-05-16 1.2  Ung      WMS-4846 CodeLKUP MHCSSCAN add StorerKey    */
/* 2023-02-16 1.4  WyeChun  JSM-129049 Extend CaseID (18) length to 40  */    
/*                          to store the proper barcode (WC01)          */  
/************************************************************************/
  
CREATE  PROCEDURE [RDT].[rdt_CaseIDCapture_Confirm] (  
   @nMobile    INT,
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3),
   @cUserName  NVARCHAR( 18),
   @cFacility  NVARCHAR( 5),
   @cStorerKey NVARCHAR( 15),
   @cOrderKey  NVARCHAR( 15),
   @cSKU       NVARCHAR( 20),   
   @cBatchNo   NVARCHAR( 18),   
   @cCaseID    NVARCHAR( 40),     --WC01   
   @cPalletID  NVARCHAR( 18),   
   @nErrNo     INT OUTPUT,   
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @bSuccess       INT
   DECLARE @nPickQTY       INT
   DECLARE @nCaseCnt       INT
   DECLARE @nQTY_PD        INT
   DECLARE @cPickDetailKey NVARCHAR(10)
   DECLARE @cBrand         NVARCHAR(10)

   -- Get SKU info
   SELECT 
      @cBrand   = Class, 
      @nCaseCnt = CAST( Pack.CaseCnt AS INT)
   FROM SKU WITH (NOLOCK)
      JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE StorerKey = @cStorerKey 
      AND SKU = @cSKU 

   -- Check brand need to capture
   IF EXISTS( SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = @cBrand AND StorerKey = @cStorerKey)
   BEGIN
      SET @nErrNo = 86001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BrandNoCapture
      GOTO Quit
   END

   -- Check SKU on PickSlip
   IF NOT EXISTS( SELECT TOP 1 1 
      FROM PickDetail WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey 
         AND SKU = @cSKU 
         AND UOM IN ('1', '2')
         AND Status <> '4' --4=Short
         AND QTY > 0)
   BEGIN
      SET @nErrNo = 86002
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
      GOTO Quit
   END

   -- Check Lottable02 on PickSlip
   IF NOT EXISTS( SELECT TOP 1 1 
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
      WHERE PD.OrderKey = @cOrderKey 
         AND PD.SKU = @cSKU 
         AND PD.UOM IN ('1', '2')
         AND PD.Status <> '4' --4=Short
         AND PD.QTY > 0
         AND LA.Lottable02 = @cBatchNo)
   BEGIN
      SET @nErrNo = 86004
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch NotInPS
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- BatchNo
      GOTO Quit
   END

   -- Check CaseID double scan
   IF EXISTS( SELECT TOP 1 1 
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
      WHERE PD.OrderKey = @cOrderKey 
         AND PD.SKU = @cSKU 
         AND PD.UOM IN ('1', '2')
         AND PD.DropID = @cCaseID
         AND LA.Lottable02 = @cBatchNo)
   BEGIN
      SET @nErrNo = 86003
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseID scanned
      EXEC rdt.rdtSetFocusField @nMobile, 5 -- CaseID
      GOTO Quit
   END


   /*-------------------------------------------------------------------------------

                              Split PickDetail, Stamp DropID

   -------------------------------------------------------------------------------*/
   IF @nCaseCnt = 0
      SET @nCaseCnt = 1

   SET @nPickQty = @nCaseCnt 

   DECLARE @tPD TABLE
   (
      PickDetailKey NVARCHAR(10) NOT NULL,
      QTY           INT      NOT NULL
   )

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_CaseIDCapture_Confirm

   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey, PD.QTY
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
      WHERE PD.OrderKey = @cOrderKey 
         AND PD.SKU = @cSKU 
         AND PD.UOM IN ('1', '2')
         AND PD.Status <> '4' --4=Short
         AND PD.QTY > 0
         AND PD.DropID = ''
         AND LA.Lottable02 = @cBatchNo

   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Exact match
      IF @nQTY_PD = @nPickQty
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cCaseID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 86005
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         INSERT INTO @tPD (PickDetailKey, QTY) VALUES (@cPickDetailKey, @nPickQty)
         SET @nPickQty = 0 -- Reduce balance
         BREAK
      END

      -- PickDetail have less
      ELSE IF @nQTY_PD < @nPickQty
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cCaseID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 86006
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         INSERT INTO @tPD (PickDetailKey, QTY) VALUES (@cPickDetailKey, @nPickQty)
         SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance
      END

      -- PickDetail have more, need to split
      ELSE IF @nQTY_PD > @nPickQty
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
            SET @nErrNo = 86007
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
            GOTO RollBackTran
         END

         -- Create a new PickDetail to hold the balance
         INSERT INTO dbo.PickDetail (
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
            DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
            PickDetailKey,
            Status, 
            QTY,
            TrafficCop,
            OptimizeCop)
         SELECT
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
            DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
            @cNewPickDetailKey,
            Status, 
            @nQTY_PD - @nPickQty, -- QTY
            NULL, --TrafficCop
            '1'   --OptimizeCop
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 86008
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
            GOTO RollBackTran
         END

         -- Change original PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            QTY = @nPickQty,
            DropID = @cCaseID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 86009
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         INSERT INTO @tPD (PickDetailKey, QTY) VALUES (@cPickDetailKey, @nPickQty)
         SET @nPickQty = 0 -- Reduce balance
         BREAK
      END
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
   END
   -- select * from @tPDGO

   -- Check any offset
   IF @nPickQty = @nCaseCnt
   BEGIN
      SET @nErrNo = 86010
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPKDtl Offset
      GOTO RollBackTran
   END
      
   -- Check fully offset
   IF @nPickQty <> 0
   BEGIN
      SET @nErrNo = 86011
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotFullyOffset
      GOTO RollBackTran
   END
   
   -- Update UCC
   UPDATE UCC SET 
      Status = '6'
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cBatchNo + @cCaseID
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 86012
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
      GOTO RollBackTran
   END
   
   COMMIT TRAN rdt_CaseIDCapture_Confirm
   
   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '4', -- Move
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @cOrderKey   = @cOrderKey, 
      @cLottable02 = @cBatchNo, 
      @cDropID     = @cCaseID, 
      @cID         = @cPalletID
      
   GOTO Quit
   
RollBackTran:
      ROLLBACK TRAN rdt_CaseIDCapture_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO
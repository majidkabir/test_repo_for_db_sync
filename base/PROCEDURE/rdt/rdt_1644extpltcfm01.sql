SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1644ExtPltCfm01                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pallet built Comfirm Pick SP.                               */
/*                                                                      */
/* Called from: rdtfnc_PalletBuild_SerialNo                             */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 18-Mar-2019 1.0  James       WMS7505.Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1644ExtPltCfm01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5), 
   @cPickSlipNo   NVARCHAR( 10), 
   @cDropID       NVARCHAR( 20),
   @cSKU          NVARCHAR( 20), 
   @cCaseID       NVARCHAR( 20), 
   @cSerialNo     NVARCHAR( MAX), 
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT
   DECLARE @fCaseCount     FLOAT
   DECLARE @cUOM           NVARCHAR( 10)
   DECLARE @cZone          NVARCHAR( 10)
   DECLARE @cPH_LoadKey    NVARCHAR( 10)
   DECLARE @cPH_OrderKey   NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @nCaseCount     INT
   DECLARE @nQTY_PD        INT
   DECLARE @bsuccess       INT
   DECLARE @n_err          INT
   DECLARE @c_errmsg       NVARCHAR( 20)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @nIsAnyMore2Scan INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1644ExtPltCfm01

   --If configkey is on,   Check Pickdetail.status = @rdt.storerconfig.svalue 
   --If configkey is not exist, Check Pickdetail.status = æ5Æ
   --If configkey is off,  no checking
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   SELECT @cUOM = RTRIM(PACK.PACKUOM3), 
          @fCaseCount = PACK.CaseCnt
   FROM dbo.PACK PACK WITH (NOLOCK)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE SKU.Storerkey = @cStorerKey
   AND   SKU.SKU = @cSKU

   SET @nCaseCount = rdt.rdtFormatFloat( @fCaseCount)
   --set @nCaseCount = 2
   IF ISNULL( @nCaseCount, 0) <= 0
   BEGIN
      SET @nErrNo = 136101
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Casecnt = 0'
      GOTO RollBackTran
   END                  

   SELECT @cZone = Zone, @cPH_OrderKey = OrderKey, @cPH_LoadKey = ExternOrderKey     
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo  

   SET @nIsAnyMore2Scan = 1

   If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'    
   BEGIN    
      IF NOT EXISTS ( SELECT 1
         FROM dbo.PickDetail PD (NOLOCK) 
         JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
         WHERE RPL.PickslipNo = @cPickSlipNo    
         AND   PD.Status < @cPickConfirmStatus
         AND   PD.QTY > 0
         AND   PD.StorerKey  = @cStorerKey
         AND   ISNULL( PD.Notes, '') = '')
         SET @nIsAnyMore2Scan = 0
   END
   ELSE
   IF ISNULL(@cPH_OrderKey, '') <> ''
   BEGIN      
      IF NOT EXISTS ( SELECT 1
         FROM dbo.PickHeader PH (NOLOCK)     
         JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
         WHERE PH.PickHeaderKey = @cPickSlipNo    
         AND   PD.Status < @cPickConfirmStatus
         AND   PD.QTY > 0
         AND   PD.StorerKey  = @cStorerKey
         AND   ISNULL( PD.Notes, '') = '')
         SET @nIsAnyMore2Scan = 0
   END
   ELSE
   BEGIN
      IF NOT EXISTS ( SELECT 1
         FROM dbo.PickHeader PH (NOLOCK)     
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
         JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
         WHERE PH.PickHeaderKey = @cPickSlipNo    
         AND   PD.Status < @cPickConfirmStatus
         AND   PD.QTY > 0
         AND   PD.StorerKey  = @cStorerKey
         AND   ISNULL( PD.Notes, '') = '')
         SET @nIsAnyMore2Scan = 0
   END

   IF @nIsAnyMore2Scan = 0
   BEGIN
      SET @nErrNo = 136109
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Fully Picked'
      GOTO RollBackTran
   END

   If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'    
   BEGIN    
      -- Get PickDetail candidate to offset based on RPL's candidate
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey, QTY  
      FROM dbo.PickDetail PD (NOLOCK) 
      JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
      WHERE RPL.PickslipNo = @cPickSlipNo    
      AND   PD.Status < @cPickConfirmStatus
      AND   PD.QTY > 0
      AND   PD.StorerKey  = @cStorerKey
      AND   PD.SKU = @cSKU
      AND   ISNULL( PD.Notes, '') = ''
      ORDER BY PD.PickDetailKey
   END
   ELSE
   IF ISNULL(@cPH_OrderKey, '') <> ''
   BEGIN      
      -- Get PickDetail candidate to offset based on RPL's candidate
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, QTY  
      FROM dbo.PickHeader PH (NOLOCK)     
      JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
      WHERE PH.PickHeaderKey = @cPickSlipNo    
      AND   PD.Status < @cPickConfirmStatus
      AND   PD.QTY > 0
      AND   PD.StorerKey  = @cStorerKey
      AND   PD.SKU = @cSKU
      AND   ISNULL( PD.Notes, '') = ''
      ORDER BY PD.PickDetailKey
   END
   ELSE
   BEGIN
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, QTY  
      FROM dbo.PickHeader PH (NOLOCK)     
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
      JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
      WHERE PH.PickHeaderKey = @cPickSlipNo    
      AND   PD.Status < @cPickConfirmStatus
      AND   PD.QTY > 0
      AND   PD.StorerKey  = @cStorerKey
      AND   PD.SKU = @cSKU
      AND   ISNULL( PD.Notes, '') = ''
      ORDER BY PD.PickDetailKey
   END
   OPEN curPD
   FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Exact match
      IF @nQTY_PD = @nCaseCount
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cDropID,
            CaseID = @cCaseID, 
            Notes = @cSerialNo,
            Status = @cPickConfirmStatus
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 136102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
            GOTO RollBackTran
         END

         SET @nCaseCount = 0 -- Reduce balance
      END
      -- PickDetail have less
      ELSE IF @nQTY_PD < @nCaseCount
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cDropID,
            CaseID = @cCaseID, 
            Notes = @cSerialNo,
            Status = @cPickConfirmStatus
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 136103
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
            GOTO RollBackTran
         END
         ELSE

         SET @nCaseCount = 0 -- Reduce balance
      END
      -- PickDetail have more, need to split
      ELSE IF @nQTY_PD > @nCaseCount
      BEGIN
         DECLARE @cNewPickDetailKey NVARCHAR( 10)
         EXECUTE dbo.nspg_GetKey
            'PICKDETAILKEY',
            10 ,
            @cNewPickDetailKey OUTPUT,
            @bsuccess          OUTPUT,
            @n_err             OUTPUT,
            @c_errmsg          OUTPUT

         IF @bsuccess <> 1
         BEGIN
            SET @nErrNo = 136104
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKeyFail'
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
            Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
            @nQTY_PD - @nCaseCount, -- QTY
            NULL, --TrafficCop,
            '1'  --OptimizeCop
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 136105
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'
            GOTO RollBackTran
         END

         -- Get PickDetail info  
         DECLARE @cPD_LoadKey      NVARCHAR( 10)  
         DECLARE @cPD_OrderKey     NVARCHAR( 10)  
         DECLARE @cOrderLineNumber NVARCHAR( 5)  
         SELECT 
            @cPD_Loadkey = O.LoadKey, 
            @cPD_OrderKey = OD.OrderKey, 
            @cOrderLineNumber = OD.OrderLineNumber
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         WHERE PD.PickDetailkey = @cPickDetailKey  
                       
         -- Insert into   
         INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
         VALUES (@cNewPickDetailKey, @cPickSlipNo, @cPD_OrderKey, @cOrderLineNumber, @cPD_Loadkey)  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 136108  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
            GOTO RollBackTran  
         END  

         -- Change orginal PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            QTY = @nCaseCount,
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME(),
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 137158
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
            GOTO RollBackTran
         END

         -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cDropID,
            CaseID = @cCaseID, 
            Notes = @cSerialNo,
            Status = @cPickConfirmStatus
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 136106
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
            GOTO RollBackTran
         END

         SET @nCaseCount = 0 -- Reduce balance
      END

      --IF @cPickConfirmStatus <> '5'
      --BEGIN
      --   UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
      --      Status = '5'
      --   WHERE PickDetailKey = @cPickDetailKey

      --   IF @@ERROR <> 0
      --   BEGIN
      --      SET @nErrNo = 136107
      --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Cfm Pick Fail'
      --      GOTO RollBackTran
      --   END
      --END

      IF @nCaseCount = 0 
      BEGIN
         BREAK 
      END

      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
   END
   CLOSE curPD
   DEALLOCATE curPD


   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1644ExtPltCfm01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1644ExtPltCfm01

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
            
/************************************************************************/            
/* Store procedure: rdt_ClusterPickCfm17                                */            
/* Copyright      : IDS                                                 */            
/*                                                                      */            
/* Purpose: Cluster Pick Comfirm Pick SP.                               */            
/*          1. Insert/Update PackInfo with carton type                  */            
/*          2. Insert/Update PickDetail with carton type                */            
/*                                                                      */            
/* Called from: rdtfnc_Cluster_Pick                                     */            
/*                                                                      */            
/* Exceed version: 5.4                                                  */            
/*                                                                      */            
/* Modifications log:                                                   */            
/*                                                                      */            
/* Date        Rev  Author      Purposes                                */            
/* 2021-04-20  1.0  Rungtham W  WMS-16797. Created                      */            
/* 2022-09-20  1.1  James       WMS-20784 Generate pickslip if not      */  
/*                              exists (james01)                        */
/*                              Add auto scan in and pack confirm       */
/************************************************************************/   
CREATE    PROCEDURE [RDT].[rdt_ClusterPickCfm17](            
   @nMobile                   INT,             
   @nFunc                     INT,             
   @cLangCode                 NVARCHAR( 3),             
   @nStep                     INT,             
   @nInputKey                 INT,             
   @cFacility                 NVARCHAR( 5),             
   @cStorerkey                NVARCHAR( 15),            
   @cWaveKey                  NVARCHAR( 10),            
   @cLoadKey                  NVARCHAR( 10),            
   @cOrderKey                 NVARCHAR( 10),             
   @cPutAwayZone              NVARCHAR( 10),             
   @cPickZone                 NVARCHAR( 10),             
   @cSKU                      NVARCHAR( 20),             
   @cPickSlipNo               NVARCHAR( 10),             
   @cLOT                      NVARCHAR( 10),             
   @cLOC                      NVARCHAR( 10),             
   @cDropID                   NVARCHAR( 20),             
   @cStatus                   NVARCHAR( 1),              
   @cCartonType               NVARCHAR( 10),              
   @nErrNo                    INT           OUTPUT,              
   @cErrMsg                   NVARCHAR( 20) OUTPUT               
)            
AS            
BEGIN            
  SET NOCOUNT ON            
   SET QUOTED_IDENTIFIER OFF            
   SET ANSI_NULLS OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
            
   DECLARE              
      @bsuccess            INT,            
      @cUserName           NVARCHAR( 20),             
      @n_err              INT,            
      @c_errmsg           NVARCHAR( 250),            
      @cPickDetailKey     NVARCHAR( 10),            
      @nPickQty           INT,            
      @nQTY_PD            INT,            
      @nRowRef            INT,            
      @nTranCount         INT,            
      @nPackQty           INT,            
      @nPack2Qty          INT,            
      @nCartonNo          INT,            
      @cLabelNo           NVARCHAR( 20),            
      @cLabelLine         NVARCHAR( 5),            
      @cConsigneeKey      NVARCHAR( 15),            
      @cExternOrderKey    NVARCHAR( 30),            
      @cUOM               NVARCHAR( 10),             
      @cLoadDefaultPickMethod NVARCHAR( 1),             
      @nTotalPickedQty    INT,             
      @nTotalPackedQty    INT,             
      @nPickPackQty       INT,             
      @cRoute             NVARCHAR( 20),             
      @cOrderRefNo        NVARCHAR( 18),             
      @nT_CartonNo        INT,             
      @nLoop              INT,            
      @nDropIDExists      INT,            
      @nGenUCCLabelNo     INT,            
      @fCaseCount         FLOAT,            
      @fCube              FLOAT,             
      @fWeight            FLOAT,        
      @fCtnWeight         FLOAT,               
      @cCaseCount         NVARCHAR( 10),             
      @cCube              NVARCHAR( 10),             
      @cWeight       NVARCHAR( 10),             
      @cT_LabelLine       NVARCHAR( 5),             
      @cDropID_SKU        NVARCHAR( 20),              
      @nTtl_PackQty       INT,             
      @nCaseCount         INT,             
      @nCountSKU          INT,              
      @nSum_DropID        INT,            
      @cSkipUpdCtnType    NVARCHAR( 1) = '',            
      @cAutoPackConfirm   NVARCHAR( 1) = ''

   SELECT @cUserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile            
            
   SELECT @cLoadKey = LoadKey FROM dbo.OrderDetail WITH (NOLOCK)            
   WHERE StorerKey = @cStorerKey            
      AND OrderKey = @cOrderKey            
            
   SELECT @cLoadDefaultPickMethod = LoadPickMethod FROM dbo.LoadPlan WITH (NOLOCK)            
   WHERE LoadKey = @cLoadKey            
            
   IF ISNULL(@cPickSlipNo, '') = ''            
   BEGIN            
      SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK)             
      WHERE OrderKey = @cOrderKey            

      -- New PickSlipNo  
      IF ISNULL(@cPickSlipNo, '') = ''   
      BEGIN  
         EXECUTE nspg_GetKey  
            'PICKSLIP',  
            9,  
            @cPickSlipNo OUTPUT,  
            @bsuccess    OUTPUT,  
            @nErrNo      OUTPUT,  
            @cErrMsg     OUTPUT  
         IF @@ERROR <> 0  
         BEGIN  
            SET @bSuccess = 0
            SET @cErrMsg = 'GET KEY Fail'
            GOTO RollBackTran  
         END  

         SET @cPickSlipNo = 'P' + RTRIM( @cPickSlipNo)  

         INSERT INTO dbo.PICKHEADER    
            (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone)    
         VALUES    
            (@cPickslipno, '', @cOrderKey, '0', 'D')    
       
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 166274  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PrintPKSLP Err'  
            GOTO RollBackTran  
         END    
      END  
   END            

   IF NOT EXISTS ( SELECT 1  
                     FROM dbo.PickingInfo WITH (NOLOCK)  
                     WHERE PickSlipNo = @cPickSlipNo)  
   BEGIN  
      INSERT INTO dbo.PickingInfo  
      (PickSlipNo, ScanInDate, PickerID )  
      Values(@cPickSlipNo, GETDATE(), sUser_sName())  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 166275  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Scan In Fail'  
         GOTO RollBackTran  
      END   
   END
         
   IF rdt.RDTGetConfig( @nFunc, 'ClusterPickCaptureCtnType', @cStorerKey) IN ('', '0')            
      SET @cCartonType = ''            
            
   IF @cCartonType = 'N'            
      SET @cSkipUpdCtnType = '1'            
            
   SET @nGenUCCLabelNo = 0            
   -- If storer config GenUCCLabelNoConfig turned on            
   IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)            
              WHERE StorerKey = @cStorerKey            
              AND   ConfigKey = 'GenUCCLabelNoConfig'            
              AND   SValue = '1')            
      SET @nGenUCCLabelNo = 1            
            
            
   -- If still blank picklipno then look for conso pick               
   IF ISNULL(@cPickSlipNo, '') = ''            
   BEGIN            
      SELECT TOP 1 @cPickSlipNo = PickHeaderKey             
      FROM dbo.PickHeader PIH WITH (NOLOCK)            
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PIH.ExternOrderKey = LPD.LoadKey)            
      JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)            
      WHERE O.OrderKey = @cOrderKey            
         AND O.StorerKey = @cStorerKey            
   END            
            
   SET @nTranCount = @@TRANCOUNT            
   BEGIN TRAN            
   SAVE TRAN Cluster_Pick_ConfirmTask            
            
   SELECT @cUOM = RTRIM(PACK.PACKUOM3),             
          @fCaseCount = PACK.CaseCnt            
   FROM dbo.PACK PACK WITH (NOLOCK)            
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)            
   WHERE SKU.Storerkey = @cStorerKey            
   AND   SKU.SKU = @cSKU            
             
   SET @cCaseCount = rdt.rdtFormatFloat( @fCaseCount)            
   SET @nCaseCount = @cCaseCount            
             
   ------(Rungtham W)------------------------------------------------            
   IF ISNULL( @nCaseCount, 0) <= 0            
   BEGIN            
      SET @nCaseCount = rdt.rdtFormatFloat( @fCaseCount+1 )            
   END             
           
   IF ISNULL( @nCaseCount, 0) <= 0            
   BEGIN            
      SET @nErrNo = 166273            
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Casecnt = 0'            
      GOTO RollBackTran            
   END              
            
   -- Get RDT.RDTPickLock candidate to offset            
   DECLARE curRPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   SELECT RowRef, DropID, PickQty, ID, ISNULL( PackKey, '')            
   FROM RDT.RDTPickLock WITH (NOLOCK)            
   WHERE StorerKey = @cStorerKey            
      AND OrderKey = @cOrderKey            
    AND SKU = @cSKU            
      AND LOT = @cLOT            
      AND LOC = @cLOC            
      AND Status = '1'            
      AND AddWho = @cUserName            
      AND PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN PutAwayZone ELSE @cPutAwayZone END            
      AND PickZone = CASE WHEN ISNULL(@cPickZone  , '') = '' THEN PickZone ELSE @cPickZone END            
   Order By RowRef            
   OPEN curRPL            
   FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo, @cCartonType            
             
   WHILE @@FETCH_STATUS <> -1            
   BEGIN            
      SET @nPackQty = @nPickQty           
          
      ------(Rungtham W)------------------------------------------------            
      IF ISNULL( @nCaseCount, 1) <= 1            
      BEGIN            
         SET @nCaseCount = rdt.rdtFormatFloat( @nPickQty+1 )            
      END             
           
      IF ISNULL( @nCaseCount, 0) < 0            
      BEGIN            
         SET @nErrNo = 166273            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Casecnt = 0'            
         GOTO RollBackTran            
      END            
         
      IF @cSkipUpdCtnType = '1'            
         SET @cCartonType = ''            
            
      -- Get PickDetail candidate to offset based on RPL's candidate            
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
      SELECT PickDetailKey, QTY            
      FROM dbo.PickDetail WITH (NOLOCK)            
      WHERE OrderKey  = @cOrderKey            
         AND StorerKey  = @cStorerKey            
         AND SKU = @cSKU            
         AND LOT = @cLOT            
         AND LOC = @cLOC            
         AND Status = '0'            
      ORDER BY PickDetailKey            
      OPEN curPD            
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD            
             
      WHILE @@FETCH_STATUS <> -1            
      BEGIN            
         SET @nPickPackQty = @nQTY_PD -- (ChewKP02)               
          
         IF @nPickQty = 0            
         BEGIN            
            -- Confirm PickDetail            
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET            
               DropID = CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4' THEN '' ELSE @cDropID END,            
               CartonType = @cCartonType,             
               Status = @cStatus            
            WHERE PickDetailKey = @cPickDetailKey            
            
            IF @@ERROR <> 0            
            BEGIN            
               SET @nErrNo = 166251            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'            
               GOTO RollBackTran            
            END            
            ELSE            
            BEGIN            
             -- (Vicky06) EventLog - QTY            
               EXEC RDT.rdt_STD_EventLog            
                 @cActionType   = '3', -- Picking            
                 @cUserID       = @cUserName,            
                 @nMobileNo     = @nMobile,            
                 @nFunctionID   = @nFunc,            
                 @cFacility     = @cFacility,            
                 @cStorerKey    = @cStorerkey,            
                 @cLocation     = @cLOC,            
                 @cID           = @cDropID,         
                 @cSKU          = @cSKU,            
                 @cUOM          = @cUOM,            
                 @nQTY          = @nPickQty,            
                 @cLot          = @cLOT,            
                 @cRefNo1       = @cPutAwayZone,            
                 @cRefNo2       = @cPickZone,            
                 @cRefNo3       = @cOrderKey,            
                 @cRefNo4       = @cPickSlipNo            
            END            
         END            
         ELSE             
         -- Exact match            
         IF @nQTY_PD = @nPickQty            
         BEGIN            
            -- Confirm PickDetail            
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET            
               DropID = CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4' THEN '' ELSE @cDropID END,            
               CartonType = @cCartonType,             
               Status = @cStatus            
            WHERE PickDetailKey = @cPickDetailKey            
            
            IF @@ERROR <> 0            
            BEGIN            
               SET @nErrNo = 166252            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'            
               GOTO RollBackTran            
            END            
            ELSE            
            BEGIN            
               -- (Vicky06) EventLog - QTY            
               EXEC RDT.rdt_STD_EventLog            
                 @cActionType   = '3', -- Picking            
                 @cUserID       = @cUserName,            
                 @nMobileNo     = @nMobile,            
                 @nFunctionID   = @nFunc,            
                 @cFacility     = @cFacility,            
                 @cStorerKey    = @cStorerkey,            
                 @cLocation     = @cLOC,            
                 @cID           = @cDropID,            
                 @cSKU          = @cSKU,            
                 @cUOM          = @cUOM,            
                 @nQTY          = @nPickQty,            
                 @cLot          = @cLOT,            
                 @cRefNo1       = @cPutAwayZone,            
                 @cRefNo2       = @cPickZone,            
                 @cRefNo3       = @cOrderKey,            
                 @cRefNo4       = @cPickSlipNo            
            END            
             
            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance -- SOS# 176144            
         END            
         -- PickDetail have less            
         ELSE IF @nQTY_PD < @nPickQty            
         BEGIN            
            -- Confirm PickDetail            
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET            
               DropID = CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4' THEN '' ELSE @cDropID END,            
               CartonType = @cCartonType,                            
               Status = '5'            
            WHERE PickDetailKey = @cPickDetailKey            
            
            IF @@ERROR <> 0            
            BEGIN            
               SET @nErrNo = 166253            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'            
               GOTO RollBackTran            
            END            
            ELSE            
            BEGIN            
               EXEC RDT.rdt_STD_EventLog            
                 @cActionType   = '3', -- Picking            
                 @cUserID       = @cUserName,            
                 @nMobileNo     = @nMobile,            
                 @nFunctionID   = @nFunc,            
                 @cFacility     = @cFacility,            
                 @cStorerKey    = @cStorerkey,            
                 @cLocation     = @cLOC,            
                 @cID           = @cDropID,            
                 @cSKU          = @cSKU,            
                 @cUOM          = @cUOM,            
                 @nQTY          = @nPickQty,            
                 @cLot          = @cLOT,          
                 @cRefNo1       = @cPutAwayZone,            
                 @cRefNo2       = @cPickZone,            
                 @cRefNo3       = @cOrderKey,            
                 @cRefNo4       = @cPickSlipNo            
            END            
            
            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance            
         END            
         -- PickDetail have more, need to split            
         ELSE IF @nQTY_PD > @nPickQty            
         BEGIN            
            IF @nPickQty > 0 -- SOS# 176144            
            BEGIN            
               -- If Status = '5' (full pick), split line if neccessary            
               -- If Status = '4' (short pick), no need to split line if already last RPL line to update,            
               -- just have to update the pickdetail.qty = short pick qty            
               -- Get new PickDetailkey            
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
                  SET @nErrNo = 166254            
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
                  CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' THEN '4' ELSE '0' END,            
                  --'0',            
                  DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,            
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,            
                  @nQTY_PD - @nPickQty, -- QTY            
                  NULL, --TrafficCop,            
                  '1'  --OptimizeCop            
               FROM dbo.PickDetail WITH (NOLOCK)            
               WHERE PickDetailKey = @cPickDetailKey            
            
               IF @@ERROR <> 0            
               BEGIN            
                  SET @nErrNo = 166255            
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'            
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
                  SET @nErrNo = 166256            
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'            
                  GOTO RollBackTran            
               END            
            
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET            
                  DropID = @cDropID,            
                  CartonType = @cCartonType,                               
                  Status = '5'            
               WHERE PickDetailKey = @cPickDetailKey            
            
               IF @@ERROR <> 0            
               BEGIN            
                  SET @nErrNo = 166257            
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'            
                  GOTO RollBackTran            
               END            
               ELSE            
               BEGIN            
                  EXEC RDT.rdt_STD_EventLog            
                    @cActionType   = '3', -- Picking            
                    @cUserID       = @cUserName,            
                    @nMobileNo     = @nMobile,            
                    @nFunctionID   = @nFunc,            
                    @cFacility     = @cFacility,            
                    @cStorerKey    = @cStorerkey,            
                    @cLocation     = @cLOC,            
                    @cID           = @cDropID,            
                    @cSKU          = @cSKU,            
                    @cUOM          = @cUOM,            
                    @nQTY          = @nPickQty,            
                    @cLot          = @cLOT,            
                    @cRefNo1       = @cPutAwayZone,            
                    @cRefNo2       = @cPickZone,            
                    @cRefNo3       = @cOrderKey,            
                    @cRefNo4       = @cPickSlipNo            
               END            
            
               SET @nPickPackQty = @nPickQty             
               SET @nPickQty = 0 -- Reduce balance            
            END            
         END            
            
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)             
                        WHERE DropID = @cDropID) OR             
            -- If dropid not exists then need create new dropid.              
            -- If exists dropid then check if allow reuse dropid. If allow then go on.            
            rdt.RDTGetConfig( @nFunc, 'ClusterPickAllowReuseDropID', @cStorerKey) = '1'            
         BEGIN            
            -- Insert into DropID table   (james08)            
            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtOpenDropID', @cStorerKey) = '1'             
            BEGIN            
               SET @nErrNo = 0              
               EXECUTE rdt.rdt_Cluster_Pick_DropID              
                  @nMobile,             
                  @nFunc,                
                  @cStorerKey,              
                  @cUserName,              
                  @cFacility,              
                  @cLoadKey,            
                  @cPickSlipNo,              
                  @cOrderKey,             
                  @cDropID       OUTPUT,              
                  @cSKU,              
                  'I',      -- I = Insert            
                  @cLangCode,              
                  @nErrNo        OUTPUT,              
                  @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max              
              
              IF @nErrNo <> 0              
                  GOTO RollBackTran            
            END            
         END            
            
         IF @nPickQty = 0             
         BEGIN            
            BREAK             
         END            
            
         FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD            
      END            
      CLOSE curPD            
      DEALLOCATE curPD            
/*            
      -- Get total qty that need to be packed            
      SELECT @nPackQty =  ISNULL(SUM(PickQty), 0)            
      FROM RDT.RDTPickLock WITH (NOLOCK)            
      WHERE StorerKey = @cStorerKey            
         AND OrderKey = @cOrderKey            
         AND SKU = @cSKU            
         AND LOT = @cLOT            
         AND LOC = @cLOC            
         AND Status = '1'            
         AND AddWho = @cUserName            
         AND DropID = @cDropID -- (ChewKP01)            
         AND PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN PutAwayZone ELSE @cPutAwayZone END            
    AND PickZone = CASE WHEN ISNULL(@cPickZone  , '') = '' THEN PickZone ELSE @cPickZone END            
*/            
          
      IF rdt.RDTGetConfig( @nFunc, 'ClusterPickInsPackDt', @cStorerKey) = '1' AND @nPackQty > 0            
      BEGIN            
         --SET @nPackQty = @nPickPackQty             
            
         IF @cLoadDefaultPickMethod = 'C'             
         BEGIN            
            -- Prevent overpacked             
            SET @nTotalPickedQty = 0             
            SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY), 0)             
            FROM dbo.PickDetail PD WITH (NOLOCK)            
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)            
            JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey            
            WHERE PD.StorerKey = @cStorerKey            
               AND O.LoadKey = @cLoadKey            
               AND PD.SKU = @cSKU            
               AND PD.Status = '5'             
            
            SET @nTotalPackedQty = 0             
            SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK)            
            WHERE StorerKey = @cStorerKey            
               AND PickSlipNo = @cPickSlipNo            
               AND SKU = @cSKU            
         END            
         ELSE            
         BEGIN            
            -- Prevent overpacked             
            SET @nTotalPickedQty = 0             
            SELECT @nTotalPickedQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)            
            WHERE StorerKey = @cStorerKey            
               AND OrderKey = @cOrderKey            
               AND SKU = @cSKU            
               AND Status = '5'             
            
            SET @nTotalPackedQty = 0             
            SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK)            
            WHERE StorerKey = @cStorerKey            
               AND PickSlipNo = @cPickSlipNo            
               AND SKU = @cSKU         
         END            
             
         IF (@nTotalPackedQty + @nPackQty) > @nTotalPickedQty -- (ChewKP02)            
         BEGIN            
            SET @nErrNo = 166258            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Overpacked'            
            --SET @cErrMsg = CAST( @nTotalPackedQty AS NVARCHAR( 3)) + '|' + CAST( @nPackQty AS NVARCHAR( 3)) + '|' + CAST( @nTotalPickedQty AS NVARCHAR( 3)) + '|' + @cSKU            
            GOTO RollBackTran            
         END            
            
         IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)            
         BEGIN            
            SELECT @cRoute = [Route],             
                     @cOrderRefNo = SUBSTRING(ExternOrderKey, 1, 18),             
                     @cConsigneekey = ConsigneeKey             
            FROM dbo.Orders WITH (NOLOCK)             
            WHERE OrderKey = @cOrderKey            
            AND   StorerKey = @cStorerKey            
            
            INSERT INTO dbo.PackHeader            
            (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)            
            VALUES            
            (@cRoute, @cOrderKey, @cOrderRefNo, @cLoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo)            
            
            IF @@ERROR <> 0            
            BEGIN            
               SET @nErrNo = 166259            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'            
               GOTO RollBackTran            
            END             
         END            
            
         IF @nPackQty < @nCaseCount            
         BEGIN            
            IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)             
                        WHERE StorerKey = @cStorerKey            
                        AND   PickSlipNo = @cPickSlipNo            
                        AND   DropID = @cDropID            
                        AND   SKU = @cSKU)            
            BEGIN            
               SELECT TOP 1             
                  @nCartonNo = CartonNo,             
                  @cLabelNo = LabelNo,            
                  @cLabelLine = LabelLine             
               FROM dbo.PackDetail WITH (NOLOCK)             
               WHERE StorerKey = @cStorerKey            
               AND   PickSlipNo = @cPickSlipNo            
               AND   DropID = @cDropID            
               AND   SKU = @cSKU            
            
               SET @nPack2Qty = @nPackQty            
               SET @nPackQty = 0            
            
               UPDATE dbo.PackDetail WITH (ROWLOCK) SET            
                  QTY = QTY + @nPack2Qty            
               WHERE PickSlipNo = @cPickSlipNo            
               AND   CartonNo = @nCartonNo            
               AND   LabelNo = @cLabelNo            
               AND   LabelLine = @cLabelLine            
            
               IF @@ERROR <> 0            
               BEGIN            
                  SET @nErrNo = 166260            
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'            
                  GOTO RollBackTran            
               END             
            
               IF @cCartonType <> ''            
               BEGIN            
                  SELECT @fCube = [Cube],             
                         @fCtnWeight = CartonWeight             
                  FROM dbo.Cartonization CZ WITH (NOLOCK)            
                  JOIN Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup            
                  WHERE StorerKey = @cStorerKey            
                  AND   CartonType = @cCartonType             
            
                  SELECT @fWeight = STDGrossWGT             
                  FROM dbo.SKU WITH (NOLOCK)            
                  WHERE StorerKey = @cStorerKey            
                  AND   SKU = @cSKU            
            
                  SET @cCube = rdt.rdtFormatFloat( @fCube)            
            
                  --SET @cWeight = ( @nPack2Qty * @fWeight) + @fCtnWeight            
                  --SET @cWeight = rdt.rdtFormatFloat( @cWeight)            
                  SET @cWeight = @nPack2Qty * @fWeight            
            
                  IF EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)       
                              WHERE PickSlipNo = @cPickSlipNo            
                              AND   CartonNo = @nCartonNo)                              
                  BEGIN            
                     UPDATE dbo.PackInfo WITH (ROWLOCK) SET            
                        CartonType = CASE WHEN ISNULL( CartonType, '') = '' THEN @cCartonType ELSE CartonType END,            
                        [Cube] = CASE WHEN [Cube] IS NULL THEN @cCube ELSE [Cube] END,            
                        --Weight = Weight + (@nPack2Qty * @fWeight), (james01)              
                        Weight = Weight + rdt.rdtFormatFloat( @cWeight),                        
                        EditDate = GETDATE(),            
                        EditWho = 'rdt.' + sUser_sName()            
                     WHERE PickSlipNo = @cPickSliPno            
                     AND CartonNo = @nCartonNo            
                                 
                     IF @@ERROR <> 0            
                     BEGIN            
                        SET @nErrNo = 166265            
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackInfoFail'            
                        GOTO RollBackTran            
                     END                              
                  END            
                  ELSE            
                  BEGIN            
                     SET @cWeight = @cWeight + @fCtnWeight              
                     SET @cWeight = rdt.rdtFormatFloat( @cWeight)              
                                 
                     INSERT INTO dbo.PACKINFO            
                     (PickSlipNo, CartonNo, CartonType, [Cube], Weight)            
                     VALUES            
                     (@cPickSlipNo, @nCartonNo, @cCartonType, @cCube, @cWeight)            
            
                     IF @@ERROR <> 0            
                     BEGIN            
                        SET @nErrNo = 166266            
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackInfoFail'            
                        GOTO RollBackTran            
                     END                              
                  END            
               END            
            END              
            ELSE            
            BEGIN            
               SELECT @nCountSKU = COUNT( DISTINCT SKU)             
               FROM dbo.PackDetail WITH (NOLOCK)             
               WHERE StorerKey = @cStorerKey            
               AND   PickSlipNo = @cPickSlipNo            
               AND   DropID = @cDropID            
            
               IF @nCountSKU = 1            
               BEGIN            
                  SELECT @cDropID_SKU = SKU,             
                         @nSum_DropID = ISNULL( SUM( QTY), 0)            
                  FROM dbo.PackDetail WITH (NOLOCK)             
                  WHERE StorerKey = @cStorerKey            
                  AND   PickSlipNo = @cPickSlipNo            
                  AND   DropID = @cDropID            
                  GROUP BY SKU            
            
                  SELECT @fCaseCount = PACK.CaseCnt            
                  FROM dbo.PACK PACK WITH (NOLOCK)            
                  JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)            
                  WHERE SKU.Storerkey = @cStorerKey            
                  AND   SKU.SKU = @cDropID_SKU            
      ------------------(RungthamW)---------------------------------------------            
                   --Current dropid already is a full carton, cannot use same dropid            
                  IF @nSum_DropID / @fCaseCount = 1            
                  BEGIN            
                     SET @nErrNo = 166269            
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropID In Use'            
                     GOTO RollBackTran            
                  END             
      ----------------------------------------------------------------------------            
               END            
            END            
         END   -- @nPackQty < @nCaseCount            
         ELSE            
         IF @nPackQty = @nCaseCount            
         BEGIN            
            IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)             
                        WHERE StorerKey = @cStorerKey            
                        AND   PickSlipNo = @cPickSlipNo            
                     AND   DropID = @cDropID)            
            BEGIN            
               SET @nErrNo = 166261            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropidInUse'            
               GOTO RollBackTran            
            END                                
         END   -- @nPackQty = @nCaseCount            
         ELSE            
         IF @nPackQty > @nCaseCount            
         BEGIN            
            IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)             
                        WHERE StorerKey = @cStorerKey            
                        AND   PickSlipNo = @cPickSlipNo            
                        AND   DropID = @cDropID)            
            BEGIN            
               SET @nErrNo = 166262            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropidInUse'            
               GOTO RollBackTran            
            END                                            
         END   -- @nPackQty > @nCaseCount            
             
         WHILE @nPackQty > 0            
         BEGIN                    
            --Ins packdetail            
            SET @nCartonNo = 0            
            SET @cLabelNo = ''            
            SET @bsuccess = 1            
            SET @nErrNo = 0            
            
            IF @nPackQty < @nCaseCount            
            BEGIN            
               SELECT TOP 1             
                  @nCartonNo = CartonNo,             
                  @cLabelNo = LabelNo,            
                  @cLabelLine = LabelLine             
               FROM dbo.PackDetail WITH (NOLOCK)             
               WHERE StorerKey = @cStorerKey            
               AND   PickSlipNo = @cPickSlipNo            
               AND   DropID = @cDropID            
            
               IF @nCartonNo > 0            
                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)                
                  FROM PACKDETAIL WITH (NOLOCK)                
                  WHERE StorerKey = @cStorerKey            
                  AND   PickSlipNo = @cPickSlipNo            
                  AND   DropID = @cDropID            
               ELSE            
               BEGIN            
                  IF @nGenUCCLabelNo = 1            
                  BEGIN            
                     EXEC RDT.rdt_GenUCCLabelNo            
                        @cStorerKey = @cStorerKey,            
                        @nMobile    = @nMobile,            
                        @cLabelNo   = @cLabelNo    OUTPUT,            
                        @cLangCode  = @cLangCode,            
                        @nErrNo     = @nErrNo      OUTPUT,            
                        @cErrMsg    = @cErrMsg     OUTPUT             
            
                     IF @nErrNo <> 0            
                        SET @bsuccess = -1            
                  END            
                  ELSE IF rdt.RDTGetConfig( @nFunc, 'PickAndPackUseDropIDAsLblNo', @cStorerKey) = '1' -- ZG01              
                  BEGIN              
                     SET @cLabelNo = @cDropID              
                  END              
                  ELSE              
                  BEGIN            
                     EXECUTE dbo.nsp_GenLabelNo            
                        '',            
                        @cStorerKey,            
                        @c_labelno     = @cLabelNo  OUTPUT,            
                        @n_cartonno    = @nCartonNo OUTPUT,            
                        @c_button      = '',            
                        @b_success     = @bsuccess  OUTPUT,            
                        @n_err         = @nErrNo    OUTPUT,            
                        @c_errmsg      = @cErrMsg   OUTPUT            
                  END             
               END                           
            END            
            ELSE            
            BEGIN            
               IF @nGenUCCLabelNo = 1            
               BEGIN            
                  EXEC RDT.rdt_GenUCCLabelNo            
                     @cStorerKey = @cStorerKey,            
                     @nMobile    = @nMobile,            
                     @cLabelNo   = @cLabelNo    OUTPUT,            
                     @cLangCode  = @cLangCode,            
                     @nErrNo     = @nErrNo      OUTPUT,            
                     @cErrMsg    = @cErrMsg     OUTPUT             
            
                  IF @nErrNo <> 0            
                     SET @bsuccess = -1                   END            
               ELSE IF rdt.RDTGetConfig( @nFunc, 'PickAndPackUseDropIDAsLblNo', @cStorerKey) = '1' -- ZG01              
               BEGIN              
                  SET @cLabelNo = @cDropID              
               END              
               ELSE              
               BEGIN            
                  EXECUTE dbo.nsp_GenLabelNo            
                     '',            
                     @cStorerKey,            
                     @c_labelno     = @cLabelNo  OUTPUT,            
                     @n_cartonno    = @nCartonNo OUTPUT,            
                     @c_button      = '',            
                     @b_success     = @bsuccess  OUTPUT,            
                     @n_err         = @nErrNo    OUTPUT,            
                     @c_errmsg      = @cErrMsg   OUTPUT            
               END            
            END            
            
            IF @bsuccess <> 1            
            BEGIN            
               SET @nErrNo = 166263            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'            
               GOTO RollBackTran            
            END            
            
            IF @nCaseCount > @nPackQty            
            BEGIN            
               SET @nPack2Qty = @nPackQty            
               SET @nPackQty = 0            
            END            
            ELSE            
            BEGIN            
               SET @nPack2Qty = @nCaseCount            
               SET @nPackQty = @nPackQty - @nPack2Qty            
            END            
            --#rungtham insert             
            INSERT INTO dbo.PackDetail            
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)            
            VALUES            
               (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nPack2Qty,            
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)            
            
            IF @@ERROR <> 0            
            BEGIN            
               SET @nErrNo = 166264            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'            
               GOTO RollBackTran            
            END                                  
            
            IF @cCartonType <> ''            
            BEGIN            
               SELECT TOP 1 @nCartonNo = CartonNo, @nTtl_PackQty = ISNULL( SUM( Qty), 0)            
               FROM dbo.PackDetail WITH (NOLOCK)             
               WHERE PickSlipNo = @cPickSlipNo            
               AND   LabelNo = @cLabelNo            
               AND   StorerKey = @cStorerKey            
               GROUP BY CartonNo            
                              
               SELECT @fCube = [Cube],             
                      @fCtnWeight = CartonWeight             
               FROM dbo.Cartonization CZ WITH (NOLOCK)            
               JOIN Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup            
               WHERE StorerKey = @cStorerKey            
               AND   CartonType = @cCartonType             
            
               SELECT @fWeight = STDGrossWGT             
               FROM dbo.SKU WITH (NOLOCK)            
               WHERE StorerKey = @cStorerKey            
               AND   SKU = @cSKU            
            
               SET @cCube = rdt.rdtFormatFloat( @fCube)            
            
               --SET @cWeight = ( @nTtl_PackQty * @fWeight) + @fCtnWeight            
               --SET @cWeight = rdt.rdtFormatFloat( @cWeight)            
               SET @cWeight = @nPack2Qty * @fWeight              
                              
               IF EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)             
                           WHERE PickSlipNo = @cPickSlipNo            
                           AND   CartonNo = @nCartonNo)                              
               BEGIN            
                  UPDATE dbo.PackInfo WITH (ROWLOCK) SET            
                     CartonType = CASE WHEN ISNULL( CartonType, '') = '' THEN @cCartonType ELSE CartonType END,            
                     [Cube] = CASE WHEN [Cube] IS NULL THEN @cCube ELSE [Cube] END,            
                     --Weight = Weight + (@nTtl_PackQty * @fWeight), (james01)              
                     Weight = Weight + rdt.rdtFormatFloat( @cWeight),              
                     EditDate = GETDATE(),            
                     EditWho = 'rdt.' + sUser_sName()            
                  WHERE PickSlipNo = @cPickSliPno            
                  AND CartonNo = @nCartonNo            
                              
                  IF @@ERROR <> 0            
                  BEGIN            
                     SET @nErrNo = 166267            
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackInfoFail'            
                     GOTO RollBackTran            
                  END                              
               END            
               ELSE            
               BEGIN            
                  SET @cWeight = @cWeight + @fCtnWeight              
                  SET @cWeight = rdt.rdtFormatFloat( @cWeight)              
                              
                  INSERT INTO dbo.PACKINFO            
                  (PickSlipNo, CartonNo, CartonType, [Cube], Weight)            
                  VALUES            
                  (@cPickSlipNo, @nCartonNo, @cCartonType, @cCube, @cWeight)            
            
                  IF @@ERROR <> 0            
                  BEGIN            
                     SET @nErrNo = 166268            
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackInfoFail'            
                     GOTO RollBackTran            
                  END                              
               END                      
            END   -- @cCartonType <> ''                       
         END   -- While @nPackQty > 0            
      END            
            
      -- Stamp RPL's candidate to '5'            
      UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET            
         Status = '5'   -- Picked            
      WHERE RowRef = @nRowRef            
            
      IF @@ERROR <> 0            
      BEGIN            
         SET @nErrNo = 166266            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'            
         GOTO RollBackTran            
      END            
            
      FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo, @cCartonType            
   END            
   CLOSE curRPL            
   DEALLOCATE curRPL            
   
   SET @nPickQty = 0
   SET @nPackQty = 0
   SELECT @nPickQty = ISNULL( SUM( Qty), 0)
   FROM dbo.PickDetail WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   AND   [Status] <> '4'
   
   SELECT @nPackQty = SUM( Qty)
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
   
   IF @nPickQty = @nPackQty
   BEGIN
      SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)  
      
      IF @cAutoPackConfirm = '1'
      BEGIN
      	IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) 
      	            WHERE PickSlipNo = @cPickSlipNo 
      	            AND  [Status] < '9')
         BEGIN
            UPDATE dbo.PackHeader SET  
               STATUS = '9'  
            WHERE PickSlipNo = @cPickSlipNo  

            IF @@ERROR <> 0
            BEGIN        
               SET @nErrNo = 166276        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ConfPackFail    
               GOTO RollBackTran  
            END
         END 
      END
   END
   
   GOTO Quit            
            
   RollBackTran:            
      ROLLBACK TRAN Cluster_Pick_ConfirmTask            
            
   Quit:            
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
         COMMIT TRAN Cluster_Pick_ConfirmTask            
            
END 

GO
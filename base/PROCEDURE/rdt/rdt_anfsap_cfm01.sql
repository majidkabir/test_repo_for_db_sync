SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_ANFSAP_Cfm01                                    */  
/* Copyright: LFL                                                       */  
/* Purpose: ANF Sort And Pack Confirm                                   */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Ver  Author   Purposes                                   */  
/* 2014-04-01  1.0  Chee     SOS#307177 Created                         */  
/* 2014-05-21  1.1  Chee     Update UCC to status 6 to loose it (Chee01)*/  
/* 2014-05-27  1.2  Chee     Removed DropID and DropIDDetail Insert     */
/*                           Add checking to validate if current        */
/*                           labelno has been closed                    */
/*                           Logic change to cater scanning UCC & SKU   */
/*                           in random sequence  (Chee02)               */
/* 2014-06-16  1.3  Chee     Add rdt.StorerConfig -                     */
/*                           GenLabelByUserForDCToStoreOdr (Chee03)     */
/* 2014-09-23  1.4  Chee     Bug fix multi SKU UCC.Status update -      */
/*                           loose UCC after looping done (Chee04)      */
/* 2015-04-27  1.5  Leong    SOS# 340315 - Add TraceInfo.               */ 
/* 2021-04-19  1.5  Chermain WMS-16851 Add Channel_ID when split        */
/*                           pickDetail (cc01)                          */
/* 2022-06-07  1.6  yeekung  WMS-19703 Add eventlog (yeekung01)         */
/************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_ANFSAP_Cfm01]  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR(3),  
   @cPackByType   NVARCHAR(10),   
   @cLoadKey      NVARCHAR(10),  
   @cOrderKey     NVARCHAR(10),   
   @cConsigneeKey NVARCHAR(15),  
   @cStorerKey    NVARCHAR(15),  
   @cSKU          NVARCHAR(20),  
   @nQTY          INT,   
   @cLabelNo      NVARCHAR(20),  
   @cCartonType   NVARCHAR(10),
   @bSuccess      INT            OUTPUT,
   @nErrNo        INT            OUTPUT,  
   @cErrMsg       NVARCHAR(20)   OUTPUT,   
   @cUCCNo        NVARCHAR(20) = ''

AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
      @cPickDetailKey    NVARCHAR(10),
      @cNewPickDetailKey NVARCHAR(10), 
      @cPickSlipNo       NVARCHAR(10),
      @cFacility         NVARCHAR(5), 
      @nQTY_PD           INT,
      @nPickQty          INT, 
      @nCountOrderKey    INT,
      @nCartonNo         INT,   
      @cLabelLine        NVARCHAR(5),
      @nTotalPickedQty   INT,     
      @nTotalPackedQty   INT,
      @nContinueLoop     INT,
      @cDropID           NVARCHAR(20), -- (Chee01)
      @cUserName         NVARCHAR(18), -- (Chee02)
      @cOrderType        NVARCHAR(20), -- (Chee02)
      @cCaseID           NVARCHAR(20), -- (Chee02)
      @c_ConsigneeKey    NVARCHAR(15), -- (Chee02)  
      @c_SKU             NVARCHAR(20), -- (Chee02)  
      @n_QTY             INT,          -- (Chee02) 
      @cGenLabelByUserForDCToStoreOdr NVARCHAR(20),   -- (Chee03)
      @nStep             INT

   DECLARE @cuserid NVARCHAR(20) -- SOS# 340315  
   SET @cuserid = SUSER_SNAME()  
   
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_ANFSAP_Cfm01  

   SET @nErrNo = 0  
   SET @cErrMsg = ''

   -- Get UserName (Chee02)
   SELECT @cUserName = UserName,
          @nStep = step
   FROM rdt.RDTMOBREC WITH (NOLOCK)    
   WHERE Mobile = @nMobile 

   -- Get OrderType (Chee02)
   SELECT @cOrderType = O.[Type]
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)
   JOIN ORDERS O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
     AND O.OrderKey = @cOrderKey 

   -- Get GenLabelByUserForDCToStoreOdr rdt.StorerConfig (Chee03)
   SELECT @cGenLabelByUserForDCToStoreOdr = rdt.RDTGetConfig( @nFunc, 'GenLabelByUserForDCToStoreOdr', @cStorerKey) 

   -- Get PickSlipNo (PickHeader)  
   SET @cPickSlipNo = ''  
   SELECT @cPickSlipNo = PickHeaderKey     
   FROM dbo.PickHeader WITH (NOLOCK)    
   WHERE LoadKey = @cLoadKey  

   IF ISNULL(@cPickSlipNo, '') = ''
   BEGIN    
      SET @nErrNo = 86601 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoPickSlipNo
      GOTO RollBackTran   
   END   

   IF ISNULL(@cUCCNo, '') <> '' AND 
      NOT EXISTS (SELECT 1 FROM UCC (NOLOCK) WHERE UCCNo = @cUCCNo AND StorerKey = @cStorerKey AND Status IN ('3', '6'))
   BEGIN
      SET @nErrNo = 86614
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvUCCNo
      GOTO RollBackTran  
   END

   -- Validate if current labelno has been closed (Chee02)
   IF EXISTS ( SELECT 1 FROM dbo.DropID D WITH (NOLOCK)
               JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON (D.DropID = DD.DropID)
               WHERE D.PickSlipNo = @cPickSlipNo
                 AND D.DropID = @cLabelNo
                 AND D.DropIDType = '0' 
                 AND D.DropLoc = ''
                 AND D.LabelPrinted = 'Y'
                 AND D.Status = '9'
                 AND DD.UserDefine01 = @cConsigneeKey
                 AND DD.UserDefine02 = CASE WHEN @cOrderType = 'DCToDC' 
                                                 OR (@cOrderType = 'N' AND @cGenLabelByUserForDCToStoreOdr = '1') -- (Chee03)
                                            THEN @cUserName ELSE DD.UserDefine02 END)

   BEGIN    
      SET @nErrNo = 86620 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LabelNoClosed
      GOTO RollBackTran   
   END   

   /***************************************************/    
   /* Insert PackHeader                               */    
   /***************************************************/    
   IF NOT EXISTS(SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK) WHERE PickSlipNo = ISNULL(RTRIM(@cPickSlipNo),''))    
   BEGIN    
      INSERT INTO dbo.PACKHEADER    
      (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, ConsoOrderKey, [STATUS])     
      VALUES    
      (@cPickSlipNo, @cStorerKey, '', @cLoadKey, '', '', '', 0, 'SaP', '0') -- SOS# 340315  
          
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 86602    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHFail'    
         GOTO RollBackTran             
      END               
   END 

   -- Stamp occupied caseID of UCC to other PickDetail record of same criteria (Chee02)  
   IF ISNULL(@cUCCNo, '') <> '' AND 
      EXISTS( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)     
              JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
              JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (OD.OrderKey = LPD.OrderKey)
              WHERE PD.PickslipNo   = @cPickSlipNo   
              AND   LPD.LoadKey     = @cLoadKey    
              AND   PD.StorerKey    = @cStorerKey    
              AND   PD.DropID       = @cUCCNo 
              AND   PD.Status       IN ('3', '5')    
              AND   ISNULL(PD.CaseID, '') <> '' )
   BEGIN
      DECLARE CURSOR_RESTAMP_PICKDETAIL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PD.CaseID, OD.Userdefine02, PD.SKU, SUM(PD.Qty)
      FROM dbo.PickDetail PD WITH (NOLOCK)     
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (OD.OrderKey = LPD.OrderKey)  
      WHERE PD.PickslipNo   = @cPickSlipNo      
      AND   LPD.LoadKey     = @cLoadKey 
      AND   PD.StorerKey    = @cStorerKey    
      AND   PD.DropID       = @cUCCNo 
      AND   PD.Status       IN ('3', '5')    
      AND   ISNULL(PD.CaseID, '') <> ''
      GROUP BY PD.CaseID, OD.Userdefine02, PD.SKU

      OPEN CURSOR_RESTAMP_PICKDETAIL
      FETCH NEXT FROM CURSOR_RESTAMP_PICKDETAIL INTO @cCaseID, @c_ConsigneeKey, @c_SKU, @n_Qty

      WHILE @@FETCH_STATUS <> -1         
      BEGIN 
         SET @nPickQty = @n_Qty

--         INSERT INTO Traceinfo (Tracename, timein, col1, col2, col3, col4)
--         VALUES ('SortAndPackConfirm_ANF', GETDATE(), @cCaseID, @c_ConsigneeKey, @c_SKU, @n_Qty)

         DECLARE CURSOR_RESTAMP_PICKDETAIL_INNER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                    
         SELECT PD.PickDetailKey, PD.Qty
         FROM dbo.PickDetail PD WITH (NOLOCK)  
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)  
         WHERE PD.PickslipNo   = @cPickSlipNo    
         AND   LPD.LoadKey     = @cLoadKey    
         AND   PD.StorerKey    = @cStorerKey    
         AND   PD.SKU          = @c_SKU    
         AND   OD.Userdefine02 = @c_ConsigneeKey 
         AND   PD.Status       IN ('3', '5')    
         AND   ISNULL(PD.CaseID, '') = ''  
         ORDER BY PD.UOM DESC  

         OPEN  CURSOR_RESTAMP_PICKDETAIL_INNER    
         FETCH NEXT FROM CURSOR_RESTAMP_PICKDETAIL_INNER INTO @cPickDetailKey, @nQTY_PD
              
         WHILE @@FETCH_STATUS <> -1         
         BEGIN     
            -- Exact match  
            IF @nQTY_PD = @nPickQty  
            BEGIN  
               -- Confirm PickDetail  
               UPDATE dbo.PickDetail WITH (ROWLOCK) 
               SET CaseID = @cCaseID, Status = '5'
               WHERE PickDetailKey = @cPickDetailKey  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 86622  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDetFail  
                  GOTO RollBackTran  
               END  

               SET @nPickQty = 0 -- Reduce balance 
               BREAK  
            END   
            -- PickDetail have less  
            ELSE IF @nQTY_PD < @nPickQty  
            BEGIN  
               -- Confirm PickDetail  
               UPDATE dbo.PickDetail WITH (ROWLOCK)  
               SET CaseID = @cCaseID, Status = '5'
               WHERE PickDetailKey = @cPickDetailKey  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 86623  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDetFail 
                  GOTO RollBackTran  
               END  
       
               SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance  
            END  
        
            -- PickDetail have more, need to split  
            ELSE IF @nQTY_PD > @nPickQty  
            BEGIN  
               -- Get new PickDetailkey  
               SET  @cNewPickDetailKey = ''
               EXECUTE dbo.nspg_GetKey  
                  'PICKDETAILKEY',  
                  10 ,  
                  @cNewPickDetailKey OUTPUT,  
                  @bSuccess          OUTPUT,  
                  @nErrNo            OUTPUT,  
                  @cErrMsg           OUTPUT  

               IF @bSuccess <> 1  
               BEGIN  
                  SET @nErrNo = 86624  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
                  GOTO RollBackTran  
               END  
        
               -- Create a new PickDetail to hold the balance  
               INSERT INTO dbo.PICKDETAIL (  
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,  
                  Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,  
                  QTY,  
                  TrafficCop,  
                  OptimizeCop,
                  Channel_ID )--(cc01)
               SELECT  
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,  
                  Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,  
                  @nQTY_PD - @nPickQty, -- QTY  
                  NULL, --TrafficCop,  
                  '1',  --OptimizeCop  
                  Channel_ID --(cc01)
               FROM dbo.PickDetail WITH (NOLOCK)  
               WHERE PickDetailKey = @cPickDetailKey  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 86625 
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPickDetFail  
                  GOTO RollBackTran  
               END  
        
               -- Change orginal PickDetail with exact QTY (with TrafficCop)  
               UPDATE dbo.PickDetail WITH (ROWLOCK) 
               SET QTY = @nPickQty, TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 86626  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDetFail
                  GOTO RollBackTran  
               END  

               -- Update status (without TrafficCop)  
               UPDATE dbo.PickDetail WITH (ROWLOCK) 
               SET CaseID = @cCaseID, QTY = @nPickQty, Status = '5'
               WHERE PickDetailKey = @cPickDetailKey  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 86627  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDetFail
                  GOTO RollBackTran  
               END  
        
               SET @nPickQty = 0 -- Reduce balance  
               BREAK  
            END 

            FETCH NEXT FROM CURSOR_RESTAMP_PICKDETAIL_INNER INTO @cPickDetailKey, @nQTY_PD
         END

         CLOSE CURSOR_RESTAMP_PICKDETAIL_INNER
         DEALLOCATE CURSOR_RESTAMP_PICKDETAIL_INNER

         FETCH NEXT FROM CURSOR_RESTAMP_PICKDETAIL INTO @cCaseID, @c_ConsigneeKey, @c_SKU, @n_Qty
      END

      CLOSE CURSOR_RESTAMP_PICKDETAIL
      DEALLOCATE CURSOR_RESTAMP_PICKDETAIL

      -- Clean up CaseID in pickdetail of UCC 
      UPDATE dbo.PickDetail WITH (ROWLOCK)
      SET CaseID = ''
      WHERE PickslipNo   = @cPickSlipNo      
      AND   StorerKey    = @cStorerKey    
      AND   DropID       = @cUCCNo 
      AND   Status       IN ('3', '5')    
      AND   ISNULL(CaseID, '') <> ''

      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 86621    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPickDetFail'    
         GOTO RollBackTran             
      END  

      -- Retrieve latest qty
      SELECT @nQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      WHERE PD.PickslipNo = @cPickSlipNo    
      AND PD.StorerKey    = @cStorerKey
      AND PD.DropID       = @cUCCNo
      AND PD.Status       IN ('3', '5')
      AND ISNULL(PD.CaseID,'') = ''

   END -- IF ISNULL(@cUCCNo, '') <> '' AND EXISTS

   /***************************************************/    
   /* Insert PackDetail                               */    
   /***************************************************/    
   IF ISNULL(@cUCCNo, '') <> ''
   BEGIN
      DECLARE CUR_UCC CURSOR READ_ONLY FAST_FORWARD LOCAL FOR
      SELECT SKU, Qty
      FROM UCC WITH (NOLOCK) 
      WHERE UCCNo = @cUCCNo 
        AND StorerKey = @cStorerKey 
        AND Status = '3'

      OPEN CUR_UCC
      FETCH NEXT FROM CUR_UCC INTO @cSKU, @nQty
   END 

UpdateDB:
   SET @nPickQty = @nQty
   SET @nCartonNo = 0    
   SET @cLabelLine = '00000'    

   -- Prevent OverPacked by ConsigneeKey --     
   -- Want to Check OverPack Here How To Handle ? --    
   SET @nTotalPickedQty = 0    
   SET @nTotalPackedQty = 0    
     
   SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)    
   FROM dbo.PickDetail PD WITH (NOLOCK)     
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   WHERE PD.PickslipNo   = @cPickSlipNo      
   AND   PD.StorerKey    = @cStorerKey    
   AND   PD.DropID       = CASE WHEN ISNULL(@cUCCNo, '') <> '' THEN @cUCCNo ELSE PD.DropID END
   AND   PD.SKU          = @cSKU
   AND   PD.Status       IN ('3', '5')    
   AND   PD.OrderKey     = CASE WHEN ISNULL(@cUCCNo, '') = '' THEN @cOrderKey ELSE PD.OrderKey END  
   AND   OD.Userdefine02 = CASE WHEN ISNULL(@cUCCNo, '') = '' THEN @cConsigneeKey ELSE OD.Userdefine02 END  

   SELECT @nTotalPackedQty = ISNULL(SUM(PCD.QTY),0)    
   FROM dbo.PACKDETAIL PCD WITH (NOLOCK)
   WHERE PCD.PickslipNo   = @cPickSlipNo    
   AND   PCD.StorerKey    = @cStorerKey 
   AND   PCD.SKU          = @cSKU
   AND   PCD.LabelNo      = @cLabelNo

   IF (ISNULL(@nTotalPackedQty,0) + ISNULL(@nQty,0)) > ISNULL(@nTotalPickedQty,0)    
   BEGIN    
      SET @nErrNo = 86603    
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OverPacked'     
      GOTO RollBackTran    
   END 

   IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
             WHERE PickSlipNo = @cPickSlipNo    
               AND LabelNo = @cLabelNo    
               AND SKU = @cSKU )    
   BEGIN    
      UPDATE PACKDETAIL WITH (ROWLOCK)    
      SET Qty = Qty + @nQty    
      WHERE PickSlipNo = @cPickSlipNo    
        AND LabelNo = @cLabelNo    
        AND SKU = @cSKU    
           
      IF @@ERROR <> 0     
      BEGIN    
         SET @nErrNo = 86604    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackDetFail'    
         GOTO RollBackTran    
      END     
   END    
   ELSE    
   BEGIN    
      INSERT INTO dbo.PACKDETAIL    
      (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, DropID)    
      VALUES    
      (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nQty, @cLabelNo)    
           
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 86605    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPackDetFail'    
         GOTO RollBackTran    
      END    

--      -- Insert DropID
--      IF NOT EXISTS(SELECT 1 FROM dbo.DropID WITH (NOLOCK)    
--                    WHERE PickSlipNo = @cPickSlipNo    
--                      AND DropID = @cLabelNo 
--                      AND DropIDType = '0'
--                      AND LabelPrinted <> 'Y')    
--      BEGIN 
--         INSERT INTO dbo.DropID 
--         (DropID, DropIDType, LabelPrinted, Status, Loadkey, PickSlipNo)
--         VALUES 
--         (@cLabelNo, '0', '0', '0', @cLoadKey , @cPickSlipNo)
--     
--         IF @@ERROR <> 0    
--         BEGIN    
--            SET @nErrNo = 86613   
--            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsDropIDFail'    
--            GOTO RollBackTran    
--         END    
--      END
--
--      -- Insert DropIDDetail
--      IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK)
--                     WHERE DropID = @cLabelNo
--                     AND ChildID = @cLabelNo
--                     AND UserDefine01 = @cConsigneeKey)
--      BEGIN                
--         INSERT INTO dbo.DropIDDetail (DropID, ChildID , UserDefine01)  
--         VALUES ( @cLabelNo , @cLabelNo, @cConsigneeKey) 
--                 
--         IF @@ERROR <> 0
--         BEGIN
--            SET @nErrNo = 86618
--            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsDrIDDetFail'
--            GOTO RollBackTran
--         END            
--      END
   END    
        
   -- Update PickDetail.CaseID = LabelNo, PickDetail.Status = '5'   
   DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                    
   SELECT PD.PickDetailKey, PD.Qty, PD.DropID
   FROM dbo.PickDetail PD WITH (NOLOCK)  
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)  
   WHERE PD.PickslipNo   = @cPickSlipNo    
   AND   LPD.LoadKey     = @cLoadKey    
   AND   PD.StorerKey    = @cStorerKey    
   AND   PD.DropID       = CASE WHEN ISNULL(@cUCCNo, '') <> '' THEN @cUCCNo ELSE PD.DropID END
   AND   PD.SKU          = @cSKU    
   AND   PD.Status       IN ('3', '5')    
   AND   PD.OrderKey     = CASE WHEN ISNULL(@cUCCNo, '') = '' THEN @cOrderKey ELSE PD.OrderKey END  
   AND   OD.Userdefine02 = CASE WHEN ISNULL(@cUCCNo, '') = '' THEN @cConsigneeKey ELSE OD.Userdefine02 END  
   AND   ISNULL(PD.CaseID,'') = ''  
   --ORDER BY PD.PickDetailKey  -- (Chee02)
   ORDER BY PD.UOM DESC

   OPEN  CursorPickDetail    
   FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cDropID -- (Chee01)
        
   WHILE @@FETCH_STATUS <> -1         
   BEGIN
      -- Chee04
--      -- Loose UCC (Chee01)
--      IF EXISTS(SELECT 1 FROM dbo.UCC WITH (NOLOCK)  
--                WHERE UCCNo = @cDropID 
--                  AND StorerKey = @cStorerKey 
--                  AND Status = '3')
--      BEGIN
--         UPDATE dbo.UCC WITH (ROWLOCK)
--         SET Status = '6'
--         WHERE UCCNo = @cDropID 
--           AND StorerKey = @cStorerKey 
--           AND Status = '3'
--
--         IF @@ERROR <> 0  
--         BEGIN  
--            SET @nErrNo = 86619  
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdUCCFail 
--            GOTO RollBackTran  
--         END
--      END

      -- Exact match  
      IF @nQTY_PD = @nPickQty  
      BEGIN  
         -- Confirm PickDetail  
         UPDATE dbo.PickDetail WITH (ROWLOCK) 
         SET CaseID = @cLabelNo, Status = '5'
         WHERE PickDetailKey = @cPickDetailKey  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 86606  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDetFail  
            GOTO RollBackTran  
         END  

         SET @nPickQty = 0 -- Reduce balance 
         BREAK  
      END   
      -- PickDetail have less  
      ELSE IF @nQTY_PD < @nPickQty  
      BEGIN  
         -- Confirm PickDetail  
         UPDATE dbo.PickDetail WITH (ROWLOCK)  
         SET CaseID = @cLabelNo, Status = '5'
         WHERE PickDetailKey = @cPickDetailKey  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 86607  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDetFail 
            GOTO RollBackTran  
         END  
 
         SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance  
      END  
  
      -- PickDetail have more, need to split  
      ELSE IF @nQTY_PD > @nPickQty  
      BEGIN  
         -- Get new PickDetailkey  
         SET @cNewPickDetailKey = ''
         EXECUTE dbo.nspg_GetKey  
            'PICKDETAILKEY',  
            10 ,  
            @cNewPickDetailKey OUTPUT,  
            @bSuccess          OUTPUT,  
            @nErrNo            OUTPUT,  
            @cErrMsg           OUTPUT  

         IF @bSuccess <> 1  
         BEGIN  
            SET @nErrNo = 86608  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
            GOTO RollBackTran  
         END  
  
         -- Create a new PickDetail to hold the balance  
         INSERT INTO dbo.PICKDETAIL (  
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,  
            Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,  
            QTY,  
            TrafficCop,  
            OptimizeCop,
            Channel_ID)  --(cc01)
         SELECT  
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,  
            Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,  
            @nQTY_PD - @nPickQty, -- QTY  
            NULL, --TrafficCop,  
            '1',  --OptimizeCop  
            Channel_ID --(cc01)
         FROM dbo.PickDetail WITH (NOLOCK)  
         WHERE PickDetailKey = @cPickDetailKey  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 86609  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPickDetFail  
            GOTO RollBackTran  
         END  
  
         -- Change orginal PickDetail with exact QTY (with TrafficCop)  
         UPDATE dbo.PickDetail WITH (ROWLOCK) 
         SET QTY = @nPickQty, TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 86610  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDetFail
            GOTO RollBackTran  
         END  

         -- Update status (without TrafficCop)  
         UPDATE dbo.PickDetail WITH (ROWLOCK) 
         SET CaseID = @cLabelNo, QTY = @nPickQty, Status = '5'
         WHERE PickDetailKey = @cPickDetailKey  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 86615  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDetFail
            GOTO RollBackTran  
         END  
  
         SET @nPickQty = 0 -- Reduce balance  
         BREAK  
      END 
          
      FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cDropID -- (Chee01)   
    END    
    CLOSE CursorPickDetail             
    DEALLOCATE CursorPickDetail    
  
   /***************************************************/    
   /* Insert PackInfo                                 */    
   /***************************************************/    
   SET @nCartonNo = 0    
   SELECT TOP 1 @nCartonNo = CartonNo 
   FROM dbo.PackDetail WITH (NOLOCK)  
   WHERE PickSlipNo = @cPickSlipNo  
     AND LabelNo = @cLabelNo  

   IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   CartonNo = @nCartonNo)
   BEGIN
      INSERT INTO dbo.PACKINFO (PickSlipNo, CartonNo, CartonType, RefNo)  
      VALUES (@cPickSlipNo, @nCartonNo, @cCartonType, @cLabelNo)   
      
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 86611  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackInfFail
         GOTO RollBackTran  
      END    
   END
   ELSE
   BEGIN
      UPDATE dbo.PackInfo WITH (ROWLOCK) 
      SET CartonType = @cCartonType 
      WHERE PickSlipNo = @cPickSlipNo
      AND   CartonNo = @nCartonNo
      AND   ISNULL(CartonType, '') = ''

      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 86612  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackInfFail 
         GOTO RollBackTran  
      END    
   END

   IF ISNULL(@cUCCNo, '') <> ''
   BEGIN
      FETCH NEXT FROM CUR_UCC INTO @cSKU, @nQty
      IF @@FETCH_STATUS <> -1
      BEGIN   
         GOTO UpdateDB
      END
      ELSE
      BEGIN
         CLOSE CUR_UCC
         DEALLOCATE CUR_UCC

         -- Loose UCC (Chee04)
         IF EXISTS(SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                   WHERE UCCNo = @cDropID 
                     AND StorerKey = @cStorerKey 
                     AND Status = '3')
         BEGIN
            UPDATE dbo.UCC WITH (ROWLOCK)
            SET Status = '6'
            WHERE UCCNo = @cDropID 
              AND StorerKey = @cStorerKey 
              AND Status = '3'

            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 86619  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdUCCFail 
               GOTO RollBackTran  
            END
         END
      END
   END

   /********************************/    
   /* Pack Confirm                 */    
   /********************************/      
   SET @nTotalPickedQty = 0    
   SET @nTotalPackedQty = 0   
        
   SELECT @nTotalPickedQty = SUM(PD.QTY)    
   FROM dbo.PickDetail PD WITH (NOLOCK)     
   INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
   INNER JOIN dbo.LoadPlanDetail LP WITH (NOLOCK) ON LP.OrderKey = PD.OrderKey    
   WHERE PD.PickslipNo  = @cPickSlipNo    
   AND   LP.LoadKey     = @cLoadKey    
   AND   PD.StorerKey   = @cStorerKey    
  
   SELECT @nTotalPackedQty = SUM(PCD.QTY)    
   FROM   dbo.PACKDETAIL PCD WITH (NOLOCK)    
   WHERE  PCD.PickSlipNo = @cPickSlipNo    
   AND    PCD.StorerKey  = @cStorerKey    
       
   IF @nTotalPickedQty = @nTotalPackedQty AND @nTotalPickedQty <> 0 
   BEGIN    
      UPDATE dbo.PackHeader WITH (ROWLOCK)    
         SET STATUS = '9'    
      WHERE PICKSLIPNO = @cPickSlipNo    
          
      IF @@ERROR <> 0     
      BEGIN      
         SET @nErrNo = 86616  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackHdrFail 
         GOTO RollBackTran     
      END     
        
      -- Update PickingInfo   
      UPDATE dbo.PickingInfo WITH (ROWLOCK)  
         SET ScanOutdate = GetDate() , TrafficCop = NULL  
      WHERE PickSlipNo = @cPickSlipNo   
        
      IF @@ERROR <> 0     
      BEGIN      
         SET @nErrNo = 86617  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickInfFail 
         GOTO RollBackTran   
      END  
   END -- IF @nTotalPickedQty = @nTotalPackedQty  


   -- Add eventlog  (yeekung01)      
   EXEC RDT.rdt_STD_EventLog      
      @cActionType = '3', -- Sign in function      
      @cUserID     = @cUserName,      
      @nMobileNo   = @nMobile,      
      @nFunctionID = @nFunc,      
      @cFacility   = @cFacility,      
      @cStorerKey  = @cStorerkey,  
      @nStep       = @nStep,
      @cLoadKey    = @cLoadkey,
      @cUCC        = @cUCCNo,
      @cLabelNo    = @cLabelNo

   GOTO Quit
  
RollBackTran:  
      ROLLBACK TRAN rdt_ANFSAP_Cfm01  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  
END  

GO
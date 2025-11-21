SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_Carton_Consolidation_Confirm                    */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Comfirm Pick                                                */  
/*                                                                      */  
/* Called from: rdtfnc_ToteConsolidation                                */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2011-01-05 1.0  James    Created                                     */  
/************************************************************************/  
CREATE PROC [RDT].[rdt_Carton_Consolidation_Confirm] (    
   @nMobile          INT,     
   @nFunc            INT, 
   @cStorerKey       NVARCHAR(10),  
   @cPickSlipNo      NVARCHAR(10),  
   @cFromCarton      NVARCHAR(18),  
   @cToCarton        NVARCHAR(18),  
   @cLangCode        NVARCHAR(3),  
   @cUserName        NVARCHAR(18),  
   @cStatus          NVARCHAR(1),  
   @cSKU             NVARCHAR(20),
   @cFacility        NVARCHAR(5), 
   @nQtyMV           INT,  
   @nErrNo           INT          OUTPUT,    
   @cErrMsg          NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE   
      @nTranCount         INT ,  
      @nQTy               INT,  
      @cRefNo             NVARCHAR(20), 
      @nTotPack           INT, 
      @cOrderKey          NVARCHAR(10), 
      @nCarton_QTY        INT, 
      @cLabelLine         NVARCHAR(5), 
      @cPDOrderkey        NVARCHAR(10),
      @cPDPickSlipNo      NVARCHAR(10), 
      @nSumPackQTY        INT, 
      @nSumPickQTY        INT, 
      @nCartonNo          INT,
      @cLabelNo           NVARCHAR(20),
      @nPackedQty         INT, 
      @cPickDetailKey     NVARCHAR(10), 
      @cNewPickDetailKey  NVARCHAR(10),
      @bSuccess           INT,
      @nPickedQty         INT, 
      @cTaskDetailKey     NVARCHAR(10), 
      @cNewTaskDetailKey  NVARCHAR(10),
      @b_success          INT, 
      @n_err              INT, 
      @c_errmsg           NVARCHAR(20) 
       
  
   -- Initialize Variable  
   SET @nTranCount = @@TRANCOUNT    
   SET @nErrNo = 0  
   SET @nQty = 0  
    
   BEGIN TRAN    
   SAVE TRAN Carton_Confirm    

   SET @nTotPack = 0
     
   SELECT @nTotPack = ISNULL(SUM(QTY),0)     
   FROM PackDetail PD WITH (NOLOCK)    
   JOIN PackHeader PH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo  
   JOIN ORDERS O (NOLOCK) ON PH.OrderKey = O.OrderKey   
   WHERE O.Status < '9'   
   AND  PD.DropID  = @cFromCarton 
   AND  PD.SKU = CASE WHEN @cStatus = 'F' THEN PD.SKU ELSE @cSKU END
   
   IF @nTotPack > 0 
   BEGIN
      IF @cStatus = 'F'  
      BEGIN 
         DELETE PD 
         FROM PackDetail PD WITH (NOLOCK)    
         JOIN PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo  
         JOIN ORDERS O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey   
         WHERE O.Status < '9'   
         AND  PD.DropID  = @cFromCarton 
      END  
      IF @cStatus = 'P'
      BEGIN
         IF @nTotPack > @nQtyMV
         BEGIN
            SET @nQty = @nQtyMV
            
            DECLARE CUR_PACKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT PD.PickSlipNo, PD.CartonNo, PD.LabelNo, PD.LabelLine, PD.Qty 
            FROM PackDetail PD WITH (NOLOCK)    
            JOIN PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo  
            JOIN ORDERS O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey   
            WHERE O.Status < '9'   
            AND  PD.DropID  = @cFromCarton 
            AND  PD.StorerKey = @cStorerKey  
            AND  PD.SKU = @cSKU            
            
            OPEN CUR_PACKDETAIL 
            
            FETCH NEXT FROM CUR_PACKDETAIL INTO @cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @nPackedQty
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @nPackedQty > @nQty
                  SET @nPackedQty = @nQty
                   
               UPDATE PACKDETAIL WITH (ROWLOCK) 
                  SET Qty = Qty - @nPackedQty
               WHERE PickSlipNo = @cPickSlipNo 
               AND  CartonNo = @nCartonNo
               AND  LabelNo  = @cLabelNo
               AND  LabelLine = @cLabelLine
               
               SET @nQty = @nQty - @nPackedQty
               
               IF @nQty = 0 
                  BREAK 
               
               FETCH NEXT FROM CUR_PACKDETAIL INTO @cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @nPackedQty
            END                         
            CLOSE CUR_PACKDETAIL
            DEALLOCATE CUR_PACKDETAIL
         END
         ELSE
         BEGIN
            DELETE PD 
            FROM PackDetail PD WITH (NOLOCK)    
            JOIN PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo  
            JOIN ORDERS O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey   
            WHERE O.Status < '9'   
            AND  PD.DropID  = @cFromCarton 
            AND  PD.StorerKey = @cStorerKey  
            AND  PD.SKU = @cSKU            
         END
      END
   END        
   --IF @nTotPack = 0
   BEGIN
      -- Insert Pack Detail Here....  
      BEGIN TRAN                
       
      DECLARE CUR_CARTON CURSOR LOCAL READ_ONLY FAST_FORWARD FOR                
      SELECT PD.OrderKey, PD.SKU, SUM(PD.Qty)   
      FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.ORDERS O WITH (NOLOCK) ON o.OrderKey = PD.OrderKey   
      WHERE PD.StorerKey = @cStorerKey                
        AND PD.DropID = @cFromCarton                
        AND PD.Status >= '5'                
        AND PD.Status < '9'  
        AND PD.Qty > 0        
        AND O.Status < '9' 
        AND PD.SKU = CASE WHEN @cStatus = 'F' THEN PD.SKU ELSE @cSKU END
      GROUP BY PD.OrderKey, PD.SKU  
                   
      OPEN CUR_CARTON                
      FETCH NEXT FROM CUR_CARTON INTO @cOrderKey, @cSKU, @nCarton_QTY                
      WHILE @@FETCH_STATUS <> -1                
      BEGIN  
         IF @nCarton_QTY <= @nQtyMV OR @cStatus = 'F' 
         BEGIN
            UPDATE PD WITH (ROWLOCK) SET   
               DropID = @cToCarton,     
               TrafficCop = NULL 
            FROM dbo.PickDetail PD   
            JOIN dbo.Orders O ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)   
            WHERE PD.StorerKey = @cStorerKey 
               AND PD.SKU = @cSKU   
               AND O.Status NOT IN ('9', 'CANC')  
               AND PD.Status = '5'  
               AND PD.DropID = @cFromCarton  
               AND PD.OrderKey = @cOrderKey             
         END
         ELSE
         BEGIN
            SET @nCarton_QTY = @nQtyMv

            -- Split PickDetail 
            DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT PD.PickDetailKey, PD.Qty 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)   
            WHERE PD.StorerKey = @cStorerKey 
               AND PD.SKU = @cSKU   
               AND O.Status NOT IN ('9', 'CANC')  
               AND PD.Status = '5'  
               AND PD.DropID = @cFromCarton  
               AND PD.OrderKey = @cOrderKey  

            OPEN CUR_PICKDETAIL

            FETCH NEXT FROM CUR_PICKDETAIL INTO @cPickDetailKey, @nQty
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @nQty > @nQtyMv 
               BEGIN
                  EXECUTE dbo.nspg_GetKey      
                     'PICKDETAILKEY',      
                     10 ,      
                     @cNewPickDetailKey OUTPUT,      
                     @bSuccess         OUTPUT,      
                     @nErrNo           OUTPUT,      
                     @cErrMsg          OUTPUT      
            
                  IF @bSuccess <> 1      
                  BEGIN      
                     SET @nErrNo = 72016      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKeyFail'      
                     GOTO QUIT      
                  END      
            
                  -- Create a new PickDetail to hold the balance      
                  INSERT INTO dbo.PICKDETAIL (      
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,      
                     Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,      
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,      
                     QTY, TrafficCop, OptimizeCop, TaskDetailKey)      
                  SELECT      
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, @nQty - @nQtyMv, QTYMoved,      
                     Status,    
                     DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,      
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,      
                     @nQty - @nQtyMv, -- QTY      
                     NULL, --TrafficCop,      
                     '1',  --OptimizeCop      
                     TaskDetailKey     
                  FROM dbo.PickDetail WITH (NOLOCK)      
                  WHERE PickDetailKey = @cPickDetailKey      
            
                  IF @@ERROR <> 0      
                  BEGIN      
                     SET @nErrNo = 72017      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'      
                     GOTO QUIT
                  END      

                  UPDATE PICKDETAIL WITH (ROWLOCK) 
                     SET QTY = @nQtyMv,  
                         TrafficCop=NULL  
                  WHERE PickDetailKey = @cPickDetailKey               

                  SET @nQty = @nQtyMv
               END
               
               UPDATE PICKDETAIL WITH (ROWLOCK) 
                  SET DropID = @cToCarton, 
                      TrafficCop=NULL  
               WHERE PickDetailKey = @cPickDetailKey               
               
               SET @nQtyMv = @nQtyMv - @nQty

               IF @nQtyMv = 0 
                  BREAK
                   
               FETCH NEXT FROM CUR_PICKDETAIL INTO @cPickDetailKey, @nQty 
            END
            CLOSE CUR_PICKDETAIL
            DEALLOCATE CUR_PICKDETAIL 
         END
                               
         SELECT @cPickSlipNo = PickHeaderKey   
         FROM dbo.PickHeader WITH (NOLOCK)       
         WHERE OrderKey = @cOrderKey                
        
         IF ISNULL(@cPickSlipNo, '') = ''                
         BEGIN                
            ROLLBACK TRAN                
             
            CLOSE CUR_CARTON                
            DEALLOCATE CUR_CARTON                
            SET @nErrNo = 72018                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKSLIP REQ                
                            
            GOTO Quit                  
         END                
          
         -- Create packheader if not exists                
         IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)                 
            WHERE PickSlipNo = @cPickSlipNo)                
         BEGIN                
            INSERT INTO dbo.PackHeader                 
            (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)                
            SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo                 
            FROM  dbo.PickHeader PH WITH (NOLOCK)                
            JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)                
            WHERE PH.PickHeaderKey = @cPickSlipNo                
     
            IF @@ERROR <> 0                
            BEGIN                
               ROLLBACK TRAN                
             
               CLOSE CUR_CARTON                
               DEALLOCATE CUR_CARTON                
               SET @nErrNo = 72019                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PAHDR FAIL                               
               GOTO Quit                  
            END                
         END                
             
         -- Create packdetail                
         IF EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)   
                    WHERE PickSlipNo = @cPickSlipNo   
                    AND StorerKey = @cStorerKey ) -- (Vicky01)                
         BEGIN                
            -- Not exists then new label no, hardcode label no to '00001'                
            -- CartonNo and LabelLineNo will be inserted by trigger                
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) -- (james05)              
                           WHERE PickSlipNo = @cPickSlipNo               
                           AND StorerKey = @cStorerKey   
                           AND LabelNo = @cToCarton)   
            BEGIN              
               SET @nCartonNo = 0
               SET @cLabelNo = ''

               EXECUTE dbo.nsp_GenLabelNo
                  '',
                  @cStorerKey,
                  @c_labelno     = @cLabelNo  OUTPUT,
                  @n_cartonno    = @nCartonNo OUTPUT,
                  @c_button      = '',
                  @b_success     = @b_success OUTPUT,
                  @n_err         = @n_err     OUTPUT,
                  @c_errmsg      = @c_errmsg  OUTPUT

               INSERT INTO dbo.PackDetail                 
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, 
                   AddWho, AddDate, EditWho, EditDate, DropID, RefNo2)                
               VALUES                 
                  (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU, @nCarton_QTY,               
                   'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cToCarton, @cFromCarton)   

               -- insert to Eventlog                
               EXEC RDT.rdt_STD_EventLog                
                  @cActionType   = '4',                
                  @cUserID       = @cUserName,                
                  @nMobileNo     = @nMobile,                
                  @nFunctionID   = @nFunc,                
                  @cFacility     = @cFacility,                
                  @cStorerKey    = @cStorerKey,                
                  @nQty          = @nCarton_QTY,  -- (james04)                
                  @cRefNo1       = @cFromCarton,              
                  @cRefNo2       = @cToCarton              
            END              
            ELSE              
            BEGIN              
               -- (shong02)              
               SET @nCartonNo = 0              
               SET @cLabelLine= ''               
               SELECT TOP 1               
                      @nCartonNo = CartonNo,               
                      @cLabelLine = LabelLine                
               FROM dbo.PackDetail WITH (NOLOCK) -- (james05)              
               WHERE PickSlipNo = @cPickSlipNo               
               AND   StorerKey = @cStorerKey              
               AND   DropID = @cToCarton               
               ORDER BY LabelLine DESC              
                       
               SET @cLabelLine = RIGHT('0000' + CONVERT( NVARCHAR(5), CAST(@cLabelLine AS INT) + 1 ), 5)                
                             
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) -- (james05)              
                              WHERE PickSlipNo = @cPickSlipNo               
                              AND StorerKey = @cStorerKey               
                              AND SKU = @cSKU               
                              AND LabelNo = @cToCarton )              
               BEGIN                                
                  SET @nCartonNo = 0
                  SET @cLabelNo = ''

                  EXECUTE dbo.nsp_GenLabelNo
                     '',
                     @cStorerKey,
                     @c_labelno     = @cLabelNo  OUTPUT,
                     @n_cartonno    = @nCartonNo OUTPUT,
                     @c_button      = '',
                     @b_success     = @b_success OUTPUT,
                     @n_err         = @n_err     OUTPUT,
                     @c_errmsg      = @c_errmsg  OUTPUT

                  INSERT INTO dbo.PackDetail                 
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, 
                      AddWho, AddDate, EditWho, EditDate, DropID, RefNo2)                
                  VALUES                 
                     (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nCarton_QTY,               
                     'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cToCarton, @cFromCarton)                                     
               END
               ELSE
               BEGIN
                  UPDATE dbo.PackDetail WITH (ROWLOCK) 
                     SET Qty = Qty + @nCarton_QTY 
                  WHERE PickSlipNo = @cPickSlipNo               
                    AND StorerKey = @cStorerKey               
                    AND SKU = @cSKU               
                    AND LabelNo = @cToCarton
                    
               END
               -- insert to Eventlog                
               EXEC RDT.rdt_STD_EventLog                
                  @cActionType   = '4',                
                  @cUserID       = @cUserName,                
                  @nMobileNo     = @nMobile,                
                  @nFunctionID   = @nFunc,                
                  @cFacility     = @cFacility,                
                  @cStorerKey    = @cStorerkey,                
                  @nQty          = @nCarton_QTY,  -- (james04)                
                  @cRefNo1       = @cFromCarton,              
                  @cRefNo2       = @cToCarton              
            END              
         END                
          
         IF @@ERROR <> 0                
         BEGIN                
            ROLLBACK TRAN                
             
            CLOSE CUR_CARTON                
            DEALLOCATE CUR_CARTON                
            SET @nErrNo = 72020                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PADET FAIL                               
            GOTO Quit                  
         END                

         FETCH NEXT FROM CUR_CARTON INTO @cOrderKey, @cSKU, @nCarton_QTY                
      END                
      CLOSE CUR_CARTON                
      DEALLOCATE CUR_CARTON                
        
      -- (Vicky03) - Pack Confirmation - Start              
      DECLARE Cursor_PackConf CURSOR LOCAL READ_ONLY FAST_FORWARD FOR          
      SELECT DISTINCT O.OrderKey              
      FROM PackDetail PD WITH (NOLOCK)    
      JOIN PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo  
      JOIN ORDERS O (NOLOCK) ON o.OrderKey = PH.OrderKey   
      WHERE  O.StorerKey = @cStorerKey                
         AND PD.DropID = @cToCarton                
         AND PH.Status < '9'                
         AND O.Status  < '9'                
                 
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
                   
               SET @nErrNo = 72021                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PaHdr Fail'                
               GOTO Quit                
            END              
         END                
                 
         FETCH NEXT FROM Cursor_PackConf INTO @cPDOrderkey              
      END                
      CLOSE Cursor_PackConf          
      DEALLOCATE Cursor_PackConf                
      -- (Vicky03) - Pack Confirmation - End           
          
      COMMIT TRAN                
   END -- IF @nTotPack = 0

   GOTO Quit    
    
   RollBackTran:    
      ROLLBACK TRAN Carton_Confirm    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN Carton_Confirm    
END    

GO
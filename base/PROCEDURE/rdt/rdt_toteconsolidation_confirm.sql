SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_ToteConsolidation_Confirm                       */  
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
/* 2010-08-25 1.0  ChewKP   Created                                     */  
/* 2010-09-13 1.1  James    Get the correct packdetail to upd (james01) */  
/* 2012-06-18 1.2  ChewKP   SOS#247246 Delete WCS Routing when Tote     */
/*                          Consolidation (ChewKP01)                    */
/* 2014-09-21 1.3  James    Update Sack ID to TD.FinalID (james02)      */
/* 2014-10-03 1.4  James    Bug fix for tote reuse. Only select the     */
/*                          record not yet packed (james03)             */
/* 2015-09-29 1.5  TLTING   Add Nolock                                  */
/************************************************************************/  
CREATE PROC [RDT].[rdt_ToteConsolidation_Confirm] (    
   @nMobile          INT,     
   @cStorerKey       NVARCHAR(10),  
   @cPickSlipNo      NVARCHAR(10),  
   @cFromTote        NVARCHAR(18),  
   @cToTote          NVARCHAR(18),  
   @cLangCode        NVARCHAR(3),  
   @cUserName        NVARCHAR(18),  
   @cStatus          NVARCHAR(1),  
   @cSKU             NVARCHAR(20),
   @cFacility        NVARCHAR(5), 
   @nFunc            INT,  
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
      @nTote_QTY          INT, 
      @cConsigneeKey      NVARCHAR(15), 
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
      @b_Success          INT, 
      @cPTS_Sacks         NVARCHAR( 1)
       
  
   -- Initialize Variable  
   SET @nTranCount = @@TRANCOUNT    
   SET @nErrNo = 0  
   SET @nQty = 0  
   SET @nFunc = 973
    
   BEGIN TRAN    
   SAVE TRAN ToteConfirm    

   SET @nTotPack = 0
   SET @cPTS_Sacks = '0'

   IF rdt.RDTGetConfig( @nFunc, 'PTS_INITIAL_SCN', @cStorerKey) = 1
   BEGIN
      -- If len of fromtote = 8 and len of totote = 10 then is PTS sack
      -- else is either tote consolidation or sack consolidation
      IF LEN( RTRIM( @cToTote)) = 10 AND LEN( RTRIM( @cFromTote)) = 8
         SET @cPTS_Sacks = '1'
   END

   SELECT @nTotPack = ISNULL(SUM(QTY),0)     
   FROM PackDetail pd WITH (NOLOCK)    
   JOIN PackHeader p (NOLOCK) ON p.PickSlipNo = pd.PickSlipNo  
   JOIN ORDERS o (NOLOCK) ON o.OrderKey = p.OrderKey   
   JOIN DROPID D (NOLOCK) ON D.DropID = pd.dropid AND D.DropIDType = 'PIECE' AND D.LoadKey = P.Loadkey    
   WHERE o.status < '9'   
   AND  O.UserDefine01=''  
   AND  pd.dropid  = @cFromTote 
   AND  pd.SKU = CASE WHEN @cStatus = 'F' THEN PD.SKU ELSE @cSKU END
   
   IF @nTotPack > 0 
   BEGIN
      IF @cStatus = 'F'  
      BEGIN 
         DELETE PD 
         FROM PackDetail pd WITH (NOLOCK)    
         JOIN PackHeader p (NOLOCK) ON p.PickSlipNo = pd.PickSlipNo  
         JOIN ORDERS o (NOLOCK) ON o.OrderKey = p.OrderKey   
         JOIN DROPID D (NOLOCK) ON D.DropID = pd.dropid AND D.DropIDType = 'PIECE' AND D.LoadKey = P.Loadkey    
         WHERE o.status < '9'   
         AND  O.UserDefine01=''  
         AND  pd.dropid  = @cFromTote 
      END  
      IF @cStatus = 'P'
      BEGIN
         IF @nTotPack > @nQtyMV
         BEGIN
            SET @nQty = @nQtyMV
            
            DECLARE CUR_PACKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT pd.PickSlipNo, pd.CartonNo, pd.LabelNo, pd.LabelLine, pd.Qty 
            FROM PackDetail pd WITH (NOLOCK)    
            JOIN PackHeader p (NOLOCK) ON p.PickSlipNo = pd.PickSlipNo  
            JOIN ORDERS o (NOLOCK) ON o.OrderKey = p.OrderKey   
            JOIN DROPID D (NOLOCK) ON D.DropID = pd.dropid AND D.DropIDType = 'PIECE' AND D.LoadKey = P.Loadkey    
            WHERE o.status < '9'   
            AND  O.UserDefine01=''  
            AND  pd.dropid  = @cFromTote 
            AND  pd.StorerKey = @cStorerKey  
            AND  pd.SKU = @cSKU            
            
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
            FROM PackDetail pd WITH (NOLOCK)    
            JOIN PackHeader p (NOLOCK) ON p.PickSlipNo = pd.PickSlipNo  
            JOIN ORDERS o (NOLOCK) ON o.OrderKey = p.OrderKey   
            JOIN DROPID D (NOLOCK) ON D.DropID = pd.dropid AND D.DropIDType = 'PIECE' AND D.LoadKey = P.Loadkey    
            WHERE o.status < '9'   
            AND  O.UserDefine01=''  
            AND  pd.dropid  = @cFromTote 
            AND  pd.StorerKey = @cStorerKey  
            AND  pd.SKU = @cSKU            
         END
      END
   END        
   --IF @nTotPack = 0
   BEGIN
      -- Insert Pack Detail Here....  
      BEGIN TRAN                
       
      DECLARE CUR_TOTE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR                
      SELECT PD.OrderKey, PD.SKU, SUM(PD.Qty)   
      FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = PD.OrderKey   
      JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey 
      JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = PD.DropID AND DI.Loadkey = O.LoadKey  -- (SHONGxx)        
      WHERE PD.StorerKey = @cStorerKey                
        AND PD.DropID = @cFromTote                
        AND PD.Status >= '5'                
        AND PD.Status < '9'  
        AND PD.Qty > 0        
        AND TD.PickMethod = 'PIECE'      
        AND TD.Status = '9'     
        AND O.Status < '9' 
        AND PD.SKU = CASE WHEN @cStatus = 'F' THEN PD.SKU ELSE @cSKU END
        AND ISNULL( PD.AltSKU, '') = ''   -- Tote can be reused. Exclude those already packed   (james03)
      GROUP BY PD.OrderKey, PD.SKU  
                   
      OPEN CUR_TOTE                
      FETCH NEXT FROM CUR_TOTE INTO @cOrderKey, @cSKU, @nTote_QTY                
      WHILE @@FETCH_STATUS <> -1                
      BEGIN  
         IF @nTote_QTY <= @nQtyMV OR @cStatus = 'F' 
         BEGIN
            -- (james02)
            -- If it is PTS sack then do not update TD.DropID and update to FinalID
            UPDATE TD WITH (ROWLOCK) SET   
               TD.DropID = CASE WHEN @cPTS_Sacks = '1' THEN TD.DropID ELSE @cToTote END,   
               TD.FinalID = CASE WHEN @cPTS_Sacks = '1' THEN @cToTote ELSE TD.FinalID END,   
               TD.Message02 = @cFromTote,   
               TD.TrafficCop = NULL 
            FROM dbo.TaskDetail TD 
            JOIN dbo.PickDetail PD (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey   
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)   
            WHERE TD.StorerKey = @cStorerKey 
               AND TD.SKU = @cSKU   
               AND O.Status NOT IN ('9', 'CANC')  
               AND PD.Status = '5'  
               AND PD.DropID = @cFromTote  
               AND PD.OrderKey = @cOrderKey
               AND ISNULL( PD.AltSKU, '') = ''   -- Tote can be reused. Exclude those already packed (james03)
                           
            UPDATE PD WITH (ROWLOCK) SET   
               PD.DropID = CASE WHEN @cPTS_Sacks = '1' THEN DropID ELSE @cToTote END,   
               PD.AltSKU = CASE WHEN @cPTS_Sacks = '1' THEN @cToTote ELSE AltSKU END,   
               PD.TrafficCop = NULL 
            FROM dbo.PickDetail PD   
            JOIN dbo.Orders O  WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)   
            WHERE PD.StorerKey = @cStorerKey 
               AND PD.SKU = @cSKU   
               AND O.Status NOT IN ('9', 'CANC')  
               AND PD.Status = '5'  
               AND PD.DropID = @cFromTote  
               AND PD.OrderKey = @cOrderKey  
               AND ISNULL( PD.AltSKU, '') = ''   -- Tote can be reused. Exclude those already packed  (james03)

         END
         ELSE
         BEGIN
            SET @nTote_QTY = @nQtyMv

            -- Split PickDetail 
            DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT PD.PickDetailKey, PD.Qty, PD.TaskDetailKey 
            FROM dbo.PickDetail PD   WITH (NOLOCK)
            JOIN dbo.Orders O  WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)   
            WHERE PD.StorerKey = @cStorerKey 
               AND PD.SKU = @cSKU   
               AND O.Status NOT IN ('9', 'CANC')  
               AND PD.Status = '5'  
               AND PD.DropID = @cFromTote  
               AND PD.OrderKey = @cOrderKey  
               AND ISNULL( PD.AltSKU, '') = ''   -- Tote can be reused. Exclude those already packed  (james03)

            OPEN CUR_PICKDETAIL

            FETCH NEXT FROM CUR_PICKDETAIL INTO @cPickDetailKey, @nQty, @cTaskDetailKey  
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
                     SET @nErrNo = 70528      
                     SET @cErrMsg = rdt.rdtgetmessage( 70528, @cLangCode, 'DSP') -- 'GetDetKeyFail'      
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
                     SET @nErrNo = 70529      
                     SET @cErrMsg = rdt.rdtgetmessage( 70529, @cLangCode, 'DSP') --'Ins PDtl Fail'      
                     GOTO QUIT
                  END      

                 EXECUTE nspg_getkey             
                 'TaskDetailKey',             
                 10,             
                 @cNewTaskDetailKey OUTPUT,             
                 @bSuccess          OUTPUT,      
                 @nErrNo            OUTPUT,      
                 @cErrMsg           OUTPUT             

                 INSERT TASKDETAIL            
                   (            
                     TaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM,             
                     UOMQty, Qty, FromLoc, FromID, ToLoc, ToId, SourceType,             
                     SourceKey, Caseid, Priority, SourcePriority, OrderKey,             
                     OrderLineNumber, PickDetailKey, PickMethod, STATUS,             
                     LoadKey, AreaKey, Message01, SystemQty, DropID, UserKey             
                   )            
                 SELECT @cNewTaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM,             
                     @nQty - @nQtyMv, @nQty - @nQtyMv, FromLoc, FromID, ToLoc, ToId, SourceType,             
                     SourceKey, Caseid, Priority, SourcePriority, OrderKey,             
                     OrderLineNumber, PickDetailKey, PickMethod, STATUS,             
                     LoadKey, AreaKey, Message01, SystemQty, DropID, UserKey
                 FROM TASKDETAIL (NOLOCK)
                 WHERE TaskDetailKey = @cTaskDetailKey   
                  
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                     SET QTY = @nQtyMv,  
                         TrafficCop=NULL  
                  WHERE PickDetailKey = @cPickDetailKey               

                  SET @nQty = @nQtyMv

               END
               
               /* -- (james02)
               UPDATE PICKDETAIL 
                  SET DropID = @cToTote, 
                      TrafficCop=NULL  
               WHERE PickDetailKey = @cPickDetailKey               
               
               UPDATE TASKDETAIL 
                  SET DropID = @cToTote, Message02 = @cFromTote, TrafficCop=NULL
               WHERE TaskDetailKey = @cTaskDetailKey 
               */

               UPDATE PICKDETAIL WITH (ROWLOCK) SET   
                  DropID = CASE WHEN @cPTS_Sacks = '1' THEN DropID ELSE @cToTote END,   
                  AltSKU = CASE WHEN @cPTS_Sacks = '1' THEN @cToTote ELSE AltSKU END,   
                  TrafficCop = NULL 
               WHERE PickDetailKey = @cPickDetailKey

               UPDATE TaskDetail WITH (ROWLOCK) SET   
                  DropID = CASE WHEN @cPTS_Sacks = '1' THEN DropID ELSE @cToTote END,   
                  FinalID = CASE WHEN @cPTS_Sacks = '1' THEN @cToTote ELSE FinalID END,   
                  Message02 = @cFromTote,   
                  TrafficCop = NULL 
               WHERE TaskDetailKey = @cTaskDetailKey
               
               SET @nQtyMv = @nQtyMv - @nQty

               IF @nQtyMv = 0 
                  BREAK
                   
               FETCH NEXT FROM CUR_PICKDETAIL INTO @cPickDetailKey, @nQty, @cTaskDetailKey  
            END
            CLOSE CUR_PICKDETAIL
            DEALLOCATE CUR_PICKDETAIL 
         END
                               
         SELECT @cPickSlipNo = PickHeaderKey   
         FROM dbo.PickHeader WITH (NOLOCK)       
         WHERE OrderKey = @cOrderKey                
        
         SELECT @cConsigneeKey = ConsigneeKey   
         FROM dbo.PackHeader WITH (NOLOCK)       
         WHERE PickSlipNo = @cPickSlipNo                

         IF ISNULL(@cPickSlipNo, '') = ''                
         BEGIN                
            ROLLBACK TRAN                
             
            CLOSE CUR_TOTE                
            DEALLOCATE CUR_TOTE                
            SET @nErrNo = 69823                
            SET @cErrMsg = rdt.rdtgetmessage( 69823, @cLangCode, 'DSP') --PKSLIP REQ                
                            
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
             
               CLOSE CUR_TOTE                
               DEALLOCATE CUR_TOTE                
               SET @nErrNo = 69824                
               SET @cErrMsg = rdt.rdtgetmessage( 69824, @cLangCode, 'DSP') --INS PAHDR FAIL                               
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
                           AND LabelNo = @cToTote)   
            BEGIN              
               INSERT INTO dbo.PackDetail                 
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, 
                   AddWho, AddDate, EditWho, EditDate, DropID, RefNo2)                
               VALUES                 
                  (@cPickSlipNo, 0, @cToTote, '00000', @cStorerKey, @cSKU, @nTote_QTY,               
                   'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cToTote, @cFromTote)   

               -- insert to Eventlog                
               EXEC RDT.rdt_STD_EventLog                
                  @cActionType   = '4',                
                  @cUserID       = @cUserName,                
                  @nMobileNo     = @nMobile,                
                  @nFunctionID   = @nFunc,                
                  @cFacility     = @cFacility,                
                  @cStorerKey    = @cStorerKey,                
                  @nQty          = @nTote_QTY,  -- (james04)                
                  @cRefNo1       = @cToTote,              
                  @cRefNo2       = @cConsigneekey   -- (james07)              
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
               AND   DropID = @cToTote               
               ORDER BY LabelLine DESC              
                       
               SET @cLabelLine = RIGHT('0000' + CONVERT( NVARCHAR(5), CAST(@cLabelLine AS INT) + 1 ), 5)                
                             
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) -- (james05)              
                              WHERE PickSlipNo = @cPickSlipNo               
                              AND StorerKey = @cStorerKey               
                              AND SKU = @cSKU               
                              AND LabelNo = @cToTote )              
               BEGIN                                
                  INSERT INTO dbo.PackDetail                 
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, 
                      AddWho, AddDate, EditWho, EditDate, DropID, RefNo2)                
                  VALUES                 
                     (@cPickSlipNo, @nCartonNo, @cToTote, @cLabelLine, @cStorerKey, @cSKU, @nTote_QTY,               
                     'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cToTote, @cFromTote)                                     

               END
               ELSE
               BEGIN
                  UPDATE dbo.PackDetail WITH (ROWLOCK)
                     SET Qty = Qty + @nTote_QTY 
                  WHERE PickSlipNo = @cPickSlipNo               
                    AND StorerKey = @cStorerKey               
                    AND SKU = @cSKU               
                    AND LabelNo = @cToTote
                    
               END
               -- insert to Eventlog                
               EXEC RDT.rdt_STD_EventLog                
                  @cActionType   = '4',                
                  @cUserID       = @cUserName,                
                  @nMobileNo     = @nMobile,                
                  @nFunctionID   = @nFunc,                
                  @cFacility     = @cFacility,                
                  @cStorerKey    = @cStorerkey,                
                  @nQty          = @nTote_QTY,  -- (james04)                
                  @cRefNo1       = @cToTote,              
                  @cRefNo2       = @cConsigneekey   -- (james07)              
                             
            END              
         END                
          
         IF @@ERROR <> 0                
         BEGIN                
            ROLLBACK TRAN                
             
            CLOSE CUR_TOTE                
            DEALLOCATE CUR_TOTE                
            SET @nErrNo = 69825                
            SET @cErrMsg = rdt.rdtgetmessage( 69825, @cLangCode, 'DSP') --INS PADET FAIL                               
            GOTO Quit                  
         END                

         FETCH NEXT FROM CUR_TOTE INTO @cOrderKey, @cSKU, @nTote_QTY                
      END                
      CLOSE CUR_TOTE                
      DEALLOCATE CUR_TOTE                
        
      -- (Vicky03) - Pack Confirmation - Start              
      DECLARE Cursor_PackConf CURSOR LOCAL READ_ONLY FAST_FORWARD FOR          
      SELECT DISTINCT O.OrderKey              
      FROM PackDetail PD WITH (NOLOCK)    
      JOIN PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo  
      JOIN ORDERS o (NOLOCK) ON o.OrderKey = PH.OrderKey   
      WHERE  O.StorerKey = @cStorerKey                
         AND PD.DropID = @cToTote                
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
                   
               SET @nErrNo = 69863                
               SET @cErrMsg = rdt.rdtgetmessage( 69863, @cLangCode, 'DSP') --'Upd PaHdr Fail'                
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

   
   -- Delete WCS Routing when Tote is consolidated (Start) (ChewKP01)
   
   IF NOT EXISTS (SELECT 1 FROM dbo.PACKDETAIL WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                  AND StorerKey = @cStorerKey
                  AND DropID = @cFromTote   )
   BEGIN                  
      
      EXEC [dbo].[nspInsertWCSRouting]          
          @cStorerKey               
         ,@cFacility                
         ,@cFromTote                  
         ,'TOTE_CONSO'                
         ,'D'           
         ,''           
         ,@cUserName                
         ,0          
         ,@b_Success          OUTPUT          
         ,@nErrNo             OUTPUT          
         ,@cErrMsg   OUTPUT          
          
      IF @nErrNo <> 0          
      BEGIN          
         ROLLBACK TRAN
         
         SET @nErrNo = @nErrNo          
         SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'          
         
         GOTO QUIT                
      END     
     
   END               
                   
   
   -- Delete WCS Routing when Tote is consolidated (End)   (ChewKP01)
   
--   IF @cStatus = 'F'  
--   BEGIN  
--      -- If To Tote not exists then create it  
--      IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID  = @cToTote)  
--      BEGIN  
--         INSERT INTO dbo.DropID (dropid, droploc, additionalloc, dropidtype, labelprinted, manifestprinted, status , loadkey , pickslipno )  
--         SELECT @cToTote, '' , additionalloc , 'CONSO' , labelprinted, manifestprinted, '0' , loadkey , pickslipno   
--         FROM DropID   
--         WHERE dropid = @cFromTote  
--  
--         IF @@ERROR <> 0  
--         BEGIN  
--            SET @nErrNo = 71020  
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
--            GOTO RollBackTran  
--         END  
--      END  
--      ELSE  
--      BEGIN  
--         -- If merge whole tote and we need to check the uniqueness of child in to tote.  
--         -- If exists in to tote then need to delete from from tote  
--         DELETE FROM D_FROM  
--         FROM dbo.DropIDDetail D_FROM WITH (NOLOCK)   
--         WHERE EXISTS (SELECT 1 FROM dbo.DropIDDetail D_TO WITH (NOLOCK)   
--                       WHERE D_FROM.DropID = D_TO.DropID 
--                         AND D_FROM.ChildID = D_TO.ChildID)   
--         AND D_FROM.DropID = @cFromTote  
--  
--         IF @@ERROR <> 0  
--         BEGIN  
--          SET @nErrNo = 71018  
--          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelDropIDDetFail'  
--          GOTO RollBackTran  
--         END  
--      END  
--  
--      UPDATE PD WITH (ROWLOCK) SET   
--         DropID = CASE WHEN ISNULL(CaseID, '') <> '' THEN DropID ELSE @cToTote END,   
--         ALTSKU = CASE WHEN ISNULL(CaseID, '') <> '' THEN @cToTote ELSE ALTSKU END,  
--         TrafficCop = NULL 
--      FROM dbo.PickDetail PD   
--      JOIN dbo.Orders O ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)   
--      WHERE PD.StorerKey = @cStorerKey  
--         AND O.Status NOT IN ('9', 'CANC')  
--         AND PD.Status = '5'  
--         AND PD.DropID = @cFromTote  
--  
--      -- Update child of DropID to to tote  
--      UPDATE dbo.DropIDDetail WITH (ROWLOCK) 
--         SET DropID = @cToTote  
--      WHERE DropID = @cFromTote  
--    
--      IF @@ERROR <> 0  
--      BEGIN  
--         SET @nErrNo = 71018  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDDetFail'  
--         GOTO RollBackTran  
--      END  
--  
--      -- Close DropID (From Tote)   
--      UPDATE dbo.DropID WITH (ROWLOCK) SET  
--           Status = '9'  
--          ,DropIDType = 'CONSO'  
--          ,DropLoc = ''  
--      WHERE DropID = @cFromTote  
--      --  AND PickSlipNo = @cPickSlipNo  
--           
--      IF @@ERROR <> 0  
--      BEGIN  
--         SET @nErrNo = 71016  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'  
--         GOTO RollBackTran  
--      END  
--     
--      UPDATE dbo.PackDetail WITH (ROWLOCK) SET   
--          DropID = @cToTote  
--      WHERE DropID = @cFromTote  
--        AND PickSlipNo = @cPickSlipNo -- (james01)  
--        
--      IF @@ERROR <> 0  
--      BEGIN  
--         SET @nErrNo = 71017  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
--         GOTO RollBackTran  
--      END  
--   END  -- IF @cStatus = 'F'
--     
--   IF @cStatus = 'P'  
--   BEGIN  
--      UPDATE dbo.DropID WITH (ROWLOCK)  
--      SET DropID = @cToTote   
--         ,Status = 'C'  
--         ,DropIDType = 'CONSO'  
--         ,DropLoc = ''  
--      WHERE DropID = @cFromTote  
--      AND PickSlipNo = @cPickSlipNo  
--  
--      IF @@ERROR <> 0  
--      BEGIN  
--         SET @nErrNo = 71021  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'  
--         GOTO RollBackTran  
--      END  
--  
--      IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cToTote AND ChildID = @cSKU)  
--      BEGIN  
--         INSERT dbo.DropIDDetail (DropID , ChildID)  
--         VALUES ( @cToTote , @cSKU )   
--  
--         IF @@ERROR <> 0  
--         BEGIN  
--            SET @nErrNo = 71022  
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDDetFail'  
--            GOTO RollBackTran  
--         END  
--      END  
--           
--      SELECT @nQTy = ISNULL(SUM(Qty), 0) 
--      FROM dbo.PackDetail WITH (NOLOCK)  
--      WHERE DropID = @cFromTote  
--         AND PickSlipNo = @cPickSlipNo  
--         AND SKU = @cSKU  
--  
--      IF @nQty = @nQtyMV   
--      BEGIN  
--         UPDATE dbo.PackDetail WITH (ROWLOCK)  
--         SET DropID = @cToTote  
--         WHERE DropID = @cFromTote  
--            AND PickSlipNo = @cPickSlipNo  
--            AND SKU = @cSKU  
--  
--         IF @@ERROR <> 0  
--         BEGIN  
--            SET @nErrNo = 71023  
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
--            GOTO RollBackTran  
--         END           
--      END  
--  
--      IF @nQty > @nQtyMV   
--      BEGIN  
--         UPDATE dbo.PackDetail WITH (ROWLOCK)  
--         SET Qty = Qty - @nQtyMV  
--         WHERE DropID = @cFromTote  
--            AND SKU = @cSKU  
--            AND PickSlipNo = @cPickSlipNo  
--  
--         IF @@ERROR <> 0  
--         BEGIN  
--            SET @nErrNo = 71024  
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
--            GOTO RollBackTran  
--         END     
--  
--         SELECT @cRefNo = RefNo  
--         FROM dbo.PackDetail WITH (NOLOCK)  
--         WHERE DropID = @cFromTote  
--            AND PickSlipNo = @cPickSlipNo  
--  
--         INSERT dbo.PackDetail (PickSlipNo, CartonNo, LabelNo, Labelline, Storerkey, SKU, Qty, RefNo, DropID, RefNo2)  
--         VALUES  
--         (@cPickSlipNo, 0, @cToTote, '00000', @cStorerKey, @cSKU, @nQtyMV, @cRefNo, @cToTote, @cFromTote)  
--  
--         IF @@ERROR <> 0  
--         BEGIN  
--            SET @nErrNo = 71025  
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDetFail'  
--            GOTO RollBackTran  
--         END           
--      END  
--   END -- Status=P 
     
   GOTO Quit    
    
   RollBackTran:    
      ROLLBACK TRAN ToteConfirm    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN ToteConfirm    
END    

GO
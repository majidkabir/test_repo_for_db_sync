SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: rdt_Tote_QC_Inquiry_Confirm                         */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Purpose: Comfirm Pick                                                */      
/*                                                                      */      
/* Called from: rdtfnc_Tote_QC_Inquiry                                  */      
/*                                                                      */      
/* Exceed version: 5.4                                                  */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author   Purposes                                    */      
/* 2010-09-28 1.0  ChewKP   Created                                     */      
/* 2015-03-03 1.1  James    Cater for all pickmethod (james01)          */
/************************************************************************/      
CREATE PROC [RDT].[rdt_Tote_QC_Inquiry_Confirm] (    
     @nMobile INT    
    ,@nFunc INT    
    ,@cStorerKey NVARCHAR(15)    
    ,@cUserName NVARCHAR(18)    
    ,@cFacility NVARCHAR(5)    
    ,@cOrderkey NVARCHAR(10)  
    ,@cTaskDetailKey NVARCHAR(10)  
    ,@cSKU NVARCHAR(20)    
    ,@cLOC NVARCHAR(10)    
    ,@cToteNo NVARCHAR(18)    
    ,@nPickQty INT    
    ,@cStatus NVARCHAR(1) -- 4 = Short Pick ; 5 = Picked    
    ,@cLangCode NVARCHAR(3)    
    ,@nErrNo INT OUTPUT    
    ,@cErrMsg NVARCHAR(20) OUTPUT -- screen limitation, 20 char max    
    ,@cPickMethod NVARCHAR(10)=''    
 )        
AS        
BEGIN    
    SET NOCOUNT ON        
    SET QUOTED_IDENTIFIER OFF        
    SET ANSI_NULLS OFF        
    SET CONCAT_NULL_YIELDS_NULL OFF        
        
    DECLARE @b_success             INT    
           ,@n_err                 INT    
           ,@c_errmsg              NVARCHAR(250)    
           ,@nTranCount            INT        
        
    DECLARE    
           @cPickSlipno            NVARCHAR(10)    
           ,@cPickDetailKey        NVARCHAR(10)    
           ,@nQTY_PD               INT    
           ,@cLOT                  NVARCHAR(10)    
           ,@cNewPickDetailKey     NVARCHAR(10)    
           ,@cPDOrderkey           NVARCHAR(10)    
           ,@cPickDetailKeySingle  NVARCHAR(10)   
           ,@cLoadkey              NVARCHAR(10)     
        
    SET @nTranCount = @@TRANCOUNT     
    SET @cLoadkey = ''  
  
--   INSERT INTO TraceInfo (TraceName, TimeIn, [TimeOut], Step1, Col1, Col2, Col3, Col4, Col5)  
--   VALUES ('Tote_QC_Inquiry_Confirm', GETDATE(), GETDATE(), @cTaskDetailKey, @cOrderkey, @cSKU, @cLOC,   
--           @cToteNo, @nPickQty)  
        
        
    BEGIN TRAN     
    SAVE TRAN Picking_ConfirmTask        
  
    IF @cStatus = '4' AND  
       @nPickQty = 0 AND   
       --@cPickMethod IN ('SINGLES','DOUBLES','MULTIS','PIECE')     
       (@cPickMethod LIKE 'SINGLES%' OR @cPickMethod LIKE 'DOUBLES%' OR @cPickMethod LIKE 'MULTIS%' OR @cPickMethod = 'PIECE')            
    BEGIN  
       UPDATE PICKDETAIL   
         SET Qty = 0, Status = '4'   
       WHERE OrderKey = @cOrderKey   
       AND   TaskDetailKey = @cTaskDetailKey  
       AND   SKU = @cSKU   
       AND   StorerKey = @cStorerKey   
       AND   LOC = @cLOC   
       
       IF @@ERROR<>0    
       BEGIN    
          ROLLBACK TRAN        
          SET @nErrNo = 71241        
          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- UpdPickDetailFail        
          GOTO RollBackTran    
       END     
  
  
       GOTO Quit  
    END   
            
    SET @cPickSlipno = ''        
    SELECT @cPickSlipno = PickheaderKey    
    FROM   dbo.PickHeader WITH (NOLOCK)    
    WHERE  OrderKey = @cOrderKey -- AND Zone = 'D'        
      
    SELECT @cLoadkey = Loadkey   
    FROM dbo.Orders WITH (NOLOCK)   
    WHERE Orderkey = @cOrderkey  
      
     -- Create Pickheader        
     IF ISNULL(@cPickSlipno ,'')=''    
     BEGIN    
         EXECUTE dbo.nspg_GetKey     
         'PICKSLIP',     
         9,     
         @cPickslipno OUTPUT,     
         @b_success OUTPUT,     
         @n_err OUTPUT,     
         @c_errmsg OUTPUT        
             
         IF @n_err<>0    
         BEGIN    
             ROLLBACK TRAN        
             SET @nErrNo = 71316        
             SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --GetDetKey Fail        
             GOTO RollBackTran    
         END        
             
         SELECT @cPickslipno = 'P'+@cPickslipno        
             
         INSERT INTO dbo.PICKHEADER    
           (    
             PickHeaderKey   ,ExternOrderKey  ,Orderkey    
            ,PickType        ,Zone            ,TrafficCop    
           )    
         VALUES    
           (    
             @cPickslipno    ,@cLoadKey       ,@cOrderKey    
            ,'0'             ,'D'             ,''    
           )        
             
         IF @@ERROR<>0    
         BEGIN    
             ROLLBACK TRAN        
             SET @nErrNo = 71317        
             SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --InstPKHdr Fail        
             GOTO RollBackTran    
         END    
     END --ISNULL(@cPickSlipno, '') = ''        
       
     IF NOT EXISTS (SELECT 1     
                    FROM   dbo.PickingInfo WITH (NOLOCK)    
                    WHERE  PickSlipNo = @cPickSlipNo)    
     BEGIN    
         INSERT INTO dbo.PickingInfo    
           ( PickSlipNo         ,ScanInDate     ,PickerID    
            ,ScanOutDate        ,AddWho)    
         VALUES    
           ( @cPickSlipNo       ,GETDATE()      ,@cUserName    
            ,NULL               ,@cUserName      )        
             
         IF @@ERROR<>0    
         BEGIN    
             ROLLBACK TRAN        
             SET @nErrNo = 71318       
             SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Scan In Fail        
             GOTO RollBackTran    
         END    
     END  
                       
      UPDATE dbo.PICKDETAIL WITH (ROWLOCK)    
      SET    PickSlipNo = @cPickSlipNo    
            ,TrafficCop = NULL    
      WHERE  OrderKey = @cOrderKey         
            
      IF @@ERROR<>0    
      BEGIN    
          ROLLBACK TRAN        
          SET @nErrNo = 71241        
          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- UpdPickDetailFail        
          GOTO RollBackTran    
      END     
            
    -- Confirm PickDetail --    
    --   IF @cPickMethod = 'SINGLES'    
    --   BEGIN    
    --   END -- @cPickMethod = 'SINGLES'        
        
    --**CONFIRM PICKDETAIL (START)**--        
    IF @cStatus='5'    
    BEGIN    
        DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY     
        FOR    
            SELECT PD.PickDetailKey    
                  ,PD.QTY    
                  ,PD.LOT    
                  ,PD.Orderkey    
            FROM   dbo.PickDetail PD WITH (NOLOCK)    
            WHERE  PD.LOC = @cLOC    
            AND    PD.SKU = @cSKU  
            AND    PD.Orderkey = @cOrderkey    
            ORDER BY PD.PickDetailKey    
            
        OPEN CursorPickDetail     
        FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cLOT, @cPDOrderkey             
        WHILE @@FETCH_STATUS<>-1    
        BEGIN    
            IF @nQTY_PD=@nPickQty    
            BEGIN    
                -- Confirm PickDetail     
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET    DropID = @cToteNo    
                      ,STATUS = @cStatus    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71320  
                    SET @cErrMsg = rdt.rdtgetmessage(71320 ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END    
            END    
            ELSE     
            IF @nPickQty>@nQTY_PD    
            BEGIN    
                -- Confirm PickDetail        
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET    DropID = @cToteNo    
                      ,STATUS = '5'    
                      -- ,TaskDetailkey = @cTaskDetailKey (Shong01)    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71321        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END    
            END    
            ELSE     
            IF @nPickQty < @nQTY_PD AND @nPickQty > 0    
            BEGIN    
                EXECUTE dbo.nspg_GetKey     
                'PICKDETAILKEY',     
                10 ,     
                @cNewPickDetailKey OUTPUT,     
                @b_success OUTPUT,     
                @n_err OUTPUT,     
                @c_errmsg OUTPUT        
                    
                IF @b_success<>1    
                BEGIN    
                    SET @nErrNo = 71322        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetDetKeyFail'        
                    GOTO RollBackTran    
                END     
                    
                -- Create a new PickDetail to hold the balance        
                INSERT INTO dbo.PICKDETAIL    
                  (    
                    CaseID                ,PickHeaderKey         ,OrderKey    
                   ,OrderLineNumber       ,LOT                   ,StorerKey    
                   ,SKU                   ,AltSKU                ,UOM    
                   ,UOMQTY                ,QTYMoved              ,STATUS    
                   ,DropID                ,LOC                   ,ID    
                   ,PackKey               ,UpdateSource          ,CartonGroup    
                   ,CartonType            ,ToLoc                 ,DoReplenish    
                   ,ReplenishZone         ,DoCartonize           ,PickMethod    
                   ,WaveKey               ,EffectiveDate         ,ArchiveCop    
                   ,ShipFlag              ,PickSlipNo            ,PickDetailKey    
                   ,QTY                   ,TrafficCop            ,OptimizeCop    
                   ,TaskDetailkey    
                  )    
                SELECT CaseID                   ,PickHeaderKey            ,OrderKey    
                      ,OrderLineNumber          ,Lot                      ,StorerKey    
                      ,SKU                      ,AltSku                   ,UOM    
                      ,UOMQTY                   ,QTYMoved                 ,'0'    
                      ,''                       ,LOC                      ,ID    
                      ,PackKey                  ,UpdateSource             ,CartonGroup    
                      ,CartonType               ,ToLoc                    ,DoReplenish    
                      ,ReplenishZone            ,DoCartonize              ,PickMethod    
                      ,WaveKey                  ,EffectiveDate            ,ArchiveCop    
                      ,ShipFlag                 ,PickSlipNo               ,@cNewPickDetailKey    
                      ,@nQTY_PD- @nPickQty      ,NULL                     ,'1'  --OptimizeCop,    
                      ,TaskDetailkey    
                FROM   dbo.PickDetail WITH (NOLOCK)    
                WHERE  PickDetailKey = @cPickDetailKey        
                   
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71323        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'        
                    GOTO RollBackTran    
                END     
                    
                -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop    
                -- Change orginal PickDetail with exact QTY (with TrafficCop)        
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET    QTY = @nPickQty    
                      ,Trafficcop = NULL    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71324        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END     
                    
                -- Confirm orginal PickDetail with exact QTY        
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET    DropID = @cToteNo    
                      ,STATUS = @cStatus    
                WHERE  PickDetailKey = @cPickDetailKey        
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71325        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END    
            END        
                
            IF @nPickQty>0    
            BEGIN    
                SET @nPickQty = @nPickQty- @nQTY_PD -- OffSet PickQty    
            END      
                
            -- (Shong02)    
--            IF ISNULL(RTRIM(@c_NTaskDetailkey),'') = ''     
--               BREAK    
                
--            IF @nPickQty = 0 --AND @cPickMethod IN ('DOUBLES', 'MULTIS')    
--               BREAK     
            -- (Shong02)    
                
--            IF @nPickQty=0 AND @cPickMethod='SINGLES'    
--            BEGIN    
--                DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD READ_ONLY     
--                FOR    
--                    SELECT PD.PickDetailKey    
--                    FROM   dbo.PickDetail PD WITH (NOLOCK)    
--                    WHERE  PD.StorerKey = @cStorerKey    
--                    AND    PD.LOC = @cLOC    
--                    AND    PD.Status = '0'    
--                    AND    PD.SKU = @cSKU    
--                    ORDER BY PD.PickDetailKey     
--                    
--                OPEN CursorPickDetailSingle     
--                FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle      
--                WHILE @@FETCH_STATUS<>-1    
--                BEGIN    
--                          
--                    UPDATE dbo.PickDetail WITH (ROWLOCK)    
--                    SET    TaskDetailkey = @c_NTaskDetailkey    
--                          ,Trafficcop = NULL -- (Vicky01)    
--                    WHERE  Pickdetailkey = @cPickDetailKeySingle     
--                        
--                    FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle    
--                END     
--                CLOSE CursorPickDetailSingle     
--                DEALLOCATE CursorPickDetailSingle     
--                    
--                BREAK    
--            END    
--            ELSE    
--            BEGIN    
--                --IF @nPickQty = 0 BREAK      
--                IF @nPickQTy=0    
--                BEGIN    
--                    DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD READ_ONLY     
--                    FOR    
--                        SELECT PD.PickDetailKey    
--                        FROM   dbo.PickDetail PD WITH (NOLOCK)    
--                        WHERE  PD.StorerKey = @cStorerKey    
--                        AND    PD.LOC = @cLOC    
--                        AND    PD.Status = '0'    
--                        AND    PD.SKU = @cSKU    
--                        ORDER BY PD.PickDetailKey     
--                        
--                    OPEN CursorPickDetailSingle     
--                    FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle      
--                    WHILE @@FETCH_STATUS<>-1     
--                    BEGIN    
--                          
--                        UPDATE dbo.PickDetail WITH (ROWLOCK)     
--                        SET    TaskDetailkey = @c_NTaskDetailkey     
--                              ,Trafficcop = NULL -- (Vicky01)    
--                        WHERE  Pickdetailkey = @cPickDetailKeySingle     
--                            
--                        FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle    
--                    END     
--                    CLOSE CursorPickDetailSingle     
--                    DEALLOCATE CursorPickDetailSingle     
--                        
--                    BREAK    
--                END    
--            END     
                
            FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cLOT, @cPDOrderkey    
        END -- While Loop for PickDetail Key      
        CLOSE CursorPickDetail     
        DEALLOCATE CursorPickDetail    
    END --  @cStatus = '5'         
        
    IF @cStatus='4' -- OffSet    
    BEGIN    
        DECLARE CursorPickDetailShort  CURSOR LOCAL FAST_FORWARD READ_ONLY     
        FOR    
            SELECT PD.PickDetailKey    
                  ,PD.QTY    
                  ,PD.LOT    
            FROM   dbo.PickDetail PD WITH (NOLOCK)    
            WHERE  PD.StorerKey = @cStorerKey    
            AND    PD.Orderkey = @cOrderkey  
            AND    PD.LOC = @cLOC    
            AND    PD.Status IN ('0','4')     
            AND    PD.SKU = @cSKU    
            ORDER BY    
                   PD.PickDetailKey    
            
        OPEN CursorPickDetailShort     
        FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT                                                                           
        WHILE @@FETCH_STATUS<>-1    
        BEGIN    
            -- Exact match        
            IF @nQTY_PD=@nPickQty    
            BEGIN    
                -- Confirm PickDetail        
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET    DropID = @cToteNo --               Status = @cStatus    
                      ,STATUS = '5'    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71326       
                    SET @cErrMsg = rdt.rdtgetmessage(71326 ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END     
                    
                -- EventLog - QTY         
                EXEC RDT.rdt_STD_EventLog     
                     @cActionType='3' -- Picking    
                    ,@cUserID=@cUserName    
                    ,@nMobileNo=@nMobile    
                    ,@nFunctionID=@nFunc    
                    ,@cFacility=@cFacility    
                    ,@cStorerKey=@cStorerKey    
                    ,@cLocation=@cLoc    
                    --,@cToLocation=@cToLOC    
                    --,@cID=@cID -- Sugg FromID    
                    ,@cToID=@cToteNo -- DropID    
                    ,@cSKU=@cSKU    
                    ,@nQTY=@nQTY_PD    
                    ,@cRefNo1=@cLoadKey    
                    --,@cRefNo2=@cTaskDetailKey    
                    ,@cRefNo3=@cPickMethod    
                    ,@cRefNo4=''    
            END    
            ELSE     
            IF @nPickQty>@nQTY_PD    
            BEGIN    
                -- Confirm PickDetail        
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET    DropID = @cToteNo --               Status = @cStatus    
                      ,STATUS = '5'    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71327        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END     
                    
                    
                -- EventLog - QTY         
                EXEC RDT.rdt_STD_EventLog     
                     @cActionType='3' -- Picking    
                    ,@cUserID=@cUserName    
                    ,@nMobileNo=@nMobile    
                    ,@nFunctionID=@nFunc    
                    ,@cFacility=@cFacility    
                    ,@cStorerKey=@cStorerKey    
                    ,@cLocation=@cLoc    
                    --,@cToLocation=@cToLOC    
                    --,@cID=@cID -- Sugg FromID    
                    ,@cToID=@cToteNo -- DropID    
                    ,@cSKU=@cSKU    
                    ,@nQTY=@nQTY_PD    
                    ,@cRefNo1=@cLoadKey    
                    --,@cRefNo2=@cTaskDetailKey    
                    ,@cRefNo3=@cPickMethod    
                    ,@cRefNo4=''    
            END-- PickDetail have more, need to split    
            ELSE     
            IF @nQTY_PD>@nPickQty AND @nPickQty>0    
            BEGIN    
                -- If Status = '4' (short pick), no need to split line if already last RPL line to update,    
                -- just have to update the pickdetail.qty = short pick qty    
                -- Get new PickDetailkey        
                    
                EXECUTE dbo.nspg_GetKey     
                'PICKDETAILKEY',     
                10 ,     
                @cNewPickDetailKey OUTPUT,     
                @b_success OUTPUT,     
                @n_err OUTPUT,     
                @c_errmsg OUTPUT        
                    
                IF @b_success<>1    
                BEGIN    
                    SET @nErrNo = 71328        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetDetKeyFail'        
                    GOTO RollBackTran    
                END     
                    
                -- Create a new PickDetail to hold the balance        
                INSERT INTO dbo.PICKDETAIL    
                  (    
                    CaseID                ,PickHeaderKey         ,OrderKey    
                   ,OrderLineNumber       ,LOT                   ,StorerKey    
                   ,SKU                   ,AltSKU                ,UOM    
                   ,UOMQTY                ,QTYMoved              ,STATUS    
                   ,DropID                ,LOC                   ,ID    
                   ,PackKey               ,UpdateSource          ,CartonGroup    
                   ,CartonType            ,ToLoc                 ,DoReplenish    
                   ,ReplenishZone         ,DoCartonize           ,PickMethod    
                   ,WaveKey               ,EffectiveDate         ,ArchiveCop    
                   ,ShipFlag              ,PickSlipNo            ,PickDetailKey    
                   ,QTY                   ,TrafficCop            ,OptimizeCop    
                   ,TaskDetailkey    
                  )    
                SELECT CaseID                ,PickHeaderKey            ,OrderKey    
                      ,OrderLineNumber       ,Lot                      ,StorerKey    
                      ,SKU                   ,AltSku                   ,UOM    
                      ,UOMQTY                ,QTYMoved                 ,'4'    
                      ,DropID                ,LOC                      ,ID    
                      ,PackKey               ,UpdateSource             ,CartonGroup    
                      ,CartonType            ,ToLoc                    ,DoReplenish    
                      ,ReplenishZone         ,DoCartonize              ,PickMethod    
                      ,WaveKey               ,EffectiveDate            ,ArchiveCop    
                      ,ShipFlag              ,PickSlipNo               ,@cNewPickDetailKey    
                      ,@nQTY_PD- @nPickQty   ,NULL                     ,'1'     
                      ,TaskDetailKey    
                FROM   dbo.PickDetail WITH (NOLOCK)    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71329        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'        
                    GOTO RollBackTran    
                END     
                    
                -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop    
                -- Change orginal PickDetail with exact QTY (with TrafficCop)        
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET    QTY = @nPickQty    
                      ,Trafficcop = NULL    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71330        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END     
                    
                -- Confirm orginal PickDetail with exact QTY        
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET    DropID = @cToteNo    
                      ,STATUS = '5'    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71331        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END     
                    
                -- EventLog - QTY         
                EXEC RDT.rdt_STD_EventLog     
                     @cActionType='3' -- Picking    
                    ,@cUserID=@cUserName    
                    ,@nMobileNo=@nMobile    
                    ,@nFunctionID=@nFunc    
                    ,@cFacility=@cFacility    
                    ,@cStorerKey=@cStorerKey    
                    ,@cLocation=@cLoc    
                    --,@cToLocation=@cToLOC    
                    --,@cID=@cID -- Sugg FromID    
                    ,@cToID=@cToteNo -- DropID    
                    ,@cSKU=@cSKU    
                    ,@nQTY=@nQTY_PD    
                    ,@cRefNo1=@cLoadKey    
                    --,@cRefNo2=@cTaskDetailKey    
                    ,@cRefNo3=@cPickMethod    
                    ,@cRefNo4=''    
            END        
                
            IF @nPickQty>0    
            BEGIN    
                SET @nPickQty = @nPickQty- @nQTY_PD -- OffSet PickQty    
            END      
                
            IF @nPickQty=0  AND @cPickMethod='SINGLES'    
            BEGIN    
                DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD     
                        READ_ONLY     
                FOR    
                    SELECT PD.PickDetailKey    
                    FROM   dbo.PickDetail PD WITH (NOLOCK)    
                    WHERE  PD.StorerKey = @cStorerKey    
                    AND    PD.Orderkey = @cOrderkey  
                    AND    PD.LOC = @cLOC    
                    AND    PD.Status = '0'    
                    AND    PD.SKU = @cSKU    
                    ORDER BY    
                           PD.PickDetailKey     
         
                OPEN CursorPickDetailSingle     
                FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle      
                WHILE @@FETCH_STATUS<>-1    
                BEGIN    
                    UPDATE dbo.PickDetail WITH (ROWLOCK)    
                    SET    STATUS = '4', TrafficCop=NULL, EditWho=sUser_sName(), EditDate=GETDATE()    
                    WHERE  Pickdetailkey = @cPickDetailKeySingle     
                        
                    FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle    
                END     
                CLOSE CursorPickDetailSingle     
                DEALLOCATE CursorPickDetailSingle     
                    
                BREAK    
            END    
            ELSE    
            BEGIN    
                IF @nPickQty=0    
                BEGIN    
                    DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD     
                            READ_ONLY     
                    FOR    
                        SELECT PD.PickDetailKey    
                        FROM   dbo.PickDetail PD WITH (NOLOCK)    
                        WHERE  PD.StorerKey = @cStorerKey   
                        AND    PD.Orderkey = @cOrderkey   
                        AND    PD.LOC = @cLOC    
                        AND    PD.Status = '0'    
                        AND    PD.SKU = @cSKU    
                        ORDER BY    
                               PD.PickDetailKey     
                        
                    OPEN CursorPickDetailSingle     
                    FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle      
                    WHILE @@FETCH_STATUS<>-1    
                    BEGIN    
                        UPDATE dbo.PickDetail WITH (ROWLOCK)    
                        SET    STATUS = '4', TrafficCop=NULL, EditWho=sUser_sName(), EditDate=GETDATE()    
                        WHERE  Pickdetailkey = @cPickDetailKeySingle     
                            
                        FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle    
                    END     
                    CLOSE CursorPickDetailSingle     
                    DEALLOCATE CursorPickDetailSingle     
                        
                    BREAK    
                END    
          END                 
                
            FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD,     
            @cLOT    
        END     
        CLOSE CursorPickDetailShort     
        DEALLOCATE CursorPickDetailShort    
    END     
  
        
    GOTO Quit     
        
    RollBackTran:     
    ROLLBACK TRAN Picking_ConfirmTask     
        
    Quit:  
      
    IF ISNULL(RTRIM(@cTaskDetailKey),'') <> ''   
    BEGIN  
       UPDATE TASKDETAIL    
         SET Status = '9', TrafficCop = NULL    
       WHERE OrderKey = @cOrderKey   
       AND   TaskDetailKey = @cTaskDetailKey   
       AND   SKU = @cSKU   
       AND   StorerKey = @cStorerKey   
       AND   TaskType = 'PK'  
       IF @@ERROR<>0    
       BEGIN    
          ROLLBACK TRAN        
          SET @nErrNo = 71241        
          SET @cErrMsg = '71241^UpdTaskDetFail'   
          -- rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 71241^UpdTaskDetFail        
          -- GOTO RollBackTran    
       END            
    END  
            
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started        
          COMMIT TRAN Picking_ConfirmTask    
END        

GO
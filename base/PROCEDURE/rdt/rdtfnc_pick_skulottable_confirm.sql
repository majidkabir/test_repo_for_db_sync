SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/      
/* Store procedure: rdtfnc_Pick_SKULottable_Confirm                           */      
/* Copyright      : IDS                                                       */      
/*                                                                            */      
/* Purpose: Comfirm Pick                                                      */      
/*                                                                            */      
/* Called from: rdtfnc_Pick_SKULottable                                       */      
/*                                                                            */      
/* Exceed version: 5.4                                                        */      
/*                                                                            */      
/* Modifications log:                                                         */      
/*                                                                            */      
/* Date       Rev  Author   Purposes                                          */      
/* 2010-10-15 1.0  ChewKP   Created                                           */   
/* 2017-01-25 1.3  Ung      WMS-1000 Temporary modify for urgent release      */   
/******************************************************************************/      
      
CREATE PROC [RDT].[rdtfnc_Pick_SKULottable_Confirm] (    
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5) , 
   @cStorerKey   NVARCHAR( 15), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cSKU         NVARCHAR( 20), 
   @cLottable01  NVARCHAR( 18), 
   @cLottable02  NVARCHAR( 18), 
   @cLottable03  NVARCHAR( 18), 
   @dLottable04  DATETIME,
   @nPickQTY     INT,           
   @cStatus      NVARCHAR(1),   
   @nErrNo       INT           OUTPUT, 
   @cErrMsg      NVARCHAR(250) OUTPUT 
 )        
AS        
BEGIN    
    SET NOCOUNT ON        
    SET QUOTED_IDENTIFIER OFF        
    SET ANSI_NULLS OFF        
    SET CONCAT_NULL_YIELDS_NULL OFF        
    
    DECLARE @cSQL       NVARCHAR( MAX)
    DECLARE @cSQLParam  NVARCHAR( MAX)

    DECLARE @cConfirmSP NVARCHAR(20)
    SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey) 
    IF @cConfirmSP = '0'
      SET @cConfirmSP = ''
    
   /***********************************************************************************************
                                              Custom get task
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cConfirmSP <> ''
   BEGIN
      -- Confirm SP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cPickSlipNo, @cLOC, @cDropID, @cSKU, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @nQTY, @cType, @nErrNo OUTPUT, @cErrMsg OUTPUT '
      SET @cSQLParam =
         ' @nMobile      INT,           ' + 
         ' @nFunc        INT,           ' + 
         ' @cLangCode    NVARCHAR( 3),  ' + 
         ' @nStep        INT,           ' + 
         ' @nInputKey    INT,           ' + 
         ' @cFacility    NVARCHAR( 5) , ' + 
         ' @cStorerKey   NVARCHAR( 15), ' + 
         ' @cPickSlipNo  NVARCHAR( 10), ' + 
         ' @cLOC         NVARCHAR( 10), ' + 
         ' @cDropID      NVARCHAR( 20), ' + 
         ' @cSKU         NVARCHAR( 20), ' + 
         ' @cLottable01  NVARCHAR( 18), ' + 
         ' @cLottable02  NVARCHAR( 18), ' + 
         ' @cLottable03  NVARCHAR( 18), ' + 
         ' @dLottable04  DATETIME,      ' + 
         ' @nQTY         INT,           ' + 
         ' @cType        NVARCHAR(1),   ' + 
         ' @nErrNo       INT           OUTPUT, ' + 
         ' @cErrMsg      NVARCHAR(250) OUTPUT  ' 
   
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cPickSlipNo, @cLOC, @cDropID, @cSKU, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @nPickQTY, @cStatus, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
      GOTO Quit
   END

   /***********************************************************************************************
                                              Standard get task
   ***********************************************************************************************/
    DECLARE @b_success             INT    
           ,@n_err                 INT    
           ,@c_errmsg              NVARCHAR(250)    
           ,@nTranCount            INT        
        
    DECLARE    
            @cPickDetailKey        NVARCHAR(10)    
           ,@nQTY_PD               INT    
           ,@cLOT                  NVARCHAR(10)    
           ,@cNewPickDetailKey     NVARCHAR(10)    
           ,@cPDOrderkey           NVARCHAR(10)    
           ,@cPickDetailKeySingle  NVARCHAR(10)   
           ,@cOrderKey             NVARCHAR(10)   
           
   -- Get Pick slip info
   SELECT @cOrderKey = OrderKey FROM PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo
        
    SET @nTranCount = @@TRANCOUNT     
    BEGIN TRAN     
    SAVE TRAN Picking_ConfirmTask        
  
      
       
     IF NOT EXISTS (SELECT 1     
                    FROM   dbo.PickingInfo WITH (NOLOCK)    
                    WHERE  PickSlipNo = @cPickSlipNo)    
     BEGIN    
         INSERT INTO dbo.PickingInfo    
           ( PickSlipNo         ,ScanInDate     ,PickerID    
            ,ScanOutDate        ,AddWho)    
         VALUES    
           ( @cPickSlipNo       ,GETDATE()      ,SUSER_SNAME()    
            ,NULL               ,SUSER_SNAME())        
             
         IF @@ERROR<>0    
         BEGIN    
             ROLLBACK TRAN        
             SET @nErrNo = 71516       
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
          SET @nErrNo = 71517        
          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- UpdPickDetailFail        
          GOTO RollBackTran    
      END     
            
    -- Confirm PickDetail --    
        
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
                SET   STATUS = @cStatus    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71518  
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END    
            END    
            ELSE     
            IF @nPickQty>@nQTY_PD    
            BEGIN    
                -- Confirm PickDetail        
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET   STATUS = '5'    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71519        
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
                    SET @nErrNo = 71520        
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
                    SET @nErrNo = 71521        
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
                    SET @nErrNo = 71522        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END     
                    
                -- Confirm orginal PickDetail with exact QTY        
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET   STATUS = @cStatus    
                WHERE  PickDetailKey = @cPickDetailKey        
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71523        
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
                SET  STATUS = '5'    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71524    
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END     
                    
                -- EventLog - QTY         
               DECLARE @cUserName NVARCHAR(18)
               SET @cUserName = LEFT( SUSER_SNAME(), 15)

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
                    --,@cToID=@cToteNo -- DropID    
                    ,@cSKU=@cSKU    
                    ,@nQTY=@nQTY_PD    
                    --,@cRefNo1=@cLoadKey    
                    --,@cRefNo2=@cTaskDetailKey    
                    --,@cRefNo3=@cPickMethod    
                    ,@cRefNo4=''    
            END    
            ELSE     
            IF @nPickQty>@nQTY_PD    
            BEGIN    
                -- Confirm PickDetail        
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET    STATUS = '5'    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71525        
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
                    --,@cToID=@cToteNo -- DropID    
                    ,@cSKU=@cSKU    
                    ,@nQTY=@nQTY_PD    
                    --,@cRefNo1=@cLoadKey    
                    --,@cRefNo2=@cTaskDetailKey    
                    --,@cRefNo3=@cPickMethod    
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
                    SET @nErrNo = 71526        
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
                    SET @nErrNo = 71527        
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
                    SET @nErrNo = 71528        
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'        
                    GOTO RollBackTran    
                END     
                    
                -- Confirm orginal PickDetail with exact QTY        
                UPDATE dbo.PickDetail WITH (ROWLOCK)    
                SET    STATUS = '5'    
                WHERE  PickDetailKey = @cPickDetailKey        
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = 71529        
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
                    --,@cToID=@cToteNo -- DropID    
                    ,@cSKU=@cSKU    
                    ,@nQTY=@nQTY_PD    
                    --,@cRefNo1=@cLoadKey    
                    --,@cRefNo2=@cTaskDetailKey    
                    --,@cRefNo3=@cPickMethod    
                    ,@cRefNo4=''    
            END        
                
            IF @nPickQty>0    
            BEGIN    
                SET @nPickQty = @nPickQty- @nQTY_PD -- OffSet PickQty    
            END      
                
          
             
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
      
            
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started        
          COMMIT TRAN Picking_ConfirmTask    
END        


GO
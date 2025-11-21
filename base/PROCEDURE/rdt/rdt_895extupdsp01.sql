SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_895ExtUpdSP01                                   */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Replenishment Extended Update                               */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2014-06-17  1.0  ChewKP   SOS#342435 Created                         */    
/* 2015-10-02  1.1  ChewKP   SOS#353787 Add StorerConfig WaveDPPConfirm */
/*                           (ChewKP01)                                 */
/* 2017-01-16  1.2  ChewKP   WMS-935 - Add Generate PackInfo (ChewKP02) */
/* 2017-08-04  1.3  ChewKP   WMS-2428- Add Carton Count Screen(ChewKP03)*/
/* 2017-10-25  1.4  ChewKP   WMS-3291- Changes for FCS (ChewKP04)       */
/* 2020-08-27  1.5  James    WMS-14885. Trigger TL3 after confirm replen*/
/*                           and replenno = 'FCS' (james01)             */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_895ExtUpdSP01] (    
  @nMobile        INT, 
  @nFunc          INT, 
  @nStep          INT,
  @cLangCode      NVARCHAR( 3),  
  @cUserName      NVARCHAR( 18), 
  @cFacility      NVARCHAR( 5),  
  @cStorerKey     NVARCHAR( 15), 
  @cWaveKey       NVARCHAR( 10), 
  @cPutawayZone   NVARCHAR( 10), 
  @cActToLOC      NVARCHAR( 10), 
  @cSKU           NVARCHAR( 20), 
  @cLabelNo       NVARCHAR( 20), 
  @nQTY           INT,
  @cReplenKey     NVARCHAR(10), 
  @nErrNo         INT           OUTPUT, 
  @cErrMsg        NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
  
   DECLARE @nTranCount        INT  
          --,@cReplenKey        NVARCHAR(10)
          ,@nQtyMoved         INT
          ,@cDropID           NVARCHAR(20)
          --,@cSKU              NVARCHAR(20)
          ,@cLot              NVARCHAR(10)
          ,@cID               NVARCHAR(18)
          ,@cToLoc            NVARCHAR(10)
          ,@cUOM              NVARCHAR(10) 
          ,@cPickDetailKey    NVARCHAR(10)
          ,@nPickDetailQty    INT
          ,@cFromLoc          NVARCHAR(10) 
          ,@cRefNo            NVARCHAR(20) 
          ,@cOrderKey         NVARCHAR(10)
          ,@cLocationType     NVARCHAR(10)
          ,@cPickslipno       NVARCHAR(10)
          ,@bsuccess          INT
          ,@nSUM_PackQTY      INT
          ,@nSUM_PickQTY      INT
          --,@cLabelNo          NVARCHAR(20) 
          ,@nCartonNo         INT
          ,@cLabelLine        NVARCHAR(5) 
          ,@cRefNo2           NVARCHAR(30) 
          ,@nRowRef           INT
          ,@nQTY_PD           INT
          ,@cNewPickDetailKey NVARCHAR(10)
          ,@nReplenQty        INT
          ,@cNotMoveReplenToLoc NVARCHAR(1) 
          ,@cCombineKey        NVARCHAR(10)
          ,@cOrderType        NVARCHAR(10)
          ,@cNotConfirmDPPReplen NVARCHAR(1)
          ,@cSuggSKU          NVARCHAR(20)
          ,@cGenPackInfo      NVARCHAR(1) -- (ChewKP02) 
          ,@nPackCtnNo        INT   -- (ChewKP02)
          ,@nSumCartonQty     INT   -- (ChewKP02)
          ,@fWeight           FLOAT -- (ChewKP02) 
          ,@fCube             FLOAT -- (ChewKP02)
          ,@fLength           FLOAT -- (ChewKP02)
          ,@fWidth            FLOAT -- (ChewKP02)
          ,@fHeight           FLOAT -- (ChewKP02)
     
     
   SET @nErrNo    = 0    
   SET @cErrMsg   = ''   
   --SET @cReplenKey = ''
   SET @nQtyMoved = 0
   SET @cDropID   = ''
   
   SET @cLot      = ''
   SET @cID       = ''
   SET @cToLoc    = ''
   SET @cUOM      = ''
   SET @cPickDetailKey = '' 
   SET @cFromLoc  = ''
   SET @cRefNo    = ''
   SET @cOrderKey = ''
   SET @cLocationType = ''
   SET @cPickslipno = ''
   SET @bsuccess = 0
   SET @nSUM_PackQTY = 0
   SET @nSUM_PickQTY = 0
   --SET @cLabelNo = ''
   SET @nCartonNo = 0 
   SET @cLabelLine = ''
   SET @cRefNo2 = ''
   SET @cNewPickDetailKey = ''
   SET @nQTY_PD = ''
   SET @nReplenQty = ''
   SET @cNotMoveReplenToLoc = ''
   SET @cCombineKey  = ''
   
   -- (ChewKP01) 
   SET @cNotConfirmDPPReplen = rdt.RDTGetConfig( @nFunc, 'NotConfirmDPPReplen', @cStorerKey)  
   IF @cNotConfirmDPPReplen = '0'  
   BEGIN  
      SET @cNotConfirmDPPReplen = ''  
   END  
   
   -- (ChewKP02) 
   SET @cGenPackInfo = rdt.RDTGetConfig( @nFunc, 'GeneratePackInfo', @cStorerKey)  
   IF @cGenPackInfo = '0'  
   BEGIN  
      SET @cNotConfirmDPPReplen = ''  
   END  
     
   SET @nTranCount = @@TRANCOUNT  
     
   BEGIN TRAN  
   SAVE TRAN rdt_895ExtUpdSP01  
   
   IF @nFunc = 895 
   BEGIN


      IF @nStep = 5
      BEGIN
--         SELECT @cReplenKey = V_String18
--         FROM rdt.rdtMobrec WITH (NOLOCK)
--         WHERE Mobile = @nMobile 
         
         
         IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                     WHERE WaveKey = @cWaveKey
                     AND RefNo = @cLabelNo
                     AND Confirmed = 'N')
         BEGIN
            UPDATE rdt.rdtReplenishmentLog
            SET  Confirmed = '1' -- In Progress
               , QtyMoved  = Qty
               , DropID    = @cLabelNo
            WHERE WaveKey = @cWaveKey
            AND RefNo = @cLabelNo
            
            IF @@ERROR <> 0 
            BEGIN 
                  SET @nErrNo = 93860
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRPLogFail
                  GOTO RollBackTran
            END
         END
         ELSE
         BEGIN         
            --INSERT INTO TRACEINFO ( TraceName , TimeIN , Col1, col2 , Col3 ) 
            --VALUES ( '895' , Getdate() , @cReplenKey , '' , ''  ) 

            IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                        WHERE WaveKey = @cWaveKey
                        AND StorerKey = @cStorerKey
                        AND ReplenNo = 'RPL-COMBCA'
                        AND Confirmed = 'N' 
                        AND ReplenishmentKey = @cReplenKey) 
            BEGIN
               
               SELECT  @cCombineKey = RefNo
               FROM rdt.rdtReplenishmentLog WITH (NOLOCK) 
               WHERE WaveKey = @cWaveKey
               AND StorerKey = @cStorerKey
                 AND ReplenNo = 'RPL-COMBCA'
                 AND Confirmed = 'N' 
                 AND ReplenishmentKey = @cReplenKey
               
               -- Update rdt.rdtReplenishmentLog
               UPDATE rdt.rdtReplenishmentLog
               SET  Confirmed = '1' -- In Progress
                  , QtyMoved  = Qty
                  , DropID    = @cLabelNo
               WHERE WaveKey = @cWaveKey
                 AND ReplenNo = 'RPL-COMBCA'
                 AND Confirmed = 'N' 
                 AND StorerKey = @cStorerKey
                 AND @cCombineKey = RefNo 
               
               IF @@ERROR <> 0 
               BEGIN 
                     SET @nErrNo = 93870
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRPLogFail
                     GOTO RollBackTran
               END
               
            END
            ELSE
            BEGIN            
            
               -- Update rdt.rdtReplenishmentLog
               UPDATE rdt.rdtReplenishmentLog
               SET  Confirmed = '1' -- In Progress
                  , QtyMoved  = @nQTY
                  , DropID    = @cLabelNo
               WHERE ReplenishmentKey = @cReplenKey
               
               IF @@ERROR <> 0 
               BEGIN 
                     SET @nErrNo = 93859
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRPLogFail
                     GOTO RollBackTran
               END
            END
         END
      END
      
      IF @nStep = 6
      BEGIN       
         
         SET @cNotMoveReplenToLoc = rdt.RDTGetConfig( @nFunc, 'NotMoveReplenToLoc', @cStorerKey)  
         IF @cNotMoveReplenToLoc = '0'  
         BEGIN  
              SET @cNotMoveReplenToLoc = ''  
         END  
         
         SET @cReplenKey = ''
         SET @cLabelNo = ''
         SET @cSKU     = ''
         
         -- Loop All Records and Confirm Replenishment
         DECLARE CursorReplen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
      
         SELECT ReplenishmentKey, QtyMoved, DropID, SKU, Lot, ID, ToLoc, UOM, RefNo, FromLoc, RowRef
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
         WHERE WaveKey = @cWaveKey
         AND StorerKey = @cStorerKey
         AND AddWho = @cUserName
         AND Confirmed = '1'
         AND ToLoc = @cActToLOC
         ORDER BY ReplenishmentKey
         
         
         OPEN CursorReplen            
         
         FETCH NEXT FROM CursorReplen INTO @cReplenKey, @nQtyMoved, @cDropID, @cSKU, @cLot, @cID, @cToLoc, @cUOM, @cRefNo, @cFromLoc, @nRowRef
         
         
         WHILE @@FETCH_STATUS <> -1     
         BEGIN
            -- IF Not Exists in Replenishment table Next Record 
            IF NOT EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey 
                           AND WaveKey = @cWaveKey
                           AND ReplenishmentKey = @cReplenKey)
            BEGIN
               
               IF @cNotConfirmDPPReplen = '1' 
               BEGIN
                  Update rdt.rdtReplenishmentLog WITH (ROWLOCK) 
                  SET Confirmed = 'VERIFIED' 
                     ,ArchiveCop = NULL
                  WHERE RowRef = @nRowRef
               END
               ELSE
               BEGIN
                  Update rdt.rdtReplenishmentLog WITH (ROWLOCK) 
                  SET Confirmed = 'Y'
                  WHERE RowRef = @nRowRef
               END
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 93871
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdReplenLogFail'
                  GOTO RollBackTran
               END
               
               FETCH NEXT FROM CursorReplen INTO @cReplenKey, @nQtyMoved, @cDropID, @cSKU, @cLot, @cID, @cToLoc, @cUOM, @cRefNo, @cFromLoc, @nRowRef
            END
            
            SELECT @cLocationType = LocationType
            FROM dbo.Loc WITH (NOLOCK)
            WHERE Loc = @cToLoc
            AND Facility = @cFacility

            SET @nReplenQty = @nQtyMoved
            -- Generate PackDetail when ToLoc <> DPP and UOM = 2 
            IF @cLocationType NOT IN (  'DYNPPICK', 'RPLSORT' )  AND @cUOM = 'CA' 
            BEGIN
              
               
               -- Split Pickdetail
               DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT  PickDetailKey
                      ,QTY
                      --,LOT
                      ,Orderkey
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                     AND WaveKey = @cWaveKey
                     AND Loc = @cFromLoc
                     AND Lot = @cLot
                     AND SKU = @cSKU
                     AND UOM = CASE WHEN @cUOM = 'CA' THEN '2' ELSE UOM END
                     AND CaseID = ''
                     Order by OrderKey, OrderLineNumber
               
               OPEN CursorPickDetail
               FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cOrderkey
               WHILE @@FETCH_STATUS<>-1
               BEGIN
                 
                   IF @nQTY_PD=@nReplenQty
                   BEGIN
                      -- Confirm PickDetail
                      UPDATE dbo.PickDetail WITH (ROWLOCK)
                      SET    DropID = @cDropID
                            ,CaseID = @cDropID
                            ,STATUS = 5
                      WHERE  PickDetailKey = @cPickDetailKey
               
                      IF @@ERROR <> 0
                      BEGIN
                          SET @nErrNo = 93862
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPickDetFail'
                          GOTO RollBackTran
                      END
               
                 
               
                   END
                   ELSE IF @nReplenQty > @nQTY_PD
                   BEGIN
                      -- Confirm PickDetail
                      UPDATE dbo.PickDetail WITH (ROWLOCK)
                      SET    DropID = @cDropID
                            ,CaseID = @cDropID
                            ,STATUS = '5'
                      WHERE  PickDetailKey = @cPickDetailKey
               
                      IF @@ERROR <> 0
                      BEGIN
                          SET @nErrNo = 93863
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPickDetFail'
                          GOTO RollBackTran
                      END
               
                 
                      
                   END -- IF @nQtyMoved > @nQTY_PD
                   ELSE IF @nReplenQty < @nQTY_PD AND @nReplenQty > 0
                   BEGIN
                      EXECUTE dbo.nspg_GetKey
                               'PICKDETAILKEY',
                               10 ,
                               @cNewPickDetailKey OUTPUT,
                               @bsuccess          OUTPUT,
                               @nErrNo            OUTPUT,
                               @cErrMsg           OUTPUT
               
                      IF @bsuccess <> 1
                      BEGIN
                          SET @nErrNo = 93864
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetDetKeyFail'
                          GOTO RollBackTran
                      END
               
                      -- Create a new PickDetail to hold the balance
                      INSERT INTO dbo.PICKDETAIL
                        (
                          CaseID                  ,PickHeaderKey   ,OrderKey
                         ,OrderLineNumber         ,LOT             ,StorerKey
                         ,SKU                     ,AltSKU          ,UOM
                         ,UOMQTY                  ,QTYMoved        ,STATUS
                         ,DropID                  ,LOC             ,ID
                         ,PackKey                 ,UpdateSource    ,CartonGroup
                         ,CartonType              ,ToLoc           ,DoReplenish
                         ,ReplenishZone           ,DoCartonize     ,PickMethod
                         ,WaveKey                 ,EffectiveDate   ,ArchiveCop
                         ,ShipFlag                ,PickSlipNo      ,PickDetailKey
                         ,QTY                     ,TrafficCop      ,OptimizeCop
                         ,TaskDetailkey
                        )
                      SELECT CaseID               ,PickHeaderKey   ,OrderKey
                            ,OrderLineNumber      ,Lot             ,StorerKey
                            ,SKU                  ,AltSku          ,UOM
                            ,UOMQTY               ,QTYMoved        ,'0'
                            ,''                   ,LOC             ,ID
                            ,PackKey              ,UpdateSource    ,CartonGroup
                            ,CartonType           ,ToLoc           ,DoReplenish
                            ,ReplenishZone        ,DoCartonize     ,PickMethod
                            ,WaveKey              ,EffectiveDate   ,ArchiveCop
                            ,ShipFlag             ,PickSlipNo      ,@cNewPickDetailKey
                            ,@nQTY_PD - @nReplenQty ,NULL            ,'1'  --OptimizeCop,
                            ,TaskDetailkey
                      FROM   dbo.PickDetail WITH (NOLOCK)
                      WHERE  PickDetailKey = @cPickDetailKey
               
                      IF @@ERROR <> 0
                      BEGIN
                          SET @nErrNo = 93865
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'
                          GOTO RollBackTran
                      END
               
                      -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
                      -- Change orginal PickDetail with exact QTY (with TrafficCop)
                      UPDATE dbo.PickDetail WITH (ROWLOCK)
                      SET    QTY = @nReplenQty
                            ,Trafficcop = NULL
                      WHERE  PickDetailKey = @cPickDetailKey
               
                      IF @@ERROR <> 0
                      BEGIN
                          SET @nErrNo = 93866
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPickDetFail'
                          GOTO RollBackTran
                      END
               
                      -- Confirm orginal PickDetail with exact QTY
                      UPDATE dbo.PickDetail WITH (ROWLOCK)
                      SET    DropID = @cDropID
                            ,CaseID = @cDropID
                            ,STATUS = '5'
                      WHERE  PickDetailKey = @cPickDetailKey
                      IF @@ERROR <> 0
                      BEGIN                      
                          SET @nErrNo = 93867
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPickDetFail'
                          GOTO RollBackTran
                      END
               
               
                   END  -- IF @nQtyMoved < @nQTY_PD AND @nQtyMoved > 0
                   
                        
               
                   IF @nReplenQty > 0
                   BEGIN
                       SET @nReplenQty = @nReplenQty- @nQTY_PD 
                       
                       
                       
                       IF @nReplenQty < 0 		
                       		SET @nReplenQty = 0	
                   END
                   ELSE IF @nReplenQty <= 0 
                   BEGIN
                     BREAK
                   END
                   
                   
               
                   FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cOrderkey
               END -- While Loop for PickDetail Key
               CLOSE CursorPickDetail
               DEALLOCATE CursorPickDetail
               
               IF ISNULL(RTRIM(@cNotMoveReplenToLoc),'')  <> '1' 
               BEGIN
   --               -- Actual Move of the Allocated Qty --
                  EXECUTE rdt.rdt_Move
                     @nMobile     = @nMobile,
                     @cLangCode   = @cLangCode,
                     @nErrNo      = @nErrNo  OUTPUT,
                     @cErrMsg     = @cErrMsg OUTPUT, 
                     @cSourceType = 'rdt_895ExtUpdSP01',
                     @cStorerKey  = @cStorerKey,
                     @cFacility   = @cFacility,
                     @cFromLOC    = @cFromLOC,
                     @cToLOC      = @cActToLOC,
                     @cFromID     = @cID,     
                     @cToID       = @cID,       
                     @cSKU        = @cSKU,
                     @nQTY        = @nQtyMoved,
                     @nQTYAlloc   = 0,
                     @nQTYPick    = @nQtyMoved, 
                     @nFunc       = @nFunc, 
                     @cDropID     = @cDropID
               
                  IF @nErrNo <> 0 
                  BEGIN
                         
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                        GOTO RollBackTran    
                  END
               END

                SET @cOrderkey = ''
                
                SELECT @cOrderKey = OrderKey FROM dbo.PickDetail WITH (NOLOCK)
                WHERE StorerKey = @cStorerKey
                AND DropID = @cDropID
                
                IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Orderkey = @cOrderkey)    
                BEGIN 
                   
                   
                   SELECT @cPickSlipNo = PickHeaderKey 
                   FROM dbo.PickHeader WITH (NOLOCK) 
                   WHERE OrderKey = @cOrderKey 
                   
                   
                   INSERT INTO dbo.PackHeader (OrderKey, StorerKey, PickSlipNo, AddWho, AddDate, EditWho, EditDate)     
                                       VALUES (@cOrderKey, @cStorerKEy, @cPickSlipNo,  sUser_sName(), Getdate(),  sUser_sName() , GetDate() )
                              
                   IF @@ERROR <> 0    
                   BEGIN    
                      SET @nErrNo = 93854    
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'    
                      GOTO RollBackTran    
                   END    
                   
                     
                END
                ELSE
                BEGIN
                   
                   SELECT @cPickSlipNo = PickSlipNo 
                   FROM dbo.PackHeader WITH (NOLOCK)
                   WHERE OrderKey = @cOrderKey
                   AND StorerKey = @cStorerKey 
                   
                END
                
                 
                SELECT @nSUM_PackQTY = 0, @nSUM_PickQTY = 0    
                
                
                SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)     
                FROM dbo.PackDetail PD WITH (NOLOCK)     
                WHERE PD.StorerKey = @cStorerKey    
                   AND PD.PickSlipNo = @cPickSlipNo  
                  
                SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)     
                FROM dbo.PickDetail PD WITH (NOLOCK)    
                WHERE PD.StorerKey = @cStorerKey    
                  AND PD.OrderKey = @cOrderKey
                
                
                IF @nSUM_PackQTY = @nSUM_PickQTY    
                BEGIN              
                   SET @nErrNo = 93855              
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PackCompleted              
                   GOTO RollBackTran                
                END    
                
                
                
                /****************************    
                 PACKDETAIL    
                ****************************/    
                SET @cLabelNo = 0     
                SET @nCartonNo = 0    
                 
                 
                IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)         
                                WHERE PickSlipNo = @cPickSlipNo
                                  AND DropID     = @cDropID )   
                BEGIN  
                   
                   SELECT Top 1 @cOrderType = O.Type 
                   FROM dbo.Orders O WITH (NOLOCK) 
                   INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                   WHERE O.StorerKey = @cStorerKey
                   AND O.OrderKey = @cOrderKey
                   AND PD.DropID = @cDropID
                   
                   IF NOT EXISTS ( SELECT 1 FROM dbo.Codelkup WITH (NOLOCK)
                               WHERE ListName = 'UAORGLABEL' 
                               AND Code = @cOrderType ) 
                   BEGIN
                      EXEC isp_GenUCCLabelNo 
                            @cStorerKey ,  
                            @cLabelNo   OUTPUT,   
                            @bsuccess  OUTPUT,  
                            @nErrNo      OUTPUT,  
                            @cErrmsg   OUTPUT  
                                     
                                    
                       
                      IF ISNULL(@cLabelNo,'')  = ''   
                      BEGIN  
                            SET @nErrNo = 93856              
                            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen              
                            GOTO RollBackTran             
                      END  
                   END
                   ELSE
                   BEGIN
                     SET @cLabelNo = @cDropID
                   END
                END
                ELSE
                BEGIN
                   SELECT Top 1 @cLabelNo = LabelNo  
                   FROM dbo.PackDetail WITH (NOLOCK)
                   WHERE PickSlipNo = @cPickSlipNo 
                   AND DropID = @cDropID 
                   
                   
                END    
                
                SET @cLabelLine = '00000'    
                SET @nCartonNo = 0  
                SET @cRefNo2   = ''
                
                SELECT @cRefNo2 = ISNULL(RTRIM(Lottable08),'') 
                FROM dbo.LotAttribute WITH (NOLOCK)
                WHERE Lot = @cLot 
                
                -- Insert PackDetail    
                INSERT INTO dbo.PackDetail    
                   (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, UPC, AddWho, AddDate, EditWho, EditDate, RefNo2)    
                VALUES    
                   (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQtyMoved,    
                    '', @cDropID, '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cRefNo2)    
                
                IF @@ERROR <> 0    
                BEGIN    
                   SET @nErrNo = 93857    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDetFail'    
                   GOTO RollBackTran    
                END    
                ELSE    
                BEGIN    
                   EXEC RDT.rdt_STD_EventLog      
                     @cActionType = '8', -- Packing     
                     @cUserID     = @cUserName,      
                     @nMobileNo   = @nMobile,      
                     @nFunctionID = @nFunc,      
                     @cFacility   = @cFacility,      
                     @cStorerKey  = @cStorerkey,      
                     @cSKU        = @cSKU,    
                     @nQty        = @nQTY_PD,    
                     @cRefNo1     = @cDropID,    
                     @cRefNo2     = @cLabelNo,    
                     @cRefNo3     = @cPickSlipNo     
                END    
                
                IF @cGenPackInfo = '1'
                BEGIN 
                   -- (ChewKP03) -- Add PackInfo 
                   SET @nPackCtnNo    = 0 
                   SET @nSumCartonQty = 0 
                   SET @fWeight       = 0  
                   SET @fCube         = 0
                   SET @fLength       = 0
                   SET @fWidth        = 0
                   SET @fHeight       = 0
                   
                                   
                   SELECT @nPackCtnNo = CartonNo 
                         ,@nSumCartonQty = SUM(Qty) 
                   FROM dbo.PackDetail WITH (NOLOCK) 
                   WHERE PickSlipNo = @cPickSlipNo 
                   AND LabelNo = @cLabelNo
                   AND SKU = @cSKU 
                   AND DropID = @cDropID 
                   GROUP BY CartonNo 
                                   
                   
                   SELECT @fWeight = CONVERT(float,max(userdefined04))
                         ,@fCube   = CONVERT(float,max(userdefined08)) 
                         ,@fLength = CONVERT(float,max(userdefined05)) 
                         ,@fWidth  = CONVERT(float,max(userdefined06)) 
                         ,@fHeight = CONVERT(float,max(userdefined07)) 
                   FROM dbo.UCC WITH (NOLOCK) 
                   WHERE UCCNo = @cDropID 
                   
                   IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                               WHERE PickSlipNo = @cPickSlipNo
                               AND CartonNo = @nPackCtnNo ) 
                   BEGIN
                      INSERT INTO dbo.PackInfo ( PickSlipNo, CartonNo, Weight, Cube, Qty, CartonType, RefNo, Length, Width, Height, UCCNo ) 
                      VALUES ( @cPickSlipNo, @nPackCtnNo, @fWeight, @fCube, @nSumCartonQty, '', 'FCP', @fLength, @fWidth, @fHeight, @cLabelNo) 
                      
                      IF @@ERROR <> 0 
                      BEGIN
                           SET @nErrNo = 93872              
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPackInfoFail              
                           GOTO RollBackTran   
                      END
                   END
                   ELSE
                   BEGIN
                     UPDATE dbo.PackInfo WITH (ROWLOCK) 
                        SET Qty = Qty + @nSumCartonQty
                     WHERE PickSlipNo = @cPickSlipNo 
                     AND CartonNo = @nPackCtnNo
                     
                     IF @@ERROR <> 0 
                     BEGIN
                           SET @nErrNo = 93873              
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPackInfoFail              
                           GOTO RollBackTran   
                     END
                   END
                END
                
                -- Auto PackConfirm 
                SELECT @nSUM_PackQTY = 0, @nSUM_PickQTY = 0    
                
                
                SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)     
                FROM dbo.PackDetail PD WITH (NOLOCK)     
                WHERE PD.StorerKey = @cStorerKey    
                   AND PD.PickSlipNo = @cPickSlipNo  
                  
                SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)     
                FROM dbo.PickDetail PD WITH (NOLOCK)    
                WHERE PD.StorerKey = @cStorerKey    
                  AND PD.OrderKey = @cOrderKey
                  --AND PD.Status = '5'
                
   
                IF @nSUM_PackQTY = @nSUM_PickQTY    
                BEGIN              
                   
                   UPDATE dbo.PackHeader WITH (ROWLOCK) 
                   SET Status = '9'
                   WHERE PickSlipNo = @cPickSlipNo 
                   
                   IF @@ERROR <> 0 
                   BEGIN   
                      SET @nErrNo = 93869              
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPackHdrFail              
                      GOTO RollBackTran        
                   END        
                END      
             
                 
               
      
--                                 
--                  
--               -- Update PickDetail 
--               UPDATE dbo.PickDetail WITH (ROWLOCK) 
--               SET Status = '5' 
--               WHERE PickDetailKey = @cPickDetailKey
--               
--               IF @@ERROR <> 0
--               BEGIN
--                  SET @nErrNo = 93861
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'
--                  GOTO RollBackTran
--               END   
                  
                 
            END
            ELSE IF @cLocationType = 'RPLSORT' -- (ChewKP04) 
            BEGIN
               
               

               --Update PickDetail.DropID , Status = '3'
               -- Split Pickdetail
               DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT  PickDetailKey
                      ,QTY
                      --,LOT
                      ,Orderkey
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                     AND WaveKey = @cWaveKey
                     AND Loc = @cFromLoc
                     AND Lot = @cLot
                     AND SKU = @cSKU
                     AND UOM = '2'
                     AND CaseID = ''
                     AND DropID = ''
                     AND Status = '0'
                     Order by OrderKey, OrderLineNumber
               
               OPEN CursorPickDetail
               FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cOrderkey
               WHILE @@FETCH_STATUS<>-1
               BEGIN
                 
                   IF @nQTY_PD=@nReplenQty
                   BEGIN
                      -- Confirm PickDetail
                      UPDATE dbo.PickDetail WITH (ROWLOCK)
                      SET    DropID = @cDropID
                            ,STATUS = 3
                      WHERE  PickDetailKey = @cPickDetailKey
               
                      IF @@ERROR <> 0
                      BEGIN
                          SET @nErrNo = 93877
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPickDetFail'
                          GOTO RollBackTran
                      END
               
                 
               
                   END
                   ELSE IF @nReplenQty > @nQTY_PD
                   BEGIN
                      -- Confirm PickDetail
                      UPDATE dbo.PickDetail WITH (ROWLOCK)
                      SET    DropID = @cDropID
                            ,STATUS = '3'
                      WHERE  PickDetailKey = @cPickDetailKey
               
                      IF @@ERROR <> 0
                      BEGIN
                          SET @nErrNo = 93878
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPickDetFail'
                          GOTO RollBackTran
                      END
               
                 
                      
                   END -- IF @nQtyMoved > @nQTY_PD
                   ELSE IF @nReplenQty < @nQTY_PD AND @nReplenQty > 0
                   BEGIN
                      EXECUTE dbo.nspg_GetKey
                               'PICKDETAILKEY',
                               10 ,
                               @cNewPickDetailKey OUTPUT,
                               @bsuccess          OUTPUT,
                               @nErrNo            OUTPUT,
                               @cErrMsg           OUTPUT
               
                      IF @bsuccess <> 1
                      BEGIN
                          SET @nErrNo = 93879
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetDetKeyFail'
                          GOTO RollBackTran
                      END
               
                      -- Create a new PickDetail to hold the balance
                      INSERT INTO dbo.PICKDETAIL
                        (
                          CaseID                  ,PickHeaderKey   ,OrderKey
                         ,OrderLineNumber         ,LOT             ,StorerKey
                         ,SKU                     ,AltSKU          ,UOM
                         ,UOMQTY                  ,QTYMoved        ,STATUS
                         ,DropID                  ,LOC             ,ID
                         ,PackKey                 ,UpdateSource    ,CartonGroup
                         ,CartonType              ,ToLoc           ,DoReplenish
                         ,ReplenishZone           ,DoCartonize     ,PickMethod
                         ,WaveKey                 ,EffectiveDate   ,ArchiveCop
                         ,ShipFlag                ,PickSlipNo      ,PickDetailKey
                         ,QTY                     ,TrafficCop      ,OptimizeCop
                         ,TaskDetailkey
                        )
                      SELECT CaseID               ,PickHeaderKey   ,OrderKey
                            ,OrderLineNumber      ,Lot             ,StorerKey
                            ,SKU                  ,AltSku          ,UOM
                            ,UOMQTY               ,QTYMoved        ,'0'
                            ,''                   ,LOC             ,ID
                            ,PackKey              ,UpdateSource    ,CartonGroup
                            ,CartonType           ,ToLoc           ,DoReplenish
                            ,ReplenishZone        ,DoCartonize     ,PickMethod
                            ,WaveKey              ,EffectiveDate   ,ArchiveCop
                            ,ShipFlag             ,PickSlipNo      ,@cNewPickDetailKey
                            ,@nQTY_PD - @nReplenQty ,NULL            ,'1'  --OptimizeCop,
                            ,TaskDetailkey
                      FROM   dbo.PickDetail WITH (NOLOCK)
                      WHERE  PickDetailKey = @cPickDetailKey
               
                      IF @@ERROR <> 0
                      BEGIN
                          SET @nErrNo = 93880
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'
                          GOTO RollBackTran
                      END
               
                      -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
                      -- Change orginal PickDetail with exact QTY (with TrafficCop)
                      UPDATE dbo.PickDetail WITH (ROWLOCK)
                      SET    QTY = @nReplenQty
                            ,Trafficcop = NULL
                      WHERE  PickDetailKey = @cPickDetailKey
               
                      IF @@ERROR <> 0
                      BEGIN
                          SET @nErrNo = 93881
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPickDetFail'
                          GOTO RollBackTran
                      END
               
                      -- Confirm orginal PickDetail with exact QTY
                      UPDATE dbo.PickDetail WITH (ROWLOCK)
                      SET    DropID = @cDropID
                            ,STATUS = '3'
                      WHERE  PickDetailKey = @cPickDetailKey
                      IF @@ERROR <> 0
                      BEGIN                      
                          SET @nErrNo = 93882
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPickDetFail'
                          GOTO RollBackTran
                      END
               
               
                   END  -- IF @nQtyMoved < @nQTY_PD AND @nQtyMoved > 0
                   
                        
               
                   IF @nReplenQty > 0
                   BEGIN
                       SET @nReplenQty = @nReplenQty- @nQTY_PD 
                       
                       
                       
                       IF @nReplenQty < 0 		
                       		SET @nReplenQty = 0	
                   END
                   ELSE IF @nReplenQty <= 0 
                   BEGIN
                     BREAK
                   END
                   
                   
               
                   FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cOrderkey
               END -- While Loop for PickDetail Key
               CLOSE CursorPickDetail
               DEALLOCATE CursorPickDetail
               
               IF ISNULL(RTRIM(@cNotMoveReplenToLoc),'')  <> '1' 
               BEGIN
   --               -- Actual Move of the Allocated Qty --
                  EXECUTE rdt.rdt_Move
                     @nMobile     = @nMobile,
                     @cLangCode   = @cLangCode,
                     @nErrNo      = @nErrNo  OUTPUT,
                     @cErrMsg     = @cErrMsg OUTPUT, 
                     @cSourceType = 'rdt_895ExtUpdSP01',
                     @cStorerKey  = @cStorerKey,
                     @cFacility   = @cFacility,
                     @cFromLOC    = @cFromLOC,
                     @cToLOC      = @cActToLOC,
                     @cFromID     = @cID,     
                     @cToID       = @cID,       
                     @cSKU        = @cSKU,
                     @nQTY        = @nQtyMoved,
                     @nQTYAlloc   = @nQtyMoved,
                     @nQTYPick    = 0, 
                     @nFunc       = @nFunc, 
                     @cDropID     = @cDropID
               
                  IF @nErrNo <> 0 
                  BEGIN
                         
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                        GOTO RollBackTran    
                  END
               END


               ---- Move Inventory
               --IF @cNotConfirmDPPReplen <> '1' 
               --BEGIN
               --   -- Actual Move of the Qty --
               --   EXECUTE rdt.rdt_Move
               --      @nMobile     = @nMobile,
               --      @cLangCode   = @cLangCode,
               --      @nErrNo      = @nErrNo  OUTPUT,
               --      @cErrMsg     = @cErrMsg OUTPUT, 
               --      @cSourceType = 'rdt_895ExtUpdSP01',
               --      @cStorerKey  = @cStorerKey,
               --      @cFacility   = @cFacility,
               --      @cFromLOC    = @cFromLOC,
               --      @cToLOC      = @cActToLOC,
               --      @cFromID     = @cID,     
               --      @cToID       = @cID,       
               --      @cFromLot    = @cLot,
               --      @cSKU        = @cSKU,
               --      @nQTY        = @nQtyMoved,
               --      @nQTYAlloc   = 0,
               --      @nQTYPick    = 0, 
               --      @nQTYReplen  = @nQtyMoved,
               --      @nFunc       = @nFunc
                     
               --   IF @nErrNo <> 0 
               --   BEGIN
               --         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               --         GOTO RollBackTran    
               --   END   
               --END
               
               
            END
            ELSE
            BEGIN
               
--               SELECT Top 1 @cPickDetailKey = PickDetailKey
--                        ,@nPickDetailQty = Qty
--                        ,@cOrderKey = OrderKey
--               FROM dbo.PickDetail WITH (NOLOCK)
--               WHERE StorerKey = @cStorerKey
--               AND WaveKey = @cWaveKey
--               AND Loc = @cToLoc
--               AND Lot = @cLot
--               AND SKU = @cSKU
--               AND UOM = CASE WHEN @cUOM = 'CA' THEN '2' ELSE UOM END
--               AND CaseID = ''
--               Order by OrderKey, OrderLineNumber
               
--               DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
--               SELECT  PickDetailKey
--               FROM dbo.PickDetail WITH (NOLOCK)
--               WHERE StorerKey = @cStorerKey
--                     AND WaveKey = @cWaveKey
--                     AND Loc = @cToLoc
--                     AND Lot = @cLot
--                     AND SKU = @cSKU
--                     AND UOM = CASE WHEN @cUOM = 'CA' THEN '2' ELSE UOM END
--                     AND CaseID = ''
--                     Order by OrderKey, OrderLineNumber
--               
--               OPEN CursorPickDetail
--               FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey--, @nQTY_PD, @cOrderkey
--               WHILE @@FETCH_STATUS<>-1
--               BEGIN
--
--                  -- Update PickDetail 
--                  UPDATE dbo.PickDetail WITH (ROWLOCK) 
--                  SET DropID = @cDropID
--                     ,CaseID = @cDropID
--                     ,Trafficcop = NULL
--                  WHERE PickDetailKey = @cPickDetailKey
--                  
--                  IF @@ERROR <> 0
--                  BEGIN
--                     SET @nErrNo = 93854
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'
--                     GOTO RollBackTran
--                  END
--                  
--                  FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey --, @nQTY_PD, @cOrderkey
--                  
--               END
--               CLOSE CursorPickDetail
--               DEALLOCATE CursorPickDetail
               
               IF @cNotConfirmDPPReplen <> '1' -- (ChewKP01) 
               BEGIN
                  -- Actual Move of the Qty --
                  EXECUTE rdt.rdt_Move
                     @nMobile     = @nMobile,
                     @cLangCode   = @cLangCode,
                     @nErrNo      = @nErrNo  OUTPUT,
                     @cErrMsg     = @cErrMsg OUTPUT, 
                     @cSourceType = 'rdt_895ExtUpdSP01',
                     @cStorerKey  = @cStorerKey,
                     @cFacility   = @cFacility,
                     @cFromLOC    = @cFromLOC,
                     @cToLOC      = @cActToLOC,
                     @cFromID     = @cID,     
                     @cToID       = @cID,       
                     @cFromLot    = @cLot,
                     @cSKU        = @cSKU,
                     @nQTY        = @nQtyMoved,
                     @nQTYAlloc   = 0,
                     @nQTYPick    = 0, 
                     @nQTYReplen  = @nQtyMoved,
                     @nFunc       = @nFunc
                     
                  IF @nErrNo <> 0 
                  BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                        GOTO RollBackTran    
                  END   
               END
               
               
               
                 
            END
            
            
            -- Update replenishment
            UPDATE dbo.Replenishment WITH (ROWLOCK) SET
               QTY       = @nQtyMoved,
               Confirmed = 'Y',
               RefNo    = CASE WHEN RefNo = '' THEN @cDropID ELSE RefNo END,
               EditWho  = @cUserName,
               EditDate = GetDate(), 
               Remark   = 'VERIFIED', -- (CheWKP01) 
               ArchiveCop = NULL
            WHERE ReplenishmentKey = @cReplenKey
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 93851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd RPL Fail'
               GOTO RollBackTran
            END
            
            Update dbo.UCC 
            SET Status = '6'
            WHERE UCCNo = @cDropID
            AND StorerKey = @cStorerKey
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 93853
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdUCCFail'
               GOTO RollBackTran
            END
            
            Update rdt.rdtReplenishmentLog WITH (ROWLOCK) 
            SET Confirmed = 'Y'
               ,Remark = 'VERIFIED' -- (ChewKP01) 
            WHERE RowRef = @nRowRef
   
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 93858
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdReplenLogFail'
               GOTO RollBackTran
            END
            
            -- (james01)
            IF EXISTS ( SELECT 1 FROM dbo.REPLENISHMENT WITH (NOLOCK)
                        WHERE ReplenishmentKey = @cReplenKey
                        AND   ReplenNo = 'FCS')
            BEGIN
               IF NOT EXISTS ( SELECT 1 FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
                               WHERE tablename = 'REPLRDTLOG'
                               AND   key1 = @cReplenKey
                               AND   key2 = 'UCC'
                               AND   key3 = @cStorerKey)
               BEGIN
                  -- Insert transmitlog3 here
                  EXECUTE ispGenTransmitLog3 
                     @c_TableName      = 'REPLRDTLOG', 
                     @c_Key1           = @cReplenKey, 
                     @c_Key2           = 'UCC', 
                     @c_Key3           = @cStorerkey, 
                     @c_TransmitBatch  = '', 
                     @b_Success        = @bSuccess   OUTPUT,    
                     @n_err            = @nErrNo     OUTPUT,    
                     @c_errmsg         = @cErrMsg    OUTPUT    

                  IF @bSuccess <> 1    
                  BEGIN
                     SET @nErrNo = 93883
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Insert TL3 Err
                     GOTO RollBackTran
                  END
               END
            END

            FETCH NEXT FROM CursorReplen INTO @cReplenKey, @nQtyMoved, @cDropID, @cSKU, @cLot, @cID, @cToLoc, @cUOM, @cRefNo, @cFromLoc, @nRowRef
   
         END
         CLOSE CursorReplen            
         DEALLOCATE CursorReplen  
         
         
      END  
      
      IF @nStep = 8 
      BEGIN
         
         
         SELECT @cFromLoc = V_Loc
               ,@cID      = V_ID
               ,@cSuggSKU = V_String15
         FROM rdt.rdtMobrec WITH (NOLOCK)
         WHERE Mobile = @nMobile 
         
         SELECT TOP 1 @cDropID  = RefNo 
               --,@cSuggSKU = SKU
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND FromLoc = @cFromLoc
         AND ID = @cID
         AND SKU = @cSuggSKU 
         --AND ReplenishmentKey = @cReplenKey
         
         
         IF ISNULL(@cDropID,'' ) = '' 
         BEGIN
            UPDATE rdt.rdtReplenishmentLog WITH (ROWLOCK)
            SET  Confirmed = 'S' -- Short
            WHERE StorerKey = @cStorerKey
            AND WaveKey = @cWaveKey
            AND FromLoc = @cFromLoc
            AND ID = @cID
            AND SKU = @cSuggSKU 
         END
         ELSE
         BEGIN
            UPDATE rdt.rdtReplenishmentLog WITH (ROWLOCK)
            SET  Confirmed = 'S' -- Short
            WHERE StorerKey = @cStorerKey
            AND WaveKey = @cWaveKey
            AND FromLoc = @cFromLoc
            AND ID = @cID
            AND RefNo = @cDropID
         END
         
         IF @@ERROR <> 0 
         BEGIN 
               SET @nErrNo = 93868
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRPLogFail
               GOTO RollBackTran
         END
         
     
      END
      
      IF @nStep = 10 
      BEGIN
         SELECT @cFromLoc = V_Loc
               ,@cID      = V_ID
               ,@cSuggSKU = V_String15
         FROM rdt.rdtMobrec WITH (NOLOCK)
         WHERE Mobile = @nMobile 
         
         DECLARE CursorPalletCount CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
      
         SELECT RefNo, RowRef
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
         WHERE WaveKey = @cWaveKey
         AND StorerKey = @cStorerKey
         AND AddWho = @cUserName
         --AND Confirmed = '1'
         AND FromLoc = @cFromLoc
         AND ID = @cID
         --AND ToLoc = @cActToLOC
         ORDER BY ReplenishmentKey
         
         
         OPEN CursorPalletCount            
         
         FETCH NEXT FROM CursorPalletCount INTO  @cRefNo, @nRowRef
         
         
         WHILE @@FETCH_STATUS <> -1     
         BEGIN
         
            IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                        WHERE WaveKey = @cWaveKey
                        AND RefNo = @cRefNo
                        AND Confirmed = 'N')
            BEGIN
               UPDATE rdt.rdtReplenishmentLog
               SET  Confirmed = '1' -- In Progress
                  , QtyMoved  = Qty
                  , DropID    = @cRefNo
               WHERE WaveKey = @cWaveKey
               AND RefNo = @cRefNo
               AND RowRef = @nRowRef
               
               IF @@ERROR <> 0 
               BEGIN 
                     SET @nErrNo = 93874
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRPLogFail
                     GOTO RollBackTran
               END
            END
            ELSE
            BEGIN         
               --INSERT INTO TRACEINFO ( TraceName , TimeIN , Col1, col2 , Col3 ) 
               --VALUES ( '895' , Getdate() , @cReplenKey , '' , ''  ) 

               IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                           WHERE WaveKey = @cWaveKey
                           AND StorerKey = @cStorerKey
                           AND ReplenNo = 'RPL-COMBCA'
                           AND Confirmed = 'N' 
                           AND RefNo = @cRefNo) 
               BEGIN
                  
--                  SELECT  @cCombineKey = RefNo
--                  FROM rdt.rdtReplenishmentLog WITH (NOLOCK) 
--                  WHERE WaveKey = @cWaveKey
--                  AND StorerKey = @cStorerKey
--                    AND ReplenNo = 'RPL-COMBCA'
--                    AND Confirmed = 'N' 
--                    AND ReplenishmentKey = @cReplenKey
                  
                  -- Update rdt.rdtReplenishmentLog
                  UPDATE rdt.rdtReplenishmentLog
                  SET  Confirmed = '1' -- In Progress
                     , QtyMoved  = Qty
                     , DropID    = @cLabelNo
                  WHERE WaveKey = @cWaveKey
                    AND ReplenNo = 'RPL-COMBCA'
                    AND Confirmed = 'N' 
                    AND StorerKey = @cStorerKey
                    AND RefNo = @cRefNo
                  
                  IF @@ERROR <> 0 
                  BEGIN 
                        SET @nErrNo = 93876
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRPLogFail
                        GOTO RollBackTran
                  END
                  
               END
               ELSE
               BEGIN            
               
                  -- Update rdt.rdtReplenishmentLog
                  UPDATE rdt.rdtReplenishmentLog
                  SET  Confirmed = '1' -- In Progress
                     , QtyMoved  = @nQTY
                     , DropID    = @cRefNo
                  WHERE RowRef = @nRowRef
                  
                  IF @@ERROR <> 0 
                  BEGIN 
                        SET @nErrNo = 93875
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRPLogFail
                        GOTO RollBackTran
                  END
               END
            END
            
            FETCH NEXT FROM CursorPalletCount INTO  @cRefNo, @nRowRef
         END
         CLOSE CursorPalletCount            
         DEALLOCATE CursorPalletCount  
      END
   END
   

   
   
  
   GOTO QUIT   
     
RollBackTran:  
   ROLLBACK TRAN rdt_895ExtUpdSP01 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_895ExtUpdSP01  
   
  
END    

GO
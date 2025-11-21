SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Store procedure: rdt_839Confirm02                                       */  
/* Copyright      : Maersk                                                 */  
/*                                                                         */  
/* Date       Rev  Author  Purposes                                        */  
/* 2018-04-30 1.0  ChewKP  WMS-4542 Created                                */  
/* 2021-06-30 1.1  James   WMS-17406 Add rdt_STD_EventLog (james01)        */
/* 2022-04-20 1.2  YeeKung WMS-19311 Add Data capture (yeekung01)          */
/* 2023-07-25 1.3  Ung     WMS-23002 Add serial no                         */
/***************************************************************************/  
CREATE   PROC [RDT].[rdt_839Confirm02](  
   @nMobile       INT,             
   @nFunc         INT,             
   @cLangCode     NVARCHAR( 3),    
   @nStep         INT,             
   @nInputKey     INT,             
   @cFacility     NVARCHAR( 5) ,   
   @cStorerKey    NVARCHAR( 15),   
   @cType         NVARCHAR( 10),   
   @cPickSlipNo   NVARCHAR( 10),   
   @cPickZone     NVARCHAR( 1),    
   @cDropID       NVARCHAR( 20),   
   @cLOC          NVARCHAR( 10),   
   @cSKU          NVARCHAR( 20),   
   @nQTY          INT,             
   @cLottableCode NVARCHAR( 30),   
   @cLottable01   NVARCHAR( 18),     
   @cLottable02   NVARCHAR( 18),     
   @cLottable03   NVARCHAR( 18),     
   @dLottable04   DATETIME,  
   @dLottable05   DATETIME,  
   @cLottable06   NVARCHAR( 30),    
   @cLottable07   NVARCHAR( 30),    
   @cLottable08   NVARCHAR( 30),    
   @cLottable09   NVARCHAR( 30),    
   @cLottable10   NVARCHAR( 30),    
   @cLottable11   NVARCHAR( 30),   
   @cLottable12   NVARCHAR( 30),   
   @dLottable13   DATETIME,  
   @dLottable14   DATETIME,  
   @dLottable15   DATETIME,  
   @cPackData1    NVARCHAR( 30),
   @cPackData2    NVARCHAR( 30),
   @cPackData3    NVARCHAR( 30),
   @cID           NVARCHAR( 18),
   @cSerialNo     NVARCHAR( 30),
   @nSerialQTY    INT,
   @nBulkSNO      INT,
   @nBulkSNOQTY   INT,
   @nErrNo        INT           OUTPUT,   
   @cErrMsg       NVARCHAR(250) OUTPUT    
     
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
     
   DECLARE @cOrderKey      NVARCHAR( 10)  
   DECLARE @cLoadKey       NVARCHAR( 10)  
   DECLARE @cZone          NVARCHAR( 18)  
   DECLARE @cPickDetailKey NVARCHAR( 18)  
   DECLARE @cPickConfirmStatus NVARCHAR( 1)  
   DECLARE @nQTY_Bal       INT  
   DECLARE @nQTY_PD        INT  
   DECLARE @bSuccess       INT  
          ,@cWCS           NVARCHAR(1)  
   DECLARE @curPD          CURSOR  
          ,@c_authority    NVARCHAR(1)   
          ,@cWCSSequence   NVARCHAR(2)   
          ,@cWCSOrderKey   NVARCHAR(20)   
          ,@cWCSKey        NVARCHAR(10)   
          ,@nCounter       INT  
          ,@cBatchKey      NVARCHAR(10)   
          ,@cWCSStation    NVARCHAR(10)  
          ,@cWCSMessage    NVARCHAR(MAX)  
          ,@nToteCount     INT  
          ,@cDeviceType    NVARCHAR( 10)  
          ,@cDeviceID      NVARCHAR( 10)  
          ,@cDocType       NVARCHAR( 1)  
          ,@cPDOrderKey    NVARCHAR( 10)  
          ,@cSKUGroup      NVARCHAR( 10)  
          ,@cDropID2UPD    NVARCHAR( 20)  
          ,@nCount         INT  
          ,@cPutawayZone   NVARCHAR( 10)   
  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_839Confirm02     
  
   SELECT @cDeviceID = DeviceID  
   FROM rdt.rdtMobrec WITH (NOLOCK)   
   WHERE Mobile = @nMobile   
   AND Func = @nFunc  
     
     
   -- Get storer config  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  
     
   SET @cOrderKey = ''  
   SET @cLoadKey = ''  
   SET @cZone = ''  
     
   SET @cWCS = '0'  
   SET @cDeviceType = 'WCS'  
   SET @cDeviceID = 'WCS'  
     
     
  
   -- GET WCS Config   
   EXECUTE nspGetRight   
            @cFacility,  -- facility  
            @cStorerKey,  -- Storerkey  
            null,         -- Sku  
            'WCS',        -- Configkey  
            @bSuccess     output,  
            @c_authority  output,   
            @nErrNo       output,  
            @cErrMsg      output  
  
   IF @c_authority = '1' AND @bSuccess = 1  
   BEGIN  
      SET @cWCS = '1'   
   END       
     
   IF @nFunc = 839   
   BEGIN  
        
   IF @nStep IN ( '3', '5')  
   BEGIN  
      -- For calculation  
      SET @nQTY_Bal = @nQTY  
  
      -- Get PickHeader info  
      SELECT TOP 1  
         @cOrderKey = OrderKey,  
         @cLoadKey = ExternOrderKey,  
         @cZone = Zone  
      FROM dbo.PickHeader WITH (NOLOCK)  
      WHERE PickHeaderKey = @cPickSlipNo  
  
      -- Cross dock PickSlip  
      IF @cZone IN ('XD', 'LB', 'LP')  
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.PickDetailKey, PD.QTY  
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
         WHERE RKL.PickSlipNo = @cPickSlipNo  
            AND PD.LOC = @cLOC  
            AND PD.SKU = @cSKU  
            AND PD.QTY > 0  
            AND PD.DropID = ''  
            AND PD.Status <> '4'  
            AND PD.Status < @cPickConfirmStatus  
  
      -- Discrete PickSlip  
      ELSE IF @cOrderKey <> ''  
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.PickDetailKey, PD.QTY  
         FROM dbo.PickDetail PD WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
         WHERE PD.OrderKey = @cOrderKey  
            AND PD.LOC = @cLOC  
            AND PD.SKU = @cSKU  
            AND PD.QTY > 0  
            AND PD.DropID = ''  
            AND PD.Status <> '4'  
            AND PD.Status < @cPickConfirmStatus  
  
      -- Conso PickSlip  
      ELSE IF @cLoadKey <> ''  
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.PickDetailKey, PD.QTY  
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)  
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
         WHERE LPD.LoadKey = @cLoadKey  
            AND PD.LOC = @cLOC  
            AND PD.SKU = @cSKU  
            AND PD.QTY > 0  
            AND PD.DropID = ''  
            AND PD.Status <> '4'  
            AND PD.Status < @cPickConfirmStatus  
  
         -- Custom PickSlip  
         ELSE  
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PD.PickDetailKey, PD.QTY  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.PickSlipNo = @cPickSlipNo  
               AND PD.LOC = @cLOC  
               AND PD.SKU = @cSKU  
               AND PD.QTY > 0  
               AND PD.DropID = ''  
               AND PD.Status <> '4'  
               AND PD.Status < @cPickConfirmStatus  

         -- Loop PickDetail  
         OPEN @curPD  
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            -- Exact match  
            IF @nQTY_PD = @nQTY_Bal  
            BEGIN  
               -- Confirm PickDetail  
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                  Status = @cPickConfirmStatus,  
                  DropID = @cDropID,  
                  EditDate = GETDATE(),  
                  EditWho  = SUSER_SNAME()  
               WHERE PickDetailKey = @cPickDetailKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 123701  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                  GOTO RollBackTran  
               END  
  
               SET @nQTY_Bal = 0 -- Reduce balance  
            END  
  
            -- PickDetail have less  
            ELSE IF @nQTY_PD < @nQTY_Bal  
            BEGIN  
               -- Confirm PickDetail  
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                  Status = @cPickConfirmStatus,  
                  DropID = @cDropID,  
                  EditDate = GETDATE(),  
                  EditWho  = SUSER_SNAME()  
               WHERE PickDetailKey = @cPickDetailKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 123702  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                  GOTO RollBackTran  
               END  
  
               SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance  
            END  
  
            -- PickDetail have more  
            ELSE IF @nQTY_PD > @nQTY_Bal  
            BEGIN  
               -- Don't need to split  
               IF @nQTY_Bal = 0  
               BEGIN  
                  -- Short pick  
                  IF @cType = 'SHORT' -- Don't need to split  
                  BEGIN  
                     -- Confirm PickDetail  
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                        Status = '4',  
                        EditDate = GETDATE(),  
                        EditWho  = SUSER_SNAME(),  
                        TrafficCop = NULL  
                     WHERE PickDetailKey = @cPickDetailKey  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 123703  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                        GOTO RollBackTran  
                     END  
                  END  
               END  
               ELSE  
               BEGIN -- Have balance, need to split  
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
                     SET @nErrNo = 123704  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                     GOTO RollBackTran  
                  END  
  
                  -- Create new a PickDetail to hold the balance  
                  INSERT INTO dbo.PickDetail (  
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,  
                     UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                     ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
                     EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,  
                     PickDetailKey,  
                     Status,  
                     QTY,  
                     TrafficCop,  
                     OptimizeCop)  
                  SELECT  
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,  
                     UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,  
                     CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
                     EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,  
                     @cNewPickDetailKey,  
                     Status,  
                     @nQTY_PD - @nQTY_Bal, -- QTY  
                     NULL, -- TrafficCop  
                     '1'   -- OptimizeCop  
                  FROM dbo.PickDetail WITH (NOLOCK)  
                  WHERE PickDetailKey = @cPickDetailKey  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 123705  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail  
                     GOTO RollBackTran  
                  END  
  
                  -- Split RefKeyLookup  
                  IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)  
                  BEGIN  
                     -- Insert into  
                     INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)  
                     SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey  
                     FROM RefKeyLookup WITH (NOLOCK)  
                     WHERE PickDetailKey = @cPickDetailKey  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 123706  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
                        GOTO RollBackTran  
                     END  
                  END  
  
                  -- Change orginal PickDetail with exact QTY (with TrafficCop)  
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                     QTY = @nQTY_Bal,  
                     EditDate = GETDATE(),  
                     EditWho  = SUSER_SNAME(),  
                     Trafficcop = NULL  
                  WHERE PickDetailKey = @cPickDetailKey  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 123707  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                     GOTO RollBackTran  
                  END  
  
                  -- Confirm orginal PickDetail with exact QTY  
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                     Status = @cPickConfirmStatus,  
                     DropID = @cDropID,  
                     EditDate = GETDATE(),  
                     EditWho  = SUSER_SNAME()  
                  WHERE PickDetailKey = @cPickDetailKey  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 123708  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                     GOTO RollBackTran  
                  END  
  
                  SET @nQTY_Bal = 0 -- Reduce balance  
               END  
            END  
  
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD  
         END  

         DECLARE @cUserName NVARCHAR( 18)  
         SET @cUserName = SUSER_SNAME()  
  
         EXEC RDT.rdt_STD_EventLog  
            @cActionType   = '3', -- Picking  
            @cUserID       = @cUserName,  
            @nMobileNo     = @nMobile,  
            @nFunctionID   = @nFunc,  
            @cFacility     = @cFacility,  
            @cStorerKey    = @cStorerKey,  
            @cLocation     = @cLOC,  
            @cSKU          = @cSKU,  
            @nQTY          = @nQTY,  
            @cRefNo1       = @cType,  
            @cPickSlipNo   = @cPickSlipNo,  
            @cPickZone     = @cPickZone,   
            @cDropID       = @cDropID  


         -- WCS Event  
         IF @nStep = '5'   
         BEGIN  
            IF @cWCS = '1'  
            BEGIN  
                  SELECT TOP 1  
                     @cWCSOrderKey = OrderKey  
                  FROM dbo.PickDetail WITH (NOLOCK)  
                  WHERE StorerKey = @cStorerKey  
                  AND PickSlipNo = @cPickSlipNo  
                    
                  SELECT @cDocType = DocType   
                  FROM dbo.Orders WITH (NOLOCK)   
                  WHERE StorerKey = @cStorerKey  
                  AND OrderKey = @cWCSOrderKey  
  
                    
                    
                  IF @cDocType = 'N'  
                  BEGIN  
                     SET @cWCSSequence = '01'  
              
                     EXECUTE dbo.nspg_GetKey  
                        'WCSKey',  
                        10 ,  
                        @cWCSKey           OUTPUT,  
                        @bSuccess          OUTPUT,  
                        @nErrNo            OUTPUT,  
                        @cErrMsg           OUTPUT  
                          
                     IF @bSuccess <> 1  
                     BEGIN  
                        SET @nErrNo = 123710  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                        GOTO RollBackTran  
                     END  
                       
                    
  
                     DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
                     --SELECT DropID FROM dbo.DropID WITH (NOLOCK)  
                     --WHERE LoadKey = @cLoadKey    
                     --AND   [Status] <> '5'    
                       
                     SELECT PD.OrderKey, PD.DropID, CD.Short FROM dbo.PickDetail PD WITH (NOLOCK)   
                     INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey     
                     JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)    
                     JOIN dbo.Codelkup CD WITH (NOLOCK) ON CD.StorerKey = PD.StorerKey AND CD.Code = SKU.SUSR3 AND CD.ListName = 'SKUGROUP'   
                     WHERE PD.StorerKey = @cStorerkey    
                     AND   PD.Status = '5'    
                     AND   LPD.LoadKey = @cLoadKey  
                     AND CD.ListName = 'SKUGROUP'  
                     GROUP BY PD.OrderKey, PD.DropID, CD.Short   
                       
                                    
                     OPEN CUR_UPD   
                     FETCH NEXT FROM CUR_UPD INTO @cPDOrderKey, @cDropID2UPD, @cSKUGroup  
                     WHILE @@FETCH_STATUS <> -1  
                     BEGIN  
                          
                        -- Sent WCS Data  
                        SET @nCount = 1   
                                       
                             
                        SELECT @cLoc = Loc  
                        FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
                        WHERE StorerKey = @cStorerKey   
                        AND OrderKey = @cPDOrderKey  
                        AND UserDefine02 = @cSKUGroup  
                          
                        SELECT @cPutawayZone = PutawayZone   
                        FROM dbo.Loc WITH (NOLOCK)   
                        WHERE Facility = @cFacility   
                        AND Loc = @cLoc   
                          
                        SELECT @cWCSStation = Short                  
                        FROM dbo.Codelkup WITH (NOLOCK)   
                        WHERE ListName = 'WCSSTATION'  
                        AND StorerKey = @cStorerKey  
                        AND Code = @cPutawayZone   
                          
                        EXECUTE dbo.nspg_GetKey  
                           'WCSKey',  
                           10 ,  
                           @cWCSKey           OUTPUT,  
                           @bSuccess          OUTPUT,  
                           @nErrNo            OUTPUT,  
                           @cErrMsg           OUTPUT  
                             
                        IF @bSuccess <> 1  
                        BEGIN  
                           SET @nErrNo = 123711  
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                           GOTO RollBackTran  
                        END  
                          
                        SET @cWCSSequence =  RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
                        SET @cWCSMessage = '<STX>' + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cDropID2UPD) + '|' + @cWCSKey + '|' + @cWCSStation + '|<ETX>'  
                          
                        EXEC [RDT].[rdt_GenericSendMsg]  
                         @nMobile      = @nMobile        
                        ,@nFunc        = @nFunc          
                        ,@cLangCode    = @cLangCode      
                        ,@nStep        = @nStep          
                        ,@nInputKey    = @nInputKey      
                        ,@cFacility    = @cFacility      
                        ,@cStorerKey   = @cStorerKey     
                        ,@cType        = @cDeviceType         
                        ,@cDeviceID    = @cDeviceID  
                        ,@cMessage     = @cWCSMessage       
                        ,@nErrNo       = @nErrNo       OUTPUT  
                        ,@cErrMsg      = @cErrMsg      OUTPUT    
                          
                          
                        IF @nErrNo <> 0   
                           GOTO RollBackTran    
                          
                          
                        SET @nCount = @nCount + 1   
                          
                        FETCH NEXT FROM CUR_UPD INTO @cPDOrderKey, @cDropID2UPD, @cSKUGroup  
                     END  
                     CLOSE CUR_UPD  
                     DEALLOCATE CUR_UPD  
                  END  
                  ELSE IF @cDocType = 'E'  
                  BEGIN  
                     SET @cWCSSequence = '01'  
                       
                     SELECT @cType = ISNULL(ECOM_Single_FLAG,'')   
                     FROM dbo.Orders WITH (NOLOCK)   
                     WHERE StorerKey = @cStorerKey  
                     AND OrderKey = @cWCSOrderKey   
                       
                          
                     EXECUTE dbo.nspg_GetKey  
                        'WCSKey',  
                        10 ,  
                        @cWCSKey           OUTPUT,  
                        @bSuccess          OUTPUT,  
                        @nErrNo            OUTPUT,  
                        @cErrMsg           OUTPUT  
                          
                     IF @bSuccess <> 1  
                     BEGIN  
                        SET @nErrNo = 123709  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                        GOTO RollBackTran  
                     END  
                       
                     IF @nCounter = 1   
                     BEGIN  
                        SET @cBatchKey = @cWCSKey  
                     END  
                       
                     IF @cType = 'S'  
                     BEGIN  
                        SELECT @cWCSStation = Short                  
                        FROM dbo.Codelkup WITH (NOLOCK)   
                        WHERE ListName = 'WCSSTATION'  
                        AND StorerKey = @cStorerKey  
                        AND Code = @cType  
                          
                        SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cDropID) + '|' + @cPickSlipNo + '|' + @cWCSStation + '|' + CHAR(3)  
                          
                     END  
                     ELSE IF @cType = 'M'  
                     BEGIN  
                        SELECT @cWCSStation = Short                  
                        FROM dbo.Codelkup WITH (NOLOCK)   
                        WHERE ListName = 'WCSSTATION'  
                        AND StorerKey = @cStorerKey  
                        AND Code = @cType  
                          
                        IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)   
                                       WHERE StorerKey = @cStorerKey  
                                       AND PickSlipNo = @cPickSlipNo   
                                       AND Status NOT IN ( '4', @cPickConfirmStatus)   
                                       AND DropID = '' )  
                        BEGIN  
                           SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cDropID) + '|' + @cPickSlipNo + '|' + @cWCSStation + '|'  + CHAR(3)  
                        END  
                        ELSE  
                        BEGIN  
                             
                           SELECT @nToteCount = Count(Distinct DropID)  
                           FROM dbo.PickDetail WITH (NOLOCK)   
                           WHERE StorerKey = @cStorerKey   
                           AND PickSlipNo = @cPickSlipNo   
                           AND QTY > 0  
                           AND DropID <> ''  
                           AND Status = @cPickConfirmStatus  
                             
                          
                           SET @cWCSMessage = CHAR(2) +  @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cDropID) + '|' + @cPickSlipNo + '|' + @cWCSStation + '|' + CAST(@nToteCount AS NVARCHAR(3)) + CHAR(3)   
                             
                        END  
                          
                     END  
                       
                     EXEC [RDT].[rdt_GenericSendMsg]  
                      @nMobile      = @nMobile        
                     ,@nFunc        = @nFunc          
                     ,@cLangCode    = @cLangCode      
                     ,@nStep        = @nStep          
                     ,@nInputKey    = @nInputKey      
                     ,@cFacility    = @cFacility      
                     ,@cStorerKey   = @cStorerKey     
                     ,@cType        = @cDeviceType         
                     ,@cDeviceID    = @cDeviceID  
                     ,@cMessage     = @cWCSMessage       
                     ,@nErrNo       = @nErrNo       OUTPUT  
                     ,@cErrMsg      = @cErrMsg      OUTPUT    
  
                     IF @nErrNo <> 0   
                        GOTO RollBackTran  
      --               EXEC [RDT].[rdt_UAWCSSendMsg]  
      --                        @nMobile        
      --                       ,@nFunc          
      --                       ,@cLangCode      
      --                       ,@nStep          
      --                       ,@nInputKey      
      --                       ,@cFacility      
      --                       ,@cStorerKey     
      --                       ,@cType          
      --                       ,@cWCSMessage       
      --                       ,@nErrNo       OUTPUT  
      --                       ,@cErrMsg      OUTPUT    
                       
                          
                  END  
            END  
         END  
     END   
   END  
  
   GOTO QUIT  
  
RollBackTran:  
  
   ROLLBACK TRAN rdt_839Confirm02 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_839Confirm02    
        
END  

GO
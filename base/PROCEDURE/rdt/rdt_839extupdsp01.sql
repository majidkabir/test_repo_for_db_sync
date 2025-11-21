SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_839ExtUpdSP01                                      */  
/* Copyright      : LF Logistics                                           */  
/*                                                                         */  
/* Date       Rev  Author  Purposes                                        */  
/* 2018-04-30 1.0  ChewKP  WMS-4542 Created                                */  
/* 2019-06-21 1.1  James   WMS-9209 Move step3 esc part to step8 (james01) */
/* 2019-09-10 1.2  YeeKung WMS-10517 Add parms in gettask (yeekung01)      */  
/* 2020-02-25 1.3  James   WMS-11654 Fix error return bug (james02)        */
/* 2021-01-08 1.4  James   WMS-15993 Add support suggested id (james03)    */
/* 2022-04-20 1.5  YeeKung WMS-19311 Add Data capture (yeekung02)          */
/***************************************************************************/  
CREATE   PROC [RDT].[rdt_839ExtUpdSP01](  
   @nMobile         INT                       
  ,@nFunc           INT                       
  ,@cLangCode       NVARCHAR( 3)              
  ,@nStep           INT                       
  ,@nInputKey       INT                       
  ,@cFacility       NVARCHAR( 5)              
  ,@cStorerKey      NVARCHAR( 15)             
  ,@cPickSlipNo     NVARCHAR( 10)             
  ,@cPickZone       NVARCHAR( 10)             
  ,@cDropID         NVARCHAR( 20)             
  ,@cLOC            NVARCHAR( 10)             
  ,@cSKU            NVARCHAR( 20)             
  ,@nQTY            INT                       
  ,@cOption         NVARCHAR( 1)              
  ,@cLottableCode   NVARCHAR( 30)             
  ,@cLottable01     NVARCHAR( 18)             
  ,@cLottable02     NVARCHAR( 18)             
  ,@cLottable03     NVARCHAR( 18)             
  ,@dLottable04     DATETIME                  
  ,@dLottable05     DATETIME                  
  ,@cLottable06     NVARCHAR( 30)             
  ,@cLottable07     NVARCHAR( 30)             
  ,@cLottable08     NVARCHAR( 30)             
  ,@cLottable09     NVARCHAR( 30)             
  ,@cLottable10     NVARCHAR( 30)             
  ,@cLottable11     NVARCHAR( 30)             
  ,@cLottable12     NVARCHAR( 30)             
  ,@dLottable13     DATETIME                  
  ,@dLottable14     DATETIME                  
  ,@dLottable15     DATETIME
  ,@cPackData1      NVARCHAR( 30)
  ,@cPackData2      NVARCHAR( 30)
  ,@cPackData3      NVARCHAR( 30)  
  ,@nErrNo          INT           OUTPUT      
  ,@cErrMsg         NVARCHAR(250) OUTPUT      
     
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
          ,@nSuggQTY       INT  
          ,@cSKUDescr      NVARCHAR(60)  
          ,@cDisableQTYField NVARCHAR(1)   
          ,@cPTLStation      NVARCHAR(10)   
          ,@cType            NVARCHAR(10)   
          ,@cSuggLoc         NVARCHAR(10)   
          ,@cSuggSKU         NVARCHAR(20)   
          ,@cLoadPlanLaneDetailLoc NVARCHAR(10)   
          ,@nNormalWCS       INT  
          ,@cWaveKey         NVARCHAR(10)
          ,@nTtlBlncQty      INT
          ,@nBlncQty         INT   
          ,@cSuggID          NVARCHAR(20)

   --DECLARE @cPickConfirmStatus NVARCHAR( 1)              
  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_839ExtUpdSP01     
  
   SELECT @cDeviceID = DeviceID  
         ,@nSuggQty  = V_Qty   
         ,@cSuggLoc  = V_LOC  
         ,@cSuggSKU  = V_SKU
         ,@cSuggID   = V_String38  
   FROM rdt.rdtMobrec WITH (NOLOCK)   
   WHERE Mobile = @nMobile   
   AND Func = @nFunc  
     
     
   SET @cOrderKey = ''  
   SET @cLoadKey = ''  
   SET @cZone = ''  
     
   SET @cWCS = '0'  
   SET @cDeviceType = 'WCS'  
   SET @cDeviceID = 'WCS'  
     
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  
     
     
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
        
      IF @nStep = 3  
      BEGIN  
              
           IF @nInputKey = 1   
           BEGIN  
                
              --SELECT @cLOC '@cLOC' ,@cSuggLoc '@cSuggLoc'   
              EXEC rdt.rdt_PickPiece_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTSKU'      
               ,@cPickSlipNo      
               ,@cPickZone      
               ,4      
               ,@nTtlBlncQty      OUTPUT
               ,@nBlncQty         OUTPUT
               ,@cSuggLOC         OUTPUT
               ,@cSuggSKU         OUTPUT
               ,@cSKUDescr        OUTPUT
               ,@nSuggQTY         OUTPUT
               ,@cDisableQTYField OUTPUT
               ,@cLottableCode    OUTPUT
               ,@cLottable01      OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
               ,@cLottable06      OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
               ,@cLottable11      OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT
               ,@nErrNo           OUTPUT
               ,@cErrMsg          OUTPUT      
               ,@cSuggID          OUTPUT  --(yeekung02)
                
              IF @nErrNo = 0   
              BEGIN  
                  GOTO QUIT   
              END  
              ELSE  
              BEGIN  
               -- (james02)
               SET @nErrNo = 0
               SET @cErrMsg = ''
               SET @cSuggSKU = ''
               EXEC rdt.rdt_PickPiece_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTLOC'
                  ,@cPickSlipNo
                  ,@cPickZone
                  ,4
                  ,@nTtlBlncQty      OUTPUT
                  ,@nBlncQty         OUTPUT
                  ,@cSuggLOC         OUTPUT
                  ,@cSuggSKU         OUTPUT
                  ,@cSKUDescr        OUTPUT
                  ,@nSuggQTY         OUTPUT
                  ,@cDisableQTYField OUTPUT
                  ,@cLottableCode    OUTPUT
                  ,@cLottable01      OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
                  ,@cLottable06      OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
                  ,@cLottable11      OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT
                  ,@nErrNo           OUTPUT
                  ,@cErrMsg          OUTPUT    
                  ,@cSuggID          OUTPUT  --(yeekung02)
                  
                  IF @nErrNo = 0    
                  BEGIN    
                       
                     GOTO QUIT   
                  END  
                  ELSE  
                  BEGIN  
                     IF @nSuggQty <> @nQty   
                     BEGIN   
                        SET @nErrNo = 0   
                        SET @cErrMSG = ''   
                        GOTO QUIT  
                     END  
                     ELSE  
                     BEGIN  
                        SET @nErrNo = 0   
                        SET @cErrMSG = ''                           
                        GOTO WCS  
                     END  
                  END  
              END  
           END  
--         IF @nInputKey = 1   
--         BEGIN  
--             SELECT TOP 1 @cOrderKey = OrderKey   
--            FROM dbo.PickDetail WITH (NOLOCK)   
--            WHERE StorerKey = @cStorerKey  
--            AND PickslipNo = @cPickslipNo   
--              
--            SELECT @cOrderType = DocType  
--            FROM dbo.Orders WITH (NOLOCK)   
--            WHERE StorerKey = @cStorerKey  
--            AND OrderKey = @cOrderKey   
--              
--            IF ISNULL(@cOrderType,'') = 'N'  
--            BEGIN  
--               IF EXISTS ( SELECT 1 FROm dbo.PickDetail WITH (NOLOCK)  
--                           WHERE StorerKey = @cStorerKey  
--                           AND PickSlipNo = @cPickSlipNo   
--                           AND DropID = @cDropID  
--                           AND Status = @cPickConfirmStatus  
--                           AND SKU <> @cSKU )  
--               BEGIN  
--                  SET @nErrNo = 123952  
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NotAllowMixSKUInDropID'  
--                  GOTO QUIT  
--               END  
--            END  
--         END  
         /* -- comment by (james01)  
         IF @nInputKey = 0  
         BEGIN  
            --IF ISNULL(@cDropID,'') <> ''   
            --BEGIN  
               GOTO WCS  
            --END  
         END  
         */  
          
      END  
        
      -- WCS Event  
      IF @nStep = 5  
      BEGIN  
         IF @nInputKey = 1  
         BEGIN  
            IF @cOption = '3'  
            BEGIN  
               GOTO WCS  
            END  
           
         END  
      END  
  
      -- Abort Picking (james01)  
      IF @nStep = 8  
      BEGIN  
         IF @nInputKey = 1  
         BEGIN  
            IF @cOption = '1'  
               GOTO WCS  
         END  
      END  
   END  
     
   GOTO QUIT   
     
   WCS:  
   IF @cWCS = '1'  
   BEGIN  
              
            SELECT TOP 1  
               @cWCSOrderKey = OrderKey  
               ,@cWaveKey    = Wavekey   
            FROM dbo.PickDetail WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND PickSlipNo = @cPickSlipNo  
            AND DropID = @cDropID   
              
            SELECT @cDocType = DocType   
            FROM dbo.Orders WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND OrderKey = @cWCSOrderKey  
              
            SELECT @cLoadKey = LoadKey   
            FROM dbo.LoadPlanDetail WITH (NOLOCK)   
            WHERE OrderKey = @cWCSOrderKey   
  
              
            IF @cDocType = 'N'  
            BEGIN  
                 
--               IF EXISTS ( SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)   
--                           WHERE StorerKey = @cStorerKey  
--                           AND Configkey = 'WaveConsoAllocation'  
--                           AND Svalue = '1')  
--                  SET @nNormalWCS = 1   
--               ELSE  
--                  SET @nNormalWCS = 0   
--                 
--               IF @nNormalWCS = 1   
--               BEGIN  
--                 
--                  --SET @cWCSSequence = '01'  
--           
----                  EXECUTE dbo.nspg_GetKey  
----                     'WCSKey',  
----                     10 ,  
----                     @cWCSKey           OUTPUT,  
----                     @bSuccess          OUTPUT,  
----                     @nErrNo            OUTPUT,  
----                     @cErrMsg           OUTPUT  
----                       
----                  IF @bSuccess <> 1  
----                  BEGIN  
----                     SET @nErrNo = 123710  
----                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
----                     GOTO RollBackTran  
----                  END  
--                    
--                    
--  
--   --               DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
--   --               --SELECT DropID FROM dbo.DropID WITH (NOLOCK)  
--   --               --WHERE LoadKey = @cLoadKey    
--   --               --AND   [Status] <> '5'    
--   --                 
--   --               SELECT PD.OrderKey, PD.DropID, CD.Short FROM dbo.PickDetail PD WITH (NOLOCK)   
--   --               INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey     
--   --               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)    
--   --               JOIN dbo.Codelkup CD WITH (NOLOCK) ON CD.StorerKey = PD.StorerKey AND CD.Code = SKU.SUSR3 AND CD.ListName = 'SKUGROUP'   
--   --               WHERE PD.StorerKey = @cStorerkey    
--   --               AND   PD.Status = '5'    
--   --               AND   LPD.LoadKey = @cLoadKey  
--   --               AND CD.ListName = 'SKUGROUP'  
--   --               GROUP BY PD.OrderKey, PD.DropID, CD.Short   
--   --                 
--   --                              
--   --               OPEN CUR_UPD   
--   --               FETCH NEXT FROM CUR_UPD INTO @cPDOrderKey, @cDropID2UPD, @cSKUGroup  
--   --               WHILE @@FETCH_STATUS <> -1  
--   --               BEGIN  
--  
--   --                 SELECT TOP 1 @cSKUGroup = CD.Short FROM dbo.PickDetail PD WITH (NOLOCK)   
--   --                 INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey     
--   --                 --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)    
--   --                 JOIN dbo.Codelkup CD WITH (NOLOCK) ON CD.StorerKey = PD.StorerKey AND CD.Code = SKU.SUSR3 AND CD.ListName = 'SKUGROUP'   
--   --                 WHERE PD.StorerKey = @cStorerkey    
--   --                 AND   PD.Status = '5'    
--   --                 AND   PD.PickSlipNo = @cPickSlipNo   
--   --                 AND CD.ListName = 'SKUGROUP'  
--   --                 AND   PD.DropID = @cDropID   
--   --                 GROUP BY PD.OrderKey, PD.DropID, CD.Short   
--     
--                     -- Sent WCS Data  
--                     SET @nCount = 1   
--                          
--                     DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
--                       
--                     SELECT CD.Short FROM dbo.PickDetail PD WITH (NOLOCK)   
--                      INNER JOIN rdt.rdtPTLStationLOG PTL WITH (NOLOCK) ON PTL.OrderKey = PD.OrderKey   
--                      INNER JOIN dbo.Codelkup CD WITH (NOLOCK) ON PTL.Station = CD.Code AND PTL.StorerKey = CD.StorerKey   
--                     WHERE PD.StorerKey = @cStorerKey   
--                     AND PD.DropID = @cDropID  
--                     AND PD.Status = '3'  
--                     AND PD.WaveKey = @cWaveKey  
--                     AND CD.ListName = 'WCSSTATION'   
--                     GROUP BY CD.Short                     
--                       
--                     OPEN CUR_UPD   
--                     FETCH NEXT FROM CUR_UPD INTO @cWCSStation  
--                     WHILE @@FETCH_STATUS <> -1  
--                     BEGIN    
----                          
----                                       
----                             
----                        SELECT TOP 1 @cPTLStation = Station   
----                        FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
----                        WHERE StorerKey = @cStorerKey   
----                        AND OrderKey = @cWCSOrderKey  
----                        --AND UserDefine02 = @cSKUGroup  
----                          
----      --                  SELECT @cPutawayZone = PutawayZone   
----      --                  FROM dbo.Loc WITH (NOLOCK)   
----      --                  WHERE Facility = @cFacility   
----      --                  AND Loc = @cLoc   
----  
----                          
----                          
----                        SELECT @cWCSStation = Short                  
----                        FROM dbo.Codelkup WITH (NOLOCK)   
----                        WHERE ListName = 'WCSSTATION'  
----                        AND StorerKey = @cStorerKey  
----                        AND Code = @cPTLStation   
--  
--  
--                   
--                        EXECUTE dbo.nspg_GetKey  
--                           'WCSKey',  
--                           10 ,  
--                           @cWCSKey           OUTPUT,  
--                           @bSuccess          OUTPUT,  
--                           @nErrNo            OUTPUT,  
--                           @cErrMsg           OUTPUT  
--                             
--                        IF @bSuccess <> 1  
--                        BEGIN  
--                           SET @nErrNo = 123711  
--                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
--                           GOTO RollBackTran  
--                        END  
--                          
--                        SET @cWCSSequence =  RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
--                        SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cDropID) + '|' + @cWCSKey + '|' + @cWCSStation + '|' + CHAR(3)  
--                          
--  
--                        EXEC [RDT].[rdt_GenericSendMsg]  
--                         @nMobile      = @nMobile        
--                        ,@nFunc        = @nFunc          
--                        ,@cLangCode    = @cLangCode      
--                        ,@nStep        = @nStep          
--                        ,@nInputKey    = @nInputKey      
--                        ,@cFacility    = @cFacility      
--                        ,@cStorerKey   = @cStorerKey     
--                        ,@cType        = @cDeviceType         
--                        ,@cDeviceID    = @cDeviceID  
--                        ,@cMessage     = @cWCSMessage       
--                        ,@nErrNo       = @nErrNo       OUTPUT  
--                        ,@cErrMsg      = @cErrMsg      OUTPUT    
--                          
--                          
--                        --PRINT @nErrNo  
--                        IF @nErrNo <> 0   
--                        BEGIN  
--                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
--                           GOTO RollBackTran    
--                        END  
--                          
--                        SET @nCount = @nCount + 1   
--                          
--                        FETCH NEXT FROM CUR_UPD INTO @cWCSStation  
--                     END  
--                     CLOSE CUR_UPD  
--                     DEALLOCATE CUR_UPD  
--                       
--               END  
--               ELSE IF @nNormalWCS= 0   
               BEGIN  
                    
                  SET @cWCSSequence = '01'  
           
--                  EXECUTE dbo.nspg_GetKey  
--                     'WCSKey',  
--                     10 ,  
--                     @cWCSKey           OUTPUT,  
--                     @bSuccess          OUTPUT,  
--                     @nErrNo            OUTPUT,  
--                     @cErrMsg           OUTPUT  
--                       
--                  IF @bSuccess <> 1  
--                  BEGIN  
--                     SET @nErrNo = 123712  
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
--                     GOTO RollBackTran  
--                  END  
--                    
--                                      
--                  SELECT @cWCSStation = Short                  
--                  FROM dbo.Codelkup WITH (NOLOCK)   
--                  WHERE ListName = 'WCSSTATION'  
--                  AND StorerKey = @cStorerKey  
--                  AND Code = 'B2BPACK2'  
--                    
--                  SET @nCount = 1   
--  
--                  SET @cWCSSequence =  RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
--                  SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cDropID) + '|' + @cWCSKey + '|' + @cWCSStation + '|' + CHAR(3)  
--                    
--                    
--  
--                  EXEC [RDT].[rdt_GenericSendMsg]  
--                   @nMobile      = @nMobile        
--                  ,@nFunc        = @nFunc          
--                  ,@cLangCode    = @cLangCode      
--                  ,@nStep        = @nStep          
--                  ,@nInputKey    = @nInputKey      
--                  ,@cFacility    = @cFacility      
--                  ,@cStorerKey   = @cStorerKey     
--                  ,@cType        = @cDeviceType         
--                  ,@cDeviceID    = @cDeviceID  
--                  ,@cMessage     = @cWCSMessage       
--                  ,@nErrNo       = @nErrNo       OUTPUT  
--                  ,@cErrMsg      = @cErrMsg      OUTPUT    
--                    
--                    
--                  --PRINT @nErrNo  
--                  IF @nErrNo <> 0   
--                  BEGIN  
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
--                     GOTO RollBackTran    
--                  END  
                                 
                                       
                 EXECUTE dbo.nspg_GetKey  
                     'WCSKey',  
                     10 ,  
                     @cWCSKey           OUTPUT,  
                     @bSuccess          OUTPUT,  
                     @nErrNo            OUTPUT,  
                     @cErrMsg           OUTPUT  
                       
                  IF @bSuccess <> 1  
                  BEGIN  
                     SET @nErrNo = 123713  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                     GOTO RollBackTran  
                  END   
      
           
                  SELECT @cLoadPlanLaneDetailLoc = LOC   
                  FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)   
                  WHERE LoadKey = @cLoadKey   
  
                    
                  SELECT @cWCSStation = Short                  
                  FROM dbo.Codelkup WITH (NOLOCK)   
                  WHERE ListName = 'WCSSTATION'  
                  AND StorerKey = @cStorerKey  
                  AND Code = @cLoadPlanLaneDetailLoc   
                    
                  SET @nCount = 1  
  
                  SET @cWCSSequence =  RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
                  SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cDropID) + '|' + @cPickSlipNo + '|' + @cWCSStation + '|' + CHAR(3)  
                    
                    
                    
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
                    
                    
                  --PRINT @nErrNo  
                  IF @nErrNo <> 0   
                  BEGIN  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                     GOTO RollBackTran    
                  END  
                    
                    
               END  
                   
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
               BEGIN  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                     GOTO RollBackTran    
               END  
                    
--                 EXEC [RDT].[rdt_UAWCSSendMsg]  
--                          @nMobile        
--                         ,@nFunc          
--                         ,@cLangCode      
--                         ,@nStep          
--                         ,@nInputKey      
--                         ,@cFacility      
--                         ,@cStorerKey   
--                         ,@cType          
--                         ,@cWCSMessage       
--                         ,@nErrNo       OUTPUT  
--                         ,@cErrMsg      OUTPUT    
                 
                    
            END  
   END  
           
   GOTO QUIT  
  
RollBackTran:  
  
   ROLLBACK TRAN rdt_839ExtUpdSP01 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_839ExtUpdSP01    
        
END  

GO
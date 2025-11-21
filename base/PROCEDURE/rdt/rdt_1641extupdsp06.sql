SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_1641ExtUpdSP06                                  */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Called from: rdtfnc_Pallet_Build                                     */      
/*                                                                      */      
/* Purpose: Build pallet & palletdetail                                 */      
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author    Purposes                                  */      
/* 2020-01-31  1.0  James     WMS-11721. Created                        */    
/* 2020-12-23  1.1  Chermaine WMS-15765 Add print lable (cc01)          */  
/* 2022-03-31  1.2  Ung       WMS-19340 Add shipping label              */  
/* 2022-05-26  1.3  James     WMS-19695 Change pallet label printing    */
/*                            logic (james01)                           */
/* 2023-02-10  1.1  YeeKung  WMS-21738 Add UCC column (yeekung01)        */
/************************************************************************/      
      
CREATE   PROC [RDT].[rdt_1641ExtUpdSP06] (      
   @nMobile     INT,      
   @nFunc       INT,      
   @cLangCode   NVARCHAR( 3),      
   @cUserName   NVARCHAR( 15),      
   @cFacility   NVARCHAR( 5),      
   @cStorerKey  NVARCHAR( 15),      
   @cDropID     NVARCHAR( 20),
   @cUCCNo      NVARCHAR( 20),  
   @nErrNo      INT          OUTPUT,      
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max      
) AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
       
   DECLARE  @nStep         INT,    
            @nInputKey     INT,    
            @nTranCount    INT,    
            @bSuccess      INT,    
            @nPD_Qty       INT,    
            @cSKU          NVARCHAR( 20),      
            @cRouteCode    NVARCHAR( 30),    
            @cOrderKey     NVARCHAR( 10),    
            @cPickSlipNo   NVARCHAR( 10),    
            @cPalletLineNumber   NVARCHAR( 5),    
            @cSortCode   NVARCHAR(13),    
            @cRoute      NVARCHAR(10),    
            @cExternOrderKey NVARCHAR(30),    
            @cLot            NVARCHAR(10),     
            @cFromLoc        NVARCHAR(10),     
            @cFromID         NVARCHAR(18),     
            @nPickedQty      INT,     
            @cPickedQty      INT,      
            @cTaskDetailKey  NVARCHAR(10),    
            @cCaseID         NVARCHAR(20),    
            @nQty            INT,    
            @cToLoc          NVARCHAR(10),    
            @cPackDropID     NVARCHAR(20),    
            @nPackedQty      INT,    
            @cPaperPrinter   NVARCHAR(10),    
            @cLabelPrinter   NVARCHAR(10),    
            @nQtyBalance     INT,    
            @nQtyToMove      INT,   
            @nSKU_Count      INT,  
            @cUserDefine09   NVARCHAR(10),  
            @nPrintPLTSRLABEL    INT,  
            @nNoOfCopy       INT,  
            @cCompany        NVARCHAR(45) --(cc01)  
  
   DECLARE @cUDF01          NVARCHAR(60)    
   DECLARE @cUDF02          NVARCHAR(60)    
   DECLARE @cUDF03          NVARCHAR(60)    
   DECLARE @cUDF04          NVARCHAR(60)    
   DECLARE @cUDF05          NVARCHAR(60)     
  
   SELECT @nStep = Step,    
          @nInputKey = InputKey,    
          @cPaperPrinter = Printer_Paper,   
          @cLabelPrinter = Printer  
   FROM RDT.RDTMobRec WITH (NOLOCK)    
   WHERE Mobile = @nMobile    
  
   SET @nPrintPLTSRLABEL = 0  
  
   SET @nTranCount = @@TRANCOUNT    
    
   BEGIN TRAN    
   SAVE TRAN rdt_1641ExtUpdSP06    
       
   IF @nStep = 3    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         SELECT    
            @cUDF01 = LEFT( ISNULL( UDF01, ''), 20),     
            @cUDF02 = LEFT( ISNULL( UDF02, ''), 20),     
            @cUDF03 = LEFT( ISNULL( UDF03, ''), 20),     
            @cUDF04 = LEFT( ISNULL( UDF04, ''), 20),     
            @cUDF05 = LEFT( ISNULL( UDF05, ''), 20)    
         FROM DropID WITH (NOLOCK)     
         WHERE DropID = @cDropID    
  
         -- Check if pallet id exists before    
         IF NOT EXISTS ( SELECT 1     
                         FROM dbo.Pallet WITH (NOLOCK)    
                         WHERE PalletKey = @cDropID)  
         BEGIN    
            -- Insert Pallet info    
            INSERT INTO dbo.Pallet (PalletKey, StorerKey) VALUES (@cDropID, @cStorerKey)    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 147951    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPLTFail    
               GOTO RollBackTran    
            END    
         END    
    
         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)     
                     WHERE StorerKey = @cStorerKey    
                     AND   CaseId = @cUCCNo    
                     AND  [Status] < '9')    
        BEGIN    
            SET @nErrNo = 147952    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonExist    
            GOTO RollBackTran    
         END    
    
         -- Insert PalletDetail     
         DECLARE CUR_PalletDetail CURSOR LOCAL READ_ONLY FAST_FORWARD FOR     
         SELECT PickSlipNo, SKU, ISNULL( SUM( Qty), 0)    
         FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE StorerKey = @cStorerKey    
         AND   LabelNo = @cUCCNo    
         GROUP BY PickSlipNo, SKU    
         OPEN CUR_PalletDetail    
         FETCH NEXT FROM CUR_PalletDetail INTO @cPickSlipNo, @cSKU, @nPD_Qty    
         WHILE @@FETCH_STATUS <> -1     
         BEGIN    
            SELECT @cOrderKey = OrderKey     
            FROM dbo.PackHeader WITH (NOLOCK)     
            WHERE PickSlipNo = @cPickSlipNo     
                
            SELECT @cRoute = ISNULL(Route,'')     
                  ,@cExternOrderKey = ExternOrderKey    
                  ,@cUserDefine09 = ISNULL(UserDefine09,'')  
            FROM dbo.Orders WITH (NOLOCK)     
            WHERE StorerKey = @cStorerKey    
            AND OrderKey = @cOrderKey     
                
            IF ISNULL(@cUDF01,'')  IN ( '' , '1' )   
               SET @cSortCode = RTRIM(@cRoute) + RIGHT(RTRIM(@cExternOrderKey),5)    
            ELSE IF ISNULL(@cUDF01,'')  = '2'   
               SET @cSortCode = RTRIM(@cRoute) + RIGHT(RTRIM(@cUserDefine09),5)    
    
            INSERT INTO dbo.PalletDetail     
            (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Qty, UserDefine01, UserDefine02)     
            VALUES    
            (@cDropID, 0, @cUCCNo, @cStorerKey, @cSKU, @nPD_Qty, @cSortCode, @cOrderKey)    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 147953    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPLTDetFail    
               GOTO RollBackTran    
            END    
                
            FETCH NEXT FROM CUR_PalletDetail INTO @cPickSlipNo, @cSKU, @nPD_Qty    
         END    
         CLOSE CUR_PalletDetail          
         DEALLOCATE CUR_PalletDetail    
      END    
   END    
    
   IF @nStep = 4    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)    
                         WHERE StorerKey = @cStorerKey    
                         AND   PalletKey = @cDropID    
                         AND  [Status] < '9')    
         BEGIN    
            SET @nErrNo = 147954    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLTKeyNotFound    
            GOTO RollBackTran    
         END    
  
         -- Move Inventory     
         DECLARE CUR_PalletBuild CURSOR LOCAL READ_ONLY FAST_FORWARD FOR     
         SELECT PackDet.DropID,PD.SKU, SUM(PD.Qty)    
         FROM dbo.PalletDetail PD WITH (NOLOCK)     
         INNER JOIN dbo.PackDetail PackDet WITH (NOLOCK) ON PackDet.StorerKey = PD.StorerKey AND PackDet.LabelNo = PD.CaseID    
         WHERE PD.StorerKey = @cStorerKey    
         AND PD.PalletKey = @cDropID    
         AND PD.Status = '0'    
         Group by PackDet.DropID, PD.SKU     
         OPEN CUR_PalletBuild    
         FETCH NEXT FROM CUR_PalletBuild INTO @cPackDropID, @cSKU, @nPackedQty    
         WHILE @@FETCH_STATUS <> -1     
         BEGIN    
            SET @cTaskDetailKey = ''     
            SET @cLot = ''    
            SET @cFromLoc = ''    
            SET @cFromID  = ''    
            SET @cPickedQty = ''  
            SET @nQtyBalance = @nPackedQty    
    
            SELECT @cToLoc = Code    
            FROM dbo.Codelkup WITH (NOLOCK)     
            WHERE ListName = 'LOGIPLTLOC'    
            AND StorerKey = @cStorerKey     
                  
            DECLARE CUR_PalletBuild_GroupBy_Loc CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            SELECT Lot, Loc, ID, ISNULL( SUM( QTY), 0)    
            FROM dbo.PickDetail WITH (NOLOCK)     
            WHERE StorerKey = @cStorerKey    
            AND DropID = @cPackDropID    
            AND SKU = @cSKU    
            AND LOC <> @cToLoc    
            Group by Lot, Loc, ID    
            OPEN CUR_PalletBuild_GroupBy_Loc       
            FETCH NEXT FROM CUR_PalletBuild_GroupBy_Loc INTO @cLot, @cFromLoc, @cFromID, @cPickedQty    
            WHILE @@FETCH_STATUS <> -1    
            BEGIN     
               IF @nQtyBalance > @cPickedQty    
                  SET @nQtyToMove =  @cPickedQty    
               ELSE    
                  SET @nQtyToMove =  @nQtyBalance    
    
               -- Move by SKU      
               EXECUTE rdt.rdt_Move      
                  @nMobile     = @nMobile,      
                  @cLangCode   = @cLangCode,      
                  @nErrNo      = @nErrNo  OUTPUT,      
                  @cErrMsg     = @cErrMsg OUTPUT,      
                  @cSourceType = 'rdt_1641ExtUpdSP06',      
                  @cStorerKey  = @cStorerKey,      
                  @cFacility   = @cFacility,      
                  @cFromLOC    = @cFromLoc,      
                  @cToLOC      = @cToLoc, -- Final LOC      
                  @cFromID     = @cFromID,      
                  @cToID       = @cDropID,      
                  @nQTYPick    = @nQtyToMove,    
                  @nQTY        = @nQtyToMove,    
                  @cFromLOT    = @cLOT,      
                  @nFunc       = @nFunc,    
                  @cDropID     = @cPackDropID,    
                  @cSKU        = @cSKU    
                       
               IF @nErrNo <> 0      
                  GOTO RollBackTran      
    
               SET @nQtyBalance = @nQtyBalance - @cPickedQty    
                     
               IF @nQtyBalance <= 0     
                  BREAK    
    
               FETCH NEXT FROM CUR_PalletBuild_GroupBy_Loc INTO @cLot, @cFromLoc, @cFromID, @cPickedQty     
            END    
            CLOSE CUR_PalletBuild_GroupBy_Loc   
            DEALLOCATE CUR_PalletBuild_GroupBy_Loc   
                   
            FETCH NEXT FROM CUR_PalletBuild INTO @cPackDropID, @cSKU, @nPackedQty    
         END    
         CLOSE CUR_PalletBuild          
         DEALLOCATE CUR_PalletBuild    
    
         UPDATE dbo.PALLETDETAIL WITH (ROWLOCK) SET     
            [Status] = '9'    
         WHERE StorerKey = @cStorerKey    
         AND   PalletKey = @cDropID    
         AND   [Status] < '9'    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 147955    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPLTDetFail    
            GOTO RollBackTran    
         END    
    
         UPDATE dbo.PALLET WITH (ROWLOCK) SET     
            [Status] = '9'    
         WHERE StorerKey = @cStorerKey    
         AND   PalletKey = @cDropID    
         AND   [Status] < '9'    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 147956    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPLTFail    
            GOTO RollBackTran             END    
             
         SET @nPrintPLTSRLABEL = 1  
           
         --(cc01)-- print label when close pallet  
         DECLARE @nPrintLGPALLETLB INT  
         SET @nSKU_Count = 0    
    
         SELECT @nSKU_Count = COUNT( DISTINCT SKU)    
         FROM dbo.palletdetail WITH (NOLOCK)      
            WHERE StorerKey = @cStorerKey      
            AND   PalletKey = @cDropID    
  
         IF @nSKU_Count = 1    
         BEGIN    
            SET @nPrintLGPALLETLB = '1'  
  
            DECLARE CUR_pallet CURSOR LOCAL READ_ONLY FAST_FORWARD FOR     
            SELECT SKU, UserDefine02  
            FROM dbo.palletdetail WITH (NOLOCK)    
            WHERE StorerKey = @cStorerKey    
            AND   PalletKey = @cDropID    
         
            OPEN CUR_pallet    
            FETCH NEXT FROM CUR_pallet INTO @cSKU, @cOrderKey   
            WHILE @@FETCH_STATUS <> -1     
            BEGIN    
               SELECT @cCompany = C_Company,@cUDF03 = UserDefine03 FROM dbo.Orders WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND OrderKey = @cOrderKey  
  
               --IF NOT EXISTS (select TOP 1 1 from CODELKUP WITH (NOLOCK) where listname = 'LGRDTSKU' AND Storerkey =@cStorerKey AND [Description] = @cSKU)  
               --BEGIN  
               --   SET @nPrintLGPALLETLB = '0'  
               --   Break  
               --END  
               
               IF NOT EXISTS ( SELECT 1 FROM dbo.SKU SKU WITH (NOLOCK)
                               JOIN dbo.SKUINFO SI WITH (NOLOCK) ON 
                                 (SKU.StorerKey = SI.StorerKey AND SKU.SKU = SI.SKU)
                               WHERE SKU.StorerKey = @cStorerKey 
                               AND   SKU.SKU = @cSKU
                               AND   SI.ExtendedField12 = 'Channel')
               BEGIN  
                  SET @nPrintLGPALLETLB = '0'  
                  BREAK  
               END  

               IF NOT EXISTS (select TOP 1 1 from CODELKUP WITH (NOLOCK) where listname = 'LGCUSTOMER' AND Storerkey =@cStorerKey AND [Description] = @cCompany AND UDF01 = @cUDF03)  
               BEGIN  
                  SET @nPrintLGPALLETLB = '0'  
                  Break  
               END  
                   
               FETCH NEXT FROM CUR_pallet INTO @cSKU, @cOrderKey    
            END    
            CLOSE CUR_pallet          
            DEALLOCATE CUR_pallet  
                 
  
            IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)     
                        WHERE StorerKey = @cStorerKey     
                        AND ReportType = 'LGPALLETLB' )  
            BEGIN  
               IF @nPrintLGPALLETLB = '1'  
               BEGIN  
                  DECLARE @tLGLblLis AS VariableTable    
                  DELETE FROM @tLGLblLis  
                  INSERT INTO @tLGLblLis (Variable, Value) VALUES ( '@cDropID', @cDropID)    
                   
                  -- Print label    
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,     
                     'LGPALLETLB', -- Report type    
                     @tLGLblLis, -- Report params    
                     'rdt_1641ExtUpdSP06',     
                     @nErrNo  OUTPUT,    
                     @cErrMsg OUTPUT    
                      
                  IF @nErrNo <> 0    
                     GOTO RollBackTran                  
               END  
            END  
         END  
           
         -- Ship label    
         DECLARE @cShipLabel NVARCHAR( 10)  
         SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)    
         IF @cShipLabel = '0'    
            SET @cShipLabel = ''   
         IF @cShipLabel <> ''     
         BEGIN    
            -- Common params    
            DECLARE @tShipLabel AS VariableTable    
            INSERT INTO @tShipLabel (Variable, Value) VALUES     
               ( '@cDropID',     @cDropID)  
    
            -- Print label    
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,     
               @cShipLabel, -- Report type    
               @tShipLabel, -- Report params    
               'rdt_1641ExtUpdSP06',     
               @nErrNo  OUTPUT,    
               @cErrMsg OUTPUT    
            IF @nErrNo <> 0    
               GOTO RollBackTran    
         END  
      END    
   END    
  
   IF @nStep = 6    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN                
         SET @nNoOfCopy = 1  
         IF EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL PD WITH (NOLOCK)  
                     JOIN dbo.ORDERS O WITH (NOLOCK)   
                        ON ( PD.UserDefine02 = O.OrderKey AND PD.StorerKey = O.StorerKey)  
                     WHERE PD.PalletKey = @cDropID  
                     AND   PD.StorerKey = @cStorerKey  
                     AND   NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP CLK WITH (NOLOCK)  
                                        WHERE CLK.LISTNAME = 'LOGIONEOBL'  
                                        AND   CLK.Code = O.ConsigneeKey  
                                        AND   CLK.Storerkey = O.StorerKey))  
         BEGIN  
            SET @nNoOfCopy = 2  
         END  
  
         WHILE @nNoOfCopy > 0  
         BEGIN  
            IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)     
                        WHERE StorerKey = @cStorerKey     
                        AND ReportType = 'OBLIST' )     
            BEGIN     
               DECLARE @tOutBoundLis AS VariableTable    
               DELETE FROM @tOutBoundLis  
               INSERT INTO @tOutBoundLis (Variable, Value) VALUES ( '@cDropID', @cDropID)    
                
               -- Print label    
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,     
                  'OBLIST', -- Report type    
                  @tOutBoundLis, -- Report params    
                  'rdt_1641ExtUpdSP06',     
                  @nErrNo  OUTPUT,    
                  @cErrMsg OUTPUT    
                   
               IF @nErrNo <> 0    
                  GOTO RollBackTran    
            END  
  
            SET @nNoOfCopy = @nNoOfCopy - 1  
         END    
      END    
   END    
     
   GOTO Quit    
    
   RollBackTran:    
      ROLLBACK TRAN rdt_1641ExtUpdSP06    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN rdt_1641ExtUpdSP06    
  
   IF @nPrintPLTSRLABEL = 1    
   BEGIN    
      --If a pallet is with serialno ends with æ9Æ or æCÆ, then do not release the label out.  
      --OPS will not print the pallet with 9/C serial no.  
      IF NOT EXISTS ( SELECT 1   
                        FROM dbo.PALLETDETAIL PLTD WITH (NOLOCK)  
                        JOIN dbo.PackDetail PD WITH (NOLOCK)   
                           ON ( PLTD.StorerKey = PD.StorerKey AND PLTD.CaseId = PD.LabelNo)  
                        JOIN dbo.SerialNo SR WITH (NOLOCK)   
                           ON ( PD.StorerKey = SR.StorerKey AND PD.PickSlipNo = SR.PickSlipNo   
                           AND PD.CartonNo = SR.CartonNo AND PD.SKU = SR.SKU)  
                        WHERE PLTD.PalletKey = @cDropID  
                        AND   RIGHT( RTRIM( SR.SerialNo), 1) IN ( '9', 'C'))  
      BEGIN  
         -- If pallet contain only value from orders.userdefine10  
         IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)   
                           WHERE StorerKey = @cStorerKey  
                           AND   UserDefine10 NOT IN   
                           (     SELECT DISTINCT Code   
                                 FROM dbo.CODELKUP CLP WITH (NOLOCK)   
                                 WHERE Listname = 'LGKRPLTLBL'   
                                 AND   Storerkey = @cStorerKey)  
                           AND   OrderKey IN   
                           (     SELECT DISTINCT UserDefine02   
                                 FROM dbo.PALLETDETAIL WITH (NOLOCK)   
                                 WHERE PalletKey = @cDropID))  
         BEGIN  
            SET @nSKU_Count = 0  
  
            SELECT @nSKU_Count = COUNT( DISTINCT PKD.SKU)  
            FROM dbo.PALLETDETAIL PLD WITH (NOLOCK)  
            JOIN dbo.PackDetail PKD WITH (NOLOCK)   
               ON ( PLD.StorerKey = PKD.StorerKey AND PLD.CaseId= PKD.LabelNo)  
            WHERE PLD.PalletKey = @cDropID  
                  
            -- In this pallet, all pallet only have one SKU  
            IF @nSKU_Count = 1  
            BEGIN  
               DECLARE @tPalletLabel AS VariableTable    
               INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cDropID', @cDropID)    
                
               -- Print label    
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',   
                  'PLTSRLABEL', -- Report type    
                  @tPalletLabel, -- Report params    
                  'rdt_1641ExtUpdSP06',     
                  @nErrNo  OUTPUT,    
                  @cErrMsg OUTPUT    
                   
               IF @nErrNo <> 0    
                  GOTO Fail    
            END  
         END  
      END  
   END    
      
Fail:      
END      

GO
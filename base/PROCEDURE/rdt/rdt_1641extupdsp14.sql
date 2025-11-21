SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_1641ExtUpdSP14                                  */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Called from: rdtfnc_Pallet_Build                                     */      
/*                                                                      */      
/* Purpose: Build pallet & palletdetail                                 */ 
/*          05->13                                                      */     
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2023-05-05   1.0 Yeekung  WMS-22419 Created                          */
/************************************************************************/      
      
CREATE   PROC [RDT].[rdt_1641ExtUpdSP14] (      
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
            @nPD_Qty       INT,    
            @cSKU          NVARCHAR( 20),    
            @cCartonID     NVARCHAR( 20),    
            @cOrderKey     NVARCHAR( 10),  
            @cCurOrderKey  NVARCHAR( 10),
            @cPickSlipNo   NVARCHAR( 10),    
            @cPalletLineNumber   NVARCHAR( 5),    
            @cCaseID         NVARCHAR(20),    
            @nQty            INT,    
            @cOtherPalletKey NVARCHAR( 30) = '',  
            @cSUSR1          NVARCHAR( 20) = '',  
            @cConsigneeKey   NVARCHAR( 15) = '',  
            @cOption         NVARCHAR( 1) = '',  
            @cOrderGroup     NVARCHAR( 20) = '',  
            @cC_ISOCntryCode NVARCHAR( 10) = '',  
            @cUserDefine01   NVARCHAR( 30) = '',  
            @cOrders_M_Company   NVARCHAR( 45) = '',  
            @cShipperKey      NVARCHAR( 15) = '',  
            @cLoc             NVARCHAR(20),
            @cFromLoc         NVARCHAR(20),
            @cFromID          NVARCHAR(20)
                   
    
   SELECT @nStep = Step,    
          @nInputKey = InputKey,    
          @cCartonID = I_Field03,
          @cLoc = V_string29    
   FROM RDT.RDTMobRec WITH (NOLOCK)    
   WHERE Mobile = @nMobile    
    
   SET @nTranCount = @@TRANCOUNT    

   SET @cLoc = rdt.RDTGetConfig( @nFunc, 'MoveToLoc', @cStorerKey)
    
   BEGIN TRAN    
   SAVE TRAN rdt_1641ExtUpdSP14    
       
   IF @nStep = 3    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
  
    
         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)     
                     WHERE StorerKey = @cStorerKey    
                     AND   CaseId = @cUCCNo    
                     AND  [Status] < '9')    
        BEGIN    
            SET @nErrNo = 202201    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonExist    
            GOTO RollBackTran    
         END    
  
         -- Check if pallet id exists before    
         IF NOT EXISTS ( SELECT 1     
                         FROM dbo.Pallet WITH (NOLOCK)    
                         WHERE PalletKey = @cDropID)  
         BEGIN    
            -- Insert Pallet info    
            INSERT INTO dbo.Pallet (PalletKey, StorerKey) VALUES (@cDropID, @cStorerKey)    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 202202    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPLTFail    
               GOTO RollBackTran    
            END    
         END    

         SELECT @cSKU = SKU,
               @nPD_Qty = qty
         FROM UCC (nolock)
         WHERE UCCNO = @cUCCNo
            AND Storerkey = @cStorerKey


         SELECT top 1 @cOrderkey=PD.Orderkey
         FROM dbo.PickDetail PD (NOLOCK)
         where PD.Storerkey = @cStorerKey
            AND PD.ID = @cDropID
            AND Status IN ('3','5')

         INSERT INTO dbo.PalletDetail     
         (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Qty, UserDefine01, UserDefine02,Loc, Orderkey)     
         VALUES    
         (@cDropID, 0, @cUCCNo, @cStorerKey, @cSKU, @nPD_Qty, SUBSTring(@cUCCNo,charindex('-', @cUCCNo)+ 1, 20 ), SUBSTring(@cUCCNo,1, charindex('-', @cUCCNo)- 1 ),@cLoc,'')    
          
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 202203    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPLTDetFail                      
            GOTO RollBackTran    
         END   

      END    
   END    
  
   IF @nStep = 4    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         SELECT @cOption = I_Field01    
         FROM RDT.RDTMobRec WITH (NOLOCK)    
         WHERE Mobile = @nMobile    
  
         IF @cOption = '1'  
         BEGIN  
            IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)    
                            WHERE StorerKey = @cStorerKey    
                            AND   PalletKey = @cDropID    
                            AND  [Status] < '9')    
            BEGIN    
               SET @nErrNo = 202204    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLTKeyNotFound    
               GOTO RollBackTran    
            END   
  
            IF NOT EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)    
                            WHERE StorerKey = @cStorerKey    
                            AND   PalletKey = @cDropID    
                            AND  [Status] < '9')    
            BEGIN    
              SET @nErrNo = 202205    
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Ctn Scanned    
              GOTO RollBackTran    
            END   


  
            UPDATE dbo.PALLETDETAIL WITH (ROWLOCK) SET     
               [Status] = '9'   
            WHERE StorerKey = @cStorerKey    
            AND   PalletKey = @cDropID    
            AND   [Status] < '9'    
    
            IF @@ERROR <> 0    
           BEGIN    
               SET @nErrNo = 202206    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PLTDet Err    
               GOTO RollBackTran    
            END    
    
            DECLARE CUR_PackConfirm CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PickSlipNo   
            FROM dbo.Packdetail PD WITH (NOLOCK)   
            JOIN dbo.PALLETDETAIL PDL WITH (NOLOCK) on (PD.StorerKey =PDL.StorerKey AND PD.SKU = PDL.SKU AND PD.LabelNo = PDL.Caseid)
            WHERE PDL.StorerKey = @cStorerKey    
               AND   PDL.palletkey = @cDropID
            GROUP BY PickSlipNo

            OPEN CUR_PackConfirm    
            FETCH NEXT FROM CUR_PackConfirm INTO @cPickSlipNo 
            WHILE @@FETCH_STATUS <> -1     
            BEGIN   

               UPDATE dbo.PackHeader WITH (ROWLOCK) SET     
                  [Status] = '9'    
               WHERE PickSlipNo = @cPickSlipNo    
                  AND Storerkey = @cStorerKey

               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 202208    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPHFail    
                  GOTO RollBackTran    
               END  
               
               FETCH NEXT FROM CUR_PackConfirm INTO @cPickSlipNo 
            END
            CLOSE CUR_PackConfirm          
            DEALLOCATE CUR_PackConfirm 

            UPDATE dbo.PALLET WITH (ROWLOCK) SET     
               [Status] = '9'    
            WHERE StorerKey = @cStorerKey    
            AND   PalletKey = @cDropID    
            AND   [Status] < '9'    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 202207    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close Plt Fail    
               GOTO RollBackTran    
            END    


         END  
      END  
   END  
   GOTO Quit    
    
   RollBackTran:    
      ROLLBACK TRAN rdt_1641ExtUpdSP14    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN rdt_1641ExtUpdSP14    
    
      
Fail:      
END      

GO
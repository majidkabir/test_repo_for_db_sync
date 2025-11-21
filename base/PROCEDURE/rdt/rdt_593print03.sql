SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdt_593Print03                                         */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2015-12-09 1.0  ChewKP   SOS#358738 Created                             */  
/* 2016-10-31 1.1  ChewKP   WMS-598 - Add new options (ChewKP01)           */
/* 2017-03-23 1.2  ChewKP   WMS-1391 - Add NoOfCopy for Option 6 (ChewKP02)*/
/* 2017-06-05 1.3  ChewKP   WMS-2117 - Add Options and Changes (ChewKP03)  */
/* 2017-08-15 1.4  ChewKP   WMS-2680 - Add Option 8 (ChewKP04)             */
/* 2018-05-16 1.5  ChewKP   WMS-5053 - Add RFID (ChewKP05)                 */
/* 2018-09-25 1.6  ChewKP   WMS-6446 - Update Option 8 (ChewKP06)          */ 
/* 2020-05-10 1.7  James    WMS-13273 Add new param to option 5 (james01)  */
/* 2020-06-05 1.8  James    WMS-13504 Cater multiple printing process      */
/*                          process (james02)                              */
/* 2020-07-14 1.9  Chermaine  WMS-14164 - Check Weight Range (cc01)        */
/***************************************************************************/    
    
CREATE PROC [RDT].[rdt_593Print03] (    
   @nMobile    INT,    
   @nFunc      INT,    
   @nStep      INT,    
   @cLangCode  NVARCHAR( 3),    
   @cStorerKey NVARCHAR( 15),    
   @cOption    NVARCHAR( 1),    
   @cParam1    NVARCHAR(20),  -- OrderKey 
   @cParam2    NVARCHAR(20),  
   @cParam3    NVARCHAR(20),     
   @cParam4    NVARCHAR(20),    
   @cParam5    NVARCHAR(20),    
   @nErrNo     INT OUTPUT,    
   @cErrMsg    NVARCHAR( 20) OUTPUT    
)    
AS    
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF     
    
   DECLARE @b_Success     INT    
       
   DECLARE @cDataWindow   NVARCHAR( 50)  
         , @cManifestDataWindow NVARCHAR( 50)  
         
   DECLARE @cTargetDB     NVARCHAR( 20)    
   DECLARE @cLabelPrinter NVARCHAR( 10)    
   DECLARE @cPaperPrinter NVARCHAR( 10)    
   DECLARE @cUserName     NVARCHAR( 18)     
   DECLARE @cLabelType    NVARCHAR( 20)    
   
   DECLARE @cToteNo       NVARCHAR( 20)
          ,@cCartonType   NVARCHAR( 10)
          ,@nTranCount    INT   
          ,@cGenLabelNoSP NVARCHAR(30)  
          ,@cPickDetailKey NVARCHAR(10)
          ,@cPickSlipNo   NVARCHAR(10)
          ,@cOrderKey     NVARCHAR(10)
          ,@cLabelNo       NVARCHAR(20)
          ,@nCartonNo     INT
          ,@cLabelLine    NVARCHAR(5)
          ,@cExecStatements   NVARCHAR(4000)         
          ,@cExecArguments    NVARCHAR(4000)  
          ,@cSKU           NVARCHAR(20)  
          ,@nTTL_PackedQty INT
          ,@nTTL_PickedQty INT
          ,@nQty           INT
          ,@cFacility      NVARCHAR(5)
          ,@nTotalPackedQty INT
          ,@cType          NVARCHAR(10)
          ,@cLoadKey       NVARCHAR(10) 
          ,@cTTLWeight     NVARCHAR(10) 
          ,@nFocusParam    INT 
          ,@bsuccess       INT 
          --,@b_success      INT
          ,@nSKUCnt        INT
          ,@nNoOfCopy      INT
          ,@cCountry       NVARCHAR(30)
          ,@cUPC           NVARCHAR(20)
          ,@nLength        INT
          ,@cPrinterName   NVARCHAR(100) 
          ,@cWinPrinter    NVARCHAR(128)
          ,@cFileName      NVARCHAR( 50)  
          ,@cPrintCommand  NVARCHAR(MAX)    
          ,@cTrackingNo    NVARCHAR(20) 
          ,@cFilePath      NVARCHAR(100) 
          ,@cPrintFilePath NVARCHAR(100)   
          ,@cPrinterInGroup NVARCHAR( 10)   
          ,@cReportType    NVARCHAR( 10)  
          ,@cProcessType   NVARCHAR( 15) 
          ,@cExternOrderKey NVARCHAR(30)  
          ,@cOrderGroup     NVARCHAR(20)
   
   DECLARE @tOutBoundList AS VariableTable  
             
   DECLARE  @fCartonWeight FLOAT
           ,@fCartonLength FLOAT
           ,@fCartonHeight FLOAT
           ,@fCartonWidth  FLOAT
           ,@fStdGrossWeight FLOAT
           ,@fCartonTotalWeight FLOAT
           ,@fCartonCube   FLOAT
           ,@nFromCartonNo INT
           ,@nToCartonNo   INT
           ,@cOrderType    NVARCHAR(10)
           ,@bPrintManifest NVARCHAR(1)
           ,@cCartonLabelNo NVARCHAR(20)
           ,@cCCountry      NVARCHAR(30)
           ,@cAltSKU        NVARCHAR(20)
           ,@cStyle         NVARCHAR(20) 
           ,@cLanguageCode  NVARCHAR(5) 
           ,@nPreSetNoOfCopy INT
           ,@cConsigneeKey  NVARCHAR(15)
           ,@cRFID          NVARCHAR(20)
           ,@cShipperKey    NVARCHAR(15)
           ,@cPaperType     NVARCHAR( 10)
   
   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank    
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''    
   BEGIN    
      SET @nErrNo = 95251    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
      GOTO Quit    
   END    

   SET @nTranCount = @@TRANCOUNT      
         
   BEGIN TRAN      
   SAVE TRAN rdt_593Print03      
      
   IF @cOption = '1' 
   BEGIN 
         
      SET @cToteNo      = @cParam1
      SET @cCartonType  = @cParam2
      SET @cTTLWeight   = @cParam3
      SET @cRFID        = @cParam4
      
      --SELECT @cStorerKey '@cStorerKey', @cToteNo '@cToteNo' , @cCartonType '@cCartonType' , @cTTLWeight '@cTTLWeight' , @cRFID '@cRFID' 

      SET @cGenLabelNoSP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo', @cStorerkey)          
             
            
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = ISNULL(RTRIM(@cGenLabelNoSP),'') AND type = 'P')        
      BEGIN      
                    
            SET @nErrNo = 95456      
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'GenLblSPNotFound'      
            --SET @cErrMsg = 'GenLblSPNotFound'      
            GOTO RollBackTran      
      END 
   
      
      -- Check blank    
      IF ISNULL(RTRIM(@cToteNo), '') = ''    
      BEGIN    
         SET @nErrNo = 95451    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ToteNoReq  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         SET @nFocusParam = 2
         GOTO RollBackTran    
      END    
      
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND DropID = @cToteNo
                      AND Status < '5' ) 
      BEGIN    
         SET @nErrNo = 95452   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidTote  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         SET @nFocusParam = 2
         GOTO RollBackTran    
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND DropID = @cToteNo
                      AND Status = '5' ) 
      BEGIN    
         SET @nErrNo = 95468   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidTote  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         SET @nFocusParam = 2
         GOTO RollBackTran    
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                      WHERE DropID = @cToteNo
                      AND Status IN ( '3', '5') )
      BEGIN
         SET @nErrNo = 95469
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidTote  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
         SET @nFocusParam = 2
         GOTO RollBackTran  
      END
      
      IF ISNULL(RTRIM(@cCartonType), '') = ''    
      BEGIN    
         SET @nErrNo = 95453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --CartonTypeReq  
         --EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param2
         SET @nFocusParam = 4
         GOTO RollBackTran    
      END  
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Cartonization WITH (NOLOCK)
                      WHERE CartonType = @cCartonType ) 
      BEGIN    
         SET @nErrNo = 95454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidCtnType  
         --EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param2
         SET @nFocusParam = 4
         GOTO RollBackTran    
      END  
      
      IF ISNULL(@cTTLWeight,'' )  = ''
      BEGIN    
         SET @nErrNo = 95476
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --WeightReq  
         --EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param3\
         SET @nFocusParam = 6
         GOTO RollBackTran    
      END  
      
      
      IF rdt.rdtIsValidQTY( @cTTLWeight, 21) = 0
      BEGIN
         SET @nErrNo = 95477
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvalidWeight'
         --EXEC rdt.rdtSetFocusField @nMobile, 6
         SET @nFocusParam = 6
         GOTO RollBackTran
      END
      
      DECLARE @fTTLWeight DECIMAL (5,2) --(cc01)
      
      SET @fTTLWeight = CAST(@cTTLWeight AS DECIMAL(18,2))
      
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'WgtChk', @fTTLWeight) = 0  --(cc01)
      BEGIN  
         SET @nErrNo = 95500  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WgtOutOfRange  
         SET @nFocusParam = 6
         GOTO RollBackTran  
      END
      
      SELECT @cType = O.Type
      FROM dbo.PickDetail PD WITH (NOLOCK)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey AND O.StorerKey = PD.StorerKey
      WHERE PD.StorerKey = @cStorerKey
      AND PD.DropID = @cToteNo
      AND PD.Status = '5'
    
      
      -- (ChewKP05) 
      IF ISNULL(@cRFID ,'' ) = ''
      BEGIN
         

         IF EXISTS ( SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) 
                     WHERE ListName = 'LULURFID'
                     AND StorerKey = @cStorerKey
                     AND Code = @cType)
         BEGIN
            SET @nErrNo = 95492
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'RFIDReq'
            --EXEC rdt.rdtSetFocusField @nMobile, 6
            SET @nFocusParam = 8
            GOTO RollBackTran
         END
      END
      
      IF ISNULL(@cRFID, '' ) <> '' 
      BEGIN
         
         SELECT @nLength = Short 
         FROM dbo.Codelkup WITH (NOLOCK) 
         WHERE ListName = 'LULURFID'
         AND StorerKey = @cStorerKey
         AND Code = @cType
         
         IF LEN(ISNULL(@cRFID, '' )) <> @nLength 
         BEGIN
            SET @nErrNo = 95493
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvalidRFID'
            --EXEC rdt.rdtSetFocusField @nMobile, 6
            SET @nFocusParam = 8
            GOTO RollBackTran
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND LabelNo = @cRFID )
         BEGIN
            SET @nErrNo = 95494
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'RFIDUsed'
            --EXEC rdt.rdtSetFocusField @nMobile, 6
            SET @nFocusParam = 8
            GOTO RollBackTran
         END
         
         
      END
           
      SET @cType = '' 
      
      DECLARE C_LULUTOTE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
      
      SELECT PD.PickDetailKey
            ,PD.SKU
            ,PD.QTy
            ,PD.OrderKey
      FROM dbo.Pickdetail PD WITH (NOLOCK) 
      --INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
      WHERE PD.StorerKey = @cStorerKey
      AND PD.Status = '5'
      AND PD.DropID = @cToteNo
      ORDER BY PD.OrderKey
      
            
      OPEN C_LULUTOTE        
      FETCH NEXT FROM C_LULUTOTE INTO  @cPickDetailKey, @cSKU, @nQty, @cOrderKey     
      WHILE (@@FETCH_STATUS <> -1)        
      BEGIN        
         
         SELECT @cType = Type
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey 
         
         IF @cType = 'LULUECOM' 
         BEGIN          
               SET @nErrNo = 95470          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOrder'          
               GOTO RollBackTran          
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK)  
                     WHERE  OrderKey = @cOrderKey ) 
         BEGIN
            
            SELECT @cPickSlipNo = PickHeaderKey 
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey 
            
         END
         ELSE 
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) 
                            WHERE StorerKey = @cStorerKey
                            AND Orderkey = @cOrderKey  ) 
            BEGIN
                EXECUTE dbo.nspg_GetKey  
                  'PICKSLIP',  
                  9,  
                  @cPickslipno OUTPUT,  
                  @bsuccess   OUTPUT,  
                  @nErrNo     OUTPUT,  
                  @cErrMsg    OUTPUT  
     
                SET @cPickslipno = 'P' + @cPickslipno  
            END
            ELSE 
            BEGIN
               SELECT @cPickSlipNo = PickSlipNo 
               FROM dbo.PackHeader WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND Orderkey = @cOrderKey
            END
         END
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
                         WHERE PickSlipNo = @cPickSlipNo ) 
         BEGIN
            
            INSERT INTO dbo.PickingInfo (PickSlipNo , ScanInDate , AddWho  ) 
            VALUES ( @cPickSlipNo , GetDATE() , @cUserName ) 
            
            IF @@ERROR <> 0 
            BEGIN 
                  SET @nErrNo = 95478        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickInfoFail'        
                  GOTO RollBackTran   
            ENd
            
         END
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) 
                         WHERE PickHeaderKey = @cPickSlipNo 
                         AND OrderKey = @cOrderKey  )
         BEGIN
               INSERT INTO dbo.PICKHEADER (PickHeaderKey, Storerkey, Orderkey, PickType, Zone, TrafficCop, AddWho, AddDate, EditWho, EditDate)  
               VALUES (@cPickSlipNo, @cStorerkey, @cOrderKey, '0', 'D', '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())  
               
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 95479  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'  
                  GOTO RollBackTran  
               END  
         END
            
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                         WHERE PickSlipNo = @cPickSlipNo
                         AND StorerKey = @cStorerKey ) 
         BEGIN
            /****************************        
             PACKHEADER        
            ****************************/        
              
                  
            INSERT INTO dbo.PackHeader         
            (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho, AddDate, EditWho, EditDate)         
            SELECT TOP 1  O.Route, O.OrderKey,'', O.LoadKey, O.ConsigneeKey, O.Storerkey,         
                  @cPickSlipNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()        
            FROM  dbo.Orders O WITH (NOLOCK)
            WHERE O.Orderkey = @cOrderKey         
           
            IF @@ERROR <> 0        
            BEGIN        
               SET @nErrNo = 95455        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'        
               GOTO RollBackTran        
            END    

            
         END
         
         BEGIN
            
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND PickSlipNo = @cPickSlipNo
                            AND SKU = @cSKU
                            AND RefNo = @cToteNo ) 
            BEGIN
               
               
               SET @cLabelNo = ''
               SET @nCartonNo = 0   
               SET @cLabelLine = '00000'
               
          

               IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                           AND PickSlipNo = @cPickSlipNo
                           AND RefNo = @cToteNo ) 
               BEGIN 
             

                  SELECT @cLabelNo = LabelNo 
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey 
                  AND RefNo = @cToteNo
                  AND PickSlipNo = @cPickSlipNo 
                  
               END
               ELSE
               BEGIN
             
                  IF ISNULL(@cRFID,'' )  <> '' -- (ChewKP05) 
                  BEGIN
                     SET @cLabelNo = @cRFID
                  END
                  ELSE  
                  BEGIN
                     SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenLabelNoSP) +        
                                          '   @cPickslipNo           ' +                           
                                          ' , @nCartonNo             ' +       
                                          ' , @cLabelNo     OUTPUT   '       
                                              
                          
                     SET @cExecArguments =         
                               N'@cPickslipNo  nvarchar(10),       ' +        
                                '@nCartonNo    int,                ' +            
                                '@cLabelNo     nvarchar(20) OUTPUT '            
                                
                                  
                            
                     EXEC sp_executesql @cExecStatements, @cExecArguments,         
                                          @cPickslipNo                       
                                        , @nCartonNo      
                                        , @cLabelNo      OUTPUT   
                  END   
               END
                      
               IF ISNULL(@cLabelNo,'')  = ''       
               BEGIN      
                     SET @nErrNo = 95457                  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen                  
                     GOTO RollBackTran                 
               END      
               
               
               -- Check if sku overpacked    
               --SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)      
               --FROM dbo.PickDetail PD WITH (NOLOCK)      
               --JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey      
               --WHERE PD.StorerKey = @cStorerKey      
               --   AND PD.Status IN ( '0', '5')     
               --   AND PD.SKU = @cSKU      
               --   AND PH.PickHeaderKey = @cPickSlipNo      
               
               
               
               --SELECT @nTTL_PackedQty = ISNULL(SUM(QTY), 0)      
               --FROM dbo.PackDetail WITH (NOLOCK)      
               --WHERE StorerKey = @cStorerKey      
               --   AND PickSlipNo = @cPickSlipNo      
               --   AND SKU = @cSKU      
       

               --IF @nTTL_PickedQty < (@nTTL_PackedQty + @nQty)      
               --BEGIN        
               --   SET @nErrNo = 95458        
               --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OVER PACKED'        
               --   GOTO RollBackTran        
               --END       
               
               
               -- Insert PackDetail        
               INSERT INTO dbo.PackDetail        
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, UPC, AddWho, AddDate, EditWho, EditDate)        
               VALUES        
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nQty,        
                  @cToteNo, @cLabelNo, '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())        
              
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 95459        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDetFail'        
                  GOTO RollBackTran        
               END    
               
               -- INSERT DRopID 
               IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                               WHERE DropID = @cLabelNo ) 
               BEGIN
                  
                  SELECT @cLoadKey = LoadKey 
                  FROM dbo.PackHeader WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo
                  
                  INSERT INTO DRopID (DropID, DropIDType, Status, LoadKey ) 
                  VALUES ( @cLabelNo , '1' , '5', @cLoadKey ) 
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 95475              
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'       
                     GOTO RollBackTran 
                  END
                  
               END   
               
               EXEC RDT.rdt_STD_EventLog          
                    @cActionType = '8', -- Packing         
                    @cUserID     = @cUserName,          
                    @nMobileNo   = @nMobile,          
                    @nFunctionID = @nFunc,          
                    @cFacility   = @cFacility,          
                    @cStorerKey  = @cStorerkey,          
                    @cSKU        = @cSku,        
                    @nQty        = @nQty,        
                    @cRefNo1     = @cToteNo,        
                    @cRefNo2     = @cLabelNo,        
                    @cRefNo3     = @cPickSlipNo 
                    
                
               
            END
            ELSE
            BEGIN
               -- Check if sku overpacked      
               --SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)      
               --FROM dbo.PickDetail PD WITH (NOLOCK)      
               --JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey      
               --WHERE PD.StorerKey = @cStorerKey      
               --   AND PD.Status IN ( '0', '5')     
               --   AND PD.SKU = @cSKU      
               --   AND PH.PickHeaderKey = @cPickSlipNo      
               
               --SELECT @nTTL_PackedQty = ISNULL(SUM(QTY), 0)      
               --FROM dbo.PackDetail WITH (NOLOCK)      
               --WHERE StorerKey = @cStorerKey      
               --   AND PickSlipNo = @cPickSlipNo      
               --   AND SKU = @cSKU      
       
               
               --IF @nTTL_PickedQty < (@nTTL_PackedQty + @nQty)      
               --BEGIN        
               --   SET @nErrNo = 95460        
               --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OVER PACKED'        
               --   GOTO RollBackTran        
               --END   
               

               SELECT @cLabelNo = LabelNo 
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey 
               AND SKU = @cSKU
               AND RefNo  = @cToteNo
               AND PickSlipNo = @cPickSlipNo 
               
               UPDATE dbo.Packdetail WITH (ROWLOCK)        
                  SET   QTY      = QTY + @nQty
                       ,EditDate = GetDate()
                       ,EditWho = sUser_sName()
               WHERE PickSlipNo = @cPickSlipNo 
               AND SKU = @cSku 
               AND RefNo = @cToteNo
               AND LabelNo = @cLabelNo      
              
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 69907        --(Kc07)        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'       
                  GOTO RollBackTran        
               END   
               
               EXEC RDT.rdt_STD_EventLog          
                    @cActionType = '8', -- Packing         
                    @cUserID     = @cUserName,          
                    @nMobileNo   = @nMobile,          
                    @nFunctionID = @nFunc,          
                    @cFacility   = @cFacility,          
                    @cStorerKey  = @cStorerkey,          
                    @cSKU        = @cSku,        
                    @nQty        = @nQty,        
                    @cRefNo1     = @cToteNo,        
                    @cRefNo2     = @cLabelNo,        
                    @cRefNo3     = @cPickSlipNo 
               
            END
            
         END
     
         
         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET DropID = @cLabelNo
            ,CaseID = @cLabelNo 
            ,Trafficcop = NULL
         WHERE StorerKey = @cStorerKey
         AND PickDetailKey = @cPickDetailKey 
         
         IF @@ERROR <> 0        
         BEGIN        
            SET @nErrNo = 95461               
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'       
            GOTO RollBackTran        
         END   

         UPDATE dbo.DropID WITH (ROWLOCK)
         SET Status = '9'
         WHERE DropID = @cToteNo

         IF @@ERROR <> 0        
         BEGIN        
            SET @nErrNo = 95464               
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'       
            GOTO RollBackTran        
         END   
         
         /****************************    
          PACKINFO    
         ****************************/  
         SELECT @fCartonWeight = CartonWeight
               ,@fCartonLength = CartonLength
               ,@fCartonHeight = CartonHeight
               ,@fCartonWidth  = CartonWidth 
         FROM dbo.Cartonization WITH (NOLOCK)
         WHERE CartonType = @cCartonType

         
         
--         SELECT @fStdGrossWeight = StdGrossWgt 
--         FROM dbo.SKU WITH (NOLOCK)
--         WHERE Storerkey = @cStorerKey
--         AND SKU = @cSKU 
         
         SELECT @nCartonNo  = CartonNo 
               ,@nTotalPackedQty = SUM(Qty)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND LabelNo = @cLabelNo
         GROUP BY CartonNo

         --SET @fCartonCube = (@fCartonLength * @fCartonHeight * @fCartonWidth)/(100*100*100) 
         
         SET @fCartonTotalWeight = @cTTLWeight
         
         SET @fCartonCube = (@fCartonLength * @fCartonHeight * @fCartonWidth)/(100*100*100) 

         --SELECT @fCartonWeight '@fCartonWeight', @fCartonLength '@fCartonLength' , @fCartonHeight '@fCartonHeight', @fCartonWidth '@fCartonWidth' , @fStdGrossWeight '@fStdGrossWeight'
         
         --SELECT @nCartonNo '@nCartonNo' , @nTotalPackedQty '@nTotalPackedQty' , @fCartonCute '@fCartonCute'
         
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                         WHERE PickSlipNo = @cPickSlipNo
                         AND CartonNo = @nCartonNo ) 
         BEGIN
      

            INSERT INTO dbo.PackInfo(PickslipNo, CartonNo, CartonType, Refno, Weight, Cube, Qty, AddWho, AddDate, EditWho, EditDate)    
            VALUES ( @cPickSlipNo , @nCartonNo, @cCartonType, '', @fCartonTotalWeight, @fCartonCube, @nTotalPackedQty, sUser_sName(), GetDate(), sUser_sName(), GetDate()) 
            
            IF @@ERROR <> 0        
            BEGIN        
               SET @nErrNo = 95462               
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackInfoFail'       
               GOTO RollBackTran        
            END  
            
         END
         ELSE
         BEGIN
       

            UPDATE dbo.PackInfo WITH (ROWLOCK)
            SET Qty = @nTotalPackedQty
               ,Weight = @fCartonTotalWeight
            WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            
            IF @@ERROR <> 0        
            BEGIN        
               SET @nErrNo = 95463              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackInfoFail'       
               GOTO RollBackTran        
            END  
            
         END
         
         
--         SET @nTTL_PickedQty = 0 
--         SET @nTTL_PackedQty = 0 
--         
--         SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)      
--         FROM dbo.PickDetail PD WITH (NOLOCK)      
--         JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey      
--         WHERE PD.StorerKey = @cStorerKey      
--            AND PD.Status = ('5')     
--            --AND PD.SKU = @cSKU      
--            AND PD.DropID = @cLabelNo
--            AND PH.PickHeaderKey = @cPickSlipNo      
--         
--         
--         SELECT @nTTL_PackedQty = ISNULL(SUM(QTY), 0)      
--         FROM dbo.PackDetail WITH (NOLOCK)      
--         WHERE StorerKey = @cStorerKey      
--            AND PickSlipNo = @cPickSlipNo      
--            --AND SKU = @cSKU    
--            AND LabelNo = @cLabelNo
         
         

         
         FETCH NEXT FROM C_LULUTOTE INTO  @cPickDetailKey, @cSKU, @nQty, @cOrderKey     
         
      END
      CLOSE C_LULUTOTE        
      DEALLOCATE C_LULUTOTE 
      
      
      
      
      --IF @nTTL_PickedQty = @nTTL_PackedQty 
      --BEGIN
      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      SET @nFromCartonNo = 0
      SET @nToCartonNo = 0
      
      SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'CARTONLBL'    
      
      
      SET @cOrderType = ''
      SET @bPrintManifest = '' 
      
      
      SELECT @cOrderType = Type
            ,@cConsigneeKey = ConsigneeKey
            ,@cOrderGroup   = OrderGroup
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
      
      SELECT @bPrintManifest = UDF01 
      FROM dbo.CodeLkup WITH (NOLOCK)
      WHERE ListName = 'LULULabel'
      AND Code = @cOrderType 
           
      SELECT @cManifestDataWindow = DataWindow,     
          @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'CTNMNFEST'   
      
      SELECT DISTINCT @nCartonNo = CartonNo 
      FROM dbo.Packdetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND PickSlipNo = @cPickSlipNo
      AND DropID = @cToteNo
      ORDER BY CartonNo
      
      EXEC RDT.rdt_BuiltPrintJob      
                   @nMobile,      
                   @cStorerKey,      
                   'CARTONLBL',      -- ReportType      
                   'CartonLabel',    -- PrintJobName      
                   @cDataWindow,      
                   @cLabelPrinter,      
                   @cTargetDB,      
                   @cLangCode,      
                   @nErrNo  OUTPUT,      
                   @cErrMsg OUTPUT,    
                   @cStorerKey,   
                   @cPickSlipNo, 
                   @nCartonNo,
                   @nCartonNo 
               
     IF @bPrintManifest = 'Y' 
     BEGIN
                  
                  EXEC RDT.rdt_BuiltPrintJob      
                   @nMobile,      
                   @cStorerKey,      
                   'CTNMNFEST',    -- ReportType      
                   'CartonManifest',    -- PrintJobName      
                   @cManifestDataWindow,      
                   @cLabelPrinter,      
                   @cTargetDB,      
                   @cLangCode,      
                   @nErrNo  OUTPUT,      
                   @cErrMsg OUTPUT,    
                   @cPickSlipNo, 
                   @nCartonNo,
                   @nCartonNo 
                   
     END
      
     -- (ChewKP03) 
     IF EXISTS ( SELECT 1 FROM dbo.CodeLKup WITH (NOLOCK) 
                 WHERE ListName = 'LULUSTLBL'
                 AND StorerKey = @cStorerKey 
                 AND Code = @cConsigneeKey
                 AND Code2 = @cType ) 
     BEGIN
         SET @cManifestDataWindow = ''
         SELECT @cManifestDataWindow = DataWindow,     
                @cTargetDB = TargetDB     
         FROM rdt.rdtReport WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
         AND   ReportType = 'STORELABEL'   
      
          EXEC RDT.rdt_BuiltPrintJob      
                   @nMobile,      
                   @cStorerKey,      
                   'STORELABEL',    -- ReportType      
                   'STORELABEL',    -- PrintJobName      
                   @cManifestDataWindow,      
                   @cLabelPrinter,      
                   @cTargetDB,      
                   @cLangCode,      
                   @nErrNo  OUTPUT,      
                   @cErrMsg OUTPUT,  
                   @cStorerKey,  
                   @cPickSlipNo, 
                   @nCartonNo,
                   @nCartonNo 
     END  
      
     -- (ChewKP06) 
     IF EXISTS ( SELECT 1 FROM dbo.CodeLKup WITH (NOLOCK) 
                 WHERE ListName = 'LULUNSO'
                 AND StorerKey = @cStorerKey 
                 AND Code = @cOrderGroup ) 
     BEGIN
          -- Common params  
          DELETE FROM @tOutBoundList
          
          INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
          INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cFromCartonNo',    @nCartonNo)
          INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cToCartonNo',   @nCartonNo)
          
          -- Print label
          EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
             'CTNMNFEST2', -- Report type
             @tOutBoundList, -- Report params
             'rdt_593Print03', 
             @nErrNo  OUTPUT,
             @cErrMsg OUTPUT
     END  
      
      
      
   END
   
   IF @cOption ='2'
   BEGIN
      SET @cLabelNo      = @cParam1
      
      -- Check blank    
      IF ISNULL(RTRIM(@cLabelNo), '') = ''    
      BEGIN    
         SET @nErrNo = 95465    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND LabelNo = @cLabelNo ) 
      BEGIN
         SET @nErrNo = 95466
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran  
      END
      
      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      SET @nFromCartonNo = 0
      SET @nToCartonNo = 0
      SET @cPickSlipNo = ''
      
      
      
      SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'CARTONLBL'   
      
      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo 
      
      SET @cOrderKey = ''
      SELECT @cOrderKey = OrderKey 
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      
      SELECT @cType = Type 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey 
      
--      IF @cType = 'LULUECOM' 
--      BEGIN          
--         SET @nErrNo = 95471       
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOrder'          
--         GOTO RollBackTran          
--      END
      
      
      SELECT @nFromCartonNo = MIN(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo 
      AND LabelNo = @cLabelNo    
      
      SELECT @nToCartonNo = MAX(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo    
      AND LabelNo = @cLabelNo 
      
      EXEC RDT.rdt_BuiltPrintJob      
          @nMobile,      
          @cStorerKey,      
          'CARTONLBL',    -- ReportType      
          'CartonLabel',    -- PrintJobName      
          @cDataWindow,      
          @cLabelPrinter,      
          @cTargetDB,      
          @cLangCode,      
          @nErrNo  OUTPUT,      
          @cErrMsg OUTPUT,    
          @cStorerKey,   
          @cPickSlipNo, 
          @nFromCartonNo,
          @nToCartonNo 
                
      
   END
   
   IF @cOption ='3'
   BEGIN
      SET @cLabelNo      = @cParam1
      
      -- Check blank    
      IF ISNULL(RTRIM(@cLabelNo), '') = ''    
      BEGIN    
         SET @nErrNo = 95466    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND LabelNo = @cLabelNo ) 
      BEGIN
         SET @nErrNo = 95467
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran  
      END
      
      SET @cDataWindow = ''
      SET @cPickSlipNo = ''
      
      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo 
      
      SET @cOrderKey = ''
      SELECT @cOrderKey = OrderKey 
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      
      SELECT @cType = Type 
            ,@cOrderGroup   = OrderGroup
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey 
      
      IF @cType = 'LULUECOM' 
      BEGIN          
         SET @nErrNo = 95472     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOrder'          
         GOTO RollBackTran          
      END
               
      SELECT @cDataWindow = DataWindow,     
          @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'CTNMNFEST'   
      
      
      SELECT @nCartonNo = CartonNo 
      FROM dbo.Packdetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo
      ORDER BY CartonNo

      EXEC RDT.rdt_BuiltPrintJob      
          @nMobile,      
          @cStorerKey,      
          'CTNMNFEST',    -- ReportType      
          'CartonManifest',    -- PrintJobName      
          @cDataWindow,      
          @cLabelPrinter,      
          @cTargetDB,      
          @cLangCode,      
          @nErrNo  OUTPUT,      
          @cErrMsg OUTPUT,    
          @cPickSlipNo, 
          @nCartonNo,
          @nCartonNo  

     -- (ChewKP06) 
     IF EXISTS ( SELECT 1 FROM dbo.CodeLKup WITH (NOLOCK) 
                 WHERE ListName = 'LULUNSO'
                 AND StorerKey = @cStorerKey 
                 AND Code = @cOrderGroup ) 
     BEGIN
         -- Common params  
          DELETE FROM @tOutBoundList
      
          INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
          INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cFromCartonNo',    @nCartonNo)
          INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cToCartonNo',   @nCartonNo)
           
          -- Print label
          EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
             'CTNMNFEST2', -- Report type
             @tOutBoundList, -- Report params
             'rdt_593Print03', 
             @nErrNo  OUTPUT,
             @cErrMsg OUTPUT
     END  
--      DECLARE C_LULUMANIFEST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
--      
--      SELECT CartonNo 
--      FROM dbo.Packdetail WITH (NOLOCK) 
--      WHERE StorerKey = @cStorerKey
--      AND LabelNo = @cLabelNo
--      ORDER BY CartonNo
--      
--            
--      OPEN C_LULUMANIFEST        
--      FETCH NEXT FROM C_LULUMANIFEST INTO  @nCartonNo
--      WHILE (@@FETCH_STATUS <> -1)        
--      BEGIN      
--         
--         EXEC RDT.rdt_BuiltPrintJob      
--          @nMobile,      
--          @cStorerKey,      
--          'CTNMNFEST',    -- ReportType      
--          'CartonManifest',    -- PrintJobName      
--          @cDataWindow,      
--          @cLabelPrinter,      
--          @cTargetDB,      
--          @cLangCode,      
--          @nErrNo  OUTPUT,      
--          @cErrMsg OUTPUT,    
--          @cPickSlipNo, 
--          @nCartonNo,
--          @nCartonNo  
--          
--         FETCH NEXT FROM C_LULUMANIFEST INTO  @nCartonNo    
--      END   
--      CLOSE C_LULUMANIFEST        
--      DEALLOCATE C_LULUMANIFEST  
--                
      
   END
   
   IF @cOption = '4'
   BEGIN
      SET @cLabelNo      = @cParam1
       
      IF ISNULL(RTRIM(@cLabelNo), '') = ''    
      BEGIN    
         SET @nErrNo = 95473    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran    
      END 
      
      SELECT TOP 1 @cOrderKey = OrderKey 
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND CaseID = @cLabelNo 
      
      IF ISNULL(@cOrderKey,'')  = ''
      BEGIN
         SET @nErrNo = 95474  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran   
      END
      
      SELECT @cPickSlipNo = PickSlipNo
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey 
            
      
      SELECT @cDataWindow = DataWindow,  
             @cTargetDB = TargetDB  
      FROM rdt.rdtReport WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   ReportType = 'PACKLIST'  
      
      EXEC RDT.rdt_BuiltPrintJob  
       @nMobile,  
       @cStorerKey,  
       'PACKLIST',              -- ReportType  
       'PackingList',           -- PrintJobName  
       @cDataWindow,  
       @cPaperPrinter,  
       @cTargetDB,  
       @cLangCode,  
       @nErrNo  OUTPUT,  
       @cErrMsg OUTPUT,  
       @cPickSlipNo, 
       @cOrderKey,
       '',
       '',
       ''
      
   END
   
   -- (ChewKP01) 
   IF @cOption = '5'
   BEGIN
      SET @cLabelNo      = @cParam1
      
      -- Check blank    
      IF ISNULL(RTRIM(@cLabelNo), '') = ''    
      BEGIN    
         SET @nErrNo = 95480    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND LabelNo = @cLabelNo ) 
      BEGIN
         SET @nErrNo = 95481
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran  
      END
      
      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      SET @nFromCartonNo = 0
      SET @nToCartonNo = 0
      SET @cPickSlipNo = ''
      
      
      SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'WWMTLBLLU'   
      
      SELECT @cPickSlipNo  = PickSlipNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo 
      
      
      SET @cOrderKey = ''
      SELECT @cOrderKey = OrderKey 
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      
      SELECT @cCCountry = C_Country 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey 

      SELECT @cLanguageCode = Code2 
      FROM dbo.Codelkup (NOLOCK) 
      WHERE ListName = 'LULUWWMT'
      AND StorerKey = @cStorerKey 
      AND Code = @cCCountry
      

      DECLARE C_WWMTLBLLU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
      
      SELECT SKU 
            ,Qty
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo 
      
            
      OPEN C_WWMTLBLLU        
      FETCH NEXT FROM C_WWMTLBLLU INTO  @cSKU, @nNoOfCopy
      WHILE (@@FETCH_STATUS <> -1)        
      BEGIN        
         
         

         SELECT @cAltSKU = AltSKU
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 
         
         SET @cStyle = ''

         SELECT @cStyle = Style 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 

         --INSERT INTO TRACEINFO (TRACENAME , TimeIn ,  Col1, col2, col3  ) 
         --VALUES ( 'rdt_593Print03' , getdate() , @cSKU,@cStyle, ''  ) 
         
         IF EXISTS ( SELECT 1 FROM dbo.DocInfo WITH (NOLOCK) 
                     WHERE TableName = 'SKU'
                     AND Key1 = @CStyle
                     AND Key2 = @cLanguageCode ) 
         BEGIN

            EXEC RDT.rdt_BuiltPrintJob      
                @nMobile,      
                @cStorerKey,      
                'WWMTLBLLU',    -- ReportType      
                'WWMTLBLLU',    -- PrintJobName      
                @cDataWindow,      
                @cLabelPrinter,      
                @cTargetDB,      
                @cLangCode,      
                @nErrNo  OUTPUT,      
                @cErrMsg OUTPUT,    
                @cCCountry,   
                @cAltSKU, 
                @nNoOfCopy,
                @cStorerKey,
                @cOrderKey       -- (james01) 

         END     
             FETCH NEXT FROM C_WWMTLBLLU INTO  @cSKU, @nNoOfCopy
             
      END    
      CLOSE C_WWMTLBLLU        
      DEALLOCATE C_WWMTLBLLU          
   END  
   
   IF @cOption = '6'
   BEGIN
      SET @cCCountry     = @cParam1
      SET @cUPC          = @cParam2
      SET @nNoOfCopy     = @cParam3
      
      --SELECT @cCCountry '@cCCountry' , @cUPC '@cUPC' , @nNoOfCopy '@nNoOfCopy' 

       -- Check blank    
      IF ISNULL(RTRIM(@cCCountry), '') = ''    
      BEGIN    
         SET @nErrNo = 95482    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --CountryReq  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         SET @nFocusParam = 2 
         GOTO RollBackTran    
      END 
      
      IF ISNULL(RTRIM(@cUPC), '') = ''    
      BEGIN    
         SET @nErrNo = 95483    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UPCReq  
         --EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param1   
         SET @nFocusParam = 6
         GOTO RollBackTran    
      END 
      
      IF ISNULL(RTRIM(@nNoOfCopy), '') = '0'    
      BEGIN    
         SET @nErrNo = 95486    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NoOfCopyReq  
         --EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param1   
         SET @nFocusParam = 10
         GOTO RollBackTran    
      END 
      
      -- (ChewKP02) 
      SELECT @nPreSetNoOfCopy = Short 
      FROM dbo.CodeLkup WITH (NOLOCK) 
      WHERE Listname = 'LULU593'
      AND Code = 'NoOfCopy'
      
      IF ISNULL(RTRIM(@nNoOfCopy), '') > ISNULL( @nPreSetNoOfCopy, 0 ) 
      BEGIN
         SET @nErrNo = 95487    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NoOfCopyExceed
         --EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param1   
         SET @nFocusParam = 10
         GOTO RollBackTran    
      END
      
      EXEC rdt.rdt_GETSKUCNT    
             @cStorerKey  = @cStorerKey    
            ,@cSKU        = @cUPC    
            ,@nSKUCnt     = @nSKUCnt       OUTPUT    
            ,@bSuccess    = @b_Success     OUTPUT    
            ,@nErr        = @nErrNo        OUTPUT    
            ,@cErrMsg     = @cErrMsg       OUTPUT    
        
      -- Check SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 95484    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU    
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU    
         GOTO RollBackTran    
      END    
        
      -- Check multi SKU barcode    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 95485    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod    
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU    
         GOTO RollBackTran    
      END    
        
      -- Get SKU code    
      EXEC rdt.rdt_GETSKU    
             @cStorerKey  = @cStorerKey    
            ,@cSKU        = @cUPC          OUTPUT    
            ,@bSuccess    = @b_Success     OUTPUT    
            ,@nErr        = @nErrNo        OUTPUT    
            ,@cErrMsg     = @cErrMsg       OUTPUT    
      

      SELECT @cAltSKU = AltSKU 
            ,@cStyle  = Style 
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND SKU = @cUPC

--      IF ISNULL(@nNoOfCopy, 0 ) = 0 
--      BEGIN
--         SET @nNoOfCopy = 1 
--      END
      
      
      
      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      
      
      SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'WWMTLBLLU'   
      
      SELECT @cLanguageCode = Code2
      FROM dbo.Codelkup (NOLOCK) 
      WHERE ListName = 'LULUWWMT'
      AND StorerKey = @cStorerKey 
      AND Code = @cCCountry
      
      IF EXISTS ( SELECT 1 FROM dbo.DocInfo WITH (NOLOCK) 
                     WHERE TableName = 'SKU'
                     AND Key1 = @CStyle
                     AND Key2 = @cLanguageCode ) 
      BEGIN
            
         EXEC RDT.rdt_BuiltPrintJob      
             @nMobile,      
             @cStorerKey,      
             'WWMTLBLLU',    -- ReportType      
             'WWMTLBLLU',    -- PrintJobName      
             @cDataWindow,      
             @cLabelPrinter,      
             @cTargetDB,      
             @cLangCode,      
             @nErrNo  OUTPUT,      
             @cErrMsg OUTPUT,    
             @cCCountry,   
             @cAltSKU, 
             @nNoOfCopy,
             @cStorerKey 
      END          
   END
   
   -- (ChewKP03) 
   IF @cOption ='7'
   BEGIN
      SET @cLabelNo      = @cParam1
      
      -- Check blank    
      IF ISNULL(RTRIM(@cLabelNo), '') = ''    
      BEGIN    
         SET @nErrNo = 95488    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND LabelNo = @cLabelNo ) 
      BEGIN
         SET @nErrNo = 95489
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran  
      END
      
      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      SET @nFromCartonNo = 0
      SET @nToCartonNo = 0
      SET @cPickSlipNo = ''
      
      
      
      SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'STORELABEL'   
      
      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo 
      
      SET @cOrderKey = ''
      SELECT @cOrderKey = OrderKey 
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      
      SELECT @cType = Type 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey 
      
--      IF @cType = 'LULUECOM' 
--      BEGIN          
--         SET @nErrNo = 95471       
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOrder'          
--         GOTO RollBackTran          
--      END
      
      
      SELECT @nFromCartonNo = MIN(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo 
      AND LabelNo = @cLabelNo    
      
      SELECT @nToCartonNo = MAX(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo    
      AND LabelNo = @cLabelNo 
      
      EXEC RDT.rdt_BuiltPrintJob      
          @nMobile,      
          @cStorerKey,      
          'STORELABEL',    -- ReportType      
          'STORELABEL',    -- PrintJobName      
          @cDataWindow,      
          @cLabelPrinter,      
          @cTargetDB,      
          @cLangCode,      
          @nErrNo  OUTPUT,      
          @cErrMsg OUTPUT,    
          @cStorerKey,   
          @cPickSlipNo, 
          @nFromCartonNo,
          @nToCartonNo 
                
      
   END
   
   -- (ChewKP04) 
   IF @cOption ='8'
   BEGIN
      
      SET @cLabelNo      = @cParam1
      SET @cTrackingNo   = @cParam2
      SET @cOrderKey     = @cParam3
      SET @cUPC          = @cParam4
      
      -- Check blank    
      IF ISNULL(RTRIM(@cLabelNo), '') = '' AND ISNULL(RTRIM(@cTrackingNo), '') = ''  AND ISNULL(RTRIM(@cOrderKey), '') = '' AND ISNULL(RTRIM(@cUPC), '') = ''   
      BEGIN    
         SET @nErrNo = 95490    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --EitherFieldReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran    
      END 
      
      IF ISNULL(@cLabelNo,'') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey 
                         AND LabelNo = @cLabelNo ) 
         BEGIN
            SET @nErrNo = 95491
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo  
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
            GOTO RollBackTran  
         END
      END
      
      IF ISNULL(@cTrackingNo,'') <> '' 
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey 
                         AND UserDefine04 = @cTrackingNo ) 
         BEGIN
            SET @nErrNo = 95497
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidTrackingNo
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
            GOTO RollBackTran  
         END
         
         SELECT @cLabelNo = PD.LabelNo 
         FROM dbo.PackHeader PH WITH (NOLOCK) 
         INNER JOIN dbo.PackDetail PD WITH (NOlOCK)  ON PD.PickSlipNo = PH.PickSlipNo
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey 
         AND PH.StorerKey = @cStorerKey
         AND O.TrackingNo = @cTrackingNo 
         AND PD.CartonNo = '1'
         
      END
      
      IF ISNULL(@cOrderKey,'') <> '' 
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey 
                         AND OrderKey = @cOrderKey ) 
         BEGIN
            SET @nErrNo = 95498
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidOrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
            GOTO RollBackTran  
         END
         
         SELECT @cLabelNo = PD.LabelNo 
         FROM dbo.PackHeader PH WITH (NOLOCK) 
         INNER JOIN dbo.PackDetail PD WITH (NOlOCK) ON PD.PickSlipNo = PH.PickSlipNo
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey 
         AND PH.StorerKey = @cStorerKey
         AND O.OrderKey = @cOrderKey 
         AND PD.CartonNo = '1'
      END
      
      IF ISNULL(@cUPC,'') <> '' 
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey 
                         AND UPC = @cUPC ) 
         BEGIN
            SET @nErrNo = 95499
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidUPC
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
            GOTO RollBackTran  
         END
         
         SELECT TOP 1 @cLabelNo = PD.LabelNo 
         FROM dbo.PackDetail PD WITH (NOlOCK)
         WHERE PD.StorerKey = @cStorerKey
         AND PD.UPC= @cUPC
         
      END
      
      
      SELECT @cPickSlipNo = PickSlipNo 
            ,@nCartonNo   = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo 
      
      SELECT @cOrderKey = OrderKey 
      FROM dbo.PackHeader WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo 
      
      SELECT @cCCountry = C_Country
            ,@cShipperKey = ShipperKey 
            ,@cTrackingNo = UserDefine04
            ,@cExternOrderKey = ExternOrderKey
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey 
      
      
      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      SET @nFromCartonNo = 0
      SET @nToCartonNo = 0
      SET @cPickSlipNo = ''
      
--      IF @cCCountry = 'KR' AND @cShipperKey = 'CJE'
--      BEGIN
      
--      SELECT @cDataWindow = DataWindow,     
--             @cTargetDB = TargetDB     
--      FROM rdt.rdtReport WITH (NOLOCK)     
--      WHERE StorerKey = @cStorerKey    
--      AND   ReportType = 'SHIPLBLCJK'   
      
      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo 
      
      SET @cOrderKey = ''
      SELECT @cOrderKey = OrderKey 
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      
      -- Check if it is Metapack printing      
      SELECT @cFilePath = Long,   
               @cPrintFilePath = Notes,  
               @cReportType = Code2  
      FROM dbo.CODELKUP WITH (NOLOCK)        
      WHERE LISTNAME = 'PrtbyShipK'        
      AND   Code = @cShipperKey      
      AND   StorerKey = @cStorerKey  
  
      -- Make sure we have setup the printer id  
      -- Record searched based on func + storer + reporttype + printergroup (shipperkey)  
      SELECT @cPrinterInGroup = PrinterID  
      FROM rdt.rdtReportToPrinter WITH (NOLOCK)  
      WHERE Function_ID = @nFunc  
      AND   StorerKey = @cStorerKey  
      AND   ReportType = @cReportType  
      AND   PrinterGroup = @cLabelPrinter  
  
      -- Determine print type (command/bartender)  
      SELECT @cProcessType = ProcessType, 
             @cPaperType = PaperType  
      FROM rdt.RDTREPORT WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   ReportType = @cReportType  
      AND  (Function_ID = @nFunc OR Function_ID = 0)  
      ORDER BY Function_ID DESC  
  
      -- PDF use foxit then need use the winspool printer name  
      IF @cReportType = 'PDFWBILL'    
      BEGIN  
         SELECT @cWinPrinter = WinPrinter    
         FROM rdt.rdtPrinter WITH (NOLOCK)    
         WHERE PrinterID = CASE WHEN ISNULL( @cPrinterInGroup, '') <> '' THEN @cPrinterInGroup ELSE @cLabelPrinter END  
  
         IF CHARINDEX(',' , @cWinPrinter) > 0   
         BEGIN  
            SET @cPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )      
         END  
         ELSE  
         BEGIN  
            SET @cPrinterName =  @cWinPrinter   
         END  
      END  
      ELSE
      BEGIN
         IF @cPaperType = 'LABEL'
            SET @cPrinterName = @cLabelPrinter
         ELSE
            SET @cPrinterName = @cPaperPrinter
      END
           
      IF ISNULL( @cFilePath, '') <> ''      
      BEGIN      
         SET @cFileName = 'THG_' + RTRIM( @cExternOrderKey) + '.pdf'       
         SET @cPrintCommand = '"' + @cPrintFilePath + '" /t "' + @cFilePath + '\' + @cFileName + '" "' + @cPrinterName + '"'                                
            
         DECLARE @tRDTPrintJob AS VariableTable  
            
         -- Print label (pass in shipperkey as label printer. then rdt_print will look for correct printer id)  
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '',   
            @cReportType,     -- Report type  
            @tRDTPrintJob,    -- Report params  
            'rdt_593Print03',   
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT,  
            1,  
            @cPrintCommand  
      END  
      ELSE  
      BEGIN  
         -- Common params  
         DELETE FROM @tOutBoundList
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cOrderKey',   @cOrderKey)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cTrackingNo', @cTrackingNo)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cLabelNo',    @cLabelNo)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonNo',   @nCartonNo)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)   
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)   
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)  

         IF @cPaperType = 'LABEL'
            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '',
               @cReportType, -- Report type
               @tOutBoundList, -- Report params
               'rdt_593Print03', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
         ELSE
            -- Print paper
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPrinterName, 
               @cReportType, -- Report type
               @tOutBoundList, -- Report params
               'rdt_593Print03', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
      END

      
   END
   GOTO QUIT       
         
RollBackTran:      
   ROLLBACK TRAN rdt_593Print03 -- Only rollback change made here      
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam

 
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN rdt_593Print03    
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam 
        

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtMetaPackLblReprn                                    */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2014-09-07 1.0  James    SOS317664 Created                              */  
/* 2015-01-23 1.1  ChewKP   SOS#330427 Additional validation for           */  
/*                            MetaPack (ChewKP01)                          */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtMetaPackLblReprn] (  
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
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @b_Success     INT  
     
   DECLARE @cDataWindow       NVARCHAR( 50)  
          ,@cTargetDB         NVARCHAR( 20)  
          ,@cLabelPrinter     NVARCHAR( 10)  
          ,@cIncoTerm         NVARCHAR( 10)  
          ,@cOrderKey         NVARCHAR( 10) 
          ,@cPickSlipNo       NVARCHAR( 10) 
          ,@nCartonNo         INT  
          ,@cLabelNo          NVARCHAR( 20) 
          ,@cReportType       NVARCHAR( 10)  
          ,@cPrintJobName     NVARCHAR( 50) 
          ,@cDocumentFilePath NVARCHAR( 1000) 
          ,@cToteNo           NVARCHAR( 18)
           
          ,@cReceiptKey    NVARCHAR(10)   -- (ChewKP01)  
          ,@cErrMsg1       NVARCHAR( 20)  -- (ChewKP01)  
          ,@cErrMsg2       NVARCHAR( 20)  -- (ChewKP01) 
          ,@cErrMsg3       NVARCHAR( 20)  -- (ChewKP01)  
          ,@cErrMsg4       NVARCHAR( 20)  -- (ChewKP01)  
          ,@cErrMsg5       NVARCHAR( 20)  -- (ChewKP01)
          ,@cCCountry      NVARCHAR( 30)  -- (ChewKP01)
          ,@cSKU           NVARCHAR( 20)  -- (ChewKP01)




   SET @cOrderKey = ''
   SET @cToteNo = ''
   
   SET @cOrderKey = @cParam1
   SET @cToteNo = @cParam2

   -- To ToteNo value must not blank
   IF ISNULL( @cOrderKey, '') = '' AND ISNULL( @cToteNo, '') = ''
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'Value Required'
      GOTO Quit  
   END

   -- Get printer info  
   SELECT @cLabelPrinter = Printer 
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   IF ISNULL( @cLabelPrinter, '') = ''
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'Label Prnter Req'
      GOTO Quit  
   END

   IF ISNULL( @cOrderKey, '') = ''
   BEGIN
      SELECT TOP 1 @cOrderKey = PD.OrderKey 
      FROM dbo.PickDetail PD  WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey 
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.DropID = @cToteNo
      AND   PD.[Status] = '5'
      AND   O.UserDefine05 <> '' --ECOMM
   END

   -- To ToteNo value must not blank
   IF ISNULL( @cOrderKey, '') = '' 
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'No OrderKey Found'
      GOTO Quit  
   END

   SELECT @cIncoTerm = IncoTerm FROM dbo.Orders WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND OrderKey = @cOrderkey

   SELECT @cPickSlipNo = PickSlipno 
   FROM dbo.PackHeader WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey
   
   -- (ChewKP01)   
   SELECT @cCCountry = C_Country 
   FROM dbo.Orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey 
   
   IF @cIncoTerm <> 'CC' AND ISNULL(RTRIM(@cCCountry),'' )  <> 'GB'
   BEGIN
      
      DECLARE CUR_METAPACK_VALIDATION CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
         SELECT DISTINCT LEFT(LA.Lottable02, 10)  FROM dbo.PackDetail PackD WITH (NOLOCK)   
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PackD.PickSlipNo   
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey  
         INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PD.Lot  
         --AND PackD.LabelNo = @cLabelNo  
         AND PackD.PickSlipNo = @cPickSlipno  
         --AND PackD.DropID = @cToteNo  
         AND PackD.StorerKey = @cStorerKey  
      OPEN CUR_METAPACK_VALIDATION  
      FETCH NEXT FROM CUR_METAPACK_VALIDATION INTO @cReceiptKey  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
           
         IF NOT EXISTS (SELECT 1 FROM dbo.Receipt WITH (NOLOCK)  
                        WHERE ReceiptKey = @cReceiptKey )   
         BEGIN  
            SET @nErrNo = 92651    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReceiptKeyNotFound'   
            
            SET @cErrMsg1 = @nErrNo    
            SET @cErrMsg2 = @cErrMsg    
            SET @cErrMsg3 = ''    
            SET @cErrMsg4 = ''    
            SET @cErrMsg5 = ''    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
                
            GOTO Quit    
         END      
           
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)  
                     WHERE Receiptkey = @cReceiptKey  
                     AND ISNULL(VesselKey,'')  = '' )   
         BEGIN  
            SET @nErrNo = 92652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CountryOriginReq'    
            
            SET @cErrMsg1 = @nErrNo    
            SET @cErrMsg2 = @cErrMsg    
            SET @cErrMsg3 = ''    
            SET @cErrMsg4 = ''    
            SET @cErrMsg5 = ''    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
            
            GOTO QUIT  
         END      
           
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)  
                     WHERE Receiptkey = @cReceiptKey  
                     AND ISNULL(UserDefine04,'')  = '' )   
         BEGIN  
            SET @nErrNo = 92653    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ProductTypeDescrReq'  
            
            SET @cErrMsg1 = @nErrNo    
            SET @cErrMsg2 = @cErrMsg    
            SET @cErrMsg3 = ''    
            SET @cErrMsg4 = ''    
            SET @cErrMsg5 = ''    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
                 
            GOTO QUIT    
         END    
         
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)  
                     WHERE Receiptkey = @cReceiptKey  
                     AND ISNULL(UserDefine02,'')  = '' )   
         BEGIN  
            SET @nErrNo = 92654    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'FabricContentReq'  
            
            SET @cErrMsg1 = @nErrNo    
            SET @cErrMsg2 = @cErrMsg    
            SET @cErrMsg3 = ''    
            SET @cErrMsg4 = ''    
            SET @cErrMsg5 = ''    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
                 
            GOTO QUIT    
         END    
           
                                  
         FETCH NEXT FROM CUR_METAPACK_VALIDATION INTO @cReceiptKey  
      END  
      CLOSE CUR_METAPACK_VALIDATION  
      DEALLOCATE CUR_METAPACK_VALIDATION  
        
      SET @cSKU = ''  
        
      DECLARE CUR_METAPACK_VALIDATION_ORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
         SELECT DISTINCT PackD.SKU FROM dbo.PackDetail PackD WITH (NOLOCK)   
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PackD.PickSlipNo   
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey  
         INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PD.Lot  
         --AND PackD.LabelNo = @cLabelNo  
         AND PackD.PickSlipNo = @cPickSlipno  
         --AND PackD.DropID = @cToteNo  
         AND PackD.StorerKey = @cStorerKey  
      OPEN CUR_METAPACK_VALIDATION_ORDER  
      FETCH NEXT FROM CUR_METAPACK_VALIDATION_ORDER INTO @cSKU  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
           
         IF EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK)  
                    WHERE SKU = @cSKU  
                    AND ISNULL(BUSR4,'')  = '' )   
         BEGIN  
            SET @nErrNo = 92655    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'HormonizeCodeReq'    
            
            SET @cErrMsg1 = @nErrNo    
            SET @cErrMsg2 = @cErrMsg    
            SET @cErrMsg3 = ''    
            SET @cErrMsg4 = ''    
            SET @cErrMsg5 = ''    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
               
            GOTO QUIT    
         END      
           
         IF EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK)  
                    WHERE SKU = @cSKU  
                    AND ISNULL(DESCR,'')  = '' )   
         BEGIN  
            SET @nErrNo = 92656    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUDescrReq'    
            
            SET @cErrMsg1 = @nErrNo    
            SET @cErrMsg2 = @cErrMsg    
            SET @cErrMsg3 = ''    
            SET @cErrMsg4 = ''    
            SET @cErrMsg5 = ''    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
               
            GOTO QUIT    
         END      
           
         IF EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK)  
                    WHERE SKU = @cSKU  
                    AND ISNULL(StdGrossWgt,'0')  = '0' )   
         BEGIN  
            SET @nErrNo = 92657  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WeightReq'    
            
            SET @cErrMsg1 = @nErrNo    
            SET @cErrMsg2 = @cErrMsg    
            SET @cErrMsg3 = ''    
            SET @cErrMsg4 = ''    
            SET @cErrMsg5 = ''    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
               
            GOTO QUIT    
         END    
           
         IF NOT EXISTS ( SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)  
                         WHERE OrderKey = @cOrderKey  
                         AND SKU = @cSKU)   
         BEGIN  
            SET @nErrNo = 92658  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUNotExistInOrder'   
            
            SET @cErrMsg1 = @nErrNo    
            SET @cErrMsg2 = @cErrMsg    
            SET @cErrMsg3 = ''    
            SET @cErrMsg4 = ''    
            SET @cErrMsg5 = ''    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
             
            GOTO QUIT   
         END            
           
         IF EXISTS ( SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)  
                         WHERE OrderKey = @cOrderKey  
                         AND SKU = @cSKU  
                         AND ISNULL(UnitPrice,'0')  = '0' )   
         BEGIN  
            SET @nErrNo = 92659  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UnitPriceReq'   
            
            SET @cErrMsg1 = @nErrNo    
            SET @cErrMsg2 = @cErrMsg    
            SET @cErrMsg3 = ''    
            SET @cErrMsg4 = ''    
            SET @cErrMsg5 = ''    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
               
            GOTO QUIT   
         END    
           
--         IF NOT EXISTS ( SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)  
--                         WHERE OrderKey = @cOrderKey  
--                         AND SKU = @cSKU  
--                         AND QtyPicked > 0 )   
--         BEGIN  
--            SET @nErrNo = 92660  
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUNotPicked'    
--            
--            SET @cErrMsg1 = @nErrNo    
--            SET @cErrMsg2 = @cErrMsg    
--            SET @cErrMsg3 = ''    
--            SET @cErrMsg4 = ''    
--            SET @cErrMsg5 = ''    
--            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
--               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
--               
--            GOTO QUIT   
--         END    
                                  
         FETCH NEXT FROM CUR_METAPACK_VALIDATION_ORDER INTO @cSKU  
      END  
      CLOSE CUR_METAPACK_VALIDATION_ORDER  
      DEALLOCATE CUR_METAPACK_VALIDATION_ORDER  
   END
   

   -- Skip printing is incoterm = 'CC'
   IF @cIncoTerm <> 'CC'
   BEGIN
      /********************************  
         CALL METAPACK & PRINT Label   
      *********************************/ 
      DECLARE CUR_PRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT DISTINCT CartonNo, LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipno
      ORDER BY 1
      OPEN CUR_PRINT
      FETCH NEXT FROM CUR_PRINT INTO @nCartonNo, @cLabelNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         EXEC [dbo].isp_WS_Metapack_AllocationService 
            @nMobile, 
            @cPickSlipNo, 
            @nCartonNo, 
            @cLabelNo, 
            @cDocumentFilePath   OUTPUT, 
            @b_Success           OUTPUT, 
            @nErrNo              OUTPUT, 
            @cErrMsg             OUTPUT 

         IF @b_Success <> 1 
         BEGIN  
            CLOSE CUR_PRINT
            DEALLOCATE CUR_PRINT
            GOTO Quit
         END     

         FETCH NEXT FROM CUR_PRINT INTO @nCartonNo, @cLabelNo
      END
      CLOSE CUR_PRINT
      DEALLOCATE CUR_PRINT
   END
   ELSE  -- Click & Collect label
   BEGIN
      SET @cReportType = 'CCBAGLABEL'                
      SET @cPrintJobName = 'PRINT_BAGLABEL'        

      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
             @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
      FROM RDT.RDTReport WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey
      AND ReportType = @cReportType  

      IF ISNULL(RTRIM(@cDataWindow),'') = ''    
      BEGIN    
         SET @nErrNo = 1    
         SET @cErrMsg = 'Label NOT Setup'    
         GOTO Quit    
      END    
       
      IF ISNULL(RTRIM(@cTargetDB),'') = ''    
      BEGIN    
         SET @nErrNo = 1    
         SET @cErrMsg = 'No Target DB'  
         GOTO Quit    
      END    

      EXEC RDT.rdt_BuiltPrintJob   
         @nMobile,  
         @cStorerKey,  
         @cReportType,  
         @cPrintJobName,  
         @cDataWindow,  
         @cLabelPrinter,  
         @cTargetDB,  
         @cLangCode,  
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT,  
         @cStorerKey,  
         @cOrderkey,  
         ' ',        
         ' '         

      IF @nErrNo <> 0
         GOTO Quit    

   END

Quit:  

GO
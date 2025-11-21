SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdt_593PackList02                                      */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2019-01-22 1.0  ChewKP   WMS-7675 Created                               */  
/***************************************************************************/    
    
CREATE PROC [RDT].[rdt_593PackList02] (    
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
   
   DECLARE 
           @cPickSlipNo       NVARCHAR(10)
          ,@cUCCNo            NVARCHAR(20) 
          ,@nCartonStart      INT
          ,@nCartonEnd        INT
          ,@cVASType          NVARCHAR(10)  
          ,@cField01          NVARCHAR(10)   
          ,@cTemplate         NVARCHAR(50)  
          ,@nTranCount        INT
          ,@cPickDetailKey    NVARCHAR(10) 
          ,@cOrderKey         NVARCHAR(10) 
          ,@cLabelNo          NVARCHAR(20) 
          ,@cSKU              NVARCHAR(20)
          ,@nCartonNo         INT
          ,@cLabelLine        NVARCHAR(5) 
          ,@cGenLabelNoSP     NVARCHAR(30)  
          ,@nQty              INT
          ,@cExecStatements   NVARCHAR(4000)         
          ,@cExecArguments    NVARCHAR(4000)  
          ,@cCodeTwo          NVARCHAR(30)  
          ,@cTemplateCode     NVARCHAR(60)  
          ,@nFocusParam       INT
          ,@bsuccess          INT
          ,@nPackQTY          INT  
          ,@nPickQTY          INT  
          ,@nMaxCarton        INT
          ,@nIsUCC            INT
          ,@cPrintPackingList NVARCHAR(1)
          ,@cShipFlag         NVARCHAR(1)
          ,@cDocType          NVARCHAR(10) 
          ,@cSectionKey       NVARCHAR(10)  
          ,@cPrinter02        NVARCHAR(10)  
          ,@cBrand01          NVARCHAR(10)  
          ,@cBrand02          NVARCHAR(10)  
          ,@cPrinter01        NVARCHAR(10)  
          
          

   DECLARE @tOutBoundList AS VariableTable          
   DECLARE @tOutBoundList2 AS VariableTable          
   
   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank    
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''    
   BEGIN    
      SET @nErrNo = 133951    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
      GOTO Quit    
   END    
   
   -- Check label printer blank    
   IF ISNULL(RTRIM(@cPaperPrinter),'')  = ''    
   BEGIN    
      SET @nErrNo = 133952    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq    
      GOTO Quit    
   END 


   SET @nTranCount = @@TRANCOUNT      
         
   BEGIN TRAN      
   SAVE TRAN rdt_593PackList02      
      
  
   IF @cOption ='7'
   BEGIN
      SET @cOrderKey      = @cParam1
      
      -- Check blank    
      IF ISNULL(RTRIM(@cOrderKey), '') = ''    
      BEGIN    
         SET @nErrNo = 133953    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --OrderKeyReq  
         GOTO RollBackTran    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND OrderKey = @cOrderKey)
      BEGIN
         SET @nErrNo = 133954   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidOrderKey  
         GOTO RollBackTran 
      END
      
      
      SELECT  @cDocType = DocType
              ,@cShipFlag = Ecom_Single_Flag 
              ,@cSectionKey = RTRIM(SectionKey)  
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey 

      
      
      
                       
      IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey 
                  AND OrderKey = @cOrderKey ) 
      BEGIN
         SELECT @cPickSlipNo = PickSlipNo
         FROM dbo.PackHeader WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND OrderKey = @cOrderKey
      END
      ELSE
      BEGIN
      

         SET @nErrNo = 133955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NoRecFound
         GOTO RollBackTran  
      END

      
      
      -- Print UCC Label
      SELECT TOP 1 @nCartonStart = MIN(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo 
      AND StorerKey = @cStorerKey
      
         
      SELECT TOP 1 @nCartonEnd = MAX(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo    
      AND StorerKey = @cStorerKey

      SELECT TOP 1 @cLabelNo = LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo    
      AND StorerKey = @cStorerKey
      
      
      IF @cDocType = 'E'
      BEGIN
         IF @cShipFlag = 'S'
         BEGIN
             SELECT @cDataWindow = DataWindow,  
                    @cTargetDB = TargetDB  
             FROM rdt.rdtReport WITH (NOLOCK)  
             WHERE StorerKey = @cStorerKey  
             AND   ReportType = 'BAGMANFEST'  
             
             IF EXISTS ( SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK)  
                         WHERE ListName = 'DTCPrinter' )  
             BEGIN  
        
        
                -- Get Printer Information  
                SELECT @cPrinter01 = RTRIM(Code)  
                      ,@cBrand01   = RTRIM(Short)  
                      ,@cPrinter02 = RTRIM(UDF01)  
                      ,@cBrand02   = RTRIM(UDF02)  
                FROM dbo.CodeLkup WITH (NOLOCK)  
                WHERE ListName = 'DTCPrinter'  
                AND RTRIM(Code) = ISNULL(RTRIM(@cPaperPrinter),'')  
        
        
                IF @cSectionKey = @cBrand01  
                BEGIN  
                   SET @cPaperPrinter = @cPrinter01  
                END  
                ELSE IF @cSectionKey = @cBrand02  
                BEGIN  
                   SET @cPaperPrinter = @cPrinter02  
                END  
        
             END  
               
             EXEC RDT.rdt_BuiltPrintJob  
                   @nMobile,  
                   @cStorerKey,  
                   'BAGMANFEST',              -- ReportType  
                   'rdt_593PackList02',    -- PrintJobName  
                   @cDataWindow,  
                   @cPaperPrinter,  
                   @cTargetDB,  
                   @cLangCode,  
                   @nErrNo  OUTPUT,  
                   @cErrMsg OUTPUT,  
                   @cOrderkey,  
                   @cLabelNo    
                   
             IF @nErrNo <> 0 
               GOTO RollBackTran      
                   
             
         END   
         
         IF @cShipFlag = 'M'
         BEGIN
             DELETE FROM @tOutBoundList
       
             INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
             
             -- Print label
             EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter, 
                'EMPACKLIST', -- Report type
                @tOutBoundList, -- Report params
                'rdt_593PackList02', 
                @nErrNo  OUTPUT,
                @cErrMsg OUTPUT
            
            IF @nErrNo <> 0 
               GOTO RollBackTran 
         END   
         
      END
      
      

      IF @cDocType = 'N'
      BEGIN
      
      

            -- Print Packing List Process --  
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)   
                            WHERE StorerKey = @cStorerKey  
                            AND PickSlipNo = @cPickSlipNo  
                            AND ISNULL(RTRIM(RefNo),'')  <> '1' )   
            BEGIN  
               --IF @nMaxCarton = @nCartonEnd
               --BEGIN
                  
                  SET @cTemplate = ''  
                    
                  IF EXISTS ( SELECT 1  
                              FROM dbo.DocInfo WITH (NOLOCK)  
                              WHERE StorerKey = @cStorerKey  
                              AND TableName = 'ORDERDETAIL'  
                              AND Key1 = @cOrderKey   
                              AND Rtrim(Substring(Docinfo.Data,31,30)) = 'F01'  )   
                  BEGIN  
                    
                     SELECT @cVASType = Rtrim(Substring(Docinfo.Data,31,30))   
                     FROM dbo.DocInfo WITH (NOLOCK)  
                     WHERE StorerKey = @cStorerKey  
                     AND TableName = 'ORDERDETAIL'  
                     AND Key1 = @cOrderKey   
                     AND Rtrim(Substring(Docinfo.Data,31,30)) = 'F01'   
                       
                     SELECT @cTemplate = ISNULL(RTRIM(Notes),'')   
                     FROM dbo.CodeLkup WITH (NOLOCK)  
                     WHERE ListName = 'UAPACKLIST'  
                     AND Code  = @cVASType  
                     AND UDF01 <> '1'  
                     AND StorerKey = @cStorerKey  
                       
                     IF ISNULL(RTRIM(@cTemplate),'')  <> ''   
                     BEGIN  
                             
                        
                        DELETE @tOutBoundList
                        INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
                        
                        -- Print label
                        EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter, 
                           'PACKLIST', -- Report type
                           @tOutBoundList, -- Report params
                           'rdt_593PackList02', 
                           @nErrNo  OUTPUT,
                           @cErrMsg OUTPUT
                           
                        IF @nErrNo <> 0
                           GOTO RollBackTran
                          
                     END  
                  END  
                   

                 
                 
            END   
            
         
         
         
                  
      END
   END

   GOTO QUIT   
   
   
  
RollBackTran:      
   ROLLBACK TRAN rdt_593PackList02 -- Only rollback change made here      
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam

 
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN rdt_593PackList02    
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam 
        

GO
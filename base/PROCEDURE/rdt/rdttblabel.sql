SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdtTBLabel                                             */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2015-06-03 1.0  ChewKP   SOS#343054 Created                             */   
/* 2016-09-01 1.1  ChewKP   SOS#374578 (ChewKP01)                          */
/***************************************************************************/    
    
CREATE PROC [RDT].[rdtTBLabel] (    
   @nMobile    INT,    
   @nFunc      INT,    
   @nStep      INT,    
   @cLangCode  NVARCHAR( 3),    
   @cStorerKey NVARCHAR( 15),    
   @cOption    NVARCHAR( 1),    
   @cParam1    NVARCHAR(20),  -- LabelNo    
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
       
  
   DECLARE @cLabelPrinter NVARCHAR( 10)    
   DECLARE @cPaperPrinter NVARCHAR( 10)    
 
   DECLARE @cLabelType    NVARCHAR( 20)    
   DECLARE @cUserName     NVARCHAR( 18)     
   
   DECLARE @cLabelNo      NVARCHAR(20)  
          ,@cDataWindow   NVARCHAR(50)  
          ,@cTargetDB     NVARCHAR(20)  
          ,@cPickSlipNo   NVARCHAR(10)
          ,@nCartonNo     INT

  
   
   -- Get printer info    
   SELECT     
      @cUserName = UserName,   
      @cLabelPrinter = Printer,     
      @cPaperPrinter = Printer_Paper    
   FROM rdt.rdtMobRec WITH (NOLOCK)    
   WHERE Mobile = @nMobile    
   
     
       
   /*-------------------------------------------------------------------------------    
    
                                    Print Label    
    
   -------------------------------------------------------------------------------*/    
    
   -- Check label printer blank    
   IF @cLabelPrinter = ''    
   BEGIN    
      SET @nErrNo = 93903    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
      GOTO Quit    
   END    
   
   
   IF @cOption = '1' 
   BEGIN
      -- cLabelNo mapping    
      SET @cLabelNo = @cParam1   
      
   
     
      -- Check blank    
      IF ISNULL( @cLabelNo, '') = ''    
      BEGIN    
         SET @nErrNo = 93901    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Label Req
         GOTO Quit    
      END    
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Packdetail  WITH (NOLOCK)
                      WHERE LabelNo = @cLabelNo
                      AND StorerKey = @cStorerKey ) 
      BEGIN
         SET @nErrNo = 93902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo
         GOTO Quit  
      END
      
      SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'CARTONLBL'   
      
      SELECT TOP 1 @cPickSlipNo = PickSlipNo
            ,@nCartonNo   = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE LabelNo = @cLabelNo
      
      
      EXEC RDT.rdt_BuiltPrintJob      
       @nMobile,      
       @cStorerKey,      
       'CARTONLBL',              -- ReportType      
       'PRINTCARTONLBL',         -- PrintJobName      
       @cDataWindow,      
       @cLabelPrinter,      
       @cTargetDB,      
       @cLangCode,      
       @nErrNo  OUTPUT,      
       @cErrMsg OUTPUT,       
       @cPickSlipNo,     
       @nCartonNo  ,
       @nCartonNo,
       @cLabelNo,
       @cLabelNo
    
   END
   
   -- (ChewKP01) 
   IF @cOption = '2' 
   BEGIN
      -- cLabelNo mapping    
      SET @cLabelNo = @cParam1   
         
     
      -- Check blank    
      IF ISNULL( @cLabelNo, '') = ''    
      BEGIN    
         SET @nErrNo = 93904    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Label Req
         GOTO Quit    
      END    
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Packdetail  WITH (NOLOCK)
                      WHERE LabelNo = @cLabelNo
                      AND StorerKey = @cStorerKey ) 
      BEGIN
         SET @nErrNo = 93905
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo
         GOTO Quit  
      END
      
      SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'CTNMNFEST'   
      
      SELECT TOP 1 @cPickSlipNo = PickSlipNo
            ,@nCartonNo   = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE LabelNo = @cLabelNo
      
      
      EXEC RDT.rdt_BuiltPrintJob      
       @nMobile,      
       @cStorerKey,      
       'CTNMNFEST',              -- ReportType      
       'Carton Manifest',         -- PrintJobName      
       @cDataWindow,      
       @cLabelPrinter,      
       @cTargetDB,      
       @cLangCode,      
       @nErrNo  OUTPUT,      
       @cErrMsg OUTPUT,       
       @cPickSlipNo,     
       @cLabelNo  ,
       @cLabelNo,
       '',
       ''
    
   END
  
Quit:    

GO
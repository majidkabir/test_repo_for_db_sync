SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdt_593PrintEAT01                                      */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2017-11-27 1.0  ChewKP   WMS-3496 Created                               */  
/***************************************************************************/    
    
CREATE PROC [RDT].[rdt_593PrintEAT01] (    
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
   
   DECLARE @nTranCount    INT   
          ,@cPickSlipNo   NVARCHAR(10)
          ,@cLabelNo       NVARCHAR(20)
          ,@cExecStatements   NVARCHAR(4000)         
          ,@cExecArguments    NVARCHAR(4000)  
          ,@nCartonStart      INT
          ,@nCartonEnd        INT
          ,@nFocusParam       INT
   
   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nFocusParam = 2 

   -- Check label printer blank    
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''    
   BEGIN    
      SET @nErrNo = 117201    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
      GOTO Quit    
   END    

   SET @nTranCount = @@TRANCOUNT      
         
   --BEGIN TRAN      
   --SAVE TRAN rdt_593PrintEAT01      
      
  
   
   IF @cOption ='1'
   BEGIN
      SET @cLabelNo      = @cParam1
      
      -- Check blank    
      IF ISNULL(RTRIM(@cLabelNo), '') = ''    
      BEGIN    
         SET @nErrNo = 117202    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND LabelNo = @cLabelNo ) 
      BEGIN
         SET @nErrNo = 117203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit  
      END
      
      
      -- Print Carton Label --
--      SET @cDataWindow = ''
--      SET @cTargetDB   = ''
      SET @nCartonStart = 0
      SET @nCartonEnd = 0
      SET @cPickSlipNo = ''
      
            
      SELECT TOP 1 @cPickSlipNo = PickSlipNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo 
      
      
      SELECT @nCartonStart = MIN(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo 
      AND LabelNo = @cLabelNo    
      
      SELECT @nCartonEnd = MAX(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo    
      AND LabelNo = @cLabelNo 
      
                   
      DECLARE @tOutBoundList AS VariableTable
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonStart', @nCartonStart)
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonEnd',   @nCartonEnd)
                        

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
         'UCCLABEL02', -- Report type
         @tOutBoundList, -- Report params
         'rdt_593PrintEAT01', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
         
      IF @nErrNo <> 0
         GOTO Quit
   END
   
   GOTO QUIT
        
         
--RollBackTran:      
--   ROLLBACK TRAN rdt_593PrintEAT01 -- Only rollback change made here      
--   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam

 
Quit:      
   --WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
   --   COMMIT TRAN rdt_593PrintEAT01    
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam 
        

GO
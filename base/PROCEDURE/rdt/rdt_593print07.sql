SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdt_593Print07                                         */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2016-05-13 1.0  ChewKP   SOS#368773 Created                             */  
/***************************************************************************/    
    
CREATE PROC [RDT].[rdt_593Print07] (    
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
   
   DECLARE @cReceiptKey NVARCHAR(10) 
         , @cCaseID     NVARCHAR(18) 
         , @nTranCount  INT   
         , @cReceiptLineNumber NVARCHAR(5)
          
  
   
   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank    
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''    
   BEGIN    
      SET @nErrNo = 100701    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
      GOTO Quit    
   END    

   SET @nTranCount = @@TRANCOUNT      
         
   BEGIN TRAN      
   SAVE TRAN rdt_593Print07      
      
   IF @cOption = '1' 
   BEGIN 
         
      SET @cReceiptKey  = @cParam1
      SET @cCaseID      = @cParam3
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey 
                      AND ReceiptKey = @cReceiptKey ) 
      BEGIN
         SET @nErrNo = 100702    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidASN  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran  
      END
      
      IF ISNULL(@cCaseID,'' )  = '' 
      BEGIN
         SET @nErrNo = 100704
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- CaseIDReq 
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param1   
         GOTO RollBackTran  
      END



      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND ReceiptKey = @cReceiptKey
                      AND ToID = @cCaseID ) 
      BEGIN
         SET @nErrNo = 100703    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidCaseID 
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Param1   
         GOTO RollBackTran  
      END
      
      SELECT
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
            @cTargetDB = ISNULL(RTRIM(TargetDB), '')
      FROM RDT.RDTReport WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ReportType = 'PostRecv'
      
      -- Find receipt detai line
      SET @cReceiptLineNumber = ''
      SELECT TOP 1
         @cReceiptLineNumber = ReceiptLineNumber
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND ToID = @cCaseID

      EXEC RDT.rdt_BuiltPrintJob
         @nMobile,
         @cStorerKey,
         'PostRecv',       -- ReportType
         'PRINT_PostRecv', -- PrintJobName
         @cDataWindow,
         @cLabelPrinter,
         @cTargetDB,
         @cLangCode,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         @cReceiptKey,
         @cReceiptLineNumber,
         @cReceiptLineNumber,
         @cCaseID
      
      
      
   END
   
     
   GOTO QUIT       
         
RollBackTran:      
   ROLLBACK TRAN rdt_593Print07 -- Only rollback change made here      
      
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN rdt_593Print07      
        

GO
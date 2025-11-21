SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdt_593Print17                                         */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2017-11-17 1.0  ChewKP   WMS-3418 Created                               */  
/***************************************************************************/    
    
CREATE PROC [RDT].[rdt_593Print17] (    
   @nMobile    INT,    
   @nFunc      INT,    
   @nStep      INT,    
   @cLangCode  NVARCHAR( 3),    
   @cStorerKey NVARCHAR( 15),    
   @cOption    NVARCHAR( 1),    
   @cParam1    NVARCHAR(60),  
   @cParam2    NVARCHAR(60),  
   @cParam3    NVARCHAR(60),     
   @cParam4    NVARCHAR(60),    
   @cParam5    NVARCHAR(60),    
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
          ,@nFocusParam       INT
          ,@nPrintParam   INT
          ,@cReceiptKey   NVARCHAR(10) 
          ,@cCartonID     NVARCHAR(30) 
          ,@cPrintType    NVARCHAR(1)
          ,@cSKU          NVARCHAR(20)
          ,@nQty          INT
          ,@nNoOfCopy     INT
          
   DECLARE @tOutBoundList AS VariableTable      

   
   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nFocusParam = 2 
   
   

   -- Check label printer blank    
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''    
   BEGIN    
      SET @nErrNo = 116756    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
      GOTO Quit    
   END    

   SET @nTranCount = @@TRANCOUNT      
         
   --BEGIN TRAN      
   --SAVE TRAN rdt_593Print17      
      
  
   
   IF @cOption ='1'
   BEGIN
      SET @cReceiptKey   = @cParam1
      SET @cCartonID     = @cParam3
      SET @cPrintType    = @cParam5
      
      -- Check blank    
      IF ISNULL(RTRIM(@cReceiptKey), '') = ''    
      BEGIN    
         SET @nErrNo = 116751    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq  
         SET @nFocusParam = 2  
         GOTO Quit    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND ReceiptKey = @cReceiptKey ) 
      BEGIN
         SET @nErrNo = 116752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvReceiptKey  
         SET @nFocusParam = 2  
         GOTO Quit  
      END
      
      -- Check blank    
      IF ISNULL(RTRIM(@cCartonID), '') = ''    
      BEGIN    
         SET @nErrNo = 116753   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --CartonIDReq  
         SET @nFocusParam = 6 
         GOTO Quit    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND ReceiptKey = @cReceiptKey
                      AND Lottable07 = @cCartonID ) 
      BEGIN
         SET @nErrNo = 116754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvCartonID  
         SET @nFocusParam = 6  
         GOTO Quit  
      END
      
      
      
      IF ISNULL(RTRIM(@cPrintType), '') <> 'A'   
      BEGIN
         IF RDT.rdtIsValidQTY( @cPrintType, 1) = 0     
         BEGIN    
            SET @nErrNo = 116755    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvPrintType'    
            SET @nFocusParam = 10 
            GOTO Quit  
         END   
         
         --SET @nPrintParam = @cPrintType
      END
      ELSE
      BEGIN
         
         IF EXISTS ( SELECT 1 
                     FROM dbo.ReceiptDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND ReceiptKey = @cReceiptKey
                     AND Lottable07 = @cCartonID
                     AND BeforeReceivedQty  = 0 ) 
         BEGIN
            SET @nErrNo = 116757    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'BeforeReceivedQtyReq'    
            SET @nFocusParam = 10 
            GOTO Quit  
         END
         
      END
      
      
            
      
      
--      WHILE @nPrintParam > 0 
--      BEGIN
--      
--         DELETE @tOutBoundList 
--                      
--         
--         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cReceiptKey',  @cReceiptKey)
--         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cCartonID', @cCartonID)
--         
--                           
--         
--         -- Print label
--         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
--            'PALLETLBL4', -- Report type
--            @tOutBoundList, -- Report params
--            'rdt_593Print17', 
--            @nErrNo  OUTPUT,
--            @cErrMsg OUTPUT
--            
--         IF @nErrNo <> 0
--            GOTO Quit
--            
--         SET @nPrintParam = @nPrintParam - 1 
--         
--         
--      END  
      
      DECLARE C_REVLBL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT SKU, BeforeReceivedQty 
      FROM dbo.ReceiptDetail  WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND ReceiptKey = @cReceiptKey
      AND Lottable07 = @cCartonID
      ORDER BY SKU
      
      OPEN C_REVLBL  
      FETCH NEXT FROM C_REVLBL INTO  @cSKU, @nQty 
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         
         
         SET @nNoOfCopy = 0 
         
         IF @cPrintType <> 'A' 
         BEGIN
            SET @nNoOfCopy = @cPrintType
         END
         ELSE 
         BEGIN
            SET @nNoOfCopy = @nQty 
         END
         
         
         WHILE @nNoOfCopy > 0 
         BEGIN
            DELETE FROM @tOutBoundList
            
            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cReceiptKey',  @cReceiptKey)
            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cCartonID', @cCartonID)
            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU', @cSKU)
            
            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
               'PALLETLBL4', -- Report type
               @tOutBoundList, -- Report params
               'rdt_593Print17', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
               
            IF @nErrNo <> 0
               GOTO Quit
            
            SET @nNoOfCopy  = @nNoOfCopy - 1 
            
         END  
         
         
            
         FETCH NEXT FROM C_REVLBL INTO  @cSKU, @nQty 
         
      END
      CLOSE C_REVLBL  
      DEALLOCATE C_REVLBL 
      
   END
   
   GOTO QUIT
        
         
--RollBackTran:      
--   ROLLBACK TRAN rdt_593Print17 -- Only rollback change made here      
--   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam

 
Quit:      
   --WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
   --   COMMIT TRAN rdt_593Print17    
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam 
        

GO
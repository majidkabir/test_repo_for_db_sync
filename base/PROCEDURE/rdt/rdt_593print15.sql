SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdt_593Print15                                         */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2017-10-30 1.0  ChewKP   WMS-3302 Created                               */  
/***************************************************************************/    
    
CREATE PROC [RDT].[rdt_593Print15] (    
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
          ,@nMaxNoOfCopy      INT
          ,@cOrderKey         NVARCHAR(10) 
          ,@cSKU              NVARCHAR(20)
          ,@cUPC              NVARCHAR(20) 
          ,@nNoOfCopy         INT
          ,@nSKUCnt           INT
          ,@nQty              INT
          
          

          
   DECLARE @tOutBoundList AS VariableTable
   --DECLARE @tOutBoundLis AS VariableTable
   
   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nFocusParam = 2 

   -- Check label printer blank    
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''    
   BEGIN    
      SET @nErrNo = 116251    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
      GOTO Quit    
   END    

   SET @nTranCount = @@TRANCOUNT      
         
   --BEGIN TRAN      
   --SAVE TRAN rdt_593Print15      
      
  
   
   IF @cOption ='3'
   BEGIN
      SET @cLabelNo      = @cParam1
      
      -- Check blank    
      IF ISNULL(RTRIM(@cLabelNo), '') = ''    
      BEGIN    
         SET @nErrNo = 116252    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND LabelNo = @cLabelNo ) 
      BEGIN
         SET @nErrNo = 116253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit  
      END
      
      SELECT @cPickSlipNo = PickSlipNo
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND LabelNo = @cLabelNo
      
      SELECT @cOrderKey = OrderKey
      FROM dbo.PackHeader WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND PickSlipNo = @cPickSlipNo 
      
      IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey
                  AND C_Country <> 'RU' ) 
      BEGIN
         SET @nErrNo = 116254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNotRU  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit  
      END
      
      
      
      -- Print Carton Label --
--      SET @cDataWindow = ''
--      SET @cTargetDB   = ''
      SET @cPickSlipNo = ''
      
      DECLARE C_RussiaLBL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT SKU, Qty
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo 
      ORDER BY SKU
      
      OPEN C_RussiaLBL  
      FETCH NEXT FROM C_RussiaLBL INTO  @cSKU, @nQty 
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         
         SET @nNoOfCopy = 0 
         SET @nNoOfCopy = @nQty 
         
         WHILE @nNoOfCopy > 0 
         BEGIN
            
                         
            DELETE FROM @tOutBoundList

            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)
            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)
            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU',   @cSKU)
                              

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
               'RUSSIALBL', -- Report type
               @tOutBoundList, -- Report params
               'rdt_593Print15', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
               
            IF @nErrNo <> 0
               GOTO Quit
            
            SET @nNoOfCopy  = @nNoOfCopy - 1 
            
         END  
         
         
            
         FETCH NEXT FROM C_RussiaLBL INTO  @cSKU, @nQty    
         
      END
      CLOSE C_RussiaLBL  
      DEALLOCATE C_RussiaLBL 
      
   END
   
   IF @cOption ='4'
   BEGIN
      SET @cUPC          = @cParam1
      SET @nNoOfCopy     = @cParam3
      
      -- Check blank    
      IF ISNULL(RTRIM(@cUPC), '') = ''    
      BEGIN    
         SET @nErrNo = 116255    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UPCReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit    
      END 
      
      -- Get SKU barcode count    
      --DECLARE @nSKUCnt INT    
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
         SET @nErrNo = 116256    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit     
      END    
      
      -- Check multi SKU barcode    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 116257 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod    
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit    
      END    
      
      -- Get SKU code    
      EXEC rdt.rdt_GETSKU    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cUPC          OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
      
      IF @nErrNo = 0 
      BEGIN
         SET @cSKU = @cUPC
      END
      
      IF rdt.rdtIsValidQTY( @nNoOfCopy, 1) = 0
      BEGIN
         SET @nErrNo = 116258
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvalidValue'
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Param1   
         GOTO Quit
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) 
                  WHERE ListName = 'UARU593'
                  AND StorerKey = @cStorerKey ) 
      BEGIN
         
         SELECT @nMaxNoOfCopy = Short 
         FROM dbo.Codelkup WITH (NOLOCK) 
         WHERE ListName = 'UARU593'
         AND StorerKey = @cStorerKey
         
         IF @nNoOfCopy > ISNULL( @nMaxNoOfCopy, 0 ) 
         BEGIN
            SET @nErrNo = 116259
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'ExceedNoOfCopy'
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Param1   
            GOTO Quit
            
            
         END
      END
                  
      
      SET @cLabelNo = ''
      
      
      WHILE @nNoOfCopy > 0 
      BEGIN
         
                      
         DELETE FROM @tOutBoundList

         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU',   @cSKU)
                           

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
            'RUSSIALBL', -- Report type
            @tOutBoundList, -- Report params
            'rdt_593Print15', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
            
         IF @nErrNo <> 0
            GOTO Quit
         
         SET @nNoOfCopy  = @nNoOfCopy - 1 
         
      END      
      
      
      
   END
   GOTO QUIT
        
         
--RollBackTran:      
--   ROLLBACK TRAN rdt_593Print15 -- Only rollback change made here      
--   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam

 
Quit:      
   --WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
   --   COMMIT TRAN rdt_593Print15    
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam 
        

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdt_593Print18                                         */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2017-11-16 1.0  ChewKP   WMS-3431 Created                               */  
/***************************************************************************/    
    
CREATE PROC [RDT].[rdt_593Print18] (    
   @nMobile    INT,    
   @nFunc      INT,    
   @nStep      INT,    
   @cLangCode  NVARCHAR( 3),    
   @cStorerKey NVARCHAR( 15),    
   @cOption    NVARCHAR( 1),    
   @cParam1    NVARCHAR(20),  
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
          ,@cSKUInfo02        NVARCHAR(30) 
          ,@cSKUInfo21        NVARCHAR(30) 
          ,@cDefaultLabelType NVARCHAR( 20) 
          ,@nWarningMsg       INT
          
          

          
   DECLARE @tOutBoundList AS VariableTable
   --DECLARE @tOutBoundLis AS VariableTable
   
   SET @nTranCount = @@TRANCOUNT  
   
   SET @nWarningMsg = 0    
         
   --BEGIN TRAN      
   --SAVE TRAN rdt_593Print18      
   
    SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nFocusParam = 2 

   -- Check label printer blank    
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''    
   BEGIN    
      SET @nErrNo = 116955    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrinterReq    
      GOTO Quit    
   END  
   
   
   
   IF @cOption ='1'
   BEGIN
      SET @cLabelNo      = @cParam1
      
      -- Check blank    
      IF ISNULL(RTRIM(@cLabelNo), '') = ''    
      BEGIN    
         SET @nErrNo = 116951    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND LabelNo = @cLabelNo ) 
      BEGIN
         SET @nErrNo = 116952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit  
      END
      
--      IF NOT EXISTS ( SELECT 1
--                      FROM dbo.PackDetail PD WITH (NOLOCK) 
--                      INNER JOIN dbo.SKUInfo SKUInfo WITH (NOLOCK) ON SKUInfo.StorerKey = PD.StorerKey AND SKUInfo.SKU = PD.SKU 
--                      WHERE PD.StorerKey = @cStorerKey
--                      AND PD.LabelNo = @cLabelNo  ) 
--      BEGIN
--         SET @nErrNo = 116953
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SKUInfoNotExist  
--         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
--         GOTO Quit  
--      END
      
      
      SELECT @cPickSlipNo = PickSlipNo
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND LabelNo = @cLabelNo
      
      
      -- Print Carton Label --
--      SET @cDataWindow = ''
--      SET @cTargetDB   = ''
      
      
         
      DECLARE C_MASTLBL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PD.SKU,  PD.Qty 
      FROM dbo.PackDetail PD WITH (NOLOCK) 
      --INNER JOIN dbo.SKUInfo SKUInfo WITH (NOLOCK) ON SKUInfo.StorerKey = PD.StorerKey AND SKUInfo.SKU = PD.SKU 
      WHERE PD.StorerKey = @cStorerKey
      AND PD.LabelNo = @cLabelNo 
      ORDER BY PD.SKU
      
      OPEN C_MASTLBL  
      FETCH NEXT FROM C_MASTLBL INTO  @cSKU, @nQty 
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         SET @cSKUInfo02 = ''
         SET @cSKUInfo21 = '' 
         
         SELECT @cSKUInfo02 = ISNULL(ExtendedField02,'') 
              , @cSKUInfo21 = ISNULL(ExtendedField21,'') 
         FROM dbo.SKUInfo WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 
         
         

         IF @@RowCount = 0 
         BEGIN
            SET @nWarningMsg = 1 
            GOTO NEXTLOOP
            --FETCH NEXT FROM C_MASTLBL INTO  @cSKU, @nQty 

            --SET @cSKUInfo02 = ''
            --SET @cSKUInfo21 = '' 
         
            --SELECT @cSKUInfo02 = ISNULL(ExtendedField02,'') 
            --     , @cSKUInfo21 = ISNULL(ExtendedField21,'') 
            --FROM dbo.SKUInfo WITH (NOLOCK) 
            --WHERE StorerKey = @cStorerKey
            --AND SKU = @cSKU 
         END



         --SELECT @cSKU '@cSKU' , @cSKUInfo02 '@cSKUInfo02' , @cSKUInfo21 '@cSKUInfo21' 
         
--         IF ISNULL(@cSKUInfo02,'')  = ''
--         BEGIN
--            
--            
--            --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
--            --GOTO Quit  
--         END
         
         
         SELECT @cLabelType    = UDF01 
         FROM dbo.Codelkup WITH (NOLOCK) 
         WHERE ListName = 'MASTLBL'
         AND Code = @cSKUInfo02 
         AND StorerKey = @cStorerKey

         
         
         IF ISNULL(@cLabelType,'')  <> '' AND ISNULL(@cSKUInfo21,'')  <> '' 
         BEGIN
            

            SET @nNoOfCopy = 0 
            SET @nNoOfCopy = @nQty 
            
            WHILE @nNoOfCopy > 0 
            BEGIN
               DELETE FROM @tOutBoundList
               
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU',   @cSKU)
               
               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
                  @cLabelType, -- Report type
                  @tOutBoundList, -- Report params
                  'rdt_593Print18', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
                  
               IF @nErrNo <> 0
                  GOTO Quit
               
               SET @nNoOfCopy  = @nNoOfCopy - 1 
               
            END  
         
         END
         ELSE
         BEGIN
            SET @cDefaultLabelType = '' 
            
            IF @cSKUInfo21 <> ''
            BEGIN
               SELECT @cDefaultLabelType = UDF01 
               FROM dbo.Codelkup WITH (NOLOCK) 
               WHERE ListName = 'MASTLBL'
               AND StorerKey = @cStorerKey 
               AND Long = 'DEFAULT'
            END
            ELSE
            BEGIN
               SELECT @cDefaultLabelType = UDF01 
               FROM dbo.Codelkup WITH (NOLOCK) 
               WHERE ListName = 'MASTLBL'
               AND StorerKey = @cStorerKey 
               AND Long = 'SKUONLY'
            END

            PRINT @cDefaultLabelType
            
            SET @nNoOfCopy = 0 
            SET @nNoOfCopy = @nQty 
            
            WHILE @nNoOfCopy > 0 
            BEGIN
               DELETE FROM @tOutBoundList
               
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU',   @cSKU)
               
               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
                  @cDefaultLabelType, -- Report type
                  @tOutBoundList, -- Report params
                  'rdt_593Print18', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
                  
               IF @nErrNo <> 0
                  GOTO Quit
               
               SET @nNoOfCopy  = @nNoOfCopy - 1 
               
            END  
         END
         
         NEXTLOOP:   
         FETCH NEXT FROM C_MASTLBL INTO  @cSKU, @nQty  
         
      END
      CLOSE C_MASTLBL  
      DEALLOCATE C_MASTLBL 
      
      IF @nWarningMsg = 1 
      BEGIN
         SET @nErrNo = 116954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SKUInfoNotExist  
         GOTO QUIT
      END
      
   END
   
   IF @cOption ='2'
   BEGIN
      SET @cUPC          = @cParam1
      SET @nNoOfCopy     = @cParam3
      
      -- Check blank    
      IF ISNULL(RTRIM(@cUPC), '') = ''    
      BEGIN    
         SET @nErrNo = 116956    
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
         SET @nErrNo = 116957    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit     
      END    
      
      -- Check multi SKU barcode    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 116958 
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
         SET @nErrNo = 116959
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvalidValue'
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Param1   
         GOTO Quit
      END
      
      SELECT @cSKUInfo02 = SKUInfo.ExtendedField02
           , @cSKUInfo21 = SKUInfo.ExtendedField21
      FROM dbo.SKU SKU WITH (NOLOCK) 
      INNER JOIN SKUInfo SKUInfo WITH (NOLOCK) ON SKU.StorerKey = SKUInfo.StorerKey AND SKU.SKU = SKUInfo.SKU
      WHERE SKU.StorerKey = @cStorerKey
      AND SKU.SKU = @cSKU
      
      IF @@ROWCount = 0 
      BEGIN
         SET @nErrNo = 116960
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SKUInfoNotExist  
         GOTO QUIT
      END
      
      IF ISNULL(@cSKUInfo02,'')   <> ''
      BEGIN
         SELECT @cLabelType    = UDF01 
         FROM dbo.Codelkup WITH (NOLOCK) 
         WHERE ListName = 'MASTLBL'
         AND Code = @cSKUInfo02 
         AND StorerKey = @cStorerKey
      END
      ELSE
      BEGIN
         
         IF ISNULL(@cSKUInfo21, '' ) <> ''
         BEGIN
            SELECT @cLabelType = UDF01 
            FROM dbo.Codelkup WITH (NOLOCK) 
            WHERE ListName = 'MASTLBL'
            AND StorerKey = @cStorerKey 
            AND Long = 'DEFAULT'
         END
         ELSE
         BEGIN
            SELECT @cLabelType = UDF01 
            FROM dbo.Codelkup WITH (NOLOCK) 
            WHERE ListName = 'MASTLBL'
            AND StorerKey = @cStorerKey 
            AND Long = 'SKUONLY'
         END
      END
      
      IF ISNULL(@cLabelType, '' ) <> '' 
      BEGIN
         WHILE @nNoOfCopy > 0 
         BEGIN
                                     
            DELETE FROM @tOutBoundList

            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)
            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU',   @cSKU)
                              

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
               @cLabelType, -- Report type
               @tOutBoundList, -- Report params
               'rdt_593Print18', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
               
            IF @nErrNo <> 0
               GOTO Quit
            
            SET @nNoOfCopy  = @nNoOfCopy - 1 
            
         END  
      END    
      
      
     
   END
   GOTO QUIT
        
         
--RollBackTran:      
--   ROLLBACK TRAN rdt_593Print18 -- Only rollback change made here      
--   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam

 
Quit:      
   --WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
   --   COMMIT TRAN rdt_593Print18    
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam 
        

GO
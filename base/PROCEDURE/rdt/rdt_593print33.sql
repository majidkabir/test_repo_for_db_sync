SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_593Print33                                         */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2021-06-02 1.0  James    WMS-17143. Created                             */  
/* 2022-03-14 1.1  James    WMS-19131 Add pdf printing (james01)           */  
/* 2022-09-14 1.2  James    WMS-20641 Change orderkey to loadkey (james02) */  
/* 2023-05-10 1.3  James    WMS-22422 Change print condition (james03)     */
/***************************************************************************/  
  
CREATE   PROC [RDT].[rdt_593Print33] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- ASN  
   @cParam2    NVARCHAR(20),  -- ID  
   @cParam3    NVARCHAR(20),  -- SKU/UPC  
   @cParam4    NVARCHAR(20),  
   @cParam5    NVARCHAR(20),  
   @nErrNo     INT OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @cPaperPrinter  NVARCHAR( 10)  
          ,@cPH_StorerKey  NVARCHAR( 15)  
          ,@cLabelNo       NVARCHAR( 20)  
          ,@cPickSlipNo    NVARCHAR( 10)  
          ,@cDataWindow    NVARCHAR( 50)    
          ,@cTargetDB      NVARCHAR( 20)     
          ,@cReportType    NVARCHAR( 10)   
          ,@cLoadKey       NVARCHAR( 10)   
          ,@cPickHeaderKey NVARCHAR( 10)   
          ,@nCartonNo      INT  
          ,@nTTLCnts       INT  
          ,@cOrderKey      NVARCHAR( 10)  
          ,@cSalesman      NVARCHAR( 30)  
          ,@cUDF01         NVARCHAR( 60)  
          ,@cUDF02         NVARCHAR( 60)  
          ,@cPaperPrinter1 NVARCHAR( 10)  
          ,@cPaperPrinter2 NVARCHAR( 10)  
          ,@tCR            VariableTable  
          ,@tSI            VariableTable  
  
   DECLARE @cErrMsg01        NVARCHAR( 20),  
           @cErrMsg02        NVARCHAR( 20),  
           @cErrMsg03        NVARCHAR( 20),  
           @cErrMsg04        NVARCHAR( 20),  
           @cErrMsg05        NVARCHAR( 20),  
           @cErrMsg06        NVARCHAR( 20),  
           @cErrMsg07        NVARCHAR( 20),  
           @cErrMsg08        NVARCHAR( 20),  
           @cErrMsg09        NVARCHAR( 20),  
           @cErrMsg10        NVARCHAR( 20),  
           @cErrMsg11        NVARCHAR( 20),  
           @cErrMsg12        NVARCHAR( 20),  
           @cErrMsg13        NVARCHAR( 20),  
           @cErrMsg14        NVARCHAR( 20),  
           @cErrMsg15        NVARCHAR( 20)  
  
   DECLARE @cFilePath         NVARCHAR(100)         
   DECLARE @cPrintFilePath    NVARCHAR(100)        
   DECLARE @cFilePrefix       NVARCHAR( 30)  
   DECLARE @cFileName         NVARCHAR( 50)  
   DECLARE @cWinPrinter       NVARCHAR(128)  
   DECLARE @cWinPrinterName   NVARCHAR(100)  
   DECLARE @cPrintCommand     NVARCHAR(MAX)  
   DECLARE @cPrinterName      NVARCHAR(100)  
   DECLARE @cPaperPrinterPDF1 NVARCHAR( 10)  
   DECLARE @cPaperPrinterPDF2 NVARCHAR( 10)  
  
   -- Parameter mapping  
   SET @cLoadKey = ''  
  
   -- Check blank  
   IF ISNULL( @cParam1, '') = ''  
   BEGIN  
      SET @nErrNo = 168701  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Input required  
      GOTO Quit  
   END  
  
   SET @cOrderKey = @cParam1  
     
   SELECT @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
   -- Check blank  
   IF ISNULL( @cPaperPrinter, '') = ''  
   BEGIN  
      SET @nErrNo = 168702  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Printer req  
      GOTO Quit  
   END  
     
   IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReportToPrinter WITH (NOLOCK)  
                   WHERE Function_ID = @nFunc  
                   AND   StorerKey = @cStorerKey  
                   AND   PrinterGroup = @cPaperPrinter)  
   -- Check blank  
   BEGIN  
      SET @nErrNo = 168703  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PrinterGroup req  
      GOTO Quit  
   END  
     
   DECLARE @curPrint CURSOR  
   SET @curPrint = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
   SELECT OrderKey FROM dbo.Orders WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
   AND   LoadKey = @cLoadKey  
   ORDER BY 1  
   OPEN @curPrint  
   FETCH NEXT FROM @curPrint INTO @cOrderKey  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
    SET @cSalesman = ''  
      SELECT @cSalesman = Salesman   
      FROM dbo.ORDERS WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey  
        
      SET @cUDF01 = ''  
      SET @cUDF02 = ''  
      SELECT @cUDF01 = UDF01,  
             @cUDF02 = UDF02  
      FROM dbo.CODELKUP WITH (NOLOCK)  
      WHERE LISTNAME = 'PRTVALID'  
      AND   Long = @cSalesman  
      AND   Storerkey = @cStorerKey  
  
      -- Check blank  
      IF ISNULL( @cUDF01, '') = '' AND ISNULL( @cUDF02, '') = ''  
      BEGIN  
         SET @nErrNo = 168704  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ReportType req  
         GOTO Quit  
      END  
  
      IF ISNULL( @cUDF01, '') = 'CR'  
      BEGIN  
         SELECT @cFilePath = Long,   
                @cPrintFilePath = Notes,   
                @cReportType = Code2,   
                @cFilePrefix = UDF01  
         FROM dbo.CODELKUP WITH (NOLOCK)        
         WHERE LISTNAME = 'PrtbyShipK'        
         AND   StorerKey = @cStorerKey  
         AND   code2 = @cUDF01 + '_PDF'  
        
         IF ISNULL( @cFilePath, '') = ''      
         BEGIN      
            SET @nErrNo = 168705       
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup FilePath      
            GOTO Quit     
         END  
      END  
  
      IF ISNULL( @cUDF02, '') = 'SI'  
      BEGIN  
         SELECT @cFilePath = Long,   
                @cPrintFilePath = Notes,   
                @cReportType = Code2,   
                @cFilePrefix = UDF01  
         FROM dbo.CODELKUP WITH (NOLOCK)        
         WHERE LISTNAME = 'PrtbyShipK'        
         AND   StorerKey = @cStorerKey  
         AND   code2 = @cUDF02 + '_PDF'  
        
         IF ISNULL( @cFilePath, '') = ''      
         BEGIN      
            SET @nErrNo = 168706       
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup FilePath      
            GOTO Quit     
         END  
      END  
  
      IF ISNULL( @cUDF01, '') = 'CR'  
      BEGIN  
         SELECT @cPaperPrinter1 = PrinterID  
         FROM rdt.rdtReportToPrinter WITH (NOLOCK)  
         WHERE Function_ID = @nFunc  
         AND   StorerKey = @cStorerKey  
         AND   PrinterGroup = @cPaperPrinter  
         AND   ReportType = @cUDF01  
        
         INSERT INTO @tCR (Variable, Value) VALUES ( '@cOrderkey',     @cOrderkey)    
             
         -- Print label    
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter1,      
            @cUDF01, -- Report type    
            @tCR, -- Report params    
            'rdt_593Print33',     
            @nErrNo  OUTPUT,    
            @cErrMsg OUTPUT     
                 
         IF @nErrNo <> 0  
            GOTO Quit  
  
         SELECT @cPaperPrinterPDF1 = PrinterID  
         FROM rdt.rdtReportToPrinter WITH (NOLOCK)  
         WHERE Function_ID = @nFunc  
         AND   StorerKey = @cStorerKey  
         AND   PrinterGroup = @cPaperPrinter  
         AND   ReportType = @cUDF01 + '_PDF'  
        
         -- Print pdf  
         SET @cWinPrinter = ''  
         SET @cPrinterName = ''  
        
         SELECT @cWinPrinter = WinPrinter  
         FROM rdt.rdtPrinter WITH (NOLOCK)    
         WHERE PrinterID = @cPaperPrinterPDF1  
  
         IF CHARINDEX(',' , @cWinPrinter) > 0   
         BEGIN  
            SET @cPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )      
            SET @cWinPrinterName = @cPrinterName  
         END  
         ELSE  
         BEGIN  
            SET @cPrinterName =  @cPaperPrinterPDF1  
            SET @cWinPrinterName = @cWinPrinter  
         END  
           
         SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END  
         SET @cFileName = @cFilePrefix + RTRIM( @cOrderKey) + '.pdf'       
         SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cFilePath + '\' + @cFileName + '" "0" "2" "' + @cWinPrinterName + '"'                                
  
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPrinterName,  
            @cUDF01,     -- Report type  
            @tCR,    -- Report params  
            'rdt_593Print33',   
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT,  
            1,  
            @cPrintCommand  
  
       IF @nErrNo <> 0  
            GOTO Quit  
      END  
  
      IF ISNULL( @cUDF02, '') = 'SI'  
      BEGIN  
         SELECT @cPaperPrinter2 = PrinterID  
         FROM rdt.rdtReportToPrinter WITH (NOLOCK)  
         WHERE Function_ID = @nFunc  
         AND   StorerKey = @cStorerKey  
         AND   PrinterGroup = @cPaperPrinter  
         AND   ReportType = @cUDF02  
        
         INSERT INTO @tSI (Variable, Value) VALUES ( '@cOrderkey',     @cOrderkey)    
             
         -- Print label    
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter2,      
            @cUDF02, -- Report type    
            @tSI, -- Report params    
            'rdt_593Print33',     
            @nErrNo  OUTPUT,    
            @cErrMsg OUTPUT     
                 
         IF @nErrNo <> 0  
            GOTO Quit  
  
         SELECT @cPaperPrinterPDF2 = PrinterID  
         FROM rdt.rdtReportToPrinter WITH (NOLOCK)  
         WHERE Function_ID = @nFunc  
         AND   StorerKey = @cStorerKey  
         AND   PrinterGroup = @cPaperPrinter  
         AND   ReportType = @cUDF02 + '_PDF'  
        
         -- Print pdf  
         SET @cWinPrinter = ''  
         SET @cPrinterName = ''  
        
         SELECT @cWinPrinter = WinPrinter  
         FROM rdt.rdtPrinter WITH (NOLOCK)    
         WHERE PrinterID = @cPaperPrinterPDF2  
  
         IF CHARINDEX(',' , @cWinPrinter) > 0   
         BEGIN  
            SET @cPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )      
            SET @cWinPrinterName = @cPrinterName  
         END  
         ELSE  
         BEGIN  
            SET @cPrinterName =  @cPaperPrinterPDF2  
            SET @cWinPrinterName = @cWinPrinter  
         END  
           
         SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END  
         SET @cFileName = @cFilePrefix + RTRIM( @cOrderKey) + '.pdf'       
         SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cFilePath + '\' + @cFileName + '" "0" "2" "' + @cWinPrinterName + '"'                                
  
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPrinterName,  
            @cUDF02,     -- Report type  
            @tSI,    -- Report params  
            'rdt_593Print33',   
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT,  
            1,  
            @cPrintCommand  
  
       IF @nErrNo <> 0  
            GOTO Quit  
  
         FETCH NEXT FROM @curPrint INTO @cOrderKey  
      END  
   END  
Quit:  

GO
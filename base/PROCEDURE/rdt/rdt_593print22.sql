SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_593Print22                                      */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Print way bill based on shipperkey                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2018-09-03  1.0  James    WMS-6046 Created                           */  
/* 2018-10-18  1.1  James    Add print using tracking no (james01)      */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_593Print22] (  
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- StorerKey
   @cParam2    NVARCHAR(20),  -- OrderKey
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT 
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cTrackingNo       NVARCHAR( 20)
   DECLARE @cReportType       NVARCHAR( 10)
   DECLARE @cProcessType      NVARCHAR( 15)
   DECLARE @cShipperKey       NVARCHAR( 15)
   DECLARE @cFilePath         NVARCHAR(100)       
   DECLARE @cPrintFilePath    NVARCHAR(100)      
   DECLARE @cPrintCommand     NVARCHAR(MAX)    
   DECLARE @cWinPrinter       NVARCHAR(128)  
   DECLARE @cPrinterName      NVARCHAR(100)   
   DECLARE @cFileName         NVARCHAR( 50)          
   DECLARE @cPrinterInGroup   NVARCHAR( 10)     
   DECLARE @cLabelPrinter     NVARCHAR( 10)     
   DECLARE @cLabelNo          NVARCHAR( 20)     
   DECLARE @cExternOrderKey   NVARCHAR( 30)
   DECLARE @cTempOrderKey     NVARCHAR( 10)     
   DECLARE @nCartonNo         INT

   SET @cTempOrderKey = @cParam1
   SET @cTrackingNo = @cParam2

   -- Check blank
   IF ISNULL( @cTempOrderKey, '') = '' AND ISNULL( @cTrackingNo, '') = ''
   BEGIN    
      SET @nErrNo = 129251     
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Value    
      GOTO Quit    
   END  

   -- Check orderkey validity
   IF ISNULL( @cTempOrderKey, '') <> ''    
   BEGIN    
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.Orders WITH (NOLOCK) 
                      WHERE OrderKey = @cTempOrderKey)
      BEGIN
         SET @nErrNo = 129252     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OrderKey    
         GOTO Quit    
      END

      SET @cOrderKey = @cTempOrderKey
   END  

   -- Check tracking no validity
   IF ISNULL( @cTrackingNo, '') <> ''    
   BEGIN    
      SET @cOrderKey = ''
      SELECT @cOrderKey = OrderKey
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   TrackingNo = @cTrackingNo
      AND ( ( ISNULL( @cTempOrderKey, '') = '') OR ( OrderKey = @cTempOrderKey))

      IF ISNULL( @cOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 129253     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Track #    
         GOTO Quit    
      END
   END  

   IF ISNULL( @cOrderKey, '') = ''
   BEGIN
      SET @nErrNo = 129254     
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No record
      GOTO Quit    
   END

   SELECT @cLabelPrinter = Printer
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cShipperKey = ShipperKey,
          @cTrackingNo = TrackingNo,
          @cExternOrderKey = ExternOrderKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   -- Check if it is Metapack printing    
   SELECT @cFilePath = Long, 
          @cPrintFilePath = Notes,
          @cReportType = Code2
   FROM dbo.CODELKUP WITH (NOLOCK)      
   WHERE LISTNAME = 'PrtbyShipK'      
   AND   Code = @cShipperKey    
   --insert into traceinfo (tracename, timein, col1, col2) values ('thg', getdate(), @cShipperKey, @cOrderKey)
   -- Make sure we have setup the printer id
   -- Record searched based on func + storer + reporttype + printergroup (shipperkey)
   SELECT @cPrinterInGroup = PrinterID
   FROM rdt.rdtReportToPrinter WITH (NOLOCK)
   WHERE Function_ID = @nFunc
   AND   StorerKey = @cStorerKey
   AND   ReportType = @cReportType
   AND   PrinterGroup = @cLabelPrinter

   -- Determine print type (command/bartender)
   SELECT @cProcessType = ProcessType
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
      SET @cPrinterName = @cLabelPrinter

   IF @cProcessType = 'QCOMMANDER'
   BEGIN
      IF ISNULL( @cFilePath, '') <> ''    
      BEGIN    
         SET @cFileName = 'THG_' + RTRIM( @cExternOrderKey) + '.pdf'     
         SET @cPrintCommand = '"' + @cPrintFilePath + '" /t "' + @cFilePath + '\' + @cFileName + '" "' + @cPrinterName + '"'                              

         DECLARE @tRDTPrintJob AS VariableTable
      
         -- Print label (pass in shipperkey as label printer. then rdt_print will look for correct printer id)
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '', 
            @cReportType,     -- Report type
            @tRDTPrintJob,    -- Report params
            'rdt_593Print22', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            1,
            @cPrintCommand

            --IF @nErrNo <> 0 SET @cErrMsg = @cPrinterName
      END
   END
   ELSE
   BEGIN
      -- Common params
      DECLARE @tSHIPLabel AS VariableTable
      INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
      INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey) 
      INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cTrackingNo', @cTrackingNo) 
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@nCartonNo', @nCartonNo)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '', 
         @cReportType, -- Report type
         @tSHIPLabel, -- Report params
         'rdt_593Print22', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
   END
   --delete from traceinfo where tracename = '593'
   --insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5, step1) values ('593', getdate(), @cReportType, @cStorerKey, @cOrderKey, @cLabelPrinter, @cPrinterName, @cPrinterInGroup)
	IF @nErrNo <> 0
      GOTO Quit
           
Quit: 
        
      
END  


GO
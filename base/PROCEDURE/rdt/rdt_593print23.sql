SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_593Print23                                      */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Print way bill based on shipperkey                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2018-10-18  1.0  James    WMS-6262 Created                           */  
/* 2019-08-05  1.1  James    WMS-9955 Add LabelNo param (james01)       */
/* 2020-06-05  1.2  James    WMS-13504 Cater multiple printing process  */
/*                           process (james02)                          */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_593Print23] (  
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
   DECLARE @cWinPrinterName   NVARCHAR(100)   
   DECLARE @cFileName         NVARCHAR( 50)    
   DECLARE @cPrinterInGroup   NVARCHAR( 10)     
   DECLARE @cLabelPrinter     NVARCHAR( 10)     
   DECLARE @cLabelNo          NVARCHAR( 20)     
   DECLARE @cExternOrderKey   NVARCHAR( 30)
   DECLARE @cTempOrderKey     NVARCHAR( 10)     
   DECLARE @nCartonNo         INT
   DECLARE @cFilePrefix       NVARCHAR( 30)
   DECLARE @cPaperType        NVARCHAR( 10)   
   DECLARE @cPaperPrinter     NVARCHAR( 10)  
   DECLARE @cPickSlipNo       NVARCHAR( 10)  

   SET @cTempOrderKey = @cParam1
   SET @cTrackingNo = @cParam2
   SET @cLabelNo = @cParam3

   -- Check blank
   IF ISNULL( @cTempOrderKey, '') = '' AND ISNULL( @cTrackingNo, '') = '' AND ISNULL( @cLabelNo, '') = ''
   BEGIN    
      SET @nErrNo = 130501     
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
         SET @nErrNo = 130502     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OrderKey    
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
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
      AND ( ( ISNULL( TrackingNo, '') <> '' AND TrackingNo = @cTrackingNo) OR 
            ( ISNULL( UserDefine04, '') <> '' AND UserDefine04 = @cTrackingNo))
      AND ( ( ISNULL( @cTempOrderKey, '') = '') OR ( OrderKey = @cTempOrderKey))

      IF ISNULL( @cOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 130503     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Track #    
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param2
         GOTO Quit    
      END
   END  

   IF ISNULL( @cLabelNo, '') <> ''
   BEGIN
      SELECT @cPickSlipNo = PickSlipNo 
            ,@nCartonNo   = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo 
      
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 130505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo  
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param3
         GOTO Quit  
      END

      SELECT @cOrderKey = OrderKey 
      FROM dbo.PackHeader WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo 
   END

   IF ISNULL( @cOrderKey, '') = ''
   BEGIN
      SET @nErrNo = 130504     
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No record
      GOTO Quit    
   END

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cShipperKey = ShipperKey,
          @cTrackingNo = TrackingNo,
          @cExternOrderKey = ExternOrderKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   DECLARE Cur_Print CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT Long, Notes, Code2, UDF01
   FROM dbo.CODELKUP WITH (NOLOCK)      
   WHERE LISTNAME = 'PrtbyShipK'      
   AND   Code = @cShipperKey 
   AND   StorerKey = @cStorerKey
   OPEN CUR_Print
   FETCH NEXT FROM CUR_Print INTO @cFilePath, @cPrintFilePath, @cReportType, @cFilePrefix
   WHILE @@FETCH_STATUS = 0
   BEGIN

      -- Make sure we have setup the printer id
      -- Record searched based on func + storer + reporttype + printergroup (shipperkey)
      SELECT @cPrinterInGroup = PrinterID
      FROM rdt.rdtReportToPrinter WITH (NOLOCK)
      WHERE Function_ID = @nFunc
      AND   StorerKey = @cStorerKey
      AND   ReportType = @cReportType
      AND   PrinterGroup = @cLabelPrinter

      IF @@ROWCOUNT > 0
      BEGIN
         -- Determine print type (command/bartender)
         SELECT TOP 1
                @cProcessType = ProcessType, 
                @cPaperType = PaperType
         FROM rdt.RDTREPORT WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReportType = @cReportType
         AND  (Function_ID = @nFunc OR Function_ID = 0)
         ORDER BY Function_ID DESC

         -- PDF use foxit then need use the winspool printer name
         IF @cReportType LIKE 'PDFWBILL%'   
         BEGIN
            SELECT @cWinPrinter = WinPrinter
            FROM rdt.rdtPrinter WITH (NOLOCK)  
            WHERE PrinterID = CASE WHEN ISNULL( @cPrinterInGroup, '') <> '' THEN @cPrinterInGroup ELSE @cLabelPrinter END
         
            IF CHARINDEX(',' , @cWinPrinter) > 0 
            BEGIN
               SET @cPrinterName = @cPrinterInGroup
               SET @cWinPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) ) 
            END
            ELSE
            BEGIN
               SET @cPrinterName =  @cPrinterInGroup
               SET @cWinPrinterName = @cWinPrinter
            END
         END
         ELSE
         BEGIN
            IF @cPaperType = 'LABEL'
               SET @cPrinterName = @cLabelPrinter
            ELSE
               SET @cPrinterName = @cPaperPrinter
         END

         IF ISNULL( @cFilePath, '') <> ''    
         BEGIN    
            SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
            SET @cFileName = @cFilePrefix + RTRIM( @cOrderKey) + '.pdf'     
            SET @cPrintCommand = '"' + @cPrintFilePath + '" /t "' + @cFilePath + '\' + @cFileName + '" "' + @cWinPrinterName + '"'                              

            DECLARE @tRDTPrintJob AS VariableTable
      
            -- Print label (pass in shipperkey as label printer. then rdt_print will look for correct printer id)
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '', 
               @cReportType,     -- Report type
               @tRDTPrintJob,    -- Report params
               'rdt_593Print23', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               1,
               @cPrintCommand
         END
         ELSE  -- For datawindow printing
         BEGIN
            DECLARE @tSHIPLabel AS VariableTable
            DELETE FROM @tSHIPLabel
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey) 
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cTrackingNo', @cTrackingNo) 
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@nCartonNo', @nCartonNo)
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)   
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)   
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)  

            IF @cPaperType = 'LABEL'
               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '',
                  @cReportType, -- Report type
                  @tSHIPLabel, -- Report params
                  'rdt_593Print23', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
            ELSE
               -- Print paper
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPrinterName, 
                  @cReportType, -- Report type
                  @tSHIPLabel, -- Report params
                  'rdt_593Print23', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

         END

	      IF @nErrNo <> 0
            BREAK
      END

      FETCH NEXT FROM CUR_Print INTO @cFilePath, @cPrintFilePath, @cReportType, @cFilePrefix
   END
   CLOSE Cur_Print
   DEALLOCATE Cur_Print

Quit: 
       
      
END  


GO
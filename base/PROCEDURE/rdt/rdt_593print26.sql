SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Store procedure: rdt_593Print26                                      */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Print PDF                                                   */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2019-08-05  1.0  James    WMS-10110. Created                         */  
/* 2020-05-31  1.1  James    Enhance label printing (Add-hoc) (james01) */
/* 2021-04-16  1.2  James    WMS-16024 Standarized use of TrackingNo    */
/*                           (james02)                                  */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_593Print26] (  
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
   DECLARE @cFolder           NVARCHAR( 30)
   DECLARE @cRptID            NVARCHAR( 10)
   DECLARE @cBrand            NVARCHAR( 30)

   -- Check blank
   IF ISNULL( @cParam1, '') = '' 
   BEGIN    
      SET @nErrNo = 142551     
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Value    
      GOTO Quit    
   END  

   -- Check orderkey validity
   SELECT @cOrderKey = OrderKey,
          @cShipperKey = ShipperKey,
          @cBrand = Salesman
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   --AND   UserDefine04 = @cParam1
   AND   TrackingNo = @cParam1 -- (james02)

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 142552     
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv OrderKey    
      GOTO Quit    
   END

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   DECLARE Cur_Print CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT Long, Notes, Code2, UDF01
   FROM dbo.CODELKUP WITH (NOLOCK)      
   WHERE LISTNAME = 'PrtbyShipK'      
   AND   StorerKey = @cStorerKey
   ORDER BY Code
   OPEN CUR_Print
   FETCH NEXT FROM CUR_Print INTO @cFilePath, @cPrintFilePath, @cReportType, @cFilePrefix
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- PDF use foxit then need use the winspool printer name
      IF @cFilePrefix LIKE '%INV%'   
      BEGIN
         SELECT @cWinPrinter = WinPrinter
         FROM rdt.rdtPrinter WITH (NOLOCK)  
         WHERE PrinterID = @cPaperPrinter

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 142553     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Paper Printer    
            GOTO Quit    
         END
      END
      ELSE
      BEGIN
         SELECT @cWinPrinter = WinPrinter
         FROM rdt.rdtPrinter WITH (NOLOCK)  
         WHERE PrinterID = @cLabelPrinter

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 142554     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Label Printer    
            GOTO Quit    
         END
      END
         
      IF CHARINDEX(',' , @cWinPrinter) > 0 
      BEGIN
         SET @cPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )    
         SET @cWinPrinterName = @cPrinterName
      END
      ELSE
      BEGIN
         SET @cPrinterName =  @cPrinterInGroup
         SET @cWinPrinterName = @cWinPrinter
      END

      IF ISNULL( @cFilePath, '') = ''    
      BEGIN    
         SET @nErrNo = 142555     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup FilePath    
         GOTO Quit   
      END

      DECLARE @tRDTPrintJob AS VariableTable
      
      IF @cFilePrefix LIKE '%INV%'
      BEGIN
         SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
         SET @cFileName = @cFilePrefix + RTRIM( @cOrderKey) + '.pdf'     
         SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cFilePath + '\' + @cFileName + '" "0" "2" "' + @cWinPrinterName + '"'                              

         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
            @cReportType,     -- Report type
            @tRDTPrintJob,    -- Report params
            'rdt_593Print26', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            1,
            @cPrintCommand

	      IF @nErrNo <> 0
            BREAK
      END
      ELSE
      BEGIN
         -- (james01)
         SELECT @cFolder = code2, 
                @cRptID = Short
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'ECOMLBLCFG'
         AND   UDF01 = 'LABELS'
         AND   Storerkey = @cStorerKey
         AND   Long = @cBrand

         IF @@ROWCOUNT = 0
         BEGIN
            SET @cFolder = 'Send2Printer'
            SET @cRptID = '0'
         END
         
         SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
         SET @cFileName = @cFilePrefix + RTRIM( @cOrderKey) + '.pdf'     
         SET @cPrintFilePath = SUBSTRING( @cPrintFilePath, 1, CHARINDEX( 'Send2Printer', @cPrintFilePath) - 1)
         SET @cPrintFilePath = @cPrintFilePath + RTRIM( @cFolder) + '\' + 'Send2Printer.exe'
         SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cFilePath + '\' + @cFileName + '" "' + @cRptID + '" "2" "' + @cWinPrinterName + '"'                              

         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
            @cReportType,     -- Report type
            @tRDTPrintJob,    -- Report params
            'rdt_593Print26', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            1,
            @cPrintCommand

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
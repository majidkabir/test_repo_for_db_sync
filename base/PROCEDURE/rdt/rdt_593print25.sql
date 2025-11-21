SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_593Print25                                      */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Print pdf file by label no (cartontrack)                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2019-07-01  1.0  James    WMS-9483 Created                           */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_593Print25] (  
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
  
   DECLARE @cFilePath         NVARCHAR(100)       
   DECLARE @cPrintFilePath    NVARCHAR(100)      
   DECLARE @cPrintCommand     NVARCHAR(MAX)    
   DECLARE @cWinPrinter       NVARCHAR(128)  
   DECLARE @cPrinterName      NVARCHAR(100)   
   DECLARE @cWinPrinterName   NVARCHAR(100)   
   DECLARE @cLabelPrinter     NVARCHAR( 10)     
   DECLARE @cLabelNo          NVARCHAR( 20)     
   DECLARE @cPaperPrinter     NVARCHAR( 10)  
   DECLARE @cFacility         NVARCHAR( 5)  

   SET @cLabelNo = @cParam1

   -- Check blank
   IF ISNULL( @cLabelNo, '') = '' 
   BEGIN    
      SET @nErrNo = 141401     
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Value    
      GOTO Quit    
   END  

   SELECT @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cFilePath = PrintData 
   FROM dbo.CartonTrack WITH (NOLOCK) 
   WHERE KeyName = @cStorerKey
   AND   LabelNo = @cLabelNo

   IF @@ROWCOUNT = 0
   BEGIN    
      SET @nErrNo = 141402     
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Label    
      GOTO Quit    
   END 

   IF ISNULL( @cFilePath, '') = ''
   BEGIN    
      SET @nErrNo = 141403     
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PDF File    
      GOTO Quit    
   END 

   -- Get the related printing info, path, file type, etc
   SELECT @cPrintFilePath = Notes   -- foxit program
   FROM dbo.CODELKUP WITH (NOLOCK) 
   WHERE ListName = 'PrintLabel' 
   AND   Code = 'QSFilePath'
   AND   Storerkey = @cStorerKey
   AND   (( ISNULL( code2, '') = '') OR ( code2 = @cFacility))

   IF ISNULL( @cPrintFilePath, '') = ''
   BEGIN    
      SET @nErrNo = 141404     
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Print Path    
      GOTO Quit    
   END 

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cWinPrinter = WinPrinter
   FROM rdt.rdtPrinter WITH (NOLOCK)  
   WHERE PrinterID = @cLabelPrinter
         
   IF CHARINDEX(',' , @cWinPrinter) > 0 
   BEGIN
      SET @cWinPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )    
      SET @cPrinterName = @cLabelPrinter
   END
   ELSE
   BEGIN
      SET @cPrinterName =  @cLabelPrinter
      SET @cWinPrinterName = @cWinPrinter
   END

   --SET @cPrintCommand = '"' + @cPrintFilePath + '" /t "' + @cFilePath + '" "' + @cWinPrinterName + '"'                              
   SET @cPrintCommand = @cPrintFilePath + ' /t "' + @cFilePath + '" "' + @cWinPrinterName + '"'                              

   DECLARE @tRDTPrintJob AS VariableTable
      
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '',
      'ShipLabel',      -- Report type
      @tRDTPrintJob,    -- Report params
      'rdt_593Print25', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT,
      1,
      @cPrintCommand

Quit: 
        
      
END  


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_843ExtPrint01                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Print way bill based on shipperkey                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2020-10-08  1.0  Chermaine WMS-15046 Created                         */  
/* 2021-02-10  1.1  Bug fixing                                          */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_843ExtPrint01] (  
   @nMobile       INT,
   @nFunc         INT,
   @nStep         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10),
   @nCartonNo     INT, 
   @cLabelNo      NVARCHAR( 20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT 
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE 
   @cCNAShipLbl      NVARCHAR( 10),
   @cPackList1       NVARCHAR( 10),
   @cPackList2       NVARCHAR( 10),
   @cPrinterInGroup  NVARCHAR( 10),
   @cPrinterName     NVARCHAR(100),
   @cLabelPrinter    NVARCHAR(10),    
   @cPaperPrinter    NVARCHAR(10)  
  
   SET @cPackList1 = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)    
   IF @cPackList1 = '0'    
      SET @cPackList1 = ''  
      
   SET @cPackList2 = rdt.RDTGetConfig( @nFunc, 'PackList2', @cStorerKey)    
   IF @cPackList2 = '0'    
      SET @cPackList2 = ''   
      
   SET @cCNAShipLbl = rdt.RDTGetConfig( @nFunc, 'CNASHIPLBL', @cStorerKey)    
   IF @cCNAShipLbl = '0'    
      SET @cCNAShipLbl = ''   
      
   SELECT @cLabelPrinter = Printer  
         ,@cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobrec WITH (NOLOCK)  
   WHERE Mobile = @nMobile

   IF @cPackList1 <> '' 
   BEGIN
   	-- Make sure we have setup the printer id
      -- Record searched based on func + storer + reporttype + printergroup (shipperkey)
      SELECT @cPrinterInGroup = PrinterID
      FROM rdt.rdtReportToPrinter WITH (NOLOCK)
      WHERE Function_ID = @nFunc
      AND   StorerKey = @cStorerKey
      AND   ReportType = @cPackList1
      
      SELECT @cPrinterName = WinPrinter  
      FROM rdt.rdtPrinter WITH (NOLOCK)  
      WHERE PrinterID = CASE WHEN ISNULL( @cPrinterInGroup, '') <> '' THEN @cPrinterInGroup ELSE @cPaperPrinter END
      
      -- Common params
      DECLARE @tPackList AS VariableTable    
      INSERT INTO @tPackList (Variable, Value) VALUES        
         ( '@cPickSlipNo',    @cPickSlipNo)  

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '', 
         @tPackList, -- Report type
         @cPackList1, -- Report params
         'rdt_843ExtPrint01', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
         
       IF @nErrNo <> 0    
            GOTO Quit 
   	
   END
   
   IF @cPackList2 <> '' 
   BEGIN
   	-- Make sure we have setup the printer id
      -- Record searched based on func + storer + reporttype + printergroup (shipperkey)
      SELECT @cPrinterInGroup = PrinterID
      FROM rdt.rdtReportToPrinter WITH (NOLOCK)
      WHERE Function_ID = @nFunc
      AND   StorerKey = @cStorerKey
      AND   ReportType = @cPackList2
      
      SELECT @cPrinterName = WinPrinter  
      FROM rdt.rdtPrinter WITH (NOLOCK)  
      WHERE PrinterID = CASE WHEN ISNULL( @cPrinterInGroup, '') <> '' THEN @cPrinterInGroup ELSE @cPaperPrinter END
      
      -- Common params
      DECLARE @tPackList2 AS VariableTable    
      INSERT INTO @tPackList (Variable, Value) VALUES        
         ( '@cPickSlipNo',    @cPickSlipNo)  

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '', 
         @tPackList2, -- Report type
         @cPackList2, -- Report params
         'rdt_843ExtPrint01', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
         
       IF @nErrNo <> 0    
            GOTO Quit 
   	
   END
   
   IF @cCNAShipLbl <> '' 
   BEGIN
   	-- Make sure we have setup the printer id
      -- Record searched based on func + storer + reporttype + printergroup (shipperkey)
      SELECT @cPrinterInGroup = PrinterID
      FROM rdt.rdtReportToPrinter WITH (NOLOCK)
      WHERE Function_ID = @nFunc
      AND   StorerKey = @cStorerKey
      AND   ReportType = @cCNAShipLbl
      
      SELECT @cPrinterName = WinPrinter  
      FROM rdt.rdtPrinter WITH (NOLOCK)  
      WHERE PrinterID = CASE WHEN ISNULL( @cPrinterInGroup, '') <> '' THEN @cPrinterInGroup ELSE @cPaperPrinter END
      
      -- Common params
      DECLARE @tCNAShipLbl AS VariableTable    
      INSERT INTO @tCNAShipLbl (Variable, Value) VALUES     
            ( '@cStorerKey',     @cStorerKey),     
            ( '@cPickSlipNo',    @cPickSlipNo),     
            ( '@cLabelNo',       @cLabelNo),     
            ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))  

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '', 
         @tCNAShipLbl, -- Report type
         @cCNAShipLbl, -- Report params
         'rdt_843ExtPrint01', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
         
       IF @nErrNo <> 0    
            GOTO Quit 
   	
   END
           
Quit: 
        
      
END  


GO
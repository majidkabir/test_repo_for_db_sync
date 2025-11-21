SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Store procedure: rdt_593UCCLabel05                                      */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2018-01-29 1.0  Ung      WMS-3857 Created                               */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593UCCLabel05] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- UCCNo
   @cParam2    NVARCHAR(20),  
   @cParam3    NVARCHAR(20),    
   @cParam4    NVARCHAR(20),  
   @cParam5    NVARCHAR(20),  
   @nErrNo     INT OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
  
   DECLARE @cLabelPrinter NVARCHAR( 10)  
   DECLARE @cPaperPrinter NVARCHAR( 10)  
   DECLARE @cFacility     NVARCHAR( 5)
   DECLARE @cUCCNo        NVARCHAR( 20)  
   DECLARE @cStatus       NVARCHAR( 1)
   DECLARE @cSKU          NVARCHAR( 20)
   DECLARE @cUCCLabel     NVARCHAR( 10)
   DECLARE @nRowCount     INT
   
   SET @cUCCNo = @cParam1

   -- Check blank
   IF @cUCCNo = ''
   BEGIN
      SET @nErrNo = 119151  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need UCC
      GOTO Quit  
   END

   -- Get login info
   SELECT 
      @cFacility = Facility, 
      @cLabelPrinter = Printer,   
      @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   -- Get ID info
   SELECT @cStatus = Status
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cUCCNo

   SET @nRowCount = @@ROWCOUNT

   -- Check valid ID
   IF @nRowCount = 0
   BEGIN  
      SET @nErrNo = 119152  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC  
      GOTO Quit  
   END  

   -- Multi SKU
   IF @nRowCount > 1
   BEGIN  
      SET @nErrNo = 119153  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Multi SKU UCC  
      GOTO Quit  
   END  

       
   /*-------------------------------------------------------------------------------  
  
                                    Print UCC Label  
  
   -------------------------------------------------------------------------------*/  
   -- Get storer config
   SET @cUCCLabel = rdt.RDTGetConfig( @nFunc, 'UCCLabel', @cStorerKey)
   IF @cUCCLabel = '0'
      SET @cUCCLabel = ''

   -- Check report setup
   IF @cUCCLabel = ''
   BEGIN  
      SET @nErrNo = 119154  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --RPTypeNotSetup
      GOTO Quit  
   END 
   
   -- Common params
   DECLARE @tUCCLabel VariableTable
   INSERT INTO @tUCCLabel (Variable, Value) VALUES 
      ( '@cStorerKey',  @cStorerKey),
      ( '@cUCCNo',      @cUCCNo)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
      @cUCCLabel, -- Report type
      @tUCCLabel, -- Report params
      'rdt_593UCCLabel05', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT

   IF @nErrNo <> 0
      GOTO Quit

Quit:  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtSKULblReprn04                                       */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2014-06-05 1.0  James    SOS304122 Created                              */ 
/* 2014-11-07 1.1  James    Remove traceinfo                               */ 
/* 2014-12-02 1.2  James    SOS326144 - Add currency filter (james01)      */ 
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtSKULblReprn04] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- SKU  
   @cParam2    NVARCHAR(20),  -- # Of Copies
   @cParam3    NVARCHAR(20),  -- Currency
   @cParam4    NVARCHAR(20),  
   @cParam5    NVARCHAR(20),  
   @nErrNo     INT OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @b_Success     INT  
     
   DECLARE @cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cLabelPrinter NVARCHAR( 10)  
          ,@cSKU          NVARCHAR( 20) 
          ,@cNoOfCopy     NVARCHAR( 20) 
          ,@cCurrency     NVARCHAR( 10)  

   SET @cStorerKey = ''
   SET @cSKU = ''
   SET @cNoOfCopy  = ''
   SET @cCurrency = ''

   SELECT @cStorerKey = StorerKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @cSKU = @cParam1
   SET @cNoOfCopy = @cParam2
   SET @cCurrency = @cParam3

   -- To ToteNo value must not blank
   IF ISNULL(@cStorerKey, '') = '' AND ISNULL( @cSKU, '') = '' AND ISNULL( @cNoOfCopy, '') = '' AND ISNULL( @cCurrency, '') = ''
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'VALUE REQ'
      GOTO Quit  
   END

   IF ISNULL(@cStorerKey, '') = '' 
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'STORERKEY REQ'
      GOTO Quit  
   END

   IF ISNULL(@cSKU, '') = '' 
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'SKU REQ'
      GOTO Quit  
   END

   IF ISNULL(@cNoOfCopy, '') = '' 
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'NO OF COPY REQ'
      GOTO Quit  
   END

   -- (james02)
   IF ISNULL(@cCurrency, '') = '' 
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'Currency REQ'
      GOTO Quit  
   END

   IF NOT EXISTS ( SELECT 1 FROM ConsigneeSKU WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey
                   AND   SKU = @cSKU
                   AND   UDF02 = @cCurrency)
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'Invalid SKU/Currency'
      GOTO Quit  
   END

   -- Get printer info  
   SELECT @cLabelPrinter = Printer 
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   IF ISNULL( @cLabelPrinter, '') = ''
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'Label Prnter Req'
      GOTO Quit  
   END

   -- Get report info  
   SET @cDataWindow = ''  
   SET @cTargetDB = ''  
   SELECT   
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
      AND ReportType = 'SKULABEL5'  

   -- Insert print job  
   SET @nErrNo = 0                    
   EXEC RDT.rdt_BuiltPrintJob                     
      @nMobile,                    
      @cStorerKey,                    
      'SKULABEL5',                    
      'PRINT_SKULABEL',                    
      @cDataWindow,                    
      @cLabelPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @cStorerKey, 
      @cSKU, 
      @cNoOfCopy, 
      '', 
      @cCurrency 

   IF @nErrNo <> 0
      GOTO Quit  

   


Quit:  

GO
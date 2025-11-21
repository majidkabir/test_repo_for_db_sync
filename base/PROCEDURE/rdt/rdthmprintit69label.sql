SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtHMPrintIT69Label                                    */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2014-03-14 1.0  James    SOS301441 Created                              */  
/* 2016-03-09 1.1  James    Change printing to rdt_BuiltPrintJob (james01) */  
/* 2017-02-27 1.2  James    Bug fix on qty input (james02)                 */  
/* 2018-07-26 1.3  Ung      WMS-5843 Change ReceiptLineNumber to optional  */
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtHMPrintIT69Label] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- ReceiptKey  
   @cParam2    NVARCHAR(20),  -- ReceiptLine  
   @cParam3    NVARCHAR(20),  -- Qty  
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
     
   DECLARE @cDataWindow             NVARCHAR( 50)  
          ,@cTargetDB               NVARCHAR( 20)  
          ,@cLabelPrinter           NVARCHAR( 10)  
          ,@cPaperPrinter           NVARCHAR( 10)  
          ,@cReceiptKey             NVARCHAR( 10)  
          ,@cReceiptLineNumber      NVARCHAR( 5)  
          ,@cQty                    NVARCHAR( 5)  
          ,@cPrintTemplateSP        NVARCHAR( 40) 
          ,@cSKU                    NVARCHAR( 20) 
          ,@cActSKU                 NVARCHAR( 20) 
          ,@cCOO                    NVARCHAR( 20) 
          ,@cLOTNo                  NVARCHAR( 20) 
          ,@nSKUCnt                 INT
          ,@n_Err                   INT
          ,@c_ErrMsg                NVARCHAR( 20)  
          ,@cUserName               NVARCHAR( 18) 

   IF @cOption = '1'
   BEGIN
      -- Parameter mapping  
      SET @cReceiptKey = @cParam1  
      SET @cReceiptLineNumber = ISNULL( @cParam2, '')
      SET @cQty = @cParam3

      -- Check if it is blank
      IF ISNULL(@cReceiptKey, '') = '' 
      BEGIN
         SET @nErrNo = 85851  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ASN REQ
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
         GOTO Quit  
      END

      -- Check if it is valid ASN
      IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) 
                      WHERE ReceiptKey = @cReceiptKey 
                      AND   StorerKey = @cStorerKey)
                      -- AND   '0' IN ([Status], ASNStatus))   -- not check status of ASN
       BEGIN  
         SET @nErrNo = 85852  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INVALID ASN  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
         GOTO Quit  
      END  
/*
      IF ISNULL( @cReceiptLineNumber, '') = ''
      BEGIN
         SET @nErrNo = 85853  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ASN LINE REQ
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param2  
         GOTO Quit  
      END
*/      
      -- Check if ASN line exists
      IF @cReceiptLineNumber <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                         WHERE ReceiptKey = @cReceiptKey
                         AND   ReceiptLineNumber = @cReceiptLineNumber
                         AND   StorerKey = @cStorerKey)
         BEGIN  
            SET @nErrNo = 85854  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ASN LINE  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param2  
            GOTO Quit  
         END
      END

      -- Check if Qty is blank
      IF ISNULL( @cQTY, '') = ''
      BEGIN
         SET @nErrNo = 85855  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --QTY REQ
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param3  
         GOTO Quit  
      END

      -- Check for valid Qty
      IF rdt.rdtIsValidQty(@cQty, 1) = 0
      BEGIN
         SET @nErrNo = 85856  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --QTY REQ
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param3  
         GOTO Quit  
      END

      IF CAST( @cQty AS INT) > '999'
      BEGIN
         SET @nErrNo = 85857  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --QTY > MAXQTY
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param3  
         GOTO Quit  
      END
   END
   ELSE
   BEGIN
      -- Parameter mapping  
      SET @cSKU = @cParam1  
      SET @cCOO = @cParam2  
      SET @cLOTNo = @cParam3
      SET @cQty = @cParam4

      IF ISNULL( @cSKU, '') = ''
      BEGIN
         SET @nErrNo = 85858  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SKU REQ
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
         GOTO Quit  
      END

      IF ISNULL( @cCOO, '') = ''
      BEGIN
         SET @nErrNo = 85859  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --COO REQ
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param2  
         GOTO Quit  
      END

      IF ISNULL( @cLOTNo, '') = ''
      BEGIN
         SET @nErrNo = 85860  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LOT NO REQ
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param3  
         GOTO Quit  
      END

      IF ISNULL( @cQty, '') = ''
      BEGIN
         SET @nErrNo = 85861  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --QTY REQ
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- Param4  
         GOTO Quit  
      END

      -- Check for valid Qty (james02)
      IF rdt.rdtIsValidQty(@cQty, 1) = 0
      BEGIN
         SET @nErrNo = 85868  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- Param4  
         GOTO Quit  
      END

      SET @cActSKU = SUBSTRING( @cSKU, 3, 13)

      EXEC [RDT].[rdt_GETSKUCNT]
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cSKU,
         @nSKUCnt     = @nSKUCnt       OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 85862
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
         GOTO Quit  
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 85863
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
         GOTO Quit  
      END

      EXEC [RDT].[rdt_GETSKU]
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cActSKU       OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      IF CAST( @cQty AS INT) > '999'
      BEGIN
         SET @nErrNo = 85864  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --QTY > MAXQTY
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- Param4  
         GOTO Quit  
      END
   END
   
   -- Get printer info  
   SELECT   
      @cUserName = UserName, 
      @cLabelPrinter = Printer,   
      @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   /*-------------------------------------------------------------------------------  
  
                                    Print SKU Label  
  
   -------------------------------------------------------------------------------*/  
  
   -- Check label printer blank  
   IF @cLabelPrinter = ''  
   BEGIN  
      SET @nErrNo = 85864  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
      GOTO Quit  
   END  

   SELECT   
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
      AND ReportType = 'IT69LABEL'  

   IF ISNULL(@cOption, '') = '1'
   BEGIN
      -- Insert print job  (james01)
      SET @nErrNo = 0                    
      EXEC RDT.rdt_BuiltPrintJob                     
         @nMobile,                    
         @cStorerKey,                    
         'IT69LABEL',                    
         'PRINT_IT69LABEL',                    
         @cDataWindow,                    
         @cLabelPrinter,                    
         @cTargetDB,                    
         @cLangCode,                    
         @nErrNo  OUTPUT,                     
         @cErrMsg OUTPUT,                    
         @cReceiptKey,
         @cReceiptLineNumber,
         '',
         @cQty,
         @cOption
   END
   ELSE
   BEGIN
      -- Insert print job  (james01)
      SET @nErrNo = 0                    
      EXEC RDT.rdt_BuiltPrintJob                     
         @nMobile,                    
         @cStorerKey,                    
         'IT69LABEL',                    
         'PRINT_IT69LABEL',                    
         @cDataWindow,                    
         @cLabelPrinter,                    
         @cTargetDB,                    
         @cLangCode,                    
         @nErrNo  OUTPUT,                     
         @cErrMsg OUTPUT,                    
         @cSKU,
         @cCOO,
         @cLOTNo,
         @cQty,
         @cOption   
   END
   
Quit:  

GO
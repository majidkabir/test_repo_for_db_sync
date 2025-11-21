SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdtCarterLabel01                                       */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2015-06-09 1.0  ChewKP   SOS#343945 Created                             */   
/* 2016-04-12 1.1  ChewKP   SOS#337277 Add Option 3 (ChewKP01)             */
/* 2018-02-08 1.2  James    WMS6249-Check status of SKU (james01)          */
/***************************************************************************/    
    
CREATE PROC [RDT].[rdtCarterLabel01] (    
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
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
    
   DECLARE @b_Success     INT    
       
  
   DECLARE @cLabelPrinter NVARCHAR( 10)    
   DECLARE @cPaperPrinter NVARCHAR( 10)    
 
   DECLARE @cLabelType    NVARCHAR( 20)    
   DECLARE @cUserName     NVARCHAR( 18)     
   
   DECLARE @cLabelNo      NVARCHAR(20)  
         , @cPrintCartonLabel NVARCHAR(1) 
         , @cReceiptKey   NVARCHAR(10)
         , @cReceiptLineNumber NVARCHAR(5)
         , @nNoOfCopy     INT
         , @cSKU          NVARCHAR(20)
         , @nSKUCnt       INT
         , @cPrintTemplate NVARCHAR( MAX)
         , @cTargetDB      NVARCHAR( 20)    
         , @cNotes         NVARCHAR( 1)

   DECLARE @cSKUStatus     NVARCHAR(10) -- (james01) 

   SELECT @cNotes = Notes FROM dbo.codelkup WITH (NOLOCK) 
   WHERE ListName = 'RDTLBLRPT' 
   AND   StorerKey = @cStorerKey
   AND   Code = @cOption

   IF ISNULL( @cNotes, '') IN ('1', '2', '3')
   BEGIN
      SET @cOption = @cNotes
   END

   IF @cOption = '1'
   BEGIN  
      SET @cReceiptKey = @cParam1   
      SET @cReceiptLineNumber = @cParam3
      SET @nNoOfCopy = @cParam5 
   END
   ELSE IF @cOption = '2'
   BEGIN
      SET @cSKU = @cParam1   
      SET @nNoOfCopy = @cParam3
   END
   ELSE IF @cOption = '3'
   BEGIN
      SET @cLabelNo = @cParam1   
   END

   
   -- Get printer info    
   SELECT     
      @cUserName = UserName,   
      @cLabelPrinter = Printer,     
      @cPaperPrinter = Printer_Paper    
   FROM rdt.rdtMobRec WITH (NOLOCK)    
   WHERE Mobile = @nMobile    
     
       
   /*-------------------------------------------------------------------------------    
    
                                    Print Label    
    
   -------------------------------------------------------------------------------*/    

  
   
   IF @cOption = '1'
   BEGIN
          
      -- Check label printer blank    
      IF @cLabelPrinter = ''    
      BEGIN    
         SET @nErrNo = 93751    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
         GOTO Quit    
      END    
      
      -- Check blank    
      IF ISNULL( @cReceiptKey, '') = ''    
      BEGIN    
         SET @nErrNo = 93752    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ReceiptKeyReq
         GOTO Quit    
      END    
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK)
                      WHERE ReceiptKey = @cReceiptKey ) 
      BEGIN
         SET @nErrNo = 93753    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidReceiptKey
         GOTO Quit  
      END
      
      IF ISNULL( @cReceiptLineNumber, '') = ''    
      BEGIN
         SET @nErrNo = 93754    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LineNoReq
         GOTO Quit    
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Receiptdetail WITH (NOLOCK)
                      WHERE ReceiptKey = @cReceiptKey 
                      AND ReceiptLineNumber = @cReceiptLineNumber ) 
      BEGIN
         SET @nErrNo = 93755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLineNo
         GOTO Quit  
      END
      
      IF @nNoOfCopy <> ''
      BEGIN
          -- Validate QTY
         IF rdt.rdtIsValidQty( @nNoOfCopy, 21) = 0
         BEGIN
            SET @nErrNo = 93756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidQty
            GOTO Quit  
         END
      END
      ELSE
      BEGIN
         SET @nNoOfCopy = 1
      END
      
      SET @cSKU = '' 
      
      SELECT @cSKU = SKU FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber = @cReceiptLineNumber
      
      
      SET @cLabelType = 'UPCLABEL'     
      EXEC dbo.isp_BT_GenBartenderCommand       
         @cLabelPrinter                             
       , @cLabelType                             
       , @cUserName                              
       , @cStorerKey                               
       , @cSKU
       , @nNoOfCopy
       , ''                     
       , ''  
       , ''                                 
       , ''                                      
       , ''                                      
       , ''   
       , ''    
       , @cStorerKey  
       , '1'  
       , '0'  
       , 'N'                                       
       , @nErrNo  OUTPUT                         
       , @cERRMSG OUTPUT    
   
     
      IF @nErrNo <> 0                      
         GOTO Quit      
      
      
   END
   ELSE IF @cOption = '2'
   BEGIN
          
      -- Check label printer blank    
      IF @cLabelPrinter = ''    
      BEGIN    
         SET @nErrNo = 93751    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
         GOTO Quit    
      END    

      -- (james01)
      SET @cSKUStatus  = ''
      SET @cSKUStatus = rdt.RDTGetConfig( @nFunc, 'SKUStatus', @cStorerkey)  
      IF @cSKUStatus = '0'
   	   SET @cSKUStatus = ''
      
      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT
         ,@cSKUStatus  = @cSKUStatus

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 93757
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidSKU
         GOTO Quit  
      END
      
      -- Validate barcode return multiple SKU
--      IF @nSKUCnt > 1
--      BEGIN
--         SET @nErrNo = 93758
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --MultiBarCodeSKU
--         GOTO Quit  
--      END
      
      --IF @nSKUCnt = 1
         --SET @cSKU = @cSKUCode
      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT
         ,@cSKUStatus  = @cSKUStatus



      IF @nNoOfCopy <> ''
      BEGIN
         IF rdt.rdtIsValidQty( @nNoOfCopy, 21) = 0
         BEGIN
            SET @nErrNo = 93759
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidQty
            GOTO Quit  
         END
      END
      ELSE
      BEGIN
         SET @nNoOfCopy = 1
      END
      
      

      SET @cLabelType = 'UPCLABEL'     
      EXEC dbo.isp_BT_GenBartenderCommand       
         @cLabelPrinter                             
       , @cLabelType                             
       , @cUserName                              
       , @cStorerKey                               
       , @cSKU
       , @nNoOfCopy
       , ''                     
       , ''  
       , ''                                 
       , ''                                      
       , ''                                      
       , ''   
       , ''    
       , @cStorerKey  
       , '1'  
       , '0'  
       , 'N'                                       
       , @nErrNo  OUTPUT                         
       , @cERRMSG OUTPUT    
   
     
      IF @nErrNo <> 0                      
         GOTO Quit      
      
   END
   ELSE IF @cOption = '3'
   BEGIN
      
          

      IF @cLabelNo = ''
      BEGIN
            SET @nErrNo = 93760
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq
            GOTO Quit  
      END
      
      
      IF NOT EXISTS (SELECT 1 FROM dbo.CartonTrack WITH (NOLOCK)
                     WHERE LabelNo = @cLabelNo) 
      BEGIN
            SET @nErrNo = 93761
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNotExist
            GOTO Quit  
      END
      
--      SELECT @cPrintTemplete = PrintData 
--      FROM dbo.CartonTrack WITH (NOLOCK)
--      WHERE LabelNo = @cLabelNo
      SELECT @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'UPSLABEL'  

      EXEC RDT.rdt_BuiltPrintJob  
               @nMobile,  
               @cStorerKey,  
               'UPSLABEL',       -- ReportType  
               'UPSLABEL',       -- PrintJobName  
               '',  
               @cLabelPrinter,  
               @cTargetDB,  
               @cLangCode,  
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT,  
               @cLabelNo
               
      IF @nErrNo <> 0                      
         GOTO Quit      
      
                     
   END
   
  
  
Quit:    

GO
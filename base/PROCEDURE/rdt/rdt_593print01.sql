SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdt_593Print01                                         */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2015-03-16 1.0  ChewKP   SOS#334977 Created                             */  
/* 2015-11-24 1.1  ChewKP   SOS#357394 - Additional RePrint Option (CheWKP01)*/ 
/***************************************************************************/    
    
CREATE PROC [RDT].[rdt_593Print01] (    
   @nMobile    INT,    
   @nFunc      INT,    
   @nStep      INT,    
   @cLangCode  NVARCHAR( 3),    
   @cStorerKey NVARCHAR( 15),    
   @cOption    NVARCHAR( 1),    
   @cParam1    NVARCHAR(20),  -- PickSlipNo    
   @cParam2    NVARCHAR(20),  
   @cParam3    NVARCHAR(20),  -- Total Carton    
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
   DECLARE @cTargetDB     NVARCHAR( 20)    
   DECLARE @cLabelPrinter NVARCHAR( 10)    
   DECLARE @cPaperPrinter NVARCHAR( 10)    
   DECLARE @cUserName     NVARCHAR( 18)     
   DECLARE @cLabelType    NVARCHAR( 20)    
         , @cPickSlipNo     NVARCHAR(10)  
         , @cOrderKey       NVARCHAR(10)   
         , @nTotalCartonNo  INT
         , @cReceiptKey   NVARCHAR(10)
         , @cToID         NVARCHAR(18)


   
   SELECT @cLabelPrinter = Printer
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank    
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''    
   BEGIN    
      SET @nErrNo = 93155    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
      GOTO Quit    
   END    

   
   IF @cOption = '1' 
   BEGIN 
         
      SET @cPickSlipNo = @cParam1
      SET @nTotalCartonNo = @cParam2
   
      
      -- Check blank    
      IF ISNULL(RTRIM(@cPickSlipNo), '') = ''    
      BEGIN    
         SET @nErrNo = 93151    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PickSlipNoReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit    
      END    
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK)
                      WHERE PickHeaderKey = @cPickSlipNo ) 
      BEGIN    
         SET @nErrNo = 93152    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidPickSlipNo  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO Quit    
      END    
      
      IF @nTotalCartonNo = ''
      BEGIN
         SET @nErrNo = 93153    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --TTLCtnNoReq  
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param1   
         GOTO Quit    
      END
      
      IF rdt.rdtIsValidQty( @nTotalCartonNo, 1) = 0
      BEGIN
         SET @nErrNo = 93154    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidCtnNo  
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param1   
         GOTO Quit   
      END
     
      --SET @cLabelType = 'SHIPPLABELDTC'  
        
      SELECT @cOrderKey = OrderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo
      
      
      UPDATE dbo.Orders WITH (ROWLOCK)
         SET ContainerQty = @nTotalCartonNo
            ,Trafficcop = NULL
      WHERE OrderKey = @cOrderKey
      AND StorerKey = @cStorerKey 
      
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 93156 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdOrderFail    
         GOTO Quit    
      END
      
      UPDATE dbo.PickingInfo WITH (ROWLOCK) 
      SET ScanOutDate = GetDate()
      WHERE PickSlipNo = @cPickSlipNo
    
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 93157 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickingInfoFail    
         GOTO Quit    
      END
      
              
      SET @cLabelType = 'CARRIERLABEL'   
      
      
   
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      
      SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'CarrierLBL'    
      
      
      EXEC RDT.rdt_BuiltPrintJob      
          @nMobile,      
          @cStorerKey,      
          'CarrierLBL',    -- ReportType      
          'CarrierLBL',    -- PrintJobName      
          @cDataWindow,      
          @cLabelPrinter,      
          @cTargetDB,      
          @cLangCode,      
          @nErrNo  OUTPUT,      
          @cErrMsg OUTPUT,       
          @cPickSlipNo    
   
      
   END
   
   --(CheWKP01)
   IF @cOption = '2'
   BEGIN
      -- mapping      
      SET @cReceiptKey       = @cParam1     
      SET @cToID             = @cParam3  
      
      IF ISNULL( @cReceiptKey, '') = ''  
      BEGIN      
         SET @nErrNo = 93158      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ReceiptKey  
         GOTO Quit      
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND ReceiptKey = @cReceiptKey ) 
      BEGIN
         SET @nErrNo = 93159
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidReceiptKey  
         GOTO Quit     
      END   
      
      IF ISNULL(@cToID ,'' ) = ''
      BEGIN
         SET @nErrNo = 93163
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ToIDReq  
         GOTO Quit    
      END
      
      SET @cDataWindow = ''
      SET @cTargetDB = ''
      
      SELECT  
         @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
         @cTargetDB = ISNULL(RTRIM(TargetDB), '')  
      FROM RDT.RDTReport WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND ReportType ='IDLABEL'  
  
      -- Check data window  
      IF ISNULL(@cDataWindow, '') = ''  
      BEGIN  
         SET @nErrNo = 93161  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
         GOTO Quit  
      END  
  
      -- Check database  
      IF ISNULL(@cTargetDB, '') = ''  
      BEGIN  
         SET @nErrNo = 93162  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set  
         GOTO Quit  
      END  
      
      EXEC RDT.rdt_BuiltPrintJob  
             @nMobile  
            ,@cStorerKey  
            ,'IDLABEL'          -- ReportType   
            ,'PRINT_IDLABEL'  -- PrintJobName  
            ,@cDataWindow  
            ,@cLabelPrinter  
            ,@cTargetDB  
            ,@cLangCode  
            ,@nErrNo  OUTPUT  
            ,@cErrMsg OUTPUT  
            ,@cReceiptKey  
            ,@cToID  
     
      
      
   END
   
   IF @cOption = '3'
   BEGIN
      -- mapping      
      SET @cReceiptKey       = @cParam1     
      
      
      IF ISNULL( @cReceiptKey, '') = ''  
      BEGIN      
         SET @nErrNo = 93164      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ReceiptKey  
         GOTO Quit      
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND ReceiptKey = @cReceiptKey ) 
      BEGIN
         SET @nErrNo = 93165
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidReceiptKey  
         GOTO Quit     
      END   
      
      EXEC RDT.rdt_BuiltPrintJob  
                  @nMobile,  
                  @cStorerKey,  
                  'CASELABEL',       -- ReportType  
                  'PRINT_CASELABEL', -- PrintJobName  
                  @cDataWindow,  
                  @cLabelPrinter,  
                  @cTargetDB,  
                  @cLangCode,  
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT,  
                  @cReceiptKey  
   END

 
  
Quit:    

GO
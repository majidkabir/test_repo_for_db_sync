SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Store procedure: rdtUAPrintILotteLbl                                    */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2017-07-22 1.0  James    Created                                        */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtUAPrintILotteLbl] (  
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
   SET CONCAT_NULL_YIELDS_NULL OFF
  
   DECLARE @b_Success     INT  
     
   DECLARE @cDataWindow             NVARCHAR( 50)  
          ,@cTargetDB               NVARCHAR( 20)  
          ,@cLabelPrinter           NVARCHAR( 10)  
          ,@cPaperPrinter           NVARCHAR( 10)  
          ,@cDropId                 NVARCHAR( 20)  
          ,@cReceiptLineNumber      NVARCHAR( 5)  
          ,@cQty                    NVARCHAR( 5)  
          ,@cPrintTemplateSP        NVARCHAR( 40) 
          ,@cPickSlipNo             NVARCHAR( 20) 
          ,@cUserDefine03           NVARCHAR( 20) 
          ,@cCOO                    NVARCHAR( 20) 
          ,@cOrderKey               NVARCHAR( 10) 
          ,@nSKUCnt                 INT
          ,@n_Err                   INT
          ,@c_ErrMsg                NVARCHAR( 20)  
          ,@cUserName               NVARCHAR( 18) 


   -- Parameter mapping  
   SET @cDropId = @cParam1  

   -- Check if it is blank
   IF ISNULL(@cDropId, '') = '' 
   BEGIN
      SET @nErrNo = 112751  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Drop ID Req
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
      GOTO Quit  
   END

   SET @cPickSlipNo = ''
   
   SELECT TOP 1 @cPickSlipNo = p.PickSlipNo
   FROM  PACKDETAIL AS p WITH(NOLOCK) 
   WHERE DropID = @cDropId 
   AND   StorerKey = @cStorerKey
      
   -- Check if it is valid ASN
   IF @cPickSlipNo = ''
   BEGIN  
      SET @nErrNo = 112752  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Inv Drop ID  
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
      GOTO Quit  
   END  
   
      
   SET @cUserDefine03 = ''
   SELECT @cUserDefine03 = o.UserDefine03
   FROM PackHeader AS ph WITH(NOLOCK)
   JOIN ORDERS AS o WITH(NOLOCK) ON o.OrderKey = ph.OrderKey
   WHERE ph.PickSlipNo = @cPickSlipNo 

   -- Check if Qty is blank
   IF ISNULL( RTRIM(@cUserDefine03), '') <> 'NC'
      GOTO Quit  
   
   -- Get printer info  
   SELECT   
      @cUserName = UserName, 
      @cLabelPrinter = Printer,   
      @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   /*-------------------------------------------------------------------------------  
  
                                    Print LOTTE Label  
  
   -------------------------------------------------------------------------------*/  
  
   -- Check label printer blank  
   IF @cLabelPrinter = ''  
   BEGIN  
      SET @nErrNo = 112753  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
      GOTO Quit  
   END  

  -- Get CTNMNFLBL list report info
   SET @cDataWindow = ''
   SET @cTargetDB = ''
   SELECT 
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   ReportType = 'UALOTTELBL'
   AND   ( Function_ID = @nFunc OR Function_ID = 0)

   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 112754
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END
   
   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 112755
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END

   EXEC RDT.rdt_BuiltPrintJob
      @nMobile,
      @cStorerKey,
      'UALOTTELBL',       -- ReportType
      'rdtUAPrintILotteLbl', -- PrintJobName
      @cDataWindow,
      @cLabelPrinter,
      @cTargetDB,
      @cLangCode,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT, 
      @cDropId
Quit:  


GO
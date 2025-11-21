SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtIDXShipLabelReprn                                   */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2014-05-14 1.0  James    SOS309850 Created                              */  
/* 2014-05-26 2.0  CSCHONG  To add in parameter04 passing (CS01)           */   
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtIDXShipLabelReprn] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- OrderKey  
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
     
   DECLARE @cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cLabelPrinter NVARCHAR( 10)  
          ,@cPaperPrinter NVARCHAR( 10)  
          ,@cOrderKey     NVARCHAR( 10)  
          ,@cLoadKey      NVARCHAR( 10)  
          ,@cShipperKey   NVARCHAR( 15) 
          ,@cStatus       NVARCHAR( 10)  
          ,@PickDetQty    NVARCHAR( 5)     
   

   SET @cOrderKey = @cParam1
   SET @PickDetQty = '0'          --(CS01)

   -- Both value must not blank
   IF ISNULL(@cOrderKey, '') = '' 
   BEGIN
      SET @nErrNo = 88301  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQ
      GOTO Quit  
   END

   -- Check if it is valid OrderKey
   IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                   WHERE OrderKey = @cOrderKey 
                   AND   StorerKey = @cStorerKey)
    BEGIN  
      SET @nErrNo = 88302  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ORDERS  
      GOTO Quit  
   END  

   SELECT @cStatus = [Status], 
          @cLoadKey = LoadKey, 
          @cShipperKey = ShipperKey 
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   IF ISNULL( @cStatus, '') = '0'
    BEGIN  
      SET @nErrNo = 88303  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORD NOT ALLOC
      GOTO Quit  
   END  
/*
   IF ISNULL( @cStatus, '') = '9'
    BEGIN  
      SET @nErrNo = 88304  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORD SHIPPED
      GOTO Quit  
   END  
*/
   IF ISNULL( @cLoadKey, '') = ''
    BEGIN  
      SET @nErrNo = 88305  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO LOADKEY
      GOTO Quit  
   END  

   IF ISNULL( @cShipperKey, '') = ''
    BEGIN  
      SET @nErrNo = 88306  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO SHIPPER
      GOTO Quit  
   END  

   -- Get printer info  
   SELECT   
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
      SET @nErrNo = 88307  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
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
      AND ReportType = 'SHIPPLABEL'  
        
   -- Insert print job  (james15)
   SET @nErrNo = 0                    
   EXEC RDT.rdt_BuiltPrintJob                     
      @nMobile,                    
      @cStorerKey,                    
      'SHIPPLABEL',                    
      'PRINT_SHIPLABEL',                    
      @cDataWindow,                    
      @cLabelPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @cLoadKey,                    
      @cOrderKey, 
      @cShipperKey, 
      @PickDetQty         --(CS01)   

   IF @nErrNo <> 0
   BEGIN  
      SET @nErrNo = 88308  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reprint Fail  
      GOTO Quit  
   END  

Quit:  

GO
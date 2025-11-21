SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtIDXRtnTicketReprn                                   */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */
/* Purpose: Reprint Iditex A5 return ticket                                */
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2014-12-29 1.0  James    SOS329112 Created                              */  
/* 2018-03-07 1.1  Ung      Convert to RDT message                         */
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtIDXRtnTicketReprn] (  
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

   -- Both value must not blank
   IF ISNULL(@cOrderKey, '') = '' 
   BEGIN
      SET @nErrNo = 120701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --VALUE REQ
      GOTO Quit  
   END

   -- Check if it is valid OrderKey
   IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                   WHERE OrderKey = @cOrderKey 
                   AND   StorerKey = @cStorerKey)
    BEGIN  
      SET @nErrNo = 120702
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID ORDERS
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
      SET @nErrNo = 120703
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORDER NOTALLOC
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
   IF @cPaperPrinter = ''  
   BEGIN  
      SET @nErrNo = 120704
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PAPERPRNTERREQ
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
      AND ReportType = 'RTNTICKET'  
        
   -- Insert print job  (james15)
   SET @nErrNo = 0                    
   EXEC RDT.rdt_BuiltPrintJob                     
      @nMobile,                    
      @cStorerKey,                    
      'RTNTICKET',                    
      'PRINT_RTNTICKET',                    
      @cDataWindow,                    
      @cPaperPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @cStorerKey,
      @cOrderKey

   IF @nErrNo <> 0
   BEGIN  
      SET @nErrNo = 120705
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --REPRINT FAIL
      GOTO Quit  
   END  

Quit:  

GO
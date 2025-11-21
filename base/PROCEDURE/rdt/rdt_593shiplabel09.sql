SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Store procedure: rdt_593ShipLabel09                                     */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2017-08-22 1.0  James    WMS2052.Created                                */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593ShipLabel09] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- OrderKey  
   @cParam2    NVARCHAR(20),  -- Carton no
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
          ,@cCartonNo     NVARCHAR( 5)     
   

   SET @cOrderKey = @cParam1
   SET @cCartonNo = ISNULL( @cParam2, '')

   -- Both value must not blank
   IF ISNULL(@cOrderKey, '') = '' 
   BEGIN
      SET @nErrNo = 114001  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQ
      GOTO Quit  
   END

   -- Check if it is valid OrderKey
   IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                   WHERE OrderKey = @cOrderKey 
                   AND   StorerKey = @cStorerKey)
    BEGIN  
      SET @nErrNo = 114002  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ORDERS  
      GOTO Quit  
   END  

   SELECT @cStatus = [Status], 
          @cShipperKey = ShipperKey 
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   IF ISNULL( @cStatus, '') = '0'
    BEGIN  
      SET @nErrNo = 114003  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORD NOT ALLOC
      GOTO Quit  
   END  

   IF ISNULL( @cShipperKey, '') = ''
   BEGIN  
      SET @nErrNo = 114004  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO SHIPPER
      GOTO Quit  
   END  

   IF ISNULL( @cCartonNo, '') <> ''
   BEGIN
      IF rdt.rdtIsValidQTY( @cCartonNo, 1) = 0
      BEGIN  
         SET @nErrNo = 114005  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV CARTON NO
         GOTO Quit  
      END  
   END

   -- Get printer info  
   SELECT   
      @cLabelPrinter = Printer,   
      @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   /*-------------------------------------------------------------------------------  
  
                                    Print Ship Label  
  
   -------------------------------------------------------------------------------*/  
  
   -- Check label printer blank  
   IF @cLabelPrinter = ''  
   BEGIN  
      SET @nErrNo = 114005  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
      GOTO Quit  
   END  

      -- Common params
   DECLARE @tShipLabel AS VariableTable
   INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
   INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cFromCartonNo', @cCartonNo)
   INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cToCartonNo', @cCartonNo)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
      'SHIPLBLCV', -- Report type
      @tShipLabel, -- Report params
      'rdt_593ShipLabel09', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

Quit:  


GO
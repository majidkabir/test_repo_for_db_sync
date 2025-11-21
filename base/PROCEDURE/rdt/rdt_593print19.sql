SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_593Print19                                         */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2018-02-05 1.0  James    WMS3974. Created                               */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593Print19] (  
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
          ,@cBuyerPO      NVARCHAR( 20)
          ,@cValue        NVARCHAR( 20)
   
   SET @PickDetQty = '0'          

   -- Both value must not blank
   IF ISNULL(@cParam1, '') = '' 
   BEGIN
      SET @nErrNo = 119351  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQ
      GOTO Quit  
   END

   SET @cValue = @cParam1

   -- Remove leading 00
   SET @cValue = SUBSTRING ( @cValue, 3, LEN( RTRIM( @cParam1)) - 2)

   -- Orderkey
   IF LEN( @cValue) = 10
   BEGIN
      SELECT @cStatus = [Status] 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cValue

      -- Check if it is valid OrderKey
      IF @@ROWCOUNT = 0
      BEGIN  
         SET @nErrNo = 119352  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ORDERS  
         GOTO Quit  
      END 

      SET @cOrderKey = @cValue
   END  
   ELSE  -- BuyerPO
   BEGIN
      SELECT @cOrderKey = OrderKey, 
             @cStatus = [Status] 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   BuyerPO = @cValue

      -- Check if it is valid OrderKey
      IF @@ROWCOUNT = 0
      BEGIN  
         SET @nErrNo = 119353
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV CUST ORDERS  
         GOTO Quit  
      END 
   END

   -- Check orders allocated
   IF ISNULL( @cStatus, '') = '0'
   BEGIN  
      SET @nErrNo = 119354
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORD NOT ALLOC
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
      SET @nErrNo = 119355  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq  
      GOTO Quit  
   END  

   -- Common params
   DECLARE @tDELNOTES AS VariableTable
   INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
   INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey', '')

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter, 
      'DELNOTES', -- Report type
      @tDELNOTES, -- Report params
      'rdt_593Print19', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT

   IF @nErrNo <> 0
      GOTO Quit  

Quit:  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_593ShipLabel03                                     */  
/*                                                                         */  
/* Purpose: User key in tracking no. Check if orders exists                */  
/*          (userdefine04 = tracking no). If yes, update status = 9        */
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2016-07-01 1.0  James    SOS372555 Created                              */  
/* 2019-03-13 1.1  James    WMS8094 - Update editdate (james01)            */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593ShipLabel03] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- OrderKey  
   @cParam2    NVARCHAR(20),  -- Carton no
   @cParam3    NVARCHAR(20),  -- Reprint from web service  
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
          ,@cReportType   NVARCHAR( 10)
          ,@cPrintJobName NVARCHAR( 60)
          ,@cTrackingNo   NVARCHAR( 20) 
          ,@cOrderKey     NVARCHAR( 10) 
          ,@cTerminalCode NVARCHAR( 30)
          ,@cUCCLabelNo   NVARCHAR( 20) 
          ,@cExternOrderKey   NVARCHAR( 30)
          ,@nRowCount     INT

   SET @cTrackingNo = @cParam1

   -- Both value must not blank
   IF ISNULL(@cTrackingNo, '') = '' 
   BEGIN
      SET @nErrNo = 102201  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQ
      GOTO Quit  
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.CartonShipMentDetail WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey
                   AND   TrackingNumber = @cTrackingNo)
   BEGIN
      SET @nErrNo = 102202  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO TRACKING
      GOTO Quit  
   END

   SELECT @cExternOrderKey = ExternOrderKey, 
          @cUCCLabelNo = UCCLabelNo
   FROM dbo.CartonShipMentDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   TrackingNumber = @cTrackingNo

   -- Check if it is valid OrderKey
   SELECT @cOrderKey = OrderKey,
          @cTerminalCode = B_Country
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   ExternOrderKey = @cExternOrderKey

   SET @nRowCount = @@ROWCOUNT

   IF @nRowCount > 1
   BEGIN  
      SET @nErrNo = 102207  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --EXTORD > 1 ORD  
      GOTO Quit  
   END  

   IF ISNULL( @cOrderKey, '') = ''
   BEGIN  
      SET @nErrNo = 102203  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO ORDERS  
      GOTO Quit  
   END  

   IF ISNULL( @cTerminalCode, '') = ''
   BEGIN  
      SET @nErrNo = 102204  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO TERMINAL  
      GOTO Quit  
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
      SET @nErrNo = 102205  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
      GOTO Quit  
   END  

   SET @cReportType = 'SHIPLBL'
   SET @cPrintJobName = 'PRINT_SHIPPLABEL'

   SELECT   
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
      AND ReportType = @cReportType  

   -- Insert print job  
   SET @nErrNo = 0                    
   EXEC RDT.rdt_BuiltPrintJob                     
      @nMobile,                    
      @cStorerKey,                    
      @cReportType,                    
      @cPrintJobName,                    
      @cDataWindow,                    
      @cLabelPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @cExternOrderKey, 
      @cUCCLabelNo

   IF @nErrNo <> 0
      GOTO Quit  

   -- No error in printing then update orders to status '9'
   -- Use TrafficCop here as this storer do not have WMS inventory
   IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                WHERE StorerKey = @cStorerKey
                AND   OrderKey = @cOrderKey
                AND   [Status] <> '9')
   BEGIN
      UPDATE dbo.Orders WITH (ROWLOCK) SET 
         [Status] = '9', 
         EditDate = GETDATE(),   -- (james01)
         TrafficCop = NULL
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cOrderKey

      IF @@ERROR <> 0 OR @@ROWCOUNT = 0
      BEGIN  
         SET @nErrNo = 102206  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CLOSE ORD ERR  
         GOTO Quit  
      END  
   END

Quit:  

GO
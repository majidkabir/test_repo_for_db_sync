SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtTNTStoreLblReprn                                    */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2014-09-05 1.0  James    Created                                        */  
/* 2014-10-20 1.1  James    Prevent non TNT sack to reprint (james01)      */
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtTNTStoreLblReprn] (  
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
          ,@cToToteNo     NVARCHAR( 18)  
          ,@cOrderKey     NVARCHAR( 10) 
          ,@cTrackNo      NVARCHAR( 20) 
          ,@cPickSlipNo   NVARCHAR( 10)
          ,@cLabelNo      NVARCHAR( 20) 
          ,@nCartonNo     INT 
          ,@bSuccess      INT 
          ,@cRoute        NVARCHAR( 10)

   SET @cToToteNo = ''
   SET @cOrderKey = ''
   SET @cTrackNo  = ''

   SET @cToToteNo = @cParam1
   SET @cOrderKey = @cParam2
   SET @cTrackNo  = @cParam3

   -- To ToteNo value must not blank
   IF ISNULL(@cToToteNo, '') = '' AND ISNULL( @cOrderKey, '') = '' AND ISNULL( @cTrackNo, '') = ''
   BEGIN
      SET @nErrNo = 50551  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQ
      GOTO Quit  
   END

   IF ISNULL(@cToToteNo, '') <> '' AND ISNULL( @cOrderKey, '') <> ''
   BEGIN
      SET @nErrNo = 50552  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ONLY 1 VALUE
      GOTO Quit  
   END

   IF ISNULL(@cToToteNo, '') <> '' AND ISNULL( @cTrackNo, '') <> ''
   BEGIN
      SET @nErrNo = 50553  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ONLY 1 VALUE
      GOTO Quit  
   END

   IF ISNULL(@cOrderKey, '') <> '' AND ISNULL( @cTrackNo, '') <> ''
   BEGIN
      SET @nErrNo = 50554  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ONLY 1 VALUE
      GOTO Quit  
   END

   -- Get printer info  
   SELECT @cLabelPrinter = Printer 
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   IF ISNULL( @cLabelPrinter, '') = ''
   BEGIN
      SET @nErrNo = 50555  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelPrnterReq
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
      AND ReportType = 'SORTTNTLBL'  

   IF ISNULL(@cToToteNo, '') <> ''
   BEGIN
      SELECT @cRoute = PH.Route, @cOrderKey = PH.OrderKey, @cPickSlipNo = PH.PickSlipNo 
      FROM dbo.PackHeader PH WITH (NOLOCK) 
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipno = PD.PickSlipNo)
      WHERE PH.StorerKey = @cStorerKey
      AND   PD.DropID = @cToToteNo

      -- Check if it is valid Sacks/Tote
      IF ISNULL( @cOrderKey, '') = ''
      BEGIN  
         SET @nErrNo = 50556  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Sacks  
         GOTO Quit  
      END  

      -- (james01)
      IF ISNULL( @cRoute, '') <> 'TNT'
      BEGIN  
         SET @nErrNo = 50563  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NOT TNT Sacks  
         GOTO Quit  
      END  

      IF EXISTS ( SELECT 1 
                  FROM dbo.PackDetail WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   DropID = @cToToteNo
                  AND   LabelNo = '') 
      BEGIN  
         SET @nErrNo = 50557  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Label Not Found  
         GOTO Quit  
      END

      -- 1 carton 1 TNT label
      SELECT TOP 1 @cLabelNo = LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipno
      AND   DropID = @cToToteNo

      -- Check if it is label printed for sacks/Tote
      IF NOT EXISTS ( SELECT 1 FROM dbo.CartonShipmentDetail WITH (NOLOCK) 
                      WHERE UCCLabelNo = @cToToteNo)
       BEGIN  
         SET @nCartonNo = 1
         EXEC [dbo].[isp_WS_TNT_ExpressLabel] 
             @nMobile,         
             @cPickSlipNo,     
             @nCartonNo,       
             @cLabelNo,        
             @bSuccess        OUTPUT,  
             @nErrNo          OUTPUT,  
             @cErrMsg         OUTPUT 

         IF @bSuccess <> 1
            GOTO Quit
      END  
        
      -- Insert print job  
      SET @nErrNo = 0                    
      EXEC RDT.rdt_BuiltPrintJob                     
         @nMobile,                    
         @cStorerKey,                    
         'SORTTNTLBL',                    
         'PRINT_SORTTNTLABEL',                    
         @cDataWindow,                    
         @cLabelPrinter,                    
         @cTargetDB,                    
         @cLangCode,                    
         @nErrNo  OUTPUT,                     
         @cErrMsg OUTPUT,                    
         @cToToteNo,    
         @cStorerKey       

      GOTO Quit  
   END

   IF ISNULL(@cOrderKey, '') <> ''
   BEGIN
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.PackDetail PD WITH (NOLOCK) 
                      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
                      WHERE PH.StorerKey = @cStorerKey
                      AND   PH.OrderKey = @cOrderKey
                      AND   PD.DropID <> '') 
      BEGIN  
         SET @nErrNo = 50559  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Label Not Found  
         GOTO Quit  
      END

      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackHeader WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cOrderKey

      -- 1 carton 1 TNT label
      SELECT TOP 1 @cLabelNo = LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipno

      -- Check if it is label printed for sacks/Tote
      IF NOT EXISTS ( SELECT 1 FROM dbo.CartonShipmentDetail WITH (NOLOCK) 
                      WHERE UCCLabelNo = @cToToteNo)
       BEGIN  
         SET @nCartonNo = 1
         EXEC [dbo].[isp_WS_TNT_ExpressLabel] 
             @nMobile,         
             @cPickSlipNo,     
             @nCartonNo,       
             @cLabelNo,        
             @bSuccess        OUTPUT,  
             @nErrNo          OUTPUT,  
             @cErrMsg         OUTPUT 

         IF @bSuccess <> 1
            GOTO Quit
      END  

      -- Insert print job  
      SET @nErrNo = 0                    
      EXEC RDT.rdt_BuiltPrintJob                     
         @nMobile,                    
         @cStorerKey,                    
         'SORTTNTLBL',                    
         'PRINT_SORTTNTLABEL',                    
         @cDataWindow,                    
         @cLabelPrinter,                    
         @cTargetDB,                    
         @cLangCode,                    
         @nErrNo  OUTPUT,                     
         @cErrMsg OUTPUT,                    
         @cToToteNo,    
         @cStorerKey       

      IF @nErrNo <> 0
         GOTO Quit
      
      GOTO Quit
   END
   
   IF ISNULL(@cTrackNo, '') <> ''
   BEGIN
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.CartonShipmentDetail WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND   TrackingNumber = @cTrackNo) 
      BEGIN  
         SET @nErrNo = 50561  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Track#NotFound  
         GOTO Quit  
      END  

      SELECT @cToToteNo = PD.DropID 
      FROM dbo.CartonShipmentDetail CSD WITH (NOLOCK) 
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON ( CSD.UCCLabelNo = PD.LabelNo) 
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo AND CSD.OrderKey = PH.OrderKey)
      WHERE CSD.TrackingNumber = @cTrackNo
      AND   PH.StorerKey = @cStorerKey

      -- Insert print job  
      SET @nErrNo = 0                    
      EXEC RDT.rdt_BuiltPrintJob                     
         @nMobile,                    
         @cStorerKey,                    
         'SORTTNTLBL',                    
         'PRINT_SORTTNTLABEL',                    
         @cDataWindow,                    
         @cLabelPrinter,                    
         @cTargetDB,                    
         @cLangCode,                    
         @nErrNo  OUTPUT,                     
         @cErrMsg OUTPUT,                    
         @cToToteNo,    
         @cStorerKey       

      GOTO Quit
   END
   


Quit:  

GO
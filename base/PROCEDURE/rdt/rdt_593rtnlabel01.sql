SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_593RtnLabel01                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author   Purposes                                      */
/* 2017-Jul-19 1.0  James    WMS2429. Created                              */
/* 2021-Apr-08 1.1  James    WMS-16024 Standar use of TrackingNo (james01) */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593RtnLabel01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- Label No
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

   DECLARE @cLabelPrinter  NVARCHAR( 10)
          ,@cPaperPrinter  NVARCHAR( 10)
          ,@cTrackingNo    NVARCHAR( 20)
          ,@cPickSlipNo    NVARCHAR( 10)
          ,@cLoadKey       NVARCHAR( 10) 
          ,@cOrderKey      NVARCHAR( 10) 
          ,@cShipperKey    NVARCHAR( 15) 
          ,@cSOStatus      NVARCHAR( 10) 
          ,@nCartonNo      INT

   -- Parameter mapping
   SET @cTrackingNo = @cParam1

   -- Check blank
   IF ISNULL( @cTrackingNo, '') = ''
   BEGIN
      SET @nErrNo = 112651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --TrackNo req
      GOTO Quit
   END

   SELECT TOP 1 @cPickSlipNo = PIF.PickSlipNo, 
                @nCartonNo = PIF.CartonNo,
                @cOrderKey = PH.OrderKey
   FROM dbo.PackInfo PIF WITH (NOLOCK)
   JOIN dbo.PackDetail PD WITH (NOLOCK) ON ( PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo)
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
   WHERE PIF.TrackingNo = @cTrackingNo
   AND   PH.StorerKey = @cStorerKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 112652
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid TrackNo
      GOTO Quit
   END

   SELECT @cSOStatus = SOStatus
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 112653
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --No OrderKey
      GOTO Quit
   END

   IF @cSOStatus NOT IN ('5', '9')
   BEGIN
      SET @nErrNo = 112654
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Order Not Pick
      GOTO Quit
   END

    -- Get login info
   SELECT @cLabelPrinter = Printer
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Common params
   DECLARE @tReturnLabel AS VariableTable
   INSERT INTO @tReturnLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
   INSERT INTO @tReturnLabel (Variable, Value) VALUES ( '@nCartonStart', @nCartonNo)
   INSERT INTO @tReturnLabel (Variable, Value) VALUES ( '@nCartonEnd', @nCartonNo)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
      'SHIPPIRLBL', -- Report type
      @tReturnLabel, -- Report params
      'rdt_593RtnLabel01', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

Quit:
  


GO
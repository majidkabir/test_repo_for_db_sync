SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593ShipLabel08                                     */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author   Purposes                                      */
/* 2017-Jul-25 1.0  James    WMS2482. Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593ShipLabel08] (
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
          ,@cLabelNo    NVARCHAR( 20)
          ,@cPickSlipNo    NVARCHAR( 10)
          ,@cLoadKey       NVARCHAR( 10) 
          ,@cOrderKey      NVARCHAR( 10) 
          ,@cShipperKey    NVARCHAR( 15) 
          ,@cSOStatus      NVARCHAR( 10) 
          ,@nCartonNo      INT

   -- Parameter mapping
   SET @cLabelNo = @cParam1

   -- Check blank
   IF ISNULL( @cLabelNo, '') = ''
   BEGIN
      SET @nErrNo = 112901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNo req
      GOTO Quit
   END

   SELECT TOP 1 @cPickSlipNo = PD.PickSlipNo
   FROM dbo.PackDetail PD WITH (NOLOCK) 
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
   WHERE PD.LabelNo = @cLabelNo
   AND   PD.StorerKey = @cStorerKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 112902
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid LabelNo
      GOTO Quit
   END

    -- Get login info
   SELECT @cLabelPrinter = Printer
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Common params
   DECLARE @tShipLabel AS VariableTable
   INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
   INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
      'SHIPLABEL', -- Report type
      @tShipLabel, -- Report params
      'rdt_593ShipLabel08', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

Quit:
  


GO
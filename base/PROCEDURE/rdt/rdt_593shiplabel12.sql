SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593ShipLabel12                                     */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date        Rev  Author   Purposes                                      */
/* 2018-06-18  1.0  Ung      WMS-5435 Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593ShipLabel12] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR( 60),  -- Label No
   @cParam2    NVARCHAR( 60),  
   @cParam3    NVARCHAR( 60),  
   @cParam4    NVARCHAR( 60),
   @cParam5    NVARCHAR( 60),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount      INT
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @cPaperPrinter  NVARCHAR( 10)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cCartonType    NVARCHAR( 30)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cRoute         NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   DECLARE @nWeight        FLOAT
   DECLARE @nCube          FLOAT

   -- Parameter mapping
   SET @cDropID = @cParam1
   SET @cCartonType = @cParam2

   -- Check blank
   IF @cDropID = ''
   BEGIN
      SET @nErrNo = 125251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
      GOTO Quit
   END

   -- Get PackDetail info
   SELECT TOP 1 
      @cPickSlipNo = PD.PickSlipNo, 
      @nCartonNo = CartonNo, 
      @cOrderKey = OrderKey
   FROM dbo.PackDetail PD WITH (NOLOCK) 
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
   WHERE PD.DropID = @cDropID
      AND PD.StorerKey = @cStorerKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 125252
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DropID
      GOTO Quit
   END

   -- Get Order info
   SELECT @cRoute = Route FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
   
   -- Export orders
   IF EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'EXOrdRoute' AND Code = @cRoute AND StorerKey = @cStorerKey)
   BEGIN
      -- Check carton type blank
      IF @cCartonType = ''
      BEGIN
         SET @nErrNo = 125253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType
         GOTO Quit
      END

      -- Get carton type info
      SET @nRowCount = 0
      SELECT TOP 1 
         @nRowCount = 1, 
         @nCube = Cube, 
         @nWeight = ISNULL( CartonWeight, 0)
      FROM Storer S WITH (NOLOCK)
         JOIN Cartonization C WITH (NOLOCK) ON (S.CartonGroup = C.CartonizationGroup)
      WHERE S.StorerKey = @cStorerKey
         AND C.CartonType = @cCartonType

      IF @nRowCount = 0
         SELECT TOP 1 
            @nRowCount = 1, 
            @cCartonType = CartonType, 
            @nCube = Cube, 
            @nWeight = ISNULL( CartonWeight, 0)
         FROM Storer S WITH (NOLOCK)
            JOIN Cartonization C WITH (NOLOCK) ON (S.CartonGroup = C.CartonizationGroup)
         WHERE S.StorerKey = @cStorerKey
            AND C.Barcode = @cCartonType

      -- Check Carton type valid
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 125254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonType
         GOTO Quit
      END
   END
   ELSE
      SET @cCartonType = ''
   
   -- PackInfo
   IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
   BEGIN
      INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Weight, Cube, CartonType)
      VALUES (@cPickSlipNo, @nCartonNo, @nWeight, @nCube, @cCartonType)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 125255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
         GOTO Quit
      END
   END
   ELSE
   BEGIN
      UPDATE dbo.PackInfo SET
         Weight = @nWeight, 
         Cube = @nCube, 
         CartonType = @cCartonType, 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 125256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
         GOTO Quit
      END
   END

    -- Get login info
   SELECT 
      @cFacility = Facility, 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Storer configure
   DECLARE @cShipLabel NVARCHAR(10)
   SET @cShipLabel = rdt.rdtGetConfig( @nFunc, 'ShipLabel', @cStorerKey)

   DECLARE @cCartonManifest NVARCHAR(10)
   SET @cCartonManifest = rdt.rdtGetConfig( @nFunc, 'CartonManifest', @cStorerKey)

   -- Ship label
   IF @cShipLabel <> '' 
   BEGIN
      -- Get load info (assume DropID only in 1 load)
      DECLARE @cLoadKey NVARCHAR(10)
      SET @cLoadKey = ''
      SELECT TOP 1 
         @cLoadKey = PH.LoadKey 
   	FROM dbo.PackHeader PH WITH (NOLOCK)  
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      WHERE PD.DropID  = @cDropID
         AND PD.StorerKey = @cStorerKey
      
      IF @cLoadKey = ''
      BEGIN
         SET @nErrNo = 125257
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Load not found
         GOTO Quit
      END
      
      -- Check not yet pack cofirm
      IF EXISTS (SELECT 1 
         FROM dbo.PackHeader WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
            AND StorerKey = @cStorerKey
            AND Status < '9')
      BEGIN
         SET @nErrNo = 125258
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotPackConfirm
         GOTO Quit
      END
      
      -- Check not fully pick
      IF EXISTS (SELECT 1 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.Status < '5')
      BEGIN
         SET @nErrNo = 125259
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickInProgress
         GOTO Quit
      END
      
      -- Common params
      DECLARE @tShipLabel AS VariableTable
      INSERT INTO @tShipLabel (Variable, Value) VALUES 
         ( '@cStorerKey', @cStorerKey), 
         ( '@cDropID',    @cDropID)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 1, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
         @cShipLabel, -- Report type
         @tShipLabel, -- Report params
         'rdt_593ShipLabel12', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END
   
   IF @cCartonManifest <> ''
   BEGIN
      -- Common params
      DECLARE @tCartonManifest AS VariableTable
      INSERT INTO @tCartonManifest (Variable, Value) VALUES 
         ( '@cStorerKey', @cStorerKey), 
         ( '@cDropID',    @cDropID)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 1, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
         @cCartonManifest, -- Report type
         @tCartonManifest, -- Report params
         'rdt_593ShipLabel12', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

Quit:
  


GO
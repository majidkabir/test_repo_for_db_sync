SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_Cluster_Pick_PrintLabel                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Print label                                                 */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 24-Nov-2015 1.0  James       Created                                 */
/* 04-Apr-2018 1.1  James       WMS4338-Add rdt_print (james01)         */
/* 30-Oct-2020 1.2  James       Adhoc fix on fnc conversion err(james02)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_Cluster_Pick_PrintLabel] (
   @nMobile          INT, 
   @nFunc            INT, 
   @nStep            INT, 
   @nInputKey        INT, 
   @cLangCode        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cWaveKey         NVARCHAR( 10),
   @cLoadKey         NVARCHAR( 10),
   @cOrderKey        NVARCHAR( 10),
   @cPickSlipNo      NVARCHAR( 10),
   @cLOC             NVARCHAR( 10),
   @cDropID          NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQty             INT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE  @cPaperPrinter       NVARCHAR( 10),
            @cLabelPrinter       NVARCHAR( 10),
            @cReportType         NVARCHAR( 10),
            @cPrintJobName       NVARCHAR( 50),
            @cDataWindow         NVARCHAR( 50),
            @cTargetDB           NVARCHAR( 10),
            @cSP                 NVARCHAR( 20),
            @cSQLStatement       NVARCHAR( 4000),
            @cSQLParms           NVARCHAR( 4000),
            @cOption             NVARCHAR( 1), 
            @cParam1             NVARCHAR( 20), 
            @cParam2             NVARCHAR( 20), 
            @cParam3             NVARCHAR( 20), 
            @cParam4             NVARCHAR( 20), 
            @cParam5             NVARCHAR( 20),
            @cShipLabel          NVARCHAR( 10),
            @cLabelNo            NVARCHAR( 20),
            @cFacility           NVARCHAR( 5),
            @nCartonNo           INT

   SELECT @cLabelPrinter = Printer, 
          @cPaperPrinter = Printer_Paper 
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''

   IF ISNULL( @cPickSlipNo, '') = '' AND ISNULL( @cOrderKey, '') <> ''
      -- check discrete first
      SELECT TOP 1 @cPickSlipNo = PickHeaderKey
      FROM dbo.PickHeader PH WITH (NOLOCK)
      WHERE PH.OrderKey = @cOrderKey
      AND   PH.Status = '0'

   -- not discrete pick, look in wave
   IF ISNULL(@cPickSlipNo, '') = '' AND ISNULL( @cWaveKey, '') <> ''
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE WaveKey = @cWaveKey
         AND   Status = '0'

   -- If not wave plan, look in loadplan
   IF ISNULL(@cPickSlipNo, '') = '' AND ISNULL( @cLoadKey, '') <> ''
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE ExternOrderKey = @cLoadKey
         AND   Status = '0'

   IF EXISTS (SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)
              WHERE StorerKey = @cStorerKey
              AND   ReportType = 'CLOCASELBL')
   BEGIN
      IF ISNULL(@cLabelPrinter, '') = ''
      BEGIN
         SET @nErrNo = 95201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter
         GOTO Quit
      END

      SET @cReportType = 'CLOCASELBL'
      SET @cPrintJobName = 'PRINT CLOSE CASE Label'

      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
             @cTargetDB = ISNULL(RTRIM(TargetDB), '')
      FROM RDT.RDTReport WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ReportType = @cReportType

      IF ISNULL(@cDataWindow, '') = ''
      BEGIN
         SET @nErrNo = 95202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
         GOTO Quit
      END

      IF ISNULL(@cTargetDB, '') = ''
      BEGIN
         SET @nErrNo = 95203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
         GOTO Quit
      END

      --(james04)
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
         @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO Quit
   END

   IF EXISTS (SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)
              WHERE StorerKey = @cStorerKey
              AND   ReportType = 'CTNMANFEST')
   BEGIN
      SET @cReportType = 'CTNMANFEST'  
      SET @cPrintJobName = 'PRINT CARTON MANIFEST LABEL'  

      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
             @cTargetDB = ISNULL(RTRIM(TargetDB), '')  
      FROM RDT.RDTReport WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND ReportType = @cReportType  

      IF @@ROWCOUNT > 0
      BEGIN
         IF ISNULL(@cPaperPrinter, '') = ''
         BEGIN
            SET @nErrNo = 95204
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter
            GOTO Quit
         END
            
         IF ISNULL(@cDataWindow, '') = ''  
         BEGIN  
            SET @nErrNo = 95205  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
            GOTO Quit  
         END  
  
         IF ISNULL(@cTargetDB, '') = ''  
         BEGIN  
            SET @nErrNo = 95206  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set  
            GOTO Quit  
         END  
  
         SET @nErrNo = 0  
         EXEC RDT.rdt_BuiltPrintJob  
            @nMobile,  
            @cStorerKey,  
            @cReportType,  
            @cPrintJobName,  
            @cDataWindow,  
            @cPaperPrinter,  
            @cTargetDB,  
            @cLangCode,  
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT, 
            @cOrderKey
  
         IF @nErrNo <> 0  
            GOTO Quit  
      END
   END

   -- Ship label
   IF @cShipLabel <> '' 
   BEGIN
      SELECT @cLabelNo = LabelNo, @nCartonNo = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND   DropID = @cDropID

      -- Common params
      DECLARE @tShipLabel AS VariableTable
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cFromDropID', @cDropID)
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@nCartonNo', @nCartonNo)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
         @cShipLabel, -- Report type
         @tShipLabel, -- Report params
         'rdt_Cluster_Pick_PrintLabel', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

   SELECT @cSP = Long
   FROM dbo.CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'RDTLBLRPT' 
      AND StorerKey = @cStorerKey
      AND Code2 = CAST( @nFunc AS NVARCHAR( 30))   

   -- Proceed printing if report sp setup
   IF ISNULL( @cSP, '') <> ''
   BEGIN
      -- Check SP setup
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')
      BEGIN
         SET @nErrNo = 95207
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SP NotSetup
         GOTO Quit
      END
      ELSE
      -- Execute label/report stored procedure
      BEGIN
         SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cSP) +
            ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParms =
            '@nMobile    INT,           ' +
            '@nFunc      INT,           ' +
            '@nStep      INT,           ' + 
            '@cLangCode  NVARCHAR( 3),  ' +
            '@cStorerKey NVARCHAR( 15), ' + 
            '@cOption    NVARCHAR( 1),  ' +
            '@cParam1    NVARCHAR(20),  ' + 
            '@cParam2    NVARCHAR(20),  ' + 
            '@cParam3    NVARCHAR(20),  ' + 
            '@cParam4    NVARCHAR(20),  ' + 
            '@cParam5    NVARCHAR(20),  ' + 
            '@nErrNo     INT OUTPUT,    ' +
            '@cErrMsg    NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,
            @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cOrderKey, @cParam2, @cParam3, @cParam4, @cParam5, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
   END               
END

Quit:

GO
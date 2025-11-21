SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_838ExtUpd15                                           */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 04-07-2023 1.0  Ung        WMS-22913 Created                               */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_838ExtUpd15] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20), 
   @cPackDtlRefNo2   NVARCHAR( 20), 
   @cPackDtlUPC      NVARCHAR( 30), 
   @cPackDtlDropID   NVARCHAR( 20), 
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30), 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 2 -- Statistics
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            DECLARE @nTotalPick INT
            DECLARE @nTotalPack INT

            -- Get statistics
            IF @cFromDropID = ''
               SELECT
                  @nTotalPick = V_Integer4,
                  @nTotalPack = V_Integer5
               FROM rdt.rdtMobRec WITH (NOLOCK)
               WHERE Mobile = @nMobile
            ELSE
            BEGIN
               DECLARE @cSQL        NVARCHAR( MAX)
               DECLARE @cSQLParam   NVARCHAR( MAX)
               DECLARE @cOrderKey   NVARCHAR( 10)
               DECLARE @cLoadKey    NVARCHAR( 10)
               DECLARE @cZone       NVARCHAR( 18)
               DECLARE @cPickFilter NVARCHAR( MAX) = ''
               DECLARE @cPackFilter NVARCHAR( MAX) = ''

               -- Get PickHeader info
               SELECT TOP 1
                  @cOrderKey = OrderKey,
                  @cLoadKey = ExternOrderKey,
                  @cZone = Zone
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickSlipNo               
               
               -- Get pick filter
               SELECT @cPickFilter = ISNULL( Long, '')
               FROM CodeLKUP WITH (NOLOCK) 
               WHERE ListName = 'PickFilter'
                  AND Code = @nFunc 
                  AND StorerKey = @cStorerKey
                  AND Code2 = @cFacility

               -- Get pack filter
               SELECT @cPackFilter = ISNULL( Long, '')
               FROM CodeLKUP WITH (NOLOCK) 
               WHERE ListName = 'PackFilter'
                  AND Code = @nFunc 
                  AND StorerKey = @cStorerKey
                  AND Code2 = @cFacility

               -- Get PickStatus
               DECLARE @cPickStatus NVARCHAR( 20)
               SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey)
               
               -- Add default PickStatus 5-picked, if not specified
               IF CHARINDEX( '5', @cPickStatus) = 0
                  SET @cPickStatus += ',5'
                  
               -- Make PickStatus into comma delimeted, quoted string, in '0','5'... format
               SELECT @cPickStatus = STRING_AGG( QUOTENAME( a.value, ''''), ',')
               FROM 
               (
                  SELECT TRIM( value) value FROM STRING_SPLIT( @cPickStatus, ',') WHERE value <> ''
               ) a

               -- Get Pack QTY
               SET @cSQL = 
                  ' SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0) ' + 
                  ' FROM PackDetail PD WITH (NOLOCK) ' + 
                  ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
                     ' AND PD.StorerKey = @cStorerKey ' + 
                     CASE WHEN @cFromDropID <> '' THEN ' AND PD.DropID = @cFromDropID ' ELSE '' END + 
                     CASE WHEN @cPackFilter <> '' THEN @cPackFilter ELSE '' END
               SET @cSQLParam = 
                  ' @cPickSlipNo NVARCHAR( 10), ' + 
                  ' @cStorerKey  NVARCHAR( 15), ' + 
                  ' @cFromDropID NVARCHAR( 20), ' + 
                  ' @nPackQTY    INT OUTPUT '
               EXEC sp_executeSQL @cSQL, @cSQLParam
                  ,@cPickSlipNo = @cPickSlipNo
                  ,@cStorerKey  = @cStorerKey 
                  ,@cFromDropID = @cFromDropID
                  ,@nPackQTY    = @nTotalPack OUTPUT
               
               -- Get Pick QTY
               IF @cZone IN ('XD', 'LB', 'LP') -- Cross dock PickSlip
                  SET @cSQL = 
                     ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
                        ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' + 
                     ' WHERE RKL.PickSlipNo = @cPickSlipNo '  

               ELSE IF @cOrderKey <> ''   -- Discrete PickSlip
                  SET @cSQL = 
                     ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                     ' WHERE PD.OrderKey = @cOrderKey '

               ELSE IF @cLoadKey <> '' -- Conso PickSlip
                  SET @cSQL = 
                     ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' + 
                        ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
                     ' WHERE LPD.LoadKey = @cLoadKey '

               ELSE  -- Custom PickSlip
                  SET @cSQL = 
                     ' FROM dbo.PickDetail PD (NOLOCK) ' + 
                     ' WHERE PD.PickSlipNo = @cPickSlipNo ' 

               -- Build complete SQL
               SET @cSQL = 
                  ' SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0) ' + 
                  @cSQL + 
                     ' AND PD.StorerKey = @cStorerKey ' + 
                     ' AND PD.Status IN (' + @cPickStatus + ') ' + 
                     CASE WHEN @cFromDropID <> '' THEN ' AND PD.DropID = @cFromDropID ' ELSE '' END + 
                     CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END 
                     
               SET @cSQLParam = 
                  ' @cPickSlipNo NVARCHAR( 10), ' + 
                  ' @cLoadKey    NVARCHAR( 10), ' + 
                  ' @cOrderKey   NVARCHAR( 10), ' + 
                  ' @cStorerKey  NVARCHAR( 15), ' + 
                  ' @cFromDropID NVARCHAR( 20), ' + 
                  ' @nPickQTY    INT OUTPUT '
               EXEC sp_executeSQL @cSQL, @cSQLParam
                  ,@cPickSlipNo = @cPickSlipNo
                  ,@cLoadKey    = @cLoadKey
                  ,@cOrderKey   = @cOrderKey
                  ,@cStorerKey  = @cStorerKey
                  ,@cFromDropID = @cFromDropID
                  ,@nPickQTY    = @nTotalPick OUTPUT
            END
            
            -- Variance
            IF @nTotalPick > 0 AND @nTotalPick <> @nTotalPack
            BEGIN
               DECLARE @cVarianceReport NVARCHAR( 10)
               SET @cVarianceReport = rdt.RDTGetConfig( @nFunc, 'VarianceReport', @cStorerKey)
               IF @cVarianceReport = '0'
                  SET @cVarianceReport = ''

               -- Variance report
               IF @cVarianceReport <> ''
               BEGIN
                  -- Get session info
                  DECLARE @cLabelPrinter NVARCHAR( 10)
                  DECLARE @cPaperPrinter NVARCHAR( 10)
                  SELECT
                     @cLabelPrinter = Printer, 
                     @cPaperPrinter = Printer_Paper
                  FROM rdt.rdtMobRec WITH (NOLOCK)
                  WHERE Mobile = @nMobile
                  
                  -- Get report param
                  DECLARE @tVarianceReport AS VariableTable
                  INSERT INTO @tVarianceReport (Variable, Value) VALUES
                     ( '@cPickSlipNo',    @cPickSlipNo), 
                     ( '@cFromDropID',    @cFromDropID)

                  -- Print packing list
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                     @cVarianceReport, -- Report type
                     @tVarianceReport, -- Report params
                     'rdt_838ExtUpd15',
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT
                  IF @nErrNo <> 0
                     GOTO Quit 
               END
            END
         END
      END
   END

Quit:

END

GO
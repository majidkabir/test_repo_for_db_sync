SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_921ExtPrint01                                   */
/* Purpose: Print Label for puma                                        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-08-06 1.0  JHU151    FCR-631 Created                            */
/* 2024-11-25 1.1  TLE109    FCR-1378 Change in report PackInfLE        */
/************************************************************************/
CREATE   PROC [rdt].[rdt_921ExtPrint01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 2),
   @cParam1    NVARCHAR(20),  -- dropid
   @cParam2    NVARCHAR(20),  
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey      NVARCHAR( 10),
           @nCartonNo      INT,
           @cPickSlipNo    NVARCHAR( 10),
           @cReportType    NVARCHAR( 10),
           @cFacility      NVARCHAR( 5),
           @cPaperPrinter  NVARCHAR( 10),
           @cPrinter       NVARCHAR( 10),
           @nInputKey      INT,
           @nTotalCQty     INT,
           @nTotalPackQty  INT

   -- Get Default Printer
   SELECT   @cPrinter = ISNULL(Printer,'')
            ,@cPaperPrinter = ISNULL(Printer_Paper,'')
            ,@cFacility = ISNULL(Facility, '')
            ,@nInputKey = InputKey
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile


   SELECT TOP 1
      @cPickSlipNo = PickSlipNo,
      @nCartonNo = CartonNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND DropID = @cParam1
   ORDER BY PickSlipNo DESC

   SELECT @cOrderKey = OrderKey
   FROM dbo.PackHeader WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND PickslipNo = @cPickSlipNo


   SELECT @nTotalPackQty = SUM(qty)
   FROM PackDetail WIHT(NOLOCK)
   WHERE storerkey = @cStorerKey
      AND PickslipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
   
   SELECT
      @nTotalCQty = SUM(CQTY)
   FROM RDT.RDTPPA WITH(NOLOCK)
   WHERE storerkey = @cStorerKey
   --AND PickslipNo = @cPickSlipNo
   AND DropID = @cParam1

   DECLARE @tShipLabel AS VariableTable

   IF @nTotalPackQty = @nTotalCQty
      AND NOT EXISTS(SELECT 1
                  FROM PickDetail WITH(NOLOCK)
                  WHERE orderkey = @cOrderKey
                  AND storerkey = @cStorerKey
                  AND status IN ('0','4'))
   BEGIN
      SET @cReportType = 'PackInfLBL'

      INSERT INTO @tShipLabel (Variable, Value) VALUES 
      ( '@cStorerKey',  @cStorerKey), 
      ( '@cPickSlipNo', @cPickSlipNo), 
      ( '@nCartonNo',   CAST( @nCartonNo AS NVARCHAR(10)))
   END
   ELSE IF @nTotalPackQty = @nTotalCQty
      AND EXISTS(SELECT 1
                  FROM PickDetail WITH(NOLOCK)
                  WHERE orderkey = @cOrderKey
                  AND storerkey = @cStorerKey
                  AND status IN ('0','4'))
   BEGIN
      /**
      SET @cReportType = 'PackInfLE2'
      
      INSERT INTO @tShipLabel (Variable, Value) VALUES 
      ( '@DropID',   CAST( @cParam1 AS NVARCHAR(20))),
      ( '@cStorerKey',  @cStorerKey), 
      ( '@cPickSlipNo', @cPickSlipNo)
      **/
      SET @cReportType = 'PackInfLE2'

      INSERT INTO @tShipLabel (Variable, Value) VALUES 
      ( '@cStorerKey',  @cStorerKey), 
      ( '@cPickSlipNo', @cPickSlipNo), 
      ( '@nCartonNo',   CAST( @nCartonNo AS NVARCHAR(10)))
   END
   ELSE IF @nTotalPackQty <> @nTotalCQty
   BEGIN
      SET @cReportType = 'PackInfLE'

      INSERT INTO @tShipLabel (Variable, Value) VALUES 
      ( '@cStorerKey',  @cStorerKey), 
      ( '@cPickSlipNo', @cPickSlipNo),
      ( '@nCartonNo',   CAST( @nCartonNo AS NVARCHAR(10)))
   END
   ELSE
   BEGIN
      GOTO QUIT
   END

   

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPrinter, @cPaperPrinter, 
      @cReportType, -- Report type
      @tShipLabel, -- Report params
      'rdt_921ExtPrint01', --source type
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT

   IF @nErrNo <> 0
      GOTO Quit
      
Quit:

END


GO
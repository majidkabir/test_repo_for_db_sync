SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint26                                   */
/* Purpose: Print carton label                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-03-31 1.0  James      WMS-22084. Created                        */
/* 2023-08-25 1.1  James      WMS-23401 Add additional report retrieved */
/*                            from CODELKUP using BillToKey (james01)   */
/*                            Add condition skip print carton label     */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtPrint26] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerkey  NVARCHAR( 15),
   @cOrderKey   NVARCHAR( 10),
   @cPickSlipNo NVARCHAR( 10),
   @cTrackNo    NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @nCartonNo   INT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelPrinter     NVARCHAR( 10)
   DECLARE @cCartonLbl        NVARCHAR( 10)
   DECLARE @cShipperKey       NVARCHAR( 15)
   DECLARE @tCartonLbl        VariableTable
   DECLARE @cLabelNo          NVARCHAR( 20)
   DECLARE @cCartonLbl2       NVARCHAR( 10)
   DECLARE @cBillToKey        NVARCHAR( 15)
   DECLARE @cReportType       NVARCHAR( 10)
   DECLARE @nSkipPrintCtnLbl  INT = 0
   
   SELECT @cLabelPrinter = Printer
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         SELECT @cBillToKey = BillToKey
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
       
      	IF EXISTS( SELECT TOP 1 1 
      	           FROM dbo.CODELKUP WITH (NOLOCK) 
      	           WHERE Listname = 'LVSLBLSKIP'
      	           AND   Code = @cBillToKey 
      	           AND   StorerKey = @cStorerKey) 
      	   SET @nSkipPrintCtnLbl = 1
      	   
      	SELECT TOP 1
      	   @cLabelNo = LabelNo
      	FROM dbo.PackDetail WITH (NOLOCK)
      	WHERE PickSlipNo = @cPickSlipNo
      	AND   CartonNo = @nCartonNo
      	ORDER BY 1
      	
         SET @cCartonLbl = rdt.RDTGetConfig( @nFunc, 'CartonLbl', @cStorerKey)
         IF @cCartonLbl = '0'
            SET @cCartonLbl = ''

         IF @cCartonLbl <> '' AND @nSkipPrintCtnLbl = 0
         BEGIN
            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@cPickSlipNo',    @cPickSlipNo)
            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@cOrderkey',      @cOrderkey)
            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@nCartonNo',      @nCartonNo)
            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@cLabelNo',       @cLabelNo)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
               @cCartonLbl, -- Report type
               @tCartonLbl, -- Report params
               'rdt_840ExtPrint26',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
         END

         SELECT @cReportType = Long
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'LVSPLTCUST'
         AND   Code = @cBillToKey
         AND   Storerkey = @cStorerkey
         
         IF EXISTS ( SELECT 1 
                     FROM rdt.RDTReport WITH (NOLOCK)
                     WHERE StorerKey = @cStorerkey
                     AND   ReportType = @cReportType) AND ISNULL( @cReportType, '') <> ''
         BEGIN
         	DELETE FROM @tCartonLbl
            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@cPickSlipNo',    @cPickSlipNo)
            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@cOrderkey',      @cOrderkey)
            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@nCartonNo',      @nCartonNo)
            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@cLabelNo',       @cLabelNo)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
               @cReportType, -- Report type
               @tCartonLbl, -- Report params
               'rdt_840ExtPrint26',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
         END
      END   -- IF @nStep = 4
   END   -- @nInputKey = 1

Quit: 

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593ECLLabel01                                         */
/*                                                                            */
/* Customer: Granite                                                          */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-02-07 1.0  NLT03      FCR-727 Create                                  */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_593ECLLabel01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 2), 
   @cParam1    NVARCHAR(60), 
   @cParam2    NVARCHAR(60), 
   @cParam3    NVARCHAR(60), 
   @cParam4    NVARCHAR(60), 
   @cParam5    NVARCHAR(60), 
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @cDropID                   NVARCHAR( 20),
      @cLabelPrinterGroup        NVARCHAR( 10),
      @cPaperPrinter             NVARCHAR( 10),
      @cFacility                 NVARCHAR( 5),
      @cLabelName                NVARCHAR( 30),
      @tFedexLabelList           VariableTable

   SET @cDropID = ISNULL(@cParam1, '')

   IF TRIM(@cDropID) = ''
   BEGIN
      SET @nErrNo = 222951
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNoNeeded
      GOTO Quit
   END

   SELECT 
      @cLabelPrinterGroup = Printer,
      @cPaperPrinter = Printer_Paper,
      @cFacility = Facility
   FROM RDT.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   INSERT INTO @tFedexLabelList (Variable, Value) 
   VALUES 
      ( '@cLabelNo', @cDropID)

   SET @cLabelName = 'SHIPLBL'

    -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinterGroup, @cPaperPrinter,
      @cLabelName, -- Report type
      @tFedexLabelList, -- Report params
      'rdt_593ECLLabel01',
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
      
   IF @nErrNo <> 0
   BEGIN
      GOTO Quit
   END

Fail:
   RETURN
Quit:

GO
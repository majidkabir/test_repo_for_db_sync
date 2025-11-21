SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593SKULabel08                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 05-01-2020 1.0  YeeKung   WMS-16444 Created                             */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593SKULabel08] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- SKU
   @cParam2    NVARCHAR(20),  -- SKUPRICE
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success     INT
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cPrice         INT
   DECLARE @cFacility      NVARCHAR( 20)
   DECLARE @cReportType    NVARCHAR( 20)

   DECLARE @nNoofCopy      INT

   DECLARE @tSKULabel AS VariableTable


   SELECT @cReportType=code2
   FROM codelkup (NOLOCK)
   WHERE listname='RDTLBLRPT'
   AND storerkey=@cStorerKey
   AND code=@cOption

   select  @cSKU=S.SKU,
           @cPrice=S.Price
   from  SKU S(nolock) 
   where S.StorerKey=@cstorerkey 
   and S.SKU = @cParam1 


   -- Get login info
   SELECT 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper, 
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF ISNULL(@cParam2,'')=''
   BEGIN
      SET @cParam2='1'
   END

   INSERT INTO @tSKULabel (Variable, Value) VALUES 
      ( '@cSKU',       @cSKU), 
      ( '@cPrice',     @cPrice),
      ( '@cNoofcopy', @cParam2)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
      @cReportType, -- Report type
      @tSKULabel, -- Report params
      'rdt_593SKULabel08', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT

   IF @nErrNo <> 0
      GOTO Quit
   
Quit:


GO
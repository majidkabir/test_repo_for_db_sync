SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_803PrintLabel01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 13-08-2020 1.0  Chermaine   WMS-14683 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_803PrintLabel01] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cStation     NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1)
   ,@cOrderKey    NVARCHAR( 10)
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @tPrintLabelParam AS VariableTable     

   SET @nErrNo = 0 

   SELECT     
   @cLabelPrinter = Printer,   
   @cPaperPrinter = Printer_Paper   
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile
      
   SELECT * FROM pickDetail WITH (NOLOCK) WHERE storerKey = @cStorerKey AND orderKey = @cOrderKey AND caseID <> 'SORTED'
   
   IF @@ROWCOUNT > 0 
   BEGIN
      GOTO QUIT 
   END 
   ELSE 
   BEGIN
      INSERT INTO @tPrintLabelParam (Variable, Value) VALUES 
          ( '@sourcekey',     @cOrderkey)
          
      -- Print label  
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
         'IKPTLP', -- Report type  
         @tPrintLabelParam,  -- Report params  
         'rdt_803PrintLabel01',   
         @nErrNo  OUTPUT,  
         @cErrMsg  OUTPUT  
   
         
      IF @nErrNo <> 0  
         GOTO Quit  
   END 
      
Quit:
END

GO
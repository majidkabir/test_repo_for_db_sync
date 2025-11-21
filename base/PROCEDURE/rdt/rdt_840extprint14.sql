SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint14                                   */
/* Purpose: Print carton label for each carton                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-09-30 1.0  James      WMS-14993. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPrint14] (
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

   DECLARE @cPaperPrinter     NVARCHAR( 10),
           @cLabelPrinter     NVARCHAR( 10),
           @cUserName         NVARCHAR( 18),
           @cCartonLabel      NVARCHAR( 10),
           @cFacility         NVARCHAR( 5),
           @cDocType          NVARCHAR( 1),
           @cShippLabel       NVARCHAR( 10)

   DECLARE @tCartonLabel   VariableTable
   DECLARE @tShippLabel    VariableTable
   
   SELECT @cLabelPrinter = Printer,
          @cFacility = Facility,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         SELECT @cDocType = DocType
         FROM dbo.Orders WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey
      
         IF @cDocType = 'N'
         BEGIN
            SET @cCartonLabel = rdt.RDTGetConfig( @nFunc, 'CARTONLBL', @cStorerkey)  
            IF @cCartonLabel = '0'  
               SET @cCartonLabel = ''  

            IF @cCartonLabel <> ''
            BEGIN
              INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cPickSlipNo',     @cPickSlipNo)  
              INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)
              INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)
           
              -- Print label  
              EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',   
                 @cCartonLabel, -- Report type  
                 @tCartonLabel, -- Report params  
                 'rdt_840ExtPrint14',   
                 @nErrNo  OUTPUT,  
                 @cErrMsg OUTPUT  
            END
         END

         IF @cDocType = 'E'
         BEGIN
            SET @cShippLabel = rdt.RDTGetConfig( @nFunc, 'SHIPPLABEL', @cStorerkey)  
            IF @cShippLabel = '0'  
               SET @cShippLabel = ''  
            
            IF @cShippLabel <> ''
            BEGIN
               INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)
               INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)
               INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)

              -- Print label  
              EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',   
                 @cShippLabel, -- Report type  
                 @tShippLabel, -- Report params  
                 'rdt_840ExtPrint14',   
                 @nErrNo  OUTPUT,  
                 @cErrMsg OUTPUT  
            END
         END
      END   -- IF @nStep = 4
   END   -- @nInputKey = 1

Quit:

GO
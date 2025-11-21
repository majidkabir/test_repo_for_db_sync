SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_840ExtPrint17                                   */  
/* Purpose: Print carton label                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-07-23 1.0  James      WMS-17435. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_840ExtPrint17] (  
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
           @cFacility         NVARCHAR( 5),  
           @cShippLabel       NVARCHAR( 10),  
           @cPrtInvoice       NVARCHAR( 10),  
           @nExpectedQty      INT = 0,  
           @nPackedQty        INT = 0  
             
  
   DECLARE @tShippLabel    VariableTable  
   DECLARE @tPrtInvoice    VariableTable  
     
   SELECT @cLabelPrinter = Printer,  
          @cPaperPrinter = Printer_Paper,  
          @cFacility = Facility,  
          @cUserName = UserName  
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 4  
      BEGIN  
         SET @cShippLabel = rdt.RDTGetConfig( @nFunc, 'SHIPPLABEL', @cStorerkey)    
         IF @cShippLabel = '0'    
            SET @cShippLabel = ''    
  
         IF @cShippLabel <> ''  
         BEGIN  
            INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)    
            INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)  
            INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)  
             
            -- Print label    
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',     
               @cShippLabel, -- Report type    
               @tShippLabel, -- Report params    
               'rdt_840ExtPrint17',     
               @nErrNo  OUTPUT,    
               @cErrMsg OUTPUT    
         END  
      END   -- IF @nStep = 4  
   END   -- @nInputKey = 1  
  
Quit:  

GO
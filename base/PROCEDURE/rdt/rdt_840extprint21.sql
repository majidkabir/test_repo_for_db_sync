SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_840ExtPrint21                                   */  
/* Purpose: Print carton label                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2022-03-18 1.0  James      WMS-19123. Created                        */  
/* 2022-06-15 1.1  James      WMS-19935 Last Carton of the order only   */
/*                            print packing list (james01)              */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_840ExtPrint21] (  
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
           @cShipLabel        NVARCHAR( 10),  
           @cPackList         NVARCHAR( 10),
           @nExpectedQty      INT = 0,
           @nPackedQty        INT = 0

  
   DECLARE @tShipLabel     VariableTable  
   DECLARE @tPackList      VariableTable  
     
   SELECT @cLabelPrinter = Printer,  
          @cPaperPrinter = Printer_Paper
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 4  
      BEGIN  
         SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'SHIPLABEL', @cStorerkey)    
         IF @cShipLabel = '0'    
            SET @cShipLabel = ''    
  
         IF @cShipLabel <> ''  
         BEGIN  
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cPickSlipNo',    @cPickSlipNo)    
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@nCartonNoFrom',  @nCartonNo)  
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@nCartonNoTo',    @nCartonNo)  
             
            -- Print label    
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',     
               @cShipLabel, -- Report type    
               @tShipLabel, -- Report params    
               'rdt_840ExtPrint21',     
               @nErrNo  OUTPUT,    
               @cErrMsg OUTPUT    
         END  
         
         -- (james01)
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey
            AND Storerkey = @cStorerkey
            AND Status < '9'

         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         IF @nExpectedQty > @nPackedQty
            GOTO Quit
            
         SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PACKLIST', @cStorerkey)    
         IF @cPackList = '0'    
            SET @cPackList = ''    
  
         IF @cPackList <> ''  
         BEGIN  
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)  
             
            -- Print label    
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,     
               @cPackList, -- Report type    
               @tPackList, -- Report params    
               'rdt_840ExtPrint21',     
               @nErrNo  OUTPUT,    
               @cErrMsg OUTPUT    
         END  
      END   -- IF @nStep = 4  
   END   -- @nInputKey = 1  
  
Quit:  

GO
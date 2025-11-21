SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint25                                   */
/* Purpose: Print label after carton closed                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-11-17 1.0  James      WMS-18321. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtPrint25] (
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
           @nExpectedQty      INT,
           @nPackedQty        INT,
           @cShipLabel        NVARCHAR( 10),
           @cReturnLabel      NVARCHAR( 10),
           @cPackList         NVARCHAR( 10),
           @cFacility         NVARCHAR( 5),
           @cLoadKey          NVARCHAR( 10),
           @cLabelNo          NVARCHAR( 20)

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         SELECT @cLoadKey = LoadKey
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         SET @nExpectedQty = 0
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey
         AND   Storerkey = @cStorerkey
         AND   Status < '9'

         SET @nPackedQty = 0
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         IF @nExpectedQty = @nPackedQty  
         BEGIN  
            SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)  
            IF @cPackList = '0'  
               SET @cPackList = ''  
           
            IF @cPackList <> ''  
            BEGIN  
               DECLARE @tPackList AS VariableTable  
               INSERT INTO @tPackList (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)  
               INSERT INTO @tPackList (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)  
               INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)  
  
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter,   
                  @cPackList, -- Report type  
                  @tPackList, -- Report params  
                  'rdt_840ExtPrint25',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT   
  
               IF @nErrNo <> 0  
                  GOTO Quit                   
            END  
         END  
      END   -- IF @nStep = 4
   END   -- @nInputKey = 1

Quit:

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint12                                   */
/* Purpose: Print label after carton closed                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-07-05 1.0  James      WMS-13913. Created                        */
/* 2022-10-19 1.1  James      WMS-20992 Add print carton DN (james01)   */
/* 2023-07-26 1.2  James      WMS-23151 Skip label printing if label    */
/*                            alreadt printed (james02)                 */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtPrint12] (
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
           @cLabelNo          NVARCHAR( 20),
           @cCartonDN         NVARCHAR( 10),
           @nSkiZplPrint      INT = 0

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
                  'rdt_840ExtPrint12',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT   
  
               IF @nErrNo <> 0  
                  GOTO Quit                   
            END  
         END  

         IF ISNULL( @nCartonNo, 0) = 0
            SELECT @nCartonNo = V_Cartonno
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

         IF EXISTS ( SELECT 1
                     FROM dbo.TRANSMITLOG2 WITH (NOLOCK)
                     WHERE TableName = 'WSCRSOADDMP'
                     AND   key1 = @cOrderKey
                     AND   key2 = @nCartonNo
                     AND   key3 = @cStorerkey)
            SET @nSkiZplPrint = 1

         SELECT @cLabelNo = LabelNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo
                  
         SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'SHIPZPLLBL', @cStorerKey)  
         IF @cShipLabel = '0'  
            SET @cShipLabel = ''  
               
         IF @cShipLabel <> '' AND @nSkiZplPrint = 0
         BEGIN
            DECLARE @tShipLabel AS VariableTable  
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLabelNo',     @cLabelNo)  
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)  
   
            -- Print label  
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',   
               @cShipLabel, -- Report type  
               @tShipLabel, -- Report params  
               'rdt_840ExtPrint12',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT   
  
            IF @nErrNo <> 0  
               GOTO Quit                   
         END

         SET @cReturnLabel = rdt.RDTGetConfig( @nFunc, 'RTNZPLLBL', @cStorerKey)  
         IF @cReturnLabel = '0'  
            SET @cReturnLabel = ''  
               
         IF @cReturnLabel <> '' AND @nSkiZplPrint = 0
         BEGIN
            DECLARE @tReturnLabel AS VariableTable  
            INSERT INTO @tReturnLabel (Variable, Value) VALUES ( '@cLabelNo',     @cLabelNo)  
            INSERT INTO @tReturnLabel (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)  
   
            -- Print label  
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',   
               @cReturnLabel, -- Report type  
               @tReturnLabel, -- Report params  
               'rdt_840ExtPrint12',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT   
  
            IF @nErrNo <> 0  
               GOTO Quit                   
         END

         SET @cCartonDN = rdt.RDTGetConfig( @nFunc, 'CARTONDN', @cStorerKey)  
         IF @cCartonDN = '0'  
            SET @cCartonDN = ''  

         IF @cCartonDN <> ''
         BEGIN
            DECLARE @tCartonDN AS VariableTable
            INSERT INTO @tCartonDN (Variable, Value) VALUES ( '@cLabelNo',    @cLabelNo)
            INSERT INTO @tCartonDN (Variable, Value) VALUES ( '@cOrderKey',   @cOrderKey)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
               @cCartonDN, -- Report type
               @tCartonDN, -- Report params
               'rdt_840ExtPrint12', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 
         END
         
            
      END   -- IF @nStep = 4
   END   -- @nInputKey = 1

Quit:

GO
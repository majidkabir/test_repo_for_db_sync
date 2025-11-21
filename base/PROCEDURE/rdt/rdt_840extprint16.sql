SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint16                                   */
/* Purpose: Print carton label                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-05-07 1.0  James      WMS-16955. Created                        */
/* 2021-08-05 1.1  James      WMS-17645 Add no of copy (james01)        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPrint16] (
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
           @nPackedQty        INT = 0,
           @nNoOfCopy         INT = 0,
           @cNoOfCopy         NVARCHAR( 2),
           @cShipperKey       NVARCHAR( 15)

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
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey
            AND Storerkey = @cStorerkey
            AND Status < '9'

         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         IF @nExpectedQty > @nPackedQty
            GOTO Quit

         SET @cShippLabel = rdt.RDTGetConfig( @nFunc, 'SHIPPLABEL', @cStorerkey)  
         IF @cShippLabel = '0'  
            SET @cShippLabel = ''  

         IF @cShippLabel <> ''
         BEGIN
            SELECT @cShipperKey = ShipperKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            
            SELECT @cNoOfCopy = Short
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'SHIPMETHOD'
            AND   Code = @cShipperKey
            AND   Storerkey = @cStorerkey
            
            -- If no setup, default print copy to 1 (james01)
            IF ISNULL( @cNoOfCopy, '') = '' OR @cNoOfCopy = '0' OR rdt.rdtIsValidQTY( @cNoOfCopy, 0) = 0
               SET @nNoOfCopy = 1
            ELSE
               SET @nNoOfCopy = CAST( @cNoOfCopy AS INT)
               
            INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@cOrderkey',     @cOrderkey)  
            
            WHILE @nNoOfCopy > 0
            BEGIN
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',   
                  @cShippLabel, -- Report type  
                  @tShippLabel, -- Report params  
                  'rdt_840ExtPrint16',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT
               
               SET @nNoOfCopy = @nNoOfCopy - 1
            END  
         END

         SET @cPrtInvoice = rdt.RDTGetConfig( @nFunc, 'PrtInvoice', @cStorerkey)  
         IF @cPrtInvoice = '0'  
            SET @cPrtInvoice = ''  

         IF @cPrtInvoice <> ''
         BEGIN
            INSERT INTO @tPrtInvoice (Variable, Value) VALUES ( '@cOrderkey',     @cOrderkey)  
           
            -- Print label  
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,  
               @cPrtInvoice, -- Report type  
               @tPrtInvoice, -- Report params  
               'rdt_840ExtPrint16',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT  
         END
      END   -- IF @nStep = 4
   END   -- @nInputKey = 1

Quit:

GO
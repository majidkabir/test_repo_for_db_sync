SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_840ExtPrint04                                   */
/* Purpose: Print label after pick = pack                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2018-08-24 1.0  James      WMS6095. Created                          */
/* 2018-12-03 1.1  James      WMS7181. Change shipping label reporttype */
/*                            from SHIPPLABEL to SHIPLBLCOS (james01)   */
/*                            Skip print delnotes if doctype <> 'E'     */
/* 2019-09-07 1.2  James      Change Long -> UDF01 (james01)            */
/* 2020-05-18 1.3  James      WMS-13200 Add invoice printing (james02)  */
/* 2020-07-17 1.4  James      WMS-14320 Add more Delnotes print         */
/*                            condition   (james03)                     */
/* 2021-01-27 1.5  James      WMS-16145 Add carton label print (james04)*/
/* 2021-04-16 1.6  James      WMS-16024 Standarized use of TrackingNo   */
/*                            (james05)                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPrint04] (
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
           @cLoadKey          NVARCHAR( 10),
           @cShipperKey       NVARCHAR( 10),
           @cFacility         NVARCHAR( 5),
           @nExpectedQty      INT,
           @nPackedQty        INT,
           @nIsMoveOrder      INT,
           @cDocType          NVARCHAR( 1),
           @cOrderGroup       NVARCHAR( 20),  -- (james02)
           @cPrtInvoice       NVARCHAR( 10),  -- (james03)
           @cTrackingNo       NVARCHAR( 30),  -- (james04)
           @cUserDefine03     NVARCHAR( 20),  -- (james03)
           @cUDF02            NVARCHAR( 60),  -- (james03)
           @cCartonLabel      NVARCHAR( 10)   -- (james04)

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep IN ( 3, 4)
      BEGIN
         -- 1 orders 1 tracking no
         -- discrete pickslip, 1 ordes 1 pickslipno
         SET @nExpectedQty = 0
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey
            AND Storerkey = @cStorerkey
            AND Status < '9'

         SET @nPackedQty = 0
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND Storerkey = @cStorerkey

         -- all SKU and qty has been packed, Update the carton barcode to the PackDetail.UPC for each carton
         IF @nExpectedQty = @nPackedQty
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)
                        JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Userdefine03 AND C.StorerKey = O.StorerKey)
                        WHERE C.ListName = 'HMCOSORD'
                        AND   C.UDF01 = 'M'
                        AND   O.OrderKey = @cOrderkey
                        AND   O.StorerKey = @cStorerKey)
               SET @nIsMoveOrder = 1
            ELSE
               SET @nIsMoveOrder = 0

            SELECT @cLoadKey = ISNULL(RTRIM(LoadKey), ''),
                   @cShipperKey = ISNULL(RTRIM(ShipperKey), ''),
                   @cDocType = DocType, 
                   @cOrderGroup = OrderGroup,      -- (james02)
                   --@cTrackingNo = UserDefine04,    -- (james02)
                   @cTrackingNo = TrackingNo,    -- (james05)
                   @cUserDefine03 = UserDefine03   -- (james03)
            FROM dbo.Orders WITH (NOLOCK)
            WHERE Storerkey = @cStorerkey
            AND   Orderkey = @cOrderkey

            SELECT @cUDF02 = UDF02
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE ListName = 'HMCOSORD' 
            AND   Code = @cUserDefine03 
            AND   Storerkey = @cStorerkey

            IF @nIsMoveOrder = 0 -- Move order no need print ship label
            BEGIN
               DECLARE @tSHIPPLABEL AS VariableTable
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',  @cShipperKey)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nQty',         0)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                  'SHIPLBLCOS', -- Report type
                  @tSHIPPLABEL, -- Report params
                  'rdt_840ExtPrint04', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 
            END

            IF @cDocType = 'E' AND @cUDF02 <> 'N'
            BEGIN
               DECLARE @tDELNOTES AS VariableTable
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     '')
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cType',        '')

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
                  'DELNOTES', -- Report type
                  @tDELNOTES, -- Report params
                  'rdt_840ExtPrint04', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 
            END
            
            -- (james02)
            SET @cPrtInvoice = rdt.RDTGetConfig( @nFunc, 'PrtInvoice', @cStorerKey) 
            IF @cPrtInvoice = '0'
               SET @cPrtInvoice = ''
            
            IF @cPrtInvoice <> ''
            BEGIN
               IF @cOrderGroup = '1'
               BEGIN
                  DECLARE @tPRTINVOICE AS VariableTable
                  INSERT INTO @tPRTINVOICE (Variable, Value) VALUES ( '@cLoadKey',      @cLoadKey)
                  INSERT INTO @tPRTINVOICE (Variable, Value) VALUES ( '@cOrderKey',     @cOrderKey)
                  INSERT INTO @tPRTINVOICE (Variable, Value) VALUES ( '@cTrackingNo',   @cTrackingNo)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
                     @cPrtInvoice,  -- Report type
                     @tPRTINVOICE, -- Report params
                     'rdt_840ExtPrint04', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT 
               END
            END
         END

         -- (james04)
         IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                     WHERE OrderKey = @cOrderKey
                     AND   UserDefine03 = 'MOVE')
         BEGIN
            SET @cCartonLabel = rdt.RDTGetConfig( @nFunc, 'CartonLbl', @cStorerKey)
            IF @cCartonLabel = '0'
               SET @cCartonLabel = ''

            IF @cCartonLabel <> ''
            BEGIN
               DECLARE @tCartonLabel AS VariableTable
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)  
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)  
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)     
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)     
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)    

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
                  @cCartonLabel, -- Report type
                  @tCartonLabel, -- Report params
                  'rdt_840ExtPrint0', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 
            END
         END
      END   -- IF @nStep = 3
   END   -- @nInputKey = 1

Quit:

GO
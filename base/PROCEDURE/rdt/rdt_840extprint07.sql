SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_840ExtPrint07                                   */  
/* Purpose: Print label after pick = pack                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-11-19 1.0  James      WMS-11146. Created                        */  
/* 2020-02-11 1.1  Grick      Fixed for packlist is null  (G01)         */  
/* 2022-10-03 1.2  James      WMS-20788 Change shiplabel config name    */
/*                            to shipplabel (james01)                   */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_840ExtPrint07] (  
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
           @cShippLabel       NVARCHAR( 10),  
           @cPackList         NVARCHAR( 10),  
           @nShortPack        INT = 0,  
           @nOriginalQty      INT = 0,  
           @nPackQty          INT = 0  
  
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
         SELECT @nOriginalQty = ISNULL( SUM( OriginalQty), 0)    
         FROM dbo.Orders O WITH (NOLOCK)    
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON ( O.OrderKey = OD.OrderKey)    
         WHERE O.OrderKey = @cOrderKey    
         AND   O.StorerKey = @cStorerkey    
    
         SELECT @nPackQty = ISNULL( SUM( QTY), 0)    
         FROM dbo.PackDetail PD WITH (NOLOCK)    
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)    
         WHERE PH.OrderKey = @cOrderKey             
         AND   PH.StorerKey = @cStorerkey    
    
         -- Compare packed qty to order qty to check if short qty    
         IF @nOriginalQty > @nPackQty        
            SET @nShortPack = 1    
              
         -- all SKU and qty has been packed  
         IF @nShortPack <> 1    
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
                   @cDocType = DocType  
            FROM dbo.Orders WITH (NOLOCK)  
            WHERE Storerkey = @cStorerkey  
            AND   Orderkey = @cOrderkey  
  
            SET @cShippLabel = rdt.RDTGetConfig( @nFunc, 'ShippLabel', @cStorerKey)  
            IF @cShippLabel = '0'  
               SET @cShippLabel = ''  
        
            SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)  --G01  
            IF @cPackList = '0'  
               SET @cPackList = ''  
        
            IF @nIsMoveOrder = 0 -- Move order no need print ship label  
            BEGIN  
               IF @cShippLabel <> ''  
               BEGIN  
                  DECLARE @tSHIPPLABEL AS VariableTable  
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)  
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)  
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',  @cShipperKey)  
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nQty',         0)  
  
                  -- Print label  
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',   
                     @cShippLabel, -- Report type  
                     @tSHIPPLABEL, -- Report params  
                     'rdt_840ExtPrint07',   
                     @nErrNo  OUTPUT,  
                     @cErrMsg OUTPUT   
               END  
            END  
  
            IF @cDocType = 'E'  
            BEGIN  
               IF @cPackList <> ''  
               BEGIN  
                  DECLARE @tDELNOTES AS VariableTable  
                  INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)  
                  INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     '')  
                  INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cType',        '')  
  
                  -- Print label  
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter,   
                     @cPackList, -- Report type  
                     @tDELNOTES, -- Report params  
                     'rdt_840ExtPrint07',   
                     @nErrNo  OUTPUT,  
                     @cErrMsg OUTPUT   
               END  
            END  
         END  
      END   -- IF @nStep = 3  
   END   -- @nInputKey = 1  
  
Quit:  

GO
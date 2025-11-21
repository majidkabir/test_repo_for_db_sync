SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_840ExtValid09                                   */  
/* Purpose: Validate carton weight                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-07-05 1.0  James      WMS-13913. Created                        */  
/* 2021-04-01 1.1  YeeKung    WMS-16717 Add serialno and serialqty      */  
/*                            Params (yeekung01)                        */  
/* 2021-12-23 1.2  James      WMS-18321 Prevent scan orderkey (james01) */  
/* 2022-05-19 1.3  YeeKung    WMS-19442 Based by ecomtype (yeekung01)   */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_840ExtValid09] (  
   @nMobile                   INT,  
   @nFunc                     INT,  
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,  
   @nInputKey                 INT,   
   @cStorerkey                NVARCHAR( 15),  
   @cOrderKey                 NVARCHAR( 10),  
   @cPickSlipNo               NVARCHAR( 10),  
   @cTrackNo                  NVARCHAR( 20),  
   @cSKU                      NVARCHAR( 20),  
   @nCartonNo                 INT,  
   @cCtnType                  NVARCHAR( 10),  
   @cCtnWeight                NVARCHAR( 10),  
   @cSerialNo                 NVARCHAR( 30),   
   @nSerialQTY                INT,             
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)  
AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @cWeightChk     NVARCHAR( 10)  
   DECLARE @cWeightMax     NVARCHAR( 5)  
   DECLARE @cWeightMin     NVARCHAR( 5)  
   DECLARE @cShipperKey    NVARCHAR( 15)  
   DECLARE @cOrdType       NVARCHAR( 10)  
   DECLARE @cErrMsg1       NVARCHAR( 20)  
   DECLARE @cPmtTerm       NVARCHAR( 10)  
   DECLARE @fCtnWeight        FLOAT  
   DECLARE @fBoxWeight        FLOAT  
   DECLARE @fSTDGrossWeight   FLOAT  
   DECLARE @cInField01        NVARCHAR( 60)  
     
   SET @nErrNo = 0  
  
   IF @nStep = 1  
   BEGIN  
      SELECT @cInField01 = I_Field01
      FROM rdt.RDTMOBREC WITH (NOLOCK)  
      WHERE Mobile = @nMobile  


        
      IF ISNULL( @cInField01, '') <> ''  
      BEGIN  
         IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK)
                     WHERE ORDERKEY=@cInField01
                     AND storerkey=@cStorerkey
                     AND DocType='E')
         BEGIN
            SET @nErrNo = 154604  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'DropID Only'  
            GOTO Quit    
         END
      END  
        
      -- If it is Sales type order check carton type exists  
      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)   
                  JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)  
                  WHERE C.ListName = 'HMORDTYPE'  
                  AND   C.Short = 'S'  
                  AND   O.OrderKey = @cOrderkey  
                  AND   O.StorerKey = @cStorerKey)  
      BEGIN  
         SELECT @cPickSlipNo = PickHeaderKey  
         FROM dbo.PICKHEADER WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
        
         SET @cCtnType = ''  
  
         SELECT TOP 1 @cCtnType = CartonType   
         FROM dbo.PackInfo WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
         ORDER BY 1  
        
         IF ISNULL( @cCtnType, '') = ''  
         BEGIN        
            SET @nErrNo = 154603  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'Label Not RCVD'  
            GOTO Quit        
         END   
      END  
   END  
     
   IF @nStep = 4  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         SELECT @cShipperKey = ShipperKey,  
                @cOrdType = [Type],   
                @cPmtTerm = PmtTerm  
         FROM dbo.ORDERS WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
           
         SELECT @cWeightChk = UDF04   
         FROM dbo.CODELKUP WITH (NOLOCK)  
  WHERE ListName = 'HMCOURIER'  
         AND   Storerkey = @cStorerkey  
         AND   Code = @cShipperKey  
         AND   Long = @cOrdType  
         AND   UDF01 = @cPmtTerm  
           
         IF ISNULL( @cWeightChk, '') <> '' AND CHARINDEX( '_', @cWeightChk) > 0  
         BEGIN  
            SELECT @cWeightMin = LEFT( @cWeightChk, CHARINDEX( '_', @cWeightChk) - 1)  
            SELECT @cWeightMax = RIGHT( @cWeightChk, CHARINDEX( '_', @cWeightChk) - 1)  
              
            SELECT @fCtnWeight = CartonWeight   
            FROM dbo.CARTONIZATION CZ WITH (NOLOCK)   
            JOIN dbo.STORER ST WITH (NOLOCK) ON ( CZ.CartonizationGroup = ST.CartonGroup)  
            WHERE CartonType = @cCtnType  
              
            SELECT @fSTDGrossWeight = ISNULL( SUM( SKU.STDGROSSWGT * PD.Qty), 0)  
            FROM dbo.PackDetail PD WITH (NOLOCK)  
            JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.Sku)  
            WHERE PickSlipNo = @cPickSlipNo  
            AND   PD.CartonNo = @nCartonNo  
              
            SET @fBoxWeight = @fCtnWeight + @fSTDGrossWeight  
            --SELECT @fCtnWeight '@fCtnWeight', @fSTDGrossWeight '@fSTDGrossWeight', @fBoxWeight '@fBoxWeight'  
            --SELECT @cWeightMin '@cWeightMin', @cWeightMax '@cWeightMax'  
            IF @fBoxWeight >= CAST( @cWeightMin AS FLOAT) AND  
               @fBoxWeight < CAST( @cWeightMax AS FLOAT)   
            BEGIN  
               SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 154601, @cLangCode, 'DSP'), 7, 14) --Heavy Box  
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1   
               SET @nErrNo = 0  
               SET @cErrMsg = ''  
               GOTO Quit  
            END  
              
            IF @fBoxWeight > CAST( @cWeightMax AS FLOAT)   
            BEGIN  
               SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 154602, @cLangCode, 'DSP'), 7, 14) --Over Weight  
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1   
               SET @nErrNo = 154602  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over Weight'  
               GOTO Quit  
            END  
         END  
      END     
   END  
     
  
  
Quit:  

GO
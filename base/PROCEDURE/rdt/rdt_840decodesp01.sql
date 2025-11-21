SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840DecodeSP01                                   */
/* Copyright      : MAERSK                                              */
/*                                                                      */
/* Purpose: Return orders using pickdetail.dropid                       */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2020-08-24  1.0  James       WMS-13913. Created                      */
/* 2021-05-31  1.1  James       WMS-16580 Output pickslipno (james01)   */
/* 2021-06-24  1.2  James       WMS-17200 Exclude CaseID checking for   */
/*                              Move orders (james02)                   */
/* 2021-04-01  1.3 YeeKung      WMS-16717 Add serialno and serialqty    */
/*                              Params (yeekung01)                      */
/* 2024-09-06  1.4  James       Rearrange Pickslip output param(james03)*/
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_840DecodeSP01
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cBarcode     NVARCHAR( 2000),
   @cDropID      NVARCHAR( 20),
   @cOrderKey    NVARCHAR( 10)  OUTPUT,
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @cTrackingNo  NVARCHAR( 20)  OUTPUT,
   @cLottable01  NVARCHAR( 18)  OUTPUT,
   @cLottable02  NVARCHAR( 18)  OUTPUT,
   @cLottable03  NVARCHAR( 18)  OUTPUT,
   @cLottable04  DATETIME  OUTPUT,
   @cLottable05  DATETIME  OUTPUT,
   @cLottable06  NVARCHAR( 30)  OUTPUT,
   @cLottable07  NVARCHAR( 30)  OUTPUT,
   @cLottable08  NVARCHAR( 30)  OUTPUT,
   @cLottable09  NVARCHAR( 30)  OUTPUT,
   @cLottable10  NVARCHAR( 30)  OUTPUT,
   @cLottable11  NVARCHAR( 30)  OUTPUT,
   @cLottable12  NVARCHAR( 30)  OUTPUT,
   @cLottable13  DATETIME  OUTPUT,
   @cLottable14  DATETIME  OUTPUT,
   @cLottable15  DATETIME  OUTPUT, 
   @cSerialNo    NVARCHAR(30)  OUTPUT,  
   @nSerialQTY   INT            OUTPUT,   
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT,
   @cPickSlipNo  NVARCHAR( 10)  OUTPUT  

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nLblLength              INT,
           @cTempOrderKey           NVARCHAR( 10),       
           @cTempSKU                NVARCHAR( 20),
           @cTempLottable02         NVARCHAR( 18),
           @cShowErrMsgInNewScn     NVARCHAR( 1),       
           @cDecodeUCCNo            NVARCHAR( 1),
           @cTempPickSlipNo         NVARCHAR( 10),
           @nIsMoveOrders           INT = 0 
   
   SET @nErrNo = 0
            
   IF @nStep = 3 -- SKU
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cDecodeUCCNo = rdt.RDTGetConfig( @nFunc, 'DecodeUCCNo', @cStorerkey)      
      
         IF @cDecodeUCCNo = '1'      
            SET @cBarcode = RIGHT( @cBarcode, LEN(@cBarcode) - 2)      
      
         SET @cShowErrMsgInNewScn = rdt.RDTGetConfig( @nFunc, 'ShowErrMsgInNewScn', @cStorerkey)      
         IF @cShowErrMsgInNewScn = '0'      
            SET @cShowErrMsgInNewScn = ''            

         SET @nLblLength = 0      
         SET @nLblLength = LEN( ISNULL( RTRIM( @cBarcode),''))      
      
         IF @nLblLength = 0 OR @nLblLength > 29      
         BEGIN     
            SET @nErrNo = 157501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'Invalid SKU'
            GOTO Quit      
         END      
         
         SET @cTempSKU = SUBSTRING( RTRIM( @cBarcode), 3, 13) -- SKU      
         SET @cTempLottable02 = SUBSTRING( RTRIM( @cBarcode), 16, 12) -- Lottable02      
         SET @cTempLottable02 = RTRIM( @cTempLottable02) + '-' -- Lottable02      
         SET @cTempLottable02 = RTRIM( @cTempLottable02) + SUBSTRING( RTRIM( @cBarcode), 28, 2) -- Lottable02      

         IF ISNULL( @cDropID, '') = ''  -- User scan orderkey
         BEGIN
            SET @cTempOrderKey = @cOrderKey
            SET @cTempPickSlipNo = @cPickslipNo  

            IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)       
                              WHERE StorerKey = @cStorerkey      
                              AND   OrderKey = @cTempOrderKey      
                              AND   SKU = @cTempSKU      
                              AND   [Status] < '9')      
            BEGIN      
               SET @nErrNo = 157502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'Invalid SKU'
               GOTO Quit      
            END      
            
            IF NOT EXISTS ( SELECT 1 FROM dbo.LotAttribute WITH (NOLOCK)     
                              WHERE StorerKey = @cStorerKey    
                              AND   SKU = @cTempSKU    
                              AND   Lottable02 = @cTempLottable02)    
            BEGIN    
               SELECT TOP 1 @cTempLottable02 = LA.Lottable02    
               FROM dbo.PICKDETAIL PD WITH (NOLOCK)     
               JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( PD.Lot = LA.Lot)    
               WHERE PD.Storerkey = @cStorerkey    
               AND   PD.OrderKey = @cTempOrderKey    
               AND   PD.Sku = @cTempSKU    
               AND   PD.[Status] < '9'    
               ORDER BY 1    
          
               IF @@ROWCOUNT = 0    
               BEGIN    
                  SET @nErrNo = 157503
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'Invalid Lot02'
                  GOTO Quit    
               END    
            END    
         END      
         ELSE
         BEGIN
            SELECT TOP 1 @cTempOrderKey = PD.OrderKey
            FROM dbo.PICKDETAIL PD WITH (NOLOCK)
            JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( PD.Lot = LA.Lot)
            WHERE PD.Storerkey = @cStorerKey
            AND   PD.SKU = @cTempSKU
            AND   PD.[Status] < '9'
            AND   pd.DropID = @cDropID
            AND   LA.Lottable02 = @cTempLottable02
            ORDER BY 1
            
            IF ISNULL( @cTempOrderKey, '') = ''
            BEGIN      
               SET @nErrNo = 157504
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'No OrderKey'  
               GOTO Quit        
            END  
  
            SELECT @cTempPickSlipNo = PickHeaderKey  
            FROM dbo.PICKHEADER WITH (NOLOCK)  
            WHERE OrderKey = @cTempOrderKey  
  
            IF ISNULL( @cTempPickSlipNo, '') = ''  
            BEGIN        
               SET @nErrNo = 157505  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'No PickSlip No'  
               GOTO Quit      
            END 
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                     WHERE OrderKey = @cTempOrderKey
                     AND   DocType = 'N'
                     AND   ConsigneeKey LIKE 'W%')
            SET @nIsMoveOrders = 1

         IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)  
                     WHERE OrderKey = @cTempOrderKey  
                     AND   ISNULL( CaseID, '') = '') AND @nIsMoveOrders = 0 -- move orders skip checking
         BEGIN        
            SET @nErrNo = 157506  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') + @cTempOrderKey  --'No Lbl'  
            GOTO Quit        
         END   
         
         SET @cOrderKey = @cTempOrderKey
         SET @cSKU = @cTempSKU      
         SET @cLottable02 = @cTempLottable02      
         SET @cPickslipNo = @cTempPickSlipNo  
      END
   END

Quit:
END

GO
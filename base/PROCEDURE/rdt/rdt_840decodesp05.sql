SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840DecodeSP05                                   */
/* Copyright      : LF logistics                                        */
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
/* 2022-11-04  1.4  James       WMS-21055 Add Qty output (james03)      */
/************************************************************************/

CREATE    PROCEDURE [RDT].[rdt_840DecodeSP05]
    @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cBarcode     NVARCHAR( 2000),
   @cDropID      NVARCHAR( 20),
   @cOrderKey    NVARCHAR( 10)  OUTPUT,
   @cPickslipNo  NVARCHAR( 10)  OUTPUT,
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
   @cErrMsg      NVARCHAR( 20)  OUTPUT  

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

         SET @cTempSKU = @cBarcode-- SUBSTRING( RTRIM( @cBarcode), 1, 20) -- SKU      

         SELECT TOP 1 @cTempOrderKey = PD.Orderkey,@cTempSKU = UPC.SKU    
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
         JOIN UPC UPC (NOLOCK) ON PD.SKU = UPC.SKU AND PD.Storerkey = UPC.Storerkey
         WHERE PD.Storerkey = @cStorerkey    
         AND   UPC.UPC = @cTempSKU    
         AND   PD.DropiD = @cDropID
         AND   PD.[Status] < '9'    
         ORDER BY 1    
            
      END      
         
      SET @cOrderKey = @cTempOrderKey
      SET @cSKU = @cTempSKU  
   END

Quit:
END

GO
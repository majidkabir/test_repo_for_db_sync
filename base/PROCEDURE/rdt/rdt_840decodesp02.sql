SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_840DecodeSP02                                      */
/* Copyright      : MAERSK                                                 */
/*                                                                         */
/* Purpose: decode serialno to sku                                         */
/*                                                                         */
/* Modifications log:                                                      */
/* Date        Rev  Author      Purposes                                   */
/* 2021-04-02  1.0  YeeKung     WMS-16717 Created                          */ 
/* 2024-09-06  1.1  James       Add Pickslip output during decode (james01)*/
/***************************************************************************/

CREATE   PROCEDURE rdt.rdt_840DecodeSP02
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cBarcode     NVARCHAR( 2000),
   @cDropID      NVARCHAR( 20),
   @cOrderKey    NVARCHAR( 18)  OUTPUT,
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @cTrackingNo  NVARCHAR( 18)  OUTPUT,
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
   @cSerialNo    NVARCHAR( 30)  OUTPUT,    
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
           @cDecodeUCCNo            NVARCHAR( 1)
   
   SET @nErrNo = 0
            
   IF @nStep = 3 -- SKU
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @cPickSlipNO=V_String4
         FROM rdt.rdtmobrec (NOLOCK)
         WHERE mobile=@nMobile


         SELECT  @cTempSKU=sku
         FROM dbo.SerialNo (NOLOCK)
         WHERE SerialNo=@cBarcode
         AND storerkey=@cStorerKey
          AND status <='1'

         IF ISNULL(@cTempSKU,'')=''
         BEGIN
            SET @cTempSKU=@cBarcode

            SELECT @nSerialQTY=1

         END
         ELSE
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.PackSerialNo (NOLOCK) WHERE serialno=@cBarcode AND storerkey=@cStorerKey and sku=@cTempSKU AND PickSlipNo=@cPickSlipNO)
            BEGIN
               SET @nErrNo = 165801   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidBarcode'  
               GOTO QUIT  
            END
            SET @cSerialNo=@cBarcode
         END

         SET @cSKU=@cTempSKU
      END
   END

Quit:
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608DecodeSP02                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode SKU                                                        */
/*                                                                            */
/* Called from: rdtfnc_PieceReturn                                            */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 25-09-2017  James     1.0   WMS-10122 Created                              */
/* 27-11-2019  James     1.1   Fix get sku from barcode (james01)             */
/* 05-08-2017  YeeKung   1.2   WMS-14415 Add Params (yeekung01)               */ 
/* 25-02-2021  Ung       1.3   INC1423399 Change map V_DropID to V_SerialNo   */
/******************************************************************************/

CREATE PROC [RDT].[rdt_608DecodeSP02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 60),
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nUCCQTY      INT            OUTPUT,
   @cUCCUOM      NVARCHAR( 6)   OUTPUT, --(yeekung01)
   @cLottable01  NVARCHAR( 18)  OUTPUT,
   @cLottable02  NVARCHAR( 18)  OUTPUT,
   @cLottable03  NVARCHAR( 18)  OUTPUT,
   @dLottable04  DATETIME       OUTPUT,
   @dLottable05  DATETIME       OUTPUT,
   @cLottable06  NVARCHAR( 30)  OUTPUT,
   @cLottable07  NVARCHAR( 30)  OUTPUT,
   @cLottable08  NVARCHAR( 30)  OUTPUT,
   @cLottable09  NVARCHAR( 30)  OUTPUT,
   @cLottable10  NVARCHAR( 30)  OUTPUT,
   @cLottable11  NVARCHAR( 30)  OUTPUT,
   @cLottable12  NVARCHAR( 30)  OUTPUT,
   @dLottable13  DATETIME       OUTPUT,
   @dLottable14  DATETIME       OUTPUT,
   @dLottable15  DATETIME       OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cTempSKU       NVARCHAR( 20)
   DECLARE @cTempBarcode   NVARCHAR( 60)
   DECLARE @nPosition   INT

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         --HTTP://TY.DOTERRA.CN/F0101DDGDQJDFDEFZ
         SET @cTempBarcode = @cBarcode
         --SET @nPosition = PATINDEX('%A%CN%', @cTempBarcode)
         --SET @cTempBarcode = RIGHT( @cTempBarcode, @nPosition)

         -- (james01)
         SET @cTempBarcode = REPLACE( @cBarcode, 'http://ty.doterra.cn/', '')  
            
         SELECT TOP 1 @cTempSKU = SKU
         FROM dbo.SerialNo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SerialNo = @cTempBarcode
         ORDER BY 1

         -- If cannot find in serialno then it might be sku
         IF @@ROWCOUNT = 0
         BEGIN
            SET @cTempSKU = @cBarcode

            UPDATE RDT.RDTMOBREC SET V_SerialNo = ''
            WHERE Mobile = @nMobile
         END
         ELSE
         BEGIN
            UPDATE RDT.RDTMOBREC SET V_SerialNo = @cTempBarcode
            WHERE Mobile = @nMobile
         END
      END
   END
   
   -- Return value
   IF @cTempSKU <> '' 
   BEGIN
      SET @cSKU = @cTempSKU
   END
   
Quit:

END

GO
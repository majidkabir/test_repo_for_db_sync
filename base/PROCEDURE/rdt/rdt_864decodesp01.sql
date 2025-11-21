SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_864DecodeSP01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 12-07-2016  James     1.0   SOS372493 Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_864DecodeSP01] (
@nMobile        INT,
@nFunc          INT,
@cLangCode      NVARCHAR( 3),
@nStep          INT,
@nInputKey      INT,
@cStorerKey     NVARCHAR( 15), 
@cBarcode       NVARCHAR( 60),
@cID            NVARCHAR( 18)  OUTPUT, 
@cSKU           NVARCHAR( 20)  OUTPUT, 
@nQTY           INT            OUTPUT, 
@cDropID        NVARCHAR( 20)  OUTPUT, 
@cLottable01    NVARCHAR( 18)  OUTPUT, 
@cLottable02    NVARCHAR( 18)  OUTPUT, 
@cLottable03    NVARCHAR( 18)  OUTPUT, 
@dLottable04    DATETIME       OUTPUT, 
@dLottable05    DATETIME       OUTPUT, 
@cLottable06    NVARCHAR( 30)  OUTPUT, 
@cLottable07    NVARCHAR( 30)  OUTPUT, 
@cLottable08    NVARCHAR( 30)  OUTPUT, 
@cLottable09    NVARCHAR( 30)  OUTPUT, 
@cLottable10    NVARCHAR( 30)  OUTPUT, 
@cLottable11    NVARCHAR( 30)  OUTPUT, 
@cLottable12    NVARCHAR( 30)  OUTPUT, 
@dLottable13    DATETIME       OUTPUT, 
@dLottable14    DATETIME       OUTPUT, 
@dLottable15    DATETIME       OUTPUT, 
@cUserDefine01  NVARCHAR( 60)  OUTPUT, 
@cUserDefine02  NVARCHAR( 60)  OUTPUT, 
@cUserDefine03  NVARCHAR( 60)  OUTPUT, 
@cUserDefine04  NVARCHAR( 60)  OUTPUT, 
@cUserDefine05  NVARCHAR( 60)  OUTPUT, 
@nErrNo         INT            OUTPUT, 
@cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nPos     INT,
           @cExternOrderKey   NVARCHAR( 20),
           @cLoadKey          NVARCHAR( 10), 
           @cConsigneeKey     NVARCHAR( 15), 
           @cBarcode1         NVARCHAR( 60), 
           @cBarcode2         NVARCHAR( 60), 
           @cSKUCode          NVARCHAR( 20), 
           @cQty              NVARCHAR( 5)
   
   IF @nFunc = 864 -- Pick To Drop ID
   BEGIN
      IF @nStep = 1 -- MUID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SET @cExternOrderKey = SUBSTRING(@cBarcode, 1, CHARINDEX( '/', @cBarcode) - 1)
               
               SELECT TOP 1 
                      @cConsigneeKey = ConsigneeKey, 
                      @cLoadKey = LoadKey
               FROM dbo.Orders WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ExternOrderKey = @cExternOrderKey
               AND   Status < '9'
               
               SET @cID = RTRIM( @cConsigneeKey) + RIGHT( RTRIM( @cLoadKey), 8)
            END
         END
      END   -- @nStep = 1

      IF @nStep = 2
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SET @cUserDefine01 = @cBarcode
         END
      END

      IF @nStep = 6
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SET @cConsigneeKey = SUBSTRING(@cBarcode, 1, CHARINDEX( '/', @cBarcode) - 1)

               SET @cBarcode1 = SUBSTRING(@cBarcode, LEN( @cConsigneeKey) + 2, 60) 

               SET @cSKUCode = SUBSTRING(@cBarcode1, 1, CHARINDEX( '/', @cBarcode1) - 1)

               SET @cBarcode2 = SUBSTRING(@cBarcode1, LEN( @cSKUCode) + 2, 60) 
               
               SET @cQty = SUBSTRING(@cBarcode2, 1, 60)
               
               SET @cSKU = @cSKUCode 
               
               SET @nQty = CAST( @cQty AS INT)
               
               SET @cUserDefine01 = @cConsigneeKey
            END
         END   -- @nInputKey = 1
      END   -- @nStep = 3
   END

Quit:

END

GO
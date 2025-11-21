SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513DecodeSP01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Adidas decode label return SKU + Qty                              */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 25-04-2017  ChewKP    1.0   WMS-1686 Created                               */
/* 05-06-2018  James     1.1   WMS5309-Modify params (james01)                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_513DecodeSP01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cBarcode     NVARCHAR( 60), 
   @cFromLOC     NVARCHAR( 10)  OUTPUT, 
   @cFromID      NVARCHAR( 18)  OUTPUT, 
   @cSKU         NVARCHAR( 20)  OUTPUT, 
   @nQTY         INT            OUTPUT, 
   @cToLOC       NVARCHAR( 10)  OUTPUT, 
   @cToID        NVARCHAR( 18)  OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nLength     INT,
           @cBUSR1      NVARCHAR( 30), 
           @cStyle      NVARCHAR( 20), 
           @cQty        NVARCHAR( 5), 
           @bSuccess    INT
   
   IF @nFunc = 513 -- Move by SKU
   BEGIN
      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
	            SELECT @bsuccess = 1
      
               -- Validate SKU/UPC
               EXEC dbo.nspg_GETSKU
                  @c_StorerKey= @cStorerKey  OUTPUT
                 ,@c_Sku      = @cBarcode    OUTPUT
                 ,@b_Success  = @bSuccess    OUTPUT
                 ,@n_Err      = @nErrNo      OUTPUT
                 ,@c_ErrMsg   = @cErrMsg     OUTPUT

               -- User key in valid SKU/UPC, no need decode anymore
   	         IF @bSuccess = 1
   	         BEGIN
   	            SET @nQty = 0 
                  SET @cSKU = @cBarcode
                  GOTO Quit
               END

               SET @nErrNo = 0
               SET @cErrMsg = ''

               SET @nLength = LEN( RTRIM( @cBarcode))
               
               IF @nLength = 24
               BEGIN
                  SET @cStyle = SUBSTRING( RTRIM( @cBarcode), 12, 6)
                  SET @cBUSR1 = SUBSTRING( RTRIM( @cBarcode), 18, 2)
                  SET @cQty   = SUBSTRING( RTRIM( @cBarcode), 20, 3)
                  
                  SELECT TOP 1 @cSKU = SKU
                  FROM dbo.SKU WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   Style = @cStyle
                  AND   BUSR1 = @cBUSR1
               END
               ELSE
               BEGIN
                  SET @cSKU = SUBSTRING( RTRIM( @cBarcode), 5, 13)
                  SET @cQty = SUBSTRING( RTRIM( @cBarcode), 19, 3)                  
               END
               
        

               IF rdt.rdtIsValidQty( @cQty, 1) = 0
                  SET @nQty = 0
               ELSE
                  SET @nQty = CAST( @cQty AS INT)
            END   -- @cBarcode
         END   -- ENTER
      END   -- @nStep = 3
   END

Quit:

END

GO
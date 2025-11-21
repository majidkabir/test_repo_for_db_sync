SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1620DecodeSP04                                        */
/* Copyright: MAERSK                                                          */
/*                                                                            */
/* Purpose: Puma decode label return SKU + Qty                                */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-06-04  James     1.0   WMS22591. Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1620DecodeSP04] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15), 
   @cBarcode       NVARCHAR( 60),
   @cWaveKey       NVARCHAR( 10), 
   @cLoadKey       NVARCHAR( 10), 
   @cOrderKey      NVARCHAR( 10), 
   @cPutawayZone   NVARCHAR( 10), 
   @cPickZone      NVARCHAR( 10), 
   @cDropID        NVARCHAR( 20)  OUTPUT, 
   @cUPC           NVARCHAR( 20)  OUTPUT, 
   @nQTY           INT            OUTPUT, 
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

   DECLARE @cQty        NVARCHAR( 5), 
           @bSuccess    INT
   
   IF @nFunc = 1620 -- Cluster Pick 
   BEGIN
      IF @nStep = 8 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
            	-- User can key in sku barcode then default qty = 1 (piece scanning)
            	SET @cUPC = SUBSTRING( @cBarcode, 1, 30)
            	SET @nQTY = 1
            	
	            SELECT @bsuccess = 1
      
               -- Validate SKU/UPC
               EXEC dbo.nspg_GETSKU
                  @c_StorerKey= @cStorerKey  OUTPUT
                 ,@c_Sku      = @cUPC        OUTPUT
                 ,@b_Success  = @bSuccess    OUTPUT
                 ,@n_Err      = @nErrNo      OUTPUT
                 ,@c_ErrMsg   = @cErrMsg     OUTPUT

               -- User key in valid SKU/UPC, no need decode anymore
   	         IF @bSuccess = 1
                  GOTO Quit
         
               -- User key in ocl label barcode
               SET @nErrNo = 0
               SET @cErrMsg = ''
            
               SET @cUPC = SUBSTRING( RTRIM( @cBarcode), 16, 13)
               SET @cQty = SUBSTRING( RTRIM( @cBarcode), 29, 3)                  

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
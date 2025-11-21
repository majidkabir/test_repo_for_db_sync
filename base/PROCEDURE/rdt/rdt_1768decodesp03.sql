SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1768DecodeSP03                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Nike decode label return SKU + Qty                                */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2022-07-13  James     1.0   WMS-19597. Created                             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1768DecodeSP03] (
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @nInputKey      INT,           
   @cStorerKey     NVARCHAR( 15), 
   @cBarcode       NVARCHAR( 60), 
   @cTaskDetailKey NVARCHAR( 10), 
   @cLOC           NVARCHAR( 10),                
   @cID            NVARCHAR( 18),                
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

   DECLARE @bSuccess    INT = 1
   DECLARE @nCaseCnt    INT = 0

   IF @cBarcode = ''
      GOTO Quit

   IF @nFunc = 1768 -- TMCC SKU
   BEGIN
      IF @nStep = 1 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
         	IF EXISTS ( SELECT 1 FROM dbo.UPC WITH (NOLOCK, INDEX(PK_UPC))
         	            WHERE StorerKey = @cStorerKey
         	            AND   UPC = @cBarcode)
            BEGIN
               EXEC dbo.nspg_GETSKU
                  @c_StorerKey= @cStorerKey  OUTPUT
                 ,@c_Sku      = @cBarcode    OUTPUT
                 ,@b_Success  = @bSuccess    OUTPUT
                 ,@n_Err      = @nErrNo      OUTPUT
                 ,@c_ErrMsg   = @cErrMsg     OUTPUT

               -- User key in valid SKU/UPC, no need decode anymore
   	         IF @bSuccess = 1
   	         BEGIN
                  SELECT @nCaseCnt = PACK.CaseCnt
                  FROM dbo.SKU SKU WITH (NOLOCK)
                  JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
                  WHERE SKU.StorerKey = @cStorerKey
                  AND   SKU.Sku = @cBarcode
                  
                  SET @cUPC = @cBarcode
                  SET @nQTY = @nCaseCnt

                  GOTO Quit
               END
            END
            ELSE
            BEGIN
               EXEC dbo.nspg_GETSKU
                  @c_StorerKey= @cStorerKey  OUTPUT
                 ,@c_Sku      = @cBarcode    OUTPUT
                 ,@b_Success  = @bSuccess    OUTPUT
                 ,@n_Err      = @nErrNo      OUTPUT
                 ,@c_ErrMsg   = @cErrMsg     OUTPUT

               -- User key in valid SKU/UPC, no need decode anymore
   	         IF @bSuccess = 1
   	         BEGIN
                  SET @cUPC = @cBarcode
                  SET @nQTY = 1
                  
                  GOTO Quit
               END
            END
         END   -- ENTER
      END   -- @nStep = 3
      ELSE
         SET @cUPC = @cBarcode
   END

Quit:

END

GO
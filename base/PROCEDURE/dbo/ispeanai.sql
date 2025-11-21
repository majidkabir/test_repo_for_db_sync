SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispEANAI                                            */
/* Copyright      : LFL                                                 */
/*                                                                      */
/* Purpose: SOS#370218 - EAN AI Barcode decode based on barcode config  */          
/*                                                                      */
/* Called from: Packing screen sku scanning (isp_SKUDecode_Wrapper)     */
/*              By Storerconfig SKUDECODE                               */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispEANAI]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(50),
   @c_NewSku           NVARCHAR(20) OUTPUT,
   @b_Success          INT      OUTPUT,
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_UPC NVARCHAR(30)
                                
   SELECT @b_Success = 1, @n_ErrNo = 0, @c_ErrMsg = '', @c_UPC = ''

   EXEC rdt.rdt_Decode 
      @nMobile = 0,
      @nFunc = 538,
      @cLangCode = 'ENG',
      @nStep = 0,
      @nInputKey = 0,
      @cStorerKey = @c_Storerkey,
      @cFacility = '',   
      @cBarcode = @c_Sku,   
      @cUPC = @c_UPC OUTPUT,  
      @nErrNo = @n_ErrNo OUTPUT,  
      @cErrMsg = @c_ErrMsg OUTPUT
      
   IF ISNULL(@n_ErrNo,0) <> 0
   BEGIN
      SET @b_Success = 0   
      SET @c_NewSKU = LEFT(@c_SKU, 20)
   END
   ELSE
   BEGIN
      IF ISNULL(@c_UPC,'') <> ''
      BEGIN       	
         EXEC nspg_GETSKU 
            @c_storerkey = @c_Storerkey, 
            @c_sku = @c_UPC  OUTPUT, 
            @b_Success = @b_Success OUTPUT,
            @n_err = @n_ErrNo OUTPUT, 
            @c_errmsg = @c_ErrMsg OUTPUT    
      END
                
      IF ISNULL(@c_UPC,'') <> ''
      BEGIN
         SET @c_NewSKU = LEFT(LTRIM(@c_UPC), 20)                                                                    
      END
      ELSE
      BEGIN
         SET @c_NewSKU = LEFT(@c_SKU, 20)          
      END
   END      
END -- End Procedure


GO
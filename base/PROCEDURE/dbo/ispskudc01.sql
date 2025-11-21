SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispSKUDC01                                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: SOS#208211 - barcode rule in Packing module                 */
/*                                                                      */
/* Called from: isp_SKUDecode_Wrapper                                   */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispSKUDC01]
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

   DECLARE @n_SkuLength   INT           
                                 
   SELECT @b_Success = 1, @n_ErrNo = 0, @c_ErrMsg = ''

   SET @n_SKULength = LEN(ISNULL(RTRIM(@c_Sku),''))
      
   IF (@n_SKULength >= 20)
   BEGIN
      SET @c_NewSKU = LEFT(ISNULL(RTRIM(@c_SKU), ''), (@n_SKULength - 6))
   END
   ELSE
   BEGIN
      SET @c_NewSKU = @c_SKU          
   END
   
END -- End Procedure


GO
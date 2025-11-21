SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp867DecodeSP01                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: If sku is manufacturer sku then return sku else return      */
/*          label no                                                    */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 11-Nov-2016  1.0  James       Created                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp867DecodeSP01]
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@c_LangCode	        NVARCHAR(3),
	@c_oFieled01        NVARCHAR(20) OUTPUT,
	@c_oFieled02        NVARCHAR(20) OUTPUT,
   @c_oFieled03        NVARCHAR(20) OUTPUT,
   @c_oFieled04        NVARCHAR(20) OUTPUT,
   @c_oFieled05        NVARCHAR(20) OUTPUT,
   @c_oFieled06        NVARCHAR(20) OUTPUT,
   @c_oFieled07        NVARCHAR(20) OUTPUT,
   @c_oFieled08        NVARCHAR(20) OUTPUT,
   @c_oFieled09        NVARCHAR(20) OUTPUT,
   @c_oFieled10        NVARCHAR(20) OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue     INT,
           @b_debug        INT

   DECLARE @c_SKU         NVARCHAR(40)
           
   SELECT @b_Success = 1, @n_ErrNo = 0, @b_debug = 0

   SELECT @c_SKU   = ''

   SELECT TOP 1 @c_SKU = SKU 
   FROM dbo.SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
   WHERE ManufacturerSku = @c_LabelNo 
   AND   StorerKey = @c_Storerkey

   IF @@ROWCOUNT = 0
   BEGIN
      SELECT TOP 1 @c_SKU = SKU 
      FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
      WHERE AltSku = @c_LabelNo 
      AND   StorerKey = @c_Storerkey

      IF @@ROWCOUNT = 0
      BEGIN
         SELECT TOP 1 @c_SKU = SKU 
         FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
         WHERE RetailSku = @c_LabelNo 
         AND   StorerKey = @c_Storerkey

         IF @@ROWCOUNT = 0
         BEGIN
            SELECT TOP 1 @c_SKU = SKU 
            FROM dbo.UPC UPC WITH (NOLOCK, INDEX(PK_UPC)) 
            WHERE UPC = @c_LabelNo 
            AND   StorerKey = @c_Storerkey            

            IF @@ROWCOUNT = 0
            BEGIN
               SET @c_oFieled01 = @c_LabelNo
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            SET @c_oFieled01 = @c_SKU
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         SET @c_oFieled01 = @c_SKU
         GOTO Quit
      END
   END
   ELSE
      SET @c_oFieled01 = @c_SKU
     
QUIT:
END -- End Procedure


GO
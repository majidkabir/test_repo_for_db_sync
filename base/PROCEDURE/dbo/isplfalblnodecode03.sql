SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispLFALblNoDecode03                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode Label No Scanned                                     */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 02-04-2013  1.0  James       SOS276235. Created                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispLFALblNoDecode03]
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
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nMultiStorer   INT, 
           @cCurrentSKU    NVARCHAR( 20) 

   SET @cCurrentSKU = ''
   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @c_Storerkey)
   BEGIN
      SET @nMultiStorer = 1

      IF ISNULL(@c_oFieled01, '') <> ''
         SET @cCurrentSKU = @c_oFieled01
   END
      
   SET @c_oFieled01 = ''

   /* For multi storer label decode use only*/
   IF @nMultiStorer = 1
   BEGIN
      IF ISNULL(@cCurrentSKU, '') = ''
      BEGIN
         GETNEXT_SKU:
         SELECT TOP 1 @c_oFieled01 = SKU.SKU 
         FROM dbo.SKU SKU WITH (NOLOCK, INDEX(PKSKU)) 
         JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
         JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
         WHERE SKU.SKU = @c_LabelNo
         AND   SG.StorerGroup = @c_Storerkey 
         AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
         ORDER BY SKU.SKU
         
         IF ISNULL(@c_oFieled01, '') = ''
         BEGIN
            SELECT TOP 1 @c_oFieled01 = SKU.SKU 
            FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
            JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
            WHERE SKU.ALTSKU = @c_LabelNo
            AND   SG.StorerGroup = @c_Storerkey 
            AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
            ORDER BY SKU.SKU
            
            IF ISNULL(@c_oFieled01, '') = ''
            BEGIN
               SELECT TOP 1 @c_oFieled01 = SKU.SKU 
               FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
               JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
               JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
               WHERE SKU.RETAILSKU = @c_LabelNo
               AND   SG.StorerGroup = @c_Storerkey 
               AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
               ORDER BY SKU.SKU
               
               IF ISNULL(@c_oFieled01, '') = ''
               BEGIN
                  SELECT TOP 1 @c_oFieled01 = SKU.SKU 
                  FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
                  JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
                  JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
                  WHERE SKU.ManufacturerSku = @c_LabelNo
                  AND   SG.StorerGroup = @c_Storerkey 
                  AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
                  ORDER BY SKU.SKU
                  
                  IF ISNULL(@c_oFieled01, '') = ''
                  BEGIN
                     SELECT TOP 1 @c_oFieled01 = UPC.SKU 
                     FROM dbo.UPC UPC WITH (NOLOCK, INDEX(PK_UPC)) 
                     JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (UPC.StorerKey = SG.StorerKey)
                     JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (UPC.StorerKey = LLI.StorerKey AND UPC.SKU = LLI.SKU)
                     WHERE UPC.UPC = @c_LabelNo
                     AND   SG.StorerGroup = @c_Storerkey 
                     AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
                     ORDER BY UPC.SKU
                     
                     IF ISNULL(@c_oFieled01, '') = ''
                     BEGIN
                        SET @c_ErrMsg = 'INVALID SKU'
                        GOTO Quit
                     END
                  END   -- UPC
               END      -- MANUFACTURERSKU
            END         -- RETAIL SKU
         END            -- ALTSKU
      END
      ELSE
      BEGIN
         SELECT TOP 1 @c_oFieled01 = SKU.SKU 
         FROM dbo.SKU SKU WITH (NOLOCK, INDEX(PKSKU)) 
         JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
         JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
         WHERE SKU.SKU = @c_LabelNo
         AND   SKU.SKU > @cCurrentSKU
         AND   SG.StorerGroup = @c_Storerkey 
         AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
         ORDER BY SKU.SKU
         
         IF ISNULL(@c_oFieled01, '') = ''
         BEGIN
            SELECT TOP 1 @c_oFieled01 = SKU.SKU 
            FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
            JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
            WHERE SKU.ALTSKU = @c_LabelNo
            AND   SKU.SKU > @cCurrentSKU
            AND   SG.StorerGroup = @c_Storerkey 
            AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
            ORDER BY SKU.SKU
            
            IF ISNULL(@c_oFieled01, '') = ''
            BEGIN
               SELECT TOP 1 @c_oFieled01 = SKU.SKU 
               FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
               JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
               JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
               WHERE SKU.RETAILSKU = @c_LabelNo
               AND   SKU.SKU > @cCurrentSKU
               AND   SG.StorerGroup = @c_Storerkey 
               AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
               ORDER BY SKU.SKU
               
               IF ISNULL(@c_oFieled01, '') = ''
               BEGIN
                  SELECT TOP 1 @c_oFieled01 = SKU.SKU 
                  FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
                  JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
                  JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
                  WHERE SKU.ManufacturerSku = @c_LabelNo
                  AND   SKU.SKU > @cCurrentSKU
                  AND   SG.StorerGroup = @c_Storerkey 
                  AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
                  ORDER BY SKU.SKU
                  
                  IF ISNULL(@c_oFieled01, '') = ''
                  BEGIN
                     SELECT TOP 1 @c_oFieled01 = UPC.SKU 
                     FROM dbo.UPC UPC WITH (NOLOCK, INDEX(PK_UPC)) 
                     JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (UPC.StorerKey = SG.StorerKey)
                     JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (UPC.StorerKey = LLI.StorerKey AND UPC.SKU = LLI.SKU)
                     WHERE UPC.UPC = @c_LabelNo
                     AND   UPC.SKU > @cCurrentSKU
                     AND   SG.StorerGroup = @c_Storerkey 
                     AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
                     ORDER BY UPC.SKU
                     
                     IF ISNULL(@c_oFieled01, '') = ''
                     BEGIN
                        GOTO GETNEXT_SKU
                     END
                  END   -- UPC
               END      -- MANUFACTURERSKU
            END         -- RETAIL SKU
         END            -- ALTSKU
      END
   END
   ELSE
   BEGIN
      SET @c_oFieled09 = @c_Storerkey
      
      SELECT TOP 1 @c_oFieled01 = SKU.SKU 
      FROM dbo.SKU SKU WITH (NOLOCK, INDEX(PKSKU)) 
      JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
      WHERE SKU.SKU = @c_LabelNo 
      AND   SKU.StorerKey = @c_Storerkey
      AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
        
      IF ISNULL(@c_oFieled01, '') = '' 
      BEGIN 
         SELECT TOP 1 @c_oFieled01 = SKU.SKU 
         FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
         JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
         WHERE SKU.AltSku = @c_LabelNo 
         AND   SKU.StorerKey = @c_Storerkey
         AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
      
         IF ISNULL(@c_oFieled01, '') = '' 
         BEGIN
            SELECT TOP 1 @c_oFieled01 = SKU.SKU 
            FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
            WHERE SKU.RetailSku = @c_LabelNo 
            AND   SKU.StorerKey = @c_Storerkey
            AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)

            IF ISNULL(@c_oFieled01, '') = '' 
            BEGIN 
               SELECT @c_oFieled01 = SKU.SKU 
               FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
               JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
               WHERE SKU.ManufacturerSku = @c_LabelNo 
               AND   SKU.StorerKey = @c_Storerkey
               AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
               
               IF ISNULL(@c_oFieled01, '') = '' 
               BEGIN
                  SELECT TOP 1 @c_oFieled01 = UPC.SKU 
                  FROM dbo.UPC UPC WITH (NOLOCK, INDEX(PK_UPC)) 
                  JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (UPC.StorerKey = LLI.StorerKey AND UPC.SKU = LLI.SKU)
                  WHERE UPC.UPC = @c_LabelNo 
                  AND   UPC.StorerKey = @c_Storerkey 
                  AND   (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
                  
                  IF ISNULL(@c_oFieled01, '') = '' 
                  BEGIN 
                     SET @c_ErrMsg = 'INVALID SKU'
                     GOTO Quit
                  END 
               END
            END 
         END
      END
   END
   
QUIT:
END -- End Procedure


GO
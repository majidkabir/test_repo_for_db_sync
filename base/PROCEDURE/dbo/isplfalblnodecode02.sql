SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispLFALblNoDecode02                                 */
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

CREATE PROCEDURE [dbo].[ispLFALblNoDecode02]
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

   DECLARE @cRPL_SKU       NVARCHAR( 20),
           @cFromLOC       NVARCHAR( 10),
           @cFromID        NVARCHAR( 18),
           @cFacility      NVARCHAR( 5),
           @nStorerCount   INT,
           @nMultiStorer   INT 
   
   SET @c_oFieled01 = ''
   SET @cRPL_SKU = ''
      
   SELECT @cFacility = Facility, 
          @cFromLOC  = V_LOC, 
          @cFromID   = V_ID 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = CAST(@c_ReceiptKey AS INT)

   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @c_Storerkey)
      SET @nMultiStorer = 1
   /*
      For multi storer label decode use only
      For multi storer move by sku, only able to move sku from loc contain
      only 1 sku 1 storer because if 1 sku multi storer then move by sku
      system don't know which storer's sku to move
      If contain SKU A (Storer 1), SKU A (Storer 2) in 1 LOC then will be blocked at decode label sp
   */
   IF @nMultiStorer = 1
   BEGIN
      SELECT TOP 1 @cRPL_SKU = SKU.SKU 
      FROM dbo.SKU SKU WITH (NOLOCK) 
      JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
      JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE SKU.SKU = @c_LabelNo
      AND   SG.StorerGroup = @c_Storerkey 
      AND   LLI.LOC = @cFromLOC
      AND   LLI.ID = CASE WHEN ISNULL(@cFromID, '') = '' THEN LLI.ID ELSE @cFromID END
      AND   LOC.Facility = @cFacility

      
      IF ISNULL(@cRPL_SKU, '') = ''
      BEGIN
         SELECT TOP 1 @cRPL_SKU = SKU.SKU 
         FROM dbo.SKU SKU WITH (NOLOCK) 
         JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
         JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE SKU.ALTSKU = @c_LabelNo
         AND   SG.StorerGroup = @c_Storerkey 
         AND   LLI.LOC = @cFromLOC
         AND   LLI.ID = CASE WHEN ISNULL(@cFromID, '') = '' THEN LLI.ID ELSE @cFromID END
         AND   LOC.Facility = @cFacility

         IF ISNULL(@cRPL_SKU, '') = ''
         BEGIN
            SELECT TOP 1 @cRPL_SKU = SKU.SKU 
            FROM dbo.SKU SKU WITH (NOLOCK) 
            JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE SKU.RETAILSKU = @c_LabelNo
            AND   SG.StorerGroup = @c_Storerkey 
            AND   LLI.LOC = @cFromLOC
            AND   LLI.ID = CASE WHEN ISNULL(@cFromID, '') = '' THEN LLI.ID ELSE @cFromID END
            AND   LOC.Facility = @cFacility
         
            IF ISNULL(@cRPL_SKU, '') = ''
            BEGIN
               SELECT TOP 1 @cRPL_SKU = SKU.SKU 
               FROM dbo.SKU SKU WITH (NOLOCK) 
               JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
               JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
               WHERE SKU.ManufacturerSku = @c_LabelNo
               AND   SG.StorerGroup = @c_Storerkey 
               AND   LLI.LOC = @cFromLOC
               AND   LLI.ID = CASE WHEN ISNULL(@cFromID, '') = '' THEN LLI.ID ELSE @cFromID END
               AND   LOC.Facility = @cFacility
      
               IF ISNULL(@cRPL_SKU, '') = ''
               BEGIN
                  SELECT TOP 1 @cRPL_SKU = UPC.SKU 
                  FROM dbo.UPC UPC WITH (NOLOCK) 
                  JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (UPC.StorerKey = SG.StorerKey)
                  JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (UPC.SKU = LLI.SKU AND UPC.StorerKey = LLI.StorerKey)
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  WHERE UPC.UPC = @c_LabelNo
                  AND   SG.StorerGroup = @c_Storerkey 
                  AND   LLI.LOC = @cFromLOC
                  AND   LLI.ID = CASE WHEN ISNULL(@cFromID, '') = '' THEN LLI.ID ELSE @cFromID END
                  AND   LOC.Facility = @cFacility
                  
                  IF ISNULL(@cRPL_SKU, '') = ''
                  BEGIN
                     SET @c_ErrMsg = 'INVALID SKU'
                     GOTO Quit
                  END
               END   -- UPC
            END      -- MANUFACTURERSKU
         END         -- RETAIL SKU
      END            -- ALTSKU

      IF ISNULL(@cRPL_SKU, '') <> '' AND ISNULL(@cFromLOC, '') <> ''
      BEGIN
         SET @nStorerCount = 0
         SELECT @nStorerCount = COUNT (DISTINCT LLI.StorerKey) 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LLI.SKU = @cRPL_SKU
         AND   LLI.LOC = @cFromLOC
         AND   LLI.ID = CASE WHEN ISNULL(@cFromID, '') = '' THEN LLI.ID ELSE @cFromID END
         AND   LOC.Facility = @cFacility
         
         IF @nStorerCount > 1
         BEGIN
            SET @c_ErrMsg = 'LOC DIFF STORER'
            GOTO Quit
         END
         /*
         SET @nStorerCount = 0
         SELECT @nStorerCount = COUNT (1) 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LLI.SKU = @cRPL_SKU
         AND   LLI.LOC = @cFromLOC
         AND   LLI.ID = CASE WHEN ISNULL(@cFromID, '') = '' THEN LLI.ID ELSE @cFromID END
         AND   LOC.Facility = @cFacility
         AND NOT EXISTS (SELECT 1 FROM dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @c_StorerKey)
         
         IF @nStorerCount >= 1
         BEGIN
            SET @c_ErrMsg = 'LOC INV STORER'
            GOTO Quit
         END
         */
         SET @c_oFieled01 = @cRPL_SKU
         SELECT TOP 1 @c_oFieled09 = StorerKey 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LLI.SKU = @cRPL_SKU
         AND   LLI.LOC = @cFromLOC
         AND   LLI.ID = CASE WHEN ISNULL(@cFromID, '') = '' THEN LLI.ID ELSE @cFromID END
         AND   LOC.Facility = @cFacility
      END
      ELSE
      BEGIN
         SET @c_ErrMsg = 'INVALID SKU'
         GOTO Quit
      END
   END
   ELSE
   BEGIN
      SET @c_oFieled09 = @c_Storerkey
      
      SELECT TOP 1 @c_oFieled01 = SKU 
      FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(PKSKU)) 
      WHERE Sku = @c_LabelNo 
        AND StorerKey = @c_Storerkey
      IF @@ROWCOUNT = 0 
      BEGIN 
         SELECT TOP 1 @c_oFieled01 = SKU 
         FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
         WHERE AltSku = @c_LabelNo 
           AND StorerKey = @c_Storerkey
         IF @@ROWCOUNT = 0 
         BEGIN
            SELECT TOP 1 @c_oFieled01 = SKU 
            FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
            WHERE RetailSku = @c_LabelNo 
             AND StorerKey = @c_Storerkey

            IF @@ROWCOUNT = 0 
            BEGIN 
               SELECT @c_oFieled01 = SKU 
               FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
                WHERE ManufacturerSku = @c_LabelNo 
                  AND StorerKey = @c_Storerkey
               IF @@ROWCOUNT = 0 
               BEGIN
                  SELECT TOP 1 @c_oFieled01 = SKU 
                  FROM dbo.UPC UPC WITH (NOLOCK, INDEX(PK_UPC)) 
                  WHERE UPC = @c_LabelNo 
                    AND StorerKey = @c_Storerkey            
                  IF @@ROWCOUNT = 0 
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
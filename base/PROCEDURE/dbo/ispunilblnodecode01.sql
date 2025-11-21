SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispUniLblNoDecode01                                 */
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
/* 07-10-2013  1.0  James       SOS291606. Created                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispUniLblNoDecode01]
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

   DECLARE 
      @c_SKU               NVARCHAR( 20), 
      @n_IsSKU             INT, 
      @n_IsRetailSKU       INT, 
      @n_IsManufacturerSKU INT, 
      @n_IsAltSKU          INT, 
      @n_IsUPC             INT, 
      @n_UOMQtyINT         INT, 
      @n_Mobile            INT,
      @n_PackUOMQty        INT, 
      @n_ActPQty           INT, 
      @n_ActMQty           INT, 
      @c_PackUOM           NVARCHAR( 20), 
      @c_PrefUOM           NVARCHAR( 1), 
      @cExecStatements     NVARCHAR( 4000), 
      @cExecArguments      NVARCHAR( 4000) 
   
   SET @n_Mobile = @c_ReceiptKey
   SET @c_SKU = ''
   SET @c_PackUOM = ''
   SET @n_IsSKU = 0
   SET @n_IsRetailSKU = 0
   SET @n_IsManufacturerSKU = 0
   SET @n_IsAltSKU = 0
   SET @n_IsUPC = 0
   SET @n_PackUOMQty = 0
     
   
   SELECT @n_ActPQty = V_String21, 
          @n_ActMQty = V_String22 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @n_Mobile
          
   IF EXISTS (SELECT 1 
              FROM dbo.SKU SKU WITH (NOLOCK, INDEX(PKSKU)) 
              WHERE Sku = @c_LabelNo 
              AND   StorerKey = @c_Storerkey)
   BEGIN
      SET @n_IsSKU = 1
      SET @c_SKU = @c_LabelNo
   END

   IF @n_IsSKU = 0
   BEGIN
      IF EXISTS (SELECT 1 
                 FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
                 WHERE RetailSku = @c_LabelNo 
                 AND   StorerKey = @c_Storerkey)
      BEGIN
         SET @n_IsRetailSKU = 1
         
         SELECT @c_SKU = SKU
         FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
         WHERE RetailSku = @c_LabelNo 
         AND   StorerKey = @c_Storerkey 
      END
   END
   
   IF @n_IsSKU = 0 AND @n_IsRetailSKU = 0
   BEGIN
      IF EXISTS (SELECT 1 
                 FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
                 WHERE ManufacturerSku = @c_LabelNo 
                 AND   StorerKey = @c_Storerkey)
      BEGIN
         SET @n_IsManufacturerSKU = 1

         SELECT @c_SKU = SKU
         FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
         WHERE ManufacturerSku = @c_LabelNo 
         AND   StorerKey = @c_Storerkey 
      END
   END

   IF @n_IsSKU = 0 AND @n_IsRetailSKU = 0 AND @n_IsManufacturerSKU = 0
   BEGIN
      IF EXISTS (SELECT 1 
                 FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
                 WHERE AltSku = @c_LabelNo 
                 AND   StorerKey = @c_Storerkey)
      BEGIN
         SET @n_IsAltSKU = 1

         SELECT @c_SKU = SKU
         FROM dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
         WHERE AltSku = @c_LabelNo 
         AND   StorerKey = @c_Storerkey 
      END
   END

   IF @n_IsSKU = 0 AND @n_IsRetailSKU = 0 AND @n_IsManufacturerSKU = 0 AND @n_IsAltSKU = 0
   BEGIN
      IF EXISTS (SELECT 1 
                 FROM dbo.UPC UPC WITH (NOLOCK, INDEX(PK_UPC)) 
                 WHERE UPC = @c_LabelNo 
                 AND   StorerKey = @c_Storerkey)
      BEGIN
         SET @n_IsUPC = 1

         SELECT @c_SKU = SKU
         FROM dbo.UPC UPC WITH (NOLOCK, INDEX(PK_UPC)) 
         WHERE UPC = @c_LabelNo 
         AND   StorerKey = @c_Storerkey
      END
   END
   
   SELECT @c_PackUOM = Short 
   FROM dbo.CodeLkUp WITH (NOLOCK) 
   WHERE ListName = 'SCANQTY'
   AND CODE = CASE WHEN @n_IsSKU = 1 THEN 'SKU' 
                   WHEN @n_IsRetailSKU = 1 THEN 'RETAILSKU'
                   WHEN @n_IsManufacturerSKU = 1 THEN 'MANUFACTURERSKU'
                   WHEN @n_IsAltSKU = 1 THEN 'ALTSKU'
                   WHEN @n_IsUPC = 1 THEN 'UPC'
                   ELSE '' END
   AND StorerKey = @c_Storerkey
      

   SET @cExecStatements = ' SELECT @n_PackUOMQty  =  ' + @c_PackUOM +
      	                 ' FROM dbo.SKU SKU WITH (NOLOCK) ' + 
      	                 ' JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey ' + 
                          ' WHERE SKU.StorerKey = ''' + RTRIM(@c_Storerkey)  + ''' ' + 
                          ' AND   SKU.SKU = ''' + RTRIM(@c_SKU) + ''' ' 

   SET @cExecArguments = N' @n_PackUOMQty INT   OUTPUT ' 
   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments, @n_PackUOMQty OUTPUT
   
   IF @c_PackUOM <> 'Qty'
   BEGIN
      -- Get prefer UOM  
      SELECT @c_PrefUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA  
      FROM RDT.rdtMobRec M WITH (NOLOCK)  
         INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)  
      WHERE M.Mobile = @n_Mobile  
      
      -- If user prefer uom is 6 (each) then direct display casecnt as each
      IF @c_PrefUOM <> '6' 
         SET @c_oFieled01 = @n_PackUOMQty + @n_ActPQty
      ELSE
         SET @c_oFieled02 = @n_PackUOMQty + @n_ActMQty
      
   END
   ELSE
      SET @c_oFieled02 = @n_PackUOMQty + @n_ActMQty


QUIT:
END -- End Procedure


GO
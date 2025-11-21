SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_523LblNoDecode01                                */
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
/* 03-06-2019  1.0  James       WMS9223. Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_523LblNoDecode01]
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

   DECLARE @c_SKU       NVARCHAR( 20),
           @n_Func      INT,
           @n_Step      INT,
           @n_InputKey  INT,
           @n_SKUCnt    INT,
           @c_LOC       NVARCHAR( 10),
           @c_SKUStatus NVARCHAR( 10),
           @c_ID        NVARCHAR( 18),
           @c_InputValue   NVARCHAR( 60)

   IF ISNULL( @c_LabelNo, '') = ''
      GOTO Quit

   SELECT @n_Func = Func, 
          @n_Step = Step,
          @n_InputKey = InputKey,
          @c_LOC = V_LOC,
          @c_ID = V_ID,
          @c_InputValue = I_Field05
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE UserName = sUser_sName()

   IF @n_Func = 523
   BEGIN
      IF @n_Step = 2
      BEGIN
         IF @n_InputKey = 1
         BEGIN
            SELECT @c_SKU = SKU 
            FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(PKSKU)) 
            WHERE StorerKey = @c_Storerkey 
            AND Sku = @c_InputValue
            AND EXISTS ( SELECT 1 
                         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                         WHERE LOC = @c_LOC 
                         AND   ID = @c_ID 
                         AND   QTY > 0 
                         AND   LLI.SKU = SKU.SKU 
                         AND   LLI.StorerKey = SKU.StorerKey)

            IF ISNULL( @c_SKU, '') = ''
               SELECT @c_SKU = SKU 
               FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
               WHERE StorerKey = @c_Storerkey
               AND AltSku = @c_InputValue
               AND EXISTS ( SELECT 1 
                            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                            WHERE LOC = @c_LOC 
                            AND   ID = @c_ID 
                            AND   QTY > 0 
                            AND   LLI.SKU = SKU.SKU 
                            AND   LLI.StorerKey = SKU.StorerKey)

            IF ISNULL( @c_SKU, '') = ''
               SELECT @c_SKU = SKU 
               FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
               WHERE StorerKey = @c_Storerkey
               AND RetailSku = @c_InputValue
               AND EXISTS ( SELECT 1 
                            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                            WHERE LOC = @c_LOC 
                            AND   ID = @c_ID 
                            AND   QTY > 0 
                            AND   LLI.SKU = SKU.SKU 
                            AND   LLI.StorerKey = SKU.StorerKey)

            IF ISNULL( @c_SKU, '') = ''
               SELECT @c_SKU = SKU 
               FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
               WHERE StorerKey = @c_Storerkey
               AND ManufacturerSku = @c_InputValue
               AND EXISTS ( SELECT 1 
                            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                            WHERE LOC = @c_LOC 
                            AND   ID = @c_ID 
                            AND   QTY > 0 
                            AND   LLI.SKU = SKU.SKU 
                            AND   LLI.StorerKey = SKU.StorerKey)

            IF ISNULL( @c_SKU, '') = ''
               SELECT @c_SKU = SKU 
               FROM  dbo.UPC UPC WITH (NOLOCK, INDEX(PK_UPC)) 
               WHERE StorerKey = @c_Storerkey
               AND UPC = @c_InputValue
               AND EXISTS ( SELECT 1 
                            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                            WHERE LOC = @c_LOC 
                            AND   ID = @c_ID 
                            AND   QTY > 0 
                            AND   LLI.SKU = UPC.SKU 
                            AND   LLI.StorerKey = UPC.StorerKey)

            IF ISNULL( @c_SKU, '') = ''
            BEGIN
               SET @n_ErrNo = 139551
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- SKU NOT EXISTS
               GOTO Quit
            END

            SET @c_oFieled01 = @c_SKU
         END
      END
   END

QUIT:
END -- End Procedure


GO
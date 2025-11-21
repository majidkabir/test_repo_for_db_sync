SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispLFALblNoDecode01                                */
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

CREATE PROCEDURE [dbo].[ispLFALblNoDecode01]
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
           @cUserName      NVARCHAR( 20), 
           @cOrderKey      NVARCHAR( 10), 
           @cStorerKey     NVARCHAR( 15) 
   
   SET @c_oFieled01 = ''
   
   SELECT @cOrderKey = V_OrderKey, 
          @cRPL_SKU = V_SKU
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = CAST(@c_ReceiptKey AS INT)

   -- If user key in suggested sku
   IF @c_LabelNo = @cRPL_SKU
   BEGIN
      SET @c_oFieled01 = @cRPL_SKU
      GOTO Quit
   END
   
   SELECT @cStorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey 
   
   IF EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
              WHERE StorerKey = @cStorerKey
              AND   ALTSKU = @c_LabelNo
              AND   SKU = @cRPL_SKU)
   BEGIN
      SET @c_oFieled01 = @cRPL_SKU
      GOTO Quit
   END

   IF EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
              WHERE StorerKey = @cStorerKey
              AND   RETAILSKU = @c_LabelNo
              AND   SKU = @cRPL_SKU)   
   BEGIN
      SET @c_oFieled01 = @cRPL_SKU
      GOTO Quit
   END

   IF EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
              WHERE StorerKey = @cStorerKey
              AND   ManufacturerSku = @c_LabelNo
              AND   SKU = @cRPL_SKU)
   BEGIN
      SET @c_oFieled01 = @cRPL_SKU
      GOTO Quit
   END

   IF EXISTS (SELECT 1 FROM dbo.UPC WITH (NOLOCK) 
              WHERE StorerKey = @cStorerKey
              AND   UPC = @c_LabelNo
              AND   SKU = @cRPL_SKU)
   BEGIN
      SET @c_oFieled01 = @cRPL_SKU
      GOTO Quit
   END

   IF ISNULL(@c_oFieled01, '') = ''
      SET @c_ErrMsg = 'INVALID SKU'
QUIT:
END -- End Procedure


GO
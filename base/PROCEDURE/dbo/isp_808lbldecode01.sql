SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_808LblDecode01                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 02-07-2019  1.0  Ung         WMS-4890 Created                        */
/* 14-07-2021  1.1  James       WMS-17476 Check if sku blank (james01)  */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_808LblDecode01]
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@c_LangCode	        NVARCHAR(3),
	@c_oFieled01        NVARCHAR(20) OUTPUT,  -- SKU
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

   DECLARE @cLOC        NVARCHAR(10)
   DECLARE @cStorerKey  NVARCHAR(15)
   DECLARE @cSKU        NVARCHAR(20)
   
   -- Get session info
   SELECT 
      @cLOC = V_LOC, 
      @cStorerKey = StorerKey, 
      @cSKU = V_SKU
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE UserName = SUSER_SNAME()
   
   -- LOC will not mix SKU code with same barcode. Just need to check the barcode belong to SKU I current LOC 
   SELECT TOP 1 
      @c_oFieled01 = SKU.SKU
   FROM PickDetail PD WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
   WHERE PD.LOC = @cLOC
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.Status < '5'
      AND PD.Status <> '4'
      AND PD.QTY > 0
      AND @c_LabelNo in (SKU.ALTSKU, SKU.ManufacturerSKU, SKU.RetailSKU, SKU.SKU)

   IF ISNULL( @c_oFieled01, '') = ''
   BEGIN
      SET @n_ErrNo = 171051
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Invalid SKU
      GOTO Quit
   END

   Quit:
END -- End Procedure


GO
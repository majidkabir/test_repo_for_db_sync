SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispERKELabelNoDecode                                */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 23-07-2014  1.0  Ung         SOS316652 Created                       */
/* 25-06-2018  1.1  James       WMS5311-Add function id, step (james01) */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispERKELabelNoDecode]
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@cLangCode	        NVARCHAR(3),
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
   @nErrNo             INT      OUTPUT, 
   @cErrMsg            NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cStyle  NVARCHAR( 20)
   DECLARE @cColor  NVARCHAR( 10)
   DECLARE @cSize   NVARCHAR( 10)
   DECLARE @cSKU    NVARCHAR( 20)
   DECLARE @cQTY    NVARCHAR( 5)
   DECLARE @nFunc   INT
   DECLARE @nStep   INT

   SELECT @nFunc = Func, 
          @nStep = Step
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE UserName = sUser_sName()

   IF @nFunc IN ( 1580, 1581)
   BEGIN
      IF @nStep = 3  -- TOID
      BEGIN
         SET @c_oFieled01 = @c_LabelNo
         GOTO Quit
      END

      IF @nStep = 5
      BEGIN
         SET @cStyle = ''
         SET @cColor = ''
         SET @cSize = ''
         SET @cSKU = ''
         SET @cQTY = ''

         -- Get style, color, size, QTY
         SET @cStyle = rdt.rdtGetParsedString( @c_LabelNo, 1, '*')
         SET @cColor = rdt.rdtGetParsedString( @c_LabelNo, 2, '*')
         SET @cSize = rdt.rdtGetParsedString( @c_LabelNo, 3, '*')
         SET @cQTY = rdt.rdtGetParsedString( @c_LabelNo, 4, '*')
   
         -- Construct SKU
         SET @cSKU = LEFT( RTRIM( @cStyle) + RTRIM( @cColor) + RTRIM( @cSize), 20)
   
         -- Return value
         IF @cSKU <> '' 
         BEGIN
            -- Return SKU
            SET @c_oFieled01 = @cSKU
      
            -- Return QTY
            IF rdt.rdtIsValidQTY( @cQTY, 1) = 1 -- 1=Check for zero QTY
               SET @c_oFieled05 = @cQTY
         END
      END
   END
     
QUIT:
END -- End Procedure


GO
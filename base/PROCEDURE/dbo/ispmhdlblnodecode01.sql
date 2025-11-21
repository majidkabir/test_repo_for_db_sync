SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispMHDLblNoDecode01                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode Label No Scanned                                     */
/*          For MHD SG. Need decode 2 types of label                    */
/*          1. SSCC (20 digits). Take last 18 digits and search SKU     */
/*             from Lottable03                                          */
/*          2. GS1 (28 digits). Take 3rd digits and 13 character as     */
/*             SKU EAN code                                             */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 22-04-2014  1.0  James       SOS308816 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMHDLblNoDecode01]
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

   SET @n_ErrNo = 0
   DECLARE @nStep          INT,
           @cInField01     NVARCHAR( 60), 
           @cSKU           NVARCHAR( 20), 
           @cSSCC          NVARCHAR( 20) 

   SELECT @nStep = Step FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE UserName = sUser_sName()

   -- Not from SKU step, quit
   IF @nStep = 4
   BEGIN
      IF ISNULL( @c_ReceiptKey, '') = ''
      BEGIN
         SET @c_ErrMsg = 'Invalid ASN'
         GOTO Quit
      END

      SET @cSKU = ''
      SET @cSSCC = ''
      IF LEN( RTRIM( @c_LabelNo)) <= 20
      BEGIN
         SET @cInField01 = RIGHT( RTRIM( @c_LabelNo), 18)

         SELECT TOP 1 @cSKU = SKU 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @c_Storerkey
         AND   ReceiptKey = @c_ReceiptKey
         AND   Lottable03 = @cInField01
         AND   BeforeReceivedQty = 0
         AND   FinalizeFlag = 'N'
         ORDER BY ExternLineNo

         IF ISNULL( @cSKU, '') = ''
            SELECT TOP 1 @cSKU = SKU 
            FROM dbo.ReceiptDetail WITH (NOLOCK) 
            WHERE StorerKey = @c_Storerkey
            AND   ReceiptKey = @c_ReceiptKey
            AND   Lottable03 = @cInField01
            AND   BeforeReceivedQty > 0
            AND   FinalizeFlag = 'N'
            ORDER BY ExternLineNo

         IF ISNULL( @cSKU, '') = ''
            SET @cSKU = @c_LabelNo
         ELSE
            SET @cSSCC = @cInField01
      END
      ELSE
      BEGIN
         SET @cSKU = SUBSTRING( @c_LabelNo, 3, 13)
      END

      SET @c_oFieled01 = @cSKU
      SET @c_oFieled02 = @cSSCC
   END
--   ELSE IF @nStep = 6
--   BEGIN
--      SET @c_oFieled01 = RIGHT( RTRIM( @c_LabelNo), 7)
--   END
Quit:  


END -- End Procedure


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispNIKELabelNoDecode                                */
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
/* 11-03-2013  1.0  Ung         SOS272437. Created                      */
/* 10-09-2015  1.1  Ung         SOS347745 Check UCC in ASN              */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispNIKELabelNoDecode]
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
   
   -- Get SKU, QTY
   IF EXISTS( SELECT 1 
      FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @c_LabelNo
            AND StorerKey = @c_Storerkey
            AND Status = '0')   
   BEGIN
      DECLARE @cLangCode     NVARCHAR( 3)
      DECLARE @cSKU          NVARCHAR( 20)
      DECLARE @nQTY          INT
      DECLARE @cReceiptKey   NVARCHAR( 10) 
      DECLARE @cPOKey        NVARCHAR( 10) 
      DECLARE @cPOLineNumber NVARCHAR( 5) 
      DECLARE @cExternKey    NVARCHAR( 20)

      -- Get login info
      SELECT 
         @cLangCode = Lang_Code, 
         @cReceiptKey = V_ReceiptKey
      FROM rdt.rdtMobRec WITH (NOLOCK) 
      WHERE UserName = SUSER_SNAME()      

      -- Get UCC info
      SELECT TOP 1 
         @cSKU = SKU, 
         @nQTY = QTY, 
         @cExternKey    = ExternKey, 
         @cPOKey        = SUBSTRING(UCC.Sourcekey, 1, 10), 
         @cPOLineNumber = SUBSTRING(UCC.Sourcekey, 11, 5)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @c_LabelNo
         AND StorerKey = @c_Storerkey
         AND Status = '0'

      -- Check UCC in ASN
      IF NOT EXISTS( SELECT 1 
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND ExternReceiptKey = @cExternKey
            AND POKey = @cPOKey
            AND POLineNumber = @cPOLineNumber)
      BEGIN
         SET @n_ErrNo = 56401
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --UCC not in ASN
         GOTO Quit
      END

      -- Stamp UCC received
      UPDATE dbo.UCC SET
         Status = '1'
      WHERE UCCNo = @c_LabelNo
         AND StorerKey = @c_Storerkey      

      SET @c_oFieled01 = @cSKU
      SET @c_oFieled05 = @nQTY
   END
   
QUIT:
END -- End Procedure



GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispQSHKLabelNoDecode                                */
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
/* 07-11-2013  1.0  Ung         SOS293944. Created                      */
/* 24-02-2017  1.1  TLTING 1.3  Bug fix                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispQSHKLabelNoDecode]
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
   
   DECLARE @cSKU      NVARCHAR(20)
   DECLARE @cFacility NVARCHAR(5)
   DECLARE @cUDF08    NVARCHAR(30)

   SET @cSKU = ''
   SET @cFacility = ''
   SET @cUDF08 = ''

   -- Get facility
   SELECT TOP 1 
      @cFacility = Facility 
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE UserName = SUSER_NAME()
   ORDER BY EditDate DESC

   -- Get facility UDF8
   SELECT @cUDF08 = UserDefine08
   FROM Facility WITH (NOLOCK)
   WHERE Facility = @cFacility

   -- Get SKU
   SELECT @cSKU = SKU
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @c_Storerkey 
      AND @c_LabelNo IN (SKU, AltSKU)
      AND BUSR10 = @cUDF08
   
   -- Return value
   IF @@ROWCOUNT = 0
   BEGIN
      SET @n_ErrNo = 60557  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, 'ENG', 'DSP') --'Invalid SKU'  
      GOTO Quit
   END

   SET @c_oFieled01 = @cSKU
   SET @c_oFieled08 = ''
   
QUIT:
END -- End Procedure


GO
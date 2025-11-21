SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispDysonLBLNoDecode                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Default QTY base on Receipt.DocType                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 04-05-2017  1.0  Ung         WMS-1817 Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispDysonLBLNoDecode]
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
   
   DECLARE @cSKU     NVARCHAR( 30)
   DECLARE @nQTY     INT
   DECLARE @nSKUCnt  INT
   DECLARE @nCaseCnt INT
   DECLARE @cDocType NVARCHAR( 1)

   SET @cSKU = LEFT( @c_LabelNo, 30)
   SET @nQTY = 0

   EXEC RDT.rdt_GETSKUCNT
       @cStorerKey  = @c_Storerkey
      ,@cSKU        = @cSKU
      ,@nSKUCnt     = @nSKUCnt        OUTPUT
      ,@bSuccess    = @b_Success      OUTPUT
      ,@nErr        = @n_ErrNo        OUTPUT
      ,@cErrMsg     = @c_ErrMsg       OUTPUT
   IF @n_ErrNo <> 0
      GOTO Quit

   IF @nSKUCnt <> 1
      GOTO Quit
      
   -- Get SKU
   EXEC [RDT].[rdt_GETSKU]
       @cStorerKey  = @c_Storerkey
      ,@cSKU        = @cSKU          OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_ErrNo       OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT
   IF @n_ErrNo <> 0
      GOTO Quit
      
   -- Get SKU info
   SELECT 
      @nCaseCnt = CAST( Pack.CaseCnt AS INT)
   FROM dbo.SKU WITH (NOLOCK) 
      JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE SKU.StorerKey = @c_Storerkey 
      AND SKU.SKU = @cSKU

   -- Get ASN info
   SELECT @c_ReceiptKey = V_ReceiptKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()
   SELECT @cDocType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @c_ReceiptKey
   
   -- Get QTY
   IF @cDocType = 'A'
      SET @nQTY = @nCaseCnt
   IF @cDocType = 'R'
      SET @nQTY = 1
      
   -- Return value
   IF @cSKU <> '' SET @c_oFieled01 = @cSKU
   IF @nQTY <> 0  SET @c_oFieled05 = CAST( @nQTY AS NVARCHAR( 20))
     
Quit:

END


GO
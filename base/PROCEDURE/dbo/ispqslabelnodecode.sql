SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispQSLabelNoDecode                                  */
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
/* 23-03-2012  1.0  Ung         SOS239384. Created                      */
/* 10-07-2012  1.1  Ung         Not overwrite QTY if UOM is master      */
/* 25-06-2018  1.2  James       WMS5311-Add function id, step (james01) */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispQSLabelNoDecode]
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
   
   DECLARE @cSKU     NVARCHAR( 20)
   DECLARE @cUOM     NVARCHAR( 10)
   DECLARE @nQTY     INT
   DECLARE @cPackKey NVARCHAR( 10)
   DECLARE @nFunc    INT
   DECLARE @nStep    INT

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
         SET @cSKU = ''
         SET @cUOM = ''
         SET @nQTY = 0
         SET @cPackKey = ''

         -- Get SKU
         SELECT 
            @cSKU = SKU, 
            @cUOM = UOM, 
            @cPackKey = PackKey
         FROM dbo.UPC WITH (NOLOCK) 
         WHERE StorerKey = @c_Storerkey 
            AND UPC = @c_LabelNo
   
         -- Get QTY
         SELECT @nQTY = CASE
            WHEN @cUOM = PackUOM1 THEN CAST( CaseCnt    AS INT)
            WHEN @cUOM = PackUOM2 THEN CAST( InnerPack  AS INT)
            WHEN @cUOM = PackUOM3 THEN 0 --CAST( QTY        AS INT) -- To allow user overwrite
            WHEN @cUOM = PackUOM4 THEN CAST( Pallet     AS INT)
            WHEN @cUOM = PackUOM5 THEN CAST( Cube       AS INT)
            WHEN @cUOM = PackUOM6 THEN CAST( GrossWGT   AS INT)
            WHEN @cUOM = PackUOM7 THEN CAST( NetWGT     AS INT)
            WHEN @cUOM = PackUOM8 THEN CAST( OtherUnit1 AS INT)
            WHEN @cUOM = PackUOM9 THEN CAST( OtherUnit2 AS INT)
            END
         FROM dbo.Pack WITH (NOLOCK)
         WHERE PackKey = @cPackKey
   
         -- Return value
         IF @cSKU <> '' SET @c_oFieled01 = @cSKU
         IF @nQTY <> 0  SET @c_oFieled05 = CAST( @nQTY AS NVARCHAR( 20))
      END
   END
     
QUIT:
END -- End Procedure


GO
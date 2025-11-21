SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispIDTXLabelNoDecode                                */
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
/* 03-09-2012  1.0  Ung         SOS254312. Created                      */
/* 14-12-2012  1.1  James       SOS261739 Enhancement (james01)         */
/* 25-06-2018  1.2  James       WMS5311-Add function id, step (james02) */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispIDTXLabelNoDecode]
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

   DECLARE @c_SKU           NVARCHAR( 20), 
           @c_LOC           NVARCHAR( 20), 
           @c_ID            NVARCHAR( 18), 
           @n_Mobile        INT,  
           @n_QTY           INT, 
           @n_AvlQTY        INT,
           @n_Func          INT,
           @n_Step          INT

   SELECT @n_Func = Func, 
          @n_Step = Step,
          @c_LOC = V_String1, 
          @c_ID = V_String2
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE UserName = sUser_sName()

   IF @n_Func = 513
   BEGIN
      IF @n_Step = 3
         GOTO DECODE_SKU
      ELSE
         GOTO Quit
   END
   ELSE IF @n_Func IN ( 1580, 1581)
   BEGIN
      IF @n_Step = 3  -- TOID
      BEGIN
         SET @c_oFieled01 = @c_LabelNo
         GOTO Quit
      END
      ELSE IF @n_Step = 5
         GOTO DECODE_SKU
      ELSE
         GOTO Quit
   END

   DECODE_SKU:   
   -- Get SKU, QTY
   IF LEN( RTRIM( @c_LabelNo)) = 18 -- (james01)
   BEGIN
      SET @c_SKU = LEFT( @c_LabelNo, 13) -- SKU
      SET @n_QTY = CAST( SUBSTRING( @c_LabelNo, 14, 4) AS INT) -- QTY

      EXEC ispInditexConvertQTY 'ToDispQTY', @c_Storerkey, @c_SKU, @n_QTY OUTPUT

      SET @c_oFieled01 = @c_SKU
      SET @c_oFieled05 = @n_QTY
   END
   ELSE
   BEGIN
      -- Assume if barcode < 18 then user key in sku
      SET @c_SKU = @c_LabelNo
      SET @c_oFieled01 = @c_SKU
      SET @c_oFieled05 = CASE WHEN ISNULL(@c_oFieled05, '') <> '' THEN @c_oFieled05 ELSE '' END
   END

   -- Get QTY avail
   SELECT @n_AvlQTY = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
   FROM dbo.LOTxLOCxID WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND   LOC = @c_LOC
   AND   ID = @c_ID
   AND   SKU = @c_SKU
   
   EXEC ispInditexConvertQTY 'ToDispQTY', @c_Storerkey, @c_SKU, @n_AvlQTY OUTPUT
   
   SET @c_oFieled10 = @n_AvlQTY
QUIT:
END -- End Procedure


GO
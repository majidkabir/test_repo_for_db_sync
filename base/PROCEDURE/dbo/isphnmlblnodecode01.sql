SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispHnMLblNoDecode01                                 */
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
/* 26-02-2014  1.0  James       SOS301646. Created                      */
/* 02-01-2018  1.1  James       WMS3666 - Add config to control the     */
/*                              decoding method (james01)               */
/* 25-06-2018  1.2  James       WMS5311-Add function id, step (james02) */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispHnMLblNoDecode01]
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
           @c_Lot01     NVARCHAR( 18), 
           @c_Lot02     NVARCHAR( 18), 
           @c_Lot02_1   NVARCHAR( 18), 
           @c_Lot02_2   NVARCHAR( 18), 
           @c_Lot       NVARCHAR( 10),
           @cDecodeUCCNo NVARCHAR( 1),
           @n_Func      INT,
           @n_Step      INT,
           @n_InputKey  INT

   IF ISNULL( @c_LabelNo, '') = ''
      GOTO Quit

   SELECT @n_Func = Func, 
          @n_Step = Step,
          @n_InputKey = InputKey
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE UserName = sUser_sName()

   IF @n_InputKey = 1
   BEGIN
      IF @n_Func = 523
      BEGIN
         IF @n_Step = 1
         BEGIN
            SET @c_oFieled01 = @c_LabelNo
            GOTO Quit
         END
         ELSE IF @n_Step = 2
            GOTO DECODE_SKU
         ELSE
            GOTO Quit
      END
      ELSE
      IF @n_Func = 513
      BEGIN
         IF @n_Step = 3
            GOTO DECODE_SKU
         ELSE
            GOTO Quit
      END

      DECODE_SKU:
      SET @cDecodeUCCNo = rdt.RDTGetConfig( @n_Func, 'DecodeUCCNo', @c_Storerkey)

      IF @cDecodeUCCNo = '1'
         SET @c_LabelNo = SUBSTRING( @c_LabelNo, 1, 2)

      -- Lottable01
      SET @c_Lot01 = SUBSTRING( RTRIM( @c_LabelNo), 1, 2)

      -- SKU
      SET @c_SKU = SUBSTRING( RTRIM( @c_LabelNo), 3, 13)

      --Lottable02
      SET @c_Lot02_1 = SUBSTRING( RTRIM( @c_LabelNo), 16, 12)
      SET @c_Lot02_2 = SUBSTRING( RTRIM( @c_LabelNo), 28, 2)
      SET @c_Lot02 = RTRIM( @c_Lot02_1) + '-' + RTRIM( @c_Lot02_1)

      -- Get Lot#
      SELECT TOP 1 @c_Lot = LOT 
      FROM dbo.LotAttribute WITH (NOLOCK) 
      WHERE StorerKey = @c_Storerkey
      AND   SKU = @c_SKU
      AND   Lottable01 = @c_Lot01
      AND   Lottable02 = @c_Lot02
   
      SET @c_oFieled01 = @c_SKU
      SET @c_oFieled09 = @c_Lot
   END
QUIT:
END -- End Procedure


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_US_LCI_LPNDecode                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode US LCI Carton LPN# (UCC#)                            */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 19-Sep-2011 1.0  Shong       Created                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_US_LCI_LPNDecode]
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
   @b_Success          INT      OUTPUT,
   @n_ErrNo            INT      OUTPUT,
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_LOT       NVARCHAR(10),
           @c_UCC       NVARCHAR(20),
           @c_Style     NVARCHAR(20),
           @c_Color     NVARCHAR(10),
           @c_Size      NVARCHAR(5),
           @c_QTY       NVARCHAR(5),
           @c_SKU       NVARCHAR(20),
           @c_LabelType NVARCHAR(20)

   SELECT @c_oFieled01  = '',
          @c_oFieled02  = '',
          @c_oFieled03  = '',
          @c_oFieled04  = '',
          @c_oFieled05  = '',
          @c_oFieled06  = '',
          @c_oFieled07  = '',
          @c_oFieled08  = '',
          @c_oFieled09  = '',
          @c_oFieled10  = ''

   SELECT @c_LOT  = '',
          @c_UCC   = '',
          @c_Style = '',
          @c_Color = '',
          @c_Size  = '',
          @c_QTY   = '0',
          @c_SKU   = ''

   -- Decode by SKU
	SET @c_SKU = @c_LabelNo
   SET @b_Success = 0
   EXECUTE nspg_GETSKU
      @c_StorerKey  = @c_StorerKey,
      @c_SKU        = @c_SKU     OUTPUT,
      @b_Success    = @b_Success OUTPUT,
      @n_Err        = @n_ErrNo   OUTPUT,
      @c_Errmsg     = @c_Errmsg  OUTPUT
   IF @b_Success = 1
   BEGIN
      SELECT @c_Style = ISNULL(RTRIM(Style), ''),
             @c_Color = ISNULL(RTRIM(Color), ''),
             @c_Size  = ISNULL(RTRIM(Size), '')
      FROM SKU WITH (NOLOCK)
      WHERE Storerkey = RTRIM(@c_Storerkey)
      AND   SKU = RTRIM(@c_SKU)

      SET @c_QTY = '1'
      SET @c_LOT = ''
      SET @c_LabelType = 'SKU'
      SET @c_UCC = ''

      GOTO Quit
   END

   -- Decode by UCC
   SET @c_SKU = ''
   SET @c_UCC = @c_LabelNo
   SELECT @c_SKU = ISNULL(SKU,''),
          @c_QTY = CAST(ISNULL(Qty, 0) AS NVARCHAR(10)),
          @c_LOT = ISNULL(LOT,'')
   FROM UCC WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND   UCCNo = @c_UCC

	IF @@ROWCOUNT = 0
	BEGIN
      SET @b_Success = 0
      SET @n_ErrNo = 71745
      SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Invalid SKU'
      GOTO Fail
	END

   SET @c_Style = ''
   SET @c_Color = ''
   SET @c_Size  = ''
	SET @c_LabelType = 'UCC'

Quit:
   SET @b_Success = 1
   SET @n_ErrNo = 0
   SET @c_Errmsg = ''
   SET @c_oFieled01 = RTRIM(@c_SKU)
   SET @c_oFieled02 = RTRIM(@c_Style)
   SET @c_oFieled03 = RTRIM(@c_Color)
   SET @c_oFieled04 = RTRIM(@c_Size)
   SET @c_oFieled05 = RTRIM(CONVERT ( INT, @c_QTY))
   SET @c_oFieled06 = RTRIM(@c_LOT)
   SET @c_oFieled07 = @c_LabelType
   SET @c_oFieled08 = @c_UCC

Fail:
END

GO
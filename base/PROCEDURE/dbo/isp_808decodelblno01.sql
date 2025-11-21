SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: isp_808DecodeLBLNo01                                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: key-in SP (short pick) to skip SKU verify when no physical stock  */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 23-07-2015  1.0  Ung         SOS347418 Created                             */
/******************************************************************************/

CREATE PROCEDURE [dbo].[isp_808DecodeLBLNo01]
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

   DECLARE @n_Func INT 

   -- Get function
   SET @n_Func = 0
   SELECT @n_Func = Func FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = sUser_sName()

   -- Get SKU if key-in SP
   IF @n_Func = 808 AND @c_LabelNo = 'SP'
      SELECT @c_oFieled01 = V_SKU FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()
   ELSE
      SET @c_oFieled01 = @c_LabelNo

END

GO
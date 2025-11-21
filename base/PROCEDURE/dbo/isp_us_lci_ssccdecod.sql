SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_US_LCI_SSCCDecod                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode US LCI SSCC on tote                                  */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 12-Dec-2011 1.0  Ung         Created                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_US_LCI_SSCCDecod]
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
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF 

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
          
   -- Truncate label
   IF LEN( RTRIM( @c_LabelNo)) = 20
      SET @c_LabelNo = SUBSTRING( @c_LabelNo, 11, 9)
      
   SET @c_oFieled01 = @c_LabelNo
   SET @n_ErrNo = 0
   SET @c_ErrMsg = ''

Fail:
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispSCNLblNoDecode01                                 */
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
/* 26-09-2013  1.0  James       SOS289765 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispSCNLblNoDecode01]
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
           @c_Length        NVARCHAR( 20), 
           @n_Length        INT, 
           @n_LblLength     INT

   SET @n_ErrNo = 0
   
   SET @c_Length = @c_oFieled01
   
   IF ISNULL( @c_Length, '') = '' OR @c_Length = '0' OR ISNUMERIC( @c_Length) <> '1'
   BEGIN
      SET @c_oFieled02 = @c_LabelNo
      GOTO Quit
   END
   ELSE
      SET @n_Length = CAST( @c_Length AS INT)

   SET @n_LblLength = 0
   SET @n_LblLength = LEN(ISNULL(RTRIM(@c_LabelNo),''))
   
   -- Retrieve req sku length
   -- SET @c_SKU = SUBSTRING( RTRIM( @c_LabelNo), 1, LEN( RTRIM( @c_LabelNo)) - @n_Length)
   SET @c_SKU = LEFT(ISNULL(RTRIM(@c_LabelNo), ''), (@n_LblLength - @n_Length))
   SET @c_oFieled02 = @c_SKU
QUIT:
END -- End Procedure


GO
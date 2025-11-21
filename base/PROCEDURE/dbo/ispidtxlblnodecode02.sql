SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispIDTXLblNoDecode02                                */
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
/************************************************************************/

CREATE PROCEDURE [dbo].[ispIDTXLblNoDecode02]
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

   DECLARE @c_DistCtr       NVARCHAR( 4), 
           @c_ConsigneeKey  NVARCHAR( 15), 
           @c_Section       NVARCHAR( 1), 
           @c_Separate      NVARCHAR( 1), 
           @n_Mobile        INT  

   SET @c_DistCtr = SUBSTRING( RTRIM( @c_LabelNo), 1, 4) 
   SET @c_ConsigneeKey = SUBSTRING( RTRIM( @c_LabelNo), 5, 4)
   SET @c_Section = SUBSTRING( RTRIM( @c_LabelNo), 9, 1) 
   SET @c_Separate = SUBSTRING( RTRIM( @c_LabelNo), 10, 1) 

   IF SUBSTRING(RTRIM( @c_ConsigneeKey), 1, 1) = '0' 
   BEGIN
      WHILE SUBSTRING(RTRIM( @c_ConsigneeKey), 1, 1) = '0'
      BEGIN
         SET @c_ConsigneeKey = RIGHT(RTRIM( @c_ConsigneeKey), LEN( RTRIM( @c_ConsigneeKey) - 1))
      END
   END

   SET @c_ConsigneeKey = 'ITX' + RTRIM( @c_ConsigneeKey)

   SET @c_oFieled01 = @c_DistCtr
   SET @c_oFieled02 = @c_ConsigneeKey
   SET @c_oFieled03 = @c_Section
   SET @c_oFieled04 = @c_Separate

QUIT:
END -- End Procedure


GO
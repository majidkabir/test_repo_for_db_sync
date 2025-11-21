SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store procedure: ispHnMLblNoDecode02                                 */
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
/* 27-02-2014  1.0  James       SOS304353 Created                       */
/* 22-06-2015  1.1  Ung         SOS332714 Add smart cart module         */
/* 02-01-2018  1.2  James       WMS3666 - Add config to control the     */
/*                              decoding method (james01)               */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispHnMLblNoDecode02]
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

   DECLARE @n_LblLength           INT, 
           @n_Func                INT,
           @cDecodeUCCNo          NVARCHAR( 1)

   SET @n_Func = 0
   SELECT @n_Func = Func FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = sUser_sName()

   SET @n_ErrNo = 0

   SET @cDecodeUCCNo = rdt.RDTGetConfig( @n_Func, 'DecodeUCCNo', @c_Storerkey)

   IF @cDecodeUCCNo = '1'
      SET @c_LabelNo = RIGHT( @c_LabelNo, LEN(@c_LabelNo) - 2)
         
   SET @n_LblLength = 0
   SET @n_LblLength = LEN(ISNULL(RTRIM(@c_LabelNo),''))

   IF @n_LblLength = 0
      SET @c_ErrMsg = 'Invalid SKU'   --Return Error

   -- If SKU screen return error after decode, e.g. qty error 
   -- then screen will become valid SKU after decode
   -- press ENTER 2nd time then take this SKU, no decode needed
   IF @n_Func IN (1620, 1621, 1628, 808)
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                  WHERE StorerKey = @c_Storerkey
                  AND   SKU = @c_LabelNo)
         SET @c_oFieled01 = @c_LabelNo
      ELSE
         IF @n_Func = 808 AND @c_LabelNo = 'SP'
            SELECT @c_oFieled01 = V_SKU FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()
         ELSE
            SET @c_oFieled01 = SUBSTRING( RTRIM( @c_LabelNo), 3, 13) -- SKU
   END
   ELSE
      SET @c_oFieled01 = SUBSTRING( RTRIM( @c_LabelNo), 3, 13) -- SKU
QUIT:
END -- End Procedure


GO
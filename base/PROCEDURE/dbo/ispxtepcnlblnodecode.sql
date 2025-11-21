SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispXTEPCNLblNoDecode                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Mannings Decode Label No Scanned                            */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 09-03-2010  1.0  ChewKP      Created                                 */
/* 26-05-2014  1.1  Ung         SOS312251. Fix QTY is reset when decode */
/* 25-06-2018  1.2  James       WMS5311-Add function id, step (james01) */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispXTEPCNLblNoDecode]
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue     INT,
           @b_debug        INT,
           @n_Func         INT,
           @n_Step         INT

   DECLARE @c_SKU         NVARCHAR(40), 
           @n_LblLength   INT

   SELECT @n_Func = Func,
          @n_Step = Step
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE UserName = sUser_sName()

   SELECT @b_Success = 1, @n_ErrNo = 0, @b_debug = 0

   --IF @n_Func NOT IN (513, 523, 555, 556, 610, 731, 840, 841, 867, 1580, 1581)
   --   GOTO Quit

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
   ELSE IF @n_Func = 513
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
   SELECT @c_SKU   = ''

   SET @n_LblLength = 0
   SET @n_LblLength = LEN(ISNULL(RTRIM(@c_LabelNo),''))
   
   
   IF (@n_LblLength >= 20)
   BEGIN
      SET @c_SKU = LEFT(ISNULL(RTRIM(@c_LabelNo), ''), (@n_LblLength - 6))
   END
   ELSE
   BEGIN
      SET @c_SKU = @c_LabelNo          
   END
   
   IF @b_Success <> 0
   BEGIN
        SET @c_oFieled01 = RTRIM(@c_SKU)
        SET @c_oFieled02 = ISNULL( @c_oFieled02, '')
        SET @c_oFieled03 = ISNULL( @c_oFieled03, '')
        SET @c_oFieled04 = ISNULL( @c_oFieled04, '')
        SET @c_oFieled05 = ISNULL( @c_oFieled05, '')
        SET @c_oFieled06 = ISNULL( @c_oFieled06, '')
        SET @c_oFieled07 = ISNULL( @c_oFieled07, '')
        SET @c_oFieled08 = ISNULL( @c_oFieled08, '')
        SET @c_oFieled09 = ISNULL( @c_oFieled09, '')
        SET @c_oFieled10 = ISNULL( @c_oFieled10, '')
   END    

   IF @b_debug = 1
   BEGIN
     SELECT '@c_SKU',       @c_SKU
     SELECT '@c_oFieled01', @c_oFieled01
     SELECT '@c_oFieled02', @c_oFieled02
     SELECT '@c_oFieled03', @c_oFieled03
     SELECT '@c_oFieled04', @c_oFieled04
     SELECT '@c_oFieled05', @c_oFieled05
     SELECT '@c_oFieled06', @c_oFieled06
     SELECT '@c_ErrMsg', @c_ErrMsg
   END

     
QUIT:
END -- End Procedure


GO
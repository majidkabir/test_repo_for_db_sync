SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispLFALblNoDecode05                                 */
/* Copyright      : LF                                                  */
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
/* 26-05-2015  1.0  ChewKP      SOS#351702. Created                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispLFALblNoDecode05]
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@c_LangCode	        NVARCHAR(3),
	@c_oFieled01         NVARCHAR(20) OUTPUT,
	@c_oFieled02         NVARCHAR(20) OUTPUT,
   @c_oFieled03         NVARCHAR(20) OUTPUT,
   @c_oFieled04         NVARCHAR(20) OUTPUT,
   @c_oFieled05         NVARCHAR(20) OUTPUT,
   @c_oFieled06         NVARCHAR(20) OUTPUT,
   @c_oFieled07         NVARCHAR(20) OUTPUT,
   @c_oFieled08         NVARCHAR(20) OUTPUT,
   @c_oFieled09         NVARCHAR(20) OUTPUT,
   @c_oFieled10         NVARCHAR(20) OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @cSKU       NVARCHAR( 20),
            @nStep      INT,
            @nMobileNo  INT,
            @nFunc      INT,
            @cSerialNo  NVARCHAR(10)
           
   
            
   SELECT @nStep = Step
         ,@nFunc = Func
         ,@nMobileNo = Mobile
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE UserName = (suser_sname())
   
   
   SET @c_oFieled01 = ''
   SET @c_oFieled07 = ''
   
   


   IF @nFunc = 867 
   BEGIN
         IF Len(RTRIM(@c_LabelNo)) <> 20 
         BEGIN
             SET @c_ErrMsg = 'Wrong Code'
             GOTO QUIT
         END
   
         SET @cSKU = LEFT(RTRIM(@c_LabelNo),10) 
         SET @cSerialNo = RIGHT(RTRIM(@c_LabelNo),10) 
     
    
         SET @c_oFieled01 = @cSKU
         SET @c_oFieled07 = @cSerialNo

   END

   
   
   
   
QUIT:
END -- End Procedure


GO
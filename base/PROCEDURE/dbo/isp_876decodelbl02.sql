SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_876DecodeLBL02                                  */
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
/* 30-06-2014  1.0  James       SOS314637 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_876DecodeLBL02]
   @nMobile            INT,   
   @nFunc              INT,    
   @c_CodeString       NVARCHAR(MAX),
   @c_Storerkey        NVARCHAR(15),
   @c_OrderKey         NVARCHAR(10),
   @c_LangCode	        NVARCHAR(3),
	@c_oFieled01        NVARCHAR(20) OUTPUT,  -- SerialNo   
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

   DECLARE @c_String    NVARCHAR(MAX) 

   SET @c_String = RTRIM( ISNULL( @c_CodeString, ''))

   IF ISNULL( @c_String, '') = '' 
      GOTO Quit
   ELSE
   BEGIN
      SET @c_oFieled01 = SUBSTRING( @c_String, CHARINDEX( '=', @c_String) + 1, LEN( @c_String) - CHARINDEX( '=', @c_String))
      SET @c_oFieled02 = ''
   END

QUIT:
END -- End Procedure


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1016DecodeLBL01                                 */  
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
/* 06-11-2017  1.0  ChewKP      Created                                 */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[rdt_1016DecodeLBL01]  
   @c_LabelNo          NVARCHAR(40),  
   @c_Storerkey        NVARCHAR(15),  
   @c_ReceiptKey       NVARCHAR(10),  
   @c_POKey            NVARCHAR(10),  
   @c_LangCode         NVARCHAR(3),  
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
  
   DECLARE @nRowCount      INT  
          ,@cADCode        NVARCHAR(20) 
          ,@nCharIndex     INT
          ,@nLabelLength   INT
   
  
   SET @n_ErrNo = 0  
   SET @c_ErrMsg = ''  
   SET @cADCode = ''
   
   SET @nCharIndex = CHARINDEX( '91' , @c_LabelNo ) + 2 
   SET @nLabelLength = LEN(@c_LabelNo) 

   IF @nLabelLength = 10 
   BEGIN
      SET @cADCode = @c_LabelNo 
   END
   ELSE IF @nLabelLength >= 20
   BEGIN
      SET @cADCode = Substring(@c_LabelNo , @nCharIndex , @nLabelLength) 
   END
  
   IF @cADCode = '' 
   BEGIN
      SET @n_ErrNo = -1
   END
   ELSE 
   BEGIN
      IF LEN(RTRIM(@cADCode)) <> 10 
      BEGIN
         SET @n_ErrNo = -1
      END
      ELSE
      BEGIN
         SET @c_oFieled02 = @cADCode  
         --SET @c_oFieled05 = @nUCCQTY  
         --SET @c_oFieled08 = @cUCCNo  
      END
   END
  
END -- End Procedure  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispLabelNo_Decoding_Wrapper                         */
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
/* 09-Jan-2009 1.0  Vicky       Created                                 */
/* 25-Apr-2013 1.1  Ung         Fix UPC should allow 30 chars (ung01)   */  
/* 26-Mar-2014 1.2  Ung         SOS306108 Expand LabelNo 60 char (ung02)*/
/* 2023-02-16  1.3  WyeChun     JSM-129049 Extend oField09 (20) length  */    
/*                              to 40 to store the proper barcode (WC01)*/  
/************************************************************************/

CREATE PROC [dbo].[ispLabelNo_Decoding_Wrapper] (
   @c_SPName           NVARCHAR(250),
   @c_LabelNo          NVARCHAR(60), --(ung02)
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@c_LangCode	        NVARCHAR(3),
   @c_oFieled01        NVARCHAR(60) OUTPUT, --(ung01)  
	@c_oFieled02        NVARCHAR(20) OUTPUT,
   @c_oFieled03        NVARCHAR(20) OUTPUT,
   @c_oFieled04        NVARCHAR(20) OUTPUT,
   @c_oFieled05        NVARCHAR(20) OUTPUT,
   @c_oFieled06        NVARCHAR(20) OUTPUT,
   @c_oFieled07        NVARCHAR(20) OUTPUT,
   @c_oFieled08        NVARCHAR(20) OUTPUT,
   @c_oFieled09        NVARCHAR(40) OUTPUT,    --WC01  
   @c_oFieled10        NVARCHAR(20) OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
)
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQLStatement   nvarchar(2000), 
           @cSQLParms       nvarchar(2000)

   DECLARE @b_debug  int 
   SET @b_debug = 0

   IF @c_SPName = '' OR @c_SPName IS NULL
   BEGIN
      SET @b_Success = 0
      SET @n_ErrNo = 66151    
      SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Stored Proc Not Setup. (ispLabelNo_Decoding_Wrapper)'
      GOTO QUIT
   END
      
   IF @b_debug = 1
   BEGIN
     SELECT '@c_SPName', @c_SPName
   END

   IF @c_LabelNo = '' OR @c_LabelNo IS NULL
   BEGIN
      SET @b_Success = 0
      SET @n_ErrNo = 66152    
      SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Blank LabelNo. (ispLabelNo_Decoding_Wrapper)'
      GOTO QUIT
   END
      
   IF @b_debug = 1
   BEGIN
     SELECT '@c_LabelNo', @c_LabelNo
   END

   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')
   BEGIN

	   SET @cSQLStatement = N'EXEC ' + RTrim(@c_SPName) + 
	       ' @c_LabelNo, @c_Storerkey, @c_ReceiptKey, @c_POKey, @c_LangCode,' +
          ' @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT,' +
          ' @c_oFieled04 OUTPUT, @c_oFieled05 OUTPUT, @c_oFieled06 OUTPUT,' +
          ' @c_oFieled07 OUTPUT, @c_oFieled08 OUTPUT, @c_oFieled09 OUTPUT,' +
          ' @c_oFieled10 OUTPUT, @b_Success   OUTPUT, @n_ErrNo     OUTPUT,' +
          ' @c_ErrMsg    OUTPUT '
	
	   SET @cSQLParms = N'@c_LabelNo          NVARCHAR(40),        ' +
                        '@c_Storerkey        NVARCHAR(15),           ' +
                        '@c_ReceiptKey       NVARCHAR(10),           ' +
                        '@c_POKey            NVARCHAR(10),           ' +
                        '@c_LangCode         NVARCHAR(3),            ' +
                        '@c_oFieled01        NVARCHAR(60) OUTPUT, ' +  -- (ung01)  
	                     '@c_oFieled02        NVARCHAR(20) OUTPUT, ' + 
	                     '@c_oFieled03        NVARCHAR(20) OUTPUT, ' + 
	                     '@c_oFieled04        NVARCHAR(20) OUTPUT, ' + 
	                     '@c_oFieled05        NVARCHAR(20) OUTPUT, ' + 
	                     '@c_oFieled06        NVARCHAR(20) OUTPUT, ' + 
	                     '@c_oFieled07        NVARCHAR(20) OUTPUT, ' + 
	                     '@c_oFieled08        NVARCHAR(20) OUTPUT, ' + 
                        '@c_oFieled09        NVARCHAR(40) OUTPUT, ' +     --WC01 
	                     '@c_oFieled10        NVARCHAR(20) OUTPUT, ' + 	
                        '@b_Success          INT      OUTPUT,    ' +                     
                        '@n_ErrNo            INT      OUTPUT,    ' +
                        '@c_ErrMsg           NVARCHAR(250) OUTPUT ' 
                        
	   
	   EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
             @c_LabelNo
            ,@c_Storerkey
            ,@c_ReceiptKey
            ,@c_POKey
            ,@c_LangCode
	         ,@c_oFieled01  OUTPUT
	         ,@c_oFieled02  OUTPUT
	         ,@c_oFieled03  OUTPUT
	         ,@c_oFieled04  OUTPUT
	         ,@c_oFieled05  OUTPUT
	         ,@c_oFieled06  OUTPUT
	         ,@c_oFieled07  OUTPUT
	         ,@c_oFieled08  OUTPUT
	         ,@c_oFieled09  OUTPUT
	         ,@c_oFieled10  OUTPUT
            ,@b_Success    OUTPUT
	         ,@n_ErrNo      OUTPUT
	         ,@c_ErrMsg     OUTPUT
   END


   IF @b_debug = 1
   BEGIN
     SELECT '@c_oFieled01', @c_oFieled01
     SELECT '@c_oFieled02', @c_oFieled02
     SELECT '@c_oFieled03', @c_oFieled03
     SELECT '@c_oFieled04', @c_oFieled04
     SELECT '@c_oFieled05', @c_oFieled05
     SELECT '@c_oFieled06', @c_oFieled06
     SELECT '@c_oFieled07', @c_oFieled07
     SELECT '@c_oFieled08', @c_oFieled08
     SELECT '@c_oFieled09', @c_oFieled09
     SELECT '@c_oFieled10', @c_oFieled10
     SELECT '@c_ErrMsg', @c_ErrMsg
   END

QUIT:
END -- procedure


GO
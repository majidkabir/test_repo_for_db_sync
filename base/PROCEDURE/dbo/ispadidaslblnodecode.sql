SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispAdidasLblNoDecode                                */
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
/* 25-10-2010  1.0  ChewKP      Created                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispAdidasLblNoDecode]
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
           @b_debug        INT

   DECLARE @c_CONo    NVARCHAR(14), 
           @c_UPC     NVARCHAR(20),
           @c_Style   NVARCHAR(20),
           @c_Color   NVARCHAR(10),
           @c_Size    NVARCHAR(5),
           @c_QTY     NVARCHAR(5),
           @c_SKU     NVARCHAR(20),
           @c_UserDefine01    NVARCHAR(30),
           @n_LblLength       INT,
           @c_ArticleNo       NVARCHAR(6),
           @c_TechnicalIndex  NVARCHAR(2)
           
           
           

   SELECT @b_Success = 1, @n_ErrNo = 0, @b_debug = 0
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

   SELECT @c_CONo  = '',
          @c_UPC   = '',
          @c_Style = '',
          @c_Color = '',
          @c_Size  = '',
          @c_QTY   = '0',
          @c_SKU   = ''

   

   SET @n_LblLength = 0
   SET @n_LblLength = LEN(ISNULL(RTRIM(@c_LabelNo),''))



   IF (@n_LblLength <> 24) AND (@n_LblLength <> 32)
   BEGIN
         SET @b_Success = 0
         SET @n_ErrNo = 71744
         SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Inv Lbl Length'
         GOTO QUIT
   END
   
   
   
   IF @n_LblLength = 32
   BEGIN
      SET @c_CONo = ISNULL(SUBSTRING(RTRIM(@c_LabelNo), 19, 10), '')
      SET @c_UPC  = ISNULL(SUBSTRING(RTRIM(@c_LabelNo), 5,13), '')
      SET @c_QTY  = ISNULL(SUBSTRING(RTRIM(@c_LabelNo), 19, 3), '0')
   END
   
   IF @n_LblLength = 24
   BEGIN
      SET @c_ArticleNo  = ISNULL(SUBSTRING(RTRIM(@c_LabelNo), 12, 6), '0')
      SET @c_TechnicalIndex  = ISNULL(SUBSTRING(RTRIM(@c_LabelNo), 18, 2), '0')
      SET @c_QTY  = ISNULL(SUBSTRING(RTRIM(@c_LabelNo), 20, 3), '0')
   END
   


   IF @b_debug = 1
   BEGIN
     SELECT '@c_CONo', @c_CONo
     SELECT '@c_UPC',  @c_UPC
     SELECT '@c_QTY',  @c_QTY
     SELECT '@c_ReceiptKey', @c_ReceiptKey
     SELECT '@c_POKey', @c_POKey
     SELECT '@c_TechnicalIndex', @c_TechnicalIndex
     SELECT '@c_ArticleNo', @c_ArticleNo
   END

   
--   IF ISNULL(@c_POKey,'') <> '' 
--   BEGIN
--        IF ISNULL(@c_CONo,'') <>  ISNULL(@c_POKey,'')
--        BEGIN
--            SET @b_Success = 0
--            SET @n_ErrNo = 71741 -- UnMatch POkey
--            SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' UnMatch POkey'
--            GOTO QUIT     
--        END
--        
--        IF NOT EXISTS ( SELECT 1 FROM dbo.PO WITH (NOLOCK) WHERE POKEY = @c_POKey )
--        BEGIN
--            SET @b_Success = 0
--            SET @n_ErrNo = 71742 -- Invalid POkey
--            SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Invalid POkey'
--            GOTO QUIT     
--        END
--   END
   
   
   IF @b_Success <> 0 AND @n_LblLength = 32
   BEGIN
      SELECT @b_success = 0
      EXECUTE nspg_GETSKU
      @c_StorerKey  = @c_StorerKey,
      @c_SKU        = @c_UPC     OUTPUT,
      @b_Success    = @b_Success OUTPUT,
      @n_Err        = @n_ErrNo   OUTPUT,
      @c_Errmsg     = @c_Errmsg  OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SET @b_Success = 0
         SET @n_ErrNo = 71743    
         SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Invalid SKU'
         GOTO QUIT
      END
      ELSE
      BEGIN
         SELECT @c_SKU = @c_UPC

         SELECT @c_Style = ISNULL(RTRIM(Style), ''),
                @c_Color = ISNULL(RTRIM(Color), ''),
                @c_Size  = ISNULL(RTRIM(Size), '')
         FROM SKU WITH (NOLOCK)
         WHERE Storerkey = RTRIM(@c_Storerkey)
         AND   SKU = RTRIM(@c_SKU)
      END
      
   END
   
   
   IF @b_Success <> 0 AND @n_LblLength = 24
   BEGIN
      SELECT @c_SKU = ISNULL(RTRIM(SKU), ''),
             @c_Color = ISNULL(RTRIM(Color), ''),
             @c_Size  = ISNULL(RTRIM(Size), '')
      FROM dbo.SKU WITH (NOLOCK)
      WHERE Style = @c_ArticleNo 
      AND BUSR1 = @c_TechnicalIndex
      AND Storerkey = @c_Storerkey
      
      IF @c_SKU = ''
      BEGIN
         SET @b_Success = 0
         SET @n_ErrNo = 71745    
         SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Invalid SKU'
         GOTO QUIT
      END
      
   END
   
   

   IF @b_Success <> 0
   BEGIN
        SET @c_oFieled01 = RTRIM(@c_SKU)
        SET @c_oFieled02 = RTRIM(@c_Style)
        SET @c_oFieled03 = RTRIM(@c_Color)
        SET @c_oFieled04 = RTRIM(@c_Size)
        SET @c_oFieled05 = RTRIM(CONVERT ( INT,@c_QTY))
        SET @c_oFieled06 = RTRIM(@c_CONo)
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
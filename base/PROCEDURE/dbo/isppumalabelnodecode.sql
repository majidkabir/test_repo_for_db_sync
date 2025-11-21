SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispPumaLabelNoDecode                                */
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
/* 01-Jun-2009 1.0  Vicky       Take out PO.POGroup checking as the     */
/*                              Customer PO now is being inserted to    */
/*                              PODetail.Userdefine05                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPumaLabelNoDecode]
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
           @c_UserDefine01 NVARCHAR(30)

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

   SET @c_CONo = ISNULL(SUBSTRING(RTRIM(@c_LabelNo), 2, 14), '')
   SET @c_UPC  = ISNULL(SUBSTRING(RTRIM(@c_LabelNo), 16,13), '')
   SET @c_QTY  = ISNULL(SUBSTRING(RTRIM(@c_LabelNo), 29, 3), '0')

   IF @b_debug = 1
   BEGIN
     SELECT '@c_CONo', @c_CONo
     SELECT '@c_UPC',  @c_UPC
     SELECT '@c_QTY',  @c_QTY
     SELECT '@c_ReceiptKey', @c_ReceiptKey
     SELECT '@c_POKey', @c_POKey
   END

   -- Note: PO.POGroup checking 
   -- Check If @c_CONo exists in PODetail.Userdefine05, if not prompt error
   IF ISNULL(RTRIM(@c_POKey), '') <> '' AND RTRIM(@c_POKey) <> 'NOPO'
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM PODETAIL WITH (NOLOCK)
                     WHERE POKey = RTRIM(@c_POKey) AND Storerkey = RTRIM(@c_Storerkey)
                     AND UserDefine05 = RTRIM(@c_CONo))
      BEGIN
            SET @b_Success = 0
            SET @n_ErrNo = 66153    
            SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Invalid CO# (ispPumaLabelNoDecode)'
            GOTO QUIT
      END
   END
   ELSE IF (ISNULL(RTRIM(@c_POKey), '') = '' OR RTRIM(@c_POKey) = 'NOPO') AND ISNULL(RTRIM(@c_ReceiptKey), '') <> ''
   BEGIN
       IF NOT EXISTS (SELECT 1 FROM PO WITH (NOLOCK) 
                      JOIN RECEIPTDETAIL WITH (NOLOCK) ON (RECEIPTDETAIL.POKey = PO.POKey AND RECEIPTDETAIL.Storerkey = PO.Storerkey)
                      JOIN PODETAIL WITH (NOLOCK) ON (PODETAIL.POKey = PO.POKey and PODETAIL.Storerkey = PO.Storerkey)
                      WHERE RECEIPTDETAIL.Receiptkey = RTRIM(@c_Receiptkey)
                      AND   RECEIPTDETAIL.Storerkey = RTRIM(@c_Storerkey)
                      AND   PODETAIL.UserDefine05 = RTRIM(@c_CONo))
       BEGIN
            SET @b_Success = 0
            SET @n_ErrNo = 66154    
            SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Invalid CO# (ispPumaLabelNoDecode)'
            GOTO QUIT
      END
   END
   ELSE
   BEGIN
      SET @b_Success = 0
      SET @n_ErrNo = 66155    
      SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' ASN/PO is blank (ispPumaLabelNoDecode)'
      GOTO QUIT
   END
   
   IF @b_Success <> 0
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
         SET @n_ErrNo = 66156    
         SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Invalid UPC/SKU (ispPumaLabelNoDecode)'
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

         IF NOT EXISTS (SELECT 1 FROM PO WITH (NOLOCK) 
                        JOIN RECEIPTDETAIL WITH (NOLOCK) ON (RECEIPTDETAIL.POKey = PO.POKey AND RECEIPTDETAIL.Storerkey = PO.Storerkey)
                        JOIN PODETAIL WITH (NOLOCK) ON (PODETAIL.POKey = PO.POKey and PODETAIL.Storerkey = PO.Storerkey)
                        WHERE RECEIPTDETAIL.Receiptkey = RTRIM(@c_Receiptkey)
                        AND   RECEIPTDETAIL.Storerkey = RTRIM(@c_Storerkey)
                        AND   PODETAIL.UserDefine05 = RTRIM(@c_CONo)
                        AND   RECEIPTDETAIL.SKU = RTRIM(@c_SKU))
         BEGIN
            SET @b_Success = 0
            SET @n_ErrNo = 66157    
            SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' SKU not match (ispPumaLabelNoDecode)'
            GOTO QUIT
         END
      END
   END

   IF @b_Success <> 0
   BEGIN
     SET @c_oFieled01 = RTRIM(@c_SKU)
     SET @c_oFieled02 = RTRIM(@c_Style)
     SET @c_oFieled03 = RTRIM(@c_Color)
     SET @c_oFieled04 = RTRIM(@c_Size)
     SET @c_oFieled05 = RTRIM(@c_QTY)
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
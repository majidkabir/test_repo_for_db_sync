SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenLot2BySuppLot                                        */
/* Creation Date: 02-Apr-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: AQSACM                                                   */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable02                          */
/*           By Ncounter IDSLot_yymmdd                                  */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 21-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLot2BySuppLot]
     @c_Storerkey          NVARCHAR(15)
   , @c_Sku                NVARCHAR(20)
   , @c_Lottable01Value    NVARCHAR(18)
   , @c_Lottable02Value    NVARCHAR(18)
   , @c_Lottable03Value    NVARCHAR(18)
   , @dt_Lottable04Value   DATETIME
   , @dt_Lottable05Value   DATETIME
   , @c_Lottable06Value    NVARCHAR(30)   = ''
   , @c_Lottable07Value    NVARCHAR(30)   = ''
   , @c_Lottable08Value    NVARCHAR(30)   = ''
   , @c_Lottable09Value    NVARCHAR(30)   = ''
   , @c_Lottable10Value    NVARCHAR(30)   = ''
   , @c_Lottable11Value    NVARCHAR(30)   = ''
   , @c_Lottable12Value    NVARCHAR(30)   = ''
   , @dt_Lottable13Value   DATETIME       = NULL
   , @dt_Lottable14Value   DATETIME       = NULL
   , @dt_Lottable15Value   DATETIME       = NULL
   , @c_Lottable01         NVARCHAR(18)            OUTPUT
   , @c_Lottable02         NVARCHAR(18)            OUTPUT
   , @c_Lottable03         NVARCHAR(18)            OUTPUT
   , @dt_Lottable04        DATETIME                OUTPUT
   , @dt_Lottable05        DATETIME                OUTPUT
   , @c_Lottable06         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable07         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable08         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable09         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable10         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable11         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable12         NVARCHAR(30)   = ''     OUTPUT
   , @dt_Lottable13        DATETIME       = NULL   OUTPUT
   , @dt_Lottable14        DATETIME       = NULL   OUTPUT
   , @dt_Lottable15        DATETIME       = NULL   OUTPUT
   , @b_Success            int            = 1      OUTPUT
   , @n_ErrNo              int            = 0      OUTPUT
   , @c_Errmsg             NVARCHAR(250)  = ''     OUTPUT
   , @c_Sourcekey          NVARCHAR(15)   = ''  
   , @c_Sourcetype         NVARCHAR(20)   = ''   
   , @c_LottableLabel      NVARCHAR(20)   = '' 
 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @c_Lottable02Label   NVARCHAR(20),
      @c_Lottable04Label   NVARCHAR(20),
      @c_ReceiptKey        NVARCHAR(10),
      @c_ReceiptLineNo     NVARCHAR(5),
      @c_KeyName           NVARCHAR(13),  --IDSLot_yymmdd
      @c_keystring         NVARCHAR(3),
      @c_DateStr           NVARCHAR(6)

   DECLARE @n_continue     INT,
           @b_debug        INT

   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0

   SET @c_Sourcekey = ISNULL(RTRIM(@c_Sourcekey),'')
   IF ISNULL(RTRIM(@c_Sourcekey),'') = '' 
      SET @n_continue = 3

   IF @b_debug = 1
      SELECT '@c_Sourcekey', @c_Sourcekey

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 

      SET @c_KeyName = ''
      SET @c_keystring = ''
      SET @c_DateStr = ''      
      
      SET @c_ReceiptKey = substring(@c_Sourcekey,1,10) 

      IF @b_debug = 1
      BEGIN
         SELECT '@c_ReceiptKey', @c_ReceiptKey
         SELECT '@c_ReceiptLineNo', @c_ReceiptLineNo
      END

      SELECT @c_Lottable02 = ISNULL(RTRIM(Lottable02),'')
      FROM RECEIPTDETAIL WITH (NOLOCK)
      WHERE STORERKEY = ISNULL(RTRIM(@c_Storerkey),'')
      AND ReceiptKey = @c_ReceiptKey
      AND Sku = ISNULL(RTRIM(@c_Sku),'')
      AND Lottable01 = @c_Lottable01Value

      IF ISNULL(RTRIM(@c_Lottable02),'') = ''
      BEGIN

         SELECT @c_DateStr = CONVERT(char(6), GETDATE(), 12) 
         SET @c_KeyName = 'IDSLot_'+@c_DateStr

         IF @b_debug = 1
         BEGIN
            SELECT '@c_KeyName', @c_KeyName
            SELECT '@c_DateStr', @c_DateStr
         END

         EXECUTE nspg_GetKey
                  @c_KeyName, 
                  3 ,
                  @c_keystring       OUTPUT,
                  @b_success         OUTPUT,
                  @n_ErrNo           OUTPUT,
                  @c_errmsg          OUTPUT

         IF ISNULL(RTRIM(@c_keystring),'') = '001'
         BEGIN
            DELETE FROM NCOUNTER 
            WHERE KEYNAME LIKE 'IDSLot_%' AND KEYNAME <> @c_KeyName
         END
         ELSE IF ISNULL(RTRIM(@c_keystring),'') = '999'
         BEGIN
            UPDATE NCOUNTER WITH (ROWLOCK) SET keycount = 1
            WHERE KEYNAME = @c_KeyName
         END

         SET @c_Lottable02 = @c_DateStr+@c_keystring

      END
   END
      
QUIT:
END -- End Procedure


SET QUOTED_IDENTIFIER OFF 

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispGetLot1FromPO                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Purposes                                      */
/* 2013-04-02   Ung       SOS273757 Created. Default L01 from PO        */
/* 2014-05-28   NJOW      Fix finalize error - set @n_errno=0           */
/* 2013-05-31   Ung       SOS273757 Exclude from ASN Finalize           */
/* 21-May-2014  TKLIM     Added Lottables 06-15                         */
/* 14-Jan-2015  CSCHONG   Add new input parameter (CS01)                */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGetLot1FromPO]
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
   , @c_type               NVARCHAR(10)   = ''     --(CS01)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT @b_Success = 1, @n_ErrNo = 0, @c_Errmsg = ''

   IF @c_Sourcetype IN('RECEIPT','RDTRECEIPT') --'RECEIPTFINALIZE',
   BEGIN
     DECLARE @c_Doctype NVARCHAR(1)
     SELECT @c_Doctype = Doctype
     FROM RECEIPT (NOLOCK)
     WHERE Receiptkey = LEFT(@c_Sourcekey,10)

     IF @c_Doctype IN('R','X')
       GOTO QUIT
   END
   ELSE
   --(Wan01) - START
   BEGIN
      IF @c_Sourcetype NOT IN ('CCOUNT','RDTCCOUNT')
      BEGIN
         GOTO QUIT
      END
   END
   
   DECLARE @cPOKey NVARCHAR( 10)

   --SET @c_Lottable01 = 'X'
   
   -- 1 ASN 1 PO
   SET @cPOKey = ''
   SELECT TOP 1 @cPOKey = POKey
   FROM dbo.ReceiptDetail WITH (NOLOCK) 
   WHERE ReceiptKey = LEFT( @c_Sourcekey, 10)
      AND SKU = @c_SKU

   -- 1 PO 1 SKU
   IF @cPOKey <> ''
      SELECT TOP 1 @c_Lottable01 = Lottable01
      FROM dbo.PODetail WITH (NOLOCK) 
      WHERE POKey = @cPOKey
         AND SKU = @c_SKU

QUIT:
END -- End Procedure


GO
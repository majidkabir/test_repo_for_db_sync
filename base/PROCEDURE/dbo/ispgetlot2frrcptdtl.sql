SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispGetLot2FrRcptDtl                                 */
/* Copyright: IDS                                                       */
/* Purpose: Default lottable02 from ReceiptDetail                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2012-04-02   Ung       1.0   Created                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGetLot2FrRcptDtl]
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
   , @c_type               NVARCHAR(10)   = ''      
   
   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @c_Lottable02 = ''

   -- 1 PO in the same SKU will only have one or 2 kinds of lottable02 receiving
   -- Receive sku with lottable02 = 'ECOM' 1st then the receive the rest
   IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @c_Sourcekey
               AND   SKU = @c_Sku
               AND   Lottable02 = 'ECOM'
               AND  (QTYExpected - BeforeReceivedQTY) > 0)  -- NOT FULLY RECEIPT)
   BEGIN
      SET @c_Lottable02 = 'ECOM'
   END
   ELSE
   BEGIN
      SELECT TOP 1 @c_Lottable02 = Lottable02  
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE ReceiptKey = @c_Sourcekey
      AND   SKU = @c_Sku
      AND   Lottable02 <> 'ECOM'
      AND  (QTYExpected - BeforeReceivedQTY) > 0   -- NOT FULLY RECEIPT)
      GROUP BY Lottable02
      ORDER BY CASE WHEN SUM(QtyExpected) - SUM(BeforeReceivedQty) > 0 
      THEN SUM(QtyExpected) - SUM(BeforeReceivedQty) ELSE 999999999 END

      -- If over receipt, take the lottable02 of last received
      IF ISNULL( @c_Lottable02, '') = ''
         SELECT TOP 1 @c_Lottable02 = Lottable02  
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @c_Sourcekey
         AND   SKU = @c_Sku
         ORDER BY EditDate DESC
   END

END

GO
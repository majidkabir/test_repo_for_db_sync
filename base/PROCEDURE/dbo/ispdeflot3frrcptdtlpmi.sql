SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispDefLot3FrRcptDtl                                 */
/* Copyright: IDS                                                       */
/* Purpose: Default lottable03 from ReceiptDetail                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2024-10-18   Vandy     1.0   UWP-25782 Created                       */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispDefLot3FrRcptDtlPMI]
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
   , @c_type               NVARCHAR(10)   = ''      --(CS01)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLottable03Label NVARCHAR( 20)
   DECLARE @cUserDefine03 NVARCHAR( 30)
   DECLARE @nCount INT
   
   SET @nCount = 0
   SET @cUserDefine03 = ''
   SET @c_Lottable03Value = ''

   -- Get code lookup info
   SELECT @cUserDefine03 = UDF03
   FROM dbo.CodeLkUp WITH (NOLOCK)   
   WHERE ListName = 'LOTTABLE03'  
      AND Storerkey = @c_Storerkey
      AND Code = @c_LottableLabel

   IF @cUserDefine03 <> ''
      SET @c_Lottable03 = @cUserDefine03
   ELSE
   BEGIN
      -- Get receipt detail info
      SELECT 
         @nCount = COUNT( DISTINCT Lottable03), 
         @c_Lottable03Value = MAX( Lottable03)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @c_Sourcekey
         AND SKU = @c_Sku
         AND Lottable03 <> ''
      
      IF @nCount = 1
         SET @c_Lottable03 = @c_Lottable03Value
      ELSE
         SET @c_Lottable03 = ''
   END
END

GO
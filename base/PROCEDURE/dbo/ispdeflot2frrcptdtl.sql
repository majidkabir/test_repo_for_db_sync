SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispDefLot2FrRcptDtl                                 */
/* Copyright: IDS                                                       */
/* Purpose: Default lottable02 from ReceiptDetail                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2012-04-02   Ung       1.0   Created                                 */
/* 2014-05-21   TKLIM     1.1   Added Lottables 06-15                   */
/* 2015-02-05   CSCHONG   1.2   Add new input parameter (CS01)          */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispDefLot2FrRcptDtl]
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

   DECLARE @cLottable02Label NVARCHAR( 20)
   DECLARE @cUserDefine02 NVARCHAR( 30)
   DECLARE @nCount INT
   
   SET @nCount = 0
   SET @cUserDefine02 = ''
   SET @c_Lottable02Value = ''

   -- Get code lookup info
   SELECT @cUserDefine02 = UDF02
   FROM dbo.CodeLkUp WITH (NOLOCK)   
   WHERE ListName = 'LOTTABLE02'  
      AND Code = @c_LottableLabel

   IF @cUserDefine02 <> ''
      SET @c_Lottable02 = @cUserDefine02
   ELSE
   BEGIN
      -- Get receipt detail info
      SELECT 
         @nCount = COUNT( DISTINCT Lottable02), 
         @c_Lottable02Value = MAX( Lottable02)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @c_Sourcekey
         AND Lottable02 <> ''
      
      IF @nCount = 1
         SET @c_Lottable02 = @c_Lottable02Value
      ELSE
         SET @c_Lottable02 = ''
   END
END

GO
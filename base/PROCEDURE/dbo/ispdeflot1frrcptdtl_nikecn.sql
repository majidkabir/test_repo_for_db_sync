SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispDefLot1FrRcptDtl_NIKECN                          */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-05-28   Ung       1.0   WMS-4695 Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispDefLot1FrRcptDtl_NIKECN]
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

   DECLARE @cLottable01Label NVARCHAR( 20)
   DECLARE @cUserDefine01 NVARCHAR( 30)
   DECLARE @nCount INT
   
   DECLARE @n_IsRDT INT  
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   IF @n_IsRDT = 1 
   BEGIN
      -- Get session info
      DECLARE @nFunc INT
      DECLARE @cLangCode NVARCHAR(3)
      SELECT 
         @nFunc = Func, 
         @cLangCode = Lang_Code
      FROM rdt.rdtMobRec WITH (NOLOCK) 
      WHERE UserName = SUSER_SNAME()
      
      -- Piece receiving, NOPO
      IF @nFunc = 1581
      BEGIN
         IF NOT EXISTS( SELECT 1 
            FROM ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @c_Sourcekey 
               AND StorerKey = @c_Storerkey
               AND SKU = @c_Sku
               AND Lottable01 = @c_Lottable01Value)
         BEGIN
            SET @n_ErrNo = 124651
            SET @c_Errmsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --Invalid L01
         END
         ELSE
            SET @c_Lottable01 = @c_Lottable01Value
         
         GOTO Quit
      END
   END

   SET @nCount = 0
   SET @cUserDefine01 = ''
   SET @c_Lottable01Value = ''

   -- Get code lookup info
   SELECT @cUserDefine01 = UDF01
   FROM dbo.CodeLkUp WITH (NOLOCK)   
   WHERE ListName = 'LOTTABLE01'  
      AND Code = @c_LottableLabel

   IF @cUserDefine01 <> ''
      SET @c_Lottable01 = @cUserDefine01
   ELSE
   BEGIN
      -- Get receipt detail info
      SELECT 
         @nCount = COUNT( DISTINCT Lottable01), 
         @c_Lottable01Value = MAX( Lottable01)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @c_Sourcekey
         AND Lottable01 <> ''
      
      IF @nCount = 1
         SET @c_Lottable01 = @c_Lottable01Value
      ELSE
         SET @c_Lottable01 = ''
   END
   
Quit:

END

GO
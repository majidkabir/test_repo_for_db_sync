SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGetLottableTW01                                         */
/* Creation Date: 11-Sep-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: Chew KP                                                  */
/*                                                                      */
/* Purpose:  SOS#289137 Generate Receiptdetail Lottable01 to Lottable04 */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2013-12-03   ChewKP    1.1   SOS#296907 - (ChewKP03)                 */
/* 2014-05-21   TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/
                 
CREATE PROCEDURE [dbo].[ispGetLottableTW01]
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
   , @n_Err                int            = 0      OUTPUT
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
      @c_Lottable01Label   NVARCHAR( 20),
      @c_ReceiptKey        NVARCHAR( 10),
      @c_ReceiptLineNo     NVARCHAR( 5),
      @c_CodeLkupStorerKey NVARCHAR( 15),
      @c_ListName          NVARCHAR( 10),
      @c_UserName          NVARCHAR( 18),
      @c_UCCNo             NVARCHAR( 20),
      @c_POKey             NVARCHAR( 18)

   DECLARE @n_continue     INT,
           @b_debug        INT
           

   SELECT @n_continue = 1, @b_success = 1, @n_Err = 0, @b_debug = 0
   SELECT @c_Lottable02  = ''
   SELECT @c_Lottable03  = ''
   SET @dt_Lottable04 = NULL
   
          
   
   SET @c_ReceiptKey    = LEFT(@c_SourceKey,10) 
   SET @c_ReceiptLineNo = RIGHT(@c_SourceKey,5) 
   
   -- Hardcode StorerKey for the Moments as PB , RDT need CR to enhance the Lottable Request
   IF ISNULL(RTRIM(@c_StorerKey),'')  <> 'TBLTW'
   BEGIN
      GOTO QUIT
   END
   
   IF @c_Sourcetype <> 'RDTUCCRCV' AND @c_Sourcetype <> 'rdtfnc_PieceReceivin'
   BEGIN
      GOTO QUIT
   END
   
   IF @c_Sourcetype = 'RDTUCCRCV'
   BEGIN
      SET @c_UserName = ''
      SET @c_UCCNo    = ''
      SET @c_POKey    = ''
      
      SET @c_UserName = suser_sname()
      
      SELECT @c_UCCNo = I_Field01
      FROM rdt.rdtMobrec WITH (NOLOCK)
      WHERE Func = '898'
      AND UserName = @c_UserName
      Order by EditDate Desc
      
      SELECT @c_POKey = SourceKey 
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo     = @c_UCCNo
      AND   StorerKey = @c_Storerkey
      AND   SKU       = @c_Sku
      
   END
   
   SELECT TOP 1 
              @c_Lottable01 = ISNULL(Lottable01,'')
            , @c_Lottable02 = ISNULL(Lottable02,'')
            , @c_Lottable03 = ISNULL(Lottable03,'')
            , @dt_Lottable04 = ISNULL(Lottable04,'')
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE StorerKey      = @c_Storerkey
         AND ReceiptKey = @c_ReceiptKey
         AND SKU        = @c_Sku
         AND POKey      = CASE WHEN @c_SourceType = 'RDTUCCRCV' THEN @c_POKey ELSE POKey END



QUIT:

END -- End Procedure

GO
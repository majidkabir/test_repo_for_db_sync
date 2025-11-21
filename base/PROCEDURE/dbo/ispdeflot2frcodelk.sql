SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispDefLot2FrCodelk                                  */
/* Copyright: IDS                                                       */
/* Purpose: Default lottable01 from Codelkup                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2021-06-08   Chermaine 1.0   WMS-16334 Created                       */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispDefLot2FrCodelk]
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
   

   DECLARE @cToLoc      NVARCHAR( 10)
   DECLARE @cReceiptKey NVARCHAR( 10) 
   DECLARE @cRecType    NVARCHAR(10)

   SELECT @cToLoc = V_LOC, @cReceiptKey = V_ReceiptKey FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE UserName = SUSER_SNAME()
   SELECT @cRecType = recType FROM receipt WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND ReceiptKey = @cReceiptKey
   
   IF EXISTS (SELECT 1 FROM codelkup WITH (NOLOCK) WHERE listName = 'RTNLOC2L10' AND storerKey = @c_Storerkey AND code = @cToLOC)
       AND @cRecType IN ('RSO-F','RSO-N')  
   BEGIN
   	-- Get code lookup info
      SELECT @c_Lottable02 = long
      FROM dbo.CodeLkUp WITH (NOLOCK)   
      WHERE ListName = 'RTNLOC2L10'  
         AND Code = @cToLoc
         AND storerKey = @c_Storerkey
   	
   END
END

GO
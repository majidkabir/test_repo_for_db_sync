SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispDefL2L3_PRESTIGE                                 */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-09-30   Ung       1.0   SOS????? Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispDefL2L3_PRESTIGE]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(20),
	@c_Lottable01Value  NVARCHAR(18),
	@c_Lottable02Value  NVARCHAR(18),
	@c_Lottable03Value  NVARCHAR(18),
	@dt_Lottable04Value datetime,
	@dt_Lottable05Value datetime,
	@c_Lottable01       NVARCHAR(18) OUTPUT,
	@c_Lottable02       NVARCHAR(18) OUTPUT,
	@c_Lottable03       NVARCHAR(18) OUTPUT,
	@dt_Lottable04      datetime OUTPUT,
   @dt_Lottable05      datetime OUTPUT,
   @b_Success          int = 1  OUTPUT,
   @n_ErrNo            int = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_Sourcekey        NVARCHAR(10) = '',  -- (Vicky01)
   @c_Sourcetype       NVARCHAR(20) = '',  -- (Vicky01)
   @c_LottableLabel    NVARCHAR(20) = ''   -- (Vicky01)

AS
BEGIN
	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
 
   IF @c_Sourcetype = 'RDTRECEIPT'
   BEGIN
      -- Get LineNo not yet receive
      SET @c_Lottable02 = ''
      SELECT TOP 1 
         @c_Lottable02 = ReceiptLineNumber
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @c_Sourcekey
         AND SKU = @c_Sku
         AND QTYExpected > BeforeReceivedQTY
      ORDER BY ReceiptLineNumber
      
      SET @c_Lottable03 = 'OK'   -- Condition code
   END
END -- End Procedure

GO
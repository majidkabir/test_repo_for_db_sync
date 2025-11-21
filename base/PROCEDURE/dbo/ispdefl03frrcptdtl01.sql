SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispDefL03FrRcptDtl01                                */
/* Copyright: LF Logistics                                              */
/* Purpose: Default lottable03 from ReceiptDetail                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-10-03   Ung       1.0   SOS319427 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispDefL03FrRcptDtl01]
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
	@dt_Lottable04      DATETIME     OUTPUT,
   @dt_Lottable05      DATETIME     OUTPUT,
   @b_Success          INT = 1      OUTPUT,
   @n_ErrNo            INT = 0      OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_Sourcekey        NVARCHAR(15) = '',  
   @c_Sourcetype       NVARCHAR(20) = '',  
   @c_LottableLabel    NVARCHAR(20) = ''   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @c_Sourcetype IN ('RDTRECEIPT', 'RECEIPTRET')
   BEGIN
      -- Get LineNo not yet receive
      SET @c_Lottable03 = ''
      SELECT TOP 1 
         @c_Lottable03 = Lottable03
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = LEFT( @c_Sourcekey, 10)
         AND SKU = @c_Sku
         AND QTYExpected > BeforeReceivedQTY
      ORDER BY ReceiptLineNumber
   END
END

GO
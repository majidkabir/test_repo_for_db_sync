SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispNIKECNL3FrRcptSKU                                */
/* Copyright: IDS                                                       */
/* Purpose: Default lottable03 from ReceiptDetail                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2012-04-02   Ung       1.0   Created                                 */
/* 2014-12-02   Ung       1.1   Performance tuning                      */
/* 2015-03-12   CSCHONG   1.2   New lottable06 to 15 (CS01)             */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispNIKECNL3FrRcptSKU]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(20),
	@c_Lottable01Value  NVARCHAR(18),
	@c_Lottable02Value  NVARCHAR(18),
	@c_Lottable03Value  NVARCHAR(18),
	@dt_Lottable04Value DATETIME,
	@dt_Lottable05Value DATETIME,
   @c_Lottable06Value  NVARCHAR(30)  = '',    --(CS01)
	@c_Lottable07Value  NVARCHAR(30)  = '',    --(CS01)
	@c_Lottable08Value  NVARCHAR(30)  = '',    --(CS01)
   @c_Lottable09Value  NVARCHAR(30)  = '',    --(CS01)
	@c_Lottable10Value  NVARCHAR(30)  = '',    --(CS01)
	@c_Lottable11Value  NVARCHAR(30)  = '',    --(CS01)
   @c_Lottable12Value  NVARCHAR(30)  = '',    --(CS01)
   @dt_Lottable13Value DATETIME  = NULL,      --(CS01)
	@dt_Lottable14Value DATETIME  = NULL,      --(CS01)
	@dt_Lottable15Value DATETIME  = NULL,      --(CS01)
	@c_Lottable01       NVARCHAR(18) OUTPUT,
	@c_Lottable02       NVARCHAR(18) OUTPUT,
	@c_Lottable03       NVARCHAR(18) OUTPUT,
	@dt_Lottable04      DATETIME OUTPUT,
   @dt_Lottable05      DATETIME OUTPUT,
   @c_Lottable06       NVARCHAR(30) OUTPUT,    --(CS01)
	@c_Lottable07       NVARCHAR(30) OUTPUT,    --(CS01)
	@c_Lottable08       NVARCHAR(30) OUTPUT,    --(CS01)
   @c_Lottable09       NVARCHAR(30) OUTPUT,    --(CS01)
	@c_Lottable10       NVARCHAR(30) OUTPUT,    --(CS01)
	@c_Lottable11       NVARCHAR(30) OUTPUT,    --(CS01)
   @c_Lottable12       NVARCHAR(30) OUTPUT,    --(CS01)
   @dt_Lottable13      DATETIME OUTPUT,        --(CS01)
	@dt_Lottable14      DATETIME OUTPUT,        --(CS01)
   @dt_Lottable15      DATETIME OUTPUT,        --(CS01)
   @b_Success          INT = 1  OUTPUT,   
   @n_ErrNo            INT = 0  OUTPUT,
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

   IF @c_Sourcetype IN ('RECEIPT','RECEIPTFINALIZE')
      RETURN

   -- Get ToID
   DECLARE @cToID NVARCHAR(18)
   SET @cToID = ''
   SELECT 
      @cToID = V_ID
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE V_ReceiptKey = @c_Sourcekey
      AND StorerKey = @c_Storerkey
      -- AND V_SKU = @c_Sku
      AND UserName = SUSER_SNAME()

   -- Get receipt detail info
   SET @c_Lottable03 = ''
   SELECT TOP 1
      @c_Lottable03 = Lottable03
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @c_Sourcekey
      AND SKU = @c_SKU
      AND Lottable03 <> ''
   ORDER BY 
       CASE WHEN QTYExpected > BeforeReceivedQTY THEN 0 ELSE 1 END
      ,CASE WHEN ToID = @cToID THEN 0 ELSE 1 END
      ,ReceiptLineNumber
END

GO
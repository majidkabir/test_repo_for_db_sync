SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispMHTLottableTW02                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:  Decode lottable02                                          */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 04-Apr-2014  Ung       1.0   SOS306108 RDT return decode GS1 barcode */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMHTLottableTW02]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(60),
   @c_Lottable01Value  NVARCHAR(60),
   @c_Lottable02Value  NVARCHAR(60),
   @c_Lottable03Value  NVARCHAR(60),
   @dt_Lottable04Value datetime,
   @dt_Lottable05Value datetime,
   @c_Lottable01       NVARCHAR(18) OUTPUT,
   @c_Lottable02       NVARCHAR(18) OUTPUT,
   @c_Lottable03       NVARCHAR(18) OUTPUT,
   @dt_Lottable04      datetime OUTPUT,
   @dt_Lottable05      datetime OUTPUT,
   @b_Success          int = 1  OUTPUT,
   @n_Err              int = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_Sourcekey        NVARCHAR(15) = '',
   @c_Sourcetype       NVARCHAR(20) = '',
   @c_LottableLabel    NVARCHAR(20) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_IsRDT Int
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   IF @n_IsRDT <> 1
      GOTO Quit

   IF @c_Sourcetype NOT IN ('RDTRECEIPT', 'RECEIPTRET')
      GOTO Quit

   DECLARE @c_ReceiptKey      NVARCHAR( 10),
           @c_ReceiptLineNo   NVARCHAR( 5),
           @c_ID              NVARCHAR( 18),
           @c_OldLottable01   NVARCHAR( 18),
           @c_OldLottable02   NVARCHAR( 18),
           @c_OldLottable03   NVARCHAR( 18),
           @dt_OldLottable04  DATETIME,
           @dt_OldLottable05  DATETIME,
           @n_SKUCount        INT,
           @n_LotCount        INT,
           @n_Func            INT

   SELECT @n_Func = Func FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE UserName = sUser_sName()

   IF @n_Func = 581 -- Return
   BEGIN
      /*
      Barcode format:
      1. (10)BatchNo(21)CaseID

      BatchNo = alpha numeric, variable length
      CaseID  = max 20 digits

      Example:
      (10)327516(21)032751600030
      */

      IF LEFT( @c_Lottable02Value, 4) = '(10)'
      BEGIN
         DECLARE @cBatchNo NVARCHAR( 18)
         DECLARE @cCaseID  NVARCHAR( 18)
         DECLARE @nPOS     INT

         SET @cBatchNo = ''
         SET @cCaseID = ''

         -- Decode Batch no
         SET @nPOS = PATINDEX( '%(21)%', @c_Lottable02Value)
         IF @nPOS > 0
         BEGIN
            SET @cBatchNo = LEFT( SUBSTRING( @c_Lottable02Value, 5, @nPOS-5), 18)
            SET @c_Lottable02Value = SUBSTRING( @c_Lottable02Value, @nPOS, LEN( @c_Lottable02Value))
         END

         -- Decode case ID
         IF LEFT( @c_Lottable02Value, 4) = '(21)'
            SET @cCaseID = SUBSTRING( @c_Lottable02Value, 5, LEN( @c_Lottable02Value))
            
         IF @cBatchNo <> ''
            SET @c_Lottable02 = @cBatchNo
         IF @cCaseID <> ''
            SET @c_Lottable03 = @cCaseID
      END
      GOTO Quit
   END

QUIT:

END -- End Procedure

GO
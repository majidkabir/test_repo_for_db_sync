SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ispMHTLottableTW01                                         */
/* Creation Date: 11-Sep-2013                                           */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  SOS#305458 Blank Receiptdetail Lottable01 to Lottable04    */
/*           if 1 pallet + sku contain multiple batches                 */
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
/* 28-Mar-2014  James     1.0   SOS305458 James Created                 */
/* 04-Apr-2014  Ung       1.1   SOS306108 RDT return decode GS1 barcode */
/* 08-May-2014  James     1.2   SOS310761 - Bug fix on getting          */
/*                              correct lottables (james01)             */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMHTLottableTW01]
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
           @n_Func            INT, 
           @c_PalletID        NVARCHAR( 18), 
           @c_LOC             NVARCHAR( 10) 

   SELECT @n_Func = Func, 
          @c_PalletID = V_ID, 
          @c_LOC = V_LOC 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE UserName = sUser_sName()

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

   SET @c_ReceiptKey    = LEFT(@c_SourceKey,10)
   SET @c_ReceiptLineNo = RIGHT(@c_SourceKey,5)

   SELECT @c_ID = ToID,
          @c_OldLottable01 = Lottable01,  -- remember old values
          @c_OldLottable02 = Lottable02,
          @c_OldLottable03 = Lottable03,
          @dt_OldLottable04 = Lottable04,
          @dt_OldLottable05 = Lottable05
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @c_ReceiptKey
--   AND   ReceiptLineNumber = @c_ReceiptLineNo
   AND   SKU = @c_Sku
   AND   TOID = @c_PalletID
   

   -- If > 1 line return 
   IF @@ROWCOUNT > 1 
   BEGIN
      SET @c_OldLottable01 = ''
      SET @c_OldLottable01 = ''
      SET @c_OldLottable01 = ''
      SET @dt_OldLottable04 = NULL
      SET @dt_OldLottable05 = NULL
   END

   SELECT @n_SKUCount = COUNT( DISTINCT SKU)
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND   ReceiptKey = @c_ReceiptKey
   AND   ToID = @c_ID

   IF @n_SKUCount = 1
      -- If 1 pallet only contain 1 SKU
      SELECT TOP 1 @c_SKU = SKU
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @c_Storerkey
      AND   ReceiptKey = @c_ReceiptKey
      AND   ToID = @c_ID

   DECLARE @iDummy INT
   SELECT @iDummy = COUNT( 1)
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND   ReceiptKey = @c_ReceiptKey
   AND   ToID = @c_ID
   AND   SKU = @c_SKU
   GROUP BY Lottable01, Lottable02, Lottable03, Lottable04

   SET @n_LotCount = @@ROWCOUNT

   IF @n_LotCount > 1
   BEGIN
      IF @n_Func = 550
      BEGIN
         -- If 1 pallet + SKU contain > 1 distinct batch no/lottables
         SET @c_Lottable01 = ''
         SET @c_Lottable02 = ''
         SET @c_Lottable03 = ''
         SET @dt_Lottable04 = NULL
         SET @dt_Lottable05 = NULL
      END
   END
   ELSE
   BEGIN
      SET @c_Lottable01 = @c_OldLottable01
      SET @c_Lottable02 = @c_OldLottable02
      SET @c_Lottable03 = @c_OldLottable03
      SET @dt_Lottable04 = @dt_OldLottable04
      SET @dt_Lottable05 = @dt_OldLottable05
   END

QUIT:

END -- End Procedure

GO
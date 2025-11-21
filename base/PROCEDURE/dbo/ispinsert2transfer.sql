SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[ispInsert2Transfer] (
       @c_StorerKey     NVARCHAR(15)
     , @c_FromLoc       NVARCHAR(10)
     , @c_ToLoc         NVARCHAR(10)
     , @c_TransferKey   NVARCHAR(10) = ''
     )
AS 
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF

   DECLARE @c_FromLot               NVARCHAR(10)
         , @c_FromID                NVARCHAR(10)         
         , @c_SKU                   NVARCHAR(20)
         , @n_FromQty               int
         , @c_ToLot                 NVARCHAR(10)
         , @c_ToID                  NVARCHAR(10)         
         , @c_Packkey               NVARCHAR(10)
         , @c_UOM                   NVARCHAR(10)
         , @c_FromLottable01        NVARCHAR(18) 
         , @c_FromLottable02        NVARCHAR(18) 
         , @c_FromLottable03        NVARCHAR(18) 
         , @d_FromLottable04        DATETIME
         , @c_FromLottable06        NVARCHAR(30)
         , @c_FromLottable07        NVARCHAR(30)
         , @c_FromLottable08        NVARCHAR(30)
         , @c_FromLottable09        NVARCHAR(30)
         , @c_FromLottable10        NVARCHAR(30)
         , @c_FromLottable11        NVARCHAR(30)
         , @c_FromLottable12        NVARCHAR(30)
         , @d_FromLottable13        DATETIME
         , @d_FromLottable14        DATETIME
         , @d_FromLottable15        DATETIME
         , @c_ToLottable01          NVARCHAR(18) 
         , @c_ToLottable02          NVARCHAR(18) 
         , @c_ToLottable03          NVARCHAR(18) 
         , @d_ToLottable04          DATETIME
         , @c_ToLottable06          NVARCHAR(30)
         , @c_ToLottable07          NVARCHAR(30)
         , @c_ToLottable08          NVARCHAR(30)
         , @c_ToLottable09          NVARCHAR(30)
         , @c_ToLottable10          NVARCHAR(30)
         , @c_ToLottable11          NVARCHAR(30)
         , @c_ToLottable12          NVARCHAR(30)
         , @d_ToLottable13          DATETIME
         , @d_ToLottable14          DATETIME
         , @d_ToLottable15          DATETIME
         , @d_Lottable05            DATETIME
         , @c_TransferLineNumber    NVARCHAR(5)

   IF ISNULL(@c_StorerKey, '') = '' OR ISNULL(@c_FromLoc, '') = '' OR ISNULL(@c_ToLoc, '') = ''
   RETURN

   DECLARE CUR_SEARCH CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SKU FROM LOTXLOCXID WITH (NOLOCK)
   WHERE STORERKEY = @c_StorerKey
      AND LOC = @c_FromLoc
      AND (QTY - QTYAllocated - QTYPicked) > 0
   GROUP BY SKU
   HAVING COUNT(SKU) > 1

   OPEN CUR_SEARCH

   FETCH NEXT FROM CUR_SEARCH INTO @c_SKU

   WHILE @@FETCH_STATUS = 0
   BEGIN

      SET ROWCOUNT 1

      SELECT 
         @c_ToLot = Lot,
         @c_ToID = ID
      FROM LOTXLOCXID WITH (NOLOCK)
      WHERE STORERKEY = @c_StorerKey
         AND LOC = @c_FromLoc
         AND SKU = @c_SKU
      ORDER BY LOT DESC

      SET ROWCOUNT 0

      SELECT 
         @c_Packkey = PACK.Packkey,
         @c_UOM = PACK.PackUOM3
      FROM SKU SKU WITH (NOLOCK)
      join PACK PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey
      WHERE SKU.STORERKEY = @c_StorerKey
         AND SKU = @c_SKU

      SELECT
         @c_ToLottable01 = Lottable01, 
         @c_ToLottable02 = Lottable02, 
         @c_ToLottable03 = Lottable03, 
         @d_ToLottable04 = Lottable04,
         @c_ToLottable06 = Lottable06,
         @c_ToLottable07 = Lottable07,
         @c_ToLottable08 = Lottable08,
         @c_ToLottable09 = Lottable09,
         @c_ToLottable10 = Lottable10,
         @c_ToLottable11 = Lottable11,
         @c_ToLottable12 = Lottable12,
         @d_ToLottable13 = Lottable13,
         @d_ToLottable14 = Lottable14,
         @d_ToLottable15 = Lottable15,
         @d_Lottable05   = Lottable05
      FROM LOTATTRIBUTE WITH (NOLOCK)
      WHERE LOT = @c_ToLot


      --BEGIN INSERT LOOP
      DECLARE CUR_INSERT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LOT, ID, QTY FROM LOTXLOCXID WITH (NOLOCK)
      WHERE STORERKEY = @c_StorerKey
         AND LOC = @c_FromLoc
         AND (QTY - QTYAllocated - QTYPicked) > 0
         AND SKU = @c_SKU
         AND LOT < @c_ToLot

      OPEN CUR_INSERT

      FETCH NEXT FROM CUR_INSERT INTO @c_FromLot, @c_FromID, @n_FromQty

      WHILE @@FETCH_STATUS = 0
      BEGIN

         SELECT
            @c_FromLottable01 = Lottable01, 
            @c_FromLottable02 = Lottable02, 
            @c_FromLottable03 = Lottable03, 
            @d_FromLottable04 = Lottable04,
            @c_FromLottable06 = Lottable06,
            @c_FromLottable07 = Lottable07,
            @c_FromLottable08 = Lottable08,
            @c_FromLottable09 = Lottable09,
            @c_FromLottable10 = Lottable10,
            @c_FromLottable11 = Lottable11,
            @c_FromLottable12 = Lottable12,
            @d_FromLottable13 = Lottable13,
            @d_FromLottable14 = Lottable14,
            @d_FromLottable15 = Lottable15
         FROM LOTATTRIBUTE WITH (NOLOCK)
         WHERE LOT = @c_FromLot

         -- Get next ReceiptLineNumber
         SELECT @c_TransferLineNumber = 
            RIGHT( '00000' + CAST( CAST( IsNULL( MAX( TransferLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
         FROM TransferDetail (NOLOCK)
         WHERE TransferKey = @c_TransferKey

         INSERT INTO TRANSFERDETAIL
         (TransferKey, TransferLineNumber, FromStorerKey, FromSku, FromLoc, FromLot, FromId, 
         FromQty, FromPackKey, FromUOM, 
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
         ToStorerKey, ToSku, ToLoc, ToLot, ToId, ToQty, ToPackKey, ToUOM, Status, EffectiveDate, 
         ToLottable01, ToLottable02, ToLottable03, ToLottable04, ToLottable05, 
         ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10, 
         ToLottable11, ToLottable12, ToLottable13, ToLottable14, ToLottable15,
         UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
         UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10)
         VALUES
         (@c_TransferKey, @c_TransferLineNumber, @c_StorerKey, @c_Sku, @c_FromLoc, @c_FromLot, @c_FromID, 
         @n_FromQty, @c_Packkey, @c_UOM, 
         @c_FromLottable01, @c_FromLottable02, @c_FromLottable03, @d_FromLottable04, @d_Lottable05,
         @c_FromLottable06, @c_FromLottable07, @c_FromLottable08, @c_FromLottable09, @c_FromLottable10, 
         @c_FromLottable11, @c_FromLottable12, @d_FromLottable13, @d_FromLottable14, @d_FromLottable15,
         @c_StorerKey, @c_SKU, @c_ToLoc, @c_ToLot, @c_ToID, @n_FromQty, @c_Packkey, @c_UOM, '0', GETDATE(), 
         @c_ToLottable01, @c_ToLottable02, @c_ToLottable03, @d_ToLottable04, @d_Lottable05, 
         @c_ToLottable06, @c_ToLottable07, @c_ToLottable08, @c_ToLottable09, @c_ToLottable10, 
         @c_ToLottable11, @c_ToLottable12, @d_ToLottable13, @d_ToLottable14, @d_ToLottable15,
         '', '', '', '', '', '', '', '', '', '')

         FETCH NEXT FROM CUR_INSERT INTO @c_FromLot, @c_FromID, @n_FromQty
      END
      CLOSE CUR_INSERT
      DEALLOCATE CUR_INSERT

      FETCH NEXT FROM CUR_SEARCH INTO @c_SKU
   END
   CLOSE CUR_SEARCH
   DEALLOCATE CUR_SEARCH      
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_InsertStockByStorerkey                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* 2022-11-21   LZG     JSM-111763 - Added NOLOCK & ROWLOCK (ZG01)      */
/************************************************************************/

CREATE   PROC [dbo].[isp_InsertStockByStorerkey] (@b_success int OUTPUT, @c_StorerKey NVARCHAR(15) = '')
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE  @c_SKU            NVARCHAR(20),
            @c_id             NVARCHAR(18),
            @c_Lottable01     NVARCHAR(18),
            @c_Lottable02     NVARCHAR(18),
            @c_Lottable03     NVARCHAR(18),
            @d_Lottable04     DATETIME,
            @d_Lottable05     DATETIME,
            @c_Lottable06     NVARCHAR(30),
            @c_Lottable07     NVARCHAR(30),
            @c_Lottable08     NVARCHAR(30),
            @c_Lottable09     NVARCHAR(30),
            @c_Lottable10     NVARCHAR(30),
            @c_Lottable11     NVARCHAR(30),
            @c_Lottable12     NVARCHAR(30),
            @d_Lottable13     DATETIME,
            @d_Lottable14     DATETIME,
            @d_Lottable15     DATETIME,
            @c_LOC            NVARCHAR(10),
            @n_qty            int,
            @d_today          DATETIME,
            @c_PackKey        NVARCHAR(10),
            @c_PackUOM3       NVARCHAR(10),
            @c_temploc        NVARCHAR(10),
            @c_tempsku        NVARCHAR(20),
            @n_RowId          int,
            @n_continue       int,
            @c_SourceKey      char (20),
            @c_SourceType     char (30),
            @c_cckey          char (10),
            @n_TotalQty       int

   SET NOCOUNT ON
   SELECT @d_today = GetDate(), @b_success = 1

   SELECT @n_RowId = 0, @n_TotalQty = 0

   WHILE 1=1
   BEGIN
      SELECT @n_RowId = MIN(RowId)
      FROM  TempStock (NOLOCK)
      WHERE RowId > @n_RowId

      IF @n_RowId = 0 OR @n_RowID IS NULL
      BEGIN
         BREAK
      END

      SELECT @c_PackKey = '', @c_PackUOM3 = '', @c_LOC = '', @c_SKU = ''

      SET ROWCOUNT 1

      SELECT --@c_Storerkey = TempStock.storerkey,
            @c_SKU = TempStock.sku,
            @c_id = ISNULL(TempStock.id, ''),
            -- (YokeBeen01) - Start.
            @c_Lottable01  = ISNULL(UPPER(TempStock.Lottable01), ''),
            @c_Lottable02  = ISNULL(UPPER(TempStock.Lottable02), ''),
            @c_Lottable03  = ISNULL(UPPER(TempStock.Lottable03), ''),
            -- (YokeBeen01) - End.
            @d_Lottable04  = TempStock.Lottable04,
            @d_Lottable05  = TempStock.Lottable05,
            @c_Lottable06  = ISNULL(UPPER(TempStock.Lottable06), ''),
            @c_Lottable07  = ISNULL(UPPER(TempStock.Lottable07), ''),
            @c_Lottable08  = ISNULL(UPPER(TempStock.Lottable08), ''),
            @c_Lottable09  = ISNULL(UPPER(TempStock.Lottable09), ''),
            @c_Lottable10  = ISNULL(UPPER(TempStock.Lottable10), ''),
            @c_Lottable11  = ISNULL(UPPER(TempStock.Lottable11), ''),
            @c_Lottable12  = ISNULL(UPPER(TempStock.Lottable12), ''),
            @d_Lottable13  = TempStock.Lottable13,
            @d_Lottable14  = TempStock.Lottable14,
            @d_Lottable15  = TempStock.Lottable15,
            @c_LOC         = LOC.loc,
            @n_qty         = TempStock.qty,
            @c_SourceKey   = TempStock.SourceKey,
            @c_SourceType  = TempStock.SourceType,
            @c_PackKey     = SKU.PackKey,
            @c_PackUOM3    = PACK.PackUOM3
      FROM TempStock (NOLOCK)   -- ZG01
      INNER JOIN LOC (NOLOCK) ON (TempStock.LOC = LOC.LOC)
      INNER JOIN SKU (NOLOCK) ON (TempStock.StorerKey = SKU.StorerKey AND TempStock.SKU = SKU.SKU)
      INNER JOIN PACK (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
       WHERE RowID = @n_RowId
       AND Substring(TempStock.sourcetype,1,11) = 'ExcelLoader'

      IF @@ROWCOUNT = 0
      BEGIN
         SET ROWCOUNT 0
         CONTINUE
      END

      SET ROWCOUNT 0

      IF @c_PackKey <> '' AND @c_PackUOM3 <> '' AND @c_LOC <> '' AND @c_SKU <> ''
      BEGIN
         BEGIN TRAN
         SELECT @b_success = 1
         EXECUTE nspItrnAddDeposit
             NULL,
             @c_StorerKey,
             @c_SKU,
            '',
             @c_LOC,
             @c_id,
             'OK',
             @c_Lottable01,
             @c_Lottable02,
             @c_Lottable03,
             @d_Lottable04,
             @d_Lottable05,
             @c_Lottable06,
             @c_Lottable07,
             @c_Lottable08,
             @c_Lottable09,
             @c_Lottable10,
             @c_Lottable11,
             @c_Lottable12,
             @d_Lottable13,
             @d_Lottable14,
             @d_Lottable15,
             0,
             0,
             @n_qty,
             0,
             0,
             0,
             0,
             0,
             0,
             @c_SourceKey,
             @c_SourceType,
             @c_PackKey,
             @c_PackUOM3,
             0,
             @d_today,
             "",
             @b_Success OUTPUT,
             0,
             ''

          SELECT @n_TotalQty = @n_TotalQty + @n_qty



          IF NOT @b_success = 1
          BEGIN
          SELECT @c_StorerKey, @c_SKU,
                  @c_Lottable01 '@c_Lottable01', @c_Lottable02 '@c_Lottable02', @c_Lottable03 '@c_Lottable03', @d_Lottable04 '@c_Lottable04', @d_Lottable05 '@c_Lottable05',
                  @c_Lottable06 '@c_Lottable06', @c_Lottable07 '@c_Lottable07', @c_Lottable08 '@c_Lottable08', @c_Lottable09 '@c_Lottable09', @c_Lottable10 '@c_Lottable10',
                  @c_Lottable11 '@c_Lottable11', @c_Lottable12 '@c_Lottable12', @d_Lottable13 '@c_Lottable13', @d_Lottable14 '@c_Lottable14', @d_Lottable15 '@c_Lottable15'

             SELECT @n_continue = 3
             SELECT @b_success = 0
             ROLLBACK TRAN
             BREAK
          END
          ELSE
          BEGIN
             Update CCDETAIL WITH (ROWLOCK)     -- ZG01
             SET   status = '9'
             Where CCDETAIL.CCDETAILKEY = @c_SourceKey

             DELETE TempStock WHERE RowId = @n_RowId
             COMMIT TRAN
          END
      END -- PackKey <> ''
    END -- While
END -- Procedure

GO
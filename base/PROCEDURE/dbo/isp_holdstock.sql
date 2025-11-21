SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_HoldStock                                      */
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
/* Date         Who      Purpose                                        */
/* 29-Jul-2004  YokeBeen (SOS#25644) - (YokeBeen01)                     */
/*                       Set all values for Lottable01, Lottable02 &    */
/*                       Lottable03 to Upper Case during Deposit, since */
/*                       OW cannot accept Lower Case for Lottable02.    */
/*                                                                      */
/* 03-Feb-2009  NJOW     (SOS#126943) - Filer by stocktakekey           */
/* 07-May-2014  TKLIM    Added Lottables 06-15                          */
/************************************************************************/  

CREATE PROC [dbo].[isp_HoldStock] (@b_success int OUTPUT)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_SKU            NVARCHAR(20),
            @c_ID             NVARCHAR(18),
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
            @n_err            int,
            @d_today          DATETIME,
            @c_LOT            NVARCHAR(10),
            @c_PackUOM3       NVARCHAR(10),
            @c_temploc        NVARCHAR(10),
            @c_tempsku        NVARCHAR(20),
            @c_Storerkey      NVARCHAR(15),
            @n_RowId          int,
            @n_continue       int,
            @c_Status         char (10),  
            @c_SourceType     char (30),
            @c_errmsg         char (215),
            @n_HoldCnt        int                      

   DECLARE @RC int      

   SELECT @d_today = GetDate(), @b_success = 1

   SELECT @n_RowId = 0 
      
   WHILE 1=1
   BEGIN
      SELECT @n_RowId = MIN(RowId)
      FROM  HoldStock (NOLOCK)
      WHERE RowId > @n_RowId
      
      IF @n_RowId = 0 OR @n_RowID IS NULL
      BEGIN
         BREAK
      END

      SELECT @c_Storerkey = Storerkey, 
             @c_SKU = SKU, 
             @c_LOT = LOT, 
             @c_LOC = LOC,
             @c_ID = ID, 
             @c_Lottable01 = Lottable01,
             @c_Lottable02 = Lottable02,
             @c_Lottable03 = Lottable03,
             @d_Lottable04 = Lottable04, 
             @d_Lottable05 = Lottable05,
             @c_Lottable06 = Lottable06,
             @c_Lottable07 = Lottable07,
             @c_Lottable08 = Lottable08,
             @c_Lottable09 = Lottable09,
             @c_Lottable10 = Lottable10,
             @c_Lottable11 = Lottable11,
             @c_Lottable12 = Lottable12,
             @d_Lottable13 = Lottable13,
             @d_Lottable14 = Lottable14,
             @d_Lottable15 = Lottable15,
             @c_Status = [Status]
      FROM HoldStock
       WHERE RowID = @n_RowId

      IF @@ROWCOUNT = 0
      BEGIN
         SET ROWCOUNT 0 
         CONTINUE
      END 

      SET @n_HoldCnt = 0 
      IF ISNULL(RTRIM(@c_LOT), '') <> '' 
      BEGIN
         SET @n_HoldCnt = @n_HoldCnt + 1
      END 
      IF ISNULL(RTRIM(@c_LOC), '') <> '' 
      BEGIN
         SET @n_HoldCnt = @n_HoldCnt + 1
      END 
      IF ISNULL(RTRIM(@c_ID), '') <> '' 
      BEGIN
         SET @n_HoldCnt = @n_HoldCnt + 1
      END 
      IF ISNULL(RTRIM(@c_StorerKey), '') <> '' AND 
         ISNULL(RTRIM(@c_SKU), '') <> '' AND 
         ( ISNULL(RTRIM(@c_Lottable01), '') <> '' OR
           ISNULL(RTRIM(@c_Lottable02), '') <> '' OR
           ISNULL(RTRIM(@c_Lottable03), '') <> '' OR 
           ISNULL(RTRIM(@c_Lottable06), '') <> '' OR
           ISNULL(RTRIM(@c_Lottable07), '') <> '' OR
           ISNULL(RTRIM(@c_Lottable08), '') <> '' OR 
           ISNULL(RTRIM(@c_Lottable09), '') <> '' OR
           ISNULL(RTRIM(@c_Lottable10), '') <> '' OR
           ISNULL(RTRIM(@c_Lottable11), '') <> '' OR 
           ISNULL(RTRIM(@c_Lottable12), '') <> '' OR
           @d_Lottable04 IS NOT NULL OR
           @d_Lottable05 IS NOT NULL OR
           @d_Lottable13 IS NOT NULL OR
           @d_Lottable14 IS NOT NULL OR
           @d_Lottable15 IS NOT NULL )
      BEGIN
         SET @n_HoldCnt = @n_HoldCnt + 1
      END 

      SET @d_Lottable04 = CASE WHEN ISNULL(@d_Lottable04, '') = '' THEN NULL ELSE @d_Lottable04 END
      SET @d_Lottable05 = CASE WHEN ISNULL(@d_Lottable05, '') = '' THEN NULL ELSE @d_Lottable05 END
      SET @d_Lottable13 = CASE WHEN ISNULL(@d_Lottable13, '') = '' THEN NULL ELSE @d_Lottable13 END
      SET @d_Lottable14 = CASE WHEN ISNULL(@d_Lottable14, '') = '' THEN NULL ELSE @d_Lottable14 END
      SET @d_Lottable15 = CASE WHEN ISNULL(@d_Lottable15, '') = '' THEN NULL ELSE @d_Lottable15 END

      IF @n_HoldCnt = 1 
      BEGIN   
         BEGIN TRAN

         SELECT @b_success = 1

         EXECUTE @RC = [dbo].[nspInventoryHoldWrapper] 
                 @c_LOT          = @c_LOT
               , @c_Loc          = @c_Loc
               , @c_ID           = @c_ID
               , @c_StorerKey    = @c_StorerKey
               , @c_SKU          = @c_SKU
               , @c_Lottable01   = @c_Lottable01
               , @c_Lottable02   = @c_Lottable02
               , @c_Lottable03   = @c_Lottable03
               , @dt_Lottable04  = @d_Lottable04
               , @dt_Lottable05  = @d_Lottable05
               , @c_Lottable06   = @c_Lottable06
               , @c_Lottable07   = @c_Lottable07
               , @c_Lottable08   = @c_Lottable08
               , @c_Lottable09   = @c_Lottable09
               , @c_Lottable10   = @c_Lottable10
               , @c_Lottable11   = @c_Lottable11
               , @c_Lottable12   = @c_Lottable12
               , @dt_Lottable13  = @d_Lottable13
               , @dt_Lottable14  = @d_Lottable14
               , @dt_Lottable15  = @d_Lottable15
               , @c_Status       = @c_Status
               , @c_Hold         = '1'
               , @b_success      = @b_success   OUTPUT
               , @n_err          = @n_err       OUTPUT
               , @c_errmsg       = @c_errmsg    OUTPUT
               , @c_remark       = ''

          IF NOT @b_success = 1
          BEGIN
             Print 'hold lot failed'

             SELECT @n_continue = 3
             SELECT @b_success = 0             
             ROLLBACK TRAN
             BREAK
          END
          ELSE
          BEGIN
             DELETE HoldStock WHERE RowId = @n_RowId
             COMMIT TRAN
   END
      END -- PackKey <> ''
    END -- While
END -- Procedure

GO
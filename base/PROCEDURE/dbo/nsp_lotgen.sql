SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_LotGen                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 19-06-2012   SPChin   1.1  SOS247875 - Add ISNULL Check              */
/* 24-Apr-2014  TLTING   1.2  Add Lottable06-15                         */
/* 27-Jul-2017  TLTING   1.3  Missng nolock                             */
/************************************************************************/

CREATE PROC [dbo].[nsp_LotGen]
               @c_storerkey    NVARCHAR(15)
,              @c_sku          NVARCHAR(20)
,              @c_lottable01   NVARCHAR(18) = ''
,              @c_lottable02   NVARCHAR(18) = ''
,              @c_lottable03   NVARCHAR(18) = ''
,              @c_lottable04   datetime = NULL 
,              @c_lottable05   datetime = NULL 
,              @c_lottable06   NVARCHAR(30) = ''    -- tlting
,              @c_lottable07   NVARCHAR(30) = ''
,              @c_lottable08   NVARCHAR(30) = ''
,              @c_lottable09   NVARCHAR(30) = ''
,              @c_lottable10   NVARCHAR(30) = ''
,              @c_lottable11   NVARCHAR(30) = ''
,              @c_lottable12   NVARCHAR(30) = ''
,              @c_lottable13   datetime = NULL 
,              @c_lottable14   datetime = NULL 
,              @c_lottable15   datetime = NULL 
,              @c_lot          NVARCHAR(10)  OUTPUT
,              @b_Success      int           OUTPUT
,              @n_err          int           OUTPUT
,              @c_errmsg       NVARCHAR(250) OUTPUT
,              @b_resultset    int       = 0
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @n_continue int
   ,      @n_starttcnt int         -- Holds the current transaction count
   ,      @c_preprocess NVARCHAR(250)  -- preprocess
   ,      @c_pstprocess NVARCHAR(250)  -- post process
   ,      @n_err2 int              -- For Additional Error Detection
   SELECT @n_continue=1, @b_success=0, @n_err=0,@c_errmsg='',@n_starttcnt=@@TRANCOUNT,@n_err2=0
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT @c_preprocess  =(SELECT   NSQLValue FROM NSQLCONFIG WITH (NOLOCK) WHERE NSQLCONFIG.ConfigKey = 'nsp_LotGen_pre') ,
      @c_pstprocess =(SELECT   NSQLValue FROM NSQLCONFIG WITH (NOLOCK) WHERE NSQLCONFIG.ConfigKey = 'nsp_LotGen_pst')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err)   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL61000: Lot Determination Failed Because Select Statement Failed On Preprocess Lookup. (nsp_LotGen) SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         SELECT @n_err = 61000
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @c_preprocess is NOT NULL AND @c_preprocess <> '' AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_preprocess)) IS NOT NULL
      BEGIN
         EXEC(@c_preprocess)
         SELECT @n_err = @@ERROR
         IF @n_err - 60000 > 4  or @n_err - 60000 < 0
         BEGIN
            SELECT @c_errmsg = 'NSQL70000:'+'PreProcess (nsp_LotGen)'   -- Should Be Set To The error message characterised by raise error but I have no clue how.
            SELECT @n_continue=3
         END
      ELSE
         SELECT @n_continue = @n_err - 60000
      END
   END
   IF @n_continue =1 or @n_continue=2
   BEGIN
      SET @c_LOT = ''
      
      SELECT TOP 1 @c_lot = LOT
      FROM   LOTATTRIBUTE WITH (NOLOCK)
      WHERE  storerkey = @c_storerkey
      AND    sku = @c_sku
      AND    lottable01 = @c_lottable01
      AND    lottable02 = @c_lottable02
      AND    lottable03 = @c_lottable03
      AND    lottable04 = @c_lottable04
      AND    lottable05 = @c_lottable05
      AND    lottable06 = @c_lottable06
      AND    lottable07 = @c_lottable07
      AND    lottable08 = @c_lottable08
      AND    lottable09 = @c_lottable09
      AND    lottable10 = @c_lottable10
      AND    lottable11 = @c_lottable11
      AND    lottable12 = @c_lottable12
      AND    lottable13 = @c_lottable13
      AND    lottable14 = @c_lottable14
      AND    lottable15 = @c_lottable15 
      IF ISNULL(RTRIM(@c_lot),'') ='' 
      BEGIN
         BEGIN TRANSACTION
            EXECUTE nspg_getkey
            'LOT'
            ,  10
            ,  @c_lot OUTPUT
            ,  @b_success OUTPUT
            ,  @n_err OUTPUT
            ,  @c_errmsg OUTPUT
            SELECT @n_err2=@@ERROR
            IF @n_err2 <> 0
            BEGIN
               SELECT @n_continue=3
               SELECT @c_errmsg = CONVERT(char(250),@n_err2)   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL61000: Lot Determination Failed Because nsp_getkey failed. (nsp_LotGen)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               SELECT @n_err = 61000
            END
         ELSE
            BEGIN
               IF @b_success=1
               BEGIN
                  INSERT INTO LOTATTRIBUTE
                  (
                       storerkey,    sku,    lot
                  ,    lottable01,    lottable02,    lottable03
                  ,    lottable04,    lottable05
                  ,    lottable06,    lottable07,    lottable08
                  ,    lottable09,    lottable10,    lottable11
                  ,    lottable12
                  ,    lottable13,    lottable14,    lottable15                                    
                  )
                  VALUES
                  (
                  @c_storerkey, @c_sku, @c_lot,
                  ISNULL(RTRIM(@c_lottable01),''), ISNULL(RTRIM(@c_lottable02),''), ISNULL(RTRIM(@c_lottable03),''),  --SOS247875
                  @c_lottable04, @c_lottable05,
                  ISNULL(RTRIM(@c_lottable06),''), ISNULL(RTRIM(@c_lottable07),''), ISNULL(RTRIM(@c_lottable08),''),  --tlting
                  ISNULL(RTRIM(@c_lottable09),''), ISNULL(RTRIM(@c_lottable10),''), ISNULL(RTRIM(@c_lottable11),''),  --tlting
                  ISNULL(RTRIM(@c_lottable12),''),
                  @c_lottable13, @c_lottable14,   @c_lottable15               
                  )
                  SELECT @n_err2=@@ERROR
                  IF @n_err2 <> 0
                  BEGIN
                     SELECT @n_continue=3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err2)   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL61000: Lot Determination Failed Because insert failed. (nsp_LotGen)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     SELECT @n_err = 61000
                  END
               END
            ELSE
               BEGIN
                  SELECT @n_continue=3
               END
            END
         END
      END -- @n_continue =1 or @n_continue=2
      IF @c_pstprocess is NOT NULL AND @c_pstprocess <> '' AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_pstprocess)) IS NOT NULL AND ( @n_continue=1 or @n_continue=2 )
      BEGIN
         EXEC(@c_pstprocess)
         SELECT @n_err = @@ERROR
         IF @n_err - 60000 > 4  or @n_err - 60000 < 0
         BEGIN
            SELECT @c_errmsg = 'NSQL70000:'+'PstProcess (nsp_LotGen)'   -- Should Be Set To The error message characterised by raise error but I have no clue how.
            SELECT @n_continue=3
         END
      ELSE
         SELECT @n_continue = @n_err - 60000
      END
      IF @b_resultset = 1
      BEGIN
         SELECT @c_lot, @b_Success, @n_err, @c_errmsg
      END
      IF @n_continue=3  -- Error Occured - Process And Return
      BEGIN
         SELECT @b_success = 0
         IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END
      ELSE
         BEGIN
            WHILE @@TRANCOUNT > @n_starttcnt
            BEGIN
               COMMIT TRAN
            END
         END
         execute nsp_logerror @n_err, @c_errmsg, 'nsp_LotGen'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   ELSE
      BEGIN
         SELECT @b_success = 1
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
         RETURN
      END
   END

GO
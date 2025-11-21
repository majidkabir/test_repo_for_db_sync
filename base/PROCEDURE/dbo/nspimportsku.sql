SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspImportSKU                                       */
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
/* Date         Author        Purposes                                  */
/* 12-Aug-2008  SHONG         PickCode Default to nspRPFIFO             */
/* 02-Jun-2014  TKLIM         Added Lottables 06-15                     */
/************************************************************************/

CREATE PROC [dbo].[nspImportSKU]
AS
BEGIN -- start of procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue       int,
            @n_starttcnt      int,              -- Holds the current transaction count
            @n_cnt            int,              -- Holds @@ROWCOUNT after certain operations
            @c_preprocess     NVARCHAR(250),    -- preprocess
            @c_pstprocess     NVARCHAR(250),    -- post process
            @n_err2           int,              -- For Additional Error Detection
            @b_debug          int,              -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
            @b_success        int,              
            @n_err            int,              
            @c_errmsg         NVARCHAR(250),
            @errorcount       int
   DECLARE  @c_hikey          NVARCHAR(10),
            @c_externSKUkey   NVARCHAR(30),
            @c_storerkey      NVARCHAR(15)

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@n_cnt = 0,@c_errmsg="",@n_err2=0
   SELECT @b_debug = 0
   /* Start Main Processing */

   -- get the hikey,
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 0
      EXECUTE nspg_GetKey
               "hirun",
               10,
               @c_hikey OUTPUT,
               @b_success       OUTPUT,
               @n_err           OUTPUT,
               @c_errmsg        OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> The HI Run Identifer Is ' + @c_hikey + ' started at ' + convert (char(20), getdate()), 'GENERAL', ' ')

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspImportSKU)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      declare @count1 int
      -- delete sku that already exist in SKU table
      DELETE FROM WMSSKU
      WHERE SKU in (SELECT SKU FROM SKU )
      OR dbo.fnc_LTrim(dbo.fnc_RTrim(SKU)) = ''
      OR dbo.fnc_LTrim(dbo.fnc_RTrim(SKU)) IS NULL

      SELECT @count1 = COUNT(*) FROM WMSSKU
      IF @count1 > 0
      BEGIN
         INSERT INTO SKU ( StorerKey, SKU,  Descr, SUSR1, SUSR2, SUSR3, SUSR4, SUSR5,
               MANUFACTURERSKU, retailsku, altsku, Packkey, StdGrossWgt,
               StdNetwgt, StdCube, SKUGroup, 
               Lottable01Label, Lottable02Label, Lottable03label, Lottable04label, Lottable05Label, 
               Lottable06Label, Lottable07Label, Lottable08Label, Lottable09Label, Lottable10Label,
               Lottable11Label, Lottable12Label, Lottable13Label, Lottable14Label, Lottable15Label,
               PickCode, Strategykey , PutCode, PutawayLoc,
               PutawayZone, GrossWgt, NetWgt, Length, Width, Height, Weight, Shelflife, Facility, Notes1 )
         SELECT Storerkey, SKU, Descr, ISNULL(SUSR1, ' ' ), ISNULL (SUSR2, ' ' ), ISNULL(SUSR3,' '), ISNULL (SUSR4, ' '), ISNULL(SUSR5,' '),
               ISNULL(MANUFACTURESKU, ' '), ISNULL(RETAILSKU,' '), ISNULL(ALTSKU,' '), ISNULL(PACKKEY,'STD') , ISNULL(StdGrossWgt, 0),
               ISNULL(StdNetwgt,0), ISNULL(StdCube,0), ISNULL(SKUGROUP, 'STD'), 
               ISNULL(Lottable01Label,' '), ISNULL(Lottable02Label,' '), ISNULL(Lottable03Label,' '), ISNULL(Lottable04Label,' '), ISNULL(Lottable05Label,' '), 
               ISNULL(Lottable06Label,' '), ISNULL(Lottable07Label,' '), ISNULL(Lottable08Label,' '), ISNULL(Lottable09Label,' '), ISNULL(Lottable10Label,' '),
               ISNULL(Lottable11Label,' '), ISNULL(Lottable12Label,' '), ISNULL(Lottable13Label,' '), ISNULL(Lottable14Label,' '), ISNULL(Lottable15Label,' '),
               'nspRPFIFO', 'TWNSTD', 'NSPPASTD', 'UNKNOWN',
               'SEE_SUPV', ISNULL(GrossWgt, 0), ISNULL(NetWgt,0), ISNULL(Length,0), ISNULL(Width,0), ISNULL(Height,0), ISNULL(Weight,0), ISNULL(ShelfLife,0), ISNULL(Facility,' '),
               NOTES1
         FROM WMSSKU

         SELECT @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62103   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Failed On SKU (nspImportSKU)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
         -- Delete WMSSKU, if records is successfully imported,
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            DELETE FROM WMSSKU where SKU IN (SELECT SKU FROM SKU (NOLOCK) )

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62111   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On WMSRCM (nspImportSKU)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
         END
      END
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
         VALUES ( @c_hikey, ' -> nspImportSKU . Process completed for ' + @c_hikey + '. Process ended at ' + convert (NVARCHAR(20), getdate()), 'GENERAL', ' ')

         SELECT @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Failed On HIERROR. (nspImportSKU)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
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
      execute nsp_logerror @n_err, @c_errmsg, "nspImportSKU"
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
END -- end of procedure


GO
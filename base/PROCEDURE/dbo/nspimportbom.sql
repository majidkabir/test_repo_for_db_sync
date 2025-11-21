SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspImportBOM                                       */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspImportBOM]
AS
BEGIN -- start of procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt   int      , -- Holds the current transaction count
   @n_cnt         int      , -- Holds @@ROWCOUNT after certain operations
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int             , -- For Additional Error Detection
   @b_debug int            ,  -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
   @b_success int         ,
   @n_err   int        ,
   @c_errmsg NVARCHAR(250),
   @errorcount int
   DECLARE @c_hikey NVARCHAR(10),
   @c_externorderkey NVARCHAR(30),
   @c_storerkey NVARCHAR(15)
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
      @b_success   	 OUTPUT,
      @n_err       	 OUTPUT,
      @c_errmsg    	 OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspImportBOM -- The HI Run Identifer Is ' + @c_hikey + ' started at ' + convert (char(20), getdate()), 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspImportBOM)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   -- BEGIN VALIDATION SECTION
   -- do all the validation on the WMSORM and WMSORD tables first before inserting into temp table
   -- 'ERROR CODES ->
   -- 1. E1 for blank externorderkey
   -- 2. E2 for blank storerkey
   -- 3. E3 for Invalid Storerkey
   -- 4. E4 for Invalid sku
   -- 5. E5 for repeating externorderkey
   -- 6. E6 for non existing externorderkey in header file
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- check for any records to be processed
      IF EXISTS (SELECT 1 FROM WMSBOM WHERE WMS_FLAG = 'N')
      BEGIN
         SELECT @n_continue = 1
         Update WMSORM
         SET ADDWHO = @c_hikey
         WHERE WMS_FLAG = 'N'
         AND ( dbo.fnc_LTrim(dbo.fnc_RTrim(ADDWHO)) = '' OR dbo.fnc_LTrim(dbo.fnc_RTrim(ADDWHO)) IS NULL )
      END
   ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62201   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": There is no records to be processed (nspImportBOM)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         -- check for blank storerkey
         UPDATE WMSBOM
         SET WMS_FLAG = 'E2'
         WHERE ( dbo.fnc_LTrim(dbo.fnc_RTrim(Storerkey)) = ''
         OR dbo.fnc_LTrim(dbo.fnc_RTrim(Storerkey ) ) IS NULL )
         AND WMS_FLAG = 'N'

         -- check for invalid storerkey
         UPDATE WMSBOM
         SET WMS_FLAG = 'E3'
         WHERE STORERKEY NOT IN (SELECT Storerkey from STORER )
         AND WMS_FLAG = 'N'

         -- check for invalid sku
         UPDATE WMSBOM
         SET WMS_FLAG = 'E4'
         WHERE SKU NOT IN (SELECT sku from SKU)
         AND WMS_FLAG = 'N'
         IF EXISTS (SELECT 1 FROM WMSBOM WHERE SUBSTRING(WMS_FLAG,1,1) = 'E' AND ADDWHO = @c_hikey )
         BEGIN
            INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType, sourcekey )
            VALUES ( @c_hikey, 'There are invalid storerkeys/skus. ' , 'GENERAL', ' ')
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspImportBOM)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
         END
      END

   END -- if @n_continue
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO BILLOFMATERIAL ( Storerkey, SKU, ComponentSku, Sequence, BOMONLY, Notes, Qty)
      SELECT Storerkey, Sku, ComponentSku, Sequence, BomOnly, Notes, Qty
      FROM WMSBOM
      WHERE WMS_FLAG = 'N'
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62201   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On BillOfMaterial (nspImportBOM)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      -- update the flag to received 'R' after successful import
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         UPDATE WMSBOM
         SET WMS_FLAG = 'R'
         WHERE WMS_FLAG = 'N'
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspImportBOM. Process completed for ' + @c_hikey + '. Process ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspImportBOM)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
      execute nsp_logerror @n_err, @c_errmsg, "nspImportBOM"
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
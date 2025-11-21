SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspImportRec                                       */
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

CREATE PROC    [dbo].[nspImportRec]
@b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int             , -- For Additional Error Detection
   @b_debug int              -- Debug: 0 - OFF, 1 - show all, 2 - map
   select @b_debug = 1, @n_continue = 1
   Declare @c_storerkey NVARCHAR(15)
   ,   @c_sku NVARCHAR(20)
   ,   @n_qty int
   ,   @c_loc NVARCHAR(10)
   ,   @n_count int
   declare @n_lineno int, @c_line NVARCHAR(10)
   declare @c_lineno NVARCHAR(5)
   ,   @c_receiptkey NVARCHAR(10)
   ,   @c_packkey NVARCHAR(10)
   ,   @c_uom NVARCHAR(10)
   -- validation section
   -- 1. validate storerkey
   UPDATE RECUPLOAD
   SET Flag = 'E', Message = 'Invalid Storerkey'
   WHERE Storerkey NOT IN (SELECT Storerkey from STORER (nolock) )
   AND Flag = 'N'
   -- 2. Validate SKU
   UPDATE RECUPLOAD
   Set Flag = 'E', Message = 'Invalid SKU and Storerkey Combination'
   WHERE SKU NOT IN (select sku.SKU
   from SKU (nolock), RECUPLOAD (NolocK)
   WHERE SKU.SKU = RECupload.SKU
   AND SKU.Storerkey = RECUPLOAD.Storerkey)
   AND Flag = 'N'
   UPDATE RECUPLOAD
   Set Flag = 'E', Message = 'Qty has 0(Zero) value'
   WHERE Qty = '0'
   AND Flag = 'N'
   -- End of Validation Section
   DECLARE curx CURSOR  FAST_FORWARD READ_ONLY FOR
   SELECT STORERKEY, SKU, Qty, LOC
   FROM RECUPLOAD (NOLOCK)
   WHERE FLAG = 'N'
   OPEN curx
   SELECT @n_count = 0
   /*
   insert into receipt (receiptkey,storerkey)
   values ('0000000001', 'JDH30')
   insert into receiptdetail (receiptkey, receiptlinenumber, storerkey, sku, qtyexpected, toloc, packkey, uom)
   values ('0000000001', '00001', 'JDH30', '0130002', 10, 'STAGE', '0012x00420','TIN' )
   */
   SELECT @c_receiptkey = ''
   WHILE (1 = 1)
   BEGIN
      FETCH NEXT FROM curx INTO @c_storerkey, @c_sku, @n_qty, @c_loc
      IF @@FETCH_STATUS <> 0 BREAK
      IF @n_continue = 3 BREAK
      select @n_count
      IF @n_count = 10 OR @n_count = 0
      BEGIN
         SELECT @n_count = 0
         -- generate new receiptkey
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspg_GetKey
            "Receipt",
            10,
            @c_receiptkey OUTPUT,
            @b_success   	 OUTPUT,
            @n_err       	 OUTPUT,
            @c_errmsg    	 OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg
            END
         END
         -- reinitialize receiptlinenumber
         SELECT @n_lineno = 1
         select @c_line = REPLICATE('0', 4)  + convert(char(5),@n_lineno)
         SELECT @c_lineno = RIGHT(@c_line , 5)
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            -- INSERT INTO receipt table,
            INSERT INTO RECEIPT ( Receiptkey, STorerkey , CarrierAddress1,EditWho)
            VALUES ( @c_receiptkey, @c_storerkey , 'Inventory Upload','dbo')
            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 65002
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting into RECEIPT (nspImportRec)"
            END
         END
      END
      -- get the packkey and uom
      SELECT @c_packkey = PACKKEY FROM SKU (NOLOCK) WHERE Storerkey = @c_storerkey and SKU = @c_sku
      IF @c_packkey = ''
      BEGIN
         UPDATE RECUPLOAD
         SET FLAG = 'E', MESSAGE = 'Packkey is not setup in SKU table.'
         WHERE SKU = @c_sku
         AND Storerkey = @c_storerkey
      END
   ELSE
      BEGIN
         SELECT @c_uom = PACKUOM3 FROM PACK (nOLOCK) WHERE PACKKEY = @c_packkey
         IF @c_uom = ''
         BEGIN
            select @c_uom = 'EA' -- default EA if it's not setup.
         END
         IF @b_debug = 1
         BEGIN
            SELECT 'Receiptkey' = @c_receiptkey, 'LineNumber' = @c_lineno, 'Storerkey' = @c_storerkey
         END
         INSERT INTO RECEIPTDETAIL (receiptkey, receiptlinenumber, storerkey, sku, qtyexpected, toloc, packkey, uom)
         VALUES ( @c_receiptkey, @c_lineno, @c_storerkey, @c_sku, @n_qty, @c_loc, @c_packkey, @c_uom)
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 65003
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting into RECEIPTDETAIL (nspImportRec)"
         END
      END
      -- generate the next lineno
      SELECT @n_lineno = @n_lineno + 1
      select @c_line = REPLICATE('0', 4)  + convert(char(5),@n_lineno)
      SELECT @c_lineno = RIGHT(@c_line , 5)
      SELECT @n_count = @n_count + 1
   END -- While
   CLOSE curx
   DEALLOCATE curx
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
      execute nsp_logerror @n_err, @c_errmsg, "nspImportRec"
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
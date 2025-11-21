SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_TransferDetailInterface_OW                     */
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
/* 06/11/2002 Leo Ng  Program rewrite for IDS version 5                 */
/************************************************************************/
CREATE PROC  [dbo].[nsp_TransferDetailInterface_OW]
@c_transferkey           NVARCHAR(10),
@c_transferlinenumber    NVARCHAR(5),
@c_type                  NVARCHAR(10),
@b_success               int      output,
@n_err                   int      output,
@c_errmsg                NVARCHAR(25) output
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   Declare @n_continue     int,
   @n_starttcnt    int,  -- Holds the current transaction count
   @c_trmlogkey    NVARCHAR(10)
   SET NOCOUNT ON
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=""
   IF EXISTS( SELECT 1 FROM CODELKUP (NOLOCK) WHERE CODELKUP.Code = @c_type AND
   CODELKUP.ListName = 'TRANTYPE' AND
   CODELKUP.LONG = 'OW')
   BEGIN
      IF NOT EXISTS( SELECT 1 FROM TRANSMITLOG (NOLOCK) WHERE TableName = 'OWTRFADJ' AND KEY1 = @c_transferkey
      AND Key2 = @c_transferlinenumber
      AND Key3 = 'F') -- Add by June 2.Feb.02
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspg_getkey
         "transmitlogkey"
         , 10
         , @c_trmlogkey OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to obtain transmitlogkey (nsp_TransferDetailInterface_OW)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      ELSE
         BEGIN
            INSERT INTO transmitlog (transmitlogkey, tablename, key1, key2, key3, transmitflag)
            VALUES (@c_trmlogkey, 'OWTRFADJ', @c_transferkey , @c_transferlinenumber,'F', '0')
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to obtain transmitlogkey (nsp_TransferDetailInterface_OW)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
         END	-- success = 1
      END -- not exists in transmitlog
      -- Start - Add by June 2.Feb.02 - Insert 2 records for 'Transfer' Records
      IF NOT EXISTS( SELECT 1 FROM TRANSMITLOG (NOLOCK) WHERE TableName = 'OWTRFADJ' AND KEY1 = @c_transferkey
      AND Key2 = @c_transferlinenumber
      AND Key3 = 'T')
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspg_getkey
         "transmitlogkey"
         , 10
         , @c_trmlogkey OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to obtain transmitlogkey (nsp_TransferDetailInterface_OW)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      ELSE
         BEGIN
            INSERT INTO transmitlog (transmitlogkey, tablename, key1, key2, key3, transmitflag)
            VALUES (@c_trmlogkey, 'OWTRFADJ', @c_transferkey , @c_transferlinenumber,'T', '0')
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to obtain transmitlogkey (nsp_TransferDetailInterface_OW)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
         END	-- success = 1
      END -- End - Add by June not exists in transmitlog
   END -- this trantype need to interface back to OW

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
      execute nsp_logerror @n_err, @c_errmsg, "nsp_TransferDetailInterface_OW"
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

END -- Main

GO
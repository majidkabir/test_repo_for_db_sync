SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspaltertable                                      */
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
/* 10-Sep-2008	 TLTING			SQl2005 change of behaviour on variable 	*/
/*                            space   tlting01                          */
/* 13-Jun-2012  KHLim01       increase storage size for length          */
/************************************************************************/

CREATE PROC [dbo].[nspaltertable]
@c_field    NVARCHAR(50),
@n_length   int,        -- KHLim01
@c_typename NVARCHAR(32),
@c_tablename NVARCHAR(50),
@c_copyto_db NVARCHAR(55),
@c_inclen    NVARCHAR(25),
@b_success int OUTPUT,
@n_err int OUTPUT,
@c_errmsg NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @b_debug int              -- Debug On Or Off
   DECLARE @c_msg      NVARCHAR(255)
   SELECT @c_msg = ''
   SELECT @n_continue = 1
   SELECT @b_debug = 0
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_msg = ' Alter Table ' + @c_copyto_db + '..' +
      @c_tablename + ' ADD ' +' ' +  @c_field + ' ' +   @c_typename +
      @c_inclen + ' ' + 'NULL'     -- tlting01 
      IF (@b_debug = 1)
      BEGIN
         SELECT 'in sp_alter proc', @c_msg
      END
      EXEC (@c_msg)
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 73601
         SELECT @c_errmsg = CONVERT(char(250),@n_err)
         + ":  dynamic execute failed. (nspaltertable) " + " ( " +
         " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ")"
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nspaltertable"
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
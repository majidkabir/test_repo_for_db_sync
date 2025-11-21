SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispGenNSCLog                                       */
/* Creation Date: 20-Feb-2004                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose:  Trigger records into the NSCLog table for Interfaces.      */
/*                                                                      */
/* Input Parameters:  @c_TableName     - Tablename                      */
/*                    @c_Key1          - Key #1                         */
/*                    @c_Key2          - Key #2                         */
/*                    @c_Key3          - Key #3                         */
/*                    @c_TransmitBatch - Transmit Batch                 */
/*                                                                      */
/* Output Parameters:  @b_Success                                       */
/*                     @n_err                                           */
/*                     @c_errmsg                                        */
/*                                                                      */
/* Usage:  Store Records for Interfaces.                                */
/*                                                                      */
/* Called By:  Trigger/Store Procedure.                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 25-Jul-2006  YokeBeen  Extended the length of the parameter -        */
/*                        Tablename from NVARCHAR(10) to NVARCHAR(30).          */
/*                                                                      */
/************************************************************************/

CREATE PROC   [dbo].[ispGenNSCLog]
               @c_TableName    NVARCHAR(30)
,              @c_Key1         NVARCHAR(10)
,              @c_Key2         NVARCHAR(5)
,              @c_Key3         NVARCHAR(20)
,              @c_TransmitBatch NVARCHAR(10) 
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE	@n_continue int         ,  
			@n_starttcnt int        , -- Holds the current transaction count
			@c_preprocess NVARCHAR(250) , -- preprocess
			@c_pstprocess NVARCHAR(250) , -- post process
			@n_err2 int               -- For Additional Error Detection

DECLARE @c_trmlogkey NVARCHAR(10)

SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0,@c_errmsg="", @n_err2=0
     /* #INCLUDE <SPIAD1.SQL> */     

IF ISNULL(dbo.fnc_RTrim(@c_Key1),'') = '' 
BEGIN
   RETURN
END

SELECT @c_Key2 = ISNULL(dbo.fnc_RTrim(@c_Key2), '')
SELECT @c_Key3 = ISNULL(dbo.fnc_RTrim(@c_Key3), '')
SELECT @c_TransmitBatch = ISNULL(dbo.fnc_RTrim(@c_TransmitBatch), '')

IF @n_continue=1 OR @n_continue=2
BEGIN
   SELECT @b_success = 1
	IF NOT EXISTS ( SELECT 1 FROM NSCLog (NOLOCK) WHERE TableName = @c_TableName 
							 AND Key1 = @c_Key1 AND Key2 = @c_Key2 AND Key3 = @c_Key3)
   BEGIN
		SELECT @b_success = 1

		EXECUTE nspg_getkey
		'NSCKEY'
		, 10
		, @c_trmlogkey OUTPUT
		, @b_success   OUTPUT
		, @n_err       OUTPUT
		, @c_errmsg    OUTPUT

		IF NOT @b_success = 1
		BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL" + CONVERT(CHAR(5),@n_err) + ": Unable to Obtain NSCLogkey. (ispGenNSCLog)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      ELSE 
      BEGIN
         INSERT INTO NSCLog (NSCLogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
         VALUES (@c_trmlogkey, @c_TableName, @c_Key1, @c_Key2, @c_Key3, '0', @c_TransmitBatch)
      END
   END

     /* #INCLUDE <SPIAD2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, "ispGenNSCLog"
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
END -- procedure 

GO
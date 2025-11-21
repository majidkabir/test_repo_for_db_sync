SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nspg_GetKeyMinMax                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  update ncounter if exceed the min & max range              */
/*           Generate a new key                                         */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Interfaces.                                                  */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  nsp_GetPickSlipNike02                                    */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 10-Jun-2005  ONG       Update ncounter if exceed the min & max range */
/*                        Generate a new key                            */
/* 24-Apr-2012  NJOW01    241943-Reset keycount when hit max count      */
/* 24-Jan-2019  WLCHOOI   WMS-7739 Change @Min & @Max to BIGINT         */
/************************************************************************/

CREATE PROC    [dbo].[nspg_GetKeyMinMax] 
					@keyname       NVARCHAR(18)
,              @fieldlength   int
,              @Min           BIGINT
,              @Max           BIGINT
,              @keystring     NVARCHAR(25)       OUTPUT
,              @b_Success     int            OUTPUT
,              @n_err         int            OUTPUT
,              @c_errmsg      NVARCHAR(250)      OUTPUT
,              @b_resultset   int       = 0
,              @n_batch       int       = 1
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
DECLARE @n_count int /* next key */
DECLARE @n_ncnt int
DECLARE @n_starttcnt int /* Holds the current transaction count */
DECLARE @n_continue int /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */
DECLARE @n_cnt int /* Variable to record if @@ROWCOUNT=0 after UPDATE */
SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=""

BEGIN TRANSACTION 

UPDATE ncounter SET keycount = keycount WHERE keyname = @keyname
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

IF @n_err <> 0
BEGIN
  SELECT @n_continue = 3 
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
  IF @n_cnt > 0
  BEGIN
		-- To reset the Counter if (KeyCount > @Max or KeyCount < @Min) 
--      IF EXISTS (SELECT 1 FROM ncounter (NOLOCK) WHERE keyname = @keyname And (KeyCount > @Max or KeyCount < @Min))
      IF ISNULL(@Min,0) > 0 AND EXISTS (SELECT 1 FROM ncounter (NOLOCK) WHERE keyname = @keyname And (KeyCount < @Min))
      BEGIN
         UPDATE ncounter SET keycount = @Min - 1
         WHERE  keyname = @keyname
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT			 
      END
      
      --NJOW01
      IF ISNULL(@Max,0) > 0 AND EXISTS (SELECT 1 FROM ncounter (NOLOCK) WHERE keyname = @keyname And (KeyCount + @n_batch > @Max))
      BEGIN
         UPDATE ncounter SET keycount = @Min - 1
         WHERE  keyname = @keyname
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT			       	
      END
      
      -- Update the counter with @n_batch
      UPDATE ncounter SET keycount = keycount + @n_batch WHERE keyname = @keyname
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3 
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Ncounter:"+@keyname+". (nspg_getkey)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      ELSE IF @n_cnt = 0
      BEGIN
          SELECT @n_continue = 3 
          SELECT @n_err=61901
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update To Table Ncounter:"+@keyname+" Returned Zero Rows Affected. (nspg_getkey)"
      END
  END
  ELSE BEGIN   -- if keyname is new, then insert a new record into ncounter table
      INSERT ncounter (keyname, keycount) VALUES (@keyname, @n_batch + @Min - 1 )
      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3 
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61902   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Ncounter:"+@keyname+". (nspg_getkey)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
  END

  IF @n_continue=1 OR @n_continue=2
  BEGIN
      SELECT @n_count = keycount - @n_batch FROM ncounter WHERE keyname = @keyname

      SELECT @keystring = dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(CHAR(18),@n_count + 1)))

      DECLARE @bigstring NVARCHAR(50)
      SELECT @bigstring = dbo.fnc_RTrim(@keystring)
      SELECT @bigstring = Replicate("0",25) + @bigstring
      SELECT @bigstring = RIGHT(dbo.fnc_RTrim(@bigstring), @fieldlength)
      SELECT @keystring = dbo.fnc_RTrim(@bigstring)

      IF @b_resultset = 1
      BEGIN
          SELECT @keystring "c_keystring", @b_Success "b_success", @n_err "n_err", @c_errmsg "c_errmsg" 
      END
  END
END

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
  SELECT @b_success = 0     
  IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
      BEGIN
          ROLLBACK TRAN
      END
      ELSE BEGIN
          WHILE @@TRANCOUNT > @n_starttcnt 
          BEGIN
              COMMIT TRAN
          END          
      END
     EXECUTE nsp_logerror @n_err, @c_errmsg, "nspg_getkey"
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
     RETURN
  END
  ELSE BEGIN
		SELECT @b_success = 1
		WHILE @@TRANCOUNT > @n_starttcnt 
		BEGIN
          COMMIT TRAN
		END
		RETURN
END

GO
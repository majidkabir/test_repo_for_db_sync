SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************/
/* Start Create Procedure Here                                   */
/*****************************************************************/
CREATE PROC    [dbo].[nspRFPK02]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_ordno		        NVARCHAR(10)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   -- SET ANSI_DEFAULTS OFF
   DECLARE @b_debug int
   SELECT @b_debug = 0
   IF @c_taskId = 'DS1'
   BEGIN
      SELECT @b_debug = 1
   END

   DECLARE @c_loadno  NVARCHAR(10)

   DECLARE  @n_continue int        ,  /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int               -- For Additional Error Detection

   /* Declare RF Specific Variables */
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   DECLARE @c_dbnamestring NVARCHAR(255)
   DECLARE @n_cqty int, @n_returnrecs int

   /* Set default values for variables */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1

   /* Execute Preprocess */
   /* #INCLUDE <SPRFPK02_1.SQL> */
   /* End Execute Preprocess */

   /* Get load key */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SET ROWCOUNT 1 

      SELECT @c_loadno = loadkey 
      FROM   ORDERS (NOLOCK) 
      WHERE  Orderkey = @c_ordno

      IF @@rowcount = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 90001
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Order# does not exist (nspRFPK02)"
      END
      SET ROWCOUNT 0 

   END

   /* Set RF Return Record */
   IF @n_continue=3
   BEGIN
      SELECT @c_retrec="09"
   END
   /* End Set RF Return Record */

   /* Construct RF Return String */
   SELECT @c_outstring =   @c_ptcid        + @c_senddelimiter
   + dbo.fnc_RTrim(@c_userid)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_taskid)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_databasename)     + @c_senddelimiter
   + dbo.fnc_RTrim(@c_appflag)          + @c_senddelimiter
   + dbo.fnc_RTrim(@c_retrec)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_server)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_loadno)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_errmsg)
   SELECT dbo.fnc_RTrim(@c_outstring)
   /* End Main Processing */

   /* Return Statement */
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
      execute nsp_logerror @n_err, @c_errmsg, "nspRFPK02"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      /* Error Did Not Occur , Return Normally */
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
   /* End Return Statement */
END


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************/
/* Start Create Procedure Here                                   */
/*****************************************************************/
CREATE PROC    [dbo].[nspRFPK05]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)	
,	            @c_psno		        NVARCHAR(10)
,	            @c_ordno		        NVARCHAR(10)
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

   DECLARE  @n_continue int,  /* continuation flag
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
   DECLARE @n_returnrecs int

   /* Set default values for variables */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1

   DECLARE 	@n_aqty int,
            @n_pqty int

	-- Start : SOS32132
	DECLARE @c_consoflag NVARCHAR(1), @c_orderkey NVARCHAR(10),  @c_loadkey NVARCHAR(10)
	SELECT @c_consoflag = 'N'

	SELECT @c_loadkey  = ph.ExternOrderkey,
			 @c_orderkey = ph.Orderkey
	FROM   PICKHEADER ph (NOLOCK)	
	WHERE  ph.Pickheaderkey = @c_psno
	IF @c_orderkey IS NULL OR @c_orderkey = ''
	BEGIN
		SELECT @c_consoflag = 'Y'
	END
	-- End : SOS32132

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
		-- Start : SOS32132
		/*
      select @n_aqty = sum(orderdetail.qtyallocated) 
      from   orderdetail(nolock)
      where  orderkey = @c_ordno
		*/
		IF @c_consoFlag = 'N'
		BEGIN
	      select @n_aqty = sum(orderdetail.qtyallocated) 
	      from   orderdetail(nolock)
	      where  orderkey = @c_orderkey
		END
		ELSE
		BEGIN
	      select @n_aqty = sum(orderdetail.qtyallocated) 
	      from   orderdetail(nolock)
	      where  Loadkey = @c_loadkey
		END
		-- End : SOS32132

      select @n_pqty = sum(qty) 
      from  packdetail(nolock)
      where pickslipno = @c_psno

      IF @n_aqty <> @n_pqty
      BEGIN
         SELECT @n_continue = 3 
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 67890   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Total packed quantity and total picked quantity differs (nspRFPK05)" 
      END
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
   + dbo.fnc_RTrim(convert(char(10), @n_aqty)) + @c_senddelimiter
   + dbo.fnc_RTrim(convert(char(10), @n_pqty)) + @c_senddelimiter
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
      execute nsp_logerror @n_err, @c_errmsg, "nspRFPK05"
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
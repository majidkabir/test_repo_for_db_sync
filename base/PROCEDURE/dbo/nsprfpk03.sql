SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************/
/* Start Create Procedure Here                                   */
/*****************************************************************/
CREATE PROC    [dbo].[nspRFPK03]
               @c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_psno		        NVARCHAR(10)
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

   DECLARE @n_cartonno 	     int,
           @n_maxcartonno 	  int,
           @c_labelno	     NVARCHAR(20),
           @c_Storerkey      NVARCHAR(15) 

   DECLARE @c_vat            NVARCHAR(9), 
           @c_ncounter       NVARCHAR(7),
           @c_UCCLabelConfig NVARCHAR(1)

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
   DECLARE @c_retrec NVARCHAR(2) -- Return Record '01' = Success, '09' = Failure
   DECLARE @c_dbnamestring NVARCHAR(255)
   DECLARE @n_cqty int, @n_returnrecs int

   /* Set default values for variables */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_err2=0
   SELECT @c_retrec = '01'
   SELECT @n_returnrecs=1

   /* Get carton number */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      select @n_maxcartonno =  MAX(Cartonno)
      FROM		PackDetail (NOLOCK)
      WHERE		PickSlipNo = @c_psno

      IF @n_maxcartonno is null
      BEGIN
         SELECT @n_cartonno = 1
      END
   ELSE
      BEGIN
         SELECT @n_cartonno = @n_maxcartonno + 1
      END
   END

   /* Generate label number */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SET ROWCOUNT 1

      SELECT 	@c_vat = STORER.Vat, 
               @c_Storerkey = StorerConfig.StorerKey, 
               @c_UCCLabelConfig = ISNULL(StorerConfig.sValue, '0')  
		FROM	  	ORDERS (NOLOCK) 
      JOIN     STORER (NOLOCK) ON (STORER.Storerkey = ORDERS.Storerkey)
      JOIN     LOADPLANDETAIL (NOLOCK) ON (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)
      JOIN     PICKHEADER (NOLOCK) ON (LOADPLANDETAIL.Loadkey = PICKHEADER.ExternOrderKey)
		LEFT OUTER JOIN StorerConfig (NOLOCK) ON (STORER.StorerKey = StorerConfig.StorerKey)
		WHERE ConfigKey = 'GenUCCLabelNoConfig'
      AND   PICKHEADER.Pickheaderkey = @c_psno

      IF dbo.fnc_RTrim(@c_StorerKey) IS NULL OR dbo.fnc_RTrim(@c_StorerKey) = ''
         SELECT @c_UCCLabelConfig = '0'
      
      
      IF @c_UCCLabelConfig = '1' 
      BEGIN
         EXECUTE nspg_getkey
         'TBLPackNo',
         7,
         @c_ncounter OUTPUT,
         @b_success OUTPUT,
         @n_err OUTPUT,
         @c_errmsg OUTPUT

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate TBL Pack No failed. (nspRFPK03)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         IF (@c_vat is null) OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_vat)) = ''
         BEGIN
            SELECT @c_vat = '000000000'
         END
   
         declare @c_checkdigit NVARCHAR(1), @n_odd int, @n_even int, @n_len int

         SELECT @c_labelno = ('00' + '0' + dbo.fnc_RTrim(@c_vat)  + dbo.fnc_RTrim(@c_ncounter))
         select @n_len = len(@c_labelno)
   

         DECLARE @n_totalcnt int,
                 @n_totaloddcnt int,
                 @n_totalevencnt int,
                 @n_add int,
                 @n_devide int,
                 @n_remain int,
                 @n_oddcnt int,
                 @n_evencnt int

         SELECT @n_totalcnt = 0, @n_totaloddcnt = 0, @n_totalevencnt = 0, @n_add = 0,
                @n_devide = 0,   @n_remain = 0,      @n_oddcnt= 0,        @n_evencnt = 0
   
         SELECT @n_odd = 1
   
         WHILE @n_odd <= @n_len
         BEGIN
            IF substring(@c_labelno, @n_odd,1) in ('0','1','2','3','4','5','6','7','8','9')
            BEGIN
               SELECT @n_oddcnt = convert(int,Substring(@c_labelno, @n_odd,1))
            END
            ELSE
            BEGIN
               SELECT @n_oddcnt = 0
            END
            SELECT @n_totaloddcnt = (@n_totaloddcnt + @n_oddcnt)
            SELECT @n_odd = @n_odd + 2
         END

         SELECT @n_totalcnt = (@n_totaloddcnt * 3)
   
   
         SELECT @n_even = 2
   
         WHILE @n_even <= @n_len
         BEGIN
            IF Substring(@c_labelno, @n_even,1) in ('0','1','2','3','4','5','6','7','8','9')
            BEGIN
               SELECT @n_evencnt = convert(int,Substring(@c_labelno, @n_even,1))
               --select '@n_evencnt = ', @n_evencnt
            END
            ELSE
            BEGIN
               SELECT @n_evencnt = 0
            END
            SELECT @n_totalevencnt = (@n_totalevencnt + @n_evencnt)
            --select '@n_totalevencnt = ', @n_totalevencnt
            SELECT @n_even = @n_even + 2
         END


         DECLARE @n_checkdigit int
         SELECT @n_add = @n_totalcnt + @n_totalevencnt
         SELECT @n_remain = @n_add %10
         SELECT @n_checkdigit = (10 - (@n_remain))
   
         --select '@n_checkdigit = ', @n_checkdigit
         IF @n_checkdigit = 10
         BEGIN
            SELECT @n_checkdigit = 0
         END
   
         SELECT @c_checkdigit = convert(char(1),@n_checkdigit)
         SELECT @c_labelno = dbo.fnc_RTrim(@c_labelno) + @c_checkdigit
      END -- IF @c_UCCLabelConfig = '1' 
      ELSE
      BEGIN
         EXECUTE nspg_getkey
         'PackNo',
         10,
         @c_labelno OUTPUT,
         @b_success OUTPUT,
         @n_err OUTPUT,
         @c_errmsg OUTPUT

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Pack No failed. (nspRFPK03)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

      END -- IF @c_UCCLabelConfig = '0' 
   END -- if continue = 1 or 2 

   /* Set RF Return Record */
   IF @n_continue=3
   BEGIN
      SELECT @c_retrec='09'
   END
   /* End Set RF Return Record */

   /* Construct RF Return String */
   SELECT @c_outstring =   @c_ptcid  + @c_senddelimiter
   + dbo.fnc_RTrim(@c_userid)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_taskid)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_databasename)     + @c_senddelimiter
   + dbo.fnc_RTrim(@c_appflag)          + @c_senddelimiter
   + dbo.fnc_RTrim(@c_retrec)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_server)           + @c_senddelimiter
   + dbo.fnc_RTrim(convert (char(4), @n_cartonno)) + @c_senddelimiter
   + dbo.fnc_RTrim(@c_labelno)          + @c_senddelimiter
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
      execute nsp_logerror @n_err, @c_errmsg, 'nspRFPK03'
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
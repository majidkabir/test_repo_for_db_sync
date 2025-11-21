SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************/
/* Start Create Procedure Here                                   */
/*****************************************************************/
CREATE PROC    [dbo].[nspRFPK04]
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
,	            @n_cartonno	        int
,	            @c_labelno	        NVARCHAR(20)
,              @c_sku		        NVARCHAR(20)
,	            @n_qty		        int
,	            @c_psku	           NVARCHAR(20)
,	            @n_pcartonno	     int
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
-- (@c_psno, @n_cartonno, @c_labelno, @c_LabelLine, @c_storekey, @c_sku, @n_qty)
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
   DECLARE @n_returnrecs int

   /* Added By Vicky 20 May 2003 - Exceed V5.1 */
   Declare @c_uccpack NVARCHAR(1),
   @c_uccstatus NVARCHAR(1),
   @ll_found int,
   @n_uccqty int,
   @c_uccsku NVARCHAR(20)

   /* Set default values for variables */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_err2=0
   SELECT @c_retrec = '01'
   SELECT @n_returnrecs=1

   DECLARE @c_route NVARCHAR(10),
   @c_orderkey NVARCHAR(10),
   @c_externorderkey NVARCHAR(30),
   @c_loadkey NVARCHAR(10),
   @c_consigneekey NVARCHAR(15),
   @c_storerkey NVARCHAR(15),
   @n_cnt int,
   @c_descr NVARCHAR(15),
   @n_aqty int,
   @n_pqty int,
   @n_cqty int,
   @c_LabelLine NVARCHAR(5),
   @n_MaxLabelLineNo int,
   @n_allocatedqty int,
   @n_packedqty int

   /* get storerkey */
	-- Start : SOS32132
	/*
   SELECT @c_storerkey = Orders.Storerkey 
   FROM  ORDERS(nolock)
   WHERE ORDERKEY = @c_ordno
	*/
	DECLARE @c_consoflag NVARCHAR(1)
	SELECT @c_consoflag = 'N'

	SELECT @c_loadkey  = ph.ExternOrderkey,
			 @c_orderkey = ph.Orderkey
	FROM   PICKHEADER ph (NOLOCK)	
	WHERE  ph.Pickheaderkey = @c_psno

	IF @c_orderkey IS NULL OR @c_orderkey = ''
	BEGIN
		SELECT @c_consoflag = 'Y'
	END

	IF @c_consoflag = 'Y'
	BEGIN
	   SELECT @c_storerkey = MIN(Orders.Storerkey)
	   FROM  ORDERS(nolock)
	   WHERE Loadkey = @c_Loadkey
	END
	ELSE
	BEGIN
	   SELECT @c_storerkey = Orders.Storerkey 
	   FROM  ORDERS(nolock)
	   WHERE ORDERKEY = @c_orderkey		
	END
	-- End : SOS32132

	-- Start : SOS32132
	-- Get the actual SKU code if ser scan-in Manufacturer or Retail code
  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL
  BEGIN     
    SELECT @b_success = 0
	 DECLARE @c_uom  NVARCHAR(10), @c_packkey NVARCHAR(10)
    EXECUTE nspg_GETSKU1
          @c_StorerKey  = @c_StorerKey,
          @c_sku        = @c_sku     OUTPUT,
          @b_success    = @b_success OUTPUT,
          @n_err        = @n_err     OUTPUT,
          @c_errmsg     = @c_errmsg  OUTPUT,
          @c_uom        = @c_uom     OUTPUT,
          @c_packkey    = @c_packkey OUTPUT

    IF NOT @b_success = 1
    BEGIN
         SELECT @n_continue = 3
    END

    IF @b_debug = 1
    BEGIN
         SELECT @c_sku "@c_sku after nspGetSku"
    END
  END      
	/*
	IF NOT EXISTS(SELECT 1 FROM ORDERDETAIL(NOLOCK) WHERE Loadkey = @c_loadkey AND SKU = @c_sku)
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 80005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': SKU does not exist in this order (nspRFPK04)' 
   END
	*/
	IF @c_consoflag = 'N'
	BEGIN
		IF NOT EXISTS(SELECT 1 FROM ORDERDETAIL(NOLOCK) WHERE Orderkey = @c_orderkey AND SKU = @c_sku)
	   BEGIN
	      SELECT @n_continue = 3
	      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 80005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': SKU does not exist in this order (nspRFPK04)' 
	   END
	END
	ELSE
	BEGIN -- Conso - by Load
		IF NOT EXISTS(SELECT 1 FROM ORDERDETAIL(NOLOCK) WHERE Loadkey = @c_Loadkey AND SKU = @c_sku)
	   BEGIN
	      SELECT @n_continue = 3
	      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 80005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': SKU does not exist in this order (nspRFPK04)' 
	   END
	END
	-- End : SOS32132

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
		-- Start : SOS32132		
		/*
      SELECT @n_allocatedqty = sum(orderdetail.qtyallocated) 
      from   orderdetail(nolock)
      where  orderkey = @c_ordno
      and    sku = @c_psku
		*/
		IF @c_consoflag = 'N'
		BEGIN
	      SELECT @n_allocatedqty = sum(orderdetail.qtyallocated) 
	      from   orderdetail(nolock)
	      where  orderkey = @c_orderkey
	      and    sku = @c_sku
		END
		ELSE
		BEGIN
	      SELECT @n_allocatedqty = sum(orderdetail.qtyallocated) 
	      from   orderdetail(nolock)
	      where  Loadkey = @c_loadkey
	      and    sku = @c_sku
		END
		-- End : SOS32132

      IF @n_allocatedqty is null
      BEGIN
         select @n_allocatedqty = 0
      END

      SELECT @n_packedqty = sum(qty) 
      from  packdetail(nolock)
      where pickslipno = @c_psno
      and   sku = @c_sku

      IF @n_packedqty is null
      BEGIN
         select @n_packedqty = 0
      END

      IF @n_packedqty + @n_qty > @n_allocatedqty
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 80009   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Pack Qty Exceeds Allocated Qty (nspRFPK04)' 
      END

      IF @n_packedqty + @n_qty < 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 80010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Pack Qty will fall below 0 (nspRFPK04)' 
      END
   END

   /* create packheader */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
		-- SOS32132
      -- IF NOT EXISTS(SELECT 1 FROM PACKHEADER(NOLOCK) WHERE PICKSLIPNO = @c_psno AND ORDERKEY = @c_ordno)
		IF NOT EXISTS(SELECT 1 FROM PACKHEADER(NOLOCK) WHERE PICKSLIPNO = @c_psno)
      BEGIN
			-- Start : SOS32132
			/*
         SELECT @c_route = Orders.Route,
                @c_externorderkey = Orders.ExternOrderKey,
                @c_loadkey = Orders.LoadKey,
                @c_consigneekey = Orders.ConsigneeKey
         FROM Orders (NOLOCK)
         WHERE Orders.OrderKey = @c_ordno

         INSERT PACKHEADER(Pickslipno, StorerKey, Route, OrderKey, OrderRefno, LoadKey, ConsigneeKey)
         VALUES		 (@c_psno, @c_storerkey, @c_route, @c_ordno, @c_externorderkey, @c_loadkey, @c_consigneekey)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 80001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into packheader table failed. (nspRFPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
			*/
			IF @c_consoflag = 'N'
			BEGIN
	         SELECT @c_route = Orders.Route,
	                @c_externorderkey = Orders.ExternOrderKey,
	                @c_loadkey = Orders.LoadKey,
	                @c_consigneekey = Orders.ConsigneeKey
	         FROM  Orders (NOLOCK)
	         WHERE Orders.OrderKey = @c_orderkey

		      INSERT PACKHEADER(Pickslipno, StorerKey, Route, OrderKey, OrderRefno, LoadKey, ConsigneeKey)
	         VALUES		     (@c_psno, @c_storerkey, @c_route, @c_orderkey, @c_externorderkey, @c_loadkey, @c_consigneekey)	
	         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
	         IF @n_err <> 0
	         BEGIN
	            SELECT @n_continue = 3
	            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 80001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into packheader table failed. (nspRFPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
	         END
			END -- Conso = 'N'
			ELSE
			BEGIN	
	         INSERT PACKHEADER(Pickslipno, StorerKey, LoadKey, Orderkey)
	         VALUES		 (@c_psno, @c_storerkey, @c_loadkey, '')	
	         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
	         IF @n_err <> 0
	         BEGIN
	            SELECT @n_continue = 3
	            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 80001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into packheader table failed. (nspRFPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
	         END
			END -- Conso = 'Y'
		END -- Not in Packheader
	END

   /* Added By Vicky 20 May 2003 - Exceed V5.1
   Cater for UCC Scanning */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN

      SELECT @b_success = 0
   
      Execute nspGetRight null,	-- facility
         @c_storerKey, 	-- Storerkey
         null,				-- Sku
         'UCCPACK',		   -- Configkey
         @b_success		output,
         @c_uccpack 	   output,
         @n_err			output,
         @c_errmsg		output
   
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'nspRFPK04' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE
      IF @c_uccpack <> '1'
      BEGIN -- configkey not on
      /* create packdetail */
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM PACKDETAIL(NOLOCK)
                          WHERE  PickSlipNo = @c_psno
                          AND		labelno = @c_labelno
                          AND		sku     = @c_sku)
            BEGIN
               SELECT @n_MaxLabelLineNo = MAX(LabelLine)
               FROM	 PackDetail (NOLOCK)
               WHERE  PickSlipNo = @c_psno

               IF @n_MaxLabelLineNo is null or @n_MaxLabelLineNo = 0
               BEGIN
                  SELECT @c_LabelLine = '00001'
               END
               ELSE
               BEGIN
                  SELECT @c_LabelLine = RIGHT('0000' + CONVERT(varchar(5), @n_MaxLabelLineNo + 1), 5)
               END
      
               INSERT PACKDETAIL(PickslipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty)
               VALUES (@c_psno, @n_cartonno, @c_labelno, @c_LabelLine, @c_storerkey, @c_sku, @n_qty)
      
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 80002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into packdetail table failed. (nspRFPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
            ELSE
            BEGIN
               UPDATE PACKDETAIL SET QTY = QTY + @n_qty
               WHERE PICKSLIPNO = @c_psno
               AND LABELNO = @c_labelno
               AND SKU = @c_sku
      
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 80003   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update to packdetail table failed. (nspRFPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
         END -- if continue = 1 or 2
      END -- configkey not on
      ELSE
      BEGIN -- configkey is on
         IF @c_sku is not null or @c_sku <> ''
         BEGIN
            SELECT @ll_found = COUNT(Uccno)
            FROM   UCC (NOLOCK)
            WHERE  UCCNo = @c_sku
            AND    StorerKey = @c_storerKey
      
            IF @ll_found = 0
            BEGIN
               SELECT @n_continue = 3 , @n_err = 50000
               SELECT @c_errmsg = 'The UCCNo' + @c_sku + 'Doest Not Exists in Database'
            END

            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @n_uccqty = Qty, 
                      @c_uccsku = Sku
               FROM   UCC (NOLOCK)
               WHERE  UCCNo = @c_sku
               AND    Storerkey = @c_storerkey
         
               IF NOT EXISTS(SELECT PickSlipNo FROM PACKDETAIL(NOLOCK)
                             WHERE	PickSlipNo = @c_psno AND labelno = @c_labelno )
               BEGIN
                  SELECT @n_MaxLabelLineNo = MAX(LabelLine)
                  FROM	  PackDetail (NOLOCK)
                  WHERE  PickSlipNo = @c_psno
         
                  IF @n_MaxLabelLineNo is null or @n_MaxLabelLineNo = 0
                  BEGIN
                     SELECT @c_LabelLine = '00001'
                  END
                  ELSE
                  BEGIN
                     SELECT @c_LabelLine = RIGHT('0000' + CONVERT(varchar(5), @n_MaxLabelLineNo + 1), 5)
                  END
         
                  INSERT PACKDETAIL(PickslipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty)
                  VALUES (@c_psno, @n_cartonno, @c_labelno, @c_LabelLine, @c_storerkey, @c_uccsku, @n_uccqty)
         
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 80002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into packdetail table failed. (nspRFPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END -- exists labelno
            END -- @n_continue = 1 or @n_continue = 2
      
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               EXEC isp_update_UCC_Status
               @c_sku,
               @c_uccsku,
               @c_storerkey
            END
            ELSE
 BEGIN
               SELECT @n_continue = 3
            END
         END -- if sku <> ''
      END -- configkey is on
   END 
   /* End Exceed V5.1 */

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      select @c_descr = substring(descr,1,15) 
      from  sku(nolock) 
      where sku = @c_sku 
      and   storerkey = @c_storerkey
   
		-- Start : SOS32132
		/*
      select @n_aqty = sum(orderdetail.qtyallocated) 
      from orderdetail(nolock)
      where orderkey = @c_ordno
      and sku = @c_psku   
		*/
		IF @c_consoflag = 'N' 
		BEGIN
	      select @n_aqty = sum(orderdetail.qtyallocated) 
	      from  orderdetail(nolock)
	      where orderkey = @c_orderkey
	      and   sku = @c_sku	   
		END
		ELSE
		BEGIN
	      select @n_aqty = sum(orderdetail.qtyallocated) 
	      from  orderdetail(nolock)
	      where loadkey = @c_loadkey
	      and   sku = @c_sku	   
		END
		-- End : SOS32132
      select @n_pqty = sum(qty) 
      from  packdetail(nolock)
      where pickslipno = @c_psno
      and   sku = @c_sku
   
      select @n_cqty = sum(qty) 
      from  packdetail(nolock)
      where pickslipno = @c_psno
      and   cartonno = @n_pcartonno
   END

/* Set RF Return Record */
IF @n_continue=3
BEGIN
   SELECT @c_retrec='09'
END
/* End Set RF Return Record */

/* Construct RF Return String */
SELECT @c_outstring = @c_ptcid + @c_senddelimiter
+ dbo.fnc_RTrim(@c_userid)           + @c_senddelimiter
+ dbo.fnc_RTrim(@c_taskid)           + @c_senddelimiter
+ dbo.fnc_RTrim(@c_databasename)     + @c_senddelimiter
+ dbo.fnc_RTrim(@c_appflag)          + @c_senddelimiter
+ dbo.fnc_RTrim(@c_retrec)           + @c_senddelimiter
+ dbo.fnc_RTrim(@c_server)           + @c_senddelimiter
+ dbo.fnc_RTrim(@c_descr) 	     + @c_senddelimiter
+ dbo.fnc_RTrim(convert(char(10), @n_aqty)) + @c_senddelimiter
+ dbo.fnc_RTrim(convert(char(10), @n_pqty)) + @c_senddelimiter
+ dbo.fnc_RTrim(convert(char(10), @n_cqty)) + @c_senddelimiter
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
   execute nsp_logerror @n_err, @c_errmsg, 'nspRFPK04'
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
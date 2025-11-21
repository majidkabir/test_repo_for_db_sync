SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Trigger: ntrOrderScanAdd                                              */
/* Creation Date:                                                        */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose:                                                              */
/*                                                                       */
/*                                                                       */
/* Usage:                                                                */
/*                                                                       */
/* Local Variables:                                                      */
/*                                                                       */
/* Called By: All Archive Script                                         */
/*                                                                       */
/* PVCS Version: 1.10                                                    */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/* Date         Author Ver. Purposes                                     */
/* 01-Dec-2005  Shong       Skip the process if the ArchiveCop = 9       */ 
/* 05-Mar-2009  NJOW        Add storerconfig 'DISALLOWSCANOUTPARTIALPICK'*/
/*                          to disallow partial pick auto scan out       */
/* 25-Aug-2011  Audrey  1.2 SOS#224273 - Extend storer length            */
/*                          from 5 to 15                        (ang01)  */
/*************************************************************************/
CREATE TRIGGER [ntrOrderScanAdd] 
ON [OrderScan]
FOR INSERT
AS
BEGIN -- MAIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
/******************************************************************
* FBR094 - Auto populate ORDERS
******************************************************************/
   SET CONCAT_NULL_YIELDS_NULL OFF
   -- Declaration
   DECLARE 
    @b_Success             int       -- Populated by calls to stored procedures - was the proc successful?
   ,@n_err                 int       -- Error number returned by stored procedure or this trigger
   ,@c_errmsg              NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,@n_continue      int                 
   ,@n_starttcnt     int                -- Holds the current TRANsaction count
   ,@c_OrderKey      NVARCHAR(10)
   ,@c_loadkey    NVARCHAR(10)
   ,@b_debug      int 
   ,@n_cnt int

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  , @b_debug = 0

   -- Skip the process if the ArchiveCop = 9 
   IF EXISTS(SELECT 1 FROM INSERTED WHERE ArchiveCop = '9') 
      SET  @n_continue=4

IF @n_continue=1 or @n_continue=2
BEGIN
   -- Check existing OrderKey
   IF EXISTS ( SELECT 1 
               FROM INSERTED           
               LEFT OUTER JOIN ORDERS (NOLOCK) ON INSERTED.OrderKey = ORDERS.OrderKey 
               WHERE ORDERS.OrderKey IS NULL
               AND left(inserted.OrderKey, 1) <> 'P' )   
   BEGIN
      SELECT @c_OrderKey = INSERTED.OrderKey
      FROM  INSERTED 
      LEFT OUTER JOIN ORDERS (NOLOCK) ON INSERTED.OrderKey = ORDERS.OrderKey
      WHERE ORDERS.OrderKey IS NULL

      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': OrderKey# ' + @c_OrderKey + ' not exists. (ntrOrderScanAdd)' 
   END
END

IF @n_continue=1 or @n_continue=2
BEGIN
   -- Check existing OrderKey
   IF EXISTS ( SELECT 1 FROM INSERTED 
               LEFT OUTER JOIN LOADPLAN (NOLOCK) ON INSERTED.Loadkey = LOADPLAN.Loadkey 
               WHERE LOADPLAN.Loadkey IS NULL)  
   BEGIN
      SELECT @c_loadkey = INSERTED.loadkey
      FROM  INSERTED 
         LEFT OUTER JOIN LOADPLAN (NOLOCK)
         ON INSERTED.Loadkey = LOADPLAN.Loadkey
      WHERE LOADPLAN.Loadkey IS NULL

      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Loadkey# ' + @c_loadkey + ' not exists. (ntrOrderScanAdd)' 
   END
END

IF @n_continue=1 or @n_continue=2
BEGIN

   -- Check existing OrderKey
   IF EXISTS ( SELECT 1 FROM INSERTED, LOADPLAN (NOLOCK) 
            WHERE INSERTED.Loadkey = LOADPLAN.Loadkey AND LOADPLAN.FinalizeFlag = 'Y' )
   BEGIN
      SET ROWCOUNT 1
      SELECT   @c_loadkey = INSERTED.loadkey 
      FROM INSERTED, LOADPLAN (NOLOCK) 
         WHERE INSERTED.Loadkey = LOADPLAN.Loadkey AND LOADPLAN.FinalizeFlag = 'Y'     
      SET ROWCOUNT 0

      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Loadkey# ' + @c_loadkey + ' has been finalized. (ntrOrderScanAdd)' 
   END
END


/** Refer to logic on ue_sendload in w_populate_load **/
IF @n_continue=1 or @n_continue=2
BEGIN
   IF EXISTS(SELECT 1 
             FROM LOADPLANDETAIL (NOLOCK), INSERTED
             WHERE   LOADPLANDETAIL.Loadkey = INSERTED.Loadkey
               AND   LOADPLANDETAIL.OrderKey  = '')
   BEGIN 
      DELETE LOADPLANDETAIL
      FROM  LOADPLANDETAIL, INSERTED
      WHERE LOADPLANDETAIL.Loadkey = INSERTED.Loadkey
      AND   LOADPLANDETAIL.OrderKey  = ''
   END

   DECLARE 
    @n_lineno        int
   ,@c_lineno     NVARCHAR(5)
   ,@d_ttlgrosswgt   float -- decimal - Changed by June 25.Feb.2004 SOS19510
   ,@d_ttlcube       float -- decimal - Changed by June 25.Feb.2004 SOS19510
   ,@n_ttlcasecnt    int
   ,@n_nooflines     int

   DECLARE @c_load_facility NVARCHAR(5),
            @c_pick_facility NVARCHAR(5)

   SELECT @c_loadkey = ''

   DECLARE Ins_Cur CURSOR READ_ONLY FAST_FORWARD FOR 
   SELECT I.Loadkey, I.OrderKey, L.Facility 
   FROM   INSERTED I 
   JOIN   LOADPLAN L (NOLOCK) ON L.Loadkey = I.LoadKey 
   ORDER By I.Loadkey, I.OrderKey

   OPEN Ins_Cur

   FETCH NEXT FROM Ins_Cur INTO @c_loadkey, @c_OrderKey, @c_load_facility 
   WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 or @n_continue=2)
   BEGIN -- Loadkey Loop
      IF LEFT(@c_OrderKey, 1) = 'P' 
      BEGIN
         SELECT @c_pick_facility = o.facility
         FROM PICKHEADER P (NOLOCK) 
         JOIN ORDERS O (nolock) on P.ExternOrderKey = o.POKey
         WHERE P.PICKHEADERkey = @c_OrderKey 

         IF @c_load_facility <> @c_pick_facility
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62300   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Facility Mismatch. (ntrOrderScanAdd)' 
            BREAK
         END

         EXEC @b_success = isp_Populate_Load_By_Pickslip @c_loadkey, @c_OrderKey
         IF @b_success <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62300   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': SP Execution Failed. (ntrOrderScanAdd)' 
            BREAK
         END
      END
      ELSE
      BEGIN
         SELECT @n_lineno = ISNULL(MAX(LoadLineNumber),0) FROM LOADPLANDETAIL(NOLOCK) WHERE Loadkey = @c_loadkey
         SELECT @c_lineno = dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(5), @n_lineno + 1))) --New line number
         SELECT @c_lineno = REPLICATE('0', 5 - LEN(@c_lineno)) + @c_lineno

         SELECT @d_ttlgrosswgt = SUM(ORDERDETAIL.Openqty * SKU.StdGrossWgt),
                @d_ttlcube = SUM(ORDERDETAIL.Openqty * SKU.StdCube),
                @n_ttlcasecnt = SUM( CASE WHEN  PACK.CaseCnt = 0 THEN 0
                                     ELSE (ORDERDETAIL.OpenQty / PACK.CaseCnt) 
                                     END ),
                @n_nooflines = COUNT(ORDERDETAIL.OrderKey)
         FROM  ORDERDETAIL(NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
         WHERE ORDERDETAIL.OrderKey = @c_OrderKey
         AND   ORDERDETAIL.Storerkey = SKU.Storerkey
         AND   ORDERDETAIL.SKU = SKU.SKU
         AND   SKU.Packkey = PACK.Packkey

         if @b_debug = 1
         BEGIN
            print 'start insert to loadplandetail'
            SELECT @c_loadkey '@c_loadkey', @c_OrderKey '@c_OrderKey'
         END 

         INSERT INTO LOADPLANDETAIL (
            Loadkey,    LoadLineNumber,   OrderKey,   Consigneekey,  Priority,
            OrderDate,  DeliveryDate,     Type,       Door,          Stop,
            Route,      DeliveryPlace,    Weight,     Cube,          ExternOrderKey,
            CustomerName,  NoOfOrdLines,  CaseCnt,    Status ) 
         SELECT 
            @c_loadkey, @c_lineno,        @c_OrderKey,    billtokey,    priority,
            orderdate,  deliverydate,     type,           door,         stop,
            route,      deliveryplace,    @d_ttlgrosswgt, @d_ttlcube,   ExternOrderKey,
            c_company,  @n_nooflines,     @n_ttlcasecnt,  status
         FROM  ORDERS (NOLOCK)
         WHERE OrderKey = @c_OrderKey
      
         SELECT @n_err = @@ERROR         
         IF @@error <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fail to insert LoadPlanDetail table. (ntrOrderScanAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END   

         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            UPDATE ORDERDETAIL WITH (ROWLOCK) 
               SET LoadKey = @c_LoadKey, 
                   TrafficCop = NULL 
            WHERE OrderKey = @c_OrderKey

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62303   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlanDetail. (ntrOrderScanAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END 

     
      -- Add by June 8.Aug.02
      -- Auto update ORDERS to 'PICKED' if DBYPASSCAN is enabled.

      -- Do a scan out as well
      -- Added By SHONG
      -- Date: 15-Aug-2002

         IF @n_continue=1 or @n_continue=2
         BEGIN
            DECLARE @c_PickSlipNo NVARCHAR(10),
                    @c_PickerId   NVARCHAR(15)
   
            DECLARE @c_storerkey NVARCHAR(15)--ang01
   
            SELECT @c_storerkey = Storerkey 
            FROM  ORDERS (NOLOCK)  
            WHERE OrderKey = @c_OrderKey
   
            IF EXISTS (SELECT 1 FROM StorerConfig (NOLOCK) WHERE Storerkey = @c_storerkey AND Configkey = 'DBYPASSCAN' AND sValue = '1')
            BEGIN 
            	  
               SELECT  @c_PickSlipNo = PICKHEADERKey,
                       @c_PickerID = UserId
               FROM    PICKHEADER (NOLOCK), INSERTED 
               WHERE   PICKHEADER.OrderKey = @c_OrderKey
               AND     PICKHEADER.ZONE in ('3', '8') 
               AND     INSERTED.OrderKey = PICKHEADER.OrderKey
               AND     INSERTED.LoadKey = @c_LoadKey
   
               IF dbo.fnc_RTrim(@c_PickSlipNo) IS NOT NULL AND dbo.fnc_RTrim(@c_PickSlipNo) <> ''
               BEGIN
               	  IF (SELECT COUNT(*) FROM PickingInfo (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo) = 0  --SOS#130124 NJOW 05-MAR-09
               	  BEGIN
                  	INSERT INTO PickingInfo (PickSlipNo, PickerId, ScanInDate, ScanOutDate)
                      	VALUES (@c_PickSlipNo, @c_PickerID, GetDate(), NULL)
   
	                  SELECT @n_err = @@ERROR
	                  IF @n_err <> 0 
	                  BEGIN
	                     SELECT @n_continue = 3
	                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fail to Insert Into Pickinginfo Table. (ntrOrderScanAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
	                  END   
	                END
         
                  IF @n_continue=1 or @n_continue=2
                  BEGIN
                  	 --SOS#130124 NJOW 05-MAR-09 START
                     DECLARE @c_toscanout NVARCHAR(1)
                     SELECT @c_toscanout = 'Y'
                     
										 IF (SELECT COUNT(*) FROM StorerConfig (NOLOCK) WHERE Storerkey = @c_storerkey AND Configkey = 'DISALLOWSCANOUTPARTIALPICK' AND sValue = '1') > 0
            				 BEGIN 
            				 	  IF (SELECT COUNT(*) FROM PickDetail (NOLOCK) WHERE Orderkey = @c_Orderkey AND status < '5') > 0 AND
            				 	  	 (SELECT COUNT(*) FROM PickingInfo (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND scanoutdate IS NULL) > 0
            				 	  BEGIN
            				 	      SELECT @c_toscanout = 'N'
                            SELECT @n_continue = 3
                            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62311   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	                          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Partial Scan Out Is Not Allowed. (ntrOrderScanAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            				 	  END
            				 END 
            				 
          				   --IF (SELECT COUNT(*) FROM PickingInfo (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND scanoutdate IS NOT NULL) > 0
            				 --    SELECT @c_toscanout = 'N'

            				 IF (SELECT COUNT(*) FROM PickingInfo (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo) = 0
            				     SELECT @c_toscanout = 'N'
            				 --SOS#130124 END
            				       				 
                     IF @c_toscanout = 'Y'  --SOS#130124 NJOW 05-MAR-09
                     BEGIN
	                      BEGIN TRAN
	                      UPDATE PICKINGINFO 
	                      SET    ScanOutDate = GETDATE()
	                      WHERE  Pickslipno = @c_pickslipno
	                      SELECT @n_err = @@error
	                      IF @@error <> 0 
	                      BEGIN
	                         ROLLBACK TRAN
                           SELECT @n_continue = 3
	                         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	                         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fail to Update Pickinginfo Table. (ntrOrderScanAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
	                      END   
	                      ELSE COMMIT TRAN
                     
                     -- SOS 7843 wally 6.seP.02
                     -- force a re-scan out if, for some reason, status are not updated to '5' (picked)
     -- start 7843
                  	 		declare @n_cnt_pick int,
                        		    @n_cnt_status int
                     
	            select @n_cnt_pick = count (distinct pickmethod),
		                           @n_cnt_status = count (distinct status)
		                    from pickdetail (nolock)
		                    where OrderKey = @c_OrderKey

		                    if @n_cnt_pick = 1 and @n_cnt_status > 1
		                    BEGIN
		                       BEGIN TRAN
		                        UPDATE PickingInfo
		                           SET ScanOutDate = NULL
		                        WHERE PickSlipNo = @c_PickSlipNo
		                        SELECT @n_err = @@error
		                        IF @@error <> 0 
		                        BEGIN
		                           ROLLBACK TRAN
		                           SELECT @n_continue = 3
		                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fail to Update PickingInfo Table. (ntrOrderScanAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
		                        END
		                        ELSE COMMIT TRAN
		
		                       BEGIN TRAN
		                        UPDATE PickingInfo
		                           SET ScanOutDate = GetDate()
		                        WHERE PickSlipNo = @c_PickSlipNo
		                        SELECT @n_err = @@error
		
		                        IF @@error <> 0 
		                        BEGIN
		                           ROLLBACK TRAN
		                           SELECT @n_continue = 3
		                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fail to Update PickingInfo Table. (ntrOrderScanAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
		                        END
		                        ELSE COMMIT TRAN
		                    END -- if @n_cnt_pick = 1 
		                  END -- @c_toscanout = Y
                  END -- @n_continue=1 or @n_continue=2
               END -- IF dbo.fnc_RTrim(@c_PickSlipNo) IS NOT NULL            
            END -- storerconfig (DBYPASSCAN) turn on 
         END -- continue = 1 or 2
      END -- IF LEFT(@c_OrderKey, 1) = 'P' 
      FETCH NEXT FROM Ins_Cur INTO @c_loadkey, @c_OrderKey, @c_load_facility 
   END -- Loadkey Loop
   
   CLOSE Ins_Cur -- SOS38254
   DEALLOCATE Ins_Cur -- SOS38254   
END


/* Return Statement */
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt 
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
      
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrOrderScanAdd'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
   RETURN
END
ELSE
BEGIN
   /* Error Did Not Occur , Return Normally */
   WHILE @@TRANCOUNT > @n_starttcnt 
   BEGIN
      COMMIT TRAN
   END
   RETURN
END
/* END Return Statement */


END -- MAIN









GO
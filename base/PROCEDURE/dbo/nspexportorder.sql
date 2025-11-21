SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportOrder                                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4.2                                                       */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 20-Sep-2005  June				SOS40934 - bug fixed duplicate records		*/
/* 2014-Mar-21  TLTING    1.1   SQL20112 Bug                            */
/************************************************************************/


CREATE PROC [dbo].[nspExportOrder]
AS
BEGIN -- start of procedure
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue    int      ,
            @n_starttcnt   int      , -- Holds the current transaction count
            @n_cnt         int      , -- Holds @@ROWCOUNT after certain operations
            @c_preprocess  NVARCHAR(250), -- preprocess
            @c_pstprocess  NVARCHAR(250), -- post process
            @n_err2        int      , -- For Additional Error Detection
            @b_debug       int      , -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
            @b_success     int      ,
            @n_err         int      ,
            @c_errmsg      NVARCHAR(250),
            @errorcount    int,
            @c_hikey       NVARCHAR(10)

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@n_cnt = 0,@c_errmsg="",@n_err2=0
   SELECT @b_debug = 0

   -- get the hikey,
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 0
      EXECUTE nspg_GetKey
            "hirun",
            10,
            @c_hikey OUTPUT,
            @b_success   	 OUTPUT,
            @n_err       	 OUTPUT,
            @c_errmsg    	 OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType, sourcekey)
      VALUES ( @c_hikey, ' -> nspExportOrder -- The HI Run Identifer Is ' + @c_hikey + ' started at ' + convert (char(20), getdate()), 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportOrder)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   -- Update TransmitFlag to 9 incase previous task was failed because of DeadLock
   -- Added By SHONG
   -- Date: 5th April 2001
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS( SELECT 1 FROM Transmitlog with (NOLOCK, INDEX(IX_TRANSMITLOG01))
                 JOIN ORDERS (NOLOCK) ON (Transmitlog.Key1 = ORDERS.OrderKey)
                 JOIN WMSEXPMBOL (NOLOCK) ON (WMSEXPMBOL.ExternOrderKey = ORDERS.ExternOrderKey)
                 WHERE TRANSMITLOG.Transmitflag = '0'
                 AND   Transmitlog.Tablename = 'ORDERS')
      BEGIN
         BEGIN TRAN

         UPDATE TRANSMITLOG
         SET TRANSMITLOG.Transmitflag = '9'
         FROM Transmitlog with (INDEX(IX_TRANSMITLOG01))
         JOIN ORDERS (NOLOCK) ON (Transmitlog.Key1 = ORDERS.OrderKey)
         JOIN WMSEXPMBOL (NOLOCK) ON (WMSEXPMBOL.ExternOrderKey = ORDERS.ExternOrderKey)
         WHERE TRANSMITLOG.Transmitflag = '0'
         AND   Transmitlog.Tablename = 'ORDERS'
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            ROLLBACK TRAN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update Transmitlog table (nspExportOrder)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END
      END
   END

   BEGIN TRAN
   IF @n_continue = 1 OR @n_Continue = 2
   BEGIN
      -- start exporting the records here, into a temp table so that AS/400 can pick it up via DTS
      -- check against the transmitlog table.
      INSERT INTO WMSEXPMBOL
      (ExternOrderkey,Consigneekey,ExternLineNo,SKU,OriginalQty,ShippedQty,Shortqty,TRANSFLAG,MBOLKey,
       TotalCarton, StorerKey)
      SELECT  ORDERS.ExternOrderkey,
      ORDERS.Consigneekey,
      ORDERDETAIL.ExternLineNo,
      UPPER(ORDERDETAIL.SKU),
      ORDERDETAIL.OriginalQty,
      'ShippedQty' = SUM( ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked ),
      'Shortqty' = ORDERDETAIL.OriginalQty - SUM(ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked),
      'TRANSFLAG' = '0',
      MBOL.MBolkey, 
      ISNULL(TotCarton, 0) as TotalCarton,
      ORDERS.StorerKey 
      FROM  MBOL (NOLOCK)
      INNER JOIN MBOLDETAIL (NOLOCK) ON ( MBOL.MBOLKEY = MBOLDETAIL.Mbolkey )      
      -- Start : SOS40934
      -- INNER JOIN ORDERS (NOLOCK) ON ( ORDERS.Orderkey = MBOLDETAIL.Orderkey )
      -- INNER JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.ORDERKEY )
      INNER JOIN ORDERDETAIL (NOLOCK) ON ( ORDERDETAIL.MBOLKEY = MBOLDETAIL.MBOLKEY AND ORDERDETAIL.Loadkey = MBOLDETAIL.Loadkey AND ORDERDETAIL.Orderkey = MBOLDETAIL.Orderkey )
			INNER JOIN ORDERS (NOLOCK) ON ( ORDERS.Orderkey = ORDERDETAIL.Orderkey )
			-- End : SOS40934
      INNER JOIN Transmitlog (NOLOCK) ON (TransmitLog.Tablename = 'ORDERS'
                 AND TransmitLog.TransmitFlag = '0' AND TransmitLog.Key1 = ORDERS.OrderKey)
      LEFT OUTER JOIN (SELECT MAX(CartonNo) as TotCarton, PH.ORDERKEY FROM PACKDETAIL PD (NOLOCK)
                  JOIN PACKHEADER PH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo 
                  JOIN ORDERS O (NOLOCK) ON PH.OrderKey = O.OrderKey 
                  JOIN Transmitlog (NOLOCK) ON (TransmitLog.Tablename = 'ORDERS'
                       AND TransmitLog.TransmitFlag = '0' AND TransmitLog.Key1 = O.OrderKey)
                  GROUP BY PH.ORDERKEY ) as PackCarton
               ON (PackCarton.OrderKey = ORDERS.OrderKey) 
      GROUP BY ORDERS.ExternOrderkey,
               ORDERS.Consigneekey,
               ORDERDETAIL.ExternLineNo,
               ORDERDETAIL.SKU,
               ORDERDETAIL.OriginalQty,
               MBOL.MBolkey, 
               TotCarton,
               ORDERS.StorerKey 
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN 
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to create WMSEXPMBOL (nspExportOrder)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   -- Added By Shong
   -- Stop here if nothing to process
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF NOT EXISTS( SELECT ExternOrderKey FROM WMSEXPMBOL (NOLOCK) WHERE  TransFlag = '0' )
      BEGIN
         SELECT @n_continue = 4
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to create WMSEXPMBOL (nspExportOrder)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   -- Update Shipped Qty Again Incase dirty read when order detail update not yet complete
   -- To solve a problem that Shipped Qty = 0 when transfer, in fact the shipped qty in order detail is > 0
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_ExternOrderKey NVARCHAR(30),
              @c_ExternLineNo   NVARCHAR(15),
              @n_ShippedQty     int

      IF EXISTS( SELECT ExternOrderKey
                  FROM   WMSEXPMBOL (NOLOCK)
                  WHERE  TransFlag = '0'
                  GROUP  By ExternOrderKey
                  HAVING SUM(Originalqty) > SUM(ShippedQty))
      BEGIN
         SELECT ExternOrderKey
         INTO   #ExtOrd
         FROM   WMSEXPMBOL (NOLOCK)
         WHERE  TransFlag = '0'
         GROUP  By ExternOrderKey
         HAVING SUM(Originalqty) > SUM(ShippedQty)
         SELECT @c_ExternOrderKey = SPACE(10)
         WHILE 1=1
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_ExternOrderKey = ExternOrderKey
            FROM   #ExtOrd
            WHERE  ExternOrderKey > @c_ExternOrderKey

            IF @@ROWCOUNT = 0
               BREAK

            SET ROWCOUNT 0
            DECLARE ORD_CUR CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT  ORDERDETAIL.ExternOrderKey,
                    ORDERDETAIL.ExternLineNo,
                    SUM(PickDetail.Qty)
            FROM  ORDERDETAIL (NOLOCK), PICKDETAIL (NOLOCK)
            WHERE ORDERDETAIL.ExternOrderKey = @c_ExternOrderKey
            AND   ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey
            AND   ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber
            GROUP BY ORDERDETAIL.ExternOrderKey, ORDERDETAIL.ExternLineNo

            OPEN ORD_CUR
            FETCH NEXT FROM ORD_CUR
            INTO @c_ExternOrderKey, @c_ExternLineNo, @n_ShippedQty
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE WMSEXPMBOL
               SET ShippedQty = @n_ShippedQty,
                   ShortQty = OriginalQty - @n_ShippedQty
               WHERE  ExternOrderKey = @c_ExternOrderKey
               AND    ExternLineNo = @c_ExternLineNo
               AND    TRANSFLAG = '0'
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update WMSEXPMBOL (nspExportOrder)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  BREAK
               END
               FETCH NEXT FROM ORD_CUR
               INTO @c_ExternOrderKey, @c_ExternLineNo, @n_ShippedQty
            END
            CLOSE ORD_CUR
            DEALLOCATE ORD_CUR
         END
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE TRANSMITLOG
      SET TRANSMITLOG.Transmitflag = '9'
      FROM Transmitlog with (INDEX(IX_TRANSMITLOG01))
      JOIN ORDERS (NOLOCK) ON (Transmitlog.Key1 = ORDERS.OrderKey)
      JOIN WMSEXPMBOL (NOLOCK) ON (WMSEXPMBOL.ExternOrderKey = ORDERS.ExternOrderKey)
      WHERE TRANSMITLOG.Transmitflag = '0'
      AND   Transmitlog.Tablename = 'ORDERS'
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update Transmitlog table (nspExportOrder)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportOrder -- Export Process For ' + @c_hikey + ' ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportOrder)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue = 3
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportOrder ERROR -- Export Process for ' + @c_hikey + ' Ended at ' + convert (char(20), getdate()) , 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportOrder)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
      execute nsp_logerror @n_err, @c_errmsg, "nspExportOrder"
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
END -- End of Procedure

GO
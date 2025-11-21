SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportAllocatedOrd                              */
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
/* Date         Author   Ver.     Purposes                              */
/* 23-Mar-2021  WLChooi  1.1      Comment out code due to GDSITF DB name*/
/*                                and ExpOrdAlloc table are not exists  */
/*                                in Production (WL01)                  */
/************************************************************************/

CREATE PROC [dbo].[nspExportAllocatedOrd]
AS
BEGIN -- main proc
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt   int       , -- Holds the current transaction count
   @n_cnt         int       , -- Holds @@ROWCOUNT after certain operations
   @c_preprocess  NVARCHAR(250) , -- preprocess
   @c_pstprocess  NVARCHAR(250) , -- post process
   @n_err2 			int       , -- For Additional Error Detection
   @b_debug 		int       ,  -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
   @b_success 		int       ,
   @n_err   		int       ,
   @c_errmsg 	 NVARCHAR(250),
   @errorcount 	int,
   @c_BatchNo 	 NVARCHAR(10)

   --WL01 S
   --GDSITF db name and ExpOrdAlloc table are not exists in production. 
   --According to IML team, transmitlog table is no longer used. This stored proc might not valid anymore. 
   -- get the BatchNo
   --IF @n_continue = 1 OR @n_continue = 2
   --BEGIN
   --   SELECT @b_success = 0
   --   EXECUTE nspg_GetKey
   --   'ORDALLOC',
   --   10,
   --   @c_BatchNo 		 OUTPUT,
   --   @b_success   	 OUTPUT,
   --   @n_err       	 OUTPUT,
   --   @c_errmsg    	 OUTPUT
   --   IF NOT @b_success = 1
   --   BEGIN
   --      SELECT @n_continue = 3
   --   END
   --END

   --IF @n_continue = 1 OR @n_continue = 2
   --BEGIN
   --   INSERT INTO GDSITF..ExpOrdAlloc(
   --   BatchNo,
   --   LoadKey,
   --   ExternOrderKey,
   --   ExternOrderLine,
   --   SKU,
   --   WHCode,
   --   QtyOrdered,
   --   QtyAllocated,
   --   UOM)
   --   SELECT DISTINCT CAST( @c_BatchNo AS Int),
   --   ORDERS.LoadKey,
   --   ORDERS.ExternOrderkey,
   --   ORDERDETAIL.ExternLineNo,
   --   UPPER(ORDERDETAIL.SKU),
   --   ORDERS.Facility,
   --   ORDERDETAIL.OriginalQty,
   --   ORDERDETAIL.QtyAllocated,
   --   PACK.PACKUOM3
   --   FROM  ORDERDETAIL(nolock),
   --   ORDERS (nolock),
   --   Transmitlog (nolock),
   --   PACK (NOLOCK)
   --   WHERE    ORDERS.Orderkey = ORDERDETAIL.Orderkey
   --   AND      Transmitlog.Tablename = 'ORDALLOC'
   --   AND      ORDERDETAIL.ExternOrderkey = Transmitlog.Key1
   --   AND      ORDERDETAIL.ExternLineNo = Transmitlog.Key2
   --   AND      Transmitlog.TransmitFlag = '0'
   --   IF @@ERROR <> 0
   --   BEGIN
   --      SELECT @n_continue = 3
   --      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   --      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to create ExpOrdAlloc (nspExportAllocatedOrd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   --   END
   --END

   --IF @n_continue = 1 OR @n_continue = 2
   --BEGIN
   --   UPDATE Transmitlog
   --   SET  Transmitlog.Transmitflag = '9'
   --   FROM Transmitlog, GDSITF..ExpOrdAlloc
   --   WHERE Transmitlog.Key1 = GDSITF..ExpOrdAlloc.ExternOrderKey
   --   AND Transmitlog.Key2 = GDSITF..ExpOrdAlloc.ExternOrderLine
   --   AND Transmitlog.Tablename = 'ORDALLOC'
   --   AND Transmitlog.Transmitflag = '0'
   --   SELECT @n_err = @@ERROR
   --   IF @n_err <> 0
   --   BEGIN
   --      SELECT @n_continue = 3
   --      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   --      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update Transmitlog table (nspExportOrder)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   --   END

   --END
   --WL01 E

END -- main proc

GO
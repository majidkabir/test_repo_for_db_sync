SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspXDockPickList                                   */
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
/* Date         Author        Purposes                                  */
/************************************************************************/

/****** Object:  Stored Procedure dbo.nspXDockPickList    Script Date: 3/11/99 6:24:26 PM ******/
CREATE PROC [dbo].[nspXDockPickList](
@a_s_LoadKey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @c_firsttime NVARCHAR(1),
   @c_PrintedFlag  NVARCHAR(1),
   @n_err          int,
   @n_continue     int,
   @n_cnt          int,
   @c_PickHeaderKey NVARCHAR(10),
   @b_success       int,
   @c_errmsg        NVARCHAR(255),
   @n_starttcnt       int,
   @n_intcnt        int
   /* Start Modification */
   SET NOCOUNT ON
   DECLARE @c_route NVARCHAR(10)
   SELECT @n_continue=1, @n_intcnt = 0, @n_starttcnt=@@TRANCOUNT
   SELECT Orders.OrderKey,
   Orders.POKey,
   Orders.ConsigneeKey,
   Orders.C_Company,
   OrderDetail.Storerkey,
   OrderDetail.SKU,
   OrderDetail.UOM,
   OrderDetail.QtyAllocated,
   OrderDetail.Lottable03,
   OrderDetail.Lottable04,
   PickDetail.Loc,
   PickDetail.ToLoc,
   PickDetail.ID
   INTO   #XdockPickDetail
   FROM   PickDetail, OrderDetail, Orders, LoadPlanDetail
   WHERE  PickDetail.OrderKey = OrderDetail.OrderKey
   AND    OrderDetail.OrderKey = Orders.OrderKey
   AND    Orders.OrderKey = LoadPlanDetail.OrderKey
   AND    LoadPlanDetail.LoadKey = @a_s_LoadKey
   AND    Orders.XDockFlag = '1'
   AND    PickDetail.Status < '5'
   SELECT @n_cnt = @@ROWCOUNT
   IF @n_cnt = 0
   SELECT @n_continue = 4
ELSE
   SELECT @n_intcnt = @n_cnt
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_route = ROUTE
      FROM LoadPlan
      WHERE loadkey = @a_s_LoadKey
      IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK)
      WHERE ExternOrderKey = @a_s_LoadKey
      AND   Zone = "6")
      BEGIN
         SELECT @c_firsttime = 'N'
         SELECT @c_PrintedFlag = 'Y'
      END
   ELSE
      BEGIN
         SELECT @c_firsttime = 'Y'
         SELECT @c_PrintedFlag = "N"
      END -- Record Not Exists
      SET NOCOUNT ON
      -- Uses PickType as a Printed Flag
      UPDATE PickHeader
      SET PickType = '1',
      TrafficCop = NULL
      WHERE ExternOrderKey = @a_s_LoadKey
      AND Zone = "6"
      AND PickType = '0'
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_firsttime = "Y"
      BEGIN
         EXECUTE nspg_GetKey
         "PICKSLIP",
         9,
         @c_pickheaderkey     OUTPUT,
         @b_success   	 OUTPUT,
         @n_err       	 OUTPUT,
         @c_errmsg    	 OUTPUT
         IF @b_success = 0
         SELECT @n_continue = 3
      ELSE
         BEGIN
            SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey
            INSERT INTO PICKHEADER
            (PickHeaderKey,  ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES
            (@c_pickheaderkey, @a_s_LoadKey,     "0",      "6",  "")
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            SELECT @n_continue = 3
         END
      END
   ELSE
      BEGIN
         SELECT @c_pickheaderkey = PickHeaderKey FROM PickHeader (NOLOCK)
         WHERE ExternOrderKey = @a_s_LoadKey
         AND   Zone = "6"
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PickDetail
      SET PickSlipNo = @c_pickheaderkey,
      Trafficcop = NULL
      FROM   PickDetail , ORDERS, LoadPlanDetail, PickHeader
      WHERE  PickDetail.OrderKey = Orders.OrderKey
      AND    Orders.OrderKey = LoadPlanDetail.OrderKey
      AND    LoadPlanDetail.LoadKey = PickHeader.ExternOrderKey
      AND    Orders.XDockFlag = '1'
      AND    PickDetail.Status < '5'
      AND    ( PickDetail.PickSlipNo is NULL OR PICKDETAIL.Pickslipno = '' )
      AND    PickHeader.PickHeaderKey = @c_pickheaderkey
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      SELECT @n_continue = 3
   END
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
   END
ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END
   IF @n_intcnt >=1 AND (@n_continue = 3 OR @n_continue = 4)
   DELETE FROM #XdockPickDetail
   SELECT @a_s_LoadKey,
   Receipt.ReceiptKey,
   @c_route,
   @c_pickheaderkey ,
   Receipt.ReceiptDate,
   #XdockPickDetail.Loc,
   #XdockPickDetail.SKU,
   SKU.Descr,
   #XdockPickDetail.Toloc,
   #XdockPickDetail.POKey,
   #XdockPickDetail.OrderKey,
   #XdockPickDetail.ConsigneeKey,
   #XdockPickDetail.C_Company,
   #XdockPickDetail.Lottable03,
   #XdockPickDetail.Lottable04,
   #XdockPickDetail.ID,
   #XdockPickDetail.UOM,
   #XdockPickDetail.QtyAllocated
   FROM #XdockPickDetail, ReceiptDetail, Receipt, SKU
   WHERE SKU.StorerKey = #XdockPickDetail.StorerKey
   AND   SKU.SKU = #XdockPickDetail.SKU
   AND   Receipt.ReceiptKey = ReceiptDetail.ReceiptKey
   AND   ReceiptDetail.StorerKey = #XdockPickDetail.StorerKey
   AND   ReceiptDetail.SKU = #XdockPickDetail.SKU
   AND   ReceiptDetail.POKey = #XdockPickDetail.POKey
   SET NOCOUNT OFF
END /* main procedure */

GO
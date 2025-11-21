SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GetPickSlipOrders101_rpt                        */
/* Creation Date: 03-Dec-2019                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-11250 - 【CN】GYM_Picklist by load_CR                     */
/*                                                                      */
/* Input Parameters: @as_LoadKey - (LoadKey)                            */
/*                                                                      */
/* Called By: r_dw_print_pickorder103_rpt                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author Ver.  Purposes                                   */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders103_rpt] (@c_LoadKey NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE
      @n_starttrancnt  int, 
      @n_continue      int,
      @b_success       int,
      @n_err           int,
      @c_errmsg        NVARCHAR(255)

   DECLARE 
      @c_PrintedFlag   NVARCHAR(1),
      @c_PickHeaderKey NVARCHAR(10)

   SELECT @n_starttrancnt = @@TRANCOUNT, @n_continue = 1

   /********************************/
   /* Use Zone as a UOM Picked     */
   /* 1 = Pallet                   */
   /* 2 = Case                     */
   /* 6 = Each                     */
   /* 7 = Consolidated pick list   */
   /* 8 = By Order                 */
   /********************************/

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT DISTINCT
            LoadPlan.LoadKey,   
            LoadPlan.Facility,
            ISNULL(LoadPlan.Route,'') as route,
            LoadPlan.AddDate,   
            PickDetail.LOC,   
            PickDetail.SKU,     
            SKU.DESCR,   
            ( SELECT SUM(OriginalQty)
              FROM OrderDetail (NOLOCK)
              WHERE OrderDetail.Loadkey = LoadPlanDETAIL.LoadKey AND SKU =PickDetail.sku) AS TotalQtyOrder, 
            ( SELECT SUM(QtyAllocated)
              FROM OrderDetail (NOLOCK)
              WHERE OrderDetail.Loadkey = LoadPlanDETAIL.LoadKey AND SKU =PickDetail.sku) AS TotalQtyAlloc,
            PACK.Casecnt,
            FLOOR(( SELECT SUM(OriginalQty)
                    FROM OrderDetail (NOLOCK)
                    WHERE OrderDetail.Loadkey = LoadPlanDETAIL.LoadKey AND SKU =PickDetail.sku)/PACK.Casecnt) as TTLCTNS
      FROM LoadPlan (NOLOCK) 
      JOIN LoadPlanDetail (NOLOCK) ON (LoadPlan.LoadKey = LoadPlanDetail.LoadKey)
      JOIN Orders (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
      JOIN OrderDetail (NOLOCK) ON (Orders.OrderKey = OrderDetail.OrderKey AND OrderDetail.LoadKey = LoadPlanDetail.LoadKey) 
      JOIN PickDetail (NOLOCK) ON (Orders.OrderKey = PickDetail.OrderKey AND OrderDetail.OrderLineNumber = PickDetail.OrderLineNumber)
      JOIN SKU (NOLOCK) ON (SKU.StorerKey = PickDetail.Storerkey) AND (SKU.SKU = PickDetail.SKU)
      JOIN PACK (NOLOCK) ON (PACK.PackKey = SKU.PackKey)    
      WHERE LoadPlan.loadkey = @c_loadkey
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipOrders103_rpt'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END /* main procedure */

GO
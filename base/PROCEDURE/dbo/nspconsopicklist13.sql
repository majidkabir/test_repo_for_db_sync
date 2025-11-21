SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nspConsoPickList13                                  */
/* Creation Date: 11-Sep-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: IDSCN C&A Consolidated PickSlip (print from LoadPlan)       */
/*                                                                      */
/* Input Parameters: @as_LoadKey - (LoadKey)                            */
/*                                                                      */
/* Called By: r_dw_consolidated_pick13_2                                */
/*                                                                      */
/* PVCS Version: 1.0 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 05-Sept-2008 HFLiew  1.1   Added the SKU.Measurement for SOS 115481  */
/*                            (HaurFuh01)                               */     
/* 16-Sept-2009 NJOW01  1.2   SOS#147132 Sort by logical location       */
/* 02-Oct-2013  YTWan   1.2   SOS#290393 - Add Orders.Consigneekey      */
/*                            (Wan01)                                   */
/* 16-MAR-2016  CSCHONG 1.3   SOS#365850 (CS01)                         */
/* 12-Apr-2016  SHONG   1.4   SOS#368128 (SHONG01)                      */
/* 31-MAR-2017  CSCHONG 1.5   WMS-1498 - Add new field (CS02)           */
/* 14-APR-2017  CSCHONG 1.6   WMS-1498 - Revise Altsku field (CS03)     */
/* 28-JUN-2017  CSCHONG 1.7   WMS-2143 - Add new field (CS04)           */
/* 14-DEC-2017  CSCHONG 1.8   WMS-3606 - remove group by LOT02(CS05)    */
/* 15-Dec-2018  TLTING01 1.9   Missing nolock                           */
/* 12-NOV-2020  CSCHONG  2.0  Performance tunning (CS06)                */
/************************************************************************/

CREATE PROC [dbo].[nspConsoPickList13] (@as_LoadKey NVARCHAR(10) )
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

   SELECT @c_PickHeaderKey = SPACE(10)

   IF NOT EXISTS (SELECT PickHeaderKey FROM PICKHEADER (NOLOCK) WHERE ExternOrderKey = @as_LoadKey AND Zone = '7') 
   BEGIN
      SELECT @c_PrintedFlag = 'N'
      
      SELECT @b_success = 0

      EXECUTE nspg_GetKey
         'PICKSLIP',
         9,   
         @c_PickHeaderKey  OUTPUT,
         @b_success        OUTPUT,
         @n_err            OUTPUT,
         @c_errmsg         OUTPUT

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

         INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone)
         VALUES (@c_PickHeaderKey, @as_LoadKey, '1', '7')
          
         SELECT @n_err = @@ERROR
   
         IF @n_err <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63501
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (nspConsoPickList13)'
         END
      END -- @n_continue = 1 or @n_continue = 2
   END
   ELSE
   BEGIN
      SELECT @c_PrintedFlag = 'Y'

      SELECT @c_PickHeaderKey = PickHeaderKey
      FROM  PICKHEADER (NOLOCK)  
      WHERE ExternOrderKey = @as_LoadKey 
       AND  Zone = '7'
   END
  
   IF dbo.fnc_RTrim(@c_PickHeaderKey) IS NULL OR dbo.fnc_RTrim(@c_PickHeaderKey) = ''
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63502
      SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Get LoadKey Failed. (nspConsoPickList13)'
   END

   -- (SHONG01) Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      BEGIN TRY
         EXEC isp_Gen_CNA_SUP
            @cLoadkey = @as_LoadKey          
      END TRY
      BEGIN CATCH
         SELECT @n_continue = 3
         SELECT @n_err = 63502
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Execute isp_Gen_CNA_SUP Failed. (nspConsoPickList13)'
      END CATCH
   END
   -- (SHONG01) End
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT
         LoadPlan.LoadKey,   
         LoadPlan.Facility,
         ISNULL(LoadPlan.Route,'') AS [Route],
         LoadPlan.AddDate, 
         PickHeader.PickHeaderKey,  
         PickDetail.LOC,   
         PickDetail.SKU,   
         SUM(PickDetail.Qty) AS qty,   
         SKU.DESCR,   
         --CS06 START
         --( SELECT SUM(OpenQty)
         --  FROM OrderDetail (NOLOCK)
         --  WHERE OrderDetail.Loadkey = LoadPlanDETAIL.LoadKey ) AS TotalQtyOrdered, 
         --( SELECT SUM(QtyAllocated+QtyPicked+ShippedQty)
         --  FROM OrderDetail (NOLOCK)
         --  WHERE OrderDetail.Loadkey = LoadPlanDETAIL.LoadKey ) AS TotalQtyAllocated, 
         ( SELECT SUM(OrderDetail.OpenQty)
           FROM OrderDetail (NOLOCK)
           JOIN Loadplandetail A (NOLOCK) ON A.orderkey = OrderDetail.orderkey
           WHERE A.Loadkey = LoadPlanDETAIL.LoadKey ) AS TotalQtyOrdered, 
         ( SELECT SUM(OrderDetail.QtyAllocated+QtyPicked+OrderDetail.ShippedQty)
           FROM OrderDetail (NOLOCK)
           JOIN Loadplandetail A (NOLOCK) ON A.orderkey = OrderDetail.orderkey
           WHERE A.Loadkey = LoadPlanDETAIL.LoadKey ) AS TotalQtyAllocated, 
         --CS06 END  
         PACK.PackUOM3 As UOM,
         '' AS Lottable02,--OrderDetail.Lottable02,          --(CS05)
         '' AS Lottable03,--LOTATTRIBUTE.Lottable03,         --(CS05) 
         ISNULL(SKU.Measurement,'') AS Measurement, --(HaurFuh01)  
         LOC.LogicalLocation --NJOW01
      ,  ORDERS.Consigneekey        --(Wan01)
      ,  RIGHT(RTRIM(SKU.ALTSKU),4) AS Altsku     --(CS02)   --(CS03)
      ,  ORDERS.C_Company  AS CCompany                       --(CS04)
      FROM LoadPlan (NOLOCK) 
      INNER JOIN LoadPlanDetail (NOLOCK) ON (LoadPlan.LoadKey = LoadPlanDetail.LoadKey)
      INNER JOIN Orders (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
      INNER JOIN OrderDetail (NOLOCK) ON (Orders.OrderKey = OrderDetail.OrderKey AND OrderDetail.LoadKey = LoadPlanDetail.LoadKey) 
      INNER JOIN PickDetail (NOLOCK) ON (Orders.OrderKey = PickDetail.OrderKey AND OrderDetail.OrderLineNumber = PickDetail.OrderLineNumber)
      INNER JOIN SKU (NOLOCK) ON (SKU.StorerKey = PickDetail.Storerkey) AND (SKU.SKU = PickDetail.SKU)
      INNER JOIN PACK (NOLOCK) ON (PACK.PackKey = SKU.PackKey)    
      INNER JOIN PickHeader (NOLOCK) ON (PickHeader.ExternOrderKey = LoadPlan.LoadKey)  --tlting01
      INNER JOIN LOT (NOLOCK) ON (PickDetail.LOT = LOT.LOT)
      INNER JOIN LOTATTRIBUTE (NOLOCK) ON (LOTATTRIBUTE.LOT = LOT.LOT)
      INNER JOIN LOC (NOLOCK) ON (Pickdetail.Loc = LOC.Loc)  --NJOW01
      WHERE PickHeader.PickHeaderKey = @c_PickHeaderKey 
      GROUP BY  LoadPlan.LoadKey,   
         LoadPlan.Facility,
         LoadPlan.Route,
         LoadPlan.AddDate, 
         PickHeader.PickHeaderKey,  
         PickDetail.LOC,   
         PickDetail.SKU,   
       --  PickDetail.Qty,   
         SKU.DESCR,  
          PACK.PackUOM3,
        -- OrderDetail.Lottable02,                      --(CS05)
        -- LOTATTRIBUTE.Lottable03,                     --(CS05)
         SKU.Measurement, --(HaurFuh01)  
         LOC.LogicalLocation --NJOW01
      ,  ORDERS.Consigneekey  
      ,LoadPlanDETAIL.LoadKey 
      ,RIGHT(RTRIM(SKU.ALTSKU),4)                         --(CS02) --(Cs03)
      ,ORDERS.C_Company                                   --(CS04)
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList13'
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
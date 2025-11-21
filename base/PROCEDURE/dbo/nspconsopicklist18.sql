SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: nspConsoPickList18                                  */
/* Creation Date: 11-Sep-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: ACM                                                      */
/*                                                                      */
/* Purpose: IDSCN Converse PickSlip (print from LoadPlan)               */
/*                                                                      */
/* Input Parameters: @as_LoadKey - (LoadKey)                            */
/*                                                                      */
/* Output Parameters: Report                                            */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: r_dw_consolidated_pick18                                  */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 0                                                           */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-Aug-2011  YTWan     1.1   SOS#222532-Change to Discrete Pickslip  */
/*                              by order. (Wan01)                       */
/* 13-Apr-2012  NJOW01    1.2   241188-Make report title configurable   */
/* 12-Jul-2013  TLTING    1.3   Perfromance Tune - Reduce blocking      */
/* 09-Nov-2015  SHONG01   1.4   Performance Tuning                      */
/* 16-Nov-2015  Leong     1.5   SOS# 356792 - Include missing column.   */
/* 10-May-2016	 CSCHONG   1.6   SOS# 369615 - add report config (CS01)  */
/* 05-Oct-2016  CSCHONG   1.7   WMS-393 - Add new field (CS02)          */
/* 11-Aug-2020  WLChooi   1.8   WMS-14653 - Modify layout for KR (WL01) */
/************************************************************************/

CREATE PROC [dbo].[nspConsoPickList18] (@as_LoadKey NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
         @n_starttrancnt   int,
         @n_continue       int,
         @b_success        int,
         @n_err            int,
         @c_errmsg         NVARCHAR(255)

   DECLARE
         @c_PrintedFlag    NVARCHAR(1),
         @c_PickHeaderKey  NVARCHAR(10),
         @c_Orderkey       NVARCHAR(10)                                                             --(Wan01)

   SET @c_Orderkey = ''                                                                            --(Wan01)

   SELECT @n_starttrancnt = @@TRANCOUNT, @n_continue = 1

   /********************************/
   /* Use Zone as a UOM Picked     */
   /* 1 = Pallet                   */
   /* 2 = Case                     */
   /* 6 = Each                     */
   /* 7 = Consolidated pick list   */
   /* 8 = By Order                 */
   /********************************/

   IF @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SET @c_PickHeaderKey = SPACE(10)

   --(Wan01) - START

   DECLARE CURSOR_SO CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ISNULL(RTRIM(LPD.OrderKey),'')
     FROM LoadPlan LP WITH (NOLOCK)
     JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = LP.Loadkey)
    WHERE  LP.Loadkey = @as_LoadKey
   ORDER BY ISNULL(RTRIM(LPD.OrderKey),'')

   OPEN CURSOR_SO

   FETCH NEXT FROM CURSOR_SO INTO @c_Orderkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
   --IF NOT EXISTS (SELECT PickHeaderKey FROM PICKHEADER WITH (NOLOCK) WHERE ExternOrderKey = @as_LoadKey AND Zone = '7')
      IF NOT EXISTS (SELECT PickHeaderKey FROM PICKHEADER WITH (NOLOCK) WHERE ExternOrderKey = @as_LoadKey
                     AND Orderkey = @c_Orderkey AND Zone = '3')
      --(Wan01) - END
      BEGIN
         --SET @c_PrintedFlag = 'N'                                                                --(Wan01)

         SET @b_success = 0
         BEGIN TRAN

         EXECUTE nspg_GetKey
            'PICKSLIP',
            9,
            @c_PickHeaderKey  OUTPUT,
            @b_success        OUTPUT,
            @n_err            OUTPUT,
            @c_errmsg         OUTPUT

         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3
         END

         IF @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SET @c_PickHeaderKey = 'P' + @c_PickHeaderKey
            BEGIN TRAN

            --(Wan01) - START
            --INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone)
            --VALUES (@c_PickHeaderKey, @as_LoadKey, '1', '7')
            INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, Orderkey, Zone)
            VALUES (@c_PickHeaderKey, @as_LoadKey, @c_Orderkey, '3')
            --(Wan01) - END

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 63501
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (nspConsoPickList18)'
            END

            IF @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END -- @n_continue = 1 or @n_continue = 2
      END
      ELSE
      BEGIN
         --SET @c_PrintedFlag = 'Y'                                                                --(Wan01)

         SELECT @c_PickHeaderKey = PickHeaderKey
         FROM  PICKHEADER WITH (NOLOCK)
         WHERE ExternOrderKey = @as_LoadKey
         --(Wan01) - START
         -- AND  Zone = '7'
           AND Orderkey = @c_Orderkey
           AND Zone = '3'
         --(Wan01) - END
      END
   --(Wan01) - START
      FETCH NEXT FROM CURSOR_SO INTO @c_Orderkey
   END
   CLOSE CURSOR_SO
   DEALLOCATE CURSOR_SO

   --IF ISNULL(RTRIM(@c_PickHeaderKey),'') = ''
   --BEGIN
   -- SET @n_continue = 3
   -- SET @n_err = 63502
   -- SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Get LoadKey Failed. (nspConsoPickList18)'
   --END
   --(Wan01) - END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- SHONG01
      DECLARE @n_TotalQtyOrdered   INT,
              @n_TotalQtyAllocated INT

      SET @n_TotalQtyOrdered = 0
      SET @n_TotalQtyAllocated = 0

      SELECT @n_TotalQtyOrdered= SUM(OpenQty),
             @n_TotalQtyAllocated = SUM(QtyAllocated+QtyPicked+ShippedQty)
      FROM ORDERDETAIL WITH (NOLOCK)
      JOIN LOADPLANDETAIL lpd (NOLOCK) ON lpd.OrderKey = ORDERDETAIL.OrderKey
      WHERE lpd.LoadKey = @as_LoadKey
      GROUP BY lpd.LoadKey


      SELECT DISTINCT                                                                              --(Wan01)
         LoadPlan.LoadKey,
         LoadPlan.Facility,
         LoadPlan.Route,
         LoadPlan.AddDate,
         PickHeader.PickHeaderKey,
         PickHeader.Orderkey, -- SOS# 356792
         @n_TotalQtyOrdered AS TotalQtyOrdered,
--         ( SELECT SUM(OpenQty)
--           FROM OrderDetail WITH (NOLOCK)
--           WHERE OrderDetail.Loadkey = LoadPlanDETAIL.LoadKey ) AS TotalQtyOrdered,
         @n_TotalQtyAllocated AS TotalQtyAllocated,
--         ( SELECT SUM(QtyAllocated+QtyPicked+ShippedQty)
--           FROM OrderDetail WITH (NOLOCK)
--           WHERE OrderDetail.Loadkey = LoadPlanDETAIL.LoadKey ) AS TotalQtyAllocated,
         Loc.PutawayZone,
         --(Wan01) - END
         ISNULL(Storer.ConsigneeFor,'') AS ConsigneeFor, --NJOW01
         CASE WHEN ISNULL(C.Code,'') <> '' THEN 'Y' ELSE 'N' END AS 'ShowSubReport',
         S1.SUSR2,                                                                   --(CS02)
         ISNULL(CL.Short,'N') AS ShowCols,   --WL01
         SUBSTRING(ISNULL(ORD.Notes,''),1,255) AS Notes   --WL01
      FROM LoadPlan WITH (NOLOCK)
      INNER JOIN LoadPlanDetail WITH (NOLOCK) ON (LoadPlan.LoadKey = LoadPlanDetail.LoadKey)
     --(Wan01) - START
      INNER JOIN PickHeader WITH (NOLOCK) ON (PickHeader.ExternOrderKey = LoadPlan.LoadKey)
                                          AND(PickHeader.Orderkey = LoadPlanDetail.Orderkey)
      INNER JOIN PickDetail WITH (NOLOCK) ON (PickDetail.OrderKey = PickHeader.OrderKey)
      INNER JOIN Loc        WITH (NOLOCK) ON (Loc.Loc             = PickDetail.Loc)
      INNER JOIN Storer     WITH (NOLOCK) ON (PickDetail.Storerkey = Storer.Storerkey)  --NJOW01
      LEFT JOIN CODELKUP C WITH (nolock) ON C.storerkey= PickDetail.Storerkey               
                                        AND listname = 'REPORTCFG' and code ='ShowSubReport'                            
                                        AND long='r_dw_consolidated_pick18'  
      JOIN Orders ORD WITH (NOLOCK) ON ord.OrderKey=pickheader.OrderKey                  -- (CS02)
      JOIN Storer S1 WITH (NOLOCK) ON S1.StorerKey=ord.ConsigneeKey                      ---  (CS02)     
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.Listname = 'REPORTCFG' AND CL.Code = 'ShowCols'   --WL01
                                         AND CL.Storerkey = PickDetail.Storerkey   --WL01
                                         AND CL.Long = 'r_dw_consolidated_pick18'  --WL01
      WHERE LoadPlan.LoadKey = @as_LoadKey
      --(Wan01) - END
   END

   IF  @@TRANCOUNT < @n_starttrancnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList18'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END /* main procedure */

GO
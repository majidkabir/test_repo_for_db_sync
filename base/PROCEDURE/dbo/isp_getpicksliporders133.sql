SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_GetPickSlipOrders133                           */
/* Creation Date: 08-SEP-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-20625 [CN] - YONEX_PrintPickSlips_PLISTN_NEW            */
/*                                                                      */
/* Called By: r_dw_print_pickorder133                                   */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 08-SEP-2022  CSCHONG  1.0  Devops Scripts Combine                    */
/* 04-Nov-2022  WLChooi  1.1  WMS-21139 - Change sorting (WL01)         */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders133]
(@c_LoadKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_err           INT
         , @n_continue      INT
         , @c_PickHeaderKey NVARCHAR(10)
         , @b_success       INT
         , @c_errmsg        NVARCHAR(255)
         , @n_StartTCnt     INT
         , @c_GetLoadkey    NVARCHAR(10)
         , @c_GetOrderkey   NVARCHAR(10)
         , @c_storerkey     NVARCHAR(10)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_continue = 1

   --WL01 S
   SELECT TOP 1 @c_storerkey = OH.StorerKey
   FROM LoadPlanDetail LPD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_LoadKey
   --WL01 E

   CREATE TABLE #TMP_LoadOrd
   (
      RowID    INT NOT NULL IDENTITY(1, 1)
    , Loadkey  NVARCHAR(10)
    , Orderkey NVARCHAR(10)
   )

   --WL01 S
   INSERT INTO #TMP_LoadOrd
   SELECT DISTINCT LoadPlanDetail.LoadKey
                 , LoadPlanDetail.OrderKey
   FROM LoadPlanDetail (NOLOCK)
   JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = LoadPlanDetail.OrderKey
   WHERE LoadPlanDetail.LoadKey = @c_LoadKey AND ORDERS.StorerKey = @c_storerkey
   ORDER BY LoadPlanDetail.LoadKey
          , LoadPlanDetail.OrderKey
   --WL01 E

   CREATE TABLE #TMP_PSORD133
   (
      Loadkey      NVARCHAR(50)
    , Pickslipno   NVARCHAR(50)
    , Facility     NVARCHAR(15)
    , TodayDate    NVARCHAR(16)
    , OriginalQty  INT
    , QtyAllocated INT
    , Pickzone     NVARCHAR(20)
    , Loc          NVARCHAR(10)
    , SKU          NVARCHAR(20)
    , RetailSKU    NVARCHAR(50)
    , Size         NVARCHAR(20)
    , UOMQty       INT
    , Qty          INT
    , Dropid       NVARCHAR(20)
    , Sdescr       NVARCHAR(60)
    , Orderkey     NVARCHAR(10)
    , Wavekey      NVARCHAR(50)
    , LogicalLoc   NVARCHAR(50) --WL01
   )

   CREATE TABLE #TMP_PZ
   (
      Loadkey  NVARCHAR(10)
    , Orderkey NVARCHAR(10)
    , Pickzone NVARCHAR(20)
   )

   CREATE TABLE #TMP_PZ1
   (
      RowID    INT --NOT NULL IDENTITY(1,1),
    , Loadkey  NVARCHAR(10)
    , Orderkey NVARCHAR(10)
    , Pickzone NVARCHAR(20)
   )

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Loadkey
        , Orderkey
   FROM #TMP_LoadOrd
   ORDER BY RowID

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP
   INTO @c_GetLoadkey
      , @c_GetOrderkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order
      SET @c_PickHeaderKey = N''

      IF NOT EXISTS (  SELECT PickHeaderKey
                       FROM PICKHEADER WITH (NOLOCK)
                       WHERE ExternOrderKey = @c_GetLoadkey AND OrderKey = @c_GetOrderkey AND Zone = '3')
      BEGIN
         SET @b_success = 0

         BEGIN TRAN

         SELECT @b_success = 0
         EXECUTE nspg_GetKey 'PICKSLIP'
                           , 9
                           , @c_PickHeaderKey OUTPUT
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            ROLLBACK TRAN
            SELECT @n_continue = 3
            SELECT @n_err = 63500 -- SOS# 245168
            SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                               + N': Get PICKSLIP number failed. (isp_GetPickSlipOrders133)'
         END
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT @c_PickHeaderKey = N'P' + @c_PickHeaderKey

            INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, OrderKey, Zone)
            VALUES (@c_PickHeaderKey, @c_GetLoadkey, @c_GetOrderkey, '3')

            SELECT @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               ROLLBACK TRAN
               SELECT @n_continue = 3
               SELECT @n_err = 63501
               SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                                  + N': Insert Into PICKHEADER Failed. (isp_GetPickSlipOrders133)'
            END
         END -- @n_continue = 1 or @n_continue = 2
         COMMIT TRAN

         IF @b_success = 0
            SELECT @n_continue = 3
      END
      ELSE
      BEGIN
         SELECT @c_PickHeaderKey = PickHeaderKey
         FROM PICKHEADER WITH (NOLOCK)
         WHERE ExternOrderKey = @c_GetLoadkey AND OrderKey = @c_GetOrderkey AND Zone = '3'
      END

      IF ISNULL(RTRIM(@c_PickHeaderKey), '') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_err = 65005
         SET @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err) + N': Get Pickslipno Failed. (isp_GetPickSlipOrders133)'
      END

      INSERT INTO #TMP_PSORD133 (Loadkey, Pickslipno, Facility, TodayDate, OriginalQty, QtyAllocated, Pickzone, Loc
                               , SKU, RetailSKU, [Size], UOMQty, Qty, Dropid, Sdescr, Orderkey, Wavekey, LogicalLoc) --WL01
      SELECT --CASE WHEN (SELECT COUNT(Distinct OH.Consigneekey)
         --                  FROM ORDERS (NOLOCK)
         --                  WHERE ORDERS.LoadKey = @c_Loadkey
         --                  AND ORDERS.Consigneekey <> '') = 1 THEN MAX(OH.Consigneekey) ELSE @c_Loadkey END AS Loadkey
         @c_GetLoadkey
       , PH.PickHeaderKey
       , OH.Facility
       , REPLACE(CONVERT(NVARCHAR(16), GETDATE(), 120), '-', '/') AS TodayDate
       , (  SELECT SUM(ORDERDETAIL.OriginalQty)
            FROM ORDERDETAIL (NOLOCK)
            JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
            WHERE ORDERS.OrderKey = @c_GetOrderkey) AS OriginalQty
       , (  SELECT SUM(ORDERDETAIL.QtyAllocated)
            FROM ORDERDETAIL (NOLOCK)
            JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
            WHERE ORDERS.OrderKey = @c_GetOrderkey) AS QtyAllocated
       , LOC.PickZone
       , PD.Loc
       , PD.Sku
       , S.RETAILSKU
       , S.Size
       , CASE WHEN PD.UOM = '2' THEN SUM(PD.UOMQty)
              ELSE 0 END AS UOMQty
       , CASE WHEN PD.UOM <> '2' THEN SUM(PD.Qty)
              ELSE 0 END AS Qty
       , PD.DropID
       , S.DESCR
       , @c_GetOrderkey
       , OH.UserDefine09
       , LOC.LogicalLocation --WL01
      FROM LoadPlanDetail LPD (NOLOCK) --WL01
      JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey --WL01
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
      JOIN PICKDETAIL PD (NOLOCK) ON  PD.OrderKey = OH.OrderKey
                                  AND PD.Sku = OD.Sku
                                  AND PD.OrderLineNumber = OD.OrderLineNumber
      JOIN SKU S (NOLOCK) ON S.Sku = PD.Sku AND S.StorerKey = OH.StorerKey
      JOIN LOC LOC (NOLOCK) ON PD.Loc = LOC.Loc
      LEFT JOIN PICKHEADER PH (NOLOCK) ON OH.LoadKey = PH.ExternOrderKey AND OH.OrderKey = PH.OrderKey
      WHERE LPD.LoadKey = @c_GetLoadkey AND OH.OrderKey = @c_GetOrderkey --WL01
      GROUP BY PH.PickHeaderKey
             , OH.Facility
             , LOC.PickZone
             , PD.Loc
             , PD.Sku
             , S.RETAILSKU
             , S.Size
             , PD.UOM
             , PD.DropID
             , S.DESCR
             , OH.UserDefine09
             , LOC.LogicalLocation --WL01

      FETCH NEXT FROM CUR_LOOP
      INTO @c_GetLoadkey
         , @c_GetOrderkey
   END

   INSERT INTO #TMP_PZ (Loadkey, Orderkey, Pickzone)
   SELECT DISTINCT Loadkey
                 , Orderkey
                 , Pickzone
   FROM #TMP_PSORD133
   ORDER BY Loadkey
          , Orderkey
          , Pickzone

   INSERT INTO #TMP_PZ1 (RowID, Loadkey, Orderkey, Pickzone)
   SELECT DISTINCT (ROW_NUMBER() OVER (PARTITION BY Loadkey
                                                  , Orderkey
                                       ORDER BY Loadkey
                                              , Orderkey
                                              , Pickzone ASC))
                 , Loadkey
                 , Orderkey
                 , Pickzone
   FROM #TMP_PZ
   ORDER BY Loadkey
          , Orderkey
          , Pickzone

   --SELECT * FROM #TMP_PZ1 ORDER BY Loadkey,Pickzone

   SELECT tc.Loadkey
        , tc.Pickslipno AS Pickslipno
        , tc.Facility
        , tc.TodayDate
        , tc.OriginalQty
        , tc.QtyAllocated
        , tc.Pickzone
        , tc.Loc
        , tc.SKU
        , tc.RetailSKU
        , tc.[Size]
        , tc.UOMQty
        , tc.Qty
        , tc.Dropid
        , tc.Sdescr
        , tc.Orderkey
        , tc.Wavekey
   FROM #TMP_PSORD133 tc
   JOIN #TMP_PZ1 tp ON tp.Pickzone = tc.Pickzone AND tp.Loadkey = tc.Loadkey AND tp.Orderkey = tc.Orderkey
   ORDER BY tc.Loadkey
          , tc.Orderkey
          , tc.Pickzone
          , tc.LogicalLoc --WL01
          , tc.SKU
          , tc.Dropid

   QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_PSORD133') IS NOT NULL
      DROP TABLE #TMP_PSORD133

   IF OBJECT_ID('tempdb..#TMP_PZ') IS NOT NULL
      DROP TABLE #TMP_PZ

   IF OBJECT_ID('tempdb..#TMP_PZ1') IS NOT NULL
      DROP TABLE #TMP_PZ1

   IF OBJECT_ID('tempdb..#TMP_LoadOrd') IS NOT NULL
      DROP TABLE #TMP_LoadOrd

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   IF @n_continue = 3 -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipOrders133'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END /* main procedure */

GO
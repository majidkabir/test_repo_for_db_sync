SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_ConsoPickList50                                */
/* Creation Date: 18-AUG-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-20542 [CN] - YONEX_PrintPickSlips_NEW                   */
/*                                                                      */
/* Called By: r_dw_consolidated_pick50                                  */
/*           Duplicate from r_dw_consolidated_pick46                    */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 18-AUG-2022  CSCHONG  1.0  Devops Scripts Combine                    */
/************************************************************************/

CREATE PROC [dbo].[isp_ConsoPickList50] (
   @c_LoadKey      NVARCHAR(10),
   @c_LoadKeyEnd   NVARCHAR(10) = '',
   @c_Storerkey    NVARCHAR(15) = '' )

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_err           INT,
            @n_continue      INT,
            @c_PickHeaderKey NVARCHAR(10),
            @b_success       INT,
            @c_errmsg        NVARCHAR(255),
            @n_StartTCnt     INT,
            @c_GetLoadkey    NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_continue = 1

   CREATE TABLE #TMP_Load (
      RowID             INT NOT NULL IDENTITY(1,1),
      Loadkey           NVARCHAR(10)
   )

   IF ISNULL(@c_LoadKeyEnd,'') = '' OR ISNULL(@c_Storerkey,'') = ''
   BEGIN
      INSERT INTO #TMP_Load
      SELECT @c_LoadKey
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_Load
      SELECT DISTINCT LoadKey
      FROM ORDERS (NOLOCK)
      WHERE LoadKey BETWEEN @c_LoadKey AND @c_LoadKeyEnd
      AND StorerKey = @c_Storerkey
      ORDER BY LoadKey
   END

   CREATE TABLE #TMP_CONSO50 (
      Loadkey           NVARCHAR(50),
      Pickslipno        NVARCHAR(50),
      Facility          NVARCHAR(15),
      TodayDate         NVARCHAR(16),
      OriginalQty       INT,
      QtyAllocated      INT,
      Pickzone          NVARCHAR(20),
      Loc               NVARCHAR(10),
      SKU               NVARCHAR(20),
      RetailSKU         NVARCHAR(50),
      Size              NVARCHAR(20),
      UOMQty            INT,
      Qty               INT,
      Dropid            NVARCHAR(20),
      Sdescr            NVARCHAR(60)
   )

   CREATE TABLE #TMP_PZ (
      Loadkey           NVARCHAR(10),
      Pickzone          NVARCHAR(20)
   )

   CREATE TABLE #TMP_PZ1 (
      RowID             INT, --NOT NULL IDENTITY(1,1),
      Loadkey           NVARCHAR(10),
      Pickzone          NVARCHAR(20)
   )

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT LoadKey
   FROM #TMP_Load
   ORDER BY RowID

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_GetLoadkey

   WHILE @@FETCH_STATUS <> - 1
   BEGIN
      -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order
      SET @c_PickHeaderKey = ''

      IF NOT EXISTS(SELECT PickHeaderKey
                    FROM PICKHEADER WITH (NOLOCK)
                    WHERE ExternOrderKey = @c_GetLoadkey
                    AND Zone = '7')
      BEGIN
         SET @b_success = 0

         EXEC isp_CreatePickSlip
              @c_Loadkey = @c_GetLoadkey
             ,@c_PickslipType = '7'
             ,@c_ConsolidateByLoad = 'Y'
             ,@c_Refkeylookup = 'N'
             ,@c_LinkPickSlipToPick = 'N'  --Y=Update pickslipno to pickdetail.pickslipno
             ,@c_AutoScanIn = 'N'
             ,@b_Success = @b_Success OUTPUT
             ,@n_Err = @n_err OUTPUT
             ,@c_ErrMsg = @c_errmsg OUTPUT

         IF @b_Success = 0
            SELECT @n_continue = 3
      END
      ELSE
      BEGIN
         SELECT @c_PickHeaderKey = PickHeaderKey
         FROM PickHeader WITH (NOLOCK)
         WHERE ExternOrderKey = @c_GetLoadkey
         AND Zone = '7'
      END

      IF ISNULL(RTRIM(@c_PickHeaderKey),'') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_err = 65005
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Get Pickslipno Failed. (isp_ConsoPickList50)'
      END

      INSERT INTO #TMP_CONSO50
      (
         Loadkey,
         Pickslipno,
         Facility,
         TodayDate,
         OriginalQty,
         QtyAllocated,
         Pickzone,
         Loc,
         SKU,
         RetailSKU,
         [Size],
         UOMQty,
         Qty,
         Dropid,Sdescr
      )
      SELECT --CASE WHEN (SELECT COUNT(Distinct OH.Consigneekey)
      --                  FROM ORDERS (NOLOCK)
      --                  WHERE ORDERS.LoadKey = @c_Loadkey
      --                  AND ORDERS.Consigneekey <> '') = 1 THEN MAX(OH.Consigneekey) ELSE @c_Loadkey END AS Loadkey
             @c_GetLoadkey
           , PH.PickHeaderKey
           , OH.Facility
           , REPLACE(CONVERT(NVARCHAR(16), Getdate(), 120), '-', '/') AS TodayDate
           , (SELECT SUM(ORDERDETAIL.OriginalQty) FROM ORDERDETAIL (NOLOCK)
              JOIN ORDERS (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
              WHERE ORDERS.Loadkey = @c_GetLoadkey) AS OriginalQty
           , (SELECT SUM(ORDERDETAIL.QtyAllocated) FROM ORDERDETAIL (NOLOCK)
              JOIN ORDERS (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
              WHERE ORDERS.Loadkey = @c_GetLoadkey) AS QtyAllocated
           , Loc.Pickzone
           , PD.Loc
           , PD.SKU
           , S.RetailSKU
           , S.Size
           , CASE WHEN PD.UOM = '2' THEN SUM(PD.UOMQty) ELSE 0 END AS UOMQty
           , CASE WHEN PD.UOM <> '2' THEN SUM(PD.Qty) ELSE 0 END AS Qty
           , PD.DropID
           , S.DESCR
      FROM ORDERS OH (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey AND PD.SKU = OD.SKU AND PD.OrderLineNumber = OD.OrderLineNumber
      JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = OH.StorerKey
      JOIN LOC LOC (NOLOCK) ON PD.LOC = LOC.LOC
      LEFT JOIN PICKHEADER PH (NOLOCK) ON OH.LoadKey = PH.ExternOrderKey
      WHERE OH.LoadKey = @c_GetLoadkey
      GROUP BY PH.PickHeaderKey
             , OH.Facility
             , Loc.Pickzone
             , PD.Loc
             , PD.SKU
             , S.Retailsku
             , S.Size
             , PD.UOM
             , PD.DropID
             , S.DESCR

      FETCH NEXT FROM CUR_LOOP INTO @c_GetLoadkey
   END

   INSERT INTO #TMP_PZ (Loadkey, PickZone)
   SELECT DISTINCT Loadkey, Pickzone
   FROM #TMP_CONSO50
   ORDER BY Loadkey,Pickzone

   INSERT INTO #TMP_PZ1 (RowID, Loadkey, PickZone)
   SELECT DISTINCT (Row_Number() OVER (PARTITION BY Loadkey ORDER BY Loadkey,Pickzone ASC)), Loadkey, Pickzone
   FROM #TMP_PZ
   ORDER BY Loadkey,Pickzone

   --SELECT * FROM #TMP_PZ1 ORDER BY Loadkey,Pickzone

   SELECT tc.Loadkey,
          tc.Pickslipno + '-' + CAST(tp.RowID AS NVARCHAR(10)) AS Pickslipno,
          tc.Facility,
          tc.TodayDate,
          tc.OriginalQty,
          tc.QtyAllocated,
          tc.Pickzone,
          tc.Loc,
          tc.SKU,
          tc.RetailSKU,
          tc.[Size],
          tc.UOMQty,
          tc.Qty,
          tc.Dropid,
          tc.Sdescr  
   FROM #TMP_CONSO50 tc
   JOIN #TMP_PZ1 tp ON tp.Pickzone = tc.Pickzone AND tp.Loadkey = tc.Loadkey
   ORDER BY tc.Loadkey, Pickzone

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_CONSO50') IS NOT NULL
      DROP TABLE #TMP_CONSO50

   IF OBJECT_ID('tempdb..#TMP_PZ') IS NOT NULL
      DROP TABLE #TMP_PZ

   IF OBJECT_ID('tempdb..#TMP_PZ1') IS NOT NULL
      DROP TABLE #TMP_PZ1

   IF OBJECT_ID('tempdb..#TMP_Load') IS NOT NULL
      DROP TABLE #TMP_Load

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   IF @n_continue=3  -- Error Occured - Process And Return
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_ConsoPickList50'
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
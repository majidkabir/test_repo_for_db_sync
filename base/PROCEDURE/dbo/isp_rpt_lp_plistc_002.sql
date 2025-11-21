SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_LP_PLISTC_002                                 */
/* Creation Date: 26-APR-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-19502                                                      */
/*                                                                         */
/* Called By: RPT_LP_PLISTC_002                                            */
/*                                                                         */
/* GitLab Version: 1.1                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author   Ver  Purposes                                     */
/* 27-Apr-2022  WLChooi  1.0  DevOps Combine Script                        */
/* 31-Oct-2023  WLChooi  1.1  UWP-10213 - Global Timezone (GTZ01)          */
/***************************************************************************/

CREATE   PROC [dbo].[isp_RPT_LP_PLISTC_002]
(
   @c_Loadkey       NVARCHAR(10)
 , @c_PreGenRptData NVARCHAR(10) = ''
)
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET NOCOUNT ON

   DECLARE @c_pickheaderkey   NVARCHAR(10)
         , @n_continue        INT
         , @n_starttcnt       INT
         , @c_errmsg          NVARCHAR(255)
         , @b_success         INT
         , @n_err             INT
         , @c_sku             NVARCHAR(20)
         , @c_SkuDescr        NVARCHAR(60)
         , @c_Loc             NVARCHAR(10)
         , @c_LogicalLoc      NVARCHAR(18)
         , @c_LocType         NVARCHAR(10)
         , @c_ID              NVARCHAR(18)
         , @c_orderkey        NVARCHAR(10)
         , @c_PickslipNo      NVARCHAR(10)
         , @c_PrintedFlag     NVARCHAR(1)
         , @c_PrevPickslipNo  NVARCHAR(10)
         , @c_PickUOM         NVARCHAR(5)
         , @c_PickZone        NVARCHAR(10)
         , @c_C_Company       NVARCHAR(45)
         , @c_PickType        NVARCHAR(30)
         , @c_PickDetailkey   NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)
         , @d_LoadDate        DATETIME
         , @c_Lottable02      NVARCHAR(18)
         , @d_Lottable04      DATETIME
         , @n_Palletcnt       INT
         , @n_Cartoncnt       INT
         , @n_EA              INT
         , @n_TotalCarton     FLOAT
         , @n_Pallet          INT
         , @n_Casecnt         INT
         , @n_Qty             INT
         , @n_PageNo          INT
         , @c_TotalPage       INT
         , @b_debug           INT
         , @c_WaveKey         NVARCHAR(10)
         , @c_Lottable02label NVARCHAR(30)
         , @c_Lottable04Label NVARCHAR(30)
         , @c_Storerkey       NVARCHAR(15)
         , @c_Route           NVARCHAR(10)
         , @c_Consigneekey    NVARCHAR(15)
         , @c_OrderGrp        NVARCHAR(20)
         , @n_CntOrderGrp     INT
         , @c_OrdGrpFlag      NVARCHAR(1)
         , @c_RLoadkey        NVARCHAR(20)
         , @c_TrfRoom         NVARCHAR(10)
         , @c_LEXTLoadKey     NVARCHAR(20)
         , @c_LPriority       NVARCHAR(10)
         , @c_LPuserdefDate01 DATETIME
         , @n_innerpack       FLOAT
         , @n_showField       INT
         , @n_innercnt        FLOAT
         , @c_Facility        NVARCHAR(5)   --GTZ01

   DECLARE @t_Result TABLE
   (
      Loadkey         NVARCHAR(10)
    , Pickslipno      NVARCHAR(10)
    , PickType        NVARCHAR(30)
    , LoadingDate     DATETIME
    , PickZone        NVARCHAR(10)
    , C_Company       NVARCHAR(45)
    , Loc             NVARCHAR(10)
    , Logicalloc      NVARCHAR(18)
    , SKU             NVARCHAR(20)
    , Descr           NVARCHAR(60)
    , Palletcnt       INT
    , Cartoncnt       INT
    , EA              INT
    , TotalCarton     FLOAT
    , ID              NVARCHAR(18)
    , Lottable02      NVARCHAR(18)
    , Lottable04      DATETIME
    , ReprintFlag     NVARCHAR(1)
    , PageNo          INT
    , TotalPage       INT
    , Route           NVARCHAR(10)
    , Storerkey       NVARCHAR(15)
    , Consigneekey    NVARCHAR(15)
    , OrderGrpFlag    NVARCHAR(1)
    , OrderGrp        NVARCHAR(20)
    , TrfRoom         NVARCHAR(10) NULL
    , LEXTLoadKey     NVARCHAR(20) NULL
    , LPriority       NVARCHAR(10) NULL
    , LPuserdefDate01 DATETIME
    , rowid           INT          IDENTITY(1, 1)
    , showfield       INT
    , InnerPack       FLOAT
   )

   SELECT @n_continue = 1
        , @n_starttcnt = @@TRANCOUNT
   SELECT @b_debug = 0

   IF EXISTS (  SELECT 1
                FROM PICKHEADER (NOLOCK)
                WHERE ExternOrderKey = @c_Loadkey AND Zone = 'LB')
      SELECT @c_PrintedFlag = N'Y'
   ELSE
      SELECT @c_PrintedFlag = N'N'

   BEGIN TRAN

   IF ISNULL(@c_PreGenRptData, '') = 'Y'
   BEGIN
      -- Uses PickType as a Printed Flag
      UPDATE PICKHEADER
      SET PickType = '1'
        , TrafficCop = NULL
      WHERE ExternOrderKey = @c_Loadkey AND Zone = 'LB' AND PickType = '0'
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
              , @n_err = 73000
         SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + N': Update Failed On Table Pickheader Table. (isp_RPT_LP_PLISTC_002)' + N' ( '
                            + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '
      END
   END


   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE pickslip_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LoadPlan.LoadKey
           , LOC.LocationType
           , LoadPlan.AddDate

           -- CASE WHEN UPPER(LOC.LocationType) = 'CASE' OR UPPER(LOC.LocationType) = 'PICK'
      --      THEN LOC.PickZone ELSE 'BULK' END,
           , ISNULL(RTRIM(LOC.PickZone), '')
           , ISNULL(RTRIM(ORDERS.C_Company), '')
           , PICKDETAIL.Loc
           , LOC.LogicalLocation
           , PICKDETAIL.Sku
           , MAX(SKU.DESCR)
           , PICKDETAIL.ID
           , LA.Lottable02
           , LA.Lottable04
           , PACK.Pallet
           , PACK.CaseCnt
           , SUM(PICKDETAIL.Qty)
           , ISNULL(RTRIM(LoadPlan.Route), '')
           , ORDERS.StorerKey
           , ORDERS.ConsigneeKey
           , CASE WHEN ISNULL(CLR.Code, '') = '' THEN 'N'
                  ELSE 'Y' END AS showordergrp
           , LoadPlan.TrfRoom
           , LoadPlan.ExternLoadKey AS LEXTLoadKey
           , LoadPlan.Priority AS LPriority
           , LoadPlan.lpuserdefdate01 AS LPuserdefDate01
           , PACK.InnerPack
      FROM PICKDETAIL WITH (NOLOCK)
      JOIN ORDERS WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERS.OrderKey)
      JOIN LoadPlanDetail WITH (NOLOCK) ON LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey
      JOIN LoadPlan WITH (NOLOCK) ON LoadPlan.LoadKey = LoadPlanDetail.LoadKey
      JOIN LOC WITH (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
      JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = PICKDETAIL.Storerkey AND SKU.Sku = PICKDETAIL.Sku
      JOIN PACK WITH (NOLOCK) ON PACK.PackKey = SKU.PACKKey
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = PICKDETAIL.Lot
      LEFT OUTER JOIN CODELKUP CLR (NOLOCK) ON (   ORDERS.StorerKey = CLR.Storerkey
                                               AND CLR.Code = 'SHOWORDERGRP'
                                               AND CLR.LISTNAME = 'REPORTCFG'
                                               AND CLR.Long = 'RPT_LP_PLISTC_002'
                                               AND ISNULL(CLR.Short, '') <> 'N')
      WHERE LoadPlan.LoadKey = @c_Loadkey
      -- AND   Pickdetail.Pickslipno > ''
      AND   PICKDETAIL.Status < '5'
      GROUP BY LoadPlan.LoadKey
             , LOC.LocationType
             , LoadPlan.AddDate
             , ISNULL(RTRIM(LOC.PickZone), '')
             , ISNULL(RTRIM(ORDERS.C_Company), '')
             , PICKDETAIL.Loc
             , LOC.LogicalLocation
             , PICKDETAIL.Sku
             , PICKDETAIL.ID
             , LA.Lottable02
             , LA.Lottable04
             , PACK.Pallet
             , PACK.CaseCnt
             , ISNULL(RTRIM(LoadPlan.Route), '')
             , ORDERS.StorerKey
             , ORDERS.ConsigneeKey
             , CASE WHEN ISNULL(CLR.Code, '') = '' THEN 'N'
                    ELSE 'Y' END
             , LoadPlan.TrfRoom
             , LoadPlan.ExternLoadKey
             , LoadPlan.Priority
             , LoadPlan.lpuserdefdate01
             , PACK.InnerPack
      ORDER BY ISNULL(RTRIM(LOC.PickZone), '')
             , LOC.LogicalLocation
             , PICKDETAIL.Loc
             , PICKDETAIL.Sku

      OPEN pickslip_cur

      FETCH NEXT FROM pickslip_cur
      INTO @c_Loadkey
         , @c_LocType
         , @d_LoadDate
         , @c_PickZone
         , @c_C_Company
         , @c_Loc
         , @c_LogicalLoc
         , @c_sku
         , @c_SkuDescr
         , @c_ID
         , @c_Lottable02
         , @d_Lottable04
         , @n_Pallet
         , @n_Casecnt
         , @n_Qty
         , @c_Route
         , @c_Storerkey
         , @c_Consigneekey
         , @c_OrdGrpFlag
         , @c_TrfRoom
         , @c_LEXTLoadKey
         , @c_LPriority
         , @c_LPuserdefDate01
         , @n_innerpack

      WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         SET @n_Palletcnt = 0
         SET @n_Cartoncnt = 0
         SET @n_EA = 0
         SET @n_TotalCarton = 0.00

         SET @n_TotalCarton = CASE WHEN @n_Casecnt > 0 THEN @n_Qty / @n_Casecnt
                                   ELSE 0 END

         IF UPPER(@c_PickZone) <> 'BULK'
         BEGIN
            SET @c_PickType = N'PICKING AREA'
         END
         ELSE
         BEGIN
            IF @n_Qty >= @n_Pallet
            BEGIN
               SET @c_PickType = N'FULL PALLET PICK'
            END
            ELSE
            BEGIN
               SET @c_PickType = N'CASE PICK'
            END
         END

         SET @n_Palletcnt = CASE WHEN @n_Pallet > 0 THEN @n_Qty / @n_Pallet
                                 ELSE 0 END
         SET @n_Cartoncnt = CASE WHEN @n_Casecnt > 0 THEN (@n_Qty - (@n_Palletcnt * @n_Pallet)) / @n_Casecnt
                                 ELSE 0 END
         SET @n_EA = @n_Qty - (@n_Palletcnt * @n_Pallet) - (@n_Cartoncnt * @n_Casecnt)

         SET @n_innercnt = CASE WHEN @n_innerpack > 0 AND @n_Casecnt > 0 THEN
         ((@n_Qty - (@n_Cartoncnt * @n_Casecnt)) / @n_innerpack)
                                ELSE 0 END

         SET @n_showField = 0

         SELECT @n_showField = CASE WHEN ISNULL(Short, '0') = 'Y' THEN 1
                                    ELSE 0 END
         FROM CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'REPORTCFG'
         AND   Storerkey = @c_Storerkey
         AND   Long = 'RPT_LP_PLISTC_002'
         AND   Code = 'showfield'
         AND   ISNULL(Short, '') <> 'N'

         INSERT INTO @t_Result (Loadkey, Pickslipno, PickType, LoadingDate, PickZone, Loc, Logicalloc, SKU, Descr
                              , Palletcnt, Cartoncnt, TotalCarton, ID, Lottable02, Lottable04, ReprintFlag, PageNo
                              , TotalPage, C_Company, EA, Route, Storerkey, Consigneekey, OrderGrpFlag, TrfRoom
                              , LEXTLoadKey, LPriority, LPuserdefDate01, showfield, InnerPack)
         VALUES (@c_Loadkey, '', @c_PickType, @d_LoadDate, @c_PickZone, @c_Loc, @c_LogicalLoc, @c_sku, @c_SkuDescr
               , @n_Palletcnt, @n_Cartoncnt, @n_TotalCarton, @c_ID, @c_Lottable02, @d_Lottable04, @c_PrintedFlag, 0, 0
               , @c_C_Company, @n_EA, @c_Route, @c_Storerkey, @c_Consigneekey, @c_OrdGrpFlag, @c_TrfRoom
               , @c_LEXTLoadKey, @c_LPriority, @c_LPuserdefDate01, @n_showField, @n_innercnt)

         FETCH NEXT FROM pickslip_cur
         INTO @c_Loadkey
            , @c_LocType
            , @d_LoadDate
            , @c_PickZone
            , @c_C_Company
            , @c_Loc
            , @c_LogicalLoc
            , @c_sku
            , @c_SkuDescr
            , @c_ID
            , @c_Lottable02
            , @d_Lottable04
            , @n_Pallet
            , @n_Casecnt
            , @n_Qty
            , @c_Route
            , @c_Storerkey
            , @c_Consigneekey
            , @c_OrdGrpFlag
            , @c_TrfRoom
            , @c_LEXTLoadKey
            , @c_LPriority
            , @c_LPuserdefDate01
            , @n_innerpack
      END /* While */

      CLOSE pickslip_cur
      DEALLOCATE pickslip_cur
   END /* @n_Continue = 1 */

   IF @b_debug = 1
   BEGIN
      SELECT *
      FROM @t_Result

      SELECT PickType
           , PickZone
           , Consigneekey
      FROM @t_Result
      WHERE Pickslipno = ''
      GROUP BY PickType
             , PickZone
             , Consigneekey
      ORDER BY CASE WHEN PickType = 'PICKING AREA' THEN '1'
                    WHEN PickType = 'FULL PALLET PICK' THEN '2'
                    ELSE '3' END
             , Consigneekey
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE PickType_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickType
           , PickZone
           , Consigneekey
      FROM @t_Result
      WHERE Pickslipno = ''
      GROUP BY PickType
             , PickZone
             , Consigneekey
      ORDER BY CASE WHEN PickType = 'PICKING AREA' THEN '1'
                    WHEN PickType = 'FULL PALLET PICK' THEN '2'
                    ELSE '3' END
             , Consigneekey

      OPEN PickType_cur

      FETCH NEXT FROM PickType_cur
      INTO @c_PickType
         , @c_PickZone
         , @c_Consigneekey

      WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         SET @c_pickheaderkey = N''
         SET @c_WaveKey = N''

         IF @c_PickZone = 'BULK'
         BEGIN
            IF @c_PickType = 'FULL PALLET PICK'
            BEGIN
               SELECT @c_pickheaderkey = PickHeaderKey
               FROM PICKHEADER (NOLOCK)
               WHERE ExternOrderKey = @c_Loadkey
               AND   WaveKey = RTRIM(@c_PickZone) + '_P'
               AND   Zone = 'LB'
               AND   ConsoOrderKey = @c_Consigneekey

               SELECT @c_WaveKey = RTRIM(@c_PickZone) + N'_P'
            END
            ELSE
            BEGIN
               SELECT @c_pickheaderkey = PickHeaderKey
               FROM PICKHEADER (NOLOCK)
               WHERE ExternOrderKey = @c_Loadkey
               AND   WaveKey = RTRIM(@c_PickZone) + '_C'
               AND   Zone = 'LB'
               AND   ConsoOrderKey = @c_Consigneekey

               SELECT @c_WaveKey = RTRIM(@c_PickZone) + N'_C'
            END
         END
         ELSE
         BEGIN
            SELECT @c_pickheaderkey = PickHeaderKey
            FROM PICKHEADER (NOLOCK)
            WHERE ExternOrderKey = @c_Loadkey
            AND   WaveKey = @c_PickZone
            AND   Zone = 'LB'
            AND   ConsoOrderKey = @c_Consigneekey

            SELECT @c_WaveKey = RTRIM(@c_PickZone)
         END

         -- Only insert the First Pickslip# in PickHeader
         IF ISNULL(RTRIM(@c_pickheaderkey), '') = '' AND ISNULL(@c_PreGenRptData, '') = 'Y'
         BEGIN
            EXECUTE nspg_GetKey 'PICKSLIP'
                              , 9
                              , @c_pickheaderkey OUTPUT
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

            SELECT @c_pickheaderkey = N'P' + @c_pickheaderkey

            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop, WaveKey
                                  , ConsoOrderKey)
            VALUES (@c_pickheaderkey, '', @c_Loadkey, '0', 'LB', '', @c_WaveKey, @c_Consigneekey)

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 73001
               SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                  + N': Insert Failed On Table PICKHEADER. (isp_RPT_LP_PLISTC_002)' + N' ( '
                                  + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '
            END
         END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            UPDATE @t_Result
            SET Pickslipno = @c_pickheaderkey
            WHERE Pickslipno = ''
            AND   PickType = @c_PickType
            AND   PickZone = @c_PickZone
            AND   Consigneekey = @c_Consigneekey

            -- Get PickDetail records for each Pick Ticket (Picking Area / Full Pallet / Case Pick)
            DECLARECURSOR_PickDet:
            IF @c_PickType = 'PICKING AREA'
            BEGIN
               DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PICKDETAIL.PickDetailKey
                    , PICKDETAIL.OrderKey
                    , PICKDETAIL.OrderLineNumber
               FROM PICKDETAIL WITH (NOLOCK)
               JOIN LoadPlanDetail WITH (NOLOCK) ON LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey
               JOIN LOC WITH (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
               JOIN ORDERS WITH (NOLOCK) ON LoadPlanDetail.OrderKey = ORDERS.OrderKey
               WHERE LoadPlanDetail.LoadKey = @c_Loadkey
               --AND    (LOC.LocationType = 'CASE' OR LOC.LocationType = 'PICK' OR LOC.LocationType = 'PALLET')  
               AND   (  LOC.LocationType = 'CASE'
                     OR LOC.LocationType = 'PICK'
                     OR LOC.LocationType = 'PALLET'
                     OR ISNULL(LOC.PickZone, '') = '')
               AND   LOC.PickZone = @c_PickZone
               AND   PICKDETAIL.Status < '5'
               AND   ORDERS.ConsigneeKey = @c_Consigneekey
               ORDER BY PickDetailKey
            END
            ELSE IF @c_PickType = 'FULL PALLET PICK'
            BEGIN
               DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PICKDETAIL.PickDetailKey
                    , PICKDETAIL.OrderKey
                    , PICKDETAIL.OrderLineNumber
               FROM PICKDETAIL WITH (NOLOCK)
               JOIN LoadPlanDetail WITH (NOLOCK) ON LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey
               JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = PICKDETAIL.Lot
               JOIN ORDERS WITH (NOLOCK) ON LoadPlanDetail.OrderKey = ORDERS.OrderKey
               JOIN @t_Result RESULT ON  PICKDETAIL.Sku = RESULT.SKU
                                     AND PICKDETAIL.Loc = RESULT.Loc
                                     AND PICKDETAIL.ID = RESULT.ID
                                     AND ISNULL(LA.Lottable02, '') = ISNULL(RESULT.Lottable02, '')
                                     AND ISNULL(LA.Lottable04, '') = ISNULL(RESULT.Lottable04, '')
                                     AND RESULT.Consigneekey = ORDERS.ConsigneeKey
               WHERE LoadPlanDetail.LoadKey = @c_Loadkey
               AND   RESULT.PickType = 'FULL PALLET PICK'
               AND   PICKDETAIL.Status < '5'
               AND   ORDERS.ConsigneeKey = @c_Consigneekey
               ORDER BY PickDetailKey
            END -- 'Full Pallet Pick'
            ELSE IF @c_PickType = 'CASE PICK'
            BEGIN
               DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PICKDETAIL.PickDetailKey
                    , PICKDETAIL.OrderKey
                    , PICKDETAIL.OrderLineNumber
               FROM PICKDETAIL WITH (NOLOCK)
               JOIN LoadPlanDetail WITH (NOLOCK) ON LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey
               JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = PICKDETAIL.Lot
               JOIN ORDERS WITH (NOLOCK) ON LoadPlanDetail.OrderKey = ORDERS.OrderKey
               JOIN @t_Result RESULT ON  PICKDETAIL.Sku = RESULT.SKU
                                     AND PICKDETAIL.Loc = RESULT.Loc
                                     AND PICKDETAIL.ID = RESULT.ID
                                     AND ISNULL(LA.Lottable02, '') = ISNULL(RESULT.Lottable02, '')
                                     AND ISNULL(LA.Lottable04, '') = ISNULL(RESULT.Lottable04, '')
                                     AND RESULT.Consigneekey = ORDERS.ConsigneeKey
               WHERE LoadPlanDetail.LoadKey = @c_Loadkey
               AND   RESULT.PickType = 'CASE PICK'
               AND   PICKDETAIL.Status < '5'
               AND   ORDERS.ConsigneeKey = @c_Consigneekey
               ORDER BY PickDetailKey
            END -- 'CASE PICK'

            OPEN PickDet_cur
            SELECT @n_err = @@ERROR

            IF @n_err = 16905
            BEGIN
               CLOSE PickDet_cur
               DEALLOCATE PickDet_cur
               GOTO DECLARECURSOR_PickDet
            END

            IF @n_err = 16915
            BEGIN
               CLOSE PickDet_cur
               DEALLOCATE PickDet_cur
               GOTO DECLARECURSOR_PickDet
            END

            IF @n_err = 16916
            BEGIN
               GOTO EXIT_SP
            END

            FETCH NEXT FROM PickDet_cur
            INTO @c_PickDetailkey
               , @c_orderkey
               , @c_OrderLineNumber

            WHILE (@@FETCH_STATUS <> -1)
            AND   (@n_continue = 1 OR @n_continue = 2)
            AND   ISNULL(@c_PreGenRptData, '') = 'Y'
            BEGIN
               IF NOT EXISTS (  SELECT 1
                                FROM RefKeyLookup WITH (NOLOCK)
                                WHERE PickDetailkey = @c_PickDetailkey)
               BEGIN
                  INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                  VALUES (@c_PickDetailkey, @c_pickheaderkey, @c_orderkey, @c_OrderLineNumber, @c_Loadkey)

                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                          , @n_err = 73001
                     SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + N': Insert Failed On Table RefkeyLookup. (isp_RPT_LP_PLISTC_002)' + N' ( '
                                        + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '
                  END

                  IF (@n_continue = 1 OR @n_continue = 2)
                  BEGIN
                     UPDATE PICKDETAIL WITH (ROWLOCK)
                     SET PickSlipNo = @c_pickheaderkey
                       , TrafficCop = NULL
                     WHERE PickDetailKey = @c_PickDetailkey

                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                             , @n_err = 73001
                        SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                           + N': Update Failed On Table PICKDETAIL. (isp_RPT_LP_PLISTC_002)' + N' ( '
                                           + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '
                     END
                  END
               END

               FETCH NEXT FROM PickDet_cur
               INTO @c_PickDetailkey
                  , @c_orderkey
                  , @c_OrderLineNumber
            END

            CLOSE PickDet_cur
            DEALLOCATE PickDet_cur
         END -- Continue = 1

         FETCH NEXT FROM PickType_cur
         INTO @c_PickType
            , @c_PickZone
            , @c_Consigneekey
      END -- While : Get Pickslip#
      CLOSE PickType_cur
      DEALLOCATE PickType_cur
   END

   SET @c_OrderGrp = N''

   DECLARE C_OrdGrp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Loadkey
   FROM @t_Result
   ORDER BY Loadkey

   OPEN C_OrdGrp

   FETCH NEXT FROM C_OrdGrp
   INTO @c_RLoadkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @n_CntOrderGrp = COUNT(DISTINCT Ord.OrderGroup)
      FROM ORDERS Ord WITH (NOLOCK)
      WHERE Ord.LoadKey = @c_RLoadkey

      IF @n_CntOrderGrp = 1
      BEGIN
         SELECT @c_OrderGrp = ord.OrderGroup
         FROM ORDERS ord WITH (NOLOCK)
         WHERE ord.LoadKey = @c_RLoadkey
      END

      UPDATE @t_Result
      SET OrderGrp = @c_OrderGrp
      WHERE Loadkey = @c_RLoadkey

      FETCH NEXT FROM C_OrdGrp
      INTO @c_RLoadkey
   END
   CLOSE C_OrdGrp
   DEALLOCATE C_OrdGrp

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Assign Page No
      SET @c_PrevPickslipNo = N''
      SET @c_TotalPage = 0
      SET @n_PageNo = 1

      DECLARE C_PageNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Pickslipno
      FROM @t_Result
      ORDER BY Pickslipno
      OPEN C_PageNo

      FETCH NEXT FROM C_PageNo
      INTO @c_PickslipNo

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_PickslipNo <> @c_PrevPickslipNo
         BEGIN
            WHILE 1 = 1
            BEGIN
               IF NOT EXISTS (  SELECT 1
                                FROM @t_Result
                                WHERE Pickslipno = @c_PickslipNo AND PageNo = 0)
               BEGIN
                  SET ROWCOUNT 0
                  BREAK
               END

               SET ROWCOUNT 20

               UPDATE @t_Result
               SET PageNo = @n_PageNo
               WHERE Pickslipno = @c_PickslipNo AND PageNo = 0

               SET @n_PageNo = @n_PageNo + 1
               SET @c_TotalPage = @c_TotalPage + 1
               SET ROWCOUNT 0
            END -- end while 1=1
         END

         SET @c_PrevPickslipNo = @c_PickslipNo

         FETCH NEXT FROM C_PageNo
         INTO @c_PickslipNo
      END
      CLOSE C_PageNo
      DEALLOCATE C_PageNo

      -- Update Totalpage
      UPDATE @t_Result
      SET TotalPage = @c_TotalPage
      WHERE TotalPage = 0

      SELECT TOP 1 @c_Storerkey = ORDERS.StorerKey   --GTZ01
                 , @c_Facility = ORDERS.Facility   --GTZ01
      FROM LOADPLANDETAIL (NOLOCK)   --GTZ01
      JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = LOADPLANDETAIL.OrderKey   --GTZ01
      WHERE LOADPLANDETAIL.LoadKey = @c_Loadkey   --GTZ01

      SELECT @c_Lottable02label = Description
      FROM CODELKUP (NOLOCK)
      WHERE Code = 'Lottable02' AND LISTNAME = 'RPTCOLHDR' AND Storerkey = @c_Storerkey

      SELECT @c_Lottable04Label = Description
      FROM CODELKUP (NOLOCK)
      WHERE Code = 'Lottable04' AND LISTNAME = 'RPTCOLHDR' AND Storerkey = @c_Storerkey

      IF ISNULL(@c_Lottable02label, '') = ''
         SET @c_Lottable02label = N'Batch No'

      IF ISNULL(@c_Lottable04Label, '') = ''
         SET @c_Lottable04Label = 'Exp Date'

      IF ISNULL(@c_PreGenRptData, '') = ''
      BEGIN
         SELECT Loadkey
              , Pickslipno
              , PickType
              , [dbo].[fnc_ConvSFTimeZone](StorerKey, @c_Facility, LoadingDate) AS LoadingDate   --GTZ01
              , PickZone
              , Loc
              , Logicalloc
              , SKU
              , Descr
              , Palletcnt
              , Cartoncnt
              , TotalCarton
              , ID
              , Lottable02
              , [dbo].[fnc_ConvSFTimeZone](StorerKey, @c_Facility, Lottable04) AS Lottable04   --GTZ01
              , ReprintFlag
              , PageNo
              , TotalPage
              , rowid
              , SUSER_SNAME() AS Username
              , @c_Lottable02label AS Lottable02label
              , @c_Lottable04Label AS Lottable04label
              , C_Company
              , EA
              , Route
              , Storerkey
              , OrderGrpFlag
              , OrderGrp
              , TrfRoom
              , LEXTLoadKey
              , LPriority
              , [dbo].[fnc_ConvSFTimeZone](StorerKey, @c_Facility, LPuserdefDate01) AS LPuserdefDate01   --GTZ01
              , showfield
              , InnerPack
              , [dbo].[fnc_ConvSFTimeZone](StorerKey, @c_Facility, GETDATE()) AS CurrentDateTime   --GTZ01
         FROM @t_Result
         ORDER BY Pickslipno
                , PageNo
                , rowid
      END
   END

   EXIT_SP:
   IF @n_continue = 3 -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'Generation of Pick Slip'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END
END

GO
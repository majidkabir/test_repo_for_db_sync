SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure:isp_RPT_WV_WAVPLISTC_006                             */
/* Creation Date: 02-Mar-2023                                            */
/* Copyright: LFL                                                        */
/* Written by: Adarsh                                                    */
/*                                                                       */
/* Purpose: WMS-21785-Migrate WMS Report To LogiReport                   */
/*                                                                       */
/* Called By: RPT_WV_WAVPLISTC_006                                       */
/*                                                                       */
/* GitLab Version: 1.2                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 02-Mar-2023 WLChooi 1.0   DevOps Combine Script                       */
/* 10-Jul-2023 WLChooi 1.1   UWP-2584 - Bug Fix (WL01)                   */
/* 31-Oct-2023 WLChooi 1.2   UWP-10213 - Global Timezone (GTZ01)         */
/*************************************************************************/

CREATE   PROC [dbo].[isp_RPT_WV_WAVPLISTC_006]
(
   @c_Wavekey       NVARCHAR(10)
 , @c_PreGenRptData NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET NOCOUNT ON

   DECLARE @b_debug           INT
         , @n_StartTCnt       INT
         , @n_continue        INT
         , @b_success         INT
         , @n_err             INT
         , @c_errmsg          NVARCHAR(255)
         , @c_pickheaderkey   NVARCHAR(10)
         , @c_PickslipNo      NVARCHAR(10)
         , @c_PrintedFlag     NVARCHAR(1)
         , @c_PrevPickslipNo  NVARCHAR(10)
         , @c_PickUOM         NVARCHAR(5)
         , @c_PickZone        NVARCHAR(10)
         , @c_PickType        NVARCHAR(30)
         , @c_C_Company       NVARCHAR(45)
         , @d_LoadDate        DATETIME
         , @c_Loadkey         NVARCHAR(10)
         , @c_Orderkey        NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)
         , @c_PickDetailkey   NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @c_sku             NVARCHAR(20)
         , @c_SkuDescr        NVARCHAR(60)
         , @c_Loc             NVARCHAR(10)
         , @c_LogicalLoc      NVARCHAR(18)
         , @c_LocType         NVARCHAR(10)
         , @c_ID              NVARCHAR(18)
         , @c_Lottable02label NVARCHAR(30)
         , @c_Lottable04Label NVARCHAR(30)
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
         , @c_TrfRoom         NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)   --GTZ01

   --WL01 S
   --IF ISNULL(@c_PreGenRptData,'') IN ('0','')
   --SET @c_PreGenRptData = ''
   SET @c_PreGenRptData = IIF(@c_PreGenRptData = 'Y', 'Y', '')
   --WL01 E

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_continue = 1
   SET @b_debug = 0

   --GTZ01 S
   SELECT TOP 1 @c_Facility = OH.Facility
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
   WHERE WD.WaveKey = @c_Wavekey
   --GTZ01 E

   DECLARE @t_Result TABLE
   (
      Loadkey     NVARCHAR(10)
    , Pickslipno  NVARCHAR(10)
    , PickType    NVARCHAR(30)
    , LoadingDate DATETIME
    , PickZone    NVARCHAR(10)
    , C_Company   NVARCHAR(45)
    , Loc         NVARCHAR(10)
    , Logicalloc  NVARCHAR(18)
    , Storerkey   NVARCHAR(15)
    , SKU         NVARCHAR(20)
    , Descr       NVARCHAR(60)
    , Palletcnt   INT
    , Cartoncnt   INT
    , EA          INT
    , TotalCarton FLOAT
    , ID          NVARCHAR(18)
    , Lottable02  NVARCHAR(18)
    , Lottable04  DATETIME
    , ReprintFlag NVARCHAR(1)
    , PageNo      INT
    , TotalPage   INT
    , TrfRoom     NVARCHAR(10) NULL
    , rowid       INT          IDENTITY(1, 1)
   )

   DECLARE WAVE_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT LoadPlanDetail.LoadKey
   FROM WAVEDETAIL WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.OrderKey = ORDERS.OrderKey)
   JOIN LoadPlanDetail WITH (NOLOCK) ON (ORDERS.OrderKey = LoadPlanDetail.OrderKey)
   WHERE WAVEDETAIL.WaveKey = @c_Wavekey

   OPEN WAVE_CUR

   FETCH NEXT FROM WAVE_CUR
   INTO @c_Loadkey

   WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM PICKHEADER WITH (NOLOCK)
                   WHERE ExternOrderKey = @c_Loadkey AND Zone = 'LB')
         SET @c_PrintedFlag = N'Y'
      ELSE
         SET @c_PrintedFlag = N'N'

      BEGIN TRAN

      IF @c_PreGenRptData = 'Y'
      BEGIN
         UPDATE PICKHEADER WITH (ROWLOCK)
         SET PickType = '1'
           , TrafficCop = NULL
         WHERE ExternOrderKey = @c_Loadkey AND Zone = 'LB' AND PickType = '0'

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 73000
            SET @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + N': Update Failed On Table Pickheader Table. (isp_RPT_WV_WAVPLISTC_006)' + N' ( '
                            + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '
            GOTO EXIT_SP
         END
      END


      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         DECLARE pickslip_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LoadPlan.LoadKey
              , ISNULL(RTRIM(LOC.LocationType), '')
              , LoadPlan.AddDate
              , ISNULL(RTRIM(LOC.PickZone), '')
              , ISNULL(RTRIM(ORDERS.C_Company), '')
              , PICKDETAIL.Loc
              , ISNULL(RTRIM(LOC.LogicalLocation), '')
              , PICKDETAIL.Storerkey
              , PICKDETAIL.Sku
              , MAX(ISNULL(RTRIM(SKU.DESCR), ''))
              , PICKDETAIL.ID
              , ISNULL(RTRIM(LA.Lottable02), '')
              , ISNULL(LA.Lottable04, 1900 - 01 - 01)
              , ISNULL(PACK.Pallet, 0)
              , ISNULL(PACK.CaseCnt, 0)
              , SUM(PICKDETAIL.Qty)
              , LoadPlan.TrfRoom
         FROM PICKDETAIL WITH (NOLOCK)
         JOIN ORDERS WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERS.OrderKey)
         JOIN LoadPlanDetail WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey)
         JOIN LoadPlan WITH (NOLOCK) ON (LoadPlan.LoadKey = LoadPlanDetail.LoadKey)
         JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
         JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)
         JOIN PACK WITH (NOLOCK) ON (PACK.PackKey = SKU.PACKKey)
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PICKDETAIL.Lot = LA.Lot)
         WHERE LoadPlan.LoadKey = @c_Loadkey AND PICKDETAIL.Status < '5'
         GROUP BY LoadPlan.LoadKey
                , ISNULL(RTRIM(LOC.LocationType), '')
                , LoadPlan.AddDate
                , ISNULL(RTRIM(LOC.PickZone), '')
                , ISNULL(RTRIM(ORDERS.C_Company), '')
                , PICKDETAIL.Loc
                , ISNULL(RTRIM(LOC.LogicalLocation), '')
                , PICKDETAIL.Storerkey
                , PICKDETAIL.Sku
                , PICKDETAIL.ID
                , ISNULL(RTRIM(LA.Lottable02), '')
                , ISNULL(LA.Lottable04, 1900 - 01 - 01)
                , ISNULL(PACK.Pallet, 0)
                , ISNULL(PACK.CaseCnt, 0)
                , LoadPlan.TrfRoom
         ORDER BY ISNULL(RTRIM(LOC.PickZone), '')
                , ISNULL(RTRIM(LOC.LogicalLocation), '')
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
            , @c_Storerkey
            , @c_sku
            , @c_SkuDescr
            , @c_ID
            , @c_Lottable02
            , @d_Lottable04
            , @n_Pallet
            , @n_Casecnt
            , @n_Qty
            , @c_TrfRoom

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


            INSERT INTO @t_Result (Loadkey, Pickslipno, PickType, LoadingDate, PickZone, C_Company, Loc, Logicalloc
                                 , Storerkey, SKU, Descr, Palletcnt, Cartoncnt, EA, TotalCarton, ID, Lottable02
                                 , Lottable04, ReprintFlag, PageNo, TotalPage, TrfRoom)
            VALUES (@c_Loadkey, '', @c_PickType, @d_LoadDate, @c_PickZone, @c_C_Company, @c_Loc, @c_LogicalLoc
                  , @c_Storerkey, @c_sku, @c_SkuDescr, @n_Palletcnt, @n_Cartoncnt, @n_EA, @n_TotalCarton, @c_ID
                  , @c_Lottable02, @d_Lottable04, @c_PrintedFlag, 0, 0, @c_TrfRoom)

            FETCH NEXT FROM pickslip_cur
            INTO @c_Loadkey
               , @c_LocType
               , @d_LoadDate
               , @c_PickZone
               , @c_C_Company
               , @c_Loc
               , @c_LogicalLoc
               , @c_Storerkey
               , @c_sku
               , @c_SkuDescr
               , @c_ID
               , @c_Lottable02
               , @d_Lottable04
               , @n_Pallet
               , @n_Casecnt
               , @n_Qty
               , @c_TrfRoom
         END

         CLOSE pickslip_cur
         DEALLOCATE pickslip_cur
      END

      IF @b_debug = 1
      BEGIN
         SELECT *
         FROM @t_Result

         SELECT PickType
              , PickZone
         FROM @t_Result
         WHERE Pickslipno = ''
         GROUP BY PickType
                , PickZone
         ORDER BY CASE WHEN PickType = 'PICKING AREA' THEN '1'
                       WHEN PickType = 'FULL PALLET PICK' THEN '2'
                       ELSE '3' END
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         DECLARE PickType_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickType
              , PickZone
         FROM @t_Result
         WHERE Pickslipno = ''
         GROUP BY PickType
                , PickZone
         ORDER BY CASE WHEN PickType = 'PICKING AREA' THEN '1'
                       WHEN PickType = 'FULL PALLET PICK' THEN '2'
                       ELSE '3' END

         OPEN PickType_cur

         FETCH NEXT FROM PickType_cur
         INTO @c_PickType
            , @c_PickZone

         WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            SET @c_pickheaderkey = N''
            SET @c_Wavekey = ''

            IF @c_PickZone = 'BULK'
            BEGIN
               IF @c_PickType = 'FULL PALLET PICK'
               BEGIN
                  SELECT @c_pickheaderkey = PickHeaderKey
                  FROM PICKHEADER WITH (NOLOCK)
                  WHERE ExternOrderKey = @c_Loadkey AND WaveKey = RTRIM(@c_PickZone) + '_P' AND Zone = 'LB'

                  SET @c_Wavekey = RTRIM(@c_PickZone) + '_P'
               END
               ELSE
               BEGIN
                  SELECT @c_pickheaderkey = PickHeaderKey
                  FROM PICKHEADER WITH (NOLOCK)
                  WHERE ExternOrderKey = @c_Loadkey AND WaveKey = RTRIM(@c_PickZone) + '_C' AND Zone = 'LB'

                  SET @c_Wavekey = RTRIM(@c_PickZone) + '_C'
               END
            END
            ELSE
            BEGIN
               SELECT @c_pickheaderkey = PickHeaderKey
               FROM PICKHEADER WITH (NOLOCK)
               WHERE ExternOrderKey = @c_Loadkey AND WaveKey = @c_PickZone AND Zone = 'LB'

               SET @c_Wavekey = RTRIM(@c_PickZone)
            END

            IF ISNULL(RTRIM(@c_pickheaderkey), '') = '' AND @c_PreGenRptData = 'Y'
            BEGIN
               EXECUTE nspg_GetKey 'PICKSLIP'
                                 , 9
                                 , @c_pickheaderkey OUTPUT
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

               SET @c_pickheaderkey = N'P' + @c_pickheaderkey

               INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop, WaveKey)
               VALUES (@c_pickheaderkey, '', @c_Loadkey, '0', 'LB', '', @c_Wavekey)

               SET @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 73001
                  SET @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                  + N': Insert Failed On Table PICKHEADER. (isp_RPT_WV_WAVPLISTC_006)' + N' ( '
                                  + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '
                  GOTO EXIT_SP
               END
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               UPDATE @t_Result
               SET Pickslipno = @c_pickheaderkey
               WHERE Pickslipno = '' AND PickType = @c_PickType AND PickZone = @c_PickZone

               DECLARECURSOR_PickDet:
               IF @c_PickType = 'PICKING AREA'
               BEGIN
                  DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PICKDETAIL.PickDetailKey
                       , PICKDETAIL.OrderKey
                       , PICKDETAIL.OrderLineNumber
                  FROM PICKDETAIL WITH (NOLOCK)
                  JOIN LoadPlanDetail WITH (NOLOCK) ON (PICKDETAIL.OrderKey = LoadPlanDetail.OrderKey)
                  JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
                  WHERE LoadPlanDetail.LoadKey = @c_Loadkey
                  AND   (LOC.LocationType = 'CASE' OR LOC.LocationType = 'PICK' OR LOC.LocationType = 'PALLET')
                  AND   LOC.PickZone = @c_PickZone
                  AND   PICKDETAIL.Status < '5'
                  ORDER BY PickDetailKey
               END
               ELSE IF @c_PickType = 'FULL PALLET PICK'
               BEGIN
                  DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PICKDETAIL.PickDetailKey
                       , PICKDETAIL.OrderKey
                       , PICKDETAIL.OrderLineNumber
                  FROM PICKDETAIL WITH (NOLOCK)
                  JOIN LoadPlanDetail WITH (NOLOCK) ON (PICKDETAIL.OrderKey = LoadPlanDetail.OrderKey)
                  JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PICKDETAIL.Lot = LA.Lot)
                  JOIN @t_Result RESULT ON  (PICKDETAIL.Storerkey = RESULT.Storerkey)
                                        AND (PICKDETAIL.Sku = RESULT.SKU)
                                        AND (PICKDETAIL.Loc = RESULT.Loc)
                                        AND (PICKDETAIL.ID = RESULT.ID)
                                        AND (LA.Lottable02 = RESULT.Lottable02)
                                        AND (LA.Lottable04 = RESULT.Lottable04)
                  WHERE LoadPlanDetail.LoadKey = @c_Loadkey
                  AND   RESULT.PickType = 'FULL PALLET PICK'
                  AND   PICKDETAIL.Status < '5'
                  ORDER BY PickDetailKey
               END
               ELSE IF @c_PickType = 'CASE PICK'
               BEGIN
                  DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PICKDETAIL.PickDetailKey
                       , PICKDETAIL.OrderKey
                       , PICKDETAIL.OrderLineNumber
                  FROM PICKDETAIL WITH (NOLOCK)
                  JOIN LoadPlanDetail WITH (NOLOCK) ON (PICKDETAIL.OrderKey = LoadPlanDetail.OrderKey)
                  JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PICKDETAIL.Lot = LA.Lot)
                  JOIN @t_Result RESULT ON  (PICKDETAIL.Storerkey = RESULT.Storerkey)
                                        AND (PICKDETAIL.Sku = RESULT.SKU)
                                        AND (PICKDETAIL.Loc = RESULT.Loc)
                                        AND (PICKDETAIL.ID = RESULT.ID)
                                        AND (LA.Lottable02 = RESULT.Lottable02)
                                        AND (LA.Lottable04 = RESULT.Lottable04)
                  WHERE LoadPlanDetail.LoadKey = @c_Loadkey
                  AND   RESULT.PickType = 'CASE PICK'
                  AND   PICKDETAIL.Status < '5'
                  ORDER BY PickDetailKey
               END

               OPEN PickDet_cur
               SET @n_err = @@ERROR

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
                  , @c_Orderkey
                  , @c_OrderLineNumber

               WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2) AND @c_PreGenRptData = 'Y'
               BEGIN
                  IF NOT EXISTS (  SELECT 1
                                   FROM RefKeyLookup WITH (NOLOCK)
                                   WHERE PickDetailkey = @c_PickDetailkey)
                  BEGIN
                     INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                     VALUES (@c_PickDetailkey, @c_pickheaderkey, @c_Orderkey, @c_OrderLineNumber, @c_Loadkey)

                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_err = 73002
                        SET @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + N': Insert Failed On Table RefkeyLookup. (isp_RPT_WV_WAVPLISTC_006)' + N' ( '
                                        + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '
                        GOTO EXIT_SP
                     END

                     IF (@n_continue = 1 OR @n_continue = 2)
                     BEGIN
                        UPDATE PICKDETAIL WITH (ROWLOCK)
                        SET PickSlipNo = @c_pickheaderkey
                          , TrafficCop = NULL
                          , EditWho = SUSER_NAME()
                          , EditDate = GETDATE()
                        WHERE PickDetailKey = @c_PickDetailkey

                        IF @@ERROR <> 0
                        BEGIN
                           SET @n_continue = 3
                           SET @n_err = 73003
                           SET @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                           + N': Update Failed On Table PICKDETAIL. (isp_RPT_WV_WAVPLISTC_006)'
                                           + N' ( ' + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '
                           GOTO EXIT_SP
                        END
                     END
                  END

                  FETCH NEXT FROM PickDet_cur
                  INTO @c_PickDetailkey
                     , @c_Orderkey
                     , @c_OrderLineNumber
               END
               CLOSE PickDet_cur
               DEALLOCATE PickDet_cur
            END

            FETCH NEXT FROM PickType_cur
            INTO @c_PickType
               , @c_PickZone
         END
         CLOSE PickType_cur
         DEALLOCATE PickType_cur
      END

      COMMIT TRAN
      FETCH NEXT FROM WAVE_CUR
      INTO @c_Loadkey
   END
   CLOSE WAVE_CUR
   DEALLOCATE WAVE_CUR

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
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
            END
         END

         FETCH NEXT FROM C_PageNo
         INTO @c_PickslipNo
      END
      CLOSE C_PageNo
      DEALLOCATE C_PageNo

      UPDATE @t_Result
      SET TotalPage = @c_TotalPage
      WHERE TotalPage = 0

      SELECT TOP 1 @c_Storerkey = StorerKey
      FROM ORDERS WITH (NOLOCK)
      WHERE LoadKey = @c_Loadkey

      SELECT @c_Lottable02label = ISNULL(RTRIM(Description), '')
      FROM CODELKUP WITH (NOLOCK)
      WHERE Code = 'Lottable02' AND LISTNAME = 'RPTCOLHDR' AND Storerkey = @c_Storerkey

      SELECT @c_Lottable04Label = ISNULL(RTRIM(Description), '')
      FROM CODELKUP WITH (NOLOCK)
      WHERE Code = 'Lottable04' AND LISTNAME = 'RPTCOLHDR' AND Storerkey = @c_Storerkey

      IF ISNULL(@c_Lottable02label, '') = ''
         SET @c_Lottable02label = N'Batch No'

      IF ISNULL(@c_Lottable04Label, '') = ''
         SET @c_Lottable04Label = N'Exp Date'

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
              , @c_Lottable04Label AS Lottable04Label
              , C_Company
              , EA
              , TrfRoom
              , [dbo].[fnc_ConvSFTimeZone](StorerKey, @c_Facility, GETDATE()) AS CurrentDateTime   --GTZ01
         FROM @t_Result
         ORDER BY Pickslipno
                , PageNo
                , rowid
      END
   END

   EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'WAVE_CUR') IN ( 0, 1 )
   BEGIN
      CLOSE WAVE_CUR
      DEALLOCATE WAVE_CUR
   END

   IF CURSOR_STATUS('LOCAL', 'pickslip_cur') IN ( 0, 1 )
   BEGIN
      CLOSE pickslip_cur
      DEALLOCATE pickslip_cur
   END

   IF CURSOR_STATUS('LOCAL', 'PickType_cur') IN ( 0, 1 )
   BEGIN
      CLOSE PickType_cur
      DEALLOCATE PickType_cur
   END

   IF CURSOR_STATUS('LOCAL', 'PickDet_cur') IN ( 0, 1 )
   BEGIN
      CLOSE PickDet_cur
      DEALLOCATE PickDet_cur
   END


   IF @n_continue = 3
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'Generation of Pick Slip'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END

GO
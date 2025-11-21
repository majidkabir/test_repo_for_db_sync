SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: isp_GetPickSlipOrders104ikeaMulti_rpt                       */
/* Creation Date: 06-SEP-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose:  WMS-20604 - [CN] IKEA_Multi_PickSlip Report_CR             */
/*                                                                      */
/*        :                                                             */
/* Called By: r_dw_print_pickorder104_ikea_multi_rpt                    */
/*            duplicate from r_dw_print_pickorder104_multi_rpt          */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver   Purposes                                */
/* 06-SEP-2022  CSCHONG   1.0   Devops Scripts Combine                  */
/* 29-NOV-2022  Mingle    1.1   WMS-21188 Add new logic(ML01)           */
/* 31-Mar-2023  WLChooi   1.2   WMS-22101 Add new column (WL01)         */
/* 15-Aug-2023  WLChooi   1.3   WMS-23377 - Add new logic (WL02)        */
/************************************************************************/

CREATE   PROC [dbo].[isp_GetPickSlipOrders104ikeaMulti_rpt]
   @c_loadkey    NVARCHAR(10)
 , @c_batchkey   NVARCHAR(10) = ''
 , @c_Ordergroup NVARCHAR(20) = '' --ML01

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue    INT            = 1
         , @c_Zones       NVARCHAR(255)  = N''
         , @c_GetBatchkey NVARCHAR(10)   = N''
         , @n_StartTCnt   INT            = @@TRANCOUNT
         , @b_Success     INT            = 1
         , @n_err         INT            = 0
         , @c_ErrMsg      NVARCHAR(255)
         , @c_Storerkey   NVARCHAR(15)   = N'' --WL01
         , @c_ShowRoom    NVARCHAR(10)   = N'N' --WL01
         , @c_Room        NVARCHAR(50)   = N'' --WL01
         , @c_Notes2      NVARCHAR(4000) = N'' --WL01
         , @c_RptTitle    NVARCHAR(100)  = N'' --WL01

   DECLARE @n_MaxLine INT = 9
   DECLARE @c_Facility NVARCHAR(15) = N''

   DECLARE @n_ctnplatform INT

   SET @b_Success = 1
   SET @n_err = 0

   IF @c_batchkey = NULL
      SET @c_batchkey = ''
   IF @c_Ordergroup = NULL
      SET @c_Ordergroup = '' --ML01

   --START ML01
   IF EXISTS (  SELECT 1
                FROM LoadPlan (NOLOCK)
                WHERE LoadKey = @c_loadkey AND ISNULL(UserDefine10, '') NOT IN ( 'VPBATCH', '' ))
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 63920
      --SET @c_ErrMsg = 'Cannot print pickingslip report for this load now, waiting for Voice Picking return information. (isp_GetPickSlipOrders134Single_rpt) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      SET @c_ErrMsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                      + N': Cannot print pickingslip report for this load now, waiting for Voice Picking return information. (isp_GetPickSlipOrders134Single_rpt)'
      GOTO QUIT_SP
   END
   --END ML01

   --WL02 S
   --SELECT @n_ctnplatform = COUNT(DISTINCT ORD.ShipperKey)
   --FROM ORDERS ORD WITH (NOLOCK)
   --WHERE ORD.LoadKey = @c_loadkey

   SELECT @n_ctnplatform = COUNT(DISTINCT OIF.StoreName)
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERINFO OIF (NOLOCK) ON OIF.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_Loadkey
   --WL02 E

   CREATE TABLE #Temp_Zone
   (
      BatchKey NVARCHAR(10)
    , Descr    NVARCHAR(255)
   )

   CREATE TABLE #Temp_Result
   (
      Loadkey       NVARCHAR(10)
    , BatchKey      NVARCHAR(10)
    , TotalQty      INT
    , TotalSKU      INT
    , AllZones      NVARCHAR(255)
    , [Zone]        NVARCHAR(10)
    , Pickheaderkey NVARCHAR(10)
    , Orderkey      NVARCHAR(10)
    , Title         NVARCHAR(20)
    , ORDPlatform   NVARCHAR(30)
    , OrderGroup    NVARCHAR(20)
    , Remark        NVARCHAR(20)
    , Room          NVARCHAR(30) --WL01
   )

   CREATE TABLE #TEMP_ByBatch
   (
      Batchkey   NVARCHAR(10)
    , ShipperKey NVARCHAR(15)
   )

   --WL01 S
   DECLARE @t_Room TABLE
   (
      Loadkey    NVARCHAR(10) NULL
    , Orderkey   NVARCHAR(10) NULL
    , Pickslipno NVARCHAR(10) NULL
    , MaxRoom    NVARCHAR(30) NULL
   )

   SELECT @c_Facility = OH.Facility
        , @c_Storerkey = OH.StorerKey
   FROM LoadPlanDetail LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_loadkey
   --WL01 E

   IF NOT EXISTS (  SELECT 1
                    FROM CODELKUP (NOLOCK)
                    WHERE LISTNAME = 'IKEATITLE' AND code2 = @c_Facility)
   BEGIN
      GOTO QUIT_SP
   END
   ELSE --WL01 S
   BEGIN
      SELECT @c_Notes2 = ISNULL(CODELKUP.Notes2, '')
           , @c_RptTitle = ISNULL(CODELKUP.Notes, '')
      FROM CODELKUP (NOLOCK)
      WHERE LISTNAME = 'IKEATITLE' AND code2 = @c_Facility AND Storerkey = @c_Storerkey

      SELECT @c_ShowRoom = dbo.fnc_GetParamValueFromString('@c_ShowRoom', @c_Notes2, 'N')

      IF ISNULL(@c_RptTitle, '') = ''
         SET @c_RptTitle = N'IKEA SH CPU Picking Slip'
   END
   --WL01 E

   INSERT INTO #TEMP_ByBatch
   SELECT DISTINCT OH.OrderKey AS Batchkey     --WL02
                 , ISNULL(OIF.StoreName, '')   --WL02
   FROM ORDERS OH (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
   JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
   LEFT JOIN ORDERINFO OIF (NOLOCK) ON OIF.OrderKey = OH.OrderKey   --WL02
   WHERE LPD.LoadKey = @c_loadkey
   AND   OH.ECOM_SINGLE_Flag = 'M'
   AND   PD.PickSlipNo = CASE WHEN @c_batchkey = '' THEN PD.PickSlipNo
                              ELSE @c_batchkey END

   INSERT INTO #Temp_Zone
   SELECT DISTINCT PD.PickSlipNo
                 , ISNULL(LOC.Descr, '')
   FROM LoadPlanDetail LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
   JOIN LOC (NOLOCK) ON LOC.Loc = PD.Loc
   WHERE LPD.LoadKey = @c_loadkey AND PD.PickSlipNo = CASE WHEN @c_batchkey = '' THEN PD.PickSlipNo
                                                           ELSE @c_batchkey END

   --WL01 S
   INSERT INTO @t_Room (Loadkey, Orderkey, Pickslipno, MaxRoom)
   SELECT LPD.LoadKey
        , OH.OrderKey
        , PKD.PickSlipNo
        , MAX(LOC.LocationRoom)
   FROM LoadPlanDetail LPD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
   JOIN PICKDETAIL PKD WITH (NOLOCK) ON LPD.OrderKey = PKD.OrderKey
   JOIN LOC LOC WITH (NOLOCK) ON PKD.Loc = LOC.Loc
   WHERE LPD.LoadKey = @c_loadkey
   GROUP BY LPD.LoadKey
          , OH.OrderKey
          , PKD.PickSlipNo
   --WL01 E

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT BatchKey
   FROM #Temp_Zone
   ORDER BY BatchKey

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP
   INTO @c_GetBatchkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_Zones = STUFF((  SELECT ' + ' + RTRIM(Descr)
                                 FROM #Temp_Zone
                                 WHERE BatchKey = @c_GetBatchkey
                                 ORDER BY Descr
                                 FOR XML PATH(''))
                            , 1
                            , 1
                            , '')
      SELECT @c_Zones = SUBSTRING(@c_Zones, 3, LEN(@c_Zones))

      DELETE FROM #Temp_Zone
      WHERE BatchKey = @c_GetBatchkey

      INSERT INTO #Temp_Zone
      SELECT @c_GetBatchkey
           , @c_Zones

      FETCH NEXT FROM CUR_LOOP
      INTO @c_GetBatchkey
   END
   CLOSE CUR_LOOP --WL01
   DEALLOCATE CUR_LOOP --WL01

   INSERT INTO #Temp_Result
   SELECT OH.LoadKey
        , PD.PickSlipNo AS Batchkey
        --, SUM(PD.Qty) AS TotalQty
        , (  SELECT SUM(P.Qty)
             FROM PICKDETAIL P (NOLOCK)
             WHERE P.PickSlipNo = PD.PickSlipNo) AS TotalQty
        --, Count(Distinct(PD.SKU)) AS TotalSKU
        , (  SELECT COUNT(DISTINCT P.Sku)
             FROM PICKDETAIL P (NOLOCK)
             WHERE P.PickSlipNo = PD.PickSlipNo) AS TotalSKU
        , #Temp_Zone.Descr AS AllZones
        , CASE WHEN #Temp_Zone.Descr = 'T1' THEN '2'
               ELSE '1' END AS [Zone]
        , PH.PickHeaderKey
        , OH.OrderKey
        , CASE WHEN @n_ctnplatform > 1 THEN N''   --WL02
               WHEN ISNULL(CL.Long, '') = '' THEN N'(官网)'   --WL02
               ELSE '(' + LTRIM(RTRIM(ISNULL(CL.Long, ''))) + ')' END AS Title
        , CASE WHEN ISNULL(t1.Shipperkey, '') = '618' THEN N'天猫'   --WL02
               ELSE N'官网' END AS ORDPlatform
        , LPD.UserDefine05 AS Ordergroup --ML01
        , CASE WHEN OH.SpecialHandling = 'A' THEN 'Autopacking'
               ELSE '' END AS Remark --ML01
        , CASE WHEN @c_ShowRoom = 'Y' THEN MAX(TR.MaxRoom) --WL01
               ELSE '' END AS Room --WL01
   FROM ORDERS OH (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
   JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
   JOIN PICKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   LEFT JOIN #Temp_Zone ON #Temp_Zone.BatchKey = PD.PickSlipNo
   JOIN LoadPlan LP (NOLOCK) ON LP.LoadKey = LPD.LoadKey
   CROSS APPLY (  SELECT TOP 1 LTRIM(RTRIM(ISNULL(t.ShipperKey, ''))) AS Shipperkey
                  FROM #TEMP_ByBatch t
                  WHERE t.Batchkey = PD.Orderkey) AS t1   --WL02
   LEFT JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'IKEATITLE'
                                  AND CL.Code = t1.Shipperkey
                                  AND CL.Storerkey = OH.StorerKey
                                  AND CL.code2 = LP.facility
   JOIN @t_Room TR ON  TR.Loadkey = LPD.LoadKey --WL01
                   AND TR.Orderkey = LPD.OrderKey --WL01
                   AND TR.Pickslipno = PD.PickSlipNo --WL01
   WHERE LPD.LoadKey = @c_loadkey
   AND   OH.ECOM_SINGLE_Flag = 'M'
   AND   PD.PickSlipNo = CASE WHEN @c_batchkey = '' THEN PD.PickSlipNo
                              ELSE @c_batchkey END
   AND   LPD.UserDefine05 = CASE WHEN @c_Ordergroup = '' THEN LPD.UserDefine05
                                 ELSE @c_Ordergroup END --ML01
   GROUP BY OH.LoadKey
          , PD.PickSlipNo
          , #Temp_Zone.Descr
          , CASE WHEN #Temp_Zone.Descr = 'T1' THEN '2'
                 ELSE '1' END
          , PH.PickHeaderKey
          , OH.OrderKey
          , CASE WHEN @n_ctnplatform > 1 THEN N''   --WL02
                 WHEN ISNULL(CL.Long, '') = '' THEN N'(官网)'   --WL02
                 ELSE '(' + LTRIM(RTRIM(ISNULL(CL.Long, ''))) + ')' END
          , CASE WHEN ISNULL(t1.Shipperkey, '') = '618' THEN N'天猫'   --WL02
                 ELSE N'官网' END
          , LPD.UserDefine05 --ML01
          , CASE WHEN OH.SpecialHandling = 'A' THEN 'Autopacking'
                 ELSE '' END --ML01
   ORDER BY OH.LoadKey
          , PD.PickSlipNo
          , PH.PickHeaderKey
          , OH.OrderKey

   --WL01 S
   SELECT Loadkey
        , BatchKey
        , TotalQty
        , TotalSKU
        , AllZones
        , [Zone]
        , Pickheaderkey
        , Orderkey
        , @c_RptTitle + ' ' + Title AS Title
        , ORDPlatform
        , OrderGroup
        , Remark
        , (ROW_NUMBER() OVER (PARTITION BY Loadkey
                                         , BatchKey
                              ORDER BY Loadkey
                                     , BatchKey ASC) - 1) / @n_MaxLine AS RowNo
        , Room
        , @c_ShowRoom AS ShowRoom
   FROM #Temp_Result
   ORDER BY Loadkey
          , BatchKey
          , Pickheaderkey
          , Orderkey
   --WL01 E

   QUIT_SP:
   IF OBJECT_ID('tempdb..#Temp_Zone') IS NOT NULL
      DROP TABLE #Temp_Zone

   IF OBJECT_ID('tempdb..#Temp_Result') IS NOT NULL
      DROP TABLE #Temp_Result

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   --START ML01
   IF @n_Continue = 3 -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
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
      EXECUTE dbo.nsp_logerror @n_err
                             , @c_ErrMsg
                             , 'isp_GetPickSlipOrders134Single_rpt'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
--END ML01
END -- procedure

GO
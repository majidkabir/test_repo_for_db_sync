SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_011                          */
/* Creation Date: 29-JUN-2022                                           */
/* Copyright: IDS                                                       */
/* Written by: Mingle                                                   */
/*                                                                      */
/* Purpose: WMS-20214 TH-PUMA-CR-Wave Pick Slip                         */
/*                                                                      */
/* Called By: RCM - Generate Pickslip                                   */
/*          : Datawindow - RPT_WV_PLIST_WAVE_011                        */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver  Purposes                                   */
/* 29-JUN-2022  Mingle  1.0  DevOps Combine Script                      */
/* 11-Dec-2022  WLChooi 1.1  WMS-21327 - Show Pickslipno (WL01)         */
/************************************************************************/

CREATE PROC [dbo].[isp_RPT_WV_PLIST_WAVE_011]
(@c_wavekey NVARCHAR(13))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt INT
         , @n_Continue  INT
         , @b_Success   INT
         , @n_Err       INT
         , @c_Errmsg    NVARCHAR(255)

   DECLARE @c_Loadkey     NVARCHAR(10)
         , @c_PickSlipNo  NVARCHAR(10)
         , @c_RPickSlipNo NVARCHAR(10)
         , @c_PrintedFlag NVARCHAR(1)

   DECLARE @c_PickHeaderkey    NVARCHAR(10)
         , @c_Storerkey        NVARCHAR(15)
         , @c_ST_Company       NVARCHAR(45)
         , @c_Orderkey         NVARCHAR(10)
         , @c_PreOrderkey      NVARCHAR(10)
         , @c_OrderGroup       NVARCHAR(20)
         , @c_PAZone           NVARCHAR(10)
         , @c_PrevPAZone       NVARCHAR(10)
         , @n_NoOfLine         INT
         , @c_GetStorerkey     NVARCHAR(15)
         , @c_pickZone         NVARCHAR(10)
         , @c_PZone            NVARCHAR(10)
         , @n_MaxRow           INT
         , @n_RowNo            INT
         , @n_CntRowNo         INT
         , @c_OrdKey           NVARCHAR(20)
         , @c_OrdLineNo        NVARCHAR(5)
         , @c_GetWavekey       NVARCHAR(10)
         , @c_GetPickSlipNo    NVARCHAR(10)
         , @c_GetPickZone      NVARCHAR(10)
         , @c_GetOrdKey        NVARCHAR(20)
         , @c_GetLoadkey       NVARCHAR(10)
         , @c_PickDetailKey    NVARCHAR(18)
         , @c_GetPickDetailKey NVARCHAR(18)
         , @c_ExecStatement    NVARCHAR(4000)
         , @c_GetPHOrdKey      NVARCHAR(20)
         , @c_GetWDOrdKey      NVARCHAR(20)
         , @n_NoFilterDocType  INT
         , @n_ShowPickslipno   INT   --WL01

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @c_PickHeaderkey = N''
   SET @c_Storerkey = N''
   SET @c_ST_Company = N''
   SET @c_Orderkey = N''
   SET @c_PreOrderkey = N''
   SET @c_RPickSlipNo = N''
   SET @n_NoOfLine = 1
   SET @c_GetStorerkey = N''
   SET @n_CntRowNo = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TMP_PICK
   (
      PickSlipNo    NVARCHAR(10) NULL
    , LoadKey       NVARCHAR(10)
    , OrderKey      NVARCHAR(10)
    , OHUDF09       NVARCHAR(10) NULL
    , Qty           INT
    , PrintedFlag   NVARCHAR(1)  NULL
    , Storerkey     NVARCHAR(15) NULL
    , OrderGrp      NVARCHAR(20) NULL
    , Wavekey       NVARCHAR(10) NULL
    , GPAZone       NVARCHAR(10) NULL
    , PAZone        NVARCHAR(10) NULL
    , Pickdetailkey NVARCHAR(20) NULL
    , WUDF01        NVARCHAR(10) NULL
   )

   SELECT TOP 1 @c_GetStorerkey = ORD.StorerKey
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS ORD WITH (NOLOCK) ON WD.OrderKey = ORD.OrderKey
   WHERE WD.WaveKey = @c_wavekey

   SELECT @n_NoFilterDocType = ISNULL(MAX(CASE WHEN CL.Code = 'NoFilterDocType' THEN 1
                                               ELSE 0 END)
                                    , 0)
        , @n_ShowPickslipno = ISNULL(MAX(CASE WHEN CL.Code = 'ShowPickslipno' THEN 1   --WL01
                                              ELSE 0 END)                              --WL01
                                   , 0)                                                --WL01
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'REPORTCFG'
   AND   CL.Long = 'RPT_WV_PLIST_WAVE_011'
   AND   (CL.Short IS NULL OR CL.Short <> 'N')
   AND   CL.Storerkey = @c_GetStorerkey

   INSERT INTO #TMP_PICK (PickSlipNo, LoadKey, OrderKey, OHUDF09, Qty, PrintedFlag, Storerkey, OrderGrp, Wavekey
                        , GPAZone, PAZone, Pickdetailkey, WUDF01)
   SELECT DISTINCT RefKeyLookup.Pickslipno
                 , ORDERS.LoadKey AS LoadKey
                 , ORDERS.OrderKey AS Orderkey
                 , ISNULL(ORDERS.UserDefine09, '') AS OHUDF09
                 , SUM(PICKDETAIL.Qty) AS Qty
                 , ISNULL((  SELECT DISTINCT 'Y'
                             FROM PICKDETAIL WITH (NOLOCK)
                             WHERE PICKDETAIL.PickSlipNo = RefKeyLookup.Pickslipno)
                        , 'N') AS PrintedFlag
                 , ORDERS.StorerKey
                 --ORDERS.OrderGroup,                                               
                 , CASE ORDERS.ECOM_SINGLE_Flag
                        WHEN 'M' THEN 'MULTI'
                        WHEN 'S' THEN 'SINGLE'
                        ELSE ORDERS.ECOM_SINGLE_Flag END
                 , WD.WaveKey
                 , UPPER(SUBSTRING(LOC.PickZone, 1, 2)) AS GPAZone
                 , LOC.PickZone AS PAZone
                 , PICKDETAIL.PickDetailKey
                 , ISNULL(WAVE.UserDefine01, '') AS WUDF01
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN WAVE WITH (NOLOCK) ON WAVE.WaveKey = WD.WaveKey
   JOIN PICKDETAIL WITH (NOLOCK) ON PICKDETAIL.OrderKey = WD.OrderKey
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON PICKHEADER.ExternOrderKey = PICKDETAIL.PickSlipNo
   JOIN ORDERS WITH (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey
   JOIN LOC WITH (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
   LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailkey = PICKDETAIL.PickDetailKey)
   WHERE WD.WaveKey = @c_wavekey AND (ORDERS.DocType = 'E' OR @n_NoFilterDocType = 1)
   GROUP BY RefKeyLookup.Pickslipno
          , ORDERS.LoadKey
          , ORDERS.OrderKey
          , ISNULL(ORDERS.UserDefine09, '')
          , ORDERS.StorerKey
          --ORDERS.OrderGroup,                                                
          , CASE ORDERS.ECOM_SINGLE_Flag
                 WHEN 'M' THEN 'MULTI'
                 WHEN 'S' THEN 'SINGLE'
                 ELSE ORDERS.ECOM_SINGLE_Flag END
          , WD.WaveKey
          , UPPER(SUBSTRING(LOC.PickZone, 1, 2))
          , LOC.PickZone
          , PICKDETAIL.PickDetailKey
          , ISNULL(WAVE.UserDefine01, '')
   ORDER BY PICKDETAIL.PickDetailKey
          , ORDERS.OrderKey
          , LOC.PickZone

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SET @c_Orderkey = N''
   SET @c_PreOrderkey = N''
   SET @c_pickZone = N''
   SET @c_PrevPAZone = N''
   SET @c_PickDetailKey = N''
   SET @n_Continue = 1

   DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT LoadKey
                 , OrderKey
                 , PAZone
                 , Pickdetailkey
   FROM #TMP_PICK
   WHERE ISNULL(PickSlipNo, '') = ''
   ORDER BY PAZone
          , Pickdetailkey

   OPEN CUR_LOAD

   FETCH NEXT FROM CUR_LOAD
   INTO @c_Loadkey
      , @c_Orderkey
      , @c_PZone
      , @c_GetPickDetailKey

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF ISNULL(@c_Orderkey, '0') = '0'
         BREAK

      IF @c_PrevPAZone <> @c_PZone --AND NOT EXISTS (SELECT 1 FROM dbo.PICKHEADER (NOLOCK) WHERE orderkey = @c_Orderkey)          
      --IF @c_PreOrderkey <> @c_Orderkey  
      --IF NOT EXISTS (SELECT 1 FROM dbo.PICKHEADER (NOLOCK) WHERE consoorderkey = @c_PZone AND Wavekey = @c_wavekey AND LoadKey = @c_Loadkey)      
      BEGIN
         --IF NOT EXISTS (SELECT 1 FROM dbo.PICKHEADER (NOLOCK) WHERE Wavekey = @c_wavekey AND orderkey = @c_Orderkey)  
         --BEGIN                   
         SET @c_RPickSlipNo = N''

         EXECUTE nspg_GetKey 'PICKSLIP'
                           , 9
                           , @c_RPickSlipNo OUTPUT
                           , @b_Success OUTPUT
                           , @n_Err OUTPUT
                           , @c_Errmsg OUTPUT

         IF @b_Success = 1
         BEGIN
            SET @c_RPickSlipNo = N'P' + @c_RPickSlipNo

            --SELECT @c_PrevPAZone '@c_PrevPAZone',@c_PZone '@c_PZone', @c_RPickSlipNo '@c_RPickSlipNo'  

            INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, OrderKey, ExternOrderKey, LoadKey, PickType, Zone
                                  , ConsoOrderKey, TrafficCop)
            VALUES (@c_RPickSlipNo, @c_wavekey, '', @c_RPickSlipNo, @c_Loadkey, '0', 'LP', @c_PZone, '')

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Errmsg = CONVERT(NVARCHAR(250), @n_Err)
               SET @n_Err = 81008 -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
               SET @c_Errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                               + N': Insert PICKHEADER Failed (isp_RPT_WV_PLIST_WAVE_011)' + N' ( '
                               + N' SQLSvr MESSAGE=' + RTRIM(@c_Errmsg) + N' ) '
               GOTO QUIT
            END
         END
         ELSE
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 63502
            SELECT @c_Errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                               + N': Get PSNO Failed. (isp_RPT_WV_PLIST_WAVE_011)'
            BREAK
         END
      --END          
      END

      IF @n_Continue = 1
      BEGIN
         DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PICKDETAIL.PickDetailKey
              , PICKDETAIL.OrderLineNumber
         FROM PICKDETAIL WITH (NOLOCK)
         JOIN ORDERDETAIL WITH (NOLOCK) ON (   PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey
                                           AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
         JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
         WHERE PICKDETAIL.PickDetailKey = @c_GetPickDetailKey
         AND   ORDERDETAIL.LoadKey = @c_Loadkey
         AND   LOC.PickZone = RTRIM(@c_PZone)
         ORDER BY PICKDETAIL.PickDetailKey

         OPEN C_PickDetailKey
         FETCH NEXT FROM C_PickDetailKey
         INTO @c_PickDetailKey
            , @c_OrdLineNo

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF NOT EXISTS (  SELECT 1
                             FROM RefKeyLookup WITH (NOLOCK)
                             WHERE PickDetailkey = @c_PickDetailKey)
            BEGIN
               INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
               VALUES (@c_PickDetailKey, @c_RPickSlipNo, @c_Orderkey, @c_OrdLineNo, @c_Loadkey)

               SELECT @n_Err = @@ERROR
               IF @n_Err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_Err = 63503
                  SELECT @c_Errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                     + N': Insert RefKeyLookup Failed. (isp_RPT_WV_PLIST_WAVE_011)'
                  GOTO QUIT
               END
            END

            FETCH NEXT FROM C_PickDetailKey
            INTO @c_PickDetailKey
               , @c_OrdLineNo
         END
         CLOSE C_PickDetailKey
         DEALLOCATE C_PickDetailKey
      END

      UPDATE #TMP_PICK
      SET PickSlipNo = @c_RPickSlipNo
      WHERE OrderKey = @c_Orderkey
      AND   PAZone = @c_PZone
      AND   ISNULL(PickSlipNo, '') = ''
      AND   Pickdetailkey = @c_GetPickDetailKey

      SELECT @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 63504
         SELECT @c_Errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                            + N': Update #TMP_PICK Failed. (isp_RPT_WV_PLIST_WAVE_011)'
         GOTO QUIT
      END

      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET PickSlipNo = @c_RPickSlipNo
        , EditWho = SUSER_NAME()
        , EditDate = GETDATE()
        , TrafficCop = NULL
      FROM ORDERS OH WITH (NOLOCK)
      JOIN PICKDETAIL PD ON (OH.OrderKey = PD.OrderKey)
      JOIN LOC L ON L.Loc = PD.Loc
      WHERE PD.OrderKey = @c_Orderkey
      AND   L.PickZone = @c_PZone
      AND   ISNULL(PickSlipNo, '') = ''
      AND   PickDetailKey = @c_GetPickDetailKey

      SET @n_Err = @@ERROR

      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_Errmsg = CONVERT(NVARCHAR(250), @n_Err)
         SET @n_Err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
         SET @c_Errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                         + N': UPDATE Pickdetail Failed (isp_RPT_WV_PLIST_WAVE_011)' + N' ( ' + N' SQLSvr MESSAGE='
                         + RTRIM(@c_Errmsg) + N' ) '
         GOTO QUIT
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      -- SET @c_RPickSlipNo = ''     
      SET @c_PrevPAZone = @c_PZone
      --SET @c_PreOrderkey = @c_Orderkey  

      FETCH NEXT FROM CUR_LOAD
      INTO @c_Loadkey
         , @c_Orderkey
         , @c_PZone
         , @c_GetPickDetailKey
   END
   CLOSE CUR_LOAD
   DEALLOCATE CUR_LOAD

   DECLARE CUR_WaveOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT WD.WaveKey
                 , LPD.LoadKey
                 , ''
                 , WD.OrderKey
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (WD.OrderKey = LPD.OrderKey)
   JOIN PICKDETAIL AS PDET ON PDET.OrderKey = WD.OrderKey
   JOIN LOC L WITH (NOLOCK) ON L.Loc = PDET.Loc
   WHERE WD.WaveKey = @c_wavekey

   OPEN CUR_WaveOrder

   FETCH NEXT FROM CUR_WaveOrder
   INTO @c_GetWavekey
      , @c_GetLoadkey
      , @c_GetPHOrdKey
      , @c_GetWDOrdKey

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN

      IF NOT EXISTS (  SELECT 1
                       FROM PICKHEADER (NOLOCK)
                       WHERE WaveKey = @c_wavekey AND OrderKey = @c_GetWDOrdKey)
      BEGIN
         BEGIN TRAN
         EXECUTE nspg_GetKey 'PICKSLIP'
                           , 9
                           , @c_PickSlipNo OUTPUT
                           , @b_Success OUTPUT
                           , @n_Err OUTPUT
                           , @c_Errmsg OUTPUT

         SET @c_PickSlipNo = N'P' + @c_PickSlipNo


         --SELECT @c_GetWDOrdKey '@c_GetWDOrdKey', @c_Pickslipno '@c_Pickslipno'  

         INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, OrderKey, ExternOrderKey, LoadKey, PickType, Zone
                               , ConsoOrderKey, TrafficCop)
         VALUES (@c_PickSlipNo, @c_wavekey, @c_GetWDOrdKey, @c_PickSlipNo, @c_GetLoadkey, '0', '3', '', '')

         SET @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_Errmsg = CONVERT(NVARCHAR(250), @n_Err)
            SET @n_Err = 81008 -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
            SET @c_Errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                            + N': Insert PICKHEADER Failed (isp_RPT_WV_PLIST_WAVE_011)' + N' ( ' + N' SQLSvr MESSAGE='
                            + RTRIM(@c_Errmsg) + N' ) '
            GOTO QUIT
         END
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      FETCH NEXT FROM CUR_WaveOrder
      INTO @c_GetWavekey
         , @c_GetLoadkey
         , @c_GetPHOrdKey
         , @c_GetWDOrdKey
   END
   CLOSE CUR_WaveOrder
   DEALLOCATE CUR_WaveOrder

   --SELECT * FROM #TMP_PICK                                                  

   GOTO QUIT

   QUIT:


   IF @n_Continue = 3 -- Error Occured - Process And Return      
   BEGIN
      IF @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_Err, @c_Errmsg, 'isp_RPT_WV_PLIST_WAVE_011'
   END


   SELECT #TMP_PICK.PickSlipNo
        , #TMP_PICK.Wavekey
        , SUM(#TMP_PICK.Qty) AS Qty
        , #TMP_PICK.Storerkey
        , #TMP_PICK.OrderGrp
        , #TMP_PICK.OHUDF09
        , #TMP_PICK.GPAZone
        , #TMP_PICK.PAZone
        , #TMP_PICK.WUDF01
        , @n_ShowPickslipno AS ShowPickslipno   --WL01
   FROM #TMP_PICK
   GROUP BY #TMP_PICK.PickSlipNo
          , #TMP_PICK.Wavekey
          , #TMP_PICK.Storerkey
          , #TMP_PICK.OrderGrp
          , #TMP_PICK.GPAZone
          , #TMP_PICK.PAZone
          , #TMP_PICK.OHUDF09
          , #TMP_PICK.WUDF01
   --ORDER BY #TMP_PICK.PickSlipNo,#TMP_PICK.GPAZone,#TMP_PICK.PAZone     --CS02  
   ORDER BY #TMP_PICK.GPAZone
          , #TMP_PICK.PAZone --CS02  

   --SELECT '1' AS PickSlipNo  

   DROP TABLE #TMP_PICK



   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   RETURN
END

GO
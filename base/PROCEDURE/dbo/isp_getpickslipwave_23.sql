SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store Procedure: isp_GetPickSlipWave_23                              */
/* Creation Date: 02-Jun-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-13575 - JP_Desigual_B2B Consolidate Picking List        */
/*                                                                      */
/* Input Parameters: @c_LoadKey  - (Wavekey)                            */
/*                                                                      */
/* Output Parameters: None                                              */
/*                                                                      */
/* Return Status: Report                                                */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: r_dw_print_wave_pickslip_23                               */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 28-Dec-2020  CSCHONG   1.1   WMS-15909 add new field (CS01)          */
/* 20-Jun-2023  CSCHONG   1.2   Devops Scripts Combine & WMS-22794 (CS02)*/
/************************************************************************/

CREATE   PROC [dbo].[isp_GetPickSlipWave_23]
            (@c_WaveKey NVARCHAR(10), @c_Type NVARCHAR(10) = '')
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTranCnt   INT
         , @n_continue       INT
         , @n_err            INT
         , @b_Success        INT
         , @c_errmsg         NVARCHAR(255)
         , @c_PickHeaderKey  NVARCHAR(10)
         , @c_PrintedFlag    NVARCHAR(1)
         , @c_Loadkey        NVARCHAR(10)
         , @n_CtnOrder       INT                --CS01
         , @n_TTLQTY         INT                --CS01
         , @c_VASCode        NVARCHAR(20)       --CS01

   SET @n_StartTranCnt  = @@TRANCOUNT
   SET @n_Continue      = 1
   SET @n_err           = 0
   SET @b_Success       = 1
   SET @c_errmsg        = ''
   SET @c_PickHeaderKey = ''
   SET @c_PrintedFlag   = 'N'
   SET @n_CtnOrder      = 1                   --CS01
   SET @n_TTLQTY        = 1                   --CS01

   IF ISNULL(@c_Type,'') = '' SET @c_Type = ''

   IF @c_Type = 'H'
   BEGIN
      SELECT '1', @c_WaveKey
      UNION ALL
      SELECT '2', @c_WaveKey
   END
   ELSE IF @c_Type = 'Barcode'
   BEGIN
      CREATE TABLE #TMP_STG1 (
         RowID      INT NOT NULL identity(1,1),
         Orderkey   NVARCHAR(100)
      )

      CREATE TABLE #TMP_STG2 (
         RowID      INT NOT NULL identity(1,1),
         Orderkey   NVARCHAR(100)
      )

      --CS01 START
     CREATE TABLE #TMP_STG3 (
         RowID      INT NOT NULL identity(1,1),
         Orderkey   NVARCHAR(100),
         Wavekey    NVARCHAR(10),
         ExtOrdKey  NVARCHAR(50),
         VASCODE    NVARCHAR(2500),
         OHNotes    NVARCHAR(2500)

      )
      --CS01 END

      INSERT INTO #TMP_STG1
      SELECT DISTINCT LTRIM(RTRIM(Orderkey))
      FROM WAVEDETAIL (NOLOCK)
      WHERE Wavekey = @c_Wavekey --IN ('0000000021','0000000022','0000000027','0000000031','0000000032','0000000033','0000000034','0000000037')
      ORDER BY LTRIM(RTRIM(Orderkey))

      --WHILE(EXISTS(SELECT 1 FROM #TMP_STG1) )
      --BEGIN
      --   INSERT #TMP_STG2
      --   SELECT CAST(STUFF((SELECT TOP 3 ',' + RTRIM(a.Orderkey) FROM #TMP_STG1 a ORDER BY RowID FOR XML PATH('')),1,1,'' ) AS NVARCHAR(250)) AS Orderkey

      --   DELETE TOP (3) FROM #TMP_STG1
      --END

       SET @c_VASCode = ''

       SELECT TOP 1 @c_VASCode = RTRIM(OH.BuyerPO)--RTRIM(OD.userdefine01) + '-' + RTRIM(OD.Userdefine02) + '-' + RTRIM(OD.notes)   --CS02
       FROM  #TMP_STG1 STG1
       JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = STG1.Orderkey
       JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.OrderKey

      SELECT DISTINCT LTRIM(RTRIM(STG1.Orderkey)) AS Orderkey, OH.ExternOrderKey as ExtOrdkey,OH.userdefine03 AS OHNotes , @c_VASCode as VASCODE,@c_WaveKey as wavekey  --CS02
                     , 'Ext Order Key : ' as extordkeyfield , 'Address Code : ' as Addcodefield, 'Buyer PO : ' as vascodefield     --CS02
      FROM #TMP_STG1 STG1
      JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = STG1.Orderkey
      --JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.OrderKey
      ORDER BY LTRIM(RTRIM(STG1.Orderkey))

      GOTO QUIT_SP
   END

   CREATE TABLE #TEMP_Load (
      Loadkey       NVARCHAR(10),
      Pickheaderkey NVARCHAR(10),
      PrintedFlag   NVARCHAR(1)
   )

   INSERT INTO #TEMP_Load
   SELECT DISTINCT LPD.Loadkey, ISNULL(PH.Pickheaderkey,''), CASE WHEN ISNULL(PH.Pickheaderkey,'') = '' THEN 'N' ELSE 'Y' END AS PrintedFlag
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON WD.Orderkey = LPD.Orderkey
   LEFT JOIN PICKHEADER PH (NOLOCK) ON PH.Loadkey = LPD.Loadkey
   WHERE WD.Wavekey = @c_WaveKey

   --CS01 START


   SELECT @n_CtnOrder  = COUNT(DISTINCT Orderkey)
   FROM WAVEDETAIL WITH (NOLOCK)
   WHERE wavekey = @c_WaveKey

   SELECT @n_TTLQTY = SUM(PickDetail.Qty)
   FROM PickHeader WITH (NOLOCK)
   INNER JOIN LoadPlan WITH (NOLOCK) ON  (LoadPlan.LoadKey = PICKHEADER.ExternOrderKey)
   INNER JOIN LoadPlanDetail WITH (NOLOCK) ON  (LoadPlanDetail.LoadKey = LoadPlan.LoadKey)
   INNER JOIN PickDetail WITH (NOLOCK) ON  (PickDetail.OrderKey = LoadPlanDetail.OrderKey)
   INNER JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WD.Orderkey = Pickdetail.Orderkey)
   WHERE  WD.WaveKey = @c_Wavekey
   AND    PickDetail.QTY > 0

   --CS01 END

   BEGIN TRAN

   IF EXISTS (SELECT TOP 1 1 FROM #TEMP_Load WHERE PrintedFlag = 'Y')
   BEGIN
      SET @c_PrintedFlag = 'Y'

      DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Loadkey, Pickheaderkey FROM #TEMP_Load

      OPEN CUR_PSLIP

      FETCH NEXT FROM CUR_PSLIP INTO @c_Loadkey, @c_Pickheaderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE PICKHEADER WITH (ROWLOCK)
         SET PickType = '1'
            ,EditWho = SUSER_NAME()
            ,EditDate= GETDATE()
            ,TrafficCop = NULL
         FROM PICKHEADER
         WHERE PickHeaderKey = @c_PickHeaderKey

         FETCH NEXT FROM CUR_PSLIP INTO @c_Loadkey, @c_Pickheaderkey
      END
   END
   ELSE
   BEGIN
      EXEC isp_CreatePickSlip
         @c_Wavekey           = @c_Wavekey
       , @c_PickslipType      = '7'
       , @c_ConsolidateByLoad = 'Y'
       , @b_Success           = @b_Success OUTPUT
       , @n_Err               = @n_Err     OUTPUT
       , @c_ErrMsg            = @c_ErrMsg  OUTPUT

      IF @n_Err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63400
         SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                       + ': Create Pickslip Failed. (isp_GetPickSlipWave_23)'
         GOTO QUIT_SP
      END
   END

   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      IF @@TRANCOUNT >= 1
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
      ELSE
      BEGIN
         SELECT @n_continue = 3
         ROLLBACK TRAN
      END
   END

   --0000020943

   /* Start Modification */
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order

   /*IF NOT EXISTS(
                 SELECT PickHeaderKey
                 FROM   PICKHEADER WITH (NOLOCK)
                 WHERE  ExternOrderKey = @c_LoadKey
                 AND    Zone = '7'
                )
   BEGIN
      SET @b_success = 0

      EXECUTE nspg_GetKey
            'PICKSLIP'
          , 9
          , @c_PickHeaderKey  OUTPUT
          , @b_success        OUTPUT
          , @n_err            OUTPUT
          , @c_errmsg         OUTPUT

      IF @b_success<>1
      BEGIN
         SET @n_continue = 3
         GOTO QUIT_SP
      END

      SET @c_PickHeaderKey = 'P' + @c_PickHeaderKey

      INSERT INTO PICKHEADER
        (PickHeaderKey ,ExternOrderKey,PickType,Zone)
      VALUES
        (@c_PickHeaderKey,@c_LoadKey,'1','7')

      SET @n_err = @@ERROR

      IF @n_err<>0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63501
         SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                       + ': Insert Into PICKHEADER Failed. (isp_GetPickSlipWave_23)'
         GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
      SELECT @c_PickHeaderKey = PickHeaderKey
      FROM   PickHeader WITH (NOLOCK)
      WHERE  ExternOrderKey = @c_LoadKey
      AND    Zone = '7'

      SET @c_PrintedFlag = 'Y'
   END

   IF ISNULL(RTRIM(@c_PickHeaderKey) ,'')=''
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63502
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)
                   + ': Get LoadKey Failed. (isp_GetPickSlipWave_23)'
      GOTO QUIT_SP
   END  */

   SELECT  ISNULL(RTRIM(PickHeader.PickHeaderKey),'')
        , @c_PrintedFlag
        , ISNULL(RTRIM(WD.Wavekey),'')
        , LoadPlan.LPUserdefDate01
        , ISNULL(RTRIM(LoadPlan.Route),'')
        , ISNULL(RTRIM(LoadPlan.TrfRoom),'')
        , ISNULL(RTRIM(PickDetail.Storerkey),'')
        , ISNULL(RTRIM(Storer.Company),'')
        , ISNULL(RTRIM(PickDetail.Sku),'')
        , ISNULL(RTRIM(PickDetail.Loc),'')
        , ISNULL(PickDetail.Qty,0)
        , ISNULL(RTRIM(SKU.Descr),'')
        , ISNULL(RTRIM(SKU.AltSku),'')
        , ISNULL(RTRIM(SKU.ManufacturerSKU),'')
        , ISNULL(SKU.StdCube,0.0)
        , ISNULL(SKU.StdGrossWgt,0.0)
        , ISNULL(PACK.CaseCnt,0.0)
        , ISNULL(PACK.InnerPack,0.0)
        , CASE IsDate(LotAttribute.Lottable01) WHEN 1 THEN CONVERT( Datetime, LotAttribute.Lottable01)
                                               ELSE NULL
                                               END
        , ISNULL(RTRIM(LotAttribute.Lottable02),'')
        , ISNULL(RTRIM(LotAttribute.Lottable03),'')
        , ISNULL(LotAttribute.Lottable04,'01/01/1900')
        , ISNULL(RTRIM(L.PutawayZone),'')
        , ISNULL(RTRIM(Z.Descr),'')
        , ISNULL(RTRIM(PACK.PackUOM1),'')
        , ISNULL(RTRIM(PACK.PackUOM2),'')
        , ISNULL(RTRIM(PACK.PackUOM3),'')
        , UPPER(ISNULL(RTRIM(L.PickZone),''))
        , ISNULL(RTRIM(LoadPlan.Loadkey),'') as Loadkey
        , @n_CtnOrder AS TTLORD
        , @n_TTLQTY AS PTTLQTY
        , ISNULL(PACK.qty,0.0) AS Packqty            --CS02
   FROM PickHeader WITH (NOLOCK)
   INNER JOIN LoadPlan WITH (NOLOCK) ON  (LoadPlan.LoadKey = PICKHEADER.ExternOrderKey)
   INNER JOIN LoadPlanDetail WITH (NOLOCK) ON  (LoadPlanDetail.LoadKey = LoadPlan.LoadKey)
   INNER JOIN PickDetail WITH (NOLOCK) ON  (PickDetail.OrderKey = LoadPlanDetail.OrderKey)
   INNER JOIN Storer WITH (NOLOCK) ON  (Storer.Storerkey = PickDetail.Storerkey)
   INNER JOIN SKU WITH (NOLOCK) ON  (SKU.StorerKey = PickDetail.Storerkey) AND   (SKU.Sku = PickDetail.Sku)
   INNER JOIN PACK WITH (NOLOCK) ON  (PACK.PackKey = SKU.Packkey)
   INNER JOIN LotAttribute WITH (NOLOCK) ON  (LotAttribute.LOT = PickDetail.LOT)
   INNER JOIN LOC L WITH (NOLOCK) ON  (L.Loc = PickDetail.Loc)
   INNER JOIN PutawayZone Z WITH (NOLOCK) ON  (Z.PutawayZone = L.PutawayZone)
   INNER JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WD.Orderkey = Pickdetail.Orderkey)
   WHERE  WD.WaveKey = @c_Wavekey
   AND    PickDetail.QTY > 0
   ORDER BY ISNULL(RTRIM(LoadPlan.Loadkey),'')
          , UPPER(ISNULL(RTRIM(L.PickZone),''))   --ISNULL(RTRIM(L.PutawayZone),'')
          , ISNULL(RTRIM(PickDetail.Loc),'')
          , ISNULL(RTRIM(PickDetail.Sku),'')
          , ISNULL(RTRIM(LotAttribute.Lottable01),'')
          , ISNULL(RTRIM(LotAttribute.Lottable02),'')
          , ISNULL(LotAttribute.Lottable04,'01/01/1900')
          , ISNULL(RTRIM(LotAttribute.Lottable03),'')

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_STG1') IS NOT NULL
      DROP TABLE #TMP_STG1

   IF OBJECT_ID('tempdb..#TMP_STG2') IS NOT NULL
      DROP TABLE #TMP_STG2

   IF @n_continue=3 -- Error Occured - Process And Return
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave_23'
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_008_1                           */
/* Creation Date: 01-Sep-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-20000 - Convert to Logi Report -                           */
/*                      r_dw_print_wave_pickslip_26_1 (KR)                 */
/*          WMS-23483 - [KR] ADIDAS_Picking Slip Report Data Window_CR     */
/*                                                                         */
/* Called By: RPT_WV_PLIST_WAVE_008_1                                      */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 01-Sep-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_008_1]
   @c_Wavekey       NVARCHAR(10)
 , @c_PickSlipNo    NVARCHAR(10)
 , @c_Zone          NVARCHAR(10)
 , @c_PrintedFlag   NCHAR(1)
 , @n_NoOfSku       INT
 , @n_NoOfPickLines INT
 , @c_ordselectkey  NVARCHAR(20)
 , @c_colorcode     NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt    INT
         , @n_Continue     INT
         , @n_WaveSeqOfDay INT
         , @dt_Adddate     DATETIME
         , @d_Adddate      DATETIME
         , @c_Storerkey    NVARCHAR(15)
         , @c_ordermode    NVARCHAR(30)
         , @n_TTLSeq       INT
         , @c_KeyName      NVARCHAR(30)
         , @c_KeyCount     NVARCHAR(10)
         , @b_Success      INT
         , @n_err          INT
         , @c_errmsg       NVARCHAR(250)
         , @c_WaveSeq      NVARCHAR(10)
         , @c_doctype      NVARCHAR(1)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SELECT TOP 1 @dt_Adddate = CASE WHEN ISNULL(TD.AddDate, '') <> '1900-01-01 00:00:00.000' THEN MIN(TD.AddDate)
                                   ELSE WH.EditDate END
              , @c_Storerkey = OH.StorerKey
              , @c_doctype = OH.DocType
   FROM WAVE WH WITH (NOLOCK)
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WH.WaveKey = WD.WaveKey)
   JOIN ORDERS OH WITH (NOLOCK) ON (WD.OrderKey = OH.OrderKey)
   LEFT JOIN TaskDetail TD WITH (NOLOCK) ON TD.WaveKey = WH.WaveKey
   WHERE WH.WaveKey = @c_Wavekey
   GROUP BY OH.StorerKey
          , TD.AddDate
          , WH.EditDate
          , OH.DocType

   SET @d_Adddate = CONVERT(DATETIME, CONVERT(NVARCHAR(10), @dt_Adddate, 112))

   IF OBJECT_ID('tempdb..#TMP_WAVORD', 'u') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_WAVORD;
   END

   CREATE TABLE #TMP_WAVORD
   (
      Wavekey  NVARCHAR(10) NOT NULL DEFAULT ('')
    , Orderkey NVARCHAR(10) NOT NULL DEFAULT ('')
    , OpenQty  INT          NOT NULL DEFAULT (0)
    , EditDate DATETIME     NULL
   )

   INSERT INTO #TMP_WAVORD (Wavekey, Orderkey, OpenQty, EditDate)
   SELECT WH.WaveKey
        , OD.OrderKey
        , OpenQty = ISNULL(SUM(OD.OpenQty), 0)
        , WH.EditDate
   FROM WAVE WH WITH (NOLOCK)
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.WaveKey = WH.WaveKey
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON WD.OrderKey = OD.OrderKey
   WHERE WH.AddDate BETWEEN @d_Adddate AND DATEADD(d, 1, @d_Adddate) AND OD.StorerKey = @c_Storerkey
   GROUP BY WH.WaveKey
          , WH.EditDate
          , OD.OrderKey
   ORDER BY WH.WaveKey
          , OD.OrderKey

   SELECT MaxOrderQty = CASE WHEN MAX(WH.OpenQty) = 1 THEN 'Single'
                             ELSE 'Multi' END
        , WH.Wavekey
        , ReleaseDate = CASE WHEN ISNULL(TD.AddDate, '') <> '1900-01-01 00:00:00.000' THEN MIN(TD.AddDate)
                             ELSE WH.EditDate END
   INTO #TMP_Wave
   FROM #TMP_WAVORD WH
   LEFT JOIN TaskDetail TD WITH (NOLOCK) ON TD.WaveKey = WH.Wavekey
   GROUP BY WH.Wavekey
          , TD.AddDate
          , WH.EditDate

   SELECT @c_WaveSeq = ISNULL(W.UserDefine02, '')
   FROM WAVE W (NOLOCK)
   WHERE W.WaveKey = @c_Wavekey

   IF ISNULL(@c_WaveSeq, '') = ''
   BEGIN
      SELECT @c_KeyName = CL.Code
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'WVSeqOfDay' AND CL.Storerkey = @c_Storerkey AND CL.Short = 'Y'

      EXEC [dbo].[nspg_GetKey] @KeyName = @c_KeyName
                             , @fieldlength = 10
                             , @keystring = @c_KeyCount OUTPUT
                             , @b_Success = @b_Success OUTPUT
                             , @n_err = @n_err OUTPUT
                             , @c_errmsg = @c_errmsg OUTPUT

      SET @c_WaveSeq = SUBSTRING(@c_KeyCount, PATINDEX('%[^0]%', @c_KeyCount + '.'), LEN(@c_KeyCount))

      UPDATE WAVE WITH (ROWLOCK)
      SET UserDefine02 = @c_WaveSeq
        , TrafficCop = NULL
        , EditDate = EditDate
        , EditWho = EditWho
      WHERE WaveKey = @c_Wavekey
   END

   SELECT WaveSeqOfDay = @c_WaveSeq
        , ordermode = WH.MaxOrderQty
        , Wavekey = WH.Wavekey
        , DateRelease = WH.ReleaseDate
   INTO #TMP_WaveSeq
   FROM #TMP_Wave WH

   SET @n_WaveSeqOfDay = 0
   SET @c_ordermode = N''

   SELECT @n_WaveSeqOfDay = WH.WaveSeqOfDay
        , @c_ordermode = WH.ordermode
   FROM #TMP_WaveSeq WH
   WHERE Wavekey = @c_Wavekey

   SET @n_TTLSeq = 1

   SELECT @n_TTLSeq = COUNT(1)
   FROM #TMP_WaveSeq
   WHERE DateRelease <= @dt_Adddate

   SELECT PH.WaveKey
        , AddDate = @dt_Adddate
        , @c_ordermode AS ordermode
        , WaveSeqOfDay = CONVERT(NVARCHAR(10), @n_WaveSeqOfDay)
        , PH.PickHeaderKey
        , LOC.PutawayZone
        , PrintedFlag = @c_PrintedFlag
        , PD.Storerkey
        , PD.Loc
        , PD.ID
        , Style = SKU.Style
        , Color = SKU.Color
        , Size = SKU.Size
        , SkuDescr = ISNULL(MIN(SKU.DESCR), 0)
        , AltSku = ISNULL(RTRIM(SKU.MANUFACTURERSKU), '')
        , SKUGroup = ISNULL(C.Long, '')
        , Qty = ISNULL(SUM(PD.Qty), 0)
        , NoOfSku = @n_NoOfSku
        , NoOfPickLines = @n_NoOfPickLines
        , TTLSeq = @n_TTLSeq
        , logicalloc = LOC.LogicalLocation
        , OrdSelectkey = @c_ordselectkey
        , Colorcode = @c_colorcode
        , doctype = @c_doctype
        , PD.OrderKey
        , ISNULL(C1.Code, '') AS clcode
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN LOC LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
   JOIN SKU SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.StorerKey) AND (PD.Sku = SKU.Sku)
   JOIN RefKeyLookup RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)
   JOIN (  SELECT OD.OrderKey
                , Openqty = SUM(OD.OpenQty)
           FROM ORDERS OH WITH (NOLOCK)
           JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.OrderKey = OD.OrderKey)
           WHERE OH.UserDefine09 = @c_Wavekey
           GROUP BY OD.OrderKey) ODSUM ON (ODSUM.OrderKey = PD.OrderKey)
   JOIN PICKHEADER PH WITH (NOLOCK) ON (RL.Pickslipno = PH.PickHeaderKey)
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON  C.LISTNAME = 'ADSKUDIV'
                                      AND C.Storerkey = SKU.StorerKey
                                      AND C.Code = SKU.SKUGROUP
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON  C1.LISTNAME = 'WAVETYPE'
                                       AND C1.Storerkey = SKU.StorerKey
                                       AND C1.Code = 'AD_OrderP'
   WHERE PH.PickHeaderKey = @c_PickSlipNo AND LOC.PutawayZone = @c_Zone AND PD.Status < '5'
   GROUP BY PH.WaveKey
          , PH.PickHeaderKey
          , LOC.PutawayZone
          , PD.Storerkey
          , PD.Loc
          , PD.ID
          , SKU.Style
          , SKU.Color
          , SKU.Size
          , ISNULL(RTRIM(SKU.MANUFACTURERSKU), '')
          , ISNULL(C.Long, '')
          , LOC.LogicalLocation
          , PD.OrderKey
          , ISNULL(C1.Code, '')
   ORDER BY ISNULL(RTRIM(PH.PickHeaderKey), '')
          , LOC.PutawayZone
          , LOC.LogicalLocation
          , PD.Loc
          , Style
          , Color
          , Size

END -- procedure

GO
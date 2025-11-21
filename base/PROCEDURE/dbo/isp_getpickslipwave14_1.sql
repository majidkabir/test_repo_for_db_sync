SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_GetPickSlipWave14_1                                 */
/* Creation Date: 10-JAN-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-3711 - KR_Nike_Picking Slip Report_Data Window_New      */
/*        :                                                             */
/* Called By: R_dw_print_wave_pickslip_14_1                             */
/*          :                                                           */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 05-Feb-2018 Wan01    1.1   WMS-3980 - KR_Nike_Picking Slip Report_Data*/
/*                            Window_CR                                 */
/* 07-Feb-2018 Wan02    1.2   Bug Fix on NoOfWavePerday                 */
/* 28-Feb-2018 CSCHONG  1.3   WMS-4041 revised and add new field(CS01)  */
/* 14-Jun-2018 CSCHONG  1.4   WMS-5247 - revise sorting (CS02)          */
/* 21-Nov-2018 WLCHOOI  1.5   WMS-6779 - Add new fields (WL01)          */
/* 21-Nov-2019 TTLTING01 1.5   WMS-6779 - Add new fields (WL01)         */      
/* 03-Dec-2019 Wan03    1.5   Performance enhancement                   */  
/* 15-06-2020  Wan04    1.6   Sync Exceed & SCE                         */ 
/* 26-07-2021  CSCHONG  1.7   WMS-17182 revised field logic (CS03)      */   
/* 31-01-2023  MINGLE   1.8   WMS-21515 revised field logic (ML01)      */ 
/************************************************************************/
CREATE   PROC isp_GetPickSlipWave14_1
            @c_Wavekey        NVARCHAR(10)
         ,  @c_PickSlipNo     NVARCHAR(10)
         ,  @c_Zone           NVARCHAR(10)
         ,  @c_PrintedFlag    NCHAR(1)
         ,  @n_NoOfSku        INT
         ,  @n_NoOfPickLines  INT
         ,  @c_ordselectkey NVARCHAR(20)
         ,  @c_colorcode    NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT

         , @n_WaveSeqOfDay    INT
         , @dt_Adddate        DATETIME
         , @d_Adddate         DATETIME

         , @c_Storerkey       NVARCHAR(15)                                    --(Wan02)
         , @c_ordermode       NVARCHAR(30)                                    --(CS01)
         , @n_TTLSeq          INT                                             --(CS01) 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

  
   SELECT TOP 1 @dt_Adddate = CASE WHEN ISNULL(TD.AddDate,'')  <>'1900-01-01 00:00:00.000' 
                               THEN MIN(TD.AddDate) ELSE WH.EditDate END--WH.AddDate   --CS01
         ,@c_Storerkey= OH.Storerkey                                          --(Wan02)
   FROM WAVE WH  WITH (NOLOCK)
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WH.Wavekey = WD.Wavekey)              --(Wan02)
   JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey= OH.Orderkey)             --(Wan02)
   LEFT JOIN Taskdetail TD WITH (NOLOCK) ON TD.wavekey=WH.wavekey             --(CS01)
   WHERE WH.Wavekey = @c_Wavekey
   GROUP BY OH.Storerkey,TD.AddDate ,WH.EditDate
   

   SET @d_Adddate = CONVERT (DATETIME, CONVERT(NVARCHAR(10), @dt_Adddate, 112))
     -- SELECT * FROM #TMP_Wave
   --select * from #TMP_WaveSeq 
   
--(Wan03) - START  
   IF OBJECT_ID('tempdb..#TMP_WAVORD','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_WAVORD;  
   END       
  
   CREATE TABLE #TMP_WAVORD    
      (  Wavekey  NVARCHAR(10) NOT NULL   DEFAULT ('')    
      ,  Orderkey NVARCHAR(10) NOT NULL   DEFAULT ('')      
      ,  OpenQty  INT          NOT NULL   DEFAULT (0)    
      ,  EditDate DATETIME     NULL           
      )      
    
   INSERT INTO #TMP_WAVORD    
      (  Wavekey    
      ,  Orderkey    
      ,  OpenQty    
      ,  EditDate    
      )    
   SELECT WH.Wavekey    
         ,OD.Orderkey     
         ,OpenQty= ISNULL(SUM(OD.OpenQty),0)      
         ,WH.EditDate      
   FROM WAVE        WH WITH (NOLOCK)      
   JOIN WAVEDETAIL  WD WITH (NOLOCK) ON WD.WaveKey  = WH.WaveKey     
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON WD.Orderkey = OD.Orderkey    
   WHERE WH.AddDate BETWEEN @d_Adddate AND DATEADD(d, 1, @d_Adddate)      
   AND   WH.TMReleaseFlag = 'Y'  --Wan04
   --AND WH.status='1'           --Wan04
   AND OD.Storerkey = @c_Storerkey    
   GROUP BY WH.Wavekey, WH.EditDate, OD.Orderkey    
   ORDER BY WH.Wavekey, OD.Orderkey    
    
   SELECT MaxOrderQty= CASE WHEN MAX(WH.OpenQty) = 1 THEN 'Single' ELSE 'Multi' END      
         ,WH.Wavekey      
         ,ReleaseDate =CASE WHEN ISNULL(TD.AddDate,'')  <>'1900-01-01 00:00:00.000'       
                            THEN MIN(TD.AddDate) ELSE WH.EditDate END      
   INTO #TMP_Wave      
   FROM #TMP_WAVORD WH    
   LEFT JOIN Taskdetail TD WITH (NOLOCK) ON TD.wavekey=WH.wavekey             --(CS01)      
   GROUP BY WH.Wavekey,TD.AddDate ,WH.EditDate      
    
   --   SELECT MaxOrderQty= CASE WHEN MAX(ODSUM.OpenQty) = 1 THEN 'Single' ELSE 'Multi' END      
   --      ,WH.Wavekey      
   --      ,ReleaseDate =CASE WHEN ISNULL(TD.AddDate,'')  <>'1900-01-01 00:00:00.000'       
   --                          THEN MIN(TD.AddDate) ELSE WH.EditDate END      
   --INTO #TMP_Wave      
   --FROM WAVE WH WITH (NOLOCK)      
   --JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.WaveKey=WH.WaveKey      
   -- JOIN (SELECT OD.Orderkey, Openqty = SUM(OD.OpenQty)       
   --      FROM ORDERS OH WITH (NOLOCK)      
   --      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)       
   --     -- WHERE OH.UserDefine09 = @c_Wavekey      
   --     WHERE OH.Storerkey = @c_Storerkey    -- TTLTING01      
   --      GROUP BY OD.Orderkey) ODSUM ON (ODSUM.Orderkey = WD.Orderkey)      
   --LEFT JOIN Taskdetail TD WITH (NOLOCK) ON TD.wavekey=WH.wavekey             --(CS01)      
   --WHERE WH.AddDate BETWEEN @d_Adddate AND DATEADD(d, 1, @d_Adddate)      
   --AND WH.status='1'      
   --AND EXISTS (SELECT 1                                                       --(Wan02)      
   --            FROM WAVEDETAIL WD WITH(NOLOCK)                                --(Wan02)      
   --            JOIN ORDERS OH WITH(NOLOCK) ON OH.Orderkey = WD.Orderkey       --(Wan02)      
   --            WHERE WD.Wavekey = WH.Wavekey AND OH.Storerkey = @c_Storerkey) --(Wan02)      
   --GROUP BY WH.Wavekey,TD.AddDate ,WH.EditDate      
   --(Wan03) - END 
   
   --SELECT * FROM #TMP_Wave
   --select * from #TMP_WaveSeq  
   
   --AND EXISTS (SELECT 1                                                       --(Wan02)
   --            FROM WAVEDETAIL WD WITH(NOLOCK)                                --(Wan02)
   --            JOIN ORDERS OH WITH(NOLOCK) ON OH.Orderkey = WD.Orderkey       --(Wan02)
   --            WHERE WD.Wavekey = WH.Wavekey AND OH.Storerkey = @c_Storerkey) --(Wan02)
   --ORDER BY WH.AddDate       
   
   
     SELECT WaveSeqOfDay  = ROW_NUMBER() OVER (PARTITION BY  WH.MaxOrderQty ORDER BY WH.Wavekey)
          ,ordermode = WH.MaxOrderQty                                    --(CS01)
          ,Wavekey = WH.wavekey
          ,DateRelease = WH.ReleaseDate
   INTO   #TMP_WaveSeq     
   FROM #TMP_Wave WH   
   --WHERE Wavekey = @c_Wavekey  
   --
  --select * from #TMP_WaveSeq                                               
   
   SET @n_WaveSeqOfDay = 0
   SET @c_ordermode = ''
   
   SELECT @n_WaveSeqOfDay  = WH.WaveSeqOfDay
          ,@c_ordermode = WH.ordermode                                    --(CS01)
   FROM #TMP_WaveSeq WH   
   WHERE Wavekey = @c_Wavekey
   
   --SELECT n_WaveSeqOfDay  = ROW_NUMBER() OVER (PARTITION BY  WH.MaxOrderQty ORDER BY WH.Wavekey)
   --       ,c_ordermode = WH.MaxOrderQty                                    --(CS01)
   --FROM #TMP_WaveSeq WH   
   --WHERE Wavekey = @c_Wavekey
   
   --SELECT @n_WaveSeqOfDay = WaveSeqOfDay
   --FROM #TMP_WaveSeq
   --WHERE Wavekey = @c_Wavekey
     
   SET @n_TTLSeq = 1
   
   --IF @c_PrintedFlag <> 'Y'
   --BEGIN
   -- SELECT @n_TTLSeq = count(1)
   --   FROM #TMP_WaveSeq
      
   --END
   --ELSE
   --BEGIN
      SELECT @n_TTLSeq = COUNT(1)
      FROM #TMP_WaveSeq
      WHERE DateRelease <= @dt_Adddate
   --END 
                             
   SELECT PH.Wavekey
         ,AddDate = @dt_Adddate
         --,MaxOrderQty= CASE WHEN MAX(ODSUM.OpenQty) = 1 THEN 'Single' ELSE 'Multi' END
         ,@c_ordermode AS ordermode                                            --(CS01)
         ,WaveSeqOfDay = CONVERT( NVARCHAR(10), @n_WaveSeqOfDay )
         ,PH.PickHeaderkey
         ,LOC.PutawayZone                                      --(Wan01)
         ,@c_Printedflag  
         ,PD.Storerkey
         ,PD.Loc
         ,PD.ID
         ,Style   = SUBSTRING(SKU.Sku,1,6)                               --CS03  --ML01 use SKU instead of S1
         ,Color   = SUBSTRING(SKU.Sku,7,3)                               --CS03  --ML01 use SKU instead of S1  
         --,Size    = LTRIM(SUBSTRING(SKU.Sku,12,5))                       --CS03  --ML01 use SKU instead of S1
         ,Size    = LTRIM(SUBSTRING(SKU.Sku,10,LEN(SKU.SKU)))
         ,SkuDescr= ISNULL(MIN(SKU.Descr),0)                             --CS03  --ML01 use SKU instead of S1
         ,AltSku  = ISNULL(RTRIM(SKU.AltSku), '')
         --,S1.SkuGroup                                                   --CS03
         ,CASE SKU.BUSR7 WHEN '10' THEN 'AP'
                         WHEN '20' THEN 'FW'
                         WHEN '30' THEN 'EQ'
                         WHEN '40' THEN 'VM' 
                         ELSE 'XX' END AS SKUGroup                         --ML01 
         ,Qty    = ISNULL(SUM(PD.Qty),0)
         ,NoOfSku= @n_NoOfSku --COUNT(DISTINCT PD.Sku)
         ,NoOfPickLines= @n_NoOfPickLines --COUNT(DISTINCT PD.Loc + PD.ID)
         ,TTLSeq  = @n_TTLSeq                                          --(CS01)
         ,logicalloc = loc.logicallocation                             --(CS02)
         ,OrdSelectkey = @c_ordselectkey      --WL01
         ,Colorcode = @c_colorcode         --WL01
   FROM PICKDETAIL PD   WITH (NOLOCK) 
   JOIN LOC        LOC  WITH (NOLOCK) ON (PD.Loc = LOC.Loc)    --(Wan01)
   JOIN SKU        SKU  WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                      AND(PD.Sku = SKU.Sku)
   --JOIN SKU S1 (NOLOCK) ON S1.ALTSKU=SKU.ALTSKU AND S1.StorerKey='NIKEKRB' AND SKU.StorerKey='NIKEKR'      --CS03
   JOIN REFKEYLOOKUP RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)
   JOIN (SELECT OD.Orderkey, Openqty = SUM(OD.OpenQty) FROM ORDERS OH WITH (NOLOCK)
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey) 
         WHERE OH.UserDefine09 = @c_Wavekey
         GROUP BY OD.Orderkey) ODSUM ON (ODSUM.Orderkey = PD.Orderkey)
   JOIN PICKHEADER PH WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderkey)
   WHERE PH.PickHeaderKey = @c_PickSlipNo
   AND   LOC.PutawayZone = @c_Zone                             --(Wan01)
   AND   PD.Status < '5'
   GROUP BY PH.Wavekey
         ,  PH.PickHeaderkey
         ,  LOC.PutawayZone                                    --(Wan01)
         ,  PD.Storerkey
         ,  PD.Loc
         ,  PD.ID
         ,  SUBSTRING(SKU.Sku,1,6)                              --CS03  --ML01 use SKU instead of S1 
         ,  SUBSTRING(SKU.Sku,7,3)                              --CS03  --ML01 use SKU instead of S1
         ,  LTRIM(SUBSTRING(SKU.Sku,10,LEN(SKU.SKU)))           --CS03  --ML01 use SKU instead of S1
         ,  ISNULL(RTRIM(SKU.AltSku), '')
         --,  S1.SkuGroup                                        --CS03
         ,CASE SKU.BUSR7 WHEN '10' THEN 'AP'
                         WHEN '20' THEN 'FW'
                         WHEN '30' THEN 'EQ'
                         WHEN '40' THEN 'VM' 
                         ELSE 'XX' END                         --ML01
         ,  loc.logicallocation                                --(CS02)
   ORDER BY ISNULL(RTRIM(PH.PickHeaderkey), '') 
         ,  LOC.PutawayZone                                    --(Wan01)  
         ,  loc.logicallocation                                --(CS02)
         ,  PD.Loc
         ,  Style
         ,  Color
         ,  Size

END -- procedure

GO
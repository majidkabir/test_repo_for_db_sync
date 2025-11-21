SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_GetPickSlipWave26_2                                 */
/* Creation Date: 17-MAR-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-16525 - KR_ADIDAS_Picking Slip Report Data Window_CR    */
/*        :                                                             */
/* Called By: R_dw_print_wave_pickslip_26_2                             */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */   
/* 2021-03-31  WLChooi  1.1   WMS-16733 - Get the Distinct SKU of the   */
/*                            whole Wave (WL01)                         */
/* 2021-04-16  WLChooi  1.2   WMS-16380 - Take QtyAllocated (WL02)      */
/* 2022-10-31  Mingle   1.3   WMS-21045 - Add new mapping(ML01)         */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPickSlipWave26_2]
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

         , @c_Storerkey       NVARCHAR(15)                                     
         , @c_ordermode       NVARCHAR(30)                                     
         , @n_TTLSeq          INT     
         
         , @c_KeyName         NVARCHAR(30)   
         , @c_KeyCount        NVARCHAR(10) 
         , @b_Success         INT          
         , @n_err             INT          
         , @c_errmsg          NVARCHAR(250)
         , @c_WaveSeq         NVARCHAR(10) 
			, @c_salesman			NVARCHAR(30)	--ML01

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
  
   SELECT TOP 1 @dt_Adddate = CASE WHEN ISNULL(TD.AddDate,'')  <>'1900-01-01 00:00:00.000' 
                              THEN MIN(TD.AddDate) ELSE WH.EditDate END  
               ,@c_Storerkey= OH.Storerkey
					,@c_salesman = OH.Salesman	--ML01
   FROM WAVE WH  WITH (NOLOCK)
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WH.Wavekey = WD.Wavekey)               
   JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey= OH.Orderkey)              
   LEFT JOIN Taskdetail TD WITH (NOLOCK) ON TD.wavekey=WH.wavekey              
   WHERE WH.Wavekey = @c_Wavekey
   AND OH.DocType='N'
   GROUP BY OH.Storerkey,TD.AddDate ,WH.EditDate,OH.Salesman
   
   SET @d_Adddate = CONVERT (DATETIME, CONVERT(NVARCHAR(10), @dt_Adddate, 112))
 
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
   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = OD.OrderKey  
   WHERE WH.AddDate BETWEEN @d_Adddate AND DATEADD(d, 1, @d_Adddate)      
   AND OD.Storerkey = @c_Storerkey    
   AND OH.DocType='N'
   GROUP BY WH.Wavekey, WH.EditDate, OD.Orderkey    
   ORDER BY WH.Wavekey, OD.Orderkey    
    
   SELECT MaxOrderQty= CASE WHEN MAX(WH.OpenQty) = 1 THEN 'Single' ELSE 'Multi' END      
         ,WH.Wavekey      
         ,ReleaseDate =CASE WHEN ISNULL(TD.AddDate,'')  <>'1900-01-01 00:00:00.000'       
                            THEN MIN(TD.AddDate) ELSE WH.EditDate END      
   INTO #TMP_Wave      
   FROM #TMP_WAVORD WH    
   LEFT JOIN Taskdetail TD WITH (NOLOCK) ON TD.wavekey=WH.wavekey                    
   GROUP BY WH.Wavekey,TD.AddDate ,WH.EditDate      
      
   SELECT @c_WaveSeq = ISNULL(W.UserDefine02,'')
   FROM WAVE W (NOLOCK)
   WHERE W.WaveKey = @c_Wavekey
   
   IF ISNULL(@c_WaveSeq,'') = ''
   BEGIN
      SELECT @c_KeyName = CL.Code
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'WVSeqOfDay' 
      AND CL.Storerkey = @c_Storerkey
      AND CL.Short = 'Y'
      
      EXEC [dbo].[nspg_GetKey]     
          @KeyName     =  @c_KeyName     
        , @fieldlength =  10
        , @keystring   =  @c_KeyCount   OUTPUT    
        , @b_Success   =  @b_Success    OUTPUT    
        , @n_err       =  @n_err        OUTPUT    
        , @c_errmsg    =  @c_errmsg     OUTPUT    
        
      --SET @c_WaveSeq = LTRIM(REPLACE(@c_KeyCount,'0',''))   --WL02
      SET @c_WaveSeq = SUBSTRING(@c_KeyCount, PATINDEX('%[^0]%', @c_KeyCount + '.'), LEN(@c_KeyCount))   --WL02

      UPDATE WAVE WITH (ROWLOCK)
      SET UserDefine02 = @c_WaveSeq,
          TrafficCop   = NULL,
          EditDate     = EditDate,
          EditWho      = EditWho
      WHERE WaveKey = @c_Wavekey
   END

   SELECT WaveSeqOfDay  = @c_WaveSeq   --ROW_NUMBER() OVER (PARTITION BY  WH.MaxOrderQty ORDER BY WH.Wavekey)   --WL01
         ,ordermode = WH.MaxOrderQty                                     
         ,Wavekey = WH.wavekey
         ,DateRelease = WH.ReleaseDate
   INTO  #TMP_WaveSeq     
   FROM #TMP_Wave WH   

  --select * from #TMP_WaveSeq                                               
   
   SET @n_WaveSeqOfDay = 0
   SET @c_ordermode = ''
   
   SELECT @n_WaveSeqOfDay  = WH.WaveSeqOfDay
         ,@c_ordermode = WH.ordermode                                     
   FROM #TMP_WaveSeq WH   
   WHERE Wavekey = @c_Wavekey
     
   SET @n_TTLSeq = 1

   SELECT @n_TTLSeq = COUNT(1)
   FROM #TMP_WaveSeq
   WHERE DateRelease <= @dt_Adddate
   
   --WL01 S
   SELECT @n_NoOfSku = COUNT(DISTINCT OD.SKU)
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON WD.OrderKey = OH.OrderKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.Orderkey
   WHERE WD.WaveKey = @c_Wavekey
   --WL01 E
                        
   SELECT PH.Wavekey
         ,AddDate = @dt_Adddate
         ,@c_ordermode AS ordermode                                             
         ,WaveSeqOfDay = CONVERT( NVARCHAR(10), @n_WaveSeqOfDay )
         ,PH.PickHeaderkey AS pickslipno
         ,LOC.PutawayZone  AS Zone                                      
         ,@c_Printedflag  AS printedflag
         ,PD.Storerkey
         ,PD.Loc
         ,PD.ID
         ,Style   = SKU.Style 
         ,Color   = SKU.color
         ,Size    = SKU.Size
         ,SkuDescr= ISNULL(MIN(SKU.Descr),0)
         ,AltSku  = ISNULL(RTRIM(SKU.manufacturersku), '')
        -- ,SKU.SkuGroup
         ,RptDesc = ISNULL(C.long,'')
         ,Qty    = ISNULL(SUM(PD.Qty),0)
         ,NoOfSku= @n_NoOfSku 
         ,NoOfPickLines= @n_NoOfPickLines 
         ,TTLSeq  = @n_TTLSeq                                           
         ,logicalloc = loc.logicallocation                             
         ,OrdSelectkey = @c_ordselectkey       
         ,Colorcode = @c_colorcode          
         ,Orderkey = ODSUM.Orderkey
         ,Openqty = ODSUM.Openqty
         --,RptDesc = ISNULL(C.long,''
			,Salesman = @c_salesman	--ML01
   FROM PICKDETAIL PD   WITH (NOLOCK) 
   JOIN LOC        LOC  WITH (NOLOCK) ON (PD.Loc = LOC.Loc)    
   JOIN SKU        SKU  WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                      AND(PD.Sku = SKU.Sku)
   --JOIN REFKEYLOOKUP RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)
   JOIN (SELECT OD.Orderkey, Openqty = SUM(OD.QtyAllocated) FROM ORDERS OH WITH (NOLOCK)   --WL02	
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey) 
         WHERE OH.UserDefine09 = @c_Wavekey
         AND OH.DocType='N'
         GROUP BY OD.Orderkey) ODSUM ON (ODSUM.Orderkey = PD.Orderkey)	
   JOIN PICKHEADER PH WITH (NOLOCK) ON (PD.Orderkey = PH.Orderkey)
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'ADSKUDIV' AND C.Storerkey=sku.StorerKey AND C.code=SKU.SKUGROUP
   WHERE PH.PickHeaderKey = @c_PickSlipNo
   AND   LOC.PutawayZone = @c_Zone                              
   AND   PD.Status < '5'
   GROUP BY PH.Wavekey
         ,  PH.PickHeaderkey
         ,  LOC.PutawayZone                                     
         ,  PD.Storerkey
         ,  PD.Loc
         ,  PD.ID
         ,  SKU.Style 
         ,  SKU.color
         ,  SKU.Size
         ,  ISNULL(RTRIM(SKU.manufacturersku), '')
         --,  SKU.SkuGroup
         , ISNULL(C.long,'')
         , loc.logicallocation      
         , ODSUM.Orderkey           
         , ODSUM.Openqty  
   ORDER BY ISNULL(RTRIM(PH.PickHeaderkey), '') 
         ,  LOC.PutawayZone                                       
         ,  loc.logicallocation                              
         ,  PD.Loc
         ,  Style
         ,  Color
         ,  Size

END -- procedure

GO
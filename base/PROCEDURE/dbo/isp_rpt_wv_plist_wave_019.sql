SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_019                             */    
/* Creation Date: 25-APR-2023                                              */    
/* Copyright: LFL                                                          */    
/* Written by: CSCHONG                                                     */    
/*                                                                         */    
/* Purpose: WMS-22356 SG-AESOP-B2B Picking Slip                            */    
/*                                                                         */    
/* Called By: RPT_WV_PLIST_WAVE_019                                        */    
/*                                                                         */    
/* GitLab Version: 1.0                                                     */    
/*                                                                         */    
/* Version: 1.0                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date            Author   Ver  Purposes                                  */
/* 25-Apr-2023     CSCHONG  1.0  DevOps Combine Script                     */
/***************************************************************************/     

CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_019]
     (  
       @c_Wavekey_Type          NVARCHAR(13)  
    -- , @c_PreGenRptData         NVARCHAR(10)
     )  
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF 
  
     
   DECLARE @n_StartTCnt          INT  
         , @n_Continue           INT             
         , @b_Success            INT  
         , @n_Err                INT  
         , @c_Errmsg             NVARCHAR(255)  
           
   DECLARE @c_Wavekey            NVARCHAR(10)  
         , @c_Type               NVARCHAR(2)  
         , @c_Loadkey            NVARCHAR(10)  
         , @c_PickSlipNo         NVARCHAR(10)  
         , @c_RPickSlipNo        NVARCHAR(10)  
         , @c_PrintedFlag        NVARCHAR(1) 
         , @c_MaxPickslip        NVARCHAR(10)
         , @c_PreOrderkey        NVARCHAR(10)   
   
   DECLARE @c_PickHeaderkey      NVARCHAR(10)   
         , @c_Storerkey          NVARCHAR(15)   
         , @c_ST_Company         NVARCHAR(45)  
         , @c_Orderkey           NVARCHAR(10)  
         , @c_OrderType          NVARCHAR(10)  
         , @c_Stop               NVARCHAR(10)  
         , @c_ExternOrderkey     NVARCHAR(30)  
         , @c_BuyerPO            NVARCHAR(20)  
         , @c_OrderGroup         NVARCHAR(20)  
         , @c_Sectionkey         NVARCHAR(10)  
         , @c_DeliveryDate       NVARCHAR(10)  
         , @c_Consigneekey       NVARCHAR(15)  
         , @c_C_Company          NVARCHAR(45)                                                  
         , @n_TotalCBM           FLOAT     
         , @n_TotalGrossWgt      FLOAT  
         , @n_noOfTotes          INT    
         , @c_PAZone             NVARCHAR(10) 
         , @c_PrevPAZone         NVARCHAR(10) 
         , @c_PADescr            NVARCHAR(60)   
         , @c_LogicalLoc         NVARCHAR(18)  
         , @c_Sku                NVARCHAR(20)  
         , @c_SkuDescr           NVARCHAR(60)  
         , @c_HazardousFlag      NVARCHAR(30)  
         , @c_Loc                NVARCHAR(10)  
         , @c_ID                 NVARCHAR(18)      
         , @c_DropID             NVARCHAR(20)   
         , @n_Qty                INT  
         , @c_UserDefine02       NVARCHAR(18) 
         , @n_NoOfLine           INT
         , @c_GetStorerkey       NVARCHAR(15)  
         , @c_pickZone           NVARCHAR(10)
         , @c_PZone              NVARCHAR(10)
         , @n_MaxRow             INT
         , @n_RowNo              INT
         , @n_CntRowNo           INT
         , @c_OrdKey             NVARCHAR(20)
         , @c_OrdLineNo          NVARCHAR(5)
         , @c_GetWavekey         NVARCHAR(10)
         , @c_GetPickSlipNo      NVARCHAR(10)    
         , @c_GetPickZone        NVARCHAR(10)
         , @c_GetOrdKey          NVARCHAR(20)
         , @c_GetLoadkey         NVARCHAR(10)
         , @c_PickDetailKey      NVARCHAR(18) 
         , @c_GetPickDetailKey   NVARCHAR(18) 
         , @c_ExecStatement      NVARCHAR(4000)
         , @c_GetPHOrdKey        NVARCHAR(20)
         , @c_GetWDOrdKey        NVARCHAR(20)                       
         , @c_LogoType           NVARCHAR(1) = '1'                    
         , @c_DataWindow         NVARCHAR(60) = 'RPT_WV_PLIST_WAVE_019'
         , @c_RetVal             NVARCHAR(255)    
         , @n_ctnOrd             INT   = 0
         , @c_PreGenRptData      NVARCHAR(10) = ''
          
   SET @n_StartTCnt  =  @@TRANCOUNT  
   SET @n_Continue   =  1    
   SET @c_PickHeaderkey = ''  
   SET @c_Storerkey     = ''  
   SET @c_ST_Company    = ''  
   SET @c_Orderkey      = ''  
   SET @c_OrderType     = ''  
   SET @c_Stop   = ''  
   SET @c_ExternOrderkey= ''    
   SET @c_BuyerPO       = ''  
   SET @c_Consigneekey  = ''  
   SET @c_C_Company     = ''       
   SET @c_RPickSlipNo   = ''                  
   SET @n_TotalCBM      = 0.00  
   SET @n_TotalGrossWgt = 0.00  
   SET @n_noOfTotes     = 0                          
   SET @c_Sku           = ''  
   SET @c_SkuDescr      = ''  
   SET @c_HazardousFlag = ''  
   SET @c_Loc           = ''  
   SET @c_ID            = ''  
   SET @c_DropID        = ''     
   SET @c_PZone         = ''
   SET @n_Qty           = 0  
   SET @c_PADescr       = ''  
   SET @c_UserDefine02  = ''  
   SET @n_NoOfLine      =  1
   SET @c_GetStorerkey  = ''
   SET @n_CntRowNo      = 1
    
  
   WHILE @@TranCount > 0    
   BEGIN    
      COMMIT TRAN    
   END   

   IF @c_PreGenRptData = '0' SET @c_PreGenRptData = ''
           
      CREATE TABLE #TMP_PICK  
   (  PickSlipNo         NVARCHAR(10) NULL,  
      LoadKey            NVARCHAR(10),  
      OrderKey           NVARCHAR(10),  
      OHNotes2           NVARCHAR(4000), 
      C_Company          NVARCHAR(45),  
      Storerkey          NVARCHAR(15) NULL, 
      Wavekey            NVARCHAR(10) NULL,
      ExtOrderkey        NVARCHAR(50) NULL,
      MaxPickslip        NVARCHAR(10) NULL, 
      CtnCarton          NVARCHAR(10) NULL
   )    
      
  
   SET @c_Wavekey = SUBSTRING(@c_Wavekey_Type, 1, 10)  
   SET @c_Type    = SUBSTRING(@c_Wavekey_Type, 11,2)  
      
   SELECT TOP 1 @c_GetStorerkey = ORD.Storerkey
   FROM WAVEDETAIL WD  WITH (NOLOCK)
   JOIN ORDERS ORD WITH (NOLOCK) ON WD.Orderkey = ORD.OrderKey
   WHERE WD.Wavekey = @c_Wavekey     


   IF EXISTS (SELECT 1
              FROM WAVEDETAIL WD (NOLOCK)
              JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
              WHERE WD.WaveKey = @c_Wavekey
              AND OH.DocType = 'E')
   BEGIN
      GOTO QUIT
   END 
      
   INSERT INTO #TMP_PICK
   (
       PickSlipNo,
       LoadKey,
       OrderKey,
       OHNotes2,
       C_Company,  
       Storerkey,
       Wavekey,
       ExtOrderkey,
       MaxPickslip,
       CtnCarton
   )
                
  SELECT DISTINCT 
      IsNull(Pickheader.Pickheaderkey,''),   
      ORDERS.LoadKey,CASE WHEN ISNULL(ORDERS.notes2, '') <> '' THEN ORDERS.OrderKey ELSE '' END,
      SUBSTRING(ISNULL(ORDERS.notes2, ''),1,200) AS OHnotes2,  
      CASE WHEN ISNULL(ORDERS.notes2, '') <> '' THEN ISNULL(ORDERS.C_Company, '') ELSE '' END AS c_company,     
      ORDERS.Storerkey,  
      WD.WaveKey,
      CASE WHEN ISNULL(ORDERS.notes2, '') <> '' THEN ORDERS.ExternOrderKey ELSE '' END,
      (SELECT MAX(PD.Pickslipno) FROM PICKDETAIL PD (NOLOCK) WHERE PD.OrderKey = ORDERS.OrderKey) AS MaxPickslip,
      CASE WHEN ISNULL(ORDERS.notes2, '') <> '' THEN  CAST(PAD.ctncartonno AS NVARCHAR(10)) ELSE '' END
   FROM WAVEDETAIL      WD  WITH (NOLOCK) 
   JOIN PICKDETAIL WITH (NOLOCK)  ON PICKDETAIL.OrderKey = WD.OrderKey --AND  PICKDETAIL.WaveKey=wd.WaveKey
   --LEFT JOIN PICKHEADER WITH (NOLOCK) ON PICKHEADER.ExternOrderKey = PICKDETAIL.PickSlipNo
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON PICKHEADER.OrderKey = PICKDETAIL.Orderkey 
   JOIN ORDERS WITH (NOLOCK) ON  PICKDETAIL.OrderKey = ORDERS.OrderKey  
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.OrderKey=ORDERS.orderkey
   --JOIN dbo.PackDetail PAD WITH (NOLOCK) ON PAD.PickSlipNo=PH.PickSlipNo
   CROSS APPLY (SELECT DISTINCT PD.PickSlipNo,count(DISTINCT PD.cartonno) AS ctncartonno FROM PackDetail PD WITH (NOLOCK) WHERE PD.PickSlipNo=PH.PickSlipNo
                  GROUP BY PD.PickSlipNo) AS PAD
   JOIN STORER WITH (NOLOCK) ON  PICKDETAIL.Storerkey = STORER.Storerkey  
   JOIN SKU(NOLOCK) ON  PICKDETAIL.SKU = SKU.SKU  
                       AND PICKDETAIL.Storerkey = SKU.Storerkey  
   JOIN PACK WITH (NOLOCK) ON  PICKDETAIL.PACKkey = PACK.PACKkey  
   JOIN LOC WITH (NOLOCK) ON  PICKDETAIL.LOC = LOC.LOC  
   --LEFT JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PICKDETAILKey = PICKDETAIL.PICKDETAILKey) 
   JOIN WAVE W WITH (NOLOCK) ON (W.WaveKey = WD.WaveKey)
   WHERE PICKDETAIL.Status <= '5' 
   AND WD.WaveKey = @c_waveKey
   --AND ISNULL(Orders.Notes2,'') <> ''
   GROUP BY PICKHEADER.Pickheaderkey,--RefKeyLookup.PickSlipNo,
            ORDERS.LoadKey,ORDERS.OrderKey,
            ISNULL(ORDERS.notes2, ''),  
            ISNULL(ORDERS.C_Company, ''),  
            ORDERS.Storerkey,  
            WD.WaveKey,
            ORDERS.ExternOrderKey, CAST(PAD.ctncartonno AS NVARCHAR(10))
               
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END
     
   SET @c_OrderKey = ''  
   SET @c_preorderkey = ''
   SET @n_continue = 1
    
   DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT loadkey  
         , orderkey 
         , MaxPickslip
   FROM #TMP_PICK  
   WHERE ISNULL(PickSlipNo,'') = ''
   ORDER BY Orderkey      
  
   OPEN CUR_LOAD  
     
   FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_orderkey   
                              ,  @c_MaxPickslip
                           
  
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN              
      IF ISNULL(@c_OrderKey, '0') = '0'  
         BREAK  

     SET @c_PreGenRptData=''       
     IF @c_preorderkey <> @c_orderkey AND ISNULL(@c_MaxPickslip,'') = '' 
     BEGIN
               SET @c_PreGenRptData='Y'     
     END
                  
      IF @c_preorderkey <> @c_orderkey AND ISNULL(@c_MaxPickslip,'') = ''  AND @c_PreGenRptData='Y'         
      BEGIN               
         SET @c_RPickSlipNo = ''
         
         EXECUTE nspg_GetKey       
                  'PICKSLIP'    
               ,  9    
               ,  @c_RPickSlipNo   OUTPUT    
               ,  @b_Success       OUTPUT    
               ,  @n_err           OUTPUT    
               ,  @c_errmsg        OUTPUT 
                        
         IF @b_success = 1   
         BEGIN                 
            SET @c_RPickSlipNo = 'P' + @c_RPickSlipNo          
                      
            INSERT INTO PICKHEADER      
                     (  PickHeaderKey    
                     ,  Wavekey    
                     ,  Orderkey    
                     ,  ExternOrderkey    
                     ,  Loadkey    
                     ,  PickType    
                     ,  Zone    
                     ,  consoorderkey
                     ,  TrafficCop    
                     )      
            VALUES      
                     (  @c_RPickSlipNo    
                     ,  @c_Wavekey     
                     ,  @c_orderkey
                     ,  @c_RPickSlipNo   
                     ,  @c_Loadkey    
                     ,  '0'     
                     ,  '3'  
                     ,  ''     
                     ,  ''    
                     )          
            
            SET @n_err = @@ERROR
                       
            IF @n_err <> 0      
            BEGIN      
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 81008         
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_RPT_WV_PLIST_WAVE_019)'   
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
               GOTO QUIT     
            END                 
         END
         ELSE   
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @n_err = 63502
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PSNO Failed. (isp_RPT_WV_PLIST_WAVE_019)'  
            BREAK   
         END            
      END            
       
      IF @n_Continue = 1  
      BEGIN        
                     DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR  
                     SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber     
                     FROM   PickDetail WITH (NOLOCK)  
                     JOIN   OrderDetail WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND   
                                                          PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
                     WHERE  PickDetail.orderkey = @c_Orderkey
                     ORDER BY PickDetail.PickDetailKey

         OPEN C_PickDetailKey  
     
         FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo   
     
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey) AND @c_PreGenRptData='Y'  
            BEGIN   
               INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
               VALUES (@c_PickDetailKey, @c_RPickSlipNo, @c_OrderKey, @c_OrdLineNo, @c_Loadkey)
         
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3
                  SELECT @n_err = 63503
                   SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookup Failed. (isp_RPT_WV_PLIST_WAVE_019)'    
                  GOTO QUIT
               END                          
            END   


      UPDATE #TMP_PICK  
      SET PickSlipNo = @c_RPickSlipNo  
      WHERE OrderKey = @c_OrderKey  
      AND   ISNULL(PickSlipNo,'') = '' 
      
      SELECT @n_err = @@ERROR  
      IF @n_err <> 0   
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63504
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TMP_PICK Failed. (isp_RPT_WV_PLIST_WAVE_019)'    
         GOTO QUIT
      END
     
      UPDATE PICKDETAIL WITH (ROWLOCK)      
      SET PickSlipNo = @c_RPickSlipNo     
        , EditWho = SUSER_NAME()    
        , EditDate= GETDATE()     
        , TrafficCop = NULL     
      FROM ORDERS     OH WITH (NOLOCK)    
      JOIN PICKDETAIL PD ON (OH.Orderkey = PD.Orderkey) 
      JOIN LOC L ON L.LOC = PD.Loc   
      WHERE PD.OrderKey = @c_OrderKey  
      AND   ISNULL(PickSlipNo,'') = ''  
      AND Pickdetailkey = @c_PickDetailKey AND OrderLineNumber=@c_OrdLineNo
     
      SET @n_err = @@ERROR      
       
      IF @n_err <> 0      
      BEGIN      
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 81009       
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (isp_RPT_WV_PLIST_WAVE_019)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
         GOTO QUIT     
      END  
         
            FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo   
         END   
         CLOSE C_PickDetailKey   
         DEALLOCATE C_PickDetailKey        
      END   
                
     
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END            
              
      SET @c_PreGenRptData = ''   
    
      FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_orderkey   
                              ,  @c_MaxPickslip
   END  
   CLOSE CUR_LOAD  
   DEALLOCATE CUR_LOAD  
   
                                                     
   
   GOTO QUIT    
      
QUIT:  
  
   IF CURSOR_STATUS('LOCAL' , 'CUR_LOAD') in (0 , 1)  
   BEGIN  
      CLOSE CUR_LOAD  
      DEALLOCATE CUR_LOAD  
   END  
  
   IF CURSOR_STATUS('LOCAL' , 'CUR_PICK') in (0 , 1)  
   BEGIN  
      CLOSE CUR_PICK  
      DEALLOCATE CUR_PICK  
   END  
  
   IF @n_Continue=3      
   BEGIN   
      IF @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END   
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_WV_PLIST_WAVE_019'    
   END  
   
   IF ISNULL(@c_PreGenRptData,'') = ''
   BEGIN
     

      SELECT TOP 1 @c_Storerkey = TP.Storerkey
      FROM #TMP_PICK TP

      EXEC [dbo].[isp_GetCompanyInfo]
         @c_Storerkey  = @c_Storerkey
      ,  @c_Type       = @c_LogoType
      ,  @c_DataWindow = @c_DataWindow
      ,  @c_RetVal     = @c_RetVal           OUTPUT


       SET @n_ctnOrd = 0

       SELECT @n_ctnOrd = COUNT(1)
       FROM #TMP_PICK
       WHERE OrderKey <> ''
      
     IF @n_ctnOrd > 1
     BEGIN
      SELECT             
            #TMP_PICK.PickSlipNo     
         ,  #TMP_PICK.LoadKey            
         ,  #TMP_PICK.OrderKey           
         ,  #TMP_PICK.OHNotes2
         ,  #TMP_PICK.C_Company       
         ,  #TMP_PICK.Storerkey
         ,  #TMP_PICK.Wavekey
         ,  #TMP_PICK.ExtOrderkey
         ,  #TMP_PICK.MaxPickslip
         ,  #TMP_PICK.CtnCarton
         ,  ISNULL(@c_RetVal,'') AS Logo
         ,  @n_ctnOrd AS countord
        -- ,  CASE WHEN #TMP_PICK.OHNotes2 <> '' THEN (Row_Number() OVER (PARTITION BY #TMP_PICK.PickSlipNo ORDER BY #TMP_PICK.OrderKey Asc)) ELSE '' END AS LineNumber
      FROM   #TMP_PICK  
      WHERE  #TMP_PICK.OrderKey <> ''
      ORDER BY #TMP_PICK.OrderKey --CASE WHEN #TMP_PICK.OrderKey <> '' THEN 0 ELSE 1 END
      END
      ELSE 
      BEGIN
         SELECT TOP 1            
            #TMP_PICK.PickSlipNo     
         ,  #TMP_PICK.LoadKey            
         ,  #TMP_PICK.OrderKey           
         ,  #TMP_PICK.OHNotes2
         ,  #TMP_PICK.C_Company       
         ,  #TMP_PICK.Storerkey
         ,  #TMP_PICK.Wavekey
         ,  #TMP_PICK.ExtOrderkey
         ,  #TMP_PICK.MaxPickslip
         ,  #TMP_PICK.CtnCarton
         ,  ISNULL(@c_RetVal,'') AS Logo
         ,  @n_ctnOrd AS countord
        -- ,  CASE WHEN #TMP_PICK.OHNotes2 <> '' THEN (Row_Number() OVER (PARTITION BY #TMP_PICK.PickSlipNo ORDER BY #TMP_PICK.OrderKey Asc)) ELSE '' END AS LineNumber
      FROM   #TMP_PICK  
      WHERE PickSlipNo IS NOT NULL
      END
  
   END
     
   IF OBJECT_ID('tempdb..#TMP_PICK') IS NOT NULL
      DROP TABLE #TMP_PICK  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN   
   END  
     
   RETURN  
END      

GO
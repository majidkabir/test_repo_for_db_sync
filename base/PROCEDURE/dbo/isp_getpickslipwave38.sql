SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/
/* Stored Procedure: isp_GetPickSlipWave38                              */
/* Creation Date: 08-Mar-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18895 - [KR] COLLAGE_PickSlip by Load_DW_New            */
/*                                                                      */
/* Called By: RCM - Generate Pickslip                                   */
/*          : Datawindow - r_dw_print_wave_pickslip_38                  */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 08-Mar-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 06-Apr-2022  WLChooi  1.1  Fix - Default Priority Value (WL01)       */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPickSlipWave38] (  
   @c_wavekey_type          NVARCHAR(13)  
)  
AS  
  
BEGIN  
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
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
   
   DECLARE @c_PickHeaderkey      NVARCHAR(10)   
         , @c_Storerkey          NVARCHAR(15)   
         , @c_ST_Company         NVARCHAR(45) 
         , @c_PrevLoadkey        NVARCHAR(10)    
         , @c_Orderkey           NVARCHAR(10)  
         , @c_OrderType          NVARCHAR(10)  
         , @c_ExternOrderkey     NVARCHAR(50)  
         , @c_BuyerPO            NVARCHAR(20)  
         , @c_OrderGroup         NVARCHAR(20)  
         , @c_Sectionkey         NVARCHAR(10)  
         , @c_DeliveryDate       DATE 
         , @c_Consigneekey       NVARCHAR(15)  
         , @c_Priority           NVARCHAR(10)   
         , @c_Route              NVARCHAR(18) 
         , @n_NoOfLine           INT
         , @c_PickZone           NVARCHAR(10)
         , @c_PZone              NVARCHAR(10)
         , @n_MaxRow             INT
         , @n_RowNo              INT
         , @n_CntRowNo           INT
         , @c_OrdLineNo          NVARCHAR(5)
         , @c_GetWavekey         NVARCHAR(10)
         , @c_GetPickSlipNo      NVARCHAR(10)    
         , @c_GetPickZone        NVARCHAR(10)
         , @c_GetOrdKey          NVARCHAR(20)
         , @c_GetLoadkey         NVARCHAR(10)
         , @c_PickDetailKey      NVARCHAR(18) 
         , @c_GetPickDetailKey   NVARCHAR(18) 
         , @n_SumQtyByLoad       INT
          
   SET @n_StartTCnt  =  @@TRANCOUNT  
   SET @n_Continue   =  1    
   SET @c_PickHeaderkey = ''  
   SET @c_Storerkey     = ''  
   SET @c_Consigneekey  = ''     
   SET @c_RPickSlipNo   = ''     
   SET @n_NoOfLine      = 1
   SET @n_CntRowNo      = 1
   
   WHILE @@TranCount > 0    
   BEGIN    
      COMMIT TRAN    
   END   
           
   CREATE TABLE #TMP_PICK  
   (  ReportTitle          NVARCHAR(50),  
      PickslipNoTitle      NVARCHAR(50),  
      PickslipNo           NVARCHAR(10),  
      OHTypeTitle          NVARCHAR(50),  
      OHType               NVARCHAR(10),  
      WavekeyTitle         NVARCHAR(50),  
      Wavekey              NVARCHAR(10),  
      LoadkeyTitle         NVARCHAR(50),  
      Loadkey              NVARCHAR(10),
      CurrentDate          DATETIME,  
      LocTitle             NVARCHAR(50),
      Loc                  NVARCHAR(10),
      SKUTitle             NVARCHAR(50), 
      SKU                  NVARCHAR(20),
      DESCRTitle           NVARCHAR(50),
      DESCR                NVARCHAR(100),
      SUSR1Title           NVARCHAR(50),
      SUSR1                NVARCHAR(50) NULL,
      ChannelTitle         NVARCHAR(50),
      Channel              NVARCHAR(50),
      PackKeyTitle         NVARCHAR(50),
      PackKey              NVARCHAR(10),
      UOMTitle             NVARCHAR(50),
      UOM                  NVARCHAR(10),
      QtyTitle             NVARCHAR(50),
      QTY                  INT,
      TotalQtyTitle        NVARCHAR(50),
      TotalQty             INT,
      LotTitle             NVARCHAR(50),
      Lot                  NVARCHAR(10),
      Lottable04Title      NVARCHAR(50),
      Lottable04           DATETIME NULL,
      TotalEATitle         NVARCHAR(50),
      EAQty                INT,
      TotalCaseTitle       NVARCHAR(50),
      CaseQty              INT,
      TotalTTLTitle        NVARCHAR(50),
      TotalTTLQty          INT,
      PICKDETAILKey        NVARCHAR(10),
      CCLogicalLoc         NVARCHAR(50)
   )

   SET @c_Wavekey = SUBSTRING(@c_wavekey_type, 1, 10)  
   SET @c_Type    = SUBSTRING(@c_wavekey_type, 11,2)      

   INSERT INTO #TMP_PICK  
   SELECT 'COLLAGE ' + CHAR(13) + 'PickSlip by Load'
        , 'PickSlip #'
        , ISNULL(RFL.PickSlipNo,'')
        , 'DocType:'
        , OH.[TYPE]
        , 'WaveKey #'
        , @c_Wavekey
        , 'LoadKey #'
        , OH.LoadKey
        , CONVERT(CHAR(16), GetDate(), 120) 
        , 'Location'
        , PD.Loc
        , 'SKU'
        , PD.Sku
        , 'Descr'
        , S.Descr
        , 'SUSR1'
        , ISNULL(S.SUSR1,'')
        , 'Channel'
        , ''
        , 'PackKey'
        , OD.PackKey
        , 'UOM'
        , OD.UOM
        , 'Qty'
        , PD.UOMQty
        , 'TTL'
        , PD.Qty
        , 'Lot'
        , ''
        , 'Lottable04'
        , LA.Lottable04
        , 'Total EA:'
        , 0
        , 'Total CASE:'
        , 0
        , 'Total TTL:'
        , 0
        , PD.PICKDETAILKey
        , L.CCLogicalLoc
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber 
                              AND PD.SKU = OD.SKU
   JOIN SKU S (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.SKU = PD.SKU
   JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.Lot = PD.Lot
   LEFT JOIN REFKEYLOOKUP RFL (NOLOCK) ON (RFL.PICKDETAILKey = PD.PICKDETAILKey) 
   JOIN LOC L (NOLOCK) ON PD.LOC = L.LOC
   WHERE WD.WaveKey = @c_Wavekey

   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END

   SET @c_Loadkey = ''  
   SET @c_PickDetailKey = ''  
   SET @n_continue = 1

   DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Loadkey, PickDetailKey
   FROM #TMP_PICK  
   WHERE ISNULL(PickSlipNo,'') = ''
   ORDER BY Loadkey, PickDetailKey        
  
   OPEN CUR_LOAD  
     
   FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey
                              ,  @c_GetPickDetailKey
  
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN             
      IF ISNULL(@c_Loadkey, '0') = '0'  
         BREAK  

      SELECT @c_RPickSlipNo = PH.PickHeaderKey
      FROM PICKHEADER PH (NOLOCK)
      WHERE PH.ExternOrderKey = @c_Loadkey
      AND PH.[Zone] = 'LP'
      AND PH.PickType = '0'
      
      IF ISNULL(@c_RPickSlipNo,'') = ''
      BEGIN
         IF @c_PrevLoadkey <> @c_Loadkey
         BEGIN      
            SELECT TOP 1 @c_Storerkey     = OH.Storerkey
                       , @c_Consigneekey  = OH.ConsigneeKey
                       , @c_Priority      = OH.[Priority]
                       , @c_Route         = OH.[Route]
            FROM ORDERS OH (NOLOCK)
            JOIN LOADPLANDETAIL LPD (NOLOCK) ON OH.OrderKey = LPD.OrderKey
            WHERE LPD.LoadKey = @c_Loadkey
         
            SELECT @n_SumQtyByLoad = SUM(TP.TotalTTLQty)
            FROM #TMP_PICK TP
            WHERE TP.Loadkey = @c_Loadkey
         
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
                      ,  StorerKey
                      ,  ConsigneeKey
                      ,  [Priority]
                      ,  [Type]
                      ,  [Zone] 
                      ,  Loadkey    
                      ,  PickType    
                      ,  TrafficCop    
                      )  
               SELECT @c_RPickSlipNo
                    , @c_Wavekey
                    , ''
                    , @c_Loadkey
                    , @c_Storerkey
                    , @c_Consigneekey
                    , '5'   --@c_Priority   --WL01
                    , '5'
                    , 'LP'
                    , @c_Loadkey
                    , '0'
                    , ''

               SET @n_err = @@ERROR
                          
               IF @n_err <> 0      
               BEGIN      
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81008  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave38)'   
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
                  GOTO QUIT     
               END                
            END
            ELSE   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 63502
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PSNO Failed. (isp_GetPickSlipWave38)'  
               BREAK   
            END  
            
            IF @n_Continue = 1  
            BEGIN        
               INSERT INTO RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
               SELECT PD.PickdetailKey, @c_RPickSlipNo, PD.OrderKey, PD.OrderLineNumber 
               FROM LOADPLANDETAIL LPD (NOLOCK)
               JOIN PICKDETAIL PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey 
               LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.Pickdetailkey = RKL.Pickdetailkey             
               WHERE LPD.Loadkey = @c_Loadkey
               AND RKL.Pickdetailkey IS NULL        
            END 
         
            IF NOT EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_RPickSlipNo)
            BEGIN
               INSERT INTO PACKHEADER (PickSlipNo, StorerKey, [Route], OrderKey, LoadKey, ConsigneeKey, TTLCNTS)
               SELECT TOP 1 @c_RPickSlipNo
                          , @c_Storerkey
                          , @c_Route
                          , ''
                          , @c_Loadkey
                          , @c_Consigneekey
                          , @n_SumQtyByLoad
            END
         END   
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM RefKeyLookup RKL (NOLOCK) WHERE RKL.PickDetailkey = @c_GetPickDetailKey)
         BEGIN
            INSERT INTO RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
            SELECT PD.PickdetailKey, @c_RPickSlipNo, PD.OrderKey, PD.OrderLineNumber 
            FROM LOADPLANDETAIL LPD (NOLOCK)
            JOIN PICKDETAIL PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey 
            LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.Pickdetailkey = RKL.Pickdetailkey             
            WHERE LPD.Loadkey = @c_Loadkey
            AND RKL.Pickdetailkey IS NULL  
         END
      END
      
      UPDATE #TMP_PICK  
      SET PickSlipNo = @c_RPickSlipNo  
      WHERE ISNULL(PickSlipNo,'') = '' 
      AND Pickdetailkey = @c_GetPickDetailKey

      SELECT @n_err = @@ERROR  
      IF @n_err <> 0   
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63504
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TMP_PICK Failed. (isp_GetPickSlipWave38)'    
         GOTO QUIT
      END
     
      UPDATE PICKDETAIL WITH (ROWLOCK)      
      SET PickSlipNo = @c_RPickSlipNo     
         ,EditWho = SUSER_NAME()    
         ,EditDate= GETDATE()     
         ,TrafficCop = NULL     
      WHERE Pickdetailkey = @c_GetPickDetailKey
     
      SET @n_err = @@ERROR      
       
      IF @n_err <> 0      
      BEGIN      
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (isp_GetPickSlipWave38)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
         GOTO QUIT     
      END  
     
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END             

      SET @c_PrevLoadkey = @c_Loadkey              
             
      FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey
                                 ,  @c_GetPickDetailKey
   END  
   CLOSE CUR_LOAD  
   DEALLOCATE CUR_LOAD  

QUIT:  
   IF CURSOR_STATUS('LOCAL' , 'CUR_LOAD') in (0 , 1)  
   BEGIN  
      CLOSE CUR_LOAD  
      DEALLOCATE CUR_LOAD  
   END  
  
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN   
      IF @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END   
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave38'    
   END  

   SELECT ReportTitle      
        , PickslipNoTitle  
        , PickslipNo       
        , OHTypeTitle      
        , OHType           
        , WavekeyTitle     
        , Wavekey          
        , LoadkeyTitle     
        , Loadkey          
        , CurrentDate      
        , LocTitle         
        , Loc              
        , SKUTitle         
        , SKU              
        , DESCRTitle       
        , DESCR            
        , SUSR1Title       
        , SUSR1                     
        , ChannelTitle
        , Channel          
        , PackKeyTitle     
        , PackKey          
        , UOMTitle         
        , UOM              
        , QtyTitle         
        , SUM(QTY) AS QTY       
        , TotalQtyTitle    
        , SUM(TotalQty) AS TotalQty               
        , LotTitle         
        , Lot              
        , Lottable04Title  
        , Lottable04       
        , TotalEATitle     
        , CASE WHEN UOM = 'EA'
               THEN SUM(Qty)
               ELSE 0
          END AS EAQty            
        , TotalCaseTitle   
        , CASE WHEN UOM = 'CASE'
               THEN SUM(Qty)
               ELSE 0
          END AS CaseQty          
        , TotalTTLTitle    
        , TotalTTLQty  
   FROM #TMP_PICK TP
   GROUP BY ReportTitle      
        , PickslipNoTitle  
        , PickslipNo       
        , OHTypeTitle      
        , OHType           
        , WavekeyTitle     
        , Wavekey          
        , LoadkeyTitle     
        , Loadkey          
        , CurrentDate      
        , LocTitle         
        , Loc              
        , SKUTitle         
        , SKU              
        , DESCRTitle       
        , DESCR            
        , SUSR1Title       
        , SUSR1                      
        , ChannelTitle
        , Channel             
        , PackKeyTitle     
        , PackKey          
        , UOMTitle         
        , UOM              
        , QtyTitle                       
        , TotalQtyTitle                   
        , LotTitle         
        , Lot              
        , Lottable04Title  
        , Lottable04       
        , TotalEATitle                
        , TotalCaseTitle           
        , TotalTTLTitle    
        , TotalTTLQty 
        , CCLogicalLoc
   ORDER BY Loadkey, CCLogicalLoc
 
   IF OBJECT_ID('tempdb..#TMP_PICK') IS NOT NULL
      DROP TABLE #TMP_PICK
   
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN   
   END  
     
   RETURN  
END  

GO
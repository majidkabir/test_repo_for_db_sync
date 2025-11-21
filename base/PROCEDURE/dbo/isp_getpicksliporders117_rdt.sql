SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_GetPickSlipOrders117_rdt                            */  
/* Creation Date: 04-Feb-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-16311 - HM India - Outbound Pick Slip Report            */  
/*        : Copy from isp_GetPickSlipWave24                             */  
/*                                                                      */
/* Called By: r_dw_print_pickorder117_rdt                               */  
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 04-Feb-2021 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/  
CREATE PROC [dbo].[isp_GetPickSlipOrders117_rdt]
           @c_Loadkey       NVARCHAR(10)  

AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_ErrMsg          NVARCHAR(255)   

         , @n_RowNum          INT  
         , @c_PickSlipNo      NVARCHAR(10)  
         , @c_PickSlipNo_PD   NVARCHAR(10)  
         , @c_Zone            NVARCHAR(10)  
    
         , @c_PickDetailKey   NVARCHAR(10)  
         , @c_Orderkey        NVARCHAR(10)  
         , @c_OrderLineNumber NVARCHAR(5)  
           
         , @CUR_PSLIP         CURSOR  
         , @CUR_PD            CURSOR  
         , @CUR_PACKSLIP      CURSOR  

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
  
   CREATE TABLE #TMP_PSLIP  
   (  
         RowNum            INT   IDENTITY(1,1)  NOT NULL PRIMARY KEY  
      ,  Storerkey         NVARCHAR(15)   NULL  
      ,  Loadkey           NVARCHAR(10)   NULL  
      ,  PickHeaderKey     NVARCHAR(10)   NULL  
      ,  PutawayZone       NVARCHAR(10)   NULL  
      ,  Printedflag       NCHAR(1)       NULL  
      ,  NoOfSku           INT            NULL  
      ,  NoOfPickLines     INT            NULL
      ,	OrdSelectkey	   NVARCHAR(20)   NULL
      ,  ColorCode			NVARCHAR(20)   NULL  
   )  

   INSERT INTO #TMP_PSLIP                                            
      (  Storerkey       
      ,  Loadkey         
      ,  PickHeaderKey     
      ,  PutawayZone   
      ,  Printedflag    
      ,  NoOfSku          
      ,  NoOfPickLines 
      ,  OrdSelectkey
      ,	ColorCode       
      )                             
   SELECT PD.Storerkey  
         ,LPD.Loadkey  
         ,PickHeaderKey = ISNULL(RTRIM(PH.PickHeaderkey), '')  
         ,LOC.PutawayZone                                              
         ,Printedflag = CASE WHEN ISNULL(RTRIM(PH.PickHeaderkey), '') =  '' THEN 'N' ELSE 'Y' END  
         ,NoOfSku= COUNT(DISTINCT PD.Sku)  
         ,NoOfPickLines= COUNT(DISTINCT PD.PickDetailkey)
         ,Orderselectionkey = ''
         ,ColorCode = ''
   FROM LOADPLANDETAIL LPD   WITH (NOLOCK)    
   JOIN PICKDETAIL PD   WITH (NOLOCK) ON (LPD.Orderkey= PD.Orderkey)  
   JOIN LOC        LOC  WITH (NOLOCK) ON (PD.Loc = LOC.Loc)                      
   LEFT JOIN REFKEYLOOKUP RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)  
   LEFT JOIN PICKHEADER   PH WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderkey)  
   WHERE LPD.Loadkey = @c_Loadkey  
   AND   PD.Status < '5'
   GROUP BY PD.Storerkey  
         ,  LPD.Loadkey  
         ,  ISNULL(RTRIM(PH.PickHeaderkey), '')  
         ,  LOC.PutawayZone                                               
   ORDER BY ISNULL(RTRIM(PH.PickHeaderkey), '')   
         ,  LOC.PutawayZone                                               
  
   SET @CUR_PSLIP = CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT   RowNum  
         ,  PickHeaderKey   
         ,  PutawayZone  
   FROM #TMP_PSLIP  
   ORDER BY RowNum  
  
   OPEN @CUR_PSLIP  
  
   FETCH NEXT FROM @CUR_PSLIP INTO @n_RowNum, @c_PickSlipNo, @c_Zone  
  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @c_PickSlipNo = ''    
      BEGIN  
         EXECUTE nspg_GetKey         
                  'PICKSLIP'      
               ,  9      
               ,  @c_PickSlipNo  OUTPUT      
               ,  @b_Success     OUTPUT      
               ,  @n_err         OUTPUT      
               ,  @c_errmsg      OUTPUT   
                          
         IF @b_success <> 1     
         BEGIN      
            SET @n_continue = 3    
            SET @n_err = 81010  
            SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PickSlip # Failed. (isp_GetPickSlipOrders117_rdt)'    
            BREAK     
         END               
   
         SET @c_PickSlipNo = 'P' + @c_PickSlipNo            
                        
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
                  (  @c_PickSlipNo      
                  ,  ''      
                  ,  ''  
                  ,  @c_PickSlipNo     
                  ,  @c_Loadkey   
                  ,  '0'       
                  ,  'LP'    
                  ,  @c_Zone    
                  ,  ''      
                  )            
               
         SET @n_err = @@ERROR        
         IF @n_err <> 0        
         BEGIN        
            SET @n_continue = 3        
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)      
            SET @n_err = 81020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipOrders117_rdt)'     
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '     
            GOTO QUIT_SP       
         END    
     
         UPDATE #TMP_PSLIP  
         SET PickHeaderKey = @c_PickSlipNo  
         WHERE RowNum = @n_RowNum  
         AND PickHeaderkey = ''  
      END           
     
      SET @CUR_PD = CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT   PD.PickDetailKey     
            ,  PD.Orderkey  
            ,  PD.OrderLineNumber  
            ,  ISNULL(RTRIM(PD.PickSlipNo),'')  
      FROM LOADPLANDETAIL LPD  WITH (NOLOCK)   
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)  
      JOIN LOC        LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)                 
      WHERE LPD.Loadkey = @c_Loadkey  
      AND   LOC.PutawayZone = @c_Zone                                        
      ORDER BY PD.PickDetailKey         
  
      OPEN @CUR_PD  
  
      FETCH NEXT FROM @CUR_PD INTO @c_PickDetailKey  
                                 , @c_Orderkey  
                                 , @c_OrderLineNumber  
                                 , @c_PickSlipNo_PD  
  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         IF NOT EXISTS (SELECT 1   
                        FROM REFKEYLOOKUP RL WITH (NOLOCK)   
                        WHERE PickDetailKey = @c_PickDetailKey)  
         BEGIN  
            INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber )    
            VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber)  
  
            SET @n_err = @@ERROR    
            IF @n_err <> 0     
            BEGIN    
               SET @n_continue = 3  
               SET @n_err = 81030  
               SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookup Failed. (isp_GetPickSlipOrders117_rdt)'      
               GOTO QUIT_SP  
            END                  
         END  
  
         IF @c_PickSlipNo <> @c_PickSlipNo_PD  
         BEGIN  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET PickSlipNo = @c_PickSlipNo  
               ,EditWho    = SUSER_NAME()  
               ,EditDate   = GETDATE()  
               ,Trafficcop = NULL  
            WHERE PickDetailkey = @c_PickDetailKey  
  
            SET @n_err = @@ERROR        
            IF @n_err <> 0        
            BEGIN        
               SET @n_continue = 3        
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)      
               SET @n_err = 81040 -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (isp_GetPickSlipOrders117_rdt)'     
                              + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '     
               GOTO QUIT_SP       
            END   
         END  
  
         FETCH NEXT FROM @CUR_PD INTO @c_PickDetailKey  
                                    , @c_Orderkey  
                                    , @c_OrderLineNumber  
                                    , @c_PickSlipNo_PD  
      END  
  
      CLOSE @CUR_PD  
      DEALLOCATE @CUR_PD  
  
      FETCH NEXT FROM @CUR_PSLIP INTO @n_RowNum, @c_PickSlipNo, @c_Zone  
  
   END  
   CLOSE @CUR_PSLIP  
   DEALLOCATE @CUR_PSLIP  
  
   SET @CUR_PACKSLIP = CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT OH.Orderkey     
         ,LPD.LoadKey  
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)  
   JOIN ORDERS          OH WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)  
   LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey)  
                                         --AND(OH.Loadkey  = PH.ExternOrderkey)  
   WHERE LPD.Loadkey = @c_Loadkey   
   AND   PH.PickHeaderKey IS NULL  
   
   OPEN @CUR_PACKSLIP  
  
   FETCH NEXT FROM @CUR_PACKSLIP INTO @c_Orderkey  
                                    , @c_Loadkey  
                            
  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      SET @c_PickSlipNo = ''  
      EXECUTE nspg_GetKey         
               'PICKSLIP'      
            ,  9      
            ,  @c_PickSlipNo  OUTPUT      
            ,  @b_Success     OUTPUT      
            ,  @n_err         OUTPUT      
            ,  @c_errmsg      OUTPUT   
                          
      IF @b_success <> 1     
      BEGIN      
         SET @n_continue = 3    
         SET @n_err = 81050  
         SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PickSlip # Failed. (isp_GetPickSlipOrders117_rdt)'    
         BREAK     
      END               
   
      SET @c_PickSlipNo = 'P' + @c_PickSlipNo            
                        
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
               (  @c_PickSlipNo      
               ,  ''      
               ,  @c_Orderkey  
               ,  @c_Loadkey   
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
         SET @n_err = 81060  -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipOrders117_rdt)'     
                        + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '     
         GOTO QUIT_SP       
      END    
  
      FETCH NEXT FROM @CUR_PACKSLIP INTO @c_Orderkey  
                                       , @c_Loadkey  
   END  
   CLOSE @CUR_PACKSLIP  
   DEALLOCATE @CUR_PACKSLIP  
   
QUIT_SP:  
   SELECT   TMP.Storerkey  
         ,  TMP.Loadkey  
         ,  TMP.PickHeaderkey  
         ,  TMP.PutawayZone  
         ,  TMP.Printedflag  
         ,  TMP.NoOfSku          
         ,  TMP.NoOfPickLines   
         ,  TMP.OrdSelectkey
         ,  TMP.ColorCode 
   FROM #TMP_PSLIP TMP  
   ORDER BY TMP.PickHeaderKey  
         ,  TMP.PutawayZone  
     
   IF CURSOR_STATUS( 'VARIABLE', '@CUR_PSLIP') in (0 , 1)    
   BEGIN  
      CLOSE @CUR_PSLIP  
      DEALLOCATE @CUR_PSLIP  
   END  
  
   IF CURSOR_STATUS( 'VARIABLE', '@CUR_PD') in (0 , 1)    
   BEGIN  
      CLOSE @CUR_PD  
      DEALLOCATE @CUR_PD  
   END  
  
   IF CURSOR_STATUS( 'VARIABLE', '@CUR_PACKSLIP') in (0 , 1)    
   BEGIN  
      CLOSE @CUR_PACKSLIP  
      DEALLOCATE @CUR_PACKSLIP  
   END  
  
  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPickSlipOrders117_rdt'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END -- procedure

GO
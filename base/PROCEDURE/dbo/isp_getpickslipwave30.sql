SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_GetPickSlipWave30                              */  
/* Creation Date: 29-JUN-2021                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-17294 SG - aCommerce Adidas - Picking Slip Summary      */     
/*                                                                      */  
/* Called By: RCM - Generate Pickslip                                   */  
/*          : Datawindow - r_dw_print_wave_pickslip_30                  */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Purposes                                       */ 
/* 21-JUL-2021  CSCHONG  WMS-17294 revised field logic (CS01)           */
/* 10-DEC-2021  MINGLE   WMS-18541 add filter (ML01)                    */
/* 10-DEC-2021  Mingle   DevOps Combine Script                          */
/* 11-May-2022  WLChooi  WMS-19648 - Remove Validation control by report*/
/*                       config (WL01)                                  */
/* 24-Jun-2022 CSCHONG   WMS-20054 revised sorting rule (CS02)          */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GetPickSlipWave30] (  
@c_wavekey          NVARCHAR(13)  
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
           
   DECLARE 
           @c_Loadkey            NVARCHAR(10)  
         , @c_PickSlipNo         NVARCHAR(10)  
         , @c_RPickSlipNo        NVARCHAR(10)  
         , @c_PrintedFlag        NVARCHAR(1)   
   
   DECLARE @c_PickHeaderkey      NVARCHAR(10)   
         , @c_Storerkey          NVARCHAR(15)   
         , @c_ST_Company         NVARCHAR(45)  
         , @c_Orderkey           NVARCHAR(10)  
         , @c_PreOrderkey        NVARCHAR(10)
         , @c_OrderGroup         NVARCHAR(20)     
         , @c_PAZone             NVARCHAR(10) 
         , @c_PrevPAZone         NVARCHAR(10)
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
         , @n_NoFilterDocType    INT   --WL01
          
   SET @n_StartTCnt  =  @@TRANCOUNT  
   SET @n_Continue   =  1    
   SET @c_PickHeaderkey = ''  
   SET @c_Storerkey     = ''  
   SET @c_ST_Company    = ''  
   SET @c_Orderkey      = ''  
   SET @c_PreOrderkey   = ''      
   SET @c_RPickSlipNo   = ''                  
   SET @n_NoOfLine      =  1
   SET @c_GetStorerkey  = ''
   SET @n_CntRowNo      = 1

  
   WHILE @@TranCount > 0    
   BEGIN    
      COMMIT TRAN    
   END   
           
   CREATE TABLE #TMP_PICK  
   (  PickSlipNo         NVARCHAR(10) NULL,  
      LoadKey            NVARCHAR(10),  
      OrderKey           NVARCHAR(10),  
      OHUDF09            NVARCHAR(10) NULL,  
      Qty                int, 
      PrintedFlag        NVARCHAR(1) NULL,    
      Storerkey          NVARCHAR(15) NULL, 
      OrderGrp           NVARCHAR(20) NULL,
      Wavekey            NVARCHAR(10) NULL,
      GPAZone            NVARCHAR(10) NULL,
      PAZone             NVARCHAR(10) NULL,
      Pickdetailkey      NVARCHAR(20) NULL  )     
      
      
   SELECT TOP 1 @c_GetStorerkey = ORD.Storerkey
   FROM WAVEDETAIL WD  WITH (NOLOCK)
   JOIN ORDERS ORD WITH (NOLOCK) ON WD.Orderkey = ORD.OrderKey
   WHERE WD.Wavekey = @c_Wavekey      

   --WL01 S
   SELECT @n_NoFilterDocType  = ISNULL(MAX(CASE WHEN CL.Code = 'NoFilterDocType' THEN 1 ELSE 0 END),0)  
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'REPORTCFG'
   AND CL.Long = 'r_dw_print_wave_pickslip_30'
   AND (CL.Short IS NULL OR CL.Short <> 'N')
   AND CL.Storerkey = @c_GetStorerkey
   --WL01 E
      
   INSERT INTO #TMP_PICK  
         (  
           PickSlipNo,  
           LoadKey, 
           OrderKey,  
           OHUDF09,   
           Qty,  
           PrintedFlag, 
           Storerkey,  
           OrderGrp,wavekey,GPAZone,PAZone,Pickdetailkey)                
   SELECT DISTINCT RefKeyLookup.PickSlipNo,  
          orders.loadkey                   AS LoadKey,
          orders.orderkey                  AS Orderkey,   
          ISNULL(ORDERS.UserDefine09, '') AS OHUDF09,   
          SUM(PickDetail.qty)            AS Qty,    
          ISNULL((SELECT Distinct 'Y' FROM pickdetail WITH (NOLOCK) WHERE pickdetail.PickSlipNo = RefKeyLookup.PickSlipNo), 'N') AS PrintedFlag,  
          ORDERS.Storerkey,  
          --ORDERS.OrderGroup,                                             --CS01
          CASE ORDERS.ECOM_SINGLE_Flag WHEN 'M' THEN 'MULTI'
                                       WHEN 'S' THEN 'SINGLE'         
                                       ELSE  ORDERS.ECOM_SINGLE_Flag END,                                          --CS01
          wd.WaveKey,
          UPPER(SUBSTRING(loc.pickzone,1,2)) AS GPAZone,
          loc.PickZone AS PAZone,
          pickdetail.pickdetailkey
   FROM WAVEDETAIL      WD  WITH (NOLOCK) 
   JOIN pickdetail WITH (NOLOCK)  ON pickdetail.OrderKey = WD.OrderKey 
   LEFT JOIN Pickheader WITH (NOLOCK) ON PickHeader.ExternOrderkey = pickdetail.PickSlipNo
   JOIN orders WITH (NOLOCK) ON  pickdetail.orderkey = orders.orderkey  
   JOIN loc WITH (NOLOCK) ON  pickdetail.loc = loc.loc  
   left outer join RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey) 
   WHERE WD.WaveKey = @c_waveKey
   AND (ORDERS.Doctype = 'E' OR @n_NoFilterDocType = 1)   --ML01   --WL01
   GROUP BY RefKeyLookup.PickSlipNo,orders.loadkey ,orders.orderkey ,
            ISNULL(ORDERS.UserDefine09, '') ,      
            ORDERS.Storerkey,  
          --ORDERS.OrderGroup,                                              --CS01
            CASE ORDERS.ECOM_SINGLE_Flag WHEN 'M' THEN 'MULTI'
                                         WHEN 'S' THEN 'SINGLE'         
                                         ELSE  ORDERS.ECOM_SINGLE_Flag END,                                          --CS01
          wd.WaveKey,
          UPPER(SUBSTRING(loc.pickzone,1,2)),
          loc.PickZone ,pickdetail.pickdetailkey
ORDER BY pickdetail.pickdetailkey,orders.orderkey,loc.PickZone                                      
               
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END
     
   SET @c_OrderKey = '' 
   SET @c_PreOrderkey ='' 
   SET @c_Pickzone = ''
   SET @c_PrevPAzone = ''
   SET @c_PickDetailKey = ''  
   SET @n_continue = 1
    
   DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT loadkey 
         ,  orderkey  
         ,  PAZone
         ,  PickDetailKey
   FROM #TMP_PICK  
   WHERE  ISNULL(PickSlipNo,'') = ''
   ORDER BY PAZone,PickDetailKey        
  
   OPEN CUR_LOAD  
     
   FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_Orderkey
                                ,@c_PZone
                                ,@c_GetPickDetailKey
  
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN             
     IF ISNULL(@c_Orderkey, '0') = '0'  
        BREAK  
                  
     IF @c_PrevPAZone <> @c_PZone  --AND NOT EXISTS (SELECT 1 FROM dbo.PICKHEADER (NOLOCK) WHERE orderkey = @c_Orderkey)        
     --IF @c_PreOrderkey <> @c_Orderkey
     --IF NOT EXISTS (SELECT 1 FROM dbo.PICKHEADER (NOLOCK) WHERE consoorderkey = @c_PZone AND Wavekey = @c_wavekey AND LoadKey = @c_Loadkey)    
     BEGIN
         --IF NOT EXISTS (SELECT 1 FROM dbo.PICKHEADER (NOLOCK) WHERE Wavekey = @c_wavekey AND orderkey = @c_Orderkey)
         --BEGIN                 
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

     --SELECT @c_PrevPAZone '@c_PrevPAZone',@c_PZone '@c_PZone', @c_RPickSlipNo '@c_RPickSlipNo'
                      
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
                        ,  '' 
                        ,  @c_RPickSlipNo   
                        ,  @c_Loadkey    
                        ,  '0'     
                        ,  'LP'  
                        ,  @c_PZone     
                        ,  ''    
                        )          
            
                 SET @n_err = @@ERROR
                       
                 IF @n_err <> 0      
                 BEGIN      
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81008  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave30)'   
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
                  GOTO QUIT     
                 END                
            END
            ELSE   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 63502
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PSNO Failed. (isp_GetPickSlipWave30)'  
               BREAK   
            END    
      --END        
     END            
       
     IF @n_Continue = 1  
     BEGIN        
        DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber 
         FROM   PickDetail WITH (NOLOCK) 
         JOIN   OrderDetail WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND 
                                              PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) 
         JOIN   LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
         WHERE  PickDetail.pickdetailkey = @c_GetPickDetailKey 
         AND    OrderDetail.LoadKey  =  @c_LoadKey  
         AND LOC.pickzone = RTRIM(@c_Pzone) 
         ORDER BY PickDetail.PickDetailKey
     
        OPEN C_PickDetailKey 
        FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo   
     
        WHILE @@FETCH_STATUS <> -1  
        BEGIN  
           IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)   
           BEGIN   
              INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
              VALUES (@c_PickDetailKey, @c_RPickSlipNo, @c_OrderKey, @c_OrdLineNo, @c_Loadkey)

              SELECT @n_err = @@ERROR  
              IF @n_err <> 0   
              BEGIN  
                 SELECT @n_continue = 3
                 SELECT @n_err = 63503
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookup Failed. (isp_GetPickSlipWave30)'    
                 GOTO QUIT
              END                          
           END   
     
           FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo   
        END   
        CLOSE C_PickDetailKey   
        DEALLOCATE C_PickDetailKey        
     END   
                
     UPDATE #TMP_PICK  
     SET PickSlipNo = @c_RPickSlipNo  
     WHERE OrderKey = @c_OrderKey  
     AND   PAzone = @c_Pzone
     AND   ISNULL(PickSlipNo,'') = '' 
     AND Pickdetailkey = @c_GetPickDetailKey

     SELECT @n_err = @@ERROR  
     IF @n_err <> 0   
     BEGIN  
        SELECT @n_continue = 3  
        SELECT @n_err = 63504
        SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TMP_PICK Failed. (isp_GetPickSlipWave30)'    
        GOTO QUIT
     END
     
       UPDATE PICKDETAIL WITH (ROWLOCK)      
       SET PickSlipNo = @c_RPickSlipNo     
         ,EditWho = SUSER_NAME()    
           ,EditDate= GETDATE()     
           ,TrafficCop = NULL     
       FROM ORDERS     OH WITH (NOLOCK)    
       JOIN PICKDETAIL PD ON (OH.Orderkey = PD.Orderkey) 
       JOIN LOC L ON L.LOC = PD.Loc   
       WHERE PD.OrderKey = @c_OrderKey  
     AND L.pickzone = @c_PZone
     AND   ISNULL(PickSlipNo,'') = ''  
     AND Pickdetailkey = @c_GetPickDetailKey
     
       SET @n_err = @@ERROR      
       
       IF @n_err <> 0      
       BEGIN      
           SET @n_continue = 3      
           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
           SET @n_err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (isp_GetPickSlipWave30)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
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
     SET @c_PrevPAzone = @c_Pzone                 
      --SET @c_PreOrderkey = @c_Orderkey
             
     FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_Orderkey  
                                ,  @c_PZone
                                , @c_GetPickDetailKey
   END  
   CLOSE CUR_LOAD  
   DEALLOCATE CUR_LOAD    

      DECLARE CUR_WaveOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT   
             WD.Wavekey  
            ,LPD.LoadKey  
            ,'' 
            ,WD.Orderkey
      FROM WAVEDETAIL      WD  WITH (NOLOCK)  
      JOIN LOADPLANDETAIL  LPD WITH (NOLOCK) ON (WD.Orderkey = LPD.Orderkey)  
      JOIN PICKDETAIL AS PDET ON PDET.OrderKey = WD.OrderKey
      JOIN LOC L WITH (NOLOCK) ON L.LOC = PDET.Loc
      WHERE WD.WaveKey = @c_Wavekey                                        
                                          
   OPEN CUR_WaveOrder 
   
   FETCH NEXT FROM CUR_WaveOrder INTO @c_GetWavekey,@c_GetLoadkey,@c_GetPHOrdKey,@c_GetWDOrdKey
   
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN           
       
       IF NOT EXISTS (SELECT 1 FROM PICKHEADER (NOLOCK)   
                      WHERE wavekey      = @c_Wavekey 
                      AND Orderkey       = @c_GetWDOrdKey)         
       BEGIN               
          BEGIN TRAN
          EXECUTE nspg_GetKey       
                   'PICKSLIP'    
                ,  9    
                ,  @c_Pickslipno OUTPUT    
                ,  @b_Success    OUTPUT    
                ,  @n_err        OUTPUT    
                ,  @c_errmsg     OUTPUT          
                           
          SET @c_Pickslipno = 'P' + @c_Pickslipno    
                    

            --SELECT @c_GetWDOrdKey '@c_GetWDOrdKey', @c_Pickslipno '@c_Pickslipno'

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
                   (  @c_Pickslipno    
                   ,  @c_Wavekey    
                   ,  @c_GetWDOrdKey   
                   ,  @c_Pickslipno   
                   ,  @c_GetLoadkey 
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
                    SET @n_err = 81008  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave30)'   
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
                    GOTO QUIT     
                END      
       END   
              
       WHILE @@TRANCOUNT > 0  
       BEGIN  
          COMMIT TRAN  
       END  
     
       FETCH NEXT FROM  CUR_WaveOrder INTO @c_GetWavekey,@c_GetLoadkey,@c_GetPHOrdKey,@c_GetWDOrdKey
   END     
   CLOSE CUR_WaveOrder  
   DEALLOCATE CUR_WaveOrder   

    --SELECT * FROM #TMP_PICK                                                
   
   GOTO QUIT    
      
QUIT:  
  
  
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN   
      IF @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END   
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave30'    
   END  
      
  
   SELECT             
         #TMP_PICK.PickSlipNo     
      ,  #TMP_PICK.Wavekey          
      ,  SUM(#TMP_PICK.Qty) AS Qty                         
      ,  #TMP_PICK.Storerkey          
      ,  #TMP_PICK.OrderGrp 
      ,  #TMP_PICK.OHUDF09
      ,  #TMP_Pick.GPAZone,#TMP_PICK.PAZone         
   FROM   #TMP_PICK  
  GROUP BY #TMP_PICK.PickSlipNo     
      ,  #TMP_PICK.Wavekey ,  #TMP_PICK.Storerkey          
      ,  #TMP_PICK.OrderGrp,#TMP_Pick.GPAZone,#TMP_PICK.PAZone  
      ,  #TMP_PICK.OHUDF09 
   --ORDER BY #TMP_PICK.PickSlipNo,#TMP_PICK.GPAZone,#TMP_PICK.PAZone     --CS02
    ORDER BY #TMP_PICK.GPAZone,#TMP_PICK.PAZone      --CS02
     
  --SELECT '1' AS PickSlipNo
  
  DROP TABLE #TMP_PICK  
  
  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN   
   END  
     
   RETURN  
END  

GO
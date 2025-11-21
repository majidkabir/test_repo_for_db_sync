SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
      
/************************************************************************/      
/* Stored Procedure: isp_GetPickSlipWave29                              */      
/* Creation Date: 06-JAN-2021                                           */      
/* Copyright: IDS                                                       */      
/* Written by: CSCHONG                                                  */      
/*                                                                      */      
/* Purpose: WMS-15994 - RG - Lego - Picking Slip                        */      
/*                                                                      */      
/* Called By: RCM - Generate Pickslip                                   */      
/*          : Datawindow - r_dw_print_wave_pickslip_29                  */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Purposes                                       */     
/* 26-MAR-21    CSCHONG  WMS-15994 fix split line carton issue (CS01)   */    
/* 14-APR-21    MINGLE   WMS-16758 add new mappings(ML01)               */    
/* 31-MAY-21    MINGLE   WMS-17131 add new mappings(ML02)               */    
/* 23-MAY-23    CALVIN   JSM-150842 Adjust Sorting (CLVN01)             */  
/* 25-MAY-23    IAN      JSM-150842 Adjust Sorting (IAN01)              */  
/* 09-JUN-23    CSCHONG  WMS-22719 add report config (CS02)             */
/************************************************************************/      
      
CREATE   PROC [dbo].[isp_GetPickSlipWave29] (      
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
         , @c_PreOrderkey        NVARCHAR(10)        
         , @c_Orderkey           NVARCHAR(10)      
         , @c_OrderType          NVARCHAR(10)      
         , @c_Stop               NVARCHAR(10)      
         , @c_ExternOrderkey     NVARCHAR(30)      
         , @c_BuyerPO            NVARCHAR(20)      
         , @c_OrderGroup         NVARCHAR(20)      
         , @c_Sectionkey         NVARCHAR(10)      
         , @c_DeliveryDate       DATE     
         , @c_Consigneekey       NVARCHAR(15)      
         , @c_C_Company          NVARCHAR(50)                                                      
         , @n_TotalCBM           FLOAT         
         , @n_TotalGrossWgt      FLOAT      
         , @n_noOfTotes          INT        
         , @c_PAZone             NVARCHAR(10)     
         , @c_PrevPAZone         NVARCHAR(10)     
         , @c_PADescr            NVARCHAR(60)       
         , @c_LogicalLoc         NVARCHAR(18)      
         , @c_Sku                NVARCHAR(20)      
         , @c_SkuDescr     NVARCHAR(60)      
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
         , @c_ExecArguments      NVARCHAR(4000)    
         , @n_hidepickzone       INT   --CS02
              
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
   --SET @n_MaxRow =  1      
      
   WHILE @@TranCount > 0        
   BEGIN        
      COMMIT TRAN        
   END       
               
   CREATE TABLE #TMP_PICK      
   (  PickSlipNo         NVARCHAR(10) NULL,      
      LoadKey            NVARCHAR(10),      
      OrderKey           NVARCHAR(10),      
      ConsigneeKey       NVARCHAR(15),      
      c_Company            NVARCHAR(45),      
      LOC                NVARCHAR(10) NULL,      
      SKU                NVARCHAR(20),      
      SkuDesc            NVARCHAR(60),      
      Qty                INT,      
      LOCZone            NVARCHAR(10) NULL,      
      --Pallet_cal         INT DEFAULT(0),      
      Cartons_cal        INT DEFAULT(0),      
      --inner_cal          INT DEFAULT(0),      
      Each_cal           INT  DEFAULT(0),      
      --Total_cal          INT DEFAULT(0),       
      SKUGROUP           NVARCHAR(10) NULL,      
      Storerkey          NVARCHAR(15) NULL,     
      Wavekey            NVARCHAR(10) NULL,    
      Pickdetailkey      NVARCHAR(20) NULL,    
      packcasecnt        FLOAT,    
      ExtOrderkey        NVARCHAR(50) NULL,    
      --ML01 START    
      DeliveryDate       DATE,    
      Route              NVARCHAR(20),    
      c_Address1           NVARCHAR(45),    
      c_Address2           NVARCHAR(45),    
      c_Address3           NVARCHAR(45),    
      c_Address4           NVARCHAR(45),    
      c_Zip                NVARCHAR(10),    
      c_City               NVARCHAR(45),    
      c_State              NVARCHAR(10),    
      c_Country            NVARCHAR(10),    
      --ML01 END    
      --ML02 START    
      BillToKey            NVARCHAR(20),    
      b_Company        NVARCHAR(45),        
      b_Address1           NVARCHAR(45),    
      b_Address2           NVARCHAR(45),    
      b_Address3           NVARCHAR(45),    
      b_Address4           NVARCHAR(45),    
      b_Zip                NVARCHAR(10),    
      b_City               NVARCHAR(45),    
      b_State              NVARCHAR(10),    
      b_Country            NVARCHAR(10),    
      --ML02 END     
)        
          
          
   CREATE TABLE #TEMP_PICKBYZONE    
   (  Pickslipno NVARCHAR(10),     
      LOCZone    NVARCHAR(10) NULL      
      )       
      
   SET @c_Wavekey = SUBSTRING(@c_wavekey_type, 1, 10)      
   SET @c_Type    = SUBSTRING(@c_wavekey_type, 11,2)      
          
   SELECT TOP 1 @c_GetStorerkey = ORD.Storerkey    
   FROM WAVEDETAIL WD  WITH (NOLOCK)    
   JOIN ORDERS ORD WITH (NOLOCK) ON WD.Orderkey = ORD.OrderKey    
   WHERE WD.Wavekey = @c_Wavekey        


   --CS02 S
   SELECT @n_hidepickzone    = ISNULL(MAX(CASE WHEN Code = 'HIDELOCZONE' THEN 1 ELSE 0 END),0) 
   FROM CODELKUP WITH (NOLOCK)    
   WHERE ListName = 'REPORTCFG'    
   AND   Storerkey= @c_GetStorerkey    
   AND   Long = 'r_dw_print_wave_pickslip_29'    
   AND   ISNULL(Short,'') <> 'N' 
   --CS02 E 
       
          
   INSERT INTO #TMP_PICK      
         (      
           PickSlipNo,     
           loadkey,OrderKey,     
           ConsigneeKey,      
           c_Company,      
           LOC,       
           SKU,      
           SkuDesc,      
           Qty,      
           LOCZone,      
           Cartons_cal,      
           Each_cal,      
           SKUGROUP,      
           Storerkey,      
           wavekey,    
           Pickdetailkey,    
           packcasecnt,    
           ExtOrderkey,    
           --ML01 START    
           DeliveryDate,    
           Route,    
           c_Address1,    
           c_Address2,    
           c_Address3,    
           c_Address4,    
           c_Zip,    
           c_City,    
           c_State,    
           c_Country,    
           --ML01 END    
           --ML02 START    
           BillToKey,    
           b_Company,    
           b_Address1,    
           b_Address2,    
           b_Address3,    
           b_Address4,    
           b_Zip,    
           b_City,    
           b_State,    
           b_Country    
           --ML02 END    
           )                    
   SELECT DISTINCT RefKeyLookup.PickSlipNo,      
          ORDERS.LoadKey,ORDERS.OrderKey,    
          ISNULL(ORDERS.ConsigneeKey, '') AS ConsigneeKey,      
          ISNULL(ORDERS.c_Company, ''),         
          PickDetail.loc,       
          PickDetail.sku,      
          ISNULL(Sku.Descr, '')  AS  SkuDescr,      
          SUM(PickDetail.qty)            AS Qty,      
          loc.PickZone AS LOCZone,        
          Cartons_cal = CASE Pack.Casecnt      
                            WHEN 0 THEN 0      
                            ELSE FLOOR(SUM(PickDetail.qty) / (Pack.Casecnt))      
                       END,       
          Each_cal    = CASE Pack.Casecnt      
                            WHEN 0 THEN 0      
                            ELSE FLOOR(SUM(PickDetail.qty) % CAST(Pack.Casecnt AS INT))      
                       END,       
          SKU.SKUGROUP,      
          ORDERS.Storerkey,      
          wd.WaveKey,    
          pickdetail.PickDetailKey,    
          pack.casecnt,    
          orders.externorderkey,    
          --ML01 START    
          ISNULL(ORDERS.DeliveryDate, ''),     
          orders.Route,    
          ISNULL(ORDERS.c_Address1, ''),       
          ISNULL(ORDERS.c_Address2, ''),       
          ISNULL(ORDERS.c_Address3, ''),      
          ISNULL(ORDERS.c_Address4, ''),       
          ISNULL(ORDERS.c_Zip, ''),       
          ISNULL(ORDERS.c_City, ''),       
          ISNULL(ORDERS.c_State, ''),       
          ISNULL(ORDERS.c_Country, ''),    
          --ML01 END    
          --ML02 START     
          ISNULL(ORDERS.BillToKey,''),    
          ISNULL(ORDERS.b_Company, ''),    
          ISNULL(ORDERS.b_Address1, ''),       
          ISNULL(ORDERS.b_Address2, ''),     
          ISNULL(ORDERS.b_Address3, ''),       
          ISNULL(ORDERS.b_Address4, ''),       
          ISNULL(ORDERS.b_Zip, ''),       
          ISNULL(ORDERS.b_City, ''),       
          ISNULL(ORDERS.b_State, ''),       
          ISNULL(ORDERS.b_Country, '')    
          --ML02 END    
    
   FROM WAVEDETAIL      WD  WITH (NOLOCK)     
   JOIN pickdetail WITH (NOLOCK)  ON pickdetail.OrderKey = WD.OrderKey --AND  pickdetail.WaveKey=wd.WaveKey    
   LEFT JOIN Pickheader WITH (NOLOCK) ON PickHeader.ExternOrderkey = pickdetail.PickSlipNo    
   JOIN orders WITH (NOLOCK) ON  pickdetail.orderkey = orders.orderkey      
   JOIN lotattribute WITH (NOLOCK) ON  pickdetail.lot = lotattribute.lot      
   JOIN loadplandetail WITH (NOLOCK) ON  pickdetail.orderkey = loadplandetail.orderkey      
   JOIN orderdetail WITH (NOLOCK)  ON  pickdetail.orderkey = orderdetail.orderkey      
                                   AND pickdetail.orderlinenumber = orderdetail.orderlinenumber      
   JOIN storer WITH (NOLOCK) ON  pickdetail.storerkey = storer.storerkey      
   JOIN sku(NOLOCK) ON  pickdetail.sku = sku.sku      
                       AND pickdetail.storerkey = sku.storerkey      
   JOIN pack WITH (NOLOCK) ON  pickdetail.packkey = pack.packkey      
   JOIN loc WITH (NOLOCK) ON  pickdetail.loc = loc.loc      
   left outer join RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)     
    WHERE  PickDetail.Status <= '5' AND orders.status >= '2'      
   AND WD.WaveKey = @c_waveKey      
   GROUP BY RefKeyLookup.PickSlipNo,    
           ORDERS.LoadKey,ORDERS.OrderKey,    
          ISNULL(ORDERS.ConsigneeKey, ''),      
          ISNULL(ORDERS.c_Company, ''),     
          PickDetail.loc,       
          PickDetail.sku,      
          ISNULL(Sku.Descr, ''),      
          loc.pickzone,     
          PACK.CaseCnt,        
          SKU.SKUGROUP,      
          ORDERS.Storerkey,      
          wd.WaveKey,pickdetail.PickDetailKey,orders.externorderkey,    
          ISNULL(ORDERS.DeliveryDate, ''),    
          --ML01 START    
          orders.Route,    
          ISNULL(ORDERS.c_Address1, ''),       
          ISNULL(ORDERS.c_Address2, ''),     
          ISNULL(ORDERS.c_Address3, ''),       
          ISNULL(ORDERS.c_Address4, ''),       
          ISNULL(ORDERS.c_Zip, ''),       
          ISNULL(ORDERS.c_City, ''),       
          ISNULL(ORDERS.c_State, ''),       
          ISNULL(ORDERS.c_Country, ''),    
          --ML01 END    
          --ML02 START    
          ISNULL(ORDERS.BillToKey,''),    
          ISNULL(ORDERS.b_Company, ''),    
          ISNULL(ORDERS.b_Address1, ''),       
          ISNULL(ORDERS.b_Address2, ''),     
          ISNULL(ORDERS.b_Address3, ''),       
          ISNULL(ORDERS.b_Address4, ''),       
          ISNULL(ORDERS.b_Zip, ''),       
          ISNULL(ORDERS.b_City, ''),       
          ISNULL(ORDERS.b_State, ''),       
          ISNULL(ORDERS.b_Country, '')     
          --ML02 END    
                   
   WHILE @@TRANCOUNT > 0      
   BEGIN      
      COMMIT TRAN      
   END    
         
   SET @c_OrderKey = ''      
   SET @c_Pickzone = ''    
   SET @c_PrevPAzone = ''    
   SET @c_preorderkey = ''    
   SET @c_PickDetailKey = ''      
   SET @n_continue = 1    
        
   DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT DISTINCT loadkey,Orderkey,LOCZone     
        ,PickDetailKey    
   FROM #TMP_PICK      
   WHERE  ISNULL(PickSlipNo,'') = ''    
   ORDER BY Orderkey,LOCZone,PickDetailKey            
      
   OPEN CUR_LOAD      
         
   FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_orderkey       
                              ,  @c_PZone    
                              ,  @c_GetPickDetailKey    
      
   WHILE (@@FETCH_STATUS <> -1)      
   BEGIN                 
     IF ISNULL(@c_OrderKey, '0') = '0'      
        BREAK      
                      
     IF @c_preorderkey <> @c_orderkey             
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
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave29)'       
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '       
                  GOTO QUIT         
                 END                    
         END    
         ELSE       
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @n_err = 63502    
             SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PSNO Failed. (isp_GetPickSlipWave29)'      
            BREAK       
         END                
     END                
           
     IF @n_Continue = 1      
     BEGIN            
        SET @c_ExecStatement = N'DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' +    
                                'SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber ' +       
                                'FROM   PickDetail WITH (NOLOCK) ' +    
                                'JOIN   OrderDetail WITH (NOLOCK) ' +                                           
                                'ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND ' +     
                                'PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) ' +    
                                'JOIN   LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) ' +    
                                ' WHERE  PickDetail.pickdetailkey = @c_GetPickDetailKey ' +    
                                ' AND    OrderDetail.orderkey  =  @c_orderkey  ' +    
                                ' AND LOC.PickZone =  RTRIM(@c_Pzone)  ' +      
                                ' ORDER BY PickDetail.PickDetailKey '      
       
        --EXEC(@c_ExecStatement)    
       SET @c_ExecArguments =  N' @c_GetPickDetailKey     NVARCHAR(20)'          
                             + ', @c_orderkey             NVARCHAR(20)'          
                             + ', @c_Pzone                NVARCHAR(20)'     
    
    
         EXEC sp_ExecuteSql  @c_ExecStatement           
                           , @c_ExecArguments          
                           , @c_GetPickDetailKey          
                           , @c_orderkey       
                           , @c_Pzone       
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
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookup Failed. (isp_GetPickSlipWave29)'        
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
     AND   LOCzone = @c_Pzone    
     AND   ISNULL(PickSlipNo,'') = ''     
     AND Pickdetailkey = @c_GetPickDetailKey    
    
     SELECT @n_err = @@ERROR      
     IF @n_err <> 0       
     BEGIN      
        SELECT @n_continue = 3      
        SELECT @n_err = 63504    
        SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TMP_PICK Failed. (isp_GetPickSlipWave29)'        
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
    -- AND L.PickZone = @c_PZone    
     AND   ISNULL(PickSlipNo,'') = ''      
     AND Pickdetailkey = @c_GetPickDetailKey    
         
       SET @n_err = @@ERROR          
           
       IF @n_err <> 0          
       BEGIN          
           SET @n_continue = 3          
           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
           SET @n_err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (isp_GetPickSlipWave29)'       
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
    -- SET @c_PrevPAzone = @c_Pzone       
     SET @c_preorderkey = @c_orderkey                  
                 
     FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_Orderkey      
                                ,  @c_PZone    
                              --  ,  @n_MaxRow    
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
       --IF RTRIM(@c_GetPHOrdKey) = '' OR @c_GetPHOrdKey IS NULL  --NJOW02 Removed    
       -- BEGIN      
           
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
                    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave29)'       
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
      
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN       
      IF @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         ROLLBACK TRAN        
      END       
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave29'        
   END      
          
   -- --NJOW01 Start       
   --SELECT tp.Orderkey,       
   --       SUM(tp.QtyOverAllocate) AS TotalQtyOverAllocate       
   --    ,  ISNULL(RTRIM(CL.Description),'') AS PriceTag      
   --INTO #tmp_ordsum      
   --FROM #TMP_PICK tp        
   --LEFT JOIN STORER   CS WITH (NOLOCK) ON (tp.consigneekey = CS.Storerkey)      
   --LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.Listname = 'TitleRem' AND CS.Fax2 = CL.Code AND CL.Storerkey = @c_GetStorerkey)      
   --GROUP BY tp.Orderkey      
   --      ,  ISNULL(RTRIM(CL.Description),'')       
         
   --SELECT DISTINCT #tmp_pick.Loc      
   --INTO #tmp_highbayloc      
   --FROM #TMP_PICK      
   --JOIN LOC (NOLOCK) ON #tmp_pick.Loc = LOC.Loc      
   --LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'HighLight' AND LOC.PickZone = CL.Code AND CL.Storerkey = @c_GetStorerkey)      
   --WHERE CL.Short = 'Y'      
      
   SELECT                 
         #TMP_PICK.PickSlipNo         
      ,  #TMP_PICK.LoadKey                
      ,  #TMP_PICK.OrderKey               
      ,  #TMP_PICK.ConsigneeKey           
      ,  #TMP_PICK.c_Company                           
      ,  UPPER(#TMP_PICK.LOC) AS LOC                     
      ,  #TMP_PICK.SKU                    
      ,  #TMP_PICK.SkuDesc                
      ,  SUM(#TMP_PICK.Qty) AS Qty                   --CS01                           
      ,  CASE WHEN @n_hidepickzone = 0 THEN #TMP_PICK.LOCZone ELSE '' END AS LOCZone    --CS02    
      ,  #TMP_PICK.packcasecnt                         
      ,  SUM(#TMP_PICK.Cartons_cal) AS  Cartons_cal    --CS01                     
      ,  SUM(#TMP_PICK.Each_cal) AS Each_cal           --CS01            
      ,  #TMP_PICK.SKUGROUP               
      ,  #TMP_PICK.Storerkey              
      ,  #TMP_PICK.Wavekey,#TMP_Pick.ExtOrderkey     
      ,  #TMP_PICK.DeliveryDate    
      --ML01 START    
      ,  #TMP_PICK.Route         
      ,  #TMP_PICK.c_Address1    
      ,  #TMP_PICK.c_Address2     
      ,  #TMP_PICK.c_Address3    
      ,  #TMP_PICK.c_Address4    
      ,  #TMP_PICK.c_Zip    
      ,  #TMP_PICK.c_City    
      ,  #TMP_PICK.c_State    
      ,  #TMP_PICK.c_Country    
      --ML01 END    
      --ML02 START    
      ,  #TMP_PICK.BillToKey        
      ,  #TMP_PICK.b_Company    
      ,  #TMP_PICK.b_Address1    
      ,  #TMP_PICK.b_Address2     
      ,  #TMP_PICK.b_Address3    
      ,  #TMP_PICK.b_Address4    
      ,  #TMP_PICK.b_Zip    
      ,  #TMP_PICK.b_City    
      ,  #TMP_PICK.b_State    
      ,  #TMP_PICK.b_Country 
      ,  @n_hidepickzone   AS hidepickzone     --CS02
      --ML02 END    
   FROM   #TMP_PICK      
   --CS01 START    
   GROUP BY  #TMP_PICK.PickSlipNo         
      ,  #TMP_PICK.LoadKey                
      ,  #TMP_PICK.OrderKey               
      ,  #TMP_PICK.ConsigneeKey           
      ,  #TMP_PICK.c_Company                           
      ,  UPPER(#TMP_PICK.LOC)                
      ,  #TMP_PICK.SKU                    
      ,  #TMP_PICK.SkuDesc                               
      ,  CASE WHEN @n_hidepickzone = 0 THEN #TMP_PICK.LOCZone ELSE '' END     --CS02      
      ,  #TMP_PICK.packcasecnt                                
      ,  #TMP_PICK.SKUGROUP               
      ,  #TMP_PICK.Storerkey              
      ,  #TMP_PICK.Wavekey,#TMP_Pick.ExtOrderkey     
      ,  #TMP_PICK.DeliveryDate     
      --ML01 START      
      ,  #TMP_PICK.Route    
      ,  #TMP_PICK.c_Address1    
      ,  #TMP_PICK.c_Address2     
      ,  #TMP_PICK.c_Address3    
      ,  #TMP_PICK.c_Address4    
      ,  #TMP_PICK.c_Zip    
      ,  #TMP_PICK.c_City    
      ,  #TMP_PICK.c_State    
      ,  #TMP_PICK.c_Country    
      --ML01 END    
      --ML02 START    
      ,  #TMP_PICK.BillToKey    
      ,  #TMP_PICK.b_Company    
      ,  #TMP_PICK.b_Address1    
      ,  #TMP_PICK.b_Address2     
      ,  #TMP_PICK.b_Address3    
      ,  #TMP_PICK.b_Address4    
      ,  #TMP_PICK.b_Zip    
      ,  #TMP_PICK.b_City    
      ,  #TMP_PICK.b_State    
      ,  #TMP_PICK.b_Country      
      ,  SUBSTRING(#TMP_PICK.LOC, 3, 3), SUBSTRING(#TMP_PICK.LOC, 6, 2), SUBSTRING(#TMP_PICK.LOC, 8, 3) --(CLVN01)    
      --ML02 END    
   --CS01 END    
   --ORDER BY #TMP_PICK.PickSlipNo,#TMP_PICK.LOCZone,UPPER(#TMP_PICK.LOC),  #TMP_PICK.SKU --(CLVN01)    
   --ORDER BY #TMP_PICK.PickSlipNo, UPPER(#TMP_PICK.LOC), #TMP_PICK.LOCZone, #TMP_PICK.SKU --(CLVN01)    
   --ORDER BY #TMP_PICK.PickSlipNo, SUBSTRING(#TMP_PICK.LOC, 3, 3), SUBSTRING(#TMP_PICK.LOC, 6, 2), SUBSTRING(#TMP_PICK.LOC, 8, 3), #TMP_PICK.LOCZone, #TMP_PICK.SKU --(CLVN01)    
   ORDER BY #TMP_PICK.PickSlipNo, SUBSTRING(#TMP_PICK.LOC, 3, 3), SUBSTRING(#TMP_PICK.LOC, 6, 2), SUBSTRING(#TMP_PICK.LOC, 8, 3), #TMP_PICK.SKU --(IAN01)    
             
  --SELECT '1' AS PickSlipNo    
      
  DROP TABLE #TMP_PICK      
      
      
      
   WHILE @@TRANCOUNT < @n_StartTCnt      
   BEGIN      
      BEGIN TRAN       
   END      
         
RETURN      
END 


GO
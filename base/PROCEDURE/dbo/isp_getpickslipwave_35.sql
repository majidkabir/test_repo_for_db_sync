SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/
/* Stored Procedure: isp_GetPickSlipWave_35                             */
/* Creation Date: 28-Oct-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18172 - SG - Adidas SEA - PLIST_WAVE Picking Slip       */
/*                                                                      */
/* Called By: RCM - Generate Pickslip                                   */
/*          : Datawindow - r_dw_print_wave_pickslip_35                  */
/*                                                                      */
/* GitLab Version: 1.4                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 28-Oct-2021  WLChooi  1.0  DevOps Combine Script                     */
/* 03-Mar-2022  WLChooi  1.1  WMS-18172 Change DeliveryDate column(WL01)*/
/* 14-Mar-2022  WLChooi  1.2  WMS-19171 Add logic for Case Pick (WL02)  */
/* 27-Apr-2022  WLChooi  1.3  WMS-19171 Add condition (WL03)            */
/* 09-May-2022  WLChooi  1.4  WMS-19171 Add filter by UOM6 (WL04)       */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPickSlipWave_35] (  
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
         , @c_SkuDescr           NVARCHAR(60)  
         , @c_HazardousFlag      NVARCHAR(30)  
         , @c_Loc                NVARCHAR(10)  
         , @c_ID                 NVARCHAR(18)      
         , @c_DropID             NVARCHAR(20)   
         , @n_Qty                INT  
         , @c_UserDefine02       NVARCHAR(18) 
         , @n_NoOfLine           INT
         , @c_GetStorerkey       NVARCHAR(15)  
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
         , @c_ExecStatement      NVARCHAR(4000)
         , @c_GetPHOrdKey        NVARCHAR(20)
         , @c_GetWDOrdKey        NVARCHAR(20)
         , @c_ExecArguments      NVARCHAR(4000)
         , @n_SortSeq            INT = 1
         , @c_Sku_Min_LogLoc     NVARCHAR(20)
         , @c_MaxPickslip        NVARCHAR(10)
          
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
           
   CREATE TABLE #TMP_PICK  
   (  PickSlipNo         NVARCHAR(10) NULL,  
      LoadKey            NVARCHAR(10),  
      OrderKey           NVARCHAR(10),  
      ConsigneeKey       NVARCHAR(15),  
      c_Company          NVARCHAR(45),  
      LOC                NVARCHAR(10) NULL,  
      SKU                NVARCHAR(20),  
      SkuDesc            NVARCHAR(60),  
      Qty                INT,  
      LOCZone            NVARCHAR(10) NULL,  
      Cartons_cal        INT DEFAULT(0),  
      Each_cal           INT  DEFAULT(0),  
      SKUGROUP           NVARCHAR(10) NULL,  
      Storerkey          NVARCHAR(15) NULL, 
      Wavekey            NVARCHAR(10) NULL,
      Pickdetailkey      NVARCHAR(20) NULL,
      packcasecnt        FLOAT,
      ExtOrderkey        NVARCHAR(50) NULL,
      DeliveryDate       DATE NULL,   --WL02
      [Route]            NVARCHAR(20),
      c_Address1         NVARCHAR(45),
      c_Address2         NVARCHAR(45),
      c_Address3         NVARCHAR(45),
      c_Address4         NVARCHAR(45),
      c_Zip              NVARCHAR(45),   --WL02
      c_City             NVARCHAR(45),
      c_State            NVARCHAR(45),   --WL02
      c_Country          NVARCHAR(45),   --WL02
      BillToKey          NVARCHAR(20),
      b_Company          NVARCHAR(45),    
      b_Address1         NVARCHAR(45),
      b_Address2         NVARCHAR(45),
      b_Address3         NVARCHAR(45),
      b_Address4         NVARCHAR(45),
      b_Zip              NVARCHAR(10),
      b_City             NVARCHAR(45),
      b_State            NVARCHAR(45),   --WL02
      b_Country          NVARCHAR(45),   --WL02
      M_VAT              NVARCHAR(50),
      Export             NVARCHAR(50),
      ManufacturerSKU    NVARCHAR(50),
      LogicalLoc         NVARCHAR(20),
      SKUStyle           NVARCHAR(20),
      SortSeq            INT NULL,
      MaxPickslip        NVARCHAR(10) NULL,   --WL02
      UserDefine04       NVARCHAR(50),   --WL02
      UOM                NVARCHAR(10),   --WL02
      DropID             NVARCHAR(30)    --WL02
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
   
   IF NOT EXISTS (SELECT 1
                  FROM WAVEDETAIL WD (NOLOCK)
                  WHERE WD.WaveKey = @c_Wavekey)
   BEGIN
      GOTO QUIT
   END 

   IF EXISTS (SELECT 1
              FROM WAVEDETAIL WD (NOLOCK)
              JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
              WHERE WD.WaveKey = @c_Wavekey
              AND OH.DocType = 'E')
   BEGIN
      GOTO QUIT
   END 

   IF EXISTS (SELECT 1
              FROM WAVE W (NOLOCK)
              WHERE W.WaveKey = @c_Wavekey
              AND W.UserDefine01 <> 'PPA')
   BEGIN
      GOTO QUIT
   END 

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
      DeliveryDate,
      [Route],
      c_Address1,
      c_Address2,
      c_Address3,
      c_Address4,
      c_Zip,
      c_City,
      c_State,
      c_Country,
      BillToKey,
      b_Company,
      b_Address1,
      b_Address2,
      b_Address3,
      b_Address4,
      b_Zip,
      b_City,
      b_State,
      b_Country,
      M_VAT,
      Export,
      ManufacturerSKU,
      LogicalLoc,
      SKUStyle,
      MaxPickslip,
      UserDefine04,   --WL02
      UOM,            --WL02
      Dropid          --WL02
   )                
   SELECT DISTINCT 
      RefKeyLookup.PickSlipNo,  
      ORDERS.LoadKey,ORDERS.OrderKey,
      ISNULL(ORDERS.ConsigneeKey, '') AS ConsigneeKey,  
      ISNULL(ORDERS.C_Company, ''),     
      PICKDETAIL.LOC,   
      PICKDETAIL.SKU,  
      ISNULL(SKU.Descr, '')  AS  SKUDescr,  
      SUM(PICKDETAIL.qty)            AS Qty,  
      CASE WHEN W.UserDefine02 <> 'Y' THEN '' ELSE LOC.PickZone END AS LOCZone,  
      --WL02 S
      --Cartons_cal = CASE PACK.Casecnt  
      --                  WHEN 0 THEN 0  
      --                  ELSE FLOOR(SUM(PICKDETAIL.qty) / (PACK.Casecnt))  
      --             END,   
      --Each_cal    = CASE PACK.Casecnt  
      --                  --WHEN 0 THEN 0 
      --                  WHEN 0 THEN SUM(PICKDETAIL.qty) 
      --                  ELSE FLOOR(SUM(PICKDETAIL.qty) % CAST(PACK.Casecnt AS INT))  
      --             END,
      Cartons_cal = CASE PICKDETAIL.UOM
                        WHEN 2 THEN 1  
                        ELSE 0
                   END,   
      Each_cal    = CASE PICKDETAIL.UOM 
                        WHEN 6 THEN SUM(PICKDETAIL.qty) 
                        ELSE 0 
                   END,
      --WL02 E
      SKU.SKUGROUP,  
      ORDERS.Storerkey,  
      WD.WaveKey,
      PICKDETAIL.PICKDETAILKey,
      PACK.Casecnt,
      ORDERS.ExternOrderKey,
      --ISNULL(ORDERS.DeliveryDate, ''),   --WL01
      CASE WHEN ISDATE(ORDERS.UserDefine10) = 1 THEN CONVERT(DATE, ORDERS.UserDefine10) ELSE NULL END,   --WL01
      ORDERS.[Route],
      ISNULL(ORDERS.C_Address1, ''),   
      ISNULL(ORDERS.C_Address2, ''),   
      ISNULL(ORDERS.C_Address3, ''),  
      ISNULL(ORDERS.C_Address4, ''),   
      ISNULL(ORDERS.C_Zip, ''),   
      ISNULL(ORDERS.C_City, ''),   
      ISNULL(ORDERS.C_State, ''),   
      ISNULL(ORDERS.C_Country, ''),
      ISNULL(ORDERS.BillToKey,''),
      ISNULL(ORDERS.B_Company, ''),
      ISNULL(ORDERS.B_Address1, ''),   
      ISNULL(ORDERS.B_Address2, ''), 
      ISNULL(ORDERS.B_Address3, ''),   
      ISNULL(ORDERS.B_Address4, ''),   
      ISNULL(ORDERS.B_Zip, ''),   
      ISNULL(ORDERS.B_City, ''),   
      ISNULL(ORDERS.B_State, ''),   
      ISNULL(ORDERS.B_Country, ''),
      ISNULL(ORDERS.M_vat, ''),
      CASE WHEN ORDERS.C_Country <> STORER.Country THEN 'EXPORT' ELSE '' END,
      ISNULL(SKU.MANUFACTURERSKU,''),
      LOC.LogicalLocation,
      ISNULL(SKU.Style,''),
      (SELECT MAX(PD.Pickslipno) FROM PICKDETAIL PD (NOLOCK) WHERE PD.OrderKey = ORDERS.OrderKey) AS MaxPickslip,
      ORDERS.UserDefine04,   --WL02
      PICKDETAIL.UOM,        --WL02
      CASE WHEN PICKDETAIL.UOM = '2' THEN PICKDETAIL.DropID ELSE '' END   --WL02
   FROM WAVEDETAIL      WD  WITH (NOLOCK) 
   JOIN PICKDETAIL WITH (NOLOCK)  ON PICKDETAIL.OrderKey = WD.OrderKey --AND  PICKDETAIL.WaveKey=wd.WaveKey
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON PICKHEADER.ExternOrderKey = PICKDETAIL.PickSlipNo
   JOIN ORDERS WITH (NOLOCK) ON  PICKDETAIL.OrderKey = ORDERS.OrderKey  
   JOIN LOTATTRIBUTE WITH (NOLOCK) ON  PICKDETAIL.lot = LOTATTRIBUTE.lot  
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON  PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey  
   JOIN ORDERDETAIL WITH (NOLOCK)  ON  PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey  
                                   AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber  
   JOIN STORER WITH (NOLOCK) ON  PICKDETAIL.Storerkey = STORER.Storerkey  
   JOIN SKU(NOLOCK) ON  PICKDETAIL.SKU = SKU.SKU  
                       AND PICKDETAIL.Storerkey = SKU.Storerkey  
   JOIN PACK WITH (NOLOCK) ON  PICKDETAIL.PACKkey = PACK.PACKkey  
   JOIN LOC WITH (NOLOCK) ON  PICKDETAIL.LOC = LOC.LOC  
   LEFT JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PICKDETAILKey = PICKDETAIL.PICKDETAILKey) 
   JOIN WAVE W WITH (NOLOCK) ON (W.WaveKey = WD.WaveKey)
   WHERE PICKDETAIL.Status <= '5' --AND ORDERS.status >= '2'  
   AND WD.WaveKey = @c_waveKey  
   GROUP BY RefKeyLookup.PickSlipNo,
            ORDERS.LoadKey,ORDERS.OrderKey,
            ISNULL(ORDERS.ConsigneeKey, ''),  
            ISNULL(ORDERS.C_Company, ''), 
            PICKDETAIL.LOC,   
            PICKDETAIL.SKU,  
            ISNULL(SKU.Descr, ''),  
            CASE WHEN W.UserDefine02 <> 'Y' THEN '' ELSE LOC.PickZone END, 
            PACK.CaseCnt,    
            SKU.SKUGROUP,  
            ORDERS.Storerkey,  
            WD.WaveKey,PICKDETAIL.PICKDETAILKey,
            ORDERS.ExternOrderKey,
            --ISNULL(ORDERS.DeliveryDate, ''),   --WL01
            CASE WHEN ISDATE(ORDERS.UserDefine10) = 1 THEN CONVERT(DATE, ORDERS.UserDefine10) ELSE NULL END,   --WL01
            ORDERS.[Route],
            ISNULL(ORDERS.C_Address1, ''),   
            ISNULL(ORDERS.C_Address2, ''), 
            ISNULL(ORDERS.C_Address3, ''),   
            ISNULL(ORDERS.C_Address4, ''),   
            ISNULL(ORDERS.C_Zip, ''),   
            ISNULL(ORDERS.C_City, ''),   
            ISNULL(ORDERS.C_State, ''),   
            ISNULL(ORDERS.C_Country, ''),
            ISNULL(ORDERS.BillToKey,''),
            ISNULL(ORDERS.B_Company, ''),
            ISNULL(ORDERS.B_Address1, ''),   
            ISNULL(ORDERS.B_Address2, ''), 
            ISNULL(ORDERS.B_Address3, ''),   
            ISNULL(ORDERS.B_Address4, ''),   
            ISNULL(ORDERS.B_Zip, ''),   
            ISNULL(ORDERS.B_City, ''),   
            ISNULL(ORDERS.B_State, ''),   
            ISNULL(ORDERS.B_Country, ''),
            ISNULL(ORDERS.M_vat, ''),
            CASE WHEN ORDERS.C_Country <> STORER.Country THEN 'EXPORT' ELSE '' END,
            ISNULL(SKU.MANUFACTURERSKU,''),
            LOC.LogicalLocation,
            ISNULL(SKU.Style,''),
            ORDERS.UserDefine04,   --WL02
            PICKDETAIL.UOM,        --WL02
            PICKDETAIL.DropID      --WL02
               
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END
     
   SET @c_OrderKey = ''  
   SET @c_PickZone = ''
   SET @c_PrevPAzone = ''
   SET @c_preorderkey = ''
   SET @c_PickDetailKey = ''  
   SET @n_continue = 1

   DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT loadkey,Orderkey,LOCZone 
                 , PickDetailKey, MaxPickslip
   FROM #TMP_PICK  
   WHERE ISNULL(PickSlipNo,'') = ''
   ORDER BY Orderkey,LOCZone,PickDetailKey

   OPEN CUR_LOAD  
     
   FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_orderkey   
                              ,  @c_PZone
                              ,  @c_GetPickDetailKey
                              ,  @c_MaxPickslip
  
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN             
      IF ISNULL(@c_OrderKey, '0') = '0'  
         BREAK  
                  
      IF @c_preorderkey <> @c_orderkey AND ISNULL(@c_MaxPickslip,'') = ''   
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
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave_35)'   
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
               GOTO QUIT     
            END                
         END
         ELSE   
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @n_err = 63502
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PSNO Failed. (isp_GetPickSlipWave_35)'  
            BREAK   
         END            
      END  
      ELSE
      BEGIN
         --Added condition only when preorderkey <> orderkey. 
         --If not for 1st time gen pickslip, the next pickdetail Pickslipno line will be set to null
         IF @c_preorderkey <> @c_orderkey  
         BEGIN 
            SET @c_RPickSlipNo = @c_MaxPickslip
         END
      END          
       
      IF @n_Continue = 1  
      BEGIN        
         SET @c_ExecStatement = N' DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                 ' SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber ' +   
                                 ' FROM   PickDetail WITH (NOLOCK) ' +
                                 ' JOIN   OrderDetail WITH (NOLOCK) ' +                                       
                                 ' ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND ' + 
                                 ' PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) ' +
                                 ' JOIN   LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) ' +
                                 ' WHERE  PickDetail.pickdetailkey = @c_GetPickDetailKey ' +
                                 ' AND    OrderDetail.orderkey  =  @c_orderkey  ' +
                                 ' AND LOC.PickZone =  CASE WHEN ISNULL(TRIM(@c_Pzone),'''') = '''' THEN LOC.Pickzone ELSE TRIM(@c_Pzone) END ' +  
                                 ' ORDER BY PickDetail.PickDetailKey '  
   
         --EXEC(@c_ExecStatement)
         SET @c_ExecArguments =  N'@c_GetPickDetailKey     NVARCHAR(20)'      
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
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookup Failed. (isp_GetPickSlipWave_35)'    
                  GOTO QUIT
               END                          
            END   
            NEXT_LOOP:
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
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TMP_PICK Failed. (isp_GetPickSlipWave_35)'    
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
      AND   ISNULL(PickSlipNo,'') = ''  
      AND Pickdetailkey = @c_GetPickDetailKey
     
      SET @n_err = @@ERROR      
       
      IF @n_err <> 0      
      BEGIN      
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (isp_GetPickSlipWave_35)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
         GOTO QUIT     
      END  
     
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END             

      SET @c_preorderkey = @c_orderkey              
             
      FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_Orderkey  
                                  , @c_PZone
                                  , @c_GetPickDetailKey
                                  , @c_MaxPickslip
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
                     WHERE Wavekey  = @c_Wavekey 
                     AND Orderkey   = @c_GetWDOrdKey)         
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
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave_35)'   
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
            GOTO QUIT     
         END      
      END   
              
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END   
      NEXT_REC:
      FETCH NEXT FROM  CUR_WaveOrder INTO @c_GetWavekey,@c_GetLoadkey,@c_GetPHOrdKey,@c_GetWDOrdKey
   END     
   CLOSE CUR_WaveOrder  
   DEALLOCATE CUR_WaveOrder 
   
   --Sort SKU based on LogicalLocation OR Style then SKU (with Min Logical Location of Style)
   IF @n_Continue IN (1,2)
   BEGIN
      --Sort SKU based on LogicalLocation
      IF EXISTS (SELECT 1
                 FROM CODELKUP CL (NOLOCK)
                 WHERE CL.LISTNAME = 'ADIPSSORT'
                 AND CL.Storerkey = @c_GetStorerkey
                 AND CL.Short = '1')
      BEGIN
         DECLARE CUR_LOGICALLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TP.Orderkey, TP.LOCZone, X.Sku_Min_LogLoc, TP.LogicalLoc, TP.Sku, TP.Loc, SUM(TP.Qty)
            FROM #TMP_PICK TP
            JOIN (SELECT #TMP_PICK.OrderKey, #TMP_PICK.LOCZone, Sku_Min_LogLoc = MIN(#TMP_PICK.LogicalLoc), #TMP_PICK.Sku
                  FROM #TMP_PICK
                  WHERE #TMP_PICK.UOM = '6'   --WL04
                  GROUP BY #TMP_PICK.OrderKey, #TMP_PICK.LOCZone, #TMP_PICK.Sku
                 ) X ON TP.Orderkey = X.Orderkey
                    AND TP.LOCZone = X.LOCZone
                    AND TP.Sku = X.Sku
            WHERE TP.UOM = '6'   --WL02
            GROUP BY TP.Orderkey, TP.LOCZone, X.Sku_Min_LogLoc, TP.LogicalLoc, TP.Sku, TP.Loc
            ORDER BY TP.Orderkey, TP.LOCZone, X.Sku_Min_LogLoc, TP.Sku, TP.LogicalLoc
         
         OPEN CUR_LOGICALLOC

         FETCH NEXT FROM CUR_LOGICALLOC INTO @c_Orderkey, @c_PickZone, @c_Sku_Min_LogLoc, @c_LogicalLoc, @c_SKU, @c_Loc, @n_Qty

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE #TMP_PICK
            SET SortSeq = @n_SortSeq
            WHERE OrderKey = @c_Orderkey
            AND LOCZone = @c_PickZone
            AND LogicalLoc = @c_LogicalLoc
            AND SKU = @c_Sku
            AND LOC = @c_Loc
            AND UOM = '6'   --WL02

            --WL02 S
            DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT PD.PickDetailKey
            FROM PICKDETAIL PD (NOLOCK)
            WHERE PD.OrderKey = @c_Orderkey
            AND PD.SKU = @c_Sku
            AND PD.Loc = @c_Loc
            AND PD.UOM = '6'
            AND PD.[Status] <> '9'   --WL03

            OPEN CUR_UPD

            FETCH NEXT FROM CUR_UPD INTO @c_PickDetailKey

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE PICKDETAIL
               SET TaskManagerReasonKey = @n_SortSeq
                 , TrafficCop = NULL
                 , EditDate   = GETDATE()
                 , EditWho    = SUSER_SNAME()
               WHERE PickDetailKey = @c_PickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 63005
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': UPDATE PICKDETAIL Failed. (isp_GetPickSlipWave_35)'
                  GOTO QUIT
               END

               FETCH NEXT FROM CUR_UPD INTO @c_PickDetailKey
            END 
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            --WL02 E

            SET @n_SortSeq = @n_SortSeq + 1

            FETCH NEXT FROM CUR_LOGICALLOC INTO @c_Orderkey, @c_PickZone, @c_Sku_Min_LogLoc, @c_LogicalLoc, @c_SKU, @c_Loc, @n_Qty
         END
         CLOSE CUR_LOGICALLOC
         DEALLOCATE CUR_LOGICALLOC
      END
      ELSE   --Sort by Style then SKU (with Min Logical Location of Style)
      BEGIN
         DECLARE CUR_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TP.Orderkey, TP.LOCZone, Y.Style_Min_LogLoc, TP.LogicalLoc, TP.Sku, TP.Loc, SUM(TP.Qty)
            FROM #TMP_PICK TP
            JOIN ( SELECT TP1.Orderkey, TP1.LOCZone, X.Style_Min_LogLoc, Sku_Min_LogLoc = MIN(TP1.LogicalLoc), TP1.SKUStyle
                   FROM #TMP_PICK TP1
                   JOIN ( SELECT #TMP_PICK.OrderKey, #TMP_PICK.LOCZone, Style_Min_LogLoc = MIN(#TMP_PICK.LogicalLoc), #TMP_PICK.SKUStyle
                          FROM #TMP_PICK
                          WHERE #TMP_PICK.UOM = '6'   --WL04
                          GROUP BY #TMP_PICK.OrderKey, #TMP_PICK.LOCZone, #TMP_PICK.SKUStyle
                        ) X ON TP1.LOCZone = X.LOCZone
                           AND TP1.SKUStyle = X.SKUStyle
                           AND TP1.OrderKey = X.OrderKey
                   WHERE TP1.UOM = '6'   --WL04
                   GROUP BY TP1.Orderkey, TP1.LOCZone, X.Style_Min_LogLoc, TP1.SKUStyle
                 ) Y ON TP.OrderKey = Y.OrderKey
                    AND TP.LOCZone  = Y.LOCZone
                    AND TP.SKUStyle = Y.SKUStyle
            WHERE TP.UOM = '6'   --WL02
            GROUP BY TP.Orderkey, TP.LOCZone, Y.Style_Min_LogLoc, Y.Sku_Min_LogLoc, TP.LogicalLoc, TP.Sku, TP.Loc
            ORDER BY TP.Orderkey, TP.LOCZone, Y.Style_Min_LogLoc, Y.Sku_Min_LogLoc, TP.Sku, TP.LogicalLoc
         
         OPEN CUR_SKU

         FETCH NEXT FROM CUR_SKU INTO @c_Orderkey, @c_PickZone, @c_Sku_Min_LogLoc, @c_LogicalLoc, @c_SKU, @c_Loc, @n_Qty

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE #TMP_PICK
            SET SortSeq = @n_SortSeq
            WHERE OrderKey = @c_Orderkey
            AND LOCZone = @c_PickZone
            AND LogicalLoc = @c_LogicalLoc
            AND SKU = @c_Sku
            AND LOC = @c_Loc
            AND UOM = '6'   --WL02

            --WL02 S
            DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT PD.PickDetailKey
            FROM PICKDETAIL PD (NOLOCK)
            WHERE PD.OrderKey = @c_Orderkey
            AND PD.SKU = @c_Sku
            AND PD.Loc = @c_Loc
            AND PD.UOM = '6'
            AND PD.[Status] <> '9'   --WL03

            OPEN CUR_UPD

            FETCH NEXT FROM CUR_UPD INTO @c_PickDetailKey

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE PICKDETAIL
               SET TaskManagerReasonKey = @n_SortSeq
                 , TrafficCop = NULL
                 , EditDate   = GETDATE()
                 , EditWho    = SUSER_SNAME()
               WHERE PickDetailKey = @c_PickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 63010
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': UPDATE PICKDETAIL Failed. (isp_GetPickSlipWave_35)'
                  GOTO QUIT
               END

               FETCH NEXT FROM CUR_UPD INTO @c_PickDetailKey
            END 
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            --WL02 E

            SET @n_SortSeq = @n_SortSeq + 1

            FETCH NEXT FROM CUR_SKU INTO @c_Orderkey, @c_PickZone, @c_Sku_Min_LogLoc, @c_LogicalLoc, @c_SKU, @c_Loc, @n_Qty
         END
         CLOSE CUR_SKU
         DEALLOCATE CUR_SKU
      END
   END       

QUIT:  
   IF CURSOR_STATUS('LOCAL' , 'CUR_LOAD') in (0 , 1)  
   BEGIN  
      CLOSE CUR_LOAD  
      DEALLOCATE CUR_LOAD  
   END  
  
   IF CURSOR_STATUS('LOCAL' , 'CUR_WaveOrder') in (0 , 1)  
   BEGIN  
      CLOSE CUR_WaveOrder  
      DEALLOCATE CUR_WaveOrder  
   END  

   IF CURSOR_STATUS('GLOBAL' , 'C_PickDetailKey') in (0 , 1)  
   BEGIN  
      CLOSE C_PickDetailKey  
      DEALLOCATE C_PickDetailKey  
   END  

   IF CURSOR_STATUS('LOCAL' , 'CUR_LOGICALLOC') in (0 , 1)  
   BEGIN  
      CLOSE CUR_LOGICALLOC  
      DEALLOCATE CUR_LOGICALLOC  
   END 

   IF CURSOR_STATUS('LOCAL' , 'CUR_SKU') in (0 , 1)  
   BEGIN  
      CLOSE CUR_SKU  
      DEALLOCATE CUR_SKU  
   END

   --WL02 S
   IF CURSOR_STATUS('LOCAL' , 'CUR_UPD') in (0 , 1)  
   BEGIN  
      CLOSE CUR_UPD  
      DEALLOCATE CUR_UPD  
   END
   --WL02 E
  
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN   
      IF @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END   
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave_35'    
   END  

   SELECT             
         #TMP_PICK.PickSlipNo     
      ,  #TMP_PICK.LoadKey            
      ,  #TMP_PICK.OrderKey           
      ,  #TMP_PICK.ConsigneeKey       
      ,  #TMP_PICK.c_Company                       
      ,  UPPER(#TMP_PICK.LOC) AS LOC                 
      ,  #TMP_PICK.SKU                
      ,  #TMP_PICK.SkuDesc            
      ,  SUM(#TMP_PICK.Qty) AS Qty                                       
      ,  #TMP_PICK.LOCZone
      ,  #TMP_PICK.packcasecnt                     
      ,  SUM(#TMP_PICK.Cartons_cal) AS Cartons_cal                  
      ,  SUM(#TMP_PICK.Each_cal) AS Each_cal                
      ,  #TMP_PICK.SKUGROUP           
      ,  #TMP_PICK.Storerkey          
      ,  #TMP_PICK.Wavekey,#TMP_Pick.ExtOrderkey 
      ,  #TMP_PICK.DeliveryDate
      ,  #TMP_PICK.[Route]     
      ,  #TMP_PICK.c_Address1
      ,  #TMP_PICK.c_Address2 
      ,  #TMP_PICK.c_Address3
      ,  #TMP_PICK.c_Address4
      ,  #TMP_PICK.c_Zip
      ,  #TMP_PICK.c_City
      ,  #TMP_PICK.c_State
      ,  #TMP_PICK.c_Country
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
      ,  #TMP_PICK.M_VAT
      ,  #TMP_PICK.Export
      ,  #TMP_PICK.ManufacturerSKU
      ,  #TMP_PICK.SortSeq
      ,  #TMP_PICK.UserDefine04   --WL02
      ,  #TMP_PICK.UOM            --WL02
      ,  #TMP_PICK.DropID         --WL02
      ,  (SELECT CASE STUFF((SELECT DISTINCT ',' + RTRIM(T.UOM) 
                      FROM #TMP_PICK T 
                      WHERE T.OrderKey = #TMP_PICK.OrderKey
                      ORDER BY 1 FOR XML PATH('')),1,1,'' )
                 WHEN '2' THEN 'B'
                 WHEN '6' THEN 'PF'
                 ELSE 'B & PF' END) AS UOMIndicator   --WL02
   FROM  #TMP_PICK  
   GROUP BY  #TMP_PICK.PickSlipNo     
      ,  #TMP_PICK.LoadKey            
      ,  #TMP_PICK.OrderKey           
      ,  #TMP_PICK.ConsigneeKey       
      ,  #TMP_PICK.c_Company                       
      ,  UPPER(#TMP_PICK.LOC)            
      ,  #TMP_PICK.SKU                
      ,  #TMP_PICK.SkuDesc                           
      ,  #TMP_PICK.LOCZone
      ,  #TMP_PICK.packcasecnt                            
      ,  #TMP_PICK.SKUGROUP           
      ,  #TMP_PICK.Storerkey          
      ,  #TMP_PICK.Wavekey,#TMP_Pick.ExtOrderkey 
      ,  #TMP_PICK.DeliveryDate 
      ,  #TMP_PICK.[Route]
      ,  #TMP_PICK.c_Address1
      ,  #TMP_PICK.c_Address2 
      ,  #TMP_PICK.c_Address3
      ,  #TMP_PICK.c_Address4
      ,  #TMP_PICK.c_Zip
      ,  #TMP_PICK.c_City
      ,  #TMP_PICK.c_State
      ,  #TMP_PICK.c_Country
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
      ,  #TMP_PICK.M_VAT
      ,  #TMP_PICK.Export
      ,  #TMP_PICK.ManufacturerSKU
      ,  #TMP_PICK.SortSeq
      ,  #TMP_PICK.UserDefine04   --WL02
      ,  #TMP_PICK.UOM            --WL02
      ,  #TMP_PICK.DropID         --WL02
      ,  #TMP_PICK.LogicalLoc     --WL02
   ORDER BY #TMP_PICK.UOM   --WL02
          , CASE WHEN #TMP_PICK.UOM = '2' THEN #TMP_PICK.OrderKey   ELSE '' END   --WL02
          , CASE WHEN #TMP_PICK.UOM = '2' THEN #TMP_PICK.LogicalLoc ELSE '' END   --WL02
          , CASE WHEN #TMP_PICK.UOM = '2' THEN UPPER(#TMP_PICK.LOC) ELSE '' END   --WL02
          , CASE WHEN #TMP_PICK.UOM = '2' THEN '' ELSE #TMP_PICK.SortSeq END      --WL02

   IF OBJECT_ID('tempdb..#TMP_PICK') IS NOT NULL
      DROP TABLE #TMP_PICK
   
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN   
   END  
     
   RETURN  
END  

GO
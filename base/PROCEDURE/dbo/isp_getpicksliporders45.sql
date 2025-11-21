SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_GetPickSlipOrders45                            */  
/* Creation Date: 30-Mar-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan (Copy from nsp_GetPickSlipOrders24)                */  
/*                                                                      */  
/* Purpose: IDSPH - SOS#239075:JSU Picklist report                      */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 26-Nov-2013  TLTING     Change user_name() to SUSER_SNAME()          */  
/* 07-JUL-2015  CSCHONG    SOS346662 (CS01)                             */  
/* 24-Sep-2015  CSCHONG    SOS#352276 (CS02)                            */
/************************************************************************/  
   
CREATE PROC [dbo].[isp_GetPickSlipOrders45] (@c_loadkey NVARCHAR(10))  
AS  
BEGIN  
  SET NOCOUNT ON  
  SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue           INT     
         , @b_success            INT  
         , @n_err                INT  
         , @c_errmsg             NVARCHAR(255)  
            
         , @c_Storerkey          NVARCHAR(15)   
         , @c_OrderKey           NVARCHAR(10)   
         , @c_OrderLineNumber    NVARCHAR(5)   
         , @c_ConsigneeKey       NVARCHAR(15)   
         , @c_PickDetailKey      NVARCHAR(10)   
         , @c_PickSlipNo         NVARCHAR(10)   
         , @c_WaveKey            NVARCHAR(10)   
              
   SET @n_Continue         = 1  
   SET @b_success    = 1  
   SET @n_err     = 0  
   SET @c_ErrMsg           = ''  
     
   SET @c_Storerkey   = ''  
   SET @c_OrderKey    = ''  
   SET @c_OrderLineNumber  = ''  
   SET @c_ConsigneeKey  = ''  
   SET @c_PickDetailKey  = ''  
   SET @c_PickSlipNo   = ''  
   SET @c_WaveKey    = ''  
   
   SELECT PickSlipNo   = ISNULL(RTRIM(RefKeyLookup.PickSlipNo),'')   
       ,Company    = ISNULL(RTRIM(STORER.Company),'')      
       ,StorerKey   = ISNULL(RTRIM(ORDERS.StorerKey),'')      
       ,OrderKey   = ISNULL(RTRIM(ORDERS.OrderKey),'')  
       ,ExternOrderKey = ISNULL(RTRIM(ORDERS.ExternOrderKey),'')    
       ,ConsigneeKey  = ISNULL(RTRIM(ORDERS.ConsigneeKey),'')     
       ,C_Company   = ISNULL(RTRIM(ORDERS.C_Company),'')   
       ,C_Address1   = ISNULL(RTRIM(ORDERS.C_Address1),'')    
       ,C_Address2   = ISNULL(RTRIM(ORDERS.C_Address2),'')    
       ,C_Address3   = ISNULL(RTRIM(ORDERS.C_Address3),'')    
       ,C_Address4   = ISNULL(RTRIM(ORDERS.C_Address4),'')    
       ,LoadKey    = ISNULL(RTRIM(ORDERS.LoadKey ),'')   
       ,Route    = ISNULL(RTRIM(ORDERS.Route),'')            
       ,Notes    = CONVERT(NVARCHAR(250),ISNULL(ORDERS.Notes,''))     
       ,PrintFlag   = ISNULL(RTRIM(ORDERS.PrintFlag),'')            
       ,Facility   = ISNULL(RTRIM(ORDERS.Facility),'')     
       ,FacilityDescr  = ISNULL(RTRIM(FACILITY.Descr),'')    
       ,UOM             = ISNULL(RTRIM(ORDERDETAIL.UOM),'')   
       ,PL               = SUM(CASE WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') = '1' AND ISNULL(PACK.Pallet,0) > 0   
                                      THEN FLOOR(PICKDETAIL.Qty / PACK.Pallet)  
                                      ELSE 0 END)   
  
       ,CS               = SUM(CASE WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') = '2' AND ISNULL(PACK.Casecnt,0) > 0   
                                      THEN FLOOR(PICKDETAIL.Qty / PACK.CaseCnt)  
                                      ELSE 0 END)   
       ,IP               = SUM(CASE WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') = '3' AND ISNULL(PACK.InnerPack,0) > 0  
                                      THEN FLOOR(PICKDETAIL.Qty / PACK.Innerpack)   
                                      ELSE 0 END)  
       ,EA               = SUM(CASE WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') IN ('6','7')   
                                      THEN PICKDETAIL.Qty   
                                      ELSE 0 END)  
  
--         ,CS               = SUM(CASE WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') = '2' AND ISNULL(PACK.Pallet,0) > 0 AND ISNULL(PACK.Casecnt,0) > 0   
--                                      THEN FLOOR(PICKDETAIL.Qty % CONVERT(INT,PACK.Pallet) / PACK.CaseCnt)  
--                                      WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') = '2' AND ISNULL(PACK.Pallet,0) = 0 AND ISNULL(PACK.CaseCnt,0) > 0  
--                                      THEN FLOOR(PICKDETAIL.Qty / PACK.CaseCnt)  
--                                      ELSE 0 END)   
--         ,IP               = SUM(CASE WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') = '3' AND ISNULL(PACK.Pallet,0) > 0 AND ISNULL(PACK.Casecnt,0) > 0 AND ISNULL(PACK.InnerPack,0) > 0  
--                                      THEN FLOOR((PICKDETAIL.Qty % CONVERT(INT,PACK.Pallet)) % CONVERT(INT,PACK.Casecnt) / PACK.InnerPack)  
--                                      WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') = '3' AND ISNULL(PACK.Pallet,0) > 0 AND ISNULL(PACK.Casecnt,0) = 0 AND ISNULL(PACK.InnerPack,0) > 0  
--                                      THEN FLOOR((PICKDETAIL.Qty % CONVERT(INT,PACK.Pallet)) / PACK.Innerpack)   
--                                      WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') = '3' AND ISNULL(PACK.Pallet,0) = 0 AND ISNULL(PACK.Casecnt,0) > 0 AND ISNULL(PACK.InnerPack,0) > 0  
--                                      THEN FLOOR((PICKDETAIL.Qty % CONVERT(INT,PACK.CaseCnt)) / PACK.Innerpack)   
--                                      WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') = '3' AND ISNULL(PACK.Pallet,0) = 0 AND ISNULL(PACK.Casecnt,0) = 0 AND ISNULL(PACK.InnerPack,0) > 0  
--                                      THEN FLOOR(PICKDETAIL.Qty / PACK.Innerpack)   
--                                      ELSE 0 END)  
--         ,EA               = SUM(CASE WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') IN ('6','7') AND ISNULL(PACK.Pallet,0) > 0 AND ISNULL(PACK.Casecnt,0) > 0 AND ISNULL(PACK.InnerPack,0) > 0  
--                                      THEN (((PICKDETAIL.Qty % CONVERT(INT,PACK.Pallet))) % CONVERT(INT,PACK.CaseCnt)) % CONVERT(INT,PACK.InnerPack)   
--                                      WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') IN ('6','7') AND ISNULL(PACK.Pallet,0) > 0 AND ISNULL(PACK.Casecnt,0) > 0 AND ISNULL(PACK.InnerPack,0) = 0  
--                                      THEN (PICKDETAIL.Qty % CONVERT(INT,PACK.Pallet)) % CONVERT(INT,PACK.CaseCnt)  
--                                      WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') IN ('6','7') AND ISNULL(PACK.Pallet,0) > 0 AND ISNULL(PACK.Casecnt,0) = 0 AND ISNULL(PACK.InnerPack,0) > 0  
--                                      THEN (PICKDETAIL.Qty % CONVERT(INT,PACK.Pallet)) % CONVERT(INT,PACK.InnerPack)   
--                                      WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') IN ('6','7') AND ISNULL(PACK.Pallet,0) > 0 AND ISNULL(PACK.Casecnt,0) = 0 AND ISNULL(PACK.InnerPack,0) = 0  
--                                      THEN PICKDETAIL.Qty % CONVERT(INT,PACK.Pallet)   
--                                      WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') IN ('6','7') AND ISNULL(PACK.Pallet,0) = 0 AND ISNULL(PACK.Casecnt,0) > 0 AND ISNULL(PACK.InnerPack,0) > 0  
--                                      THEN (PICKDETAIL.Qty % CONVERT(INT,PACK.Casecnt)) % CONVERT(INT,PACK.InnerPack)   
--                 WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') IN ('6','7') AND ISNULL(PACK.Pallet,0) = 0 AND ISNULL(PACK.Casecnt,0) > 0 AND ISNULL(PACK.InnerPack,0) = 0  
--                                      THEN PICKDETAIL.Qty % CONVERT(INT,PACK.Casecnt)  
--                                      WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') IN ('6','7') AND ISNULL(PACK.Pallet,0) = 0 AND ISNULL(PACK.Casecnt,0) = 0 AND ISNULL(PACK.InnerPack,0) > 0  
--                                      THEN PICKDETAIL.Qty % CONVERT(INT,PACK.InnerPack)  
--                                      WHEN ISNULL(RTRIM(PICKDETAIL.UOM),'') IN ('6','7') AND ISNULL(PACK.Pallet,0) = 0 AND ISNULL(PACK.Casecnt,0) = 0 AND ISNULL(PACK.InnerPack,0) = 0  
--                                      THEN PICKDETAIL.Qty   
--                                      ELSE 0 END)  
  
       ,PickedQty   = ISNULL(SUM(PICKDETAIL.Qty) ,0)   
       ,Lot     = ISNULL(RTRIM(PICKDETAIL.Lot),'')        
       ,Loc     = ISNULL(RTRIM(PICKDETAIL.Loc),'')      
       ,ID     = ISNULL(RTRIM(PICKDETAIL.ID),'')   
       ,Sku     = ISNULL(RTRIM(SKU.Sku),'')    
       ,DESCR    = ISNULL(RTRIM(SKU.DESCR),'')        
       ,SUSR3            = ISNULL(RTRIM(SKU.SUSR3),'')        
       ,STDNETWGT   = ISNULL(SKU.STDNETWGT,0.00)       
       ,STDCUBE    = ISNULL(SKU.STDCUBE,0.00)      
       ,STDGROSSWGT  = ISNULL(SKU.STDGROSSWGT,0.00)      
       ,PackUOM1   = ISNULL(RTRIM(PACK.PackUOM1),'')      
       ,PackUOM2   = ISNULL(RTRIM(PACK.PackUOM2),'')     
       ,PackUOM3   = ISNULL(RTRIM(PACK.PackUOM3),'')       
       ,PackUOM4   = ISNULL(RTRIM(PACK.PackUOM4),'')   
       ,CaseCnt    = ISNULL(PACK.CaseCnt,0.00)     
       ,InnerPack   = ISNULL(PACK.InnerPack,0.00)   
       ,Pallet    = ISNULL(PACK.Pallet,0.00)  
       ,Lottable02   = ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')      
       ,Lottable04   = LOTATTRIBUTE.Lottable04      
       ,LogicalLocation  = ISNULL(RTRIM(LOC.LogicalLocation),'')   
       ,Note1            = ISNULL(RTRIM(ORDERDETAILREF.Note1),'')  
       ,Principal   = ISNULL(RTRIM(CODELKUP.Description),'')    
       ,Prepared    = CONVERT(NVARCHAR(10), Suser_Sname())  
       ,shelflife        = SKU.Shelflife                                  --(CS01)  
       ,Exp_date         = CASE WHEN ISNULL(SKU.Shelflife,0) = 0 THEN NULL ELSE LOTATTRIBUTE.Lottable04 + SKU.Shelflife END       --(CS01)  
       ,ShowExpDate      = CL1.Short                                         --(CS01)  
       ,LRoute= Loadplan.Route                                               --(CS02)
       ,LEXTLoadKey = Loadplan.Externloadkey                                 --(CS02) 
       ,LPriority = Loadplan.Priority                                        --(CS02)
       ,LPuserdefDate01 = Loadplan.LPuserdefDate01                           --(CS02)   
   INTO  #RESULT  
   FROM ORDERS WITH (NOLOCK)   
   JOIN STORER WITH (NOLOCK)                 ON (ORDERS.StorerKey = STORER.StorerKey)   
   JOIN FACILITY WITH (NOLOCK)               ON (ORDERS.Facility = FACILITY.Facility)  
   JOIN ORDERDETAIL WITH (NOLOCK)            ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)  
   JOIN PICKDETAIL WITH (NOLOCK)             ON (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey)  
                                             AND(ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)  
   JOIN LOC WITH (NOLOCK)                    ON (PICKDETAIL.Loc = LOC.Loc)  
   JOIN LOTATTRIBUTE WITH (NOLOCK)           ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)  
   JOIN SKU WITH (NOLOCK)                    ON (PICKDETAIL.Storerkey = SKU.StorerKey)   
                                             AND(PICKDETAIL.Sku = SKU.Sku)  
   JOIN PACK WITH (NOLOCK)                   ON (PACK.PackKey = SKU.PackKey)  
   LEFT JOIN STORER Consignee WITH (NOLOCK)  ON (Consignee.StorerKey = ORDERS.ConsigneeKey)   
   LEFT JOIN ORDERDETAILREF WITH (NOLOCK)    ON (ORDERDETAIL.Orderkey = ORDERDETAILREF.Orderkey)  
                                             AND(ORDERDETAIL.OrderLineNumber = ORDERDETAILREF.OrderLineNumber)  
   LEFT JOIN CODELKUP WITH (NOLOCK)          ON (CODELKUP.ListName = 'PRINCIPAL')  
                                             AND(CODELKUP.Code = SKU.SUSR3)  
   LEFT JOIN RefKeyLookup WITH (NOLOCK)      ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)   
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Code = 'SHOWEXPDATE' AND CL1.Long = 'r_dw_print_pickorder45'    --(CS01)  
                                             AND CL1.Storerkey = ORDERS.StorerKey )   
  JOIN LOADPLAN WITH (NOLOCK)                     --(CS02)
      ON LOADPLAN.loadkey = ORDERDETAIL.loadkey    --(CS02)                                                         --(CS01)  
   WHERE ORDERDETAIL.Loadkey = @c_Loadkey  
   GROUP BY ISNULL(RTRIM(RefKeyLookup.PickSlipNo),'')   
       , ISNULL(RTRIM(STORER.Company),'')         
       , ISNULL(RTRIM(ORDERS.StorerKey),'')                
       , ISNULL(RTRIM(ORDERS.OrderKey),'')                 
       , ISNULL(RTRIM(ORDERS.ExternOrderKey),'')           
       , ISNULL(RTRIM(ORDERS.ConsigneeKey),'')             
       , ISNULL(RTRIM(ORDERS.C_Company),'')                
       , ISNULL(RTRIM(ORDERS.C_Address1),'')               
       , ISNULL(RTRIM(ORDERS.C_Address2),'')               
       , ISNULL(RTRIM(ORDERS.C_Address3),'')               
       , ISNULL(RTRIM(ORDERS.C_Address4),'')  
       ,  ISNULL(RTRIM(ORDERS.LoadKey ),'')                
       , ISNULL(RTRIM(ORDERS.Route),'')                  
       , CONVERT(NVARCHAR(250),ISNULL(ORDERS.Notes,''))    
       , ISNULL(RTRIM(ORDERS.PrintFlag),'')      
       , ISNULL(RTRIM(ORDERS.Facility),'')                 
       , ISNULL(RTRIM(FACILITY.Descr),'')                        
       , ISNULL(RTRIM(ORDERDETAIL.UOM),'')      
       ,  CASE ISNULL(RTRIM(PICKDETAIL.UOM),'') WHEN '1' THEN ISNULL(RTRIM(PACK.PackUOM4),'')   
                                                  WHEN '2' THEN ISNULL(RTRIM(PACK.PackUOM1),'')   
                                                  WHEN '3' THEN ISNULL(RTRIM(PACK.PackUOM2),'')   
                                                  WHEN '6' THEN ISNULL(RTRIM(PACK.PackUOM3),'')   
                                                  WHEN '7' THEN ISNULL(RTRIM(PACK.PackUOM3),'')   
            END                  
       , ISNULL(RTRIM(PICKDETAIL.Lot),'')                  
       , ISNULL(RTRIM(PICKDETAIL.Loc),'')                  
       , ISNULL(RTRIM(PICKDETAIL.ID),'')     
       , ISNULL(RTRIM(SKU.Sku),'')                     
       , ISNULL(RTRIM(SKU.DESCR),'')                   
       , ISNULL(RTRIM(SKU.SUSR3),'')                   
       , ISNULL(SKU.STDNETWGT,0.00)                    
       , ISNULL(SKU.STDCUBE,0.00)                      
       , ISNULL(SKU.STDGROSSWGT,0.00)                  
       ,  ISNULL(RTRIM(PACK.PackUOM1),'')               
       ,  ISNULL(RTRIM(PACK.PackUOM2),'')   
       ,  ISNULL(RTRIM(PACK.PackUOM3),'')                
       ,  ISNULL(RTRIM(PACK.PackUOM4),'')               
       ,  ISNULL(PACK.CaseCnt,0.00)                     
       ,  ISNULL(PACK.InnerPack,0.00)                   
       ,  ISNULL(PACK.Pallet,0.00)   
       , ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')     
       , LOTATTRIBUTE.Lottable04                          
       ,  ISNULL(RTRIM(LOC.LogicalLocation),'') -- All pick list must sort by LogicalLocation  
       ,  ISNULL(RTRIM(ORDERDETAILREF.Note1),'')    
       ,  ISNULL(RTRIM(CODELKUP.Description),'')     
       ,  SKU.Shelflife                    --(CS01)   
       ,  CL1.Short                         --(CS01) 
       ,Loadplan.Route                                              --(CS02)
       ,Loadplan.Externloadkey                                      --(CS02) 
       ,Loadplan.Priority                                           --(CS02)
       ,Loadplan.LPuserdefDate01                                    --(CS02)         
   ORDER BY ISNULL(RTRIM(LOC.LogicalLocation),'')  
       , ISNULL(RTRIM(PICKDETAIL.Loc),'')    
       , ISNULL(RTRIM(SKU.Sku),'')  
       , ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')  
       , LOTATTRIBUTE.Lottable04  
                 
     
   -- process PickSlipNo  
     
   DECLARE C_LoadKey_ExternOrdKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT LoadKey, ConsigneeKey   
   FROM   #RESULT   
   WHERE  PickSlipNo IS NULL OR PickSlipNo = ''  
   ORDER BY LoadKey, ConsigneeKey   
  
   OPEN C_LoadKey_ExternOrdKey   
  
   FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_ConsigneeKey     
  
   WHILE (@@Fetch_Status <> -1)  
   BEGIN   
      SET @c_PickSlipNo = ''  
  
      SELECT @c_PickSlipNo = PICKHEADERKEY  
      FROM PICKHEADER WITH (NOLOCK)   
      WHERE ExternOrderKey = @c_LoadKey  
      AND   ConsigneeKey = @c_ConsigneeKey   
      AND   Zone = 'LB'  
  
      IF @c_PickSlipNo IS NULL OR @c_PickSlipNo = ''    
      BEGIN     
         SELECT @c_WaveKey = MAX(WaveKey)   
         FROM PICKHEADER WITH (NOLOCK)   
         WHERE ExternOrderKey = @c_LoadKey   
         AND   ConsigneeKey = @c_ConsigneeKey  
  
         IF @c_WaveKey IS NULL OR @c_WaveKey = ''   
         BEGIN  
            SET @c_waveKey = '1'  
         END  
         ELSE  
         BEGIN  
            SET @c_WaveKey = CONVERT(NVARCHAR(10),CONVERT(INT,@c_WaveKey) + 1)  
         END  
           
         EXECUTE nspg_GetKey  
              'PICKSLIP'   
            , 9      
            , @c_PickSlipNo   OUTPUT   
            , @b_success      OUTPUT   
            , @n_err          OUTPUT   
            , @c_errmsg       OUTPUT  
     
         IF @b_success = 1   
         BEGIN  
            SELECT @c_PickSlipNo = 'P' + @c_PickSlipNo            
  
            INSERT PICKHEADER (pickheaderkey, externOrderKey, WaveKey, ConsigneeKey, Zone)  
            VALUES (@c_PickSlipNo, @c_loadkey, @c_WaveKey, @c_ConsigneeKey, 'LB')  
  
            IF @@ERROR <> 0   
            BEGIN  
               SET @n_Continue = 3   
               BREAK   
            END   
         END -- @b_success = 1    
         ELSE   
         BEGIN  
            BREAK   
         END   
      END   
  
      IF @n_Continue = 1   
      BEGIN  
         DECLARE C_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PickDetail.PickDetailKey  
               ,PickDetail.OrderKey  
               ,PickDetail.OrderLineNumber   
         FROM   PickDetail WITH (NOLOCK)  
         JOIN   OrderDetail WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey)   
                                          AND(PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)   
         JOIN ORDERS WITH (NOLOCK)        ON ORDERS.OrderKey = PICKDETAIL.OrderKey  
         WHERE OrderDetail.LoadKey = @c_LoadKey   
         AND   Orders.ConsigneeKey = @c_ConsigneeKey  
         ORDER BY PickDetail.PickDetailKey   
  
         OPEN C_PickDetailKey  
  
         FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderKey, @c_OrderLineNumber   
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)   
            BEGIN   
               INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey) --SOS78054   
               VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey)                        
            END   
  
            FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderKey, @c_OrderLineNumber   
         END   
         CLOSE C_PickDetailKey   
         DEALLOCATE C_PickDetailKey   
      END         
  
  
      UPDATE #RESULT  
      SET PickSlipNo = @c_PickSlipNo  
      WHERE LoadKey = @c_LoadKey   
      AND   ConsigneeKey = @c_ConsigneeKey     
      AND  (PickSlipNo IS NULL OR PickSlipNo = '')  
  
      -- update prINTflag  
      UPDATE ORDERS  
      SET TrafficCop = NULL,  
          PrintFlag = 'Y'  
      WHERE LoadKey = @c_LoadKey  
      AND   ConsigneeKey = @c_ConsigneeKey  
  
      FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_ConsigneeKey    
   END -- while 1   
  
   CLOSE C_LoadKey_ExternOrdKey  
   DEALLOCATE C_LoadKey_ExternOrdKey   
     
   IF @n_Continue = 1   
   BEGIN  
      -- return result set  
      SELECT PickSlipNo  
            ,Company  
            ,StorerKey  
            ,OrderKey    
            ,ExternOrderKey    
            ,ConsigneeKey    
            ,C_Company  
            ,C_Address1  
            ,C_Address2  
            ,C_Address3  
            ,C_Address4   
            ,LoadKey  
            ,Route  
            ,Notes  
            ,PrintFlag  
            ,Facility  
            ,FacilityDescr  
            ,UOM  
            ,PL         = SUM(PL)  
            ,CS         = SUM(CS)  
            ,IP         = SUM(IP)  
            ,EA         = SUM(EA)  
            ,PickedQty  = SUM(PickedQty)  
            ,Lot  
            ,Loc  
            ,ID  
            ,Sku  
            ,Descr  
            ,Susr3  
            ,StdNetWgt  
            ,StdCube  
            ,StdGrossWgt  
            ,PackUOM1  
            ,PackUOM2  
            ,PackUOM3  
            ,PackUOM4  
            ,CaseCnt  
            ,InnerPack  
            ,Pallet  
            ,Lottable02  
            ,Lottable04  
            ,LogicalLocation   
            ,Note1  
            ,Principal  
            ,Prepared  
            ,shelflife           --(CS01)  
            ,Exp_Date            --(CS01)  
            ,ShowExpDate         --(CS01)  
            ,LRoute,LEXTLoadKey,LPriority,LPuserdefDate01              -- (CS02)
      FROM #RESULT   
      GROUP BY PickSlipNo  
            , Company  
            , StorerKey  
            ,  OrderKey    
            ,  ExternOrderKey    
            , ConsigneeKey    
            , C_Company  
            , C_Address1  
            , C_Address2  
            , C_Address3  
            , C_Address4   
            , LoadKey  
            , Route  
            , Notes  
            , PrintFlag  
            , Facility  
            , FacilityDescr  
            , UOM  
            , Lot  
            , Loc  
            , ID  
            , Sku  
            , Descr  
            , Susr3  
            , StdNetWgt  
            , StdCube  
            , StdGrossWgt  
            , PackUOM1  
            ,  PackUOM2  
            , PackUOM3  
            , PackUOM4  
            , CaseCnt  
            , InnerPack  
            , Pallet  
            , Lottable02  
            , Lottable04  
            , LogicalLocation   
            ,  Note1  
            , Principal  
            , Prepared  
            ,  shelflife           --(CS01)  
            ,  Exp_Date            --(CS01)  
            ,  ShowExpDate         --(CS01)  
            ,LRoute,LEXTLoadKey,LPriority,LPuserdefDate01                         --(CS02)
      ORDER BY PickSlipNo   
            , LogicalLocation     
            ,  Loc  
            ,  Sku  
            ,  Lottable02  
            ,  Lottable04  
   END   
  
   -- drop table  
   DROP TABLE #RESULT   
  
END  


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_loadmani_mbol08                                */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by: Mingle                                                   */    
/*                                                                      */    
/* Purpose: WMS-19333 MY-Load Manifest Standardization                  */    
/*                                                                      */    
/* Input Parameters: @c_mbolkey  - mbolkey                              */    
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* Return Status:  None                                                 */    
/*                                                                      */    
/* Usage:  Used for report dw = r_dw_load_manifest_mbol08               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */    
/* 2022-04-07   mingle01      Created - (WMS-19333)                     */    
/* 2022-12-21   mingle01      WMS-20348 - Update fields(ML01)           */ 
/* 2023-01-19   mingle02      WMS-21535 - Modify datatype(ML02)         */ 
/************************************************************************/    
CREATE     PROC [dbo].[isp_loadmani_mbol08] (    
     @c_mbolkey   NVARCHAR(10)    
)    
 AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
    DECLARE @n_continue       INT    
         ,  @c_errmsg         NVARCHAR(255)    
         ,  @b_success        INT    
         ,  @n_err            INT    
         ,  @n_StartTCnt      INT    
    
         ,  @c_SQL            NVARCHAR(MAX)    
         ,  @c_Storerkey      NVARCHAR(15)    
    
         ,  @c_Facility       NVARCHAR(5)    
         ,  @c_VoyageNumber   NVARCHAR(30)    
         ,  @dt_adddate       DATETIME    
         ,  @c_Remarks        NVARCHAR(40)    
         ,  @c_Loadkey        NVARCHAR(10)    
         ,  @c_ExternOrderkey NVARCHAR(50)   --tlting_ext    
         ,  @c_Consigneekey   NVARCHAR(15)    
         ,  @c_SHOWFIELD      NVARCHAR(5)  
         ,  @dt_DeliveryDate  DATETIME   
         ,  @dt_ArrivalDateFD DATETIME  
    
         ,  @c_ST_Company      NVARCHAR(45)    
         ,  @c_ST_Address1     NVARCHAR(45)    
         ,  @c_ST_Address2     NVARCHAR(45)    
         ,  @c_ST_Address3     NVARCHAR(45)    
         ,  @c_c_Address4     NVARCHAR(45)    
         ,  @c_c_Zip          NVARCHAR(18)    
         ,  @c_c_City         NVARCHAR(45)    
         ,  @c_Route          NVARCHAR(10)    
         ,  @c_BuyerPO        NVARCHAR(20)   
         ,  @c_invoiceno      NVARCHAR(20)
    
         ,  @n_NoOfCartons    INT    
    
    
         ,  @c_ExternSO       NVARCHAR(250)    
         ,  @c_MultiExternSO  NVARCHAR(1000)   --(Wan01)    
    
         ,  @n_ShowAddresses  INT    
         ,  @n_ShowBuyerPO    INT    
         ,  @n_ShowMultiExtSO INT    
         ,  @c_CarrierKey   NVARCHAR(10)    
         ,  @c_OrderKey     NVARCHAR(10)    
         ,  @c_Departuredate   NVARCHAR(30)    
         ,  @c_transmethod   NVARCHAR(30)    
         ,  @c_UserDefine03   NVARCHAR(20)    
         ,  @c_TPT   NVARCHAR(250)    
         ,  @c_Delivery_Zone   NVARCHAR(10)    
         ,  @c_RDD   NVARCHAR(30)    
         ,  @n_m3   DECIMAL(10,5)	--ML02    
         ,  @n_TTLCNTS   INT    
         ,  @n_totalwgt   DECIMAL(10,5)	--ML02    
         ,  @c_LM_SG   NVARCHAR(1)
         ,  @n_totcs INT
         ,  @n_pqty   INT
         ,  @c_mboldesc	NVARCHAR(30)
    
   SET @n_StartTCnt = @@TRANCOUNT    
    
   WHILE @@TRANCOUNT > 0    
   BEGIN    
      COMMIT TRAN    
   END    
    
   CREATE TABLE #TMP_LOAD    
      (  mbolkey              NVARCHAR(10)    
      ,  VoyageNumber         NVARCHAR(30)    
      ,  carrierkey           NVARCHAR(10)    
      ,  loadkey              NVARCHAR(10)    
      ,  orderkey             NVARCHAR(10)    
      ,  ST_Company           NVARCHAR(45)         
      ,  Departuredate        NVARCHAR(30)    
      ,  totalwgt             DECIMAL(10,5)	--ML02    
      ,  transmethod          NVARCHAR(30)    
      ,  route                NVARCHAR(10)    
      ,  m3                   DECIMAL(10,5)	--ML02    
      ,  Storerkey            NVARCHAR(15)    
      ,  deliverydate         DATETIME    
      ,  Facility             NVARCHAR(5)    
      ,  Userdefine03         NVARCHAR(20)    
      ,  ST_Address1          NVARCHAR(45)    
      ,  ST_Address2          NVARCHAR(45)    
      ,  ST_Address3          NVARCHAR(45)    
      ,  TTLCNTS              INT    
      ,  TPT                  NVARCHAR(250)    
      ,  Delivery_Zone        NVARCHAR(10)    
      ,  Externorderkey       NVARCHAR(50)    
      ,  RDD                  NVARCHAR(20)    
      ,  Consigneekey         NVARCHAR(15)  
      ,  SHOWFIELD            NVARCHAR(5)  
      ,  ArrivalDateFD        DATETIME  
      ,  LM_SG                NVARCHAR(1)  
      ,  pqty                 INT 
      ,  buyerpo              NVARCHAR(20)
      ,  totcs			         INT
      ,  mboldesc             NVARCHAR(30)  
      ,  invoiceno            NVARCHAR(20)
      )    
    
   BEGIN TRAN    
   DECLARE CUR_LOAD CURSOR FAST_FORWARD READ_ONLY FOR    
   SELECT   DISTINCT MH.MbolKey    
         ,  MH.VoyageNumber    
         ,  MH.CarrierKey    
         --,  CASE WHEN ISNULL(SC.Svalue,'') = '1' THEN ''    
         --        ELSE ISNULL(RTRIM(OH.Loadkey),'') END    
         --,  CASE WHEN ISNULL(SC.Svalue,'') = '0' THEN ISNULL(RTRIM(OH.Loadkey),'')   
         --  WHEN ISNULL(SC2.Svalue,'') = '0' THEN ISNULL(RTRIM(OH.Loadkey),'') ELSE '' END  
         --,CASE WHEN ISNULL(SC.Svalue,'') = '1' THEN ''    
         --              ELSE ISNULL(RTRIM(OH.Loadkey),'') END  
         ,  CASE WHEN OH.Storerkey NOT LIKE '%NIKE%' AND ISNULL(SC.Svalue,'') <> '1' THEN ISNULL(RTRIM(OH.Loadkey),'')   
                 WHEN OH.Storerkey LIKE '%NIKE%' AND ISNULL(SC2.Svalue,'') <> '1' THEN ISNULL(RTRIM(OH.Loadkey),'') ELSE '' END  
         --,  MD.OrderKey    
         ,  CONVERT(VARCHAR, MH.Departuredate, 105)    
         --,  MH.Departuredate    
         ,  MH.transmethod    
         ,  OH.StorerKey    
         ,  OH.deliverydate    
         ,  OH.Facility    
         ,  OH.UserDefine03    
         ,  ISNULL(CL1.Description ,'')    
         ,  MH.Delivery_Zone    
         --,  CASE WHEN ISNULL(SC.Svalue,'') <> '1' THEN ISNULL(RTRIM(OH.ExternOrderkey),'')   
         --  WHEN ISNULL(SC2.Svalue,'') <> '1' THEN ISNULL(RTRIM(OH.ExternOrderkey),'') ELSE '' END  
         ,  CASE WHEN OH.Storerkey NOT LIKE '%NIKE%' AND ISNULL(SC.Svalue,'') <> '1' THEN ISNULL(RTRIM(OH.ExternOrderkey),'')   
                       WHEN OH.Storerkey LIKE '%NIKE%' AND ISNULL(SC2.Svalue,'') = '1' THEN ISNULL(RTRIM(OH.ExternOrderkey),'') ELSE '' END  
         ,  CASE WHEN OH.Storerkey = 'ADIDAS' THEN CONVERT(VARCHAR,(CONVERT(DATETIME,OH.UserDefine03)),103) ELSE CONVERT(VARCHAR, MD.deliverydate, 103) END    
         ,  ISNULL(RTRIM(OH.Consigneekey),'')  
         ,  ISNULL(CL2.SHORT,'') AS SHOWFIELD  
         ,  MH.ArrivalDateFinalDestination
         --,  OH.Route	--ML01
         ,  SUM(ISNULL(PH.TTLCNTS,'0'))
         ,  MD.Description
   FROM MBOL         MH WITH (NOLOCK)    
   JOIN MBOLDETAIL   MD WITH (NOLOCK)  ON (MH.MBOLKey = MD.MBolKey)    
   JOIN ORDERS       OH WITH (NOLOCK)  ON (MD.OrderKey = OH.OrderKey) 
   JOIN packheader   PH WITH (NOLOCK)  ON PH.OrderKey = OH.OrderKey
   LEFT OUTER JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.ListName = 'TRANSMETH' AND CL1.Code = MH.transmethod     
   LEFT OUTER JOIN STORERCONFIG SC WITH (NOLOCK) ON ( OH.Storerkey = SC.Storerkey AND OH.Facility = SC.Facility    
                                                 AND  SC.Configkey='LoadManiMBOL_MY' AND SC.Svalue='1' )    
   LEFT OUTER JOIN STORERCONFIG SC2 WITH (NOLOCK) ON ( OH.Storerkey = SC2.Storerkey AND OH.Facility = SC2.Facility    
                                                 AND  SC2.Configkey='CustomLoadMani' AND SC2.Svalue='1' )  
   LEFT OUTER JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.ListName = 'REPORTCFG' AND CL2.Code = 'SHOWFIELD'  
                                                 AND CL2.Storerkey = OH.Storerkey AND CL2.LONG = 'r_dw_load_manifest_mbol08'  
   WHERE ( MH.MbolKey = @c_mbolkey ) 
	GROUP BY MH.MbolKey    
         ,  MH.VoyageNumber    
         ,  MH.CarrierKey    
         --,  CASE WHEN ISNULL(SC.Svalue,'') = '1' THEN ''    
         --        ELSE ISNULL(RTRIM(OH.Loadkey),'') END    
         --,  CASE WHEN ISNULL(SC.Svalue,'') = '0' THEN ISNULL(RTRIM(OH.Loadkey),'')   
         --  WHEN ISNULL(SC2.Svalue,'') = '0' THEN ISNULL(RTRIM(OH.Loadkey),'') ELSE '' END  
         --,CASE WHEN ISNULL(SC.Svalue,'') = '1' THEN ''    
         --              ELSE ISNULL(RTRIM(OH.Loadkey),'') END  
         ,  CASE WHEN OH.Storerkey NOT LIKE '%NIKE%' AND ISNULL(SC.Svalue,'') <> '1' THEN ISNULL(RTRIM(OH.Loadkey),'')   
                 WHEN OH.Storerkey LIKE '%NIKE%' AND ISNULL(SC2.Svalue,'') <> '1' THEN ISNULL(RTRIM(OH.Loadkey),'') ELSE '' END  
         --,  MD.OrderKey    
         ,  CONVERT(VARCHAR, MH.Departuredate, 105)    
         --,  MH.Departuredate    
         ,  MH.transmethod    
         ,  OH.StorerKey    
         ,  OH.deliverydate    
         ,  OH.Facility    
			,  OH.UserDefine03    
			,  ISNULL(CL1.Description ,'')    
			,  MH.Delivery_Zone    
         --,  CASE WHEN ISNULL(SC.Svalue,'') <> '1' THEN ISNULL(RTRIM(OH.ExternOrderkey),'')   
         --  WHEN ISNULL(SC2.Svalue,'') <> '1' THEN ISNULL(RTRIM(OH.ExternOrderkey),'') ELSE '' END  
         ,  CASE WHEN OH.Storerkey NOT LIKE '%NIKE%' AND ISNULL(SC.Svalue,'') <> '1' THEN ISNULL(RTRIM(OH.ExternOrderkey),'')   
                       WHEN OH.Storerkey LIKE '%NIKE%' AND ISNULL(SC2.Svalue,'') = '1' THEN ISNULL(RTRIM(OH.ExternOrderkey),'') ELSE '' END  
         ,  CASE WHEN OH.Storerkey = 'ADIDAS' THEN CONVERT(VARCHAR,(CONVERT(DATETIME,OH.UserDefine03)),103) ELSE CONVERT(VARCHAR, MD.deliverydate, 103) END    
         ,  ISNULL(RTRIM(OH.Consigneekey),'')  
         ,  ISNULL(CL2.SHORT,'')  
         ,  MH.ArrivalDateFinalDestination
         --,  OH.Route	--ML01
         --,  PH.TTLCNTS
         ,  MD.Description
    
   OPEN CUR_LOAD    
    
   FETCH NEXT FROM CUR_LOAD INTO  @c_MbolKey    
                                 ,@c_VoyageNumber    
                                 ,@c_CarrierKey    
                                 ,@c_Loadkey    
                                 --,@c_OrderKey    
                                 ,@c_Departuredate    
                                 ,@c_transmethod    
                                 ,@c_Storerkey    
                                 ,@dt_DeliveryDate    
                                 ,@c_Facility    
                                 ,@c_UserDefine03    
                                 ,@c_TPT    
                                 ,@c_Delivery_Zone    
                                 ,@c_ExternOrderkey    
                                 ,@c_RDD    
                                 ,@c_Consigneekey    
                                 ,@c_SHOWFIELD  
                                   ,@dt_ArrivalDateFD 
                                 --,@c_Route
                                 ,@n_totcs
                                 ,@c_mboldesc
    
    
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SET @c_ST_Company = ''    
      SET @c_ST_Address1 = ''    
      SET @c_ST_Address2= ''    
      SET @c_ST_Address3= ''    
      SET @c_c_Zip     = ''    
      SET @c_c_City   = ''    
      SET @c_Route     = ''    
      SET @c_BuyerPO   = ''    
    
      SET @c_ExternSO      = ''    
      SET @c_MultiExternSO = ''    
    
      SET @n_ShowAddresses = 0    
      SET @n_ShowBuyerPO   = 0    
      SET @n_ShowMultiExtSO= 0    
      --SELECT @n_ShowAddresses = MAX(CASE WHEN Code = 'ShowAddresses' THEN 1 ELSE 0 END)    
      --      ,@n_ShowBuyerPO   = MAX(CASE WHEN Code = 'ShowBuyerPO' THEN 1 ELSE 0 END)    
      --      ,@n_ShowMultiExtSO= MAX(CASE WHEN Code = 'ShowMultiExtSO' THEN 1 ELSE 0 END)    
      --FROM CODELKUP WITH (NOLOCK)    
      --WHERE ListName = 'REPORTCFG'    
      --AND   Storerkey= @c_Storerkey    
      --AND   Long     = 'r_dw_load_manifest_mbol03'    
      --AND   (Short    IS NULL OR Short = 'N')    
    
      SELECT TOP 1    
             @c_ST_Company  = CASE WHEN OH.STORERKEY IN ('JDSPORTSMY','NIKEMY','NIKESG','SPZ') THEN ISNULL(OH.C_Company,'') ELSE ISNULL(ST.Company,'') END   
            ,@c_ST_Address1 = CASE WHEN OH.STORERKEY NOT IN ('JDSPORTSMY','NIKEMY','NIKESG','SPZ') THEN ISNULL(ST.Address1,'') ELSE '' END   
            ,@c_ST_Address2 = CASE WHEN OH.STORERKEY NOT IN ('JDSPORTSMY','NIKEMY','NIKESG','SPZ') THEN ISNULL(ST.Address2,'') ELSE '' END
            ,@c_ST_Address3 = CASE WHEN OH.STORERKEY NOT IN ('JDSPORTSMY','NIKEMY','NIKESG','SPZ') THEN ISNULL(ST.Address3,'') ELSE '' END    
            --,@c_c_Address4 = CASE WHEN @n_ShowAddresses = 1 THEN ISNULL(OH.c_Address4,'') ELSE '' END    
            --,@c_c_Zip      = CASE WHEN @n_ShowAddresses = 1 THEN ISNULL(OH.c_Zip,'')      ELSE '' END    
            --,@c_c_City     = CASE WHEN @n_ShowAddresses = 1 THEN ISNULL(OH.c_City,'')     ELSE '' END    
            ,@c_BuyerPO    = CASE WHEN OH.STORERKEY = 'LVS' THEN ISNULL(OH.BuyerPO,'') ELSE '' END     
            ,@c_Route      = ISNULL(OH.Route,'') 
            ,@c_OrderKey   = OH.OrderKey
            ,@c_invoiceno = OH.InvoiceNo
      FROM ORDERS OH  WITH (NOLOCK)    
      --JOIN STORER ST(NOLOCK) ON ST.StorerKey = OH.StorerKey    
      LEFT OUTER JOIN Storer ST (NOLOCK) ON Oh.consigneekey = ST.Storerkey    
      WHERE OH.Loadkey        = CASE WHEN @c_Loadkey = '' THEN OH.Loadkey ELSE @c_Loadkey END    
      AND   OH.ExternOrderkey = CASE WHEN @c_ExternOrderkey = '' THEN OH.ExternOrderkey ELSE @c_ExternOrderkey END    
      AND   OH.Consigneekey = @c_Consigneekey    
      AND   OH.DeliveryDate = @dt_DeliveryDate    
    
   --SELECT @n_totalwgt = ISNULL(SUM(PICKDETAIL.Qty),0) * SKU.stdgrosswgt,        
   --       --totcs = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty),0) / PACK.CaseCnt ELSE 0 END,        
   --       --totea = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty),0) % CAST (PACK.CaseCnt AS Int) ELSE 0 END,        
   --       @n_m3 = CASE WHEN PACK.CaseCnt > 0 THEN (SKU.[Cube] * ISNULL(SUM(PICKDETAIL.Qty),0)) / (PACK.CaseCnt) ELSE 0 END,               
   --       --TTLCNTS = COUNT(DISTINCT PACKDETAIL.dropid)  
		 --   @n_pqty = ISNULL(PICKDETAIL.Qty,0)
   --   FROM PICKDETAIL WITH (NOLOCK)        
   --   INNER JOIN SKU WITH (NOLOCK) ON Pickdetail.sku = Sku.sku        
   --                                AND (Pickdetail.storerkey = Sku.storerkey)        
	  -- INNER JOIN PACK WITH (NOLOCK) ON PickDetail.PackKey = Pack.PackKey        
   --   INNER JOIN ORDERS WITH (NOLOCK) ON (PickDetail.OrderKey = Orders.OrderKey        
   --                                AND ORDERS.Mbolkey = @c_mbolkey)        
   --   --INNER JOIN PACKHEADER WITH (NOLOCK) ON PackHeader.PickSlipNo = PICKDETAIL.PickSlipNo        
   --   LEFT JOIN PACKHEADER WITH (NOLOCK) ON PackHeader.OrderKey = PICKDETAIL.OrderKey       
   --   LEFT JOIN PACKDETAIL WITH (NOLOCK) ON PackDetail.PickSlipNo = PackHeader.PickSlipNo    
   --   GROUP BY ORDERS.Mbolkey, ORDERS.Orderkey, PACK.CaseCnt, SKU.stdgrosswgt, SKU.[cube],PICKDETAIL.Qty 
	      
		
		--SET @c_orderkey = ''
		--SELECT @c_orderkey = OrderKey 
		--FROM ORDERS(NOLOCK)
		--WHERE MBOLKEY = @c_mbolkey

		--SELECT --@n_totalwgt = ISNULL(SUM(PICKDETAIL.Qty),0) * SKU.stdgrosswgt,        
  --        --totcs = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty),0) / PACK.CaseCnt ELSE 0 END,        
  --        --totea = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty),0) % CAST (PACK.CaseCnt AS Int) ELSE 0 END,        
  --        --@n_m3 = CASE WHEN PACK.CaseCnt > 0 THEN (SKU.[Cube] * ISNULL(SUM(PICKDETAIL.Qty),0)) / (PACK.CaseCnt) ELSE 0 END,               
  --        --TTLCNTS = COUNT(DISTINCT PACKDETAIL.dropid)  
		--    @n_pqty = ISNULL(SUM(PICKDETAIL.Qty),0)
  --    FROM PICKDETAIL WITH (NOLOCK) 
		--INNER JOIN SKU WITH (NOLOCK) ON Pickdetail.sku = Sku.sku        
  --                                 AND (Pickdetail.storerkey = Sku.storerkey)        
	 ----  INNER JOIN PACK WITH (NOLOCK) ON PickDetail.PackKey = Pack.PackKey        
  --    INNER JOIN ORDERS WITH (NOLOCK) ON (PickDetail.OrderKey = Orders.OrderKey)        
  --                                 --AND (ORDERS.Mbolkey = @c_mbolkey)        
  --    --INNER JOIN PACKHEADER WITH (NOLOCK) ON PackHeader.PickSlipNo = PICKDETAIL.PickSlipNo        
  --    --LEFT JOIN PACKHEADER WITH (NOLOCK) ON PackHeader.OrderKey = PICKDETAIL.OrderKey       
  --    --LEFT JOIN PACKDETAIL WITH (NOLOCK) ON PackDetail.PickSlipNo = PackHeader.PickSlipNo    
		--WHERE ORDERS.MBOLKEY = '0010871109'  
		--GROUP BY ORDERS.Mbolkey, ORDERS.Orderkey, PACK.CaseCnt, SKU.stdgrosswgt, SKU.[cube],PICKDETAIL.Qty
		--GROUP BY SKU.stdgrosswgt,ISNULL(PICKDETAIL.Qty,0)
		
		--SELECT @n_totcs = packheader.TTLCNTS
  --    FROM PACKHEADER WITH (NOLOCK)                
  --    INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.ORDERKEY = PACKHEADER.ORDERKEY)    
		--WHERE ORDERS.MBOLKEY = @c_mbolkey
    
      SET @n_TTLCNTS = 0    
      SELECT @n_TTLCNTS = COUNT(DISTINCT CASE WHEN @c_ExternOrderkey = '' THEN PD.DropID    
                                                  ELSE OD.Userdefine01 + OD.Userdefine02  
                                                  END)    
      FROM ORDERS       OH WITH (NOLOCK)    
      JOIN ORDERDETAIL  OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)    
      LEFT JOIN PACKHEADER   PH WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey)    
      LEFT JOIN PACKDETAIL   PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)    
      WHERE OH.Loadkey        = CASE WHEN @c_Loadkey = '' THEN OH.Loadkey ELSE @c_Loadkey END    
      AND   OH.ExternOrderkey = CASE WHEN @c_ExternOrderkey = '' THEN OH.ExternOrderkey ELSE @c_ExternOrderkey END    
      AND   OH.Consigneekey = @c_Consigneekey    
      AND   OH.DeliveryDate = @dt_DeliveryDate    
    
      --DECLARE CUR_EXTSO CURSOR FAST_FORWARD READ_ONLY FOR    
      --SELECT   DISTINCT ISNULL(RTRIM(OH.ExternOrderkey),'')    
      --FROM ORDERS OH  WITH (NOLOCK)    
      --WHERE OH.Loadkey        = CASE WHEN @c_Loadkey = '' THEN OH.Loadkey ELSE @c_Loadkey END    
      --AND   OH.ExternOrderkey = CASE WHEN @c_ExternOrderkey = '' THEN OH.ExternOrderkey ELSE @c_ExternOrderkey END    
      --AND   OH.Consigneekey = @c_Consigneekey    
      --AND   OH.DeliveryDate = @dt_DeliveryDate    
      --AND   @n_ShowMultiExtSO = 1    
    
      --OPEN CUR_EXTSO    
    
      --FETCH NEXT FROM CUR_EXTSO INTO @c_ExternSO    
    
      --WHILE @@FETCH_STATUS <> -1    
      --BEGIN    
      --   SET @c_MultiExternSO = @c_MultiExternSO + @c_ExternSO + ' '    
      --   FETCH NEXT FROM CUR_EXTSO INTO @c_ExternSO    
      --END    
      --CLOSE CUR_EXTSO    
      --DEALLOCATE CUR_EXTSO    
    
      --SET @c_MultiExternSO = CASE WHEN LEN(@c_MultiExternSO) > 0 THEN SUBSTRING(@c_MultiExternSO,1, LEN(@c_MultiExternSO)) ELSE '' END    
    
      INSERT INTO #TMP_LOAD    
            (  mbolkey                 
      ,  VoyageNumber             
      ,  carrierkey               
      ,  loadkey                  
      ,  orderkey                 
      ,  ST_Company                    
      ,  Departuredate           
      ,  totalwgt                 
      ,  transmethod              
      --,  route                    
      ,  m3                       
      ,  Storerkey                
      ,  deliverydate             
      ,  Facility                 
      ,  Userdefine03             
      ,  ST_Address1              
      ,  ST_Address2              
      ,  ST_Address3              
      ,  TTLCNTS                  
      ,  TPT                      
      ,  Delivery_Zone            
      ,  Externorderkey           
      ,  RDD                      
      ,  Consigneekey  
      ,  SHOWFIELD  
      ,  ArrivalDateFD  
      ,  LM_SG   
      ,  pqty
      ,  buyerpo
      ,  route
      ,  totcs
      ,  mboldesc
      ,  invoiceno
            )    
      VALUES    
            (    @c_MbolKey    
            ,  @c_VoyageNumber    
            ,  @c_CarrierKey    
            ,  @c_Loadkey    
            ,  @c_OrderKey    
            ,  @c_ST_Company    
            ,  @c_Departuredate    
            ,  @n_totalwgt    
            ,  @c_transmethod    
            --,  @c_Route    
            ,  @n_m3    
            ,  @c_Storerkey    
            ,  @dt_DeliveryDate    
            ,  @c_Facility    
            ,  @c_UserDefine03    
            ,  @c_ST_Address1    
            ,  @c_ST_Address2    
            ,  @c_ST_Address3    
            ,  @n_TTLCNTS    
            ,  @c_TPT    
            ,  @c_Delivery_Zone    
            ,  @c_ExternOrderkey    
            ,  @c_RDD    
            ,  @c_Consigneekey    
            ,  @c_showfield  
            ,  @dt_ArrivalDateFD  
            ,  CASE WHEN @c_Loadkey = '' THEN '1' ELSE '0' END 
            ,  @n_pqty
            ,  @c_BuyerPO
            ,  @c_route
            ,  @n_totcs
            ,  @c_mboldesc
            ,  @c_invoiceno
            )    
    
    
      FETCH NEXT FROM CUR_LOAD INTO  @c_MbolKey    
                                 ,@c_VoyageNumber    
                                 ,@c_CarrierKey    
                                 ,@c_Loadkey    
                                 --,@c_OrderKey    
                                 ,@c_Departuredate    
                                 ,@c_transmethod    
                                 ,@c_Storerkey    
                                 ,@dt_deliverydate    
                                 ,@c_Facility    
                                 ,@c_UserDefine03    
                                 ,@c_TPT    
                                 ,@c_Delivery_Zone    
                                 ,@c_ExternOrderkey    
                                 ,@c_RDD    
                                 ,@c_Consigneekey  
                                 ,@c_showfield  
                                 ,@dt_ArrivalDateFD  
                                   --,@c_Route
                                 ,@n_totcs
                                 ,@c_mboldesc
   END    
   CLOSE CUR_LOAD    
   DEALLOCATE CUR_LOAD    

   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT orderkey FROM #TMP_LOAD
   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_orderkey
   WHILE (@@fetch_status <> -1)
   BEGIN
      SELECT @n_pqty = ISNULL(SUM(qty), 0)
      FROM PICKDETAIL (NOLOCK)
      WHERE orderkey = @c_orderkey
      UPDATE #TMP_LOAD
      SET pqty = @n_pqty
      WHERE mbolkey = @c_mbolkey
      AND orderkey = @c_orderkey
      FETCH NEXT FROM cur_1 INTO @c_orderkey
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   SELECT ORDERS.Mbolkey,
   ORDERS.Orderkey,
   totwgt = ISNULL(SUM(PICKDETAIL.Qty),0) * SKU.stdgrosswgt,
   n_m3  = CASE WHEN PACK.CaseCnt > 0 THEN (SKU.[Cube] * ISNULL(SUM(PICKDETAIL.Qty),0)) / (PACK.CaseCnt) ELSE 0 END
   INTO #TEMPCALC
   FROM PICKDETAIL (NOLOCK), SKU (NOLOCK), PACK (NOLOCK), ORDERS (NOLOCK)
   WHERE PICKDETAIL.sku = SKU.sku
   AND PICKDETAIL.Storerkey = SKU.Storerkey
   AND SKU.PackKey = PACK.PackKey
   AND PICKDETAIL.Orderkey = ORDERS.Orderkey
   AND ORDERS.Mbolkey = @c_mbolkey
   GROUP BY ORDERS.Mbolkey, ORDERS.Orderkey, PACK.CaseCnt, SKU.stdgrosswgt,SKU.[Cube]

   SELECT Mbolkey, Orderkey, totwgt = SUM(totwgt), n_m3 = SUM(n_m3)
   INTO   #TEMPTOTAL
   FROM   #TEMPCALC
   GROUP BY Mbolkey, Orderkey

   UPDATE #TMP_LOAD
   SET totalwgt = t.totwgt,
       m3 = t.n_m3
   FROM  #TEMPTOTAL t
   WHERE #TMP_LOAD.mbolkey = t.Mbolkey
   AND   #TMP_LOAD.Orderkey = t.Orderkey
    
   QUIT_SP:    
   SELECT mbolkey                 
      ,  VoyageNumber             
      ,  carrierkey               
      ,  loadkey                  
      ,  orderkey                 
      ,  ST_Company                    
      ,  Departuredate           
      ,  totalwgt                 
      ,  transmethod              
      --,  route                    
      ,  m3                       
      ,  Storerkey                
      ,  deliverydate             
      ,  Facility                 
      ,  Userdefine03             
      ,  ST_Address1              
      ,  ST_Address2              
      ,  ST_Address3         
      ,  TTLCNTS                  
      ,  TPT                      
      ,  Delivery_Zone            
      ,  Externorderkey           
      ,  RDD                      
      ,  Consigneekey    
      ,  SHOWFIELD  
      ,  ArrivalDateFD  
      ,  LM_SG  
      ,  pqty
      ,  buyerpo
      ,  route
      ,  totcs
      ,  mboldesc
      ,  invoiceno
   FROM #TMP_LOAD  
   ORDER BY Externorderkey
   --ORDER BY Route    
   --      ,  Consigneekey    
   --      ,  Loadkey    
   --      ,  DeliveryDate    
   --      ,  Orderkey    
    
    
   WHILE @@TRANCOUNT < @n_StartTCnt    
   BEGIN    
      BEGIN TRAN    
   END    
    
   /* #INCLUDE <SPTPA01_2.SQL> */    
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt    
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_loadmani_mbol08'    
      --RAISERROR @n_err @c_errmsg    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
   END    
    
END  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/    
/* Stored Procedure: isp_Packing_List_88_rdt                             */    
/* Creation Date: 05-NOV-2020                                            */    
/* Copyright: IDS                                                        */    
/* Written by: CSCHONG                                                   */    
/*                                                                       */    
/* Purpose:WMS-15451  [RG] - Specialized Bicycle - Packing List (PL)     */    
/*                                                                       */    
/*                                                                       */    
/* Called By: report dw = r_dw_packing_list_88_rdt                       */    
/*                                                                       */    
/* PVCS Version: 1.2                                                     */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author     Ver. Purposes                                 */    
/* 04-DEC-2020  CSCHONG    1.1  WMS-15451 revised field logic (CS01)     */  
/* 13-JAN-2021  CheeJunYan 1.2  Discrete pickslip; CartonNo sort (CJY01) */  
/* 11-May-2021  WLChooi    1.3  WMS-16878 - Add new column (WL01)        */
/* 04-Jun-2021  Mingle     1.4  WMS-17177 - Change packdetail.qty to     */
/*                                          pickdetail.qty & add notes2  */   
/* 13-Jul-2021  Mingle     1.5  WMS-17177 - Add new mappings(ML02)       */                            
/*************************************************************************/    
    
CREATE PROC [dbo].[isp_Packing_List_88_rdt] (      
   @c_PickSlipNo      NVARCHAR(10)    
)      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF     
      
   DECLARE @n_rowid           int,      
           @c_cartontype      NVARCHAR(10),      
           @c_prevcartontype  NVARCHAR(10),      
           @n_cnt             int      
    
    
   DECLARE @c_CompanyName        NVARCHAR(45),    
           @c_RptName            NVARCHAR(150),    
           @c_ST_Secondary       NVARCHAR(15),    
           @c_storerkey          NVARCHAR(20),    
           @c_Consigneekey       NVARCHAR(45),    
           @c_CCompany           NVARCHAR(45),    
           @c_Loadkey            NVARCHAR(20),    
           @c_ExtOrderkey        NVARCHAR(50),    
           @c_CAddress1          NVARCHAR(45),    
           @c_CAddress2          NVARCHAR(45),    
           @c_CAddress3          NVARCHAR(45),    
           @c_CAddress4          NVARCHAR(45),    
           @c_Ccity              NVARCHAR(45),    
           @c_Ccountry           NVARCHAR(45),    
           @c_mbolkey            NVARCHAR(20),    
           @c_salesman           NVARCHAR(30),    
           @c_labelno            NVARCHAR(20),    
           @c_sku                NVARCHAR(20),    
           @c_susr1              NVARCHAR(20),    
           @c_style              NVARCHAR(20),    
           @c_color              NVARCHAR(10),    
           @c_ssize              NVARCHAR(10),    
           @c_measurement        NVARCHAR(10),    
           @c_Getmeasurement     NVARCHAR(10),    
           @c_FullAddress        NVARCHAR(250),    
           @n_Pqty               INT,    
           @n_cntExtOrdkey       INT,    
           @n_cntLoadkey         INT,    
           @c_storeCode          NVARCHAR(100),    
           @c_GetStyle           NVARCHAR(80),    
           @c_GetSize            NVARCHAR(50),    
           @n_TTLCTN             INT,    
           @n_TTLQTY             INT,    
           @n_TTLCBM             FLOAT,    
           @n_TTLGWGT            FLOAT,    
           @n_LooseCTN           INT,    
           @n_pltvol             FLOAT,    
           @n_pltwgt             FLOAT,    
           @n_picube             FLOAT,    
           @n_piweight           FLOAT,    
           @n_Convertpltvol      INT,           --CS01    
           @n_Convertctnvol      INT,           --CS01    
           @n_TTLNETWGT          FLOAT,         --CS01    
           @c_ShowSO             NVARCHAR(10) = 'N',   --WL01    
           @c_showcontact2       NVARCHAR(45),  --ML02  
           @c_shownotes2         NVARCHAR(45)   --ML02   
    
   SET  @n_LooseCTN = 0    
   SET  @n_TTLCTN = 0    
   SET  @n_TTLQTY = 0    
   SET  @n_TTLCBM = 0    
   SET  @n_TTLGWGT = 0    
   SET  @n_pltvol = 0    
   SET  @n_pltwgt = 0    
   SET  @n_picube = 0    
   SET  @n_piweight = 0    
   SET  @n_Convertpltvol = 0                            --CS01    
   SET  @n_Convertctnvol = 1000000                            --CS01    
   SET  @n_TTLNETWGT   = 0                              --CS01    
    
   CREATE TABLE #PACKLIST88       
         ( ROWID           INT IDENTITY (1,1) NOT NULL    
         , C_Address1      NVARCHAR(45) NULL       
         , C_Address2      NVARCHAR(45) NULL      
         , C_Address3      NVARCHAR(45) NULL      
         , CCITY           NVARCHAR(45) NULL      
         , CZIP            NVARCHAR(45) NULL      
         , CCompany        NVARCHAR(45) NULL       
         , Externorderkey  NVARCHAR(50) NULL      
         , CState          NVARCHAR(45) NULL      
         , CCountry        NVARCHAR(45) NULL      
         , BCompany        NVARCHAR(45) NULL         
         , B_Address1      NVARCHAR(45) NULL               
         , SDESCR          NVARCHAR(250) NULL                 
         , SKU             NVARCHAR(20)  NULL                       
         , PQty            INT   DEFAULT(0)          
         , labelno         NVARCHAR(20) NULL     
         , Pickslipno      NVARCHAR(20) NULL          
         , B_Address2      NVARCHAR(45) NULL    
         , B_Address3      NVARCHAR(45) NULL    
         , BCITY           NVARCHAR(45) NULL      
         , BZIP            NVARCHAR(45) NULL     
         , BState          NVARCHAR(45) NULL      
         , BCountry        NVARCHAR(45) NULL    
         , PICUBE          FLOAT   DEFAULT (0)      
         , PIFLength       FLOAT   DEFAULT (0)         
         , PIFWidth        FLOAT   DEFAULT (0)       
         , PIFHeight       FLOAT   DEFAULT (0)      
         , PIWeight        FLOAT   DEFAULT (0)      
         , TTLCTN          INT DEFAULT(0)    
         , PLTID           NVARCHAR(50) NULL    
         , PLTVOL          FLOAT   DEFAULT (0)     
         , PLTLENGTH       INT DEFAULT (0)    
         , PLTWIDTH        INT DEFAULT(0)    
         , PLTHEIGHT       INT DEFAULT (0)    
         , PLTWGT          FLOAT DEFAULT(0)    
         , C_Address4      NVARCHAR(45) NULL     
         , B_Address4      NVARCHAR(45) NULL    
         , LOOSECTH        INT    
         , TTLQTY          INT    
         , TTLCBM          FLOAT    
         , TTLGWGT         FLOAT    
         , RPTFLD01        NVARCHAR(500) NULL    
         , RPTFLD02        NVARCHAR(500) NULL      
         , RPTFLD03        NVARCHAR(500) NULL       
         , RPTFLD04        NVARCHAR(500) NULL      
         , RPTFLD05        NVARCHAR(500) NULL    
         , RPTFLD06        NVARCHAR(500) NULL    
         , RPTFLD07        NVARCHAR(500) NULL         
         , RPTFLD08        NVARCHAR(500) NULL    
         , RPTFLD09        NVARCHAR(500) NULL     
         , RPTFLD10        NVARCHAR(500) NULL    
         , RPTFLD11        NVARCHAR(500) NULL     
         , RPTFLD12        NVARCHAR(500) NULL      
         , RPTFLD13        NVARCHAR(500) NULL    
         , RPTFLD14        NVARCHAR(500) NULL    
         , RPTFLD15        NVARCHAR(500) NULL    
         , RPTFLD16        NVARCHAR(500) NULL    
         , RPTFLD17        NVARCHAR(500) NULL    
         , RPTFLD18        NVARCHAR(500) NULL     
         , RPTFLD19        NVARCHAR(500) NULL     
         , CartonNo        INT     
         , RPTFLD20        NVARCHAR(500) NULL      --CS01     
         , RPTFLD21        NVARCHAR(500) NULL      --CS01    
         , NetWGT          FLOAT                   --CS01    
         , TTLNETWGT       FLOAT                   --CS01    
         , ExternPOKey     NVARCHAR(20) NULL       --WL01  
         , RPTFLD22        NVARCHAR(500) NULL      --WL01  
         , notes2          NVARCHAR(100) NULL      --ML01  
         , C_Contact2      NVARCHAR(45) NULL       --ML02  
         , SHOWCONTACT2    NVARCHAR(10) NULL       --ML02  
         , SHOWNOTES2      NVARCHAR(10) NULL       --ML02  
         )        
    
    
   CREATE TABLE #PACKLIST88WPLT (    
    ROWID           INT IDENTITY (1,1) NOT NULL    
  , PLTID           NVARCHAR(50) NULL    
  , PLTVOL          FLOAT   DEFAULT (0)     
  , PLTWGT          FLOAT DEFAULT(0)    
    )    
    
    
   CREATE TABLE #PACKLIST88WOPLT (    
     ROWID           INT IDENTITY (1,1) NOT NULL    
   , PLTID           NVARCHAR(50) NULL    
   , CartonNo        INT NULL     
   , PICUBE          FLOAT   DEFAULT (0)     
   , PIWeight        FLOAT   DEFAULT (0)     
    )    
    
    --CS01 START    
   SET @c_storerkey = ''    
     
   SELECT @c_storerkey = PH.Storerkey     
   FROM PACKHEADER PH WITH (NOLOCK)    
   WHERE PH.PickSlipNo = @c_PickSlipNo     
     
   SELECT @n_Convertpltvol = CASE WHEN ISNUMERIC(C.short) = 1  THEN CAST(C.short as INT) ELSE 0 END    
   FROM CODELKUP C WITH (NOLOCK)    
   WHERE C.Listname = 'REPORTCFG' AND C.long = 'r_dw_packing_list_88_rdt'    
   AND C.storerkey = @c_storerkey AND C.code ='CONVPLTVOL'    
     
     
   SELECT @n_Convertctnvol = CASE WHEN ISNUMERIC(C.short) = 1  THEN CAST(C.short as INT) ELSE 0 END    
   FROM CODELKUP C WITH (NOLOCK)    
   WHERE C.Listname = 'REPORTCFG' AND C.long = 'r_dw_packing_list_88_rdt'    
   AND C.storerkey = @c_storerkey AND C.code ='CONVCTNVOL'    
    
     
   --CS01 END    
  
   --WL01  
   SELECT @c_ShowSO = ISNULL(C.Short,'N')  
   FROM CODELKUP C WITH (NOLOCK)    
   WHERE C.Listname = 'REPORTCFG' AND C.long = 'r_dw_packing_list_88_rdt'    
   AND C.Storerkey = @c_storerkey AND C.Code ='ShowSO'  
    
   INSERT INTO #PACKLIST88 (    C_Address1           
                              , C_Address2           
                              , C_Address3           
                              , CCITY                
                              , CZIP                 
                              , CCompany             
                              , Externorderkey       
                              , CState               
                              , CCountry             
                              , BCompany             
                              , B_Address1           
                              , SDESCR               
                              , SKU                  
                              , PQty                 
                              , labelno               
                              , Pickslipno           
                              , B_Address2           
                              , B_Address3           
                              , BCITY                
                              , BZIP                 
                              , BState               
                              , BCountry             
                              , PICUBE           
                              , PIFLength            
                              , PIFWidth             
                              , PIFHeight            
                              , PIWeight         
                              , TTLCTN               
                              , PLTID                
                              , PLTVOL               
                              , PLTLENGTH            
                              , PLTWIDTH             
                              , PLTHEIGHT            
                              , PLTWGT            
                              , C_Address4    
                              , B_Address4      
                              , LOOSECTH    
                              , TTLQTY    
                              , TTLCBM    
                              , TTLGWGT     
                              , RPTFLD01    
                              , RPTFLD02     
                              , RPTFLD03     
                              , RPTFLD04     
                              , RPTFLD05     
                              , RPTFLD06    
                              , RPTFLD07     
                              , RPTFLD08     
                              , RPTFLD09     
                              , RPTFLD10        
                              , RPTFLD11      
                              , RPTFLD12     
                              , RPTFLD13     
                              , RPTFLD14    
                              , RPTFLD15    
                              , RPTFLD16    
                              , RPTFLD17    
                              , RPTFLD18    
                              , RPTFLD19       
                              , CartonNo     
                              , RPTFLD20                 --CS01    
                              , RPTFLD21                 --CS01    
                              , NetWGT                   --CS01    
                              , TTLNETWGT                --CS01    
                              , ExternPOKey              --WL01  
                              , RPTFLD22                 --WL01  
                              , notes2                   --ML01    
                              , C_Contact2               --ML02  
                              , SHOWCONTACT2             --ML02  
                              , SHOWNOTES2               --ML02  
                           )    
   SELECT  ORDERS.c_Address1 AS ord_address1,      
      ISNULL(ORDERS.c_Address2,'') AS ord_Address2,    
      ISNULL(ORDERS.c_Address3,'') AS ord_Address3,    
      ISNULL(ORDERS.C_City,'') AS ord_City,      
      ISNULL(ORDERS.c_zip,'') AS ord_czip,      
      ORDERS.c_Company AS ord_company,     
      ORDERS.ExternOrderkey AS ExtOrdKey,    
      ISNULL(ORDERS.c_state,'') AS ord_cstate,      
      ISNULL(ORDERS.c_country,'') AS ord_ccountry,      
      ORDERS.B_Company AS ord_bcompany,      
      ORDERS.b_Address1 AS ord_baddress1,     
      SKU.DESCR as Sdescr,    
      PACKDETAIL.SKU as sku,    
      SUM(PICKDETAIL.qty) as Pqty,     
      PACKDETAIL.labelno AS Labelno,      
      PACKHEADER.PickSlipNo,       
      ISNULL(ORDERS.b_Address2,'') AS ord_baddress2,       
      ISNULL(ORDERS.b_Address3,'') AS ord_baddress3,       
      ISNULL(ORDERS.B_City,'') AS ord_BCity,      
      ISNULL(ORDERS.B_zip,'') AS ord_bzip,     
      ISNULL(ORDERS.b_state,'') AS ord_bstate,      
      ISNULL(ORDERS.b_country,'') AS ord_bcountry,      
      --CASE WHEN PACKINFO.[cube] = 0 THEN (PACKINFO.length*PACKINFO.width*PACKINFO.height) ELSE PACKINFO.cube END, 
      CASE WHEN PACKINFO.CARTONTYPE = 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN SKU.HEIGHT*SKU.LENGTH*SKU.WIDTH   
           WHEN PACKINFO.CARTONTYPE <> 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN CARTONIZATION.CartonLength*CARTONIZATION.CartonWidth*CARTONIZATION.CartonHeight   
           ELSE PACKINFO.[CUBE] END,   
      CASE WHEN PACKINFO.CARTONTYPE = 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN SKU.LENGTH   
           WHEN PACKINFO.CARTONTYPE <> 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN CARTONIZATION.CartonLength   
           ELSE PACKINFO.length END,
      CASE WHEN PACKINFO.CARTONTYPE = 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN SKU.WIDTH   
           WHEN PACKINFO.CARTONTYPE <> 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN CARTONIZATION.CartonWidth   
           ELSE PACKINFO.width END,
      CASE WHEN PACKINFO.CARTONTYPE = 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN SKU.HEIGHT   
           WHEN PACKINFO.CARTONTYPE <> 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN CARTONIZATION.CartonHeight   
           ELSE PACKINFO.height END,
      PACKINFO.weight,    
      0,ISNULL(PLT.Palletkey,''),(ISNULL(PLT.Length,0) * ISNULL(PLT.Width,0) * ISNULL(PLT.Height,0)),    
      ISNULL(PLT.Length,0) , ISNULL(PLT.Width,0) , ISNULL(PLT.Height,0),ISNULL(PLT.GrossWgt,0),    
      ISNULL(ORDERS.C_Address4,'') AS ord_caddress4, ISNULL(ORDERS.b_Address4,'') AS ord_baddress4,0,0,0,0,    
      ISNULL(MAX(CASE WHEN C.Code ='1' THEN RTRIM(C.long) ELSE '' END),'PACKING LIST') ,    
      ISNULL(MAX(CASE WHEN C.Code ='2' THEN RTRIM(C.long) ELSE '' END),'DELIVERY ID') ,    
      ISNULL(MAX(CASE WHEN C.Code ='3' THEN RTRIM(C.long) ELSE '' END),'SOLD TO ADDRESS') ,    
      ISNULL(MAX(CASE WHEN C.Code ='4' THEN RTRIM(C.long) ELSE '' END),'SHIP TO ADDRESS') ,    
      ISNULL(MAX(CASE WHEN C.Code ='5' THEN RTRIM(C.long) ELSE '' END),'Pallet ID') ,    
      ISNULL(MAX(CASE WHEN C.Code ='6' THEN RTRIM(C.long) ELSE '' END),'Carton No') ,                       --CS01    
      ISNULL(MAX(CASE WHEN C.Code ='7' THEN RTRIM(C.long) ELSE '' END),'Item Number') ,                     --CS01    
      ISNULL(MAX(CASE WHEN C.Code ='8' THEN RTRIM(C.long) ELSE '' END),'Description') ,                     --CS01     
      ISNULL(MAX(CASE WHEN C.Code ='9' THEN RTRIM(C.long) ELSE '' END),'Units (Qty)') ,      
      ISNULL(MAX(CASE WHEN C.Code ='10' THEN RTRIM(C.long) ELSE '' END),'Volume (CBM)') ,     
      ISNULL(MAX(CASE WHEN C.Code ='11' THEN RTRIM(C.long) ELSE '' END),'Length') ,     
      ISNULL(MAX(CASE WHEN C.Code ='12' THEN RTRIM(C.long) ELSE '' END),'Width') ,     
      ISNULL(MAX(CASE WHEN C.Code ='13' THEN RTRIM(C.long) ELSE '' END),'Height (CM)') ,     
      ISNULL(MAX(CASE WHEN C.Code ='14' THEN RTRIM(C.long) ELSE '' END),'G.Weight (KG)') ,                   --CS01    
      ISNULL(MAX(CASE WHEN C.Code ='15' THEN RTRIM(C.long) ELSE '' END),'# PALLETS') ,     
      ISNULL(MAX(CASE WHEN C.Code ='16' THEN RTRIM(C.long) ELSE '' END),'# LOOSE CARTONS') ,     
      ISNULL(MAX(CASE WHEN C.Code ='17' THEN RTRIM(C.long) ELSE '' END),'TOTAL QTY') ,     
      ISNULL(MAX(CASE WHEN C.Code ='18' THEN RTRIM(C.long) ELSE '' END),'TOTAL CBM') ,     
      ISNULL(MAX(CASE WHEN C.Code ='19' THEN RTRIM(C.long) ELSE '' END),'TOTAL GROSS WEIGHT'),    
      PACKDETAIL.CartonNo,          
      ISNULL(MAX(CASE WHEN C.Code ='18' THEN RTRIM(C.long) ELSE '' END),'N.Weight') ,                 --CS01    
      ISNULL(MAX(CASE WHEN C.Code ='19' THEN RTRIM(C.long) ELSE '' END),'TOTAL NETT WEIGHT'),         --CS01    
      SUM(PICKDETAIL.qty*SKU.STDNETWGT) as netwgt, 0 AS TTLNETWGT,                                       --CS01    
      ISNULL(OD.ExternPOKey,''),   --WL01  
      ISNULL(MAX(CASE WHEN C.Code ='22' THEN RTRIM(C.long) ELSE '' END),'SO#'),   --WL01   
      ORDERS.notes2,   --ML01    
      ORDERS.C_Contact2, --ML02  
      ISNULL(C2.SHORT,'')  AS SHOWCONTACT2, --ML02  
      ISNULL(C3.SHORT,'')  AS SHOWNOTES2    --ML02  
   FROM ORDERS WITH (NOLOCK) --ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)      
   JOIN ORDERDETAIL OD (NOLOCK) ON (ORDERS.OrderKey = OD.OrderKey)      
   JOIN SKU WITH (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND OD.Sku = SKU.Sku)      
       
   -- JOIN PACKHEADER WITH (NOLOCK) ON ( ORDERS.Loadkey = PACKHEADER.Loadkey)            -- CJY01    
   JOIN PACKHEADER WITH (NOLOCK) ON ( ORDERS.orderkey = PACKHEADER.orderkey)             -- CJY01    
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo AND      
                                            OD.Storerkey = PACKDETAIL.Storerkey AND      
                                             OD.Sku = PACKDETAIL.Sku)      
   JOIN PACKINFO WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKINFO.PickSlipNo AND PACKDETAIL.CartonNo = PackInfo.CartonNo)   
   JOIN PICKDETAIL   WITH (NOLOCK) ON  (OD.Orderkey = PICKDETAIL.Orderkey AND PICKDETAIL.sku = OD.sku   
                                   AND PICKDETAIL.OrderLineNumber = OD.OrderLineNumber AND PICKDETAIL.dropid = PACKDETAIL.labelno) --ML01  
   LEFT JOIN CARTONIZATION WITH (NOLOCK) ON (CARTONIZATION.CartonType = PackInfo.CartonType AND cartonization.cartonizationgroup = 'SPZ')       
   LEFT JOIN PALLETDETAIL PLTD (NOLOCK) ON PLTD.Storerkey = PACKDETAIL.StorerKey AND PLTD.CaseId=PACKDETAIL.LabelNo     
                                         --  AND PLTD.sku = PACKDETAIL.SKU    
   LEFT JOIN PALLET PLT WITH (NOLOCK) ON PLT.PalletKey = PLTD.PalletKey    
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON c.listname = 'REPORTFLD' AND c.storerkey = ORDERS.storerkey    
   --LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.Listname = 'REPORTCFG' AND C1.Code = 'CONVPLTVOL'   
                                       --AND C1.Long = 'r_dw_packing_list_88_rdt' AND C1.StorerKey = Orders.StorerKey  
   LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.Listname = 'REPORTCFG' AND C2.Code = 'SHOWCONTACT2'   
                                       AND C2.Long = 'r_dw_packing_list_88_rdt' AND C2.StorerKey = Orders.StorerKey  
   LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON C3.Listname = 'REPORTCFG' AND C3.Code = 'SHOWNOTES2'   
                                       AND C3.Long = 'r_dw_packing_list_88_rdt' AND C3.StorerKey = Orders.StorerKey  
  
   WHERE PACKHEADER.PickSlipNo  = @c_PickSlipNo    
   group by ORDERS.c_Address1 ,      
      ISNULL(ORDERS.c_Address2,''),    
      ISNULL(ORDERS.c_Address3,''),    
      ISNULL(ORDERS.C_City,''),      
      ISNULL(ORDERS.c_zip,''),      
      ORDERS.c_Company,     
      ORDERS.ExternOrderkey,    
      ISNULL(ORDERS.c_state,''),      
      ISNULL(ORDERS.c_country,''),      
      ORDERS.B_Company,      
      ORDERS.b_Address1,     
      SKU.DESCR,    
      PACKDETAIL.SKU,     
      PACKDETAIL.labelno,      
      PACKHEADER.PickSlipNo,       
      ISNULL(ORDERS.b_Address2,''),       
      ISNULL(ORDERS.b_Address3,''),       
      ISNULL(ORDERS.B_City,''),      
      ISNULL(ORDERS.B_zip,''),     
      ISNULL(ORDERS.b_state,''),      
      ISNULL(ORDERS.b_country,''),     
      --PICKDETAIL.qty,    
      --CASE WHEN PACKINFO.[cube] = 0 THEN (PACKINFO.length*PACKINFO.width*PACKINFO.height) ELSE PACKINFO.[cube] END,
      CASE WHEN PACKINFO.CARTONTYPE = 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN SKU.HEIGHT*SKU.LENGTH*SKU.WIDTH   
           WHEN PACKINFO.CARTONTYPE <> 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN CARTONIZATION.CartonLength*CARTONIZATION.CartonWidth*CARTONIZATION.CartonHeight   
           ELSE PACKINFO.[CUBE] END,    
      CASE WHEN PACKINFO.CARTONTYPE = 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN SKU.LENGTH   
           WHEN PACKINFO.CARTONTYPE <> 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN CARTONIZATION.CartonLength   
           ELSE PACKINFO.length END,
      CASE WHEN PACKINFO.CARTONTYPE = 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN SKU.WIDTH   
           WHEN PACKINFO.CARTONTYPE <> 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN CARTONIZATION.CartonWidth   
           ELSE PACKINFO.width END,
      CASE WHEN PACKINFO.CARTONTYPE = 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN SKU.HEIGHT   
           WHEN PACKINFO.CARTONTYPE <> 'CTNORG' AND cartonization.cartonizationgroup = 'SPZ' THEN CARTONIZATION.CartonHeight   
           ELSE PACKINFO.height END,
      PACKINFO.weight,    
      ISNULL(PLT.PalletKey,''),    
      ISNULL(PLT.Length,0) , ISNULL(PLT.Width,0) , ISNULL(PLT.Height,0),    
      ISNULL(PLT.GrossWgt,0),ISNULL(ORDERS.C_Address4,'') ,ISNULL(ORDERS.B_Address4,''),packdetail.CartonNo,    
      SKU.STDNETWGT, ISNULL(OD.ExternPOKey,''),      --CS01   --WL01  
      ORDERS.notes2,   --ML01   
      ORDERS.C_Contact2,   --ML02  
      ISNULL(C2.SHORT,''), --ML02  
      ISNULL(C3.SHORT,'')  --ML02  
  
   ORDER BY PACKHEADER.PickSlipNo,CASE WHEN ISNULL(PLT.PalletKey,'') <> '' THEN 1 ELSE 2 END,    
   PACKDETAIL.labelno,PACKDETAIL.SKU    
       
      
   SELECT @n_LooseCTN = count(DISTINCT labelno)    
   FROM #PACKLIST88    
   WHERE pltid = ''     
    
   SELECT @n_TTLCTN = count(DISTINCT pltid )    
      --  ,@n_TTLQTY = sum(pqty)    
   FROM #PACKLIST88    
   WHERE pltid <> ''     
    
   SELECT @n_TTLQTY = sum(pqty)    
         ,@n_TTLNETWGT = sum(netwgt)    
   FROM #PACKLIST88    
     
   INSERT INTO #PACKLIST88WPLT (PLTID,PLTVOL,PLTWGT)    
   SELECT DISTINCT Pltid,PLTVOL,PLTWGT    
   FROM #PACKLIST88    
   WHERE pltid <> ''     
    
   INSERT INTO #PACKLIST88WOPLT (PLTID,CartonNo,PICUBE,PIWeight)    
   SELECT DISTINCT Pltid,CartonNo,(PICUBE),(PIWeight)    
   FROM #PACKLIST88    
   WHERE pltid = ''    
   GROUP by  Pltid,CartonNo,(PICUBE),(PIWeight)    
    
   SELECT @n_pltvol = CASE WHEN  @n_Convertpltvol > 1 THEN SUM(PLTVOL)/@n_Convertpltvol ELSE SUM(PLTVOL) END    
         ,@n_pltwgt = SUM(PLTWGT)    
   FROM #PACKLIST88WPLT    
    
    
   SELECT  @n_picube = CASE WHEN @n_Convertctnvol > 1 THEN SUM(picube)/@n_Convertctnvol ELSE SUM(picube) END    
         , @n_piweight = SUM(piweight)     
   FROM #PACKLIST88WOPLT    
    
--select * from #PACKLIST88WOPLT    
    
   SET  @n_TTLCBM = ISNULL(@n_pltvol,0) + ISNULL(@n_picube,0)    
   SET  @n_TTLGWGT = ISNULL(@n_pltwgt,0) + ISNULL(@n_piweight,0)    
    
--select @n_TTLCBM '@n_TTLCBM'    
    
    
   SELECT  Pickslipno    
         , Externorderkey     
         , C_Address1     
         , CCompany           
         , C_Address2           
         , C_Address3           
         , CCITY                
         , CZIP                 
         , labelno                        
         , CState               
         , CCountry      
         , SKU                  
         , PQty            
         , BCompany             
         , B_Address1           
         , SDESCR               
         , B_Address2           
         , B_Address3           
         , BCITY                
         , BZIP                 
         , BState               
         , BCountry             
         , CASE WHEN @n_Convertctnvol > 1 THEN CAST((PICUBE/@n_Convertctnvol)as decimal(10,2)) ELSE CAST(PICUBE as Decimal(10,2)) END AS PICUBE            
         , PIFLength            
         , PIFWidth             
         , PIFHeight            
         , PIWeight         
         , @n_TTLCTN as TTLCTN               
         , PLTID            
       --  , PLTVOL as 'chkPLTVOL'          
         , CASE WHEN @n_Convertpltvol > 1 THEN CAST((PLTVOL/@n_Convertpltvol) as decimal(10,2)) ELSE PLTVOL END AS PLTVOL              
         , PLTLENGTH            
         , PLTWIDTH             
         , PLTHEIGHT            
         , PLTWGT     
         , C_Address4    
         , B_Address4    
         ,@n_LooseCTN as LOOSECTH    
         ,@n_TTLQTY  as TTLQTY    
         , CAST(@n_TTLCBM as decimal(10,2)) as TTLCBM    
         , CAST(@n_TTLGWGT as decimal(10,2)) as TTLGWGT     
         , CASE WHEN ISNULL(RPTFLD01,'') <> '' THEN RPTFLD01 ELSE 'PACKING LIST' END AS RPTFLD01    
         , CASE WHEN ISNULL(RPTFLD02,'') <> '' THEN RPTFLD02 ELSE 'DELIVERY ID' END as RPTFLD02             
         , CASE WHEN ISNULL(RPTFLD03,'') <> '' THEN RPTFLD03 ELSE 'SOLD TO ADDRESS' END AS RPTFLD03                 
         , CASE WHEN ISNULL(RPTFLD04,'') <> '' THEN RPTFLD04 ELSE 'SHIP TO ADDRESS' END AS RPTFLD04                 
         , CASE WHEN ISNULL(RPTFLD05,'') <> '' THEN RPTFLD05 ELSE 'Pallet ID' END AS RPTFLD05                        
         , CASE WHEN ISNULL(RPTFLD06,'') <> '' THEN RPTFLD06 ELSE 'Carton No' END AS  RPTFLD06          --CS01                   
         , CASE WHEN ISNULL(RPTFLD07,'') <> '' THEN RPTFLD07 ELSE 'Item Number' END AS   RPTFLD07       --CS01                     
         , CASE WHEN ISNULL(RPTFLD08,'') <> '' THEN RPTFLD08 ELSE 'Description' END AS RPTFLD08         --CS01                         
         , CASE WHEN ISNULL(RPTFLD09,'') <> '' THEN RPTFLD09 ELSE 'Units (Qty)' END AS  RPTFLD09                    
         , CASE WHEN ISNULL(RPTFLD10,'') <> '' THEN RPTFLD10 ELSE 'Volume (CBM)' END AS RPTFLD10                    
         , CASE WHEN ISNULL(RPTFLD11,'') <> '' THEN RPTFLD11 ELSE 'Length' END AS  RPTFLD11                         
         , CASE WHEN ISNULL(RPTFLD12,'') <> '' THEN RPTFLD12 ELSE 'Width' END AS   RPTFLD12                         
         , CASE WHEN ISNULL(RPTFLD13,'') <> '' THEN RPTFLD13 ELSE 'Height (CM)' END AS RPTFLD13                     
         , CASE WHEN ISNULL(RPTFLD14,'') <> '' THEN RPTFLD14 ELSE 'G.Weight (KG)' END AS RPTFLD14        --CS01             
         , CASE WHEN ISNULL(RPTFLD15,'') <> '' THEN RPTFLD15 ELSE '# PALLETS' END AS   RPTFLD15                     
         , CASE WHEN ISNULL(RPTFLD16,'') <> '' THEN RPTFLD16 ELSE '# LOOSE CARTONS' END AS RPTFLD16                
         , CASE WHEN ISNULL(RPTFLD17,'') <> '' THEN RPTFLD17 ELSE 'TOTAL QTY' END AS  RPTFLD17                      
         , CASE WHEN ISNULL(RPTFLD18,'') <> '' THEN RPTFLD18 ELSE 'TOTAL CBM' END AS  RPTFLD18                      
         , CASE WHEN ISNULL(RPTFLD19,'') <> '' THEN RPTFLD19 ELSE 'TOTAL GROSS WEIGHT' END AS RPTFLD19    
         , CASE WHEN ISNULL(RPTFLD20,'') <> '' THEN RPTFLD20 ELSE 'N.Weight' END AS  RPTFLD20                    --CS01          
         , CASE WHEN ISNULL(RPTFLD21,'') <> '' THEN RPTFLD21 ELSE 'TOTAL NETT WEIGHT' END AS RPTFLD21            --CS01       
         , CAST(NetWGT as decimal(10,2)) as NetWGT,@n_TTLNETWGT as TTLNETWGT                                     --CS01        
         , CartonNo                                                                                     -- CJY01         
         , CASE WHEN ISNULL(RPTFLD22,'') <> '' THEN RPTFLD22 ELSE 'SO#' END AS RPTFLD22            --WL01     
         , ExternPOKey  --WL01  
         , @c_ShowSO AS ShowSO   --WL01    
         , notes2      --ML01     
         , C_Contact2  --ML02   
         , SHOWCONTACT2--ML02        
         , SHOWNOTES2  --ML02       
   FROM #PACKLIST88 (nolock)    
   ORDER BY ROWID    
    
    
   DROP TABLE #PACKLIST88    
   DROP TABLE #PACKLIST88WPLT    
   DROP TABLE #PACKLIST88WOPLT    
    
END

 

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Stored Proc: isp_POD_07                                              */    
/* Creation Date: 09-MAR-2017                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: Wan                                                      */    
/*                                                                      */    
/* Purpose: WMS-1282 - CN-Nike SDC POD Report                           */    
/*        :                                                             */    
/* Called By: r_dw_pod_07 (reporttype = 'NIKEPODRPT')                   */    
/*          :                                                           */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver Purposes                                  */    
/* 25-Aug-2017  CSCHONG   1.1 WMS-2742 - add new field (CS01)           */    
/* 23-Nov-2017  WLCHOOI   1.2 WMS-3509 - add spaces after the delimiter */    
/*          (WL01)                                                      */    
/* 17-JUL-2018  CSCHONG   1.3 WMS-5685 - Revised field logic (CS02)     */    
/* 23-Aug-2018  CSCHONG   1.4 WMS-5685 - Fix ctn issue (CS02a)          */  
/* 02-Nov-2018  LZG       1.6 INC0452488 - Fix incorrect report Qty due */  
/*                            to cut off of #TMP_PODRPT.PickSlipNo(ZG01)*/  
/* 27-Aug-2018  CSCHONG   1.5 WMS-6055 - support for conso pick (CS03)  */  
/* 26-Feb-2021  mingle01  1.6 WMS-16413 - add codelkup to remove 'POD-' */
/*                                        for mbolkey barcode           */  
/************************************************************************/    
CREATE PROC [dbo].[isp_POD_07]    
           @c_MBOLKey   NVARCHAR(10)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE      
           @n_StartTCnt       INT    
         , @n_Continue        INT     
         , @c_getmbolkey      NVARCHAR(20)    --CS02    
         , @c_getPickslipno   NVARCHAR(1000)  --CS02      -- ZG01  
    
   SET @n_StartTCnt = @@TRANCOUNT    
    
   WHILE @@TRANCOUNT > 0    
   BEGIN    
      COMMIT TRAN    
   END    
    
   CREATE TABLE #TMP_POD    
      (  RowRef         INT            IDENTITY(1,1)    
      ,  MBOLKey        NVARCHAR(10)   NULL  DEFAULT('')    
      ,  Orderkey       NVARCHAR(10)   NULL  DEFAULT('')    
      ,  LoadKey        NVARCHAR(10)   NULL  DEFAULT('')    
      ,  Consigneekey   NVARCHAR(15)   NULL  DEFAULT('')    
      ,  PickSlipNo     NVARCHAR(10)   NULL  DEFAULT('')    
      ,  CRD            NVARCHAR(30)   NULL  DEFAULT('')    
      )    
    
   CREATE TABLE #TMP_PODRPT    
      (  MBOLKey        NVARCHAR(10)   NULL  DEFAULT('')    
      ,  Facility       NVARCHAR(5)    NULL  DEFAULT('')    
      ,  MBOLShipDate   DATETIME       NULL    
      ,  EstArrivalDate DATETIME       NULL    
      ,  Address1       NVARCHAR(45)   NULL  DEFAULT('')       
      ,  Address2       NVARCHAR(45)   NULL  DEFAULT('')    
      ,  Address3       NVARCHAR(45)   NULL  DEFAULT('')    
      ,  Address4       NVARCHAR(45)   NULL  DEFAULT('')    
      ,  Contact1       NVARCHAR(30)   NULL  DEFAULT('')    
      ,  Phone1         NVARCHAR(18)   NULL  DEFAULT('')    
      ,  Fax1           NVARCHAR(18)   NULL  DEFAULT('')    
      ,  Loadkey        NVARCHAR(500)  NULL  DEFAULT('')    
      ,  PickSlipNo     NVARCHAR(1000) NULL  DEFAULT('')            -- ZG01  
      ,  Storerkey      NVARCHAR(15)   NULL  DEFAULT('')    
      ,  Consigneekey   NVARCHAR(15)   NULL  DEFAULT('')    
      ,  C_Company      NVARCHAR(45)   NULL  DEFAULT('')    
      ,  C_Address1     NVARCHAR(45)   NULL  DEFAULT('')    
      ,  C_Address2     NVARCHAR(45)   NULL  DEFAULT('')    
      ,  C_Address3     NVARCHAR(45)   NULL  DEFAULT('')    
      ,  C_Address4     NVARCHAR(45)   NULL  DEFAULT('')    
      ,  C_City         NVARCHAR(45)   NULL  DEFAULT('')    
      ,  C_Contact1     NVARCHAR(30)  NULL  DEFAULT('')    
      ,  C_Phone1       NVARCHAR(18)   NULL  DEFAULT('')    
      ,  FWQty          INT            NULL  DEFAULT(0)    
      ,  APPQty         INT            NULL  DEFAULT(0)    
      ,  EQQty          INT            NULL  DEFAULT(0)    
      ,  NoOfCarton     INT            NULL  DEFAULT(0)    
      ,  CRD            NVARCHAR(30)   NULL  DEFAULT('')    
      ,  POD_Barcode    NVARCHAR(30)   NULL  DEFAULT('')    
      ,  FWCtn          INT            NULL  DEFAULT(0)       --CS01    
      ,  APPCtn         INT            NULL  DEFAULT(0)       --CS01    
      ,  EQCtn          INT            NULL  DEFAULT(0)       --CS01    
      ,  DELNotes       NVARCHAR(30)   NULL  DEFAULT('')      --CS02    
      )    
    
   INSERT INTO #TMP_POD     
      (  MBOLKey      
      ,  Orderkey    
      ,  Loadkey    
      ,  Consigneekey    
      ,  PickSlipNo    
      ,  CRD    
      )    
   SELECT     
         OH.MBOLKey      
      ,  OH.Orderkey    
      ,  OH.Loadkey    
      ,  OH.Consigneekey    
      ,  PH.PickSlipNo    
      ,  ISNULL(RTRIM(OH.Deliverynote),'')            --CS02    
   FROM ORDERS     OH      WITH (NOLOCK)    
   JOIN PACKHEADER PH      WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey)    
   LEFT JOIN ORDERINFO OIF WITH (NOLOCK) ON (OH.Orderkey = OIF.Orderkey)    
   WHERE OH.MBOLKey = @c_MBOLKey    
       /*CS03 Start*/
    AND PH.Orderkey <> ''
    UNION ALL
    SELECT 
    OH.MBOLKey 
    , OH.Orderkey
    , OH.Loadkey
    , OH.Consigneekey
    , PH.PickSlipNo
    ,  ISNULL(RTRIM(OH.Deliverynote),'')            --CS02
    FROM ORDERS OH WITH (NOLOCK)
    JOIN LOADPLANDETAIL LD WITH (NOLOCK) ON OH.Orderkey = LD.Orderkey
    JOIN PACKHEADER PH WITH (NOLOCK) ON (LD.Loadkey = PH.Loadkey)
    LEFT JOIN ORDERINFO OIF WITH (NOLOCK) ON (OH.Orderkey = OIF.Orderkey)
    WHERE OH.MBOLKey = @c_Mbolkey 
    AND PH.Orderkey = ''
    AND PH.Loadkey <> ''
       /*CS03 End*/   
    
   INSERT INTO #TMP_PODRPT    
      (  MBOLKey      
      ,  Facility          
      ,  MBOLShipDate       
      ,  EstArrivalDate      
      ,  Address1             
      ,  Address2           
      ,  Address3            
      ,  Address4           
      ,  Contact1           
      ,  Phone1             
      ,  Fax1          
      ,  Loadkey            
      ,  PickSlipNo         
      ,  Storerkey          
      ,  Consigneekey       
      ,  C_Company       
      ,  C_Address1         
      ,  C_Address2         
      ,  C_Address3         
      ,  C_Address4         
      ,  C_City             
      ,  C_Contact1         
      ,  C_Phone1           
      ,  FWQty                 
      ,  APPQty                
      ,  EQQty                
      ,  NoOfCarton          
      ,  CRD     
      ,  POD_Barcode       
      ,FWCtn, APPCtn, EQCtn, DELNotes                  --CS01  --CS02    
      )    
   SELECT TMP.MBOLKey    
         ,MH.Facility    
         ,MH.EditDate    
         ,MH.EditDate    
         ,Address1    = ISNULL(RTRIM(FC.Address1),'')    
         ,Address2    = ISNULL(RTRIM(FC.Address2),'')    
         ,Address3    = ISNULL(RTRIM(FC.Address3),'')    
         ,Address4    = ISNULL(RTRIM(FC.Address4),'')    
         ,Contact1    = ISNULL(RTRIM(FC.Contact1),'')    
         ,Phone1      = ISNULL(RTRIM(FC.Phone1),'')    
         ,Fax1        = ISNULL(RTRIM(FC.Fax1),'')    
         ,Loadkey     = ISNULL(STUFF( (SELECT DISTINCT '/' + TPOD.Loadkey    
                                       FROM #TMP_POD TPOD WITH (NOLOCK)    
                                       WHERE TPOD.MBOLkey = TMP.MBOLKey    
                                       AND   TPOD.Consigneekey = TMP.Consigneekey    
                                       AND   TPOD.CRD = TMP.CRD    
                                       FOR XML PATH ('')    
                                       ),1,1,'' ),'')    
         ,PickSlipno  = ISNULL(STUFF( (SELECT DISTINCT '/ ' + TPOD.PickSlipNo --WL01    
                                       FROM #TMP_POD TPOD WITH (NOLOCK)    
                                       WHERE TPOD.MBOLkey = TMP.MBOLKey    
                                       AND   TPOD.Consigneekey = TMP.Consigneekey    
                                       AND   TPOD.CRD = TMP.CRD    
                    FOR XML PATH ('')    
                                    ),1,2,'' ),'')    
         ,OH.Storerkey    
         ,TMP.Consigneekey    
         ,C_Company   = ISNULL(MAX(RTRIM(OH.C_Company)),'')    
         ,C_Address1  = ISNULL(MAX(RTRIM(OH.C_Address1)),'')    
         ,C_Address2  = ISNULL(MAX(RTRIM(OH.C_Address2)),'')    
         ,C_Address3  = ISNULL(MAX(RTRIM(OH.C_Address3)),'')    
         ,C_Address4  = ISNULL(MAX(RTRIM(OH.C_Address4)),'')    
         ,C_City      = ISNULL(MAX(RTRIM(OH.C_City)),'')    
         ,C_Contact1  = ISNULL(MAX(RTRIM(OH.C_Contact1)),'')    
         ,C_Phone1    = ISNULL(MAX(RTRIM(OH.C_Phone1)),'')    
         ,FWQty       = SUM(CASE WHEN ISNULL(RTRIM(SKU.BUSR7),'') = '20' THEN PD.Qty ELSE 0 END)    
         ,APPQty      = SUM(CASE WHEN ISNULL(RTRIM(SKU.BUSR7),'') = '10' THEN PD.Qty ELSE 0 END)    
         ,EQQty       = SUM(CASE WHEN ISNULL(RTRIM(SKU.BUSR7),'') = '30' THEN PD.Qty ELSE 0 END)    
         ,NoOfCarton  = COUNT(DISTINCT PD.CaseID)     
         --,CRD         = (SELECT ISNULL(MAX(RTRIM(ORDERINFO.OrderInfo07)),'')    
         --                FROM ORDERS     WITH (NOLOCK)    
         --                JOIN ORDERINFO  WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERINFO.Orderkey)    
         --                WHERE ORDERS.MBOLkey = MH.MBOLKey    
         --                AND   ORDERS.Consigneekey = OH.Consigneekey    
         --                )    
         ,CRD         = TMP.CRD    
         ,POD_Barcode = CASE WHEN ISNULL(CL.SHORT,'') = 'Y' THEN RTRIM(TMP.MBOLKey) ELSE 'POD-' + RTRIM(TMP.MBOLKey)  END       --mingle01 - START
         ,'0'--FWCtn       = CASE WHEN ISNULL(RTRIM(SKU.BUSR7),'') = '20' THEN COUNT(DISTINCT PD.CaseID) ELSE 0 END    
         ,'0'--APPCtn      = CASE WHEN ISNULL(RTRIM(SKU.BUSR7),'') = '10' THEN COUNT(DISTINCT PD.CaseID) ELSE 0 END    
         ,'0'--EQCtn       = CASE WHEN ISNULL(RTRIM(SKU.BUSR7),'') = '30' THEN COUNT(DISTINCT PD.CaseID) ELSE 0 END    
   ,DELNotes = CAST(ISNULL(MAX(OH.Deliverynote),'') as NVARCHAR(30))                      --CS02    
   FROM MBOL       MH  WITH (NOLOCK)    
   JOIN MBOLDETAIL MD  WITH (NOLOCK) ON (MH.MBOLKey  = MD.MBOLKey)    
   JOIN ORDERS     OH  WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)    
   JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)    
   JOIN SKU        SKU WITH (NOLOCK) ON (SKU.Storerkey = PD.Storerkey)    
                                     AND(SKU.Sku = PD.Sku)    
   JOIN FACILITY   FC  WITH (NOLOCK) ON (MH.Facility = FC.Facility)    
   JOIN #TMP_POD   TMP WITH (NOLOCK) ON (OH.Orderkey = TMP.Orderkey)    
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname =  'REPORTCFG' AND CL.Storerkey = OH.Storerkey       
                                  AND CL.Code = 'RemovePODfrPODBarcode' AND CL.Long = 'r_dw_pod_07'     --mingle01 
   WHERE MH.MBOLKey = @c_MBOLKey    
   GROUP BY TMP.MBOLKey    
         ,  MH.Facility    
         ,  MH.EditDate    
         ,  ISNULL(RTRIM(FC.Address1),'')    
         ,  ISNULL(RTRIM(FC.Address2),'')    
         ,  ISNULL(RTRIM(FC.Address3),'')    
         ,  ISNULL(RTRIM(FC.Address4),'')    
         ,  ISNULL(RTRIM(FC.Contact1),'')    
         ,  ISNULL(RTRIM(FC.Phone1),'')    
         ,  ISNULL(RTRIM(FC.Fax1),'')    
         ,  OH.Storerkey    
         ,  TMP.Consigneekey    
         ,  TMP.CRD    
         --,ISNULL(RTRIM(SKU.BUSR7),'')             --CS01   
         ,  ISNULL(CL.SHORT,'')                     --mingle01 - END 
   ORDER BY TMP.Consigneekey    
         ,  TMP.CRD    
    
   UPDATE TMP    
      SET EstArrivalDate =  CASE WHEN ISNUMERIC(CL.Short) = 1     
                                 THEN DATEADD(dd, CONVERT(INT, CL.Short), MBOLShipDate)    
                                 ELSE MBOLShipDate    
                                 END    
   FROM #TMP_PODRPT TMP      
   JOIN  CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'CityLdTime')    
                                   AND(CL.Storerkey= TMP.Storerkey)    
                                   AND(CL.Long = TMP.Facility)    
                                   AND(CL.Description = TMP.C_City)    
    
/*CS02 start*/    
    
    DECLARE C_loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT mbolkey, PickSlipno     
         FROM #TMP_PODRPT    
   where mbolkey = @c_MBOLKey    
    
         OPEN C_loop    
         FETCH NEXT FROM C_loop INTO @c_getmbolkey, @c_getpickslipno    
            WHILE (@@FETCH_STATUS=0)     
        BEGIN      
    
        UPDATE #TMP_PODRPT SET FWCtn    = ISNULL((SELECT COUNT(DISTINCT PD.CaseID)                                                        --CS02a    
            FROM MBOL       MH  WITH (NOLOCK)    
            JOIN MBOLDETAIL MD  WITH (NOLOCK) ON (MH.MBOLKey  = MD.MBOLKey)    
            JOIN ORDERS     OH  WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)    
            JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)    
            JOIN SKU        SKU WITH (NOLOCK) ON (SKU.Storerkey = PD.Storerkey)    
                   AND(SKU.Sku = PD.Sku)    
            JOIN FACILITY   FC  WITH (NOLOCK) ON (MH.Facility = FC.Facility)    
            --JOIN #TMP_POD   TMP WITH (NOLOCK) ON (OH.Orderkey = TMP.Orderkey)    
            WHERE MH.MBOLKey = @c_MBOLKey AND ISNULL(RTRIM(SKU.BUSR7),'') = '20'    
          and PD.pickslipno in ( select RTRIM(LTRIM(Colvalue)) FROM dbo.fnc_DelimSplit('/',@c_getpickslipno) )           --CS02    
            ),0),    
              
    
       APPCtn = ISNULL((SELECT COUNT(DISTINCT PD.CaseID)                                                                     --CS02a    
            FROM MBOL       MH  WITH (NOLOCK)    
            JOIN MBOLDETAIL MD  WITH (NOLOCK) ON (MH.MBOLKey  = MD.MBOLKey)    
            JOIN ORDERS     OH  WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)    
            JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)    
            JOIN SKU        SKU WITH (NOLOCK) ON (SKU.Storerkey = PD.Storerkey)    
                   AND(SKU.Sku = PD.Sku)    
            JOIN FACILITY   FC  WITH (NOLOCK) ON (MH.Facility = FC.Facility)    
            --JOIN #TMP_POD   TMP WITH (NOLOCK) ON (OH.Orderkey = TMP.Orderkey)    
            WHERE MH.MBOLKey = @c_MBOLKey AND ISNULL(RTRIM(SKU.BUSR7),'') = '10'    
          and PD.pickslipno in ( select RTRIM(LTRIM(Colvalue)) FROM dbo.fnc_DelimSplit('/',@c_getpickslipno) )           --CS02    
            GROUP BY ISNULL(RTRIM(SKU.BUSR7),'')),0),    
              
    
       EQCtn = ISNULL((SELECT COUNT(DISTINCT PD.CaseID)                                                                       --CS02a    
            FROM MBOL       MH  WITH (NOLOCK)    
            JOIN MBOLDETAIL MD  WITH (NOLOCK) ON (MH.MBOLKey  = MD.MBOLKey)    
            JOIN ORDERS     OH  WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)    
            JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)    
            JOIN SKU        SKU WITH (NOLOCK) ON (SKU.Storerkey = PD.Storerkey)    
                   AND(SKU.Sku = PD.Sku)    
            JOIN FACILITY   FC  WITH (NOLOCK) ON (MH.Facility = FC.Facility)    
            --JOIN #TMP_POD   TMP WITH (NOLOCK) ON (OH.Orderkey = TMP.Orderkey)    
            WHERE MH.MBOLKey = @c_MBOLKey AND ISNULL(RTRIM(SKU.BUSR7),'') = '30'    
          and PD.pickslipno in ( select RTRIM(LTRIM(Colvalue)) FROM dbo.fnc_DelimSplit('/',@c_getpickslipno) )           --CS02    
            GROUP BY ISNULL(RTRIM(SKU.BUSR7),'')),0)    
 where mbolkey = @c_getmbolkey     
 and Pickslipno =@c_getpickslipno    
      
   FETCH NEXT FROM C_loop INTO @c_getmbolkey, @c_getpickslipno    
 END     
    
   CLOSE C_loop    
   DEALLOCATE C_loop     
    
    
   SELECT MBOLKey    
      ,  Facility      
      ,  MBOLShipDate     
      ,  EstArrivalDate              
      ,  Address1             
      ,  Address2           
      ,  Address3            
      ,  Address4           
      ,  Contact1           
      ,  Phone1             
      ,  Fax1          
      ,  Loadkey            
      ,  PickSlipNo         
      ,  Storerkey          
      ,  Consigneekey     
      ,  C_Company      
      ,  C_Address1         
      ,  C_Address2         
      ,  C_Address3         
      ,  C_Address4         
      ,  C_City             
      ,  C_Contact1         
      ,  C_Phone1           
      ,  FWQty                 
      ,  APPQty                
      ,  EQQty                 
      ,  NoOfCarton          
,  CRD     
      ,  POD_Barcode    
      ,FWCtn, APPCtn, EQCtn,Delnotes                   --CS01   --CS02    
   FROM #TMP_PODRPT    
    
   WHILE @@TRANCOUNT < @n_StartTCnt    
   BEGIN    
      BEGIN TRAN    
   END    
END -- procedure 

GO
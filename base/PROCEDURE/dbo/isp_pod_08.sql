SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_POD_08                                              */
/* Creation Date: 19-JUNE-2017                                          */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-2152 - CN_DYSON_Report_POD                              */
/*        :                                                             */
/* Called By: r_dw_pod_08 (reporttype = 'MBOLPOD')                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 09-Aug-2017  CSCHONG   1.0 WMS-2642-Add new field (CS01)             */
/* 13-NOV-2021  MINGLE    1.0 WMS-18329-Add new field (ML01)            */
/************************************************************************/
CREATE PROC [dbo].[isp_POD_08]
           @c_MBOLKey   NVARCHAR(10),
           @c_exparrivaldate  NVARCHAR(30) = ''

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END


   CREATE TABLE #TMP_PODRPT08
      (  RowID       INT IDENTITY (1,1) NOT NULL 
      ,	MBOLKey        NVARCHAR(10)   NULL  DEFAULT('')
      ,  ExtOrdKey      NVARCHAR(30)   NULL  DEFAULT('')
      ,  Orderkey       NVARCHAR(10)   NULL  DEFAULT('')
      ,  MBOLShipDate   DATETIME       NULL
      ,  DeliveryDate   DATETIME       NULL
      ,  consigneekey   NVARCHAR(45)   NULL  DEFAULT('')
      ,  Storerkey      NVARCHAR(15)   NULL  DEFAULT('')
      ,  C_Company      NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address1     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address2     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address3     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address4     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_City         NVARCHAR(45)   NULL  DEFAULT('')
      ,  c_State        NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Contact1     NVARCHAR(30)   NULL  DEFAULT('')
      ,  C_Phone1       NVARCHAR(18)   NULL  DEFAULT('')
      ,  PQty           INT            NULL  DEFAULT(0)
      ,  STDGrossQty    FLOAT          NULL  DEFAULT(0)
      ,  STDCube        FLOAT          NULL  DEFAULT(0)
      ,  SKU            NVARCHAR(20)   NULL  DEFAULT('')
      ,  SDESCR         NVARCHAR(120)  NULL  DEFAULT('')
      ,  OHNotes        NVARCHAR(120)  NULL  DEFAULT('')
      ,  POD_Barcode    NVARCHAR(80)   NULL  DEFAULT('')
      ,  LineNum        NVARCHAR(10)   NULL  DEFAULT ('')
      ,  OHUDF01        NVARCHAR(20)   NULL  DEFAULT ('')                 --CS01
      ,  OHUDF02        NVARCHAR(20)   NULL  DEFAULT ('')                 --CS01
      ,  OHUDF07        DATETIME       NULL                               --ML01
      ,  Shipperkey     NVARCHAR(15)   NULL  DEFAULT ('')                 --ML01
      )

            

   INSERT INTO #TMP_PODRPT08
      (  MBOLKey     
      ,  ExtOrdKey   
      ,  MBOLShipDate   
      ,  DeliveryDate  
      ,  consigneekey         
      ,  Orderkey           
      ,  Storerkey       
      ,  C_Company   
      ,  C_Address1     
      ,  C_Address2     
      ,  C_Address3     
      ,  C_Address4     
      ,  C_City     
      ,  c_State    
      ,  C_Contact1     
      ,  C_Phone1       
      ,  PQty             
      ,  STDGrossQty            
      ,  STDCube            
      ,  SKU      
      ,  SDESCR 
      ,  OHNotes
      ,  POD_Barcode   
      ,  LineNum     
      ,  OHUDF01, OHUDF02                        --CS01  
      ,  OHUDF07                    --ML01
      ,  ShipperKey                 --ML01  
      )
   SELECT MH.MBOLKey
         ,OH.ExternOrderKey
         ,MH.shipDate
         ,OH.DeliveryDate    
         ,OH.consigneekey
         ,OH.Orderkey 
         ,OH.Storerkey
         ,C_Company   = ISNULL(MAX(RTRIM(OH.C_Company)),'')
         ,C_Address1  = ISNULL(MAX(RTRIM(OH.C_Address1)),'')
         ,C_Address2  = ISNULL(MAX(RTRIM(OH.C_Address2)),'')
         ,C_Address3  = ISNULL(MAX(RTRIM(OH.C_Address3)),'')
         ,C_Address4  = ISNULL(MAX(RTRIM(OH.C_Address4)),'')
         ,C_City      = ISNULL(MAX(RTRIM(OH.C_City)),'')
         ,C_State     = ISNULL(MAX(RTRIM(OH.C_State)),'')
         ,C_Contact1  = ISNULL(MAX(RTRIM(OH.C_Contact1)),'')
         ,C_Phone1    = ISNULL(MAX(RTRIM(OH.C_Phone1)),'')
         ,PQty        = SUM(PD.Qty)
         ,STDGrossQty = ROUND(SUM(sku.STDGROSSWGT*PD.qty),2)
         ,STDCube     = ROUND(SUM(sku.STDCUBE*PD.qty),3)
         ,PD.sku
         ,SKU.DESCR
         ,OH.Notes
         ,POD_Barcode = 'POD-CN' + RTRIM(C.short) + OH.orderkey
         ,LineNum=RIGHT('00000'+ CAST(Row_number() OVER (PARTITION BY oh.orderkey ORDER BY oh.orderkey, pd.sku) AS NVARCHAR(5)),5)
         ,OH.UserDefine01,OH.UserDefine02                                    --CS01
         ,OH.UserDefine07               --ML01
         ,OH.ShipperKey                 --ML01                                                         
   FROM MBOL       MH  WITH (NOLOCK)
   JOIN MBOLDETAIL MD  WITH (NOLOCK) ON (MH.MBOLKey  = MD.MBOLKey)
   JOIN ORDERS     OH  WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)
   JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
   JOIN SKU        SKU WITH (NOLOCK) ON (SKU.Storerkey = PD.Storerkey)
                                     AND(SKU.Sku = PD.Sku)
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname='strdomain' AND C.code = OH.storerkey                                   
   WHERE MH.MBOLKey = @c_MBOLKey
   GROUP BY MH.MBOLKey
         ,  OH.ExternOrderKey
         ,  MH.shipDate
         ,  OH.DeliveryDate
         ,  OH.Orderkey     
         ,  OH.consigneekey
         ,  OH.Storerkey
         ,  PD.sku
         ,  SKU.DESCR
         ,  OH.Notes
         ,  c.Short
         ,OH.UserDefine01,OH.UserDefine02                         --CS01
         ,OH.UserDefine07                --ML01
         ,OH.ShipperKey                  --ML01
   ORDER BY MH.MBOLKey
         ,  OH.Orderkey


  
   SELECT MBOLKey  
      ,  ExtOrdKey    
      ,  Orderkey   
      ,  MBOLShipDate   
      ,  DeliveryDate  
      ,  consigneekey                     
      ,  Storerkey        
      ,  C_Company   
      ,  C_Address1     
      ,  C_Address2     
      ,  C_Address3     
      ,  C_Address4     
      ,  C_City     
      ,  c_State    
      ,  C_Contact1     
      ,  C_Phone1       
      ,  PQty             
      ,  STDGrossQty            
      ,  STDCube            
      ,  SKU      
      ,  SDESCR 
      ,  OHNotes
      ,  POD_Barcode 
      ,  LineNum
		,  OHUDF01,OHUDF02                        --CS01
      ,  OHUDF07                --ML01
      ,  Shipperkey             --ML01
   FROM #TMP_PODRPT08

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO
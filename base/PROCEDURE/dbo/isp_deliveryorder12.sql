SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure: isp_DeliveryOrder12           */    
/* Creation Date: 30-MAR-2021               */    
/* Copyright: LFL                   */    
/* Written by: ChongCS                 */    
/*                        */    
/* Purpose:WMS-16625/16626-[SG/MY]-Specialized Bicycle- Delivery Note(DN)*/    
/*                        */    
/* Usage:  Used for report dw = r_dw_delivery_Order_12      */    
/*                        */    
/* Called By: RCM from MBOL, ReportType = 'DELORDER'       */    
/*                        */    
/* PVCS Version: 1.0                  */    
/*                        */    
/* Version: 7.0                   */    
/*                        */    
/* Data Modifications:                 */    
/*                        */    
/* Updates:                     */    
/* Date    Author Ver. Purposes            */    
/* 25-JUN-2021  CSCHONG 1.1 WMS-17296 revised field logic (CS01)  */    
/* 16-JUL-2021  CSCHONG 1.2 WMS-17296 fix qty issue       */    
/* 14-AUG-2021  MINGLE  1.3 WMS-17627 add externpokey (ML01)      */    
/* 29-JUN-2022  MINGLE  1.4 WMS-19783 added codelkup (ML02)      */
/************************************************************************/    
CREATE PROC [dbo].[isp_DeliveryOrder12]    
  (@c_MBOLKey NVARCHAR(10))    
AS    
BEGIN    
 SET NOCOUNT ON    
 SET QUOTED_IDENTIFIER OFF    
 SET ANSI_NULLS OFF    
 SET CONCAT_NULL_YIELDS_NULL OFF    
    
 DECLARE @n_Continue INT = 1, @n_MaxLine INT = 20,@n_ttlctn INT    
    ,@c_userid   nvarchar(125)    
    
  SET @c_userid =suser_name()    
    
  SET @n_ttlctn = 1    
    
    
    
 CREATE TABLE #Temp_DOrder12(    
  DCompany    NVARCHAR(45),      
  DAddress1   NVARCHAR(45),    
  DAddress2   NVARCHAR(45),    
  DAddress3   NVARCHAR(45),     
  DZip     NVARCHAR(45),    
  MBRemarks   NVARCHAR(500),      
  OHROUTE    NVARCHAR(10),      
  DeliveryDate  DATETIME ,    
  Orderkey    NVARCHAR(20),    
  DState    NVARCHAR(45),      
  Consigneekey  NVARCHAR(45),    
  SDESCR    NVARCHAR(250),    
  Qty     INT,    
  SKU     NVARCHAR(20),    
  FAddress1   NVARCHAR(45),    
  FAddress2   NVARCHAR(45),    
  FAddress3   NVARCHAR(45),     
  FZip     NVARCHAR(45),    
  PQTY     INT,    
  FState    NVARCHAR(45),    
  FCompany    NVARCHAR(45),       
  ExtOrdKey   NVARCHAR(50),    
  TTLCTN    INT,    
  UOM     NVARCHAR(10),       
  mbolkey    NVARCHAR(20),    
  FCountry    NVARCHAR(45),    
  DCountry    NVARCHAR(45)     
  , orderlinenumber  NVARCHAR(20) -- MC 14062021    
  , externpokey      NVARCHAR(20) --ML01   
  , ShowExtCode      NVARCHAR(10) --ML02  
      
  )    
    
    
   /*SELECT @n_ttlctn = Count(Distinct PD.CartonNo)    
   From Orders O with (nolock)     
   Join PackHeader PH with (nolock) ON PH.StorerKey = O.StorerKey     
   and PH.OrderKey = O.OrderKey    
   Join PackDetail PD with (nolock) ON PD.StorerKey = PH.StorerKey and PD.PickSlipNo = PH.PickSlipNo    
   Where O.MBOLKey=@c_MBOLKey*/ -- MC 14062021    
    
    
 IF(@n_Continue = 1 OR @n_Continue = 2)    
 BEGIN    
  INSERT INTO #Temp_DOrder12 (DCompany,DAddress1,DAddress2,DAddress3,DZip,MBRemarks,OHROUTE,DeliveryDate,Orderkey,DState,Consigneekey,    
            SDESCR,Qty,SKU,FAddress1,FAddress2,FAddress3,FZip, PQTY,--MC 14062021    
          FState,FCompany,     
            ExtOrdKey,TTLCTN,UOM,mbolkey,FCountry,DCountry    
          ,orderlinenumber,externpokey,ShowExtCode )  --MC 14062021  --ML01 --ML02   
  SELECT  DISTINCT ISNULL(OH.c_company,''),ISNULL(OH.c_Address1,''),ISNULL(OH.c_Address2,''),ISNULL(Oh.c_Address3,''),    
   ISNULL(OH.c_zip,''),MB.Remarks,ISNULL(OH.Route,''),OH.Deliverydate,OH.Orderkey,ISNULL(OH.c_State,''),ISNULL(OH.Consigneekey,''),    
   S.descr,  (OD.QtyPicked + OD.ShippedQty)  --MC 14062021    
  ,OD.SKU,ISNULL(ST.Address1,''),ISNULL(ST.Address2,''),ISNULL(ST.Address3,''),    
   ISNULL(ST.zip,''), sum(PD.Qty), --MC 14062021    
  ISNULL(ST.state,''),ISNULL(ST.company,''),    
   OH.ExternOrderkey,--@n_ttlctn,    
   (Select Count(Distinct PD2.CartonNo)    
From     
Orders O with (nolock) Inner Join PackHeader PH2 with (nolock) ON PH2.StorerKey = O.StorerKey and PH2.OrderKey = O.OrderKey    
Inner Join PackDetail PD2 with (nolock) ON PD2.StorerKey = PH2.StorerKey and PD2.PickSlipNo = PH2.PickSlipNo   
Where PH2.StorerKey = (OD.StorerKey)    
And O.OrderKey = (OD.OrderKey))  as TTLCTN, --MC 14062021    
P.PackUOM3,MB.Mbolkey,ISNULL(ST.Country,''),ISNULL(OH.c_Country,'')    
, od.orderlinenumber --MC 14062021    
, od.ExternPOKey --ML01   
, ISNULL(C1.SHORT,'') AS ShowExtCode --ML02  
  FROM MBOL MB (NOLOCK)    
  JOIN MBOLDETAIL MD (NOLOCK) ON MB.MBOLKEY = MD.MBOLKEY    
  JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = MD.ORDERKEY    
  JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey    
  LEFT JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey    
  LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = OH.StorerKey    
  --LEFT JOIN STORER SHPT WITH (NOLOCK) ON SHPT.ConsigneeFor = OH.StorerKey AND SHPT.Type='2' AND SHPT.StorerKey=OH.ConsigneeKey    
  JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey=OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.sku = OD.Sku    
               AND PD.Storerkey = OD.StorerKey    
  JOIN SKU S WITH (NOLOCK) ON S.Storerkey = OD.Storerkey AND S.SKU = OD.SKU    
  JOIN PACK P WITH (NOLOCK) ON P.PackKey=S.PACKKey    
  LEFT JOIN CODELKUP C1(NOLOCK) ON C1.LISTNAME = 'REPORTCFG' AND C1.CODE = 'ShowExternBarcode' AND C1.Storerkey = OH.StorerKey AND C1.LONG = 'r_dw_delivery_Order_12' --ML02  
  WHERE MB.MBOLKEY = @c_MBOLKey    
   group by oh.orderkey, od.OrderLineNumber, OH.c_company,OH.c_Address1,OH.c_Address2,Oh.c_Address3,    
  OH.c_zip,MB.Remarks,OH.Route,OH.Deliverydate,OH.Orderkey,OH.c_State,OH.Consigneekey,    
   S.descr,OD.SKU,ST.Address1,ST.Address2,ST.Address3,    
   ST.zip,    
  ST.state,ST.company,    
   OH.ExternOrderkey,P.PackUOM3,MB.Mbolkey,ST.Country,OH.c_Country,od.ExternPOKey --ML01    
  ,od.orderkey, od.storerkey, od.shippedqty, OD.QtyPicked--, pd.qty  
  ,ISNULL(C1.SHORT,'') --ML02  
  ORDER BY  MB.Mbolkey,OH.Orderkey,od.orderlinenumber, OD.SKU    
   -- ORDER BY MB.Mbolkey,OH.Orderkey,OD.SKU -- --MC 14062021    
  END    
    
  SELECT *    
  FROM #Temp_DOrder12    
  ORDER BY Mbolkey,Orderkey,sku    
    
    
  IF OBJECT_ID('tempdb..#Temp_DOrder12') IS NOT NULL    
   DROP TABLE #Temp_DOrder12    
    
END   

GO
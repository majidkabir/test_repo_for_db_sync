SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger: isp_delivery_note15                                         */  
/* Creation Date: 17-NOV-2015                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose:                                                             */  
/*        :                                                             */  
/* Called By: r_dw_delivery_note15                                      */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 14-Jun-2016  CSCHONG   1.1 SOS#370326 Change ETA logic (CS01)        */  
/* 16-Apr-2018  CSCHONG   1.2 WMS-4526 - revised field logic (CS02)     */  
/* 12-JUL-2018  CSCHONG   1.3 WMS-5589-revised field mapping (CS03)     */  
/* 22-Mar-2019  WLCHOOI   1.4 WMS-8362 - Add ETA Calculate for Facility */
/*                                       SUB02 (WL01)                   */
/************************************************************************/  
CREATE PROC [dbo].[isp_delivery_note15]   
            @c_MBOlKey     NVARCHAR(10)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF     
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT  
   
         , @c_Orderkey        NVARCHAR(10)  
         , @c_Consigneekey    NVARCHAR(15)  
         , @c_TransMehtod     NVARCHAR(30)  
         , @d_ShipDate4ETA    DATETIME  
         , @d_ETA             DATETIME  
         , @c_Rptsku          NVARCHAR(5)  --(CS02)  
  
         , @n_Leadtime        INT  
         , @n_Leadtime1       INT  
         , @n_Leadtime2       INT  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
     
   SET @c_Rptsku = ''                      --(CS02)  
  
  
   CREATE TABLE #DO  
      (  Facility          NVARCHAR(5)      
      ,  BookingReference  NVARCHAR(30)     
      ,  Vessel            NVARCHAR(30)  
      ,  TransMethod       NVARCHAR(30)  
      ,  ShipDate          DATETIME    NULL  
      ,  ETA               DATETIME    NULL  
      ,  Loadkey           NVARCHAR(10)  
      ,  Orderkey          NVARCHAR(10)  
      ,  ExternOrderkey    NVARCHAR(30)
      ,  ExternPOkey       NVARCHAR(20)  
      ,  OrderDate         DATETIME    NULL  
      ,  DeliveryDate      DATETIME    NULL  
      ,  Consigneekey      NVARCHAR(15)  
      ,  C_Company         NVARCHAR(45)  
      ,  C_Address1        NVARCHAR(45)  
      ,  C_Address2        NVARCHAR(45)  
      ,  C_Address3        NVARCHAR(45)  
      ,  C_City            NVARCHAR(45)  
      ,  C_Zip             NVARCHAR(18)  
      ,  C_Phone1          NVARCHAR(18)  
      ,  BillToKey         NVARCHAR(15)  
      ,  B_Company         NVARCHAR(45)  
      ,  B_Address1        NVARCHAR(45)  
      ,  B_Address2        NVARCHAR(45)  
      ,  B_Address3        NVARCHAR(45)  
      ,  B_City            NVARCHAR(45)  
      ,  B_Zip             NVARCHAR(18)  
      ,  B_Phone1          NVARCHAR(18)  
      ,  Notes2            NVARCHAR(4000)  
      ,  Storerkey         NVARCHAR(15)  
      ,  Sku               NVARCHAR(20)  
      ,  SKUDescr          NVARCHAR(60)  
      ,  QtyInPCS          INT  
      ,  QtyInCS           INT  
      ,  Lottable02        NVARCHAR(18)  
      ,  Lottable04        DATETIME    NULL  
      )  
  
  INSERT INTO #DO  
   (  Facility            
      ,  BookingReference    
      ,  Vessel     
      ,  TransMethod           
      ,  ShipDate   
      ,  ETA   
      ,  Loadkey             
      ,  Orderkey            
      ,  ExternOrderkey      
      ,  ExternPOkey         
      ,  OrderDate           
      ,  DeliveryDate        
      ,  Consigneekey        
      ,  C_Company           
      ,  C_Address1          
      ,  C_Address2    
      ,  C_Address3        
      ,  C_City              
      ,  C_Zip               
      ,  C_Phone1            
      ,  BillToKey           
      ,  B_Company           
      ,  B_Address1          
      ,  B_Address2     
      ,  B_Address3       
      ,  B_City              
      ,  B_Zip               
      ,  B_Phone1            
      ,  Notes2              
      ,  Storerkey           
      ,  Sku                 
      ,  SKUDescr            
      ,  QtyInPCS            
      ,  QtyInCS             
      ,  Lottable02          
      ,  Lottable04          
      )  
   SELECT MBOL.Facility  
  , bookingreference = ISNULL(RTRIM(MBOL.bookingreference),'')  
  , vessel = ISNULL(RTRIM(MBOL.vessel),'')  
      , TransMethod = ISNULL(RTRIM(MBOL.TransMethod),'')  
      , ShipDate = MBOL.ShipDate    
      , ETA = CASE WHEN ISNULL(orders.podarrive,'') = '' THEN MBOL.ShipDate ELSE ORDERS.DeliveryDate END  
  , Loadkey= ISNULL(RTRIM(MBOLDETAIL.Loadkey),'')  
  , ORDERS.Orderkey  
  , ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
  , ExternPOkey = CASE WHEN ISNULL(ORDERS.Salesman,'') = '' THEN ISNULL(RTRIM(ORDERS.ExternPOkey),'')           --(CS03)  
                  ELSE ORDERS.Salesman END                                                                      --(CS03)  
  , ORDERS.OrderDate  
  , ORDERS.DeliveryDate  
  , Consigneekey = ISNULL(RTRIM(ORDERS.Consigneekey),'')  
  , C_Company = ISNULL(RTRIM(ORDERS.C_Company),'')  
  , C_Address1 = ISNULL(RTRIM(ORDERS.C_Address1),'')  
  , C_Address2 = ISNULL(RTRIM(ORDERS.C_Address2),'')  
  , C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3),'')  
  , C_City= ISNULL(RTRIM(ORDERS.C_City),'')  
  , C_Zip = ISNULL(RTRIM(ORDERS.C_Zip),'')  
  , C_Phone1= ISNULL(RTRIM(ORDERS.C_Phone1),'')  
  , BillToKey = ISNULL(RTRIM(ORDERS.BillToKey),'')  
  , B_Company = ISNULL(RTRIM(ORDERS.B_Company),'')  
  , B_Address1 = ISNULL(RTRIM(ORDERS.B_Address1),'')  
  , B_Address2 = ISNULL(RTRIM(ORDERS.B_Address2),'')  
  , B_Address3 = ISNULL(RTRIM(ORDERS.B_Address3),'')  
  , B_City= ISNULL(RTRIM(ORDERS.B_City),'')  
  , B_Zip = ISNULL(RTRIM(ORDERS.B_Zip),'')  
  , B_Phone1= ISNULL(RTRIM(ORDERS.B_Phone1),'')  
  , Notes2 = ISNULL(RTRIM(ORDERS.Notes2),'')  
  , PICKDETAIL.Storerkey  
  /*CS02 Start*/  
  , CASE WHEN ISNULL(C.code,'') <> '' THEN SUBSTRING (PICKDETAIL.Sku, 1, 5 )  
      + '-' +   
      SUBSTRING ( PICKDETAIL.Sku, 6, 5 )  
      + '-' +  
      SUBSTRING ( PICKDETAIL.Sku, 11, 2 )  
   ELSE PICKDETAIL.Sku END AS sku  
  /*CS02 END*/  
  , SKUDescr = ISNULL(RTRIM(SKU.Descr),'')  
  , QtyInPCS = SUM(PICKDETAIL.Qty)  
  , QtyInCS  = CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN SUM(PICKDETAIL.Qty) / ISNULL(PACK.CaseCnt,0) ELSE 0 END  
  , Lottable02 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')  
  , Lottable04 = ISNULL(LOTATTRIBUTE.Lottable04,'1900-01-01')  
 FROM MBOL       WITH (NOLOCK)   
 JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLkey = MBOLDETAIL.MBOLkey)  
 JOIN ORDERS     WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)  
 JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)  
 JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot= LOTATTRIBUTE.Lot)  
 JOIN SKU        WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)  
          AND(PICKDETAIL.Sku = SKU.Sku)  
 JOIN PACK       WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)  
 /*CS02 start*/  
 LEFT JOIN  CODELKUP C WITH (NOLOCK) ON C.listname = 'RPTSKU' AND C.Storerkey = ORDERS.StorerKey AND C.code = 'BDFSKU'  
 /*CS02 End*/  
 WHERE MBOL.MBOLkey = @c_Mbolkey  
 AND PICKDETAIL.Status >= '5'  
 GROUP BY MBOL.Facility  
  , ISNULL(RTRIM(MBOL.bookingreference),'')  
  , ISNULL(RTRIM(MBOL.vessel),'')  
      , ISNULL(RTRIM(MBOL.TransMethod),'')  
      , MBOL.ShipDate   
      , CASE WHEN ISNULL(orders.podarrive,'') = '' THEN MBOL.ShipDate ELSE ORDERS.DeliveryDate END  
  , ISNULL(RTRIM(MBOLDETAIL.Loadkey),'')  
  , ORDERS.Orderkey  
  , ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
  , CASE WHEN ISNULL(ORDERS.Salesman,'') = '' THEN ISNULL(RTRIM(ORDERS.ExternPOkey),'')           --(CS03)  
                  ELSE ORDERS.Salesman END                                                        --(CS03)  
  , ORDERS.OrderDate  
  , ORDERS.DeliveryDate  
  , ISNULL(RTRIM(ORDERS.Consigneekey),'')  
  , ISNULL(RTRIM(ORDERS.C_Company),'')  
  , ISNULL(RTRIM(ORDERS.C_Address1),'')  
  , ISNULL(RTRIM(ORDERS.C_Address2),'')  
  , ISNULL(RTRIM(ORDERS.C_Address3),'')  
  , ISNULL(RTRIM(ORDERS.C_City),'')  
  , ISNULL(RTRIM(ORDERS.C_Zip),'')  
  , ISNULL(RTRIM(ORDERS.C_Phone1),'')  
  , ISNULL(RTRIM(ORDERS.BillToKey),'')  
  , ISNULL(RTRIM(ORDERS.B_Company),'')  
  , ISNULL(RTRIM(ORDERS.B_Address1),'')  
  , ISNULL(RTRIM(ORDERS.B_Address2),'')  
  , ISNULL(RTRIM(ORDERS.B_Address3),'')  
  , ISNULL(RTRIM(ORDERS.B_City),'')  
  , ISNULL(RTRIM(ORDERS.B_Zip),'')  
  , ISNULL(RTRIM(ORDERS.B_Phone1),'')  
  , ISNULL(RTRIM(ORDERS.Notes2),'')  
  , PICKDETAIL.Storerkey  
  --, PICKDETAIL.Sku  
  , ISNULL(RTRIM(SKU.Descr),'')  
  , ISNULL(PACK.CaseCnt,0)  
  , ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')  
  , ISNULL(LOTATTRIBUTE.Lottable04,'1900-01-01')  
  /*CS02 Start*/  
  , CASE WHEN ISNULL(C.code,'') <> '' THEN SUBSTRING (PICKDETAIL.Sku, 1, 5 )  
      + '-' +   
      SUBSTRING ( PICKDETAIL.Sku, 6, 5 )  
      + '-' +  
      SUBSTRING ( PICKDETAIL.Sku, 11, 2 )  
   ELSE PICKDETAIL.Sku END   
  /*CS02 End*/  
  
   DECLARE CUR_ETA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT   
          Orderkey  
         ,Consigneekey  
         ,TransMethod  
         ,ETA  
   FROM #DO  
  
   OPEN CUR_ETA  
  
   FETCH NEXT FROM CUR_ETA INTO @c_Orderkey  
                              , @c_Consigneekey  
                              , @c_TransMehtod  
                              , @d_ShipDate4ETA  
  
   WHILE @@FETCH_STATUS <> -1    
   BEGIN  
      SET @n_Leadtime = 0  
      SET @n_Leadtime1 = 0  
      SET @n_Leadtime2 = 0  
  
    /*CS01 Start*/  
     /* SELECT @n_Leadtime1 = CASE WHEN ISNUMERIC(Susr1) = 1 THEN Susr1 ELSE 0 END  
            ,@n_Leadtime2 = CASE WHEN ISNUMERIC(Susr2) = 1 THEN Susr2 ELSE 0 END  
      FROM STORER WITH (NOLOCK)  
      WHERE Storerkey = @c_Consigneekey  
     
   
      IF @c_TransMehtod IN ('L', 'S4')  
      BEGIN  
         SET @n_Leadtime = @n_Leadtime1  
      END  
  
      IF @c_TransMehtod = 'S3'  
      BEGIN  
         SET @n_Leadtime = @n_Leadtime2  
      END*/  
         
       SELECT @n_Leadtime = CASE WHEN MB.transmethod IN ('S4','FT','L' ) AND MB.facility='CBT01' THEN LEFT(S.SUSR1,2)  
   WHEN MB.transmethod IN ('LT','S3') AND MB.facility='CBT01' THEN SUBSTRING(S.susr1,4,2)  
   WHEN MB.transmethod='U'  AND MB.facility='CBT01' THEN SUBSTRING(S.susr1,7,2)  
   WHEN MB.transmethod='U1' AND MB.facility='CBT01' THEN RIGHT(S.susr1,2)  
  
   WHEN MB.transmethod IN ('S4','FT','L' ) AND MB.facility IN ('SUB01','SUB02') THEN LEFT(S.SUSR2,2)    --WL01
   WHEN MB.transmethod IN ('LT','S3') AND MB.facility IN ('SUB01','SUB02') THEN SUBSTRING(S.SUSR2,4,2)  --WL01 
   WHEN MB.transmethod='U'  AND MB.facility IN ('SUB01','SUB02') THEN SUBSTRING(S.SUSR2,7,2)            --WL01
   WHEN MB.transmethod='U1' AND MB.facility IN ('SUB01','SUB02') THEN RIGHT(S.susr2,2)                  --WL01
  
   WHEN MB.transmethod IN ('S4','FT','L' ) AND MB.facility='MLG01' THEN LEFT(S.SUSR3,2)  
   WHEN MB.transmethod IN ('LT','S3') AND MB.facility='MLG01' THEN SUBSTRING(S.SUSR3,4,2)  
   WHEN MB.transmethod='U'  AND MB.facility='MLG01' THEN SUBSTRING(S.SUSR3,7,2)  
   WHEN MB.transmethod='U1' AND MB.facility='MLG01' THEN RIGHT(S.susr3,2)  
   ELSE 0 END  
       FROM ORDERS ORD WITH (NOLOCK)  
       JOIN MBOL MB WITH (NOLOCK) ON MB.mbolkey=ORD.mbolKey  
       JOIN Storer S WITH (NOLOCK) ON S.storerkey = ORD.Consigneekey   
       AND ORD.Orderkey = @c_Orderkey  
 /*CS01 END*/  
      SET @d_ETA = CONVERT(NVARCHAR(10),DATEADD(d, @n_Leadtime, @d_ShipDate4ETA),112)  
   
      WHILE 1 = 1  
      BEGIN  
         --IF DATEPART(DW, @d_ETA) <> 1     --  Sunday = 1  
         --BEGIN  
         --   BREAK  
         --END  
   
         IF NOT EXISTS (SELECT 1   
                        FROM HOLIDAYDETAIL WITH (NOLOCK)  
                        WHERE Holidaydate = @d_ETA  
         ) AND DATEPART(DW, @d_ETA) <> 1    --(CS01)  
         BEGIN  
            BREAK  
         END    
   
         SET @d_ETA = DATEADD(d, 1, @d_ETA)                   
      END  
     
      UPDATE #DO   
      SET ETA = @d_ETA  
      WHERE Orderkey = @c_Orderkey  
  
      FETCH NEXT FROM CUR_ETA INTO @c_Orderkey  
                                 , @c_Consigneekey  
                                 , @c_TransMehtod  
                                 , @d_ShipDate4ETA  
   
   END  
   CLOSE CUR_ETA  
   DEALLOCATE CUR_ETA  
  
   SELECT   
         Facility            
      ,  BookingReference    
      ,  Vessel     
      ,  ShipDate           
      ,  ETA    
      ,  Loadkey             
      ,  Orderkey            
      ,  ExternOrderkey      
      ,  ExternPOkey         
      ,  OrderDate           
      ,  DeliveryDate        
      ,  Consigneekey        
      ,  C_Company           
      ,  C_Address1          
      ,  C_Address2   
      ,  C_Address3          
      ,  C_City              
      ,  C_Zip               
      ,  C_Phone1            
      ,  BillToKey           
      ,  B_Company           
      ,  B_Address1          
      ,  B_Address2    
      ,  B_Address3        
      ,  B_City              
      ,  B_Zip               
      ,  B_Phone1            
      ,  Notes2              
      ,  Storerkey           
      ,  Sku                 
      ,  SKUDescr            
      ,  QtyInPCS            
      ,  QtyInCS             
      ,  Lottable02          
      ,  Lottable04  
      FROM #DO     
      ORDER BY Orderkey  
            ,  Storerkey       
            ,  Sku  
  
QUIT:  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_ETA') in (0 , 1)    
   BEGIN  
      CLOSE CUR_ETA  
      DEALLOCATE CUR_ETA  
   END  
  
END -- procedure  


GO
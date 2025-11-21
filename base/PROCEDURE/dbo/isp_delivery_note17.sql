SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_delivery_note17                                         */
/* Creation Date: 15-MAR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By: r_dw_delivery_note17                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_delivery_note17]
            @c_OrderKey     NVARCHAR(10)
AS
BEGIN
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
 
       
         , @c_Consigneekey    NVARCHAR(15)
         , @c_TransMehtod     NVARCHAR(30)
         , @d_ShipDate4ETA    DATETIME
         , @d_ETA             DATETIME

         , @n_Leadtime        INT
         , @n_Leadtime1       INT
         , @n_Leadtime2       INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1


   CREATE TABLE #DELNOTES
      (  Facility          NVARCHAR(5)    
      ,  DischargePlace    NVARCHAR(30)   
      ,  intermodalvehicle NVARCHAR(30)
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
      ,  Notes             NVARCHAR(4000)
      )

  INSERT INTO #DELNOTES
      (  Facility          
      ,  DischargePlace  
      ,  intermodalvehicle      
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
      ,  Notes   
      )
   SELECT ORDERS.Facility
      , DischargePlace = ISNULL(RTRIM(ORDERS.DischargePlace),'')
      , intermodalvehicle = ISNULL(RTRIM(ORDERS.intermodalvehicle),'')
      , ETA = ''
      , Loadkey= ISNULL(RTRIM(ORDERS.Loadkey),'')
      , ORDERS.Orderkey
      , ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
      , ExternPOkey = ISNULL(RTRIM(ORDERS.ExternPOkey),'')
      , OrderDate = ORDERS.OrderDate  
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
      , ORDERS.Storerkey
      , ORDERDETAIL.Sku
      , SKUDescr = ISNULL(RTRIM(SKU.Descr),'')
      , QtyInPCS = SUM(ORDERDETAIL.OriginalQty)
      , QtyInCS  = CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN SUM(ORDERDETAIL.OriginalQty) / ISNULL(PACK.CaseCnt,0) ELSE 0 END
      , Lottable02 = ISNULL(RTRIM(ORDERDETAIL.Lottable02),'')
      , Lottable04 = ISNULL(ORDERDETAIL.Lottable04,'1900-01-01')
      , Notes = ISNULL(RTRIM(ORDERS.Notes),'') 
   FROM ORDERS     WITH (NOLOCK) 
   JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERDETAIL.Orderkey = ORDERS.Orderkey
   JOIN SKU        WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                              AND(ORDERDETAIL.Sku = SKU.Sku)
   JOIN PACK       WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE ORDERS.Orderkey = @c_Orderkey
   GROUP BY ORDERS.Facility
      , ISNULL(RTRIM(ORDERS.DischargePlace),'')
      , ISNULL(RTRIM(ORDERS.intermodalvehicle),'')
      , ORDERS.OrderDate 
      , ISNULL(RTRIM(ORDERS.Loadkey),'')
      , ORDERS.Orderkey
      , ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
      , ISNULL(RTRIM(ORDERS.ExternPOkey),'')
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
      , ORDERS.Storerkey
      , ORDERDETAIL.Sku
      , ISNULL(RTRIM(SKU.Descr),'')
      , ISNULL(PACK.CaseCnt,0)
      , ISNULL(RTRIM(ORDERDETAIL.Lottable02),'')
      , ISNULL(ORDERDETAIL.Lottable04,'1900-01-01')
      , ISNULL(RTRIM(ORDERS.Notes),'')


   DECLARE CUR_ETA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT 
          Orderkey
         ,Consigneekey
         ,DeliveryDate
   FROM #DELNOTES

   OPEN CUR_ETA

   FETCH NEXT FROM CUR_ETA INTO @c_Orderkey
                              , @c_Consigneekey
                              , @d_ShipDate4ETA

   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      SET @n_Leadtime = 0
      SET @n_Leadtime1 = 0
      SET @n_Leadtime2 = 0

 
      SELECT @n_Leadtime = CASE WHEN ISNUMERIC(Susr2) = 1 THEN Susr1 ELSE 0 END
           -- ,@n_Leadtime2 = CASE WHEN ISNUMERIC(Susr2) = 1 THEN Susr2 ELSE 0 END
      FROM STORER WITH (NOLOCK)
      WHERE Storerkey = @c_Consigneekey
   
 
--      IF @c_TransMehtod IN ('L', 'S4')
--      BEGIN
--         SET @n_Leadtime = @n_Leadtime1
--      END
--
--      IF @c_TransMehtod = 'S3'
--      BEGIN
--         SET @n_Leadtime = @n_Leadtime2
--      END

      SET @d_ETA = CONVERT(NVARCHAR(10),DATEADD(d, @n_Leadtime, @d_ShipDate4ETA),112)
 
--      WHILE 1 = 1
--      BEGIN
--         --IF DATEPART(DW, @d_ETA) <> 1     --  Sunday = 1
--         --BEGIN
--         --   BREAK
--         --END
-- 
--         IF NOT EXISTS (SELECT 1 
--                        FROM HOLIDAY WITH (NOLOCK)
--                        WHERE Holiday = @d_ETA
--                       )
--         BEGIN
--            BREAK
--         END  
-- 
--         SET @d_ETA = DATEADD(d, 1, @d_ETA)                 
--      END
--   
      UPDATE #DELNOTES 
      SET ETA = @d_ETA
      WHERE Orderkey = @c_Orderkey

      FETCH NEXT FROM CUR_ETA INTO @c_Orderkey
                                 , @c_Consigneekey
                                 , @d_ShipDate4ETA
 
   END
   CLOSE CUR_ETA
   DEALLOCATE CUR_ETA

   SELECT 
         Facility          
      ,  DischargePlace  
      ,  intermodalvehicle          
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
      ,  Notes
      ,  DeliveryDate
   FROM #DELNOTES   
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
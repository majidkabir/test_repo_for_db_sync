SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_delivery_note29                                         */
/* Creation Date: 10-JUL-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By: r_dw_delivery_note29                                      */
/*            copy from r_dw_delivery_note15                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 18-JUL-2018  CSCHONG   1.0 WMS-5659-fix qty duplicate issue (CS01)   */
/* 20-JUL-2018  CSCHONG   1.1 WMS-5794 - revised field mapping(CS02)    */
/************************************************************************/
CREATE PROC [dbo].[isp_delivery_note29]
            @c_MBOlKey     NVARCHAR(10)
AS
BEGIN
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
 
         , @c_Orderkey        NVARCHAR(10)
         , @c_Consigneekey    NVARCHAR(15)
         , @c_TransMehtod     NVARCHAR(30)
         , @d_ShipDate4ETA    DATETIME
         , @d_ETA             DATETIME
         , @c_Rptsku          NVARCHAR(5)  --(CS02)
			, @n_shipqty         INT

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
      ,  BuyerPO           NVARCHAR(20)
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
		,  OtherReference    NVARCHAR(30)
		,  C_Phone2          NVARCHAR(18)
		,  B_Phone2          NVARCHAR(18)
		,  UOM               NVARCHAR(20)
		,  ExternPOkey       NVARCHAR(30)
      )

  INSERT INTO #DO
      (  Facility          
      ,  BookingReference  
      ,  Vessel   
      ,  TransMethod         
      ,  ShipDate 
     -- ,  ETA 
      ,  Loadkey           
      ,  Orderkey          
      ,  ExternOrderkey    
      ,  BuyerPO       
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
		,  OtherReference 
		,  C_Phone2
		,  B_Phone2      
		,  UOM
		,  ExternPOkey
      )
   SELECT MBOL.Facility
		, bookingreference = ISNULL(RTRIM(MBOL.bookingreference),'')
		, vessel = ISNULL(RTRIM(MBOL.vessel),'')
      , TransMethod = ISNULL(RTRIM(MBOL.TransMethod),'')
      , ShipDate = MBOL.ShipDate  
     -- , ETA = CASE WHEN ISNULL(orders.podarrive,'') = '' THEN MBOL.ShipDate ELSE ORDERS.DeliveryDate END
		, Loadkey= ISNULL(RTRIM(MBOLDETAIL.Loadkey),'')
		, ORDERS.Orderkey
		, ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
		, BuyerPO = ISNULL(RTRIM(ORDERS.BuyerPO),'')
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
		, Notes2 = ISNULL(RTRIM(ORDERS.Notes),'')
		, ORDERDETAIL.Storerkey
		, SKU = ORDERDETAIL.SKU
		, SKUDescr = ISNULL(RTRIM(SKU.Descr),'')
		, QtyInPCS = SUM(PICKDETAIL.Qty)--(ORDERDETAIL.ShippedQty)                       --CS01  --CS02  --CS02a
		, QtyInCS  =  0 
		, Lottable02 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')
		, OtherReference = ISNULL(mbol.OtherReference,'')
		, C_Phone2= ISNULL(RTRIM(ORDERS.C_Phone2),'')
		, B_Phone2= ISNULL(RTRIM(ORDERS.B_Phone2),'')
		, UOM = ORDERDETAIL.UOM
		, ExternPOkey = ISNULL(RTRIM(ORDERS.externpokey),'')
	FROM MBOL       WITH (NOLOCK) 
	JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLkey = MBOLDETAIL.MBOLkey)
	JOIN ORDERS     WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
	JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
   JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey)
	                              AND (ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
											AND (ORDERDETAIL.Sku = PICKDETAIL.Sku)                         --CS02a
	JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot= LOTATTRIBUTE.Lot)
	JOIN SKU        WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
										AND(ORDERDETAIL.Sku = SKU.Sku)
	JOIN PACK       WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
	WHERE MBOL.MBOLkey = @c_Mbolkey
	AND MBOL.Status = '9'
	GROUP BY MBOL.Facility
		, ISNULL(RTRIM(MBOL.bookingreference),'')
		, ISNULL(RTRIM(MBOL.vessel),'')
      , ISNULL(RTRIM(MBOL.TransMethod),'')
      , MBOL.ShipDate 
      --, CASE WHEN ISNULL(orders.podarrive,'') = '' THEN MBOL.ShipDate ELSE ORDERS.DeliveryDate END
		, ISNULL(RTRIM(MBOLDETAIL.Loadkey),'')
		, ORDERS.Orderkey
		, ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
		, ISNULL(RTRIM(ORDERS.BuyerPO),'')
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
		, ISNULL(RTRIM(ORDERS.Notes),'')
		, ORDERDETAIL.Storerkey
		--, PICKDETAIL.Sku
		, ISNULL(RTRIM(SKU.Descr),'')
		, ISNULL(PACK.CaseCnt,0)
		, ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')
		,  ISNULL(mbol.OtherReference,'')
	   , ORDERDETAIL.SKU
		, ISNULL(RTRIM(ORDERS.C_Phone2),'')
		, ISNULL(RTRIM(ORDERS.B_Phone2),'')
		, ORDERDETAIL.UOM
		,ISNULL(RTRIM(ORDERS.externpokey),'')
		--, PICKDETAIL.Qty--(ORDERDETAIL.ShippedQty)                                    --CS01  --CS02  --CS02a
		 
   DECLARE CUR_ETA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT 
          Orderkey
         ,Consigneekey
         ,TransMethod
         ,ShipDate
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
       
       SELECT @n_Leadtime = CASE WHEN MB.transmethod IN ('S4','L' ) THEN S.SUSR1
		 WHEN MB.transmethod IN ('S3') THEN S.susr2
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
      ,  BuyerPO       
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
		,  OtherReference
		,  C_Phone2
		,  B_Phone2
		,  UOM
		, externpokey
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
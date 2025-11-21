SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_dmanifest_vehicle_02                           */  
/* Creation Date: 2020-05-19                                            */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-13410 - MYS-KFMY-Alter Address on MBOL                  */  
/*          Copy from nsp_dmanifest_vehicle_sbuxm                       */  
/*                                                                      */  
/* Called By: PB dw:r_dw_dmanifest_vehicle02                            */
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author    Ver.  Purposes                                 */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_dmanifest_vehicle_02] (  
    @c_mbolkey NVARCHAR(10))  
 AS  
 BEGIN  

   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF        
 
   DECLARE @n_totalorders  INT,  
   @n_totalcust            INT,  
   @n_totalqty             INT,  
   @c_orderkey             NVARCHAR(10),  
   @dc_totalwgt            DECIMAL(7,2),  
   @c_orderkey2            NVARCHAR(10),  
   @c_prevorder            NVARCHAR(10),  
   @c_pickdetailkey        NVARCHAR(18),  
   @c_sku                  NVARCHAR(20),  
   @dc_skuwgt              DECIMAL(7,2),  
   @n_carton               INT,  
   @n_totalcarton          DECIMAL(7,2),  
   @n_each                 INT,      
   @n_totaleach            INT,  
   @dc_m3                  DECIMAL(7,2),
   @c_FacilityAddr         NVARCHAR(255),
   @c_FacilityPhone        NVARCHAR(255),
   @c_FacilityFax          NVARCHAR(255) 
   
   SELECT @c_FacilityAddr  = (LTRIM(RTRIM(ISNULL(F.Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(F.Address2,''))) + ' ' + 
                              LTRIM(RTRIM(ISNULL(F.Address3,''))) + ' ' + LTRIM(RTRIM(ISNULL(F.Address4,''))) + ' ' + LTRIM(RTRIM(ISNULL(F.Country,''))))
        , @c_FacilityPhone = LTRIM(RTRIM(ISNULL(F.Phone1,'')))
        , @c_FacilityFax   = LTRIM(RTRIM(ISNULL(F.Fax1,'')))
   FROM Facility F (NOLOCK)
   JOIN MBOL MB (NOLOCK) ON F.Facility = MB.Facility
   WHERE MB.MbolKey = @c_mbolkey

   SELECT MBOL.mbolkey,  
   vessel = convert(NVARCHAR(30), MBOL.vessel),      
   MBOL.carrierkey,  
   MBOLDETAIL.loadkey,   
   MBOLDETAIL.orderkey,  
   MBOLDETAIL.externorderkey,  
   MBOLDETAIL.description,  
   MBOLDETAIL.deliverydate,  
   totalqty = 0,  
   totalorders = 0,  
   totalcust = 0,  
   MBOL.Departuredate,     
   totalwgt = 99999999.99,    
   totalcarton = 99999999.99,      
   totaleach = 0,     
   TotalCartons = Orders.ContainerQty,  
   MBOL.carrieragent,       
   MBOL.drivername,         
   remarks = convert(NVARCHAR(255), MBOL.remarks),      
   ISNULL(RTRIM(CODELKUP.Long) , MBOL.transmethod) TransMethod,   
   MBOL.placeofdelivery,    
   MBOL.placeofloading,    
   MBOL.placeofdischarge,  
   MBOL.otherreference,  
   ORDERS.invoiceno,  
   ORDERS.route,  
   m3 = 99999999.99,
   STORER.Company,
   STORER.Address1,
   STORER.Address2,
   STORER.Address3,
   STORER.City,
   STORER.phone1,
   STORER.Logo,
   @c_FacilityAddr  AS FacilityAddr,
   @c_FacilityPhone AS FacilityPhone,
   @c_FacilityFax   AS FacilityFax  
   INTO #RESULT  
   FROM MBOL WITH (NOLOCK)   
   INNER JOIN MBOLDETAIL WITH (NOLOCK) ON MBOL.mbolkey = MBOLDETAIL.mbolkey  
   JOIN ORDERS WITH (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey  
   LEFT OUTER JOIN CODELKUP WITH (NOLOCK) ON CODELKUP.ListName = 'TRANSMETH' AND CODELKUP.Code = MBOL.transmethod   
   JOIN STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.StorerKey
   WHERE MBOL.mbolkey = @c_mbolkey  
  
   SELECT @n_totalorders = COUNT(*), @n_totalcust = COUNT(DISTINCT description)  
   FROM MBOLDETAIL WITH (NOLOCK)  
   WHERE mbolkey = @c_mbolkey  
     
   UPDATE #RESULT  
   SET totalorders = @n_totalorders,  
   totalcust = @n_totalcust  
   WHERE mbolkey = @c_mbolkey  
     
   DECLARE cur_1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT orderkey FROM #RESULT  
   OPEN cur_1  
   FETCH NEXT FROM cur_1 INTO @c_orderkey  
   WHILE (@@fetch_status <> -1)  
   BEGIN  
   SELECT @n_totalqty = ISNULL(SUM(qty), 0)  
   FROM PICKDETAIL WITH (NOLOCK)  
   WHERE orderkey = @c_orderkey  
  
   UPDATE #RESULT  
   SET totalqty = @n_totalqty      
   WHERE mbolkey = @c_mbolkey  
   AND orderkey = @c_orderkey  

   FETCH NEXT FROM cur_1 INTO @c_orderkey  
   END  
   CLOSE cur_1  
   DEALLOCATE cur_1  
/* Comment off (Vanessa01)
   SELECT     PICKDETAIL.Sku, ORDERS.MBOLKey, ORDERS.OrderKey, ISNULL(SUM(ORDERDETAIL.ShippedQty), 0) * SKU.STDGROSSWGT AS totwgt, 
                         CASE WHEN PACK.CaseCnt > 0 THEN ISNULL((ORDERDETAIL.shippedqty), 0) / PACK.CaseCnt ELSE 0 END AS totcs, 
                         CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty), 0) % CAST(PACK.CaseCnt AS Int) ELSE 0 END AS totea, 
                         CASE WHEN PACK.CaseCnt > 0 THEN (SKU.StdCube * ISNULL(SUM(ORDERDETAIL.shippedqty), 0)) ELSE 0 END AS m3
   INTO            [#TEMPCALC]
   FROM         PICKDETAIL WITH (NOLOCK) INNER JOIN
                         SKU WITH (NOLOCK) ON PICKDETAIL.Sku = SKU.Sku AND PICKDETAIL.Storerkey = SKU.StorerKey INNER JOIN
                         PACK WITH (NOLOCK) ON SKU.PACKKey = PACK.PackKey INNER JOIN
                         ORDERS WITH (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey INNER JOIN
                         ORDERDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey AND 
                         PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber
   WHERE     (ORDERS.MBOLKey = @c_mbolkey)
   GROUP BY PICKDETAIL.Sku, ORDERS.MBOLKey, ORDERS.OrderKey, PACK.CaseCnt, SKU.STDGROSSWGT, ORDERDETAIL.ShippedQty, SKU.STDCUBE
*/

   SELECT     ORDERDETAIL.Sku, ORDERS.MBOLKey, ORDERS.OrderKey,
              ISNULL(SUM(ORDERDETAIL.ShippedQty), 0) * SKU.STDGROSSWGT AS totwgt, 
              CASE WHEN PACK.CaseCnt > 0 
                 THEN ISNULL((ORDERDETAIL.shippedqty), 0) / PACK.CaseCnt 
                 ELSE 0 END AS totcs, 
              CASE WHEN PACK.CaseCnt > 0 
                 THEN ISNULL(SUM(ORDERDETAIL.shippedqty), 0) % CAST(PACK.CaseCnt AS Int) 
                 ELSE 0 END AS totea, 
              CASE WHEN PACK.CaseCnt > 0 
                 THEN (SKU.StdCube * ISNULL(SUM(ORDERDETAIL.shippedqty), 0)) 
                 ELSE 0 END AS m3
   INTO            [#TEMPCALC]
   FROM  ORDERDETAIL WITH (NOLOCK) INNER JOIN
   SKU WITH (NOLOCK) ON (ORDERDETAIL.Sku = SKU.Sku AND ORDERDETAIL.Storerkey = SKU.StorerKey) INNER JOIN
   PACK WITH (NOLOCK) ON (SKU.PACKKey = PACK.PackKey) INNER JOIN
   ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
   WHERE  ORDERS.MBOLKey = @c_mbolkey
   GROUP BY ORDERDETAIL.Sku, ORDERS.MBOLKey, ORDERS.OrderKey, PACK.CaseCnt, SKU.STDGROSSWGT, ORDERDETAIL.ShippedQty, SKU.STDCUBE, ORDERDETAIL.OrderLineNumber  --(JH01) add ,ORDERDETAIL.orderlineNumber
   -- (Vanessa01)

   SELECT Mbolkey, Orderkey, totwgt = SUM(totwgt), totcs = SUM(totcs), totea = SUM(totea), m3 = SUM(m3)  
   INTO   #TEMPTOTAL   
   FROM   #TEMPCALC  
   GROUP BY Mbolkey, Orderkey  
  

   UPDATE #RESULT  
   SET totalwgt = t.totwgt,  
   totalcarton = t.totcs,  
   totaleach = t.totea,   
   m3 = t.m3  
   FROM #TEMPTOTAL t   
   WHERE #RESULT.mbolkey = t.Mbolkey  
   AND #RESULT.Orderkey = t.Orderkey  

   SELECT *  
   FROM #RESULT  
   ORDER BY loadkey, orderkey   
  
   IF OBJECT_ID('tempdb..#RESULT') IS NOT NULL
      DROP TABLE #RESULT
   IF OBJECT_ID('tempdb..#TEMPCALC') IS NOT NULL
      DROP TABLE #TEMPCALC
   IF OBJECT_ID('tempdb..#TEMPTOTAL') IS NOT NULL
      DROP TABLE #TEMPTOTAL 
END  


GO
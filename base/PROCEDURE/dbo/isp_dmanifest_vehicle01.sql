SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_dmanifest_vehicle01                            */  
/* Creation Date: 2008-10-22                                            */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: Create Load Manifest Summary                                */ 
/*                                                                      */
/* Input Parameters: @c_mbolkey                                         */
/*                                                                      */
/* Output Parameters: Report                                            */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/*                                                                      */  
/* Called By: PB dw: r_dw_dmanifest_vehicle01 (RCM ReportType 'MANSUM') */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 01-Aug-2012  NJOW01    1.0   251353-Add Storerkey                    */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_dmanifest_vehicle01] (  
	@c_mbolkey NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_totalorders  int,  
		     @n_totalcust    int,  
		     @n_totalqty    int,  
		     @c_orderkey    NVARCHAR(10),  
		     @c_orderkey2   NVARCHAR(10),  
		     @c_prevorder   NVARCHAR(10),  
		     @c_pickdetailkey NVARCHAR(18),  
		     @c_sku     NVARCHAR(20),  
		     @dc_skuwgt     decimal(7,2),  
		     @n_carton    int,  
		     @n_totalcarton   int,  
		     @n_each     int,      
		     @n_totaleach   int           
  
   SELECT MBOL.mbolkey,  
		    vessel = convert(NVARCHAR(30), MBOL.vessel),      -- 2008-02-29 TTL 
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
		    totalcarton = 0,      
		    totaleach = 0,     
		    TotalCartons = Orders.ContainerQty, --- mboldetail.totalcartons,  -- ONG01  
		    MBOL.carrieragent,       
		    MBOL.drivername,         
		    remarks = convert(NVARCHAR(255), MBOL.remarks),       -- 2008-02-29 TTL 
		    ISNULL(RTRIM(CODELKUP.Long) , MBOL.transmethod) TransMethod,   
		    MBOL.placeofdelivery,    
		    MBOL.placeofloading,    
		    MBOL.placeofdischarge,  
		    MBOL.otherreference,  
		    ORDERS.invoiceno,  
		    ORDERS.route,
          ORDERS.containerqty,
 			 ORDERS.billedcontainerqty,
 			 ORDERS.Storerkey 
   INTO #RESULT  
   FROM MBOL                WITH (NOLOCK)   
 	INNER JOIN MBOLDETAIL    WITH (NOLOCK) ON MBOL.mbolkey = MBOLDETAIL.mbolkey  
   JOIN ORDERS              WITH (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey  
   LEFT OUTER JOIN CODELKUP WITH (NOLOCK) ON CODELKUP.ListName = 'TRANSMETH' AND CODELKUP.Code = MBOL.transmethod   
   WHERE MBOL.mbolkey = @c_mbolkey  
  
   SELECT @n_totalorders = COUNT(1), @n_totalcust = COUNT(DISTINCT description)  
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
  
	SELECT ORDERS.Mbolkey,  
			 ORDERS.Orderkey,     
			 totcs = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty),0) / PACK.CaseCnt ELSE 0 END,  
			 totea = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty),0) % CAST (PACK.CaseCnt AS Int) ELSE 0 END 
	INTO #TEMPCALC  
	FROM PICKDETAIL WITH (NOLOCK), SKU WITH (NOLOCK), PACK WITH (NOLOCK), ORDERS WITH (NOLOCK)
	WHERE PICKDETAIL.sku = SKU.sku  
	AND PICKDETAIL.Storerkey = SKU.Storerkey  
	AND SKU.PackKey = PACK.PackKey  
	AND PICKDETAIL.Orderkey = ORDERS.Orderkey  
	AND ORDERS.Mbolkey = @c_mbolkey  
	GROUP BY ORDERS.Mbolkey, ORDERS.Orderkey, PACK.CaseCnt
  
	SELECT Mbolkey, Orderkey, totcs = SUM(totcs), totea = SUM(totea)  
	INTO   #TEMPTOTAL   
	FROM   #TEMPCALC  
	GROUP BY Mbolkey, Orderkey  
  
	UPDATE #RESULT  
	SET totalcarton = t.totcs,  
		 totaleach = t.totea
   FROM #TEMPTOTAL t   
	WHERE #RESULT.mbolkey = t.Mbolkey  
	AND #RESULT.Orderkey = t.Orderkey  
  
   SELECT *  
   FROM #RESULT  
   ORDER BY loadkey, orderkey   
  
	DROP TABLE #RESULT  
	DROP TABLE #TEMPCALC  
	DROP TABLE #TEMPTOTAL  
END  


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nsp_print_packslip_sbuxm                           */  
/* Creation Date: 2008-08-07                                            */  
/* Copyright: IDS                                                       */  
/* Written by: HFLiew                                                   */  
/*                                                                      */  
/* Purpose: Create Load Manifest Summary                                */  
/*                                                                      */  
/* Called By: PB dw:r_dw_print_packslip_sbuxm(RCM ReportType 'DO')      */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Ver. Author   Purposes                                   */ 
/* 17-May-2010 1.1  Vanessa  SOS#173070 before MBOL Shipped using       */
/*                           OrderDetail.QtyPicked.   -- (Vanessa01)    */
/* 05-Aug-2013 1.2  NJOW01   285805-Add userdefine01 & change sorting   */   
/* 03-Nov-2020 1.3  WLChooi  WMS-15592 - Add packing requirement column */
/*                           in Delivery Notes                          */
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_print_packslip_sbuxm](@c_mbolkey NVARCHAR(10))    
 AS  
BEGIN
	SET NOCOUNT ON -- SQL 2005 Standard
	SET QUOTED_IDENTIFIER OFF	
	SET ANSI_NULLS OFF   
	SET CONCAT_NULL_YIELDS_NULL OFF        
	
	DECLARE @n_totalorders       INT,
	        @n_totalcust         INT,
	        @n_totalqty          INT,
	        @c_orderkey          NVARCHAR(10),
	        @dc_totalwgt         DECIMAL(7, 2),
	        @c_orderkey2         NVARCHAR(10),
	        @c_prevorder         NVARCHAR(10),
	        @c_pickdetailkey     NVARCHAR(18),
	        @c_sku               NVARCHAR(20),
	        @dc_skuwgt           DECIMAL(7, 2),
	        @n_carton            INT,
	        @n_totalcarton       DECIMAL(7, 2),
	        @n_each              INT,
	        @n_totaleach         INT,
	        @dc_m3               DECIMAL(7, 2)              
	
	SELECT MBOL.mbolkey,
	       vessel = CONVERT(NVARCHAR(30), MBOL.vessel),
	       MBOL.carrierkey,
	       MBOLDETAIL.loadkey,
	       UPPER(MBOLDETAIL.orderkey)  AS OrderKey,
	       UPPER(MBOLDETAIL.externorderkey) AS externorderkey,
	       MBOLDETAIL.description,
	       MBOLDETAIL.deliverydate,
	       totalqty = 0,
	       totalorders = 0,
	       totalcust = 0,
	       MBOL.Departuredate,
	       totalwgt = 99999999.99,
	       --totalcarton = 99999999.99,
	       totalcarton =  SUM(CASE 
	                            WHEN PACK.CaseCnt > 0 THEN 
	                                 CASE WHEN PICKDETAIL.Status >= '5' THEN
	                                      PICKDETAIL.Qty / PACK.CaseCnt
	                                 ELSE 0 END
	                            ELSE 0
	                          END),
	       totaleach = 0,
	       TotalCartons = Orders.ContainerQty,
	       MBOL.carrieragent,
	       MBOL.drivername,
	       remarks = CONVERT(NVARCHAR(255), MBOL.remarks),
	       ISNULL(RTRIM(CODELKUP.Long), MBOL.transmethod) TransMethod,
	       MBOL.placeofdelivery,
	       MBOL.placeofloading,
	       MBOL.placeofdischarge,
	       MBOL.otherreference,
	       ORDERS.invoiceno,
	       ORDERS.route,
	       m3 = 99999999.99,
	       UPPER(STORER.Company)       AS Company,
	       UPPER(STORER.Address1)      AS Address1,
	       UPPER(STORER.Address2)      AS Address2,
	       UPPER(STORER.Address3)      AS Address3,
	       UPPER(STORER.City)          AS City,
	       STORER.phone1,
	       STORER.Logo,
	       ORDERS.ConsigneeKey,
	       UPPER(ORDERS.C_Company)     AS C_Company,
	       UPPER(ORDERS.C_Address1)    AS C_Address1,
	       UPPER(ORDERS.C_Address2)    AS C_Address2,
	       UPPER(ORDERS.C_Address3)    AS C_Address3,
	       ORDERS.C_Zip,
	       UPPER(ORDERS.C_City)        AS C_City,
	       UPPER(ORDERS.BillToKey)     AS BillToKey,
	       UPPER(ORDERS.B_Company)     AS B_Company,
	       UPPER(ORDERS.B_Address1)    AS B_Address1,
	       UPPER(ORDERS.B_Address2)    AS B_Address2,
	       UPPER(ORDERS.B_Address3)    AS B_Address3,
	       UPPER(ORDERS.B_Zip)         AS B_Zip,
	       UPPER(ORDERS.B_City)        AS B_City,
	       UPPER(PICKDETAIL.SKU)       AS SKU,
	       LOTATTRIBUTE.Lottable04,
	       SUM(CASE 
	            WHEN PICKDETAIL.Status >= '5' -- (Vanessa01)
	                  THEN PICKDETAIL.Qty  -- (Vanessa01)
	            ELSE 0 END)                         AS ShippedQty,	-- (Vanessa01)
	       UPPER(SKU.Descr)            AS Descr,
	       UPPER(PACK.PackUOM1)        AS PackUOM1,
	       UPPER(PACK.PackUOM3)        AS PackUOM3,
	       UPPER(SKU.SkuGroup)         AS SkuGroup,
	       --ORDERDETAIL.OrderLineNumber,
	       ORDERDETAIL.Userdefine01 AS Userdefine01,  --NJOW01
	       ISNULL(CL.Short,'N') AS ShowPackRequirement   --WL01
	       INTO #RESULT
	FROM   MBOL WITH (NOLOCK)
	       JOIN MBOLDETAIL WITH (NOLOCK)
	            ON  MBOL.Mbolkey = MBOLDETAIL.mbolkey
	       JOIN ORDERS WITH (NOLOCK)
	            ON  MBOLDETAIL.Orderkey = ORDERS.Orderkey
	       JOIN ORDERDETAIL WITH (NOLOCK)
	            ON  ORDERS.Orderkey = ORDERDETAIL.OrderKey
	       JOIN PICKDETAIL WITH (NOLOCK)
	            ON  PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey
	            AND PICKDETAIL.Storerkey = ORDERDETAIL.Storerkey
	            AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber
	       LEFT OUTER JOIN CODELKUP WITH (NOLOCK)
	            ON  CODELKUP.ListName = 'TRANSMETH'
	            AND CODELKUP.Code = MBOL.transmethod
	       JOIN STORER WITH (NOLOCK)
	            ON  ORDERS.Storerkey = STORER.StorerKey
	       JOIN SKU WITH (NOLOCK)
	            ON  (
	                    SKU.SKU = PICKDETAIL.SKU
	                    AND SKU.StorerKey = PICKDETAIL.StorerKey
	                )
	       JOIN PACK WITH (NOLOCK)
	            ON  PACK.PackKey = SKU.PackKey
	       JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
	       LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'ShowPackRequirement'               --WL01
	                                          AND CL.Long = 'r_dw_print_packslip_sbuxm' AND CL.Storerkey = ORDERS.StorerKey   --WL01
	WHERE  mbol.mbolkey = @c_mbolkey
	GROUP BY MBOL.mbolkey,
	         CONVERT(NVARCHAR(30), MBOL.vessel),
	         MBOL.carrierkey,
	         MBOLDETAIL.loadkey,
	         UPPER(MBOLDETAIL.orderkey),
	         UPPER(MBOLDETAIL.externorderkey),
	         MBOLDETAIL.description,
	         MBOLDETAIL.deliverydate,
	         MBOL.Departuredate,
	         Orders.ContainerQty,
	         MBOL.carrieragent,
	         MBOL.drivername,
	         CONVERT(NVARCHAR(255), MBOL.remarks),
	         ISNULL(RTRIM(CODELKUP.Long), MBOL.transmethod),
	         MBOL.placeofdelivery,
	         MBOL.placeofloading,
	         MBOL.placeofdischarge,
	         MBOL.otherreference,
	         ORDERS.invoiceno,
	         ORDERS.route,
	         UPPER(STORER.Company),
	         UPPER(STORER.Address1),
	         UPPER(STORER.Address2),
	         UPPER(STORER.Address3),
	         UPPER(STORER.City),
	         STORER.phone1,
	         STORER.Logo,
	         ORDERS.ConsigneeKey,
	         UPPER(ORDERS.C_Company),
	         UPPER(ORDERS.C_Address1),
	         UPPER(ORDERS.C_Address2),
	         UPPER(ORDERS.C_Address3),
	         ORDERS.C_Zip,
	         UPPER(ORDERS.C_City),  
	         UPPER(ORDERS.BillToKey),
	         UPPER(ORDERS.B_Company),
	         UPPER(ORDERS.B_Address1),
	         UPPER(ORDERS.B_Address2),
	         UPPER(ORDERS.B_Address3),
	         UPPER(ORDERS.B_Zip),
	         UPPER(ORDERS.B_City),
	         UPPER(PICKDETAIL.SKU),
	         LOTATTRIBUTE.Lottable04,
	         UPPER(SKU.Descr),
	         UPPER(PACK.PackUOM1),
	         UPPER(PACK.PackUOM3),
	         UPPER(SKU.SkuGroup),
	         ORDERDETAIL.Userdefine01,
	         ISNULL(CL.Short,'N')   --WL01
	
	SELECT @n_totalorders = COUNT(*),
	       @n_totalcust     = COUNT(DISTINCT DESCRIPTION)
	FROM   MBOLDETAIL WITH (NOLOCK)
	WHERE  mbolkey          = @c_mbolkey  
	
	UPDATE #RESULT
	SET    totalorders = @n_totalorders,
	       totalcust = @n_totalcust
	WHERE  mbolkey = @c_mbolkey  
	
	DECLARE cur_1 CURSOR LOCAL FAST_FORWARD READ_ONLY 
	FOR
	    SELECT DISTINCT orderkey
	    FROM   #RESULT
	
	OPEN cur_1 
	FETCH NEXT FROM cur_1 INTO @c_orderkey  
	WHILE (@@fetch_status <> -1)
	BEGIN
	    SELECT @n_totalqty = ISNULL(SUM(qty), 0)
	    FROM   PICKDETAIL WITH (NOLOCK)
	    WHERE  orderkey = @c_orderkey  
	    
	    UPDATE #RESULT
	    SET    totalqty = @n_totalqty
	    WHERE  mbolkey = @c_mbolkey
	           AND orderkey = @c_orderkey 
	    
	    FETCH NEXT FROM cur_1 INTO @c_orderkey
	END 
	CLOSE cur_1 
	DEALLOCATE cur_1  
	
	SELECT ORDERS.MBOLKey,
	       ORDERS.OrderKey,
	       -- Start (Vanessa01)
	       CASE 
	            WHEN MBOL.Status = '0' THEN ISNULL(SUM(ORDERDETAIL.QtyPicked), 0) 
	                 * SKU.STDGROSSWGT
	            ELSE ISNULL(SUM(ORDERDETAIL.ShippedQty), 0) * SKU.STDGROSSWGT
	       END  AS totwgt,
	       CASE 
	            WHEN PACK.CaseCnt > 0 THEN CASE 
	                                            WHEN MBOL.Status = '0' THEN (SKU.stdCube * ISNULL(SUM(ORDERDETAIL.QtyPicked), 0))
	                                            ELSE (SKU.stdCube * ISNULL(SUM(ORDERDETAIL.shippedqty), 0))
	                                       END
	            ELSE 0
	       END  AS m3
	       -- End (Vanessa01)
	       INTO #TEMPCALC
	FROM   PICKDETAIL WITH (NOLOCK)
	       INNER JOIN SKU WITH (NOLOCK)
	            ON  PICKDETAIL.Sku = SKU.Sku
	            AND PICKDETAIL.Storerkey = SKU.StorerKey
	       INNER JOIN ORDERDETAIL WITH (NOLOCK)
	            ON  SKU.Sku = ORDERDETAIL.Sku
	            AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber
	       INNER JOIN PACK WITH (NOLOCK)
	            ON  SKU.PACKKey = PACK.PackKey
	       INNER JOIN ORDERS WITH (NOLOCK)
	            ON  PICKDETAIL.OrderKey = ORDERS.OrderKey
	            AND ORDERDETAIL.OrderKey = ORDERS.OrderKey
	       JOIN MBOL WITH (NOLOCK)
	            ON  MBOL.Mbolkey = ORDERS.mbolkey -- (Vanessa01)
	WHERE  (ORDERS.MBOLKey = @c_mbolkey)
	GROUP BY
	       ORDERS.MBOLKey,
	       ORDERS.OrderKey,
	       SKU.STDGROSSWGT,
	       ORDERDETAIL.ShippedQty,
	       SKU.STDCUBE,
	       PACK.CaseCnt,
	       ORDERDETAIL.QtyPicked,
	       MBOL.Status -- (Vanessa01)
	
	
	SELECT Mbolkey,
	       Orderkey,
	       totwgt = SUM(totwgt),
	       m3 = SUM(m3) 
	       INTO #TEMPTOTAL
	FROM   #TEMPCALC
	GROUP BY
	       Mbolkey,
	       Orderkey  
	
	
	UPDATE #RESULT
	SET    totalwgt = t.totwgt,
	       m3 = t.m3
	FROM   #TEMPTOTAL t
	WHERE  #RESULT.mbolkey = t.Mbolkey
	       AND #RESULT.Orderkey = t.Orderkey 
	
	/*
	SELECT ORDERDETAIL.Sku,
	       ORDERS.MBOLKey,
	       ORDERS.OrderKey,
	       CASE 
	            WHEN PACK.CaseCnt > 0 THEN CASE 
	                                            WHEN MBOL.Status = '0' THEN 
	                                                 ISNULL((ORDERDETAIL.QtyPicked), 0) 
	                                                 / PACK.CaseCnt
	                                            ELSE ISNULL((ORDERDETAIL.shippedqty), 0) 
	                                                 / PACK.CaseCnt
	                                       END
	            ELSE 0
	       END                      AS totcs,
	       LOTATTRIBUTE.Lottable04  AS lot4
	       INTO #TEMPCALC1
	FROM   ORDERS WITH (NOLOCK)
	       INNER JOIN ORDERDETAIL WITH (NOLOCK)
	            ON  ORDERS.OrderKey = ORDERDETAIL.OrderKey
	            AND ORDERS.StorerKey = ORDERDETAIL.StorerKey
	       INNER JOIN SKU WITH (NOLOCK)
	            ON  ORDERDETAIL.StorerKey = SKU.StorerKey
	            AND ORDERDETAIL.Sku = SKU.Sku
	       INNER JOIN PICKDETAIL WITH (NOLOCK)
	            ON  ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey
	            AND ORDERDETAIL.StorerKey = PICKDETAIL.Storerkey
	            AND ORDERDETAIL.Sku = PICKDETAIL.Sku
	            AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber
	       INNER JOIN PACK WITH (NOLOCK)
	            ON  SKU.PACKKey = PACK.PackKey
	       INNER JOIN LOTATTRIBUTE WITH (NOLOCK)
	            ON  PICKDETAIL.Storerkey = LOTATTRIBUTE.StorerKey
	            AND PICKDETAIL.Sku = LOTATTRIBUTE.Sku
	            AND PICKDETAIL.Lot = LOTATTRIBUTE.Lot
	       JOIN MBOL WITH (NOLOCK)
	            ON  MBOL.Mbolkey = ORDERS.mbolkey -- (Vanessa01)
	WHERE  ORDERS.Mbolkey = @c_mbolkey
	GROUP BY
	       ORDERDETAIL.Sku,
	       ORDERS.MBOLKey,
	       ORDERS.OrderKey,
	       ORDERDETAIL.shippedqty,
	       PACK.CaseCnt,
	       LOTATTRIBUTE.Lottable04,
	       ORDERDETAIL.QtyPicked,
	       MBOL.Status -- (Vanessa01)
	
	SELECT sku,
	       Mbolkey,
	       Orderkey,
	       Totcs,
	       lot4
	INTO #TEMPTOTAL1
	FROM   #TEMPCALC1
	GROUP BY
	       sku,
	       Mbolkey,
	       Orderkey,
	       totcs,
	       lot4
	
	UPDATE #RESULT
	SET    totalcarton = t1.totcs,
	       lottable04 = lot4
	FROM   #TEMPTOTAL1 t1
	WHERE  #RESULT.mbolkey = t1.Mbolkey
	       AND #RESULT.Orderkey = t1.Orderkey
	       AND #RESULT.Sku = t1.sku
	*/
	
	SELECT *
	FROM   #RESULT
	ORDER BY
	       loadkey,
	       orderkey,
	       userdefine01, --NJOW01
	       skugroup,
	       sku,
	       lottable04 
	
	DROP TABLE #RESULT 
	DROP TABLE #TEMPCALC 
	DROP TABLE #TEMPTOTAL 
	--DROP TABLE #TEMPCALC1 
	--DROP TABLE #TEMPTOTAL1
END  


GO
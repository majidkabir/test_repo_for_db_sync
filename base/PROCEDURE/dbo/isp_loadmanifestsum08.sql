SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_LoadManifestSum08                              */  
/* Creation Date: 07-Jan-2016                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 360375 - Report Load Manifest                               */  
/*                                                                      */  
/* Called By: PB dw: r_dw_dmanifest_sum08 (RCM ReportType 'MANSUM')     */  
/*                                                                      */  
/* PVCS Version: 1.10                                                   */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_LoadManifestSum08] (  
    @c_mbolkey NVARCHAR(10)  
 )  
 AS  
 BEGIN  
    SET NOCOUNT ON			-- SQL 2005 Standard
    SET QUOTED_IDENTIFIER OFF	
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF    
    
    DECLARE @n_totalorders int,  
            @n_totalcust  int,  
            @n_totalqty  int,  
            @c_orderkey  NVARCHAR(10),  
            @dc_totalwgt    decimal(7,2),  
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
           vessel = MBOL.vessel,   
           MBOL.carrierkey,  
           MBOLDETAIL.loadkey,   
           MBOLDETAIL.orderkey,  
           MBOLDETAIL.externorderkey,  
           MBOLDETAIL.description,  
           MBOLDETAIL.deliverydate,  
           totalqty = 0,  
           totalorders = 0,  
           totalcust = MBOL.custcnt,--totalcust = 0,  
           MBOL.Departuredate,   
           totalwgt = 99999999.99, 
           totalcarton = 0,       
           totaleach = 0,    
           mboldetail.totalcartons, 
           Orders.StorerKey,     
           MBOL.CarrierAgent,    
           MBOL.PlaceOfDelivery, 
           MBOL.PlaceOfDischarge,
           MBOL.OtherReference,  
           MBOL.DriverName,      
           transmethod = CDL.description,     
           MBOL.PlaceOfLoading,  
           MBOL.Remarks,         
           FACILITY.Descr,  
           STORER.Company, 
           MBOL.EditWho,
           MBOL.cube,
           MBOL.bookingreference 
    INTO #RESULT  
    FROM MBOL (NOLOCK) 
    INNER JOIN MBOLDETAIL (NOLOCK)  
          ON MBOL.mbolkey = MBOLDETAIL.mbolkey  
    INNER JOIN ORDERS (NOLOCK) 
          ON MBOL.MbolKey = ORDERS.MBOLKey AND   
             MBOLDETAIL.OrderKey = ORDERS.OrderKey
    INNER JOIN FACILITY (NOLOCK) ON MBOL.Facility = FACILITY.Facility 
    INNER JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey 
    INNER JOIN Codelkup CDL WITH (NOLOCK) ON CDL.code = MBOL.TransMethod and CDL.listname='transmeth' 
    WHERE MBOL.mbolkey = @c_mbolkey  
    
    SELECT @n_totalorders = COUNT(*)--, @n_totalcust = COUNT(DISTINCT description)  
    FROM MBOLDETAIL (NOLOCK)  
    WHERE mbolkey = @c_mbolkey  
      
    UPDATE #RESULT  
    SET totalorders = @n_totalorders--  
        --totalcust = @n_totalcust  
    WHERE mbolkey = @c_mbolkey  
      
    DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY  
      FOR SELECT orderkey FROM #RESULT
        
    OPEN cur_1  
    FETCH NEXT FROM cur_1 INTO @c_orderkey  
    WHILE (@@fetch_status <> -1)  
    BEGIN  
       SELECT @n_totalqty = ISNULL(SUM(qty), 0)  
       FROM PICKDETAIL (NOLOCK)  
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
           totwgt = ISNULL(SUM(PICKDETAIL.Qty),0) * SKU.stdgrosswgt,  
           totcs = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty),0) / PACK.CaseCnt ELSE 0 END,  
           totea = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty),0) % CAST (PACK.CaseCnt AS Int) ELSE 0 END      
    INTO #TEMPCALC  
    FROM PICKDETAIL (NOLOCK), SKU (NOLOCK), PACK (NOLOCK), ORDERS (NOLOCK)  
    WHERE PICKDETAIL.sku = SKU.sku  
    AND PICKDETAIL.Storerkey = SKU.Storerkey  
    AND SKU.PackKey = PACK.PackKey  
    AND PICKDETAIL.Orderkey = ORDERS.Orderkey  
    AND ORDERS.Mbolkey = @c_mbolkey  
    GROUP BY ORDERS.Mbolkey, ORDERS.Orderkey, PACK.CaseCnt, SKU.stdgrosswgt  
    
    SELECT Mbolkey, Orderkey, totwgt = SUM(totwgt), totcs = SUM(totcs), totea = SUM(totea)  
    INTO   #TEMPTOTAL   
    FROM   #TEMPCALC  
    GROUP BY Mbolkey, Orderkey  
      
    UPDATE #RESULT  
    SET totalwgt = t.totwgt,  
        totalcarton = t.totcs,  
        totaleach = t.totea  
    FROM  #TEMPTOTAL t   
    WHERE #RESULT.mbolkey = t.Mbolkey  
    AND   #RESULT.Orderkey = t.Orderkey  
    
    SELECT *  
    FROM #RESULT  
    ORDER BY loadkey, orderkey   
    
    DROP TABLE #RESULT  
    DROP TABLE #TEMPCALC  
    DROP TABLE #TEMPTOTAL  
 END  

GO
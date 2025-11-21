SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_LoadManifestDet05                              */  
/* Creation Date: 27-Jun-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 247851 - PH Load Manifest Summary                           */  
/*                                                                      */  
/* Called By: PB dw: r_dw_dmanifest_sum06 (RCM ReportType 'MANSUM')     */  
/*                                                                      */  
/* PVCS Version: 1.10                                                   */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/* 02-APR-2019  WLCHOOI    WMS-8458 - NK_PH Load Manifest Report (WL01) */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_LoadManifestDet05] (  
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
            @n_totaleach   int,
            @c_ProductEngine      NVARCHAR(100),      --WL01
            @c_ShowField          NVARCHAR(1),        --WL01
            @c_BUSR7              NVARCHAR(50)        --WL01          
    
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
           totalcust = 0,  
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
           MBOL.TransMethod,     
           MBOL.PlaceOfLoading,  
           MBOL.Remarks,         
           FACILITY.Descr,  
           STORER.CustomerGroupName, 
           MBOL.EditWho,
           ShowField = ISNULL(CL.SHORT,'N'),              --WL01
           ProductEngine = CONVERT(NVARCHAR(100),''),      --WL01
           ExternPOKey = ORDERS.ExternPOKey               --WL01
    INTO #RESULT  
    FROM MBOL (NOLOCK) 
    INNER JOIN MBOLDETAIL (NOLOCK)  
          ON MBOL.mbolkey = MBOLDETAIL.mbolkey  
    INNER JOIN ORDERS (NOLOCK) 
          ON MBOL.MbolKey = ORDERS.MBOLKey AND   
             MBOLDETAIL.OrderKey = ORDERS.OrderKey
    INNER JOIN FACILITY (NOLOCK) ON MBOL.Facility = FACILITY.Facility 
    INNER JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey 
    LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'ShowField'                                   --WL01
                                  AND CL.Long = 'r_dw_dmanifest_sum06' AND CL.STORERKEY = ORDERS.Storerkey                  --WL01
    WHERE MBOL.mbolkey = @c_mbolkey  
    
    SELECT @n_totalorders = COUNT(*), @n_totalcust = COUNT(DISTINCT description)  
    FROM MBOLDETAIL (NOLOCK)  
    WHERE mbolkey = @c_mbolkey  
      
    UPDATE #RESULT  
    SET totalorders = @n_totalorders,  
        totalcust = @n_totalcust  
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

       --WL01 START
       SELECT TOP 1 @c_BUSR7 = BUSR7 FROM SKU (NOLOCK)
       JOIN ORDERDETAIL (NOLOCK) ON SKU.SKU = ORDERDETAIL.SKU AND SKU.STORERKEY = ORDERDETAIL.STORERKEY
       WHERE ORDERDETAIL.ORDERKEY = @c_Orderkey

       SELECT @c_ProductEngine = ISNULL(CL2.description,'')
       FROM CODELKUP CL2 (NOLOCK) WHERE CL2.LISTNAME = 'NIKEPH001'
       AND CL2.CODE = @c_BUSR7 AND CL2.STORERKEY = (SELECT TOP 1 STORERKEY FROM ORDERS (NOLOCK) WHERE ORDERKEY = @c_Orderkey)
       --WL01 END

       UPDATE #RESULT  
       SET totalqty          = @n_totalqty
           ,ProductEngine    = ISNULL(@c_ProductEngine,'')            --WL01
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
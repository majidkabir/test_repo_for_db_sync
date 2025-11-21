SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Stored Procedure: nsp_LoadManifestSum05                              */  
/* Creation Date: 25-Mar-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Load Manifest Summary (copy from nsp_LoadManifestSum01      */  
/*          SOS#209446                                                  */  
/* Called By: PB dw: r_dw_dmanifest_sum05 (RCM ReportType 'MANSUM')     */  
/*                                                                      */  
/* PVCS Version: 1.10                                                   */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver.  Purposes                                  */  
/* 19-May-2011  NJOW01  1.0   215868 - Only show Scanned Order          */
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_LoadManifestSum05] (  
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
           @n_totaltote int   

--NJOW01           
   SELECT DISTINCT MD.Orderkey, PD.LabelNo
   INTO #STV
   FROM MBOLDETAIL MD (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)
   JOIN PACKDETAIL PD (NOLOCK) ON (PH.Pickslipno = PD.Pickslipno)
   JOIN rdt.RDTScanToTruck S2T (NOLOCK) ON (MD.Mbolkey = S2T.Mbolkey AND PD.Labelno = S2T.Refno)
   WHERE MD.Mbolkey = @c_mbolkey 
  
   SELECT MBOL.mbolkey,  
          MBOL.vessel AS vessel, 
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
          CAST(MBOL.Remarks AS NVARCHAR(255)) AS Remarks,
          ORDERS.Consigneekey,
          SHIPTO.Address1,
          MAX(ORDERS.Route) AS Route,
          totaltote = 0
   INTO #RESULT  
   FROM MBOL (NOLOCK) JOIN MBOLDETAIL (NOLOCK) ON MBOL.mbolkey = MBOLDETAIL.mbolkey  
   JOIN ORDERS (NOLOCK) ON MBOL.MbolKey = ORDERS.MBOLKey AND 
												   MBOLDETAIL.OrderKey = ORDERS.OrderKey
   JOIN (SELECT DISTINCT Orderkey FROM #STV) SV ON (SV.Orderkey = MBOLDETAIL.Orderkey)   --NJOW01
   LEFT JOIN STORER SHIPTO (NOLOCK) ON ORDERS.Consigneekey = SHIPTO.Storerkey
   WHERE MBOL.mbolkey = @c_mbolkey
   GROUP BY MBOL.mbolkey,  
            MBOL.vessel, 
            MBOL.carrierkey,  
            MBOLDETAIL.loadkey,   
            MBOLDETAIL.orderkey,  
            MBOLDETAIL.externorderkey,  
            MBOLDETAIL.description,  
            MBOLDETAIL.deliverydate,  
            MBOL.Departuredate,   
            mboldetail.totalcartons,  
            Orders.StorerKey,     
            MBOL.CarrierAgent,    
            MBOL.PlaceOfDelivery, 
            MBOL.PlaceOfDischarge,
            MBOL.OtherReference,  
            MBOL.DriverName,      
            MBOL.TransMethod,     
            MBOL.PlaceOfLoading,  
            CAST(MBOL.Remarks AS NVARCHAR(255)),
            ORDERS.Consigneekey,
            SHIPTO.Address1
  
   SELECT @n_totalorders = COUNT(*), @n_totalcust = COUNT(DISTINCT description)  
   FROM MBOLDETAIL (NOLOCK)  
   JOIN (SELECT DISTINCT Orderkey FROM #STV) SV ON (SV.Orderkey = MBOLDETAIL.Orderkey)   --NJOW01
   WHERE mbolkey = @c_mbolkey  
     
   UPDATE #RESULT  
   SET totalorders = @n_totalorders,  
  		 totalcust = @n_totalcust  
   WHERE mbolkey = @c_mbolkey  
     
   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY  
   FOR  
   SELECT orderkey FROM #RESULT  
   OPEN cur_1  
   FETCH NEXT FROM cur_1 INTO @c_orderkey  
   WHILE (@@fetch_status <> -1)  
   BEGIN  
     /*SELECT @n_totalqty = ISNULL(SUM(qty), 0)  
     FROM PICKDETAIL (NOLOCK)  
     WHERE orderkey = @c_orderkey */
     
     SELECT @n_totaltote = COUNT(DISTINCT PD.Labelno+PD.Dropid),
            @n_totalqty = ISNULL(SUM(qty), 0)          
     FROM PackHeader PH (NOLOCK)
     JOIN PackDetail PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
     JOIN #STV ON PH.Orderkey = #STV.Orderkey AND PD.Labelno = #STV.Labelno
     WHERE PH.Orderkey = @c_orderkey
     
     UPDATE #RESULT  
     SET totalqty = @n_totalqty,
         totaltote = @n_totaltote  
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
   FROM ORDERS (NOLOCK), PICKDETAIL (NOLOCK), SKU (NOLOCK), PACK (NOLOCK), #STV 
   WHERE PICKDETAIL.sku = SKU.sku  
   AND PICKDETAIL.Storerkey = SKU.Storerkey  
   AND SKU.PackKey = PACK.PackKey  
   AND PICKDETAIL.Orderkey = ORDERS.Orderkey  
   AND ORDERS.Mbolkey = @c_mbolkey  
   AND #STV.Orderkey = Orders.Orderkey  --NJOW01
   AND #STV.Labelno = PICKDETAIL.DropID  --NJOW1
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nsp_LoadManifestSum01                              */  
/* Creation Date: 19-Feb-2008                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Create Load Manifest Summary                                */  
/*                                                                      */  
/* Called By: PB dw: r_dw_dmanifest_sum01 (RCM ReportType 'MANSUM')     */  
/*                                                                      */  
/* PVCS Version: 1.10                                                   */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/* 23-Dec-2002  Vicky      SOS #9086 - Date Dispatched should get from  */  
/*                         MBOL.DepartureDate instead of today()        */  
/* 05-Feb-2003  Wally      SOS 9113 - Display "remarks" as the "vessel" */  
/* 12-Apr-2004  MaryVong   Add TotalWgt for NZMM Project                */  
/* 29-Apr-2004  MaryVong   Add in TotalCarton (NZMM)                    */  
/* 04-May-2004  MaryVong   Add TotalEach,change TotalWgt to decimal(7,2)*/  
/* 17-Jun-2004  MaryVong   SOS24320 Bug fixed                           */  
/* 15-Oct-2004  Mohit      Change cursor type                           */  
/* 30-Jun-2005  OngGB      SOS36940 - SARALEE - Print no. of cartons    */  
/*                         packed mboldetail.totalcartons               */  
/* 08-Jul-2005  June       SOS37649 - bug fixed incorrect total weight &*/  
/*                         total cube                                   */  
/* 11-Nov-2005  MaryVong   SOS42825 Increase length of totalwgt field   */  
/*                         to 99999999.99                               */  
/* 19-Feb-2008  HFLiew     SOS#97833 Add new fields in the report       */ 
/* 11-Aug-2020  WLChooi    WMS-14656 - Show MBOLKey Barcode (WL01)      */
/* 1-May-2021   Mingle     WMS-16929 - Show OrdGroup and add codelkup(ML01)*/
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_LoadManifestSum01] (  
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
       -- Added By MaryVong on 11-Mar-2004 (NZMM Project)  
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
          --     vessel = MBOL.remarks, -- SOS 9113 wally 5.feb.03 , remarked by HFLIEW on 27-02-2008 from IT Local request  
          vessel = MBOL.vessel, -- Added by HFLiew on 27 Feb 2008 SOS Ticket#97833-Local IT request to change it to Mbol.vessel  
          MBOL.carrierkey,  
          MBOLDETAIL.loadkey,   
          MBOLDETAIL.orderkey,  
          MBOLDETAIL.externorderkey,  
          MBOLDETAIL.description,  
          MBOLDETAIL.deliverydate,  
          totalqty = 0,  
          totalorders = 0,  
          totalcust = 0,  
          MBOL.Departuredate,   -- Added By Vicky 23 Dec 2002 SOS #9086  
          -- SOS42825         
          -- totalwgt = 99999.99,  -- Added By MaryVong on 11-Mar-2004 (NZMM Project)  
          totalwgt = 99999999.99,  -- Added By MaryVong on 11-Mar-2004 (NZMM Project)  
          totalcarton = 0,    -- Added By MaryVong on 11-Mar-2004 (NZMM Project)   
          totaleach = 0,     -- Added By MaryVong on 04-May-2004 (NZMM Project)  
          mboldetail.totalcartons,  -- Added By Ong on 17Jun2005 sos36940  
          Orders.StorerKey,     -- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
          MBOL.CarrierAgent,    -- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
          MBOL.PlaceOfDelivery, -- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
          MBOL.PlaceOfDischarge,-- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
          MBOL.OtherReference,  -- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
          MBOL.DriverName,      -- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
          MBOL.TransMethod,     -- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
          MBOL.PlaceOfLoading,  -- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
          MBOL.Remarks,         -- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
          ISNULL(CL.Short,'N') AS ShowBarcode,   --WL01
          CASE WHEN Orders.StorerKey = 'IDSMED' THEN Orders.OrderGroup ELSE MBOLDETAIL.orderkey END AS ShowOrdGrp,   --ML01
          ISNULL(CL.Short,'N') AS RepOrdKeybyOrdGrp   --ML01
   INTO #RESULT  
   FROM MBOL (NOLOCK) INNER JOIN MBOLDETAIL (NOLOCK)  
   ON MBOL.mbolkey = MBOLDETAIL.mbolkey  
   INNER JOIN ORDERS (NOLOCK)-- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
   ON MBOL.MbolKey = ORDERS.MBOLKey AND -- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
   MBOLDETAIL.OrderKey = ORDERS.OrderKey-- Added by HFLiew on 19 Feb 2008 SOS Ticket#97833  
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname =  'REPORTCFG' AND CL.Storerkey = ORDERS.Storerkey   --WL01
                                 AND CL.Code = 'ShowBarcode' AND CL.Long = 'r_dw_dmanifest_sum01'     --WL01
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.Listname =  'REPORTCFG' AND CL1.Storerkey = ORDERS.Storerkey   --ML01
                                 AND CL1.Code = 'RepOrdKeybyOrdGrp' AND CL1.Long = 'r_dw_dmanifest_sum01'     --ML01
   WHERE MBOL.mbolkey = @c_mbolkey  
  
   SELECT @n_totalorders = COUNT(*), @n_totalcust = COUNT(DISTINCT description)  
   FROM MBOLDETAIL (NOLOCK)  
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
  
   -- Start : SOS37649  
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
   -- Start : SOS37649  
   DROP TABLE #TEMPCALC  
   DROP TABLE #TEMPTOTAL  
   -- End : SOS37649  
END   

GO
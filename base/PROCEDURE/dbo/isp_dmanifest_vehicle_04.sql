SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Stored Procedure: isp_dmanifest_vehicle_04                           */          
/* Creation Date: 2020-09-01                                            */          
/* Copyright: IDS                                                       */          
/* Written by: NickYeo                                                  */          
/*                                                                      */          
/* Purpose: Create Load Manifest Summary                                */          
/*                                                                      */          
/* Called By: PB dw: r_dw_dmanifest_vehicle04 (RCM ReportType 'MANSUM') */          
/*                                                                      */          
/* PVCS Version: 1.1                                                    */          
/*                                                                      */          
/* Version: 5.4                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date        Author    Ver.  Purposes                                 */          
/* 21-Dec-2020 WLChooi   1.1   WMS-15884 - Add new logic (WL01)         */        
/* 12-May-2021 mingle01  1.2   WMS-16488 - Add new mapping(ML01)        */      
/************************************************************************/          
          
CREATE PROC [dbo].[isp_dmanifest_vehicle_04] (          
    @c_mbolkey NVARCHAR(10)          
 )          
 AS          
 BEGIN          
   SET NOCOUNT ON          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF          
          
   DECLARE @n_totalorders  int,          
     @n_totalcust    int,          
     @n_totalqty    int,          
     @c_orderkey    NVARCHAR(10),          
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
     @dc_m3             decimal(7,2)            
          
          
   DECLARE          
   @c_FacilityAddr         NVARCHAR(255),          
   @c_FacilityPhone        NVARCHAR(255),          
   @c_FacilityFax          NVARCHAR(255),          
   @c_Company              NVARCHAR(255)          
             
   SELECT @c_FacilityAddr  = CASE WHEN ISNULL(CL.Short,'N') = 'Y' THEN          
                                 (LTRIM(RTRIM(ISNULL(F.Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(F.Address2,''))) + ' ' +           
                                 LTRIM(RTRIM(ISNULL(F.Address3,''))) + ' ' + LTRIM(RTRIM(ISNULL(F.Address4,''))) + ' ' + LTRIM(RTRIM(ISNULL(F.Country,''))))          
                             ELSE          
                                 'IDS Logistics Services (M) Sdn Bhd . Lot 23, Jalan Batu Arang, Rawang Integrated Industrial Park, 48000 Rawang, Selangor Darul Ehsan.'          
                             END          
        , @c_FacilityPhone = CASE WHEN ISNULL(CL.Short,'N') = 'Y' THEN          
                                LTRIM(RTRIM(ISNULL(F.Phone1,'')))          
                             ELSE          
                                '603-60925581'          
                             END          
        , @c_FacilityFax   = CASE WHEN ISNULL(CL.Short,'N') = 'Y' THEN          
                                LTRIM(RTRIM(ISNULL(F.Fax1,'')))          
                             ELSE          
                           '603-60925681'          
                             END          
        , @c_Company       = CASE WHEN ISNULL(CL.Short,'N') = 'Y' THEN          
                                N'LF Logistics Services (M) Sdn Bhd  ?≥√ A Li & Fung Company'          
                   ELSE          
                                ''          
                             END          
   FROM Facility F (NOLOCK)          
   JOIN MBOL MB (NOLOCK) ON F.Facility = MB.Facility          
   JOIN MBOLDETAIL MD (NOLOCK) ON MB.MbolKey = MD.MbolKey          
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = MD.OrderKey          
   LEFT OUTER JOIN CODELKUP CL WITH (NOLOCK) ON CL.ListName = 'REPORTCFG'           
                                            AND CL.Code = 'ShowFacilityInfo'           
                                            AND CL.Storerkey = OH.Storerkey          
                                            AND CL.Long = 'r_dw_dmanifest_vehicle'          
   WHERE MB.MbolKey = @c_mbolkey          
          
   DECLARE @c_epodweburl NVARCHAR(120),          
           @c_epodweburlparam NVARCHAR(500)          
                     
                
   SELECT MBOL.mbolkey,           
          VoyageNumber = MBOL.VoyageNumber,                
          MBOL.carrierkey,           
          MBOLDETAIL.loadkey,           
          MBOLDETAIL.orderkey,           
          ORDERS.externorderkey,           
          ST_Company = ST.company,            
          MBOL.ArrivalDate,               
          totalqty = 0,          
          totalorders = 0,          
          totalcust = 0,          
          MBOL.Departuredate,           
          totalwgt = 99999999.99,          
          totalcarton = 0,          
          totaleach = 0,          
          TotalCartons = ISNULL(Orders.ContainerQty,0),   --WL01         
          MBOL.VesselQualifier,           
          MBOL.Equipment,               
          remarks = convert(NVARCHAR(255), MBOL.remarks),               
          MBOL.transmethod TransMethod,           
          MBOL.placeofdelivery,           
          MBOL.placeofloading,           
          MBOL.placeofdischarge,           
          MBOL.otherreference,          
          ORDERS.invoiceno,           
          MBOL.route,                
          m3 = 99999999.99,          
          STORER.Logo,            
          ORDERS.Storerkey,          
          MBWGT = MBOL.Weight,          
          MBCube = MBOL.Cube,           
          epodfullurl = @c_epodweburlparam,        
          (SELECT SUM(PD.Qty) FROM PICKDETAIL PD (NOLOCK) WHERE PD.OrderKey = ORDERS.OrderKey) AS SUMQty,   --WL01            
          ContainerNo = ISNULL(MBOL.ContainerNo,''),   --WL01         
          SealNo = ISNULL(MBOL.SealNo,''),   --WL01     
          --START (ML01)   
          MBOLDETAIL.deliverydate,              
          LTRIM(RTRIM(ISNULL(Facility.Address1,''))) AS Address1,  
          LTRIM(RTRIM(ISNULL(Facility.Address2,''))) AS Address2,  
          LTRIM(RTRIM(ISNULL(Facility.Address3,''))) AS Address3,      
          LTRIM(RTRIM(ISNULL(Facility.Address4,''))) AS Address4,  
          LTRIM(RTRIM(ISNULL(Facility.Country,''))) AS country,  
          LTRIM(RTRIM(ISNULL(Facility.Phone1,''))) AS phone1,  
          LTRIM(RTRIM(ISNULL(Facility.Phone2,''))) AS phone2  
          --END (ML01)  
   INTO #RESULT          
   FROM MBOL WITH (NOLOCK)          
   INNER JOIN MBOLDETAIL WITH (NOLOCK) ON MBOL.mbolkey = MBOLDETAIL.mbolkey          
   JOIN ORDERS WITH (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey          
   JOIN STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey           
   JOIN STORER ST WITH (NOLOCK) ON ORDERS.consigneekey = ST.Storerkey         
   JOIN FACILITY WITH (NOLOCK) ON MBOL.facility = FACILITY.facility    
   LEFT OUTER JOIN CODELKUP WITH (NOLOCK) ON CODELKUP.ListName = 'TRANSMETH' AND CODELKUP.Code = MBOL.transmethod          
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
        , epodfullurl = @c_Orderkey            
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
          totea = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty),0) % CAST (PACK.CaseCnt AS Int) ELSE 0 END,          
          m3 = CASE WHEN PACK.CaseCnt > 0 THEN (SKU.[Cube] * ISNULL(SUM(PICKDETAIL.Qty),0)) / (PACK.CaseCnt) ELSE 0 END          
   INTO #TEMPCALC          
   FROM PICKDETAIL WITH (NOLOCK)          
   INNER JOIN SKU WITH (NOLOCK) ON Pickdetail.sku = Sku.sku          
                      AND (Pickdetail.storerkey = Sku.storerkey)          
   INNER JOIN PACK WITH (NOLOCK) ON PickDetail.PackKey = Pack.PackKey          
   INNER JOIN ORDERS WITH (NOLOCK) ON (PickDetail.OrderKey = Orders.OrderKey          
                                   AND ORDERS.Mbolkey = @c_mbolkey)          
   GROUP BY ORDERS.Mbolkey, ORDERS.Orderkey, PACK.CaseCnt, SKU.stdgrosswgt, SKU.[cube]          
          
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
          
   DROP TABLE #RESULT          
   DROP TABLE #TEMPCALC          
   DROP TABLE #TEMPTOTAL          
END   

GO
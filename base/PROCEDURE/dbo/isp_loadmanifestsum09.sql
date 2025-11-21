SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_LoadManifestSum09                              */      
/* Creation Date: 19-AUG-2020                                           */      
/* Copyright: IDS                                                       */      
/* Written by:CSCHONG                                                   */      
/*                                                                      */      
/* Purpose: WMS-14645 - Request of Truck Manifest Datawindow            */      
/*                                                                      */      
/* Called By: PB dw: r_dw_dmanifest_sum09 (RCM ReportType 'MANSUM')     */      
/*                                                                      */      
/* PVCS Version: 1.1                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author  Ver.  Purposes                                  */    
/************************************************************************/      
      
CREATE PROC [dbo].[isp_LoadManifestSum09] (      
    @c_mbolkey NVARCHAR(10)      
 )      
 AS      
 BEGIN      
   SET NOCOUNT ON   -- SQL 2005 Standard    
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF     


  DECLARE @c_CNTMDExtOrdkey INT,
          @c_company  NVARCHAR(45),
          @c_userid   nvarchar(125)

    
    SET @c_company = 'LF LOGISTICS Services(M) SDN BHD'
    SET @c_userid =suser_name()  
       
   CREATE TABLE #TMP_LMNFSUM09
         (  Mbolkey                       NVARCHAR(10)
         ,  Orderkey                      NVARCHAR(30)
         ,  ExtPOKey                      NVARCHAR(20)
         ,  OHROUTE                       NVARCHAR(30)
         ,  DepartureDate                 DATETIME
         ,  Storerekey                    NVARCHAR(15)
         ,  FAddress1                     NVARCHAR(45)
         ,  FAddress2                     NVARCHAR(45)
         ,  FAddress3                     NVARCHAR(45) 
         ,  FZip                          NVARCHAR(45)
         ,  FCity                         NVARCHAR(45)
         ,  FAddress4                     NVARCHAR(45)
         ,  FState                        NVARCHAR(45)
         ,  Remarks                       NVARCHAR(255)      
         ,  Consigneekey                  NVARCHAR(100)       
         ,  TtlExtLineno                  INT
         ,  Company                       NVARCHAR(45)       
         ,  FPhone1                       NVARCHAR(45)          
         ,  ExtOrdkey                     NVARCHAR(50) 
         ,  TTLCTN                        INT
         ,  MDWGT                         FLOAT
         ,  CNTMDExtOrdkey                INT
         ,  PrepareBy                     NVARCHAR(125)
          )


        CREATE TABLE #TMP_LMNFSUMORD09
         (  Mbolkey                       NVARCHAR(10)
         ,  Orderkey                      NVARCHAR(30)
         ,  Extordkey                     NVARCHAR(50)
         ,  TTLExtLineNo                  INT)


        INSERT INTO #TMP_LMNFSUMORD09 (mbolkey,orderkey,extordkey,ttlextlineno) 
        SELECT DISTINCT MB.MbolKey,OH.OrderKey,oh.ExternOrderKey,COUNT(distinct OD.ExternLineNo)
        FROM MBOL MB (NOLOCK)
        JOIN MBOLDETAIL MD (NOLOCK) ON MB.MBOLKEY = MD.MBOLKEY
        JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = MD.ORDERKEY
        JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
        WHERE MB.mbolkey = @c_mbolkey
        GROUP BY MB.MbolKey,OH.OrderKey,oh.ExternOrderKey

    
    SET @c_CNTMDExtOrdkey = 0
    
    SELECT @c_CNTMDExtOrdkey = COUNT(Externorderkey)
    FROM MBOLDETAIL MBD WITH (NOLOCK)
    WHERE MBD.mbolkey = @c_mbolkey
         
   INSERT INTO #TMP_LMNFSUM09
         (  Mbolkey                        
         ,  Orderkey                         
         ,  ExtPOKey                    
         ,  OHROUTE  
         ,  DepartureDate                 
         ,  Storerekey                    
         ,  FAddress1                   
         ,  FAddress2                
         ,  FAddress3                
         ,  FZip                 
         ,  FCity                     
         ,  FAddress4                    
         ,  FState                 
         ,  Remarks                        
         ,  Consigneekey                   
         ,  TtlExtLineno                      
         ,  Company                        
         ,  FPhone1                    
         ,  ExtOrdkey
         ,  TTLCTN
         ,  MDWGT
         ,  CNTMDExtOrdkey
         ,  PrepareBy
         )  
   SELECT DISTINCT MB.mbolkey,      
          OH.OrderKey,     
          OH.ExternPOKey,      
          OH.Route,      
          MB.Departuredate,       
          OH.StorerKey,         
          ISNULL(F.Address1,''),
          ISNULL(F.Address2,''),
          ISNULL(F.Address3,''),      
          ISNULL(F.zip,''),
          ISNULL(F.city,''),     
          ISNULL(F.Address4,''),  
          ISNULL(F.State,''),            
          CAST(MB.Remarks AS NVARCHAR(255)) AS Remarks,    
          OH.ConsigneeKey +space(2) + ISNULL(DELA.company,''),   
          LORD09.TTLExtLineNo,    
          Company = @c_company
         ,ISNULL(F.Phone1,'') 
         ,OH.ExternOrderKey   
         , CASE WHEN ISNULL(PH.TTLCNTS,0) = 0 THEN OH.ContainerQty ELSE PH.TTLCNTS  END
         , MD.Weight    
         ,@c_CNTMDExtOrdkey
         ,@c_userid
   FROM MBOL MB (NOLOCK) 
   JOIN MBOLDETAIL MD (NOLOCK) ON MB.MBOLKEY = MD.MBOLKEY
   JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = MD.ORDERKEY  
   JOIN FACILITY F WITH (NOLOCK) ON F.Facility=OH.Facility
   LEFT JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = OH.Orderkey
   LEFT JOIN STORER DELA WITH (NOLOCK) ON DELA.Storerkey = OH.consigneekey AND DELA.Type='2'
   JOIN #TMP_LMNFSUMORD09 LORD09 ON LORD09.Mbolkey=OH.MbolKey AND LORD09.Orderkey=OH.OrderKey AND LORD09.Extordkey=OH.ExternOrderKey
   WHERE MB.mbolkey = @c_mbolkey         
           
   SELECT  Mbolkey                        
         ,  Orderkey                         
         ,  ExtPOKey                    
         ,  OHROUTE  
         ,  DepartureDate                 
         ,  Storerekey                    
         ,  FAddress1                   
         ,  FAddress2                
         ,  FAddress3                
         ,  FZip                 
         ,  FCity                     
         ,  FAddress4                    
         ,  FState                 
         ,  Remarks                        
         ,  Consigneekey                   
         ,  TtlExtLineno                      
         ,  Company                        
         ,  FPhone1                    
         ,  ExtOrdkey
         ,  TTLCTN
         ,  MDWGT
         ,  CNTMDExtOrdkey
         ,  PrepareBy
   FROM #TMP_LMNFSUM09
   ORDER BY mbolkey,orderkey,extordkey
      
 DROP Table #TMP_LMNFSUM09  
 DROP Table #TMP_LMNFSUMORD09   
        
 END      

SET QUOTED_IDENTIFIER OFF

GO
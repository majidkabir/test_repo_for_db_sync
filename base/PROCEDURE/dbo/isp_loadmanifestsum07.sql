SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_LoadManifestSum07                              */      
/* Creation Date: 04-Dec-2012                                           */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: SOS#262670-Vanguard - Despatch Manifest Summary             */      
/*                                                                      */      
/* Called By: PB dw: r_dw_dmanifest_sum07 (RCM ReportType 'MANSUM')     */      
/*                                                                      */      
/* PVCS Version: 1.3                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author  Ver.  Purposes                                  */    
/* 03-07-2013   ChewKP  1.0   Remove Join by MBOLDetail (ChewKP01)      */  
/* 09-JUL-2013  YTWan   1.1   Add ToteID to Report (Wan01)              */
/* 25-JUL-2013  YTWan   1.2   SOS#284522-Store & Driver Copy (Wan02)    */
/* 10-May-2022  WLChooi 1.3   DevOps Combine Script                     */
/* 10-May-2022  WLChooi 1.3   WMS-19628 Extend Userdefine02 column to   */
/*                            40 (WL01)                                 */
/************************************************************************/      
      
CREATE PROC [dbo].[isp_LoadManifestSum07] (      
    @c_mbolkey NVARCHAR(10)      
 )      
 AS      
 BEGIN      
   SET NOCOUNT ON   -- SQL 2005 Standard    
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF        
       
   CREATE TABLE #TMP_MNF
         (  Mbolkey                       NVARCHAR(10)
         ,  Vessel                        NVARCHAR(30)
         ,  Carrierkey                    NVARCHAR(10)
         ,  ArrivalDateFinaleDestination  DATETIME
         ,  DepartureDate                 DATETIME
         ,  Storerekey                    NVARCHAR(15)
         ,  CarrierAgent                  NVARCHAR(30)
         ,  PlaceOfDelivery               NVARCHAR(30)
         ,  PlaceOfDischarge              NVARCHAR(30)   
         ,  OtherReference                NVARCHAR(30)
         ,  DriverName                    NVARCHAR(30)
         ,  TransMethod                   NVARCHAR(30)
         ,  PlaceOfLoading                NVARCHAR(30)
         ,  Remarks                       NVARCHAR(255)      
         ,  Consigneekey                  NVARCHAR(40)   --WL01       
         ,  TotalTote                     INT
         ,  Company                       NVARCHAR(45)       
         ,  UserDefine05                  NVARCHAR(30)          
         ,  CopyDesc                      NVARCHAR(30) 
         )

   INSERT INTO #TMP_MNF
         (  Mbolkey                        
         ,  Vessel                         
         ,  Carrierkey                    
         ,  ArrivalDateFinaleDestination  
         ,  DepartureDate                 
         ,  Storerekey                    
         ,  CarrierAgent                   
         ,  PlaceOfDelivery                
         ,  PlaceOfDischarge                
         ,  OtherReference                 
         ,  DriverName                     
         ,  TransMethod                    
         ,  PlaceOfLoading                 
         ,  Remarks                        
         ,  Consigneekey                   
         ,  TotalTote                      
         ,  Company                        
         ,  UserDefine05                    
         ,  CopyDesc
         )  
   SELECT MBOL.mbolkey,      
          MBOL.vessel,     
          MBOL.carrierkey,      
          MBOL.ArrivalDateFinalDestination,      
          MBOL.Departuredate,       
          PD.StorerKey,         
          MBOL.CarrierAgent,        
          MBOL.PlaceOfDelivery,     
          MBOL.PlaceOfDischarge,    
          MBOL.OtherReference,      
          MBOL.DriverName,          
          MBOL.TransMethod,         
          MBOL.PlaceOfLoading,      
          CAST(MBOL.Remarks AS NVARCHAR(255)) AS Remarks,    
          Userdefine02 = ISNULL(RTRIM(PD.Userdefine02),''), --(Wan02)    
          --COUNT(DISTINCT PD.CaseId)  AS totaltote,    
          COUNT(DISTINCT PD.UserDefine05)  AS totaltote,    
          Company = ISNULL(RTRIM(SHIPTO.Company),'')        --(Wan02)
         ,ToteID = ISNULL(RTRIM(PD.UserDefine05),'')        --(Wan01)  
         ,Copydesc = 'STORE COPY'                           --(Wan02)
   FROM MBOL (NOLOCK) --JOIN MBOLDETAIL (NOLOCK) ON MBOL.mbolkey = MBOLDETAIL.mbolkey  -- (ChewKP01)  
   JOIN PALLETDETAIL PD (NOLOCK) ON MBOL.Mbolkey = PD.Userdefine03     
   LEFT JOIN STORER SHIPTO (NOLOCK) ON PD.Userdefine02 = SHIPTO.Storerkey    
   WHERE MBOL.mbolkey = @c_mbolkey    
   AND MBOL.PlaceOfLoadingQualifier = 'NS'    
   AND PD.Userdefine02 <> 'ECOM'    
   GROUP BY MBOL.mbolkey,      
            MBOL.vessel,     
            MBOL.carrierkey,      
            MBOL.ArrivalDateFinalDestination,      
            MBOL.Departuredate,       
            PD.StorerKey,         
            MBOL.CarrierAgent,        
            MBOL.PlaceOfDelivery,     
            MBOL.PlaceOfDischarge,    
            MBOL.OtherReference,      
            MBOL.DriverName,          
            MBOL.TransMethod,         
            MBOL.PlaceOfLoading,      
            CAST(MBOL.Remarks AS NVARCHAR(255)),    
            ISNULL(RTRIM(PD.Userdefine02),''),    
            ISNULL(RTRIM(SHIPTO.Company),'') 
         ,  ISNULL(RTRIM(PD.UserDefine05),'')               --(Wan01)  


   INSERT INTO #TMP_MNF
         (  Mbolkey                        
         ,  Vessel                         
         ,  Carrierkey                    
         ,  ArrivalDateFinaleDestination  
         ,  DepartureDate                 
         ,  Storerekey                    
         ,  CarrierAgent                   
         ,  PlaceOfDelivery                
         ,  PlaceOfDischarge                
         ,  OtherReference                 
         ,  DriverName                     
         ,  TransMethod                    
         ,  PlaceOfLoading                 
         ,  Remarks                        
         ,  Consigneekey                   
         ,  TotalTote                      
         ,  Company                        
         ,  UserDefine05                    
         ,  CopyDesc
         )  
   SELECT  MBOL.mbolkey       
         , MBOL.vessel     
         , MBOL.carrierkey      
         , MBOL.ArrivalDateFinalDestination      
         , MBOL.Departuredate      
         , PD.StorerKey        
         , MBOL.CarrierAgent        
         , MBOL.PlaceOfDelivery     
         , MBOL.PlaceOfDischarge     
         , MBOL.OtherReference       
         , MBOL.DriverName          
         , MBOL.TransMethod         
         , MBOL.PlaceOfLoading      
         , Remarks     = CAST(MBOL.Remarks AS NVARCHAR(255))    
         , Userdefine02= ISNULL(RTRIM(PD.Userdefine02),'')   
         , TotalTote   = COUNT(DISTINCT PD.UserDefine05)    
         , Company     = ISNULL(RTRIM(SHIPTO.Company),'')   
         , ToteID      = ISNULL(RTRIM(PD.UserDefine05),'')          
         , Copydesc    = 'DRIVER COPY'                           
   FROM MBOL (NOLOCK)  
   JOIN PALLETDETAIL PD (NOLOCK) ON MBOL.Mbolkey = PD.Userdefine03     
   LEFT JOIN STORER SHIPTO (NOLOCK) ON PD.Userdefine02 = SHIPTO.Storerkey    
   WHERE MBOL.mbolkey = @c_mbolkey    
   AND MBOL.PlaceOfLoadingQualifier = 'NS'    
   AND PD.Userdefine02 <> 'ECOM'    
   GROUP BY MBOL.mbolkey       
         ,  MBOL.vessel     
         ,  MBOL.carrierkey      
         ,  MBOL.ArrivalDateFinalDestination      
         ,  MBOL.Departuredate      
         ,  PD.StorerKey        
         ,  MBOL.CarrierAgent        
         ,  MBOL.PlaceOfDelivery     
         ,  MBOL.PlaceOfDischarge     
         ,  MBOL.OtherReference       
         ,  MBOL.DriverName          
         ,  MBOL.TransMethod         
         ,  MBOL.PlaceOfLoading       
         ,  CAST(MBOL.Remarks AS NVARCHAR(255))    
         ,  ISNULL(RTRIM(PD.Userdefine02),'')   
         ,  ISNULL(RTRIM(SHIPTO.Company),'')   
         ,  ISNULL(RTRIM(PD.UserDefine05),'')          
           
   SELECT   Mbolkey                        
         ,  Vessel                         
         ,  Carrierkey                    
         ,  ArrivalDateFinaleDestination  
         ,  DepartureDate                 
         ,  Storerekey                    
         ,  CarrierAgent                   
         ,  PlaceOfDelivery                
         ,  PlaceOfDischarge                
         ,  OtherReference                 
         ,  DriverName                     
         ,  TransMethod                    
         ,  PlaceOfLoading                 
         ,  Remarks                        
         ,  Consigneekey                   
         ,  TotalTote                      
         ,  Company                        
         ,  UserDefine05                    
         ,  CopyDesc 
   FROM #TMP_MNF
   ORDER BY CopyDesc
         ,  Consigneekey
              
 END      

SET QUOTED_IDENTIFIER OFF

GO
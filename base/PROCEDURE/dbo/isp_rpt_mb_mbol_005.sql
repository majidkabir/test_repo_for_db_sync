SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_RPT_MB_MBOL_005                                */        
/* CreatiON Date: 13-JUN-2023                                           */    
/* Copyright: Maersk                                                    */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-22767 (DU)                                              */      
/*                                                                      */        
/* Called By: RPT_MB_MBOL_005            									      */        
/*                                                                      */        
/* PVCS VersiON: 1.0                                                    */        
/*                                                                      */        
/* VersiON: 7.0                                                         */        
/*                                                                      */        
/* Data ModificatiONs:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 13-JUN-2023  WZPang   1.0  DevOps Combine Script                     */
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_MB_MBOL_005] (
      @c_Mbolkey NVARCHAR(10)    
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        

    SELECT  MBOL.MbolKey
         , MBOL.BookingReference
         , MBOL.Vessel
         , MBOL.PlaceOfLoadingQualifier
         , MBOL.PlaceOfDischarge
         , MBOL.ArrivalDateFinalDestination
         , MBOL.CarrierKey
         , MBOL.VoyageNumber
         , MBOL.ContainerNo
         , MBOL.Equipment
         , MBOL.PlaceOfLoading
         , ORDERS.ExternOrderKey
         , ORDERDETAIL.Lottable03
         , ORDERS.UserDefine09
         , PICKDETAIL.PickSlipNo
         , PICKDETAIL.ID
         , STORER.Company
         , CASE WHEN ISNULL(STT.RefNo,'') = '' THEN 'N' ELSE 'Y' END AS Scanned 
         --, (SELECT O.MBOLKey, PD.ID, STT.RefNo, CASE WHEN ISNULL(STT.RefNo,'') = '' THEN 'N' ELSE 'Y' END
         --   FROM dbo.ORDERS O WITH (NOLOCK)
         --   INNER JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         --   LEFT OUTER JOIN RDT.RDTSCANTOTRUCK STT (NOLOCK) ON STT.MBOLKey = O.MBOLKey AND STT.RefNo = PD.ID
         --   WHERE O.MBOLKey = @c_MBOLKey) AS Scanned      
   FROM MBOL (NOLOCK)
   JOIN MBOLDETAIL (NOLOCK) ON MBOL.MbolKey = MBOLDETAIL.MbolKey
   JOIN ORDERS (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey
   JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey         
   JOIN PICKDETAIL (NOLOCK) ON ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey 
   JOIN STORER (NOLOCK) ON ORDERS.StorerKey = STORER.StorerKey
   LEFT OUTER JOIN RDT.RDTSCANTOTRUCK STT (NOLOCK) ON STT.MBOLKey = ORDERS.MBOLKey AND STT.RefNo = PICKDETAIL.ID
   WHERE MBOL.MbolKey = @c_Mbolkey
   GROUP BY MBOL.MbolKey 
         , MBOL.BookingReference
         , MBOL.Vessel
         , MBOL.PlaceOfLoadingQualifier
         , MBOL.PlaceOfDischarge
         , MBOL.ArrivalDateFinalDestination
         , MBOL.CarrierKey
         , MBOL.VoyageNumber
         , MBOL.ContainerNo
         , MBOL.Equipment
         , MBOL.PlaceOfLoading
         , ORDERS.ExternOrderKey
         , ORDERDETAIL.Lottable03
         , ORDERS.UserDefine09
         , PICKDETAIL.PickSlipNo
         , PICKDETAIL.ID
         , STORER.Company
         , STT.RefNo
   

END -- procedure    

GO
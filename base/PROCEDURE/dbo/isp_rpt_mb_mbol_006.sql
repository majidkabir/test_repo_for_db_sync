SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_RPT_MB_MBOL_006                                */        
/* CreatiON Date: 24-JUL-2023                                           */    
/* Copyright: Maersk                                                    */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-23080 (RG)                                              */      
/*                                                                      */        
/* Called By: RPT_MB_MBOL_006                                           */        
/*                                                                      */        
/* PVCS VersiON: 1.0                                                    */        
/*                                                                      */        
/* VersiON: 7.0                                                         */        
/*                                                                      */        
/* Data ModificatiONs:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 24-JUL-2023  WZPang   1.0  DevOps Combine Script                     */
/* 09-Sep-2024  TianLei  1.1  UWP-24051 Global Timezone	(GTZ01)         */
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_MB_MBOL_006] (
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
         --, MBOL.PlaceOfLoading
         , MBOL.CarrierKey
         , MBOL.VoyageNumber
         , MBOL.ContainerNo
         , MBOL.Equipment
         , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, MBOL.ArrivalDateFinalDestination) AS ArrivalDateFinalDestination    --GTZ01
         , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, (SELECT MIN(RDT.rdtScanToTruck.AddDate)
                                                                          FROM RDT.rdtScanToTruck (NOLOCK)    
                                                                          WHERE MBOLKey = @c_Mbolkey)) AS LoadingDate    --GTZ01
         , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, (SELECT MAX(RDT.rdtScanToTruck.AddDate) 
                                                                                    FROM RDT.rdtScanToTruck (NOLOCK)    
                                                                                    WHERE MBOLKey = @c_Mbolkey)) AS SealDate    --GTZ01
         , ORDERS.ExternOrderKey
         , ORDERDETAIL.Lottable03
         , ORDERS.UserDefine09
         --, PICKDETAIL.PickSlipNo
         , PACKDETAIL.PickSlipNo
         --, (SELECT PAD.LabelNo
         --   FROM PACKDETAIL PAD (NOLOCK)
         --   JOIN PICKDETAIL PKD (NOLOCK) ON PAD.PickSlipNo = PKD.PickSlipNo
         --   JOIN ORDERS ORD (NOLOCK) ON PKD.OrderKey = ORD.OrderKey
         --   JOIN MBOLDETAIL MBOLD (NOLOCK) ON ORD.Orderkey = MBOLD.OrderKey
         --   WHERE MBOL.MbolKey = @c_Mbolkey) AS PalletID
         , PACKDETAIL.LabelNo AS PalletID
         , STORER.Company
         , CASE WHEN ISNULL(STT.URNNo,'') = '' THEN 'N' ELSE 'Y' END AS Scanned 
         , STT.Door
         , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, GETDATE()) AS CurrentDateTime
   FROM MBOL (NOLOCK)
   JOIN MBOLDETAIL (NOLOCK) ON MBOL.MbolKey = MBOLDETAIL.MbolKey
   JOIN ORDERS (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey
   JOIN ORDERDETAIL (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey
   JOIN PICKDETAIL (NOLOCK) ON MBOLDETAIL.OrderKey = PICKDETAIL.OrderKey
   JOIN STORER (NOLOCK) ON ORDERDETAIL.StorerKey = STORER.StorerKey
   JOIN PACKHEADER (NOLOCK) ON MBOLDETAIL.OrderKey = PACKHEADER.OrderKey
   JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo
   LEFT OUTER JOIN RDT.RDTSCANTOTRUCK STT (NOLOCK) ON STT.MBOLKey = ORDERS.MBOLKey AND STT.URNNo = PACKDETAIL.LabelNo
   WHERE MBOL.MbolKey = @c_Mbolkey
   GROUP BY MBOL.MbolKey
         , MBOL.BookingReference
         , MBOL.Vessel
         , MBOL.PlaceOfLoadingQualifier
         , MBOL.PlaceOfDischarge
         --, MBOL.PlaceOfLoading
         , MBOL.CarrierKey
         , MBOL.VoyageNumber
         , MBOL.ContainerNo
         , MBOL.Equipment
         , MBOL.ArrivalDateFinalDestination
         , ORDERS.ExternOrderKey
         , ORDERDETAIL.Lottable03
         , ORDERS.UserDefine09
         , ORDERS.StorerKey
         , ORDERS.Facility
         --, PICKDETAIL.PickSlipNo
         , PACKDETAIL.PickSlipNo
         , PACKDETAIL.LabelNo
         , STORER.Company
         , STT.URNNo
         , STT.Door

END -- procedure


GO
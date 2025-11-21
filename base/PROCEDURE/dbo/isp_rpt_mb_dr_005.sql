SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_RPT_MB_DR_005                                  */        
/* CreatiON Date: 04-OCT-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-20821 (ID)                                              */  
/*          WMS-23777 ID-PUMA-Update SP                                 */
/*                                                                      */        
/* Called By: RPT_MB_DR_005            									      */        
/*                                                                      */        
/* PVCS VersiON: 1.0                                                    */        
/*                                                                      */        
/* VersiON: 7.0                                                         */        
/*                                                                      */        
/* Data ModificatiONs:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 04-OCT-2022  WZPang   1.0  DevOps Combine Script                     */     
/* 29-SEP-2023  WZPang	 1.1  Add new columns (WZ01)  						*/
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_MB_DR_005] (
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
		, MAX(PD.ID) AS PalletID
		, OH.StorerKey
		, MBOL.CarrierAgent + '_'+ CL1.Description AS CarrierAgent  --WZ01
		, MBOL.Vessel
		, MBOL.DriverName
		, MBOL.ShipDate
		, ORDERinfo.EcomOrderId
		, ORDERinfo.Platform
		, OH.C_City
		, SUM(PACKHEADER.TTLCNTS) OVER (PARTITION BY MBOL.MbolKey) AS CTNs
		, DENSE_RANK() OVER (ORDER BY OH.ExternOrderKey) + DENSE_RANK() OVER (ORDER BY OH.ExternOrderKey DESC) - 1 AS OrdCount
		, (PACKHEADER.TTLCNTS) AS CTNsByOrder
		, SUM(OD.ShippedQty) AS QtyByOrder
	FROM MBOL 
	JOIN ORDERS OH ON MBOL.MbolKey = OH.MBOLKey
	JOIN ORDERDETAIL OD ON OH.OrderKey = OD.OrderKey
	JOIN PICKDETAIL PD ON OD.OrderKey = PD.OrderKey and OD.OrderLineNumber = PD.OrderLineNumber
	JOIN PACKHEADER  ON PACKHEADER.OrderKey = OH.OrderKey
	JOIN ORDERinfo ON OH.OrderKey = ORDERinfo.OrderKey 
   LEFT JOIN CODELKUP CL1 ON MBOL.Carrieragent = CL1.Code AND CL1.ListName='CARRIERAGT'   --WZ01
	CROSS APPLY (SELECT SUM(TTLCNTS) [CTNs] FROM PACKHEADER WHERE OrderKey = OH.OrderKey) ph
	WHERE MBOL.MbolKey = @c_Mbolkey
	
	GROUP BY
		MBOL.MbolKey
		, OH.StorerKey
		, MBOL.CarrierAgent
		, MBOL.Vessel
		, MBOL.DriverName
		, MBOL.ShipDate
		, OH.ExternOrderKey
		, ORDERinfo.EcomOrderId	
		, ORDERinfo.Platform
		, OH.C_City
		, PACKHEADER.TTLCNTS
      , CL1.Description
   

END -- procedure    

GO
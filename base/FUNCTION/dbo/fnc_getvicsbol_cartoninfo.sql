SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/  
/* Store procedure: fnc_GetVicsBOL_CartonInfo                           */  
/* Copyright      : IDS                                                 */  
/* FBR:                                                                 */  
/* Purpose: Report                                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* 29-Aug-2012  1.1  Shong01  Performance Tuning                        */  
/************************************************************************/  

CREATE   FUNCTION [dbo].[fnc_GetVicsBOL_CartonInfo] (@cMBOLKey NVARCHAR(10), @cConsigneeKey NVARCHAR(15))  
RETURNS @tVicsBOLCtnInfo TABLE   
(  
    MBOLKey          NVARCHAR(10)  NOT NULL,  
    TTLCTN           INT          NULL DEFAULT 0,  
    TTLWeight        REAL         NULL DEFAULT 0,  
    ExternConsoOrderkey    NVARCHAR(30)  NULL DEFAULT ''
 )  
AS  
BEGIN  
   DECLARE @tPack TABLE 
      (PickSlipNo NVARCHAR(10),
       LabelNo    NVARCHAR(20),
       CartonNo   INT,
       [WEIGHT]   REAL,
       [CUBE]     REAL,
       ExternConsoOrderkey NVARCHAR(30) NULL)
       
   DECLARE @cStorerkey NVARCHAR(15)
          ,@c_Svalue NVARCHAR(10)
   
   -- Shong01 - Replace MAX with TOP 1 
   SELECT TOP 1 @cStorerkey = O.Storerkey  
   FROM MBOLDETAIL MD (NOLOCK)  
   JOIN ORDERS O ON MD.Orderkey = O.Orderkey  
   WHERE MD.Mbolkey = @cMBOLKEY  
   AND O.Consigneekey = @cConsigneekey  
   ORDER BY O.Storerkey DESC
   
   SELECT @c_Svalue = Svalue
   FROM STORERCONFIG (NOLOCK)
   WHERE Storerkey = @cStorerkey
   AND Configkey = 'MASTERPACK'
             	
   IF EXISTS(SELECT 1 FROM ORDERDETAIL o WITH (NOLOCK) WHERE o.MBOLKey = @cMBOLKey 
             AND o.ConsoOrderKey IS NOT NULL AND o.ConsoOrderKey <> '')
   BEGIN      	     	     	
     INSERT INTO @tPack (PickSlipNo, LabelNo, CartonNo, [WEIGHT], [CUBE], ExternConsoOrderkey)
	   SELECT DISTINCT P.PickSlipNo, 
      	             CASE WHEN ISNULL(PD.Refno,'') <> '' AND ISNULL(PD.Refno2,'') <> '' AND @c_Svalue = '1' THEN
	                       PD.Refno2 ELSE PD.LabelNo END,
               PD.CartonNo,0, 0, OD.ExternConsoOrderkey
	   FROM   PICKDETAIL p WITH (NOLOCK) 
	   JOIN   ORDERS O WITH (NOLOCK) ON P.OrderKey = O.OrderKey 
	   JOIN   PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = P.PickSlipNo 
	                           AND PD.DropID = P.DropID
	   JOIN  PACKHEADER PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
     JOIN  MBOLDETAIL MD WITH (NOLOCK) ON MD.OrderKey = P.OrderKey 
-- Shong01 Comment and Replace with different Link 
--    JOIN  ORDERDETAIL OD WITH (NOLOCK) ON PH.ConsoOrderkey = OD.ConsoOrderkey   
--                                        AND PD.Storerkey = OD.Storerkey  
--                                        AND PD.Sku = OD.Sku   
    JOIN  ORDERDETAIL OD WITH (NOLOCK) ON P.OrderKey = OD.OrderKey   
                                        AND P.OrderLineNumber = OD.OrderLineNumber  
	   WHERE MD.MbolKey = @cMBOLKey
	   AND   O.ConsigneeKey = @cConsigneeKey
   	 
	   UPDATE TP 
	      SET [WEIGHT]  = ISNULL(pi1.[Weight],0), 
	          TP.[CUBE] = ISNULL(CASE WHEN pi1.[CUBE] < 1.00 THEN 1.00 ELSE pi1.[CUBE] END, 0)
	   FROM @tPack TP
	   JOIN PackInfo pi1 WITH (NOLOCK) ON pi1.PickSlipNo = TP.PickSlipNo AND pi1.CartonNo = TP.CartonNo
   	 
	   IF EXISTS(SELECT 1 FROM @tPack WHERE [WEIGHT]=0)
	   BEGIN
	      UPDATE TP 
	         SET TP.[WEIGHT]  = TWeight.[WEIGHT], 
	             TP.[CUBE] = CASE WHEN TP.[CUBE] < 1.00 THEN 1.00 ELSE TP.[CUBE] END   
	      FROM @tPack TP
	      JOIN (SELECT PD.PickSlipNo, PD.CartonNo, SUM(ISNULL(S.STDGROSSWGT,0) * PD.Qty) AS [WEIGHT]  
	            FROM PACKDETAIL PD WITH (NOLOCK) 
	            JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU 
	            JOIN @tPack TP2 ON TP2.PickSlipNo = PD.PickSlipNo AND TP2.CartonNo = PD.CartonNo 
	            GROUP BY PD.PickSlipNo, PD.CartonNo) AS TWeight ON TP.PickSlipNo = TWeight.PickSlipNo  
	                     AND TP.CartonNo = TWeight.CartonNo 
	      WHERE TP.[WEIGHT] = 0   		           
	   END

     INSERT @tVicsBOLCtnInfo (MBOLKey, TTLCTN, TTLWeight, ExternConsoOrderkey) 
     SELECT @cMBOLKey AS MBOLKEY, COUNT(DISTINCT LabelNo) AS CtnCnts, SUM(ISNULL(WEIGHT,0)) AS Weight, 
            ExternConsoOrderkey
     FROM @tPack 	
     GROUP BY ExternConsoOrderkey
   END
   ELSE
   BEGIN
       INSERT @tVicsBOLCtnInfo (MBOLKey, TTLCTN, TTLWeight, ExternConsoOrderkey) 
       SELECT MBOLDET.MBOLKEY AS MBLKey, SUM(MBOLDET.TotalCartons) AS TTLCTN ,
               SUM(ISNULL(MBOLDET.Weight,0)) AS TTLWeight,
               ''
        FROM MBOLDETAIL MBOLDET WITH (NOLOCK)
        JOIN ORDERS ORD WITH (NOLOCK) ON (ORD.OrderKey = MBOLDET.OrderKey)
        WHERE MBOLDET.MBOLKEY = @cMBOLKey 
        AND ORD.Consigneekey  = @cConsigneeKey
        GROUP BY MBOLDET.MBOLKEY, ORD.ConsigneeKey    	
   END
         	    
   RETURN  
END

GO
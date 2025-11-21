SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: fnc_GetVicsCBOL_CartonInfo                          */  
/* Copyright      : IDS                                                 */  
/* FBR:                                                                 */  
/* Purpose: Report                                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* 02-Sep-2012  1.1  Shong01  Performance Tuning                        */  
/************************************************************************/  
CREATE FUNCTION [dbo].[fnc_GetVicsCBOL_CartonInfo] (@nCBOLKey BIGINT)    
RETURNS @tVicsCBOLCtnInfo TABLE     
(    
    CBOLKey          BIGINT       NOT NULL,    
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
          ,@c_Svalue   NVARCHAR(10)  
   
   -- Shong01 Performance Tuning  
   SELECT TOP 1  @cStorerkey = O.Storerkey  
   FROM MBOL MB WITH (NOLOCK)   
   JOIN MBOLDETAIL MD WITH (NOLOCK) ON MB.Mbolkey = MD.Mbolkey  
   JOIN ORDERS O WITH (NOLOCK) ON MD.Orderkey = O.Orderkey  
   WHERE MB.Cbolkey = @nCBOLKEY  
   AND ISNULL(MB.CBOLKEY,0) <> 0  
   ORDER BY Storerkey DESC
     
   SELECT @c_Svalue = Svalue  
   FROM STORERCONFIG (NOLOCK)  
   WHERE Storerkey = @cStorerkey  
   AND Configkey = 'MASTERPACK'  
                
   IF EXISTS(SELECT 1 FROM MBOL MB (NOLOCK)   
             JOIN MBOLDETAIL MD (NOLOCK) ON MB.Mbolkey = MD.Mbolkey  
             JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
             JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey   
             WHERE MB.CBOLKey = @nCBOLKey   
             AND ISNULL(MB.Cbolkey,0) <> 0  
             AND ISNULL(OD.ConsoOrderKey,'') <> '')  
   BEGIN                     
     INSERT INTO @tPack (PickSlipNo, LabelNo, CartonNo, [WEIGHT], [CUBE], ExternConsoOrderkey)  
     SELECT DISTINCT P.PickSlipNo,   
                    CASE WHEN ISNULL(PD.Refno,'') <> '' AND ISNULL(PD.Refno2,'') <> '' AND @c_Svalue = '1' THEN  
                        PD.Refno2 ELSE PD.LabelNo END,  
               PD.CartonNo,0, 0, OD.ExternConsoOrderkey  
    FROM   PICKDETAIL p WITH (NOLOCK)   
    JOIN   PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = P.PickSlipNo   
                            AND PD.DropID = P.DropID  
    JOIN  PACKHEADER PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno  
    JOIN  MBOLDETAIL MD WITH (NOLOCK) ON MD.OrderKey = P.OrderKey   
    JOIN  MBOL MB WITH (NOLOCK) ON MD.Mbolkey = MB.Mbolkey  
--     JOIN  ORDERDETAIL OD WITH (NOLOCK) ON PH.ConsoOrderkey = OD.ConsoOrderkey   
--                                        AND PD.Storerkey = OD.Storerkey  
--                                        AND PD.Sku = OD.Sku   
    JOIN  ORDERDETAIL OD WITH (NOLOCK) ON P.OrderKey = OD.OrderKey   
                                        AND P.OrderLineNumber = OD.OrderLineNumber
    WHERE MB.cbolKey = @nCBOLKey  
       
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
  
     INSERT @tVicsCBOLCtnInfo (CBOLKey, TTLCTN, TTLWeight, ExternConsoOrderkey)   
     SELECT @nCBOLKey, COUNT(DISTINCT LabelNo) AS CtnCnts, SUM(ISNULL(WEIGHT,0)) AS Weight,   
            ExternConsoOrderkey  
     FROM @tPack    
     GROUP BY ExternConsoOrderkey  
   END  
   ELSE  
   BEGIN  
       INSERT @tVicsCBOLCtnInfo (CBOLKey, TTLCTN, TTLWeight, ExternConsoOrderkey)   
       SELECT MB.CBOLKEY, SUM(MBOLDET.TotalCartons) AS TTLCTN ,  
               SUM(ISNULL(MBOLDET.Weight,0)) AS TTLWeight,  
               ''  
        FROM MBOL MB WITH (NOLOCK)  
        JOIN MBOLDETAIL MBOLDET WITH (NOLOCK) ON (MB.Mbolkey = MBOLDET.Mbolkey)  
        WHERE MB.CBOLKEY = @nCBOLKey   
        AND ISNULL(MB.CBOLKEY,0) <> 0  
        GROUP BY MB.CBOLKEY  
   END  
                
   RETURN    
END  

GO
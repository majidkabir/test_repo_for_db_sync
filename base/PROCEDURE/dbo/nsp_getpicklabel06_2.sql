SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Proc : nsp_GetPicklabel06_2                                       */  
/* Creation Date:                                                          */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: WMS-1066-UNITY - To migrate Picklabel from Hyperion to EXCEED  */  
/*                                                                         */  
/*                                                                         */  
/* Usage:                                                                  */  
/*                                                                         */  
/* Local Variables:                                                        */  
/*                                                                         */  
/* Called By: r_dw_picklabel_06_2 (Zone label01)                           */  
/*                                                                         */  
/* PVCS Version: 1.1                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author      Ver   Purposes                                  */  
/***************************************************************************/  
  
CREATE PROC [dbo].[nsp_GetPicklabel06_2] (@c_wavekey NVARCHAR(10))  
AS  
BEGIN  
    SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   -- Added by YokeBeen on 30-Jul-2004 (SOS#25474) - (YokeBeen01)  
   -- Added SKU.SUSR3 (Agency) & ORDERS.InvoiceNo.  
     
   DECLARE @n_starttcnt INT  
  
   SELECT PDET2.SKU, COUNT(DISTINCT PDET2.CASEID) FullCaseLabel  
   INTO #Temp_ZoneLabelA  
 FROM PICKDETAIL PDET2 WITH (NOLOCK)   
 WHERE PDET2.STORERKEY = 'UNI'   
 AND PDET2.WAVEKEY = @c_wavekey  
 AND ISNULL(PDET2.CASEID, '') > '0'  
GROUP BY PDET2.SKU  
  
SELECT PDET.DropID,   
    L.PutawayZone,   
    PDET.Sku,   
    S.DESCR,   
    SUM (PDET.Qty) Qty,   
    P.CaseCnt,   
    P.InnerPack,   
    P.Qty PQty,   
    WVDET.WaveKey,   
    WVDET.EditWho,   
    S.BUSR6,   
    L1.LocationCategory,   
    L1.LocLevel,   
    L1.LocAisle,   
    L1.Loc,   
    L1.LogicalLocation,   
    SUBSTRING(S.DESCR, 1, (CHARINDEX(' ', S.DESCR + ' ') -1)) SKUDescr_FirstWord,   
    PDET.PickSlipNo,   
    PDET.Storerkey,  
  
    CS =  (CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END),  
    Q1 =  SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt),  
  
    IN_Computed = ( CASE WHEN (SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) > 0   
       THEN (CASE WHEN P.InnerPack > 0 THEN FLOOR ((SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) / P.InnerPack) ELSE 0 END)   
        ELSE 0 END ),  
  
    Q2 =   SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt) -    
     ( ( CASE WHEN (SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) > 0   
       THEN (CASE WHEN P.InnerPack > 0 THEN FLOOR ((SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) / P.InnerPack) ELSE 0 END)   
        ELSE 0 END ) * P.InnerPack ),  
    
  PC = (CASE WHEN (SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt) -    
     ( ( CASE WHEN (SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) > 0   
       THEN (CASE WHEN P.InnerPack > 0 THEN FLOOR ((SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) / P.InnerPack) ELSE 0 END)   
        ELSE 0 END ) * P.InnerPack )) > 0   
     THEN SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt) -    
       ( ( CASE WHEN (SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) > 0   
       THEN (CASE WHEN P.InnerPack > 0 THEN FLOOR ((SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) / P.InnerPack) ELSE 0 END)   
        ELSE 0 END ) * P.InnerPack )   
     ELSE 0 END),  
  PTL_Zone = Right(L.PutawayZone, Len(L.PutawayZone) - 3),  
  TotalQty = CONVERT(VARCHAR, (CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END))  
             + '/' + CONVERT(VARCHAR, ( CASE WHEN (SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) > 0   
       THEN (CASE WHEN P.InnerPack > 0 THEN FLOOR ((SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) / P.InnerPack) ELSE 0 END)   
        ELSE 0 END ))  
     + '/' + CONVERT(VARCHAR, (CASE WHEN (SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt) -    
     ( ( CASE WHEN (SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) > 0   
       THEN (CASE WHEN P.InnerPack > 0 THEN FLOOR ((SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) / P.InnerPack) ELSE 0 END)   
        ELSE 0 END ) * P.InnerPack )) > 0   
     THEN SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt) -    
       ( ( CASE WHEN (SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) > 0   
       THEN (CASE WHEN P.InnerPack > 0 THEN FLOOR ((SUM(PDET.Qty) - ((CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(PDET.Qty) / P.CaseCnt) ELSE 0 END) * P.CaseCnt)) / P.InnerPack) ELSE 0 END)   
        ELSE 0 END ) * P.InnerPack )   
     ELSE 0 END)),  
   PackSize = CONVERT(VARCHAR, P.CaseCnt) + '/' + CONVERT(VARCHAR, P.InnerPack),  
    CASE WHEN UPPER(L1.LocationCategory) = 'RACK' AND L1.LocLevel = '1' THEN 'LOW'   
            WHEN (UPPER(L1.Locationcategory) = UPPER('Shelving' ) AND Substring(PDET.Loc,1,2) = 'B7' AND L1.LocLevel < 4) THEN 'LOW'  
               WHEN (UPPER(L1.LocationCategory) = UPPER('Shelving') AND (Substring(PDET.Loc,1,2) = 'B8' ) AND (L1.LocLevel <  3 ) ) THEN 'LOW'   
    ELSE 'HIGH'    
       END AS BayLevel,  
  
    Srt = L1.LocAisle + '-' + (CASE WHEN UPPER(L1.LocationCategory) = 'RACK' AND L1.LocLevel = '1' THEN 'LOW'   
            WHEN (UPPER(L1.Locationcategory) = UPPER('Shelving' ) AND Substring(PDET.Loc,1,2) = 'B7' AND L1.LocLevel < 4) THEN 'LOW'  
               WHEN (UPPER(L1.LocationCategory) = UPPER('Shelving') AND (Substring(PDET.Loc,1,2) = 'B8' ) AND (L1.LocLevel <  3 ) ) THEN 'LOW'   
    ELSE 'HIGH'    
       END)  
  
INTO #Temp_ZoneLabel    
FROM WAVEDETAIL WVDET WITH (NOLOCK)  
JOIN ORDERS ORD WITH (NOLOCK) ON WVDET.OrderKey = ORD.OrderKey  
JOIN PICKDETAIL PDET WITH (NOLOCK) ON ORD.OrderKey = PDET.OrderKey   
JOIN StoreToLocDetail STLD WITH (NOLOCK) ON ORD.ConsigneeKey = STLD.ConsigneeKey  
JOIN LOC L WITH (NOLOCK) ON STLD.LOC = L.Loc  
JOIN SKU S WITH (NOLOCK) ON PDET.Storerkey = S.StorerKey AND S.Sku = PDET.Sku  
JOIN PACK P WITH (NOLOCK) ON S.PACKKey = P.PackKey  
JOIN LOC L1 WITH (NOLOCK) ON PDET.Loc = L1.Loc  
WHERE (WVDET.WaveKey = @c_wavekey)  
GROUP BY PDET.DropID,   
    L.PutawayZone,   
    PDET.Sku,   
    S.DESCR,   
    P.CaseCnt,   
    P.InnerPack,   
    P.Qty,   
    WVDET.WaveKey,   
    WVDET.EditWho,   
    S.BUSR6,   
    L1.LocationCategory,   
    L1.LocLevel,   
    L1.LocAisle,   
    L1.Loc,   
    L1.LogicalLocation,   
    SUBSTRING(S.DESCR, 1, (CHARINDEX(' ', S.DESCR + ' ') -1)),   
    PDET.PickSlipNo,   
    PDET.Storerkey,  
    PDET.WaveKey,  
    PDET.Loc  
HAVING (SELECT count(distinct PDET1.loc)   
    FROM PICKDETAIL PDET1 WITH (NOLOCK)   
    WHERE PDET1.StorerKey = PDET.StorerKey  
    AND   PDET1.WaveKey = PDET.WaveKey  
    AND   PDET1.SKU = PDET.SKU  
    GROUP BY PDET1.Storerkey, PDET1.Sku, PDET1.WaveKey) = 1  
  
SELECT A.*, ISNULL(B.FullCaseLabel, 0) FullCaseLabel  FROM  #Temp_ZoneLabel A LEFT OUTER JOIN #Temp_ZoneLabelA B ON B.SKU = A.SKU  
  
DROP TABLE #Temp_ZoneLabeL  
DROP TABLE #Temp_ZoneLabelA  
  
   WHILE @@TRANCOUNT < @n_starttcnt  
   BEGIN  
      BEGIN TRAN  
   END  
END  

GO
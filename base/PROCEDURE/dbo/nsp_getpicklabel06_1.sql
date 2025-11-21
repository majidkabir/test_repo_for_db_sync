SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Proc : nsp_GetPicklabel06_1                                      */  
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
/* Called By: r_dw_picklabel_06_1 (full caselabel)                         */  
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
  
CREATE PROC [dbo].[nsp_GetPicklabel06_1] (@c_wavekey NVARCHAR(10))  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   -- Added by YokeBeen on 30-Jul-2004 (SOS#25474) - (YokeBeen01)  
   -- Added SKU.SUSR3 (Agency) & ORDERS.InvoiceNo.  
     
   DECLARE @n_starttcnt INT  
  
      SELECT row_number() OVER (ORDER BY ORD.ConsigneeKey + PDET.Sku) rownum,  
    DropID = PDET.DropID,   
    PutawayZone = L.PutawayZone,   
    Sku= PDET.Sku,   
    DESCR = S.DESCR,   
    SUM (PDET.Qty) Qty,   
    CaseCnt=P.CaseCnt,   
    InnerPack=P.InnerPack,   
    P.Qty PQty,   
    WaveKey = WVDET.WaveKey,   
    EditWho = WVDET.EditWho,   
    CaseID=PDET.CaseID,   
    Store = ORD.ConsigneeKey,   
    [Route]=STRSODef.Route,   
    LEFT( S.BUSR7, 1) BUSR7,   
    LocationCategory=L1.LocationCategory,   
    LocLevel=L1.LocLevel,   
    LocAisle=L1.LocAisle,   
    STLD.LOC STLD_Loc,   
    Loc = PDET.Loc,  
      
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
       END),  
    Serial_No_C = 1,  
    StoreSKU = ORD.ConsigneeKey + PDET.Sku  
 INTO #TempFullCase     
FROM WAVEDETAIL WVDET WITH (NOLOCK)  
     JOIN ORDERS ORD WITH (NOLOCK) ON  WVDET.OrderKey = ORD.OrderKey  
     JOIN PICKDETAIL PDET WITH (NOLOCK) ON ORD.OrderKey = PDET.OrderKey  
     JOIN StoreToLocDetail STLD WITH (NOLOCK) ON ORD.ConsigneeKey = STLD.ConsigneeKey   
     JOIN LOC L WITH (NOLOCK) ON STLD.LOC = L.Loc  
     JOIN SKU S WITH (NOLOCK) ON PDET.Storerkey = S.StorerKey AND S.Sku = PDET.Sku  
     JOIN PACK P WITH (NOLOCK) ON S.PACKKey = P.PackKey  
     JOIN LOC L1 WITH (NOLOCK)  ON PDET.Loc = L1.Loc  
   LEFT OUTER JOIN StorerSODefault STRSODef ON (STRSODef.StorerKey = ORD.ConsigneeKey)   
WHERE WVDET.WaveKey = @c_wavekey AND PDET.CaseID > '0'   
GROUP BY PDET.DropID, L.PutawayZone, PDET.Sku, S.DESCR, P.CaseCnt, P.InnerPack,   
   P.Qty, WVDET.WaveKey, WVDET.EditWho, PDET.CaseID,   
   ORD.ConsigneeKey, STRSODef.Route, LEFT( S.BUSR7, 1),   
   L1.LocationCategory, L1.LocLevel, L1.LocAisle, STLD.LOC, PDET.Loc  
     
     
     
  
Select A.DropID, A.PutAwayZone, A.SKU, A.Descr, A.Qty, A.CaseCnt, A.InnerPack, A.PQty, A.WaveKey,  
    A.EditWho, A.Store, A.CaseID, A.Route, A.BUSR7, A.LocationCategory, A.LocLevel, A.LocAisle,   
    A.STLD_Loc, A.Loc, A.CS, A.Q1, A.In_Computed, A.Q2, A.PC, A.PTL_Zone, A.TotalQty, A.PackSize, A.BayLevel,  
    A.Srt, A.StoreSKU, A.Serial_No_C, SUM(B.Serial_No_C) AS [Cumulative_Sum],  
    Total_Cases = SUM(A.Serial_No_C) OVER (PARTITION BY A.StoreSKU ORDER BY A.StoreSKU),  
    n_of_n_Cases =  convert(varchar, SUM(B.Serial_No_C)) + ' of ' + convert(varchar, SUM(A.Serial_No_C) OVER (PARTITION BY A.StoreSKU ORDER BY A.StoreSKU))  
From #TempFullCase A  
Inner Join #TempFullCase B ON B.StoreSKU = A.StoreSKU AND B.rownum <= A.rownum  
GROUP BY A.DropID, A.PutAwayZone, A.SKU, A.Descr, A.Qty, A.CaseCnt, A.InnerPack, A.PQty, A.WaveKey,  
    A.EditWho, A.Store, A.CaseID, A.Route, A.BUSR7, A.LocationCategory, A.LocLevel, A.LocAisle,   
    A.STLD_Loc, A.Loc, A.CS, A.Q1, A.In_Computed, A.Q2, A.PC, A.PTL_Zone, A.TotalQty, A.PackSize, A.BayLevel,  
    A.Srt, A.StoreSKU, A.Serial_No_C  
      
   DROP TABLE #TempFullCase  
  
   WHILE @@TRANCOUNT < @n_starttcnt  
   BEGIN  
      BEGIN TRAN  
   END  
END  

GO
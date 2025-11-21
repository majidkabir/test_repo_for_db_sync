SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_ReplenishLetdown_rpt08                              */  
/* Creation Date: 24-AUG-2017                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-1860 - Backend Alloc And Replenishment                  */  
/*        : Replenishment LetDown Report For Single Mode Task Batch     */  
/* Called By:                                                           */  
/*          :                                                           */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 29-SEP-2017 Wan01    1.1   Enhancement.Exclude Empty ReplenishmentGroup*/  
/* 26-OCT-2017 Wan02    1.2   Multiple Loadkey Pass in                  */  
/* 31-OCT-2017 Wan03    1.3   Change Request on Report layout           */  
/************************************************************************/  
CREATE PROC [dbo].[isp_ReplenishLetdown_rpt08]  
           @c_Facility     NVARCHAR(5)  
         , @c_Loadkey      NVARCHAR(1000)       --(Wan02)  
         , @c_BatchNoList  NVARCHAR(4000)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt          INT  
         , @n_Continue           INT   
  
         , @c_ReplenGrpList      NVARCHAR(1000)  
  
         , @n_TotalLoc           INT         --(Wan03)  
         , @n_TotalQtyReplenInCS FLOAT       --(Wan03)  
         , @n_TotalQtyReplenInEA FLOAT       --(Wan03)  
         , @n_TotalFullCasePICK  FLOAT       --(Wan03)  
  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   CREATE TABLE #TMP_TASKBATCHNO   
      (  
         TaskBatchNo NVARCHAR(10)   PRIMARY KEY  
      )   
  
   CREATE TABLE #TMP_REPLENGRP   
      (  
         ReplenishmentGroup NVARCHAR(10) PRIMARY KEY  
      )   
  
   CREATE TABLE #TMP_REPLENRPT  
     (   RowRef      INT   IDENTITY(1,1) PRIMARY KEY  
      ,  Storerkey   NVARCHAR(15)  
      ,  Sku         NVARCHAR(20)  
      ,  AltSku      NVARCHAR(20)  
      ,  FromLoc     NVARCHAR(10)  
      ,  ToLoc       NVARCHAR(10)  
      ,  ID          NVARCHAR(18)  
      ,  Packkey     NVARCHAR(10)  
      ,  CaseCnt     FLOAT  
      ,  UOM         NVARCHAR(10)  
      ,  Qty         INT  
      ,  QtyAvail    INT  
      ,  QtyPick     INT  
      ,  QtyReplen   INT  
      )  
  
   --(Wan02) - START  
   CREATE TABLE #TMP_LOADKEY   
      (  
         Loadkey NVARCHAR(10)   PRIMARY KEY  
      )   
   --(Wan02) - END  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   --IF ISNULL(RTRIM(@c_BatchNoList), '') <> ''       --(Wan01)  
   IF CHARINDEX( '|', @c_BatchNoList) > 0             --(Wan01)  
   BEGIN          
      INSERT INTO #TMP_TASKBATCHNO (TaskBatchNo)  
      SELECT DISTINCT ColValue   
      FROM [dbo].[fnc_DelimSplit]('|', @c_BatchNoList)  
   END  
   ELSE   
   BEGIN   
      INSERT INTO #TMP_TASKBATCHNO (TaskBatchNo)  
      VALUES (@c_BatchNoList)  
   END  
  
   --(Wan02) - START  
   IF CHARINDEX( '|', @c_Loadkey) > 0                
   BEGIN          
      INSERT INTO #TMP_LOADKEY (LoadKey)  
      SELECT DISTINCT ColValue   
      FROM [dbo].[fnc_DelimSplit]('|', @c_Loadkey)  
  
      SET @c_Loadkey = STUFF((SELECT ',' + RTRIM(LoadKey) FROM #TMP_LOADKEY ORDER BY Loadkey   
                              FOR XML PATH('')),1,1,'' )  
   END  
   --(Wan02) - END  
  
  
   INSERT INTO #TMP_REPLENRPT  
      (  Storerkey  
      ,  Sku  
      ,  AltSku  
      ,  FromLoc  
      ,  ToLoc  
      ,  ID  
      ,  UOM  
      ,  Packkey  
      ,  CaseCnt  
      ,  Qty   
      ,  QtyAvail  
      ,  QtyPick  
      ,  QtyReplen  
      )  
   SELECT PD.Storerkey  
         ,PD.Sku  
         ,Altsku = ISNULL(RTRIM(SKU.AltSku),'')  
         ,PD.Loc  
         ,ToLoc = 'PACK'  
         ,PD.ID  
         ,PD.UOM  
         ,PACK.Packkey  
         ,PACK.CaseCnt  
         ,Qty      = 0  
         ,QtyAvail = 0  
         ,QtyPick  = SUM(PD.Qty)  
         ,QtyReplen= 0  
   FROM #TMP_TASKBATCHNO TB  
   JOIN PACKTASK PT WITH (NOLOCK) ON (TB.TaskBatchNo = PT.TaskBatchNo)  
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (PT.Orderkey = PD.Orderkey)  
   JOIN SKU  SKU  WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)  
                                AND(PD.Sku = SKU.Sku)  
   JOIN PACK PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)  
   WHERE PD.UOM IN ('1', '2')  
   AND PD.Status < '5'  
   GROUP BY PD.Storerkey  
         ,  PD.Sku  
         ,  ISNULL(RTRIM(SKU.AltSku),'')  
         ,  PD.Loc  
         ,  PD.ID  
         ,  PD.UOM  
         ,  PACK.Packkey  
         ,  PACK.CaseCnt  
  
   INSERT INTO #TMP_REPLENGRP (ReplenishmentGroup)  
   SELECT DISTINCT ISNULL(RTRIM(ReplenishmentGroup),'')  
   FROM #TMP_TASKBATCHNO TB  
   JOIN PACKTASK PT WITH (NOLOCK) ON (TB.TaskBatchNo = PT.TaskBatchNo)  
   JOIN ORDERS  ORD WITH(NOLOCK) ON (PT.Orderkey = ORD.Orderkey)  
   WHERE ISNULL(RTRIM(ORD.Loadkey),'') <> ''     --WWANG01  
   AND   ISNULL(RTRIM(PT.ReplenishmentGroup),'') <> ''                  --Exclude Empty ReplenishmentGroup   
  
   INSERT INTO #TMP_REPLENRPT  
      (  Storerkey  
      ,  Sku  
      ,  AltSku  
      ,  FromLoc  
      ,  ToLoc  
      ,  ID  
      ,  UOM  
      ,  Packkey  
      ,  CaseCnt  
      ,  Qty   
      ,  QtyAvail  
      ,  QtyPick  
      ,  QtyReplen  
      )  
   SELECT RP.Storerkey  
         ,RP.Sku  
         ,AltSku = ISNULL(RTRIM(SKU.AltSku),'')  
         ,RP.FromLoc  
         ,RP.ToLoc    
         ,RP.ID  
         ,RP.UOM  
         ,PACK.Packkey  
         ,PACK.CaseCnt  
         ,Qty      = 0   
         ,QtyAvail = 0   
         ,QtyPick  = 0  
         ,QtyReplen= SUM(RP.Qty)  
   FROM #TMP_REPLENGRP TRG  
   JOIN REPLENISHMENT  RP WITH (NOLOCK) ON (RP.ReplenishmentGroup = TRG.ReplenishmentGroup)  
   JOIN SKU  SKU       WITH (NOLOCK) ON (RP.Storerkey = SKU.Storerkey)  
                                     AND(RP.Sku = SKU.Sku)  
   JOIN PACK PACK      WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)  
   WHERE RP.Confirmed IN('N','Y') --WWANG01  
   GROUP BY RP.Storerkey  
         ,  RP.Sku  
         ,  ISNULL(RTRIM(SKU.AltSku),'')  
         ,  RP.FromLoc  
         ,  RP.ToLoc    
         ,  RP.ID  
         ,  RP.UOM  
         ,  PACK.Packkey  
         ,  PACK.CaseCnt;  
  
  
   WITH   
   INV( Storerkey, Sku, Loc, ID, Qty, QtyAvail )  
   AS (  SELECT  LLI.Storerkey  
               , LLI.Sku  
               , LLI.Loc  
               , LLI.ID  
               , Qty      = ISNULL(SUM(LLI.Qty),0)  
               , QtyAvail = ISNULL(SUM(LLI.Qty - LLI.QtyAllocated- LLI.QtyPicked),0)  
         FROM  LOTxLOCxID LLI WITH (NOLOCK)   
         WHERE EXISTS ( SELECT 1 FROM #TMP_REPLENRPT TMP   
                        WHERE TMP.Storerkey = LLI.Storerkey  
                        AND   TMP.Sku = LLI.Sku  
                        AND   TMP.FromLoc = LLI.Loc  
                        AND   TMP.ID = LLI.ID )  
         GROUP BY LLI.Storerkey  
               ,  LLI.Sku  
               ,  LLI.Loc  
               ,  LLI.ID  
      )  
   ,  
   ALLOC( Storerkey, Sku, Loc, ID, QtyAlloc)  
   AS (  SELECT  TMP.Storerkey  
               , TMP.Sku  
               , TMP.FromLoc  
               , TMP.ID  
               , QtyAlloc = ISNULL(SUM(TMP.QtyPick),0)  
         FROM  #TMP_REPLENRPT TMP   
         WHERE TMP.QtyPick > 0  
     GROUP BY TMP.Storerkey  
               ,  TMP.Sku  
               ,  TMP.FromLoc  
               ,  TMP.ID  
      )  
  
   UPDATE RPT  
   SET Qty      = INV.Qty           --(Wan03) INV.QtyAvail + ISNULL(QtyAlloc,0)         --(Wan01) - Fixed  
      ,QtyAvail = INV.QtyAvail  
   FROM #TMP_REPLENRPT RPT  
   JOIN INV ON (RPT.Storerkey = INV.Storerkey)  
            AND(RPT.Sku       = INV.Sku)  
            AND(RPT.FromLoc   = INV.Loc)  
            AND(RPT.ID        = INV.ID)  
   LEFT JOIN ALLOC   ON (RPT.Storerkey = ALLOC.Storerkey)   --(Wan01) - Fixed to use left outer join  
                     AND(RPT.Sku       = ALLOC.Sku)  
                     AND(RPT.FromLoc   = ALLOC.Loc)  
                     AND(RPT.ID        = ALLOC.ID)  
  
QUIT_SP:  
  
   SET @c_BatchNoList   = STUFF((SELECT ',' + RTRIM(Taskbatchno) FROM #TMP_TASKBATCHNO    
                                 ORDER BY Taskbatchno  
                                 FOR XML PATH('')),1,1,'' )  
   SET @c_ReplenGrpList = STUFF((SELECT ',' + RTRIM(ReplenishmentGroup) FROM #TMP_REPLENGRP    
                                 ORDER BY RTRIM(ReplenishmentGroup)  
                                 FOR XML PATH('')),1,1,'' )  
  
   IF LEFT(@c_ReplenGrpList,1) = ','  
   BEGIN  
      SET @c_ReplenGrpList = STUFF(@c_ReplenGrpList,1,1,'')  
   END  
          
   SELECT Facility      = @c_Facility                          --(Wan03)  
      ,  Loadkey        = @c_Loadkey                           --(Wan03)  
      ,  BatchNoList    = @c_BatchNoList                       --(Wan03)  
      ,  ReplenGrpList  = @c_ReplenGrpList                     --(Wan03)  
      ,  RPT.Storerkey    
      ,  RPT.Sku  
      ,  RPT.AltSku  
      ,  RPT.FromLoc  
      ,  ToLoc = ISNULL(MAX(CASE WHEN RPT.UOM = '2' THEN '' ELSE RPT.ToLoc END),'')  
      ,  ID    = MIN(RPT.ID)                                   --(Wan03)  
      ,  RPT.Packkey  
      ,  UOM       = ISNULL(MAX(CASE WHEN RPT.UOM = '2' THEN '' ELSE RPT.UOM END),'')  
      ,  RPT.CaseCnt  
      ,  Qty       = SUM(RPT.Qty)  
      ,  QtyAvail  = SUM(RPT.QtyAvail)  
      ,  QtyPicked = SUM(RPT.QtyPick)  
      ,  QtyPLPickInCS= FLOOR(CASE WHEN RPT.CaseCnt > 0 THEN SUM(RPT.Qty) / RPT.CaseCnt   
                                   ELSE 0 END)  
      ,  QtyPLPickInEA= CASE WHEN RPT.CaseCnt > 0 THEN SUM(RPT.Qty) % CONVERT(INT, RPT.CaseCnt)    
                             ELSE SUM(RPT.Qty)  
                             END  
      ,  FullCasePICK = FLOOR(CASE WHEN RPT.CaseCnt > 0 THEN SUM(CASE WHEN RPT.UOM = '2' THEN RPT.QtyPick ELSE 0 END) / RPT.CaseCnt  
                                   ELSE 0 END)  
      ,  QtyReplen = SUM(RPT.QtyReplen)  
      ,  QtyReplenInCS= FLOOR(CASE WHEN RPT.CaseCnt > 0 THEN SUM(RPT.QtyReplen) / RPT.CaseCnt ELSE 0 END)  
      ,  QtyReplenInEA= CASE WHEN RPT.CaseCnt > 0 THEN SUM(RPT.QtyReplen) % CONVERT(INT, RPT.CaseCnt) ELSE SUM(RPT.QtyReplen) END  
      ,  QtyBalInCS   = FLOOR(CASE WHEN RPT.CaseCnt > 0 AND SUM(CASE WHEN RPT.UOM = '2' THEN RPT.QtyPick ELSE 0 END + RPT.QtyReplen) > 0   
                                   THEN (SUM(RPT.Qty) - SUM(CASE WHEN RPT.UOM = '2' THEN RPT.QtyPick ELSE 0 END + RPT.QtyReplen)) / RPT.CaseCnt   
                                   ELSE 0 END)  
      ,  QtyBacInEA   = CASE --WHEN SUM(RPT.QtyReplen) = 0 THEN 0 --(Wan03)  
                             WHEN RPT.CaseCnt > 0  THEN (SUM(RPT.Qty) - SUM(CASE WHEN RPT.UOM = '2' THEN RPT.QtyPick ELSE 0 END + RPT.QtyReplen)) % CONVERT(INT, RPT.CaseCnt)   
                             ELSE SUM(RPT.Qty) - SUM(CASE WHEN RPT.UOM = '2' THEN RPT.QtyPick ELSE 0 END + RPT.QtyReplen) END  
  
      ,  RowID = ROW_NUMBER() OVER ( ORDER BY   LOC.LogicalLocation  
                                             ,  RPT.FromLoc  
                                             ,  RPT.Sku  
                                    )  
   INTO #TMP_RESULT                                               --(Wan03)  
   FROM #TMP_REPLENRPT RPT  
   JOIN LOC WITH (NOLOCK) ON (RPT.FromLoc = LOC.Loc)  
   GROUP BY RPT.Storerkey  
         ,  RPT.Sku  
         ,  RPT.AltSku  
         ,  RPT.FromLoc  
         --,  RPT.ToLoc    
         --,  RPT.ID                                              --(Wan03)  
         ,  RPT.Packkey  
         --,  RPT.UOM   
         ,  RPT.CaseCnt  
         --,  RPT.Qty  
         --,  RPT.QtyAvail  
         ,  LOC.LogicalLocation  
   ORDER BY LOC.LogicalLocation  
         ,  RPT.FromLoc  
         ,  RPT.Sku  
  
  
   --(Wan03) - START  
   SET @n_TotalQtyReplenInCS = 0.00  
   SET @n_TotalQtyReplenInEA = 0.00  
   SET @n_TotalFullCasePICK  = 0.00  
   SET @n_TotalLoc = 0.00  
  
   SELECT @n_TotalQtyReplenInCS= ISNULL(SUM(RPT.QtyReplenInCS),0)  
      ,   @n_TotalQtyReplenInEA= ISNULL(SUM(RPT.QtyReplenInEA),0)  
      ,   @n_TotalFullCasePICK = ISNULL(SUM(RPT.FullCasePICK),0)  
      ,   @n_TotalLoc     = COUNT(DISTINCT RPT.FromLoc)  
   FROM #TMP_RESULT RPT WITH (NOLOCK)  
  
   SELECT   
         RPT.Facility                            
      ,  RPT.Loadkey                             
      ,  RPT.BatchNoList                         
      ,  RPT.ReplenGrpList                        
      ,  RPT.Storerkey    
      ,  RPT.Sku  
      ,  RPT.AltSku  
      ,  RPT.FromLoc  
      ,  RPT.ToLoc   
      ,  RPT.ID    
      ,  RPT.Packkey  
      ,  RPT.UOM        
      ,  RPT.CaseCnt  
      ,  RPT.Qty         
      ,  RPT.QtyAvail    
      ,  RPT.QtyPicked    
      ,  RPT.QtyPLPickInCS   
      ,  RPT.QtyPLPickInEA   
      ,  RPT.FullCasePICK   
      ,  RPT.QtyReplen   
      ,  RPT.QtyReplenInCS   
      ,  RPT.QtyReplenInEA   
      ,  RPT.QtyBalInCS     
      ,  RPT.QtyBacInEA     
      ,  RPT.RowID  
      ,  TotalQtyReplenInCS = @n_TotalQtyReplenInCS  
      ,  TotalQtyReplenInEA = @n_TotalQtyReplenInEA  
      ,  TotalFullCasePICK  = @n_TotalFullCasePICK  
      ,  TotalLoc           = @n_TotalLoc  
   FROM #TMP_RESULT RPT WITH (NOLOCK)  
   ORDER BY RPT.RowID  
   --(Wan03) - END  
  
  
  
  
   DROP TABLE #TMP_TASKBATCHNO  
   DROP TABLE #TMP_REPLENGRP  
   DROP TABLE #TMP_REPLENRPT  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
END -- procedure  

GO
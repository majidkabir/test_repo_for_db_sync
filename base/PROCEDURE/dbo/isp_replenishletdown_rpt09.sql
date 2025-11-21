SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ReplenishLetdown_rpt09                              */
/* Creation Date: 29-JUN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5237 - [CN] UA Relocation Phase II -                    */
/*        : Replenishment  Letdown Report (B2C)                         */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_ReplenishLetdown_rpt09]
           @c_Facility     NVARCHAR(5)
         , @c_Loadkey      NVARCHAR(1000)        
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

         , @c_ToLoc              NVARCHAR(10)

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
     (   RowRef         INT   IDENTITY(1,1) PRIMARY KEY
      ,  Storerkey      NVARCHAR(15)
      ,  Sku            NVARCHAR(20)
      ,  UCCNo          NVARCHAR(20)
      ,  FromLoc        NVARCHAR(10)
      ,  ToLoc          NVARCHAR(10)
      ,  ID             NVARCHAR(18)
      ,  UOM            NVARCHAR(10)
      ,  Packkey        NVARCHAR(10)
      ,  CaseCnt        FLOAT
      ,  FullCasePICK   INT
      ,  ReplenCasePICK INT
      )

   CREATE TABLE #TMP_LOADKEY 
      (
         Loadkey NVARCHAR(10)   PRIMARY KEY
      ) 


   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END


   IF CHARINDEX( '|', @c_BatchNoList) > 0            
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

   IF CHARINDEX( '|', @c_Loadkey) > 0              
   BEGIN        
      INSERT INTO #TMP_LOADKEY (LoadKey)
      SELECT DISTINCT ColValue 
      FROM [dbo].[fnc_DelimSplit]('|', @c_Loadkey)

      SET @c_Loadkey = STUFF((SELECT ',' + RTRIM(LoadKey) FROM #TMP_LOADKEY ORDER BY Loadkey 
                              FOR XML PATH('')),1,1,'' )
   END

   SET @c_ToLoc = ''
   SELECT @c_ToLoc = ISNULL(RTRIM(CL.Long),'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'UALOC'
   AND CL.Code = '3'

   INSERT INTO #TMP_REPLENRPT
      (  Storerkey
      ,  Sku
      ,  UCCNo
      ,  FromLoc
      ,  ToLoc
      ,  ID
      ,  UOM
      ,  Packkey
      ,  CaseCnt
      ,  FullCasePICK 
      ,  ReplenCasePICK
      )
   SELECT PD.Storerkey
         ,PD.Sku
         ,PD.DropID
         ,PD.Loc
         ,@c_ToLoc
         ,''
         ,PD.UOM
         ,PACK.Packkey
         ,PACK.CaseCnt
         ,FullCasePICK = 1
         ,ReplenCasePICK = 0
   FROM #TMP_TASKBATCHNO TB
   JOIN PACKTASK PT WITH (NOLOCK) ON (TB.TaskBatchNo = PT.TaskBatchNo)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (PT.Orderkey = PD.Orderkey)
   JOIN SKU  SKU  WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                AND(PD.Sku = SKU.Sku)
   JOIN PACK PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE PD.UOM = '2'
   AND PD.Status < '5'
   GROUP BY PD.Storerkey
         ,  PD.Sku
         ,  PD.DropID
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
   WHERE ISNULL(RTRIM(ORD.Loadkey),'') <> ''     
   AND   ISNULL(RTRIM(PT.ReplenishmentGroup),'') <> ''                  
 
   INSERT INTO #TMP_REPLENRPT
      (  Storerkey
      ,  Sku
      ,  UCCNo
      ,  FromLoc
      ,  ToLoc
      ,  ID
      ,  UOM
      ,  Packkey
      ,  CaseCnt
      ,  FullCasePICK 
      ,  ReplenCasePICK
      )
   SELECT RP.Storerkey
         ,RP.Sku
         ,UCC.UCCNo
         ,RP.FromLoc
         ,RP.ToLoc  
         ,''
         ,RP.UOM
         ,PACK.Packkey
         ,PACK.CaseCnt
         ,FullCasePICK = 0
         ,ReplenCasePICK = 1
   FROM UCC  UCC          WITH (NOLOCK)  
   JOIN REPLENISHMENT  RP WITH (NOLOCK) ON (UCC.UserDefined10 = RP.ReplenishmentKey)
   JOIN #TMP_REPLENGRP TRG              ON (RP.ReplenishmentGroup = TRG.ReplenishmentGroup)
   JOIN SKU  SKU          WITH (NOLOCK) ON (RP.Storerkey = SKU.Storerkey)
                                        AND(RP.Sku = SKU.Sku)
   JOIN PACK PACK         WITH (NOLOCK)  ON (SKU.Packkey = PACK.Packkey)
   WHERE RP.Confirmed IN('N','Y')  
   GROUP BY RP.Storerkey
         ,  RP.Sku
         ,  UCC.UCCNo
         ,  RP.FromLoc
         ,  RP.ToLoc  
         ,  RP.ID
         ,  RP.UOM
         ,  PACK.Packkey
         ,  PACK.CaseCnt;

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
        
   SELECT 
         SortBy = ROW_NUMBER() OVER ( ORDER BY  LOC.LogicalLocation
                                             ,  RPT.FromLoc
                                             ,  RPT.Sku
                                    )
      ,  Facility      = @c_Facility                           
      ,  Loadkey        = @c_Loadkey                            
      ,  BatchNoList    = @c_BatchNoList                        
      ,  ReplenGrpList  = @c_ReplenGrpList                      
      ,  RPT.Storerkey  
      ,  RPT.Sku
      ,  RPT.UCCNo
      ,  RPT.FromLoc
      ,  RPT.ToLoc
      ,  RPT.ID
      ,  RPT.Packkey
      ,  RPT.UOM
      ,  RPT.CaseCnt
      ,  FullCasePICK
      ,  ReplenCasePICK

   FROM #TMP_REPLENRPT RPT
   JOIN LOC WITH (NOLOCK) ON (RPT.FromLoc = LOC.Loc)
   ORDER BY LOC.LogicalLocation
         ,  RPT.FromLoc
         ,  RPT.Sku

   DROP TABLE #TMP_TASKBATCHNO
   DROP TABLE #TMP_REPLENGRP
   DROP TABLE #TMP_REPLENRPT

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO
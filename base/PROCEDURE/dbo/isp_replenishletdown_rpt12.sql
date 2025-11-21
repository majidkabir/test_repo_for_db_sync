SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ReplenishLetdown_rpt12                              */
/* Creation Date: 02-MAR-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-12058 [CN]Levis Exceed Release Replenishment Wave Report*/
/*                                                                      */
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
CREATE PROC [dbo].[isp_ReplenishLetdown_rpt12]
           @c_Loadkey       NVARCHAR(20)
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
         , @c_Facility           NVARCHAR(10) = ''
         , @c_wavetype           NVARCHAR(20)=''

   SET @n_StartTCnt = @@TRANCOUNT

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
      ,  Qty            INT
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

   SET @c_facility = ''
   SET @c_wavetype = ''

   SELECT top 1 @c_facility = MAX(ORD.Facility)
               ,@c_wavetype = MAX(WV.wavetype)
   FROM WAVEDETAIL WDET WITH (NOLOCK)
   JOIN WAVE WV WITH (NOLOCK) ON WV.wavekey=WDET.wavekey 
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = WDET.orderkey   
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.orderkey = OD.orderkey
   where WDET.wavekey = @c_loadkey


   SET @c_ToLoc = ''
   SELECT @c_ToLoc = ISNULL(RTRIM(CL.Short),'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'LEVISLOC'
   AND CL.Code = 'PACK'
   AND Code2 = @c_wavetype

   --Full Case Pick
   INSERT INTO #TMP_REPLENRPT
      (  Storerkey
      ,  Sku
      ,  UCCNo
      ,  FromLoc
      ,  ToLoc
      ,  ID
      ,  UOM
      ,  Packkey
      ,  Qty
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
         ,UCC.Qty --PACK.CaseCnt
         ,FullCasePICK = 1
         ,ReplenCasePICK = 0
   FROM PICKDETAIL PD WITH (NOLOCK) 
   JOIN SKU  SKU  WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                AND(PD.Sku = SKU.Sku)
   JOIN PACK PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   JOIN UCC UCC WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
   WHERE PD.UOM = '2'
   --AND PD.Status < '5'
   AND PD.wavekey = @c_loadkey
   GROUP BY PD.Storerkey
         ,  PD.Sku
         ,  PD.DropID
         ,  PD.Loc
         ,  PD.ID
         ,  PD.UOM
         ,  PACK.Packkey
         ,  UCC.Qty
     --    ,  PACK.CaseCnt

   --INSERT INTO #TMP_REPLENGRP (ReplenishmentGroup)
   --SELECT DISTINCT ISNULL(RTRIM(ReplenishmentGroup),'')
   --FROM #TMP_TASKBATCHNO TB
   --JOIN PACKTASK PT WITH (NOLOCK) ON (TB.TaskBatchNo = PT.TaskBatchNo)
   --JOIN ORDERS  ORD WITH(NOLOCK) ON (PT.Orderkey = ORD.Orderkey)
   --WHERE ISNULL(RTRIM(ORD.Loadkey),'') <> ''     
   --AND   ISNULL(RTRIM(PT.ReplenishmentGroup),'') <> ''                  
   
   --Replenishment
   INSERT INTO #TMP_REPLENRPT
      (  Storerkey
      ,  Sku
      ,  UCCNo
      ,  FromLoc
      ,  ToLoc
      ,  ID
      ,  UOM
      ,  Packkey
      ,  Qty
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
         ,UCC.Qty --PACK.CaseCnt
         ,FullCasePICK = 0
         ,ReplenCasePICK = 1
   FROM UCC  UCC          WITH (NOLOCK)  
   JOIN REPLENISHMENT  RP WITH (NOLOCK) ON (UCC.UserDefined10 = RP.ReplenishmentKey)
   --JOIN #TMP_REPLENGRP TRG              ON (RP.ReplenishmentGroup = TRG.ReplenishmentGroup)
   JOIN SKU  SKU          WITH (NOLOCK) ON (RP.Storerkey = SKU.Storerkey)
                                        AND(RP.Sku = SKU.Sku)
   JOIN PACK PACK         WITH (NOLOCK)  ON (SKU.Packkey = PACK.Packkey)
   --WHERE RP.Confirmed IN('N','Y')  
   WHERE RP.wavekey = @c_loadkey
   GROUP BY RP.Storerkey
         ,  RP.Sku
         ,  UCC.UCCNo
         ,  RP.FromLoc
         ,  RP.ToLoc  
         ,  RP.ID
         ,  RP.UOM
         ,  PACK.Packkey
         ,  UCC.Qty

QUIT_SP:

   --SET @c_BatchNoList   = STUFF((SELECT ',' + RTRIM(Taskbatchno) FROM #TMP_TASKBATCHNO  
   --                              ORDER BY Taskbatchno
   --                              FOR XML PATH('')),1,1,'' )
   set @c_ReplenGrpList = ''
   SET @c_ReplenGrpList = STUFF((SELECT ',' + RTRIM(ReplenishmentGroup) FROM replenishment WITH (NOLOCK)
                                 WHERE wavekey = @c_loadkey
                                 ORDER BY RTRIM(ReplenishmentGroup)
                                 FOR XML PATH('')),1,1,'' )

   --IF LEFT(@c_ReplenGrpList,1) = ','
   --BEGIN
   --   SET @c_ReplenGrpList = STUFF(@c_ReplenGrpList,1,1,'')
   --END
        
   SELECT 
         SortBy = ROW_NUMBER() OVER ( ORDER BY  LOC.LogicalLocation
                                             ,  RPT.FromLoc
                                             ,  RPT.Sku
                                    )
      ,  Facility      = @c_Facility                           
      ,  Loadkey        = ''                            
      ,  BatchNoList    = @c_loadkey                        
      ,  ReplenGrpList  = ISNULL(@c_ReplenGrpList,'')                      
      ,  RPT.Storerkey  
      ,  RPT.Sku
      ,  RPT.UCCNo
      ,  RPT.FromLoc
      ,  RPT.ToLoc
      ,  RPT.ID
      ,  RPT.Packkey
      ,  RPT.UOM
      ,  RPT.Qty
      ,  FullCasePICK
      ,  ReplenCasePICK

   FROM #TMP_REPLENRPT RPT
   JOIN LOC WITH (NOLOCK) ON (RPT.FromLoc = LOC.Loc)
   ORDER BY LOC.LogicalLocation
         ,  RPT.FromLoc
         ,  RPT.Sku

   DROP TABLE #TMP_REPLENRPT

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO
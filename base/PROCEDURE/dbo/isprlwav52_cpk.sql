SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV52_PACK                                         */
/* Creation Date: 2022-05-12                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-19633 - TH-Nike-Wave Release                            */
/*        :                                                             */
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
/* 2022-05-12  Wan      1.0   Created.                                  */
/* 2022-05-12  Wan      1.0   DevOps Combine Script.                    */
/* 2022-08-04  Wan01    1.1   Fixed to get correct SourceType           */
/* 2022-09-06  Wan02    1.2   WMS-20686 - TH-NIKE - customize Wave      */
/*                            Release V2022                             */
/************************************************************************/
CREATE PROC [dbo].[ispRLWAV52_CPK]
   @c_Wavekey     NVARCHAR(10)    
,  @b_Success     INT            = 1   OUTPUT
,  @n_Err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
,  @b_debug       INT            = 0 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                INT         = 0
         , @n_Continue                 INT         = 1

         , @b_NewCart                  INT         = 0

         , @n_RowRef                   INT         = 0
         , @n_Batch                    INT         = 0
         , @n_TaskDetailkey            INT         = 0

         , @c_LocMissAreaKey           NVARCHAR(10)= ''

         , @c_Facility                 NVARCHAR(5) = ''              --Wan02
         , @c_Areakey_Prev             NVARCHAR(10)= ''  
         , @c_Areakey                  NVARCHAR(10)= ''  
         , @c_LocLevel_Prev            NVARCHAR(10)= ''
         , @c_Orderkey                 NVARCHAR(10)= ''
         , @c_LocLevel                 NVARCHAR(10)= ''
         , @c_GroupKey                 NVARCHAR(10)= '' 
         , @c_NewGroupKey              NVARCHAR(10)= '' 
         , @c_TaskDetailKey            NVARCHAR(10)= ''
         , @c_PickDetailKey            NVARCHAR(10)= ''
         , @c_Storerkey                NVARCHAR(15)= ''
         , @c_Sku                      NVARCHAR(20)= ''
         , @c_CaseID                   NVARCHAR(20)= ''
         , @c_Loc                      NVARCHAR(20)= ''
         , @c_LogicalLocation          NVARCHAR(10)= ''
         , @c_ToLoc                    NVARCHAR(20)= ''
         , @c_ToLogicalLocation        NVARCHAR(20)= ''
         , @c_PickMethod               NVARCHAR(10)= ''
         , @c_TaskStatus               NVARCHAR(10)= '0'
         , @n_Qty                      INT         = 0

         , @c_CartPos1                 NVARCHAR(20)= ''
         , @c_CartPos2                 NVARCHAR(20)= ''
         , @c_CartPos3                 NVARCHAR(20)= ''
         , @c_CartPos4                 NVARCHAR(20)= ''
         , @n_NoOfCartonPerCart        INT         = 0               --Wan02
         , @n_NoOfReqGroupKey          INT         = 1               --Wan02
         
         , @c_ReleaseWave_Authority    NVARCHAR(30)   = ''           --Wan02
         , @c_ReleaseWave_Opt5         NVARCHAR(1000) = ''           --Wan02
         , @c_NoOfCartonPerCart        NVARCHAR(2)    = '4'          --Wan02
         , @c_UseCTNBreakByFloor       CHAR(1)        = 'N'          --Wan02         

         , @CUR_TIP                    CURSOR
         , @CUR_UPDPICK                CURSOR
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
  
   IF @b_Debug = 1
   BEGIN
      PRINT '@n_StartTCnt: ' + CAST(@n_StartTCnt AS NVARCHAR) 
   END

   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP','U') IS NOT NULL
   BEGIN
      DROP TABLE #PICKDETAIL_WIP
   END
   
   CREATE TABLE #PICKDETAIL_WIP  
      (  RowRef            INT            IDENTITY(1,1)     PRIMARY KEY
      ,  Wavekey           NVARCHAR(10)   NOT NULL DEFAULT('') 
      ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  PickDetailKey     NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')
      ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  UOM               NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Qty               INT            NOT NULL DEFAULT(0)
      ,  CaseID            NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  DropID            NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  Lot               NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  ToLoc             NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  LocLevel          NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Logicallocation   NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  PickSlipNo        NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  CartonType        NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  CartonCube        FLOAT          NOT NULL DEFAULT('')
      )

   INSERT INTO #PICKDETAIL_WIP  
      (  
         Wavekey   
      ,  Orderkey  
      ,  PickDetailKey
      ,  Storerkey         
      ,  Sku  
      ,  UOM             
      ,  Qty 
      ,  CaseID 
      ,  DropID
      ,  Lot             
      ,  ToLoc
      ,  PickSlipNo
      )
   SELECT  WD.Wavekey
         , PD.Orderkey
         , PD.PickDetailkey
         , PD.Storerkey
         , PD.Sku
         , PD.UOM
         , Qty = ISNULL(SUM(PD.Qty),0)
         , PD.CaseID
         , PD.DropID
         , PD.Lot
         , ToLoc = CASE WHEN TD.TaskDetailKey IS NULL THEN PD.Loc ELSE TD.LogicalToLoc END      
         , PickSlipNo = ISNULL(PD.PickSlipNo,'')
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
   JOIN SKU SKU WITH (NOLOCK) ON  PD.Storerkey = SKU.Storerkey
                              AND PD.Sku = SKU.Sku
   LEFT JOIN TASKDETAIL TD WITH (NOLOCK) ON  PD.DropID = TD.CaseID
                                         AND TD.TaskType  = 'RPF'
                                         AND TD.Sourcetype LIKE 'ispRLWAV52_RPF-%'              --(Wan01)
                                         AND PD.DropID <> ''                                    --(Wan01)                                          
   LEFT JOIN TASKDETAIL CPK WITH (NOLOCK) ON  PD.CaseID = CPK.CaseID                
                                         AND CPK.TaskType  = 'CPK'                  
                                         AND CPK.Sourcetype IN  ( 'ispRLWAV52_CPK' )            --(Wan01)
                                         AND CPK.Wavekey = PD.Wavekey               
   WHERE WD.Wavekey = @c_WaveKey
   AND   PD.UOM IN ('6', '7')
   AND   CPK.TaskDetailKey IS NULL                                                  
   GROUP BY WD.Wavekey
         ,  PD.Orderkey
         ,  PD.PickDetailKey
         ,  PD.Storerkey
         ,  PD.Sku
         ,  PD.UOM
         ,  PD.CaseID
         ,  PD.DropID
         ,  PD.Lot
         ,  CASE WHEN TD.TaskDetailKey IS NULL THEN PD.Loc ELSE TD.LogicalToLoc END 
         ,  PD.PickSlipNo
   ORDER BY PD.Orderkey

   IF @b_debug = 1
   BEGIN
      PRINT 'INsert data to #PICKDETAIL_WIP'
   END
   
   --Wan02 - START
   SELECT TOP 1 @c_Facility = o.Facility
               ,@c_Storerkey= o.Storerkey
   FROM #PICKDETAIL_WIP AS pw
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = pw.Orderkey
   ORDER BY pw.RowRef
   
   SELECT @c_ReleaseWave_Authority = fgr.Authority
         ,@c_ReleaseWave_Opt5 = fgr.Option5
   FROM dbo.fnc_GetRight2( @c_Facility, @c_Storerkey, '', 'ReleaseWave_SP') AS fgr 
   
   SET @c_UseCTNBreakByFloor = 'N' 
   SELECT @c_UseCTNBreakByFloor = dbo.fnc_GetParamValueFromString('@c_UseCTNBreakByFloor', @c_ReleaseWave_Opt5, @c_UseCTNBreakByFloor) 
   --Wan02 - END   
      
   UPDATE #PICKDETAIL_WIP
   SET LocLevel = CASE WHEN  @c_UseCTNBreakByFloor = 'N' THEN L.LocLevel ELSE L.[Floor] END              --Wan02
         ,Logicallocation = L.LogicalLocation
   FROM #PICKDETAIL_WIP PIP
   JOIN LOC L (NOLOCK) ON PIP.ToLoc = L.Loc
   
   UPDATE #PICKDETAIL_WIP 
      SET CartonType = PACK.CartonType
         ,CartonCube = CZ.[Cube]
   FROM #PICKDETAIL_WIP PIP
   JOIN STORER ST WITH (NOLOCK) ON PIP.Storerkey = ST.Storerkey
   JOIN (   SELECT PD.PickSlipNo
               ,   PD.LabelNo
               ,   PIF.CartonType
            FROM #PICKDETAIL_WIP P
            JOIN PACKDETAIL PD  WITH (NOLOCK) ON PD.PickSlipNo = P.PickSlipNo AND PD.LabelNo = P.CaseID
            JOIN PACKINFO   PIF WITH (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo
            GROUP BY PD.PickSlipNo
                    ,PD.LabelNo
                    ,PIF.CartonType
         ) PACK ON PIP.PickSlipNo = PACK.PickSlipNo AND PIP.CaseID = PACK.LabelNo
   JOIN CARTONIZATION CZ WITH (NOLOCK) ON  CZ.CartonizationGroup = ST.CartonGroup
                                       AND CZ.CartonType = PACK.CartonType
   
   IF @b_debug = 1
   BEGIN
      SELECT PICKSLIPNO, * FROM #PICKDETAIL_WIP 

      SELECT L.Loc, L.PickZone
            FROM #PICKDETAIL_WIP PIP
            JOIN LOC L (NOLOCK) ON PIP.ToLoc = L.Loc
            LEFT JOIN AREADETAIL AD WITH (NOLOCK) ON L.PickZone = AD.PutawayZone
            WHERE AD.Areakey IS NULL
   END
   
   IF @b_debug = 1
   BEGIN
      SELECT toloc, * FROM #PICKDETAIL_WIP PIP     
   END

   SET @c_LocMissAreaKey = ''
   SELECT TOP 1 @c_LocMissAreaKey= L.Loc
               FROM #PICKDETAIL_WIP PIP
               JOIN LOC L (NOLOCK) ON PIP.ToLoc = L.Loc
               LEFT JOIN AREADETAIL AD WITH (NOLOCK) ON L.PickZone = AD.PutawayZone
               WHERE AD.Areakey IS NULL

   IF @c_LocMissAreaKey <> ''
   BEGIN
      SET @n_continue = 3  
      SET @n_Err = 84010
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Missing Loc areakey for Loc:.' + @c_LocMissAreaKey + '. (ispRLWAV52_CPK)' 
      GOTO QUIT_SP
   END

   IF OBJECT_ID('tempdb..#TASKDETAIL_WIP','U') IS NOT NULL
   BEGIN
      DROP TABLE #TASKDETAIL_WIP;
   END
   
   CREATE TABLE #TASKDETAIL_WIP  
   (  RowRef            INT          IDENTITY(1,1)     PRIMARY KEY
   ,  TaskDetailKey     NVARCHAR(10) DEFAULT('') 
   ,  Wavekey           NVARCHAR(10) DEFAULT('') 
   ,  Orderkey          NVARCHAR(10) DEFAULT('')
   ,  Storerkey         NVARCHAR(15) DEFAULT('')
   ,  Sku               NVARCHAR(20) DEFAULT('')
   ,  UOM               NVARCHAR(10) DEFAULT('')
   ,  Qty               INT          DEFAULT(0)
   ,  CaseID            NVARCHAR(20) DEFAULT('')
   ,  Lot               NVARCHAR(10) DEFAULT('')
   ,  FromLoc           NVARCHAR(10) DEFAULT('')
   ,  Logicallocation   NVARCHAR(10) DEFAULT('')
   ,  ToLoc             NVARCHAR(10) DEFAULT('')
   ,  ToLogicallocation NVARCHAR(10) DEFAULT('') 
   ,  LocLevel          NVARCHAR(10) DEFAULT('')
   ,  AreaKey           NVARCHAR(10) DEFAULT('')
   ,  PickDetailKey     NVARCHAR(10) DEFAULT('')  
   ,  CartonPerLoc      INT          DEFAULT(0)
   ,  SkuPerCarton      INT          DEFAULT(0)
   ,  PickMethod        NVARCHAR(10) DEFAULT('')
   ,  GroupKey          NVARCHAR(10) DEFAULT('')
   ,  CartonType        NVARCHAR(10) DEFAULT('') 
   ,  CartonCube        FLOAT        DEFAULT(0.00)
   )
   
   --Wan02 - START
   IF OBJECT_ID('tempdb..#CART','U') IS NOT NULL                                          
   BEGIN
      DROP TABLE #CART;
   END
   
   CREATE TABLE #CART 
   (  RowRef         INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY
   ,  CaseID         NVARCHAR(20)   NOT NULL DEFAULT('')
   ,  GroupKey_WIP   INT            NOT NULL DEFAULT(0)
   )                                                                                     

   SET @n_NoOfCartonPerCart = 4 
   SELECT @n_NoOfCartonPerCart = dbo.fnc_GetParamValueFromString('@n_NoOfCartonPerCart', @c_ReleaseWave_Opt5, @n_NoOfCartonPerCart) 
   --Wan02 - END   

   IF @b_Debug = 1
   BEGIN
      SELECT PIP.Wavekey           
         ,  PIP.Orderkey          
         ,  PIP.Storerkey         
         ,  PIP.Sku  
         ,  PIP.UOM             
         ,  Qty = SUM(PIP.Qty)               
         ,  PIP.CaseID 
         ,  PIP.Lot           
         ,  PIP.ToLoc             
         ,  PIP.Logicallocation
         ,  ToLoc = cl.udf02
         ,  ToLogicalLocation = LT.LogicalLocation
         ,  PIP.LocLevel   
         ,  AD.AreaKey
         ,  PickDetailKey = CASE WHEN PIP.DropID = '' AND PIP.UOM = '7' THEN PIP.PickdetailKey ELSE '' END
         ,  PIP1.CartonPerLoc 
         ,  PIP2.SkuPerCarton
         ,  PIP.CartonType 
         ,  PIP.CartonCube
      FROM #PICKDETAIL_WIP PIP
      JOIN (  SELECT ToLoc, CartonPerLoc = COUNT(DISTINCT CaseID)
              FROM #PICKDETAIL_WIP 
              GROUP BY ToLoc ) PIP1 ON PIP.ToLoc = PIP1.ToLoc
      JOIN (  SELECT CaseID, SkuPerCarton = COUNT(DISTINCT Sku)
              FROM #PICKDETAIL_WIP 
              GROUP BY CaseID ) PIP2 ON PIP.CaseID = PIP2.CaseID
      JOIN dbo.SKU as s WITH (NOLOCK) ON  s.Storerkey = pip.Storerkey
                                      AND s.Sku       = pip.Sku        
      JOIN LOC LF WITH (NOLOCK) ON PIP.ToLoc = LF.Loc
      JOIN AREADETAIL AD WITH (NOLOCK) ON LF.PickZone = AD.PutawayZone
      JOIN CODELKUP CL WITH (NOLOCK) ON  cl.ListName = 'NikeLoc'  
                                     AND cl.Short = 'PPAST'                                              
                                     AND cl.UDF01 = s.BUSR7 
      LEFT JOIN LOC LT WITH (NOLOCK) ON cl.udf02 = LT.Loc
      WHERE PIP.UOM IN ('6', '7')
      GROUP BY PIP.Wavekey        
            ,  PIP.Orderkey          
            ,  PIP.Storerkey         
            ,  PIP.Sku   
            ,  PIP.UOM              
            --,  PIP.Qty               
            ,  PIP.CaseID 
            ,  PIP.Lot           
            ,  PIP.ToLoc             
            ,  PIP.Logicallocation
            ,  cl.udf02
            ,  LT.LogicalLocation
            ,  PIP.LocLevel 
            ,  AD.AreaKey
            ,  CASE WHEN PIP.DropID = '' AND PIP.UOM = '7' THEN PIP.PickdetailKey ELSE '' END
            ,  PIP1.CartonPerLoc 
            ,  PIP2.SkuPerCarton
            ,  PIP.CartonType 
            ,  PIP.CartonCube
      ORDER BY AD.AreaKey              
            ,  PIP.LocLevel
            ,  PIP1.CartonPerLoc DESC
            ,  PIP2.SkuPerCarton
            ,  PIP.Logicallocation    
         
      PRINT 'START INSERT #TASKDETAIL_WIP'  
   END

   INSERT INTO #TASKDETAIL_WIP
      (  Wavekey           
      ,  Orderkey          
      ,  Storerkey         
      ,  Sku  
      ,  UOM             
      ,  Qty               
      ,  CaseID 
      ,  Lot           
      ,  FromLoc  
      ,  Logicallocation  
      ,  ToLoc
      ,  ToLogicallocation            
      ,  LocLevel 
      ,  AreaKey  
      ,  PickDetailKey       
      ,  CartonPerLoc      
      ,  SkuPerCarton 
      ,  CartonType  
      ,  CartonCube     
      )         
   SELECT PIP.Wavekey           
      ,  PIP.Orderkey          
      ,  PIP.Storerkey         
      ,  PIP.Sku  
      ,  PIP.UOM             
      ,  Qty = SUM(PIP.Qty)               
      ,  PIP.CaseID 
      ,  PIP.Lot           
      ,  PIP.ToLoc             
      ,  PIP.Logicallocation
      ,  ToLoc = cl.udf02
      ,  ToLogicalLocation = LT.LogicalLocation
      ,  PIP.LocLevel   
      ,  AD.AreaKey
      ,  PickDetailKey = CASE WHEN PIP.DropID = '' AND PIP.UOM = '7' THEN PIP.PickdetailKey ELSE '' END
      ,  PIP1.CartonPerLoc 
      ,  PIP2.SkuPerCarton
      ,  PIP.CartonType 
      ,  PIP.CartonCube
   FROM #PICKDETAIL_WIP PIP
   JOIN (  SELECT ToLoc, CartonPerLoc = COUNT(DISTINCT CaseID)
           FROM #PICKDETAIL_WIP 
           GROUP BY ToLoc ) PIP1 ON PIP.ToLoc = PIP1.ToLoc
   JOIN (  SELECT CaseID, SkuPerCarton = COUNT(DISTINCT Sku)
           FROM #PICKDETAIL_WIP 
           GROUP BY CaseID ) PIP2 ON PIP.CaseID = PIP2.CaseID
   JOIN dbo.SKU as s WITH (NOLOCK) ON  s.Storerkey = pip.Storerkey
                                   AND s.Sku       = pip.Sku        
   JOIN LOC LF WITH (NOLOCK) ON PIP.ToLoc = LF.Loc
   JOIN AREADETAIL AD WITH (NOLOCK) ON LF.PickZone = AD.PutawayZone
   JOIN CODELKUP CL WITH (NOLOCK) ON  cl.ListName = 'NikeLoc'  
                                  AND cl.Short = 'PPAST'                                              
                                  --AND cl.Storerkey = @c_Storerkey
                                  AND cl.UDF01 = s.BUSR7 
   LEFT JOIN LOC LT WITH (NOLOCK) ON cl.udf02 = LT.Loc
   WHERE PIP.UOM IN ('6', '7')
   GROUP BY PIP.Wavekey           
         ,  PIP.Orderkey          
         ,  PIP.Storerkey         
         ,  PIP.Sku   
         ,  PIP.UOM              
         --,  PIP.Qty               
         ,  PIP.CaseID 
         ,  PIP.Lot           
         ,  PIP.ToLoc             
         ,  PIP.Logicallocation
         ,  cl.udf02
         ,  LT.LogicalLocation
         ,  PIP.LocLevel 
         ,  AD.AreaKey
         ,  CASE WHEN PIP.DropID = '' AND PIP.UOM = '7' THEN PIP.PickdetailKey ELSE '' END
         ,  PIP1.CartonPerLoc 
         ,  PIP2.SkuPerCarton
         ,  PIP.CartonType 
         ,  PIP.CartonCube
   ORDER BY AD.AreaKey              
         ,  PIP.LocLevel
         ,  PIP1.CartonPerLoc DESC
         ,  PIP2.SkuPerCarton
         ,  PIP.Logicallocation                  

   IF @b_Debug = 1
   BEGIN
      PRINT 'START Process' 
      SELECT  TIP.RowRef
         , TIP.Areakey                          
         , TIP.LocLevel
         , TIP.CaseID
      FROM #TASKDETAIL_WIP TIP
      ORDER BY TIP.RowRef 
   END

   BEGIN TRAN
   --Wan02 - START
   ;WITH cpaf AS 
   (  SELECT 
           TIP.Areakey                          
         , TIP.LocLevel                                                              
         , TIP.CaseID
         , CartonOnCart = ((DENSE_RANK() OVER (PARTITION BY TIP.Areakey,TIP.LocLevel  ORDER BY MIN(TIP.RowRef))) - 1) / @n_NoOfCartonPerCart
      FROM #TASKDETAIL_WIP TIP
      GROUP BY
           TIP.Areakey                          
         , TIP.LocLevel                                                              
         , TIP.CaseID
   )
   INSERT INTO #CART (CaseID, GroupKey_WIP)
   SELECT cpaf.CaseID, groupkey_wip = (DENSE_RANK() OVER (ORDER BY cpaf.Areakey, cpaf.LocLevel, cpaf.CartonOnCart)) - 1
   FROM cpaf 
   
   SET @n_NoOfReqGroupKey = 1
   SELECT @n_NoOfReqGroupKey = COUNT(DISTINCT c.GroupKey_WIP)
   FROM #CART AS c
   SET @c_NewGroupKey = ''
   SET @b_success = 1  
   EXECUTE nspg_getkey  
           @KeyName   = 'GroupKey'  
         , @fieldlength = 10     
         , @KeyString   = @c_NewGroupKey     OUTPUT  
         , @b_success   = @b_success         OUTPUT  
         , @n_err       = @n_err             OUTPUT  
         , @c_errmsg    = @c_errmsg          OUTPUT
         , @n_batch     = @n_NoOfReqGroupKey    
                 
   IF NOT @b_success = 1  
   BEGIN  
      SET @n_continue = 3
      SET @n_Err = 84020
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get Groupkey Fail. (ispRLWAV52_CPK)' 
      GOTO QUIT_SP  
   END 
   
   ;WITH upd AS 
   (  SELECT t.RowRef, c.GroupKey_WIP
      FROM #TASKDETAIL_WIP AS t
      JOIN #CART AS c ON c.CaseID = t.CaseID AND t.CaseID <> ''
   )
   
   UPDATE tw
      SET tw.GroupKey = RIGHT('0000000000' + CONVERT(VARCHAR(10),u.GroupKey_WIP + CONVERT(INT, @c_NewGroupKey)), 10)
   FROM upd AS u
   JOIN #TASKDETAIL_WIP AS tw ON tw.RowRef = u.RowRef
   
   /*
   SET @CUR_TIP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  TIP.RowRef
         , TIP.Areakey                          
         , TIP.LocLevel
         , TIP.CaseID
   FROM #TASKDETAIL_WIP TIP
   ORDER BY TIP.RowRef
          
   OPEN @CUR_TIP
   
   FETCH NEXT FROM @CUR_TIP INTO @n_RowRef
                               , @c_Areakey     
                               , @c_LocLevel
                               , @c_CaseID
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @b_NewCart = 0

      IF (@c_LocLevel_Prev <> @c_LocLevel OR @c_Areakey_Prev <> @c_Areakey)            
      BEGIN
         SET @b_NewCart = 1
      END

      IF @b_Debug = 1
      BEGIN
         PRINT '@c_LocLevel: ' + @c_LocLevel
            + ',@CaseID: '+ @c_CaseID
            + ',@b_NewCart: ' + CAST(@b_NewCart AS CHAR)
      END

      IF @b_NewCart = 0
      BEGIN
         SET @c_GroupKey = ''
         SELECT TOP 1 @c_GroupKey = TIP.GroupKey
         FROM #TASKDETAIL_WIP TIP
         WHERE TIP.CaseID = @c_CaseID
         ORDER BY TIP.GroupKey DESC

         IF @b_Debug = 1
         BEGIN
            PRINT '@b_NewCart: ' + CAST(@b_NewCart AS CHAR)
               + ',@c_GroupKey: ' + @c_GroupKey
         END

         IF @c_GroupKey <> ''
         BEGIN 
            GOTO NEXT_TASK
         END

         IF @b_Debug = 1
         BEGIN
            PRINT '@c_CartPos1: ' + @c_CartPos1
               + ',@c_CartPos2: ' + @c_CartPos2
               + ',@c_CartPos3: ' + @c_CartPos3
               + ',@c_CartPos4: ' + @c_CartPos4
         END

         IF @c_CartPos1 <> '' AND
            @c_CartPos2 <> '' AND
            @c_CartPos3 <> '' AND
            @c_CartPos4 <> ''
         BEGIN
            SET @b_NewCart = 1
         END
         ELSE
         BEGIN
            SET @c_GroupKey = @c_NewGroupKey
         END
      END
      
      IF @b_NewCart = 1
      BEGIN
         SET @c_NewGroupKey = ''
         SET @b_success = 1  
         EXECUTE nspg_getkey  
                 @KeyName   = 'GroupKey'  
               , @fieldlength = 10     
               , @KeyString   = @c_NewGroupKey     OUTPUT  
               , @b_success   = @b_success         OUTPUT  
               , @n_err       = @n_err             OUTPUT  
               , @c_errmsg    = @c_errmsg          OUTPUT
                 
         IF NOT @b_success = 1  
         BEGIN  
            SET @n_continue = 3
            SET @n_Err = 84020
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get Groupkey Fail. (ispRLWAV52_CPK)' 
            GOTO QUIT_SP  
         END  

         SET @c_CartPos1 = ''
         SET @c_CartPos2 = ''
         SET @c_CartPos3 = ''
         SET @c_CartPos4 = ''

         SET @c_GroupKey = @c_NewGroupKey
      END
    
      SET @b_NewCart = 0
      IF @c_CartPos1 = ''
      BEGIN
         SET @c_CartPos1 = @c_CaseID
      END
      ELSE IF @c_CartPos2 = ''
      BEGIN
         SET @c_CartPos2 = @c_CaseID
      END
      ELSE IF @c_CartPos3 = ''
      BEGIN
         SET @c_CartPos3 = @c_CaseID
      END 
      ELSE IF @c_CartPos4 = ''
      BEGIN
         SET @c_CartPos4 = @c_CaseID
      END 

      NEXT_TASK:
      IF @b_debug = 1
      BEGIN
         Print 'update @c_GroupKey: ' + @c_GroupKey
      END 
      UPDATE #TASKDETAIL_WIP
         SET GroupKey = @c_GroupKey
      WHERE RowRef = @n_RowRef

      SET @c_Areakey_Prev = @c_Areakey             
      SET @c_LocLevel_Prev = @c_LocLevel
      FETCH NEXT FROM @CUR_TIP INTO @n_RowRef
                                  , @c_Areakey     
                                  , @c_LocLevel
                                  , @c_CaseID
   END
   CLOSE @CUR_TIP
   DEALLOCATE @CUR_TIP  
   */
   --Wan02 - END

   IF @b_debug = 1
   BEGIN
      SELECT 1, groupkey, * FROM #TASKDETAIL_WIP
   END

   --------------------------------------------------------------------
   --- Calculate Carton Position in the Cart By Small to Large Sequence
   --------------------------------------------------------------------
   UPDATE #TASKDETAIL_WIP
      SET PickMethod = CART.PickMethod
   FROM #TASKDETAIL_WIP TIP
   JOIN (  SELECT RowRef
            ,PickMethod = DENSE_RANK() OVER ( PARTITION BY GroupKey
                                              ORDER BY CartonCube
                                                      ,SkuPerCarton
                                                      ,CaseID
                                            )
            FROM #TASKDETAIL_WIP
         ) CART ON TIP.RowRef = CART.RowRef  

   IF @b_debug = 1
   BEGIN
      SELECT 2, groupkey,pickmethod, caseid, CartonCube, SkuPerCarton, * FROM #TASKDETAIL_WIP
   END

   SET @n_Batch = 0
   SELECT Top 1 @n_Batch = WIP.RowRef        --2022-09-19 Fix
   FROM #TASKDETAIL_WIP WIP
   ORDER BY RowRef DESC

   SET @c_TaskDetailKey = ''
   SET @b_success = 1  
   EXECUTE nspg_getkey  
           @KeyName   = 'TaskDetailKey'  
         , @fieldlength = 10     
         , @KeyString = @c_TaskDetailKey   OUTPUT  
         , @b_success   = @b_success         OUTPUT  
         , @n_err       = @n_err             OUTPUT  
         , @c_errmsg    = @c_errmsg          OUTPUT
         , @n_Batch     = @n_Batch
                 
   IF NOT @b_success = 1  
   BEGIN  
      SET @n_continue = 3
      SET @n_Err = 84030
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get Batch TaskDetaikkey Fail. (ispRLWAV52_CPK)' 
      GOTO QUIT_SP  
   END  

   SET @n_TaskDetailkey = CONVERT(INT,@c_TaskDetailKey) - 1

   UPDATE #TASKDETAIL_WIP 
      SET TaskDetailKey = TASK.Taskdetailkey
   FROM #TASKDETAIL_WIP WIP
   JOIN ( SELECT RowRef
               , Taskdetailkey = RIGHT('0000000000' + CONVERT( NVARCHAR(10), ROW_NUMBER() OVER (ORDER BY TIP.GroupKey, TIP.RowRef) + @n_TaskDetailkey),10)
          FROM #TASKDETAIL_WIP TIP
         ) TASK ON WIP.RowRef = TASK.RowRef  

   SET @c_TaskStatus = '0'
   IF EXISTS ( SELECT 1
               FROM #PICKDETAIL_WIP PIP WITH (NOLOCK)
               JOIN TASKDETAIL TD WITH (NOLOCK) ON  PIP.DropID = TD.CaseID
                                                AND TD.TaskType  = 'RPF'
                                                AND TD.Sourcetype LIKE 'ispRLWAV52_RPF-%'              --(Wan01)
                                                AND PIP.Wavekey = TD.Wavekey
               WHERE PIP.Wavekey = @c_Wavekey
               AND   PIP.DropID <> ''
               AND   PIP.UOM IN ('6', '7') 
            )
   BEGIN 
      SET @c_TaskStatus = 'H' 
   END
   
   INSERT INTO TASKDETAIL
      (  TaskDetailKey
      ,  TaskType
      ,  Storerkey
      ,  Sku
      ,  Lot
      ,  UOM
      ,  UOMQty
      ,  Qty
      ,  FromLoc
      ,  LogicalFromLoc
      ,  FromID
      ,  ToLoc
      ,  LogicalToLoc
      ,  ToID
      ,  CaseID
      ,  PickMethod
      ,  [Status]
      ,  [Priority]
      ,  AreaKey
      ,  SourceType
      ,  Sourcekey 
      ,  Wavekey
      ,  Orderkey
      ,  GroupKey
      )
   SELECT TIP.TaskDetailkey
         ,TaskType = 'CPK'
         ,TIP.Storerkey
         ,TIP.Sku
         ,TIP.Lot
         ,TIP.UOM
         ,TIP.Qty
         ,TIP.Qty
         ,TIP.FromLoc
         ,TIP.Logicallocation
         ,FromID = ''
         ,TIP.ToLoc
         ,TIP.ToLogicallocation
         ,ToID = ''
         ,TIP.CaseID
         ,TIP.PickMethod
         ,@c_TaskStatus
         ,[Priority] = '9'
         ,TIP.Areakey
         ,SourceType = 'ispRLWAV52_CPK'              ---(Wan01)
         ,Sourcekey  = @c_Wavekey
         ,TIP.Wavekey
         ,TIP.Orderkey
         ,TIP.GroupKey
   FROM #TASKDETAIL_WIP TIP
   ORDER BY TIP.GroupKey
         ,  TIP.RowRef

   SET @n_err = @@ERROR  
   IF @n_err <> 0  
   BEGIN
      SET @n_continue = 3  
      SET @n_Err = 84040
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV52_CPK)' 
      GOTO QUIT_SP
   END

   -------------------------------------------------------------------------------------------------------------
   --- Update Pick TaskDetailkey to PICKDETAIL.Taskdetail for Home Location (PickDetail UOM='7' And DropID = ''
   --- Cannot Upate Other Pickdetail.Taskdetaikey due to it had been stamped with Replen TaskDetailkey
   -------------------------------------------------------------------------------------------------------------
   SET @CUR_UPDPICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  TIP.PickDetailKey
         , TIP.TaskDetailKey
   FROM #TASKDETAIL_WIP TIP
   WHERE TIP.PickDetailKey <> ''
   ORDER BY TIP.RowRef
          
   OPEN @CUR_UPDPICK

   FETCH NEXT FROM @CUR_UPDPICK INTO @c_PickDetailKey
                                    ,@c_TaskDetailKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE PICKDETAIL 
         SET TaskDetailkey = @c_TaskDetailKey
            ,Trafficcop = NULL
            ,EditWho  = SUSER_SNAME()
            ,EditDate = GETDATE()
      FROM  PICKDETAIL PD WITH (NOLOCK)
      WHERE PD.PickdetailKey = @c_PickDetailKey

      SET @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 84050
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed. (ispRLWAV52_CPK)' 
         GOTO QUIT_SP
      END

      FETCH NEXT FROM @CUR_UPDPICK INTO @c_PickDetailKey
                                       ,@c_TaskDetailKey
   END
   CLOSE @CUR_UPDPICK
   DEALLOCATE @CUR_UPDPICK

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV52_CPK'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO
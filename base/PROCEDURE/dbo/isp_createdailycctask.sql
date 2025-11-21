SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_CreateDailyCCTask                              */  
/* Creation Date: 26-Apr-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: James Wong                                               */  
/*                                                                      */  
/* Purpose: SOS241825 - Create daily CC TM task and send email alert    */  
/*                                                                      */  
/* Called By: SQL scheduler                                             */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/************************************************************************/  

CREATE PROC [dbo].[isp_CreateDailyCCTask] (  
     @c_Facility        NVARCHAR( 5)  
    ,@c_StorerKey       NVARCHAR(15)  
    ,@b_Debug           INT  
    ,@b_Success         INT         OUTPUT  
    ,@n_ErrNo           INT         OUTPUT  
    ,@c_ErrMsg          NVARCHAR(250) OUTPUT -- screen limitation, 20 char max  
 )      
AS  
BEGIN  
    SET NOCOUNT ON      
    SET QUOTED_IDENTIFIER OFF      
    SET ANSI_NULLS OFF      
    SET CONCAT_NULL_YIELDS_NULL OFF   
       
   DECLARE @n_NoOfLoc            INT,
           @n_NoOfSKU            INT,
           @n_Qty                INT,
           @n_StartTCnt          INT,
           @n_Continue           INT,
           @n_LOCCount           INT, 
           @n_SKUCount           INT,
           @c_Status             NVARCHAR( 1),
           @c_TaskDetailKey      NVARCHAR(10),     
           @c_LOC                NVARCHAR(10),
           @c_PREVLOC            NVARCHAR(10),
           @c_PREVSKU            NVARCHAR(20),
           @c_LogicalLocation    NVARCHAR(10),      
           @c_AreaKey            NVARCHAR(10), 
           @c_SKU                NVARCHAR(20), 
           @c_CCKey              NVARCHAR(10), 
           @c_CCType             NVARCHAR(10), 
           @c_PickMethod         NVARCHAR(10) 

   SET @n_StartTCnt = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN GENCCTASK  

   SET @c_CCKey = ''
   
   SET @n_NoOfLoc = 0
   SET @n_NoOfSKU = 0
   
   SELECT @n_NoOfLoc = ISNULL(USERDEFINE11, 0) FROM Facility WITH (NOLOCK) WHERE Facility = @c_Facility
   SELECT @n_NoOfSKU = ISNULL(CtnPickQty, 0) FROM Storer WITH (NOLOCK) WHERE StorerKey = @c_StorerKey
   
   IF @n_NoOfLoc = 0 AND @n_NoOfSKU = 0
      GOTO Quit

   -- Create temp table
   SELECT LOC.LOC, LOC.LogicalLocation, AD.AreaKey, LLI.SKU, LLI.QTY, '          ' AS CCType 
   INTO #CCTASK
   FROM LOC LOC WITH (NOLOCK)
   JOIN LotxLocxID LLI WITH (NOLOCK) ON LOC.LOC = LLI.LOC
   LEFT OUTER JOIN AreaDetail AD WITH (NOLOCK) ON AD.PutawayZone = LOC.PutawayZone
   WHERE 1 = 2
 
   IF @n_NoOfLoc > 0
   BEGIN
      -- Generate LOC
      INSERT INTO #CCTASK
      SELECT LOC.LOC, LOC.LogicalLocation, AD.AreaKey, '', (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED), 'LOC' 
      FROM LOC LOC WITH (NOLOCK) 
      JOIN LotxLocxID LLI WITH (NOLOCK) ON LOC.LOC = LLI.LOC
      JOIN ID ID WITH (NOLOCK) ON LLI.Id = ID.ID 
      JOIN LOT LOT WITH (NOLOCK) ON LLI.LOT = LOT.LOT 
      LEFT OUTER JOIN AreaDetail AD WITH (NOLOCK) ON AD.PutawayZone = LOC.PutawayZone
      WHERE LLI.StorerKey = @c_StorerKey
      AND   DATEDIFF(d, LOC.LastCycleCount, GETDATE()) >= LOC.CycleCountFrequency
      AND   LOC.Facility = @c_Facility
      AND   LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
      AND   LOC.Status <> 'HOLD'
      AND   ID.STATUS <> 'HOLD'   
      AND   LOT.STATUS <> 'HOLD'  
      AND   LOC.CycleCountFrequency > 0
   END

   IF @n_NoOfSKU > 0
   BEGIN
      -- Generate SKU
      INSERT INTO #CCTASK
      SELECT LOC.LOC, LOC.LogicalLocation, AD.AreaKey, LLI.SKU, (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED), 'SKU' 
      FROM LOC LOC WITH (NOLOCK) 
      JOIN LotxLocxID LLI WITH (NOLOCK) ON LOC.LOC = LLI.LOC
      JOIN ID ID WITH (NOLOCK) ON LLI.Id = ID.ID 
      JOIN LOT LOT WITH (NOLOCK) ON LLI.LOT = LOT.LOT 
      JOIN SKU SKU WITH (NOLOCK) ON LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU
      LEFT OUTER JOIN AreaDetail AD WITH (NOLOCK) ON AD.PutawayZone = LOC.PutawayZone
      WHERE LLI.StorerKey = @c_StorerKey
      AND   DATEDIFF(d, SKU.LastCycleCount, GETDATE()) >= SKU.CycleCountFrequency
      AND   LOC.Facility = @c_Facility
      AND   LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
      AND   LOC.Status <> 'HOLD'
      AND   ID.STATUS <> 'HOLD'   
      AND   LOT.STATUS <> 'HOLD'  
      AND   SKU.CycleCountFrequency > 0
      AND   NOT EXISTS (SELECT 1 FROM #CCTASK CCTASK WHERE CCTASK.LOC = LLI.LOC AND CCTASK.SKU = LLI.SKU)
   END
   
   IF @b_Debug = 1
      SELECT * FROM #CCTASK

   SET @n_LOCCount = 0
   DECLARE CUR_CCTASK_LOC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT LOC, LogicalLocation, AreaKey, SKU, QTY, CCTYPE  
   FROM #CCTASK WITH (NOLOCK) 
   WHERE CCType = 'LOC'
   ORDER BY AreaKey, LogicalLocation, LOC 
   OPEN CUR_CCTASK_LOC
   FETCH NEXT FROM CUR_CCTASK_LOC INTO @c_LOC, @c_LogicalLocation, @c_AreaKey, @c_SKU, @n_QTY, @c_CCType
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @n_LOCCount >= @n_NoOfLoc 
         BREAK
      
      IF @c_PREVLOC <> @c_LOC
      BEGIN
         SET @c_PREVLOC = @c_LOC
         SET @n_LOCCount = @n_LOCCount + 1
      END

      IF ISNULL(@c_CCKey, '') = ''
      BEGIN
         SET @b_Success = 1  
        
         EXECUTE nspg_getkey  
         'CCKey'  
         , 10  
         , @c_CCKey           OUTPUT  
         , @b_Success         OUTPUT  
         , @n_ErrNo           OUTPUT  
         , @c_ErrMsg          OUTPUT  
        
         IF @b_Success <> 1  
         BEGIN  
            SET @n_Continue = 3  
            SET @c_Status = '5'  
            SET @c_ErrMsg = 'Get CCDetail Key Failed (isp_CreateDailyCCTask).'  
            GOTO Quit
         END  
      END
         
      -- Create Cycle Count Task  
      SET @b_Success = 1  
     
      EXECUTE nspg_getkey  
      'TaskDetailKey'  
      , 10  
      , @c_TaskDetailKey   OUTPUT  
      , @b_Success         OUTPUT  
      , @n_ErrNo           OUTPUT  
      , @c_ErrMsg          OUTPUT  
     
      IF @b_Success <> 1  
      BEGIN  
         SET @n_Continue = 3  
         SET @c_Status = '5'  
         SET @c_ErrMsg = 'Get TaskDetail Key Failed (isp_CreateDailyCCTask).'  
         GOTO Quit
      END  
  
      SELECT @c_LogicalLocation = LogicalLocation,  
             @c_AreaKey         = ISNULL(ad.AreaKey, '')  
      FROM   LOC WITH (NOLOCK)  
      LEFT OUTER JOIN AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone  
      WHERE  LOC = @c_Loc  
  
      -- If not outstanding cycle count task, then insert new cycle count task  
      IF NOT EXISTS(SELECT 1 FROM TaskDetail td (NOLOCK) WHERE td.TaskType = 'CC' AND td.FromLoc = @c_Loc  
                    AND td.[Status] IN ('0','3') AND td.Storerkey = @c_StorerKey AND td.Sku = @c_SKU)  
      BEGIN  
      
         SET @c_PickMethod = @c_CCtype
         
         INSERT INTO TaskDetail  
           (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc  
           ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide  
           ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey  
           ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty)  
           VALUES  
           (@c_TaskDetailKey  
            ,'CC' -- TaskType  
            ,@c_Storerkey  
            ,@c_Sku  
            ,'' -- Lot  
            ,'' -- UOM  
            ,0  -- UOMQty  
            ,0  -- Qty  
            ,@c_Loc  
            ,ISNULL(@c_LogicalLocation,'')  
            ,'' -- FromID  
            ,'' -- ToLoc  
            ,'' -- LogicalToLoc  
            ,'' -- ToID  
            ,'' -- Caseid  
            ,@c_PickMethod -- PickMethod  
            ,'0' -- STATUS  
            ,''  -- StatusMsg  
            ,'9' -- Priority  
            ,''  -- SourcePriority  
            ,''  -- Holdkey  
            ,''  -- UserKey  
            ,''  -- UserPosition  
            ,''  -- UserKeyOverRide  
            ,GETDATE() -- StartTime  
            ,GETDATE() -- EndTime  
            ,'DAILYCCTASK'   -- SourceType  
            ,@c_CCKey -- SourceKey  
            ,'' -- PickDetailKey  
            ,'' -- OrderKey  
            ,'' -- OrderLineNumber  
            ,'' -- ListKey  
            ,'' -- WaveKey  
            ,'' -- ReasonKey  
            ,'' -- Message01  
            ,'' -- Message02  
            ,'' -- Message03  
            ,'' -- RefTaskKey  
            ,'' -- LoadKey  
            ,@c_AreaKey  
            ,'' -- DropID  
            ,@n_Qty)  
     
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @c_Status = '5'  
               SET @c_ErrMsg = 'Insert TaskDetail Failed (isp_CreateDailyCCTask).'  
               GOTO Quit
            END  
  
            IF @b_Debug = 1
            BEGIN
               SELECT '@c_TaskDetailKey', @c_TaskDetailKey
            END
      END  
      FETCH NEXT FROM CUR_CCTASK_LOC INTO @c_LOC, @c_LogicalLocation, @c_AreaKey, @c_SKU, @n_QTY, @c_CCType
   END
   CLOSE CUR_CCTASK_LOC
   DEALLOCATE CUR_CCTASK_LOC

   SET @n_SKUCount = 0
   DECLARE CUR_CCTASK_SKU CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT LOC, LogicalLocation, AreaKey, SKU, QTY, CCTYPE  
   FROM #CCTASK WITH (NOLOCK) 
   WHERE CCType = 'SKU'
   ORDER BY SKU, AreaKey, LogicalLocation, LOC 
   OPEN CUR_CCTASK_SKU
   FETCH NEXT FROM CUR_CCTASK_SKU INTO @c_LOC, @c_LogicalLocation, @c_AreaKey, @c_SKU, @n_QTY, @c_CCType
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @n_SKUCount >= @n_NoOfSKU 
         BREAK
      
      IF @c_PREVSKU <> @c_SKU
      BEGIN
         SET @c_PREVSKU = @c_SKU
         SET @n_SKUCount = @n_SKUCount + 1
      END

      IF ISNULL(@c_CCKey, '') = ''
      BEGIN
         SET @b_Success = 1  
        
         EXECUTE nspg_getkey  
         'CCKey'  
         , 10  
         , @c_CCKey           OUTPUT  
         , @b_Success         OUTPUT  
         , @n_ErrNo           OUTPUT  
         , @c_ErrMsg          OUTPUT  
        
         IF @b_Success <> 1  
         BEGIN  
            SET @n_Continue = 3  
            SET @c_Status = '5'  
            SET @c_ErrMsg = 'Get CCDetail Key Failed (isp_CreateDailyCCTask).'  
            GOTO Quit
         END  
      END
         
      -- Create Cycle Count Task  
      SET @b_Success = 1  
     
      EXECUTE nspg_getkey  
      'TaskDetailKey'  
      , 10  
      , @c_TaskDetailKey   OUTPUT  
      , @b_Success         OUTPUT  
      , @n_ErrNo           OUTPUT  
      , @c_ErrMsg          OUTPUT  
     
      IF @b_Success <> 1  
      BEGIN  
         SET @n_Continue = 3  
         SET @c_Status = '5'  
         SET @c_ErrMsg = 'Get TaskDetail Key Failed (isp_CreateDailyCCTask).'  
         GOTO Quit
      END  
  
      SELECT @c_LogicalLocation = LogicalLocation,  
             @c_AreaKey         = ISNULL(ad.AreaKey, '')  
      FROM   LOC WITH (NOLOCK)  
      LEFT OUTER JOIN AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone  
      WHERE  LOC = @c_Loc  
  
      -- If not outstanding cycle count task, then insert new cycle count task  
      IF NOT EXISTS(SELECT 1 FROM TaskDetail td (NOLOCK) WHERE td.TaskType = 'CC' AND td.FromLoc = @c_Loc  
                    AND td.[Status] IN ('0','3') AND td.Storerkey = @c_StorerKey AND td.Sku = @c_SKU)  
      BEGIN  
      
         SET @c_PickMethod = @c_CCtype
         
         INSERT INTO TaskDetail  
           (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc  
           ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide  
           ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey  
           ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty)  
           VALUES  
           (@c_TaskDetailKey  
            ,'CC' -- TaskType  
            ,@c_Storerkey  
            ,@c_Sku  
            ,'' -- Lot  
            ,'' -- UOM  
            ,0  -- UOMQty  
            ,0  -- Qty  
            ,@c_Loc  
            ,ISNULL(@c_LogicalLocation,'')  
            ,'' -- FromID  
            ,'' -- ToLoc  
            ,'' -- LogicalToLoc  
            ,'' -- ToID  
            ,'' -- Caseid  
            ,@c_PickMethod -- PickMethod  
            ,'0' -- STATUS  
            ,''  -- StatusMsg  
            ,'9' -- Priority  
            ,''  -- SourcePriority  
            ,''  -- Holdkey  
            ,''  -- UserKey  
            ,''  -- UserPosition  
            ,''  -- UserKeyOverRide  
            ,GETDATE() -- StartTime  
            ,GETDATE() -- EndTime  
            ,'DAILYCCTASK'   -- SourceType  
            ,@c_CCKey -- SourceKey  
            ,'' -- PickDetailKey  
            ,'' -- OrderKey  
            ,'' -- OrderLineNumber  
            ,'' -- ListKey  
            ,'' -- WaveKey  
            ,'' -- ReasonKey  
            ,'' -- Message01  
            ,'' -- Message02  
            ,'' -- Message03  
            ,'' -- RefTaskKey  
            ,'' -- LoadKey  
            ,@c_AreaKey  
            ,'' -- DropID  
            ,@n_Qty)  
     
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @c_Status = '5'  
               SET @c_ErrMsg = 'Insert TaskDetail Failed (isp_CreateDailyCCTask).'  
               GOTO Quit
            END  
  
            IF @b_Debug = 1
            BEGIN
               SELECT '@c_TaskDetailKey', @c_TaskDetailKey
            END
      END  
      FETCH NEXT FROM CUR_CCTASK_SKU INTO @c_LOC, @c_LogicalLocation, @c_AreaKey, @c_SKU, @n_QTY, @c_CCType
   END
   CLOSE CUR_CCTASK_SKU
   DEALLOCATE CUR_CCTASK_SKU
   
   -- Increate taskdetail priority for the task not finish from previous day
   UPDATE TASKDETAIL SET Priority = CAST(Priority AS INT) - 1
   WHERE StorerKey = @c_StorerKey
   AND Status = '0'
   AND Priority > 1     -- Priority 1 is the top priority
   AND DATEDIFF(D, ADDDATE, GETDATE()) >= 1
   AND TaskType = 'CC'

   IF @@ERROR <> 0  
   BEGIN  
      SET @n_Continue = 3  
      SET @c_Status = '5'  
      SET @c_ErrMsg = 'Increase TaskDetail Priority Failed (isp_CreateDailyCCTask).'  
      GOTO Quit
   END  

   SET @n_ErrNo = 0
   EXEC isp_DailyCCTaskAlert 
         @c_StorerKey, 
         @n_ErrNo        OUTPUT, 
         @c_ErrMsg       OUTPUT
   
   IF @n_ErrNo <> 0  
   BEGIN  
      SET @n_Continue = 3  
      SET @c_Status = '5'  
      SET @c_ErrMsg = @c_ErrMsg
      GOTO Quit
   END  
  
   Quit:
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      ROLLBACK TRAN GENCCTASK  
      EXECUTE nsp_logerror @n_ErrNo, @c_ErrMsg, 'isp_TCP_RESIDUAL_SHORT_IN'  
   END  
  
   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started  
      COMMIT TRAN GENCCTASK  
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1760ExtUpd01                                    */
/* Purpose: When LOC is empty then generate CC task. If CC task         */
/*          generated then update the task as counted                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-04-07 1.0  James      SOS337425. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1760ExtUpd01] (
   @nMobile         INT, 
   @nFunc           INT, 
   @nStep           INT, 
   @nInputKey       INT, 
   @cLangCode       NVARCHAR( 3),  
   @cStorerkey      NVARCHAR( 15), 
   @cTaskDetailKey  NVARCHAR( 10), 
   @cAreaKey        NVARCHAR( 10), 
   @cFromLOC        NVARCHAR( 10), 
   @cSKU            NVARCHAR( 20), 
   @nPickQty        INT, 
   @cToteNo         NVARCHAR( 18), 
   @nAfterStep      INT, 
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT  
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @n_StartTCnt       INT, 
           @b_Success         INT, 
           @n_ErrNo           INT,
           @b_Debug           INT,
           @c_CCKey           NVARCHAR( 10), 
           @c_NTaskDetailKey  NVARCHAR( 10), 
           @c_CCLogicalLoc    NVARCHAR( 18), 
           @c_ErrMsg          NVARCHAR( 250), 
           @c_PickMethod      NVARCHAR( 10), 
           @c_Facility        NVARCHAR( 5)  

   SELECT @c_Facility = Facility 
   FROM dbo.LOC LOC WITH (NOLOCK) 
   JOIN dbo.AreaDetail AD WITH (NOLOCK) ON ( LOC.PutAwayZone = AD.PutAwayZone)
   WHERE LOC = @cFromLOC
   AND   AD.AreaKey = @cAreaKey
   
   SET @n_StartTCnt = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN GENCCTASKJW  
   
   SET @nErrNo = 0
   IF @nStep = 15 AND @nInputKey = 1
   BEGIN
      -- Generate CCKey
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
         SET @nErrNo = 53101
         SET @c_ErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetCCKeyFail'  
         GOTO Quit
      END  
         
      -- Generate TaskDetailKey
      SET @b_Success = 1  
     
      EXECUTE nspg_getkey  
      'TaskDetailKey'  
      , 10  
      , @c_NTaskDetailKey  OUTPUT  
      , @b_Success         OUTPUT  
      , @n_ErrNo           OUTPUT  
      , @c_ErrMsg          OUTPUT  
     
      IF @b_Success <> 1  
      BEGIN  
         SET @nErrNo = 53102
         SET @c_ErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetTaskKeyFail'  
         GOTO Quit
      END  

      SELECT @c_CCLogicalLoc = CCLogicalLoc
      FROM   LOC WITH (NOLOCK)  
      LEFT OUTER JOIN AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone  
      WHERE  LOC = @cFromLOC  
  
      -- If not outstanding cycle count task, then insert new cycle count task  
      IF NOT EXISTS(SELECT 1 FROM TaskDetail td (NOLOCK) WHERE td.TaskType = 'CC' AND td.FromLoc = @cFromLOC  
                    AND td.[Status] IN ('0','3') AND td.Storerkey = @cStorerkey AND td.Sku = @cSKU)  
      BEGIN  
      
         SET @c_PickMethod = 'PITSKEMPTY'
         
         INSERT INTO TaskDetail  
           (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc  
           ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide  
           ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey  
           ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty)  
           VALUES  
           (@c_NTaskDetailKey  
            ,'CC' -- TaskType  
            ,@cStorerkey  
            ,'' -- SKU  
            ,'' -- Lot  
            ,'' -- UOM  
            ,0  -- UOMQty  
            ,0  -- Qty  
            ,@cFromLOC  
            ,ISNULL(@c_CCLogicalLoc,'')  
            ,'' -- FromID  
            ,'' -- ToLoc  
            ,'' -- LogicalToLoc  
            ,'' -- ToID  
            ,'' -- Caseid  
            ,@c_PickMethod -- PickMethod  
            ,'0' -- STATUS  
            ,'Created by rdt_1760ExtUpd01'  -- StatusMsg 
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
            ,@cAreaKey  
            ,'' -- DropID  
            ,0)  
     
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 53104
               SET @c_ErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsCCTaskFail'  
               GOTO Quit
            END  
  
            IF @b_Debug = 1
            BEGIN
               SELECT '@c_TaskDetailKey', @c_NTaskDetailKey
            END
      END  
         
      IF @nPickQty = '1'   -- pass in param as Option
      BEGIN
         -- If user confirm physical location is empty then cancel existing cc task
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerkey
                     AND   TaskType = 'CC'
                     AND   PickMethod = 'PITSKEMPTY'
                     AND   FromLOC = @cFromLOC
                     AND   [Status] = '0')     
         BEGIN
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
               [Status] = '9', 
               StatusMsg = 'Cancel by rdt_1760ExtUpd01',
               UserKey = sUser_sName(),
               EditDate = GETDATE(),
               EditWho  = sUser_sName(), 
               TrafficCop = NULL
            WHERE StorerKey = @cStorerkey
            AND   TaskType = 'CC'
            AND   PickMethod = 'PITSKEMPTY'
            AND   FromLOC = @cFromLOC
            AND   [Status] = '0'
                     
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 53101  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdCCTaskFail'  
               GOTO Quit
            END  
         END
      END
   END
           
   Quit:
   IF @nErrNo <> 0  -- Error Occured - Process And Return  
      ROLLBACK TRAN GENCCTASKJW  
  
   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started  
      COMMIT TRAN GENCCTASKJW  
   

GO
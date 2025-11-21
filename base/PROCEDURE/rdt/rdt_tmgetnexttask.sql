SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_TMGetNextTask                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Get Next TM Task , Generate Func, Screen , Step             */  
/*                                                                      */  
/* Called from: RDT TM Modules                                          */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2011-09-19 1.0  ChewKP   Created                                     */ 
/* 2017-02-27 1.1  TLTING   Variable Nvarchar                           */  
/************************************************************************/  
CREATE PROC [RDT].[rdt_TMGetNextTask] (
     @nMobile INT
    ,@cStorerKey NVARCHAR(15)
    ,@cUserName NVARCHAR(15)
    ,@cFacility NVARCHAR(5)
    ,@cLoadKey NVARCHAR(10)
    ,@cAreaKey NVARCHAR(10)
    ,@cToLoc   NVARCHAR(10)
    ,@cLangCode NVARCHAR(3)
    ,@cFromLoc NVARCHAR(10)        OUTPUT
    ,@cTaskDetailKey NVARCHAR(10)  OUTPUT
    ,@cRefKey01 NVARCHAR(20)       OUTPUT
    ,@cRefKey02 NVARCHAR(20)       OUTPUT
    ,@cRefKey03 NVARCHAR(20)       OUTPUT
    ,@cRefKey04 NVARCHAR(20)       OUTPUT
    ,@cRefKey05 NVARCHAR(20)       OUTPUT
    ,@c_outstring NVARCHAR(255)    OUTPUT
    ,@cTTMTasktype NVARCHAR(10)    OUTPUT
    ,@nFunc     INT            OUTPUT
    ,@nScn      INT            OUTPUT
    ,@nStep     INT            OUTPUT
    ,@nErrNo    INT            OUTPUT
    ,@cErrMsg NVARCHAR(20)      OUTPUT -- screen limitation, 20 char max
    ,@b_Success NVARCHAR(10)       OUTPUT                               
    
    
 )    
AS    
BEGIN
    SET NOCOUNT ON    
    SET QUOTED_IDENTIFIER OFF    
    SET ANSI_NULLS OFF    
    SET CONCAT_NULL_YIELDS_NULL OFF    
    
    DECLARE @cNextTaskdetailkey NVARCHAR(10)
            , @nTranCount INT
            , @nTaskDetail_Qty  INT
            , @nOn_HandQty      INT
            , @cTaskStorer      NVARCHAR(15)
            , @cID              NVARCHAR(20)
            , @cLoc             NVARCHAR(10)
            
    SET @nTranCount = @@TRANCOUNT 
    
    
    
    BEGIN TRAN 
    SAVE TRAN TM_GetNextTask    
    
    -- Search for next task and redirect screen      
      EXEC dbo.nspTMTM01      
          @c_sendDelimiter = null      
       ,  @c_ptcid         = 'RDT'      
       ,  @c_userid        = @cUserName      
       ,  @c_taskId        = 'RDT'      
       ,  @c_databasename  = NULL      
       ,  @c_appflag       = NULL      
       ,  @c_recordType    = NULL      
       ,  @c_server        = NULL      
       ,  @c_ttm           = NULL      
       ,  @c_areakey01     = @cAreaKey      
       ,  @c_areakey02     = ''      
       ,  @c_areakey03     = ''      
       ,  @c_areakey04     = ''      
       ,  @c_areakey05     = ''      
       ,  @c_lastloc       = @cToLoc      
       ,  @c_lasttasktype  = 'MV'      
       ,  @c_outstring     = @c_outstring    OUTPUT      
       ,  @b_Success       = @b_Success      OUTPUT      
       ,  @n_err           = @nErrNo         OUTPUT      
       ,  @c_errmsg        = @cErrMsg        OUTPUT      
       ,  @c_taskdetailkey = @cNextTaskdetailkey OUTPUT      
       ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT      
       ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func      
       ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func      
       ,  @c_RefKey03      = @cRefKey03     OUTPUT -- this is the field value to parse to 1st Scn in func      
       ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func      
       ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func      
      
          
      
      IF ISNULL(RTRIM(@cNextTaskdetailkey), '') = '' --@nErrNo = 67804 -- Nothing to do!      
      BEGIN      
         -- EventLog - Sign Out Function     
--         EXEC RDT.rdt_STD_EventLog      
--          @cActionType = '9', -- Sign Out function      
--          @cUserID     = @cUserName,      
--          @nMobileNo   = @nMobile,      
--          @nFunctionID = @nFunc,      
--          @cFacility   = @cFacility,      
--          @cStorerKey  = @cTaskStorer
      
           -- Go back to Task Manager Main Screen      
           SET @nFunc = 1756      
           SET @nScn = 2100      
           SET @nStep = 1      
      
           SET @cErrMsg = 'No More Task'      
           SET @cAreaKey = ''      
      
--           SET @cOutField01 = ''  -- Area      
--           SET @cOutField02 = ''      
--           SET @cOutField03 = ''      
--           SET @cOutField04 = ''      
--           SET @cOutField05 = ''      
--           SET @cOutField06 = ''      
--           SET @cOutField07 = ''      
--           SET @cOutField08 = ''      
      
           GOTO QUIT      
      END      
      
      IF ISNULL(@cErrMsg, '') <> ''      
      BEGIN      
         SET @cErrMsg = @cErrMsg      
         GOTO QUIT      
      END      
      
      
      IF ISNULL(@cNextTaskdetailkey, '') <> ''      
      BEGIN      
         SET @cTaskdetailkey = @cNextTaskdetailkey      
      END      
      
      IF @cTTMTasktype = 'PK'      
      BEGIN      
         -- This screen will only be prompt if the QTY to be picked is not full Pallet      
         IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
            WHERE TaskDetailKey = @cTaskdetailkey      
               AND PickMethod <> 'FP')  --FP = full pallet; PP = partial pallet      
         BEGIN      
            SET @nTaskDetail_Qty = 0      
            SET @nOn_HandQty = 0      
            
            SELECT @cTaskStorer = StorerKey,      
               @cID = FromID,      
               @cLoc = FromLOC,      
               @nTaskDetail_Qty = ISNULL(Qty, 0)      
            FROM dbo.TaskDetail WITH (NOLOCK)      
            WHERE TaskDetailKey = @cTaskdetailkey      
      
            -- Get on hand qty      
            SELECT @nOn_HandQty = ISNULL(SUM(QTY - QtyPicked), 0)      
            FROM dbo.LotxLocxID WITH (NOLOCK)      
            WHERE StorerKey = @cTaskStorer      
               AND LOC = @cLoc      
               AND ID = @cID      
      
            IF @nOn_HandQty = 0      
            BEGIN      
               SET @nErrNo = 73951      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --onhandqty=0      
               GOTO QUIT      
            END      
      
            IF @nTaskDetail_Qty = 0      
            BEGIN      
               SET @nErrNo = 73952      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --tdqty=0      
               GOTO QUIT      
            END      
      
            IF @nOn_HandQty > @nTaskDetail_Qty      
            BEGIN      
               SET @nFunc = 1756
               SET @nScn = 2108      
               SET @nStep = 8      
               GOTO Quit      
            END      
         END      
      END      
      
--       SELECT @nToFunc = CAST(ISNULL(RTRIM(SHORT), '0') AS INT)      
--       FROM dbo.CODELKUP WITH (NOLOCK)      
--       WHERE Listname = 'TASKTYPE'      
--       AND   Code = RTRIM(@cTTMTasktype)      
      
      SET @nFunc = 0      
      SET @nScn = 0      
      
      SELECT @nFunc = ISNULL(FUNCTION_ID, 0)      
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)      
      WHERE TaskType = RTRIM(@cTTMTasktype)      
      
      IF @nFunc = 0      
      BEGIN      
         SET @nErrNo = 73953      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr      
         GOTO QUIT      
      END      
      
      SELECT TOP 1 @nScn = Scn      
      FROM RDT.RDTScn WITH (NOLOCK)      
      WHERE Func = @nFunc      
      ORDER BY Scn      
      
      IF @nScn = 0      
      BEGIN      
         SET @nErrNo = 73954      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr      
         GOTO QUIT      
      END      
      
      SELECT @cFromLoc = FromLoc
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey
      
      
    
    GOTO Quit 
    
    RollBackTran: 
    ROLLBACK TRAN TM_GetNextTask 
    
    Quit:    
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started    
          COMMIT TRAN TM_GetNextTask
END

GO
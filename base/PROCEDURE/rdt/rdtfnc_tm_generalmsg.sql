SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*****************************************************************************/  
/* Store procedure: rdtfnc_TM_GeneralMsg                                     */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: RDT Task Manager - General Message                               */  
/*          Called By rdtfnc_TaskManager                                     */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2010-06-17 1.0  KHLim    SOS#189353 Created                               */  
/*****************************************************************************/  

CREATE PROC [RDT].[rdtfnc_TM_GeneralMsg](  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
) AS  
  
-- Misc variable  
DECLARE  
   @b_success           INT  
          
-- Define a variable  
DECLARE    
   @nFunc               INT,  
   @nScn                INT,  
   @nStep               INT,  
   @cLangCode           NVARCHAR(3),  
   @nMenu               INT,  
   @nInputKey           NVARCHAR(3),  
   @cPrinter            NVARCHAR(10),  
   @cUserName           NVARCHAR(18),  
  
   @cStorerKey          NVARCHAR(15),  
   @cFacility           NVARCHAR(5),  
  
   @cAreaKey            NVARCHAR(10),  
   @cStrategykey        NVARCHAR(10),   
   @cTTMStrategykey     NVARCHAR(10),   
   @cTTMTasktype        NVARCHAR(10),  
   @cFromLoc            NVARCHAR(10),  
   @cSuggFromLoc        NVARCHAR(10),  
   @cToLoc              NVARCHAR(10),  
   @cSuggToLoc          NVARCHAR(10),  
   @cTaskdetailkey      NVARCHAR(10),  
   @cID                 NVARCHAR(18),  
   @cSuggID             NVARCHAR(18),  
   @cUOM                NVARCHAR(5),   -- Display NVARCHAR(5)  
   @cReasonCode         NVARCHAR(10),  
   @cSKU                NVARCHAR(20),  
   @cTaskStorer         NVARCHAR(15),  
   @cFromFacility       NVARCHAR(5),  
   @c_outstring         NVARCHAR(255),  
   @cUserPosition       NVARCHAR(10),   
   @cQTY                NVARCHAR(5),  
   @cPackkey            NVARCHAR(10),  
   @cNextTaskdetailkeyS NVARCHAR(10),  
  
   @cRefKey01           NVARCHAR(20),  
   @cRefKey02           NVARCHAR(20),  
   @cRefKey03           NVARCHAR(20),  
   @cRefKey04           NVARCHAR(20),  
   @cRefKey05           NVARCHAR(20),  
  
   @nQTY                INT,  
   @nToFunc             INT,  
   @nSuggQTY            INT,  
   @nFromStep           INT,  
   @nFromScn            INT,  
   @nToScn              INT,  
  
   @nOn_HandQty         INT,  
   @nTTL_Alloc_Qty      INT,  
   @nTaskDetail_Qty     INT,  
   @cLoc                NVARCHAR( 10),  
     
   @cPUOM               NVARCHAR( 1), -- Prefer UOM  
   @cSuggestPQTY        NVARCHAR( 5),  
   @cSuggestMQTY        NVARCHAR( 5),  
   @cActPQTY            NVARCHAR( 5),  
   @cActMQTY            NVARCHAR( 5),  
  
   @nSum_PalletQty      INT,  
   @nActQTY             INT, -- Actual QTY  
   @nSuggestPQTY        INT, -- Suggested master QTY  
   @nSuggestMQTY        INT, -- Suggested prefered QTY  
   @nSuggestQTY         INT, -- Suggetsed QTY  
   @cCaseID             NVARCHAR(10),  
   @cInSKU              NVARCHAR(20),  
   @cLot                NVARCHAR(10),  
   @cComponentSKU       NVARCHAR(20),  
   @n_CaseCnt           INT,  
   @n_TotalPalletQTY    INT,  
   @n_TotalBOMQTY       INT,  
   @c_BOMSKU            NVARCHAR(20),  
   @c_VirtualLoc        NVARCHAR(10),  
   @c_NewTaskDetailkey  NVARCHAR(10),  
   @c_ComponentPackkey  NVARCHAR(10),  
   @c_ComponentPackUOM3 NVARCHAR(5),   
   @cContinueProcess    NVARCHAR(10),
   @i                   int,
   @end                 int,
   @start               int,
   @space               int,
   @length              int,
   @cStatusMsg          NVARCHAR(255),


   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  
  
   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),  
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),  
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),  
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),  
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),  
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),  
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),  
   @cFieldAttr15 NVARCHAR( 1)  
              
-- Getting Mobile information  
SELECT   
   @nFunc            = Func,  
   @nScn             = Scn,  
   @nStep            = Step,  
   @nInputKey        = InputKey,  
   @cLangCode        = Lang_code,  
   @nMenu            = Menu,  
  
   @cFacility        = Facility,  
   @cStorerKey       = StorerKey,  
   @cPrinter         = Printer,   
   @cUserName        = UserName,  
  
   @cSKU             = V_SKU,  
   @cFromLoc         = V_LOC,  
   @cID              = V_ID,  
   @cPUOM            = V_UOM,  
   @nQTY             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,  
   @cLot             = V_Lot,  
   @cCaseID          = V_CaseID,  
  
   @cToLoc           = V_String3,  
   @cReasonCode      = V_String4,  
   @cTaskdetailkey   = V_String5,  
  
   @cSuggFromloc     = V_String6,  
   @cSuggToloc       = V_String7,  
   @cSuggID          = V_String8,  
   @nSuggQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,  
   @cUserPosition    = V_String10,  
        
   @cNextTaskdetailkeyS = V_String12,  
   @cPackkey         = V_String13,  
   @nFromStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END,  
   @nFromScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END,  
   @cTaskStorer      = V_String16,  
  
   @cPUOM            = V_String27,  
  
   @cAreakey         = V_String32,   
   @cTTMStrategykey  = V_String33,   
   @cTTMTasktype     = V_String34,   
   @cRefKey01        = V_String37,   
   @cRefKey02        = V_String38,   
   @cRefKey03        = V_String37,   
   @cRefKey04        = V_String38,   
   @cRefKey05        = V_String39,   
     
   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  
  
   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,  
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,  
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,  
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,  
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,  
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,  
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,  
   @cFieldAttr15 =  FieldAttr15  
  
FROM   RDT.RDTMOBREC (NOLOCK)  
WHERE  Mobile = @nMobile  


-- Redirect to respective screen  
IF @nFunc = 1763  
BEGIN  
   IF @nStep = 1 GOTO Step_1   -- Menu. Func = 1763, Scn = 2550 -- GM  
   IF @nStep = 2 GOTO Step_2   -- Scn = 2109   REASON Screen  
   IF @nStep = 3 GOTO Step_3   -- Scn = 2551   Msg (Enter / Exit)
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 1. Called from Task Manager Main Screen (func = 1763)  
    Screen = 2550  
    Message (Field01)  
********************************************************************************/  
Step_1:  
BEGIN  
   -- Set all variable for 1st record - records are from rdtfnc_TaskManager  

   IF @nInputKey = 1 -- ENTER  
   BEGIN  

      BEGIN TRAN  
      UPDATE dbo.TaskDetail WITH (ROWLOCK)
      SET    EndTime = GETDATE() --CURRENT_TIMESTAMP
            ,EditDate = GETDATE() --CURRENT_TIMESTAMP
            ,EditWho = @cUserName
            ,Status = '9'
            ,UserKey = @cUserName
      WHERE  TaskDetailkey = @cTaskdetailkey  
              
      IF @@ERROR<>0
      BEGIN
          SET @nErrNo = 71191  
          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdTaskFailed'  
          ROLLBACK TRAN 
      END
      ELSE
      BEGIN
          COMMIT TRAN
      END      
        
         -- EventLog - Sign In Function   
      EXEC RDT.rdt_STD_EventLog 
           @cActionType='1'	-- Sign in function
          ,@cUserID=@cUserName
          ,@nMobileNo=@nMobile
          ,@nFunctionID=@nFunc
          ,@cFacility=@cFacility
          ,@cStorerKey=@cStorerKey  

        
      -- prepare next screen  
      SET @cUserPosition = '1'  
        
     -- Go back to Task Manager Main Screen  
--     SET @nFunc   = 1756
--     SET @nScn    = 2100
--     SET @nStep   = 1

      GOTO GETNEXTTASK_R
   END  

  
   SELECT @cTaskStorer  = RTRIM(Storerkey)
         ,@cSKU         = RTRIM(SKU)
         ,@cSuggID      = RTRIM(FromID)
         ,@cSuggToLoc   = RTRIM(ToLOC)
         ,@cLot         = RTRIM(Lot)
         ,@cFromLoc     = RTRIM(FromLoc)
         ,@nSuggQTY     = Qty
         ,@c_BOMSKU     = RTRIM(Sourcekey)
   FROM   dbo.TaskDetail WITH (NOLOCK)
   WHERE  TaskDetailKey = @cTaskdetailkey  


   IF @nInputKey=0 -- ESC
   BEGIN
      -- Go to Reason Code screen
      IF @cUserPosition=''
      BEGIN
         SET @cUserPosition = '1'
      END 

      SET @cOutField01 = '' 
       
      -- Go to Reason Code Screen  
      SET @nScn = 2109  
      SET @nStep = 2

   END
     
   GOTO Quit  
END  
GOTO Quit  

/********************************************************************************  
Step 2. screen = 2109  
     REASON CODE  (Field01, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cReasonCode = @cInField01  
  
      IF @cReasonCode = ''  
      BEGIN  
        SET @nErrNo = 71192 
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason Req  
        GOTO Step_2_Fail    
      END  
  
      -- Update ReasonCode  
      EXEC dbo.nspRFRSN01  
              @c_sendDelimiter = NULL  
           ,  @c_ptcid         = 'RDT'  
           ,  @c_userid        = @cUserName  
           ,  @c_taskId        = 'RDT'  
           ,  @c_databasename  = NULL  
           ,  @c_appflag       = NULL  
           ,  @c_recordType    = NULL  
           ,  @c_server        = NULL  
           ,  @c_ttm           = NULL  
           ,  @c_taskdetailkey = @cTaskdetailkey  
           ,  @c_fromloc       = @cFromLoc  
           ,  @c_fromid        = @cID  
           ,  @c_toloc         = @cSuggToloc  
           ,  @c_toid          = @cID  
           ,  @n_qty           = @nQTY
           ,  @c_packkey       = ''  
           ,  @c_uom           = ''  
           ,  @c_reasoncode    = @cReasonCode  
           ,  @c_outstring     = @c_outstring    OUTPUT  
           ,  @b_Success       = @b_Success      OUTPUT  
           ,  @n_err           = @nErrNo         OUTPUT  
           ,  @c_errmsg        = @cErrMsg        OUTPUT  
           ,  @c_userposition  = @cUserPosition  
  
      IF ISNULL(@cErrMsg, '') <> ''    
      BEGIN  
        SET @cErrMsg = @cErrMsg  
        GOTO Step_2_Fail  
      END   

      SET @nScn = 2551 
      SET @nStep = 3 
  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  

      -- retrieve back OutField01 for StatusMsg
      set @start = 0
      set @end = 0
      set @space = 0
      set @length = 0

      SELECT @cStatusMsg = StatusMsg
		FROM dbo.TaskDetail (NOLOCK) 
		WHERE TaskDetailkey = @cTaskdetailkey

      WHILE @space < @start + 20
      BEGIN
         SET @end = @space
         SET @space = CHARINDEX(' ', @cStatusMsg, @end+1)
      END
      if @end <= @start
      BEGIN
         set @end = @start+ 20
      END
      SET @cOutField01 = substring(@cStatusMsg,@start,@end-@start)
      SET @start = @end+1


      -- go to previous screen  
      SET @nScn = 2550  
      SET @nStep = 1  
         
     --END       
   END  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      SET @cReasonCode = ''  
    
      -- Reset this screen var  
      SET @cOutField01 = ''  
  
   END  
END  
GOTO Quit  

/********************************************************************************  
Step 3. screen = 2551  
     MSG ( EXIT / ENTER ) 
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      
  
      GETNEXTTASK_R:  
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
     ,  @c_lastloc       = @cSuggToLoc  
     ,  @c_lasttasktype  = 'TPA'  
     ,  @c_outstring     = @c_outstring    OUTPUT  
     ,  @b_Success       = @b_Success      OUTPUT  
     ,  @n_err           = @nErrNo         OUTPUT  
     ,  @c_errmsg        = @cErrMsg        OUTPUT  
     ,  @c_taskdetailkey = @cNextTaskdetailkeyS OUTPUT  
     ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT  
     ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func  
     ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func  
     ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func  
     ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func  
     ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func  
  
      IF ISNULL(RTRIM(@cNextTaskdetailkeyS), '') = '' --@nErrNo = 67804 -- Nothing to do!  
      BEGIN  
  
         -- Go back to Task Manager Main Screen  
         SET @nFunc = 1756  
         SET @nScn = 2100  
         SET @nStep = 1  
  
         SET @cErrMsg = 'No More Task'  
         SET @cAreaKey = ''  
        
         SET @cOutField01 = ''  -- Area  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
         SET @cOutField06 = ''  
         SET @cOutField07 = ''  
         SET @cOutField08 = ''  
          
         GOTO QUIT  
          
      END       
  
      IF ISNULL(@cErrMsg, '') <> ''    
      BEGIN  
         SET @cErrMsg = @cErrMsg  
         GOTO QUIT  
      END       

      IF ISNULL(@cNextTaskdetailkeyS, '') <> ''  
      BEGIN  
       
         SELECT @cRefKey03 = CaseID,
                @cRefkey04 = PickMethod 
               ,@cStatusMsg = StatusMsg  -- (KHLim01)
         From  dbo.TaskDetail (NOLOCK)   
         WHERE TaskDetailkey = @cNextTaskdetailkeyS  
          
         SET @cTaskdetailkey = @cNextTaskdetailkeyS  
          
			IF @cTTMTasktype = 'GM' -- (KHLim01)
			BEGIN

            set @start = 0
            set @end = 0
            set @space = 0
            set @length = 0

            set @i = 1
            WHILE @i <= 10
            BEGIN
               WHILE @space < @start + 20
               BEGIN
                  SET @end = @space
                  SET @space = CHARINDEX(' ', @cStatusMsg, @end+1)
               END
               IF @end <= @start
               BEGIN
                  set @end = @start+ 20
               END
               IF       @i =  1 SET @cOutField01 = substring(@cStatusMsg,@start,@end-@start)
               ELSE IF  @i =  2 SET @cOutField02 = substring(@cStatusMsg,@start,@end-@start)
               ELSE IF  @i =  3 SET @cOutField03 = substring(@cStatusMsg,@start,@end-@start)
               ELSE IF  @i =  4 SET @cOutField04 = substring(@cStatusMsg,@start,@end-@start)
               ELSE IF  @i =  5 SET @cOutField05 = substring(@cStatusMsg,@start,@end-@start)
               ELSE IF  @i =  6 SET @cOutField09 = substring(@cStatusMsg,@start,@end-@start)
               ELSE IF  @i =  7 SET @cOutField10 = substring(@cStatusMsg,@start,@end-@start)
               ELSE IF  @i =  8 SET @cOutField11 = substring(@cStatusMsg,@start,@end-@start)
               ELSE IF  @i =  9 SET @cOutField12 = substring(@cStatusMsg,@start,@end-@start)
               ELSE IF  @i = 10 SET @cOutField13 = substring(@cStatusMsg,@start,@end-@start)
               SET @start = @end+1
               SET @i = @i + 1
            END

         END
     END  
     
      SET @nToFunc = 0  
      SET @nToScn = 0  
        
      SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)  
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)  
      WHERE TaskType = RTRIM(@cTTMTasktype)  
     
      IF @nFunc = 0  
      BEGIN  
         SET @nErrNo = 71193  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr  
         GOTO QUIT    
      END  
          
      SELECT TOP 1 @nToScn = Scn   
      FROM RDT.RDTScn WITH (NOLOCK)  
      WHERE Func = @nToFunc  
      ORDER BY Scn  
     
      IF @nToScn = 0  
      BEGIN  
         SET @nErrNo = 71194  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr  
         GOTO QUIT  
      END  
      
	   SET @nFunc     = @nToFunc
	   SET @nScn      = @nToScn
	   SET @nStep     = 1

   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Go back to Task Manager Main Screen  
      SET @nFunc   = 1756
      SET @nScn    = 2100
      SET @nStep   = 1

      --SET @cErrMsg = 'No More Task'  
      SET @cAreaKey = ''  

      SET @cOutField01 = ''  -- Area  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
       
      GOTO QUIT  
   END  
   GOTO Quit  
  
     
END  
GOTO Quit  
  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE RDTMOBREC WITH (ROWLOCK) SET  
       ErrMsg        = @cErrMsg,   
       Func          = @nFunc,  
       Step          = @nStep,              
       Scn           = @nScn,  
  
       StorerKey     = @cStorerKey,  
       Facility      = @cFacility,   
       Printer       = @cPrinter,      
       UserName      = @cUserName,  
  
       V_SKU         = @cSKU,  
       V_LOC         = @cFromloc,  
       V_ID          = @cID,  
       V_UOM         = @cPUOM,  
       V_QTY         = @nQTY,  
       V_Lot         = @cLot,     
       V_CaseID      = @cCaseID,  
  
       V_String3     = @cToloc,  
       V_String4     = @cReasonCode,  
       V_String5     = @cTaskdetailkey,  
        
       V_String6     = @cSuggFromloc,  
       V_String7     = @cSuggToloc,  
       V_String8     = @cSuggID,  
       V_String9     = @nSuggQTY,  
       V_String10    = @cUserPosition,  
       V_String12    = @cNextTaskdetailkeyS,  
       V_String13    = @cPackkey,  
       V_String14    = @nFromStep,  
       V_String15    = @nFromScn,  
       V_String16    = @cTaskStorer,  
  
       V_STRING27    = @cPUOM,  
         
       V_String32  = @cAreakey,           
       V_String33  = @cTTMStrategykey,    
       V_String34  = @cTTMTasktype,       
       V_String35  = @cRefKey01,  
       V_String36  = @cRefKey02,            
       V_String37  = @cRefKey03,          
       V_String38  = @cRefKey04,          
       V_String39  = @cRefKey05,          
  
      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  
  
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,  
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,  
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,  
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,  
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,  
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,  
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,  
      FieldAttr15  = @cFieldAttr15  
  
   WHERE Mobile = @nMobile  
  
END                  

GO
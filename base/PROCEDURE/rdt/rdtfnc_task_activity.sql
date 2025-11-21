SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdtfnc_Task_Activity                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Rev  Author     Purposes                                */  
/* 2009-06-08   1.0  Vicky      Created                                 */  
/* 2016-09-30   1.1  Ung        Performance tuning                      */
/* 2018-11-16   1.2  TungGH     Performance                             */   
/************************************************************************/  
CREATE  PROC [RDT].[rdtfnc_Task_Activity] (  
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
-- Misc variables  
DECLARE  
   @b_success      INT,  
   @n_err          INT,  
   @c_errmsg       NVARCHAR( 250),  
   @i              INT,   
   @nTask          INT,    
   @cParentScn     NVARCHAR( 3),   
   @cOption        NVARCHAR( 1),   
   @cXML           NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc  
  
-- RDT.RDTMobRec variables  
DECLARE  
   @nFunc               INT,  
   @nScn                INT,  
   @nStep               INT,  
   @cLangCode           NVARCHAR( 3),  
   @nInputKey           INT,  
   @nMenu               INT,  
  
   @nPrevScn            INT,  
   @nPrevStep           INT,  
  
   @cStorerKey          NVARCHAR( 15),  
   @cUserName           NVARCHAR( 18),  
   @cFacility           NVARCHAR( 5),  
  
   @cLocation           NVARCHAR( 32),   
   @cUserID             NVARCHAR( 18),   
   @cTaskID             NVARCHAR(  5),  
   @cDescription        NVARCHAR( 40),   
   @cClickCnt           NVARCHAR(  1),  
  
   @cErrMsg1            NVARCHAR(20),  
   @cErrMsg2            NVARCHAR(20),  
   @cErrMsg3            NVARCHAR(20),  
   @cErrMsg4            NVARCHAR(20),  
        
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
   @nMenu            = Menu,  
   @cLangCode        = Lang_code,  
  
   @cStorerKey       = StorerKey,  
   @cFacility        = Facility,  
   @cUserName        = UserName,  
  
  
   @cLocation        = V_LOC,   
   @cClickCnt        = V_String1,  
     
  
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
  
FROM rdt.rdtMobRec (NOLOCK)  
WHERE Mobile = @nMobile  
  
-- Screen constant  
DECLARE   
   @nStep_1          INT,  @nScn_1          INT,    
   @nStep_2          INT,  @nScn_2          INT  
  
SELECT  
   @nStep_1          = 1,  @nScn_1          = 706,    
   @nStep_2          = 2,  @nScn_2          = 707  
  
  
  
IF @nFunc = 702  
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 715  
   IF @nStep = 1  GOTO Step_1           -- Scn = 705. Location  
   IF @nStep = 2  GOTO Step_2           -- Scn = 706. USER ID  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step_Start. Func = 715  
********************************************************************************/  
Step_Start:  
BEGIN  
   
   -- Prepare label screen var  
   SET @cOutField01 = ''  
     
  
   SET @cFieldAttr01 = ''   
   SET @cFieldAttr02 = ''  
   SET @cFieldAttr03 = ''   
   SET @cFieldAttr04 = ''  
   SET @cFieldAttr05 = ''   
   SET @cFieldAttr06 = ''  
   SET @cFieldAttr07 = ''   
   SET @cFieldAttr08 = ''  
   SET @cFieldAttr09 = ''  
   SET @cFieldAttr10 = ''  
   SET @cFieldAttr11 = ''   
   SET @cFieldAttr12 = ''  
   SET @cFieldAttr13 = ''  
   SET @cFieldAttr14 = ''  
   SET @cFieldAttr15 = ''  
  
   SET @cClickCnt = 0  
  
   -- Go to Label screen  
   SET @nScn = @nScn_1  
   SET @nStep = @nStep_1  
   GOTO Quit  
  
   Step_Start_Fail:  
   BEGIN  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- LOC  
   END  
END  
GOTO Quit  
  
  
  
/***********************************************************************************  
Scn = 704. LOC screen  
   Location       (field01)  
***********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
     -- Screen mapping  
     SET @cLocation = @cInField01 -- SKU  
  
--      IF NOT EXISTS (SELECT 1 FROM DBO.LOC WITH (NOLOCK)   
--                     WHERE LOC = @cLocation)  
--      BEGIN  
-- --          SET @nErrNo = 50021  
-- --          SET @cErrMsg = rdt.rdtgetmessage( 50021, @cLangCode, 'DSP') -- LOC NOT EXISTS  
--   
--          SET @nErrNo = 0  
--          SET @cErrMsg1 = '50026'  
--          SET @cErrMsg2 = 'LOC NOT EXISTS'  
--          EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
--             @cErrMsg1, @cErrMsg2  
--          IF @nErrNo = 1  
--          BEGIN  
--             SET @cErrMsg1 = ''  
--             SET @cErrMsg2 = ''  
--          END  
--          GOTO Step_1_Fail  
--      END   
  
--     IF NOT EXISTS (SELECT 1 FROM DBO.SECTION WITH (NOLOCK)   
--                    WHERE SectionKey = @cLocation)  
--     BEGIN  ----          SET @nErrNo = 50022  
----          SET @cErrMsg = rdt.rdtgetmessage( 50022, @cLangCode, 'DSP') --INVLD LOC-SEE SUPV  
--         SET @nErrNo = 0  
--         SET @cErrMsg1 = '50027'  
--         SET @cErrMsg2 = 'INVALID LOC'  
--         SET @cErrMsg3 = 'SEE SUPV'  
--         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
--            @cErrMsg1, @cErrMsg2, @cErrMsg3  
--         IF @nErrNo = 1  
--         BEGIN  
--            SET @cErrMsg1 = ''  
--            SET @cErrMsg2 = ''  
--            SET @cErrMsg3 = ''  
--         END  
--  
--         GOTO Step_1_Fail  
--     END   
  
  
     -- Prep USERID screen var  
     SET @cOutField01 = ''  
  
  
   -- Go to USERID screen  
   SET @nScn = @nScn_2  
   SET @nStep = @nStep_2  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- Option  
      SET @cFieldAttr01 = ''   
      SET @cFieldAttr02 = ''  
      SET @cFieldAttr03 = ''   
      SET @cFieldAttr04 = ''  
      SET @cFieldAttr05 = ''   
      SET @cFieldAttr06 = ''  
      SET @cFieldAttr07 = ''   
      SET @cFieldAttr08 = ''  
      SET @cFieldAttr09 = ''  
      SET @cFieldAttr10 = ''  
      SET @cFieldAttr11 = ''   
      SET @cFieldAttr12 = ''  
      SET @cFieldAttr13 = ''  
      SET @cFieldAttr14 = ''  
      SET @cFieldAttr15 = ''  
   END  
   GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
      SET @cOutField01 = '' -- SKU  
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU  
      GOTO Quit  
   END  
  
END  
GOTO Quit  
  
  
/********************************************************************************  
Scn = 704. USER ID screen  
   USER ID       (field01)  
   TASK ID       (field02)   
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
  
     -- Screen mapping  
     SET @cUserID = @cInField01 -- USER ID  
     SET @cTaskID = @cInField02 -- Task ID  
  
--     IF NOT EXISTS (SELECT 1 FROM DBO.TASKMANAGERUSER WITH (NOLOCK)  
--                    WHERE UserKey = @cUserID)  
--     BEGIN  
--         SET @nErrNo = 0  
--         SET @cErrMsg1 = '50028'  
--         SET @cErrMsg2 = 'INVALID USER ID'  
--         SET @cErrMsg3 = 'PLEASE RESCAN'  
--         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
--            @cErrMsg1, @cErrMsg2, @cErrMsg3  
--         IF @nErrNo = 1  
--         BEGIN  
--            SET @cErrMsg1 = ''  
--            SET @cErrMsg2 = ''  
--            SET @cErrMsg3 = ''  
--         END  
--         GOTO Step_2_ID_Fail  
--     END  
  
     IF NOT EXISTS (SELECT 1 FROM RDT.rdtWATLog WITH (NOLOCK)  
                WHERE UserName = @cUserID  
                AND   Location = @cLocation  
                AND   Module = 'CLK'  
                AND   Status = '0')  
     BEGIN  
         SET @nErrNo = 0  
         SET @cErrMsg1 = '50029'  
         SET @cErrMsg2 = 'CLOCKED-OUT'  
         SET @cErrMsg3 = 'ENTER PLEASE'  
         SET @cErrMsg4 = 'CLOCK-IN'  
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
            @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4  
         IF @nErrNo = 1  
         BEGIN  
            SET @cErrMsg1 = ''  
            SET @cErrMsg2 = ''  
            SET @cErrMsg3 = ''  
            SET @cErrMsg4 = ''  
         END  
         GOTO Step_2_ID_Fail  
     END  
  
--     IF NOT EXISTS (SELECT 1 FROM DBO.CODELKUP WITH (NOLOCK)  
--                    WHERE Code = @cTaskID AND Listname = 'JOBCODE')  
--     BEGIN  
--         SET @nErrNo = 0  
--         SET @cErrMsg1 = '50030'  
--         SET @cErrMsg2 = 'INVALID TASK ID'  
--         SET @cErrMsg3 = 'PLEASE RESCAN'  
--         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
--            @cErrMsg1, @cErrMsg2, @cErrMsg3  
--         IF @nErrNo = 1  
--         BEGIN  
--            SET @cErrMsg1 = ''  
--            SET @cErrMsg2 = ''  
--  SET @cErrMsg3 = ''  
--         END  
--         GOTO Step_2_Task_Fail  
--     END  
      
  
     IF EXISTS (SELECT 1 FROM RDT.rdtWATLog WITH (NOLOCK)  
                    WHERE UserName = @cUserID  
                    AND   Location = @cLocation  
                    AND   TaskCode <> @cTaskID  
                    AND   Module = 'TSK'  
                    AND   Status = '0')  
     BEGIN  
         SET @nErrNo = 0  
         SET @cErrMsg1 = '50031'  
         SET @cErrMsg2 = 'Complete OLD TASK'  
         SET @cErrMsg3 = 'START NEW'  
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
            @cErrMsg1, @cErrMsg2, @cErrMsg3  
         IF @nErrNo = 1  
         BEGIN  
            SET @cErrMsg1 = ''  
            SET @cErrMsg2 = ''  
            SET @cErrMsg3 = ''  
         END  
         GOTO Step_2_Task_Fail  
     END  
     ELSE IF EXISTS (SELECT 1 FROM RDT.rdtWATLog WITH (NOLOCK)  
                     WHERE UserName = @cUserID  
                     AND   Location = @cLocation  
                     AND   TaskCode = @cTaskID  
                     AND   Module = 'TSK'  
                     AND   Status = '0')  
     BEGIN  
         SET @nErrNo = 50032  
         SET @cErrMsg = rdt.rdtgetmessage( 50032, @cLangCode, 'DSP') --END TASK  
  
         SELECT @cDescription = RTRIM(DESCRIPTION)  
         FROM DBO.CODELKUP WITH (NOLOCK)  
         WHERE Code = @cTaskID   
         AND   Listname = 'JOBCODE'  
  
         UPDATE RDT.rdtWATLog  
           SET Status = '9',  
               EndDate = GETDATE()  
           WHERE UserName = @cUserID  
           AND   Location = @cLocation  
           AND   TaskCode = @cTaskID  
           AND   Module = 'TSK'  
           AND   Status = '0'  
  
         GOTO Step_2_Continue  
     END   
     BEGIN  
         SET @nErrNo = 50033  
         SET @cErrMsg = rdt.rdtgetmessage( 50033, @cLangCode, 'DSP') --STARTING TASK  
  
         SELECT @cDescription = RTRIM(DESCRIPTION)  
         FROM DBO.CODELKUP WITH (NOLOCK)  
         WHERE Code = @cTaskID   
         AND   Listname = 'JOBCODE'  
  
         INSERT INTO RDT.rdtWATLog (Module, UserName, Location, TaskCode, Description, EndDate)  
         VALUES ('TSK', @cUserID, @cLocation, @cTaskID, @cDescription, '')  
     
         GOTO Step_2_Continue  
     END  
       
  
--      -- Initialize  
--      SET @cUserID = ''  
--      SET @cOutField01 = ''  
  
      -- Screen mapping  
      SET @nScn = @nScn  
    SET @nStep = @nStep  
   END   
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare SKU screen var  
      SET @cOutField01 = '' -- LOC  
      SET @cLocation = ''  
  
      SET @cFieldAttr01 = ''   
      SET @cFieldAttr02 = ''  
      SET @cFieldAttr03 = ''   
      SET @cFieldAttr04 = ''  
      SET @cFieldAttr05 = ''   
      SET @cFieldAttr06 = ''  
      SET @cFieldAttr07 = ''   
      SET @cFieldAttr08 = ''  
      SET @cFieldAttr09 = ''  
      SET @cFieldAttr10 = ''  
      SET @cFieldAttr11 = ''   
      SET @cFieldAttr12 = ''  
      SET @cFieldAttr13 = ''  
      SET @cFieldAttr14 = ''  
      SET @cFieldAttr15 = ''  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU  
  
      -- Go to prev screen  
      SET @nScn = @nScn_1  
      SET @nStep = @nStep_1  
   END  
   GOTO Quit  
  
   Step_2_Continue:  
   BEGIN  
      SET @cOutField01 = '' -- UserID  
      SET @cOutField02 = '' -- Task ID  
      SET @cOutField03 = Substring(@cDescription, 1, 20)  
      SET @cOutField04 = Substring(@cDescription, 21, 20)  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
      SET @nScn = @nScn  
    SET @nStep = @nStep  
      GOTO Quit  
   END  
  
   Step_2_ID_Fail:  
   BEGIN  
      SET @cOutField01 = '' -- UserID  
      SET @cOutField02 = '' -- UserID  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
      GOTO Quit  
   END  
  
   Step_2_Task_Fail:  
   BEGIN  
      SET @cOutField01 = @cUserID -- UserID  
      SET @cOutField02 = '' -- TaskID  
      SET @cOutField03 = '' -- Descr  
      SET @cOutField04 = '' -- Descr  
      EXEC rdt.rdtSetFocusField @nMobile, 2  
      GOTO Quit  
   END  
  
   Step_2_Task2_Fail:  
   BEGIN  
      SET @cOutField01 = '' -- UserID  
      SET @cOutField02 = '' -- TaskID  
      SET @cOutField03 = '' -- Descr  
      SET @cOutField04 = '' -- Descr  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
      GOTO Quit  
   END  
  
 END  
GOTO Quit  
  
  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET  
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,  
      Func   = @nFunc,  
      Step   = @nStep,  
      Scn    = @nScn,  
  
      StorerKey      = @cStorerKey,  
      Facility       = @cFacility,  
      -- UserName       = @cUserName,  
  
      V_LOC          = @cLocation,   
      V_String1      = @cClickCnt,  
       
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
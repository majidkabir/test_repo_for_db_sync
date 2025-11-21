SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/*****************************************************************************/  
/* Store procedure: rdtfnc_Staging_Lane_Release                              */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: SOS#173268 - Standard/Generic Scan To Door module                */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2010-05-20 1.0  Vicky    Created                                          */  
/* 2016-09-30 1.1  Ung      Performance tuning                               */
/* 2018-11-13 1.2  TungGH   Performance                                      */   
/*****************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_Staging_Lane_Release](  
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
  
   @cLane               NVARCHAR(20),  
   @cEmptyFlag          NVARCHAR(1),  
   @cLoadkey            NVARCHAR(10),  
   @cOrderkey           NVARCHAR(10),  
  
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
  
   @cLoadkey         = V_Loadkey,  
   @cOrderkey        = V_Orderkey,  
   @cLane            = V_String1,  
   @cEmptyFlag       = V_String2,  
        
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
  
FROM   RDTMOBREC (NOLOCK)  
WHERE  Mobile = @nMobile  
  
-- Redirect to respective screen  
IF @nFunc = 1753  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1753  
   IF @nStep = 1 GOTO Step_1   -- Scn = 2340  Staging Lane  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 1753)  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn  = 2340  
   SET @nStep = 1  
  
    -- EventLog - Sign In Function  
    EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep
  
   -- initialise all variable  
   SET @cLane = ''  
   SET @cEmptyFlag = 'Y'  
   SET @cLoadkey = ''  
   SET @cOrderkey = ''  
  
   -- Prep next screen var     
   SET @cOutField01 = ''   
   SET @cOutField02 = ''   
END  
GOTO Quit  
  
/********************************************************************************  
Step 1. screen = 2340  
   STAGING LANE (Field01, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cLane = @cInField01  
  
      --When Lane is blank  
      IF @cLane = ''  
      BEGIN  
         SET @nErrNo = 69441  
         SET @cErrMsg = rdt.rdtgetmessage( 69441, @cLangCode, 'DSP') --Lane req  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail    
      END   
  
      --Lane Exists  
      IF NOT EXISTS (SELECT 1 FROM DBO.LOC WITH (NOLOCK) WHERE LOC = @cLane AND LocationCategory = 'STAGING')  
      BEGIN  
             SET @nErrNo = 69442  
             SET @cErrMsg = rdt.rdtgetmessage( 69442, @cLangCode, 'DSP') --Invalid Lane  
             EXEC rdt.rdtSetFocusField @nMobile, 1  
             GOTO Step_1_Fail    
      END  
  
      -- Check whether there's still outstanding pallet in Lane  
      IF EXISTS (SELECT 1 FROM DBO.DROPID WITH (NOLOCK) WHERE DropLOC = @cLane   
                 AND ISNULL(RTRIM(AdditionalLOC), '') = '' AND Status = '9')  
      BEGIN  
             SET @cEmptyFlag = 'N'  
  
             SET @nErrNo = 69443  
             SET @cErrMsg = rdt.rdtgetmessage( 69443, @cLangCode, 'DSP') --Lane Not Empty  
             EXEC rdt.rdtSetFocusField @nMobile, 1  
             GOTO Step_1_Fail    
      END  
  
      -- Check whether being assigned to other load  
      IF @cEmptyFlag = 'Y'  
      BEGIN  
        SELECT DISTINCT Loadkey INTO #TempLoad FROM DBO.DROPID WITH (NOLOCK)   
        WHERE DropLOC = @cLane   
        AND ISNULL(RTRIM(AdditionalLOC), '') <> ''   
        AND Status = '9'  
  
        IF EXISTS (SELECT 1 FROM DBO.LOADPLANLANEDETAIL WITH (NOLOCK)  
                   WHERE LOC = @cLane AND LocationCategory = 'STAGING'  
                   AND Status <> '9' AND Loadkey NOT IN (SELECT Loadkey FROM #TempLoad))  
        BEGIN  
             SET @cEmptyFlag = 'N'  
  
             SET @nErrNo = 69444  
             SET @cErrMsg = rdt.rdtgetmessage( 69444, @cLangCode, 'DSP') --Lane Assigned to LP  
             EXEC rdt.rdtSetFocusField @nMobile, 1  
             GOTO Step_1_Fail    
        END  
        ELSE  
        BEGIN  
           BEGIN TRAN  
  
           UPDATE DBO.LOADPLANLANEDETAIL WITH (ROWLOCK)  
             SET Status = '9'  
           WHERE LOC = @cLane  
           AND LocationCategory = 'STAGING'  
           AND Status <> '9'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 69445  
               SET @cErrMsg = rdt.rdtgetmessage( 69445, @cLangCode, 'DSP') --'Upd LoadPlanLaneDet Fail'  
           ROLLBACK TRAN   
           GOTO QUIT  
            END  
            ELSE  
            BEGIN  
             COMMIT TRAN   
               SET @cErrMsg = 'Lane Released'  
            END  
  
           -- insert to Eventlog  
           EXEC RDT.rdt_STD_EventLog  
               @cActionType   = '15', -- Tracking  
               @cUserID       = @cUserName,  
               @nMobileNo     = @nMobile,  
               @nFunctionID   = @nFunc,  
               @cFacility     = @cFacility,  
               @cStorerKey    = @cStorerkey,  
               @cLane         = @cLane,
               @nStep         = @nStep  
         END  
       END  
         
        
      --prepare next screen variable  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
  
      SET @cLane = ''  
      SET @cEmptyFlag = 'Y'  
                           
      SET @nScn = @nScn  
      SET @nStep = @nStep  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- EventLog - Sign Out Function  
      EXEC RDT.rdt_STD_EventLog  
       @cActionType = '9', -- Sign Out function  
       @cUserID     = @cUserName,  
       @nMobileNo   = @nMobile,  
       @nFunctionID = @nFunc,  
       @cFacility   = @cFacility,  
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep  
  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''   
  
      SET @cLane = ''  
      SET @cEmptyFlag = ''  
   END  
   GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
      SET @cLane = ''  
      SET @cEmptyFlag = ''  
  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
    END  
END  
GOTO Quit  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE RDTMOBREC WITH (ROWLOCK) SET  
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg,   
       Func          = @nFunc,  
       Step          = @nStep,              
       Scn           = @nScn,  
  
       StorerKey     = @cStorerKey,  
       Facility      = @cFacility,   
       Printer       = @cPrinter,      
       -- UserName      = @cUserName,  
  
       V_Loadkey     = @cLoadkey,  
       V_Orderkey    = @cOrderkey,  
       V_String1     = @cLane,  
       V_String2     = @cEmptyFlag,  
  
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
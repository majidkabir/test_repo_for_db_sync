SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Tote_ConveyerMove_Single                          */
/* Copyright      : LF Logistics                                             */
/*                                                                           */
/* Purpose: Allow User to Scan the Tote and Send Instruction to WCS to move  */
/*          to specified station.                                            */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2014-05-08 1.0  ChewKP   Created                                          */
/* 2016-09-30 1.1  Ung      Performance tuning                               */   
/* 2017-05-22 1.2  James    Add config to use Codelkup.Code for station      */
/*                          instead of Codelkup.Short (james01)              */
/* 2018-11-15 1.3  Gan      Performance tuning                               */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_Tote_ConveyerMove_Single](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

   SET NOCOUNT ON                  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF   
   
-- Misc variable
DECLARE
   @bSuccess           INT
        
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

   @cToteNo             NVARCHAR(20),
   @cCaseID             NVARCHAR(18),                
   @cStation            NVARCHAR(10),
   @cWCSKey             NVARCHAR(10),
   @cFinalLoc           NVARCHAR(10),
   @nStationCnt         INT, 
   @cStation1           NVARCHAR(10), 
   @cStation2           NVARCHAR(10), 
   @cStation3           NVARCHAR(10), 
   @cStation4           NVARCHAR(10), 
   @cStation5           NVARCHAR(10), 
   @cStation6           NVARCHAR(10), 
   @cStation7           NVARCHAR(10), 
   @cWCSStation         NVARCHAR(10), 
   @cOption             NVARCHAR(1), 
   @cInit_Final_Zone    NVARCHAR(10), 
   @cFinalWCSZone       NVARCHAR(10), 
   @nCount              INT,
   @c_ActionFlag        NVARCHAR(1),
   @b_success           INT,
   @cSuggWCSStation     NVARCHAR(10),   
   @cSQL                NVARCHAR(1000), 
   @cSQLParam           NVARCHAR(1000), 
   @cExtendedValidateSP NVARCHAR(30),   
   @cExtendedUpdateSP   NVARCHAR(30),   
   @cTaskDetailKey      NVARCHAR(10),
   @cRefNo01            NVARCHAR(60),
   @cRefNo02            NVARCHAR(60),
   @cRefNo03            NVARCHAR(60),
   @cRefNo04            NVARCHAR(60),
   @cRefNo05            NVARCHAR(60),
   @bdebug              INT,  
   @cUseCodeAsStation   NVARCHAR(1),   -- (james01)
   

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
   
   @nStationCnt      = V_Integer1,

   @cCaseID          = V_ID,
   @cStation         = V_String1,
   @cToteNo          = V_String2,
  -- @nStationCnt      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
   @cStation1        = V_String4,
   @cStation2        = V_String5,
   @cStation3        = V_String6,
   @cStation4        = V_String7,
   @cStation5        = V_String8,
   @cStation6        = V_String9,
   @cStation7        = V_String10,
   @cExtendedValidateSP = V_String11, 
   @cExtendedUpdateSP   = V_String12, 
   @cUseCodeAsStation   = V_String13,

         
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
IF @nFunc = 1810
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1810
   IF @nStep = 1 GOTO Step_1   -- Scn = 3900  Tote No
   IF @nStep = 2 GOTO Step_2   -- Scn = 3901  Station
   
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1777)
********************************************************************************/
Step_0:
BEGIN
  
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
   BEGIN
      SET @cExtendedValidateSP = ''
   END
   
   
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
   BEGIN
      SET @cExtendedUpdateSP = ''
   END

   SET @cUseCodeAsStation = rdt.RDTGetConfig( @nFunc, 'UseCodeAsStation', @cStorerKey)
   
   -- Set the entry point
   SET @nScn  = 3900
   SET @nStep = 1

   -- initialise all variable
   SET @cToteNo = ''
   SET @cCaseID = ''
   SET @cStation = ''
   SET @cSuggWCSStation = ''

   -- Prep next screen var   
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 
   SET @cOutField03 = '' 
   SET @cOutField04 = '' 
   SET @cOutField05 = '' 
   SET @cOutField06 = '' 
   SET @cOutField07 = '' 
   SET @cOutField08 = '' 
   SET @cOutField09 = '' 
   SET @cOutField10 = '' 
   SET @cOutField11 = '' 
END
GOTO Quit

/********************************************************************************
Step 1. screen = 3900
   TOTE NO (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToteNo = @cInField01
      SET @cCaseID = ''
      


      IF ISNULL(@cToteNo, '') = ''         
      BEGIN                
         SET @nErrNo = 90201                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CASE/TOTE req                
         EXEC rdt.rdtSetFocusField @nMobile, 1                
         GOTO Step_1_Fail                
      END                
                

      -- TOTE validation
      IF ISNULL(@cToteNo, '') <> ''   
      BEGIN
         IF ISNUMERIC(@cToteNo) = 0            
         BEGIN            
            SET @nErrNo = 90202                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID TOTENO                
            EXEC rdt.rdtSetFocusField @nMobile, 1                
            GOTO Step_1_Fail                
         END            
      
      END


      -- Extended Validate SP 
      IF @cExtendedValidateSP <> ''
      BEGIN
         
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            
              
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteNo, @cSuggWCSStation OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cToteNo        NVARCHAR( 20), ' +
               '@cSuggWCSStation NVARCHAR( 10) OUTPUT, ' +
               '@nErrNo         INT           OUTPUT, ' + 
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
               
           
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteNo, @cSuggWCSStation OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
--            IF @nErrNo <> 0 
--            BEGIN
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --
--               GOTO Step_1_Fail 
--            END
      
         END
      END   

      -- Prev next screen
      SET @cOutField01 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN 'TOTE NO:' ELSE 'CASE ID:' END
      SET @cOutField02 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN @cToteNo ELSE @cCaseID END 
      SET @cOutField03 = @cSuggWCSStation
      SET @cOutField04 = '1' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' 
      SET @cOutField11 = '' 

      SET @cStation = ''
      SET @cStation1 = ''
      SET @cStation2 = ''
      SET @cStation3 = ''
      SET @cStation4 = ''
      SET @cStation5 = ''
      SET @cStation6 = ''
      SET @cStation7 = ''
      SET @nStationCnt = 0

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      
     
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' 
      SET @cOutField11 = '' 

      SET @cToteNo = ''
      SET @cCaseID = ''
      SET @cStation = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cToteNo = ''
      SET @cCaseID = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 2. screen = 3901
   Tote    (field01)
   Station (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      SET @cStation = @cInField03
      SET @cOption = @cInField04

      IF ISNULL(RTRIM(@cStation), '') = '' AND @cOption = '1'
      BEGIN
         SET @nErrNo = 90203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Station Req
         GOTO Step_2_Fail  
      END
      
      IF @cOption = '1' 
      BEGIN
         IF @cUseCodeAsStation <> '1'  -- (james01)
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM CODELKUP c WITH (NOLOCK) WHERE c.LISTNAME = 'WCSSTATION' AND C.Short = @cStation)
            BEGIN
               SET @nErrNo = 90204
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD Station
               GOTO Step_2_Fail  
            END
         END
         ELSE
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM CODELKUP c WITH (NOLOCK) WHERE c.LISTNAME = 'WCSSTATION' AND C.Code = @cStation)
            BEGIN
               SET @nErrNo = 90212
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD Station
               GOTO Step_2_Fail  
            END
         END
      END
      
       IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 90205
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --Opt required 
         GOTO Step_2_Fail      
      END      

      -- Check if option is valid
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 90206
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --Inv Option 
         GOTO Step_2_Fail      
      END     
      
      IF @cOption = '1'
      BEGIN
         SET @c_ActionFlag = 'N'
      END
      ELSE
      BEGIN
         SET @c_ActionFlag = 'D'
      END
      
      IF @cExtendedUpdateSP <> ''
      BEGIN
            
            -- IF From Tote Conveyor Move -- 
            -- Update previous Tote WCSRouting record to status = '9'
            UPDATE dbo.WCSRouting WITH (ROWLOCK)
            SET Status = '9'
            WHERE ToteNo = @cToteNo
            AND Status <> '9'
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 90208
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --UpdWCSRouteFail
               GOTO Step_2_Fail      
            END
            
            -- Update previous Tote WCSRouting record to status = '9'
            UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)
            SET Status = '9'
            WHERE ToteNo = @cToteNo
            AND Status <> '9'
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 90209
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --UpdWCSRouteDetFail
               GOTO Step_2_Fail      
            END
            
            
            
            
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cRefNo01 = @cStation

               SET @cSQL = 'EXEC dbo.' + RTRIM( @cExtendedUpdateSP) +
                  ' @c_StorerKey    
                    , @c_Facility     
                    , @c_ToteNo       
                    , @c_TaskType     
                    , @c_ActionFlag   
                    , @c_TaskDetailKey
                    , @c_Username     
                    , @c_RefNo01      
                    , @c_RefNo02      
                    , @c_RefNo03      
                    , @c_RefNo04      
                    , @c_RefNo05      
                    , @b_debug        
                    , @c_LangCode     
                    , @n_Func         
                    , @b_Success      
                    , @n_ErrNo     OUTPUT   
                    , @c_ErrMsg    OUTPUT     '
                    
               SET @cSQLParam =
                  ' @c_StorerKey     NVARCHAR(15) ,        ' +              
                  ' @c_Facility      NVARCHAR(10) ,        ' +              
                  ' @c_ToteNo        NVARCHAR(20) ,        ' +              
                  ' @c_TaskType      NVARCHAR(10) ,        ' + -- TaskType = 1777 = Direct from RDT Tote Conveyor Move  
                  ' @c_ActionFlag    NVARCHAR(1)  ,        ' + -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual, C = Complete      
                  ' @c_TaskDetailKey NVARCHAR(10) ,        ' +          
                  ' @c_Username      NVARCHAR(18) ,        ' + 
                  ' @c_RefNo01       NVARCHAR(60) ,        ' + -- WCSTATION if direct from 1777  
                  ' @c_RefNo02       NVARCHAR(60) ,        ' +
                  ' @c_RefNo03       NVARCHAR(60) ,        ' +
                  ' @c_RefNo04       NVARCHAR(60) ,        ' +
                  ' @c_RefNo05       NVARCHAR(60) ,        ' +
                  ' @b_debug         INT          ,        ' +
                  ' @c_LangCode      NVARCHAR(3)  ,        ' +
                  ' @n_Func          INT          ,        ' +         
                  ' @b_Success       INT         OUTPUT,   ' +           
                  ' @n_ErrNo         INT         OUTPUT,   ' +         
                  ' @c_ErrMsg        NVARCHAR(20) OUTPUT   ' 
                  
      
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @cStorerKey    
                     , @cFacility     
                     , @cToteNo       
                     , @nFunc     
                     , @c_ActionFlag   
                     , @cTaskDetailKey
                     , @cUsername     
                     , @cRefNo01      
                     , @cRefNo02      
                     , @cRefNo03      
                     , @cRefNo04      
                     , @cRefNo05      
                     , @bdebug        
                     , @cLangCode     
                     , @nFunc         
                     , @bSuccess      
                     , @nErrNo   OUTPUT
                     , @cErrMsg  OUTPUT     
      
               IF @nErrNo <> 0 
                  GOTO QUIT
                  
            END
      END  

                                 
                                 
      IF @nErrNo <> 0            
      BEGIN
             GOTO Step_2_Fail  
      END


      SET @cOutField03 = ''

      SET @nScn = @nScn 
      SET @nStep = @nStep 

      -- Message to Show Move Sent
      SET @nErrNo = 90207
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --RouteCreated
      

      
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Update WCSRouting -- 
      UPDATE dbo.WCSRouting WITH (ROWLOCK)
      SET Status = '9'
      WHERE ToteNo = @cToteNo
      AND Status <> '9'
      
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 90210
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --UpdWCSRouteFail
         GOTO Step_2_Fail      
      END
      
      -- Update previous Tote WCSRouting record to status = '9'
      UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)
      SET Status = '9'
      WHERE ToteNo = @cToteNo
      AND Status <> '9'
      
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 90211
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --UpdWCSRouteDetFail
         GOTO Step_2_Fail      
      END
      
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOption = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END  
   GOTO Quit
   
   Step_2_Fail:
   BEGIN
      SET @cOutField01 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN 'TOTE NO:' ELSE 'CASE ID:' END
      SET @cOutField02 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN @cToteNo ELSE @cCaseID END 
      SET @cOutField03 = ''        
      SET @cOutField04 = '1'   

      SET @cStation = ''
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
      EditDate      = GETDATE(), 
      ErrMsg        = @cErrMsg, 
      Func          = @nFunc,
      Step          = @nStep,            
      Scn           = @nScn,

      StorerKey     = @cStorerKey,
      Facility      = @cFacility, 
      Printer       = @cPrinter,    
      -- UserName      = @cUserName,
      
      V_Integer1    = @nStationCnt,

      V_ID          = @cCaseID,       
      V_String1     = @cStation,  
      V_String2     = @cToteNo,   
      --V_String3     = @nStationCnt,
      V_String4     = @cStation1,
      V_String5     = @cStation2,
      V_String6     = @cStation3,
      V_String7     = @cStation4,
      V_String8     = @cStation5,
      V_String9     = @cStation6,
      V_String10    = @cStation7,
      V_String11    = @cExtendedValidateSP, 
      V_String12    = @cExtendedUpdateSP, 
      V_String13    = @cUseCodeAsStation,
      
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
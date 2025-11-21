SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_MoveByDropID_Drop                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Replenishment                                           */
/*          SOS93812 - Move By Drop ID                                  */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2012-05-23 1.0  Ung      Created                                     */
/* 2012-05-23 1.1  James    Del FromDropID header (james01)             */
/*                          If the Dropid has no more child id then del */
/*                          Add eventlog                                */
/* 2012-05-31 1.2  Ung      SOS245688 Add MoveByDropIDDropCheckStatus   */
/* 2012-09-26 1.3  Ung      SOS257128 Add Split pallet                  */
/* 2014-12-18 1.4  ChewKP   SOS#327678 -- Add Extended Update (ChewKP01)*/
/* 2016-09-30 1.5  Ung      Performance tuning                          */
/* 2018-11-02 1.6  Gan      Performance tuning                          */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_MoveByDropID_Drop] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE @cChildID NVARCHAR( 20)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cUserName   NVARCHAR(18),
   @cPrinter    NVARCHAR(10),

   @cFromDropID NVARCHAR( 20),
   @cToDropID   NVARCHAR( 20),
   @cMergePLT   NVARCHAR( 1),
   @cScanned    NVARCHAR( 5), 
   @cMoveByDropIDDropExtValidate NVARCHAR( 20), 
   @cNewToDropID NVARCHAR( 1), 
   @cSQL                NVARCHAR(1000), 
   @cSQLParam           NVARCHAR(1000), 
   @cExtendedUpdateSP   NVARCHAR(30),      

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,
   @cPrinter    = Printer,

   @cFromDropID = V_String1,
   @cToDropID   = V_String2,
   @cMergePLT   = V_String3,
   @cScanned    = V_String4,
   @cMoveByDropIDDropExtValidate = V_String6,
   @cNewToDropID = V_String7, 
   @cExtendedUpdateSP = V_String8,  
   
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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 525
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 525
   IF @nStep = 1 GOTO Step_1   -- Scn = 3110. From DropID
   IF @nStep = 2 GOTO Step_2   -- Scn = 3112. To Drop ID, merge pallet
   IF @nStep = 3 GOTO Step_3   -- Scn = 3112. ChildID
   IF @nStep = 4 GOTO Step_4   -- Scn = 3113. Option. To new dropID?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3110
   SET @nStep = 1

   -- Init var

   -- Get StorerConfig
   SET @cMoveByDropIDDropExtValidate = rdt.RDTGetConfig( 525, 'MoveByDropIDDropExtValidate', @cStorerKey)
   IF @cMoveByDropIDDropExtValidate = '0'
      SET @cMoveByDropIDDropExtValidate = ''
   
   -- (ChewKP01)   
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)  
   IF @cExtendedUpdateSP = '0'    
   BEGIN  
      SET @cExtendedUpdateSP = ''  
   END  
   
   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Prep next screen var
   SET @cFromDropID = ''
   SET @cMergePLT = 1
   SET @cOutField01 = ''  -- From DropID
   SET @cOutField02 = '1' -- Merge Pallet

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

   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 2960
   FROM DROPID   (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromDropID = @cInField01
      SET @cMergePLT = @cInField02

      -- Validate blank
      IF @cFromDropID = ''
      BEGIN
         SET @nErrNo = 64101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID needed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Check if valid DropID
      IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cFromDropID)
      BEGIN
         SET @nErrNo = 64102
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DropID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- (ChewKP01)
      IF @cMoveByDropIDDropExtValidate = '' 
      BEGIN
         -- Check DropID status
         IF EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cFromDropID AND Status = '9')
         BEGIN
            SET @nErrNo = 64103
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Status
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      END

      SET @cNewToDropID = 'N'

      -- Prep next screen var
      SET @cOutField01 = @cFromDropID
      SET @cOutField02 = '' -- ToDropID
      SET @cOutField03 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 2 --ToDropID
      
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Logging
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
      SET @cOutField01 = '' -- Clean up for menu option

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
      SET @cFromDropID = ''
      SET @cOutField01 = ''
      SET @cOutField02 = '1'
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 2961
   FROM DROPID     (Field01)
   TO DROPID       (Field12, input)
   MERGE PALLET:   (Field03, input)
   1 = Yes 2 = No
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToDropID = @cInField02
      SET @cMergePLT = @cInField03

      IF @cInField02 <> @cOutField02
         SET @cNewToDropID = 'N'

      -- Validate blank
      IF @cToDropID = ''
      BEGIN
         SET @nErrNo = 64104
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TO DROPID
         GOTO Step_2_Fail
      END
      
      -- Check from DropID = To DropID
      IF @cFromDropID = @cToDropID
      BEGIN
         SET @nErrNo = 64105
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BothDropIDSame
         GOTO Step_2_Fail
      END
         
      -- Validate ToDropID
      IF @cNewToDropID = 'N'
      BEGIN
         -- Check if new ToDropID
         IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToDropID)
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = ''
   
            -- Go to option screen
            SET @nScn  = @nScn + 2
            SET @nStep = @nStep + 2
   
            GOTO Quit
         END

          -- (ChewKP01)
         IF @cMoveByDropIDDropExtValidate = '' 
         BEGIN
            -- Check DropID status
            IF EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToDropID AND Status = '9')
            BEGIN
               SET @nErrNo = 64106
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Status
               GOTO Step_1_Fail
            END

            -- Check DropLOC different
            IF (SELECT DropLOC FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cFromDropID) <> 
               (SELECT DropLOC FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToDropID) 
            BEGIN
               SET @nErrNo = 64107
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropLOC Diff
               GOTO Step_2_Fail
            END
         END 

         
         -- Check extended validation
         IF @cMoveByDropIDDropExtValidate <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMoveByDropIDDropExtValidate AND type = 'P')
            BEGIN
          
   
               SET @cSQL = 'EXEC ' + RTRIM( @cMoveByDropIDDropExtValidate) + ' @cLangCode, @cFromDropID, @cToDropID, @cChildID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@cLangCode    NVARCHAR( 30), ' + 
                  '@cFromDropID  NVARCHAR( 20), ' +
                  '@cToDropID    NVARCHAR( 20), ' +
                  '@cChildID     NVARCHAR( 25), ' +
                  '@nErrNo       INT OUTPUT, ' +
                  '@cErrMsg      NVARCHAR( 20) OUTPUT'
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam
                  ,@cLangCode
                  ,@cFromDropID
                  ,@cToDropID
                  ,@cChildID
                  ,@nErrNo  OUTPUT
                  ,@cErrMsg OUTPUT
                  
               IF @nErrNo <> 0
                  GOTO Step_2_Fail
            END
         END
      END

      -- Retain ToDropID
      SET @cOutField02 = @cToDropID

      -- Validate Option is blank
      IF @cMergePLT = ''
      BEGIN
         SET @nErrNo = 64108
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END

      -- Validate Option
      IF @cMergePLT NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 64109
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END

      -- Merge by pallet
      IF @cMergePLT = '1'
      BEGIN
         
         IF @cExtendedUpdateSP = ''  
         BEGIN  
            
            DECLARE @nTranCount INT
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN
            SAVE TRAN rdtfnc_MoveByDropID_Pack
            
            -- DropIDDetail
            DECLARE curDropIDDetail CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT ChildID FROM dbo.DropIDDetail WITH (NOLOCK) 
               WHERE DropID = @cFromDropID
            OPEN curDropIDDetail 
            FETCH NEXT FROM curDropIDDetail INTO @cChildID
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE DropIDDetail WITH (ROWLOCK) SET
                  DropID = @cToDropID
               WHERE DropID = @cFromDropID
                  AND ChildID = @cChildID
               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN rdtfnc_MoveByDropID_Pack
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN
   
                  SET @nErrNo = 64110
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DID Fail
                  CLOSE curDropIDDetail
                  DEALLOCATE curDropIDDetail
                  GOTO Quit
               END
               ELSE
               BEGIN
                 EXEC RDT.rdt_STD_EventLog
                    @cActionType   = '4', -- Move
                    @cUserID       = @cUserName,
                    @nMobileNo     = @nMobile,
                    @nFunctionID   = @nFunc,
                    @cFacility     = @cFacility,
                    @cStorerKey    = @cStorerkey,
                    @cID           = @cFromDropID,
                    @cToID         = @cToDropID, 
                    @cChildID      = @cChildID,
                    --@cRefNo1       = @cChildID ,
                    @nStep         = @nStep
               END
               
               FETCH NEXT FROM curDropIDDetail INTO @cChildID
            END
            CLOSE curDropIDDetail
            DEALLOCATE curDropIDDetail
   
            -- DropID
            IF @cNewToDropID = 'Y'
            BEGIN
               UPDATE DropID WITH (ROWLOCK) SET
                  DropID = @cToDropID
               WHERE DropID = @cFromDropID
               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN rdtfnc_MoveByDropID_Pack
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN
                  SET @nErrNo = 64111
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DID Fail
                  GOTO Quit
               END
            END
            ELSE
            BEGIN
               -- Remove the from dropid  (james01)
               DELETE DropID WHERE DropID = @cFromDropID
               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN rdtfnc_MoveByDropID_Pack
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN
                  SET @nErrNo = 64112
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL DID Fail
                  GOTO Quit
               END
            END
               
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
         END
         ELSE IF @cExtendedUpdateSP <> '' -- (ChewKP01)
         BEGIN
                IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
                BEGIN  
                     
                   SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
                      ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cFromDropID, @cToDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
                   SET @cSQLParam =  
                      '@nMobile          INT, ' +  
                      '@nFunc            INT, ' +  
                      '@cLangCode        NVARCHAR( 3),  ' +  
                      '@cUserName          NVARCHAR( 18), ' +  
                      '@cFacility        NVARCHAR( 5),  ' +  
                      '@cStorerKey       NVARCHAR( 15), ' +  
                      '@nStep            INT,           ' +  
                      '@cFromDropID      NVARCHAR( 20), ' +  
                      '@cToDropID        NVARCHAR( 20), ' +  
                      '@nErrNo           INT           OUTPUT, ' +   
                      '@cErrMsg          NVARCHAR( 20) OUTPUT'  
                        
           
                   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                      @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cFromDropID, @cToDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT
           
                   IF @nErrNo <> 0   
                      GOTO Step_2_Fail  
                        
                END  
         END
         
         -- Prep next screen var
         SET @cOutField01 = '' -- Option

         -- Back to FromDropID screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
         
         DECLARE @cErrMsg1 NVARCHAR( 20)
         SET @cErrMsg1 = rdt.rdtgetmessage( 64120, @cLangCode, 'DSP') --MERGE SUCCESSFUL
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
      END

      -- Merge by carton
      IF @cMergePLT = '2'
      BEGIN
         SET @cScanned = '0'
         SET @cOutField01 = @cToDropID
         SET @cOutField02 = '' -- SKU
         SET @cOutField03 = @cScanned

         -- Go to SKU/UPC screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cFromDropID = ''
      SET @cOutField01 = '' --FromDropID

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cToDropID = ''
      SET @cOutField12 = '' -- To DropID
      EXEC rdt.rdtSetFocusField @nMobile, 2 --ToDropID
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen 2962
   TO DROPID:   (Field01)
   CARTON:      (Field02, input)
   SCANNED:     (Field03)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cChildID = @cInField02

      -- Validate blank
      IF @cChildID = ''
      BEGIN
         SET @nErrNo = 64113
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ChildID needed
         GOTO Step_3_Fail
      END

      -- Check if child ID exists in FromDropID
      IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cFromDropID AND ChildID = @cChildID)
      BEGIN
         SET @nErrNo = 64114
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidChildID
         GOTO Step_3_Fail
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdtfnc_MoveByDropID_Pack

      -- Insert DropID
      IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToDropID) AND @cNewToDropID = 'Y'
      BEGIN
         INSERT INTO dbo.DropID (Dropid, Droploc, AdditionalLoc, DropIDType, LabelPrinted, ManifestPrinted, Status, Loadkey, PickSlipNo)
         SELECT @cToDropID, Droploc, AdditionalLoc, DropIDType, LabelPrinted, ManifestPrinted, Status, Loadkey, PickSlipNo
         FROM dbo.DropID WITH (NOLOCK)
         WHERE DropID = @cFromDropID
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_MoveByDropID_Pack
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            SET @nErrNo = 64115
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS DID Fail
            GOTO Step_3_Fail
         END
      END
            
      -- Move carton to ToDropID
      UPDATE DropIDDetail WITH (ROWLOCK) SET
         DropID = @cToDropID
      WHERE DropID = @cFromDropID
         AND ChildID = @cChildID
      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_MoveByDropID_Pack
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         SET @nErrNo = 64116
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DIDtl Fail
         GOTO Step_3_Fail
      END
      
      -- Last carton on the pallet, delete the dropid header (james01)
      IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cFromDropID) 
      BEGIN
         DELETE DropID WHERE DropID = @cFromDropID
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_MoveByDropID_Pack
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            SET @nErrNo = 64117
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL DID Fail
            GOTO Quit
         END
      END

      -- Event log
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cID           = @cFromDropID,
         @cToID         = @cToDropID, 
         @cChildID      = @cChildID,
         --@cRefNo1       = @cChildID 
         @nStep         = @nStep
      
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN
               
      SET @cScanned = CAST( @cScanned AS INT) + 1

      -- Remain in current screen
      SET @cChildID = ''
      SET @cOutField01 = @cToDropID
      SET @cOutField02 = ''
      SET @cOutField03 = @cScanned

      -- Remain in current screen
      -- SET @nScn  = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cNewToDropID = 'N'
      SET @cOutField01 = @cFromDropID
      SET @cOutField02 = ''
      SET @cOutField03 = @cMergePLT

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- FromDropID
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cChildID = ''
      SET @cOutField02 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen 3113
   OPTION:   (Field01)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 1)
      
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 64118
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
         GOTO Step_4_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 64119
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_4_Fail
      END

      IF @cOption = '1'
      BEGIN
         SET @cNewToDropID = 'Y'
         SET @cMergePLT = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3 --MergePLT
      END
      ELSE
      BEGIN
         SET @cNewToDropID = 'N'
         SET @cToDropID = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 --ToDropID
      END

      -- Prepare prev screen var
      SET @cOutField01 = @cFromDropID
      SET @cOutField02 = @cToDropID
      SET @cOutField03 = @cMergePLT

      -- Remain in current screen
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cFromDropID
      SET @cOutField02 = @cToDropID
      SET @cOutField03 = @cMergePLT

      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,
      -- UserName   = @cUserName,-- (Vicky06)
      Printer    = @cPrinter,

      V_String1  = @cFromDropID,
      V_String2  = @cToDropID,
      V_String3  = @cMergePLT,
      V_String4  = @cScanned,
      V_String6  = @cMoveByDropIDDropExtValidate, 
      V_String7  = @cNewToDropID, 
      V_string8  = @cExtendedUpdateSP,

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
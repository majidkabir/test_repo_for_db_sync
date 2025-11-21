SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_Trolley_Build_UCC                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-07-22 1.0  Chermaine  WMS14257. Created                         */
/************************************************************************/
CREATE PROC [RDT].[rdtfnc_Trolley_Build_UCC] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cTrolleyPos      NVARCHAR( 4), 
   @cSQL             NVARCHAR(1000),
   @cSQLParam        NVARCHAR(1000),
   @cOption          NVARCHAR(1)   

-- rdt.rdtMobRec variable
DECLARE
   @nFunc             INT,
   @nScn              INT,
   @nStep             INT,
   @nMenu             INT,
   @cLangCode         NVARCHAR( 3),
   @nInputKey         INT,
                      
   @cStorerKey        NVARCHAR( 15),
   @cFacility         NVARCHAR( 5),
   @cUserName         NVARCHAR(18),
   @cPrinter          NVARCHAR( 10),
                      
   @cUCC              CHAR (20), 
   @cSuggestedLOC     NVARCHAR( 10),
   @cSuggestedID      NVARCHAR( 18),
   @cPutawayZone      NVARCHAR( 10),
   @cTaskDetailKey    NVARCHAR( 10), 
   @cTrolleyNo        NVARCHAR( 10),
   @cExtendedValidateSP NVARCHAR( 20),
   @nUccCount         INT,

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

   @cFieldAttr01 NVARCHAR( 1),
   @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1),
   @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,
   @nInputKey  = InputKey,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cUCC          = V_UCC, 
   @cSuggestedLOC = V_LOC,
   @cSuggestedID  = V_ID,
   @cPutawayZone  = V_Zone,
   @cTaskDetailKey = V_TaskDetailKey, 

   @cTrolleyNo          = V_String1,
   @cExtendedValidateSP = V_String2,
   @cTrolleyPos         = V_String3,
   
   @nUccCount       = V_Integer1,
   
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

   @cFieldAttr01 = FieldAttr01,
   @cFieldAttr02 = FieldAttr02,
   @cFieldAttr03 = FieldAttr03,
   @cFieldAttr04 = FieldAttr04,
   @cFieldAttr05 = FieldAttr05

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc in (1843)
BEGIN
   IF @nStep = 0 GOTO Step_0  -- Menu. Func = 1843
   IF @nStep = 1 GOTO Step_1  -- Scn = 5770. UCC
   --IF @nStep = 2 GOTO Step_2  -- Scn = 5771. PWAYZONE, LOC
   IF @nStep = 2 GOTO Step_2  -- Scn = 5771. Option. Close trolley
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Func = 1843
********************************************************************************/
Step_0:
BEGIN
   -- Init var
   SET @cUCC = ''
   SET @nUccCount = 0

   ---- Get storer config
   --SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   --IF @cExtendedValidateSP = '0'
   --   SET @cExtendedValidateSP = ''

   -- Sign-in
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign in function
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @nStep           = @nStep

   -- Go to next screen
   SET @nScn = 5770
   SET @nStep = 1

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 5770
   UCC       (field01, input)
   UCC ON TROLLEY (field02, input)
   TrolleyNo (field03, input)
   OPTION    (field04, input)
********************************************************************************/
Step_1: 
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField01
      SET @cTrolleyNo = @cInField03 --TrolleyNo
      SET @cOption = @cInField03 --Option

      -- Check blank
      IF @cUCC = '' AND @cTrolleyNo = ''
      BEGIN    	
      	SET @nErrNo = 155351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC or Trolley
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
         GOTO Step_1_Fail
      END

      -- UCC
      IF @cUCC <> ''
      BEGIN
         -- Check UCC
         IF NOT EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cUCC AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 155354
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC not exist
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
            GOTO Step_1_Fail
         END
         
         -- Check UCC valid
         IF NOT EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                        WHERE UCCNo = @cUCC 
                        AND   StorerKey = @cStorerKey 
                        AND   Status IN ('1', '3')) 
         BEGIN
            SET @nErrNo = 155355
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad UCC status
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
            GOTO Step_1_Fail
         END
         
         -- Check UCC scanned
         IF EXISTS( SELECT 1 FROM rdt.rdtTrolleyLog WITH (NOLOCK) WHERE UCCNo = @cUCC)
         BEGIN
            SET @nErrNo = 155356
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
            GOTO Step_1_Fail
         END
         ELSE
         BEGIN
         	SELECT @cTrolleyPos = ISNULL( MAX( Position), '')
            FROM rdt.rdtTrolleyLog WITH (NOLOCK)
            WHERE AddWho = @cUserName
            AND TrolleyNo = ''
      
            -- Increase trolley position
            IF @cTrolleyPos = ''
               SET @cTrolleyPos = '1'
            ELSE
               SET @cTrolleyPos = @cTrolleyPos + 1
               
            DECLARE @cSKU NVARCHAR( 20)
            DECLARE @cLOT NVARCHAR( 10)
            DECLARE @cLOC NVARCHAR( 10)
            DECLARE @cID  NVARCHAR( 18)
            DECLARE @cUOM NVARCHAR( 10)
            DECLARE @nQTY INT
   
            -- Get UCC info
            SELECT TOP 1 
               @cSKU = SKU, 
               @cLOT = LOT, 
               @cLOC = LOC, 
               @cID = ID, 
               @nQTY = QTY
            FROM dbo.UCC WITH (NOLOCK)
            WHERE UCCNo = @cUCC 
               AND StorerKey = @cStorerKey
               AND Status = '1'
   
            -- Get UCC assigned PickDetail
            SET @cTaskDetailKey = ''
            SELECT TOP 1 
               @cTaskDetailKey = TaskDetailKey, 
               @cUOM = UOM
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
               AND Status < '9' -- Exclude cancel order that ship out and generate ASN, and re-receive the same UCC
               AND DropID = @cUCC
               
            IF @cTaskDetailKey = ''
            BEGIN
               SET @nErrNo = 155357
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC NotOnPKDtl
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
               GOTO Step_1_Fail
            END

            -- Get UCC assigned TaskDetail LOC
            SET @cSuggestedLOC = ''
            SET @cSuggestedID = ''
            SELECT 
               @cSuggestedLOC = CASE WHEN FinalLOC <> '' THEN FinalLOC ELSE ToLOC END, 
               @cSuggestedID  = CASE WHEN FinalLOC <> '' THEN FinalID  ELSE ToID END
            FROM dbo.TaskDetail WITH (NOLOCK) 
            WHERE TaskDetailKey = @cTaskDetailKey 
            --IF @cSuggestedLOC = ''
            --BEGIN
            --   SET @nErrNo = 155358
            --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoUCCAssignLOC
            --   GOTO Step_1_Fail
            --END
         
         	-- Insert log
            INSERT INTO rdt.rdtTrolleyLog (TrolleyNo, Position, UCCNo, LOC, ID, Status, TaskDetailKey)
            VALUES ('', @cTrolleyPos, @cUCC, @cSuggestedLOC, @cSuggestedID, '0', @cTaskDetailKey)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 155359
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- INS Log Fail
               GOTO Step_1_Fail
            END
            
            select @nUccCount = COUNT(position) FROM rdt.rdtTrolleyLog WITH (NOLOCK) WHERE AddWho = @cUserName AND trolleyNo = ''
           
            -- EventLog
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '4', -- Move
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerkey,
               @cUCC          = @cUCC, 
               @cDevicePosition = @cTrolleyPos
               
             SET @cOutField01 = ''
             SET @cOutField02 = @nUccCount
         END
      END

      -- TrolleyNo
      IF @cTrolleyNo <> ''
      BEGIN
         ---- Check trolley valid
         --IF NOT EXISTS( SELECT 1 FROM rdt.rdtTrolleyLog WITH (NOLOCK) WHERE TrolleyNo = @cTrolleyNo)
         --BEGIN
         --   SET @nErrNo = 155360
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Bad Trolley No
         --   EXEC rdt.rdtSetFocusField @nMobile, 2 -- TrolleyNo
         --   SET @cOutField02 = '' -- TrolleyNo
         --   GOTO Step_1_Fail
         --END

         -- Check trolley closed
         IF EXISTS( SELECT 1 FROM rdt.rdtTrolleyLog WITH (NOLOCK) WHERE TrolleyNo = @cTrolleyNo AND Status = '1')
         BEGIN
            SET @nErrNo = 155361
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Trolley closed
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- TrolleyNo
            SET @cOutField02 = '' -- TrolleyNo
            GOTO Step_1_Fail
         END
         
         IF NOT EXISTS ( SELECT 1 FROM DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cTrolleyNo)
         BEGIN
            SET @nErrNo = 155401
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Bad TrolleyNo 
            SET @cOutField02 = '' -- TrolleyNo
            GOTO Step_1_Fail
         END
         
         Update rdt.rdtTrolleyLog SET 
            TrolleyNo = @cTrolleyNo
         WHERE TrolleyNo = ''
         AND AddWho = @cUserName
      
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155362
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UPD Log Fail
            GOTO Step_1_Fail
         END
              
         -- Prepare next screen var
         SET @cOutField01 = @nUccCount
         SET @cOutField02 = ''
   
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey
         
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cTrolleyNo = ''
      SET @cOutField01 = '' -- UCC
   END
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 5771. Message. Close trolley?
   TROLLEY POS (field01)
   OPTION      (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField02 -- Option

      -- Check option blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 155365
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- OptionRequired
         GOTO Step_2_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 155366
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Option
         GOTO Step_2_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Update rdtTrolleyLog
         UPDATE rdt.rdtTrolleyLog SET 
            Status = '1' 
         WHERE TrolleyNo = @cTrolleyNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155367
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Log Fail
            GOTO Step_2_Fail
         END

         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cDeviceID     = @cTrolleyNo, 
            @cRefNo4       = 'CLOSE',
            @nStep         = @nStep
      END
   END

   -- Go to UCC screen
   SET @cUCC = ''
   SET @cTrolleyNo = ''
   SET @cOption = ''
   SET @cOutField01 = '' -- UCC
   SET @cOutField02 = @nUccCount -- TrolleyNo
   SET @cOutField03 = '' -- Option
   EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC

   -- Go to prev screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1

   GOTO Quit

   Step_2_Fail:
      SET @cOption = ''
      SET @cOutField02 = '' --Option
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

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      Printer   = @cPrinter,
      -- UserName  = @cUserName,

      V_UCC     = @cUCC, 
      V_LOC     = @cSuggestedLOC,
      V_ID      = @cSuggestedID,
      V_Zone    = @cPutawayZone,
      V_TaskDetailKey = @cTaskDetailKey, 

      V_String1 = @cTrolleyNo,
      V_String2 = @cExtendedValidateSP,
      V_String3 = @cTrolleyPos,
      
      V_Integer1 = @nUccCount,

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

      FieldAttr01  = @cFieldAttr01,
      FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,
      FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05

   WHERE Mobile = @nMobile
END

GO
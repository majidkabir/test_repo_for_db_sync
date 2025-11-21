SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_SortLaneLoc                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-01-04 1.0  Ung        SOS265198 Created                         */
/* 2013-12-09 1.1  Ung        SOS297221 Add build pallet by Load        */
/* 2014-01-29 1.2  Ung        SOS300988 Add EventLog                    */
/* 2014-05-21 1.3  Ung        SOS311570 Support TBL XDock               */
/* 2014-09-25 1.4  Ung        SOS321840 Fix carton built on 2 pallets   */
/* 2016-09-30 1.5  Ung        Performance tuning                        */  
/* 2016-11-03 1.6  Ung        Performance tuning                        */  
/* 2018-10-02 1.7  Gan        Performance tuning                        */
/* 2018-10-18 1.8  LZG        Tune to fix CN lag issue in Step 3 (ZG01) */
/* 2018-10-23 1.9  James      WMS-6789 Add refno lookup                 */
/*                            Add ExtendedGetLocSP (james01)            */
/* 2019-03-29 2.0  James      Bug fix when user key in ID (james02)     */
/************************************************************************/
CREATE PROC [RDT].[rdtfnc_SortLaneLoc] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
-- DECLARE

-- rdt.rdtMobRec variable
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @nMenu         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,

   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cUserName     NVARCHAR(18),
   @cPrinter      NVARCHAR( 10),

   @cLOC          NVARCHAR( 10),
   @cLabelNo      NVARCHAR( 20),
   @cPickSlipNo   NVARCHAR( 10),
   @cOrderKey     NVARCHAR( 10), 
   @cLoadKey      NVARCHAR( 10), 

   @cLane         NVARCHAR( 10),
   @cSuggID       NVARCHAR( 18),
   @cID           NVARCHAR( 18),
   @cLastCarton   NVARCHAR( 1), 
   @cOption       NVARCHAR( 1),
   @cRefNo        NVARCHAR( 20),
   @cColumnName   NVARCHAR( 20),
   @cExtendedGetLocSP   NVARCHAR( 20),
   @tVar          VariableTable,
   @cSQL          NVARCHAR( MAX),
   @cSQLParam     NVARCHAR( MAX),
   @n_Err         INT,
   @nRowCount     INT,

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

   @cLOC        = V_LOC,
   @cLabelNo    = V_CaseID,
   @cPickSlipNo = V_PickSlipNo, 
   @cOrderKey   = V_OrderKey, 
   @cLoadKey    = V_LoadKey, 

   @cLane       = V_String1,
   @cSuggID     = V_String2,   
   @cID         = V_String3,   
   @cLastCarton = V_String4,   
   @cExtendedGetLocSP = V_String5,
   @cRefNo      = V_String6,   

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

IF @nFunc in (545)
BEGIN
   IF @nStep = 0 GOTO Step_0  -- Menu. Func = 545
   IF @nStep = 1 GOTO Step_1  -- Scn = 3380. Lane
   IF @nStep = 2 GOTO Step_2  -- Scn = 3381. LabelNo
   IF @nStep = 3 GOTO Step_3  -- Scn = 3382. LOC, ID
   IF @nStep = 4 GOTO Step_4  -- Scn = 3383. Option. Close pallet
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Func = 850~855
********************************************************************************/
Step_0:
BEGIN
   SET @cExtendedGetLocSP = rdt.RDTGetConfig( @nFunc, 'ExtendedGetLocSP', @cStorerKey)
   IF @cExtendedGetLocSP = '0'
      SET @cExtendedGetLocSP = ''

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @nStep           = @nStep
   
   -- Init var
   SET @cLane = ''

   -- Get storer config

   -- Go to next screen
   SET @nScn = 3380
   SET @nStep = 1

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3380
   Lane (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLane = @cInField01 --Lane

      -- Check blank
      IF @cLane = ''
      BEGIN
         SET @nErrNo = 78751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Lane required
         GOTO Step_1_Fail
      END

      -- Check lane valid
      IF NOT EXISTS( SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK) WHERE Lane = @cLane)
      BEGIN
         SET @nErrNo = 78752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Lane
         GOTO Step_1_Fail
      END
      
      -- Prepare next screen var
      SET @cOutField01 = @cLane
      SET @cOutField02 = '' -- LabelNo
      SET @cOutField03 = '' -- ID
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 2 --LabelNo
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
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep
      
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cLane = ''
      SET @cOutField01 = '' --Lane
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3381. LabelNo screen
   Lane     (field01)
   LabelNo  (field02, input)
   ID       (field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes OR Send
   BEGIN
      -- Screen mapping
      SET @cLabelNo = @cInField02 --LabelNo
      SET @cID = @cInField03 --ID
      SET @cRefNo = @cInField04

      -- Check blank
      IF @cLabelNo = '' AND @cID = '' AND @cRefNo = ''
      BEGIN
         SET @nErrNo = 78753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need Value
         GOTO Quit
      END

      -- Check both key-in
      IF @cLabelNo <> '' AND @cID <> '' AND @cRefNo <> ''
      BEGIN
         SET @nErrNo = 78754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Key-in either
         GOTO Quit
      END

      -- Check ref no
      IF @cRefNo <> '' AND @cLabelNo = ''
      BEGIN
         -- Get storer config
         DECLARE @cFieldName NVARCHAR(20)
         SET @cFieldName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)
         
         -- Get lookup field data type
         DECLARE @cDataType NVARCHAR(128)
         SET @cDataType = ''
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'PackDetail' AND COLUMN_NAME = @cFieldName
         
         IF @cDataType <> ''
         BEGIN
            IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE
            IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE 
            IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE 
            IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)
                              
            -- Check data type
            IF @n_Err = 0
            BEGIN
               SET @nErrNo = 78769
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
               GOTO Quit
            END
            
            DECLARE @tPack TABLE
            (
               RowRef     INT IDENTITY( 1, 1),
               LabelNo    NVARCHAR( 20) NOT NULL
            )
   
            SET @cSQL = 
               ' SELECT TOP 1 LabelNo ' + 
               ' FROM dbo.PackDetail PD WITH (NOLOCK) ' + 
               ' JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)' + 
               ' WHERE PD.StorerKey = ' + QUOTENAME( @cStorerKey, '''') + 
                  ' AND ISNULL( ' + @cFieldName + CASE WHEN @cDataType IN ('int', 'float') THEN ',0)' ELSE ','''')' END + ' = ' + QUOTENAME( @cRefNo, '''') + 
               ' ORDER BY LabelNo ' 
   
            -- Get ASN by RefNo
            INSERT INTO @tPack (LabelNo)
            EXEC (@cSQL)
            SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
            IF @nErrNo <> 0
               GOTO Quit
   
            -- Check RefNo in PackDetail
            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 78770
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack Not Found
               GOTO Quit
            END

            SELECT @cLabelNo = LabelNo FROM @tPack
         END
         ELSE
         BEGIN
            -- Lookup field is SP
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cColumnName AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cColumnName) +
                  ' @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey, @cRefNo, @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@cFacility     NVARCHAR( 5),  ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cRefNo        NVARCHAR( 20), ' +
                  '@cLabelNo      NVARCHAR( 20) OUTPUT, ' +
                  '@nErrNo        INT           OUTPUT, ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT  '
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey, @cRefNo, @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
               IF @nErrNo <> 0
                  GOTO Quit
            END            
         END
      END

      -- LabelNo
      IF @cLabelNo <> ''
      BEGIN
         -- Check labelno valid
         IF NOT EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cLabelNo)
         BEGIN
            SET @nErrNo = 78755
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Bad LabelNo
            GOTO Step_2_Fail
         END
         
         -- Check double scan
         IF EXISTS( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE ChildID = @cLabelNo)
         BEGIN
            SET @nErrNo = 78756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LabelNoScanned
            GOTO Step_2_Fail
         END

         -- Get pack info
         SELECT 
            @cOrderKey = PH.OrderKey, 
            @cPickSlipNo = PH.PickSlipNo
         FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.LabelNo = @cLabelNo

         -- Get Order info
         DECLARE @cOrderType NVARCHAR( 2)
         DECLARE @cSOStatus NVARCHAR( 10)
         SELECT 
            @cOrderType = CASE WHEN RIGHT( Type, 2) = '-X' THEN 'XD' ELSE '' END, 
            @cLoadKey = LoadKey, 
            @cSOStatus = SOStatus
         FROM Orders WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey

         -- Check LabelNo belong to lane
         IF NOT EXISTS( SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Door = @cLane)
         BEGIN
            SET @nErrNo = 78757
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Different Lane
            GOTO Step_2_Fail
         END

         -- Extended get loc
         SET @cLOC = ''
         SET @cSuggID = ''
         IF @cExtendedGetLocSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedGetLocSP AND type = 'P')
            BEGIN
               INSERT INTO @tVar (Variable, Value) VALUES 
                  ('@cLane',     @cLane), 
                  ('@cLabelNo',  @cLabelNo), 
                  ('@cID',       @cID), 
                  ('@cLoadKey',  @cLoadKey), 
                  ('@cOrderKey', @cOrderKey), 
                  ('@cOption',   @cOption)

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedGetLocSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
                  ' @cLOC OUTPUT, @cSuggID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nAfterStep     INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cFacility      NVARCHAR( 5),  ' + 
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @tVar           VariableTable READONLY, ' + 
                  ' @cLOC           NVARCHAR( 10) OUTPUT,   ' + 
                  ' @cSuggID        NVARCHAR( 18) OUTPUT,   ' + 
                  ' @nErrNo         INT           OUTPUT,   ' +
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, 3, @nInputKey, @cFacility, @cStorerKey, @tVar, 
                  @cLOC OUTPUT, @cSuggID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Get existing LOC, ID
            IF @cOrderType = 'XD' OR @cSOStatus IN ('CANC', 'HOLD')
            BEGIN
               -- Cancel or hold order build pallet by order
               SET @cLoadKey = ''
               SELECT TOP 1 
                  @cLOC = LOC, 
                  @cSuggID = ID
               FROM rdt.rdtSortLaneLocLog WITH (NOLOCK) 
               WHERE Lane = @cLane 
                  AND OrderKey = @cOrderKey 
                  AND Status = '1' -- In-use
            END
            ELSE
            BEGIN
               -- Normal order build pallet by load
               SET @cOrderKey = ''
               SELECT TOP 1 
                  @cLOC = LOC, 
                  @cSuggID = ID
               FROM rdt.rdtSortLaneLocLog WITH (NOLOCK) 
               WHERE Lane = @cLane 
                  AND LoadKey = @cLoadKey 
                  AND Status = '1' -- In-use
            END
            
            -- Get available empty LOC
            IF @cLOC = ''
            BEGIN
               -- Lock a LOC
               UPDATE TOP (1) rdt.rdtSortLaneLocLog SET
                  OrderKey = @cOrderKey, 
                  LoadKey  = @cLoadKey, 
                  Status   = '1', -- In-use
                  @cLOC    = LOC  -- Retrieve LOC used
               WHERE Lane = @cLane 
                  AND Status = '0'
               SELECT @nRowCount = @@ROWCOUNT, @nErrNo = @@ERROR
               
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 78758
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Lock LOC fail
                  GOTO Step_2_Fail
               END
               
               -- Check LOC available
               IF @nRowCount <> 1
               BEGIN
                  SET @nErrNo = 78759
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- No avail LOC
                  GOTO Step_2_Fail
               END
               
               -- SELECT FROM rdt.rdtSortLaneLocLog WITH (NOLOCK) WHERE Lane = @cLane AND OrderKey = @cOrderKey 
            END
         END

         -- Prep next screen var
         SET @cOutField01 = @cLane
         SET @cOutField02 = @cLabelNo
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cSuggID
         SET @cOutField05 = '' --ID
      
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      
      -- ID
      IF @cID <> ''
      BEGIN
         -- Get LOC info  
         SET @cLOC = ''
         SELECT @cLOC = LOC
         FROM rdt.rdtSortLaneLocLog WITH (NOLOCK)   
         WHERE Lane = @cLane   
            AND ID = @cID  

         -- Check ID valid 
         IF @cLOC = ''
         BEGIN
            SET @nErrNo = 78760
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid ID
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- ID
            SET @cOutField03 = '' -- ID
            GOTO Quit
         END
         
         -- Prep next screen var
         SET @cOutField01 = '' --Option
   
         -- Go to close pallet screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      -- Reset prev screen var
      SET @cLane = ''
      SET @cOutField01 = '' -- Lane

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
      SET @cLabelNo = ''
      SET @cOutField02 = '' --LabelNo
      EXEC rdt.rdtSetFocusField @nMobile, 2 --LabelNo
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 3382. LOC, ID screen
   Lane     (field01)
   LabelNo  (field02)
   LOC      (field03)
   SuggID   (field04)
   ID       (field05, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cID = @cInField05 -- ID

      -- Check blank
      IF @cID = ''
      BEGIN
         SET @nErrNo = 78761
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LabelNo Needed
         GOTO Step_3_Fail
      END

      -- Check format
      IF LEFT( @cID, 1) <> 'P'
      BEGIN
         SET @nErrNo = 78767
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid format
         GOTO Step_3_Fail
      END

      -- Check valid
      IF @cSuggID = ''
      BEGIN
         -- Check reuse pallet ID
         IF EXISTS( SELECT 1 FROM DropID WITH (NOLOCK) WHERE DropID = @cID)
         BEGIN
            SET @nErrNo = 78766
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not new ID
            GOTO Step_3_Fail
         END
         
         -- Check double scan
         -- ESC back from close pallet screen, scan a new pallet ID
         IF EXISTS( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE ChildID = @cLabelNo)
         BEGIN
            SET @nErrNo = 78768
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- CTNAdyBuiltPLT
            GOTO Step_2_Fail
         END
      END
      ELSE
      BEGIN
         -- Check valid
         IF @cID <> @cSuggID
         BEGIN
            SET @nErrNo = 78762
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Different ID
            GOTO Step_3_Fail
         END
      END
      
      -- Build pallet
      EXEC rdt.rdt_SortLaneLoc_Confirm @nMobile, @nFunc, @cLangCode, @cUserName
         ,@cStorerKey
         ,@cFacility
         ,@cLane      
         ,@cLOC       
         ,@cID         
         ,@cLabelNo   
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      /*
      Last carton logic:
      1. If not fully pack (PickDetail.Status = 0 or 4), definitely not last carton
      2. If fully pallet build (all PackDetail and DropIDDetail records created), it is last carton
      */      

      IF @cOrderKey <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND RIGHT( Type, 2) = '-X') -- XDock order
         BEGIN
            -- 1. Check Pick vs Pack QTY
            DECLARE @nPackQTY INT
            DECLARE @nPickQTY INT
            SELECT @nPackQTY = ISNULL( SUM( QTY), 0) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0) FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> '4'
            IF @nPackQTY <> @nPickQTY
               SET @cLastCarton = 'N'
            ELSE
               -- 2. Check any label not yet printed
               IF EXISTS( SELECT TOP 1 1 
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                     LEFT JOIN dbo.DropIDDetail DID WITH (NOLOCK) ON (PD.LabelNo = DID.ChildID)
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND DID.ChildID IS NULL)
                  SET @cLastCarton = 'N'
               ELSE
                  SET @cLastCarton = 'Y'
         END
         ELSE
         BEGIN
            -- 1. Check outstanding PickDetail
            IF EXISTS( SELECT TOP 1 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND (Status IN ('0', '4') AND QTY > 0))
               SET @cLastCarton = 'N' 
            ELSE
               -- 2. Check any label not yet printed
               IF EXISTS( SELECT TOP 1 1 
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                     LEFT JOIN dbo.DropIDDetail DID WITH (NOLOCK) ON (PD.LabelNo = DID.ChildID)
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND DID.ChildID IS NULL)
                  SET @cLastCarton = 'N'
               ELSE
                  SET @cLastCarton = 'Y'
         END
      END
      ELSE
      BEGIN
         -- 1. Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1
            FROM LoadPlanDetail LD WITH (NOLOCK)
               JOIN OrderDetail OD WITH (NOLOCK) ON OD.orderkey = LD.orderkey
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            WHERE LD.LoadKey = @cLoadKey
               AND PD.Status IN ('0', '4'))
            SET @cLastCarton = 'N'
         ELSE
            -- 2. Check any label not yet printed
            IF EXISTS( SELECT TOP 1 1
               FROM LoadPlanDetail LD WITH (NOLOCK)
               JOIN Orders O WITH (NOLOCK) ON O.orderkey = LD.orderkey
                  JOIN dbo.PackHeader PH WITH (NOLOCK, INDEX=IDX_PackHeader_orderkey) ON (PH.OrderKey = O.OrderKey)
                     JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                  LEFT JOIN dbo.DropIDDetail DID WITH (NOLOCK) ON (PD.LabelNo = DID.ChildID)
               WHERE LD.LoadKey = @cLoadKey
                  AND DID.ChildID IS NULL)
               SET @cLastCarton = 'N'
            ELSE
               SET @cLastCarton = 'Y'
      END

      -- Close pallet if last carton
      IF @cLastCarton = 'Y'
      BEGIN
         -- Go to close pallet screen
         SET @cOutField01 = '' -- Option
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         -- Go to labelno screen
         SET @cOutField01 = @cLane
         SET @cOutField02 = '' --LabelNo
         SET @cOutField03 = '' --ID
         
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Release LOC if not using
      IF EXISTS( SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK) 
         WHERE Lane = @cLane 
            AND LOC = @cLOC
            -- AND OrderKey <> ''
            AND Status = '1' -- In-use
            AND ID = '')
      BEGIN
         UPDATE rdt.rdtSortLaneLocLog SET
            OrderKey = '', 
            LoadKey  = '', 
            Status   = '0', -- Not using
            ID       = ''
         WHERE Lane = @cLane 
            AND LOC = @cLOC
            AND Status = '1'
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 78763
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UPD Log Fail
            GOTO Quit
         END
      END      

      -- Prepare next screen var
      SET @cOutField01 = @cLane
      SET @cOutField02 = '' --LabelNo
      SET @cOutField03 = '' --ID

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 2 --LabelNo
   END
   GOTO Quit

   Step_3_Fail:
      SET @cID = ''
      SET @cOutField05 = '' --ID
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 3382. Close pallet screen
   Close pallet
   1=Yes
   2=No
   OPTION (field01)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes OR Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01 -- Option

      -- Check option blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 78764
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- OptionRequired
         GOTO Step_4_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 78765
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Option
         GOTO Step_4_Fail
      END

      -- Close pallet
      IF @cOption = '1'
      BEGIN
         EXEC rdt.rdt_SortLaneLoc_ClosePallet @nMobile, @nFunc, @cLangCode, @cUserName
            ,@cStorerKey
            ,@cFacility
            ,@cLane      
            ,@cLOC       
            ,@cID         
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
      
      -- Prep next screen var
      SET @cLabelNo = ''
      SET @cOutField01 = @cLane
      SET @cOutField02 = '' -- LabelNo
      SET @cOutField03 = '' -- ID

      -- Go to labelno screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
      
      EXEC rdt.rdtSetFocusField @nMobile, 2 --LabelNo
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      IF @cLabelNo = ''
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cLane
         SET @cOutField02 = '' --@cLabelNo
         SET @cOutField03 = '' --@cID
   
         -- Go to Lable/ID screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2

         EXEC rdt.rdtSetFocusField @nMobile, 2 --LabelNo
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cLane
         SET @cOutField02 = @cLabelNo
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cSuggID
         SET @cOutField05 = '' -- ID
   
         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   GOTO Quit

   Step_4_Fail:
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

      V_LOC        = @cLOC,
      V_CaseID     = @cLabelNo,
      V_PickSlipNo = @cPickSlipNo, 
      V_OrderKey   = @cOrderKey, 
      V_LoadKey    = @cLoadKey, 

      V_String1 = @cLane,
      V_String2 = @cSuggID,
      V_String3 = @cID,
      V_String4 = @cLastCarton, 
      V_String5 = @cExtendedGetLocSP,
      V_String6 = @cRefNo,   

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
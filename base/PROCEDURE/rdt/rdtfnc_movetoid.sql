SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_MoveToID                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2013-01-08 1.0  Ung      SOS265133 Created                           */
/* 2016-06-13 1.1  Ung      SOS371769 Add DecodeSP                      */
/* 2016-09-30 1.2  Ung      Performance tuning                          */
/* 2018-03-07 1.3  ChewKP   WMS-4190 Add Custom DecodeSP (ChewKP01)     */
/* 2018-08-07 1.4  James    INC0341989 - Support decode label without   */
/*                          qty output. No prompt error when no qty     */
/*                          input (james01)                             */
/* 2018-10-02 1.5  Gan      Performance tuning                          */
/* 2019-11-05 1.6  Chermaine WMS-11031 Add eventLog (cc01)              */
/* 2021-06-15 1.7  James    WMS-17221 Move capture rdt_STD_EventLog to  */
/*                          rdt_MoveToID_Close (james02)                */
/* 2023-07-29 1.8  Ung      WMS-23069 Add serial no                     */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_MoveToID] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cChkFacility  NVARCHAR( 5),
   @nSKUCnt       INT,
   @b_success     INT,
   @n_err         INT,
   @c_errmsg      NVARCHAR( 20),
   @cSQL          NVARCHAR( MAX),
   @cSQLParam     NVARCHAR( MAX),
   @cSerialNo     NVARCHAR( 30) = '',
   @nSerialQTY    INT,
   @nMoreSNO      INT,
   @nBulkSNO      INT,
   @nBulkSNOQTY   INT

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cUserName   NVARCHAR(18),
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),

   @cFromLOC    NVARCHAR( 10),
   @cFromID     NVARCHAR( 18),
   @cSKU        NVARCHAR( 20),
   @cPUOM_Desc  NVARCHAR( 5), -- Pref UOM desc
   @cMUOM_Desc  NVARCHAR( 5), -- Master UOM desc
   @cSKUSerialNoCapture NVARCHAR( 1),

   @cPUOM       NVARCHAR( 1), -- Pref UOM
   @cSKUDescr   NVARCHAR( 60),
   @nPQTY       INT,      -- QTY to move, in pref UOM
   @nMQTY       INT,      -- Remining QTY to move, in master UOM
   @nPUOM_Div   INT,

   @nQTY_Avail  INT,      -- QTY avail in master UOM
   @nPQTY_Avail INT,      -- QTY avail in pref UOM
   @nMQTY_Avail INT,      -- Remaining QTY in master UOM
   @nQTY        INT,      -- QTY to move, in master UOM
   @nIDQTY      INT,

   @cToLOC              NVARCHAR( 10),
   @cToID               NVARCHAR( 18),
   @cDecodeLabelNo      NVARCHAR( 20),
   @cDisableQTYField    NVARCHAR( 1),
   @cDefaultToLOC       NVARCHAR( 10),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20),
   @cSKUValidated       NVARCHAR( 1), -- (james01)
   @cSerialNoCapture    NVARCHAR( 1),

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)

-- Load RDT.RDTMobRec
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cUserName   = UserName,
   @cStorerKey  = StorerKey,
   @cFacility   = Facility,

   @cFromLOC    = V_String1,
   @cFromID     = V_String2,
   @cSKU        = V_String3,
   @cPUOM_Desc  = V_String4, -- Pref UOM desc
   @cMUOM_Desc  = V_String5, -- Master UOM desc
   @cSKUSerialNoCapture = V_String6, 

   @cPUOM       = V_UOM,     -- Pref UOM
   @cSKUDescr   = V_SKUDescr,
   @nPQTY       = V_PQTY,
   @nMQTY       = V_MQTY,
   @nPUOM_Div   = V_PUOM_Div,

   @nQTY_Avail  = V_Integer1,
   @nPQTY_Avail = V_Integer2,
   @nMQTY_Avail = V_Integer3,
   @nQTY        = V_Integer4,
   @nIDQTY      = V_Integer5,

   @cToLOC              = V_String14,
   @cToID               = V_String15,
   @cDecodeLabelNo      = V_String16,
   @cDisableQTYField    = V_String17,
   @cDefaultToLOC       = V_String18,
   @cExtendedUpdateSP   = V_String19,
   @cDecodeSP           = V_String20,
   @cSKUValidated       = V_String21,
   @cSerialNoCapture    = V_String22, 

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_ToID             INT,  @nScn_ToID           INT,
   @nStep_FromLOC          INT,  @nScn_FromLOC        INT,
   @nStep_SKUQTY           INT,  @nScn_SKUQTY         INT,
   @nStep_CloseToID        INT,  @nScn_CloseToID      INT,
   @nStep_ToLOC            INT,  @nScn_ToLOC          INT,
   @nStep_SerialNo         INT,  @nScn_SerialNo       INT
   
SELECT
   @nStep_ToID             = 1,  @nScn_ToID           = 3390,
   @nStep_FromLOC          = 2,  @nScn_FromLOC        = 3391,
   @nStep_SKUQTY           = 3,  @nScn_SKUQTY         = 3392,
   @nStep_CloseToID        = 4,  @nScn_CloseToID      = 3393,
   @nStep_ToLOC            = 5,  @nScn_ToLOC          = 3394,
   @nStep_SerialNo         = 6,  @nScn_SerialNo       = 4830

IF @nFunc = 534 -- Move to ID
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Move to ID
   IF @nStep = 1 GOTO Step_1   -- Scn = 3390. ToID
   IF @nStep = 2 GOTO Step_2   -- Scn = 3391. FromLOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 3392. SKU, QTY
   IF @nStep = 4 GOTO Step_4   -- Scn = 3393. Message. Close To ID?
   IF @nStep = 5 GOTO Step_5   -- Scn = 3394. ToLOC
   IF @nStep = 6 GOTO Step_6   -- Scn = 4830. Serial no
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 513. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Get storer config
   SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)
   SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey) 

   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cDefaultToLOC = rdt.RDTGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)
   IF @cDefaultToLOC = '0'
      SET @cDefaultToLOC = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

    -- EventLog sign In
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey

   -- Enable all fields
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

   -- Prep next screen var
   SET @cOutField01 = '' -- ToID

   -- Set the entry point
   SET @nScn = 3390
   SET @nStep = 1

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3390. ToID
   ToID    (field11, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField01

      -- Check blank
      IF @cToID = ''
      BEGIN
         SET @nErrNo = 78901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --To ID needed
         GOTO Step_1_Fail
      END

      -- Check ToID in use
      IF EXISTS( SELECT 1 FROM rdt.rdtMoveToIDLog WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ToID = @cToID AND AddWho <> @cUserName)
      BEGIN
         SET @nErrNo = 78902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --To ID in-used
         GOTO Step_1_Fail
      END

      -- Check ToID with QTY
      IF EXISTS( SELECT 1
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey
            AND LOC.Facility = @cFacility
            AND LLI.ID = @cToID
            AND LLI.QTY-LLI.QTYPicked > 0)
      BEGIN
         SET @nErrNo = 78903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --To ID with QTY
         GOTO Step_1_Fail
      END

      -- Prepare next screen var
      SET @cOutField01 = @cToID
      SET @cOutField02 = '' -- FromLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- EventLog - Sign Out
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cToID = ''
      SET @cOutField01 = '' -- ToID
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3391. FromLOC
   FromLOC (field01, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField02

      -- Validate blank
      IF @cFromLOC = '' OR @cFromLOC IS NULL
      BEGIN
         SET @nErrNo = 78904
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC needed
         GOTO Step_2_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 78905
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_2_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 78906
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_2_Fail
      END

      -- Prep next screen var
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cPUOM_Desc = ''
      SET @cMUOM_Desc = ''
      SET @nIDQTY = 0

      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- SKU desc 1
      SET @cOutField05 = '' -- SKU desc 2
      SET @cOutField06 = '' -- PUOM_Desc
      SET @cOutField07 = '' -- PQTY_Avail
      SET @cOutField08 = '' -- PQTY
      SET @cOutField09 = '' -- MUOM_Desc
      SET @cOutField10 = '' -- MQTY_Avail
      SET @cOutField11 = '' -- MQTY
      SET @cOutField12 = '' -- PUOM_DIV
      SET @cOutField13 = '' -- IDQTY

      -- Disable and default QTY field
      IF @cDisableQTYField = '1'
      BEGIN
         SET @cFieldAttr08 = 'O' -- PQTY
         SET @cFieldAttr11 = 'O' -- MQTY
      END
      IF @cPUOM = '6'
         SET @cFieldAttr08 = 'O' -- PQTY

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU

      SET @cSKUValidated = '0'   -- (james01)

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cToID = ''
      SET @cOutField01 = '' --ToID

      -- Go to next screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cFromLOC = ''
      SET @cOutField02 = '' -- FromLOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. scn = 3392. SKU screen
   FromLOC (field01)
   SKU/UPC (field02, input)
   SKU     (field03)
   Desc1   (field04)
   Desc2   (field05)
   PUOM    (field06)
   PQTYAVL (field07)
   PQTYMV  (field08, input)
   MUOM    (field09)
   MQTYAVL (field10)
   MQTYMV  (field11, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cBarcode NVARCHAR( 60)
      DECLARE @cUPC     NVARCHAR( 30)
      DECLARE @cPQTY    NVARCHAR( 5)
      DECLARE @cMQTY    NVARCHAR( 5)

      -- Screen mapping
      SET @cBarcode = @cInField02
      SET @cUPC = LEFT( @cInField02, 30)

      IF @cDisableQTYField = '1'
      BEGIN
         SET @cPQTY = ''
         SET @cMQTY = '1'

         -- Retain the key-in value
         SET @cInField08 = @cPQTY -- Pref QTY
         SET @cInField11 = @cMQTY -- Master QTY
         SET @cSKUValidated = '0'   -- If disable qty field then meaning everytime scan sku only. need decode
      END
      ELSE
      BEGIN
         SET @cPQTY = @cInField08
         SET @cMQTY = @cInField11
      END

      -- Check blank
      IF @cBarcode = ''
      BEGIN
         -- Check if close ToID
         IF EXISTS( SELECT 1 FROM rdt.rdtMoveToIDLog WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ToID = @cToID)
         BEGIN
            -- Go to close ToID screen
            SET @cOutField01 = '' --Option

            SET @cFieldAttr08 = '' -- PQTY
            SET @cFieldAttr11 = '' -- MQTY

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 78907
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU needed
            GOTO Step_3_Fail
         END
      END

      IF @cSKUValidated = '0'
      BEGIN
         -- Decode
         IF @cDecodeSP <> ''
         BEGIN
            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cUPC    = @cUPC     OUTPUT,
                  @nQTY    = @cMQTY    OUTPUT,
                  @nErrNo  = @nErrNo   OUTPUT,
                  @cErrMsg = @cErrMsg  OUTPUT,
                  @cType = 'UPC'
               -- IF @nErrNo <> 0
               --    GOTO Step_3_Fail
               SET @cInField11 = @cMQty
            END
            ELSE -- (ChewKP01)
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
               BEGIN


                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                     '  @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, @cFromLoc, @cToID, @cBarcode, @cUPC OUTPUT, @nQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '  @nMobile      INT                     '+
                     ' ,@nFunc        INT                     '+
                     ' ,@nStep        INT                     '+
                     ' ,@nInputKey    INT                     '+
                     ' ,@cLangCode    NVARCHAR( 3)            '+
                     ' ,@cStorerKey   NVARCHAR( 15)           '+
                     ' ,@cFacility    NVARCHAR( 5)            '+
                     ' ,@cFromLoc     NVARCHAR( 10)           '+
                     ' ,@cToID        NVARCHAR( 18)           '+
                     ' ,@cBarcode     NVARCHAR( 20)           '+
                     ' ,@cUPC         NVARCHAR( 20) OUTPUT    '+
                     ' ,@nQTY         INT           OUTPUT    '+
                     ' ,@nErrNo       INT           OUTPUT    '+
                     ' ,@cErrMsg      NVARCHAR( 20) OUTPUT    '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, @cFromLoc, @cToID, @cBarcode, @cUPC OUTPUT, @cMQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     --SET @nErrNo = 78922
                     --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DecodeError
                     GOTO Step_3_Fail
                  END

                  IF ISNULL( @cMQty, 0) <> 0
                     SET @cInField11 = @cMQty
               END
            END

            SET @cSKUValidated = '1'
         END

         -- Get SKU count
         EXEC [RDT].[rdt_GETSKUCNT]
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cUPC
            ,@nSKUCnt     = @nSKUCnt       OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @n_Err         OUTPUT
            ,@cErrMsg     = @c_ErrMsg      OUTPUT

         -- Validate SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 78908
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO Step_3_Fail
         END

         -- Check multi SKU barcode
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 78921
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Step_3_Fail
         END

         -- Get SKU code
         EXEC [RDT].[rdt_GETSKU]
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cUPC          OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @n_Err         OUTPUT
            ,@cErrMsg     = @c_ErrMsg      OUTPUT
         IF @n_Err <> 0
            GOTO Step_3_Fail

         SET @cSKU = @cUPC
      END

      -- Get SKU info
      SELECT
         @cSKUDescr = S.DescR,
         @cMUOM_Desc = Pack.PackUOM3,
         @cSKUSerialNoCapture = S.SerialNoCapture, 
         @cPUOM_Desc =
            CASE @cPUOM
               WHEN '2' THEN Pack.PackUOM1 -- Case
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack
               WHEN '6' THEN Pack.PackUOM3 -- Master unit
               WHEN '1' THEN Pack.PackUOM4 -- Pallet
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
            END,
         @nPUOM_Div = CAST(
            CASE @cPUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END AS INT)
      FROM dbo.SKU S WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Get QTY avail
      SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cFromLOC
         AND SKU = @cSKU

      -- Validate no QTY
      IF @nQTY_Avail = 0 OR @nQTY_Avail IS NULL
      BEGIN
         SET @nErrNo = 78909
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No QTY to move
         GOTO Step_3_Fail
      END

      -- Serial no SKU
      IF @cSerialNoCapture IN ('1', '2')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         -- Get scanned serial no
         DECLARE @nScan INT
         SELECT @nScan = ISNULL( SUM( QTY), 0)
         FROM rdt.rdtMoveToIDLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND FromLOC = @cFromLOC
            
         -- Check fully scanned
         IF @nScan = @nQTY_Avail
         BEGIN
            SET @nErrNo = 78923
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No QTY to move
            GOTO Step_3_Fail
         END
         
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDescr, @nQTY_Avail, 'CHECK', 'MOVE', @cFromLOC,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0,
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '1', 
            @nScan = @nScan

         IF @nErrNo <> 0
            GOTO Step_3_Fail

         IF @nMoreSNO = 1
         BEGIN
            -- Go to Serial No screen
            SET @nScn = @nScn_SerialNo
            SET @nStep = @nStep_SerialNo

            /*
            -- Flow thru
            IF @cSerialNo <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '6') -- Serial no screen
               BEGIN
                  -- rdt_SerialNo will read from rdtMboRec directly
                  UPDATE rdt.rdtMobRec SET 
                     V_Max = @cSerialNo, 
                     EditDate = GETDATE()
                  WHERE Mobile = @nMobile
                  
                  SET @nInputKey = '1'
                  GOTO 6
               END
            END
            */

            GOTO Quit
         END
      END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Avail = 0
         SET @nMQTY_Avail = @nQTY_Avail
      END
      ELSE
      BEGIN
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prep next screen var
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cOutField08 = '' -- @nPQTY
         SET @cFieldAttr08 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField08 = '' -- @nPQTY
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField11 = '' -- @nMQTY

      -- Screen mapping
      SET @cPQTY = @cInField08
      SET @cMQTY = @cInField11

      -- Retain the key-in value
      SET @cOutField08 = @cInField08 -- Pref QTY
      SET @cOutField11 = @cInField11 -- Master QTY

      -- Validate PQTY
      IF ISNULL(@cPQTY, '') = '' SET @cPQTY = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 78910
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY
         GOTO Quit
      END

      -- Validate MQTY
      IF ISNULL(@cMQTY, '')  = '' SET @cMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 78911
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- MQTY
         GOTO Quit
      END

      -- Calc total QTY in master UOM
      SET @nPQTY = CAST( @cPQTY AS INT)
      SET @nMQTY = CAST( @cMQTY AS INT)
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      -- Validate QTY
      IF @nQTY = 0
      BEGIN
         --SET @nErrNo = 78912
         --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY needed
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- MQTY
         GOTO Quit
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY > @nQTY_Avail
      BEGIN
         SET @nErrNo = 78913
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYAVL NotEnuf
         GOTO Quit
      END

      -- Confirm
      EXEC rdt.rdt_MoveToID_Confirm
         @nMobile     = @nMobile,
         @nFunc       = @nFunc,
         @cLangCode   = @cLangCode,
         @cType       = 'Y', -- Confirm
         @cStorerKey  = @cStorerKey,
         @cToID       = @cToID,
         @cFromLOC    = @cFromLOC,
         @cSKU        = @cSKU,
         @cUCC        = @cBarcode,
         @nQTY        = @nQTY,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Step_3_Fail

      -- Get ID QTY
      SELECT @nIDQTY = ISNULL( SUM( QTY), 0)
      FROM rdt.rdtMoveToIDLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ToID = @cToID

      -- Update QTY AVL
      SET @nPQTY_Avail = @nPQTY_Avail - @nPQTY
      SET @nMQTY_Avail = @nMQTY_Avail - @nMQTY

      -- Prep ToID screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = ''
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cOutField08 = '' -- @nPQTY
         SET @cFieldAttr08 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField08 = '' --@nPQTY
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField11 = CASE WHEN @cDisableQTYField = '1' THEN '1' ELSE '' END -- @nMQTY
      SET @cOutField12 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      SET @cOutField13 = CAST( @nIDQTY AS NVARCHAR( 5))

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU

      SET @cSKUValidated = '0'

      -- Retain in current screen
      -- SET @nScn = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Unconfirm
      EXEC rdt.rdt_MoveToID_Confirm
         @nMobile     = @nMobile,
         @nFunc       = @nFunc,
         @cLangCode   = @cLangCode,
         @cType       = 'N', --Undo
         @cStorerKey  = @cStorerKey,
         @cToID       = @cToID,
         @cFromLOC    = '',
         @cSKU        = '',
         @cUCC        = '',
         @nQTY        = 0,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Step_3_Fail

      -- Prepare prev screen var
      SET @cFromLOC = ''
      SET @cOutField01 = @cToID
      SET @cOutField02 = '' --FromLOC

      SET @cFieldAttr08 = '' -- PQTY
      SET @cFieldAttr11 = '' -- MQTY

      SET @cSKUValidated = '0'   -- (james01)

      -- Go to FromLOC screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU
   END
END
GOTO Quit


/********************************************************************************
Step 4. scn = 3393. Close To ID?
   1=YES
   2=NO
   OPTION (field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes OR Send
   BEGIN
      DECLARE @cOption NVARCHAR(1)

      -- Screen mapping
      SET @cOption = @cInField01 -- Option

      -- Check option blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 78916
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- OptionRequired
         GOTO Step_4_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 78917
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Option
         GOTO Step_4_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Go to ToLOC screen
         SET @cToLOC = ''
         SET @cOutField01 = @cDefaultToLOC
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END

      IF @cOption = '2'
      BEGIN
         -- Go to FromLOC screen
         SET @cOutField01 = @cToID
         SET @cOutField02 = '' -- FromLOC

         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cOutField08 = '' -- @nPQTY
         SET @cFieldAttr08 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 5))
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField11 = CASE WHEN @cDisableQTYField = '1' THEN '1' ELSE '' END -- @nMQTY
      SET @cOutField12 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      SET @cOutField13 = CAST( @nIDQTY AS NVARCHAR( 5))

      -- Enable disable QTY
      IF @cDisableQTYField = '1'
      BEGIN
         SET @cFieldAttr08 = 'O' -- PQTY
         SET @cFieldAttr11 = 'O' -- MQTY
      END

      SET @cSKUValidated = '0'   -- (james01)

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   GOTO Quit

   Step_4_Fail:
      SET @cOutField01 = '' -- Option
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 3395. ToLOC
   ToLOC   (field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField01

      --SET @cToLoc = 'NI-PALLET'

      -- Validate blank
      IF @cToLOC = '' OR @cToLOC IS NULL
      BEGIN
         SET @nErrNo = 78918
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC needed
         GOTO Step_5_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 78919
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_5_Fail
      END

      -- Validate LOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 78920
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            GOTO Step_5_Fail
         END

      -- Move
      EXEC rdt.rdt_MoveToID_Close
         @nMobile     = @nMobile,
         @nFunc       = @nFunc,
         @cLangCode   = @cLangCode,
         @nStep       = @nStep,
         @cStorerKey  = @cStorerKey,
         @cToID       = @cToID,
         @cToLOC      = @cToLOC,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Step_5_Fail

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToID, @cFromLOC, @cSKU, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile    INT,        ' +
               '@nFunc      INT,        ' +
               '@cLangCode  NVARCHAR( 3),   ' +
               '@nStep      INT,        ' +
               '@cStorerKey NVARCHAR( 15),  ' +
               '@cToID      NVARCHAR( 18),  ' +
               '@cFromLOC   NVARCHAR( 10),  ' +
               '@cSKU       NVARCHAR( 20),  ' +
               '@nQTY       INT,        ' +
               '@cToLOC     NVARCHAR( 10),  ' +
               '@nErrNo     INT OUTPUT, ' +
               '@cErrMsg    NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToID, @cFromLOC, @cSKU, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Go to To ID screen
      SET @cOutField01 = ''

      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Go to close To ID screen
      SET @cOutField01 = '' -- Option
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField01 = '' -- ToLOC
   END
END
GOTO Quit


/********************************************************************************
Step 6. Screen = 4830. Serial No
   SKU            (Field01)
   SKUDesc1       (Field02)
   SKUDesc2       (Field03)
   SerialNo       (Field04, input)
   Scan           (Field05)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDescr, @nQTY_Avail, 'UPDATE', 'MOVE', @cFromLOC,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
         @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
         @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn,
         @nBulkSNO   OUTPUT,  @nBulkSNOQTY OUTPUT,  @cSerialCaptureType = '1'

      IF @nErrNo <> 0
         GOTO Quit
         
      -- Confirm
      EXEC rdt.rdt_MoveToID_Confirm
         @nMobile     = @nMobile,
         @nFunc       = @nFunc,
         @cLangCode   = @cLangCode,
         @cType       = 'Y', -- Confirm
         @cStorerKey  = @cStorerKey,
         @cToID       = @cToID,
         @cFromLOC    = @cFromLOC,
         @cSKU        = @cSKU,
         @nQTY        = @nSerialQTY,
         @cSerialNo   = @cSerialNo,
         @nSerialQTY  = @nSerialQTY,
         @nBulkSNO    = 0,
         @nBulkSNOQTY = 0,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      IF @nMoreSNO = 1
         GOTO Quit
   END

   -- Get ID QTY
   SELECT @nIDQTY = ISNULL( SUM( QTY), 0)
   FROM rdt.rdtMoveToIDLog WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ToID = @cToID

   -- Get QTY avail
   SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
   FROM dbo.LOTxLOCxID WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND LOC = @cFromLOC
      AND SKU = @cSKU

   -- Convert to prefer UOM QTY
   IF @cPUOM = '6' OR -- When preferred UOM = master unit
      @nPUOM_Div = 0 -- UOM not setup
   BEGIN
      SET @cPUOM_Desc = ''
      SET @nPQTY_Avail = 0
      SET @nMQTY_Avail = @nQTY_Avail
   END
   ELSE
   BEGIN
      SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
      SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
   END

   -- Prepare prev screen var
   SET @cOutField01 = @cFromLOC
   SET @cOutField02 = '' -- SKU
   SET @cOutField03 = @cSKU
   SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
   SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
   IF @cPUOM_Desc = ''
   BEGIN
      SET @cOutField06 = '' -- @cPUOM_Desc
      SET @cOutField07 = '' -- @nPQTY_Avail
      SET @cOutField08 = '' -- @nPQTY
      SET @cFieldAttr08 = 'O'
   END
   ELSE
   BEGIN
      SET @cOutField06 = @cPUOM_Desc
      SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
      SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 5))
   END
   SET @cOutField09 = @cMUOM_Desc
   SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
   SET @cOutField11 = CASE WHEN @cDisableQTYField = '1' THEN '1' ELSE '' END -- @nMQTY
   SET @cOutField12 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
   SET @cOutField13 = CAST( @nIDQTY AS NVARCHAR( 5))

   -- Enable disable QTY
   IF @cDisableQTYField = '1'
   BEGIN
      SET @cFieldAttr08 = 'O' -- PQTY
      SET @cFieldAttr11 = 'O' -- MQTY
   END

   SET @cSKUValidated = '0'

   -- Go to prev screen
   SET @nScn = @nScn_SKUQTY
   SET @nStep = @nStep_SKUQTY
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
      -- UserName  = @cUserName,

      V_String1  = @cFromLOC,
      V_String2  = @cFromID,
      V_String3  = @cSKU,
      V_String4  = @cPUOM_Desc,
      V_String5  = @cMUOM_Desc,
      V_String6  = @cSKUSerialNoCapture, 

      V_UOM      = @cPUOM,
      V_SKUDescr = @cSKUDescr,
      V_PQTY     = @nPQTY,
      V_MQTY     = @nMQTY,
      V_PUOM_Div = @nPUOM_Div,

      V_Integer1 = @nQTY_Avail,
      V_Integer2 = @nPQTY_Avail,
      V_Integer3 = @nMQTY_Avail,
      V_Integer4 = @nQTY,
      V_Integer5 = @nIDQTY,

      V_String14 = @cToLOC,
      V_String15 = @cToID,
      V_String16 = @cDecodeLabelNo,
      V_String17 = @cDisableQTYField,
      V_String18 = @cDefaultToLOC,
      V_String19 = @cExtendedUpdateSP,
      V_String20 = @cDecodeSP,
      V_String21 = @cSKUValidated,
      V_String22 = @cSerialNoCapture, 

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08, 
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15 

   WHERE Mobile = @nMobile
END

GO
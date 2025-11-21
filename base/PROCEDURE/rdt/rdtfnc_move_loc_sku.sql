SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Move_LOC_SKU                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2006-07-25 1.0  Ung      SOS256721 Created                           */
/* 2016-05-27 1.1  Ung      SOS370943 Add DecodeSP                      */
/* 2016-09-30 1.2  Ung      Performance tuning                          */
/* 2017-11-17 1.3  Ung      WMS-3429 Add custom DecodeSP                */
/************************************************************************/

CREATE  PROCEDURE rdt.rdtfnc_Move_LOC_SKU (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @nRowCount    INT,
   @cChkFacility NVARCHAR( 5),
   @nSKUCnt      INT,
   @cSQL         NVARCHAR( MAX), 
   @cSQLParam    NVARCHAR( MAX), 
   @b_success    INT,
   @n_err        INT,
   @c_errmsg     NVARCHAR( 20)

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
   @cSKU        NVARCHAR( 30),
   @cSKUDescr   NVARCHAR( 60),
   @nQTY        INT,
   @cToLOC      NVARCHAR( 10),
   
   @cDecodeSP   NVARCHAR( 20),
   @cLOCCheckDigitSP  NVARCHAR( 20),
   @cCheckDigitLOC    NVARCHAR( 20),

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

   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,

   @cFromLOC    = V_String1,
   @cToLOC      = V_String2,
   @nQTY        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
   
   @cDecodeSP   = V_String10,

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

IF @nFunc = 532 -- Move LOC SKU
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Move LOC SKU
   IF @nStep = 1 GOTO Step_1   -- Scn = 3210. FromLOC
   IF @nStep = 2 GOTO Step_2   -- Scn = 3211. SKU, desc1, desc2
   IF @nStep = 3 GOTO Step_3   -- Scn = 3212. ToLOC
   IF @nStep = 4 GOTO Step_4   -- Scn = 3213. Message
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 513. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
         
   -- Set the entry point
   SET @nScn = 3210
   SET @nStep = 1

    -- Event log
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey

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
   SET @cFromLOC = ''
   SET @cOutField01 = '' -- FromLOC
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3210. FromLOC
   FromLOC (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField01

      -- Validate blank
      IF @cFromLOC = '' OR @cFromLOC IS NULL
      BEGIN
         SET @nErrNo = 77201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC needed'
         GOTO Step_1_Fail
      END

      SET @cCheckDigitLOC = @cInField01
      SET @cLOCCheckDigitSP = rdt.rdtGetConfig(@nFunc, 'LOCCheckDigitSP', @cStorerKey)
      IF @cLOCCheckDigitSP = 1
      BEGIN
         EXEC rdt.rdt_LOCLookUp_CheckDigit @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cCheckDigitLOC    OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Step_1_Fail
         SET @cFromLOC = @cCheckDigitLOC
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 77202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_1_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 77203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_1_Fail
      END

      -- Get StorerConfig 'UCC'
      DECLARE @cUCCStorerConfig NVARCHAR( 1)
      SELECT @cUCCStorerConfig = SValue
      FROM dbo.StorerConfig (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConfigKey = 'UCC'

      -- Check UCC exists
      IF @cUCCStorerConfig = '1'
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.UCC (NOLOCK)
            WHERE Storerkey = @cStorerKey
               AND LOC = @cFromLOC
               AND Status = 1) -- 1=Received
         BEGIN
            SET @nErrNo = 77204
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC have UCC'
            GOTO Step_1_Fail
         END
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' --SKU

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- Event log
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
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
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cFromLOC = ''
      SET @cOutField01 = '' -- LOC
   END
END
GOTO Quit


/********************************************************************************
Step 2. scn = 3211. SKU screen
   FromLOC (field01)
   SKU     (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cBarcode NVARCHAR( 60)
      
      -- Screen mapping
      SET @cBarcode = @cInField02
      SET @cSKU = LEFT( @cInField02, 30)

      -- Validate blank
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 77205
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU needed'
         GOTO Step_2_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cUPC    = @cSKU    OUTPUT, 
               @nErrNo  = @nErrNo  OUTPUT, 
               @cErrMsg = @cErrMsg OUTPUT
            -- IF @nErrNo <> 0
            --    GOTO Step_2_Fail
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromLOC, @cBarcode, ' +
                  ' @cSKU OUTPUT, @nQTY OUTPUT, @cToLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  ' @nMobile      INT,           ' +
                  ' @nFunc        INT,           ' +
                  ' @cLangCode    NVARCHAR( 3),  ' +
                  ' @nStep        INT,           ' +
                  ' @nInputKey    INT,           ' +
                  ' @cStorerKey   NVARCHAR( 15), ' +
                  ' @cFromLOC     NVARCHAR( 10), ' +
                  ' @cBarcode     NVARCHAR( 60), ' +
                  ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY         INT            OUTPUT, ' +
                  ' @cToLOC       NVARCHAR( 10), OUTPUT  ' +
                  ' @nErrNo       INT            OUTPUT, ' +
                  ' @cErrMsg      NVARCHAR( 20)  OUTPUT'
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromLOC, @cBarcode, 
                  @cSKU OUTPUT, @nQTY OUTPUT, @cToLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
               IF @nErrNo <> 0
                  GOTO Step_2_Fail
            END
         END
      END
         
      -- Get SKU count
      EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 77206
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_2_Fail
      END

      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT


      -- Get QTY avail
      SELECT @nQTY = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
      FROM dbo.LOTxLOCxID (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cFromLOC
         AND SKU = @cSKU

      -- Validate not QTY
      IF @nQTY = 0 OR @nQTY IS NULL
      BEGIN
         SET @nErrNo = 77207
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No QTY to move'
         GOTO Step_3_Fail
      END

      -- Get SKU info
      SELECT
         @cSKUDescr = S.DescR
      FROM dbo.SKU S (NOLOCK)
         INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cFromLOC = ''
      SET @cOutField01 = @cFromLOC

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      -- Reset this screen var
      SET @cSKU = ''
      SET @cOutField02 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 3213. ToLOC
   FromLOC (field01)
   SKU     (field02)
   Desc1   (field03)
   Desc2   (field04)
   ToLOC   (field15, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField05

      -- Validate blank
      IF @cToLOC = '' OR @cToLOC IS NULL
      BEGIN
         SET @nErrNo = 77208
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToLOC needed'
         GOTO Step_3_Fail
      END

      SET @cCheckDigitLOC = @cInField05
      SET @cLOCCheckDigitSP = rdt.rdtGetConfig(@nFunc, 'LOCCheckDigitSP', @cStorerKey)
      IF @cLOCCheckDigitSP = 1
      BEGIN
         EXEC rdt.rdt_LOCLookUp_CheckDigit @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cCheckDigitLOC    OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Step_3_Fail
         SET @cToLOC = @cCheckDigitLOC
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 77209
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_3_Fail
      END

      -- Validate LOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 77210
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
            GOTO Step_3_Fail
         END

      -- Validate FromLOC same as ToLOC
      IF @cFromLOC = @cToLOC
      BEGIN
         SET @nErrNo = 77211
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Same FromToLOC'
         GOTO Step_3_Fail
      END      

      DECLARE @cFromID   NVARCHAR( 18)
      DECLARE @nQTYAvail INT
      DECLARE @curLLI CURSOR
      SET @curLLI = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT
            ID,
            SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) -- Avail
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND LOC = @cFromLOC
         GROUP BY ID
         HAVING SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0
      OPEN @curLLI
      FETCH NEXT FROM @curLLI INTO @cFromID, @nQTYAvail
      WHILE @@FETCH_STATUS = 0
      BEGIN
         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode,
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
            @cSourceType = 'rdtfnc_Move_LOC_SKU',
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility,
            @cFromLOC    = @cFromLOC,
            @cToLOC      = @cToLOC,
            @cFromID     = @cFromID, -- NULL means not filter by ID. Blank is a valid ID
            @cToID       = NULL,     -- NULL means not changing ID. Blank consider a valid ID
            @cSKU        = @cSKU,
            @nQTY        = @nQTYAvail
         IF @nErrNo <> 0
            GOTO Step_3_Fail

         FETCH NEXT FROM @curLLI INTO @cFromID, @nQTYAvail
      END

      -- Event log
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cLocation     = @cFromLOC,
         @cToLocation   = @cToLOC,
         @cSKU          = @cSKU,
         @nQTY          = @nQTY

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare ToID screen var
      SET @cSKU = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' --@cSKU

      -- Go to ToID screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField05 = '' --ToLOC
   END
END
GOTO Quit


/********************************************************************************
Step 4. scn = 1038. Message screen
   Message
********************************************************************************/
Step_4:
BEGIN
   -- Go back to 1st screen
   SET @nScn  = @nScn - 3
   SET @nStep = @nStep - 3

   -- Prep next screen var
   SET @cFromLOC = ''
   SET @cOutField01 = '' -- FromLOC
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

      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,

      V_String1  = @cFromLOC,
      V_String2  = @cToLOC,
      V_String3  = @nQTY,
      
      V_String10 = @cDecodeSP,

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
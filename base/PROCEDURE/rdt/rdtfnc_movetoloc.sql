SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_MoveToLOC                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: move to a LOC, fill it up by piece scan                           */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-01-03 1.0  Ung      WMS-18656 created                                 */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_MoveToLOC] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @nRowCount     INT,
   @cChkFacility  NVARCHAR( 5),
   @nSKUCnt       INT,
   @cSQL          NVARCHAR( MAX),
   @cSQLParam     NVARCHAR( MAX),
   @cDocType      NVARCHAR( 30), 
   @cDocNo        NVARCHAR( 20), 
   @cBarcode      NVARCHAR( 60),
   @nQueueErrNo   INT,
   @cQueueErrMsg  NVARCHAR( 20) = '',
   @b_Success     INT, 
   @n_err         INT, 
   @c_errmsg      NVARCHAR( 20),
   @tExtInfo      VariableTable

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
   @cUserName   NVARCHAR( 18),

   @cFromLOC    NVARCHAR( 10),
   @cFromID     NVARCHAR( 18),
   @cSKU        NVARCHAR( 30),
   @cSKUDescr   NVARCHAR( 60),
   @nQTY        INT, 

   @cToLOC              NVARCHAR( 10),
   @cToID               NVARCHAR( 18),
   @cFromLOCLoseID      NVARCHAR( 1), 
   @cToLOCLoseID        NVARCHAR( 1), 
   @cPrePackIndicator   NVARCHAR( 30),

   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cMultiSKUBarcode    NVARCHAR( 1), 
   @cDecodeSP           NVARCHAR( 20),
	@cLOCLookupSP        NVARCHAR( 20), 

   @nPackQtyIndicator   INT,
   @nTotalSKU           INT, 
   @nTotalQTY           INT, 


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

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,

   @cFromLOC    = V_LOC,
   @cFromID     = V_ID,
   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,
   @nQTY        = V_QTY,

   @cToLOC              = V_String1,
   @cToID               = V_String2,
   @cFromLOCLoseID      = V_String3,
   @cToLOCLoseID        = V_String4,
   @cPrePackIndicator   = V_String5,

   @cExtendedInfoSP     = V_String20,
   @cExtendedInfo       = V_String21,
   @cExtendedUpdateSP   = V_String22,
   @cExtendedValidateSP = V_String23,
   @cMultiSKUBarcode    = V_String24,
   @cDecodeSP           = V_String25,
	@cLOCLookupSP        = V_String26,

   @nPackQtyIndicator   = V_Integer1,
   @nTotalSKU           = V_Integer2, 
   @nTotalQTY           = V_Integer3, 

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
   @nStep_FromLOC       INT,  @nScn_FromLOC        INT,
   @nStep_FromID        INT,  @nScn_FromID         INT,
   @nStep_ToLOC         INT,  @nScn_ToLOC          INT,
   @nStep_ToID          INT,  @nScn_ToID           INT,
   @nStep_SKUQTY        INT,  @nScn_SKUQTY         INT,
   @nStep_ConfirmMove   INT,  @nScn_ConfirmMove    INT, 
   @nStep_MultiSKU      INT,  @nScn_MultiSKU       INT

SELECT
   @nStep_FromLOC       = 1,  @nScn_FromLOC        = 6000,
   @nStep_FromID        = 2,  @nScn_FromID         = 6001,
   @nStep_ToLOC         = 3,  @nScn_ToLOC          = 6002,
   @nStep_ToID          = 4,  @nScn_ToID           = 6003,
   @nStep_SKUQTY        = 5,  @nScn_SKUQTY         = 6004,
   @nStep_ConfirmMove   = 6,  @nScn_ConfirmMove    = 6005, 
   @nStep_MultiSKU      = 7,  @nScn_MultiSKU       = 3570

IF @nFunc = 617 -- Move to LOC
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_Start          -- Func = 617
   IF @nStep = 1 GOTO Step_FromLOC        -- 6000 FromLOC
   IF @nStep = 2 GOTO Step_FromID         -- 6001 FromID
   IF @nStep = 3 GOTO Step_ToLOC          -- 6002 ToLOC
   IF @nStep = 4 GOTO Step_ToID           -- 6003 ToID
   IF @nStep = 5 GOTO Step_SKUQTY         -- 6004 SKU, QTY
   IF @nStep = 6 GOTO Step_ConfirmMove    -- 6005 Confirm move?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 513. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- Storer configure
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cLOCLookupSP = rdt.rdtGetConfig(@nFunc,'LOCLookupSP',@cStorerKey)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)

   -- Prep next screen var
   SET @cOutField01 = '' -- FromLOC

   -- Set the entry point
   SET @nScn = @nScn_FromLOC
   SET @nStep = @nStep_FromLOC

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 6000. FromLOC
   FROM LOC (field01, input)
********************************************************************************/
Step_FromLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField01

      -- Check blank
      IF @cFromLOC = ''
      BEGIN
         SET @nErrNo = 180351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC needed
         GOTO Step_FromLOC_Fail
      END

		-- Get LOC prefix
		IF @cLOCLookupSP = 1
		BEGIN
			EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
   			@cFromLOC   OUTPUT,
   			@nErrNo     OUTPUT,
   			@cErrMsg    OUTPUT
			IF @nErrNo <> 0
				GOTO Step_FromLOC_Fail
		END

      -- Get LOC info
      SELECT
         @cChkFacility = Facility,
         @cFromLOCLoseID = LoseID
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Check LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 180352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_FromLOC_Fail
      END

      -- Check facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 180353
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_FromLOC_Fail
      END

      -- Get storer config
      DECLARE @cUCCStorerConfig NVARCHAR(1)
      EXECUTE dbo.nspGetRight
         @cFacility,
         @cStorerKey,
         NULL, -- SKU
         'UCC',
         @b_Success        OUTPUT,
         @cUCCStorerConfig OUTPUT,
         @nErrNo           OUTPUT,
         @cErrMsg          OUTPUT
      IF @b_Success <> 1
      BEGIN
         SET @nErrNo = 180354
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspGetRight
         GOTO Quit
      END

      -- Check UCC exists
      IF @cUCCStorerConfig = '1'
      BEGIN
         IF EXISTS( SELECT 1
            FROM dbo.UCC (NOLOCK)
            WHERE Storerkey = @cStorerKey
               AND LOC = @cFromLOC
               AND LOT <> ''
               AND LOT IS NOT NULL
               AND Status = '1') -- 1=Received
         BEGIN
            SET @nErrNo = 180355
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC have UCC
            GOTO Step_FromLOC_Fail
         END
      END

      -- Prep next screen var
      SET @cFromID = ''

      -- Go to next screen
      IF @cFromLOCLoseID = '1'
      BEGIN
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = @cFromID
         SET @cOutField03 = '' --@cToLOC

         SET @nScn = @nScn_ToLOC
         SET @nStep = @nStep_ToLOC
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = @cFromID

         SET @nScn = @nScn_FromID
         SET @nStep = @nStep_FromID
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
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
   END
   GOTO Quit

   Step_FromLOC_Fail:
   BEGIN
      SET @cFromLOC = ''
      SET @cOutField01 = '' -- FromLOC
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 6001. FromID
   FROM LOC (field01)
   FROM ID  (field02, input)
********************************************************************************/
Step_FromID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField02
      SET @cBarcode = @cInField02

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'FROMID', @cBarcode) = 0
      BEGIN
         SET @nErrNo = 180356
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_FromID_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1' AND ISNULL( @cBarcode, '') <> ''  -- blank string no need decode
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID     = @cFromID OUTPUT,
               @cUPC    = @cSKU    OUTPUT,
               @nQTY    = @nQTY    OUTPUT,
               @cType   = 'ID'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cFromLOC    OUTPUT, @cFromID     OUTPUT, ' +
               ' @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
               ' @cToLOC      OUTPUT, @cToID       OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cToID        NVARCHAR( 18)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,
               @cFromLOC    OUTPUT, @cFromID     OUTPUT,
               @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cToLOC      OUTPUT, @cToID       OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_FromID_Fail
      END

      -- Validate ID
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID = @cFromID
            AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0)
      BEGIN
         SET @nErrNo = 180357
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_FromID_Fail
      END

      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_FromID_Fail
         END
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' --@cSKU

      -- Go to next screen
      SET @nScn = @nScn_ToLOC
      SET @nStep = @nStep_ToLOC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = '' -- @cFromLOC

      -- Go to prev screen
      SET @nScn = @nScn_FromLOC
      SET @nStep = @nStep_FromLOC
   END
   GOTO Quit

   Step_FromID_Fail:
   BEGIN
      SET @cFromID  = ''
      SET @cOutField02 = '' -- ID
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 6002. ToLOC
   FROM LOC (field01)
   FROM ID  (field02)
   TO LOC   (field13, input)
********************************************************************************/
Step_ToLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField03

      -- Check blank
      IF @cToLOC = ''
      BEGIN
         SET @nErrNo = 180358
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC needed
         GOTO Step_ToLOC_Fail
      END

		-- Get LOC prefix
		IF @cLOCLookupSP = 1
		BEGIN
			EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
   			@cToLOC  OUTPUT,
   			@nErrNo  OUTPUT,
   			@cErrMsg OUTPUT
			IF @nErrNo <> 0
				GOTO Step_ToLOC_Fail
		END

      -- Get LOC info
      SELECT 
         @cChkFacility = Facility, 
         @cToLOCLoseID = LoseID
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      -- Check valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 180359
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_ToLOC_Fail
      END

      -- Check facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
      BEGIN
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 180360
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            GOTO Step_ToLOC_Fail
         END
      END
      
      -- Check FromLOC same as ToLOC
      IF @cFromLOC = @cToLOC
      BEGIN
         IF rdt.rdtGetConfig( @nFunc, 'MoveNotCheckSameFromToLoc', @cStorerKey) = '0'
         BEGIN
            SET @nErrNo = 180361
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Same FromToLOC
            GOTO Step_ToLOC_Fail
         END
      END

      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
      -- Prep next screen var
      SET @cToID = ''

      -- Go to next screen
      IF @cToLOCLoseID = '1'
      BEGIN
         -- Clean up log table
         DELETE rdt.rdtMoveToLOCLog WHERE Mobile = @nMobile

         SET @cSKU = ''
         SET @cSKUDescr = ''
         SET @cPrePackIndicator = ''
         SET @nPackQtyIndicator = 0
         SET @nTotalSKU = 0
         SET @nTotalQTY = 0

         -- Prep next screen var
         SET @cOutField01 = @cToLOC
         SET @cOutField02 = @cToID
         SET @cOutField03 = '' -- @cSKU
         SET @cOutField04 = @cSKU
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)   -- SKU desc 1
         SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
         SET @cOutField07 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END
         SET @cOutField08 = CAST( @nTotalSKU AS NVARCHAR(5))
         SET @cOutField09 = CAST( @nTotalQTY AS NVARCHAR(5))
         SET @cOutField15 = '' -- ExtInfo
      
         SET @nScn = @nScn_SKUQTY
         SET @nStep = @nStep_SKUQTY
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = @cFromID
         SET @cOutField03 = @cToLOC
         SET @cOutField04 = '' -- @cToID

         SET @nScn = @nScn_FromID
         SET @nStep = @nStep_FromID
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go to next screen
      IF @cFromLOCLoseID = '1'
      BEGIN
         SET @cOutField01 = '' --@cFromLOC

         SET @nScn = @nScn_FromLOC
         SET @nStep = @nStep_FromLOC
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = '' --@cFromID

         SET @nScn = @nScn_FromID
         SET @nStep = @nStep_FromID
      END
   END
   GOTO Quit

   Step_ToLOC_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField03 = '' -- @cToLOC
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 6003. ToID
   FROM LOC (field01)
   FROM ID  (field02)
   TO LOC   (field03)
   TO ID    (field04, input)
********************************************************************************/
Step_ToID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField04
      SET @cBarcode = @cInField04

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TOID', @cBarcode) = 0
      BEGIN
         SET @nErrNo = 180362
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_ToID_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1' AND ISNULL( @cBarcode, '') <> ''  -- blank string no need decode
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID     = @cToID   OUTPUT,
               @cUPC    = @cSKU    OUTPUT,
               @nQTY    = @nQTY    OUTPUT,
               @cType   = 'ID'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cFromLOC    OUTPUT, @cFromID     OUTPUT, ' +
               ' @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
               ' @cToLOC      OUTPUT, @cToID       OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cToID        NVARCHAR( 18)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,
               @cFromLOC    OUTPUT, @cFromID     OUTPUT,
               @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cToLOC      OUTPUT, @cToID       OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Quit
      END

      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Clean up log table
      DELETE rdt.rdtMoveToLOCLog WHERE Mobile = @nMobile

      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cPrePackIndicator = ''
      SET @nPackQtyIndicator = 0
      SET @nTotalSKU = 0
      SET @nTotalQTY = 0

      -- Prep next screen var
      SET @cOutField01 = @cToLOC
      SET @cOutField02 = @cToID
      SET @cOutField03 = '' -- @cSKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField07 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END
      SET @cOutField08 = CAST( @nTotalSKU AS NVARCHAR(5))
      SET @cOutField09 = CAST( @nTotalQTY AS NVARCHAR(5))
      SET @cOutField15 = '' -- ExtInfo

      -- Go to next screen
      SET @nScn = @nScn_SKUQTY
      SET @nStep = @nStep_SKUQTY
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep SKU screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' --@cToLOC

      -- Go to QTY screen
      SET @nScn = @nScn_ToLOC
      SET @nStep = @nStep_ToLOC
   END
   GOTO Quit

   Step_ToID_Fail:
   BEGIN
      SET @cToID = ''
      SET @cOutField04 = '' -- @cToID
   END
END
GOTO Quit


/********************************************************************************
Step 3. scn = 6004. SKU QTY screen
   TO LOC   (field01)
   TO ID    (field02)
   SKU/UPC  (field03, input)
   SKU      (field04)
   DESC1    (field05)
   DESC1    (field06)
   SKU CNT  (field07)
   QTY      (field08)
********************************************************************************/
Step_SKUQTY:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cUPC NVARCHAR( 30)
      
      -- Screen mapping
      SET @cBarcode = @cInField03
      SET @cUPC = LEFT( @cInField03, 30)

      -- Check blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 180363
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU needed
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nQueueErrNo OUTPUT, @cQueueErrMsg OUTPUT, '', @nErrNo, '', @cErrMsg
         IF @nQueueErrNo = 1
            SET @cErrMsg = ''
         GOTO Step_SKUQTY_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUPC    = @cSKU    OUTPUT,
               @nQTY    = @nQTY    OUTPUT,
               @cType   = 'UPC'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cFromLOC    OUTPUT, @cFromID     OUTPUT, ' +
               ' @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
               ' @cToLOC      OUTPUT, @cToID       OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cToID        NVARCHAR( 18)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,
               @cFromLOC    OUTPUT, @cFromID     OUTPUT,
               @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cToLOC      OUTPUT, @cToID       OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKUQTY_Fail
         END
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
         SET @nErrNo = 180364
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nQueueErrNo OUTPUT, @cQueueErrMsg OUTPUT, '', @nErrNo, '', @cErrMsg
         IF @nQueueErrNo = 1
            SET @cErrMsg = ''
         GOTO Step_SKUQTY_Fail
      END

      -- Multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            -- Limit search scope 
            IF @cFromID <> ''
            BEGIN
               SET @cDocType = 'LOTXLOCXID.ID'
               SET @cDocNo = @cFromID
            END
            ELSE
            BEGIN
               SET @cDocType = 'LOTXLOCXID.LOC'
               SET @cDocNo = @cFromLOC
            END
               
            EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,
               'POPULATE',
               @cMultiSKUBarcode,
               @cStorerKey,
               @cSKU         OUTPUT,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT,
               @cDocType, 
               @cDocNo
            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nScn = @nScn_MultiSKU
               SET @nStep = @nStep_MultiSKU
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
         END
         ELSE
         BEGIN
            SET @nErrNo = 180365
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nQueueErrNo OUTPUT, @cQueueErrMsg OUTPUT, '', @nErrNo, '', @cErrMsg
            IF @nQueueErrNo = 1
               SET @cErrMsg = ''
            GOTO Step_SKUQTY_Fail
         END
      END

      -- Get SKU
      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT
      
      SET @cSKU = @cUPC

      -- Get SKU info
      SELECT
         @cSKUDescr = SKU.DescR,
         @cPrePackIndicator = PrePackIndicator,
         @nPackQtyIndicator = ISNULL( PackQtyIndicator, 0)
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack (nolock) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      SET @nQTY = 1

      -- Calc prepack QTY
      IF @cPrePackIndicator = '2'
         IF @nPackQtyIndicator > 1
            SET @nQTY = @nQTY * @nPackQtyIndicator

      -- Get QTY avail
      DECLARE @nQTY_Avail INT
      SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)), 0)
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cFromLOC
         AND ID = @cFromID
         AND SKU = @cSKU

      -- Get QTY in log (include other operators)
      DECLARE @nQTY_Log INT
      SELECT @nQTY_Log = ISNULL( SUM( QTY), 0)
      FROM rdt.rdtMoveToLOCLog WITH (NOLOCK)
      -- WHERE Mobile = @nMobile
      WHERE StorerKey = @cStorerKey
         AND FromLOC = @cFromLOC
         AND FromID = @cFromID
         AND SKU = @cSKU

      -- Check QTY enough
      IF (@nQTY + @nQTY_Log) > @nQTY_Avail
      BEGIN
         SET @nErrNo = 180366
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Enuf QTY
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nQueueErrNo OUTPUT, @cQueueErrMsg OUTPUT, '', @nErrNo, '', @cErrMsg
         IF @nQueueErrNo = 1
            SET @cErrMsg = ''
         GOTO Step_SKUQTY_Fail
      END

      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Confirm
      EXEC rdt.rdt_MoveToLOC_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'LOG', 
         @cFromLOC, 
         @cFromID, 
         @cSKU, 
         @nQTY, 
         @cToID, 
         @cToLOC, 
         @nTotalSKU OUTPUT, 
         @nTotalQTY OUTPUT, 
         @nErrNo    OUTPUT, 
         @cErrMsg   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prep next screen var
      SET @cOutField01 = @cToLOC
      SET @cOutField02 = @cToID
      SET @cOutField03 = '' -- @cSKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField07 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END
      SET @cOutField08 = CAST( @nTotalSKU AS NVARCHAR(5))
      SET @cOutField09 = CAST( @nTotalQTY AS NVARCHAR(5))
      SET @cOutField15 = '' -- ExtInfo
      
      -- Extended update
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN      
            INSERT INTO @tExtInfo (Variable, Value) VALUES
               ('@cFromLOC',     @cFromLOC),
               ('@cFromID',      @cFromID),
               ('@cSKU',         @cSKU),
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
               ('@cToID',        @cToID),
               ('@cToLOC',       @cToLOC)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtInfo, @cExtendedInfo OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@tExtInfo        VariableTable READONLY, ' +
               '@cExtendedInfo   NVARCHAR( 20)  OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtInfo, @cExtendedInfo OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF EXISTS( SELECT TOP 1 1 FROM rdt.rdtMoveToLOCLog WITH (NOLOCK) WHERE Mobile = @nMobile)
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option
         SET @cOutField02 = CAST( @nTotalSKU AS NVARCHAR(5))
         SET @cOutField03 = CAST( @nTotalQTY AS NVARCHAR(5))

         -- Go to next screen
         SET @nScn = @nScn_ConfirmMove
         SET @nStep = @nStep_ConfirmMove
      END
      ELSE
      BEGIN
         -- Go to prev screen
         IF @cToLOCLoseID = '1'
         BEGIN
            SET @cOutField01 = @cFromLOC
            SET @cOutField02 = @cFromID
            SET @cOutField03 = '' --@cToLOC

            SET @nScn = @nScn_ToLOC
            SET @nStep = @nStep_ToLOC
         END
         ELSE
         BEGIN
            SET @cOutField01 = @cFromLOC
            SET @cOutField02 = @cFromID
            SET @cOutField03 = @cToLOC
            SET @cOutField04 = '' --@cToID

            SET @nScn = @nScn_ToID
            SET @nStep = @nStep_ToID
         END
      END 
   END
   GOTO Quit

   Step_SKUQTY_Fail:
   BEGIN
      -- Reset this screen var
      SET @cSKU = ''
      SET @cOutField03 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Step 6. scn = 6005. Confirm move?
   SKU      (field01)
   QTY      (field02)
   OPTION   (field03, input)
********************************************************************************/
Step_ConfirmMove:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR(1)

      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 180367
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need option
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 180368
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         SET @cOutField01 = ''
         GOTO Quit
      END

      DECLARE @cType NVARCHAR( 10)
      IF @cOption = '1' -- YES
         SET @cType = 'UPDATE'
      ELSE
         SET @cType = 'UNDO'

      -- Confirm
      EXEC rdt.rdt_MoveToLOC_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cType, 
         @cFromLOC, 
         @cFromID, 
         @cSKU, 
         @nQTY, 
         @cToID, 
         @cToLOC, 
         @nTotalSKU OUTPUT, 
         @nTotalQTY OUTPUT, 
         @nErrNo    OUTPUT, 
         @cErrMsg   OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' -- @cToLOC

      SET @nScn = @nScn_ToLOC
      SET @nStep = @nStep_ToLOC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cToLOC
      SET @cOutField02 = @cToID
      SET @cOutField03 = '' -- @cSKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField07 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END
      SET @cOutField08 = CAST( @nTotalSKU AS NVARCHAR(5))
      SET @cOutField09 = CAST( @nTotalQTY AS NVARCHAR(5))
      SET @cOutField15 = @cExtendedInfo

      SET @nScn = @nScn_SKUQTY
      SET @nStep = @nStep_SKUQTY
   END
END
GOTO Quit


/********************************************************************************
Step 7. Screen = 3570. Multi SKU
   SKU         (Field01)
   SKUDesc1    (Field02)
   SKUDesc2    (Field03)
   SKU         (Field04)
   SKUDesc1    (Field05)
   SKUDesc2    (Field06)
   SKU         (Field07)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   Option      (Field10, input)
********************************************************************************/
Step_MultiSKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Limit search scope 
      IF @cFromID <> ''
      BEGIN
         SET @cDocType = 'LOTXLOCXID.ID'
         SET @cDocNo = @cFromID
      END
      ELSE
      BEGIN
         SET @cDocType = 'LOTXLOCXID.LOC'
         SET @cDocNo = @cFromLOC
      END

      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,
         'CHECK',
         @cMultiSKUBarcode,
         @cStorerKey,
         @cSKU     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT,  
         @cDocType,  
         @cDocNo      

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      -- Get SKU info
      SELECT
         @cSKUDescr = SKU.DescR,
         @cPrePackIndicator = PrePackIndicator,
         @nPackQtyIndicator = ISNULL( PackQtyIndicator, 0)
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack (nolock) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Prep next screen var
      SET @cOutField01 = @cToLOC
      SET @cOutField02 = @cToID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField07 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END
      SET @cOutField08 = CAST( @nTotalSKU AS NVARCHAR(5))
      SET @cOutField09 = CAST( @nTotalQTY AS NVARCHAR(5))
      SET @cOutField15 = @cExtendedInfo

      SET @nScn = @nScn_SKUQTY
      SET @nStep = @nStep_SKUQTY
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cToLOC
      SET @cOutField02 = @cToID
      SET @cOutField03 = '' -- @cSKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField07 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END
      SET @cOutField08 = CAST( @nTotalSKU AS NVARCHAR(5))
      SET @cOutField09 = CAST( @nTotalQTY AS NVARCHAR(5))
      SET @cOutField15 = @cExtendedInfo

      SET @nScn = @nScn_SKUQTY
      SET @nStep = @nStep_SKUQTY
   END

END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,

      V_LOC      = @cFromLOC, 
      V_ID       = @cFromID,  
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,
      V_QTY      = @nQTY,

      V_String1  = @cToLOC,
      V_String2  = @cToID,
      V_String3  = @cFromLOCLoseID,
      V_String4  = @cToLOCLoseID,
      V_String5  = @cPrePackIndicator,

      V_String20 = @cExtendedInfoSP,
      V_String21 = @cExtendedInfo,
      V_String22 = @cExtendedUpdateSP,
      V_String23 = @cExtendedValidateSP,
      V_String24 = @cMultiSKUBarcode,
      V_String25 = @cDecodeSP,
		V_String26 = @cLOCLookupSP,

      V_Integer1 = @nPackQtyIndicator,
      V_Integer2 = @nTotalSKU, 
      V_Integer3 = @nTotalQTY, 

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
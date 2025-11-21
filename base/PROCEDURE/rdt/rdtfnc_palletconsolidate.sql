SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_PalletConsolidate                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Move between ID (PickDetail.ID)                             */
/*          SOS315975 - Modified from Move By Drop ID                   */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2015-02-13 1.0  James    Created                                     */
/* 2015-12-17 1.1  James    Allow pallet mix storer (james01)           */
/* 2016-02-26 1.2  James    Add pallet id validation (james02)          */
/* 2016-09-30 1.3  Ung      Performance tuning                          */
/* 2017-06-13 1.4  ChewKP   WMS-2180 - Add ExtendedUpdate storer config */
/*                          (ChewKP01)                                  */
/* 2018-09-03 1.5  TanJH    INC0371596 Sku Descr using old value if user*/
/*                          input SKU at Step 2(TanJH01)                */
/* 2018-09-12 1.6  James    WMS6078 - Add MultiSKUBarcode (james03)     */
/* 2018-09-12 1.6  James    Change doctype LLL to fullname (james04)    */
/* 2024-09-26 1.7.0  LJQ006    FCR-877 AutoGenID (LJQ006)               */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_PalletConsolidate] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @cChkFacility        NVARCHAR( 5),
   @nSKUCnt             INT, 
   @nRowCount           INT, 
   @bSuccess            INT 

-- RDT.RDTMobRec variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerGroup        NVARCHAR( 20),
   @cStorerKey          NVARCHAR( 15),
   @cChkStorerKey       NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cPrinter            NVARCHAR( 10),		

   @cSKU                NVARCHAR( 20),
   @cDescr              NVARCHAR( 40),
   @cPUOM               NVARCHAR( 1), -- Prefer UOM
   @cPUOM_Desc          NVARCHAR( 5),
   @cMUOM_Desc          NVARCHAR( 5),
   @cOrderKey           NVARCHAR( 10),

   @nPUOM_Div           INT, -- UOM divider
   @nPQTY               INT, -- Preferred UOM QTY
   @nMQTY               INT, -- Master unit QTY
   @nPQTY_Avail         INT, -- QTY avail in pref UOM
   @nQTY_Avail          INT, -- QTY available in LOTxLOCXID
   @nMQTY_Avail         INT, -- Remaining QTY in master UOM
   @nMQTY_Move          INT, -- Remining QTY to move, in master UOM
   @nQTY_Move           INT, -- QTY to move, in master UOM
   @nPQTY_Move          INT, -- QTY to move, in pref UOM
   @cFromLOC            NVARCHAR( 10), -- From Loc
   @cToLOC              NVARCHAR( 10), -- To Loc
   @cFromID             NVARCHAR( 18), -- From ID
   @cToID               NVARCHAR( 18), -- To ID
   @cMergePlt           NVARCHAR( 1), -- Merge Pallet

   @b_success           INT,
   @n_err               INT,
   @c_errmsg            NVARCHAR( 255),
   @cUserName           NVARCHAR( 18), 
   @nQtyMove_Merge      INT, 
   @cSKU_Merge          NVARCHAR( 20), 
   @cPackUOM3_Merge     NVARCHAR( 5), 
   @cPackUOM3           NVARCHAR( 5), 
   
   @nSKU_CNT            INT, 
   @nID_Qty             INT, 
   @nQty                INT, 
   @nID_AllocQty        INT, 
   @nID_PickQty         INT, 
   @nQTY_Alloc          INT, 
   @nQTY_Pick           INT,
   @nPQTY_Alloc         INT,
   @nPQTY_Pick          INT,
   @nMQTY_Alloc         INT,
   @nMQTY_Pick          INT,
   @nStorer_Cnt         INT, 
   @nMV_Alloc           INT, 
   @nMV_Pick            INT, 
   @cOrder_Cnt          INT, 
   @nLOTCount           INT, 
   @cPQTY               NVARCHAR( 5),
   @cMQTY               NVARCHAR( 5),

   @cOption             NVARCHAR( 1),
   @cPrtOpt             NVARCHAR( 1), 
   @cMergePltOpt        NVARCHAR( 1), 
   @cCurrentSKU         NVARCHAR( 20),
   @cExtendedInfo01     NVARCHAR( 20), 
   @cExtendedInfoSP     NVARCHAR( 20), 
   @cExtendedValidateSP NVARCHAR( 20), 
   @cSQL                NVARCHAR(1000),   
   @cSQLParam           NVARCHAR(1000),   

   @cDefaultOpt         NVARCHAR( 1), 
   @cExtendedDefaultOptSP NVARCHAR( 20), 
   @cSKU_StorerKey      NVARCHAR( 15),
   @nMultiStorer        INT,
   @cExtendedUpdateSP   NVARCHAR(30), -- (ChewKP01) 
   @cMultiSKUBarcode    NVARCHAR(1),
   @cOnScreenSKU        NVARCHAR(20),
   @nFromScn            INT,
   @nFromStep           INT,
   
   @cGenID              NVARCHAR(20), -- LJQ006 FCR-877
   @tExtData            VariableTable,
   @cAutoID             NVARCHAR(18), --LJQ006 FCR-877

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
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerGroup     = StorerGroup, 
   @cStorerKey       = V_StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,	

   @cSKU             = V_SKU,
   @cDescr           = V_SKUDescr,
   @cPUOM            = V_UOM,
   @cFromLOC         = V_LOC,
   @cOrderKey        = V_OrderKey,

   @cFromID          = V_String1,
   @cToID            = V_String2,
   @cMergePltOpt     = V_String3,
   @cPUOM_Desc       = V_String4,
   @cMUOM_Desc       = V_String5,
   @nPUOM_Div        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6,  7), 0) = 1 THEN LEFT( V_String6,  7) ELSE 0 END,
   @nMQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7,  7), 0) = 1 THEN LEFT( V_String7,  7) ELSE 0 END,
   @nPQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8,  7), 0) = 1 THEN LEFT( V_String8,  7) ELSE 0 END,
   @nQTY_Avail       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9,  7), 0) = 1 THEN LEFT( V_String9,  7) ELSE 0 END,
   @nPQTY_Avail      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String10, 7), 0) = 1 THEN LEFT( V_String10, 7) ELSE 0 END,
   @nMQTY_Avail      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 7), 0) = 1 THEN LEFT( V_String11, 7) ELSE 0 END, 
   @nPQTY_Move       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12, 7), 0) = 1 THEN LEFT( V_String12, 7) ELSE 0 END, 
   @nMQTY_Move       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13, 7), 0) = 1 THEN LEFT( V_String13, 7) ELSE 0 END, 
   @nQTY_Move        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 7), 0) = 1 THEN LEFT( V_String14, 7) ELSE 0 END, 
   @cPackUOM3_Merge  = V_String15, 
   @nQtyMove_Merge   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16, 7), 0) = 1 THEN LEFT( V_String16, 7) ELSE 0 END, 
   @cMergePlt        = V_String17, 
   @nQTY_Alloc       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String18,  7), 0) = 1 THEN LEFT( V_String18,  7) ELSE 0 END,
   @nQTY_Pick        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String19,  7), 0) = 1 THEN LEFT( V_String19,  7) ELSE 0 END,
   @cOption          = V_String20, 
   @cPackUOM3        = V_String21, 
   @nMultiStorer     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String22,  7), 0) = 1 THEN LEFT( V_String22,  7) ELSE 0 END,
   @cExtendedUpdateSP = V_String23,
   @cMultiSKUBarcode  = V_String24,
   @nFromScn          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String25,  7), 0) = 1 THEN LEFT( V_String25,  7) ELSE 0 END,
   @nFromStep         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String26,  7), 0) = 1 THEN LEFT( V_String26,  7) ELSE 0 END,
   @cExtendedValidateSP = V_String27,
   @cOnScreenSKU        = V_String28,

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
IF @nFunc = 1813 
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1813
   IF @nStep = 1 GOTO Step_1   -- Scn = 4050. From ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 4051. SKU/UPC
   IF @nStep = 3 GOTO Step_3   -- Scn = 4052. Qty AVL/Qty Move
   IF @nStep = 4 GOTO Step_4   -- Scn = 4053. To ID (single sku move)
   IF @nStep = 5 GOTO Step_5   -- Scn = 4054. To ID (whole pallet move)
   IF @nStep = 6 GOTO Step_6   -- Scn = 4055. Messsage
   IF @nStep = 7 GOTO Step_7   -- Scn = 4056. Option
   IF @nStep = 8 GOTO Step_8   -- Scn = 4057. OrderKey
   IF @nStep = 9 GOTO Step_9   -- Scn = 3570. Multi SKU Barocde
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 515)
********************************************************************************/
Step_0:
BEGIN
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
   SET @cOutField12 = ''
   SET @cOutField13 = ''
   SET @cOutField14 = ''
   SET @cOutField15 = ''

   -- Set the entry point
   SET @nScn = 4050
   SET @nStep = 1

   -- Init var
   SET @nPQTY = 0

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   SET @cMUOM_Desc = ''
   SET @nQTY_Move = 0
   SET @cOrderKey = ''

   SET @cMergePlt = rdt.RDTGetConfig( @nFunc, 'MergePltDefaultOpt', @cStorerKey)
   IF ISNULL(@cMergePlt, '') IN ('', '0')
      SET @cMergePlt = ''

   -- (ChewKP01) 
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)

   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   -- Prep next screen var
   SET @cFromID = ''
   SET @cOutField01 = ''         -- From DropID
   SET @cOutField02 = @cMergePlt -- Merge Pallet
   
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
Step 1. Screen = 4050
   FROM PALLET ID
   (Field01, input)
   Merge Pallet: (Field02, input)
   1 = Yes 2 = No
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField01
      SET @cMergePltOpt = @cInField02
      SET @cOrderKey = ''

      -- Validate blank
      IF ISNULL(@cFromID, '') = '' 
      BEGIN
         SET @nErrNo = 51651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID needed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Check if pallet exists and with inventory
      SET @nStorer_Cnt = 0
      SELECT @nStorer_Cnt = COUNT( DISTINCT StorerKey)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      --WHERE LLI.StorerKey = @cStorerKey 
      WHERE LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   Qty > 0

      IF @nStorer_Cnt = 0
      BEGIN
         SET @nErrNo = 51652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

/*
      -- 1 pallet only 1 storer
      IF @nStorer_Cnt > 1   
      BEGIN
         SET @nErrNo = 51653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID mix storer
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      SELECT TOP 1 @cChkStorerKey = StorerKey
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   Qty > 0
*/
      SET @nMultiStorer = 0

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 
                        FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                        WHERE LLI.ID = @cFromID 
                        AND   LOC.Facility = @cFacility
                        AND   LLI.Qty > 0
                        AND   EXISTS ( SELECT 1 FROM dbo.StorerGroup ST WITH (NOLOCK) 
                                       WHERE StorerGroup = @cStorerGroup 
                                       AND   ST.StorerKey = LLI.StorerKey))
         BEGIN
            SET @nErrNo = 51685
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
            GOTO Step_1_Fail
         END

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
         SET @nMultiStorer = 1
      END

      -- Check pallet status
      IF EXISTS ( SELECT 1  
                  FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN StorerKey ELSE @cStorerKey END
                  AND   ID = @cFromID
                  AND   [Status] = '5'
                  AND   ShipFlag = 'Y')
      BEGIN
         SET @nErrNo = 51654
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID is shipped
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      SELECT TOP 1 @cFromLOC = LOC.Loc 
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN StorerKey ELSE @cStorerKey END 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   Qty > 0

      IF ISNULL( @cFromLOC, '') = ''
      BEGIN
         SET @nErrNo = 51675
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --From Loc Req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      SET @nErrNo = 0
      SET @cSKU = ''
      EXECUTE rdt.rdt_PltConso_GetNextSKU
         @nMobile,
         @nFunc,
         @cLangCode,
         @nStep,
         @nInputKey,
         @cFacility,
         @cStorerKey,
         @cFromID,
         @cOption,
         @nQty,
         @cToID,
         @nMultiStorer,
         @cSKU_StorerKey   OUTPUT,
         @cSKU             OUTPUT,
         @cDescr           OUTPUT,
         @nErrNo           OUTPUT,
         @cErrMsg          OUTPUT   

      IF @nErrNo <> 0 OR ISNULL( @cSKU, '') = '' OR ISNULL( @cSKU_StorerKey, '') = ''
      BEGIN
         SET @nErrNo = 51655
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No suggest sku
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      SET @cStorerKey = @cSKU_StorerKey

      -- Check from id format (james02)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cFromID) = 0
      BEGIN
         SET @nErrNo = 51686
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Extended update
      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromID         NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT, '           +
               '@cToID           NVARCHAR( 20), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQTY_Move, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_3_Fail
            END
         END
      END

      SELECT TOP 1 @cFromLOC = LOC.Loc 
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   Qty > 0

      SELECT @nSKU_CNT = COUNT( DISTINCT SKU), 
             @nID_Qty = ISNULL( SUM( QTY), 0) 
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   Qty > 0

      SELECT @cPackUOM3 = PACK.PACKUOM3
      FROM dbo.PACK PACK WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE SKU.Storerkey = @cStorerKey
      AND   SKU.SKU = @cSKU

      -- Validate Option if blank
      IF ISNULL(@cMergePltOpt, '') = '' 
      BEGIN
         SET @nErrNo = 51656
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField01 = @cFromID
         SET @cOutField02 = @cMergePlt
         GOTO Quit
      END

      -- Validate Option
      IF @cMergePltOpt NOT IN ('1', '2') 
      BEGIN
         SET @nErrNo = 51657
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField01 = @cFromID
         SET @cOutField02 = @cMergePlt
         GOTO Quit
      END

      IF @cMergePltOpt = '1' --Go to To ID screen
      BEGIN
         SET @cOutField01 = @cFromID   -- From DropID
         SET @cOutField02 = ''         -- SKU/UPC
         
         SET @nScn  = @nScn + 4
         SET @nStep = @nStep + 4
         SET @cMergePlt = @cMergePltOpt

         GOTO Quit
      END

      IF @cMergePltOpt = '2' -- Go to SKU/UPC screen
      BEGIN
         SET @cMergePlt = @cMergePltOpt

         -- Prep next screen var
         SET @cOutField01 = @cFromID -- From DropID
         SET @cOutField02 = @cStorerKey
         SET @cOutField03 = @nSKU_CNT
         SET @cOutField04 = @nID_Qty
         SET @cOutField05 = @cSKU
         SET @cOutField06 = SUBSTRING( @cDescr, 1, 20)
         SET @cOutField07 = SUBSTRING( @cDescr, 21, 20)
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END

      SET @nFromScn = 0
      SET @nFromStep = 0
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
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option


     SET @cMUOM_Desc = ''
     SET @nQTY_Move = 0

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
      SET @cFromID = ''
      SET @cOutField01 = ''
      SET @cOutField02 = @cMergePlt
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
END
GOTO Quit

/********************************************************************************
Step 2. Screen 4051
   FROM DROPID: 
   (Field01)
   SKU/UPC:
   (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cCurrentSKU = @cOutField05
      SET @cSKU = @cInField08
      SET @cOption = @cInField09
      SET @cOnScreenSKU = @cOutField05

      -- Validate blank
      IF ISNULL( @cSKU, '') = '' AND ISNULL( @cOption, '') = ''
      BEGIN
         SET @nErrNo = 0
         EXECUTE rdt.rdt_PltConso_GetNextSKU
            @nMobile,
            @nFunc,
            @cLangCode,
            @nStep,
            @nInputKey,
            @cFacility,
            @cStorerKey,
            @cFromID,
            @cOption,
            @nQty,
            @cToID,
            @nMultiStorer,
            @cSKU_StorerKey   OUTPUT,
            @cCurrentSKU      OUTPUT,
            @cDescr           OUTPUT,
            @nErrNo           OUTPUT,
            @cErrMsg          OUTPUT   

         IF ISNULL( @cCurrentSKU, '') <> ''
         BEGIN
            SET @cSKU = @cCurrentSKU
            SET @cStorerKey = @cSKU_StorerKey

            SELECT TOP 1 @cFromLOC = LOC.Loc 
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @cStorerKey
            AND   LLI.ID = @cFromID 
            AND   LOC.Facility = @cFacility
            AND   Qty > 0

            SELECT @nSKU_CNT = COUNT( DISTINCT SKU), 
                   @nID_Qty = ISNULL( SUM( QTY), 0)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @cStorerKey 
            AND   LLI.ID = @cFromID 
            AND   LOC.Facility = @cFacility
            AND   Qty > 0

            -- Prep next screen var
            SET @cOutField01 = @cFromID -- From DropID
            SET @cOutField02 = @cStorerKey
            SET @cOutField03 = @nSKU_CNT
            SET @cOutField04 = @nID_Qty
            SET @cOutField05 = @cSKU
            SET @cOutField06 = SUBSTRING( @cDescr, 1, 20)
            SET @cOutField07 = SUBSTRING( @cDescr, 21, 20)
            SET @cOutField08 = ''
            SET @cOutField09 = ''

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 51658
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more sku
            GOTO Step_2_SKU_Fail
         END

      END

      IF ISNULL( @cOption, '') <> '' OR ISNULL( @cSKU, '') <> ''
      BEGIN
         IF ISNULL( @cOption, '') <> '' AND @cOption <> '1'
         BEGIN
            SET @nErrNo = 51659
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID OPTION
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_2_OPT_Fail
         END

         -- Extended update
         IF @cExtendedValidateSP <> '' 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,       '     + 
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFromID         NVARCHAR( 20), ' +
                  '@cOption         NVARCHAR( 1), '  +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQty            INT, '           +
                  '@cToID           NVARCHAR( 20), ' +
                  '@nErrNo          INT OUTPUT,    ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT'  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQTY_Move, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                  GOTO Step_2_SKU_Fail
               END
            END
         END

         IF ISNULL( @cSKU, '') <> ''
            SET @cCurrentSKU = @cSKU

         EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cCurrentSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

         -- Validate SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 51660
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
            GOTO Step_2_SKU_Fail
         END

         -- Get SKU
         IF @nSKUCnt = 1
            EXEC [RDT].[rdt_GETSKU]
               @cStorerKey  = @cStorerKey
              ,@cSKU        = @cCurrentSKU   OUTPUT
              ,@bSuccess    = @b_Success     OUTPUT
              ,@nErr        = @nErrNo        OUTPUT
              ,@cErrMsg     = @cErrMsg       OUTPUT

         -- Validate barcode return multiple SKU
         IF @nSKUCnt > 1
         BEGIN
            IF @cMultiSKUBarcode IN ('1', '2')
            BEGIN
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
                  @cCurrentSKU  OUTPUT,
                  @nErrNo       OUTPUT,
                  @cErrMsg      OUTPUT,
                  'LOTXLOCXID.ID',    -- DocType
                  @cFromID

               IF @nErrNo = 0 -- Populate multi SKU screen
               BEGIN
                  -- Go to Multi SKU screen
                  SET @nFromScn = @nScn
                  SET @nFromStep = @nStep
                  SET @nScn = 3570
                  SET @nStep = @nStep + 7
                  GOTO Quit
               END
               IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
                  SET @nErrNo = 0
            END
            ELSE
            BEGIN
               SET @nErrNo = 51661
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'
               GOTO Step_2_SKU_Fail
            END
         END 
      
         SET @cSKU = @cCurrentSKU

         SELECT 
            @cMUOM_Desc = Pack.PackUOM3, 
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
               END AS INT),
            @cDescr = DESCR  --(TanJH01)
         FROM dbo.SKU S (NOLOCK) 
            INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

         -- Check if SKU exists on pallet
         IF NOT EXISTS (SELECT 1 
                        FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                        WHERE LLI.StorerKey = @cStorerKey 
                        AND   LLI.ID = @cFromID 
                        AND   LOC.Facility = @cFacility
                        AND   SKU = @cSKU
                        AND   Qty > 0)
         BEGIN
            SET @nErrNo = 51662
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU NOT ON ID'
            GOTO Step_2_SKU_Fail
         END
         
         -- Get SKU QTY
         SET @nQTY_Avail = 0 
         SET @nQTY_Alloc = 0
         SET @nQTY_Pick = 0

         SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),
                @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),
                @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey 
         AND   LLI.ID = @cFromID 
         AND   LOC.Facility = @cFacility
         AND   SKU = @cSKU

         IF (@nQTY_Avail + @nQTY_Alloc + @nQTY_Pick) = 0
         BEGIN
            SET @nErrNo = 51663
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No QTY to move'
            GOTO Step_2_SKU_Fail
         END

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY_Avail = 0
            SET @nPQTY_Alloc = 0
            SET @nPQTY_Pick = 0
            SET @nPQTY_Move  = 0
            SET @nMQTY_Avail = @nQTY_Avail 
            SET @nMQTY_Alloc = @nQTY_Alloc
            SET @nMQTY_Pick = @nQTY_Pick
         END
         ELSE
         BEGIN
            SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
            SET @nPQTY_Alloc = @nQTY_Alloc / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_Alloc = @nQTY_Alloc % @nPUOM_Div -- Calc the remaining in master unit
            SET @nPQTY_Pick = @nQTY_Pick / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_Pick = @nQTY_Pick % @nPUOM_Div -- Calc the remaining in master unit
         END

         -- Extended info sp (james16)
         SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
         IF @cExtendedInfoSP = '0'
            SET @cExtendedInfoSP = ''

         -- Extended update
         IF @cExtendedInfoSP <> '' 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @c_oFieled01 OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,       '     + 
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFromID         NVARCHAR( 20), ' +
                  '@cOption         NVARCHAR( 1), '  +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQty            INT, '           +
                  '@cToID           NVARCHAR( 20), ' +
                  '@c_oFieled01     NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @cExtendedInfo01 OUTPUT

            END
         END

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
         SET @cOutField12 = ''
         SET @cOutField13 = ''
         SET @cOutField14 = ''
         SET @cOutField15 = ''

         -- Prepare next screen var
         SET @nPQTY_Move = 0
         SET @nMQTY_Move = 0
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRInG(@cDescr, 1, 20)
         SET @cOutField03 = SUBSTRInG(@cDescr, 21, 20)

         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField04 = '' -- @cPUOM_Desc
            SET @cOutField05 = '' -- @nPQTY_Avail
            SET @cOutField06 = '' -- @nPQTY_Alloc
            SET @cOutField07 = '' -- @nPQTY_Pick
            SET @cOutField08 = '' -- @nPQTY_Move
            SET @cFieldAttr08 = 'O' 
         END
         ELSE
         BEGIN
            SET @cOutField04 = @cPUOM_Desc
            SET @cOutField05 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
            SET @cOutField06 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))
            SET @cOutField07 = CAST( @nPQTY_Pick AS NVARCHAR( 5))
            SET @cOutField08 = '' -- @nPQTY_Move
         END
         SET @cOutField09 = @cMUOM_Desc
         SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
         SET @cOutField11 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))
         SET @cOutField12 = CAST( @nMQTY_Pick AS NVARCHAR( 5))
         SET @cOutField13 = '' -- @nMQTY_Move
               

         IF @cFieldAttr08 = 'O'
            EXEC rdt.rdtSetFocusField @nMobile, 13
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 8 

         SET @cOutField14 = @cExtendedInfo01

         SET @cExtendedDefaultOptSP = rdt.rdtGetConfig( @nFunc, 'ExtendedDefaultOptSP', @cStorerKey)
         IF @cExtendedDefaultOptSP = '0'
            SET @cExtendedDefaultOptSP = ''

         IF @cExtendedDefaultOptSP NOT IN ('1', '2', '3')
         BEGIN
            -- Extended update
            IF @cExtendedDefaultOptSP <> '' 
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedDefaultOptSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedDefaultOptSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @cDefaultOpt OUTPUT'
                  SET @cSQLParam =
                     '@nMobile         INT,       '     +
                     '@nFunc           INT,       '     +
                     '@cLangCode       NVARCHAR( 3),  ' +
                     '@nStep           INT,       '     + 
                     '@nInputKey       INT,       '     +
                     '@cStorerKey      NVARCHAR( 15), ' +
                     '@cFromID         NVARCHAR( 20), ' +
                     '@cOption         NVARCHAR( 1), '  +
                     '@cSKU            NVARCHAR( 20), ' +
                     '@nQty            INT, '           +
                     '@cToID           NVARCHAR( 20), ' +
                     '@cDefaultOpt     NVARCHAR( 1)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @cDefaultOpt OUTPUT

               END
            END
         END
         ELSE
         BEGIN
            SET @cDefaultOpt = @cExtendedDefaultOptSP
         END
         
         SET @cOutField15 = @cDefaultOpt

         -- Go to QTY screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
      
      SET @cOutField01 = ''
      SET @cOutField02 = @cMergePlt

      SET @cMUOM_Desc = ''
      SET @nQTY_Move = 0

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

   Step_2_SKU_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField08 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 8
      GOTO Quit
   END

   Step_2_OPT_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField09 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 9
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 3. Screen = 4052
   SKU
   (Field01)
   (Field02)
   (Field03)
   (Field04)
   (Field05)
   (Field06)
   (Field07)
   PUOM MUOM  (Field08, Field12)
   QTY AVL    (Field09, Field12)
   QTY MV     (Field10, Field13 input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPQTY = CASE WHEN @cFieldAttr08 = 'O' THEN '' ELSE IsNULL( @cInField08, '') END
      SET @cMQTY = CASE WHEN @cFieldAttr13 = 'O' THEN '' ELSE IsNULL( @cInField13, '') END
      SET @cOption = IsNULL( @cInField15, '')

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

      -- Retain the key-in value
      SET @cOutField08 = @cInField07 -- Pref QTY
      SET @cOutField13 = @cInField10 -- Master QTY

      -- Validate PQTY
      IF @cPQTY = '' SET @cPQTY = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 51666
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- PQTY
         GOTO Step_3_Fail
      END
      
      -- Validate MQTY
      IF @cMQTY  = '' SET @cMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 51667
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- MQTY
         GOTO Step_3_Fail
      END
      
      -- Calc total QTY in master UOM
      SET @nPQTY_Move = CAST( @cPQTY AS INT)
      SET @nMQTY_Move = CAST( @cMQTY AS INT)
      SET @nQTY_Move = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY_Move = @nQTY_Move + @nMQTY_Move

      -- Validate QTY
      IF @nQTY_Move = 0
      BEGIN
         SET @nErrNo = 51668
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY needed'
      GOTO Step_3_Fail
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY_Move > ( @nQTY_Avail + @nQTY_Alloc + @nQTY_Pick)
      BEGIN
         SET @nErrNo = 51669
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTYAVL NotEnuf'
         GOTO Step_3_Fail
      END

      IF @cOption = ''
      BEGIN
         SET @nErrNo = 51676
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option req'
         GOTO Step_3_Fail
      END

      IF @cOption NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 51677
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_3_Fail
      END

      -- Qty available check
      IF @cOption = '1'
      BEGIN
         IF @nQTY_Move > @nQTY_Avail 
         BEGIN
            SET @nErrNo = 51681
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
            GOTO Step_3_Fail
         END

         -- When move available qty, check if the sku contain multi lot in 1 pallet
         -- if multi lot then system don't know which lot to move. So block to move
         IF @nQTY_Move <> @nQTY_Avail -- Move partial qty of the SKU
         BEGIN
            SELECT @nLOTCount = COUNT( A.ID)
            FROM 
            (
               SELECT ID
               FROM dbo.LOTxLOCxID WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND   ID = @cFromID
                  AND   SKU = @cSKU
                  AND   (Qty - QtyAllocated - QtyPicked) > 0
               GROUP BY ID
               HAVING COUNT( DISTINCT LOT) > 1
            ) A

            -- If ID contain > 1 LOT
            IF @nLOTCount > 0
            BEGIN
               SET @nErrNo = 51684
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'AVL QTY >1 LOT'
               GOTO Step_3_Fail
            END
         END

         SET @nQTY_Alloc = 0
         SET @nQTY_Pick = 0
      END

      -- Qty available check
      IF @cOption = '2'
      BEGIN
         IF @nQTY_Move > @nQTY_Alloc 
         BEGIN
            SET @nErrNo = 51682
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
            GOTO Step_3_Fail
         END
         SET @nQTY_Avail = 0
         SET @nQTY_Pick = 0
      END

      -- Qty available check
      IF @cOption = '3'
      BEGIN
         IF @nQTY_Move > @nQTY_Pick 
         BEGIN
            SET @nErrNo = 51683
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
            GOTO Step_3_Fail
         END

         SET @nQTY_Avail = 0
         SET @nQTY_Alloc = 0
      END

      -- Extended update
      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromID         NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT, '           +
               '@cToID           NVARCHAR( 20), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQTY_Move, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_3_Fail
            END
         END
      END

      -- Move Picked qty
      IF @cOption = '3'
      BEGIN
         SET @cOrder_Cnt = 0
         SELECT @cOrder_Cnt = COUNT( DISTINCT OrderKey)
         FROM dbo.PICKDETAIL WITH (NOLOCK) 
         WHERE Storerkey = @cStorerKey
         AND ID = @cFromID
         AND [Status] = '5'
         AND SKU = @cSKU

         IF @cOrder_Cnt > 1
         BEGIN
            SET @cOutField01 = ''

            SET @nScn  = @nScn + 5
            SET @nStep = @nStep + 5

            GOTO Quit
         END
         ELSE
            SET @cOrderKey = ''
            SELECT TOP 1 @cOrderKey = OrderKey 
            FROM dbo.PICKDETAIL WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey
            AND ID = @cFromID
            AND [Status] = '5'
            AND SKU = @cSKU
      END

      /*
      SET @bSuccess = 0
      EXEC rdt.rdtIsAmbiguous 
          @nA           = @nQTY_Avail
         ,@nB           = @nQTY_Alloc
         ,@nC           = @nQTY_Pick
         ,@nQty2Check   = @nQTY_Move
         ,@b_Success    = @b_Success   OUTPUT  
         ,@n_ErrNo      = @n_Err       OUTPUT  
         ,@c_ErrMsg     = @c_ErrMsg    OUTPUT 

      IF @b_Success = 0  
      BEGIN
         SET @nErrNo = 51674
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTYAVL NotEnuf'
         GOTO Step_3_Fail
      END
      */

      -- Get Autogen ToID Conf
      SET @cGenID = rdt.rdtGetConfig( @nFunc, 'AutoGenID', @cStorerKey)
      IF @cGenID = '0'
      BEGIN
        SET @cGenID = ''
      END
      -- Get AutoGenID
      IF @cGenID <> ''
      BEGIN
         EXEC [rdt].[rdt_AutoGenID]
            @nMobile,
            @nFunc,
            @nStep,
            @cLangCode,
            @cGenID,
            @tExtData,
            @cAutoID    OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
            
         IF @nErrNo <> 0
         BEGIN
            GOTO Step_3_Fail
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField05 = '' -- @cPUOM_Desc
         SET @cOutField06 = '' -- @nPQTY_Move
         SET @cFieldAttr06 = 'O' -- (Vicky02)
      END
      ELSE
      BEGIN
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField06 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField07 = @cMUOM_Desc
      SET @cOutField08 = CAST( @nMQTY_Move AS NVARCHAR( 5))
      -- SET @cOutField09 = '' -- To DropID
      -- SET AutoGenID
      IF @cAutoID <> ''
      BEGIN
         SET @cOutField09 = @cAutoID
      END
      ELSE 
      BEGIN
         SET @cOutField09 = ''
      END      

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @nSKU_CNT = COUNT( DISTINCT SKU), 
             @nID_Qty = ISNULL( SUM( QTY), 0) 
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   Qty > 0

      -- Prep next screen var
      SET @cOutField01 = @cFromID -- From DropID
      SET @cOutField02 = @cStorerKey
      SET @cOutField03 = @nSKU_CNT
      SET @cOutField04 = @nID_Qty
      SET @cOutField05 = @cSKU
      SET @cOutField06 = SUBSTRING( @cDescr, 1, 20)
      SET @cOutField07 = SUBSTRING( @cDescr, 21, 20)
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      SET @cOutField13 = ''

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      -- Re-enable back the disbaled field
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

   Step_3_Fail:
   BEGIN
      -- Get SKU QTY
      SET @nQTY_Avail = 0 
      SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),
             @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),
             @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   SKU = @cSKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Avail = 0
         SET @nPQTY_Alloc = 0
         SET @nPQTY_Pick = 0
         SET @nPQTY_Move  = 0
         SET @nMQTY_Avail = @nQTY_Avail 
         SET @nMQTY_Alloc = @nQTY_Alloc
         SET @nMQTY_Pick = @nQTY_Pick
      END
      ELSE
      BEGIN
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY_Alloc = @nQTY_Alloc / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Alloc = @nQTY_Alloc % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY_Pick = @nQTY_Pick / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Pick = @nQTY_Pick % @nPUOM_Div -- Calc the remaining in master unit
      END

      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField04 = '' -- @cPUOM_Desc
         SET @cOutField05 = '' -- @nPQTY_Avail
         SET @cOutField06 = '' -- @nPQTY_Alloc
         SET @cOutField07 = '' -- @nPQTY_Pick
         SET @cOutField08 = '' -- @nPQTY_Move
         SET @cFieldAttr08 = 'O' 
      END
      ELSE
      BEGIN
         SET @cOutField04 = @cPUOM_Desc
         SET @cOutField05 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField06 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))
         SET @cOutField07 = CAST( @nPQTY_Pick AS NVARCHAR( 5))
         SET @cOutField08 = '' -- @nPQTY_Move
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField11 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))
      SET @cOutField12 = CAST( @nMQTY_Pick AS NVARCHAR( 5))
      SET @cOutField13 = '' -- @nMQTY_Move

      IF @cFieldAttr08 = 'O'
         EXEC rdt.rdtSetFocusField @nMobile, 13
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 8 

      SET @cOutField08 = '' -- PQTY
      SET @cOutField13 = '' -- MQTY
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 4053
   FROM DROPID:
   (Field01)
   SKU:
   (Field02)
   (Field03)
   (Field04)
   PUOM MUOM  (Field05, Field07)
   QTY MV     (Field06, Field08)
   To DROPID:
   (Field09, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField09

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
      
      -- Validate blank
      IF ISNULL(@cToID, '') = ''
      BEGIN
         SET @nErrNo = 51670
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_4_Fail
      END
      
      -- Validate if From DropID = To DropID
      IF @cFromID = @cToID
      BEGIN
         SET @nErrNo = 51671
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_4_Fail
      END

      -- Check from id format (james02)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cToID) = 0
      BEGIN
         SET @nErrNo = 51687
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_4_Fail
      END

      -- Extended update
      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromID         NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT, '           +
               '@cToID           NVARCHAR( 20), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_4_Fail
            END
         END
      END

      -- ID not exists
      IF NOT EXISTS ( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cToID)
      BEGIN
         SET @cOutField01 = ''

         -- Go to option screen
         SET @nScn  = @nScn + 3
         SET @nStep = @nStep + 3

         GOTO Quit       
      END

      SET @nMV_Alloc = 0
      SET @nMV_Pick = 0

      IF @nQTY_Alloc > 0 SET @nMV_Alloc = @nQTY_Move

      IF @nQTY_Pick > 0 SET @nMV_Pick = @nQTY_Move       

      -- EXEC move
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, 
         @cSourceType = 'rdtfnc_PalletConsolidate',
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility,
         @cFromLOC    = @cFromLOC,
         @cToLOC      = @cFromLOC,
         @cFromID     = @cFromID,     
         @cToID       = @cToID,       
         @cSKU        = @cSKU,
         @nQTY        = @nQTY_Move,
         @nQTYAlloc   = @nMV_Alloc,
         @nQTYPick    = @nMV_Pick, 
         @nFunc       = @nFunc, 
         @cOrderKey   = @cOrderKey
                  
      IF @nErrNo <> 0
         GOTO Step_4_Fail
      ELSE
      BEGIN
         -- Extended update
         IF @cExtendedUpdateSP <> '' 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,       '     + 
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFromID         NVARCHAR( 20), ' +
                  '@cOption         NVARCHAR( 1), '  +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQty            INT, '           +
                  '@cToID           NVARCHAR( 20), ' +
                  '@nErrNo          INT OUTPUT,    ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT'  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                  GOTO Step_4_Fail
               END
            END
         END
         
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cID           = @cFromID,
            @cToID         = @cToID, 
            @cUOM          = @cPackUOM3,
            @nQTY          = @nQTY_Move,
            @cOrderKey     = @cOrderKey,
            @cRefNo1       = 'PALLET PARTIAL MOVE'

         -- Check if pallet still have another sku to move
         SET @nErrNo = 0
         SET @cCurrentSKU = @cSKU
         EXECUTE rdt.rdt_PltConso_GetNextSKU
            @nMobile,
            @nFunc,
            @cLangCode,
            @nStep,
            @nInputKey,
            @cFacility,
            @cStorerKey,
            @cFromID,
            @cOption,
            @nQty,
            @cToID,
            @nMultiStorer,
            @cSKU_StorerKey   OUTPUT,
            @cCurrentSKU      OUTPUT,
            @cDescr           OUTPUT,
            @nErrNo           OUTPUT,
            @cErrMsg          OUTPUT   

         IF ISNULL( @cCurrentSKU, '') = ''
         BEGIN
            -- Go to message screen
            SET @nScn  = @nScn + 2
            SET @nStep = @nStep + 2

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @cSKU = @cCurrentSKU
            SET @cStorerKey = @cSKU_StorerKey

            SELECT TOP 1 @cFromLOC = LOC.Loc 
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @cStorerKey
            AND   LLI.ID = @cFromID 
            AND   LOC.Facility = @cFacility
            AND   Qty > 0

            SELECT @cPackUOM3 = PACK.PACKUOM3
            FROM dbo.PACK PACK WITH (NOLOCK)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
            WHERE SKU.Storerkey = @cStorerKey
            AND   SKU.SKU = @cSKU

            SELECT @nSKU_CNT = COUNT( DISTINCT SKU), 
                     @nID_Qty = ISNULL( SUM( QTY), 0)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @cStorerKey 
            AND   LLI.ID = @cFromID 
            AND   LOC.Facility = @cFacility
            AND   Qty > 0

            -- Prep next screen var
            SET @cOutField01 = @cFromID -- From DropID
            SET @cOutField02 = @cStorerKey
            SET @cOutField03 = @nSKU_CNT
            SET @cOutField04 = @nID_Qty
            SET @cOutField05 = @cSKU
            SET @cOutField06 = SUBSTRING( @cDescr, 1, 20)
            SET @cOutField07 = SUBSTRING( @cDescr, 21, 20)
            SET @cOutField08 = ''
            SET @cOutField09 = ''

            -- Go to message screen
            SET @nScn  = @nScn - 2
            SET @nStep = @nStep - 2

            GOTO Quit
         END
      END

      -- Go to message screen
      SET @nScn  = @nScn + 2
      SET @nStep = @nStep + 2

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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
      SET @cOutField12 = ''
      SET @cOutField13 = ''
      SET @cOutField14 = ''
      SET @cOutField15 = ''

      -- Get SKU QTY
      SET @nQTY_Avail = 0 
      SET @nQTY_Alloc = 0
      SET @nQTY_Pick = 0
      SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),
               @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),
               @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   SKU = @cSKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Avail = 0
         SET @nPQTY_Alloc = 0
         SET @nPQTY_Pick = 0
         SET @nPQTY_Move  = 0
         SET @nMQTY_Avail = @nQTY_Avail 
         SET @nMQTY_Alloc = @nQTY_Alloc
         SET @nMQTY_Pick = @nQTY_Pick
      END
      ELSE
      BEGIN
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY_Alloc = @nQTY_Alloc / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Alloc = @nQTY_Alloc % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY_Pick = @nQTY_Pick / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Pick = @nQTY_Pick % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prepare next screen var
      SET @nPQTY_Move = 0
      SET @nMQTY_Move = 0
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRInG(@cDescr, 1, 20)
      SET @cOutField03 = SUBSTRInG(@cDescr, 21, 20)

      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField04 = '' -- @cPUOM_Desc
         SET @cOutField05 = '' -- @nPQTY_Avail
         SET @cOutField06 = '' -- @nPQTY_Alloc
         SET @cOutField07 = '' -- @nPQTY_Pick
         SET @cOutField08 = '' -- @nPQTY_Move
         SET @cFieldAttr08 = 'O' 
      END
      ELSE
      BEGIN
         SET @cOutField04 = @cPUOM_Desc
         SET @cOutField05 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField06 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))
         SET @cOutField07 = CAST( @nPQTY_Pick AS NVARCHAR( 5))
         SET @cOutField08 = '' -- @nPQTY_Move
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField11 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))
      SET @cOutField12 = CAST( @nMQTY_Pick AS NVARCHAR( 5))
      SET @cOutField13 = '' -- @nMQTY_Move
               
      IF @cFieldAttr08 = 'O'
         EXEC rdt.rdtSetFocusField @nMobile, 13
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 8 

      SET @cOutField14 = @cExtendedInfo01

      SET @cExtendedDefaultOptSP = rdt.rdtGetConfig( @nFunc, 'ExtendedDefaultOptSP', @cStorerKey)
      IF @cExtendedDefaultOptSP = '0'
         SET @cExtendedDefaultOptSP = ''

      IF @cExtendedDefaultOptSP NOT IN ('1', '2', '3')
      BEGIN
         -- Extended update
         IF @cExtendedDefaultOptSP <> '' 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedDefaultOptSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedDefaultOptSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @cDefaultOpt OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,       '     + 
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFromID         NVARCHAR( 20), ' +
                  '@cOption         NVARCHAR( 1), '  +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQty            INT, '           +
                  '@cToID           NVARCHAR( 20), ' +
                  '@cDefaultOpt     NVARCHAR( 1)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @cDefaultOpt OUTPUT
            END
         END
      END
      ELSE
      BEGIN
         SET @cDefaultOpt = @cExtendedDefaultOptSP
      END
         
      SET @cOutField15 = @cDefaultOpt
               
      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cToID = ''
      SET @cOutField09 = '' -- To DropID
   END
END
GOTO Quit


/********************************************************************************
Step 5. Screen = 4054
   FROM DROPID:
   (Field01)
	Orderkey: Field03
	Field04 (Loadkey)   
   Field05 (xternOrderkey)
   Field06 (CCompany1)
   Field07 (CCompany2)      
   Field08 (Door)           
   Field09 (Route)          
   Field10 (Stop)           
   TO DROPID:
   (Field02, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField02

      

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
      
      -- Validate blank
      IF ISNULL(@cToID, '') = ''
      BEGIN
         SET @nErrNo = 51672
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_5_Fail
      END

      -- Validate if From DropID = To DropID
      IF @cFromID = @cToID
      BEGIN
         SET @nErrNo = 51673
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Both ID Same
         GOTO Step_5_Fail
      END

      -- Check from id format (james02)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cToID) = 0
      BEGIN
         SET @nErrNo = 51688
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_5_Fail
      END

      -- Extended update
      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromID         NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT, '           +
               '@cToID           NVARCHAR( 20), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_5_Fail
            END
         END
      END


      -- Check if To DropID exists within same storer
      IF NOT EXISTS(SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cToID)
      BEGIN
         SET @cOutField01 = ''

         -- Go to option screen
         SET @nScn  = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO Quit       
      END

      -- Get the To LOC. Check if the To ID already have inventory
      -- If yes then take the To LOC from To ID
      SELECT TOP 1 @cToLOC = LOC.Loc 
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cToID 
      AND   LOC.Facility = @cFacility
      AND   QTY > 0

      -- If To ID do not have inventory then take To Loc = From Loc
      IF ISNULL( @cToLOC, '') = ''
         SET @cToLOC = @cFromLOC

      -- EXEC move
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, 
         @cSourceType = 'rdtfnc_PalletConsolidate',
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility,
         @cFromLOC    = @cFromLOC,
         @cToLOC      = @cToLOC,
         @cFromID     = @cFromID,     
         @cToID       = @cToID,       
         @nFunc       = @nFunc, 
         @cOrderKey   = ''

         
      IF @nErrNo <> 0
         GOTO Step_5_Fail
      ELSE
      BEGIN
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cID           = @cFromID,
            @cToID         = @cToID, 
            @cUOM          = @cPackUOM3,
            @nQTY          = 0, 
            @cRefNo1       = 'FULL PALLET MOVE'
      END
      
      -- Extended update
      IF @cExtendedUpdateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromID         NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT, '           +
               '@cToID           NVARCHAR( 20), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_5_Fail
            END
         END
      END

      -- Go to message screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep prev screen var
      SET @cOutField01 = '' -- From DropID
      SET @cOutField02 = @cMergePlt -- Merge Pallet

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
      
      -- Go to prev screen
      SET @nScn  = @nScn - 4
      SET @nStep = @nStep - 4
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cToID = ''
      SET @cOutField01 = @cFromID -- From DropID
      SET @cOutField02 = '' -- To DropID
   END
END
GOTO Quit

/********************************************************************************
Step 6. Screen = 4055
   Message
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey IN (1, 0) -- ENTER/ESC
   BEGIN
		IF @cMergePlt = '1'
		BEGIN
			SET @cOutField01 = '' -- From DropID
			SET @cOutField02 = '1' -- Merge Pallet
			SET @cFromID = ''
			SET @cMergePlt = ''    
	 
			SET @cMUOM_Desc = ''
			SET @nQTY_Move = 0

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

			-- Go to From ID screen
			SET @nScn  = @nScn - 5
			SET @nStep = @nStep - 5
		END
		ELSE
		IF @cMergePlt = '2'
		BEGIN
         SET @cMergePlt = rdt.RDTGetConfig( @nFunc, 'MergePltDefaultOpt', @cStorerKey)
         IF ISNULL(@cMergePlt, '') IN ('', '0')
            SET @cMergePlt = ''

         -- Prep next screen var
         SET @cFromID = ''
         SET @cOutField01 = ''         -- From DropID
         SET @cOutField02 = @cMergePlt -- Merge Pallet

			SET @cMUOM_Desc = ''
			SET @nQTY_Move = 0

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

			-- Go to sku/upc screen
			SET @nScn  = @nScn - 5
			SET @nStep = @nStep - 5
		END
   END
END
GOTO Quit

/********************************************************************************
Step 7. Screen = 4056
   Option (Field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
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

      -- Screen mapping
      SET @cOption = @cInField01
      
      

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 63880
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
         GOTO Step_7_Fail
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 63881
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Step_7_Fail
      END

      -- Get the To LOC. Check if the To ID already have inventory
      -- If yes then take the To LOC from To ID
      SELECT TOP 1 @cToLOC = LOC.Loc 
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cToID 
      AND   LOC.Facility = @cFacility
      AND   QTY > 0

      -- If To ID do not have inventory then take To Loc = From Loc
      IF ISNULL( @cToLOC, '') = ''
         SET @cToLOC = @cFromLOC

      IF @cOption = '1' -- YES
      BEGIN
         IF @cMergePlt = '1'
         BEGIN
            -- EXEC move
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, 
               @cSourceType = 'rdtfnc_PalletConsolidate',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLOC,
               @cFromID     = @cFromID,     
               @cToID       = @cToID,      
               @nFunc       = @nFunc, 
               @cOrderKey   = ''

            IF @nErrNo <> 0
               GOTO Step_7_Fail
            ELSE
            BEGIN
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '4', -- Move
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerkey,
                  @cID           = @cFromID,
                  @cToID         = @cToID, 
                  @cUOM          = @cPackUOM3,
                  @nQTY          = 0, 
                  @cRefNo1       = 'FULL PALLET MOVE'
            END
         END
         ELSE
         BEGIN
            SET @nMV_Alloc = 0
            SET @nMV_Pick = 0

            IF @nQTY_Alloc > 0 SET @nMV_Alloc = @nQTY_Move

            IF @nQTY_Pick > 0 SET @nMV_Pick = @nQTY_Move            

            -- EXEC move
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, 
               @cSourceType = 'rdtfnc_PalletConsolidate',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cFromLOC,
               @cFromID     = @cFromID,     
               @cToID       = @cToID,       
               @cSKU        = @cSKU,
               @nQTY        = @nQTY_Move,
               @nQTYAlloc   = @nMV_Alloc,
               @nQTYPick    = @nMV_Pick, 
               @nFunc       = @nFunc, 
               @cOrderKey   = @cOrderKey


            IF @nErrNo <> 0
            BEGIN
               GOTO Step_7_Fail
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
                  @cID           = @cFromID,
                  @cToID         = @cToID, 
                  @cUOM          = @cPackUOM3,
                  @nQTY          = @nQTY_Move,
                  @cOrderKey     = @cOrderKey,
                  @cRefNo1       = 'PALLET PARTIAL MOVE'
            END
         END

         -- Extended update
         IF @cExtendedUpdateSP <> '' 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,       '     + 
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFromID         NVARCHAR( 20), ' +
                  '@cOption         NVARCHAR( 1), '  +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQty            INT, '           +
                  '@cToID           NVARCHAR( 20), ' +
                  '@nErrNo          INT OUTPUT,    ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT'  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                  GOTO Step_7_Fail
               END
            END
         END
         
         -- Go to message screen
         SET @nScn  = @nScn - 1 
         SET @nStep = @nStep - 1
         
         GOTO Quit
      END
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
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

      IF @cMergePlt = '1'      
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = '1'   

         SET @nScn  = @nScn - 2
         SET @nStep = @nStep - 2
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cFromID
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
         SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField05 = '' -- @cPUOM_Desc
            SET @cOutField06 = '' -- @nPQTY_Move
            SET @cFieldAttr06 = 'O' 
         END
         ELSE
         BEGIN
            SET @cOutField05 = @cPUOM_Desc
            SET @cOutField06 = CAST( @nPQTY_Move AS NVARCHAR( 5))
         END
         SET @cOutField07 = @cMUOM_Desc
         SET @cOutField08 = CAST( @nMQTY_Move AS NVARCHAR( 5))
         SET @cOutField09 = '' -- To DropID

         SET @nScn  = @nScn - 3
         SET @nStep = @nStep - 3
      END      
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit

/********************************************************************************
Step 8. Screen = 4057
   Option (Field01, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
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

      -- Screen mapping
      SET @cOrderKey = @cInField01
      
      -- Validate blank
      IF ISNULL( @cOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 51678
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Orderkey req
         GOTO Step_8_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND   OrderKey = @cOrderKey
                      AND   ID = @cFromID
                      AND   [Status] = '5')
      BEGIN
         SET @nErrNo = 51679
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Orderkey
         GOTO Step_8_Fail
      END
      
      -- Get Autogen ToID Conf
      SET @cGenID = rdt.rdtGetConfig( @nFunc, 'AutoGenID', @cStorerKey)
      IF @cGenID = '0'
      BEGIN
        SET @cGenID = ''
      END
      -- Get AutoGenID
      IF @cGenID <> ''
      BEGIN
         EXEC [rdt].[rdt_AutoGenID]
            @nMobile,
            @nFunc,
            @nStep,
            @cLangCode,
            @cGenID,
            @tExtData,
            @cAutoID    OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         
         IF @nErrno <> 0
         BEGIN
            GOTO Step_8_Fail
         END
      END      
   
      -- Prepare next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField05 = '' -- @cPUOM_Desc
         SET @cOutField06 = '' -- @nPQTY_Move
         SET @cFieldAttr06 = 'O' -- (Vicky02)
      END
      ELSE
      BEGIN
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField06 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField07 = @cMUOM_Desc
      SET @cOutField08 = CAST( @nMQTY_Move AS NVARCHAR( 5))
      -- SET @cOutField09 = '' -- To DropID
      IF @cAutoID <> ''
      BEGIN
         SET @cOutField09 = @cAutoID
      END
      ELSE 
      BEGIN
         SET @cOutField09 = ''
      END
      -- Go to next screen
      SET @nScn  = @nScn - 4
      SET @nStep = @nStep - 4
      
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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
      SET @cOutField12 = ''
      SET @cOutField13 = ''
      SET @cOutField14 = ''
      SET @cOutField15 = ''

      SET @nQTY_Avail = 0 
      SET @nQTY_Alloc = 0
      SET @nQTY_Pick = 0

      SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),
               @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),
               @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   SKU = @cSKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Avail = 0
         SET @nPQTY_Alloc = 0
         SET @nPQTY_Pick = 0
         SET @nPQTY_Move  = 0
         SET @nMQTY_Avail = @nQTY_Avail 
         SET @nMQTY_Alloc = @nQTY_Alloc
         SET @nMQTY_Pick = @nQTY_Pick
      END
      ELSE
      BEGIN
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY_Alloc = @nQTY_Alloc / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Alloc = @nQTY_Alloc % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY_Pick = @nQTY_Pick / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Pick = @nQTY_Pick % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prepare next screen var
      SET @nPQTY_Move = 0
      SET @nMQTY_Move = 0
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRInG(@cDescr, 1, 20)
      SET @cOutField03 = SUBSTRInG(@cDescr, 21, 20)

      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField04 = '' -- @cPUOM_Desc
         SET @cOutField05 = '' -- @nPQTY_Avail
         SET @cOutField06 = '' -- @nPQTY_Alloc
         SET @cOutField07 = '' -- @nPQTY_Pick
         SET @cOutField08 = '' -- @nPQTY_Move
         SET @cFieldAttr08 = 'O' 
      END
      ELSE
      BEGIN
         SET @cOutField04 = @cPUOM_Desc
         SET @cOutField05 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField06 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))
         SET @cOutField07 = CAST( @nPQTY_Pick AS NVARCHAR( 5))
         SET @cOutField08 = '' -- @nPQTY_Move
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField11 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))
      SET @cOutField12 = CAST( @nMQTY_Pick AS NVARCHAR( 5))
      SET @cOutField13 = '' -- @nMQTY_Move
               
      IF @cFieldAttr08 = 'O'
         EXEC rdt.rdtSetFocusField @nMobile, 13
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 8 

      SET @cOutField14 = @cExtendedInfo01

      SET @cExtendedDefaultOptSP = rdt.rdtGetConfig( @nFunc, 'ExtendedDefaultOptSP', @cStorerKey)
      IF @cExtendedDefaultOptSP = '0'
         SET @cExtendedDefaultOptSP = ''

      IF @cExtendedDefaultOptSP NOT IN ('1', '2', '3')
      BEGIN
         -- Extended update
         IF @cExtendedDefaultOptSP <> '' 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedDefaultOptSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedDefaultOptSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @cDefaultOpt OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,       '     + 
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFromID         NVARCHAR( 20), ' +
                  '@cOption         NVARCHAR( 1), '  +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQty            INT, '           +
                  '@cToID           NVARCHAR( 20), ' +
                  '@cDefaultOpt     NVARCHAR( 1)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @cDefaultOpt OUTPUT
            END
         END
      END
      ELSE
      BEGIN
         SET @cDefaultOpt = @cExtendedDefaultOptSP
      END
         
      SET @cOutField15 = @cDefaultOpt

      -- Go to QTY screen
      SET @nScn  = @nScn - 5
      SET @nStep = @nStep - 5
   END

   GOTO Quit

   Step_8_Fail:
   BEGIN
      SET @cOrderKey = ''
      SET @cOutField01 = '' -- OrderKey
   END
END
GOTO Quit

/********************************************************************************
Step 9. Screen = 3570. Multi SKU
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
Step_9:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cCurrentSKU = @cSKU
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
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END
      
      -- Extended update
      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQty, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromID         NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT, '           +
               '@cToID           NVARCHAR( 20), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cOption, @cSKU, @nQTY_Move, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               SET @nErrNo = 0
               SET @cSKU = @cCurrentSKU
               GOTO Quit
            END
         END
      END
      
      -- Get SKU info
      SELECT @cDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

      SET @cMergePlt = @cMergePltOpt

      -- Prep next screen var
      SET @cOutField01 = @cFromID -- From DropID
      SET @cOutField02 = @cStorerKey
      SET @cOutField03 = @nSKU_CNT
      SET @cOutField04 = @nID_Qty
      SET @cOutField05 = @cSKU
      SET @cOutField06 = SUBSTRING( @cDescr, 1, 20)
      SET @cOutField07 = SUBSTRING( @cDescr, 21, 20)
      SET @cOutField08 = ''
      SET @cOutField09 = ''

      -- Go to SKU QTY screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep

      -- To indicate sku has been successfully selected
      SET @nFromScn = 3570
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cMergePlt = @cMergePltOpt

      -- Prep next screen var
      SET @cOutField01 = @cFromID -- From DropID
      SET @cOutField02 = @cStorerKey
      SET @cOutField03 = @nSKU_CNT
      SET @cOutField04 = @nID_Qty
      SET @cOutField05 = @cOnScreenSKU
      SET @cOutField06 = SUBSTRING( @cDescr, 1, 20)
      SET @cOutField07 = SUBSTRING( @cDescr, 21, 20)
      SET @cOutField08 = ''
      SET @cOutField09 = ''

      -- Go to SKU QTY screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep
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

      V_StorerKey = @cStorerKey, 
      Facility    = @cFacility, 
      -- UserName    = @cUserName,

      V_SKU       = @cSKU,
      V_SKUDescr  = @cDescr,
      V_UOM       = @cPUOM,
      V_LOC       = @cFromLOC,
      V_OrderKey  = @cOrderKey,         

      V_String1 = @cFromID,
      V_String2 = @cToID, 
      V_String3 = @cMergePltOpt,
      V_String4 = @cPUOM_Desc,
      V_String5 = @cMUOM_Desc,
      V_String6 = @nPUOM_Div,
      V_String7 = @nMQTY,
      V_String8 = @nPQTY,
      V_String9 = @nQTY_Avail, 
      V_String10 = @nPQTY_Avail, 
      V_String11 = @nMQTY_Avail, 
      V_String12 = @nPQTY_Move, 
      V_String13 = @nMQTY_Move, 
      V_String14 = @nQTY_Move, 
      V_String15 = @cPackUOM3_Merge, 
      V_String16 = @nQtyMove_Merge, 
      V_String17 = @cMergePlt, 
      V_String18 = @nQTY_Alloc,
      V_String19 = @nQTY_Pick,
      V_String20 = @cOption, 
      V_String21 = @cPackUOM3, 
      V_String22 = @nMultiStorer,
      V_String23 = @cExtendedUpdateSP,
      V_String24 = @cMultiSKUBarcode,
      V_String25 = @nFromScn,
      V_String26 = @nFromStep,
      V_String27 = @cExtendedValidateSP,
      V_String28 = @cOnScreenSKU,

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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_MoveToUCC_V7                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Move To UCC with dynamic lottable                                 */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-02-17 1.0  James    WMS-12070. Created                                */
/* 2021-03-26 1.1  James    WMS-16614 Add StdEventLog to step to ucc (james01)*/
/* 2021-07-27 1.2  SYChua   Bug Fix: duplicated @cid in SP execution (SY01)   */
/* 2022-08-08 1.3  Ung      WMS-20238 Add ExtendedValidateSP to SKU screen    */
/*                          Add ToID format                                   */
/* 2023-01-25 1.4  Ung      WMS-21506 Add Prepack SKU                         */
/*                          Add ExtenededValidateSP at From LOC screen        */
/*                          Add AutoGenUCC                                    */
/*                          Add CustomCaseCNTSP                               */
/*                          Add DecodeSP                                      */
/*                          Add MassBuildUCC, SValue=2                        */
/*                          Add UCCWithDynamicCaseCNT                         */
/*                          Clean up source                                   */
/* 2023-03-27 1.5  Ung      WMS-22105 Skip FROM ID, TO ID, if LoseID          */
/*                          Fix PQTYAvail not shown, when DisableQTYField     */
/******************************************************************************/
CREATE   PROC [RDT].[rdtfnc_MoveToUCC_V7](
   @nMobile    INT,
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
) AS

-- Misc variable
DECLARE
   @bSuccess            INT,
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @nMorePage           INT,
   @cLoseUCC            NVARCHAR( 1),
   @cLoseID             NVARCHAR( 1),
   @cOption             NVARCHAR( 1),
   @cBarcode            NVARCHAR( 60),
   @cChkFacility        NVARCHAR( 5),

   @tExtInfoVar         VariableTable,
   @tExtValidVar        VariableTable,
   @tExtUpdateVar       VariableTable,
   @tConfirm            VariableTable,
   @tExtGetTask         VariableTable

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nMenu               INT,
   @nInputKey           NVARCHAR( 3),

   @cFacility           NVARCHAR( 5),
   @cStorerKey          NVARCHAR( 15),
   @cLabelPrinter       NVARCHAR( 10),
   @cPaperPrinter       NVARCHAR( 10),

   @cSKU                NVARCHAR( 20),
   @cSKUDescr           NVARCHAR( 60),
   @cFromLOC            NVARCHAR( 10),
   @cFromID             NVARCHAR( 18),
   @cUCC                NVARCHAR( 20),
   @cPUOM               NVARCHAR( 1), -- Pref UOM
   @nPQTY               INT,          -- QTY to move, in pref UOM
   @nMQTY               INT,          -- QTY to move, in master UOM
   @nPUOM_Div           INT,

   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cLottable06         NVARCHAR( 30),
   @cLottable07         NVARCHAR( 30),
   @cLottable08         NVARCHAR( 30),
   @cLottable09         NVARCHAR( 30),
   @cLottable10         NVARCHAR( 30),
   @cLottable11         NVARCHAR( 30),
   @cLottable12         NVARCHAR( 30),
   @dLottable13         DATETIME,
   @dLottable14         DATETIME,
   @dLottable15         DATETIME,

   @nQTY_Avail          INT,         -- QTY avail in master UOM
   @nPQTY_Avail         INT,         -- QTY avail in pref UOM
   @nMQTY_Avail         INT,         -- Remaining QTY in master UOM
   @nQTY                INT,         -- QTY to move, in master UOM
   @nMultiStorer        INT,
   @bBuiltUCC           INT,
   @nTotalRec           INT,
   @nCurrentRec         INT,
   @nPackQtyIndicator   INT,
   @nCaseCNT            INT,

   @cToLOC              NVARCHAR( 10),
   @cToID               NVARCHAR( 18),
   @cLottableCode       NVARCHAR( 30),
   @cPUOM_Desc          NCHAR( 5),    -- Pref UOM desc
   @cMUOM_Desc          NCHAR( 5),    -- Master UOM desc
   @cSKU_StorerKey      NVARCHAR( 15),
   @cPrePackIndicator   NVARCHAR( 20),

   @cExtendedUpdateSP      NVARCHAR( 20),
   @cExtendedValidateSP    NVARCHAR( 20),
   @cExtendedInfoSP        NVARCHAR( 20),
   @cExtendedInfo          NVARCHAR( 20),
   @cDefaultFromLOC        NVARCHAR( 10),
   @cDefaultToLOC          NVARCHAR( 10),
   @cDefaultOption         NVARCHAR( 1),
   @cDefaultQTY            NVARCHAR( 5),
   @cDisableQTYField       NVARCHAR( 1),
   @cMultiSKUBarcode       NVARCHAR( 1),
   @cUCCWithMultiSKU       NVARCHAR( 1),
   @cUCCWithDynamicCaseCNT NVARCHAR( 1),
   @cDecodeSP              NVARCHAR( 20),
   @cDecodeUCCNoSP         NVARCHAR( 20),
   @cAutoGenID             NVARCHAR( 20),
   @cAutoGenUCC            NVARCHAR( 20),
   @cMassBuildUCC          NVARCHAR( 1),
   @cClosePallet           NVARCHAR( 1),
   @cUCCLabel              NVARCHAR( 20),
   @cCustomCaseCNTSP       NVARCHAR( 20),

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

-- Getting Mobile information
SELECT
   @nFunc             = Func,
   @nScn              = Scn,
   @nStep             = Step,
   @nInputKey         = InputKey,
   @cLangCode         = Lang_code,
   @nMenu             = Menu,

   @cFacility         = Facility,
   @cStorerKey        = StorerKey,
   @cLabelPrinter     = Printer,
   @cPaperPrinter     = Printer_Paper,

   @cSKU              = V_SKU,
   @cSKUDescr         = V_SKUDescr,
   @cFromLOC          = V_LOC,
   @cFromID           = V_ID,
   @cUCC              = V_UCC,
   @cPUOM             = V_UOM,
   @nPQTY             = V_PQTY,
   @nMQTY             = V_MQTY,
   @nPUOM_Div         = V_PUOM_Div,

   @cLottable01       = V_Lottable01,
   @cLottable02       = V_Lottable02,
   @cLottable03       = V_Lottable03,
   @dLottable04       = V_Lottable04,
   @dLottable05       = V_Lottable05,
   @cLottable06       = V_Lottable06,
   @cLottable07       = V_Lottable07,
   @cLottable08       = V_Lottable08,
   @cLottable09       = V_Lottable09,
   @cLottable10       = V_Lottable10,
   @cLottable11       = V_Lottable11,
   @cLottable12       = V_Lottable12,
   @dLottable13       = V_Lottable13,
   @dLottable14       = V_Lottable14,
   @dLottable15       = V_Lottable15,

   @nQTY_Avail        = V_Integer1,
   @nPQTY_Avail       = V_Integer2,
   @nMQTY_Avail       = V_Integer3,
   @nQTY              = V_Integer4,
   @nMultiStorer      = V_Integer5,
   @bBuiltUCC         = V_Integer6,
   @nTotalRec         = V_Integer7,
   @nCurrentRec       = V_Integer8,
   @nPackQtyIndicator = V_Integer9,
   @nCaseCNT          = V_Integer10,

   @cToLOC            = V_String1,
   @cToID             = V_String2,
   @cLottableCode     = V_String3,
   @cPUOM_Desc        = V_String4,
   @cMUOM_Desc        = V_String5,
   @cSKU_StorerKey    = V_String6,
   @cPrePackIndicator = V_String7,

   @cExtendedValidateSP    = V_String20,
   @cExtendedUpdateSP      = V_String21,
   @cExtendedInfoSP        = V_String22,
   @cExtendedInfo          = V_String23,
   @cDefaultFromLOC        = V_String24,
   @cDefaultToLOC          = V_String25,
   @cDefaultOption         = V_String26,
   @cDefaultQTY            = V_String27,
   @cDisableQTYField       = V_String28,
   @cMultiSKUBarcode       = V_String29,
   @cUCCWithMultiSKU       = V_String30,
   @cUCCWithDynamicCaseCNT = V_String31,
   @cDecodeSP              = V_String32,
   @cDecodeUCCNoSP         = V_String33,
   @cAutoGenID             = V_String34,
   @cAutoGenUCC            = V_String35,
   @cMassBuildUCC          = V_String36,
   @cClosePallet           = V_String37,
   @cUCCLabel              = V_String38,
   @cCustomCaseCNTSP       = V_String39, 

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
   @nStep_TOLOC            INT,  @nScn_TOLOC          INT,
   @nStep_TOID             INT,  @nScn_TOID           INT,
   @nStep_FROMLOC          INT,  @nScn_FROMLOC        INT,
   @nStep_FROMID           INT,  @nScn_FROMID         INT,
   @nStep_SKU              INT,  @nScn_SKU            INT,
   @nStep_QTY              INT,  @nScn_QTY            INT,
   @nStep_TOUCC            INT,  @nScn_TOUCC          INT,
   @nStep_CLOSEPALLET      INT,  @nScn_CLOSEPALLET    INT,
   @nStep_MultiSKU         INT,  @nScn_MultiSKU       INT

SELECT
   @nStep_TOLOC         = 1,    @nScn_TOLOC        = 5670,
   @nStep_TOID          = 2,    @nScn_TOID         = 5671,
   @nStep_FROMLOC       = 3,    @nScn_FROMLOC      = 5672,
   @nStep_FROMID        = 4,    @nScn_FROMID       = 5673,
   @nStep_SKU           = 5,    @nScn_SKU          = 5674,
   @nStep_QTY           = 6,    @nScn_QTY          = 5675,
   @nStep_TOUCC         = 7,    @nScn_TOUCC        = 5676,
   @nStep_CLOSEPALLET   = 8,    @nScn_CLOSEPALLET  = 5677,
   @nStep_MultiSKU      = 9,    @nScn_MultiSKU     = 3570

-- Redirect to respective screen
IF @nFunc = 639
BEGIN
   IF @nStep = 0 GOTO Step_Start       -- Menu. Func = 639
   IF @nStep = 1 GOTO Step_TOLOC       -- Scn = 5670  Scan TO LOC screen
   IF @nStep = 2 GOTO Step_TOID        -- Scn = 5671  Scan TO ID screen
   IF @nStep = 3 GOTO Step_FROMLOC     -- Scn = 5672  Scan FROM LOC screen
   IF @nStep = 4 GOTO Step_FROMID      -- Scn = 5673  Scan FROM ID screen
   IF @nStep = 5 GOTO Step_SKU         -- Scn = 5674  Scan SKU screen
   IF @nStep = 6 GOTO Step_QTY         -- Scn = 5675  Enter QTY MOVE screen
   IF @nStep = 7 GOTO Step_TOUCC       -- Scn = 5676  Scan TO UCC screen
   IF @nStep = 8 GOTO Step_CLOSEPALLET -- Scn = 5677  Close Pallet screen
   IF @nStep = 9 GOTO Step_MULTISKU    -- Scn = 3570  Multi SKU screen
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu (func = 639)
********************************************************************************/
Step_Start:
BEGIN
   -- Get prefer UOM
   SELECT @cPUOM = ISNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1

   SET @cClosePallet = rdt.rdtGetConfig( @nFunc, 'ClosePallet', @cStorerKey)
   SET @cDisableQTYField = rdt.rdtGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)
   SET @cMassBuildUCC = rdt.rdtGetConfig( @nFunc, 'MassBuildUCC', @cStorerKey)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)
   SET @cUCCWithDynamicCaseCNT = rdt.rdtGetConfig( @nFunc, 'UCCWithDynamicCaseCNT', @cStorerKey)
   SET @cUCCWithMultiSKU = rdt.rdtGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)

   SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorerKey)
   IF @cAutoGenID = '0'
      SET @cAutoGenID = ''
   SET @cAutoGenUCC = rdt.RDTGetConfig( @nFunc, 'AutoGenUCC', @cStorerKey)
   IF @cAutoGenUCC = '0'
      SET @cAutoGenUCC = ''
   SET @cCustomCaseCNTSP = rdt.RDTGetConfig( @nFunc, 'CustomCaseCNTSP', @cStorerKey)
   IF @cCustomCaseCNTSP = '0'
      SET @cCustomCaseCNTSP = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cDecodeUCCNoSP = rdt.RDTGetConfig( @nFunc, 'DecodeUCCNoSP', @cStorerKey)
   IF @cDecodeUCCNoSP = '0'
      SET @cDecodeUCCNoSP = ''
   SET @cDefaultFromLOC = rdt.RDTGetConfig( @nFunc, 'DefaultFromLoc', @cStorerKey)
   IF @cDefaultFromLOC = '0'
      SET @cDefaultFromLOC = ''
   SET @cDefaultOption = rdt.rdtGetConfig( @nFunc, 'DefaultOption', @cStorerKey)
   IF @cDefaultOption = '0'
      SET @cDefaultOption = ''
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)
   IF @cDefaultQTY = '0'
      SET @cDefaultQTY = ''
   SET @cDefaultToLOC = rdt.RDTGetConfig( @nFunc, 'DefaultToLoc', @cStorerKey)
   IF @cDefaultToLOC = '0'
      SET @cDefaultToLOC = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cUCCLabel = rdt.rdtGetConfig( @nFunc, 'UCCLabel', @cStorerKey)
   IF @cUCCLabel = '0'
      SET @cUCCLabel = ''

   IF @cDisableQTYField = '1' AND @cDefaultQTY = ''
      SET @cDefaultQTY = '1'

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey

   -- init variable
   SET @bBuiltUCC = 0

   -- Prep next screen var
   SET @cOutField01 = @cDefaultToLOC

   -- Set the entry point
   SET @nScn  = @nScn_TOLOC
   SET @nStep = @nStep_TOLOC
END
GOTO Quit

/********************************************************************************
Step 1. screen = 5670
   TO LOC (field01, input)
********************************************************************************/
Step_TOLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLoc = @cInField01

      -- Check TOLOC
      IF ISNULL(@cToLoc, '') = ''
      BEGIN
         SET @nErrNo = 148351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TOLOC
         GOTO Step_TOLOC_Fail
      END

      -- Get TOLOC info
      SELECT
         @cChkFacility = Facility,
         @cLoseUCC = LoseUCC, 
         @cLoseID = LoseID
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLoc

      -- Validate TOLOC
      IF ISNULL(@cChkFacility, '') = ''
      BEGIN
         SET @nErrNo = 148352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid TOLOC
         GOTO Step_TOLOC_Fail
      END

      -- Validate TOLOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 148353
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Facility
         GOTO Step_TOLOC_Fail
      END

      IF @cLoseUCC = '1'
      BEGIN
         SET @nErrNo = 148354
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOLOC LoseUCC
         GOTO Step_TOLOC_Fail
      END

      IF @cLoseID = '1'
      BEGIN
         SET @cToID = ''
         
         -- Prep next screen var
         SET @cOutField01 = @cToLoc
         SET @cOutField02 = @cToID
         SET @cOutField03 = @cDefaultFromLOC

         SET @nScn = @nScn_FROMLOC
         SET @nStep = @nStep_FROMLOC
      END
      ELSE
      BEGIN
         IF @cAutoGenID <> ''
         BEGIN
            DECLARE @cAutoID NVARCHAR(18)
            EXEC rdt.rdt_MoveToUCC_AutoGenID @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility
               ,@cAutoGenID
               ,@cFromLOC
               ,@cFromID
               ,@cSKU
               ,@nQTY
               ,@cUCC
               ,@cToID
               ,@cToLOC
               ,@cOption
               ,@cAutoID  OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
            IF @nErrNo <> 0
               GOTO Step_TOLOC_Fail

            SET @cToID = @cAutoID
         END
         ELSE
            SET @cToID = ''

         -- Prep next screen var
         SET @cOutField01 = @cToLoc
         SET @cOutField02 = @cToID

         -- Go to next screen
         SET @nScn = @nScn_TOID
         SET @nStep = @nStep_TOID
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cToLoc = ''
   END
   GOTO Quit

   Step_TOLOC_Fail:
   BEGIN
      SET @cToLoc = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 5671
   TO LOC (field01)
   TO ID  (field02, input)
********************************************************************************/
Step_TOID:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField02

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ToID', @cToID) = 0
      BEGIN
         SET @nErrNo = 148355
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_2_Fail
      END

      -- Prep next screen var
      SET @cOutField01 = @cToLoc
      SET @cOutField02 = @cToID
      SET @cOutField03 = @cDefaultFromLOC

      SET @nScn = @nScn_FROMLOC
      SET @nStep = @nStep_FROMLOC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cToLoc = ''
      SET @cOutField01 = ''

      -- Go to prev screen
      SET @nScn = @nScn_TOLOC
      SET @nStep = @nStep_TOLOC
   END
   GOTO Quit

   Step_2_Fail:
   SET @cOutField01 = ''
END
GOTO Quit

/********************************************************************************
Step 3. screen = 5672
   TO LOC   (field01)
   TO ID    (field02)
   FROM LOC (field03, input)
********************************************************************************/
Step_FROMLOC:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromLoc = @cInField03

      -- Check FROMLOC
      IF ISNULL(@cFromLoc, '') = ''
      BEGIN
         SET @nErrNo = 148356
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need FROMLOC
         GOTO Step_FROMLOC_Fail
      END

      -- Get FROMLOC info
      SELECT
         @cChkFacility = Facility,
         @cLoseUCC = LoseUCC, 
         @cLoseID = LoseID
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLoc

      -- Validate FROMLOC
      IF ISNULL(@cChkFacility, '') = ''
      BEGIN
         SET @nErrNo = 148357
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidFROMLOC
         GOTO Step_FROMLOC_Fail
      END

      -- Validate FROMLOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 148358
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Facility
         GOTO Step_FROMLOC_Fail
      END

      IF @cLoseUCC = '0'
      BEGIN
         SET @nErrNo = 148359
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NOT LOSEUCC
         GOTO Step_FROMLOC_Fail
      END

      -- Validate FromLOC same as ToLOC
      IF @cFromLOC = @cToLOC
      BEGIN
         SET @nErrNo = 148360
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Same FromToLOC
         GOTO Step_FROMLOC_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR(3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR(15), ' +
               '@cFacility       NVARCHAR(5), '  +
               '@cToLOC          NVARCHAR(10), ' +
               '@cToID           NVARCHAR(18), ' +
               '@cFromLOC        NVARCHAR(10), ' +
               '@cFromID         NVARCHAR(18), ' +
               '@cSKU            NVARCHAR(20), ' +
               '@nQTY            INT, ' +
               '@cUCC            NVARCHAR(20), ' +
               '@cLottable01     NVARCHAR(18), ' +
               '@cLottable02     NVARCHAR(18), ' +
               '@cLottable03     NVARCHAR(18), ' +
               '@dLottable04     DATETIME,     ' +
               '@dLottable05     DATETIME,     ' +
               '@cLottable06     NVARCHAR(18), ' +
               '@cLottable07     NVARCHAR(18), ' +
               '@cLottable08     NVARCHAR(18), ' +
               '@cLottable09     NVARCHAR(18), ' +
               '@cLottable10     NVARCHAR(18), ' +
               '@cLottable11     NVARCHAR(18), ' +
               '@cLottable12     NVARCHAR(18), ' +
               '@dLottable13     DATETIME,     ' +
               '@dLottable14     DATETIME,     ' +
               '@dLottable15     DATETIME,     ' +
               '@tExtValidVar    VARIABLETABLE READONLY, ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR(20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @cLoseID = '1'
      BEGIN
         SET @cFromID = ''
         
         -- Prep next screen var
         SET @cOutField01 = @cFromLoc
         SET @cOutField02 = @cFromID
         SET @cOutField03 = ''

         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cToLOC
         SET @cOutField02 = @cToID
         SET @cOutField03 = @cFromLoc
         SET @cOutField04 = '' --@cFromID

         SET @nScn = @nScn_FROMID
         SET @nStep = @nStep_FROMID
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cClosePallet = '1' AND @bBuiltUCC = 1
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cDefaultOption

         -- Go to prev screen
         SET @nScn = @nScn_CLOSEPALLET
         SET @nStep = @nStep_CLOSEPALLET
      END
      ELSE
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLOC AND LoseID = '1')
         BEGIN
            -- Prep next screen var
            SET @cToLoc = ''
            SET @cOutField01 = ''

            -- Go to prev screen
            SET @nScn = @nScn_TOLOC
            SET @nStep = @nStep_TOLOC
         END
         ELSE
         BEGIN
            -- Prep next screen var
            SET @cToID = ''
            SET @cOutField01 = @cToLoc
            SET @cOutField02 = ''

            -- Go to prev screen
            SET @nScn = @nScn_TOID
            SET @nStep = @nStep_TOID
         END
      END
   END
   GOTO Quit

   Step_FROMLOC_Fail:
   BEGIN
      SET @cFromLoc  = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 5673
   TO LOC   (field01)
   TO ID    (field02)
   FROM LOC (field03)
   FROM ID  (field04, input)
********************************************************************************/
Step_FROMID:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField04

      -- Validate ID
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN StorerKey ELSE @cStorerKey END
            AND LOC = @cFromLOC
            AND ID = @cFromID
            AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0)
      BEGIN
         SET @nErrNo = 148361
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid FROMID
         GOTO Step_FROMID_Fail
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cFromID
      SET @cOutField03 = ''

      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cFromLoc = ''
      SET @cOutField01 = @cToLoc
      SET @cOutField02 = @cToID
      SET @cOutField03 = ''

      SET @nScn = @nScn_FROMLOC
      SET @nStep = @nStep_FROMLOC
   END
   GOTO Quit

   Step_FROMID_Fail:
   BEGIN
      SET @cFromID  = ''
      SET @cOutField04 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 5. screen = 5674
   FROM LOC (field01)
   FROM ID  (field02)
   SKU/UPC  (field03, input)
********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField03
      SET @cBarcode = @cInField03

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @nErrNo = 148362
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU/UPC
         GOTO Step_SKU_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUPC        = @cSKU         OUTPUT,
               @nQTY        = @nQTY         OUTPUT,
               @cLottable01 = @cLottable01  OUTPUT,
               @cLottable02 = @cLottable02  OUTPUT,
               @cLottable03 = @cLottable03  OUTPUT,
               @dLottable04 = @dLottable04  OUTPUT,
               @dLottable05 = @dLottable05  OUTPUT,
               @cLottable06 = @cLottable06  OUTPUT,
               @cLottable07 = @cLottable07  OUTPUT,
               @cLottable08 = @cLottable08  OUTPUT,
               @cLottable09 = @cLottable09  OUTPUT,
               @cLottable10 = @cLottable10  OUTPUT,
               @cLottable11 = @cLottable11  OUTPUT,
               @cLottable12 = @cLottable12  OUTPUT,
               @dLottable13 = @dLottable13  OUTPUT,
               @dLottable14 = @dLottable14  OUTPUT,
               @dLottable15 = @dLottable15  OUTPUT,
               @nErrNo      = @nErrNo       OUTPUT,
               @cErrMsg     = @cErrMsg      OUTPUT,
               @cType       = 'UPC'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, ' +
               ' @cToLOC      OUTPUT, @cToID       OUTPUT, @cFromLOC    OUTPUT, @cFromID     OUTPUT, ' +
               ' @cSKU        OUTPUT, @nQTY        OUTPUT, @cUCC        OUTPUT, ' +
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,             ' +
               ' @nFunc        INT,             ' +
               ' @cLangCode    NVARCHAR( 3),    ' +
               ' @nStep        INT,             ' +
               ' @nInputKey    INT,             ' +
               ' @cStorerKey   NVARCHAR( 15),   ' +
               ' @cFacility    NVARCHAR( 5),    ' +
               ' @cBarcode     NVARCHAR( 2000), ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cToID        NVARCHAR( 18)  OUTPUT, ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
               ' @cUCC         NVARCHAR( 20)  OUTPUT, ' +
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04  DATETIME       OUTPUT, ' +
               ' @dLottable05  DATETIME       OUTPUT, ' +
               ' @cLottable06  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12  NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13  DATETIME       OUTPUT, ' +
               ' @dLottable14  DATETIME       OUTPUT, ' +
               ' @dLottable15  DATETIME       OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cToLOC      OUTPUT, @cToID       OUTPUT, @cFromLoc    OUTPUT, @cFromID     OUTPUT,
               @cSKU        OUTPUT, @nQTY        OUTPUT, @cUCC        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_SKU_Fail

         IF @nMultiStorer = 1
            SET @cSKU_StorerKey = @cSKU
      END

      IF @nMultiStorer = '1'
         GOTO Skip_ValidateSKU

      -- Get SKU count
      DECLARE @nSKUCnt INT
      EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt   OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 148363
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_SKU_Fail
      END

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
               @cSku     OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT,
               'LotXLocXID.Loc',    -- DocType
               @cFromLoc

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
            SET @nErrNo = 148364
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Step_SKU_Fail
         END
      END

      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU      OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR(3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR(15), ' +
               '@cFacility       NVARCHAR(5), '  +
               '@cToLOC          NVARCHAR(10), ' +
               '@cToID           NVARCHAR(18), ' +
               '@cFromLOC        NVARCHAR(10), ' +
               '@cFromID         NVARCHAR(18), ' +
               '@cSKU            NVARCHAR(20), ' +
               '@nQTY            INT, ' +
               '@cUCC            NVARCHAR(20), ' +
               '@cLottable01     NVARCHAR(18), ' +
               '@cLottable02     NVARCHAR(18), ' +
               '@cLottable03     NVARCHAR(18), ' +
               '@dLottable04     DATETIME,     ' +
               '@dLottable05     DATETIME,     ' +
               '@cLottable06     NVARCHAR(18), ' +
               '@cLottable07     NVARCHAR(18), ' +
               '@cLottable08     NVARCHAR(18), ' +
               '@cLottable09     NVARCHAR(18), ' +
               '@cLottable10     NVARCHAR(18), ' +
               '@cLottable11     NVARCHAR(18), ' +
               '@cLottable12     NVARCHAR(18), ' +
               '@dLottable13     DATETIME,     ' +
               '@dLottable14     DATETIME,     ' +
               '@dLottable15     DATETIME,     ' +
               '@tExtValidVar    VARIABLETABLE READONLY, ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR(20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      Skip_ValidateSKU:
      SELECT @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,
             @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',
             @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL

      -- Get task
      SET @nErrNo = 0
      EXEC rdt.rdt_MoveToUCC_GetTask_V7
         @nMobile         = @nMobile,
         @nFunc           = @nFunc,
         @cLangCode       = @cLangCode,
         @nStep           = @nStep,
         @nInputKey       = @nInputKey,
         @cStorerKey      = @cStorerKey,
         @cFacility       = @cFacility,
         @cType           = '',
         @cToLOC          = @cToLOC,
         @cToID           = @cToID,
         @cFromLOC        = @cFromLOC,
         @cFromID         = @cFromID,
         @cUCC            = @cUCC,
         @cSKU            = @cSKU,
         @nQTY            = @nQTY_Avail      OUTPUT,
         @nTotalRec       = @nTotalRec       OUTPUT,
         @cLottableCode   = @cLottableCode   OUTPUT,
         @cLottable01     = @cLottable01     OUTPUT,
         @cLottable02     = @cLottable02     OUTPUT,
         @cLottable03     = @cLottable03     OUTPUT,
         @dLottable04     = @dLottable04     OUTPUT,
         @dLottable05     = @dLottable05     OUTPUT,
         @cLottable06     = @cLottable06     OUTPUT,
         @cLottable07     = @cLottable07     OUTPUT,
         @cLottable08     = @cLottable08     OUTPUT,
         @cLottable09     = @cLottable09     OUTPUT,
         @cLottable10     = @cLottable10     OUTPUT,
         @cLottable11     = @cLottable11     OUTPUT,
         @cLottable12     = @cLottable12     OUTPUT,
         @dLottable13     = @dLottable13     OUTPUT,
         @dLottable14     = @dLottable14     OUTPUT,
         @dLottable15     = @dLottable15     OUTPUT,
         @tExtGetTask     = @tExtGetTask,
         @nErrNo          = @nErrNo          OUTPUT,
         @cErrMsg         = @cErrMsg         OUTPUT

      IF @nErrNo <> 0
        GOTO Step_SKU_Fail

      IF @nTotalRec = 0
      BEGIN
         SET @nErrNo = 148365
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No QTY To Move
         GOTO Step_SKU_Fail
      END

      /*
      -- Validate not QTY
      IF @nQTY_Avail = 0
      BEGIN
         SET @nErrNo = 148366
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO QTY TO MOVE
         GOTO Step_SKU_Fail
      END
      */

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 6,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      -- Get SKU info
      SELECT
         @cSKUDescr = S.DescR,
         @cPrePackIndicator = LEFT( PrePackIndicator, 20),
         @nPackQtyIndicator = ISNULL( PackQtyIndicator, 0),
         @nCaseCNT = Pack.CaseCNT,
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
            END AS INT)
      FROM dbo.SKU S (NOLOCK)
         JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
         AND SKU = @cSKU

      -- Custom CaseCNT
      IF @cCustomCaseCNTSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCustomCaseCNTSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCustomCaseCNTSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nCaseCNT OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR(3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR(15), ' +
               '@cFacility       NVARCHAR(5), '  +
               '@cToLOC          NVARCHAR(10), ' +
               '@cToID           NVARCHAR(18), ' +
               '@cFromLOC        NVARCHAR(10), ' +
               '@cFromID         NVARCHAR(18), ' +
               '@cSKU            NVARCHAR(20), ' +
               '@nQTY            INT, ' +
               '@cUCC            NVARCHAR(20), ' +
               '@cLottable01     NVARCHAR(18), ' +
               '@cLottable02     NVARCHAR(18), ' +
               '@cLottable03     NVARCHAR(18), ' +
               '@dLottable04     DATETIME,     ' +
               '@dLottable05     DATETIME,     ' +
               '@cLottable06     NVARCHAR(18), ' +
               '@cLottable07     NVARCHAR(18), ' +
               '@cLottable08     NVARCHAR(18), ' +
               '@cLottable09     NVARCHAR(18), ' +
               '@cLottable10     NVARCHAR(18), ' +
               '@cLottable11     NVARCHAR(18), ' +
               '@cLottable12     NVARCHAR(18), ' +
               '@dLottable13     DATETIME,     ' +
               '@dLottable14     DATETIME,     ' +
               '@dLottable15     DATETIME,     ' +
               '@nCaseCNT        INT          OUTPUT, ' +
               '@nErrNo          INT          OUTPUT, ' +
               '@cErrMsg         NVARCHAR(20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nCaseCNT OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Avail = 0
         SET @nMQTY_Avail = @nQTY_Avail
         SET @cFieldAttr13 = 'O' -- PQTY
      END
      ELSE
      BEGIN
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY = 0
         SET @cFieldAttr13 = '' -- PQTY
      END

      -- Disable QTY field
      IF @cDisableQTYField = '1'
      BEGIN
         SET @cFieldAttr13 = 'O' -- PQTY
         SET @cFieldAttr14 = 'O' -- MQTY
      END

      SET @nCurrentRec = 1
      SET @nQTY = 0

      -- Prep next screen var
      SET @cOutField01 = CAST ( @nCurrentRec AS NVARCHAR(2) ) + '/' + CAST ( @nTotalRec AS NVARCHAR(4) )
      SET @cOutField02 = ''
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING(@cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING(@cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField10 = CAST(@nPUOM_DIV AS NCHAR(6))  + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
      SET @cOutField11 = CASE WHEN @nPQTY_Avail = 0 THEN '' ELSE CAST( @nPQTY_Avail AS NVARCHAR( 5)) END
      SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField13 = '' -- PQTY
      SET @cOutField14 = CASE WHEN @cDisableQTYField = '1' THEN '' ELSE @cDefaultQTY END -- MQTY
      SET @cOutField15 = '' -- ExtendedInfo

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU

      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFromLOC AND LoseID = '1')
      BEGIN
         -- Prep next screen var
         SET @cFromLoc = ''
         SET @cOutField01 = @cToLoc
         SET @cOutField02 = @cToID
         SET @cOutField03 = ''

         SET @nScn = @nScn_FROMLOC
         SET @nStep = @nStep_FROMLOC
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cToLOC
         SET @cOutField02 = @cToID
         SET @cOutField03 = @cFromLoc
         SET @cOutField04 = '' --FromID

         SET @nScn = @nScn_FROMID
         SET @nStep = @nStep_FROMID
      END
   END

   Step_SKU_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
           SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               ' @nMobile         INT, ' +
               ' @nFunc           INT, ' +
               ' @cLangCode       NVARCHAR(3), ' +
               ' @nStep           INT, ' +
               ' @nAfterStep      INT, ' +
               ' @nInputKey       INT, ' +
               ' @cStorerKey      NVARCHAR(15), ' +
               ' @cFacility       NVARCHAR(5), '  +
               ' @cToLOC          NVARCHAR(10), ' +
               ' @cToID           NVARCHAR(18), ' +
               ' @cFromLOC        NVARCHAR(10), ' +
               ' @cFromID         NVARCHAR(18), ' +
               ' @cSKU            NVARCHAR(20), ' +
               ' @nQTY            INT, ' +
               ' @cUCC            NVARCHAR(20), ' +
               ' @cLottable01     NVARCHAR(18), ' +
               ' @cLottable02     NVARCHAR(18), ' +
               ' @cLottable03     NVARCHAR(18), ' +
               ' @dLottable04     DATETIME,     ' +
               ' @dLottable05     DATETIME,     ' +
               ' @cLottable06     NVARCHAR(18), ' +
               ' @cLottable07     NVARCHAR(18), ' +
               ' @cLottable08     NVARCHAR(18), ' +
               ' @cLottable09     NVARCHAR(18), ' +
               ' @cLottable10     NVARCHAR(18), ' +
               ' @cLottable11     NVARCHAR(18), ' +
               ' @cLottable12     NVARCHAR(18), ' +
               ' @dLottable13     DATETIME,     ' +
               ' @dLottable14     DATETIME,     ' +
               ' @dLottable15     DATETIME,     ' +
               ' @tExtInfoVar     VariableTable READONLY, ' +
               ' @cExtendedInfo   NVARCHAR( 20) OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_SKU, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
      GOTO Quit
   END

   Step_SKU_Fail:
   BEGIN
      SET @cSKU  = ''
      SET @cInField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 6. screen = 5675
   COUNTER  (field01)
   SKU/UPC  (field02, input)
   SKU      (field03)
   DESC1    (field04)
   DESC2    (field05)
   LOTTABLE (field06)
   LOTTABLE (field07)
   LOTTABLE (field08)
   LOTTABLE (field09)
   UOMRatio, PUOMDesc, MUOMDesc (field10)
   QTY AVL: (field11, field12)
   QTY MV:  (field13, field14, input)
   EXTINFO  (field15)
********************************************************************************/
Step_QTY:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      DECLARE @c_SKU    NVARCHAR(20)
      DECLARE @c_PQTY   NVARCHAR(5)
      DECLARE @c_MQTY   NVARCHAR(5)

      -- Screen mapping
      SET @c_SKU  = @cInField02
      SET @c_PQTY = CASE WHEN @cFieldAttr13 = 'O' THEN @cOutField13 ELSE @cInField13 END
      SET @c_MQTY = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE @cInField14 END

      -- Loop lottables
      IF @c_PQTY = '' AND @c_MQTY = '' AND @c_SKU = ''
      BEGIN
         -- Get task
         SET @nErrNo = 0
         EXEC rdt.rdt_MoveToUCC_GetTask_V7
            @nMobile         = @nMobile,
            @nFunc           = @nFunc,
            @cLangCode       = @cLangCode,
            @nStep           = @nStep,
            @nInputKey       = @nInputKey,
            @cStorerKey      = @cStorerKey,
            @cFacility       = @cFacility,
            @cType           = 'NEXT',
            @cToLOC          = @cToLOC,
            @cToID           = @cToID,
            @cFromLOC        = @cFromLOC,
            @cFromID         = @cFromID,
            @cUCC            = @cUCC,
            @cSKU            = @cSKU,
            @nQTY            = @nQTY_Avail      OUTPUT,
            @nTotalRec       = @nTotalRec       OUTPUT,
            @cLottableCode   = @cLottableCode   OUTPUT,
            @cLottable01     = @cLottable01     OUTPUT,
            @cLottable02     = @cLottable02     OUTPUT,
            @cLottable03     = @cLottable03     OUTPUT,
            @dLottable04     = @dLottable04     OUTPUT,
            @dLottable05     = @dLottable05     OUTPUT,
            @cLottable06     = @cLottable06     OUTPUT,
            @cLottable07     = @cLottable07     OUTPUT,
            @cLottable08     = @cLottable08     OUTPUT,
            @cLottable09     = @cLottable09     OUTPUT,
            @cLottable10     = @cLottable10     OUTPUT,
            @cLottable11     = @cLottable11     OUTPUT,
            @cLottable12     = @cLottable12     OUTPUT,
            @dLottable13     = @dLottable13     OUTPUT,
            @dLottable14     = @dLottable14     OUTPUT,
            @dLottable15     = @dLottable15     OUTPUT,
            @tExtGetTask     = @tExtGetTask,
            @nErrNo          = @nErrNo          OUTPUT,
            @cErrMsg         = @cErrMsg         OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Validate not QTY
         IF @nQTY_Avail = 0
         BEGIN
            SET @nErrNo = 148367
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO MORE REC
            GOTO Quit
         END

         SET @nCurrentRec = @nCurrentRec + 1
         IF @nCurrentRec > @nTotalRec
            SET @nCurrentRec = 1

         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 6,
            @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
            @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
            @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
            @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
            @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
            @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
            @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
            @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
            @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
            @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
            @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
            @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
            @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
            @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
            @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
            @nMorePage   OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT,
            '',      -- SourceKey
            @nFunc   -- SourceType

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
            SET @nPQTY = 0
         END

         -- Prep next screen var
         SET @cOutField01 = CAST ( @nCurrentRec AS NVARCHAR(2) ) + '/' + CAST ( @nTotalRec AS NVARCHAR(4) )
         SET @cOutField02 = ''
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING(@cSKUDescr, 1, 20)   -- SKU desc 1
         SET @cOutField05 = SUBSTRING(@cSKUDescr, 21, 20)  -- SKU desc 2
         SET @cOutField10 = CAST(@nPUOM_DIV AS NCHAR(6))  + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
         SET @cOutField11 = CASE WHEN @nPQTY_Avail = 0 THEN '' ELSE CAST( @nPQTY_Avail AS NVARCHAR( 5)) END
         SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
         SET @cOutField13 = '' -- PQTY
         SET @cOutField14 = CASE WHEN @cDisableQTYField = '1' THEN '' ELSE @cDefaultQTY END -- @nMQTY
         SET @cOutField15 = '' -- ExtendedInfo

         EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU

         GOTO Step_QTY_Quit
      END

      -- Validate SKU
      IF @c_SKU <> ''
      BEGIN
         EXEC [RDT].[rdt_GETSKU]
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @c_SKU     OUTPUT
            ,@bSuccess    = @bSuccess  OUTPUT
            ,@nErr        = @nErrNo    OUTPUT
            ,@cErrMsg     = @cErrMsg   OUTPUT

         IF @c_SKU <> @cSKU
         BEGIN
            SET @nErrNo = 148368
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not same
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU
            SET @cOutField11 = ''
            GOTO Quit
         END
      END

      -- Validate PQTY
      IF @c_PQTY <> '' AND RDT.rdtIsValidQTY(@c_PQTY, 0) = 0
      BEGIN
         SET @nErrNo = 148369
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Quit
      END
      SET @nPQTY = CAST(@c_PQTY AS INT)

      -- Validate MQTY
      IF @c_MQTY <> '' AND RDT.rdtIsValidQTY(@c_MQTY, 0) = 0
      BEGIN
         SET @nErrNo = 148370
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Quit
      END
      SET @nMQTY = CAST(@c_MQTY AS INT)

      -- Top up QTY
      IF @c_SKU <> '' AND @cDisableQTYField = '1'
      BEGIN
         IF @cPrePackIndicator = '2' AND @nPackQtyIndicator > 1
            SET @nMQTY = @nMQTY + @nPackQtyIndicator
         ELSE
            SET @nMQTY = @nMQTY + 1
      END
      ELSE
      BEGIN
         IF @cInField14 <> @cOutField14 -- MQTY changed
            IF @cPrePackIndicator = '2' AND @nPackQtyIndicator > 1
               SET @nMQTY = @nMQTY * @nPackQtyIndicator -- Recalc MQTY
      END

      -- Calc total QTY in master UOM
      IF @nMultiStorer = 0
         SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @c_PQTY, @cPUOM, 6)
      ELSE
         SET @nQTY = rdt.rdtConvUOMQTY( @cSKU_StorerKey, @cSKU, @c_PQTY, @cPUOM, 6)
      SET @nQTY = @nQTY + @nMQTY

      -- Check QTY enough
      IF @nQTY = 0
      BEGIN
         SET @nErrNo = 148371
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need QTY
         GOTO Quit
      END

      -- Check QTY available enough
      IF @nQTY > @nQTY_Avail
      BEGIN
         SET @nErrNo = 148372
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYAVL NOTENUF
         GOTO Quit
      END

      /*
      3 factors:
      1. standard/non standard case count
      2. over, equal, under case count
      3. scan sku/not scan sku

      Merge 1 & 2:
         standard: cannot over, cannot under, only equal
         non standard: can over, can under, can equal (no control)

      Merge 1 & 2 & 3:
         scan sku:
            standard: cannot over = prompt error, cannot under = remain in current screen, only equal = go to UCC screen
            non standard: can over, can under, can equal. All no check, remain in SKU screen
         not scan sku:
            standard: cannot over = prompt error, cannot under = prompt error, only equal = go to UCC screen
            non standard: can over, can under, can equal. All no check, go to UCC screen
      */

      -- Use standard case count
      IF @cUCCWithDynamicCaseCNT <> '1' AND @nCaseCNT > 0
      BEGIN
         -- QTY more than case count
         IF @nQTY > @nCaseCNT
         BEGIN
            SET @nErrNo = 148373
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over build UCC
            GOTO Quit
         END

         -- QTY less then case count
         IF @nQTY < @nCaseCNT
         BEGIN
            -- SKU scanned
            IF @c_SKU <> ''
            BEGIN
               SET @cOutField02 = '' -- SKU
               SET @cOutField13 = CASE WHEN @cDisableQTYField = '1' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END -- PQTY
               SET @cOutField14 = CAST( @nMQTY AS NVARCHAR( 5)) -- MQTY

               IF @cDisableQTYField = '1'
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU
               ELSE
                  IF @cFieldAttr13 = 'O'
                     EXEC rdt.rdtSetFocusField @nMobile, 14 -- MQTY
                  ELSE
                     EXEC rdt.rdtSetFocusField @nMobile, 13 -- PQTY

               GOTO Step_QTY_Quit
            END
            ELSE
            BEGIN
               SET @nErrNo = 148374
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not full UCC
               GOTO Quit
            END
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR(3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR(15), ' +
               '@cFacility       NVARCHAR(5), '  +
               '@cToLOC          NVARCHAR(10), ' +
               '@cToID           NVARCHAR(18), ' +
               '@cFromLOC        NVARCHAR(10), ' +
               '@cFromID         NVARCHAR(18), ' +
               '@cSKU            NVARCHAR(20), ' +
               '@nQTY            INT, ' +
               '@cUCC            NVARCHAR(20), ' +
               '@cLottable01     NVARCHAR(18), ' +
               '@cLottable02     NVARCHAR(18), ' +
               '@cLottable03     NVARCHAR(18), ' +
               '@dLottable04     DATETIME,     ' +
               '@dLottable05     DATETIME,     ' +
               '@cLottable06     NVARCHAR(18), ' +
               '@cLottable07     NVARCHAR(18), ' +
               '@cLottable08     NVARCHAR(18), ' +
               '@cLottable09     NVARCHAR(18), ' +
               '@cLottable10     NVARCHAR(18), ' +
               '@cLottable11     NVARCHAR(18), ' +
               '@cLottable12     NVARCHAR(18), ' +
               '@dLottable13     DATETIME,     ' +
               '@dLottable14     DATETIME,     ' +
               '@dLottable15     DATETIME,     ' +
               '@tExtValidVar    VARIABLETABLE READONLY, ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR(20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- SKU scanned
      IF @c_SKU <> ''
      BEGIN
         -- Non standard case count
         IF NOT (@cUCCWithDynamicCaseCNT <> '1' AND @nCaseCNT > 0)
         BEGIN
            SET @cOutField02 = '' -- SKU
            SET @cOutField13 = CASE WHEN @cDisableQTYField = '1' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END -- PQTY
            SET @cOutField14 = CAST( @nMQTY AS NVARCHAR( 5)) -- MQTY

            IF @cDisableQTYField = '1'
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU
            ELSE
               IF @cFieldAttr13 = 'O'
                  EXEC rdt.rdtSetFocusField @nMobile, 14 -- MQTY
               ELSE
                  EXEC rdt.rdtSetFocusField @nMobile, 13 -- PQTY

            GOTO Step_QTY_Quit
         END
      END

      -- Auto generate new UCCNo
      IF @cAutoGenUCC <> ''
      BEGIN
         DECLARE @cAutoUCC NVARCHAR( 20)
         EXEC rdt.rdt_MoveToUCC_AutoGenUCC_V7 @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility
            ,@cAutoGenUCC
            ,@cFromLOC
            ,@cFromID
            ,@cSKU
            ,@nQTY
            ,@cUCC
            ,@cToID
            ,@cToLOC
            ,@cOption
            ,@cAutoUCC OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cUCC = @cAutoUCC
      END
      ELSE
         SET @cUCC = ''

      -- Prepare next screen var
      SET @cOutField01 = @cUCC
      SET @cOutField15 = '' --@cExtendedInfo

      SET @cFieldAttr13 = '' -- PQTY
      SET @cFieldAttr14 = '' -- MQTY

      SET @nScn = @nScn_TOUCC
      SET @nStep = @nStep_TOUCC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' -- SKU

      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   Step_QTY_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               ' @nMobile         INT, ' +
               ' @nFunc           INT, ' +
               ' @cLangCode       NVARCHAR(3), ' +
               ' @nStep           INT, ' +
               ' @nAfterStep      INT, ' +
               ' @nInputKey       INT, ' +
               ' @cStorerKey      NVARCHAR(15), ' +
               ' @cFacility       NVARCHAR(5), '  +
               ' @cToLOC          NVARCHAR(10), ' +
               ' @cToID           NVARCHAR(18), ' +
               ' @cFromLOC        NVARCHAR(10), ' +
               ' @cFromID         NVARCHAR(18), ' +
               ' @cSKU            NVARCHAR(20), ' +
               ' @nQTY            INT, ' +
               ' @cUCC            NVARCHAR(20), ' +
               ' @cLottable01     NVARCHAR(18), ' +
               ' @cLottable02     NVARCHAR(18), ' +
               ' @cLottable03     NVARCHAR(18), ' +
               ' @dLottable04     DATETIME,     ' +
               ' @dLottable05     DATETIME,     ' +
               ' @cLottable06     NVARCHAR(18), ' +
               ' @cLottable07     NVARCHAR(18), ' +
               ' @cLottable08     NVARCHAR(18), ' +
               ' @cLottable09     NVARCHAR(18), ' +
               ' @cLottable10     NVARCHAR(18), ' +
               ' @cLottable11     NVARCHAR(18), ' +
               ' @cLottable12     NVARCHAR(18), ' +
               ' @dLottable13     DATETIME,     ' +
               ' @dLottable14     DATETIME,     ' +
               ' @dLottable15     DATETIME,     ' +
               ' @tExtInfoVar     VariableTable READONLY, ' +
               ' @cExtendedInfo   NVARCHAR( 20) OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_QTY, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit

/********************************************************************************
Step 7. screen = 5676
   TO UCC   (field01, input)
   EXTINFO  (field15)
********************************************************************************/
Step_TOUCC:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      -- Screen mapping
      SET @cBarCode = @cInField01
      SET @cUCC = LEFT( @cInField01, 20)

      -- Check blank
      IF @cBarCode = ''
      BEGIN
         IF @cMassBuildUCC = '1'
         BEGIN
            IF @cClosePallet = '1'
            BEGIN
               -- Prep next screen var
               SET @cOutField01 = @cDefaultOption

               SET @nScn = @nScn_CLOSEPALLET
               SET @nStep = @nStep_CLOSEPALLET
            END
            ELSE
            BEGIN
               -- Prep next screen var
               SET @cOutField01 = @cToLoc
               SET @cOutField02 = @cToID
               SET @cOutField03 = ''

               SET @nScn = @nScn_FROMLOC
               SET @nStep = @nStep_FROMLOC
            END
            GOTO Step_TOUCC_Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 148375
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TOUCC
            GOTO Quit
         END
      END

      -- Check format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UCC', @cBarCode) = 0
      BEGIN
         SET @nErrNo = 148376
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_TOUCC_Fail
      END

      -- Standard decode
      IF @cDecodeUCCNoSP <> ''
      BEGIN
         IF @cDecodeUCCNoSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUCCNo  = @cUCC     OUTPUT,
               @nErrNo  = @nErrNo   OUTPUT,
               @cErrMsg = @cErrMsg  OUTPUT,
               @cType   = 'UCC'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeUCCNoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, ' +
               ' @cToLOC      OUTPUT, @cToID       OUTPUT, @cFromLOC    OUTPUT, @cFromID     OUTPUT, ' +
               ' @cSKU        OUTPUT, @nQTY        OUTPUT, @cUCC        OUTPUT, ' +
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,             ' +
               ' @nFunc        INT,             ' +
               ' @cLangCode    NVARCHAR( 3),    ' +
               ' @nStep        INT,             ' +
               ' @nInputKey    INT,             ' +
               ' @cStorerKey   NVARCHAR( 15),   ' +
               ' @cFacility    NVARCHAR( 5),    ' +
               ' @cBarcode     NVARCHAR( 2000), ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cToID        NVARCHAR( 18)  OUTPUT, ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
               ' @cUCC         NVARCHAR( 20)  OUTPUT, ' +
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04  DATETIME       OUTPUT, ' +
               ' @dLottable05  DATETIME       OUTPUT, ' +
               ' @cLottable06  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12  NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13  DATETIME       OUTPUT, ' +
               ' @dLottable14  DATETIME       OUTPUT, ' +
               ' @dLottable15  DATETIME       OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cToLOC      OUTPUT, @cToID       OUTPUT, @cFromLoc    OUTPUT, @cFromID     OUTPUT,
               @cSKU        OUTPUT, @nQTY        OUTPUT, @cUCC        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_TOUCC_Fail
         END
      END

      IF @cUCCWithMultiSKU = '0'
      BEGIN
         IF EXISTS( SELECT 1
            FROM UCC WITH (NOLOCK)
            WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
               AND UCCNo = @cUCC)
         BEGIN
            SET @nErrNo = 148377
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOUCC exists
            GOTO Step_TOUCC_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR(3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR(15), ' +
               '@cFacility       NVARCHAR(5), '  +
               '@cToLOC          NVARCHAR(10), ' +
               '@cToID           NVARCHAR(18), ' +
               '@cFromLOC        NVARCHAR(10), ' +
               '@cFromID         NVARCHAR(18), ' +
               '@cSKU            NVARCHAR(20), ' +
               '@nQTY            INT, ' +
               '@cUCC            NVARCHAR(20), ' +
               '@cLottable01     NVARCHAR(18), ' +
               '@cLottable02     NVARCHAR(18), ' +
               '@cLottable03     NVARCHAR(18), ' +
               '@dLottable04     DATETIME,     ' +
               '@dLottable05     DATETIME,     ' +
               '@cLottable06     NVARCHAR(18), ' +
               '@cLottable07     NVARCHAR(18), ' +
               '@cLottable08     NVARCHAR(18), ' +
               '@cLottable09     NVARCHAR(18), ' +
               '@cLottable10     NVARCHAR(18), ' +
               '@cLottable11     NVARCHAR(18), ' +
               '@cLottable12     NVARCHAR(18), ' +
               '@dLottable13     DATETIME,     ' +
               '@dLottable14     DATETIME,     ' +
               '@dLottable15     DATETIME,     ' +
               '@tExtValidVar    VARIABLETABLE READONLY, ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR(20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_TOUCC_Fail
         END
      END

      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN BuildUCC

      EXEC rdt.rdt_MoveToUCC_Confirm_V7
         @nMobile       = @nMobile,
         @nFunc         = @nFunc,
         @cLangCode     = @cLangCode,
         @nStep         = @nStep,
         @nInputKey     = @nInputKey,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cToLOC        = @cToLOC,
         @cToID         = @cToID,
         @cFromLOC      = @cFromLOC,
         @cFromID       = @cFromID,
         @cUCC          = @cUCC,
         @cSKU          = @cSKU,
         @nQTY          = @nQTY,
         @cLottableCode = @cLottableCode,
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = @dLottable05,
         @cLottable06   = @cLottable06,
         @cLottable07   = @cLottable07,
         @cLottable08   = @cLottable08,
         @cLottable09   = @cLottable09,
         @cLottable10   = @cLottable10,
         @cLottable11   = @cLottable11,
         @cLottable12   = @cLottable12,
         @dLottable13   = @dLottable13,
         @dLottable14   = @dLottable14,
         @dLottable15   = @dLottable15,
         @tConfirm      = @tConfirm,
         @nErrNo        = @nErrNo          OUTPUT,
         @cErrMsg       = @cErrMsg         OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN BuildUCC
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_TOUCC_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR(3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR(15), ' +
               '@cFacility       NVARCHAR(5), ' +
               '@cToLOC          NVARCHAR(10), ' +
               '@cToID           NVARCHAR(18), ' +
               '@cFromLOC        NVARCHAR(10), ' +
               '@cFromID         NVARCHAR(18), ' +
               '@cSKU            NVARCHAR(20), ' +
               '@nQTY            INT, ' +
               '@cUCC            NVARCHAR(20), ' +
               '@cLottable01     NVARCHAR(18), ' +
               '@cLottable02     NVARCHAR(18), ' +
               '@cLottable03     NVARCHAR(18), ' +
               '@dLottable04     DATETIME,     ' +
               '@dLottable05     DATETIME,     ' +
               '@cLottable06     NVARCHAR(18), ' +
               '@cLottable07     NVARCHAR(18), ' +
               '@cLottable08     NVARCHAR(18), ' +
               '@cLottable09     NVARCHAR(18), ' +
               '@cLottable10     NVARCHAR(18), ' +
               '@cLottable11     NVARCHAR(18), ' +
               '@cLottable12     NVARCHAR(18), ' +
               '@dLottable13     DATETIME,     ' +
               '@dLottable14     DATETIME,     ' +
               '@dLottable15     DATETIME,     ' +
               '@tExtUpdateVar   VARIABLETABLE READONLY, ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR(20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN BuildUCC
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_TOUCC_Fail
            END
         END
      END

      IF @cUCCLabel <> ''
      BEGIN
         -- Common params
         DECLARE @tUCCLabel AS VariableTable
         INSERT INTO @tUCCLabel (Variable, Value) VALUES
            ( '@cToLOC',      @cToLOC),
            ( '@cToID',       @cToID),
            ( '@cFromLOC',    @cFromLOC),
            ( '@cFromID',     @cFromID),
            ( '@cStorerKey',  @cStorerKey),
            ( '@cSKU',        @cSKU),
            ( '@nQTY',        CAST( @nQTY AS NVARCHAR( 5))),
            ( '@cUCC',        @cUCC)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
            @cUCCLabel, -- Report type
            @tUCCLabel, -- Report params
            'rdtfnc_MoveToUCC_V7',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN BuildUCC
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Step_TOUCC_Fail
         END
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cLocation     = @cFromLOC,
         @cID           = @cFromID,
         @cToLocation   = @cToLOC,
         @cToID         = @cToID,
         @cSKU          = @cSKU,
         @nQTY          = @nQTY,
         @cUCC          = @cUCC

      IF @cMassBuildUCC = '1'
      BEGIN
         -- Prep current screen var
         SET @cOutField01 = ''
         GOTO Step_TOUCC_Quit
      END
      ELSE IF @cMassBuildUCC = '2'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cFromLoc
         SET @cOutField02 = @cFromID
         SET @cOutField03 = ''

         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
         
         GOTO Step_TOUCC_Quit
      END

      IF @cClosePallet = '1'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cDefaultOption

         SET @nScn = @nScn_CLOSEPALLET
         SET @nStep = @nStep_CLOSEPALLET
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cToLoc
         SET @cOutField02 = @cToID
         SET @cOutField03 = '' -- SKU

         SET @nScn = @nScn_FROMLOC
         SET @nStep = @nStep_FROMLOC
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 6,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
         SET @cFieldAttr13 = 'O' -- PQTY
      ELSE
         SET @cFieldAttr13 = '' -- PQTY

      -- Disable QTY field
      IF @cDisableQTYField = '1'
      BEGIN
         SET @cFieldAttr13 = 'O' -- PQTY
         SET @cFieldAttr14 = 'O' -- MQTY
      END

      -- Prep next screen var
      SET @cOutField01 = CAST ( @nCurrentRec AS NVARCHAR(2) ) + '/' + CAST ( @nTotalRec AS NVARCHAR(4) )
      SET @cOutField02 = ''
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING(@cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING(@cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField10 = CAST(@nPUOM_DIV AS NCHAR(6))  + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
      SET @cOutField11 = CASE WHEN @nPQTY_Avail = 0 THEN '' ELSE CAST( @nPQTY_Avail AS NVARCHAR( 5)) END
      SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField13 = CASE WHEN @cDisableQTYField = '1' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END -- PQTY
      SET @cOutField14 = CAST( @nMQTY AS NVARCHAR( 5)) -- MQTY
      SET @cOutField15 = '' -- ExtendedInfo

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU

      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
   END

   Step_TOUCC_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               ' @nMobile         INT, ' +
               ' @nFunc           INT, ' +
               ' @cLangCode       NVARCHAR(3), ' +
               ' @nStep           INT, ' +
               ' @nAfterStep      INT, ' +
               ' @nInputKey       INT, ' +
               ' @cStorerKey      NVARCHAR(15), ' +
               ' @cFacility       NVARCHAR(5), '  +
               ' @cToLOC          NVARCHAR(10), ' +
               ' @cToID           NVARCHAR(18), ' +
               ' @cFromLOC        NVARCHAR(10), ' +
               ' @cFromID         NVARCHAR(18), ' +
               ' @cSKU            NVARCHAR(20), ' +
               ' @nQTY            INT, ' +
               ' @cUCC            NVARCHAR(20), ' +
               ' @cLottable01     NVARCHAR(18), ' +
               ' @cLottable02     NVARCHAR(18), ' +
               ' @cLottable03     NVARCHAR(18), ' +
               ' @dLottable04     DATETIME,     ' +
               ' @dLottable05     DATETIME,     ' +
               ' @cLottable06     NVARCHAR(18), ' +
               ' @cLottable07     NVARCHAR(18), ' +
               ' @cLottable08     NVARCHAR(18), ' +
               ' @cLottable09     NVARCHAR(18), ' +
               ' @cLottable10     NVARCHAR(18), ' +
               ' @cLottable11     NVARCHAR(18), ' +
               ' @cLottable12     NVARCHAR(18), ' +
               ' @dLottable13     DATETIME,     ' +
               ' @dLottable14     DATETIME,     ' +
               ' @dLottable15     DATETIME,     ' +
               ' @tExtInfoVar     VariableTable READONLY, ' +
               ' @cExtendedInfo   NVARCHAR( 20) OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_TOUCC, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
      GOTO Quit
   END

   Step_TOUCC_Fail:
   BEGIN
      IF @nErrNo <> -1 -- -1=Retain UCC
         SET @cOutField01 = '' -- UCC
   END
END
GOTO Quit

/********************************************************************************
Step 8. screen = 5677
   CLOSE PALLET?
   1 = YES
   2 = NO
   OPTION (field01, input)
********************************************************************************/
Step_CLOSEPALLET:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 148378
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OPTION
         GOTO Step_CLOSEPALLET_Fail
      END

      IF NOT @cOption IN ('1', '2')
      BEGIN
         SET @nErrNo = 148379
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid OPTION
         GOTO Step_CLOSEPALLET_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @nErrNo = 0
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
                  ' @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT, ' +
                  '@nFunc           INT, ' +
                  '@cLangCode       NVARCHAR(3), ' +
                  '@nStep           INT, ' +
                  '@nInputKey       INT, ' +
                  '@cStorerKey      NVARCHAR(15), ' +
                  '@cFacility       NVARCHAR(5), ' +
                  '@cToLOC          NVARCHAR(10), ' +
                  '@cToID           NVARCHAR(18), ' +
                  '@cFromLOC        NVARCHAR(10), ' +
                  '@cFromID         NVARCHAR(18), ' +
                  '@cSKU            NVARCHAR(20), ' +
                  '@nQTY            INT, ' +
                  '@cUCC            NVARCHAR(20), ' +
                  '@cLottable01     NVARCHAR(18), ' +
                  '@cLottable02     NVARCHAR(18), ' +
                  '@cLottable03     NVARCHAR(18), ' +
                  '@dLottable04     DATETIME,     ' +
                  '@dLottable05     DATETIME,     ' +
                  '@cLottable06     NVARCHAR(18), ' +
                  '@cLottable07     NVARCHAR(18), ' +
                  '@cLottable08     NVARCHAR(18), ' +
                  '@cLottable09     NVARCHAR(18), ' +
                  '@cLottable10     NVARCHAR(18), ' +
                  '@cLottable11     NVARCHAR(18), ' +
                  '@cLottable12     NVARCHAR(18), ' +
                  '@dLottable13     DATETIME,     ' +
                  '@dLottable14     DATETIME,     ' +
                  '@dLottable15     DATETIME,     ' +
                  '@tExtUpdateVar   VARIABLETABLE READONLY, ' +
                  '@nErrNo          INT OUTPUT, ' +
                  '@cErrMsg         NVARCHAR(20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
                  @cToLOC, @cToID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN BuildUCC
                  GOTO Step_CLOSEPALLET_Fail
               END
            END
         END

         SET @bBuiltUCC = 0
         SET @cToLoc = ''
         SET @cToID = ''

         -- Prep next screen var
         SET @cOutField01 = @cDefaultToLOC

         SET @nScn = @nScn_TOLOC
         SET @nStep = @nStep_TOLOC
      END
      ELSE
      BEGIN
         SET @bBuiltUCC = 1
         SET @cFromLOC = ''
         SET @cFromID = ''

         -- Prep next screen var
         SET @cOutField01 = @cToLOC
         SET @cOutField02 = @cToID
         SET @cOutField03 = ''

         SET @nScn = @nScn_FROMLOC
         SET @nStep = @nStep_FROMLOC
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''

      SET @nScn = @nScn
      SET @nStep = @nStep
   END
   GOTO Quit

   Step_CLOSEPALLET_Fail:
   BEGIN
      SET @cOutField01 = ''
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
Step_MULTISKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
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

      -- Get SKU info
      SELECT @cSKUDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   END
   
   EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

   -- Go to next screen
   SET @nScn = @nScn_SKU
   SET @nStep = @nStep_SKU

END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.rdtMobRec SET
      EditDate      = GETDATE(),
      ErrMsg        = @cErrMsg,
      Func          = @nFunc,
      Step          = @nStep,
      Scn           = @nScn,

      StorerKey     = @cStorerKey,
      Facility      = @cFacility,

      V_Integer1    = @nQTY_Avail,
      V_Integer2    = @nPQTY_Avail,
      V_Integer3    = @nMQTY_Avail,
      V_Integer4    = @nQTY,
      V_Integer5    = @nMultiStorer,
      V_Integer6    = @bBuiltUCC,
      V_Integer7    = @nTotalRec,
      V_Integer8    = @nCurrentRec,
      V_Integer9    = @nPackQtyIndicator,
      V_Integer10   = @nCaseCNT,

      V_Lottable01  = @cLottable01,
      V_Lottable02  = @cLottable02,
      V_Lottable03  = @cLottable03,
      V_Lottable04  = @dLottable04,
      V_Lottable05  = @dLottable05,
      V_Lottable06  = @cLottable06,
      V_Lottable07  = @cLottable07,
      V_Lottable08  = @cLottable08,
      V_Lottable09  = @cLottable09,
      V_Lottable10  = @cLottable10,
      V_Lottable11  = @cLottable11,
      V_Lottable12  = @cLottable12,
      V_Lottable13  = @dLottable13,
      V_Lottable14  = @dLottable14,
      V_Lottable15  = @dLottable15,

      V_PQTY        = @nPQTY,
      V_MQTY        = @nMQTY,
      V_PUOM_Div    = @nPUOM_Div,
      V_LOC         = @cFromLOC,
      V_ID          = @cFromID,
      V_SKU         = @cSKU,
      V_SKUDescr    = @cSKUDescr,
      V_UCC         = @cUCC,
      V_UOM         = @cPUOM,

      V_String1     = @cToLOC,
      V_String2     = @cToID,
      V_String3     = @cLottableCode,
      V_String4     = @cPUOM_Desc,
      V_String5     = @cMUOM_Desc,
      V_String6     = @cSKU_StorerKey,
      V_String7     = @cPrePackIndicator,

      V_String20    = @cExtendedValidateSP,
      V_String21    = @cExtendedUpdateSP,
      V_String22    = @cExtendedInfoSP,
      V_String23    = @cExtendedInfo,
      V_String24    = @cDefaultFromLOC,
      V_String25    = @cDefaultToLOC,
      V_String26    = @cDefaultOption,
      V_String27    = @cDefaultQTY,
      V_String28    = @cDisableQTYField,
      V_String29    = @cMultiSKUBarcode,
      V_String30    = @cUCCWithMultiSKU,
      V_String31    = @cUCCWithDynamicCaseCNT,
      V_String32    = @cDecodeSP,
      V_String33    = @cDecodeUCCNoSP,
      V_String34    = @cAutoGenID,
      V_String35    = @cAutoGenUCC,
      V_String36    = @cMassBuildUCC,
      V_String37    = @cClosePallet,
      V_String38    = @cUCCLabel,
      V_String39    = @cCustomCaseCNTSP, 

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01 = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02 = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03 = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04 = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05 = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06 = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07 = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08 = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09 = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10 = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11 = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12 = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13 = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14 = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15 = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO
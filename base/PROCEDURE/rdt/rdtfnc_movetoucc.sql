SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_MoveToUCC                                          */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Move To UCC                                                       */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2013-09-24 1.0  Chee     Created                                           */
/* 2013-11-21 1.1  Chee     Show rdt_move error (Chee01)                      */
/* 2013-12-26 1.2  Chee     Bug Fix - Add FromLot into rdt_move (Chee02)      */
/* 2014-05-22 1.3  Ung      SOS309830 ExtendedUpdateSP add UCC param          */
/* 2014-12-17 1.4  ChewKP   SOS#326367 , Show Lottable Screen (ChewKP01)      */
/* 2015-03-23 1.5  ChewKP   SOS#336025 , Enabled multiSKU UCC (ChewKP02)      */
/* 2015-04-29 1.6  ChewKP   SOS#340551 , Exceed 7 Go Live Fixes (ChewKP03)    */
/* 2016-04-26 1.7  ChewKP   SOS#369220 , Add rdtIsValidFormat (ChewKP04)      */
/* 2016-09-30 1.8  Ung      Performance tuning                                */
/* 2017-03-10 1.9  James    WMS-1318 Move ExtendedUpdateSP after created UCC  */
/* 2017-03-24 2.0  Ung      WMS-1371 Add AutoGenID, DefaultToLOC, DefaultQTY, */
/*                          DecodeUCCNoSP, MassBuildUCC                       */
/* 2017-05-03 2.1  ChewKP   WMS-1796 Add ExtendedValidateSP @ Step-6(ChewKP05)*/
/* 2017-06-05 2.2  James    Bug fix (james01)                                 */
/* 2017-06-19 2.3  ChewKP   WMS-1796 Add DefaultOption config (ChewKP06)      */
/* 2017-08-10 2.4  Ung      WMS-2656 Add ExtendedInfoSP at UCC screen         */
/* 2018-04-18 2.5  James    WMS-4665 Add ExtendedValidateSP at SKU/QTY screen */
/*                          Add print UCC label (james02)                     */
/* 2018-01-26 2.6  ChewKP   WMS-3850 Add ConfirmSP config (ChewKP07)          */
/* 2018-08-17 2.7  James    WMS-5970 Add storerkey to ucclabel (james03)      */
/* 2018-09-03 2.8  LZG      INC0374412 - Fix arithmetic overflow error (ZG01) */
/* 2018-10-02 2.9  TungGH   Performance                                       */
/* 2019-01-09 3.0  James    WMS-7490 Add custom fetch batch sp (james04)      */
/*                          Set to display none if config DefaultQty = ''     */
/*                          instead of 0                                      */
/* 2019-10-22 3.1  Chermaine WMS-10909 Add Event log  (cc01)                  */ 
/* 2022-04-11 3.2  Ung       WMS-19419 Add rdtFormat for To ID                */
/* 2023-03-13 3.3  Ung       WMS-21971 Add ExtendedValidateSP at FromLOC      */
/******************************************************************************/
CREATE   PROC [RDT].[rdtfnc_MoveToUCC](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
) AS

  
SET NOCOUNT ON        
SET QUOTED_IDENTIFIER OFF        
SET ANSI_NULLS OFF        
SET CONCAT_NULL_YIELDS_NULL OFF        
    
-- Misc variable
DECLARE
   @bSuccess            INT,
   @cAutoID             NVARCHAR(18),
   @tVar                VariableTable

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
   @cFromLOC            NVARCHAR(10),
   @cFromID             NVARCHAR(18),
   @cSKU                NVARCHAR(20),
   @cSKUDescr           NVARCHAR(60),
   @nSKUCnt             INT,

   @cPUOM               NVARCHAR(1), -- Pref UOM
   @cPUOM_Desc          NCHAR(5),    -- Pref UOM desc
   @cMUOM_Desc          NCHAR(5),    -- Master UOM desc
   @nQTY_Avail          INT,         -- QTY avail in master UOM
   @nPQTY_Avail         INT,         -- QTY avail in pref UOM
   @nMQTY_Avail         INT,         -- Remaining QTY in master UOM
   @nQTY                INT,         -- QTY to move, in master UOM
   @nPQTY               INT,         -- QTY to move, in pref UOM
   @nMQTY               INT,         -- Remining QTY to move, in master UOM
   @nPUOM_Div           INT,

   @cToLoc              NVARCHAR(10),
   @cToID               NVARCHAR(18),
   @cLoseUCC            NVARCHAR(1),
   @cUCC                NVARCHAR(20),
   @cOption             NVARCHAR(1),
   @bBuiltUCC           INT,
   @cLottable01         NVARCHAR(18),
   @cLottable02         NVARCHAR(18),
   @cLottable03         NVARCHAR(18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cLOT                NVARCHAR(10),

   @cChkFacility        NVARCHAR(5),
   @nMultiStorer        INT,
   @cSKU_StorerKey      NVARCHAR(15),
   @cExtendedUpdateSP   NVARCHAR(20),
   @cSQL                NVARCHAR(1000),
   @cSQLParam           NVARCHAR(1000),

   @b_Success           INT,
   @n_Err               INT,
   @c_ErrMsg            NVARCHAR(20),

   @nCountTotalLot      INT,
   @nCountLot           INT,
   @cUCCWithMultiSKU    NVARCHAR(1), -- (ChewKP01)
   @cExtendedValidateSP NVARCHAR(20), -- (ChewKP02)
   @cDefaultFromLOC     NVARCHAR(10),
   @cDefaultToLOC       NVARCHAR(10),
   @cDecodeUCCNoSP      NVARCHAR(20),
   @cAutoGenID          NVARCHAR(20),
   @cDefaultQTY         NVARCHAR(5),
   @cMassBuildUCC       NVARCHAR(1),
   @cClosePallet        NVARCHAR(1),
   @cDefaultOption      NVARCHAR(1), -- (ChewKP06)
   @cExtendedInfoSP     NVARCHAR(20),
   @cExtendedInfo       NVARCHAR(20),
   @cUCCLabel           NVARCHAR(20),
   @cConfirmSP          NVARCHAR(20), -- (ChewKP07)

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

DECLARE
   @c_oFieled01      NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03      NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05      NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07      NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09      NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11      NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13      NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15      NVARCHAR(20),
   @cDecodeLabelNo   NVARCHAR(20),
   @c_LabelNo        NVARCHAR(32),
   @cDecodeQty       NVARCHAR(5),
   @cAvlQTY          NVARCHAR(5)

DECLARE
   @nLOTQty                    INT,
   @nReLOTQty                  INT,
   @c_LOT                      NVARCHAR(10),
   @c_LOC                      NVARCHAR(10),
   @c_ID                       NVARCHAR(18),
   @c_Lottable01               NVARCHAR(18),
   @c_Lottable02               NVARCHAR(18),
   @c_Lottable03               NVARCHAR(18),
   @d_Lottable04               DATETIME,
   @d_Lottable05               DATETIME,
   @c_SKU                      NVARCHAR(20),
   @c_PQTY                     NVARCHAR(5),
   @c_MQTY                     NVARCHAR(5),
   @n_PQTY                     INT,
   @n_MQTY                     INT

DECLARE @cCustomFetchTask_SP   NVARCHAR( 20) -- (james04)

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
   @cPrinter          = Printer,
   @cUserName         = UserName,

   @cFromLOC          = V_String1,
   @cFromID           = V_String2,
   @cSKU              = V_String3,
   @cSKUDescr         = V_SKUDescr,
   @cLottable01       = V_Lottable01,
   @cLottable02       = V_Lottable02,
   @cLottable03       = V_Lottable03,
   @dLottable04       = V_Lottable04,
   @cLOT              = V_LOT,
   @cUCC              = V_UCC,
   @cPUOM             = V_UOM,     -- Pref UOM

   @cPUOM_Desc          = V_String4, -- Pref UOM desc
   @cMUOM_Desc          = V_String5, -- Master UOM desc
   @cCustomFetchTask_SP = V_String6, -- (james04)
   @cToLOC              = V_String13,
   @cToID               = V_String14,
   @cSKU_StorerKey      = V_String16,
   @cExtendedUpdateSP   = V_String17,
   @cUCCWithMultiSKU    = V_String21, -- (ChewKP02)
   @cExtendedValidateSP = V_String22, -- (ChewKP02)
   @cDefaultFromLOC     = V_String23,
   @cDefaultToLOC       = V_String24,
   @cDecodeUCCNoSP      = V_String25,
   @cAutoGenID          = V_String26,
   @cDefaultQTY         = V_String27,
   @cMassBuildUCC       = V_String28,
   @cClosePallet        = V_String29,
   @cDefaultOption      = V_String30, -- (ChewKP06)
   @cExtendedInfoSP     = V_String31,
   @cExtendedInfo       = V_String32,
   @cUCCLabel           = V_String33,
   @cConfirmSP          = V_String34, -- (ChewKP07)
   
   @nPQTY               = V_PQTY,
   @nMQTY               = V_MQTY,
   @nPUOM_Div           = V_PUOM_Div,
   
   @nQTY_Avail          = V_Integer1,
   @nPQTY_Avail         = V_Integer2,
   @nMQTY_Avail         = V_Integer3,
   @nQTY                = V_Integer4,
   @nMultiStorer        = V_Integer5,  
   --@bBuiltUCC           = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_String18, 6), 0) = 1 THEN LEFT(V_String18, 6) ELSE 0 END,
   @bBuiltUCC           = V_Integer6,
   @nCountTotalLot      = V_Integer7,
   @nCountLot           = V_Integer8,

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

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1804
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1804
   IF @nStep = 1 GOTO Step_1   -- Scn = 3690  Scan TO LOC screen
   IF @nStep = 2 GOTO Step_2   -- Scn = 3691  Scan TO ID screen
   IF @nStep = 3 GOTO Step_3   -- Scn = 3692  Scan FROM LOC screen
   IF @nStep = 4 GOTO Step_4   -- Scn = 3693  Scan FROM ID screen
   IF @nStep = 5 GOTO Step_5   -- Scn = 3694  Scan SKU screen
   IF @nStep = 6 GOTO Step_6   -- Scn = 3695  Enter QTY MOVE screen
   IF @nStep = 7 GOTO Step_7   -- Scn = 3696  Scan TO UCC screen
   IF @nStep = 8 GOTO Step_8   -- Scn = 3697  Close Pallet screen
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1804)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 3690
   SET @nStep = 1

   -- Get prefer UOM
   SELECT @cPUOM = ISNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1
   SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorerKey)
   IF @cAutoGenID = '0'
      SET @cAutoGenID = ''
   SET @cClosePallet = rdt.rdtGetConfig( @nFunc, 'ClosePallet', @cStorerKey)
   SET @cDecodeUCCNoSP = rdt.RDTGetConfig( @nFunc, 'DecodeUCCNoSP', @cStorerKey)
   IF @cDecodeUCCNoSP = '0'
      SET @cDecodeUCCNoSP = ''
   SET @cDefaultFromLOC = rdt.RDTGetConfig( @nFunc, 'DefaultFromLoc', @cStorerKey)
   IF @cDefaultFromLOC = '0'
      SET @cDefaultFromLOC = ''
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
   SET @cMassBuildUCC = rdt.rdtGetConfig( @nFunc, 'MassBuildUCC', @cStorerKey)
   SET @cUCCWithMultiSKU = rdt.rdtGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)
   IF @cUCCWithMultiSKU = '0'
      SET @cUCCWithMultiSKU = ''

   -- (ChewKP06)
   SET @cDefaultOption = rdt.rdtGetConfig( @nFunc, 'DefaultOption', @cStorerKey)
   IF @cDefaultOption = '0'
      SET @cDefaultOption = ''

   -- (james02)
   SET @cUCCLabel = rdt.rdtGetConfig( @nFunc, 'UCCLabel', @cStorerKey)
   IF @cUCCLabel = '0'
      SET @cUCCLabel = ''

   -- (ChewKP07)
   SET @cConfirmSP = rdt.rdtGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''

   SET @cCustomFetchTask_SP = rdt.rdtGetConfig( @nFunc, 'CustomFetchTask_SP', @cStorerKey)
   IF @cCustomFetchTask_SP = '0'
      SET @cCustomFetchTask_SP = ''

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
   SET @bBuiltUCC = 0
   SET @nQTY_Avail = 0
   SET @nPQTY_Avail = 0
   SET @nMQTY_Avail = 0
   SET @nQTY = 0
   SET @nPQTY = 0
   SET @nMQTY = 0
   SET @nPUOM_Div = 0

   SET @cToLoc = ''
   SET @cToID = ''
   SET @cFromLOC = ''
   SET @cFromID = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''
   SET @cPUOM_Desc = ''
   SET @cMUOM_Desc = ''

   SET @cLOT = ''
   SET @cLottable01 = ''
   SET @cLottable02 = ''
   SET @cLottable03 = ''
   SET @dLottable04 = ''

   -- Prep next screen var
   SET @cOutField01 = @cDefaultToLOC
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
END
GOTO Quit

/********************************************************************************
Step 1. screen = 3690
   MOVE TO UCC

   TO LOC: (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLoc = @cInField01

      -- Check TOLOC
      IF ISNULL(@cToLoc, '') = ''
      BEGIN
         SET @nErrNo = 82901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TOLOC NEEDED'
         GOTO Step_1_Fail
      END

      -- Get TOLOC info
      SELECT
         @cChkFacility = Facility,
         @cLoseUCC = LoseUCC
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLoc

      -- Validate TOLOC
      IF ISNULL(@cChkFacility, '') = ''
      BEGIN
         SET @nErrNo = 82902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV TOLOC'
         GOTO Step_1_Fail
      END

      -- Validate TOLOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 82903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DIFF FACILITY'
         GOTO Step_1_Fail
      END

      IF @cLoseUCC = '1'
      BEGIN
         SET @nErrNo = 82904
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOSEUCC TOLOC'
         GOTO Step_1_Fail
      END

      IF @cAutoGenID <> ''
      BEGIN
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
            GOTO Step_1_Fail

         SET @cToID = @cAutoID
      END

      -- Prep next screen var
      SET @cOutField01 = @cToLoc
      SET @cOutField02 = @cToID

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out
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

      SET @cToLoc = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cToLoc = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 3691
   TO LOC: (Field01, display)
   TO ID:
   (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField02

      -- Check format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TOID', @cToID) = 0
      BEGIN
         SET @nErrNo = 82939
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidFormat
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Prep next screen var
      SET @cOutField01 = @cToLoc
      SET @cOutField02 = @cToID
      SET @cOutField03 = @cDefaultFromLOC

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cToLoc = ''
      SET @cOutField01 = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 3. screen = 3692
   TO LOC: (Field01, display)
   TO ID:
   (Field02, display)

   FROM LOC: (Field03, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromLoc = @cInField03

      -- Check FROMLOC
      IF ISNULL(@cFromLoc, '') = ''
      BEGIN
         SET @nErrNo = 82905
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'FROMLOC NEEDED'
         GOTO Step_3_Fail
      END

      -- Get FROMLOC info
      SELECT
         @cChkFacility = Facility,
         @cLoseUCC = LoseUCC
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLoc

      -- Validate FROMLOC
      IF ISNULL(@cChkFacility, '') = ''
      BEGIN
         SET @nErrNo = 82906
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV FROMLOC'
         GOTO Step_3_Fail
      END

      -- Validate FROMLOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 82907
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DIFF FACILITY'
         GOTO Step_3_Fail
      END

      IF @cLoseUCC = '0'
      BEGIN
         SET @nErrNo = 82908
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NOT LOSEUCC'
         GOTO Step_3_Fail
      END

      -- Validate FromLOC same as ToLOC
      IF @cFromLOC = @cToLOC
      BEGIN
         SET @nErrNo = 82909
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Same FromToLOC'
         GOTO Step_3_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR(3), ' +
               '@nStep           INT, ' +
               '@cStorerKey      NVARCHAR(15), ' +
               '@cFacility       NVARCHAR(5), '  +
               '@cFromLOC        NVARCHAR(10), ' +
               '@cFromID         NVARCHAR(18), ' +
               '@cSKU            NVARCHAR(20), ' +
               '@nQTY            INT, ' +
               '@cUCC            NVARCHAR(20), ' +
               '@cToID           NVARCHAR(18), ' +
               '@cToLOC          NVARCHAR(10), ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR(20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Prep next screen var
      SET @cOutField01 = @cToLOC
      SET @cOutField02 = @cToID
      SET @cOutField03 = @cFromLoc
      SET @cOutField04 = '' --@cFromID

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cClosePallet = '1' AND @bBuiltUCC = 1
      BEGIN
         -- Prep next screen var
         -- (ChewKP06)
         IF ISNULL(@cDefaultOption,'') <> ''
         BEGIN
            SET @cOutField01 = @cDefaultOption
         END
         ELSE
         BEGIN
            SET @cOutField01 = ''
         END

         -- Go to prev screen
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cToID = ''
         SET @cOutField01 = @cToLoc
         SET @cOutField02 = ''

         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cFromLoc  = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 3693
   TO LOC: (Field01, display)
   TO ID:
   (Field02, display)

   FROM LOC: (Field03, display)
   FROM ID:
   (Field04, input)
********************************************************************************/
Step_4:
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
         SET @nErrNo = 82910
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV ID'
         GOTO Step_4_Fail
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cFromID
      SET @cOutField03 = ''

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cFromLoc = ''
      SET @cOutField01 = @cToLoc
      SET @cOutField02 = @cToID
      SET @cOutField03 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cFromID  = ''
      SET @cOutField04 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 5. screen = 3694
   FROM LOC: (Field01, display)
   FROM ID:
   (Field02, display)

   SKU/UPC:
   (Field03, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField03

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @nErrNo = 82911
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU NEEDED'
         GOTO Step_5_Fail
      END

      SET @cDecodeQty = ''
      SET @cAvlQTY = ''

      SET @cDecodeLabelNo = ''
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)

      IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')
      BEGIN
         EXEC dbo.ispLabelNo_Decoding_Wrapper
          @c_SPName     = @cDecodeLabelNo
         ,@c_LabelNo    = @cSKU
         ,@c_Storerkey  = @cStorerkey
         ,@c_ReceiptKey = @nMobile
         ,@c_POKey      = ''
         ,@c_LangCode   = @cLangCode
         ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
         ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
         ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
         ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
         ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
         ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
         ,@c_oFieled07  = @c_oFieled07 OUTPUT
         ,@c_oFieled08  = @c_oFieled08 OUTPUT
         ,@c_oFieled09  = @c_oFieled09 OUTPUT
         ,@c_oFieled10  = @c_oFieled10 OUTPUT
         ,@b_Success    = @b_Success   OUTPUT
         ,@n_ErrNo      = @nErrNo      OUTPUT
         ,@c_ErrMsg     = @cErrMsg     OUTPUT   -- AvlQTY

         IF ISNULL(@cErrMsg, '') <> ''
         BEGIN
            SET @cErrMsg = @cErrMsg
            GOTO Step_5_Fail
         END

         SET @cSKU = @c_oFieled01
         SET @cDecodeQty = @c_oFieled05
         SET @cAvlQTY = @c_oFieled10

         IF @nMultiStorer = 1
            SET @cSKU_StorerKey = @c_oFieled09
      END

      IF @nMultiStorer = '1'
         GOTO Skip_ValidateSKU

      --Performance tuning
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
         SET @nErrNo = 82912
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV SKU'
         GOTO Step_5_Fail
      END

      EXEC [RDT].[rdt_GETSKU]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cSKU          OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT

      Skip_ValidateSKU:
      -- Get SKU info
      SELECT
         @cSKUDescr = S.DescR,
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
         INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
         AND SKU = @cSKU

      IF ISNULL(@cLOT, '') = ''
      BEGIN
         IF @cCustomFetchTask_SP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCustomFetchTask_SP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCustomFetchTask_SP) +
               ' @nMobile,    @nFunc,  @cLangCode,    @nStep,     @nInputKey,    @cFacility,    @cStorerkey, ' + 
               ' @cToLoc,     @cToID,  @cFromLoc,     @cFromID,   @cSKU, ' + 
               ' @cLot        OUTPUT,  @cLottable01      OUTPUT,  @cLottable02   OUTPUT,        @cLottable03 OUTPUT, ' + 
               ' @dLottable04 OUTPUT,  @nCountTotalLot   OUTPUT,  @nErrNo        OUTPUT,        @cErrMsg     OUTPUT '

            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerkey      NVARCHAR( 15), ' +
               '@cToLoc          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cFromLoc        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cLot            NVARCHAR( 10)  OUTPUT, ' +
               '@cLottable01     NVARCHAR( 18)  OUTPUT, ' +
               '@cLottable02     NVARCHAR( 18)  OUTPUT, ' +
               '@cLottable03     NVARCHAR( 18)  OUTPUT, ' +
               '@dLottable04     DATETIME       OUTPUT, ' +
               '@nCountTotalLot  INT            OUTPUT, ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile,   @nFunc,  @cLangCode,    @nStep,     @nInputKey,    @cFacility,    @cStorerkey, 
               @cToLoc,    @cToID,  @cFromLOC,     @cFromID,   @cSKU, 
               @cLot          OUTPUT, @cLottable01    OUTPUT,  @cLottable02 OUTPUT, @cLottable03    OUTPUT,       
               @dLottable04   OUTPUT, @nCountTotalLot OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

            IF @nErrNo <> 0
               GOTO Step_5_Fail
         END
         ELSE
         BEGIN
            -- GET EARLIEST LOT
            SELECT TOP 1
               @cLOT = LA.LOT,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = LA.Lottable04

            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
              AND LLI.LOC = @cFromLOC
              AND LLI.ID = CASE WHEN ISNULL(@cFromID, '') <> '' THEN @cFromID ELSE ID END
              AND LLI.SKU = @cSKU
              AND LLI.QTY > 0

            --ORDER BY LA.Lottable05
            GROUP BY LA.Lot, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
            HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
            ORDER BY LA.Lot

            SET @nCountTotalLot = 0

            SELECT @nCountTotalLot = Count ( Distinct LA.Lot )
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
              AND LLI.LOC = @cFromLOC
              AND LLI.ID = CASE WHEN ISNULL(@cFromID, '') <> '' THEN @cFromID ELSE ID END
              AND LLI.SKU = @cSKU
              AND LLI.QTY > 0
            --GROUP BY LA.Lot, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
            HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0

            IF ISNULL(@cLOT, '') = ''
            BEGIN
               SET @nErrNo = 82937
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --NoCandidateToMove
               GOTO Step_5_Fail
            END
         END
      END

      -- Get QTY avail of same Lottable01 - Lottable04
      SELECT @nQTY_Avail = SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
      FROM dbo.LOTxLOCxID LLI (NOLOCK)
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
         AND LLI.LOC = @cFromLOC
         AND LLI.ID = CASE WHEN ISNULL(@cFromID, '') <> '' THEN @cFromID ELSE LLI.ID END
         AND LLI.SKU = @cSKU
         AND LLI.QTY > 0
         AND LA.Lottable01 = @cLottable01
         AND LA.Lottable02 = @cLottable02
         AND LA.Lottable03 = @cLottable03
         AND LA.Lottable04 = @dLottable04

      -- Validate not QTY
      IF ISNULL(@nQTY_Avail, 0) = 0
      BEGIN
         SET @nErrNo = 82913
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --NO QTY TO MOVE
         GOTO Step_5_Fail
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cFromLOC',     @cFromLOC),
               ('@cFromID',      @cFromID),
               ('@cSKU',         @cSKU),
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
               ('@cToID',        @cToID),
               ('@cToLOC',       @cToLOC),
               ('@cUCC',         @cUCC)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            SET @cOutField10 = @cExtendedInfo
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
         SET @nPQTY = 0
      END

      -- SET @nMQTY = 1

      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING(@cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField03 = SUBSTRING(@cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField04 = @cLottable01
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = @dLottable04
      SET @nCountLot = 1
      SET @cOutField08 = CAST ( @nCountLot AS NVARCHAR(2) ) + '/' + CAST ( @nCountTotalLot AS NVARCHAR(4) )                -- ZG01



      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField12 = '' -- @nPQTY_Avail
         SET @cFieldAttr14 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField12 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
      END
      SET @cOutField09 = CAST(@nPUOM_DIV AS NCHAR(6))  + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
      SET @cOutField13 = CASE WHEN ISNULL(@cAvlQTY, '') <> '' THEN CAST(@cAvlQTY AS NVARCHAR(5)) ELSE CAST( @nMQTY_Avail AS NVARCHAR( 5)) END
      SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE '0' END -- @nPQTY
      SET @cOutField15 = CASE WHEN @cDefaultQTY <> '' THEN @cDefaultQTY ELSE '' END -- @nMQTY

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cToLOC
      SET @cOutField02 = @cToID
      SET @cOutField03 = @cFromLoc

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cSKU  = ''
      SET @cInField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 6. screen = 3695
   FROM LOC: (Field01, display)
   FROM ID:
   (Field02, display)

   SKU/UPC:
   (Field03, input)
   (Field04, display)
   (Field05, display)
   (Field06, display)

   1:(Field07, display) (Field08, display) (Field09, display)
   QTY AVL:             (Field10, display) (Field11, display)
   QTY MV:              (Field12, input)   (Field13, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      -- Screen mapping
      SET @c_SKU  = @cInField11 -- (ChewKP03)
      SET @c_PQTY = @cInField14
      SET @c_MQTY = @cInField15


      -- Validate PQTY
      SET @c_PQTY = CASE WHEN ISNULL(@c_PQTY, '') = '' THEN '0' ELSE @c_PQTY END
      IF RDT.rdtIsValidQTY(@c_PQTY, 0) = 0
      BEGIN
         SET @nErrNo = 82915
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'INV QTY'
         GOTO Quit
      END
      SET @n_PQTY = CAST(@c_PQTY AS INT)

      -- Validate MQTY
      SET @c_MQTY = CASE WHEN ISNULL(@c_MQTY, '') = '' THEN '0' ELSE @c_MQTY END
      IF RDT.rdtIsValidQTY(@c_MQTY, 0) = 0
      BEGIN
         SET @nErrNo = 82916
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'INV QTY'
         GOTO Quit
      END

      SET @n_MQTY = CAST(@c_MQTY AS INT)

--      -- Piece Scanning -- (ChewKP03)
      IF ISNULL(@c_SKU, '') <> ''
      BEGIN
/*
         IF @n_PQTY <> @nPQTY OR @n_MQTY <> @nMQTY
         BEGIN
            SET @nErrNo = 82917
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'SKU NOT NEEDED'
            EXEC rdt.rdtSetFocusField @nMobile, 11 -- SKU
            SET @cOutField11 = ''
            GOTO Quit
         END
*/
         EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @c_SKU         OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

         IF ISNULL(@c_SKU, '') <> @cSKU
         BEGIN
            SET @nErrNo = 82918
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'SKU NOT SAME'
            EXEC rdt.rdtSetFocusField @nMobile, 11 -- SKU
            SET @cOutField11 = ''
            GOTO Quit
         END

         IF @cDefaultQTY <> ''
         BEGIN
            SET @n_MQTY = @n_MQTY + @cDefaultQTY
            SET @c_MQTY = CAST( @n_MQTY AS NVARCHAR( 5))
         END
      END



      -- Calc total QTY in master UOM
      IF @nMultiStorer = 0
         SET @nQTY = rdt.rdtConvUOMQTY(@cStorerKey, @cSKU, @c_PQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      ELSE
         SET @nQTY = rdt.rdtConvUOMQTY(@cSKU_StorerKey, @cSKU, @c_PQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @n_MQTY

      -- Validate QTY
--      IF @nQTY = 0
--      BEGIN
--         SET @nErrNo = 82919
--         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'QTY NEEDED'
--         GOTO Quit
--      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY > @nQTY_Avail
      BEGIN
         SET @nErrNo = 82920
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'QTYAVL NOTENUF'
         GOTO Quit
      END

      SET @nPQTY = CASE WHEN ISNULL(@cPUOM_Desc, '') <> '' THEN @nQTY / @nPUOM_Div ELSE @n_PQTY END
      SET @nMQTY = CASE WHEN ISNULL(@cPUOM_Desc, '') <> '' THEN @nQTY % @nPUOM_Div ELSE @n_MQTY END

      -- Prep next screen var
      IF @c_PQTY = '0' AND @c_MQTY = '0' AND @c_SKU = ''
      BEGIN
         IF @cCustomFetchTask_SP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCustomFetchTask_SP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCustomFetchTask_SP) +
               ' @nMobile,    @nFunc,  @cLangCode,    @nStep,     @nInputKey,    @cFacility,    @cStorerkey, ' + 
               ' @cToLoc,     @cToID,  @cFromLoc,     @cFromID,   @cSKU, ' + 
               ' @cLot        OUTPUT,  @cLottable01      OUTPUT,     @cLottable02   OUTPUT,        @cLottable03 OUTPUT, ' + 
               ' @dLottable04 OUTPUT,  @nCountTotalLot   OUTPUT,     @nErrNo        OUTPUT,        @cErrMsg     OUTPUT '

            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerkey      NVARCHAR( 15), ' +
               '@cToLoc          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cFromLoc        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cLot            NVARCHAR( 10)  OUTPUT, ' +
               '@cLottable01     NVARCHAR( 18)  OUTPUT, ' +
               '@cLottable02     NVARCHAR( 18)  OUTPUT, ' +
               '@cLottable03     NVARCHAR( 18)  OUTPUT, ' +
               '@dLottable04     DATETIME       OUTPUT, ' +
               '@nCountTotalLot  INT            OUTPUT, ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile,   @nFunc,  @cLangCode,    @nStep,     @nInputKey,    @cFacility,    @cStorerkey, 
               @cToLoc,    @cToID,  @cFromLOC,     @cFromID,   @cSKU, 
               @cLot          OUTPUT, @cLottable01    OUTPUT,   @cLottable02   OUTPUT,        @cLottable03    OUTPUT,       
               @dLottable04   OUTPUT, @nCountTotalLot OUTPUT,   @nErrNo        OUTPUT,        @cErrMsg        OUTPUT

            IF @nErrNo <> 0
               GOTO Step_5_Fail

            SET @nCountLot = @nCountLot + 1

            IF @nCountLot > @nCountTotalLot
               SET @nCountLot = 1
         END
         ELSE
         BEGIN
            -- GET EARLIEST LOT
            SELECT TOP 1
               @cLOT = LA.LOT,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = LA.Lottable04
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
              AND LLI.LOC = @cFromLOC
              AND LLI.ID = CASE WHEN ISNULL(@cFromID, '') <> '' THEN @cFromID ELSE ID END
              AND LLI.SKU = @cSKU
              AND LLI.QTY > 0
              AND LLI.Lot > @cLot
            --ORDER BY LA.Lottable05
            GROUP BY LA.Lot, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
            HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
            ORDER BY LA.Lot

            IF @@ROWCOUNT = 0
            BEGIN
               SET @cLot = ''
            END
            ELSE
            BEGIN
               SET @nCountLot = @nCountLot + 1
            END

            IF ISNULL( @cLot, '' ) = ''
            BEGIN
                -- Back to First Lot
               SELECT TOP 1
                  @cLOT = LA.LOT,
                  @cLottable01 = LA.Lottable01,
                  @cLottable02 = LA.Lottable02,
                  @cLottable03 = LA.Lottable03,
                  @dLottable04 = LA.Lottable04
               FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
               WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
                 AND LLI.LOC = @cFromLOC
                 AND LLI.ID = CASE WHEN ISNULL(@cFromID, '') <> '' THEN @cFromID ELSE ID END
                 AND LLI.SKU = @cSKU
                 AND LLI.QTY > 0
                 GROUP BY LA.Lot, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
                 HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                 ORDER BY LA.Lot

               SET @nCountLot = 1
            END
         END

         -- Get QTY avail of same Lottable01 - Lottable04
         SELECT @nQTY_Avail = SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
            AND LLI.LOC = @cFromLOC
            AND LLI.ID = CASE WHEN ISNULL(@cFromID, '') <> '' THEN @cFromID ELSE LLI.ID END
            AND LLI.SKU = @cSKU
            AND LLI.QTY > 0
            AND LA.Lottable01 = @cLottable01
            AND LA.Lottable02 = @cLottable02
            AND LA.Lottable03 = @cLottable03
            AND LA.Lottable04 = @dLottable04

         -- Validate not QTY
         IF ISNULL(@nQTY_Avail, 0) = 0
         BEGIN
            SET @nErrNo = 82936
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --NO QTY TO MOVE
            GOTO Quit
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
            SET @nPQTY = 0
         END
         -- SET @nMQTY = 1

         -- (ChewKP05)
         IF @cExtendedValidateSP <> ''
         BEGIN

            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
            BEGIN


               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT, ' +
                  '@nFunc           INT, ' +
                  '@cLangCode       NVARCHAR(3), ' +
                  '@nStep           INT, ' +
                  '@cStorerKey      NVARCHAR(15), ' +
                  '@cFacility       NVARCHAR(5), '  +
                  '@cFromLOC        NVARCHAR(10), ' +
                  '@cFromID         NVARCHAR(18), ' +
                  '@cSKU            NVARCHAR(20), ' +
                  '@nQTY            INT, ' +
                  '@cUCC            NVARCHAR(20), ' +
                  '@cToID           NVARCHAR(18), ' +
                  '@cToLOC          NVARCHAR(10), ' +
                  '@nErrNo          INT OUTPUT, ' +
                  '@cErrMsg         NVARCHAR(20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  --SET @nErrNo = 82923
                  --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --EXT UPD FAIL
                  --ROLLBACK TRAN BuildUCC
                  GOTO Quit -- (ChewKP06)
               END

            END
         END

         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               INSERT INTO @tVar (Variable, Value) VALUES
                  ('@cFromLOC',     @cFromLOC),
                  ('@cFromID',      @cFromID),
                  ('@cSKU',         @cSKU),
                  ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
                  ('@cToID',        @cToID),
                  ('@cToLOC',       @cToLOC),
                  ('@cUCC',         @cUCC)

               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
                  ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
                  ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
                  ' @nErrNo         INT           OUTPUT, ' +
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
                  @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit

               SET @cOutField10 = @cExtendedInfo
            END
         END

         -- Prep next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING(@cSKUDescr, 1, 20)   -- SKU desc 1
         SET @cOutField03 = SUBSTRING(@cSKUDescr, 21, 20)  -- SKU desc 2
         SET @cOutField04 = @cLottable01
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
         SET @cOutField07 = @dLottable04
         SET @cOutField08 = CAST ( @nCountLot AS NVARCHAR(2) ) + '/' + CAST ( @nCountTotalLot AS NVARCHAR(4) )          -- ZG01

         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField12 = '' -- @nPQTY_Avail
            SET @cFieldAttr14 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField12 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         END
         SET @cOutField09 = CAST(@nPUOM_DIV AS NCHAR(6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
         SET @cOutField13 = CASE WHEN ISNULL(@cAvlQTY, '') <> '' THEN CAST(@cAvlQTY AS NVARCHAR(5)) ELSE CAST( @nMQTY_Avail AS NVARCHAR( 5)) END
         SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR(5)) END
         --SET @cOutField15 = CAST( @nMQTY AS NVARCHAR(5))
         SET @cOutField15 = CASE WHEN @cDefaultQTY <> '' THEN @cDefaultQTY ELSE '' END -- @nMQTY

         SET @nScn = @nScn
         SET @nStep = @nStep
      END
      ELSE
      BEGIN
         IF ISNULL(@c_SKU, '') = ''
         BEGIN
            -- (james02)
            IF @cExtendedValidateSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile         INT, ' +
                     '@nFunc           INT, ' +
                     '@cLangCode       NVARCHAR(3), ' +
                     '@nStep           INT, ' +
                     '@cStorerKey      NVARCHAR(15), ' +
                     '@cFacility       NVARCHAR(5), '  +
                     '@cFromLOC        NVARCHAR(10), ' +
                     '@cFromID         NVARCHAR(18), ' +
                     '@cSKU            NVARCHAR(20), ' +
                     '@nQTY            INT, ' +
                     '@cUCC            NVARCHAR(20), ' +
                     '@cToID           NVARCHAR(18), ' +
                     '@cToLOC          NVARCHAR(10), ' +
                     '@nErrNo          INT OUTPUT, ' +
                     '@cErrMsg         NVARCHAR(20) OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END

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
            SET @cOutField15 = '' --@cExtendedInfo

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
         END
         ELSE
         BEGIN
            IF @cPUOM_Desc = ''
            BEGIN
               SET @cOutField12 = '' -- @nPQTY_Avail
               SET @cFieldAttr14 = 'O'
            END
            ELSE
            BEGIN
               SET @cOutField12 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
               SET @cOutField14 = CAST(@nPQTY AS NVARCHAR(5))
            END
            SET @cOutField09 = CAST(@nPUOM_DIV AS NCHAR(6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
            SET @cOutField13 = CASE WHEN ISNULL(@cAvlQTY, '') <> '' THEN CAST(@cAvlQTY AS NVARCHAR(5)) ELSE CAST( @nMQTY_Avail AS NVARCHAR( 5)) END
            SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR(5)) END
            SET @cOutField15 = CAST( @nMQTY AS NVARCHAR(5))
         END
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cFromLOC',     @cFromLOC),
               ('@cFromID',      @cFromID),
               ('@cSKU',         @cSKU),
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
               ('@cToID',        @cToID),
               ('@cToLOC',       @cToLOC),
               ('@cUCC',         @cUCC)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 7
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- initialise all variable
      SET @nQTY_Avail = 0
      SET @nPQTY_Avail = 0
      SET @nMQTY_Avail = 0
      SET @nQTY = 0
      SET @nPQTY = 0
      SET @nMQTY = 0
      SET @nPUOM_Div = 0

      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cPUOM_Desc = ''
      SET @cMUOM_Desc = ''

      SET @cLOT = ''
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = ''

      SET @cOutField01 = @cToLOC
      SET @cOutField02 = @cToID
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

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit

/********************************************************************************
Step 7. screen = 3696
   TO UCC:
   (Field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      DECLARE @cBarCode       NVARCHAR( 60)
      DECLARE @cUserdefined01 NVARCHAR( 15)
      DECLARE @cUserdefined02 NVARCHAR( 15)
      DECLARE @cUserdefined03 NVARCHAR( 20)
      DECLARE @cUserdefined04 NVARCHAR( 30)
      DECLARE @cUserdefined05 NVARCHAR( 30)
      DECLARE @cUserdefined06 NVARCHAR( 30)
      DECLARE @cUserdefined07 NVARCHAR( 30)
      DECLARE @cUserdefined08 NVARCHAR( 30)
      DECLARE @cUserdefined09 NVARCHAR( 30)
      DECLARE @cUserdefined10 NVARCHAR( 30)

      SET @cUserdefined01 = ''
      SET @cUserdefined02 = ''
      SET @cUserdefined03 = ''
      SET @cUserdefined04 = ''
      SET @cUserdefined05 = ''
      SET @cUserdefined06 = ''
      SET @cUserdefined07 = ''
      SET @cUserdefined08 = ''
      SET @cUserdefined09 = ''
      SET @cUserdefined10 = ''

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
               -- (ChewKP06)
               IF ISNULL(@cDefaultOption,'') <> ''
               BEGIN
                  SET @cOutField01 = @cDefaultOption
               END
               ELSE
               BEGIN
                  SET @cOutField01 = ''
               END

               SET @nScn = @nScn + 1
               SET @nStep = @nStep + 1
            END
            ELSE
            BEGIN
               -- Prep next screen var
               SET @cOutField01 = @cToLoc
               SET @cOutField02 = @cToID
               SET @cOutField03 = ''

               SET @nScn = @nScn - 4
               SET @nStep = @nStep - 4
            END
            GOTO Step_7_Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 82921
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'TOUCC NEEDED'
            GOTO Step_7_Fail
         END
      END

      -- (ChewKP04)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UCC', @cBarCode) = 0
      BEGIN
         SET @nErrNo = 82939
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidFormat
         GOTO Step_7_Fail
      END

      -- Decode UCC
      IF @cDecodeUCCNoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeUCCNoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeUCCNoSP) +
               ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @cBarCode, @cUCC OUTPUT, ' +
               ' @cUserdefined01 OUTPUT, @cUserdefined02 OUTPUT, @cUserdefined03 OUTPUT, @cUserdefined04 OUTPUT, @cUserdefined05 OUTPUT, ' +
               ' @cUserdefined06 OUTPUT, @cUserdefined07 OUTPUT, @cUserdefined08 OUTPUT, @cUserdefined09 OUTPUT, @cUserdefined10 OUTPUT, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR(3) ,  ' +
               '@cStorerKey      NVARCHAR(15),  ' +
               '@cFacility       NVARCHAR(5) ,  ' +
               '@cFromLOC        NVARCHAR(10),  ' +
               '@cFromID         NVARCHAR(18),  ' +
               '@cSKU            NVARCHAR(20),  ' +
               '@nQTY            INT,           ' +
               '@cToID           NVARCHAR(18),  ' +
               '@cToLOC          NVARCHAR(10),  ' +
               '@cBarCode        NVARCHAR(60),  ' +
               '@cUCC            NVARCHAR(20)  OUTPUT, ' +
               '@cUserdefined01  NVARCHAR( 15) OUTPUT, ' +
               '@cUserdefined02  NVARCHAR( 15) OUTPUT, ' +
               '@cUserdefined03  NVARCHAR( 20) OUTPUT, ' +
               '@cUserdefined04  NVARCHAR( 30) OUTPUT, ' +
               '@cUserdefined05  NVARCHAR( 30) OUTPUT, ' +
               '@cUserdefined06  NVARCHAR( 30) OUTPUT, ' +
               '@cUserdefined07  NVARCHAR( 30) OUTPUT, ' +
               '@cUserdefined08  NVARCHAR( 30) OUTPUT, ' +
               '@cUserdefined09  NVARCHAR( 30) OUTPUT, ' +
               '@cUserdefined10  NVARCHAR( 30) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR(20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @cBarCode, @cUCC OUTPUT,
               @cUserdefined01 OUTPUT, @cUserdefined02 OUTPUT, @cUserdefined03 OUTPUT, @cUserdefined04 OUTPUT, @cUserdefined05 OUTPUT,
               @cUserdefined06 OUTPUT, @cUserdefined07 OUTPUT, @cUserdefined08 OUTPUT, @cUserdefined09 OUTPUT, @cUserdefined10 OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_7_Fail
         END
      END

      IF @cUCCWithMultiSKU = '' -- (ChewKP02)
      BEGIN
         IF EXISTS(SELECT 1 FROM UCC WITH (NOLOCK)
                   WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
                   AND UCCNo = @cUCC)
         BEGIN
            SET @nErrNo = 82922
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'TOUCC EXISTS'
            GOTO Step_7_Fail
         END
      END



      -- (ChewKP02)
      IF @cExtendedValidateSP <> ''
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN


            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR(3), ' +
               '@nStep           INT, ' +
               '@cStorerKey      NVARCHAR(15), ' +
               '@cFacility       NVARCHAR(5), '  +
               '@cFromLOC        NVARCHAR(10), ' +
               '@cFromID         NVARCHAR(18), ' +
               '@cSKU            NVARCHAR(20), ' +
               '@nQTY            INT, ' +
               '@cUCC            NVARCHAR(20), ' +
               '@cToID           NVARCHAR(18), ' +
               '@cToLOC          NVARCHAR(10), ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR(20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               --SET @nErrNo = 82923
               --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --EXT UPD FAIL
               --ROLLBACK TRAN BuildUCC
               GOTO Step_7_Fail
            END

         END
      END




      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN BuildUCC

      IF @cConfirmSP <> '' -- (ChewKP07)
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
               ' @nMobile, @nFunc, @nStep, @cLangCode,  @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cToID, @cToLOC, @cSKU, @cLot, @nQTY, @cUCC, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @nMultiStorer, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
              '@nMobile        INT,                       ' +
              '@nFunc          INT,                       ' +
              '@nStep          INT,                       ' +
              '@cLangCode      NVARCHAR( 3),              ' +
              '@cStorerKey     NVARCHAR( 15),             ' +
              '@cFacility      NVARCHAR( 5),              ' +
              '@cFromLoc       NVARCHAR( 10),             ' +
              '@cFromID        NVARCHAR( 18),             ' +
              '@cToLOC         NVARCHAR( 10),             ' +
              '@cToID          NVARCHAR( 18),             ' +
              '@cSKU           NVARCHAR( 20),             ' +
              '@cLot           NVARCHAR( 10),             ' +
              '@nQty           INT,                       ' +
              '@cUCC           NVARCHAR( 20),             ' +
              '@cLottable01    NVARCHAR( 18),             ' +
              '@cLottable02    NVARCHAR( 18),             ' +
              '@cLottable03    NVARCHAR( 18),             ' +
              '@dLottable04    DATETIME,                  ' +
              '@dLottable05    DATETIME,                  ' +
              '@nMultiStorer   INT,                       ' +
              '@nErrNo         INT           OUTPUT,      ' +
              '@cErrMsg        NVARCHAR( 20) OUTPUT       '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @cLangCode,  @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cToID, @cToLOC, @cSKU, @cLot, @nQTY, @cUCC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @nMultiStorer, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN BuildUCC
               GOTO Step_7_Fail
            END
         END
      END
      ELSE
      BEGIN

         -- Get @nLOTQty
         SELECT @nLOTQty = SUM(QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
         FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
           AND LOC = @cFromLOC
           AND ID = CASE WHEN ISNULL(@cFromID, '') <> '' THEN @cFromID ELSE ID END
           AND SKU = @cSKU
           AND QTY > 0
           AND LOT = @cLOT

         SET @nReLOTQty = @nQty - @nLOTQty

         DECLARE CURSOR_RELOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.LOT,
                LLI.LOC,
                LLI.ID,
                QTYAVAILABLE = (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen)
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
         JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
           AND LLI.LOC = @cFromLOC
           AND LLI.ID = CASE WHEN ISNULL(@cFromID, '') <> '' THEN @cFromID ELSE LLI.ID END
           AND LLI.SKU = @cSKU
           AND LLI.QTY > 0
           AND LA.Lottable01 = @cLottable01
           AND LA.Lottable02 = @cLottable02
           AND LA.Lottable03 = @cLottable03
           AND LA.Lottable04 = @dLottable04
           AND LLI.LOT <> @cLOT

         OPEN CURSOR_RELOT
         FETCH NEXT FROM CURSOR_RELOT INTO @c_LOT, @c_LOC, @c_ID, @nLOTQty

         WHILE (@@FETCH_STATUS <> -1 AND @nReLOTQty > 0)
         BEGIN
            IF @nLOTQty > @nReLOTQty
               SET @nLOTQty = @nReLOTQty

            SELECT
               @c_Lottable01 = Lottable01,
               @c_Lottable02 = Lottable02,
               @c_Lottable03 = Lottable03,
               @d_Lottable04 = Lottable04,
               @d_Lottable05 = Lottable05
            FROM LOTATTRIBUTE WITH (NOLOCK)
            WHERE LOT = @c_LOT

            -- RELOT
            IF @nMultiStorer = 0
            BEGIN
               EXECUTE nspItrnAddWithdrawal
                  @n_ItrnSysId  = NULL,
                  @c_StorerKey  = @cStorerKey,
                  @c_Sku        = @cSKU,
                  @c_Lot        = @c_LOT,
                  @c_ToLoc      = @c_LOC,
                  @c_ToID       = @c_ID,
                  @c_Status     = '',
                  @c_lottable01 = @c_Lottable01,
                  @c_lottable02 = @c_Lottable02,
                  @c_lottable03 = @c_Lottable03,
                  @d_lottable04 = @d_Lottable04,
                  @d_lottable05 = @d_Lottable05,
                  @n_casecnt    = 0,
                  @n_innerpack  = 0,
                  @n_Qty        = @nLOTQty,
                  @n_pallet     = 0,
                  @f_cube       = 0,
                  @f_grosswgt   = 0,
                  @f_netwgt     = 0,
                  @f_otherunit1 = 0,
                  @f_otherunit2 = 0,
                  @c_SourceKey  = '',
                  @c_SourceType = 'rdtfnc_MoveToUCC',
                  @c_PackKey    = '',
                  @c_UOM        = '',
                  @b_UOMCalc    = 0,
                  @d_EffectiveDate = NULL,
                  @c_ItrnKey    = '',
                  @b_Success    = @b_Success OUTPUT,
                  @n_err        = @n_err     OUTPUT,
                  @c_errmsg     = @c_errmsg  OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 82924
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --WITHDRAW FAIL
                  ROLLBACK TRAN BuildUCC
                  GOTO Step_7_Fail
               END

               EXECUTE nspItrnAddDeposit
                  @n_ItrnSysId  = NULL,
                  @c_StorerKey  = @cStorerKey,
                  @c_Sku        = @cSKU,
                  @c_Lot        = @cLOT,
                  @c_ToLoc      = @c_LOC,
                  @c_ToID       = @c_ID,
                  @c_Status     = '',
                  @c_lottable01 = @c_Lottable01,
                  @c_lottable02 = @c_Lottable02,
                  @c_lottable03 = @c_Lottable03,
                  @d_lottable04 = @d_Lottable04,
                  @d_lottable05 = @d_Lottable05,
                  @n_casecnt    = 0,
                  @n_innerpack  = 0,
                  @n_Qty        = @nLOTQty,
                  @n_pallet     = 0,
                  @f_cube       = 0,
                  @f_grosswgt   = 0,
                  @f_netwgt     = 0,
                  @f_otherunit1 = 0,
                  @f_otherunit2 = 0,
                  @c_SourceKey  = '',
                  @c_SourceType = 'rdtfnc_MoveToUCC',
                  @c_PackKey    = '',
                  @c_UOM        = '',
                  @b_UOMCalc    = 0,
                  @d_EffectiveDate = NULL,
                  @c_ItrnKey    = '',
                  @b_Success    = @b_Success OUTPUT,
                  @n_err        = @n_err     OUTPUT,
                  @c_errmsg     = @c_errmsg  OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 82925
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --DEPOSIT FAIL
                  ROLLBACK TRAN BuildUCC
                  GOTO Step_7_Fail
               END
            END
            ELSE
            BEGIN
               EXECUTE nspItrnAddWithdrawal
                  @n_ItrnSysId  = NULL,
                  @c_StorerKey  = @cSKU_StorerKey,
                  @c_Sku        = @cSKU,
                  @c_Lot        = @c_LOT,
                  @c_ToLoc      = @c_LOC,
                  @c_ToID       = @c_ID,
                  @c_Status     = '',
                  @c_lottable01 = @c_Lottable01,
                  @c_lottable02 = @c_Lottable02,
                  @c_lottable03 = @c_Lottable03,
                  @d_lottable04 = @d_Lottable04,
                  @d_lottable05 = @d_Lottable05,
                  @n_casecnt    = 0,
                  @n_innerpack  = 0,
                  @n_Qty        = @nLOTQty,
                  @n_pallet     = 0,
                  @f_cube       = 0,
                  @f_grosswgt   = 0,
                  @f_netwgt     = 0,
                  @f_otherunit1 = 0,
                  @f_otherunit2 = 0,
                  @c_SourceKey  = '',
                  @c_SourceType = 'rdtfnc_MoveToUCC',
                  @c_PackKey    = '',
                  @c_UOM        = '',
                  @b_UOMCalc    = 0,
                  @d_EffectiveDate = NULL,
                  @c_ItrnKey    = '',
                  @b_Success    = @b_Success OUTPUT,
                  @n_err        = @n_err     OUTPUT,
                  @c_errmsg     = @c_errmsg  OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 82926
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --WITHDRAW FAIL
                  ROLLBACK TRAN BuildUCC
                  GOTO Step_7_Fail
               END

               EXECUTE nspItrnAddDeposit
                  @n_ItrnSysId  = NULL,
                  @c_StorerKey  = @cSKU_StorerKey,
                  @c_Sku        = @cSKU,
                  @c_Lot        = @cLOT,
                  @c_ToLoc      = @c_LOC,
                  @c_ToID       = @c_ID,
                  @c_Status     = '',
                  @c_lottable01 = @c_Lottable01,
                  @c_lottable02 = @c_Lottable02,
                  @c_lottable03 = @c_Lottable03,
                  @d_lottable04 = @d_Lottable04,
                  @d_lottable05 = @d_Lottable05,
                  @n_casecnt    = 0,
                  @n_innerpack  = 0,
                  @n_Qty        = @nLOTQty,
                  @n_pallet     = 0,
                  @f_cube       = 0,
                  @f_grosswgt   = 0,
                  @f_netwgt     = 0,
                  @f_otherunit1 = 0,
                  @f_otherunit2 = 0,
                  @c_SourceKey  = '',
                  @c_SourceType = 'rdtfnc_MoveToUCC',
                  @c_PackKey    = '',
                  @c_UOM        = '',
                  @b_UOMCalc    = 0,
                  @d_EffectiveDate = NULL,
                  @c_ItrnKey    = '',
                  @b_Success    = @b_Success OUTPUT,
                  @n_err        = @n_err     OUTPUT,
                  @c_errmsg     = @c_errmsg  OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 82927
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --DEPOSIT FAIL
                  ROLLBACK TRAN BuildUCC
                  GOTO Step_7_Fail
               END
            END

            SET @nReLOTQty = @nReLOTQty - @nLOTQty

            FETCH NEXT FROM CURSOR_RELOT INTO @c_LOT, @c_LOC, @c_ID, @nLOTQty
         END -- END WHILE FOR CURSOR_RELOT
         CLOSE CURSOR_RELOT
         DEALLOCATE CURSOR_RELOT

         -- Move to LOC
         IF @nMultiStorer = 0
         BEGIN
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType = 'rdtfnc_MoveToUCC',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLOC,
               @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
               @cSKU        = @cSKU,
               @nQTY        = @nQTY,
               @cFromLOT    = @cLot,        -- Chee02
               @nFunc       = @nFunc        -- SKIP CantMixSKU&UCC Checking
         END
         ELSE
         BEGIN
            -- For multi storer move by sku, only able to move sku from loc contain
            -- only 1 sku 1 storer because if 1 sku multi storer then move by sku
            -- don't know which storer's sku to move
            -- If contain SKU A (Storer 1), SKU A (Storer 2) then will be blocked @ decode label sp
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType = 'rdtfnc_MoveToUCC',
               @cStorerKey  = @cSKU_StorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLOC,
               @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
               @cSKU        = @cSKU,
               @nQTY        = @nQTY,
               @cFromLOT    = @cLot,        -- Chee02
               @nFunc       = @nFunc        -- SKIP CantMixSKU&UCC Checking
         END

         IF @nErrNo <> 0
         BEGIN
            -- Chee01
   --         SET @nErrNo = 82928
   --         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --RDTMOVE FAIL
            ROLLBACK TRAN BuildUCC
            GOTO Step_7_Fail
         END
         ELSE
         BEGIN
             -- EventLog - QTY
             EXEC RDT.rdt_STD_EventLog
                @cActionType   = '4', -- Move
                @cUserID       = @cUserName,
                @nMobileNo     = @nMobile,
                @nFunctionID   = @nFunc,
                @cFacility     = @cFacility,
                @cStorerKey    = @cStorerkey,
                @cLocation     = @cFromLOC,
                @cToLocation   = @cToLOC,
                @cID           = @cFromID,
                @cToID         = @cToID,
                @cSKU          = @cSKU,
                @cUOM          = @cMUOM_Desc,
                @nQTY          = @nQTY,
                @nStep         = @nStep,
                @cUCC          = @cUCC    --(cc01)
         END

      END

      -- Build/Update UCC
      -- (ChewKP02)
      IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                     WHERE UCCNo   = @cUCC
                     AND StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
                     AND SKU       = @cSKU
                     AND Lot       = @cLot
                     AND ID        = @cToID
                     AND Loc       = @cToLoc )
      BEGIN
         IF @nMultiStorer = 1
            INSERT INTO UCC (UCCNo, StorerKey, ExternKey, Qty, SourceType, Status, SKU, Lot, Loc, ID,
               Userdefined01, Userdefined02, Userdefined03, Userdefined04, Userdefined05,
               Userdefined06, Userdefined07, Userdefined08, Userdefined09, Userdefined10)
            VALUES (@cUCC, @cSKU_StorerKey, '', @nQTY, 'rdtfnc_MoveToUCC', '1', @cSKU, @cLot, @cToLOC ,@cToID,
               @cUserdefined01, @cUserdefined02, @cUserdefined03, @cUserdefined04, @cUserdefined05,
               @cUserdefined06, @cUserdefined07, @cUserdefined08, @cUserdefined09, @cUserdefined10)
         ELSE
            INSERT INTO UCC (UCCNo, StorerKey, ExternKey, Qty, SourceType, Status, SKU, Lot, Loc, ID,
               Userdefined01, Userdefined02, Userdefined03, Userdefined04, Userdefined05,
               Userdefined06, Userdefined07, Userdefined08, Userdefined09, Userdefined10)
            VALUES (@cUCC, @cStorerKey, '', @nQTY, 'rdtfnc_MoveToUCC', '1', @cSKU, @cLot, @cToLOC ,@cToID,
               @cUserdefined01, @cUserdefined02, @cUserdefined03, @cUserdefined04, @cUserdefined05,
               @cUserdefined06, @cUserdefined07, @cUserdefined08, @cUserdefined09, @cUserdefined10)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 82929
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'INS UCC FAIL'
            ROLLBACK TRAN BuildUCC
            GOTO Step_7_Fail
         END
      END
      ELSE
      BEGIN

         UPDATE dbo.UCC
         SET Qty = Qty + @nQty
         WHERE UCCNo = @cUCC
         AND StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
         AND SKU       = @cSKU
         AND Lot       = @cLot
         AND ID        = @cToID
         AND Loc       = @cToLoc

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 82938
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'UpdUCCFail'
            ROLLBACK TRAN BuildUCC
            GOTO Step_7_Fail
         END

      END

      DECLARE
         @cStorerConfig_UCC NVARCHAR(1),
         @cMoveQTYAlloc     NVARCHAR(1),
         @cToLocType        NVARCHAR(10),
         @nFromLOC_SKU      INT,
         @nFromLOC_UCC      INT,
         @nToLOC_SKU        INT,
         @nToLOC_UCC        INT

      -- Get StorerConfig 'UCC'
      SET @cStorerConfig_UCC = '0' -- Default Off
      SELECT @cStorerConfig_UCC = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
      FROM dbo.StorerConfig (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConfigKey = 'UCC'

      SET @cMoveQTYAlloc = rdt.RDTGetConfig(@nFunc, 'MoveQTYAlloc', @cStorerKey)

      -- Get ToLOC LocationType
      SET @cToLocType = '' -- Default as BULK (just in case SKUxLOC not yet setup)
      SELECT @cToLocType = LocationType
      FROM dbo.SKUxLOC (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LOC = @cToLOC

      -- Validate if moved ToLOC will cause SKU + UCC mixed
      -- Check bulk location only. Pick location always lose UCC and become SKU
      IF @cStorerConfig_UCC = '1' AND                           -- When warehouse has SKU and UCC
         NOT (@cToLocType IN ('CASE', 'PICK') OR @cLoseUCC = '1') -- ToLOC keep UCC
      BEGIN
         -- (james01)
         -- Get ToLOC SKU QTY
         SELECT @nToLOC_SKU =
            CASE WHEN @cMoveQTYAlloc = '1'
               THEN IsNULL( SUM( QTY - QTYPicked), 0)
               ELSE IsNULL( SUM( QTY - QtyAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)), 0) -- (Avail + Alloc)
            END
         FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cToLOC
            AND ID  = CASE WHEN @cToID IS NULL THEN ID ELSE @cToID END

         -- Get ToLOC UCC QTY
         SELECT @nToLOC_UCC = IsNULL( SUM( UCC.QTY), 0)
         FROM dbo.UCC UCC (NOLOCK)
         WHERE UCC.StorerKey = @cStorerKey
            AND UCC.LOC = @cToLOC
            AND UCC.ID  = CASE WHEN @cToID IS NULL THEN UCC.ID ELSE @cToID END
            AND UCC.Status = '1' -- Received (Avail + Alloc)

         IF @nToLOC_SKU > 0 -- Means SKU or UCC have stock
         BEGIN
            IF @nToLOC_SKU = @nToLOC_UCC -- To contain only UCC
               SET @nToLOC_SKU = 0
            IF (@nToLOC_SKU <> 0 AND @nToLOC_UCC <> 0) -- ToLOC is already mix SKU and UCC
            BEGIN
               SET @nErrNo = 82930
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'CantMixSKU&UCC'
               ROLLBACK TRAN BuildUCC
               GOTO Step_7_Fail
            END
         END
      END

      DECLARE @nRemainInCurrentScreen INT
      -- (james01)
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR(3), ' +
               '@nStep           INT, ' +
               '@cStorerKey      NVARCHAR(15), ' +
               '@cFacility       NVARCHAR(5), ' +
               '@cFromLOC        NVARCHAR(10), ' +
               '@cFromID         NVARCHAR(18), ' +
               '@cSKU            NVARCHAR(20), ' +
               '@nQTY            INT, ' +
               '@cUCC            NVARCHAR(20), ' +
               '@cToID           NVARCHAR(18), ' +
               '@cToLOC          NVARCHAR(10), ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR(20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN BuildUCC
               GOTO Step_7_Fail
            END
         END
      END

      IF @cUCCLabel <> ''
      BEGIN
         -- Common params
         DECLARE @tUCCLabel AS VariableTable
         INSERT INTO @tUCCLabel (Variable, Value) VALUES ( '@cUCC', @cUCC)
         INSERT INTO @tUCCLabel (Variable, Value) VALUES ( '@cSKU', @cSKU)
         INSERT INTO @tUCCLabel (Variable, Value) VALUES ( '@cToLOC', @cToLOC)
         INSERT INTO @tUCCLabel (Variable, Value) VALUES ( '@cToID', @cToID)
         INSERT INTO @tUCCLabel (Variable, Value) VALUES ( '@cFromLOC', @cFromLOC)
         INSERT INTO @tUCCLabel (Variable, Value) VALUES ( '@cFromID', @cFromID)
         INSERT INTO @tUCCLabel (Variable, Value) VALUES ( '@nQty', @nQTY)
         INSERT INTO @tUCCLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey) -- (james03)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinter, '',
            @cUCCLabel, -- Report type
            @tUCCLabel, -- Report params
            'rdtfnc_MoveToUCC',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN BuildUCC
            GOTO Step_7_Fail
         END
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN



      IF @cMassBuildUCC = '1'
      BEGIN
         -- Prep current screen var
         SET @cOutField01 = ''
         GOTO Step_7_Quit
      END

      -- initialise all variable
      SET @nQTY_Avail = 0
      SET @nPQTY_Avail = 0
      SET @nMQTY_Avail = 0
      SET @nQTY = 0
      SET @nPQTY = 0
      SET @nMQTY = 0
      SET @nPUOM_Div = 0

      SET @cFromLOC = ''
      SET @cFromID = ''
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cPUOM_Desc = ''
      SET @cMUOM_Desc = ''

      SET @cLOT = ''
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = ''

      IF @cClosePallet = '1'
      BEGIN
         -- (ChewKP06)
         -- Prep next screen var
         IF ISNULL(@cDefaultOption,'') <> ''
         BEGIN
            SET @cOutField01 = @cDefaultOption
         END
         ELSE
         BEGIN
            SET @cOutField01 = ''
         END

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cToLoc
         SET @cOutField02 = @cToID
         SET @cOutField03 = ''

         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4
      END
      GOTO Step_7_Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cFromLOC',     @cFromLOC),
               ('@cFromID',      @cFromID),
               ('@cSKU',         @cSKU),
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
               ('@cToID',        @cToID),
               ('@cToLOC',       @cToLOC),
               ('@cUCC',         @cUCC)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, 6, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            SET @cOutField10 = @cExtendedInfo
         END
      END

      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING(@cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField03 = SUBSTRING(@cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField04 = @cLottable01
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = @dLottable04
      SET @cOutField08 = CAST ( @nCountLot AS NVARCHAR(2) ) + '/' + CAST ( @nCountTotalLot AS NVARCHAR(4) )             -- ZG01

      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField12 = '' -- @nPQTY_Avail
         SET @cFieldAttr14 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField12 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
      END
      SET @cOutField09 = CAST(@nPUOM_DIV AS NCHAR(6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
      SET @cOutField13 = CASE WHEN ISNULL(@cAvlQTY, '') <> '' THEN CAST(@cAvlQTY AS NVARCHAR(5)) ELSE CAST( @nMQTY_Avail AS NVARCHAR( 5)) END
      SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR(5)) END -- @nPQTY
      SET @cOutField15 = CAST( @nMQTY AS NVARCHAR(5)) -- @nMQTY

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Step_7_Quit

   Step_7_Fail:
   BEGIN
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_RELOT')) >=0
      BEGIN
         CLOSE CURSOR_RELOT
         DEALLOCATE CURSOR_RELOT
      END

      SET @cOutField01 = ''
      GOTO Quit
   END

   Step_7_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cFromLOC',     @cFromLOC),
               ('@cFromID',      @cFromID),
               ('@cSKU',         @cSKU),
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
               ('@cToID',        @cToID),
               ('@cToLOC',       @cToLOC),
               ('@cUCC',         @cUCC)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 7
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit

/********************************************************************************
Step 8. screen = 3697
   CLOSE PALLET:

   1=YES
   2=NO

   OPTION: (Field01, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 82931
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'OPTION NEEDED'
         GOTO Step_8_Fail
      END

      IF NOT @cOption IN ('1', '2')
      BEGIN
         SET @nErrNo = 82932
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'INV OPTION'
         GOTO Step_8_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT, ' +
                  '@nFunc           INT, ' +
                  '@cLangCode       NVARCHAR(3), ' +
                  '@nStep           INT, ' +
                  '@cStorerKey      NVARCHAR(15), ' +
                  '@cFacility       NVARCHAR(5), ' +
                  '@cFromLOC        NVARCHAR(10), ' +
                  '@cFromID         NVARCHAR(18), ' +
                  '@cSKU            NVARCHAR(20), ' +
                  '@nQTY            INT, ' +
                  '@cUCC            NVARCHAR(20), ' +
                  '@cToID           NVARCHAR(18), ' +
                  '@cToLOC          NVARCHAR(10), ' +
                  '@nErrNo          INT OUTPUT, ' +
                  '@cErrMsg         NVARCHAR(20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 82933
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --EXT UPD FAIL
                  ROLLBACK TRAN BuildUCC
                  GOTO Step_8_Fail
               END
            END
         END

         SET @bBuiltUCC = 0
         SET @cToLoc = ''
         SET @cToID = ''

         -- Prep next screen var
         SET @cOutField01 = @cDefaultToLOC

         SET @nScn = @nScn - 7
         SET @nStep = @nStep - 7
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

         SET @nScn = @nScn - 5
         SET @nStep = @nStep - 5
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''

      SET @nScn = @nScn
      SET @nStep = @nStep
   END
   GOTO Quit

   Step_8_Fail:
   BEGIN
      SET @cOutField01 = ''
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

      V_String1     = @cFromLOC,
      V_String2     = @cFromID,
      V_String3     = @cSKU,
      V_SKUDescr    = @cSKUDescr,
      V_Lottable01  = @cLottable01,
      V_Lottable02  = @cLottable02,
      V_Lottable03  = @cLottable03,
      V_Lottable04  = @dLottable04,
      V_LOT         = @cLOT,
      V_UCC         = @cUCC,
      V_UOM         = @cPUOM,
      V_String4     = @cPUOM_Desc,
      V_String5     = @cMUOM_Desc,
      V_String6     = @cCustomFetchTask_SP, 
      V_String13    = @cToLOC,
      V_String14    = @cToID,
      V_String16    = @cSKU_StorerKey,
      V_String17    = @cExtendedUpdateSP,
      V_String21    = @cUCCWithMultiSKU,
      V_String22    = @cExtendedValidateSP,
      V_String23    = @cDefaultFromLOC,
      V_String24    = @cDefaultToLOC,
      V_String25    = @cDecodeUCCNoSP,
      V_String26    = @cAutoGenID,
      V_String27    = @cDefaultQTY,
      V_String28    = @cMassBuildUCC,
      V_String29    = @cClosePallet,
      V_String30    = @cDefaultOption, -- (ChewKP06)
      V_String31    = @cExtendedInfoSP,
      V_String32    = @cExtendedInfo,
      V_String33    = @cUCCLabel,
      V_String34    = @cConfirmSP, -- (ChewKP07)

      V_PQTY        = @nPQTY,
      V_MQTY        = @nMQTY,
      V_PUOM_Div    = @nPUOM_Div,
      
      V_Integer1    = @nQTY_Avail,
      V_Integer2    = @nPQTY_Avail,
      V_Integer3    = @nMQTY_Avail,
      V_Integer4    = @nQTY,
      V_Integer5    = @nMultiStorer,
      V_Integer6    = @bBuiltUCC,
      V_Integer7    = @nCountTotalLot,
      V_Integer8    = @nCountLot,
      
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
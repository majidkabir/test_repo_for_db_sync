SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_Move_SKU_Lottable                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose:                                                             */
/* Move partial or full QTY of a SKU from a LOC/ID to another LOC/ID    */
/*                                                                      */
/* Modifications log:                                                   */
/* Date       Rev  Author   Purposes                                    */
/* 2006-11-15 1.0  UngDH    Created                                     */
/* 2006-01-18 1.1  UngDH    Support config 'MoveToLOCNotCheckFacility'  */
/* 2007-08-09 1.2  Vicky    Bug Fix on Qty Screen - QtyAvail showing    */
/* 2007-11-28 1.3  Vicky    SOS#81879 - Add generic Lottable_Wrapper    */
/* 2008-03-14 1.3  James    Bug fix on disable prefered                 */
/*                          qty field if prefered UOM = 6 (EA)          */
/* 2008-04-25 1.4  James    Make From ID as optional field to key in    */
/* 2008-05-20 1.5  James    SOS106962 - Perfomance tuning on SKU screen */
/* 2008-06-26 1.4  James    When pref qty field disabled then need to   */
/*                          clean up pref qty field to prevent rubbish  */
/* 2008-11-03 1.5  Vicky    Remove XML part of code that is used to     */
/*                          make field invisible and replace with new   */
/*                          code (Vicky02)                              */
/* 2009-07-06 1.6  Vicky    Add in EventLog (Vicky06)                   */
/* 2010-10-01 1.7  Shong    Cater QtyReplen                             */
/* 2011-07-20 1.8  James    Performance tuning on sku retrieve (james01)*/
/* 2013-07-05 1.9  Ung      SOS283076 Add Lottable01                    */
/* 2015-06-16 2.0  SPChin   SOS344638 - Codelkup Filter By StorerKey    */
/* 2016-09-30 2.1  Ung      Performance tuning                          */
/* 2017-01-24 2.2  Ung      Fix rdt_Move loop without exit condition    */
/**2018-08-09 2.3  LZG      INC0322438 - Added rdt.rdtConvertToDate to  */
/*                          handle conversion error (ZG01)              */
/* 2018-08-14 2.4  LZG      INC0347957 - Added NULL checking (ZG01)     */
/* 2018-10-16 2.5  TungGH   Performance                                 */
/* 2020-01-06 2.6  YeeKung  Add MultiSKU Barcode(yeekung01)             */
/* 2021-04-07 2.7  chermain WMS-16638 Add @cDecodeLabelNo (cc01)        */
/* 2022-07-27 2.8  Ung      WMS-20274 Add TOLOC at success move screen  */
/* 2022-08-04 2.9  Ung      WMS-16638 Fix @cToLOC not reset             */
/* 2023-06-14 3.0  James    WMS-22793 Add BackToScreen config (james02) */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_Move_SKU_Lottable] (
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
   @nRowCount         INT,
   @cChkFacility      NVARCHAR( 5),
   @dZero             DATETIME,
   @cXML              NVARCHAR( 4000), -- To allow double byte data for e.g. SKU desc
   @dSearchLottable04 DATETIME,
   @b_Success         INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR( 250)

SET @dZero = 0 -- 1900-01-01
SET @cXML = ''

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

   @cFromLOC          NVARCHAR( 10),  -- Searched ID
   @cFromID           NVARCHAR( 18),
   @cSKU              NVARCHAR( 20),
   @cSKUDescr         NVARCHAR( 60),

   @cLottableLabel01  NVARCHAR( 20),
   @cLottableLabel02  NVARCHAR( 20),
   @cLottableLabel03  NVARCHAR( 20),
   @cLottableLabel04  NVARCHAR( 20),
   @cSearchLottable01 NVARCHAR( 18),
   @cSearchLottable02 NVARCHAR( 18),
   @cSearchLottable03 NVARCHAR( 18),
   @cSearchLottable04 NVARCHAR( 16),
   @cLottable01       NVARCHAR( 18),
   @cLottable02       NVARCHAR( 18),
   @cLottable03       NVARCHAR( 18),
   @dLottable04       DATETIME,
   @cExtendedScreenSP NVARCHAR( 20),
   @nAction           INT,
   @nAfterScn         INT,
   @nAfterStep        INT,
   @cLocNeedCheck     NVARCHAR( 20),

   @cID         NVARCHAR( 18), -- Actual moved ID
   @cPUOM       NVARCHAR( 1),  -- Pref UOM
   @cPUOM_Desc  NVARCHAR( 5),  -- Pref UOM desc
   @cMUOM_Desc  NVARCHAR( 5),  -- Master UOM desc
   @nQTY_Avail  INT,       -- QTY avail in master UOM
   @nPQTY_Avail INT,       -- QTY avail in pref UOM
   @nMQTY_Avail INT,       -- Remaining QTY in master UOM
   @nQTY_Move   INT,       -- QTY to move, in master UOM
   @nPQTY_Move  INT,       -- QTY to move, in pref UOM
   @nMQTY_Move  INT,       -- Remining QTY to move, in master UOM
   @nPUOM_Div   INT,
   @nSKUCnt     INT,       -- SOS106962 Performance tuning

   @cToLOC      NVARCHAR( 10),
   @cToID       NVARCHAR( 18),
   @cUserName   NVARCHAR( 18),  -- (Vicky06)
   @cMultiSKUBarcode    NVARCHAR( 1),  -- (yeekung01)
   @nFromScn            INT,    -- (yeekung01)
   @nFromStep           INT,
   @cDecodeSP           NVARCHAR( 20), --(cc01)
   @cDecodeLabelNo      NVARCHAR(20),  --(cc01)
   @cQTY                NVARCHAR( 10), --(cc01)
   @cBarcode            NVARCHAR( 60), --(cc01)
   @cSerialNo           NVARCHAR( 30)  --(cc01)

--(cc01)
DECLARE
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)


-- SOS#81879 (Start)
DECLARE  @cLottable01_Code    NVARCHAR( 20),
         @cLottable02_Code    NVARCHAR( 20),
         @cLottable03_Code    NVARCHAR( 20),
         @cLottable04_Code    NVARCHAR( 20),
         @cLottableLabel      NVARCHAR( 20),
         @cPreLottable01      NVARCHAR( 18),
         @cPreLottable02      NVARCHAR( 18),
         @cPreLottable03      NVARCHAR( 18),
         @cPreLottable04      NVARCHAR( 18),
         @cTempLottable01     NVARCHAR( 18),
         @cTempLottable02     NVARCHAR( 18),
         @cTempLottable03     NVARCHAR( 18),
         @cTempLottable04     NVARCHAR( 16),
         @cTempLottable05     NVARCHAR( 16),
         @cListName           NVARCHAR( 20),
         @cShort              NVARCHAR( 10),
         @dPreLottable04      DATETIME,
         @dPreLottable05      DATETIME,
         @dPostLottable05     DATETIME,
         @dTempLottable04     DATETIME,
         @dTempLottable05     DATETIME,
         @cStoredProd         NVARCHAR( 250),
         @nCountLot           INT,
-- SOS#81879 (End)
         @cBackToScreen       NVARCHAR( 10), 
         
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
   @cUserName   = UserName,-- (Vicky06)

   @cID               = V_ID,
   @cSKUDescr         = V_SKUDescr,
   @cPUOM             = V_UOM,     -- Pref UOM
   @cLottable01       = V_Lottable01,
   @cLottable02       = V_Lottable02,
   @cLottable03       = V_Lottable03,
   @dLottable04       = V_Lottable04,
   @cLottableLabel01  = V_LottableLabel01,
   @cLottableLabel02  = V_LottableLabel02,
   @cLottableLabel03  = V_LottableLabel03,
   @cLottableLabel04  = V_LottableLabel04,

   @cFromLOC          = V_String1,
   @cFromID           = V_String2,
   @cSKU              = V_String3,
   @cSearchLottable01 = V_String4,
   @cSearchLottable02 = V_String5,
   @cSearchLottable03 = V_String6,
   @cSearchLottable04 = V_String7,
   @cPUOM_Desc        = V_String8, -- Pref UOM desc
   @cMUOM_Desc        = V_String9, -- Master UOM desc
   @cBackToScreen     = V_String10,
   @cToLOC            = V_String17,
   @cToID             = V_String18,
   @cLottable01_Code  = V_String19, -- SOS#81879
   @cLottable02_Code  = V_String20, -- SOS#81879
   @cLottable03_Code  = V_String21, -- SOS#81879
   @cLottable04_Code  = V_String22, -- SOS#81879
   @cMultiSKUBarcode  = V_String23, -- (yeekung01)
   @cDecodeSP         = V_String24, --(cc01)
   @cDecodeLabelNo    = V_String25, --(cc01)
   @cQTY              = V_String26, --(cc01)

   @nQTY_Avail        = V_Integer1,
   @nPQTY_Avail       = V_Integer2,
   @nMQTY_Avail       = V_Integer3,
   @nQTY_Move         = V_Integer4,
   @nPQTY_Move        = V_Integer5,
   @nMQTY_Move        = V_Integer6,

   @nPUOM_Div         = V_PUOM_Div,
   @nFromStep         = V_FromStep,  --(yeekung01)
   @nFromScn          = V_FromScn,   --(yeekung01)

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

IF @nFunc = 515 -- Move SKU (lottable)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Move SKU (lottable)
   IF @nStep = 1 GOTO Step_1   -- Scn = 1040. FromID
   IF @nStep = 2 GOTO Step_2   -- Scn = 1041. FromLOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1042. SKU, desc1, desc2
   IF @nStep = 4 GOTO Step_4   -- Scn = 1043. Lottable 1/2/3/4
   IF @nStep = 5 GOTO Step_5   -- Scn = 1044. UOM, QTY
   IF @nStep = 6 GOTO Step_6   -- Scn = 1045. ToID
   IF @nStep = 7 GOTO Step_7   -- Scn = 1046. ToLOC
   IF @nStep = 8 GOTO Step_8   -- Scn = 1047. Message
   IF @nStep = 9 GOTO Step_9   -- Scn = 3570. Multi SKU Barcode
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 515. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1040
   SET @nStep = 1

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)    --(cc01)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)    --(cc01)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''

   SET @cBackToScreen = rdt.RDTGetConfig( @nFunc, 'BackToScreen', @cStorerKey)

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Prep next screen var
   SET @cFromLOC = ''
   SET @cOutField01 = '' -- FromLOC

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


/********************************************************************************
Step 1. Scn = 1040. FromLOC
   FromLOC (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField01
      SET @cLocNeedCheck = @cInField01

      -- Validate blank
      IF @cFromLOC = '' OR @cFromLOC IS NULL
      BEGIN
         SET @nErrNo = 62876
         SET @cErrMsg = rdt.rdtgetmessage( 62876, @cLangCode, 'DSP') --'LOC needed'
         GOTO Step_1_Fail
      END

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '515ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_515ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cLocNeedCheck OUTPUT,
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
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_1_Fail
            
            SET @cFromLOC = @cLocNeedCheck
         END
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62877
         SET @cErrMsg = rdt.rdtgetmessage( 62877, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_1_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 62878
         SET @cErrMsg = rdt.rdtgetmessage( 62878, @cLangCode, 'DSP') --'Diff facility'
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
            SET @nErrNo = 62879
            SET @cErrMsg = rdt.rdtgetmessage( 62879, @cLangCode, 'DSP') --'LOC have UCC'
            GOTO Step_1_Fail
         END
      END

      -- Prep next screen var
      SET @cFromID = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' --@cFromID

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- (Vicky06) EventLog - Sign Out Function
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
Step 2. Scn = 1041. FromID
   FromLOC (field01)
   FromID  (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField02

      -- Validate ID
      IF ISNULL(@cFromID, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1
            FROM dbo.LOTxLOCxID (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND LOC = @cFromLOC
               AND ID = @cFromID
               AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0)
         BEGIN
            SET @nErrNo = 62880
            SET @cErrMsg = rdt.rdtgetmessage( 62880, @cLangCode, 'DSP') --'Invalid ID'
            GOTO Step_2_Fail
         END
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' --@cSKU

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cFromLOC = ''
      SET @cOutField01 = @cFromLOC

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
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cFromID  = ''
      SET @cOutField02 = '' -- ID
   END
END
GOTO Quit


/********************************************************************************
Step 3. scn = 1042. SKU screen
   FromLOC (field01)
   FromID  (field02)
   SKU     (field03, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField03
      SET @cBarcode = @cInField03

      -- Validate blank
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 62881
         SET @cErrMsg = rdt.rdtgetmessage( 62881, @cLangCode, 'DSP') --'SKU needed'
         GOTO Step_3_Fail
      END

      SET @cPreLottable01 = ''
      SET @cPreLottable02 = ''
      SET @cPreLottable03 = ''
      SET @dPreLottable04 = 0
      SET @dPreLottable05 = 0
      SET @cQTY = ''
      SET @cToLOC = ''

      -- Decode  --(cc01)
      -- Standard decode
      IF @cDecodeSP = '1'
      BEGIN
         EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
            @cUPC    = @cSKU    OUTPUT,
            @nQTY    = @cQTY    OUTPUT,
            @nErrNo  = @nErrNo  OUTPUT,
            @cErrMsg = @cErrMsg OUTPUT,
            @cType   = 'UPC'

      END
      ELSE
      BEGIN
         -- Label decoding
         IF @cDecodeLabelNo <> ''
         BEGIN
            SET @c_oFieled01 = @cSKU
            SET @c_oFieled03 = @cToLOC
            SET @c_oFieled05 = @cQTY
            SET @c_oFieled07 = @cPreLottable01
            SET @c_oFieled08 = @cPreLottable02
            SET @c_oFieled09 = @cPreLottable03
            SET @c_oFieled10 = @cPreLottable04

            EXEC dbo.ispLabelNo_Decoding_Wrapper
                @c_SPName     = @cDecodeLabelNo
               ,@c_LabelNo    = @cSKU
               ,@c_Storerkey  = @cStorerKey
               ,@c_ReceiptKey = ''
               ,@c_POKey      = ''
               ,@c_LangCode   = @cLangCode
               ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
               ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
               ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
               ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
               ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
               ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
               ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Lottable01
               ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- Lottable02
               ,@c_oFieled09  = @c_oFieled09 OUTPUT   -- Lottable03
               ,@c_oFieled10  = @c_oFieled10 OUTPUT   -- Lottable04
               ,@b_Success    = @b_Success   OUTPUT
               ,@n_ErrNo      = @nErrNo     OUTPUT
               ,@c_ErrMsg     = @cErrMsg     OUTPUT

            IF ISNULL(@cErrMsg, '') <> ''
            BEGIN
            	SET @nErrNo =  @nErrNo
               SET @cErrMsg = @cErrMsg

               GOTO Step_3_Fail
            END

            SET @cSKU = @c_oFieled01
            SET @cSerialNo = @c_oFieled02
            SET @cToLOC = @c_oFieled03
            SET @cQty = @c_oFieled05
            SET @cPreLottable01 = @c_oFieled07
            SET @cPreLottable02 = @c_oFieled08
            SET @cPreLottable03 = @c_oFieled09
            SET @cPreLottable04 = @c_oFieled10
         END
      END

      -- Validate SKU
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
         SET @nErrNo = 62882
         SET @cErrMsg = rdt.rdtgetmessage( 62882, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_3_Fail
      END

      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            SET @cInField13=''
            SET @cOutField13=''

            IF (@cFromID <>'')
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
                  @cSKU         OUTPUT,
                  @nErrNo       OUTPUT,
                  @cErrMsg      OUTPUT,
                  'LOTXLOCXID.ID',    -- DocType
                  @cFromID
            END
            ELSE
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
                  @cSKU         OUTPUT,
                  @nErrNo       OUTPUT,
                  @cErrMsg      OUTPUT,
                  'LOTXLOCXID.LOC',    -- DocType
                  @cFromLOC
            END

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nFromScn = @nScn
               SET @nFromStep = @nStep
               SET @nScn = 3570
               SET @nStep = @nStep + 6
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
         END
         ELSE
         BEGIN
            SET @nErrNo = 62895
            SET @cErrMsg = rdt.rdtgetmessage( 62895, @cLangCode, 'DSP') --'SameBarCodeSKU'
            GOTO Step_3_Fail
         END
      END

      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Get QTY avail
      SET @nQTY_Avail = 0
      SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
      FROM dbo.LOTxLOCxID (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cFromLOC
         AND ID = CASE WHEN @cFromID = '' THEN ID ELSE @cFromID END
         AND SKU = @cSKU

      -- Validate no QTY
      IF @nQTY_Avail = 0 OR @nQTY_Avail IS NULL
      BEGIN
         SET @nErrNo = 62883
         SET @cErrMsg = rdt.rdtgetmessage( 62883, @cLangCode, 'DSP') --'No QTY to move'
         GOTO Step_3_Fail
      END

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
            END AS INT),
         @cLottableLabel01 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.StorerKey = '') ORDER BY C.StorerKey DESC),''), --SOS344638
         @cLottableLabel02 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.StorerKey = '') ORDER BY C.StorerKey DESC),''), --SOS344638
         @cLottableLabel03 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.StorerKey = '') ORDER BY C.StorerKey DESC),''), --SOS344638
         @cLottableLabel04 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.StorerKey = '') ORDER BY C.StorerKey DESC),''), --SOS344638
         @cLottable01_Code = IsNULL(S.Lottable01Label, ''), -- SOS#81879
         @cLottable02_Code = IsNULL(S.Lottable02Label, ''), -- SOS#81879
         @cLottable03_Code = IsNULL(S.Lottable03Label, ''), -- SOS#81879
         @cLottable04_Code = IsNULL(S.Lottable04Label, '') -- SOS#81879
      FROM dbo.SKU S (NOLOCK)
         INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Disable lottable field
      IF @cLottableLabel01 = '' SET @cFieldAttr05 = 'O'
      IF @cLottableLabel02 = '' SET @cFieldAttr07 = 'O'
      IF @cLottableLabel03 = '' SET @cFieldAttr09 = 'O'
      IF @cLottableLabel04 = '' SET @cFieldAttr11 = 'O'

/********************************************************************************************************************/
/* SOS#81879 - Start                                                                                                */
/* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
/* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
/* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */
/* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
/*    Codelkup.Short = 'PRE' and Codelkup.Long = <SP Name>                                                          */
/********************************************************************************************************************/

      IF (IsNULL(@cLottable01_Code, '') <> '') OR
         (IsNULL(@cLottable02_Code, '') <> '') OR
         (IsNULL(@cLottable03_Code, '') <> '') OR
         (IsNULL(@cLottable04_Code, '') <> '')
      BEGIN
         --initiate @nCounter = 1
         SET @nCountLot = 1

         --retrieve value for pre lottable02 - 04
         WHILE @nCountLot <=4 --break the loop when @nCount > 3
         BEGIN
            IF @nCountLot = 1 SELECT @cListName = 'Lottable01', @cLottableLabel = @cLottable01_Code
            IF @nCountLot = 2 SELECT @cListName = 'Lottable02', @cLottableLabel = @cLottable02_Code
            IF @nCountLot = 3 SELECT @cListName = 'Lottable03', @cLottableLabel = @cLottable03_Code
            IF @nCountLot = 4 SELECT @cListName = 'Lottable04', @cLottableLabel = @cLottable04_Code

            --get short, store procedure and lottablelable value for each lottable
            SET @cShort = ''
            SET @cStoredProd = ''
            SELECT TOP 1 @cShort = ISNULL(RTRIM(C.Short),''),
                   @cStoredProd = IsNULL(RTRIM(C.Long), '')
            FROM dbo.CodeLkUp C WITH (NOLOCK)
            JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)
            WHERE C.ListName = @cListName
            AND   C.Code = @cLottableLabel
            AND   S.Storerkey = @cStorerKey        --SOS344638
            AND  (C.StorerKey = @cStorerKey OR C.StorerKey = '') --SOS344638
          ORDER BY C.StorerKey DESC          --SOS344638

            IF @cShort = 'PRE' AND @cStoredProd <> ''
            BEGIN
               EXEC dbo.ispLottableRule_Wrapper
                  @c_SPName            = @cStoredProd,
                  @c_ListName          = @cListName,
                  @c_Storerkey         = @cStorerKey,
                  @c_Sku               = @cSKU,
                  @c_LottableLabel     = @cLottableLabel,
                  @c_Lottable01Value   = '',
                  @c_Lottable02Value   = '',
                  @c_Lottable03Value   = '',
                  @dt_Lottable04Value  = '',
                  @dt_Lottable05Value  = '',
                  @c_Lottable01        = @cPreLottable01 OUTPUT,
                  @c_Lottable02        = @cPreLottable02 OUTPUT,
                  @c_Lottable03        = @cPreLottable03 OUTPUT,
                  @dt_Lottable04       = @dPreLottable04 OUTPUT,
                  @dt_Lottable05       = @dPreLottable05 OUTPUT,
                  @b_Success           = @b_Success   OUTPUT,
                  @n_Err               = @nErrNo      OUTPUT,
                  @c_Errmsg            = @cErrMsg     OUTPUT,
                  @c_Sourcekey         = '',
                  @c_Sourcetype        = 'RDTLOTMOVE'

               --IF @b_success <> 1
               IF ISNULL(@cErrMsg, '') <> ''
               BEGIN
                  SET @cErrMsg = @cErrMsg
                  GOTO Step_3_Fail
                  BREAK
               END

               SET @cPreLottable01 = IsNULL( @cPreLottable01, '')
               SET @cPreLottable02 = IsNULL( @cPreLottable02, '')
               SET @cPreLottable03 = IsNULL( @cPreLottable03, '')
               SET @dPreLottable04 = IsNULL( @dPreLottable04, 0)
               IF @dPreLottable04 > 0
                  SET @cPreLottable04 = RDT.RDTFormatDate(@dPreLottable04)
            END

            -- increase counter by 1
            SET @nCountLot = @nCountLot + 1
         END -- nCount
      END -- Lottable <> ''
/********************************************************************************************************************/
/* SOS#81879 - End                                                                                                  */
/* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
/********************************************************************************************************************/

      SET @cSearchLottable01 = ''
      SET @cSearchLottable02 = ''
      SET @cSearchLottable03 = ''
      SET @cSearchLottable04 = ''

      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField04 = CASE WHEN @cLottableLabel01 = '' THEN 'Lottable01:'   ELSE @cLottableLabel01 END
      SET @cOutField05 = CASE WHEN @cPreLottable01  <> '' THEN @cPreLottable01 ELSE '' END -- SOS#81879 --'' -- @cSearchLottable01
      SET @cOutField06 = CASE WHEN @cLottableLabel02 = '' THEN 'Lottable02:'   ELSE @cLottableLabel02 END
      SET @cOutField07 = CASE WHEN @cPreLottable02  <> '' THEN @cPreLottable02 ELSE '' END -- SOS#81879 --'' -- @cSearchLottable02
      SET @cOutField08 = CASE WHEN @cLottableLabel03 = '' THEN 'Lottable03:'   ELSE @cLottableLabel03 END
      SET @cOutField09 = CASE WHEN @cPreLottable03  <> '' THEN @cPreLottable03 ELSE '' END -- SOS#81879- -'' -- @cSearchLottable03
      SET @cOutField10 = CASE WHEN @cLottableLabel04 = '' THEN 'Lottable04:'   ELSE @cLottableLabel04 END
      SET @cOutField11 = CASE WHEN @cPreLottable04  <> '' THEN @cPreLottable04 ELSE '' END -- SOS#81879 --'' -- @cSearchLottable04

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cFromID = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' --@cFromID

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
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cSKU = ''
      SET @cOutField03 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Step 4. scn = 1043. Lottables
   SKU             (field01)
   SKUDesc         (field02)
   SKUDesc         (field03)
   LottableLabel01 (field04)
   Lottable01      (field05)
   LottableLabel02 (field06)
   Lottable02      (field07)
   LottableLabel03 (field08)
   Lottable03      (field09)
   LottableLabel04 (field10)
   Lottable04      (field11)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SELECT
         @cSearchLottable01 = CASE WHEN @cLottableLabel01 = '' THEN '' ELSE @cInField05 END,
         @cSearchLottable02 = CASE WHEN @cLottableLabel02 = '' THEN '' ELSE @cInField07 END,
         @cSearchLottable03 = CASE WHEN @cLottableLabel03 = '' THEN '' ELSE @cInField09 END,
         @cSearchLottable04 = CASE WHEN @cLottableLabel04 = '' THEN '' ELSE @cInField11 END

/********************************************************************************************************************/
/* SOS#81879 - Start                                                                                                */
/* Generic Lottables Computation (POST): To compute Lottables after input of Lottable value                         */
/* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
/* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */
/* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
/*    Codelkup.Short = 'POST' and Codelkup.Long = <SP Name>                                                         */
/********************************************************************************************************************/

      DECLARE @dtSearchLottable04 DATETIME

      SET @dPostLottable05 = 0

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

      --initiate @nCounter = 1
      SET @nCountLot = 1

      WHILE @nCountLot < = 4
      BEGIN
         IF @nCountLot = 1 SELECT @cListName = 'Lottable01', @cLottableLabel = @cLottable01_Code
         IF @nCountLot = 2 SELECT @cListName = 'Lottable02', @cLottableLabel = @cLottable02_Code
         IF @nCountLot = 3 SELECT @cListName = 'Lottable03', @cLottableLabel = @cLottable03_Code
         IF @nCountLot = 4 SELECT @cListName = 'Lottable04', @cLottableLabel = @cLottable04_Code

         SET @cShort = ''
         SET @cStoredProd = ''
         SELECT TOP 1 @cShort = C.Short,
               @cStoredProd = IsNULL( C.Long, '')
         FROM dbo.CodeLkUp C WITH (NOLOCK)
         WHERE C.Listname = @cListName
         AND   C.Code = @cLottableLabel
         AND  (C.StorerKey = @cStorerKey OR C.StorerKey = '') --SOS344638
         ORDER BY C.StorerKey DESC          --SOS344638

         IF @cShort = 'POST' AND @cStoredProd <> ''
         BEGIN
            IF rdt.rdtIsValidDate(@cSearchLottable04) = 1 --valid date
               SET @dtSearchLottable04 = ISNULL(rdt.rdtConvertToDate(@cSearchLottable04), 0)                  -- ZG01
               --SET @dtSearchLottable04 = CAST( @cSearchLottable04 AS DATETIME)

            EXEC dbo.ispLottableRule_Wrapper
               @c_SPName            = @cStoredProd,
               @c_ListName          = @cListName,
               @c_Storerkey         = @cStorerKey,
               @c_Sku               = @cSku,
               @c_LottableLabel     = @cLottableLabel,
               @c_Lottable01Value   = @cSearchLottable01,
               @c_Lottable02Value   = @cSearchLottable02,
               @c_Lottable03Value   = @cSearchLottable03,
               @dt_Lottable04Value  = @dtSearchLottable04,
               @dt_Lottable05Value  = @dPostLottable05,
               @c_Lottable01        = @cTempLottable01 OUTPUT,
               @c_Lottable02        = @cTempLottable02 OUTPUT,
               @c_Lottable03        = @cTempLottable03 OUTPUT,
               @dt_Lottable04       = @dTempLottable04 OUTPUT,
               @dt_Lottable05       = @dTempLottable05 OUTPUT,
               @b_Success           = @b_Success   OUTPUT,
               @n_Err               = @nErrNo      OUTPUT,
               @c_Errmsg            = @cErrMsg     OUTPUT,
               @c_Sourcekey         = '',
               @c_Sourcetype        = 'RDTLOTMOVE'

            IF ISNULL(@cErrMsg, '') <> ''
            BEGIN
               SET @cErrMsg = @cErrMsg

               IF @cListName = 'Lottable01' EXEC rdt.rdtSetFocusField @nMobile, 5
               IF @cListName = 'Lottable02' EXEC rdt.rdtSetFocusField @nMobile, 7
               IF @cListName = 'Lottable03' EXEC rdt.rdtSetFocusField @nMobile, 9
               IF @cListName = 'Lottable04' EXEC rdt.rdtSetFocusField @nMobile, 11

               GOTO Step_4_Fail
            END

            SET @cTempLottable01 = IsNULL( @cTempLottable01, '')
            SET @cTempLottable02 = IsNULL( @cTempLottable02, '')
            SET @cTempLottable03 = IsNULL( @cTempLottable03, '')
            SET @dTempLottable04 = IsNULL( @dTempLottable04, 0)
            SET @dTempLottable05 = IsNULL( @dTempLottable05, 0)

            SET @cOutField02 = CASE WHEN @cTempLottable01 <> '' THEN @cTempLottable01 ELSE @cSearchLottable01 END
            SET @cOutField03 = CASE WHEN @cTempLottable02 <> '' THEN @cTempLottable02 ELSE @cSearchLottable02 END
            SET @cOutField04 = CASE WHEN @cTempLottable03 <> '' THEN @cTempLottable03 ELSE @cSearchLottable03 END
            SET @cOutField05 = CASE WHEN @dTempLottable04 <> 0  THEN rdt.rdtFormatDate( @dTempLottable04) ELSE @cSearchLottable04 END

            SET @cSearchLottable01 = IsNULL(@cOutField02, '')
            SET @cSearchLottable02 = IsNULL(@cOutField03, '')
            SET @cSearchLottable03 = IsNULL(@cOutField05, '')
            SET @cSearchLottable04 = IsNULL(@cOutField07, '')
         END -- Short

         --increase counter by 1
         SET @nCountLot = @nCountLot + 1

      END -- end of while

/********************************************************************************************************************/
/* SOS#81879 - End                                                                                                  */
/* Generic Lottables Computation (POST): To compute Lottables after input of Lottable value                         */
/********************************************************************************************************************/

      -- Validate lottable04
      IF @cSearchLottable04 <> ''
         IF RDT.rdtIsValidDate( @cSearchLottable04) = 0
         BEGIN
            SET @nErrNo = 62884
            SET @cErrMsg = rdt.rdtgetmessage( 62884, @cLangCode, 'DSP') --'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 11 -- Lottable04
            GOTO Step_4_Fail
         END
      SET @dSearchLottable04 = ISNULL(rdt.rdtConvertToDate(@cSearchLottable04), 0) -- When blank, @dLottable04 = 0              -- ZG01

      -- Get SKU QTY
      SET @nQTY_Avail = 0
      SELECT TOP 1
         @cID = LLI.ID,
         @cLottable01 = LA.Lottable01,
         @cLottable02 = LA.Lottable02,
         @cLottable03 = LA.Lottable03,
         @dLottable04 = LA.Lottable04,
         @nQTY_Avail = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
      FROM dbo.LOTxLOCxID LLI(NOLOCK)
         INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LLI.LOC = @cFromLOC
         AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         AND LLI.ID = CASE WHEN @cFromID = '' THEN LLI.ID ELSE @cFromID END
         AND LA.Lottable01 = CASE WHEN @cSearchLottable01 = '' THEN LA.Lottable01 ELSE @cSearchLottable01 END
         AND LA.Lottable02 = CASE WHEN @cSearchLottable02 = '' THEN LA.Lottable02 ELSE @cSearchLottable02 END
         AND LA.Lottable03 = CASE WHEN @cSearchLottable03 = '' THEN LA.Lottable03 ELSE @cSearchLottable03 END
         -- NULL column cannot be compared, even if SET ANSI_NULLS OFF
         AND IsNULL( LA.Lottable04, 0) = CASE WHEN @dSearchLottable04 = 0 THEN IsNULL( LA.Lottable04, 0) ELSE @dSearchLottable04 END
      GROUP BY LLI.ID, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
      ORDER BY LLI.ID, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04

      IF @nQTY_Avail = 0 OR @nQTY_Avail IS NULL
      BEGIN
         SET @nErrNo = 62885
         SET @cErrMsg = rdt.rdtgetmessage( 62885, @cLangCode, 'DSP') --'No QTY to move'
         GOTO Step_4_Fail
      END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Avail = 0
         SET @nPQTY_Move  = 0
         SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
      END
      ELSE
      BEGIN
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prepare next screen var
      SET @nPQTY_Move = 0
      SET @nMQTY_Move = 0
      SET @cOutField01 = @cID
      SET @cOutField02 = @cLottable01
      SET @cOutField03 = @cLottable02
      SET @cOutField04 = @cLottable03
      SET @cOutField05 = rdt.rdtFormatDate( @dLottable04)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField08 = '' -- @cPUOM_Desc
         SET @cOutField09 = '' -- @nPQTY_Avail
         SET @cOutField10 = '' -- @nPQTY_Move
         SET @cFieldAttr10 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField08 = @cPUOM_Desc
         SET @cOutField09 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField10 = @nPQTY_Move
      END
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField13 = CASE WHEN ISNULL(@cQTY,'') = '' THEN '' ELSE @cQTY END  -- @nPQTY_Move  --(cc01)

      -- Goto next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      --bug fix - to reset the input value scanned
      SET @cInField10 = ''
      SET @cInField13 = ''
      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- SKU desc 1
      SET @cOutField05 = '' -- SKU desc 2

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

      -- Go back to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cFieldAttr05 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr11 = ''

      -- Disable lottable field
      IF @cLottableLabel01 = '' SET @cFieldAttr05 = 'O' ELSE SET @cOutField05 = ISNULL(@cSearchLottable01, '') -- SOS#81879
      IF @cLottableLabel02 = '' SET @cFieldAttr07 = 'O' ELSE SET @cOutField07 = ISNULL(@cSearchLottable02, '') -- SOS#81879
      IF @cLottableLabel03 = '' SET @cFieldAttr09 = 'O' ELSE SET @cOutField09 = ISNULL(@cSearchLottable03, '') -- SOS#81879
      IF @cLottableLabel04 = '' SET @cFieldAttr11 = 'O' ELSE SET @cOutField11 = ISNULL(@cSearchLottable04, '') -- SOS#81879

      -- Remain in current screen
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField04 = CASE WHEN @cLottableLabel01 = '' THEN 'Lottable01:' ELSE @cLottableLabel01 END
      SET @cOutField06 = CASE WHEN @cLottableLabel02 = '' THEN 'Lottable02:' ELSE @cLottableLabel02 END
      SET @cOutField08 = CASE WHEN @cLottableLabel03 = '' THEN 'Lottable03:' ELSE @cLottableLabel03 END
      SET @cOutField10 = CASE WHEN @cLottableLabel04 = '' THEN 'Lottable04:' ELSE @cLottableLabel04 END
   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 1044. QTY screen
   ID              (field01)
   Lottable01      (field02)
   Lottable02      (field03)
   Lottable03      (field04)
   Lottable04      (field05)
   UOM             (field08, field11)
   QTY AVL         (field09, field12)
   QTY MV          (field10, field13, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cPQTY NVARCHAR( 5)
      DECLARE @cMQTY NVARCHAR( 5)

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
      IF @cPUOM_Desc = ''
         SET @cPQTY = ''
      ELSE
         SET @cPQTY = IsNULL( @cInField10, '')
         SET @cMQTY = IsNULL( @cInField13, '')

      -- Retain the key-in value
      IF @cPUOM_Desc = ''
         SET @cOutField10 = @cInField10 -- Pref QTY
      ELSE
         SET @cOutField10 = ''
         SET @cOutField13 = @cInField13 -- Master QTY

      -- Blank to iterate lottables
      IF @cPQTY = '' AND @cMQTY = ''
      BEGIN
         DECLARE @cNextID NVARCHAR( 18)
         DECLARE @cNextLottable01 NVARCHAR( 18)
         DECLARE @cNextLottable02 NVARCHAR( 18)
         DECLARE @cNextLottable03 NVARCHAR( 18)
         DECLARE @dNextLottable04 DATETIME
         DECLARE @nNextQTY_Avail INT

         SET @dSearchLottable04 = ISNULL(rdt.rdtConvertToDate(@cSearchLottable04), 0)          -- ZG01

         -- Get SKU QTY
         SELECT TOP 1
            @cNextID = LLI.ID,
            @cNextLottable01 = LA.Lottable01,
            @cNextLottable02 = LA.Lottable02,
            @cNextLottable03 = LA.Lottable03,
            @dNextLottable04 = LA.Lottable04,
            @nNextQTY_Avail = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
         FROM dbo.LOTxLOCxID LLI(NOLOCK)
            INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LLI.LOC = @cFromLOC
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
            AND LLI.ID = CASE WHEN @cFromID = '' THEN LLI.ID ELSE @cFromID END
            AND LA.Lottable01 = CASE WHEN @cSearchLottable01 = '' THEN LA.Lottable01 ELSE @cSearchLottable01 END
            AND LA.Lottable02 = CASE WHEN @cSearchLottable02 = '' THEN LA.Lottable02 ELSE @cSearchLottable02 END
            AND LA.Lottable03 = CASE WHEN @cSearchLottable03 = '' THEN LA.Lottable03 ELSE @cSearchLottable03 END
            -- NULL column cannot be compared, even if SET ANSI_NULLS OFF
            AND IsNULL( LA.Lottable04, 0) = CASE WHEN @dSearchLottable04 = 0 THEN IsNULL( LA.Lottable04, 0) ELSE @dSearchLottable04 END
            AND (LLI.ID + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL( LA.Lottable04, @dZero), 120)) >
                (@cID + @cLottable01 + @cLottable02 + @cLottable03 + CONVERT( NVARCHAR( 10), IsNULL( @dLottable04, @dZero), 120))
         GROUP BY LLI.ID, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
         ORDER BY LLI.ID, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04

         -- Validate if any result
         IF IsNULL( @nNextQTY_Avail, 0) = 0
         BEGIN
            SET @nErrNo = 62886
            SET @cErrMsg = rdt.rdtgetmessage( 62886, @cLangCode, 'DSP') --'No record'
            GOTO Step_5_Fail
         END

         -- Set next record values
         SET @cID = @cNextID
         SET @cLottable01 = @cNextLottable01
         SET @cLottable02 = @cNextLottable02
         SET @cLottable03 = @cNextLottable03
         SET @dLottable04 = @dNextLottable04
         SET @nQTY_Avail = @nNextQTY_Avail

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY_Avail = 0
            SET @nPQTY_Move  = 0
            SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
         END
         ELSE
         BEGIN
            SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         END

         -- Prepare next screen var
         SET @nPQTY_Move = 0
         SET @nMQTY_Move = 0
         SET @cOutField01 = @cID
         SET @cOutField02 = @cLottable01
         SET @cOutField03 = @cLottable02
         SET @cOutField04 = @cLottable03
         SET @cOutField05 = rdt.rdtFormatDate( @dLottable04)
         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField08 = '' -- @cPUOM_Desc
            SET @cOutField09 = '' -- @nPQTY_Avail
            SET @cOutField10 = '' -- @nPQTY_Move
            SET @cFieldAttr10 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField08 = @cPUOM_Desc
            SET @cOutField09 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
            SET @cOutField10 = '' -- @nPQTY_Move
         END
         SET @cOutField11 = @cMUOM_Desc
         SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
         SET @cOutField13 = '' -- @nMQTY_Move

         -- Remain in current screen
         -- SET @nScn = @nScn + 1
         -- SET @nStep = @nStep + 1

         GOTO Quit
      END

      -- Validate PQTY
      IF @cPQTY = '' SET @cPQTY = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 62887
         SET @cErrMsg = rdt.rdtgetmessage( 62887, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY
         GOTO Step_5_Fail
      END

      -- Validate MQTY
      IF @cMQTY  = '' SET @cMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 62888
         SET @cErrMsg = rdt.rdtgetmessage( 62888, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- MQTY
         GOTO Step_5_Fail
      END

      -- Calc total QTY in master UOM
      SET @nPQTY_Move = CAST( @cPQTY AS INT)
      SET @nMQTY_Move = CAST( @cMQTY AS INT)
      SET @nQTY_Move = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY_Move = @nQTY_Move + @nMQTY_Move

      -- Validate QTY
      IF @nQTY_Move = 0
      BEGIN
         SET @nErrNo = 62889
         SET @cErrMsg = rdt.rdtgetmessage( 62889, @cLangCode, 'DSP') --'QTY needed'
         GOTO Step_5_Fail
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY_Move > @nQTY_Avail
      BEGIN
         SET @nErrNo = 62890
         SET @cErrMsg = rdt.rdtgetmessage( 62890, @cLangCode, 'DSP') --'QTYAVL NotEnuf'
         GOTO Step_5_Fail
      END

      -- Prep ToID screen var
      SET @cFromID = @cID
      SET @cToID = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cFieldAttr07 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField08 = @cMUOM_Desc
      SET @cOutField09 = CAST( @nMQTY_Move AS NVARCHAR( 5))
      SET @cOutField10 = '' -- @cToID

      -- Go to ToID screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Init next screen var
      SET @cSearchLottable01 = ''
      SET @cSearchLottable02 = ''
      SET @cSearchLottable03 = ''
      SET @cSearchLottable04 = ''

      -- Disable lottable field
      SET @cFieldAttr05 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr11 = ''
      IF @cLottableLabel01 = '' SET @cFieldAttr05 = 'O'
      IF @cLottableLabel02 = '' SET @cFieldAttr07 = 'O'
      IF @cLottableLabel03 = '' SET @cFieldAttr09 = 'O'
      IF @cLottableLabel04 = '' SET @cFieldAttr11 = 'O'

      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField04 = CASE WHEN @cLottableLabel01 = '' THEN 'Lottable01:' ELSE @cLottableLabel01 END
      SET @cOutField05 = '' -- @cSearchLottable01
      SET @cOutField06 = CASE WHEN @cLottableLabel02 = '' THEN 'Lottable02:' ELSE @cLottableLabel02 END
      SET @cOutField07 = '' -- @cSearchLottable02
      SET @cOutField08 = CASE WHEN @cLottableLabel03 = '' THEN 'Lottable03:' ELSE @cLottableLabel03 END
      SET @cOutField09 = '' -- @cSearchLottable03
      SET @cOutField10 = CASE WHEN @cLottableLabel04 = '' THEN 'Lottable04:' ELSE @cLottableLabel04 END
      SET @cOutField11 = '' -- @cSearchLottable04

      -- Go to QTY screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
      SET @cFieldAttr10 = ''

      IF @cPUOM_Desc = ''
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition
         -- Disable pref QTY field
         SET @cFieldAttr10 = 'O'

END
GOTO Quit


/********************************************************************************
Step 6. Scn = 1045. ToID
   FromLOC (field01)
   FromID  (field02)
   SKU     (field03)
   Desc1   (field04)
   Desc2   (field05)
   UOM     (field06, field08)
   QTY MV  (field07, field09)
   ToID    (field10, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField10

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

      -- Prep ToLOC screen var
      --SET @cToLOC = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cFieldAttr07 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField08 = @cMUOM_Desc
      SET @cOutField09 = CAST( @nMQTY_Move AS NVARCHAR( 5))
      SET @cOutField10 = @cToID
      SET @cOutField11 = @cToLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
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

      -- Prepare next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = @cLottable01
      SET @cOutField03 = @cLottable02
      SET @cOutField04 = @cLottable03
      SET @cOutField05 = rdt.rdtFormatDate( @dLottable04)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField08 = '' -- @cPUOM_Desc
         SET @cOutField09 = '' -- @nPQTY_Avail
         SET @cOutField10 = '' -- @nPQTY_Move
         SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
         SET @cFieldAttr10 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField08 = @cPUOM_Desc
         SET @cOutField09 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField10 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField13 = CAST( @nMQTY_Move AS NVARCHAR( 5))

      -- Go to QTY screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 7. Scn = 1046. ToLOC
   FromLOC (field01)
   FromID  (field02)
   SKU     (field03)
   Desc1   (field04)
   Desc2   (field05)
   UOM     (field06, field08)
   QTY MV  (field07, field09)
   ToID    (field10)
   ToLOC   (field11, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField11
      SET @cLocNeedCheck = @cInField11

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
      IF @cToLOC = '' OR @cToLOC IS NULL
      BEGIN
         SET @nErrNo = 62891
         SET @cErrMsg = rdt.rdtgetmessage( 62891, @cLangCode, 'DSP') --'ToLOC needed'
         GOTO Step_7_Fail
      END

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '515ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_515ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cLocNeedCheck OUTPUT,
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
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_7_Fail
            
            SET @cToLOC = @cLocNeedCheck
         END
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62892
         SET @cErrMsg = rdt.rdtgetmessage( 62892, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_7_Fail
      END

      -- Validate LOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 62893
            SET @cErrMsg = rdt.rdtgetmessage( 62893, @cLangCode, 'DSP') --'Diff facility'
            GOTO Step_7_Fail
         END

      DECLARE @nQTY_Bal INT
      DECLARE @nQTY_LLI INT
      DECLARE @nQTY     INT
      DECLARE @cLOT     NVARCHAR( 10)
      SET @dSearchLottable04 = ISNULL(rdt.rdtConvertToDate(@cSearchLottable04), 0)             -- ZG01

      -- Prepare cursor
      DECLARE @curLLI CURSOR
      SET @curLLI = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT
            LLI.LOT,
            LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)
         FROM dbo.LOTxLOCxID LLI(NOLOCK)
            INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LLI.LOC = @cFromLOC
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
            AND LLI.ID = @cID
            AND LA.Lottable01 = @cLottable01
            AND LA.Lottable02 = @cLottable02
            AND LA.Lottable03 = @cLottable03
            -- NULL column cannot be compared, even if SET ANSI_NULLS OFF
--            AND LA.Lottable04 = @dLottable04
            AND IsNULL( LA.Lottable04, 0) = CASE WHEN @dSearchLottable04 = 0 THEN IsNULL( LA.Lottable04, 0) ELSE @dSearchLottable04 END
         ORDER BY LLI.ID, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
      OPEN @curLLI

      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_Move_SKU_Lottable -- For rollback or commit only our own transaction

      -- Loop LOTxLOTxID
      FETCH NEXT FROM @curLLI INTO @cLOT, @nQTY_LLI
      SET @nQTY_Bal = @nQTY_Move
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Calc LLI.QTY to take
         IF @nQTY_LLI > @nQTY_Bal
            SET @nQTY = @nQTY_Bal -- LLI had enuf QTY, so charge all the balance into this LLI
         ELSE
            SET @nQTY = @nQTY_LLI -- LLI not enuf QTY, take all QTY avail of this LLI

         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode,
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
            @cSourceType = 'rdtfnc_Move_SKU_Lottable',
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility,
            @cFromLOC    = @cFromLOC,
            @cToLOC      = @cToLOC,
            @cFromID     = @cID,         -- NULL means not filter by ID. Blank is a valid ID
            @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
            @cSKU        = @cSKU,
            @nQTY        = @nQTY,
            @cFromLOT    = @cLOT

         IF @nErrNo <> 0
         BEGIN
            CLOSE @curLLI
            DEALLOCATE @curLLI
            GOTO RollBackTran
         END
         ELSE
         BEGIN
            -- EventLog
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
              @cLot          = @cLOT,
              @nStep         = @nStep
         END

         SET @nQTY_Bal = @nQTY_Bal - @nQTY  -- Reduce balance
         IF @nQTY_Bal <= 0
            BREAK

         FETCH NEXT FROM @curLLI INTO @cLOT, @nQTY_LLI
      END

      -- Still have balance, means no LLI changed
      IF @nQTY_Bal <> 0
      BEGIN
         SET @nErrNo = 62894
         SET @cErrMsg = rdt.rdtgetmessage( 62894, @cLangCode, 'DSP') --'Inv changed'
         CLOSE @curLLI
         DEALLOCATE @curLLI
         GOTO RollBackTran
      END
      COMMIT TRAN rdtfnc_Move_SKU_Lottable -- Only commit change made in here
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

      SET @cOutField01 = @cToLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
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

      -- Prepare ToID screen var
      SET @cToID = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
  SET @cOutField04 = SUBSTRING( @cSKUDescR, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescR, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cFieldAttr07 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField08 = @cMUOM_Desc
      SET @cOutField09 = CAST( @nMQTY_Move AS NVARCHAR( 5))
      SET @cOutField10 = '' -- ToID

      -- Go to ToID screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   RollBackTran:
   BEGIN
      ROLLBACK TRAN rdtfnc_Move_SKU_Lottable
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN
   END

   Step_7_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField13 = '' -- @cToLOC
   END
END
GOTO Quit


/********************************************************************************
Step 8. scn = 1047. Message screen
   Message
********************************************************************************/
Step_8:
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

   IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cBackToScreen, ',') WHERE TRIM( value) = '3') -- SKU screen 
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' --@cSKU

      -- Go to SKU screen
      SET @nScn  = @nScn - 5
      SET @nStep = @nStep - 5
   END
   ELSE IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cBackToScreen, ',') WHERE TRIM( value) = '2') -- From ID screen
   BEGIN
      -- Prep next screen var
      SET @cFromID = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' --@cFromID

      -- Go to From ID screen
      SET @nScn  = @nScn - 6
      SET @nStep = @nStep - 6
   END
   ELSE
   BEGIN
      -- Go back to 1st screen
      SET @nScn  = @nScn - 7
      SET @nStep = @nStep - 7

      -- Prep next screen var
      SET @cFromLOC = ''
      SET @cOutField01 = '' -- FromLOC
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
      IF (@cFromID <>'')
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
            @cSKU         OUTPUT,
            @nErrNo       OUTPUT,
            @cErrMsg      OUTPUT,
            'LOTXLOCXID.ID',    -- DocType
            @cFromID
      END
      ELSE
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
            @cErrMsg  OUTPUT,
             'LOTXLOCXID.LOC',    -- DocType
            @cFromLOC
      END

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cSKU

      -- Go to SKU QTY screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep

      -- To indicate sku has been successfully selected
      SET @nFromScn = 3570
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = ''   -- SKU

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

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      -- UserName  = @cUserName,-- (Vicky06)

      V_ID       = @cID,
      V_SKUDescr = @cSKUDescr,
      V_UOM      = @cPUOM,
      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_LottableLabel01 = @cLottableLabel01,
      V_LottableLabel02 = @cLottableLabel02,
      V_LottableLabel03 = @cLottableLabel03,
      V_LottableLabel04 = @cLottableLabel04,

      V_String1  = @cFromLOC,
      V_String2  = @cFromID,
      V_String3  = @cSKU,
      V_String4  = @cSearchLottable01,
      V_String5  = @cSearchLottable02,
      V_String6  = @cSearchLottable03,
      V_String7  = @cSearchLottable04,
      V_String8  = @cPUOM_Desc,
      V_String9  = @cMUOM_Desc,
      V_String10 = @cBackToScreen,
      V_String17 = @cToLOC,
      V_String18 = @cToID,
      V_String19 = @cLottable01_Code, -- SOS#81879
      V_String20 = @cLottable02_Code, -- SOS#81879
      V_String21 = @cLottable03_Code, -- SOS#81879
      V_String22 = @cLottable04_Code, -- SOS#81879
      V_String23 = @cMultiSKUBarcode, -- (yeekung01)
      V_String24 = @cDecodeSP,        -- (cc01)
      V_String25 = @cDecodeLabelNo,   -- (cc01)
      V_String26 = @cQTY,             -- (cc01)

      V_Integer1 = @nQTY_Avail,
      V_Integer2 = @nPQTY_Avail,
      V_Integer3 = @nMQTY_Avail,
      V_Integer4 = @nQTY_Move,
      V_Integer5 = @nPQTY_Move,
      V_Integer6 = @nMQTY_Move,

      V_PUOM_Div = @nPUOM_Div,
      V_FromStep = @nFromStep, --(yeekung01)
      V_FromScn  = @nFromScn,  --(yeekung01)

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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Replenishment                                */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: RDT Replenishment                                           */
/*                                                                      */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2015-06-15 1.0  ChewKP   SOS#342435 Created                          */
/* 2015-10-02 1.1  ChewKP   SOS#353787 Add StorerConfig WaveDPPConfirm  */
/*                          (ChewKP01)                                  */
/* 2016-08-17 1.2  Leong    IN00121088 - Integer conversion.            */
/* 2016-09-30 1.3  Ung      Performance tuning                          */   
/* 2016-11-22 1.4  ChewKP   WMS-602 - Bug Fix (ChewKP02)                */
/* 2017-08-04 1.5  ChewKP   WMS-2428 - Add Carton Count Screen(ChewKP03)*/
/* 2018-01-24 1.6  ChewKP   WMS-3807 - ExtendedInfo Fix (ChewKP04)      */
/* 2018-10-01 1.7  Gan      Performance                                 */
/* 2019-10-24 1.8  James    WMS-10875 Allow overwrite ToLoc with        */
/*                          config (james01)                            */
/* 2020-09-24 1.9  James    WMS-15296 Allow new replentype (james02)    */
/* 2021-02-04 2.0  James    WMS-16297 Fix PAZone cannot display more    */
/*                          than 1 page (james03)                       */
/* 2021-02-26 2.2  James    WMS-16020 Bug fix on case scanning (james04)*/
/* 							    Add ExtendedInfoSP @ step 5 					   */
/* 2022-07-22 2.3  James    WMS-20209 Add DecodeSP (james05)            */
/*                          Add flow thru sku screen                    */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_Replenishment] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 nvarchar max
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cChkFacility NVARCHAR( 5),
   @nSKUCnt      INT,
   @nRowCount    INT,
   @cXML         NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc

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

   @cSKU        NVARCHAR( 20),
   @cDescr      NVARCHAR( 40),
   @cPUOM       NVARCHAR( 1), -- Prefer UOM
   @cPUOM_Desc  NCHAR( 5),
   @cMUOM_Desc  NCHAR( 5),
   @cReplenKey  NVARCHAR( 10),
   @cLot        NVARCHAR( 10),
   @cFromLoc    NVARCHAR( 10),
   @cToLoc      NVARCHAR( 10),
   @cFromID     NVARCHAR( 18),
   @cToID       NVARCHAR( 18),
   @cActToLOC   NVARCHAR( 10),

   @nPUOM_Div   INT, -- UOM divider
   @nQTY_Avail  INT, -- QTY available in LOTxLOCXID
   @nQTY        INT, -- Replenishment.QTY
   @nPQTY       INT, -- Preferred UOM QTY
   @nMQTY       INT, -- Master unit QTY
   @nActQTY     INT, -- Actual replenish QTY
   @nActMQTY    INT, -- Actual keyed in master QTY
   @nActPQTY    INT, -- Actual keyed in prefered QTY

   @nLOCCnt     INT, -- # LOC Count
   @nIDCnt      INT, -- # ID Count

   @cUserName   NVARCHAR(18),
   @cDisplayQtyAvailable NVARCHAR(1),

   @cActPQTY    NVARCHAR( 5),
   @cActMQTY    NVARCHAR( 5),
   @cWaveKey    NVARCHAR(10),
   @cPutAwayZone   NVARCHAR( 10),
   @cPutAwayZone01 NVARCHAR( 10),
   @cPutAwayZone02 NVARCHAR( 10),
   @cPutAwayZone03 NVARCHAR( 10),
   @cPutAwayZone04 NVARCHAR( 10),
   @cPutAwayZone05 NVARCHAR( 10),
   @nLoop          INT,
   @cSuggFromLoc   NVARCHAR(10),
   @cSuggFromID    NVARCHAR(18),
   @nZoneCount     INT,
   @cSuggSKU       NVARCHAR(20),
   @cSuggToLOC     NVARCHAR(10),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,
   @dLottable14    DATETIME,
   @dLottable15    DATETIME,
   @cLabelNo       NVARCHAR(20),
   @cDecodeLabelNo NVARCHAR(20),
   @nUCCQTY        INT,
   @b_success      INT,
   @cUCC           NVARCHAR(20),
   @cReplenishmentKey NVARCHAR(10),
   @cExtendedUpdateSP NVARCHAR(30),
   @cExtendedValidateSP NVARCHAR(30),
   @cExtendedInfoSP     NVARCHAR(30),
   @cSQL                NVARCHAR(1000),
   @cSQLParam           NVARCHAR(1000),
   @cOutInfo01          NVARCHAR(60),
   @nQtyMoved           INT,
   @nSKUValidated       INT,
   @cOption             NVARCHAR(1),
   @cLottableCode       NVARCHAR( 30),
   @nMorePage           INT,
   @nRowRef             INT,
   @cDefaultToLoc       NVARCHAR(1),
   @cDefaultFromID      NVARCHAR(18),
   @nTotalTaskCount     INT,
   @nCountScanTask      INT,
   @cReplenBySKU        NVARCHAR(1),
   @cNotDisplayQty      NVARCHAR(1),
   @nReplenCount        INT,
   @cSwapLoc            NVARCHAR(1),
   @cReplenType         NVARCHAR(10),
   @cLocationType       NVARCHAR(10),
   @cNotConfirmDPPReplen NVARCHAR(1), -- (ChewKP01)
   @cLastPAZone         NVARCHAR( 10), -- (ChewKP02) 
   @cCountFail          NVARCHAR(1),  -- (ChewKP03) 
   @cReplenByPallet     NVARCHAR(5), -- (ChewKP03) 
   @cTTLCartonCount     NVARCHAR(5), -- (ChewKP03) 
   @cPalletUOM          NVARCHAR(5), -- (ChewKP03) 
   @cAllowOverWriteToLoc   NVARCHAR( 1), -- (james01)
   @nTranCount          INT,             -- (james01)
   @cRPLKey             NVARCHAR( 10),   -- (james01)
   @cRPLLot             NVARCHAR( 10),   -- (james01)
   @cRPLId              NVARCHAR( 18),   -- (james01)
   @cRPLSKU             NVARCHAR( 20),   -- (james01)
   @nRPLQty             INT,             -- (james01)
   @cPickDetailKey      NVARCHAR( 10),   -- (james01)
   @cSuggLocLoseId      NVARCHAR( 1),    -- (james01)        
   @cToLocLoseId        NVARCHAR( 1),    -- (james01)        
   @cReplenNo           NVARCHAR( 5),    -- (james01)        
   @cDecodeSP           NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cFlowThruStep5      NVARCHAR( 1),
   @nSKUOnPalletCnt     INT = 0,
   
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),

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


DECLARE @c_TraceFlag CHAR(1)
SET @c_TraceFlag = '0'

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
   @cDescr      = V_SKUDescr,
   @cPUOM       = V_UOM,
   @cLottable01 = V_Lottable01,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   @cLOT        = V_LOt,
   @cFromLoc    = V_LOC,
   @cFromID     = V_ID,

   @cAllowOverWriteToLoc = V_String1,
   @cActToLOC   = V_String2,
   @cMUOM_Desc  = V_String3,
   @cPUOM_Desc  = V_String4,
   @cExtendedInfoSP   = V_String5,
   @cDecodeSP   = V_String6,   
   @cFlowThruStep5 = V_String7,
   @nPUOM_Div   = V_PUOM_Div,
   @nMQTY       = V_MQTY,
   @nPQTY       = V_PQTY,
   @cWaveKey    = V_String12,
   @cSuggFromLoc = V_String13,
   @cSuggFromID  = V_String14,
   @cSuggSKU     = V_String15,
   @cSuggToLoc   = V_String16,
   --@nQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String17, 5), 0) = 1 THEN LEFT( V_String17, 5) ELSE 0 END,
   @cReplenishmentKey = V_String18,
   @cExtendedUpdateSP = V_String19,
   @cExtendedValidateSP = V_String20,
   @cOutInfo01          = V_String21,
   --@nSKUValidated       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String22, 5), 0) = 1 THEN LEFT( V_String22, 5) ELSE 0 END,
   @cDecodeLabelNo      = V_String23,
   @cDefaultToLoc       = V_String24,
   @cDefaultFromID      = V_String25,
   --@nTotalTaskCount     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String26, 5), 0) = 1 THEN LEFT( V_String26, 5) ELSE 0 END, -- IN00121088
   --@nCountScanTask      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String27, 5), 0) = 1 THEN LEFT( V_String27, 5) ELSE 0 END, -- IN00121088
   @cReplenBySKU        = V_String28,
   @cNotDisplayQty      = V_String29,
   @cSwapLoc            = V_String30,
   @cReplenType         = V_String31,
   @cNotConfirmDPPReplen = V_String32,
   @cPutAwayZone01      = V_String33, -- (ChewKP02)
   @cPutAwayZone02      = V_String34, -- (ChewKP02)
   @cPutAwayZone03      = V_String35, -- (ChewKP02)
   @cPutAwayZone04      = V_String36, -- (ChewKP02)
   @cPutAwayZone05      = V_String37, -- (ChewKP02)
   @cLastPAZone         = V_String38, -- (ChewKP02) 
   @cCountFail          = V_String39, -- (ChewKP03) 
   @cReplenByPallet     = V_String40, -- (ChewKP03)
   
   @nActMQTY            = V_Integer1,
   @nActPQTY            = V_Integer2,
   @nActQty             = V_Integer3,
   @nQTY                = V_Integer4,
   @nSKUValidated       = V_Integer5,
   @nTotalTaskCount     = V_Integer6,
   @nCountScanTask      = V_Integer7,


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
IF @nFunc = 895 -- Replenish (1 stage)
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 895
   IF @nStep = 1 GOTO Step_1   -- Scn = 4210. WaveKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 4211. PutawayZone
   IF @nStep = 3 GOTO Step_3   -- Scn = 4212. From Loc
   IF @nStep = 4 GOTO Step_4   -- Scn = 4213. From ID
   IF @nStep = 5 GOTO Step_5   -- Scn = 4214. SKU , Qty
   IF @nStep = 6 GOTO Step_6   -- Scn = 4215. To LOC
   IF @nStep = 7 GOTO Step_7   -- Scn = 4216. Messsage
   IF @nStep = 8 GOTO Step_8   -- Scn = 4217. Short Pick
   IF @nStep = 9 GOTO Step_9   -- Scn = 4218. Exit Without Confirm
   IF @nStep = 10 GOTO Step_10   -- Scn = 4219. Pallet Carton Count 
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 895)
********************************************************************************/
Step_0:
BEGIN



   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
   BEGIN
        SET @cExtendedUpdateSP = ''
   END


   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
   BEGIN
        SET @cExtendedValidateSP = ''
   END

   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'DefaultToLoc', @cStorerKey)
   IF @cDefaultToLoc = '0'
      SET @cDefaultToLoc = ''

   SET @cDefaultFromID = rdt.RDTGetConfig( @nFunc, 'DefaultFromID', @cStorerKey)
   IF @cDefaultFromID = '0'
      SET @cDefaultFromID = ''


   SET @cReplenBySKU = rdt.RDTGetConfig( @nFunc, 'ReplenBySKU', @cStorerKey)
   IF @cReplenBySKU = '0'
      SET @cReplenBySKU = ''

   SET @cNotDisplayQty = rdt.RDTGetConfig( @nFunc, 'NotDisplayQty', @cStorerKey)
   IF @cNotDisplayQty = '0'
      SET @cNotDisplayQty = ''


   SET @cSwapLoc = rdt.RDTGetConfig( @nFunc, 'SwapLoc', @cStorerKey)
   IF @cSwapLoc = '0'
      SET @cSwapLoc = ''

   -- (ChewKP01)
   SET @cNotConfirmDPPReplen = rdt.RDTGetConfig( @nFunc, 'NotConfirmDPPReplen', @cStorerKey)
   IF @cNotConfirmDPPReplen = '0'
      SET @cNotConfirmDPPReplen = ''

   -- (ChewKP03)
   SET @cReplenByPallet = rdt.RDTGetConfig( @nFunc, 'ReplenByPallet', @cStorerKey)
   IF @cReplenByPallet = '0'
      SET @cReplenByPallet = ''

   -- (james01)
   SET @cAllowOverWriteToLoc = rdt.RDTGetConfig( @nFunc, 'AllowOverWriteToLoc', @cStorerKey)

   -- (james05)
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   SET @cFlowThruStep5 = rdt.RDTGetConfig( @nFunc, 'FlowThruStep5', @cStorerKey)

   -- Set the entry point
   SET @nScn = 4210 --1225
   SET @nStep = 1

   -- Init var
   SET @nPQTY = 0
   SET @nActPQTY = 0
   SET @cCountFail = '0' -- (ChewKP03) 

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

    --  EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep


   -- Prep next screen var
   SET @cFromLOC = ''
   SET @cFromID = ''
   SET @cOutField01 = '' -- FromLOC
   SET @cOutField02 = '' -- FromLOC


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
Step 1. Scn = 4210.
   WaveKey         (field01, input)


********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      SET @cWaveKey = ISNULL(RTRIM(@cInField01),'')
      SET @cReplenType  = ISNULL(RTRIM(@cInField02),'')

      IF @cWaveKey = ''
      BEGIN
         SET @nErrNo = 93651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WaveKeyReq
         GOTO Step_1_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM Wave WITH (NOLOCK)
                      WHERE WaveKey = @cWaveKey )
      BEGIN
         SET @nErrNo = 93652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidWaveKey
         GOTO Step_1_Fail
      END

      IF @cReplenType = ''
      BEGIN
         SET @nErrNo = 93689
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionReq
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail
      END

      IF @cReplenType Not IN ( '1','2','3','4') -- (james02)
      BEGIN
         SET @nErrNo = 93690
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail
      END


      -- Clear the output first
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''


      -- Clear the variable first
      SET @nLoop = 0
      SET @cPutAwayZone = ''
      SET @cPutAwayZone01 = ''
      SET @cPutAwayZone02 = ''
      SET @cPutAwayZone03 = ''
      SET @cPutAwayZone04 = ''
      SET @cPutAwayZone05 = ''
      SET @cLastPAZone    = ''
      

      -- (ChewKP01)
      IF @cNotConfirmDPPReplen = '1'
      BEGIN
         DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT L.PutawayZone
         FROM dbo.Replenishment RP WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (RP.FROMLOC = L.LOC)
         WHERE RP.StorerKey = @cStorerKey
            AND RP.Remark  = 'NOTVERIFY'
            AND RP.WaveKey = @cWaveKey
            AND L.Facility = @cFacility
         ORDER BY L.PutawayZone
      END
      ELSE
      BEGIN
         DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT L.PutawayZone
         FROM dbo.Replenishment RP WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (RP.FROMLOC = L.LOC)
         WHERE RP.StorerKey = @cStorerKey
            AND RP.Confirmed = 'N'
            AND RP.WaveKey = @cWaveKey
            AND L.Facility = @cFacility
         ORDER BY L.PutawayZone

      END
      OPEN curPutAwayZone
      FETCH NEXT FROM curPutAwayZone INTO @cPutAwayZone
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nLoop = 0
         BEGIN
            SET @cOutField07 = @cPutAwayZone
            SET @cPutAwayZone01 = @cPutAwayZone

         END
         IF @nLoop = 1
         BEGIN
            SET @cOutField08 = @cPutAwayZone
            SET @cPutAwayZone02 = @cPutAwayZone

         END
         IF @nLoop = 2
         BEGIN
            SET @cOutField09 = @cPutAwayZone
            SET @cPutAwayZone03 = @cPutAwayZone

         END
         IF @nLoop = 3
         BEGIN
            SET @cOutField10 = @cPutAwayZone
            SET @cPutAwayZone04 = @cPutAwayZone

         END
         IF @nLoop = 4
         BEGIN
            SET @cOutField11 = @cPutAwayZone
            SET @cPutAwayZone05 = @cPutAwayZone

         END

         SET @nLoop = @nLoop + 1
         SET @cLastPAZone = @cPutAwayZone
         IF @nLoop = 5 BREAK

         FETCH NEXT FROM curPutAwayZone INTO @cPutAwayZone
      END
      CLOSE curPutAwayZone
      DEALLOCATE curPutAwayZone

      -- If no task
      IF ISNULL(@cOutField07, '') = ''
      BEGIN
         SET @nErrNo = 93653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No more task'
         GOTO Step_1_Fail
      END



      -- GOTO Next Screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 1



   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
      -- Delete ReplenishmentLog When UserLogin
      DELETE FROM rdt.rdtReplenishmentLog
      WHERE AddWho = @cUserName

--    -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '9', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep

      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''



   END
   GOTO Quit

   STEP_1_FAIL:
   BEGIN

      -- Prepare Next Screen Variable
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = ''

   END
END
GOTO QUIT


/********************************************************************************
Step 2. Scn = 4211.
   All Zone        (field01, input)
   PutawayZone 1   (field02, input)
   PutawayZone 2   (field03, input)
   PutawayZone 3   (field04, input)
   PutawayZone 4   (field05, input)
   PutawayZone 5   (field06, input)

********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- If blank option selected, retrieve next 5 putawayzone
      IF ISNULL(@cInField01, '') = ''   -- All
      AND ISNULL(@cInField02, '') = ''   -- PutAwayZone01
      AND ISNULL(@cInField03, '') = ''   -- PutAwayZone02
      AND ISNULL(@cInField04, '') = ''   -- PutAwayZone03
      AND ISNULL(@cInField05, '') = ''   -- PutAwayZone04
      AND ISNULL(@cInField06, '') = ''   -- PutAwayZone05
      BEGIN
         GOTO Get_Next5PutAwayZone
      END

      -- If not '1' or blank
     IF (ISNULL(@cInField01, '') <> '' AND @cInField01 <> '1' )   -- All
      OR (ISNULL(@cInField02, '') <> '' AND @cInField02 <> '1' )   -- PutAwayZone01
      OR (ISNULL(@cInField03, '') <> '' AND @cInField03 <> '1' )   -- PutAwayZone02
      OR (ISNULL(@cInField04, '') <> '' AND @cInField04 <> '1' )   -- PutAwayZone03
      OR (ISNULL(@cInField05, '') <> '' AND @cInField05 <> '1' )   -- PutAwayZone04
      OR (ISNULL(@cInField06, '') <> '' AND @cInField06 <> '1' )   -- PutAwayZone05
      BEGIN
         SET @nErrNo = 93654
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_2_Fail
      END

      -- If non of the option selected
      IF @cInField01 <> '1'   -- All
      AND @cInField02 <> '1'   -- PutAwayZone01
      AND @cInField03 <> '1'   -- PutAwayZone02
      AND @cInField04 <> '1'   -- PutAwayZone03
      AND @cInField05 <> '1'   -- PutAwayZone04
      AND @cInField06 <> '1'   -- PutAwayZone05
      BEGIN
         SET @nErrNo = 93655
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Selection
         GOTO Step_2_Fail
      END

      -- If more than one option selected
      IF (@cInField01 = '1' AND (@cInField02 = '1' OR @cInField03 = '1' OR @cInField04 = '1' OR @cInField05 = '1' OR @cInField06 = '1'))
         OR (@cInField02 = '1' AND (@cInField01 = '1' OR @cInField03 = '1' OR @cInField04 = '1' OR @cInField05 = '1' OR @cInField06 = '1'))
         OR (@cInField03 = '1' AND (@cInField01 = '1' OR @cInField02 = '1' OR @cInField04 = '1' OR @cInField05 = '1' OR @cInField06 = '1'))
         OR (@cInField04 = '1' AND (@cInField01 = '1' OR @cInField02 = '1' OR @cInField03 = '1' OR @cInField05 = '1' OR @cInField06 = '1'))
         OR (@cInField05 = '1' AND (@cInField01 = '1' OR @cInField02 = '1' OR @cInField03 = '1' OR @cInField04 = '1' OR @cInField06 = '1'))
         OR (@cInField06 = '1' AND (@cInField01 = '1' OR @cInField02 = '1' OR @cInField03 = '1' OR @cInField04 = '1' OR @cInField05 = '1'))
      BEGIN
         SET @nErrNo = 93656
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Only1ZoneAllow
         GOTO Step_2_Fail
      END



      IF ISNULL(@cInField02, '') = '1'
         SET @cPutAwayZone = @cOutField07

      IF ISNULL(@cInField03, '') = '1'
         SET @cPutAwayZone = @cOutField08

      IF ISNULL(@cInField04, '') = '1'
         SET @cPutAwayZone = @cOutField09

      IF ISNULL(@cInField05, '') = '1'
         SET @cPutAwayZone = @cOutField10

      IF ISNULL(@cInField06, '') = '1'
         SET @cPutAwayZone = @cOutField11

      SELECT @cLocationType = Short
      FROM dbo.CodeLkup WITH (NOLOCK)
      WHERE Listname = 'RDTREPLEN'
      AND Code = @cReplenType
      AND StorerKey = @cStorerKey



      IF @cInField01 = '1'
      BEGIN


         -- Delete ReplenishmentLog When UserLogin
         DELETE FROM rdt.rdtReplenishmentLog
         WHERE AddWho = @cUserName

         IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog RL WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND WaveKey = @cWaveKey
                     AND Confirmed <> 'Y' )
         BEGIN
            SET @nErrNo = 93685
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ZoneInUse
            GOTO Step_2_Fail
         END

         IF @cNotConfirmDPPReplen = '1'
         BEGIN
            -- Insert into rdt.ReplenishmentLog
            INSERT INTO rdt.rdtReplenishmentLog (
             [ReplenishmentKey]      ,[ReplenishmentGroup]      ,[Storerkey]        ,[Sku]         ,[FromLoc]      ,[ToLoc]
            ,[Lot]             ,[Id]                      ,[Qty]              ,[QtyMoved]    ,[QtyInPickLoc] ,[Priority]
            ,[UOM]             ,[PackKey]                 ,[ArchiveCop]       ,[Confirmed]   ,[ReplenNo]     ,[Remark]
            ,[AddDate]         ,[AddWho]                  ,[EditDate]         ,[EditWho]     ,[RefNo]        ,[DropID]
            ,[LoadKey]         ,[Wavekey]                 ,[OriginalFromLoc]  ,[OriginalQty] ,[ToID] )
            SELECT
             RP.[ReplenishmentKey]      ,RP.[ReplenishmentGroup]      ,RP.[Storerkey]        ,RP.[Sku]         ,RP.[FromLoc]      ,RP.[ToLoc]
            ,RP.[Lot]             ,RP.[Id]                            ,RP.[Qty]              ,RP.[QtyMoved]    ,RP.[QtyInPickLoc] ,RP.[Priority]
            ,RP.[UOM]             ,RP.[PackKey]                       ,RP.[ArchiveCop]       ,RP.[Confirmed]   ,RP.[ReplenNo]     ,RP.[Remark]
            ,GetDATE()            ,(suser_sname())                    ,GetDate()             ,(suser_sname())  ,RP.[RefNo]        ,RP.[DropID]
            ,RP.[LoadKey]         ,RP.[Wavekey]                       ,RP.[OriginalFromLoc]  ,RP.[OriginalQty] ,RP.[ToID]
            FROM dbo.Replenishment RP WITH (NOLOCK)
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.ToLoc
            WHERE RP.WaveKey = @cWaveKey
            AND RP.Remark  = 'NOTVERIFY'
            AND Loc.LocationType = CASE WHEN @cReplenType = '1' THEN Loc.LocationType ELSE @cLocationType END
            AND NOT EXISTS( SELECT 1 FROM rdt.rdtReplenishmentLog RR WITH (NOLOCK)
                            WHERE RR.ReplenishmentKey = RP.ReplenishmentKey  )
         END
         ELSE
         BEGIN
            -- Insert into rdt.ReplenishmentLog
            INSERT INTO rdt.rdtReplenishmentLog (
             [ReplenishmentKey]      ,[ReplenishmentGroup]      ,[Storerkey]        ,[Sku]         ,[FromLoc]      ,[ToLoc]
            ,[Lot]             ,[Id]                      ,[Qty]              ,[QtyMoved]    ,[QtyInPickLoc] ,[Priority]
            ,[UOM]             ,[PackKey]                 ,[ArchiveCop]       ,[Confirmed]   ,[ReplenNo]     ,[Remark]
            ,[AddDate]         ,[AddWho]                  ,[EditDate]         ,[EditWho]     ,[RefNo]        ,[DropID]
            ,[LoadKey]         ,[Wavekey]                 ,[OriginalFromLoc]  ,[OriginalQty] ,[ToID] )
            SELECT
             RP.[ReplenishmentKey]      ,RP.[ReplenishmentGroup]      ,RP.[Storerkey]        ,RP.[Sku]         ,RP.[FromLoc]      ,RP.[ToLoc]
            ,RP.[Lot]             ,RP.[Id]                            ,RP.[Qty]              ,RP.[QtyMoved]    ,RP.[QtyInPickLoc] ,RP.[Priority]
            ,RP.[UOM]             ,RP.[PackKey]                       ,RP.[ArchiveCop]       ,RP.[Confirmed]   ,RP.[ReplenNo]     ,RP.[Remark]
            ,GetDATE()            ,(suser_sname())                    ,GetDate()             ,(suser_sname())  ,RP.[RefNo]        ,RP.[DropID]
            ,RP.[LoadKey]         ,RP.[Wavekey]                       ,RP.[OriginalFromLoc]  ,RP.[OriginalQty] ,RP.[ToID]
            FROM dbo.Replenishment RP WITH (NOLOCK)
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.ToLoc
            WHERE RP.WaveKey = @cWaveKey
            AND RP.Confirmed = 'N'
            AND Loc.LocationType = CASE WHEN @cReplenType = '1' THEN Loc.LocationType ELSE @cLocationType END
            AND NOT EXISTS( SELECT 1 FROM rdt.rdtReplenishmentLog RR WITH (NOLOCK)
                            WHERE RR.ReplenishmentKey = RP.ReplenishmentKey  )
         END
      END
      ELSE
      BEGIN
         -- Delete ReplenishmentLog When UserLogin
         DELETE FROM rdt.rdtReplenishmentLog
         WHERE AddWho = @cUserName

         IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog RL WITH (NOLOCK)
                     INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RL.FromLoc
                     WHERE RL.StorerKey = @cStorerKey
                     AND RL.WaveKey = @cWaveKey
                     AND RL.Confirmed <> 'Y'
                     AND Loc.PutawayZone = @cPutAwayZone )
         BEGIN
            SET @nErrNo = 93686
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ZoneInUse
            GOTO Step_2_Fail
         END

         IF @cNotConfirmDPPReplen = '1'
         BEGIN
                 -- Insert into rdt.ReplenishmentLog
            INSERT INTO rdt.rdtReplenishmentLog (
             [ReplenishmentKey]      ,[ReplenishmentGroup]      ,[Storerkey]        ,[Sku]         ,[FromLoc]      ,[ToLoc]
            ,[Lot]             ,[Id]                      ,[Qty]              ,[QtyMoved]    ,[QtyInPickLoc] ,[Priority]
            ,[UOM]             ,[PackKey]                 ,[ArchiveCop]       ,[Confirmed]   ,[ReplenNo]     ,[Remark]
            ,[AddDate]         ,[AddWho]                  ,[EditDate]         ,[EditWho]     ,[RefNo]        ,[DropID]
            ,[LoadKey]         ,[Wavekey]                 ,[OriginalFromLoc]  ,[OriginalQty] ,[ToID] )
            SELECT
             RP.[ReplenishmentKey]      ,RP.[ReplenishmentGroup]      ,RP.[Storerkey]        ,RP.[Sku]         ,RP.[FromLoc]      ,RP.[ToLoc]
            ,RP.[Lot]             ,RP.[Id]                            ,RP.[Qty]              ,RP.[QtyMoved]    ,RP.[QtyInPickLoc] ,RP.[Priority]
            ,RP.[UOM]             ,RP.[PackKey]                       ,RP.[ArchiveCop]       ,'N'              ,RP.[ReplenNo]     ,RP.[Remark]
            ,GetDATE()            ,(suser_sname())                    ,GetDate()             ,(suser_sname())  ,RP.[RefNo]        ,RP.[DropID]
            ,RP.[LoadKey]         ,RP.[Wavekey]                       ,RP.[OriginalFromLoc]  ,RP.[OriginalQty] ,RP.[ToID]
            FROM dbo.Replenishment RP WITH (NOLOCK)
            INNER JOIN dbo.Loc LocA WITH (NOLOCK) ON LocA.Loc = RP.FromLoc
            INNER JOIN dbo.Loc LocB WITH (NOLOCK) ON LocB.Loc = RP.ToLoc
            WHERE RP.WaveKey = @cWaveKey
            AND LocA.PutawayZone = @cPutAwayZone
            AND LocB.LocationType = CASE WHEN @cReplenType = '1' THEN LocB.LocationType ELSE @cLocationType END
            AND RP.Remark = 'NOTVERIFY'
            AND NOT EXISTS( SELECT 1 FROM rdt.rdtReplenishmentLog RR WITH (NOLOCK)
                            WHERE RR.ReplenishmentKey = RP.ReplenishmentKey  )

         END
         ELSE
         BEGIN
            -- Insert into rdt.ReplenishmentLog
            INSERT INTO rdt.rdtReplenishmentLog (
             [ReplenishmentKey]      ,[ReplenishmentGroup]      ,[Storerkey]        ,[Sku]         ,[FromLoc]      ,[ToLoc]
            ,[Lot]             ,[Id]                      ,[Qty]              ,[QtyMoved]    ,[QtyInPickLoc] ,[Priority]
            ,[UOM]             ,[PackKey]                 ,[ArchiveCop]       ,[Confirmed]   ,[ReplenNo]     ,[Remark]
            ,[AddDate]         ,[AddWho]                  ,[EditDate]         ,[EditWho]     ,[RefNo]        ,[DropID]
            ,[LoadKey]         ,[Wavekey]                 ,[OriginalFromLoc]  ,[OriginalQty] ,[ToID] )
            SELECT
             RP.[ReplenishmentKey]      ,RP.[ReplenishmentGroup]      ,RP.[Storerkey]        ,RP.[Sku]         ,RP.[FromLoc]      ,RP.[ToLoc]
            ,RP.[Lot]             ,RP.[Id]                            ,RP.[Qty]              ,RP.[QtyMoved]    ,RP.[QtyInPickLoc] ,RP.[Priority]
            ,RP.[UOM]             ,RP.[PackKey]                       ,RP.[ArchiveCop]       ,'N'              ,RP.[ReplenNo]     ,RP.[Remark]
            ,GetDATE()            ,(suser_sname())                    ,GetDate()             ,(suser_sname())  ,RP.[RefNo]        ,RP.[DropID]
            ,RP.[LoadKey]         ,RP.[Wavekey]                       ,RP.[OriginalFromLoc]  ,RP.[OriginalQty] ,RP.[ToID]
            FROM dbo.Replenishment RP WITH (NOLOCK)
            INNER JOIN dbo.Loc LocA WITH (NOLOCK) ON LocA.Loc = RP.FromLoc
            INNER JOIN dbo.Loc LocB WITH (NOLOCK) ON LocB.Loc = RP.ToLoc
            WHERE RP.WaveKey = @cWaveKey
            AND LocA.PutawayZone = @cPutAwayZone
            AND LocB.LocationType = CASE WHEN @cReplenType = '1' THEN LocB.LocationType ELSE @cLocationType END
            AND RP.Confirmed = 'N'
            AND NOT EXISTS( SELECT 1 FROM rdt.rdtReplenishmentLog RR WITH (NOLOCK)
                            WHERE RR.ReplenishmentKey = RP.ReplenishmentKey  )

         END


--         SELECT TOP 1 @cSuggFromLoc = RP.FromLoc
--                     ,@cSuggFromID  = RP.ID
--                     --,@cSuggestedSKU     = RP.SKU
--                     --,@cSuggestedLot     = RP.Lot
--         FROM dbo.Replenishment RP WITH (NOLOCK)
--         INNER JOIN dbo.Pickdetail PD WITH (NOLOCK) ON PD.WaveKey = RP.WaveKey AND PD.Loc = RP.ToLoc AND PD.SKU = RP.SKU AND PD.Lot = RP.Lot
--         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.FromLoc
--         WHERE RP.WaveKey = @cWaveKey
--         AND Loc.PutawayZone = @cPutAwayZone
--         GROUP BY RP.FromLoc, Loc.LogicalLocation, RP.ID, RP.SKU--, RP.Lot
--         ORDER By Loc.LogicalLocation, RP.SKU
      END

      IF @cNotConfirmDPPReplen = ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                         WHERE WaveKey = @cWaveKey
                         AND AddWho = @cUserName
                         AND Confirmed = 'N'  )
         BEGIN
            SET @nErrNo = 93680
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoReplenRecord
            GOTO Step_2_Fail
         END
      END
      ELSE IF @cNotConfirmDPPReplen = '1'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                         WHERE WaveKey = @cWaveKey
                         AND AddWho = @cUserName
                         AND Remark = 'NOTVERIFY'  )
         BEGIN
            SET @nErrNo = 93691
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoReplenRecord
            GOTO Step_2_Fail
         END
      END


      SELECT TOP 1  @cSuggFromLoc = RP.FromLoc
                   ,@cSuggFromID  = RP.ID
                   --,@cReplenishmentKey = ReplenishmentKey
                   --,@cSuggestedLot     = RP.Lot
      FROM rdt.rdtReplenishmentLog RP WITH (NOLOCK)
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.FromLoc
      WHERE RP.WaveKey = @cWaveKey
      AND RP.Confirmed = CASE WHEN @cNotConfirmDPPReplen = '' THEN 'N' ELSE RP.Confirmed END
      AND RP.Remark    = CASE WHEN @cNotConfirmDPPReplen = '' THEN RP.Remark ELSE 'NOTVERIFY' END
      AND RP.AddWho = @cUserName
      --GROUP BY RP.FromLoc, Loc.LogicalLocation, RP.ID, RP.SKU--, RP.Lot
      ORDER By Loc.LogicalLocation, Loc.Loc, RP.SKU



      -- Prep next screen var
      SET @cOutField01 = @cSuggFromLoc
      SET @cOutField02 = ''

      -- GOTO Next Screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN


      SET @cOutField01 = ''
      SET @cOutField02 = ''


      -- GOTO Previous Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

   END

   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''

      GOTO Quit
   END

   Get_Next5PutAwayZone:
   BEGIN
      SET @nZoneCount = 0

      IF @cNotConfirmDPPReplen = '1'
      BEGIN
         SELECT @nZoneCount = COUNT(L.PutawayZone)
         FROM dbo.Replenishment RP WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (RP.FROMLOC = L.LOC)
         WHERE RP.StorerKey = @cStorerKey
            AND RP.Remark = 'NOTVERIFY'
            AND RP.WaveKey = @cWaveKey
            AND L.Facility = @cFacility
            AND L.PutawayZone NOT IN (@cPutAwayZone01, @cPutAwayZone02, @cPutAwayZone03, @cPutAwayZone04, @cPutAwayZone05) 
            AND L.PutawayZone > @cLastPAZone
      END
      ELSE
      BEGIN
         SELECT @nZoneCount = COUNT(L.PutawayZone)
         FROM dbo.Replenishment RP WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (RP.FROMLOC = L.LOC)
         WHERE RP.StorerKey = @cStorerKey
            AND RP.Confirmed = 'N'
            AND RP.WaveKey = @cWaveKey
            AND L.Facility = @cFacility
            AND L.PutawayZone NOT IN (@cPutAwayZone01, @cPutAwayZone02, @cPutAwayZone03, @cPutAwayZone04, @cPutAwayZone05) 
            AND L.PutawayZone > @cLastPAZone
            
      END



      -- If no task
      IF @nZoneCount = 0
      BEGIN
         SET @nErrNo = 93657
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No more PWZone'
         GOTO Step_2_Fail
      END

      -- Clear the variable first
      SET @nLoop = 0
      SET @cPutAwayZone = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

--      DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
--      SELECT DISTINCT L.PutawayZone
--      FROM dbo.Replenishment RP WITH (NOLOCK)
--      JOIN dbo.LOC L WITH (NOLOCK) ON (RP.FROMLOC = L.LOC)
--      WHERE RP.StorerKey = @cStorerKey
--         AND RP.Confirmed = 'N'
--         AND RP.WaveKey = @cWaveKey
--         AND L.Facility = @cFacility
--         AND L.PutawayZone NOT IN (@cPutAwayZone01, @cPutAwayZone02, @cPutAwayZone03, @cPutAwayZone04, @cPutAwayZone05)
--      ORDER BY L.PutawayZone

      IF @cNotConfirmDPPReplen = '1'
      BEGIN
         DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT L.PutawayZone
         FROM dbo.Replenishment RP WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (RP.FROMLOC = L.LOC)
         WHERE RP.StorerKey = @cStorerKey
            AND RP.Remark = 'NOTVERIFY'
            AND RP.WaveKey = @cWaveKey
            AND L.Facility = @cFacility
            AND L.PutawayZone NOT IN (@cPutAwayZone01, @cPutAwayZone02, @cPutAwayZone03, @cPutAwayZone04, @cPutAwayZone05)  -- (ChewKP02) 
            AND L.PutawayZone > @cLastPAZone    -- (james03)
         ORDER BY L.PutawayZone
      END
      ELSE
      BEGIN
         DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT L.PutawayZone
         FROM dbo.Replenishment RP WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (RP.FROMLOC = L.LOC)
         WHERE RP.StorerKey = @cStorerKey
            AND RP.Confirmed = 'N'
            AND RP.WaveKey = @cWaveKey
            AND L.Facility = @cFacility
            AND L.PutawayZone NOT IN (@cPutAwayZone01, @cPutAwayZone02, @cPutAwayZone03, @cPutAwayZone04, @cPutAwayZone05)  -- (ChewKP02) 
            AND L.PutawayZone > @cLastPAZone -- (james03)
         ORDER BY L.PutawayZone

      END


      OPEN curPutAwayZone
      FETCH NEXT FROM curPutAwayZone INTO @cPutAwayZone
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nLoop = 0
         BEGIN
            SET @cOutField07 = @cPutAwayZone
            SET @cPutAwayZone01 = @cPutAwayZone
         END
         IF @nLoop = 1
         BEGIN
            SET @cOutField08 = @cPutAwayZone
            SET @cPutAwayZone02 = @cPutAwayZone
         END
         IF @nLoop = 2
         BEGIN
            SET @cOutField09 = @cPutAwayZone
            SET @cPutAwayZone03 = @cPutAwayZone
         END
         IF @nLoop = 3
         BEGIN
            SET @cOutField10 = @cPutAwayZone
            SET @cPutAwayZone04 = @cPutAwayZone
         END
         IF @nLoop = 4
         BEGIN
            SET @cOutField11 = @cPutAwayZone
            SET @cPutAwayZone05 = @cPutAwayZone
         END

         SET @nLoop = @nLoop + 1
         SET @cLastPAZone = @cPutAwayZone -- (james03)
         IF @nLoop = 5 BREAK

         FETCH NEXT FROM curPutAwayZone INTO @cPutAwayZone
      END
      CLOSE curPutAwayZone
      DEALLOCATE curPutAwayZone

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cPutAwayZone01 = CASE WHEN ISNULL(@cOutField07, '') = '' THEN '' ELSE @cPutAwayZone01 END
      SET @cPutAwayZone02 = CASE WHEN ISNULL(@cOutField08, '') = '' THEN '' ELSE @cPutAwayZone02 END
      SET @cPutAwayZone03 = CASE WHEN ISNULL(@cOutField09, '') = '' THEN '' ELSE @cPutAwayZone03 END
      SET @cPutAwayZone04 = CASE WHEN ISNULL(@cOutField10, '') = '' THEN '' ELSE @cPutAwayZone04 END
      SET @cPutAwayZone05 = CASE WHEN ISNULL(@cOutField11, '') = '' THEN '' ELSE @cPutAwayZone05 END

      GOTO Quit
   END
END
GOTO Quit



/********************************************************************************
Step 3. Scn = 4212.
   FromLoc         (field01)
   FromLoc         (field02, input)

********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN


      SET @cFromLoc = ISNULL(RTRIM(@cInField02),'')

      IF @cFromLoc = ''
      BEGIN
         SET @nErrNo = 93658
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLocReq
         GOTO Step_3_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM Loc WITH (NOLOCK)
                      WHERE Loc = @cFromLoc
                      AND Facility = @cFacility  )
      BEGIN
         SET @nErrNo = 93659
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLoc
         GOTO Step_3_Fail
      END

      IF @cSwapLoc <> '1'
      BEGIN
         IF ISNULL(RTRIM(@cFromLoc),'') <> ISNULL(RTRIM(@cSuggFromLoc),'')
         BEGIN
            SET @nErrNo = 93674
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLoc
            GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN

         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog RP WITH (NOLOCK)
                         INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON RP.FromLoc = Loc.Loc
                         WHERE RP.WaveKey = @cWaveKey
                         AND RP.FromLoc = @cFromLoc
                         --AND RP.Confirmed = 'N'
                         AND RP.Confirmed = CASE WHEN @cNotConfirmDPPReplen = '' THEN 'N' ELSE RP.Confirmed END
                         AND RP.Remark    = CASE WHEN @cNotConfirmDPPReplen = '' THEN RP.Remark ELSE 'NOTVERIFY' END
                         AND Loc.PutawayZone = CASE WHEN ISNULL(RTRIM(@cPutawayZone),'')  = '' THEN Loc.PutawayZone ELSE ISNULL(RTRIM(@cPutawayZone),'') END  )
         BEGIN
            SET @nErrNo = 93688
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLoc
            GOTO Step_3_Fail
         END
         ELSE
         BEGIN
             SELECT TOP 1
                   @cSuggFromID  = RP.ID
                   --,@cReplenishmentKey = ReplenishmentKey
                   --,@cSuggestedLot     = RP.Lot
            FROM rdt.rdtReplenishmentLog RP WITH (NOLOCK)
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.FromLoc
            WHERE RP.WaveKey = @cWaveKey
            --AND RP.Confirmed = 'N'
            AND RP.Confirmed = CASE WHEN @cNotConfirmDPPReplen = '' THEN 'N' ELSE RP.Confirmed END
            AND RP.Remark    = CASE WHEN @cNotConfirmDPPReplen = '' THEN RP.Remark ELSE 'NOTVERIFY' END
            AND RP.AddWho = @cUserName
            AND RP.FromLoc = @cFromLoc
            ORDER By Loc.LogicalLocation, Loc.Loc, RP.SKU
         END


      END



      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cSuggFromID

      IF @cDefaultFromID = '1'
      BEGIN
         SET @cOutField03 = @cSuggFromID
      END
      ELSE
      BEGIN
         SET @cOutField03 = ''
      END

      -- GOTO Next Screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 1



   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN

      -- Clear the output first
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''


      -- Clear the variable first
      SET @nLoop = 0
      SET @cPutAwayZone = ''
      SET @cPutAwayZone01 = ''
      SET @cPutAwayZone02 = ''
      SET @cPutAwayZone03 = ''
      SET @cPutAwayZone04 = ''
      SET @cPutAwayZone05 = ''


--      DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
--      SELECT DISTINCT L.PutawayZone
--      FROM dbo.Replenishment RP WITH (NOLOCK)
--      JOIN dbo.LOC L WITH (NOLOCK) ON (RP.FROMLOC = L.LOC)
--      WHERE RP.StorerKey = @cStorerKey
--         AND RP.Confirmed = 'N'
--         AND RP.WaveKey = @cWaveKey
--         AND L.Facility = @cFacility
--      ORDER BY L.PutawayZone

      IF @cNotConfirmDPPReplen = '1'
      BEGIN
         DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT L.PutawayZone
         FROM dbo.Replenishment RP WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (RP.FROMLOC = L.LOC)
         WHERE RP.StorerKey = @cStorerKey
            AND RP.Remark = 'NOTVERIFY'
            AND RP.WaveKey = @cWaveKey
            AND L.Facility = @cFacility
         ORDER BY L.PutawayZone
      END
      ELSE
      BEGIN
         DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT L.PutawayZone
         FROM dbo.Replenishment RP WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (RP.FROMLOC = L.LOC)
         WHERE RP.StorerKey = @cStorerKey
            AND RP.Confirmed = 'N'
            AND RP.WaveKey = @cWaveKey
            AND L.Facility = @cFacility
         ORDER BY L.PutawayZone

      END

      OPEN curPutAwayZone
      FETCH NEXT FROM curPutAwayZone INTO @cPutAwayZone
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nLoop = 0
         BEGIN
            SET @cOutField07 = @cPutAwayZone
            SET @cPutAwayZone01 = @cPutAwayZone

         END
         IF @nLoop = 1
         BEGIN
            SET @cOutField08 = @cPutAwayZone
            SET @cPutAwayZone02 = @cPutAwayZone

         END
         IF @nLoop = 2
         BEGIN
            SET @cOutField09 = @cPutAwayZone
            SET @cPutAwayZone03 = @cPutAwayZone

         END
         IF @nLoop = 3
         BEGIN
            SET @cOutField10 = @cPutAwayZone
            SET @cPutAwayZone04 = @cPutAwayZone

         END
         IF @nLoop = 4
         BEGIN
            SET @cOutField11 = @cPutAwayZone
            SET @cPutAwayZone05 = @cPutAwayZone

         END

         SET @nLoop = @nLoop + 1
         IF @nLoop = 5 BREAK

         FETCH NEXT FROM curPutAwayZone INTO @cPutAwayZone
      END
      CLOSE curPutAwayZone
      DEALLOCATE curPutAwayZone


      -- GOTO Previous Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 1




   END
   GOTO Quit

   STEP_3_FAIL:
   BEGIN

      -- Prepare Next Screen Variable
      SET @cOutField01 = @cSuggFromLoc
      SET @cOutField02 = ''

   END
END
GOTO QUIT




/********************************************************************************
Step 4. Scn = 4213.
   FromLoc         (field01)
   From ID         (field02)
   From ID         (field03, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      SET @cFromID = ISNULL(RTRIM(@cInField03),'')


      IF ISNULL(RTRIM(@cFromID),'') <> ISNULL(RTRIM(@cSuggFromID),'')
      BEGIN
         SET @nErrNo = 93675
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidID
         GOTO Step_4_Fail
      END

      -- Validate ID
      IF NOT EXISTS ( SELECT 1
                      FROM dbo.LOTxLOCxID (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                         AND LOC = @cFromLOC
                         AND ID = @cFromID  )
                         --AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0)
      BEGIN
         SET @nErrNo = 93660
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidID'
         GOTO Step_4_Fail
      END



      -- Display SKU Information
      -- Get 1st replenish task
      SELECT TOP 1
         --@cReplenishmentKey = ReplenishmentKey,
         @cSuggSKU = SKU,
         @cLOT = LOT,
         @nQTY = QTY
         --@cSuggToLOC = ToLOC
      FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND FromLoc = @cFromLoc
         AND ID = @cFromID
         AND Confirmed = 'N'
         AND WaveKey = @cWaveKey
         --AND ReplenishmentKey = @cReplenishmentKey
         AND AddWho = @cUserName
      ORDER BY ReplenishmentKey

      SET @nCountScanTask = 0
      SET @nTotalTaskCount = 0
      SELECT @nTotalTaskCount = Count(ReplenishmentKey)
      FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND FromLoc = @cFromLoc
         AND ID = @cFromID
         AND Confirmed = 'N'
         AND WaveKey = @cWaveKey
         AND SKU = CASE WHEN @cReplenBySKU = '1' THEN @cSuggSKU ELSE SKU END
         AND AddWho = @cUserName




      -- Get lottables
--      SELECT
--         @cLottable01 = Lottable01,
--         @cLottable02 = Lottable02,
--         @cLottable03 = Lottable03,
--         @dLottable04 = Lottable04
--      FROM dbo.LotAttribute WITH (NOLOCK)
--      WHERE StorerKey = @cStorerKey
--         AND SKU = @cSuggSKU
--         AND LOT = @cLOT

      IF CHARINDEX('1',@cReplenByPallet )  = 1  --AND @cCountFail = '0'
      BEGIN
         
         SET @cPalletUOM = '' 
         SET @cPalletUOM = SUBSTRING(@cReplenByPallet,2,5 )
         
         IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog  WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND WaveKey = @cWaveKey
                     AND Confirmed <> 'Y'
                     AND ID = @cFromID
                     AND FromLoc = @cFromLoc
                     AND UOM <> @cPalletUOM  )
         BEGIN
              --SET @cReplenByPallet = ''
              GOTO REPLENBYSKU
         END
                  
         SET @cOutField01 = @cFromLoc
         SET @cOutField02 = @cFromID
         SET @cOutField03 = '' 
         
         SET @nScn = @nScn + 6
         SET @nStep = @nStep + 6
      END
      ELSE
      BEGIN
         REPLENBYSKU:
         IF @cReplenBySKU = '1'
         BEGIN
            -- Get Pack info
            SELECT
               @cLottableCode = LottableCode,
               @cDescr = SKU.Descr,
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
               @nPUOM_Div = CAST( IsNULL(
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END, 1) AS INT)
            FROM dbo.SKU SKU WITH (NOLOCK)
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSuggSKU

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @nMQTY = @nQTY
            END
            ELSE
            BEGIN
               SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
               SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
            END


            -- Dynamic lottable
            SELECT
                  @cLottable01 = LA.Lottable01,
                  @cLottable02 = LA.Lottable02,
                  @cLottable03 = LA.Lottable03,
                  @dLottable04 = LA.Lottable04,
                  @dLottable05 = LA.Lottable05,
                  @cLottable06 = LA.Lottable06,
                  @cLottable07 = LA.Lottable07,
                  @cLottable08 = LA.Lottable08,
                  @cLottable09 = LA.Lottable09,
                  @cLottable10 = LA.Lottable10,
                  @cLottable11 = LA.Lottable11,
                  @cLottable12 = LA.Lottable12,
                  @dLottable13 = LA.Lottable13,
                  @dLottable14 = LA.Lottable14,
                  @dLottable15 = LA.Lottable15
            FROM dbo.LotAttribute LA WITH (NOLOCK)
            WHERE Lot = @cLot


            EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSuggSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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



            -- Prep QTY screen var
            SET @cOutField01 = ''
            SET @cOutField02 = @cSuggSKU
            SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
            SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)


            


            IF @cPUOM_Desc = ''
            BEGIN

               --SET @cOutField08 = '' -- @cPUOM_Desc
               SET @cOutField10 = '' -- @nPQTY
               SET @cOutField12 = '' -- @nActPQTY
               --SET @cOutField14 = '' -- @nPUOM_Div
               -- Disable pref QTY field
               SET @cFieldAttr12 = 'O'

            END
            ELSE
            BEGIN
               --SET @cOutField08 = @cPUOM_Desc
               SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
               SET @cOutField12 = '' -- @nActPQTY
               --SET @cOutField14 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
            END
            --SET @cOutField09 = @cMUOM_Desc
            SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
            SET @cOutField13 = '' -- ActMQTY

            SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc

            SET @nCountScanTask = 0
            SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))


            SET @cSKU = ''
            SET @cInField12 = ''
            SET @cInField13 = ''
            SET @nActPQTY = 0
            SET @nActMQTY = 0
         END
         ELSE
         BEGIN
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''

            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''

            SET @cOutField14 = ''
            SET @cOutField10 = '' -- @nPQTY
            SET @cOutField12 = '' -- @nActPQTY
            SET @cOutField11 = ''
            SET @cOutField13 = '' -- ActMQTY
            SET @cOutField09 = ''
            SET @nCountScanTask = 0
            SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))

            SET @cSKU = ''
            SET @cInField12 = ''
            SET @cInField13 = ''
            SET @nActPQTY = 0
            SET @nActMQTY = 0



         END

         IF @cNotDisplayQty  = '1'
         BEGIN
            --SET @cOutField09 = ''
            --SET @cOutField10 = ''
            --SET @cOutField11 = ''

            --SET @cFieldAttr09 = 'O'
            --SET @cFieldAttr10 = 'O'
            --SET @cFieldAttr11 = 'O'
            SET @cFieldAttr12 = 'O'
            SET @cFieldAttr13 = 'O'
         END

         -- (ChewKP04) 
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReplenishmentKey, @cPutawayZone, @cSuggestedLot,  @cOutInfo01 OUTPUT,' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cReplenishmentKey  NVARCHAR( 10), ' +
               ' @cPutawayZone       NVARCHAR( 10), ' +
               ' @cSuggestedLot      NVARCHAR( 10), ' +
               ' @cOutInfo01    NVARCHAR( 60)   OUTPUT, ' +
               ' @nErrNo        INT             OUTPUT, ' +
               ' @cErrMsg       NVARCHAR( 20)   OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReplenishmentKey, @cPutawayZone, @cLOT, @cOutInfo01 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_4_Fail

            SET @cOutfield14 = @cOutInfo01
			   SELECT  @cOutfield09 = SKU FROM LOTATTRIBUTE(NOLOCK) WHERE LOT =  @cLOT--CJ
         END
         ELSE
         BEGIN
            SET @cOutField14 = '' --Optional Field
         END

         SET @nActQTY = 0

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         IF @cFlowThruStep5 = '1'
         BEGIN
         	SELECT @nSKUOnPalletCnt = COUNT( DISTINCT Sku)
         	FROM rdt.rdtReplenishmentLog  WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   WaveKey = @cWaveKey
            AND   Confirmed <> 'Y'
            AND   ID = @cFromID
            AND   FromLoc = @cFromLoc
         	
         	IF @nSKUOnPalletCnt = 1
         	BEGIN
         	   SET @cInField01 = @cSuggSKU
         	   GOTO Step_5         		
         	END
         END
      END



   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN

      -- Clear the output first
      SET @cOutField01 = @cSuggFromLoc
      SET @cOutField02 = ''

      -- GOTO Previous Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 1




   END
   GOTO Quit

   STEP_4_FAIL:
   BEGIN

      -- Prepare Next Screen Variable
      SET @cOutField03 = ''

   END
END
GOTO QUIT


/********************************************************************************
Step 5. Screen 4214
   RPL KEY   (Field01)
   SKU       (Field02)
   SKU Desc1 (Field03)
   SKU Desc2 (Field04)
   Lottable2 (Field05)
   Lottable3 (Field06)
   Lottable4 (Field07)
   PUOM MUOM (Field08, Field09)
   RPL QTY   (Field10, Field11)
   ACT QTY   (Field12, Field13, both input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1      -- Yes OR Send
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
      SET @cActPQTY = IsNULL( @cInField12, '')
      SET @cActMQTY = IsNULL( @cInField13, '')
      SET @cLabelNo = IsNULL( RTRIM(@cInField01), '')
      SET @cBarcode = IsNULL( RTRIM(@cInField01), '')

      -- Goto Short Screen If SKU & Qty = Blank
      IF ISNULL(RTRIM(@cLabelNo),'')  = '' AND ( @cActPQTY = '' AND @cActMQTY = '' ) AND @nSKUValidated = 0
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         SET @nScn  = @nScn + 3
         SET @nStep = @nStep + 3

         GOTO QUIT

      END


      IF ISNULL(RTRIM(@cLabelNo),'')  = '' AND @nSKUValidated = 0
      BEGIN
         SET @nErrNo = 93661
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKUReq
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU
         GOTO Step_5_Fail
      END

      --SET @cDecodeLabelNo = ''


      IF ISNULL(RTRIM(@cLabelNo),'')  <> ''
      BEGIN
         -- Decode
         IF @cDecodeSP <> ''
         BEGIN
            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
                  @cUPC          = @cSKU              OUTPUT, 
                  @nQTY          = @nUCCQTY           OUTPUT, 
                  @cUserDefine01 = @cUCC              OUTPUT,
                  @cUserDefine02 = @cReplenishmentKey OUTPUT,
                  @cLottable01   = @cLottable01       OUTPUT,
                  @cLottable02   = @cLottable02       OUTPUT,
                  @cLottable03   = @cLottable03       OUTPUT,
                  @dLottable04   = @dLottable04       OUTPUT,
                  @dLottable05   = @dLottable05       OUTPUT,
                  @cLottable06   = @cLottable06       OUTPUT,
                  @cLottable07   = @cLottable07       OUTPUT,
                  @cLottable08   = @cLottable08       OUTPUT,
                  @cLottable09   = @cLottable09       OUTPUT,
                  @cLottable10   = @cLottable10       OUTPUT,
                  @cLottable11   = @cLottable11       OUTPUT,
                  @cLottable12   = @cLottable12       OUTPUT,
                  @dLottable13   = @dLottable13       OUTPUT,
                  @dLottable14   = @dLottable14       OUTPUT,
                  @dLottable15   = @dLottable15       OUTPUT,
                  @nErrNo        = @nErrNo            OUTPUT, 
                  @cErrMsg       = @cErrMsg           OUTPUT,
                  @cType         = 'UPC'
            END

            -- Customize decode
            ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
                  ' @cSKU        OUTPUT, @nQty        OUTPUT, @cUCC        OUTPUT, @cReplenishmentKey  OUTPUT, ' +
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
                  ' @cBarcode     NVARCHAR( 2000), ' +
                  ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQty         INT            OUTPUT, ' +
                  ' @cUCC         NVARCHAR( 20)  OUTPUT, ' +
                  ' @cReplenishmentKey NVARCHAR( 10)  OUTPUT, ' +
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
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode,
                  @cSKU        OUTPUT, @nUCCQty      OUTPUT, @cUCC        OUTPUT, @cReplenishmentKey  OUTPUT,
                  @cLottable01 OUTPUT, @cLottable02  OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
                  @cLottable06 OUTPUT, @cLottable07  OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
                  @cLottable11 OUTPUT, @cLottable12  OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
                  @nErrNo      OUTPUT, @cErrMsg      OUTPUT
            END

            IF @nErrNo <> 0
               GOTO Step_5_Fail
         END
         ELSE
         BEGIN
            -- Decode label
            IF ISNULL(RTRIM(@cDecodeLabelNo),'')  <> ''
            BEGIN

               SET @cErrMsg = ''
               SET @nErrNo = 0

               EXEC dbo.ispLabelNo_Decoding_Wrapper
                   @c_SPName     = @cDecodeLabelNo
                  ,@c_LabelNo    = @cLabelNo
                  ,@c_Storerkey  = @cStorerKey
                  ,@c_ReceiptKey = ''
                  ,@c_POKey      = ''
                  ,@c_LangCode   = @cLangCode
                  ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
                  ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
                  ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
                  ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
                  ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
                  ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- LOT
                  ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Label Type
                  ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- UCC
                  ,@c_oFieled09  = @c_oFieled09 OUTPUT
                  ,@c_oFieled10  = @c_oFieled10 OUTPUT
                  ,@b_Success    = @b_Success   OUTPUT
                  ,@n_ErrNo      = @nErrNo      OUTPUT
                  ,@c_ErrMsg     = @cErrMsg     OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_5_Fail

               SET @cSKU    = ISNULL( @c_oFieled01, '')
               SET @nUCCQTY = CAST( ISNULL( @c_oFieled05, '') AS INT)
               SET @cUCC    = ISNULL( @c_oFieled08, '')
               SET @cReplenishmentKey = ISNULL( @c_oFieled09, '')

               IF @cNotDisplayQty  = '1'
               BEGIN
                  IF @nUCCQty > 0
                     SET @nQty = @nUCCQty
                  ELSE
                     SET @cActMQTY = @c_oFieled10
               END

               IF @cReplenishmentKey = ''
               BEGIN
                  SET @nErrNo = 93684
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ReplenNotFound
                  EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU
                  GOTO Step_5_Fail
               END



            END
            ELSE
            BEGIN
               SET @cSKU = @cLabelNo
            END
         END


         -- Get SKU barcode count
         --DECLARE @nSKUCnt INT
         EXEC rdt.rdt_GETSKUCNT
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU
            ,@nSKUCnt     = @nSKUCnt       OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT

         -- Check SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 93662
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU
            GOTO Step_5_Fail
         END

         -- Check multi SKU barcode
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 93663
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU
            GOTO Step_4_Fail
         END

         -- Get SKU code
         EXEC rdt.rdt_GETSKU
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU          OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT

         -- Check SKU same as suggested
         IF @cSKU <> @cSuggSKU
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                           AND SKU = @cSKU )
            BEGIN
               SET @nErrNo = 93664
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Different SKU
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU
               GOTO Step_5_Fail
            END
         END
      END

      IF @cExtendedValidateSP <> ''
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN

            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cReplenishmentKey, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cReplenishmentKey  NVARCHAR( 20), ' +
               '@cLabelNo           NVARCHAR( 20), ' +
               '@nErrNo             INT           OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20) OUTPUT'


            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cReplenishmentKey, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_5_Fail
            END

         END
      END

      SET @nSKUValidated = 1


      -- Retain the key-in value
      SET @cOutField12 = @cInField12 -- Pref QTY
      SET @cOutField13 = @cInField13 -- Master QTY


      IF  ISNULL(RTRIM(@cActPQTY),'')  <> ''
      BEGIN
         IF RDT.rdtIsValidQTY( @cActPQTY, 0) = 0
         BEGIN
            SET @nErrNo = 93665
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 12 -- PQTY
            GOTO Step_5_Fail
         END
      END

      -- Validate ActMQTY
--      IF @cActMQTY  = ''
--         SET @cActMQTY  = '0' -- Blank taken as zero

      IF ISNULL(RTRIM(@cActMQTY),'')  <> ''
      BEGIN
         IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0
         BEGIN
            SET @nErrNo = 93666
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 13 -- MQTY
            GOTO Step_5_Fail
         END
      END



      --SET @nActQTY = 0

      -- Calc total QTY in master UOM
      SET @nActPQTY = CAST( @cActPQTY AS INT)
      SET @nActMQTY = CAST( @cActMQTY AS INT)
      SET @nActQTY = @nActQTY + rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nActPQTY, @cPUOM, 6) -- Convert to QTY in master UOM



      IF @nUCCQTY > 0
         SET @nActQTY = @nActQTY + @nUCCQTY
      ELSE
         SET @nActQTY = @nActQTY + @nActMQTY
         --IF @cSKU <> '' --AND @cDisableQTYField = '1'
         --   SET @nActQTY = @nActQTY + 1

      -- Validate QTY
      IF @nActQTY = 0
      BEGIN
         SET @nErrNo = 93667
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY needed'
         EXEC rdt.rdtSetFocusField @nMobile, 13
         GOTO Step_5_Fail
      END


      -- Get QTY Avail
--      SET @nQTY_Avail = 0
--      SELECT @nQTY_Avail = IsNULL( SUM( QTY - QTYAllocated - QTYPicked), 0)
--      FROM dbo.LOTxLOCxID WITH (NOLOCK)
--      WHERE StorerKey = @cStorerKey
--         AND SKU = @cSKU
--         AND LOC = @cFromLOC
--         AND ID = @cFromID
--         AND LOT = @cLOT
--         AND (QTY - QTYAllocated - QTYPicked) > 0
--
--      -- Validate QTY to replen more than QTY avail
--      IF @nActQTY > @nQTY_Avail
--      BEGIN
--
--         SET @nErrNo = 93668
--         SET @cErrMsg = rdt.rdtgetmessage( 63039, @cLangCode, 'DSP') --QTYAvalNotEnuf
--         EXEC rdt.rdtSetFocusField @nMobile, 13
--         GOTO Step_5_Fail
--      END



      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cWaveKey, @cPutawayZone, @cActToLOC, @cSKU, @cLabelNo, @nActQTY, @cReplenishmentKey, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile        INT, ' +
            '@nFunc          INT, ' +
            '@nStep          INT, ' +
            '@cLangCode      NVARCHAR( 3),  ' +
            '@cUserName      NVARCHAR( 18), ' +
            '@cFacility      NVARCHAR( 5),  ' +
            '@cStorerKey     NVARCHAR( 15), ' +
            '@cWaveKey       NVARCHAR( 10), ' +
            '@cPutawayZone   NVARCHAR( 10), ' +
            '@cActToLOC      NVARCHAR( 10), ' +
            '@cSKU           NVARCHAR( 20), ' +
            '@cLabelNo       NVARCHAR( 20), ' +
            '@nActQTY        INT, ' +
            '@cReplenishmentKey NVARCHAR(10), ' +
            '@nErrNo         INT           OUTPUT, ' +
            '@cErrMsg        NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cWaveKey, @cPutawayZone, @cActToLOC,  @cSKU, @cLabelNo, @nActQTY, @cReplenishmentKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            GOTO Step_5_Fail
         END

         SET @nCountScanTask = @nCountScanTask + 1
      END
      ELSE
      BEGIN
         -- Update rdt.rdtReplenishmentLog
         UPDATE rdt.rdtReplenishmentLog
         SET  Confirmed = '1' -- In Progress
            , QtyMoved  = @nActQTY
            , DropID    = @cLabelNo
         WHERE ReplenishmentKey = @cReplenishmentKey

         IF @@ERROR <> 0
         BEGIN
               SET @nErrNo = 93676
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRPLogFail
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU
               GOTO Step_5_Fail
         END

         SET @nCountScanTask = @nCountScanTask + 1
      END


      -- Top up MQTY, PQTY
      IF @nUCCQTY > 0
      BEGIN
         -- Top up decoded QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @nActMQTY = @nActMQTY + @nUCCQTY
         END
         ELSE
         BEGIN
            SET @nActPQTY = @nActPQTY + (@nUCCQTY / @nPUOM_Div) -- Calc QTY in preferred UOM
            SET @nActMQTY = @nActMQTY + (@nUCCQTY % @nPUOM_Div) -- Calc the remaining in master unit
         END
      END
      ELSE
      BEGIN
         --IF @cSKU <> '' AND @cDisableQTYField = '1' -- QTY field disabled
            SET @nActMQTY = @nActQTY + @nActMQTY
      END

      SET @cOutField12 = CASE WHEN @cFieldAttr12 = 'O' THEN '' ELSE CAST( @nActPQTY AS NVARCHAR( 5)) END -- PQTY
      SET @cOutField13 = CAST( @nActMQTY AS NVARCHAR( 5)) -- MQTY
      SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))

      -- QTY fulfill
      IF @nActQTY >= @nQTY
      BEGIN

         SET @nSKUValidated = 0

         -- If No More Replenishment on the Same ToLoc Go to ToLoc Screen
--         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
--                         WHERE WaveKey = @cWaveKey
--                         AND AddWho = @cUserName
--                         AND Confirmed = 'N'
--                         AND ToLoc     = @cSuggToLoc
--                         AND FromLoc   = @cFromLoc )
--         BEGIN
            -- Prepare next screen var
            -- Prep next screen var
            SET @cOutField01 = @cFromLoc
            SET @cOutField02 = @cFromID

            SELECT @cSuggToLoc = ToLoc
            FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND WaveKey = @cWaveKey
            AND ReplenishmentKey = @cReplenishmentKey


            SET @cOutField12 = @cSuggToLoc

            IF @cDefaultToLoc = '1'
            BEGIN
               SET @cOutField13 = @cSuggToLoc
            END
            ELSE
            BEGIN
               SET @cOutField13 = '' -- actual ToLOC
            END

            -- Go to next screen
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO QUIT
--         END
--         ELSE
--         BEGIN
--            -- Same FromLoc, FromID
--            IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
--                         WHERE WaveKey = @cWaveKey
--                         AND AddWho = @cUserName
--                         AND Confirmed = 'N'
--                         AND ToLoc     = @cSuggToLoc
--                         AND FromLoc   = @cFromLoc
--                         AND ID        = @cFromID )
--            BEGIN
--               -- Display SKU Information
--               -- Get 1st replenish task
--               SELECT TOP 1
--                  @cReplenishmentKey = ReplenishmentKey,
--                  @cSuggSKU = SKU,
--                  @cLOT = LOT,
--                  @nQTY = QTY,
--                  @cSuggToLOC = ToLOC
--               FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
--               WHERE StorerKey = @cStorerKey
--                  AND FromLoc = @cFromLoc
--                  AND ID = @cFromID
--                  AND Confirmed = 'N'
--                  AND WaveKey = @cWaveKey
--                  --AND ReplenishmentKey > @cReplenishmentKey
--                  --AND SKU > @cSKU
--
--               ORDER BY ReplenishmentKey
--
--
--
--
--               -- Get lottables
--               --SELECT
--               --   @cLottable01 = Lottable01,
--               --   @cLottable02 = Lottable02,
--               --   @cLottable03 = Lottable03,
--               --   @dLottable04 = Lottable04
--               --FROM dbo.LotAttribute WITH (NOLOCK)
--               --WHERE StorerKey = @cStorerKey
--               --   AND SKU = @cSuggSKU
--               --   AND LOT = @cLOT
--
--               -- Get Pack info
--               SELECT
--                  @cDescr = SKU.Descr,
--                  @cMUOM_Desc = Pack.PackUOM3,
--                  @cPUOM_Desc =
--                     CASE @cPUOM
--                        WHEN '2' THEN Pack.PackUOM1 -- Case
--                        WHEN '3' THEN Pack.PackUOM2 -- Inner pack
--                        WHEN '6' THEN Pack.PackUOM3 -- Master unit
--                        WHEN '1' THEN Pack.PackUOM4 -- Pallet
--                        WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
--                        WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
--                     END,
--                  @nPUOM_Div = CAST( IsNULL(
--                     CASE @cPUOM
--                        WHEN '2' THEN Pack.CaseCNT
--                        WHEN '3' THEN Pack.InnerPack
--                        WHEN '6' THEN Pack.QTY
--                        WHEN '1' THEN Pack.Pallet
--                        WHEN '4' THEN Pack.OtherUnit1
--                        WHEN '5' THEN Pack.OtherUnit2
--                     END, 1) AS INT)
--               FROM dbo.SKU SKU WITH (NOLOCK)
--                  INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
--               WHERE SKU.StorerKey = @cStorerKey
--                  AND SKU.SKU = @cSuggSKU
--
--               -- Convert to prefer UOM QTY
--               IF @cPUOM = '6' OR -- When preferred UOM = master unit
--                  @nPUOM_Div = 0  -- UOM not setup
--               BEGIN
--                  SET @cPUOM_Desc = ''
--                  SET @nPQTY = 0
--                  SET @nMQTY = @nQTY
--               END
--               ELSE
--               BEGIN
--                  SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
--                  SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
--               END
--
--
--               -- Dynamic lottable
--               EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
--                  @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
--                  @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
--                  @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
--                  @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
--                  @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
--                  @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
--                  @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
--                  @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
--                  @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
--                  @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
--                  @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
--                  @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
--                  @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
--                  @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
--                  @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
--                  @nMorePage   OUTPUT,
--                  @nErrNo      OUTPUT,
--                  @cErrMsg     OUTPUT,
--                  '',      -- SourceKey
--                  @nFunc   -- SourceType
--
--               -- Prep QTY screen var
--               SET @cOutField01 = ''
--               SET @cOutField02 = @cSuggSKU
--               SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
--               SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
--
----               SET @cOutField09 = @cLottable01
----               SET @cOutField05 = @cLottable02
----               SET @cOutField06 = @cLottable03
----               SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
--
--               SET @cOutField14 = '' --Optional Field
--
--
--               IF @cPUOM_Desc = ''
--               BEGIN
--
--                  --SET @cOutField08 = '' -- @cPUOM_Desc
--                  SET @cOutField10 = '' -- @nPQTY
--                  SET @cOutField12 = '' -- @nActPQTY
--                  --SET @cOutField14 = '' -- @nPUOM_Div
--                  -- Disable pref QTY field
--                  SET @cFieldAttr12 = 'O'
--
--               END
--               ELSE
--               BEGIN
--                  --SET @cOutField08 = @cPUOM_Desc
--                  SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
--                  SET @cOutField12 = CAST( @cActPQTY AS NVARCHAR( 5)) --'' -- @nActPQTY
--                  --SET @cOutField14 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
--               END
--
--
--               --SET @cOutField09 = @cMUOM_Desc
--               SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
--               SET @cOutField13 = CAST( @cActMQTY AS NVARCHAR( 5)) -- MQTY
--
--               SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
--
--               SET @cSKU = ''
--               SET @cInField12 = ''
--               SET @cInField13 = ''
--               SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))
--
--               EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU
--
--
--               GOTO QUIT
--            END
--
--            -- Same FromLoc, Different ID
--            IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
--                         WHERE WaveKey = @cWaveKey
--                         AND AddWho = @cUserName
--                         AND Confirmed = 'N'
--                         AND ToLoc     = @cSuggToLoc
--                         AND FromLoc   = @cFromLoc
--                         AND ID       <> @cFromID )
--            BEGIN
--               SELECT TOP 1  @cSuggFromLoc = RP.FromLoc
--                            ,@cSuggFromID  = RP.ID
--                            ,@cReplenishmentKey = RP.ReplenishmentKey
--                            --,@cSuggestedLot     = RP.Lot
--               FROM rdt.rdtReplenishmentLog RP WITH (NOLOCK)
--               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.FromLoc
--               WHERE RP.WaveKey = @cWaveKey
--               AND RP.Confirmed = 'N'
--               AND RP.AddWho = @cUserName
--               AND ToLoc     = @cSuggToLoc
--               --GROUP BY RP.FromLoc, Loc.LogicalLocation, RP.ID, RP.SKU--, RP.Lot
--               ORDER By Loc.LogicalLocation, RP.SKU
--
--
--               SET @cOutField01 = @cSuggFromLoc
--               SET @cOutField02 = @cSuggFromID
--               IF @cDefaultFromID = '1'
--               BEGIN
--                  SET @cOutField03 = @cSuggFromID
--               END
--               ELSE
--               BEGIN
--                  SET @cOutField03 = ''
--               END
--
--               SET @nScn = @nScn - 1
--               SET @nStep = @nStep - 1
--
--               GOTO QUIT
--            END
--
--            -- Different FromLoc, Different ID
--            IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
--                         WHERE WaveKey = @cWaveKey
--                         AND AddWho    = @cUserName
--                         AND Confirmed = 'N'
--                         AND ToLoc     = @cSuggToLoc
--                         AND FromLoc  <> @cFromLoc
--                         AND ID       <> @cFromID )
--            BEGIN
--               SELECT TOP 1  @cSuggFromLoc = RP.FromLoc
--                            ,@cSuggFromID  = RP.ID
--                            ,@cReplenishmentKey = RP.ReplenishmentKey
--                            --,@cSuggestedLot     = RP.Lot
--               FROM rdt.rdtReplenishmentLog RP WITH (NOLOCK)
--               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.FromLoc
--               WHERE RP.WaveKey = @cWaveKey
--               AND RP.Confirmed = 'N'
--               AND RP.AddWho = @cUserName
--               AND ToLoc     = @cSuggToLoc
--               --GROUP BY RP.FromLoc, Loc.LogicalLocation, RP.ID, RP.SKU--, RP.Lot
--               ORDER By Loc.LogicalLocation, RP.SKU
--
--
--               SET @cOutField01 = @cSuggFromLoc
--               SET @cOutField02 = ''
--               SET @cOutField03 = ''
--
--               SET @nScn = @nScn - 2
--          SET @nStep = @nStep - 2
--
--               GOTO QUIT
--
--            END
--
--
--
--
--
--         END

      END

      IF @cNotDisplayQty  = '1'
      BEGIN
         --SET @cOutField09 = ''
         --SET @cOutField10 = ''
         --SET @cOutField11 = ''

         --SET @cFieldAttr09 = 'O'
         --SET @cFieldAttr10 = 'O'
         --SET @cFieldAttr11 = 'O'

         SET @cOutField12 = ''
         SET @cOutField13 = ''
         SET @cFieldAttr12 = 'O'
         SET @cFieldAttr13 = 'O'
      END

      -- Qty Short Manual Goto Short Screen
      IF @nActQTY < @nQTY AND ISNULL(RTRIM(@cLabelNo),'')  = '' --AND @nSKUValidated = 1
      BEGIN
         --SET @cERRMSG = @nSKUValidated
--         SET @cOutField01 = @cSKU
--         SET @cOutField02 = ''
--
--         -- Go to next screen
--         SET @nScn  = @nScn + 3
--         SET @nStep = @nStep + 3

         GOTO QUIT
      END

      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReplenishmentKey, @cPutawayZone, @cSuggestedLot,  @cOutInfo01 OUTPUT,' +
            ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
         SET @cSQLParam =
            ' @nMobile      INT,           ' +
            ' @nFunc        INT,           ' +
            ' @cLangCode    NVARCHAR( 3),  ' +
            ' @nStep        INT,           ' +
            ' @nInputKey    INT,           ' +
            ' @cStorerKey   NVARCHAR( 15), ' +
            ' @cReplenishmentKey  NVARCHAR( 10), ' +
            ' @cPutawayZone       NVARCHAR( 10), ' +
            ' @cSuggestedLot      NVARCHAR( 10), ' +
            ' @cOutInfo01    NVARCHAR( 60)   OUTPUT, ' +
            ' @nErrNo        INT             OUTPUT, ' +
            ' @cErrMsg       NVARCHAR( 20)   OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReplenishmentKey, @cPutawayZone, @cLOT, @cOutInfo01 OUTPUT,
            @nErrNo      OUTPUT, @cErrMsg     OUTPUT

         IF @nErrNo <> 0
            GOTO Step_5_Fail

         SET @cOutfield14 = @cOutInfo01
      END
      ELSE
      BEGIN
         SET @cOutField14 = '' --Optional Field
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen
--      SET @cSKU = ''
--      SET @cOutField01 = @cFromLoc
--      SET @cOutField02 = @cFromID
--      SET @cOutField03 = '' -- SKU
--      SET @nSKUValidated = 0
      -- Go to prev screen
--      SET @nScn  = @nScn - 1
--      SET @nStep = @nStep - 1

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

      SET @nScn  = @nScn + 3
      SET @nStep = @nStep + 3

      GOTO QUIT



   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      -- - Start

      IF @cNotDisplayQty <> '1'
      BEGIN
         SET @cFieldAttr12 = ''
         -- - End

         IF @cPUOM_Desc = ''
            -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
            -- to disable the Pref QTY field. So centralize disable it here for all fail condition
            -- Disable pref QTY field
            SET @cFieldAttr12 = 'O'



         SET @cOutField12 = '' -- ActPQTY
         SET @cOutField13 = '' -- ActMQTY
      END
      ELSE
      BEGIN
         --SET @cOutField09 = ''
         --SET @cOutField10 = ''
         --SET @cOutField11 = ''

         --SET @cFieldAttr09 = 'O'
         --SET @cFieldAttr10 = 'O'
         --SET @cFieldAttr11 = 'O'
         SET @cFieldAttr12 = 'O'
         SET @cFieldAttr13 = 'O'
      END
   END
END
GOTO Quit


/********************************************************************************
Step 6. Screen = 4214
   FROM LOC   (Field01)
   FROM ID    (Field02)
   SKU        (Field03)
   SKU Desc 1 (Field04)
   SKU Desc 2 (Field05)
   PUOM MUOM  (Field06, Field07)
   RPL QTY    (Field08, Field09)
   ACT QTY    (Field10, Field11)
   TO LOC     (Field12)
   TO LOC     (Field13, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cActToLOC = @cInField13

      --  - Start
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
      --  - End

      -- Validate blank
      IF ISNULL(RTRIM(@cActToLOC),'')  = ''
      BEGIN
         SET @nErrNo = 93669
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TO LOC needed
         GOTO Step_6_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cActToLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 93670
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_6_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 93671
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_6_Fail
      END

      SET @cToLoc = ''
      
      -- If replenis to different LOC
      IF @cActToLOC <> @cSuggToLoc
      BEGIN
         IF @cAllowOverWriteToLoc <> '1'
         BEGIN
            SET @nErrNo = 93672
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff Loc'
            GOTO Step_6_Fail
         END
         ELSE
         BEGIN
         	SET @cToLoc = @cActToLOC

         	SELECT @cSuggLocLoseId = LoseId
         	FROM dbo.LOC AS l WITH (NOLOCK)
         	WHERE l.Loc = @cActToLOC
         	AND   l.Facility = @cFacility

         	SELECT @cToLocLoseId = LoseId
         	FROM dbo.LOC AS l WITH (NOLOCK)
         	WHERE l.Loc = @cToLoc
         	AND   l.Facility = @cFacility
         END
      END

      IF @cToLoc = ''
         SET @cToLoc = @cSuggToLOC

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN Step_6_ConfirmReplen

      -- (james01)
      -- Reverse replen
      IF @cActToLOC <> @cSuggToLoc AND 
         @cAllowOverWriteToLoc = '1'
      BEGIN
         DECLARE CUR_DELETE_REPLEN  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ReplenishmentKey, Lot, Id, SKU, ReplenNo
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
         WHERE WaveKey = @cWaveKey
         AND   FromLoc = @cFromLoc
         AND   ( (ISNULL( @cFromID, '') = '') OR ( ID = @cFromID))
         AND   ToLoc = @cSuggToLoc
         AND   Confirmed NOT IN ('S' ,'Y', 'R') --S=In Transit R=Short Y=Confirmed N=Normal
         ORDER BY 1
         OPEN CUR_DELETE_REPLEN
         FETCH NEXT FROM CUR_DELETE_REPLEN INTO @cRPLKey, @cRPLLot, @cRPLId, @cRPLSKU, @cReplenNo
         WHILE @@FETCH_STATUS = 0
         BEGIN
         	IF @cReplenNo <> 'FCP'
         	BEGIN
               IF @cToLocLoseId = '1'
                  SET @cRPLId = ''

         	   SET @nRPLQty = 0
               SELECT @nRPLQty = ISNULL( SUM( QtyExpected), 0)
               FROM dbo.LOTxLOCxID WITH (NOLOCK)
               WHERE LOT = @cRPLLot
               AND   LOC = @cSuggToLoc
               AND (( @cSuggLocLoseId = '1' AND ID = '') OR (@cSuggLocLoseId = '0' AND ID = ID))            

               -- Cancel booking on suggested to loc 
               UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET
                  QtyAllocated = CASE WHEN QtyAllocated < @nRPLQty THEN 0
                                  ELSE QtyAllocated - @nRPLQty
                                  END,
                  QtyExpected = CASE WHEN QtyExpected < @nRPLQty THEN 0
                                  ELSE QtyExpected - @nRPLQty
                                  END
               WHERE LOT = @cRPLLot 
               AND   LOC = @cSuggToLoc
               AND (( @cSuggLocLoseId = '1' AND ID = '') OR (@cSuggLocLoseId = '0' AND ID = ID))
            
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 93693
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CancBookingErr'
                  GOTO RollBackTran
               END

               -- Booking actual user overwritten loc
               IF EXISTS(SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK)                                                           
                           WHERE LOT = @cRPLLot                                                                          
                           AND LOC = @cToLoc                                                                        
                           AND ID = @cRPLId)
               BEGIN                                                                                                 
                  UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET                                                                  
                     QtyAllocated = ISNULL( QtyAllocated,0) + @nRPLQty,   
                     QtyExpected = ISNULL( QtyExpected,0) + @nRPLQty
                  WHERE LOT = @cRPLLot                                                                                 
                  AND LOC = @cToLoc                                                                               
                  AND ID = @cRPLId                                                                                 
                                                                                                                        
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 93694
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'BookingToLocEr'
                  GOTO RollBackTran
               END                                                                                                
               END  
               ELSE   
               BEGIN  
                  INSERT INTO dbo.LOTxLOCxID (Lot, Loc, Id, StorerKey, Sku, Qty,  
                              QtyAllocated, QtyPicked, QtyExpected, PendingMoveIN, QtyReplen)  
                  VALUES (@cRPLLot, @cToLoc, @cRPLId, @cStorerkey, @cRPLSKU, 0, @nRPLQty, 0, @nRPLQty, 0, 0)  
                             
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 93695
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'BookingToLocEr'
                     GOTO RollBackTran
                  END                                  
               END  
            
               -- Update pickdetail with user overwrite loc
               DECLARE CUR_UPDATE_PICKD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey FROM dbo.PickDetail PD WITH (NOLOCK) 
               JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
               WHERE PD.StorerKey = @cStorerKey
               AND   PD.Status = '0'
               AND   PD.Loc = @cSuggToLoc
               AND   PD.Lot = @cRPLLot
               AND   PD.SKU = @cRPLSKU
               ORDER BY 1
               OPEN CUR_UPDATE_PICKD
               FETCH NEXT FROM CUR_UPDATE_PICKD INTO @cPickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     LOC = @cToLOC,
                     Id = @cRPLId,
                     EditDate = GETDATE(),
                     EditWho = @cUserName,
                     TrafficCop = NULL
                  WHERE  PickDetailKey = @cPickDetailKey
            
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 93696
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PickLOC Err'
                     CLOSE CUR_UPDATE_PICKD
                     DEALLOCATE CUR_UPDATE_PICKD
                     GOTO RollBackTran
                  END
                                 
                  FETCH NEXT FROM CUR_UPDATE_PICKD INTO @cPickDetailKey
               END
               CLOSE CUR_UPDATE_PICKD
               DEALLOCATE CUR_UPDATE_PICKD
         	END

            -- Update replenishment log table
            UPDATE rdt.rdtReplenishmentLog WITH (ROWLOCK) SET 
               ToLOC = @cToLOC
            WHERE ReplenishmentKey = @cRPLKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 93697
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd RplLog Err'
               GOTO RollBackTran
            END
            
            -- Update Replenishment table
            UPDATE dbo.REPLENISHMENT WITH (ROWLOCK) SET 
               ToLoc = @cToLOC,
               EditDate = GETDATE(),
               EditWho = @cUserName
            WHERE ReplenishmentKey = @cRPLKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 93698
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Rpl Loc Er'
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_DELETE_REPLEN INTO @cRPLKey, @cRPLLot, @cRPLId, @cRPLSKU, @cReplenNo
         END
         CLOSE CUR_DELETE_REPLEN
         DEALLOCATE CUR_DELETE_REPLEN
      END

      IF ISNULL(RTRIM(@cExtendedUpdateSP),'')  = ''
      BEGIN
         -- Loop All Records and Confirm Replenishment
         DECLARE CursorReplen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

         SELECT ReplenishmentKey, QtyMoved, RowRef
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
         WHERE WaveKey = @cWaveKey
         AND StorerKey = @cStorerKey
         AND AddWho = @cUserName
         AND Confirmed = '1'
         AND ToLoc = @cToLOC


         OPEN CursorReplen

         FETCH NEXT FROM CursorReplen INTO @cReplenKey, @nQtyMoved, @nRowRef


         WHILE @@FETCH_STATUS <> -1
         BEGIN
                        -- Update replenishment
            UPDATE dbo.Replenishment WITH (ROWLOCK) SET
               QTY       = @nQtyMoved,
               Confirmed = 'S'
            WHERE ReplenishmentKey = @cReplenKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 93673
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd RPL Fail'
               CLOSE CursorReplen
               DEALLOCATE CursorReplen
               GOTO RollBackTran
            END

            Update rdt.rdtReplenishmentLog WITH (ROWLOCK)
            SET Confirmed = 'Y'
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 93679
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdReplenLogFail'
               DEALLOCATE CursorReplen
               GOTO RollBackTran
            END

            FETCH NEXT FROM CursorReplen INTO @cReplenKey, @nQtyMoved  , @nRowRef

         END
         CLOSE CursorReplen
         DEALLOCATE CursorReplen


      END
      ELSE
      BEGIN
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
          BEGIN
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cWaveKey, @cPutawayZone, @cActToLOC, @cSKU, @cLabelNo, @nActQTY, @cReplenishmentKey, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@nStep          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@cUserName      NVARCHAR( 18), ' +
               '@cFacility      NVARCHAR( 5),  ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cWaveKey       NVARCHAR( 10), ' +
               '@cPutawayZone   NVARCHAR( 10), ' +
               '@cActToLOC      NVARCHAR( 10), ' +
               '@cSKU           NVARCHAR( 20), ' +
               '@cLabelNo       NVARCHAR( 20), ' +
               '@nActQTY        INT, ' +
               '@cReplenishmentKey NVARCHAR(10), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cWaveKey, @cPutawayZone, @cToLOC,  @cSKU, @cLabelNo, @nActQTY, @cReplenishmentKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

                 IF @nErrNo <> 0
                     GOTO RollBackTran
          END

      END
      --IF @cUserName = 'ua02'
      --GOTO RollBackTran
      COMMIT TRAN Step_6_ConfirmReplen  
      GOTO Quit_Step_6_ConfirmReplen  
  
      RollBackTran:  
         ROLLBACK TRAN Step_6_ConfirmReplen  

      Quit_Step_6_ConfirmReplen:  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  
            --            INSERT INTO TraceInfo3 (tracename, TimeIn, Col1, Col2, Col3, Col4, Col5) VALUES 
            --('replenishment123', GETDATE(), @cSuggToLoc, @cRPLLot, @cRPLId, @cRPLSKU, @nRPLQty)

      -- Go to message screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- - Start
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
      -- - End

      SET @cOutField01 = ''

      -- Go to next screen
      SET @nScn  = @nScn + 3
      SET @nStep = @nStep + 3

      GOTO QUIT

   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cActToLOC = ''
      IF @cDefaultToLoc = '1'
      BEGIN
         SET @cOutField13 = @cSuggToLoc
      END
      ELSE
      BEGIN
         SET @cOutField13 = '' -- actual ToLOC
      END
   END
END
GOTO Quit



/********************************************************************************
Step 7. Screen = 4216
   Message
********************************************************************************/
Step_7:
BEGIN
  IF @nInputKey = 1 OR @nInputKey = 0  -- ENTER / ESC
  BEGIN
     -- EventLog - QTY
     EXEC RDT.rdt_STD_EventLog
        @cActionType   = '5', -- RPL
        @cUserID       = @cUserName,
        @nMobileNo     = @nMobile,
        @nFunctionID   = @nFunc,
        @cFacility     = @cFacility,
        @cStorerKey    = @cStorerkey,
        @cLocation     = @cFromLOC,
        @cToLocation   = @cActToLOC,
        @cID           = @cFromID,
        @cSKU          = @cSKU,
        @cUOM          = @cMUOM_Desc,
        @nQTY          = @nActQty,
        @cReplenishmentKey = @cReplenishmentKey,
        @nStep         = @nStep

      -- Prep FromLOC screen
   --   SET @cFromLOC = ''
   --   SET @cFromID = ''
   --   SET @cOutField01 = '' -- FromLOC
   --   SET @cOutField02 = '' -- FromID

      --  - Start
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
      --  - End

      -- If No More Replenishment Go to WaveKey Screen
      IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                      WHERE WaveKey = @cWaveKey
                      AND AddWho = @cUserName
                      AND Confirmed = 'N'  )
      BEGIN
         DELETE FROM rdt.rdtReplenishmentLog
         WHERE AddWho = @cUserName

         -- Prepare next screen var
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         -- Go to next screen
         SET @nScn  = @nScn - 6
         SET @nStep = @nStep - 6

         GOTO QUIT
      END
      ELSE
      BEGIN


   --      SELECT TOP 1  @cSuggFromLoc = RP.FromLoc
   --                   ,@cSuggFromID  = RP.ID
   --                   ,@cReplenishmentKey = ReplenishmentKey
   --                   --,@cSuggestedLot     = RP.Lot
   --      FROM rdt.rdtReplenishmentLog RP WITH (NOLOCK)
   --      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.FromLoc
   --      WHERE RP.WaveKey = @cWaveKey
   --      AND RP.Confirmed = 'N'
   --      AND RP.AddWho = @cUserName
   --      --GROUP BY RP.FromLoc, Loc.LogicalLocation, RP.ID, RP.SKU--, RP.Lot
   --      ORDER By Loc.LogicalLocation, RP.SKU
   --
   --
   --      -- Prep next screen var
   --      SET @cOutField01 = @cSuggFromLoc
   --      SET @cOutField02 = ''
   --
   --      -- GOTO Next Screen
   --      SET @nScn = @nScn - 4
   --      SET @nStep = @nStep - 4
   --
   --
   --      GOTO QUIT


           -- Same FromLoc, FromID
           IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                        WHERE WaveKey = @cWaveKey
                        AND AddWho = @cUserName
                        AND Confirmed = 'N'
                        --AND ToLoc     = @cSuggToLoc
                        AND FromLoc   = @cFromLoc
                        AND ID        = @cFromID )
           BEGIN


              -- Display SKU Information
              -- Get 1st replenish task
              SELECT TOP 1
                 @cReplenishmentKey = ReplenishmentKey,
                 @cSuggSKU = SKU,
                 @cLOT = LOT,
                 @nQTY = QTY
                 --@cSuggToLOC = ToLOC
              FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
              WHERE StorerKey = @cStorerKey
                 AND FromLoc = @cFromLoc
                 AND ID = @cFromID
                 AND Confirmed = 'N'
                 AND WaveKey = @cWaveKey
                 AND AddWho = @cUserName
                 --AND ReplenishmentKey > @cReplenishmentKey
                 --AND SKU > @cSKU
              ORDER BY ReplenishmentKey


              IF @cReplenBySKU = '1'
              BEGIN

                 SELECT
                    @cLottableCode = LottableCode,
                    @cDescr = SKU.Descr,
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
                    @nPUOM_Div = CAST( IsNULL(
                       CASE @cPUOM
                          WHEN '2' THEN Pack.CaseCNT
                          WHEN '3' THEN Pack.InnerPack
                          WHEN '6' THEN Pack.QTY
                          WHEN '1' THEN Pack.Pallet
                          WHEN '4' THEN Pack.OtherUnit1
                          WHEN '5' THEN Pack.OtherUnit2
                       END, 1) AS INT)
                 FROM dbo.SKU SKU WITH (NOLOCK)
                    INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
                 WHERE SKU.StorerKey = @cStorerKey
                    AND SKU.SKU = @cSuggSKU

                 -- Convert to prefer UOM QTY
                 IF @cPUOM = '6' OR -- When preferred UOM = master unit
                    @nPUOM_Div = 0  -- UOM not setup
                 BEGIN
                    SET @cPUOM_Desc = ''
                    SET @nPQTY = 0
                    SET @nMQTY = @nQTY
                 END
                 ELSE
                 BEGIN
                    SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
                    SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
                 END


                 -- Dynamic lottable
                 SELECT
                       @cLottable01 = LA.Lottable01,
                       @cLottable02 = LA.Lottable02,
                       @cLottable03 = LA.Lottable03,
                       @dLottable04 = LA.Lottable04,
                       @dLottable05 = LA.Lottable05,
                       @cLottable06 = LA.Lottable06,
                       @cLottable07 = LA.Lottable07,
                       @cLottable08 = LA.Lottable08,
                       @cLottable09 = LA.Lottable09,
                       @cLottable10 = LA.Lottable10,
                       @cLottable11 = LA.Lottable11,
                       @cLottable12 = LA.Lottable12,
                       @dLottable13 = LA.Lottable13,
                       @dLottable14 = LA.Lottable14,
                       @dLottable15 = LA.Lottable15
                 FROM dbo.LotAttribute LA WITH (NOLOCK)
                 WHERE Lot = @cLot


                 EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSuggSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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

                  

                 -- Prep QTY screen var
                 SET @cOutField01 = ''
                 SET @cOutField02 = @cSuggSKU
                 SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
                 SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
      --           SET @cOutField09 = @cLottable01
      --           SET @cOutField05 = @cLottable02
      --           SET @cOutField06 = @cLottable03
      --           SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)

                 IF ISNULL(RTRIM(@cSuggSKU),'') <> ISNULL(RTRIM(@cSKU),'')
                 BEGIN
                    SET @nCountScanTask = 0
                    SET @nTotalTaskCount = 0
                    SELECT @nTotalTaskCount = Count(ReplenishmentKey)
                    FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                    WHERE StorerKey = @cStorerKey
                       AND FromLoc = @cFromLoc
                       AND ID = @cFromID
                       AND Confirmed = 'N'
                       AND WaveKey = @cWaveKey
                       AND SKU = @cSuggSKU
                       AND AddWho = @cUserName
                 END


                 SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))



                 IF @cPUOM_Desc = ''
                 BEGIN

                    --SET @cOutField08 = '' -- @cPUOM_Desc
                    SET @cOutField10 = '' -- @nPQTY
                    SET @cOutField12 = '' -- @nActPQTY
                    --SET @cOutField14 = '' -- @nPUOM_Div
                    -- Disable pref QTY field
                    SET @cFieldAttr12 = 'O'

                 END
                 ELSE
                 BEGIN
                    --SET @cOutField08 = @cPUOM_Desc
                    SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
                    SET @cOutField12 = '' -- @nActPQTY
                    --SET @cOutField14 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
                 END
                 --SET @cOutField09 = @cMUOM_Desc
                 SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
                 SET @cOutField13 = '' -- ActMQTY

                 --SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc

                 SET @cSKU = ''
                 SET @cInField12 = ''
                 SET @cInField13 = ''
              END
              ELSE
              BEGIN
                 SET @cOutField01 = ''
                 SET @cOutField02 = ''
                 SET @cOutField03 = ''
                 SET @cOutField04 = ''

                 SET @cOutField05 = ''
                 SET @cOutField06 = ''
                 SET @cOutField07 = ''
                 SET @cOutField08 = ''

                 SET @cOutField14 = ''
                 SET @cOutField10 = '' -- @nPQTY
                 SET @cOutField12 = '' -- @nActPQTY
                 SET @cOutField11 = ''
                 SET @cOutField13 = '' -- ActMQTY
                 SET @cOutField09 = ''


                 SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))

                 SET @cSKU = ''
                 SET @cInField12 = ''
                 SET @cInField13 = ''
                 SET @nActPQTY = 0
                 SET @nActMQTY = 0
              END

              IF @cNotDisplayQty  = '1'
              BEGIN
                  --SET @cOutField09 = ''
                  --SET @cOutField10 = ''
                  --SET @cOutField11 = ''

                  --SET @cFieldAttr09 = 'O'
                  --SET @cFieldAttr10 = 'O'
                  --SET @cFieldAttr11 = 'O'
                  SET @cFieldAttr12 = 'O'
                  SET @cFieldAttr13 = 'O'
              END
              
              -- (ChewKP04) 
              IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
              BEGIN
                 SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                    ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReplenishmentKey, @cPutawayZone, @cSuggestedLot,  @cOutInfo01 OUTPUT,' +
                    ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
                 SET @cSQLParam =
                    ' @nMobile      INT,           ' +
                    ' @nFunc        INT,           ' +
                    ' @cLangCode    NVARCHAR( 3),  ' +
                    ' @nStep        INT,           ' +
                    ' @nInputKey    INT,           ' +
                    ' @cStorerKey   NVARCHAR( 15), ' +
                    ' @cReplenishmentKey  NVARCHAR( 10), ' +
                    ' @cPutawayZone       NVARCHAR( 10), ' +
                    ' @cSuggestedLot      NVARCHAR( 10), ' +
                    ' @cOutInfo01    NVARCHAR( 60)   OUTPUT, ' +
                    ' @nErrNo        INT             OUTPUT, ' +
                    ' @cErrMsg       NVARCHAR( 20)   OUTPUT'

                 EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                    @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReplenishmentKey, @cPutawayZone, @cLOT, @cOutInfo01 OUTPUT,
                    @nErrNo      OUTPUT, @cErrMsg     OUTPUT

                 IF @nErrNo <> 0
                    GOTO Step_4_Fail

                SET @cOutfield14 = @cOutInfo01
			       SELECT  @cOutfield09 = SKU FROM LOTATTRIBUTE(NOLOCK) WHERE LOT =  @cLOT--CJ
              END
              ELSE
              BEGIN
                 SET @cOutField14 = '' --Optional Field
              END
                  
              SET @nActQTY = 0

              EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU


              -- Go to next screen
              SET @nScn  = @nScn - 2
              SET @nStep = @nStep - 2

              GOTO QUIT
           END

           -- Same FromLoc, Different ID
           IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                        WHERE WaveKey = @cWaveKey
                        AND AddWho = @cUserName
                        AND Confirmed = 'N'
                        --AND ToLoc     = @cSuggToLoc
                        AND FromLoc   = @cFromLoc
                        AND ID       <> @cFromID )
           BEGIN
              SELECT TOP 1  @cSuggFromLoc = RP.FromLoc
                           ,@cSuggFromID  = RP.ID
                           ,@cReplenishmentKey = RP.ReplenishmentKey
                           --,@cSuggestedLot     = RP.Lot
              FROM rdt.rdtReplenishmentLog RP WITH (NOLOCK)
              INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.FromLoc
              WHERE RP.WaveKey = @cWaveKey
              AND RP.Confirmed = 'N'
              AND RP.AddWho = @cUserName
              AND FromLoc   = @cFromLoc
              --GROUP BY RP.FromLoc, Loc.LogicalLocation, RP.ID, RP.SKU--, RP.Lot
              ORDER By Loc.LogicalLocation, Loc.Loc, RP.SKU


              SET @cOutField01 = @cFromLoc
              SET @cOutField02 = @cSuggFromID
              IF @cDefaultFromID = '1'
              BEGIN
                 SET @cOutField03 = @cSuggFromID
              END
              ELSE
              BEGIN
                 SET @cOutField03 = ''
              END

              SET @nScn = @nScn - 3
              SET @nStep = @nStep - 3

              GOTO QUIT
           END



           -- Different FromLoc, Different ID
           IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                        WHERE WaveKey = @cWaveKey
                        AND AddWho    = @cUserName
                        AND Confirmed = 'N'
                        --AND ToLoc     = @cSuggToLoc
                        AND FromLoc  <> @cFromLoc  )
           BEGIN
              SELECT TOP 1  @cSuggFromLoc = RP.FromLoc
                           ,@cSuggFromID  = RP.ID
                           ,@cReplenishmentKey = RP.ReplenishmentKey
                           --,@cSuggestedLot     = RP.Lot
              FROM rdt.rdtReplenishmentLog RP WITH (NOLOCK)
              INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.FromLoc
              WHERE RP.WaveKey = @cWaveKey
              AND RP.Confirmed = 'N'
              AND RP.AddWho = @cUserName
              --AND ToLoc     = @cSuggToLoc
              --GROUP BY RP.FromLoc, Loc.LogicalLocation, RP.ID, RP.SKU--, RP.Lot
              ORDER By Loc.LogicalLocation, Loc.Loc, RP.SKU


              SET @cOutField01 = @cSuggFromLoc
              SET @cOutField02 = ''
              SET @cOutField03 = ''

              SET @nScn = @nScn - 4
              SET @nStep = @nStep - 4

              GOTO QUIT

           END


      END
  END
--   EXEC rdt.rdtSetFocusField @nMobile, 1
--
--   -- Go to FromLOC screen
--   SET @nScn  = @nScn - 6
--   SET @nStep = @nStep - 6
END
GOTO Quit



/********************************************************************************
Step 8. Scn = 4217.
   SKU         (field01)
   1 = YES | 9 = NO
   Option      (field02, input)

********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      SET @cOption = ISNULL(RTRIM(@cInField01),'')

      IF @cOption = ''
      BEGIN
         SET @nErrNo = 93677
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionReq
         GOTO Step_8_Fail
      END

      IF @cOption NOT IN ( '1', '9' )
      BEGIN
         SET @nErrNo = 93678
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
         GOTO Step_8_Fail
      END

      IF @cOption = '1'
      BEGIN

         SET @nSKUValidated = 0

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cWaveKey, @cPutawayZone, @cActToLOC, @cSKU, @cLabelNo, @nActQTY, @cReplenishmentKey, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@nStep          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@cUserName      NVARCHAR( 18), ' +
               '@cFacility      NVARCHAR( 5),  ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cWaveKey       NVARCHAR( 10), ' +
               '@cPutawayZone   NVARCHAR( 10), ' +
               '@cActToLOC      NVARCHAR( 10), ' +
               '@cSKU           NVARCHAR( 20), ' +
               '@cLabelNo       NVARCHAR( 20), ' +
               '@nActQTY        INT, ' +
               '@cReplenishmentKey NVARCHAR(10), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cWaveKey, @cPutawayZone, @cActToLOC,  @cSKU, @cLabelNo, @nActQTY, @cReplenishmentKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_5_Fail
         END


         -- If No More Replenishment on the Same ToLoc Go to ToLoc Screen
         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                         WHERE WaveKey = @cWaveKey
                         AND AddWho = @cUserName
                         AND Confirmed = 'N'
                         --AND ToLoc     = @cSuggToLoc
                         AND FromLoc   = @cFromLoc )
         BEGIN


            SELECT @nReplenCount = Count(Rowref)
            FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
            WHERE WaveKey = @cWaveKey
            AND AddWho = @cUserName
            AND Confirmed = 'Y'
            AND FromLoc = @cFromLoc

            IF @nReplenCount > 0
            BEGIN

               -- Prepare next screen var
               -- Prep next screen var
               SET @cOutField01 = @cFromLoc
               SET @cOutField02 = @cFromID

               SELECT @cSuggToLoc = ToLoc
               FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND WaveKey = @cWaveKey
               AND ReplenishmentKey = @cReplenishmentKey

               SET @cOutField12 = @cSuggToLoc
               IF @cDefaultToLoc = '1'
               BEGIN
                  SET @cOutField13 = @cSuggToLoc
               END
               ELSE
               BEGIN
                  SET @cOutField13 = '' -- actual ToLOC
               END

               -- Go to next screen
               SET @nScn  = @nScn - 2
               SET @nStep = @nStep - 2

               GOTO QUIT
            END
            ELSE
            BEGIN
               -- No Confirmed = 'Y' Go to Next Loc
               GOTO NEXT_TASK
            END
         END
         ELSE
         BEGIN
            NEXT_TASK:
            -- Same FromLoc, FromID
            IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                         WHERE WaveKey = @cWaveKey
                         AND AddWho = @cUserName
                         AND Confirmed = 'N'
                         --AND ToLoc     = @cSuggToLoc
                         AND FromLoc   = @cFromLoc
                         AND ID        = @cFromID )
            BEGIN


               -- Display SKU Information
               -- Get 1st replenish task
               SELECT TOP 1
                  @cReplenishmentKey = ReplenishmentKey,
                  @cSuggSKU = SKU,
                  @cLOT = LOT,
                  @nQTY = QTY
                  --@cSuggToLOC = ToLOC
               FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND FromLoc = @cFromLoc
                  AND ID = @cFromID
                  AND Confirmed = 'N'
                  AND WaveKey = @cWaveKey
                  AND AddWho = @cUserName
                  --AND ReplenishmentKey > @cReplenishmentKey
                  --AND SKU > @cSKU
               ORDER BY ReplenishmentKey

              IF @cReplenBySKU = '1'
              BEGIN
                  SELECT
                     @cLottableCode = LottableCode,
                     @cDescr = SKU.Descr,
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
                     @nPUOM_Div = CAST( IsNULL(
                        CASE @cPUOM
                           WHEN '2' THEN Pack.CaseCNT
                           WHEN '3' THEN Pack.InnerPack
                           WHEN '6' THEN Pack.QTY
                           WHEN '1' THEN Pack.Pallet
                           WHEN '4' THEN Pack.OtherUnit1
                           WHEN '5' THEN Pack.OtherUnit2
                        END, 1) AS INT)
                  FROM dbo.SKU SKU WITH (NOLOCK)
                     INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
                  WHERE SKU.StorerKey = @cStorerKey
                     AND SKU.SKU = @cSuggSKU

                  -- Convert to prefer UOM QTY
                  IF @cPUOM = '6' OR -- When preferred UOM = master unit
                     @nPUOM_Div = 0  -- UOM not setup
                  BEGIN
                     SET @cPUOM_Desc = ''
                     SET @nPQTY = 0
                     SET @nMQTY = @nQTY
                  END
                  ELSE
                  BEGIN
                     SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
                     SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
                  END


                  -- Dynamic lottable
                  SELECT
                        @cLottable01 = LA.Lottable01,
                        @cLottable02 = LA.Lottable02,
                        @cLottable03 = LA.Lottable03,
                        @dLottable04 = LA.Lottable04,
                        @dLottable05 = LA.Lottable05,
                        @cLottable06 = LA.Lottable06,
                        @cLottable07 = LA.Lottable07,
                        @cLottable08 = LA.Lottable08,
                        @cLottable09 = LA.Lottable09,
                        @cLottable10 = LA.Lottable10,
                        @cLottable11 = LA.Lottable11,
                        @cLottable12 = LA.Lottable12,
                        @dLottable13 = LA.Lottable13,
                        @dLottable14 = LA.Lottable14,
                        @dLottable15 = LA.Lottable15
                  FROM dbo.LotAttribute LA WITH (NOLOCK)
                  WHERE Lot = @cLot



                  EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSuggSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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




                  -- Prep QTY screen var
                  SET @cOutField01 = ''
                  SET @cOutField02 = @cSuggSKU
                  SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
                  SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
   --               SET @cOutField09 = @cLottable01
   --               SET @cOutField05 = @cLottable02
   --               SET @cOutField06 = @cLottable03
   --               SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
                  --SET @cOutField14 = @cOutInfo01 --Optional Field
                  SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))



                  IF @cPUOM_Desc = ''
                  BEGIN

                     --SET @cOutField08 = '' -- @cPUOM_Desc
                     SET @cOutField10 = '' -- @nPQTY
                     SET @cOutField12 = '' -- @nActPQTY
                     --SET @cOutField14 = '' -- @nPUOM_Div
                     -- Disable pref QTY field
                     SET @cFieldAttr12 = 'O'

                  END
                  ELSE
                  BEGIN
                     --SET @cOutField08 = @cPUOM_Desc
                     SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
                     SET @cOutField12 = '' -- @nActPQTY
                     --SET @cOutField14 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
                  END
                  --SET @cOutField09 = @cMUOM_Desc
                  SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
                  SET @cOutField13 = '' -- ActMQTY
                  --SET @cOutField14 = @cOutInfo01
                  --SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc

                  SET @cSKU = ''
                  SET @cInField12 = ''
                  SET @cInField13 = ''
              END
              ELSE
              BEGIN

                  SET @cOutField01 = ''
                  SET @cOutField02 = ''
                  SET @cOutField03 = ''
                  SET @cOutField04 = ''

                  SET @cOutField05 = ''
                  SET @cOutField06 = ''
                  SET @cOutField07 = ''
                  SET @cOutField08 = ''

                  SET @cOutField14 = ''
                  SET @cOutField10 = '' -- @nPQTY
                  SET @cOutField12 = '' -- @nActPQTY
                  SET @cOutField11 = ''
                  SET @cOutField13 = '' -- ActMQTY
                  SET @cOutField09 = ''
                  SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))

                  SET @cSKU = ''
                  SET @cInField12 = ''
                  SET @cInField13 = ''
                  SET @nActPQTY = 0
                  SET @nActMQTY = 0

              END

              IF @cNotDisplayQty  = '1'
              BEGIN
                  --SET @cOutField09 = ''
                  --SET @cOutField10 = ''
                  --SET @cOutField11 = ''

                  --SET @cFieldAttr09 = 'O'
                  --SET @cFieldAttr10 = 'O'
                  --SET @cFieldAttr11 = 'O'
                  SET @cFieldAttr12 = 'O'
                  SET @cFieldAttr13 = 'O'
              END
              
              -- (ChewKP04) 
              IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
              BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReplenishmentKey, @cPutawayZone, @cSuggestedLot,  @cOutInfo01 OUTPUT,' +
                     ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
                  SET @cSQLParam =
                     ' @nMobile      INT,           ' +
                     ' @nFunc        INT,           ' +
                     ' @cLangCode    NVARCHAR( 3),  ' +
                     ' @nStep        INT,           ' +
                     ' @nInputKey    INT,           ' +
                     ' @cStorerKey   NVARCHAR( 15), ' +
                     ' @cReplenishmentKey  NVARCHAR( 10), ' +
                     ' @cPutawayZone       NVARCHAR( 10), ' +
                     ' @cSuggestedLot      NVARCHAR( 10), ' +
                     ' @cOutInfo01    NVARCHAR( 60)   OUTPUT, ' +
                     ' @nErrNo        INT             OUTPUT, ' +
                     ' @cErrMsg       NVARCHAR( 20)   OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReplenishmentKey, @cPutawayZone, @cLOT, @cOutInfo01 OUTPUT,
                     @nErrNo      OUTPUT, @cErrMsg     OUTPUT

                  IF @nErrNo <> 0
                     GOTO Step_4_Fail

                 SET @cOutfield14 = @cOutInfo01
			        SELECT  @cOutfield09 = SKU FROM LOTATTRIBUTE(NOLOCK) WHERE LOT =  @cLOT--CJ
              END
              ELSE
              BEGIN
                 SET @cOutField14 = '' --Optional Field
              END
              
              SET @nActQTY = 0

              EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU


              -- Go to next screen
              SET @nScn  = @nScn - 3
              SET @nStep = @nStep - 3

              GOTO QUIT
            END

            -- Same FromLoc, Different ID
            IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                         WHERE WaveKey = @cWaveKey
                         AND AddWho = @cUserName
                         AND Confirmed = 'N'
                         --AND ToLoc     = @cSuggToLoc
                         AND FromLoc   = @cFromLoc
                         AND ID       <> @cFromID )
            BEGIN
               SELECT TOP 1  @cSuggFromLoc = RP.FromLoc
                            ,@cSuggFromID  = RP.ID
                            ,@cReplenishmentKey = RP.ReplenishmentKey
                            --,@cSuggestedLot     = RP.Lot
               FROM rdt.rdtReplenishmentLog RP WITH (NOLOCK)
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.FromLoc
               WHERE RP.WaveKey = @cWaveKey
               AND RP.Confirmed = 'N'
               AND RP.AddWho = @cUserName
               AND FromLoc   = @cFromLoc
               --GROUP BY RP.FromLoc, Loc.LogicalLocation, RP.ID, RP.SKU--, RP.Lot
               ORDER By Loc.LogicalLocation, Loc.Loc, RP.SKU


               SET @cOutField01 = @cFromLoc
               SET @cOutField02 = @cSuggFromID
               IF @cDefaultFromID = '1'
               BEGIN
                  SET @cOutField03 = @cSuggFromID
               END
               ELSE
               BEGIN
                  SET @cOutField03 = ''
               END

               SET @nScn = @nScn - 4
               SET @nStep = @nStep - 4

               GOTO QUIT
            END

            -- Different FromLoc, Different ID
            IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                         WHERE WaveKey = @cWaveKey
                         AND AddWho    = @cUserName
                         AND Confirmed = 'N'
                         --AND ToLoc     = @cSuggToLoc
                         AND FromLoc  <> @cFromLoc )
            BEGIN
               SELECT TOP 1  @cSuggFromLoc = RP.FromLoc
                            ,@cSuggFromID  = RP.ID
                            ,@cReplenishmentKey = RP.ReplenishmentKey
                            --,@cSuggestedLot     = RP.Lot
               FROM rdt.rdtReplenishmentLog RP WITH (NOLOCK)
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.FromLoc
               WHERE RP.WaveKey = @cWaveKey
               AND RP.Confirmed = 'N'
               AND RP.AddWho = @cUserName
               --AND ToLoc     = @cSuggToLoc
               --GROUP BY RP.FromLoc, Loc.LogicalLocation, RP.ID, RP.SKU--, RP.Lot
               ORDER By Loc.LogicalLocation, Loc.Loc, RP.SKU


               SET @cOutField01 = @cSuggFromLoc
               SET @cOutField02 = ''
               SET @cOutField03 = ''

               SET @nScn = @nScn - 5
               SET @nStep = @nStep - 5

               GOTO QUIT

            END

            -- No More Task
            IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                         WHERE WaveKey = @cWaveKey
                         AND AddWho    = @cUserName
                         AND Confirmed = 'N' )
            BEGIN

               SET @cOutField01 = ''
               SET @cOutField02 = ''

               SET @nScn = @nScn - 7
               SET @nStep = @nStep - 7

               SET @nErrNo = 93687
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMoreTaskInZone

               GOTO QUIT
            END


         END

      END

      IF @cOption = '9'
      BEGIN

         -- If No Replenishment Done before, Go to WaveKey Screen

         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
                         WHERE AddWho = @cUserName
                         AND Confirmed = '1' )
         BEGIN

            DELETE FROM rdt.rdtReplenishmentLog
            WHERE AddWho = @cUserName

            SET @cOutField01 = ''
            SET @cOutField02 = ''

            -- Go to next screen
            SET @nScn  = @nScn - 7
            SET @nStep = @nStep - 7

            GOTO QUIT
         END
         ELSE
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cFromLoc
            SET @cOutField02 = @cFromID

            SELECT @cSuggToLoc = ToLoc
            FROM dbo.Replenishment WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND WaveKey = @cWaveKey
            AND ReplenishmentKey = @cReplenishmentKey

            SET @cOutField12 = @cSuggToLoc

            IF @cDefaultToLoc = '1'
            BEGIN
               SET @cOutField13 = @cSuggToLoc
            END
            ELSE
            BEGIN
               SET @cOutField13 = '' -- actual ToLOC
            END


            -- Go to next screen
            SET @nScn  = @nScn - 2
            SET @nStep = @nStep - 2

            GOTO QUIT
         END
      END




   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
         -- Display SKU Information
         -- Get 1st replenish task
         SELECT TOP 1
            --@cReplenishmentKey = ReplenishmentKey,
            @cSuggSKU = SKU,
            @cLOT = LOT,
            @nQTY = QTY
            --@cSuggToLOC = ToLOC
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND FromLoc = @cFromLoc
            AND ID = @cFromID
            --AND Confirmed = 'N'
            AND WaveKey = @cWaveKey
            AND AddWho = @cUserName
            AND ReplenishmentKey = @cReplenishmentKey
         ORDER BY ReplenishmentKey




         -- Get lottables
--         SELECT
--            @cLottable01 = Lottable01,
--            @cLottable02 = Lottable02,
--            @cLottable03 = Lottable03,
--            @dLottable04 = Lottable04
--         FROM dbo.LotAttribute WITH (NOLOCK)
--         WHERE StorerKey = @cStorerKey
--            AND SKU = @cSuggSKU
--            AND LOT = @cLOT
--
         -- Get Pack info
         IF @cReplenBySKU = '1'
         BEGIN
            SELECT
               @cLottableCode = LottableCode,
               @cDescr = SKU.Descr,
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
               @nPUOM_Div = CAST( IsNULL(
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END, 1) AS INT)
            FROM dbo.SKU SKU WITH (NOLOCK)
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSuggSKU

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @nMQTY = @nQTY
            END
            ELSE
            BEGIN
               SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
              SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
            END

            SELECT
                  @cLottable01 = LA.Lottable01,
                  @cLottable02 = LA.Lottable02,
                  @cLottable03 = LA.Lottable03,
                  @dLottable04 = LA.Lottable04,
                  @dLottable05 = LA.Lottable05,
                  @cLottable06 = LA.Lottable06,
                  @cLottable07 = LA.Lottable07,
                  @cLottable08 = LA.Lottable08,
                  @cLottable09 = LA.Lottable09,
                  @cLottable10 = LA.Lottable10,
                  @cLottable11 = LA.Lottable11,
                  @cLottable12 = LA.Lottable12,
                  @dLottable13 = LA.Lottable13,
                  @dLottable14 = LA.Lottable14,
                  @dLottable15 = LA.Lottable15
            FROM dbo.LotAttribute LA WITH (NOLOCK)
            WHERE Lot = @cLot


            -- Dynamic lottable
            EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSuggSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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

            -- Prep QTY screen var
            SET @cOutField01 = ''
            SET @cOutField02 = @cSuggSKU
            SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
            SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)


   --         SET @cOutField09 = @cLottable01
   --         SET @cOutField05 = @cLottable02
   --         SET @cOutField06 = @cLottable03
   --         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)

            SET @cOutField14 = @cOutInfo01
			   SELECT  @cOutfield09 = SKU FROM LOTATTRIBUTE(NOLOCK) WHERE LOT =  @cLOT--CJ
            -- Disable QTY field
            --SET @cFieldAttr12 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY
            --SET @cFieldAttr13 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY


            IF @cPUOM_Desc = ''
            BEGIN

               --SET @cOutField08 = '' -- @cPUOM_Desc
               SET @cOutField10 = '' -- @nPQTY
               SET @cOutField12 = '' -- @nActPQTY
               --SET @cOutField14 = '' -- @nPUOM_Div
               -- Disable pref QTY field
               SET @cFieldAttr12 = 'O'

            END
            ELSE
            BEGIN
               --SET @cOutField08 = @cPUOM_Desc
               SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
               SET @cOutField12 = '' -- @nActPQTY
               --SET @cOutField14 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
            END

            --SET @cOutField09 = @cMUOM_Desc
            SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
            --SET @cOutField13 = '' -- ActMQTY

            --SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc

            SET @cSKU = ''
            SET @cInField12 = @cActPQTY
            SET @cInField13 = @cActMQTY
         END
         ELSE
         BEGIN

            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''

            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''

            SET @cOutField14 = ''
            SET @cOutField10 = '' -- @nPQTY
            SET @cOutField12 = '' -- @nActPQTY
            SET @cOutField11 = ''
            SET @cOutField13 = '' -- ActMQTY
            SET @cOutField09 = ''
            SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))

            SET @cSKU = ''
            SET @cInField12 = ''
            SET @cInField13 = ''
            SET @nActPQTY = 0
            SET @nActMQTY = 0

         END

         IF @cNotDisplayQty  = '1'
         BEGIN
            --SET @cOutField09 = ''
            --SET @cOutField10 = ''
            --SET @cOutField11 = ''

            --SET @cFieldAttr09 = 'O'
            --SET @cFieldAttr10 = 'O'
            --SET @cFieldAttr11 = 'O'
            SET @cFieldAttr12 = 'O'
            SET @cFieldAttr13 = 'O'
         END

         SET @nActQTY = 0

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU

         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3




   END
   GOTO Quit

   STEP_8_FAIL:
   BEGIN

      -- Prepare Next Screen Variable
      SET @cOutField01 = @cSKU
      SET @cOutField02 = ''

   END
END
GOTO QUIT


/********************************************************************************
Step 9. Scn = 4218.
   EXIT REPLENISHMENT WITHOUT CONFIRM ?
   1 = YES | 9 = NO
   Option      (field02, input)

********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      SET @cOption = ISNULL(RTRIM(@cInField01),'')

      IF @cOption = ''
      BEGIN
         SET @nErrNo = 93681
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionReq
         GOTO Step_9_Fail
      END

      IF @cOption NOT IN ( '1', '9' )
      BEGIN
         SET @nErrNo = 93682
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
         GOTO Step_9_Fail
      END

      IF @cOption = '1'
      BEGIN

         DELETE FROM rdt.rdtReplenishmentLog WITH (ROWLOCK)
         WHERE AddWho = @cUserName

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 93683
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DELReplenLogFail
            GOTO Step_9_Fail
         END

         SET @cOutField01 = ''
         SET @cOutField02 = ''

         SET @nScn = @nScn - 8
         SET @nStep = @nStep - 8

         GOTO QUIT

      END

      IF @cOption = '9'
      BEGIN

         -- Prepare next screen var
         -- Prep next screen var
         SET @cOutField01 = @cFromLoc
         SET @cOutField02 = @cFromID

         SELECT @cSuggToLoc = ToLoc
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND WaveKey = @cWaveKey
         AND ReplenishmentKey = @cReplenishmentKey

         SET @cOutField12 = @cSuggToLoc
         IF @cDefaultToLoc = '1'
         BEGIN
            SET @cOutField13 = @cSuggToLoc
         END
         ELSE
         BEGIN
            SET @cOutField13 = '' -- actual ToLOC
         END

         -- Go to next screen
         SET @nScn  = @nScn - 3
         SET @nStep = @nStep - 3

         GOTO QUIT

      END




   END  -- Inputkey = 1

--   IF @nInputKey = 0
--   BEGIN
--
--
--   END
   GOTO Quit

   STEP_9_FAIL:
   BEGIN

      -- Prepare Next Screen Variable
      SET @cOutField01 = ''


   END
END
GOTO QUIT


/********************************************************************************
Step 10. Scn = 4219.
   From Loc     (field01) 
   From ID      (field02)
   Carton Count (field03, input)

********************************************************************************/
Step_10:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      SET @cTTLCartonCount = ISNULL(RTRIM(@cInField03),'')

      SET @cCountFail = '0' 

      IF RDT.rdtIsValidQTY( @cTTLCartonCount, 1) = 0
      BEGIN
         SET @nErrNo = 93692
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidValue'
         SET @cCountFail = '1'
         GOTO Step_10_Fail
      END

      IF @cExtendedValidateSP <> ''
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN

            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cReplenishmentKey, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cReplenishmentKey  NVARCHAR( 20), ' +
               '@cLabelNo           NVARCHAR( 20), ' +
               '@nErrNo             INT           OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20) OUTPUT'


            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cReplenishmentKey, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               SET @cCountFail = '1'
               GOTO Step_10_Fail
            END

         END
      END
      
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cWaveKey, @cPutawayZone, @cActToLOC, @cSKU, @cLabelNo, @nActQTY, @cReplenishmentKey, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile        INT, ' +
            '@nFunc          INT, ' +
            '@nStep          INT, ' +
            '@cLangCode      NVARCHAR( 3),  ' +
            '@cUserName      NVARCHAR( 18), ' +
            '@cFacility      NVARCHAR( 5),  ' +
            '@cStorerKey     NVARCHAR( 15), ' +
            '@cWaveKey       NVARCHAR( 10), ' +
            '@cPutawayZone   NVARCHAR( 10), ' +
            '@cActToLOC      NVARCHAR( 10), ' +
            '@cSKU           NVARCHAR( 20), ' +
            '@cLabelNo       NVARCHAR( 20), ' +
            '@nActQTY        INT, ' +
            '@cReplenishmentKey NVARCHAR(10), ' +
            '@nErrNo         INT           OUTPUT, ' +
            '@cErrMsg        NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cWaveKey, @cPutawayZone, @cActToLOC,  @cSKU, @cLabelNo, @nActQTY, @cReplenishmentKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            GOTO Step_10_Fail
         END

         
      END

      
         -- Go to next screen
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cFromID

      SELECT TOP 1 @cSuggToLoc = ToLoc
      FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND WaveKey = @cWaveKey
      --AND ReplenishmentKey = @cReplenishmentKey
      AND FromLoc = @cFromLoc
      AND ID      = @cfromID



      SET @cOutField12 = @cSuggToLoc

      IF @cDefaultToLoc = '1'
      BEGIN
         SET @cOutField13 = @cSuggToLoc
      END
      ELSE
      BEGIN
         SET @cOutField13 = '' -- actual ToLOC
      END
      
      SET @nScn  = @nScn - 4
      SET @nStep = @nStep - 4
      
      


   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN

      IF @cCountFail = '0' 
      BEGIN
         SET @cOutField01 = @cFromLoc
         SET @cOutField02 = @cSuggFromID

         IF @cDefaultFromID = '1'
         BEGIN
            SET @cOutField03 = @cSuggFromID
         END
         ELSE
         BEGIN
            SET @cOutField03 = ''
         END
      
         SET @nScn  = @nScn - 6
         SET @nStep = @nStep - 6
      END
      ELSE IF @cCountFail = '1' 
      BEGIN
         

         -- Display SKU Information
         -- Get 1st replenish task
         SELECT TOP 1
            --@cReplenishmentKey = ReplenishmentKey,
            @cSuggSKU = SKU,
            @cLOT = LOT,
            @nQTY = QTY
            --@cSuggToLOC = ToLOC
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND FromLoc = @cFromLoc
            AND ID = @cFromID
            AND Confirmed = 'N'
            AND WaveKey = @cWaveKey
            --AND ReplenishmentKey = @cReplenishmentKey
            AND AddWho = @cUserName
         ORDER BY ReplenishmentKey

         SET @nCountScanTask = 0
         SET @nTotalTaskCount = 0
         SELECT @nTotalTaskCount = Count(ReplenishmentKey)
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND FromLoc = @cFromLoc
            AND ID = @cFromID
            AND Confirmed = 'N'
            AND WaveKey = @cWaveKey
            AND SKU = CASE WHEN @cReplenBySKU = '1' THEN @cSuggSKU ELSE SKU END
            AND AddWho = @cUserName
         
         IF @cReplenBySKU = '1'
         BEGIN
            -- Get Pack info
            SELECT
               @cLottableCode = LottableCode,
               @cDescr = SKU.Descr,
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
               @nPUOM_Div = CAST( IsNULL(
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END, 1) AS INT)
            FROM dbo.SKU SKU WITH (NOLOCK)
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSuggSKU

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @nMQTY = @nQTY
            END
            ELSE
            BEGIN
               SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
               SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
            END


            -- Dynamic lottable
            SELECT
                  @cLottable01 = LA.Lottable01,
                  @cLottable02 = LA.Lottable02,
                  @cLottable03 = LA.Lottable03,
                  @dLottable04 = LA.Lottable04,
                  @dLottable05 = LA.Lottable05,
                  @cLottable06 = LA.Lottable06,
                  @cLottable07 = LA.Lottable07,
                  @cLottable08 = LA.Lottable08,
                  @cLottable09 = LA.Lottable09,
                  @cLottable10 = LA.Lottable10,
                  @cLottable11 = LA.Lottable11,
                  @cLottable12 = LA.Lottable12,
                  @dLottable13 = LA.Lottable13,
                  @dLottable14 = LA.Lottable14,
                  @dLottable15 = LA.Lottable15
            FROM dbo.LotAttribute LA WITH (NOLOCK)
            WHERE Lot = @cLot


            EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSuggSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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



            -- Prep QTY screen var
            SET @cOutField01 = ''
            SET @cOutField02 = @cSuggSKU
            SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
            SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)


            


            IF @cPUOM_Desc = ''
            BEGIN

               --SET @cOutField08 = '' -- @cPUOM_Desc
               SET @cOutField10 = '' -- @nPQTY
               SET @cOutField12 = '' -- @nActPQTY
               --SET @cOutField14 = '' -- @nPUOM_Div
               -- Disable pref QTY field
               SET @cFieldAttr12 = 'O'

            END
            ELSE
            BEGIN
               --SET @cOutField08 = @cPUOM_Desc
               SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
               SET @cOutField12 = '' -- @nActPQTY
               --SET @cOutField14 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
            END
            --SET @cOutField09 = @cMUOM_Desc
            SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
            SET @cOutField13 = '' -- ActMQTY

            SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc

            SET @nCountScanTask = 0
            SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))


            SET @cSKU = ''
            SET @cInField12 = ''
            SET @cInField13 = ''
            SET @nActPQTY = 0
            SET @nActMQTY = 0
         END
         ELSE
         BEGIN
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''

            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''

            SET @cOutField14 = ''
            SET @cOutField10 = '' -- @nPQTY
            SET @cOutField12 = '' -- @nActPQTY
            SET @cOutField11 = ''
            SET @cOutField13 = '' -- ActMQTY
            SET @cOutField09 = ''
            SET @nCountScanTask = 0
            SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))

            SET @cSKU = ''
            SET @cInField12 = ''
            SET @cInField13 = ''
            SET @nActPQTY = 0
            SET @nActMQTY = 0



         END

         IF @cNotDisplayQty  = '1'
         BEGIN
            --SET @cOutField09 = ''
            --SET @cOutField10 = ''
            --SET @cOutField11 = ''

            --SET @cFieldAttr09 = 'O'
            --SET @cFieldAttr10 = 'O'
            --SET @cFieldAttr11 = 'O'
            SET @cFieldAttr12 = 'O'
            SET @cFieldAttr13 = 'O'
         END
         
         -- (ChewKP04) 
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReplenishmentKey, @cPutawayZone, @cSuggestedLot,  @cOutInfo01 OUTPUT,' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cReplenishmentKey  NVARCHAR( 10), ' +
               ' @cPutawayZone       NVARCHAR( 10), ' +
               ' @cSuggestedLot      NVARCHAR( 10), ' +
               ' @cOutInfo01    NVARCHAR( 60)   OUTPUT, ' +
               ' @nErrNo        INT             OUTPUT, ' +
               ' @cErrMsg       NVARCHAR( 20)   OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReplenishmentKey, @cPutawayZone, @cLOT, @cOutInfo01 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_10_Fail

            SET @cOutfield14 = @cOutInfo01
			   SELECT  @cOutfield09 = SKU FROM LOTATTRIBUTE(NOLOCK) WHERE LOT =  @cLOT--CJ
         END
         ELSE
         BEGIN
            SET @cOutField14 = '' --Optional Field
         END
        
         SET @nActQTY = 0

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU

         SET @nScn = @nScn - 5 
         SET @nStep = @nStep - 5    
      END

   END
   GOTO Quit

   STEP_10_FAIL:
   BEGIN

      -- Prepare Next Screen Variable
      SET @cOutField03 = ''


   END
END
GOTO QUIT

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

      V_SKU     = @cSKU,
      V_SKUDescr= @cDescr,
      V_UOM     = @cPUOM,
      V_LOT     = @cLOT,
      V_LOC     = @cFromLoc,
      V_ID      = @cFromID,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,

      V_String1 = @cAllowOverWriteToLoc,
      V_String2 = @cActToLOC,
      V_String3 = @cMUOM_Desc,
      V_String4 = @cPUOM_Desc,
      V_String5 = @cExtendedInfoSP,
      V_String6 = @cDecodeSP,   
      V_String7 = @cFlowThruStep5,
      V_PUOM_Div = @nPUOM_Div,
      V_MQTY = @nMQTY,
      V_PQTY = @nPQTY,
      V_String12 = @cWaveKey,
      V_String13 = @cSuggFromLoc,
      V_String14 = @cSuggFromID,
      V_String15 = @cSuggSKU,
      V_String16 = @cSuggToLoc,
      V_String18 = @cReplenishmentKey,
      V_String19 = @cExtendedUpdateSP,
      V_String20 = @cExtendedValidateSP,
      V_String21 = @cOutInfo01,
      V_String23 = @cDecodeLabelNo,
      V_String24 = @cDefaultToLoc,
      V_String25 = @cDefaultFromID,
      V_String28 = @cReplenBySKU,
      V_String29 = @cNotDisplayQty,
      V_String30 = @cSwapLoc,
      V_String31 = @cReplenType,
      V_string32 = @cNotConfirmDPPReplen,
      V_String33 = @cPutAwayZone01, -- (ChewKP02)
      V_String34 = @cPutAwayZone02, -- (ChewKP02)
      V_String35 = @cPutAwayZone03, -- (ChewKP02)
      V_String36 = @cPutAwayZone04, -- (ChewKP02)
      V_String37 = @cPutAwayZone05, -- (ChewKP02)
      V_String38 = @cLastPAZone   , -- (ChewKP02)
      V_String39 = @cCountFail    , -- (ChewKP03) 
      V_STring40 = @cReplenByPallet, -- (ChewKP03) 
      
      V_Integer1 = @nActMQTY,
      V_Integer2 = @nActPQTY,
      V_Integer3 = @nActQty,
      V_Integer4 = @nQTY,
      V_Integer5 = @nSKUValidated,
      V_Integer6 = @nTotalTaskCount,
      V_Integer7 = @nCountScanTask,
                  
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
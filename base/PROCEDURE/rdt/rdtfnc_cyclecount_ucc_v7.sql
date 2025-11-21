SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_CycleCount_UCC_V7                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 06-May-2019 1.0  James    WMS-8649 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_CycleCount_UCC_V7] (
   @nMobile    INT,
   @nErrNo     INT            OUTPUT,
   @cErrMsg    NVARCHAR( 1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @b_success         INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR( 250),

   @cOptAction        NVARCHAR( 1),   -- 1=ADD, 2=EDIT
   @nRecCnt           INT,        -- Record count return from GetCCDetail

   @cCaseQty          NVARCHAR( 10),
   @cEachQty          NVARCHAR( 10),
   @nConvQTY          INT,
   @fConvQTY          FLOAT,

   @cNewCaseQTY       NVARCHAR( 10),
   @cNewEachQTY       NVARCHAR( 10),
   @cNewLottable04    NVARCHAR( 18),
   @cNewLottable05    NVARCHAR( 18),
   @cNewSKUDescr      NVARCHAR( 60),
   @cLotLabel01       NVARCHAR( 20),  -- labels
   @cLotLabel02       NVARCHAR( 20),
   @cLotLabel03       NVARCHAR( 20),
   @cLotLabel04       NVARCHAR( 20),
   @cLotLabel05       NVARCHAR( 20)

-- RDT.RDTMobRec variables
DECLARE
   @nFunc             INT,
   @nScn              INT,
   @nStep             INT,
   @cLangCode         NVARCHAR( 3),
   @nInputKey         INT,
   @nMenu             INT,

   @cStorerKey        NVARCHAR( 15),
   @cUserName         NVARCHAR( 18),
   @cFacility         NVARCHAR( 5),
   @cLOC              NVARCHAR( 10),
   @cID               NVARCHAR( 18),
   @cLOT              NVARCHAR( 10),
   @cSKU              NVARCHAR( 30),  --(ung01)
   @cSKUDescr         NVARCHAR( 60),
   @cUOM              NVARCHAR( 10),  -- Display NVARCHAR(3) (james19)
   @nQTY              INT,
   @cUCC              NVARCHAR( 20),
   @cLottable01       NVARCHAR( 18),
   @cLottable02       NVARCHAR( 18),
   @cLottable03       NVARCHAR( 18),
   @dLottable04       DATETIME,
   @dLottable05       DATETIME,
   @cLottable06       NVARCHAR( 30),
   @cLottable07       NVARCHAR( 30),
   @cLottable08       NVARCHAR( 30),
   @cLottable09       NVARCHAR( 30),
   @cLottable10       NVARCHAR( 30),
   @cLottable11       NVARCHAR( 30),
   @cLottable12       NVARCHAR( 30),
   @dLottable13       DATETIME,
   @dLottable14       DATETIME,
   @dLottable15       DATETIME,

   @cCCRefNo          NVARCHAR( 10),
   @cCCSheetNo        NVARCHAR( 10),
   @nCCCountNo        INT,
   @cSuggestLOC       NVARCHAR( 10),
   @cSuggestLogiLOC   NVARCHAR( 18),
   @nCntQTY           INT,
   @nTotCarton        INT,
   @cStatus           NVARCHAR( 10),
   @cPPK              NVARCHAR( 6),
   @cSheetNoFlag      NVARCHAR( 1),   -- (MaryVong01)
   @cLocType          NVARCHAR( 10),
   @cCCDetailKey      NVARCHAR( 10),
   @nUCCQTY           INT,
   @nCaseCnt          INT,
   @nCaseQTY          BIGINT,     -- (ChewKP01)
   @cCaseUOM          NVARCHAR( 10),   -- (james19)
   @nEachQTY          BIGINT,     -- (ChewKP01)
   @cEachUOM          NVARCHAR( 10),   -- (james19)
   @cLastLocFlag      NVARCHAR( 1),   -- (MaryVong01)
   @cDefaultCCOption  NVARCHAR( 1),   -- 1=UCC, 2=SKU/UPC, 3=SINGLE SKU SCAN
   @cOptCCType        NVARCHAR( 1),     -- 1=UCC, 2=SKU/UPC
   @cCountedFlag      NVARCHAR( 3),
   @cWithQtyFlag      NVARCHAR( 1),
   @nCountedQTY       INT,
   @cNewUCC           NVARCHAR( 20),
   @cNewSKU           NVARCHAR( 30), --(ung01)
   @cNewSKUDescr1     NVARCHAR( 20),
   @cNewSKUDescr2     NVARCHAR( 20),
   @nNewUCCQTY        INT,
   @nNewCaseCnt       INT,
--   @nNewCaseQTY       INT,
   @nNewCaseQTY       FLOAT,  -- (james08)
   @cNewCaseUOM       NVARCHAR( 10),    -- (james19)
--   @nNewEachQTY       NVARCHAR( 20),
   @nNewEachQTY       FLOAT,  -- (james08)
   @cNewEachUOM       NVARCHAR( 10),   -- (james19)
   @cNewPPK           NVARCHAR( 6),
   @cNewLottable01    NVARCHAR( 18),
   @cNewLottable02    NVARCHAR( 18),
   @cNewLottable03    NVARCHAR( 18),
   @dNewLottable04    DATETIME,
   @dNewLottable05    DATETIME,
   @cAddNewLocFlag    NVARCHAR( 1),   -- (MaryVong01)
   @cID_In            NVARCHAR( 18),  -- SOS79743
   @cRecountFlag      NVARCHAR( 1),   -- (MaryVong01)
   @nCCDLinesPerLOCID INT,        -- Total CCDetail Lines (LOC+ID)
   @cPrevCCDetailKey  NVARCHAR( 10),
   @nRowRef           INT,
   @cRetailSKU        NVARCHAR( 20),  -- (james07)
   @cSKUDefaultUOM    NVARCHAR( 30),    -- (james08)
   @c_PackKey         NVARCHAR( 10),    -- (james08)
   @f_Qty             FLOAT,        -- (james08)
   @nI                INT,          -- (james09)
   @cCheckStorer      NVARCHAR(15),   -- (Shong001)
   @nSYSQTY           INT,
   @cSYSID            NVARCHAR( 18),
   @nFromScn            INT,
   @nMorePage           INT,
   @nLottableOnPage     INT,
   @cLottableCode       NVARCHAR( 30)

DECLARE @c_debug  NVARCHAR(1)
   SET @c_debug = 0

-- SOS#81879 (Start)
DECLARE  @cLottable01_Code    NVARCHAR( 20),
     @cLottable02_Code    NVARCHAR( 20),
     @cLottable03_Code    NVARCHAR( 20),
     @cLottable04_Code    NVARCHAR( 20),
     @cLottable05_Code    NVARCHAR( 20), -- (MaryVong01)
     @cLottableLabel      NVARCHAR( 20),
     @cTempLottable01     NVARCHAR( 18),
     @cTempLottable02     NVARCHAR( 18),
     @cTempLottable03     NVARCHAR( 18),
     @cLottable04         NVARCHAR( 16),
     @cLottable05         NVARCHAR( 16),
     @dTemplottable04     DATETIME,
     @dTempLottable05     DATETIME,
-- SOS#81879 (End)

   -- (MaryVong01)
   @cHasLottable        NVARCHAR( 1),
   @cUCCConfig          NVARCHAR( 1),
   @cZone1              NVARCHAR( 10),
   @cZone2              NVARCHAR( 10),
   @cZone3              NVARCHAR( 10),
   @cZone4              NVARCHAR( 10),
   @cZone5              NVARCHAR( 10),
   @cAisle              NVARCHAR( 10),
   @cLevel              NVARCHAR( 10),
   @nCCDLinesPerLOC     INT,        -- Total CCDetail Lines (LOC)
   @cOption             NVARCHAR( 1),
   @cOverrideLOCConfig  NVARCHAR( 1),
   @dtNewLottable04     DATETIME,
   @dtNewLottable05     DATETIME,
   @nSetFocusField      INT,
   @cEmptyRecFlag       NVARCHAR( 1),     -- 'L' = LOC, 'D' = ID
   @cLockedByDiffUser   NVARCHAR( 1),
   @cFoundLockRec       NVARCHAR( 1),
   @cLockCCDetailKey    NVARCHAR( 10),
   @cAutoGotoIDLOCScnConfig NVARCHAR( 1), -- 1=On, the rest=Off
   @cMinCnt1Ind         NVARCHAR( 1),     -- Minimum Indicator for Counted_Cnt1
   @cMinCnt2Ind         NVARCHAR( 1),     -- Minimum Indicator for Counted_Cnt2
   @cMinCnt3Ind         NVARCHAR( 1),     -- Minimum Indicator for Counted_Cnt2
   @cEscSKU             NVARCHAR( 1), -- (Vicky03)
   @cEditSKU            NVARCHAR( 1), -- (Vicky03)
   @cCountType          NVARCHAR( 10),     -- (james10)
   @cBlindCount         NVARCHAR( 10),     -- (james10)
   @cCtnCount           NVARCHAR( 5),      -- (james10)
   @nPltCtnCount        INT,              -- (james10)
   @nCtnCount           INT,              -- (james10)
   @nTranCount          INT,              -- (james10)
   @nLOCConfirm         INT,              -- (james10)
   @cErrMsg1            NVARCHAR( 20),     -- (james10)
   @cErrMsg2            NVARCHAR( 20),     -- (james10)
   @cErrMsg3            NVARCHAR( 20),     -- (james10)
   @cErrMsg4            NVARCHAR( 20),     -- (james10)
   @cErrMsg5            NVARCHAR( 20),     -- (james10)
   @nNoOfTry            INT,               -- (james12)
   @cLastCountedLOC     NVARCHAR( 10),     -- (james12)
   @cSKUCountDefaultOpt NVARCHAR( 10),     -- (james14)
   @cDisplaySKU         NVARCHAR( 20),     -- (james15)
   @cDisplayLot01       NVARCHAR( 18),     -- (james15)
   @cDisplayLot02       NVARCHAR( 18),     -- (james15)
   @cDisplayLot03       NVARCHAR( 18),     -- (james15)
   @cDisplayLot04       NVARCHAR( 18),     -- (james15)
   @cValidateSKU        NVARCHAR( 20),     -- (james15)
   @cValidateLot01      NVARCHAR( 18),     -- (james15)
   @cValidateLot02      NVARCHAR( 18),     -- (james15)
   @cValidateLot03      NVARCHAR( 18),     -- (james15)
   @cValidateLot04      NVARCHAR( 18),     -- (james15)
   @nValidateSKU        INT,               -- (james15)
   @nValidateLot01      INT,               -- (james15)
   @nValidateLot02      INT,               -- (james15)
   @nValidateLot03      INT,               -- (james15)
   @nValidateLot04      INT,               -- (james15)

   @cDecodeLabelNo   NVARCHAR( 20),        -- (james18)
   @cLabel2Decode    NVARCHAR( 60),        -- (james18)
   @cCurSuggestLogiLOC     NVARCHAR( 10),  -- (james23)

   -- (james18)
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),

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

   -- (Vicky02) - Start
   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)
   -- (Vicky02) - End

DECLARE
   @cDecodeSP           NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cUPC                NVARCHAR( 30),
   @cFromID             NVARCHAR( 18),
   @cToLOC              NVARCHAR( 10),
   @cUserDefine01       NVARCHAR( 60),
   @cUserDefine02       NVARCHAR( 60),
   @cUserDefine03       NVARCHAR( 60),
   @cUserDefine04       NVARCHAR( 60),
   @cUserDefine05       NVARCHAR( 60),
   @cSKUCode            NVARCHAR( 20),
   @cSQL                NVARCHAR( 1000),
   @cSQLParam           NVARCHAR( 1000)

-- Getting Mobile information
SELECT
   @nFunc             = Func,
   @nScn              = Scn,
   @nStep             = Step,
   @nInputKey         = InputKey,
   @nMenu             = Menu,
   @cLangCode         = Lang_code,

   @cStorerKey        = StorerKey,
   @cFacility         = Facility,
   @cUserName         = UserName,
   @cLOC              = V_LOC,
   @cID               = V_ID,
   @cLOT              = V_LOT,
   @cSKU              = V_SKU,
   @cSKUDescr         = V_SKUDescr,
   @cUOM              = V_UOM,
--   @nQTY              = CASE WHEN rdt.rdtIsValidQTY( V_QTY, 0) = 1 THEN V_QTY ELSE 0 END,
   @cUCC              = V_UCC,
   @cLottable01       = V_Lottable01,
   @cLottable02       = V_Lottable02,
   @cLottable03       = V_Lottable03,
   @dLottable04       = V_Lottable04,
   @dLottable05       = V_Lottable05,

   @nQTY              = V_Integer1,
   @nCCCountNo        = V_Integer2,
   @nCntQTY           = V_Integer3,
   @nTotCarton        = V_Integer4,
   @nUCCQTY           = V_Integer5,
   @nCaseCnt          = V_Integer6,
   @nCaseQTY          = V_Integer7,
   @nEachQTY          = V_Integer8,
   @nNewUCCQTY        = V_Integer9,
   @nNewCaseCnt       = V_Integer10,
   @nNewCaseQTY       = V_Integer11,
   @nNewEachQTY       = V_Integer12,
   @nCCDLinesPerLOCID = V_Integer13,
   @nCtnCount         = V_Integer14,
   @nFromScn          = V_Integer15,
   
   @dNewLottable04    = V_DateTime1, 
   @dNewLottable05    = V_DateTime2,
   
   @cCCRefNo          = V_String1,
   @cCCSheetNo        = V_String2,
   @cLottableCode     = V_String3,
--   @nCCCountNo        = CASE WHEN rdt.rdtIsValidQTY( V_String3, 0) = 1 THEN V_String3 ELSE 0 END,
   @cSuggestLOC       = V_String4,
   @cSuggestLogiLOC   = V_String5,
--   @nCntQTY           = CASE WHEN rdt.rdtIsValidQTY( V_String6, 0) = 1 THEN V_String6 ELSE 0 END,
--   @nTotCarton        = CASE WHEN rdt.rdtIsValidQTY( V_String7, 0) = 1 THEN V_String7 ELSE 0 END,
   @cStatus           = V_String8,
   @cPPK              = V_String9,
-- @cUCCConfig       = V_String10,
   @cSheetNoFlag      = V_String10, -- (MaryVong01)
   @cLocType          = V_String11,
   @cCCDetailKey      = V_String12,
--   @nUCCQTY           = CASE WHEN rdt.rdtIsValidQTY( V_String13, 0) = 1 THEN V_String13 ELSE 0 END,
--   @nCaseCnt          = CASE WHEN rdt.rdtIsValidQTY( V_String14, 0) = 1 THEN V_String14 ELSE 0 END,
   --@nCaseQTY          = CASE WHEN rdt.rdtIsValidQTY( V_String15, 0) = 1 THEN V_String15 ELSE 0 END,
--   @nCaseQTY          = CASE WHEN ISNUMERIC(V_String15) = 1 THEN V_String15 ELSE 0 END, -- (ChewKP01)
   @cCaseUOM          = V_String16,
--   @nEachQTY          = CASE WHEN ISNUMERIC(V_String17) = 1 THEN V_String17 ELSE 0 END, -- (ChewKP01)
   --@nEachQTY          = CASE WHEN rdt.rdtIsValidQTY( V_String17, 0) = 1 THEN V_String17 ELSE 0 END,
   @cEachUOM          = V_String18,
   --@cHasLottable     = V_String19,
   @cLastLocFlag      = V_String19, -- (MaryVong01)
   @cDefaultCCOption  = V_String20,

   @cCountedFlag      = V_String21,
   @cWithQtyFlag      = V_String22,

   @cNewUCC           = V_String23,
   @cNewSKU           = V_String24,
   @cNewSKUDescr1     = V_String25,
   @cNewSKUDescr2     = V_String26,
--   @nNewUCCQTY        = CASE WHEN rdt.rdtIsValidQTY( V_String27, 0) = 1 THEN V_String27 ELSE 0 END,
--   @nNewCaseCnt       = CASE WHEN rdt.rdtIsValidQTY( V_String28, 0) = 1 THEN V_String28 ELSE 0 END,
--   @nNewCaseQTY       = CASE WHEN rdt.rdtIsValidQTY( V_String29, 0) = 1 THEN CAST(V_String29 AS FLOAT) ELSE 0 END,
   @cNewCaseUOM       = V_String30,
--   @nNewEachQTY       = CASE WHEN rdt.rdtIsValidQTY( V_String31, 0) = 1 THEN CAST(V_String31 AS FLOAT) ELSE 0 END,
   @cNewEachUOM       = V_String32,
   @cNewPPK           = V_String33,
   @cNewLottable01    = V_String34,
   @cNewLottable02    = V_String35,
   @cNewLottable03    = V_String36,
--   @dNewLottable04    = CASE WHEN rdt.rdtIsValidDate (V_String37) = 1 THEN V_String37 ELSE NULL END,
--   @dNewLottable05    = CASE WHEN rdt.rdtIsValidDate (V_String38) = 1 THEN V_String38 ELSE NULL END,
--   @cLottable05_Code = V_String39,
   @cAddNewLocFlag    = V_String39,     -- (MaryVong01)
   @cID_In            = V_String40,     -- SOS79743
   @cRecountFlag      = V_ReceiptKey,   -- (MaryVong01) - Used for Recount
--   @nCCDLinesPerLOCID = CASE WHEN rdt.rdtIsValidQTY( V_POKey, 0) = 1 THEN V_POKey ELSE 0 END, -- Total CCDetail Lines (LOC+ID)
   @cPrevCCDetailKey  = V_LoadKey,      -- (MaryVong01) - Used to control Counter in SKU screen
--   @cEscSKU           = V_OrderKey, -- (Vicky03)    comment by james12. not in use anymore
   @cEditSKU          = V_PickSlipNo, -- (Vicky03)
   @cBlindCount       = V_ConsigneeKey,    -- (james10)
--   @nCtnCount         = CASE WHEN rdt.rdtIsValidQTY(V_CaseID, 0) = 1 THEN V_CaseID ELSE 0 END,      -- (james17)
--   @nNoOfTry          = CASE WHEN rdt.rdtIsValidQTY(V_OrderKey, 0) = 1 THEN V_OrderKey ELSE 0 END,  -- (james17)
   @cCurSuggestLogiLOC = V_String41,

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

   -- (Vicky02) - Start
   @cFieldAttr01 = FieldAttr01,     @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15
   -- (Vicky02) - End

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_CCRef                    INT,  @nScn_CCRef                    INT,
   @nStep_SheetNo_Criteria         INT,  @nScn_SheetNo_Criteria         INT, -- (MaryVong01)
   @nStep_CountNo                  INT,  @nScn_CountNo                  INT,
   @nStep_LOC                      INT,  @nScn_LOC                      INT,
   @nStep_LOC_Option               INT,  @nScn_LOC_Option               INT, -- (MaryVong01)
   @nStep_LAST_LOC_Option          INT,  @nScn_LAST_LOC_Option          INT, -- (MaryVong01)
   @nStep_RECOUNT_LOC_Option       INT,  @nScn_RECOUNT_LOC_Option       INT, -- (MaryVong01)
   @nStep_ID                       INT,  @nScn_ID                       INT,
   @nStep_UCC                      INT,  @nScn_UCC                      INT,
   @nStep_UCC_Add_Ucc              INT,  @nScn_UCC_Add_Ucc              INT,
   @nStep_UCC_Add_SkuQty           INT,  @nScn_UCC_Add_SkuQty           INT,
   @nStep_UCC_Add_Lottables        INT,  @nScn_UCC_Add_Lottables        INT,
   @nStep_UCC_Edit_QTY             INT,  @nScn_UCC_Edit_QTY             INT
   
SELECT
   @nStep_CCRef                    = 1,  @nScn_CCRef                    = 5410,
   @nStep_SheetNo_Criteria         = 2,  @nScn_SheetNo_Criteria         = 5411, 
   @nStep_CountNo                  = 3,  @nScn_CountNo                  = 5412,
   @nStep_LOC                      = 4,  @nScn_LOC                      = 5413,
   @nStep_LOC_Option               = 5,  @nScn_LOC_Option               = 5414, 
   @nStep_LAST_LOC_Option          = 6,  @nScn_LAST_LOC_Option          = 5415, 
   @nStep_RECOUNT_LOC_Option       = 7,  @nScn_RECOUNT_LOC_Option       = 5416, 
   @nStep_ID                       = 8,  @nScn_ID                       = 5417,
   @nStep_UCC                      = 9,  @nScn_UCC                      = 5418,
   @nStep_UCC_Add_Ucc              = 10, @nScn_UCC_Add_Ucc              = 5419,
   @nStep_UCC_Add_SkuQty           = 11, @nScn_UCC_Add_SkuQty           = 5420,
   @nStep_UCC_Add_Lottables        = 12, @nScn_UCC_Add_Lottables        = 5421,
   @nStep_UCC_Edit_QTY             = 23, @nScn_UCC_Edit_QTY             = 5422


IF @nFunc = 634 -- RDT Cycle Count
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start                    -- Menu. Func = 635
   IF @nStep = 1  GOTO Step_CCRef                    -- Scn = 5410. CCREF
   IF @nStep = 2  GOTO Step_SheetNo_Criteria         -- Scn = 5411. SHEET NO OR Selection Criteria
   IF @nStep = 3  GOTO Step_CountNo                  -- Scn = 5412. COUNT NO
   IF @nStep = 4  GOTO Step_LOC                      -- Scn = 5413. LOC
   IF @nStep = 5  GOTO Step_LOC_Option               -- Scn = 5414. LOC - Option
   IF @nStep = 6  GOTO Step_LAST_LOC_Option          -- Scn = 5415. Last LOC - Option
   IF @nStep = 7  GOTO Step_RECOUNT_LOC_Option       -- Scn = 5416. Re-Count LOC - Option
   IF @nStep = 8  GOTO Step_ID                       -- Scn = 5417. ID
   IF @nStep = 9  GOTO Step_UCC                      -- Scn = 5418. UCC
   IF @nStep = 10 GOTO Step_UCC_Add_Ucc              -- Scn = 5419. UCC - Add UCC
   IF @nStep = 11 GOTO Step_UCC_Add_SkuQty           -- Scn = 5420. UCC - Add SKU & QTY
   IF @nStep = 12 GOTO Step_UCC_Add_Lottables        -- Scn = 5421. UCC - Add LOTTABLE01..05
   IF @nStep = 13 GOTO Step_UCC_Edit_QTY             -- Scn = 5422. UCC - Edit QTY

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 634. Screen 0.
********************************************************************************/
Step_Start:
BEGIN
   -- Clear the incomplete task for the same login
   DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
   WHERE AddWho = @cUserName
   AND Status = '0'

   SELECT
      @cOutField01   = '',
      @cOutField02   = '',
      @cOutField03   = '',
      @cOutField04   = '',
      @cOutField05   = '',
      @cOutField06   = '',
      @cOutField07   = '',
      @cOutField08   = '',
      @cOutField09   = '',
      @cOutField10 = '',
      @cOutField11   = '',
      @cOutField12   = '',
      @cOutField13   = '',
      @cOutField14   = '',
      @cOutField15   = ''

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

      -- (Vicky03) - Start
      SET @cCCRefNo = ''
      SET @cCCSheetNo = ''
      SET @nCCCountNo = 1
      SET @cSuggestLOC = ''
      SET @cSuggestLogiLOC = ''
      SET @nCntQTY = 0
      SET @nTotCarton = 0
      SET @cSheetNoFlag = ''
      SET @cLocType = ''
      SET @cCCDetailKey = ''
      SET @nUCCQTY = 0
      SET @nCaseCnt = 0
      SET @nCaseQTY = 0
      SET @cCaseUOM = ''
      SET @nEachQTY = 0
      SET @cEachUOM = ''
      SET @cLastLocFlag = ''
      SET @cDefaultCCOption = ''
      SET @cAddNewLocFlag = ''
      SET @cRecountFlag = ''
      SET @nCCDLinesPerLOCID = 0
      SET @cPrevCCDetailKey =  ''
      SET @cEscSKU = ''
      SET @cEditSKU = ''
      -- (Vicky03) - End

      SET @nScn = @nScn_CCRef   -- 5410
      SET @nStep = @nStep_CCRef -- 1
END
GOTO Quit

/************************************************************************************
Step_CCRef. Scn = 5410. Screen 1.
   CCREF (field01)   - Input field
************************************************************************************/
Step_CCRef:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCCRefNo = @cInField01

       -- Retain the key-in value
       SET @cOutField01 = @cCCRefNo

      -- Validate CCKey
      IF @cCCRefNo = '' OR @cCCRefNo IS NULL
      BEGIN
      SET @nErrNo = 62081
         SET @cErrMsg = rdt.rdtgetmessage( 62081, @cLangCode, 'DSP') -- 'CCREF required'
         GOTO CCRef_Fail
      END

      -- Validate with CCDETAIL
      IF NOT EXISTS (SELECT 1 --TOP 1 CCKey
                     FROM dbo.CCDETAIL (NOLOCK)
                     WHERE CCKey = @cCCRefNo)
      BEGIN
         SET @nErrNo = 62082
         SET @cErrMsg = rdt.rdtgetmessage( 62082, @cLangCode, 'DSP') -- 'Invalid CCREF'
         GOTO CCRef_Fail
      END

      -- Validate with StockTakeSheetParameters
      IF NOT EXISTS (SELECT TOP 1 StockTakeKey
                     FROM dbo.StockTakeSheetParameters (NOLOCK)
                     WHERE StockTakeKey = @cCCRefNo)
      BEGIN
         SET @nErrNo = 62083
         SET @cErrMsg = rdt.rdtgetmessage( 62083, @cLangCode, 'DSP') -- 'Setup CCREF'
         GOTO CCRef_Fail
      END

      EXEC rdt.rdtSetFocusField @nMobile, 2
      SET @nCCCountNo=1
      SELECT @nCCCountNo = CASE WHEN ISNULL(STSP.FinalizeStage,0) = 0 THEN 1
                                WHEN STSP.FinalizeStage = 1 THEN 2
                                WHEN STSP.FinalizeStage = 2 THEN 3
                           END
      FROM dbo.StockTakeSheetParameters STSP (NOLOCK)
      WHERE StockTakeKey = @cCCRefNo

      IF ISNULL(@nCCCountNo,0) = 0
      BEGIN
         SET @nErrNo = 62083
         SET @cErrMsg = rdt.rdtgetmessage( 62083, @cLangCode, 'DSP') -- 'Setup CCREF'
         GOTO CCRef_Fail
      END

      -- Check if it is blind count/blank count (james10)


      -- Prepare next screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = ''         -- SheetNo
      SET @cOutField03 = 'ALL'      -- Zone1
      SET @cOutField04 = ''         -- Zone2
      SET @cOutField05 = ''         -- Zone3
      SET @cOutField06 = ''         -- Zone4
      SET @cOutField07 = ''         -- Zone5
      SET @cOutField08 = 'ALL'      -- Aisle
      SET @cOutField09 = 'ALL'      -- Level

      -- Go to next screen
      SET @nScn = @nScn_SheetNo_Criteria
      SET @nStep = @nStep_SheetNo_Criteria
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- CCREF
      SET @cOptCCType  = ''  -- SOS# 143022: Reset option value

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option

-- (Vicky02) - Start
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
      -- (Vicky02) - End
   END
   GOTO Quit

   CCRef_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- CCREF
   END
END
GOTO Quit

/************************************************************************************
Step_SheetNo_Criteria. Scn = 661. Screen 2.
   CCREF (field01)
   SHEET (field02)   - Input field
   ZONE1 (field03)   - Input field
   ZONE2 (field04)   - Input field
   ZONE3 (field05)   - Input field
   ZONE4 (field06)   - Input field
   ZONE5 (field07)   - Input field
   AISLE (field08)   - Input field
   LEVEL (field09)   - Input field
************************************************************************************/
Step_SheetNo_Criteria:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCCSheetNo = @cInField02
      SET @cZone1     = @cInField03
      SET @cZone2     = @cInField04
      SET @cZone3     = @cInField05
      SET @cZone4     = @cInField06
      SET @cZone5     = @cInField07
      SET @cAisle     = @cInField08
      SET @cLevel     = @cInField09

      -- Retain the key-in value
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = @cZone1
      SET @cOutField04 = @cZone2
      SET @cOutField05 = @cZone3
      SET @cOutField06 = @cZone4
      SET @cOutField07 = @cZone5
      SET @cOutField08 = @cAisle
      SET @cOutField09 = @cLevel

   -- (MaryVong01)
      -- SheetNo and Zones/Aisle/Level are blank
      IF (@cCCSheetNo = '' OR @cCCSheetNo IS NULL) AND
       (@cZone1 = '' OR @cZone1 IS NULL) AND
         (@cZone2 = '' OR @cZone2 IS NULL) AND
         (@cZone3 = '' OR @cZone3 IS NULL) AND
         (@cZone4 = '' OR @cZone4 IS NULL) AND
         (@cZone5 = '' OR @cZone5 IS NULL) AND
         (@cAisle = '' OR @cAisle IS NULL) AND
         (@cLevel = '' OR @cLevel IS NULL)
      BEGIN
         SET @nErrNo = 62084
         SET @cErrMsg = rdt.rdtgetmessage( 62084, @cLangCode, 'DSP') -- 'SHEET required'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO SheetNo_Criteria_Fail
      END

      -- ONLY allow SheetNo or Criteria
      IF (@cCCSheetNo <> '' AND @cCCSheetNo IS NOT NULL) AND
         ( (@cZone1 <> 'ALL' AND @cZone1 <> '' AND @cZone1 IS NOT NULL) OR
           (@cZone2 <> '' AND @cZone2 IS NOT NULL) OR
           (@cZone3 <> '' AND @cZone3 IS NOT NULL) OR
           (@cZone4 <> '' AND @cZone4 IS NOT NULL) OR
           (@cZone5 <> '' AND @cZone5 IS NOT NULL) OR
           (@cAisle <> 'ALL' AND @cAisle <> '' AND @cAisle IS NOT NULL) OR
           (@cLevel <> 'ALL' AND @cLevel <> '' AND @cLevel IS NOT NULL) )
      BEGIN
         SET @nErrNo = 62137
         SET @cErrMsg = rdt.rdtgetmessage( 62137, @cLangCode, 'DSP') -- 'Sheet/Criteria'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO SheetNo_Criteria_Fail
      END

      -- Among 5 Zones, ONLY Zone1 allowed 'ALL'
      IF ( (@cZone2 = 'ALL' AND @cZone2 <> '' AND @cZone2 IS NOT NULL) OR
           (@cZone3 = 'ALL' AND @cZone3 <> '' AND @cZone3 IS NOT NULL) OR
           (@cZone4 = 'ALL' AND @cZone4 <> '' AND @cZone4 IS NOT NULL) OR
           (@cZone5 = 'ALL' AND @cZone5 <> '' AND @cZone5 IS NOT NULL) )
      BEGIN
         SET @nErrNo = 62138
         SET @cErrMsg = rdt.rdtgetmessage( 62138, @cLangCode, 'DSP') -- 'Wrong Zone'
         IF @cZone2 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 4
         IF @cZone3 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 5
         IF @cZone4 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 6
         IF @cZone5 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO SheetNo_Criteria_Fail
      END

      -- Initialize indicator
      SET @cMinCnt1Ind = '0'
      SET @cMinCnt2Ind = '0'
      SET @cMinCnt3Ind = '0'

      IF @cCCSheetNo <> '' AND @cCCSheetNo IS NOT NULL
      BEGIN
         -- (MaryVong01)
         SET @cSheetNoFlag = 'Y'

         -- Validate with CCDETAIL
         IF NOT EXISTS (SELECT TOP 1 CCDETAIL.CCKey
                        FROM dbo.CCDETAIL CCDETAIL (NOLOCK)
                        JOIN dbo.StockTakeSheetParameters STK (NOLOCK)
                           ON STK.StockTakeKey = CCDETAIL.CCKEY
                        WHERE CCDETAIL.CCKey = @cCCRefNo
                        AND   CCDETAIL.CCSheetNo = @cCCSheetNo)
         BEGIN
            SET @nErrNo = 62085
            SET @cErrMsg = rdt.rdtgetmessage( 62085, @cLangCode, 'DSP') -- 'Invalid SHEET'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO SheetNo_Criteria_Fail
         END

         -- Release locked record
         DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
         WHERE Mobile = @nMobile
         AND AddWho = @cUserName
         -- AND Status = '0'  -- (Vicky03)


         -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
         SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                @cMinCnt2Ind = MIN(Counted_Cnt2),
                @cMinCnt3Ind = MIN(Counted_Cnt3)
         FROM dbo.CCDETAIL CCD WITH (NOLOCK)           WHERE CCD.CCKey = @cCCRefNo
         AND CCD.CCSheetNo = @cCCSheetNo

         -- If configkey not turned on then proceed with insert CCDetail record to lock (james05)
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorerKey) <> '1'
 BEGIN
            -- Insert into RDTCCLock
   INSERT INTO RDT.RDTCCLock
               (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,
               Zone1, Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,
               StorerKey,  Sku,        Lot,         Loc, Id,
               Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,
               SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)
            SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey, CCD.CCSheetNo,  @nCCCountNo,
               @cZone1,        @cZone2,        @cZone3,         @cZone4,        @cZone5,       @cAisle, @cLevel,
               CCD.StorerKey,  CCD.SKU,        CCD.LOT,         CCD.LOC,        CCD.ID,
               CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,  CCD.Lottable04, CCD.Lottable05,
               CCD.SystemQty,
               --   CASE WHEN @nCCCountNo = 1 THEN CCD.Qty
               --        WHEN @nCCCountNo = 2 THEN CCD.Qty_Cnt2
               --        WHEN @nCCCountNo = 3 THEN CCD.Qty_Cnt3
               --   END,
               CASE WHEN @cMinCnt1Ind = '0' THEN CCD.Qty
                    WHEN @cMinCnt2Ind = '0' THEN CCD.Qty_Cnt2
                    WHEN @cMinCnt3Ind = '0' THEN CCD.Qty_Cnt3
               END,
               '0',             '',             @cUserName,     GETDATE()
            FROM dbo.CCDETAIL CCD WITH (NOLOCK)
            WHERE CCD.CCKey = @cCCRefNo
            AND CCD.CCSheetNo = @cCCSheetNo
            -- Only select uncounted record
            AND 1 = CASE
                       WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                       WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
                       WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
                    ELSE 0
                    END

            IF @@ROWCOUNT = 0 -- No data in CCDetail
            BEGIN
               SET @nErrNo = 66835
               SET @cErrMsg = rdt.rdtgetmessage( 66835, @cLangCode, 'DSP') -- 'Blank Record'
               GOTO QUIT
            END
         END

        -- Prepare next screen var
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = @nCCCountNo -- CNT NO (Shong01)
      END
           -- (MaryVong01)
      ELSE -- Key-in Zones/Aisle/Level
      BEGIN
         -- Release locked record
         DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
         WHERE Mobile = @nMobile
         AND AddWho = @cUserName
         -- AND Status = '0'     -- (Vicky03)

         -- Performance tuning
         IF @cZone1 = 'ALL'
            -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
            SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                  @cMinCnt2Ind = MIN(Counted_Cnt2),
                  @cMinCnt3Ind = MIN(Counted_Cnt3)
            FROM dbo.CCDETAIL CCD WITH (NOLOCK)
            INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
            WHERE CCD.CCKey = @cCCRefNo
            AND LOC.Facility = @cFacility
            AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END
            AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END
         ELSE
            -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
            SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                  @cMinCnt2Ind = MIN(Counted_Cnt2),
                  @cMinCnt3Ind = MIN(Counted_Cnt3)
            FROM dbo.CCDETAIL CCD WITH (NOLOCK)
            INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
            WHERE CCD.CCKey = @cCCRefNo
            AND LOC.Facility = @cFacility
      AND LOC.PutawayZone IN (@cZone1, @cZone2, @cZone3, @cZone4, @cZone5)
            AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END
          AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END

         -- If configkey not turned on then proceed with insert CCDetail record to lock (james05)
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorerKey) <> '1'
         BEGIN
            IF @cZone1 = 'ALL'
               -- Insert RDTCCLock
               INSERT INTO RDT.RDTCCLock
                  (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,
                  Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,   Level,
                  StorerKey,  Sku,        Lot,         Loc,        Id,
                  Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,
                  SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)
               SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey,  @cCCSheetNo,    0,
                      @cZone1,        @cZone2,        @cZone3, @cZone4, @cZone5,        @cAisle,        @cLevel,
                      CCD.StorerKey,  CCD.SKU,        CCD.LOT,          CCD.LOC,        CCD.ID,
                      CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,   CCD.Lottable04, CCD.Lottable05,
                      CCD.SystemQty,
--                  CASE WHEN @nCCCountNo = 1 THEN CCD.Qty
--                       WHEN @nCCCountNo = 2 THEN CCD.Qty_Cnt2
--                       WHEN @nCCCountNo = 3 THEN CCD.Qty_Cnt3
--                  END,
                  CASE WHEN @cMinCnt1Ind = '0' THEN CCD.Qty
                       WHEN @cMinCnt2Ind = '0' THEN CCD.Qty_Cnt2
                       WHEN @cMinCnt3Ind = '0' THEN CCD.Qty_Cnt3
                  END,

                  '0',             '',              @cUserName,     GETDATE()
               FROM dbo.CCDETAIL CCD WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
               WHERE CCD.CCKey = @cCCRefNo
               AND LOC.Facility = @cFacility
               AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END
               AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END
               -- Only select uncounted record
               AND 1 = CASE
                          WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                          WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
                          WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
                       END
            ELSE
               -- Insert RDTCCLock
               INSERT INTO RDT.RDTCCLock
                  (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,
                  Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,   Level,
                  StorerKey,  Sku,        Lot,         Loc,        Id,
                  Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,
                  SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)
               SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey,  @cCCSheetNo,    0,
                  @cZone1,        @cZone2,        @cZone3, @cZone4, @cZone5,        @cAisle,        @cLevel,
                  CCD.StorerKey,  CCD.SKU,        CCD.LOT,          CCD.LOC,        CCD.ID,
                  CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,   CCD.Lottable04, CCD.Lottable05,
                  CCD.SystemQty,
                  --CASE WHEN @nCCCountNo = 1 THEN CCD.Qty
                  --     WHEN @nCCCountNo = 2 THEN CCD.Qty_Cnt2
                  --     WHEN @nCCCountNo = 3 THEN CCD.Qty_Cnt3
           --END,
                  CASE WHEN @cMinCnt1Ind = '0' THEN CCD.Qty
                       WHEN @cMinCnt2Ind = '0' THEN CCD.Qty_Cnt2
                       WHEN @cMinCnt3Ind = '0' THEN CCD.Qty_Cnt3
                  END,
'0',             '',              @cUserName,     GETDATE()
     FROM dbo.CCDETAIL CCD WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
               WHERE CCD.CCKey = @cCCRefNo
               AND LOC.Facility = @cFacility
               AND LOC.PutawayZone IN (@cZone1, @cZone2, @cZone3, @cZone4, @cZone5)
               AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END
               AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END
               -- Only select uncounted record
               AND 1 = CASE
                          WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                          WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
                          WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
                       END

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 62139
               SET @cErrMsg = rdt.rdtgetmessage( 62139, @cLangCode, 'DSP') -- 'Blank record'
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO SheetNo_Criteria_Fail
            END
         END

         -- Prepare next screen var
         SET @cOutField02 = ''  -- Blank SHEET
         SET @cOutField03 = ''  -- CNT NO
      END

      -- Go to next screen
      SET @nScn = @nScn_CountNo
      SET @nStep = @nStep_CountNo
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Release locked record
      -- (Vicky03) - Start - To Store those SystemQty <> CountedQty
      UPDATE RDT.RDTCCLock WITH (ROWLOCK)
         SET Status = '9'
      WHERE Mobile = @nMobile
      AND AddWho = @cUserName
      AND Status =  '1'
      -- (Vicky03) - End

      DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
      WHERE Mobile = @nMobile
      AND AddWho = @cUserName
      -- AND Status = '0'   -- (Vicky03)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 62140
         SET @cErrMsg = rdt.rdtgetmessage( 62140, @cLangCode, 'DSP') --'ReleaseMobFail'
         ROLLBACK TRAN
         GOTO Quit
      END

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SHEET

      -- Reset this screen var
      SET @cOutField02 = @cCCSheetNo -- SHEET
      SET @cOptCCType  = ''  -- SOS# 143022: Reset option value

      -- Back to previous screen
      SET @nScn = @nScn_CCRef
      SET @nStep = @nStep_CCRef
   END
   GOTO Quit

   SheetNo_Criteria_Fail:
   --BEGIN
      -- Reset this screen var
      -- SET @cOutField02 = '' -- SHEET
   --END
END
GOTO Quit

/************************************************************************************
Step_CountNo. Scn = 662. Screen 3.
   CCREF    (field01)
   SHEET    (field02)
   COUNT NO (field03)   - Input field
************************************************************************************/
Step_CountNo:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cCCCountNo NVARCHAR( 10)

      -- Screen mapping
      SET @cCCCountNo = @cInField03

      -- Retain the key-in value
      SET @cOutField03 = @cCCCountNo

      -- Validate CountNo
      IF @cCCCountNo = '' OR @cCCCountNo IS NULL
      BEGIN
         SET @nErrNo = 62086
         SET @cErrMsg = rdt.rdtgetmessage( 62086, @cLangCode, 'DSP') -- 'CNT NO required'
         GOTO CountNo_Fail
      END

      IF @cCCCountNo <> '1' AND @cCCCountNo <> '2' AND @cCCCountNo <> '3'
      BEGIN
         SET @nErrNo = 62087
        SET @cErrMsg = rdt.rdtgetmessage( 62087, @cLangCode, 'DSP') -- 'Invalid CNT NO'
         GOTO CountNo_Fail
      END

      SET @nCCCountNo = CAST( @cCCCountNo AS INT)

      DECLARE @nFinalizeStage INT

   -- Generate countsheet with or without qty
      SET @cWithQtyFlag = 'N'

      -- Get finalized stage
      -- If FinalizeStage = 1 means 1st cnt already finalized.
      SELECT TOP 1
         @nFinalizeStage = FinalizeStage,
@cWithQtyFlag = WithQuantity
      FROM dbo.StockTakeSheetParameters (NOLOCK)
      WHERE StockTakeKey = @cCCRefNo

      -- Already counted 3 times, not allow to count again
      IF @nFinalizeStage = 3
      BEGIN
         SET @nErrNo = 62088
         SET @cErrMsg = rdt.rdtgetmessage( 62088, @cLangCode, 'DSP') -- 'Finalized Cnt3'
         GOTO CountNo_Fail
      END

      -- Entered CountNo must equal to FinalizeStage + 1, ie. if cnt1 not finalized, cannot go to cnt2
      IF @nCCCountNo <> @nFinalizeStage + 1
      BEGIN
         SET @nErrNo = 62089
         SET @cErrMsg = rdt.rdtgetmessage( 62089, @cLangCode, 'DSP') -- 'Wrong CNT NO'
         GOTO CountNo_Fail
      END

      -- If configkey not turned on (james05)
      IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorerKey) <> '1'
      BEGIN
         SELECT TOP 1
            @cZone1 = Zone1,
            @cZone2 = Zone2,
            @cZone3 = Zone3,
            @cZone4 = Zone4,
            @cZone5 = Zone5,
            @cAisle = Aisle,
            @cLevel = Level
         FROM RDT.RDTCCLock WITH (ROWLOCK)
         WHERE Mobile = @nMobile
         AND CCKey = @cCCRefNo
         AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND AddWho = @cUserName
         -- AND Status = '0'  (Vicky03)

         -- Update qty according to count no
         UPDATE CCL WITH (ROWLOCK) SET
               CCL.Lottable01 = CASE
                    WHEN @nCCCountNo = 1 THEN CCD.Lottable01
                    WHEN @nCCCountNo = 2 THEN CCD.Lottable01_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Lottable01_Cnt3 END,
               CCL.Lottable02 = CASE
                    WHEN @nCCCountNo = 1 THEN CCD.Lottable02
                    WHEN @nCCCountNo = 2 THEN CCD.Lottable02_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Lottable02_Cnt3 END,
               Lottable03 = CASE
                    WHEN @nCCCountNo = 1 THEN CCD.Lottable03
                    WHEN @nCCCountNo = 2 THEN CCD.Lottable03_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Lottable03_Cnt3 END,
               Lottable04 = CASE
                    WHEN @nCCCountNo = 1 THEN CCD.Lottable04
                    WHEN @nCCCountNo = 2 THEN CCD.Lottable04_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Lottable04_Cnt3 END,
               Lottable05 = CASE
                    WHEN @nCCCountNo = 1 THEN CCD.Lottable05
                    WHEN @nCCCountNo = 2 THEN CCD.Lottable05_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Lottable05_Cnt3 END,
               CountedQty = CASE
                    WHEN @nCCCountNo = 1 THEN CCD.Qty
                    WHEN @nCCCountNo = 2 THEN CCD.Qty_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Qty_Cnt3 END
         FROM dbo.CCDetail CCD
         JOIN RDT.RDTCCLock CCL ON (CCD.CCDetailkey = CCL.CCDetailKey)
         WHERE CCL.Mobile = @nMobile
         AND CCL.CCKey = @cCCRefNo
         AND CCL.SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND CCL.AddWho = @cUserName

         -- Get first suggested loc (sort by CCLogicalLOC)
         SET @cSuggestLOC = ''
         SET @cSuggestLogiLOC = ''

         EXECUTE rdt.rdt_CycleCount_GetNextLOC_V7
            @nMobile,
            @nFunc,
            @cLangCode,
            @nStep,
            @nInputKey,
            @cFacility,
            @cStorerKey,
            @cCCRefNo,
            @cCCSheetNo,
            @cSheetNoFlag,
            @cZone1,
            @cZone2,
            @cZone3,
            @cZone4,
            @cZone5,
            @cAisle,
            @cLevel,
            '',   -- current CCLogicalLOC is blank
            @cSuggestLogiLOC OUTPUT,
            @cSuggestLOC OUTPUT,
            @nCCCountNo

         -- Update RDTCCLock data with CountNo
         UPDATE RDT.RDTCCLock WITH (ROWLOCK) SET
            CountNo = @nCCCountNo
         WHERE Mobile = @nMobile
         AND CCKey = @cCCRefNo
            AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
            AND AddWho = @cUserName
            AND Status = '0'
            AND (CountNo = 0 OR ISNULL(CountNo, '') = '')
      END
      ELSE
      BEGIN
         -- Get first suggested loc (sort by CCLogicalLOC)
         SET @cSuggestLOC = ''
         SET @cSuggestLogiLOC = ''

         EXECUTE rdt.rdt_CycleCount_GetNextLOC_V7
            @nMobile,
            @nFunc,
            @cLangCode,
            @nStep,
            @nInputKey,
            @cFacility,
            @cStorerKey,
            @cCCRefNo,
            @cCCSheetNo,
            @cSheetNoFlag,
            'ALL',
            '',
            '',
            '',
            '',
            'ALL',
            'ALL',
            '',   -- current CCLogicalLOC is blank
            @cSuggestLogiLOC OUTPUT,
            @cSuggestLOC OUTPUT,
            @nCCCountNo
      END

      -- Get StorerConfig 'OverrideLOC' (MaryVong01)
      SET @cOverrideLOCConfig = rdt.RDTGetConfig( @nFunc, 'OverrideLOC', @cStorerKey)

      --(james02) cater for recount
      IF @cOverrideLOCConfig <> '1' AND (@cSuggestLOC = '' OR @cSuggestLOC IS NULL)
      BEGIN
         SET @nErrNo = 62090
         SET @cErrMsg = rdt.rdtgetmessage( 62090, @cLangCode, 'DSP') -- 'LOC Not Found'
         GOTO CountNo_Fail
      END

      -- (ChewKP03)
      IF ISNULL(@cSuggestLOC, '') = ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM CCDETAIL WITH (NOLOCK)
                        WHERE CCKey = @cCCRefNo
                        AND 1 = CASE
                        WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '0' THEN 1
                        WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '0' THEN 1
                        WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '0' THEN 1 END)
         BEGIN
            SET @nErrNo = 77721
            SET @cErrMsg = rdt.rdtgetmessage( 77721, @cLangCode, 'DSP') -- 'AllLocCounted'
            GOTO CountNo_Fail
         END

      END
      ELSE
         SET @cCurSuggestLogiLOC = @cSuggestLogiLOC   -- (james23)

      -- Get No. Of CCDetail Lines
      SELECT @nCCDLinesPerLOC = COUNT(1)
      FROM dbo.CCDETAIL WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND LOC = @cSuggestLOC

      -- Reset LastLocFlag
      SET @cLastLocFlag = ''

      -- Prepare next screen var
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = ''
      SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorerKey) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END

      -- Go to next screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
    SELECT TOP 1
         @cZone1 = Zone1,
         @cZone2 = Zone2,
         @cZone3 = Zone3,
         @cZone4 = Zone4,
         @cZone5 = Zone5,
         @cAisle = Aisle,
         @cLevel = Level,
         @cCCSheetNo = SheetNo -- (Vicky03)
      FROM RDT.RDTCCLock WITH (ROWLOCK)
      WHERE Mobile = @nMobile
      AND CCKey = @cCCRefNo
      AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
      AND AddWho = @cUserName
      -- Get from latest record, not necessary status = '1'
      ORDER BY EditDate DESC

      -- Reset variables
      --SET @nCCCountNo = 0 (SHONG01)
      SET @cSheetNoFlag = ''

      -- Reset this screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = @cZone1
      SET @cOutField04 = @cZone2
      SET @cOutField05 = @cZone3
      SET @cOutField06 = @cZone4
      SET @cOutField07 = @cZone5
      SET @cOutField08 = @cAisle
      SET @cOutField09 = @cLevel

      SET @cOptCCType  = ''  -- SOS# 143022: Reset option value

      -- Go to previous screen
      SET @nScn = @nScn_SheetNo_Criteria
      SET @nStep = @nStep_SheetNo_Criteria
   END
   GOTO Quit

   CountNo_Fail:
   BEGIN   -- Reset this screen var
      SET @cOutField03 = '' -- CNT NO
   END
END
GOTO Quit

/************************************************************************************
Step_LOC. Scn = 663. Screen 4.
   CCREF         (field01)
   SHEET         (field02)
   CNT NO        (field03)
   LOC           (field04)   - Suggested LOC
   LOC           (field05)   - Input field
   TOTAL RECORDS (field06)
************************************************************************************/
Step_LOC:
BEGIN
--   IF @c_debug = '3'
--   BEGIN
--    Insert Into TraceInfo (TraceName, TimeIn, Step1, Step2, Col1, Col2, Col3)
--    Values ('rdtfnc_CycleCount_UCC_V7', GetDate(), '663 Scn4', '1', @cUserName, @cCCRefNo, @cCCSheetNo)
--  END

   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      IF @cLOC = @cOutField04
         SET @nLOCConfirm = 1
      ELSE
         SET @nLOCConfirm = 0

      -- Screen mapping
      SET @cLOC = @cInField05

      -- Retain the key-in value
      SET @cOutField05 = @cLOC

      -- Get StorerConfig 'OverrideLOC' (MaryVong01)
      SET @cOverrideLOCConfig = rdt.RDTGetConfig( @nFunc, 'OverrideLOC', @cStorerKey)

      -- Get StorerConfig 'DefaultCCOption'
      -- (ChewKP04)
      IF ISNULL(@cDefaultCCOption,'' ) IN  ( '','0' )
      BEGIN
         SET @cDefaultCCOption = rdt.RDTGetConfig( @nFunc, 'DefaultCCOption', @cStorerKey)
      END


      IF @cDefaultCCOption = '0' -- Default Option not setup
         SET @cDefaultCCOption = ''

      -- (james10)
      -- if rdt storerconfig turned on and loc.loseid = '1' & loc.loseucc = '1'
      -- then set as blind count (no show sku & qty)
      SET @cBlindCount = ''
      IF rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorerKey) = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                    WHERE Facility = @cFacility
                    AND   LOC = @cLOC
                    AND   LoseID = '1'
                    AND   LoseUCC = '1')
         BEGIN
            SET @cBlindCount = '1'
         END
      END

      -- Check if the LOC scanned already locked by other ppl (james05)
      IF ISNULL(@cLOC, '') <> ''
      BEGIN
         IF EXISTS (SELECT 1 FROM RDT.RDTCCLock WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
               AND LOC = @cLOC
               AND Status = '0'
               AND AddWho <> @cUserName)
         BEGIN
            SET @nErrNo = 66841
            SET @cErrMsg = rdt.rdtgetmessage( 66841, @cLangCode, 'DSP') -- 'LOC is Locked'
            GOTO LOC_Fail
         END
      END

      -- If LOC is Blank and <Enter>, skip current LOC and get next LOC
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         -- If configkey not turned on (james10)
         IF rdt.RDTGetConfig( @nFunc, 'NOTALLOWSKIPSUGGESTLOC', @cStorerKey) = '1'
         BEGIN
            SET @nErrNo = 77713
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC REQUIRED'
            GOTO LOC_Fail
         END

         GETNEXT_LOC:
         -- If configkey not turned on (james05)
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorerKey) <> '1'
         BEGIN
            -- (Vicky03) - Start
            SELECT TOP 1
               @cZone1 = Zone1,
               @cZone2 = Zone2,
               @cZone3 = Zone3,
               @cZone4 = Zone4,
               @cZone5 = Zone5,
               @cAisle = Aisle,
               @cLevel = Level
            FROM RDT.RDTCCLock WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
               AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN SheetNo ELSE @cCCSheetNo END
               AND   CountNo = @nCCCountNo
               AND   AddWho = @cUserName
            -- (Vicky03) - End

            -- Get next suggested LOC
            EXECUTE rdt.rdt_CycleCount_GetNextLOC_V7
               @nMobile,
               @nFunc,
               @cLangCode,
               @nStep,
               @nInputKey,
               @cFacility,
               @cStorerKey,
               @cCCRefNo,
               @cCCSheetNo,
               @cSheetNoFlag,
               @cZone1,
               @cZone2,
               @cZone3,
               @cZone4,
               @cZone5,
               @cAisle,
               @cLevel,
               @cCurSuggestLogiLOC, -- current CCLogicalLOC
               @cSuggestLogiLOC  OUTPUT,
               @cSuggestLOC      OUTPUT,
               @nCCCountNo
         END
         ELSE
         BEGIN
            -- Get next suggested LOC
            EXECUTE rdt.rdt_CycleCount_GetNextLOC_V7
               @nMobile,
               @nFunc,
               @cLangCode,
               @nStep,
               @nInputKey,
               @cFacility,
               @cStorerKey,
               @cCCRefNo,
               @cCCSheetNo,
               @cSheetNoFlag,
               'ALL',
               '',
               '',
               '',
               '',
               'ALL',
               'ALL',
               @cCurSuggestLogiLOC, -- current CCLogicalLOC
               @cSuggestLogiLOC  OUTPUT,
               @cSuggestLOC      OUTPUT,
               @nCCCountNo
         END

         -- Get No. Of CCDetail Lines
         SELECT @nCCDLinesPerLOC = COUNT(1)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND LOC = @cSuggestLOC

         IF @cSuggestLOC = '' OR @cSuggestLOC IS NULL
         BEGIN
            SET @cLastLocFlag = 'Y'
            SET @nErrNo = 62091
            SET @cErrMsg = rdt.rdtgetmessage( 62091, @cLangCode, 'DSP') -- 'Last LOC'
            GOTO LOC_Fail
         END
         ELSE
            SET @cCurSuggestLogiLOC = @cSuggestLogiLOC   -- (james23)

         -- Reset var with suggested LOC and Total Records
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorerKey) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)

         -- Quit and remain at current screen
         GOTO Quit
      END

      -- LOC is NOT Blank
      IF @cLOC <> '' AND @cLOC IS NOT NULL
      BEGIN
         -- (james10)
         IF UPPER(@cLOC) = 'COUNTED'
         BEGIN
            IF @nLOCConfirm = 1
            BEGIN
               SET @nTranCount = @@TRANCOUNT
               BEGIN TRAN
               SAVE TRAN LOC_COUNTED

               -- Mark the current loc as fully counted
               UPDATE dbo.CCDetail WITH (ROWLOCK) SET
                  QTY = CASE WHEN @nCCCountNo = 1 THEN 0 ELSE QTY END,
                  QTY_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN 0 ELSE QTY_Cnt2 END,
                  QTY_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN 0 ELSE QTY_Cnt3 END,
                  Counted_Cnt1 = CASE WHEN @nCCCountNo = 1 THEN 1 ELSE Counted_Cnt1 END,
                  Counted_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN 1 ELSE Counted_Cnt2 END,
                  Counted_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN 1 ELSE Counted_Cnt3 END,
                  EditDate_Cnt1 = CASE WHEN @nCCCountNo = 1 THEN GETDATE() ELSE EditDate_Cnt1 END,
                  EditDate_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN GETDATE() ELSE EditDate_Cnt2 END,
                  EditDate_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN GETDATE() ELSE EditDate_Cnt3 END,
                  EditWho_Cnt1  = CASE WHEN @nCCCountNo = 1 THEN 'rdt.' + @cUserName ELSE EditWho_Cnt1 END,
                  EditWho_Cnt2  = CASE WHEN @nCCCountNo = 2 THEN 'rdt.' + @cUserName ELSE EditWho_Cnt2 END,
                  EditWho_Cnt3  = CASE WHEN @nCCCountNo = 3 THEN 'rdt.' + @cUserName ELSE EditWho_Cnt3 END
               WHERE CCKey = @cCCRefNo
               AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND LOC = @cOutField04  -- on screen suggested loc
               AND 1 = CASE            -- count only those not counted
         WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0
                 WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0
                          WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0
          ELSE 1
                       END

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN LOC_COUNTED
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN
                  SET @nErrNo = 77710
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Mark Ctn Fail
                  GOTO LOC_Fail
                END

               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN

               SET @cOutField05 = ''

               GOTO GETNEXT_LOC
            END
            ELSE
            BEGIN
               SET @nErrNo = 77711
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --PLS CFM LOC
               GOTO LOC_Fail
            END
         END

         -- (MaryVong01)
         IF @cLOC = @cSuggestLOC AND @cAddNewLocFlag <> 'Y' -- If add new LOC, do not check
         BEGIN
            -- Check if all counted, get min(counted_cnt)
            SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                  @cMinCnt2Ind = MIN(Counted_Cnt2),
                  @cMinCnt3Ind = MIN(Counted_Cnt3)
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND LOC = @cLOC

            IF NOT EXISTS (SELECT 1 FROM dbo.CCDETAIL WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND LOC = @cLOC
               AND 1 =  CASE
                       WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0
                       WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0
                       WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0
                    ELSE 1
                    END)
--               AND 1 = CASE
--                   WHEN @nCCCountNo = 1 AND @cMinCnt1Ind = 0 THEN 1
--                   WHEN @nCCCountNo = 2 AND @cMinCnt2Ind = 0 THEN 1
--                   WHEN @nCCCountNo = 3 AND @cMinCnt3Ind = 0 THEN 1
--                   ELSE 0 END) -- All Counted
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = '1'   -- Option (Default to "YES")

               EXEC rdt.rdtSetFocusField @nMobile, 1   -- OPTION

               -- Go to Screen 4C. ReCount_LOC - Option
               SET @nScn = @nScn_RECOUNT_LOC_Option
               SET @nStep = @nStep_RECOUNT_LOC_Option

               GOTO Quit
            END
         END

         -- LOC not equal to suggested LOC
         IF @cLOC <> @cSuggestLOC
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'OverrideLOC', @cStorerKey) <> '1' -- Not allow override loc
            BEGIN
               SET @nErrNo = 62092   -- (james16)
               SET @cErrMsg = rdt.rdtgetmessage( 62092, @cLangCode, 'DSP') -- 'LOC Not Match'   -- (james16)
               GOTO LOC_Fail
            END

            -- (MaryVong01)
            IF @cOverrideLOCConfig = '1' -- Allow override loc
            BEGIN
               DECLARE @cChkFacility NVARCHAR( 5)
               SELECT TOP 1
                  @cChkFacility = Facility
             FROM dbo.LOC (NOLOCK)
               WHERE LOC = @cLOC

               IF @cChkFacility <> @cFacility
               BEGIN
                  SET @nErrNo = 62142
                  SET @cErrMsg = rdt.rdtgetmessage( 62142, @cLangCode, 'DSP') -- 'Facility Diff'
                  GOTO LOC_Fail
               END

               -- Get CCLogicalLOC from entered LOC
               SELECT @cSuggestLogiLOC = LOC.CCLogicalLOC
               FROM dbo.LOC LOC (NOLOCK)
     WHERE LOC.LOC = @cLOC
      AND LOC.Facility = @cFacility

               IF @cSuggestLogiLOC = '' OR @cSuggestLogiLOC IS NULL
           BEGIN
     SET @nErrNo = 62143
                  SET @cErrMsg = rdt.rdtgetmessage( 62143, @cLangCode, 'DSP') -- 'Setup LogiLOC'
                  GOTO LOC_Fail
               END

               IF @cLastLocFlag = 'Y'
               BEGIN
                  -- Prepare next screen var
                  SET @cOutField01 = '1' -- Option (Default to "YES")

                  -- Go to next screen
                  SET @nScn = @nScn_LAST_LOC_Option
                  SET @nStep = @nStep_LAST_LOC_Option

                  GOTO Quit
               END
               -- IF @cLastLocFlag <> 'Y'
               ELSE
               BEGIN
                  -- Check if LOC found in CCDetail
                  IF NOT EXISTS (SELECT 1 FROM dbo.CCDETAIL WITH (NOLOCK)
                             WHERE CCKey = @cCCRefNo
                             AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                             AND LOC = @cLOC)

                  BEGIN
                     -- Check if it is a valid loc within the same facility
                     IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                        WHERE LOC = @cLOC
                        AND Facility = @cFacility)
                     BEGIN
                        SET @nErrNo = 62090
                        SET @cErrMsg = rdt.rdtgetmessage( 62090, @cLangCode, 'DSP') -- 'LOC Not Found'
                        GOTO LOC_Fail
                     END
                     ELSE
                     BEGIN
                        SET @cAddNewLocFlag = 'Y'
                     END

                     -- Prepare next screen var
                     SET @cOutField01 = '1'   -- Option (Default to "YES")

                     EXEC rdt.rdtSetFocusField @nMobile, 1   -- OPTION

                     -- Go to Screen 4a. LOC - Option
                     SET @nScn = @nScn_LOC_Option
                     SET @nStep = @nStep_LOC_Option

                     GOTO Quit
                  END

                  -- Check if all counted, get min(counted_cnt)
                  SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                         @cMinCnt2Ind = MIN(Counted_Cnt2),
                         @cMinCnt3Ind = MIN(Counted_Cnt3)
                  FROM dbo.CCDETAIL WITH (NOLOCK)
                  WHERE CCKey = @cCCRefNo
                  AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                  AND LOC = @cLOC

                  -- Check if Counted location
                  IF NOT EXISTS (SELECT 1 FROM dbo.CCDETAIL WITH (NOLOCK)
                             WHERE CCKey = @cCCRefNo
                             AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                             AND LOC = @cLOC
                          AND 1 = CASE
                                 WHEN @nCCCountNo = 1 AND @cMinCnt1Ind = 0 THEN 1
                                 WHEN @nCCCountNo = 2 AND @cMinCnt2Ind = 0 THEN 1
                                 WHEN @nCCCountNo = 3 AND @cMinCnt3Ind = 0 THEN 1
                                 ELSE 0 END) -- All Counted
                  BEGIN
                     -- Prepare next screen var
                     SET @cOutField01 = '1'   -- Option (Default to "YES")

                     EXEC rdt.rdtSetFocusField @nMobile, 1   -- OPTION

                     -- Go to Screen 4c. ReCount_LOC - Option
                     SET @nScn = @nScn_RECOUNT_LOC_Option
                     SET @nStep = @nStep_RECOUNT_LOC_Option

                     GOTO Quit
                  END
                  ELSE
                  -- Get StorerConfig 'SkipOverrideLOCScn'
                  IF rdt.RDTGetConfig( @nFunc, 'SkipOverrideLOCScn', @cStorerKey) <> '1'
                  BEGIN
                     -- Prepare next screen var
         SET @cOutField01 = '1'   -- Option (Default to "YES")

                     EXEC rdt.rdtSetFocusField @nMobile, 1   -- OPTION

                     -- Go to Screen 4a. LOC - Option
                     SET @nScn = @nScn_LOC_Option
                     SET @nStep = @nStep_LOC_Option

                     GOTO Quit
                  END
               END
            END -- @cOverrideLOCConfig = 'Y'
         END -- IF @cLOC <> @cSuggestLOC

         -- Get any SKU in the particular LOC and ID (if any)
         SET @cSKU = ''
         SET @cCheckStorer = '' -- SHONG002
         SELECT TOP 1
            @cSKU = SKU
           ,@cCheckStorer = StorerKey -- SHONG002
           --,@cStorerKey = StorerKey -- SHONG001
         FROM dbo.CCDETAIL (NOLOCK)
         WHERE CCKey = @cCCRefNo
         --AND   CCSheetNo = @cCCSheetNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND LOC = @cLOC

         IF ISNULL(RTRIM(@cCheckStorer),'') = ''
            SET @cCheckStorer = @cStorerKey

         -- If Empty LOC generated in CCDetail, no SKU found.
         -- Get first LocType found in SKUxLOC
         IF @cSKU = '' OR @cSKU IS NULL
         BEGIN
            SELECT TOP 1 @cLocType = LocationType
            FROM dbo.SKUxLOC (NOLOCK)
            WHERE StorerKey = @cCheckStorer -- SHONG002
            --WHERE StorerKey = @cStorerKey
            AND LOC = @cLOC
         END
         ELSE
         BEGIN
            -- With pre-requisite: SKUxLOC.LocationType must be correctly setup
            -- Assumption: Same storer and sku having same SKUxLOC.LocationType
            SELECT @cLocType = LocationType
            FROM dbo.SKUxLOC (NOLOCK)
            WHERE StorerKey = @cCheckStorer -- SHONG002
            --WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND LOC = @cLOC
         END
      END

      -- If configkey turned on, start insert CCLock (james05)
      --IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorerKey) = '1'
      IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cCheckStorer) = '1' -- SHONG002
      BEGIN
         -- Release locked record
         DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
         WHERE Mobile = @nMobile
            AND AddWho = @cUserName

         -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
         SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
               @cMinCnt2Ind = MIN(Counted_Cnt2),
               @cMinCnt3Ind = MIN(Counted_Cnt3)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
            AND LOC = @cLOC

         -- Insert into RDTCCLock
         INSERT INTO RDT.RDTCCLock
            (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,
            Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,
            StorerKey,  Sku,        Lot,         Loc, Id,
            Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,
            SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)
         SELECT @nMobile,   CCKey,      CCDetailKey, CCSheetNo,  @nCCCountNo,
            'ALL',        '',        '',         '',         '',         'ALL',   'ALL',
            StorerKey,  SKU,        LOT,         LOC,        ID,
            Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,
            SystemQty,
            CASE WHEN @nCCCountNo = 1 THEN Qty
                 WHEN @nCCCountNo = 2 THEN Qty_Cnt2
                 WHEN @nCCCountNo = 3 THEN Qty_Cnt3
            END,
            '0',         '',         @cUserName,  GETDATE()
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
            AND LOC = @cLOC
            -- Only select uncounted record
            AND 1 = CASE
                     WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                       WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
 WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
                    ELSE 0 END

         IF @@ROWCOUNT = 0 -- No data in CCDetail
         BEGIN
            SET @nErrNo = 66838
            SET @cErrMsg = rdt.rdtgetmessage( 66838, @cLangCode, 'DSP') -- 'Blank Record'
            GOTO QUIT
         END

--      SELECT DISTINCT @cCCSheetNo = SheetNo FROM RDT.RDTCCLock WITH (NOLOCK)
--         WHERE StorerKey = @cStorerKey
--      AND CCKey = @cCCRefNo
--            AND LOC = @cLOC
--            AND Status = '0'
--            AND AddWho = @cUserName
      END

      -- Prepare next screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = '' -- ID

      -- (james12)
      SET @nNoOfTry = 0

      -- Go to next screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset Flags
      SET @cRecountFlag = ''
      SET @cLastLocFlag = ''
      SET @cAddNewLocFlag = ''

      -- Reset this screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
      SET @cOutField04 = '' -- Suggested LOC
      SET @cOutField05 = '' -- LOC
      SET @cOutField06 = '' -- Total Records

      SET @cOptCCType  = ''  -- SOS# 143022: Reset option value

      -- Go to previous screen
      SET @nScn = @nScn_CountNo
      SET @nStep = @nStep_CountNo
   END
   GOTO Quit

   LOC_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField05 = '' -- LOC
   END
END    GOTO Quit

/************************************************************************************
Step_LOC_Option. Scn = 664. Screen 4a.
   OPTION (field01)   - Input field
************************************************************************************/
Step_LOC_Option:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Retain the key-in value
      -- SET @cOutField01 = @cOption

      -- 1=YES, 2=NO
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 62145
         SET @cErrMsg = rdt.rdtgetmessage( 62145, @cLangCode, 'DSP') -- 'Option req'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO LOC_Option_Fail
      END

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 62146
         SET @cErrMsg = rdt.rdtgetmessage( 62146, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO LOC_Option_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = '' -- ID

         EXEC rdt.rdtSetFocusField @nMobile, 7   -- ID

         -- If configkey turned on, start insert CCLock (james05)
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorerKey) = '1'
         BEGIN
            -- Release locked record
            DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
            WHERE Mobile = @nMobile
            AND AddWho = @cUserName

            -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
            SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                  @cMinCnt2Ind = MIN(Counted_Cnt2),
                  @cMinCnt3Ind = MIN(Counted_Cnt3)
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
               AND LOC = @cLOC

            -- Insert into RDTCCLock
            IF @cAddNewLocFlag <> 'Y'
            BEGIN
               INSERT INTO RDT.RDTCCLock
             (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,
                  Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,
                  StorerKey,  Sku,        Lot,         Loc, Id,
                  Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,
                  SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)
               SELECT @nMobile,   CCKey,      CCDetailKey, CCSheetNo,  @nCCCountNo,
                  'ALL',        '',        '',         '',         '',         'ALL',   'ALL',
                  StorerKey,  SKU,        LOT,         LOC,        ID,
                  Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,
                  SystemQty,
                  CASE WHEN @nCCCountNo = 1 THEN Qty
                       WHEN @nCCCountNo = 2 THEN Qty_Cnt2
                       WHEN @nCCCountNo = 3 THEN Qty_Cnt3
                  END,
                  '0',         '',         @cUserName,  GETDATE()
               FROM dbo.CCDETAIL WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
                  AND LOC = @cLOC
                  -- Only select uncounted record
                  AND 1 = CASE
                             WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                             WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
                             WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
                          ELSE 0
                          END

               IF @@ROWCOUNT = 0 -- No data in CCDetail
               BEGIN
                  SET @nErrNo = 66839
                  SET @cErrMsg = rdt.rdtgetmessage( 66839, @cLangCode, 'DSP') -- 'Blank Record'
                  GOTO QUIT
               END
            END
         END

         -- Go to next screen
         SET @nScn = @nScn_ID
         SET @nStep = @nStep_ID
      END

      IF @cOption = '2'
      BEGIN
         SELECT @nCCDLinesPerLOC = COUNT(1)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND LOC = @cSuggestLOC
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- LOC

         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorerKey) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)

         -- Go to previous screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SELECT @nCCDLinesPerLOC = COUNT(1)
      FROM dbo.CCDETAIL WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
      AND LOC = @cSuggestLOC

      -- Reset this screen var (Retain all values)
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorerKey) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)

      EXEC rdt.rdtSetFocusField @nMobile, 5 -- LOC

      -- Go to previous screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit

   LOC_Option_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit

/************************************************************************************
Step_LAST_LOC_Option. Scn = 665. Screen 4b.
   OPTION (field01)   - Input field
************************************************************************************/
Step_LAST_LOC_Option:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Retain the key-in value
      -- SET @cOutField01 = @cOption

      -- 1=YES, 2=NO
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 62147
         SET @cErrMsg = rdt.rdtgetmessage( 62147, @cLangCode, 'DSP') -- 'Option req'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO LAST_LOC_Option_Fail
      END

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 62148
         SET @cErrMsg = rdt.rdtgetmessage( 62148, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO LAST_LOC_Option_Fail
      END

      IF @cOption = '1' -- YES
      BEGIN
         SET @cAddNewLocFlag = 'Y'

         -- Set SuggestLOC equal to key-in LOC
         SET @cSuggestLOC = @cLOC

         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = 0

         EXEC rdt.rdtSetFocusField @nMobile, 5 -- LOC

         -- Go to next screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC
      END

      IF @cOption = '2' -- NO
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
        SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- CNT NO

         -- Go to next screen
         SET @nScn = @nScn_CountNo
         SET @nStep = @nStep_CountNo
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- Reset this screen var (Retain all values)
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''

      -- Go to previous screen
      SET @nScn = @nScn_CountNo
      SET @nStep = @nStep_CountNo
   END
GOTO Quit

   LAST_LOC_Option_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit

/************************************************************************************
Step_RECOUNT_LOC_Option. Scn = 666. Screen 4c.
   OPTION (field01)   - Input field
************************************************************************************/
Step_RECOUNT_LOC_Option:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Retain the key-in value
      -- SET @cOutField01 = @cOption

      -- 1=YES, 2=NO
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 62149
         SET @cErrMsg = rdt.rdtgetmessage( 62149, @cLangCode, 'DSP') -- 'Option req'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO RECOUNT_LOC_Option_Fail
      END

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 62150
         SET @cErrMsg = rdt.rdtgetmessage( 62150, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO RECOUNT_LOC_Option_Fail
      END

      IF @cOption = '1' -- YES
      BEGIN
         SET @cRecountFlag = 'Y'

         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = ''   -- ID

         EXEC rdt.rdtSetFocusField @nMobile, 7   -- ID

         -- Reset Counted_Cnt(x) -- IN00187400
         SET @nErrNo  = 0
         SET @cErrMsg = ''
         EXECUTE rdt.rdt_CycleCount_UpdateCCDetail_V7
            @nMobile,
            @nFunc,
            @cLangCode,
            @nStep,
            @nInputKey,
            @cFacility,
            @cStorerKey,
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cCCDetailKey,
            0,
            @nErrNo       OUTPUT,
            @cErrMsg      OUTPUT   -- screen limitation, 20 char max

         IF @nErrNo <> 0
            GOTO RECOUNT_LOC_Option_Fail

         -- If configkey turned on, start insert CCLock (james05)
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorerKey) = '1'
         BEGIN
            -- Release locked record
            DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
            WHERE Mobile = @nMobile
               AND AddWho = @cUserName

            -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
            SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                  @cMinCnt2Ind = MIN(Counted_Cnt2),
                  @cMinCnt3Ind = MIN(Counted_Cnt3)
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
               AND LOC = @cLOC

            -- Insert into RDTCCLock
            INSERT INTO RDT.RDTCCLock
               (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,
               Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,
               StorerKey,  Sku,        Lot,         Loc, Id,
               Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,
               SystemQty,  CountedQty, Status,      RefNo,    AddWho,     AddDate)
            SELECT @nMobile,   CCKey,      CCDetailKey, CCSheetNo,  @nCCCountNo,
               'ALL',        '',        '',         '',   '',         'ALL',   'ALL',
               StorerKey,  SKU,        LOT,         LOC,        ID,
               Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,
               SystemQty,
               CASE WHEN @nCCCountNo = 1 THEN Qty
                    WHEN @nCCCountNo = 2 THEN Qty_Cnt2
                    WHEN @nCCCountNo = 3 THEN Qty_Cnt3
               END,
               '0',         '',         @cUserName,  GETDATE()
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
               AND LOC = @cLOC
               -- Only select uncounted record
               AND 1 = CASE
                          WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                          WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
                          WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
               ELSE 0
                       END

            IF @@ROWCOUNT = 0 -- No data in CCDetail
            BEGIN
               SET @nErrNo = 66840
               SET @cErrMsg = rdt.rdtgetmessage( 66840, @cLangCode, 'DSP') -- 'Blank Record'
               GOTO QUIT
            END
         END

         -- Go to next screen
         SET @nScn = @nScn_ID
         SET @nStep = @nStep_ID
      END

      IF @cOption = '2' -- NO
      BEGIN
         SELECT @nCCDLinesPerLOC = COUNT(1)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND LOC = @cSuggestLOC

         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorerKey) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)

         EXEC rdt.rdtSetFocusField @nMobile, 5 -- LOC

         -- Go to next screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SELECT @nCCDLinesPerLOC = COUNT(1)
      FROM dbo.CCDETAIL WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
      AND LOC = @cSuggestLOC

      -- Reset this screen var (Retain all values)
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorerKey) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)

      EXEC rdt.rdtSetFocusField @nMobile, 5 -- LOC

      -- Go to next screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit

   RECOUNT_LOC_Option_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit

/************************************************************************************
Step_ID. Scn = 667. Screen 5.
   CCREF  (field01)
   SHEET  (field02)
   COUNT  (field03)
   LOC    (field04)   - Suggested LOC
   LOC    (field05)
   OPTION (field06)   - Input field
   ID     (field07)   - Input field
************************************************************************************/
Step_ID:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cID_In = @cInField06

      -- Retain the key-in value
      SET @cOutField06 = @cID_In

      -- Get stock take count type (james10)
      SELECT @cCountType = ISNULL(CountType, '')
      FROM dbo.StockTakeSheetParameters WITH (NOLOCK)
      WHERE StockTakeKey = @cCCRefNo

      IF (@cLocType = 'PICK' OR @cLocType = 'CASE') -- PICK location
      BEGIN
         SET @nErrNo = 62096
         SET @cErrMsg = rdt.rdtgetmessage( 62096, @cLangCode, 'DSP') -- 'LocType PICK'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO ID_Fail
      END

      -- Check CC count type, must either be UCC or blank count (james10)
      IF @cCountType NOT IN ('UCC', 'BLK')
      BEGIN
         SET @nErrNo = 77707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV COUNT TYPE'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO ID_Fail
      END

      SET @nCntQTY = 0
      SET @nTotCarton = 0

      SET @cID = @cID_In -- Fixed by SHONG on 03-Mar-2011

      -- Get no. of counted cartons
      SELECT @nCntQTY = COUNT(1)
      FROM dbo.CCDETAIL (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
      AND   LOC = @cLOC
      -- SOS79743
      -- AND   ID = @cID
      AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
      AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
      WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                     WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
                  ELSE 0 END
      AND   (Status = '2' OR Status = '4')

      -- Get total cartons for particular LOC and ID (if any)
      SELECT @nTotCarton = COUNT(1)
      FROM dbo.CCDETAIL (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
      AND   LOC = @cLOC
      -- SOS79743
      -- AND   ID = @cID
      AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
      -- Remarked by MaryVong on 05-Jul-2007 Count all ccdetail lines
      -- To avoid confusion since location for UCC is not shared with SKU/UPC
      -- AND   (RefNo <> '' AND RefNo IS NOT NULL)
   --insert into traceinfo (tracename, timein, step1, step2, step3, step4, step5) values ('rdtfnc_cyclecount', getdate(), @nTotCarton, @cCCRefNo, @cCCSheetNo, @cLOC, @cID_In)
      -- (MaryVong01)
      IF @cRecountFlag = 'Y'
         SET @nCntQTY = 0

      -- Blank out var
      SET @cUCC = ''
      SET @cSKU = ''
      SET @cSKUDescr = ''
      --SET @nCaseCnt = 0
      SET @nUCCQTY = 0
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = ''
      SET @dLottable05 = ''

      -- Prepare UCC (Main) screen var
      SET @cOutField01 = ''   -- UCC
      SET @cOutField02 = ''   -- SKU
      SET @cOutField03 = ''   -- SKU DESCR1
      SET @cOutField04 = ''   -- SKU DESCR2
      SET @cOutField05 = ''   -- QTY
      SET @cOutField06 = ''   -- Lottable01
      SET @cOutField07 = '' -- Lottable02
      SET @cOutField08 = ''   -- Lottable03
      SET @cOutField09 = ''   -- Lottable04
      SET @cOutField10 = ''   -- Lottable05
--       SET @cOutField11 = CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
      SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                              THEN RIGHT( SPACE(5) + CAST( @nCntQTY AS NVARCHAR( 5)), 5)
                              ELSE CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
                              END
      SET @cOutField12 = ''   -- Option

      EXEC rdt.rdtSetFocusField @nMobile, 1   -- UCC

      -- Go to UCC (Main) screen
      SET @nScn = @nScn_UCC
      SET @nStep = @nStep_UCC
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset Flags
      SET @cRecountFlag   = ''
      SET @cLastLocFlag = ''
      SET @cAddNewLocFlag = ''

      -- Check current loc whether all ccdetail line counted
      -- If yes then need to get next available loc   (james13)
      IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
     WHERE CCKey = @cCCRefNo
                      AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                      AND LOC = @cLOC
                      AND 1 = CASE
                              WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 0 THEN 1
                              WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 0 THEN 1
                              WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 0 THEN 1
                              ELSE 0
                              END)
   BEGIN
         -- If configkey not turned on (james05)
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorerKey) <> '1'
         BEGIN
            -- (Vicky03) - Start
            SELECT TOP 1
               @cZone1 = Zone1,
               @cZone2 = Zone2,
               @cZone3 = Zone3,
               @cZone4 = Zone4,
               @cZone5 = Zone5,
               @cAisle = Aisle,
               @cLevel = Level
            FROM RDT.RDTCCLock WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
               AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN SheetNo ELSE @cCCSheetNo END
               AND   CountNo = @nCCCountNo
               AND   AddWho = @cUserName
    -- (Vicky03) - End

            -- Get next suggested LOC
            EXECUTE rdt.rdt_CycleCount_GetNextLOC_V7
               @nMobile,
               @nFunc,
               @cLangCode,
               @nStep,
               @nInputKey,
               @cFacility,
               @cStorerKey,
               @cCCRefNo,
               @cCCSheetNo,
               @cSheetNoFlag,
               @cZone1,
               @cZone2,
               @cZone3,
               @cZone4,
               @cZone5,
               @cAisle,
               @cLevel,
               @cSuggestLogiLOC, -- current CCLogicalLOC
               @cSuggestLogiLOC OUTPUT,
               @cSuggestLOC OUTPUT,
               @nCCCountNo
         END
         ELSE
         BEGIN
            -- Get next suggested LOC
            EXECUTE rdt.rdt_CycleCount_GetNextLOC_V7
               @nMobile,
               @nFunc,
               @cLangCode,
               @nStep,
               @nInputKey,
               @cFacility,
               @cStorerKey,
               @cCCRefNo,
               @cCCSheetNo,
               @cSheetNoFlag,
               'ALL',
               '',
               '',
               '',
               '',
               'ALL',
               'ALL',
               @cSuggestLogiLOC, -- current CCLogicalLOC
               @cSuggestLogiLOC OUTPUT,
               @cSuggestLOC OUTPUT,
               @nCCCountNo
         END

         -- If already last loc then display current loc and prompt "Last Loc"
         IF @cSuggestLOC = '' OR @cSuggestLOC IS NULL
         BEGIN
            SET @cLastLocFlag = 'Y'
            SET @nErrNo = 62091
            SET @cErrMsg = rdt.rdtgetmessage( 62091, @cLangCode, 'DSP') -- 'Last LOC'
         END
      END

      -- Get No. Of CCDetail Lines
      SELECT @nCCDLinesPerLOC = COUNT(1)
      FROM dbo.CCDETAIL WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
      AND LOC = @cSuggestLOC

      -- Reset this screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
      SET @cOutField04 = CASE WHEN ISNULL( @cSuggestLOC, '') <> '' THEN @cSuggestLOC ELSE @cLOC END
      SET @cOutField05 = ''   -- LOC
      SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorerKey) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)
      SET @cOutField07 = ''  -- ID

      -- Go to previous screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit

   ID_Fail:
   BEGIN
      SET @cOutField07= '' -- ID
   END
END
GOTO Quit

/************************************************************************************
Step_UCC. Scn = 668. Screen 6.
   UCC         (field01) - Input field LOTTABLE02  (field07)
   SKU/UPC     (field02)       LOTTABLE03  (field08)
   SKU DESCR1  (field03) LOTTABLE04  (field09)
   SKU DESCR2  (field04)               LOTTABLE05  (field10)
   QTY         (field05)               UCC COUNTER (field11)
   LOTTABLE01  (field06)               OPT         (field12) - Input field
************************************************************************************/
Step_UCC:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField01
      SET @cOptAction = @cInField12

      -- Retain the key-in value
      SET @cOutField01 = @cUCC
      SET @cOutField12 = @cOptAction

      -- Option: 1=ADD
      IF @cOptAction <> '' AND @cOptAction IS NOT NULL
      BEGIN
         IF @cOptAction NOT IN ('1', '2')
         BEGIN
            SET @nErrNo = 62098
            SET @cErrMsg = rdt.rdtgetmessage( 62098, @cLangCode, 'DSP') -- 'Invalid Option'
            EXEC rdt.rdtSetFocusField @nMobile, 12
            GOTO UCC_Fail
         END

         -- 1=ADD
         IF @cOptAction = '1'
         BEGIN
            -- Blank out UCC (ADD) Screen
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cID_In
            SET @cOutField03 = ''   -- UCC
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = ''
            SET @cOutField10 = ''
            SET @cOutField11 = ''
            SET @cOutField12 = ''
            SET @cOutField11 = ''
            SET @cOutField12 = ''

            -- Go to next screen
            SET @nScn = @nScn_UCC_Add_Ucc
            SET @nStep = @nStep_UCC_Add_Ucc
         END

         -- 2=Edit
         IF @cOptAction = '2'
         BEGIN
            -- Check if allowed to edit ucc (james10)
            IF rdt.RDTGetConfig( @nFunc, 'CCEDITUCCNOTALLOW', @cStorerKey) = '1'
            BEGIN
               SET @nErrNo = 77712
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'EDT NOT ALLOW'
               EXEC rdt.rdtSetFocusField @nMobile, 12
               GOTO UCC_Fail
            END

            -- Check if SKU is blank => cannot edit
            IF @cSKU = '' OR @cSKU IS NULL
            BEGIN
               SET @nErrNo = 62118
               SET @cErrMsg = rdt.rdtgetmessage( 62118, @cLangCode, 'DSP') -- 'Blank record'
               EXEC rdt.rdtSetFocusField @nMobile, 12
               GOTO UCC_Fail
            END

            -- Blank out UCC (EDIT) Screen
            SET @cOutField01 = '' --QTY
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
            SET @cOutField11 = ''
            SET @cOutField12 = ''

            -- Go to next screen
            SET @nScn = @nScn_UCC_Edit_QTY
            SET @nStep = @nStep_UCC_Edit_QTY
         END
      END

      -- OPT = blank
      IF @cOptAction = '' OR @cOptAction IS NULL
      BEGIN
         -- Validate blank/existance/multiple UCC
         SET @nErrNo = 0
         EXEC rdt.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cUCC,
            @cStorerKey,
            '1' -- Received status

         IF @nErrNo > 0
            GOTO UCC_Fail

         DECLARE @cUCCStorer    NVARCHAR( 15)

         -- Get UCC StorerKey
         SELECT @cUCCStorer = StorerKey
         FROM dbo.UCC (NOLOCK)
         WHERE UCCNo = @cUCC
         AND   Status = '1'

         -- Validate UCC storer
         IF @cUCCStorer <> @cStorerKey
         BEGIN
            SET @nErrNo = 62099
            SET @cErrMsg = rdt.rdtgetmessage( 62099, @cLangCode, 'DSP') -- 'UCC StorerDiff'
            GOTO UCC_Fail
         END

         -- Check existance of valid UCC in CCDETAIL
         -- If the valid UCC Not found in CCDETAIL, prompt error
         IF NOT EXISTS (SELECT 1--TOP 1 1
                        FROM dbo.CCDETAIL (NOLOCK)
                        WHERE CCKey = @cCCRefNo
                        AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
               AND   LOC = @cLOC
                        -- SOS79743
                        -- AND   ID = @cID
                        AND   ID = CASE WHEN ISNULL(@cID_In, '') = '' THEN ID ELSE RTRIM(@cID_In) END
                        AND   RefNo = @cUCC)
         BEGIN
            SET @nErrNo = 62100
            SET @cErrMsg = rdt.rdtgetmessage( 62100, @cLangCode, 'DSP') -- 'No UCC (CCDet)'
            GOTO UCC_Fail
         END
         -- Valid UCC found in CCDETAIL, do more validation
         ELSE
         BEGIN
            SET @cCountedFlag = '[ ]'

            -- Get CCDETAIL
            SELECT TOP 1
               @cStorerKey = CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorerKey ELSE StorerKey END, -- Shong002
               @cSKU = SKU,
               @cLOT = LOT,
               @cStatus = Status,
               @nSYSQTY = CASE [Status] WHEN '4' THEN Qty ELSE SystemQty END,    -- (james11)
               -- Entered ID is optional, it can be blank
               @cSYSID = CASE WHEN (@cID_In <> '' AND @cID_In IS NOT NULL) THEN @cID_In ELSE [ID] END, -- SOS79743
               @cCCDetailKey = CCDetailKey,
               @cCountedFlag =
                  CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN '[C]'
                       WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN '[C]'
                       WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN '[C]'
                  ELSE '[ ]' END,
               @cLottable01 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable01
                       WHEN @nCCCountNo = 2 THEN Lottable01_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable01_Cnt3
                  ELSE '' END,
               @cLottable02 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable02
                       WHEN @nCCCountNo = 2 THEN Lottable02_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable02_Cnt3
                  ELSE '' END,
               @cLottable03 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable03
                       WHEN @nCCCountNo = 2 THEN Lottable03_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable03_Cnt3
                  ELSE '' END,
               @dLottable04 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable04
                       WHEN @nCCCountNo = 2 THEN Lottable04_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable04_Cnt3
                  ELSE NULL END,
               @dLottable05 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable05
                       WHEN @nCCCountNo = 2 THEN Lottable05_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable05_Cnt3
                  ELSE NULL END,
               @cLottable06 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable06
                       WHEN @nCCCountNo = 2 THEN Lottable06_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable06_Cnt3
                  ELSE '' END,
               @cLottable07 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable07
                       WHEN @nCCCountNo = 2 THEN Lottable07_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable07_Cnt3
                  ELSE '' END,
               @cLottable08 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable08
                       WHEN @nCCCountNo = 2 THEN Lottable08_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable08_Cnt3
                  ELSE '' END,
               @cLottable09 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable09
                       WHEN @nCCCountNo = 2 THEN Lottable09_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable09_Cnt3
                  ELSE NULL END,
               @cLottable10 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable10
                       WHEN @nCCCountNo = 2 THEN Lottable10_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable10_Cnt3
                  ELSE NULL END,
               @cLottable11 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable11
                       WHEN @nCCCountNo = 2 THEN Lottable11_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable11_Cnt3
                  ELSE '' END,
               @cLottable12 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable12
                       WHEN @nCCCountNo = 2 THEN Lottable12_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable12_Cnt3
                  ELSE '' END,
               @dLottable13 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable13
                       WHEN @nCCCountNo = 2 THEN Lottable13_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable13_Cnt3
                  ELSE '' END,
               @dLottable14 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable14
                       WHEN @nCCCountNo = 2 THEN Lottable14_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable14_Cnt3
                  ELSE NULL END,
               @dLottable15 =
                  CASE WHEN @nCCCountNo = 1 THEN Lottable15
                       WHEN @nCCCountNo = 2 THEN Lottable15_Cnt2
                       WHEN @nCCCountNo = 3 THEN Lottable15_Cnt3
                  ELSE NULL END
            FROM dbo.CCDETAIL (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
            AND   LOC = @cLOC
            -- SOS79743
            -- AND   ID = @cID
            AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
            AND   RefNo = @cUCC
            AND   Status < '9'

         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cNewSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 5, 6, 
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

            /***************************************************
             CCDETAIL.Status as
             '0'   -- Open    => data generated from inventory
             '2'   -- Counted => system generated data
             '4'   -- Counted => newly inserted data
        '9'   -- Posted  => data posted to inventory
            ****************************************************/

            -- (MaryVong01)
            -- Validate CCDETAIL CountedFlag + Status if NOT to recount
            IF @cRecountFlag <> 'Y'
            BEGIN
               IF @cCountedFlag = '[C]' AND @cStatus = '2'
               BEGIN
                  SET @nErrNo = 62101
                  SET @cErrMsg = rdt.rdtgetmessage( 62101, @cLangCode, 'DSP') -- 'Double scan'
           GOTO UCC_Fail
               END

               IF @cCountedFlag = '[C]' AND @cStatus = '4'
               BEGIN
                  SET @nErrNo = 62102
                  SET @cErrMsg = rdt.rdtgetmessage( 62102, @cLangCode, 'DSP') -- 'Scanned (New)'
                  GOTO UCC_Fail
               END
            END

            /****************************************************************************************
             Do not validate newly inserted record (status = '4')
             Reasons: It could be a misplaced UCC that having actual LOC or ID different from UCC.
             While come to 2nd/3rd count, should exclude validation on these records, just
                      concentrate on records with status = '0' or '2'
            *****************************************************************************************/
            IF @cStatus <> '4'
            BEGIN
               SET @nErrNo = 0
               EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                  @cUCC,
                  @cStorerKey,
                  '1',     -- Received status
                  @cChkSKU = @cSKU,    -- Validate UCC sku
                  @nChkQTY = 1,        -- Turn on validation of UCC Qty
                  @cChkLOT = @cLOT,    -- Validate UCC lot
                  @cChkLOC = @cLOC,    -- Validate UCC loc
                  @cChkID  = @cSYSID   -- Validate UCC id

               IF @nErrNo > 0
                  GOTO UCC_Fail
            END

            -- Update for uncounted record
            IF @cCountedFlag = '[ ]' OR @cRecountFlag = 'Y' -- Allow to recount
            BEGIN
               -- If matched, update CCDETAIL
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_UpdateCCDetail_V7
                  @nMobile,
                  @nFunc,
                  @cLangCode,
                  @nStep,
                  @nInputKey,
                  @cFacility,
                  @cStorerKey,
                  @cCCRefNo,
                  @cCCSheetNo,
                  @nCCCountNo,
                  @cCCDetailKey,
                  @nSYSQTY,
                  @nErrNo       OUTPUT,
                  @cErrMsg      OUTPUT   -- screen limitation, 20 char max
               IF @nErrNo <> 0
                  GOTO UCC_Fail

               -- Increase counter by 1
               SET @nCntQTY = @nCntQTY + 1

               -- Reduce carton count if count by pallet (james10)
               IF @cDefaultCCOption = '4'
               BEGIN
                  SET @nCtnCount = @nCtnCount - 1

                  -- If finish counting carton then go back sheet no sceen
                  IF @nCtnCount <= 0
                  BEGIN
                     -- Prepare next screen var
                     SET @cOutField01 = @cCCRefNo
                     SET @cOutField02 = @cCCSheetNo
                     SET @cOutField03 = @nCCCountNo

                     SET @nScn = @nScn_CountNo
                     SET @nStep = @nStep_CountNo

                     GOTO Quit
                  END
               END
            END

         END -- End of Found in CCDETAIL

         -- Get SKU DESCR
         SELECT @cSKUDescr = DESCR
         FROM   dbo.SKU (NOLOCK)
         WHERE  StorerKey = @cStorerKey
            AND SKU = @cSKU

         -- Prepare current (UCC) screen var
         SET @cOutField01 = ''      -- UCC
         SET @cOutField02 = CASE WHEN @cBlindCount = '1' THEN '' ELSE @cSKU END
         SET @cOutField03 = CASE WHEN @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20) END
         SET @cOutField04 = CASE WHEN @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 40) END
         SET @cOutField05 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorerKey) = 1 THEN 0 ELSE CAST( @nSYSQTY AS NVARCHAR( 5)) END
         SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                                 THEN RIGHT( SPACE(5) + CAST( @nCntQTY AS NVARCHAR( 5)), 5)
                                 ELSE CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
                                 END

      END
      -- End of OPT = blank
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Press ESC treat as Empty loc
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT
         CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorerKey ELSE StorerKey END,
         SKU,
         LOT,
         Status,
         SystemQty,
         CASE WHEN (@cID_In <> '' AND @cID_In IS NOT NULL) THEN @cID_In ELSE [ID] END,
         CCDetailKey
      FROM dbo.CCDETAIL (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
      AND   LOC = @cLOC
      AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
      AND   Status < '9'
      AND 1 =  CASE
                  WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0
                  WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0
                  WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0
                  ELSE 1
               END
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cStorerKey, @cSKU, @cLOT, @cStatus, @nSYSQTY, @cSYSID, @cCCDetailKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- If found, update CCDETAIL
         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXECUTE rdt.rdt_CycleCount_UpdateCCDetail_V7
            @nMobile,
            @nFunc,
            @cLangCode,
            @nStep,
            @nInputKey,
            @cFacility,
            @cStorerKey,
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cCCDetailKey,
            @nQTY,
            @nErrNo       OUTPUT,
            @cErrMsg      OUTPUT   -- screen limitation, 20 char max
         IF @nErrNo <> 0
         BEGIN
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
            -- Reset this screen var
            SET @cOutField01 = '' -- UCC
            SET @cOutField12 = '' -- OPT
            GOTO Quit
         END

         FETCH NEXT FROM CUR_LOOP INTO @cStorerKey, @cSKU, @cLOT, @cStatus, @nSYSQTY, @cSYSID, @cCCDetailKey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      -- (MaryVong01)
      -- Release RDTCCLock
      DELETE FROM RDT.RDTCCLock
      WHERE CCKey = @cCCRefNo
      AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN SheetNo ELSE @cCCSheetNo END
      AND   CountNo = @nCCCountNo
      AND   AddWho = @cUserName
      AND   Status = '1'
      AND   Loc = @cLOC
      AND   Id = @cID

      -- Set back previous values
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = @cDefaultCCOption -- Option
      SET @cOutField07 = ''                -- ID
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      SET @cOutField13 = ''

      -- SOS# 179935
      IF @cDefaultCCOption = ''
         EXEC rdt.rdtSetFocusField @nMobile, 6   -- Option
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- ID

      -- Go to previous screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END
   GOTO Quit

   UCC_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- UCC
      SET @cOutField12 = '' -- OPT
   END
END
GOTO Quit

/************************************************************************************
Step_UCC_Add_Ucc. Scn = 669. Screen 7.
   LOC         (field01)
   ID          (field02)
   UCC         (field03) - Input field
************************************************************************************/
Step_UCC_Add_Ucc:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cNewUCC = @cInField03

      -- Retain the key-in value         SET @cOutField03 = @cNewUCC

      -- Validate blank UCC
      IF @cNewUCC = '' OR @cNewUCC IS NULL
      BEGIN
         SET @nErrNo = 62103
         SET @cErrMsg = rdt.rdtgetmessage( 62103, @cLangCode, 'DSP') -- 'UCC needed'
         GOTO UCC_Add_Ucc_Fail
      END

      -- Validate UCC Status
      SET @cStatus = '0'

      SELECT @cStatus = Status
      FROM dbo.UCC (NOLOCK)
      WHERE UCCNo = @cNewUCC

--      IF @@ROWCOUNT = 1 AND @cStatus <> '1'
--    Allow to add UCC with status < '6'
      IF @@ROWCOUNT = 1 AND @cStatus = '6'    -- (james10)
      BEGIN
         SET @nErrNo = 62104
         SET @cErrMsg = rdt.rdtgetmessage( 62104, @cLangCode, 'DSP') -- 'UCC Status bad'
         GOTO UCC_Add_Ucc_Fail
      END

      SET @nErrNo = 0
      EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT,
         @cNewUCC,
         @cStorerKey,
         '1',          -- Received status
         @nChkQTY = 1  -- Turn on validation of UCC Qty

      IF @nErrNo > 0
         GOTO UCC_Add_Ucc_Fail

      -- Get Status and CountedFlag from CCDetail
      SET @cCountedFlag = '[ ]'

      SELECT TOP 1
         @cStatus = Status,
         @cCountedFlag =
            CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN '[C]'
                 WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN '[C]'
                 WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN '[C]'
            ELSE '[ ]' END
      FROM dbo.CCDETAIL (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
      AND   LOC = @cLOC
      -- SOS79743
      -- AND   ID = @cID
      AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
      AND   RefNo = @cNewUCC
      AND   Status < '9'

      -- (MaryVong01)
      -- Validate CCDETAIL CountedFlag + Status if NOT Recount
      IF @cRecountFlag <> 'Y'
      BEGIN
         IF @cCountedFlag = '[C]' AND @cStatus = '2'
         BEGIN
            SET @nErrNo = 62105
            SET @cErrMsg = rdt.rdtgetmessage( 62105, @cLangCode, 'DSP') -- 'Double scan'
            GOTO UCC_Add_Ucc_Fail
         END

         IF @cCountedFlag = '[C]' AND @cStatus = '4'
         BEGIN
            SET @nErrNo = 62106
            SET @cErrMsg = rdt.rdtgetmessage( 62106, @cLangCode, 'DSP') -- 'Scanned (New)'
            GOTO UCC_Add_Ucc_Fail
         END
      END

      -- Get SKU DESCR, UCC QTY
      SELECT
         @cNewSKU = SKU.SKU,
         @cNewSKUDescr = SKU.DESCR,
         --@nNewCaseCnt = PAC.CaseCnt
         @nNewUCCQTY = UCC.QTY
      FROM dbo.UCC UCC (NOLOCK)
      INNER JOIN dbo.SKU SKU (NOLOCK) ON (UCC.StorerKey = SKU.StorerKey AND
                                                   UCC.SKU = SKU.SKU)
      INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE UCC.StorerKey = @cStorerKey
      AND   UCCNo = @cNewUCC

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62107
         SET @cErrMsg = rdt.rdtgetmessage( 62107, @cLangCode, 'DSP') -- 'UCC Not Found'
         GOTO UCC_Add_Ucc_Fail
      END

--       -- CaseCnt must be setup
--       IF @nNewCaseCnt = 0
--       BEGIN
--          SET @nErrNo = 62110
--          SET @cErrMsg = rdt.rdtgetmessage( 62110, @cLangCode, 'DSP') -- 'Setup CaseCnt'
--          GOTO UCC_Add_Ucc_Fail
--       END

      SET @cNewSKUDescr1 = SUBSTRING( @cNewSKUDescr, 1, 20)
      SET @cNewSKUDescr2 = SUBSTRING( @cNewSKUDescr, 21, 40)

      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cNewUCC
      SET @cOutField04 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cNewSKU END
      SET @cOutField05 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cNewSKUDescr1 END
      SET @cOutField06 = case when @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cNewSKUDescr2 END
      --SET @cOutField07 = CAST( @nNewCaseCnt AS NVARCHAR( 4))
      --SET @cOutField07 = CAST( @nNewUCCQTY AS NVARCHAR( 5))   -- (jamesxx)
      SET @cOutField07 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorerKey) = 1 THEN 0 ELSE
                              CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN 0 ELSE CAST( @nNewUCCQTY AS NVARCHAR( 5)) END END --(jamesxx)
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      SET @cOutField13 = ''

      -- Go to next screen
      SET @nScn  = @nScn_UCC_Add_SkuQty
      SET @nStep = @nStep_UCC_Add_SkuQty
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare previous screen var
      SET @cOutField01 = ''   -- UCC
      SET @cOutField02 = CASE WHEN @cBlindCount = '1' THEN '' ELSE @cSKU END
      SET @cOutField03 = CASE WHEN @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20) END
      SET @cOutField04 = CASE WHEN @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 40) END
      --SET @cOutField05 = CAST( @nCaseCnt AS NVARCHAR( 4))
      SET @cOutField05 = CAST( @nUCCQTY AS NVARCHAR( 5))
--    SET @cOutField11 = CAST( @nCntQTY AS NVARCHAR( 2)) + '/' + CAST( @nTotCarton AS NVARCHAR( 2))
      SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                              THEN RIGHT( SPACE(5) + CAST( @nCntQTY AS NVARCHAR( 5)), 5)
                              ELSE CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
                              END
      SET @cOutField12 = ''
      SET @cOutField13 = ''

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

      -- Go to previous screen
      SET @nScn  = @nScn_UCC
      SET @nStep = @nStep_UCC
   END
   GOTO Quit

   UCC_Add_Ucc_Fail:
   BEGIN
      -- Reset this screen var
 SET @cOutField03 = '' -- UCC
   END
END
GOTO Quit

/************************************************************************************
Step_UCC_Add_SkuQty. Scn = 670. Screen 8.
   LOC         (field01)
   ID          (field02)
   UCC         (field03)
   SKU         (field04)
   SKU DESCR1  (field05)
   SKU DESCR2  (field06)
   QTY         (field07)
************************************************************************************/
Step_UCC_Add_SkuQty:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- (MaryVong01)
      -- Initialize Lottables
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = NULL
      SET @dLottable05 = NULL

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

      SET @cErrMsg = ''

      -- SOS#81879
      -- Get Lottables Details
      EXECUTE rdt.rdt_CycleCount_GetLottables
         @cCCRefNo, @cStorerKey, @cNewSKU, 'PRE', -- Codelkup.Short
         '', --@cIn_Lottable01
         '', --@cIn_Lottable02
         '', --@cIn_Lottable03
         '', --@dIn_Lottable04
         '', --@dIn_Lottable05
         @cLotLabel01      OUTPUT,
         @cLotLabel02      OUTPUT,
         @cLotLabel03      OUTPUT,
         @cLotLabel04      OUTPUT,
         @cLotLabel05      OUTPUT,
         @cLottable01_Code OUTPUT,
         @cLottable02_Code OUTPUT,
         @cLottable03_Code OUTPUT,
         @cLottable04_Code OUTPUT,
         @cLottable05_Code OUTPUT,
         @cLottable01      OUTPUT,
         @cLottable02      OUTPUT,
         @cLottable03      OUTPUT,
         @dLottable04      OUTPUT,
         @dLottable05      OUTPUT,
         @cHasLottable     OUTPUT,
         @nSetFocusField   OUTPUT,
         @nErrNo           OUTPUT,
         @cErrMsg          OUTPUT

      IF ISNULL(@cErrMsg, '') <> ''
         GOTO UCC_Add_SkuQty_Fail

      -- Initiate next screen var
      IF @cHasLottable = '1'
      BEGIN
         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cNewSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 5, 6, 
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

         -- Go to next screen
         SET @nScn  = @nScn_UCC_Add_Lottables
         SET @nStep = @nStep_UCC_Add_Lottables
      END -- End of @cHasLottable = '1'

      IF @cHasLottable = '0'
      BEGIN
        -- Insert a record into CCDETAIL
         SET @nErrNo = 0
         SET @cErrMsg = ''
            EXECUTE rdt.rdt_CycleCount_InsertCCDetail_V7
               @nMobile,
               @nFunc,
               @cLangCode,
               @nStep,
               @nInputKey,
               @cFacility,
               @cStorerKey,
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cNewSKU,
               @cNewUCC,
               '',            -- No LOT generated yet
               @cLOC,         -- Current LOC
               @cID,          -- Entered ID, it can be blank
               @nNewUCCQTY,
               '',            -- Lottable01
               '',            -- Lottable02
               '',            -- Lottable03
               NULL,          -- Lottable04
               NULL,          -- Lottable05
               '',            -- Lottable06
               '',            -- Lottable07
               '',            -- Lottable08
               '',            -- Lottable09
               '',            -- Lottable10
               '',            -- Lottable11
               '',            -- Lottable12
               NULL,          -- Lottable13
               NULL,          -- Lottable14
               NULL,          -- Lottable15
               @cCCDetailKey OUTPUT,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT   -- screen limitation, 20 char max

         IF @nErrNo <> 0
            GOTO UCC_Add_SkuQty_Fail

         -- Increase counter by 1
         SET @nCntQTY = @nCntQTY + 1
         SET @nTotCarton = @nTotCarton + 1

         -- Reduce carton count if count by pallet (james10)
         IF @cDefaultCCOption = '4'
         BEGIN
            SET @nCtnCount = @nCtnCount - 1

            -- If finish counting carton then go back sheet no sceen
            IF @nCtnCount <= 0
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = @cCCRefNo
               SET @cOutField02 = @cCCSheetNo
               SET @cOutField03 = @nCCCountNo

               SET @nScn = @nScn_CountNo
               SET @nStep = @nStep_CountNo

               GOTO Quit
            END
         END

         -- Set variables
         SET @cUCC = @cNewUCC
         SET @cSKU = @cNewSKU
         SET @cSKUDescr = @cNewSKUDescr1 + @cNewSKUDescr2
         ---SET @nCaseCnt = @nNewCaseCnt
         SET @nUCCQTY = @nNewUCCQTY

         -- Prepare UCC (Main) screen var
         SET @cOutField01 = ''
         SET @cOutField02 = CASE WHEN @cBlindCount = '1' THEN '' ELSE @cSKU END
         SET @cOutField03 = CASE WHEN @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20) END
         SET @cOutField04 = CASE WHEN @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 40) END
         -- SET @cOutField05 = CAST( @nCaseCnt AS NVARCHAR( 4))
--         SET @cOutField05 = CAST( @nUCCQTY AS NVARCHAR( 5))   -- (jamesxx)
         SET @cOutField05 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorerKey) = 1 THEN 0 ELSE CAST( @nNewUCCQTY AS NVARCHAR( 5)) END --(jamesxx)
         SET @cOutField06 = ''   -- Lottable01
         SET @cOutField07 = ''   -- Lottable02
         SET @cOutField08 = ''   -- Lottable03
         SET @cOutField09 = ''   -- Lottable04
         SET @cOutField10 = ''   -- Lottable05
--       SET @cOutField11 = CAST( @nCntQTY AS NVARCHAR( 2)) + '/' + CAST( @nTotCarton AS NVARCHAR( 2))
         SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                                 THEN RIGHT( SPACE(5) + CAST( @nCntQTY AS NVARCHAR( 5)), 5)
                                 ELSE CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
                                 END
         SET @cOutField12 = ''   -- Option

         -- Go to UCC (Main) screen
         SET @nScn  = @nScn_UCC
         SET @nStep = @nStep_UCC
      END -- End of @cHasLottable = '0'
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
   SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''   -- UCC
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField12 = ''

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

      -- Go to previous screen
      SET @nScn  = @nScn_UCC_Add_Ucc
      SET @nStep = @nStep_UCC_Add_Ucc
   END
   GOTO Quit

   UCC_Add_SkuQty_Fail:

END
GOTO Quit

/************************************************************************************
Step_UCC_Add_Lottables. Scn = 671. Screen 9.
   LOTTABLE01Label (field01)     LOTTABLE01 (field02) - Input field
   LOTTABLE02Label (field03)     LOTTABLE02 (field04) - Input field
   LOTTABLE03Label (field05)     LOTTABLE03 (field06) - Input field
   LOTTABLE04Label (field07)     LOTTABLE04 (field08) - Input field
   LOTTABLE05Label (field09)     LOTTABLE05 (field10) - Input field
*************************************************************************************/
Step_UCC_Add_Lottables:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'CHECK', 5, 1, 
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
         '',
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Screen mapping
      SET @cNewLottable01 = @cInField02
      SET @cNewLottable02 = @cInField04
      SET @cNewLottable03 = @cInField06
      SET @cNewLottable04 = @cInField08
      SET @cNewLottable05 = @cInField10

      -- Retain the key-in value
      SET @cOutField02 = @cNewLottable01
      SET @cOutField04 = @cNewLottable02
      SET @cOutField06 = @cNewLottable03
      SET @cOutField08 = @cNewLottable04
      SET @cOutField10 = @cNewLottable05

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

 -- (MaryVong01)
      SET @cErrMsg = ''

      -- Insert a record into CCDETAIL
      SET @nErrNo = 0
      SET @cErrMsg = ''
      EXECUTE rdt.rdt_CycleCount_InsertCCDetail_V7
         @nMobile,
         @nFunc,
         @cLangCode,
         @nStep,
         @nInputKey,
         @cFacility,
         @cStorerKey,
         @cCCRefNo,
         @cCCSheetNo,
         @nCCCountNo,
         @cNewSKU,
         @cNewUCC,      
         '',            -- No LOT generated yet
         @cLOC,         -- Current LOC
         @cID,          -- Entered ID, it can be blank
         @nNewUCCQTY,
         @cLottable01,
         @cLottable02,
         @cLottable03,
         @dLottable04,
         @dLottable05,
         @cLottable06,
         @cLottable07,
         @cLottable08,
         @cLottable09,
         @cLottable10,
         @cLottable11,
         @cLottable12,
         @dLottable13,
         @dLottable14,
         @dLottable15,
         @cCCDetailKey OUTPUT,
         @nErrNo       OUTPUT,
         @cErrMsg      OUTPUT   -- screen limitation, 20 char max

      IF @nErrNo <> 0
         GOTO UCC_Add_Lottables_Fail

      -- Increase counter by 1
      SET @nCntQTY = @nCntQTY + 1
      SET @nTotCarton = @nTotCarton + 1

      -- Reduce carton count if count by pallet (james10)
      IF @cDefaultCCOption = '4'
      BEGIN
         SET @nCtnCount = @nCtnCount - 1

         -- If finish counting carton then go back sheet no sceen
         IF @nCtnCount <= 0
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cCCRefNo
            SET @cOutField02 = @cCCSheetNo
            SET @cOutField03 = @nCCCountNo

            SET @nScn = @nScn_CountNo
            SET @nStep = @nStep_CountNo

            GOTO Quit
         END
      END

      -- Set variables
      SET @cUCC = @cNewUCC
      SET @cSKU = @cNewSKU
      SET @cSKUDescr = @cNewSKUDescr1 + @cNewSKUDescr2
      --SET @nCaseCnt = @nNewCaseCnt
      SET @nUCCQTY = @nNewUCCQTY
      SET @cLottable01 = @cNewLottable01
      SET @cLottable02 = @cNewLottable02
      SET @cLottable03 = @cNewLottable03
      SET @dLottable04 = @dNewLottable04
      SET @dLottable05 = @dNewLottable05

      -- Prepare UCC (Main) screen var
      SET @cOutField01 = ''
      SET @cOutField02 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cSKU END
      SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20) END
      SET @cOutField04 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 40) END
      --SET @cOutField05 = CAST( @nCaseCnt AS NVARCHAR( 4))
      SET @cOutField05 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorerKey) = 1 THEN 0 ELSE
                         CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN 0 ELSE CAST( @nUCCQTY AS NVARCHAR( 5)) END END --(jamesxx)
      SET @cOutField06 = @cLottable01
      SET @cOutField07 = @cLottable02
      SET @cOutField08 = @cLottable03
      SET @cOutField09 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField10 = rdt.rdtFormatDate( @dLottable05)
--    SET @cOutField11 = CAST( @nCntQTY AS NVARCHAR( 2)) + '/' + CAST( @nTotCarton AS NVARCHAR( 2))
      SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                              THEN RIGHT( SPACE(5) + CAST( @nCntQTY AS NVARCHAR( 5)), 5)
                              ELSE CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
                              END
      SET @cOutField12 = ''   -- Option

      -- Go to UCC (Main) screen
      SET @nScn  = @nScn_UCC
      SET @nStep = @nStep_UCC
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare previous screen var
 SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cNewUCC
      SET @cOutField04 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cNewSKU END
      SET @cOutField05 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cNewSKUDescr1 END
      SET @cOutField06 = case when @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cNewSKUDescr2 END
      --SET @cOutField07 = CAST( @nNewCaseCnt AS NVARCHAR( 4))
      SET @cOutField07 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorerKey) = 1 THEN 0 ELSE
                              CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN 0 ELSE CAST( @nNewUCCQTY AS NVARCHAR( 5)) END END --(jamesxx)
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      SET @cOutField13 = ''
      SET @cOutField13 = ''

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

      -- Go to previous screen
      SET @nScn  = @nScn_UCC_Add_SkuQty
      SET @nStep = @nStep_UCC_Add_SkuQty
   END
  GOTO Quit

   UCC_Add_Lottables_Fail:
   BEGIN
      -- (Vicky02) - Start
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      -- (Vicky02) - End

      -- Init next screen var
      IF @cHasLottable = '1'
      BEGIN
         -- Disable lottable
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr02 = 'O'
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr04 = 'O'
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
            SET @cFieldAttr06 = 'O'
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O'
         END

         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
         BEGIN
            SET @cFieldAttr10 = 'O'
         END

      END
   END
END
GOTO Quit


/************************************************************************************
Step_UCC_Edit_QTY. Scn = 703. Screen 9.

*************************************************************************************/
Step_UCC_Edit_QTY:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cUCCQTY NVARCHAR( 5)

      -- Screen mapping
      SET @cUCCQTY = @cInField01

      -- Validate QTY
      IF rdt.rdtIsValidQTY( @cUCCQTY, 20) <> 1 -- Do Not Check for zero
      BEGIN
         SET @nErrNo = 62122
         SET @cErrMsg = rdt.rdtgetmessage( 62122, @cLangCode, 'DSP') -- 'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 1   -- QTY
         GOTO Quit
      END
      SET @nQTY = CAST( @cUCCQTY AS INT)

      -- Update CCDetail
      EXECUTE rdt.rdt_CycleCount_UpdateCCDetail_V7
         @nMobile,
         @nFunc,
         @cLangCode,
         @nStep,
         @nInputKey,
         @cFacility,
         @cStorerKey,
         @cCCRefNo,
         @cCCSheetNo,
         @nCCCountNo,
         @cCCDetailKey,
         @nQTY,
         @nErrNo       OUTPUT,
         @cErrMsg      OUTPUT   -- screen limitation, 20 char max
      IF @nErrNo <> 0
         GOTO Quit

      SET @nUCCQTY = @nQTY

      -- Reduce carton count if count by pallet (james10)
      IF @cDefaultCCOption = '4'
      BEGIN
         SET @nCtnCount = @nCtnCount - 1

         -- If finish counting carton then go back sheet no sceen
         IF @nCtnCount <= 0
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cCCRefNo
            SET @cOutField02 = @cCCSheetNo
            SET @cOutField03 = @nCCCountNo

            SET @nScn = @nScn_CountNo
            SET @nStep = @nStep_CountNo

            GOTO Quit
         END
      END
   END

   -- Get total counted/total carton   (jamesxx)
   SET @nCntQTY = 0
   SET @nTotCarton = 0

   -- Get no. of counted cartons
   SELECT @nCntQTY = COUNT(1)
   FROM dbo.CCDETAIL (NOLOCK)
   WHERE CCKey = @cCCRefNo
   AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
   AND   LOC = @cLOC
   -- SOS79743
   -- AND   ID = @cID
   AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
   AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
                  WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
      WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
             ELSE 0 END
   AND   (Status = '2' OR Status = '4')

   -- Get total cartons for particular LOC and ID (if any)
   SELECT @nTotCarton = COUNT(1)
   FROM dbo.CCDETAIL (NOLOCK)
   WHERE CCKey = @cCCRefNo
   AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
   AND   LOC = @cLOC
   -- SOS79743
   -- AND   ID = @cID
   AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
   -- Remarked by MaryVong on 05-Jul-2007 Count all ccdetail lines
   -- To avoid confusion since location for UCC is not shared with SKU/UPC
   -- AND   (RefNo <> '' AND RefNo IS NOT NULL)

   -- (MaryVong01)
   IF @cRecountFlag = 'Y'
      SET @nCntQTY = 0

   -- Prepare previous screen var
   SET @cOutField01 = ''   -- UCC
   SET @cOutField02 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cSKU END
   SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20) END
   SET @cOutField04 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 40) END
   --SET @cOutField05 = CAST( @nCaseCnt AS NVARCHAR( 4))
   --SET @cOutField05 = CAST( @nUCCQTY AS NVARCHAR( 5))
   SET @cOutField05 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorerKey) = 1 THEN 0 ELSE
                           CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN 0 ELSE CAST( @nNewUCCQTY AS NVARCHAR( 5)) END END --(jamesxx)

   SET @cOutField06 = @cLottable01
   SET @cOutField07 = @cLottable02
   SET @cOutField08 = @cLottable03
   SET @cOutField09 = rdt.rdtFormatDate( @dLottable04)
   SET @cOutField10 = rdt.rdtFormatDate( @dLottable05)
-- SET @cOutField11 = CAST( @nCntQTY AS NVARCHAR( 2)) + '/' + CAST( @nTotCarton AS NVARCHAR( 2))
   SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                           THEN RIGHT( SPACE(5) + CAST( @nCntQTY AS NVARCHAR( 5)), 5)
                           ELSE CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
                           END
   SET @cOutField12 = ''
   SET @cOutField13 = ''

   -- (Vicky02) - Start
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
   -- (Vicky02) - End

   -- Go to previous screen
   SET @nScn  = @nScn_UCC
   SET @nStep = @nStep_UCC
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate       = GETDATE(),
      ErrMsg         = @cErrMsg,
      Func           = @nFunc,
      Step           = @nStep,
      Scn            = @nScn,

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,

      V_LOC          = @cLOC,
      V_ID           = @cID,
      V_LOT          = @cLOT,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
      V_UOM          = @cUOM,
--      V_QTY          = @nQTY,
      V_UCC          = @cUCC,
      V_Lottable01   = @cLottable01,
      V_Lottable02   = @cLottable02,
      V_Lottable03   = @cLottable03,
      V_Lottable04   = @dLottable04,
      V_Lottable05   = @dLottable05,

      V_String1      = @cCCRefNo,
      V_String2      = @cCCSheetNo,
      V_String3      = @cLottableCode,
      V_String4      = @cSuggestLOC,
      V_String5      = @cSuggestLogiLOC,
--      V_String6      = @nCntQTY,
--      V_String7      = @nTotCarton,
      V_String8      = @cStatus,
      V_String9      = @cPPK,
    --V_String10     = @cUCCConfig,
      V_String10     = @cSheetNoFlag,  -- (MaryVong01)
      V_String11     = @cLocType,
      V_String12     = @cCCDetailKey,
--      V_String13     = @nUCCQTY,
--      V_String14     = @nCaseCnt,
--      V_String15     = @nCaseQTY,
      V_String16     = @cCaseUOM,
--      V_String17     = @nEachQTY,
      V_String18     = @cEachUOM,
    --V_String19     = @cHasLottable,
      V_String19     = @cLastLocFlag,   -- (MaryVong01)
      V_String20     = @cDefaultCCOption,

      V_String21     = @cCountedFlag,
      V_String22     = @cWithQtyFlag,

      V_String23     = @cNewUCC,
      V_String24     = @cNewSKU,
      V_String25     = @cNewSKUDescr1,
      V_String26     = @cNewSKUDescr2,
--      V_String27     = @nNewUCCQTY,
--      V_String28     = @nNewCaseCnt,
--      V_String29     = @nNewCaseQTY,
      V_String30     = @cNewCaseUOM,
--      V_String31     = @nNewEachQTY,
      V_String32     = @cNewEachUOM,
      V_String33     = @cNewPPK,
      V_String34     = @cNewLottable01,
      V_String35     = @cNewLottable02,
      V_String36     = @cNewLottable03,
--      V_String37     = @dNewLottable04,
--      V_String38     = @dNewLottable05,
    --V_String39     = @cLottable05_Code,
      V_String39     = @cAddNewLocFlag,   -- (MaryVong01)
      V_String40     = @cID_In,  -- SOS79743

      -- (MaryVong01)
      V_ReceiptKey   = @cRecountFlag,      -- Used for RecountFlag
--      V_POKey        = @nCCDLinesPerLOCID, -- Total CCDetail Lines (LOC+ID)
      V_LoadKey      = @cPrevCCDetailKey,  -- Used to control Counter in SKU screen
    --V_OrderKey     = @cEscSKU, -- (Vicky03)
      V_PickSlipNo   = @cEditSKU, -- (Vicky03)
      V_ConsigneeKey = @cBlindCount,   -- (james10)
--      V_CaseID       = @nCtnCount,     -- (james10)
--      V_OrderKey     = @nNoOfTry,      -- (james12)
      V_String41     = @cCurSuggestLogiLOC,

      V_Integer1     = @nQTY,
      V_Integer2     = @nCCCountNo,
      V_Integer3     = @nCntQTY,
      V_Integer4     = @nTotCarton,
      V_Integer5     = @nUCCQTY,
      V_Integer6     = @nCaseCnt,
      V_Integer7     = @nCaseQTY,
      V_Integer8     = @nEachQTY,
      V_Integer9     = @nNewUCCQTY,
      V_Integer10    = @nNewCaseCnt,
      V_Integer11    = @nNewCaseQTY,
      V_Integer12    = @nNewEachQTY,
      V_Integer13    = @nCCDLinesPerLOCID,
      V_Integer14    = @nCtnCount,
      V_Integer15    = @nFromScn,
      
      V_DateTime1    = @dNewLottable04,
      V_DateTime2    = @dNewLottable05,
      
      I_Field01 = '',  O_Field01 = @cOutField01,
      I_Field02 = '',  O_Field02 = @cOutField02,
      I_Field03 = '',  O_Field03 = @cOutField03,
      I_Field04 = '',  O_Field04 = @cOutField04,
      I_Field05 = '',  O_Field05 = @cOutField05,
      I_Field06 = '',  O_Field06 = @cOutField06,
      I_Field07 = '',  O_Field07 = @cOutField07,
      I_Field08 = '',  O_Field08 = @cOutField08,
      I_Field09 = '',  O_Field09 = @cOutField09,
      I_Field10 = '',  O_Field10 = @cOutField10,
      I_Field11 = '',  O_Field11 = @cOutField11,
      I_Field12 = '',  O_Field12 = @cOutField12,
      I_Field13 = '',  O_Field13 = @cOutField13,
      I_Field14 = '',  O_Field14 = @cOutField14,
      I_Field15 = '',  O_Field15 = @cOutField15,

      -- (Vicky02) - Start
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15
    -- (Vicky02) - End

   WHERE Mobile = @nMobile

END

GO
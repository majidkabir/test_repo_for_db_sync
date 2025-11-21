SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_CycleCount_SKU_V7                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 06-May-2019 1.0  James    WMS-8649 Created                           */
/* 07-May-2021 1.1  Chermain WMS-16932 remove rdt_CycleCount_GetLottables*/
/*                           at screen 12 (cc01)                        */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_CycleCount_SKU_V7] (
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
   @cLotLabel01       NVARCHAR( 20), -- labels
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

   @cStorerKey           NVARCHAR( 15),
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
   @cLottableCode       NVARCHAR( 30),
   @nAfterStep       INT

DECLARE @c_debug  NVARCHAR(1)
   SET @c_debug = 0

-- SOS#81879 (Start)
DECLARE  
	@cLottable01_Code    NVARCHAR( 20), 
   @cLottable02_Code    NVARCHAR( 20), 
   @cLottable03_Code    NVARCHAR( 20), 
   @cLottable04_Code    NVARCHAR( 20), 
   @cLottable05_Code    NVARCHAR( 20), 
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
   @tExtValidate           VARIABLETABLE,  -- (james26)
   @tExtUpdate             VARIABLETABLE,  -- (james26)
   @tExtInfo               VARIABLETABLE,  -- (james26)
   @cExtendedInfo          NVARCHAR( 20),  -- (james26)
   @cExtendedInfoSP        NVARCHAR( 20),  -- (james26)
   @cExtendedValidate      NVARCHAR( 20),  -- (james26)
   @cExtendedUpdate        NVARCHAR( 20),  -- (james26)


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
   @nStep_SKU                      INT,  @nScn_SKU                      INT,
   @nStep_SKU_Add_Sku              INT,  @nScn_SKU_Add_Sku              INT,
   @nStep_SKU_Add_Qty              INT,  @nScn_SKU_Add_Qty              INT,
   @nStep_SKU_Add_Lottables        INT,  @nScn_SKU_Add_Lottables        INT,
   @nStep_SKU_Edit_Qty             INT,  @nScn_SKU_Edit_Qty             INT

SELECT
   @nStep_CCRef                    = 1,  @nScn_CCRef                    = 5430,
   @nStep_SheetNo_Criteria         = 2,  @nScn_SheetNo_Criteria         = 5431, 
   @nStep_CountNo                  = 3,  @nScn_CountNo                  = 5432,
   @nStep_LOC                      = 4,  @nScn_LOC                      = 5433,
   @nStep_LOC_Option               = 5,  @nScn_LOC_Option               = 5434, 
   @nStep_LAST_LOC_Option          = 6,  @nScn_LAST_LOC_Option          = 5435, 
   @nStep_RECOUNT_LOC_Option       = 7,  @nScn_RECOUNT_LOC_Option       = 5436, 
   @nStep_ID                       = 8,  @nScn_ID                       = 5437,
   @nStep_SKU                      = 9,  @nScn_SKU                      = 5438,
   @nStep_SKU_Add_Sku              = 10, @nScn_SKU_Add_Sku              = 5439,
   @nStep_SKU_Add_Qty              = 11, @nScn_SKU_Add_QTY              = 5440,
   @nStep_SKU_Add_Lottables        = 12, @nScn_SKU_Add_Lottables        = 5441,
   @nStep_SKU_Edit_Qty             = 13, @nScn_SKU_Edit_Qty             = 5442


IF @nFunc = 635 -- RDT Cycle Count
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start                    -- Menu. Func = 635
   IF @nStep = 1  GOTO Step_CCRef                    -- Scn = 5430. CCREF
   IF @nStep = 2  GOTO Step_SheetNo_Criteria         -- Scn = 5431. SHEET NO OR Selection Criteria
   IF @nStep = 3  GOTO Step_CountNo                  -- Scn = 5432. COUNT NO
   IF @nStep = 4  GOTO Step_LOC                      -- Scn = 5433. LOC
   IF @nStep = 5  GOTO Step_LOC_Option               -- Scn = 5434. LOC - Option
   IF @nStep = 6  GOTO Step_LAST_LOC_Option          -- Scn = 5435. Last LOC - Option
   IF @nStep = 7  GOTO Step_RECOUNT_LOC_Option       -- Scn = 5436. Re-Count LOC - Option
   IF @nStep = 8  GOTO Step_ID                       -- Scn = 5437. ID
   IF @nStep = 9  GOTO Step_SKU                      -- Scn = 5438. SKU
   IF @nStep = 10 GOTO Step_SKU_Add_Sku              -- Scn = 5439. SKU - Add SKU/UPC
   IF @nStep = 11 GOTO Step_SKU_Add_Qty              -- Scn = 5440. SKU - Add QTY
   IF @nStep = 12 GOTO Step_SKU_Add_Lottables        -- Scn = 5441. SKU - Add LOTTABLE01..05
   IF @nStep = 13 GOTO Step_SKU_Edit_Qty             -- Scn = 5442. SKU - Edit QTY
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 635. Screen 0.
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

      SET @nScn = @nScn_CCRef   -- 610
      SET @nStep = @nStep_CCRef -- 1
END
GOTO Quit

/************************************************************************************
Step_CCRef. Scn = 660. Screen 1.
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

      -- (james26)
      IF @cExtendedInfoSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +     
              ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
              ' @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, ' +
              ' @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
              ' @cLottable06, @cLottable07, @cLottable08, @dLottable09, @dLottable10, ' +
              ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
              ' @tExtInfo, @cExtendedInfo OUTPUT '         
         SET @cSQLParam =    
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cCCRefNo       NVARCHAR( 10), ' +
            ' @cCCSheetNo     NVARCHAR( 10), ' +
            ' @nCCCountNo     INT,           ' +
            ' @cZone1         NVARCHAR( 10), ' +
            ' @cZone2         NVARCHAR( 10), ' +
            ' @cZone3         NVARCHAR( 10), ' +
            ' @cZone4         NVARCHAR( 10), ' +
            ' @cZone5         NVARCHAR( 10), ' +
            ' @cAisle         NVARCHAR( 10), ' +
            ' @cLevel         NVARCHAR( 10), ' +
            ' @cLOC           NVARCHAR( 10), ' +
            ' @cID            NVARCHAR( 18), ' +
            ' @cUCC           NVARCHAR( 20), ' +
            ' @cSKU           NVARCHAR( 20), ' +
            ' @nQty           INT,           ' +
            ' @cLottable01    NVARCHAR( 18), ' +
            ' @cLottable02    NVARCHAR( 18), ' +
            ' @cLottable03    NVARCHAR( 18), ' +
            ' @dLottable04    DATETIME,      ' +
            ' @dLottable05    DATETIME,      ' +
            ' @cLottable06    NVARCHAR( 30), ' +
            ' @cLottable07    NVARCHAR( 30), ' +
            ' @cLottable08    NVARCHAR( 30), ' +
            ' @cLottable09    NVARCHAR( 30), ' +
            ' @cLottable10    NVARCHAR( 30), ' +
            ' @cLottable11    NVARCHAR( 30), ' +
            ' @cLottable12    NVARCHAR( 30), ' +
            ' @dLottable13    DATETIME, ' +
            ' @dLottable14    DATETIME, ' +
            ' @dLottable15    DATETIME, ' +
            ' @tExtInfo       VariableTable READONLY, ' +
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, 
            @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, 
            @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, 
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @tExtInfo, @cExtendedInfo OUTPUT 

         IF @cExtendedInfo <> ''
            SET @cOutField15 = @cExtendedInfo
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
--    Values ('rdtfnc_CycleCount_SKU_V7', GetDate(), '663 Scn4', '1', @cUserName, @cCCRefNo, @cCCSheetNo)
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

      -- (james26)
      IF @cExtendedInfoSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +     
              ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
              ' @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, ' +
              ' @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
              ' @cLottable06, @cLottable07, @cLottable08, @dLottable09, @dLottable10, ' +
              ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
              ' @tExtInfo, @cExtendedInfo OUTPUT '         
         SET @cSQLParam =    
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cCCRefNo       NVARCHAR( 10), ' +
            ' @cCCSheetNo     NVARCHAR( 10), ' +
            ' @nCCCountNo     INT,           ' +
            ' @cZone1         NVARCHAR( 10), ' +
            ' @cZone2         NVARCHAR( 10), ' +
            ' @cZone3         NVARCHAR( 10), ' +
            ' @cZone4         NVARCHAR( 10), ' +
            ' @cZone5         NVARCHAR( 10), ' +
            ' @cAisle         NVARCHAR( 10), ' +
            ' @cLevel         NVARCHAR( 10), ' +
            ' @cLOC           NVARCHAR( 10), ' +
            ' @cID            NVARCHAR( 18), ' +
            ' @cUCC           NVARCHAR( 20), ' +
            ' @cSKU           NVARCHAR( 20), ' +
            ' @nQty           INT,           ' +
            ' @cLottable01    NVARCHAR( 18), ' +
            ' @cLottable02    NVARCHAR( 18), ' +
            ' @cLottable03    NVARCHAR( 18), ' +
            ' @dLottable04    DATETIME,      ' +
            ' @dLottable05    DATETIME,      ' +
            ' @cLottable06    NVARCHAR( 30), ' +
            ' @cLottable07    NVARCHAR( 30), ' +
            ' @cLottable08    NVARCHAR( 30), ' +
            ' @cLottable09    NVARCHAR( 30), ' +
            ' @cLottable10    NVARCHAR( 30), ' +
            ' @cLottable11    NVARCHAR( 30), ' +
            ' @cLottable12    NVARCHAR( 30), ' +
            ' @dLottable13    DATETIME, ' +
            ' @dLottable14    DATETIME, ' +
            ' @dLottable15    DATETIME, ' +
            ' @tExtInfo       VariableTable READONLY, ' +
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, 
            @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, 
            @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, 
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @tExtInfo, @cExtendedInfo OUTPUT 

         IF @cExtendedInfo <> ''
            SET @cOutField15 = @cExtendedInfo
      END

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

      -- Check CC count type, must either be SKU or blank count (james10)
      IF @cCountType NOT IN ('SKU', 'BLK')
      BEGIN
         SET @nErrNo = 77708
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV COUNT TYPE'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO ID_Fail
      END

         -- (MaryVong01)
         SET @nCntQTY = 0
         SET @nCCDLinesPerLOCID = 0
         SET @cPrevCCDetailKey = ''

         -- Get Counted CCDet Lines for a particular LOC + ID
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

 -- Get Total CCDet Lines for a particular LOC + ID
         SELECT @nCCDLinesPerLOCID = COUNT(1)
         FROM dbo.CCDETAIL (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
         AND LOC = @cLOC
         --AND   ID = @cID
         AND ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END

         -- (MaryVong01)
         IF @cRecountFlag = 'Y'
            SET @nCntQTY = 0

         -- Get next record in current LOC and ID (if any)
         -- Initiate CCDetailKey to blank
         SET @cCCDetailKey = ''
         SET @nRecCnt = 0
         SET @cEmptyRecFlag = ''
         EXECUTE rdt.rdt_CycleCount_GetCCDetail_V7
            @cCCRefNo, @cCCSheetNo, @nCCCountNo,
            @cStorerKey       OUTPUT, -- Shong001
            @cLOC,
            @cID_In,
            @cWithQtyFlag, -- SOS79743
            @cCCDetailKey  OUTPUT,
            @cCountedFlag  OUTPUT,
            @cSKU          OUTPUT,
            @cLOT          OUTPUT,
            @cID           OUTPUT,
            @cLottableCode OUTPUT,
            @cLottable01   OUTPUT, @cLottable02   OUTPUT, @cLottable03   OUTPUT, @dLottable04   OUTPUT, @dLottable05   OUTPUT,
            @cLottable06   OUTPUT, @cLottable07   OUTPUT, @cLottable08   OUTPUT, @cLottable09   OUTPUT, @cLottable10   OUTPUT,
            @cLottable11   OUTPUT, @cLottable12   OUTPUT, @dLottable13   OUTPUT, @dLottable14   OUTPUT, @dLottable15   OUTPUT,
            @nCaseCnt      OUTPUT,
            @nCaseQTY      OUTPUT,
            @cCaseUOM      OUTPUT,
            @nEachQTY      OUTPUT,
            @cEachUOM      OUTPUT,
            @cSKUDescr     OUTPUT,
            @cPPK          OUTPUT,
            @nRecCnt       OUTPUT,
            @cEmptyRecFlag OUTPUT

         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 5, 9, 
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

         SET @cOutField08 = @cID -- SOS359218

         -- If not found any record
         -- It could be Empty LOC that allow to add new record
         IF @nRecCnt = 0 -- @cCCDetailKey = '' OR @cCCDetailKey IS NULL
         BEGIN
            SET @cID = @cID_In -- remain as key-in id for user insertion (SOS79743)

            -- Blank out var
            SET @cSKU = ''
            SET @cSKUDescr = ''
            SET @nCaseCnt = 0
            SET @nCaseQTY = 0
            SET @cCaseUOM = ''
            SET @nEachQTY = 0
            SET @cEachUOM = ''
            SET @cPPK = ''
            SET @cCountedFlag = '[ ]'
            SET @cLottable01 = ''
            SET @cLottable02 = ''
            SET @cLottable03 = ''
            SET @dLottable04 = NULL
            SET @dLottable05 = NULL
            SET @cLottable06 = ''
            SET @cLottable07 = ''
            SET @cLottable08 = ''
            SET @cLottable09 = ''
            SET @cLottable10 = ''
            SET @cLottable11 = ''
            SET @cLottable12 = ''
            SET @dLottable13 = NULL
            SET @dLottable14 = NULL
            SET @dLottable15 = NULL

            -- Clear all outfields
            SET @cOutField01 = ''   -- SKU
            SET @cOutField02 = ''   -- SKU DESCR1
            SET @cOutField03 = ''   -- SKU DESCR2
            SET @cOutField04 = ''   -- QTY (CS)
            SET @cOutField05 = ''   -- UOM (CS) + [C]
            SET @cOutField06 = ''   -- QTY (EA)
            SET @cOutField07 = ''   -- UOM (EA) + PPK
            SET @cOutField08 = @cID -- ID -- remain ID
            SET @cOutField09 = ''   -- Lottable01
            SET @cOutField10 = ''   -- Lottable02
            SET @cOutField11 = ''   -- Lottable03
            SET @cOutField12 = ''   -- Lottable04
            SET @cOutField13 = ''   -- Lottable05
            SET @cOutField14 = ''   -- Option
            SET @cOutField15 = ''   -- Counted CCDet Lines / Total CCDet Lines (for LOC+ID) -- (MaryVong01)

            -- (MaryVong01)
            -- Show message only, allow to proceed
         IF @cEmptyRecFlag = 'L'
            BEGIN
               SET @nErrNo = 62097
               SET @cErrMsg = rdt.rdtgetmessage( 62097, @cLangCode, 'DSP') -- 'LOC No Rec'
            END
            ELSE IF @cEmptyRecFlag = 'D'
            BEGIN
               SET @nErrNo = 62151
               SET @cErrMsg = rdt.rdtgetmessage( 62151, @cLangCode, 'DSP') -- 'ID No Rec'
            END
         END
         ELSE IF ISNULL(RTRIM(@cSKU),'') = '' -- SOS136921: Blank sku in CCDetail
              AND @cCountType <> 'BLK'        -- not blank count sheet (james10)
         BEGIN
            SET @cID = @cID_In -- remain as key-in id for user insertion (SOS79743)

            -- Blank out var
            SET @cSKU = ''
            SET @cSKUDescr = ''
            SET @nCaseCnt = 0
            SET @nCaseQTY = 0
            SET @cCaseUOM = ''
            SET @nEachQTY = 0
            SET @cEachUOM = ''
            SET @cPPK = ''
            SET @cCountedFlag = '[ ]'
            SET @cLottable01 = ''
            SET @cLottable02 = ''
            SET @cLottable03 = ''
            SET @dLottable04 = NULL
            SET @dLottable05 = NULL
            SET @cLottable06 = ''
            SET @cLottable07 = ''
            SET @cLottable08 = ''
            SET @cLottable09 = ''
            SET @cLottable10 = ''
            SET @cLottable11 = ''
            SET @cLottable12 = ''
            SET @dLottable13 = NULL
            SET @dLottable14 = NULL
            SET @dLottable15 = NULL

            -- Clear all outfields
            SET @cOutField01 = ''   -- SKU
            SET @cOutField02 = ''   -- SKU DESCR1
            SET @cOutField03 = ''   -- SKU DESCR2
            SET @cOutField04 = ''   -- QTY (CS)
            SET @cOutField05 = ''   -- UOM (CS) + [C]
            SET @cOutField06 = ''   -- QTY (EA)
            SET @cOutField07 = ''   -- UOM (EA) + PPK
            SET @cOutField08 = @cID -- ID -- remain ID
            SET @cOutField09 = ''   -- Lottable01
            SET @cOutField10 = ''   -- Lottable02
            SET @cOutField11 = ''   -- Lottable03
            SET @cOutField12 = ''   -- Lottable04
            SET @cOutField13 = ''   -- Lottable05
            SET @cOutField14 = ''   -- Option

            -- Show message only, allow to proceed
            SET @nErrNo = 62152
            SET @cErrMsg = rdt.rdtgetmessage( 62152, @cLangCode, 'DSP') -- 'Blank SKU'
         END
         -- If blind count then straight away goto blind count screen   -- (james10)
         ELSE
         BEGIN
            SET @cID = @cID_In

            -- Prepare SKU screen var
            SET @cOutField01 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cSKU END
            SET @cOutField02 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20) END
            IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorerKey) = '1'
            BEGIN
               SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
               SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16) END
            END
            ELSE
            BEGIN
               SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 40) END
            END

            SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey)

            -- If config turned on and skuconfig not setup then prompt error
            IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorerKey) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
            BEGIN
               SET @nErrNo = 66842
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
               EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
               GOTO ID_Fail
            END

            -- If SKUCONFIG setup
            IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
            BEGIN
              IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
                  JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
                  WHERE S.StorerKey = @cStorerKey
                  AND S.SKU = @cSKU
                  AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
               BEGIN
                  SET @nErrNo = 66844
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
                  EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
                  GOTO ID_Fail
               END

               SET @nQTY = 0
               -- Get Counted CCDet Lines for a particular LOC + ID
               SELECT @nQTY = CASE WHEN @nCCCountNo = 1 THEN
                                 CASE WHEN Counted_Cnt1 = 0 THEN
                                       CASE WHEN @cWithQtyFlag = 'Y' THEN QTY
                                       WHEN @cWithQtyFlag = 'N' THEN 0
                                       END
                                    WHEN Counted_Cnt1 = 1 THEN QTY
                                    END
                                 WHEN @nCCCountNo = 2 THEN QTY_Cnt2
                                 WHEN @nCCCountNo = 3 THEN QTY_Cnt3
                                 END
               FROM dbo.CCDETAIL (NOLOCK)
               WHERE CCDetailKey = @cCCDetailKey
/*
               WHERE CCKey = @cCCRefNo
               AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
               AND LOC = @cLOC
               AND ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
               AND Status < '9'
*/

---XXXXXXXXX
               SELECT @c_PackKey = P.PackKey
               FROM dbo.Pack P WITH (NOLOCK)
               JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
               WHERE S.StorerKey = @cStorerKey
                  AND S.SKU = @cSKU

               SELECT @b_success = 0
               EXEC nspUOMCONV
               @n_fromqty    = @nQTY,
               @c_fromuom    = @cEachUOM,
               @c_touom      = @cSKUDefaultUOM,
               @c_packkey    = @c_PackKey,
               @n_toqty      = @f_Qty        OUTPUT,
               @b_Success    = @b_Success    OUTPUT,
               @n_err        = @n_err        OUTPUT,
               @c_errmsg     = @c_errmsg     OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SET @nErrNo = 66843
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CONV FAIL'
                  EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
                  GOTO ID_Fail
               END

               IF LTRIM(RTRIM(@cEachUOM)) <> LTRIM(RTRIM(@cSKUDefaultUOM))
               BEGIN
                  SET @cOutField04 = CAST( @f_Qty AS NVARCHAR(10))
                  SET @cOutField05 = CAST(@cSKUDefaultUOM AS NVARCHAR(10)) + ' ' + @cCountedFlag
                  SET @cOutField06 = ''
                  SET @cOutField07 = ''
               END
               ELSE
               BEGIN
                  SET @cOutField04 = ''
                  SET @cOutField05 = CAST('' AS NVARCHAR(10)) + ' ' + @cCountedFlag
                  SET @cOutField06 = CAST( @f_Qty AS NVARCHAR(10))    -- QTY (EA)
                  SET @cOutField07 = @cEachUOM + @cPPK               -- UOM (EA) + PPK
               END
            END
            ELSE
            BEGIN
               IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorerKey) = 1
               BEGIN
                  SET @cOutField04 = CAST( 0 AS NVARCHAR(10))   -- QTY (CS) -- (Shong003)
                  SET @cOutField06 = CAST( 0 AS NVARCHAR(10))   -- QTY (EA) -- (Shong003)
               END
               ELSE
               BEGIN
                  SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(10))   -- QTY (CS) -- (ChewKP01)
                  SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP01)
               END

               SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS)
               SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
            END

            -- (james14)
            SET @cSKUCountDefaultOpt = ''
            SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorerKey)
            IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
               SET @cSKUCountDefaultOpt = ''

         -- SET @cOutField08 = @cID -- SOS359218
            SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14)
         -- SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
            SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                                    THEN RIGHT( SPACE(4) + CAST( @nCntQTY AS NVARCHAR( 4)), 4)
                                    ELSE CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4))
                                    END
         END

         -- Go to SKU (Main) screen
         SET @nScn  = @nScn_SKU
         SET @nStep = @nStep_SKU
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
Step_SKU. Scn = 672. Screen 10.
   SKU              (field01)           ID           (field08)
   SKU DESCR1       (field02)       LOTTABLE01      (field09)
   SKU DESCR2       (field03)           LOTTABLE02      (field10)
   QTY              (field04) - CS, [C] LOTTABLE03      (field11)
   UOM, CountedFlag (field05) - CS      LOTTABLE04      (field12)
   QTY              (field06) - EA      LOTTABLE05      (field13)
   UOM, PPK         (field07) - EA      OPTION          (field14) - Input field
                                        Cnt CCDLines/Total CCDLines (LOC+ID) (field15)
*************************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
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
      SET @cOptAction = @cInField14

      -- Retain the key-in value
      SET @cOutField14 = @cOptAction

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

      -- Option: 1=ADD 2=EDIT ENTER=NEXT

      -- Option: ENTER=NEXT (blank)
      -- Confirmed current record and get next record by CCDetailKey
      IF @cOptAction = '' OR @cOptAction IS NULL
      BEGIN
         IF @cCCDetailKey <> '' AND @cCCDetailKey IS NOT NULL
         BEGIN
            -- (james14)
            SET @cSKUCountDefaultOpt = ''
            SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorerKey)
            IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
               SET @cSKUCountDefaultOpt = ''

            IF @cSKUCountDefaultOpt <> ''
            BEGIN
               -- Convert QTY
               IF @nCaseCnt > 0
                  SET @nConvQTY = (@nCaseQTY * @nCaseCnt) + @nEachQTY
               ELSE
                  SET @nConvQTY = @nEachQTY

               IF @nConvQTY = 0
               AND EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                            WHERE CCDetailKey = @cCCDetailKey
                            AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '0' THEN 1
                                           WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '0' THEN 1
                                           WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '0' THEN 1 END)
               BEGIN/*
                  SET @nErrNo = 0
                  SET @cErrMsg1 = 'QTY COUNT IS 0.'
                  SET @cErrMsg2 = 'USE OPT 2 (EDT)'
                  SET @cErrMsg3 = 'TO CONFIRM COUNT.'
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
                  IF @nErrNo = 1
                  BEGIN
                     SET @cErrMsg1 = ''
                     SET @cErrMsg2 = ''
                     SET @cErrMsg3 = ''
                  END */
                  SET @nErrNo = 77720
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'QTY COUNTED=0'
                  SET @cOutField14 = @cSKUCountDefaultOpt
                  GOTO SKU_Fail
               END
            END

            SET @cCountedFlag = '[ ]'

            SELECT
               @cStorerKey = CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorerKey ELSE StorerKey END, -- Shong002
               @cStatus = Status,
               @cCountedFlag =
                  CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN '[C]'
                       WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN '[C]'
                       WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN '[C]'
                  ELSE '[ ]' END
            FROM dbo.CCDETAIL (NOLOCK)
            WHERE CCDetailKey = @cCCDetailKey

            -- Update at 1st time verification / not counted
            IF @cCountedFlag = '[ ]' OR @cStatus = '0' OR @cRecountFlag = 'Y' -- Allow to recount
            BEGIN
               -- Convert QTY
               IF @nCaseCnt > 0
                  SET @nConvQTY = (@nCaseQTY * @nCaseCnt) + @nEachQTY
               ELSE
                  SET @nConvQTY = @nEachQTY

               -- Confirmed current record
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
                  @nConvQTY,
                  @nErrNo       OUTPUT,
                  @cErrMsg      OUTPUT   -- screen limitation, 20 char max

               IF @nErrNo <> 0
                  GOTO SKU_Fail

               -- Set current record CountedFlag = [C]
               SET @cCountedFlag = '[C]'
               SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS) + [C]

               -- (MaryVong01)
               -- Increment Counted CCDet Lines by 1
               IF @cEditSKU = 'Y' and @cRecountFlag = 'Y'-- (Vicky03)
               BEGIN
                SET @nCntQTY = @nCntQTY
               END
               ELSE
               BEGIN
                SET @nCntQTY = @nCntQTY + 1
               END

               SET @cEditSKU = '' -- (Vicky03)
            END
         END

         -- Get next CCDetail
         SET @nRecCnt = 0
         SET @cEmptyRecFlag = ''
         EXECUTE rdt.rdt_CycleCount_GetCCDetail_V7
            @cCCRefNo, @cCCSheetNo, @nCCCountNo,
            @cStorerKey       OUTPUT,  -- Shong001
            @cLOC,
            @cID_In,
            @cWithQtyFlag, -- SOS79743
            @cCCDetailKey  OUTPUT,
            @cCountedFlag  OUTPUT,
            @cSKU          OUTPUT,
            @cLOT          OUTPUT,
            @cID           OUTPUT,
            @cLottableCode OUTPUT,
            @cLottable01   OUTPUT, @cLottable02   OUTPUT, @cLottable03   OUTPUT, @dLottable04   OUTPUT, @dLottable05   OUTPUT,
            @cLottable06   OUTPUT, @cLottable07   OUTPUT, @cLottable08   OUTPUT, @cLottable09   OUTPUT, @cLottable10   OUTPUT,
            @cLottable11   OUTPUT, @cLottable12   OUTPUT, @dLottable13   OUTPUT, @dLottable14   OUTPUT, @dLottable15   OUTPUT,
            @nCaseCnt      OUTPUT,
            @nCaseQTY      OUTPUT,
            @cCaseUOM      OUTPUT,
            @nEachQTY      OUTPUT,
            @cEachUOM      OUTPUT,
            @cSKUDescr     OUTPUT,
            @cPPK          OUTPUT,
            @nRecCnt       OUTPUT,
            @cEmptyRecFlag OUTPUT

         IF @nRecCnt = 0
         BEGIN
            -- Get StorerConfig 'AutoGotoIDLOCScnConfig'
            SET @cAutoGotoIDLOCScnConfig = rdt.RDTGetConfig( @nFunc, 'AutoGotoIDLOCScn', @cStorerKey)

            IF @cAutoGotoIDLOCScnConfig = '1' -- Turn On
            BEGIN

                -- (MaryVong01)
               IF @cEmptyRecFlag = 'L'
               BEGIN
                  -- Blank out var
                  SET @cSKU = ''
                  SET @cSKUDescr = ''
                  SET @nCaseCnt = 0
                  SET @nCaseQTY = 0
                  SET @cCaseUOM = ''
                  SET @nEachQTY = 0
                  SET @cEachUOM = ''
                  SET @cPPK = ''
                  SET @cCountedFlag = '[ ]'
                  SET @cLottable01 = ''
                  SET @cLottable02 = ''
                  SET @cLottable03 = ''
                  SET @dLottable04 = NULL
                  SET @dLottable05 = NULL
                  SET @cLottable06 = ''
                  SET @cLottable07 = ''
                  SET @cLottable08 = ''
                  SET @cLottable09 = ''
                  SET @cLottable10 = ''
                  SET @cLottable11 = ''
                  SET @cLottable12 = ''
                  SET @dLottable13 = NULL
                  SET @dLottable14 = NULL
                  SET @dLottable15 = NULL

                  -- Commented: No need to display message
                  -- Show message only, allow to proceed to LOC screen
                  --SET @nErrNo = 62116
                  --SET @cErrMsg = rdt.rdtgetmessage( 62116, @cLangCode, 'DSP') -- 'End of LOC Rec'

                  -- (Vicky03) - Start
                  SELECT TOP 1 @cZone1 = Zone1,
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

                  -- Get Next LOC
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

                  -- Get No. Of CCDetail Lines
                  SELECT @nCCDLinesPerLOC = COUNT(1)
                  FROM dbo.CCDETAIL WITH (NOLOCK)
                  WHERE CCKey = @cCCRefNo
                  AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                  AND   LOC = @cSuggestLOC

                  -- Go to LOC screen
                  -- Reset this screen var
                  SET @cOutField01 = @cCCRefNo
                  SET @cOutField02 = @cCCSheetNo
                  SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
                  SET @cOutField04 = @cSuggestLOC
                  SET @cOutField05 = ''          -- key-in LOC
                  SET @cOutField06 = CAST( @nCCDLinesPerLOC AS NVARCHAR(5))
                  SET @cOutField07 = ''          -- UOM (EA) + PPK
                  SET @cOutField08 = ''          -- ID
                  SET @cOutField09 = ''          -- Lottable01
                  SET @cOutField10 = ''          -- Lottable02
                  SET @cOutField11 = ''          -- Lottable03
                  SET @cOutField12 = ''          -- Lottable04
                  SET @cOutField13 = ''          -- Lottable05
                  SET @cOutField14 = ''          -- Option
                  SET @cOutField15 = ''          -- Counted CCDet Lines / Total CCDet Lines (for LOC+ID)

                  -- Go to LOC screen
                  SET @nScn  = @nScn_LOC
                  SET @nStep = @nStep_LOC
               END
               ELSE IF @cEmptyRecFlag = 'D'
               BEGIN
                  -- Reset this screen var
                  SET @cOutField01 = @cCCRefNo
                  SET @cOutField02 = @cCCSheetNo
                  SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
                  SET @cOutField04 = @cSuggestLOC
                  SET @cOutField05 = @cLOC
                  SET @cOutField06 = ''   -- UOM (EA) + PPK

                  -- (james12)
                  SET @nNoOfTry = 0

                  -- Go to ID screen
                  SET @nScn  = @nScn_ID
                  SET @nStep = @nStep_ID
               END

               GOTO Quit
            END -- End of Turn on 'AutoGotoIDLOCScn' configkey
         END
         ELSE IF ISNULL(RTRIM(@cSKU),'') = '' -- SOS#136921: Blank sku in CCDetail
         BEGIN
            -- Blank out var
            SET @cSKU = ''
            SET @cSKUDescr = ''
            SET @nCaseCnt = 0
            SET @nCaseQTY = 0
            SET @cCaseUOM = ''
            SET @nEachQTY = 0
            SET @cEachUOM = ''
            SET @cPPK = ''
            SET @cCountedFlag = '[ ]'
            SET @cLottable01 = ''
            SET @cLottable02 = ''
            SET @cLottable03 = ''
            SET @dLottable04 = NULL
            SET @dLottable05 = NULL
            SET @cLottable06 = ''
            SET @cLottable07 = ''
            SET @cLottable08 = ''
            SET @cLottable09 = ''
            SET @cLottable10 = ''
            SET @cLottable11 = ''
            SET @cLottable12 = ''
            SET @dLottable13 = NULL
            SET @dLottable14 = NULL
            SET @dLottable15 = NULL

            -- Clear all outfields
            SET @cOutField01 = ''   -- SKU
            SET @cOutField02 = ''   -- SKU DESCR1
            SET @cOutField03 = ''   -- SKU DESCR2
            SET @cOutField04 = ''   -- QTY (CS)
            SET @cOutField05 = ''   -- UOM (CS) + [C]
            SET @cOutField06 = ''   -- QTY (EA)
            SET @cOutField07 = ''   -- UOM (EA) + PPK
            SET @cOutField08 = ''   -- ID
            SET @cOutField09 = ''   -- Lottable01
            SET @cOutField10 = ''   -- Lottable02
            SET @cOutField11 = ''   -- Lottable03
            SET @cOutField12 = ''   -- Lottable04
            SET @cOutField13 = ''   -- Lottable05
            SET @cOutField14 = ''   -- Option

            -- Show message only, allow to proceed
            SET @nErrNo = 62155
            SET @cErrMsg = rdt.rdtgetmessage( 62155, @cLangCode, 'DSP') -- 'Blank SKU'
            GOTO Quit
         END

         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 6, 9, 
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
            

         -- Prepare current screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
         IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorerKey) = '1'
         BEGIN
            SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
            SET @cOutField03 = 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16)
         END
         ELSE
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
--         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)

         -- (ChewKP02)
         IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorerKey) = 1
         BEGIN
            SET @cOutField04 = CAST( 0 AS NVARCHAR(10))   -- QTY (CS) -- (ChewKP02)
            SET @cOutField06 = CAST( 0 AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP02)
            SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS) + [C]
            SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
            SET @cOutField08 = @cID -- SOS359218
         END
         ELSE
         BEGIN
            SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR( 10))   -- QTY (CS) -- (ChewKP01)
            SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS) + [C]
            SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR( 10))   -- QTY (EA) -- (ChewKP01)
            SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
            SET @cOutField08 = @cID -- SOS359218
         END

         -- (james14)
         SET @cSKUCountDefaultOpt = ''
         SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorerKey)
         IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
            SET @cSKUCountDefaultOpt = ''

         SET @cOutField08 = @cID
         --SET @cOutField09 = @cLottable01
         --SET @cOutField10 = @cLottable02
         --SET @cOutField11 = @cLottable03
         --SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
         --SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
         SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END  -- Option    (james14)
--       SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
         SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                                 THEN RIGHT( SPACE(4) + CAST( @nCntQTY AS NVARCHAR( 4)), 4)
                                 ELSE CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4))
                                 END

      END

      -- Option: 1=ADD 2=EDIT
      IF @cOptAction <> '' AND @cOptAction IS NOT NULL
      BEGIN
         IF @cOptAction <> '1' AND @cOptAction <> '2'
         BEGIN
            SET @nErrNo = 62117
            SET @cErrMsg = rdt.rdtgetmessage( 62117, @cLangCode, 'DSP') -- 'Invalid Option'
            GOTO SKU_Fail
         END

         -- 1=ADD
         IF @cOptAction = '1'
         BEGIN
            -- Blank out SKU (ADD) Screen
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cID
            SET @cOutField03 = ''   -- SKU
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

            EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU/UPC

            -- Go to next screen
            SET @nScn  = @nScn_SKU_Add_Sku
            SET @nStep = @nStep_SKU_Add_Sku
         END

         -- 2=EDIT
         IF @cOptAction = '2'
         BEGIN
            -- Check if SKU is blank => cannot edit
            IF @cSKU = '' OR @cSKU IS NULL
            BEGIN
               SET @nErrNo = 62118
               SET @cErrMsg = rdt.rdtgetmessage( 62118, @cLangCode, 'DSP') -- 'Blank record'
               EXEC rdt.rdtSetFocusField @nMobile, 12
               GOTO SKU_Fail
            END

            -- Check if setup to have fields to validate(james15)
            IF EXISTS ( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK)
                        WHERE ListName = 'CCVALFIELD'
                        AND   StorerKey = @cStorerKey
                        AND   Code IN ('SKU', 'LOTTABLE01', 'LOTTABLE02', 'LOTTABLE03', 'LOTTABLE04')
                        AND   Short = '1')
            BEGIN
               SELECT @nValidateSKU = CASE WHEN Short = '1' THEN 1 ELSE 0 END
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'CCVALFIELD'
               AND   StorerKey = @cStorerKey
               AND   Code = 'SKU'

               SELECT @nValidateLot01 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'CCVALFIELD'
               AND   StorerKey = @cStorerKey
               AND   Code = 'LOTTABLE01'

               SELECT @nValidateLot02 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'CCVALFIELD'
               AND   StorerKey = @cStorerKey
               AND   Code = 'LOTTABLE02'

               SELECT @nValidateLot03 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'CCVALFIELD'
               AND   StorerKey = @cStorerKey
               AND   Code = 'LOTTABLE03'

               SELECT @nValidateLot04 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'CCVALFIELD'
               AND   StorerKey = @cStorerKey
               AND   Code = 'LOTTABLE04'

               SET @cOutField01 = @cLOC
               SET @cOutField02 = @cSKU
               SET @cOutField03 = ''
               SET @cOutField04 = @cLottable01
               SET @cOutField05 = ''
               SET @cOutField06 = @cLottable02
               SET @cOutField07 = ''
               SET @cOutField08 = @cLottable03
               SET @cOutField09 = ''
               SET @cOutField10 = rdt.rdtFormatDate( @dLottable04)
               SET @cOutField11 = ''

               -- Enable/Disable field
               SET @cFieldAttr03 = CASE WHEN @nValidateSKU = 1 THEN '' ELSE 'O' END
               SET @cFieldAttr05 = CASE WHEN @nValidateLot01 = 1 THEN '' ELSE 'O' END
               SET @cFieldAttr07 = CASE WHEN @nValidateLot02 = 1 THEN '' ELSE 'O' END
               SET @cFieldAttr09 = CASE WHEN @nValidateLot03 = 1 THEN '' ELSE 'O' END
               SET @cFieldAttr11 = CASE WHEN @nValidateLot04 = 1 THEN '' ELSE 'O' END

               -- Go to validate sku lottables screen
               SET @nScn  = 3264--@nScn_Validate_SKULottables
               SET @nStep = 29--@nStep_Validate_SKULottables

               GOTO Quit
            END

            IF @nCaseCnt > 0
               EXEC rdt.rdtSetFocusField @nMobile, 4   -- QTY (CS)
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (EA)

            -- If Qty = 0, set to blank
            -- To do this to avoid user need to remove zero from handheld scanner
            IF @nCaseQTY = 0
               SET @cCaseQty = ''
            ELSE
               SET @cCaseQty = CAST( @nCaseQTY AS NVARCHAR( 10)) -- (ChewKP01)

            IF @nEachQTY = 0
               SET @cEachQty = ''
            ELSE
               SET @cEachQty = CAST( @nEachQTY AS NVARCHAR( 10)) -- (ChewKP01)

            -- Prepare SKU (EDIT) screen var
            SET @cOutField01 = @cSKU
            SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
            IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorerKey) = '1'
            BEGIN
               SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
               SET @cOutField03 = 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16)
            END
            ELSE
            BEGIN
               SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
            END

            SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey)

            -- If config turned on and skuconfig not setup then prompt error
            IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorerKey) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
            BEGIN
               SET @nErrNo = 66842
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
               EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
               GOTO ID_Fail
            END

            -- If SKUCONFIG setup
            IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
           JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
                  WHERE S.StorerKey = @cStorerKey
                  AND S.SKU = @cSKU
                  AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
               BEGIN
                  SET @nErrNo = 66844
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
                  EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
                  GOTO ID_Fail
               END

               SET @nQTY = 0
               -- Get Counted CCDet Lines for a particular LOC + ID
               -- Add top 1 to cater for 1 loc, same sku, diff lot   (james20)
               SELECT TOP 1 @nQTY = CASE WHEN @nCCCountNo = 1 THEN
                                    CASE WHEN Counted_Cnt1 = 0 THEN
                                       CASE WHEN @cWithQtyFlag = 'Y' THEN QTY
                                       WHEN @cWithQtyFlag = 'N' THEN 0
                                       END
                                    WHEN Counted_Cnt1 = 1 THEN QTY
               END
                                 WHEN @nCCCountNo = 2 THEN QTY_Cnt2
                                 WHEN @nCCCountNo = 3 THEN QTY_Cnt3
                                 END
               FROM dbo.CCDETAIL (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
               AND LOC = @cLOC
               AND ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
               AND Status < '9'
               ORDER BY [Status], CCDETAILKEY   -- order by record not counted then 1st come 1st serve (james20)

               SELECT @c_PackKey = P.PackKey, @cLottableCode = S.LottableCode
               FROM dbo.Pack P WITH (NOLOCK)
               JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
               WHERE S.StorerKey = @cStorerKey
                  AND S.SKU = @cSKU

               SELECT @b_success = 0
               EXEC nspUOMCONV
               @n_fromqty    = @nQTY,
               @c_fromuom    = @cEachUOM,
               @c_touom      = @cSKUDefaultUOM,
               @c_packkey    = @c_PackKey,
               @n_toqty      = @f_Qty        OUTPUT,
               @b_Success    = @b_Success    OUTPUT,
               @n_err        = @n_err        OUTPUT,
               @c_errmsg     = @c_errmsg     OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SET @nErrNo = 66843
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CONV FAIL'
                  EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
                  GOTO ID_Fail
               END

               IF LTRIM(RTRIM(@cEachUOM)) <> LTRIM(RTRIM(@cSKUDefaultUOM))
               BEGIN
                  -- (ChewKP02)
                  IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorerKey) = 1
                  BEGIN
                     SET @cOutField04 = CAST( 0 AS NVARCHAR(10))   -- QTY (CS) -- (ChewKP02)
                  END
                  ELSE
                  BEGIN
                     SET @cOutField04 = CAST( @f_Qty AS NVARCHAR(10))
                  END


                  SET @cOutField05 = CAST(@cSKUDefaultUOM AS NVARCHAR(10)) + ' ' + @cCountedFlag
                  SET @cOutField06 = ''
                  SET @cOutField07 = ''
                  SET @cFieldAttr06 = 'O'
                  SET @cFieldAttr07 = 'O'
               END
               ELSE
               BEGIN
                  -- (ChewKP02)
                  IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorerKey) = 1
                  BEGIN
                     SET @cOutField06 = CAST( 0 AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP02)
                  END
                  ELSE
                  BEGIN
                     SET @cOutField06 = @f_Qty   -- QTY (EA)
                  END

                  SET @cOutField04 = ''
                  SET @cOutField05 = CAST('' AS NVARCHAR(10)) + ' ' + @cCountedFlag

                  SET @cOutField07 = @cEachUOM + @cPPK          -- UOM (EA) + PPK
                  SET @cFieldAttr04 = 'O'
                  SET @cFieldAttr05 = 'O'
               END
            END
            ELSE
            BEGIN
               -- (ChewKP02)
               IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorerKey) = 1
               BEGIN
                  SET @cOutField04 = CAST( 0 AS NVARCHAR(10))   -- QTY (CS) -- (ChewKP02)
                  SET @cOutField06 = CAST( 0 AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP02)
               END
               ELSE
               BEGIN
                  SET @cOutField04 = @cCaseQTY                        -- QTY (CS)
                  SET @cOutField06 = @cEachQty                        -- QTY (EA)
               END

               SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag  -- UOM (CS) + [C]
               SET @cOutField07 = @cEachUOM + @cPPK          -- UOM (EA) + PPK
            END
            SET @cOutField08 = ''

            -- Dynamic lottable
            EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 6, 9, 
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
            SET @nScn  = @nScn_SKU_Edit_Qty
            SET @nStep = @nStep_SKU_Edit_Qty
         END
      END
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

      -- Re-initialize
      SET @cPrevCCDetailKey = ''

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
            0,               -- empty loc
            @nErrNo       OUTPUT,
            @cErrMsg      OUTPUT    -- screen limitation, 20 char max

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
      WHERE Mobile = @nMobile
      AND   CCKey = @cCCRefNo
      AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN SheetNo ELSE @cCCSheetNo END
      AND   CountNo = @nCCCountNo
      AND   AddWho = @cUserName
      AND   Status = '1'
      AND   Loc = @cLOC
      AND   Id = @cID

      -- Set back values
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = '' -- ID
      SET @cOutField07 = '' 
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
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

      EXEC rdt.rdtSetFocusField @nMobile, 6 -- ID

      -- (james12)
      SET @nNoOfTry = 0

      -- Go to OPT & ID screen
      SET @nScn  = @nScn_ID
      SET @nStep = @nStep_ID
   END
   GOTO Quit

   SKU_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField13 = '' -- Option
   END
END
GOTO Quit

/************************************************************************************
Step_SKU_Add_Sku. Scn = 673. Screen 11.
   LOC         (field01)
   ID          (field02)
   SKU/UPC     (field03) - Input field
*************************************************************************************/
Step_SKU_Add_Sku:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN          -- Screen mapping
      SET @cNewSKU = @cInField03
      SET @cLabel2Decode = @cInField03 -- (james18)

      -- Retain the key-in value
      SET @cOutField03 = @cNewSKU

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

      -- SHONG001 (Start)
      DECLARE @t_Storer TABLE(StorerKey NVARCHAR(15))

      INSERT INTO @t_Storer (StorerKey)
      SELECT Distinct StorerKey
      FROM   CCDETAIL WITH (NOLOCK)
      WHERE  CCKey = @cCCRefNo
      AND    StorerKey <> ''

      -- Validate blank SKU
      IF @cNewSKU = '' OR @cNewSKU IS NULL
      BEGIN
         SET @nErrNo = 62119
         SET @cErrMsg = rdt.rdtgetmessage( 62119, @cLangCode, 'DSP') -- 'SKU/UPC req'
         GOTO SKU_Add_Sku_Fail
      END

      -- Validate SKU
      -- Check if SKU, alt sku, manufacturer sku, upc belong to the storer
      SET @b_success = 0
      IF (SELECT COUNT(*) FROM @t_Storer) > 1
      BEGIN
         SET @cCheckStorer = ''

         DECLARE CUR_CheckSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT StorerKey
           FROM   @t_Storer

         OPEN  CUR_CheckSKU
         FETCH NEXT FROM CUR_CheckSKU INTO @cCheckStorer
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @cDecodeLabelNo = ''
            SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cCheckStorer)

            IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   --SOS320895
            BEGIN
               EXEC dbo.ispLabelNo_Decoding_Wrapper
                @c_SPName     = @cDecodeLabelNo
               ,@c_LabelNo    = @cLabel2Decode
               ,@c_Storerkey  = @cCheckStorer
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
                  GOTO SKU_Add_Sku_Fail
               END

               SET @cNewSKU = @c_oFieled01
            END

            -- (james21)
            SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cCheckStorer)
            IF @cDecodeSP = '0'
               SET @cDecodeSP = ''

            IF @cDecodeSP <> ''
            BEGIN
               SET @cBarcode = @cInField03
               SET @cUPC = ''

               -- Standard decode
               IF @cDecodeSP = '1'
               BEGIN
                  EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCheckStorer, @cFacility, @cBarcode,
                     @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                     @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                     @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                     @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                     @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
                     @nErrNo        OUTPUT, @cErrMsg        OUTPUT

                  IF ISNULL( @cUPC, '') <> ''
                     SET @cNewSKU = @cUPC
               END

               -- Customize decode
               ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCCRefNo, @cCCSheetNo, @cBarcode, ' +
                     ' @cLOC           OUTPUT, @cID            OUTPUT, @cUCC           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT, ' +
                     ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT, ' +
                     ' @cLottable06    OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT, ' +
                     ' @cLottable11    OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
                     ' @cUserDefine01  OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, ' +
                     ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
                  SET @cSQLParam =
                     ' @nMobile        INT,           ' +
                     ' @nFunc          INT,           ' +
                     ' @cLangCode      NVARCHAR( 3),  ' +
                     ' @nStep          INT,           ' +
                     ' @nInputKey      INT,           ' +
                     ' @cStorerKey     NVARCHAR( 15), ' +
                     ' @cCCRefNo       NVARCHAR( 10), ' +
                     ' @cCCSheetNo     NVARCHAR( 10), ' +
                     ' @cBarcode       NVARCHAR( 60), ' +
                     ' @cLOC           NVARCHAR( 10)  OUTPUT, ' +
                     ' @cID            NVARCHAR( 18)  OUTPUT, ' +
                     ' @cUCC           NVARCHAR( 20)  OUTPUT, ' +
                     ' @cUPC           NVARCHAR( 20)  OUTPUT, ' +
                     ' @nQTY           INT            OUTPUT, ' +
                     ' @cLottable01    NVARCHAR( 18)  OUTPUT, ' +
                     ' @cLottable02    NVARCHAR( 18)  OUTPUT, ' +
                     ' @cLottable03    NVARCHAR( 18)  OUTPUT, ' +
                     ' @dLottable04    DATETIME       OUTPUT, ' +
                     ' @dLottable05    DATETIME       OUTPUT, ' +
                     ' @cLottable06    NVARCHAR( 30)  OUTPUT, ' +
                     ' @cLottable07    NVARCHAR( 30)  OUTPUT, ' +
                     ' @cLottable08    NVARCHAR( 30)  OUTPUT, ' +
                     ' @cLottable09    NVARCHAR( 30)  OUTPUT, ' +
                     ' @cLottable10    NVARCHAR( 30)  OUTPUT, ' +
                     ' @cLottable11    NVARCHAR( 30)  OUTPUT, ' +
                     ' @cLottable12    NVARCHAR( 30)  OUTPUT, ' +
                     ' @dLottable13    DATETIME       OUTPUT, ' +
                     ' @dLottable14    DATETIME       OUTPUT, ' +
                     ' @dLottable15    DATETIME       OUTPUT, ' +
                     ' @cUserDefine01  NVARCHAR( 60)  OUTPUT, ' +
                     ' @cUserDefine02  NVARCHAR( 60)  OUTPUT, ' +
                     ' @cUserDefine03  NVARCHAR( 60)  OUTPUT, ' +
                     ' @cUserDefine04  NVARCHAR( 60)  OUTPUT, ' +
                     ' @cUserDefine05  NVARCHAR( 60)  OUTPUT, ' +
                     ' @nErrNo         INT            OUTPUT, ' +
                     ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCheckStorer, @cCCRefNo, @cCCSheetNo, @cBarcode,
                     @cLOC          OUTPUT, @cID            OUTPUT, @cUCC           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                     @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                     @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                     @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                     @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
                     @nErrNo        OUTPUT, @cErrMsg        OUTPUT

                  IF ISNULL( @cUPC, '') <> ''
                     SET @cNewSKU = @cUPC
               END
            END   -- End for DecodeSP

            EXEC dbo.nspg_GETSKU @cCheckStorer, @cNewSKU OUTPUT, @b_success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @b_success = 1
            BEGIN
               SET @cStorerKey = @cCheckStorer
               BREAK
            END

            FETCH NEXT FROM CUR_CheckSKU INTO @cCheckStorer
         END
         IF @b_success = 0
         BEGIN
            SET @nErrNo = 62120
            SET @cErrMsg = rdt.rdtgetmessage( 62120, @cLangCode, 'DSP') -- 'Invalid SKU'
            GOTO SKU_Add_Sku_Fail
         END
         CLOSE CUR_CheckSKU
         DEALLOCATE CUR_CheckSKU
      END
      ELSE
      BEGIN
         SET @cDecodeLabelNo = ''
         SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)

         IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   --SOS320895
         BEGIN
            EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cLabel2Decode
            ,@c_Storerkey  = @cStorerKey
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
               GOTO SKU_Add_Sku_Fail
            END

            SET @cNewSKU = @c_oFieled01
         END

         -- (james21)
         SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
         IF @cDecodeSP = '0'
            SET @cDecodeSP = ''

         IF @cDecodeSP <> ''
         BEGIN
            SET @cBarcode = @cInField03
            SET @cUPC = ''

            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                  @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                  @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                  @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                  @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
                  @nErrNo        OUTPUT, @cErrMsg        OUTPUT

               IF ISNULL( @cUPC, '') <> ''
                  SET @cNewSKU = @cUPC
            END

            -- Customize decode
            ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cCCRefNo, @cCCSheetNo, ' +
                  ' @cLOC           OUTPUT, @cID            OUTPUT, @cUCC           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT, ' +
                  ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT, ' +
                  ' @cLottable06    OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT, ' +
                  ' @cLottable11    OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
                  ' @cUserDefine01  OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, ' +
                  ' @nErrNo      OUTPUT, @cErrMsg  OUTPUT'
               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @cBarcode       NVARCHAR( 60), ' +
                  ' @cCCRefNo       NVARCHAR( 10), ' +
                  ' @cCCSheetNo     NVARCHAR( 10), ' +
                  ' @cLOC           NVARCHAR( 10)  OUTPUT, ' +
                  ' @cID            NVARCHAR( 18)  OUTPUT, ' +
                  ' @cUCC           NVARCHAR( 20)  OUTPUT, ' +
                  ' @cUPC           NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY           INT            OUTPUT, ' +
                  ' @cLottable01    NVARCHAR( 18)  OUTPUT, ' +
                  ' @cLottable02    NVARCHAR( 18)  OUTPUT, ' +
                  ' @cLottable03    NVARCHAR( 18)  OUTPUT, ' +
                  ' @dLottable04    DATETIME       OUTPUT, ' +
                  ' @dLottable05    DATETIME       OUTPUT, ' +
                  ' @cLottable06    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable07    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable08    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable09    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable10    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable11    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable12    NVARCHAR( 30)  OUTPUT, ' +
                  ' @dLottable13    DATETIME       OUTPUT, ' +
                  ' @dLottable14    DATETIME       OUTPUT, ' +
                  ' @dLottable15    DATETIME       OUTPUT, ' +
                  ' @cUserDefine01  NVARCHAR( 60)  OUTPUT, ' +
                  ' @cUserDefine02  NVARCHAR( 60)  OUTPUT, ' +
                  ' @cUserDefine03  NVARCHAR( 60)  OUTPUT, ' +
                  ' @cUserDefine04  NVARCHAR( 60)  OUTPUT, ' +
                  ' @cUserDefine05  NVARCHAR( 60)  OUTPUT, ' +
                  ' @nErrNo         INT            OUTPUT, ' +
                  ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cCCRefNo, @cCCSheetNo,
                  @cLOC          OUTPUT, @cID            OUTPUT, @cUCC           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                  @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                  @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                  @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                  @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
                  @nErrNo        OUTPUT, @cErrMsg        OUTPUT

               IF ISNULL( @cUPC, '') <> ''
                  SET @cNewSKU = @cUPC
            END
         END   -- End for DecodeSP

         SET @b_success = 0
         EXEC dbo.nspg_GETSKU @cStorerKey, @cNewSKU OUTPUT, @b_success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @b_success = 0
         BEGIN
            SET @nErrNo = 62120
            SET @cErrMsg = rdt.rdtgetmessage( 62120, @cLangCode, 'DSP') -- 'Invalid SKU'
            GOTO SKU_Add_Sku_Fail
         END
      END
      -- SHONG001 (End)

/*    -- (james19)
      SELECT TOP 1
         @cNewSKUDescr = SKU.DESCR,
         @nNewCaseCnt  = PAC.CaseCnt,
         @cNewCaseUOM  = CASE WHEN PAC.CaseCnt > 0
                           THEN SUBSTRING( PAC.PACKUOM1, 1, 3)
                         ELSE '' END,
         @cNewEachUOM  = SUBSTRING( PAC.PACKUOM3, 1, 3),
         @cNewPPK      = CASE WHEN SKU.PrePackIndicator = '2'
                           THEN 'PPK:' + CAST( SKU.PackQtyIndicator AS NVARCHAR( 2))
                         ELSE '' END
      FROM dbo.SKU SKU (NOLOCK)
      INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cNewSKU
*/

  SELECT TOP 1
         @cNewSKUDescr = SKU.DESCR,
         @nNewCaseCnt  = PAC.CaseCnt,
         @cNewCaseUOM  = CASE WHEN PAC.CaseCnt > 0
                           THEN PAC.PACKUOM1
                         ELSE '' END,
         @cNewEachUOM  = PAC.PACKUOM3,
         @cNewPPK      = CASE WHEN SKU.PrePackIndicator = '2'
                           THEN 'PPK:' + CAST( SKU.PackQtyIndicator AS NVARCHAR( 2))
                         ELSE '' END
      FROM dbo.SKU SKU (NOLOCK)
      INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cNewSKU

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62121
         SET @cErrMsg = rdt.rdtgetmessage( 62121, @cLangCode, 'DSP') -- 'SKU Not Found'
         GOTO SKU_Add_Sku_Fail
      END

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cNewSKU, 'RDTDefaultUOM', @cStorerKey)

      -- Set cursor
      IF @nNewCaseCnt > 0
         EXEC rdt.rdtSetFocusField @nMobile, 4   -- QTY (CS)
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (EA)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorerKey) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
      BEGIN
         SET @nErrNo = 66842
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO SKU_Add_Sku_Fail
      END

      -- If SKUCONFIG setup
      IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
        JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
            WHERE S.StorerKey = @cStorerKey
            AND S.SKU = @cNewSKU
            AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
         BEGIN
            SET @nErrNo = 66844
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO SKU_Add_Sku_Fail
         END

         IF LTRIM(RTRIM(@cNewEachUOM)) <> LTRIM(RTRIM(@cSKUDefaultUOM))
         BEGIN
            SET @cOutField06 = ''
            SET @cOutField07 = @cSKUDefaultUOM
            SET @cOutField08 = ''
            SET @cOutField09 = ''
            SET @cFieldAttr08 = 'O'
            SET @cFieldAttr09 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = @cSKUDefaultUOM + ' ' + @cNewPPK   -- UOM (EA) + PPK
            SET @cFieldAttr06 = 'O'
            SET @cFieldAttr07 = 'O'
         END
      END
      ELSE
      BEGIN
         SET @cNewSKUDescr1 = SUBSTRING( @cNewSKUDescr, 1, 20)
         SET @cNewSKUDescr2 = SUBSTRING( @cNewSKUDescr, 21, 40)

          -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID
         SET @cOutField03 = @cNewSKU
         SET @cOutField04 = @cNewSKUDescr1
         SET @cOutField05 = @cNewSKUDescr2
         SET @cOutField06 = ''                            -- QTY (CS)
         SET @cOutField07 = @cNewCaseUOM                  -- UOM (CS)
         SET @cOutField08 = ''      -- QTY (EA)
         SET @cOutField09 = @cNewEachUOM + ' ' + @cNewPPK -- UOM (EA) + PPK
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField12 = ''
      END

      SET @cSKU = @cNewSKU -- (james10)

      -- (james26)
      IF @cExtendedInfoSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +     
              ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
              ' @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, ' +
              ' @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
              ' @cLottable06, @cLottable07, @cLottable08, @dLottable09, @dLottable10, ' +
              ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
              ' @tExtInfo, @cExtendedInfo OUTPUT '         
         SET @cSQLParam =    
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cCCRefNo       NVARCHAR( 10), ' +
            ' @cCCSheetNo     NVARCHAR( 10), ' +
            ' @nCCCountNo     INT,           ' +
            ' @cZone1         NVARCHAR( 10), ' +
            ' @cZone2         NVARCHAR( 10), ' +
            ' @cZone3         NVARCHAR( 10), ' +
            ' @cZone4         NVARCHAR( 10), ' +
            ' @cZone5         NVARCHAR( 10), ' +
            ' @cAisle         NVARCHAR( 10), ' +
            ' @cLevel         NVARCHAR( 10), ' +
            ' @cLOC           NVARCHAR( 10), ' +
            ' @cID            NVARCHAR( 18), ' +
            ' @cUCC           NVARCHAR( 20), ' +
            ' @cSKU           NVARCHAR( 20), ' +
            ' @nQty           INT,           ' +
            ' @cLottable01    NVARCHAR( 18), ' +
            ' @cLottable02    NVARCHAR( 18), ' +
            ' @cLottable03    NVARCHAR( 18), ' +
            ' @dLottable04    DATETIME,      ' +
            ' @dLottable05    DATETIME,      ' +
            ' @cLottable06    NVARCHAR( 30), ' +
            ' @cLottable07    NVARCHAR( 30), ' +
            ' @cLottable08    NVARCHAR( 30), ' +
            ' @cLottable09    NVARCHAR( 30), ' +
            ' @cLottable10    NVARCHAR( 30), ' +
            ' @cLottable11    NVARCHAR( 30), ' +
            ' @cLottable12    NVARCHAR( 30), ' +
            ' @dLottable13    DATETIME, ' +
            ' @dLottable14    DATETIME, ' +
            ' @dLottable15    DATETIME, ' +
            ' @tExtInfo       VariableTable READONLY, ' +
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, 
            @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, 
            @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, 
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @tExtInfo, @cExtendedInfo OUTPUT 

         IF @cExtendedInfo <> ''
            SET @cOutField15 = @cExtendedInfo
      END
      
      -- Go to next screen
      SET @nScn  = @nScn_SKU_Add_Qty
      SET @nStep = @nStep_SKU_Add_Qty
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
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

      -- Prepare previous screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
      IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorerKey) = '1'
      BEGIN
         SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
         SET @cOutField03 = 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16)
      END
      ELSE
      BEGIN
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
      END

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorerKey) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
      BEGIN
         SET @nErrNo = 66842
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO ID_Fail
      END

      -- If SKUCONFIG setup
      IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
            JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
            WHERE S.StorerKey = @cStorerKey
            AND S.SKU = @cSKU
            AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
         BEGIN
            SET @nErrNo = 66844
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END

         SET @nQTY = 0
         -- Get Counted CCDet Lines for a particular LOC + ID
         SELECT @nQTY = CASE WHEN @nCCCountNo = 1 THEN
                              CASE WHEN Counted_Cnt1 = 0 THEN
                                 CASE WHEN @cWithQtyFlag = 'Y' THEN QTY
                                 WHEN @cWithQtyFlag = 'N' THEN 0
                                 END
                              WHEN Counted_Cnt1 = 1 THEN QTY
                              END
                           WHEN @nCCCountNo = 2 THEN QTY_Cnt2
                           WHEN @nCCCountNo = 3 THEN QTY_Cnt3
                           END
         FROM dbo.CCDETAIL (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
         AND LOC = @cLOC
         AND ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
         AND Status < '9'

         SELECT @c_PackKey = P.PackKey FROM dbo.Pack P WITH (NOLOCK)
         JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
         WHERE S.StorerKey = @cStorerKey
            AND S.SKU = @cSKU

         SELECT @b_success = 0
         EXEC nspUOMCONV
         @n_fromqty    = @nQTY,
         @c_fromuom    = @cEachUOM,
         @c_touom      = @cSKUDefaultUOM,
         @c_packkey    = @c_PackKey,
         @n_toqty      = @f_Qty        OUTPUT,
         @b_Success    = @b_Success    OUTPUT,
         @n_err        = @n_err        OUTPUT,
         @c_errmsg     = @c_errmsg     OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SET @nErrNo = 66843
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CONV FAIL'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END

         IF LTRIM(RTRIM(@cEachUOM)) <> LTRIM(RTRIM(@cSKUDefaultUOM))
         BEGIN
            SET @cOutField04 = CAST( @f_Qty AS NVARCHAR(10))
            SET @cOutField05 = CAST(@cSKUDefaultUOM AS NVARCHAR(10)) + ' ' + @cCountedFlag
            SET @cOutField06 = ''
            SET @cOutField07 = ''
         END
         ELSE
         BEGIN
            SET @cOutField04 = ''
            SET @cOutField05 = CAST('' AS NVARCHAR(10)) + ' ' + @cCountedFlag
            SET @cOutField06 = CAST( @f_Qty AS NVARCHAR(10))    -- QTY (EA)
            SET @cOutField07 = @cEachUOM + @cPPK               -- UOM (EA) + PPK
         END
      END
      ELSE
      BEGIN
         SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(10))   -- QTY (CS) -- (ChewKP01)
         SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS)
       SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP01)
         SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
      END

      -- (james14)
      SET @cSKUCountDefaultOpt = ''
      SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorerKey)
      IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
         SET @cSKUCountDefaultOpt = ''

      SET @cOutField08 = @cID
      --SET @cOutField09 = @cLottable01
      --SET @cOutField10 = @cLottable02
      --SET @cOutField11 = @cLottable03
      --SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
      --SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
      SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14)
--    SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
      SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                              THEN RIGHT( SPACE(4) + CAST( @nCntQTY AS NVARCHAR( 4)), 4)
                              ELSE CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4))
                              END

      -- Go to previous screen
      SET @nScn  = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
   GOTO Quit

   SKU_Add_Sku_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = '' -- SKU/UPC
   END
END
GOTO Quit

/************************************************************************************
Step_SKU_Add_Qty. Scn = 674. Screen 12.
   LOC         (field01)
   ID    (field02)
   SKU/UPC     (field03)
   SKU DESCR1  (field04)
   SKU DESCR2  (field05)
   QTY         (field06) - CS - Input field
   UOM         (field07) - CS
   QTY         (field08) - EA - Input field
   UOM, PPK    (field09) - EA
*************************************************************************************/
Step_SKU_Add_Qty:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cNewCaseQTY = @cInField06
      SET @cNewEachQTY = @cInField08

      -- Retain the key-in value
      SET @cOutField06 = @cNewCaseQTY
      SET @cOutField08 = @cNewEachQTY


      -- Validate QTY (CS)
      IF @cNewCaseQTY <> '' AND @cNewCaseQTY IS NOT NULL
      BEGIN
         IF rdt.rdtIsValidQTY( @cNewCaseQTY, 20) <> 1
         BEGIN
            SET @nErrNo = 62122
            SET @cErrMsg = rdt.rdtgetmessage( 62122, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
            GOTO SKU_Add_Qty_Fail
         END

         -- Check if the len of the qty cannot > 10
  IF LEN(LTRIM(RTRIM(@cNewCaseQTY))) > 10
         BEGIN
            SET @nErrNo = 66845
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
            GOTO SKU_Add_Qty_Fail
         END

         -- Check max no of decimal is only 6
         IF rdt.rdtIsRegExMatch('^\d{0,6}(\.\d{1,6})?$', LTRIM(RTRIM(@cNewCaseQTY))) = 0
         BEGIN
            SET @nErrNo = 66846
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
            GOTO SKU_Add_Qty_Fail
         END
      END

      -- Validate QTY (EA)
      IF @cNewEachQTY <> '' AND @cNewEachQTY IS NOT NULL
      BEGIN
         IF rdt.rdtIsValidQTY( @cNewEachQTY, 20) <> 1
         BEGIN
            SET @nErrNo = 62123
            SET @cErrMsg = rdt.rdtgetmessage( 62123, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 8   -- QTY (EA)
            GOTO SKU_Add_Qty_Fail
         END

         -- Check if the len of the qty cannot > 10
         IF LEN(LTRIM(RTRIM(@cNewEachQTY))) > 10
         BEGIN
            SET @nErrNo = 66845
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (EA)
            GOTO SKU_Add_Qty_Fail
         END

         -- Master unit not support decimal
         IF CHARINDEX('.', @cNewEachQTY) > 0
         BEGIN
            SET @nErrNo = 66846
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (EA)
            GOTO SKU_Add_Qty_Fail
         END
      END

      -- (james08)
      SET @nNewCaseQTY = CASE WHEN @cNewCaseQTY <> '' AND @cNewCaseQTY IS NOT NULL THEN CAST( @cNewCaseQTY AS FLOAT) ELSE 0 END
      SET @nNewEachQTY = CASE WHEN @cNewEachQTY <> '' AND @cNewEachQTY IS NOT NULL THEN CAST( @cNewEachQTY AS FLOAT) ELSE 0 END

      -- Re-select CaseCnt (get the IDSCN_RDT casecnt)
      SELECT TOP 1
         @nNewCaseCnt  = PAC.CaseCnt
      FROM dbo.SKU SKU (NOLOCK)
      INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cNewSKU

      -- If CaseCnt not setup, not allow to enter QTY (CS)
      IF @nNewCaseCnt = 0 AND @nNewCaseQTY > 0
      BEGIN
         SET @nErrNo = 62124
         SET @cErrMsg = rdt.rdtgetmessage( 62124, @cLangCode, 'DSP') -- 'Zero CaseCnt'
         EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
         GOTO SKU_Add_Qty_Fail
      END

      -- Total of QTY must greater than zero
      IF @nNewCaseQTY + @nNewEachQTY = 0
      BEGIN
         SET @nErrNo = 62125
         SET @cErrMsg = rdt.rdtgetmessage( 62125, @cLangCode, 'DSP') -- 'QTY required'

         IF @nNewCaseCnt > 0
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 8   -- QTY (EA)

         GOTO SKU_Add_Qty_Fail
      END

      -- (MaryVong01)
      -- Initialize Lottables
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = NULL
      SET @dLottable05 = NULL
      SET @cLottable06 = ''
      SET @cLottable07 = ''
      SET @cLottable08 = ''
      SET @cLottable09 = ''
      SET @cLottable10 = ''
      SET @cLottable11 = ''
      SET @cLottable12 = ''
      SET @dLottable13 = NULL
      SET @dLottable14 = NULL
      SET @dLottable15 = NULL

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
      --EXECUTE rdt.rdt_CycleCount_GetLottables_v7
      --   @cCCRefNo, @cStorerKey, @cNewSKU, 'PRE', -- Codelkup.Short
      --   '', --@cIn_Lottable01
      --   '', --@cIn_Lottable02
      --   '', --@cIn_Lottable03
      --   '', --@dIn_Lottable04
      --   '', --@dIn_Lottable05
      --   @cLotLabel01      OUTPUT, @cLotLabel06      OUTPUT, @cLotLabel11      OUTPUT,
      --   @cLotLabel02      OUTPUT, @cLotLabel07      OUTPUT, @cLotLabel12      OUTPUT,   
      --   @cLotLabel03      OUTPUT, @cLotLabel08      OUTPUT, @cLotLabel13      OUTPUT,   
      --   @cLotLabel04      OUTPUT, @cLotLabel09      OUTPUT, @cLotLabel14      OUTPUT,   
      --   @cLotLabel05      OUTPUT, @cLotLabel10      OUTPUT, @cLotLabel15      OUTPUT,   
      --   @cLottable01_Code OUTPUT, @cLottable06_Code OUTPUT, @cLottable11_Code OUTPUT,
      --   @cLottable02_Code OUTPUT, @cLottable07_Code OUTPUT, @cLottable12_Code OUTPUT,
      --   @cLottable03_Code OUTPUT, @cLottable08_Code OUTPUT, @cLottable13_Code OUTPUT,
      --   @cLottable04_Code OUTPUT, @cLottable09_Code OUTPUT, @cLottable14_Code OUTPUT,
      --   @cLottable05_Code OUTPUT, @cLottable10_Code OUTPUT, @cLottable15_Code OUTPUT,
      --   @cLottable01      OUTPUT, @cLottable06      OUTPUT, @cLottable11      OUTPUT,
      --   @cLottable02      OUTPUT, @cLottable07      OUTPUT, @cLottable12      OUTPUT,
      --   @cLottable03      OUTPUT, @cLottable08      OUTPUT, @cLottable13      OUTPUT,
      --   @dLottable04      OUTPUT, @cLottable09      OUTPUT, @cLottable14      OUTPUT,
      --   @dLottable05      OUTPUT, @cLottable10      OUTPUT, @cLottable15      OUTPUT,
      --   @cHasLottable     OUTPUT,
      --   @nSetFocusField   OUTPUT,
      --   @nErrNo           OUTPUT,
      --   @cErrMsg          OUTPUT


      --IF ISNULL(@cErrMsg, '') <> ''
      --   GOTO SKU_Add_Qty_Fail
      
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1, 
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
      BEGIN
         -- Go to dynamic lottable screen
         SET @nFromScn = @nScn
         SET @nScn = 3990
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      -- Go to next screen
      SET @nScn  = @nScn_SKU_Add_Lottables
      SET @nStep = @nStep_SKU_Add_Lottables

      -- Initiate next screen var
      --IF @cHasLottable = '1'
      --BEGIN
      --   -- Clear all outfields
      --   SET @cOutField01 = ''
      --   SET @cOutField02 = ''
      --   SET @cOutField03 = ''
      --   SET @cOutField04 = ''
      --   SET @cOutField05 = ''
      --   SET @cOutField06 = ''
      --   SET @cOutField07 = ''
      --   SET @cOutField08 = ''
      --   SET @cOutField09 = ''
      --   SET @cOutField10 = ''
      --   SET @cOutField11 = ''
      --   SET @cOutField12 = ''
      --   SET @cOutField13 = ''

      --   -- Initiate labels
      --   SELECT
      --      @cOutField01 = 'Lottable01:',
      --      @cOutField03 = 'Lottable02:',
      --      @cOutField05 = 'Lottable03:',
      --      @cOutField07 = 'Lottable04:',
      --      @cOutField09 = 'Lottable05:'

      --   -- Populate labels and lottables
      --   IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
      --   BEGIN
      --      SET @cFieldAttr02 = 'O'
      --   END
      --   ELSE
      --   BEGIN
      --      SELECT @cOutField01 = @cLotLabel01,
      --             @cOutField02 = ISNULL(@cLottable01, '')
      --   END

      --   IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
      --      BEGIN
      --      SET @cFieldAttr04 = 'O'
      --   END
      --   ELSE
      --   BEGIN
      --      SELECT @cOutField03 = @cLotLabel02,
      --             @cOutField04 = ISNULL(@cLottable02, '')
      --   END

      --   IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
      --   BEGIN
      --       SET @cFieldAttr06 = 'O'
      --   END
      --   ELSE
      --   BEGIN
      --     SELECT @cOutField05 = @cLotLabel03,
      --            @cOutField06 = ISNULL(@cLottable03, '')
      --   END

      --   IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
      --   BEGIN
      --      SET @cFieldAttr08 = 'O'
      --   END
      --   ELSE
      --   BEGIN
      --      SELECT  @cOutField07 = @cLotLabel04,
      --              @cOutField08 = RDT.RDTFormatDate(ISNULL(@dLottable04, ''))
      --   END

      --   IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
      --   BEGIN
      --      SET @cFieldAttr10 = 'O'
      --   END
      --   ELSE
      --   BEGIN
      --      -- Lottable05 is usually RCP_DATE
      --      IF @cLottable05_Code = 'RCP_DATE'
      --      BEGIN
      --         SET @dLottable05 = GETDATE()
      --      END

      --      SELECT
      --         @cOutField09 = @cLotLabel05,
      --         @cOutField10 = RDT.RDTFormatDate( @dLottable05)
      --   END

      --   EXEC rdt.rdtSetFocusField @nMobile, 1   -- Lottable01 value

      ---- Dynamic lottable
      --EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1, 
      --   @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
      --   @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
      --   @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
      --   @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
      --   @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
      --   @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
      --   @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
      --   @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
      --   @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
      --   @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
      --   @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
      --   @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
      --   @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
      --   @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
      --   @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
      --   @nMorePage   OUTPUT,
      --   @nErrNo      OUTPUT,
      --   @cErrMsg     OUTPUT,
      --   '',
      --   @nFunc

      --    INSERT INTO traceInfo (traceName,Col1,Col2,Col3,Col4,Col5)
      --    VALUES ('cc_v76',@cInField02,@cOutField02,@cFieldAttr02,@cLottable02,@cLottable06)
       
      --IF @nErrNo <> 0
      --   GOTO Quit

      --IF @nMorePage = 1 -- Yes
      --BEGIN
      --   -- Go to dynamic lottable screen
      --   SET @nFromScn = @nScn
      --   SET @nScn = 3990
      --   SET @nStep = @nStep + 1

      --   GOTO Quit
      --END

      --   -- Go to next screen
      --   SET @nScn  = @nScn_SKU_Add_Lottables
      --   SET @nStep = @nStep_SKU_Add_Lottables
      --END -- End of @cHasLottable = '1'

      --IF @cHasLottable = '0'
      --BEGIN
         -- Convert QTY
         IF @nNewCaseCnt > 0
         BEGIN
            SET @nConvQTY = (@nNewCaseQTY * @nNewCaseCnt) + @nNewEachQTY
            SET @fConvQTY = (@nNewCaseQTY * @nCaseCnt) + @nNewEachQTY
         END
         ELSE
         BEGIN
        SET @nConvQTY = @nNewEachQTY
            SET @fConvQTY = @nNewEachQTY --ang01
         END

         --IF CHARINDEX('.', @fConvQTY) > 0

         -- Start Checking for decimal
         SET @nI = CAST(@fConvQTY AS INT) -- (james09)
         IF @nI <> CAST(@fConvQTY AS INT)
         BEGIN
            SET @nErrNo = 66847
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INV Qty
            GOTO SKU_Add_Qty_Fail
         END

         -- Insert a record into CCDETAIL
         SET @nErrNo = 0
         SET @cErrMsg = ''
         IF dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey) <> '0'
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
               '',            -- No UCC
               '',            -- No LOT generated yet
               @cLOC,         -- Current LOC
               @cID,          -- Entered ID, it can be blank
               @fConvQTY,
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
         ELSE
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
               '',            -- No UCC
               '',            -- No LOT generated yet
               @cLOC,         -- Current LOC
               @cID,          -- Entered ID, it can be blank
               @nConvQTY,
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
            GOTO SKU_Add_Qty_Fail

         -- (MaryVong01)
         -- Increment Counted CCDet Lines by 1
         SET @nCntQTY = @nCntQTY + 1

         -- Increment Total CCDet Lines (for a particular LOC + ID) by 1
         SET @nCCDLinesPerLOCID = @nCCDLinesPerLOCID + 1

         SET @cEditSKU = 'Y' -- (Vicky03)

         SELECT TOP 1
            @nCaseQty = CASE WHEN PAC.CaseCnt > 0 AND @nConvQTY > 0
                             THEN FLOOR( @nConvQTY / PAC.CaseCnt)
                        ELSE 0 END,
            @nEachQty = CASE WHEN PAC.CaseCnt > 0
                                THEN @nConvQTY % CAST (PAC.CaseCnt AS INT)
                             WHEN PAC.CaseCnt = 0
                                THEN @nConvQTY
                             ELSE 0 END
         FROM dbo.SKU SKU (NOLOCK)
            INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cNewSKU

         -- Set variables
         SET @cSKU = @cNewSKU
         SET @cSKUDescr = @cNewSKUDescr1 + @cNewSKUDescr2
--         SET @nCaseQTY = @nNewCaseQTY
         SET @cCaseUOM = @cNewCaseUOM
--         SET @nEachQTY = @nNewEachQTY
         SET @cEachUOM = @cNewEachUOM
         SET @cPPK = @cNewPPK
         SET @cCountedFlag = '[C]'

         -- Prepare SKU (Main) screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
         IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorerKey) = '1'
         BEGIN
            SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
            SET @cOutField03 = 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16)
         END
         ELSE
         BEGIN
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
         END

         SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey)

         -- If config turned on and skuconfig not setup then prompt error
         IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorerKey) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
         BEGIN
            SET @nErrNo = 66842
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END

         -- If SKUCONFIG setup
         IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
               JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
               WHERE S.StorerKey = @cStorerKey
               AND S.SKU = @cSKU
               AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
            BEGIN
               SET @nErrNo = 66844
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
               EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
               GOTO ID_Fail
            END

            SET @nQTY = 0
            -- Get Counted CCDet Lines for a particular LOC + ID
            SELECT @nQTY = CASE WHEN @nCCCountNo = 1 THEN
                              CASE WHEN Counted_Cnt1 = 0 THEN
                                    CASE WHEN @cWithQtyFlag = 'Y' THEN QTY
                                         WHEN @cWithQtyFlag = 'N' THEN 0
                                    END
                                   WHEN Counted_Cnt1 = 1 THEN QTY
                              END
                              WHEN @nCCCountNo = 2 THEN QTY_Cnt2
                              WHEN @nCCCountNo = 3 THEN QTY_Cnt3
                              END
            FROM dbo.CCDETAIL (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
            AND LOC = @cLOC
            AND ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
            AND Status < '9'

            SELECT @c_PackKey = P.PackKey FROM dbo.Pack P WITH (NOLOCK)
            JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
            WHERE S.StorerKey = @cStorerKey
               AND S.SKU = @cSKU

            SELECT @b_success = 0
            EXEC nspUOMCONV
            @n_fromqty    = @nQTY,
            @c_fromuom    = @cEachUOM,
            @c_touom      = @cSKUDefaultUOM,
            @c_packkey    = @c_PackKey,
            @n_toqty      = @f_Qty        OUTPUT,
            @b_Success    = @b_Success    OUTPUT,
            @n_err        = @n_err        OUTPUT,
            @c_errmsg     = @c_errmsg     OUTPUT

            IF NOT @b_success = 1
            BEGIN
               SET @nErrNo = 66843
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CONV FAIL'
               EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
               GOTO ID_Fail
            END

            IF LTRIM(RTRIM(@cEachUOM)) <> LTRIM(RTRIM(@cSKUDefaultUOM))
            BEGIN
               SET @cOutField04 = CAST( @f_Qty AS NVARCHAR(10))
               SET @cOutField05 = CAST(@cSKUDefaultUOM AS NVARCHAR(10)) + ' ' + @cCountedFlag
               SET @cOutField06 = ''
               SET @cOutField07 = ''
            END
            ELSE
            BEGIN
            SET @cOutField04 = ''
               SET @cOutField05 = CAST('' AS NVARCHAR(10)) + ' ' + @cCountedFlag
               SET @cOutField06 = CAST( @f_Qty AS NVARCHAR(10))    -- QTY (EA)
        SET @cOutField07 = @cEachUOM + @cPPK               -- UOM (EA) + PPK
            END
         END
         ELSE
         BEGIN
            SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(10))   -- QTY (CS) -- (ChewKP01)
            SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS)
            SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP01)
            SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
         END

         -- (james14) --IN00137901
         SET @cSKUCountDefaultOpt = ''
     SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorerKey)
         IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
            SET @cSKUCountDefaultOpt = ''

         SET @cOutField08 = @cID
         SET @cOutField09 = ''   -- Lottable01
         SET @cOutField10 = ''   -- Lottable02
         SET @cOutField11 = ''   -- Lottable03             SET @cOutField12 = ''   -- Lottable04
         SET @cOutField13 = ''   -- Lottable05
         SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14) --IN00137901
--       SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
         SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                                 THEN RIGHT( SPACE(4) + CAST( @nCntQTY AS NVARCHAR( 4)), 4)
                                 ELSE CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4))
                                 END

         -- Go to SKU (Main) screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
     -- END -- End of @cHasLottable = '0'
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Clear previous screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''   -- SKU
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
      SET @nScn  = @nScn_SKU_Add_Sku
      SET @nStep = @nStep_SKU_Add_Sku
   END
   GOTO Quit

   SKU_Add_Qty_Fail:
END
GOTO Quit

/************************************************************************************
Step_SKU_Add_Lottables. Scn = 675. Screen 13.
   LOTTABLE01Label (field01)     LOTTABLE01 (field02) - Input field
   LOTTABLE02Label (field03)     LOTTABLE02 (field04) - Input field
   LOTTABLE03Label (field05)     LOTTABLE03 (field06) - Input field
   LOTTABLE04Label (field07)     LOTTABLE04 (field08) - Input field
   LOTTABLE05Label (field09)     LOTTABLE05 (field10) - Input field
*************************************************************************************/
Step_SKU_Add_Lottables:
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
      /*
      IF rdt.rdtIsValidDate(@cNewLottable04) = 1 --valid date
         --SET @dNewLottable04 = CAST( @cNewLottable04 AS DATETIME) (james22)
         SET @dNewLottable04 = RDT.rdtConvertToDate( @cNewLottable04)
      ELSE
        SET @dNewLottable04 = NULL -- Bug fix. If no value keyed then need to set lottable04 = null too

      IF rdt.rdtIsValidDate(@cNewLottable05) = 1 --valid date
         --SET @dNewLottable05 = CAST( @cNewLottable05 AS DATETIME) (james22)
         SET @dNewLottable05 = RDT.rdtConvertToDate( @cNewLottable05)
      ELSE
         SET @dNewLottable05 = NULL -- Bug fix. If no value keyed then need to set lottable05 = null too
--         SET @cErrMsg = @dNewLottable04
--            GOTO quit

      -- SOS#81879
      -- Get Lottables Details
      EXECUTE rdt.rdt_CycleCount_GetLottables
         @cCCRefNo, @cStorerKey, @cNewSKU, 'POST', -- Codelkup.Short
         @cNewLottable01,
         @cNewLottable02,
         @cNewLottable03,
         @dNewLottable04,
         @dNewLottable05,
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
         @cTempLottable01  OUTPUT,  --@cLottable01      OUTPUT,
         @cTempLottable02  OUTPUT,  --@cLottable02      OUTPUT,
         @cTempLottable03  OUTPUT,  --@cLottable03      OUTPUT,
         @dTempLottable04  OUTPUT,  --@dLottable04      OUTPUT,
         @dTempLottable05  OUTPUT,  --@dLottable05      OUTPUT,
         @cHasLottable     OUTPUT,
         @nSetFocusField   OUTPUT,
         @nErrNo           OUTPUT,
         @cErrMsg          OUTPUT

      IF ISNULL(@cErrMsg, '') <> ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, @nSetFocusField
         GOTO SKU_Add_Lottables_Fail
      END

      SET @cOutField02 = CASE WHEN ISNULL(@cTempLottable01,'') <> '' THEN @cTempLottable01 ELSE @cNewLottable01 END
      SET @cOutField04 = CASE WHEN ISNULL(@cTempLottable02,'') <> '' THEN @cTempLottable02 ELSE @cNewLottable02 END
      SET @cOutField06 = CASE WHEN ISNULL(@cTempLottable03,'') <> '' THEN @cTempLottable03 ELSE @cNewLottable03 END
      SET @cOutField08 = CASE WHEN @dTempLottable04 IS NOT NULL THEN rdt.rdtFormatDate( @dTempLottable04) ELSE rdt.rdtFormatDate( @dNewLottable04) END

      SET @cNewLottable01 = ISNULL(@cOutField02, '')
      SET @cNewLottable02 = ISNULL(@cOutField04, '')
      SET @cNewLottable03 = ISNULL(@cOutField06, '')
      SET @cNewLottable04 = ISNULL(@cOutField08, '')

      -- Validate lottable01
      IF @cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL
         IF @cNewLottable01 = '' OR @cNewLottable01 IS NULL
         BEGIN
            SET @nErrNo = 62126
            SET @cErrMsg = rdt.rdtgetmessage( 62126, @cLangCode, 'DSP') -- 'Lottable1 req'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO SKU_Add_Lottables_Fail
         END

      -- Validate lottable02
      IF @cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL
      BEGIN
         IF @cNewLottable02 = '' OR @cNewLottable02 IS NULL
         BEGIN
            SET @nErrNo = 62127
            SET @cErrMsg = rdt.rdtgetmessage( 62127, @cLangCode, 'DSP') -- 'Lottable2 req'
            EXEC rdt.rdtSetFocusField @nMobile, 4
       GOTO SKU_Add_Lottables_Fail
         END
      END

      -- Validate lottable03
      IF @cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL
         IF @cNewLottable03 = '' OR @cNewLottable03 IS NULL
         BEGIN
            SET @nErrNo = 62129
            SET @cErrMsg = rdt.rdtgetmessage( 62129, @cLangCode, 'DSP') -- 'Lottable3 req'
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO SKU_Add_Lottables_Fail
         END

      -- Validate lottable04
      IF @cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL
      BEGIN
         -- Validate empty
         IF @cNewLottable04 = '' OR @cNewLottable04 IS NULL
         BEGIN
            SET @nErrNo = 62130
            SET @cErrMsg = rdt.rdtgetmessage( 62130, @cLangCode, 'DSP') -- 'Lottable4 req'
   EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO SKU_Add_Lottables_Fail
         END
         -- Validate date
         IF rdt.rdtIsValidDate( @cNewLottable04) = 0
         BEGIN
            SET @nErrNo = 62131
      SET @cErrMsg = rdt.rdtgetmessage( 62131, @cLangCode, 'DSP') -- 'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO SKU_Add_Lottables_Fail
         END
      END

      -- Validate lottable05
      IF @cLotLabel05 <> '' AND @cLotLabel05 IS NOT NULL
      BEGIN
         -- Validate empty
         IF @cNewLottable05 = '' OR @cNewLottable05 IS NULL
         BEGIN
            SET @nErrNo = 62132
            SET @cErrMsg = rdt.rdtgetmessage( 62132, @cLangCode, 'DSP') -- 'Lottable5 req'
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO SKU_Add_Lottables_Fail
         END
         -- Validate date
         IF rdt.rdtIsValidDate( @cNewLottable05) = 0
         BEGIN
            SET @nErrNo = 62133
            SET @cErrMsg = rdt.rdtgetmessage( 62133, @cLangCode, 'DSP') -- 'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO SKU_Add_Lottables_Fail
         END
      END
      */
      -- Convert QTY
      IF @nNewCaseCnt > 0
         SET @nConvQTY = (@nNewCaseQTY * @nNewCaseCnt) + @nNewEachQTY
      ELSE
         SET @nConvQTY = @nNewEachQTY

      IF @cNewLottable04 <> '' AND @cNewLottable04 IS NOT NULL
         --SET @dNewLottable04 = CAST( @cNewLottable04 AS DATETIME) (james22)
         SET @dNewLottable04 = RDT.rdtConvertToDate( @cNewLottable04)
      ELSE
         SET @dNewLottable04 = NULL

      IF @cNewLottable05 <> '' AND @cNewLottable05 IS NOT NULL
         --SET @dNewLottable05 = CAST( @cNewLottable05 AS DATETIME) (james22)
         SET @dNewLottable05 = RDT.rdtConvertToDate( @cNewLottable05)
      ELSE
         SET @dNewLottable05 = NULL


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
         '',            -- No UCC
         '',            -- No LOT generated yet
         @cLOC,         -- Current LOC
         @cID,          -- Entered ID, it can be blank
         @nConvQTY,
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
         GOTO SKU_Add_Lottables_Fail

      -- (MaryVong01)
      -- Increment Counted CCDet Lines by 1
      SET @nCntQTY = @nCntQTY + 1

      -- Increment Total CCDet Lines (for a particular LOC + ID) by 1
      SET @nCCDLinesPerLOCID = @nCCDLinesPerLOCID + 1

      SET @cEditSKU = 'Y' -- (Vicky03)

      -- (james08)
      SELECT TOP 1
         @nCaseQty = CASE WHEN PAC.CaseCnt > 0 AND @nConvQTY > 0
                             THEN FLOOR( @nConvQTY / PAC.CaseCnt)
                          ELSE 0 END,
         @nEachQty = CASE WHEN PAC.CaseCnt > 0
                             THEN @nConvQTY % CAST (PAC.CaseCnt AS INT)
                          WHEN PAC.CaseCnt = 0
                             THEN @nConvQTY
                          ELSE 0 END
      FROM dbo.SKU SKU (NOLOCK)
         INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cNewSKU

      -- Set variables
      SET @cSKU = @cNewSKU
      SET @cSKUDescr = @cNewSKUDescr1 + @cNewSKUDescr2
--      SET @nCaseQTY = @nNewCaseQTY
      SET @cCaseUOM = @cNewCaseUOM
--      SET @nEachQTY = @nNewEachQTY
      SET @cEachUOM = @cNewEachUOM
      SET @cPPK = @cNewPPK
      SET @cCountedFlag = '[C]'
      SET @cLottable01 = @cNewLottable01
      SET @cLottable02 = @cNewLottable02
      SET @cLottable03 = @cNewLottable03
      SET @dLottable04 = @dNewLottable04
      SET @dLottable05 = @dNewLottable05
      
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 5, 9, 
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

      -- Prepare SKU (Main) screen var
      SET @cOutField01 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cSKU END
      SET @cOutField02 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20) END
      IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorerKey) = '1'          BEGIN
         SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
         SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16) END
      END
      ELSE
      BEGIN
         SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 40) END
      END

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorerKey) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
      BEGIN
         SET @nErrNo = 66842
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO ID_Fail
      END

      -- If SKUCONFIG setup
      IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
            JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
            WHERE S.StorerKey = @cStorerKey
            AND S.SKU = @cSKU
            AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
         BEGIN
            SET @nErrNo = 66844
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END

         SET @nQTY = 0
         -- Get Counted CCDet Lines for a particular LOC + ID
         SELECT @nQTY = CASE WHEN @nCCCountNo = 1 THEN
                              CASE WHEN Counted_Cnt1 = 0 THEN
                                 CASE WHEN @cWithQtyFlag = 'Y' THEN QTY
                                 WHEN @cWithQtyFlag = 'N' THEN 0
                                 END
                              WHEN Counted_Cnt1 = 1 THEN QTY
                              END
                           WHEN @nCCCountNo = 2 THEN QTY_Cnt2
                           WHEN @nCCCountNo = 3 THEN QTY_Cnt3
                           END
         FROM dbo.CCDETAIL (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
         AND LOC = @cLOC
         AND ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
         AND Status < '9'

         SELECT @c_PackKey = P.PackKey FROM dbo.Pack P WITH (NOLOCK)
         JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
         WHERE S.StorerKey = @cStorerKey
            AND S.SKU = @cSKU

       SELECT @b_success = 0
         EXEC nspUOMCONV
         @n_fromqty    = @nQTY,
         @c_fromuom    = @cEachUOM,
         @c_touom      = @cSKUDefaultUOM,
         @c_packkey    = @c_PackKey,
         @n_toqty      = @f_Qty        OUTPUT,
         @b_Success    = @b_Success    OUTPUT,
         @n_err        = @n_err        OUTPUT,
         @c_errmsg     = @c_errmsg     OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SET @nErrNo = 66843
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CONV FAIL'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END

         IF LTRIM(RTRIM(@cEachUOM)) <> LTRIM(RTRIM(@cSKUDefaultUOM))
         BEGIN
            SET @cOutField04 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '0' ELSE CAST( @f_Qty AS NVARCHAR(10)) END
            SET @cOutField05 = CAST(@cSKUDefaultUOM AS NVARCHAR(10)) + ' ' + @cCountedFlag
            SET @cOutField06 = ''
            SET @cOutField07 = ''
         END
         ELSE
         BEGIN
            SET @cOutField04 = ''
            SET @cOutField05 = CAST('' AS NVARCHAR(10)) + ' ' + @cCountedFlag
            SET @cOutField06 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '0' ELSE CAST( @f_Qty AS NVARCHAR(10)) END   -- QTY (EA)
            SET @cOutField07 = @cEachUOM + @cPPK               -- UOM (EA) + PPK
         END
      END
      ELSE
      BEGIN
         SET @cOutField04 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '0' ELSE CAST( @nCaseQTY AS NVARCHAR(10)) END  -- QTY (CS) -- (ChewKP01)
         SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS)
         SET @cOutField06 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '0' ELSE CAST( @nEachQTY AS NVARCHAR(10)) END   -- QTY (EA) -- (ChewKP01)
         SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
      END

      -- (james14)--IN00137901
      SET @cSKUCountDefaultOpt = ''
      SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorerKey)
      IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
         SET @cSKUCountDefaultOpt = ''

      SET @cOutField08 = @cID
      --SET @cOutField09 = @cLottable01
      --SET @cOutField10 = @cLottable02
      --SET @cOutField11 = @cLottable03
      --SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
      --SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
      SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14)--IN00137901
--    SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
      SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                              THEN RIGHT( SPACE(4) + CAST( @nCntQTY AS NVARCHAR( 4)), 4)
                              ELSE CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4))
                              END
--    RIGHT( '00000' + CAST( @nBultoNo AS NVARCHAR( 5)), 5)
      -- Go to SKU (Main) screen
      SET @nScn  = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
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

     SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey)

      -- Set cursor
      IF @nNewCaseCnt > 0
         EXEC rdt.rdtSetFocusField @nMobile, 4   -- QTY (CS)
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (EA)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorerKey) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
      BEGIN
         SET @nErrNo = 66842
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO SKU_Add_Lottables_Fail
      END

      -- Prepare previous screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 40)

      -- If SKUCONFIG setup
      IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
            JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
          WHERE S.StorerKey = @cStorerKey
            AND S.SKU = @cSKU
            AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
         BEGIN
            SET @nErrNo = 66844
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO SKU_Add_Lottables_Fail
         END

         IF LTRIM(RTRIM(@cEachUOM)) <> LTRIM(RTRIM(@cSKUDefaultUOM))
         BEGIN
            SET @cOutField06 = ''
            SET @cOutField07 = @cSKUDefaultUOM
            SET @cOutField08 = ''
            SET @cOutField09 = ''
            SET @cFieldAttr08 = 'O'
            SET @cFieldAttr09 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = @cSKUDefaultUOM + ' ' + @cNewPPK   -- UOM (EA) + PPK
            SET @cFieldAttr06 = 'O'
            SET @cFieldAttr07 = 'O'
         END
      END
      ELSE
      BEGIN
         SET @cOutField06 = CAST( @nNewCaseQTY AS NVARCHAR( 5))   -- QTY (CS)
         SET @cOutField07 = @cNewCaseUOM                         -- UOM (CS)
         SET @cOutField08 = CAST( @nNewEachQTY AS NVARCHAR( 5))   -- QTY (EA)
         SET @cOutField09 = @cNewEachUOM + ' ' + @cNewPPK        -- UOM (EA) + PPK
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField12 = ''
         SET @cOutField13 = ''
      END

      -- Go to previous screen
      SET @nScn  = @nScn_SKU_Add_Qty
      SET @nStep = @nStep_SKU_Add_Qty
   END
   GOTO Quit

   SKU_Add_Lottables_Fail:
   BEGIN
      -- (Vicky02) - Start
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''
      -- (Vicky02) - End

      -- Init next screen var
      IF @cHasLottable = '1'
      BEGIN
         -- Disable lottable
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr02 = 'O' -- (Vicky02)
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr04 = 'O' -- (Vicky02)
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
            SET @cFieldAttr06 = 'O' -- (Vicky02)
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O' -- (Vicky02)
         END

         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
         BEGIN
            SET @cFieldAttr10 = 'O' -- (Vicky02)
         END
      END
   END
END
GOTO Quit

/************************************************************************************
Step_SKU_Edit_Qty. Scn = 676. Screen 14.
  SKU         (field01)                 LOTTABLE01  (field08)
  SKU DESCR1  (field02)             LOTTABLE02  (field09)
  SKU DESCR2  (field03)                 LOTTABLE03  (field10)
  QTY         (field04) - CS - Input    LOTTABLE04  (field11)
  UOM         (field05) - CS            LOTTABLE05  (field12)
  QTY         (field06) - EA - Input
  UOM, PPK    (field07) - EA
*************************************************************************************/
Step_SKU_Edit_Qty:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cNewCaseQTY = @cInField04
      SET @cNewEachQTY = @cInField06

      -- Retain the key-in value
      SET @cOutField04 = @cNewCaseQTY
      SET @cOutField06 = @cNewEachQTY

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

      -- Validate QTY (CS)
      IF @cNewCaseQTY <> '' AND @cNewCaseQTY IS NOT NULL
      BEGIN
         IF rdt.rdtIsValidQTY( @cNewCaseQTY, 20) <> 1
         BEGIN
            SET @nErrNo = 62134
            SET @cErrMsg = rdt.rdtgetmessage( 62134, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 4   -- QTY (CS)
            GOTO SKU_Edit_Qty_Fail
         END

         -- Check if the len of the qty cannot > 10
         IF LEN(LTRIM(RTRIM(@cNewCaseQTY))) > 10
         BEGIN
            SET @nErrNo = 66845
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 4   -- QTY (CS)
            GOTO SKU_Edit_Qty_Fail
         END

         -- Check if max no of decimal is 6
         IF rdt.rdtIsRegExMatch('^\d{0,6}(\.\d{1,6})?$', LTRIM(RTRIM(@cNewCaseQTY))) = 0
         BEGIN
            SET @nErrNo = 66846
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 4   -- QTY (CS)
            GOTO SKU_Edit_Qty_Fail
         END
      END

      -- Validate QTY (EA)
      IF @cNewEachQTY <> '' AND @cNewEachQTY IS NOT NULL
      BEGIN
         IF rdt.rdtIsValidQTY( @cNewEachQTY, 20) <> 1
         BEGIN
            SET @nErrNo = 62135
            SET @cErrMsg = rdt.rdtgetmessage( 62135, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (EA)
            GOTO SKU_Edit_Qty_Fail
         END

         -- Check if the len of the qty cannot > 10
         IF LEN(LTRIM(RTRIM(@cNewEachQTY))) > 10
         BEGIN
            SET @nErrNo = 66845
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 4   -- QTY (EA)
            GOTO SKU_Edit_Qty_Fail
         END

         -- Master unit not support decimal
         IF CHARINDEX('.', @cNewEachQTY) > 0
         BEGIN
            SET @nErrNo = 66846
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 4   -- QTY (EA)
            GOTO SKU_Edit_Qty_Fail
         END
      END

      -- Store in New variables
     -- (james08)
      SET @nNewCaseQTY = CASE WHEN @cNewCaseQTY <> '' AND @cNewCaseQTY IS NOT NULL THEN CAST( @cNewCaseQTY AS FLOAT) ELSE 0 END
      SET @nNewEachQTY = CASE WHEN @cNewEachQTY <> '' AND @cNewEachQTY IS NOT NULL THEN CAST( @cNewEachQTY AS FLOAT) ELSE 0 END

      -- Compare CaseCnt not NewCaseCnt, it is passed from previous screen
      IF @nCaseCnt = 0 AND @nNewCaseQTY > 0
      BEGIN
         SET @nErrNo = 62136
         SET @cErrMsg = rdt.rdtgetmessage( 62136, @cLangCode, 'DSP') -- 'Zero CaseCnt'
         GOTO SKU_Edit_Qty_Fail
      END

      -- Get status
      SELECT @cStatus = Status
      FROM dbo.CCDETAIL (NOLOCK)
      WHERE CCDetailKey = @cCCDetailKey

      -- Update when Status = '0' or QTY is diff
      -- Status = '0' is 1st time verification, if EDIT then QTY shd be diff
      IF @cStatus = '0' OR
         @nNewCaseQTY <> @nCaseQTY OR
         @nNewEachQTY <> @nEachQTY
      BEGIN
         -- Convert QTY
         -- Allow zero QTY for Total of CaseQTY + EachQTY
         -- Check on CaseCnt, not NewCaseCnt
         IF @nCaseCnt > 0
         BEGIN
            SET @nConvQTY = (@nNewCaseQTY * @nCaseCnt) + @nNewEachQTY
            SET @fConvQTY = (@nNewCaseQTY * @nCaseCnt) + @nNewEachQTY
         END
         ELSE
         BEGIN
            SET @nConvQTY = @nNewEachQTY
            SET @fConvQTY = @nNewEachQTY -- ang01
         END

--         IF CHARINDEX('.', @fConvQTY) > 0
         -- Start Checking for decimal
         SET @nI = CAST(@fConvQTY AS INT) -- (james09)
         IF @nI <> CAST(@fConvQTY AS INT)
         BEGIN
            SET @nErrNo = 66847  --
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INV Qty
            GOTO SKU_Edit_Qty_Fail
         END

         -- Confirmed current record
         SET @nErrNo = 0
         SET @cErrMsg = ''
         IF dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey) <> '0'
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
               @fConvQTY,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT   -- screen limitation, 20 char max
         ELSE
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
               @nConvQTY,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT   -- screen limitation, 20 char max

         IF @nErrNo <> 0
            GOTO SKU_Edit_Qty_Fail

         --IN00137901
         SELECT TOP 1
            @nCaseQty = CASE WHEN PAC.CaseCnt > 0 AND @nConvQTY > 0
                                THEN FLOOR( @nConvQTY / PAC.CaseCnt)
                             ELSE 0 END,
            @nEachQty = CASE WHEN PAC.CaseCnt > 0
                                THEN @nConvQTY % CAST (PAC.CaseCnt AS INT)
                             WHEN PAC.CaseCnt = 0
                                THEN @nConvQTY
                             ELSE 0 END
         FROM dbo.SKU SKU (NOLOCK)
            INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                     WHERE CCKey = @cCCRefNo
                     AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
                     AND LOC = @cLOC
                     AND ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
                     AND Status = '0')  -- Not counted record
         BEGIN
            -- Get next record in current LOC and ID (if any)
            -- Initiate CCDetailKey to blank
            SET @cCCDetailKey = ''
            SET @nRecCnt = 0
            SET @cEmptyRecFlag = ''
            EXECUTE rdt.rdt_CycleCount_GetCCDetail_V7
               @cCCRefNo, @cCCSheetNo, @nCCCountNo,
               @cStorerKey       OUTPUT, -- Shong001
               @cLOC,
               @cID_In,
               @cWithQtyFlag, -- SOS79743
               @cCCDetailKey  OUTPUT,
               @cCountedFlag  OUTPUT,
               @cSKU          OUTPUT,
               @cLOT          OUTPUT,
               @cID           OUTPUT,
               @cLottableCode OUTPUT,
               @cLottable01   OUTPUT, @cLottable02   OUTPUT, @cLottable03   OUTPUT, @dLottable04   OUTPUT, @dLottable05   OUTPUT,
               @cLottable06   OUTPUT, @cLottable07   OUTPUT, @cLottable08   OUTPUT, @cLottable09   OUTPUT, @cLottable10   OUTPUT,
               @cLottable11   OUTPUT, @cLottable12   OUTPUT, @dLottable13   OUTPUT, @dLottable14   OUTPUT, @dLottable15   OUTPUT,
               @nCaseCnt      OUTPUT,
               @nCaseQTY      OUTPUT,
               @cCaseUOM      OUTPUT,
               @nEachQTY      OUTPUT,
               @cEachUOM      OUTPUT,
               @cSKUDescr     OUTPUT,
               @cPPK          OUTPUT,
               @nRecCnt       OUTPUT,
               @cEmptyRecFlag OUTPUT

            SET @cCountedFlag = ''
         END
         ELSE
         BEGIN
           SET @nCntQTY = @nCCDLinesPerLOCID
           SET @cCountedFlag = '[C]'
         END

         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 5, 9, 
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

         -- To cater user edit the same line (sku) for many times
         -- Check current and previous ccdetailkey
         IF @cPrevCCDetailKey <> @cCCDetailKey AND
            @nCntQTY <= @nCCDLinesPerLOCID   -- (jamesxxxxxx)
         BEGIN
            -- Increase counter by 1
            SET @nCntQTY = @nCntQTY + 1
         END
      END

      -- Set to prev variable
      SET @cPrevCCDetailKey = @cCCDetailKey

      SET @cEditSKU = 'Y' -- (Vicky03)

      -- Prepare SKU screen var (Scn 669)
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
      IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorerKey) = '1'
      BEGIN
         SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
         SET @cOutField03 = 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16)
      END
      ELSE
      BEGIN
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
      END

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorerKey) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
      BEGIN
         SET @nErrNo = 66842
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO ID_Fail
      END

      -- If SKUCONFIG setup
      IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
            JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
            WHERE S.StorerKey = @cStorerKey
            AND S.SKU = @cSKU
            AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
         BEGIN
            SET @nErrNo = 66844
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END

         SET @nQTY = 0
         IF ISNULL( @cCCDetailKey, '') <> ''
            -- Get Counted CCDet Lines for a particular LOC + ID
            SELECT TOP 1 @nQTY = CASE WHEN @nCCCountNo = 1 THEN
                                 CASE WHEN Counted_Cnt1 = 0 THEN
                                    CASE WHEN @cWithQtyFlag = 'Y' THEN QTY
                                    WHEN @cWithQtyFlag = 'N' THEN 0
                                    END
                                 WHEN Counted_Cnt1 = 1 THEN QTY
                                 END
                              WHEN @nCCCountNo = 2 THEN QTY_Cnt2
                              WHEN @nCCCountNo = 3 THEN QTY_Cnt3
                              END
            FROM dbo.CCDETAIL (NOLOCK)
            WHERE CCDetailKey = @cCCDetailKey
         ELSE
    -- Get Counted CCDet Lines for a particular LOC + ID
            SELECT TOP 1 @nQTY = CASE WHEN @nCCCountNo = 1 THEN
                                 CASE WHEN Counted_Cnt1 = 0 THEN
                                    CASE WHEN @cWithQtyFlag = 'Y' THEN QTY
                                    WHEN @cWithQtyFlag = 'N' THEN 0
                                    END
                                 WHEN Counted_Cnt1 = 1 THEN QTY
                                 END
                              WHEN @nCCCountNo = 2 THEN QTY_Cnt2
                              WHEN @nCCCountNo = 3 THEN QTY_Cnt3
                        END
            FROM dbo.CCDETAIL (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
            AND LOC = @cLOC
            AND ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
            AND Status < '9'
            ORDER BY [Status], CCDetailKey

         SELECT @c_PackKey = P.PackKey FROM dbo.Pack P WITH (NOLOCK)
         JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
         WHERE S.StorerKey = @cStorerKey
            AND S.SKU = @cSKU

         SELECT @b_success = 0
         EXEC nspUOMCONV
         @n_fromqty    = @nQTY,
         @c_fromuom    = @cEachUOM,
         @c_touom      = @cSKUDefaultUOM,
         @c_packkey    = @c_PackKey,
         @n_toqty      = @f_Qty        OUTPUT,
         @b_Success    = @b_Success    OUTPUT,
         @n_err        = @n_err        OUTPUT,
         @c_errmsg     = @c_errmsg     OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SET @nErrNo = 66843
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CONV FAIL'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END

         IF LTRIM(RTRIM(@cEachUOM)) <> LTRIM(RTRIM(@cSKUDefaultUOM))
         BEGIN
            SET @cOutField04 = CAST( @f_Qty AS NVARCHAR(10))
            SET @cOutField05 = CAST(@cSKUDefaultUOM AS NVARCHAR(10)) + ' ' + @cCountedFlag
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cFieldAttr06 = 'O'
            SET @cFieldAttr07 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField04 = ''
            SET @cOutField05 = CAST('' AS NVARCHAR(10)) + ' ' + @cCountedFlag
            SET @cOutField06 = @f_Qty                     -- QTY (EA)
            SET @cOutField07 = @cEachUOM + @cPPK          -- UOM (EA) + PPK
            SET @cFieldAttr04 = 'O'
            SET @cFieldAttr05 = 'O'
         END
      END
      ELSE
      BEGIN
         SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR( 10))   -- QTY (CS) -- (ChewKP01)
         SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS) + [C]
         SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR( 10))   -- QTY (EA) -- (ChewKP01)
         SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
      END

      -- (james14)-- IN00137901
      SET @cSKUCountDefaultOpt = ''
      SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorerKey)
      IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
         SET @cSKUCountDefaultOpt = ''

      SET @cOutField08 = @cID
      --SET @cOutField09 = @cLottable01
      --SET @cOutField10 = @cLottable02
      --SET @cOutField11 = @cLottable03
      --SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
      --SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
      SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14)  -- IN00137901
--    SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
      SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                              THEN RIGHT( SPACE(4) + CAST( @nCntQTY AS NVARCHAR( 4)), 4)
                              ELSE CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4))
                              END

      -- Go to SKU (Main) screen
      SET @nScn  = @nScn_SKU
      SET @nStep = @nStep_SKU
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

      -- Prepare SKU screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorerKey) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
      BEGIN
         SET @nErrNo = 66842
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO ID_Fail
      END

      -- If SKUCONFIG setup
      IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
      BEGIN
     IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
            JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
            WHERE S.StorerKey = @cStorerKey
            AND S.SKU = @cSKU
            AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
         BEGIN
            SET @nErrNo = 66844
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END

         SET @nQTY = 0
         -- Get Counted CCDet Lines for a particular LOC + ID
         SELECT @nQTY = CASE WHEN @nCCCountNo = 1 THEN
                              CASE WHEN Counted_Cnt1 = 0 THEN
                                 CASE WHEN @cWithQtyFlag = 'Y' THEN QTY
                                 WHEN @cWithQtyFlag = 'N' THEN 0
                                 END
                              WHEN Counted_Cnt1 = 1 THEN QTY
                              END
                           WHEN @nCCCountNo = 2 THEN QTY_Cnt2
                           WHEN @nCCCountNo = 3 THEN QTY_Cnt3
                           END
         FROM dbo.CCDETAIL (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
         AND LOC = @cLOC
         AND ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
         AND Status < '9'

         SELECT @c_PackKey = P.PackKey FROM dbo.Pack P WITH (NOLOCK)
         JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
         WHERE S.StorerKey = @cStorerKey
            AND S.SKU = @cSKU

         SELECT @b_success = 0
         EXEC nspUOMCONV
         @n_fromqty    = @nQTY,
         @c_fromuom    = @cEachUOM,
         @c_touom      = @cSKUDefaultUOM,
         @c_packkey    = @c_PackKey,
         @n_toqty      = @f_Qty        OUTPUT,
         @b_Success    = @b_Success    OUTPUT,
         @n_err        = @n_err        OUTPUT,
         @c_errmsg     = @c_errmsg     OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SET @nErrNo = 66843
    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CONV FAIL'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END

   IF LTRIM(RTRIM(@cEachUOM)) <> LTRIM(RTRIM(@cSKUDefaultUOM))
         BEGIN
            SET @cOutField04 = CAST( @f_Qty AS NVARCHAR(10))
            SET @cOutField05 = CAST(@cSKUDefaultUOM AS NVARCHAR(10)) + ' ' + @cCountedFlag
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cFieldAttr06 = 'O'
            SET @cFieldAttr07 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField04 = ''
            SET @cOutField05 = CAST('' AS NVARCHAR(10)) + ' ' + @cCountedFlag
            SET @cOutField06 = @f_Qty                        -- QTY (EA)
            SET @cOutField07 = @cEachUOM + @cPPK          -- UOM (EA) + PPK
            SET @cFieldAttr04 = 'O'
            SET @cFieldAttr05 = 'O'
         END
      END
      ELSE
      BEGIN
         SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR( 10))   -- QTY (CS) -- (ChewKP01)
         SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS)
         SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR( 10))   -- QTY (EA) -- (ChewKP01)
         SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
      END

      -- (james14)
      SET @cSKUCountDefaultOpt = ''
      SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorerKey)
      IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
         SET @cSKUCountDefaultOpt = ''

      SET @cOutField08 = @cID
      --SET @cOutField09 = @cLottable01
      --SET @cOutField10 = @cLottable02
      --SET @cOutField11 = @cLottable03
      --SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
      --SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
      SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14)
--    SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
      SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorerKey) = 1
                              THEN RIGHT( SPACE(4) + CAST( @nCntQTY AS NVARCHAR( 4)), 4)
                              ELSE CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4))
                              END

      -- Go to SKU (Main) screen
      SET @nScn  = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
   GOTO Quit

   SKU_Edit_Qty_Fail:
   BEGIN
     SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey)
      IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
      BEGIN
         IF LTRIM(RTRIM(@cEachUOM)) <> LTRIM(RTRIM(@cSKUDefaultUOM))
         BEGIN
            SET @cOutField04 = CAST( @f_Qty AS NVARCHAR(10))
            SET @cOutField05 = CAST(@cSKUDefaultUOM AS NVARCHAR(10)) + ' ' + @cCountedFlag
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cFieldAttr06 = 'O'
            SET @cFieldAttr07 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField04 = ''
            SET @cOutField05 = CAST('' AS NVARCHAR(10)) + ' ' + @cCountedFlag
            SET @cOutField06 = @f_Qty                     -- QTY (EA)
            SET @cOutField07 = @cEachUOM + @cPPK          -- UOM (EA) + PPK
            SET @cFieldAttr04 = 'O'
            SET @cFieldAttr05 = 'O'
         END
      END
   END
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
      V_Lottable06   = @cLottable06,  
      V_Lottable07   = @cLottable07, 
      V_Lottable08   = @cLottable08, 
      V_Lottable09   = @cLottable09, 
      V_Lottable10   = @cLottable10, 
      V_Lottable11   = @cLottable11, 
      V_Lottable12   = @cLottable12,  
      V_Lottable13   = @dLottable13,
      V_Lottable14   = @dLottable14,
      V_Lottable15   = @dLottable15,

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
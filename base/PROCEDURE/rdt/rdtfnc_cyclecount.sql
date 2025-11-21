SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_CycleCount                                   */
/* Copyright      : MAERSK                                              */
/*                                                                      */
/* Purpose: Cycle Count for:                                            */
/*          1. UCC                                                      */
/*          2. Normal Cycle Count                                       */
/*          3. Single SKU Scan                                          */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 26-May-2006 1.0  MaryVong Created                                    */
/* 28-Sep-2006 1.1  MaryVong SOS57609 Enhancement: JulianDate lottables */
/* 17-Oct-2006 1.2  MaryVong Add @cWithQtyFlag                          */
/* 19-Oct-2006 1.3  MaryVong Allow UCC.Qty <> CaseCnt if turn on RDT    */
/*                           storerconfig "UCCWithDynamicCaseCNT"       */
/* 24-Nov-2006 1.4  MaryVong Default Lottable05 = TodayDate if having   */
/*                           Lottable05Label = "RCP_DATE"               */
/* 04-Dec-2006 1.5  MaryVong Allow to add SKU with empty ID             */
/* 14-Dec-2006 1.6  MaryVong Do not allow to overwrite suggested LOC    */
/* 24-Apr-2007 1.7  MaryVong Slightly modify JulianDate format          */
/* 30-Apr-2007 1.8  MaryVong Initialize @cSuggestLogiLOC                */
/* 12-Jun-2007 1.9  MaryVong Modified SuggestLogiLOC to NVARCHAR(18)    */
/* 05-Jul-2007 1.10 MaryVong SOS79743 Cater double deep location:       */
/*                           If ID is blank, retrieve all data in the   */
/*                           particular location                        */
/* 19-Nov-2007 1.11 Shong    Check StockTakeSheetParameters.StorerKey   */
/*                           instead of CCDETAIL.StorerKey. Records Not */
/*                           Found when generate blank count sheet.     */
/* 04-Dec-2007 1.12 Vicky    SOS#81879 - Add generic Lottable_Wrapper   */
/* 03-Nov-2008 1.13 Vicky    Remove XML part of code that is used to    */
/*                           make field invisible and replace with new  */
/*                           code (Vicky02)                             */
/* 18-May-2009 1.14 Leong    SOS136921 - Reset variable if sku is blank */
/* 20-May-2009 1.15 MaryVong SOS128449 & 133966                         */
/*                           1) Cater for Single SKU Scanning           */
/*                           2) Allow Override location, Add location   */
/*                           3) Allow to recount qty in same location   */
/*                           4) If no SheetNo entered, allow cycle count*/
/*                              by Zones, Aisle or Level                */
/*                           5) Create RDTCCLock table for data locking */
/*                           6) Re-code SOS#81879 to sub-stored proc    */
/*                              (MaryVong01)                            */
/* 13-Jul-2009 1.16 Vicky    Bug Fix (Vicky03)                          */
/* 27-Jul-2009      Leong    SOS# 143022 - Add TraceInfo to track       */
/*                           CC option                                  */
/* 01-Aug-2009 1.17 James    Bug Fix (james01)                          */
/* 18-Aug-2009 1.18 James    SOS144306 - Bug fix (james02)              */
/* 04-Oct-2009 1.19 James    Take out lottable05 from single SKU scan   */
/*                           SOS149946 - Bug fix (james03)              */
/* 24-Mar-2010 1.20 James    Change screen no from 680 to 700 because   */
/*                           crashed with UCC outbound verify (james04) */
/* 30-Mar-2010 1.21 James    SOS166769 - Add configkey InsCCLockAtLOCScn*/
/*                           to control RDTCCLock insertion (james05)   */
/* 11-May-2010 1.22 James    Bug fix. CCDetail must populated with      */
/*                           correct count no (james06)                 */
/* 25-May-2010 1.21 James    SOS173957 - Add configkey to control       */
/*                           whether display DESCR or upc (james07)     */
/* 02-Jul-2010 1.21 Leong    SOS# 179935 - Bug fix                      */
/* 19-Oct-2010      Shong    Bug fixed                                  */
/* 24-Nov-2010 1.22 ChewKP   SOS#197477 Edit Qty length = 10(ChewKP01)  */
/* 02-Feb-2011 1.23 James    SOS#201672 - Allow Qty in Decimal Points   */
/*                           (james08)                                  */
/* 28-Jun-2011 1.24 Audrey   SOS#219682 - Bug fixed. Missing variable   */
/*                           passing                             (ang01)*/
/* 01-Jul-2011 1.25 James    SOS220133 & SOS220135 - Bug fix (james09)  */
/* 12-Sep-2011 1.26 TLTING   Turn OFF TraceInfo                         */
/* 22-Dec-2011 1.27 Ung      SOS231818 Handle empty LOC no StorerKey    */
/* 07-Jan-2012 1.5  Shong001 Allow RDT Count by Multiple Storer         */
/* 03-Feb-2012 1.6  Ung      SOS235498 support edit UCC.QTY             */
/* 11-May-2012 1.6  Shong002 Default StorerKey if it's Blank            */
/* 04-Aug-2012 1.7  Shong003 Do not display qty if CCNOTSHOWSYSQTY On   */
/* 05-Aug-2012 1.8  ChewKP   Do not display qty in Edit Opt when        */
/*                           CCNOTSHOWSYSQTY on (ChewKP02)              */
/* 09-Oct-2012 1.9  James    SOS254690 - Blind Count (james10)          */
/* 18-Mar-2013 2.0  James    Bug fix (james11)                          */
/* 25-May-2013 2.1  Ung      SOS276721 Fix SKU UPC > 20 chars (ung01)   */
/* 27-Sep-2013 2.2  James    SOS289160-Fix ID count cannot esc (james12)*/
/* 18-Oct-2013 2.3  James    SOS292247-Confirm loc count when press esc */
/*                           and display next available loc (james13)   */
/* 26-Feb-2014 2.4  James    SOS303558-Default opt on count by sku      */
/*                           screen (james14)                           */
/* 10-Mar-2014 2.5  James    SOS302894 - Add sku & lottables validation */
/*                           screen (james15)                           */
/* 16-Dec-2013 2.6  ChewKP   SOS#297550 - Fixes when Loc all counted    */
/*                           prompt error (ChewKP03)                    */
/* 07-May-2014 2.7  James    Bug fix (james16)                          */
/* 26-Jun-2014 2.8  James    SOS#314805 - Bug fix (james17)             */
/* 13-Oct-2014 2.9  James    SOS320895 - Add decode label (james18)     */
/* 26-Dec-2014 3.0  James    SOS329361 - Extend UOM to 10 char (james19)*/
/* 02-Jan-2015 3.1  Ung      SOS329875 Fix retrieved wrong QTY if LOC   */
/*                           contain multiple CCDetail                  */
/* 15-Jan-2015 3.2  James    SOS329875 - Add Top 1 to cater 1 loc, multi*/
/*                           lot, same sku scenario (james20)           */
/* 16-Dec-2015 3.3  Richard  SOS359218 - Bug fix.                       */
/* 29-Feb-2016 3.4  ChewKP   SOS#364350 - Retain CCOption Selection     */
/*            (ChewKP04)                                 */
/* 18-Jul-2016 3.5  James    SOS373446 - Add decodesp (james21)         */
/* 05-Sep-2016 3.6  James    IN00137901 - Bug fix.                      */
/* 26-Oct-2016 3.7  James    Perf tuning (james22)                      */
/* 28-Oct-2016 3.8  James    Change isDate to rdtIsValidDate (james23)  */
/* 01-Nov-2016 3.9  Leong    IN00187400 - Reset Counted_Cnt(x).         */
/* 03-Oct-2018 4.0  Gan      Performance tuning                         */
/* 02-Nov-2018 4.1  James    WMS-6809 - Fix curLogicalLoc bug (james23) */
/* 11-Jul-2019 4.2  James    WMS-9681 - Add rdt_Decode to ID (james24)  */
/* 11-Jun-2019 4.3  YeeKung  WMS-9385 LMF VF RDT Enhancement (yeekung01)*/
/* 15-Sep-2019 4.4  YeeKung  WMS-10467 Add Std EventLog      (yeekung02)*/
/* 22-Oct-2019 4.5  Chermaine WMS-10918 Add Std EventLog (cc01)         */
/* 18-Dec-2019 4.6  James    WMS-11420 show totalcase/casecnt (james25) */
/* 05-Feb-2020 4.7  James    WMS-11865 Add ExtendedInfo @ Qty screen    */
/*                           Add config to skip ID screen when ESC from */
/*                           scan sku screen (james26)                  */
/* 09-Jul-2020 4.8  Chermaine WMS-14169 Add Std EventLog (cc02)         */
/* 07-Apr-2021 4.9  James    WMS-16665 Allow add valid ucc but not in   */
/*                           current loc (james27)                      */
/* 15-Jul-2021 5.0  Ung      WMS-17017 Add AdHoc cycle count            */
/* 17-Nov-2021 5.1  James    WMS-18175 Add enhancement on processing on */
/*                           DoubleDeep loc (james28)                   */
/* 08-Dec-2021 5.2  James    WMS-18486 Add config to skip ID/Opt screen */
/*                           Add ExtendedUpdateSP (james29)             */
/* 04-Apr-2022 5.3  SYChua   JSM-60459 - Bug fix reset DoubleDeep       */
/*                           config (SY01)                              */
/* 06-Sep-2022 5.4  James    WMS-20691 Add flowthru from step 8 to      */
/*                           step 17 (bypass step 13) (james30)         */
/*                           Add check digit format at step Qty         */
/*                           Add config step 17 must key in qty         */
/* 07-Dec-2022 5.5  James    WMS-21288 Extend SKU length, add output    */
/*                           Qty for decodesp (james31)                 */
/* 05-Sep-2023 5.6  James    WMS-23451 Add standard UCC decode (james32)*/
/* 01-Aug-2024 5.7  NLT013   UWP-22515 Fix the issue:Keep Lottables     */
/*                           does not work                              */
/* 19-Nov-2024 5.8.0 NLT013  UWP-27188 Merge code, map @v_Barcode to @cUCC  */
/************************************************************************/
CREATE   PROC [RDT].[rdtfnc_CycleCount] (
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

   @cStorer           NVARCHAR( 15),
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

   @cCCRefNo          NVARCHAR( 10),
   @cCCSheetNo        NVARCHAR( 10),
   @nCCCountNo        INT,
   @cSuggestLOC       NVARCHAR( 10),
   @cSuggestLogiLOC   NVARCHAR( 18),
   @nCntQTY     INT,
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
   @cCheckStorer      NVARCHAR(15)   -- (Shong001)

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
   @cCountType       NVARCHAR( 10),     -- (james10)
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
   @cExtendedInfo          NVARCHAR( 20),  -- (james26)
   @cExtendedInfoSP        NVARCHAR( 20),  -- (james26)
   @nAfterStep             INT,            -- (james26)
   @tExtValidate           VARIABLETABLE,  -- (james26)
   @cSkipIDScn             NVARCHAR( 1),   -- (james26)
   @cAllowAddUCCNotInLocSP NVARCHAR( 20),  -- (james27)
   @cSingleSKUDefLottableOpt  NVARCHAR( 1),-- (james27)
   @cDoubleDeep            NVARCHAR( 1),   -- (james28)
   @nTtlID_Count           INT,            -- (james28)
   @nID_Count              INT,            -- (james28)
   @tExtUpdate             VARIABLETABLE,  -- (james29)
   @cExtendedUpdateSP      NVARCHAR( 20),  -- (james29)
   @cExtendedValidSP       NVARCHAR( 20),  -- (CYU027)
   @cPUOM                  NVARCHAR(  1),
   @nPUOM_Div              INT,
   @nPQTY                  INT,
   @nMQTY                  INT,
   @cExtendedScreenSP   NVARCHAR( 20),
   @nAction             INT,
   @nAfterScn           INT,
   @cLocNeedValid       NVARCHAR( 20),
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
   @cIDBarcode          NVARCHAR( 60),
   @cBarcode            NVARCHAR( MAX),
   @cUPC                NVARCHAR( 30),
   @cFromID             NVARCHAR( 18),
   @cToLOC              NVARCHAR( 10),
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
   @cUserDefine01       NVARCHAR( 60),
   @cUserDefine02       NVARCHAR( 60),
   @cUserDefine03       NVARCHAR( 60),
   @cUserDefine04       NVARCHAR( 60),
   @cUserDefine05       NVARCHAR( 60),
   @cSKUCode            NVARCHAR( 20),
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @cShowCaseCnt        NVARCHAR( 1),
   @cNewSKUSetFocusAtEA NVARCHAR( 1),
   @cAdHocGenCCSP       NVARCHAR( 20),
   @cCountTypeUCCSpecialHandling NVARCHAR( 1) = '0'

DECLARE @cStepSKUAllowOpt     NVARCHAR( 1)
DECLARE @cFlowThruStepSKU     NVARCHAR( 1)
DECLARE @cSKUEditQTYNotAllowBlank   NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc             = Func,
   @nScn              = Scn,
   @nStep             = Step,
   @nInputKey         = InputKey,
   @nMenu             = Menu,
   @cLangCode         = Lang_code,

   @cStorer           = StorerKey,
   @cFacility         = Facility,
   @cUserName         = UserName,
   @cLOC              = V_LOC,
   @cID               = V_ID,
   @cLOT              = V_LOT,
   @cSKU              = V_SKU,
   @cSKUDescr         = V_SKUDescr,
   @cUOM              = V_UOM,
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
   @nNoOfTry          = V_Integer15,

   @dNewLottable04    = V_DateTime1,
   @dNewLottable05    = V_DateTime2,

   @cCCRefNo          = V_String1,
   @cCCSheetNo        = V_String2,
   @cShowCaseCnt      = V_String3,
   @cSuggestLOC       = V_String4,
   @cSuggestLogiLOC   = V_String5,
   @cExtendedInfoSP   = V_String6,
   @cNewSKUSetFocusAtEA = V_String7,
   @cStatus           = V_String8,
   @cPPK              = V_String9,
   @cSheetNoFlag      = V_String10, -- (MaryVong01)
   @cLocType          = V_String11,
   @cCCDetailKey      = V_String12,
   @cSkipIDScn        = V_String13,
   @cCaseUOM          = V_String16,
   @cExtendedUpdateSP = V_String17,
   @cEachUOM          = V_String18,
   @cLastLocFlag      = V_String19, -- (MaryVong01)
   @cDefaultCCOption  = V_String20,

   @cCountedFlag      = V_String21,
   @cWithQtyFlag      = V_String22,
   @cNewUCC           = V_String23,
   @cNewSKU           = V_String24,
   @cNewSKUDescr1     = V_String25,
   @cNewSKUDescr2     = V_String26,
   @cDoubleDeep       = V_String27,
   @cNewCaseUOM       = V_String30,
   @cNewEachUOM       = V_String32,
   @cNewPPK           = V_String33,
   @cNewLottable01    = V_String34,
   @cNewLottable02    = V_String35,
   @cNewLottable03    = V_String36,
   @cAddNewLocFlag    = V_String39,     -- (MaryVong01)
   @cID_In            = V_String40,     -- SOS79743
   @cRecountFlag      = V_ReceiptKey,   -- (MaryVong01) - Used for Recount
   @cPrevCCDetailKey  = V_LoadKey,      -- (MaryVong01) - Used to control Counter in SKU screen
   @cEditSKU          = V_PickSlipNo, -- (Vicky03)
   @cBlindCount       = V_ConsigneeKey,    -- (james10)
   @cCurSuggestLogiLOC = V_String41,
   @cOptAction         = V_String42,
   @cAllowAddUCCNotInLocSP = V_String43,
   @cCountTypeUCCSpecialHandling = V_String44,
   @cFlowThruStepSKU  = V_String45,
   @cSKUEditQTYNotAllowBlank = V_String46,
   @cStepSKUAllowOpt         = V_String47,
   @cExtendedValidSP = V_String48,
   @cBarcode         = V_Barcode,
    
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
   --@nStep_SheetNo                  INT,  @nScn_SheetNo                  INT,
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
   @nStep_UCC_Edit_QTY             INT,  @nScn_UCC_Edit_QTY             INT,
   @nStep_SKU                      INT,  @nScn_SKU                      INT,
   @nStep_SKU_Add_Sku              INT,  @nScn_SKU_Add_Sku              INT,
   @nStep_SKU_Add_Qty              INT,  @nScn_SKU_Add_Qty              INT,
   @nStep_SKU_Add_Lottables        INT,  @nScn_SKU_Add_Lottables        INT,
   @nStep_SKU_Edit_Qty             INT,  @nScn_SKU_Edit_Qty             INT,
   @nStep_SINGLE_SKU_Sku_Scan      INT,  @nScn_SINGLE_SKU_Sku_Scan      INT, -- (MaryVong01)
   @nStep_SINGLE_SKU_Add_Lottables INT,  @nScn_SINGLE_SKU_Add_Lottables INT, -- (MaryVong01)
   @nStep_SINGLE_SKU_Increase_Qty  INT,  @nScn_SINGLE_SKU_Increase_Qty  INT, -- (MaryVong01)
  @nStep_SINGLE_SKU_Option        INT,  @nScn_SINGLE_SKU_Option        INT,  -- (MaryVong01)

   @nStep_SINGLE_SKU_Lottables_Option        INT,  @nScn_SINGLE_SKU_Lottables_Option        INT,
   @nStep_SINGLE_SKU_EndCount_Option         INT,  @nScn_SINGLE_SKU_EndCount_Option         INT,
   @nStep_ID_CartonCount                     INT,  @nScn_ID_CartonCount                     INT,   -- (james10)
   @nStep_Blind_Sku                          INT,  @nScn_Blind_Sku                          INT,   -- (james10)
   @nStep_Blind_Qty                          INT,  @nScn_Blind_Qty                          INT,   -- (james10)
   @nStep_Blind_Lottables                    INT,  @nScn_Blind_Lottables                    INT,   -- (james10)
   @nStep_Validate_SKULottables              INT,  @nScn_Validate_SKULottables              INT    -- (james15)

SELECT
   @nStep_CCRef                    = 1,  @nScn_CCRef                    = 660,
   @nStep_SheetNo_Criteria         = 2,  @nScn_SheetNo_Criteria         = 661, -- (MaryVong01)
   @nStep_CountNo                  = 3,  @nScn_CountNo                  = 662,
   @nStep_LOC                      = 4,  @nScn_LOC   = 663,
   @nStep_LOC_Option               = 5,  @nScn_LOC_Option               = 664, -- (MaryVong01)
   @nStep_LAST_LOC_Option          = 6,  @nScn_LAST_LOC_Option          = 665, -- (MaryVong01)
   @nStep_RECOUNT_LOC_Option       = 7,  @nScn_RECOUNT_LOC_Option       = 666, -- (MaryVong01)
   @nStep_ID                       = 8,  @nScn_ID                       = 667,
   -- UCC
   @nStep_UCC                      = 9,  @nScn_UCC                      = 668,
   @nStep_UCC_Add_Ucc              = 10, @nScn_UCC_Add_Ucc              = 669,
   @nStep_UCC_Add_SkuQty           = 11, @nScn_UCC_Add_SkuQty           = 670,
   @nStep_UCC_Add_Lottables        = 12, @nScn_UCC_Add_Lottables        = 671,
   @nStep_UCC_Edit_QTY             = 24, @nScn_UCC_Edit_QTY             = 703,
   -- SKU
   @nStep_SKU                      = 13, @nScn_SKU                      = 672,
   @nStep_SKU_Add_Sku              = 14, @nScn_SKU_Add_Sku              = 673,
   @nStep_SKU_Add_Qty              = 15, @nScn_SKU_Add_QTY              = 674,
   @nStep_SKU_Add_Lottables        = 16, @nScn_SKU_Add_Lottables        = 675,
   @nStep_SKU_Edit_Qty             = 17, @nScn_SKU_Edit_Qty             = 676,
   -- SINGLE SKU
   @nStep_SINGLE_SKU_Sku_Scan      = 18, @nScn_SINGLE_SKU_Sku_Scan      = 677, -- (MaryVong01)
   @nStep_SINGLE_SKU_Add_Lottables = 19, @nScn_SINGLE_SKU_Add_Lottables = 678, -- (MaryVong01)
   @nStep_SINGLE_SKU_Increase_Qty  = 20, @nScn_SINGLE_SKU_Increase_Qty  = 679, -- (MaryVong01)
-- @nStep_SINGLE_SKU_Option        = 21, @nScn_SINGLE_SKU_Option        = 680, -- (MaryVong01)
   @nStep_SINGLE_SKU_Option        = 21, @nScn_SINGLE_SKU_Option        = 700, -- (james04)

   @nStep_SINGLE_SKU_Lottables_Option = 22, @nScn_SINGLE_SKU_Lottables_Option = 701,   -- (james04)
   @nStep_SINGLE_SKU_EndCount_Option  = 23, @nScn_SINGLE_SKU_EndCount_Option  = 702,   -- (james04)

   @nStep_ID_CartonCount              = 25, @nScn_ID_CartonCount              = 3260,  -- (james10)
   @nStep_Blind_Sku                   = 26, @nScn_Blind_Sku                   = 3261,  -- (james10)
   @nStep_Blind_Qty                   = 27, @nScn_Blind_Qty                   = 3262,  -- (james10)
   @nStep_Blind_Lottables             = 28, @nScn_Blind_Lottables             = 3263,  -- (james10)
   @nStep_Validate_SKULottables       = 29, @nScn_Validate_SKULottables       = 3264   -- (james15)


IF @nFunc = 610 -- RDT Cycle Count
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start                    -- Menu. Func = 610
   IF @nStep = 1  GOTO Step_CCRef                    -- Scn = 660. CCREF
   IF @nStep = 2  GOTO Step_SheetNo_Criteria         -- Scn = 661. SHEET NO OR Selection Criteria
   IF @nStep = 3  GOTO Step_CountNo                  -- Scn = 662. COUNT NO
   IF @nStep = 4  GOTO Step_LOC                      -- Scn = 663. LOC
   IF @nStep = 5  GOTO Step_LOC_Option               -- Scn = 664. LOC - Option
   IF @nStep = 6  GOTO Step_LAST_LOC_Option          -- Scn = 665. Last LOC - Option
   IF @nStep = 7  GOTO Step_RECOUNT_LOC_Option       -- Scn = 666. Re-Count LOC - Option
   IF @nStep = 8  GOTO Step_ID                       -- Scn = 667. ID
   IF @nStep = 9  GOTO Step_UCC            -- Scn = 668. UCC
   IF @nStep = 10 GOTO Step_UCC_Add_Ucc    -- Scn = 669. UCC - Add UCC
   IF @nStep = 11 GOTO Step_UCC_Add_SkuQty           -- Scn = 670. UCC - Add SKU & QTY
   IF @nStep = 12 GOTO Step_UCC_Add_Lottables        -- Scn = 671. UCC - Add LOTTABLE01..05
   IF @nStep = 24 GOTO Step_UCC_Edit_QTY             -- Scn = 703. UCC - Edit QTY
   IF @nStep = 13 GOTO Step_SKU                      -- Scn = 672. SKU
   IF @nStep = 14 GOTO Step_SKU_Add_Sku              -- Scn = 673. SKU - Add SKU/UPC
   IF @nStep = 15 GOTO Step_SKU_Add_Qty              -- Scn = 674. SKU - Add QTY
   IF @nStep = 16 GOTO Step_SKU_Add_Lottables        -- Scn = 675. SKU - Add LOTTABLE01..05
   IF @nStep = 17 GOTO Step_SKU_Edit_Qty             -- Scn = 676. SKU - Edit QTY
   IF @nStep = 18 GOTO Step_SINGLE_SKU_Sku_Scan      -- Scn = 677. SINGLE SKU - Sku Scan
   IF @nStep = 19 GOTO Step_SINGLE_SKU_Add_Lottables -- Scn = 678. SINGLE SKU - Add Lottables
   IF @nStep = 20 GOTO Step_SINGLE_SKU_Increase_Qty  -- Scn = 679. SINGLE SKU - Increase Qty
   IF @nStep = 21 GOTO Step_SINGLE_SKU_Option        -- Scn = 700. SINGLE SKU - Option
   IF @nStep = 22 GOTO Step_SINGLE_SKU_Lottables_Option -- Scn = 701. SINGLE SKU Lottables - Option
   IF @nStep = 23 GOTO Step_SINGLE_SKU_EndCount_Option  -- Scn = 702. SINGLE SKU End Count - Option
   IF @nStep = 25 GOTO Step_ID_CartonCount              -- Scn = 3260. ID Carton Count             -- (james10)
   IF @nStep = 26 GOTO Step_Blind_Sku                   -- Scn = 3261. Blind Count SKU             -- (james10)
   IF @nStep = 27 GOTO Step_Blind_Qty                   -- Scn = 3262. Blind Count Qty             -- (james10)
   IF @nStep = 28 GOTO Step_Blind_Lottables             -- Scn = 3268. Blind Count Lottables       -- (james10)
   IF @nStep = 29 GOTO Step_Validate_SKULottables       -- Scn = 3264. Blind Count Lottables       -- (james15)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 610. Screen 0.
********************************************************************************/
Step_Start:
BEGIN
   -- Clear the incomplete task for the same login
   DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
   WHERE AddWho = @cUserName
   AND Status = '0'

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog   --(yeekung01)
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorer,
     @nStep       = @nStep

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorer)
   IF @cExtendedInfoSP IN ('0', '')
      SET @cExtendedInfoSP = ''

   SET @cNewSKUSetFocusAtEA = rdt.RDTGetConfig( @nFunc, 'NewSKUSetFocusAtEA', @cStorer)
   SET @cSkipIDScn = rdt.RDTGetConfig( @nFunc, 'SkipIDScn', @cStorer)

   SET @cAllowAddUCCNotInLocSP = rdt.RDTGetConfig( @nFunc, 'AllowAddUCCNotInLocSP', @cStorer)
   IF @cAllowAddUCCNotInLocSP IN ('0', '')
      SET @cAllowAddUCCNotInLocSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorer)
   IF @cExtendedUpdateSP IN ('0', '')
      SET @cExtendedUpdateSP = ''

   SET @cExtendedValidSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidSP', @cStorer)
   IF @cExtendedValidSP IN ('0', '')
      SET @cExtendedValidSP = ''

   --SY01 START
   SET @cDoubleDeep = rdt.RDTGetConfig( @nFunc, 'DoubleDeep', @cStorer)
   IF @cDoubleDeep IN ('0', '')
      SET @cDoubleDeep = ''
   --SY01 END

   SET @cFlowThruStepSKU = rdt.RDTGetConfig( @nFunc, 'FlowThruStepSKU', @cStorer)
   IF @cFlowThruStepSKU = '0'
      SET @cFlowThruStepSKU = ''

   SET @cSKUEditQTYNotAllowBlank = rdt.RDTGetConfig( @nFunc, 'SKUEditQTYNotAllowBlank', @cStorer)
   IF @cSKUEditQTYNotAllowBlank = '0'
      SET @cSKUEditQTYNotAllowBlank = ''

   SET @cStepSKUAllowOpt = rdt.RDTGetConfig( @nFunc, 'StepSKUAllowOpt', @cStorer)
   IF @cStepSKUAllowOpt = '0'
      SET @cStepSKUAllowOpt = ''

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
      @cOutField10   = '',
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

      -- AdHoc cycle count
      SET @cAdHocGenCCSP = rdt.RDTGetConfig( @nFunc, 'AdHocGenCCSP', @cStorer)
      IF @cAdHocGenCCSP NOT IN ('0', '')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAdHocGenCCSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cAdHocGenCCSP) +
              ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
              ' @cCCRefNo, @cLOC, @cCCSheetNo OUTPUT, @nCCCountNo OUTPUT, @cSuggestLOC OUTPUT, @cSuggestLogiLOC OUTPUT,' +
              ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile         INT,           ' +
               ' @nFunc           INT,           ' +
               ' @cLangCode       NVARCHAR( 3),  ' +
               ' @nStep           INT,           ' +
               ' @nInputKey       INT,           ' +
               ' @cFacility       NVARCHAR( 5),  ' +
               ' @cStorerKey      NVARCHAR( 15), ' +
               ' @cCCRefNo        NVARCHAR( 10), ' +
               ' @cLOC            NVARCHAR( 10), ' +
               ' @cCCSheetNo      NVARCHAR( 10) OUTPUT, ' +
               ' @nCCCountNo      INT           OUTPUT, ' +
               ' @cSuggestLOC     NVARCHAR( 10) OUTPUT, ' +
               ' @cSuggestLogiLOC NVARCHAR( 18) OUTPUT, ' +
               ' @nErrNo          INT           OUTPUT, ' +
               ' @cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer,
               @cCCRefNo, @cLOC, @cCCSheetNo OUTPUT, @nCCCountNo OUTPUT, @cSuggestLOC OUTPUT, @cSuggestLogiLOC OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0  AND
               @nErrNo <> -1
               GOTO CCRef_Fail

            SELECT
               @cWithQtyFlag = WithQuantity
            FROM dbo.StockTakeSheetParameters (NOLOCK)
            WHERE StockTakeKey = @cCCRefNo

            -- AdHoc CCRef
            IF @nErrNo = 0
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = @cCCRefNo
               SET @cOutField02 = @cCCSheetNo
               SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
               SET @cOutField04 = '' -- @cSuggestLOC
               SET @cOutField05 = '' -- @cLOC
               SET @cOutField06 = '' -- @nCCDLinesPerLOC

               -- Go to LOC screen
               SET @nScn = @nScn_LOC
               SET @nStep = @nStep_LOC

               GOTO Quit
            END

            -- Normal CCRef, passing thru
            IF @nErrNo = -1
               SET @nErrNo = 0   -- Reset error
         END
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

      -- EventLog - Sign Out Function (yeekung01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorer,
         @nStep       = @nStep


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
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
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
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
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
              ' @tExtValidate, @cExtendedInfo OUTPUT '
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
            ' @tExtValidate   VariableTable READONLY, ' +
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorer,
            @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel,
            @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @tExtValidate, @cExtendedInfo OUTPUT

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
      IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
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

     EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
            @cFacility,
            '',   -- current CCLogicalLOC is blank
            @cSuggestLogiLOC OUTPUT,
            @cSuggestLOC OUTPUT,
            @nCCCountNo,
            @cUserName  -- (james05)

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

         EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
            @cFacility,
            '',   -- current CCLogicalLOC is blank
            @cSuggestLogiLOC OUTPUT,
            @cSuggestLOC OUTPUT,
            @nCCCountNo,
            @cUserName  -- (james05)
      END

      -- Get StorerConfig 'OverrideLOC' (MaryVong01)
      SET @cOverrideLOCConfig = rdt.RDTGetConfig( @nFunc, 'OverrideLOC', @cStorer)

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
      SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END

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
--    Values ('rdtfnc_CycleCount', GetDate(), '663 Scn4', '1', @cUserName, @cCCRefNo, @cCCSheetNo)
--  END

   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      IF @cLOC = @cOutField04
         SET @nLOCConfirm = 1
      ELSE
         SET @nLOCConfirm = 0

      -- Screen mapping
      SET @cLOC = @cInField05
      SET @cLocNeedValid = @cInField05

      -- Retain the key-in value
      SET @cOutField05 = @cLOC

      -- Get StorerConfig 'OverrideLOC' (MaryVong01)
      SET @cOverrideLOCConfig = rdt.RDTGetConfig( @nFunc, 'OverrideLOC', @cStorer)

      -- Get StorerConfig 'DefaultCCOption'
      -- (ChewKP04)
      IF ISNULL(@cDefaultCCOption,'' ) IN  ( '','0' )
      BEGIN
         SET @cDefaultCCOption = rdt.RDTGetConfig( @nFunc, 'DefaultCCOption', @cStorer)
      END


      IF @cDefaultCCOption = '0' -- Default Option not setup
         SET @cDefaultCCOption = ''

      -- AdHoc cycle count
      SET @cAdHocGenCCSP = rdt.RDTGetConfig( @nFunc, 'AdHocGenCCSP', @cStorer)
      IF @cAdHocGenCCSP NOT IN ('0', '')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAdHocGenCCSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cAdHocGenCCSP) +
              ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
              ' @cCCRefNo, @cLOC, @cCCSheetNo OUTPUT, @nCCCountNo OUTPUT, @cSuggestLOC OUTPUT, @cSuggestLogiLOC OUTPUT,' +
              ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile         INT,           ' +
               ' @nFunc           INT,           ' +
               ' @cLangCode       NVARCHAR( 3),  ' +
               ' @nStep           INT,           ' +
               ' @nInputKey       INT,           ' +
               ' @cFacility       NVARCHAR( 5),  ' +
               ' @cStorerKey      NVARCHAR( 15), ' +
               ' @cCCRefNo        NVARCHAR( 10), ' +
               ' @cLOC            NVARCHAR( 10), ' +
               ' @cCCSheetNo      NVARCHAR( 10) OUTPUT, ' +
               ' @nCCCountNo      INT           OUTPUT, ' +
               ' @cSuggestLOC     NVARCHAR( 10) OUTPUT, ' +
               ' @cSuggestLogiLOC NVARCHAR( 18) OUTPUT, ' +
               ' @nErrNo          INT           OUTPUT, ' +
               ' @cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer,
               @cCCRefNo, @cLOC, @cCCSheetNo OUTPUT, @nCCCountNo OUTPUT, @cSuggestLOC OUTPUT, @cSuggestLogiLOC OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO LOC_Fail
         END
      END

      -- (james10)
      -- if rdt storerconfig turned on and loc.loseid = '1' & loc.loseucc = '1'
      -- then set as blind count (no show sku & qty)
      SET @cBlindCount = ''
      IF rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1'
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
         IF rdt.RDTGetConfig( @nFunc, 'NOTALLOWSKIPSUGGESTLOC', @cStorer) = '1'
         BEGIN
            SET @nErrNo = 77713
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC REQUIRED'
            GOTO LOC_Fail
         END

         GETNEXT_LOC:
         -- If configkey not turned on (james05)
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
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
            EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
               @cFacility,
               @cCurSuggestLogiLOC, -- current CCLogicalLOC
               @cSuggestLogiLOC  OUTPUT,
               @cSuggestLOC      OUTPUT,
               @nCCCountNo,
               @cUserName  -- (james05)
         END
         ELSE
         BEGIN
            -- Get next suggested LOC
            EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
               @cFacility,
               @cCurSuggestLogiLOC, -- current CCLogicalLOC
               @cSuggestLogiLOC  OUTPUT,
               @cSuggestLOC      OUTPUT,
               @nCCCountNo,
               @cUserName  -- (james05)
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
         SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)

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
         
         SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '610ExtendedScreenSP', @cStorer), '')
         SET @nAction = 1
         IF @cExtendedScreenSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
            BEGIN
               EXECUTE [RDT].[rdt_610ExtScnEntry] 
                  @cExtendedScreenSP,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestLOC OUTPUT ,@cLocNeedValid OUTPUT,@cSuggestLOC OUTPUT,
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
                  GOTO LOC_Fail
               
               SET @cLoc = @cLocNeedValid
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
            IF rdt.RDTGetConfig( @nFunc, 'OverrideLOC', @cStorer) <> '1' -- Not allow override loc
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
                  IF rdt.RDTGetConfig( @nFunc, 'SkipOverrideLOCScn', @cStorer) <> '1'
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
           --,@cStorer = StorerKey -- SHONG001
         FROM dbo.CCDETAIL (NOLOCK)
         WHERE CCKey = @cCCRefNo
         --AND   CCSheetNo = @cCCSheetNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND LOC = @cLOC

         IF ISNULL(RTRIM(@cCheckStorer),'') = ''
            SET @cCheckStorer = @cStorer

         SET @cLocType = ''
         -- If Empty LOC generated in CCDetail, no SKU found.
         -- Get first LocType found in SKUxLOC
         IF @cSKU = '' OR @cSKU IS NULL
     BEGIN
            SELECT TOP 1 @cLocType = LocationType
            FROM dbo.SKUxLOC (NOLOCK)
            WHERE StorerKey = @cCheckStorer -- SHONG002
            --WHERE StorerKey = @cStorer
            AND LOC = @cLOC
         END
         ELSE
         BEGIN
            -- With pre-requisite: SKUxLOC.LocationType must be correctly setup
            -- Assumption: Same storer and sku having same SKUxLOC.LocationType
            SELECT @cLocType = LocationType
            FROM dbo.SKUxLOC (NOLOCK)
            WHERE StorerKey = @cCheckStorer -- SHONG002
            --WHERE StorerKey = @cStorer
            AND SKU = @cSKU
            AND LOC = @cLOC
         END
      END

      -- If configkey turned on, start insert CCLock (james05)
      --IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) = '1'
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
--         WHERE StorerKey = @cStorer
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
      SET @cOutField06 = @cDefaultCCOption
      SET @cOutField07 = '' -- ID

      -- SOS# 179935
      IF @cDefaultCCOption = ''
         EXEC rdt.rdtSetFocusField @nMobile, 6   -- Option
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 7   -- ID

      -- (james12)
      SET @nNoOfTry = 0

      -- (james28)
      IF rdt.RDTGetConfig( @nFunc, 'DoubleDeep', @cCheckStorer) = '1'
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                     WHERE Facility = @cFacility
                     AND   Loc = @cLOC
                     AND   MaxPallet > 1
                     AND   LocationCategory = 'DOUBLEDEEP')
         BEGIN
            SELECT TOP 1 @cID_In = Id
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 0
                           WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 0
                           WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 0
                      ELSE 1 END
            AND   [STATUS] < '9'
            ORDER BY Id

            SELECT @nID_Count = SUM( ID_Count), @nTtlID_Count = SUM( TtlID_Count)
            FROM (
               SELECT
               CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN COUNT( DISTINCT Id)
                                 WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN COUNT( DISTINCT Id)
                                 WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN COUNT( DISTINCT Id)
                            ELSE 0 END AS ID_Count,
               CASE WHEN @nCCCountNo = 1 THEN COUNT( DISTINCT Id)
                                    WHEN @nCCCountNo = 2 THEN COUNT( DISTINCT Id)
                                    WHEN @nCCCountNo = 3 THEN COUNT( DISTINCT Id)
                               ELSE 0 END AS TtlID_Count
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   [STATUS] < '9'
            GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3) A

            SET @cDoubleDeep = '1'
            SET @cOutField03 = CAST( @nID_Count + 1 AS NVARCHAR( 2)) + '/' + CAST( @nTtlID_Count AS NVARCHAR( 2))
            SET @cOutField06 = '2'  -- Option
            SET @cOutField07 = @cID_In -- ID
            SET @cFieldAttr07 = 'O'
         END
      END

      -- Go to next screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID

      -- (james29)
      SET @cCountTypeUCCSpecialHandling = rdt.RDTGetConfig( @nFunc, 'CountTypeUCCSpecialHandling', @cCheckStorer)

      IF @cCountTypeUCCSpecialHandling > 0
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.StockTakeSheetParameters WITH (NOLOCK) WHERE StockTakeKey = @cCCRefNo AND CountType = 'UCC')
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                        WHERE Facility = @cFacility
                        AND   Loc = @cLOC
                        AND   LoseId = '1')
            BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE loc = @cLOC AND Facility = @cFacility AND LoseUCC = '0')
               BEGIN
                  SET @cInField06 = '1'
                  GOTO Step_ID
               END
               ELSE
               BEGIN
                  IF @cCountTypeUCCSpecialHandling = '2'
                  BEGIN
                     SET @cInField06 = '2'
                     GOTO Step_ID
                  END
                  ELSE
                  BEGIN
                     IF @cCountTypeUCCSpecialHandling = '3'
                     BEGIN
                        SET @cInField06 = '3'
                        GOTO Step_ID
                     END
                  END
               END
            END
         END
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset Flags
      SET @cRecountFlag = ''
      SET @cLastLocFlag = ''
      SET @cAddNewLocFlag = ''

      -- (james26)
      IF @cExtendedInfoSP <> '' AND            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
              ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
              ' @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, ' +
              ' @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
              ' @tExtValidate, @cExtendedInfo OUTPUT '
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
            ' @tExtValidate   VariableTable READONLY, ' +
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorer,
            @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel,
            @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @tExtValidate, @cExtendedInfo OUTPUT

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
END
GOTO Quit

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
         SET @cOutField06 = @cDefaultCCOption
         SET @cOutField07 = '' -- ID

         IF @cDefaultCCOption = ''
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- Option
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 7   -- ID

         -- If configkey turned on, start insert CCLock (james05)
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) = '1'
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
--            ELSE
--            BEGIN
--               INSERT INTO RDT.RDTCCLock
--                  (Mobile,    CCKey,      CCDetailKey,
--                  SheetNo,
--                  CountNo,
--                  Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,
--                  StorerKey,  Sku,        Lot,         Loc,        Id,
--                  Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,
--                  SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)
--               VALUES
--                 (@nMobile, @cCCRefNo, '',
--                  CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN '' ELSE @cCCSheetNo END,
--                  @nCCCountNo,
--                  'ALL',      '',         '',          '',         '',         'ALL',   'ALL',
--                  @cStorer    '',         '',          @cLOC,      '',
--                  '',         '',         '',          NULL,       NULL,
--                  0,  0,        '0',         '',         @cUserName,  GETDATE()
--               FROM dbo.CCDETAIL WITH (NOLOCK)
--               WHERE CCKey = @cCCRefNo
--                  AND StorerKey = @cStorer
--                  AND LOC = @cLOC
--                  -- Only select uncounted record
--                  AND 1 = CASE
--                             WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
--                             WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
--               WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
--      ELSE 0
--     END
--            END

--            SELECT DISTINCT @cCCSheetNo = SheetNo FROM RDT.RDTCCLock WITH (NOLOCK)
--            WHERE StorerKey = @cStorer
--               AND CCKey = @cCCRefNo
--               AND LOC = @cLOC
--               AND Status = '0'
--               AND AddWho = @cUserName
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
         SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)

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
      SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)

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
         SET @cOutField06 = @cDefaultCCOption
         SET @cOutField07 = ''   -- ID

         IF @cDefaultCCOption = ''
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- Option
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 7   -- ID

         -- Reset Counted_Cnt(x) -- IN00187400
         SET @nErrNo  = 0
         SET @cErrMsg = ''
         EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cLOC, --@cCCDetailKey
            0,
            @cUserName,
            @cRecountFlag,--@cLangCode
            @nErrNo       OUTPUT,
            @cErrMsg      OUTPUT   -- screen limitation, 20 char max

         IF @nErrNo <> 0
            GOTO RECOUNT_LOC_Option_Fail

         -- If configkey turned on, start insert CCLock (james05)
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) = '1'
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

--            SELECT DISTINCT @cCCSheetNo = SheetNo FROM RDT.RDTCCLock WITH (NOLOCK)
--            WHERE StorerKey = @cStorer
--               AND CCKey = @cCCRefNo
--               AND LOC = @cLOC
--               AND Status = '0'
--               AND AddWho = @cUserName
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
         SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)

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
      SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)

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
--   IF @c_debug = '3'
--   BEGIN
--    Insert Into TraceInfo (TraceName, TimeIn, Step1, Step2, Col1, Col2, Col3, Col4)
--  Values ('rdtfnc_CycleCount', GetDate(), '664 Scn5', '4', @cUserName, @cCCRefNo, @cCCSheetNo, @cInField06)
--  END

   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cDefaultCCOption = @cInField06
      SET @cID_In = CASE WHEN @cFieldAttr07 = 'O' THEN @cOutField07 ELSE @cInField07 END

      -- Retain the key-in value
      SET @cOutField06 = @cDefaultCCOption
      SET @cOutField07 = @cID_In

               -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'ID', @cID_In) = 0
      BEGIN
         SET @nErrNo = 77726
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO ID_Fail
      END

      SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)
      IF @cDecodeSP = '0'
         SET @cDecodeSP = ''

      -- (james24)
      IF @cDecodeSP <> ''
      BEGIN
         IF @cDecodeSP = '1'
         BEGIN
            SET @cIDBarcode = @cInField07

            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cIDBarcode,
               @cID     = @cID_In      OUTPUT,
               @cType   = 'ID'
         END
         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cBarcode = @cInField07

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCCRefNo, @cCCSheetNo, @cBarcode, ' +
               ' @cLOC           OUTPUT, @cID            OUTPUT, @cUCC           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT, ' +
               ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT, ' +
               ' @cLottable06    OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT, ' +
               ' @cLottable11    OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
               ' @cUserDefine01  OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,              ' +
               ' @nFunc          INT,              ' +
               ' @cLangCode      NVARCHAR( 3),     ' +
               ' @nStep          INT,              ' +
               ' @nInputKey      INT,              ' +
               ' @cStorerKey     NVARCHAR( 15),    ' +
               ' @cCCRefNo       NVARCHAR( 10),    ' +
               ' @cCCSheetNo     NVARCHAR( 10),    ' +
               ' @cBarcode       NVARCHAR( MAX),   ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCheckStorer, @cCCRefNo, @cCCSheetNo, @cIDBarcode,
               @cLOC          OUTPUT, @cID_In         OUTPUT, @cUCC           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

            IF @nErrNo <> 0
               GOTO ID_Fail
         END
      END

      -- 1=UCC, 2=SKU/UPC, 3=SINGLE SCAN
      -- Validate CCType
      IF @cDefaultCCOption = '' OR @cDefaultCCOption IS NULL
      BEGIN
         SET @nErrNo = 62093
         SET @cErrMsg = rdt.rdtgetmessage( 62093, @cLangCode, 'DSP') -- 'Option required'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO ID_Fail
      END

--      IF @c_debug = '3'
--      BEGIN
--       Insert Into TraceInfo (TraceName, TimeIn, Step1, Step2, Col1, Col2, Col3, Col4, Col5)
--       Values ('rdtfnc_CycleCount', GetDate(), '663 Scn4', '2', @cUserName, @cCCRefNo, @cCCSheetNo, @cLocType, @cUCCConfig)
--      END

      IF ( @cDefaultCCOption <> '1' AND @cDefaultCCOption <> '2' AND @cDefaultCCOption <> '3' AND @cDefaultCCOption <> '4')
         OR ( @cDoubleDeep = '1' AND @cDefaultCCOption <> '2')
      BEGIN
         SET @nErrNo = 62094
         SET @cErrMsg = rdt.rdtgetmessage( 62094, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO ID_Fail
      END

      -- Get StorerConfig 'UCC'
      SELECT @cUCCConfig = SValue
      FROM dbo.StorerConfig (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   ConfigKey = 'UCC'

      -- Get stock take count type (james10)
      SELECT @cCountType = ISNULL(CountType, '')
      FROM dbo.StockTakeSheetParameters WITH (NOLOCK)
      WHERE StockTakeKey = @cCCRefNo

      -- (MaryVong01)
      IF @cDefaultCCOption = '1'
      BEGIN
/*
         IF @cUCCConfig <> '1'
         BEGIN
            SET @nErrNo = 62095
            SET @cErrMsg = rdt.rdtgetmessage( 62095, @cLangCode, 'DSP') -- 'No UCCConfig'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END
*/
         IF (@cLocType = 'PICK' OR @cLocType = 'CASE') -- PICK location
         BEGIN
            SET @nErrNo = 62096
            SET @cErrMsg = rdt.rdtgetmessage( 62096, @cLangCode, 'DSP') -- 'LocType PICK'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END
      END

--      IF @c_debug = '3'
--      BEGIN
--        Insert Into TraceInfo (TraceName, TimeIn, Step1, Step2, Col1, Col2, Col3, Col4)
--        Values ('rdtfnc_CycleCount', GetDate(), '663 Scn4', '3', @cUserName, @cCCRefNo, @cCCSheetNo, @cOptCCType)
--      END
      -- Commented by MaryVong on 04-Dec-2006
      -- No validation for ID
      -- Reason: Should allow user to key-in any ID here, just in case ID in CCDetail not exist at warehouse.
      --         And sometimes, users need to blank out ID

      -- UCC screen
      IF @cDefaultCCOption = '1'
      BEGIN
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
         SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
                                 THEN RIGHT( SPACE(5) + CAST( @nCntQTY AS NVARCHAR( 5)), 5)
                                 ELSE CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
                                 END
         SET @cOutField12 = ''   -- Option

         EXEC rdt.rdtSetFocusField @nMobile, 1   -- UCC

         -- Go to UCC (Main) screen
         SET @nScn = @nScn_UCC
         SET @nStep = @nStep_UCC
      END

      -- SKU screen
      ELSE IF @cDefaultCCOption = '2'
      BEGIN
         -- Check CC count type, must either be SKU or blank count (james10)
         IF @cCountType NOT IN ('SKU', 'BLK')
         BEGIN
            IF @cCountTypeUCCSpecialHandling = '0'
            BEGIN
               SET @nErrNo = 77708
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV COUNT TYPE'
               EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
               GOTO ID_Fail
            END
         END

         -- (MaryVong01)
         SET @nCntQTY = 0
         SET @nCCDLinesPerLOCID = 0
         SET @cPrevCCDetailKey = ''

         SET @cShowCaseCnt = rdt.RDTGetConfig( @nFunc, 'ShowCaseCnt', @cStorer)

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
         EXECUTE rdt.rdt_CycleCount_GetCCDetail
            @cCCRefNo, @cCCSheetNo, @nCCCountNo,
            @cStorer       OUTPUT, -- Shong001
            @cLOC,
            @cID_In,
            @cWithQtyFlag, -- SOS79743
            @cCCDetailKey  OUTPUT,
            @cCountedFlag  OUTPUT,
            @cSKU          OUTPUT,
            @cLOT          OUTPUT,
            @cID           OUTPUT,
            @cLottable01   OUTPUT,
            @cLottable02   OUTPUT,
            @cLottable03   OUTPUT,
            @dLottable04   OUTPUT,
            @dLottable05   OUTPUT,
            @nCaseCnt      OUTPUT,
            @nCaseQTY      OUTPUT,
            @cCaseUOM      OUTPUT,
            @nEachQTY      OUTPUT,
            @cEachUOM      OUTPUT,
            @cSKUDescr     OUTPUT,
            @cPPK          OUTPUT,
            @nRecCnt       OUTPUT,
            @cEmptyRecFlag OUTPUT

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
            SET @dLottable04 = ''
            SET @dLottable05 = ''

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
            SET @dLottable04 = ''
            SET @dLottable05 = ''

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
         ELSE IF @cBlindCount = '1'
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
            SET @nScn  = @nScn_Blind_Sku
            SET @nStep = @nStep_Blind_Sku
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @cID = @cID_In

            -- Prepare SKU screen var
            SET @cOutField01 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cSKU END
            SET @cOutField02 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20) END
            IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorer) = '1'
            BEGIN
               SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU
               SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16) END
            END
            ELSE
            BEGIN
               SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 40) END
            END

            SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)

            -- If config turned on and skuconfig not setup then prompt error
            IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
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
                  WHERE S.StorerKey = @cStorer
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
               WHERE S.StorerKey = @cStorer
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
               IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1
               BEGIN
                  SET @cOutField04 = CAST( 0 AS NVARCHAR(10))   -- QTY (CS) -- (Shong003)
                  SET @cOutField06 = CAST( 0 AS NVARCHAR(10))   -- QTY (EA) -- (Shong003)
               END
               ELSE
               BEGIN
                  SELECT @nCaseCnt = P.CaseCnt
                  FROM dbo.Pack P WITH (NOLOCK)
                  JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
                  WHERE S.StorerKey = @cStorer
                  AND S.SKU = @cSKU

                  -- (james25)
                  IF @cShowCaseCnt = '1'
                     SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(6)) + '/' + CAST( @nCaseCnt AS NVARCHAR( 4))
                  ELSE
                     SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(10)) -- QTY (CS) -- (ChewKP01)

                  SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP01)
               END

               SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS)
               SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
            END

            -- (james14)
            SET @cSKUCountDefaultOpt = ''
            SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorer)
            IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
               SET @cSKUCountDefaultOpt = ''

         -- SET @cOutField08 = @cID -- SOS359218
            SET @cOutField09 = @cLottable01
            SET @cOutField10 = @cLottable02
            SET @cOutField11 = @cLottable03
            SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
            SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
            SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14)
         -- SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
            SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
                                    THEN RIGHT( SPACE(4) + CAST( @nCntQTY AS NVARCHAR( 4)), 4)
                                    ELSE CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4))
                                    END
         END

         -- Go to SKU (Main) screen
         SET @nScn  = @nScn_SKU
         SET @nStep = @nStep_SKU
         
         IF @cFlowThruStepSKU = '1'
         BEGIN
            SET @cInField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END
            GOTO Step_SKU
         END
      END

      -- SINGLE SCAN screen
      ELSE IF @cDefaultCCOption = '3'
      BEGIN
         -- Check CC count type, must either be SKU or blank count (james10)
         IF @cCountType NOT IN ('SKU', 'BLK')
         BEGIN
            IF @cCountTypeUCCSpecialHandling = '0'
            BEGIN
               SET @nErrNo = 77709
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV COUNT TYPE'
               EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
               GOTO ID_Fail
            END
         END

         SET @cID = @cID_In

         -- Prepare SINGLE SCAN screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID
         SET @cOutField03 = ''   -- SKU/UPC
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 3   -- SKU/UPC

         -- Go to SINGLE SCAN screen
         SET @nScn = @nScn_SINGLE_SKU_Sku_Scan
         SET @nStep = @nStep_SINGLE_SKU_Sku_Scan

         -- Skip insert to RDTCCLock, only insert at SINGLE SKU screen (Scn 15)
         GOTO Quit
      END

      -- ID/CARTON
      ELSE IF @cDefaultCCOption = '4'
      BEGIN /*
         -- Count by ID must have key in pallet ID
         IF ISNULL(@cID_In, '') = ''
         BEGIN
            SET @nErrNo = 77701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'ID required'
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- ID
            GOTO ID_Fail
         END

         -- Check if ID exists in LOC selected
         IF NOT EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
WHERE CCKey = @cCCRefNo
                        AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                        AND LOC = @cLOC
                        AND ID = @cID_In
                        AND Status < '9')
         BEGIN
            SET @nErrNo = 77706
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'ID NO RECORD'
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- ID
            GOTO ID_Fail
         END*/

         -- Count by ID must only count Loc with have LoseID set to value other than '1'
         IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                    WHERE LOC = @cLOC
                    AND   Facility = @cFacility
                    AND   LoseID = '1')
         BEGIN
            SET @nErrNo = 77702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC LOSEID'
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- ID
            GOTO ID_Fail
         END

         -- (james12)
         -- Get last counted loc
         SELECT TOP 1 @cLastCountedLOC = LOC
         FROM RDT.RDTCCLOCK WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND   Status = '9'
         AND   AddWho = @cUserName
         ORDER BY EditDate DESC

/*
         -- If count different loc then reset the nooftry counter
         -- so user no need to scan each ucc
         IF @cLastCountedLOC <> @cLOC
            SET @nNoOfTry = 0

         -- Check if any ucc on the pallet scanned before
         -- If yes, not allow to proceed with count by id
         -- When doing the counting in RDT for 'Count by ID', if a user already wronly keys in the # of cartons,
         -- and direct to Count by UCC, do not allow to go back to count by ID. Force user to do count by UCC and complete it.
         IF EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                    WHERE CCKey = @cCCRefNo
                    AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                    AND   LOC = @cLOC
                    AND   ID = @cID_In       -- ID must exists for count by id
                    AND   Status IN ('2', '4')
                    AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 1
                                   WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 1
                                   WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 1
                                   ELSE 0 END)
         BEGIN
            SET @cErrMsg1 = 'SOME UCC ALREADY'
            SET @cErrMsg2 = 'SCANNED BEFORE.'
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = 'PLS USE COUNT BY UCC'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END

            SET @nErrNo = 0
            SET @cErrMsg = ''

            EXEC rdt.rdtSetFocusField @nMobile, 7 -- ID
            GOTO ID_Fail
         END
         */
         -- Prepare next screen var
         SET @cOutField01 = @cID_In
         SET @cOutField02 = ''

         SET @nScn = @nScn_ID_CartonCount
         SET @nStep = @nStep_ID_CartonCount

         SET @cFieldAttr07 = ''
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset Flags
      SET @cRecountFlag   = ''
      SET @cLastLocFlag = ''
      SET @cAddNewLocFlag = ''
      SET @cFieldAttr07 = ''

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
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
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
            EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
               @cFacility,
               @cSuggestLogiLOC, -- current CCLogicalLOC
               @cSuggestLogiLOC OUTPUT,
               @cSuggestLOC OUTPUT,
               @nCCCountNo,
               @cUserName  -- (james05)
         END
         ELSE
         BEGIN
            -- Get next suggested LOC
            EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
               @cFacility,
               @cSuggestLogiLOC, -- current CCLogicalLOC
               @cSuggestLogiLOC OUTPUT,
               @cSuggestLOC OUTPUT,
               @nCCCountNo,
               @cUserName  -- (james05)
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
      SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)
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
      SET @cUCC = LEFT( @cBarcode, 20) -- @cInField01
      SET @cOptAction = @cInField12

      -- Retain the key-in value
      SET @cOutField01 = @cUCC
      SET @cOutField12 = @cOptAction

      IF ISNULL(@cDecodeSP,'') <> ''
      BEGIN
         IF @cDecodeSP = '1'  
         BEGIN  
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode, 
               @cUCCNo  = @cUCC    OUTPUT,   
               @nErrNo  = @nErrNo  OUTPUT,   
               @cErrMsg = @cErrMsg OUTPUT,  
               @cType   = 'UCCNo'  
  
            -- Decode is optional, allow some barcode to pass thru
            SET @nErrNo = 0
         END
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
               ' @nMobile        INT,              ' +
               ' @nFunc          INT,              ' +
               ' @cLangCode      NVARCHAR( 3),     ' +
               ' @nStep          INT,              ' +
               ' @nInputKey      INT,              ' +
               ' @cStorerKey     NVARCHAR( 15),    ' +
               ' @cCCRefNo       NVARCHAR( 10),    ' +
               ' @cCCSheetNo     NVARCHAR( 10),    ' +
               ' @cBarcode       NVARCHAR( MAX),   ' +
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
         END
      END

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
            IF rdt.RDTGetConfig( @nFunc, 'CCEDITUCCNOTALLOW', @cStorer) = '1'
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
            @cStorer,
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
         IF @cUCCStorer <> @cStorer
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
            IF @cAllowAddUCCNotInLocSP <> '' AND
               EXISTS( SELECT 1 FROM sys.objects WHERE name = @cAllowAddUCCNotInLocSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cAllowAddUCCNotInLocSP) +
                  ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cLOC, @cID, @cUCC, ' +
                  ' @cCCDetailKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile      INT,           ' +
                  '@nFunc        INT,           ' +
                  '@nStep        INT,           ' +
                  '@nInputKey    INT,           ' +
                  '@cLangCode    NVARCHAR( 3),  ' +
                  '@cStorer      NVARCHAR( 15), ' +
                  '@cCCRefNo     NVARCHAR( 10), ' +
                  '@cCCSheetNo   NVARCHAR( 10), ' +
                  '@nCCCountNo   INT,  ' +
                  '@cLOC         NVARCHAR( 10), ' +
                  '@cID          NVARCHAR( 18), ' +
                  '@cUCC         NVARCHAR( 20), ' +
                  '@cCCDetailKey NVARCHAR( 20) OUTPUT, ' +
                  '@nErrNo       INT           OUTPUT, ' +
                  '@cErrMsg      NVARCHAR( 20) OUTPUT  '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                    @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cLOC, @cID, @cUCC,
                    @cCCDetailKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit

               -- Increase counter by 1
               SET @nCntQTY = @nCntQTY + 1
            END
            ELSE
            BEGIN
               SET @nErrNo = 62100
               SET @cErrMsg = rdt.rdtgetmessage( 62100, @cLangCode, 'DSP') -- 'No UCC (CCDet)'
               GOTO UCC_Fail
            END
         END
         -- Valid UCC found in CCDETAIL, do more validation
         ELSE
         BEGIN
            DECLARE
               @cSYSID  NVARCHAR( 18),
               @nSYSQTY   INT

            SET @cCountedFlag = '[ ]'

            -- Get CCDETAIL
            SELECT TOP 1
               @cStorer = CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorer ELSE StorerKey END, -- Shong002
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
                  @cStorer,
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
              EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
                 @cCCRefNo,
                  @cCCSheetNo,
                  @nCCCountNo,
                  @cCCDetailKey,
                  @nSYSQTY,   -- equal to CaseCnt
                  @cUserName,
                  @cLangCode,
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
         WHERE  StorerKey = @cStorer
            AND SKU = @cSKU

         -- Add eventlog (yeekung01)
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '7',
            @nFunctionID   = @nFunc,
            @nMobileNo     = @nMobile,
            @cStorerKey    = @cStorer,
            @cFacility     = @cFacility,
            @cCCKey        = @cCCRefNo,
            @cLocation     = @cLOC,
            @cID           = @cID_In,
            @cUCC          = @cUCC,
            @cSKU          = @cSKU,
            @cCCSheetNo    = @cCCSheetNo,    --(cc01)
            @nCountNo      = @nCCCountNo     --(cc01)

         -- Prepare current (UCC) screen var
         SET @cOutField01 = ''      -- UCC
         SET @cOutField02 = CASE WHEN @cBlindCount = '1' THEN '' ELSE @cSKU END
         SET @cOutField03 = CASE WHEN @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20) END
         SET @cOutField04 = CASE WHEN @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 40) END
         SET @cOutField05 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1 THEN 0 ELSE CAST( @nSYSQTY AS NVARCHAR( 5)) END
         SET @cOutField06 = @cLottable01
         SET @cOutField07 = @cLottable02
         SET @cOutField08 = @cLottable03
         SET @cOutField09 = rdt.rdtFormatDate( @dLottable04)
         SET @cOutField10 = rdt.rdtFormatDate( @dLottable05)
--       SET @cOutField11 = CAST( @nCntQTY AS NVARCHAR( 2)) + '/' + CAST( @nTotCarton AS NVARCHAR( 2))
         SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
                                 THEN RIGHT( SPACE(5) + CAST( @nCntQTY AS NVARCHAR( 5)), 5)
                                 ELSE CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
                                 END

      END
      -- End of OPT = blank

      ---- Add eventlog (yeekung01)
      --EXEC RDT.rdt_STD_EventLog
      --   @cActionType   = '7',
      --   @nFunctionID   = @nFunc,
      --   @nMobileNo     = @nMobile,
      --   @cStorerKey    = @cStorer,
      --   @cFacility     = @cFacility,
      --   @cCCKey        = @cCCRefNo,
      --   @cLocation     = @cLOC,
      --   @cID           = @cID_In,
      --   @cUCC          = @cUCC,
      --   @cSKU          = @cSKU,
      --   @cCCSheetNo    = @cCCSheetNo,    --(cc01)
      --   @cOption       = @cOptAction,    --(cc01)
      --   @cOptionDefinition   = 'Add UCC',--(cc01)
      --   @cTransType    ='Cycle Count',   --(cc01)
      --   @nCountNo      = @nCCCountNo     --(cc01)
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF @nNoOfTry > 1 -- (james12)
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cID_In
         SET @cOutField02 = ''
         SET @cFieldAttr07 = ''

         SET @nScn = @nScn_ID_CartonCount
         SET @nStep = @nStep_ID_CartonCount

         GOTO Quit
      END

      -- Press ESC treat as Empty loc
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT
         CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorer ELSE StorerKey END,
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
      FETCH NEXT FROM CUR_LOOP INTO @cStorer, @cSKU, @cLOT, @cStatus, @nSYSQTY, @cSYSID, @cCCDetailKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- If found, update CCDETAIL
         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cCCDetailKey,
            0,               -- empty loc
            @cUserName,
            @cLangCode,
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

         FETCH NEXT FROM CUR_LOOP INTO @cStorer, @cSKU, @cLOT, @cStatus, @nSYSQTY, @cSYSID, @cCCDetailKey
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

      IF rdt.RDTGetConfig( @nFunc, 'SkipIDOPTScn', @cStorer) = '1'
      BEGIN
         SET @cOutField15 = ''
         GOTO Step_ID
      END
   END

   -- (james29)
   IF @cExtendedInfoSP <> '' AND
      EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
   BEGIN
      SET @cExtendedInfo = ''
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, ' +
       ' @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @tExtValidate, @cExtendedInfo OUTPUT '
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
         ' @tExtValidate   VariableTable READONLY, ' +
         ' @cExtendedInfo  NVARCHAR( 20) OUTPUT '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorer,
         @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel,
         @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @tExtValidate, @cExtendedInfo OUTPUT

      IF @cExtendedInfo <> ''
         SET @cOutField15 = @cExtendedInfo
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
         @cStorer,
         '1',          -- Received status
         @nChkQTY = 1  -- Turn on validation of UCC Qty

      IF @nErrNo > 0
         GOTO UCC_Add_Ucc_Fail

      -- Get Status and CountedFlag from CCDetail
      SET @cCountedFlag = '[ ]'

      SELECT TOP 1
         @cStatus = Status,
         @cCountedFlag =              CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN '[C]'
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
      WHERE UCC.StorerKey = @cStorer
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
      SET @cOutField07 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1 THEN 0 ELSE
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
      SET @cOutField06 = @cLottable01
      SET @cOutField07 = @cLottable02
      SET @cOutField08 = @cLottable03
      SET @cOutField09 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField10 = rdt.rdtFormatDate( @dLottable05)
--    SET @cOutField11 = CAST( @nCntQTY AS NVARCHAR( 2)) + '/' + CAST( @nTotCarton AS NVARCHAR( 2))
      SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
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
         @cCCRefNo, @cStorer, @cNewSKU, 'PRE', -- Codelkup.Short
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
         -- Clear all outfields
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

         -- Initiate labels
         SELECT
            @cOutField01 = 'Lottable01:',
            @cOutField03 = 'Lottable02:',
            @cOutField05 = 'Lottable03:',
            @cOutField07 = 'Lottable04:',
            @cOutField09 = 'Lottable05:'

         -- Populate labels and lottables
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr02 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField01 = @cLotLabel01,
                   @cOutField02 = ISNULL(@cLottable01, '')
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr04 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField03 = @cLotLabel02,
                   @cOutField04 = ISNULL(@cLottable02, '')
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
             SET @cFieldAttr06 = 'O'
         END
         ELSE
         BEGIN
           SELECT @cOutField05 = @cLotLabel03,
                  @cOutField06 = ISNULL(@cLottable03, '')
         END

      IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
         SET @cFieldAttr08 = 'O'
         END
         ELSE
         BEGIN
            SELECT  @cOutField07 = @cLotLabel04,
                    @cOutField08 = RDT.RDTFormatDate(ISNULL(@dLottable04, ''))
         END

         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
         BEGIN
            SET @cFieldAttr10 = 'O'
         END
         ELSE
         BEGIN
            -- Lottable05 is usually RCP_DATE
            IF @cLottable05_Code = 'RCP_DATE'
            BEGIN
               SET @dLottable05 = GETDATE()
           END

            SELECT
               @cOutField09 = @cLotLabel05,
               @cOutField10 = RDT.RDTFormatDate( @dLottable05)
         END

         EXEC rdt.rdtSetFocusField @nMobile, 1   -- Lottable01 value

         -- Go to next screen
         SET @nScn  = @nScn_UCC_Add_Lottables
         SET @nStep = @nStep_UCC_Add_Lottables
      END -- End of @cHasLottable = '1'

      IF @cHasLottable = '0'
      BEGIN
        -- Insert a record into CCDETAIL
         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXECUTE rdt.rdt_CycleCount_InsertCCDetail
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cStorer,
            @cNewSKU,
            @cNewUCC,      -- No UCC
            '',            -- No LOT generated yet
            @cLOC,         -- Current LOC
            @cID,          -- Entered ID, it can be blank
            --@nNewCaseCnt,
            @nNewUCCQTY,
            '',            -- Lottable01
            '',            -- Lottable02
            '',            -- Lottable03
            NULL,          -- Lottable04
            NULL,          -- Lottable05
            @cUserName,
            @cLangCode,
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
         SET @cOutField05 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1 THEN 0 ELSE CAST( @nNewUCCQTY AS NVARCHAR( 5)) END --(jamesxx)
         SET @cOutField06 = ''   -- Lottable01
         SET @cOutField07 = ''   -- Lottable02
         SET @cOutField08 = ''   -- Lottable03
         SET @cOutField09 = ''   -- Lottable04
         SET @cOutField10 = ''   -- Lottable05
--       SET @cOutField11 = CAST( @nCntQTY AS NVARCHAR( 2)) + '/' + CAST( @nTotCarton AS NVARCHAR( 2))
         SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
                                 THEN RIGHT( SPACE(5) + CAST( @nCntQTY AS NVARCHAR( 5)), 5)
                                 ELSE CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
                                 END
         SET @cOutField12 = ''   -- Option

         -- Add eventlog (cc01)
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '7',
            @nFunctionID   = @nFunc,
            @nMobileNo     = @nMobile,
            @cStorerKey    = @cStorer,
            @cFacility     = @cFacility,
            @cCCKey        = @cCCRefNo,
            @cLocation     = @cLOC,
            @cID           = @cID_In,
            @cUCC          = @cUCC,
            @cSKU          = @cSKU,
            @cCCSheetNo    = @cCCSheetNo,
            @nCountNo      = @nCCCountNo,
            @cOption       = @cOptAction,
            @cOptionDefinition   = 'Add UCC',
            @cTransType    ='Cycle Count'

         -- Go to UCC (Main) screen
         SET @nScn  = @nScn_UCC
         SET @nStep = @nStep_UCC
      END-- End of @cHasLottable = '0'
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

      -- SOS#81879
      -- Get Lottables Details
      EXECUTE rdt.rdt_CycleCount_GetLottables
         @cCCRefNo, @cStorer,
         @cNewSKU, 'POST', -- Codelkup.Short
         @cNewLottable01,
         @cNewLottable02,
         @cNewLottable03,
         @dNewLottable04,
         @dNewLottable05,
         @cLotLabel01      OUTPUT,
         @cLotLabel02      OUTPUT,
         @cLotLabel03      OUTPUT,
         @cLotLabel04      OUTPUT,
         @cLotLabel05    OUTPUT,
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
         GOTO UCC_Add_Lottables_Fail
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
            SET @nErrNo = 62108
            SET @cErrMsg = rdt.rdtgetmessage( 62108, @cLangCode, 'DSP') --'Lottable1 req'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO UCC_Add_Lottables_Fail
         END

      -- Validate lottable02
      IF @cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL
      BEGIN
         IF @cNewLottable02 = '' OR @cNewLottable02 IS NULL
         BEGIN
            SET @nErrNo = 62109
            SET @cErrMsg = rdt.rdtgetmessage( 62109, @cLangCode, 'DSP') --'Lottable2 req'
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO UCC_Add_Lottables_Fail
         END
      END

      -- Validate lottable03
      IF @cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL
         IF @cNewLottable03 = '' OR @cNewLottable03 IS NULL
         BEGIN
            SET @nErrNo = 62111
            SET @cErrMsg = rdt.rdtgetmessage( 62111, @cLangCode, 'DSP') --'Lottable3 req'
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO UCC_Add_Lottables_Fail
         END

      -- Validate lottable04
      IF @cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL
      BEGIN
         -- Validate empty
         IF @cNewLottable04 = '' OR @cNewLottable04 IS NULL
         BEGIN
            SET @nErrNo = 62112
            SET @cErrMsg = rdt.rdtgetmessage( 62112, @cLangCode, 'DSP') --'Lottable4 req'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO UCC_Add_Lottables_Fail
         END
         -- Validate date
         IF rdt.rdtIsValidDate( @cNewLottable04) = 0
         BEGIN
            SET @nErrNo = 62113
            SET @cErrMsg = rdt.rdtgetmessage( 62113, @cLangCode, 'DSP') --'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO UCC_Add_Lottables_Fail
         END
      END

      -- Validate lottable05
      IF @cLotLabel05 <> '' AND @cLotLabel05 IS NOT NULL
      BEGIN
         -- Validate empty
         IF @cNewLottable05 = '' OR @cNewLottable05 IS NULL
         BEGIN
            SET @nErrNo = 62114
            SET @cErrMsg = rdt.rdtgetmessage( 62114, @cLangCode, 'DSP') --'Lottable5 req'
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO UCC_Add_Lottables_Fail
         END           -- Validate date
         IF rdt.rdtIsValidDate( @cNewLottable05) = 0
         BEGIN
            SET @nErrNo = 62115
            SET @cErrMsg = rdt.rdtgetmessage( 62115, @cLangCode, 'DSP') --'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO UCC_Add_Lottables_Fail
         END
      END


      IF @cExtendedValidSP <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidSP AND type = 'P')
      BEGIN

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
                     ' @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, ' +
                     ' @cLOC, @cID, @cUCC, @cSKU, @nQty, @cNewLottable01, @cNewLottable02, @cNewLottable03, @cNewLottable04, @cNewLottable05, ' +
                     ' @tExtValidate, @nSetFocusField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
                 ' @nMobile            INT,           ' +
                 ' @nFunc              INT,           ' +
                 ' @cLangCode          NVARCHAR( 3),  ' +
                 ' @nStep              INT,           ' +
                 ' @nAfterStep         INT,           ' +
                 ' @nInputKey          INT,           ' +
                 ' @cFacility          NVARCHAR( 5),  ' +
                 ' @cStorerKey         NVARCHAR( 15), ' +
                 ' @cCCRefNo           NVARCHAR( 10), ' +
                 ' @cCCSheetNo         NVARCHAR( 10), ' +
                 ' @nCCCountNo         INT,           ' +
                 ' @cZone1             NVARCHAR( 10), ' +
                 ' @cZone2             NVARCHAR( 10), ' +
                 ' @cZone3             NVARCHAR( 10), ' +
                 ' @cZone4             NVARCHAR( 10), ' +
                 ' @cZone5             NVARCHAR( 10), ' +
                 ' @cAisle             NVARCHAR( 10), ' +
                 ' @cLevel             NVARCHAR( 10), ' +
                 ' @cLOC               NVARCHAR( 10), ' +
                 ' @cID                NVARCHAR( 18), ' +
                 ' @cUCC               NVARCHAR( 20), ' +
                 ' @cSKU               NVARCHAR( 20), ' +
                 ' @nQty               INT,           ' +
                 ' @cNewLottable01     NVARCHAR( 18), ' +
                 ' @cNewLottable02     NVARCHAR( 18), ' +
                 ' @cNewLottable03     NVARCHAR( 18), ' +
                 ' @cNewLottable04     NVARCHAR( 18), ' +
                 ' @cNewLottable05     NVARCHAR( 18), ' +
                 ' @tExtValidate       VariableTable READONLY, ' +
                 ' @nSetFocusField     INT           OUTPUT,   ' +
                 ' @nErrNo             INT           OUTPUT,   ' +
                 ' @cErrMsg            NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorer,
              @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel,
              @cLOC, @cID, @cUCC, @cSKU, @nQty, @cNewLottable01, @cNewLottable02, @cNewLottable03, @cNewLottable04, @cNewLottable05,
              @tExtValidate,@nSetFocusField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF ISNULL(@cErrMsg, '') <> ''
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, @nSetFocusField
            GOTO UCC_Add_Lottables_Fail
         END
      END


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
      EXECUTE rdt.rdt_CycleCount_InsertCCDetail
         @cCCRefNo,
         @cCCSheetNo,
         @nCCCountNo,
         @cStorer,
         @cNewSKU,
         @cNewUCC,      -- No UCC
         '', -- No LOT generated yet
         @cLOC,         -- Current LOC
         @cID,          -- Entered ID, it can be blank
         --@nNewCaseCnt,
         @nNewUCCQTY,
         @cNewLottable01,
         @cNewLottable02,
         @cNewLottable03,
         @dNewLottable04,
         @dNewLottable05,
         @cUserName,
         @cLangCode,
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
      SET @cOutField05 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1 THEN 0 ELSE
                         CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN 0 ELSE CAST( @nUCCQTY AS NVARCHAR( 5)) END END --(jamesxx)
      SET @cOutField06 = @cLottable01
      SET @cOutField07 = @cLottable02
      SET @cOutField08 = @cLottable03
      SET @cOutField09 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField10 = rdt.rdtFormatDate( @dLottable05)
--    SET @cOutField11 = CAST( @nCntQTY AS NVARCHAR( 2)) + '/' + CAST( @nTotCarton AS NVARCHAR( 2))
      SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
                              THEN RIGHT( SPACE(5) + CAST( @nCntQTY AS NVARCHAR( 5)), 5)
                              ELSE CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
                              END
      SET @cOutField12 = ''   -- Option

      -- Go to UCC (Main) screen
      SET @nScn  = @nScn_UCC
      SET @nStep = @nStep_UCC

      -- Add eventlog (cc01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '7',
         @nFunctionID   = @nFunc,
         @nMobileNo     = @nMobile,
         @cStorerKey    = @cStorer,
         @cFacility     = @cFacility,
         @cCCKey        = @cCCRefNo,
         @cLocation     = @cLOC,
         @cID           = @cID_In,
         @cUCC          = @cUCC,
         @cSKU          = @cSKU,
         @cCCSheetNo    = @cCCSheetNo,
         @nCountNo      = @nCCCountNo,
         @cOption       = @cOptAction,
         @cOptionDefinition   = 'Add UCC',
         @cTransType    ='Cycle Count'
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
      SET @cOutField07 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1 THEN 0 ELSE
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
 EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
         @cCCRefNo,
         @cCCSheetNo,
         @nCCCountNo,
         @cCCDetailKey,
         @nQTY,
         @cUserName,
         @cLangCode,
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
   SET @cOutField05 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1 THEN 0 ELSE
                           CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN 0 ELSE CAST( @nNewUCCQTY AS NVARCHAR( 5)) END END --(jamesxx)

   SET @cOutField06 = @cLottable01
   SET @cOutField07 = @cLottable02
   SET @cOutField08 = @cLottable03
   SET @cOutField09 = rdt.rdtFormatDate( @dLottable04)
   SET @cOutField10 = rdt.rdtFormatDate( @dLottable05)
-- SET @cOutField11 = CAST( @nCntQTY AS NVARCHAR( 2)) + '/' + CAST( @nTotCarton AS NVARCHAR( 2))
   SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
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
            SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorer)
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
               @cStorer = CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorer ELSE StorerKey END, -- Shong002
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
               EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
                  @cCCRefNo,
                  @cCCSheetNo,
                  @nCCCountNo,
                  @cCCDetailKey,
                  @nConvQTY,
                  @cUserName,
                  @cLangCode,
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
         EXECUTE rdt.rdt_CycleCount_GetCCDetail
            @cCCRefNo, @cCCSheetNo, @nCCCountNo,
            @cStorer       OUTPUT,  -- Shong001
            @cLOC,
            @cID_In,
            @cWithQtyFlag, -- SOS79743
            @cCCDetailKey  OUTPUT,
            @cCountedFlag  OUTPUT,
            @cSKU          OUTPUT,
            @cLOT          OUTPUT,
            @cID           OUTPUT,
            @cLottable01   OUTPUT,
            @cLottable02   OUTPUT,
            @cLottable03   OUTPUT,
            @dLottable04   OUTPUT,
            @dLottable05   OUTPUT,
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
            SET @cAutoGotoIDLOCScnConfig = rdt.RDTGetConfig( @nFunc, 'AutoGotoIDLOCScn', @cStorer)

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
                  SET @dLottable04 = ''
                  SET @dLottable05 = ''

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
                  EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
                     @cFacility,
                     @cSuggestLogiLOC, -- current CCLogicalLOC
                     @cSuggestLogiLOC OUTPUT,
                     @cSuggestLOC OUTPUT,
                     @nCCCountNo,
                     @cUserName  -- (james05)


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
                  SET @cOutField06 = @cDefaultCCOption
                  SET @cOutField07 = ''   -- UOM (EA) + PPK
                  SET @cOutField08 = ''   -- ID
                  SET @cOutField09 = ''   -- Lottable01
                  SET @cOutField10 = ''   -- Lottable02
                  SET @cOutField11 = ''   -- Lottable03
                  SET @cOutField12 = ''   -- Lottable04
                  SET @cOutField13 = ''   -- Lottable05
                  SET @cOutField14 = ''   -- Option
                  SET @cOutField15 = ''   -- Counted CCDet Lines / Total CCDet Lines (for LOC+ID)

                  -- Show message only, allow to proceed to ID screen
             --SET @nErrNo = 62154
                  --SET @cErrMsg = rdt.rdtgetmessage( 62154, @cLangCode, 'DSP') -- 'End of ID Rec'

                  -- (james12)
                  SET @nNoOfTry = 0

                  -- Go to ID screen
                  SET @nScn  = @nScn_ID
                  SET @nStep = @nStep_ID

                  IF rdt.RDTGetConfig( @nFunc, 'SkipIDOPTScn', @cStorer) = '1'
                  BEGIN
                     SET @cOutField15 = ''
                     GOTO Step_ID
                  END
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
            SET @dLottable04 = ''
            SET @dLottable05 = ''

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

         -- Prepare current screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
         IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorer) = '1'
         BEGIN
            SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU
            SET @cOutField03 = 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16)
         END
         ELSE
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
--         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)

         -- (ChewKP02)
         IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1
         BEGIN
            SET @cOutField04 = CAST( 0 AS NVARCHAR(10))   -- QTY (CS) -- (ChewKP02)
            SET @cOutField06 = CAST( 0 AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP02)
            SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS) + [C]
            SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
            SET @cOutField08 = @cID -- SOS359218
         END
         ELSE
         BEGIN
            -- (james25)
            IF @cShowCaseCnt = '1'
               SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(6)) + '/' + CAST( @nCaseCnt AS NVARCHAR( 4))
            ELSE
               SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR( 10))   -- QTY (CS) -- (ChewKP01)

     SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS) + [C]
            SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR( 10))   -- QTY (EA) -- (ChewKP01)
            SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
            SET @cOutField08 = @cID -- SOS359218
         END

         -- (james14)
         SET @cSKUCountDefaultOpt = ''
         SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorer)
         IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
            SET @cSKUCountDefaultOpt = ''

         SET @cOutField08 = @cID
         SET @cOutField09 = @cLottable01
         SET @cOutField10 = @cLottable02
         SET @cOutField11 = @cLottable03
         SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
         SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
         SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END  -- Option    (james14)
--       SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
         SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
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

         IF @cStepSKUAllowOpt <> ''
         BEGIN
            IF @cOptAction <> @cStepSKUAllowOpt
            BEGIN
               SET @nErrNo = 77729
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid Option'
               GOTO SKU_Fail
            END
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
                        AND   StorerKey = @cStorer
                        AND   Code IN ('SKU', 'LOTTABLE01', 'LOTTABLE02', 'LOTTABLE03', 'LOTTABLE04')
                        AND   Short = '1')
            BEGIN
               SELECT @nValidateSKU = CASE WHEN Short = '1' THEN 1 ELSE 0 END
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'CCVALFIELD'
               AND   StorerKey = @cStorer
               AND   Code = 'SKU'

               SELECT @nValidateLot01 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'CCVALFIELD'
               AND   StorerKey = @cStorer
               AND   Code = 'LOTTABLE01'

               SELECT @nValidateLot02 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'CCVALFIELD'
               AND   StorerKey = @cStorer
               AND   Code = 'LOTTABLE02'

               SELECT @nValidateLot03 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'CCVALFIELD'
               AND   StorerKey = @cStorer
               AND   Code = 'LOTTABLE03'

               SELECT @nValidateLot04 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'CCVALFIELD'
               AND   StorerKey = @cStorer
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
            IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorer) = '1'
            BEGIN
               SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU
               SET @cOutField03 = 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16)
            END
            ELSE
            BEGIN
               SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
            END

            SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)

            -- If config turned on and skuconfig not setup then prompt error
            IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
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
                  WHERE S.StorerKey = @cStorer
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

               SELECT @c_PackKey = P.PackKey FROM dbo.Pack P WITH (NOLOCK)
               JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
               WHERE S.StorerKey = @cStorer
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
                  IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1
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
                  IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1
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
               IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1
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
            SET @cOutField08 = @cLottable01
            SET @cOutField09 = @cLottable02
            SET @cOutField10 = @cLottable03
            SET @cOutField11 = rdt.rdtFormatDate( @dLottable04)
            SET @cOutField12 = rdt.rdtFormatDate( @dLottable05)
            SET @cOutField13 = ''   -- Option

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
         CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorer ELSE StorerKey END,
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
      FETCH NEXT FROM CUR_LOOP INTO @cStorer, @cSKU, @cLOT, @cStatus, @nSYSQTY, @cSYSID, @cCCDetailKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- If found, update CCDETAIL
         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cCCDetailKey,
            0,               -- empty loc
            @cUserName,
            @cLangCode,
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

         FETCH NEXT FROM CUR_LOOP INTO @cStorer, @cSKU, @cLOT, @cStatus, @nSYSQTY, @cSYSID, @cCCDetailKey
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

      IF @cSkipIDScn = '1' -- Skip id turn on then goto loc screen
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
            IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
            BEGIN
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

               -- Get next suggested LOC
               EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
                  @cFacility,
                  @cSuggestLogiLOC, -- current CCLogicalLOC
                  @cSuggestLogiLOC OUTPUT,
                  @cSuggestLOC OUTPUT,
                  @nCCCountNo,
                  @cUserName  -- (james05)
            END
            ELSE
            BEGIN
               -- Get next suggested LOC
               EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
                  @cFacility,
                  @cSuggestLogiLOC, -- current CCLogicalLOC
                  @cSuggestLogiLOC OUTPUT,
                  @cSuggestLOC OUTPUT,
                  @nCCCountNo,
                  @cUserName  -- (james05)
            END

            -- If already last loc then display current loc and prompt "Last Loc"
            IF @cSuggestLOC = '' OR @cSuggestLOC IS NULL
            BEGIN
               SET @cLastLocFlag = 'Y'
               SET @nErrNo = 77727
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
         SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)
         SET @cOutField07 = ''  -- ID

         -- Go to previous screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC
      END
      ELSE  -- GOTO id screen
      BEGIN
         -- Set back values
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = @cDefaultCCOption -- Option
         SET @cOutField07 = '' -- ID
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

         EXEC rdt.rdtSetFocusField @nMobile, 7 -- ID

         -- (james12)
         SET @nNoOfTry = 0

         -- Go to OPT & ID screen
         SET @nScn  = @nScn_ID
         SET @nStep = @nStep_ID

         IF rdt.RDTGetConfig( @nFunc, 'SkipIDOPTScn', @cStorer) = '1'
         BEGIN
            SET @cOutField15 = ''
            GOTO Step_ID
         END
      END
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
               SET @nQTY = 0

               -- Standard decode
               IF @cDecodeSP = '1'
               BEGIN
                  EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCheckStorer, @cFacility, @cBarcode,
                     @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                     @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                     @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                     @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                     @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT

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
               SET @cStorer = @cCheckStorer
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
         SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorer)

         IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   --SOS320895
         BEGIN
            EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cLabel2Decode
            ,@c_Storerkey  = @cStorer
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
         SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)
         IF @cDecodeSP = '0'
            SET @cDecodeSP = ''

         IF @cDecodeSP <> ''
         BEGIN
            SET @cBarcode = @cInField03
            SET @cUPC = ''
            SET @nQTY = 0
            
            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode,
                  @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                  @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                  @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                  @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                  @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT

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
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cBarcode, @cCCRefNo, @cCCSheetNo,
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
         EXEC dbo.nspg_GETSKU @cStorer, @cNewSKU OUTPUT, @b_success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @b_success = 0
         BEGIN
            SET @nErrNo = 62120
            SET @cErrMsg = rdt.rdtgetmessage( 62120, @cLangCode, 'DSP') -- 'Invalid SKU'
            GOTO SKU_Add_Sku_Fail
         END
      END
      -- SHONG001 (End)

      -- Get default UOM
      SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

      SELECT TOP 1
         @cNewSKUDescr = SKU.DESCR,
         @nNewCaseCnt  = PAC.CaseCnt,
         @cNewCaseUOM  = CASE WHEN PAC.CaseCnt > 0
                           THEN PAC.PACKUOM1
                         ELSE '' END,
         @cNewEachUOM  = PAC.PACKUOM3,
         @cNewPPK      = CASE WHEN SKU.PrePackIndicator = '2'
                           THEN 'PPK:' + CAST( SKU.PackQtyIndicator AS NVARCHAR( 2))
                         ELSE '' END,
         @nPUOM_Div = CAST( IsNULL(
         CASE @cPUOM
            WHEN '2' THEN PAC.CaseCNT
            WHEN '3' THEN PAC.InnerPack
            WHEN '6' THEN PAC.QTY
            WHEN '1' THEN PAC.Pallet
            WHEN '4' THEN PAC.OtherUnit1
            WHEN '5' THEN PAC.OtherUnit2
         END, 1) AS INT)
      FROM dbo.SKU SKU (NOLOCK)
      INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorer
      AND   SKU.SKU = @cNewSKU

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62121
         SET @cErrMsg = rdt.rdtgetmessage( 62121, @cLangCode, 'DSP') -- 'SKU Not Found'
         GOTO SKU_Add_Sku_Fail
      END

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cNewSKU, 'RDTDefaultUOM', @cStorer)

      -- Set cursor
      IF @cNewSKUSetFocusAtEA = '1'
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 8
      END
      ELSE
      BEGIN
         IF @nNewCaseCnt > 0
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 8   -- QTY (EA)
      END

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
      BEGIN
         SET @nErrNo = 66842
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO SKU_Add_Sku_Fail
      END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @nPQTY = 0
         SET @nMQTY = @nQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit
         SET @cFieldAttr08 = '' -- @nPQTY
      END
         
      -- If SKUCONFIG setup
      IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
        JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
            WHERE S.StorerKey = @cStorer
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
         SET @cOutField06 = @nPQTY                            -- QTY (CS)
         SET @cOutField07 = @cNewCaseUOM                  -- UOM (CS)
         SET @cOutField08 = @nMQTY      -- QTY (EA)
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
              ' @tExtValidate, @cExtendedInfo OUTPUT '
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
            ' @tExtValidate   VariableTable READONLY, ' +
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorer,
            @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel,
            @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @tExtValidate, @cExtendedInfo OUTPUT

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
      IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorer) = '1'
      BEGIN
         SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU
         SET @cOutField03 = 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16)
      END
      ELSE
      BEGIN
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
      END

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
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
            WHERE S.StorerKey = @cStorer
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
         WHERE S.StorerKey = @cStorer
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
         -- (james25)
         IF @cShowCaseCnt = '1'
            SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(6)) + '/' + CAST( @nCaseCnt AS NVARCHAR( 4))
         ELSE
            SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(10))   -- QTY (CS) -- (ChewKP01)

     SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS)
       SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP01)
         SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
      END

      -- (james14)
      SET @cSKUCountDefaultOpt = ''
      SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorer)
      IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
         SET @cSKUCountDefaultOpt = ''

      SET @cOutField08 = @cID
      SET @cOutField09 = @cLottable01
      SET @cOutField10 = @cLottable02
      SET @cOutField11 = @cLottable03
      SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
      SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14)
--    SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
      SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
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
      WHERE SKU.StorerKey = @cStorer
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

         -- Set cursor
         IF @cNewSKUSetFocusAtEA = '1'
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 8
         END
         ELSE
         BEGIN
            IF @nNewCaseCnt > 0
               EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 8   -- QTY (EA)
         END

         GOTO SKU_Add_Qty_Fail
      END

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
         @cCCRefNo, @cStorer, @cNewSKU, 'PRE', -- Codelkup.Short
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
         @cLottable01  OUTPUT,
         @cLottable02      OUTPUT,
         @cLottable03      OUTPUT,
         @dLottable04      OUTPUT,
         @dLottable05      OUTPUT,
         @cHasLottable     OUTPUT,
         @nSetFocusField   OUTPUT,
         @nErrNo           OUTPUT,
         @cErrMsg          OUTPUT

      IF ISNULL(@cErrMsg, '') <> ''
         GOTO SKU_Add_Qty_Fail

      -- Initiate next screen var
      IF @cHasLottable = '1'
      BEGIN
         -- Clear all outfields
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

         -- Initiate labels
         SELECT
            @cOutField01 = 'Lottable01:',
            @cOutField03 = 'Lottable02:',
            @cOutField05 = 'Lottable03:',
            @cOutField07 = 'Lottable04:',
            @cOutField09 = 'Lottable05:'

         -- Populate labels and lottables
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr02 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField01 = @cLotLabel01,
                   @cOutField02 = ISNULL(@cLottable01, '')
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
            BEGIN
            SET @cFieldAttr04 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField03 = @cLotLabel02,
                   @cOutField04 = ISNULL(@cLottable02, '')
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
             SET @cFieldAttr06 = 'O'
         END
         ELSE
         BEGIN
           SELECT @cOutField05 = @cLotLabel03,
                  @cOutField06 = ISNULL(@cLottable03, '')
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O'
         END
         ELSE
         BEGIN
            SELECT  @cOutField07 = @cLotLabel04,
                    @cOutField08 = RDT.RDTFormatDate(ISNULL(@dLottable04, ''))
         END

         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
         BEGIN
            SET @cFieldAttr10 = 'O'
         END
         ELSE
         BEGIN
            -- Lottable05 is usually RCP_DATE
            IF @cLottable05_Code = 'RCP_DATE'
            BEGIN
               SET @dLottable05 = GETDATE()
            END

            SELECT
               @cOutField09 = @cLotLabel05,
               @cOutField10 = RDT.RDTFormatDate( @dLottable05)
         END

         EXEC rdt.rdtSetFocusField @nMobile, 1   -- Lottable01 value

         -- Go to next screen
         SET @nScn  = @nScn_SKU_Add_Lottables
         SET @nStep = @nStep_SKU_Add_Lottables
      END -- End of @cHasLottable = '1'

      IF @cHasLottable = '0'
      BEGIN
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
         IF dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer) <> '0'
            EXECUTE rdt.rdt_CycleCount_InsertCCDetail
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cStorer,
               @cNewSKU,
               '',            -- No UCC
               '',            -- No LOT generated yet
               @cLOC,         -- Current LOC
               @cID,          -- Entered ID, it can be blank
               @fConvQTY,
               '',            -- Lottable01
               '',            -- Lottable02
               '',    -- Lottable03
               NULL,          -- Lottable04
               NULL,          -- Lottable05
               @cUserName,
               @cLangCode,
               @cCCDetailKey OUTPUT,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT   -- screen limitation, 20 char max
         ELSE
            EXECUTE rdt.rdt_CycleCount_InsertCCDetail
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cStorer,
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
               @cUserName,
               @cLangCode,
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
         WHERE SKU.StorerKey = @cStorer
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
         IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorer) = '1'
         BEGIN
            SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU
            SET @cOutField03 = 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16)
         END
         ELSE
         BEGIN
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
         END

         SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)

         -- If config turned on and skuconfig not setup then prompt error
         IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
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
               WHERE S.StorerKey = @cStorer
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
            WHERE S.StorerKey = @cStorer
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
            -- (james25)
            IF @cShowCaseCnt = '1'
               SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(6)) + '/' + CAST( @nCaseCnt AS NVARCHAR( 4))
            ELSE
               SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(10))   -- QTY (CS) -- (ChewKP01)

            SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS)
            SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP01)
            SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
         END

         -- (james14) --IN00137901
         SET @cSKUCountDefaultOpt = ''
         SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorer)
         IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
            SET @cSKUCountDefaultOpt = ''

         SET @cOutField08 = @cID
         SET @cOutField09 = ''   -- Lottable01
         SET @cOutField10 = ''   -- Lottable02
         SET @cOutField11 = ''   -- Lottable03             SET @cOutField12 = ''   -- Lottable04
         SET @cOutField13 = ''   -- Lottable05
         SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14) --IN00137901
--       SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
         SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
                                 THEN RIGHT( SPACE(4) + CAST( @nCntQTY AS NVARCHAR( 4)), 4)
                                 ELSE CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4))
                                 END

         -- Go to SKU (Main) screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END -- End of @cHasLottable = '0'
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
         @cCCRefNo, @cStorer, @cNewSKU, 'POST', -- Codelkup.Short
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

      IF @cExtendedValidSP <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
                     ' @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, ' +
                     ' @cLOC, @cID, @cUCC, @cSKU, @nQty, @cNewLottable01, @cNewLottable02, @cNewLottable03, @cNewLottable04, @cNewLottable05, ' +
                     ' @tExtValidate, @nSetFocusField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
                 ' @nMobile            INT,           ' +
                 ' @nFunc              INT,           ' +
                 ' @cLangCode          NVARCHAR( 3),  ' +
                 ' @nStep              INT,           ' +
                 ' @nAfterStep         INT,           ' +
                 ' @nInputKey          INT,           ' +
                 ' @cFacility          NVARCHAR( 5),  ' +
                 ' @cStorerKey         NVARCHAR( 15), ' +
                 ' @cCCRefNo           NVARCHAR( 10), ' +
                 ' @cCCSheetNo         NVARCHAR( 10), ' +
                 ' @nCCCountNo         INT,           ' +
                 ' @cZone1             NVARCHAR( 10), ' +
                 ' @cZone2             NVARCHAR( 10), ' +
                 ' @cZone3             NVARCHAR( 10), ' +
                 ' @cZone4             NVARCHAR( 10), ' +
                 ' @cZone5             NVARCHAR( 10), ' +
                 ' @cAisle             NVARCHAR( 10), ' +
                 ' @cLevel             NVARCHAR( 10), ' +
                 ' @cLOC               NVARCHAR( 10), ' +
                 ' @cID                NVARCHAR( 18), ' +
                 ' @cUCC               NVARCHAR( 20), ' +
                 ' @cSKU               NVARCHAR( 20), ' +
                 ' @nQty               INT,           ' +
                 ' @cNewLottable01     NVARCHAR( 18), ' +
                 ' @cNewLottable02     NVARCHAR( 18), ' +
                 ' @cNewLottable03     NVARCHAR( 18), ' +
                 ' @cNewLottable04     NVARCHAR( 18),      ' +
                 ' @cNewLottable05     NVARCHAR( 18),      ' +
                 ' @tExtValidate       VariableTable READONLY, ' +
                 ' @nSetFocusField     INT           OUTPUT,   ' +
                 ' @nErrNo             INT           OUTPUT,   ' +
                 ' @cErrMsg            NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorer,
              @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel,
              @cLOC, @cID, @cUCC, @cSKU, @nQty, @cNewLottable01, @cNewLottable02, @cNewLottable03, @cNewLottable04, @cNewLottable05,
            @tExtValidate,@nSetFocusField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF ISNULL(@cErrMsg, '') <> ''
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, @nSetFocusField
            GOTO SKU_Add_Lottables_Fail
         END
      END


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
      EXECUTE rdt.rdt_CycleCount_InsertCCDetail
         @cCCRefNo,
         @cCCSheetNo,
         @nCCCountNo,
         @cStorer,
         @cNewSKU,
         '',            -- No UCC
         '',            -- No LOT generated yet
         @cLOC,         -- Current LOC
         @cID,          -- Entered ID, it can be blank
         @nConvQTY,
         @cNewLottable01,
         @cNewLottable02,
         @cNewLottable03,
         @dNewLottable04,
         @dNewLottable05,
         @cUserName,
         @cLangCode,
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
      WHERE SKU.StorerKey = @cStorer
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

      -- Prepare SKU (Main) screen var
      SET @cOutField01 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cSKU END
      SET @cOutField02 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20) END
      IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorer) = '1'          BEGIN
         SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU
         SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16) END
      END
      ELSE
      BEGIN
         SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 40) END
      END

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
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
            WHERE S.StorerKey = @cStorer
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
         WHERE S.StorerKey = @cStorer
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
         @c_errmsg  = @c_errmsg     OUTPUT

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
      SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorer)
      IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
         SET @cSKUCountDefaultOpt = ''

      SET @cOutField08 = @cID
      SET @cOutField09 = @cLottable01
      SET @cOutField10 = @cLottable02
      SET @cOutField11 = @cLottable03
      SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
      SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14)--IN00137901
--    SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
      SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
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

     SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)

      -- Set cursor
      IF @cNewSKUSetFocusAtEA = '1'
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 8
      END
      ELSE
      BEGIN
         IF @nNewCaseCnt > 0
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 8   -- QTY (EA)
      END

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
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
          WHERE S.StorerKey = @cStorer
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

      -- (james26)
      IF @cExtendedInfoSP <> '' AND
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
              ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
              ' @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, ' +
              ' @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
              ' @tExtValidate, @cExtendedInfo OUTPUT '
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
            ' @cLevel    NVARCHAR( 10), ' +
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
            ' @tExtValidate   VariableTable READONLY, ' +
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorer,
            @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel,
            @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @tExtValidate, @cExtendedInfo OUTPUT

         IF @cExtendedInfo <> ''
            SET @cOutField15 = @cExtendedInfo
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

      -- Validate QTY keyed in    
      IF @cSKUEditQTYNotAllowBlank = '1'
      BEGIN
         IF ISNULL( @cNewCaseQTY, '') = '' AND ISNULL( @cNewEachQTY, '') = ''
         BEGIN    
            SET @nErrNo = 77734    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty    
            GOTO SKU_Edit_Qty_Fail    
         END   
      END      

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

         -- Check Case QTY format    
         IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'NewCaseQTY', @cNewCaseQTY) = 0    
         BEGIN    
            SET @nErrNo = 77730    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty    
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

         -- Check Each QTY format    
         IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'NewEachQTY', @cNewEachQTY) = 0    
         BEGIN    
            SET @nErrNo = 77731    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty    
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
         IF dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer) <> '0'
            EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cCCDetailKey,
               @fConvQTY,
               @cUserName,
               @cLangCode,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT   -- screen limitation, 20 char max
         ELSE
            EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cCCDetailKey,
               @nConvQTY,
               @cUserName,
               @cLangCode,
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
         WHERE SKU.StorerKey = @cStorer
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
            EXECUTE rdt.rdt_CycleCount_GetCCDetail
               @cCCRefNo, @cCCSheetNo, @nCCCountNo,
               @cStorer       OUTPUT, -- Shong001
               @cLOC,
               @cID_In,
               @cWithQtyFlag, -- SOS79743
               @cCCDetailKey  OUTPUT,
               @cCountedFlag  OUTPUT,
               @cSKU          OUTPUT,
               @cLOT          OUTPUT,
               @cID           OUTPUT,
               @cLottable01   OUTPUT,
               @cLottable02   OUTPUT,
               @cLottable03   OUTPUT,
               @dLottable04   OUTPUT,
               @dLottable05   OUTPUT,
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
--(jamesxxxxx)


--         SET @nCaseQTY = @nNewCaseQTY
--         SET @nEachQTY = @nNewEachQTY
--         SET @cCountedFlag = '[C]'      -- (jamesxxxxx)

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
      IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorer) = '1'
      BEGIN
         SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU
         SET @cOutField03 = 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16)
      END
      ELSE
      BEGIN
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
      END

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
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
            WHERE S.StorerKey = @cStorer
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
         WHERE S.StorerKey = @cStorer
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
         -- (james25)
         IF @cShowCaseCnt = '1'
            SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(6)) + '/' + CAST( @nCaseCnt AS NVARCHAR( 4))
         ELSE
            SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR( 10))   -- QTY (CS) -- (ChewKP01)

         SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS) + [C]
         SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR( 10))   -- QTY (EA) -- (ChewKP01)
         SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
      END

      -- (james14)-- IN00137901
      SET @cSKUCountDefaultOpt = ''
      SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorer)
      IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
         SET @cSKUCountDefaultOpt = ''

      SET @cOutField08 = @cID
      SET @cOutField09 = @cLottable01
      SET @cOutField10 = @cLottable02
      SET @cOutField11 = @cLottable03
      SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
      SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14)  -- IN00137901
--    SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
      SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
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

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
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
            WHERE S.StorerKey = @cStorer
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
         WHERE S.StorerKey = @cStorer
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
         -- (james25)
         IF @cShowCaseCnt = '1'
            SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(6)) + '/' + CAST( @nCaseCnt AS NVARCHAR( 4))
         ELSE
            SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR( 10))   -- QTY (CS) -- (ChewKP01)

         SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS)
         SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR( 10))   -- QTY (EA) -- (ChewKP01)
         SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
      END

      -- (james14)
      SET @cSKUCountDefaultOpt = ''
      SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorer)
      IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
         SET @cSKUCountDefaultOpt = ''

      SET @cOutField08 = @cID
      SET @cOutField09 = @cLottable01
      SET @cOutField10 = @cLottable02
      SET @cOutField11 = @cLottable03
      SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
      SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14)
--    SET @cOutField15 = CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4)) -- (MaryVong01)
      SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
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
     SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)
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

/************************************************************************************
Step_SINGLE_SKU_Sku_Scan. Scn = 677. Screen 15.
   LOC (field01)
   ID          (field02)
   SKU/UPC     (field03) - Input
************************************************************************************/
Step_SINGLE_SKU_Sku_Scan:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
     SET @cNewSKU = @cInField03
      SET @cLabel2Decode = @cInField03

      -- Retain the key-in value
      SET @cOutField03 = @cNewSKU

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

      -- Validate SKU
      IF @cNewSKU = '' OR @cNewSKU IS NULL
      BEGIN
         SET @nErrNo = 62156
         SET @cErrMsg = rdt.rdtgetmessage( 62156, @cLangCode, 'DSP') -- 'SKU/UPC req'
         GOTO SINGLE_SKU_Sku_Scan_Fail
      END


      -- SHONG001 (Start)
      DECLARE @t_Storer2 TABLE(StorerKey NVARCHAR(15))

      INSERT INTO @t_Storer2 (StorerKey)
      SELECT Distinct StorerKey
      FROM   CCDETAIL WITH (NOLOCK)
      WHERE  CCKey = @cCCRefNo
      AND    StorerKey <> ''

      -- Add eventlog (yeekung01)
      EXEC RDT.rdt_STD_EventLog
   @cActionType   = '7',
         @nFunctionID   = @nFunc,
         @nMobileNo     = @nMobile,
         @cStorerKey    = @cStorer,
         @cFacility     = @cFacility,
         @cCCKey        = @cCCRefNo,
         @cLocation     = @cLOC,
         @cID           = @cID,
         @cSKU          = @cNewSKU,
         @cUCC          = @cUCC

      -- Validate SKU
      -- Check if SKU, alt sku, manufacturer sku, upc belong to the storer
      SET @b_success = 0
      IF (SELECT COUNT(*) FROM @t_Storer2) > 1
      BEGIN
         SET @cCheckStorer = ''

         DECLARE CUR_CheckSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT StorerKey
         FROM   @t_Storer2

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
                  GOTO SINGLE_SKU_Sku_Scan_Fail
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
                     @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT

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
                     ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
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
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCheckStorer, @cBarcode, @cCCRefNo, @cCCSheetNo,
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
               SET @cStorer = @cCheckStorer
               BREAK
            END

            FETCH NEXT FROM CUR_CheckSKU INTO @cCheckStorer
         END
         IF @b_success = 0
         BEGIN
            SET @nErrNo = 62157
            SET @cErrMsg = rdt.rdtgetmessage( 62157, @cLangCode, 'DSP') -- 'Invalid SKU'
            GOTO SINGLE_SKU_Sku_Scan_Fail
         END
         CLOSE CUR_CheckSKU
      DEALLOCATE CUR_CheckSKU
      END
      ELSE
      BEGIN
         SET @cDecodeLabelNo = ''
         SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorer)

         IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   --SOS320895
         BEGIN
            EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cLabel2Decode
            ,@c_Storerkey  = @cStorer
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
               GOTO SINGLE_SKU_Sku_Scan_Fail
            END

            SET @cNewSKU = @c_oFieled01
         END

         -- (james21)
         SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)
         IF @cDecodeSP = '0'
            SET @cDecodeSP = ''

         IF @cDecodeSP <> ''
         BEGIN
            SET @cBarcode = @cInField03
            SET @cUPC = ''

            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode,
                  @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                  @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                  @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                  @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                  @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT

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
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
               SET @cSQLParam =
                  ' @nMobile    INT,           ' +
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
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cBarcode, @cCCRefNo, @cCCSheetNo,
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
         EXEC dbo.nspg_GETSKU @cStorer, @cNewSKU OUTPUT, @b_success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @b_success = 0
         BEGIN
            SET @nErrNo = 62157
            SET @cErrMsg = rdt.rdtgetmessage( 62157, @cLangCode, 'DSP') -- 'Invalid SKU'
            GOTO SINGLE_SKU_Sku_Scan_Fail
         END
      END
      -- SHONG001 (End)

      IF NOT EXISTS (SELECT 1
                     FROM dbo.SKU SKU (NOLOCK)
                     INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
                     WHERE SKU.StorerKey = @cStorer
                     AND   SKU.SKU = @cNewSKU )
      BEGIN
         SET @nErrNo = 62158
         SET @cErrMsg = rdt.rdtgetmessage( 62158, @cLangCode, 'DSP') -- 'SKU Not Found'
         SET @cOutField03 = '' -- SKU
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO SINGLE_SKU_Sku_Scan_Fail
      END

/*    (james19)
      SELECT TOP 1
         @cNewSKUDescr = SKU.DESCR,
         @cNewEachUOM  = SUBSTRING( PAC.PACKUOM3, 1, 3)
      FROM dbo.SKU SKU (NOLOCK)
      INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorer
      AND   SKU.SKU = @cNewSKU
*/
      SELECT TOP 1
         @cNewSKUDescr = SKU.DESCR,
         @cNewEachUOM  = PAC.PACKUOM3
      FROM dbo.SKU SKU (NOLOCK)
      INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorer
      AND   SKU.SKU = @cNewSKU

      SET @cNewSKUDescr1 = SUBSTRING( @cNewSKUDescr,  1, 20)
      SET @cNewSKUDescr2 = SUBSTRING( @cNewSKUDescr, 21, 40)

      -- Check if SKU+LOC+ID used by other users
      IF EXISTS ( SELECT 1
                  FROM RDT.RDTCCLock WITH (NOLOCK)
                  WHERE CCKey = @cCCRefNo
                  AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
                  AND   AddWho <> @cUserName
         AND   SKU = @cSKU
                  AND   Loc = @cLOC
                  AND   Id  = @cID
                  AND   (Status < '9') ) -- Status:'0'=not yet process; '1'=partial update qty
      BEGIN
         SET @nErrNo = 62160
         SET @cErrMsg = rdt.rdtgetmessage( 62160, @cLangCode, 'DSP') -- 'SKU In Use'
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU/UPC
         GOTO SINGLE_SKU_Sku_Scan_Fail
      END

      -- (Vicky03) - Start
      SELECT @nEachQTY =
         CASE WHEN @nCCCountNo = 1 THEN ISNULL(SUM(CountedQty), 0)
         WHEN @nCCCountNo = 2 THEN ISNULL(SUM(CountedQty), 0)
         WHEN @nCCCountNo = 3 THEN ISNULL(SUM(CountedQty), 0)
      ELSE 0 END
      FROM RDT.RDTCCLOCK WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
         AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND   LOC = @cLOC
         AND   ID = @cID
         AND   SKU = @cNewSKU
         AND   Status > '0'
         AND   1 = CASE WHEN @nCCCountNo = 1 AND CountNo = '1' THEN 1
                   WHEN @nCCCountNo = 2 AND CountNo = '2' THEN 1
                   WHEN @nCCCountNo = 3 AND CountNo = '3' THEN 1
                ELSE 0 END
    AND   AddWho = @cUsername
      -- (Vicky03) - End

      -- (Vicky03) - Start
      SELECT @nQTY =
      CASE WHEN @nCCCountNo = 1 THEN ISNULL(SUM(CountedQty), 0)
         WHEN @nCCCountNo = 2 THEN ISNULL(SUM(CountedQty), 0)
         WHEN @nCCCountNo = 3 THEN ISNULL(SUM(CountedQty), 0)
         ELSE 0 END
      FROM RDT.RDTCCLOCK WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
         AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND   LOC = @cLOC
         AND   ID = @cID
  AND   Status > '0'           AND   1 = CASE WHEN @nCCCountNo = 1 AND CountNo = '1' THEN 1
                   WHEN @nCCCountNo = 2 AND CountNo = '2' THEN 1
                   WHEN @nCCCountNo = 3 AND CountNo = '3' THEN 1
                   ELSE 0 END
         AND   AddWho = @cUsername
      -- (Vicky03) - End

      -- Initialize Lottables
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = NULL
      SET @dLottable05 = NULL

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

      SET @cErrMsg = ''

      -- Get Lottables Details
      EXECUTE rdt.rdt_CycleCount_GetLottables
         @cCCRefNo, @cStorer, @cNewSKU, 'PRE', -- Codelkup.Short
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
         GOTO SINGLE_SKU_Sku_Scan_Fail

      -- Initiate next screen var
      IF @cHasLottable = '1'
      BEGIN
         -- Clear all outfields
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

         -- Initiate labels
         SELECT
            @cOutField01 = 'Lottable01:',
            @cOutField03 = 'Lottable02:',
            @cOutField05 = 'Lottable03:',
            @cOutField07 = 'Lottable04:',
            @cOutField09 = 'Lottable05:'

         --Note: Not to auto populate lottables value; user can decide which lottables to scan in (james)
         -- Populate labels and lottables
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr02 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField01 = @cLotLabel01
            IF ISNULL(@cLottable01, '') <> ''
               SELECT @cOutField02 = @cLottable01
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr04 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField03 = @cLotLabel02
            IF ISNULL(@cLottable02, '') <> ''
               SELECT @cOutField04 = @cLottable02
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
             SET @cFieldAttr06 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField05 = @cLotLabel03
            IF ISNULL(@cLottable03, '') <> ''
               SELECT @cOutField06 = @cLottable03
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField07 = @cLotLabel04
            IF ISNULL(@dLottable04, '') <> ''
               SELECT @cOutField08 = rdt.rdtFormatDate(@dLottable04)
         END

         EXEC rdt.rdtSetFocusField @nMobile, 1   -- Lottable01 value

         -- Go to next screen
         SET @nScn  = @nScn_SINGLE_SKU_Add_Lottables
         SET @nStep = @nStep_SINGLE_SKU_Add_Lottables
      END -- End of @cHasLottable = '1'

      IF @cHasLottable = '0'
      BEGIN
         SET @cLockedByDiffUser = ''
         SET @cFoundLockRec     = ''
         SET @cLockCCDetailKey  = ''
         EXECUTE rdt.rdt_CycleCount_FindCCLock
            @nMobile, @cCCRefNo, @cCCSheetNo, @cStorer, @cUserName,
            @cNewSKU,
            @cLOC,
            @cID,
            '',      -- Lottable01
            '',      -- Lottable02
            '',      -- Lottable03
            NULL,  -- Lottable04
            @cWithQtyFlag,
            @cFoundLockRec     OUTPUT,
--            @cLockCCDetailKey  OUTPUT
            @nRowRef           OUTPUT

         IF @cSheetNoFlag = 'Y'
         BEGIN
            IF @cFoundLockRec = 'Y'
            BEGIN
               UPDATE RDT.RDTCCLock WITH (ROWLOCK)
               SET   CountedQty = CountedQty + 1
--               WHERE Mobile = @nMobile
--               AND   CCKey = @cCCRefNo
--               AND   SheetNo = @cCCSheetNo
--               AND   StorerKey = @cStorer
--               AND   AddWho = @cUserName
--               AND   Loc = @cLOC
--               AND   Id = @cID
--               AND   SKU = @cNewSKU
--               AND   CCDetailKey = @cLockCCDetailKey
--               AND   (Status = '0' OR Status = '1')
               WHERE RowRef = @nRowRef
            END
            ELSE
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_InsertCCLock
                  @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                  @cNewSKU,    -- @cSKU,
                  '',          -- @cLOT,
                  @cLOC,
                  @cID,
                  1,           -- CountedQTY
                  '',          -- @cLottable01
                  '',       -- @cLottable02
                  '',          -- @cLottable03
                  NULL,        -- @dLottable04
                  NULL,        -- @dLottable05
                  '',          -- @cRefNo = 'Scn15.ByShtNo' for tracking
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO SINGLE_SKU_Sku_Scan_Fail
            END
         END
         -- IF @cSheetNoFlag <> 'Y'
         ELSE
         BEGIN
         IF @cFoundLockRec = 'Y'
            BEGIN
               UPDATE RDT.RDTCCLock WITH (ROWLOCK)
               SET   CountedQty = CountedQty + 1
--               WHERE Mobile = @nMobile
--               AND   CCKey = @cCCRefNo
--               AND   StorerKey = @cStorer
--         AND   AddWho = @cUserName
--               AND   Loc = @cLOC
--               AND   Id = @cID
--               AND   SKU = @cNewSKU
--               AND   CCDetailKey = @cLockCCDetailKey
--               AND   (Status = '0' OR Status = '1')
            WHERE RowRef = @nRowRef
            END
            ELSE
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_InsertCCLock
                  @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                  @cNewSKU,    -- @cSKU,
                  '',          -- @cLOT,
                  @cLOC,
                  @cID,
                  1,           -- CountedQTY
                  '',          -- @cLottable01
                  '',          -- @cLottable02
 '',          -- @cLottable03
                  NULL,        -- @dLottable04
                  NULL,        -- @dLottable05
                  '',          -- @cRefNo = 'Scn15.NoShtNo' for tracking
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO SINGLE_SKU_Sku_Scan_Fail
            END
         END

         -- Initialise
         SET @nEachQTY = 0
         SET @nQTY = 0

         -- Incremental Counted Qty of the SKU in the specified LOC + ID
         IF @nCCCountNo = 1
         BEGIN
            SELECT @nEachQTY = 1 + ISNULL(SUM(Qty), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            AND   SKU = @cNewSKU

            --Total Qty of the specified LOC + ID
            SELECT @nQTY = 1 + ISNULL(SUM(Qty), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
         END

         IF @nCCCountNo = 2
         BEGIN
            SELECT @nEachQTY = 1 + ISNULL(SUM(Qty_Cnt2), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            AND   SKU = @cNewSKU

            --Total Qty of the specified LOC + ID
            SELECT @nQTY = 1 + ISNULL(SUM(Qty_Cnt2), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
         END

         IF @nCCCountNo = 3
         BEGIN
            SELECT @nEachQTY = 1 + ISNULL(SUM(Qty_Cnt3), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            AND   SKU = @cNewSKU

            --Total Qty of the specified LOC + ID
            SELECT @nQTY = 1 + ISNULL(SUM(Qty_Cnt3), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
         END

         -- If not match then initialise the qty as 1
         IF @nEachQTY = 0 SET @nEachQTY = 1
         IF @nQTY = 0 SET @nQTY = 1

         -- Set variables
         SET @cSKU      = @cNewSKU
         SET @cSKUDescr = @cNewSKUDescr1 + @cNewSKUDescr2
         SET @cEachUOM  = @cNewEachUOM
         SET @cEachUOM  = @cNewEachUOM

         -- Re-initialize lottables
         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = NULL
         SET @dLottable05 = NULL

         -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID
         SET @cOutField03 = ''
         SET @cOutField04 = @cSKU
         SET @cOutField05 = SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField06 = SUBSTRING( @cSKUDescr, 20, 40)
         SET @cOutField07 = CAST( @nEachQTY AS NVARCHAR( 5)) -- SKU QTY
         SET @cOutField08 = @cEachUOM                       -- UOM (master unit)
         SET @cOutField09 = CAST( @nQTY AS NVARCHAR( 5))     -- ID QTY
         SET @cOutField10 = @cEachUOM                       -- UOM (master unit)

         EXEC rdt.rdtSetFocusField @nMobile, 3  -- SKU/UPC

         SET @cEscSKU = ''

         -- Go to Screen SINGLE SKU-IncreaseQTY
         SET @nScn = @nScn_SINGLE_SKU_Increase_Qty
         SET @nStep = @nStep_SINGLE_SKU_Increase_Qty
      END -- End of @cHasLottable = '0'
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Re-initialize lottables
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = NULL
      SET @dLottable05 = NULL

      -- Press ESC treat as Empty loc
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT
         CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorer ELSE StorerKey END,
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
      FETCH NEXT FROM CUR_LOOP INTO @cStorer, @cSKU, @cLOT, @cStatus, @nSYSQTY, @cSYSID, @cCCDetailKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- If found, update CCDETAIL
         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cCCDetailKey,
            0,               -- empty loc
            @cUserName,
            @cLangCode,
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

         FETCH NEXT FROM CUR_LOOP INTO @cStorer, @cSKU, @cLOT, @cStatus, @nSYSQTY, @cSYSID, @cCCDetailKey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      -- Set back values
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
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

      EXEC rdt.rdtSetFocusField @nMobile, 7 -- ID

      -- (james12)
      SET @nNoOfTry = 0

      -- Go to ID screen
      SET @nScn  = @nScn_ID
      SET @nStep = @nStep_ID

      IF rdt.RDTGetConfig( @nFunc, 'SkipIDOPTScn', @cStorer) = '1'
      BEGIN
         SET @cOutField15 = ''
         GOTO Step_ID
      END
   END
   GOTO Quit

   SINGLE_SKU_Sku_Scan_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = '' -- SKU/UPC
   END
END
GOTO Quit

/************************************************************************************
Step_SINGLE_SKU_Add_Lottables. Scn = 678. Screen 16.
   LOTTABLE01Label (field01)     LOTTABLE01 (field02) - Input field
   LOTTABLE02Label (field03)     LOTTABLE02 (field04) - Input field
   LOTTABLE03Label (field05)     LOTTABLE03 (field06) - Input field
   LOTTABLE04Label (field07)     LOTTABLE04 (field08) - Input field
************************************************************************************/
Step_SINGLE_SKU_Add_Lottables:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cNewLottable01 = @cInField02
      SET @cNewLottable02 = @cInField04
      SET @cNewLottable03 = @cInField06
      SET @cNewLottable04 = @cInField08

      -- Retain the key-in value
      SET @cOutField02 = @cNewLottable01
      SET @cOutField04 = @cNewLottable02
      SET @cOutField06 = @cNewLottable03
      SET @cOutField08 = @cNewLottable04

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

      SET @cErrMsg = ''

      IF rdt.rdtIsValidDate(@cNewLottable04) = 1 --valid date
         --SET @dNewLottable04 = CAST( @cNewLottable04 AS DATETIME) (james22)
         SET @dNewLottable04 = RDT.rdtConvertToDate( @cNewLottable04)
      ELSE
         SET @dNewLottable04 = NULL

      -- Get Lottables Details
      EXECUTE rdt.rdt_CycleCount_GetLottables
         @cCCRefNo, @cStorer, @cNewSKU, 'POST', -- Codelkup.Short
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
         @cHasLottable OUTPUT,
         @nSetFocusField   OUTPUT,
         @nErrNo           OUTPUT,
         @cErrMsg          OUTPUT

      IF ISNULL(@cErrMsg, '') <> ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, @nSetFocusField
         GOTO SINGLE_SKU_Add_Lottables_Fail
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
      BEGIN
         IF @cNewLottable01 = '' OR @cNewLottable01 IS NULL
         BEGIN
            SET @nErrNo = 66817
            SET @cErrMsg = rdt.rdtgetmessage( 66817, @cLangCode, 'DSP') -- 'Lottable1 req'
            EXEC rdt.rdtSetFocusField @nMobile, 2
        GOTO SINGLE_SKU_Add_Lottables_Fail
         END
      END

      -- Validate Lottable02
      IF @cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL
      BEGIN
         IF @cNewLottable02 = '' OR @cNewLottable02 IS NULL
         BEGIN
            SET @nErrNo = 66818
            SET @cErrMsg = rdt.rdtgetmessage( 66818, @cLangCode, 'DSP') -- 'Lottable2 req'
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO SINGLE_SKU_Add_Lottables_Fail
      END
      END

      -- Validate Lottable03
      IF @cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL
      BEGIN
         IF @cNewLottable03 = '' OR @cNewLottable03 IS NULL
         BEGIN
            SET @nErrNo = 66819
            SET @cErrMsg = rdt.rdtgetmessage( 66819, @cLangCode, 'DSP') -- 'Lottable3 req'
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO SINGLE_SKU_Add_Lottables_Fail
         END
      END

      -- Validate Lottable04
      IF @cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL
      BEGIN
         -- Validate empty
         IF @cNewLottable04 = '' OR @cNewLottable04 IS NULL
         BEGIN
            SET @nErrNo = 66820
            SET @cErrMsg = rdt.rdtgetmessage( 66820, @cLangCode, 'DSP') -- 'Lottable4 req'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO SINGLE_SKU_Add_Lottables_Fail
         END
         -- Validate date
         IF rdt.rdtIsValidDate( @cNewLottable04) = 0
         BEGIN
            SET @nErrNo = 66821
            SET @cErrMsg = rdt.rdtgetmessage( 66821, @cLangCode, 'DSP') -- 'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO SINGLE_SKU_Add_Lottables_Fail
         END
      END

      IF @cNewLottable04 <> '' AND @cNewLottable04 IS NOT NULL
         --SET @dNewLottable04 = CAST( @cNewLottable04 AS DATETIME) (james22)
         SET @dNewLottable04 = RDT.rdtConvertToDate( @cNewLottable04)
      ELSE
         SET @dNewLottable04 = NULL

      SET @cLockedByDiffUser = ''
      SET @cFoundLockRec     = ''
      SET @cLockCCDetailKey  = ''
      EXECUTE rdt.rdt_CycleCount_FindCCLock
         @nMobile, @cCCRefNo, @cCCSheetNo, @cStorer, @cUserName,
         @cNewSKU,
         @cLOC,
         @cID,
         @cNewLottable01,
         @cNewLottable02,
         @cNewLottable03,
         @dNewLottable04,
         @cWithQtyFlag,
         @cFoundLockRec     OUTPUT,
         @nRowRef           OUTPUT

      IF @cSheetNoFlag = 'Y'
      BEGIN
         IF @cFoundLockRec = 'Y'
         BEGIN
            UPDATE RDT.RDTCCLock WITH (ROWLOCK) SET
               CountedQty = CountedQty + 1
            WHERE RowRef = @nRowRef
         END
         ELSE
         BEGIN
      IF ISNULL(@nRowRef, 0) <> 0
            BEGIN
               SET @cLockCCDetailKey = ''
               SELECT @cLockCCDetailKey = CCDetailKey FROM RDT.RDTCCLOCK WITH (NOLOCK) WHERE RowRef = @nRowRef

               SELECT @nCountedQTY = 1 + ISNULL(QTY, 0)
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
                  AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                  AND CCDetailKey = @cLockCCDetailKey
                  AND Status < '9'
            END
            ELSE
               SET @nCountedQTY = 1

            SET @nErrNo = 0
            SET @cErrMsg = ''
            EXECUTE rdt.rdt_CycleCount_InsertCCLock
               @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
               @cNewSKU,
               '',              -- @cLOT,
               @cLOC,
               @cID,
               @nCountedQTY,    -- CountedQTY
               @cNewLottable01,
               @cNewLottable02,
               @cNewLottable03,
               @dNewLottable04,
               NULL,            -- Lottable05
               '',            -- @cRefNo = 'Scn17.ByShtNo' for tracking
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO SINGLE_SKU_Add_Lottables_Fail
         END
      END
      ELSE
      BEGIN -- IF @cSheetNoFlag <> 'Y'
         IF @cFoundLockRec = 'Y'
         BEGIN
            UPDATE RDT.RDTCCLock WITH (ROWLOCK) SET
               CountedQty = CountedQty + 1
            WHERE RowRef = @nRowRef
         END
         ELSE
         BEGIN
            IF ISNULL(@nRowRef, 0) <> 0
            BEGIN
               SET @cLockCCDetailKey = ''
               SELECT @cLockCCDetailKey = CCDetailKey FROM RDT.RDTCCLOCK WITH (NOLOCK) WHERE RowRef = @nRowRef

               SELECT @nCountedQTY = 1 + ISNULL(QTY, 0)
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
                  AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                  AND CCDetailKey = @cLockCCDetailKey
                  AND Status < '9'
            END
            ELSE
               SET @nCountedQTY = 1

            SET @nErrNo = 0
            SET @cErrMsg = ''
            EXECUTE rdt.rdt_CycleCount_InsertCCLock
               @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
               @cNewSKU,
               '',              -- @cLOT,
               @cLOC,
               @cID,
               1,               -- CountedQTY
               @cNewLottable01,
               @cNewLottable02,
               @cNewLottable03,
               @dNewLottable04,
               NULL,            -- Lottable05
               '',              -- @cRefNo = 'Scn17.NoShtNo' for tracking
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO SINGLE_SKU_Add_Lottables_Fail
         END
      END
--     END -- @cESCSKU <> 'Y'

      -- Initialise
      SET @nEachQTY = 0
      SET @nQTY = 0

      --(james01)
      -- Incremental Counted Qty of the SKU in the specified LOC + ID
      SELECT @nEachQTY = 1 + -- once press enter, consider scan one time
         CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
              WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
              WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
         ELSE 0 END
      FROM dbo.CCDetail WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
      AND   LOC = @cLOC
      AND   ID = @cID
      AND   SKU = @cNewSKU
      AND   Lottable01 = CASE WHEN ISNULL(@cNewLottable01, '') <> '' THEN @cNewLottable01 ELSE Lottable01 END
      AND   Lottable02 = CASE WHEN ISNULL(@cNewLottable02, '') <> '' THEN @cNewLottable02 ELSE Lottable02 END
      AND   Lottable03 = CASE WHEN ISNULL(@cNewLottable03, '') <> '' THEN @cNewLottable03 ELSE Lottable03 END
      AND   Lottable04 = CASE WHEN ISNULL(@dNewLottable04, '') <> '' THEN @dNewLottable04 ELSE Lottable04 END
      GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3

      --Total Qty of the specified LOC + ID
      SELECT @nQTY = 1 + -- once press enter, consider scan one time
         CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
              WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
              WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
         ELSE 0 END
      FROM dbo.CCDetail WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
      AND   LOC = @cLOC
      AND   ID = @cID
      AND   Lottable01 = CASE WHEN ISNULL(@cNewLottable01, '') <> '' THEN @cNewLottable01 ELSE Lottable01 END
      AND   Lottable02 = CASE WHEN ISNULL(@cNewLottable02, '') <> '' THEN @cNewLottable02 ELSE Lottable02 END
      AND   Lottable03 = CASE WHEN ISNULL(@cNewLottable03, '') <> '' THEN @cNewLottable03 ELSE Lottable03 END
      AND   Lottable04 = CASE WHEN ISNULL(@dNewLottable04, '') <> '' THEN @dNewLottable04 ELSE Lottable04 END
      GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3

      -- If lottables not match then initialise the qty as 1
      IF @nEachQTY = 0 SET @nEachQTY = 1
      IF @nQTY = 0 SET @nQTY = 1

      -- Set variables
      SET @cSKU        = @cNewSKU
      SET @cSKUDescr   = @cNewSKUDescr1 + @cNewSKUDescr2
      SET @cEachUOM    = @cNewEachUOM
      SET @cLottable01 = @cNewLottable01
      SET @cLottable02 = @cNewLottable02
      SET @cLottable03 = @cNewLottable03
      SET @dLottable04 = @dNewLottable04

      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''   -- SKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField06 = SUBSTRING( @cSKUDescr, 21, 40)
      SET @cOutField07 = CAST( @nEachQTY AS NVARCHAR( 5)) -- SKU QTY
      SET @cOutField08 = @cEachUOM                       -- UOM (master unit)
      SET @cOutField09 = CAST( @nQTY AS NVARCHAR( 5))     -- ID  QTY
      SET @cOutField10 = @cEachUOM      -- UOM (master unit)

      -- Go to Screen SINGLE SKU-IncreaseQTY
      SET @nScn  = @nScn_SINGLE_SKU_Increase_Qty
      SET @nStep = @nStep_SINGLE_SKU_Increase_Qty
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare previous screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = '' --@cNewSKU
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''

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

      SET @cEscSKU = ''

      -- Go to previous screen
      SET @nScn  = @nScn_SINGLE_SKU_Sku_Scan
      SET @nStep = @nStep_SINGLE_SKU_Sku_Scan
   END
   GOTO Quit

   SINGLE_SKU_Add_Lottables_Fail:
   BEGIN
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Initiate next screen var
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
      END
   END
END
GOTO Quit

/************************************************************************************
Step_SINGLE_SKU_Increase_Qty. Scn = 679. Screen 17.
   SKU (field01) - Input field
************************************************************************************/
Step_SINGLE_SKU_Increase_Qty:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cNewSKU = @cInField03
      SET @cLabel2Decode = @cInField03

      -- Retain the key-in value
      SET @cOutField03 = @cNewSKU

      -- Validate SKU
      IF @cNewSKU = '' OR @cNewSKU IS NULL
      BEGIN
         SET @nErrNo = 66826
         SET @cErrMsg = rdt.rdtgetmessage( 66826, @cLangCode, 'DSP') -- 'SKU/UPC req'
         GOTO SINGLE_SKU_Increase_Qty_Fail
      END

      -- SHONG001 (Start)
      DECLARE @t_Storer3 TABLE(StorerKey NVARCHAR(15))

      INSERT INTO @t_Storer3 (StorerKey)
      SELECT Distinct StorerKey
      FROM   CCDETAIL WITH (NOLOCK)
      WHERE  CCKey = @cCCRefNo
      AND    StorerKey <> ''

      -- Validate SKU
      -- Check if SKU, alt sku, manufacturer sku, upc belong to the storer
      SET @b_success = 0
      IF (SELECT COUNT(*) FROM @t_Storer3) > 1
      BEGIN
         SET @cCheckStorer = ''

         DECLARE CUR_CheckSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT StorerKey
           FROM   @t_Storer3

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
                  GOTO SINGLE_SKU_Increase_Qty_Fail
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
                     @cID       OUTPUT, @cUPC           OUTPUT, @nQTY          OUTPUT,
                     @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                     @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                     @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                     @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT

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
                     ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
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
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCheckStorer, @cBarcode, @cCCRefNo, @cCCSheetNo,
                     @cLOC    OUTPUT, @cID  OUTPUT, @cUCC           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
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
               SET @cStorer = @cCheckStorer
               BREAK
            END

            FETCH NEXT FROM CUR_CheckSKU INTO @cCheckStorer
         END
         IF @b_success = 0
         BEGIN
            SET @nErrNo = 66827
            SET @cErrMsg = rdt.rdtgetmessage( 66827, @cLangCode, 'DSP') -- 'Invalid SKU'
            GOTO SINGLE_SKU_Increase_Qty_Fail
         END
         CLOSE CUR_CheckSKU
         DEALLOCATE CUR_CheckSKU
      END
      ELSE
      BEGIN
         SET @cDecodeLabelNo = ''
         SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorer)

         IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   --SOS320895
         BEGIN
            EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cLabel2Decode
            ,@c_Storerkey  = @cStorer
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
               GOTO SINGLE_SKU_Increase_Qty_Fail
            END

            SET @cNewSKU = @c_oFieled01
         END

         -- (james21)
         SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)
         IF @cDecodeSP = '0'
            SET @cDecodeSP = ''

         IF @cDecodeSP <> ''
         BEGIN
            SET @cBarcode = @cInField03
            SET @cUPC = ''

            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode,
                  @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                  @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                  @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                  @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                  @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT

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
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
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
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cBarcode, @cCCRefNo, @cCCSheetNo,
                  @cLOC        OUTPUT, @cID            OUTPUT, @cUCC           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
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
         EXEC dbo.nspg_GETSKU @cStorer, @cNewSKU OUTPUT, @b_success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @b_success = 0
         BEGIN
            SET @nErrNo = 66827
            SET @cErrMsg = rdt.rdtgetmessage( 66827, @cLangCode, 'DSP') -- 'Invalid SKU'
            GOTO SINGLE_SKU_Increase_Qty_Fail
         END
      END
      -- SHONG001 (End)

      -- Check if SKU, ALTSKU, ManufacturerSKU, UPC belong to the storer
--      SET @b_success = 0
--      EXEC dbo.nspg_GETSKU @cStorer, @cNewSKU OUTPUT, @b_success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
--      IF @b_success = 0
--      BEGIN
--         SET @nErrNo = 66827
--         SET @cErrMsg = rdt.rdtgetmessage( 66827, @cLangCode, 'DSP') -- 'Invalid SKU'
--         GOTO SINGLE_SKU_Increase_Qty_Fail
--      END

      IF NOT EXISTS (SELECT 1
                     FROM dbo.SKU SKU (NOLOCK)
                     INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
                     WHERE SKU.StorerKey = @cStorer
                     AND   SKU.SKU = @cNewSKU )
      BEGIN
         SET @nErrNo = 66828
         SET @cErrMsg = rdt.rdtgetmessage( 66828, @cLangCode, 'DSP') -- 'SKU Not Found'
         SET @cOutField03 = '' -- SKU
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO SINGLE_SKU_Increase_Qty_Fail
      END

      -- Get Zones/Aisle/Level from RDTCCLock table
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
      AND   CCKey = @cCCRefNo
      AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
      AND   AddWho = @cUserName
      AND   Status = '0'

      -- Check any Lottable label setup for the SKU
      SELECT
         @cLotLabel01 = ISNULL(LOTTABLE01LABEL, ''),
         @cLotLabel02 = ISNULL(LOTTABLE02LABEL, ''),
         @cLotLabel03 = ISNULL(LOTTABLE03LABEL, ''),
         @cLotLabel04 = ISNULL(LOTTABLE04LABEL, '')
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   SKU = @cSKU

      IF @cLotLabel01 <> '' OR @cLotLabel02 <> '' OR
         @cLotLabel03 <> '' OR @cLotLabel04 <> ''
      BEGIN
         SET @cHasLottable = '1'
      END
      ELSE
      BEGIN
         SET @cHasLottable = '0'       -- (james10)
      END

--    INSERT INTO TRACEINFO (TRACENAME, TIMEIN, STEP1, STEP2, STEP3, STEP4, STEP5, COL1, COL2, COL3, COL4, COL5)
--    VALUES ('CYCLE_SINGLE', GETDATE(), '@cLotLabel01', '@cLotLabel02', '@cLotLabel03', '@cLotLabel04', '@cHasLottable',
--   @cLotLabel01, @cLotLabel02, @cLotLabel03, @cLotLabel04, @cHasLottable)

       -- Add eventlog (yeekung01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '7',
         @nFunctionID   = @nFunc,
         @nMobileNo     = @nMobile,
       @cStorerKey    = @cStorer,
         @cFacility     = @cFacility,
         @cCCKey        = @cCCRefNo,
         @cLocation     = @cLOC,
         @cID           = @cID,
         @cSKU          = @cNewSKU,
         @cUCC          = @cUCC

      -- Looping here, increase QTY by 1
      IF @cNewSKU = @cSKU
      BEGIN
         -- Increase SKU QTY and ID QTY by 1
         SET @nEachQTY = @nEachQTY + 1
         SET @nQTY = @nQTY + 1

         SET @cLockedByDiffUser = ''
         SET @cFoundLockRec     = ''
         SET @cLockCCDetailKey  = ''

         IF @cHasLottable = '1'
         BEGIN
            EXECUTE rdt.rdt_CycleCount_FindCCLock
               @nMobile, @cCCRefNo, @cCCSheetNo, @cStorer, @cUserName,
               @cNewSKU,
               @cLOC,
               @cID,
               @cLottable01,      -- Lottable01
               @cLottable02,      -- Lottable02
               @cLottable03,      -- Lottable03
               @dLottable04,      -- Lottable04
               @cWithQtyFlag,
               @cFoundLockRec     OUTPUT,
--               @cLockCCDetailKey  OUTPUT
               @nRowRef           OUTPUT
         END
         ELSE
         BEGIN
            EXECUTE rdt.rdt_CycleCount_FindCCLock
               @nMobile, @cCCRefNo, @cCCSheetNo, @cStorer, @cUserName,
               @cNewSKU,
               @cLOC,
               @cID,
               '',      -- Lottable01
               '',      -- Lottable02
               '',      -- Lottable03
               NULL,    -- Lottable04
               @cWithQtyFlag,
               @cFoundLockRec     OUTPUT,
--               @cLockCCDetailKey  OUTPUT
               @nRowRef           OUTPUT
         END

         IF @cFoundLockRec = 'Y'
         BEGIN
            -- Update RDTCCLock
            UPDATE RDT.RDTCCLock WITH (ROWLOCK) SET
               CountedQty = CountedQty + 1
--            WHERE Mobile = @nMobile
--            AND   CCKey = @cCCRefNo
--            AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
--            AND   StorerKey = @cStorer
--            AND   AddWho = @cUserName
--            AND   Loc = @cLOC
--            AND   Id = @cID
--            AND   SKU = @cSKU
--            AND   CCDetailKey = @cLockCCDetailKey
--            AND   (Status = '0' OR Status = '1')
            WHERE RowRef = @nRowRef
         END
         -- Not found any match then insert RDTCCLock
         ELSE
         BEGIN
            IF @cHasLottable = '1'
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_InsertCCLock
                  @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                  @cNewSKU,         -- @cSKU,
                  '',               -- @cLOT,
                  @cLOC,
                  @cID,
                  1,                -- CountedQTY
                  @cLottable01,     -- @cLottable01
                  @cLottable02,     -- @cLottable02
                  @cLottable03,     -- @cLottable03
                  @dLottable04,     -- @dLottable04
                  @dLottable05,     -- @dLottable05
                  'Scn17.QtyDiff', -- @cRefNo = 'Scn17.QtyDiff' for tracking
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
            END
            ELSE
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_InsertCCLock
                  @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                  @cNewSKU,         -- @cSKU,
                  '',               -- @cLOT,
                  @cLOC,
                  @cID,
                  1,                -- CountedQTY
                  '',               -- @cLottable01
                  '',               -- @cLottable02
                  '',       -- @cLottable03
                  NULL,             -- @dLottable04
                  NULL,   -- @dLottable05
                  'Scn17.QtyDiff', -- @cRefNo = 'Scn17.QtyDiff' for tracking
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
            END

            IF @nErrNo <> 0
               GOTO SINGLE_SKU_Increase_Qty_Fail
         END

         -- Reset variables
         SET @cOutField03 = '' -- key-in SKU
         SET @cOutField07 = CAST (@nEachQTY AS NVARCHAR( 5))
         SET @cOutField09 = CAST (@nQTY AS NVARCHAR( 5))

         -- Quit and remain at current screen
     GOTO Quit
      END -- IF @cNewSKU = @cSKU

      -- Key-in different SKU
      IF @cNewSKU <> @cSKU
      BEGIN
         -- If no lottables setup then confirm the previous scanned sku first
         IF @cHasLottable <> '1'
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg = ''
            -- Confirm Task for Single Scan
            EXECUTE rdt.rdt_CycleCount_ConfirmSingleScan
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cStorer,
               @cSKU,
               @cLOC,
               @cID,
               @cSheetNoFlag,
               @cWithQtyFlag,
               @cUserName,
               '',
               '',
               '',
               NULL,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT  -- screen limitation, 20 char max

            IF @nErrNo <> 0
    GOTO SINGLE_SKU_Increase_Qty_Fail
         END
         ELSE
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg = ''
            -- Confirm Task for Single Scan
            EXECUTE rdt.rdt_CycleCount_ConfirmSingleScan
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cStorer,
               @cSKU,
               @cLOC,
               @cID,
               @cSheetNoFlag,
               @cWithQtyFlag,
               @cUserName,
               @cLottable01,
               @cLottable02,
               @cLottable03,
               @dLottable04,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT  -- screen limitation, 20 char max

            IF @nErrNo <> 0
            GOTO SINGLE_SKU_Increase_Qty_Fail
         END

         -- Goto SKU changed screen, no matter got lottables or not
         IF rdt.RDTGetConfig( @nFunc, 'SkipSKUChangedScn', @cStorer) = 1
         BEGIN
            GOTO Skip_SKU_Changed_Screen
         END
         ELSE  -- check if lottable01-04 setup (ignore lottable05)
         BEGIN
            -- Check any Lottable label setup for the SKU
            SELECT
               @cLotLabel01 = ISNULL(LOTTABLE01LABEL, ''),
               @cLotLabel02 = ISNULL(LOTTABLE02LABEL, ''),
               @cLotLabel03 = ISNULL(LOTTABLE03LABEL, ''),
               @cLotLabel04 = ISNULL(LOTTABLE04LABEL, '')
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorer
            AND   SKU = @cNewSKU

            IF @cLotLabel01 <> '' OR @cLotLabel02 <> '' OR
               @cLotLabel03 <> '' OR @cLotLabel04 <> ''
            BEGIN
               SET @cHasLottable = '1'
            END
            ELSE
            BEGIN
               SET @cHasLottable = '0'       -- (james10)
            END

            -- if no lottable01-04 setup (ignore lottable05)
            -- straight away skip lottables
            IF @cHasLottable = 0
            BEGIN
               GOTO Skip_SKU_Changed_Screen
            END
            ELSE
            BEGIN
               SET @cOutField01 = ''
               SET @nScn = @nScn_SINGLE_SKU_Option
               SET @nStep = @nStep_SINGLE_SKU_Option
               GOTO Quit
            END
         END
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Check any Lottable label setup for the SKU
      SELECT
         @cLotLabel01 = ISNULL(LOTTABLE01LABEL, ''),
         @cLotLabel02 = ISNULL(LOTTABLE02LABEL, ''),
         @cLotLabel03 = ISNULL(LOTTABLE03LABEL, ''),
         @cLotLabel04 = ISNULL(LOTTABLE04LABEL, '')
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   SKU = @cSKU

      IF @cLotLabel01 <> '' OR @cLotLabel02 <> '' OR
         @cLotLabel03 <> '' OR @cLotLabel04 <> ''
      BEGIN
         SET @cHasLottable = '1'
      END

      IF @cHasLottable = '1'
      BEGIN
         SET @cSingleSKUDefLottableOpt = rdt.RDTGetConfig( @nFunc, 'SingleSKUDefLottableOpt', @cStorer)
         IF @cSingleSKUDefLottableOpt NOT IN ('1', '2', '3')
            SET @cSingleSKUDefLottableOpt = ''

         -- Go to Lottables end count screen
         SET @cOutField01 = CASE WHEN @cSingleSKUDefLottableOpt <> '' THEN @cSingleSKUDefLottableOpt ELSE '' END
         SET @nScn = @nScn_SINGLE_SKU_Lottables_Option
         SET @nStep = @nStep_SINGLE_SKU_Lottables_Option
      END
      ELSE
      BEGIN
         -- Go to SKU end count screen
         SET @cOutField01 = ''
         SET @nScn = @nScn_SINGLE_SKU_EndCount_Option
         SET @nStep = @nStep_SINGLE_SKU_EndCount_Option
      END

      GOTO Quit
   END

   SINGLE_SKU_Increase_Qty_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cLoc
      SET @cOutField02 = @cID
      SET @cOutField03 = ''
      GOTO Quit
   END

   Skip_SKU_Changed_Screen:
   BEGIN
/*    (james19)
      SELECT TOP 1
         @cNewSKUDescr = SKU.DESCR,
         @cNewEachUOM  = SUBSTRING( PAC.PACKUOM3, 1, 3)
      FROM dbo.SKU SKU (NOLOCK)
      INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorer
      AND   SKU.SKU = @cNewSKU
*/
     SELECT TOP 1
         @cNewSKUDescr = SKU.DESCR,
         @cNewEachUOM  = PAC.PACKUOM3
      FROM dbo.SKU SKU (NOLOCK)
      INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorer
      AND   SKU.SKU = @cNewSKU

      SET @cNewSKUDescr1 = SUBSTRING( @cNewSKUDescr,  1, 20)
      SET @cNewSKUDescr2 = SUBSTRING( @cNewSKUDescr, 21, 40)

      -- Initialise
      SET @nEachQTY = 0
      SET @nQTY = 0

      SET @cErrMsg = ''

      -- Get Lottables Details
      EXECUTE rdt.rdt_CycleCount_GetLottables
         @cCCRefNo, @cStorer, @cNewSKU, 'PRE', -- Codelkup.Short
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
         GOTO SINGLE_SKU_Increase_Qty_Fail

      IF @cHasLottable = '0'
      BEGIN
         SET @cLockedByDiffUser = ''
         SET @cFoundLockRec     = ''
         SET @cLockCCDetailKey  = ''
         EXECUTE rdt.rdt_CycleCount_FindCCLock
            @nMobile, @cCCRefNo, @cCCSheetNo, @cStorer, @cUserName,
            @cNewSKU,
            @cLOC,
            @cID,
            '',      -- Lottable01
            '',      -- Lottable02
            '',      -- Lottable03
            NULL,    -- Lottable04
            @cWithQtyFlag,
            @cFoundLockRec     OUTPUT,
--            @cLockCCDetailKey  OUTPUT
            @nRowRef           OUTPUT

         IF @cSheetNoFlag = 'Y'
         BEGIN
            IF @cFoundLockRec = 'Y'
            BEGIN
               UPDATE RDT.RDTCCLock WITH (ROWLOCK)
               SET   CountedQty = CountedQty + 1
--   WHERE Mobile = @nMobile
--               AND   CCKey = @cCCRefNo
--               AND   SheetNo = @cCCSheetNo
--               AND   StorerKey = @cStorer
--               AND AddWho = @cUserName
--         AND   Loc = @cLOC
--               AND   Id = @cID
--               AND   SKU = @cNewSKU
--               AND   CCDetailKey = @cLockCCDetailKey
--               AND   (Status = '0' OR Status = '1')
               WHERE RowRef = @nRowRef
            END
            ELSE
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_InsertCCLock
                  @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                  @cNewSKU,    -- @cSKU,
                  '',          -- @cLOT,
                  @cLOC,
                  @cID,
                  1,           -- CountedQTY
                  '',          -- @cLottable01
                  '',          -- @cLottable02
                  '',          -- @cLottable03
                  NULL,        -- @dLottable04
                  NULL,        -- @dLottable05
                  '',          -- @cRefNo = 'Scn15.ByShtNo' for tracking
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO SINGLE_SKU_Increase_Qty_Fail
            END
         END
         -- IF @cSheetNoFlag <> 'Y'
         ELSE
         BEGIN
            IF @cFoundLockRec = 'Y'
            BEGIN
               UPDATE RDT.RDTCCLock WITH (ROWLOCK)
               SET   CountedQty = CountedQty + 1
--               WHERE Mobile = @nMobile
--               AND   CCKey = @cCCRefNo
--               AND   StorerKey = @cStorer
--               AND   AddWho = @cUserName
--               AND   Loc = @cLOC
--               AND   Id = @cID
--               AND   SKU = @cNewSKU
--               AND   CCDetailKey = @cLockCCDetailKey
--               AND   (Status = '0' OR Status = '1')
               WHERE Rowref = @nRowRef
            END
            ELSE
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_InsertCCLock
                  @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                  @cNewSKU,    -- @cSKU,
                  '',          -- @cLOT,
                  @cLOC,
                  @cID,
                  1,           -- CountedQTY
                  '',          -- @cLottable01
                  '',          -- @cLottable02
                  '',          -- @cLottable03
                  NULL,        -- @dLottable04
                  NULL,        -- @dLottable05
                  '',          -- @cRefNo = 'Scn15.NoShtNo' for tracking
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO SINGLE_SKU_Increase_Qty_Fail
            END
         END

         --(james01)
         -- Incremental Counted Qty of the SKU in the specified LOC + ID
--         SELECT @nEachQTY = 1 + -- once press enter, consider scan one time
--            CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
--                 WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
--                 WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
--            ELSE 0 END
--         FROM dbo.CCDetail WITH (NOLOCK)
--         WHERE CCKey = @cCCRefNo
--         AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
--         AND   LOC = @cLOC
--         AND   ID = @cID
--         AND   SKU = @cNewSKU
--         GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3
--
--         --Total Qty of the specified LOC + ID
--         SELECT @nQTY = 1 + -- once press enter, consider scan one time
--            CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
--                 WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
--                 WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
--            ELSE 0 END
--         FROM dbo.CCDetail WITH (NOLOCK)
--         WHERE CCKey = @cCCRefNo
--         AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
--         AND   LOC = @cLOC
--         AND   ID = @cID
--         GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3
         -- Incremental Counted Qty of the SKU in the specified LOC + ID
         IF @nCCCountNo = 1
         BEGIN
            SELECT @nEachQTY = 1 + ISNULL(SUM(Qty), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            AND   SKU = @cNewSKU

            --Total Qty of the specified LOC + ID
            SELECT @nQTY = 1 + ISNULL(SUM(Qty), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
         END

         IF @nCCCountNo = 2
         BEGIN
            SELECT @nEachQTY = 1 + ISNULL(SUM(Qty_Cnt2), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            AND   SKU = @cNewSKU

            --Total Qty of the specified LOC + ID
            SELECT @nQTY = 1 + ISNULL(SUM(Qty_Cnt2), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
         END

         IF @nCCCountNo = 3
         BEGIN
            SELECT @nEachQTY = 1 + ISNULL(SUM(Qty_Cnt3), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            AND   SKU = @cNewSKU

            --Total Qty of the specified LOC + ID
            SELECT @nQTY = 1 + ISNULL(SUM(Qty_Cnt3), 0) -- once press enter, consider scan one time
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
      AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
         END
      END
      ELSE  --@cHasLottable = '1'
      BEGIN
         SET @cLockedByDiffUser = ''
         SET @cFoundLockRec     = ''
         SET @cLockCCDetailKey  = ''
         EXECUTE rdt.rdt_CycleCount_FindCCLock
            @nMobile, @cCCRefNo, @cCCSheetNo, @cStorer, @cUserName,
            @cNewSKU,
            @cLOC,
            @cID,
            @cLottable01,      -- Lottable01
            @cLottable02,      -- Lottable02
           @cLottable03,      -- Lottable03
 @dLottable04,      -- Lottable04
            @cWithQtyFlag,
            @cFoundLockRec     OUTPUT,
--            @cLockCCDetailKey  OUTPUT
           @nRowRef           OUTPUT

         IF @cSheetNoFlag = 'Y'
         BEGIN
            IF @cFoundLockRec = 'Y'
            BEGIN
               UPDATE RDT.RDTCCLock WITH (ROWLOCK)
               SET   CountedQty = CountedQty + 1
--               WHERE Mobile = @nMobile
--               AND   CCKey = @cCCRefNo
--               AND   SheetNo = @cCCSheetNo
--               AND   StorerKey = @cStorer
--               AND   AddWho = @cUserName
--               AND   Loc = @cLOC
--               AND   Id = @cID
--               AND   SKU = @cNewSKU
--               AND   CCDetailKey = @cLockCCDetailKey
--               AND   (Status = '0' OR Status = '1')
               WHERE RowRef = @nRowRef
            END
            ELSE
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_InsertCCLock
                  @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                  @cNewSKU,    -- @cSKU,
                  '',          -- @cLOT,
        @cLOC,
                  @cID,
                  1,           -- CountedQTY
                  @cLottable01,-- @cLottable01
                  @cLottable02,-- @cLottable02
                  @cLottable03,-- @cLottable03
                  @dLottable04,-- @dLottable04
                  NULL,        -- @dLottable05
                  '',          -- @cRefNo = 'Scn15.ByShtNo' for tracking
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO SINGLE_SKU_Increase_Qty_Fail
            END
         END
         -- IF @cSheetNoFlag <> 'Y'
         ELSE
         BEGIN
            IF @cFoundLockRec = 'Y'
            BEGIN
               UPDATE RDT.RDTCCLock WITH (ROWLOCK)
               SET   CountedQty = CountedQty + 1
--               WHERE Mobile = @nMobile
--               AND   CCKey = @cCCRefNo
--               AND   StorerKey = @cStorer
--               AND   AddWho = @cUserName
--               AND   Loc = @cLOC
--               AND   Id = @cID
--               AND   SKU = @cNewSKU
--               AND   CCDetailKey = @cLockCCDetailKey
--               AND   (Status = '0' OR Status = '1')
               WHERE RowRef = @nRowRef
            END
            ELSE
            BEGIN
             SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_InsertCCLock
                  @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                  @cNewSKU,    -- @cSKU,
   '',          -- @cLOT,
                  @cLOC,
                  @cID,
                  1,           -- CountedQTY
                  @cLottable01,-- @cLottable01
                  @cLottable02,-- @cLottable02
                  @cLottable03,-- @cLottable03
                  @dLottable04,-- @dLottable04
                  NULL,        -- @dLottable05
                  '',          -- @cRefNo = 'Scn15.NoShtNo' for tracking
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO SINGLE_SKU_Increase_Qty_Fail
            END
         END

         --(james01)
     -- Incremental Counted Qty of the SKU in the specified LOC + ID
         SELECT @nEachQTY = 1 + -- once press enter, consider scan one time
            CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
                 WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
          WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
            ELSE 0 END
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND   LOC = @cLOC
         AND   ID = @cID
         AND   SKU = @cNewSKU
         AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
         AND   Lottable04 = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE Lottable04 END
         GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3

         --Total Qty of the specified LOC + ID
         SELECT @nQTY = 1 + -- once press enter, consider scan one time
            CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
                 WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
                 WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
            ELSE 0 END
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND   LOC = @cLOC
         AND   ID = @cID
         AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
         AND   Lottable04 = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE Lottable04 END
         GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3
      END

      -- If lottables not match then initialise the qty as 1
      IF @nEachQTY = 0 SET @nEachQTY = 1
      IF @nQTY = 0 SET @nQTY = 1

      EXEC rdt.rdtSetFocusField @nMobile, 3  -- SKU/UPC

      -- Set variables
      SET @cSKU      = @cNewSKU
      SET @cSKUDescr = @cNewSKUDescr1 + @cNewSKUDescr2
      SET @cEachUOM  = @cNewEachUOM
      SET @cEachUOM  = @cNewEachUOM

      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''
      SET @cOutField04 = @cSKU
      SET @cOutField05 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField06 = SUBSTRING( @cSKUDescr, 20, 40)
      SET @cOutField07 = CAST( @nEachQTY AS NVARCHAR( 5)) -- SKU QTY
      SET @cOutField08 = @cEachUOM                       -- UOM (master unit)
      SET @cOutField09 = CAST( @nQTY AS NVARCHAR( 5))     -- ID QTY
      SET @cOutField10 = @cEachUOM                       -- UOM (master unit)
   END
END
GOTO Quit

/************************************************************************************
Step_SINGLE_SKU_Option. Scn = 680. Screen 18.
   OPT   (field01) - Input
************************************************************************************/
Step_SINGLE_SKU_Option:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOptAction = @cInField01

 -- Retain the key-in value
      SET @cOutField01 = @cOptAction

      IF @cOptAction = '' OR @cOptAction IS NULL
      BEGIN
         SET @nErrNo = 66832
         SET @cErrMsg = rdt.rdtgetmessage( 66832, @cLangCode, 'DSP') -- 'Option req'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO SINGLE_SKU_Option_Fail
      END

      IF @cOptAction NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 66833
         SET @cErrMsg = rdt.rdtgetmessage( 66833, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO SINGLE_SKU_Option_Fail
   END

      -- Short - 'PRE'
      -- Verify Labels for Lotables
      -- Enable/Disable Lottables for data entry
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

      SET @cErrMsg = ''

      -- Get Lottables Details
      EXECUTE rdt.rdt_CycleCount_GetLottables
         @cCCRefNo, @cStorer, @cNewSKU, 'PRE', -- Codelkup.Short
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
         GOTO SINGLE_SKU_Option_Fail

      -- Option: 1=New Lottables
      IF @cOptAction = '1' -- GOTO Screen 16. SINGLE SKU-Add Lottables
      BEGIN
         -- No Lottable Labels
         IF @cHasLottable = '0'
         BEGIN
            SET @nErrNo = 66834
            SET @cErrMsg = rdt.rdtgetmessage( 66834, @cLangCode, 'DSP') -- 'No LotLabel'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO SINGLE_SKU_Option_Fail
         END

         IF @cHasLottable = '1'
         BEGIN
            -- Clear all outfields
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

            -- Initiate labels
            SELECT
               @cOutField01 = 'Lottable01:',
               @cOutField03 = 'Lottable02:',
               @cOutField05 = 'Lottable03:',
               @cOutField07 = 'Lottable04:',
               @cOutField09 = 'Lottable05:'

            -- Populate labels and lottables
            IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
            BEGIN
               SET @cFieldAttr02 = 'O'
            END
            ELSE
            BEGIN
               SELECT @cOutField01 = @cLotLabel01
            END

            IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
            BEGIN
               SET @cFieldAttr04 = 'O'
            END
            ELSE
            BEGIN
               SELECT @cOutField03 = @cLotLabel02
            END

            IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
            BEGIN
                SET @cFieldAttr06 = 'O'
            END
            ELSE
            BEGIN
               SELECT @cOutField05 = @cLotLabel03
            END

            IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
            BEGIN
               SET @cFieldAttr08 = 'O'
            END
            ELSE
            BEGIN
               SELECT @cOutField07 = @cLotLabel04
            END

          SET @nEachQTY = 0

            EXEC rdt.rdtSetFocusField @nMobile, 1  -- Lottable01 value

            -- Go to next screen
            SET @nScn  = @nScn_SINGLE_SKU_Add_Lottables  -- screen 16
            SET @nStep = @nStep_SINGLE_SKU_Add_Lottables

            GOTO Quit
         END -- End of @cHasLottable = '1'
      END

      IF @cOptAction = '2' -- GOTO Screen 17. SINGLE SKU-IncreaseQTY
      BEGIN
/*       (james19)
         SELECT TOP 1
            @cNewSKUDescr = SKU.DESCR,
            @cNewEachUOM  = SUBSTRING( PAC.PACKUOM3, 1, 3)
         FROM dbo.SKU SKU (NOLOCK)
         INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
         WHERE SKU.StorerKey = @cStorer
         AND   SKU.SKU = @cNewSKU
*/
         --UWP-22515 Keep Lottables
         SELECT 
            @cLottable01       = V_Lottable01,
            @cLottable02       = V_Lottable02,
            @cLottable03       = V_Lottable03,
            @dLottable04       = V_Lottable04,
            @dLottable05       = V_Lottable05
         FROM RDT.RDTMOBREC WITH(NOLOCK)
         WHERE Mobile = @nMobile

         SELECT TOP 1
            @cNewSKUDescr = SKU.DESCR,
            @cNewEachUOM  = PAC.PACKUOM3
         FROM dbo.SKU SKU (NOLOCK)
         INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
         WHERE SKU.StorerKey = @cStorer
         AND   SKU.SKU = @cNewSKU

         SET @cNewSKUDescr1 = SUBSTRING( @cNewSKUDescr,  1, 20)
         SET @cNewSKUDescr2 = SUBSTRING( @cNewSKUDescr, 21, 40)

         -- Initialise
         SET @nEachQTY = 0
         SET @nQTY = 0

         IF @cHasLottable = '0'
         BEGIN
            SET @cLockedByDiffUser = ''
            SET @cFoundLockRec     = ''
            SET @cLockCCDetailKey  = ''
            EXECUTE rdt.rdt_CycleCount_FindCCLock
               @nMobile, @cCCRefNo, @cCCSheetNo, @cStorer, @cUserName,
               @cNewSKU,
               @cLOC,
               @cID,
               '',      -- Lottable01
               '',      -- Lottable02
               '',      -- Lottable03
               NULL,    -- Lottable04
               @cWithQtyFlag,
               @cFoundLockRec     OUTPUT,
--               @cLockCCDetailKey  OUTPUT
        @nRowRef           OUTPUT

            IF @cSheetNoFlag = 'Y'
            BEGIN
               IF @cFoundLockRec = 'Y'
               BEGIN
                  UPDATE RDT.RDTCCLock WITH (ROWLOCK)
                  SET   CountedQty = CountedQty + 1
--                  WHERE Mobile = @nMobile
--                  AND   CCKey = @cCCRefNo
--                  AND   SheetNo = @cCCSheetNo
--                  AND   StorerKey = @cStorer
--                  AND   AddWho = @cUserName
--                  AND   Loc = @cLOC
--                  AND   Id = @cID
--                  AND   SKU = @cNewSKU
--                  AND   CCDetailKey = @cLockCCDetailKey
--                  AND   (Status = '0' OR Status = '1')
                  WHERE RowRef = @nRowRef
               END
               ELSE
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_InsertCCLock
                     @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                     @cNewSKU,    -- @cSKU,
                     '',          -- @cLOT,
                     @cLOC,
                     @cID,
                     1,       -- CountedQTY
                     '',          -- @cLottable01
     '',          -- @cLottable02
                     '',          -- @cLottable03
                     NULL,     -- @dLottable04
                     NULL,        -- @dLottable05
                     '',          -- @cRefNo = 'Scn15.ByShtNo' for tracking
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT
                    IF @nErrNo <> 0
                     GOTO SINGLE_SKU_Sku_Scan_Fail
               END
            END
            -- IF @cSheetNoFlag <> 'Y'
            ELSE
            BEGIN
               IF @cFoundLockRec = 'Y'
               BEGIN
                  UPDATE RDT.RDTCCLock WITH (ROWLOCK)
                  SET   CountedQty = CountedQty + 1
--                  WHERE Mobile = @nMobile
--                  AND   CCKey = @cCCRefNo
--                  AND   StorerKey = @cStorer
--                  AND   AddWho = @cUserName
--      AND   Loc = @cLOC
--                  AND   Id = @cID
--                  AND   SKU = @cNewSKU
--                  AND   CCDetailKey = @cLockCCDetailKey
--                  AND   (Status = '0' OR Status = '1')
                  WHERE RowRef = @nRowRef
               END
               ELSE
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_InsertCCLock
                     @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                     @cNewSKU,    -- @cSKU,
                     '',          -- @cLOT,
                     @cLOC,
                     @cID,
                     1,           -- CountedQTY
                     '',          -- @cLottable01
                     '',          -- @cLottable02
                     '',          -- @cLottable03
                     NULL,        -- @dLottable04
                     NULL,        -- @dLottable05
                     '',          -- @cRefNo = 'Scn15.NoShtNo' for tracking
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO SINGLE_SKU_Sku_Scan_Fail
        END
            END

            --(james01)
            -- Incremental Counted Qty of the SKU in the specified LOC + ID
--            SELECT @nEachQTY = 1 + -- once press enter, consider scan one time
--       CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
--                    WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
--                    WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
--               ELSE 0 END
--            FROM dbo.CCDetail WITH (NOLOCK)
--            WHERE CCKey = @cCCRefNo
--            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
--            AND   LOC = @cLOC
--            AND   ID = @cID
--            AND   SKU = @cNewSKU
--            GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3
--
--            --Total Qty of the specified LOC + ID
--            SELECT @nQTY = 1 + -- once press enter, consider scan one time
--               CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
--                    WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
--                    WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
--               ELSE 0 END
--            FROM dbo.CCDetail WITH (NOLOCK)
--            WHERE CCKey = @cCCRefNo
--            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
--            AND   LOC = @cLOC
--            AND   ID = @cID
--            GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3
        IF @nCCCountNo = 1
            BEGIN
               SELECT @nEachQTY = 1 + ISNULL(SUM(Qty), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND   SKU = @cNewSKU

               --Total Qty of the specified LOC + ID
               SELECT @nQTY = 1 + ISNULL(SUM(Qty), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            END

            IF @nCCCountNo = 2
            BEGIN
               SELECT @nEachQTY = 1 + ISNULL(SUM(Qty_Cnt2), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND   SKU = @cNewSKU

               --Total Qty of the specified LOC + ID
               SELECT @nQTY = 1 + ISNULL(SUM(Qty_Cnt2), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            END

            IF @nCCCountNo = 3
            BEGIN
               SELECT @nEachQTY = 1 + ISNULL(SUM(Qty_Cnt3), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND   SKU = @cNewSKU

               --Total Qty of the specified LOC + ID
               SELECT @nQTY = 1 + ISNULL(SUM(Qty_Cnt3), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
             WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            END
         END
         ELSE  --@cHasLottable = '1'
         BEGIN
            SET @cLockedByDiffUser = ''
            SET @cFoundLockRec     = ''
            SET @cLockCCDetailKey  = ''
            EXECUTE rdt.rdt_CycleCount_FindCCLock
               @nMobile, @cCCRefNo, @cCCSheetNo, @cStorer, @cUserName,
               @cNewSKU,
               @cLOC,
               @cID,
               @cLottable01,      -- Lottable01
               @cLottable02,      -- Lottable02
               @cLottable03, -- Lottable03
               @dLottable04,      -- Lottable04
               @cWithQtyFlag,
               @cFoundLockRec  OUTPUT,
--               @cLockCCDetailKey  OUTPUT
               @nRowRef           OUTPUT

            IF @cSheetNoFlag = 'Y'
            BEGIN
               IF @cFoundLockRec = 'Y'
           BEGIN
                  UPDATE RDT.RDTCCLock WITH (ROWLOCK)
                  SET   CountedQty = CountedQty + 1
--                  WHERE Mobile = @nMobile
--       AND   CCKey = @cCCRefNo
--                  AND   SheetNo = @cCCSheetNo
--                  AND   StorerKey = @cStorer
--                  AND   AddWho = @cUserName
--                  AND   Loc = @cLOC
--                  AND   Id = @cID
--                  AND   SKU = @cNewSKU
--                  AND   CCDetailKey = @cLockCCDetailKey
--                  AND   (Status = '0' OR Status = '1')
               WHERE RowRef = @nRowRef
               END
               ELSE
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_InsertCCLock
                     @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                     @cNewSKU,    -- @cSKU,
                     '',          -- @cLOT,
                 @cLOC,
                     @cID,
                     1,           -- CountedQTY
                     @cLottable01,-- @cLottable01
                     @cLottable02,-- @cLottable02
                     @cLottable03,-- @cLottable03
                     @dLottable04,-- @dLottable04
                     NULL,        -- @dLottable05
                     '',          -- @cRefNo = 'Scn15.ByShtNo' for tracking
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

  IF @nErrNo <> 0
                 GOTO SINGLE_SKU_Sku_Scan_Fail
               END
           END
            -- IF @cSheetNoFlag <> 'Y'
            ELSE
            BEGIN
               IF @cFoundLockRec = 'Y'
               BEGIN
                  UPDATE RDT.RDTCCLock WITH (ROWLOCK)
                  SET   CountedQty = CountedQty + 1
--                  WHERE Mobile = @nMobile
--           AND   CCKey = @cCCRefNo
--                  AND   StorerKey = @cStorer
--                  AND   AddWho = @cUserName
--                  AND   Loc = @cLOC
--                  AND   Id = @cID
--                  AND   SKU = @cNewSKU
--                  AND   CCDetailKey = @cLockCCDetailKey
--                  AND   (Status = '0' OR Status = '1')
                  WHERE RowRef = @nRowRef
               END
               ELSE
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_InsertCCLock
                 @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
                     @cNewSKU,    -- @cSKU,
                     '',          -- @cLOT,
                     @cLOC,
                     @cID,
                     1,           -- CountedQTY
                     @cLottable01,-- @cLottable01
                     @cLottable02,-- @cLottable02
                     @cLottable03,-- @cLottable03
                     @dLottable04,-- @dLottable04
                     NULL,        -- @dLottable05
                     '',          -- @cRefNo = 'Scn15.NoShtNo' for tracking
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO SINGLE_SKU_Sku_Scan_Fail
               END
            END

            --(james01)
            -- Incremental Counted Qty of the SKU in the specified LOC + ID
            SELECT @nEachQTY = 1 + -- once press enter, consider scan one time
             CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
                    WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
               WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
               ELSE 0 END
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
 AND   LOC = @cLOC
            AND   ID = @cID
            AND   SKU = @cNewSKU
            AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   Lottable04 = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE Lottable04 END
            GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3

            --Total Qty of the specified LOC + ID
            SELECT @nQTY = 1 + -- once press enter, consider scan one time
               CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
                    WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
                  WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
               ELSE 0 END
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = @cID
            AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
     AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   Lottable04 = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE Lottable04 END
            GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3
         END

         -- If lottables not match then initialise the qty as 1
         IF @nEachQTY = 0 SET @nEachQTY = 1
         IF @nQTY = 0 SET @nQTY = 1

         EXEC rdt.rdtSetFocusField @nMobile, 3  -- SKU/UPC

         -- Set variables
         SET @cSKU      = @cNewSKU
         SET @cSKUDescr = @cNewSKUDescr1 + @cNewSKUDescr2
         SET @cEachUOM  = @cNewEachUOM
         SET @cEachUOM  = @cNewEachUOM

         -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID
         SET @cOutField03 = ''
   SET @cOutField04 = @cSKU
         SET @cOutField05 = SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField06 = SUBSTRING( @cSKUDescr, 20, 40)
         SET @cOutField07 = CAST( @nEachQTY AS NVARCHAR( 5)) -- SKU QTY
         SET @cOutField08 = @cEachUOM                       -- UOM (master unit)
    SET @cOutField09 = CAST( @nQTY AS NVARCHAR( 5))     -- ID QTY
         SET @cOutField10 = @cEachUOM                       -- UOM (master unit)

         -- Go to Screen SINGLE SKU-IncreaseQTY
         SET @nScn = @nScn_SINGLE_SKU_Increase_Qty
         SET @nStep = @nStep_SINGLE_SKU_Increase_Qty
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = '' -- SKU/UPC

      -- Go to previous screen
      SET @nScn = @nScn_SINGLE_SKU_Increase_Qty
      SET @nStep = @nStep_SINGLE_SKU_Increase_Qty
   END
   GOTO Quit

   SINGLE_SKU_Option_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option - retain value
   END
END
GOTO Quit

/************************************************************************************
Step_SINGLE_SKU_Lottables_Option. Scn = 700. Screen 22.
   OPT   (field01) - Input
************************************************************************************/
Step_SINGLE_SKU_Lottables_Option:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOptAction = @cInField01

      -- Retain the key-in value
      SET @cOutField01 = @cOptAction

      IF @cOptAction = '' OR @cOptAction IS NULL
      BEGIN
         SET @nErrNo = 66832
         SET @cErrMsg = rdt.rdtgetmessage( 66832, @cLangCode, 'DSP') -- 'Option req'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO SINGLE_SKU_Option_Fail
      END

      IF @cOptAction NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 66833
         SET @cErrMsg = rdt.rdtgetmessage( 66833, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO SINGLE_SKU_Option_Fail
      END

      -- Short - 'PRE'
      -- Verify Labels for Lotables
      -- Enable/Disable Lottables for data entry
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

      SET @cErrMsg = ''

      -- Get Lottables Details
      EXECUTE rdt.rdt_CycleCount_GetLottables
         @cCCRefNo, @cStorer, @cNewSKU, 'PRE', -- Codelkup.Short
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
         GOTO SINGLE_SKU_Option_Fail

      -- Option: 1=New Lottables
      IF @cOptAction = '1' -- GOTO Screen 16. SINGLE SKU-Add Lottables
      BEGIN
         -- No Lottable Labels
         IF @cHasLottable = '0'
         BEGIN
            SET @nErrNo = 66834
        SET @cErrMsg = rdt.rdtgetmessage( 66834, @cLangCode, 'DSP') -- 'No LotLabel'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO SINGLE_SKU_Option_Fail
         END

         IF @cHasLottable = '1'
         BEGIN
    -- Clear all outfields
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

            -- Initiate labels
            SELECT
               @cOutField01 = 'Lottable01:',
               @cOutField03 = 'Lottable02:',
               @cOutField05 = 'Lottable03:',
               @cOutField07 = 'Lottable04:',
               @cOutField09 = 'Lottable05:'

            -- Populate labels and lottables
            IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
            BEGIN
               SET @cFieldAttr02 = 'O'
            END
            ELSE
            BEGIN
               SELECT @cOutField01 = @cLotLabel01
            END

            IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
            BEGIN
               SET @cFieldAttr04 = 'O'
            END
            ELSE
            BEGIN
               SELECT @cOutField03 = @cLotLabel02
            END

            IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
            BEGIN
                SET @cFieldAttr06 = 'O'
            END
            ELSE
            BEGIN
               SELECT @cOutField05 = @cLotLabel03
            END

            IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
            BEGIN
               SET @cFieldAttr08 = 'O'
            END
            ELSE
            BEGIN
               SELECT @cOutField07 = @cLotLabel04
         END

            SET @nEachQTY = 0

            EXEC rdt.rdtSetFocusField @nMobile, 1   -- Lottable01 value

            -- Go to next screen
            SET @nScn  = @nScn_SINGLE_SKU_Add_Lottables  -- screen 16
            SET @nStep = @nStep_SINGLE_SKU_Add_Lottables

            GOTO Quit
         END -- End of @cHasLottable = '1'
      END

      IF @cOptAction = '2' -- GOTO Screen 17. SINGLE SKU-IncreaseQTY
      BEGIN
/*
         SELECT TOP 1
   @cNewSKUDescr = SKU.DESCR,
            @cNewEachUOM  = SUBSTRING( PAC.PACKUOM3, 1, 3)
         FROM dbo.SKU SKU (NOLOCK)
         INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
         WHERE SKU.StorerKey = @cStorer
         AND   SKU.SKU = @cNewSKU
*/
         --UWP-22515 Keep Lottables
         SELECT 
            @cLottable01       = V_Lottable01,
            @cLottable02       = V_Lottable02,
            @cLottable03       = V_Lottable03,
            @dLottable04       = V_Lottable04,
            @dLottable05       = V_Lottable05
         FROM RDT.RDTMOBREC WITH(NOLOCK)
         WHERE Mobile = @nMobile
         
         SELECT TOP 1
            @cNewSKUDescr = SKU.DESCR,
            @cNewEachUOM  = PAC.PACKUOM3
         FROM dbo.SKU SKU (NOLOCK)
         INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorer
         AND   SKU.SKU = @cNewSKU

         SET @cNewSKUDescr1 = SUBSTRING( @cNewSKUDescr,  1, 20)
         SET @cNewSKUDescr2 = SUBSTRING( @cNewSKUDescr, 21, 40)

         -- Initialise
         SET @nEachQTY = 0
         SET @nQTY = 0

         IF @cHasLottable = '0'
         BEGIN
            --(james01)
            -- Incremental Counted Qty of the SKU in the specified LOC + ID
--            SELECT @nEachQTY = 1 + -- once press enter, consider scan one time
--               CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
--                    WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
--                    WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
--               ELSE 0 END
--            FROM dbo.CCDetail WITH (NOLOCK)
--            WHERE CCKey = @cCCRefNo
--            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
--            AND   LOC = @cLOC
--            AND   ID = @cID
--            AND   SKU = @cNewSKU
--            GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3
--
--            --Total Qty of the specified LOC + ID
--            SELECT @nQTY = 1 + -- once press enter, consider scan one time
--               CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
--                    WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
--                    WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
--               ELSE 0 END
--            FROM dbo.CCDetail WITH (NOLOCK)
--            WHERE CCKey = @cCCRefNo
--            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
--            AND   LOC = @cLOC
--            AND   ID = @cID
--            GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3
            IF @nCCCountNo = 1
            BEGIN
               SELECT @nEachQTY = 1 + ISNULL(SUM(Qty), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND   SKU = @cNewSKU

               --Total Qty of the specified LOC + ID
               SELECT @nQTY = 1 + ISNULL(SUM(Qty), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            END

            IF @nCCCountNo = 2
            BEGIN
               SELECT @nEachQTY = 1 + ISNULL(SUM(Qty_Cnt2), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
     AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND   SKU = @cNewSKU

               --Total Qty of the specified LOC + ID
               SELECT @nQTY = 1 + ISNULL(SUM(Qty_Cnt2), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
     END

            IF @nCCCountNo = 3
            BEGIN
               SELECT @nEachQTY = 1 + ISNULL(SUM(Qty_Cnt3), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND   SKU = @cNewSKU

               --Total Qty of the specified LOC + ID
               SELECT @nQTY = 1 + ISNULL(SUM(Qty_Cnt3), 0) -- once press enter, consider scan one time
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND  LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            END
         END
         ELSE
         BEGIN
            --(james01)
            -- Incremental Counted Qty of the SKU in the specified LOC + ID
            SELECT @nEachQTY = 1 + -- once press enter, consider scan one time
      CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
                    WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
                    WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
               ELSE 0 END
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = @cID
            AND   SKU = @cNewSKU
            AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   Lottable04 = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE Lottable04 END
            GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3

            --Total Qty of the specified LOC + ID
            SELECT @nQTY = 1 + -- once press enter, consider scan one time
               CASE WHEN @nCCCountNo = 1 THEN CASE WHEN Counted_Cnt1 = 1 THEN ISNULL(SUM(Qty), 0) ELSE 0 END
                    WHEN @nCCCountNo = 2 THEN CASE WHEN Counted_Cnt2 = 1 THEN ISNULL(SUM(Qty_Cnt2), 0) ELSE 0 END
  WHEN @nCCCountNo = 3 THEN CASE WHEN Counted_Cnt3 = 1 THEN ISNULL(SUM(Qty_Cnt3), 0) ELSE 0 END
               ELSE 0 END
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = @cID
            AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
   AND   Lottable04 = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE Lottable04 END
            GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3
         END

         -- If lottables not match then initialise the qty as 1
         IF @nEachQTY = 0 SET @nEachQTY = 1
         IF @nQTY = 0 SET @nQTY = 1

         EXEC rdt.rdtSetFocusField @nMobile, 3  -- SKU/UPC

         -- Set variables
         SET @cSKU      = @cNewSKU
         SET @cSKUDescr = @cNewSKUDescr1 + @cNewSKUDescr2
         SET @cEachUOM  = @cNewEachUOM
         SET @cEachUOM  = @cNewEachUOM

         -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID
         SET @cOutField03 = ''
       SET @cOutField04 = @cSKU
         SET @cOutField05 = SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField06 = SUBSTRING( @cSKUDescr, 20, 40)
         SET @cOutField07 = CAST( @nEachQTY AS NVARCHAR( 5)) -- SKU QTY
         SET @cOutField08 = @cEachUOM                       -- UOM (master unit)
         SET @cOutField09 = CAST( @nQTY AS NVARCHAR( 5))     -- ID QTY
         SET @cOutField10 = @cEachUOM                       -- UOM (master unit)

         -- Go to Screen SINGLE SKU-IncreaseQTY
         SET @nScn = @nScn_SINGLE_SKU_Increase_Qty
         SET @nStep = @nStep_SINGLE_SKU_Increase_Qty
      END

      IF @cOptAction = '3'
      BEGIN
         SELECT 
            @cLottable01       = V_Lottable01,
            @cLottable02       = V_Lottable02,
            @cLottable03       = V_Lottable03,
            @dLottable04       = V_Lottable04,
            @dLottable05       = V_Lottable05
         FROM RDT.RDTMOBREC WITH(NOLOCK)
         WHERE Mobile = @nMobile
         
         -- If no lottables setup then confirm the previous scanned sku first
         IF @cHasLottable <> '1'
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg = ''
            -- Confirm Task for Single Scan
            EXECUTE rdt.rdt_CycleCount_ConfirmSingleScan
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
              @cStorer,
               @cSKU,
               @cLOC,
               @cID,
               @cSheetNoFlag,
               @cWithQtyFlag,
               @cUserName,
               '',
               '',
               '',
               NULL,
               @cLangCode,
               @nErrNo  OUTPUT,
           @cErrMsg OUTPUT  -- screen limitation, 20 char max

            IF @nErrNo <> 0
            GOTO SINGLE_SKU_Increase_Qty_Fail
         END
         ELSE
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg = ''
            -- Confirm Task for Single Scan
            EXECUTE rdt.rdt_CycleCount_ConfirmSingleScan
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cStorer,
               @cSKU,
               @cLOC,
               @cID,
               @cSheetNoFlag,
               @cWithQtyFlag,
               @cUserName,
               @cLottable01,
               @cLottable02,
               @cLottable03,
               @dLottable04,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT  -- screen limitation, 20 char max

            IF @nErrNo <> 0
            GOTO SINGLE_SKU_Increase_Qty_Fail
         END

         IF rdt.RDTGetConfig( @nFunc, 'AutoGotoIDSCN', @cStorer) = 1
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cCCRefNo
            SET @cOutField02 = @cCCSheetNo
            SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
            SET @cOutField04 = @cSuggestLOC
            SET @cOutField05 = @cLOC
            SET @cOutField06 = @cDefaultCCOption
            SET @cOutField07 = '' -- ID

            EXEC rdt.rdtSetFocusField @nMobile, 7   -- ID

            -- (james12)
            SET @nNoOfTry = 0

            -- Go to ID screen directly
            SET @nScn = @nScn_ID
            SET @nStep = @nStep_ID
         END
         ELSE
         BEGIN
            -- Goto single SKU screen
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cID

            SET @nScn = @nScn_SINGLE_SKU_Sku_Scan
            SET @nStep = @nStep_SINGLE_SKU_Sku_Scan
         END
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = '' -- SKU/UPC

      -- Go to previous screen
      SET @nScn = @nScn_SINGLE_SKU_Increase_Qty
      SET @nStep = @nStep_SINGLE_SKU_Increase_Qty
   END
   GOTO Quit

   Step_SINGLE_SKU_Lottables_Option_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option - retain value
   END
END
GOTO Quit

/************************************************************************************
Step_SINGLE_SKU_EndCount_Option. Scn = 701. Screen 23.
   OPT   (field01) - Input
************************************************************************************/
Step_SINGLE_SKU_EndCount_Option:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOptAction = @cInField01

      IF @cOptAction NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 66836
         SET @cErrMsg = rdt.rdtgetmessage( 66836, @cLangCode, 'DSP') -- 'Invalid Option'
         SET @cOptAction = ''
         SET @cOutField01 = ''
      END

      IF @cOptAction = '1'
      BEGIN
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID

         -- Go back to SKU increase qty screen
         SET @nScn = @nScn_SINGLE_SKU_Increase_Qty
         SET @nStep = @nStep_SINGLE_SKU_Increase_Qty

         GOTO Quit
      END


      IF @cOptAction = '2'
      BEGIN
         SET @nTranCount = @@TRANCOUNT

         BEGIN TRAN
         SAVE TRAN EndCount

         SET @nErrNo = 0
         SET @cErrMsg = ''
         -- Confirm Task for Single Scan
         EXECUTE rdt.rdt_CycleCount_ConfirmSingleScan
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cStorer,
            @cSKU,
            @cLOC,
            @cID,
            @cSheetNoFlag,
     --@cRecountFlag,
            @cWithQtyFlag,
            @cUserName,
            @cLottable01,
            @cLottable02,
            @cLottable03,
            @dLottable04,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT  -- screen limitation, 20 char max

         IF @nErrNo <> 0
            GOTO EndCount_RollBack

         -- (james29)
         IF @cExtendedUpdateSP <> '' AND
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, ' +
               ' @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT '
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
               ' @tExtUpdate     VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorer,
               @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel,
               @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT

             IF @nErrNo <> 0
               GOTO EndCount_RollBack
         END

         GOTO EndCount_Quit

         EndCount_RollBack:
            ROLLBACK TRAN EndCount

         EndCount_Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN EndCount

         IF @nErrNo <> 0
            GOTO SINGLE_SKU_Increase_Qty_Fail

         IF rdt.RDTGetConfig( @nFunc, 'AutoGotoIDSCN', @cStorer) = 1
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cCCRefNo
            SET @cOutField02 = @cCCSheetNo
            SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
            SET @cOutField04 = @cSuggestLOC
            SET @cOutField05 = @cLOC
            SET @cOutField06 = @cDefaultCCOption
            SET @cOutField07 = '' -- ID

            EXEC rdt.rdtSetFocusField @nMobile, 7   -- ID

            -- (james12)
            SET @nNoOfTry = 0

            -- Go to ID screen directly
            SET @nScn = @nScn_ID
            SET @nStep = @nStep_ID

            IF rdt.RDTGetConfig( @nFunc, 'SkipIDOPTScn', @cStorer) = '1'
            BEGIN
               -- Reset Flags
               SET @cRecountFlag   = ''
               SET @cLastLocFlag = ''
               SET @cAddNewLocFlag = ''
               SET @cFieldAttr07 = ''

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
                  IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
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
                     EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
                        @cFacility,
                        @cSuggestLogiLOC, -- current CCLogicalLOC
                        @cSuggestLogiLOC OUTPUT,
                        @cSuggestLOC OUTPUT,
                        @nCCCountNo,
                        @cUserName  -- (james05)
                  END
                  ELSE
                  BEGIN
                     -- Get next suggested LOC
                     EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
                        @cFacility,
                        @cSuggestLogiLOC, -- current CCLogicalLOC
                        @cSuggestLogiLOC OUTPUT,
                        @cSuggestLOC OUTPUT,
                        @nCCCountNo,
                        @cUserName  -- (james05)
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
               SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)
               SET @cOutField07 = ''  -- ID

               -- Go to previous screen
               SET @nScn = @nScn_LOC
               SET @nStep = @nStep_LOC
            END

         END
         ELSE
         BEGIN
            -- Goto single SKU screen
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cID

    -- Go back to LOC/ID/SKU screen
            SET @nScn = @nScn_SINGLE_SKU_Sku_Scan
            SET @nStep = @nStep_SINGLE_SKU_Sku_Scan
         END
      END

      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Go to previous screen
      SET @nScn = @nScn_SINGLE_SKU_Increase_Qty
      SET @nStep = @nStep_SINGLE_SKU_Increase_Qty
   END
END
GOTO Quit

/************************************************************************************
Step_ID_CartonCount. Scn = 3260. Screen 24.
   Pallet ID      (field02)
   Carton Count   (field02, input)
************************************************************************************/
Step_ID_CartonCount:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCtnCount = @cInField02

         -- Add eventlog (yeekung01)
         EXEC RDT.rdt_STD_EventLog
         @cActionType   = '7',
         @nFunctionID   = @nFunc,
         @nMobileNo     = @nMobile,
         @cStorerKey    = @cStorer,
         @cFacility     = @cFacility,
         @cCCKey        = @cCCRefNo,
         @cLocation     = @cLOC,
         @cID           = @cID_In,
         @cSKU          = @cSKU,
         @cUCC          = @cUCC

      IF ISNULL(@cCtnCount, '') = ''
      BEGIN
         SET @nErrNo = 77703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CTN COUNT req'
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- not check for 0 qty because if empty loc then user put 0 as empty loc indicator
      IF RDT.rdtIsValidQTY( @cCtnCount, 0) = 0
      BEGIN
         SET @nErrNo = 77704
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'BAD CTN COUNT'
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- If not empty pallet count then must have id to confirm
      IF CAST(@cCtnCount AS INT) <> 0
      BEGIN
         -- Count by ID must have key in pallet ID
         IF ISNULL(@cID_In, '') = ''
         BEGIN
            SET @nErrNo = 77701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'ID required'
            SET @cOutField02 = ''
            GOTO Quit
         END
      END

      -- Reset whole pallet id ctn count to uncounted
      -- if this pallet prev counted b4
      IF EXISTS ( SELECT 1
                  FROM dbo.CCDETAIL (NOLOCK)
                  WHERE CCKey = @cCCRefNo
                  AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                  AND   LOC = @cLOC
                  AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
     AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
                                 WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                                 WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
                            ELSE 0 END
                  AND   (Status = '2' OR Status = '4'))
      BEGIN
         UPDATE dbo.CCDetail WITH (ROWLOCK) SET
            Counted_Cnt1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 <> 0 THEN 0 ELSE Counted_Cnt1 END,
            Counted_Cnt2 = CASE WHEN @nCCCountNo = 2 AND Counted_Cnt2 <> 0 THEN 0 ELSE Counted_Cnt2 END,
            Counted_Cnt3 = CASE WHEN @nCCCountNo = 3 AND Counted_Cnt3 <> 0 THEN 0 ELSE Counted_Cnt3 END
         WHERE CCKey = @cCCRefNo
         AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND   LOC = @cLOC
         AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
         AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
     WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                        WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
                   ELSE 0 END
         AND   (Status = '2' OR Status = '4')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77714
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'RESET CNT FAIL'
            SET @cOutField02 = ''
            GOTO Quit
         END
      END

      -- If previously counted wrong on pallet ctn count
      -- then forced to scan every ctn
      IF @nNoOfTry > 0
      BEGIN
         GOTO SCAN_EACH_UCC
      END

      -- Get Pallet carton count
      SELECT @nPltCtnCount = COUNT(1)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   ID = @cID_In
      AND   [Status] = '1'

      SET @nCtnCount = CAST(@cCtnCount AS INT)

      -- Empty loc
      IF @nCtnCount = 0
      BEGIN
         WHILE @nPltCtnCount > 0
         BEGIN
            -- Get CCDETAIL
            SELECT TOP 1
               @cStorer = CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorer ELSE StorerKey END,
               @cSKU = SKU,
               @cLOT = LOT,
               @cStatus = Status,
               @nSYSQTY = SystemQty,
               @cSYSID = CASE WHEN (@cID_In <> '' AND @cID_In IS NOT NULL) THEN @cID_In ELSE [ID] END,
               @cCCDetailKey = CCDetailKey
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

            -- If nothing found, prompt error
            IF @@ROWCOUNT = 0 OR ISNULL(@cCCDetailKey, '') = ''
            BEGIN
               SET @nErrNo = 77705
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NO CCD FOUND'
               SET @cOutField02 = ''
               GOTO Quit
            END

            -- If found, update CCDETAIL
            SET @nErrNo = 0
            SET @cErrMsg = ''
            EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cCCDetailKey,
               0,               -- empty loc
               @cUserName,
               @cLangCode,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT    -- screen limitation, 20 char max

            IF @nErrNo <> 0
            BEGIN
               SET @cOutField01 = ''
               GOTO Quit
            END

            SET @nPltCtnCount = @nPltCtnCount - 1
         END

         GOTO Step_ID_CartonCount_Continue
      END

      IF @nPltCtnCount <> @nCtnCount
      BEGIN
         SCAN_EACH_UCC:

         -- Force to scan UCC
         SET @nCntQTY = 0
         SET @nTotCarton = 0

         SET @cID = @cID_In -- Fixed by SHONG on 03-Mar-2011

         -- Get no. of counted cartons
         SELECT @nCntQTY = COUNT(1)
         FROM dbo.CCDETAIL (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND   LOC = @cLOC
         AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
         AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
                        WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                        WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
            ELSE 0 END
         AND   (Status = '2' OR Status = '4')

         IF @cRecountFlag = 'Y'
            SET @nCntQTY = 0

         -- Blank out var
         SET @cUCC = ''
         SET @cSKU = ''
         SET @cSKUDescr = ''
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
         SET @cOutField07 = ''   -- Lottable02
         SET @cOutField08 = ''   -- Lottable03
         SET @cOutField09 = ''   -- Lottable04
         SET @cOutField10 = ''   -- Lottable05
         SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
                                 THEN CAST( @nCntQTY AS NVARCHAR( 5))
                                 ELSE CAST( @nCntQTY AS NVARCHAR( 5)) + '/' + CAST( @nTotCarton AS NVARCHAR( 5))
                                 END
         SET @cOutField12 = ''   -- Option

         EXEC rdt.rdtSetFocusField @nMobile, 1   -- UCC

         -- (james12)
         SET @nNoOfTry = @nNoOfTry + 1

   -- Go to UCC (Main) screen
         SET @nScn = @nScn_UCC
         SET @nStep = @nStep_UCC
      END
      ELSE
      BEGIN
   WHILE @nCtnCount > 0
         BEGIN
            -- Get CCDETAIL
            SELECT TOP 1
               @cStorer = CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorer ELSE StorerKey END,
               @cSKU = SKU,
               @cLOT = LOT,
               @cStatus = Status,
               @nSYSQTY = SystemQty,
               @cSYSID = CASE WHEN (@cID_In <> '' AND @cID_In IS NOT NULL) THEN @cID_In ELSE [ID] END,
               @cCCDetailKey = CCDetailKey
            FROM dbo.CCDETAIL (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND   LOC = @cLOC
            AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
--            AND   RefNo = @cUCC
            AND   Status < '9'
            AND 1 =  CASE
                        WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0
                        WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0
                        WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0
                        ELSE 1
                     END

            -- If nothing found, prompt error
            IF @@ROWCOUNT = 0 OR ISNULL(@cCCDetailKey, '') = ''
            BEGIN
               SET @nErrNo = 77705
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NO CCD FOUND'
               SET @cOutField02 = ''
               GOTO Quit
            END

            -- If found, update CCDETAIL
            SET @nErrNo = 0
            SET @cErrMsg = ''
            EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cCCDetailKey,
               @nSYSQTY,               -- equal to CaseCnt
               @cUserName,
               @cLangCode,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT    -- screen limitation, 20 char max

            IF @nErrNo <> 0
            BEGIN
               SET @cOutField02 = ''
               GOTO Quit
            END

            SET @nCtnCount = @nCtnCount - 1
         END

         Step_ID_CartonCount_Continue:
         -- If configkey not turned on (james05)
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
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

            EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
               @cFacility,
               '',   -- current CCLogicalLOC is blank
               @cSuggestLogiLOC OUTPUT,
               @cSuggestLOC OUTPUT,
               @nCCCountNo,
               @cUserName  -- (james05)

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

            EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
               @cFacility,
               '',   -- current CCLogicalLOC is blank
               @cSuggestLogiLOC OUTPUT,
               @cSuggestLOC OUTPUT,
               @nCCCountNo,
               @cUserName  -- (james05)
         END

         IF ISNULL(@cSuggestLOC, '') = ''
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cCCRefNo
            SET @cOutField02 = ''  -- Blank SHEET
            SET @cOutField03 = ''  -- CNT NO


            -- Go to next screen
            SET @nScn = @nScn_CountNo
            SET @nStep = @nStep_CountNo

            GOTO Quit
         END

         -- Get No. Of CCDetail Lines
         SELECT @nCCDLinesPerLOC = COUNT(1)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
            AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND LOC = @cSuggestLOC

         -- Reset LastLocFlag
         SET @cLastLocFlag = ''

         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = ''
         SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END -- (james10)

         -- Go to next screen
       SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC
      END
      --END
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Go to previous screen
      -- Prepare next screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = @cDefaultCCOption
      SET @cOutField07 = '' -- ID

      EXEC rdt.rdtSetFocusField @nMobile, 7   -- ID

      -- (james28)
      IF rdt.RDTGetConfig( @nFunc, 'DoubleDeep', @cCheckStorer) = '1'
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                     WHERE Facility = @cFacility
                     AND   Loc = @cLOC
                     AND   MaxPallet > 1
                     AND   LocationCategory = 'DOUBLEDEEP')
         BEGIN
            SELECT TOP 1 @cID_In = Id
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
            AND   LOC = @cLOC
            AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 0
                           WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 0
                           WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 0
                      ELSE 1 END
            AND   [STATUS] < '9'
            ORDER BY Id

            SELECT @nID_Count = SUM( ID_Count), @nTtlID_Count = SUM( TtlID_Count) FROM (
               SELECT
               CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN COUNT( DISTINCT Id)
                                 WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN COUNT( DISTINCT Id)
                                 WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN COUNT( DISTINCT Id)
                            ELSE 0 END AS ID_Count,
               CASE WHEN @nCCCountNo = 1 THEN COUNT( DISTINCT Id)
                                    WHEN @nCCCountNo = 2 THEN COUNT( DISTINCT Id)
                                    WHEN @nCCCountNo = 3 THEN COUNT( DISTINCT Id)
                               ELSE 0 END AS TtlID_Count
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
            AND   LOC = @cLOC
   AND   [STATUS] < '9'
            GROUP BY Counted_Cnt1, Counted_Cnt2, Counted_Cnt3) A

            SET @cOutField03 = CAST( @nID_Count + 1 AS NVARCHAR( 2)) + '/' + CAST( @nTtlID_Count AS NVARCHAR( 2))
            SET @cOutField06 = '2'  -- Option
            SET @cOutField07 = @cID_In -- ID
            SET @cFieldAttr07 = 'O'
         END
      END

      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID

      IF rdt.RDTGetConfig( @nFunc, 'SkipIDOPTScn', @cStorer) = '1'
      BEGIN
         SET @cOutField15 = ''
         GOTO Step_ID
      END
   END
END
GOTO Quit

/************************************************************************************
Step_SKU_Add_Sku. Scn = 3261. Screen 26.
   LOC         (field01)
   ID          (field02)
   SKU/UPC     (field03) - Input field
************************************************************************************/
Step_Blind_SKU:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cSKU = @cInField03
      SET @cLabel2Decode = @cInField03

      -- Retain the key-in value
      SET @cOutField03 = @cSKU

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

      INSERT INTO @t_Storer (StorerKey)
      SELECT Distinct StorerKey
      FROM   CCDETAIL WITH (NOLOCK)
      WHERE  CCKey = @cCCRefNo
      AND    StorerKey <> ''

      -- Validate blank SKU
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 62119
         SET @cErrMsg = rdt.rdtgetmessage( 62119, @cLangCode, 'DSP') -- 'SKU/UPC req'
         GOTO SKU_Blind_Sku_Fail
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
                  GOTO SKU_Blind_Sku_Fail
               END

               SET @cSKU = @c_oFieled01
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
                     @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT

                  IF ISNULL( @cUPC, '') <> ''
                     SET @cSKU = @cUPC
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
                     ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
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
                     ' @cLottable09 NVARCHAR( 30)  OUTPUT, ' +
                     ' @cLottable10    NVARCHAR( 30)  OUTPUT, ' +
                     ' @cLottable11    NVARCHAR( 30)  OUTPUT, ' +
                     ' @cLottable12    NVARCHAR( 30)  OUTPUT, ' +
                     ' @dLottable13    DATETIME       OUTPUT, ' +
                     ' @dLottable14    DATETIME       OUTPUT, ' +
                     ' @dLottable15    DATETIME       OUTPUT, ' +
                     ' @cUserDefine01 NVARCHAR( 60)  OUTPUT, ' +
                     ' @cUserDefine02  NVARCHAR( 60)  OUTPUT, ' +
                     ' @cUserDefine03  NVARCHAR( 60)  OUTPUT, ' +
                     ' @cUserDefine04  NVARCHAR( 60)  OUTPUT, ' +
                     ' @cUserDefine05  NVARCHAR( 60)  OUTPUT, ' +
                     ' @nErrNo         INT            OUTPUT, ' +
                     ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCheckStorer, @cBarcode, @cCCRefNo, @cCCSheetNo,
                     @cLOC          OUTPUT, @cID            OUTPUT, @cUCC           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                     @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                     @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                     @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                     @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
                     @nErrNo        OUTPUT, @cErrMsg        OUTPUT

                  IF ISNULL( @cUPC, '') <> ''
                     SET @cSKU = @cUPC
               END
            END   -- End for DecodeSP

            EXEC dbo.nspg_GETSKU @cCheckStorer, @cSKU OUTPUT, @b_success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @b_success = 1
            BEGIN
               SET @cStorer = @cCheckStorer
               BREAK
            END

            FETCH NEXT FROM CUR_CheckSKU INTO @cCheckStorer
         END
         IF @b_success = 0
         BEGIN
            SET @nErrNo = 62120
            SET @cErrMsg = rdt.rdtgetmessage( 62120, @cLangCode, 'DSP') -- 'Invalid SKU'
            GOTO SKU_Blind_Sku_Fail
         END
         CLOSE CUR_CheckSKU
         DEALLOCATE CUR_CheckSKU
      END
      ELSE
      BEGIN
         SET @cDecodeLabelNo = ''
         SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorer)

         IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   --SOS320895
         BEGIN
            EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cLabel2Decode
            ,@c_Storerkey  = @cStorer
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
               GOTO SKU_Blind_Sku_Fail
            END

            SET @cSKU = @c_oFieled01
         END

         -- (james21)
         SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)
         IF @cDecodeSP = '0'
            SET @cDecodeSP = ''

         IF @cDecodeSP <> ''
         BEGIN
            SET @cBarcode = @cInField03
            SET @cUPC = ''

            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode,
                  @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                  @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                  @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                  @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                  @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT

               IF ISNULL( @cUPC, '') <> ''
                  SET @cSKU = @cUPC
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
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
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
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cBarcode, @cCCRefNo, @cCCSheetNo,
                  @cLOC          OUTPUT, @cID            OUTPUT, @cUCC           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                  @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                  @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                  @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                  @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
                  @nErrNo        OUTPUT, @cErrMsg        OUTPUT

               IF ISNULL( @cUPC, '') <> ''
                  SET @cSKU = @cUPC
            END
         END   -- End for DecodeSP

         SET @b_success = 0
         EXEC dbo.nspg_GETSKU @cStorer, @cSKU OUTPUT, @b_success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @b_success = 0
         BEGIN
            SET @nErrNo = 62120
            SET @cErrMsg = rdt.rdtgetmessage( 62120, @cLangCode, 'DSP') -- 'Invalid SKU'
            GOTO SKU_Blind_Sku_Fail
         END
      END
      -- SHONG001 (End)

      SELECT TOP 1
         @cSKUDescr = SKU.DESCR,
         @nCaseCnt  = PAC.CaseCnt,
         @cCaseUOM  = CASE WHEN PAC.CaseCnt > 0
                           THEN PAC.PACKUOM1
                         ELSE '' END,
         @cEachUOM  = PAC.PACKUOM3,
         @cPPK      = CASE WHEN SKU.PrePackIndicator = '2'
                           THEN 'PPK:' + CAST( SKU.PackQtyIndicator AS NVARCHAR( 2))
                         ELSE '' END
      FROM dbo.SKU SKU (NOLOCK)
      INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorer
      AND   SKU.SKU = @cSKU

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62121
         SET @cErrMsg = rdt.rdtgetmessage( 62121, @cLangCode, 'DSP') -- 'SKU Not Found'
         GOTO SKU_Blind_Sku_Fail
      END

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)

      -- Set cursor
      IF @cNewSKUSetFocusAtEA = '1'
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 8
      END
      ELSE
      BEGIN
         IF @nNewCaseCnt > 0
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 8   -- QTY (EA)
      END

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
      BEGIN
         SET @nErrNo = 66842
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO SKU_Blind_Sku_Fail
      END

      -- If SKUCONFIG setup
      IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
            JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
            WHERE S.StorerKey = @cStorer
            AND S.SKU = @cSKU
            AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
         BEGIN
            SET @nErrNo = 66844
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO SKU_Blind_Sku_Fail
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
            SET @cOutField09 = @cSKUDefaultUOM + ' ' + @cPPK   -- UOM (EA) + PPK
            SET @cFieldAttr06 = 'O'
            SET @cFieldAttr07 = 'O'
         END
      END
      ELSE
      BEGIN
          -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField06 = ''                            -- QTY (CS)
         SET @cOutField07 = @cCaseUOM                  -- UOM (CS)
         SET @cOutField08 = ''      -- QTY (EA)
         SET @cOutField09 = @cEachUOM + ' ' + @cPPK -- UOM (EA) + PPK
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField12 = ''
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
              ' @tExtValidate, @cExtendedInfo OUTPUT '
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
            ' @tExtValidate   VariableTable READONLY, ' +
      ' @cExtendedInfo  NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorer,
            @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel,
            @cLOC, @cID, @cUCC, @cSKU, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @tExtValidate, @cExtendedInfo OUTPUT

         IF @cExtendedInfo <> ''
            SET @cOutField15 = @cExtendedInfo
      END

      -- Go to next screen
      SET @nScn  = @nScn_Blind_Qty
      SET @nStep = @nStep_Blind_Qty
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --Enable screen
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

      IF @cSkipIDScn = '1' -- Skip id turn on then goto loc screen
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
            IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
            BEGIN
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

               -- Get next suggested LOC
               EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
                  @cFacility,
                  @cSuggestLogiLOC, -- current CCLogicalLOC
                  @cSuggestLogiLOC OUTPUT,
                  @cSuggestLOC OUTPUT,
                  @nCCCountNo,
                  @cUserName  -- (james05)
            END
            ELSE
            BEGIN
               -- Get next suggested LOC
               EXECUTE rdt.rdt_CycleCount_GetNextLOC
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
                  @cFacility,
                  @cSuggestLogiLOC, -- current CCLogicalLOC
                  @cSuggestLogiLOC OUTPUT,
                  @cSuggestLOC OUTPUT,
                  @nCCCountNo,
                  @cUserName  -- (james05)
            END

            -- If already last loc then display current loc and prompt "Last Loc"
            IF @cSuggestLOC = '' OR @cSuggestLOC IS NULL
            BEGIN
               SET @cLastLocFlag = 'Y'
               SET @nErrNo = 77728
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
         SET @cOutField06 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCBLINDCOUNT', @cStorer) = '1' THEN '' ELSE CAST( @nCCDLinesPerLOC AS NVARCHAR(5)) END   -- (james10)
         SET @cOutField07 = ''  -- ID

         -- Go to previous screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC
      END
      ELSE  -- GOTO id screen
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = @cDefaultCCOption
         SET @cOutField07 = '' -- ID

         -- SOS# 179935
         IF @cDefaultCCOption = ''
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- Option
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 7   -- ID

         -- (james12)
         SET @nNoOfTry = 0

         -- Go to next screen
         SET @nScn = @nScn_ID
         SET @nStep = @nStep_ID

         IF rdt.RDTGetConfig( @nFunc, 'SkipIDOPTScn', @cStorer) = '1'
         BEGIN
            SET @cOutField15 = ''
            GOTO Step_ID
         END
      END
   END
   GOTO Quit

   SKU_Blind_Sku_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = '' -- SKU/UPC
   END
END
GOTO Quit

/************************************************************************************
Step_Blind_Qty. Scn = 3262. Screen 27.
   LOC         (field01)
   ID    (field02)
   SKU/UPC     (field03)
   SKU DESCR1  (field04)
   SKU DESCR2  (field05)
   QTY         (field06) - CS - Input field
   UOM         (field07) - CS
   QTY         (field08) - EA - Input field
   UOM, PPK    (field09) - EA
************************************************************************************/
Step_Blind_Qty:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cCaseQTY = @cInField06
      SET @cEachQTY = @cInField08

      -- Retain the key-in value
      SET @cOutField06 = @cCaseQTY
      SET @cOutField08 = @cEachQTY


      -- Validate QTY (CS)
      IF @cCaseQTY <> '' AND @cCaseQTY IS NOT NULL
      BEGIN
         IF rdt.rdtIsValidQTY( @cCaseQTY, 20) <> 1
         BEGIN
            SET @nErrNo = 62122
            SET @cErrMsg = rdt.rdtgetmessage( 62122, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
            GOTO Blind_Qty_Fail
         END

   -- Check if the len of the qty cannot > 10
         IF LEN(LTRIM(RTRIM(@cCaseQTY))) > 10
         BEGIN
            SET @nErrNo = 66845
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
 EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
            GOTO Blind_Qty_Fail
         END

         -- Check max no of decimal is only 6
         IF rdt.rdtIsRegExMatch('^\d{0,6}(\.\d{1,6})?$', LTRIM(RTRIM(@cCaseQTY))) = 0
         BEGIN
            SET @nErrNo = 66846
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
            GOTO Blind_Qty_Fail
         END
      END

      -- Validate QTY (EA)
      IF @cEachQTY <> '' AND @cEachQTY IS NOT NULL
      BEGIN
    IF rdt.rdtIsValidQTY( @cEachQTY, 20) <> 1
         BEGIN
            SET @nErrNo = 62123
            SET @cErrMsg = rdt.rdtgetmessage( 62123, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 8   -- QTY (EA)
            GOTO Blind_Qty_Fail
         END

         -- Check if the len of the qty cannot > 10
         IF LEN(LTRIM(RTRIM(@cEachQTY))) > 10
         BEGIN
            SET @nErrNo = 66845
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (EA)
            GOTO Blind_Qty_Fail
         END

         -- Master unit not support decimal
         IF CHARINDEX('.', @cEachQTY) > 0
         BEGIN
            SET @nErrNo = 66846
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (EA)
            GOTO Blind_Qty_Fail
         END
      END

      -- (james08)
      SET @nCaseQTY = CASE WHEN @cCaseQTY <> '' AND @cCaseQTY IS NOT NULL THEN CAST( @cCaseQTY AS FLOAT) ELSE 0 END
      SET @nEachQTY = CASE WHEN @cEachQTY <> '' AND @cEachQTY IS NOT NULL THEN CAST( @cEachQTY AS FLOAT) ELSE 0 END

      -- Re-select CaseCnt (get the IDSCN_RDT casecnt)
      SELECT TOP 1
         @nCaseCnt  = PAC.CaseCnt
      FROM dbo.SKU SKU (NOLOCK)
      INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorer
      AND   SKU.SKU = @cSKU

      -- If CaseCnt not setup, not allow to enter QTY (CS)
      IF @nCaseCnt = 0 AND @nCaseQTY > 0
      BEGIN
         SET @nErrNo = 62124
         SET @cErrMsg = rdt.rdtgetmessage( 62124, @cLangCode, 'DSP') -- 'Zero CaseCnt'
         EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
         GOTO Blind_Qty_Fail
      END
/*
      -- Total of QTY must greater than zero
      IF @nCaseQTY + @nEachQTY = 0
      BEGIN
         SET @nErrNo = 62125
         SET @cErrMsg = rdt.rdtgetmessage( 62125, @cLangCode, 'DSP') -- 'QTY required'

         IF @nCaseCnt > 0
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (CS)
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 8   -- QTY (EA)

         GOTO Blind_Qty_Fail
      END
*/
      -- Convert QTY
      IF @nCaseCnt > 0
      BEGIN
         SET @nConvQTY = (@nCaseQTY * @nCaseCnt) + @nEachQTY
         SET @fConvQTY = (@nCaseQTY * @nCaseCnt) + @nEachQTY
      END
      ELSE
      BEGIN
         SET @nConvQTY = @nEachQTY
         SET @fConvQTY = @nEachQTY --ang01
 END

      -- Start Checking for decimal
      SET @nI = CAST(@fConvQTY AS INT) -- (james09)
      IF @nI <> CAST(@fConvQTY AS INT)
      BEGIN
         SET @nErrNo = 66847
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INV Qty
         GOTO Blind_Qty_Fail
      END

      -- Check if CCDetail record exists for LOC + SKU
      SET @cCCDetailKey = ''
      SELECT TOP 1 @cCCDetailKey = CCDetailKey FROM dbo.CCDetail WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND   CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
      AND   LOC = @cLOC
      AND   ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
      AND   SKU = @cSKU
      AND   Status < '9'
      AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 0 THEN 1
                     WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 0 THEN 1
                     WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 0 THEN 1
                     ELSE 0 END

      IF ISNULL(@cCCDetailKey, '') <> ''
      BEGIN
         -- Confirmed current record
         SET @nErrNo = 0
         SET @cErrMsg = ''
         IF dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer) <> '0'
            EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cCCDetailKey,
               @fConvQTY,
               @cUserName,
               @cLangCode,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT   -- screen limitation, 20 char max
         ELSE
            EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cCCDetailKey,
               @nConvQTY,
               @cUserName,
               @cLangCode,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT   -- screen limitation, 20 char max
      END
      ELSE  -- Cannot find the ccdetail, add new
      BEGIN
         -- Check if require lottables
         -- Initialize Lottables
         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = NULL
         SET @dLottable05 = NULL

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

         SET @cErrMsg = ''

         -- Get Lottables Details
         EXECUTE rdt.rdt_CycleCount_GetLottables
            @cCCRefNo, @cStorer, @cSKU, 'PRE', -- Codelkup.Short
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
            GOTO Blind_Qty_Fail

         -- Initiate next screen var
         IF @cHasLottable = '1'
         BEGIN
            -- Clear all outfields
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

            -- Initiate labels
            SELECT
               @cOutField01 = 'Lottable01:',
               @cOutField03 = 'Lottable02:',
               @cOutField05 = 'Lottable03:',
               @cOutField07 = 'Lottable04:',
      @cOutField09 = 'Lottable05:'

            -- Populate labels and lottables
            IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
            BEGIN
               SET @cFieldAttr02 = 'O'
            END
            ELSE
            BEGIN
               SELECT @cOutField01 = @cLotLabel01,
                      @cOutField02 = ISNULL(@cLottable01, '')
            END

            IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
               BEGIN
               SET @cFieldAttr04 = 'O'
            END
            ELSE
            BEGIN
               SELECT @cOutField03 = @cLotLabel02,
                      @cOutField04 = ISNULL(@cLottable02, '')
            END

            IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
            BEGIN
                SET @cFieldAttr06 = 'O'
            END
            ELSE
            BEGIN
              SELECT @cOutField05 = @cLotLabel03,
                     @cOutField06 = ISNULL(@cLottable03, '')
            END

            IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
            BEGIN
               SET @cFieldAttr08 = 'O'
            END
            ELSE
            BEGIN
               SELECT  @cOutField07 = @cLotLabel04,
                       @cOutField08 = RDT.RDTFormatDate(ISNULL(@dLottable04, ''))
            END

            IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
            BEGIN
               SET @cFieldAttr10 = 'O'
            END
            ELSE
            BEGIN
               -- Lottable05 is usually RCP_DATE
               IF @cLottable05_Code = 'RCP_DATE'
               BEGIN
                  SET @dLottable05 = GETDATE()
               END

               SELECT
                  @cOutField09 = @cLotLabel05,
                  @cOutField10 = RDT.RDTFormatDate( @dLottable05)
            END

            EXEC rdt.rdtSetFocusField @nMobile, 1   -- Lottable01 value

            -- Go to next screen
            SET @nScn  = @nScn_Blind_Lottables
            SET @nStep = @nStep_Blind_Lottables
            GOTO Quit
         END -- End of @cHasLottable = '1'

         -- Insert a record into CCDETAIL
         SET @nErrNo = 0
         SET @cErrMsg = ''
         IF dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer) <> '0'
         EXECUTE rdt.rdt_CycleCount_InsertCCDetail
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cStorer,
            @cSKU,
            '',            -- No UCC
            '',            -- No LOT generated yet
            @cLOC,         -- Current LOC
            @cID,          -- Entered ID, it can be blank
            @fConvQTY,
            '',            -- Lottable01
            '',            -- Lottable02
            '',    -- Lottable03
            NULL,          -- Lottable04
            NULL,          -- Lottable05
            @cUserName,
            @cLangCode,
            @cCCDetailKey OUTPUT,
            @nErrNo       OUTPUT,
            @cErrMsg      OUTPUT   -- screen limitation, 20 char max
         ELSE
            EXECUTE rdt.rdt_CycleCount_InsertCCDetail
               @cCCRefNo,
               @cCCSheetNo,
            @nCCCountNo,
               @cStorer,
               @cSKU,
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
               @cUserName,
               @cLangCode,
               @cCCDetailKey OUTPUT,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT   -- screen limitation, 20 char max

         IF @nErrNo <> 0
            GOTO Blind_Qty_Fail
      END

      IF @nErrNo <> 0
         GOTO Blind_Qty_Fail

     -- Add eventlog (cc02)
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '7',
         @nFunctionID   = @nFunc,
         @nMobileNo     = @nMobile,
         @cStorerKey    = @cStorer,
         @cFacility     = @cFacility,
         @cCCKey        = @cCCRefNo,
         @cLocation     = @cLOC,
         @cID           = @cID_In,
         @cUCC          = @cUCC,
         @cSKU          = @cSKU,
         @cCCSheetNo    = @cCCSheetNo,
         @nCountNo      = @nCCCountNo,
         @nQTY          = @nConvQTY


      -- Blank out SKU (ADD) Screen
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''   -- SKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField06 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField07 = CAST( @nCaseQTY AS NVARCHAR( 10))   -- QTY (CS)
      SET @cOutField08 = @cCaseUOM + ' [C]'                 -- UOM (CS) + [C]
      SET @cOutField09 = CAST( @nEachQTY AS NVARCHAR( 10))   -- QTY (EA)
      SET @cOutField10 = @cEachUOM + @cPPK                  -- UOM (EA) + PPK
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      SET @cOutField13 = ''
      SET @cOutField14 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU/UPC

      -- Go to next screen
      SET @nScn  = @nScn_Blind_Sku
      SET @nStep = @nStep_Blind_Sku

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
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
      SET @nScn  = @nScn_Blind_Sku
      SET @nStep = @nStep_Blind_Sku
   END
   GOTO Quit

   Blind_Qty_Fail:
END
GOTO Quit

/************************************************************************************
Step_Blind_Lottables. Scn = 3263. Screen 28.
   LOTTABLE01Label (field01)     LOTTABLE01 (field02) - Input field
   LOTTABLE02Label (field03)     LOTTABLE02 (field04) - Input field
   LOTTABLE03Label (field05)     LOTTABLE03 (field06) - Input field
   LOTTABLE04Label (field07)     LOTTABLE04 (field08) - Input field
   LOTTABLE05Label (field09)     LOTTABLE05 (field10) - Input field
*************************************************************************************/
Step_Blind_Lottables:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
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
         @cCCRefNo, @cStorer, @cSKU, 'POST', -- Codelkup.Short
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
         GOTO Blind_Add_Lottables_Fail
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
            GOTO Blind_Add_Lottables_Fail
         END

      -- Validate lottable02
      IF @cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL
      BEGIN
         IF @cNewLottable02 = '' OR @cNewLottable02 IS NULL
         BEGIN
            SET @nErrNo = 62127
            SET @cErrMsg = rdt.rdtgetmessage( 62127, @cLangCode, 'DSP') -- 'Lottable2 req'
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Blind_Add_Lottables_Fail
         END
      END

      -- Validate lottable03
      IF @cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL
         IF @cNewLottable03 = '' OR @cNewLottable03 IS NULL
         BEGIN
            SET @nErrNo = 62129
            SET @cErrMsg = rdt.rdtgetmessage( 62129, @cLangCode, 'DSP') -- 'Lottable3 req'
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Blind_Add_Lottables_Fail
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
            GOTO Blind_Add_Lottables_Fail
         END
         -- Validate date
         IF rdt.rdtIsValidDate( @cNewLottable04) = 0
         BEGIN
            SET @nErrNo = 62131
            SET @cErrMsg = rdt.rdtgetmessage( 62131, @cLangCode, 'DSP') -- 'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Blind_Add_Lottables_Fail
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
            GOTO Blind_Add_Lottables_Fail
         END
         -- Validate date
         IF rdt.rdtIsValidDate( @cNewLottable05) = 0
         BEGIN
            SET @nErrNo = 62133
            SET @cErrMsg = rdt.rdtgetmessage( 62133, @cLangCode, 'DSP') -- 'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO Blind_Add_Lottables_Fail
         END
      END

      -- Convert QTY
      IF @nCaseCnt > 0
         SET @nConvQTY = (@nCaseQTY * @nCaseCnt) + @nEachQTY
      ELSE
         SET @nConvQTY = @nEachQTY

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

    --GOTO Blind_Add_Lottables_Fail
      -- Insert a record into CCDETAIL
      SET @nErrNo = 0
      SET @cErrMsg = ''
      EXECUTE rdt.rdt_CycleCount_InsertCCDetail
         @cCCRefNo,
         @cCCSheetNo,
         @nCCCountNo,
         @cStorer,
         @cSKU,
         '',            -- No UCC
         '',            -- No LOT generated yet
         @cLOC,         -- Current LOC
         @cID,          -- Entered ID, it can be blank
         @nConvQTY,
         @cNewLottable01,
         @cNewLottable02,
         @cNewLottable03,
         @dNewLottable04,
         @dNewLottable05,
         @cUserName,
         @cLangCode,
         @cCCDetailKey OUTPUT,
         @nErrNo       OUTPUT,
         @cErrMsg      OUTPUT   -- screen limitation, 20 char max

      IF @nErrNo <> 0
         GOTO Blind_Add_Lottables_Fail

      -- Add eventlog (cc02)
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '7',
         @nFunctionID   = @nFunc,
         @nMobileNo     = @nMobile,
         @cStorerKey    = @cStorer,
         @cFacility     = @cFacility,
         @cCCKey        = @cCCRefNo,
         @cLocation     = @cLOC,
         @cID           = @cID_In,
         @cUCC          = @cUCC,
         @cSKU          = @cSKU,
         @cCCSheetNo    = @cCCSheetNo,
         @nCountNo      = @nCCCountNo,
         @nQty          = @nConvQTY

      -- Blank out SKU (ADD) Screen
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''   -- SKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField06 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField07 = CAST( @nCaseQTY AS NVARCHAR( 10))   -- QTY (CS)
      SET @cOutField08 = @cCaseUOM + ' [C]'                 -- UOM (CS) + [C]
      SET @cOutField09 = CAST( @nEachQTY AS NVARCHAR( 10))   -- QTY (EA)
      SET @cOutField10 = @cEachUOM + @cPPK                  -- UOM (EA) + PPK
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      SET @cOutField13 = ''
      SET @cOutField14 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU/UPC

      -- Go to next screen
      SET @nScn  = @nScn_Blind_Sku
      SET @nStep = @nStep_Blind_Sku

      GOTO Quit
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

      -- If SKUCONFIG setup
      IF ISNULL(@cSKUDefaultUOM, '0') <> '0'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU S WITH (NOLOCK)
            JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
            WHERE S.StorerKey = @cStorer
            AND S.SKU = @cSKU
            AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
         BEGIN
            SET @nErrNo = 66844
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV SKUDEFUOM'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO SKU_Blind_Sku_Fail
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
            SET @cOutField09 = @cSKUDefaultUOM + ' ' + @cPPK   -- UOM (EA) + PPK
            SET @cFieldAttr06 = 'O'
            SET @cFieldAttr07 = 'O'
         END
      END
      ELSE
      BEGIN
          -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField06 = ''                            -- QTY (CS)
         SET @cOutField07 = @cCaseUOM                  -- UOM (CS)
         SET @cOutField08 = ''      -- QTY (EA)
         SET @cOutField09 = @cEachUOM + ' ' + @cPPK -- UOM (EA) + PPK
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField12 = ''
      END

      -- Go to next screen
      SET @nScn  = @nScn_Blind_Qty
      SET @nStep = @nStep_Blind_Qty
   END
   GOTO Quit

   Blind_Add_Lottables_Fail:
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
Step_CCRef. Scn = 3264. Screen 29.
   LOC (field01)   - Display field
   SKU (field01)   - Input field
   L1 (field01)    - Input field
   L2 (field01)    - Input field
   L3 (field01)    - Input field
   L4 (field01)    - Input field
************************************************************************************/
Step_Validate_SKULottables:   -- (james15)
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SELECT @nValidateSKU = CASE WHEN Short = '1' THEN 1 ELSE 0 END
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'CCVALFIELD'
    AND   StorerKey = @cStorer
      AND   Code = 'SKU'

      SELECT @nValidateLot01 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'CCVALFIELD'
      AND   StorerKey = @cStorer
      AND   Code = 'LOTTABLE01'

      SELECT @nValidateLot02 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'CCVALFIELD'
      AND   StorerKey = @cStorer
      AND   Code = 'LOTTABLE02'

      SELECT @nValidateLot03 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'CCVALFIELD'
      AND   StorerKey = @cStorer
      AND   Code = 'LOTTABLE03'

      SELECT @nValidateLot04 = CASE WHEN Short = '1' THEN 1 ELSE 0 END
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'CCVALFIELD'
      AND   StorerKey = @cStorer
      AND   Code = 'LOTTABLE04'

      -- Screen mapping
      SET @cDisplaySKU = CASE WHEN @nValidateSKU = 1 THEN @cOutField02 ELSE '' END
      SET @cDisplayLot01 = CASE WHEN @nValidateLot01 = 1 THEN @cOutField04 ELSE '' END
      SET @cDisplayLot02 = CASE WHEN @nValidateLot02 = 1 THEN @cOutField06 ELSE '' END
      SET @cDisplayLot03 = CASE WHEN @nValidateLot03 = 1 THEN @cOutField08 ELSE '' END
      SET @cDisplayLot04 = CASE WHEN @nValidateLot04 = 1 THEN @cOutField10 ELSE '' END

      SET @cValidateSKU = CASE WHEN @nValidateSKU = 1 THEN @cInField03 ELSE '' END
      SET @cValidateLot01 = CASE WHEN @nValidateLot01 = 1 THEN @cInField05 ELSE '' END
      SET @cValidateLot02 = CASE WHEN @nValidateLot02 = 1 THEN @cInField07 ELSE '' END
      SET @cValidateLot03 = CASE WHEN @nValidateLot03 = 1 THEN @cInField09 ELSE '' END
      --SET @cValidateLot04 = CASE WHEN @nValidateLot04 = 1 THEN rdt.rdtFormatDate( @cInField11) ELSE '' END
      SET @cValidateLot04 = CASE WHEN @nValidateLot04 = 1 THEN @cInField11 ELSE '' END

      IF @nValidateSKU = 1 AND ( ISNULL( @cDisplaySKU, '') <> ISNULL( @cValidateSKU, ''))
      BEGIN
         SET @nErrNo = 77715
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID SKU'
         SET @cOutField03 = ''
         SET @cOutField05 = @cValidateLot01
         SET @cOutField07 = @cValidateLot02
         SET @cOutField09 = @cValidateLot03
         SET @cOutField11 = @cValidateLot04
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END

      IF @nValidateLot01 = 1 AND ( ISNULL( @cDisplayLot01, '') <> ISNULL( @cValidateLot01, ''))
      BEGIN
         SET @nErrNo = 77716
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID LOT01'
         SET @cOutField03 = @cValidateSKU
         SET @cOutField05 = ''
         SET @cOutField07 = @cValidateLot02
         SET @cOutField09 = @cValidateLot03
         SET @cOutField11 = @cValidateLot04
         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Quit
      END

      IF @nValidateLot02 = 1 AND ( ISNULL( @cDisplayLot02, '') <> ISNULL( @cValidateLot02, ''))
      BEGIN
         SET @nErrNo = 77717
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID LOT02'
         SET @cOutField03 = @cValidateSKU
         SET @cOutField05 = @cValidateLot01
         SET @cOutField07 = ''
         SET @cOutField09 = @cValidateLot03
         SET @cOutField11 = @cValidateLot04
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Quit
      END

      IF @nValidateLot03 = 1 AND ( ISNULL( @cDisplayLot03, '') <> ISNULL( @cValidateLot03, ''))
      BEGIN
         SET @nErrNo = 77718
 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID LOT03'
         SET @cOutField03 = @cValidateSKU
         SET @cOutField05 = @cValidateLot01
         SET @cOutField07 = @cValidateLot02
         SET @cOutField09 = ''
         SET @cOutField11 = @cValidateLot04
         EXEC rdt.rdtSetFocusField @nMobile, 9
         GOTO Quit
      END

      IF @nValidateLot04 = 1 AND ( ISNULL( @cDisplayLot04, '') <> ISNULL( @cValidateLot04, ''))
      BEGIN
         SET @nErrNo = 77719
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID LOT04'
         SET @cOutField03 = @cValidateSKU
         SET @cOutField05 = @cValidateLot01
         SET @cOutField07 = @cValidateLot02
         SET @cOutField09 = @cValidateLot03
         SET @cOutField11 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 11
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
      IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorer) = '1'
      BEGIN
         SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU
         SET @cOutField03 = 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16)
      END
      ELSE
      BEGIN
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
      END

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
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
            WHERE S.StorerKey = @cStorer
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
         WHERE S.StorerKey = @cStorer
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
            IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1
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
            IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1
            BEGIN
               SET @cOutField06 = CAST( 0 AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP02)
            END
            ELSE
            BEGIN
               SET @cOutField06 = @f_Qty                     -- QTY (EA)
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
         IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1
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
      SET @cOutField08 = @cLottable01
      SET @cOutField09 = @cLottable02
      SET @cOutField10 = @cLottable03
      SET @cOutField11 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField12 = rdt.rdtFormatDate( @dLottable05)
      SET @cOutField13 = ''   -- Option

      -- Go to next screen
      SET @nScn  = @nScn_SKU_Edit_Qty
      SET @nStep = @nStep_SKU_Edit_Qty
   END

   IF @nInputKey = 0 -- NO or ESC
   BEGIN
      GOTO_SKU_SCREEN:
      SET @cID = @cID_In

      -- Prepare SKU screen var
      SET @cOutField01 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE @cSKU END
      SET @cOutField02 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20) END
      IF rdt.RDTGetConfig( @nFunc, 'REPLACESKUDESCRWITHUPC', @cStorer) = '1'
      BEGIN
         SELECT @cRetailSKU = RetailSKU FROM dbo.SKU (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU
         SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE 'UPC:' + SUBSTRING( @cRetailSKU, 1, 16) END
      END
      ELSE
      BEGIN
         SET @cOutField03 = CASE WHEN @cDefaultCCOption = '4' OR @cBlindCount = '1' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 40) END
      END

      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND ISNULL(@cSKUDefaultUOM, '0') = '0'
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
            WHERE S.StorerKey = @cStorer
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

         SELECT @c_PackKey = P.PackKey
         FROM dbo.Pack P WITH (NOLOCK)
         JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
         WHERE S.StorerKey = @cStorer
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
            SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
         END
      END
      ELSE
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'CCNOTSHOWSYSQTY', @cStorer) = 1
         BEGIN
            SET @cOutField04 = CAST( 0 AS NVARCHAR(10))   -- QTY (CS) -- (Shong003)
            SET @cOutField06 = CAST( 0 AS NVARCHAR(10))   -- QTY (EA) -- (Shong003)
         END
         ELSE
         BEGIN
            -- (james25)
            IF @cShowCaseCnt = '1'
               SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(6)) + '/' + CAST( @nCaseCnt AS NVARCHAR( 4))
            ELSE
               SET @cOutField04 = CAST( @nCaseQTY AS NVARCHAR(10))   -- QTY (CS) -- (ChewKP01)

            SET @cOutField06 = CAST( @nEachQTY AS NVARCHAR(10))   -- QTY (EA) -- (ChewKP01)
         END

         SET @cOutField05 = @cCaseUOM + ' ' + @cCountedFlag   -- UOM (CS)
         SET @cOutField07 = @cEachUOM + @cPPK           -- UOM (EA) + PPK
      END

      -- (james14)
      SET @cSKUCountDefaultOpt = ''
      SET @cSKUCountDefaultOpt = rdt.RDTGetConfig( @nFunc, 'CCCountBySKUDefaultOpt', @cStorer)
      IF ISNULL( @cSKUCountDefaultOpt, '') = '' OR @cSKUCountDefaultOpt NOT IN ('1', '2')
         SET @cSKUCountDefaultOpt = ''

      SET @cOutField08 = @cID
      SET @cOutField09 = @cLottable01
      SET @cOutField10 = @cLottable02
      SET @cOutField11 = @cLottable03
      SET @cOutField12 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField13 = rdt.rdtFormatDate( @dLottable05)
      SET @cOutField14 = CASE WHEN @cCountedFlag = '[C]' THEN '' ELSE @cSKUCountDefaultOpt END   -- Option    (james14)
      SET @cOutField15 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CCShowOnlyCountedQty', @cStorer) = 1
                              THEN RIGHT( SPACE(4) + CAST( @nCntQTY AS NVARCHAR( 4)), 4)
                              ELSE CAST( @nCntQTY AS NVARCHAR( 4)) + '/' + CAST( @nCCDLinesPerLOCID AS NVARCHAR( 4))
                              END

       -- Go to SKU (Main) screen
      SET @nScn  = @nScn_SKU
      SET @nStep = @nStep_SKU
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

      StorerKey      = @cStorer,
      Facility       = @cFacility,

      V_LOC          = @cLOC,
      V_ID           = @cID,
      V_LOT          = @cLOT,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
      V_UOM          = @cUOM,
      V_UCC          = @cUCC,
      V_Lottable01   = @cLottable01,
      V_Lottable02   = @cLottable02,
      V_Lottable03   = @cLottable03,
      V_Lottable04   = @dLottable04,
      V_Lottable05   = @dLottable05,

      V_String1      = @cCCRefNo,
      V_String2      = @cCCSheetNo,
      V_String3      = @cShowCaseCnt,
      V_String4      = @cSuggestLOC,
      V_String5      = @cSuggestLogiLOC,
      V_String6      = @cExtendedInfoSP,
      V_String7      = @cNewSKUSetFocusAtEA,
      V_String8      = @cStatus,
      V_String9      = @cPPK,
      V_String10     = @cSheetNoFlag,  -- (MaryVong01)
      V_String11     = @cLocType,
      V_String12     = @cCCDetailKey,
      V_String13     = @cSkipIDScn,
      V_String16     = @cCaseUOM,
      V_String17     = @cExtendedUpdateSP,
      V_String18     = @cEachUOM,
      V_String19     = @cLastLocFlag,   -- (MaryVong01)
      V_String20     = @cDefaultCCOption,

      V_String21     = @cCountedFlag,
      V_String22     = @cWithQtyFlag,

      V_String23     = @cNewUCC,
      V_String24     = @cNewSKU,
      V_String25     = @cNewSKUDescr1,
      V_String26     = @cNewSKUDescr2,
      V_String27     = @cDoubleDeep,
      V_String30     = @cNewCaseUOM,
      V_String32     = @cNewEachUOM,
      V_String33     = @cNewPPK,
      V_String34     = @cNewLottable01,
      V_String35     = @cNewLottable02,
      V_String36     = @cNewLottable03,
      V_String39     = @cAddNewLocFlag,   -- (MaryVong01)
      V_String40     = @cID_In,  -- SOS79743
      V_ReceiptKey   = @cRecountFlag,      -- Used for RecountFlag
      V_LoadKey      = @cPrevCCDetailKey,  -- Used to control Counter in SKU screen
      V_PickSlipNo   = @cEditSKU, -- (Vicky03)
      V_ConsigneeKey = @cBlindCount,   -- (james10)
      V_String41     = @cCurSuggestLogiLOC,
      V_String42     = @cOptAction,
      V_String43     = @cAllowAddUCCNotInLocSP,
      V_String44     = @cCountTypeUCCSpecialHandling,
      V_String45     = @cFlowThruStepSKU,
      V_String46     = @cSKUEditQTYNotAllowBlank,
      V_String47     = @cStepSKUAllowOpt,
      V_String48     = @cExtendedValidSP,

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
      V_Integer15    = @nNoOfTry,

      V_DateTime1    = @dNewLottable04,
      V_DateTime2    = @dNewLottable05,
      V_Barcode      = @cBarcode, 

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
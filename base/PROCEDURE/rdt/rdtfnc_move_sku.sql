SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Move_SKU                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: normal receipt                                              */
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
/* Date       Rev  Author   Purposes                                    */
/* 2006-07-25 1.0  UngDH    Created                                     */
/* 2006-01-18 1.1  UngDH    Support config 'MoveToLOCNotCheckFacility'  */
/* 2007-08-09 1.2  Vicky    Bug Fix on Qty Screen - QtyAvail showing    */
/* 2007-12-06 1.3  James    SOS92972 - Bug fix on disable prefered      */
/*                          qty field if prefered UOM = 6 (EA)          */
/* 2008-11-03 1.4  Vicky    Remove XML part of code that is used to     */
/*                          make field invisible and replace with new   */
/*                          code (Vicky02)                              */
/* 2009-07-06 1.5  Vicky    Add in EventLog (Vicky06)                   */
/* 2009-11-12 1.6  James    Performance tuning on sku retrieve (james01)*/
/* 2010-07-16 1.7  James    Bug fix (james02)                           */
/* 2010-09-15 1.8  Shong    QtyAvailable Should exclude QtyReplen       */
/* 2011-05-16 1.9  Ung      SOS 215230. Add FromLOC same as ToLOC check */
/* 2012-11-21 2.0  James    SOS#261739 Default FromLoc, use Decode Label*/
/*                          & use sku.innerpack to calc qty    (james03)*/
/* 2013-03-04 2.1  SPChin   SOS271541 - Enhancement and Bug Fixed       */
/* 2013-03-08 2.2  James    SOS271810 - Show suggested loc (james04)    */
/* 2013-05-03 2.0  James    SOS276237 - Allow multi storer (james05)    */
/* 2013-06-11 2.1  James    SOS276237 - Allow same fromloc toloc move   */
/*                          by using storerconfig (james06)             */
/* 2013-09-12 2.2  James    SOS289473 - Bug fix on qty display (james07)*/
/* 2013-08-26 2.3  Ung      SOS287899                                   */
/*                          After move go to FromLOC/ID/SKU screen      */
/*                          Add ExtendedUpdateSP                        */
/* 2013-11-22 2.4  James    SOS295127 - Show TOLOC on sucessfull move   */
/*                          screen (james08)                            */
/* 2013-04-25 2.5  Ung      SOS276721 Fix SKU UPC > 20 chars (ung01)    */
/* 2013-12-03 2.6  ChewKP   SOS#292549 - Fixes & Enhancement (ChewKP01) */
/* 2014-05-15 2.7  Ung      Fix ToID ESC cleared SKU scanned            */
/* 2014-06-26 2.8  Ung      SOS314842 ExtendedUpdateSP after rdt_Move   */
/* 2014-09-03 2.9  Ung      Remove MoveBySKUShowSuggestedLOC            */
/*                          Remove PendingMoveIn UNLOCK                 */
/* 2015-06-01 3.0  James    SOS342318 - Add RDT config to go back scn 1 */
/*                          after move without check condition (james09)*/
/* 2015-07-06 3.1  ChewKP   SOS#342416 - Add V_String for LabelNo       */
/*                          (ChewKP02)                                 */
/* 2015-04-27 3.2  Ung      SOS337296 Add PABookingKey                  */
/* 2015-10-02 3.3  Ung      SOS350420 Add SuggestedIDSP                 */
/* 2015-12-15 3.4  Ung      SOS358873 SuggestedLOCSP not show if no LOC */
/* 2016-05-27 3.5  Ung      SOS370942 Add DecodeSP                      */
/* 2016-08-04 3.6  Ung      SOS374750 Add DefaultToID                   */
/*                          Add ExtendedValidateSP on step 5            */
/* 2016-10-05 3.7  James    Perf tuning                                 */
/* 2017-02-17 3.8  Ung      WMS-961 Add ExtendedValidateSP at step 3    */
/* 2017-12-04 3.9  Ung      WMS-3547 Add serial no                      */
/* 2018-01-16 4.0  James    INC0099268-Reset @nQty variable (james10)   */
/* 2018-06-05 4.1  James    WMS5309-Add rdt_decode (james10)            */
/* 2018-08-27 4.2  ChewKP   WMS-6052 - Standardize EventLog (ChewKP03)  */
/* 2018-09-18 4.3  James    WMS6353-Add rdtformat @ id screen (james11) */
/* 2018-09-28 4.4  Gan      Performance                                 */
/* 2018-10-31 4.5  CheeMun  INC0448387- Reset @nQty variable            */
/* 2018-11-16 4.6  ChewKP   WMS-7029 -- Add Lot checking (ChewKP04)     */
/* 2018-10-30 4.7  Ung      WMS-6866 Add ConfirmSP                      */
/* 2018-10-11 4.8  Ung      WMS-6467 Add PrepackIndicator, DefaultQTY   */
/* 2015-01-12 4.9  James    Allow 7 digits qty (james12)                */
/* 2019-03-05 5.0  YeeKung  WMS-8196 Add loc prefix (yeekung01)         */
/* 2019-04-01 5.1  PakYuen  INC0645262 - Fix unable to proceed to Step 3*/
/* 2019-05-10 5.2  James    WMS-9013 Skip From/To ID scn if From/To     */
/*                          LoseID = 1 when config turned on (james13)  */
/* 2019-05-14 5.3  James    WMS-9016 Add MultiSKUBarcode scn (james14)  */
/* 2019-05-15 5.4  James    WMS-9098 Add ExtendedInfoSP (james15)       */
/* 2019-07-11 5.5  James    WMS9712 Remove @nErrNo display from         */
/*                          rdt_Decode (james16)                        */
/* 2019-10-17 5.6  Pakyuen  INC0897289 Go to step fail                  */
/* 2020-02-04 5.7  YeeKung  WMS11793 Add loc as doctype (yeekung02)     */
/* 2020-01-03 5.8  YeeKung  WMS-11540 support lotxlocxid.id (yeekung03) */
/* 2020-10-23 5.9  James    WMS-15449 Add ExtValid @ step 2 (james17)   */
/* 2020-10-14 6.0  Chermain WMS-14688 backSKUScn without check sku (cc01)*/
/* 2021-03-17 6.1  James    WMS-16555 Add FlowThruToIDScn (james18)     */
/* 2021-09-01 6.2  James    WMS-17800 Add FlowThruQtyScn (james19)      */
/* 2022-08-23 6.3  YeeKung  WMS-19594 Add ExtendedValidateSP (yeekung04)*/
/* 2023-04-10 6.4  James    WMS-22175 Add V_Barcode to sku step for     */
/*                          sku input (james20)                         */
/* 2023-11-02 6.5  XiaoLun  JSM-186877 Fixed 'QTY AVL' row get wrong  	*/  
/*       				          	value (xiaolun01)       					*/  
/* 2023-03-12 6.6  YeeKung  WMS-24222 Skip PPK Check (yeekung05)        */
/* 2023-08-10 6.7  Ung      WMS-23729 Add PieceScan                     */
/* 2024-03-26 6.8  Dennis   UWP-14536 Check Digit                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_Move_SKU] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 NVARCHAR max
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
   @cSerialNo    NVARCHAR( 30),
   @nSerialQTY   INT,
   @nMoreSNO     INT

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

   @cFromLOC    NVARCHAR( 10),
   @cFromID     NVARCHAR( 18),
   @cSKU        NVARCHAR( 30),  -- (ung01)
   @cSKUDescr   NVARCHAR( 60),

   @cPUOM       NVARCHAR( 1), -- Pref UOM
   @cPUOM_Desc  NVARCHAR( 5), -- Pref UOM desc
   @cMUOM_Desc  NVARCHAR( 5), -- Master UOM desc
   @nQTY_Avail  INT,      -- QTY avail in master UOM
   @nPQTY_Avail INT,      -- QTY avail in pref UOM
   @nMQTY_Avail INT,      -- Remaining QTY in master UOM
   @nQTY        INT,      -- QTY to move, in master UOM
   @nPQTY       INT,      -- QTY to move, in pref UOM
   @nMQTY       INT,      -- Remining QTY to move, in master UOM
   @nPUOM_Div   INT,
   @nPieceScanQTY INT,

   @cToLOC        NVARCHAR( 10),
   @cToID         NVARCHAR( 18),
   @cPieceScanSKU NVARCHAR( 20),

   @cUserName   NVARCHAR(18), -- (Vicky06)
   @b_success   INT,      -- (james01)
   @n_err       INT,      -- (james01)
   @c_errmsg    NVARCHAR( 20),-- (james01)

   @cSuggestLocSP       NVARCHAR( 20),    -- (james04)
   @nMultiStorer        INT,              -- (james05)
   @cSKU_StorerKey      NVARCHAR( 15),    -- (james05)
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cGoBackFromLocScn   NVARCHAR( 20),    -- (james09)
   @cLabelNo            NVARCHAR(20),     -- (ChewKP02)
   @nPABookingKey       INT,
   @nFromStep           INT,
   @cSuggestIDSP        NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20),
   @cDefaultToID        NVARCHAR( 1),
   @cSerialNoCapture    NVARCHAR( 1),
   @cConfirmSP          NVARCHAR( 20),
   @cDefaultQTY         NVARCHAR( 1),
   @cBarcode            NVARCHAR( MAX),
   @cPrePackIndicator   NVARCHAR(30),
   @nPackQtyIndicator   INT,
   @cLOCLookupSP        NVARCHAR(20), --(yeekung01)
   @cSkipIDScnIFLocLoseID  NVARCHAR( 1),  -- (james13)
   @cFromLocLoseID         NVARCHAR( 1),  -- (james13)
   @cMultiSKUBarcode       NVARCHAR( 1),  -- (james14)
   @cOnScreenSKU           NVARCHAR(20),  -- (james14)
   @nFromScn               INT,           -- (james14)
   @cExtendedInfoSP        NVARCHAR( 20), -- (james15)
   @cExtendedInfo          NVARCHAR( 20), -- (james15)
   @tExtInfo               VariableTable, -- (james15)
   @cGoBackSKUScn          NVARCHAR( 20), -- (cc01)
   @nFlowThruToIDScn       INT,           -- (james18)
   @cDefaultSuggToLoc      NVARCHAR( 10), -- (james18)
   @nFlowThruQtyScn        INT,           -- (james19)
   @cSkipChkPPKQTY         NVARCHAR( 20), -- (yeekung05)
   @cPieceScan             NVARCHAR( 1),
   @cExtendedScreenSP      NVARCHAR( 20),
   @nAction                INT,
   @nAfterScn              INT,
   @nAfterStep             INT,
   @cLocNeedCheck          NVARCHAR( 20),

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

-- (james03)
DECLARE
   @c_oField01 NVARCHAR(20), @c_oField02 NVARCHAR(20),
   @c_oField03 NVARCHAR(20), @c_oField04 NVARCHAR(20),
   @c_oField05 NVARCHAR(20), @c_oField06 NVARCHAR(20),
   @c_oField07 NVARCHAR(20), @c_oField08 NVARCHAR(20),
   @c_oField09 NVARCHAR(20), @c_oField10 NVARCHAR(20),
   @c_oField11 NVARCHAR(20), @c_oField12 NVARCHAR(20),   -- (james04)
   @c_oField13 NVARCHAR(20), @c_oField14 NVARCHAR(20),   -- (james04)
   @c_oField15 NVARCHAR(20),                              -- (james04)
   @cDecodeLabelNo NVARCHAR( 20),
   @c_LabelNo        NVARCHAR( 32),
   @cDefaultLOC      NVARCHAR( 20),
   @cDecodeQty       NVARCHAR(  5),
   @cAvlQTY          NVARCHAR(  5)


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
   @cFromLOC    = V_LOC,   -- (james05)
   @cFromID     = V_ID,    -- (james05)

   @cSKUDescr   = V_SKUDescr,
   @cPUOM       = V_UOM,      -- Pref UOM
   @nPQTY       = V_PQTY,     --SOS271541
   @nMQTY       = V_MQTY,     --SOS271541
   @nPUOM_Div   = V_PUOM_Div, --SOS271541
   @nFromStep   = V_FromStep,
   @nFromScn    = V_FromScn,
   @cBarcode    = V_Barcode,

   @cFromLOC    = V_String1,
   @cFromID     = V_String2,
   @cSKU        = V_String3,
   @cPUOM_Desc  = V_String4, -- Pref UOM desc
   @cMUOM_Desc  = V_String5, -- Master UOM desc
   @cSkipIDScnIFLocLoseID = V_String6,
   @cFromLocLoseID   = V_String7,
   @cMultiSKUBarcode = V_String8,
   @cExtendedInfoSP  = V_String9,
   @cExtendedInfo    = V_String10,
   @cToLOC           = V_String13,
   @cToID            = V_String14,
   @cPieceScanSKU    = V_String15,
   @cSKU_StorerKey      = V_String16,   -- (james05)
   @cExtendedUpdateSP   = V_String17,
   @cSuggestLocSP       = V_String18,
   @cExtendedValidateSP = V_String19,
   @cGoBackFromLocScn   = V_String20,
   @cLabelNo            = V_String21, -- (ChewKP02)
   @cPieceScan          = V_String22,
   @cSuggestIDSP        = V_String24,
   @cDecodeSP           = V_String25,
   @cDefaultToID        = V_String26,
   @cSerialNoCapture    = V_String27,
   @cConfirmSP          = V_String28,
   @cDefaultQTY         = V_String29,
   @cGoBackSKUScn       = V_String30,  --(cc01)
   @cPrePackIndicator   = V_String41,
   @cLOCLookupSP        = V_String42, --(yeekung01)
   @cDefaultSuggToLoc   = V_String43, --(james18)
   @cSkipChkPPKQTY      = V_String44,

   @nQTY_Avail          = V_Integer1,   --SOS271541
   @nPQTY_Avail         = V_Integer2,   --SOS271541
   @nMQTY_Avail         = V_Integer3,   --SOS271541
   @nQTY                = V_Integer4,   --SOS271541
   @nMultiStorer        = V_Integer5,
   @nPABookingKey       = V_Integer6,
   @nPackQtyIndicator   = V_Integer7,
   @nFlowThruToIDScn    = V_Integer8, --(james18)
   @nFlowThruQtyScn     = V_Integer9, --(james19)
   @nPieceScanQTY       = V_Integer10,

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
   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15
   -- (Vicky02) - End

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 513 -- Move SKU
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0   -- Func = Move SKU
   IF @nStep = 1  GOTO Step_1   -- Scn = 1030. FromLOC
   IF @nStep = 2  GOTO Step_2   -- Scn = 1031. FromID
   IF @nStep = 3  GOTO Step_3   -- Scn = 1032. SKU, desc1, desc2
   IF @nStep = 4  GOTO Step_4   -- Scn = 1033. UOM, QTY
   IF @nStep = 5  GOTO Step_5   -- Scn = 1034. ToID
   IF @nStep = 6  GOTO Step_6   -- Scn = 1035. ToLOC
   IF @nStep = 7  GOTO Step_7   -- Scn = 1036. Message
   IF @nStep = 8  GOTO Step_8   -- Scn = 1037. Suggested ID/LOC
   IF @nStep = 9  GOTO Step_9   -- Scn = 4830. Serial no
   IF @nStep = 10 GOTO Step_10  -- Scn = 3570. Multi SKU Barcode
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 513. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1030
   SET @nStep = 1

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1

   -- Storer configure
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)
   IF @cDefaultQTY = '0'
      SET @cDefaultQTY = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cSkipChkPPKQTY = rdt.rdtGetConfig( @nFunc, 'SkipChkPPKQTY', @cStorerKey)
   IF @cSkipChkPPKQTY = '0'
      SET @cSkipChkPPKQTY = ''
   SET @cSuggestLocSP = rdt.RDTGetConfig( @nFunc, 'SuggestedLocSP', @cStorerKey)
   IF @cSuggestLocSP = '0'
      SET @cSuggestLocSP = ''
   SET @cSuggestIDSP = rdt.RDTGetConfig( @nFunc, 'SuggestedIDSP', @cStorerKey)
   IF @cSuggestIDSP = '0'
      SET @cSuggestIDSP = ''

   SET @cDefaultSuggToLoc = rdt.rdtGetConfig( @nFunc, 'DefaultSuggToLoc', @cStorerKey)
   SET @nFlowThruQtyScn = rdt.rdtGetConfig( @nFunc, 'FlowThruQtyScn', @cStorerKey)
   SET @nFlowThruToIDScn = rdt.rdtGetConfig( @nFunc, 'FlowThruToIDScn', @cStorerKey)
   SET @cGoBackFromLocScn = rdt.rdtGetConfig( @nFunc, 'MoveBySKUGoBackFromLocScn', @cStorerKey)
   SET @cGoBackSKUScn = rdt.rdtGetConfig( @nFunc, 'MoveBySKUGoBackSKUScn', @cStorerKey) --(cc01)
   SET @cLOCLookupSP = rdt.rdtGetConfig(@nFunc,'LOCLookupSP',@cStorerKey)   --(yeekung01)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)
   SET @cPieceScan = rdt.RDTGetConfig( @nFunc, 'PieceScan', @cStorerKey)
   SET @cSerialNoCapture = rdt.rdtGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey)
   SET @cSkipIDScnIFLocLoseID = rdt.RDTGetConfig( @nFunc, 'SkipIDScnIFLocLoseID', @cStorerKey)

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
   SET @cFromID = ''
   SET @cDefaultLOC = ''

   -- (james03)
   SET @cDefaultToID = ISNULL(rdt.RDTGetConfig( @nFunc, 'DefaultToID', @cStorerKey), '')
   SET @cDefaultLOC = ISNULL(rdt.RDTGetConfig( @nFunc, 'DefaultFromLoc', @cStorerKey), '')
   IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
  WHERE Facility = @cFacility
                  AND   LOC = @cDefaultLOC)
      SET @cOutField01 = '' -- FromLOC
   ELSE
      -- Prep next screen var
      SET @cOutField01 = @cDefaultLOC -- FromLOC

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


/********************************************************************************
Step 1. Scn = 1030. FromLOC
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
         SET @nErrNo = 60551
         SET @cErrMsg = rdt.rdtgetmessage( 60551, @cLangCode, 'DSP') --'LOC needed'
         GOTO Step_1_Fail
      END
      
      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '513ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_513ExtScnEntry] 
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
  -- add from loc prefix (yeekung01)
  IF @cLOCLookupSP = 1
  BEGIN
   EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
   @cFromLOC    OUTPUT,
   @nErrNo     OUTPUT,
   @cErrMsg    OUTPUT
   IF @nErrNo <> 0
    GOTO Step_1_Fail
  END

      SET @cFromLocLoseID = ''

      -- Get LOC info
      SELECT @cChkFacility = Facility,
             @cFromLocLoseID = LoseID
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 60552
         SET @cErrMsg = rdt.rdtgetmessage( 60552, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_1_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 60553
         SET @cErrMsg = rdt.rdtgetmessage( 60553, @cLangCode, 'DSP') --'Diff facility'
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
               AND ISNULL(LOT,'') <> '' -- (ChewKP04)
               AND Status = 1) -- 1=Received
         BEGIN
            SET @nErrNo = 60554
            SET @cErrMsg = rdt.rdtgetmessage( 60554, @cLangCode, 'DSP') --'LOC have UCC'
            GOTO Step_1_Fail
         END
      END

     EXEC RDT.rdt_STD_EventLog
       @cActionType = '3',
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @cLocation   = @cFromLOC,
       @nStep       = @nStep

      -- Prep next screen var
      SET @cFromID = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' --@cFromID

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- (james13)
      -- if loc.loseid = 1 and config turn on then flow thru id screen
      IF @cFromLocLoseID = '1' AND @cSkipIDScnIFLocLoseID = '1'
         GOTO Step_2
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

   Step_1_Fail:
   BEGIN
      SET @cFromLOC = ''
      SET @cOutField01 = '' -- LOC
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 1031. FromID
   FromLOC (field01)
   FromID  (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
   	DECLARE @cIDBarcode  NVARCHAR( 60)

      -- Screen mapping
      SET @cFromID = @cInField02
      SET @cIDBarcode = @cInField02

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'FROMID', @cIDBarcode) = 0
      BEGIN
         SET @nErrNo = 60568
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_2_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1' AND ISNULL( @cIDBarcode, '') <> ''  -- blank string no need decode
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cIDBarcode,
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cIDBarcode,
               @cFromLOC    OUTPUT, @cFromID     OUTPUT,
               @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cToLOC      OUTPUT, @cToID       OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END

      -- Validate ID
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN StorerKey ELSE @cStorerKey END
            AND LOC = @cFromLOC
            AND ID = @cFromID
            AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0)
      BEGIN
         SET @nErrNo = 60555
         SET @cErrMsg = rdt.rdtgetmessage( 60555, @cLangCode, 'DSP') --'Invalid ID'
         GOTO Step_2_Fail
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
               GOTO Step_2_Fail
         END
      END

      EXEC RDT.rdt_STD_EventLog
       @cActionType = '3',
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @cLocation   = @cFromLOC,
       @cID         = @cFromID,
       @nStep       = @nStep

      -- Reset (james10)
      --SET @nQTY = 0

      SET @nFromScn = 0
      SET @nFromStep = 0

      SET @cPieceScanSKU = ''
      SET @nPieceScanQTY = 0

      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' --@cSKU
      SET @cOutField04 = '' --@cSKUDescr
      SET @cOutField05 = '' --@cSKUDescr
      SET @cOutField06 = '' -- PieceScanQTY
      SET @cBarcode = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cFromLOC = ''
      SET @cOutField01 = @cFromLOC

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
Step 3. scn = 1032. SKU screen
   FromLOC (field01)
   FromID  (field02)
   SKU     (field03, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      --SET @cBarcode = @cInField03
      --SET @cSKU = LEFT( @cInField03, 30)

      SET @cBarcode = SUBSTRING( @cBarcode, 1, 2000)
      SET @cSKU = SUBSTRING( @cBarcode, 1, 30)

      -- Validate blank
      IF @cSKU = ''
      BEGIN
         -- Piece scan and some QTY scanned
         IF @cPieceScan = '1' AND @nPieceScanQTY > 0
         BEGIN
            SET @cSKU = @cPieceScanSKU
            
            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0 -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY_Avail = 0
               SET @nMQTY_Avail = @nQTY_Avail
               SET @nPQTY = 0
               SET @nMQTY = @nQTY
            END
            ELSE
            BEGIN
               SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
               SET @nPQTY = @nQTY / @nPUOM_Div
               SET @nMQTY = @nQTY % @nPUOM_Div
            END
            
            -- Prep next screen var
            SET @cOutField01 = @cFromLOC
            SET @cOutField02 = @cFromID
            SET @cOutField03 = @cSKU
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
            SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
            IF @cPUOM_Desc = ''
            BEGIN
               SET @cOutField06 = '' -- @cPUOM_Desc
               SET @cOutField07 = '' -- @nPQTY_Avail
               SET @cOutField08 = '' -- @nPQTY

               SET @cFieldAttr08 = 'O'
            END
            ELSE
            BEGIN
               SET @cOutField06 = @cPUOM_Desc
               SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
               SET @cOutField08 = CASE WHEN @nPQTY = 0 THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END
            END
            SET @cOutField09 = @cMUOM_Desc
            SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 7))
            SET @cOutField11 = CASE WHEN @cPieceScan = '1' THEN CAST( @nPieceScanQTY AS NVARCHAR( 5))
                                    WHEN @cDefaultQTY <> ''  THEN @cDefaultQTY
                                    WHEN @nMQTY = 0 THEN ''
                                    ELSE CAST( @nMQTY AS NVARCHAR( 7))
                               END
            SET @cOutField12 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

            -- Go to next screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            
            GOTO Step_3_Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 60556
            SET @cErrMsg = rdt.rdtgetmessage( 60556, @cLangCode, 'DSP') --'SKU needed'
            GOTO Step_3_Fail
         END
      END

      --INC0448387
      SET @nQTY = 0

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
               ' @cBarcode     NVARCHAR( 2000), ' +
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
               GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
         SET @cDecodeQty = ''    -- (jamesxxx)
         SET @cAvlQTY = ''       -- (jamesxxx)

         SET @cDecodeLabelNo = ''
         SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)

         IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   --SOS271541
         BEGIN
            EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cSKU
            ,@c_Storerkey  = @cStorerkey
            ,@c_ReceiptKey = @nMobile
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oField01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oField02 OUTPUT   -- STYLE
            ,@c_oFieled03  = @c_oField03 OUTPUT   -- COLOR
            ,@c_oFieled04  = @c_oField04 OUTPUT   -- SIZE
            ,@c_oFieled05  = @c_oField05 OUTPUT   -- QTY
            ,@c_oFieled06  = @c_oField06 OUTPUT   -- CO#
            ,@c_oFieled07  = @c_oField07 OUTPUT
            ,@c_oFieled08  = @c_oField08 OUTPUT
            ,@c_oFieled09  = @c_oField09 OUTPUT
            ,@c_oFieled10  = @c_oField10 OUTPUT
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT   -- AvlQTY

            IF ISNULL(@cErrMsg, '') <> ''
            BEGIN
               SET @cErrMsg = @cErrMsg
               GOTO Step_3_Fail
            END

            SET @cSKU = @c_oField01
            SET @nQTY = @c_oField05
            -- SET @cAvlQTY = @c_oField10

            IF @nMultiStorer = 1
               SET @cSKU_StorerKey = @c_oField09
         END

         IF @nMultiStorer = '1'
            GOTO Skip_ValidateSKU
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
         SET @nErrNo = 60557
         SET @cErrMsg = rdt.rdtgetmessage( 60557, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_3_Fail
      END

      -- (james14)
      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')    --(yeekung03)
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
                  '',    -- DocType
                  ''
            END

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
            SET @nErrNo = 60570
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'
            GOTO Step_3_Fail
         END
      END

      -- Get SKU
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
         @cPrePackIndicator = PrePackIndicator,
         @nPackQtyIndicator = ISNULL( PackQtyIndicator, 0),
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

      -- Get QTY avail
      SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
      FROM dbo.LOTxLOCxID (NOLOCK)
      WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
         AND LOC = @cFromLOC
         AND ID = @cFromID
         AND SKU = @cSKU

      -- Validate not QTY
      IF @nQTY_Avail = 0 OR @nQTY_Avail IS NULL
      BEGIN
         SET @nErrNo = 60558
         SET @cErrMsg = rdt.rdtgetmessage( 60558, @cLangCode, 'DSP') --'No QTY to move'
         GOTO Step_3_Fail
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

      -- Piece scan
      IF @cPieceScan = '1' 
      BEGIN
         -- First time scan
         IF @cPieceScanSKU = '' 
            -- Remember the SKU
            SET @cPieceScanSKU = @cSKU

         -- Check subsequence SKU scan is different from previous
         ELSE IF @cPieceScanSKU <> @cSKU
         BEGIN
            SET @nErrNo = 60571
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Different SKU
            GOTO Step_3_Fail
         END

         -- Increase scan count
         SET @nPieceScanQTY += 1
         
         -- Not fully scan
         IF @nPieceScanQTY < @nQTY_Avail
         BEGIN            
            SET @cBarcode = ''
            
            -- Stay at same screen
            SET @cOutField01 = @cFromLOC
            SET @cOutField02 = @cFromID
            SET @cOutField03 = '' --@cSKU
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
            SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
            SET @cOutField06 = CAST( @nPieceScanQTY AS NVARCHAR( 5)) + '/' + CAST( @nQTY_Avail AS NVARCHAR( 5))

            GOTO Quit
         END
      END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Avail = 0
         SET @nMQTY_Avail = @nQTY_Avail
         SET @nPQTY = 0
         SET @nMQTY = @nQTY
      END
      ELSE
      BEGIN
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY = @nQTY / @nPUOM_Div
         SET @nMQTY = @nQTY % @nPUOM_Div
      END

      EXEC RDT.rdt_STD_EventLog
       @cActionType = '3',
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @cLocation   = @cFromLOC,
       @cID         = @cFromID,
       @cSKU        = @cSKU,
       @nStep       = @nStep

      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cOutField08 = '' -- @nPQTY

         SET @cFieldAttr08 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
         SET @cOutField08 = CASE WHEN @nPQTY = 0 THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 7))
      SET @cOutField11 = CASE WHEN @cPieceScan = '1' THEN CAST( @nPieceScanQTY AS NVARCHAR( 5))
                              WHEN @cDefaultQTY <> ''  THEN @cDefaultQTY
                              WHEN @nMQTY = 0 THEN ''
                              ELSE CAST( @nMQTY AS NVARCHAR( 7))
                         END
      SET @cOutField12 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

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

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      -- (james13)
      -- if loc.loseid = 1 and config turn on then flow thru id screen
      IF @cFromLocLoseID = '1' AND @cSkipIDScnIFLocLoseID = '1'
         GOTO Step_2
   END

   Step_3_Quit:
   BEGIN
      -- Extended info
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
               @nMobile, @nFunc, @cLangCode, 3, @nInputKey, @cStorerKey, @cFacility, @tExtInfo, @cExtendedInfo OUTPUT

            SET @cOutField15 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
         END
      END
      
      -- (james19)
      IF @nFlowThruQtyScn = 1
      BEGIN
         SET @cInField11 = @cOutField11
         GOTO Step_4
      END   
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cSKU = ''
      SET @cOutField03 = '' -- SKU
      SET @cBarcode = ''
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 1033. QTY screen
   FromLOC (field01)
   FromID  (field02)
   SKU     (field03)
   Desc1   (field04)
   Desc2   (field05)
   UOM     (field06, field09)
   QTY AVL (field07, field10)
   QTY MV  (field08, field11, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cPQTY NVARCHAR( 7)
      DECLARE @cMQTY NVARCHAR( 7)

      -- Screen mapping
      SET @cPQTY = @cInField08
      SET @cMQTY = @cInField11

      -- Retain the key-in value
      SET @cOutField08 = @cInField08 -- Pref QTY
      SET @cOutField11 = @cInField11 -- Master QTY

      -- Validate PQTY
      IF ISNULL(@cPQTY, '') = '' SET @cPQTY = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 60559
         SET @cErrMsg = rdt.rdtgetmessage( 60559, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY
         GOTO Step_4_Fail
      END

      -- Validate MQTY
      IF ISNULL(@cMQTY, '')  = '' SET @cMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 60560
         SET @cErrMsg = rdt.rdtgetmessage( 60560, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- MQTY
         GOTO Step_4_Fail
      END

      -- Calc total QTY in master UOM
      SET @nPQTY = CAST( @cPQTY AS INT)
      SET @nMQTY = CAST( @cMQTY AS INT)

      IF @nMultiStorer = 0
         SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      ELSE
         SET @nQTY = rdt.rdtConvUOMQTY( @cSKU_StorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM

      SET @nQTY = @nQTY + @nMQTY

      -- Calc prepack QTY
      IF @cPrePackIndicator = '2'
         IF @nPackQtyIndicator > 1 AND @cSkipChkPPKQTY <> '1'
            SET @nQTY = @nQTY * @nPackQtyIndicator

      -- if need convert qty (james03)
      IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') NOT IN ('','0')   --SOS271541
      BEGIN
         EXEC ispInditexConvertQTY 'ToBaseQTY', @cStorerkey, @cSKU, @nQTY OUTPUT
      END

      -- Validate QTY
      IF @nQTY = 0
      BEGIN
         SET @nErrNo = 60561
         SET @cErrMsg = rdt.rdtgetmessage( 60561, @cLangCode, 'DSP') --'QTY needed'
         GOTO Step_4_Fail
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY > @nQTY_Avail
      BEGIN
         SET @nErrNo = 60562
         SET @cErrMsg = rdt.rdtgetmessage( 60562, @cLangCode, 'DSP') --'QTYAVL NotEnuf'
         GOTO Step_4_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> '' --(yeekung03)
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
               GOTO Step_4_Fail
         END
      END

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

      -- Serial No
      IF @cSerialNoCapture = '1'
      BEGIN
         -- Clear log
         EXEC rdt.rdt_Move_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLEARLOG'
            ,@cSKU
            ,'' -- @cSerialNo
            ,0  -- @nSerialQTY
            ,'' -- @cToLOC
            ,'' -- @cToID
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDescr, @nQTY, 'CHECK', 'MOVE', '',
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
 @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMoreSNO = 1
         BEGIN
            EXEC RDT.rdt_STD_EventLog
                @cActionType = '3',
                @cUserID     = @cUserName,
                @nMobileNo   = @nMobile,
                @nFunctionID = @nFunc,
                @cFacility   = @cFacility,
                @cStorerKey  = @cStorerkey,
                @cLocation   = @cFromLOC,
                @cID         = @cFromID,
                @cSKU        = @cSKU,
                @cUOM        = @cPUOM_Desc,
                @nQty        = @nQty,
                @nStep       = @nStep

            -- Go to Serial No screen
            SET @nScn = 4830
            SET @nStep = @nStep + 5

            GOTO Quit
         END
      END

      -- Ssuggest ID
      IF @cSuggestIDSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestIDSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestIDSP) +
               ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @cType, @nPABookingKey OUTPUT, ' +
               ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
               ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, ' +
               ' @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile         INT,                  ' +
               ' @nFunc           INT,                  ' +
               ' @cLangCode       NVARCHAR( 3),         ' +
               ' @cStorerKey      NVARCHAR( 15),        ' +
               ' @cFacility       NVARCHAR(  5),        ' +
               ' @cFromLOC        NVARCHAR( 10),        ' +
               ' @cFromID         NVARCHAR( 18),        ' +
               ' @cSKU            NVARCHAR( 20),        ' +
               ' @nQTY            INT,                  ' +
               ' @cToID           NVARCHAR( 18),        ' +
               ' @cToLOC          NVARCHAR( 10),        ' +
               ' @cType           NVARCHAR( 10),        ' +
               ' @nPABookingKey   INT           OUTPUT, ' +
               ' @cOutField01     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField02     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField03     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField04     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField05     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField06     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField07     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField08     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField09     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField10     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField11     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField12     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField13     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField14     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField15     NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo          INT           OUTPUT, ' +
               ' @cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, 'LOCK', @nPABookingKey OUTPUT,
               @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT,
               @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT,
               @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0 AND
               @nErrNo <> -1
               GOTO QUIT

            IF @nErrNo <> -1
            BEGIN
               EXEC RDT.rdt_STD_EventLog
                   @cActionType = '3',
                   @cUserID     = @cUserName,
                   @nMobileNo   = @nMobile,
                   @nFunctionID = @nFunc,
                   @cFacility   = @cFacility,
                   @cStorerKey  = @cStorerkey,
                   @cLocation   = @cFromLOC,
                   @cID         = @cFromID,
                   @cSKU        = @cSKU,
                   @cUOM        = @cPUOM_Desc,
                   @nQty        = @nQty,
                   @nStep       = @nStep

               SET @nFromStep = @nStep

               -- Go to suggest ID/LOC Screen
               SET @nScn = @nScn + 4
               SET @nStep = @nStep + 4

               GOTO Quit
            END
         END
      END

      EXEC RDT.rdt_STD_EventLog
           @cActionType = '3',
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerkey,
           @cLocation   = @cFromLOC,
           @cID         = @cFromID,
           @cSKU        = @cSKU,
           @cUOM        = @cPUOM_Desc,
           @nQty        = @nQty,
           @nStep       = @nStep

      -- Prep ToID screen var
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
         SET @cOutField08 = '' -- @nPQTY
         SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007

         SET @cFieldAttr08 = 'O' -- (Vicky02)
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
         SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 7))
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 7))
      SET @cOutField12 = CASE WHEN @cDefaultToID = '1' THEN @cFromID ELSE '' END -- @cToID
      SET @cOutField13 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

      -- Go to ToID screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- (james13)
      -- if loc.loseid = 1 and config turn on then flow thru id screen
      IF (@cFromLocLoseID = '1' AND @cSkipIDScnIFLocLoseID = '1') OR @nFlowThruToIDScn = 1
         GOTO Step_5
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep SKU screen var
      SET @cPieceScanSKU = ''
      SET @nPieceScanQTY = 0
      SET @cBarcode = ''
      SET @cSKU = ''
      
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' -- @cSKU
      SET @cOutField04 = '' -- @cSKUDescr
      SET @cOutField05 = '' -- @cSKUDescr
      SET @cOutField06 = '' -- QTY

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

      -- Reset (james10)
      SET @nQTY = 0

      -- Go to QTY screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   GOTO Quit

   Step_4_Fail:
   BEGIN
    -- (Vicky02) - Start
      SET @cFieldAttr08 = ''
      -- (Vicky02) - End

      IF @cPUOM_Desc = ''
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition
         -- Disable pref QTY field
         SET @cFieldAttr08 = 'O' -- (Vicky02)


      SET @cOutField08 = '' -- ActPQTY
      SET @cOutField11 = '' -- ActMQTY
   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 1034. ToID
   FromID  (field01)
   FromLOC (field02)
   SKU     (field03)
   Desc1   (field04)
   Desc2   (field05)
   UOM     (field06, field09)
   QTY MV  (field08, field11)
   ToID    (field12, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField12
      SET @cBarcode = @cInField12

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TOID', @cBarcode) = 0
      BEGIN
         SET @nErrNo = 60569
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_5_Fail
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

      -- Ssuggest loc
      IF @cSuggestLocSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestLocSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestLocSP) +
               ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @cType, @nPABookingKey OUTPUT, ' +
               ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
               ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, ' +
               ' @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile         INT,                  ' +
               ' @nFunc           INT,                  ' +
               ' @cLangCode       NVARCHAR( 3),         ' +
               ' @cStorerKey      NVARCHAR( 15),        ' +
               ' @cFacility       NVARCHAR(  5),        ' +
               ' @cFromLOC        NVARCHAR( 10),        ' +
               ' @cFromID         NVARCHAR( 18),        ' +
               ' @cSKU            NVARCHAR( 20),        ' +
               ' @nQTY            INT,                  ' +
               ' @cToID           NVARCHAR( 18),        ' +
               ' @cToLOC          NVARCHAR( 10),        ' +
               ' @cType           NVARCHAR( 10),        ' +
               ' @nPABookingKey   INT           OUTPUT, ' +
               ' @cOutField01     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField02     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField03     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField04     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField05     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField06     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField07     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField08     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField09     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField10     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField11     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField12     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField13     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField14     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField15     NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo          INT           OUTPUT, ' +
               ' @cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, 'LOCK', @nPABookingKey OUTPUT,
               @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT,
               @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT,
               @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0 AND
               @nErrNo <> -1
               GOTO QUIT

            IF @nErrNo <> -1
            BEGIN
               EXEC RDT.rdt_STD_EventLog
                @cActionType = '3',
                @cUserID     = @cUserName,
                @nMobileNo   = @nMobile,
                @nFunctionID = @nFunc,
                @cFacility   = @cFacility,
                @cStorerKey  = @cStorerkey,
                @cLocation   = @cFromLOC,
                @cID         = @cFromID,
                @cSKU        = @cSKU,
                @cUOM        = @cPUOM_Desc,
                @nQty        = @nQty,
                @cToID       = @cToID,
                @nStep       = @nStep

               SET @nFromStep = @nStep

               -- Go to Suggest ID/LOC Screen
               SET @nScn = @nScn + 3
               SET @nStep = @nStep + 3

               GOTO Quit
            END
         END
      END

      EXEC RDT.rdt_STD_EventLog
           @cActionType = '3',
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerkey,
           @cLocation   = @cFromLOC,
           @cID         = @cFromID,
           @cSKU        = @cSKU,
           @cUOM        = @cPUOM_Desc,
           @nQty        = @nQty,
           @cToID       = @cToID,
           @nStep       = @nStep

      -- Prep ToLOC screen var
      SET @cToLOC = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cOutField08 = '' -- @nPQTY_Total
         SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007

         SET @cFieldAttr08 = 'O' -- (Vicky02)
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
         SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 7))
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 7))
      SET @cOutField12 = @cToID
      SET @cOutField13 = '' -- @cToLOC
      SET @cOutField14 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF @nFlowThruQtyScn = 0
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

         -- Clear log
         EXEC rdt.rdt_Move_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLEARLOG'
            ,@cSKU
            ,'' -- @cSerialNo
            ,0  -- @nSerialQTY
            ,'' -- @cToLOC
            ,'' -- @cToID
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Get QTY avail
         SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
         FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
            AND LOC = @cFromLOC
            AND ID = @cFromID
            AND SKU = @cSKU

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
         END

         -- Prep QTY screen var
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = @cFromID
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField06 = '' -- @cPUOM_Desc
            SET @cOutField07 = '' -- @nPUOM_Avail
            SET @cOutField08 = '' -- @nPQTY

            SET @cFieldAttr08 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField06 = @cPUOM_Desc
            SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
            SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 7))
         END
         SET @cOutField09 = @cMUOM_Desc
         SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 7))
         SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 7))
         SET @cOutField12 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

         -- (james15)
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

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtInfo, @cExtendedInfo OUTPUT '
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cFacility       NVARCHAR(  5), ' +
                  '@tExtInfo        VariableTable READONLY, ' +
                  '@cExtendedInfo   NVARCHAR( 20)  OUTPUT '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtInfo, @cExtendedInfo OUTPUT

               SET @cOutField15 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
            END
         END

         -- Go to QTY screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         -- Prep SKU screen var
         SET @cSKU = ''
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = @cFromID
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

         -- Reset (james10)
         SET @nQTY = 0

         -- Go to QTY screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cToID = ''
      SET @cOutField12 = '' -- @cToID
   END
END
GOTO Quit


/********************************************************************************
Step 6. Scn = 1037. ToLOC
   FromID  (field01)
   FromLOC (field02)
   SKU     (field03)
   Desc1   (field04)
   Desc2   (field05)
   UOM     (field06, field09)
   QTY MV  (field08, field11)
   ToID    (field12)
   ToLOC   (field13, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField13
      SET @cLocNeedCheck = @cInField13
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

      -- Validate blank
      IF @cToLOC = '' OR @cToLOC IS NULL
      BEGIN
         SET @nErrNo = 60563
         SET @cErrMsg = rdt.rdtgetmessage( 60563, @cLangCode, 'DSP') --'ToLOC needed'
         GOTO Step_6_Fail
      END

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '513ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_513ExtScnEntry] 
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
               GOTO Step_6_Fail
            
            SET @cToLOC = @cLocNeedCheck
         END
      END
      
      -- add loc prefix (yeekung01)
      IF @cLOCLookupSP = 1
      BEGIN
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cToLOC     OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Step_6_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 60564
         SET @cErrMsg = rdt.rdtgetmessage( 60564, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_6_Fail
      END

      -- Validate LOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 60565
            SET @cErrMsg = rdt.rdtgetmessage( 60565, @cLangCode, 'DSP') --'Diff facility'
            GOTO Step_6_Fail
         END

      -- Validate FromLOC same as ToLOC
      IF @cFromLOC = @cToLOC
      BEGIN
         IF rdt.rdtGetConfig(@nFunc, 'MoveNotCheckSameFromToLoc', @cStorerKey) = '1' -- (james06)
         BEGIN
            -- If not check same from to loc then must check whether same from to id
            IF ISNULL(@cFromID, '') = ISNULL(@cToID, '')
            BEGIN
               SET @nErrNo = 60567
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Same FromToID'
               GOTO Step_6_Fail
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 60566
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Same FromToLOC'
            GOTO Step_6_Fail
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

      -- Custom move
      IF @cConfirmSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
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
               GOTO Step_6_Fail
         END
      END
      ELSE
      BEGIN
         IF @nMultiStorer = 0
         BEGIN
            EXECUTE rdt.rdt_Move
               @nMobile      = @nMobile,
               @cLangCode    = @cLangCode,
               @nErrNo       = @nErrNo  OUTPUT,
               @cErrMsg      = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType  = 'rdtfnc_Move_SKU',
               @cStorerKey   = @cStorerKey,
               @cFacility    = @cFacility,
               @cFromLOC     = @cFromLOC,
               @cToLOC       = @cToLOC,
               @cFromID      = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID        = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
               @cSKU         = @cSKU,
               @nQTY         = @nQTY,
               @nFunc        = @nFunc

            --INC0897289
            IF @nErrNo <> 0
               GOTO Step_6_Fail
         END
         ELSE
         BEGIN
            -- For multi storer move by sku, only able to move sku from loc contain
            -- only 1 sku 1 storer because if 1 sku multi storer then move by sku
            -- don't know which storer's sku to move
            -- If contain SKU A (Storer 1), SKU A (Storer 2) then will be blocked @ decode label sp
            EXECUTE rdt.rdt_Move
               @nMobile      = @nMobile,
               @cLangCode    = @cLangCode,
               @nErrNo       = @nErrNo  OUTPUT,
               @cErrMsg      = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType  = 'rdtfnc_Move_SKU',
               @cStorerKey   = @cSKU_StorerKey,
               @cFacility    = @cFacility,
               @cFromLOC     = @cFromLOC,
               @cToLOC       = @cToLOC,
               @cFromID      = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID        = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
               @cSKU         = @cSKU,
               @nQTY         = @nQTY,
               @nFunc        = @nFunc

            --INC0897289
            IF @nErrNo <> 0
               GOTO Step_6_Fail
         END

         -- Move serial no
         IF @cSerialNoCapture = '1'
         BEGIN
            EXEC rdt.rdt_Move_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'MOVE'
               ,@cSKU
               ,'' -- @cSerialNo
               ,0  -- @nSerialQTY
               ,@cToLOC
               ,@cToID
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            -- Clear log
            EXEC rdt.rdt_Move_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLEARLOG'
               ,@cSKU
               ,'' -- @cSerialNo
               ,0  -- @nSerialQTY
               ,'' -- @cToLOC
               ,'' -- @cToID
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
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
               '@nErrNo          INT OUTPUT,  ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Unlock suggest loc
      IF @cSuggestLocSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestLocSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestLocSP) +
               ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @cType, @nPABookingKey OUTPUT, ' +
               ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
               ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, ' +
               ' @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile         INT,                  ' +
               ' @nFunc           INT,                  ' +
               ' @cLangCode       NVARCHAR( 3),         ' +
               ' @cStorerKey      NVARCHAR( 15),        ' +
               ' @cFacility       NVARCHAR(  5),        ' +
               ' @cFromLOC        NVARCHAR( 10),        ' +
               ' @cFromID         NVARCHAR( 18),        ' +
               ' @cSKU            NVARCHAR( 20),        ' +
               ' @nQTY            INT,                  ' +
               ' @cToID           NVARCHAR( 18),        ' +
               ' @cToLOC          NVARCHAR( 10),        ' +
               ' @cType           NVARCHAR( 10),        ' +
               ' @nPABookingKey   INT           OUTPUT, ' +
               ' @cOutField01     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField02     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField03     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField04     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField05     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField06     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField07     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField08     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField09     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField10     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField11     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField12     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField13     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField14     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField15     NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo          INT           OUTPUT, ' +
               ' @cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, 'UNLOCK', @nPABookingKey OUTPUT,
               @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT,
               @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT,
               @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO QUIT
         END

         EXEC RDT.rdt_STD_EventLog
                @cActionType = '3',
                @cUserID     = @cUserName,
                @nMobileNo   = @nMobile,
                @nFunctionID = @nFunc,
                @cFacility   = @cFacility,
                @cStorerKey  = @cStorerkey,
                @cLocation   = @cFromLOC,
                @cID         = @cFromID,
                @cSKU        = @cSKU,
                @cUOM        = @cPUOM_Desc,
                @nQty        = @nQty,
                @cToID       = @cToID,
                @cToLocation = @cToLOC,
                @nStep       = @nStep

         -- Prepare next screen var
         SET @cOutField01 = @cToLOC

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
           @cActionType = '3',
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerkey,
           @cLocation   = @cFromLOC,
           @cID         = @cFromID,
           @cSKU        = @cSKU,
           @cUOM        = @cPUOM_Desc,
           @nQty        = @nQty,
           @cToID       = @cToID,
           @cToLocation = @cToLOC,
           @nStep       = @nStep

      -- Prepare next screen var
      SET @cOutField01 = @cToLOC

      -- Go to message screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF @nFlowThruToIDScn = 0
      BEGIN
         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
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

         -- Unlock suggest loc
         IF @cSuggestLocSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestLocSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestLocSP) +
                  ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @cType, @nPABookingKey OUTPUT, ' +
                  ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
                  ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, ' +
                  ' @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT, ' +
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
               SET @cSQLParam =
                  ' @nMobile         INT,                  ' +
                  ' @nFunc           INT,                  ' +
                  ' @cLangCode       NVARCHAR( 3),         ' +
                  ' @cStorerKey      NVARCHAR( 15),        ' +
                  ' @cFacility       NVARCHAR(  5),        ' +
                  ' @cFromLOC        NVARCHAR( 10),        ' +
                  ' @cFromID         NVARCHAR( 18),        ' +
                  ' @cSKU            NVARCHAR( 20),        ' +
                  ' @nQTY            INT,                  ' +
                  ' @cToID           NVARCHAR( 18),        ' +
                  ' @cToLOC          NVARCHAR( 10),        ' +
                  ' @cType           NVARCHAR( 10),        ' +
                  ' @nPABookingKey   INT           OUTPUT, ' +
                  ' @cOutField01     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField02     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField03     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField04     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField05     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField06     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField07     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField08     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField09     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField10     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField11     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField12     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField13     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField14     NVARCHAR( 20) OUTPUT, ' +
                  ' @cOutField15     NVARCHAR( 20) OUTPUT, ' +
                  ' @nErrNo          INT           OUTPUT, ' +
                  ' @cErrMsg         NVARCHAR( 20) OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, 'UNLOCK', @nPABookingKey OUTPUT,
                  @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT,
                  @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT,
                  @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT,
                  @nErrNo      OUTPUT, @cErrMsg     OUTPUT

               IF @nErrNo <> 0
                  GOTO QUIT
            END
         END

         -- Prepare ToID screen var
         SET @cToID = ''
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = @cFromID
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescR, 1, 20)   -- SKU desc 1
         SET @cOutField05 = SUBSTRING( @cSKUDescR, 21, 20)  -- SKU desc 2
         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField06 = '' -- @cPUOM_Desc
            SET @cOutField07 = '' -- @nPQTY_Avail
            SET @cOutField08 = '' -- @nPQTY
            SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
         END
         ELSE
         BEGIN
            SET @cOutField06 = @cPUOM_Desc
           SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
            SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 7))
         END
         SET @cOutField09 = @cMUOM_Desc
         SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 7))
         SET @cOutField12 = '' -- @cToID
         SET @cOutField13 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

         -- Go to ToID screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         IF @nFlowThruQtyScn = 0
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

            -- Clear log
            EXEC rdt.rdt_Move_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLEARLOG'
               ,@cSKU
               ,'' -- @cSerialNo
               ,0  -- @nSerialQTY
               ,'' -- @cToLOC
               ,'' -- @cToID
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            -- Get QTY avail
            SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
            FROM dbo.LOTxLOCxID (NOLOCK)
            WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
               AND LOC = @cFromLOC
               AND ID = @cFromID
               AND SKU = @cSKU

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
            END

            -- Prep QTY screen var
            SET @cOutField01 = @cFromLOC
            SET @cOutField02 = @cFromID
            SET @cOutField03 = @cSKU
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
            SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
            IF @cPUOM_Desc = ''
            BEGIN
               SET @cOutField06 = '' -- @cPUOM_Desc
               SET @cOutField07 = '' -- @nPUOM_Avail
               SET @cOutField08 = '' -- @nPQTY

               SET @cFieldAttr08 = 'O'
            END
            ELSE
            BEGIN
               SET @cOutField06 = @cPUOM_Desc
               SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
               SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 7))
            END
            SET @cOutField09 = @cMUOM_Desc
            SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 7))
            SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 7))
            SET @cOutField12 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

            -- (james15)
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

                  SET @cOutField15 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
               END
            END

            -- Go to QTY screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
         END
         ELSE
         BEGIN
            -- Prep SKU screen var
            SET @cSKU = ''
            SET @cOutField01 = @cFromLOC
            SET @cOutField02 = @cFromID
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

            -- Reset (james10)
            SET @nQTY = 0

            -- Go to QTY screen
            SET @nScn = @nScn - 3
            SET @nStep = @nStep - 3
         END
      END
   END

   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField13 = '' -- @cToLOC
   END
END
GOTO Quit


/********************************************************************************
Step 7. scn = 1038. Message screen
   Message
********************************************************************************/
Step_7:
BEGIN
   EXEC RDT.rdt_STD_EventLog
        @cActionType = '3',
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cLocation   = @cFromLOC,
        @cID         = @cFromID,
        @cSKU        = @cSKU,
        @cUOM        = @cPUOM_Desc,
        @nQty        = @nQty,
        @cToID       = @cToID,
        @cToLocation = @cToLOC,
        @nStep       = @nStep

   IF @cGoBackFromLocScn = '0'
   BEGIN
      --(cc01)
      DECLARE @cFrLOCCat      NVARCHAR(10)
      SELECT @cFrLOCCat = locationcategory FROM Loc WITH (NOLOCK) WHERE LOC = @cFromLOC
      
      -- Go to SKU
      IF @cGoBackSKUScn = '1' -- Go to SKU without check is it same sku (cc01)
      BEGIN
         SET @nQTY_Avail = 0
         SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
         FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
            AND LOC = @cFromLOC
            AND ID = @cFromID
         IF @nQTY_Avail > 0
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cFromLOC
            SET @cOutField02 = @cFromID
            SET @cOutField03 = '' --@cSKU

            SET @cBarcode = ''
            SET @cPieceScanSKU = ''
            SET @nPieceScanQTY = 0

            IF @cFrLOCCat = 'staging'
            BEGIN
             -- Go back to SKU screen
               SET @nScn  = @nScn - 4
               SET @nStep = @nStep - 4
            END
            ELSE
            BEGIN
             -- Go back to FromLoc screen
               SET @nScn  = @nScn - 6
               SET @nStep = @nStep - 6

                -- Prep next screen var
               SET @cFromLOC = ''
               SET @cDefaultLOC = ''
               -- (james03)
               SET @cDefaultLOC = ISNULL(rdt.RDTGetConfig( @nFunc, 'DefaultFromLoc', @cStorerKey), '')
               IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                              WHERE Facility = @cFacility
                              AND   LOC = @cDefaultLOC)
                  SET @cOutField01 = '' -- FromLOC
               ELSE
                  -- Prep next screen var
                  SET @cOutField01 = @cDefaultLOC -- FromLOC
            END

            GOTO Quit
         END
      END

      -- Go to SKU
      SET @nQTY_Avail = 0
      SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
      FROM dbo.LOTxLOCxID (NOLOCK)
      WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
         AND LOC = @cFromLOC
         AND ID = @cFromID
         AND SKU <> @cSKU
      IF @nQTY_Avail > 0
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = @cFromID
         SET @cOutField03 = '' --@cSKU

         SET @cBarcode = ''
         SET @cPieceScanSKU = ''
         SET @nPieceScanQTY = 0

         -- Go back to SKU screen
         SET @nScn  = @nScn - 4
         SET @nStep = @nStep - 4
         GOTO Quit
      END

      -- Go to FromID screen
      SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
      FROM dbo.LOTxLOCxID (NOLOCK)
      WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
         AND LOC = @cFromLOC
         AND ID <> @cFromID
      IF @nQTY_Avail > 0
      BEGIN
         -- Prep next screen var
         SET @cFromID = ''
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = '' --@cFromID

         -- Go back to FromID screen
         SET @nScn  = @nScn - 5
         SET @nStep = @nStep - 5
         GOTO Quit
      END
   END

   -- Go back to FromLOC screen
   SET @nScn  = @nScn - 6
   SET @nStep = @nStep - 6

   -- Prep next screen var
   SET @cFromLOC = ''
   SET @cDefaultLOC = ''
   -- (james03)
   SET @cDefaultLOC = ISNULL(rdt.RDTGetConfig( @nFunc, 'DefaultFromLoc', @cStorerKey), '')
   IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                  WHERE Facility = @cFacility
                  AND   LOC = @cDefaultLOC)
      SET @cOutField01 = '' -- FromLOC
   ELSE
      -- Prep next screen var
      SET @cOutField01 = @cDefaultLOC -- FromLOC

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

/********************************************************************************
Step 8. scn = 1037. Suggested LOC screen
   Suggested LOC
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- Enter
   BEGIN
      -- Prep ToLOC screen var
      SET @cToLOC = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 7))  --xiaolun01
      
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cOutField08 = '' -- @nPQTY_Total
         SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007

         SET @cFieldAttr08 = 'O' -- (Vicky02)
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
         SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 7))
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 7))

      EXEC RDT.rdt_STD_EventLog
           @cActionType = '3',
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerkey,
           @cLocation   = @cFromLOC,
           @cID         = @cFromID,
           @cSKU        = @cSKU,
           @cUOM        = @cPUOM_Desc,
           @nQty        = @nQty,
           @cToID       = @cToID,
           @cToLocation = @cToLOC,
           @nStep       = @nStep

      -- From QTY screen
      IF @nFromStep = 4
      BEGIN
         SET @cOutField12 = '' -- @cToID
         SET @cOutField13 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

         -- Go back to ToID screen
         SET @nScn  = @nScn - 3
         SET @nStep = @nStep - 3
      END

      -- From ToID screen
      IF @nFromStep = 5
      BEGIN
         SET @cOutField12 = @cToID
         SET @cOutField13 = CASE WHEN @cDefaultSuggToLoc = '1' AND ISNULL( @cOutField01, '') <> '' THEN @cOutField01 ELSE '' END -- @cToLOC
         SET @cOutField14 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

         -- Go back to ToLOC screen
         SET @nScn  = @nScn - 2
         SET @nStep = @nStep - 2
      END
   END
END
GOTO Quit


/********************************************************************************
Step 9. Screen = 4830. Serial No
   SKU            (Field01)
   SKUDesc1       (Field02)
   SKUDesc2       (Field03)
   SerialNo       (Field04, input)
   Scan           (Field05)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Update SKU setting
      EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDescr, @nQTY, 'UPDATE', 'MOVE', '',
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
         @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
         @nErrNo     OUTPUT,  @cErrMsg     OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Insert log
      EXEC rdt.rdt_Move_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'INSERTLOG'
         ,@cSKU
         ,@cSerialNo
         ,@nSerialQTY
         ,'' -- @cToLOC
         ,'' -- @cToID
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      IF @nMoreSNO = 1
         GOTO Quit

      -- Ssuggest ID
      IF @cSuggestIDSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestIDSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestIDSP) +
               ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @cType, @nPABookingKey OUTPUT, ' +
               ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
               ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, ' +
               ' @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile         INT,                  ' +
               ' @nFunc           INT,                  ' +
               ' @cLangCode       NVARCHAR( 3),         ' +
               ' @cStorerKey      NVARCHAR( 15),        ' +
               ' @cFacility       NVARCHAR(  5),        ' +
               ' @cFromLOC        NVARCHAR( 10),        ' +
               ' @cFromID         NVARCHAR( 18),        ' +
               ' @cSKU            NVARCHAR( 20),        ' +
               ' @nQTY            INT,                  ' +
               ' @cToID           NVARCHAR( 18),        ' +
               ' @cToLOC          NVARCHAR( 10),        ' +
               ' @cType           NVARCHAR( 10),        ' +
               ' @nPABookingKey   INT           OUTPUT, ' +
               ' @cOutField01     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField02     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField03     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField04     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField05     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField06     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField07     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField08     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField09     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField10     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField11     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField12     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField13     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField14     NVARCHAR( 20) OUTPUT, ' +
               ' @cOutField15     NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo          INT           OUTPUT, ' +
               ' @cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, 'LOCK', @nPABookingKey OUTPUT,
               @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT,
               @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT,
               @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0 AND
               @nErrNo <> -1
               GOTO QUIT

            IF @nErrNo <> -1
            BEGIN
               EXEC RDT.rdt_STD_EventLog
                @cActionType = '3',
                @cUserID     = @cUserName,
                @nMobileNo   = @nMobile,
                @nFunctionID = @nFunc,
                @cFacility   = @cFacility,
                @cStorerKey  = @cStorerkey,
                @cLocation   = @cFromLOC,
                @cID         = @cFromID,
                @cSKU        = @cSKU,
                @cUOM        = @cPUOM_Desc,
                @nQty        = @nQty,
                @cToID       = @cToID,
                @cToLocation = @cToLOC,
                @cSerialNo   = @cSerialNo,
                @nStep       = @nStep

               SET @nFromStep = 4

               -- Go to suggest ID/LOC Screen
               SET @nScn = 1037
               SET @nStep = @nStep - 1

               GOTO Quit
            END
         END
      END

      EXEC RDT.rdt_STD_EventLog
           @cActionType = '3',
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerkey,
           @cLocation   = @cFromLOC,
           @cID         = @cFromID,
           @cSKU        = @cSKU,
           @cUOM        = @cPUOM_Desc,
           @nQty        = @nQty,
           @cToID       = @cToID,
           @cToLocation = @cToLOC,
           @cSerialNo   = @cSerialNo,
           @nStep       = @nStep

      -- Prep ToID screen var
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
         SET @cOutField08 = '' -- @nPQTY
         SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007

         SET @cFieldAttr08 = 'O' -- (Vicky02)
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
         SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 7))
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 7))
      SET @cOutField12 = CASE WHEN @cDefaultToID = '1' THEN @cFromID ELSE '' END -- @cToID
      SET @cOutField13 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

      -- Go to ToID screen
      SET @nScn = 1034
      SET @nStep = @nStep - 4
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Clear log
      EXEC rdt.rdt_Move_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLEARLOG'
         ,@cSKU
         ,'' -- @cSerialNo
         ,0  -- @nSerialQTY
         ,'' -- @cToLOC
         ,'' -- @cToID
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Get QTY avail
      SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
      FROM dbo.LOTxLOCxID (NOLOCK)
      WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
         AND LOC = @cFromLOC
         AND ID = @cFromID
         AND SKU = @cSKU

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
      END

      -- Prep QTY screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPUOM_Avail
         SET @cOutField08 = '' -- @nPQTY

         SET @cFieldAttr08 = 'O'
      END
      ELSE
BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
         SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 7))
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 7))
      SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 7))
      SET @cOutField12 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

      -- Go to QTY screen
      SET @nScn = 1033
      SET @nStep = @nStep - 5
   END
END
GOTO Quit

/********************************************************************************
Step 10. Screen = 3570. Multi SKU
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
Step_10:
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
         @cErrMsg  OUTPUT,
         '',    -- DocType
         ''

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
      SET @cBarcode = ''

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
      --UserName  = @cUserName,-- (Vicky06)
      V_LOC     = @cFromLOC, -- (james02)
      V_ID      = @cFromID,  -- (james02)

      V_SKUDescr = @cSKUDescr,
      V_UOM      = @cPUOM,
      V_PQTY     = @nPQTY,
      V_MQTY     = @nMQTY,
      V_PUOM_Div = @nPUOM_Div,
      V_FromStep = @nFromStep,
      V_FromScn  = @nFromScn,
      V_Barcode  = @cBarcode,

      V_String1  = @cFromLOC,
      V_String2  = @cFromID,
      V_String3  = @cSKU,
      V_String4  = @cPUOM_Desc,
      V_String5  = @cMUOM_Desc,
      V_String6  = @cSkipIDScnIFLocLoseID,
      V_String7  = @cFromLocLoseID,
      V_String8  = @cMultiSKUBarcode,
      V_String9  = @cExtendedInfoSP,
      V_String10 = @cExtendedInfo,

      V_String13 = @cToLOC,
      V_String14 = @cToID,
      V_String15 = @cPieceScanSKU,
      V_String16 = @cSKU_StorerKey, -- (james05)
      V_String17 = @cExtendedUpdateSP,
      V_String18 = @cSuggestLocSP,
      V_String19 = @cExtendedValidateSP,
      V_String20 = @cGoBackFromLocScn,
      V_String21 = @cLabelNo, -- (ChewKP02)
      V_String22 = @cPieceScan,
      V_String24 = @cSuggestIDSP,
      V_String25 = @cDecodeSP,
      V_String26 = @cDefaultToID,
      V_String27 = @cSerialNoCapture,
      V_String28 = @cConfirmSP,
      V_String29 = @cDefaultQTY,
      V_String30 = @cGoBackSKUScn, --(cc01)
      V_String41 = @cPrePackIndicator,
      V_String42 = @cLOCLookupSP,   --(yeekung01)
      V_String43 = @cDefaultSuggToLoc,
      V_String44 = @cSkipChkPPKQTY,

      V_Integer1 = @nQTY_Avail,
      V_Integer2 = @nPQTY_Avail,
      V_Integer3 = @nMQTY_Avail,
      V_Integer4 = @nQTY,
      V_Integer5 = @nMultiStorer,   -- (james05)
      V_Integer6 = @nPABookingKey,
      V_Integer7 = @nPackQtyIndicator,
      V_Integer8 = @nFlowThruToIDScn,
      V_Integer9 = @nFlowThruQtyScn, --(james19)
      V_Integer10 = @nPieceScanQTY,

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
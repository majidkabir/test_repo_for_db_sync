SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/********************************************************************************************/
/* Store procedure: rdtfnc_PutawayBySKU                                                     */
/* Copyright      : IDS                                                                     */
/*                                                                                          */
/* Purpose: Putaway by SKU                                                                  */
/*                                                                                          */
/* Called from: 3                                                                           */
/*    1. From PowerBuilder                                                                  */
/*    2. From scheduler                                                                     */
/*    3. From others stored procedures or triggers                                          */
/*    4. From interface program. DX, DTS                                                    */
/*                                                                                          */
/* Exceed version: 5.4                                                                      */
/*                                                                                          */
/* Modifications log:                                                                       */
/*                                                                                          */
/* Date       Rev    Author   Purposes                                                      */
/* 2011-09-05 1.0    Ung      Created                                                       */
/* 2011-09-29 1.1    Shong    US LCI Project                                                */
/* 2011-10-14 1.2    ChewKP   Initialize Outfield Values (ChewKP01)                         */
/* 2011-10-14 1.3    Shong    Check UCC already Putaway                                     */
/* 2012-01-13 1.4    James    PA Qty need to match suggested (james01)                      */
/* 2012-02-21 1.5    ChewKP   Update UCC.ID to blank only when LoseID is                    */
/*                          turn on (ChewKP02)                                              */
/* 2012-04-02 1.6    James    SOS240530 - Prevent same loc locked by                        */
/*                          multi user (james02)                                            */
/* 2012-04-16 1.7    Ung      SOS239385 ToLOC lookup logic                                  */
/*                          Custom putaway strategy                                         */
/* 2012-04-18 1.7    James    SOS241610 - Bug fix (james03)                                 */
/* 2012-04-26 1.8    Shong    Patching Update UCC Table                                     */
/* 2012-05-15 1.9    Shong    Add Default UOM is not setup                                  */
/* 2012-09-03 2.0    ChewKP   SOS#255108 - Display error when Location is                   */
/*                          lock by other users (ChewKP03)                                  */
/* 2013-04-25 2.1    Ung      SOS276721 Fix SKU UPC > 20 chars (ung01)                      */
/* 2012-11-21 2.2    Ung      SOS257047 Add Multi SKU UCC                                   */
/*                          Add ExtendedUpdateSP                                            */
/* 2013-08-01 2.3    James    SOS285469 - Add LOC prefix (james04)                          */
/*                          Add confirm add new loc screen                                  */
/* 2013-09-23 2.4    SPChin   SOS290116 - Bug Fixed                                         */
/* 2014-01-02 2.5    ChewKP   SOS292706 - Various Fixes (ChewKP04)                          */
/* 2014-02-26 2.6    James    SOS301646-H&M Modification (james05)                          */
/* 2014-04-28 2.7    James    Bug fix (james06)                                             */
/* 2015-05-11 2.8    ChewKP   SOS#340776 - Order By Loc (ChewKP05)                          */
/* 2015-10-28 2.8    James    SOS353560-Revamp ExtendedValidateSP @ step4                   */
/*                          Add ExtendedInfoSP (james07)                                    */
/* 2016-09-30 2.9    Ung      Performance tuning                                            */
/* 2016-12-07 3.0    Ung      WMS-751 Add ExtendedPutawaySP                                 */
/*                          Replace DefaultPutawayQTYtoActQTY with DefaultQTY               */
/*                          Remove PutawayBySKUSkipErrMsg                                   */
/*                          Remove CtnRcvAllowNewLoc                                        */
/*                          Remove CtnRcvGetFacilityPrefix                                  */
/*                          Clean up source                                                 */
/* 2017-02-17 3.0    James    WMS1079-Add ExtendedValidateSP @ step1&2 (james08)            */
/* 2017-10-10 3.1    Ung      IN00487075 Fix wo PASuggestSKU go to ID/SKU scn               */
/* 2017-10-10 3.2    Ung      WMS-3552 Bring back LOC not match screen                      */
/* 2018-05-28 3.3    Ung      WMS-5183 Add DefaultSuggestLOC                                */
/* 2018-06-05 3.4    James    WMS5311-Add rdt_decode sp (james09)                           */
/* 2018-02-08 3.5    James    WMS6248-Check status of SKU (james10)                         */
/* 2018-09-28 3.6    TungGH   Performance                                                   */
/* 2019-05-03 3.7    Ung      INC0686264 ID with UCC must putaway by UCC                    */
/* 2019-02-20 3.8    YeeKung  WMS-8020 Add RDTSTDEVENTLOG (yeekung01)                       */
/* 2019-03-05 3.9    YeeKung  WMS-8196 Add Loc Prefix   (yeekung02)                         */
/*                          Comparing count by qty put away and carton                      */
/* 2019-05-21 4.0    YeeKung  WMS-9018 Add multisku screen   (yeekung03)                    */
/* 2019-12-03 4.2    James    WMS-10987 Add SKUBarcode variable (james11)                   */
/* 2020-01-20 4.3    YeeKung  WMS-11780 Add lotxlocxid doctype (yeekung04)                  */
/* 2020-02-18 4.4    Chermaine WMS-11813 Add upc to RDTMOBREC (cc01)                        */
/* 2020-12-15 4.5    James    WMS-15820 Restructure output @ Qty screen(james12)            */
/*                          Add ExtInfo @ step 2 & 4, ExtValid @ step 3                     */
/* 2022-07-08 4.6    James    WMS-20188 Add flow thru screen 3-> 4 (james13)                */
/* 2020-09-17 4.7    WinSern  Increase @nMQTY_PWY AS NVARCHAR( 5) to (6)  (ws01)            */
/* 2022-12-06 4.8    James    WMS-21272 Add DecodeSP, retrieve lot using                    */
/*                          lottable returned (james14)                                     */
/* 2022-12-09 4.9    James    WMS-21307 Add ExtendedInfoSP step 1 & 5 (james14)             */
/* 2023-06-28 5.0    Ung      WMS-22741 Remove rdt_Decode error                             */
/*                          Add L01-04 to rdt_Decode                                        */
/* 2023-08-08 5.1    YeeKung  JSM-168921 ADD Rowcount  (yeekung04)                          */
/* 2023-08-10 5.2    Ung      WMS-23170 Add PieceScan                                       */
/* 2024-10-21 5.3    ShaoAn   FCR-759-999 ID and UCC Length Issue                           */
/* 2024-10-24 5.3.1           Extended parameter definition                                 */
/********************************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_PutawayBySKU] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Other var use in this stor proc
DECLARE
   @b_Success        INT,
   @c_errmsg         NVARCHAR( 250),
   @cNextLOT         NVARCHAR( 10),
   @cByLOT           NVARCHAR( 10),
   @cChkFacility     NVARCHAR( 5),
   @cSQL             NVARCHAR( MAX),
   @cSQLParam        NVARCHAR( MAX),
   @cPQTY            NVARCHAR( 6),      --ws01
   @cMQTY            NVARCHAR( 6),      --ws01
   @cOption          NVARCHAR( 1),
   @cExtendedInfo1   NVARCHAR( 20),
   @nTranCount       INT

-- Variable for RDT.RDTMobRec
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @nMenu            INT,

   @cStorer          NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cUserName        NVARCHAR( 18),

   @cID              NVARCHAR( 18),
   @cLOC             NVARCHAR( 10),
   @cSKU             NVARCHAR( 30),
   @cSKUDesc         NVARCHAR( 60),
   @cPUOM            NVARCHAR( 10),
   @cLOT             NVARCHAR( 10),
   @cLottable01      NVARCHAR( 18),
   @cLottable02      NVARCHAR( 18),
   @cLottable03      NVARCHAR( 18),
   @dLottable04      DATETIME,
   @cUCC             NVARCHAR( 20),

   @cSuggestSKU         NVARCHAR( 20),
   @cSuggestedLOC       NVARCHAR( 10),
   @cFinalLOC           NVARCHAR( 10),
   @cMUOM_Desc          NVARCHAR( 5),
   @cPUOM_Desc          NVARCHAR( 5),
   @cQTY_Avail          NVARCHAR( 5),
   @cQTY_Alloc          NVARCHAR( 5),
   @cQTY_PMoveIn        NVARCHAR( 5),
   @cLabelType          NVARCHAR( 20),

   @nPUOM_Div           INT,
   @nPQTY_PWY           INT,
   @nMQTY_PWY           INT,
   @nQTY_PWY            INT,
   @nPQTY               INT,
   @nMQTY               INT,
   @nQTY                INT,
   @nRec                INT,
   @nTotalRec           INT,
   @nPABookingKey       INT,
   @nPieceScanQTY       INT, 
   @nFromScn            INT,   --(yeekung03)

   @cPASuggestSKU       NVARCHAR( 1),
   @cPABySKUAndLOT      NVARCHAR( 1),
   @cDecodeLabelNo      NVARCHAR( 20),
   @cToLOCLookupSP      NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cPAMatchSuggestLOC  NVARCHAR( 1),
   @cPAMatchQTY         NVARCHAR( 1),
   @cDefaultQTY         NVARCHAR( 1),
   @cDefaultSuggestSKU  NVARCHAR( 1),
   @cDecodeSP           NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cBarcodeUCC         NVARCHAR( 60),
   @cLabelNo            NVARCHAR( 32),
   @cSKUStatus          NVARCHAR( 10), -- (james10)
   @cLOCLookupSP        NVARCHAR( 20),  -- (yeekung02)
   @cMultiSKUBarcode    NVARCHAR(1),  --(yeekung03)
   @cSKUBarcode         NVARCHAR( 20), -- (james11)
   @cSKUVar             NVARCHAR( 20), -- (yeekung04)
   @cSKUDefault         NVARCHAR( 20), --(yeekung04)
   @cPieceScan          NVARCHAR( 1),
   @cUPC                NVARCHAR( 30),  --(cc01)
   @cFlowThruQtyScn     NVARCHAR( 1),
   @cPieceScanSKU       NVARCHAR( 20),
   @cDecodeLottable01   NVARCHAR( 18),
   @cDecodeLottable02   NVARCHAR( 18),
   @cDecodeLottable03   NVARCHAR( 18),
   @dDecodeLottable04   DATETIME,
   @cSQLSelect          NVARCHAR( MAX),
   @cSQLWhere           NVARCHAR( MAX),
   @cSQLOrderBy         NVARCHAR( MAX),
   @nRowCount           INT,

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc         = Func,
   @nScn          = Scn,
   @nStep         = Step,
   @nInputKey     = InputKey,
   @nMenu         = Menu,
   @cLangCode     = Lang_code,

   @cStorer       = StorerKey,
   @cFacility     = Facility,
   @cUserName     = UserName,

   @cID           = V_ID,
   @cLOC          = V_LOC,
   @cSKU          = V_SKU,
   @cSKUDesc      = V_SKUDescr,
   @cPUOM         = V_UOM,
   @cLOT          = V_LOT,
   @cLottable01   = V_Lottable01,
   @cLottable02   = V_Lottable02,
   @cLottable03   = V_Lottable03,
   @dLottable04   = V_Lottable04,
   @cUCC          = V_UCC,

   @cSuggestSKU   = V_String1,
   @cSuggestedLOC = V_String2,
   @cFinalLOC     = V_String3,
   @cMUOM_Desc    = V_String4,
   @cPUOM_Desc    = V_String5,
   @cLabelType    = V_String6,
   @cQTY_Avail    = V_String7,
   @cQTY_Alloc    = V_String8,
   @cQTY_PMoveIn  = V_String9,
   @cSKUBarcode   = V_String11,
   @cFlowThruQtyScn = V_String12,
   @cPieceScanSKU = V_String13,

   @nPUOM_Div     = V_PUOM_Div,
   @nPQTY         = V_PQTY,
   @nMQTY         = V_MQTY,

   @nPQTY_PWY     = V_Integer1,
   @nMQTY_PWY     = V_Integer2,
   @nQTY_PWY      = V_Integer3,
   @nQTY          = V_Integer4,
   @nRec          = V_Integer5,
   @nTotalRec     = V_Integer6,
   @nPABookingKey = V_Integer7,
   @nPieceScanQTY = V_Integer8,

   @cPASuggestSKU       = V_String20,
   @cPABySKUAndLOT      = V_String21,
   @cDecodeLabelNo      = V_String22,
   @cToLOCLookupSP      = V_String23,
   @cExtendedUpdateSP   = V_String24,
   @cExtendedValidateSP = V_String25,
   @cExtendedInfoSP     = V_String26,
   @cPAMatchSuggestLOC  = V_String27,
   @cPAMatchQTY         = V_String28,
   @cDefaultQTY         = V_String29,
   @cDefaultSuggestSKU  = V_String30,
   @cDecodeSP           = V_String31,
   @cSKUStatus          = V_String32, -- (james10)
   @cLOCLookupSP        = V_String33, -- (yeekung02)
   @nFromScn            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String34, 5), 0) = 1 THEN LEFT( V_String34, 5) ELSE 0 END, --(yekung03)
   @cMultiSKUBarcode    = V_String35, --(yeekung03)
   @cSKUVar             = V_String36,
   @cSKUDefault         = V_String37,
   @cPieceScan          = V_String38,

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 523
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 523. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn  = 2880. ID, LOC
   IF @nStep = 2 GOTO Step_2   -- Scn  = 2881. SKU
   IF @nStep = 3 GOTO Step_3   -- Scn  = 2882. Lottables, QTY
   IF @nStep = 4 GOTO Step_4   -- Scn  = 2883. Suggested LOC, final LOC
   IF @nStep = 5 GOTO Step_5   -- Scn  = 2884. Successful putaway
   IF @nStep = 6 GOTO Step_6   -- Scn  = 2885. LOC not match. Proceed?
   IF @nStep = 7 GOTO Step_7   -- Scn  = 3570. Multi SKU
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 524. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- Get preferred UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

   -- Get storer configure
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorer)
   SET @cDefaultSuggestSKU = rdt.RDTGetConfig( @nFunc, 'DefaultSuggestSKU', @cStorer)
   SET @cFlowThruQtyScn = rdt.RDTGetConfig( @nFunc, 'FlowThruQtyScn', @cStorer)
   SET @cLOCLookupSP = rdt.rdtGetConfig(@nFunc,'LOCLookupSP',@cStorer)       --(yeekung02)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorer)    --(yeekung03)
   SET @cPABySKUAndLOT = rdt.RDTGetConfig( @nFunc, 'PutawayBySKUAndLOT', @cStorer)
   SET @cPAMatchQTY = rdt.RDTGetConfig( @nFunc, 'PutawayBySKUMatchQty', @cStorer)
   SET @cPAMatchSuggestLOC = rdt.RDTGetConfig( @nFunc, 'PutawayMatchSuggestLOC', @cStorer)
   SET @cPASuggestSKU = rdt.RDTGetConfig( @nFunc, 'PutawaySuggestSKU', @cStorer)
   SET @cPieceScan = rdt.RDTGetConfig( @nFunc, 'PieceScan', @cStorer)
   SET @cToLOCLookupSP = rdt.RDTGetConfig( @nFunc, 'PutawayToLOCLookup', @cStorer)

   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorer)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorer)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorer)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorer)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cSKUStatus = rdt.RDTGetConfig( @nFunc, 'SKUStatus', @cStorer)
   IF @cSKUStatus = '0'
      SET @cSKUStatus = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerkey  = @cStorer,
      @nStep     = @nStep

   -- Prepare next screen var
   SET @cOutField01 = '' -- ID
   SET @cOutField02 = '' -- UCC
   SET @cOutField03 = '' -- LOC

   -- Set the entry point
   SET @nScn = 2880
   SET @nStep = 1

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 2880
   ID  (field01, input)
   UCC (field02, input)
   LOC (field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField01
      SET @cUCC = @cInField02
      SET @cLOC = @cInField03
      SET @cBarcode = @cInField01
      SET @cLabelNo = @cInField01
      SET @cBarcodeUCC = @cInField02

      -- Check blank
      IF @cID = '' AND @cUCC = ''
      BEGIN
         SET @nErrNo = 73851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need ID/UCC
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Decode
      -- Standard decode
      IF @cDecodeSP <> ''
      BEGIN
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode,
               @cID     = @cID     OUTPUT,
               @nErrNo  = 0,  --@nErrNo     OUTPUT,
               @cErrMsg = '', --@cErrMsg    OUTPUT
               @cType   = 'ID'
         END
         -- Customize decode    
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, @cBarcodeUCC,' +    
                  ' @cID, @cUCC OUTPUT, @cLOC OUTPUT, @cSKU OUTPUT, @nQTY OUTPUT, ' + 
                  ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '   
      
            SET @cSQLParam =    
                  ' @nMobile           INT                  , ' +
                  ' @nFunc             INT                  , ' +
                  ' @cLangCode         NVARCHAR( 3)         , ' +
                  ' @nStep             INT                  , ' +
                  ' @nInputKey         INT                  , ' +
                  ' @cFacility         NVARCHAR( 5)         , ' +
                  ' @cStorerKey        NVARCHAR( 15)        , ' +
                  ' @cBarcode          NVARCHAR( 60)        , ' +
                  ' @cBarcodeUCC       NVARCHAR( 60)        , ' +
                  ' @cID               NVARCHAR( 18)  OUTPUT, ' +
                  ' @cUCC              NVARCHAR( 20)  OUTPUT, ' +
                  ' @cLOC              NVARCHAR( 10)  OUTPUT, ' +
                  ' @cSKU              NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY              INT            OUTPUT, ' +
                  ' @cLottable01       NVARCHAR( 18)  OUTPUT, ' +
                  ' @cLottable02       NVARCHAR( 18)  OUTPUT, ' +
                  ' @cLottable03       NVARCHAR( 18)  OUTPUT, ' +
                  ' @dLottable04       DATETIME       OUTPUT, ' +
                  ' @nErrNo            INT            OUTPUT, ' +
                  ' @cErrMsg           NVARCHAR( 20)  OUTPUT'    
      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @cBarcode,@cBarcodeUCC,
                  @cID OUTPUT, @cUCC OUTPUT, @cLOC OUTPUT, @cSKU OUTPUT, @nQTY OUTPUT, 
                  @cDecodeLottable01 OUTPUT, @cDecodeLottable02 OUTPUT, @cDecodeLottable03 OUTPUT, @dDecodeLottable04 OUTPUT,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT    

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Decode label
         IF @cDecodeLabelNo <> ''
         BEGIN
            SELECT @c_oFieled01 = '', @c_oFieled02 = '',
                   @c_oFieled03 = '', @c_oFieled04 = '',
                   @c_oFieled05 = '', @c_oFieled06 = '',
                   @c_oFieled07 = '', @c_oFieled08 = '',
                   @c_oFieled09 = '', @c_oFieled10 = ''

            SET @cErrMsg = ''
            SET @nErrNo = 0
            EXEC dbo.ispLabelNo_Decoding_Wrapper
                @c_SPName     = @cDecodeLabelNo
               ,@c_LabelNo    = @cLabelNo
             ,@c_Storerkey  = @cStorer
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
               GOTO Step_1_Fail

            SET @cID = @c_oFieled01
         END
      END

/*
      -- Check both ID and UCC provided
      IF @cID <> '' AND @cUCC <> ''
      BEGIN
         SET @nErrNo = 73852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID or UCC only
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
*/
      DECLARE @nCountLOC INT
      DECLARE @cFromLOC  NVARCHAR( 10)

      IF @cUCC <> ''
      BEGIN
         -- Get UCC info
         SELECT TOP 1
            @cLOC = LOC,
            @cID = ID
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorer
            AND UCCNo = @cUCC
            AND Status = '1'
         ORDER BY SKU

         -- Check valid UCC
         IF @@ROWCOUNT = 0
         BEGIN
           SET @nErrNo = 73853
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid UCC
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- UCC
           SET @cOutField02 = ''
            GOTO Step_1_Fail
         END
      END
      ELSE
      BEGIN
         -- Get ID info
         SELECT
            @nCountLOC = COUNT( DISTINCT LOC.LOC),
            @cFromLOC = MIN( LOC.LOC) -- Just to bypass SQL aggregate check
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE Facility = @cFacility
            AND ID = @cID
            AND (QTY - QTYAllocated - QTYPicked - ABS( QTYReplen)) > 0

         -- Check valid ID
         IF @nCountLOC = 0
         BEGIN
            SET @nErrNo = 73854
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ID
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID
            SET @cOutField01 = ''
            GOTO Step_1_Fail
         END

         -- Auto default LOC
         IF @nCountLOC = 1 AND @cLOC = ''
            SET @cLOC = @cFromLOC

         -- Check ID with multi LOC
         IF @nCountLOC > 1 AND @cLOC = ''
         BEGIN
            SET @nErrNo = 73855
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID in multiLOC
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC
            GOTO Quit
         END

         -- -- Check ID with UCC
         --IF EXISTS( SELECT TOP 1 1
         --   FROM UCC WITH (NOLOCK)
         --   WHERE StorerKey = @cStorer
         --      AND LOC = @cLOC
         --      AND ID = @cID
         --      AND Status BETWEEN '1' AND '3')
         --BEGIN
         --   SET @nErrNo = 73873
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID with UCC
         --   EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID
         --   SET @cOutField01 = ''
         --   GOTO Quit
         --END
      END
      SET @cOutField01 = @cID
      SET @cOutField02 = @cUCC

      -- Check blank from loc
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 73856
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need LOC
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC
         GOTO Step_1_Fail
      END

      -- (yeekung02) add loc prefix
      IF @cLOCLookupSP = 1
      BEGIN
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility,
         @cLOC   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Step_1_Fail
      END

      -- Check from loc different facility
      SELECT @cChkFacility = Facility FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 73857
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid LOC
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC
         SET @cOutField03 = ''
         GOTO Step_1_Fail
      END

      -- Check from loc different facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 73858
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC
         SET @cOutField03 = ''
         GOTO Step_1_Fail
      END

      -- Check LOC in ID/UCC
      IF NOT EXISTS( SELECT 1
        FROM dbo.LOTxLOCxID WITH (NOLOCK)
        WHERE LOC = @cLOC
          AND ID = @cID
          AND (QTY - QTYAllocated - QTYPicked - ABS( QTYReplen)) > 0)
      BEGIN
         SET @nErrNo = 73859
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LOCNotInID/UCC
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC
         SET @cOutField03 = ''
         GOTO Step_1_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cFromLOC, @cFromID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo       INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility,
               @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cID, @cUCC, @cLOC, @cSuggestSKU, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cID             NVARCHAR( 18), ' +
               '@cUCC            NVARCHAR( 20), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cSuggestSKU     NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility,
               @cID, @cUCC, @cLOC, @cSuggestSKU, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

          IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Suggest SKU
      IF @cPASuggestSKU = '1'
      BEGIN
         IF @cUCC <> ''
            SELECT TOP 1
               @cSuggestSKU = SKU
            FROM dbo.UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND UCCNo = @cUCC
               AND Status = '1'
            ORDER BY SKU
         ELSE
            SELECT TOP 1
               @cSuggestSKU = SKU
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            WHERE LOC = @cLOC
               AND ID = @cID
               AND (QTY - QTYAllocated - QTYPicked - ABS( QTYReplen)) > 0
            ORDER BY SKU
            SELECT @cSKUDesc = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSuggestSKU
      END
      ELSE
      BEGIN
         SET @cSuggestSKU = ''
         SET @cSKUDesc = ''
      END

      SET @cPieceScanSKU = ''
      SET @nPieceScanQTY = 0

      -- Prepare next screen variable
      SET @cSKU = ''
      SET @cOutField01 = @cID
      SET @cOutField02 = @cUCC
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cSuggestSKU
      SET @cOutField05 = @cSKU
      SET @cOutField06 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField07 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cOutField08 = '' -- PieceScanQTY

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerkey  = @cStorer,
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END

   -- (james14)
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo1 = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cFacility, ' +
            ' @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nAfterStep      INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cLOC            NVARCHAR( 10), ' +
            '@cID             NVARCHAR( 18), ' +
            '@cSKU            NVARCHAR( 20), ' +
            '@nQTY            INT,           ' +
            '@cSuggestedLOC   NVARCHAR( 10), ' +
            '@cFinalLOC       NVARCHAR( 10), ' +
            '@cOption         NVARCHAR( 1),  ' +
            '@cExtendedInfo1  NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cStorer, @cFacility,
            @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT

         SET @cOutfield15 = @cExtendedInfo1
      END
   END
   
   GOTO Quit

   Step_1_Fail:

END
GOTO Quit


/********************************************************************************
Step 2. Scn = 2881
   ID               (field01)
   UCC              (field02)
   LOC              (field03)
   SuggestSKU       (field04)
   SKU              (field05, input)
   SuggestSKU Desc1 (field06)
   SuggestSKU Desc2 (field07)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @nUCCQTY INT

      SET @nUCCQTY = 0
      SET @cLabelType = ''

      -- Screen mapping
      SET @cLabelNo = @cInField05
      SET @cBarcode = @cInField05
      SET @cUPC = @cInField05
      SET @cSKUBarcode = @cInField05

      -- Check SKU blank
      IF @cLabelNo = ''
      BEGIN
         -- Piece scan and some QTY scanned
         IF @cPieceScan = '1' AND @nPieceScanQTY > 0
         BEGIN
            SET @nRec = 1
            SET @cSKU = @cPieceScanSKU
            
            SET @cOutField01 = @cSKU
            SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
            SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
            SET @cOutField04 = @cLottable01
            SET @cOutField05 = @cLottable02
            SET @cOutField06 = @cLottable03
            SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
            SET @cOutField08 = LEFT( '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6)) + SPACE( 7), 7) +
                               RIGHT( SPACE( 5) + rdt.rdtRightAlign( @cPUOM_Desc, 5), 5) +
                               RIGHT( SPACE( 5) + rdt.rdtRightAlign( @cMUOM_Desc, 5), 5)
            SET @cOutField09 = CAST( @nRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
            SET @cOutField11 = CASE WHEN @cFieldAttr13 = 'O' THEN '' ELSE CAST( @nPQTY_PWY AS NVARCHAR( 5)) END
            SET @cOutField12 = CAST( @nMQTY_PWY AS NVARCHAR( 6))
            SET @cOutField13 = ''
            SET @cOutField14 = CASE WHEN @cPieceScan = '1' THEN CAST( @nPieceScanQTY AS NVARCHAR( 5))
                                    WHEN @cDefaultQTY = '1' THEN '1' 
                                    ELSE '' 
                               END            
            
            -- Go to next screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Step_2_Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 73860
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU
            GOTO Step_2_Fail
         END
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
      	SET @cDecodeLottable01 = ''
      	SET @cDecodeLottable02 = ''
      	SET @cDecodeLottable03 = ''
      	SET @dDecodeLottable04 = ''
         	
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode,
               @cUPC        = @cUPC              OUTPUT,
               @nQTY        = @nQTY              OUTPUT,
               @cLottable01 = @cDecodeLottable01 OUTPUT, 
               @cLottable02 = @cDecodeLottable02 OUTPUT, 
               @cLottable03 = @cDecodeLottable03 OUTPUT, 
               @dLottable04 = @dDecodeLottable04 OUTPUT,
               @nErrNo      = 0,  --@nErrNo      OUTPUT,
               @cErrMsg     = '', --@cErrMsg     OUTPUT
               @cType       = 'UPC'
         END
         
         -- Customize decode    
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, @cBarcodeUCC, ' +    
               ' @cID OUTPUT, @cUCC OUTPUT, @cLOC OUTPUT, @cSKU OUTPUT, @nQTY OUTPUT, ' + 
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '   
   
            SET @cSQLParam =    
               ' @nMobile           INT                  , ' +    
               ' @nFunc             INT                  , ' +    
               ' @cLangCode         NVARCHAR( 3)         , ' +    
               ' @nStep             INT                  , ' +    
               ' @nInputKey         INT                  , ' +    
               ' @cFacility         NVARCHAR( 5)         , ' +    
               ' @cStorerKey        NVARCHAR( 15)        , ' +    
               ' @cBarcode          NVARCHAR( 60)        , ' +    
               ' @cBarcodeUCC       NVARCHAR( 60)        , ' +
               ' @cID               NVARCHAR( 18)  OUTPUT, ' +
               ' @cUCC              NVARCHAR( 20)  OUTPUT, ' +
               ' @cLOC              NVARCHAR( 10)  OUTPUT, ' +
               ' @cSKU              NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY              INT            OUTPUT, ' +
               ' @cLottable01       NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02       NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03       NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04       DATETIME       OUTPUT, ' +
               ' @nErrNo            INT            OUTPUT, ' +    
               ' @cErrMsg           NVARCHAR( 20)  OUTPUT'    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @cBarcode, @cBarcodeUCC,   
               @cID OUTPUT, @cUCC OUTPUT, @cLOC OUTPUT, @cSKU OUTPUT, @nQTY OUTPUT, 
               @cDecodeLottable01 OUTPUT, @cDecodeLottable02 OUTPUT, @cDecodeLottable03 OUTPUT, @dDecodeLottable04 OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT    

            IF @nErrNo <> 0
               GOTO Quit
               
            SET @cUPC = @cSKU
         END
      END    
      ELSE
      BEGIN
         -- Decode label
         IF @cDecodeLabelNo <> ''
         BEGIN
            SELECT   @c_oFieled01 = '', @c_oFieled02 = '',
                     @c_oFieled03 = '', @c_oFieled04 = '',
                     @c_oFieled05 = '', @c_oFieled06 = '',
                     @c_oFieled07 = '', @c_oFieled08 = '',
                     @c_oFieled09 = '', @c_oFieled10 = ''

            SET @cErrMsg = ''
            SET @nErrNo = 0
            EXEC dbo.ispLabelNo_Decoding_Wrapper
                @c_SPName     = @cDecodeLabelNo
               ,@c_LabelNo    = @cLabelNo
               ,@c_Storerkey  = @cStorer
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
               ,@n_ErrNo      = @nErrNo  OUTPUT
               ,@c_ErrMsg     = @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail

            SET @cSKU = @c_oFieled01
            SET @cUPC = @c_oFieled01
            SET @cLabelType = @c_oFieled07
            SET @cUCC = @c_oFieled08
            SET @nUCCQTY = CAST(@c_oFieled05 AS INT)
         END
      END

      IF @cLabelType = 'UCC'
      BEGIN
         IF NOT EXISTS(SELECT 1
                     FROM UCC WITH (NOLOCK)
                     WHERE UCCNO = @cUCC
                     AND   ID = @cID)
         BEGIN
            SET @nErrNo = 73861
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UCC Already PA
            GOTO Step_2_Fail
         END
      END

      -- Get SKU barcode count
      DECLARE @nSKUCnt INT
      EXEC rdt.rdt_GETSKUCNT
          @cStorerkey  = @cStorer
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT
         ,@cSKUStatus  = @cSKUStatus

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 73862
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         GOTO Step_2_Fail
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         -- (yeekung03)
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            --(yeekung04)
            IF (@cID<>'')
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
                  @cStorer,
                  @cUPC     OUTPUT,
                  @nErrNo   OUTPUT,
                  @cErrMsg  OUTPUT,
                  'LOTXLOCXID.ID',  --(yeekung04)
                  @cID
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
               @cStorer,
               @cUPC     OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT
            END

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nFromScn = @nScn
               SET @nScn = 3570
               SET @nStep = @nStep + 5
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
            BEGIN
               SET @nErrNo = 0
               SET @cSKU = @cUPC
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 73863
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
            GOTO Step_2_Fail
         END
      END

      -- Get SKU code
      EXEC rdt.rdt_GETSKU
          @cStorerkey  = @cStorer
         ,@cSKU        = @cUPC          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT
         ,@cSKUStatus  = @cSKUStatus

      SET @cSKU = @cUPC

      -- Check SKU same as suggested
      IF @cSuggestSKU <> '' AND @cSKU <> @cSuggestSKU
      BEGIN
         SET @nErrNo = 73864
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Different SKU
         GOTO Step_2_Fail
      END

      -- Get LOT
      SET @cLOT = ''
      IF @cUCC <> ''
      BEGIN
         SELECT
            @cLOT = LOT,
            @cLOC = LOC
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cUCC
            AND StorerKey = @cStorer
            AND SKU = @cSKU
            AND Status = '1'

         SET @nRowCount = @@ROWCOUNT --yeekung04
      END
      ELSE
      BEGIN
      	SET @cSQLSelect = ''
      	SET @cSQLWhere = ''
      	SET @cSQLOrderBy = ''
         SET @nRowCount = 0
         
         SET @cSQLSelect = 
            ' SELECT TOP 1 @cLOT = LLI.LOT ' + 
            ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' +
            ' JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ' +
            '    ON ( LLI.LOT = LA.LOT)' +
            ' WHERE LLI.ID = @cID ' +
            ' AND   LLI.LOC = @cLOC ' +
            ' AND   LLI.StorerKey = @cStorerKey ' +
            ' AND   LLI.SKU = @cSKU ' +
            ' AND  (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - ABS( LLI.QTYReplen)) > 0 '
  
         IF ISNULL( @cDecodeLottable01, '') <> ''
            SET @cSQLWhere = ' AND   LA.Lottable01 = @cLottable01 '

         IF ISNULL( @cDecodeLottable02, '') <> ''
            SET @cSQLWhere = @cSQLWhere + ' AND   LA.Lottable02 = @cLottable02 '

         IF ISNULL( @cDecodeLottable03, '') <> ''
            SET @cSQLWhere = @cSQLWhere + ' AND   LA.Lottable03 = @cLottable03 '

         IF ISNULL( @dDecodeLottable04, '') <> ''
            SET @cSQLWhere = @cSQLWhere + ' AND   LA.Lottable04 = @dLottable04 '
         
         SET @cSQLOrderBy = 'ORDER BY LLI.LOT '
         SET @cSQLOrderBy = @cSQLOrderBy + 'SET @nRowCount = @@ROWCOUNT'
         
         SET @cSQL = @cSQLSelect + @cSQLWhere + @cSQLOrderBy
   
         SET @cSQLParam = 
            '@cID             NVARCHAR( 18), ' +  
            '@cLOC            NVARCHAR( 10), ' +  
            '@cStorerKey      NVARCHAR( 15), ' + 
            '@cSKU            NVARCHAR( 20), ' +
            '@cLottable01     NVARCHAR( 18), ' +
            '@cLottable02     NVARCHAR( 18), ' +
            '@cLottable03     NVARCHAR( 18), ' +
            '@dLottable04     DATETIME, ' +
            '@cLOT            NVARCHAR( 10)  OUTPUT, ' + 
            '@nRowCount       INT            OUTPUT '
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
            @cID, @cLOC, @cStorer, @cSKU, 
            @cDecodeLottable01, @cDecodeLottable02, @cDecodeLottable03, @dDecodeLottable04, 
            @cLOT OUTPUT, @nRowCount OUTPUT
    	END

      -- Check SKU on ID
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 73865
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKUNotOnID/UCC
         GOTO Step_2_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cFromLOC, @cFromID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility,
               @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail
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
            SET @nErrNo = 73876
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Different SKU
            GOTO Step_2_Fail
         END
      END

      -- Get SKU info
      SELECT
            @cSKUDesc = S.Descr,
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
      WHERE StorerKey = @cStorer
         AND SKU = @cSKU

      -- Get lottable
      SELECT
         @cLottable01 = LA.Lottable01,
         @cLottable02 = LA.Lottable02,
         @cLottable03 = LA.Lottable03,
         @dLottable04 = LA.Lottable04
      FROM dbo.LOTAttribute LA WITH (NOLOCK)
      WHERE LOT = @cLOT

      -- Get QTY
      IF @cLabelType = 'UCC'
         SELECT
            @nRec = 1,
            @nTotalRec = 1,
            @nQTY_PWY = @nUCCQTY
      ELSE IF @cUCC <> ''
         SELECT
            @nRec = 1,
            @nTotalRec = 1,
            @nQTY_PWY = QTY
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cUCC
            AND StorerKey = @cStorer
            AND SKU = @cSKU
            AND Status = '1'
      ELSE IF @cPABySKUAndLOT = '1'
         SELECT
            @nRec = 1,
            @nTotalRec = 1,
            @nQTY_PWY = QTY - QTYAllocated - QTYPicked - ABS( QTYReplen)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         WHERE LOT = @cLOT
            AND LOC = @cLOC
            AND ID = @cID
      ELSE
         SELECT
            @nRec = 1,
            @nTotalRec = COUNT( DISTINCT LOT),
            @nQTY_PWY = ISNULL( SUM( QTY - QTYAllocated - QTYPicked - ABS( QTYReplen)), 0)
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE ID = @cID
            AND LOC = @cLOC
            AND StorerKey = @cStorer
            AND SKU = @cSKU
            AND (QTY - QTYAllocated - QTYPicked - ABS( QTYReplen)) > 0

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_PWY = 0
         SET @nPQTY  = 0
         SET @nMQTY_PWY = @nQTY_PWY
         SET @cFieldAttr13 = 'O' -- @nPQTY_PWY
         SET @cInField13 = ''
      END
      ELSE
      BEGIN
         SET @nPQTY_PWY = @nQTY_PWY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_PWY = @nQTY_PWY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Piece scan
      IF @cPieceScan = '1'
      BEGIN
         -- Increase scan count
         SET @nPieceScanQTY += 1
         
         -- Not fully scan
         IF @nPieceScanQTY < @nQTY_PWY
         BEGIN
            -- Stay at same screen
            SET @cOutField01 = @cID
            SET @cOutField02 = @cUCC
            SET @cOutField03 = @cLOC
            SET @cOutField04 = @cSuggestSKU
            SET @cOutField05 = '' -- @cSKU
            SET @cOutField06 = SUBSTRING( @cSKUDesc, 1, 20)
            SET @cOutField07 = SUBSTRING( @cSKUDesc, 21, 20)
            SET @cOutField08 = CAST( @nPieceScanQTY AS NVARCHAR( 5)) + '/' + CAST( @nQTY_PWY AS NVARCHAR( 5))

            GOTO Step_2_Quit
         END
      END
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Prepare next screen variable
      SET @nRec = 1
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cOutField04 = @cLottable01
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField08 = LEFT( '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6)) + SPACE( 7), 7) +
                         RIGHT( SPACE( 5) + rdt.rdtRightAlign( @cPUOM_Desc, 5), 5) +
                         RIGHT( SPACE( 5) + rdt.rdtRightAlign( @cMUOM_Desc, 5), 5)
      SET @cOutField09 = CAST( @nRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField11 = CASE WHEN @cFieldAttr13 = 'O' THEN '' ELSE CAST( @nPQTY_PWY AS NVARCHAR( 5)) END
      SET @cOutField12 = CAST( @nMQTY_PWY AS NVARCHAR( 6))
      SET @cOutField13 = ''
      SET @cOutField14 = CASE WHEN @cPieceScan = '1' THEN CAST( @nPieceScanQTY AS NVARCHAR( 5))
                              WHEN @cDefaultQTY = '1' THEN '1' 
                              ELSE '' 
                         END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF @cUCC <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- UCC
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID

      -- Prepare prev screen variable
      SET @cID = ''
      SET @cUCC = ''
      SET @cLOC = ''
      SET @cOutField01 = '' -- ID
      SET @cOutField02 = '' -- UCC
      SET @cOutField03 = '' -- LOC

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   Step_2_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cFacility, ' +
               ' @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nAfterStep      INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cStorer, @cFacility,
               @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT

            SET @cOutfield15 = @cExtendedInfo1
         END
      END
   
    	-- Flow thru
    	IF @cFlowThruQtyScn = '1'
    	BEGIN
         SET @cOutField14 = CASE WHEN @cPieceScan = '1' THEN @nPieceScanQTY
                                 WHEN @cDefaultQTY = '1' THEN '1' 
                                 ELSE '' 
                            END
         GOTO Step_3
      END
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField05 = '' -- SKU
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 2882
   SKU        (field01)
   DESC1      (field02)
   DESC2      (field03)
   Lottable01 (field04)
   Lottable02 (field05)
   Lottable03 (field06)
   Lottable04 (field07)
   UOM ratio  (field08)
   PUOM       (field09)
   MUOM       (field10)
   PQTY_PWY   (field11)
   MQTY_PWY   (field12)
   PQTY       (field13, input)
   MQTY       (field14, input)
   Rec/Total  (field15)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- screen mapping
      SET @cPQTY = CASE WHEN @cFieldAttr13 = 'O' THEN @cOutField13 ELSE @cInField13 END
      SET @cMQTY = @cInField14

      -- Loop lottable only (QTY no change)
      IF @cPQTY = '' AND @cMQTY = ''
      BEGIN
        -- Check reach last rec
         IF @nRec = @nTotalRec
         BEGIN
            SET @nErrNo = 73866
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No more rec
            GOTO Step_3_Fail
         END

         -- Get next LOT
         SET @cNextLOT = ''
         SELECT TOP 1
            @cNextLOT = LOT
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE ID = @cID
            AND LOC = @cLOC
            AND StorerKey = @cStorer
            AND SKU = @cSKU
            AND (QTY - QTYAllocated - QTYPicked - ABS( QTYReplen)) > 0
            AND LOT > @cLOT
         ORDER BY LOT

         -- Recheck in case changed by other
         IF @cNextLOT = ''
         BEGIN
            SET @nErrNo = 73867
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No more rec
            GOTO Step_3_Fail
         END
         ELSE
            SET @cLOT = @cNextLOT

         -- Get lottable
         SELECT
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04
         FROM dbo.LOTAttribute LA WITH (NOLOCK)
         WHERE LOT = @cLOT

         -- Prepare current screen var
         SET @nRec = @nRec + 1
         SET @cOutField04 = @cLottable01
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
         SET @cOutField11 = CASE WHEN @cFieldAttr13 = 'O' THEN '' ELSE CAST( @nPQTY_PWY AS NVARCHAR( 5)) END
         SET @cOutField12 = CAST( @nMQTY_PWY AS NVARCHAR( 5))
         SET @cOutField15 = CAST( @nRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))

         -- Remain in current screen
         -- SET @nScn = @nScn + 1
         -- SET @nStep = @nStep + 1
         GOTO Quit
      END

      -- Validate PQTY
      IF @cPQTY = '' SET @cPQTY = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 73868
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 13 -- PQTY
         GOTO Step_3_Fail
      END

      -- Validate MQTY
      IF @cMQTY  = '' SET @cMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 73869
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 14 -- MQTY
         GOTO Step_3_Fail
      END

      -- Calc total QTY in master UOM
      SET @nPQTY = CAST( @cPQTY AS INT)
      SET @nMQTY = CAST( @cMQTY AS INT)
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorer, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      -- Validate QTY
      IF @nQTY = 0
      BEGIN
         SET @nErrNo = 73870
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTY needed
         GOTO Step_3_Fail
      END

      IF @cPAMatchQTY = '1'
      BEGIN
         IF @nQTY_PWY <> @nQTY
         BEGIN
            SET @nErrNo = 73871
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTY NOT MATCH
            GOTO Step_3_Fail
         END
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY > @nQTY_PWY
      BEGIN
         SET @nErrNo = 73872
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTYPWY NotEnuf
         GOTO Step_3_Fail
      END

      -- (james12)
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cFromLOC, @cFromID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo       INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility,
               @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

      -- Get suggest LOC
      DECLARE @nPAErrNo INT
      SET @nPAErrNo = 0
      SET @nPABookingKey = 0
      EXEC rdt.rdt_PutawayBySKU_GetSuggestLOC @nMobile, @nFunc, @cLangCode, @cUserName, @cStorer, @cFacility
         ,@cLOC
         ,@cID
         ,@cLOT
         ,@cUCC
         ,@cSKU
         ,@nQTY
         ,@cSuggestedLOC   OUTPUT
         ,@nPABookingKey   OUTPUT
         ,@nPAErrNo        OUTPUT
         ,@cErrMsg         OUTPUT
      IF @nPAErrNo <> 0 AND
         @nPAErrNo <> -1 -- No suggested LOC
      BEGIN
         SET @nErrNo = @nPAErrNo
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Step_3_Fail
      END

      SET @cQTY_Avail = '0'
      SET @cQTY_Alloc = '0'
      SET @cQTY_PMoveIn = '0'

      -- Check any suggested LOC
      IF @cSuggestedLOC = ''
      BEGIN
        SET @nErrNo = 73874
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitableLOC
      END
      ELSE IF @cSuggestedLOC = 'SEE_SUPV'
      BEGIN
         SET @nErrNo = 73875
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuggestedLOC
      END
      ELSE
         -- Get suggested LOC info
         SELECT
            @cQTY_Avail = ISNULL( SUM( LLI.QTY - LLI.QtyPicked), 0),
            @cQTY_Alloc = ISNULL( SUM( LLI.QTYAllocated), 0),
            @cQTY_PMoveIn = ISNULL( SUM( LLI.PendingMoveIn), 0)
         FROM dbo.LotxLocxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LLI.StorerKey = @cStorer
            AND LLI.SKU = @cSKU
            AND LLI.LOC = @cSuggestedLOC

      -- Prepare next screen var
      SET @cOutField01 = @cSuggestedLOC
      SET @cOutField02 = CASE WHEN @cDefaultSuggestSKU = '1' THEN @cSuggestedLOC ELSE '' END -- FinalLOC
      SET @cOutField03 = @cQTY_Avail
      SET @cOutField04 = @cQTY_Alloc
      SET @cOutField05 = @cQTY_PMoveIn
      SET @cOutfield15 = '' -- ExtInfo

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cFacility, ' +
               ' @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nAfterStep      INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cStorer, @cFacility,
               @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT

            SET @cOutfield15 = @cExtendedInfo1
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr13 = '' -- @nPQTY_PWY

      -- Prepare prev screen variable
      SET @cPieceScanSKU = ''
      SET @nPieceScanQTY = 0
      SET @cSKU = ''
      IF @cPASuggestSKU <> '1' SET @cSKUDesc = ''

      SET @cOutField01 = @cID
      SET @cOutField02 = @cUCC
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cSuggestSKU
      SET @cOutField05 = '' -- SKU
      SET @cOutField06 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField07 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cOutField08 = '' -- Piece scan QTY

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:

END
GOTO Quit


/********************************************************************************
Step 4. Scn = 2883
   Suggested LOC  (field01)
   Final LOC      (field02, input)
********************************************************************************/
Step_4:
BEGIN
  IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFinalLOC = @cInField02

      -- Check blank final LOC
      IF @cFinalLOC = ''
      BEGIN
         SET @nErrNo = 73877
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Final LOC
         GOTO Step_4_Fail
      END

      -- Loc prefix
      IF @cLOCLookupSP = 1
      BEGIN
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility,
            @cFinalLOC   OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
         IF @nErrNo <> 0
         GOTO Step_4_Fail
      END

      -- ToLOC lookup
      IF @cToLOCLookupSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cToLOCLookupSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC ' + RTRIM( @cToLOCLookupSP) + ' @cID, @cLOC, @cStorer, @cSKU, @cFinalLOC OUTPUT'
            SET @cSQLParam =
               '@cID        NVARCHAR( 18), ' +
               '@cLOC       NVARCHAR( 10), ' +
               '@cStorer    NVARCHAR( 15), ' +
               '@cSKU       NVARCHAR( 20), ' +
               '@cFinalLOC  NVARCHAR( 10) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @cID
               ,@cLOC
               ,@cStorer
               ,@cSKU
               ,@cFinalLOC OUTPUT
         END
      END

      -- Check from loc different facility
      SELECT @cChkFacility = Facility FROM LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 73878
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid LOC
         GOTO Step_4_Fail
      END

      -- Check from loc different facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 73879
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff facility
         GOTO Step_4_Fail
      END

      -- Check if suggested LOC match
      IF @cSuggestedLOC <> '' AND @cSuggestedLOC <> @cFinalLOC
      BEGIN
         IF @cPAMatchSuggestLOC = '1'
         BEGIN
            SET @nErrNo = 73880
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LOC Not Match
            GOTO Step_4_Fail
         END
         ELSE IF @cPAMatchSuggestLOC = '2'
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = '' -- Option

            -- Go to LOC not match screen
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2

            GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cFromLOC, @cFromID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility,
               @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_4_Fail
         END
      END

      -- Decide putaway by LOT
      IF @cPABySKUAndLOT = '1'
         SET @cByLOT = @cLOT
      ELSE
         SET @cByLOT = ''

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_PutawayBySKU -- For rollback or commit only our own transaction

      -- Putaway
      EXEC rdt.rdt_PutawayBySKU_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cStorer, @cFacility,
         @cByLOT,
         @cLOC,
         @cID,
         @cSKU,
         @nQTY,
         @cFinalLoc,
         @cSuggestedLOC,
         @cLabelType,
         @cUCC,
         @nPABookingKey OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_PutawayBySKU
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_4_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cID, @cUCC, @cLOC, @cSuggestSKU, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cID             NVARCHAR( 18), ' +
               '@cUCC            NVARCHAR( 20), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cSuggestSKU     NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility,
               @cID, @cUCC, @cLOC, @cSuggestSKU, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_PutawayBySKU
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_4_Fail
            END
         END
      END

      --(yeekung01)
      EXEC RDT.rdt_STD_EventLog
      @cActionType      = '3',
      @cUserID          = @cUserName,
      @nMobileNo        = @nMobile,
      @nFunctionID      = @nFunc,
      @cFacility        = @cFacility,
      @cStorerKey       = @cStorer,
      @cLocation        = @cLOC,
      @cID              = @cID,
      @cUCC             = @cUCC,
      @cSKU             = @cSKU,
      @cLottable01      = @cLottable01,
      @cLottable02      = @cLottable02,
      @cLottable03      = @cLottable03,
      @dLottable04      = @dLottable04,
      @nQTY             = @cDefaultQTY,
      @cToLocation      = @cFinalLOC,
      @cStatus          = '0'

      COMMIT TRAN rdtfnc_PutawayBySKU
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
   -- Unlock current session suggested LOC
      IF @nPABookingKey <> 0
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,'' --FromID
            ,'' --SuggLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO Step_4_Fail

         SET @nPABookingKey = 0
      END

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      -- (james12)
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cFacility, ' +
               ' @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nAfterStep      INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cStorer, @cFacility,
               @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT

            SET @cOutfield15 = @cExtendedInfo1
         END
      END
      
   	-- (james13)
      IF @cFlowThruQtyScn = '1' AND @cDefaultQTY = '1'
      BEGIN
         -- Go to prev screen  
         SET @nScn = @nScn - 1  
         SET @nStep = @nStep - 1  

         -- Prepare next screen variable  
         SET @cSKU = ''  
         SET @cOutField01 = @cID  
         SET @cOutField02 = @cUCC  
         SET @cOutField03 = @cLOC  
         SET @cOutField04 = @cSuggestSKU  
         SET @cOutField05 = @cSKU  
         SET @cOutField06 = SUBSTRING( @cSKUDesc, 1, 20)  
         SET @cOutField07 = SUBSTRING( @cSKUDesc, 21, 20)  
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField12 = ''
         SET @cOutField13 = ''
         SET @cOutField14 = ''
         
         -- Set to 3 here because wanna it stop at step 2
         SET @nInputKey = 3
         
         GOTO Step_2
      END
      -- Prepare next screen variable
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cOutField04 = @cLottable01
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField08 = LEFT( '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6)) + SPACE( 7), 7) +
                         RIGHT( SPACE( 5) + rdt.rdtRightAlign( @cPUOM_Desc, 5), 5) +
                         RIGHT( SPACE( 5) + rdt.rdtRightAlign( @cMUOM_Desc, 5), 5)
      SET @cOutField09 = CAST( @nRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField11 = CASE WHEN @cFieldAttr13 = 'O' THEN '' ELSE CAST( @nPQTY_PWY AS NVARCHAR( 5)) END
      SET @cOutField12 = CAST( @nMQTY_PWY AS NVARCHAR( 5))
      SET @cOutField13 = ''
      SET @cOutField14 = CASE WHEN @cDefaultQTY = '1' THEN '1' ELSE '' END
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cFinalLOC = ''
      SET @cOutField02 = '' -- Final LOC
   END
END
GOTO Quit


/********************************************************************************
Step 5. scn = 2884. Message screen
   Successful putaway
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cNextSKU NVARCHAR( 20)
      SET @cNextLOT = ''
      SET @cNextSKU = ''

      -- Get next SKU in UCC
      IF @cUCC <> ''
      BEGIN
         SELECT TOP 1
            @cNextLOT = LOT,
            @cNextSKU = SKU
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cUCC
            AND StorerKey = @cStorer
            AND SKU > @cSKU
            AND Status = '1'
         ORDER BY SKU

         -- If Still having OutStanding Qty, should loop back to SKU Screen
         IF @cNextSKU = ''
            SELECT TOP 1
               @cNextLOT = LOT,
               @cNextSKU = SKU
            FROM dbo.UCC WITH (NOLOCK)
            WHERE UCCNo = @cUCC
               AND StorerKey = @cStorer
               AND Status = '1'
            ORDER BY SKU
      END
      ELSE
      BEGIN
         -- Get next LOT to putaway
         IF @cPABySKUAndLOT = '1'
            SELECT TOP 1
               @cNextLOT = LOT,
               @cNextSKU = SKU
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            WHERE LOT > @cLOT
               AND LOC = @cLOC
               AND ID = @cID
               AND StorerKey = @cStorer
               AND SKU = @cSKU
               AND (QTY - QTYAllocated - QTYPicked - ABS( QTYReplen)) > 0
            ORDER BY LOT

         -- Get next SKU to putaway
         IF @cNextSKU = ''
            SELECT TOP 1
               @cNextSKU = ISNULL(SKU,'')
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND SKU > @cSKU
               AND LOC = @cLOC
               AND ID = @cID
               AND (QTY - QTYAllocated - QTYPicked - ABS( QTYReplen)) > 0
            ORDER BY SKU

         -- If Still having OutStanding Qty, should loop back to SKU Screen
         IF @cNextSKU = ''
            SELECT TOP 1
               @cNextSKU = ISNULL(SKU,'')
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND LOC = @cLOC
               AND ID = @cID
               AND (QTY - QTYAllocated - QTYPicked - ABS( QTYReplen)) > 0
            ORDER BY SKU
      END

      -- Go to next SKU
      IF @cNextSKU <> ''
      BEGIN
         -- Suggest SKU
         IF @cPASuggestSKU = '1'
         BEGIN
            SET @cSuggestSKU = @cNextSKU
            SELECT @cSKUDesc = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSuggestSKU
         END
         ELSE
         BEGIN
            SET @cSuggestSKU = ''
            SET @cSKUDesc = ''
         END

         SET @cPieceScanSKU = '' 
         SET @nPieceScanQTY = 0

         -- Prepare next screen variable
         SET @cSKU = ''
         SET @cOutField01 = @cID
         SET @cOutField02 = @cUCC
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cSuggestSKU
         SET @cOutField05 = @cSKU
         SET @cOutField06 = SUBSTRING( @cSKUDesc, 1, 20)
         SET @cOutField07 = SUBSTRING( @cSKUDesc, 21, 20)
         SET @cOutField08 = '' -- PieceScanQTY

         -- Go back to SKU screen
         SET @nScn  = @nScn  - 3
         SET @nStep = @nStep - 3
      END

      -- Go to next ID
      IF @cNextSKU = ''
      BEGIN
         IF @cUCC <> ''
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- UCC
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID

         -- Prepare next screen variable
         SET @cUCC = ''
         SET @cID = ''
         SET @cLOC = ''
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''

         -- Go back to ID screen
         SET @nScn  = @nScn  - 4
         SET @nStep = @nStep - 4
      END

      -- (james14)
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cFacility, ' +
               ' @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nAfterStep      INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 5, @nStep, @nInputKey, @cStorer, @cFacility,
               @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT

            SET @cOutfield15 = @cExtendedInfo1
         END
      END
   END
END
GOTO Quit


/********************************************************************************
Step 6. Scn = 2885.
   LOC not match. Proceed?
   1 = YES
   2 = NO
   OPTION (Input, Field01)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 73883
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Option req
         GOTO Quit
      END

      -- Check optin valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 73884
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cFromLOC, @cFromID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
        '@nQty            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility,
               @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @cOption = '1' -- YES
      BEGIN
         IF @cPABySKUAndLOT = '1'
            SET @cByLOT = @cLOT
         ELSE
            SET @cByLOT = ''

         -- Putaway
         EXEC rdt.rdt_PutawayBySKU_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cStorer, @cFacility,
            @cByLOT,
            @cLOC,
            @cID,
            @cSKU,
            @nQTY,
            @cFinalLoc,
            @cSuggestedLOC,
            @cLabelType,
            @cUCC,
            @nPABookingKey OUTPUT,
            @nErrNo        OUTPUT,
            @cErrMsg       OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Go to successful putaway screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         GOTO Quit
      END
   END

   -- Prepare next screen var
   SET @cOutField01 = @cSuggestedLOC
   SET @cOutField02 = '' -- FinalLOC
   SET @cOutField03 = @cQTY_Avail
   SET @cOutField04 = @cQTY_Alloc
   SET @cOutField05 = @cQTY_PMoveIn
   SET @cOutfield15 = '' -- ExtInfo

   -- Go to suggested LOC screen
   SET @nScn = @nScn - 2
   SET @nStep = @nStep - 2

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo1 = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cFacility, ' +
            ' @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nAfterStep      INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cLOC            NVARCHAR( 10), ' +
            '@cID             NVARCHAR( 18), ' +
            '@cSKU            NVARCHAR( 20), ' +
            '@nQTY            INT,           ' +
            '@cSuggestedLOC   NVARCHAR( 10), ' +
            '@cFinalLOC       NVARCHAR( 10), ' +
            '@cOption         NVARCHAR( 1),  ' +
            '@cExtendedInfo1  NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cStorer, @cFacility,
            @cLOC, @cID, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @cOption, @cExtendedInfo1 OUTPUT

         SET @cOutfield15 = @cExtendedInfo1
      END
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
Step_7:
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
         @cStorer,
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
      SELECT @cSKUDesc = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU
   END

   -- Init next screen var
   SET @cOutField01 = @cID
   SET @cOutField02 = @cUCC
   SET @cOutField03 = @cLOC
   SET @cOutField04 = @cSuggestSKU
   SET @cOutField05 = @cSKU
   SET @cOutField06 = SUBSTRING( @cSKUDesc, 1, 20)
   SET @cOutField07 = SUBSTRING( @cSKUDesc, 21, 20)
   SET @cOutField08 = '' -- PieceScanQTY

   -- Go to SKU screen
   SET @nScn = @nFromScn
   SET @nStep = @nStep - 5

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
      Func = @nFunc,
      Step = @nStep,
      Scn = @nScn,

      Facility  = @cFacility,
      StorerKey = @cStorer,

      V_ID       = @cID,
      V_LOC      = @cLOC,
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDesc,
      V_UOM      = @cPUOM,
      V_LOT      = @cLOT,
      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_UCC        = @cUCC,

      V_String1  = @cSuggestSKU,
      V_String2  = @cSuggestedLOC,
      V_String3  = @cFinalLOC,
      V_String4  = @cMUOM_Desc,
      V_String5  = @cPUOM_Desc,
      V_String6  = @cLabelType,
      V_String7  = @cQTY_Avail,
      V_String8  = @cQTY_Alloc,
      V_String9  = @cQTY_PMoveIn,
      V_String11 = @cSKUBarcode,
      V_String12 = @cFlowThruQtyScn,
      V_String13 = @cPieceScanSKU,      

      V_PUOM_Div = @nPUOM_Div ,
      V_PQTY     = @nPQTY,
      V_MQTY     = @nMQTY,

      V_Integer1 = @nPQTY_PWY ,
      V_Integer2 = @nMQTY_PWY ,
      V_Integer3 = @nQTY_PWY,
      V_Integer4 = @nQTY,
      V_Integer5 = @nRec,
      V_Integer6 = @nTotalRec,
      V_Integer7 = @nPABookingKey,
      V_Integer8 = @nPieceScanQTY,

      V_String20 = @cPASuggestSKU,
      V_String21 = @cPABySKUAndLOT,
      V_String22 = @cDecodeLabelNo,
      V_String23 = @cToLOCLookupSP,
      V_String24 = @cExtendedUpdateSP,
      V_String25 = @cExtendedValidateSP,
      V_String26 = @cExtendedInfoSP,
      V_String27 = @cPAMatchSuggestLOC,
      V_String28 = @cPAMatchQTY,
      V_String29 = @cDefaultQTY,
      V_String30 = @cDefaultSuggestSKU,
      V_String31 = @cDecodeSP,
      V_String32 = @cSKUStatus,  -- (james10)
      V_String33 = @cLOCLookupSP,  -- (yeekung02)
      V_String34 = @nFromScn,    -- (yeekung03)
      V_String35 = @cMultiSKUBarcode, --(yeekung03)
      V_String38 = @cPieceScan,

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
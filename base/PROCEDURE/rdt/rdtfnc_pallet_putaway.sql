SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_Pallet_Putaway                                     */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2009-10-28 1.0  James    Created                                           */
/* 2010-01-06 1.1  ChewKP   SOS#157089 TM Insert PA Task (ChewKP01)           */
/* 2010-02-23 1.2  Vicky    Add DB pointing to LotxLocxID table and           */
/*                          take out debug (Vicky01)                          */
/* 2010-02-25 1.3  ChewKP   Add in Error MSG (ChewKP02)                       */
/* 2010-02-26 1.4  Shong    Hardcode the DB Name (Shong01)                    */
/* 2010-03-03 1.5  Vicky    Prevent same different Pallet from going to       */
/*                          the same P&D at the same time (Vicky02)           */
/* 2010-03-10 1.6  Vicky    Change error message from No Sugg Loc to          */
/*                          No Avail Loc (Vicky03)                            */
/* 2010-03-17 1.7  Vicky    Add validation - Pallet should not have           */
/*                          allocated/ picked QTY (Vicky04)                   */
/* 2010-06-01 1.8  ChewKP   Add Additional Parameters to rdt_TMTask           */
/*                          (ChewKP03)                                        */
/* 2010-06-09 1.9  ChewKP   Proj Diana SOS#175735  (ChewKP04)                 */
/* 2010-06-17 2.0  Vicky    Prompt Error when the same Pallet ID exists       */
/*                          in TaskDetail to prevent duplicate PA task        */
/*                          (Vicky05)                                         */
/* 2010-07-19 2.1  ChewKP  Fixed Bugs on variables (ChewKP05)                 */
/* 2010-07-19 2.2  Vicky    In Transit Loc is to be retrieved from PPA        */
/*                          Putawayzone, InLOC field (Vicky06)                */
/* 2010-07-22 2.3  ChewKP   Add in TraceInfo (ChewKP06)                       */
/* 2010-07-22 2.4  ChewKP   Prompt Error when BOM > 1 SKU (ChewKP07)          */
/* 2010-07-22 2.5  Vicky    SEE_SUPV message should be prompt (Vicky07)       */
/* 2010-07-26 2.6  ChewKP   Re-arrange of rdt_tmtask parameter pass in        */
/*                          (ChewKP08)                                        */
/* 2010-07-26 2.7  Vicky    Add validation on 1 Pallet Multi SKU for          */
/*                          BOM (Vicky08)                                     */
/* 2010-08-20 2.8  ChewKP   Remove InTransitLoc Checking (ChewKP09)           */
/* 2010-09-13 2.9  ChewKP   Enhancement cater for PendingMovein Update        */
/*                          (ChewKP10)                                        */
/* 2011-05-09 3.0  James    SOS214021 - Extra validation on tote              */
/*                                      (james01)                             */
/* 2011-07-06 3.1  James    SOS220147 - Bug fix (james02)                     */
/* 2012-07-06 3.2  TLTING   Performance Tune step 5                           */
/* 2012-08-09 3.3  Ung      Performance Tune step 5 (ung01)                   */
/* 2011-09-20 3.2  Shong    SOS224116 - SkipJack Project (Shong001)           */
/* 2011-10-14 3.3  ChewKP   SkipJack Changes - ID cannot be blank             */
/*                          ID cannot exist > 1 Loc (ChewKP11)                */
/* 2011-11-03 3.5  Shong    For Pack Size > 2, GOTO LPN# Screen SHONG002      */
/* 2011-11-03 3.6  Shong    Fix logic for multi sku/lot putaway(james03)      */
/* 2012-01-26 3.7  Shong    Update UCC Loc CombLastCtnPutaway is Off          */
/* 2012-02-21 3.8  ChewKP   Update UCC.ID to blank only when LoseID is        */
/*                          turn on (ChewKP12)                                */
/* 2012-02-23 3.9  Shong03  Calling RDTPASTD with Last Carton Qty             */
/* 2012-03-06 4.0  Shong04  Fixing Lose ID Issues, UCC Not updated            */
/* 2012-04-02 4.1  James    SOS240530 - Prevent same suggested loc            */
/*                          locked by multi user (james03)                    */
/* 2012-04-26 4.2  Shong    Add Missing Update LoseID on UCC                  */
/* 2012-06-13 4.3  Ung      SOS240955 Add dimention restriction               */
/*                          17-Fit by UCC cube (ung01)                        */
/* 2013-04-02 4.4  James    Bug fix (james04)                                 */
/* 2014-08-21 4.5  Ung      SOS318058 Fix PendingMoveIn unlock                */
/* 2014-10-21 4.6  Ung      SOS323389 Fix PendingMoveIn reset if putaway twice*/
/* 2015-02-06 4.7  Ung      SOS332294 Add ExtendedInfoSP                      */
/* 2015-07-31 4.8  James    SOS348695 Enhance on create TM PA task (james05)  */
/* 2016-09-30 4.9  Ung      Performance tuning                                */
/* 2018-06-05 5.0  James    WMS5310-Add rdt_decode sp (james06)               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_Pallet_Putaway] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Other var use in this stor proc
DECLARE
   @b_Success         INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR( 250),
   @c_outstring       NVARCHAR( 255), 
   @cSQL              NVARCHAR( MAX),
   @cSQLParam         NVARCHAR( MAX)
   
-- Variable for RDT.RDTMobRec
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nCurScn    INT,  -- Current screen variable
   @nStep      INT,
   @nCurStep   INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerkey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cPrinter   NVARCHAR( 10),
   @cUserName  NVARCHAR( 18),

   @cLOC            NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @cUOM            NVARCHAR( 10),
   @cID             NVARCHAR( 18),
   @cLOT            NVARCHAR( 10),
   @nSUM_PALog      INT,      -- (james02)
   @cLoseID         NVARCHAR(1),  -- (shong04)
   @cExtendedInfoSP NVARCHAR( 20),
   @cExtendedInfo1  NVARCHAR( 20),
   @cFinalLOC       NVARCHAR( 20),

   @cExtendedValidateSP       NVARCHAR( 20),    -- (james05)
   @cExtendedPPAPutawaySP     NVARCHAR( 20),    -- (james05)
   @nAfterStep                INT, 
   @nAfterScn                 INT,
   @nSKUCnt                   INT,
   @cDecodeSP                 NVARCHAR( 20),
   @cBarcode                  NVARCHAR( 60),

   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),
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
   @cPackKey            NVARCHAR( 10),
   @nRecCnt             INT,
   @nQTY                INT,
   @cPackUOM3           NVARCHAR( 10),
   @nPutAwayQty         INT,
   @cFromLOC            NVARCHAR( 10),
   @cToLOC              NVARCHAR( 10),
   @cSuggestedLOC       NVARCHAR( 10),
   @cDescr1             NVARCHAR( 20),
   @cDescr2             NVARCHAR( 20),
   @cPUOM               NVARCHAR( 10),
   @nTranCount          INT,
   @c_TMPATask          NVARCHAR(1),       -- SOS#157089
   @cPickAndDropLoc     NVARCHAR(10),      -- SOS#157089
   @c_taskdetailkey1    NVARCHAR(10),    -- SOS#157089
   @c_taskdetailkey2    NVARCHAR(10),     -- SOS#157089
   @c_packkey           NVARCHAR(10),
   @c_ParentSKU         NVARCHAR(20),
   @n_CaseCnt           INT,
   @n_TotalPalletQTY    INT,
   @n_TotalBOMQTY       INT,
   @c_PutawayRules01    NVARCHAR(1),    -- (ChewKP04)
   @c_IDSKU             NVARCHAR(20),   -- (ChewKP04)
   @c_LocationType      NVARCHAR(10),   -- (ChewKP04)
   @cDropID             NVARCHAR(20),   -- (ChewKP04)
   @nLocQTY             INT,        -- (ChewKP04)
   @c_PickByCase        NVARCHAR(1),    -- (ChewKP04)
   @nCaseQty            INT,        -- (ChewKP04)
   @c_CaseID            NVARCHAR(10),  -- (ChewKP04)
   @c_ComponentSKU      NVARCHAR(20),   -- (ChewKP04)
   @c_PieceLoc          NVARCHAR(10),   -- (ChewKP04)
   @n_SKUxLocQTY   INT,        -- (ChewKP04)
   @c_BOMSKU            NVARCHAR(20),   -- (ChewKP04)
   @n_QtyCount          INT,        -- (ChewKP04)
   @c_SKULocSKU         NVARCHAR(20),   -- (ChewKP04)
   @n_PutawayCaseCount  INT,        -- (ChewKP04)
   @n_PTCSCount         INT,        -- (ChewKP04)
   @c_PutawayZone       NVARCHAR(10),   -- (ChewKP04)
   @c_IDLot             NVARCHAR(10),   -- (ChewKP04)
   @c_WCSKey            NVARCHAR(10),   -- (ChewKP04)
   @c_PrePackByBOM      NVARCHAR(1),    -- (ChewKP04)
   @c_CompoenentSKU     NVARCHAR(20),   -- (ChewKP04)
   @c_VirtualLoc        NVARCHAR(10),   -- (ChewKP04)
   @n_LocationLimit     INT,        -- (ChewKP04)
   @n_MaxCaseCnt        INT,        -- (ChewKP04)
   @c_ToLocCheck        NVARCHAR(1),    -- (ChewKP04)
   @c_Lot               NVARCHAR(10),   -- (ChewKP04)
   @n_BOMQTY            INT,        -- (ChewKP04)
   @c_PASKU             NVARCHAR(20),   -- (ChewKP04),
   @c_PALot             NVARCHAR(10),   -- (ChewKP04),
   @c_PAUOM             NVARCHAR(10),   -- (ChewKP04),
   @c_PASourcekey       NVARCHAR(30),   -- (ChewKP04),
   @c_PACaseID          NVARCHAR(10),   -- (ChewKP04),
   @n_PAQty             INT,        -- (ChewKP04),
   @c_PAID              NVARCHAR( 18),  -- (ChewKP04),
   @c_PALoc             NVARCHAR( 10),  -- (ChewKP04),
   @c_PAPackkey         NVARCHAR( 10),  -- (ChewKP04),
   @n_BOMCheck          INT,        -- (ChewKP06)
   @cNotMultiBOMSKUPlt  NVARCHAR( 1),   -- (Vicky08)
   @n_RFQty             INT ,       -- (ChewKP10)
   @c_RFLoc             NVARCHAR(10),   -- (ChewKP10)
   @c_RFLot             NVARCHAR(10),   -- (ChewKP10)
   @c_RFSKU             NVARCHAR(20),   -- (ChewKP10)
   @c_RFID              NVARCHAR(18),   -- (ChewKP10)
   @c_RFStorerkey       NVARCHAR(10),   -- (ChewKP10)
   @n_RFPendingMoveIN   INT         -- (ChewKP10)

DECLARE @cDefaultCaseLength      NVARCHAR( 1)   -- (james01)

-- (Shong001)
DECLARE @cCombLastCtnPutaway   NVARCHAR(1)
       ,@cPalletType           NVARCHAR(30) -- 1_Lot_CartonSize, 1_Lot_2CartonSize, Mixed_Lot_CartonSize
       ,@nNumberOfPackSize     INT
       ,@nNumberOfSKU          INT
       ,@cUCCNo                NVARCHAR(20)
       ,@nUCCQty               INT
       ,@cDisAllowOverrideLOC  NVARCHAR( 1)

-- ***For Testing Without Putaway Strategy*** ()---
DECLARE @b_debug INT
--SET @b_debug = 1

-- Getting Mobile information
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerkey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cLOC       = V_Loc,
   @cSKU       = V_SKU,
   @cUCCNo     = V_UCC, -- (Shong001)
   @cUOM       = V_UOM,
   @cID        = V_ID,
   @cLOT       = V_Lot,
   @nQty       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,

   @cPackKey   = V_String1,
   @cFromLOC   = V_String2,
   @cToLOC     = V_String3,
   @cPUOM      = V_String4,
   @cSuggestedLOC     = V_String5,
   @c_taskdetailkey1  = V_String6,
   @c_taskdetailkey2  = V_String7,
   @cPickAndDropLoc   = V_String8,
   @c_TMPATask        = V_String9,
   @c_PutawayRules01  = V_String10,
   @c_PickByCase      = V_String11,
   @nCaseQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12, 5), 0) = 1 THEN LEFT( V_String12, 5) ELSE 0 END,
   @c_PieceLoc        = V_String13,
   @c_BOMSKU          = V_String14,
   @c_ComponentSKU    = V_String15,
   @n_PutawayCaseCount = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16, 5), 0) = 1 THEN LEFT( V_String16, 5) ELSE 0 END,
   @n_PTCSCount       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String17, 5), 0) = 1 THEN LEFT( V_String17, 5) ELSE 0 END,
   @c_PrePackByBOM    = V_String18,
   @c_packkey         = V_String19,
   @c_VirtualLoc      = V_String20,
   @n_LocationLimit   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String21, 5), 0) = 1 THEN LEFT( V_String21, 5) ELSE 0 END,
   @c_ToLocCheck      = V_String22,
   @n_BOMQTY          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String23, 5), 0) = 1 THEN LEFT( V_String23, 5) ELSE 0 END,

   @cPalletType       = V_String24,  -- (Shong001)
   @nUCCQTY           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String25, 5), 0) = 1 THEN LEFT( V_String25, 5) ELSE 0 END,
   @cExtendedInfoSP   = V_String26,
   @cExtendedInfo1    = V_String27,
   @cFinalLOC         = V_String28,
   @cDecodeSP         = V_String29,
   
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

FROM RDT.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nStep = 0 GOTO Step_0   -- Func = 522. Menu
IF @nStep = 1 GOTO Step_1   -- Scn  = 936. Look up for Inventory
IF @nStep = 2 GOTO Step_2   -- Scn  = 937. Putaway
IF @nStep = 3 GOTO Step_3   -- Scn  = 938. Suggested LOC, ToLOC
IF @nStep = 4 GOTO Step_4   -- Scn  = 939. Msg
IF @nStep = 5 GOTO Step_5   -- Scn  = 940. SKU    --> This Screen Control By Configkey PAByCase -- (ChewKP04)
IF @nStep = 6 GOTO Step_6   -- Scn  = 941. CASEID --> This Screen Control By Configkey PAByCase -- (ChewKP04)
IF @nStep = 7 GOTO Step_7   -- Scn  = 942. LPN#   --> This Screen Control By ConfigKey CombLastCtnPutaway -- (Shong001)

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 522. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- (Vicky06) EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerkey  = @cStorerkey

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Storer config
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   -- reset all output
   SET @cID    = ''
   SET @cFromLOC   = ''
   SET @cSKU = ''
   SET @cLOT = ''
   SET @cToLOC = ''

   -- Init screen
   SET @cOutField01 = '' -- ID
   SET @cOutField02 = @cStorerkey -- StorerKey
   SET @cOutField03 = '' -- FROM LOC

   -- Set the entry point
   SET @nScn = 936
   SET @nStep = 1
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 936
   ID
   Storer
   LOC
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cID = @cInField01
      SET @cFromLOC = @cInField03
      SET @cSKU = ''
      SET @cBarcode = @cInField01

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cID     = @cID     OUTPUT, 
               @cUPC    = @cSKU    OUTPUT, 
               @nQTY    = @nQTY    OUTPUT, 
               @nErrNo  = @nErrNo  OUTPUT, 
               @cErrMsg = @cErrMsg OUTPUT,
               @cType   = 'ID'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cFromID  OUTPUT, @cFromLOC    OUTPUT, @cToLOC   OUTPUT, @cSKU  OUTPUT, ' +
               ' @nErrNo   OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, 
               @cID         OUTPUT, @cFromLOC    OUTPUT, @cToLOC       OUTPUT, @cSKU        OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Quit
      END
      
      IF @cStorerkey = 'ALL' -- SOS#157089
      BEGIN
         IF EXISTS (SELECT 1 from dbo.LotxLocXID (NOLOCK) WHERE ID = @cID AND Qty > 0
                    GROUP BY Storerkey, ID
                    HAVING COUNT (DISTINCT ID) > 1   )
         BEGIN
            SET @nErrNo = 50033
            SET @cErrMsg = rdt.rdtgetmessage( 50033, @cLangCode, 'DSP') --INVALID STORER
            GOTO Quit
         END

         SELECT @cStorerkey = Storerkey from dbo.LotxLocXID (NOLOCK) WHERE ID = @cID
                AND QTY > 0

         IF ISNULL(@cStorerkey, '')  = ''
         BEGIN
            SET @nErrNo = 50037
            SET @cErrMsg = rdt.rdtgetmessage( 50037, @cLangCode, 'DSP') --INVALID STORER
            SET @cStorerkey = 'ALL'
            GOTO Quit
         END
      END

      -- SOS#157089 Generate 2 Putaway Task for Task Manager dbo.TaskDetail(Start) --
      SET @c_TMPATask = rdt.RDTGetConfig( @nFunc, 'CreatePATask', @cStorerkey)

      -- (Vicky08)
      SET @cNotMultiBOMSKUPlt = rdt.RDTGetConfig( @nFunc, 'NotAllowMultiCompSKUPLT', @cStorerkey)
      IF ISNULL(@cID, '') = ''
      BEGIN

         SET @nErrNo = 50021
         SET @cErrMsg = rdt.rdtgetmessage( 50021, @cLangCode, 'DSP') --PLT ID req
         SET @cID = ''
         SET @cOutField01 = ''

         IF @c_TMPATask = 1
            SET @cOutField02 = 'ALL'
         ELSE
            SET @cOutField02 = @cStorerkey

         SET @cOutField03 = @cFromLOC
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK) WHERE ID = @cID AND Qty > 0 )
      BEGIN
         SET @nErrNo = 50022
         SET @cErrMsg = rdt.rdtgetmessage( 50022, @cLangCode, 'DSP') --Invalid ID
         SET @cID = ''
         SET @cOutField01 = ''
         IF @c_TMPATask = 1
            SET @cOutField02 = 'ALL'
         ELSE
            SET @cOutField02 = @cStorerkey

         SET @cOutField03 = @cFromLOC
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- (Vicky04) - Start
      IF EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK) WHERE ID = @cID
                 HAVING (SUM(QTYALLOCATED) > 0) OR (SUM(QTYPICKED) > 0))
      BEGIN
         SET @nErrNo = 50048
         SET @cErrMsg = rdt.rdtgetmessage( 50048, @cLangCode, 'DSP') --IDHasAllocOrPickQty
         SET @cID = ''
         SET @cOutField01 = ''
         IF @c_TMPATask = 1
            SET @cOutField02 = 'ALL'
         ELSE
            SET @cOutField02 = @cStorerkey

         SET @cOutField03 = @cFromLOC
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END
      -- (Vicky04) - End

      -- (ChewKP11)
      IF ISNULL(@cID, '') <> ''
      BEGIN
         IF EXISTS (SELECT 1 FROM LotxLocxID WITH (NOLOCK)
                    WHERE Storerkey = @cStorerkey
                    AND ID =  @cID
                    AND Qty > 0
                    HAVING COUNT (DISTINCT LOC) > 1 )
         BEGIN
            SET @nErrNo = 50092
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID in >1 Loc
            SET @cID = ''
            SET @cOutField01 = ''

            IF @c_TMPATask = 1
               SET @cOutField02 = 'ALL'
            ELSE
               SET @cOutField02 = @cStorerkey

            SET @cOutField03 = @cFromLOC
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit

         END
      END

      -- (Vicky08) - Start
      IF @cNotMultiBOMSKUPlt = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)
                    WHERE ID = @cID
                    AND Storerkey = @cStorerkey
                    AND QTY > 0
               HAVING COUNT(DISTINCT SKU) > 1)
         BEGIN
            SET @nErrNo = 50073
            SET @cErrMsg = rdt.rdtgetmessage( 50073, @cLangCode, 'DSP') --PLTHasMultiSKU
            SET @cID = ''
            SET @cOutField01 = ''
            SET @cOutField02 = @cStorerkey

            SET @cOutField03 = @cFromLOC
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
      END
      -- (Vicky08) - End

      IF @c_TMPATask = '1'
      BEGIN
         IF ISNULL(@cFromLOC, '') = ''
         BEGIN
            SET @nErrNo = 50039
            SET @cErrMsg = rdt.rdtgetmessage( 50039, @cLangCode, 'DSP') --INVALID LOC
            SET @cFromLOC = ''
            SET @cOutField01 = @cID
            SET @cOutField02 = 'ALL'
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- (Vicky05) - Start
         IF EXISTS (SELECT 1 FROM dbo.TASKDETAIL WITH (NOLOCK) WHERE FROMID = @cID AND TaskType = 'PA')
         BEGIN
            SET @nErrNo = 50061
            SET @cErrMsg = rdt.rdtgetmessage( 50039, @cLangCode, 'DSP') --PutawayDoneB4
            SET @cFromLOC = ''
            SET @cOutField01 = ''
            SET @cOutField02 = 'ALL'
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
         -- (Vicky05) - End
      END

      -- (ChewKP11)
      IF ISNULL(@cFromLOC, '' ) = ''
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'IDAutoRetrieveFromLOC', @cStorerkey) = 1
         BEGIN
            SELECT @cFromLOC = LOC
            FROM dbo.LOTxLOCxID WITH (NOLOCK)
            WHERE Storerkey = @cStorerkey
            AND   ID =  @cID
            AND   Qty > 0

            IF ISNULL(@cFromLOC, '' ) <> ''
            BEGIN
               SET @cOutField01 = @cID
               SET @cOutField02 = CASE WHEN @c_TMPATask = 1 THEN 'ALL' ELSE @cStorerkey END  -- (james04)
               SET @cOutField03 = @cFromLOC
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Quit
            END
         END

         SET @nErrNo = 50091
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLoc Req
         SET @cFromLOC = ''
         SET @cOutField01 = ''
         SET @cOutField02 = CASE WHEN @c_TMPATask = 1 THEN 'ALL' ELSE @cStorerkey END  -- (james04)
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      IF ISNULL(@cFromLOC, '') <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFromLOC)
         BEGIN
            SET @nErrNo = 50023
            SET @cErrMsg = rdt.rdtgetmessage( 50023, @cLangCode, 'DSP') --Invalid LOC
            SET @cFromLOC = ''
            SET @cOutField01 = @cID
            IF @c_TMPATask = 1
               SET @cOutField02 = 'ALL'
            ELSE
               SET @cOutField02 = @cStorerkey

            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFromLOC AND Facility = @cFacility)
         BEGIN
            SET @nErrNo = 50024
            SET @cErrMsg = rdt.rdtgetmessage( 50024, @cLangCode, 'DSP') --Wrong facility
            SET @cFromLOC = ''
            SET @cOutField01 = @cID
            IF @c_TMPATask = 1
               SET @cOutField02 = 'ALL'
            ELSE
               SET @cOutField02 = @cStorerkey

            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO QUIT
         END
      END  -- ISNULL(@cFromLOC, '') <> ''

      ---- Extended validate (james05)
      --SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      --IF @cExtendedValidateSP = '0'  
      --   SET @cExtendedValidateSP = ''

      --IF ISNULL( @cExtendedValidateSP, '') <> ''
      --BEGIN
      --   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
      --   BEGIN
      --      SET @nErrNo = 0
      --      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
      --         ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFacility, @cID, @cFromLOC, @cSKU, @nQTY, @cSuggestedLOC, @cToLOC, @cPickAndDropLOC, @cFinalLOC, ' +
      --         ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
      --      SET @cSQLParam =
      --         '@nMobile         INT,           ' +
      --         '@nFunc           INT,           ' +
      --         '@cLangCode       NVARCHAR( 3),  ' +
      --         '@nStep           INT,           ' +
      --         '@nAfterStep      INT            ' +
      --         '@nInputKey       INT,           ' +
      --         '@cStorerKey      NVARCHAR( 15), ' +
      --         '@cFacility       NVARCHAR( 5),  ' +
      --         '@cID             NVARCHAR( 18), ' +
      --         '@cFromLOC        NVARCHAR( 10), ' +
      --         '@cSKU            NVARCHAR( 20), ' +
      --         '@nQTY            INT,           ' +
      --         '@cSuggestedLOC   NVARCHAR( 10), ' +
      --         '@cToLOC          NVARCHAR( 10), ' +
      --         '@cPickAndDropLOC NVARCHAR( 10), ' +
      --         '@cFinalLOC       NVARCHAR( 10), ' +
      --         '@nErrNo          INT           OUTPUT, ' +
      --         '@cErrMsg         NVARCHAR( 20) OUTPUT  ' 

      --      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      --         @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cStorerKey, @cFacility, @cID, @cFromLOC, @cSKU, @nQTY, @cSuggestedLOC, @cToLOC, @cPickAndDropLOC, @cFinalLOC, 
      --         @nErrNo OUTPUT, @cErrMsg OUTPUT

      --      IF @nErrNo <> 0
      --         GOTO Quit
      --   END
      --END
      
      -- If PickByCase Storerconfig turn on
      SET @c_PickByCase = rdt.RDTGetConfig( @nFunc, 'PAByCase', @cStorerkey) -- (ChewKP04)

      IF  @c_PickByCase = '1'
      BEGIN
         SET @cSKU = ''
         GOTO NORMALDISPLAY
      END

      IF @c_TMPATask = '1'
      BEGIN
         SELECT DISTINCT @c_packkey = U.Packkey , @c_ParentSKU = U.SKU FROM dbo.LOTxLOCxID LO (NOLOCK)
         INNER JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON LA.LOT = LO.LOT
         INNER JOIN dbo.UPC U (NOLOCK) ON LA.Lottable03 = U.SKU
         WHERE LO.ID = @cID
         AND LO.Storerkey = @cStorerkey
         AND U.UOM = 'CS'

         IF ISNULL(@c_ParentSKU,'') = ''
         BEGIN
            SET @cSKU = ''
            GOTO NORMALDISPLAY
         END
         ELSE
         BEGIN
            IF ISNULL(@c_packkey,'') = ''
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( 50040, @cLangCode, 'DSP') --NO PACKKEY
               SET @cFromLOC = ''
               SET @cOutField01 = @cID
               SET @cOutField02 = 'ALL'
               SET @cOutField03 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2
            END
            ELSE
            BEGIN
               SELECT @n_CaseCnt = CaseCnt, @cUOM = PackUOM1 FROM dbo.PACK (NOLOCK)
               WHERE PACKKEY = @c_packkey

               SELECT @n_TotalPalletQTY = SUM(QTY) FROM dbo.LOTxLOCxID (NOLOCK)
               WHERE ID = @cID
               AND STORERKEY = @cStorerkey

               SELECT @n_TotalBOMQTY = SUM(QTY)  FROM dbo.BILLOFMATERIAL (NOLOCK) -- (ChewKP01)
               WHERE SKU = @c_ParentSKU
               AND STORERKEY = @cStorerkey

               SELECT @cDescr1 = SUBSTRING(DESCR, 1, 20),  @cDescr2 = SUBSTRING(DESCR,21, 20)
               FROM dbo.SKU (NOLOCK)
               WHERE SKU = @c_ParentSKU
               AND STORERKEY = @cStorerkey

               SET @nCaseQty = 0

               SET @nCaseQty = (@n_TotalBOMQTY * @n_CaseCnt)

               SET @cSKU = @c_ParentSKU
               SET @nQTY = @n_TotalPalletQTY / (@n_TotalBOMQTY * @n_CaseCnt) -- (Vicky05)
               SET @cPackKey = @c_packkey
            END
         END
      END  -- @c_TMPATask = '1'

      /**************************************************/
      -- If RDT User exists in the RFPutaway
      -- 1. Delete From RFPutaway Table
      -- 2. Deduct Pending Move in from LotxLocxID
      -- (ChewKP10) Start
      /**************************************************/
    --SET @cLot = ''
         SET @n_RFQty = 0

         SET @c_RFLoc = ''
         SET @c_RFLot = ''
         SET @c_RFSKU = ''
         SET @c_RFID = ''
         SET @c_RFStorerkey = ''

         DECLARE curPending CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

         SELECT   Qty
                , SuggestedLoc
                , Lot
                , SKU
                , ID
                , Storerkey
         FROM dbo.RFPutaway WITH (NOLOCK)
         WHERE ID = @cID
            AND FromLOC = @cFromLOC

         OPEN curPending
         FETCH NEXT FROM curPending INTO @n_RFQty, @c_RFLoc, @c_RFLot, @c_RFSKU, @c_RFID, @c_RFStorerkey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF EXISTS (SELECT 1 FROM LotxLocxID WITH (NOLOCK)
            WHERE Loc = @c_RFLoc
            AND Lot = @c_RFLot
            AND SKU = @c_RFSKU
            AND ID = @c_RFID
            AND Storerkey = @c_RFStorerkey)
            BEGIN
               BEGIN TRAN

               UPDATE dbo.LotxLocxID WITH (ROWLOCK)
                     SET PendingMoveIn = CASE WHEN PendingMoveIn - @n_RFQty > 0 THEN PendingMoveIn - @n_RFQty
                                         ELSE 0
                                         END
               WHERE Lot = @c_RFLot
                     AND SKU = @c_RFSKU
                     AND Loc = @c_RFLoc
                     AND ID  = @c_RFID
                     AND Storerkey = @c_RFStorerkey

               IF @@Error <> 0    
               BEGIN    
                  SET @nErrNo = 50083     
                  SET @cErrMsg = rdt.rdtgetmessage( 50083, @cLangCode, 'DSP') --50083^UPD LLI FAIL    
                  ROLLBACK TRAN    
               END    
               ELSE    
               BEGIN    
                  COMMIT TRAN    
               END    
               
               BEGIN TRAN      
               DELETE dbo.RFPUTAWAY WITH (ROWLOCK)    
               WHERE Lot = @c_RFLot
                      AND SKU = @c_RFSKU
                      AND SuggestedLoc = @c_RFLoc
                      AND ID  = @c_RFID
                      AND Storerkey = @c_RFStorerkey
                      
               IF @@Error <> 0    
               BEGIN    
                  SET @nErrNo = 50082    
                  SET @cErrMsg = rdt.rdtgetmessage( 50082, @cLangCode, 'DSP') --50082^UPD RPA FAIL    
                  ROLLBACK TRAN    
               END    
               ELSE    
               BEGIN    
                  COMMIT TRAN    
               END
         END
         FETCH NEXT FROM curPending INTO @n_RFQty, @c_RFLoc, @c_RFLot, @c_RFSKU, @c_RFID, @c_RFStorerkey
      END
      CLOSE curPending
      DEALLOCATE curPending
      /**************************************************/
      -- (ChewKP10) End
      /**************************************************/

      -- PERFORM Normal Display --
      NORMALDISPLAY:

      IF @c_PickByCase = '1'
      BEGIN
         SET  @cPUOM = '6'
      END

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         IF ISNULL(@cFromLOC, '') <> ''
         BEGIN
            SELECT
               @cSKU = L.SKU,
               @nQty = SUM(L.Qty - L.QtyPicked - QtyAllocated),
               @cPackKey = S.PackKey,
               @cDescr1 = SUBSTRING(S.DESCR, 1, 20),
               @cDescr2 = SUBSTRING(S.DESCR,21, 20),
               @cUOM = CASE @cPUOM
               WHEN '1' THEN P.PackUOM4 -- Pallet
               WHEN '2' THEN P.PackUOM1 -- Carton
               WHEN '3' THEN P.PackUOM2 -- InnerPack
               WHEN '4' THEN P.PackUOM8 -- OtherUnit1
               WHEN '5' THEN P.PackUOM9 -- OtherUnit2
               WHEN '6' THEN P.PackUOM3 -- Each
               ELSE P.PackUOM3 END
            FROM dbo.LOTxLOCxID L (NOLOCK)
            JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = L.StorerKey AND S.SKU = L.SKU
            JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PackKey
            JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = L.LOC
            WHERE L.StorerKey = @cStorerkey
            AND LOC.Facility = @cFacility
            AND L.ID = @cID
            AND L.LOC = @cFromLOC
            AND L.Qty > 0
            GROUP BY L.SKU, S.PackKey, S.DESCR, P.PackUOM4,
            CASE @cPUOM
            WHEN '1' THEN P.PackUOM4 -- Pallet
            WHEN '2' THEN P.PackUOM1 -- Carton
            WHEN '3' THEN P.PackUOM2 -- InnerPack
            WHEN '4' THEN P.PackUOM8 -- OtherUnit1
            WHEN '5' THEN P.PackUOM9 -- OtherUnit2
            WHEN '6' THEN P.PackUOM3 -- Each
            ELSE P.PackUOM3 END
            HAVING SUM(L.Qty - L.QtyPicked - QtyAllocated) > 0
            ORDER BY L.SKU
         END
         ELSE
         BEGIN
            SELECT
               @cFromLOC = L.LOC,
               @cSKU = L.SKU,
               @nQty = SUM(L.Qty - L.QtyPicked - QtyAllocated),
               @cPackKey = S.PackKey,
               @cDescr1 = SUBSTRING(S.DESCR, 1, 20),
               @cDescr2 = SUBSTRING(S.DESCR,21, 20),
               @cUOM = CASE @cPUOM
               WHEN '1' THEN P.PackUOM4 -- Pallet
               WHEN '2' THEN P.PackUOM1 -- Carton
               WHEN '3' THEN P.PackUOM2 -- InnerPack
               WHEN '4' THEN P.PackUOM8 -- OtherUnit1
               WHEN '5' THEN P.PackUOM9 -- OtherUnit2
               WHEN '6' THEN P.PackUOM3 -- Each
               ELSE P.PackUOM3 END
            FROM dbo.LOTxLOCxID L (NOLOCK)
            JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = L.StorerKey AND S.SKU = L.SKU
            JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PackKey
            JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = L.LOC
            AND L.Qty > 0
            WHERE L.StorerKey = @cStorerkey
            AND LOC.Facility = @cFacility
            AND L.ID = @cID
            GROUP BY L.LOC, L.SKU, S.PackKey, S.DESCR, P.PackUOM4,
            CASE @cPUOM
            WHEN '1' THEN P.PackUOM4 -- Pallet
            WHEN '2' THEN P.PackUOM1 -- Carton
            WHEN '3' THEN P.PackUOM2 -- InnerPack
            WHEN '4' THEN P.PackUOM8 -- OtherUnit1
            WHEN '5' THEN P.PackUOM9 -- OtherUnit2
            WHEN '6' THEN P.PackUOM3 -- Each
            ELSE P.PackUOM3 END
            HAVING SUM(L.Qty - L.QtyPicked - QtyAllocated) > 0
            ORDER BY L.SKU
         END
      END

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @nErrNo = 50025
         SET @cErrMsg = rdt.rdtgetmessage( 50025, @cLangCode, 'DSP') --No REC found
         GOTO Quit
      END

      -- Prep next screen var
      SET @cOutField01 = @cID          --ID
      SET @cOutField02 = @cStorerkey   --StorerKey
      SET @cOutField03 = @cSKU         --SKU
      SET @cOutField04 = @cDescr1      --DESC 1
      SET @cOutField05 = @cDescr2      --DESC 2
      SET @cOutField06 = rdt.rdtConvUOMQty (@cStorerkey, @cSKU, @nQty, '6', @cPUOM) --Qty
      SET @cOutField07 = @cUOM         --UOM
      SET @cOutField08 = @cFromLOC     --FROM LOC
      SET @cOutField09 = ''            --TO LOC

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      SET @cToLOC = ''

      GOTO Quit
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
       @cStorerkey  = @cStorerkey

      --IF @c_TMPATask  = 1
      --   SET @cStorerkey = 'ALL'
      SELECT @cStorerkey = DefaultStorer FROM RDT.RDTUSER (NOLOCK)
      WHERE Username = @cUserName

      SET @cID        = ''
      SET @cFromLOC   = ''
      SET @cSKU = ''
      SET @cLOT = ''
      SET @cToLOC = ''

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- ID
      SET @cOutField03 = '' -- FROM LOC
   END
   GOTO Quit

END
GOTO Quit

/********************************************************************************
Step 2. Scn = 937
   ID
   Storer
   SKU
   QTY
   UOM
   LOC
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      --- GET STORERKEY FROM LOTXLOCXID ---
      SELECT @cStorerkey = Storerkey , @c_IDSKU = SKU
      From dbo.LOTxLOCxID (NOLOCK)
      WHERE ID = @cID
      AND   Qty > 0

      -- SOS#175735 Start Proj Diana Putaway Rules (ChewKP04) (Start) --
      IF @c_PickByCase = '1' -- Checking to Prompt Scan BOM SKU Screen (ChewKP04)
      BEGIN
         SET @c_SKULocSKU = ''

         SELECT @c_ComponentSKU = SKU , @c_Lot = Lot FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND ID = @cID
         AND LOC = @cFromLOC
         AND Qty > 0

         -- (james05)
         SET @cExtendedPPAPutawaySP = rdt.RDTGetConfig( @nFunc, 'ExtendedPPAPutawaySP', @cStorerkey)
         IF @cExtendedPPAPutawaySP = '0'  
            SET @cExtendedPPAPutawaySP = ''
   
         IF @cExtendedPPAPutawaySP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPPAPutawaySP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedPPAPutawaySP) +
                  ' @nMobile, @nFunc, @cLangCode, @nInputKey, @nStep, @nScn, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU,  
                    @nQty, @cCaseID, @nAfterStep OUTPUT, @nAfterScn OUTPUT, @cFinalLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile         INT, ' +
                  '@nFunc           INT, ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nInputKey       INT, ' +
                  '@nStep           INT, ' +
                  '@nScn            INT, ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFacility       NVARCHAR( 5),  ' +
                  '@cFromLOC        NVARCHAR( 10), ' +
                  '@cFromID         NVARCHAR( 18), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQty            INT,  ' +
                  '@cCaseID         NVARCHAR( 20), ' +
                  '@nAfterStep      INT           OUTPUT, ' +
                  '@nAfterScn       INT           OUTPUT, ' +                  
                  '@cFinalLoc       NVARCHAR( 10) OUTPUT, ' +
                  '@nErrNo          INT           OUTPUT, ' + 
                  '@cErrMsg         NVARCHAR( 20) OUTPUT'
                  
              
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nInputKey, @nStep, @nScn, @cStorerkey, @cFacility, @cFromLOC, @cID, @cSKU, 
                  @nQty, @c_CaseID, @nAfterStep OUTPUT, @nAfterScn OUTPUT, @cFinalLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
               
               IF @nErrNo <> 0 
                  GOTO Quit

               IF @nStep <> @nAfterStep AND @nScn <> @nAfterScn
               BEGIN
                  SET @cOutField01 = ''

                  -- Go to next screen
                  SET @nScn = @nAfterScn
                  SET @nStep = @nAfterStep

                  GOTO Quit
               END
            END
         END
         ELSE
         BEGIN
            SET @c_PieceLoc = '' -- (ChewKP05)

            SELECT @c_PieceLoc = Loc , @n_LocationLimit = QtyLocationLimit
            FROM dbo.SKUxLOC (NOLOCK) WHERE SKU = @c_ComponentSKU AND Storerkey = @cStorerkey AND Locationtype = 'PICK'

            IF ISNULL(@c_PieceLoc,'') = ''
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( 50053, @cLangCode, 'DSP') --NoPickLocAssign -- (Vicky06)
               SET @cFromLOC = ''
               SET @cOutField01 = @cID
               SET @cOutField02 = @cStorerkey
               SET @cOutField03 = @cFromLoc
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO QUIT
            END
            -- (Vicky06) - Start
            ELSE
            BEGIN
               SELECT @c_Putawayzone = Putawayzone FROM dbo.LOC WITH (NOLOCK)
               WHERE LOC = @c_PieceLoc
               AND   Facility = @cFacility

               SET @c_VirtualLoc = '' -- (ChewKP05)

               SELECT @c_VirtualLoc = InLoc FROM dbo.PutawayZone WITH (NOLOCK)
               WHERE Putawayzone = @c_Putawayzone
            END
                  -- (Vicky06) - End

            -- Start (ChewKP09)
            IF @c_VirtualLoc <> ''
            BEGIN
               SELECT @n_MaxCaseCnt = MAX(Pack.CaseCnt) FROM dbo.BillOfMaterial BOM (NOLOCK)
               INNER JOIN dbo.SKU SKU (NOLOCK) ON ( SKU.SKU = BOM.SKU AND SKU.Storerkey = BOM.Storerkey )
               INNER JOIN dbo.PACK PACK (NOLOCK) ON (PACK.PackKey = SKU.Packkey)
               WHERE BOM.ComponentSKU = @c_ComponentSKU
               AND BOM.Storerkey = @cStorerkey

               SET @n_PTCSCount = Round(ISNULL(@n_LocationLimit,0) / ISNULL(@n_MaxCaseCnt,0),0)

               SET @n_SKUxLocQTY = 0 -- (ChewKP05)

               SELECT @n_SKUxLocQTY = SUM(QTY) From dbo.SKUxLoc (NOLOCK)
               WHERE SKU = @c_ComponentSKU
               AND Storerkey = @cStorerkey
               AND Loc = @c_PieceLoc

               ---*** Check if Pick Location there is no QTY Left Only Show BOMSKU Screen ***---
               --IF NOT EXISTS (SELECT 1 FROM dbo.LotxLocxID (NOLOCK) WHERE SKU = @c_ComponentSKU AND Loc = @c_VirtualLoc AND Qty > 0 )
               IF NOT EXISTS (
                  SELECT 1
                  FROM   dbo.TaskDetail (NOLOCK)
                  WHERE  SKU = @c_ComponentSKU
                  AND    STATUS<>'9'
                  AND    TaskType = 'PA'
                  AND    Storerkey = @cStorerkey)
               BEGIN
                  IF ISNULL(@n_SKUxLocQty ,0)<=0
                  BEGIN
                     SET @cOutField01 = ''
                     -- Go to next screen
                     SET @nScn = @nScn+3
                     SET @nStep = @nStep+3

                     GOTO Quit
                  END
               END
            END --@c_VirtualLoc <> ''
        -- End (ChewKP09)
         END
      END
      
      PUTAWAY2BULK:
      SET @c_ToLocCheck = '0'
      -- SOS#175735 Start Proj Diana Putaway Rules (ChewKP04) (End) --

      -- If not continue from previous pallet (multi sku) putaway
      IF ISNULL(@cToLOC, '') = ''
      BEGIN
         RERUN_SP:
         SET @cCombLastCtnPutaway = rdt.RDTGetConfig( @nFunc, 'CombLastCtnPutaway', @cStorerkey) -- (Shong001)
         IF @cCombLastCtnPutaway = '1'
         BEGIN
            -- Shong03 Start
            SET @nNumberOfSKU = 0
            SET @nNumberOfPackSize = 0

            IF EXISTS(SELECT 1 FROM UCC WITH (NOLOCK) WHERE ID = @cID)
            BEGIN
               SELECT @nNumberOfSKU = COUNT(DISTINCT UCC.SKU + L.Lottable02),
                      @nNumberOfPackSize = COUNT(DISTINCT UCC.SKU + L.Lottable02 + CAST(Qty AS NVARCHAR(10)))
               FROM   UCC (NOLOCK)
               JOIN LOTATTRIBUTE l (NOLOCK) ON UCC.Lot = l.Lot AND l.StorerKey = @cStorerkey
               WHERE  UCC.StorerKey = @cStorerkey
               AND    UCC.Loc = @cFromLOC
               AND    UCC.ID = @cID

               IF @nNumberOfSKU > 1 OR @nNumberOfPackSize > 2 -- SHONG002
                  SET @cPalletType = 'Mixed_Lot_CartonSize'
               ELSE IF @nNumberOfSKU = 1 AND @nNumberOfPackSize = 2
                  SET @cPalletType = '1_Lot_2CartonSize'
               ELSE
                  SET @cPalletType = '1_Lot_CartonSize'

               IF @cPalletType = '1_Lot_2CartonSize'
               BEGIN
                  SELECT TOP 1
                     @nUCCQty = U.Qty
                  FROM   UCC U (NOLOCK)
                  JOIN LOTATTRIBUTE l (NOLOCK) ON U.Lot = L.Lot AND l.StorerKey = @cStorerkey
                  WHERE  U.StorerKey = @cStorerkey
                  AND    U.SKU = @cSKU
                  AND    U.Loc = @cFromLOC
                  AND    U.ID = @cID
                  ORDER BY QTY ASC

                  SET @nQTY = @nUCCQty
               END
               -- Shong03 End
            END

            --(ung01)
            IF @cPalletType = '1_Lot_2CartonSize'
               EXEC @n_err = [dbo].[nspRDTPASTD]
                    @c_userid        = 'RDT'          -- NVARCHAR(10)
                  , @c_storerkey     = @cStorerkey    -- NVARCHAR(15)
                  , @c_lot           = ''             -- NVARCHAR(10)
                  , @c_sku           = @cSKU            -- NVARCHAR(20)
                  , @c_id            = @cID           -- NVARCHAR(18)
                  , @c_fromloc       = @cFromLOC      -- NVARCHAR(10)
                  , @n_qty           = @nQTY          -- int
                  , @c_uom           = @cUOM          -- NVARCHAR(10)
                  , @c_packkey       = @cPackKey      -- NVARCHAR(10) -- optional
                  , @n_putawaycapacity = 0
                  , @c_final_toloc     = @cSuggestedLOC OUTPUT
                  , @c_PickAndDropLoc  = @cPickAndDropLoc OUTPUT
            ELSE
               EXEC @n_err = [dbo].[nspRDTPASTD]
                    @c_userid        = 'RDT'          -- NVARCHAR(10)
                  , @c_storerkey     = @cStorerkey    -- NVARCHAR(15)
                  , @c_lot           = ''             -- NVARCHAR(10)
                  , @c_sku           = ''             -- NVARCHAR(20)
                  , @c_id            = @cID           -- NVARCHAR(18)
                  , @c_fromloc       = @cFromLOC      -- NVARCHAR(10)
                  , @n_qty           = @nQTY          -- int
                  , @c_uom           = @cUOM          -- NVARCHAR(10)
                  , @c_packkey       = @cPackKey      -- NVARCHAR(10) -- optional
                  , @n_putawaycapacity = 0
                  , @c_final_toloc     = @cSuggestedLOC OUTPUT
                  , @c_PickAndDropLoc  = @cPickAndDropLoc OUTPUT
         END
         ELSE
         BEGIN
            EXEC @n_err = [dbo].[nspRDTPASTD]
                 @c_userid        = 'RDT'          -- NVARCHAR(10)
               , @c_storerkey     = @cStorerkey    -- NVARCHAR(15)
               , @c_lot           = ''             -- NVARCHAR(10)
               , @c_sku           = ''             -- NVARCHAR(20)
               , @c_id            = @cID           -- NVARCHAR(18)
               , @c_fromloc       = @cFromLOC      -- NVARCHAR(10)
               , @n_qty           = @nQTY          -- int
               , @c_uom           = @cUOM          -- NVARCHAR(10)
               , @c_packkey       = @cPackKey      -- NVARCHAR(10) -- optional
               , @n_putawaycapacity = 0
               , @c_final_toloc     = @cSuggestedLOC OUTPUT
               , @c_PickAndDropLoc  = @cPickAndDropLoc OUTPUT

         END

         IF @n_err <> 0
         BEGIN
            SET @cErrMsg = @c_errmsg
            GOTO Quit
         END

         IF ISNULL(@cSuggestedLOC, '') = ''
         BEGIN
            SET @nErrNo = 50026
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Avail Loc' -- (Vicky03)
            GOTO Quit
         END

         IF @cSuggestedLOC = 'SEE_SUPV'
         -- (Vicky07) - Start
         BEGIN
            SET @nErrNo = 50074
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SEE_SUPV'
            GOTO Quit
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
            WHERE LOC = @cSuggestedLOC
               AND Facility = @cFacility)
         BEGIN
            SET @nErrNo = 50028
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Bad Location'
            GOTO Quit
         END

         -- (james03)
         -- Check if suggested loc already locked by other user
         IF EXISTS (SELECT 1 FROM dbo.RFPUTAWAY WITH (NOLOCK)
                    WHERE StorerKey = @cStorerkey
                    AND SuggestedLoc = @cSuggestedLOC
                    AND SKU = @cSKU
                    AND ptcid <> @cUserName)
         BEGIN
            -- Check if the loc already locked, get another suggested loc
            IF EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)
                       WHERE StorerKey = @cStorerkey
                       AND Loc = @cSuggestedLOC
                       AND SKU = @cSKU
                       AND PendingMoveIn > 0)
            BEGIN
               SET @cSuggestedLOC = ''
               GOTO PUTAWAY2BULK
            END
         END

         /**************************************************/
         -- Once SuggestedLoc Pass the Validation
         -- 1. Insert into RFPutaway Table
         -- 2. Update LotxLocxID PendingMovein
         -- (ChewKP10) Start
         /**************************************************/

         --SET @cLot = ''
         SET @n_RFQty = 0

         SET @c_RFLoc = ''
         SET @c_RFLot = ''
         SET @c_RFSKU = ''
         SET @c_RFID = ''
         SET @c_RFStorerkey = ''
         SET @n_RFPendingMoveIN = 0

         DECLARE curPending CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

         SELECT Lot, Qty  FROM dbo.LotxLocxID WITH (NOLOCK)
         WHERE Loc = @cFromLOC
               AND SKU = @cSKU
               AND ID = @cID
               AND Storerkey = @cStorerkey

         OPEN curPending
         FETCH NEXT FROM curPending INTO @c_RFLot, @n_RFQty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            BEGIN TRAN

            INSERT INTO dbo.RFPUTAWAY (Storerkey, SKU, Lot, FromLoc, SuggestedLoc, ID, ptcid, Qty)
            VALUES (@cStorerkey, @cSKU, @c_RFLot, @cFromLoc, @cSuggestedLOC, @cID, @cUserName, @n_RFQty )
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
--              SET @nErrNo = 50078
--              SET @cErrMsg = rdt.rdtgetmessage( 50078, @cLangCode, 'DSP') --50078^UPD RPA FAIL
              ROLLBACK TRAN
            END
            ELSE
               BEGIN
               COMMIT TRAN
            END

            IF EXISTS (SELECT 1 FROM LotxLocxID WITH (NOLOCK)
               WHERE Loc = @cSuggestedLOC
               AND Lot = @c_RFLot
               AND SKU = @cSKU
               AND ID = @cID
               AND Storerkey = @cStorerkey)
            BEGIN

               BEGIN TRAN

               UPDATE dbo.LotxLocxID WITH (ROWLOCK)
                     SET PendingMoveIn = CASE WHEN PendingMoveIn >= 0 THEN PendingMoveIn + @n_RFQty
                                         ELSE 0
                                         END
               WHERE Lot = @c_RFLot
                     AND SKU = @cSKU
                     AND Loc = @cSuggestedLoc
                     AND ID  = @cID
                     AND Storerkey = @cStorerkey

               IF @@Error <> 0
               BEGIN
                  SET @nErrNo = 50079
                  SET @cErrMsg = rdt.rdtgetmessage( 50079, @cLangCode, 'DSP') --50079^UPD LLI FAIL
                  ROLLBACK TRAN
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END
            END
            ELSE
            BEGIN
               BEGIN TRAN

               INSERT LOTxLOCxID (Lot,Loc,ID,Storerkey,Sku,PendingMoveIn)
               VALUES (@c_RFLot,  @cSuggestedLOC, @cID,  @cStorerkey, @cSKU, @n_RFQty)

               IF @@Error <> 0
               BEGIN
                  SET @nErrNo = 50080
                  SET @cErrMsg = rdt.rdtgetmessage( 50080, @cLangCode, 'DSP') --50080^UPD LLI FAIL
                  ROLLBACK TRAN
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END
            END

            FETCH NEXT FROM curPending INTO @c_RFLot, @n_RFQty
         END
         CLOSE curPending
         DEALLOCATE curPending

         /**************************************************/
         -- (ChewKP10) End
         /**************************************************/

         IF @c_TMPATask = 1
         BEGIN
            IF @c_PickByCase <> '1' --Only Checked P&D Loc when PutawayRules01 turn off (ChewKP04)
            BEGIN
               IF ISNULL(@cPickAndDropLoc, '') = ''
               BEGIN
                  SET @nErrNo = 50034
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No PnD Loc'
                  GOTO Quit
               END

               IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
               WHERE LOC = @cPickAndDropLoc
               AND Facility = @cFacility)
               BEGIN
                  SET @nErrNo = 50035
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Bad Location'
                  GOTO Quit
               END

               -- (Vicky02) - Start
               IF EXISTS (SELECT 1 FROM dbo.TASKDETAIL WITH (NOLOCK)
               WHERE ToLoc = @cPickAndDropLoc AND TaskType = 'PA'
               AND Status = '3' AND UserKey <> @cUserName)
               BEGIN
                 GOTO RERUN_SP
               END
               -- (Vicky02) - End
            END

            IF ISNULL(@cPickAndDropLoc, '' ) <> '' AND @c_PickByCase <> '1'
            BEGIN
               -- Get First Key
               SELECT @b_success = 1
               -- (SHONG01)
               EXECUTE dbo.nspg_getkey
               'TaskDetailKey'
               , 10
               , @c_taskdetailkey1 OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SET @nErrNo = 50032
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
                  GOTO Quit
               END

               -- Get Second Key
               SELECT @b_success = 1
               -- (SHONG01)
               EXECUTE dbo.nspg_getkey
               'TaskDetailKey'
               , 10
               , @c_taskdetailkey2 OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SET @nErrNo = 50032
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
                  GOTO Quit
               END

               -- Generate First Task With Status = 3
               EXEC [rdt].[rdt_TMTask]
                   @c_TaskKey       = @c_taskdetailkey1
                  ,@c_TaskType      = 'PA'
                  ,@c_RefTaskKey    = @c_taskdetailkey2
                  ,@c_storerkey     = @cStorerkey
                  ,@c_sku           = ''
                  ,@c_lot           = ''
                  ,@c_Fromloc       = @cFromLOC
                  ,@c_FromID        = @cID
                  ,@c_ToLoc         = @cPickAndDropLoc
                  ,@c_Toid          = @cID
                  ,@c_UOM           = '6'
                  ,@n_UOMQTY        = 0
                  ,@n_QTY           = 0
                  ,@c_sourcekey     = ''
                  ,@c_sourcetype    = ''
                  ,@c_TaskStatus    = '3'
                  ,@c_TaskFlag      = 'A'
                  ,@c_UserName      = @cUserName
                  ,@b_Success       = @b_Success OUTPUT
                  ,@c_errmsg        = @c_errmsg OUTPUT
                  ,@c_Areakey       = '' -- (ChewKP03) -- (ChewKP08)

                If @b_success = 0
                BEGIN
                  SET @nErrNo = 50032
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
                  GOTO Quit
                END

                -- Generate Second Task With Status = W
                EXEC [rdt].[rdt_TMTask]
                   @c_TaskKey       = @c_taskdetailkey2
                  ,@c_TaskType      = 'PA'
                  ,@c_RefTaskKey    = ''
                  ,@c_storerkey     = @cStorerkey
                  ,@c_sku           = ''
                  ,@c_lot           = ''
                  ,@c_Fromloc       = @cPickAndDropLoc
                  ,@c_FromID        = @cID
                  ,@c_ToLoc         = @cSuggestedLOC
                  ,@c_Toid          = @cID
                  ,@c_UOM           = '6'
                  ,@n_UOMQTY        = 0
                  ,@n_QTY           = 0
                  ,@c_sourcekey    = ''
                  ,@c_sourcetype    = ''
                  ,@c_TaskStatus    = 'W'
                  ,@c_TaskFlag      = 'A'
                  ,@c_UserName      = ''
                  ,@b_Success       = @b_Success OUTPUT
                  ,@c_errmsg        = @c_errmsg OUTPUT
                  ,@c_Areakey       = '' -- (ChewKP03) -- (ChewKP08)

                If @b_success = 0
                BEGIN
                  SET @nErrNo = 50032
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
                  GOTO Quit
                END
            END
         END
         -- SOS#157089 Generate 2 Putaway Task for Task Manager dbo.TaskDetail (End) --

         -- Prep next screen var

         IF @c_TMPATask = 1  AND @c_PickByCase <> '1' -- SOS#157089 -- (ChewKP04)
            SET @cOutField01 = @cPickAndDropLoc
         ELSE
            SET @cOutField01 = @cSuggestedLOC

            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''

         -- Go to next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1

         SET @cToLOC = ''

         GOTO Quit
      END

      -- If continue from previous pallet (multi sku) putaway
      IF ISNULL(@cToLOC, '') <> ''
      BEGIN
         SELECT @cPackUOM3 = PACKUOM3
         FROM   dbo.PACK WITH (NOLOCK)
         WHERE  PackKey = @cPackKey

         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtfnc_Pallet_Putaway -- For rollback or commit only our own transaction

         DECLARE CUR_Putaway CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT LOT, (QTY - QTYALLOCATED - QTYPICKED)
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
            AND SKU = @cSKU
            AND LOC = @cFromLOC
            AND ID  = @cID
            AND (QTY - QTYALLOCATED - QTYPICKED) > 0

         OPEN CUR_Putaway
         FETCH NEXT FROM CUR_Putaway INTO @cLOT, @nPutAwayQty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Only putaway what is needed. For example, if I wanna putaway 10 qty to LOC A & 5 qty to LOC B from same LOC
            -- So 1st time I key in 10 qty then 2nd time I key in 5 qty (james02)
            IF @nQTY < @nPutAwayQty
               SET @nPutAwayQty = @nQTY

            -- NOTE: Not convert QTY as nspItrnAddMove will convert QTY based on pass-in UOM
            EXEC dbo.nspRFPA02
                 @c_sendDelimiter = '`'           -- NVARCHAR(1)
               , @c_ptcid         = 'RDT'         -- NVARCHAR(5)
               , @c_userid        = 'RDT'         -- NVARCHAR(10)
               , @c_taskId        = 'RDT'         -- NVARCHAR(10)
               , @c_databasename  = NULL          -- NVARCHAR(5)
               , @c_appflag       = NULL        -- NVARCHAR(2)
               , @c_recordType    = NULL          -- NVARCHAR(2)
               , @c_server        = NULL          -- NVARCHAR(30)
               , @c_storerkey     = @cStorerkey   -- NVARCHAR(30)
               , @c_lot           = @cLOT         -- NVARCHAR(10) -- optional
               , @c_sku           = @cSKU         -- NVARCHAR(30)
               , @c_fromloc       = @cFromLOC     -- NVARCHAR(18)
               , @c_fromid        = @cID          -- NVARCHAR(18)
               , @c_toloc         = @cToLOC       -- NVARCHAR(18)
               , @c_toid          = @cID          -- NVARCHAR(18)
               , @n_qty           = @nPutAwayQty  -- int
               , @c_uom           = @cPackUOM3    -- NVARCHAR(10)
               , @c_packkey       = @cPackKey     -- NVARCHAR(10) -- optional
               , @c_reference     = ' '           -- NVARCHAR(10) -- not used
               , @c_outstring     = @c_outstring  OUTPUT   -- NVARCHAR(255)  OUTPUT
               , @b_Success       = @b_Success    OUTPUT   -- int        OUTPUT
               , @n_err           = @n_err        OUTPUT   -- int        OUTPUT
               , @c_errmsg        = @c_errmsg     OUTPUT   -- NVARCHAR(250)  OUTPUT

            IF @n_err <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @n_err, @cLangCode, 'DSP')
               CLOSE CUR_Putaway
               DEALLOCATE CUR_Putaway
               GOTO RollBackTran
            END
            ELSE
            BEGIN
               SET @cCombLastCtnPutaway = rdt.RDTGetConfig( @nFunc, 'CombLastCtnPutaway', @cStorerkey) -- (Shong001)
               --IF @cCombLastCtnPutaway = '1'
               BEGIN
                  -- Update the UCC table
                  UPDATE UCC WITH (ROWLOCK)
                     SET UCC.Loc = @cToLOC,
                         UCC.EditWho  = sUser_sName(),
                         UCC.EditDate = GETDATE()
                  WHERE Storerkey = @cStorerkey
                  AND   SKU = @cSKU
                  AND   LOT = @cLOT
                  AND   LOC = @cFromLOC
                  AND   ID  = @cID
              END

            -- (Vicky06) EventLog - QTY
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '4', -- Move
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerkey    = @cStorerkey,
               @cLocation     = @cFromLOC,
               @cToLocation   = @cToLOC,
               @cID           = @cID,
               @cToID         = @cID,
               @cSKU          = @cSKU,
               @cUOM          = @cPackUOM3,
               @nQTY          = @nPutAwayQty,
               @cLot          = @cLOT
            END

            SET @nQTY = @nQTY - @nPutAwayQty
            IF @nQTY = 0
               BREAK
            FETCH NEXT FROM CUR_Putaway INTO @cLOT, @nPutAwayQty
         END
         CLOSE CUR_Putaway
         DEALLOCATE CUR_Putaway

         COMMIT TRAN rdtfnc_Pallet_Putaway -- Only commit change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         --reinitialise variable
         SELECT @cSKU = '', @nQty = 0, @cPackKey = '', @cDescr1 = '', @cDescr2 = '', @cUOM = ''

         SELECT
            @cSKU = L.SKU,
            @nQty = SUM(L.Qty - L.QtyPicked - QtyAllocated),
            @cPackKey = S.PackKey,
            @cDescr1 = SUBSTRING(S.DESCR, 1, 20),
            @cDescr2 = SUBSTRING(S.DESCR,21, 20),
            @cUOM = CASE @cPUOM
            WHEN '1' THEN P.PackUOM4 -- Pallet
            WHEN '2' THEN P.PackUOM1 -- Carton
            WHEN '3' THEN P.PackUOM2 -- InnerPack
            WHEN '4' THEN P.PackUOM8 -- OtherUnit1
            WHEN '5' THEN P.PackUOM9 -- OtherUnit2
            WHEN '6' THEN P.PackUOM3 -- Each
            ELSE P.PackUOM3 END
         FROM dbo.LOTxLOCxID L (NOLOCK)
         JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = L.StorerKey AND S.SKU = L.SKU
         JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PackKey
         JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = L.LOC
         WHERE L.StorerKey = @cStorerkey
         AND LOC.Facility = @cFacility
         AND L.ID = @cID
         AND L.LOC = @cFromLOC
         GROUP BY L.SKU, S.PackKey, S.DESCR, P.PackUOM4,
         CASE @cPUOM
         WHEN '1' THEN P.PackUOM4 -- Pallet
         WHEN '2' THEN P.PackUOM1 -- Carton
         WHEN '3' THEN P.PackUOM2 -- InnerPack
         WHEN '4' THEN P.PackUOM8 -- OtherUnit1
         WHEN '5' THEN P.PackUOM9 -- OtherUnit2
         WHEN '6' THEN P.PackUOM3 -- Each
         ELSE P.PackUOM3 END
         HAVING SUM(L.Qty - L.QtyPicked - QtyAllocated) > 0
         ORDER BY L.SKU

         -- If pallet is multi sku/pallet, proceed with the next sku
         IF ISNULL(@cSKU, '') <> ''
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cID          --ID
            SET @cOutField02 = @cStorerkey   --StorerKey
            SET @cOutField03 = @cSKU         --SKU
            SET @cOutField04 = @cDescr1      --StorerKey
            SET @cOutField05 = @cDescr1      --ID
            SET @cOutField06 = rdt.rdtConvUOMQty (@cStorerkey, @cSKU, @nQty, '6', @cPUOM) --Qty
            SET @cOutField07 = @cUOM         --UOM
            SET @cOutField08 = @cFromLOC     --FROM LOC
            SET @cOutField09 = @cToLOC       --TO LOC

            -- Remain in same screen
            GOTO Quit
         END
         ELSE
         BEGIN
            -- Finish pallet putaway, goto confirmation message screen
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2
         END
      END

      -- Extended info
      SET @cOutField15 = ''
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cID, @cFromLOC, @cSKU, @nQTY, @cSuggestedLOC, @cToLOC, @cPickAndDropLOC, @cFinalLOC, ' +
               ' @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cID             NVARCHAR( 18), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nInputKey, @cStorerKey, @cFacility, @cID, @cFromLOC, @cSKU, @nQTY, @cSuggestedLOC, @cToLOC, @cPickAndDropLOC, @cFinalLOC, 
               @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField15 = @cExtendedInfo1
         END
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = '' -- ID
      SET @cOutField02 = @cStorerkey -- FROM LOC
      SET @cOutField03 = ''

      SET @cID = ''
      SET @cFromLOC = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1


      IF @c_TMPATask = 1 -- SOS#157089
      BEGIN
         SET @cOutField02 = 'ALL'
      END

      -- Back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

END
GOTO Quit

/********************************************************************************
Step 3. Scn = 922
   Suggested LOC
   To LOC
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cToLOC = @cInField02

      SET @cFinalLOC = @cSuggestedLOC
      IF @c_TMPATask = 1 And @c_PickByCase <> '1'
      BEGIN
         SET @cSuggestedLOC = @cPickAndDropLoc
      END
      ELSE
      BEGIN
         SET @cSuggestedLOC = @cSuggestedLOC
      END

      IF ISNULL(@cToLOC, '') = ''
      BEGIN
         SET @nErrNo = 50029
         SET @cErrMsg = rdt.rdtgetmessage( 50029, @cLangCode, 'DSP') --TO LOC req
         SET @cOutField01 = @cSuggestedLOC
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- (Shong001)
      SET @cDisAllowOverrideLOC = '0'
      SET @cDisAllowOverrideLOC = rdt.RDTGetConfig( @nFunc, 'DisallowOverrideLOC', @cStorerKey)

      IF @c_PickByCase = '1' OR @cDisAllowOverrideLOC = '1'
      BEGIN
         SELECT @c_Putawayzone = Putawayzone 
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cToLOC
         AND   Facility = @cFacility

         SET @c_VirtualLoc = ''
         SELECT @c_VirtualLoc = InLoc 
         FROM dbo.PutawayZone WITH (NOLOCK)
         WHERE Putawayzone = @c_Putawayzone

         IF @cSuggestedLOC <> @cToLOC AND ISNULL( @c_VirtualLoc, '') <> ''
         BEGIN
            SET @nErrNo = 50064
            SET @cErrMsg = rdt.rdtgetmessage( 50064, @cLangCode, 'DSP') --ToLoc Not Match
            SET @cOutField01 = @cSuggestedLOC
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            GOTO Quit
         END
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLOC)
      BEGIN
         SET @nErrNo = 50030
         SET @cErrMsg = rdt.rdtgetmessage( 50030, @cLangCode, 'DSP') --Invalid LOC
         SET @cOutField01 = @cSuggestedLOC
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         GOTO Quit
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLOC AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 50031
         SET @cErrMsg = rdt.rdtgetmessage( 50031, @cLangCode, 'DSP') --Wrong facility
         SET @cOutField01 = @cSuggestedLOC
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO QUIT
      END

      SELECT @cPackUOM3 = PACKUOM3
      FROM   dbo.PACK WITH (NOLOCK)
      WHERE  PackKey = @cPackKey

      IF @c_TMPATask = 1 And @c_PickByCase <> '1'
      BEGIN
         --SET @cOutField01 = @c_cPickAndDropLoc
         IF @cToLOC <> @cPickAndDropLoc
         BEGIN
            SET @nErrNo = 50038
            SET @cErrMsg = rdt.rdtgetmessage( 50038, @cLangCode, 'DSP') --Invalid LOC
            SET @cOutField01 = @cSuggestedLOC
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            GOTO Quit
         END
      END

      -- (Shong001 - Start)
      SET  @cCombLastCtnPutaway = '0'
      SET @cPalletType = ''

      DECLARE @n_TotalCarton INT,
              @c_LocCategory  NVARCHAR(10)

      SET @c_LocCategory = ''
      SELECT @c_LocCategory = LocationCategory
      FROM LOC WITH (NOLOCK)
      WHERE LOC = @cToLOC

      SET @cCombLastCtnPutaway = rdt.RDTGetConfig( @nFunc, 'CombLastCtnPutaway', @cStorerkey) -- (Shong001)
      IF @cCombLastCtnPutaway = '1' AND @c_LocCategory NOT IN ('PnD_Out')
      BEGIN
         SET @nNumberOfSKU = 0
         SET @nNumberOfPackSize = 0

         IF EXISTS(SELECT 1 FROM UCC WITH (NOLOCK) WHERE ID = @cID)
         BEGIN

            SELECT @nNumberOfSKU = COUNT(DISTINCT UCC.SKU + L.Lottable02),
                   @nNumberOfPackSize = COUNT(DISTINCT UCC.SKU + L.Lottable02 + CAST(Qty AS NVARCHAR(10)))
            FROM   UCC (NOLOCK)
            JOIN LOTATTRIBUTE l (NOLOCK) ON UCC.Lot = l.Lot AND l.StorerKey = @cStorerkey
            WHERE  UCC.StorerKey = @cStorerkey
            AND    UCC.Loc = @cFromLOC
            AND    UCC.ID = @cID

            SET @n_TotalCarton = 0

            IF @nNumberOfSKU = 1
            BEGIN
               SELECT @n_TotalCarton= COUNT(DISTINCT UCCNO)
               FROM   UCC (NOLOCK)
               WHERE  UCC.StorerKey = @cStorerkey
               AND    UCC.Loc = @cFromLOC
               AND    UCC.ID = @cID
            END

            IF @nNumberOfSKU > 1 OR @nNumberOfPackSize > 2 -- SHONG002
               SET @cPalletType = 'Mixed_Lot_CartonSize'
            ELSE IF @nNumberOfSKU = 1 AND @nNumberOfPackSize = 2
               SET @cPalletType = '1_Lot_2CartonSize'
            ELSE
               SET @cPalletType = '1_Lot_CartonSize'
         END
      END

      IF @cCombLastCtnPutaway = '1' AND
         ( (@cPalletType IN ('1_Lot_2CartonSize','Mixed_Lot_CartonSize') AND @c_LocCategory IN ('DECK') )
            OR @n_TotalCarton = 1  )
      BEGIN
         SET @cUCCNo = ''
         SET @nUCCQty = 0

         -- james03
         -- Scenario
         -- 1. Receive 600 qty; 10 ctn 50 ea; 1 ctn 30 each; 1 ctn 70 each
         --    cannot order by qty coz 50 < 70 and this will have all ctn PA to deck
         --    Try to get the ucc with ctn count = 1
         SELECT TOP 1
            @nUCCQty = U.Qty
         FROM   UCC U (NOLOCK)
         JOIN LOTATTRIBUTE l (NOLOCK) ON U.Lot = L.Lot AND l.StorerKey = @cStorerkey
         WHERE  U.StorerKey = @cStorerkey
         AND    U.SKU = @cSKU
         AND    U.Loc = @cFromLOC
         AND    U.ID = @cID
         GROUP BY  U.Qty
         HAVING COUNT ( U.QTY) = 1

         SELECT TOP 1
            @cUCCNo = U.UCCNo
         FROM   UCC U (NOLOCK)
         JOIN LOTATTRIBUTE l (NOLOCK) ON U.Lot = L.Lot AND l.StorerKey = @cStorerkey
         WHERE  U.StorerKey = @cStorerkey
         AND    U.SKU = @cSKU
         AND    U.Loc = @cFromLOC
         AND    U.ID = @cID
         AND    U.QTY = @nUCCQty

         IF @cUCCNo = ''
         BEGIN
            SELECT TOP 1
               @nUCCQty = U.Qty,
               @cUCCNo = U.UCCNo
            FROM   UCC U (NOLOCK)
            JOIN LOTATTRIBUTE l (NOLOCK) ON U.Lot = L.Lot AND l.StorerKey = @cStorerkey
            WHERE  U.StorerKey = @cStorerkey
            AND    U.SKU = @cSKU
            AND    U.Loc = @cFromLOC
            AND    U.ID = @cID
            ORDER BY QTY ASC
         END

         SET @cOutField01 = @cToLOC
         SET @cOutField02 = @cUCCNo
         SET @cOutField03 = @cSKU
         SET @cOutField04 = @cDescr1
         SET @cOutField05 = @cDescr2
         SET @cOutField06 = @cPackUOM3
         SET @cOutField07 = @nUCCQty
         SET @cOutField08 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 8

         -- Goto Step 7
         -- Scan LPN#
         SET @nScn = @nScn+4
         SET @nStep = @nStep+4

         GOTO QUIT
      END
      -- (Shong001 - End)
      --
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_Pallet_Putaway -- For rollback or commit only our own transaction

      IF @c_TMPATask <> '1' -- SOS#157089
      BEGIN
         DECLARE CUR_Putaway CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT LOT, (QTY - QTYALLOCATED - QTYPICKED)
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
          AND SKU = @cSKU
          AND LOC = @cFromLOC
          AND ID  = @cID
          AND (QTY - QTYALLOCATED - QTYPICKED) > 0

         OPEN CUR_Putaway
         FETCH NEXT FROM CUR_Putaway INTO @cLOT, @nPutAwayQty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Only putaway what is needed. For example, if I wanna putaway 10 qty to LOC A & 5 qty to LOC B from same LOC
            -- So 1st time I key in 10 qty then 2nd time I key in 5 qty (james02)
            IF @nQTY < @nPutAwayQty
               SET @nPutAwayQty = @nQTY

            -- NOTE: Not convert QTY as nspItrnAddMove will convert QTY based on pass-in UOM
            EXEC dbo.nspRFPA02
               @c_sendDelimiter = '`'           -- NVARCHAR(1)
               , @c_ptcid         = 'RDT'         -- NVARCHAR(5)
               , @c_userid        = 'RDT'         -- NVARCHAR(10)
               , @c_taskId        = 'RDT'         -- NVARCHAR(10)
               , @c_databasename  = NULL          -- NVARCHAR(5)
               , @c_appflag       = NULL          -- NVARCHAR(2)
               , @c_recordType    = NULL          -- NVARCHAR(2)
               , @c_server        = NULL          -- NVARCHAR(30)
               , @c_storerkey     = @cStorerkey   -- NVARCHAR(30)
               , @c_lot           = @cLOT         -- NVARCHAR(10) -- optional
               , @c_sku           = @cSKU         -- NVARCHAR(30)
               , @c_fromloc       = @cFromLOC     -- NVARCHAR(18)
               , @c_fromid        = @cID          -- NVARCHAR(18)
               , @c_toloc         = @cToLOC       -- NVARCHAR(18)
               , @c_toid          = @cID          -- NVARCHAR(18)
               , @n_qty           = @nPutAwayQty  -- int
               , @c_uom           = @cPackUOM3    -- NVARCHAR(10)
               , @c_packkey       = @cPackKey     -- NVARCHAR(10) -- optional
               , @c_reference     = ' '           -- NVARCHAR(10) -- not used
               , @c_outstring     = @c_outstring  OUTPUT   -- NVARCHAR(255)  OUTPUT
               , @b_Success       = @b_Success    OUTPUT   -- int        OUTPUT
               , @n_err           = @n_err        OUTPUT   -- int  OUTPUT
               , @c_errmsg        = @c_errmsg     OUTPUT   -- NVARCHAR(250)  OUTPUT

            IF @n_err <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @n_err, @cLangCode, 'DSP')
               CLOSE CUR_Putaway
               DEALLOCATE CUR_Putaway
               GOTO RollBackTran
            END
            ELSE
            BEGIN
               SET @cCombLastCtnPutaway = rdt.RDTGetConfig( @nFunc, 'CombLastCtnPutaway', @cStorerkey) -- (Shong001)
               --IF @cCombLastCtnPutaway = '1'
               BEGIN
               	SET @cLoseID = '0'
               	SELECT @cLoseID = LoseId
               	FROM LOC WITH (NOLOCK)
               	WHERE LOC = @cToLOC

                  -- Update the UCC table
                  UPDATE UCC WITH (ROWLOCK)
                     SET UCC.Loc = @cToLOC,
                         UCC.ID  = CASE WHEN @cLoseID = '1' THEN '' ELSE UCC.ID END,
                         UCC.EditWho  = sUser_sName(),
                         UCC.EditDate = GETDATE()
                  WHERE Storerkey = @cStorerkey
                  AND   SKU = @cSKU
                  AND   LOT = @cLOT
                  AND   LOC = @cFromLOC
                  AND   ID  = @cID
              END

               -- (Vicky06) EventLog - QTY
               EXEC RDT.rdt_STD_EventLog
               @cActionType   = '4', -- Move
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerkey    = @cStorerkey,
               @cLocation     = @cFromLOC,
               @cToLocation   = @cToLOC,
               @cID           = @cID,
               @cToID         = @cID,
               @cSKU          = @cSKU,
               @cUOM          = @cPackUOM3,
               @nQTY          = @nPutAwayQty,
               @cLot          = @cLOT
            END

            SET @nQTY = @nQTY - @nPutAwayQty
            IF @nQTY = 0
               BREAK

            FETCH NEXT FROM CUR_Putaway INTO @cLOT, @nPutAwayQty
         END
         CLOSE CUR_Putaway
         DEALLOCATE CUR_Putaway
      END
      ELSE -- @c_TMPATask = 1  -- SOS#157089
      BEGIN
         IF @c_PickByCase <> '1'
         BEGIN
            -- Update TaskDetail Status = 9 When Successfully
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
               Status = '9',
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME(),
               TrafficCop = NULL
            WHERE Taskdetailkey = @c_taskdetailkey1

            IF @@Error <> 0
            BEGIN
               SET @nErrNo = 50045 -- (ChewKP02)
               SET @cErrMsg = rdt.rdtgetmessage( 50045, @cLangCode, 'DSP') --50045^UPD TD FAIL
               GOTO RollBackTran
            END

            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
               Status = '0',
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME(),
               TrafficCop = NULL
            WHERE Taskdetailkey = @c_taskdetailkey2

            IF @@Error <> 0
            BEGIN
               SET @nErrNo = 50046 -- (ChewKP02)
               SET @cErrMsg = rdt.rdtgetmessage( 50046, @cLangCode, 'DSP') --50046^UPD TD FAIL
               GOTO RollBackTran
            END
         END
         ELSE -- @c_PickByCase = '1'
         BEGIN
            IF @c_ToLocCheck = '0'
            BEGIN

               DECLARE CUR_Putaway CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT LOT, (QTY - QTYALLOCATED - QTYPICKED)
               FROM dbo.LOTxLOCxID WITH (NOLOCK)
               WHERE StorerKey = @cStorerkey
               AND SKU = @cSKU
               AND LOC = @cFromLOC
               AND ID  = @cID
               AND (QTY - QTYALLOCATED - QTYPICKED) > 0

               OPEN CUR_Putaway
               FETCH NEXT FROM CUR_Putaway INTO @cLOT, @nPutAwayQty
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  -- NOTE: Not convert QTY as nspItrnAddMove will convert QTY based on pass-in UOM
                  EXEC dbo.nspRFPA02
                    @c_sendDelimiter = '`'           -- NVARCHAR(1)
                  , @c_ptcid         = 'RDT'   -- NVARCHAR(5)
                  , @c_userid        = 'RDT'         -- NVARCHAR(10)
                  , @c_taskId        = 'RDT'         -- NVARCHAR(10)
                  , @c_databasename  = NULL          -- NVARCHAR(5)
                  , @c_appflag       = NULL          -- NVARCHAR(2)
                  , @c_recordType    = NULL          -- NVARCHAR(2)
                  , @c_server        = NULL          -- NVARCHAR(30)
                  , @c_storerkey     = @cStorerkey   -- NVARCHAR(30)
                  , @c_lot           = @cLOT         -- NVARCHAR(10) -- optional
                  , @c_sku           = @cSKU         -- NVARCHAR(30)
                  , @c_fromloc       = @cFromLOC     -- NVARCHAR(18)
                  , @c_fromid        = @cID          -- NVARCHAR(18)
                  , @c_toloc         = @cToLOC       -- NVARCHAR(18)
                  , @c_toid          = @cID          -- NVARCHAR(18)
                  , @n_qty           = @nPutAwayQty  -- int
                  , @c_uom           = @cPackUOM3    -- NVARCHAR(10)
                  , @c_packkey       = @cPackKey     -- NVARCHAR(10) -- optional
                  , @c_reference     = ' '           -- NVARCHAR(10) -- not used
                  , @c_outstring     = @c_outstring  OUTPUT   -- NVARCHAR(255)  OUTPUT
                  , @b_Success       = @b_Success    OUTPUT   -- int        OUTPUT
                  , @n_err           = @n_err        OUTPUT   -- int        OUTPUT
                  , @c_errmsg        = @c_errmsg     OUTPUT   -- NVARCHAR(250)  OUTPUT

                  IF @n_err <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @n_err, @cLangCode, 'DSP')
                     CLOSE CUR_Putaway
                     DEALLOCATE CUR_Putaway
                     GOTO RollBackTran
                  END
                  ELSE
                  BEGIN
                     SET @cCombLastCtnPutaway = rdt.RDTGetConfig( @nFunc, 'CombLastCtnPutaway', @cStorerkey) -- (Shong001)
                     --IF @cCombLastCtnPutaway = '1'
                     BEGIN
               	      SET @cLoseID = '0'
               	      SELECT @cLoseID = LoseId
               	      FROM LOC WITH (NOLOCK)
               	      WHERE LOC = @cToLOC

                        -- Update the UCC table
                        UPDATE UCC WITH (ROWLOCK)
                           SET UCC.Loc = @cToLOC,
                               UCC.ID  = CASE WHEN @cLoseID = '1' THEN '' ELSE UCC.ID END,
                               UCC.EditWho  = sUser_sName(),
                               UCC.EditDate = GETDATE()
                        WHERE Storerkey = @cStorerkey
                        AND   SKU = @cSKU
                        AND   LOT = @cLOT
                        AND   LOC = @cFromLOC
                        AND   ID  = @cID
                    END

                     -- (Vicky06) EventLog - QTY
                     EXEC RDT.rdt_STD_EventLog
                     @cActionType   = '4', -- Move
                     @cUserID       = @cUserName,
                     @nMobileNo     = @nMobile,
                     @nFunctionID   = @nFunc,
                     @cFacility     = @cFacility,
                     @cStorerkey    = @cStorerkey,
                     @cLocation     = @cFromLOC,
                     @cToLocation   = @cToLOC,
                     @cID           = @cID,
                     @cToID         = @cID,
                     @cSKU          = @cSKU,
                     @cUOM          = @cPackUOM3,
                     @nQTY          = @nPutAwayQty,
                     @cLot          = @cLOT
               END
               FETCH NEXT FROM CUR_Putaway INTO @cLOT, @nPutAwayQty
            END
            CLOSE CUR_Putaway
            DEALLOCATE CUR_Putaway
         END
         ELSE IF @c_ToLocCheck = '1'
         BEGIN
            DECLARE curPutaway CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT SKU ,Lot ,UOM ,Sourcekey ,caseID ,Qty ,ID , FromLoc , Packkey FROM rdt.rdtPutawayLog (NOLOCK)
            WHERE Status = '0'
            AND Storerkey = @cStorerkey
            AND SKU = @cSKU
            AND ID = @cID
            AND Mobile = @nMobile

            OPEN curPutaway
            FETCH NEXT FROM curPutaway INTO  @c_PASKU , @c_PALot , @c_PAUOM , @c_PASourcekey,  @c_PACaseID , @n_PAQty , @c_PAID , @c_PALoc , @c_PAPackkey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               -- Get First Key
               SELECT @b_success = 1
               -- (SHONG01)
               EXECUTE dbo.nspg_getkey
               'TaskDetailKey'
               , 10
               , @c_taskdetailkey1 OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SET @nErrNo = 50049
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
                  GOTO Quit
               END

               -- Generate First Task With Status = 0
               EXEC [rdt].[rdt_TMTask]
                   @c_TaskKey       = @c_taskdetailkey1
                  ,@c_TaskType      = 'PA'
                  ,@c_RefTaskKey    = ''
                  ,@c_storerkey     = @cStorerkey
                  ,@c_sku           = @c_PASKU
                  ,@c_lot           = @c_PALot
                  ,@c_Fromloc       = @cToLOC
                  ,@c_FromID        = ''
                  ,@c_ToLoc         = @c_PALoc
                  ,@c_Toid          = ''
                  ,@c_UOM           = '6'
                  ,@n_UOMQTY        = 0
                  ,@n_QTY           = @n_PAQty
                  ,@c_sourcekey     = @c_PASourcekey
                  ,@c_sourcetype    = ''
                  ,@c_TaskStatus    = '0'
                  ,@c_TaskFlag      = 'A'
                  ,@c_UserName      = ''
                  ,@b_Success       = @b_Success OUTPUT
                  ,@c_errmsg        = @c_errmsg OUTPUT
                  ,@c_Areakey       = '' -- (ChewKP03) -- (ChewKP08)
                  ,@c_CaseID   = @c_PACaseID -- (ChewKP08)

               If @b_success = 0
               BEGIN
                  SET @nErrNo = 50051
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
                  GOTO Quit
               END

               ---*** Insert into WCSRouting (Starting) ***---
               EXEC [dbo].[nspInsertWCSRouting]
                   @cStorerkey
                  ,@cFacility
                  ,@c_PACaseID
                  ,'PA'
                  ,'N'
                  ,@c_taskdetailkey1
                  ,@cUserName
                  , 0
                  ,@b_Success          OUTPUT
                  ,@nErrNo             OUTPUT
                  ,@c_ErrMsg           OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = @nErrNo
                  SET @cErrMsg = @c_ErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'

                  DELETE dbo.TaskDetail WITH (ROWLOCK)
                  WHERE Taskdetailkey = @c_taskdetailkey1

                IF @@ERROR <> 0
                BEGIN
                   SET @nErrNo = 50070
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                END

                GOTO Quit
            END

             -- ***Non Inventory Move *** --
             -- NOTE: Not convert QTY as nspItrnAddMove will convert QTY based on pass-in UOM
             EXEC dbo.nspRFPA02
                  @c_sendDelimiter = '`'           -- NVARCHAR(1)
                , @c_ptcid         = 'RDT'         -- NVARCHAR(5)
                , @c_userid        = 'RDT'         -- NVARCHAR(10)
                , @c_taskId        = 'RDT'         -- NVARCHAR(10)
                , @c_databasename  = NULL          -- NVARCHAR(5)
                , @c_appflag       = NULL          -- NVARCHAR(2)
                , @c_recordType    = NULL          -- NVARCHAR(2)
                , @c_server        = NULL          -- NVARCHAR(30)
                , @c_storerkey     = @cStorerkey   -- NVARCHAR(30)
                , @c_lot           = @c_PALot      -- NVARCHAR(10) -- optional
                , @c_sku           = @c_PASKU      -- NVARCHAR(30)
                , @c_fromloc      = @cFromLoc     -- NVARCHAR(18)
                , @c_fromid        = @c_PAID       -- NVARCHAR(18)
                , @c_toloc         = @cToLOC       -- NVARCHAR(18)
                , @c_toid          = ''            -- NVARCHAR(18)
                , @n_qty           = @n_PAQty      -- int
                , @c_uom           = @cPackUOM3    -- NVARCHAR(10)
                , @c_packkey       = @c_PAPackkey  -- NVARCHAR(10) -- optional
                , @c_reference     = ' '           -- NVARCHAR(10) -- not used
                , @c_outstring     = @c_outstring  OUTPUT   -- NVARCHAR(255)  OUTPUT
                , @b_Success       = @b_Success    OUTPUT   -- int        OUTPUT
                , @n_err           = @n_err        OUTPUT   -- int        OUTPUT
                , @c_errmsg        = @c_errmsg     OUTPUT   -- NVARCHAR(250)  OUTPUT

             IF @n_err <> 0
             BEGIN
                SET @cErrMsg = rdt.rdtgetmessage( @n_err, @cLangCode, 'DSP')
                --CLOSE CUR_Putaway
                --DEALLOCATE CUR_Putaway
                GOTO RollBackTran
             END
             ELSE
             BEGIN
               SET @cCombLastCtnPutaway = rdt.RDTGetConfig( @nFunc, 'CombLastCtnPutaway', @cStorerkey) -- (Shong001)
               --IF @cCombLastCtnPutaway = '1'
               BEGIN
            	   SET @cLoseID = '0'
            	   SELECT @cLoseID = LoseId
            	   FROM LOC WITH (NOLOCK)
            	   WHERE LOC = @cToLOC

                  -- Update the UCC table
                  UPDATE UCC WITH (ROWLOCK)
                     SET UCC.Loc = @cToLOC,
                         UCC.ID  = CASE WHEN @cLoseID = '1' THEN '' ELSE UCC.ID END,
                         UCC.EditWho  = sUser_sName(),
                         UCC.EditDate = GETDATE()
                  WHERE Storerkey = @cStorerkey
                  AND   SKU = @cSKU
                  AND   LOT = @cLOT
                  AND   LOC = @cFromLOC
                  AND   ID  = @cID
               END

            END
            FETCH NEXT FROM curPutaway INTO  @c_PASKU , @c_PALot , @c_PAUOM , @c_PASourcekey,  @c_PACaseID , @n_PAQty , @c_PAID , @c_PALoc , @c_PAPackkey
            --EXEC rdt.rdtSetFocusField @nMobile, 1
          END
          SET @c_ToLocCheck = 0
          CLOSE curPutaway
          DEALLOCATE curPutaway

          UPDATE rdt.rdtPutawayLog WITH (ROWLOCK)
             SET Status = '9'
          WHERE Storerkey = @cStorerkey
          AND SKU = @cSKU
          AND ID = @cID
          AND Mobile = @nMobile
          AND Status = '0'

          IF @@ERROR <> 0
          BEGIN
             SET @nErrNo = 50069
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPAFailed'
             GOTO RollBackTran
          END
       END
       END
      END

      COMMIT TRAN rdtfnc_Pallet_Putaway -- Only commit change made here
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      --reinitialise variable
      SELECT @cSKU = '', @nQty = 0, @cPackKey = '', @cDescr1 = '', @cDescr2 = '', @cUOM = ''

      SELECT
         @cSKU = L.SKU,
         @nQty = SUM(L.Qty - L.QtyPicked - QtyAllocated),
         @cPackKey = S.PackKey,
         @cDescr1 = SUBSTRING(S.DESCR, 1, 20),
         @cDescr2 = SUBSTRING(S.DESCR,21, 20),
         @cUOM = CASE @cPUOM
         WHEN '1' THEN P.PackUOM4 -- Pallet
         WHEN '2' THEN P.PackUOM1 -- Carton
         WHEN '3' THEN P.PackUOM2 -- InnerPack
         WHEN '4' THEN P.PackUOM8 -- OtherUnit1
         WHEN '5' THEN P.PackUOM9 -- OtherUnit2
         WHEN '6' THEN P.PackUOM3 -- Each
         ELSE P.PackUOM3 END
      FROM dbo.LOTxLOCxID L (NOLOCK)
      JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = L.StorerKey AND S.SKU = L.SKU
      JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PackKey
      JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = L.LOC
      WHERE L.StorerKey = @cStorerkey
      AND LOC.Facility = @cFacility
      AND L.ID = @cID
      AND L.LOC = @cFromLOC
      GROUP BY L.SKU, S.PackKey, S.DESCR, P.PackUOM4,
      CASE @cPUOM
      WHEN '1' THEN P.PackUOM4 -- Pallet
      WHEN '2' THEN P.PackUOM1 -- Carton
      WHEN '3' THEN P.PackUOM2 -- InnerPack
      WHEN '4' THEN P.PackUOM8 -- OtherUnit1
      WHEN '5' THEN P.PackUOM9 -- OtherUnit2
      WHEN '6' THEN P.PackUOM3 -- Each
      ELSE P.PackUOM3 END
      HAVING SUM(L.Qty - L.QtyPicked - QtyAllocated) > 0
      ORDER BY L.SKU

      -- If pallet is multi sku/pallet, proceed with the next sku
      IF ISNULL(@cSKU, '') <> '' AND @c_PickByCase <> '1' -- (ChewKP04)
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cID          --ID
         SET @cOutField02 = @cStorerkey   --StorerKey
         SET @cOutField03 = @cSKU         --SKU
         SET @cOutField04 = @cDescr1      --StorerKey
         SET @cOutField05 = @cDescr1      --ID
         SET @cOutField06 = rdt.rdtConvUOMQty (@cStorerkey, @cSKU, @nQty, '6', @cPUOM) --Qty
         SET @cOutField07 = @cUOM         --UOM
         SET @cOutField08 = @cFromLOC     --FROM LOC
         SET @cOutField09 = @cToLOC       --TO LOC

         -- Go to next screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1

         GOTO Quit
      END
      ELSE
      BEGIN
         -- Finish pallet putaway, goto confirmation message screen

        /**************************************************/
        -- If RDT User Confirm ToLoc
        -- 1. Delete From RFPutaway Table
        -- 2. Deduct Pending Move in from LotxLocxID
        -- (ChewKP10) Start
        /**************************************************/
        --SET @cLot = ''
         SET @n_RFQty = 0

         SET @c_RFLoc = ''
         SET @c_RFLot = ''
         SET @c_RFSKU = ''
         SET @c_RFID = ''
         SET @c_RFStorerkey = ''

         DECLARE curPending CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT   Qty
                , SuggestedLoc
                , Lot
                , SKU
                , ID
                , Storerkey
         FROM dbo.RFPutaway WITH (NOLOCK)
         WHERE ptcid = @cUserName

         OPEN curPending
         FETCH NEXT FROM curPending INTO @n_RFQty, @c_RFLoc, @c_RFLot, @c_RFSKU, @c_RFID, @c_RFStorerkey
         WHILE @@FETCH_STATUS <> -1
         BEGIN

         IF EXISTS (SELECT 1 FROM LotxLocxID WITH (NOLOCK)
            WHERE Loc = @c_RFLoc
            AND Lot = @c_RFLot
            AND SKU = @c_RFSKU
            AND ID = @c_RFID
            AND Storerkey = @c_RFStorerkey)
         BEGIN
            BEGIN TRAN

             UPDATE dbo.LotxLocxID WITH (ROWLOCK)
                   SET PendingMoveIn = CASE WHEN PendingMoveIn - @n_RFQty > 0 THEN PendingMoveIn - @n_RFQty
                                       ELSE 0
                                       END
             WHERE Lot = @c_RFLot
                   AND SKU = @c_RFSKU
                   AND Loc = @c_RFLoc
                   AND ID  = @c_RFID
                   AND Storerkey = @c_RFStorerkey

             IF @@Error <> 0
             BEGIN
               SET @nErrNo = 50076
               SET @cErrMsg = rdt.rdtgetmessage( 50076, @cLangCode, 'DSP') --50076^UPD LLI FAIL
               ROLLBACK TRAN
             END
             ELSE
             BEGIN
               COMMIT TRAN
             END
            END

            BEGIN TRAN
            DELETE dbo.RFPUTAWAY WITH (ROWLOCK)
            WHERE Lot = @c_RFLot
                   AND SKU = @c_RFSKU
                   AND SuggestedLoc = @c_RFLoc
                   AND ID  = @c_RFID
                   AND Storerkey = @c_RFStorerkey
            IF @@Error <> 0
            BEGIN
               SET @nErrNo = 50077
               SET @cErrMsg = rdt.rdtgetmessage( 50077, @cLangCode, 'DSP') --50077^UPD RPA FAIL
               ROLLBACK TRAN
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END

            FETCH NEXT FROM curPending INTO @n_RFQty, @c_RFLoc, @c_RFLot, @c_RFSKU, @c_RFID, @c_RFStorerkey
         END
         CLOSE curPending
         DEALLOCATE curPending

       /**************************************************/
        -- (ChewKP10) End
       /**************************************************/

   SET @nScn = @nScn + 1
   SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN

       /**************************************************/
        -- If RDT User ESC ToLoc
        -- 1. Delete From RFPutaway Table
        -- 2. Deduct Pending Move in from LotxLocxID
        -- (ChewKP10) Start
        /**************************************************/
        --SET @cLot = ''
         SET @n_RFQty = 0

         SET @c_RFLoc = ''
         SET @c_RFLot = ''
         SET @c_RFSKU = ''
         SET @c_RFID = ''
         SET @c_RFStorerkey = ''

         DECLARE curPending CURSOR LOCAL FAST_FORWARD READ_ONLY FOR


         SELECT   Qty
                , SuggestedLoc
                , Lot
                , SKU
                , ID
                , Storerkey
         FROM dbo.RFPutaway WITH (NOLOCK)
         WHERE ID = @cID
            AND FromLOC = @cFromLOC

         OPEN curPending
         FETCH NEXT FROM curPending INTO @n_RFQty, @c_RFLoc, @c_RFLot, @c_RFSKU, @c_RFID, @c_RFStorerkey
         WHILE @@FETCH_STATUS <> -1
         BEGIN

          IF EXISTS (SELECT 1 FROM LotxLocxID WITH (NOLOCK)
              WHERE Loc = @c_RFLoc
              AND Lot = @c_RFLot
              AND SKU = @c_RFSKU
              AND ID = @c_RFID
              AND Storerkey = @c_RFStorerkey
              )
            BEGIN
               BEGIN TRAN
               UPDATE dbo.LotxLocxID WITH (ROWLOCK)
                  SET PendingMoveIn = CASE WHEN PendingMoveIn - @n_RFQty > 0 THEN PendingMoveIn - @n_RFQty
                                      ELSE 0
                                      END
               WHERE Lot = @c_RFLot
                     AND SKU = @c_RFSKU
                     AND Loc = @c_RFLoc
                     AND ID  = @c_RFID
                     AND Storerkey = @c_RFStorerkey
               IF @@Error <> 0
               BEGIN
                 SET @nErrNo = 50081
                 SET @cErrMsg = rdt.rdtgetmessage( 50083, @cLangCode, 'DSP') --50081^UPD LLI FAIL
                  ROLLBACK TRAN
               END
               ELSE
                     BEGIN
                     COMMIT TRAN
               END

               BEGIN TRAN
               DELETE dbo.RFPUTAWAY WITH (ROWLOCK)
               WHERE Lot = @c_RFLot
                      AND SKU = @c_RFSKU
                      AND SuggestedLoc = @c_RFLoc
                      AND ID  = @c_RFID
                      AND Storerkey = @c_RFStorerkey
            
               IF @@Error <> 0
               BEGIN
                  SET @nErrNo = 50082
                  SET @cErrMsg = rdt.rdtgetmessage( 50080, @cLangCode, 'DSP') --50080^UPD RPA FAIL
                  ROLLBACK TRAN
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END
            END
            FETCH NEXT FROM curPending INTO @n_RFQty, @c_RFLoc, @c_RFLot, @c_RFSKU, @c_RFID, @c_RFStorerkey
         END
         CLOSE curPending
         DEALLOCATE curPending

       /**************************************************/
        -- (ChewKP10) End
       /**************************************************/
      DELETE FROM rdt.rdtPutawayLog
      WHERE Mobile = @nMobile
      AND ID = @cID
      AND Status = '0'

  IF @@ERROR <> 0
  BEGIN
   SET @nErrNo = 50068
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPAFailed'
   ROLLBACK TRAN
   GOTO QUIT
  END

      SET @cOutField01 = '' -- ID
      SET @cOutField02 = @cStorerkey
      SET @cOutField03 = '' -- FROM LOC

      SET @cID = ''
      SET @cFromLOC = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1

      IF @c_TMPATask = 1  And @c_PickByCase <> '1' -- SOS#157089
      BEGIN
   -- Delete Task Detail When User ESC from Screen --
   -- Delete First Task
   EXEC [rdt].[rdt_TMTask]
    @c_TaskKey       = @c_taskdetailkey1
   ,@c_TaskType      = 'PA'
   ,@c_RefTaskKey    = ''
   ,@c_storerkey     = ''
   ,@c_sku           = ''
   ,@c_lot           = ''
   ,@c_Fromloc       = ''
   ,@c_FromID        = ''
   ,@c_ToLoc         = ''
   ,@c_Toid          = ''
   ,@c_UOM       = ''
   ,@n_UOMQTY        = 0
   ,@n_QTY           = 0
   ,@c_sourcekey     = ''
   ,@c_sourcetype    = ''
   ,@c_TaskStatus    = ''
   ,@c_TaskFlag      = 'D'
   ,@c_UserName      = @cUserName
   ,@b_Success       = @b_Success OUTPUT
   ,@c_errmsg        = @c_errmsg OUTPUT
   ,@c_Areakey       = '' -- (ChewKP03) -- (ChewKP08)

   If @b_success = 0
   BEGIN
    SET @nErrNo = 50036
    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL TASK FAIL'
    GOTO Quit
   END

   -- Delete Second Task
   EXEC [rdt].[rdt_TMTask]
    @c_TaskKey       = @c_taskdetailkey2
   ,@c_TaskType      = 'PA'
   ,@c_RefTaskKey    = ''
   ,@c_storerkey     = ''
   ,@c_sku           = ''
   ,@c_lot           = ''
   ,@c_Fromloc       = ''
   ,@c_FromID        = ''
   ,@c_ToLoc         = ''
   ,@c_Toid          = ''
   ,@c_UOM           = ''
   ,@n_UOMQTY        = 0
   ,@n_QTY           = 0
   ,@c_sourcekey     = ''
   ,@c_sourcetype    = ''
   ,@c_TaskStatus    = ''
   ,@c_TaskFlag      = 'D'
   ,@c_UserName      = @cUserName
   ,@b_Success       = @b_Success OUTPUT
   ,@c_errmsg        = @c_errmsg OUTPUT
   ,@c_Areakey       = '' -- (ChewKP03) -- (ChewKP08)

   If @b_success = 0
   BEGIN
    SET @nErrNo = 50036
    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL TASK FAIL'
    GOTO Quit
   END

   SET @cStorerkey = 'ALL'
   SET @cOutField02 = 'ALL'
      END
      SET @nScn  = @nScn  - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   RollBackTran:
   BEGIN
      ROLLBACK TRAN rdtfnc_Pallet_Putaway -- Only rollback change made here
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END

END
GOTO Quit

/********************************************************************************
Step 4. scn = 923. Message screen
   Msg
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 0 OR @nInputKey = 1 -- Esc or No / Yes or Send
   BEGIN
  SET @cOutField01 = '' -- ID
  SET @cOutField02 = @cStorerkey
  SET @cOutField03 = '' -- FROM LOC

  SET @cID = ''
  SET @cFromLOC = ''

  -- SOS#157089
  IF @c_TMPATask = 1
  BEGIN
   SET @cOutField02 = 'ALL'
   SET @cStorerkey = 'ALL'
  END

  EXEC rdt.rdtSetFocusField @nMobile, 1

  -- Go back to putaway screen
  SET @nScn  = @nScn  - 3
  SET @nStep = @nStep - 3
 END
END
GOTO Quit

/********************************************************************************
Step 5. scn = 940. SKU
   SKU

********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cSKU = ISNULL(@cInField01,'')
      SET @cBarcode = ISNULL(@cInField01,'')

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cUPC    = @cSKU    OUTPUT, 
               @nQTY    = @nQTY    OUTPUT, 
               @nErrNo  = @nErrNo  OUTPUT, 
               @cErrMsg = @cErrMsg OUTPUT,
               @cType   = 'UPC'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cFromID  OUTPUT, @cFromLOC    OUTPUT, @cToLOC   OUTPUT, @cSKU  OUTPUT, ' +
               ' @nErrNo   OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, 
               @cID         OUTPUT, @cFromLOC    OUTPUT, @cToLOC       OUTPUT, @cSKU        OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Quit
      END
      
      SET @c_packkey = ''

      IF @c_PrePackByBOM = '1'
      BEGIN
         SET @c_BOMSKU = @cSKU
         SET @n_BOMCheck = 0

         SELECT @n_BOMCheck = Count(ComponentSKU) FROM dbo.BillOfMaterial (NOLOCK)
         WHERE SKU = @c_BOMSKU
         AND Storerkey = @cStorerkey

         IF ISNULL(@n_BOMCheck,0) > 1 AND @cNotMultiBOMSKUPlt = '1' -- (Vicky08)
         BEGIN
            SET @nErrNo = 50073
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BOM>1 SKU
            SET @cOutField01 = ''
            GOTO Quit
         END
      
         SELECT TOP 1 @c_packkey = U.Packkey FROM dbo.LOTxLOCxID LO (NOLOCK)  --(ung01)
         INNER JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON LA.LOT = LO.LOT
         INNER JOIN dbo.UPC U (NOLOCK) ON LA.Lottable03 = U.SKU AND LA.Storerkey = U.Storerkey    -- tlting01
         WHERE LA.Lottable03 = @c_BOMSKU
         AND LA.Storerkey = @cStorerKey            -- tlting01
         AND U.UOM = 'CS'

         IF ISNULL(@c_packkey,'') = ''
         BEGIN
            SET @nErrNo = 50055
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO PACKKEY
            SET @cOutField01 = ''
            GOTO Quit
         END

         SELECT @n_CaseCnt = CaseCnt, @cUOM = PackUOM1 FROM dbo.PACK (NOLOCK)
         WHERE PACKKEY = @c_packkey

         SELECT @n_TotalBOMQTY = SUM(QTY)  FROM dbo.BILLOFMATERIAL (NOLOCK) -- (ChewKP01)
         WHERE SKU = @c_BOMSKU
         AND STORERKEY = @cStorerkey

         -- (james02)
         SELECT @c_CompoenentSKU = ComponentSKU FROM dbo.BillOfMaterial WITH (NOLOCK)
         WHERE SKU = @c_BOMSKU
         AND STORERKEY = @cStorerkey

         IF NOT EXISTS (SELECT 1 FROM RDT.RDTPUTAWAYLOG WITH (NOLOCK) WHERE SKU = @c_CompoenentSKU AND ADDWHO = @cUserName AND Status = '0')
         BEGIN
            SET @n_PTCSCount = Round(ISNULL(@n_LocationLimit,0) / ISNULL(@n_CaseCnt * @n_TotalBOMQTY,0),0)
         END

        SELECT @cDescr1 = SUBSTRING(DESCR, 1, 20),  @cDescr2 = SUBSTRING(DESCR,21, 20)
        FROM dbo.SKU (NOLOCK)
        WHERE SKU = @c_BOMSKU
        AND STORERKEY = @cStorerkey

        SET @nCaseQty = 0

        SET @nCaseQty = (@n_TotalBOMQTY * @n_CaseCnt)

         SELECT @n_BOMQTY = LLI.QTY From dbo.LotxLocxID LLI ( NOLOCK)
         INNER JOIN LOTATTRIBUTE LA (NOLOCK) ON ( LA.Lot = LLI.Lot AND LA.Storerkey = LLI.Storerkey )
         WHERE LLI.ID = @cID
         AND   LLI.Storerkey = @cStorerkey
         AND   LLI.Loc = @cFromLOC
         AND   LA.Lottable03 = @c_BOMSKU

         SET @n_QtyCount = '1'
      END
      ELSE
      BEGIN
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
            SET @nErrNo = 50093
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            SET @cOutField01 = ''
            GOTO Quit
         END

         IF @nSKUCnt > 1 
         BEGIN
            SET @nErrNo = 50094
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarcodeSKU
            SET @cOutField01 = ''
            GOTO Quit
         END
         
         SELECT
            @n_QtyCount = SUM(L.Qty - L.QtyPicked - QtyAllocated),
            @c_packkey = S.PackKey,
            @cDescr1 = SUBSTRING(S.DESCR, 1, 20),
            @cDescr2 = SUBSTRING(S.DESCR,21, 20),
            @cUOM = CASE @cPUOM
            WHEN '1' THEN P.PackUOM4 -- Pallet
            WHEN '2' THEN P.PackUOM1 -- Carton
            WHEN '3' THEN P.PackUOM2 -- InnerPack
            WHEN '4' THEN P.PackUOM8 -- OtherUnit1
            WHEN '5' THEN P.PackUOM9 -- OtherUnit2
            WHEN '6' THEN P.PackUOM3 -- Each
            ELSE P.PackUOM3 END
         FROM dbo.LOTxLOCxID L (NOLOCK)
         JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = L.StorerKey AND S.SKU = L.SKU
         JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PackKey
         JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = L.LOC
         WHERE L.StorerKey = @cStorerkey
         AND LOC.Facility = @cFacility
         AND L.ID = @cID
         AND L.SKU = @cSKU
         GROUP BY L.LOC, L.SKU, S.PackKey, S.DESCR, P.PackUOM4,
         CASE @cPUOM
         WHEN '1' THEN P.PackUOM4 -- Pallet
         WHEN '2' THEN P.PackUOM1 -- Carton
         WHEN '3' THEN P.PackUOM2 -- InnerPack
         WHEN '4' THEN P.PackUOM8 -- OtherUnit1
         WHEN '5' THEN P.PackUOM9 -- OtherUnit2
         WHEN '6' THEN P.PackUOM3 -- Each
         ELSE P.PackUOM3 END
         HAVING SUM(L.Qty - L.QtyPicked - QtyAllocated) > 0
         ORDER BY L.SKU
         
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 50095
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No record
            SET @cOutField01 = ''
            GOTO Quit
         END
         
         SET @c_BOMSKU = @cSKU
      END

      -- Extended info
      SET @cOutField15 = ''
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cID, @cFromLOC, @cSKU, @nQTY, @cSuggestedLOC, @cToLOC, @cPickAndDropLOC, @cFinalLOC, ' +
               ' @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cID             NVARCHAR( 18), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nInputKey, @cStorerKey, @cFacility, @cID, @cFromLOC, @cSKU, @nQTY, @cSuggestedLOC, @cToLOC, @cPickAndDropLOC, @cFinalLOC, 
               @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField15 = @cExtendedInfo1
         END
      END
                  
      -- SOS#157089
      SET @cOutField01 = @c_BOMSKU
      SET @cOutField02 = @cDescr1
      SET @cOutField03 = @cDescr2
      SET @cOutField04 = @cUOM
      SET @cOutField05 = @n_QtyCount
      SET @cOutField06 = ''
      SET @c_ToLocCheck = '1'

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go back to success msg screen
      SET @nScn  = @nScn  + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN

      SET @cOutField01 = '' -- ID
      SET @cOutField02 = @cStorerkey
      SET @cOutField03 = ''

      SET @cID = ''
      SET @cFromLOC = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1


      IF @c_TMPATask = 1 -- SOS#157089
      BEGIN
         SET @cOutField02 = 'ALL'
      END

      -- Back to prev screen
      SET @nScn  = @nScn - 4
      SET @nStep = @nStep - 4
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 6. scn = 940. SKU, CaseID
   SKU
 DESCR
 DESCR
 UOM
 QTY
   CaseID
   CaseID
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @c_CaseID = ISNULL(@cInField06,'')

      IF @c_CaseID = ''
      BEGIN
         SET @nErrNo = 50052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseID Req
         EXEC rdt.rdtSetFocusField @nMobile, 6
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Get the default length of tote no
      SET @cDefaultCaseLength  = ''
      SET @cDefaultCaseLength  = rdt.RDTGetConfig( @nFunc, 'DefaultCaseLength', @cStorerkey)
      IF ISNULL(@cDefaultCaseLength, '') = ''
      BEGIN
         SET @cDefaultCaseLength = '8'  -- make it default to 8 digit if not setup
      END

      -- Check the length of tote no; 0 = no check (james01)
      IF @cDefaultCaseLength <> '0'
      BEGIN
         IF LEN(RTRIM(@c_CaseID)) <> @cDefaultCaseLength
         BEGIN
            SET @nErrNo = 50085
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV CASEID LEN
            EXEC rdt.rdtSetFocusField @nMobile, 6
            SET @cOutField06 = ''
            GOTO Quit
         END
      END

      -- (james05)
      SET @cExtendedPPAPutawaySP = rdt.RDTGetConfig( @nFunc, 'ExtendedPPAPutawaySP', @cStorerkey)
      IF @cExtendedPPAPutawaySP = '0'  
         SET @cExtendedPPAPutawaySP = ''
   
      IF @cExtendedPPAPutawaySP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPPAPutawaySP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedPPAPutawaySP) +
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @nStep, @nScn, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU,  
                 @nQty, @cCaseID, @nAfterStep OUTPUT, @nAfterScn OUTPUT, @cFinalLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nInputKey       INT, ' +
               '@nStep           INT, ' +
               '@nScn            INT, ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT,  ' +
               '@cCaseID         NVARCHAR( 20), ' +               
               '@nAfterStep      INT           OUTPUT, ' +
               '@nAfterScn       INT           OUTPUT, ' +                  
               '@cFinalLoc       NVARCHAR( 10) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' + 
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
                  
              
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nInputKey, @nStep, @nScn, @cStorerkey, @cFacility, @cFromLOC, @cID, @cSKU, 
               @nQty, @c_CaseID, @nAfterStep OUTPUT, @nAfterScn OUTPUT, @cFinalLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
               
            IF @nErrNo <> 0 
               GOTO Quit

            IF @nStep <> @nAfterStep AND @nScn <> @nAfterScn
            BEGIN
               SET @c_PieceLoc = '' 
               SELECT @c_PieceLoc = Loc, 
                      @n_LocationLimit = QtyLocationLimit
               FROM dbo.SKUxLOC WITH (NOLOCK) 
               WHERE SKU = @cSKU 
               AND   Storerkey = @cStorerkey 
               AND   Locationtype = 'PICK'

               SELECT @c_Putawayzone = Putawayzone 
               FROM dbo.LOC WITH (NOLOCK)
               WHERE LOC = @c_PieceLoc
               AND   Facility = @cFacility

               SET @c_VirtualLoc = ''
               SELECT @c_VirtualLoc = InLoc 
               FROM dbo.PutawayZone WITH (NOLOCK)
               WHERE Putawayzone = @c_Putawayzone
                        
               -- Prompt To Loc
               SET @cSuggestedLOC = @c_VirtualLOC

               SET @cOutField01 = @c_VirtualLOC
               SET @cOutField02 = ''
               SET @cOutField03 = 'THESE CASES WILL'
               SET @cOutField04 = 'BE PUT TO'
               SET @cOutField05 = 'TRANSIT LOC'

               -- Go to next screen
               SET @nScn = @nAfterScn
               SET @nStep = @nAfterStep

               GOTO Quit
            END
            ELSE
            BEGIN
               SET @cOutField06 = ''            
            END
         END
      END
      ELSE
      BEGIN
         -- Make sure the Case ID scanned is not a BOM SKU
         IF EXISTS (SELECT 1 FROM dbo.BillOfMaterial WITH (NOLOCK)
            WHERE StorerKey = @cStorerkey AND SKU = @c_CaseID)
         BEGIN
            SET @nErrNo = 50086
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SCAN CASE ID
            EXEC rdt.rdtSetFocusField @nMobile, 6
            SET @cOutField06 = ''
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail (NOLOCK) WHERE CASEID = @c_CaseID )
         BEGIN
            SET @nErrNo = 50063
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseID In Used
            EXEC rdt.rdtSetFocusField @nMobile, 6
            SET @cOutField06 = ''
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM rdt.rdtPutawayLog (NOLOCK) WHERE CASEID = @c_CaseID AND Status = '0')
         BEGIN
            SET @nErrNo = 50071
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseID In Used
            EXEC rdt.rdtSetFocusField @nMobile, 6
            SET @cOutField06 = ''
            GOTO Quit
         END

         SET @c_TMPATask = rdt.RDTGetConfig( @nFunc, 'CreatePATask', @cStorerkey)

         IF @c_PrePackByBOM = '1'
         BEGIN
            SELECT @n_CaseCnt = CaseCnt, @cUOM = PackUOM1 FROM dbo.PACK (NOLOCK)
            WHERE PACKKEY = @c_packkey

            SELECT @n_TotalBOMQTY = SUM(QTY) ,@c_CompoenentSKU = ComponentSKU  FROM dbo.BILLOFMATERIAL (NOLOCK) -- (ChewKP01)
            WHERE SKU = @c_BOMSKU
            AND STORERKEY = @cStorerkey
            GROUP BY ComponentSKU

            SET @nCaseQty = 0

            SET @nCaseQty = (@n_TotalBOMQTY * @n_CaseCnt)

            SET @n_QtyCount = @nQTY / (@n_TotalBOMQTY * @n_CaseCnt) -- (Vicky05)

            SET @c_CompoenentSKU  = ISNULL(@c_CompoenentSKU, '')

            -- Get Lot for PalletID AND BOMSKU --
            SET @c_IDLot = '' -- (ChewKP06)

            SELECT @c_IDLot = LLI.Lot From dbo.LotxLocxID LLI ( NOLOCK)
            INNER JOIN LOTATTRIBUTE LA (NOLOCK) ON ( LA.Lot = LLI.Lot AND LA.Storerkey = LLI.Storerkey )
            WHERE LLI.ID = @cID
            AND   LLI.Storerkey = @cStorerkey
            AND   LLI.Loc = @cFromLOC
            AND   LA.Lottable03 = @c_BOMSKU
         END
         ELSE
         BEGIN
            SELECT @n_CaseCnt = CaseCnt, @cUOM = PackUOM1 FROM dbo.PACK (NOLOCK)
            WHERE PACKKEY = @c_packkey

            SET @nCaseQty = 0

            SET @nCaseQty = @n_CaseCnt

            SET @n_QtyCount = @nQTY / @n_CaseCnt

            SET @c_CompoenentSKU = @c_BOMSKU
         END

         --SET @n_QtyCount = @n_QtyCount - 1
         SET @nQty = @nQty - @nCaseQty
         SET @n_PTCSCount = @n_PTCSCount - 1

         SET @cPackKey = @c_packkey

         -- (ChewKP06) Trace to Traceinfo Start
         INSERT INTO dbo.TRACEINFO ( TraceName , TimeIn , Step1 , Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
         VALUES ('rdtfnc_PalletPutaway', GetDate(), @nMobile, @cStorerkey, @c_CompoenentSKU, @c_IDLot,  @c_BOMSKU, @c_CaseID, @nCaseQty, @cID, @c_PieceLoc, @c_packkey)
         -- (ChewKP06) End

         -- (ChewKP06)
         IF ISNULL(RTRIM(@c_IDLOT),'') = ''
         BEGIN
            SET @nErrNo = 50072
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LotNotFound'
            EXEC rdt.rdtSetFocusField @nMobile, 6
            SET @cOutField06 = ''
            GOTO QUIT
         END

         -- Insert into Putaway Table for Retrieval in ToLOC Screen --
         INSERT INTO rdt.rdtPutawayLog (mobile ,status ,Storerkey ,SKU ,Lot ,UOM ,Sourcekey ,caseID ,Qty ,ID , FromLoc , Packkey)
         VALUES (@nMobile ,'0' , @cStorerkey , @c_CompoenentSKU , @c_IDLot, '6', @c_BOMSKU , @c_CaseID , @nCaseQty ,@cID , @c_PieceLoc , @c_packkey )

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50065
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPAFailed'
            EXEC rdt.rdtSetFocusField @nMobile, 6
            SET @cOutField06 = ''
            GOTO QUIT
         END

         -- (james02)
         -- Get total qty that is already confirm putaway and compare with SKUxLOC.QtyLocationLimit
         -- Make sure the qty to be putaway can only exceed SKUxLOC.QtyLocationLimit by 1 case max
         -- Sometimes the BOM case can be received in diff component qty
         -- ex. SKUxLOC.QtyLocationLimit = 50; case1=10, case2=7, case3=10, case4=10, case5=10, case6=10
         -- total 6 case, total PA qty = 57, 1 case over the max
         SET @nSUM_PALog = 0
         SELECT @nSUM_PALog = ISNULL(SUM(Qty), 0) FROM RDT.RDTPutAwayLog WITH (NOLOCK)
         WHERE ID = @cID
         AND SKU = @c_CompoenentSKU
         AND Status = '0'
         AND StorerKey = @cStorerkey
         AND Mobile = @nMobile

         IF @nSUM_PALog < @n_LocationLimit AND @nQty <> 0   -- (james02)
         BEGIN
            -- Go back to BOMSKU Screen
            --SET @nQty = @nQty - @nCaseQty
            SET @cOutField01 = ''

            SET @nScn  = @nScn  - 1
            SET @nStep = @nStep - 1
            GOTO QUIT
         END
         ELSE
         BEGIN
            -- Prompt To Loc
            SET @cSuggestedLOC = @c_VirtualLOC

            SET @cOutField01 = @c_VirtualLOC
            SET @cOutField02 = ''
            SET @cOutField03 = 'THESE CASES WILL'
            SET @cOutField04 = 'BE PUT TO'
            SET @cOutField05 = 'TRANSIT LOC'

            SET @nScn  = @nScn  - 3
            SET @nStep = @nStep - 3
         END
      END

      -- Extended info
      SET @cOutField15 = ''
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cID, @cFromLOC, @cSKU, @nQTY, @cSuggestedLOC, @cToLOC, @cPickAndDropLOC, @cFinalLOC, ' +
               ' @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cID             NVARCHAR( 18), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nInputKey, @cStorerKey, @cFacility, @cID, @cFromLOC, @cSKU, @nQTY, @cSuggestedLOC, @cToLOC, @cPickAndDropLOC, @cFinalLOC, 
               @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField15 = @cExtendedInfo1
         END
      END      
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      DELETE FROM rdt.rdtPutawayLog
      WHERE Mobile = @nMobile
      AND ID = @cID
      AND Status = '0'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 50066
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPAFailed'
         ROLLBACK TRAN
         GOTO QUIT
      END

      SET @cOutField01 = '' -- ID
      SET @cOutField02 = @cStorerkey
      SET @cOutField03 = ''

      SET @cID = ''
      SET @cFromLOC = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1


      IF @c_TMPATask = 1 -- SOS#157089
      BEGIN
         SET @cOutField02 = 'ALL'
      END

      -- Back to prev screen
      SET @nScn  = @nScn - 5
      SET @nStep = @nStep - 5
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 7. Scn = 942
   Confirm LPN#
   LPN#
********************************************************************************/
Step_7:
BEGIN
   DECLARE @cScannedUCCNo NVARCHAR(20)

   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cScannedUCCNo = ISNULL(@cInField08,'')

      IF @cScannedUCCNo = ''
      BEGIN
         SET @nErrNo = 50088
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN Required
         EXEC rdt.rdtSetFocusField @nMobile, 8
         SET @cOutField08 = ''
         GOTO Quit
      END
      IF @cScannedUCCNo <> @cUCCNo
      BEGIN
         SET @nErrNo = 50090
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LPN
         EXEC rdt.rdtSetFocusField @nMobile, 8
         SET @cOutField08 = ''
         GOTO Quit
      END

      IF NOT EXISTS(SELECT 1 FROM UCC WITH (NOLOCK)
                    WHERE Storerkey = @cStorerkey
                    AND   UCCNo = @cScannedUCCNo
                    AND   LOC = @cFromLOC
                    AND   ID = @cID)
      BEGIN
         SET @nErrNo = 50089
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN Already PA
         EXEC rdt.rdtSetFocusField @nMobile, 8
         SET @cOutField08 = ''
         GOTO Quit
      END

      SET @cLOT = ''
      SELECT TOP 1 @cLOT = ISNULL(Lot,'')
      FROM UCC WITH (NOLOCK)
      WHERE Storerkey = @cStorerkey
      AND   UCCNo = @cScannedUCCNo

      SET @nPutAwayQty = 0
      SELECT @nPutAwayQty= ISNULL((QTY - QTYALLOCATED - QTYPICKED),0)
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerkey
      AND SKU = @cSKU
      AND LOT = @cLOT
      AND LOC = @cFromLOC
      AND ID  = @cID

      IF @nUCCQTY > @nPutAwayQty
      BEGIN
         SET @nErrNo = 50087
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN Qty > QOH
         EXEC rdt.rdtSetFocusField @nMobile, 8
         SET @cOutField08 = ''
         GOTO Quit
      END
      ELSE
         SET @nPutAwayQty = @nUCCQty

      SELECT @cPackUOM3 = PACKUOM3
      FROM   dbo.PACK WITH (NOLOCK)
      WHERE  PackKey = @cPackKey

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_Pallet_Putaway2 -- For rollback or commit only our own transaction

      -- NOTE: Not convert QTY as nspItrnAddMove will convert QTY based on pass-in UOM
      EXEC dbo.nspRFPA02
         @c_sendDelimiter = '`'           -- NVARCHAR(1)
         , @c_ptcid         = 'RDT'         -- NVARCHAR(5)
         , @c_userid        = 'RDT'         -- NVARCHAR(10)
         , @c_taskId        = 'RDT'         -- NVARCHAR(10)
         , @c_databasename  = NULL          -- NVARCHAR(5)
         , @c_appflag       = NULL          -- NVARCHAR(2)
         , @c_recordType    = NULL          -- NVARCHAR(2)
         , @c_server        = NULL          -- NVARCHAR(30)
         , @c_storerkey     = @cStorerkey   -- NVARCHAR(30)
         , @c_lot           = @cLOT         -- NVARCHAR(10) -- optional
         , @c_sku           = @cSKU         -- NVARCHAR(30)
         , @c_fromloc       = @cFromLOC     -- NVARCHAR(18)
         , @c_fromid        = @cID          -- NVARCHAR(18)
         , @c_toloc         = @cToLOC       -- NVARCHAR(18)
         , @c_toid          = ''       -- NVARCHAR(18) -- SET TO ID To CLEAR Force loose ID
         , @n_qty           = @nPutAwayQty  -- int
         , @c_uom           = @cPackUOM3    -- NVARCHAR(10)
         , @c_packkey       = @cPackKey     -- NVARCHAR(10) -- optional
         , @c_reference     = ' '           -- NVARCHAR(10) -- not used
         , @c_outstring     = @c_outstring  OUTPUT   -- NVARCHAR(255)  OUTPUT
         , @b_Success       = @b_Success    OUTPUT   -- int        OUTPUT
         , @n_err           = @n_err        OUTPUT   -- int  OUTPUT
         , @c_errmsg        = @c_errmsg     OUTPUT   -- NVARCHAR(250)  OUTPUT

      IF @n_err <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @n_err, @cLangCode, 'DSP')
         GOTO Step_7_RollBackTran
      END
      ELSE
      BEGIN
         -- Update the UCC table, to remove the Carton From Pallet ID

         -- (ChewKP12)
         -- (Shong04)
         SET @cLoseID = '0'

         SELECT @cLoseID = ISNULL(LoseID,'0')
         From dbo.LOC WITH (NOLOCK)
         WHERE Loc = @cToLoc

         UPDATE UCC WITH (ROWLOCK)
            SET ID = CASE WHEN @cLoseID = '1' THEN '' ELSE ID END,
            UCC.Loc = @cToLOC,
            UCC.EditWho  = sUser_sName(),
            UCC.EditDate = GETDATE()
         WHERE Storerkey = @cStorerkey
         AND   UCCNo = @cScannedUCCNo

         -- (Vicky06) EventLog - QTY
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerkey    = @cStorerkey,
            @cLocation     = @cFromLOC,
            @cToLocation   = @cToLOC,
            @cID           = @cID,
            @cToID         = @cID,
            @cSKU          = @cSKU,
            @cUOM          = @cPackUOM3,
            @nQTY          = @nPutAwayQty,
            @cLot          = @cLOT,
            @cRefNo3       = @cScannedUCCNo
      END

      COMMIT TRAN rdtfnc_Pallet_Putaway -- Only commit change made here
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN


      SET @nQTY = @nQTY - @nPutAwayQty
      SET @cSKU = ''

      IF ISNULL(@cFromLOC, '') <> ''
      BEGIN
         SELECT
            @cSKU = L.SKU,
            @nQty = SUM(L.Qty - L.QtyPicked - QtyAllocated),
            @cPackKey = S.PackKey,
            @cDescr1 = SUBSTRING(S.DESCR, 1, 20),
            @cDescr2 = SUBSTRING(S.DESCR,21, 20),
            @cUOM = CASE @cPUOM
               WHEN '1' THEN P.PackUOM4 -- Pallet
               WHEN '2' THEN P.PackUOM1 -- Carton
               WHEN '3' THEN P.PackUOM2 -- InnerPack
               WHEN '4' THEN P.PackUOM8 -- OtherUnit1
               WHEN '5' THEN P.PackUOM9 -- OtherUnit2
               WHEN '6' THEN P.PackUOM3 -- Each
               ELSE P.PackUOM3 END
         FROM dbo.LOTxLOCxID L (NOLOCK)
         JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = L.StorerKey AND S.SKU = L.SKU
         JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PackKey
         JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = L.LOC
         WHERE L.StorerKey = @cStorerkey
         AND LOC.Facility = @cFacility
         AND L.ID = @cID
         AND L.LOC = @cFromLOC
         GROUP BY L.SKU, S.PackKey, S.DESCR, P.PackUOM4,
         CASE @cPUOM
         WHEN '1' THEN P.PackUOM4 -- Pallet
         WHEN '2' THEN P.PackUOM1 -- Carton
         WHEN '3' THEN P.PackUOM2 -- InnerPack
         WHEN '4' THEN P.PackUOM8 -- OtherUnit1
         WHEN '5' THEN P.PackUOM9 -- OtherUnit2
         WHEN '6' THEN P.PackUOM3 -- Each
         ELSE P.PackUOM3 END
         HAVING SUM(L.Qty - L.QtyPicked - QtyAllocated) > 0
         ORDER BY L.SKU
      END
      ELSE
      BEGIN
         SELECT
            @cFromLOC = L.LOC,
            @cSKU = L.SKU,
            @nQty = SUM(L.Qty - L.QtyPicked - QtyAllocated),
            @cPackKey = S.PackKey,
            @cDescr1 = SUBSTRING(S.DESCR, 1, 20),
            @cDescr2 = SUBSTRING(S.DESCR,21, 20),
            @cUOM = CASE @cPUOM
               WHEN '1' THEN P.PackUOM4 -- Pallet
               WHEN '2' THEN P.PackUOM1 -- Carton
               WHEN '3' THEN P.PackUOM2 -- InnerPack
               WHEN '4' THEN P.PackUOM8 -- OtherUnit1
               WHEN '5' THEN P.PackUOM9 -- OtherUnit2
               WHEN '6' THEN P.PackUOM3 -- Each
               ELSE P.PackUOM3 END
         FROM dbo.LOTxLOCxID L (NOLOCK)
         JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = L.StorerKey AND S.SKU = L.SKU
         JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PackKey
         JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = L.LOC
         WHERE L.StorerKey = @cStorerkey
         AND LOC.Facility = @cFacility
         AND L.ID = @cID
         GROUP BY L.LOC, L.SKU, S.PackKey, S.DESCR, P.PackUOM4,
         CASE @cPUOM
         WHEN '1' THEN P.PackUOM4 -- Pallet
         WHEN '2' THEN P.PackUOM1 -- Carton
         WHEN '3' THEN P.PackUOM2 -- InnerPack
         WHEN '4' THEN P.PackUOM8 -- OtherUnit1
         WHEN '5' THEN P.PackUOM9 -- OtherUnit2
         WHEN '6' THEN P.PackUOM3 -- Each
         ELSE P.PackUOM3 END
         HAVING SUM(L.Qty - L.QtyPicked - QtyAllocated) > 0
         ORDER BY L.SKU
      END

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @cID = ''
         SET @cFromLOC = ''
         SET @cOutField01 = ''
         SET @cOutField03 = ''
         SET @cToLOC = ''

         SET @nScn  = @nScn  - 3
         SET @nStep = @nStep - 3

         GOTO Quit
      END

      -- Prep next screen var
      SET @cOutField01 = @cID          --ID
      SET @cOutField02 = @cStorerkey   --StorerKey
      SET @cOutField03 = @cSKU         --SKU
      SET @cOutField04 = @cDescr1      --DESC 1
      SET @cOutField05 = @cDescr2      --DESC 2
      SET @cOutField06 = rdt.rdtConvUOMQty (@cStorerkey, @cSKU, @nQty, '6', @cPUOM) --Qty
      SET @cOutField07 = @cUOM         --UOM
      SET @cOutField08 = @cFromLOC     --FROM LOC
      SET @cOutField09 = ''            --TO LOC

      SET @cToLOC = ''

      -- Go to next screen
      SET @nScn  = @nScn  - 5
      SET @nStep = @nStep - 5
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO Quit


      IF ISNULL(@cFromLOC, '') <> ''
      BEGIN
         SELECT
            @cSKU = L.SKU,
            @nQty = SUM(L.Qty - L.QtyPicked - QtyAllocated),
            @cPackKey = S.PackKey,
            @cDescr1 = SUBSTRING(S.DESCR, 1, 20),
            @cDescr2 = SUBSTRING(S.DESCR,21, 20),
            @cUOM = CASE @cPUOM
               WHEN '1' THEN P.PackUOM4 -- Pallet
               WHEN '2' THEN P.PackUOM1 -- Carton
               WHEN '3' THEN P.PackUOM2 -- InnerPack
               WHEN '4' THEN P.PackUOM8 -- OtherUnit1
               WHEN '5' THEN P.PackUOM9 -- OtherUnit2
               WHEN '6' THEN P.PackUOM3 -- Each
               ELSE P.PackUOM3 END
         FROM dbo.LOTxLOCxID L (NOLOCK)
         JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = L.StorerKey AND S.SKU = L.SKU
         JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PackKey
         JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = L.LOC
         WHERE L.StorerKey = @cStorerkey
         AND LOC.Facility = @cFacility
         AND L.ID = @cID
         AND L.LOC = @cFromLOC
         GROUP BY L.SKU, S.PackKey, S.DESCR, P.PackUOM4,
         CASE @cPUOM
         WHEN '1' THEN P.PackUOM4 -- Pallet
         WHEN '2' THEN P.PackUOM1 -- Carton
         WHEN '3' THEN P.PackUOM2 -- InnerPack
         WHEN '4' THEN P.PackUOM8 -- OtherUnit1
         WHEN '5' THEN P.PackUOM9 -- OtherUnit2
         WHEN '6' THEN P.PackUOM3 -- Each
         ELSE P.PackUOM3 END
         HAVING SUM(L.Qty - L.QtyPicked - QtyAllocated) > 0
         ORDER BY L.SKU
      END
      ELSE
      BEGIN
         SELECT
            @cFromLOC = L.LOC,
            @cSKU = L.SKU,
            @nQty = SUM(L.Qty - L.QtyPicked - QtyAllocated),
            @cPackKey = S.PackKey,
            @cDescr1 = SUBSTRING(S.DESCR, 1, 20),
            @cDescr2 = SUBSTRING(S.DESCR,21, 20),
            @cUOM = CASE @cPUOM
               WHEN '1' THEN P.PackUOM4 -- Pallet
               WHEN '2' THEN P.PackUOM1 -- Carton
               WHEN '3' THEN P.PackUOM2 -- InnerPack
               WHEN '4' THEN P.PackUOM8 -- OtherUnit1
               WHEN '5' THEN P.PackUOM9 -- OtherUnit2
               WHEN '6' THEN P.PackUOM3 -- Each
               ELSE P.PackUOM3 END
         FROM dbo.LOTxLOCxID L (NOLOCK)
         JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = L.StorerKey AND S.SKU = L.SKU
         JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PackKey
         JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = L.LOC
         WHERE L.StorerKey = @cStorerkey
         AND LOC.Facility = @cFacility
         AND L.ID = @cID
         GROUP BY L.LOC, L.SKU, S.PackKey, S.DESCR, P.PackUOM4,
         CASE @cPUOM
         WHEN '1' THEN P.PackUOM4 -- Pallet
         WHEN '2' THEN P.PackUOM1 -- Carton
         WHEN '3' THEN P.PackUOM2 -- InnerPack
         WHEN '4' THEN P.PackUOM8 -- OtherUnit1
         WHEN '5' THEN P.PackUOM9 -- OtherUnit2
         WHEN '6' THEN P.PackUOM3 -- Each
         ELSE P.PackUOM3 END
         HAVING SUM(L.Qty - L.QtyPicked - QtyAllocated) > 0
         ORDER BY L.SKU
      END

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @cID = ''
         SET @cFromLOC = ''
         SET @cOutField01 = ''
         SET @cOutField03 = ''
         SET @cToLOC = ''

         SET @nScn  = @nScn  - 3
         SET @nStep = @nStep - 3

         GOTO Quit
      END

      -- Prep next screen var
      SET @cOutField01 = @cID          --ID
      SET @cOutField02 = @cStorerkey   --StorerKey
      SET @cOutField03 = @cSKU         --SKU
      SET @cOutField04 = @cDescr1      --DESC 1
      SET @cOutField05 = @cDescr2      --DESC 2
      SET @cOutField06 = rdt.rdtConvUOMQty (@cStorerkey, @cSKU, @nQty, '6', @cPUOM) --Qty
      SET @cOutField07 = @cUOM         --UOM
      SET @cOutField08 = @cFromLOC     --FROM LOC
      SET @cOutField09 = ''            --TO LOC

      SET @cToLOC = ''

      -- Go to next screen
      SET @nScn  = @nScn  - 5
      SET @nStep = @nStep - 5
      EXEC rdt.rdtSetFocusField @nMobile, 1

   END -- IF @nInputKey = 1

   IF @nInputKey = 0 -- Esc or No
   BEGIN

       /**************************************************/
        -- If RDT User ESC LPN#
        -- 1. Delete From RFPutaway Table
        -- 2. Deduct Pending Move in from LotxLocxID
        /**************************************************/
        --SET @cLot = ''
      SET @n_RFQty = 0

      SET @c_RFLoc = ''
      SET @c_RFLot = ''
      SET @c_RFSKU = ''
      SET @c_RFID = ''
      SET @c_RFStorerkey = ''

      DECLARE curPending CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

      SELECT   Qty
             , SuggestedLoc
             , Lot
             , SKU
             , ID
             , Storerkey
      FROM dbo.RFPutaway WITH (NOLOCK)
      WHERE ID = @cID
         AND FromLOC = @cFromLOC

      OPEN curPending
      FETCH NEXT FROM curPending INTO @n_RFQty, @c_RFLoc, @c_RFLot, @c_RFSKU, @c_RFID, @c_RFStorerkey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF EXISTS (SELECT 1 FROM LotxLocxID WITH (NOLOCK)
             WHERE Loc = @c_RFLoc
             AND Lot = @c_RFLot
             AND SKU = @c_RFSKU
             AND ID = @c_RFID
             AND Storerkey = @c_RFStorerkey
             )
         BEGIN
            BEGIN TRAN
            UPDATE dbo.LotxLocxID WITH (ROWLOCK)
                  SET PendingMoveIn = CASE WHEN PendingMoveIn - @n_RFQty > 0 THEN PendingMoveIn - @n_RFQty
                                      ELSE 0
                                      END
            WHERE Lot = @c_RFLot
                  AND SKU = @c_RFSKU
                  AND Loc = @c_RFLoc
                  AND ID  = @c_RFID
                  AND Storerkey = @c_RFStorerkey


            IF @@Error <> 0
            BEGIN
               SET @nErrNo = 50081
               SET @cErrMsg = rdt.rdtgetmessage( 50083, @cLangCode, 'DSP') --50081^UPD LLI FAIL
               ROLLBACK TRAN
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END
            
            BEGIN TRAN
            DELETE dbo.RFPUTAWAY WITH (ROWLOCK)
            WHERE Lot = @c_RFLot
                   AND SKU = @c_RFSKU
                   AND SuggestedLoc = @c_RFLoc
                   AND ID  = @c_RFID
                   AND Storerkey = @c_RFStorerkey
            IF @@Error <> 0
            BEGIN
               SET @nErrNo = 50082
               SET @cErrMsg = rdt.rdtgetmessage( 50080, @cLangCode, 'DSP') --50080^UPD RPA FAIL
               ROLLBACK TRAN
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END
         END
                      
         FETCH NEXT FROM curPending INTO @n_RFQty, @c_RFLoc, @c_RFLot, @c_RFSKU, @c_RFID, @c_RFStorerkey
      END
      CLOSE curPending
      DEALLOCATE curPending

      DELETE FROM rdt.rdtPutawayLog
      WHERE Mobile = @nMobile
      AND ID = @cID
      AND Status = '0'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 50068
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPAFailed'
         ROLLBACK TRAN
         GOTO QUIT
      END

      IF ISNULL(@cFromLOC, '') <> ''
      BEGIN
         SELECT
            @cSKU = L.SKU,
            @nQty = SUM(L.Qty - L.QtyPicked - QtyAllocated),
            @cPackKey = S.PackKey,
            @cDescr1 = SUBSTRING(S.DESCR, 1, 20),
            @cDescr2 = SUBSTRING(S.DESCR,21, 20),
            @cUOM = CASE @cPUOM
               WHEN '1' THEN P.PackUOM4 -- Pallet
               WHEN '2' THEN P.PackUOM1 -- Carton
               WHEN '3' THEN P.PackUOM2 -- InnerPack
               WHEN '4' THEN P.PackUOM8 -- OtherUnit1
               WHEN '5' THEN P.PackUOM9 -- OtherUnit2
               WHEN '6' THEN P.PackUOM3 -- Each
               ELSE P.PackUOM3 END
         FROM dbo.LOTxLOCxID L (NOLOCK)
         JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = L.StorerKey AND S.SKU = L.SKU
         JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PackKey
         JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = L.LOC
         WHERE L.StorerKey = @cStorerkey
         AND LOC.Facility = @cFacility
         AND L.ID = @cID
         AND L.LOC = @cFromLOC
         GROUP BY L.SKU, S.PackKey, S.DESCR, P.PackUOM4,
         CASE @cPUOM
         WHEN '1' THEN P.PackUOM4 -- Pallet
         WHEN '2' THEN P.PackUOM1 -- Carton
         WHEN '3' THEN P.PackUOM2 -- InnerPack
         WHEN '4' THEN P.PackUOM8 -- OtherUnit1
         WHEN '5' THEN P.PackUOM9 -- OtherUnit2
         WHEN '6' THEN P.PackUOM3 -- Each
         ELSE P.PackUOM3 END
         HAVING SUM(L.Qty - L.QtyPicked - QtyAllocated) > 0
         ORDER BY L.SKU
      END
      ELSE
      BEGIN
         SELECT
            @cFromLOC = L.LOC,
            @cSKU = L.SKU,
            @nQty = SUM(L.Qty - L.QtyPicked - QtyAllocated),
            @cPackKey = S.PackKey,
            @cDescr1 = SUBSTRING(S.DESCR, 1, 20),
            @cDescr2 = SUBSTRING(S.DESCR,21, 20),
            @cUOM = CASE @cPUOM
            WHEN '1' THEN P.PackUOM4 -- Pallet
            WHEN '2' THEN P.PackUOM1 -- Carton
            WHEN '3' THEN P.PackUOM2 -- InnerPack
            WHEN '4' THEN P.PackUOM8 -- OtherUnit1
            WHEN '5' THEN P.PackUOM9 -- OtherUnit2
            WHEN '6' THEN P.PackUOM3 -- Each
            ELSE P.PackUOM3 END
         FROM dbo.LOTxLOCxID L (NOLOCK)
         JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = L.StorerKey AND S.SKU = L.SKU
         JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PackKey
         JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = L.LOC
         WHERE L.StorerKey = @cStorerkey
         AND LOC.Facility = @cFacility
         AND L.ID = @cID
         GROUP BY L.LOC, L.SKU, S.PackKey, S.DESCR, P.PackUOM4,
         CASE @cPUOM
         WHEN '1' THEN P.PackUOM4 -- Pallet
         WHEN '2' THEN P.PackUOM1 -- Carton
         WHEN '3' THEN P.PackUOM2 -- InnerPack
         WHEN '4' THEN P.PackUOM8 -- OtherUnit1
         WHEN '5' THEN P.PackUOM9 -- OtherUnit2
         WHEN '6' THEN P.PackUOM3 -- Each
         ELSE P.PackUOM3 END
         HAVING SUM(L.Qty - L.QtyPicked - QtyAllocated) > 0
         ORDER BY L.SKU
      END

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @cID = ''
         SET @cFromLOC = ''
         SET @cOutField01 = ''
         SET @cOutField03 = ''

         SET @nScn  = @nScn  - 6
         SET @nStep = @nStep - 6

         GOTO Quit
      END

      -- Prep next screen var
      SET @cOutField01 = @cID          --ID
      SET @cOutField02 = @cStorerkey   --StorerKey
      SET @cOutField03 = @cSKU         --SKU
      SET @cOutField04 = @cDescr1      --DESC 1
      SET @cOutField05 = @cDescr2      --DESC 2
      SET @cOutField06 = rdt.rdtConvUOMQty (@cStorerkey, @cSKU, @nQty, '6', @cPUOM) --Qty
      SET @cOutField07 = @cUOM         --UOM
      SET @cOutField08 = @cFromLOC     --FROM LOC
      SET @cOutField09 = ''            --TO LOC

      SET @cToLOC = ''

      -- Go to next screen
      SET @nScn  = @nScn  - 5
      SET @nStep = @nStep - 5
      EXEC rdt.rdtSetFocusField @nMobile, 1

   END -- Input Key = 0
   GOTO Quit

   Step_7_RollBackTran:
   BEGIN
      ROLLBACK TRAN rdtfnc_Pallet_Putaway2 -- Only rollback change made here
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
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
      Func = @nFunc,
      Step = @nStep,
      Scn = @nScn,

      StorerKey    = @cStorerkey,
      Facility     = @cFacility,
      -- UserName     = @cUserName,
      Printer      = @cPrinter,

      V_Loc = @cLOC,
      V_SKU = @cSKU,
      V_UOM = @cUOM,
      V_ID  = @cID,
      V_Lot = @cLOT,
      V_QTY = @nQty,
      V_UCC = @cUCCNo,

      V_String1 = @cPackKey,
      V_String2 = @cFromLOC,
      V_String3 = @cToLOC,
      V_String4 = @cPUOM,
      V_String5 = @cSuggestedLOC,
      V_String6 = @c_taskdetailkey1,
      V_String7 = @c_taskdetailkey2,
      V_String8 = @cPickAndDropLoc,
      V_String9 = @c_TMPATask,
      V_String10 = @c_PutawayRules01,
      V_String11 = @c_PickByCase,
      V_String12 = @nCaseQty,
      V_String13 = @c_PieceLoc,
      V_String14 = @c_BOMSKU,
      V_String15 = @c_ComponentSKU,
      V_String16 = @n_PutawayCaseCount,
      V_String17 = @n_PTCSCount,
      V_String18 = @c_PrePackByBOM,
      V_String19 = @c_packkey,
      V_String20 = @c_VirtualLoc,
      V_String21 = @n_LocationLimit,
      V_String22 = @c_ToLocCheck,
      V_String23 = @n_BOMQTY,

      V_String24 = @cPalletType, -- (Shong001)
      V_String25 = @nUCCQty,     -- (Shong001)
      V_String26 = @cExtendedInfoSP,
      V_String27 = @cExtendedInfo1,
      V_String28 = @cFinalLOC,
      V_String29 = @cDecodeSP,

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
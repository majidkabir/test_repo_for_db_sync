SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PalletConsolidate_SSCC                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pallet consolidate & store detail to palletdetail           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 18-Mar-2016  1.0  James      SOS357366 - Created                     */
/* 27-May-2016  1.1  Leong      Bug fix (Leong01).                      */
/* 16-Jun-2016  1.2  James      Enhancement (james01)                   */
/* 12-Jul-2016  1.3  James      Add scn to confirm ctn count (james02)  */
/* 29-Aug-2016  1.4  James      Add LOC @ screen 2 (james03)            */
/*                              Add step 8 process                      */
/* 30-Sep-2016  1.5   Ung       Performance tuning                      */
/* 18-Nov-2016  1.6   James     Additional checking (james04)           */
/* 18-Sep-2017  1.7   James     WMS2991-Add ExtendedValidateSP (james05)*/
/* 27-Dec-2017  1.8   James     WMS3665-Add ExtVal @ step1 (james06)    */
/* 02-Jul-2018  1.9   James     WMS5526-Add ExtVal @ step6 (james07)    */
/* 13-Oct-2021  2.0   Chermaine WMS-18008 Add config in step2 to disable*/
/*                              cartonID column in step6 (cc01)         */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PalletConsolidate_SSCC](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variables
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @nMenu            INT,

   @cStorerKey       NVARCHAR( 15),
   @cUserName        NVARCHAR( 18),
   @cFacility        NVARCHAR( 5),
   @cPrinter         NVARCHAR( 10),
   @cFromLoc         NVARCHAR( 10),
   @cToLoc           NVARCHAR( 10),
   @cStorerGroup     NVARCHAR( 20),
   @cChkStorerKey    NVARCHAR( 15),
   @cFromID          NVARCHAR( 18),
   @cToID            NVARCHAR( 18),
   @cOption          NVARCHAR( 1),
   @cDataWindow      NVARCHAR( 50),
   @cTargetDB        NVARCHAR( 20),
   @cLabelPrinter    NVARCHAR( 10),
   @cPaperPrinter    NVARCHAR( 10),
   @cReportType      NVARCHAR( 10),
   @cPrintJobName    NVARCHAR( 60),
   @cHeight          NVARCHAR( 20),
   @cWeight          NVARCHAR( 20),
   @cOrderKey        NVARCHAR( 10),
   @cSSCC            NVARCHAR( 20),
   @cType            NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @cSKUDescr        NVARCHAR( 60),
   @cCurrentSKU      NVARCHAR( 20),
   @cSKU_StorerKey   NVARCHAR( 20),
   @cPUOM            NVARCHAR( 10),
   @cPUOM_Desc       NVARCHAR( 5),
   @cMUOM_Desc       NVARCHAR( 5),
   @cCartonID        NVARCHAR( 20),
   @cCartonBarcode   NVARCHAR( 60),
   @cCartonQty       NVARCHAR( 5),
   @cPackUOM3        NVARCHAR( 5), 
   @cPackUOM1        NVARCHAR( 5), 
   @cT_CaseID        NVARCHAR( 40), 
   @cActSKU          NVARCHAR( 20), 
   @cItemClass       NVARCHAR( 10), 
   @bSuccess         INT,
   @nSKUCnt          INT,
   @nCaseCnt         INT,
   @nPUOM_Div        INT,
   @nMultiStorer     INT,
   @nStorer_Cnt      INT,
   @nIDQty           INT,
   @nLOTIDQty        INT,
   @nQty             INT,
   @nSKU_CNT         INT,
   @nCurSKU_CNT      INT,
   @nQTY_Avail       INT,
   @nQTY_Alloc       INT,
   @nQTY_Pick        INT,
   @nPQTY_Avail      INT,
   @nPQTY_Alloc      INT,
   @nPQTY_Pick       INT,
   @nMQTY_Avail      INT,
   @nMQTY_Alloc      INT,
   @nMQTY_Pick       INT,
   @nBalQty          INT,
   @nPBalQty         INT,
   @nMBalQty         INT,
   @nQTY_Move        INT,
   @nPQTY_Move       INT,
   @nMQTY_Move       INT,
   @nMV_Alloc        INT,
   @nMV_PICK         INT,
   @nOrdCount        INT,
   @nPQTY            INT,
   @nMQTY            INT,
   @nTtl_Scanned     INT,
   @cPQTY            NVARCHAR( 5),
   @cMQTY            NVARCHAR( 5),
   @cPBalQty         NVARCHAR( 5),
   @cMBalQty         NVARCHAR( 5),
   @cToID_MBOLKey    NVARCHAR( 18),
   @cFromID_MBOLKey  NVARCHAR( 10),
   @cToID_OrderKey   NVARCHAR( 10),
   @cASRS_OrderKey   NVARCHAR( 10), -- (james04)

   @cSpecialInstruction    NVARCHAR( 20),
   @cDecodeCartonIDSP      NVARCHAR( 20),
   @cSQL                   NVARCHAR( MAX),
   @cSQLParam              NVARCHAR( MAX),
   @cFromID_OrderKey       NVARCHAR( 10),
   @cDisableCtnFieldSP     NVARCHAR( 20),
   @cDisableCtnField       NVARCHAR( 20),

   
   -- (james02)
   @nFromScn         INT,
   @nFromStep        INT,
   @nCartonCnt       INT,
   @cNoOfCarton      NVARCHAR( 5),

   -- (james03)
   @cSSCC2Validate   NVARCHAR( 30),
   @nSKUCount        INT,
   @nSSCCCount       INT,

   -- (james04)
   @cConsigneeKey    NVARCHAR( 15),
   
   -- (james05)
   @cExtendedValidateSP    NVARCHAR( 20), 
   @nQTY_Scanned           INT,
   @nIsUPC                 INT,
   @nBeforeScn             INT,
   @nBeforeStep            INT,
   
   --(cc01)
   @cCheckSSCC             NVARCHAR(11), 
   @cRemainSKU             NVARCHAR( 1),
   @cDecodeSKUSP           NVARCHAR(20),
   @cMultiSKUBarcode       NVARCHAR( 3),
   @cDoctype               NVARCHAR(5),
   @cFlowThStep4           NVARCHAR(1),
   @cMultiOrder            NVARCHAR(1),

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
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),
   @cDecodeLabelNo       NVARCHAR( 20),
   @c_LabelNo            NVARCHAR( 32)

DECLARE @c_ExecStatements     nvarchar(4000)
      , @c_ExecArguments      nvarchar(4000)

DECLARE
   @cErrMsg1    NVARCHAR( 20), @cErrMsg2    NVARCHAR( 20),
   @cErrMsg3    NVARCHAR( 20), @cErrMsg4    NVARCHAR( 20),
   @cErrMsg5    NVARCHAR( 20), @cErrMsg6    NVARCHAR( 20),
   @cErrMsg7    NVARCHAR( 20), @cErrMsg8    NVARCHAR( 20),
   @cErrMsg9    NVARCHAR( 20), @cErrMsg10   NVARCHAR( 20),
   @cErrMsg11   NVARCHAR( 20), @cErrMsg12   NVARCHAR( 20),
   @cErrMsg13   NVARCHAR( 20), @cErrMsg14   NVARCHAR( 20),
   @cErrMsg15   NVARCHAR( 20) 

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerGroup     = StorerGroup,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,

   @cStorerKey       = V_StorerKey,
   @cFromID          = V_ID,
   @cPUOM            = V_UOM,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cFromLOC         = V_LOC,

   @nBeforeScn       = V_Integer1,
   @nBeforeStep      = V_Integer2,

   @cToID            = V_String1,
   @nMultiStorer     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2, 5), 0) = 1 THEN LEFT( V_String2, 5) ELSE 0 END,
   @cSSCC            = V_String3,
   @cPUOM_Desc       = V_String4,
   @cMUOM_Desc       = V_String5,
   @nQTY_Avail       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7, 5), 0) = 1 THEN LEFT( V_String7, 5) ELSE 0 END,
   @nPQTY_Avail      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8, 5), 0) = 1 THEN LEFT( V_String8, 5) ELSE 0 END,
   @nMQTY_Avail      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END, 
   @nQTY_Alloc       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String10, 5), 0) = 1 THEN LEFT( V_String10, 5) ELSE 0 END,
   @nQTY_Pick        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END,
   @nBalQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12, 5), 0) = 1 THEN LEFT( V_String12, 5) ELSE 0 END,
   @cOption          = V_String14,
   @nCurSKU_CNT      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END,
   @nFromScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16, 5), 0) = 1 THEN LEFT( V_String16, 5) ELSE 0 END,
   @nFromStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String17, 5), 0) = 1 THEN LEFT( V_String17, 5) ELSE 0 END,
   @cExtendedValidateSP = V_String18,
   @cCheckSSCC          = V_String19,  --(cc01)
   @cDisableCtnField    = V_String20,  --(cc01)
   @cActSKU             = V_String21,  --(cc01)
   @cRemainSKU          = V_String22,  --(cc01)
   @cDecodeSKUSP        = V_String23,
   @cMultiSKUBarcode    = V_String24,
   @cDisableCtnFieldSP  = V_String25,
   @cFlowThStep4        = V_String26,
   @cMultiOrder         = V_String27,

   @nPUOM_Div = V_PUOM_Div,
   
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

IF @nFunc = 1723  -- Pallet Consolidate SSCC
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0   GOTO Step_0 -- Menu. Func = 1723
   IF @nStep = 1   GOTO Step_1 -- Scn = 4540. From Pallet
   IF @nStep = 2   GOTO Step_2 -- Scn = 4541. Pallet info
   IF @nStep = 3   GOTO Step_3 -- Scn = 4542. To Pallet
   IF @nStep = 4   GOTO Step_4 -- Scn = 4543. Carton, Qty to move, Bal Qty (To Pallet)
   IF @nStep = 5   GOTO Step_5 -- Scn = 4544. Pallet, Qty to move, Option
   IF @nStep = 6   GOTO Step_6 -- Scn = 4545. Carton, Qty to move, Bal Qty (From Pallet)
   IF @nStep = 7   GOTO Step_7 -- Scn = 4546. No of carton  (james02)
   IF @nStep = 8   GOTO Step_8 -- Scn = 4547. From Pallet, SSCC#  (james03)
   IF @nStep = 9   GOTO Step_9 -- Scn = 3570. MULTISKU barcode (cc01)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1723
********************************************************************************/
Step_0:
BEGIN
   --SET @cPUOM = '2'
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName  

   -- Prepare next screen var
   SET @cOutField01 = '' -- ID

   -- Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

      -- Decode label
   SET @cDecodeSKUSP = rdt.RDTGetConfig( @nFunc, 'DecodeSKUSP', @cStorerKey)

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''
      
   --(cc01)
   SET @cCheckSSCC = rdt.RDTGetConfig( @nFunc, 'CheckSSCC', @cStorerKey)    

   SET @cDisableCtnField = ''       
    
   SET @cDisableCtnFieldSP = rdt.RDTGetConfig( @nFunc, 'DisableCtnFieldSP', @cStorerKey)    
   IF @cDisableCtnFieldSP = '0'    
      SET @cDisableCtnFieldSP = ''   

   SET @cFlowThStep4 = rdt.RDTGetConfig( @nFunc, 'FlowThStep4', @cStorerKey) 
   
   --(cc01)
   SET @cRemainSKU = rdt.RDTGetConfig( @nFunc, 'RemainSKU', @cStorerKey)    

   --(cc01)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)    

   SET @cMultiOrder=  rdt.RDTGetConfig( @nFunc, 'MultiOrder', @cStorerKey)    
  
   -- Go to next screen
   SET @nScn = 4540
   SET @nStep = 1

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

   -- Delete temp record from log table
   DELETE FROM rdt.rdtDPKLog 
   WHERE UserKey = @cUserName 
   AND   TaskDetailKey = CAST( @nFunc AS NVARCHAR( 4))
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 4540
   ID          (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cFromID = @cInField01

      -- Validate blank
      IF ISNULL(@cFromID, '') = ''
      BEGIN
         SET @nErrNo = 97751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Is Req
         GOTO Step_1_Fail
      END

      -- Check from id format (james01)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'FROMID', @cFromID) = 0
      BEGIN
         SET @nErrNo = 97752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_1_Fail
      END

      -- Check if pallet exists and with inventory
      SET @nStorer_Cnt = 0
      SELECT @nStorer_Cnt = COUNT( DISTINCT StorerKey)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   ( QtyAllocated + QtyPicked) > 0  -- Pallet has to be at least allocated or picked

      IF @nStorer_Cnt = 0
      BEGIN
         SET @nErrNo = 97753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_1_Fail
      END

      SET @nMultiStorer = 0

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 
                        FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                        WHERE LLI.ID = @cFromID 
                        AND   LOC.Facility = @cFacility
                        AND   LLI.Qty > 0
                        AND   EXISTS ( SELECT 1 FROM dbo.StorerGroup ST WITH (NOLOCK) 
                                       WHERE StorerGroup = @cStorerGroup 
                                       AND   ST.StorerKey = LLI.StorerKey))
         BEGIN
            SET @nErrNo = 97754
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            GOTO Step_1_Fail
         END

         SELECT TOP 1 @cChkStorerKey = LLI.StorerKey
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.ID = @cFromID 
         AND   LOC.Facility = @cFacility
         AND   LLI.Qty > 0

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
         SET @nMultiStorer = 1
      END

      -- Check pallet status
      IF EXISTS ( SELECT 1  
                  FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey 
                  AND   ID = @cFromID
                  AND   [Status] = '5'
                  AND   ShipFlag = 'Y')
      BEGIN
         SET @nErrNo = 97755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID is shipped
         GOTO Step_1_Fail
      END

      SET @cFromLOC = ''
      SELECT TOP 1 @cFromLOC = LLI.LOC 
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   LOC.LocationCategory = 'STAGING'
      AND   Qty > 0

      IF ISNULL( @cFromLOC, '') = ''
      BEGIN
         SET @nErrNo = 97756
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Empty pallet
         GOTO Step_1_Fail
      END

      IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
                  WHERE PD.StorerKey = @cStorerKey
                  AND   PD.ID = @cFromID
                  AND   PD.Status < '9'
                  AND   ISNULL( O.MBOLKey, '') = '')
      BEGIN
         SET @nErrNo = 97782
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Id not in mbol
         GOTO Step_1_Fail
      END

      -- (james06)
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
               ' @cFromID, @cToID, @cSKU, @nQTY, @nMultiStorer, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cToID           NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT,           ' +
               '@nMultiStorer    NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT           OUTPUT, ' + 
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
               
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
               @cFromID, @cToID, @cSKU, @nQTY, @nMultiStorer, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
            IF @nErrNo <> 0 
               GOTO Step_3_Fail 
         END
      END 

      SELECT @nIDQty = ISNULL( SUM( Qty), 0), 
             @nLOTIDQty = ISNULL( SUM( CAST( Lottable12 AS INT)), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   LOC.LocationCategory = 'STAGING'

      SELECT @cHeight = SUSR1,
             @cWeight = SUSR3
      FROM dbo.Storer WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   [Type] = '1'

      SELECT TOP 1 @cSpecialInstruction = O.Notes
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.ID = @cFromID
      AND   PD.Status < '9'

      -- Prepare next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = CASE WHEN @nIDQty = @nLOTIDQty THEN 'FULL' ELSE 'PARTIAL' END
      SET @cOutField03 = @cHeight
      SET @cOutField04 = @cWeight
      SET @cOutField05 = @cSpecialInstruction
      SET @cOutField06 = '' -- Option
      SET @cOutField07 = '' -- SKU
      SET @cOutField08 = @cFromLoc -- LOC  (james03)

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 6   -- Option

      -- Delete temp record from log table
      DELETE FROM rdt.rdtDPKLog 
      WHERE UserKey = @cUserName 
      AND   TaskDetailKey = CAST( @nFunc AS NVARCHAR( 4))

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

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- ID
      SET @cOutField02 = '' -- From Loc
      SET @cOutField03 = '' -- To Loc

      -- Delete temp record from log table
      DELETE FROM rdt.rdtDPKLog 
      WHERE UserKey = @cUserName 
      AND   TaskDetailKey = CAST( @nFunc AS NVARCHAR( 4))
   END

   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cFromID = ''

      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. Screen = 4541
   ID          (field01)
   MISC info   (field02)
   OPTION      (field06, input)
   SKU         (field07, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInField06
      SET @cActSKU = @cInField07

      -- Validate blank
      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 97757
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         GOTO Step_2_Fail
      END

      -- Validate option value
      IF @cOption NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 97758
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Step_2_Fail
      END

      IF ISNULL( @cFromID, '') = ''
      BEGIN
         SET @nErrNo = 97791
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv asrs plt
         GOTO Step_2_Fail
      END

      IF @cOption IN ('2', '3')
      BEGIN
         SELECT TOP 1 @cFromID_OrderKey = UserDefine04
         FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UserDefine01 = @cFromID
         ORDER BY EditDate DESC  -- latest scanned

         IF ISNULL( @cFromID_OrderKey, '') <> '' AND ISNULL(@cMultiOrder,'') in('','0')
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND   ID = @cFromID
                        AND   OrderKey = @cFromID_OrderKey
                        AND   [Status] < '9')
            BEGIN
               SET @nErrNo = 97789
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet consoled
               GOTO Step_2_Fail
            END
         END
      END

      -- Get SSCC
      SELECT TOP 1 @cSSCC = LA.Lottable09
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.ID = @cFromID 
      AND   LLI.Qty > 0
      AND   LOC.Facility = @cFacility
      AND   LOC.LocationCategory = 'STAGING'

      -- Print SSCC label
      IF @cOption = '1'
      BEGIN
         SET @nFromScn = @nScn
         SET @nFromStep = @nStep

         SET @cOutField01 = @cFromID
         SET @cOutField02 = ''

         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5

         GOTO Quit
      END   -- IF @cOption = '1'

      IF @cOption = '3'
      BEGIN
         SET @cActSKU = @cInField07

         -- Verify blank
         IF ISNULL( @cActSKU, '') = ''
         BEGIN
            SET @nErrNo = 97792
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Sku required
            GOTO Step_2_Fail
         END

         -- Retrieve actual sku
         EXEC [RDT].[rdt_GETSKUCNT]
            @cStorerKey  = @cStorerKey,
            @cSKU        = @cActSKU,
            @nSKUCnt     = @nSKUCnt       OUTPUT,
            @bSuccess    = @bSuccess      OUTPUT,
            @nErr        = @nErrNo        OUTPUT,
            @cErrMsg     = @cErrMsg       OUTPUT

         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 97793
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong sku
            GOTO Step_2_Fail
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
                  @cActSKU  OUTPUT,    
                  @nErrNo   OUTPUT,    
                  @cErrMsg  OUTPUT,    
                  'LOTXLOCXID.ID',    -- DocType    
                  @cFromID 
               
               IF @nErrNo = 0 -- Populate multi SKU screen    
               BEGIN    
                  -- Go to Multi SKU screen    
                  SET @nBeforeScn = @nScn    
                  SET @nBeforeStep = @nStep
                  SET @nScn = 3570
                  SET @nStep = @nStep + 7
                  GOTO Quit    
               END    
               IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen    
                  SET @nErrNo = 0    
            END    
            ELSE    
            BEGIN  
               SET @nErrNo = 97798  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiBarcodeSKU  
               EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku  
               GOTO Quit  
            END  
         END

         EXEC [RDT].[rdt_GETSKU]
            @cStorerKey  = @cStorerkey,
            @cSKU        = @cActSKU       OUTPUT,
            @bSuccess    = @bSuccess      OUTPUT,
            @nErr        = @nErrNo        OUTPUT,
            @cErrMsg     = @cErrMsg       OUTPUT

         SELECT @cItemClass = ItemClass
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cActSKU

         -- If itemclass = 001 then sku must be upc.upc
         IF @cItemClass = '001'
         BEGIN
            IF NOT EXISTS ( 
               SELECT 1 FROM dbo.UPC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   UPC = @cInField07 -- original value is upc
               AND   SKU = @cActSKU)
            BEGIN
               SET @nErrNo = 97795
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong upc
               GOTO Step_2_Fail
            END
         END

         SET @cSKU = @cActSKU

         -- Check if SKU exists on the pallet (james03)
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
                         WHERE PD.StorerKey = @cStorerKey
                         AND   PD.ID = @cFromID
                         AND   PD.SKU = @cSKU
                         AND   PD.STATUS < '9'
                         AND   LOC.Facility = @cFacility)
         BEGIN
            -- If UPC scanned contain > 1 SKU then check one of the SKU exists in pickdetail
            IF EXISTS ( 
               SELECT 1 
               FROM dbo.UPC UPC WITH (NOLOCK, INDEX(PK_UPC)) 
               WHERE StorerKey = @cStorerKey
               AND   UPC = @cInField07
               AND   SKU = @cActSKU)
            BEGIN
               IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
                         WHERE PD.StorerKey = @cStorerKey
                         AND   PD.ID = @cFromID
                         AND   PD.STATUS < '9'
                         AND   LOC.Facility = @cFacility
                         AND   EXISTS ( SELECT 1 
                                        FROM dbo.UPC UPC WITH (NOLOCK, INDEX(PK_UPC)) 
                                         WHERE UPC.StorerKey = @cStorerKey
                                         AND   UPC.UPC = @cInField07
                                         AND   PD.SKU = UPC.SKU))
               BEGIN
                  SET @nErrNo = 102255
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong upc
                  GOTO Step_2_Fail
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 102256
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong upc
               GOTO Step_2_Fail
            END
         END
         -- Update pallet info (james03)
         -- Check if pallet only 1 SKU
         SELECT @nSKUCount = COUNT( DISTINCT LLI.SKU), 
                @nSSCCCount = COUNT( DISTINCT LA.Lottable09)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.ID = @cFromID 
         AND   LLI.Qty > 0
         AND   LOC.Facility = @cFacility
         AND   LOC.LocationCategory = 'STAGING'

         --not to check ItemClass = 001 ----(cc01)
         IF @cCheckSSCC = '1' --AND @cDisableCtnIDField = '0'
         BEGIN
         	SET @nFromScn = @nScn
            SET @nFromStep = @nStep

            SET @cOutField01 = @cFromID
            SET @cOutField02 = ''

            SET @nScn = @nScn + 6
            SET @nStep = @nStep + 6
         END
         -- If SKU.Itemclass = 001 and SSCC (lottable09) <> blank, null, X, NA
         -- Prompt step 8 to key in SSCC
         ELSE IF @nSKUCount = 1 AND @nSSCCCount = 1 AND 
            EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                     JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                     JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                     WHERE LLI.ID = @cFromID
                     AND   LLI.StorerKey = @cStorerKey
                     AND   SKU.ItemClass = '001'
                     AND   LLI.Qty > 0 
                     AND   LOC.Facility = @cFacility
                     AND   LOC.LocationCategory = 'STAGING'
                     AND   ISNULL( LA.Lottable09, '') NOT IN ( 'X', 'NA', ''))
         BEGIN
            SET @nFromScn = @nScn
            SET @nFromStep = @nStep

            SET @cOutField01 = @cFromID
            SET @cOutField02 = ''

            SET @nScn = @nScn + 6
            SET @nStep = @nStep + 6

            GOTO Quit
         END   
         ELSE
         BEGIN
            -- If sku.itemclass <> '001'
            -- Set Palletkey = ASRSPallet+YYMMDDHHMM (system date/time)
            IF NOT EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                              JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
                              JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                              WHERE LLI.ID = @cFromID
                              AND   LLI.StorerKey = @cStorerKey
                              AND   SKU.ItemClass = '001'
                              AND   LLI.Qty > 0 -- (Leong01)
                              AND   LOC.Facility = @cFacility
                              AND   LOC.LocationCategory = 'STAGING')
            BEGIN
               SET @cSSCC = 'ASRSPallet' + FORMAT(GETDATE(),'yyMMddHHmm')
            END

            -- If still blank, prompt error
            IF ISNULL( @cSSCC, '') = ''
            BEGIN
               SET @nErrNo = 97759
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC req
               GOTO Step_2_Fail
            END

            SET @nErrNo = 0
            EXEC [RDT].[rdt_PltConsoSSCC_BuildPlt] 
               @nMobile         = @nMobile, 
               @nFunc           = @nFunc, 
               @cLangCode       = @cLangCode, 
               @cStorerkey      = @cStorerkey, 
               @cFromLOC        = @cFromLOC,
               @cFromID         = @cFromID, 
               @cToID           = @cToID, 
               @cType           = @cType, 
               @cOption         = @cOption, 
               @cCartonID       = @cCartonID,
               @nQTY_Move       = 0,
               @nQTY_Alloc      = 0,
               @nQTY_Pick       = 0,
               @cSSCC           = @cSSCC     OUTPUT,
               @nErrNo          = @nErrNo    OUTPUT,  
               @cErrMsg         = @cErrMsg   OUTPUT   

            IF @nErrNo <> 0
               GOTO Step_2_Fail

            IF NOT EXISTS ( SELECT 1 
                            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                            WHERE LLI.StorerKey = @cStorerKey 
                            AND   LLI.ID <> @cFromID 
                            AND   LOC.Facility = @cFacility
                            AND   LOC.LocationCategory = 'STAGING'
                            AND   Qty > 0)
            BEGIN
               -- If no more pallet then prompt msg inform user
               SET @nErrNo = 0
               SET @cErrMsg1 = 'NO MORE PALLETS'
               SET @cErrMsg2 = 'IN THE LANE.'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
               END

               SET @cOption = ''
               SET @cOutField06 = ''
            END
            ELSE  -- Go back screen 1
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = '' -- ID

               -- Go to next screen
               SET @nScn = @nScn - 1
               SET @nStep = @nStep - 1
            END
         END
      END

      IF @cOption = '2'
      BEGIN
         SET @cOutField01 = ''
         SET @cSSCC = ''

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOption = ''
      SET @cActSKU = ''

      SET @cOutField06 = ''
      SET @cOutField07 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 3. Screen = 4542
   ID          (field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cToID = @cInField01

      -- Validate blank
      IF ISNULL(@cToID, '') = ''
      BEGIN
         SET @nErrNo = 97763
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Is Req
         GOTO Step_3_Fail
      END

      -- Check from id format (james01)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TOID', @cToID) = 0
      BEGIN
         SET @nErrNo = 97764
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_3_Fail
      END

      IF @cFromID = @cToID
      BEGIN
         SET @nErrNo = 97790
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Same pallet
         GOTO Step_3_Fail
      END

      -- (james05)
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
               ' @cFromID, @cToID, @cSKU, @nQTY, @nMultiStorer, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cToID           NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT,           ' +
               '@nMultiStorer    NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT           OUTPUT, ' + 
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
               
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
               @cFromID, @cToID, @cSKU, @nQTY, @nMultiStorer, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
            IF @nErrNo <> 0 
               GOTO Step_3_Fail 
         END
      END 

      -- No inventory, skip scan to id
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey 
         AND   LLI.ID = @cToID 
         AND   LOC.Facility = @cFacility
         AND   Qty > 0)
      BEGIN
         SET @nErrNo = 0
         SET @cSKU = ''
         EXECUTE rdt.rdt_PltConsoSSCC_GetNextSKU
            @nMobile          = @nMobile,
            @nFunc            = @nFunc,
            @cLangCode        = @cLangCode,
            @nStep            = @nStep,
            @nInputKey        = @nInputKey,
            @cFacility        = @cFacility,
            @cStorerKey       = @cStorerKey,
            @cFromID          = @cFromID,
            @cOption          = 'NEXT',
            @nQty             = @nQty,
            @cToID            = '',
            @nMultiStorer     = @nMultiStorer,
            @cSKU_StorerKey   = @cSKU_StorerKey    OUTPUT,
            @cSKU             = @cSKU              OUTPUT,
            @cDescr           = @cSKUDescr         OUTPUT,
            @cPUOM_Desc       = @cPUOM_Desc        OUTPUT,
            @cMUOM_Desc       = @cMUOM_Desc        OUTPUT,
            @nSKU_CNT         = @nSKU_CNT          OUTPUT,
            @nPQTY            = @nPQTY             OUTPUT,
            @nMQTY            = @nMQTY             OUTPUT,
            @nTtl_Scanned     = @nTtl_Scanned      OUTPUT,
            @nErrNo           = @nErrNo            OUTPUT,
            @cErrMsg          = @cErrMsg           OUTPUT   

         IF ISNULL( @cSKU, '') <> ''
         BEGIN
            SET @cStorerKey = @cSKU_StorerKey

            -- Get SKU QTY
            SET @nQTY_Avail = 0 
            SET @nQTY_Alloc = 0
            SET @nQTY_Pick = 0

            SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),
                   @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),
                   @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @cStorerKey 
            AND   LLI.ID = @cFromID 
            AND   LOC.Facility = @cFacility
            AND   SKU = @cSKU

            SELECT 
               @nPUOM_Div = CAST( Pack.CaseCNT AS INT) 
            FROM dbo.SKU S (NOLOCK) 
            JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
            WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit 
               @nPUOM_Div = 0 -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY_Avail = 0
               SET @nPQTY_Alloc = 0
               SET @nPQTY_Pick = 0
               SET @nMQTY_Avail = @nQTY_Avail 
               SET @nMQTY_Alloc = @nQTY_Alloc
               SET @nMQTY_Pick = @nQTY_Pick
            END
            ELSE
            BEGIN
               SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
               SET @nPQTY_Alloc = @nQTY_Alloc / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY_Alloc = @nQTY_Alloc % @nPUOM_Div -- Calc the remaining in master unit
               SET @nPQTY_Pick = @nQTY_Pick / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY_Pick = @nQTY_Pick % @nPUOM_Div -- Calc the remaining in master unit
            END

            SET @nCurSKU_CNT = 1

            -- Prepare next screen var
            SET @cOutField01 = @cFromID
            SET @cOutField02 = CAST( @nCurSKU_CNT AS NVARCHAR( 2)) + '/' + CAST( @nSKU_CNT AS NVARCHAR( 2))
            SET @cOutField03 = @cSKU
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
            SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
            
            IF @cPUOM_Desc = ''
            BEGIN
               SET @cOutField06 = '' -- @cPUOM_Desc
               SET @cOutField07 = '' -- @nPQTY_Avail
               SET @cOutField08 = '' -- @nPQTY_Alloc
               SET @cOutField09 = '' -- @nPQTY_Pick
            END
            ELSE
            BEGIN
               SET @cOutField06 = @cPUOM_Desc
               SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
               SET @cOutField08 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))
               SET @cOutField09 = CAST( @nPQTY_Pick AS NVARCHAR( 5))
            END
            SET @cOutField10 = @cMUOM_Desc
            SET @cOutField11 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
            SET @cOutField12 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))
            SET @cOutField13 = CAST( @nMQTY_Pick AS NVARCHAR( 5))

            SET @cOutField14 = ''

            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2

            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Check if shipper pallet is not empty
         SELECT TOP 1 @cToID_MBOLKey = O.MbolKey,
                      @cToID_OrderKey = O.OrderKey
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
         WHERE PD.ID = @cToID
         AND   PD.Status = '5'
         AND   PD.StorerKey = @cStorerKey

         -- If Shipper pallet is not empty and with mbolkey
         -- Then check if user console pallet from different mbol
         IF ISNULL( @cToID_MBOLKey, '') <> ''
         BEGIN
            SELECT TOP 1 @cFromID_MBOLKey = O.MbolKey
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
            WHERE PD.ID = @cFromID
            AND   PD.Status = '5'
            AND   PD.StorerKey = @cStorerKey

            IF ISNULL( @cFromID_MBOLKey, '') <> '' AND 
               @cFromID_MBOLKey <> @cToID_MBOLKey
            BEGIN
               SET @nErrNo = 97787
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Plt mix mbol
               GOTO Step_3_Fail
            END
         END

         SELECT TOP 1 @cOrderKey = UserDefine04
         FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UserDefine01 = @cFromID
         AND   [Status] < '9'

         -- ASRS pallet consoled before and cannot console again to same orderkey
         IF ISNULL( @cOrderKey, '') <> '' AND @cOrderKey = ISNULL( @cToID_OrderKey, '')
         BEGIN
            SET @nErrNo = 97788
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Plt consoled
            GOTO Step_3_Fail
         END

         -- (james04)
         SELECT TOP 1 @cASRS_OrderKey = OrderKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ID = @cFromID
         AND   [Status] < '9'

         SELECT @cConsigneeKey = ConsigneeKey
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cASRS_OrderKey

         IF EXISTS ( SELECT 1 FROM dbo.Storer WITH (NOLOCK)
                     WHERE StorerKey = @cConsigneeKey
                     AND   Type = '2'
                     AND   'PPAO1' IN (SUSR1, SUSR2, SUSR3, SUSR4, SUSR5))
         BEGIN
            IF ISNULL( @cASRS_OrderKey, '') <> ISNULL( @cToID_OrderKey, '')
            BEGIN
               SET @nErrNo = 102257
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CANNOT MIX ORD
               GOTO Step_3_Fail
            END
         END
      END

      SET @nErrNo = 0
      SET @cSKU = ''
      EXECUTE rdt.rdt_PltConsoSSCC_GetNextSKU
         @nMobile          = @nMobile,
         @nFunc            = @nFunc,
         @cLangCode        = @cLangCode,
         @nStep            = @nStep,
         @nInputKey        = @nInputKey,
         @cFacility        = @cFacility,
         @cStorerKey       = @cStorerKey,
         @cFromID          = @cFromID,
         @cOption          = 'NEXT',
         @nQty             = @nQty,
         @cToID            = @cToID,
         @nMultiStorer     = @nMultiStorer,
         @cSKU_StorerKey   = @cSKU_StorerKey    OUTPUT,
         @cSKU             = @cSKU              OUTPUT,
         @cDescr           = @cSKUDescr         OUTPUT,
         @cPUOM_Desc       = @cPUOM_Desc        OUTPUT,
         @cMUOM_Desc       = @cMUOM_Desc        OUTPUT,
         @nSKU_CNT         = @nSKU_CNT          OUTPUT,
         @nPQTY            = @nPQTY             OUTPUT,
         @nMQTY            = @nMQTY             OUTPUT,
         @nTtl_Scanned     = @nTtl_Scanned      OUTPUT,
         @nErrNo           = @nErrNo            OUTPUT,
         @cErrMsg          = @cErrMsg           OUTPUT   

      IF @nErrNo <> 0 OR ISNULL( @cSKU, '') = '' OR ISNULL( @cSKU_StorerKey, '') = ''
      BEGIN
         SET @nErrNo = 97765
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No suggest sku
         GOTO Step_3_Fail
      END

      SET @cStorerKey = @cSKU_StorerKey

      SELECT @nSKU_CNT = COUNT( DISTINCT SKU)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   Qty > 0

      DECLARE @cFromID_SKU    NVARCHAR( 20)
      SELECT TOP 1 @cFromID_SKU = SKU
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.Id = @cFromID
      AND   LLI.Qty > 0
      AND   LOC.Facility = @cFacility
      ORDER BY 1
      
      -- Get SKU QTY
      SET @nQTY_Avail = 0 
      SET @nQTY_Alloc = 0
      SET @nQTY_Pick = 0

      SELECT @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   SKU = @cFromID_SKU

      SELECT 
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
      WHERE StorerKey = @cStorerKey
      AND SKU = @cFromID_SKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Avail = 0
         SET @nPQTY_Alloc = 0
         SET @nPQTY_Pick = 0
         SET @nMQTY_Pick = @nQTY_Pick
      END
      ELSE
      BEGIN
         SET @nPQTY_Pick = @nQTY_Pick / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Pick = @nQTY_Pick % @nPUOM_Div -- Calc the remaining in master unit
      END

      IF @nQTY_Pick = 0
      BEGIN
         SET @nErrNo = 97770
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qtypck notenuf
         GOTO Step_5_Fail
      END

      SET @nOrdCount = 0
      SELECT @nOrdCount = COUNT( DISTINCT OrderKey)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.ID = @cFromID
      AND   PD.Status = '5'
      AND   Facility = @cFacility

      IF @nOrdCount > 1
      BEGIN
         SET @nErrNo = 97781
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Id > 1 orders
         GOTO Step_5_Fail
      END

      -- Get SSCC if the pallet still not ship yet
      -- Pallet will lose id when scan to container
      SET @cSSCC = ''
      SET @cToID_MbolKey = ''
      SELECT TOP 1 @cSSCC = PalletKey
      FROM dbo.PalletDetail PLTD WITH (NOLOCK)
      WHERE PLTD.Storerkey = @cStorerkey
      AND   PLTD.UserDefine01 = @cToID
      AND   PLTD.Status < '9'
      AND   NOT EXISTS ( SELECT 1 FROM dbo.MBOL MBOL WITH (NOLOCK)
                           WHERE PLTD.UserDefine03 = MBOL.MbolKey
                           AND   MBOL.Status = '9')
                               
      --SELECT @nQTY_Scanned = ISNULL( SUM( Qty), 0) 
      --FROM dbo.PALLETDETAIL WITH (NOLOCK) 
      --WHERE PalletKey = @cSSCC
      --AND   UserDefine05 = @cFromID
      --AND   UserDefine01 = @cToID
      --AND   SKU = @cSKU

      -- Disable carton field    
      IF @cDisableCtnFieldSP <> ''    
      BEGIN    
         IF @cDisableCtnFieldSP = '1'    
            SET @cDisableCtnField = @cDisableCtnFieldSP    
         ELSE    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableCtnFieldSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableCtnFieldSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,  ' +     
               ' @cFromID, @cToID, @cSKU, @nQTY, @cOption, @cDisableCtnField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cToID           NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +    
               '@cDisableCtnField   NVARCHAR( 1)  OUTPUT, ' +    
               '@nErrNo             INT            OUTPUT, ' +    
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
                  @cFromID, @cToID, @cSKU, @nQTY,@cOption, @cDisableCtnField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
    
               IF @nErrNo <> 0    
                  GOTO Quit    
            END    
         END    
      END    

      SELECT @nQTY_Scanned = ISNULL( SUM( QtyMove), 0) 
      FROM rdt.rdtDPKLog WITH (NOLOCK) 
      WHERE FromID = @cFromID
      AND   DropID = @cToID
      AND   SKU = @cFromID_SKU
      AND   UserKey = @cUserName
         
      SET @nBalQty = 0
      SET @nPBalQty = 0
      SET @nMBalQty=0

      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0
      BEGIN
         SET @nMBalQty = @nQTY_Pick - @nQTY_Scanned 
         SET @cPUOM_Desc = ''    
         SET @nPBalQty = 0
         SET @cFieldAttr09 = 'O'
      END
      ELSE
      BEGIN
         SET @nPBalQty = ( @nQTY_Pick - @nQTY_Scanned) / @nPUOM_Div

         SET @nMBalQty = ( @nQTY_Pick - @nQTY_Scanned) % @nPUOM_Div

         SET @cFieldAttr09 = '' -- @nPQTY
         SET @cFieldAttr14 = '' -- @nMQTY
      END

      SET @nBalQty = ( @nPBalQty + @nMBalQty)

      IF ISNULL( @nBalQty, 0) <= 0
      BEGIN
         SET @nErrNo = 97786
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more case
         GOTO Step_3_Fail
      END

      SET @nCurSKU_CNT = 1

      -- Prepare next screen var
      SET @cOutField01 = @cToID
      SET @cOutField02 = CAST( @nCurSKU_CNT AS NVARCHAR( 2)) + '/' + CAST( @nSKU_CNT AS NVARCHAR( 2))
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = ''
      SET @cOutField07 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 10)) END
      SET @cOutField08 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField09 = CASE WHEN @nPBalQty > 0 THEN '1' ELSE '' END
      SET @cOutField10 =  CASE WHEN @nPBalQty = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPBalQty AS NVARCHAR( 5)) END
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
      SET @cOutField14 = ''--CASE WHEN @nPBalQty > 0 THEN '' ELSE CAST( @nMBalQty AS NVARCHAR( 5)) END
      SET @cOutField15 = @nMBalQty
      SET @cInField06  = ''

     -- Enable field    
      IF @cDisableCtnField = '1'    
         SET @cFieldAttr06 = 'O'    
      ELSE    
         SET @cFieldAttr06 = ''  

      IF (@nPQTY - @nTtl_Scanned) > 0
      BEGIN 
         SET @cFieldAttr12 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku
      END
      ELSE
      BEGIN
         SET @cFieldAttr12 = 'O'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Carton id
      END

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      IF @cFlowThStep4='1'
      BEGIN
         SET @cInField11='1'
         SET @cFieldAttr12 ='o'
         GOTO STEP_4
      END



   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @nIDQty = ISNULL( SUM( Qty), 0), 
             @nLOTIDQty = ISNULL( SUM( CAST( Lottable12 AS INT)), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   LOC.LocationCategory = 'STAGING'

      SELECT @cHeight = SUSR1,
             @cWeight = SUSR3
      FROM dbo.Storer WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   [Type] = '1'

      SELECT TOP 1 @cSpecialInstruction = O.Notes
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.ID = @cFromID
      AND   PD.Status < '9'

      -- Prepare next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = CASE WHEN @nIDQty = @nLOTIDQty THEN 'FULL' ELSE 'PARTIAL' END
      SET @cOutField03 = @cHeight
      SET @cOutField04 = @cWeight
      SET @cOutField05 = @cSpecialInstruction
      SET @cOutField06 = '' -- Option
      SET @cOutField07 = '' -- SKU
      SET @cOutField08 = @cFromLoc -- LOC

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cToID = ''

      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. Screen = 4543
   TO ID          (field01)
   SKU            (field02)
   Qty            (field03)
   Option         (field04, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cCartonBarcode = @cInField06
      SET @cCurrentSKU = @cOutField03
      SET @cPQTY = IsNULL( @cInField09, '') 
      SET @cMQTY = IsNULL( @cInField14, '')
      SET @cPBalQty = IsNULL( @cOutField10, 0)
      SET @cMBalQty = IsNULL( @cOutField15, 0)
      SET @cOption = @cInField11

      -- Get next SKU
      IF ISNULL( @cInField06, '') = '' AND ISNULL( @cInField11, '') = ''  
      BEGIN
         IF @cDisableCtnField<>1
         BEGIN
            IF ( @cFieldAttr12 = '' AND @cInField12 = '') OR ( @cFieldAttr12 = 'O' AND @cOutField12 = '')
            BEGIN
               SET @nErrNo = 0
               EXECUTE rdt.rdt_PltConsoSSCC_GetNextSKU
                  @nMobile          = @nMobile,
                  @nFunc            = @nFunc,
                  @cLangCode        = @cLangCode,
                  @nStep            = @nStep,
                  @nInputKey        = @nInputKey,
                  @cFacility        = @cFacility,
                  @cStorerKey       = @cStorerKey,
                  @cFromID          = @cFromID,
                  @cOption          = 'NEXT',
                  @nQty             = @nQty,
                  @cToID            = @cToID,
                  @nMultiStorer     = @nMultiStorer,
                  @cSKU_StorerKey   = @cSKU_StorerKey    OUTPUT,
                  @cSKU             = @cCurrentSKU       OUTPUT,
                  @cDescr           = @cSKUDescr         OUTPUT,
                  @cPUOM_Desc       = @cPUOM_Desc        OUTPUT,
                  @cMUOM_Desc       = @cMUOM_Desc        OUTPUT,
                  @nSKU_CNT         = @nSKU_CNT          OUTPUT,
                  @nPQTY            = @nPQTY             OUTPUT,
                  @nMQTY            = @nMQTY             OUTPUT,
                  @nTtl_Scanned     = @nTtl_Scanned      OUTPUT,
                  @nErrNo           = @nErrNo            OUTPUT,
                  @cErrMsg          = @cErrMsg           OUTPUT   

               IF @nErrNo <> 0 OR ISNULL( @cCurrentSKU, '') = '' OR ISNULL( @cSKU_StorerKey, '') = ''
               BEGIN
                  SET @nErrNo = 97783
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No suggest sku
                  GOTO Step_4_Fail
               END

               SET @cStorerKey = @cSKU_StorerKey
               SET @nCurSKU_CNT = CAST( CAST( SUBSTRING( @cOutField02, 1, CHARINDEX( '/', @cOutField02) - 1) AS INT) + 1 AS NVARCHAR( 2))
               SET @cSKU = @cCurrentSKU

               -- Prepare next screen var
               SET @cOutField01 = @cToID
               SET @cOutField02 = CAST( @nCurSKU_CNT AS NVARCHAR( 2)) + '/' + CAST( @nSKU_CNT AS NVARCHAR( 2))
               SET @cOutField03 = @cSKU
               SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
               SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
               SET @cOutField06 = ''
               SET @cOutField07 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 10)) END
               SET @cOutField08 = @cPUOM_Desc
               SET @cOutField09 = '1'
               SET @cOutField10 = CASE WHEN CAST( (@nPQTY - @nTtl_Scanned) AS NVARCHAR( 3)) < 0 THEN '0' 
                                  ELSE CAST( (@nPQTY - @nTtl_Scanned) AS NVARCHAR( 3)) END

               SET @cOutField11 = ''
               SET @cOutField12 = ''

               IF (@nPQTY - @nTtl_Scanned) > 0
               BEGIN 
                  SET @cFieldAttr12 = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku
               END
               ELSE
               BEGIN
                  SET @cFieldAttr12 = 'O'
                  EXEC rdt.rdtSetFocusField @nMobile, 6 -- Carton id
               END

               GOTO Quit
            END
         END
      END

      IF @cFieldAttr12 = ''
      BEGIN
         SET @cActSKU =  @cInField12

         -- Verify blank
         IF ISNULL( @cActSKU, '') = ''
         BEGIN
            SET @nErrNo = 97796
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Sku required
            EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku
            GOTO Quit
         END

         -- Extended update
         IF @cDecodeSKUSP <> '' 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSKUSP AND type = 'P')
            BEGIN
               SET @nQty = 0
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSKUSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromID, @cToID, @cOption, ' + 
                  ' @cSKU OUTPUT, @nQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT, '            +
                  '@nFunc           INT, '            +
                  '@cLangCode       NVARCHAR( 3), '   +
                  '@nStep   INT, '            + 
                  '@nInputKey       INT, '            +
                  '@cStorerKey      NVARCHAR( 15), '  +
                  '@cFromID         NVARCHAR( 18), '  +
                  '@cToID           NVARCHAR( 18), '  +
                  '@cOption         NVARCHAR( 10), '  +
                  '@cSKU            NVARCHAR( 20)  OUTPUT, ' +
                  '@nQty            INT            OUTPUT, ' +
                  '@nErrNo          INT            OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT'  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromID, @cToID, @cOption, 
                  @cActSKU OUTPUT, @nQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
               IF @nErrNo <> 0 
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                  GOTO Quit
               END
            END
         END

         -- Retrieve actual sku
         EXEC [RDT].[rdt_GETSKUCNT]
            @cStorerKey  = @cStorerKey,
            @cSKU        = @cActSKU,
            @nSKUCnt     = @nSKUCnt       OUTPUT,
            @bSuccess    = @bSuccess      OUTPUT,
            @nErr        = @nErrNo        OUTPUT,
            @cErrMsg     = @cErrMsg       OUTPUT

         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 97797
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong sku
            EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku
            GOTO Quit
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
                  @cActSKU  OUTPUT,    
                  @nErrNo   OUTPUT,    
                  @cErrMsg  OUTPUT,    
                  'LOTXLOCXID.ID',    -- DocType    
                  @cFromID 
               
               IF @nErrNo = 0 -- Populate multi SKU screen    
               BEGIN    
                  -- Go to Multi SKU screen    
                  SET @nBeforeScn = @nScn    
                  SET @nBeforeStep = @nStep
                  SET @nScn = 3570
                  SET @nStep = @nStep + 6
                  GOTO Quit    
               END    
               IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen    
                  SET @nErrNo = 0    
            END    
            ELSE    
            BEGIN
               SET @nErrNo = 97798
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiBarcodeSKU
               EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku
               GOTO Quit
            END
         END

         EXEC [RDT].[rdt_GETSKU]
            @cStorerKey  = @cStorerkey,
            @cSKU        = @cActSKU       OUTPUT,
            @bSuccess    = @bSuccess      OUTPUT,
            @nErr        = @nErrNo        OUTPUT,
            @cErrMsg     = @cErrMsg       OUTPUT
         
         IF @nErrNo <> 0
         BEGIN 
            SET @nErrNo = 97798
            SET @cErrMsg = @cActSKU--rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiBarcodeSKU
            EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku
            GOTO Quit
         END

         SELECT @cItemClass = ItemClass
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cActSKU

         -- If itemclass = 001 then sku must be upc.upc
         IF @cItemClass = '001'
         BEGIN
            IF NOT EXISTS ( 
               SELECT 1 FROM dbo.UPC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   UPC = @cInField12
               AND   SKU = @cActSKU)                                       
            BEGIN
               SET @nErrNo = 97799
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong upc
               EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku
               GOTO Quit
            END
         END

         IF @cCurrentSKU <> @cActSKU
         BEGIN
            SET @nErrNo = 102259
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong upc
            EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku
            GOTO Quit
         END

         SET @cFieldAttr12 = 'O'

         GOTO Quit
      END

      -- User finish scanning. Get From ID 1st SKU to display
      IF ISNULL( @cOption, '') <> ''
      BEGIN
         IF @cOption <> '1'
         BEGIN
            SET @nErrNo = 97784
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid option'
            GOTO Step_4_Fail
         END

         SET @nErrNo = 0
         SET @cCurrentSKU = @cSKU   -- Remember current SKU
         SET @cSKU = ''
         EXECUTE rdt.rdt_PltConsoSSCC_GetNextSKU
            @nMobile          = @nMobile,
            @nFunc            = @nFunc,
            @cLangCode        = @cLangCode,
            @nStep            = @nStep,
            @nInputKey        = @nInputKey,
            @cFacility        = @cFacility,
            @cStorerKey       = @cStorerKey,
            @cFromID          = @cFromID,
            @cOption          = 'NEXT',
            @nQty             = @nQty,
            @cToID            = '',
            @nMultiStorer     = @nMultiStorer,
            @cSKU_StorerKey   = @cSKU_StorerKey    OUTPUT,
            @cSKU             = @cSKU              OUTPUT,
            @cDescr           = @cSKUDescr         OUTPUT,
            @cPUOM_Desc       = @cPUOM_Desc        OUTPUT,
            @cMUOM_Desc       = @cMUOM_Desc        OUTPUT,
            @nSKU_CNT         = @nSKU_CNT          OUTPUT,
            @nPQTY            = @nPQTY             OUTPUT,
            @nMQTY            = @nMQTY             OUTPUT,
            @nTtl_Scanned     = @nTtl_Scanned      OUTPUT,
            @nErrNo           = @nErrNo            OUTPUT,
            @cErrMsg          = @cErrMsg           OUTPUT   

         IF ISNULL( @cSKU, '') <> ''
         BEGIN
            SET @cStorerKey = @cSKU_StorerKey

            -- Get SKU QTY
            SET @nQTY_Avail = 0 
            SET @nQTY_Alloc = 0
            SET @nQTY_Pick = 0

            SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),
                   @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),
                   @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @cStorerKey 
            AND   LLI.ID = @cFromID 
            AND   LOC.Facility = @cFacility
            AND   SKU = @cSKU

            SELECT 
               @nPUOM_Div = CAST( Pack.CaseCNT AS INT) 
            FROM dbo.SKU S (NOLOCK) 
            JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
            WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit 
               @nPUOM_Div = 0 -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY_Avail = 0
               SET @nPQTY_Alloc = 0
               SET @nPQTY_Pick = 0
               SET @nMQTY_Avail = @nQTY_Avail 
               SET @nMQTY_Alloc = @nQTY_Alloc
               SET @nMQTY_Pick = @nQTY_Pick
            END
            ELSE
            BEGIN
               SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
               SET @nPQTY_Alloc = @nQTY_Alloc / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY_Alloc = @nQTY_Alloc % @nPUOM_Div -- Calc the remaining in master unit
               SET @nPQTY_Pick = @nQTY_Pick / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY_Pick = @nQTY_Pick % @nPUOM_Div -- Calc the remaining in master unit
            END

            SET @nCurSKU_CNT = 1

            -- Prepare next screen var
            SET @cOutField01 = @cFromID
            SET @cOutField02 = CAST( @nCurSKU_CNT AS NVARCHAR( 2)) + '/' + CAST( @nSKU_CNT AS NVARCHAR( 2))
            SET @cOutField03 = @cSKU
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
            SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
            
            IF @cPUOM_Desc = ''
            BEGIN
               SET @cOutField06 = '' -- @cPUOM_Desc
               SET @cOutField07 = '' -- @nPQTY_Avail
               SET @cOutField08 = '' -- @nPQTY_Alloc
               SET @cOutField09 = '' -- @nPQTY_Pick
            END
            ELSE
            BEGIN
               SET @cOutField06 = @cPUOM_Desc
               SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
               SET @cOutField08 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))
               SET @cOutField09 = CAST( @nPQTY_Pick AS NVARCHAR( 5))
            END
            SET @cOutField10 = @cMUOM_Desc
            SET @cOutField11 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
            SET @cOutField12 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))
            SET @cOutField13 = CAST( @nMQTY_Pick AS NVARCHAR( 5))

            SET @cOutField14 = ''

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @cSKU = @cCurrentSKU
            SET @nErrNo = 97785
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more sku
            GOTO Step_4_Fail
         END
      END

      -- Get next SKU
      IF ISNULL( @cInField06, '') = ''
      BEGIN
         SET @nErrNo = 0
         EXECUTE rdt.rdt_PltConsoSSCC_GetNextSKU
            @nMobile          = @nMobile,
            @nFunc            = @nFunc,
            @cLangCode        = @cLangCode,
            @nStep            = @nStep,
            @nInputKey        = @nInputKey,
            @cFacility        = @cFacility,
            @cStorerKey       = @cStorerKey,
            @cFromID          = @cFromID,
            @cOption          = 'NEXT',
            @nQty             = @nQty,
            @cToID            = @cToID,
            @nMultiStorer     = @nMultiStorer,
            @cSKU_StorerKey   = @cSKU_StorerKey    OUTPUT,
            @cSKU             = @cCurrentSKU       OUTPUT,
            @cDescr           = @cSKUDescr         OUTPUT,
            @cPUOM_Desc       = @cPUOM_Desc        OUTPUT,
            @cMUOM_Desc       = @cMUOM_Desc        OUTPUT,
            @nSKU_CNT         = @nSKU_CNT          OUTPUT,
            @nPQTY            = @nPQTY             OUTPUT,
            @nMQTY            = @nMQTY             OUTPUT,
            @nTtl_Scanned     = @nTtl_Scanned      OUTPUT,
            @nErrNo           = @nErrNo            OUTPUT,
            @cErrMsg          = @cErrMsg           OUTPUT   

         IF @nErrNo <> 0 OR ISNULL( @cCurrentSKU, '') = '' OR ISNULL( @cSKU_StorerKey, '') = ''
         BEGIN
            SET @nErrNo = 97783
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No suggest sku
            GOTO Step_4_Fail
         END

         SET @cStorerKey = @cSKU_StorerKey
         SET @nCurSKU_CNT = CAST( CAST( SUBSTRING( @cOutField02, 1, CHARINDEX( '/', @cOutField02) - 1) AS INT) + 1 AS NVARCHAR( 2))

         -- Prepare next screen var
         SET @cOutField01 = @cToID
         SET @cOutField02 = CAST( @nCurSKU_CNT AS NVARCHAR( 2)) + '/' + CAST( @nSKU_CNT AS NVARCHAR( 2))
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField06 = ''
         SET @cOutField07 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 10)) END
         SET @cOutField08 = @cPUOM_Desc
         SET @cOutField09 = '1'
         SET @cOutField10 = CASE WHEN CAST( (@nPQTY - @nTtl_Scanned) AS NVARCHAR( 3)) < 0 THEN '0' 
                            ELSE CAST( (@nPQTY - @nTtl_Scanned) AS NVARCHAR( 3)) END
      END

      -- Decode label
      SET @cDecodeCartonIDSP = rdt.RDTGetConfig( @nFunc, 'DecodeCartonIDSP', @cStorerKey)
      IF @cDecodeCartonIDSP = '0'
         SET @cDecodeCartonIDSP = ''

      -- Extended update
      IF @cDecodeCartonIDSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeCartonIDSP AND type = 'P')
         BEGIN
            SET @nQty = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeCartonIDSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromID, @cToID, @cOption, ' + 
               ' @cSKU OUTPUT, @nQty OUTPUT, @cCartonBarcode OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, '            +
               '@nFunc           INT, '            +
               '@cLangCode       NVARCHAR( 3), '   +
               '@nStep           INT, '            + 
               '@nInputKey       INT, '            +
               '@cStorerKey      NVARCHAR( 15), '  +
               '@cFromID         NVARCHAR( 18), '  +
               '@cToID           NVARCHAR( 18), '  +
               '@cOption         NVARCHAR( 10), '  +
               '@cSKU            NVARCHAR( 20)  OUTPUT, ' +
               '@nQty            INT            OUTPUT, ' +
               '@cCartonBarcode  NVARCHAR( 60)  OUTPUT, ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromID, @cToID, @cOption, 
               @cSKU OUTPUT, @nQty OUTPUT, @cCartonBarcode OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo = -1
            BEGIN
               SET @cCartonID = SUBSTRING( @cCartonBarcode, 1, 20)
               SET @cOutField06 = SUBSTRING( @cCartonBarcode, 1, 20)
               GOTO Quit
            END
            
            IF @nErrNo <> 0 
            BEGIN
              -- SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_4a_Fail
            END
            ELSE
               SET @cCartonID = SUBSTRING( @cCartonBarcode, 1, 20)
         END
      END
      ELSE
         SET @cCartonID = SUBSTRING( @cCartonBarcode, 1, 20)

      IF @nQty = 0
      BEGIN
         -- Validate PQTY
         IF @cPQTY = '' SET @cPQTY = '0' -- Blank taken as zero
         IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
         BEGIN
            SET @nErrNo = 97776
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 9 -- PQTY
            GOTO Step_4b_Fail
         END

         -- Validate MQTY
         IF @cMQTY = '' SET @cMQTY = '0' -- Blank taken as zero
         IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
         BEGIN
            SET @nErrNo = 102258
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 14 -- PQTY
            GOTO Step_4b_Fail
         END

         -- Calc total QTY in master UOM
         SET @nQTY_Move = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
         SET @nQTY_Move = @nQTY_Move + CAST( @cMQTY AS INT)
      END
      ELSE
      BEGIN
         SET @nQTY_Move = @nQty
      END
      
      SET @nBalQty = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPBalQty, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nBalQty = @nBalQty + CAST( @cMBalQty AS INT)

      -- Validate QTY
      IF @nQTY_Move = 0
      BEGIN
         SET @nErrNo = 97778
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY needed'
         EXEC rdt.rdtSetFocusField @nMobile, 9 -- PQTY
         GOTO Step_4b_Fail
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY_Move > @nBalQty
      BEGIN
         SET @nErrNo = 97779
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTYAVL NotEnuf'
         EXEC rdt.rdtSetFocusField @nMobile, 9 -- PQTY
         GOTO Step_4b_Fail
      END

      SELECT @cPackUOM3 = PACK.PACKUOM3,
             @cPackUOM1 = PACK.PACKUOM1,
             @nCaseCnt = PACK.CaseCnt
      FROM dbo.PACK PACK WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE SKU.Storerkey = @cStorerKey
      AND   SKU.SKU = @cSKU

      IF ( @nQTY_Move % @nCaseCnt) <> 0
      BEGIN
         IF @nBalQty > @nCaseCnt -- If not last pcs
         BEGIN
            SET @nErrNo = 97780
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Mv qty in case'
            GOTO Step_4b_Fail
         END
      END

      -- Ins pallet info
      SET @nErrNo = 0
      EXEC [RDT].[rdt_PltConsoSSCC_BuildPlt] 
         @nMobile         = @nMobile, 
         @nFunc           = @nFunc, 
         @cLangCode       = @cLangCode, 
         @cStorerkey      = @cStorerkey, 
         @cFromLOC        = @cFromLOC,
         @cFromID         = @cFromID, 
         @cToID           = @cToID, 
         @cType           = 'I', 
         @cOption         = @cOption, 
         @cCartonID       = @cCartonID,
         @nQTY_Move       = @nQTY_Move,
         @nQTY_Alloc      = 0,
         @nQTY_Pick       = 0,
         @cSSCC           = @cSSCC     OUTPUT,  
         @nErrNo          = @nErrNo    OUTPUT,  
         @cErrMsg         = @cErrMsg   OUTPUT   

      IF @nErrNo <> 0
         GOTO Step_4_Fail

      SET @nErrNo = 0
      EXECUTE rdt.rdt_PltConsoSSCC_GetNextSKU
         @nMobile          = @nMobile,
         @nFunc            = @nFunc,
         @cLangCode        = @cLangCode,
         @nStep            = @nStep,
         @nInputKey        = @nInputKey,
         @cFacility        = @cFacility,
         @cStorerKey       = @cStorerKey,
         @cFromID          = @cFromID,
         @cOption          = 'CURRENT',
         @nQty             = @nQty,
         @cToID            = @cToID,
         @nMultiStorer     = @nMultiStorer,
         @cSKU_StorerKey   = @cSKU_StorerKey    OUTPUT,
         @cSKU             = @cSKU              OUTPUT,
         @cDescr           = @cSKUDescr         OUTPUT,
         @cPUOM_Desc       = @cPUOM_Desc        OUTPUT,
         @cMUOM_Desc       = @cMUOM_Desc        OUTPUT,
         @nSKU_CNT         = @nSKU_CNT          OUTPUT,
         @nPQTY            = @nPQTY             OUTPUT,
         @nMQTY            = @nMQTY             OUTPUT,
         @nTtl_Scanned     = @nTtl_Scanned      OUTPUT,
         @nErrNo           = @nErrNo            OUTPUT,
         @cErrMsg          = @cErrMsg           OUTPUT   

      -- Get SKU QTY
      SET @nQTY_Avail = 0 
      SET @nQTY_Alloc = 0
      SET @nQTY_Pick = 0

      -- Get required qty
      SELECT @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   SKU = @cSKU

      SELECT @nPUOM_Div = CAST( Pack.CaseCNT AS INT) 
      FROM dbo.SKU S (NOLOCK) 
      JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

      -- Get SSCC if the pallet still not ship yet
      -- Pallet will lose id when scan to container
      SET @cSSCC = ''
      SET @cToID_MbolKey = ''
      SELECT TOP 1 @cSSCC = PalletKey
      FROM dbo.PalletDetail PLTD WITH (NOLOCK)
      WHERE PLTD.Storerkey = @cStorerkey
      AND   PLTD.UserDefine01 = @cToID
      AND   PLTD.Status < '9'
      AND   NOT EXISTS ( SELECT 1 FROM dbo.MBOL MBOL WITH (NOLOCK)
                           WHERE PLTD.UserDefine03 = MBOL.MbolKey
                           AND   MBOL.Status = '9')
                            
      --SELECT @nQTY_Scanned = ISNULL( SUM( Qty), 0) 
      --FROM dbo.PALLETDETAIL WITH (NOLOCK) 
      --WHERE PalletKey = @cSSCC
      --AND   UserDefine05 = @cFromID
      --AND   UserDefine01 = @cToID
      --AND   SKU = @cSKU

      SELECT @nQTY_Scanned = ISNULL( SUM( QtyMove), 0) 
      FROM rdt.rdtDPKLog WITH (NOLOCK) 
      WHERE FromID = @cFromID
      AND   DropID = @cToID
      AND   SKU = @cSKU
      AND   UserKey = @cUserName

      SET @nBalQty = @nQTY_Pick

      SET @nBalQty = @nBalQty - @nQTY_Scanned
               
      --SET @nBalQty = @nBalQty - @nQTY_Move

      -- Convert to prefer UOM QTY
      SET @nPBalQty = @nBalQty / @nPUOM_Div -- Calc QTY in preferred UOM
      SET @nMBalQty = @nBalQty % @nPUOM_Div

      -- Stay at the same screen for another carton id
      SET @cOutField01 = @cToID
      SET @cOutField02 = CAST( @nCurSKU_CNT AS NVARCHAR( 2)) + '/' + CAST( @nSKU_CNT AS NVARCHAR( 2))
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = ''
      SET @cOutField07 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 10)) END
      SET @cOutField08 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField09 = CASE WHEN @nPBalQty > 0 THEN '1' ELSE '' END
      SET @cOutField10 =  CASE WHEN @nPBalQty = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPBalQty AS NVARCHAR( 5)) END
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
      SET @cOutField14 = ''--CASE WHEN @nPBalQty > 0 THEN '' ELSE CAST( @nMBalQty AS NVARCHAR( 5)) END
      SET @cOutField15 = @nMBalQty
      
      IF (@nPQTY - @nTtl_Scanned) > 0
      BEGIN 
         SET @cFieldAttr12 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku
      END
      ELSE
      BEGIN
         SET @cFieldAttr12 = 'O'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Carton id
      END
      
      --SET @cOutField06 = ''
      --SET @cOutField09 = '1'
      --SET @cOutField10 = CASE WHEN CAST( (@nPQTY - @nTtl_Scanned) AS NVARCHAR( 3)) < 0 THEN '0' 
      --                   ELSE CAST( (@nPQTY - @nTtl_Scanned) AS NVARCHAR( 3)) END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cCartonID = ''
      SET @cPQTY = ''
      SET @cOption = ''

      SET @cOutField06 = ''
      SET @cOutField09 = '1'
      SET @cOutField11 = ''
   END
   GOTO Quit

   Step_4a_Fail:
   BEGIN
      SET @cCartonID = ''

      SET @cOutField06 = ''
   END
   GOTO Quit

   Step_4b_Fail:
   BEGIN
      SET @cPQTY = ''

      SET @cOutField09 = '1'
   END
END
GOTO Quit

/********************************************************************************
Step 5. Screen = 4544
   TO ID          (field01)
   SKU            (field02)
   Qty            (field03)
   Option         (field04, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInField14
      SET @cCurrentSKU = @cOutField03

      -- Get next sku
      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 0
         EXECUTE rdt.rdt_PltConsoSSCC_GetNextSKU
            @nMobile          = @nMobile,
            @nFunc            = @nFunc,
            @cLangCode        = @cLangCode,
            @nStep            = @nStep,
            @nInputKey        = @nInputKey,
            @cFacility        = @cFacility,
            @cStorerKey       = @cStorerKey,
            @cFromID          = @cFromID,
            @cOption          = @cOption,
            @nQty             = @nQty,
            @cToID            = @cToID,
            @nMultiStorer     = @nMultiStorer,
            @cSKU_StorerKey   = @cSKU_StorerKey    OUTPUT,
            @cSKU             = @cCurrentSKU       OUTPUT,
            @cDescr           = @cSKUDescr         OUTPUT,
            @cPUOM_Desc       = @cPUOM_Desc        OUTPUT,
            @cMUOM_Desc       = @cMUOM_Desc        OUTPUT,
            @nSKU_CNT         = @nSKU_CNT          OUTPUT,
            @nPQTY            = @nPQTY             OUTPUT,
            @nMQTY            = @nMQTY             OUTPUT,
            @nTtl_Scanned     = @nTtl_Scanned      OUTPUT,
            @nErrNo           = @nErrNo            OUTPUT,
            @cErrMsg          = @cErrMsg           OUTPUT   

         IF ISNULL( @cCurrentSKU, '') <> ''
         BEGIN
            SET @cSKU = @cCurrentSKU
            SET @cStorerKey = @cSKU_StorerKey

            SELECT @nSKU_CNT = COUNT( DISTINCT SKU)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @cStorerKey 
            AND   LLI.ID = @cFromID 
            AND   LOC.Facility = @cFacility
            AND   Qty > 0

            -- Get SKU QTY
            SET @nQTY_Avail = 0 
            SET @nQTY_Alloc = 0
            SET @nQTY_Pick = 0

            SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),
                     @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),
                     @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @cStorerKey 
            AND   LLI.ID = @cFromID 
            AND   LOC.Facility = @cFacility
            AND   SKU = @cSKU

            SELECT 
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
            WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit 
               @nPUOM_Div = 0 -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY_Avail = 0
               SET @nPQTY_Alloc = 0
               SET @nPQTY_Pick = 0
               SET @nMQTY_Avail = @nQTY_Avail 
               SET @nMQTY_Alloc = @nQTY_Alloc
               SET @nMQTY_Pick = @nQTY_Pick
            END
            ELSE
            BEGIN
               SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
               SET @nPQTY_Alloc = @nQTY_Alloc / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY_Alloc = @nQTY_Alloc % @nPUOM_Div -- Calc the remaining in master unit
               SET @nPQTY_Pick = @nQTY_Pick / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY_Pick = @nQTY_Pick % @nPUOM_Div -- Calc the remaining in master unit
            END

            SET @nCurSKU_CNT = @nCurSKU_CNT + 1

            -- Prepare next screen var
            SET @cOutField01 = @cFromID
            SET @cOutField02 = CAST( @nCurSKU_CNT AS NVARCHAR( 2)) + '/' + CAST( @nSKU_CNT AS NVARCHAR( 2))
            SET @cOutField03 = @cSKU
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
            SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
            
            IF @cPUOM_Desc = ''
            BEGIN
               SET @cOutField06 = '' -- @cPUOM_Desc
               SET @cOutField07 = '' -- @nPQTY_Avail
               SET @cOutField08 = '' -- @nPQTY_Alloc
               SET @cOutField09 = '' -- @nPQTY_Pick
            END
            ELSE
            BEGIN
               SET @cOutField06 = @cPUOM_Desc
               SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
               SET @cOutField08 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))
               SET @cOutField09 = CAST( @nPQTY_Pick AS NVARCHAR( 5))
            END
            SET @cOutField10 = @cMUOM_Desc
            SET @cOutField11 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
            SET @cOutField12 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))
            SET @cOutField13 = CAST( @nMQTY_Pick AS NVARCHAR( 5))

            SET @cOutField14 = ''

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 97766
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more sku
            GOTO Step_5_Fail
         END
      END

      -- Validate option value
      IF @cOption NOT IN ('1', '2', '3', '4')
      BEGIN
         SET @nErrNo = 97767
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Step_5_Fail
      END

      IF @cOption = '1' AND @nQTY_Avail = 0
      BEGIN
         SET @nErrNo = 97768
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qtyavl notenuf
         GOTO Step_5_Fail
      END

      IF @cOption = '2' AND @nQTY_Alloc = 0
      BEGIN
         SET @nErrNo = 97769
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qtyalc notenuf
         GOTO Step_5_Fail
      END

      IF @cOption = '3' 
      BEGIN
         IF @nQTY_Pick = 0
         BEGIN
            SET @nErrNo = 97770
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qtypck notenuf
            GOTO Step_5_Fail
         END

         SET @nOrdCount = 0
         SELECT @nOrdCount = COUNT( DISTINCT OrderKey)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.ID = @cFromID
         AND   PD.Status = '5'
         AND   Facility = @cFacility

         IF @nOrdCount > 1
         BEGIN
            SET @nErrNo = 97781
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Id > 1 orders
            GOTO Step_5_Fail
         END
      END

      IF @cOption IN ('1', '2', '3')
      BEGIN
         SET @nQTY_Avail = CASE WHEN @cOption <> '1' THEN 0 ELSE @nQTY_Avail END
         SET @nQTY_Alloc = CASE WHEN @cOption <> '2' THEN 0 ELSE @nQTY_Alloc END
         SET @nQTY_Pick  = CASE WHEN @cOption <> '3' THEN 0 ELSE @nQTY_Pick END


         SELECT @nQTY_Scanned = ISNULL( SUM( QtyMove), 0) 
         FROM rdt.rdtDPKLog WITH (NOLOCK) 
         WHERE FromID = @cFromID
         AND   DropID = @cToID
         AND   SKU = @cSKU
         AND   UserKey = @cUserName

         SET @nBalQty = 0
         SET @nPBalQty = 0
         SET @nMBalQty=0

         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0
         BEGIN
            SET @nMBalQty = CASE WHEN @cOption = '1' THEN @nQTY_Avail 
                                 WHEN @cOption = '2' THEN @nQTY_Alloc 
                                 WHEN @cOption = '3' THEN @nQTY_Pick 
                            END
            SET @cPUOM_Desc = ''    
            SET @nPBalQty = 0
            SET @cFieldAttr08 = 'O'
         END
         ELSE
         BEGIN
            SET @nPBalQty = CASE WHEN @cOption = '1' 
                                 THEN @nQTY_Avail / @nPUOM_Div
                                 WHEN @cOption = '2' 
                                 THEN @nQTY_Alloc / @nPUOM_Div
                                 WHEN @cOption = '3' 
                                 THEN @nQTY_Pick / @nPUOM_Div
                            END

            SET @nMBalQty = CASE WHEN @cOption = '1' 
                                 THEN @nQTY_Avail % @nPUOM_Div
                                 WHEN @cOption = '2' 
                                 THEN @nQTY_Alloc % @nPUOM_Div
                                 WHEN @cOption = '3' 
                                 THEN @nQTY_Pick % @nPUOM_Div
                              END

            SET @cFieldAttr08 = '' -- @nPQTY
            SET @cFieldAttr12 = '' -- @nMQTY
            --SET @nQTY_Scanned = @nQTY_Scanned / @nPUOM_Div
         END

         SET @nBalQty = ( @nPBalQty + @nMBalQty) - @nQTY_Scanned


         IF ISNULL( @nBalQty, 0) <= 0
         BEGIN
            SET @nErrNo = 97786
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more case
            GOTO Step_5_Fail
         END

         -- Disable carton field    
         IF @cDisableCtnFieldSP <> ''    
         BEGIN    
            IF @cDisableCtnFieldSP = '1'    
               SET @cDisableCtnField = @cDisableCtnFieldSP    
            ELSE    
            BEGIN    
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableCtnFieldSP AND type = 'P')    
               BEGIN    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableCtnFieldSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,  ' +     
                  ' @cFromID, @cToID, @cSKU, @nQTY, @cOption, @cDisableCtnField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                  SET @cSQLParam =    
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' + 
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFacility       NVARCHAR( 5),  ' +
                  '@cFromID         NVARCHAR( 18), ' +
                  '@cToID           NVARCHAR( 10), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQty            INT,           ' +
                  '@cOption         NVARCHAR( 1),  ' +    
                  '@cDisableCtnField   NVARCHAR( 1)  OUTPUT, ' +    
                  '@nErrNo             INT            OUTPUT, ' +    
                  '@cErrMsg            NVARCHAR( 20)  OUTPUT'    
    
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
                     @cFromID, @cToID, @cSKU, @nQTY,@cOption, @cDisableCtnField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
    
                  IF @nErrNo <> 0    
                     GOTO Quit    
               END    
            END    
         END    

         --(cc01)
         IF @cDisableCtnField = '1'
         BEGIN
         	SET @cFieldAttr05 = 'O'
            SET @cInField05 = ''
         END
         ELSE
         BEGIN
         	SET @cFieldAttr05 = ''
         END

         -- Prepare next screen var
         SET @cOutField01 = @cFromID
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField05 = ''
         SET @cOutField06 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 10)) END
         SET @cOutField07 = rdt.rdtRightAlign( @cPUOM_Desc, 5) 
         SET @cOutField08 = CASE WHEN @nPBalQty > 0 THEN '1' ELSE '' END
         SET @cOutField09 = CASE WHEN @nPBalQty = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPBalQty AS NVARCHAR( 5)) END
         SET @cOutField10 = CASE WHEN @cRemainSKU = '1' THEN @cActSKU ELSE '' END --(cc01)
         SET @cOutField11 = rdt.rdtRightAlign( @cMUOM_Desc, 5) 
         SET @cOutField12 = ''--CASE WHEN @nPBalQty > 0 THEN '' ELSE CAST( @nMBalQty AS NVARCHAR( 5)) END
         SET @cOutField13 = @nMBalQty

         SET @cFieldAttr10 = CASE WHEN @cRemainSKU = '1' THEN @cActSKU ELSE '' END  --(cc01)
         EXEC rdt.rdtSetFocusField @nMobile, 10

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      IF @cOption = '4'
      BEGIN
         -- Ins pallet info
         SET @nErrNo = 0
         EXEC [RDT].[rdt_PltConsoSSCC_BuildPlt] 
            @nMobile         = @nMobile, 
            @nFunc           = @nFunc, 
            @cLangCode       = @cLangCode, 
            @cStorerkey      = @cStorerkey, 
            @cFromLOC        = @cFromLOC,
            @cFromID         = @cFromID, 
            @cToID           = @cToID, 
            @cType           = 'E', 
            @cOption         = @cOption, 
            @cCartonID       = @cCartonID,
            @nQTY_Move       = @nQTY_Move,
            @nQTY_Alloc      = @nQTY_Alloc,
            @nQTY_Pick       = @nQTY_Pick,
            @cSSCC           = @cSSCC     OUTPUT,  
            @nErrNo          = @nErrNo    OUTPUT,  
            @cErrMsg         = @cErrMsg   OUTPUT   

         IF @nErrNo <> 0
            GOTO Step_5_Fail

         SET @cOutField01 = ''
         
         EXEC rdt.rdtSetFocusField @nMobile, 1

         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4

         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN

      SET @nCurSKU_CNT = 1

      SELECT @nSKU_CNT = COUNT( DISTINCT SKU)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cToID 
      AND   LOC.Facility = @cFacility
      AND   Qty > 0

      -- To ID is empty pallet, go back screen 1
      IF @nSKU_CNT = 0
      BEGIN
         SET @cOutField01 = ''

         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4

         GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField01 = @cToID
      SET @cOutField02 = CAST( @nCurSKU_CNT AS NVARCHAR( 2)) + '/' + CAST( @nSKU_CNT AS NVARCHAR( 2))
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = ''
      SET @cOutField07 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 10)) END
      SET @cOutField08 = @cPUOM_Desc
      SET @cOutField09 = '1'
      SET @cOutField10 = CASE WHEN CAST( (@nPQTY - @nTtl_Scanned) AS NVARCHAR( 3)) < 0 THEN '0' 
                         ELSE CAST( (@nPQTY - @nTtl_Scanned) AS NVARCHAR( 3)) END
      SET @cOutField11 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 6 -- Carton id

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOption = ''

      SET @cOutField14 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 6. Screen = 4545
   Carton ID          (field01, input)
   Carton QTY         (field02, input)
   BAL QTY            (field03)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cCurrentSKU = IsNULL( @cOutField02, '')
      SET @cCartonBarcode = IsNULL( @cInField05, '')
      SET @cPQTY = IsNULL( @cInField08, '') 
      SET @cMQTY = IsNULL( @cInField12, '')
      SET @cPBalQty = IsNULL( @cOutField09, 0)
      SET @cMBalQty = IsNULL( @cOutField13, 0)

      IF @cFieldAttr10 = ''
      BEGIN
         SET @cActSKU = @cInField10

         -- Verify blank
         IF ISNULL( @cActSKU, '') = ''
         BEGIN
            SET @nErrNo = 97796
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Sku required
            EXEC rdt.rdtSetFocusField @nMobile, 10   -- Sku
            GOTO Quit
         END

         -- Extended update
         IF @cDecodeSKUSP <> '' 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSKUSP AND type = 'P')
            BEGIN
               SET @nQty = 0
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSKUSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromID, @cToID, @cOption, ' + 
                  ' @cSKU OUTPUT, @nQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT, '            +
                  '@nFunc           INT, '            +
                  '@cLangCode       NVARCHAR( 3), '   +
                  '@nStep   INT, '            + 
                  '@nInputKey       INT, '            +
                  '@cStorerKey      NVARCHAR( 15), '  +
                  '@cFromID         NVARCHAR( 18), '  +
                  '@cToID           NVARCHAR( 18), '  +
                  '@cOption         NVARCHAR( 10), '  +
                  '@cSKU            NVARCHAR( 20)  OUTPUT, ' +
                  '@nQty            INT            OUTPUT, ' +
                  '@nErrNo          INT            OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT'  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromID, @cToID, @cOption, 
                  @cActSKU OUTPUT, @nQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
               IF @nErrNo <> 0 
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                  GOTO Step_6a_Fail
               END
            END
         END
      
         -- Retrieve actual sku
         EXEC [RDT].[rdt_GETSKUCNT]
            @cStorerKey  = @cStorerKey,
            @cSKU        = @cActSKU,
            @nSKUCnt     = @nSKUCnt       OUTPUT,
            @bSuccess    = @bSuccess      OUTPUT,
            @nErr        = @nErrNo        OUTPUT,
            @cErrMsg     = @cErrMsg       OUTPUT

         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 97797
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong sku
            EXEC rdt.rdtSetFocusField @nMobile, 10   -- Sku
            GOTO Quit
         END

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
                  @cActSKU  OUTPUT,    
                  @nErrNo   OUTPUT,    
                  @cErrMsg  OUTPUT,    
                  'LOTXLOCXID.ID',    -- DocType    
                  @cFromID 
               
               IF @nErrNo = 0 -- Populate multi SKU screen    
               BEGIN    
                  -- Go to Multi SKU screen    
                  SET @nBeforeScn = @nScn    
                  SET @nBeforeStep = @nStep
                  SET @nScn = 3570
                  SET @nStep = @nStep + 3
                  GOTO Quit    
               END    
               IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen    
                  SET @nErrNo = 0    
            END    
            ELSE    
            BEGIN
               SET @nErrNo = 97798
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiBarcodeSKU
               EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku
               GOTO Quit
            END
         END

         EXEC [RDT].[rdt_GETSKU]
            @cStorerKey  = @cStorerkey,
            @cSKU        = @cActSKU       OUTPUT,
            @bSuccess    = @bSuccess      OUTPUT,
            @nErr        = @nErrNo        OUTPUT,
            @cErrMsg     = @cErrMsg       OUTPUT
         
         IF @nErrNo<>0
         BEGIN
            SET @nErrNo = 97798
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiBarcodeSKU
            EXEC rdt.rdtSetFocusField @nMobile, 12   -- Sku
            GOTO Quit
         END
                      
         SELECT @cItemClass = ItemClass
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cActSKU

         -- If itemclass = 001 then sku must be upc.upc
         IF @cItemClass = '001'
         BEGIN
            IF NOT EXISTS ( 
               SELECT 1 FROM dbo.UPC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   UPC = @cInField10
               AND   SKU = @cActSKU)
            BEGIN
               SET @nErrNo = 97799
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong upc
               EXEC rdt.rdtSetFocusField @nMobile, 10   -- Sku
               GOTO Quit
            END
         END

         IF @cCurrentSKU <> @cActSKU
         BEGIN
            SET @nErrNo = 102260
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not Match
            EXEC rdt.rdtSetFocusField @nMobile, 10   -- Sku
            GOTO Quit
         END

         SET @cFieldAttr10 = 'O'
         SET @cOutField10 = @cSKU

         GOTO Quit
      END

      -- Validate blank
      IF @cCartonBarcode = '' 
            AND @cDisableCtnField = '0'  --(cc01)
      BEGIN
         SET @nErrNo = 97775
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton id Req
         GOTO Step_6a_Fail
      END

      -- Decode label
      SET @cDecodeCartonIDSP = rdt.RDTGetConfig( @nFunc, 'DecodeCartonIDSP', @cStorerKey)
      IF @cDecodeCartonIDSP = '0'
         SET @cDecodeCartonIDSP = ''

      -- Extended update
      IF @cDecodeCartonIDSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeCartonIDSP AND type = 'P')
         BEGIN
            SET @nQty = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeCartonIDSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromID, @cToID, @cOption, ' + 
               ' @cSKU OUTPUT, @nQty OUTPUT, @cCartonBarcode OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, '            +
               '@nFunc           INT, '            +
               '@cLangCode       NVARCHAR( 3), '   +
               '@nStep   INT, '            + 
               '@nInputKey       INT, '            +
               '@cStorerKey      NVARCHAR( 15), '  +
               '@cFromID         NVARCHAR( 18), '  +
               '@cToID           NVARCHAR( 18), '  +
               '@cOption         NVARCHAR( 10), '  +
               '@cSKU            NVARCHAR( 20)  OUTPUT, ' +
               '@nQty            INT            OUTPUT, ' +
               '@cCartonBarcode  NVARCHAR( 60)  OUTPUT, ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromID, @cToID, @cOption, 
               @cSKU OUTPUT, @nQty OUTPUT, @cCartonBarcode OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo = -1
            BEGIN
               SET @cCartonID = SUBSTRING( @cCartonBarcode, 1, 20)
               SET @cOutField05 = SUBSTRING( @cCartonBarcode, 1, 20)
               GOTO Quit
            END
            
            IF @nErrNo <> 0 
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_6a_Fail
            END
            ELSE
               SET @cCartonID = SUBSTRING( @cCartonBarcode, 1, 20)
         END
      END
      ELSE
         SET @cCartonID = SUBSTRING( @cCartonBarcode, 1, 20)

      IF @nQty = 0
      BEGIN
         -- Validate PQTY
         IF @cPQTY = '' SET @cPQTY = '0' -- Blank taken as zero
         IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
         BEGIN
            SET @nErrNo = 97776
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY
            GOTO Step_6b_Fail
         END

         -- Validate MQTY
         IF @cMQTY = '' SET @cMQTY = '0' -- Blank taken as zero
         IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
         BEGIN
            SET @nErrNo = 102258
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 12 -- PQTY
            GOTO Step_6b_Fail
         END
      
         -- Calc total QTY in master UOM
         SET @nQTY_Move = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
         SET @nQTY_Move = @nQTY_Move + CAST( @cMQTY AS INT)
      END
      ELSE
      BEGIN
         SET @nQTY_Move = @nQty
      END
      
      SET @nBalQty = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPBalQty, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nBalQty = @nBalQty + CAST( @cMBalQty AS INT)
      
      -- Validate QTY
      IF @nQTY_Move = 0
      BEGIN
         SET @nErrNo = 97778
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY needed'
      GOTO Step_6b_Fail
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY_Move > @nBalQty
      BEGIN
         SET @nErrNo = 97779
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTYAVL NotEnuf'
         GOTO Step_6b_Fail
      END

      SELECT @cPackUOM3 = PACK.PACKUOM3,
             @cPackUOM1 = PACK.PACKUOM1,
             @nCaseCnt = PACK.CaseCnt
      FROM dbo.PACK PACK WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE SKU.Storerkey = @cStorerKey
      AND   SKU.SKU = @cSKU

      IF ( @nQTY_Move % @nCaseCnt) <> 0
      BEGIN
         IF @nBalQty > @nCaseCnt -- If not last pcs
         BEGIN
            SET @nErrNo = 97780
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Mv qty in case'
            GOTO Step_6b_Fail
         END
      END

      -- (james07)
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
               ' @cFromID, @cToID, @cSKU, @nQTY, @nMultiStorer, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cToID           NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT,           ' +
               '@nMultiStorer    NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT           OUTPUT, ' + 
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
               
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
               @cFromID, @cToID, @cSKU, @nQTY, @nMultiStorer, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
            IF @nErrNo <> 0 
               GOTO Step_3_Fail 
         END
      END 

      SET @nMV_Alloc = 0
      SET @nMV_Pick = 0

      IF @nQTY_Alloc > 0 SET @nMV_Alloc = @nQTY_Move

      IF @nQTY_Pick > 0 SET @nMV_Pick = @nQTY_Move     

      -- Ins pallet info
      SET @nErrNo = 0
      EXEC [RDT].[rdt_PltConsoSSCC_BuildPlt] 
         @nMobile         = @nMobile, 
         @nFunc           = @nFunc, 
         @cLangCode       = @cLangCode, 
         @cStorerkey      = @cStorerkey, 
         @cFromLOC        = @cFromLOC,
         @cFromID         = @cFromID, 
         @cToID           = @cToID, 
         @cType           = 'I', 
         @cOption         = @cOption, 
         @cCartonID       = @cCartonID,
         @nQTY_Move       = @nQTY_Move,
         @nQTY_Alloc      = @nQTY_Alloc,
         @nQTY_Pick       = @nQTY_Pick,
         @cSSCC           = @cSSCC     OUTPUT,  
         @nErrNo          = @nErrNo    OUTPUT,  
         @cErrMsg         = @cErrMsg   OUTPUT   

      IF @nErrNo <> 0
         GOTO Step_6a_Fail

      -- Get SKU QTY
      SET @nQTY_Avail = 0 
      SET @nQTY_Alloc = 0
      SET @nQTY_Pick = 0

      -- Get required qty
      SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),
             @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),
             @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   SKU = @cSKU

      SELECT @nPUOM_Div = CAST( Pack.CaseCNT AS INT) 
      FROM dbo.SKU S (NOLOCK) 
      JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

      SET @nQTY_Avail = CASE WHEN @cOption <> '1' THEN 0 ELSE @nQTY_Avail END
      SET @nQTY_Alloc = CASE WHEN @cOption <> '2' THEN 0 ELSE @nQTY_Alloc END
      SET @nQTY_Pick  = CASE WHEN @cOption <> '3' THEN 0 ELSE @nQTY_Pick END

      -- Get scanned qty
      SELECT @nQTY_Scanned = ISNULL( SUM( QtyMove), 0) 
      FROM rdt.rdtDPKLog WITH (NOLOCK) 
      WHERE FromID = @cFromID
      AND   DropID = @cToID
      AND   SKU = @cSKU
      AND   UserKey = @cUserName

      SET @nBalQty = CASE WHEN @cOption = '1' THEN @nQTY_Avail 
                          WHEN @cOption = '2' THEN @nQTY_Alloc 
                          WHEN @cOption = '3' THEN @nQTY_Pick 
                     END

      SET @nBalQty = @nBalQty - @nQTY_Scanned
               
      --SET @nBalQty = @nBalQty - @nQTY_Move

      -- Convert to prefer UOM QTY
      SET @nPBalQty = @nBalQty / @nPUOM_Div -- Calc QTY in preferred UOM
      SET @nMBalQty = @nBalQty % @nPUOM_Div

      -- Stay at the same screen for another carton id
      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = ''
      SET @cOutField06 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 10)) END
      SET @cOutField07 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField08 = CASE WHEN @nPBalQty > 0 THEN '1' ELSE '' END
      SET @cOutField09 = CASE WHEN @nPBalQty > 0 THEN CAST( @nPBalQty AS NVARCHAR( 5)) ELSE '' END
      SET @cOutField10 = ''
      SET @cOutField11 = rdt.rdtRightAlign( @cMUOM_Desc, 5) 
      SET @cOutField12 = ''--CASE WHEN @nPBalQty > 0 THEN '' ELSE CAST( @nMBalQty AS NVARCHAR( 5)) END
      SET @cOutField13 = CAST( @nMBalQty AS NVARCHAR( 5))

      EXEC rdt.rdtSetFocusField @nMobile, 5  -- Carton id
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
   /*
      -- Something scanned
      IF EXISTS ( SELECT 1 FROM rdt.rdtDPKLog WITH (NOLOCK) 
                  WHERE FromID = @cFromID
                  AND   DropID = @cToID
                  AND   UserKey = @cUserName)
      BEGIN
         -- Ins pallet info
         SET @nErrNo = 0
         EXEC [RDT].[rdt_PltConsoSSCC_BuildPlt] 
            @nMobile         = @nMobile, 
            @nFunc           = @nFunc, 
            @cLangCode       = @cLangCode, 
            @cStorerkey      = @cStorerkey, 
            @cFromLOC        = @cFromLOC,
            @cFromID         = @cFromID, 
            @cToID           = @cToID, 
            @cType           = 'U', 
            @cOption         = @cOption, 
            @cCartonID       = @cCartonID,
            @nQTY_Move       = @nQTY_Move,
            @nQTY_Alloc      = @nQTY_Alloc,
            @nQTY_Pick       = @nQTY_Pick,
            @cSSCC           = @cSSCC     OUTPUT,  
            @nErrNo          = @nErrNo    OUTPUT,  
            @cErrMsg         = @cErrMsg   OUTPUT   

         IF @nErrNo <> 0
            GOTO Step_6a_Fail
      END
      */
      SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),
             @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),
             @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   SKU = @cSKU

      SELECT @nSKU_CNT = COUNT( DISTINCT SKU)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey 
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   Qty > 0

      -- Prepare next screen var
      SET @cOutField01 = @cToID
      SET @cOutField02 = CAST( @nCurSKU_CNT AS NVARCHAR( 2)) + '/' + CAST( @nSKU_CNT AS NVARCHAR( 2))
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Avail = 0
         SET @nPQTY_Alloc = 0
         SET @nPQTY_Pick = 0
         SET @nMQTY_Avail = @nQTY_Avail 
         SET @nMQTY_Alloc = @nQTY_Alloc
         SET @nMQTY_Pick = @nQTY_Pick
      END
      ELSE
      BEGIN
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY_Alloc = @nQTY_Alloc / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Alloc = @nQTY_Alloc % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY_Pick = @nQTY_Pick / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Pick = @nQTY_Pick % @nPUOM_Div -- Calc the remaining in master unit
      END

      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cOutField08 = '' -- @nPQTY_Alloc
         SET @cOutField09 = '' -- @nPQTY_Pick
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField08 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))
         SET @cOutField09 = CAST( @nPQTY_Pick AS NVARCHAR( 5))
      END
      SET @cOutField10 = @cMUOM_Desc
      SET @cOutField11 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField12 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))
      SET @cOutField13 = CAST( @nMQTY_Pick AS NVARCHAR( 5))

      SET @cOutField14 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_6a_Fail:
   BEGIN
      SET @cCartonID = ''

      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_6b_Fail:
   BEGIN
      SET @cOutField01 = @cCartonID
      SET @cOutField04 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 7. Screen = 4546
   FROM   ID          (field01)
   No of Carton       (field02, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cNoOfCarton = IsNULL( @cInField02, '')

      -- Validate QTY
      IF @cNoOfCarton = '' SET @cNoOfCarton = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cNoOfCarton, 1) = 0
      BEGIN
         SET @nErrNo = 97800
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         GOTO Step_7_Fail
      END

      IF EXISTS ( SELECT 1 
                  FROM dbo.SKU SKU WITH (NOLOCK) 
                  JOIN dbo.Pack Pack WITH (NOLOCK) ON ( SKU.Packkey = Pack.Packkey)
                  WHERE SKU.StorerKey = @cStorerKey
                  AND   ISNULL( Pack.CaseCnt, 0) = 0
                  AND   EXISTS 
                  ( SELECT 1 FROM dbo.PalletDetail PAD WITH (NOLOCK)
                    WHERE SKU.Sku = PAD.Sku 
                    AND   SKU.StorerKey = PAD.StorerKey
                    AND   PAD.UserDefine01 = @cFromID
                    AND   PAD.StorerKey = @cStorerKey
                    AND   PAD.Status < '9'
                    AND   EXISTS ( SELECT 1 FROM dbo.PickDetail PID WITH (NOLOCK) 
                                   WHERE PAD.UserDefine01 = PID.ID
                                   AND   PAD.UserDefine02 = PID.PickDetailKey
                                   AND   PAD.UserDefine04 = PID.OrderKey
                                   AND   PID.Status < '9')))
      BEGIN
         SET @nErrNo = 102251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No casecnt'
         GOTO Step_7_Fail
      END

      -- Get total carton count. Cannot use distinct caseid because
      -- caseid is not unique. User sometimes key in NA as case id
      SELECT @nCartonCnt = SUM( TTL_CaseCnt) FROM 
         (SELECT ISNULL( SUM( PAD.Qty), 0)/Pack.CaseCnt AS TTL_CaseCnt
         FROM dbo.PALLETDETAIL PAD WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PAD.SKU = SKU.SKU and PAD.StorerKey = SKU.StorerKey)
         JOIN dbo.Pack Pack WITH (NOLOCK) ON ( SKU.Packkey = Pack.Packkey)
         WHERE PAD.UserDefine01 = @cFromID
         AND   PAD.StorerKey = @cStorerKey
         AND   EXISTS ( SELECT 1 FROM dbo.PickDetail PID WITH (NOLOCK) 
                        WHERE PAD.UserDefine01 = PID.ID
                        AND   PAD.UserDefine02 = PID.PickDetailKey
                        AND   PAD.UserDefine04 = PID.OrderKey
                        AND   PID.Status < '9')
         AND   PAD.Status < '9'
         GROUP BY Pack.CaseCnt) A

      --SELECT @nCartonCnt = COUNT( DISTINCT ( CaseID))
      --FROM dbo.PalletDetail PAD WITH (NOLOCK)
      --WHERE PAD.UserDefine01 = @cFromID
      --AND   PAD.StorerKey = @cStorerKey
      --AND   EXISTS ( SELECT 1 FROM dbo.PickDetail PID WITH (NOLOCK) 
      --               WHERE PAD.UserDefine01 = PID.ID
      --               AND   PAD.UserDefine02 = PID.PickDetailKey
      --               AND   PAD.UserDefine04 = PID.OrderKey
      --               AND   PID.Status < '9')
      --AND   [Status] < '9'

      IF @nCartonCnt <> CAST( @cNoOfCarton AS INT)
      BEGIN
         SET @nErrNo = 102252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'#Cnt not match'
         GOTO Step_7_Fail
      END

      IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND   ReportType = 'SSCCMHAPLB')
      BEGIN
         -- Get printer info  
         SELECT   
            @cLabelPrinter = Printer,   
            @cPaperPrinter = Printer_Paper  
         FROM rdt.rdtMobRec WITH (NOLOCK)  
         WHERE Mobile = @nMobile  

         -- Check label printer blank  
         IF @cLabelPrinter = ''  
         BEGIN  
            SET @nErrNo = 97760  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
            GOTO Step_7_Fail  
         END  

         -- Get report info  
         SET @cDataWindow = ''  
         SET @cTargetDB = ''  
         SET @cReportType = 'SSCCMHAPLB'
         SET @cPrintJobName = 'PRINT_SSCCLABEL'

         SELECT   
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
            @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
         FROM RDT.RDTReport WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
            AND ReportType = @cReportType  

         IF @cDataWindow = ''
         BEGIN  
            SET @nErrNo = 97761  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP  
            GOTO Step_7_Fail  
         END  

         IF @cTargetDB = ''
         BEGIN  
            SET @nErrNo = 97762  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET  
            GOTO Step_7_Fail  
         END  

         -- Insert print job 
         SET @nErrNo = 0                    
         EXEC RDT.rdt_BuiltPrintJob                     
            @nMobile,                    
            @cStorerKey,                    
            @cReportType,                    
            @cPrintJobName,                    
            @cDataWindow,                    
            @cLabelPrinter,                    
            @cTargetDB,                    
            @cLangCode,                    
            @nErrNo  OUTPUT,                     
            @cErrMsg OUTPUT,                    
            @cFromID,
            ''

         IF @nErrNo <> 0
            GOTO Step_7_Fail  
      END

      SET @cOutField01 = '' -- ID

      -- Go to next screen
      SET @nScn = 4540
      SET @nStep = 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @nIDQty = ISNULL( SUM( Qty), 0), 
             @nLOTIDQty = ISNULL( SUM( CAST( Lottable12 AS INT)), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   LOC.LocationCategory = 'STAGING'

      SELECT @cHeight = SUSR1,
             @cWeight = SUSR3
      FROM dbo.Storer WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   [Type] = '1'

      SELECT TOP 1 @cSpecialInstruction = O.Notes
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.ID = @cFromID
      AND   PD.Status < '9'

      -- Prepare next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = CASE WHEN @nIDQty = @nLOTIDQty THEN 'FULL' ELSE 'PARTIAL' END
      SET @cOutField03 = @cHeight
      SET @cOutField04 = @cWeight
      SET @cOutField05 = @cSpecialInstruction
      SET @cOutField06 = '' -- Option
      SET @cOutField07 = '' -- SKU
      SET @cOutField08 = @cFromLoc -- LOC  (james03)

      SET @nScn = @nFromScn 
      SET @nStep = @nFromStep 

      EXEC rdt.rdtSetFocusField @nMobile, 6   -- Option

      -- Delete temp record from log table
      DELETE FROM rdt.rdtDPKLog 
      WHERE UserKey = @cUserName 
      AND   TaskDetailKey = CAST( @nFunc AS NVARCHAR( 4))
   END

   Step_7_Fail:
   BEGIN
      SET @cOutField02 = ''

      SET @cNoOfCarton = ''
   END
END
GOTO Quit

/********************************************************************************
Step 8. Screen = 4547
   FROM   ID          (field01)
   No of Carton       (field02, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cSSCC2Validate = IsNULL( @cInField02, '')

      -- If still blank, prompt error
      IF ISNULL( @cSSCC2Validate, '') = ''
      BEGIN
         SET @nErrNo = 102253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC req
         GOTO Step_8_Fail
      END

      -- Decode label
      SET @cDecodeCartonIDSP = rdt.RDTGetConfig( @nFunc, 'DecodeCartonIDSP', @cStorerKey)
      IF @cDecodeCartonIDSP = '0'
         SET @cDecodeCartonIDSP = ''

      -- Extended update
      IF @cDecodeCartonIDSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeCartonIDSP AND type = 'P')
         BEGIN
            SET @cCartonBarcode = @cSSCC2Validate

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeCartonIDSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromID, @cToID, @cOption, ' + 
               ' @cSKU OUTPUT, @nQty OUTPUT, @cCartonBarcode OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, '            +
               '@nFunc           INT, '            +
               '@cLangCode       NVARCHAR( 3), '   +
               '@nStep           INT, '            + 
               '@nInputKey       INT, '            +
               '@cStorerKey      NVARCHAR( 15), '  +
               '@cFromID         NVARCHAR( 18), '  +
               '@cToID           NVARCHAR( 18), '  +
               '@cOption         NVARCHAR( 10), '  +
               '@cSKU            NVARCHAR( 20)  OUTPUT, ' +
               '@nQty            INT            OUTPUT, '  +
               '@cCartonBarcode  NVARCHAR( 60)  OUTPUT, ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromID, @cToID, @cOption, 
               @cSKU OUTPUT, @nQty OUTPUT, @cCartonBarcode OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_8_Fail
            END
            ELSE
               SET @cSSCC2Validate = @cCartonBarcode
         END
      END

      -- Get SSCC
      SELECT TOP 1 @cSSCC = LA.Lottable09
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.ID = @cFromID 
      AND   LLI.Qty > 0
      AND   LOC.Facility = @cFacility
      AND   LOC.LocationCategory = 'STAGING'

      -- If sku.itemclass <> '001'
      -- Set Palletkey = ASRSPallet+YYMMDDHHMM (system date/time)
      IF ISNULL( @cSSCC, '') = '' AND 
         NOT EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
                      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                      WHERE LLI.ID = @cFromID
                      AND   LLI.StorerKey = @cStorerKey
                      AND   SKU.ItemClass = '001'
                      AND   LLI.Qty > 0 -- (Leong01)
                      AND   LOC.Facility = @cFacility
                      AND   LOC.LocationCategory = 'STAGING')
      BEGIN
         SET @cSSCC = 'ASRSPallet' + FORMAT(GETDATE(),'yyMMddHHmm')
      END

      -- If still blank, prompt error
      IF ISNULL( @cSSCC, '') <> ISNULL( @cSSCC2Validate, '')
      BEGIN
         SET @nErrNo = 102254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SSCC
         GOTO Step_8_Fail
      END

      -- Print SSCC label
      SET @nErrNo = 0
      EXEC [RDT].[rdt_PltConsoSSCC_BuildPlt] 
         @nMobile         = @nMobile, 
         @nFunc           = @nFunc, 
         @cLangCode       = @cLangCode, 
         @cStorerkey      = @cStorerkey, 
         @cFromLOC        = @cFromLOC,
         @cFromID         = @cFromID, 
         @cToID           = @cToID, 
         @cType           = @cType, 
         @cOption         = @cOption, 
         @cCartonID       = @cCartonID,
         @nQTY_Move       = 0,
         @nQTY_Alloc      = 0,
         @nQTY_Pick       = 0,
         @cSSCC           = @cSSCC     OUTPUT,
         @nErrNo          = @nErrNo    OUTPUT,  
         @cErrMsg         = @cErrMsg   OUTPUT   

      IF @nErrNo <> 0
         GOTO Step_8_Fail

      IF NOT EXISTS ( SELECT 1 
                        FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                        WHERE LLI.StorerKey = @cStorerKey 
                        AND   LLI.ID <> @cFromID 
                        AND   LOC.Facility = @cFacility
                        AND   LOC.LocationCategory = 'STAGING'
                        AND   Qty > 0)
      BEGIN
         -- If no more pallet then prompt msg inform user
         SET @nErrNo = 0
         SET @cErrMsg1 = 'NO MORE PALLETS'
         SET @cErrMsg2 = 'IN THE LANE.'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END

         SET @cOption = ''
         SET @cOutField06 = ''
      END

      -- Go back screen 1
      -- Prepare next screen var
      SET @cOutField01 = '' -- ID

      -- Go to next screen
      SET @nScn = @nFromScn - 1
      SET @nStep = @nFromStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @nIDQty = ISNULL( SUM( Qty), 0), 
             @nLOTIDQty = ISNULL( SUM( CAST( Lottable12 AS INT)), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.ID = @cFromID 
      AND   LOC.Facility = @cFacility
      AND   LOC.LocationCategory = 'STAGING'

      SELECT @cHeight = SUSR1,
             @cWeight = SUSR3
      FROM dbo.Storer WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   [Type] = '1'

      SELECT TOP 1 @cSpecialInstruction = O.Notes
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.ID = @cFromID
      AND   PD.Status < '9'

      -- Prepare next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = CASE WHEN @nIDQty = @nLOTIDQty THEN 'FULL' ELSE 'PARTIAL' END
      SET @cOutField03 = @cHeight
      SET @cOutField04 = @cWeight
      SET @cOutField05 = @cSpecialInstruction
      SET @cOutField06 = '' -- Option
      SET @cOutField07 = '' -- SKU
      SET @cOutField08 = @cFromLoc -- LOC  (james03)

      SET @nScn = @nFromScn 
      SET @nStep = @nFromStep 

      EXEC rdt.rdtSetFocusField @nMobile, 6   -- Option

      -- Delete temp record from log table
      DELETE FROM rdt.rdtDPKLog 
      WHERE UserKey = @cUserName 
      AND   TaskDetailKey = CAST( @nFunc AS NVARCHAR( 4))
   END

   Step_8_Fail:
   BEGIN
      SET @cOutField02 = ''

      SET @cSSCC2Validate = ''
   END
END
GOTO Quit

    
/********************************************************************************    
Step 9. Screen = 3570. Multi SKU    
   SKU         (Field01)    
   SKUDesc1    (Field02)    
   SKUDesc2   (Field03)    
   SKU         (Field04)    
   SKUDesc1    (Field05)    
   SKUDesc2    (Field06)    
   SKU         (Field07)    
   SKUDesc1    (Field08)    
   SKUDesc2    (Field09)    
   Option      (Field10, input)    
********************************************************************************/    
STEP_9:    
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
         @cACTSKU  OUTPUT,    
         @nErrNo   OUTPUT,    
         @cErrMsg  OUTPUT    
    
      IF @nErrNo <> 0    
      BEGIN    
         IF @nErrNo = -1    
            SET @nErrNo = 0    
         GOTO Quit    
      END    
    
      -- Get SKU info    
      SELECT @cSKUDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cACTSKU    
   END 

   IF @nBeforeStep=2
   BEGIN
      -- Prepare next screen var  
      SET @cOutField01 = @cFromID  
      SET @cOutField02 = CASE WHEN @nIDQty = @nLOTIDQty THEN 'FULL' ELSE 'PARTIAL' END  
      SET @cOutField03 = @cHeight  
      SET @cOutField04 = @cWeight  
      SET @cOutField05 = @cSpecialInstruction  
      SET @cOutField06 = '' -- Option  
      SET @cOutField07 = @cACTSKU  
      SET @cOutField08 = @cFromLoc -- LOC  (james03)  

      -- Go to next screen    
      SET @nScn = @nBeforeScn    
      SET @nStep = @nBeforeStep 
   END
   ELSE IF @nBeforeStep=4
   BEGIN
      -- Prepare next screen var  
      SET @cOutField01 = @cToID  
      SET @cOutField02 = CAST( @nCurSKU_CNT AS NVARCHAR( 2)) + '/' + CAST( @nSKU_CNT AS NVARCHAR( 2))  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  
      SET @cOutField06 = ''  
      SET @cOutField07 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 10)) END  
      SET @cOutField08 = rdt.rdtRightAlign( @cPUOM_Desc, 5)  
      SET @cOutField09 = CASE WHEN @nPBalQty > 0 THEN '1' ELSE '' END  
      SET @cOutField10 =  CASE WHEN @nPBalQty = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPBalQty AS NVARCHAR( 5)) END  
      SET @cOutField11 = ''  
      SET @cOutField12 = @cActSKU  
      SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)  
      SET @cOutField14 = ''--CASE WHEN @nPBalQty > 0 THEN '' ELSE CAST( @nMBalQty AS NVARCHAR( 5)) END  
      SET @cOutField15 = @nMBalQty  

      -- Go to next screen    
      SET @nScn = @nBeforeScn    
      SET @nStep = @nBeforeStep 
   END
   ELSE IF @nBeforeStep = 6
   BEGIN
      -- Prepare next screen var  
      SET @cOutField01 = @cFromID  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
      SET @cOutField05 = ''  
      SET @cOutField06 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 10)) END  
      SET @cOutField07 = rdt.rdtRightAlign( @cPUOM_Desc, 5)   
      SET @cOutField08 = CASE WHEN @nPBalQty > 0 THEN '1' ELSE '' END  
      SET @cOutField09 = CASE WHEN @nPBalQty = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPBalQty AS NVARCHAR( 5)) END  
      SET @cOutField10 = @cActSKU
      SET @cOutField11 = rdt.rdtRightAlign( @cMUOM_Desc, 5)   
      SET @cOutField12 = ''--CASE WHEN @nPBalQty > 0 THEN '' ELSE CAST( @nMBalQty AS NVARCHAR( 5)) END  
      SET @cOutField13 = @nMBalQty  
  
      SET @cFieldAttr10 = ''  
      EXEC rdt.rdtSetFocusField @nMobile, 10  
      -- Go to next screen    
      SET @nScn = @nBeforeScn    
      SET @nStep = @nBeforeStep 
   END
END

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      Facility     = @cFacility,
      -- UserName     = @cUserName,
      Printer      = @cPrinter,
      StorerGroup  = @cStorerGroup,

      V_PUOM_Div  = @nPUOM_Div,
         
      V_StorerKey = @cStorerKey,
      V_ID        = @cFromID, 
      V_UOM       = @cPUOM,
      V_SKU       = @cSKU,
      V_SKUDescr  = @cSKUDescr,
      V_LOC       = @cFromLOC,

      V_Integer1  = @nBeforeScn,
      V_Integer2  = @nBeforeStep,

      V_String1    = @cToID,
      V_String2    = @nMultiStorer,
      V_String3    = @cSSCC,
      V_String4    = @cPUOM_Desc,
      V_String5    = @cMUOM_Desc,
      V_String7    = @nQTY_Avail,
      V_String8    = @nPQTY_Avail,
      V_String9    = @nMQTY_Avail, 
      V_String10   = @nQTY_Alloc,
      V_String11   = @nQTY_Pick,
      V_String12   = @nBalQty,
      V_String14   = @cOption,
      V_String15   = @nCurSKU_CNT,
      V_String16   = @nFromScn,
      V_String17   = @nFromStep,
      V_String18   = @cExtendedValidateSP,
      V_String19   = @cCheckSSCC,          --(cc01)
      V_String20   = @cDisableCtnField,  --(cc01)
      V_String21   = @cActSKU,             --(cc01)
      V_String22   = @cRemainSKU,          --(cc01)
      V_String23   = @cDecodeSKUSP,
      V_String24   = @cMultiSKUBarcode,
      V_String25   = @cDisableCtnFieldSP,  --(cc01)
      V_String26   = @cFlowThStep4,
      V_String27   = @cMultiOrder,

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
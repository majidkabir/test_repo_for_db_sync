SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: RDT Picking using Swap lot SOS122729                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 01-12-2008 1.0  James      Created                                   */
/* 07-05-2009 1.1  Shong      Bug Fixed                                 */
/* 29-05-2009 1.2  Shong      Bug Fixed                                 */
/* 03-07-2009 1.3  Vicky      Bug Fixed - Wrong variable being parse in */
/*                            to call sub-SP  (Vicky01)                 */
/* 21-07-2009 1.4  Vicky      Should not consider empty Lot (Vicky02)   */
/* 10-08-2009 1.5  James      Filter by pickslipno (james01)            */
/* 08-06-2010 1.6  Leong      SOS# 176668 - Check Hold Lot and Loc      */
/* 03-04-2014 1.7  Ung        SOS306868                                 */
/*                            Add DropID                                */
/*                            Add ExtendedUpdateSP                      */
/*                            Add GetSuggestedLOCSP                     */
/*                            Change PickDetail.Status 4->3             */
/* 31-12-2014 1.8  James      SOS326026 - Add EventLog (james02)        */
/* 30-09-2016 1.9  Ung        Performance tuning                        */
/* 22-10-2018 2.0  TungGH     Performance                               */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_Pick_SwapLot] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cOption       NVARCHAR(1),
   @nCount        INT,
   @nRowCount     INT, 
   @cSQL          NVARCHAR(2000),
   @cSQLParam     NVARCHAR(2000)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR(3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR(15),
   @cFacility  NVARCHAR(5),
   @cPrinter   NVARCHAR(10),
   @cUserName  NVARCHAR(18),

   @nError     INT,
   @b_success  INT,
   @n_err      INT,
   @c_errmsg   NVARCHAR(250),

   @cLOC          NVARCHAR(10),
   @cLOT          NVARCHAR(10),

   @cSKU                NVARCHAR(20),
   @cSuggestedSKU       NVARCHAR(20),
   @cDescr              NVARCHAR(60),
   @nQty                INT,
   @cLottable01         NVARCHAR(18),
   @cLottable02         NVARCHAR(18),
   @cLottable03         NVARCHAR(18),
   @dLottable04         DATETIME,
   @cID                 NVARCHAR(18),
   @cPickDetailKey      NVARCHAR(18),
   @cStatus             NVARCHAR(10),
   @cPickSlipNo         NVARCHAR(10),
   @cLogicalLocation    NVARCHAR(18),

   @nTotalLoc           INT,
   @nPickedLoc          INT,
   @cSuggestedLoc       NVARCHAR(10),
   @cNewSuggestedLoc    NVARCHAR(10),
   @nRemainingTask      INT,
   @nSKUCnt             INT,
   @cPUOM               NVARCHAR(1),
   @nPUOM_Div           INT, -- UOM divider
   @nPQTY               INT, -- Preferred UOM QTY
   @nMQTY               INT, -- Master unit QTY
   @cPUOM_Desc          NVARCHAR(5),
   @cMUOM_Desc          NVARCHAR(5),
   @nID_Count           INT,
   @cActPQTY            NVARCHAR(5),
   @cActMQTY            NVARCHAR(5),
   @cBalPQTY            NVARCHAR(5),
   @cBalMQTY            NVARCHAR(5),
   @nAvailQTY           INT,
   @nActPQTY            INT,
   @nActMQTY            INT,
   @nBalPQTY            INT,
   @nBalMQTY            INT,
   @nActQTY             INT,
   @nBalQTY             INT,
   @nIDTotalQty         INT,
   @nIDQtyAlloc         INT,
   @nIDQtyPicked        INT,
   @nIDPickDQty         INT,
   @nQtyPickInProgress  INT,

   @cPickAndSwapLOT            NVARCHAR(20),   -- stored proc for swapping process
   @cPickAndSwapLOTAutoScanOut NVARCHAR(1),   -- configkey to turn on/off auto scan out
   @cDropID             NVARCHAR(20), 
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cGetSuggestedLOCSP  NVARCHAR( 20),
   @cDefaultIDQTY       NVARCHAR( 1),

   @cInField01 NVARCHAR(60),  @cOutField01 NVARCHAR(60),
   @cInField02 NVARCHAR(60),  @cOutField02 NVARCHAR(60),
   @cInField03 NVARCHAR(60),  @cOutField03 NVARCHAR(60),
   @cInField04 NVARCHAR(60),  @cOutField04 NVARCHAR(60),
   @cInField05 NVARCHAR(60),  @cOutField05 NVARCHAR(60),
   @cInField06 NVARCHAR(60),  @cOutField06 NVARCHAR(60),
   @cInField07 NVARCHAR(60),  @cOutField07 NVARCHAR(60),
   @cInField08 NVARCHAR(60),  @cOutField08 NVARCHAR(60),
   @cInField09 NVARCHAR(60),  @cOutField09 NVARCHAR(60),
   @cInField10 NVARCHAR(60),  @cOutField10 NVARCHAR(60),
   @cInField11 NVARCHAR(60),  @cOutField11 NVARCHAR(60),
   @cInField12 NVARCHAR(60),  @cOutField12 NVARCHAR(60),
   @cInField13 NVARCHAR(60),  @cOutField13 NVARCHAR(60),
   @cInField14 NVARCHAR(60),  @cOutField14 NVARCHAR(60),
   @cInField15 NVARCHAR(60),  @cOutField15 NVARCHAR(60),

   @cFieldAttr01 NVARCHAR(1), @cFieldAttr02 NVARCHAR(1),
   @cFieldAttr03 NVARCHAR(1), @cFieldAttr04 NVARCHAR(1),
   @cFieldAttr05 NVARCHAR(1), @cFieldAttr06 NVARCHAR(1),
   @cFieldAttr07 NVARCHAR(1), @cFieldAttr08 NVARCHAR(1),
   @cFieldAttr09 NVARCHAR(1), @cFieldAttr10 NVARCHAR(1),
   @cFieldAttr11 NVARCHAR(1), @cFieldAttr12 NVARCHAR(1),
   @cFieldAttr13 NVARCHAR(1), @cFieldAttr14 NVARCHAR(1),
   @cFieldAttr15 NVARCHAR(1)


-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cPUOM       = V_UOM,
   @cLOC        = V_LOC,
   @cID         = V_ID,
   @cLOT        = V_LOT,
   @nQTY        = V_QTY,
   @cSKU        = V_SKU,
   @cDescr      = V_SKUDescr,
   @cPickSlipNo = V_PickSlipNo,

   @nTotalLoc   = V_Integer1,
   @nPickedLoc  = V_Integer2,
   @nBalQTY     = V_Integer3,
      
   @cSuggestedLoc = V_String3,
   @cSuggestedSKU = V_String4,

   @cMUOM_Desc        = V_String5,
   @cPUOM_Desc        = V_String6,
   @cPickAndSwapLOT   = V_String11,
   @cLogicalLocation  = V_String12,
   @cPickAndSwapLOTAutoScanOut = V_String13,
   @cDropID                    = V_String14,
   @cExtendedUpdateSP          = V_String15, 
   @cExtendedValidateSP        = V_String16, 
   @cGetSuggestedLOCSP         = V_String17, 
   @cDefaultIDQTY              = V_String18, 
   
   @nPUOM_Div         = V_PUOM_Div,
   @nMQTY             = V_MQTY,
   @nPQTY             = V_PQTY,

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

IF @nFunc = 1640  -- Picking Swap Lot
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Picking Swap Lot
   IF @nStep = 1 GOTO Step_1   -- Scn = 1910. PS NO
   IF @nStep = 2 GOTO Step_2   -- Scn = 1911. PS NO, TOTAL LOC, PICKEDLOC, LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1912. SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 1913. SKU, BAL QTY, ID
   IF @nStep = 5 GOTO Step_5   -- Scn = 1914. SKU, LOTTABLES, BAL QTY, PICKQTY
   IF @nStep = 6 GOTO Step_6   -- Scn = 1915. MSG. Picked successfully
   IF @nStep = 7 GOTO Step_7   -- Scn = 1916. MSG. Remaining, task not completed
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1640. Menu
********************************************************************************/
Step_0:
BEGIN
   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep
      
   -- Storer configure
   SET @cPickAndSwapLOT = rdt.RDTGetConfig( @nFunc, 'PickAndSwapLOT', @cStorerKey)
   SET @cPickAndSwapLOTAutoScanOut = rdt.RDTGetConfig( @nFunc, 'PickAndSwapLotAutoScanOut', @cStorerKey)
   SET @cDefaultIDQTY = rdt.RDTGetConfig( @nFunc, 'DefaultIDQTY', @cStorerKey)
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cGetSuggestedLOCSP = rdt.rdtGetConfig( @nFunc, 'GetSuggestedLOCSP', @cStorerKey)
   IF @cGetSuggestedLOCSP = '0'
      SET @cGetSuggestedLOCSP = ''

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL(DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Set the entry point
   SET @nScn = 1910
   SET @nStep = 1

   -- Initiate var
   SET @cPickSlipNo = ''
   SET @cDropID = ''

   -- Init screen
   SET @cOutField01 = '' -- PS NO

END
GOTO Quit

/********************************************************************************
Step 1. Scn = 1910. PSNO
   PSNO      (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cPickSlipNo = @cInField01

      -- Validate blank
      IF ISNULL(@cPickSlipNo, '') = ''
      BEGIN
         SET @nErrNo = 66051
         SET @cErrMsg = rdt.rdtgetmessage(66051, @cLangCode,'DSP') --PSNO requiured
         GOTO Step_1_Fail
      END

      --validate replenGroup
      IF NOT EXISTS (SELECT 1
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo)
      BEGIN
         SET @nErrNo = 66052
         SET @cErrMsg = rdt.rdtgetmessage(66052, @cLangCode,'DSP') --Invalid PSNO
         GOTO Step_1_Fail
      END

      IF NOT EXISTS (SELECT 1
         FROM   dbo.PickHeader PH WITH (NOLOCK)
         JOIN   dbo.Orders O WITH (NOLOCK) ON PH.ExternOrderKey = O.LoadKey
         WHERE  PH.PickHeaderKey = @cPickSlipNo
            AND O.StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 66053
         SET @cErrMsg = rdt.rdtgetmessage(66053, @cLangCode, 'DSP') --Diff Storer
         GOTO Step_1_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
         Where PickslipNo = @cPickSlipNo
            AND ScanOutDate IS NOT NULL)
      BEGIN
         SET @nErrNo = 66054
         SET @cErrMsg = rdt.rdtgetmessage(66054, @cLangCode, 'DSP') --PS Scanned Out
         GOTO Step_1_Fail
      END

      -- If PS not scanned in, auto scan in
      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
         Where PickslipNo = @cPickSlipNo)
      BEGIN
         INSERT INTO dbo.PickingInfo
         (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)
         VALUES
         (@cPickSlipNo, GETDATE(), @cUserName, NULL, @cUserName)
      END

      -- Get the total no. of pick loc with status <= Picked
      SELECT @nTotalLoc = COUNT(DISTINCT LOC)
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND Status <= '3'

      -- Get the total no. of pick loc with status = Picked
      SELECT @nPickedLoc = COUNT(DISTINCT LOC)
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND Status = '3'

      SET @cLOC = ''
      SET @cSuggestedLoc = ''
      SET @cLogicalLocation = ''

      -- Get Suggested LOC
      IF @cGetSuggestedLOCSP <> ''
      BEGIN
         -- Default suggested LOC method
         IF @cGetSuggestedLOCSP = '1'
            SELECT TOP 1 
               @cLogicalLocation = L.LogicalLocation, 
               @cSuggestedLoc = L.LOC 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.PickSlipNo = @cPickSlipNo
               AND PD.Status < '3'
               AND L.Facility = @cFacility
            ORDER BY L.LogicalLocation, L.LOC
         
         -- Custom suggested LOC method
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetSuggestedLOCSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetSuggestedLOCSP) +
               ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cPickSlipNo, @cLOC, @cSuggestedLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cSuggestedLOC   NVARCHAR( 10) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cPickSlipNo, @cLOC, @cSuggestedLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @nTotalLoc   -- TOTALLOC
      SET @cOutField03 = @nPickedLoc   -- PICKEDLOC
      SET @cOutField04 = @cSuggestedLoc   -- LOC
      SET @cOutField05 = ''   -- LOC
      SET @cLOC = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      -- EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
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

   Step_1_Fail:
   BEGIN
      SET @cPickSlipNo = ''
      SET @cOutField01 = '' -- PS NO
   END

END
GOTO Quit

/********************************************************************************
Step 2. Scn = 1911. LOC
   PS NO          (field01)
   TOTAL LOC      (field02)
   PICKEDLOC      (field03)
   LOC            (field04)
   LOC            (field05, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
    SET @cLOC = @cInField05

      -- If LOC is blank, get the next available LOC within the same PS
      IF ISNULL(@cLOC, '') = ''
      BEGIN
         -- Not suggest LOC
         IF @cGetSuggestedLOCSP = ''
         BEGIN
            SET @nErrNo = 66075
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Need LOC
            GOTO Step_2_Fail
         END
         
         -- Suggest LOC
         SET @cNewSuggestedLoc = ''
         IF @cGetSuggestedLOCSP = '1'
            SELECT TOP 1
               @cLogicalLocation = L.LogicalLocation,
               @cNewSuggestedLoc = L.LOC
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.PickSlipNo = @cPickSlipNo
               AND PD.Status < '3'
   --            AND PD.LOC > @cSuggestedLoc
               AND L.LogicalLocation + L.LOC >
                  CONVERT(NVARCHAR(18), ISNULL(@cLogicalLocation, '')) + CONVERT(NVARCHAR(10), ISNULL(@cSuggestedLoc, ''))
               AND L.Facility = @cFacility
            GROUP BY L.LogicalLocation, L.LOC
            ORDER BY L.LogicalLocation, L.LOC

         -- Check no more LOC
         IF @cNewSuggestedLoc = ''
         BEGIN
            SET @nErrNo = 66056
            SET @cErrMsg = rdt.rdtgetmessage(66056, @cLangCode,'DSP') --No more record
            GOTO Step_2_Fail
         END
         SET @cSuggestedLoc = @cNewSuggestedLoc

         -- Prepare next screen var
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = @nTotalLoc   -- TOTALLOC
         SET @cOutField03 = @nPickedLoc   -- PICKEDLOC
         SET @cOutField04 = @cSuggestedLoc   -- LOC
         SET @cOutField05 = ''   -- LOC
         SET @cLOC = ''

         GOTO Quit
      END

      IF ISNULL(@cLOC, '') <> ''
      BEGIN
         -- Not suggest LOC
         IF @cGetSuggestedLOCSP = ''
         BEGIN
            -- Get LOC info  
            DECLARE @cChkFacility NVARCHAR( 5)  
            SELECT @cChkFacility = Facility  
            FROM dbo.LOC WITH (NOLOCK)  
            WHERE LOC = @cLOC  
        
            -- Validate LOC  
            IF @@ROWCOUNT = 0
            BEGIN  
               SET @nErrNo = 66076  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
               GOTO Step_2_Fail  
            END  
              
            -- Validate facility  
            IF @cChkFacility <> @cFacility
            BEGIN  
               SET @nErrNo = 66077  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
               GOTO Step_2_Fail  
            END  

            -- Check LOC on PickSlip
            IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND LOC = @cLOC
                  AND Status < '3')
            BEGIN
               SET @nErrNo = 66078  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- No task in LOC  
               GOTO Step_2_Fail
            END
         END
         
         --validate LOC
         IF @cGetSuggestedLOCSP = '1' AND @cSuggestedLoc <> @cLOC
         BEGIN
            SET @nErrNo = 66057
            SET @cErrMsg = rdt.rdtgetmessage(66057, @cLangCode,'DSP') --Diff LOC
            GOTO Step_2_Fail
         END
      END

      SELECT TOP 1 @cSuggestedSKU = SKU FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND Status < '3'
         AND LOC = @cLOC
      ORDER BY SKU

      SELECT @cDescr = Descr FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSuggestedSKU

      -- Prepare next screen var
      SET @cOutField01 = @cSuggestedSKU
      SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField03 = SUBSTRING(@cDescr, 21, 20)
      SET @cOutField04 = ''   -- SKU

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @nRemainingTask = COUNT(DISTINCT LOC)
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND Status < '3'

      IF @nRemainingTask = 0
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = ''  -- PSNO
--         SET @cPickSlipNo = ''

         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @nRemainingTask  -- PSNO

         -- Go to Option screen
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5
      END
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField05 = ''
      SET @cLOC = '' -- LOC
   END

END
GOTO Quit

/********************************************************************************
Step 3. Scn = 1912. SKU
   SKU      (field01)
   DESCR1   (field02)
   DESCR2   (field03)
   SKU      (field04, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      --screen mapping
      SET @cSKU = @cInField04

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @nErrNo = 66058
         SET @cErrMsg = rdt.rdtgetmessage(66058, @cLangCode,'DSP') --SKU/UPC needed
         GOTO Step_3_Fail
      END

      EXEC [RDT].[rdt_GETSKUCNT]
                     @cStorerKey  = @cStorerKey
      ,              @cSKU        = @cSKU
      ,              @nSKUCnt     = @nSKUCnt OUTPUT
      ,              @bSuccess    = @b_Success     OUTPUT
      ,              @nErr        = @n_Err         OUTPUT
      ,              @cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 66059
         SET @cErrMsg = rdt.rdtgetmessage(66059, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_3_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 66060
         SET @cErrMsg = rdt.rdtgetmessage(66060, @cLangCode, 'DSP') --'SameBarCodeSKU'
         GOTO Step_3_Fail
      END

      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

      IF @cSuggestedSKU <> @cSKU
      BEGIN
         SET @nErrNo = 66061
         SET @cErrMsg = rdt.rdtgetmessage(66061, @cLangCode, 'DSP') --'Different SKU'
         GOTO Step_3_Fail
      END

      SELECT @nQTY = SUM(QTY) FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND Status < '3'
         AND LOC = @cLOC
         AND SKU = @cSKU

      -- Get Pack info
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
         @nPUOM_Div = CAST(IsNULL(
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
         AND SKU.SKU = @cSKU

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

      --prepare next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField03 = SUBSTRING(@cDescr, 21, 20)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField04 = '' -- @cPUOM_Desc
         SET @cOutField05 = '' -- @nPQTY
         SET @cOutField07 = '' -- @nActPQTY
         -- Disable pref QTY field
         SET @cFieldAttr07 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField04 = '1:' + CAST(@nPUOM_Div AS NVARCHAR(6))
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField07 = @nPQTY -- ActPQTY
      END
      SET @cOutField06 = @cMUOM_Desc --PKSLIPNO
      SET @cOutField08 = @nMQTY
      SET @cOutField09 = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @nTotalLoc   -- TOTALLOC
      SET @cOutField03 = @nPickedLoc   -- PICKEDLOC
      SET @cOutField04 = @cSuggestedLoc   -- LOC
      SET @cOutField05 = ''   -- LOC

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

 Step_3_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField04 = '' -- SKU
   END

END
GOTO Quit

/********************************************************************************
Step 4. Scn = 1913. ID screen
   SKU       (field01)
   DESCR1    (field02)
   DESCR2    (field03)
   PUOM MUOM (Field04, Field05, Field06)
   BAL QTY   (Field07, Field08)
   ID        (field09, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
      SET @cID = @cInField09

      -- Validate blank
      IF ISNULL(@cID, '') = ''
      BEGIN
         SET @nErrNo = 66062
         SET @cErrMsg = rdt.rdtgetmessage(66062, @cLangCode,'DSP') --ID is needed
         GOTO Step_4_Fail
      END

      -- If ID not in the same LOC, SKU, PSNo
      IF NOT EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
--            AND PickSlipNo = @cPickSlipNo
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND ID = @cID)
      BEGIN
         SET @nErrNo = 66063
         SET @cErrMsg = rdt.rdtgetmessage(66063, @cLangCode,'DSP') --Invalid ID
         GOTO Step_4_Fail
      END
        -- Change Here...Shong
      -- Reject when Status = HOLD
      IF EXISTS (SELECT 1 FROM dbo.ID WITH (NOLOCK)
         WHERE ID = @cID
            AND Status = 'HOLD')
      BEGIN
         SET @nErrNo = 66070
         SET @cErrMsg = rdt.rdtgetmessage(66070, @cLangCode,'DSP') --Pallet On Hold
         GOTO Step_4_Fail
      END

      SELECT @nID_Count = COUNT(DISTINCT LOT)
      FROM dbo.LotxLocxID LLI WITH (NOLOCK)
      JOIN dbo.LOC L WITH (NOLOCK) ON (LLI.LOC = L.LOC)
      WHERE LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LLI.ID = @cID
         AND L.Facility = @cFacility
         AND LLI.QTY > 0 -- (Vicky02)

      IF @nID_Count > 1 -- ID contains multiple LOT
      BEGIN
         SET @nErrNo = 66064
         SET @cErrMsg = rdt.rdtgetmessage(66064, @cLangCode,'DSP') --Multi LOT ID
         GOTO Step_4_Fail
      END


      SELECT TOP 1 @cLOT = LOT
      FROM dbo.LotxLocxID LLI WITH (NOLOCK)
      JOIN dbo.LOC L WITH (NOLOCK) ON (LLI.LOC = L.LOC)
      WHERE LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LLI.LOC = @cLOC
         AND LLI.ID = @cID
         AND L.Facility = @cFacility
         AND LLI.QTY > 0 -- (Vicky02)

      -- Check if the pallet id scanned exists in pickdetail within the pickslipno scanned
      -- if exists then check whether any available pick task to continue
      -- note: I check the id exists first to prevent user scanning free inventory id which might not exists on pickdetail
      SELECT @nQtyPickInProgress = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOT = @cLOT
         AND LOC = @cLOC
         AND ID = @cID
         AND SKU = @cSKU
         AND STATUS = '3'

      -- Get QTY to pick, for this LOT
      DECLARE @nQTYToPick INT
      SELECT @nQTYToPick = ISNULL(SUM(QTY), 0) 
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND LOT = @cLOT
         AND LOC = @cLOC
         -- AND ID = @cID
         AND STATUS = '0'

      -- Get ID QTY available
      DECLARE @nIDQTYAvail INT
      SELECT @nIDQTYAvail = ISNULL( SUM( QTY - QTYPicked), 0)
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE  LOT = @cLOT
         AND LOC = @cLOC
         AND ID  = @cID
      
      -- Deduct already taken for this ID
      SET @nIDQTYAvail = @nIDQTYAvail - @nQtyPickInProgress
      
      -- Get QTY can be pick for this ID
      IF @nQTYToPick > @nIDQTYAvail
         SET @nQTYToPick = @nIDQTYAvail 

      -- Check ID has QTY avai
      IF @nIDQTYAvail < 1
      BEGIN
         SET @nErrNo = 66071
         SET @cErrMsg = rdt.rdtgetmessage(66071, @cLangCode,'DSP') --ID Fully Pick
         GOTO Step_4_Fail
      END

      --SOS# 176668 (Start)
      IF EXISTS (SELECT 1 FROM dbo.LOT WITH (NOLOCK)--Check hold LOT
                 WHERE STATUS    = 'HOLD'
                   AND LOT       = @cLOT
                   AND StorerKey = @cStorerKey
                   AND SKU       = @cSKU)
      BEGIN
         SET @nErrNo = 66073
         SET @cErrMsg = rdt.rdtgetmessage(66073, @cLangCode,'DSP') --LOT On Hold
         GOTO Step_4_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)--Check hold LOC
                 WHERE LOC = @cLOC
                   AND (Status = 'HOLD' OR LocationFlag = 'HOLD'))
      BEGIN
         SET @nErrNo = 66074
         SET @cErrMsg = rdt.rdtgetmessage(66074, @cLangCode,'DSP') --LOC On Hold
         GOTO Step_4_Fail
      END
      --SOS# 176668 (End)

      SELECT
         @cLottable01 = Lottable01,
         @cLottable02 = Lottable02,
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04
      FROM dbo.LotAttribute WITH (NOLOCK)
      WHERE LOT = @cLOT

      -- Convert to prefer UOM QTY
      DECLARE @nPIDQTY INT
      DECLARE @nMIDQTY INT
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @nPIDQTY = 0
         SET @nMIDQTY = @nQTYToPick
      END
      ELSE
      BEGIN
         SET @nPIDQTY = @nQTYToPick / @nPUOM_Div  -- Calc QTY in preferred UOM
         SET @nMIDQTY = @nQTYToPick % @nPUOM_Div  -- Calc the remaining in master unit
      END

      -- Prepare next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = @cLottable01
      SET @cOutField03 = @cLottable02
      SET @cOutField04 = @cLottable03
      SET @cOutField05 = rdt.rdtFormatDate(@dLottable04)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY
         SET @cOutField09 = '' -- @nActPQTY
         -- Disable pref QTY field
         SET @cFieldAttr11 = 'O'
         SET @cOutField11 = ''
      END
      ELSE
      BEGIN
         SET @cOutField06 = '1:' + CAST(@nPUOM_Div AS NVARCHAR(6))
         SET @cOutField07 = @cPUOM_Desc
         SET @cOutField09 = @nPQTY -- ActPQTY
         SET @cOutField11 = CASE WHEN @cDefaultIDQTY = '1' THEN @nPIDQTY ELSE '' END
      END
      SET @cOutField08 = @cMUOM_Desc -- Master UOM
      SET @cOutField10 = @nMQTY -- @nActMQTY
      SET @cOutField12 = CASE WHEN @cDefaultIDQTY = '1' THEN @nMIDQTY ELSE '' END
      SET @cOutField13 = '' -- @cDropID

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField03 = SUBSTRING(@cDescr, 21, 20)
      SET @cOutField04 = ''   -- SKU

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:

END
GOTO Quit

/********************************************************************************
Step 5. Scn = 1914. QTY, DropID
   ID         (field01)
   LOTTABLES1 (field02)
   LOTTABLES2 (field03)
   LOTTABLES3 (field04)
   LOTTABLES4 (field05)
   PUOM MUOM  (Field07, Field08)
   BAL QTY    (Field09, Field10)
   PICKQTY    (Field11, Field12, input)
   DROP ID    (Field13, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cBalPQTY = CASE WHEN @cFieldAttr11 = 'O' THEN '' ELSE IsNULL(@cOutField09, '') END
      SET @cBalMQTY = IsNULL(@cOutField10, '')

      SET @cActPQTY = CASE WHEN @cFieldAttr11 = 'O' THEN '' ELSE IsNULL(@cInField11, '') END
      SET @cActMQTY = IsNULL(@cInField12, '')
      SET @cDropID = @cInField13

      -- Validate ActPQTY
      IF @cActPQTY = '' SET @cActPQTY = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY(@cActPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 66065
         SET @cErrMsg = rdt.rdtgetmessage(66065, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- PQTY
         GOTO Step_5_Fail
      END

      -- Validate ActMQTY
      IF @cActMQTY  = '' SET @cActMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY(@cActMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 66066
         SET @cErrMsg = rdt.rdtgetmessage(66066, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- MQTY
         GOTO Step_5_Fail
      END

      -- Calc total QTY in master UOM
      SET @nActPQTY = CAST(@cActPQTY AS INT)
      SET @nActMQTY = CAST(@cActMQTY AS INT)
      SET @nActQTY = rdt.rdtConvUOMQTY(@cStorerKey, @cSKU, @nActPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nActQTY = @nActQTY + @nActMQTY

      -- Calc total QTY in master UOM
      SET @nBalPQTY = CAST(@cBalPQTY AS INT)
      SET @nBalMQTY = CAST(@cBalMQTY AS INT)
      SET @nBalQTY = rdt.rdtConvUOMQTY(@cStorerKey, @cSKU, @nBalPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nBalQTY = @nBalQTY + @nBalMQTY

      -- Validate QTY
      IF @nActQTY = 0
      BEGIN
         SET @nErrNo = 66067
         SET @cErrMsg = rdt.rdtgetmessage(66067, @cLangCode, 'DSP') --'QTY needed'
         GOTO Step_5_Fail
      END

      IF @nActQTY > @nBalQTY
      BEGIN
         SET @nErrNo = 66068
         SET @cErrMsg = rdt.rdtgetmessage(66068, @cLangCode,'DSP') --Over Pick
         GOTO Step_5_Fail
      END

      SELECT @nIDPickDQty = SUM(QTY)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Loc LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.ID = @cID
         AND PD.LOC = @cLOC
         AND PD.LOT = @cLOT
         -- AND PD.PickSlipNo = @cPickSlipNo	(james01)
         AND PD.PickSlipNo = @cPickSlipNo
         AND PD.Status = '0'
         AND LOC.Facility = @cFacility

      SELECT
         @nIDTotalQty = SUM(LLI.QTY),
         @nIDQtyAlloc = SUM(LLI.QtyAllocated),
         @nIDQtyPicked = SUM(LLI.QtyPicked)
      FROM dbo.LotxLocxID LLI WITH (NOLOCK)
      JOIN dbo.Lot LOT WITH (NOLOCK) ON (LLI.LOT = LOT.LOT)
      JOIN dbo.Loc LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN dbo.ID ID WITH (NOLOCK) ON (LLI.ID = ID.ID)
      WHERE LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LLI.LOT = @cLOT
         AND LLI.LOC = @cLOC
         AND LLI.ID = @cID
         AND LOC.LocationFlag NOT IN ('HOLD','DAMAGE')
         AND LOC.Facility = @cFacility
         AND LOT.STATUS = 'OK'
         AND LOC.STATUS = 'OK'
         AND ID.STATUS = 'OK'

      -- Check if qty wanna pick is greater than what is allocated.
      -- If Yes then we check for free qty in LotxLocxID
      -- Else we do have enuf qty to pick

      IF @nActQTY > @nIDPickDQty
      BEGIN
         -- If qty wanna pick greater than what we have in LotxLocxID, prompt error
         IF (@nActQTY - @nIDPickDQty) > (@nIDTotalQty - @nIDQtyAlloc - @nIDQtyPicked)
         BEGIN
            SET @nErrNo = 66069
            SET @cErrMsg = rdt.rdtgetmessage(66069, @cLangCode,'DSP') --ID Over Pick
            GOTO Step_5_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cPickSlipNo, @cLOT, @cLOC, @cID, @cSKU, @nBalQTY, @nActQTY, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cLOT            NVARCHAR( 10), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nBalQTY         INT,           ' +
               '@nActQTY         INT,           ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cPickSlipNo, @cLOT, @cLOC, @cID, @cSKU, @nBalQTY, @nActQTY, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_5_Fail
         END
      END

      IF ISNULL(RTRIM(@cPickAndSwapLOT), '') <> ''
      BEGIN
         -- Check if not exists within the same pickslip + loc + sku + id + lot, need to swap lot
         IF (SELECT ISNULL(SUM(Qty),0)
             FROM  dbo.PickDetail WITH (NOLOCK)
             WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
               AND LOC = @cLOC
               AND SKU = @cSKU
               AND ID = @cID
               AND LOT = @cLOT
               AND Status < '3') < @nActQTY
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = ISNULL(RTRIM(@cPickAndSwapLOT), '') AND type = 'P')
            BEGIN
               SET @nErrNo = 66072
               SET @cErrMsg = rdt.rdtgetmessage(66072, @cLangCode,'DSP') --SPROCNotSetup
               GOTO Step_5_Fail
            END

            SELECT
               @cLottable01 = Lottable01,
               @cLottable02 = Lottable02,
               @cLottable03 = Lottable03,
               @dLottable04 = Lottable04
            FROM dbo.LotAttribute WITH (NOLOCK)
            WHERE LOT = @cLOT

            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cPickAndSwapLOT) + ' @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility, ' + 
                ' @cPickSlipNo, @cSKU, @cLOC, @cID, @nActQTY, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam = 
               '@nMobile      INT,          ' + 
               '@nFunc        INT,          ' +  
               '@cLangCode    NVARCHAR(3),  ' +
               '@cUserName    NVARCHAR(18), ' + 
               '@cStorerkey   NVARCHAR(15), ' +
               '@cFacility    NVARCHAR(5),  ' +
               '@cPickSlipNo  NVARCHAR(10), ' +
               '@cSKU         NVARCHAR(20), ' +
               '@cLOC         NVARCHAR(10), ' +
               '@cID          NVARCHAR(18), ' +
               '@nActQTY      INT,          ' +
               '@cLottable01  NVARCHAR(18), ' +
               '@cLottable02  NVARCHAR(18), ' +
               '@cLottable03  NVARCHAR(18), ' +
               '@dLottable04  DATETIME,     ' +
               '@cDropID      NVARCHAR(20), ' + 
               '@nErrNo       INT          OUTPUT, ' +
               '@cErrMsg      NVARCHAR(20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility,
               @cPickSlipNo,
               @cSKU,
               @cLOC,
               @cID,  -- ID to be swapped
               @nActQTY,
               @cLottable01,
               @cLottable02,
               @cLottable03,
               @dLottable04,
               @cDropID,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_5_Fail
            END
            -- 2009-05-29 Added by SHONG
            GOTO Step_5_Complete
         END
      END

      SET @nErrNo = 0
      EXECUTE rdt.rdt_Pick_SwapLot_ConfirmTask @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility,
         @cSKU,
         @cPickSlipNo,
         @cLOT,
         @cLOC,
         @cID,
         @nActQTY,
         '3',         -- 3=In-Progress, 5=Picked
         @cDropID,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT

      IF @nErrNo <> 0
      BEGIN
         GOTO Step_5_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cPickSlipNo, @cLOT, @cLOC, @cID, @cSKU, @nBalQTY, @nActQTY, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cLOT            NVARCHAR( 10), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nBalQTY         INT,           ' +
               '@nActQTY         INT,           ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cPickSlipNo, @cLOT, @cLOC, @cID, @cSKU, @nBalQTY, @nActQTY, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_5_Fail
         END
      END

   Step_5_Complete:
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField03 = SUBSTRING(@cDescr, 21, 20)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField04 = '1:1' -- @cPUOM_Desc
         SET @cOutField05 = '' -- @nPQTY
         SET @cOutField07 = '' -- @nActPQTY
         -- Disable pref QTY field
         SET @cFieldAttr11 = ''
      END
      ELSE
      BEGIN
         SET @cOutField04 = '1:' + CAST(@nPUOM_Div AS NVARCHAR(6))
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField07 = @nPQTY -- ActPQTY
      END
      SET @cOutField06 = @cMUOM_Desc --PKSLIPNO
      SET @cOutField08 = @nMQTY
      SET @cOutField09 = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   Step_5_Fail:

   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 6. Scn = 1915. Message
   Picked successfully
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey IN (0, 1)
   BEGIN
      -- Get QTY pick for same LOC, same SKU
      SET @nQTY = 0
      SELECT @nQTY = SUM(QTY) FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND Status < '3'
         AND LOC = @cLOC
         AND SKU = @cSKU

      -- Same LOC, same SKU, different ID, goto ID screen
      IF @nQTY > 0
      BEGIN
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

         --prepare next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
         SET @cOutField03 = SUBSTRING(@cDescr, 21, 20)
         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField04 = '' -- @cPUOM_Desc
            SET @cOutField05 = '' -- @nPQTY
            SET @cOutField07 = '' -- @nActPQTY
         -- Disable pref QTY field
            SET @cFieldAttr07 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField04 = '1:' + CAST(@nPUOM_Div AS NVARCHAR(6))
            SET @cOutField05 = @cPUOM_Desc
            SET @cOutField07 = @nPQTY -- ActPQTY
         END
         SET @cOutField06 = @cMUOM_Desc 
         SET @cOutField08 = @nMQTY
         SET @cOutField09 = ''

         -- Go to ID screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
         
         GOTO Quit
      END

      -- Get suggested SKU in same LOC
      SET @cSuggestedSKU = ''
      SELECT TOP 1 @cSuggestedSKU = SKU
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND Status < '3'
         AND LOC = @cLOC
      ORDER BY SKU

      -- Same LOC, same / different SKU, goto SKU screen
      IF @cSuggestedSKU <> ''
      BEGIN
         SELECT @cDescr = Descr FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSuggestedSKU

         -- Prepare next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
         SET @cOutField03 = SUBSTRING(@cDescr, 21, 20)
         SET @cOutField04 = ''   -- SKU
         set @cSKU = ''

         -- Go to screen 3
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3
         
         GOTO Quit
      END
         
      -- Get next suggested LOC 
      SET @cNewSuggestedLoc = ''
      IF @cGetSuggestedLOCSP = '1' -- Suggest LOC
         SELECT TOP 1
            @cLogicalLocation = L.LogicalLocation,
            @cNewSuggestedLoc = L.LOC
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.PickSlipNo = @cPickSlipNo
            AND PD.Status < '3'
            AND L.LogicalLocation + L.LOC >
               CONVERT(NVARCHAR(18), ISNULL(@cLogicalLocation, '')) + CONVERT(NVARCHAR(10), ISNULL(@cSuggestedLoc, ''))
            AND L.Facility = @cFacility
         GROUP BY L.LogicalLocation, L.LOC
         ORDER BY L.LogicalLocation, L.LOC

      -- Get all LOC
      IF @cNewSuggestedLoc = '' OR @cGetSuggestedLOCSP = '0' -- Not suggest LOC
         SELECT TOP 1 @cNewSuggestedLoc = PD.LOC
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.PickSlipNo = @cPickSlipNo
            AND PD.Status < '3'
            AND L.Facility = @cFacility
         ORDER BY L.LogicalLocation, L.LOC
      
      -- Goto LOC screen
      IF @cNewSuggestedLoc <> ''
      BEGIN
         SET @cSuggestedLoc = @cNewSuggestedLoc

         -- Get the total no. of pick loc with status <= Picked
         SELECT @nTotalLoc = COUNT(DISTINCT LOC)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND Status <= '3'

         -- Get the total no. of pick loc with status = Picked
         SELECT @nPickedLoc = COUNT(DISTINCT LOC)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND Status = '3'

         -- Prepare next screen var
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = @nTotalLoc   -- TOTALLOC
         SET @cOutField03 = @nPickedLoc   -- PICKEDLOC
         SET @cOutField04 = CASE WHEN @cGetSuggestedLOCSP = '1' THEN @cSuggestedLoc ELSE '' END
         SET @cOutField05 = ''   -- LOC
         SET @cLoc = ''

         -- Go to next screen
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4
         
         GOTO Quit
      END

      -- No more LOC
      IF @cNewSuggestedLoc = ''
      BEGIN
         IF @cPickAndSwapLOTAutoScanOut = '1'
         BEGIN
            -- Auto scan out pickslip if fully picked
            IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
               AND Status IN ('0', '4')) -- <= '4')
            BEGIN
               BEGIN TRAN

               UPDATE dbo.PickingInfo WITH (ROWLOCK) SET
                  ScanOutDate = GetDate()
               WHERE PickSlipNo = @cPickSlipNo

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 66055
                  SET @cErrMsg = rdt.rdtgetmessage(66055, @cLangCode, 'DSP') --PSScanOut Fail
                  GOTO Step_1_Fail
               END

               COMMIT TRAN
            END
         END

         -- Prepare next screen var
         SET @cOutField01 = ''

         -- Go to PickSlilpNo screen
         SET @nScn = @nScn - 5
         SET @nStep = @nStep - 5
      END
   END
END
GOTO Quit

/********************************************************************************
Step 7. Scn = 1916. Message
   Remaining, task not completed
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey IN (0, 1)
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = ''

      -- Go to next screen
      SET @nScn = @nScn - 6
      SET @nStep = @nStep - 6
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
      Printer   = @cPrinter,
      -- UserName  = @cUserName,

      V_UOM = @cPUOM,
      V_LOC = @cLOC,
      V_ID  = @cID,
      V_LOT = @cLOT,
      V_QTY = @nQTY,
      V_SKU = @cSKU,
      V_SKUDescr = @cDescr,
      V_PickSlipNo = @cPickSlipNo,

      V_Integer1 = @nTotalLoc,
      V_Integer2 = @nPickedLoc,
      V_Integer3 = @nBalQTY,
      
      V_String3 = @cSuggestedLoc,
      V_String4 = @cSuggestedSKU,
      V_String5 = @cMUOM_Desc,
      V_String6 = @cPUOM_Desc,
      V_String11 = @cPickAndSwapLOT,
      V_String12 = @cLogicalLocation,
      V_String13 = @cPickAndSwapLOTAutoScanOut,
      V_String14 = @cDropID, 
      V_String15 = @cExtendedUpdateSP, 
      V_String16 = @cExtendedValidateSP,
      V_String17 = @cGetSuggestedLOCSP, 
      V_String18 = @cDefaultIDQTY, 
      
      V_PUOM_Div = @nPUOM_Div,
      V_MQTY     = @nMQTY,
      V_PQTY     = @nPQTY,

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

      FieldAttr01 = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_DynamicPick_PickAndPack                            */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: RDT Dynamic Pick - Pick And Pack                                  */
/*          SOS88235 - Dynamic Pick Pick And Pack                             */
/*                                                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 22-Nov-2007 1.0  James    Created                                          */
/* 02-Sep-2008 1.1  James    Perfomance tuning (james01)                      */
/* 03-Sep-2008 1.2  James    SOS115147 Add PPK (james02)                      */
/* 18-Sep-2008 1.3  Shong    Performance Tuning                               */
/* 10-Oct-2008 1.4  James    Bug fix (james03)                                */
/* 15-Oct-2008 1.5  James    Check if the labelno scanned is unique           */
/*                           within same storer (james04)                     */
/* 15-Oct-2008 1.6  James    Reserve the carton no to prevent other           */
/*                           to get the same carton no (james05)              */
/* 28-Oct-2008 1.7  James    Retrieve the existing cartonno if user           */
/*                           scan the existing labelno (james06)              */
/* 2008-11-10  1.8  James    Add in Event Log (james07)                       */
/* 2009-02-04  1.9  Leong    SOS127262 - Retrieve qty from PickDetail         */
/*                           for sub SP: rdt_EventLogDetail                   */
/* 03-Mar-2009 2.0  James    Modified by Shong to prevent multiple            */
/*                           labels in a carton                               */
/* 14-Aug-2009 2.1  James    SOS144951 - Bug fix for EventLogDetail.Qty       */
/* 26-Aug-2009 2.2  Vicky    Replace current EventLog with Standard           */
/*                           EventLog (Vicky06)                               */
/* 11-Nov-2011 2.3  Ung      SOS230234. Check for reuse labelno               */
/*                           Scan pick slip cursor jump to empty field        */
/*                           Delete locking records after exit                */
/*                           Create PackHeader if not exist                   */
/*                           Disable QTY field                                */
/*                           Set DynamicPickDefaultLabelLength optional       */
/*                           Change status from 4 to 3                        */
/*                           Decode labelno                                   */
/*                           Implement DynamicPickPrePrintedLabelNo           */
/*                           Revise event log                                 */
/* 07-fEB-2012 2.4  James    Enable UCC scanning (james01)                    */
/* 02-Apr-2012 2.5  ChewKP   SOS#239881 - Prevent Picking when Replen         */
/*                           Not Done (ChewKP01)                              */
/* 19-Apr-2013 2.6  Ung      SOS276057                                        */
/*                           Add PickSlipNo6                                  */
/*                           Add ExtendedUpdateSP                             */
/*                           Add DynamicPickDisableQTYField                   */
/*                           Add DynamicPickDefaultQTY                        */
/*                           Allow zero QTY for short                         */
/* 17-Jul-2013 2.7  Ung      SOS283844 Add PickSlipNo7-9                      */
/* 08-Nov-2013 2.8  Shong    Performance Tuning                               */
/* 23-Dec-2013 2.9  Ung      Fix system resuggest PSNO lock by LOC range      */
/*                           Fix blank PackDetail line if NO QTY to pick      */
/*                           Fix same cartonno different labelno              */
/* 20-Jan-2014 3.0  Ung      SOS294417 New carton                             */
/* 18-Jan-2016 3.1  Ung      Performance Tuning                               */
/* 26-Jul-2016 3.2  Ung      SOS375224                                        */
/*                           Add LoadKey, pick zone                           */
/*                           Add support of standard pick slip                */
/*                           Add DynamicPickPickZone, pick zone optional      */
/*                           Add short pick 99 with DisableQTYField           */
/*                           Remove putaway zone                              */
/*                           Remove DynamicPickDefaultLabelLength             */
/* 27-Jul-2017 3.3  Ung      IN00419503 Fix QTY field not disable             */
/* 01-Mar-2018 3.4  James    WMS4107-Add auto match SKU in Doc (james08)      */
/* 07-Jun-2018 3.5  Ung      INC0228346 Standardize GetNextCartonLabel param  */  
/* 28-Aug-2018 3.6  James    WMS6078-Add rdt_decode (james09)                 */
/* 29-Oct-2018 3.7  TungGH   Performance                                      */
/* 15-Jun-2020 3.8  James    WMS-13602 Add Loc.Descr (james10)                */
/* 17-Mar-2021 3.9  LZG      INC1454205 - Extended length from 5 to 8 (ZG01)  */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_DynamicPick_PickAndPack] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT 
) AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @b_Success           INT,
   @nPSCnt              INT,
   @nTotal_PickQTY      INT,
   @cTotal_CBM          NVARCHAR(20),
   @cLabelLine          NVARCHAR(5),
   @cOption             NVARCHAR(1), 
   @cSQL                NVARCHAR(MAX),
   @cSQLParam           NVARCHAR(MAX), 
   @nTranCount          INT, 
   @nOtherLocQtyToPick  INT,   -- Qty to pick from next location onwards within the same pickslipno
   @nTotalQtyToPick     INT    -- Qty to pick for all locations within the same pickslipno

-- RDT.RDTMobRec variable
DECLARE
   @nFunc              INT,
   @nScn               INT,
   @nStep              INT,
   @cLangCode          NVARCHAR(3),
   @nInputKey          INT,
   @nMenu              INT,

   @cStorerKey         NVARCHAR(15),
   @cFacility          NVARCHAR(5),
   @cUserName          NVARCHAR(15),
   @cPrinter           NVARCHAR(10),

   @cSKU               NVARCHAR(20),
   @cSKUDescr          NVARCHAR(40),
   @nActQty            INT,   -- Actual Pick QTY
   @cLottable01        NVARCHAR(18),
   @cLottable02        NVARCHAR(18),
   @cLottable03        NVARCHAR(18),
   @dLottable04        DATETIME,
   @cFromLOC           NVARCHAR(10),
   @cPickSlipNo        NVARCHAR(10),
   @cLoadKey           NVARCHAR(10),

   @cWaveKey           NVARCHAR(10), -- wavekey
   @cPickZone          NVARCHAR(10), -- putaway zone
   @cPKSLIP_Cnt        NVARCHAR(5),  -- no. of pickslip
   @cCountry           NVARCHAR(20),
   @cToLOC             NVARCHAR(10),
   @cS_Loc             NVARCHAR(10), -- suggested loc
   @cC_Loc             NVARCHAR(10), -- confirmed loc
   @nCartonNo          INT,
   @cLabelNo           NVARCHAR(20),
   @cT_PickSlipNo1     NVARCHAR(10), -- temp pickslipno
   @cT_PickSlipNo2     NVARCHAR(10), 
   @cT_PickSlipNo3     NVARCHAR(10), 
   @cT_PickSlipNo4     NVARCHAR(10), 
   @cT_PickSlipNo5     NVARCHAR(10), 
   @cT_PickSlipNo6     NVARCHAR(10), 
   @cT_PickSlipNo7     NVARCHAR(10), 
   @cT_PickSlipNo8     NVARCHAR(10), 
   @cT_PickSlipNo9     NVARCHAR(10), 
   @cPrePackIndicator  NVARCHAR(30), -- james02
   @nPackQtyIndicator  INT,      -- james02
   @cSKUValidated      NVARCHAR(2),
   @nTotal_PSNO        INT,
   @nQtyToPick         INT,   -- Qty to pick for same sku in same location
   @cPickSlipType      NVARCHAR(1), 

   @nNewCartonNo       INT, -- james06
   @nPID_QTY           INT, -- SOS144951
   @nPAD_QTY           INT, -- SOS144951
   @nFromScn           INT,
   @cSuggestedSKU       NVARCHAR( 20),

   @cDynamicPickPickZone            NVARCHAR(1),  -- Pick zone required
   @cDynamicPickAutoDefaultDPLoc    NVARCHAR(1),  -- auto default DP loc
   @cDynamicPickPrePrintedLabelNo   NVARCHAR(1),  -- pre-generate label no
   @cDynamicPickCartonLabel         NVARCHAR(1),  -- print carton label
   @cDynamicPickCartonManifest      NVARCHAR(1),  -- print carton manifest label
   @cPopulatePickSlipSP             NVARCHAR(20),  -- leave the PSNO blank if turned on
   @cDynamicPickDefaultLBLNoIf1PSNO NVARCHAR(1),  -- default label no if only 1 PSNo
   @cExtendedValidateSP             NVARCHAR(20),
   @cDynamicPickReplenB4Pick        NVARCHAR(1),  -- Replenishment must be done before Pick -- (ChewKP01)
   @cDynamicPickDisableQTYField     NVARCHAR(1),
   @cDynamicPickDefaultQTY          NVARCHAR(1),
   @cDecodeLabelNo                  NVARCHAR(20),
   @cExtendedUpdateSP               NVARCHAR(20),
   @cMultiSKUBarcode                NVARCHAR(1),
   @cDecodeSP                       NVARCHAR( 20), 
   @cBarcode                        NVARCHAR( 60), 
   @cLocDescr                       NVARCHAR( 20), -- (james10)
   @cLocShowDescr                   NVARCHAR( 1),  -- (james10)

   @cInField01 NVARCHAR(60),   @cOutField01 NVARCHAR(60),   @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR(60),   @cOutField02 NVARCHAR(60),   @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR(60),   @cOutField03 NVARCHAR(60),   @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR(60),   @cOutField04 NVARCHAR(60),   @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR(60),   @cOutField05 NVARCHAR(60),   @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR(60),   @cOutField06 NVARCHAR(60),   @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR(60),   @cOutField07 NVARCHAR(60),   @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR(60),   @cOutField08 NVARCHAR(60),   @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR(60),   @cOutField09 NVARCHAR(60),   @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR(60),   @cOutField10 NVARCHAR(60),   @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR(60),   @cOutField11 NVARCHAR(60),   @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR(60),   @cOutField12 NVARCHAR(60),   @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR(60),   @cOutField13 NVARCHAR(60),   @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR(60),   @cOutField14 NVARCHAR(60),   @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR(60),   @cOutField15 NVARCHAR(60),   @cFieldAttr15 NVARCHAR( 1)
   
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
   @cPrinter    = Printer,

   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,
   @cLottable01 = V_Lottable01,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   @cFromLOC    = V_LOC,
   @cPickSlipNo = V_PickSlipNo,
   @cLoadKey    = V_LoadKey, 

   @cWaveKey       = V_String1,
   @cPickZone      = V_String2,
   @cPKSlip_Cnt    = V_String3,
   @cCountry       = V_String4,
   @cToLOC         = V_String5,
   @cS_Loc         = V_String6,
   @cC_Loc         = V_String7,
   @cLocShowDescr  = V_String8,
   @cLabelNo       = V_String9,
   @cT_PickSlipNo1 = V_String10,
   @cT_PickSlipNo2 = V_String11,
   @cT_PickSlipNo3 = V_String12,
   @cT_PickSlipNo4 = V_String13,
   @cT_PickSlipNo5 = V_String14,
   @cT_PickSlipNo6 = V_String15,
   @cT_PickSlipNo7 = V_String16,
   @cT_PickSlipNo8 = V_String17,
   @cT_PickSlipNo9 = V_String18,

   @cPrePackIndicator  = V_String19,
   @cSKUValidated       = V_String21,
   @cSuggestedSKU      = V_String24, 
   @cDecodeSP          = V_String25,   
   @cPickSlipType      = V_String26, 
   
   @nActQty            = V_QTY,
   @nCartonNo          = V_Cartonno,
   @nFromScn           = V_FromScn,

   @cDynamicPickPickZone            = V_String28, 
   @cDynamicPickDefaultQTY          = V_String29,
   @cDynamicPickAutoDefaultDPLoc    = V_String30,
   @cDynamicPickCartonLabel         = V_String31,
   @cDynamicPickCartonManifest      = V_String32,
   @cPopulatePickSlipSP             = V_String33,
   @cDynamicPickDefaultLBLNoIf1PSNO = V_String34,
   @cExtendedValidateSP             = V_String35,
   @cDynamicPickPrePrintedLabelNo   = V_String36,
   @cDynamicPickReplenB4Pick        = V_String37, -- (ChewKP01)
   @cDynamicPickDisableQTYField     = V_String38,
   @cDecodeLabelNo                  = V_String39,
   @cExtendedUpdateSP               = V_String40,
   @cMultiSKUBarcode                = V_String43,
   
   @nPackQtyIndicator               = V_Integer1,
   @nTotal_PSNO                     = V_Integer2,
   @nQtyToPick                      = V_Integer3,
   @nOtherLocQtyToPick              = V_Integer4,
   @nTotalQtyToPick                 = V_Integer5,

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

FROM RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 950 -- Dynamic Pick & Pack
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 950
   IF @nStep = 1 GOTO Step_1   -- Scn = 1640. WAVEKEY
   IF @nStep = 2 GOTO Step_2   -- Scn = 1641. PKSLIPNO
   IF @nStep = 3 GOTO Step_3   -- Scn = 1642. TOTAL QTY, TOTAL CBM
   IF @nStep = 4 GOTO Step_4   -- Scn = 1643. LOC
   IF @nStep = 5 GOTO Step_5   -- Scn = 1644. SKU                                                 
   IF @nStep = 6 GOTO Step_6   -- Scn = 1645. LABEL NO                                                 
   IF @nStep = 7 GOTO Step_7   -- Scn = 1646. OPTION                                                 
   IF @nStep = 8 GOTO Step_8   -- Scn = 1647. Confirm Short Pick                                                 
   IF @nStep = 9 GOTO Step_9   -- Scn = 3570. Multi SKU Barocde
END                                              
                                                 
RETURN -- Do nothing if incorrect step           
                                                 
/********************************************************************************
Step 0. Called from menu (func = 515)            
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1640
   SET @nStep = 1

   -- Init var
   SET @cWaveKey = ''
   SET @cLoadKey = ''
   SET @cPickZone = ''
   SET @cPKSlip_Cnt = ''
   SET @cCountry = ''

   SET @cPickSlipNo = ''
   SET @cT_PickSlipNo1 = ''
   SET @cT_PickSlipNo2 = ''
   SET @cT_PickSlipNo3 = ''
   SET @cT_PickSlipNo4 = ''
   SET @cT_PickSlipNo5 = ''
   SET @cT_PickSlipNo6 = ''
   SET @cT_PickSlipNo7 = ''
   SET @cT_PickSlipNo8 = ''
   SET @cT_PickSlipNo9 = ''

   SET @cSKU = ''
   SET @cSKUDescr = ''
   SET @cLottable01 = ''
   SET @cLottable02 = ''
   SET @cLottable03 = ''
   SET @dLottable04 = 0

   -- Get StorerConfig
   SET @cDynamicPickPickZone = rdt.RDTGetConfig( @nFunc, 'DynamicPickPickZone', @cStorerKey)
   SET @cDynamicPickAutoDefaultDPLoc = rdt.RDTGetConfig( @nFunc, 'DynamicPickAutoDefaultDPLoc', @cStorerKey)
   SET @cDynamicPickPrePrintedLabelNo = rdt.RDTGetConfig( @nFunc, 'DynamicPickPrePrintedLabelNo', @cStorerKey)
   SET @cDynamicPickCartonLabel = rdt.RDTGetConfig( @nFunc, 'DynamicPickCartonLabel', @cStorerKey)
   SET @cDynamicPickCartonManifest = rdt.RDTGetConfig( @nFunc, 'DynamicPickCartonManifest', @cStorerKey)
   SET @cDynamicPickDefaultLBLNoIf1PSNO = rdt.RDTGetConfig( @nFunc, 'DynamicPickDefaultLBLNoIf1PSNO', @cStorerKey)
   SET @cDynamicPickReplenB4Pick = rdt.RDTGetConfig( @nFunc, 'DynamicPickReplenB4Pick', @cStorerKey) -- (ChewKP01)
   SET @cDynamicPickDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DynamicPickDisableQTYField', @cStorerKey)
   SET @cDynamicPickDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DynamicPickDefaultQTY', @cStorerKey)
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cPopulatePickSlipSP = rdt.RDTGetConfig( @nFunc, 'PopulatePickSlipSP', @cStorerKey)
   IF @cPopulatePickSlipSP = '0'
      SET @cPopulatePickSlipSP = ''

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)

   -- (james09)
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   -- (james10)
   SET @cLocShowDescr = rdt.RDTGetConfig( @nFunc, 'LocShowDescr', @cStorerkey)
   
   -- Prep next screen var
   SET @cOutField01 = ''   -- wavekey
   SET @cOutField02 = ''   -- putaway zone
   SET @cOutField03 = ''   -- no. of pickslip to pick
   SET @cOutField04 = ''   -- country
   SET @cOutField05 = ''   -- from loc
   SET @cOutField06 = ''   -- to loc
   SET @cOutField07 = ''   -- LoadKey

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @cRefNo1     = 'Pick And Pack',
      @nStep       = @nStep
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 1640
   WAVEKEY        (field01, input)
   LOADKEY        (field07, input)
   PWAYZONE       (field02, input)
   NO OF PICKSLIP (field03, input)
   COUNTRY        (field04, input)
   FROM LOC       (field05, input)
   TO LOC         (field06, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWaveKey    = @cInField01
      SET @cLoadKey    = @cInField07
      SET @cPickZone   = @cInField02
      SET @cPKSlip_Cnt = @cInField03
      SET @cCountry    = @cInField04
      SET @cFromLOC    = @cInField05
      SET @cToLOC      = @cInField06

      -- Check both Wave and Load
      IF @cWaveKey <> '' AND @cLoadKey <> ''
      BEGIN
         SET @nErrNo = 64455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wave or Load
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      -- Validate blank
      IF @cWaveKey = '' AND @cLoadKey = ''
      BEGIN
         SET @nErrNo = 64401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Wave/Load
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Wave
      IF @cWaveKey <> ''
      BEGIN
         -- Check wave valid
         IF NOT EXISTS (SELECT 1 FROM dbo.WaveDetail WITH (NOLOCK) WHERE WaveKey = @cWaveKey)
         BEGIN
            SET @cWaveKey = ''
            SET @nErrNo = 64402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad WAVEKEY
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
         
         -- Check replen before pick
         IF @cDynamicPickReplenB4Pick = '1'
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK) WHERE WaveKey = @cWaveKey AND Confirmed = 'N')
            BEGIN
               SET @cWaveKey = ''
               SET @nErrNo = 64451
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReplenNotDone
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_1_Fail
            END
         END
      END
      
      -- Load
      IF @cLoadKey <> ''
      BEGIN
         -- Check Load valid
         IF NOT EXISTS( SELECT 1 FROM LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
         BEGIN
            SET @cLoadKey = ''
            SET @nErrNo = 64456
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- LoadKey
            SET @cOutField07 = ''
            GOTO Step_1_Fail
         END
      END

      IF @cPickZone = '' AND @cDynamicPickPickZone = '1'
      BEGIN
         SET @cPickZone = ''
         SET @nErrNo = 64403
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickZone
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail
      END

      -- Check pick zone valid
      IF @cPickZone <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND PickZone = @cPickZone)
         BEGIN
            SET @cPickZone = ''
            SET @nErrNo = 64404
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad PickZone
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END
      END
            
      -- Check if No. of pickslip is blank
      IF @cPKSlip_Cnt = ''
      BEGIN
         SET @cPKSlip_Cnt = ''
         SET @nErrNo = 64405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickSlip
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_1_Fail
      END

      -- Validate whether order to pick is valid (not alphanumeric, not -ve, not decimal, not 0)
      IF RDT.rdtIsValidQTY( @cPKSlip_Cnt, 1) = 0
      BEGIN
         SET @cPKSlip_Cnt = ''
         SET @nErrNo = 64406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad PickSlip
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_1_Fail
      END

      -- Validate country (if keyed in)
      IF @cCountry <> ''
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) WHERE Listname = 'CTYCAT' AND Code = @cCountry)
         BEGIN
            SET @cCountry = ''   -- Need to reset coz this is not compulsary field
            SET @nErrNo = 64408
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Country
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Step_1_Fail
         END
      END

      -- Validate FromLOC (cannot have only one loc keyed in)
      IF @cFromLOC = '' AND @cToLOC <> ''
      BEGIN
         SET @cFromLOC = ''   -- Need to reset coz this is not compulsary field
         SET @nErrNo = 64409
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MissingFromLOC
         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Step_1_Fail
      END

      IF @cFromLOC <> ''
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @cFromLOC)
         BEGIN
            SET @cFromLOC = ''   -- Need to reset coz this is not compulsary field
            SET @nErrNo = 64410
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad FromLOC
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Step_1_Fail
         END

         IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @cFromLOC AND Facility = @cFacility)
         BEGIN
            SET @cFromLOC = ''   -- Need to reset coz this is not compulsary field
            SET @nErrNo = 64411
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Step_1_Fail
         END

         IF @cPickZone <> ''
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @cFromLOC AND Facility = @cFacility AND PickZone = @cPickZone)
            BEGIN
               SET @cFromLOC = ''   -- Need to reset coz this is not compulsary field
               SET @nErrNo = 64412
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotIn PickZone
               EXEC rdt.rdtSetFocusField @nMobile, 5
               GOTO Step_1_Fail
            END
         END
      END

      -- Validate ToLOC (cannot have only one loc keyed in)
      IF @cFromLOC <> '' AND @cToLOC = ''
      BEGIN
         SET @cToLOC = ''   -- Need to reset coz this is not compulsary field
         SET @nErrNo = 64413
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Missing ToLOC
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_1_Fail
      END

      IF @cToLOC <> ''
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @cToLOC)
         BEGIN
            SET @cToLOC = ''   -- Need to reset coz this is not compulsary field
            SET @nErrNo = 64414
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad TO LOC
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Step_1_Fail
         END

         IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @cToLOC AND Facility = @cFacility)
         BEGIN
            SET @cToLOC = ''   -- Need to reset coz this is not compulsary field
            SET @nErrNo = 64415
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Step_1_Fail
         END

         IF @cPickZone <> ''
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @cToLOC AND Facility = @cFacility AND PickZone = @cPickZone)
            BEGIN
               SET @cToLOC = ''   -- Need to reset coz this is not compulsary field
               SET @nErrNo = 64416
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotIn PickZone
               EXEC rdt.rdtSetFocusField @nMobile, 6
               GOTO Step_1_Fail
            END
         END
      END

      -- Reset pick slip
      SET @cT_PickSlipNo1 = ''
      SET @cT_PickSlipNo2 = ''
      SET @cT_PickSlipNo3 = ''
      SET @cT_PickSlipNo4 = ''
      SET @cT_PickSlipNo5 = ''
      SET @cT_PickSlipNo6 = ''
      SET @cT_PickSlipNo7 = ''
      SET @cT_PickSlipNo8 = ''
      SET @cT_PickSlipNo9 = ''
      SET @cPickSlipType = ''
      
      -- Populate pick slip
      IF @cPopulatePickSlipSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPopulatePickSlipSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cPopulatePickSlipSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cWaveKey, @cLoadKey, @cPickZone, @cPKSLIP_Cnt, @cCountry, @cFromLOC, @cToLOC, ' + 
               ' @cPickSlipNo1 OUTPUT, @cPickSlipNo2 OUTPUT, @cPickSlipNo3 OUTPUT, @cPickSlipNo4 OUTPUT, @cPickSlipNo5 OUTPUT, ' +
               ' @cPickSlipNo6 OUTPUT, @cPickSlipNo7 OUTPUT, @cPickSlipNo8 OUTPUT, @cPickSlipNo9 OUTPUT, @cPickSlipType  OUTPUT, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile       INT,                  ' + 
               ' @nFunc         INT,                  ' + 
               ' @cLangCode     NVARCHAR( 3),         ' + 
               ' @nStep         INT,                  ' + 
               ' @nInputKey     INT,                  ' + 
               ' @cFacility     NVARCHAR( 5),         ' + 
               ' @cStorerKey    NVARCHAR( 15),        ' + 
            	' @cWaveKey      NVARCHAR( 10),        ' + 
            	' @cLoadKey      NVARCHAR( 10),        ' + 
               ' @cPickZone     NVARCHAR( 10),        ' + 
               ' @cPKSlip_Cnt   NVARCHAR( 1),         ' + 
               ' @cCountry      NVARCHAR( 20),        ' + 
               ' @cFromLoc      NVARCHAR( 10),        ' + 
               ' @cToLoc        NVARCHAR( 10),        ' + 
               ' @cPickSlipNo1  NVARCHAR( 10) OUTPUT, ' + 
               ' @cPickSlipNo2  NVARCHAR( 10) OUTPUT, ' + 
               ' @cPickSlipNo3  NVARCHAR( 10) OUTPUT, ' + 
               ' @cPickSlipNo4  NVARCHAR( 10) OUTPUT, ' + 
               ' @cPickSlipNo5  NVARCHAR( 10) OUTPUT, ' + 
               ' @cPickSlipNo6  NVARCHAR( 10) OUTPUT, ' + 
               ' @cPickSlipNo7  NVARCHAR( 10) OUTPUT, ' + 
               ' @cPickSlipNo8  NVARCHAR( 10) OUTPUT, ' + 
               ' @cPickSlipNo9  NVARCHAR( 10) OUTPUT, ' + 
               ' @cPickSlipType NVARCHAR( 1)  OUTPUT, ' + 
               ' @nErrNo        INT           OUTPUT, ' + 
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  ' 
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cWaveKey, @cLoadKey, @cPickZone, @cPKSLIP_Cnt, @cCountry, @cFromLOC, @cToLOC, 
               @cT_PickSlipNo1 OUTPUT, @cT_PickSlipNo2 OUTPUT, @cT_PickSlipNo3 OUTPUT, @cT_PickSlipNo4 OUTPUT, @cT_PickSlipNo5 OUTPUT, 
               @cT_PickSlipNo6 OUTPUT, @cT_PickSlipNo7 OUTPUT, @cT_PickSlipNo8 OUTPUT, @cT_PickSlipNo9 OUTPUT, @cPickSlipType  OUTPUT, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT 
         END
      END

      -- Prep next screen variable
      SET @cOutField01 = @cT_PickSlipNo1
      SET @cOutField02 = @cT_PickSlipNo2
      SET @cOutField03 = @cT_PickSlipNo3
      SET @cOutField04 = @cT_PickSlipNo4
      SET @cOutField05 = @cT_PickSlipNo5
      SET @cOutField06 = @cT_PickSlipNo6
      SET @cOutField07 = @cT_PickSlipNo7
      SET @cOutField08 = @cT_PickSlipNo8
      SET @cOutField09 = @cT_PickSlipNo9

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @cRefNo1     = 'Pick And Pack',
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = CASE WHEN @cWaveKey    <> '' THEN @cWaveKey    ELSE '' END   -- wavekey
      SET @cOutField07 = CASE WHEN @cLoadKey    <> '' THEN @cLoadKey    ELSE '' END   -- Loadkey
      SET @cOutField02 = CASE WHEN @cPickZone   <> '' THEN @cPickZone   ELSE '' END   -- pick zone
      SET @cOutField03 = CASE WHEN @cPKSlip_Cnt <> '' THEN @cPKSlip_Cnt ELSE '' END   -- no. of orders to pick
      SET @cOutField04 = CASE WHEN @cCountry    <> '' THEN @cCountry    ELSE '' END   -- country
      SET @cOutField05 = CASE WHEN @cFromLOC    <> '' THEN @cFromLOC    ELSE '' END   -- FromLoc
      SET @cOutField06 = CASE WHEN @cToLOC      <> '' THEN @cToLOC      ELSE '' END   -- ToLoc
   END
END
GOTO Quit

/********************************************************************************
Step 2. Screen = 1641
   PKSLIPNO1 (field01, input)
   PKSLIPNO2 (field02, input)
   PKSLIPNO3 (field03, input)
   PKSLIPNO4 (field04, input)
   PKSLIPNO5 (field05, input)
   PKSLIPNO6 (field06, input)
   PKSLIPNO7 (field07, input)
   PKSLIPNO8 (field08, input)
   PKSLIPNO9 (field09, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Retain key-in value
      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02
      SET @cOutField03 = @cInField03
      SET @cOutField04 = @cInField04
      SET @cOutField05 = @cInField05
      SET @cOutField06 = @cInField06
      SET @cOutField07 = @cInField07
      SET @cOutField08 = @cInField08
      SET @cOutField09 = @cInField09

      -- Validate blank
      IF @cInField01 = '' AND
         @cInField02 = '' AND
         @cInField03 = '' AND
         @cInField04 = '' AND
         @cInField05 = '' AND
         @cInField06 = '' AND
         @cInField07 = '' AND
         @cInField08 = '' AND
         @cInField09 = ''
      BEGIN
         SET @nErrNo = 64417
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PSLIPNO needed'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Put all PickSlipNo into temp table
      DECLARE @tTempPSlip TABLE (PickSlipNo NVARCHAR( 10), NoOfPSlip INT)
      INSERT INTO @tTempPSlip (PickSlipNo, NoOfPSlip) VALUES (@cInField01, 1)
      INSERT INTO @tTempPSlip (PickSlipNo, NoOfPSlip) VALUES (@cInField02, 2)
      INSERT INTO @tTempPSlip (PickSlipNo, NoOfPSlip) VALUES (@cInField03, 3)
      INSERT INTO @tTempPSlip (PickSlipNo, NoOfPSlip) VALUES (@cInField04, 4)
      INSERT INTO @tTempPSlip (PickSlipNo, NoOfPSlip) VALUES (@cInField05, 5)
      INSERT INTO @tTempPSlip (PickSlipNo, NoOfPSlip) VALUES (@cInField06, 6)
      INSERT INTO @tTempPSlip (PickSlipNo, NoOfPSlip) VALUES (@cInField07, 7)
      INSERT INTO @tTempPSlip (PickSlipNo, NoOfPSlip) VALUES (@cInField08, 8)
      INSERT INTO @tTempPSlip (PickSlipNo, NoOfPSlip) VALUES (@cInField09, 9)

      -- Validate PickSlipNo scanned more than once
      SELECT @nPSCnt = MAX( NoOfPSlip)
      FROM @tTempPSlip
      WHERE PickSlipNo <> '' AND PickSlipNo IS NOT NULL
      GROUP BY PickSlipNo
      HAVING COUNT( PickSlipNo) > 1

      IF @@ROWCOUNT <> 0
      BEGIN
         SET @nErrNo = 64418
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Dup PSLIPNO'
         EXEC rdt.rdtSetFocusField @nMobile, @nPSCnt
         GOTO Quit
      END

      -- Validate if anything changed
      IF @cT_PickSlipNo1 <> @cInField01 OR
         @cT_PickSlipNo2 <> @cInField02 OR
         @cT_PickSlipNo3 <> @cInField03 OR
         @cT_PickSlipNo4 <> @cInField04 OR
         @cT_PickSlipNo5 <> @cInField05 OR
         @cT_PickSlipNo6 <> @cInField06 OR
         @cT_PickSlipNo7 <> @cInField07 OR
         @cT_PickSlipNo8 <> @cInField08 OR
         @cT_PickSlipNo9 <> @cInField09 

      -- There are changes, remain in current screen
      BEGIN
         DECLARE @cInField NVARCHAR( 20)

         -- Check newly scanned PickSlipNO
         SET @nPSCnt = 1
         WHILE @nPSCnt <= 9
         BEGIN
            IF @nPSCnt = 1 SELECT @cInField = @cInField01, @cPickSlipNo = @cT_PickSlipNo1 ELSE 
            IF @nPSCnt = 2 SELECT @cInField = @cInField02, @cPickSlipNo = @cT_PickSlipNo2 ELSE 
            IF @nPSCnt = 3 SELECT @cInField = @cInField03, @cPickSlipNo = @cT_PickSlipNo3 ELSE 
            IF @nPSCnt = 4 SELECT @cInField = @cInField04, @cPickSlipNo = @cT_PickSlipNo4 ELSE 
            IF @nPSCnt = 5 SELECT @cInField = @cInField05, @cPickSlipNo = @cT_PickSlipNo5 ELSE 
            IF @nPSCnt = 6 SELECT @cInField = @cInField06, @cPickSlipNo = @cT_PickSlipNo6 ELSE 
            IF @nPSCnt = 7 SELECT @cInField = @cInField07, @cPickSlipNo = @cT_PickSlipNo7 ELSE 
            IF @nPSCnt = 8 SELECT @cInField = @cInField08, @cPickSlipNo = @cT_PickSlipNo8 ELSE 
            IF @nPSCnt = 9 SELECT @cInField = @cInField09, @cPickSlipNo = @cT_PickSlipNo9

            -- Value changed
            IF @cInField <> @cPickSlipNo
            BEGIN
               -- Consist a new value
               IF @cInField <> ''
               BEGIN
                  -- Validate PickSlip
                  SET @nErrNo = 0
                  EXECUTE rdt.rdt_DynamicPick_PickAndPack_ValidatePickSlip @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                     @cWaveKey,
                     @cLoadKey, 
                     @cPickZone,
                     @cCountry,
                     @cFromLOC,
                     @cToLOC,
                     @cInField, -- Entered PickSlipNo
                     @cPickSlipType OUTPUT,
                     @nErrNo        OUTPUT,
                     @cErrMsg       OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     -- Error, clear the field
                     IF @nPSCnt = 1 SELECT @cT_PickSlipNo1 = '', @cInField01 = '', @cOutField01 = '' ELSE
                     IF @nPSCnt = 2 SELECT @cT_PickSlipNo2 = '', @cInField02 = '', @cOutField02 = '' ELSE
                     IF @nPSCnt = 3 SELECT @cT_PickSlipNo3 = '', @cInField03 = '', @cOutField03 = '' ELSE
                     IF @nPSCnt = 4 SELECT @cT_PickSlipNo4 = '', @cInField04 = '', @cOutField04 = '' ELSE
                     IF @nPSCnt = 5 SELECT @cT_PickSlipNo5 = '', @cInField05 = '', @cOutField05 = '' ELSE
                     IF @nPSCnt = 6 SELECT @cT_PickSlipNo6 = '', @cInField06 = '', @cOutField06 = '' ELSE
                     IF @nPSCnt = 7 SELECT @cT_PickSlipNo7 = '', @cInField07 = '', @cOutField07 = '' ELSE
                     IF @nPSCnt = 8 SELECT @cT_PickSlipNo8 = '', @cInField08 = '', @cOutField08 = '' ELSE
                     IF @nPSCnt = 9 SELECT @cT_PickSlipNo9 = '', @cInField09 = '', @cOutField09 = ''

                     EXEC rdt.rdtSetFocusField @nMobile, @nPSCnt
                     GOTO Quit
                  END
               END

               -- Save to PickSlipNo variable
               IF @nPSCnt = 1 SET @cT_PickSlipNo1 = @cInField01 ELSE
               IF @nPSCnt = 2 SET @cT_PickSlipNo2 = @cInField02 ELSE
               IF @nPSCnt = 3 SET @cT_PickSlipNo3 = @cInField03 ELSE
               IF @nPSCnt = 4 SET @cT_PickSlipNo4 = @cInField04 ELSE
               IF @nPSCnt = 5 SET @cT_PickSlipNo5 = @cInField05 ELSE
               IF @nPSCnt = 6 SET @cT_PickSlipNo6 = @cInField06 ELSE
               IF @nPSCnt = 7 SET @cT_PickSlipNo7 = @cInField07 ELSE
               IF @nPSCnt = 8 SET @cT_PickSlipNo8 = @cInField08 ELSE
               IF @nPSCnt = 9 SET @cT_PickSlipNo9 = @cInField09
            END
            SET @nPSCnt = @nPSCnt + 1
         END

         -- Position cursor on next empty field
         IF @cInField01 = '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE 
         IF @cInField02 = '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE 
         IF @cInField03 = '' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE 
         IF @cInField04 = '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE 
         IF @cInField05 = '' EXEC rdt.rdtSetFocusField @nMobile, 5 ELSE 
         IF @cInField06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE 
         IF @cInField07 = '' EXEC rdt.rdtSetFocusField @nMobile, 7 ELSE 
         IF @cInField08 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 ELSE 
         IF @cInField09 = '' EXEC rdt.rdtSetFocusField @nMobile, 9

         GOTO Quit
      END -- End of if there are changes

      -- Calculate TotalPickQty and TotalCBM
      SET @nTotal_PickQTY = 0
      SET @cTotal_CBM = ''
      EXECUTE rdt.rdt_DynamicPick_PickAndPack_CalcTotalQTYAndCBM @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cPickZone,
         @cFromLOC,
         @cToLOC,
         @cPickSlipType, 
         @cT_PickSlipNo1,
         @cT_PickSlipNo2,
         @cT_PickSlipNo3,
         @cT_PickSlipNo4,
         @cT_PickSlipNo5,
         @cT_PickSlipNo6,
         @cT_PickSlipNo7,
         @cT_PickSlipNo8,
         @cT_PickSlipNo9,
         @nTotal_PickQTY OUTPUT,
         @cTotal_CBM     OUTPUT

      IF @nTotal_PickQTY = 0
      BEGIN
         SET @nErrNo = 64420
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No QTY to pick'
         EXEC rdt.rdtSetFocusField @nMobile, @nPSCnt
         GOTO Quit
      END

      -- Lock the pickslip
      SET @nPSCnt = 0
      WHILE @nPSCnt <=9
      BEGIN
         SET @nPSCnt = @nPSCnt + 1
         IF @nPSCnt = 1 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo1, '') ELSE
         IF @nPSCnt = 2 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo2, '') ELSE
         IF @nPSCnt = 3 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo3, '') ELSE
         IF @nPSCnt = 4 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo4, '') ELSE
         IF @nPSCnt = 5 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo5, '') ELSE
         IF @nPSCnt = 6 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo6, '') ELSE
         IF @nPSCnt = 7 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo7, '') ELSE
         IF @nPSCnt = 8 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo8, '') ELSE
         IF @nPSCnt = 9 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo9, '')

         IF @cPickSlipNo = '' CONTINUE

         IF NOT EXISTS (SELECT 1 FROM RDT.RDTDynamicPickLog WITH (NOLOCK)
            WHERE PickSlipNo= @cPickSlipNo
               AND AddWho = @cUserName
               AND Zone = @cPickZone
               AND FromLOC = @cFromLOC
               AND ToLOC = @cToLOC)
         BEGIN
            -- Transaction protection is required here, eventhou only single insert statement
            -- ntrRDTDynamicPickLogAdd will not rollback, parent control the rollback
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN
            SAVE TRAN Insert_RDTDynamicPickLog          

            INSERT INTO RDT.RDTDynamicPickLog (PickSlipNo, Zone, FromLOC, ToLOC, Facility, AddWho)
            VALUES (@cPickSlipNo, @cPickZone, @cFromLOC, @cToLOC, @cFacility, @cUserName)
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 64419
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LockPSNoFail'
               ROLLBACK TRAN Insert_RDTDynamicPickLog
            END
            
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN

            IF @nErrNo <> 0
               GOTO Quit
         END

         -- Get next CartonNo, LabelNo
         EXECUTE rdt.rdt_DynamicPick_PickAndPack_GetNextCartonLabel @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cUserName,
            @cPrinter, 
            @cDynamicPickCartonLabel,
            @cDynamicPickPrePrintedLabelNo,
            @cPickSlipNo,
            @cPickZone,
            @cFromLOC,
            @cToLOC,
            @nCartonNo   OUTPUT,
            @cLabelNo    OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
      END

      -- Count how many pickslip keyed in
      SELECT @nTotal_PSNO = COUNT(1) FROM @tTempPSlip WHERE PickSlipNo <> ''

      -- Prep next screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField09 = @cLoadKey
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = @nTotal_PSNO
      SET @cOutField04 = @cCountry

      SELECT @cLocDescr = SUBSTRING( Descr, 1, 20) FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cFromLOC
      IF ISNULL( @cLocDescr, '') = ''
         SET @cLocDescr = @cFromLOC

      SET @cOutField05 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cFromLOC END

      SELECT @cLocDescr = SUBSTRING( Descr, 1, 20) FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cToLOC
      IF ISNULL( @cLocDescr, '') = ''
         SET @cLocDescr = @cToLOC

      SET @cOutField06 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cToLOC END

      SET @cOutField07 = @nTotal_PickQTY   --total qty
      SET @cOutField08 = @cTotal_CBM   --total cbm

      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cOutField01 = ''   -- WaveKey
      SET @cOutField07 = ''   -- LoadKey
      SET @cOutField02 = ''   -- PickZone
      SET @cOutField03 = ''   -- No of PickSlip
      SET @cOutField04 = ''   -- Country
      SET @cOutField05 = ''   -- FromLoc
      SET @cOutField06 = ''   -- ToLoc

      IF @cWaveKey <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- WaveKey
      ELSE 
         EXEC rdt.rdtSetFocusField @nMobile, 7  -- LoadKey
   END
   GOTO Quit

END
GOTO Quit

/********************************************************************************
Step 3. Screen = 1642
   WAVEKEY        (field01)
   LOADKEY        (field09)
   PWAYZONE       (field02)
   NO OF PICKSLIP (field03)
   COUNTRY        (field04)
   FROM LOC       (field05)
   TO LOC         (field06)
   TOTAL QTY      (field07)
   TOTAL CBM      (field08)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @nPSCnt = 0
      WHILE @nPSCnt <= 9
      BEGIN
         SET @nPSCnt = @nPSCnt + 1

         IF @nPSCnt = 1 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo1, '') ELSE 
         IF @nPSCnt = 2 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo2, '') ELSE 
         IF @nPSCnt = 3 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo3, '') ELSE 
         IF @nPSCnt = 4 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo4, '') ELSE 
         IF @nPSCnt = 5 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo5, '') ELSE 
         IF @nPSCnt = 6 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo6, '') ELSE 
         IF @nPSCnt = 7 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo7, '') ELSE 
         IF @nPSCnt = 8 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo8, '') ELSE 
         IF @nPSCnt = 9 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo9, '') 

         -- Loop next
         IF @cPickSlipNo = '' 
            CONTINUE 

         -- Insert PickingInfo, if not exists
         IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN
            SAVE TRAN Start_Picking

            INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)
            VALUES (@cPickSlipNo, GetDate(), @cUserName)
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN Start_Picking
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               
               SET @nErrNo = 64421
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PkInf fail'
               GOTO Quit
            END

            COMMIT TRAN Start_Picking
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
         END
      END

      -- Calculate TotalPickQty and TotalCBM
      SET @nTotal_PickQTY = 0
      SET @cTotal_CBM = ''
      EXECUTE rdt.rdt_DynamicPick_PickAndPack_CalcTotalQTYAndCBM @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cPickZone,
         @cFromLOC,
         @cToLOC,
         @cPickSlipType, 
         @cT_PickSlipNo1,
         @cT_PickSlipNo2,
         @cT_PickSlipNo3,
         @cT_PickSlipNo4,
         @cT_PickSlipNo5,
         @cT_PickSlipNo6,
         @cT_PickSlipNo7,
         @cT_PickSlipNo8,
         @cT_PickSlipNo9,
         @nTotal_PickQTY OUTPUT,
         @cTotal_CBM     OUTPUT

      -- Check if have further pick task
      IF @nTotal_PickQTY > 0
      BEGIN
         -- Print carton label turn on
         IF @cPrinter <> '' AND              -- Login with printer
            @cDynamicPickCartonLabel = '1'   -- Carton label turn on
         BEGIN
            SET @nPSCnt = 1
            WHILE @nPSCnt <= 9
            BEGIN
               IF @nPSCnt = 1 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo1, '') ELSE 
               IF @nPSCnt = 2 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo2, '') ELSE 
               IF @nPSCnt = 3 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo3, '') ELSE 
               IF @nPSCnt = 4 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo4, '') ELSE 
               IF @nPSCnt = 5 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo5, '') ELSE 
               IF @nPSCnt = 6 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo6, '') ELSE 
               IF @nPSCnt = 7 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo7, '') ELSE 
               IF @nPSCnt = 8 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo8, '') ELSE 
               IF @nPSCnt = 9 SET @cPickSlipNo = ISNULL(@cT_PickSlipNo9, '')

               IF @cPickSlipNo <> ''
               BEGIN
                  -- Get carton no, label no
                  SELECT TOP 1
                     @nCartonNo = CartonNo,
                     @cLabelNo  = LabelNo
                  FROM RDT.RDTDynamicPickLog WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                     AND AddWho = @cUserName
                     AND Zone = @cPickZone
                     AND FromLOC = @cFromLOC
                     AND ToLOC = @cToLOC

                  -- Print Carton Label
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_DynamicPick_PickAndPack_PrintJob
                     @cStorerKey, 'PRINTCARTONLBL', 'CARTONLBL', @cPrinter, '0', 5, 1, @nMobile, @cPickSlipNo, @nCartonNo, @nCartonNo, @cLabelNo, @cLabelNo,
                     @cLangCode,
                     @nErrNo       OUTPUT,
                     @cErrMsg      OUTPUT

                  IF @nErrNo <> 0 GOTO Quit
               END

               SET @nPSCnt = @nPSCnt + 1
            END -- While
         END
      END
      ELSE
      BEGIN
         -- No more task
         SET @nErrNo = 64439
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No more TASK'
         GOTO Quit
      END

      -- Get 1st suggested pick LOC
      SET @nErrNo = 0
      SET @cS_Loc = ''
      EXECUTE rdt.rdt_DynamicPick_PickAndPack_GetNextLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cPickZone,
         @cFromLOC,
         @cToLOC,
         @cPickSlipType, 
         @cT_PickSlipNo1,
         @cT_PickSlipNo2,
         @cT_PickSlipNo3,
         @cT_PickSlipNo4,
         @cT_PickSlipNo5,
         @cT_PickSlipNo6,
         @cT_PickSlipNo7,
         @cT_PickSlipNo8,
         @cT_PickSlipNo9,
         '',      -- Current location
         @cS_Loc  OUTPUT,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT

      -- Check if no more pick LOC
      IF @nErrNo <> 0 
         GOTO Quit

      SELECT @cLocDescr = SUBSTRING( Descr, 1, 20) FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cS_Loc
      IF ISNULL( @cLocDescr, '') = ''
         SET @cLocDescr = @cS_Loc
            
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey ' +
               ',@cWaveKey, @cLoadKey, @cPickZone, @cPKSLIP_Cnt, @cCountry, @cFromLOC, @cToLOC ' +
               ',@cT_PickSlipNo1, @cT_PickSlipNo2, @cT_PickSlipNo3, @cT_PickSlipNo4, @cT_PickSlipNo5 ' +
               ',@cT_PickSlipNo6, @cT_PickSlipNo7, @cT_PickSlipNo8, @cT_PickSlipNo9, @cPickSlipNo ' +
               ',@cS_LOC, @cSKU, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
               ',@nQtyToPick, @nActQty, @nCartonNo, @cLabelNo, @cOption, @nErrNo  OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile         INT           ' +  
               ',@nFunc           INT           ' + 
               ',@cLangCode       NVARCHAR( 3)  ' + 
               ',@nStep           INT           ' +
               ',@nInputKey       INT           ' + 
               ',@cFacility       NVARCHAR( 5)  ' +
               ',@cStorerKey      NVARCHAR( 15) ' +
               ',@cWaveKey        NVARCHAR( 10) ' +
               ',@cLoadKey        NVARCHAR( 10) ' +
               ',@cPickZone       NVARCHAR( 10) ' +
               ',@cPKSLIP_Cnt     NVARCHAR( 5)  ' +
               ',@cCountry        NVARCHAR( 20) ' +
               ',@cFromLOC        NVARCHAR( 10) ' +
               ',@cToLOC          NVARCHAR( 10) ' +
               ',@cT_PickSlipNo1  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo2  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo3  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo4  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo5  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo6  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo7  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo8  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo9  NVARCHAR( 10) ' +
               ',@cPickSlipNo     NVARCHAR( 10) ' +
               ',@cS_LOC          NVARCHAR( 10) ' +
               ',@cSKU            NVARCHAR( 20) ' +
               ',@cLottable01     NVARCHAR( 18) ' +
               ',@cLottable02     NVARCHAR( 18) ' +
               ',@cLottable03     NVARCHAR( 18) ' +
               ',@dLottable04     DATETIME      ' +
               ',@nQtyToPick      INT           ' +
               ',@nActQty         INT           ' +
               ',@nCartonNo       INT           ' +
               ',@cLabelNo        NVARCHAR( 20) ' +
               ',@cOption         NVARCHAR( 1)  ' +
               ',@nErrNo          INT OUTPUT    ' +
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey 
               ,@cWaveKey, @cLoadKey, @cPickZone, @cPKSLIP_Cnt, @cCountry, @cFromLOC, @cToLOC 
               ,@cT_PickSlipNo1, @cT_PickSlipNo2, @cT_PickSlipNo3, @cT_PickSlipNo4, @cT_PickSlipNo5
               ,@cT_PickSlipNo6, @cT_PickSlipNo7, @cT_PickSlipNo8, @cT_PickSlipNo9, @cPickSlipNo
               ,@cS_LOC, @cSKU, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@nQtyToPick, @nActQty, @nCartonNo, @cLabelNo, @cOption, @nErrNo  OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cS_Loc END
      SET @cOutField02 = '' -- LOC

      -- Auto default pick LOC
      IF @cDynamicPickAutoDefaultDPLoc = '1'
         SET @cOutField02 = @cS_Loc

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Delete PackDetail for reserving CartonNo, LabelNo
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PickSlipNo, CartonNo, LabelNo
         FROM RDT.RDTDynamicPickLog WITH (NOLOCK)
         WHERE PickSlipNo IN (@cT_PickSlipNo1, @cT_PickSlipNo2, @cT_PickSlipNo3, @cT_PickSlipNo4, @cT_PickSlipNo5, @cT_PickSlipNo6, @cT_PickSlipNo7, @cT_PickSlipNo8, @cT_PickSlipNo9)
            AND AddWho = @cUserName
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickSlipNo, @nCartonNo, @cLabelNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Delete PackDetail
         DELETE FROM dbo.PackDetail
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND SKU = ''
         FETCH NEXT FROM @curPD INTO @cPickSlipNo, @nCartonNo, @cLabelNo
      END

      -- Unlock the pickslip
      DELETE FROM RDT.RDTDynamicPickLog WHERE AddWho = @cUserName

      SET @cT_PickSlipNo1 = ''
      SET @cT_PickSlipNo2 = ''
      SET @cT_PickSlipNo3 = ''
      SET @cT_PickSlipNo4 = ''
      SET @cT_PickSlipNo5 = ''
      SET @cT_PickSlipNo6 = ''
      SET @cT_PickSlipNo7 = ''
      SET @cT_PickSlipNo8 = ''
      SET @cT_PickSlipNo9 = ''
      SET @cPickSlipType = ''
      
      -- Prep previous screen var
      SET @cOutField01    = '' --PickSlipNo1
      SET @cOutField02    = '' --PickSlipNo2
      SET @cOutField03    = '' --PickSlipNo3
      SET @cOutField04    = '' --PickSlipNo4
      SET @cOutField05    = '' --PickSlipNo5
      SET @cOutField06    = '' --PickSlipNo6
      SET @cOutField07    = '' --PickSlipNo7
      SET @cOutField08    = '' --PickSlipNo8
      SET @cOutField09    = '' --PickSlipNo9

      EXEC rdt.rdtSetFocusField @nMobile, 01

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
   SET @cOutField01 = ''
      SET @cOutField02 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 4. Screen 1643
   LOC (Field01)
   LOC (Field02, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cC_Loc = @cInField02  --confirmed
      SET @cC_Loc = ISNULL(@cC_Loc, '')

      -- Validate blank
      IF @cC_Loc <> ''
      BEGIN
         IF @cC_Loc <> @cS_Loc
         BEGIN
        SET @nErrNo = 64422
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Different LOC'
            GOTO Step_4_Fail
         END
      END

      -- Get next loc if ConfirmLoc is blank
      IF @cC_Loc = ''
      BEGIN
         SET @nErrNo = 0
         EXECUTE rdt.rdt_DynamicPick_PickAndPack_GetNextLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPickZone,
            @cFromLOC,
            @cToLOC,
            @cPickSlipType, 
            @cT_PickSlipNo1,
            @cT_PickSlipNo2,
            @cT_PickSlipNo3,
            @cT_PickSlipNo4,
            @cT_PickSlipNo5,
            @cT_PickSlipNo6,
            @cT_PickSlipNo7,
            @cT_PickSlipNo8,
            @cT_PickSlipNo9,
            @cS_Loc,
            @cS_Loc  OUTPUT,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         -- No more loc
         IF @nErrNo <> 0 GOTO Quit

         SELECT @cLocDescr = SUBSTRING( Descr, 1, 20) FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cS_Loc
         IF ISNULL( @cLocDescr, '') = ''
            SET @cLocDescr = @cS_Loc
         
         SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cS_Loc END
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Get next task
      SET @nErrNo = 0
      EXEC rdt.rdt_DynamicPick_PickAndPack_GetNextTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cPickZone,
         @cFromLOC,
         @cToLOC,
         @cC_Loc,
         @cPickSlipType, 
         @cT_PickSlipNo1,
         @cT_PickSlipNo2,
         @cT_PickSlipNo3,
         @cT_PickSlipNo4,
         @cT_PickSlipNo5,
         @cT_PickSlipNo6,
         @cT_PickSlipNo7,
         @cT_PickSlipNo8,
         @cT_PickSlipNo9,
         @cPickSlipNo   OUTPUT,
         @cSKU          OUTPUT,
         @cSKUDescr     OUTPUT,
         @cLottable01   OUTPUT,
         @cLottable02   OUTPUT,
         @cLottable03   OUTPUT,
         @dLottable04   OUTPUT,
         @nQtyToPick    OUTPUT,      -- Qty need to pick for same sku in same location within the same pickslipno
         @nOtherLocQtyToPick OUTPUT, -- Qty to pick from next location onwards within the same pickslipno
         @nTotalQtyToPick    OUTPUT, -- Qty to pick for all locations within the same pickslipno
         'L',                        -- Indicate from LOC screen to SKU screen
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT

      IF @nErrNo <> 0 
         GOTO Step_4_Fail

      -- Get SKU info
      SELECT @cPrePackIndicator = PrePackIndicator,
             @nPackQtyIndicator = PackQtyIndicator
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
        AND SKU = @cSKU

      SET @nActQty = 0
      SET @cSKUValidated = '0'

      -- Disable QTY field
      IF @cDynamicPickDisableQTYField = '1'
         SET @cFieldAttr10 = 'O'

      -- Prep next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING(@cSKUDescr, 21, 20)
      SET @cOutField05 = @cLottable01
      SET @cOutField06 = @cLottable02
      SET @cOutField07 = @cLottable03
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField09 = @nQtyToPick
      SET @cOutField10 = CASE WHEN @cDynamicPickDisableQTYField = '1' THEN '0' ELSE '' END -- QTY
      SET @cOutField11 = ''  -- SKU
      SET @cOutField12 = RTRIM(CAST( ISNULL(@nOtherLocQtyToPick, 0) AS NVARCHAR( 8))) + '/' + CAST( ISNULL(@nTotalQtyToPick, 0) AS NVARCHAR( 8))   -- ZG01
      SET @cOutField13 = CASE WHEN @cPrePackIndicator = '2' THEN ISNULL(@nPackQtyIndicator, '0') ELSE '' END

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 11 -- SKU
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cS_Loc = ''

      -- Calculate TotalPickQty and TotalCBM
      SET @nTotal_PickQTY = 0
      SET @cTotal_CBM = ''
      EXECUTE rdt.rdt_DynamicPick_PickAndPack_CalcTotalQTYAndCBM @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cPickZone,
         @cFromLOC,
         @cToLOC,
         @cPickSlipType, 
         @cT_PickSlipNo1,
         @cT_PickSlipNo2,
         @cT_PickSlipNo3,
         @cT_PickSlipNo4,
         @cT_PickSlipNo5,
         @cT_PickSlipNo6,
         @cT_PickSlipNo7,
         @cT_PickSlipNo8,
         @cT_PickSlipNo9,
         @nTotal_PickQTY OUTPUT,
         @cTotal_CBM     OUTPUT

      SET @cOutField01 = @cWaveKey
      SET @cOutField09 = @cLoadKey
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = @nTotal_PSNO
      SET @cOutField04 = @cCountry

      SELECT @cLocDescr = SUBSTRING( Descr, 1, 20) FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cFromLOC
      IF ISNULL( @cLocDescr, '') = ''
         SET @cLocDescr = @cFromLOC

      SET @cOutField05 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cFromLOC END

      SELECT @cLocDescr = SUBSTRING( Descr, 1, 20) FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cToLOC
      IF ISNULL( @cLocDescr, '') = ''
         SET @cLocDescr = @cToLOC
         
      SET @cOutField06 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cToLOC END
      SET @cOutField07 = @nTotal_PickQTY --total qty
      SET @cOutField08 = @cTotal_CBM     --total cbm

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SELECT @cLocDescr = SUBSTRING( Descr, 1, 20) FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cS_Loc
      IF ISNULL( @cLocDescr, '') = ''
         SET @cLocDescr = @cS_Loc

      SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cS_Loc END -- Suggested Loc
      SET @cOutField02 = ''      -- Confirmed Loc
   END
END
GOTO Quit

/********************************************************************************
Step 5. Screen 1644
   PKSLIPNO  (Field01)
   SKU       (Field02)
   SKU Desc1 (Field03)
   SKU Desc2 (Field04)
   PPK       (Field12)
   Lottable1 (Field05)
   Lottable2 (Field06)
   Lottable3 (Field07)
   Lottable4 (Field08)
   PICKQTY   (Field09)
   ACT QTY   (Field10, input)
   SKU/UPC   (Field11, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      DECLARE @cActSKU NVARCHAR(20) -- Act Pick SKU
      DECLARE @cActQty NVARCHAR(5)  -- Actual Pick QTY

      DECLARE @cUCCNo NVARCHAR(20)
      DECLARE @cUCCSKU NVARCHAR(20)
      DECLARE @nUCCQTY INT

      -- Screen mapping
      SET @cActSKU = @cInField11
      SET @cActQTY = CASE WHEN @cFieldAttr10 = 'O' THEN @cOutField10 ELSE @cInField10 END
      SET @cBarcode = @cInField11

      -- Check SKU blank
      IF @cActSKU = '' AND @cSKUValidated = '0' -- False
      BEGIN
         SET @nErrNo = 64430
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Scan SKU/UPC
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- SKU
         GOTO Quit
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         DECLARE @cDecodeSKU  NVARCHAR( 20)
         DECLARE @nDecodeQTY  INT

         SET @cDecodeSKU = @cActSKU
         SET @nDecodeQTY = CAST( @cActQTY AS INT)

         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cUPC    = @cDecodeSKU        OUTPUT, 
               @nQTY    = @nDecodeQTY        OUTPUT, 
               @cLottable01  = @cLottable01  OUTPUT,
               @cLottable02  = @cLottable02  OUTPUT,
               @cLottable03  = @cLottable03  OUTPUT,
               @dLottable04  = @dLottable04  OUTPUT,
               @nErrNo  = @nErrNo  OUTPUT, 
               @cErrMsg = @cErrMsg OUTPUT,
               @cType = 'UPC'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile,          @nFunc,           @cLangCode,       @nStep,           @nInputKey,    @cStorerKey,   @cBarcode, ' +
               ' @cWaveKey,         @cLoadKey,        @cPickZone,       @cPKSLIP_Cnt,     @cCountry,     @cFromLOC,     @cToLOC, ' +
               ' @cT_PickSlipNo1,   @cT_PickSlipNo2,  @cT_PickSlipNo3,  @cT_PickSlipNo4,  @cT_PickSlipNo5, ' +
               ' @cT_PickSlipNo6,   @cT_PickSlipNo7,  @cT_PickSlipNo8,  @cT_PickSlipNo9,  @cPickSlipNo, ' +
               ' @cS_LOC,           @nQtyToPick,      @nCartonNo,       @cLabelNo,        @cOption, ' + 
               ' @cSKU    OUTPUT,   @nQty    OUTPUT,  @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, ' +
               ' @nErrNo  OUTPUT,   @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile           INT,             ' +
               ' @nFunc             INT,             ' +
               ' @cLangCode         NVARCHAR( 3),    ' +
               ' @nStep             INT,             ' +
               ' @nInputKey         INT,             ' +
               ' @cStorerKey        NVARCHAR( 15),   ' +
               ' @cBarcode          NVARCHAR( 60), ' +
               ' @cWaveKey          NVARCHAR( 10),   ' +
               ' @cLoadKey          NVARCHAR( 10),   ' +
               ' @cPickZone         NVARCHAR( 10),   ' +
               ' @cPKSLIP_Cnt       NVARCHAR( 5),    ' +
               ' @cCountry          NVARCHAR( 20),   ' +
               ' @cFromLOC          NVARCHAR( 10),   ' +
               ' @cToLOC            NVARCHAR( 10),   ' +
               ' @cT_PickSlipNo1    NVARCHAR( 10), ' +
               ' @cT_PickSlipNo2    NVARCHAR( 10), ' +
               ' @cT_PickSlipNo3    NVARCHAR( 10), ' +
               ' @cT_PickSlipNo4    NVARCHAR( 10), ' +
               ' @cT_PickSlipNo5    NVARCHAR( 10), ' +
               ' @cT_PickSlipNo6    NVARCHAR( 10), ' +
               ' @cT_PickSlipNo7    NVARCHAR( 10), ' +
               ' @cT_PickSlipNo8    NVARCHAR( 10), ' +
               ' @cT_PickSlipNo9    NVARCHAR( 10), ' +
               ' @cPickSlipNo       NVARCHAR( 10), ' +
               ' @cS_LOC            NVARCHAR( 10), ' +
               ' @nQtyToPick        INT,           ' +
               ' @nCartonNo         INT,           ' +
               ' @cLabelNo          NVARCHAR( 20), ' +
               ' @cOption           NVARCHAR( 1),  ' +
               ' @cSKU              NVARCHAR( 20)  OUTPUT, ' +
               ' @nQty              INT            OUTPUT, ' +
               ' @cLottable01       NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02       NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03       NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04       DATETIME       OUTPUT, ' +
               ' @nErrNo            INT            OUTPUT, ' +
               ' @cErrMsg           NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile,          @nFunc,           @cLangCode,       @nStep,           @nInputKey,    @cStorerKey,   @cBarcode, 
               @cWaveKey,         @cLoadKey,        @cPickZone,       @cPKSLIP_Cnt,     @cCountry,     @cFromLOC,     @cToLOC, 
               @cT_PickSlipNo1,   @cT_PickSlipNo2,  @cT_PickSlipNo3,  @cT_PickSlipNo4,  @cT_PickSlipNo5, 
               @cT_PickSlipNo6,   @cT_PickSlipNo7,  @cT_PickSlipNo8,  @cT_PickSlipNo9,  @cPickSlipNo, 
               @cS_LOC,           @nQtyToPick,      @nCartonNo,       @cLabelNo,        @cOption, 
               @cDecodeSKU OUTPUT,@nDecodeQTY OUTPUT,  @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, 
               @nErrNo     OUTPUT,@cErrMsg    OUTPUT

         END

         IF @nErrNo <> 0
            GOTO Quit
         ELSE
         BEGIN
            SET @cActSKU = @cDecodeSKU

            IF ISNULL( @nDecodeQTY, 0) <> 0
               SET @cActQTY = CAST( @nDecodeQTY AS NVARCHAR( 8))  -- ZG01
         END
      END

      SET @cUCCNo = @cActSKU
      SET @cUCCSKU = ''
      SET @nUCCQTY = 0

      -- SKU/UPC/UCC
      IF @cActSKU <> ''
      BEGIN
         IF @cActSKU = '99' -- Fully short
         BEGIN
            SET @cSKUValidated = '99'
            SET @cActQTY = '0'
            SET @cOutField10 = '0'
         END
         ELSE
         BEGIN
            -- Get SKU/UPC
            DECLARE @nSKUCnt INT
            SET @nSKUCnt = 0
            EXEC RDT.rdt_GETSKUCNT
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cActSKU
               ,@nSKUCnt     = @nSKUCnt       OUTPUT
               ,@bSuccess    = @b_Success     OUTPUT
               ,@nErr        = @nErrNo        OUTPUT
               ,@cErrMsg     = @cErrMsg       OUTPUT
   
            -- Validate SKU/UPC
            IF @nSKUCnt = 0
            BEGIN
               -- Check if UCC scanned
               SELECT 
                  @cUCCSKU = SKU, 
                  @nUCCQTY = QTY
               FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND UCCNo = @cUCCNo
   
               IF @cUCCSKU <> ''
                  SET @cActSKU = @cUCCSKU
               ELSE
               BEGIN
                  SET @nErrNo = 64426
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
                  SET @cOutField11 = CASE WHEN @nActQty = 0 THEN '' ELSE @nActQty END
                  SET @cOutField11 = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 11
                  GOTO Quit
               END
            END

            -- Get SKU
            IF @nSKUCnt = 1
            BEGIN
               EXEC [RDT].[rdt_GETSKU]
                   @cStorerKey  = @cStorerKey
                  ,@cSKU        = @cActSKU       OUTPUT
                  ,@bSuccess    = @b_Success     OUTPUT
                  ,@nErr        = @nErrNo        OUTPUT
                  ,@cErrMsg     = @cErrMsg       OUTPUT
            END

            -- (james08)
            -- Validate barcode return multiple SKU
            IF @nSKUCnt > 1
            BEGIN
               IF @cMultiSKUBarcode IN ('1', '2')
               BEGIN
                  -- Remember current on screen displayed SKU
                  SET @cSuggestedSKU = @cOutField02

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
                     'PickSlipNo',    -- DocType
                     @cPickSlipNo

                  IF @nErrNo = 0 -- Populate multi SKU screen
                  BEGIN
                     -- Go to Multi SKU screen
                     SET @nFromScn = @nScn
                     SET @nScn = 3570
                     SET @nStep = @nStep + 4
                     GOTO Quit
                  END
                  IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
                     SET @nErrNo = 0
               END
               ELSE
               BEGIN
                  SET @nErrNo = 64427
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'
                  SET @cOutField11 = CASE WHEN @nActQty = 0 THEN '' ELSE @nActQty END
                  SET @cOutField11 = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 11
                  GOTO Quit
               END
            END

            /*
            -- Validate barcode return multiple SKU
            IF @nSKUCnt > 1
            BEGIN
               SET @nErrNo = 64427
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'
               SET @cOutField11 = CASE WHEN @nActQty = 0 THEN '' ELSE @nActQty END
               SET @cOutField11 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 11
               GOTO Quit
            END
            */
            IF @cActSKU <> @cSKU
            BEGIN
               SET @nErrNo = 64428
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Different SKU'
               SET @cOutField11 = CASE WHEN @nActQty = 0 THEN '' ELSE @nActQty END
               SET @cOutField11 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 11
               GOTO Quit
            END
            
            SET @cSKUValidated = '1'
         END
      END
      
      IF @cActQty <> '' AND RDT.rdtIsValidQTY( @cActQty, 0) = 0 --Not check for zero QTY
      BEGIN
         SET @nErrNo = 64424
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 10
         GOTO Step_5_Fail
      END

      -- Check full short with QTY
      IF @cSKUValidated = '99' AND (@cActQty <> '0' AND @cActQty <> '') 
      BEGIN
         SET @nErrNo = 72302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FullShortNoQTY
         GOTO Step_5_Fail
      END

      DECLARE @nQTY INT
      SET @nQTY = CAST( @cActQty AS INT)

      -- Top up QTY
      IF @cSKUValidated = '99' -- Fully short
         SET @nQTY = 0
      ELSE IF @nUCCQTY > 0
         SET @nQTY = @nQTY + @nUCCQTY
      ELSE
         IF @cActSKU <> '' 
         BEGIN
            IF @cDynamicPickDisableQTYField = '1' 
            BEGIN
               IF @cPrePackIndicator = '2' 
                  SET @nQTY = @nQTY + @nPackQtyIndicator 
               ELSE 
                  SET @nQTY = @nQTY + 1
            END
            ELSE
            BEGIN
               IF @nQTY = @cActQTY AND           -- User not change QTY field
                  @cDynamicPickDefaultQTY <> '0' -- Have default QTY 
               BEGIN
                  IF @cPrePackIndicator = '2'
                     SET @nQTY = @nActQty + (@nPackQtyIndicator * @cDynamicPickDefaultQTY)
                  ELSE
                     SET @nQTY = @nActQty + @cDynamicPickDefaultQTY
               END
            END
         END
/*
      -- Top up QTY
      IF @cDynamicPickDisableQTYField = '1' -- QTY field disabled
      BEGIN
         IF @cUCCSKU <> ''
            SET @nQTY = @nActQty + @nUCCQTY
         ELSE 
         BEGIN
            IF @cActSKU <> ''
            BEGIN
               IF @cPrePackIndicator = '2'
                  SET @nQTY = @nActQty + @nPackQtyIndicator
               ELSE
                  SET @nQTY = @nActQty + 1
            END
         END
      END
      ELSE      
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- SKU
         
         IF @cUCCSKU <> ''
            SET @nQTY = @nActQty + @nUCCQTY
         ELSE
         BEGIN
            IF @cActSKU <> '' AND             -- SKU/UPC scanned
               @nQTY = @cActQTY AND           -- User not change QTY field
               @cDynamicPickDefaultQTY <> '0' -- Have default QTY 
            BEGIN
               IF @cPrePackIndicator = '2'
                  SET @nQTY = @nActQty + (@nPackQtyIndicator * @cDynamicPickDefaultQTY)
               ELSE
                  SET @nQTY = @nActQty + @cDynamicPickDefaultQTY
            END
            ELSE
            BEGIN
               SET @nQTY = @cActQTY  -- Capture user key-in QTY
               EXEC rdt.rdtSetFocusField @nMobile, 10 -- QTY
            END
         END
      END
*/
      -- Check over pick
      IF @nQty > @nQtyToPick
      BEGIN
         SET @nErrNo = 64429
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over Pick'
         GOTO Step_5_Fail
      END
      SET @nActQty = @nQTY
      
      -- SKU scanned, remain in current screen
      IF @cActSKU <> ''
      BEGIN
         SET @cOutField10 = @nActQty
         SET @cOutField11 = '' -- SKU

         IF @cDynamicPickDisableQTYField = '1' OR @cDynamicPickDefaultQTY <> '0'
            EXEC rdt.rdtSetFocusField @nMobile, 11 -- SKU
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 10 -- QTY
            
         GOTO Quit
      END

      -- Get carton no and label no
      SELECT TOP 1
         @nCartonNo = CartonNo,
         @cLabelNo = LabelNo
      FROM rdt.rdtDynamicPickLog WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND Zone = @cPickZone
         AND FromLOC = @cFromLOC
         AND ToLOC = @cToLOC
         AND AddWho = @cUserName

      -- Prep next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @nCartonNo
      SET @cOutField03 = @cLabelNo
      SET @cOutField04 = '' -- LabelNo
      SET @cOutField05 = '' -- Option

      -- Auto default label no
      IF @cDynamicPickDefaultLBLNoIf1PSNO = '1' AND @nTotal_PSNO = 1
         SET @cOutField04 = @cLabelNo

      -- Enable / disable field
      SET @cFieldAttr10 = ''
      
      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @cLocDescr = SUBSTRING( Descr, 1, 20) FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cS_Loc
      IF ISNULL( @cLocDescr, '') = ''
         SET @cLocDescr = @cS_Loc

      -- Prep prev screen var
      SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cS_Loc END
      SET @cOutField02 = ''

      -- Enable / disable field
      SET @cFieldAttr10 = ''
      
      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOutField11 = '' -- ActSKU
   END
END
GOTO Quit

/********************************************************************************
Step 6. Screen = 1645
   PKSLIPNO   (Field01)
   CARTONNO   (Field02)
   LABEL NO   (Field03)
   LABEL NO   (Field04, input)
   OPTION     (Field05, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cActLabelNo NVARCHAR(20)

      -- Screen mapping
      SET @cActLabelNo = @cInField04
      SET @cOption = @cInField05

      -- Validate option
      IF @cOption NOT IN ('', '1')
      BEGIN
         SET @nErrNo = 64452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Step_6_Fail
      END
      
      -- New carton
      IF @cOption = '1'
      BEGIN
         -- Validate if already a new carton (for preprinted label)
         IF @cLabelNo = ''
         BEGIN
            SET @nErrNo = 64453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AdyIsNewCarton
            GOTO Step_6_Fail
         END

         -- Validate if already a new carton (for non preprinted label)
         IF EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
               AND LabelNo = @cLabelNo
               AND CartonNo = @nCartonNo
               AND SKU = '')
         BEGIN
            SET @nErrNo = 64454
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AdyIsNewCarton
            GOTO Step_6_Fail
         END

         -- New carton
         EXECUTE rdt.rdt_DynamicPick_PickAndPack_NewCarton @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cUserName, 
            @cPrinter,
            @cPickSlipType,
            @cPickSlipNo,
            @cPickZone,
            @cFromLOC,
            @cToLOC, 
            @cDynamicPickCartonLabel, 
            @cDynamicPickCartonManifest, 
            @cDynamicPickPrePrintedLabelNo, 
            @nCartonNo OUTPUT,
            @cLabelNo  OUTPUT,
            @nErrNo    OUTPUT,
            @cErrMsg   OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prep next screen var
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = @nCartonNo
         SET @cOutField03 = @cLabelNo
         SET @cOutField04 = '' -- LabelNo
         SET @cOutField05 = '' -- Option
         
         GOTO Quit
      END

      -- Label is optional for zero pick QTY
      IF @nActQTY = 0 AND @cActLabelNo = ''
      BEGIN
         -- Go to option (confirm/close case) screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Validate blank
      IF @cActLabelNo = '' OR @cActLabelNo IS NULL
      BEGIN
         SET @nErrNo = 64431
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNo needed
         GOTO Step_6_Fail
      END

      -- Decode label
      IF @cDecodeLabelNo <> ''
      BEGIN
         DECLARE
            @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
            @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
            @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
            @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
            @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)

         SET @cErrMsg = ''
         SET @nErrNo = 0
         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cActLabelNo
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
            GOTO Step_6_Fail

         SET @cActLabelNo = @c_oFieled01
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LABELNO', @cActLabelNo) = 0
      BEGIN
         SET @nErrNo = 64443
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_6_Fail
      END

      -- Displayed label no can be blank so scanned label might different with displayed label
      -- If the label no already been assigned (by system/pre-printed), scanned label no must = assigned label no
      -- Else assign the label no with the scanned label no if displayed label no is blank
      IF @cActLabelNo <> @cLabelNo
      BEGIN
--         IF @cPrinter <> '' AND @cLabelNo <> ''  (james03)
         IF @cLabelNo <> ''
         BEGIN
            SET @nErrNo = 64432
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LABELNo
            GOTO Step_6_Fail
         END

         -- Check if labelno used in other pickslip
         IF EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND LabelNo = @cActLabelNo
               AND PickSlipNo <> @cPickSlipNo)
         BEGIN
            SET @nErrNo = 64447
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNo Used
            GOTO Step_6_Fail
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey ' +
               ',@cWaveKey, @cLoadKey, @cPickZone, @cPKSLIP_Cnt, @cCountry, @cFromLOC, @cToLOC ' +
               ',@cT_PickSlipNo1, @cT_PickSlipNo2, @cT_PickSlipNo3, @cT_PickSlipNo4, @cT_PickSlipNo5 ' +
               ',@cT_PickSlipNo6, @cT_PickSlipNo7, @cT_PickSlipNo8, @cT_PickSlipNo9, @cPickSlipNo ' +
               ',@cS_LOC, @cSKU, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
               ',@nQtyToPick, @nActQty, @nCartonNo, @cLabelNo, @cOption, @nErrNo  OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile         INT           ' +  
               ',@nFunc           INT           ' + 
               ',@cLangCode       NVARCHAR( 3)  ' + 
               ',@nStep           INT           ' +
               ',@nInputKey       INT           ' + 
               ',@cFacility       NVARCHAR( 5)  ' +
               ',@cStorerKey      NVARCHAR( 15) ' +
               ',@cWaveKey        NVARCHAR( 10) ' +
               ',@cLoadKey        NVARCHAR( 10) ' +
               ',@cPickZone       NVARCHAR( 10) ' +
               ',@cPKSLIP_Cnt     NVARCHAR( 5)  ' +
               ',@cCountry        NVARCHAR( 20) ' +
               ',@cFromLOC        NVARCHAR( 10) ' +
               ',@cToLOC          NVARCHAR( 10) ' +
               ',@cT_PickSlipNo1  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo2  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo3  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo4  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo5  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo6  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo7  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo8  NVARCHAR( 10) ' +
               ',@cT_PickSlipNo9  NVARCHAR( 10) ' +
               ',@cPickSlipNo     NVARCHAR( 10) ' +
               ',@cS_LOC          NVARCHAR( 10) ' +
               ',@cSKU            NVARCHAR( 20) ' +
               ',@cLottable01     NVARCHAR( 18) ' +
               ',@cLottable02     NVARCHAR( 18) ' +
               ',@cLottable03     NVARCHAR( 18) ' +
               ',@dLottable04     DATETIME      ' +
               ',@nQtyToPick      INT           ' +
               ',@nActQty         INT           ' +
               ',@nCartonNo       INT           ' +
               ',@cLabelNo        NVARCHAR( 20) ' +
               ',@cOption         NVARCHAR( 1)  ' +
               ',@nErrNo          INT OUTPUT    ' +
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey 
               ,@cWaveKey, @cLoadKey, @cPickZone, @cPKSLIP_Cnt, @cCountry, @cFromLOC, @cToLOC 
               ,@cT_PickSlipNo1, @cT_PickSlipNo2, @cT_PickSlipNo3, @cT_PickSlipNo4, @cT_PickSlipNo5
               ,@cT_PickSlipNo6, @cT_PickSlipNo7, @cT_PickSlipNo8, @cT_PickSlipNo9, @cPickSlipNo
               ,@cS_LOC, @cSKU, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@nQtyToPick, @nActQty, @nCartonNo, @cLabelNo, @cOption, @nErrNo  OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      BEGIN TRAN

      -- Check if the label scanned exist in PackDetail.
      -- If exists then assign the existing carton no (james06)
      IF @cPrinter = ''
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
               AND LabelNo = @cActLabelNo)
         BEGIN
            SELECT @nNewCartonNo = ISNULL(CartonNo, 0)
            FROM dbo.PackDetail (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
               AND LabelNo = @cActLabelNo

            IF @nNewCartonNo <> @nCartonNo
            BEGIN
               -- Delete the reserved PackDetail line (cartonno) since we are going to use the existing cartonno
               DELETE FROM dbo.PackDetail
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND SKU = ''

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 64445
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPACKDTLFail'
                  ROLLBACK TRAN
                  GOTO Step_6_Fail
               END

               -- Update RDTDynamicPickLog CartonNo to new CartonNo
               UPDATE rdt.rdtDynamicPickLog WITH (ROWLOCK) SET
                  CartonNo = @nNewCartonNo
               WHERE PickSlipNo = @cPickSlipNo
                  AND Zone = @cPickZone
                  AND FromLOC = @cFromLOC
                  AND ToLOC = @cToLOC
		            AND AddWho = @cUserName
                  AND CartonNo = @nCartonNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 64446
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPKInfoFail'
                  ROLLBACK TRAN
                  GOTO Step_6_Fail
               END

               SET @nCartonNo = @nNewCartonNo
            END
         END
      END

      -- Check if label no exists within other carton no for the same storer (james04)
      IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LabelNo = @cActLabelNo)
--            AND CartonNo <> @nCartonNo)
      BEGIN
         -- Label no exists within same storer, check whether it is within the same pickslip and carton
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cActLabelNo)
         BEGIN
            SET @nErrNo = 64440
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LabelNo Exists
            ROLLBACK TRAN
            GOTO Step_6_Fail
         END
      END

      -- Update RDTDynamicPickLog (LabelNo)
      DECLARE @nRowRef INT
      SELECT @nRowRef = RowRef 
      FROM RDT.RDTDynamicPickLog WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo
         AND Zone = @cPickZone
         AND FromLOC = @cFromLOC
         AND ToLOC = @cToLOC
         AND AddWho = @cUserName

      UPDATE RDT.RDTDynamicPickLog WITH (ROWLOCK) SET
         LabelNo = @cActLabelNo
      WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 64433
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd DPL Fail'
         GOTO Quit
      END

      IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = ''
            AND SKU = '')
      BEGIN
         UPDATE dbo.PackDetail WITH (ROWLOCK) SET
            LabelNo = @cActLabelNo,
            ArchiveCop = NULL,
            EditWho  = 'rdt.' + sUser_sName(),
            EditDate = GetDate()
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = ''
            AND SKU = ''

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 64444
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PADtl Fail'
            ROLLBACK TRAN
            GOTO Quit
         END
      END

      COMMIT TRAN
      SET @cLabelNo = @cActLabelNo

      -- Go to option (confirm/close case) screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      SET @cOutField01 = ''
      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Disable QTY field
      IF @cDynamicPickDisableQTYField = '1'
         SET @cFieldAttr10 = 'O'

      -- Prep next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING(@cSKUDescr, 21, 20)
      SET @cOutField05 = @cLottable01
      SET @cOutField06 = @cLottable02
      SET @cOutField07 = @cLottable03
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField09 = @nQtyToPick
      SET @cOutField10 = @nActQty
      SET @cOutField11 = ''
      SET @cOutField13 = CASE @cPrePackIndicator WHEN '2' THEN ISNULL(@nPackQtyIndicator, '0') ELSE '' END

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cActLabelNo = ''
      SET @cOutField04 = '' -- ActLabelNo
   END
END
GOTO Quit

/********************************************************************************
Step 7. Screen = 1646
   Next Option

   1=CONFIRM
   2=CLOSE CASE
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 64434
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'
         GOTO Step_7_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 64435
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_7_Fail
      END

      DECLARE @nCurrentCartonNo INT
      DECLARE @cCurrentLabelNo  NVARCHAR(20)
      SET @nCurrentCartonNo = @nCartonNo
      SET @cCurrentLabelNo  = @cLabelNo

      IF @cOption = '1' -- Confirm
      BEGIN
         -- Check if short pick
         IF @nQtyToPick <> @nActQty
         BEGIN
            -- Go to short pick screen
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1
            GOTO Quit
         END

         -- Get last task qty
         DECLARE @nLastTaskQTY INT
         SET @nLastTaskQTY = 0
         EXEC rdt.rdt_DynamicPick_PickAndPack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cPickSlipType
            ,@cPickSlipNo
            ,@cPickZone
            ,@cFromLoc
            ,@cToLoc
            ,'Balance' -- Type
            ,@nLastTaskQTY OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT

         IF @nLastTaskQTY = @nActQTY
         BEGIN
            SET @nErrNo = 64436
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pls close case'
            GOTO Quit
         END

         -- Confirm PickDetail, insert/update PackDetail
         SET @nErrNo = 0
         EXECUTE rdt.rdt_DynamicPick_PickAndPack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPickSlipType,
            @cPickSlipNo,
            @cPickZone,
            @cC_Loc,
            @cSKU,
            @cLottable01,
            @cLottable02,
            @cLottable03,
            @dLottable04,
            @nActQty,
            'N', -- Short = Y/N
            @nCartonNo,
            @cLabelNo,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT  

         IF @nErrNo <> 0
            GOTO Quit
      END

      IF @cOption = '2' -- Close case
      BEGIN
         DECLARE @cShort NVARCHAR(1)
         IF @nActQty = 0
            SET @cShort = 'Y'
         ELSE
            SET @cShort = 'N'

         SET @nErrNo = 0
         BEGIN TRAN
         -- Confirm PickDetail, insert/update PackDetail
         EXECUTE rdt.rdt_DynamicPick_PickAndPack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPickSlipType,
            @cPickSlipNo,
            @cPickZone,
            @cC_Loc,
            @cSKU,
            @cLottable01,
            @cLottable02,
            @cLottable03,
            @dLottable04,
            @nActQty,
            @cShort, -- Short = Y/N
            @nCartonNo,
            @cLabelNo,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN
            GOTO Quit
         END

         -- Confirm PackHeader, scan out PickingInfo (if pickslip fully picked)
         EXECUTE rdt.rdt_DynamicPick_PickAndPack_Close @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPickSlipType, 
            @cPickSlipNo,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN
            GOTO Quit
         END

         COMMIT TRAN

         -- New carton
         EXECUTE rdt.rdt_DynamicPick_PickAndPack_NewCarton @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cUserName, 
            @cPrinter,
            @cPickSlipType,
            @cPickSlipNo,
            @cPickZone,
            @cFromLOC,
            @cToLOC, 
            @cDynamicPickCartonLabel, 
            @cDynamicPickCartonManifest, 
            @cDynamicPickPrePrintedLabelNo, 
            @nCartonNo OUTPUT,
            @cLabelNo  OUTPUT,
            @nErrNo    OUTPUT,
            @cErrMsg   OUTPUT
      END
      
      GOTO Where_To_Go
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @nCartonNo
      SET @cOutField03 = @cLabelNo
      SET @cOutField04 = '' --LabelNo
      SET @cOutField05 = '' --CartonNo

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 8. Screen = 1647
 CONFIRM SHORT PICK?

   1=YES
   2=NO
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 64437
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'
         GOTO Step_8_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 64438
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_8_Fail
      END

      IF @cOption = '1' -- Confirm
      BEGIN
         -- Confirm PickDetail, insert/update PackDetail
         SET @nErrNo = 0
         EXECUTE rdt.rdt_DynamicPick_PickAndPack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPickSlipType, 
            @cPickSlipNo, 
            @cPickZone,
            @cC_Loc,
            @cSKU,
            @cLottable01,
            @cLottable02,
            @cLottable03,
            @dLottable04,
            @nActQty,
            'Y', -- Short = Y/N
            @nCartonNo,
            @cLabelNo,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT  
         IF @nErrNo <> 0 GOTO Quit

         GOTO Where_To_Go
      END

      IF @cOption = '2'
      BEGIN
         -- Prepare prev screen variable
         SET @cOption = ''
         SET @cOutField01 = '' -- Option

         -- Go to previous screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen variable
      SET @cOption = ''
      SET @cOutField01 = '' -- Option

      -- Go to previous screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_8_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = '' --Option
   END
END
GOTO Quit

Where_To_Go:
BEGIN
   -- Get next task
   SET @nErrNo = 0
      EXEC rdt.rdt_DynamicPick_PickAndPack_GetNextTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
      @cPickZone,
      @cFromLOC,
      @cToLOC,
      @cC_Loc,
      @cPickSlipType, 
      @cT_PickSlipNo1,
      @cT_PickSlipNo2,
      @cT_PickSlipNo3,
      @cT_PickSlipNo4,
      @cT_PickSlipNo5,
      @cT_PickSlipNo6,
      @cT_PickSlipNo7,
      @cT_PickSlipNo8,
      @cT_PickSlipNo9,
      @cPickSlipNo   OUTPUT,
      @cSKU          OUTPUT, -- Next SKU
      @cSKUDescr     OUTPUT,
      @cLottable01   OUTPUT,
      @cLottable02   OUTPUT,
      @cLottable03   OUTPUT,
      @dLottable04   OUTPUT,
      @nQtyToPick    OUTPUT, -- Qty need to pick for same sku in same location within the same pickslipno
      @nOtherLocQtyToPick OUTPUT, -- Qty to pick from next location onwards within the same pickslipno
      @nTotalQtyToPick  OUTPUT, -- Qty to pick for all locations within the same pickslipno
      'C',                          -- Indicate from close case
      @nErrNo     OUTPUT,
      @cErrMsg     OUTPUT

   IF @nErrNo = 0 -- More task
   BEGIN
      -- Disable QTY field
      IF @cDynamicPickDisableQTYField = '1'
         SET @cFieldAttr10 = 'O'

      -- 1) If there is more qty to pick on same location, go to Screen 5
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING(@cSKUDescr, 21, 20)
      SET @cOutField05 = @cLottable01
      SET @cOutField06 = @cLottable02
      SET @cOutField07 = @cLottable03
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField09 = @nQtyToPick
      SET @cOutField10 = CASE WHEN @cDynamicPickDisableQTYField = '1' THEN '0' ELSE '' END -- QTY
      SET @cOutField11 = '' -- SKU
      SET @cOutField12 = RTRIM(CAST( ISNULL(@nOtherLocQtyToPick, 0) AS NVARCHAR( 8))) + '/' + CAST( ISNULL(@nTotalQtyToPick, 0) AS NVARCHAR( 8))   -- ZG01
      
      SET @nActQty = 0
      SET @cSKUValidated = '0'

      SET @nScn  = 1644
      SET @nStep = 5

      EXEC rdt.rdtSetFocusField @nMobile, 11 -- SKU
      GOTO Quit
   END

   IF @nErrNo <> 0 -- No task in same location
   BEGIN
      -- If no task at same location, check if any different loc to pick
      SET @nErrNo = 0
      SET @cS_Loc = ''
      EXECUTE rdt.rdt_DynamicPick_PickAndPack_GetNextLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cPickZone,
         @cFromLOC,
         @cToLOC,
         @cPickSlipType, 
         @cT_PickSlipNo1,
         @cT_PickSlipNo2,
         @cT_PickSlipNo3,
         @cT_PickSlipNo4,
         @cT_PickSlipNo5,
         @cT_PickSlipNo6,
         @cT_PickSlipNo7,
         @cT_PickSlipNo8,
         @cT_PickSlipNo9,
         @cC_Loc,   -- Current location
         @cS_Loc  OUTPUT,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT

      IF @nErrNo = 0
      BEGIN
         SELECT @cLocDescr = SUBSTRING( Descr, 1, 20) FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cS_Loc
         IF ISNULL( @cLocDescr, '') = ''
            SET @cLocDescr = @cS_Loc

         -- Found next location, go to Screen 4
         SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cS_Loc END
         SET @cOutField02 = CASE WHEN @cDynamicPickAutoDefaultDPLoc = '1' THEN @cS_Loc ELSE '' END

         SET @nScn  = 1643
         SET @nStep = 4
      END
      ELSE
      BEGIN
         -- If no more pick task for this wave, go to Screen 3
         -- Calculate TotalPickQty and TotalCBM
         SET @nTotal_PickQTY = 0
         SET @cTotal_CBM = ''
         EXECUTE rdt.rdt_DynamicPick_PickAndPack_CalcTotalQTYAndCBM @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPickZone,
            @cFromLOC,
            @cToLOC,
            @cPickSlipType, 
            @cT_PickSlipNo1,
            @cT_PickSlipNo2,
            @cT_PickSlipNo3,
            @cT_PickSlipNo4,
            @cT_PickSlipNo5,
            @cT_PickSlipNo6,
            @cT_PickSlipNo7,
            @cT_PickSlipNo8,
            @cT_PickSlipNo9,
            @nTotal_PickQTY OUTPUT,
            @cTotal_CBM     OUTPUT

         SET @cOutField01 = @cWaveKey
         SET @cOutField09 = @cLoadKey
         SET @cOutField02 = @cPickZone
         SET @cOutField03 = @nTotal_PSNO
         SET @cOutField04 = @cCountry

         SELECT @cLocDescr = SUBSTRING( Descr, 1, 20) FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cFromLOC
         IF ISNULL( @cLocDescr, '') = ''
            SET @cLocDescr = @cFromLOC

         SET @cOutField05 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cFromLOC END

         SELECT @cLocDescr = SUBSTRING( Descr, 1, 20) FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cToLOC
         IF ISNULL( @cLocDescr, '') = ''
            SET @cLocDescr = @cToLOC
         
         SET @cOutField06 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cToLOC END
      
         SET @cOutField07 = @nTotal_PickQty
         SET @cOutField08 = @cTotal_CBM
         SET @cOutField09 = @cLoadKey

         SET @nScn  = 1642
         SET @nStep = 3
      END
   END

   -- Clean up err msg (otherwise appear on destination screen)
   SET @nErrNo = 0
   SET @cErrMsg = ''
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
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      -- Get SKU info
      SELECT @cSKUDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   END

   SET @nActQty = 0
   SET @cSKUValidated = '0'

   -- Disable QTY field
   IF @cDynamicPickDisableQTYField = '1'
      SET @cFieldAttr10 = 'O'

   -- Prep next screen var
   SET @cOutField01 = @cPickSlipNo
   SET @cOutField02 = @cSKU
   SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)
   SET @cOutField04 = SUBSTRING(@cSKUDescr, 21, 20)
   SET @cOutField05 = @cLottable01
   SET @cOutField06 = @cLottable02
   SET @cOutField07 = @cLottable03
   SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)
   SET @cOutField09 = @nQtyToPick
   SET @cOutField10 = CASE WHEN @cDynamicPickDisableQTYField = '1' THEN '0' ELSE '' END -- QTY
   SET @cOutField11 = @cSKU  -- SKU
   SET @cOutField12 = RTRIM(CAST( ISNULL(@nOtherLocQtyToPick, 0) AS NVARCHAR( 8))) + '/' + CAST( ISNULL(@nTotalQtyToPick, 0) AS NVARCHAR( 8))   -- ZG01
   SET @cOutField13 = CASE WHEN @cPrePackIndicator = '2' THEN ISNULL(@nPackQtyIndicator, '0') ELSE '' END

   -- Go to SKU QTY screen
   SET @nScn = @nFromScn
   SET @nStep = @nStep - 4

END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg   = @cErrMsg,
      Func     = @nFunc,
      Step     = @nStep,
      Scn      = @nScn,

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,
      Printer    = @cPrinter,

      V_SKU       = @cSKU,
      V_SKUDescr  = @cSKUDescr,

      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,

      V_LOC        = @cFromLOC,
      V_PickSlipNo = @cPickSlipNo,
      V_LoadKey    = @cLoadKey, 

      V_String1    = @cWaveKey,
      V_String2    = @cPickZone,
      V_String3    = @cPKSlip_Cnt,
      V_String4    = @cCountry,
      V_String5    = @cToLOC,
      V_String6    = @cS_Loc,
      V_String7    = @cC_Loc,
      V_String8    = @cLocShowDescr,
      V_String9    = @cLabelNo,
      V_String10   = @cT_PickSlipNo1,
      V_String11   = @cT_PickSlipNo2,
      V_String12   = @cT_PickSlipNo3,
      V_String13   = @cT_PickSlipNo4,
      V_String14   = @cT_PickSlipNo5,
      V_String15   = @cT_PickSlipNo6,
      V_String16   = @cT_PickSlipNo7,
      V_String17   = @cT_PickSlipNo8,
      V_String18   = @cT_PickSlipNo9,
      V_String19   = @cPrePackIndicator,
      V_String21   = @cSKUValidated,
      V_String24   = @cSuggestedSKU, 
      V_String25   = @cDecodeSP,   
      V_String26   = @cPickSlipType,  
      V_String28   = @cDynamicPickPickZone, 
      V_String29   = @cDynamicPickDefaultQTY,
      V_String30   = @cDynamicPickAutoDefaultDPLoc,
      V_String31   = @cDynamicPickCartonLabel,
      V_String32   = @cDynamicPickCartonManifest,
      V_String33   = @cPopulatePickSlipSP,
      V_String34   = @cDynamicPickDefaultLBLNoIf1PSNO,
      V_String35   = @cExtendedValidateSP, 
      V_String36   = @cDynamicPickPrePrintedLabelNo,
      V_String37   = @cDynamicPickReplenB4Pick, -- (ChewKP01)
      V_String38   = @cDynamicPickDisableQTYField,
      V_String39   = @cDecodeLabelNo,
      V_String40   = @cExtendedUpdateSP,
      V_String43   = @cMultiSKUBarcode,

      V_QTY        = @nActQty,
      V_Cartonno   = @nCartonNo, 
      V_FromScn    = @nFromScn,
      
      V_Integer1   = @nPackQtyIndicator,
      V_Integer2   = @nTotal_PSNO,
      V_Integer3   = @nQtyToPick,
      V_Integer4   = @nOtherLocQtyToPick,
      V_Integer5   = @nTotalQtyToPick,
      
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
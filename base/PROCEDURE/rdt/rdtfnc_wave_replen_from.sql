SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/                      
/* Copyright: IDS                                                       */                      
/* Purpose: Wave Replenishment From SOS141253                           */                      
/*                                                                      */                      
/* Modifications log:                                                   */                      
/*                                                                      */                      
/* Date       Rev  Author     Purposes                                  */                      
/* 2009-08-10 1.0  James      Created                                   */                      
/* 2011-06-24 1.1  ChewKP     SOS#218879 Changes for IDSUS Sean John    */                      
/*                            (ChewKP01)                                */                      
/* 2011-09-07 1.2  James      Display TOLOC as REPLENINPROGLOC (james01)*/                    
/* 2011-09-14 1.3  James      Bug fix (james02)                         */                    
/* 2011-11-23 1.4  ChewKP     Bug fix (ChewKP02)                        */                
/* 2011-12-05 1.5  ChewKP     Changes for LCI - Allow over replen       */                
/*                            (ChewKP03)                                */                
/* 2011-12-08 1.6  James      Bug fix (james03)                         */                
/* 2011-12-13 1.7  James      Reset variable (james04)                  */                
/* 2011-12-14 1.8  ChewKP     Validate UCC SKU = Replen SKU , Validate  */              
/*                            Qty on SKUxLoc (ChewKP04)                 */              
/* 2011-12-21 1.9  James      Reset variable (james05)                  */               
/* 2011-12-21 2.0  ChewKP     Consolidate ReplenFrom (ChewKP05)         */         
/* 2011-01-01 2.1  ChewKP     Loc Lock when Loc been assigned           */      
/*                            (ChewKP06)                                */      
/* 2011-01-01 2.2  ChewKP     Fixes - Scanning Multiple UCC But Qty     */      
/*                            not updating (ChewKP07)                   */      
/* 2011-01-01 2.3  ChewKP     Fixes - When scanning Multiple UCC not    */      
/*                            able to Over Replen correctly (ChewKP08)  */      
/* 2011-01-01 2.4  ChewKP     Update UCC.Status ='4' (ChewKP09)         */      
/* 2012-01-01 2.5  Shong      Revise the logic (SHONG001)               */      
/* 2012-01-06 2.5  James      Ensure SKU display properly (james06)     */      
/* 2012-01-11 2.6  ChewKP     Standardize UCC Status (ChewKP10)         */      
/* 2012-02-03 2.7  Shong      Added Start Location                      */      
/* 2012-04-19 2.8  ChewKP     Restrict scanning of UPC when UCC From Loc*/    
/*                            is Open (ChewKP11)                        */    
/* 2012-05-03 2.9  James      Check LocationCategory when we determine  */    
/*                            whether we need to scan UCC (james07)     */
/* 2016-09-30 3.0  Ung        Performance tuning                        */
/* 2018-11-21 3.1  Gan        Performance tuning                        */
/************************************************************************/                      
                      
CREATE PROC [RDT].[rdtfnc_Wave_Replen_From] (                      
   @nMobile    int,                      
   @nErrNo     int  OUTPUT,                      
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max                      
)                      
AS          
SET NOCOUNT ON                      
   SET QUOTED_IDENTIFIER OFF                      
   SET ANSI_NULLS OFF                      
   SET CONCAT_NULL_YIELDS_NULL OFF                      
                      
-- Misc variable                      
DECLARE                       
   @cOption     NVARCHAR( 1),                      
   @nCount      INT,                      
   @nRowCount   INT                      
                      
-- RDT.RDTMobRec variable                      
DECLARE                       
   @nFunc      INT,                      
   @nScn       INT,                      
   @nCurScn    INT,  -- Current screen variable                      
   @nStep      INT,                      
   @nCurStep   INT,                      
   @cLangCode  NVARCHAR( 3),                      
   @nInputKey  INT,                      
   @nMenu      INT,                      
                      
   @cStorerKey NVARCHAR( 15),                      
   @cFacility  NVARCHAR( 5),                       
   @cPrinter   NVARCHAR( 10),                      
   @cUserName  NVARCHAR( 18),       
   @cStartLoc  NVARCHAR(10),                      
                      
   @c_ExecStatements    NVARCHAR(4000),                      
   @c_ExecArguments     NVARCHAR(4000),                      
                      
   @cWaveKey             NVARCHAR( 10),                      
   @cLoadKey             NVARCHAR( 10),                      
   @cMBOLKey             NVARCHAR( 10),                      
   @cPickSlipNo          NVARCHAR( 10),                      
   @cCaseID              NVARCHAR( 10),                      
   @cDataWindow          NVARCHAR( 50),                       
   @cTargetDB            NVARCHAR( 10),                       
   @cSKU                 NVARCHAR( 20),                      
   @cActSKU              NVARCHAR( 20),                      
   @cUCC_SKU             NVARCHAR( 20),                      
   @cType                NVARCHAR( 5),                      
   @cDropID              NVARCHAR( 20),                      
   @cLOT                 NVARCHAR( 10),                      
   @cLOC                 NVARCHAR( 10),                      
   @cTOLOC               NVARCHAR( 10),                  
   @cID                  NVARCHAR( 18),                      
   @cStyle               NVARCHAR( 20),                      
   @cColor               NVARCHAR( 10),                 
   @cMeasurement         NVARCHAR( 5),                      
   @cSize                NVARCHAR( 5),                      
   @cColorField          NVARCHAR( 10),                 
   @cColorDescr          NVARCHAR( 20),                      
   @c_ErrMsg             NVARCHAR( 20),                      
   @cActQty              NVARCHAR( 5),                      
   @cUCCFlag             NVARCHAR( 1),                      
   @cSKUFlag             NVARCHAR( 1),                      
   @cUCCMixedSKUFlag     NVARCHAR( 1),                      
   @cReplenishmentKey    NVARCHAR( 10),                  
   @cSKUInUCC1           NVARCHAR( 20),                      
   @cSKUInUCC2           NVARCHAR( 20),                      
   @cDefaultQty          NVARCHAR( 5),                      
   @cConfirmed           NVARCHAR( 1),                      
   @cUCC                 NVARCHAR( 20),                      
   @cReplenInProgressLOC NVARCHAR( 10),                      
   @cPutawayZone         NVARCHAR( 10), -- (ChewKP01)                      
   @cSuggLOC             NVARCHAR( 10), -- (ChewKP01)                      
   @cReplenValidateZone  NVARCHAR(  1), -- (CheWKP01)                 
   @cUCCSKU              NVARCHAR( 20), -- (ChewKP04)              
   @nUCCQty              INT,       -- (ChewKP04)                 
   @cReplenToByBatch     NVARCHAR(1),   -- (ChewKP05)            
   @nReplenQTY           INT,       -- (ChewKP05)                   
                      
   @nSuggestedQTY       INT,                      
   @nOutstandingQty     INT,                      
   @nQTY                INT,                      
   @nSKUCnt             INT,                       
   @b_Success           INT,                       
   @n_Err               INT,                       
   @nQTYInUCC1          INT,                      
   @nQTYInUCC2          INT,                      
   @cAllowOverReplen    NVARCHAR(1), -- (ChewKP03)           
                  
                      
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
   @cInField15 NVARCHAR( 60), @cOutField15 NVARCHAR( 60),                      
                      
   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),                      
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),                      
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),                      
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),                      
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),                      
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),                      
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),                      
   @cFieldAttr15 NVARCHAR( 1)                      
                         
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
                         
   @cPickSlipNo = V_PickSlipNo,                      
   @cLoadKey    = V_LoadKey,                      
   @cLOT        = V_LOT,                      
   @cLOC        = V_LOC,                      
   @cID         = V_ID,                      
   @cSKU        = V_SKU,                      
   @nQTY        = V_QTY,  
   
   @nSuggestedQTY   = V_Integer1,
   @nOutstandingQty = V_Integer2,
                  
   @cWaveKey    = V_String1,                      
   @cDropID     = V_String2,                      
   @cTOLOC      = V_String3,                      
   @cStyle      = V_String4,                      
   @cColor      = V_String5,                      
   @cMeasurement= V_String6,                      
   @cColorField = V_String7,                      
  -- @nSuggestedQTY        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8,  5), 0) = 1 THEN LEFT( V_String8,  5) ELSE 0 END,                      
  -- @nOutstandingQty      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9,  5), 0) = 1 THEN LEFT( V_String9,  5) ELSE 0 END,             
   @cDefaultQty          = V_String10,                      
   @cReplenishmentKey    = V_String11,                      
   @cReplenInProgressLOC = V_String12,                      
   @cLoadKey             = V_String13,                      
   @cPutawayZone         = V_String14,                      
   @cSuggLOC             = V_String15,       
   @cStartLoc            = V_String16,                      
                      
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
                      
IF @nFunc = 942  -- Wave Replenishment From                      
BEGIN                      
   -- (ChewKP01)                      
   DECLARE @nScnWave          INT                      
   ,@nStepWave                INT                      
   ,@nScnZone                 INT                      
   ,@nStepZone                INT                      
   ,@nScnDropID               INT                      
   ,@nStepDropID              INT                      
   ,@nScnShortPick            INT                      
   ,@nStepShortPick           INT                      
   ,@nScnShortPickConfirm     INT                      
   ,@nStepShortPickConfirm    INT                      
   ,@nScnSKUQty               INT                      
   ,@nStepSKUQty              INT                      
   ,@nScnLoc                  INT                      
   ,@nStepLoc                 INT                      
   ,@nScnNoTask               INT                      
   ,@nStepNoTask              INT      
   ,@nScnLocationLock         INT      
   ,@nStepLocationLock        INT                      
                      
                      
   SET @nScnWave      = 2070                      
   SET @nStepWave     = 1                      
                         
   SET @nScnDropID    = 2071                           
   SET @nStepDropID   = 2                      
                         
   SET @nScnLoc    = 2072                           
   SET @nStepLoc   = 3                      
                      
   SET @nScnSKUQty      = 2073                                   
   SET @nStepSKUQty     = 4                      
                      
   SET @nScnZone      = 2077                           
   SET @nStepZone     = 8                                   
                      
   SET @nScnShortPickConfirm   = 2075                      
   SET @nStepShortPickConfirm  = 6                      
                         
   SET @nScnShortPick   = 2078                      
   SET @nStepShortPick  = 9                      
                         
   SET @nScnNoTask   = 2079                      
   SET @nStepNoTask  = 10                      
      
   SET @nScnLocationLock  = 2069      
   SET @nStepLocationLock = 11      
                             
   -- Redirect to respective screen                      
   IF @nStep = 0 GOTO Step_0   -- Wave Replenishment From                      
   IF @nStep = 1 GOTO Step_1   -- Scn = 2070. Wave                      
   IF @nStep = 2 GOTO Step_2   -- Scn = 2071. Wave, Scan Drop ID                      
   IF @nStep = 3 GOTO Step_3   -- Scn = 2072. Wave, Drop ID, LOC               
   IF @nStep = 4 GOTO Step_4  -- Scn = 2073. Drop ID, LOC, ID, TO LOC, SKU, ...                      
   IF @nStep = 5 GOTO Step_5   -- Scn = 2074. Enter                      
   IF @nStep = 6 GOTO Step_6   -- Scn = 2075. Option                      
   IF @nStep = 7 GOTO Step_7   -- Scn = 2076. Option                      
   IF @nStep = 8 GOTO Step_8   -- Scn = 2077. PutawayZone -- (ChewKP01)                      
   IF @nStep = 9 GOTO Step_9   -- Scn = 2078. Short Pick Confirm -- (ChewKP01)                      
   IF @nStep = 10 GOTO Step_10 -- Scn = 2079. No Task -- (ChewKP01)                      
   IF @nStep = 11 GOTO Step_11 -- Scn = 2069. Location Locked       
                         
END                      
                      
--RETURN -- Do nothing if incorrect step                      
                      
/********************************************************************************                      
Step 0. func = 942. Menu                      
********************************************************************************/                      
Step_0:                      
BEGIN                      
   -- Set the entry point                      
   SET @nScn = 2070                      
   SET @nStep = 1                      
                      
   -- Initiate var                      
   SET @cWaveKey = ''                      
   SET @cLoadKey = '' -- (ChewKP01)                      
                      
   -- Init screen                      
   SET @cOutField01 = '' -- Wave                      
   SET @cOutField02 = '' -- Load                      
                      
   SELECT @cReplenInProgressLOC = ISNULL(SValue, '') FROM dbo.StorerConfig WITH (NOLOCK)                      
   WHERE StorerKey = @cStorerKey                      
      AND Facility = @cFacility                      
      AND ConfigKey = 'REPLENINPROGLOC'                      
            
--   COMMENTED james05            
--   SELECT @cColorField = ISNULL(SValue, '') FROM dbo.StorerConfig WITH (NOLOCK)                      
--   WHERE StorerKey = @cStorerKey                      
--      AND ConfigKey = 'COLORDESCRFIELD'                      
                      
   SET @cDefaultQty = rdt.RDTGetConfig( 0, 'DefaultQty', @cStorerKey)                      
   IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 0                      
      SET @cDefaultQty = ''                      
                      
END                      
GOTO Quit                      
                      
/********************************************************************************                      
Step 1. Scn = 2070.                       
   Wave     (field01, input)                      
   LoadKey  (field02, input)                      
********************************************************************************/                      
Step_1:                      
BEGIN                      
   IF @nInputKey = 1 --ENTER                      
   BEGIN                      
         --screen mapping                      
      SET @cWaveKey = @cInField01                      
      SET @cLoadKey = @cInField02              
      SET @cStartLoc = ''              
                  
      -- Validate blank                      
      IF ISNULL(@cWaveKey, '') = '' AND ISNULL(@cLoadKey, '') = ''                       
      BEGIN                      
         SET @nErrNo = 67391                      
         SET @cErrMsg = rdt.rdtgetmessage( 67391, @cLangCode,'DSP') --Key Needed                      
         GOTO Step_1_Fail                               
      END                      
                      
      -- Check if wavekey exists                      
      IF ISNULL(@cWaveKey, '') <> ''                      
      BEGIN   
           
                              
         IF NOT EXISTS (SELECT 1 FROM dbo.WAVE WITH (NOLOCK) WHERE WaveKey = @cWaveKey)                      
         BEGIN                                
            SET @nErrNo = 67392                      
            SET @cErrMsg = rdt.rdtgetmessage( 67392, @cLangCode,'DSP') --Invalid Wave                      
            GOTO Step_1_Fail                               
         END                      
                         
         -- Check if Storer same as RDT login storer                      
         IF EXISTS (SELECT 1 FROM dbo.WAVEDETAIL WD WITH (NOLOCK)                       
            JOIN dbo.ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)                      
            WHERE WD.WaveKey = @cWaveKey                      
               AND O.StorerKey <> @cStorerKey)                      
         BEGIN                      
            SET @nErrNo = 67393                      
            SET @cErrMsg = rdt.rdtgetmessage( 67393, @cLangCode,'DSP') --Diff Storer                      
            GOTO Step_1_Fail                               
         END                      
                         
         -- Check if Facility same as RDT login facility                      
         IF EXISTS (SELECT 1 FROM dbo.WAVEDETAIL WD WITH (NOLOCK)                       
            JOIN dbo.ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)                      
            WHERE WD.WaveKey = @cWaveKey                      
               AND O.Facility <> @cFacility)                      
         BEGIN                      
            SET @nErrNo = 67394                      
            SET @cErrMsg = rdt.rdtgetmessage( 67394, @cLangCode,'DSP') --Diff Facility                      
            GOTO Step_1_Fail                               
         END                      
                         
         -- Check if Facility same as RDT login facility              
         IF NOT EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)                       
            WHERE WaveKey = @cWaveKey                     
               AND StorerKey = @cStorerKey                      
               AND Confirmed = 'N')                      
         BEGIN                      
            SET @nErrNo = 67395                      
            SET @cErrMsg = rdt.rdtgetmessage( 67395, @cLangCode,'DSP') --No Task                       
            GOTO Step_1_Fail                               
         END                      
                               
         SET @cLoadKey = ''                      
         GOTO STEP_CONTINUE                      
      END                      
      ELSE IF ISNULL(@cLoadKey, '') <> '' -- (ChewKP01)                      
      BEGIN                      
         IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE Loadkey = @cLoadkey)                      
         BEGIN                      
            SET @nErrNo = 67411                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Loadkey                      
            GOTO Step_1_Fail                               
         END                      
                               
            -- Check if Storer same as RDT login storer                      
         IF EXISTS (SELECT 1 FROM dbo.LoadPlanDetail LD WITH (NOLOCK)                       
                    JOIN dbo.ORDERS O WITH (NOLOCK) ON (LD.OrderKey = O.OrderKey)                      
                    WHERE LD.LoadKey = @cLoadKey                      
                      AND O.StorerKey <> @cStorerKey)                      
         BEGIN                      
            SET @nErrNo = 67412                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff Storer                      
            GOTO Step_1_Fail                               
         END                      
                         
         -- Check if Facility same as RDT login facility                      
         IF EXISTS (SELECT 1 FROM dbo.LoadPlanDetail LD WITH (NOLOCK)                       
            JOIN dbo.ORDERS O WITH (NOLOCK) ON (LD.OrderKey = O.OrderKey)                      
            WHERE LD.LoadKey = @cLoadKey                      
               AND O.Facility <> @cFacility)                      
         BEGIN                      
            SET @nErrNo = 67413                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff Facility                      
            GOTO Step_1_Fail                               
         END                      
                               
                               
         IF NOT EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)             
            WHERE LoadKey = @cLoadKey                      
               AND StorerKey = @cStorerKey                      
               AND Confirmed = 'N')                      
         BEGIN                      
            SET @nErrNo = 67414                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --No Task                       
            GOTO Step_1_Fail                               
         END                      
                               
         SET @cWaveKey = ''                      
                               
      END                      
                            
      STEP_CONTINUE:                      
                            
      SET @cOutField01 = @cWaveKey                      
      SET @cOutField02 = @cLoadKey                      
      SET @cOutField03 = ''      
      SET @cOutField04 = ''                      
                      
      -- Goto Putaway Zone Screen -- (ChewKP01)                         
      SET @nScn  = @nScnZone                      
      SET @nStep = @nStepZone                      
                      
      GOTO Quit                      
   END                      
                      
   IF @nInputKey = 0 --ESC                      
   BEGIN                      
      --go to main menu              
      SET @nFunc = @nMenu                      
      SET @nScn  = @nMenu                      
      SET @nStep = 0                      
      SET @cOutField01 = ''            
      SET @cOutField02 = ''                      
                      
      GOTO Quit                      
   END                      
                      
   Step_1_Fail:                      
   BEGIN                      
      SET @cWaveKey = ''                      
      SET @cOutField01 = ''                      
   END                   
END                      
GOTO Quit                      
                      
/********************************************************************************                      
Step 2. Scn = 2071.                       
   Wave      (field01)                      
   LoadKey   (field03)                      
   Zone      (field04)                      
   DROP ID   (field02, input)       
********************************************************************************/                      
Step_2:                      
BEGIN                      
   IF @nInputKey = 1 --ENTER                      
   BEGIN                      
      -- screen mapping                      
      SET @cDropID = @cInField02                      
      
                      
      -- Validate blank                      
      IF ISNULL(@cDropID, '') = ''                      
      BEGIN                      
         SET @nErrNo = 67396                      
         SET @cErrMsg = rdt.rdtgetmessage( 67396, @cLangCode,'DSP') --DROP ID Needed                      
         GOTO Step_2_Fail                               
      END                      
/*
      -- Prevent 2 picker using the same dropid (james07)
      IF EXISTS (SELECT 1 FROM rdt.rdtPickLock WITH (NOLOCK) 
                 WHERE DropID = @cDropID
                 AND Addwho <> @cUserName
                 AND StorerKey = @cStorerKey
                 AND LabelNo = @nFunc
                 AND Status < '9')
      BEGIN
         SET @nErrNo = 67410                      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --DROPID In Use                      
         GOTO Step_2_Fail    
      END
*/      
      -- Check if dropid exists, if exists goto screen 7 else goto next screen                      
      IF ISNULL(RTRIM(@cWaveKey),'') <> ''                      
      BEGIN                      
         IF EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)                       
            WHERE WaveKey = @cWaveKey                      
               AND DropID = @cDropID)                      
         BEGIN                      
            SET @cOutField01 = ''   -- (james04)                
                            
      -- Go to drop id exists screen                      
            SET @nScn  = @nScn + 5            
            SET @nStep = @nStep + 5                      
                         
            GOTO Quit                      
         END                      
      END                      
      ELSE                
      --IF ISNULL(RTRIM(@cLoadKey),'') <> ''      (james04)                
      BEGIN                      
         IF EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)                       
         WHERE LoadKey = @cLoadkey      -- (ChewKP02)                
               AND DropID = @cDropID)                      
         BEGIN                      
            -- Go to drop id exists screen                      
            SET @nScn  = @nScn + 5                      
            SET @nStep = @nStep + 5                      
                         
            GOTO Quit                      
         END                      
      END                      
      -- (ChewKP01) -- Get Loc                       
      
      -- SHONG001      
      -- Clean the RDT.RDTPickLock table, make sure release all the locked task      
      -- for current user      
      DELETE RDT.RDTPickLock       
      WHERE  AddWho = @cUserName      
                            
      IF ISNULL(RTRIM(@cWaveKey),'') <> ''                      
      BEGIN                      
         SET @cSuggLOC = ''      
      
         SELECT TOP 1                   
                @cSuggLOC = RPL.FROMLOC                      
         FROM dbo.Replenishment RPL WITH (NOLOCK)                       
         JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)                      
         JOIN dbo.LOC Loc WITH (NOLOCK) ON (RPL.FromLOC = LOC.Loc)                      
         WHERE RPL.StorerKey = @cStorerKey                      
            AND RPL.WaveKey = @cWaveKey                      
            AND Loc.PutawayZone = @cPutawayZone                      
            AND RPL.Confirmed = 'N'                      
            AND RPL.QTY > 0                      
            AND RPL.FROMLOC >= @cStartLoc       
            AND NOT EXISTS (  -- not being locked by other picker                      
                  SELECT 1 FROM RDT.RDTPickLock RL WITH (NOLOCK)                  
                  WHERE RPL.StorerKey = RL.StorerKey                      
                        AND RPL.WaveKey = RL.WaveKey                      
                        AND RPL.FROMLOC = RL.LOC                       
                        --AND RL.AddWho <> @cUserName -- (ChewKP06)                     
                        AND Status < '9')                      
         --GROUP BY Loc.LogicalLocation, RPL.ReplenishmentKey, LOT, RPL.ID, RPL.FROMLOC, RPL.SKU, S.Style, S.Color, S.Measurement, S.Size                      
         --ORDER BY Loc.LogicalLocation, S.Style, S.Color, S.Measurement, S.Size, RPL.SKU                   
         ORDER BY Loc.LogicalLocation, RPL.FromLoc       
                        
         --      IF @@RowCount = 0      (james03) cannot use rowcount here                
         IF ISNULL(@cSuggLOC, '') = ''                
         BEGIN                      
            SET @nErrNo = 67424                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Replen                      
            GOTO Step_2_Fail                          
         END                   
      END                      
      ELSE                            
      --IF ISNULL(RTRIM(@cLoadKey),'') <> ''      (james04)                
      BEGIN                      
         SELECT TOP 1                       
                @cSuggLOC = RPL.FROMLOC                      
         FROM dbo.Replenishment RPL WITH (NOLOCK)                       
         JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)                      
         JOIN dbo.LOC Loc WITH (NOLOCK) ON (RPL.FromLOC = LOC.Loc)                      
         WHERE RPL.StorerKey = @cStorerKey                      
            AND RPL.LoadKey = @cLoadKey                      
            AND Loc.PutawayZone = @cPutawayZone                      
            AND RPL.Confirmed = 'N'                      
            AND RPL.QTY > 0       
            AND RPL.FROMLOC >= @cStartLoc                      
            AND NOT EXISTS (  -- not being locked by other picker                      
                  SELECT 1 FROM RDT.RDTPickLock RL WITH (NOLOCK)                       
                     WHERE RPL.StorerKey = RL.StorerKey                      
                        AND RPL.LoadKey = RL.LoadKey                      
                        AND RPL.FROMLOC = RL.LOC                      
                        --AND RL.AddWho <> @cUserName -- (ChewKP06)                                
                        AND Status < '9')                      
         --GROUP BY Loc.LogicalLocation, RPL.ReplenishmentKey, LOT, RPL.ID, RPL.FROMLOC, RPL.SKU, S.Style, S.Color, S.Measurement, S.Size                      
         --ORDER BY Loc.LogicalLocation, S.Style, S.Color, S.Measurement, S.Size, RPL.SKU                      
         ORDER BY Loc.LogicalLocation, RPL.FromLoc        
                      
         IF @@RowCount = 0                      
         BEGIN                      
            SET @nErrNo = 67430                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Replen                      
            GOTO Step_2_Fail                          
         END                          
      END                      
            
      -- (ChewKP06)                
      -- Start locking picker's wave+loc                      
      INSERT INTO RDT.RDTPickLock                        
      (WaveKey, LoadKey, OrderKey, OrderLineNumber, Putawayzone, PickZone, StorerKey, LOC, LOT, DropID, Status, AddWho, AddDate, PickdetailKey, SKU, ID, PickQty, LabelNo)                        
      VALUES                        
      (@cWaveKey, @cLoadKey, '', '*', '', '', @cStorerKey, @cSuggLOC, '', @cDropID, '3', @cUserName, GETDATE(), '', '', '', '', @nFunc)                        
                      
      IF @@ERROR <> 0                      
      BEGIN                      
         SET @nErrNo = 67421                      
         SET @cErrMsg = rdt.rdtgetmessage( 67421, @cLangCode,'DSP') --INS PLOCK Fail                      
         GOTO Step_3_Fail                               
      END                      
      
      -- Check whether another user get the same location or not?      
      IF EXISTS(SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)       
                WHERE WaveKey = @cWaveKey       
                  AND LoadKey = @cLoadKey       
                  AND StorerKey = @cStorerKey       
                  AND LOC       = @cSuggLOC       
                  AND AddWho    <> @cUserName       
                  AND [Status]  = '3')      
      BEGIN      
         --ROLLBACK TRAN                      
         --SET @nErrNo = 67421                      
         --SET @cErrMsg = rdt.rdtgetmessage( 67421, @cLangCode,'DSP') --INS PLOCK Fail                      
         --GOTO Step_3_Fail             
         SET @nScn  = @nScnLocationLock                      
         SET @nStep = @nStepLocationLock       
         GOTO Quit                                  
      END                   
                      
      SET @cOutField01 = @cWaveKey                      
      SET @cOutField02 = @cDropID                      
      SET @cOutField03 = ''                      
      SET @cOutField04 = @cLoadKey       -- (ChewKP01)                      
      SET @cOutField05 = @cPutawayZone   -- (ChewKP01)                      
      SET @cOutField06 = @cSuggLOC       -- (ChewKP01)                      
                      
      --goto next screen                      
      SET @nScn  = @nScn + 1                      
      SET @nStep = @nStep + 1                      
                    
      GOTO Quit              
   END                      
                      
   IF @nInputKey = 0 --ESC                      
   BEGIN                      
      --Release from locked                      
      --DELETE FROM RDT.RDTPickLock WHERE AddWho = @cUserName AND Status < '9'                      
                      
      --go to screen 1                      
      --SET @cWaveKey = ''                      
      SET @cOutField01 = @cWaveKey                      
      SET @cOutField02 = @cLoadKey                      
      SET @cOutField03 = ''        
      SET @cOutField04 = ''                     
                      
      --goto next screen                      
      --SET @nScn  = @nScn - 1                      
      --SET @nStep = @nStep - 1                      
                            
      SET @nScn  = @nScnZone                      
      SET @nStep = @nStepZone                      
                      
      GOTO Quit                      
   END                      
                      
   Step_2_Fail:                      
   BEGIN                      
      SET @cDropID = ''                      
      SET @cOutField02 = ''                      
   END                      
END                      
GOTO Quit                      
                      
/********************************************************************************                      
Step 3. Scn = 2072.                       
   Wave     (field01)                      
   LoadKey  (Field04)                      
   Zone     (Field05)                      
   DROP ID  (field02)                      
   LOC      (field06)                      
   LOC      (field03, input)                      
********************************************************************************/                      
Step_3:             
BEGIN                      
   IF @nInputKey = 1 --ENTER                      
   BEGIN                      
      --screen mapping                      
      SET @cLOC = @cInField03                      
                      
      -- Validate blank                      
      IF ISNULL(@cLOC, '') = ''                      
      BEGIN                      
         SET @nErrNo = 67397                      
         SET @cErrMsg = rdt.rdtgetmessage( 67397, @cLangCode,'DSP') --LOC Needed                      
         GOTO Step_3_Fail                               
      END                      
                      
      --check whether the loc is a valid loc                      
      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC)                      
      BEGIN                      
         SET @nErrNo = 67398                      
         SET @cErrMsg = rdt.rdtgetmessage( 67398, @cLangCode,'DSP') --Invalid LOC                      
         GOTO Step_3_Fail                               
      END                      
                      
      --check if loc is within the RDT login facility                      
      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)                       
                     WHERE LOC = @cLOC                      
                       AND Facility = @cFacility)                      
      BEGIN                      
         SET @nErrNo = 67399                      
         SET @cErrMsg = rdt.rdtgetmessage( 67399, @cLangCode,'DSP') --Diff Facility                      
         GOTO Step_3_Fail                               
      END                      
        
      IF ISNULL(@cSuggLOC,'') <> ISNULL(@cLOC,'')                      
      BEGIN                      
         SET @nErrNo = 67425                      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid LOC                      
         GOTO Step_3_Fail                               
      END                      
                  
      -- (ChewKP05)            
      SET @cReplenToByBatch = ''            
      SET @cReplenToByBatch = rdt.RDTGetConfig( @nFunc, 'ReplenToByBatch', @cStorerKey)                 
             
      IF ISNULL(RTRIM(@cWaveKey),'') <> ''                      
      BEGIN                      
         --check if the loc exists in current replenishment process                      
         IF NOT EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)                       
            WHERE StorerKey = @cStorerKey                      
               AND WaveKey = @cWaveKey                      
               AND FROMLOC = @cLOC)                      
         BEGIN                      
            SET @nErrNo = 67400                      
            SET @cErrMsg = rdt.rdtgetmessage( 67400, @cLangCode,'DSP') --LOC NOT IN RPL                      
            GOTO Step_3_Fail               
         END                      
                         
         --check if any outstanding task in currect loc                      
         IF NOT EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)                       
            WHERE StorerKey = @cStorerKey                      
               AND WaveKey = @cWaveKey                      
               AND FROMLOC = @cLOC                      
               AND Confirmed = 'N')                      
         BEGIN                      
            SET @nErrNo = 67401                      
            SET @cErrMsg = rdt.rdtgetmessage( 67401, @cLangCode,'DSP') --No Task In LOC                      
            GOTO Step_3_Fail                 
         END                      
                               
         --check if same wave+loc is being locked by other picker (1 wave+loc = 1 picker)                      
         IF EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)                       
            WHERE StorerKey = @cStorerKey                      
               AND WaveKey = @cWaveKey                      
               AND LOC = @cLOC                      
               AND AddWho <> @cUserName                      
               AND Status < '9')                      
         BEGIN                      
--            SET @nErrNo = 67402                      
--            SET @cErrMsg = rdt.rdtgetmessage( 67402, @cLangCode,'DSP') --LOC Locked                      
--            GOTO Step_3_Fail                               
              SET @nScn  = @nScnLocationLock                      
              SET @nStep = @nStepLocationLock       
              GOTO Quit       
         END                      
          
         -- SHONG001      
         SET @cReplenishmentKey = ''      
      
         SELECT TOP 1                       
             @cReplenishmentKey = RPL.ReplenishmentKey,                      
             @cLOT = RPL.LOT,                       
             @cID = RPL.ID,                       
             @cTOLOC = RPL.TOLOC,                       
             @cSKU = RPL.SKU,                       
             @cStyle = S.Style,                      
             @cColor = S.Color,                       
             @cMeasurement = S.Measurement,                       
             @cSize = S.Size,                        
             @nSuggestedQTY = RPL.Qty       
         FROM dbo.Replenishment RPL WITH (NOLOCK)                       
         JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)                      
         JOIN dbo.Loc LOC WITH (NOLOCK) ON (LOC.LOC = RPL.TOLOC)                      
         WHERE RPL.StorerKey = @cStorerKey                      
            AND RPL.WaveKey = @cWaveKey                      
            AND RPL.FROMLOC = @cLOC                      
            AND RPL.Confirmed = 'N'                      
            AND RPL.QTY > 0                      
         --GROUP BY Loc.LogicalLocation,RPL.ReplenishmentKey, LOT, RPL.ID, RPL.TOLOC, RPL.SKU, S.Style, S.Color, S.Measurement, S.Size                      
         ORDER BY Loc.LogicalLocation,S.Style, S.Color, S.Measurement, S.Size, RPL.SKU              
                   
         IF ISNULL(@cReplenishmentKey ,'') <> '' -- (ChewKP06)      
       BEGIN      
            IF @cReplenToByBatch = '1'            
            BEGIN            
               -- Get TotalQty from Other Wave with Same SKU, Loc, Lot, ID                      
               SET @nReplenQTY = 0           
               SELECT                        
                   @nReplenQTY = ISNULL(SUM(RPL.Qty), 0)          
               FROM dbo.Replenishment RPL WITH (NOLOCK)                       
               WHERE RPL.StorerKey = @cStorerKey      
                  AND RPL.SKU = @cSKU      
                  AND RPL.Lot = @cLot                          
                  AND RPL.FROMLOC = @cLOC       
                  AND RPL.ID = @cID -- SHONG001                       
                  AND RPL.Confirmed = 'N'                      
                  AND RPL.QTY > 0                      
                  AND RPL.ReplenishmentKey <> @cReplenishmentKey -- SHONG001      
                  --AND RPL.WaveKey <> @cWaveKey               
                         
               IF @nReplenQty > 0          
               BEGIN          
                  SET @nSuggestedQTY = @nSuggestedQTY + @nReplenQty          
               END          
            END          
         END      
         ELSE      
         BEGIN      
            SET @nErrNo = 67433                      
            SET @cErrMsg = rdt.rdtgetmessage( 67433, @cLangCode,'DSP') --INV Replen                     
            GOTO Step_3_Fail       
         END      
           
--         BEGIN TRAN                      
--         --confirm picklock                      
--         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET                       
--           Status = '9'                      
--         WHERE StorerKey = @cStorerKey                      
--            AND WaveKey = @cWaveKey                      
--            AND LOC = @cLOC                      
--            AND DropID = @cDropID                      
--            AND AddWho = @cUserName                      
--            AND Status = '3'                  
--                   
--         -- Start locking picker's wave+loc                      
--         INSERT INTO RDT.RDTPickLock                        
--         (WaveKey, LoadKey, OrderKey, OrderLineNumber, Putawayzone, PickZone, StorerKey, LOC, LOT, DropID, Status, AddWho, AddDate, PickdetailKey, SKU, ID, PickQty)                        
--         VALUES                        
--         (@cWaveKey, '', '', '*', '', '', @cStorerKey, @cLOC, @cLOT, @cDropID, '1', @cUserName, GETDATE(), @cReplenishmentKey, @cSKU, @cID, @nSuggestedQTY)                        
--                         
--         IF @@ERROR <> 0                      
--         BEGIN                      
--            ROLLBACK TRAN                      
--                         
--            SET @nErrNo = 67421                      
--            SET @cErrMsg = rdt.rdtgetmessage( 67403, @cLangCode,'DSP') --INS PLOCK Fail                      
--            GOTO Step_3_Fail                               
--         END                      
--         COMMIT TRAN                              
                   
      END                      
      ELSE                
      --IF ISNULL(RTRIM(@cLoadKey),'') <> ''      (james04)                
      BEGIN                      
         --check if the loc exists in current replenishment process                      
         IF NOT EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)                       
            WHERE StorerKey = @cStorerKey               
               AND Loadkey = @cLoadKey                
               AND FROMLOC = @cLOC)                      
         BEGIN                      
            SET @nErrNo = 67418                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LOC NOT IN RPL                      
            GOTO Step_3_Fail                               
         END                      
                               
         --check if any outstanding task in currect loc                      
         IF NOT EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)                       
            WHERE StorerKey = @cStorerKey                      
               AND Loadkey = @cLoadKey                      
               AND FROMLOC = @cLOC                      
               AND Confirmed = 'N')                      
         BEGIN                      
            SET @nErrNo = 67419                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --No Task In LOC                      
            GOTO Step_3_Fail                               
         END                      
          
         --check if same wave+loc is being locked by other picker (1 wave+loc = 1 picker)                      
         IF EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)                       
            WHERE StorerKey = @cStorerKey                      
               AND Loadkey = @cLoadKey                      
               AND LOC = @cLOC               
               AND AddWho <> @cUserName                      
               AND Status < '9')                      
         BEGIN                      
            SET @nErrNo = 67420                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LOC Locked                      
            GOTO Step_3_Fail                               
         END                                 
                     
         SELECT TOP 1                       
                @cReplenishmentKey = RPL.ReplenishmentKey,                      
                @cLOT = RPL.LOT,                      
                @cLOT = RPL.LOT,                       
                @cID = RPL.ID,                       
                @cTOLOC = RPL.TOLOC,                   
                @cSKU = RPL.SKU,                       
                @cStyle = S.Style,                      
                @cColor = S.Color,                       
                @cMeasurement = S.Measurement,                       
                @cSize = S.Size,                        
                @nSuggestedQTY = RPL.Qty                      
         FROM dbo.Replenishment RPL WITH (NOLOCK)                     
         JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)                      
         JOIN dbo.Loc LOC WITH (NOLOCK) ON (LOC.LOC = RPL.TOLOC)                      
         WHERE RPL.StorerKey = @cStorerKey                      
            AND RPL.Loadkey = @cLoadKey                      
            AND RPL.FROMLOC = @cLOC                      
            AND RPL.Confirmed = 'N'                      
            AND RPL.QTY > 0                      
         -- GROUP BY Loc.LogicalLocation,RPL.ReplenishmentKey, LOT, RPL.ID, RPL.TOLOC, RPL.SKU, S.Style, S.Color, S.Measurement, S.Size                      
         ORDER BY Loc.LogicalLocation,S.Style, S.Color, S.Measurement, S.Size, RPL.SKU               
                   
         IF ISNULL(@cReplenishmentKey ,'') <> ''  -- (ChewKP06)      
         BEGIN       
            IF @cReplenToByBatch = '1'            
            BEGIN            
               -- Get TotalQty from Other Wave with Same SKU, Loc, Lot, ID                      
               SET @nReplenQTY = 0           
               SELECT                        
                   @nReplenQTY = ISNULL(SUM(RPL.Qty), 0)          
               FROM dbo.Replenishment RPL WITH (NOLOCK)                       
               WHERE RPL.StorerKey = @cStorerKey                      
                  AND RPL.FROMLOC = @cLOC                      
                  AND RPL.Confirmed = 'N'                      
                  AND RPL.QTY > 0                      
                  --AND RPL.LoadKey <> @cLoadKey       
                  AND RPL.ReplenishmentKey <> @cReplenishmentKey -- SHONG001      
                  AND RPL.SKU = @cSKU          
                  AND RPL.Lot = @cLot      
                  AND RPL.ID = @cID         
                         
               IF @nReplenQty > 0          
               BEGIN          
                  SET @nSuggestedQTY = @nSuggestedQTY + @nReplenQty          
               END          
            END      
         END        
         ELSE      
         BEGIN      
            SET @nErrNo = 67434                   
            SET @cErrMsg = rdt.rdtgetmessage( 67434, @cLangCode,'DSP') --INV Replen                     
            GOTO Step_3_Fail       
         END          
--         BEGIN TRAN        
--      
--         --confirm picklock                      
--         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET                       
--            Status = '9'                      
--         WHERE StorerKey = @cStorerKey                      
--            AND LoadKey = @cLoadKey                      
--            AND LOC = @cLOC                      
--            AND DropID = @cDropID                      
--            AND AddWho = @cUserName                      
--            AND Status = '3'                      
--                            
--         -- Start locking picker's wave+loc                      
--         INSERT INTO RDT.RDTPickLock                        
--         (WaveKey, LoadKey, OrderKey, OrderLineNumber, Putawayzone, PickZone, StorerKey, LOC, LOT, DropID, Status, AddWho, AddDate, PickdetailKey, SKU, ID, PickQty)                        
--         VALUES                        
--         ('', @cLoadKey, '', '*', '', '', @cStorerKey, @cLOC, @cLOT, @cDropID, '1', @cUserName, GETDATE(), @cReplenishmentKey, @cSKU, @cID, @nSuggestedQTY)                        
--                         
--         IF @@ERROR <> 0                      
--         BEGIN                      
--            ROLLBACK TRAN                      
--                         
--            SET @nErrNo = 67421                      
--            SET @cErrMsg = rdt.rdtgetmessage( 67403, @cLangCode,'DSP') --INS PLOCK Fail                      
--            GOTO Step_3_Fail                               
--         END                      
--                         
--         COMMIT TRAN                      
      END -- LoadKey                      
            
      -- james05            
      SET @cColorField = ''            
      SELECT @cColorField = ISNULL(SValue, '') FROM dbo.StorerConfig WITH (NOLOCK)                      
      WHERE StorerKey = @cStorerKey                      
         AND ConfigKey = 'COLORDESCRFIELD'                      
                                  
      IF ISNULL(@cColorField, '') <> ''                      
      BEGIN                      
         SET @c_ExecStatements = ''                      
         SET @c_ExecArguments = ''                      
         SET @c_ExecStatements = N'SELECT @cColorDescr = ' + @cColorField                      
                                 + ' FROM dbo.SKU WITH (NOLOCK) '                      
                                 + ' WHERE Storerkey = @cStorerkey '                      
                                 + ' AND SKU = @cSKU '                      
                                 
         SET @c_ExecArguments = N' @cStorerkey NVARCHAR( 15), '                      
                              + '@cSKU          NVARCHAR( 20), '                      
                              + '@cColorField   NVARCHAR( 10), '                  
                              + '@cColorDescr   NVARCHAR( 20) OUTPUT '                      
                      
         EXEC sp_executesql @c_ExecStatements,                      
                            @c_ExecArguments,                      
                            @cStorerkey,                      
                            @cSKU,                      
                            @cColorField,                      
                            @cColorDescr OUTPUT                      
      END                      
                      
      SET @nOutstandingQty = @nSuggestedQTY                      
                      
      SET @cOutField01 = @cDropID                      
      SET @cOutField02 = @cLOC                      
      SET @cOutField03 = @cID                        SET @cOutField04 = CASE WHEN ISNULL(@cReplenInProgressLOC, '') <> '' THEN @cReplenInProgressLOC ELSE @cTOLOC END                      
      SET @cOutField05 = @cSKU                      
      SET @cOutField06 = @cStyle                   
      SET @cOutField07 = RIGHT(REPLICATE(' ', 10 - LEN(@cColor)) + @cColor, 10)                       
                        + LEFT(REPLICATE(' ', 5 - LEN(@cMeasurement)) + @cMeasurement, 5)                       
                   + LEFT(REPLICATE(' ', 5 - LEN(@cSize)) + @cSize, 5)                      
      SET @cOutField08 = @cColorDescr                      
--      SET @cOutField09 = 'S/O QTY:'                       
--                        + LEFT(REPLICATE(' ', 5 - LEN(@nSuggestedQTY)) + CAST(@nSuggestedQTY AS NVARCHAR(5)), 5)                      
--                        + '/'                      
--                        + RIGHT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + CAST(@nOutstandingQty AS NVARCHAR(5)), 5)                      
      SET @cOutField09 = 'O/S QTY:' + LEFT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + RTRIM(CAST(@nOutstandingQty AS NVARCHAR(5))), 5) + '/' + CAST(@nSuggestedQTY AS NVARCHAR(5))                     
      SET @cOutField10 = ''   --UCC/SKU                      
      SET @cOutField11 = CASE WHEN ISNULL(@cDefaultQty, '') = '' THEN '' ELSE @cDefaultQty END --QTY                      
                      
      SET @nQTY = 0  --reset the qty for new replenishment task                      
                      
      EXEC rdt.rdtSetFocusField @nMobile, 10                      
                   
      --goto next screen                      
      SET @nScn  = @nScn + 1                      
      SET @nStep = @nStep + 1                      
                      
      GOTO Quit                      
   END                      
                      
   IF @nInputKey = 0 --ESC                      
   BEGIN                      
      --go to screen 2                      
      SET @cDropID = ''                      
                      
      SET @cOutField01 = @cWaveKey                      
      SET @cOutField02 = ''                      
      SET @cOutField03 = @cLoadKey                      
      SET @cOutField04 = @cPutawayZone                       
                      
      --goto next screen                      
      SET @nScn  = @nScn - 1                      
      SET @nStep = @nStep - 1                      
      GOTO Quit                      
   END                      
                      
   Step_3_Fail:                      
   BEGIN                      
      SET @cLOC = ''                      
      SET @cOutField03 = ''                      
   END                      
END                      
GOTO Quit                      
                      
/********************************************************************************                      
Step 4. Scn = 2073.                       
   DROP ID  (field01)                      
   LOC      (field02)                      
   ID       (field03)                      
   ...                      
   UCC/SKU  (field10, input)                      
   QTY      (field11, input)                      
********************************************************************************/                      
Step_4:                      
BEGIN                      
   IF @nInputKey = 1 --ENTER                      
   BEGIN                      
      --screen mapping                      
      SET @cUCC_SKU = @cInField10                      
      SET @cActQty = @cInField11                      
                      
      -- Validate blank                      
      IF ISNULL(@cUCC_SKU, '') = ''                      
      BEGIN                      
         SET @nErrNo = 67404                      
         SET @cErrMsg = rdt.rdtgetmessage( 67404, @cLangCode,'DSP') --UCC/SKU Needed                   
         SET @cOutField10 = ''                      
         SET @cUCC_SKU = ''                      
         EXEC rdt.rdtSetFocusField @nMobile, 10                      
         GOTO Quit                               
      END                      
                      
      --if cannot find the ucc then look in sku table                      
      IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)                       
                     WHERE StorerKey = @cStorerKey                       
                     AND UCCNo = @cUCC_SKU)                      
      BEGIN                      
         EXEC [RDT].[rdt_GETSKUCNT]                        
                        @cStorerKey  = @cStorerKey                        
         ,              @cSKU        = @cUCC_SKU                         
         ,              @nSKUCnt     = @nSKUCnt       OUTPUT                        
         ,              @bSuccess    = @b_Success     OUTPUT                        
         ,              @nErr        = @n_Err         OUTPUT                        
         ,              @cErrMsg     = @c_ErrMsg      OUTPUT                        
                                 
         -- Validate SKU/UPC                        
         IF @nSKUCnt = 0                        
         BEGIN                        
            INSERT INTO TRACEINFO (TRACENAME, TIMEIN, step1,  COL1, COL2, COL3)            
            VALUES ('RDT_REPLEN_FROM_SKU1', GETDATE(), @nMobile, @cStorerKey, @cUCC_SKU, @nSKUCnt)      
            
            SET @nErrNo = 67405                        
            SET @cErrMsg = rdt.rdtgetmessage( 67405, @cLangCode, 'DSP') --'Invalid SKU'                  
            SET @cOutField10 = ''                        
            SET @cUCC_SKU = ''                      
            EXEC rdt.rdtSetFocusField @nMobile, 10                      
            GOTO Quit                        
         END                        
                        
         -- Validate barcode return multiple SKU                        
         IF @nSKUCnt > 1                        
         BEGIN                        
            SET @nErrNo = 67406                        
            SET @cErrMsg = rdt.rdtgetmessage( 67406, @cLangCode, 'DSP') --'SameBarCodeSKU'                        
            SET @cOutField10 = ''                        
            SET @cUCC_SKU = ''                      
            EXEC rdt.rdtSetFocusField @nMobile, 10                      
            GOTO Quit                        
         END                        
                        
         EXEC [RDT].[rdt_GETSKU]                        
                        @cStorerKey  = @cStorerKey                        
         ,              @cSKU        = @cUCC_SKU      OUTPUT                        
         ,              @bSuccess    = @b_Success     OUTPUT                        
         ,              @nErr        = @n_Err         OUTPUT                        
         ,              @cErrMsg     = @c_ErrMsg      OUTPUT                
                     
         -- (james05)            
         -- Reselect SKU again because if scan UCC previously, the @cSKU will be reset to blank to cater for UCC            
         -- If got error and user rescan again using SKU the @cSKU will be blank. Refer below            
         --BEGIN                      
         -- SET @cUCC = @cUCC_SKU                      
         -- SET @cSKU = ''                      
         -- SET @nQty = 0                      
         --END             
                      
         IF ISNULL(@cSKU, '') = ''            
         BEGIN            
            SELECT @cSKU = SKU FROM dbo.Replenishment WITH (NOLOCK) WHERE ReplenishmentKey = @cReplenishmentKey            
         END                    
                      
         IF @cUCC_SKU <> @cSKU                        
         BEGIN                        
            INSERT INTO TRACEINFO (TRACENAME, TIMEIN, step1, COL1, COL2, COL3)    
            VALUES ('RDT_REPLEN_FROM_SKU2', GETDATE(), @nMobile, @cStorerKey, @cUCC_SKU, @cSKU)      
            
            SET @nErrNo = 67407                        
            SET @cErrMsg = rdt.rdtgetmessage( 67407, @cLangCode, 'DSP') --'Different SKU'                        
            SET @cOutField10 = ''                        
            SET @cUCC_SKU = ''                      
            EXEC rdt.rdtSetFocusField @nMobile, 10                      
            GOTO Quit                        
         END           

         -- (james07)
         IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC AND LocationCategory IN ('GOH', 'SHELVING'))
         BEGIN
            -- (ChewKP11)    
            IF EXISTS (SELECT 1 from dbo.UCC WITH (NOLOCK)    
                       WHERE SKU       = @cSKU    
                       AND   StorerKey = @cStorerKey    
                       AND   Loc       = @cLOC     
                       AND   Status    = '1')    
            BEGIN    
               SET @nErrNo = 67436                        
               SET @cErrMsg = rdt.rdtgetmessage( 67436, @cLangCode, 'DSP') --'PLS Scan UCC'                        
               SET @cOutField10 = ''                        
               SET @cUCC_SKU = ''                      
               EXEC rdt.rdtSetFocusField @nMobile, 10                      
               GOTO Quit     
            END       
         END
                      
         --set sku flag, means picker scan in sku                      
         SET @cUCCFlag = 'N'                      
         SET @cSKUFlag = 'Y'       
      END -- If not exists in sku table         
      ELSE --set ucc flag, means picker scan in ucc                      
      BEGIN                      
         IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)       
                        WHERE StorerKey = @cStorerKey                    
                        AND UCCNo = @cUCC_SKU      
                        AND Status < '4')      
         BEGIN                      
            SET @nErrNo = 67435                      
            SET @cErrMsg = rdt.rdtgetmessage( 67435, @cLangCode,'DSP') --Invalid UCC                     
            SET @cOutField10 = ''                      
            SET @cUCC_SKU = ''                      
            EXEC rdt.rdtSetFocusField @nMobile, 10                      
            GOTO Quit                               
         END          
               
         SET @cUCCFlag = 'Y'                      
         SET @cSKUFlag = 'N'                    
                      
         --if ucc contain > 1 distinct sku then it is a mixed sku carton                      
         IF EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)                       
                    WHERE StorerKey = @cStorerKey                      
                      AND UCCNo = @cUCC_SKU                      
                    GROUP BY UCCNo                      
                    HAVING COUNT(DISTINCT SKU) > 1)                      
            SET @cUCCMixedSKUFlag = 'Y'                      
         ELSE                      
            SET @cUCCMixedSKUFlag = 'N'          
               
      END                      
                     
      --no need to consider qty field if scan in ucc                   
      IF @cUCCFlag = 'N'                      
      BEGIN         
         IF @cActQty  = ''             
            SET @cActQty  = '0' --'Blank taken as zero'        
                                      
         IF @cActQty = '0'                        
         BEGIN                        
            SET @nErrNo = 67408                        
            SET @cErrMsg = rdt.rdtgetmessage( 67408, @cLangCode, 'DSP') --'QTY needed'                        
            SET @cOutField11 = ''                      
            SET @cActQty = ''                        
            EXEC rdt.rdtSetFocusField @nMobile, 11                      
            GOTO Quit                        
         END                        
            
         IF RDT.rdtIsValidQTY( @cActQty, 0) = 0                        
         BEGIN                        
            SET @nErrNo = 67409                        
            SET @cErrMsg = rdt.rdtgetmessage( 67409, @cLangCode, 'DSP') --'Invalid QTY'                        
            SET @cOutField11 = ''                      
            SET @cActQty = ''                        
            EXEC rdt.rdtSetFocusField @nMobile, 11                        
            GOTO Quit                        
         END                        
                 
         -- (ChewKP03)                
         SET @cAllowOverReplen = ''                
         SET @cAllowOverReplen = rdt.RDTGetConfig( @nFunc, 'AllowOverReplen', @cStorerKey)                     
                         
         IF @cAllowOverReplen <> '1'                
         BEGIN                
            IF (CAST(@cActQty AS INT) + @nQTY) > @nSuggestedQTY                      
            BEGIN                      
               SET @nErrNo = 67426                        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Qty Exceed'                        
               SET @cOutField11 = ''                      
               SET @cActQty = ''                                       
               EXEC rdt.rdtSetFocusField @nMobile, 11                        
               GOTO Quit                                                      
            END                      
         END                
                         
         SET @nQTY = @nQTY + CAST(@cActQty AS INT)                      
         SET @nOutstandingQty = @nOutstandingQty - CAST(@cActQty AS INT)                      
      END -- IF @cUCCFlag = 'N'                     
                      
      IF @cUCCFlag = 'N'                       
      BEGIN                      
       SET @cUCC = ''                  
      END                      
      ELSE               
      BEGIN                      
         SET @cUCC = @cUCC_SKU                      
         SET @cOutField05 = @cSKU   -- (james06)      
--         SET @cSKU = ''                      
         --SET @nQty = 0   -- (ChewKP07)      
      END      
                            
      -- If Scanned Code is UCC No                  
      INSERT INTO TRACEINFO (TraceName , TimeIN , Step1 , Step2)                      
      VAlues ( 'ReplenFrom1', Getdate(), @nQty,@cDropID)         
                    
      IF @cUCCFlag = 'Y' -- By SHONG 15th Dec 2011            
      BEGIN            
         -- Validate UCC SKU Scan & Replen SKU is match -- (ChewKP04)              
         SET @cUCCSKU = ''              
     
         SELECT @cUCCSKU = SKU,              
              @nUCCQty = Qty                
         FROM dbo.UCC WITH (NOLOCK)              
         WHERE UCCNo = @cUCC              
         AND StorerKey = @cStorerKey              
                        
         IF NOT EXISTS ( SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)              
                          WHERE ReplenishmentKey = @cReplenishmentKey              
                          AND SKU = @cUCCSKU )               
         BEGIN              
            SET @nErrNo = 67431                      
            SET @cErrMsg = rdt.rdtgetmessage( 67431, @cLangCode,'DSP') --Invalid UCC                 
            SET @cOutField10 = ''                      
--            SET @cSKU = @cUCC_SKU      -- (james06)      
            SET @cUCC_SKU = ''                      
            EXEC rdt.rdtSetFocusField @nMobile, 10                      
            GOTO Quit                 
         END      
                  
         -- Validate Have Enough Qty to Move -- (ChewKP04)       
         -- SHONG001       
         IF NOT EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)             
                        WHERE Loc = @cLOC             
                          AND Lot = @cLOT       
                          AND ID  = @cID      
                          AND (QTY - QTYALLOCATED - QTYPICKED) >= @nQTY + CAST(@nUCCQty AS INT)  )          
                       --GROUP BY StorerKey, SKU, Loc              
                 --HAVING (SUM(QTY) - SUM(QTYALLOCATED) - SUM(QTYPICKED)) >= @nUCCQty )              
         BEGIN              
            SET @nErrNo = 67432                      
            SET @cErrMsg = rdt.rdtgetmessage( 67432, @cLangCode,'DSP') --Invalid UCCQty                
            SET @cOutField10 = ''                      
--            SET @cSKU = @cUCC_SKU      -- (james06)      
            SET @cUCC_SKU = ''                      
            SET @cOutField11 = ''                      
            EXEC rdt.rdtSetFocusField @nMobile, 10              
            GOTO Quit               
         END      
                    
         SET @nQTY = @nQTY + CAST(@nUCCQty AS INT)          
      
         -- SHONG001      
         IF @nOutstandingQty > CAST(@nUCCQty AS INT)       
            SET @nOutstandingQty = @nOutstandingQty - CAST(@nUCCQty AS INT)      
         ELSE      
          SET @nOutstandingQty = 0       
      
         -- (ChewKP09)       
         -- Update UCC Status, do not allow to scan same UCC again      
         UPDATE dbo.UCC WITH (ROWLOCK)       
         SET         
             --ID = @cDropID,         
             Status = '4', -- (ChewKP10)      
             SourceType = 'fnc_Wave_Replen_From',         
             LOC = @cLOC,         
             EditDate = GETDATE(),         
             EditWho = 'rdt.' + sUSER_sNAME(),       
             WaveKey = @cWaveKey      
         WHERE UCCNo = @cUCC        
                            
      END -- IF @cUCCFlag = 'Y'                         
                 
      --IF @nQTY < @nOutstandingQty        
      --IF (@nOutstandingQty - @nUCCQty) > 0 -- (ChewKP08)      
      IF @nOutstandingQty > 0 -- (SHONG001)      
      BEGIN        
         INSERT TRACEINFO (TraceName, TimeIN, Step1 , Col1, Col2, Col3)      
         VALUES ('MULTIUCC', Getdate(), 'S1', @cReplenishmentKey, @nQty, @nOutstandingQty )      
                                            
         --SET @nOutstandingQty = @nOutstandingQty - CAST(@nUCCQty AS INT)            
         IF ISNULL(@cSKU, '') = ''  --(james06)      
         BEGIN            
            SELECT @cOutField05 = SKU FROM dbo.Replenishment WITH (NOLOCK) WHERE ReplenishmentKey = @cReplenishmentKey            
         END                  
               
         SET @cOutField09 = 'O/S QTY:' + LEFT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + RTRIM(CAST(@nOutstandingQty AS NVARCHAR(5))), 5) + '/' + CAST(@nSuggestedQTY AS NVARCHAR(5))                     
         SET @cOutField10 = ''   --UCC/SKU                      
         SET @cOutField11 = CASE WHEN ISNULL(@cDefaultQty, '') = '' THEN '' ELSE @cDefaultQty END --QTY                      
         
         GOTO Quit          
      END        
               
      EXEC rdt.rdt_Wave_ReplenFrom                       
            @nFunc                = @nFunc,                      
            @nMobile              = @nMobile,                      
            @cLangCode            = @cLangCode,                       
            @nErrNo               = @nErrNo  OUTPUT,                      
            @cErrMsg              = @cErrMsg OUTPUT,                       
            @cStorerKey           = @cStorerKey,                      
            @cFromLOC             = @cLOC,                       
            @cToLOC               = @cToLOC,                       
            @cFromID              = @cID,                       
            @cToID                = @cID,                       
            @cSKU                 = @cSKU,                       
            @cUCC                 = @cUCC,                       
            @nQTY                 = @nQTY,                       
            @cFromLOT             = @cLot,                       
            @cWaveKey             = @cWaveKey,                      
            @cDropID              = @cDropID,                      
            @cReplenInProgressLOC = '', --@cReplenInProgressLOC,                      
            @cReplenishmentKey    = @cReplenishmentKey,                      
            @cLoadKey             = @cLoadKey,                      
            @cStatus              = ''                      
                      
     IF @nErrNo <> 0                      
         GOTO QUIT                      
                      
--         WHILE @@TRANCOUNT > 0                       
--            COMMIT TRAN                         
                                                       
                   
     IF ISNULL(RTRIM(@cWaveKey),'') <> ''                      
     BEGIN                      
         --confirm picklock                      
         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET                       
            Status = '9'                      
         WHERE StorerKey = @cStorerKey                      
            AND WaveKey = @cWaveKey                      
            AND LOC = @cLOC                      
            --AND DropID = @cDropID  (SHONG001)      
            AND AddWho = @cUserName                      
            AND Status = '1'                      
      END                          
      ELSE                
      BEGIN                      
         --confirm picklock                      
         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET                       
            Status = '9'                      
         WHERE StorerKey = @cStorerKey                      
            AND LoadKey = @cLoadKey                      
            AND LOC = @cLOC                      
            --AND DropID = @cDropID  (SHONG001)                   
            AND AddWho = @cUserName                      
            AND Status = '1'                      
      END                      
                               
      IF @@ERROR <> 0                      
      BEGIN                      
         ROLLBACK TRAN                      
         SET @nErrNo = 67409                        
         SET @cErrMsg = rdt.rdtgetmessage( 67409, @cLangCode, 'DSP') --'UPD PLOCK Fail'                        
         SET @cOutField11 = ''                      
         SET @cActQty = ''                        
         IF ISNULL(@cSKU, '') = ''      --(james06)      
         BEGIN            
            SELECT @cOutField05 = SKU FROM dbo.Replenishment WITH (NOLOCK) WHERE ReplenishmentKey = @cReplenishmentKey            
         END        
         EXEC rdt.rdtSetFocusField @nMobile, 11                        
         GOTO Quit               
      END                      
                
      SET @cReplenToByBatch = ''            
      SET @cReplenToByBatch = rdt.RDTGetConfig( @nFunc, 'ReplenToByBatch', @cStorerKey)                 
                     
      SET @cReplenishmentKey = ''   -- (james04)                
      IF ISNULL(RTRIM(@cWaveKey),'') <> ''                      
      BEGIN                      
         SELECT TOP 1                                              
                @cReplenishmentKey = RPL.ReplenishmentKey,                      
                @cLOT = RPL.LOT,                      
                @cID = RPL.ID,                       
                @cTOLOC = RPL.TOLOC,                       
                @cSKU = RPL.SKU,                       
                @cStyle = S.Style,                      
                @cColor = S.Color,                       
                @cMeasurement = S.Measurement,                       
                @cSize = S.Size,                        
                @nSuggestedQTY = RPL.Qty                      
         FROM dbo.Replenishment RPL WITH (NOLOCK)                       
         JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)                      
         JOIN dbo.Loc LOC WITH (NOLOCK) ON (LOC.LOC = RPL.TOLOC)                      
         WHERE RPL.StorerKey = @cStorerKey                      
            AND RPL.WaveKey = @cWaveKey                      
            AND RPL.FROMLOC = @cLOC                      
            AND RPL.Confirmed = 'N'                      
            AND RPL.QTY > 0                      
         --GROUP BY Loc.LogicalLocation,RPL.ReplenishmentKey, RPL.ID, RPL.TOLOC, RPL.Lot, RPL.SKU, S.Style, S.Color, S.Measurement, S.Size                      
         ORDER BY Loc.LogicalLocation,S.Style, S.Color, S.Measurement, S.Size, RPL.SKU            
                      
                   
         IF @cReplenToByBatch = '1' AND ISNULL(RTRIM(@cReplenishmentKey),'') <> ''       
         BEGIN            
            -- Get TotalQty from Other Wave with Same SKU, Loc, Lot, ID                      
            SET @nReplenQTY = 0           
            SELECT                        
                @nReplenQTY = ISNULL(SUM(RPL.Qty), 0)          
            FROM dbo.Replenishment RPL WITH (NOLOCK)                       
            WHERE RPL.StorerKey = @cStorerKey                      
               AND RPL.FROMLOC = @cLOC                      
               AND RPL.Confirmed = 'N'                      
               AND RPL.QTY > 0                      
               --AND RPL.WaveKey <> @cWaveKey          
               AND RPL.SKU = @cSKU          
               AND RPL.Lot = @cLot      
               AND RPL.ID  = @cID       
               AND RPL.ReplenishmentKey <> @cReplenishmentKey          
                       
            IF ISNULL(@nReplenQty,0) > 0          
            BEGIN          
               SET @nSuggestedQTY = @nSuggestedQTY + @nReplenQty          
            END          
         END            
                       
         insert into traceinfo                
         (tracename, timein, step1, step2, step3, step4, step5)                
         values                
         ('replenfrom_wave', getdate(), @cReplenishmentKey, @cStorerKey, @cWaveKey, @cLOC, @cUserName)      
                         
      END -- Wave Key                      
      ELSE                
      BEGIN                      
         SELECT TOP 1                       
                @cReplenishmentKey = RPL.ReplenishmentKey,                      
                @cLOT = RPL.LOT,                      
                @cID = RPL.ID,                       
                @cTOLOC = RPL.TOLOC,                       
                @cSKU = RPL.SKU,                       
                @cStyle = S.Style,                      
                @cColor = S.Color,                       
                @cMeasurement = S.Measurement,                       
                @cSize = S.Size,                        
                @nSuggestedQTY = RPL.Qty                       
         FROM dbo.Replenishment RPL WITH (NOLOCK)                       
         JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)                      
         JOIN dbo.Loc LOC WITH (NOLOCK) ON (LOC.LOC = RPL.TOLOC)                      
         WHERE RPL.StorerKey = @cStorerKey                      
            AND RPL.LoadKey = @cLoadKey                      
            AND RPL.FROMLOC = @cLOC                      
            AND RPL.Confirmed = 'N'                      
            AND RPL.QTY > 0       
         --GROUP BY Loc.LogicalLocation,RPL.ReplenishmentKey, RPL.ID, RPL.TOLOC, RPL.Lot, RPL.SKU, S.Style, S.Color, S.Measurement, S.Size                      
         ORDER BY Loc.LogicalLocation,S.Style, S.Color, S.Measurement, S.Size, RPL.SKU            
                   
         IF @cReplenToByBatch = '1' AND ISNULL(RTRIM(@cReplenishmentKey),'') <> ''      
         BEGIN            
            -- Get TotalQty from Other Wave with Same SKU, Loc, Lot, ID                      
            SET @nReplenQTY = 0           
            SELECT                        
                @nReplenQTY = ISNULL(SUM(RPL.Qty), 0)          
            FROM dbo.Replenishment RPL WITH (NOLOCK)                       
           WHERE RPL.StorerKey = @cStorerKey                      
               AND RPL.FROMLOC = @cLOC                      
               AND RPL.Confirmed = 'N'                      
               AND RPL.QTY > 0                      
               --AND RPL.LoadKey <> @cLoadKey               
               AND RPL.SKU = @cSKU          
               AND RPL.Lot = @cLot        
               AND RPL.ID  = @cID        
               AND RPL.ReplenishmentKey <> @cReplenishmentKey      
                                        
            IF @nReplenQty > 0          
            BEGIN          
               SET @nSuggestedQTY = @nSuggestedQTY + @nReplenQty          
            END          
         END                                      
         insert into traceinfo                
         (tracename, timein, step1, step2, step3, step4, step5)                
         values                
         ('replenfrom_load', getdate(), @cReplenishmentKey, @cStorerKey, @cWaveKey, @cLOC, @cUserName)                
      END -- LoadKey                      
            
      -- If found other replenishment record for same location            
      IF ISNULL(@cReplenishmentKey, '') <> ''                    
      BEGIN                      
         SET @nQTY = 0                      
--(ChewKP06)                   
--            -- Start locking picker's load+loc+sku                      
--            INSERT INTO RDT.RDTPickLock                        
--            (WaveKey, LoadKey, OrderKey, OrderLineNumber, Putawayzone, PickZone,             
--             StorerKey, LOC, LOT, DropID, Status, AddWho, AddDate, PickdetailKey, SKU, ID, PickQty)                        
--           VALUES                        
--            (@cWaveKey, @cLoadkey, '', '**', '', '', @cStorerKey, @cLOC, @cLOT,             
--             @cDropID, '1', @cUserName, GETDATE(), @cReplenishmentKey, @cSKU, @cID, @nSuggestedQTY)                        
--                      
--            IF @@ERROR <> 0                      
--            BEGIN                      
--               ROLLBACK TRAN                      
--                      
--               SET @nErrNo = 67409                        
--               SET @cErrMsg = rdt.rdtgetmessage( 67409, @cLangCode, 'DSP') --'INS PLOCK Fail'                        
--               SET @cOutField11 = ''                      
--               SET @cActQty = ''                        
--               EXEC rdt.rdtSetFocusField @nMobile, 11                        
--               GOTO Quit                        
--            END                      
--            rollback tran                      
--         COMMIT TRAN                      
         
         -- james05            
         SET @cColorField = ''            
         SELECT @cColorField = ISNULL(SValue, '') FROM dbo.StorerConfig WITH (NOLOCK)                      
         WHERE StorerKey = @cStorerKey                      
           AND ConfigKey = 'COLORDESCRFIELD'                      
            
         IF ISNULL(@cColorField, '') <> ''                      
         BEGIN                      
      SET @c_ExecStatements = ''             
            SET @c_ExecArguments = ''                      
    SET @c_ExecStatements = N'SELECT @cColorDescr = ' + @cColorField                      
                                + ' FROM dbo.SKU WITH (NOLOCK) '                      
                                    + ' WHERE Storerkey = @cStorerkey '                      
                                    + ' AND SKU = @cSKU '                      
                       
            SET @c_ExecArguments = N' @cStorerkey NVARCHAR( 15), '                      
                                 + '@cSKU          NVARCHAR( 20), '                      
                                 + '@cColorField   NVARCHAR( 10), '                      
                                 + '@cColorDescr   NVARCHAR( 20) OUTPUT '                      
                   
            EXEC sp_executesql @c_ExecStatements,                      
                               @c_ExecArguments,                      
                               @cStorerkey,                      
                               @cSKU,             
                               @cColorField,                      
                               @cColorDescr OUTPUT                      
         END                      
                         
         SET @nOutstandingQty = @nSuggestedQTY                      
                   
         SET @cOutField01 = @cDropID                      
         SET @cOutField02 = @cLOC                      
         SET @cOutField03 = @cID                      
         SET @cOutField04 = CASE WHEN ISNULL(@cReplenInProgressLOC, '') <> '' THEN @cReplenInProgressLOC ELSE @cTOLOC END                      
         SET @cOutField05 = @cSKU                      
         SET @cOutField06 = @cStyle                      
         SET @cOutField07 = RIGHT(REPLICATE(' ', 10 - LEN(@cColor)) + @cColor, 10)                       
                           + LEFT(REPLICATE(' ', 5 - LEN(@cMeasurement)) + @cMeasurement, 5)                       
                           + LEFT(REPLICATE(' ', 5 - LEN(@cSize)) + @cSize, 5)                      
         SET @cOutField08 = @cColorDescr                      
--               SET @cOutField09 = 'S/O QTY:'                       
--                                 + LEFT(REPLICATE(' ', 5 - LEN(@nSuggestedQTY)) + CAST(@nSuggestedQTY AS NVARCHAR(5)), 5)                      
--                                 + '/'                      
--             + RIGHT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + CAST(@nOutstandingQty AS NVARCHAR(5)), 5)                      
         SET @cOutField09 = 'O/S QTY:' + LEFT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + RTRIM(CAST(@nOutstandingQty AS NVARCHAR(5))), 5) + '/' + CAST(@nSuggestedQTY AS NVARCHAR(5))                     
         SET @cOutField10 = ''   --UCC/SKU                      
         SET @cOutField11 = CASE WHEN ISNULL(@cDefaultQty, '') = '' THEN '' ELSE @cDefaultQty END --QTY                      
                         
            --continue next replenishment task                      
         GOTO Quit                      
      END -- IF ISNULL(@cReplenishmentKey, '') <> ''                     
      ELSE                       
      BEGIN      
       -- if no other replenishment task for same location, get next location      
         --COMMIT TRAN                      
         -- SHONG001      
                         
         SET @cSuggLOC = ''                
         -- After All SKU Scanned Goto ToLoc Screen                      
         IF ISNULL(RTRIM(@cWaveKey),'') <> ''                      
         BEGIN      
            -- Release location, since no more task      
            UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET                       
               Status = '9'                      
            WHERE StorerKey = @cStorerKey                      
               AND WaveKey = @cWaveKey                      
               AND LOC = @cLOC                                     
               AND AddWho = @cUserName                      
               AND Status = '3'                  
                                
            SELECT TOP 1                       
                   @cSuggLOC = RPL.FROMLOC                      
            FROM dbo.Replenishment RPL WITH (NOLOCK)                       
            JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)                      
            JOIN dbo.LOC Loc WITH (NOLOCK) ON (RPL.FromLOC = LOC.Loc)                      
            WHERE RPL.StorerKey = @cStorerKey                      
               AND RPL.WaveKey = @cWaveKey                      
               AND Loc.PutawayZone = @cPutawayZone                      
               AND RPL.Confirmed = 'N'                      
               AND RPL.QTY > 0       
               AND RPL.FROMLOC >= @cStartLoc                      
               AND NOT EXISTS (  -- not being locked by other picker                      
                     SELECT 1 FROM RDT.RDTPickLock RL WITH (NOLOCK)                       
                        WHERE RPL.StorerKey = RL.StorerKey                      
                           AND RPL.WaveKey = RL.WaveKey                      
                           AND RPL.FROMLOC = RL.LOC                      
                           --AND RL.AddWho <> @cUserName -- (ChewKP06)                       
                           AND Status < '9')             
            --GROUP BY Loc.LogicalLocation, RPL.ReplenishmentKey, LOT, RPL.ID, RPL.FROMLOC, RPL.SKU, S.Style, S.Color, S.Measurement, S.Size                      
            --ORDER BY Loc.LogicalLocation, S.Style, S.Color, S.Measurement, S.Size, RPL.SKU                      
            ORDER BY Loc.LogicalLocation, RPL.FromLoc       
         END                      
         ELSE                
         BEGIN      
            -- Release location, since no more task      
            UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET                       
               Status = '9'                      
            WHERE StorerKey = @cStorerKey                      
               AND LoadKey = @cLoadKey                      
               AND LOC = @cLOC                                     
               AND AddWho = @cUserName                      
               AND Status = '3'                  
      
                                
            SELECT TOP 1                       
                   @cSuggLOC = RPL.FROMLOC                      
            FROM dbo.Replenishment RPL WITH (NOLOCK)                       
            JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)                      
            JOIN dbo.LOC Loc WITH (NOLOCK) ON (RPL.FromLOC = LOC.Loc)                      
            WHERE RPL.StorerKey = @cStorerKey                      
               AND RPL.LoadKey = @cLoadKey                      
               AND Loc.PutawayZone = @cPutawayZone                      
               AND RPL.Confirmed = 'N'                      
               AND RPL.Qty > 0      
               AND RPL.FROMLOC >= @cStartLoc                      
               AND NOT EXISTS (  -- not being locked by other picker                      
                     SELECT 1 FROM RDT.RDTPickLock RL WITH (NOLOCK)                       
                        WHERE RPL.StorerKey = RL.StorerKey                      
                           AND RPL.LoadKey = RL.LoadKey                      
                           AND RPL.FROMLOC = RL.LOC                      
                           --AND RL.AddWho <> @cUserName -- (ChewKP06)                       
                           AND Status < '9')                      
            --GROUP BY Loc.LogicalLocation, RPL.ReplenishmentKey, LOT, RPL.ID, RPL.FROMLOC, RPL.SKU, S.Style, S.Color, S.Measurement, S.Size                      
            --ORDER BY Loc.LogicalLocation, S.Style, S.Color, S.Measurement, S.Size, RPL.SKU                      
            ORDER BY Loc.LogicalLocation, RPL.FromLoc       
         END                      
                        
         IF ISNULL(@cSuggLOC, '') = ''                   
         BEGIN                      
            SET @cOutField01 = @cWaveKey                      
            SET @cOutField02 = @cLoadKey                
            SET @cOutField03 = @cPutawayZone                      
            SET @cOutField04 = @cDropID         
                                 
         --goto No Task screen                      
         SET @nScn  = @nScnNoTask                      
            SET @nStep = @nStepNoTask                      
                      
            GOTO Quit                      
         END                      
         ELSE                      
         BEGIN                 
            -- (ChewKP06)                               
                                  
            -- Start locking picker's wave+loc                      
            INSERT INTO RDT.RDTPickLock                        
            (WaveKey, LoadKey, OrderKey, OrderLineNumber, Putawayzone, PickZone, StorerKey, LOC, LOT, DropID, Status, AddWho, AddDate, PickdetailKey, SKU, ID, PickQty, LabelNo)                        
            VALUES                        
            (@cWaveKey, @cLoadKey, '', '*', '', '', @cStorerKey, @cSuggLOC, '', @cDropID, '3', @cUserName, GETDATE(), '', '', '', '', @nFunc)                        
                               
            IF @@ERROR <> 0                      
            BEGIN                      
               ROLLBACK TRAN                      
                               
               SET @nErrNo = 67421                      
               SET @cErrMsg = rdt.rdtgetmessage( 67421, @cLangCode,'DSP') --INS PLOCK Fail                      
               GOTO Step_3_Fail                               
            END                     
                          
            SET @cOutField01 = @cWaveKey                      
            SET @cOutField02 = @cDropID                      
            SET @cOutField03 = ''                      
            SET @cOutField04 = @cLoadKey       -- (ChewKP01)                      
            SET @cOutField05 = @cPutawayZone   -- (ChewKP01)                      
            SET @cOutField06 = @cSuggLOC       -- (ChewKP01)                      
                                  
            --goto loc screen                      
            SET @nScn  = @nScnLoc                      
            SET @nStep = @nStepLoc                      
                      
            GOTO Quit                      
         END                      
      END -- IF ISNULL(@cReplenishmentKey, '') = ''                  
      
      -- SHONG001, I think this portion will never execute by system....                      
      --last replenishment task in wave + loc                      
      --sku/upc                      
      IF @cUCCFlag = 'N'                      
      BEGIN                      
         SET @cOutField01 = @cWaveKey                      
         SET @cOutField02 = @cDropID                      
         SET @cOutField03 = ''                      
         SET @cOutField04 = @cLoadKey       -- (ChewKP01)                      
         SET @cOutField05 = @cPutawayZone   -- (ChewKP01)                      
         SET @cOutField06 = @cSuggLOC       -- (ChewKP01)                      
                   
         --goto next screen                      
         SET @nScn  = @nScn - 1                      
         SET @nStep = @nStep - 1                      
                   
         GOTO Quit                      
      END                      
      ELSE                      
      BEGIN                      
         --check if ucc is mixed sku                      
         IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)                       
                        WHERE StorerKey = @cStorerKey                      
                          AND UCCNo = @cUCC                      
                        GROUP BY UCCNo                      
                        HAVING COUNT(DISTINCT SKU) > 1)                      
         BEGIN                      
            SET @cOutField01 = @cWaveKey                      
            SET @cOutField02 = @cDropID                      
            SET @cOutField03 = ''                      
            SET @cOutField04 = @cLoadKey       -- (ChewKP01)                      
            SET @cOutField05 = @cPutawayZone   -- (ChewKP01)                      
            SET @cOutField06 = @cSuggLOC       -- (ChewKP01)            
                      
            --goto next screen                      
            SET @nScn  = @nScn - 1                      
            SET @nStep = @nStep - 1                      
                   
            GOTO Quit           
         END                      
         ELSE                      
         BEGIN --ucc is a mixed sku                     
            -- 1st record to show                      
            SELECT TOP 1                       
               @cSKUInUCC1 = SKU,                      
               @nQTYInUCC1 = ISNULL(QTY, 0)                      
            FROM dbo.UCC WITH (NOLOCK)                       
            WHERE StorerKey = @cStorerKey                      
               AND UCCNo = @cUCC                      
               AND SKU > @cSKU   --next sku greater than sku displayed on screen                      
            ORDER BY SKU                      
                   
            IF @@ROWCOUNT > 0                      
               BEGIN                      
                  SET @cOutField01 = @cSKUInUCC1                      
                  SET @cOutField02 = @nQTYInUCC1                      
                  SET @cOutField03 = CASE WHEN ISNULL(@cReplenInProgressLOC, '') <> '' THEN @cReplenInProgressLOC ELSE @cTOLOC END                      
                  SET @cOutField04 = ''                      
                  SET @cOutField05 = ''                      
                  SET @cOutField06 = ''                      
                      
                  -- 2ND record to show              
                  SELECT TOP 1                       
                     @cSKUInUCC2 = SKU,                      
                     @nQTYInUCC2 = ISNULL(QTY, 0)                      
                  FROM dbo.UCC WITH (NOLOCK)                       
                  WHERE StorerKey = @cStorerKey                      
                     AND UCCNo = @cUCC                      
                     AND SKU > @cSKUInUCC1                      
                  ORDER BY SKU                      
                      
                  IF @@ROWCOUNT > 0                      
                  BEGIN                      
                     SET @cOutField04 = @cSKUInUCC2                      
                     SET @cOutField05 = @nQTYInUCC2                      
                     SET @cOutField06 = CASE WHEN ISNULL(@cReplenInProgressLOC, '') <> '' THEN @cReplenInProgressLOC ELSE @cTOLOC END                      
                  END                      
                      
                  --goto screen 5                      
                  SET @nScn  = @nScn + 1                      
                  SET @nStep = @nStep + 1                      
                      
                  GOTO Quit                      
               END                      
            END  --ucc is a mixed sku                     
         END -- @cUCCFlag = 'Y'                     
      END                      
                      
   IF @nInputKey = 0 --ESC                      
   BEGIN                      
                            
      IF @nOutstandingQty > 0                      
      BEGIN                      
         SET @cOutField01 = ''                      
                               
         SET @nScn  = @nScnShortPick                       
         SET @nStep = @nStepShortPick                       
                               
         GOTO QUIT                      
      END                      
                            
      --go to screen 1                      
      SET @cDropID = ''                      
      SET @cOutField02 = ''                      
                      
      SET @cOutField01 = @cWaveKey                      
      SET @cOutField02 = ''                      
      SET @cOutField03 = @cLoadKey                      
      SET @cOutField04 = @cPutawayZone                      
                      
      --goto next screen                      
      SET @nScn  = @nScn - 2                      
      SET @nStep = @nStep - 2                      
                      
      GOTO Quit                      
   END                   
                      
   Step_4_Fail:                      
   BEGIN                      
      SET @cDropID = ''                      
      SET @cOutField02 = ''                      
   END                      
END                      
GOTO Quit                      
                      
/********************************************************************************                      
Step 5. Scn = 2074.                       
   SKU        (field01)                      
   QTY Picked (field02)                      
   TOLOC      (field03)                      
********************************************************************************/                      
Step_5:                      
BEGIN                      
   IF @nInputKey = 1 --ENTER               
   BEGIN                      
         --screen mapping                      
      SET @cSKUInUCC1 = @cInField01  --1st SKU on the screen                      
      SET @cSKUInUCC2 = @cInField04  --2nd SKU on the screen                      
                      
      -- 1st record to show                      
      SELECT TOP 1                       
         @cSKUInUCC1 = SKU,                      
         @nQTYInUCC1 = ISNULL(QTY, 0)                      
      FROM dbo.UCC WITH (NOLOCK)                       
      WHERE StorerKey = @cStorerKey                      
         AND UCCNo = @cUCC                      
         AND SKU > @cSKUInUCC2                      
      ORDER BY SKU                      
                      
      IF @@ROWCOUNT = 0                      
      BEGIN                      
         SET @nErrNo = 66351                      
         SET @cErrMsg = rdt.rdtgetmessage( 66351, @cLangCode, 'DSP') --'No More Rec'                      
         GOTO Quit                      
      END                      
                      
      -- 2ND record to show                      
      SELECT TOP 1                       
         @cSKUInUCC2 = SKU,                      
         @nQTYInUCC2 = ISNULL(QTY, 0)                      
      FROM dbo.UCC WITH (NOLOCK)                       
      WHERE StorerKey = @cStorerKey                      
         AND UCCNo = @cUCC                      
         AND SKU > @cSKUInUCC1                      
      ORDER BY SKU                      
                      
      SET @cOutField01 = @cSKUInUCC1                      
      SET @cOutField02 = @nQTYInUCC1                      
      SET @cOutField03 = CASE WHEN ISNULL(@cReplenInProgressLOC, '') <> '' THEN @cReplenInProgressLOC ELSE @cTOLOC END                      
      SET @cOutField04 = @cSKUInUCC2                      
      SET @cOutField05 = @nQTYInUCC2                      
      SET @cOutField06 = CASE WHEN ISNULL(@cReplenInProgressLOC, '') <> '' THEN @cReplenInProgressLOC ELSE @cTOLOC END                      
                      
      GOTO Quit                      
   END                      
                      
   IF @nInputKey = 0 --ESC                      
   BEGIN                      
  SET @cOutField01 = @cDropID                      
      SET @cOutField02 = @cLOC                      
      SET @cOutField03 = @cID                      
      SET @cOutField04 = CASE WHEN ISNULL(@cReplenInProgressLOC, '') <> '' THEN @cReplenInProgressLOC ELSE @cTOLOC END                      
      SET @cOutField05 = @cSKU                      
      SET @cOutField06 = @cStyle                      
      SET @cOutField07 = RIGHT(REPLICATE(' ', 10 - LEN(@cColor)) + @cColor, 10)                       
                        + LEFT(REPLICATE(' ', 5 - LEN(@cMeasurement)) + @cMeasurement, 5)                       
                        + LEFT(REPLICATE(' ', 5 - LEN(@cSize)) + @cSize, 5)                      
      SET @cOutField08 = @cColorDescr                      
--      SET @cOutField09 = 'S/O QTY:'                       
--                        + LEFT(REPLICATE(' ', 5 - LEN(@nSuggestedQTY)) + CAST(@nSuggestedQTY AS NVARCHAR(5)), 5)                      
--                        + ' '                      
--                        + LEFT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + CAST(@nOutstandingQty AS NVARCHAR(5)), 5)                      
      SET @cOutField09 = 'O/S QTY:' + LEFT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + RTRIM(CAST(@nOutstandingQty AS NVARCHAR(5))), 5) + '/' + CAST(@nSuggestedQTY AS NVARCHAR(5))                     
      SET @cOutField10 = ''   --UCC/SKU                      
      SET @cOutField11 = CASE WHEN ISNULL(@cDefaultQty, '') = '' THEN '' ELSE @cDefaultQty END --QTY                      
                      
      --goto next screen                      
      SET @nScn  = @nScn - 1                      
      SET @nStep = @nStep - 1                      
   END                      
END                      
GOTO Quit                      
         
/********************************************************************************                      
Step 6. Scn = 2075.                       
   Confirm Short Picked                      
   Option     (field01, input)                      
********************************************************************************/                      
Step_6:                      
BEGIN                      
   IF @nInputKey = 1 --ENTER                      
   BEGIN                      
         --screen mapping                      
      SET @cOption = @cInField01                        
                      
    IF ISNULL(@cOption, '') = ''                      
      BEGIN                      
         SET @nErrNo = 66351                      
         SET @cErrMsg = rdt.rdtgetmessage( 66351, @cLangCode, 'DSP') --'Option needed'                      
         GOTO Step_6_Fail                      
      END                      
                      
      IF @cOption NOT IN ('1', '2')                      
      BEGIN                      
         SET @nErrNo = 66351                      
         SET @cErrMsg = rdt.rdtgetmessage( 66351, @cLangCode, 'DSP') --'Invalid Option'                      
         GOTO Step_6_Fail                      
      END                      
                      
      SELECT @cConfirmed = ISNULL(Confirmed, '') FROM dbo.Replenishment WITH (NOLOCK)                      
      WHERE ReplenishmentKey = @cReplenishmentKey                      
                      
                            
                      
      IF @cOption  = '1'                      
      BEGIN                      
        --if confirmed = 'N' and no qty been scanned to sku, do nothing and back to dropid screen                   
         IF @cConfirmed = 'N' AND @nQty = 0                      
         BEGIN                      
                                     
            UPDATE dbo.Replenishment WITH (ROWLOCK) SET                       
               Confirmed = 'R' -- Short Pick                      
            WHERE ReplenishmentKey = @cReplenishmentKey                      
                      
            IF @@ERROR <> 0                      
            BEGIN                      
                                     
               SET @nErrNo = 67423                      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD RPL Fail'                      
               ROLLBACK TRAN                      
               GOTO Step_6_Fail                      
            END                      
                                  
            -- Set QtyReplen to PickQty                      
                                    
            UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET                       
               QTYReplen = CASE WHEN ( QTYReplen - (@nSuggestedQTY - @nQTY)) > 0 THEN QTYReplen - (@nSuggestedQTY - @nQTY) ELSE 0 END                      
            WHERE StorerKey = @cStorerKey                      
               AND LOT = @cLot                      
               AND LOC = @cLOC                      
               AND ID  = @cID                      
               AND SKU = @cSKU                      
                               
            IF @@ERROR <> 0                      
            BEGIN                      
             SET @nErrNo = 67429                      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD LLI Fail'                      
  ROLLBACK TRAN                      
               GOTO Step_6_Fail                      
        END                      
      
             --go to dropid Screen                      
            SET @cDropID = ''                      
                      
            SET @cOutField01 = @cWaveKey                      
            SET @cOutField02 = ''                      
            SET @cOutField03 = @cLoadKey                      
            SET @cOutField04 = @cPutawayZone                      
                      
            --goto next screen                      
            SET @nScn  = @nScnDropID                      
            SET @nStep = @nStepDropID                   
        
            GOTO Quit                      
         END                         
         ELSE                      
         BEGIN                      
                               
            INSERT INTO TRACEINFO (TraceName , TimeIN , Step1 , Step2,Step3,Step4)                      
            VAlues ( 'ReplenFrom1', Getdate(), @nQty,@nSuggestedQTY, @cSKU, @cLot)                      
                                  
                                     
            EXEC rdt.rdt_Wave_ReplenFrom                       
               @nFunc                = @nFunc,                      
               @nMobile              = @nMobile,           
               @cLangCode            = @cLangCode,                       
               @nErrNo               = @nErrNo  OUTPUT,                      
               @cErrMsg              = @cErrMsg OUTPUT,                       
               @cStorerKey           = @cStorerKey,                      
               @cFromLOC             = @cLOC,                       
               @cToLOC               = @cToLOC,                       
               @cFromID              = @cID,                       
               @cToID                = @cID,                       
               @cSKU                 = @cSKU,                       
               @cUCC             = @cUCC,                       
               @nQTY                 = @nQTY,                       
               @cFromLOT             = @cLot,                       
               @cWaveKey             = @cWaveKey,                      
               @cDropID              = @cDropID,                      
               @cReplenInProgressLOC = '', --@cReplenInProgressLOC,                      
               @cReplenishmentKey    = @cReplenishmentKey,                      
               @cLoadKey             = @cLoadKey,                      
               @cStatus              = 'R' -- Short Pick                      
                      
            IF @nErrNo <> 0                      
               GOTO QUIT                      
                                  
            -- Set QtyReplen to PickQty                      
            UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET                       
               QTYReplen = CASE WHEN ( QTYReplen - (@nSuggestedQTY - @nQTY)) > 0 THEN QTYReplen - (@nSuggestedQTY - @nQTY) ELSE 0 END                      
            WHERE StorerKey = @cStorerKey                      
               AND LOT = @cLot                      
               AND LOC = @cLOC                      
               AND ID  = @cID                      
               AND SKU = @cSKU                      
                               
            IF @@ERROR <> 0                      
            BEGIN                      
             SET @nErrNo = 67428                      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD LLI Fail'                      
               ROLLBACK TRAN                      
               GOTO Step_6_Fail                      
            END                                                  
         END                      
             --go to dropid Screen                      
            SET @cDropID = ''                      
                      
         SET @cOutField01 = @cWaveKey                      
         SET @cOutField02 = ''   
         SET @cOutField03 = @cLoadKey            
         SET @cOutField04 = @cPutawayZone                      
                      
         --goto next screen                      
         SET @nScn  = @nScnDropID                      
         SET @nStep = @nStepDropID                      
                   
         GOTO Quit                      
                      
      END                      
                      
      IF @cOption  = '2'                      
      BEGIN                      
            SET @cOutField01 = @cDropID                      
            SET @cOutField02 = @cLOC                      
            SET @cOutField03 = @cID                      
            SET @cOutField04 = CASE WHEN ISNULL(@cReplenInProgressLOC, '') <> '' THEN @cReplenInProgressLOC ELSE @cTOLOC END                      
            SET @cOutField05 = @cSKU                      
            SET @cOutField06 = @cStyle             
            SET @cOutField07 = RIGHT(REPLICATE(' ', 10 - LEN(@cColor)) + @cColor, 10)                    
                              + LEFT(REPLICATE(' ', 5 - LEN(@cMeasurement)) + @cMeasurement, 5)                       
                              + LEFT(REPLICATE(' ', 5 - LEN(@cSize)) + @cSize, 5)                      
            SET @cOutField08 = @cColorDescr                      
--            SET @cOutField09 = 'S/O QTY:'                       
--                              + LEFT(REPLICATE(' ', 5 - LEN(@nSuggestedQTY)) + CAST(@nSuggestedQTY AS NVARCHAR(5)), 5)                      
--                  + '/'                      
--                   + RIGHT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + CAST(@nOutstandingQty AS NVARCHAR(5)), 5)                      
            SET @cOutField09 = 'O/S QTY:' + LEFT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + RTRIM(CAST(@nOutstandingQty AS NVARCHAR(5))), 5) + '/' + CAST(@nSuggestedQTY AS NVARCHAR(5))                     
            SET @cOutField10 = ''   --UCC/SKU                      
            SET @cOutField11 = CASE WHEN ISNULL(@cDefaultQty, '') = '' THEN '' ELSE @cDefaultQty END --QTY                      
                      
                                  
        
            EXEC rdt.rdtSetFocusField @nMobile, 10                      
                      
                                  
            SET @nScn  = @nScnSKUQty                      
            SET @nStep = @nStepSKUQty                      
                   
            GOTO Quit                      
                              
      END                      
                      
                      
   END                      
                      
   IF @nInputKey = 0 --ESC                      
   BEGIN                      
--      SET @cOutField01 = @cDropID                      
--      SET @cOutField02 = @cLOC                      
--      SET @cOutField03 = @cID                      
--      SET @cOutField04 = @cTOLOC                      
--      SET @cOutField05 = @cSKU                      
--      SET @cOutField06 = @cStyle                      
--      SET @cOutField07 = RIGHT(REPLICATE(' ', 10 - LEN(@cColor)) + @cColor, 10)                       
--                        + LEFT(REPLICATE(' ', 5 - LEN(@cMeasurement)) + @cMeasurement, 5)                       
--                        + LEFT(REPLICATE(' ', 5 - LEN(@cSize)) + @cSize, 5)                      
--      SET @cOutField08 = @cColorDescr                      
--      SET @cOutField09 = 'S/O QTY:'                       
--                        + LEFT(REPLICATE(' ', 5 - LEN(@nSuggestedQTY)) + CAST(@nSuggestedQTY AS NVARCHAR(5)), 5)                      
--                        + ' '                      
--                        + LEFT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + CAST(@nOutstandingQty AS NVARCHAR(5)), 5)                      
--      SET @cOutField10 = ''   --UCC/SKU                      
--      SET @cOutField11 = CASE WHEN ISNULL(@cDefaultQty, '') = '' THEN '' ELSE @cDefaultQty END --QTY                      
--                      
--      --goto next screen                      
--      SET @nScn  = @nScn - 2                      
--      SET @nStep = @nStep - 2                      
      SET @cOutfield01 = ''                      
                      
      SET @nScn = @nScnShortPick                      
      SET @nStep = @nStepShortPick                      
                      
      GOTO Quit                      
   END                      
                      
   Step_6_Fail:                      
   BEGIN                      
      SET @cOption = ''                      
      SET @cOutField01 = ''                      
   END                      
END                      
GOTO Quit                      
                      
/********************************************************************************                      
Step 7. Scn = 2076.                       
   Drop ID Exists                      
   Option     (field01, input)                      
********************************************************************************/                      
Step_7:                      
BEGIN                      
   IF @nInputKey = 1 --ENTER                      
   BEGIN        
         --screen mapping                      
      SET @cOption = @cInField01                        
                      
      IF ISNULL(@cOption, '') = ''                      
      BEGIN                      
         SET @nErrNo = 66351                      
         SET @cErrMsg = rdt.rdtgetmessage( 66351, @cLangCode, 'DSP') --'Option needed'                      
         GOTO Step_7_Fail                      
      END                      
                      
      IF @cOption NOT IN ('1', '2')                      
      BEGIN                      
         SET @nErrNo = 66351                      
         SET @cErrMsg = rdt.rdtgetmessage( 66351, @cLangCode, 'DSP') --'Invalid Option'                      
         GOTO Step_7_Fail                      
      END                      
                      
      -- (james04)                
      --accept new drop id, goto LOC screen                      
      IF @cOption = '1'                      
      BEGIN                      
         IF ISNULL(RTRIM(@cWaveKey),'') <> ''                      
         BEGIN               
            SELECT TOP 1                       
                   @cSuggLOC = RPL.FROMLOC                      
            FROM dbo.Replenishment RPL WITH (NOLOCK)                       
            JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)                      
            JOIN dbo.LOC Loc WITH (NOLOCK) ON (RPL.FromLOC = LOC.Loc)                      
            WHERE RPL.StorerKey = @cStorerKey                      
               AND RPL.WaveKey = @cWaveKey                      
               AND Loc.PutawayZone = @cPutawayZone                      
               AND RPL.Confirmed = 'N'                      
               AND RPL.QTY > 0       
               AND RPL.FROMLOC >= @cStartLoc                      
               AND NOT EXISTS (  -- not being locked by other picker                      
                     SELECT 1 FROM RDT.RDTPickLock RL WITH (NOLOCK)                       
                        WHERE RPL.StorerKey = RL.StorerKey                      
                           AND RPL.WaveKey = RL.WaveKey      
                           AND RPL.FROMLOC = RL.LOC                      
                           --AND RL.AddWho <> @cUserName -- (ChewKP06)                     
                           AND Status < '9')                      
            GROUP BY Loc.LogicalLocation, RPL.ReplenishmentKey, LOT, RPL.ID, RPL.FROMLOC, RPL.SKU, S.Style, S.Color, S.Measurement, S.Size                      
            --ORDER BY Loc.LogicalLocation, S.Style, S.Color, S.Measurement, S.Size, RPL.SKU                   
            ORDER BY Loc.LogicalLocation, RPL.FromLoc        
                            
            --      IF @@RowCount = 0      (james03) cannot use rowcount here                
            IF ISNULL(@cSuggLOC, '') = ''                
            BEGIN                      
               SET @nErrNo = 67424                      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Replen                      
               GOTO Step_2_Fail                        
            END                   
         END                      
         ELSE                
         --IF ISNULL(RTRIM(@cLoadKey),'') <> ''      (james04)                
         BEGIN                      
            SELECT TOP 1                       
                   @cSuggLOC = RPL.FROMLOC                      
            FROM dbo.Replenishment RPL WITH (NOLOCK)                       
            JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)                      
            JOIN dbo.LOC Loc WITH (NOLOCK) ON (RPL.FromLOC = LOC.Loc)                      
            WHERE RPL.StorerKey = @cStorerKey                      
               AND RPL.LoadKey = @cLoadKey                      
               AND Loc.PutawayZone = @cPutawayZone                      
               AND RPL.Confirmed = 'N'                      
               AND RPL.QTY > 0       
               AND RPL.FROMLOC >= @cStartLoc                     
               AND NOT EXISTS (  -- not being locked by other picker                      
                     SELECT 1 FROM RDT.RDTPickLock RL WITH (NOLOCK)                       
                        WHERE RPL.StorerKey = RL.StorerKey                      
              AND RPL.LoadKey = RL.LoadKey                      
                           AND RPL.FROMLOC = RL.LOC                      
                           --AND RL.AddWho <> @cUserName -- (ChewKP06)                       
                           AND Status < '9')                      
            GROUP BY Loc.LogicalLocation, RPL.ReplenishmentKey, LOT, RPL.ID, RPL.FROMLOC, RPL.SKU, S.Style, S.Color, S.Measurement, S.Size                      
            --ORDER BY Loc.LogicalLocation, S.Style, S.Color, S.Measurement, S.Size, RPL.SKU                      
            ORDER BY Loc.LogicalLocation, RPL.FromLoc       
                         
            IF @@RowCount = 0                      
            BEGIN                      
               SET @nErrNo = 67430                      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Replen                      
               GOTO Step_2_Fail                          
            END                          
         END          
               
         -- (ChewKP06)                
         -- Start locking picker's wave+loc                      
         INSERT INTO RDT.RDTPickLock                        
         (WaveKey, LoadKey, OrderKey, OrderLineNumber, Putawayzone, PickZone, StorerKey, LOC, LOT, DropID, Status, AddWho, AddDate, PickdetailKey, SKU, ID, PickQty, LabelNo)                        
         VALUES                        
         (@cWaveKey, @cLoadKey, '', '*', '', '', @cStorerKey, @cSuggLOC, '', @cDropID, '3', @cUserName, GETDATE(), '', '', '', '', @nFunc)                        
                         
         IF @@ERROR <> 0                      
         BEGIN                      
            ROLLBACK TRAN                      
                         
            SET @nErrNo = 67421                      
            SET @cErrMsg = rdt.rdtgetmessage( 67421, @cLangCode,'DSP') --INS PLOCK Fail                      
            GOTO Step_3_Fail                               
         END                      
                
         SET @cLOC = ''                      
         SET @cOutField01 = @cWaveKey                      
         SET @cOutField02 = @cDropID                      
         SET @cOutField03 = ''                      
         SET @cOutField04 = @cLoadKey       -- (ChewKP01)                      
         SET @cOutField05 = @cPutawayZone   -- (ChewKP01)                      
         SET @cOutField06 = @cSuggLOC       -- (ChewKP01)                      
                         
                
         SET @nScn  = @nScn - 4                      
         SET @nStep = @nStep - 4                      
      END                      
      ELSE                      
      --not accept new drop id, go back to drop id screen                      
      BEGIN                      
         SET @cDropID = ''                      
         SET @cOutField02 = ''                      
                      
         SET @nScn  = @nScn - 5                      
         SET @nStep = @nStep - 5                      
      END                      
                      
      GOTO Quit                      
   END                      
                      
   IF @nInputKey = 0 --ESC                      
   BEGIN                      
      SET @cDropID = ''                      
      SET @cOutField03 = ''                      
                      
      --go back to drop id screen                      
      SET @nScn  = @nScn - 5                      
      SET @nStep = @nStep - 5                      
                      
      GOTO Quit                      
   END                      
                      
   Step_7_Fail:                      
   BEGIN                      
      SET @cOption = ''                      
      SET @cOutField01 = ''                  
   END                      
END                      
GOTO Quit                      
                      
-- ChewKP01                      
/********************************************************************************                      
Step 8. Scn = 2077.                       
   Wave     (field01)          
   LoadKey  (field02)                      
   Zone     (field03, input )      
   Start Loc (field04, input)                      
********************************************************************************/               
Step_8:                      
BEGIN                      
   IF @nInputKey = 1 --ENTER                      
   BEGIN                      
         --screen mapping                      
      SET @cPutawayZone = ISNULL(@cInField03,'')        
      SET @cStartLoc    = ISNULL(RTRIM(@cInField04),'')      
                            
      -- Validate blank                      
      --SET @cReplenValidateZone = ''                          
      --SET @cReplenValidateZone = rdt.RDTGetConfig( @nFunc, 'ReplenValidateZone', @cStorerKey)                            
                            
      --IF ISNULL(RTRIM(@cReplenValidateZone),'') = '1'                      
      --BEGIN                      
      IF ISNULL(@cPutawayZone, '') = ''                      
      BEGIN                      
         SET @nErrNo = 67415                      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Zone Req                      
         GOTO Step_8_Fail                               
      END                      
                            
      IF ISNULL(@cWaveKey,'')  <> ''                      
      BEGIN                      
         IF NOT EXISTS ( SELECT 1 FROM dbo.Replenishment RPL WITH (NOLOCK)                      
                         INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.LOC = RPL.FromLoc                       
                         WHERE RPL.Storerkey = @cStorerkey                      
                   AND LOC.Putawayzone = @cPutawayZone                      
                         AND RPL.WaveKey = @cWaveKey )                      
         BEGIN                      
            SET @nErrNo = 67416                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Zone                      
            GOTO Step_8_Fail                          
         END                      
      END ELSE IF ISNULL(@cLoadKey,'')  <> ''                      
      BEGIN                      
         IF NOT EXISTS ( SELECT 1 FROM dbo.Replenishment RPL WITH (NOLOCK)                      
       INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.LOC = RPL.FromLoc                       
                      WHERE RPL.Storerkey = @cStorerkey                      
                      AND LOC.Putawayzone = @cPutawayZone                      
                      AND RPL.LoadKey = @cLoadkey )                      
         BEGIN                      
            SET @nErrNo = 67417                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Zone                      
            GOTO Step_8_Fail                          
         END                      
      END      
      
      IF ISNULL(RTRIM(@cStartLoc), '') <> ''                      
      BEGIN                      
         IF NOT EXISTS(SELECT 1 FROM LOC WITH (NOLOCK)      
                       WHERE LOC = @cStartLoc       
                         AND PutawayZone = @cPutawayZone)      
         BEGIN       
            SET @nErrNo = 67398                      
            SET @cErrMsg = rdt.rdtgetmessage( 67398, @cLangCode,'DSP') --Invalid LOC                      
            GOTO Step_8_Fail               
         END                                
      END                      
                      
  --END                      
                      
                            
      SET @cOutField01 = @cWaveKey                      
      SET @cOutField02 = ''                      
      SET @cOutField03 = @cLoadKey                      
      SET @cOutField04 = @cPutawayZone                      
      --goto DropID screen                      
                          
      SET @nScn  = @nScnDropID                      
      SET @nStep = @nStepDropID                      
                      
      GOTO Quit                      
   END                      
                      
   IF @nInputKey = 0 --ESC                      
   BEGIN                      
      DELETE FROM RDT.RDTPickLock WHERE AddWho = @cUserName AND Status < '9'                      
                           
      --go to main menu                      
      SET @nScn = @nScnWave                      
      SET @nStep = @nStepWave                      
      SET @cStartLoc = ''                            
                            
 SET @cOutField01 = ''                      
      SET @cOutField02 = ''                      
                      
      GOTO Quit                      
   END                      
                      
   Step_8_Fail:                      
   BEGIN                      
      --SET @cWaveKey = ''                      
      SET @cOutField03 = ''                      
   END                      
END                      
GOTO Quit                      
                      
-- ChewKP01                      
/********************************************************************************                      
Step 9. Scn = 2078.                       
   Short Pick                       
   Option (field01, Input)                      
********************************************************************************/                      
Step_9:                      
BEGIN                      
   IF @nInputKey = 1 --ENTER                      
   BEGIN                      
         --screen mapping                      
      SET @cOption = ISNULL(@cInField01,'')                      
                      
                       
                 
      IF @cOption <> '1' AND @cOption <> '2'                       
      BEGIN                      
            SET @nErrNo = 67422                      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Option Req                      
            GOTO Step_9_Fail                        
      END                      
                            
                            
      IF @cOption = '1'                      
      BEGIN                      
         SET @cOutField02 = @cLOC                      
         SET @cOutField03 = CASE WHEN ISNULL(@cReplenInProgressLOC, '') <> '' THEN @cReplenInProgressLOC ELSE @cTOLOC END                      
                               
         SET @cOutField04 = @cSKU                      
         SET @cOutField05 = @cStyle                      
         SET @cOutField06 = RIGHT(REPLICATE(' ', 10 - LEN(@cColor)) + @cColor, 10)                       
                        + LEFT(REPLICATE(' ', 5 - LEN(@cMeasurement)) + @cMeasurement, 5)                       
                        + LEFT(REPLICATE(' ', 5 - LEN(@cSize)) + @cSize, 5)                      
         SET @cOutField07 = @cColorDescr                      
         SET @cOutField08 = CAST(@nSuggestedQTY AS NVARCHAR(5))                      
         SET @cOutField09 = CAST(@nSuggestedQTY - @nOutstandingQty AS NVARCHAR(5))                      
                               
         SET @nScn  = @nScnShortPickConfirm                      
         SET @nStep = @nStepShortPickConfirm                      
                               
         GOTO QUIT                      
      END                      
                            
      IF @cOption = '2'                      
      BEGIN                      
         INSERT INTO TRACEINFO (TraceName , TimeIN , Step1 , Step2)                      
         VAlues ( 'ReplenFrom1', Getdate(), @nQty,'3')                      
                                  
         EXEC rdt.rdt_Wave_ReplenFrom                       
               @nFunc                = @nFunc,                      
               @nMobile              = @nMobile,                      
               @cLangCode            = @cLangCode,                       
               @nErrNo               = @nErrNo  OUTPUT,                      
               @cErrMsg              = @cErrMsg OUTPUT,                       
               @cStorerKey           = @cStorerKey,                      
               @cFromLOC             = @cLOC,                       
               @cToLOC               = @cToLOC,                                    
               @cFromID              = @cID,                       
               @cToID                = @cID,                       
               @cSKU                 = @cSKU,                       
               @cUCC                 = @cUCC,                       
               @nQTY                 = @nQTY,                       
               @cFromLOT             = @cLot,                       
               @cWaveKey             = @cWaveKey,                      
               @cDropID              = @cDropID,                      
               @cReplenInProgressLOC = '', --@cReplenInProgressLOC,                      
               @cReplenishmentKey    = @cReplenishmentKey,                      
               @cLoadKey             = @cLoadKey,                      
               @cStatus              = 'F'                      
                      
         IF @nErrNo <> 0                      
            GOTO QUIT                      
                               
                               
         SET @cOutField01 = @cWaveKey                      
         SET @cOutField02 = ''                      
         SET @cOutField03 = @cLoadKey                      
         SET @cOutField04 = @cPutawayZone                      
         --goto DropID screen                      
                             
         SET @nScn  = @nScnDropID                      
         SET @nStep = @nStepDropID                      
         GOTO Quit                      
      END                      
                             
                            
                            
   END                      
                      
   IF @nInputKey = 0 --ESC                      
   BEGIN                      
      SET @cOutField01 = @cDropID                      
      SET @cOutField02 = @cLOC                      
      SET @cOutField03 = @cID                      
      SET @cOutField04 = CASE WHEN ISNULL(@cReplenInProgressLOC, '') <> '' THEN @cReplenInProgressLOC ELSE @cTOLOC END                      
      SET @cOutField05 = @cSKU                      
      SET @cOutField06 = @cStyle                      
      SET @cOutField07 = RIGHT(REPLICATE(' ', 10 - LEN(@cColor)) + @cColor, 10)                       
                        + LEFT(REPLICATE(' ', 5 - LEN(@cMeasurement)) + @cMeasurement, 5)                       
                        + LEFT(REPLICATE(' ', 5 - LEN(@cSize)) + @cSize, 5)                      
      SET @cOutField08 = @cColorDescr                      
--      SET @cOutField09 = 'S/O QTY:'                       
--                        + LEFT(REPLICATE(' ', 5 - LEN(@nSuggestedQTY)) + CAST(@nSuggestedQTY AS NVARCHAR(5)), 5)                      
--                        + '/'                      
--                        + RIGHT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + CAST(@nOutstandingQty AS NVARCHAR(5)), 5)                      
      SET @cOutField09 = 'O/S QTY:' + LEFT(REPLICATE(' ', 5 - LEN(@nOutstandingQty)) + RTRIM(CAST(@nOutstandingQty AS NVARCHAR(5))), 5) + '/' + CAST(@nSuggestedQTY AS NVARCHAR(5))                     
      SET @cOutField10 = ''   --UCC/SKU                      
      SET @cOutField11 = CASE WHEN ISNULL(@cDefaultQty, '') = '' THEN '' ELSE @cDefaultQty END --QTY                      
                      
                            
                      
      EXEC rdt.rdtSetFocusField @nMobile, 10                      
                      
                            
      SET @nScn  = @nScnSKUQty                      
      SET @nStep = @nStepSKUQty                      
                      
                            
   END                      
                      
   Step_9_Fail:                      
   BEGIN                      
      --SET @cWaveKey = ''                      
      SET @cOutField01 = ''                      
                            
   END                      
END                      
GOTO Quit                      
                      
-- ChewKP01                      
/********************************************************************************                      
Step 10. Scn = 2079.                       
   No Task                       
********************************************************************************/                      
Step_10:                      
BEGIN                      
   IF @nInputKey = 1 --ENTER                      
   BEGIN                      
                             
      -- Go to Screen 1                       
      SET @cOutField01 = ''                      
      SET @cOutField02 = ''                      
                            
      SET @nScn  = @nScnWave                      
      SET @nStep = @nStepWave              
                            
   END              
END                      
GOTO Quit                      
      
/********************************************************************************                      
Step 11. Scn = 2069.                   
   Location Locked                       
********************************************************************************/                      
Step_11:                      
BEGIN                      
   IF @nInputKey = 1 --ENTER                      
   BEGIN      
      DELETE RDT.RDTPickLock       
      WHERE  AddWho = @cUserName       
        AND  WaveKey = @cWaveKey       
        AND LoadKey = @cLoadKey       
        AND StorerKey = @cStorerKey       
        AND LOC       = @cSuggLOC       
        AND [Status]  = '3'       
                                            
      -- Reset Suggested Location      
      SET @cSuggLOC = ''      
      
      -- Go to Screen 2      
      SET @cOutField01 = @cWaveKey                      
      SET @cOutField02 = @cDropID                       
      SET @cOutField03 = @cLoadKey                      
      SET @cOutField04 = @cPutawayZone                      
                
      --goto next screen                      
      SET @nScn  = @nScnDropID                      
      SET @nStep = @nStepDropID                      
        
   END                      
END                      
GOTO Quit                      
                      
/********************************************************************************                      
Quit. Update back to I/O table, ready to be pick up by JBOSS                      
********************************************************************************/                      
Quit:                      
BEGIN                      
   UPDATE RDTMOBREC WITH (ROWLOCK) SET         
      EditDate     = GETDATE(),               
      ErrMsg       = @cErrMsg,                       
      Func         = @nFunc,                      
      Step         = @nStep,                      
      Scn          = @nScn,                      
                      
      StorerKey    = @cStorerKey,                      
      Facility     = @cFacility,                       
      Printer      = @cPrinter,                          
      -- UserName     = @cUserName,                      
                      
      V_PickSlipNo = @cPickSlipNo,                      
      V_LoadKey    = @cLoadKey,                      
      V_LOT        = @cLOT,           
      V_LOC        = @cLOC,                      
      V_ID         = @cID,                      
      V_SKU        = @cSKU,                      
      V_QTY        = @nQTY,            
      
      V_Integer1  = @nSuggestedQTY,
      V_Integer2  = @nOutstandingQty,
                      
      V_String1  = @cWaveKey,                      
      V_String2  = @cDropID,                      
      V_String3  = @cTOLOC,                      
      V_String4  = @cStyle,                      
      V_String5  = @cColor,                      
      V_String6  = @cMeasurement,                      
      V_String7  = @cColorField,                      
      --V_String8  = @nSuggestedQTY,                      
      --V_String9  = @nOutstandingQty,                      
      V_String10 = @cDefaultQty,                      
      V_String11 = @cReplenishmentKey,                 
      V_String12 = @cReplenInProgressLOC,                      
      V_String13 = @cLoadkey,                      
      V_String14 = @cPutawayZone,                      
      V_String15 = @cSuggLoc,      
      V_String16 = @cStartLoc,                       
                      
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
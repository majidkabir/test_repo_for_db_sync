SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdtfnc_PicktoDropID                                 */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Picking: Pick to DropID (C4LGMY - Carrefour)                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Rev  Author     Purposes                                */  
/* 2009-07-17   1.0  Vanessa    Created                                 */  
/* 2009-09-16   1.1  Vanessa    Script enhancement                      */  
/* 2009-09-14   1.2  Vicky      Add in EventLog (Vicky06)               */  
/* 2009-09-14   1.3  James      Performance tuning (james01)            */  
/* 2009-11-09   1.4  Vicky      Performance Tuning (Vicky01)            */  
/* 2009-12-30   1.5  ChewKP     SOS#156663 RDT Drop ID change Req -     */  
/*                            Additional Check While Scanning (ChewKP01)*/  
/* 2016-07-11   1.6  James      SOS372493 - Add DecodeSP (james02)      */  
/*                              Add new screen to scan sku & qty        */  
/* 2016-10-26   1.7  James      Perf tuning (james03)                   */  
/* 2018-03-30   1.8  James      WMS4127. Enable direct flow thru        */  
/*                              screen if input value is ready (james04)*/  
/*                              Add config to verify stor if flow thru  */  
/* 2018-08-07   1.9  James      Change update pickdetail status to      */  
/*                              config (james05)                        */ 
/* 2018-10-22   2.0  TungGH     Performance                             */ 
/************************************************************************/  
CREATE PROC  [RDT].[rdtfnc_PicktoDropID](  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
) AS  
  
-- Misc variable  
DECLARE  
 @b_success      INT,  
 @n_err       INT,  
 @c_errmsg      NVARCHAR( 250),  
   @nLOCCnt             INT,  
   @nCount              INT  
    
-- Define a variable  
DECLARE    
   @nFunc               INT,  
   @nScn                INT,  
   @nStep               INT,  
   @cLangCode           NVARCHAR(3),  
   @nMenu               INT,  
   @nInputKey           NVARCHAR( 3),  
  
   @cStorerKey          NVARCHAR(15),  
   @cFacility           NVARCHAR(5),  
   @cUserName           NVARCHAR( 18),  
     
   @cC4DropID           CHAR (1), --(ChewKP01)   
   @nFuncStorerConfig   INT, --(ChewKP01)   
     
   @cLOC                NVARCHAR(10),  
   @cSKU                NVARCHAR(20),  
   @cNextSKU            NVARCHAR(20),  
   @cDefaultUOM         NVARCHAR(1),  
   @cMUID               NVARCHAR(18),   
   @cConsigneeKey       NVARCHAR(15),  
   @cNextConsigneeKey   NVARCHAR(15),  
   @cSKUDesc            NVARCHAR(60),  
   @nQty                INT,  
   @cLottable01         NVARCHAR(18),  
   @cLottable02         NVARCHAR(18),  
   @cLottable03         NVARCHAR(18),  
   @dLottable04         DATETIME,  
   @cBALQty             NVARCHAR(5),  
   @cACTQty             NVARCHAR(5),  
   @cPackUOM3           NVARCHAR(10),  
   @cDefaultUOMDesc     NVARCHAR(10),  
   @cDefaultUOMDIV      NVARCHAR(5),  
   @cDefaultUOMQTY      NVARCHAR(5),  
   @cPackUOM3QTY        NVARCHAR(5),  
   @cKeyDefaultUOMQTY   NVARCHAR(5),  
   @cKeyPackUOM3QTY     NVARCHAR(5),  
   @cDropID             NVARCHAR(18),  
   @cScanConsigneeKey   NVARCHAR(15),  
   @cOption             NVARCHAR(1),  
   @nQTY_Act            INT,  
   @nQTY_Bal            INT,  
 @nQTY_PD       INT,  
 @cPickDetailKey    NVARCHAR(10),  
 @cPrePickDetailKey NVARCHAR(10),  
  
   -- (james02)  
   @nSKUQTY             INT,  
   @cDecodeSP           NVARCHAR( 20),   
   @cBarcode            NVARCHAR( 2000),   
   @cUPC                NVARCHAR( 30),   
   @cFromID             NVARCHAR( 18),   
   @cReceiptKey         NVARCHAR( 10),   
   @cPOKey              NVARCHAR( 10),   
   @cToLOC              NVARCHAR( 10),   
   @dLottable05         DATETIME,      
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
   @cDefaultUOMSKUQTY   NVARCHAR( 5),   
   @cPackUOM3SKUQTY     NVARCHAR( 5),   
   @nSKUCnt             INT,  
   @cExtendedValidateSP NVARCHAR(20),     
   @cExtendedUpdateSP   NVARCHAR(20),     
   @cNotAutoShortPick   NVARCHAR( 1),     
   @cPDStatus           NVARCHAR( 1),     
   @cDirectFlowThruScn  NVARCHAR( 1),     -- (james04)  
   @cPrevConsigneeKey   NVARCHAR( 15),    -- (james04)  
   @cMax                NVARCHAR( MAX),   -- (james04)  
   @cVerifyStor         NVARCHAR( 1),     -- (james04)  
   @nStorVerified       INT,              -- (james04)  
   @nTranCount          INT,              -- (james04)  
   @nPackQty            INT,              -- (james04)  
   @cPickConfirmStatus  NVARCHAR( 1),     -- (james05)  
     
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
  
-- TraceInfo (Vicky02) - Start    
DECLARE    @d_starttime    datetime,    
           @d_endtime      datetime,    
           @d_step1        datetime,    
           @d_step2        datetime,    
           @d_step3        datetime,    
           @d_step4        datetime,    
           @d_step5        datetime,    
           @c_col1         NVARCHAR(20),    
           @c_col2         NVARCHAR(20),    
           @c_col3         NVARCHAR(20),    
           @c_col4         NVARCHAR(20),    
           @c_col5         NVARCHAR(20),    
           @c_TraceName    NVARCHAR(80)    
    
SET @d_starttime = getdate()    
    
SET @c_TraceName = 'rdtfnc_PicktoDropID'    
-- TraceInfo (Vicky02) - End    
  
-- To Make RDTGetConfig Function using Variable for FunctionID (ChewKP01) --  
SET @nFuncStorerConfig = 0 -- (ChewKP01)  
              
-- Getting Mobile information  
SELECT   
   @nFunc               = Func,  
   @nScn                = Scn,  
   @nStep               = Step,  
   @nInputKey           = InputKey,  
   @cLangCode           = Lang_code,  
   @nMenu               = Menu,  
  
   @cFacility           = Facility,  
   @cStorerKey          = StorerKey,  
   @cUserName           = UserName, -- (Vicky06)  
  
   @cLOC                = V_Loc,  
   @cSKU                = V_SKU,   
   @cDefaultUOM         = V_UOM,  
   @cMUID               = V_ID,  
   @cConsigneeKey       = V_ConsigneeKey,  
   @cSKUDesc            = V_SkuDescr,   
   @nQty                = V_QTY,     
   @cLottable01         = V_Lottable01,  
   @cLottable02         = V_Lottable02,  
   @cLottable03         = V_Lottable03,  
   @dLottable04         = V_Lottable04,  
   @cBALQty             = V_String1,  
   @cACTQty             = V_String2,  
   @cPackUOM3           = V_String3,  
   @cDefaultUOMDesc     = V_String4,  
   @cDefaultUOMDIV      = V_String5,  
   @cDefaultUOMQTY      = V_String6,  
   @cPackUOM3QTY        = V_String7,  
   @cKeyDefaultUOMQTY   = V_String8,  
   @cKeyPackUOM3QTY     = V_String9,  
   @cDropID             = V_String10,  
   @cDecodeSP           = V_String11,  -- (james02)  
   @cNotAutoShortPick   = V_String12,  -- (james02)  
   @cDirectFlowThruScn  = V_String13,  -- (james04)  
   @cUserDefine01       = V_String14,  -- (james04)  
   @cPrevConsigneeKey   = V_String15,  -- (james04)  
   @cVerifyStor         = V_String16,  -- (james04)  
   @nStorVerified       = V_String17,  -- (james04)  
   @cExtendedValidateSP = V_String18,  -- (james04)  
   @cExtendedUpdateSP   = V_String19,  -- (james04)  
   @cUserDefine01       = V_String20,  -- (james04)  
   @cUserDefine02       = V_String21,  -- (james04)  
   @cUserDefine03       = V_String22,  -- (james04)  
   @cUserDefine04       = V_String23,  -- (james04)  
   @cUserDefine05       = V_String24,  -- (james04)  
   @cPickConfirmStatus  = V_String25,  -- (james05)  
   @cMax                = V_Max,  
  
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
  
FROM   RDTMOBREC (NOLOCK)  
WHERE  Mobile = @nMobile  
  
-- Redirect to respective screen  
IF @nFunc = 864 -- Pick to DropID  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 864  
   IF @nStep = 1 GOTO Step_1   -- Scn = 2060   Scan-in the MUID  
   IF @nStep = 2 GOTO Step_2   -- Scn = 2061   Scan-in the STOR  
   IF @nStep = 3 GOTO Step_3   -- Scn = 2062   Key-in the ACT QTY picked in its corresponding UOM column  
   IF @nStep = 4 GOTO Step_4   -- Scn = 2063   Scan-in the Drop ID  
   IF @nStep = 5 GOTO Step_5   -- Scn = 2064   Enter Option  
   IF @nStep = 6 GOTO Step_6   -- Scn = 2065   Key-in the SKU & ACT QTY picked in its corresponding UOM column  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 864)  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn  = 2060  
   SET @nStep = 1  
  
    -- (Vicky06) EventLog - Sign In Function  
    EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep  
  
   -- Init var  
   SET @nLOCCnt = 0  
   SET @nCount  = 0  
  
   -- (james02)  
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)  
   IF @cDecodeSP = '0'  
      SET @cDecodeSP = ''  
  
   -- (james02)  
   SET @cNotAutoShortPick = rdt.RDTGetConfig( @nFunc, 'NotAutoShortPick', @cStorerKey)  
   IF @cNotAutoShortPick = '0'  
      SET @cNotAutoShortPick = ''  
  
   -- (james04)  
   SET @cVerifyStor = rdt.RDTGetConfig( @nFunc, 'VerifyStor', @cStorerKey)  
   IF @cVerifyStor = '0'  
      SET @cVerifyStor = ''  
  
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)  
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''  
  
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''  
  
   -- (james01)  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  
  
   -- initialise all variable  
   SET @cLOC              = ''  
   SET @cSKU              = ''  
   SET @cNextSKU          = ''  
   SET @cDefaultUOM       = ''  
   SET @cMUID             = ''  
   SET @cConsigneeKey     = ''  
   SET @cSKUDesc          = ''  
   SET @nQty              = 0  
   SET @cLottable01       = ''  
   SET @cLottable02       = ''  
   SET @cLottable03       = ''  
   SET @dLottable04       = ''  
   SET @cBALQty           = ''  
   SET @cACTQty           = ''  
   SET @cPackUOM3         = ''  
   SET @cDefaultUOMDesc   = ''  
   SET @cDefaultUOMDIV    = ''  
   SET @cDefaultUOMQTY    = ''  
   SET @cPackUOM3QTY      = ''  
   SET @cKeyDefaultUOMQTY = ''  
   SET @cKeyPackUOM3QTY   = ''  
   SET @cDropID           = ''  
   SET @cScanConsigneeKey = ''  
   SET @cOption           = ''  
   SET @nQTY_Act          = 0  
   SET @nQTY_Bal          = 0  
   SET @nQTY_PD           = 0  
   SET @cPickDetailKey    = ''  
   SET @cPrePickDetailKey = ''  
   -- Prep next screen var     
   SET @cOutField01 = ''  -- MUID  
   SET @cOutField02 = ''  -- LOC  
   SET @cOutField03 = ''  -- ConsigneeKey  
  
   SET @cInField01  = ''  -- MUID  
   SET @cDirectFlowThruScn = ''  
   SET @cMax = ''  
   SET @nStorVerified = 0  
  
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
GOTO Quit  
  
/********************************************************************************  
Step 1. screen = 2060 Scan-in the MUID screen  
   MUID:   
   (Field01, input)  
  
   ENTER = Next Page  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cMUID = SUBSTRING( @cMax, 1, 18) -- SKU  
      SET @cBarcode = SUBSTRING( @cMax, 1, 2000)  
  
  
      --When MUID is blank  
      IF @cMUID = ''  
      BEGIN  
         SET @nErrNo = 67326  
         SET @cErrMsg = rdt.rdtgetmessage( 67326, @cLangCode, 'DSP') --MUID required  
         GOTO Step_1_Fail    
      END   
  
      -- (james02)  
      IF @cDecodeSP <> ''  
      BEGIN  
         --SET @cBarcode = @cInField01  
         SET @cUserDefine01 = ''  
  
-- Standard decode  
         IF @cDecodeSP = '1'  
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,   
               @cMUID         OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,   
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,  
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,  
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,  
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,  
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT  
  
         -- Customize decode  
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +  
               ' @cID            OUTPUT, @cSKU           OUTPUT, @nQTY           OUTPUT, @cDropID        OUTPUT, ' +  
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
               ' @cBarcode       NVARCHAR( 2000), ' +  
               ' @cID            NVARCHAR( 18)  OUTPUT, ' +  
               ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +  
               ' @nQTY           INT            OUTPUT, ' +  
               ' @cDropID        NVARCHAR( 20)  OUTPUT, ' +  
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode,   
               @cMUID         OUTPUT, @cSKU           OUTPUT, @nQTY           OUTPUT, @cDropID        OUTPUT,  
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,  
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,  
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,  
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,                 
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Quit  
               --insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5) values  
               --('864', getdate(), @cUserDefine01, @cSKU, @cMUID, @cUserDefine03, @cUserDefine02)  
         END  
      END   -- End for DecodeSP  
  
      -- Check id format (james02)  
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'MUID', @cMUID) = 0  
      BEGIN  
         SET @nErrNo = 102651  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO Step_1_Fail  
      END  
  
      --check diff storer  
      IF NOT EXISTS ( SELECT 1   
         FROM dbo.PickDetail WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))  
         WHERE ID = @cMUID  
           AND Storerkey = @cStorerkey)  
      BEGIN  
         SET @nErrNo = 67328  
         SET @cErrMsg = rdt.rdtgetmessage( 67328, @cLangCode, 'DSP') --Diff storer  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
         GOTO Step_1_Fail      
      END  
  
      --check for MUID Status = 0  
      IF NOT EXISTS ( SELECT 1   
         FROM dbo.PickDetail WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))  
         WHERE ID = @cMUID  
           AND Storerkey = @cStorerkey  
           AND QTY > 0  
           AND Status = '0')  
      BEGIN  
         SET @nErrNo = 67327  
         SET @cErrMsg = rdt.rdtgetmessage( 67327, @cLangCode, 'DSP') --Invalid MUID  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey  
         GOTO Step_1_Fail      
      END  
  
      --check diff facility  
      IF NOT EXISTS ( SELECT 1   
         FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))  
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.Storerkey = OD.Storerkey)  -- (Vicky01)  
         JOIN dbo.ORDERS O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey)  -- (Vicky01)  
         WHERE PD.ID = @cMUID  
           AND PD.Storerkey = @cStorerkey  
           --AND O.Storerkey = @cStorerkey  -- (Vicky01)  
           AND O.Facility = @cFacility)  
      BEGIN  
         SET @nErrNo = 67329  
         SET @cErrMsg = rdt.rdtgetmessage( 67329, @cLangCode, 'DSP') --Diff facility  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
         GOTO Step_1_Fail      
      END  
  
      --Check if MUID exists in more than 1 PickDetail.LOC  
      SELECT @nLOCCnt = COUNT(DISTINCT LOC)  
      FROM dbo.PickDetail WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))  
      WHERE ID = @cMUID  
        AND Storerkey = @cStorerkey  
      IF ISNULL(@nLOCCnt, 0) > 1  
      BEGIN  
         SET @nErrNo = 67330  
         SET @cErrMsg = rdt.rdtgetmessage( 67330, @cLangCode, 'DSP') --Multi LOC  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
         GOTO Step_1_Fail      
      END  
  
      --Check if MUID is on hold  
      IF EXISTS ( SELECT 1   
         FROM dbo.ID WITH (NOLOCK)  
         WHERE ID = @cMUID  
           AND STATUS = 'HOLD')  
      BEGIN  
         SET @nErrNo = 67331  
         SET @cErrMsg = rdt.rdtgetmessage( 67331, @cLangCode, 'DSP') --MUID on Hold  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
         GOTO Step_1_Fail      
      END  
  
      --check Orders Status < 3  
      IF EXISTS ( SELECT 1   
         FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))  
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.Storerkey = OD.Storerkey)  -- (Vicky01)  
         JOIN dbo.ORDERS O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey)  -- (Vicky01)  
         WHERE PD.ID = @cMUID  
           AND PD.Storerkey = @cStorerkey  
           --AND O.Storerkey = @cStorerkey  
           AND O.Status <= '3')  
      BEGIN  
         UPDATE dbo.ORDERS WITH (ROWLOCK) SET   
            Status = '3',  
            TrafficCop = NULL,   
            EditDate = GetDate(),   
            EditWho  = sUser_sName()   
         FROM dbo.ORDERS O   
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey AND PD.Storerkey = O.Storerkey)  -- (Vicky01)  
         WHERE PD.ID = @cMUID  
           AND PD.Storerkey = @cStorerkey  
           AND O.Status < '3'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 67332  
            SET @cErrMsg = rdt.rdtgetmessage( 67332, @cLangCode, 'DSP') --'UpdOrdersFail'  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
            GOTO Step_1_Fail  
         END  
  
         UPDATE dbo.ORDERDetail WITH (ROWLOCK) SET   
            Status = '3',  
            TrafficCop = NULL,   
            EditDate = GetDate(),   
            EditWho  = sUser_sName()   
         FROM dbo.ORDERDetail OD   
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.Storerkey = OD.Storerkey AND PD.OrderLinenumber = OD.OrderLineNumber)  -- (Vicky01)  
         WHERE PD.ID = @cMUID  
           AND PD.Storerkey = @cStorerkey  
           AND OD.Status < '3'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 67333  
            SET @cErrMsg = rdt.rdtgetmessage( 67333, @cLangCode, 'DSP') --'UpdOdrDtlFail'  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
            GOTO Step_1_Fail  
         END  
      END  
      ELSE  
      BEGIN  
         SET @nErrNo = 67334  
         SET @cErrMsg = rdt.rdtgetmessage( 67334, @cLangCode, 'DSP') --Orders Status>3  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
         GOTO Step_1_Fail      
      END  
  
      --check LoadPlan Status < 3  
      IF EXISTS ( SELECT 1   
         FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))  
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND OD.Storerkey = PD.Storerkey)  -- (Vicky01)  
         JOIN dbo.ORDERS O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey)  -- (Vicky01)  
         JOIN dbo.LoadPlan LP (NOLOCK) ON (O.LoadKey = LP.LoadKey)  
         WHERE PD.ID = @cMUID  
           AND PD.Storerkey = @cStorerkey  
        --   AND O.Storerkey = @cStorerkey  -- (Vicky01)  
           AND LP.Status <= '3')  
      BEGIN  
         UPDATE dbo.LoadPlan WITH (ROWLOCK) SET   
            Status = '3',  
            TrafficCop = NULL,   
            EditDate = GetDate(),   
            EditWho  = sUser_sName()   
         FROM dbo.LoadPlan LP   
         JOIN dbo.ORDERS O WITH (NOLOCK) ON (O.LoadKey = LP.LoadKey)  
         JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID)) ON (PD.OrderKey = O.OrderKey AND PD.Storerkey = O.Storerkey)  -- (Vicky01)  
         WHERE PD.ID = @cMUID  
           AND PD.Storerkey = @cStorerkey  
           AND LP.Status < '3'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 67335  
            SET @cErrMsg = rdt.rdtgetmessage( 67335, @cLangCode, 'DSP') --'UpdLdPlanFail'  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
            GOTO Step_1_Fail  
         END  
  
         UPDATE dbo.LoadPlanDetail WITH (ROWLOCK) SET   
            Status = '3',  
            TrafficCop = NULL,   
            EditDate = GetDate(),   
            EditWho  = sUser_sName()   
         FROM dbo.LoadPlanDetail LPD   
         JOIN dbo.ORDERS O (NOLOCK) ON (O.LoadKey = LPD.LoadKey  
                                            AND O.OrderKey = LPD.OrderKey)  
         JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID)) ON (PD.OrderKey = O.OrderKey AND PD.Storerkey = O.Storerkey)  -- (Vicky01)  
         WHERE PD.ID = @cMUID  
           AND PD.Storerkey = @cStorerkey  
           AND LPD.Status < '3'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 67336  
            SET @cErrMsg = rdt.rdtgetmessage( 67336, @cLangCode, 'DSP') --'UpdLPDtlFail'  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
            GOTO Step_1_Fail  
         END  
      END  
/* 31-Jul-09: Requested Remove thsi checking  
      ELSE  
      BEGIN  
         SET @nErrNo = 67337  
         SET @cErrMsg = rdt.rdtgetmessage( 67337, @cLangCode, 'DSP') --LoadPlan Sts>3  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
         GOTO Step_1_Fail      
      END  
*/  
      -- If config turned on then check whether user change consignee. If yes then need verify again  
      IF @cVerifyStor = '1' AND @nStorVerified = 1 AND   
         @cConsigneeKey <> @cUserDefine01 --AND  
         --@cConsigneeKey = ''  
            SET @cUserDefine01 = ''  
  
      SELECT TOP 1   
             @cLOC = PD.LOC,   
             @cConsigneeKey = O.ConsigneeKey   
      FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))  
      JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.Storerkey = OD.Storerkey)  -- (Vicky01)  
      JOIN dbo.ORDERS O (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey)  -- (Vicky01)  
      WHERE PD.ID = @cMUID  
        AND PD.Storerkey = @cStorerkey  
        AND PD.STATUS = '0'  
        AND (( ISNULL( @cUserDefine01, '') = '') OR ( O.ConsigneeKey = @cUserDefine01))  
      ORDER BY O.ConsigneeKey   
  
      SET @cPrevConsigneeKey = CASE WHEN ISNULL( @cConsigneeKey, '') <> '' THEN @cConsigneeKey ELSE '' END  
  
      Step_1_Next:    
  
      -- If config turned on then need verify stor for at least 1 time  
      IF @cVerifyStor = '1' AND @nStorVerified = 0 AND @cUserDefine01 <> ''  
         SET @cUserDefine01 = ''  
  
      --prepare next screen variable  
      SET @cOutField01 = @cMUID  
      SET @cOutField02 = @cLOC  
      SET @cOutField03 = @cConsigneeKey  
      SET @cOutField04 = ''  
  
      SET @cInField04  = ''  
                    
      -- Go to next screen  
      SET @nScn  = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Reset drop id value if ESC  
      SET @cDropID = ''  
  
      IF ISNULL(@cMUID, '') = ''  
      BEGIN  
         SET @cBALQty = '0'  
         SET @cACTQty = '0'  
      END  
      ELSE  
      BEGIN  
         SELECT @cBALQty = CONVERT(VARCHAR(5), ISNULL(SUM(PD.QTY), 0))  
         FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))  
         WHERE PD.ID = @cMUID  
           AND PD.Storerkey = @cStorerkey  
           AND PD.Status = '0'  
  
         SELECT @cACTQty = CONVERT(VARCHAR(5), ISNULL(SUM(PD.QTY), 0))  
         FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))  
         WHERE PD.ID = @cMUID  
           AND PD.Storerkey = @cStorerkey  
           AND PD.Status = @cPickConfirmStatus  
      END  
  
      SET @cOutField01 = @cBALQty   
      SET @cOutField02 = @cACTQty   
      SET @cOutField03 = '' -- Option  
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Option  
  
      -- Back to menu  
      SET @nScn  = @nScn + 4  
      SET @nStep = @nStep + 4  
  
      GOTO Quit  
   END  
  
   IF ISNULL( @cUserDefine01, '') <> ''  
   BEGIN  
      SET @cInField04 = @cUserDefine01  
      SET @cDirectFlowThruScn = 'Y'  
      GOTO Step_2  
   END  
   ELSE  
      GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
      SET @cLOC          = ''  
      SET @cConsigneeKey = ''  
      SET @cMax = ''  
  
      -- Reset this screen var  
      SET @cOutField02 = ''  -- LOC  
      SET @cOutField03 = ''  -- ConsigneeKey  
  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 2. (screen = 2061) Scan-in the STOR  
   MUID:  
   (Field01)      -- MUID  
   LOC:  (Field02)   
   STOR: (Field03)  
   STOR: (Field04, input)  
   
   ENTER =  Next Page  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cScanConsigneeKey = @cInField04  
  
      --When STOR is blank  
      IF @cScanConsigneeKey = ''  
      BEGIN  
         SET @nErrNo = 67338  
         SET @cErrMsg = rdt.rdtgetmessage( 67338, @cLangCode, 'DSP') --STOR needed  
         GOTO Step_2_Fail    
      END   
  
      -- (james02)  
      IF @cDecodeSP <> ''  
      BEGIN  
         SET @cBarcode = @cInField04  
         --SET @cUserDefine01 = ''  
  
         -- Standard decode  
         IF @cDecodeSP = '1'  
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,   
               @cMUID         OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,   
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,  
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,  
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,  
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,  
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT  
         -- Customize decode  
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +  
               ' @cID            OUTPUT, @cSKU           OUTPUT, @nQTY           OUTPUT, @cDropID        OUTPUT, ' +  
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
               ' @cBarcode       NVARCHAR( 2000), ' +  
               ' @cID            NVARCHAR( 18)  OUTPUT, ' +  
               ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +  
               ' @nQTY           INT            OUTPUT, ' +  
               ' @cDropID        NVARCHAR( 20)  OUTPUT, ' +  
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode,   
               @cMUID         OUTPUT, @cSKU           OUTPUT, @nQTY           OUTPUT, @cDropID        OUTPUT,  
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,  
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,  
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,  
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,                 
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT  
  
            SET @cScanConsigneeKey = CASE WHEN @cUserDefine01 = '' THEN @cInfield04 ELSE @cUserDefine01 END  
            SET @cSKUCode = @cSKU  
            SET @nSKUQTY = @nQTY  
         END  
      END   -- End for DecodeSP  
  
      --Validate for same STOR   
      IF ISNULL(RTRIM(@cConsigneeKey),'') <> ISNULL(RTRIM(@cScanConsigneeKey),'')  
      BEGIN  
         SET @nErrNo = 67339  
         SET @cErrMsg = rdt.rdtgetmessage( 67339, @cLangCode, 'DSP') --Invalid STOR  
         GOTO Step_2_Fail    
      END  
  
      -- Check consigneekey format (james02)  
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'STOR', @cConsigneeKey) = 0  
      BEGIN  
         SET @nErrNo = 102652  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO Step_2_Fail  
      END  
  
      -- If config turn on then go to screen scan sku (james02)  
      IF rdt.RDTGetConfig( @nFunc, 'PickToDropIDScanSKU', @cStorerKey) = '1'  
      BEGIN  
         SET @nStorVerified = 1  
         SET @cOutField01 = @cConsigneeKey  
         SET @cOutField02 = ''  
           
         SET @nScn = @nScn + 4  
         SET @nStep = @nStep + 4           
  
         GOTO Quit  
      END  
        
      -- Get prefer UOM  
      SELECT @cDefaultUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA  
      FROM RDT.rdtMobRec M (NOLOCK)  
         INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)  
      WHERE M.Mobile = @nMobile  
  
      SET ROWCOUNT 1  
      SELECT @cSKU            = SKU.SKU,   
             @cSKUDesc        = SKU.DESCR,   
             @cLottable01     = LA.Lottable01,   
             @cLottable02     = LA.Lottable02,   
             @cLottable03     = LA.Lottable03,   
             @dLottable04     = LA.Lottable04,  
           @cPackUOM3       = PACK.PackUOM3,  
             @cDefaultUOMDesc = CASE @cDefaultUOM  
                               WHEN '2' THEN PACK.PackUOM1 -- Case  
                               WHEN '3' THEN PACK.PackUOM2 -- Inner pack  
                               WHEN '6' THEN PACK.PackUOM3 -- Master unit  
                               WHEN '1' THEN PACK.PackUOM4 -- Pallet  
                               WHEN '4' THEN PACK.PackUOM8 -- Other unit 1  
                               WHEN '5' THEN PACK.PackUOM9 -- Other unit 2  
                            END,  
           @cDefaultUOMDIV  = CAST( IsNULL(  
                            CASE @cDefaultUOM  
                               WHEN '2' THEN PACK.CaseCNT  
                               WHEN '3' THEN PACK.InnerPack  
                               WHEN '6' THEN PACK.QTY  
                               WHEN '1' THEN PACK.Pallet  
                               WHEN '4' THEN PACK.OtherUnit1  
                               WHEN '5' THEN PACK.OtherUnit2  
                            END, 1) AS INT),  
             @nQTY            = SUM(PD.QTY)  
      FROM dbo.PickDetail PD (NOLOCK)   
      JOIN dbo.SKU SKU (NOLOCK) ON (SKU.StorerKey = PD.Storerkey AND PD.SKU = SKU.SKU)  -- (Vicky01)  
      JOIN dbo.PACK PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
      JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT AND PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU)  -- (Vicky01)  
      JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.Storerkey = OD.Storerkey AND PD.OrderLineNumber = OD.OrderLineNumber) -- (Vicky01)  
      JOIN dbo.ORDERS O (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey) -- (Vicky01)  
      WHERE PD.ID = @cMUID  
      AND PD.Storerkey = @cStorerkey  
      AND PD.STATUS = '0'  
      AND PD.QTY > 0  
      AND O.ConsigneeKey = @cConsigneeKey  
      -- (james02)  
      -- If decoded return sku then filter with the decoded sku to get the desired result  
      AND SKU.SKU = CASE WHEN ISNULL( @cSKUCode, '') <> '' THEN @cSKUCode ELSE SKU.SKU END  
      GROUP BY SKU.SKU,   
               SKU.DESCR,   
               LA.Lottable01,   
               LA.Lottable02,   
               LA.Lottable03,   
               LA.Lottable04,  
             PACK.PackUOM3,  
               CASE @cDefaultUOM  
              WHEN '2' THEN PACK.PackUOM1 -- Case  
              WHEN '3' THEN PACK.PackUOM2 -- Inner pack  
              WHEN '6' THEN PACK.PackUOM3 -- Master unit  
              WHEN '1' THEN PACK.PackUOM4 -- Pallet  
              WHEN '4' THEN PACK.PackUOM8 -- Other unit 1  
              WHEN '5' THEN PACK.PackUOM9 -- Other unit 2  
           END,  
             CAST( IsNULL(  
           CASE @cDefaultUOM  
              WHEN '2' THEN PACK.CaseCNT  
              WHEN '3' THEN PACK.InnerPack  
              WHEN '6' THEN PACK.QTY  
              WHEN '1' THEN PACK.Pallet  
              WHEN '4' THEN PACK.OtherUnit1  
              WHEN '5' THEN PACK.OtherUnit2  
           END, 1) AS INT)  
      ORDER BY SKU.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04  
      SET ROWCOUNT 0  
  
      IF @cDefaultUOM < '6'   
      BEGIN  
         IF ISNULL(@cDefaultUOMDIV,'') = '' OR @cDefaultUOMDIV = '0'  
         BEGIN  
            SET @nErrNo = 67340  
            SET @cErrMsg = rdt.rdtgetmessage( 67340, @cLangCode, 'DSP') --Invalid PackQTY  
            GOTO Step_2_Fail    
         END  
  
         -- Initialise value (james02)  
         SET @cDefaultUOMSKUQTY = ''  
         SET @cPackUOM3SKUQTY = ''  
  
         -- Calc QTY in DefaultUOM  
         SET @cDefaultUOMQTY = CONVERT(VARCHAR(5), @nQTY/CONVERT(INT, @cDefaultUOMDIV))  
         SET @cDefaultUOMSKUQTY = CONVERT(VARCHAR(5), @nSKUQTY/CONVERT(INT, @cDefaultUOMDIV))  
          
         -- Calc the Balance QTY in PackUOM3  
         SET @cPackUOM3QTY = CONVERT(VARCHAR(5), @nQTY % CONVERT(INT, @cDefaultUOMDIV))  
         SET @cPackUOM3SKUQTY = CONVERT(VARCHAR(5), @nSKUQTY % CONVERT(INT, @cDefaultUOMDIV))  
      END  
      ELSE  
      BEGIN  
         SET @cDefaultUOMDesc = ''  
         SET @cDefaultUOMQTY  = ''  
         SET @cPackUOM3QTY    = CONVERT(VARCHAR(5), @nQTY)  
         SET @cInField14      = ''  
           
         -- (james02)  
         SET @cPackUOM3SKUQTY = @nSKUQTY  
      END  
  
      Step_2_Next:  
      --prepare next screen variable  
      SET @cOutField01 = @cConsigneeKey  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = SUBSTRING(@cSKUDesc,1,20)  
      SET @cOutField04 = SUBSTRING(@cSKUDesc,21,20)  
      SET @cOutField05 = @cLottable01        SET @cOutField06 = @cLottable02  
      SET @cOutField07 = @cLottable03  
      SET @cOutField08 = rdt.rdtFormatDate(@dLottable04)  
      SET @cOutField09 = @cDefaultUOMDIV  
      SET @cOutField10 = @cDefaultUOMDesc  
      SET @cOutField11 = @cPackUOM3  
      SET @cOutField12 = @cDefaultUOMQTY  
      SET @cOutField13 = @cPackUOM3QTY  
      SET @cOutField14 = CASE WHEN ISNULL( @cDefaultUOMSKUQTY, '') <> '' THEN @cDefaultUOMSKUQTY ELSE '' END  
      SET @cOutField15 = CASE WHEN ISNULL( @cPackUOM3SKUQTY, '') <> '' THEN @cPackUOM3SKUQTY ELSE '' END  
  
      SET @cInField14  = '' -- KeyDefaultUOMQTY  
      SET @cInField15  = '' -- KeyPackUOM3QTY  
        
      IF ISNULL(@cDefaultUOMQTY,'') = ''   
      BEGIN  
         SET @cFieldAttr14 = 'O' -- KeyDefaultUOMQTY  
         SET @cOutField14  = ''  
      END  
  
      SET @nStorVerified = 1  
  
      -- Go to next screen  
      SET @nScn  = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare prev screen var  
      SET @cLOC               = ''  
      SET @cConsigneeKey      = ''  
      SET @cScanConsigneeKey  = ''  
      SET @cOutField01        = '' -- MUID  
      SET @cFieldAttr14       = '' -- KeyDefaultUOMQTY  
      SET @cMax = ''  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
  
      -- go to previous screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
  
      GOTO Quit  
   END  
  
   IF ISNULL( @nQty, -1) <> -1  
   BEGIN  
      IF @cDefaultUOM < '6'  
      BEGIN  
         SET @cInField14 = @cDefaultUOMSKUQTY  
         SET @cInField15 = @cPackUOM3SKUQTY  
      END  
      ELSE  
         SET @cInField15 = @cPackUOM3SKUQTY  
  
      GOTO Step_3  
   END  
   ELSE  
      GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      SET @cScanConsigneeKey  = ''  
      SET @cOutField01        = @cMUID  
      SET @cOutField02        = @cLOC  
      SET @cOutField03        = @cConsigneeKey  
      SET @cOutField04        = '' -- ScanConsigneeKey  
      SET @cFieldAttr14       = '' -- KeyDefaultUOMQTY  
      SET @cOutField14        = ''  
   END    
END  
GOTO Quit  
  
/********************************************************************************  
Step 3. (screen = 2062) Key-in the ACT QTY picked in its corresponding UOM column  
   STOR: (Field01)  
   SKU:    
   (Field02)                                       -- SKU  
   (Field03)                                       -- SKUDesc (Len  1-20)  
   (Field04)                                       -- SKUDesc (Len 21-40)  
   1 (Field05)                                     -- Lottable01   
   2 (Field06)                                     -- Lottable02  
   3 (Field07)                                     -- Lottable03   
   4 (Field08)                                     -- Lottable04  
   1:(Field09)  (Field10)        (Field11)         -- DefaultUOMDIV     -- DefaultUOMDesc  -- PackUOM3  
   BAL QTY:     (Field12)        (Field13)         -- DefaultUOMQTY     -- PackUOM3QTY  
   ACT QTY:     (Field14, input) (Field15, input)  -- KeyDefaultUOMQTY  -- KeyPackUOM3QTY  
   
   ENTER =  Next Page  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cKeyDefaultUOMQTY = @cInField14  
      SET @cKeyPackUOM3QTY   = @cInField15  
      /*  
      IF ISNULL(@cKeyDefaultUOMQTY,'') = ''   
      BEGIN  
         IF ISNULL(@cDefaultUOMQTY,'') = ''   
         BEGIN  
            SET @cKeyDefaultUOMQTY = ''  
         END  
         ELSE  
         BEGIN  
            SET @cKeyDefaultUOMQTY = '0'  
         END  
      END  
      */  
      -- Blank taken as 0 (james02)  
      IF ISNULL(@cKeyDefaultUOMQTY,'') = ''   
      BEGIN  
         SET @cKeyDefaultUOMQTY = '0'  
      END  
  
      IF ISNULL(@cKeyPackUOM3QTY,'') = ''   
      BEGIN  
         SET @cKeyPackUOM3QTY = '0'  
      END  
  
      -- (Vicky01)   
      IF (RDT.rdtIsValidQTY( @cKeyDefaultUOMQTY, 0) = 0) OR   
         (RDT.rdtIsValidQTY( @cKeyPackUOM3QTY, 0) = 0)   
    BEGIN  
         SET @nErrNo = 67341  
         SET @cErrMsg = rdt.rdtgetmessage( 67341, @cLangCode, 'DSP') --Invalid QTY  
         GOTO Step_3_Fail      
      END  
  
--      IF (CHARINDEX('.',@cKeyDefaultUOMQTY) > 0) OR   -- Validate Decimal Value  
--         (CHARINDEX('.',@cKeyPackUOM3QTY) > 0)        -- Validate Decimal Value  
--      BEGIN  
--         SET @nErrNo = 67341  
--         SET @cErrMsg = rdt.rdtgetmessage( 67341, @cLangCode, 'DSP') --Invalid QTY  
--         GOTO Step_3_Fail             
--      END  
--  
--      IF ISNULL(@cKeyDefaultUOMQTY,'') <> ''   
--      BEGIN  
--         IF (ISNUMERIC(@cKeyDefaultUOMQTY) = 0) OR       -- Validate Numeric  
--            (@cKeyDefaultUOMQTY < '0')                   -- Validate Negative VaLue  
--         BEGIN  
--            SET @nErrNo = 67341  
--            SET @cErrMsg = rdt.rdtgetmessage( 67341, @cLangCode, 'DSP') --Invalid QTY  
--            GOTO Step_3_Fail             
--         END  
--      END  
--  
--      IF (ISNUMERIC(@cKeyPackUOM3QTY) = 0) OR         -- Validate Numeric  
--         (@cKeyPackUOM3QTY < '0')                     -- Validate Negative VaLue  
--      BEGIN  
--         SET @nErrNo = 67341  
--         SET @cErrMsg = rdt.rdtgetmessage( 67341, @cLangCode, 'DSP') --Invalid QTY  
--         GOTO Step_3_Fail             
--      END  
     
      SET @nQTY_Act = CONVERT(INT, @cKeyDefaultUOMQTY) * CONVERT(INT, @cDefaultUOMDIV) +   
                      CONVERT(INT, @cKeyPackUOM3QTY)  
  
      IF @nQTY_Act > @nQTY                       
      BEGIN  
         SET @nErrNo = 67342  
         SET @cErrMsg = rdt.rdtgetmessage( 67342, @cLangCode, 'DSP') --Over pick  
         GOTO Step_3_Fail             
      END  
  
      Step_3_Next:  
      --prepare next screen variable  
      SET @cOutField01 = @cConsigneeKey  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = SUBSTRING(@cSKUDesc,1,20)  
      SET @cOutField04 = SUBSTRING(@cSKUDesc,21,20)  
      SET @cOutField05 = @cDefaultUOMDIV  
      SET @cOutField06 = @cDefaultUOMDesc  
      SET @cOutField07 = @cPackUOM3  
      SET @cOutField08 = @cDefaultUOMQTY  
      SET @cOutField09 = @cPackUOM3QTY  
      SET @cOutField10 = @cKeyDefaultUOMQTY  
      SET @cOutField11 = @cKeyPackUOM3QTY  
      SET @cOutField12 = @cDropID  
  
      SET @cInField12  = '' -- DropID  
  
      -- Go to next screen  
      SET @nScn  = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      IF rdt.RDTGetConfig( @nFunc, 'PickToDropIDScanSKU', @cStorerKey) = '1'  
      BEGIN  
         SET @cOutField01 = @cConsigneeKey  
         SET @cOutField02 = ''  
  
         -- go to previous screen  
         SET @nScn = @nScn + 3  
         SET @nStep = @nStep + 3  
      END  
      ELSE  
      BEGIN  
         -- Prepare prev screen var  
         SET @cScanConsigneeKey  = ''  
         SET @cDefaultUOM        = ''  
         SET @cSKU               = ''  
         SET @cSKUDesc           = ''  
         SET @cLottable01        = ''  
         SET @cLottable02        = ''  
         SET @cLottable03        = ''  
         SET @dLottable04        = ''  
         SET @cDefaultUOMDIV     = ''  
         SET @cDefaultUOMDesc    = ''  
         SET @cPackUOM3          = ''  
         SET @cDefaultUOMQTY     = ''  
         SET @cPackUOM3QTY       = ''  
  
         SET @cOutField01        = @cMUID  
         SET @cOutField02        = @cLOC  
         SET @cOutField03        = @cConsigneeKey  
         SET @cOutField04        = '' -- ScanConsigneeKey  
  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ScanConsigneeKey  
  
         -- go to previous screen  
         SET @nScn = @nScn - 1  
         SET @nStep = @nStep - 1  
      END  
  
      GOTO Quit  
   END  
  
   IF ISNULL( @cDropID, '') <> ''  
   BEGIN  
      SET @cInField12 = @cDropID  
      GOTO Quit  
   END  
   ELSE  
      GOTO Quit  
  
   Step_3_Fail:  
   BEGIN  
      SET @cKeyDefaultUOMQTY  = ''  
      SET @cKeyPackUOM3QTY    = ''  
      SET @cOutField01        = @cConsigneeKey  
      SET @cOutField02        = @cSKU  
      SET @cOutField03        = SUBSTRING(@cSKUDesc,1,20)  
      SET @cOutField04        = SUBSTRING(@cSKUDesc,21,20)  
      SET @cOutField05        = @cLottable01  
      SET @cOutField06        = @cLottable02  
      SET @cOutField07        = @cLottable03  
      SET @cOutField08        = rdt.rdtFormatDate(@dLottable04)  
      SET @cOutField09        = @cDefaultUOMDIV  
      SET @cOutField10        = @cDefaultUOMDesc  
      SET @cOutField11        = @cPackUOM3  
      SET @cOutField12        = @cDefaultUOMQTY  
      SET @cOutField13        = @cPackUOM3QTY  
   END    
END  
GOTO Quit  
  
/********************************************************************************  
Step 4. (screen = 2063) Scan-in the Drop ID  
   STOR: (Field01)  
   SKU:    
   (Field02)                                       -- SKU  
   (Field03)                                       -- SKUDesc (Len  1-20)  
   (Field04)                                       -- SKUDesc (Len 21-40)  
  
   1:(Field05)  (Field06)        (Field07)         -- DefaultUOMDIV     -- DefaultUOMDesc  -- PackUOM3  
   BAL QTY:     (Field08)        (Field09)         -- DefaultUOMQTY     -- PackUOM3QTY  
   ACT QTY:     (Field10)        (Field11)         -- KeyDefaultUOMQTY  -- KeyPackUOM3QTY  
   DROP ID:  
   (Field14, input)                                -- DropID  
  
   ENTER =  Next Page  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cDropID = @cInField12  
        
      -- StorerConfig For C4 Validation of Drop ID -- SOS#156663  
      SET @cC4DropID = rdt.RDTGetConfig( @nFuncStorerConfig, 'ValidateDropIDC4', @cStorerKey)  
        
      IF @cC4DropID = 1   
      BEGIN  
            IF CharIndex ('C4',LEFT(RTrim(@cDropID),2),1) = 0 OR LEN(RTrim(@cDropID)) <> 10    
            BEGIN  
               SET @nErrNo = 67350  
               SET @cErrMsg = rdt.rdtgetmessage( 67350, @cLangCode, 'DSP') --Invalid DropID  
               EXEC rdt.rdtSetFocusField @nMobile, 1  
               GOTO Step_4_Fail  
            END  
      END    
        
      --When DropID is blank  
      IF @cDropID = ''  
      BEGIN  
         SET @nErrNo = 67343  
         SET @cErrMsg = rdt.rdtgetmessage( 67343, @cLangCode, 'DSP') --Drop ID req  
         GOTO Step_4_Fail    
      END   
      ELSE  
      BEGIN  
         -- Check drop id format (james02)  
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DropID', @cDropID) = 0  
         BEGIN  
            SET @nErrNo = 102653  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
            GOTO Step_4_Fail  
         END  
  
         IF EXISTS(SELECT 1  
                  FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID))  
                  JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.Storerkey = OD.Storerkey) -- (Vicky01)  
                  JOIN dbo.ORDERS O (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey) -- (Vicky01)  
                  WHERE PD.DropID = @cDropID  
                  AND PD.Storerkey = @cStorerkey  
                  AND O.Storerkey = @cStorerkey  
                  AND O.ConsigneeKey <> @cConsigneeKey)  
         BEGIN  
            SET @nErrNo = 67344  
            SET @cErrMsg = rdt.rdtgetmessage( 67344, @cLangCode, 'DSP') --Drop ID used  
            GOTO Step_4_Fail     
         END  
  
         IF @cExtendedValidateSP <> '' AND  
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cID, @cConsigneeKey, @cSKU, @nQty, @cDropID,' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               '@nMobile   INT,           ' +  
               '@nFunc           INT,           ' +  
               '@nStep           INT,           ' +  
               '@nInputKey       INT,           ' +  
               '@cLangCode       NVARCHAR( 3),  ' +  
               '@cStorerkey      NVARCHAR( 15), ' +  
               '@cID             NVARCHAR( 18), ' +  
               '@cConsigneeKey   NVARCHAR( 15), ' +  
               '@cSKU            NVARCHAR( 20), ' +  
               '@nQty            INT,           ' +  
               '@cDropID         NVARCHAR( 20), ' +  
               '@nErrNo          INT           OUTPUT, ' +  
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                 @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cMUID, @cConsigneeKey, @cSKU, @nQty, @cDropID,  
                 @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_4_Fail  
         END  
  
         SET @nTranCount = @@TRANCOUNT  
         BEGIN TRAN  -- Begin our own transaction  
         SAVE TRAN Step_4 -- For rollback or commit only our own transaction  
  
         IF (CONVERT(INT, @cKeyDefaultUOMQTY) < CONVERT(INT, @cDefaultUOMQTY)) OR (CONVERT(INT, @cKeyPackUOM3QTY) < CONVERT(INT, @cPackUOM3QTY))  
         BEGIN  
            SET @nCount   = 0  
            SET @nQTY_Act = CONVERT(INT, @cKeyDefaultUOMQTY) * CONVERT(INT, @cDefaultUOMDIV) +   
                            CONVERT(INT, @cKeyPackUOM3QTY)  
  
            SET @nPackQty = @nQTY_Act  
  
            SET @cPDStatus = CASE WHEN @cNotAutoShortPick = '1' THEN '0' ELSE '4' END  
  
            -- Get PickDetail candidate  
            DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
            SELECT PickDetailKey, QTY  
            FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))  
            JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.Storerkey = OD.Storerkey) -- (Vicky01)  
            JOIN dbo.ORDERS O (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey) -- (Vicky01)  
            WHERE PD.ID          = @cMUID  
              AND PD.Storerkey   = @cStorerkey  
              --AND O.Storerkey    = @cStorerkey -- (Vicky01)  
              AND PD.STATUS      = '0'  
              AND PD.QTY         > 0  
              AND PD.SKU         = @cSKU  
              AND O.ConsigneeKey = @cConsigneeKey  
            ORDER BY PD.PickDetailKey  
  
            OPEN curPD  
            FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD   
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               IF @nCount = 0  
               BEGIN  
                  IF @nQTY_Act > @nQTY_PD  
                  BEGIN  
                     SET @nQTY_Act = @nQTY_Act - @nQTY_PD  
  
                     SET @d_step1 = GETDATE()   
                     -- Confirm PickDetail  
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
                        DropID = @cDropID,  
                        Status = @cPickConfirmStatus,  
                        EditDate = GetDate(),   
                        EditWho  = sUser_sName()   
                     WHERE PickDetailKey = @cPickDetailKey  
  
                     SET @d_step1 = GETDATE() - @d_step1  
                     SET @c_col1 = 'QAct>QPD'  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 67345  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'  
                        GOTO Step_4_RollBack  
                     END  
                     ELSE  
                     BEGIN  
                          -- (Vicky06) EventLog - QTY  
                          EXEC RDT.rdt_STD_EventLog  
                             @cActionType   = '3', -- Picking  
                             @cUserID       = @cUserName,  
                             @nMobileNo     = @nMobile,  
                             @nFunctionID   = @nFunc,  
                             @cFacility     = @cFacility,  
                             @cStorerKey    = @cStorerkey,  
                             --@cLocation     = @cLOC,  
                             @cID           = @cMUID,  
                             @cSKU          = @cSKU,  
                             @cUOM          = @cPackUOM3,  
                             @nQTY          = @nQTY_PD,  
                             @cConsigneeKey = @cConsigneeKey,  
                             @cDropID       = @cDropID,
                             @nStep         = @nStep  
                     END  
                  END  
                  ELSE IF @nQTY_Act = @nQTY_PD  
                  BEGIN  
                     SET @nQTY_Act = @nQTY_Act - @nQTY_PD  
  
                     SET @d_step1 = GETDATE()  
  
                     -- Confirm PickDetail  
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
                        DropID = @cDropID,  
                        Status = @cPickConfirmStatus,  
                        EditDate = GetDate(),   
                        EditWho  = sUser_sName()   
                     WHERE PickDetailKey = @cPickDetailKey  
  
                     SET @d_step1 = GETDATE() - @d_step1  
                     SET @c_col1 = 'QAct=QPD'  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 67345  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'  
                        GOTO Step_4_RollBack  
                     END  
                     ELSE  
                     BEGIN  
                          -- (Vicky06) EventLog - QTY  
                          EXEC RDT.rdt_STD_EventLog  
                             @cActionType   = '3', -- Picking  
                             @cUserID       = @cUserName,  
                             @nMobileNo     = @nMobile,  
                             @nFunctionID   = @nFunc,  
                             @cFacility     = @cFacility,  
                             @cStorerKey    = @cStorerkey,  
                             --@cLocation     = @cLOC,  
                             @cID           = @cMUID,  
                             @cSKU          = @cSKU,  
                             @cUOM          = @cPackUOM3,  
                             @nQTY          = @nQTY_PD,  
                             @cConsigneeKey = @cConsigneeKey,  
                             @cDropID       = @cDropID,
                             @nStep         = @nStep  
                     END  
                  END  
                  ELSE IF @nQTY_Act < @nQTY_PD AND @nQTY_Act <> 0  
                  BEGIN  
                     SET @nQTY_Bal = @nQTY_PD - @nQTY_Act  
                     SET @nCount   = 1  
                     SET @cPrePickDetailKey = @cPickDetailKey  
  
                     SET @d_step1 = GETDATE()  
  
                     -- Get new PickDetailkey  
                     DECLARE @cNewPickDetailKey NVARCHAR(10)  
                     EXECUTE dbo.nspg_GetKey  
                        'PICKDETAILKEY',   
                        10 ,  
                        @cNewPickDetailKey OUTPUT,  
                        @b_success         OUTPUT,  
                        @n_err             OUTPUT,  
                        @c_errmsg          OUTPUT  
                     IF @b_success <> 1  
                     BEGIN  
                        SET @nErrNo = 67346  
                        SET @cErrMsg = rdt.rdtgetmessage( 67346, @cLangCode, 'DSP') -- 'GetPDtlKeyFail'  
                        GOTO Step_4_Fail  
                     END  
  
                     -- Create new a PickDetail to hold the balance  
                     INSERT INTO dbo.PICKDETAIL (  
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,   
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,   
                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
                       EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,   
                        PickDetailKey,   
                        QTY,   
                        --TrafficCop,  
                        OptimizeCop)  
                     SELECT   
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,   
                        UOMQTY, QTYMoved, @cPDStatus AS Status,   
                        DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,   
                        CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,   
                        @cNewPickDetailKey,   
                        @nQTY_Bal, -- QTY  
                        --NULL, --TrafficCop,    
                        '1'  --OptimizeCop  
                     FROM dbo.PickDetail WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))   
               WHERE PickDetailKey = @cPickDetailKey   
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 67347  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickDtlFail'  
                        GOTO Step_4_RollBack  
                     END   
  
                     -- Confirm PickDetail  
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
                        QTY    = @nQTY_Act,  
                        DropID = @cDropID,  
                        TrafficCop = NULL,  
                        EditDate = GetDate(),   
                        EditWho  = sUser_sName()   
                     WHERE PickDetailKey = @cPickDetailKey  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 67345  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'  
                        GOTO Step_4_RollBack  
                     END  
  
                     -- Confirm PickDetail  
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
                        Status = @cPickConfirmStatus,  
                        EditDate = GetDate(),   
                        EditWho  = sUser_sName()   
                     WHERE PickDetailKey = @cPickDetailKey  
  
                     SET @d_step1 = GETDATE() - @d_step1  
                     SET @c_col1 = 'QAct<QPD'  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 67345  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'  
                        GOTO Step_4_RollBack  
                     END  
                     ELSE  
                     BEGIN  
                          -- (Vicky06) EventLog - QTY  
                          EXEC RDT.rdt_STD_EventLog  
                             @cActionType   = '3', -- Picking  
                             @cUserID       = @cUserName,  
                             @nMobileNo     = @nMobile,  
                             @nFunctionID   = @nFunc,  
                             @cFacility     = @cFacility,  
                             @cStorerKey    = @cStorerkey,  
                             --@cLocation     = @cLOC,  
                             @cID           = @cMUID,  
                             @cSKU          = @cSKU,  
                             @cUOM          = @cPackUOM3,  
                             @nQTY          = @nQTY_Act,  
                             @cConsigneeKey = @cConsigneeKey,  
                             @cDropID       = @cDropID,
                             @nStep         = @nStep  
                     END  
  
                     SET @d_step3 = GETDATE() - @d_step3  
                  END   
               END -- @nCount = 0  
     
               IF @cPrePickDetailKey <> @cPickDetailKey AND @nCount = 1   
               BEGIN  
  
                  SET @d_step2 = GETDATE()  
  
                  -- Confirm PickDetail  
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
                     Status = @cPDStatus,  
                     TrafficCop = NULL,   
                     EditDate = GetDate(),   
                     EditWho  = sUser_sName()   
                  WHERE PickDetailKey = @cPickDetailKey  
  
                  SET @d_step2 = GETDATE() - @d_step2  
                  SET @c_col2 = 'PrePickDetailKey'  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 67345  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'  
                     GOTO Step_4_RollBack  
                  END  
               END  
                 
               SET @cPrePickDetailKey = @cPickDetailKey  
               FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD   
            END   
            CLOSE curPD  
            DEALLOCATE curPD   
              
            SET @d_step1 = GETDATE() - @d_step1  
         END     
         ELSE   
         BEGIN  
            SET @d_step3 = GETDATE()   
  
            -- Confirm PickDetail  
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
               DropID = @cDropID,  
               Status = @cPickConfirmStatus,  
               EditDate = GetDate(),   
               EditWho  = sUser_sName()   
            FROM dbo.PickDetail PD  
            JOIN dbo.ORDERS O (NOLOCK) ON (PD.OrderKey = O.OrderKey AND PD.Storerkey = O.Storerkey)  -- (Vicky01)  
            JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT AND PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU)  -- (Vicky01)  
            WHERE PD.ID          = @cMUID  
              AND PD.Storerkey   = @cStorerkey  
              AND PD.STATUS      = '0'  
              AND PD.QTY         > 0  
              AND PD.SKU         = @cSKU  
              AND O.ConsigneeKey = @cConsigneeKey  
              AND LA.Lottable01 = ISNULL(RTRIM(@cLottable01), '') -- (Vicky01)  
              AND LA.Lottable02 = ISNULL(RTRIM(@cLottable02), '') -- (Vicky01)  
              AND LA.Lottable03 = ISNULL(RTRIM(@cLottable03), '') -- (Vicky01)   
              AND LA.Lottable04 = @dLottable04  -- (Vicky01)  
  
             SET @d_step3 = GETDATE() - @d_step3  
             SET @c_col3 = '@d_step3'  
    
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 67345  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'  
               GOTO Step_4_RollBack  
            END  
            ELSE  
            BEGIN  
              DECLARE @nQtyPick INT  
  
              SELECT @nQtyPick = SUM(QTY)  
              FROM dbo.PickDetail PD (NOLOCK)  
              JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.Storerkey = OD.Storerkey)  -- (Vicky01)  
              JOIN dbo.ORDERS O (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey) -- (Vicky01)  
              JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT AND PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU)  -- (Vicky01)  
              WHERE PD.ID          = @cMUID  
                AND PD.STATUS      = @cPickConfirmStatus  
                AND PD.QTY         > 0  
                AND PD.SKU         = @cSKU  
                AND O.ConsigneeKey = @cConsigneeKey  
                AND PD.DropID      = @cDropID  
                AND LA.Lottable01 = ISNULL(RTRIM(@cLottable01), '') -- (Vicky01)  
                AND LA.Lottable02 = ISNULL(RTRIM(@cLottable02), '') -- (Vicky01)  
                AND LA.Lottable03 = ISNULL(RTRIM(@cLottable03), '') -- (Vicky01)  
                AND LA.Lottable04 = @dLottable04   -- (Vicky01)  
                AND PD.StorerKey = @cStorerKey  
                AND O.StorerKey = @cStorerKey  
  
               SET @nPackQty = @nQtyPick  
  
              -- (Vicky06) EventLog - QTY  
              EXEC RDT.rdt_STD_EventLog  
                 @cActionType   = '3', -- Picking  
                 @cUserID       = @cUserName,  
                 @nMobileNo     = @nMobile,  
                 @nFunctionID   = @nFunc,  
                 @cFacility     = @cFacility,  
                 @cStorerKey    = @cStorerkey,  
                 --@cLocation     = @cLOC,  
                 @cID           = @cMUID,  
                 @cSKU          = @cSKU,  
                 @cUOM          = @cPackUOM3,  
                 @nQTY          = @nQtyPick,  
                 @cConsigneeKey = @cConsigneeKey,  
                 @cDropID       = @cDropID,
                 @nStep         = @nStep 
             END    
         END       
  
         IF @cExtendedUpdateSP <> '' AND  
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cID, @cConsigneeKey, @cSKU, @nQty, @cDropID,' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               '@nMobile         INT,           ' +  
               '@nFunc           INT,           ' +  
               '@nStep           INT,           ' +  
               '@nInputKey       INT,           ' +  
               '@cLangCode       NVARCHAR( 3),  ' +  
               '@cStorerkey      NVARCHAR( 15), ' +  
               '@cID             NVARCHAR( 18), ' +  
               '@cConsigneeKey   NVARCHAR( 15), ' +  
               '@cSKU            NVARCHAR( 20), ' +  
               '@nQty            INT,           ' +  
               '@cDropID         NVARCHAR( 20), ' +  
               '@nErrNo          INT           OUTPUT, ' +  
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                 @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cMUID, @cConsigneeKey, @cSKU, @nPackQty, @cDropID,  
                 @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_4_RollBack  
         END  
  
         GOTO Step_4_Commit  
  
         Step_4_RollBack:  
            ROLLBACK TRAN Step_4  
  
         Step_4_Commit:  
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
               COMMIT TRAN  
  
         IF @nErrNo <> 0  
            GOTO Step_4_Fail  
  
         -- Trace Info (Vicky02) - Start    
         SET @d_endtime = GETDATE()    
         INSERT INTO TraceInfo VALUES    
                 (RTRIM(@c_TraceName), @d_starttime, @d_endtime    
                 ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)    
                 ,CONVERT(CHAR(12),@d_step1,114)    
                 ,CONVERT(CHAR(12),@d_step2,114)    
                 ,CONVERT(CHAR(12),@d_step3,114)    
                 ,CONVERT(CHAR(12),@d_step4,114)    
                 ,CONVERT(CHAR(12),@d_step5,114)    
                 ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)    
    
            SET @d_step1 = NULL    
            SET @d_step2 = NULL    
            SET @d_step3 = NULL    
            SET @d_step4 = NULL    
            SET @d_step5 = NULL    
         -- Trace Info (Vicky02) - End    
  
         SET @nCount   = 0  
  
         SET ROWCOUNT 1  
         SELECT @cNextSKU        = SKU.SKU,   
                @cSKUDesc        = SKU.DESCR,   
                @cLottable01     = LA.Lottable01,   
                @cLottable02     = LA.Lottable02,   
                @cLottable03     = LA.Lottable03,   
                @dLottable04     = LA.Lottable04,  
              @cPackUOM3       = PACK.PackUOM3,  
                @cDefaultUOMDesc = CASE @cDefaultUOM  
                                  WHEN '2' THEN PACK.PackUOM1 -- Case  
                                  WHEN '3' THEN PACK.PackUOM2 -- Inner pack  
                                  WHEN '6' THEN PACK.PackUOM3 -- Master unit  
                                  WHEN '1' THEN PACK.PackUOM4 -- Pallet  
                                  WHEN '4' THEN PACK.PackUOM8 -- Other unit 1  
                                  WHEN '5' THEN PACK.PackUOM9 -- Other unit 2  
                           END,  
              @cDefaultUOMDIV  = CAST( IsNULL(  
                               CASE @cDefaultUOM  
                                  WHEN '2' THEN PACK.CaseCNT  
                                  WHEN '3' THEN PACK.InnerPack  
                                  WHEN '6' THEN PACK.QTY  
                                  WHEN '1' THEN PACK.Pallet  
                                  WHEN '4' THEN PACK.OtherUnit1  
                                  WHEN '5' THEN PACK.OtherUnit2  
                               END, 1) AS INT),  
                @nQTY            = SUM(PD.QTY)  
         FROM dbo.PickDetail PD (NOLOCK)   
         JOIN dbo.SKU SKU (NOLOCK) ON (SKU.StorerKey = PD.Storerkey AND PD.SKU = SKU.SKU)  -- (Vicky01)  
         JOIN dbo.PACK PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
         JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT AND PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU) -- (Vicky01)  
         JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.Storerkey = PD.Storerkey AND OD.OrderLineNumber = PD.OrderLineNumber) -- (Vicky01)  
         JOIN dbo.ORDERS O (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey) -- (Vicky01)  
         WHERE PD.ID        = @cMUID  
         AND PD.Storerkey   = @cStorerkey  
         AND PD.STATUS      = '0'  
         AND PD.QTY         > 0  
         AND O.ConsigneeKey = @cConsigneeKey  
         AND PD.SKU         > @cSKU  
         GROUP BY SKU.SKU,   
                  SKU.DESCR,   
                  LA.Lottable01,   
                  LA.Lottable02,   
                  LA.Lottable03,   
                  LA.Lottable04,  
                PACK.PackUOM3,  
                  CASE @cDefaultUOM  
                 WHEN '2' THEN PACK.PackUOM1 -- Case  
                 WHEN '3' THEN PACK.PackUOM2 -- Inner pack  
                 WHEN '6' THEN PACK.PackUOM3 -- Master unit  
                 WHEN '1' THEN PACK.PackUOM4 -- Pallet  
                 WHEN '4' THEN PACK.PackUOM8 -- Other unit 1  
                 WHEN '5' THEN PACK.PackUOM9 -- Other unit 2  
              END,  
                CAST( IsNULL(  
              CASE @cDefaultUOM  
                 WHEN '2' THEN PACK.CaseCNT  
                 WHEN '3' THEN PACK.InnerPack  
                 WHEN '6' THEN PACK.QTY  
                 WHEN '1' THEN PACK.Pallet  
                 WHEN '4' THEN PACK.OtherUnit1  
                 WHEN '5' THEN PACK.OtherUnit2  
              END, 1) AS INT)  
         ORDER BY SKU.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04  
         SET ROWCOUNT 0    
  
         SET @cSKU = @cNextSKU  
      END     
  
      Step_4_Next:  
      -- (james02)  
      -- Go back screen 1 if config turn on to scan another muid  
      IF rdt.RDTGetConfig( @nFunc, 'PickCfmGo2Step1', @cStorerKey) = '1'  
      BEGIN  
         SET @cOutField01 = '' -- MUID  
         SET @cMax = ''  
  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
  
         -- Go to next screen  
         SET @nScn  = @nScn - 3  
         SET @nStep = @nStep - 3  
           
         GOTO Quit  
      END  
  
      IF ISNULL(@cSKU,'') <> ''  
      BEGIN  
         IF @cDefaultUOM < '6'   
         BEGIN  
            IF ISNULL(@cDefaultUOMDIV,'') = '' OR @cDefaultUOMDIV = '0'  
            BEGIN  
               SET @nErrNo = 67340  
               SET @cErrMsg = rdt.rdtgetmessage( 67340, @cLangCode, 'DSP') --Invalid PackQTY  
               GOTO Step_4_Fail    
            END  
  
            -- Initialise value (james02)  
            SET @cDefaultUOMSKUQTY = ''  
            SET @cPackUOM3SKUQTY = ''  
           
            -- Calc QTY in DefaultUOM  
            SET @cDefaultUOMQTY = CONVERT(VARCHAR(5), @nQTY/CONVERT(INT, @cDefaultUOMDIV))  
            SET @cDefaultUOMSKUQTY = CONVERT(VARCHAR(5), @nSKUQTY/CONVERT(INT, @cDefaultUOMDIV))  
  
            -- Calc the Balance QTY in PackUOM3  
            SET @cPackUOM3QTY = CONVERT(VARCHAR(5), @nQTY % CONVERT(INT, @cDefaultUOMDIV))  
            SET @cPackUOM3SKUQTY = CONVERT(VARCHAR(5), @nSKUQTY % CONVERT(INT, @cDefaultUOMDIV))  
         END  
         ELSE  
         BEGIN  
            SET @cDefaultUOMDesc = ''  
            SET @cDefaultUOMQTY  = ''  
            SET @cPackUOM3QTY    = CONVERT(VARCHAR(5), @nQTY)  
            SET @cInField14      = ''  
  
            -- (james02)  
            SET @cDefaultUOMSKUQTY = ''  
         END   
  
         --prepare screen 3 variable  
         SET @cKeyDefaultUOMQTY  = ''  
         SET @cKeyPackUOM3QTY    = ''  
         SET @cOutField01        = @cConsigneeKey  
         SET @cOutField02        = @cSKU  
         SET @cOutField03        = SUBSTRING(@cSKUDesc,1,20)  
         SET @cOutField04        = SUBSTRING(@cSKUDesc,21,20)  
         SET @cOutField05        = @cLottable01  
         SET @cOutField06        = @cLottable02  
         SET @cOutField07        = @cLottable03  
         SET @cOutField08        = rdt.rdtFormatDate(@dLottable04)  
         SET @cOutField09        = @cDefaultUOMDIV  
         SET @cOutField10        = @cDefaultUOMDesc  
         SET @cOutField11        = @cPackUOM3  
         SET @cOutField12        = @cDefaultUOMQTY  
         SET @cOutField13        = @cPackUOM3QTY  
         SET @cOutField14        = CASE WHEN ISNULL( @cDefaultUOMSKUQTY, '') <> '' THEN @cDefaultUOMSKUQTY ELSE '' END  
         SET @cOutField15        = CASE WHEN ISNULL( @cPackUOM3SKUQTY, '') <> '' THEN @cPackUOM3SKUQTY ELSE '' END  
  
         IF ISNULL(@cDefaultUOMQTY,'') = ''   
         BEGIN  
            SET @cFieldAttr14    = 'O' -- KeyDefaultUOMQTY  
            SET @cOutField14     = ''  
         END  
  
         SET @cInField14         = ''  -- KeyDefaultUOMQTY  
         SET @cInField15         = ''  -- KeyPackUOM3QTY  
  
         -- Go to next screen  
         SET @nScn  = @nScn - 1  
         SET @nStep = @nStep - 1  
      END   
      ELSE  
      BEGIN  
         SET ROWCOUNT 1  
         SELECT @cLOC = PD.LOC,   
                @cNextConsigneeKey = O.ConsigneeKey   
         FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_ID))  
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.Storerkey = OD.Storerkey) -- (Vicky01)  
         JOIN dbo.ORDERS O (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey)  -- (Vicky01)  
         WHERE PD.ID        = @cMUID  
         AND PD.Storerkey   = @cStorerkey  
         --AND O.Storerkey    = @cStorerkey  
         AND PD.STATUS      = '0'  
         AND O.ConsigneeKey > @cConsigneeKey  
         ORDER BY O.ConsigneeKey   
         SET ROWCOUNT 0  
  
         SET @cConsigneeKey = @cNextConsigneeKey  
  
         IF ISNULL(@cConsigneeKey,'') <> ''  
         BEGIN  
            --prepare screen 2 variable  
            SET @cOutField01  = @cMUID  
            SET @cOutField02  = @cLOC  
            SET @cOutField03  = @cConsigneeKey  
            SET @cOutField04  = ''  
  
            SET @cInField04   = ''  
                          
            -- Go to next screen  
            SET @nScn  = @nScn - 2  
            SET @nStep = @nStep - 2  
         END  
         ELSE  
         BEGIN  
            SET @cOutField01 = '' -- MUID  
  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
   
            -- Go to next screen  
            SET @nScn  = @nScn - 3  
            SET @nStep = @nStep - 3  
         END  
      END  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Initialise value (james02)  
      SET @cDefaultUOMSKUQTY = ''  
      SET @cPackUOM3SKUQTY = ''  
  
      -- Calc QTY in DefaultUOM  
      SET @cDefaultUOMSKUQTY = CONVERT(VARCHAR(5), @nSKUQTY/CONVERT(INT, @cDefaultUOMDIV))  
       
      -- Calc the Balance QTY in PackUOM3  
      SET @cPackUOM3SKUQTY = CONVERT(VARCHAR(5), @nSKUQTY % CONVERT(INT, @cDefaultUOMDIV))  
           
      -- Prepare prev screen var  
      SET @cKeyDefaultUOMQTY  = ''  
      SET @cKeyPackUOM3QTY    = ''   
      SET @cOutField01        = @cConsigneeKey  
      SET @cOutField02        = @cSKU  
      SET @cOutField03        = SUBSTRING(@cSKUDesc,1,20)  
      SET @cOutField04        = SUBSTRING(@cSKUDesc,21,20)  
      SET @cOutField05        = @cLottable01  
      SET @cOutField06        = @cLottable02  
      SET @cOutField07        = @cLottable03  
      SET @cOutField08        = rdt.rdtFormatDate(@dLottable04)  
      SET @cOutField09        = @cDefaultUOMDIV  
      SET @cOutField10        = @cDefaultUOMDesc  
      SET @cOutField11        = @cPackUOM3  
      SET @cOutField12        = @cDefaultUOMQTY  
      SET @cOutField13        = @cPackUOM3QTY  
      SET @cOutField14        = CASE WHEN ISNULL( @cDefaultUOMSKUQTY, '') <> ''   
                                THEN @cDefaultUOMSKUQTY ELSE '' END   -- KeyDefaultUOMQTY  
      SET @cOutField15        = CASE WHEN ISNULL( @cPackUOM3SKUQTY, '') <> ''   
                                THEN @cPackUOM3SKUQTY ELSE '' END    -- KeyPackUOM3QTY  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- MUID  
  
      -- go to previous screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_4_Fail:  
   BEGIN  
      SET @cDropID            = ''  
      SET @cOutField01        = @cConsigneeKey  
      SET @cOutField02        = @cSKU  
      SET @cOutField03        = SUBSTRING(@cSKUDesc,1,20)  
      SET @cOutField04        = SUBSTRING(@cSKUDesc,21,20)  
      SET @cOutField05        = @cDefaultUOMDIV  
      SET @cOutField06        = @cDefaultUOMDesc  
      SET @cOutField07        = @cPackUOM3  
      SET @cOutField08        = @cDefaultUOMQTY  
      SET @cOutField09        = @cPackUOM3QTY  
      SET @cOutField10        = @cKeyDefaultUOMQTY  
      SET @cOutField11        = @cKeyPackUOM3QTY  
   END    
END  
GOTO Quit  
  
/********************************************************************************  
Step 5. (screen = 2064) Enter Option  
   FINISH DISTRIBUTE?      
  
   BAL QTY: (Field01)  
   ACT QTY: (Field02)  
  
   1=YES  
   2=NO  
  
   OPTION: (Field03, input)  
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField03  
  
      --When Option is blank  
      IF @cOption = ''  
      BEGIN  
         SET @nErrNo = 67348  
         SET @cErrMsg = rdt.rdtgetmessage( 67348, @cLangCode, 'DSP') --Option needed  
         GOTO Step_5_Fail    
      END   
      ELSE IF @cOption = '1'  
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
         SET @cOutField01 = '' -- MUID           
         SET @nStorVerified = 0  
      END  
      ELSE IF @cOption = '2'  
      BEGIN  
         SET @cMUID = ''  
         SET @cMax = ''  
         SET @cOutField01 = '' -- MUID   
  
         -- go to screen 1  
         SET @nScn = 2060  
         SET @nStep = 1       
      END  
      ELSE  
      BEGIN  
         SET @nErrNo = 67349  
         SET @cErrMsg = rdt.rdtgetmessage( 67349, @cLangCode, 'DSP') --Invalid Option  
         GOTO Step_5_Fail    
      END   
   END    
   GOTO Quit   
  
   Step_5_Fail:  
   BEGIN  
      SET @cMUID       = ''  
      SET @cOption     = ''  
      SET @cOutField03 = '' -- Option  
   END    
END  
GOTO Quit  
  
/********************************************************************************  
Step 6. (screen = 2065) Key-in the SKU & ACT QTY picked in its corresponding UOM column  
   STOR: (Field01)  
   SKU:    
   (Field02, input)                                -- SKU  
   (Field03)                                       -- SKUDesc (Len  1-20)  
   (Field04)                                       -- SKUDesc (Len 21-40)  
   1 (Field05)           -- Lottable01   
   2 (Field06)                                     -- Lottable02  
   3 (Field07)                                     -- Lottable03   
   4 (Field08)                                     -- Lottable04  
   1:(Field09)  (Field10)        (Field11)         -- DefaultUOMDIV     -- DefaultUOMDesc  -- PackUOM3  
   BAL QTY:     (Field12)        (Field13)         -- DefaultUOMQTY     -- PackUOM3QTY  
   ACT QTY:     (Field14, input) (Field15, input)  -- KeyDefaultUOMQTY  -- KeyPackUOM3QTY  
   
   ENTER =  Next Page  
********************************************************************************/  
Step_6:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cSKUCode = @cInField02  
  
      --When STOR is blank  
      IF ISNULL( @cSKUCode, '') = ''  
      BEGIN  
         SET @nErrNo = 102654  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU needed  
         GOTO Step_6_Fail    
      END   
  
      -- (james02)  
      IF @cDecodeSP <> ''  
      BEGIN  
         SET @cBarcode = @cInField02  
         SET @cUserDefine01 = ''  
  
         -- Standard decode  
         IF @cDecodeSP = '1'  
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,   
               @cMUID         OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,   
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,  
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,  
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,  
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,  
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT  
         -- Customize decode  
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +  
               ' @cID            OUTPUT, @cSKU           OUTPUT, @nQTY           OUTPUT, @cDropID        OUTPUT, ' +  
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
               ' @cID            NVARCHAR( 18)  OUTPUT, ' +  
               ' @cSKU           NVARCHAR( 2000)  OUTPUT, ' +  
               ' @nQTY           INT            OUTPUT, ' +  
               ' @cDropID        NVARCHAR( 20)  OUTPUT, ' +  
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode,   
               @cMUID         OUTPUT, @cSKU           OUTPUT, @nQTY           OUTPUT, @cDropID        OUTPUT,  
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,  
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,  
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,  
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,                 
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT  
  
            SET @cScanConsigneeKey = @cUserDefine01  
            SET @cSKUCode = @cSKU  
            SET @nSKUQTY = @nQTY  
         END  
      END   -- End for DecodeSP  
  
      EXEC [RDT].[rdt_GETSKUCNT]  
         @cStorerKey  = @cStorerKey  
        ,@cSKU        = @cSKUCode  
        ,@nSKUCnt     = @nSKUCnt       OUTPUT  
        ,@bSuccess    = @b_Success     OUTPUT  
        ,@nErr        = @n_Err         OUTPUT  
        ,@cErrMsg     = @c_ErrMsg      OUTPUT  
  
      -- Validate SKU/UPC  
      IF @nSKUCnt = 0  
      BEGIN  
         SET @nErrNo = 102655  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
         GOTO Step_6_Fail    
      END  
  
      -- Validate barcode return multiple SKU  
      IF @nSKUCnt > 1  
      BEGIN  
         SET @nErrNo = 102656  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarcodeSKU  
         GOTO Step_6_Fail    
      END  
  
      EXEC [RDT].[rdt_GETSKU]  
          @cStorerKey  = @cStorerKey  
         ,@cSKU        = @cSKUCode      OUTPUT  
         ,@bSuccess    = @b_Success     OUTPUT  
         ,@nErr        = @n_Err         OUTPUT  
         ,@cErrMsg     = @c_ErrMsg      OUTPUT  
  
      SET @cSKU = @cSKUCode  
  
      -- Get prefer UOM  
      SELECT @cDefaultUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA  
      FROM RDT.rdtMobRec M (NOLOCK)  
         INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)  
      WHERE M.Mobile = @nMobile  
  
      SELECT TOP 1  
             @cSKUDesc        = SKU.DESCR,   
             @cLottable01     = LA.Lottable01,   
             @cLottable02     = LA.Lottable02,   
             @cLottable03     = LA.Lottable03,   
             @dLottable04     = LA.Lottable04,  
           @cPackUOM3       = PACK.PackUOM3,  
             @cDefaultUOMDesc = CASE @cDefaultUOM  
                               WHEN '2' THEN PACK.PackUOM1 -- Case  
                               WHEN '3' THEN PACK.PackUOM2 -- Inner pack  
                               WHEN '6' THEN PACK.PackUOM3 -- Master unit  
                               WHEN '1' THEN PACK.PackUOM4 -- Pallet  
                               WHEN '4' THEN PACK.PackUOM8 -- Other unit 1  
                               WHEN '5' THEN PACK.PackUOM9 -- Other unit 2  
                            END,  
           @cDefaultUOMDIV  = CAST( IsNULL(  
                            CASE @cDefaultUOM  
                               WHEN '2' THEN PACK.CaseCNT  
                               WHEN '3' THEN PACK.InnerPack  
                               WHEN '6' THEN PACK.QTY  
                               WHEN '1' THEN PACK.Pallet  
                               WHEN '4' THEN PACK.OtherUnit1  
                               WHEN '5' THEN PACK.OtherUnit2  
                            END, 1) AS INT),  
             @nQTY            = SUM(PD.QTY)  
      FROM dbo.PickDetail PD (NOLOCK)   
      JOIN dbo.SKU SKU (NOLOCK) ON (SKU.StorerKey = PD.Storerkey AND PD.SKU = SKU.SKU)  -- (Vicky01)  
      JOIN dbo.PACK PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
      JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT AND PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU)  -- (Vicky01)  
      JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.Storerkey = OD.Storerkey AND PD.OrderLineNumber = OD.OrderLineNumber) -- (Vicky01)  
      JOIN dbo.ORDERS O (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey) -- (Vicky01)  
      WHERE PD.ID = @cMUID  
      AND PD.Storerkey = @cStorerkey  
      AND PD.STATUS = '0'  
      AND PD.QTY > 0  
      AND O.ConsigneeKey = @cConsigneeKey  
      AND SKU.SKU = @cSKU  
      GROUP BY SKU.SKU,   
               SKU.DESCR,   
               LA.Lottable01,   
               LA.Lottable02,   
               LA.Lottable03,   
               LA.Lottable04,  
             PACK.PackUOM3,  
               CASE @cDefaultUOM  
              WHEN '2' THEN PACK.PackUOM1 -- Case  
              WHEN '3' THEN PACK.PackUOM2 -- Inner pack  
              WHEN '6' THEN PACK.PackUOM3 -- Master unit  
              WHEN '1' THEN PACK.PackUOM4 -- Pallet  
              WHEN '4' THEN PACK.PackUOM8 -- Other unit 1  
              WHEN '5' THEN PACK.PackUOM9 -- Other unit 2  
           END,  
             CAST( IsNULL(  
           CASE @cDefaultUOM  
              WHEN '2' THEN PACK.CaseCNT  
              WHEN '3' THEN PACK.InnerPack  
              WHEN '6' THEN PACK.QTY  
              WHEN '1' THEN PACK.Pallet  
              WHEN '4' THEN PACK.OtherUnit1  
              WHEN '5' THEN PACK.OtherUnit2  
           END, 1) AS INT)  
      ORDER BY SKU.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04  
  
      -- Validate barcode return multiple SKU  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 102657  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Nothing 2 pick  
         GOTO Step_6_Fail    
      END  
  
      IF @cDefaultUOM < '6'   
      BEGIN  
         IF ISNULL(@cDefaultUOMDIV,'') = '' OR @cDefaultUOMDIV = '0'  
         BEGIN  
            SET @nErrNo = 102658  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PackQTY  
            GOTO Step_2_Fail    
         END  
  
         SET @cDefaultUOMSKUQTY = ''  
         SET @cPackUOM3SKUQTY = ''  
  
         -- Calc QTY in DefaultUOM  
         SET @cDefaultUOMQTY = CONVERT(VARCHAR(5), @nQTY/CONVERT(INT, @cDefaultUOMDIV))  
         SET @cDefaultUOMSKUQTY = CONVERT(VARCHAR(5), @nSKUQTY/CONVERT(INT, @cDefaultUOMDIV))  
          
         -- Calc the Balance QTY in PackUOM3  
         SET @cPackUOM3QTY = CONVERT(VARCHAR(5), @nQTY % CONVERT(INT, @cDefaultUOMDIV))  
         SET @cPackUOM3SKUQTY = CONVERT(VARCHAR(5), @nSKUQTY % CONVERT(INT, @cDefaultUOMDIV))  
      END  
      ELSE  
      BEGIN  
         SET @cDefaultUOMDesc = ''  
         SET @cDefaultUOMQTY  = ''  
         SET @cPackUOM3QTY    = CONVERT(VARCHAR(5), @nQTY)  
         SET @cInField14      = ''  
           
         SET @cPackUOM3SKUQTY = @nSKUQTY  
      END  
  
      --prepare next screen variable  
      SET @cOutField01 = @cConsigneeKey  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = SUBSTRING(@cSKUDesc,1,20)  
      SET @cOutField04 = SUBSTRING(@cSKUDesc,21,20)  
      SET @cOutField05 = @cLottable01  
      SET @cOutField06 = @cLottable02  
      SET @cOutField07 = @cLottable03  
      SET @cOutField08 = rdt.rdtFormatDate(@dLottable04)  
      SET @cOutField09 = @cDefaultUOMDIV  
      SET @cOutField10 = @cDefaultUOMDesc  
      SET @cOutField11 = @cPackUOM3  
      SET @cOutField12 = @cDefaultUOMQTY  
      SET @cOutField13 = @cPackUOM3QTY  
      SET @cOutField14 = CASE WHEN ISNULL( @cDefaultUOMSKUQTY, '') <> '' THEN @cDefaultUOMSKUQTY ELSE '' END  
      SET @cOutField15 = CASE WHEN ISNULL( @cPackUOM3SKUQTY, '') <> '' THEN @cPackUOM3SKUQTY ELSE '' END  
  
      SET @cInField14  = '' -- KeyDefaultUOMQTY  
      SET @cInField15  = '' -- KeyPackUOM3QTY  
        
      IF ISNULL(@cDefaultUOMQTY,'') = ''   
      BEGIN  
         SET @cFieldAttr14 = 'O' -- KeyDefaultUOMQTY  
         SET @cOutField14  = ''  
      END  
  
      -- Go to next screen  
      SET @nScn  = @nScn - 3  
      SET @nStep = @nStep - 3  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare prev screen var  
      SET @cScanConsigneeKey  = ''  
      SET @cDefaultUOM        = ''  
      SET @cSKU               = ''  
      SET @cSKUDesc           = ''  
      SET @cLottable01        = ''  
      SET @cLottable02        = ''  
      SET @cLottable03        = ''  
      SET @dLottable04        = ''  
      SET @cDefaultUOMDIV     = ''  
      SET @cDefaultUOMDesc    = ''  
      SET @cPackUOM3          = ''  
      SET @cDefaultUOMQTY     = ''  
      SET @cPackUOM3QTY       = ''  
  
      SET @cOutField01        = @cMUID  
      SET @cOutField02        = @cLOC  
      SET @cOutField03        = @cConsigneeKey  
      SET @cOutField04        = '' -- ScanConsigneeKey  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ScanConsigneeKey  
  
      -- go to previous screen  
      SET @nScn = @nScn - 4  
      SET @nStep = @nStep - 4  
   END  
   GOTO Quit  
  
   Step_6_Fail:  
   BEGIN  
      SET @cSKUCode = ''  
      SET @cOutField01        = @cConsigneeKey  
      SET @cOutField02        = ''  
   END    
   GOTO Quit  
END  
GOTO Quit  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE RDTMOBREC WITH (ROWLOCK) SET  
       EditDate         = GETDATE(),  
       ErrMsg           = @cErrMsg,   
       Func             = @nFunc,  
       Step             = @nStep,              
       Scn              = @nScn,  
  
       Facility         = @cFacility, -- (Vicky06)  
       StorerKey        = @cStorerKey, -- (Vicky06)  
  
       V_Loc            = @cLOC,  
       V_SKU            = @cSKU,    
       V_UOM            = @cDefaultUOM,  
       V_ID             = @cMUID,  
       V_ConsigneeKey   = @cConsigneeKey,  
       V_SkuDescr       = @cSKUDesc,  
       V_QTY            = @nQty,     
       V_Lottable01     = @cLottable01,  
       V_Lottable02     = @cLottable02,  
       V_Lottable03     = @cLottable03,  
       V_Lottable04     = @dLottable04,  
       V_String1        = @cBALQty,  
       V_String2        = @cACTQty,  
       V_String3        = @cPackUOM3,  
       V_String4        = @cDefaultUOMDesc,  
       V_String5        = @cDefaultUOMDIV,  
       V_String6        = @cDefaultUOMQTY,  
       V_String7        = @cPackUOM3QTY,  
       V_String8        = @cKeyDefaultUOMQTY,  
       V_String9        = @cKeyPackUOM3QTY,  
       V_String10       = @cDropID,  
       V_String11       = @cDecodeSP,  
       V_String12       = @cNotAutoShortPick,  
       V_String13       = @cDirectFlowThruScn,  -- (james04)  
       V_String14       = @cUserDefine01,       -- (james04)  
       V_String15       = @cPrevConsigneeKey,   -- (james04)  
       V_String16       = @cVerifyStor,         -- (james04)  
       V_String17       = @nStorVerified,       -- (james04)  
     V_String18       = @cExtendedValidateSP, -- (james04)  
       V_String19       = @cExtendedUpdateSP,   -- (james04)  
       V_String20       = @cUserDefine01,       -- (james04)  
       V_String21       = @cUserDefine02,       -- (james04)  
       V_String22       = @cUserDefine03,       -- (james04)  
       V_String23       = @cUserDefine04,       -- (james04)  
       V_String24       = @cUserDefine05,       -- (james04)  
       V_String25       = @cPickConfirmStatus,  -- (james05)  
       V_Max            = @cMax,                -- (james04)  
     
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
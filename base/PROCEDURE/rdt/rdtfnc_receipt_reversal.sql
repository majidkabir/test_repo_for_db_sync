SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdtfnc_Receipt_Reversal                             */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: RDT Receipt Reversal                                        */  
/*          To reverse the receipt of the stocks on the ASN             */  
/*                                                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2015-07-27 1.0  James    Created SOS338503                           */  
/* 2016-09-30 1.1  Ung      Performance tuning                          */  
/* 2018-10-25 1.2  Gan      Performance tuning                          */  
/* 2021-11-15 1.3  James    WMS-18372 Add ExtendedUpdateSP (james01)    */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_Receipt_Reversal] (  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 nvarchar max  
) AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variable  
DECLARE  
   @cChkFacility NVARCHAR( 5),  
   @nSKUCnt      INT,  
   @nRowCount    INT,  
   @cXML         NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc  
  
-- RDT.RDTMobRec variable  
DECLARE  
   @nFunc         INT,  
   @nScn          INT,  
   @nStep         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nInputKey     INT,  
   @nMenu         INT,  
  
   @cStorerGroup  NVARCHAR( 20),  
   @cStorerKey    NVARCHAR( 15),  
   @cFacility     NVARCHAR( 5),  
   @cUserName     NVARCHAR( 18),   
  
   @cSKU                NVARCHAR( 20),  
   @cDescr              NVARCHAR( 40),  
   @cPUOM               NVARCHAR( 1),   
   @cPUOM_Desc          NVARCHAR( 5),  
   @cMUOM_Desc          NVARCHAR( 5),  
   @cASNStatus          NVARCHAR( 10),  
   @cID                 NVARCHAR( 18),  
   @cReceiptKey         NVARCHAR( 10),     
   @cReceiptLineNumber  NVARCHAR( 5),  
   @cOption             NVARCHAR( 1),     
  
   @nPUOM_Div     INT, -- UOM divider  
   @nQTY_Avail    INT, -- QTY available in LOTxLOCXID  
   @nQTY          INT, -- Replenishment.QTY  
   @nPQTY         INT, -- Preferred UOM QTY  
   @nMQTY         INT, -- Master unit QTY  
   @nActQTY       INT, -- Actual replenish QTY  
   @nActMQTY      INT, -- Actual keyed in master QTY  
   @nActPQTY      INT, -- Actual keyed in prefered QTY  
   @cChkStorerKey NVARCHAR( 15),  
  
   @cExtendedValidateSP NVARCHAR( 20),   
   @cSQLStatement       NVARCHAR(2000),  
   @cSQLParms           NVARCHAR(2000),  
   @cLottable01         NVARCHAR( 18),  
   @cLottable02         NVARCHAR( 18),  
   @cLottable03         NVARCHAR( 18),  
   @dLottable04         DATETIME,   
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
  
   @cLottable1Label     NVARCHAR( 20),   
   @cLottable2Label     NVARCHAR( 20),   
   @cLottable3Label     NVARCHAR( 20),   
   @cLottable4Label     NVARCHAR( 20),   
   @cLottable5Label     NVARCHAR( 20),   
   @cLottable01Value    NVARCHAR( 20),   
   @cLottable02Value    NVARCHAR( 20),   
   @cLottable03Value    NVARCHAR( 20),   
   @cLottable04Value    NVARCHAR( 20),   
   @cLottable05Value    NVARCHAR( 20),   
   @cLottable06Value  NVARCHAR( 30),  
   @cLottable07Value    NVARCHAR( 30),  
   @cLottable08Value    NVARCHAR( 30),  
   @cLottable09Value    NVARCHAR( 30),  
   @cLottable10Value    NVARCHAR( 30),  
   @cLottable11Value    NVARCHAR( 30),  
   @cLottable12Value    NVARCHAR( 30),  
   @cExtendedUpdateSP   NVARCHAR( 20),    
   @nTranCount          INT,  
   @dLottable04Value    DATETIME,  
   @dLottable05Value    DATETIME,  
   @dLottable13Value    DATETIME,  
   @dLottable14Value    DATETIME,  
   @dLottable15Value    DATETIME,  
   @cSQL                NVARCHAR( MAX),  
   @cSQLParam           NVARCHAR( MAX),  
   @tExtUpdate          VARIABLETABLE,  
     
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
  
-- Load RDT.RDTMobRec  
SELECT  
   @nFunc       = Func,  
   @nScn        = Scn,  
   @nStep       = Step,  
   @nInputKey   = InputKey,  
   @nMenu       = Menu,  
   @cLangCode   = Lang_code,  
  
   @cStorerGroup = StorerGroup,   
   @cFacility   = Facility,  
   @cUserName   = UserName,   
  
   @cStorerKey  = V_StorerKey,  
   @cSKU        = V_SKU,  
   @cDescr      = V_SKUDescr,  
   @cPUOM       = V_UOM,  
   @cReceiptKey = V_ReceiptKey,  
   @cID         = V_ID,  
  
   @cReceiptLineNumber  = V_String1,  
   @cMUOM_Desc          = V_String3,  
   @cPUOM_Desc          = V_String4,  
   @cExtendedUpdateSP   = V_String5,    
        
   @nPUOM_Div   = V_PUOM_Div,  
   @nMQTY       = V_MQTY,  
   @nPQTY       = V_PQTY,  
  
   @cLottable01 =  V_Lottable01,  
   @cLottable02 =  V_Lottable02,  
   @cLottable03 =  V_Lottable03,  
   @dLottable04 =  V_Lottable04,  
   @dLottable05 =  V_Lottable05,  
   @cLottable06 =  V_Lottable06,  
   @cLottable07 =  V_Lottable07,  
   @cLottable08 =  V_Lottable08,  
   @cLottable09 =  V_Lottable09,  
   @cLottable10 =  V_Lottable10,  
   @cLottable11 =  V_Lottable11,  
   @cLottable12 =  V_Lottable12,  
   @dLottable13 =  V_Lottable13,  
   @dLottable14 =  V_Lottable14,  
   @dLottable15 =  V_Lottable15,  
  
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
  
FROM RDTMOBREC WITH (NOLOCK)  
WHERE Mobile = @nMobile  
  
-- Redirect to respective screen  
IF @nFunc = 599   
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 599  
   IF @nStep = 1 GOTO Step_1   -- Scn = 4220. ASN  
   IF @nStep = 2 GOTO Step_2   -- Scn = 4221. PALLET ID  
   IF @nStep = 3 GOTO Step_3   -- Scn = 4222. SKU, DESCRIPTION, QTY, OPTION  
   IF @nStep = 4 GOTO Step_4   -- Scn = 4223. OPTION  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 599)  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn = 4220   
   SET @nStep = 1  
  
   -- Get prefer UOM  
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA  
   FROM RDT.rdtMobRec M WITH (NOLOCK)  
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)  
   WHERE M.Mobile = @nMobile  
  
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
   IF @cExtendedUpdateSP = '0'      
      SET @cExtendedUpdateSP = ''    
  
    -- (Vicky06) EventLog - Sign In Function  
    EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerkey,  
     @nStep       = @nStep  
  
  
   -- Prep next screen var  
   SET @cReceiptKey = ''  
   SET @cOutField01 = '' -- ASN  
  
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
  
   EXEC rdt.rdtSetFocusField @nMobile, 1  
END  
GOTO Quit  
  
/********************************************************************************  
Step 1. Screen = 4220  
   ASN       (Field01)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cReceiptKey = @cInField01  
  
      -- Validate blank  
      IF ISNULL(@cReceiptKey, '') = ''   
      BEGIN  
         SET @nErrNo = 55601  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN required  
         GOTO Step_1_Fail  
      END  
  
      SELECT @cASNStatus = ASNStatus,   
             @cChkFacility = Facility,   
             @cChkStorerKey = StorerKey   
      FROM dbo.Receipt WITH (NOLOCK)  
      WHERE ReceiptKey = @cReceiptKey  
  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 55602  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ASN  
         GOTO Step_1_Fail  
      END  
  
      IF ISNULL( @cASNStatus, '') = '9'  
      BEGIN  
         SET @nErrNo = 55603  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN Closed  
         GOTO Step_1_Fail  
      END  
  
      IF @cFacility <> @cChkFacility  
      BEGIN  
         SET @nErrNo = 55604  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Facility diff  
         GOTO Step_1_Fail  
      END  
  
      -- Check storer group  
      IF @cStorerGroup <> ''  
      BEGIN  
         -- Check storer not in storer group  
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)  
         BEGIN  
            SET @nErrNo = 55611  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp  
            GOTO Step_1_Fail  
         END  
  
         -- Set session storer  
         SET @cStorerKey = @cChkStorerKey  
      END  
  
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = ''  
  
      -- Go to next screen  
      SET @nScn  = @nScn + 1  
      SET @nStep = @nStep + 1  
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
       @cStorerKey  = @cStorerkey,  
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
      SET @cReceiptKey = ''  
      SET @cOutField01 = '' -- ASN  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 2. Screen 4221  
   ASN      (Field01)  
   ID       (Field02, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cID = @cInField02  
  
      -- Validate ID if keyed in  
      IF ISNULL( @cID, '') <> ''  
      BEGIN  
         IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)   
                         WHERE StorerKey = @cStorerKey  
                         AND   ReceiptKey = @cReceiptKey  
                         AND   ToID = @cID)  
         BEGIN  
            SET @nErrNo = 55605  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Plt ID  
            GOTO Step_2_Fail  
         END  
      END  
  
      -- (james41)  
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
      IF @cExtendedValidateSP = '0'  
         SET @cExtendedValidateSP = ''  
  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         SET @nErrNo = 0  
         SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +       
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cReceiptKey, @cID, @cSKU, ' +   
            ' @nQty, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '      
  
         SET @cSQLParms =      
            '@nMobile                   INT,           ' +  
            '@nFunc                     INT,           ' +  
            '@cLangCode                 NVARCHAR( 3),  ' +  
            '@nStep                     INT,           ' +  
            '@nInputKey                 INT,           ' +  
            '@cStorerkey                NVARCHAR( 15), ' +  
            '@cReceiptKey               NVARCHAR( 10), ' +  
            '@cID                       NVARCHAR( 18), ' +  
            '@cSKU                      NVARCHAR( 20), ' +  
            '@nQty                      INT, '           +  
            '@cOption                   NVARCHAR( 1), ' +  
            '@nErrNo                    INT           OUTPUT,  ' +  
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '   
                 
         EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,       
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cReceiptKey, @cID, @cSKU,    
               @nQty, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT       
  
         IF @nErrNo <> 0  
            GOTO Step_2_Fail  
      END  
  
      -- 1st time get receipt details  
      SET @cSKU = ''  
      SET @nErrNo = 0  
      EXEC [RDT].[rdt_ReceiptReversal_GetDetails]   
         @nMobile             = @nMobile,   
         @nFunc               = @nFunc,   
         @cLangCode           = @cLangCode,    
         @nScn                = @nScn,   
         @nInputKey           = @nInputKey,   
         @cStorerKey          = @cStorerKey,    
         @cReceiptKey         = @cReceiptKey,    
         @cFacility           = @cFacility,    
         @cID                 = @cID,    
         @cSKU                = @cSKU               OUTPUT,    
         --@cLottable1Label     = @cLottable1Label    OUTPUT,    
         --@cLottable2Label     = @cLottable2Label    OUTPUT,    
         --@cLottable3Label     = @cLottable3Label    OUTPUT,    
         --@cLottable4Label     = @cLottable4Label    OUTPUT,    
         --@cLottable5Label     = @cLottable5Label    OUTPUT,    
       @cLottable1Value     = @cLottable01Value    OUTPUT,  
       @cLottable2Value     = @cLottable02Value    OUTPUT,  
         @cLottable3Value     = @cLottable03Value    OUTPUT,  
         @cLottable4Value     = @cLottable04Value    OUTPUT,  
         @cLottable5Value     = @cLottable05Value    OUTPUT,  
         @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,  
         @nQty                = @nQty               OUTPUT,  
         @nErrNo              = @nErrNo             OUTPUT,     
         @cErrMsg             = @cErrMsg            OUTPUT   
  
      --IF ISNULL( @cSKU, '') = ''   
      --BEGIN  
      --   SET @nErrNo = 55606  
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Rec Found  
      --   GOTO Step_2_Fail  
      --END  
  
      IF ISNULL( @nQty, 0) = 0  
      BEGIN  
         SET @nErrNo = 55610  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --0 Received Qty  
         GOTO Step_2_Fail  
      END  
  
      -- Get Pack info  
      SELECT  
         @cDescr = SKU.Descr,  
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
         @nPUOM_Div = CAST( IsNULL(  
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
  
      -- Prep QTY screen var  
      SET @cOutField01 = @cID  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)  
      SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)  
      SET @cOutField05 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE LEFT( CAST( @nPUOM_Div AS NVARCHAR( 5)) + SPACE( 5), 5) END +  
                        RIGHT( SPACE( 5) + RTRIM( @cPUOM_Desc), 5) +   
                        RIGHT( SPACE( 8) + RTRIM( @cMUOM_Desc), 8)  
      SET @cOutField06 = 'QTY:' + RIGHT( SPACE( 8) + CAST( @nPQTY AS NVARCHAR( 7)), 8) + RIGHT( SPACE( 8) +   
                        CAST( @nMQTY AS NVARCHAR( 7)), 8)  
      SET @cOutField07 = @cLottable01Value  
      SET @cOutField08 = @cLottable02Value  
      SET @cOutField09 = @cLottable03Value  
      SET @cOutField10 = @cLottable04Value  
      SET @cOutField11 = @cLottable05Value  
      SET @cOutField12 = ''  
  
      -- Go to QTY screen  
      SET @nScn  = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
  
      SET @cReceiptKey = ''  
      SET @cOutField01 = '' -- ASN  
   END  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 3. Screen 4222  
   RPL KEY   (Field01)  
   SKU       (Field02)  
   SKU Desc1 (Field03)  
   SKU Desc2 (Field04)  
   Lottable2 (Field05)  
   Lottable3 (Field06)  
   Lottable4 (Field07)  
   PUOM MUOM (Field08, Field09)  
   RPL QTY   (Field10, Field11)  
   ACT QTY   (Field12, Field13, both input)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1      -- Yes OR Send  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField12  
  
      -- Option is blank, get next sku to display  
      IF ISNULL( @cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 0  
         EXEC [RDT].[rdt_ReceiptReversal_GetDetails]   
            @nMobile             = @nMobile,   
            @nFunc               = @nFunc,   
            @cLangCode           = @cLangCode,    
            @nScn                = @nScn,   
            @nInputKey           = @nInputKey,   
            @cStorerKey          = @cStorerKey,    
            @cReceiptKey         = @cReceiptKey,    
            @cFacility           = @cFacility,    
            @cID                 = @cID,    
            @cSKU                = @cSKU               OUTPUT,    
          @cLottable1Value     = @cLottable01Value    OUTPUT,  
          @cLottable2Value     = @cLottable02Value    OUTPUT,  
            @cLottable3Value     = @cLottable03Value    OUTPUT,  
            @cLottable4Value     = @cLottable04Value    OUTPUT,  
            @cLottable5Value     = @cLottable05Value    OUTPUT,  
            @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,  
            @nQty                = @nQty               OUTPUT,  
            @nErrNo              = @nErrNo             OUTPUT,     
            @cErrMsg             = @cErrMsg            OUTPUT   
  
         IF ISNULL( @cSKU, '') = ''   
         BEGIN  
            SET @nErrNo = 55607  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Rec Found  
            SET @cSKU = @cOutField02  
            GOTO Step_3_Fail  
         END  
  
         -- Get Pack info  
         SELECT  
            @cDescr = SKU.Descr,  
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
            @nPUOM_Div = CAST( IsNULL(  
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
  
         -- Prep QTY screen var  
         SET @cOutField01 = @cID  
         SET @cOutField02 = @cSKU  
         SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)  
         SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)  
         SET @cOutField05 = '1:' + LEFT( CAST( @nPUOM_Div AS NVARCHAR( 4)) + SPACE( 4), 4) +  
                           RIGHT( SPACE( 6) + RTRIM( @cPUOM_Desc), 6) +   
                           RIGHT( SPACE( 8) + RTRIM( @cMUOM_Desc), 8)  
         SET @cOutField06 = 'QTY:' + RIGHT( SPACE( 8) + CAST( @nPQTY AS NVARCHAR( 7)), 8) + RIGHT( SPACE( 8) +   
                           CAST( @nMQTY AS NVARCHAR( 7)), 8)  
         SET @cOutField07 = @cLottable01Value  
         SET @cOutField08 = @cLottable02Value  
         SET @cOutField09 = @cLottable03Value  
         SET @cOutField10 = @cLottable04Value  
         SET @cOutField11 = @cLottable05Value  
         SET @cOutField12 = ''  
  
         GOTO Quit  
      END  
   
      IF @cOption <> '1'   
      BEGIN  
         SET @nErrNo = 55608  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         GOTO Step_3_Fail  
      END  
      ELSE  
      BEGIN  
         SET @cOutField01 = ''  
  
         -- Go to next screen  
         SET @nScn  = @nScn + 1  
         SET @nStep = @nStep + 1  
      END  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare prev screen  
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = ''  
  
      -- Go to prev screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_3_Fail:  
   BEGIN  
      SET @cOption = ''  
      SET @cOutField12 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 4. Screen = 1229  
   FROM LOC   (Field01)  
   FROM ID    (Field02)  
   SKU        (Field03)  
   SKU Desc 1 (Field04)  
   SKU Desc 2 (Field05)  
   PUOM MUOM  (Field06, Field07)  
   RPL QTY    (Field08, Field09)  
   ACT QTY    (Field10, Field11)  
   ID         (Field14, input)  
   TO LOC     (Field12)  
   TO LOC     (Field13, input)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 55609  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         GOTO Step_4_Fail  
      END  
  
      SET @nTranCount = @@TRANCOUNT    
      BEGIN TRAN    
      SAVE TRAN rdt_ReceiptReversal_Cfm    
     
      SET @nErrNo = 0  
      EXEC [RDT].[rdt_ReceiptReversal_Confirm]   
         @nMobile         = @nMobile,   
         @nFunc           = @nFunc,   
         @cLangCode       = @cLangCode,    
         @nScn            = @nScn,   
         @nInputKey       = @nInputKey,   
         @cStorerKey      = @cStorerKey,    
         @cReceiptKey     = @cReceiptKey,    
         @cFacility       = @cFacility,    
         @cID             = @cID,    
         @cSKU            = @cSKU,    
       @cLottable1Value = @cLottable01Value,  
       @cLottable2Value = @cLottable02Value,  
         @cLottable3Value = @cLottable03Value,  
         @cLottable4Value = @cLottable04Value,  
         @cLottable5Value = @cLottable05Value,  
         @cOption         = @cOption,  
         @nQty            = @nQty,  
         @nErrNo          = @nErrNo             OUTPUT,     
         @cErrMsg         = @cErrMsg            OUTPUT   
  
      IF @nErrNo <> 0  
         GOTO RollBack_Cfm  
  
      -- Extended update    
      IF @cExtendedUpdateSP <> ''    
BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @dLottable04Value = rdt.rdtFormatDate( @cLottable04Value)  
            SET @dLottable05Value = rdt.rdtFormatDate( @cLottable05Value)  
              
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +     
               ' @cReceiptKey, @cID, @cSKU, @nQty, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +     
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cOption, @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
            SET @cSQLParam =    
               ' @nMobile        INT,           ' +    
               ' @nFunc          INT,           ' +    
               ' @cLangCode      NVARCHAR( 3),  ' +    
               ' @nStep          INT,           ' +    
               ' @nInputKey      INT,           ' +    
               ' @cFacility      NVARCHAR( 5),  ' +    
               ' @cStorerKey     NVARCHAR( 15), ' +    
               ' @cReceiptKey    NVARCHAR( 10), ' +    
               ' @cID            NVARCHAR( 18), ' +    
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
               ' @dLottable13    DATETIME,      ' +  
               ' @dLottable14    DATETIME,      ' +  
               ' @dLottable15    DATETIME,      ' +  
               ' @cOption        NVARCHAR( 1),  ' +    
               ' @tExtUpdate     VariableTable READONLY, ' +     
               ' @nErrNo         INT           OUTPUT, ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,     
               @cReceiptKey, @cID, @cSKU, @nQty,     
               @cLottable01Value, @cLottable02Value, @cLottable03Value, @dLottable04Value, @dLottable05Value,      
               @cLottable06Value, @cLottable07Value, @cLottable08Value, @cLottable09Value, @cLottable10Value,   
               @cLottable11Value, @cLottable12Value, @dLottable13Value, @dLottable14Value, @dLottable15Value,   
               @cOption, @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0     
               GOTO RollBack_Cfm    
         END    
      END            
  
   GOTO ReceiptReversal_Cfm  
    
   RollBack_Cfm:    
      ROLLBACK TRAN rdt_ReceiptReversal_Cfm    
     
   ReceiptReversal_Cfm:    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    
        
      -- Prep next screen var  
      SET @cReceiptKey = ''  
      SET @cOutField01 = '' -- ASN  
  
      SET @nScn  = @nScn - 3  
      SET @nStep = @nStep - 3  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prep next screen var  
      SET @cReceiptKey = ''  
      SET @cOutField01 = '' -- ASN  
  
      SET @nScn  = @nScn - 3  
      SET @nStep = @nStep - 3  
   END  
   GOTO Quit  
  
   Step_4_Fail:  
   BEGIN  
      SET @cOption = ''  
      SET @cOutField01 = ''  
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
  
      Facility  = @cFacility,  
      -- UserName  = @cUserName,-- (Vicky06)  
  
      V_StorerKey    = @cStorerKey,   
      V_SKU          = @cSKU,  
      V_SKUDescr     = @cDescr,  
      V_UOM          = @cPUOM,  
      V_ReceiptKey   = @cReceiptKey,  
      V_ID           = @cID,  
  
      V_String1      = @cReceiptLineNumber,  
      V_String3      = @cMUOM_Desc,  
      V_String4      = @cPUOM_Desc,  
      V_String5  = @cExtendedUpdateSP,    
        
      V_PUOM_Div = @nPUOM_Div,  
      V_MQTY     = @nMQTY,  
      V_PQTY     = @nPQTY,  
  
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
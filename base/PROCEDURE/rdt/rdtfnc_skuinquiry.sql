SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdtfnc_SKUInquiry                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: SKU Inquiry                                                 */  
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
/*            1.0  Shong    Created                                     */  
/* 2007-05-21 1.1  Vicky    Change Display Msg Number & Change != to <> */  
/* 2007-05-29 1.2  Vicky    SOS#76474 - Take out checking on Descr &    */  
/*                          add in SKU validation                       */  
/* 2007-10-01 1.3  James    SOS87612 - restructre screen and trim       */  
/*                          extra blank space for inv bal & avail stk   */  
/* 2008-11-13 1.4  James    Change nspg_getsku to rdt_getsku            */  
/* 2008-12-01 1.5  Vanessa  SOS87612-Retrieve OnHoldQty based on Exceed */  
/*                          method Refer d_dw_lotxlocxid_report_balance */  
/*                          -- (Vanessa01)                              */  
/* 2008-12-15 1.6  Vanessa  SOS87612-ID.Status=HOLD, LocationFlag=Damage*/  
/*                          and Status=HOLD exist at AVL -- (Vanessa02) */  
/* 2010-09-15 1.7  Shong    QtyAvailable Should exclude QtyReplen       */  
/* 2010-10-02 1.8  Shong    Remove the Filter For ReplenQty             */  
/* 2011-06-21 1.9  Ung      SOS217852 Add inquiry by LOC                */  
/*                          Clean up source                             */  
/* 2014-03-20 1.20 TLTING   Bug fix                                     */  
/* 2016-08-11 1.21 James    SOS375234 - Add DecodeSP (james01)          */  
/* 2016-09-30 1.22 Ung      Performance tuning                          */  
/* 2018-10-01 1.23 TungGH   Performance                                 */    
/* 2021-06-09 1.24 YeeKung  WMS-17216 Add LOCLookUP (yeekung01)         */    
/* 2022-06-22 1.25 James    WMS-20022 Add update sp (james02)           */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdtfnc_SKUInquiry] (  
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR(125) OUTPUT  
) AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variable  
DECLARE  
   @bSuccess       INT,     
   @cChkFacility   NVARCHAR( 5),   
   @cNextSKU       NVARCHAR( 20),  
   @cNextLOC       NVARCHAR( 10),  
   @cSKUDescr      NVARCHAR( 60),   
   @cQtyOnHand     NVARCHAR( 20),   
   @cQtyAvail      NVARCHAR( 20)  
  
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
  
   @cInquiry_SKU NVARCHAR( 20),  
   @cInquiry_Loc NVARCHAR( 10),  
   @cCurrentSKU  NVARCHAR( 20),   
   @cCurrentLOC  NVARCHAR( 10),  
   @nRec         INT,   
   @nTotRec      INT,   
   @cCS_PL       NVARCHAR( 5),   
   @cEA_CS       NVARCHAR( 5),   
   @cMin         NVARCHAR( 5),   
   @cMax         NVARCHAR( 5),   
   @cCaseUOM     NVARCHAR( 5),  
   @cEachUOM     NVARCHAR( 5),   
  
   -- (james01)  
   @cDecodeSP           NVARCHAR( 20),   
   @cBarcode            NVARCHAR( 60),   
   @cUPC                NVARCHAR( 30),   
   @cLOC                NVARCHAR( 10),   
   @cID                 NVARCHAR( 18),  
   @cSKU                NVARCHAR( 20),  
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
   @cUserDefine01       NVARCHAR( 60),    
   @cUserDefine02       NVARCHAR( 60),    
   @cUserDefine03       NVARCHAR( 60),    
   @cUserDefine04       NVARCHAR( 60),    
   @cUserDefine05       NVARCHAR( 60),    
   @cSQL                NVARCHAR( MAX),   
   @cSQLParam           NVARCHAR( MAX),   
   @nQTY                INT,  
   @cLOCLookUP          NVARCHAR(20),  --(yeekung01)  
   @tSKUInqUpdate       VariableTable, -- (james02)

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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)  
  
-- Getting Mobile information  
SELECT  
   @nFunc       = Func,  
   @nScn        = Scn,  
   @nStep       = Step,  
   @nInputKey   = InputKey,  
   @nMenu       = Menu,  
   @cLangCode   = Lang_code,  
  
   @cStorerKey  = StorerKey,  
   @cFacility   = Facility,  
  
   @cInquiry_SKU = V_SKU,  
   @cInquiry_LOC = V_Loc,  
     
   @cCurrentSKU = V_String1,  
   @cCurrentLoc = V_String2,  
   @cCS_PL      = V_String5,   
   @cEA_CS      = V_String6,   
   @cMin        = V_String7,   
   @cMax        = V_String8,   
   @cCaseUOM    = V_String9,  
   @cEachUOM    = V_String10,   
   @cLOCLookUP  = V_String11,  --(yeekung01)  
     
   @nRec        = V_Integer1,  
   @nTotRec     = V_Integer2,  
  
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15  
  
FROM RDTMOBREC (NOLOCK)  
WHERE Mobile = @nMobile  
  
IF @nFunc = 556 -- Inquiry (SKU)   
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0 GOTO Step_0   -- Func = Inquiry SKU  
   IF @nStep = 1 GOTO Step_1   -- Scn = 1030. SKU, LOC  
   IF @nStep = 2 GOTO Step_2   -- Scn = 1031. Result  
END  
  
RETURN -- Do nothing if incorrect step  
  
  
/********************************************************************************  
Step 0. func = 556. Menu  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Prep next screen var  
   SET @cInquiry_SKU = ''  
   SET @cInquiry_LOC = ''  
   SET @cOutField01 = '' -- SKU  
   SET @cOutField02 = '' -- LOC  
  
   SET @cLOCLookUP = rdt.rdtGetConfig( @nFunc, 'LOCLookUPSP', @cStorerKey)          
   IF @cLOCLookUP = '0'                
      SET @cLOCLookUP = ''       
  
   SET @nScn = 820  
   SET @nStep = 1  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Scn = 820. SKU, LOC  
   SKU (field11, input)  
   LOC (field12, input)     
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cInquiry_SKU = @cInField01  
      SET @cInquiry_LOC = @cInField02  
  
      -- Get no field keyed-in  
      DECLARE @i INT  
      SET @i = 0  
      IF @cInquiry_SKU <> '' AND @cInquiry_SKU IS NOT NULL SET @i = @i + 1  
      IF @cInquiry_LOC <> '' AND @cInquiry_LOC IS NOT NULL SET @i = @i + 1  
  
      IF @i = 0  
      BEGIN  
         SET @nErrNo = 63726  
         SET @cErrMsg = rdt.rdtgetmessage( 63726, @cLangCode, 'DSP') --Need SKU/LOC  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail  
      END  
  
      IF @i > 1  
      BEGIN  
         SET @nErrNo = 63727  
         SET @cErrMsg = rdt.rdtgetmessage( 63727, @cLangCode, 'DSP') --Either SKU/LOC  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail  
      END  
  
      -- (james01)  
      SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)  
      IF @cDecodeSP = '0'  
         SET @cDecodeSP = ''  
  
      IF @cDecodeSP <> ''  
      BEGIN  
         IF ISNULL( @cInquiry_SKU, '') <> ''  
            SET @cBarcode = @cInField01  
         ELSE  
            SET @cBarcode = @cInField02  
  
         -- Standard decode  
         IF @cDecodeSP = '1'  
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,   
               @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,   
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
               ' @cSKU           OUTPUT, @cLOC           OUTPUT, ' +  
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
               ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +  
               ' @cLOC           NVARCHAR( 10)  OUTPUT, ' +  
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
               @cSKU          OUTPUT, @cLOC           OUTPUT,   
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,  
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,  
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,  
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,                 
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT  
  
            SET @cInquiry_SKU = @cSKU  
            SET @cInquiry_LOC = @cLOC  
         END  
      END   -- End for DecodeSP  
  
      -- By SKU  
      IF @cInquiry_SKU <> '' AND @cInquiry_SKU IS NOT NULL  
      BEGIN  
  
         EXEC RDT.rdt_GETSKU  
             @cStorerKey = @cStorerKey  
            ,@cSKU       = @cInquiry_SKU OUTPUT  
            ,@bSuccess   = @bSuccess     OUTPUT  
            ,@nErr       = @nErrNo       OUTPUT  
            ,@cErrMsg    = @cErrMsg      OUTPUT  
  
         IF @bSuccess <> 1  
         BEGIN  
            SET @nErrNo = 63728  
            SET @cErrMsg = rdt.rdtgetmessage( 63728, @cLangCode, 'DSP') --Invalid SKU  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_1_Fail  
         END  
      END  
  
      -- By LOC  
      IF @cInquiry_LOC <> '' AND @cInquiry_LOC IS NOT NULL  
      BEGIN    
         IF @cLOCLookUP <> ''       --(yeekung03)   
         BEGIN          
            EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,           
               @cInquiry_LOC OUTPUT,           
               @nErrNo     OUTPUT,           
               @cErrMsg    OUTPUT          
    
            IF @nErrNo <> 0          
               GOTO Step_1_Fail          
         END    
  
         SELECT @cChkFacility = Facility  
         FROM dbo.LOC WITH (NOLOCK)  
         WHERE LOC = @cInquiry_LOC  
  
         -- Validate LOC  
         IF @@ROWCOUNT = 0  
         BEGIN  
            SET @nErrNo = 63729  
            SET @cErrMsg = rdt.rdtgetmessage( 63729, @cLangCode, 'DSP') --Invalid LOC  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Step_1_Fail  
         END  
  
         -- Validate facility  
         IF @cChkFacility <> @cFacility  
         BEGIN  
            SET @nErrNo = 63730  
            SET @cErrMsg = rdt.rdtgetmessage( 63730, @cLangCode, 'DSP') --Diff facility  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Step_1_Fail  
         END      
      END  
  
      -- Get next screen data  
      SET @cCurrentLOC = ''  
      SET @cCurrentSKU = ''  
      EXEC rdt.rdt_SKUInquiry_GetNext @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cInquiry_SKU, @cInquiry_LOC, @cCurrentSKU, @cCurrentLOC,   
         @cNextSKU   OUTPUT,   
         @cNextLOC   OUTPUT,   
         @cSKUDescr  OUTPUT,   
         @cCaseUOM   OUTPUT,  
         @cEachUOM   OUTPUT,   
         @cQtyOnHand OUTPUT,   
         @cQtyAvail  OUTPUT,   
         @cCS_PL     OUTPUT,   
         @cEA_CS     OUTPUT,   
         @cMin       OUTPUT,   
         @cMax       OUTPUT,  
         @nRec       OUTPUT,   
         @nTotRec    OUTPUT,   
         @nErrNo     OUTPUT,   
         @cErrMsg    OUTPUT  
      SET @cCurrentLOC = @cNextLOC  
      SET @cCurrentSKU = @cNextSKU  
  
      -- Prep next screen var  
      SET @cOutField01 = @cCurrentSKU  
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)  
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)  
      SET @cOutField04 = @cQTYOnHand  
      SET @cOutField05 = @cQtyAvail  
      SET @cOutField06 = @cCS_PL  
      SET @cOutField07 = @cEA_CS  
      SET @cOutField08 = @cCurrentLoc  
      SET @cOutField09 = @cMin  
      SET @cOutField10 = @cMax  
      SET @cOutField11 = @cCaseUOM  
      SET @cOutField12 = ''  
      SET @cOutField13 = @cEachUOM  
      SET @cOutField14 = CAST( @nRec AS NVARCHAR( 5)) + '/' + CAST( @nTotRec AS NVARCHAR( 5))  
        
      EXEC rdt.rdtSetFocusField @nMobile, 12 -- Next  
  
      SET @nScn  = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = ''  
   END  
   GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cInquiry_SKU = ''  
      SET @cInquiry_LOC = ''  
  
      SET @cOutField01 = @cInquiry_SKU  
      SET @cOutField02 = @cInquiry_LOC  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 2. Scn = 821. Result  
   CS/PL    (field06, input)  
   EA/CS    (field07, input)  
   PICK LOC (field08, input)  
   MIN      (field09, input)  
   MAX      (field10, input)  
   Next     (field12, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      DECLARE @cInCS_PL   NVARCHAR( 5)  
      DECLARE @cInEA_CS   NVARCHAR( 5)  
      DECLARE @cInPickLOC NVARCHAR( 10)  
      DECLARE @cInMin     NVARCHAR( 5)  
      DECLARE @cInMax     NVARCHAR( 5)  
      DECLARE @cNext      NVARCHAR( 20)  
        
      -- Screen mapping  
      SET @cInCS_PL   = @cInField06  
      SET @cInEA_CS   = @cInField07  
      SET @cInPickLOC = @cInField08  
      SET @cInMin     = @cInField09  
      SET @cInMax     = @cInField10  
      SET @cNext      = @cInField12  
  
      -- Insert alert if setting changed  
      IF (@cCS_PL <> @cInCS_PL OR  
         @cEA_CS <> @cInEA_CS OR  
         @cCurrentLOC <> @cInPickLOC OR  
         @cMin <> @cInMin OR  
         @cMax <> @cInMax) AND   
         @cCurrentSKU <> ''   
      BEGIN  
         -- Validate CS_PL  
         IF (@cCS_PL <> @cInCS_PL) AND RDT.rdtIsValidQTY( @cInCS_PL, 0) = 0  
         BEGIN  
            SET @nErrNo = 63735  
            SET @cErrMsg = rdt.rdtgetmessage( 63735, @cLangCode, 'DSP') --Invalid CS/PL  
            EXEC rdt.rdtSetFocusField @nMobile, 6  
            GOTO Quit  
         END  
     
         -- Validate EA/CS  
         IF (@cEA_CS <> @cInEA_CS) AND RDT.rdtIsValidQTY( @cInEA_CS, 0) = 0  
         BEGIN  
            SET @nErrNo = 63736  
            SET @cErrMsg = rdt.rdtgetmessage( 63736, @cLangCode, 'DSP') --Invalid EA/CS  
            EXEC rdt.rdtSetFocusField @nMobile, 7  
            GOTO Quit  
         END  
     
         IF @cCurrentLOC <> @cInPickLOC  
         BEGIN  
            -- Validate facility  
            IF NOT EXISTS( SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cInPickLOC AND Facility = @cFacility)  
            BEGIN  
               SET @nErrNo = 63737  
               SET @cErrMsg = rdt.rdtgetmessage( 63737, @cLangCode, 'DSP') --PickLOCDiffFAC  
               EXEC rdt.rdtSetFocusField @nMobile, 8  
               GOTO Quit  
            END  
        
            -- Validate loc already assigned  
            IF EXISTS( SELECT 1   
               FROM dbo.SKUxLOC SL WITH (NOLOCK)   
               WHERE SL.LOC = @cInPickLOC   
                  AND SL.StorerKey = @cStorerKey  
                  AND SL.SKU <> @cInquiry_SKU  
                  AND SL.LocationType IN ('PICK', 'CASE') )  
            BEGIN  
               SET @nErrNo = 63738  
               SET @cErrMsg = rdt.rdtgetmessage( 63738, @cLangCode, 'DSP') --PickLOCAssignd  
               EXEC rdt.rdtSetFocusField @nMobile, 8  
               GOTO Quit  
            END  
         END  
     
         -- Validate min  
         IF (@cMin <> @cInMin) AND RDT.rdtIsValidQTY( @cInMin, 0) = 0  
         BEGIN  
            SET @nErrNo = 63739  
            SET @cErrMsg = rdt.rdtgetmessage( 63739, @cLangCode, 'DSP') --Invalid min  
            EXEC rdt.rdtSetFocusField @nMobile, 9  
            GOTO Quit  
         END  
  
         -- Validate min  
         IF (@cMax <> @cInMax) AND RDT.rdtIsValidQTY( @cInMax, 0) = 0  
         BEGIN  
            SET @nErrNo = 63740  
            SET @cErrMsg = rdt.rdtgetmessage( 63740, @cLangCode, 'DSP') --Invalid max  
            EXEC rdt.rdtSetFocusField @nMobile, 10  
            GOTO Quit  
         END  
  
         -- Validate min > max  
         IF CAST( @cInMin AS INT) > CAST( @cInMax AS INT)  
         BEGIN  
            SET @nErrNo = 63741  
            SET @cErrMsg = rdt.rdtgetmessage( 63741, @cLangCode, 'DSP') --Min > Max  
            EXEC rdt.rdtSetFocusField @nMobile, 9  
            GOTO Quit  
         END  

         SET @nErrNo = 0
         EXEC rdt.rdt_SKUInquiry_Update 
            @nMobile       = @nMobile,
            @nFunc         = @nFunc, 
            @cLangCode     = @cLangCode,
            @nStep         = @nStep,
            @nInputKey     = @nInputKey,
            @cStorerKey    = @cStorerKey, 
            @cFacility     = @cFacility, 
            @cInquiry_SKU  = @cCurrentSKU, 
            @cCaseUOM      = @cCaseUOM, 
            @cEAUOM        = @cEachUOM, 
            @cCS_PL        = @cInCS_PL,  
            @cEA_CS        = @cInEA_CS, 
            @cPickLOC      = @cInPickLOC,   
            @cMin          = @cInMin, 
            @cMax          = @cInMax, 
            @tSKUInqUpdate = @tSKUInqUpdate,
            @nErrNo        = @nErrNo      OUTPUT,  
            @cErrMsg       = @cErrMsg     OUTPUT    

         IF @nErrNo > 0 
            GOTO Quit  
         
         -- If packinfo updated (by above) then no need send alert
         IF @nErrNo = 0
         BEGIN
            -- Insert alert  
            EXEC rdt.rdt_SKUInquiry_Alert @nMobile, @nFunc, @cStorerKey, @cFacility, @cCurrentSKU, @cCaseUOM, @cEachUOM,   
               @cCS_PL,      @cInCS_PL,   
               @cEA_CS,      @cInEA_CS,   
               @cCurrentLOC, @cInPickLOC,   
               @cMin,        @cInMin,   
               @cMax,        @cInMax  
  
            DECLARE @cErrMsg1 NVARCHAR( 20)  
            SET @cErrMsg1 = rdt.rdtgetmessage( 63742, @cLangCode, 'DSP') --SKUAlertToWMS  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1  
            EXEC rdt.rdtSetFocusField @nMobile, 12 -- Next  
         END
         
         SET @nErrNo = 0
         GOTO Quit  
      END  
        
      -- Next SKU or LOC  
      IF @cNext <> ''  
      BEGIN  
         -- (james01)  
         SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)  
         IF @cDecodeSP = '0'  
            SET @cDecodeSP = ''  
  
         IF @cDecodeSP <> ''  
         BEGIN  
            SET @cBarcode = @cInField12   -- @cNext  
  
            -- Standard decode  
            IF @cDecodeSP = '1'  
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,   
                  @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,   
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
                  ' @cSKU           OUTPUT, @cLOC           OUTPUT, ' +  
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
                  ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +  
                  ' @cLOC           NVARCHAR( 10)  OUTPUT, ' +  
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
                  @cSKU          OUTPUT, @cLOC           OUTPUT,   
                  @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,  
                  @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,  
                  @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,  
                  @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,                 
                  @nErrNo        OUTPUT, @cErrMsg        OUTPUT  
  
               IF ISNULL( @cInquiry_SKU, '') <> ''  
                  SET @cNext = @cSKU  
               ELSE  
                  SET @cNext = @cLOC  
            END  
         END   -- End for DecodeSP  
  
         -- By SKU  
         IF ISNULL( @cInquiry_SKU, '') <> ''  
         BEGIN  
            EXEC RDT.rdt_GETSKU  
                @cStorerKey = @cStorerKey  
               ,@cSKU       = @cNext      OUTPUT  
               ,@bSuccess   = @bSuccess   OUTPUT  
               ,@nErr       = @nErrNo     OUTPUT  
               ,@cErrMsg    = @cErrMsg    OUTPUT  
     
            IF @bSuccess <> 1  
            BEGIN  
               SET @nErrNo = 63731  
               SET @cErrMsg = rdt.rdtgetmessage( 63731, @cLangCode, 'DSP') --Invalid SKU  
               EXEC rdt.rdtSetFocusField @nMobile, 12  
               GOTO Step_2_Fail  
            END  
            SET @cInquiry_SKU = @cNext  
         END  
  
         -- By LOC  
         IF ISNULL( @cInquiry_LOC, '') <> ''  
         BEGIN  
            SELECT @cChkFacility = Facility  
            FROM dbo.LOC WITH (NOLOCK)  
            WHERE LOC = @cNext  
     
            -- Validate LOC  
            IF @@ROWCOUNT = 0  
            BEGIN  
               SET @nErrNo = 63732  
               SET @cErrMsg = rdt.rdtgetmessage( 63732, @cLangCode, 'DSP') --Invalid LOC  
               EXEC rdt.rdtSetFocusField @nMobile, 12  
               GOTO Step_2_Fail  
            END  
     
            -- Validate facility  
            IF @cChkFacility <> @cFacility  
            BEGIN  
               SET @nErrNo = 63733  
               SET @cErrMsg = rdt.rdtgetmessage( 63733, @cLangCode, 'DSP') --Diff facility  
               EXEC rdt.rdtSetFocusField @nMobile, 12  
               GOTO Step_2_Fail  
            END  
            SET @cInquiry_LOC = @cNext  
         END  
  
         -- To go into loop result  
         SET @cNext = ''   
         SET @cCurrentSKU = ''  
         SET @cCurrentLOC = ''  
         SET @nRec = 0  
      END  
  
      -- Loop result  
      IF @cNext = ''  
      BEGIN  
         IF @nRec = @nTotRec AND @nRec > 0  
         BEGIN  
            SET @nErrNo = 63734  
            SET @cErrMsg = rdt.rdtgetmessage( 63734, @cLangCode, 'DSP') --No more record  
            EXEC rdt.rdtSetFocusField @nMobile, 12  
            GOTO Step_2_Fail  
         END  
           
         -- Get next screen data  
         EXEC rdt.rdt_SKUInquiry_GetNext @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cInquiry_SKU, @cInquiry_LOC, @cCurrentSKU, @cCurrentLOC,   
            @cNextSKU   OUTPUT,   
            @cNextLOC   OUTPUT,   
            @cSKUDescr  OUTPUT,   
            @cCaseUOM   OUTPUT,  
            @cEachUOM   OUTPUT,   
            @cQtyOnHand OUTPUT,   
            @cQtyAvail  OUTPUT,   
            @cCS_PL     OUTPUT,   
            @cEA_CS     OUTPUT,   
            @cMin       OUTPUT,   
            @cMax       OUTPUT,  
            @nRec       OUTPUT,   
            @nTotRec    OUTPUT,   
            @nErrNo     OUTPUT,   
            @cErrMsg    OUTPUT  
         SET @cCurrentLOC = @cNextLOC  
         SET @cCurrentSKU = @cNextSKU  
  
         -- Prep next screen var  
         SET @cOutField01 = @cCurrentSKU  
         SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)  
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)  
         SET @cOutField04 = @cQTYOnHand  
         SET @cOutField05 = @cQtyAvail  
         SET @cOutField06 = @cCS_PL  
         SET @cOutField07 = @cEA_CS  
         SET @cOutField08 = @cCurrentLoc  
         SET @cOutField09 = @cMin  
         SET @cOutField10 = @cMax  
         SET @cOutField11 = @cCaseUOM  
         SET @cOutField13 = @cEachUOM  
         SET @cOutField14 = CAST( @nRec AS NVARCHAR( 5)) + '/' + CAST( @nTotRec AS NVARCHAR( 5))  
           
         GOTO Quit  
      END  
   END  
     
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Prep prev screen var  
      IF @cInquiry_SKU <> '' EXEC rdt.rdtSetFocusField @nMobile, 1  
      IF @cInquiry_LOC <> '' EXEC rdt.rdtSetFocusField @nMobile, 2  
  
      SET @cInquiry_SKU = ''  
      SET @cInquiry_LOC = ''  
      SET @cOutField01 = @cInquiry_SKU  
      SET @cOutField02 = @cInquiry_LOC  
        
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cNext = ''  
      SET @cOutField12 = ''  
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
  
      V_SKU  = @cInquiry_SKU,  
      V_LOC  = @cInquiry_LOC,  
  
      V_String1 = @cCurrentSKU,  
      V_String2 = @cCurrentLOC,  
      V_String5 = @cCS_PL,   
      V_String6 = @cEA_CS,   
      V_String7 = @cMin,   
      V_String8 = @cMax,   
      V_String9 = @cCaseUOM,  
      V_String10 = @cEachUOM,   
      V_String11 = @cLOCLookUP,              --(yeekung01)  
        
      V_Integer1 = @nRec,  
      V_Integer2 = @nTotRec,  
  
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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15  
   WHERE Mobile = @nMobile  
END  

GO
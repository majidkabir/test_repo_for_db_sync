SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************/
/* Store procedure: rdtfnc_Receive_By_Pallet                                    */
/* Copyright      : IDS                                                         */
/*                                                                              */
/* Purpose: ASN receiving by pallet id (MHAP Migration use)                     */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date         Rev   Author   Purposes                                         */
/* 14-Mar-2016  1.0   James    SOS365315 - Created                              */
/* 30-Sep-2016  1.1   Ung      Performance tuning                               */   
/* 26-Oct-2018  1.2   Gan      Performance tuning                               */
/* 20-Aug-2019  1.3   YeeKung   WMS-10286 Add ExtendedValidate  (yeekung01)     */ 
/* 15-Oct-2019  1.4   Chermaine WMS-10822 Add RDT                               */
/*                    config-NotAutoFinalizeByLine(cc01)                        */ 
/********************************************************************************/ 

CREATE PROC [RDT].[rdtfnc_Receive_By_Pallet] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
) AS

SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
-- Misc variable  
DECLARE  
   @cSQL           NVARCHAR( MAX),  
   @cSQLParam      NVARCHAR( MAX)  
  
  
-- Define a variable  
DECLARE    
   @nFunc           INT,    
   @nScn            INT,    
   @nStep           INT,    
   @cLangCode       NVARCHAR( 3),    
   @nInputKey       INT,    
   @nMenu           INT,    
   @cPrinter        NVARCHAR(10),    
   @cUserName       NVARCHAR(18),    
   @cStorerKey      NVARCHAR(15),    
   @cFacility       NVARCHAR( 5),    
   @cReceiptKey     NVARCHAR( 10),    
   @cPOKey          NVARCHAR( 10),    
   @cLOC            NVARCHAR( 20),    
   @cSKU            NVARCHAR( 20),    
   @cUOM            NVARCHAR( 10),    
   @cID             NVARCHAR( 18),    
   @cSKUDesc        NVARCHAR( 60),    
   @cQTY            NVARCHAR( 10),    
   @cPackQTY        NVARCHAR( 10),   
   @cPackUOM        NVARCHAR( 10),   
   @cBaseUOM        NVARCHAR( 10),   
   @cReasonCode     NVARCHAR( 10),    
   @cIVAS           NVARCHAR( 20),    
   @cLotLabel01     NVARCHAR( 20),    
   @cLotLabel02     NVARCHAR( 20),    
   @cLotLabel03     NVARCHAR( 20),    
   @cLotLabel04     NVARCHAR( 20),    
   @cLotLabel05     NVARCHAR( 20),    
   @cLotLabel06     NVARCHAR( 20),    
   @cLotLabel07     NVARCHAR( 20),    
   @cLotLabel08     NVARCHAR( 20),    
   @cLotLabel09     NVARCHAR( 20),    
   @cLotLabel10     NVARCHAR( 20),    
   @cLotLabel11     NVARCHAR( 20),    
   @cLotLabel12     NVARCHAR( 20),    
   @cLotLabel13     NVARCHAR( 20),    
   @cLotLabel14     NVARCHAR( 20),    
   @cLotLabel15     NVARCHAR( 20),    
   @cLottable01     NVARCHAR( 18),    
   @cLottable02     NVARCHAR( 18),    
   @cLottable03     NVARCHAR( 18),    
   @cLottable04     NVARCHAR( 16),    
   @cLottable05     NVARCHAR( 16),    
   @cLottable06     NVARCHAR( 30),    
   @cLottable07     NVARCHAR( 30),    
   @cLottable08     NVARCHAR( 30),    
   @cLottable09     NVARCHAR( 30),    
   @cLottable10     NVARCHAR( 30),    
   @cLottable11     NVARCHAR( 30),    
   @cLottable12     NVARCHAR( 30),    
   @cLottable13     NVARCHAR( 16),    
   @cLottable14     NVARCHAR( 16),    
   @cLottable15     NVARCHAR( 16),    
   @dLottable04         DATETIME,  
   @dLottable05         DATETIME,  
   @dLottable13         DATETIME,  
   @dLottable14         DATETIME,  
   @dLottable15         DATETIME,  
   @cLottable01Label    NVARCHAR( 20),  
   @cLottable02Label    NVARCHAR( 20),  
   @cLottable03Label    NVARCHAR( 20),  
   @cLottable04Label    NVARCHAR( 20),  
   @cLottable05Label    NVARCHAR( 20),  
   @cLottable06Label    NVARCHAR( 20),  
   @cLottable07Label    NVARCHAR( 20),  
   @cLottable08Label    NVARCHAR( 20),  
   @cLottable09Label    NVARCHAR( 20),  
   @cLottable10Label    NVARCHAR( 20),  
   @cLottable11Label    NVARCHAR( 20),  
   @cLottable12Label    NVARCHAR( 20),  
   @cLottable13Label    NVARCHAR( 20),  
   @cLottable14Label    NVARCHAR( 20),  
   @cLottable15Label    NVARCHAR( 20),  
   @cPackKey            NVARCHAR( 10),    
   @cOption             NVARCHAR( 1),    
   @cExternPOKey        NVARCHAR( 20),   
   @cExternReceiptKey   NVARCHAR( 20),   
   @cExternLineNo       NVARCHAR( 20),   
   @cPrefUOM            NVARCHAR(  1),   
   @cAllowOverRcpt      NVARCHAR(  1),   
   @nASNExists          INT,    
   @nREFExists          INT,    
   @cSourcekey          NVARCHAR(15),   
   @cChkReceiptKey      NVARCHAR( 10),  
   @cReceiptStatus      NVARCHAR( 10),   
   @cChkStorerKey       NVARCHAR( 15),    
   @cChkFacility        NVARCHAR( 5),    
   @cExtPalletID        NVARCHAR( 20),    
   @cItemClass          NVARCHAR( 10),    
   @cSKUType            NVARCHAR( 20),       
   @cSSCC               NVARCHAR( 30),       
   @cDecodeSP           NVARCHAR( 20),  
   @cToID               NVARCHAR( 18),  
   @cReceiptLineNumber  NVARCHAR( 5),  
   @nRowCount           INT,   
   @nPalletQty          INT,   
   @nQTY                INT,   
   @nRecCount           INT,   
   @nCurRec             INT,   
   @nStartTCnt          INT,   
   @cBarcode            NVARCHAR( 60),  
   @cLong               NVARCHAR( 250),  
   @cExtendedValidateSP NVARCHAR(30),      
   @cLot5toLot4         NVARCHAR(1),  
   @cNotAutoFinalizeByLine NVARCHAR(1),   
     
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
   @cDecodeLabelNo       NVARCHAR( 20)  
  
  
-- Getting Mobile information  
SELECT  
   @nFunc            = Func,  
   @nScn             = Scn,  
   @nStep            = Step,  
   @nInputKey        = InputKey,  
   @cLangCode        = Lang_code,  
   @nMenu            = Menu,  
  
   @cFacility        = Facility,  
   @cStorerKey       = StorerKey,  
   @cPrinter         = Printer,  
   @cUserName        = UserName,  
  
   @cReceiptKey      = V_ReceiptKey,  
   @cSKU             = V_SKU,  
   @cSKUDesc         = V_SKUDescr,  
   @cUOM             = V_UOM,  
   @nQTY             = V_Qty,  
  
   @cLottable01      = V_Lottable01,  
   @cLottable02   = V_Lottable02,  
   @cLottable03   = V_Lottable03,  
   @dLottable04   = V_Lottable04,  
   @dLottable05   = V_Lottable05,  
   @cLottable06   = V_Lottable06,  
   @cLottable07   = V_Lottable07,  
   @cLottable08   = V_Lottable08,  
   @cLottable09   = V_Lottable09,  
   @cLottable10   = V_Lottable10,  
   @cLottable11   = V_Lottable11,  
   @cLottable12   = V_Lottable12,  
   @dLottable13   = V_Lottable13,  
   @dLottable14   = V_Lottable14,  
   @dLottable15   = V_Lottable15,  
     
   @nRecCount        = V_Integer1,  
   @nCurRec          = V_Integer2,  
  
   @cExternReceiptKey   = V_String1,  
   @cExtPalletID        = V_String2,  
   @cSKUType            = V_String3,  
  -- @nRecCount           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,  
   @cSSCC               = V_String5,  
  -- @nCurRec             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,  
   @cExtendedValidateSP    = V_String6,      
   @cLot5toLot4            = V_String7,       
   @cNotAutoFinalizeByLine = V_String8,   
  
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
  
FROM   RDT.RDTMOBREC (NOLOCK)  
WHERE  Mobile = @nMobile  
  
-- Redirect to respective screen    
IF @nFunc = 1823    
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Func = 550. Menu    
   IF @nStep = 1 GOTO Step_1   -- Scn = 4520. ASN #    
   IF @nStep = 2 GOTO Step_2   -- Scn = 4521. EXT PALLET ID    
   IF @nStep = 3 GOTO Step_3   -- Scn = 4522. SSCC    
   IF @nStep = 4 GOTO Step_4   -- Scn = 4523. PALLET INFO    
   IF @nStep = 5 GOTO Step_5   -- Scn = 4524. LF PALLET ID    
   IF @nStep = 6 GOTO Step_6   -- Scn = 4525. MESSAGE    
END    
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 1823)  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn  = 4520  
   SET @nStep = 1  
  
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)          
   IF @cExtendedValidateSP = '0'          
      SET @cExtendedValidateSP = ''         
         
   SET @cLot5toLot4 = rdt.RDTGetConfig( @nFunc, 'Lot5toLot4', @cStorerKey)     
     
   SET @cNotAutoFinalizeByLine = rdt.RDTGetConfig( @nFunc, 'NotAutoFinalizeByLine', @cStorerKey)          
   IF @cNotAutoFinalizeByLine = '0'          
      SET @cNotAutoFinalizeByLine = ''   
     
   -- EventLog - Sign In Function  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType = '1', -- Sign in function  
      @cUserID     = @cUserName,  
      @nMobileNo   = @nMobile,  
      @nFunctionID = @nFunc,  
      @cFacility   = @cFacility,  
      @cStorerKey  = @cStorerkey,  
      @nStep       = @nStep  
  
   -- initialise all variable  
   SET @cReceiptKey = ''  
   SET @cExternReceiptKey = ''  
   
   -- Init screen  
   SET @cOutField01 = ''  
   SET @cOutField02 = ''  
  
    -- (Vicky06) EventLog - Sign In Function  
    EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerKey,  
     @nStep       = @nStep  
END  
GOTO Quit  
  
/********************************************************************************  
Step 1. screen = 4520  
   ASN (Field01, input)  
   REF (Field02, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cReceiptKey = ISNULL( @cInField01, '')  
      SET @cExternReceiptKey = ISNULL( @cInField02, '')  
    
      -- Validate at least one field must key-in    
      IF ISNULL( @cReceiptKey, '') = '' AND ISNULL( @cExternReceiptKey, '') = ''  
      BEGIN    
         SET @nErrNo = 97401  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Value required'    
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Quit  
      END    
    
      -- Both value keyed-in    
      IF ISNULL( @cReceiptKey, '') <> '' AND ISNULL( @cExternReceiptKey, '') <> ''  
      BEGIN    
         -- Get the ASN    
         SELECT    
            @cChkFacility = Facility,    
            @cChkStorerKey = StorerKey,    
            @cReceiptStatus = [Status]  
         FROM dbo.Receipt WITH (NOLOCK)    
         WHERE ReceiptKey = @cReceiptKey    
         AND   ExternReceiptKey = @cExternReceiptKey    
         AND   StorerKey = @cStorerKey  
  
         IF @@ROWCOUNT = 0    
         BEGIN    
            SET @nASNExists = 0    
            SET @nREFExists = 0    
    
            -- No row returned, either ASN or PO not exists    
            IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)    
               WHERE StorerKey = @cStorerKey    
               AND   ReceiptKey = @cReceiptKey)    
                  SET @nASNExists = 1    
    
            IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)    
               WHERE StorerKey = @cStorerKey    
               AND   ExternReceiptKey = @cExternReceiptKey)  
                  SET @nREFExists = 1    
    
            -- Both ASN & PO also not exists    
            IF (@nASNExists = 0 AND @nREFExists = 0)    
            BEGIN    
               SET @nErrNo = 97402  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASN not exists'    
               SET @cOutField01 = ''  
               SET @cOutField02 = ''  
               EXEC rdt.rdtSetFocusField @nMobile, 1  
               GOTO Quit    
            END    
            ELSE    
            -- Only ASN not exists    
            IF @nASNExists = 0    
            BEGIN    
               SET @nErrNo = 97403  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASN not exists'    
               SET @cOutField01 = '' -- ReceiptKey    
               SET @cOutField02 = @cExternReceiptKey -- ExternReceiptKey    
               EXEC rdt.rdtSetFocusField @nMobile, 1  
               GOTO Quit    
            END    
            ELSE    
            -- Only PO not exists    
            IF @nREFExists = 0    
            BEGIN    
               SET @nErrNo = 97404  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ref not exists'    
               SET @cOutField01 = @cReceiptKey -- ReceiptKey    
               SET @cOutField02 = '' -- ExternReceiptKey    
               EXEC rdt.rdtSetFocusField @nMobile, 2  
               GOTO Quit    
            END    
         END    
      END    
  
      -- Only ASN # keyed-in (POKey = blank)    
      IF ISNULL( @cReceiptKey, '') <> ''   
      BEGIN    
         -- Validate ASN   
         SELECT   
            @cExternReceiptKey = ExternReceiptKey,  
            @cChkFacility = Facility,    
            @cChkStorerKey = StorerKey,    
            @cReceiptStatus = [Status]    
         FROM dbo.Receipt WITH (NOLOCK)    
         WHERE ReceiptKey = @cReceiptKey    
         AND   StorerKey = @cStorerKey  
  
         IF @@ROWCOUNT = 0  
         BEGIN    
            SET @nErrNo = 97405  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASN not exists'    
            SET @cOutField01 = ''  
            SET @cOutField02 = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Quit    
         END    
      END    
      ELSE  -- Only ExternReceiptKey keyed-in  
      BEGIN    
         -- Validate ExternReceiptKey  
         SELECT     
            @cChkFacility = Facility,    
            @cChkStorerKey = StorerKey,    
            @cReceiptKey = ReceiptKey,    
            @cReceiptStatus = [Status]    
         FROM dbo.Receipt R WITH (NOLOCK)    
         WHERE ExternReceiptKey = @cExternReceiptKey    
         AND   StorerKey = @cStorerKey  
  
         IF @@ROWCOUNT = 0    
         BEGIN    
            SET @nErrNo = 97406  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ref not exists'    
            SET @cOutField01 = @cReceiptKey -- ReceiptKey    
            SET @cOutField02 = '' -- ExternReceiptKey    
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Quit    
         END    
      END    
    
      -- Validate ASN in different facility    
      IF @cFacility <> @cChkFacility    
      BEGIN    
         SET @nErrNo = 97407  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASN facility diff'    
         SET @cOutField01 = '' -- ReceiptKey    
         SET @cReceiptKey = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Quit    
      END    
    
      -- Validate ASN belong to the storer    
      IF ISNULL( @cChkStorerKey, '') = ''    
      BEGIN    
         SET @nErrNo = 97408  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASN storer different'    
         SET @cOutField01 = '' -- ReceiptKey    
         SET @cReceiptKey = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Quit    
      END    
    
      -- Validate ASN status    
      IF @cReceiptStatus = '9'    
      BEGIN    
         SET @nErrNo = 97409  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASN is closed'    
         SET @cOutField01 = '' -- ReceiptKey    
         SET @cReceiptKey = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Quit    
      END    
    
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = @cExternReceiptKey  
      SET @cOutField03 = ''  
  
      -- Go to next screen    
      SET @nScn = @nScn + 1    
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
  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
  
      SET @cReceiptKey = ''  
      SET @cExternReceiptKey = ''  
   END  
   GOTO Quit  
  
END  
GOTO Quit  
  
/********************************************************************************  
Step 2. screen = 4521  
   ASN            (Field01)  
   REF            (Field02)  
   EXT PALLET ID  (Field03, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cExtPalletID = @cInField03  
  
      -- Validate blank  
      IF ISNULL( @cExtPalletID, '') = ''   
      BEGIN  
         SET @nErrNo = 97410  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet req  
         GOTO Step_2_Fail  
      END  
  
      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)   
                      WHERE ReceiptKey = @cReceiptKey  
                      AND   StorerKey = @cStorerKey  
                      AND   Lottable11 = @cExtPalletID)  
      BEGIN  
         SET @nErrNo = 97411  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv pallet  
         GOTO Step_2_Fail  
      END  
  
         SELECT @nQTY = CASE WHEN ISNULL( SUM( QTYExpected), 0) > ISNULL( SUM( BeforeReceivedQTY), 0) THEN   
                        ISNULL( SUM( QTYExpected - BeforeReceivedQTY), 0) ELSE 0 END  
         FROM dbo.ReceiptDetail WITH (NOLOCK)  
         WHERE ReceiptKey = @cReceiptKey  
         AND   StorerKey = @cStorerKey  
         AND   Lottable11 = @cExtPalletID  
         AND   FinalizeFlag <> 'Y'  
  
      IF ISNULL( @nQTY, 0) = 0  
      BEGIN  
         SET @nErrNo = 97412  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet rcv b4  
         GOTO Step_2_Fail  
      END  
  
      -- Pallet might have multi sku but will not mix sku.itemclass  
      SELECT TOP 1   
         @cItemClass = SKU.ItemClass,  
         @cSSCC = RD.Lottable09     
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)   
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)   
      WHERE RD.ReceiptKey = @cReceiptKey  
      AND   RD.StorerKey = @cStorerKey  
      AND   RD.Lottable11 = @cExtPalletID  
      AND   RD.FinalizeFlag <> 'Y'  
  
      IF @cItemClass = '001'  
      BEGIN  
         SET @cSKUType = 'FG'  
         SET @cOutField01 = @cExtPalletID  
         SET @cOutField02 = @cSSCC  
         SET @cOutField03 = @cSSCC  
  
         SET @cLottable09 = @cSSCC  
  
         SET @nScn  = @nScn + 1    
         SET @nStep = @nStep + 1  
      END  
      ELSE  
      BEGIN  
         SET @cSKUType = 'POSM'  
  
         SELECT TOP 1   
            @cSKU = SKU,  
            @cLottable01 = Lottable01,   
            @cLottable02 = Lottable02,   
            @dLottable04 = Lottable04,     
            @dLottable05 = Lottable05,   
            @cLottable09 = Lottable09,   
            @cLottable11 = Lottable11,   
            @dLottable13 = Lottable13,   
            @nQTY        = CASE WHEN ISNULL( SUM( QTYExpected), 0) > ISNULL( SUM( BeforeReceivedQTY), 0) THEN   
                           ISNULL( SUM( QTYExpected - BeforeReceivedQTY), 0) ELSE 0 END  
         FROM dbo.ReceiptDetail WITH (NOLOCK)  
         WHERE ReceiptKey = @cReceiptKey  
         AND   StorerKey = @cStorerKey  
         AND   Lottable11 = @cExtPalletID  
         AND   FinalizeFlag <> 'Y'  
         AND   LTRIM( SKU + Lottable01 + Lottable02 + CONVERT( NVARCHAR( 10), Lottable05, 112) + Lottable09 + CONVERT( NVARCHAR( 10), Lottable13, 112)) > ''  
         GROUP BY SKU, Lottable01, Lottable02,Lottable04, Lottable05,           
                  Lottable09, Lottable11, Lottable13          
         ORDER BY SKU          
          
         SELECT @nRecCount = COUNT( 1)          
         FROM dbo.ReceiptDetail WITH (NOLOCK)          
         WHERE ReceiptKey = @cReceiptKey          
         AND   StorerKey = @cStorerKey          
         AND   Lottable11 = @cExtPalletID          
         AND   FinalizeFlag <> 'Y'          
         GROUP BY SKU, Lottable01, Lottable02,Lottable04, Lottable05, Lottable13, UOM       
  
         SET @nRecCount = @@ROWCOUNT  
         --GROUP BY SKU, Lottable01, Lottable02, Lottable05,   
         --         Lottable09, Lottable11, Lottable13  
  
         SELECT   
            @cSKUDesc = DESCR,  
            @cLottable01Label = CASE WHEN ISNULL( LOTTABLE01LABEL, '') = '' THEN 'L01' ELSE LOTTABLE01LABEL END,  
            @cLottable02Label = CASE WHEN ISNULL( LOTTABLE02LABEL, '') = '' THEN 'L02' ELSE LOTTABLE02LABEL END,  
            @cLottable04Label = CASE WHEN ISNULL( LOTTABLE04LABEL, '') = '' THEN 'L04' ELSE LOTTABLE04LABEL END,              
            @cLottable05Label = CASE WHEN ISNULL( LOTTABLE05LABEL, '') = '' THEN 'L05' ELSE LOTTABLE05LABEL END,  
            @cLottable09Label = CASE WHEN ISNULL( LOTTABLE09LABEL, '') = '' THEN 'L09' ELSE LOTTABLE09LABEL END,  
            @cLottable11Label = CASE WHEN ISNULL( LOTTABLE11LABEL, '') = '' THEN 'L11' ELSE LOTTABLE11LABEL END,  
            @cLottable13Label = CASE WHEN ISNULL( LOTTABLE13LABEL, '') = '' THEN 'L13' ELSE LOTTABLE13LABEL END  
         FROM dbo.SKU WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   SKU = @cSKU  
  
         --SELECT @cUOM = PackUOM3  
         --FROM dbo.SKU WITH (NOLOCK)  
         --JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
         --WHERE StorerKey = @cStorerKey  
         --AND   SKU = @cSKU  
  
         SET @nCurRec = 1  
  
         SET @cOutField01 = @cSKU  
         SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)  
         SET @cOutField04 = 'L01:' + @cLottable01  
         SET @cOutField05 = 'L02:' + @cLottable02  
         SET @cOutField06 = CASE WHEN @cLot5toLot4 = '1' THEN 'L04:' + rdt.rdtFormatDate( @dLottable04) ELSE'L05:' + rdt.rdtFormatDate( @dLottable05) END         
         SET @cOutField07 = 'L09:' + @cLottable09  
         SET @cOutField08 = 'L11:' +  @cLottable11  
         SET @cOutField09 = 'L13:' + rdt.rdtFormatDate( @dLottable13)  
         SET @cOutField10 = @cUOM  
         SET @cOutField11 = @nQTY  
         SET @cOutField12 = CAST( @nCurRec AS NVARCHAR( 2)) + '/' + CAST( @nRecCount AS NVARCHAR( 2))  
         SET @cOutField13 = ''  
  
         SET @nScn  = @nScn + 2    
         SET @nStep = @nStep + 2   
      END  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
        
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      SET @cExtPalletID = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 3. screen = 4522  
   EXT PALLET ID  (Field01)  
   SSCC           (Field01, input)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      SET @cBarcode = @cInField03  
  
      -- Validate blank  
      IF ISNULL(@cBarcode, '') = ''  
      BEGIN  
         SET @nErrNo = 97413  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC req  
         GOTO Step_3_Fail  
      END  
  
      SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)  
      IF @cDecodeSP = '0'  
         SET @cDecodeSP = ''  
  
      IF @cDecodeSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')  
         BEGIN  
            SELECT @cSKU = '', @nQTY = 0,  
               @cLottable01 = '', @cLottable02 = '', @cLottable03 = '', @dLottable04 = 0,  @dLottable05 = 0,  
               @cLottable06 = '', @cLottable07 = '', @cLottable08 = '', @cLottable09 = '', @cLottable10 = '',  
               @cLottable11 = '', @cLottable12 = '', @dLottable13 = 0,  @dLottable14 = 0,  @dLottable15 = 0  
  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cBarcode, @cFieldName, ' +  
               ' @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT, ' +  
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +  
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +  
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +  
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'  
            SET @cSQLParam =  
               ' @nMobile      INT,           ' +  
               ' @nFunc        INT,           ' +  
               ' @cLangCode    NVARCHAR( 3),  ' +  
               ' @nStep        INT,           ' +  
               ' @nInputKey    INT,           ' +  
               ' @cStorerKey   NVARCHAR( 15), ' +  
               ' @cReceiptKey  NVARCHAR( 10), ' +  
               ' @cPOKey       NVARCHAR( 10), ' +  
               ' @cLOC         NVARCHAR( 10), ' +  
               ' @cBarcode     NVARCHAR( 60), ' +  
               ' @cFieldName   NVARCHAR( 10), ' +  
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +  
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +  
               ' @nQTY         INT            OUTPUT, ' +  
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +  
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +  
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +  
               ' @dLottable04  DATETIME       OUTPUT, ' +  
               ' @dLottable05  DATETIME       OUTPUT, ' +  
               ' @cLottable06  NVARCHAR( 30)  OUTPUT, ' +  
               ' @cLottable07  NVARCHAR( 30)  OUTPUT, ' +  
               ' @cLottable08  NVARCHAR( 30)  OUTPUT, ' +  
               ' @cLottable09  NVARCHAR( 30)  OUTPUT, ' +  
               ' @cLottable10  NVARCHAR( 30)  OUTPUT, ' +  
               ' @cLottable11  NVARCHAR( 30)  OUTPUT, ' +  
               ' @cLottable12  NVARCHAR( 30)  OUTPUT, ' +  
               ' @dLottable13  DATETIME       OUTPUT, ' +  
               ' @dLottable14  DATETIME       OUTPUT, ' +  
               ' @dLottable15  DATETIME       OUTPUT, ' +  
               ' @nErrNo       INT            OUTPUT, ' +  
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cBarcode, 'ID',  
               @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT,  
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,  
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,  
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,  
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_3_Fail  
  
            -- SSCC value must match  
            IF ISNULL(@cOutField02, '') <> '' AND   
               ISNULL( @cLottable09, '') <> ISNULL(@cOutField02, '')  
            BEGIN  
               SET @nErrNo = 97414  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong SSCC  
               GOTO Step_3_Fail  
            END  
         END  
      END  
      ELSE   
         SET @cLottable09 = @cBarcode  
  
      SET @cSSCC = @cLottable09  
  
      SELECT   
         @cLong = ISNULL( Long, '')  
      FROM dbo.CodeLKUP WITH (NOLOCK)   
      WHERE ListName = 'SSCCDECODE'  
         AND StorerKey = @cStorerKey  
  
      IF @cOutField02 = '' AND @cInField03 <> @cLong  
      BEGIN  
         SET @nErrNo = 97421  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong SSCC  
         SET @cOutField01 = @cExtPalletID  
         SET @cOutField03 = ''  
         GOTO Quit  
      END  
  
      SELECT TOP 1           
         @cSKU = SKU,          
         @cLottable01 = Lottable01,           
         @cLottable02 = Lottable02,    
         @dLottable04 = Lottable04,           
         @dLottable05 = Lottable05,           
         @cLottable11 = Lottable11,           
         @dLottable13 = Lottable13,           
         @cUOM        = UOM,          
         @nQTY        = CASE WHEN ISNULL( SUM( QTYExpected), 0) > ISNULL( SUM( BeforeReceivedQTY), 0) THEN           
                        ISNULL( SUM( QTYExpected - BeforeReceivedQTY), 0) ELSE 0 END          
      FROM dbo.ReceiptDetail WITH (NOLOCK)          
      WHERE ReceiptKey = @cReceiptKey          
      AND   StorerKey = @cStorerKey          
      AND   Lottable11 = @cExtPalletID          
      AND   FinalizeFlag <> 'Y'          
      AND   Lottable09 = CASE WHEN @cInField03 = 'X' THEN Lottable09 ELSE @cOutField02 END          
      AND   LTRIM( SKU + Lottable01 + Lottable02 + CONVERT( NVARCHAR( 10), Lottable05, 112) +           
                   CONVERT( NVARCHAR( 10), Lottable13, 112)) > ''          
            --LTRIM( @cSKU + @cLottable01 + @cLottable02 + CONVERT( NVARCHAR( 10), @dLottable05, 112) +           
            --       CONVERT( NVARCHAR( 10), @dLottable13, 112))          
      GROUP BY SKU, Lottable01, Lottable02,Lottable04, Lottable05,           
               Lottable11, Lottable13, UOM          
      ORDER BY SKU        
  
      SELECT @nRecCount = COUNT( 1)  
      FROM dbo.ReceiptDetail WITH (NOLOCK)  
      WHERE ReceiptKey = @cReceiptKey  
      AND   StorerKey = @cStorerKey  
      AND   Lottable11 = @cExtPalletID  
      AND   FinalizeFlag <> 'Y'  
      --AND   Lottable09 = CASE WHEN @cInField03 = 'X' THEN Lottable09 ELSE @cOutField02 END  
      GROUP BY SKU, Lottable01, Lottable02, Lottable05, Lottable13, UOM  
  
      SET @nRecCount = @@ROWCOUNT  
  
      SELECT   
         @cSKUDesc = DESCR,  
         @cLottable01Label = CASE WHEN ISNULL( LOTTABLE01LABEL, '') = '' THEN 'L01' ELSE LOTTABLE01LABEL END,  
         @cLottable02Label = CASE WHEN ISNULL( LOTTABLE02LABEL, '') = '' THEN 'L02' ELSE LOTTABLE02LABEL END,  
         @cLottable04Label = CASE WHEN ISNULL( LOTTABLE04LABEL, '') = '' THEN 'L04' ELSE LOTTABLE04LABEL END,          
         @cLottable05Label = CASE WHEN ISNULL( LOTTABLE05LABEL, '') = '' THEN 'L05' ELSE LOTTABLE05LABEL END,  
         @cLottable09Label = CASE WHEN ISNULL( LOTTABLE09LABEL, '') = '' THEN 'L09' ELSE LOTTABLE09LABEL END,  
         @cLottable11Label = CASE WHEN ISNULL( LOTTABLE11LABEL, '') = '' THEN 'L11' ELSE LOTTABLE11LABEL END,  
         @cLottable13Label = CASE WHEN ISNULL( LOTTABLE13LABEL, '') = '' THEN 'L13' ELSE LOTTABLE13LABEL END  
      FROM dbo.SKU WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   SKU = @cSKU  
  
      --SELECT @cUOM = PackUOM3  
      --FROM dbo.SKU WITH (NOLOCK)  
      --JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
      --WHERE StorerKey = @cStorerKey  
      --AND   SKU = @cSKU  
  
      SET @nCurRec = 1  
  
      SET @cOutField01 = @cSKU  
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)  
      SET @cOutField04 = 'L01:' + @cLottable01  
      SET @cOutField05 = 'L02:' + @cLottable02  
      SET @cOutField06 = CASE WHEN @cLot5toLot4 = '1' THEN 'L04:' + rdt.rdtFormatDate( @dLottable04) ELSE'L05:' + rdt.rdtFormatDate( @dLottable05) END         
      SET @cOutField07 = 'L09:' + @cLottable09  
      SET @cOutField08 = 'L11:' +  @cLottable11  
      SET @cOutField09 = 'L13:' + rdt.rdtFormatDate( @dLottable13)  
      SET @cOutField10 = @cUOM  
      SET @cOutField11 = @nQTY  
      SET @cOutField12 = CAST( @nCurRec AS NVARCHAR( 2)) + '/' + CAST( @nRecCount AS NVARCHAR( 2))  
      SET @cOutField13 = ''  
  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1        
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      --prepare next screen variable  
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = @cExternReceiptKey  
      SET @cOutField03 = ''  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1        
  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_3_Fail:  
   BEGIN  
     SET @cOutField01 = @cExtPalletID  
      SET @cOutField02 = @cSSCC  
      SET @cOutField03 = ''  
   END  
END  
GOTO QUIT  
  
  
/********************************************************************************  
Step 4. Scn = 4523.   
   Pallet Info (Field01)  
     
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
    SET @cOption = ISNULL(RTRIM(@cInField13),'')  
  
      IF @cOption = ''  
      BEGIN  
         SELECT TOP 1           
            @cSKU = SKU,          
            @cLottable01 = Lottable01,           
            @cLottable02 = Lottable02,    
            @dLottable04 = Lottable04,           
            @dLottable05 = Lottable05,           
            @cLottable09 = Lottable09,           
            @cLottable11 = Lottable11,           
            @dLottable13 = Lottable13,           
            @cUOM        = UOM,          
            @nQTY        = CASE WHEN ISNULL( SUM( QTYExpected), 0) > ISNULL( SUM( BeforeReceivedQTY), 0) THEN           
                           ISNULL( SUM( QTYExpected - BeforeReceivedQTY), 0) ELSE 0 END          
         FROM dbo.ReceiptDetail WITH (NOLOCK)          
         WHERE ReceiptKey = @cReceiptKey          
         AND   StorerKey = @cStorerKey          
         AND   Lottable11 = @cExtPalletID          
         AND   FinalizeFlag <> 'Y'          
         AND   LTRIM(SKU + Lottable01 + Lottable02 + CONVERT( NVARCHAR( 10), Lottable05, 112) + Lottable09 + CONVERT( NVARCHAR( 10), Lottable13, 112)) >            
               LTRIM(@cSKU + @cLottable01 + @cLottable02 + CONVERT( NVARCHAR( 10), @dLottable05, 112) + Lottable09 + CONVERT( NVARCHAR( 10), @dLottable13, 112))          
         GROUP BY SKU, Lottable01, Lottable02, Lottable04,Lottable05,           
                  Lottable09, Lottable11, Lottable13, UOM          
         ORDER BY SKU    
  
         IF @@ROWCOUNT = 0  
         BEGIN  
            SET @nErrNo = 97415  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more rec  
            GOTO Quit  
         END  
  
         SELECT   
            @cSKUDesc = DESCR,  
            @cLottable01Label = CASE WHEN ISNULL( LOTTABLE01LABEL, '') = '' THEN 'L01' ELSE LOTTABLE01LABEL END,  
            @cLottable02Label = CASE WHEN ISNULL( LOTTABLE02LABEL, '') = '' THEN 'L02' ELSE LOTTABLE02LABEL END,  
            @cLottable04Label = CASE WHEN ISNULL( LOTTABLE04LABEL, '') = '' THEN 'L04' ELSE LOTTABLE04LABEL END,              
            @cLottable05Label = CASE WHEN ISNULL( LOTTABLE05LABEL, '') = '' THEN 'L05' ELSE LOTTABLE05LABEL END,  
            @cLottable09Label = CASE WHEN ISNULL( LOTTABLE09LABEL, '') = '' THEN 'L09' ELSE LOTTABLE09LABEL END,  
            @cLottable11Label = CASE WHEN ISNULL( LOTTABLE11LABEL, '') = '' THEN 'L11' ELSE LOTTABLE11LABEL END,  
            @cLottable13Label = CASE WHEN ISNULL( LOTTABLE13LABEL, '') = '' THEN 'L13' ELSE LOTTABLE13LABEL END  
         FROM dbo.SKU WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   SKU = @cSKU  
  
         --SELECT @cUOM = PackUOM3  
         --FROM dbo.SKU WITH (NOLOCK)  
         --JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
         --WHERE StorerKey = @cStorerKey  
         --AND   SKU = @cSKU  
  
         SET @nCurRec = @nCurRec + 1  
  
         SET @cOutField01 = @cSKU  
         SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)  
         SET @cOutField04 = 'L01:' + @cLottable01  
         SET @cOutField05 = 'L02:' + @cLottable02    
         SET @cOutField06 = CASE WHEN @cLot5toLot4 = '1' THEN 'L04:' + rdt.rdtFormatDate( @dLottable04) ELSE'L05:' + rdt.rdtFormatDate( @dLottable05) END         
         SET @cOutField06 = 'L05:' + rdt.rdtFormatDate( @dLottable05)  
         SET @cOutField07 = 'L09:' + @cLottable09  
         SET @cOutField08 = 'L11:' +  @cLottable11  
         SET @cOutField09 = 'L13:' + rdt.rdtFormatDate( @dLottable13)  
    SET @cOutField10 = @cUOM  
         SET @cOutField11 = @nQTY  
         SET @cOutField12 = CAST( @nCurRec AS NVARCHAR( 2)) + '/' + CAST( @nRecCount AS NVARCHAR( 2))  
  
         GOTO Quit  
      END  
  
      IF @cOption <> '1'  
      BEGIN  
         SET @nErrNo = 97416  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid opt  
         GOTO Step_4_Fail  
      END  
  
      SET @cLottable01 = SUBSTRING( @cOutField04, 5, 15)  
      SET @cLottable02 = SUBSTRING( @cOutField05, 5, 15) 
      SET @cLottable09 = SUBSTRING( @cOutField07, 5, 15)  
      SET @cLottable11 = SUBSTRING( @cOutField08, 5, 15)  
     
      SET @cOutField01 = ''  
  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
 END  -- Inputkey = 1  
  
 IF @nInputKey = 0   
   BEGIN  
      SELECT TOP 1   
         @cItemClass = SKU.ItemClass,  
         @cSSCC = RD.Lottable09     
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)   
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)   
      WHERE RD.ReceiptKey = @cReceiptKey  
      AND   RD.StorerKey = @cStorerKey  
      AND   RD.Lottable11 = @cExtPalletID  
  
      IF @cSKUType = 'FG'  
      BEGIN  
         -- Prepare screen variable  
         SET @cOutField01 = @cExtPalletID  
         SET @cOutField02 = @cSSCC  
         SET @cOutField03 = ''  
     
     -- GOTO Prev Screen  
     SET @nScn = @nScn - 1  
       SET @nStep = @nStep - 1  
      END  
      ELSE  
      BEGIN  
         SET @cOutField01 = @cReceiptKey  
         SET @cOutField02 = @cExternReceiptKey  
         SET @cOutField03 = ''  
  
     -- GOTO Prev Screen  
     SET @nScn = @nScn - 2  
       SET @nStep = @nStep - 2  
      END  
   END  
 GOTO Quit  
  
   STEP_4_FAIL:  
   BEGIN  
      SET @cOutField01 = ''  
        
      EXEC rdt.rdtSetFocusField @nMobile, 1  
        
   END  
     
  
END   
GOTO QUIT  
  
/********************************************************************************  
Step 5. Scn = 4524  
   LF Pallet ID (Field01, Input)  
     
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
    SET @cToID  = ISNULL(RTRIM(@cInField01),'')  
    
      -- Validate blank  
      IF @cToID = ''  
      BEGIN  
         SET @nErrNo = 97417  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet id req  
         GOTO Step_5_Fail  
      END  
  
      -- Check barcode format  
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cToID) = 0  
      BEGIN  
         SET @nErrNo = 97418  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv pallet id  
         GOTO Step_5_Fail  
      END  
              
      SELECT TOP 1 @cID = ToID   
      FROM dbo.ReceiptDetail WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey  
      AND   ReceiptKey = @cReceiptKey  
      AND   Lottable11 = @cExtPalletID  
      AND   BeforeReceivedQTY > 0  
  
      -- 1 Ext pallet id only can receive to 1 LF pallet id  
      -- If this Ext pallet id received something before  
      IF ISNULL( @cID, '') <> '' AND @cToID <> @cID  
      BEGIN  
         SET @nErrNo = 97419  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Rcv to diff id  
         GOTO Step_5_Fail  
      END  
  
       -- Extended validate          
      IF @cExtendedValidateSP <> ''          
      BEGIN          
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')          
         BEGIN          
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +          
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID,@cReceiptKey, @cExtPalletID,@cExternReceiptKey,@cSKU,' +          
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '          
            SET @cSQLParam =          
               '@nMobile       INT,           ' +          
               '@nFunc         INT,           ' +          
               '@cLangCode     NVARCHAR( 3),  ' +          
               '@nStep         INT,           ' +          
               '@nInputKey     INT,           ' +          
               '@cStorerKey    NVARCHAR( 15), ' +          
               '@cToID         NVARCHAR( 18), ' +          
               '@cReceiptKey   NVARCHAR( 20), ' +          
               '@cExtPalletID  NVARCHAR( 20), ' +        
               '@cExternReceiptKey NVARCHAR(20),' +         
               '@cSKU          NVARCHAR(20),     '+         
               '@nErrNo        INT           OUTPUT, ' +          
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '          
          
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,          
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID, @cReceiptKey, @cExtPalletID,@cExternReceiptKey,@cSKU,        
               @nErrNo OUTPUT, @cErrMsg OUTPUT          
          
            IF @nErrNo <> 0          
            BEGIN          
               EXEC rdt.rdtSetFocusField @nMobile, 3          
               GOTO Step_5_Fail          
            END          
         END          
      END    
        
      SET @nErrNo = 0  
  
      SET @nStartTCnt = @@TRANCOUNT    
      BEGIN TRAN    
      SAVE TRAN Receipt_Confirm    
  
      IF @cSKUType = 'POSM'  
      BEGIN  
         DECLARE CUR_RECEIPT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
         SELECT ReceiptLineNumber  
         FROM dbo.ReceiptDetail WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND   ReceiptKey = @cReceiptKey  
         AND   FinalizeFlag <> 'Y'  
         AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') = '' THEN Lottable01 ELSE @cLottable01 END  
         AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') = '' THEN Lottable02 ELSE @cLottable02 END  
         AND   ISNULL( Lottable05, 0) = ISNULL( @dLottable05, 0)  
         AND   Lottable09 = CASE WHEN ISNULL(@cLottable09, '') = '' THEN Lottable09 ELSE @cLottable09 END  
         AND   Lottable11 = @cExtPalletID  
         AND   ISNULL( Lottable13, 0) = ISNULL( @dLottable13, 0)  
      END  
      ELSE  -- FG SKU  
      BEGIN  
         IF ISNULL( @cLottable09, '') <> 'X'  
         BEGIN  
            DECLARE CUR_RECEIPT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
            SELECT ReceiptLineNumber  
            FROM dbo.ReceiptDetail WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND   ReceiptKey = @cReceiptKey  
            AND   FinalizeFlag <> 'Y'  
            AND   Lottable09 = @cSSCC  
            AND   Lottable11 = @cExtPalletID  
         END  
         ELSE  
         BEGIN  
            DECLARE CUR_RECEIPT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
            SELECT ReceiptLineNumber  
            FROM dbo.ReceiptDetail WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND   ReceiptKey = @cReceiptKey  
            AND   FinalizeFlag <> 'Y'  
            AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') = '' THEN Lottable01 ELSE @cLottable01 END  
            AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') = '' THEN Lottable02 ELSE @cLottable02 END  
            AND   ISNULL( Lottable05, 0) = ISNULL( @dLottable05, 0)  
            AND   Lottable11 = @cExtPalletID  
            AND   ISNULL( Lottable13, 0) = ISNULL( @dLottable13, 0)  
         END  
      END  
      OPEN CUR_RECEIPT  
      FETCH NEXT FROM CUR_RECEIPT INTO @cReceiptLineNumber  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
      /*  
         IF @cUserName = 'james1'  
            UPDATE ReceiptDetail WITH (ROWLOCK) SET   
               Lottable09 = CASE WHEN ISNULL( @cLottable09, '') = 'X' THEN @cLottable09 ELSE Lottable09 END  
              ,ToID = @cToID  
              ,BeforeReceivedQty = QtyExpected  
              --,QtyReceived = QtyExpected  
              --,FinalizeFlag = 'Y'  
            WHERE ReceiptKey = @cReceiptKey  
            AND   ReceiptLineNumber = @cReceiptLineNumber  
         ELSE  
      */  
            IF @cNotAutoFinalizeByLine = '1'  
            BEGIN  
                  UPDATE ReceiptDetail WITH (ROWLOCK) SET   
                     Lottable09 = CASE WHEN ISNULL( @cLottable09, '') = 'X' THEN @cLottable09 ELSE Lottable09 END  
                     ,ToID = @cToID  
                     ,BeforeReceivedQty = QtyExpected  
                     --,QtyReceived = QtyExpected 
                     --,FinalizeFlag = 'Y'  
                  WHERE ReceiptKey = @cReceiptKey  
                  AND ReceiptLineNumber = @cReceiptLineNumber  
              
            END  
            ELSE  
            BEGIN  
                  UPDATE ReceiptDetail WITH (ROWLOCK) SET   
                     Lottable09 = CASE WHEN ISNULL( @cLottable09, '') = 'X' THEN @cLottable09 ELSE Lottable09 END  
                     ,ToID = @cToID  
                     ,BeforeReceivedQty = QtyExpected  
                     ,QtyReceived = QtyExpected  
                     ,FinalizeFlag = 'Y'  
                  WHERE ReceiptKey = @cReceiptKey  
                  AND ReceiptLineNumber = @cReceiptLineNumber  
              
            END  
  
         IF @@ERROR <> 0  
         BEGIN  
            ROLLBACK TRAN Receipt_Confirm  
            SET @nErrNo = 97420  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Finalize error  
            BREAK  
         END  
  
         FETCH NEXT FROM CUR_RECEIPT INTO @cReceiptLineNumber  
      END  
      CLOSE CUR_RECEIPT  
      DEALLOCATE CUR_RECEIPT  
  
      WHILE @@TRANCOUNT > @nStartTCnt -- Commit until the level we started    
         COMMIT TRAN Receipt_Confirm    
  
      IF @nErrNo = 0  
      BEGIN  
         EXEC RDT.rdt_STD_EventLog  
            @cActionType   = '2', -- Receiving  
            @cUserID       = @cUserName,  
            @nMobileNo     = @nMobile,  
            @nFunctionID   = @nFunc,  
            @cFacility     = @cFacility,  
            @cStorerKey    = @cStorerKey,  
            @cLocation     = @cLOC,  
            @cToID         = @cToID,  
            @cSKU          = @cSku,  
            @cComponentSKU = @cSku,  
            @cUOM          = @cUOM,  
            @nQTY          = 0,  
            @cLottable09   = @cLottable09,  
            @cLottable11   = @cExtPalletID,  
            @cReceiptKey   = @cReceiptKey,  
            @nStep         = @nStep  
  
         SET @nScn = @nScn + 1  
         SET @nStep = @nStep + 1  
      END  
      ELSE  
         GOTO Step_5_Fail  
  
 END  -- Inputkey = 1  
  
 IF @nInputKey = 0   
   BEGIN  
      -- Prepare Screen 4 Variable  
      SET @cOutField01 = @cSKU  
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)  
      SET @cOutField04 = 'L01:' + @cLottable01  
      SET @cOutField05 = 'L02:' + @cLottable02  
      SET @cOutField06 = CASE WHEN @cLot5toLot4 = '1' THEN 'L04:' + rdt.rdtFormatDate( @dLottable04) ELSE'L05:' + rdt.rdtFormatDate( @dLottable05) END         
      SET @cOutField07 = 'L09:' + @cLottable09  
      SET @cOutField08 = 'L11:' +  @cLottable11  
      SET @cOutField09 = 'L13:' + rdt.rdtFormatDate( @dLottable13)  
      SET @cOutField10 = @cUOM  
      SET @cOutField11 = @nQTY  
      SET @cOutField12 = CAST( @nCurRec AS NVARCHAR( 2)) + '/' + CAST( @nRecCount AS NVARCHAR( 2))  
  SET @cOutField13 = ''  
     
  -- GOTO Screen 4  
  SET @nScn = @nScn - 1  
    SET @nStep = @nStep - 1  
   END  
 GOTO Quit  
  
   STEP_5_FAIL:  
   BEGIN  
      SET @cOutField01 = ''  
        
      SET @cID = ''        
   END  
END   
GOTO QUIT  
  
/********************************************************************************  
Step 6. screen = 4525  
   Message  
     
********************************************************************************/  
Step_6:  
BEGIN  
   IF @nInputKey IN (0, 1) -- ESC/ENTER  
   BEGIN  
      -- initialise all variable  
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = @cExternReceiptKey  
   
      -- Init screen  
      SET @cOutField03 = ''  
  
      SET @nScn = @nScn - 4  
      SET @nStep = @nStep - 4  
   END  
  
 GOTO Quit  
END  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET  
      EditDate      = GETDATE(),   
      ErrMsg        = @cErrMsg,  
      Func          = @nFunc,  
      Step          = @nStep,  
      Scn           = @nScn,  
  
      StorerKey     = @cStorerKey,  
      Facility      = @cFacility,  
      Printer       = @cPrinter,  
      -- UserName      = @cUserName,  
  
      V_ReceiptKey = @cReceiptKey,  
      V_SKU        = @cSKU,  
      V_SKUDescr   = @cSKUDesc,  
      V_UOM        = @cUOM,  
      V_Qty        = @nQTY,  
  
      V_Lottable01 = @cLottable01,  
      V_Lottable02 = @cLottable02,  
      V_Lottable03 = @cLottable03,  
      V_Lottable04 = @dLottable04,  
      V_Lottable05 = @dLottable05,  
      V_Lottable06 = @cLottable06,  
      V_Lottable07 = @cLottable07,  
      V_Lottable08 = @cLottable08,  
      V_Lottable09 = @cLottable09,  
      V_Lottable10 = @cLottable10,  
      V_Lottable11 = @cLottable11,  
      V_Lottable12 = @cLottable12,  
      V_Lottable13 = @dLottable13,  
      V_Lottable14 = @dLottable14,  
      V_Lottable15 = @dLottable15,  
        
      V_Integer1 = @nRecCount,  
      V_Integer2 = @nCurRec,  
  
      V_String1 = @cExternReceiptKey,  
      V_String2 = @cExtPalletID,  
      V_String3 = @cSKUType,  
      --V_String4 = @nRecCount,  
      V_String5 = @cSSCC,  
      --V_String6 = @nCurRec,  
      V_String6 = @cExtendedValidateSP,      
      V_String7 = @cLot5toLot4,          
      V_String8 = @cNotAutoFinalizeByLine,      
  
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
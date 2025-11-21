SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdtfnc_CPVAdjustment                                */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Purpose: Cooper vision unbundle, using adjustment                    */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 14-Sep-2018 1.0  Ung        WMS-6149 Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_CPVAdjustment] (  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT  
)  
AS  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc var  
DECLARE  
   @bSuccess    INT,  
   @cOption     NVARCHAR(1),   
   @cMasterLOT  NVARCHAR(60),   
   @dToday      DATETIME,   
   @dExpiryDate DATETIME,   
   @cBarcode    NVARCHAR( 60),   
   @nRowCount   INT  
  
-- RDT.RDTMobRec variable  
DECLARE  
   @nFunc       INT,  
   @nScn        INT,  
   @nStep       INT,  
   @cLangCode   NVARCHAR( 3),  
   @cUserName   NVARCHAR( 10),  
   @nInputKey   INT,  
   @nMenu       INT,  
  
   @cStorerKey  NVARCHAR( 15),  
   @cFacility   NVARCHAR( 5),  
  
   @dExternLottable04 DATETIME,  
   @cLottable07       NVARCHAR( 30),  
   @cLottable08       NVARCHAR( 30),  
  
   @cADJKey           NVARCHAR( 10),  
   @cParentSKU        NVARCHAR( 20),  
   @cChildSKU         NVARCHAR( 20),  
   @cScan             NVARCHAR( 5),  
   @cTotal            NVARCHAR( 5),  
     
   @cDefaultQTY       NVARCHAR( 1),  
  
   @cParentDesc       NVARCHAR( 60),  
   @cChildDesc        NVARCHAR( 60),  
  
   @nParentQTY        INT,  
   @nParentShelfLife  INT,  
   @nParentCaseCNT    INT,  
   @nChildCaseCNT     INT,  
   @nFromStep         INT,  
  
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),  
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),  
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),  
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),  
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),  
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),  
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),  
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),  
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),  
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),  
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),  
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),  
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),  
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),  
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)  
  
-- Load RDT.RDTMobRec  
SELECT  
   @nFunc       = Func,  
   @nScn        = Scn,  
   @nStep       = Step,  
   @nInputKey   = InputKey,  
   @nMenu       = Menu,  
   @cLangCode   = Lang_code,  
   @cUserName   = UserName,  
  
   @cStorerKey  = StorerKey,  
   @cFacility   = Facility,  
  
   @dExternLottable04 = V_Lottable04,  
   @cLottable07       = V_Lottable07,  
   @cLottable08       = V_Lottable08,  
  
   @cADJKey           = V_String1,  
   @cParentSKU        = V_String2,  
   @cChildSKU         = V_String3,  
   @cScan             = V_String4,  
   @cTotal            = V_String5,  
     
   @cDefaultQTY       = V_String21,  
  
   @cParentDesc       = V_String41,  
   @cChildDesc        = V_String42,  
  
   @nParentQTY        = V_Integer1,  
   @nParentShelfLife  = V_Integer2,  
   @nParentCaseCNT    = V_Integer3,  
   @nChildCaseCNT     = V_Integer4,  
   @nFromStep         = V_Integer5,  
  
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
  
FROM rdt.RDTMOBREC (NOLOCK)  
WHERE Mobile = @nMobile  
  
IF @nFunc = 619 -- CPV adjustment  
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0 GOTO Step_0   -- Func = 619  
   IF @nStep = 1 GOTO Step_1   -- 5230 ADJKey  
   IF @nStep = 2 GOTO Step_2   -- 5232 Parent LOT  
   IF @nStep = 3 GOTO Step_3   -- 5233 Child LOT  
   IF @nStep = 4 GOTO Step_4   -- 5234 Abort scan?  
   IF @nStep = 5 GOTO Step_5   -- 5235 Close ADJ?  
   IF @nStep = 6 GOTO Step_6   -- 5236 Multi SKU selection  
END  
  
RETURN -- Do nothing if incorrect step  
  
  
/********************************************************************************  
Step 0. func = 619. Menu  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Get storer config  
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)  
   IF @cDefaultQTY = '0'  
      SET @cDefaultQTY = ''  
  
   -- Set the entry point  
   SET @nScn = 5230  
   SET @nStep = 1  
  
   -- Prepare next screen var  
   SET @cOutField01 = '' -- @cADJKey  
  
   -- EventLog - Sign In Function  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType = '1', -- Sign in function  
      @cUserID     = @cUserName,  
      @nMobileNo   = @nMobile,  
      @nFunctionID = @nFunc,  
      @cFacility   = @cFacility,  
      @cStorerKey  = @cStorerkey  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Screen = 5230. ADJ KEY  
   ADJ KEY  (Field01, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cADJKey = @cInField01  
  
      IF @cADJKey = ''  
      BEGIN  
         SET @nErrNo = 129301  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ADJ Key  
         GOTO Quit  
      END  
  
      -- Get Adjustment info  
      DECLARE @cChkFacility   NVARCHAR(5)  
      DECLARE @cChkStorerKey  NVARCHAR(15)  
      DECLARE @cADJType       NVARCHAR(3)  
      DECLARE @cFinalizeFlag  NVARCHAR(1)  
      SELECT  
         @cChkFacility = Facility,  
         @cChkStorerKey = StorerKey,  
         @cADJType = AdjustmentType,  
         @cFinalizeFlag = FinalizedFlag  
      FROM Adjustment WITH (NOLOCK)  
      WHERE AdjustmentKey = @cADJKey  
  
      -- Check Adjustment valid  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 129302  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ADJ  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      -- Check diff storer  
      IF @cChkStorerKey <> @cStorerKey  
      BEGIN  
         SET @nErrNo = 129303  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      -- Check diff facility  
      IF @cChkFacility <> @cFacility  
      BEGIN  
         SET @nErrNo = 129304  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      -- Check status  
      IF @cFinalizeFlag = 'Y'  
      BEGIN  
         SET @nErrNo = 129305  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ADJ finalized  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Adjustment  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      -- Check ADJ type  
      IF @cADJType <> 'MPB'  
      BEGIN  
         SET @nErrNo = 129306  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidADJType  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      -- Get parent SKU  
--      SET @cParentSKU = ''  
--      SELECT TOP 1   
--         @cParentSKU = SKU  
--      FROM dbo.AdjustmentDetail OD WITH (NOLOCK)  
--      WHERE AdjustmentKey = @cADJKey  
--      ORDER BY AdjustmentLineNumber  
--  
--      IF @cParentSKU = ''  
--      BEGIN  
--         SET @nErrNo = 129307  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No parent SKU  
--         GOTO Quit  
--      END  
  
      -- Prep next screen var  
      SET @cOutField01 = @cADJKey  
      SET @cOutField02 = '' -- @cParentSKU  
      SET @cOutField03 = '' -- SUBSTRING( @cParentDesc, 1, 20)  
      SET @cOutField04 = '' -- SUBSTRING( @cParentDesc, 21, 20)  
      SET @cOutField05 = '' -- SUBSTRING( @cParentDesc, 41, 20)  
      SET @cOutField06 = '' -- LOT  
      SET @cOutField07 = '' -- ParentQTY  
      
      
  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
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
       @cStorerKey  = @cStorerkey  
  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- Clean up for menu option  
   END  
   GOTO Quit  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 2. Screen = 5232. Parent LOT  
   ADJ KEY     (Field01)  
   Parent SKU  (Field02)  
   DESC1       (Field03)  
   DESC2       (Field04)  
   DESC3       (Field05)  
   Parent LOT  (Field06, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cBarcode = @cInField06  
  
      -- Check blank  
      IF @cBarcode = ''  
      BEGIN  
         SET @nErrNo = 129310  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ParentLOT  
         SET @cOutField06 = ''  
         GOTO Quit  
      END  
  
      -- In future MasterLOT could > 30 chars, need to use 2 lottables field  
      SET @cLottable07 = ''  
      SET @cLottable08 = ''  
  
      -- Decode to abstract master LOT  
      EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,  
         @cLottable07 = @cLottable07 OUTPUT,  
         @cLottable08 = @cLottable08 OUTPUT,  
         @nErrNo  = @nErrNo  OUTPUT,  
         @cErrMsg = @cErrMsg OUTPUT  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      -- Check barcode format  
      IF @cLottable07 = '' AND @cLottable08 = ''  
      BEGIN  
         SET @nErrNo = 129311  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format  
         SET @cOutField06 = ''  
         GOTO Quit  
      END  
  
      SELECT @cMasterLOT = @cLottable07 + @cLottable08  
  
      -- Get master LOT info  
      DECLARE @cExternLotStatus NVARCHAR(10)  
      SELECT  
         @cParentSKU = SKU,   
         @cExternLotStatus = ExternLotStatus,  
         @dExternLottable04 = ExternLottable04  
      FROM ExternLotAttribute WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         -- AND SKU = @cParentSKU  
         AND ExternLOT = @cMasterLOT  
  
      SET @nRowCount = @@ROWCOUNT   
  
      -- Check master LOT valid  
      IF @nRowCount = 0  
      BEGIN  
         SET @nErrNo = 129312  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOT  
         SET @cOutField06 = ''  
         GOTO Quit  
      END  
  
      -- Check multi SKU LOT  
      IF @nRowCount > 1  
      BEGIN  
--         SET @cChkSKU = ''  
         EXEC rdt.rdt_CPVMultiSKUExtLOT @nMobile, @nFunc, @cLangCode,  
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
            @cMasterLOT,   
            @cStorerKey,  
            @cParentSKU OUTPUT,  
            @nErrNo     OUTPUT,  
            @cErrMsg    OUTPUT  
  
         IF @nErrNo = 0 -- Populate multi SKU screen  
         BEGIN  
            -- Go to Multi SKU screen  
            SET @nScn = @nScn + 4  
            SET @nStep = @nStep + 4  
            GOTO Quit  
         END  
          
      END  
      
      
        
      -- Check parent SKU  
      IF NOT EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND BUSR5 = 'RX' AND BUSR6 IS NOT NULL)  
      BEGIN  
         SET @nErrNo = 129325  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not parent SKU  
         SET @cOutField06 = ''  
         GOTO Quit  
      END  
  
      -- Get parent SKU info  
      SELECT  
         @cParentDesc = Descr,   
         @nParentShelfLife = SUSR2,   
         @cChildSKU = BUSR6,   
         @nParentCaseCNT = CAST( Pack.CaseCNT AS INT)  
      FROM dbo.SKU WITH (NOLOCK)  
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
      WHERE StorerKey = @cStorerKey  
         AND SKU = @cParentSKU  
  
      -- Get child SKU info  
      SELECT  
         @cChildDesc = Descr,  
         @nChildCaseCNT = CAST( Pack.CaseCNT AS INT)  
      FROM dbo.SKU WITH (NOLOCK)  
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
      WHERE StorerKey = @cStorerKey  
         AND SKU = @cChildSKU  
        
      -- Check child SKU  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 129308  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No child SKU  
         SET @cOutField06 = ''  
         GOTO Quit  
      END  
  
      -- Check child packing  
      IF @nParentCaseCNT = 0  
      BEGIN  
         SET @nErrNo = 129309  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoChildCaseCNT  
         SET @cOutField06 = ''  
         GOTO Quit  
      END  
  
      SET @nParentQTY = 0  
  
      -- Check master LOT status  
      IF @cExternLotStatus <> 'ACTIVE'  
      BEGIN  
         SET @nErrNo = 129313  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive LOT  
         SET @cOutField06 = ''  
         GOTO Quit  
      END  
  
      -- Calc expiry date  
      SET @dToday = CONVERT( DATE, GETDATE()) -- Today  
      SET @dExpiryDate = @dExternLottable04  
      IF @nParentShelfLife > 0  
         SET @dExpiryDate = DATEADD( dd, -@nParentShelfLife, @dExternLottable04)  
  
      -- Check expired stock  
      IF @dExpiryDate < @dToday  
      BEGIN  
         SET @nErrNo = 129314  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stock expired  
         SET @cOutField06 = ''  
         GOTO Quit  
      END  
  
      -- Confirm  
      EXEC rdt.rdt_CPVAdjustment_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'PARENT',   
         @cADJKey     = @cADJKey,  
         @cParentSKU  = @cParentSKU,  
         @cLottable07 = @cLottable07,  
         @cLottable08 = @cLottable08,  
         @nParentQTY  = @nParentQTY OUTPUT,  
         @nErrNo      = @nErrNo     OUTPUT,  
         @cErrMsg     = @cErrMsg    OUTPUT  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      SET @cTotal = (@nParentQTY * @nParentCaseCNT) / @nChildCaseCNT  
      SET @cScan = '0'  
        
      -- Prepare next screen var  
      SET @cOutField01 = @cChildSKU  
      SET @cOutField02 = SUBSTRING( @cChildDesc, 1, 20)  
      SET @cOutField03 = SUBSTRING( @cChildDesc, 21, 20)  
      SET @cOutField04 = SUBSTRING( @cChildDesc, 41, 20)  
      SET @cOutField05 = '' -- LOT  
      SET @cOutField06 = @cDefaultQTY  
      SET @cOutField07 = @cScan + '/' + @cTotal  
      
      EXEC rdt.rdtSetFocusField @nMobile, 5 -- ChildLot      
  
      -- Go to child LOT screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Aboart scan  
      IF @nParentQTY > 0 AND CAST( @cScan AS INT) > 0 AND @cScan <> @cTotal  
      BEGIN  
         SET @nFromStep = @nStep  
  
         -- Prepare next screen var  
         SET @cOutField01 = '' -- OPTION  
  
         -- Go to abort scan screen  
         SET @nScn = @nScn + 2  
         SET @nStep = @nStep + 2  
      END  
        
      -- Close adjustment  
      ELSE IF EXISTS( SELECT TOP 1 1 FROM AdjustmentDetail (NOLOCK) WHERE AdjustmentKey = @cADJKey AND QTY < 0)  
      BEGIN  
         -- Prepare next screen var  
         SET @cOutField01 = '' -- Option  
  
         SET @nScn = @nScn + 3  
         SET @nStep = @nStep + 3  
      END  
        
      -- Adjustment screen  
      ELSE  
      BEGIN  
         -- Prepare next screen var  
         SET @cOutField01 = '' -- @cADJKey  
  
         -- Go back adj screen  
         SET @nScn  = @nScn - 1  
         SET @nStep = @nStep - 1  
      END  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 3. Screen = 5233. Child LOT  
   Child SKU   (Field01)  
   DESC1       (Field02)  
   DESC2       (Field03)  
   DESC3       (Field04)  
   Child LOT   (Field05, input)  
   QTY         (Field06, input)  
   SCAN/TOTAL  (Field07)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      DECLARE @cQTY NVARCHAR( 5)  
  
      -- Screen mapping  
      SET @cBarcode = @cInField05  
      SET @cQTY = @cInField06  
  
      -- Check blank  
      IF @cBarcode = ''  
      BEGIN  
         SET @nErrNo = 129315  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ChildLOT  
         SET @cOutField05 = ''  
         GOTO Quit  
      END  
  
      -- In future MasterLOT could > 30 chars, need to use 2 lottables field  
      SET @cLottable07 = ''  
      SET @cLottable08 = ''  
  
      -- Decode to abstract master LOT  
      EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,  
         @cLottable07 = @cLottable07 OUTPUT,  
         @cLottable08 = @cLottable08 OUTPUT,  
         @nErrNo  = @nErrNo  OUTPUT,  
         @cErrMsg = @cErrMsg OUTPUT  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      -- Check barcode format  
      IF @cLottable07 = '' AND @cLottable08 = ''  
      BEGIN  
         SET @nErrNo = 129316  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format  
         SET @cOutField05 = ''  
         GOTO Quit  
      END  

-- (ChewKPXX)  
--      DECLARE @cChildLOT    NVARCHAR(60)   
--      DECLARE @cChkChildSKU NVARCHAR(20)   
--      SET @cChildLOT = @cLottable07 + @cLottable08   
--        
--      SELECT @cChkChildSKU = SKU  
--      FROM ExternLotAttribute WITH (NOLOCK)  
--      WHERE StorerKey = @cStorerKey  
--         AND ExternLOT = @cChildLOT  
--  
--      SET @nRowCount = @@ROWCOUNT  
--        
--      -- Child extern lot exist  
--      IF @nRowCount > 0   
--      BEGIN  
--         -- Unique child found  
--         IF @nRowCount = 1  
--         BEGIN  
--            -- Check child SKU matches  
--            IF @cChkChildSKU <> @cChildSKU  
--            BEGIN  
--               SET @nErrNo = 129326  
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff child SKU  
--               SET @cOutField05 = ''  
--               GOTO Quit  
--            END  
--         END  
--         ELSE  
--         BEGIN  
--            -- Check child SKU is in the extern lot (multiple child)  
--            IF NOT EXISTS( SELECT TOP 1 1   
--               FROM ExternLotAttribute WITH (NOLOCK)  
--               WHERE StorerKey = @cStorerKey  
--                  AND SKU = @cChildSKU  
--                  AND ExternLOT = @cChildLOT)  
--            BEGIN  
--               SET @nErrNo = 129327  
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff child SKU  
--               SET @cOutField05 = ''  
--               GOTO Quit  
--            END  
--         END           
--      END  
      SET @cOutField05 = @cBarcode  
  
      -- Check QTY blank  
      IF @cQTY = ''  
      BEGIN  
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY  
         GOTO Quit  
      END  
        
      -- Check QTY valid  
      IF rdt.rdtIsValidQty( @cQTY, 1) = 0  
      BEGIN  
         SET @nErrNo = 129317  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY  
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY  
         GOTO Quit  
      END  
  
      -- Check over scan  
      IF CAST( @cQTY AS INT) + CAST( @cScan AS INT) > CAST( @cTotal AS INT)  
      BEGIN  
         SET @nErrNo = 129318  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pick  
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY  
         GOTO Quit  
      END  
        
      SELECT @cMasterLOT = @cLottable07 + @cLottable08  
  
      -- Handling transaction  
      DECLARE @nTranCount INT  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN rdtfnc_CPVAdjustment -- For rollback or commit only our own transaction  
  
      -- Confirm  
      EXEC rdt.rdt_CPVAdjustment_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'CHILD',   
         @cADJKey     = @cADJKey,  
         @cChildSKU   = @cChildSKU,  
         @nChildQTY   = @cQTY,   
         @cLottable07 = @cLottable07,  
         @cLottable08 = @cLottable08,  
         @cScan       = @cScan   OUTPUT,  
         @nErrNo      = @nErrNo  OUTPUT,  
         @cErrMsg     = @cErrMsg OUTPUT  
      IF @nErrNo <> 0  
      BEGIN  
         ROLLBACK TRAN rdtfnc_Confirm -- Only rollback change made here  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  
         GOTO Quit  
      END  
        
      -- Posting  
      IF @cScan = @cTotal  
      BEGIN  
         EXEC rdt.rdt_CPVAdjustment_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'POSTING',   
            @cADJKey        = @cADJKey,  
            @cParentSKU     = @cParentSKU,   
            @nParentCaseCNT = @nParentCaseCNT,   
            @nChildCaseCnt  = @nChildCaseCnt,   
            @nErrNo         = @nErrNo  OUTPUT,  
            @cErrMsg        = @cErrMsg OUTPUT  
         IF @nErrNo <> 0  
         BEGIN  
            ROLLBACK TRAN rdtfnc_Confirm -- Only rollback change made here  
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
               COMMIT TRAN  
            GOTO Quit  
         END  
      END  
  
      COMMIT TRAN rdtfnc_Confirm  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  
  
      IF @cScan = @cTotal  
      BEGIN  
         -- Prep next screen var  
         SET @cOutField01 = @cADJKey  
         SET @cOutField02 = @cParentSKU  
         SET @cOutField03 = SUBSTRING( @cParentDesc, 1, 20)  
         SET @cOutField04 = SUBSTRING( @cParentDesc, 21, 20)  
         SET @cOutField05 = SUBSTRING( @cParentDesc, 41, 20)  
         SET @cOutField06 = '' -- LOT  
         SET @cOutField07 = '' -- ParentQTY  
  
         -- Go back parent LOT screen  
         SET @nScn  = @nScn - 1  
         SET @nStep = @nStep - 1  
      END  
      ELSE  
      BEGIN  
         -- Prepare next screen var  
         SET @cOutField05 = '' -- Child LOT  
         SET @cOutField06 = '' -- QTY  
         SET @cOutField07 = @cScan + '/' + @cTotal  
           
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- Child LOT  
      END  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      IF CAST( @cScan AS INT) > 0 AND @cScan <> @cTotal  
      BEGIN  
         SET @nFromStep = @nStep  
           
         -- Prepare next screen var  
         SET @cOutField01 = '' -- OPTION  
  
         -- Go to abort scan screen  
         SET @nScn = @nScn + 1  
         SET @nStep = @nStep + 1  
      END  
      ELSE  
      BEGIN  
         -- Prepare next screen var  
         SET @cOutField01 = @cADJKey  
         SET @cOutField02 = @cParentSKU  
         SET @cOutField03 = SUBSTRING( @cParentDesc, 1, 20)  
         SET @cOutField04 = SUBSTRING( @cParentDesc, 21, 20)  
         SET @cOutField05 = SUBSTRING( @cParentDesc, 41, 20)  
         SET @cOutField06 = '' -- LOT  
         SET @cOutField07 = CAST( @nParentQTY AS NVARCHAR(10))  
  
         -- Go back parent LOT screen  
         SET @nScn  = @nScn - 1  
         SET @nStep = @nStep - 1  
      END  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 4. Screen = 5234.  
   ABORT SCAN?  
   1 = YES  
   2 = NO  
   OPTION (Field01, input)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      -- Check blank  
      IF @cOption = ''  
      BEGIN  
         SET @nErrNo = 129319  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OPTION  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      -- Check blank  
      IF @cOption NOT IN ('1', '9')  
      BEGIN  
         SET @nErrNo = 129320  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid OPTION  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      IF @cOption = '1' -- YES  
      BEGIN  
          -- Parent LOT  
         IF @nFromStep = 2  
         BEGIN  
            -- Reset  
            EXEC rdt.rdt_CPVAdjustment_Reset @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,   
               'PARENT',   
               @cADJKey,  
               @nErrNo     OUTPUT,  
               @cErrMsg    OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
  
            SET @cTotal = ''  
  
            -- Prepare next screen var  
            SET @cOutField01 = @cADJKey  
  
            -- Go to parent LOT screen  
            SET @nScn  = @nScn - 3  
            SET @nStep = @nStep - 3  
         END  
           
         -- Child LOT  
         ELSE IF @nFromStep = 3  
         BEGIN  
            -- Reset  
            EXEC rdt.rdt_CPVAdjustment_Reset @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,   
               'CHILD',   
               @cADJKey,  
               @nErrNo     OUTPUT,  
               @cErrMsg    OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
                 
            SET @cScan = ''  
              
            -- Prepare next screen var  
            SET @cOutField01 = @cADJKey  
            SET @cOutField02 = @cParentSKU  
            SET @cOutField03 = SUBSTRING( @cParentDesc, 1, 20)  
            SET @cOutField04 = SUBSTRING( @cParentDesc, 21, 20)  
            SET @cOutField05 = SUBSTRING( @cParentDesc, 41, 20)  
            SET @cOutField06 = '' -- LOT  
            SET @cOutField07 = CAST( @nParentQTY AS NVARCHAR(10))  
  
            -- Go to parent LOT screen  
            SET @nScn  = @nScn - 1  
            SET @nStep = @nStep - 1  
         END  
           
         GOTO Quit  
      END  
   END  
  
    -- Parent LOT  
   IF @nFromStep = 2  
   BEGIN  
      -- Prepare next screen var  
      SET @cOutField01 = @cADJKey  
      SET @cOutField02 = @cParentSKU  
      SET @cOutField03 = SUBSTRING( @cParentDesc, 1, 20)  
      SET @cOutField04 = SUBSTRING( @cParentDesc, 21, 20)  
      SET @cOutField05 = SUBSTRING( @cParentDesc, 41, 20)  
      SET @cOutField06 = '' -- LOT  
      SET @cOutField07 = CAST( @nParentQTY AS NVARCHAR(10))  
  
      -- Go to parent LOT screen  
      SET @nScn  = @nScn - 2  
      SET @nStep = @nStep - 2  
   END  
     
   -- Child LOT  
   ELSE IF @nFromStep = 3  
   BEGIN  
      -- Prepare next screen var  
      SET @cOutField01 = @cChildSKU  
      SET @cOutField02 = SUBSTRING( @cChildDesc, 1, 20)  
      SET @cOutField03 = SUBSTRING( @cChildDesc, 21, 20)  
      SET @cOutField04 = SUBSTRING( @cChildDesc, 41, 20)  
      SET @cOutField05 = '' -- LOT  
      SET @cOutField06 = '' -- QTY  
      SET @cOutField07 = @cScan + '/' + @cTotal  
  
      -- Go to child LOT screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 5. Screen = 5235.  
   CLOSE ADJ?  
   1 = YES  
   2 = NO  
   OPTION (Field01, input)  
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      -- Check blank  
      IF @cOption = ''  
      BEGIN  
         SET @nErrNo = 129321  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OPTION  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      -- Check blank  
      IF @cOption NOT IN ('1', '9')  
      BEGIN  
         SET @nErrNo = 129322  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid OPTION  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      IF @cOption = '1' -- YES  
      BEGIN  
         -- Submit for allocation schedule  
         UPDATE Adjustment SET   
            UserDefine10 = 'PENDALLOC',    
            EditWho = SUSER_SNAME(),   
            EditDate = GETDATE()   
         WHERE AdjustmentKey = @cADJKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 125023  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Order Fail  
            GOTO Quit  
         END  
      END  
  
      -- Prepare next screen var  
      SET @cOutField01 = '' -- ADJKey  
  
      -- Go to adjust screen  
      SET @nScn  = @nScn - 4  
      SET @nStep = @nStep - 4  
   END  
   
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare next screen var  
      SET @cOutField01 = @cADJKey  
      SET @cOutField02 = @cParentSKU  
      SET @cOutField03 = SUBSTRING( @cParentDesc, 1, 20)  
      SET @cOutField04 = SUBSTRING( @cParentDesc, 21, 20)  
      SET @cOutField05 = SUBSTRING( @cParentDesc, 41, 20)  
      SET @cOutField06 = '' -- LOT  
      SET @cOutField07 = CAST( @nParentQTY AS NVARCHAR(10))  
  
      -- Go to parent LOT screen  
      SET @nScn  = @nScn - 3  
      SET @nStep = @nStep - 3  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 6. Screen = 5236. Multi SKU  
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
Step_6:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      SET @cMasterLOT = @cLottable07 + @cLottable08  
      
--      SET @cOption = ISNULL(@cInField13,'') 
--      
--      IF @cOption = '' 
--      BEGIN
--         SET @nErrNo = 129333  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption  
--         --SET @cOutField06 = ''  
--         GOTO Quit
--      END
              
      EXEC rdt.rdt_CPVMultiSKUExtLOT @nMobile, @nFunc, @cLangCode,  
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
         @cMasterLOT,   
         @cStorerKey OUTPUT,  
         @cParentSKU OUTPUT,  
         @nErrNo     OUTPUT,  
         @cErrMsg    OUTPUT  
  
      IF @nErrNo <> 0  
      BEGIN  
         IF @nErrNo = -1  
            SET @nErrNo = 0  
         GOTO Quit  
      END  
      
      SELECT  
         @cParentDesc = Descr,   
         @nParentShelfLife = SUSR2,   
         @cChildSKU = BUSR6,   
         @nParentCaseCNT = CAST( Pack.CaseCNT AS INT)  
      FROM dbo.SKU WITH (NOLOCK)  
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
      WHERE StorerKey = @cStorerKey  
         AND SKU = @cParentSKU  
  
      -- Get child SKU info  
      SELECT  
         @cChildDesc = Descr,  
         @nChildCaseCNT = CAST( Pack.CaseCNT AS INT)  
      FROM dbo.SKU WITH (NOLOCK)  
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
      WHERE StorerKey = @cStorerKey  
         AND SKU = @cChildSKU  
        
      -- Check child SKU  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 129330  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No child SKU  
         --SET @cOutField06 = ''  
         GOTO Quit  
      END  
  
      -- Check child packing  
      IF @nParentCaseCNT = 0  
      BEGIN  
         SET @nErrNo = 129331  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoChildCaseCNT  
         --SET @cOutField06 = ''  
         GOTO Quit  
      END  
  
      SET @nParentQTY = 0  
  
      -- Get master LOT info  
      SELECT TOP 1  
         @cExternLotStatus = ExternLotStatus,  
         @dExternLottable04 = ExternLottable04  
      FROM ExternLotAttribute WITH (NOLOCK)  
      WHERE ExternLOT = @cMasterLOT  
         AND StorerKey = @cStorerKey  
         AND SKU = @cParentSKU   
  
      -- Check master LOT status  
      IF @cExternLotStatus <> 'ACTIVE'  
      BEGIN  
         SET @nErrNo = 129328  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive LOT  
         SET @cOutField06 = ''  
         GOTO Quit  
      END  
        
      
      -- Calc expiry date  
      SET @dToday = CONVERT( DATE, GETDATE()) -- Today  
      SET @dExpiryDate = @dExternLottable04  
      IF @nParentShelfLife > 0  
         SET @dExpiryDate = DATEADD( dd, -@nParentShelfLife, @dExternLottable04)  
              
      -- Check expired stock  
      IF @dExpiryDate < @dToday  
      BEGIN  
         SET @nErrNo = 129332  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stock expired  
         SET @cOutField06 = ''  
         GOTO Quit  
      END  
        
      -- Confirm  
      EXEC rdt.rdt_CPVAdjustment_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'PARENT',   
         @cADJKey     = @cADJKey,  
         @cParentSKU  = @cParentSKU,  
         @cLottable07 = @cLottable07,  
         @cLottable08 = @cLottable08,  
         @nParentQTY  = @nParentQTY OUTPUT,  
         @nErrNo      = @nErrNo     OUTPUT,  
         @cErrMsg     = @cErrMsg    OUTPUT  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      SET @cTotal = (@nParentQTY * @nParentCaseCNT) / @nChildCaseCNT  
      SET @cScan = '0'  
        
      -- Prepare next screen var  
      SET @cOutField01 = @cChildSKU  
      SET @cOutField02 = SUBSTRING( @cChildDesc, 1, 20)  
      SET @cOutField03 = SUBSTRING( @cChildDesc, 21, 20)  
      SET @cOutField04 = SUBSTRING( @cChildDesc, 41, 20)  
      SET @cOutField05 = '' -- LOT  
      SET @cOutField06 = @cDefaultQTY  
      SET @cOutField07 = @cScan + '/' + @cTotal  
      
      EXEC rdt.rdtSetFocusField @nMobile, 5 -- ChildLot  
      
         -- Go to LOT screen  
      SET @nScn = @nScn - 3  
      SET @nStep = @nStep - 3  
   END  
  
  

END  
GOTO Quit   
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
  
      StorerKey = @cStorerKey,  
      Facility  = @cFacility,  
  
      V_Lottable04 = @dExternLottable04,  
      V_Lottable07 = @cLottable07,  
      V_Lottable08 = @cLottable08,  
  
      V_String1   = @cADJKey,  
      V_String2   = @cParentSKU,  
      V_String3   = @cChildSKU,  
      V_String4   = @cScan,  
      V_String5   = @cTotal,  
        
      V_String21  = @cDefaultQTY,  
  
      V_String41  = @cParentDesc,  
      V_String42  = @cChildDesc,  
  
      V_Integer1  = @nParentQTY,  
      V_Integer2  = @nParentShelfLife,  
      V_Integer3  = @nParentCaseCNT,  
      V_Integer4  = @nChildCaseCNT,   
      V_Integer5  = @nFromStep,  
  
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
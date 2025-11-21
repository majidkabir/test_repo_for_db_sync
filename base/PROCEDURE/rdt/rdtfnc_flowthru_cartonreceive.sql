SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Flow thru receive carton                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2014-02-27 1.0  Ung      SOS302424 Created                           */
/* 2016-09-30 1.1  Ung      Performance tuning                          */
/* 2018-01-11 1.2  Gan      Performance tuning                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_Flowthru_CartonReceive] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @nTotalCarton INT

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cUserName  NVARCHAR( 18),

   @cReceiptKey   NVARCHAR( 10), 
   @cSKU          NVARCHAR( 20), 
   @cLOC          NVARCHAR( 10), 
   
   @cShipmentID   NVARCHAR( 20),
   @cBrand        NVARCHAR( 10),
   @cFromShop     NVARCHAR( 15), 
   @cFromShopDesc NVARCHAR( 20), 
   @cToShop       NVARCHAR( 15), 
   @cToShopDesc   NVARCHAR( 20), 
   @cCartonID     NVARCHAR( 18),

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

   @cFieldAttr01 VARCHAR( 1), @cFieldAttr02 VARCHAR( 1),
   @cFieldAttr03 VARCHAR( 1), @cFieldAttr04 VARCHAR( 1),
   @cFieldAttr05 VARCHAR( 1), @cFieldAttr06 VARCHAR( 1),
   @cFieldAttr07 VARCHAR( 1), @cFieldAttr08 VARCHAR( 1),
   @cFieldAttr09 VARCHAR( 1), @cFieldAttr10 VARCHAR( 1),
   @cFieldAttr11 VARCHAR( 1), @cFieldAttr12 VARCHAR( 1),
   @cFieldAttr13 VARCHAR( 1), @cFieldAttr14 VARCHAR( 1),
   @cFieldAttr15 VARCHAR( 1)

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
   @cUserName  = UserName,

   @cReceiptKey   = V_ReceiptKey, 
   @cSKU          = V_SKU, 
   @cLOC          = V_LOC, 

   @cShipmentID   = V_String1,
   @cBrand        = V_String2,
   @cFromShop     = V_String3, 
   @cFromShopDesc = V_String4, 
   @cToShop       = V_String5, 
   @cToShopDesc   = V_String6, 
   @cCartonID     = V_String7,

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

IF @nFunc = 587 -- Flow thru carton receiving
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = 587
   IF @nStep = 1 GOTO Step_1   -- Scn = 3760. Shipment ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 3761. Brand, from, to Shop
   IF @nStep = 3 GOTO Step_3   -- Scn = 3762. Carton ID, total carton
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 587. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Set the entry point
   SET @nScn = 3760
   SET @nStep = 1

   -- Enable all fields
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

   -- Initialize var
   SET @cLOC = rdt.RDTGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)
   IF @cLOC = '0'
      SET @cLOC = ''

   -- Init screen
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3760. Shipment ID screen
   SHIPMENT ID (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cShipmentID = @cInField01

      -- Check blank
      IF @cShipmentID = ''
      BEGIN
         SET @nErrNo = 85451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedShipmentID 
         GOTO Step_1_Fail
      END

      -- Check ShipmentID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SHIPMENTID', @cShipmentID) = 0
      BEGIN
         SET @nErrNo = 85452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_1_Fail
      END

      -- Prepare next screen var
      SET @cOutField01 = @cShipmentID
      SET @cOutField02 = '' -- Brand
      SET @cOutField03 = '' -- From shop
      SET @cOutField04 = '' -- To shop

      -- Go to SKU desc screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
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
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = '' --ShipmentID
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3761. Brand, shop screen
   ShipmentID (field01)
   Brand      (field02, input)
   From shop  (field03, input)
   To shop    (field04, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cBrand = @cInField02 --Brand
      SET @cFromShop = @cInField03 --FromShop
      SET @cToShop = @cInField04 --ToShop

      -- Check blank
      IF @cBrand = ''
      BEGIN
         SET @nErrNo = 85453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Brand
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Brand
         SET @cOutField02 = ''
         GOTO Quit
      END
      
      -- Check brand in code lookup
      IF NOT EXISTS( SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'Brand' AND Code = @cBrand)
      BEGIN
         SET @nErrNo = 85454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Brand
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Brand
         SET @cOutField02 = ''
         GOTO Quit
      END
      SET @cOutField02 = @cBrand

      -- Check blank
      IF @cFromShop = ''
      BEGIN
         SET @nErrNo = 85455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need From Shop
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- FromShop
         GOTO Quit
      END

      -- Get From Shop info
      SELECT @cFromShopDesc = Company
      FROM Storer WITH (NOLOCK) 
      WHERE Type = '2' -- Consignee
         AND ConsigneeFor = @cStorerKey 
         AND SUSR1 = @cFromShop
         AND SUSR4 = @cBrand
         
      -- Check from shop
      IF @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 85456
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad From Shop
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- FromShop
         GOTO Quit
      END
      SET @cOutField03 = @cFromShop

      -- Check blank
      IF @cToShop = ''
      BEGIN
         SET @nErrNo = 85457
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need To Shop
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToShop
         GOTO Quit
      END

      -- Get To Shop info
      SELECT @cToShopDesc = Company
      FROM Storer WITH (NOLOCK) 
      WHERE Type = '2' -- Consignee
         AND ConsigneeFor = @cStorerKey 
         AND SUSR1 = @cToShop
         AND SUSR4 = @cBrand

      -- Check to shop
      IF @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 85458
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid To Shop
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToShop
         GOTO Quit
      END
      SET @cOutField04 = @cToShop

      -- Check from, to shop same
      IF @cFromShop = @cToShop
      BEGIN
         SET @nErrNo = 85459
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromToShopSame
         GOTO Quit
      END

      -- Get Receipt info
      DECLARE @cChkStatus NVARCHAR(10)
      SET @cReceiptKey = ''
      SELECT 
         @cReceiptKey = ReceiptKey, 
         @cChkStatus = Status
      FROM Receipt WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND ExternReceiptKey = @cShipmentID
         AND UserDefine01 = @cBrand
         AND PlaceOfLoading = @cFromShop
         AND PlaceOfDischarge = @cToShop

      -- Check receipt open
      IF @cReceiptKey <> '' AND @cChkStatus = '9'
      BEGIN
         SET @nErrNo = 85468
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Receipt Closed
         GOTO Quit
      END

      -- Check Receipt exist
      IF @cReceiptKey = ''
      BEGIN
         -- Get new ReceiptKey
         DECLARE @nSuccess INT
      	SET @nSuccess = 1
      	EXECUTE dbo.nspg_getkey
      		'RECEIPT'
      		, 10
      		, @cReceiptKey OUTPUT
      		, @nSuccess    OUTPUT
      		, @nErrNo      OUTPUT
      		, @cErrMsg     OUTPUT
         IF @nSuccess <> 1
         BEGIN
            SET @nErrNo = 85460
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
            GOTO Quit
         END
         
         -- Insert Receipt
         INSERT INTO Receipt (ReceiptKey, StorerKey, Facility, DocType, RecType, ExternReceiptKey, UserDefine01, PlaceOfLoading, PlaceOfDischarge)
         VALUES (@cReceiptKey, @cStorerKey, @cFacility, 'A', 'Normal', @cShipmentID, @cBrand, @cFromShop, @cToShop)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 85461
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RCP Fail
            GOTO Quit
         END
      END

      -- Get SKU
      SELECT @cSKU = Short FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'Brand' AND Code = @cBrand
      
      -- Calc total carton
      SELECT @nTotalCarton = COUNT( 1) FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

      -- Prep next screen var
      SET @cOutField01 = @cShipmentID
      SET @cOutField02 = @cBrand
      SET @cOutField03 = @cFromShop
      SET @cOutField04 = @cFromShopDesc
      SET @cOutField05 = @cToShop
      SET @cOutField06 = @cToShopDesc
      SET @cOutField07 = '' -- Carton ID
      SET @cOutField08 = CAST( @nTotalCarton AS NVARCHAR(5))

      -- Go to Carton ID screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = '' -- ShipmentID

      -- Go to Shipment ID screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 3761. Carton ID screen
   ShipmentID     (field01)
   Brand          (field02)
   From shop      (field03)
   From shop desc (field04)
   To shop        (field05)
   To shop desc   (field06)
   Carton ID      (field07, input)
   Total carton   (field08)
********************************************************************************/
Step_3:     
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cCartonID = @cInField07
        
      -- Check blank
      IF @cCartonID = ''
      BEGIN
         SET @nErrNo = 85462
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID
         GOTO Quit
      END
      
      -- Check ShipmentID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CARTONID', @cCartonID) = 0
      BEGIN
         SET @nErrNo = 85463
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_1_Fail
      END

      -- Check double scan
      IF EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND Lottable02 = @cCartonID)
      BEGIN
         SET @nErrNo = 85464
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Double scan
         SET @cOutField07 = '' -- CartonID
         GOTO Quit
      END
      
      -- Check scanned to other Receipt
      IF EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ReceiptKey <> @cReceiptKey AND Lottable02 = @cCartonID)
      BEGIN
         SET @nErrNo = 85465
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Double scan
         SET @cOutField07 = '' -- CartonID
         GOTO Quit
      END

      -- Check carton ID reuse
      IF EXISTS( SELECT 1 FROM LotAttribute WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND Lottable02 = @cCartonID)
      BEGIN
         SET @nErrNo = 85466
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Used CartonID
         SET @cOutField07 = '' -- CartonID
         GOTO Quit
      END
      
      -- Get SKU info
      DECLARE @cPackKey NVARCHAR(10)
      DECLARE @cUOM     NVARCHAR(10)
      SELECT @cPackKey = PackKey FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
      SELECT @cUOM = PackUOM3 FROM Pack WITH (NOLOCK) WHERE PackKey = @cPackKey
      
      -- Get ReceiptLineNumber
      DECLARE @cReceiptLineNumber NVARCHAR(5)
      SET @cReceiptLineNumber = ''
      SELECT @cReceiptLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
      FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      
      -- Insert ReceiptDetail
      INSERT INTO ReceiptDetail (ReceiptKey, ReceiptLineNumber, StorerKey, SKU, PackKey, UOM, ToLOC, Lottable01, Lottable02, Lottable03, BeforeReceivedQTY)
      VALUES (@cReceiptKey, @cReceiptLineNumber, @cStorerKey, @cSKU, @cPackKey, @cUOM, @cLOC, @cFromShop, @cCartonID, @cToShop, 1)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 85467
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RCDtl Fail
         GOTO Quit
      END
        
      -- Logging
      EXEC RDT.rdt_STD_EventLog  
         @cActionType = '2', -- Receive
         @cUserID     = @cUserName,  
         @nMobileNo   = @nMobile,  
         @nFunctionID = @nFunc,  
         @cFacility   = @cFacility,  
         @cStorerKey  = @cStorerkey, 
         @cReceiptKey = @cReceiptKey, 
         @cSKU        = @cSKU, 
         @cLocation   = @cLOC, 
         @cLottable02 = @cCartonID, 
         @nQTY        = 1,
         @nStep       = @nStep

      -- Calc total carton
      SELECT @nTotalCarton = COUNT( 1) FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

      -- Retain in current screen
      SET @cOutField07 = '' -- Carton ID
      SET @cOutField08 = CAST( @nTotalCarton AS NVARCHAR(5))
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN    
      -- previous screen var  
      SET @cOutField01 = @cShipmentID
      SET @cOutField02 = '' -- Brand
      SET @cOutField03 = '' -- From Shop
      SET @cOutField04 = '' -- To Shop
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Brand
      
      -- Back to brand screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1      
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
      -- UserName  = @cUserName,

      V_ReceiptKey = @cReceiptKey, 
      V_SKU        = @cSKU, 
      V_LOC        = @cLOC, 

      V_String1 = @cShipmentID,
      V_String2 = @cBrand,
      V_String3 = @cFromShop, 
      V_String4 = @cFromShopDesc, 
      V_String5 = @cToShop, 
      V_String6 = @cToShopDesc, 
      V_String7 = @cCartonID,

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
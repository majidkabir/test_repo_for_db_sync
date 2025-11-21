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
/* 2014-02-27 1.0  Ung      SOS302984 Created                           */
/* 2016-09-30 1.1  Ung      Performance tuning                          */
/* 2018-11-01 1.2  TungGH   Performance                                 */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_Flowthru_CartonPick] (
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

   @cOrderKey  NVARCHAR( 10), 
   
   @cShipmentID   NVARCHAR( 20),
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

   @cOrderKey  = V_OrderKey, 

   @cShipmentID   = V_String1,
   @cToShop       = V_String2, 
   @cToShopDesc   = V_String3, 
   @cCartonID     = V_String4,

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

IF @nFunc = 588 -- Flow thru carton receiving
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = 588
   IF @nStep = 1 GOTO Step_1   -- Scn = 3760. Shipment ID, to Shop
   IF @nStep = 2 GOTO Step_2   -- Scn = 3762. Carton ID, total carton
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
   SET @nScn = 3770
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

   -- Init screen
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3760. Shipment ID, To shop screen
   SHIPMENT ID (field01, input)
   TO SHOP     (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cShipmentID = @cInField01
      SET @cToShop = @cInField02

      -- Check blank
      IF @cShipmentID = ''
      BEGIN
         SET @nErrNo = 85501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedShipmentID 
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Shipment ID
         GOTO Quit
      END

      -- Check ShipmentID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SHIPMENTID', @cShipmentID) = 0
      BEGIN
         SET @nErrNo = 85502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Shipment ID
         SET @cOutField01 = ''
         GOTO Quit
      END
      SET @cOutField01 = @cShipmentID

      -- Check blank
      IF @cToShop = ''
      BEGIN
         SET @nErrNo = 85503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need To Shop
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ToShop
         GOTO Quit
      END

      -- Get To Shop info
      SELECT @cToShopDesc = Company
      FROM Storer WITH (NOLOCK) 
      WHERE Type = '2' -- Consignee
         AND ConsigneeFor = @cStorerKey 
         AND SUSR1 = @cToShop

      -- Check to shop
      IF @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 85504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ToShop
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ToShop
         GOTO Quit
      END
      SET @cOutField02 = @cToShop

      -- Get Order info
      DECLARE @cChkStatus NVARCHAR(10)
      SET @cOrderKey = ''
      SELECT 
         @cOrderKey = OrderKey, 
         @cChkStatus = Status
      FROM Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND ExternOrderKey = @cShipmentID
         AND ConsigneeKey = @cToShop

      -- Check order open
      IF @cOrderKey <> '' AND @cChkStatus = '9'
      BEGIN
         SET @nErrNo = 85505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Shipped
         GOTO Quit
      END

      -- Check Order exist
      IF @cOrderKey = ''
      BEGIN
         -- Get new ReceiptKey
         DECLARE @nSuccess INT
      	SET @nSuccess = 1
      	EXECUTE dbo.nspg_getkey
      		'ORDER'
      		, 10
      		, @cOrderKey OUTPUT
      		, @nSuccess    OUTPUT
      		, @nErrNo      OUTPUT
      		, @cErrMsg     OUTPUT
         IF @nSuccess <> 1
         BEGIN
            SET @nErrNo = 85506
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
            GOTO Quit
         END
         
         -- Insert Order
         INSERT INTO Orders (OrderKey, StorerKey, Facility, ExternOrderKey, ConsigneeKey, UserDefine08, BuyerPO)
         VALUES (@cOrderKey, @cStorerKey, @cFacility, @cShipmentID, @cToShop, '2', @cToShopDesc) -- udf8=2 is for user at mbol detail, RMC populate from order (type2)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 85507
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RCP Fail
            GOTO Quit
         END
      END

      -- Calc total carton
      SELECT @nTotalCarton = COUNT( 1) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      -- Prepare next screen var
      SET @cOutField01 = @cShipmentID
      SET @cOutField02 = @cToShop
      SET @cOutField03 = @cToShopDesc
      SET @cOutField04 = '' -- Carton ID
      SET @cOutField05 = CAST( @nTotalCarton AS NVARCHAR(5))

      -- Go to Carton ID screen
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
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3761. Carton ID screen
   ShipmentID     (field01)
   To shop        (field02)
   To shop desc   (field03)
   Carton ID      (field04, input)
   Total carton   (field05)
********************************************************************************/
Step_2:
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cCartonID = @cInField04
        
      -- Check blank
      IF @cCartonID = ''
      BEGIN
         SET @nErrNo = 85508
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID
         GOTO Quit
      END
      
      -- Check CartonID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CARTONID', @cCartonID) = 0
      BEGIN
         SET @nErrNo = 85509
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Quit
      END

      -- Check CartonID valid
      IF NOT EXISTS( SELECT 1 FROM LOTAttribute WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND Lottable02 = @cCartonID)
      BEGIN
         SET @nErrNo = 85510
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonID
         GOTO Quit
      END
      
      DECLARE @cSKU NVARCHAR(20)
      DECLARE @cLOT NVARCHAR(10)
      DECLARE @cLOC NVARCHAR(10)
      DECLARE @cID  NVARCHAR(18)
      DECLARE @cLottable03 NVARCHAR(18)
      SET @cSKU = ''
      SET @cLOT = ''
      SET @cLOC = ''
      SET @cID  = ''
      SET @cLottable03 = ''

      -- Get inventory info
      SELECT 
         @cSKU = LLI.SKU, 
         @cLOT = LLI.LOT, 
         @cLOC = LLI.LOC, 
         @cID = LLI.ID, 
         @cLottable03 = LA.Lottable03
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LLI.StorerKey = @cStorerKey
         AND LA.Lottable02 = @cCartonID
         AND (LLI.QTY-LLI.QTYAllocated-QTYPicked) > 0   
      
      -- Check double scan
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 85511
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Double scan
         GOTO Quit
      END
      
      -- Check different ToShop
      IF @cToShop <> @cLottable03
      BEGIN
         SET @nErrNo = 85512
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff ToShop
         GOTO Quit
      END
      
      -- Create PickDetail
      EXEC rdt.rdt_Flowthru_CartonPick @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
         ,@cOrderKey
         ,@cCartonID
         ,@cSKU
         ,@cLOT
         ,@cLOC
         ,@cID
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
        
      -- Calc total carton
      SELECT @nTotalCarton = COUNT( 1) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      -- Retain in current screen
      SET @cOutField04 = '' -- Carton ID
      SET @cOutField05 = CAST( @nTotalCarton AS NVARCHAR(5))
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN    
      -- previous screen var  
      SET @cOutField01 = '' -- ShipmentID
      SET @cOutField02 = '' -- To Shop
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ShipmentID
      
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

      V_OrderKey = @cOrderKey, 

      V_String1 = @cShipmentID,
      V_String2 = @cToShop, 
      V_String3 = @cToShopDesc, 
      V_String4 = @cCartonID,

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
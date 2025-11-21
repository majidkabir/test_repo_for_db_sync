SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_ReturnByTrackNo                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Receive return SKU and have option to exchange another SKU  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 2012-03-15 1.0  Ung       SOS235637 Created                          */
/* 2012-05-18 1.1  Ung       SOS244875 Add factory code and LOT         */
/*                           Storer config ReturnByTrackNoSkipCheckColor*/
/* 2016-09-30 1.2  Ung       Performance tuning                         */
/* 2018-11-12 1.3  TungGH    Performance                                */ 
/************************************************************************/
CREATE   PROCEDURE [RDT].[rdtfnc_ReturnByTrackNo] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cOption NVARCHAR(1), 
   @cChkFacility NVARCHAR( 5)

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR( 3),

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cUserName           NVARCHAR( 18),
   @cPrinter            NVARCHAR( 10),

   @cReceiptKey         NVARCHAR( 10),
   @cRECType            NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cSKU                NVARCHAR( 20),
   @cDescr              NVARCHAR( 60),
   @cUOM                NVARCHAR( 10),
   @nQTY                INT, 
   @cOrderKey           NVARCHAR( 10), 

   @cTrackingNo         NVARCHAR( 20), 
   @cPackKey            NVARCHAR( 10),
   @nCurrentRec         INT,
   @nTotalRec           INT,
   @nRowID              INT,  
   @cCondition          NVARCHAR( 1), 
   @cReason             NVARCHAR( 10), 
   @cOrderLineNumber    NVARCHAR( 5), 
   @cBuyerPO            NVARCHAR( 20), 
   @cExternOrderKey     NVARCHAR( 20), 
   @cUserDefine01       NVARCHAR( 18), 
   @cExchgSKU           NVARCHAR( 20),
   @cStyle              NVARCHAR( 20), 
   @cColor              NVARCHAR( 10), 
   @cSize               NVARCHAR( 5), 
   @cFactoryCode        NVARCHAR( 10),
   @cFactoryLOT         NVARCHAR( 10), 
   @cSkipCheckColor     NVARCHAR( 1), 

   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1), 
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1) 

-- Getting Mobile information
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @cLangCode   = Lang_code,
   @nMenu       = Menu,

   @cFacility   = Facility,
   @cStorerKey  = StorerKey,
   @cUserName   = UserName,
   @cPrinter    = Printer,

   @cReceiptKey = V_ReceiptKey,
   @cLOC        = V_LOC,
   @cSKU        = V_SKU,
   @cDescr      = V_SKUDescr,
   @cUOM        = V_UOM,
   @nQTY        = V_QTY, 
   @cOrderKey   = V_OrderKey, 

   @cTrackingNo = V_String1,
   @cPackKey    = V_String2,
   @cRECType    = V_String6,
   @cCondition  = V_String7, 
   @cReason     = V_String8, 
   @cOrderLineNumber = V_String9, 
   @cBuyerPO         = V_String10, 
   @cExternOrderKey  = V_String11, 
   @cUserDefine01    = V_String12, 
   @cExchgSKU        = V_String13, 
   @cStyle           = V_String14, 
   @cColor           = V_String15, 
   @cSize            = V_String16, 
   @cFactoryCode     = V_String17,
   @cFactoryLOT      = V_String18, 
   @cSkipCheckColor  = V_String19, 
   
   @nCurrentRec = V_Integer1,
   @nTotalRec   = V_Integer2,
   @nRowID      = V_Integer3,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01  =FieldAttr01,
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

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 549
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 549. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn = 3040. ASN
   IF @nStep = 2 GOTO Step_2   -- Scn = 3041. Tracking no
   IF @nStep = 3 GOTO Step_3   -- Scn = 3042. Return SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 3043. Return SKU lookup
   IF @nStep = 5 GOTO Step_5   -- Scn = 3044. Return SKU condtion
   IF @nStep = 6 GOTO Step_6   -- Scn = 3045. Exchange SKU
   IF @nStep = 7 GOTO Step_7   -- Scn = 3046. Exchange SKU confirm
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1580. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- EventLog sign in
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

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

   -- Storer config
   SET @cSkipCheckColor = rdt.RDTGetConfig( 549, 'ReturnByTrackNoSkipCheckColor', @cStorerKey)    

   -- Prep next screen var
   SET @cOutField01 = '' -- ReceiptKey

   -- Set the entry point
   SET @nScn  = 3040
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 3040. ASN screen
   ASN (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReceiptKey = @cInField01
      
      -- Check ASN blank
      IF @cReceiptKey = ''
      BEGIN
         SET @nErrNo = 75401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN needed
         GOTO Step_1_Fail
      END

      DECLARE @cChkStorerKey NVARCHAR( 15)
      DECLARE @cChkASNStatus NVARCHAR( 10)
      DECLARE @cChkStatus    NVARCHAR( 10)
      DECLARE @cChkDocType   NVARCHAR( 1)

      -- Get ASN info
      SELECT 
         @cChkFacility = Facility, 
         @cChkStorerKey = StorerKey, 
         @cChkASNStatus = ASNStatus, 
         @cChkStatus = Status, 
         @cChkDocType = DocType, 
         @cRECType = RECType
      FROM dbo.Receipt WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptkey

      -- Check if receiptkey exists
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 75402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exists
         GOTO Step_1_Fail
      END

      -- Check diff facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 75403
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_1_Fail
      END

      -- Check diff storer
      IF @cChkStorerKey <> @cStorerKey
      BEGIN
         SET @nErrNo = 75404
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         GOTO Step_1_Fail

      END

      -- Check for ASN closed by receipt.ASNStatus
      IF @cChkASNStatus = '9'
      BEGIN
         SET @nErrNo = 75405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASNStatusClose
         GOTO Step_1_Fail
      END

      -- Check for ASN cancelled
      IF @cChkASNStatus = 'CANC'
      BEGIN
         SET @nErrNo = 75406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASNStatus CANC
         GOTO Step_1_Fail
      END

      -- Check for ASN cancelled
      IF @cChkStatus = '9'
      BEGIN
         SET @nErrNo = 75407
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Status Closed
         GOTO Step_1_Fail
      END

      -- Check if trade return ASN
      IF @cChkDocType <> 'R'
      BEGIN
         SET @nErrNo = 75408
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not ReturnASN
         GOTO Step_1_Fail
      END

      --prepare next screen variable
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = ''-- TrackingNo

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- EventLog sign out
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerKey,
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = '' -- ReceiptKey
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3041. Tracking No screen
   RTN ASN     (field01)
   TRACKING NO (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cTrackingNo = @cInField02

      -- Check blank LOC
      IF @cTrackingNo = ''
      BEGIN
         SET @nErrNo = 75409
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedTrackingNo
         GOTO Step_2_Fail
      END
      
      -- Check TrackingNo valid
      IF NOT EXISTS( SELECT 1 FROM dbo.UPSReturnTrackNo WITH (NOLOCK) WHERE RefNo01 = @cTrackingNo)
      BEGIN
         SET @nErrNo = 75410
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadTrackingNo
         GOTO Step_2_Fail
      END
      
      -- Get TrackingNo inf
      SELECT 
         @cOrderKey = OrderKey, 
         @cOrderLineNumber = OrderLineNumber, 
         @cSKU = SKU, 
         @nQTY = QTY, 
         @cBuyerPO = LEFT( ISNULL( RefNo02, ''), 20), 
         @cExternOrderKey = LEFT( ISNULL( RefNo05, ''), 20), 
         @cUserDefine01 = RefNo04
      FROM dbo.UPSReturnTrackNo WITH (NOLOCK) 
      WHERE RefNo01 = @cTrackingNo

      -- Get SKU info
      SELECT 
         @cDescr = SKU.Descr, 
         @cStyle = SKU.Style,
         @cColor = SKU.Color, 
         @cSize = SKU.Size, 
         @cUOM = Pack.PackUOM3,
         @cPackKey = Pack.PackKey
      FROM dbo.SKU WITH (NOLOCK)
         INNER JOIN Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

/*
      -- Get order info
      SELECT 
         @cBuyerPO = BuyerPO, 
         @cExternOrderKey = LEFT( ExternOrderKey, 20)
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Get orderdetail info
      SELECT @cUserDefine01 = UserDefine01 
      FROM dbo.OrderDetail WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
         AND OrderLineNumber = @cOrderLineNumber
*/
         
      -- Prep next screen var
      SET @cOutField01 = @cBuyerPO
      SET @cOutField02 = @cExternOrderKey
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cDescr, 20, 20)
      SET @cOutField06 = @cStyle
      SET @cOutField07 = @cColor
      SET @cOutField08 = @cSize
      SET @cOutField09 = '' -- Option
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- ReceiptKey

      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cTrackingNo = ''
      SET @cOutField02 = '' -- TrackingNo
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 3042. Return SKU screen
   PT     (field01)
   PO     (field02)
   SKU    (field03)
   Desc1  (field04)
   Desc2  (field05)
   Style  (field06)
   Color  (field07)
   Size   (field08)
   Option (field09)
   1=RECEIVE 2=LOOKUP
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField09
      
      -- Check valid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 75411
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid option
         GOTO Quit
      END

      IF @cOption = '1' -- Receive
      BEGIN         
         --prepare next screen variable
         SET @cOutField01 = '' -- Return type
         SET @cOutField02 = '' -- Condition code
         SET @cOutField03 = '' -- Reason code
         SET @cOutField04 = '' -- To LOC
         SET @cOutField05 = '' -- Factory code
         SET @cOutField06 = '' -- Factory LOT

         EXEC rdt.rdtSetFocusField @nMobile, 01
         
         -- Go to return SKU condition screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
         
         GOTO Quit
      END
               
      IF @cOption = '2' -- Lookup
      BEGIN
         -- Get counter
         SET @nCurrentRec = 1
         SELECT @nTotalRec = COUNT(1) 
         FROM dbo.UPSReturnTrackNo WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         
         -- Get TrackingNo inf
         SELECT TOP 1
            @cOrderKey = OrderKey, 
            @cOrderLineNumber = OrderLineNumber, 
            @nRowID = RowID, 
            @cSKU = SKU 
         FROM dbo.UPSReturnTrackNo WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         ORDER BY RowID

         -- Get SKU info
         SELECT 
            @cDescr = SKU.Descr, 
            @cStyle = SKU.Style,
            @cColor = SKU.Color, 
            @cSize = SKU.Size
         FROM dbo.SKU WITH (NOLOCK)
            INNER JOIN Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         -- Get orderdetail info
         SELECT @cUserDefine01 = UserDefine01 
         FROM dbo.OrderDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND OrderLineNumber = @cOrderLineNumber

         -- Prep next screen var
         SET @cOutField01 = @cUserDefine01
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cDescr, 20, 20)
         SET @cOutField05 = @cStyle
         SET @cOutField06 = @cColor
         SET @cOutField07 = @cSize
         SET @cOutField08 = '' --Option
         SET @cOutField09 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5)) 

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = '' --TrackingNo

      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 3043. Lookup return SKU screen
   Name   (field01)
   SKU    (field02)
   Desc1  (field03)
   Desc2  (field04)
   Style  (field05)
   Color  (field06)
   Size   (field07)
   QTY    (field08)
   Option (field09)
   1=RECEIVE,ENTER=NEXT
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField08

      -- Loop next record
      IF @cOption = ''
      BEGIN
         -- Get TrackingNo inf
         SELECT TOP 1
            @cOrderKey = OrderKey, 
            @cOrderLineNumber = OrderLineNumber, 
            @nRowID = RowID, 
            @cSKU = SKU 
         FROM dbo.UPSReturnTrackNo WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
            AND RowID > @nRowID
         ORDER BY RowID

         -- Check end of records
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 75412
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more record
            GOTO Quit
         END

         -- Get SKU info
         SELECT 
            @cDescr = SKU.Descr, 
            @cStyle = SKU.Style,
            @cColor = SKU.Color, 
            @cSize = SKU.Size
         FROM dbo.SKU WITH (NOLOCK)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         -- Get orderdetail info
         SELECT @cUserDefine01 = UserDefine01 
         FROM dbo.OrderDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND OrderLineNumber = @cOrderLineNumber

         -- Prep next screen var
         SET @nCurrentRec = @nCurrentRec + 1
         SET @cOutField01 = @cUserDefine01
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cDescr, 20, 20)
         SET @cOutField05 = @cStyle
         SET @cOutField06 = @cColor
         SET @cOutField07 = @cSize
         SET @cOutField08 = '' -- Option
         SET @cOutField09 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5)) 
         
         GOTO Quit
      END 

      -- Check valid option
      IF @cOption <> '1'
      BEGIN
         SET @nErrNo = 75413
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid option
         GOTO Quit
      END
      
      IF @cOption = '1' -- Receive
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = '' --RECType
         SET @cOutField02 = '' --CondCode
         SET @cOutField03 = '' --Reason
         SET @cOutField04 = '' --To LOC
         SET @cOutField05 = '' --Factory code
         SET @cOutField06 = '' --Factory LOT

         EXEC rdt.rdtSetFocusField @nMobile, 01
         
         -- Go to TrackingNo screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Get TrackingNo inf
      SELECT 
         @cOrderKey = OrderKey, 
         @cOrderLineNumber = OrderLineNumber, 
         @cSKU = SKU
      FROM dbo.UPSReturnTrackNo WITH (NOLOCK) 
      WHERE RefNo01 = @cTrackingNo

      -- Get SKU info
      SELECT 
         @cDescr = SKU.Descr, 
         @cStyle = SKU.Style,
         @cColor = SKU.Color, 
         @cSize = SKU.Size
      FROM dbo.SKU WITH (NOLOCK)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU
      
      -- Prep next screen var
      SET @cOutField01 = @cBuyerPO
      SET @cOutField02 = @cExternOrderKey
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cDescr, 20, 20)
      SET @cOutField06 = @cStyle
      SET @cOutField07 = @cColor
      SET @cOutField08 = @cSize
      SET @cOutField09 = '' -- Option
      
      -- Go to return SKU screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 3044. Return SKU condition screen
   RTN TYPE  (field01)
   CONDCODE  (field02)
   RSN CODE  (field03)
   TO LOC    (field04)
   FCTRYCOD  (field05)
   FCTRYLOT  (field06)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cRECType = @cInField01
      SET @cCondition = @cInField02
      SET @cReason = @cInField03
      SET @cLOC = @cInField04
      SET @cFactoryCode = @cInField05
      SET @cFactoryLOT = @cInField06
      
      -- Check return type
      IF @cRECType NOT IN ('RETURN', 'EXCHANGE')
      BEGIN
         SET @nErrNo = 75414
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ReturnType
         EXEC rdt.rdtSetFocusField @nMobile, 01
         SET @cOutField01 = ''
         GOTO Quit
      END
      SET @cOutField01 = @cRECType      
      
      -- Check condition
      IF @cCondition NOT IN ('1', '2', '3', '5')
      BEGIN
         SET @nErrNo = 75415
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Condition
         EXEC rdt.rdtSetFocusField @nMobile, 02
         SET @cOutField02 = ''
         GOTO Quit
      END
      SET @cOutField02 = @cCondition
      
      -- Check reason
      IF NOT EXISTS( SELECT * FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = '3PSRETURN' AND Short = @cReason)
      BEGIN
         SET @nErrNo = 75416
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Reason
         EXEC rdt.rdtSetFocusField @nMobile, 03
         SET @cOutField03 = ''
         GOTO Quit
      END
      SET @cOutField03 = @cReason
      
      -- Check blank LOC
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         SET @nErrNo = 75417
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC required
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Quit
      END

      -- Get LOC info
      DECLARE @cChkLOC NVARCHAR( 10)
      SELECT 
         @cChkLOC = LOC, 
         @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE LOC = @cLOC

      -- Check invalid LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 75418
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not found
         EXEC rdt.rdtSetFocusField @nMobile, 4
         SET @cOutField04 = ''
         GOTO Quit
      END

      -- Check different facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 75419
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 4
         SET @cOutField04 = ''
         GOTO Quit
      END
      SET @cOutField04 = @cLOC

      -- Check factory code
      IF @cFactoryCode = '' OR @cFactoryCode IS NULL
      BEGIN
         SET @nErrNo = 75430
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need FctryCode
         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Quit
      END
      SET @cOutField05 = @cFactoryCode

      -- Check factory code
      IF @cFactoryLOT = '' OR @cFactoryLOT IS NULL
      BEGIN
         SET @nErrNo = 75431
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need FctryLOT
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END
      SET @cOutField06 = @cFactoryLOT

      IF @cRECType = 'RETURN'
      BEGIN
         -- Receive
         EXEC rdt.rdt_ReturnByTrackNo_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility, 
            @cTrackingNo, 
            @cRECType, 
            @cReceiptKey, 
            @cLOC, 
            @cSKU,             --Return SKU
            '',                --Exchange SKU
            @cCondition, 
            @cReason, 
            @cFactoryCode, 
            @cFactoryLOT, 
            @cBuyerPO,         --ReceiptDetail.ExternReceiptKey NVARCHAR(20)
            @cExternOrderKey,  --ReceiptDetail.ExternLineNo     NVARCHAR(20)
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
         
         -- Prepare next screen variable
         SET @cOutField01 = @cReceiptkey
         SET @cOutField02 = '' -- TrackingNo
         
         -- Go to tracking no screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3
         
         GOTO Quit
      END
         
      IF @cRECType = 'EXCHANGE'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' --SKU
         SET @cOutField02 = '' --Style
         SET @cOutField03 = '' --Color
         SET @cOutField04 = '' --Size

         IF @cSkipCheckColor = '1'
         BEGIN
            SET @cFieldAttr03 = 'O' -- Color
            SET @cInField03 = ''
         END
   
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         
         GOTO QUIT
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cBuyerPO
      SET @cOutField02 = @cExternOrderKey
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cDescr, 20, 20)
      SET @cOutField06 = @cStyle
      SET @cOutField07 = @cColor
      SET @cOutField08 = @cSize
      SET @cOutField09 = '' -- Option

      -- Go to previous screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
END
GOTO Quit


/********************************************************************************
Step 6. Screen = 3045. Exchange SKU screen
   SKU   (field01)
   Style (field02)
   Color (field03)
   Size  (field04)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @nSKUCnt INT
      DECLARE @cExchgDescr NVARCHAR( 60)
      DECLARE @cExchgStyle NVARCHAR( 20)
      DECLARE @cExchgColor NVARCHAR( 10)
      DECLARE @cExchgSize  NVARCHAR( 5)

      -- Screen mapping
      SET @cExchgSKU = @cInField01
      SET @cExchgStyle = @cInField02
      SET @cExchgColor = @cInField03
      SET @cExchgSize = @cInField04
      
      -- Check blank
      IF @cExchgSKU = '' AND @cExchgStyle = '' AND @cExchgColor = '' AND @cExchgSize = ''
      BEGIN
         SET @nErrNo = 75420
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need value
         EXEC rdt.rdtSetFocusField @nMobile, 01
         GOTO Quit
      END
      
      -- Check both key-in
      IF (@cExchgSKU <> '') AND (@cExchgStyle <> '' OR @cExchgColor <> '' OR @cExchgSize <> '')
      BEGIN
         SET @nErrNo = 75421
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU or Style
         EXEC rdt.rdtSetFocusField @nMobile, 01
         GOTO Quit
      END
      
      -- Check SKU blank
      IF @cExchgSKU = ''
      BEGIN
         -- Check Style
         IF @cExchgStyle = ''
         BEGIN
            SET @nErrNo = 75422
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Style
            EXEC rdt.rdtSetFocusField @nMobile, 02
            SET @cOutField02 = ''
            GOTO Quit
         END
         SET @cOutField02 = @cExchgStyle

         -- Check Color
         IF @cSkipCheckColor = '1'
            SET @cOutField03 = ''
         ELSE
         BEGIN
            IF @cExchgColor = '' 
            BEGIN
               SET @nErrNo = 75423
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Color
               EXEC rdt.rdtSetFocusField @nMobile, 03
               SET @cOutField03 = ''
               GOTO Quit
            END
            SET @cOutField03 = @cExchgColor
         END
         
         -- Check Size
         IF @cExchgSize = ''
         BEGIN
            SET @nErrNo = 75424
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Size
            EXEC rdt.rdtSetFocusField @nMobile, 04
            SET @cOutField04 = ''
            GOTO Quit
         END
         SET @cOutField04 = @cExchgSize
         
         -- Get SKU info
         SET @cExchgSKU = ''
         SELECT 
            @nSKUCnt = COUNT( 1), 
            @cExchgSKU = MAX( SKU)
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND Style = @cExchgStyle
            AND Color = CASE WHEN @cSkipCheckColor = '1' THEN Color ELSE @cExchgColor END
            AND Size = @cExchgSize
            
         -- Check SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 75425
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No SKU found
            EXEC rdt.rdtSetFocusField @nMobile, 02
            GOTO Quit
         END
   
         -- Check multi SKU return
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 75426
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Multi SKU
            GOTO Quit
         END
      END
      
      -- Get SKU barcode count
      DECLARE @bSuccess INT
      EXEC rdt.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cExchgSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 75427
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         GOTO Quit
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 75428
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
         GOTO Quit
      END

      -- Get SKU code
      EXEC rdt.rdt_GETSKU
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cExchgSKU  OUTPUT
         ,@bSuccess    = @bSuccess   OUTPUT
         ,@nErr        = @nErrNo     OUTPUT
         ,@cErrMsg     = @cErrMsg    OUTPUT
      
      -- Get SKU info
      SELECT 
         @cExchgDescr = SKU.Descr, 
         @cExchgStyle = SKU.Style,
         @cExchgColor = SKU.Color, 
         @cExchgSize = SKU.Size
      FROM dbo.SKU WITH (NOLOCK)
         INNER JOIN Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cExchgSKU
      
      --prepare next screen variable
      SET @cOutField01 = @cExchgSKU
      SET @cOutField02 = SUBSTRING( @cExchgDescr, 1, 20)
      SET @cOutField03 = SUBSTRING( @cExchgDescr, 20, 20)
      SET @cOutField04 = @cExchgStyle
      SET @cOutField05 = @cExchgColor
      SET @cOutField06 = @cExchgSize

      SET @cFieldAttr03 = ''
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = '' -- RECType
      SET @cOutField02 = '' -- Condition
      SET @cOutField03 = '' -- Reason
      SET @cOutField04 = '' -- To LOC
      SET @cOutField05 = '' -- Factory code
      SET @cOutField06 = '' -- Factory LOT

      SET @cFieldAttr03 = ''

      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 7. Screen = 3046. Confirm exchange SKU screen
   SKU   (field01)
   Desc1 (field02)
   Desc2 (field03)
   Style (field04)
   Color (field05)
   Size  (field06)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Receive
      EXEC rdt.rdt_ReturnByTrackNo_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility, 
         @cTrackingNo, 
         @cRECType, 
         @cReceiptKey, 
         @cLOC, 
         @cSKU,             --Return SKU
         @cExchgSKU,        --Exchange SKU
         @cCondition, 
         @cReason, 
         @cFactoryCode, 
         @cFactoryLOT, 
         @cBuyerPO,         --ReceiptDetail.ExternReceiptKey NVARCHAR(20)
         @cExternOrderKey,  --ReceiptDetail.ExternLineNo     NVARCHAR(20)
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
      
      -- Prep next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = '' -- TrackingNo   
      
      -- Go to tracking no screen
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
      
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 'Label sent to print'
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = '' --@cExchgSKU
      SET @cOutField02 = '' --@cExchgStyle
      SET @cOutField03 = '' --@cExchgColor
      SET @cOutField04 = '' --@cExchgSize
      
      IF @cSkipCheckColor = '1'
         SET @cFieldAttr03 = 'O' -- Color
      
      -- Go to previous screen
      SET @nScn = @nScn - 1
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
      Func = @nFunc,
      Step = @nStep,
      Scn = @nScn,

      Facility  = @cFacility,
      StorerKey = @cStorerKey,
      -- UserName  = @cUserName,

      V_Receiptkey = @cReceiptkey,
      V_LOC        = @cLOC,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cDescr,
      V_QTY        = @nQTY, 
      V_UOM        = @cUOM,
      V_OrderKey   = @cOrderKey, 

      V_String1    = @cTrackingNo,
      V_String2    = @cPackKey, 
      V_String6    = @cRECType,
      V_String7    = @cCondition, 
      V_String8    = @cReason, 
      V_String9    = @cOrderLineNumber, 
      V_String10   = @cBuyerPO, 
      V_String11   = @cExternOrderKey, 
      V_String12   = @cUserDefine01, 
      V_String13   = @cExchgSKU,
      V_String14   = @cStyle, 
      V_String15   = @cColor, 
      V_String16   = @cSize, 
      V_String17   = @cFactoryCode,
      V_String18   = @cFactoryLOT, 
      V_String19   = @cSkipCheckColor, 
      
      V_Integer1   = @nCurrentRec,
      V_Integer2   = @nTotalRec, 
      V_Integer3   = @nRowID,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO
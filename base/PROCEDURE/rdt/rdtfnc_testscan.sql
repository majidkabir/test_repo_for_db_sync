SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_TestScan                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Receive by carton no                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2013-02-27 1.0  James    SOS271073 Created                           */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_TestScan] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE @b_Success      INT,
   @cExtendedInfoSP     NVARCHAR(20),
   @cExtendedInfo       NVARCHAR(20),
   @cSQL                NVARCHAR(1000),
   @cSQLParam           NVARCHAR(1000)

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
   @cUserName   NVARCHAR(18),
   @cPrinter    NVARCHAR(10),

   @nCounter    INT,
   @cLoadKey      NVARCHAR( 10),
   @cConsigneeKey NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cPOKey        NVARCHAR( 10),
   @cToLOC        NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @cUOM          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cSKUDesc      NVARCHAR( 60),
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @cLottable04   NVARCHAR( 16),
   @cLottable05   NVARCHAR( 16),
   @cOption       NVARCHAR( 1),
   @cPrefUOM      NVARCHAR( 1),
   @cTempQty      NVARCHAR( 5),
   @cCartonNo     NVARCHAR( 20),
   @cLabelNo      NVARCHAR( 20),
   @cTempSKU      NVARCHAR( 20),
   @cShipmentID         NVARCHAR( 20),
   @cReceiptStatus      NVARCHAR( 10),
   @cReceiptFacility    NVARCHAR( 5),
   @cReceiptLineNumber  NVARCHAR( 5),
   @cDocType            NVARCHAR( 1),

   @nQty                   INT,
   @nExpQTY                INT,
   @nSUM_B4ReceivedQty     INT,
   @nSUM_QtyExpected       INT,
   @nTranCount             INT,
   @nSKUCnt                INT,
   @nSum_QtyExp            INT,
   @nCheckExp              INT,
   @nCheckB4Rcv            INT,
   @nReceiptKey_Cnt        INT,
   @nDefaultReceivingQty   INT,

   @c_RCPTLOGITF           NVARCHAR( 1),
   @cTestData              NVARCHAR( MAX),
   @n_err                  INT,
   @c_errmsg               NVARCHAR( 250),

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

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,
   @cPrinter    = Printer,

   @cReceiptKey = V_ReceiptKey,
   @cPOKey      = V_POKey,
   @cToLOC      = V_Loc,
   @cSKU        = V_SKU,
   @cUOM        = V_UOM,
   @cID         = V_ID,
   @cSKUDesc    = V_SKUDescr,

   @cLottable01 = V_Lottable01,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @cLottable04 = V_Lottable04,
   @cLottable05 = V_Lottable05,

   @cTestData      = V_Max,
   @cExtendedInfoSP  = V_String2,
   @cCartonNo        = V_String3,

   @nCounter         = V_Integer1,

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

-- Redirect to respective screen
IF @nFunc = 9999
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 589
   IF @nStep = 1 GOTO Step_1   -- Scn = 3540. Shipment ID

END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 9991
   SET @nStep = 1

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

      SET @nCounter = 0
      SET @cOutField02 = @nCounter

END
GOTO Quit


/********************************************************************************
Step 1. Screen = 3540
   ShipmentID   (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cTest NVARCHAR(20)
      DECLARE @cTime DATETIME = '00:00:00'
      DECLARE @nSecond INT

      -- Screen mapping
      SET @cTest = @cTestData

      IF @cTest LIKE 'DELAY%'
      BEGIN
         SET @nSecond = SUBSTRING(@cTest,LEN('DELAY')+1,len(@cTest))

         SET @cTime = DATEADD(ss, @nSecond,@cTime)

         WAITFOR DELAY @cTime
      END

      SET @cTestData = ''

      SET @nCounter = @nCounter +1

      SET @cOutField02 = @nCounter

     
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''

      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep


      -- Reset any carton no scanned
      UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
         V_String3 = ''
      WHERE Mobile = @nMobile
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
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,
      -- UserName   = @cUserName,
      Printer    = @cPrinter,

      V_ReceiptKey = @cReceiptKey,
      V_POKey      = @cPOKey,
      V_Loc        = @cToLOC,
      V_SKU        = @cSKU,
      V_UOM        = @cUOM,
      V_ID         = @cID,
      V_SKUDescr   = @cSKUDesc,

      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @cLottable04,
      V_Lottable05 = @cLottable05,

      V_Max        = @cTestData,

      V_String1    = @cShipmentID,
      V_String2    = @cExtendedInfoSP,
      V_String3    = @cCartonNo,

      V_Integer1   = @nCounter,

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
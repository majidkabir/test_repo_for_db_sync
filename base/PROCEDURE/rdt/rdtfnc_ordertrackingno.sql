SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_OrderTrackingNo                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Change tracking no in order                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2014-02-14 1.0  Ung      SOS303065 Created                           */
/* 2016-09-30 1.1  Ung      Performance tuning                          */
/* 2017-09-28 1.2  TLTING   call new Assign tracking no                 */
/* 2018-11-07 1.3  Gan      Performance tuning                          */
/************************************************************************/
CREATE PROC [RDT].[rdtfnc_OrderTrackingNo] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @b_Success     INT,
   @nTotalCarton  INT,
   @nScanCarton   INT,
   @cSQL          NVARCHAR(1000),
   @cSQLParam     NVARCHAR(1000)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR(15),
   @cFacility   NVARCHAR(5),
   @cUserName   NVARCHAR(18),
   @cPrinter    NVARCHAR(10),

   @cOrderKey     NVARCHAR(10),
   @nTotalTrackNo INT,

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

   @cOrderKey     = V_OrderKey,
   
   @nTotalTrackNo = V_Integer1,
  -- @nTotalTrackNo = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY,  5), 0) = 1 THEN LEFT( V_QTY,  5) ELSE 0 END,

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

   @cFieldAttr01 = FieldAttr01,     @cFieldAttr02   = FieldAttr02,
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
IF @nFunc = 548
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 548
   IF @nStep = 1 GOTO Step_1   -- Scn = 3750. OrderKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 3751. TrackingNo, Old, New total trackingno
   IF @nStep = 3 GOTO Step_3   -- Scn = 3752. Message. Tracking
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3750
   SET @nStep = 1

   -- Get storer configure
   -- SET @cCheckPackDetailDropID = rdt.RDTGetConfig( @nFunc, 'CheckPackDetailDropID', @cStorerKey)

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Prep next screen var
   SET @cOutField01 = '' -- OrderKey
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 3750
   ORDERKEY  (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOrderKey = @cInField01

      DECLARE @cChkOrderKey NVARCHAR(10)
      DECLARE @cChkStatus   NVARCHAR(10)
      DECLARE @cChkSOStatus NVARCHAR(10)

      SET @cChkOrderKey = ''
      SET @cChkStatus   = ''
      SET @cChkSOStatus = ''
      SET @nTotalTrackNo = 0

      -- Get Order info
      SELECT
         @cChkOrderKey = OrderKey,
         @cChkStatus   = Status,
         @cChkSOStatus = SOStatus,
         @nTotalTrackNo = ISNULL(ContainerQty, 0)
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Check OrderKey valid
      IF @cChkOrderKey = ''
      BEGIN
         SET @nErrNo = 85201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
         GOTO Step_1_Fail
      END

      -- Check order shipped
      IF @cChkStatus = '9'
      BEGIN
         SET @nErrNo = 85202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order shipped
         GOTO Step_1_Fail
      END

      -- Check order cancel
      IF @cChkStatus = 'CANC'
      BEGIN
         SET @nErrNo = 85203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order cancel
         GOTO Step_1_Fail
      END

      -- Check order status
      IF @cChkSOStatus IN ('HOLD','PENDCANC','PENDGET','PENDPACK')
      BEGIN
         SET @nErrNo = 85204
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadOrderStatus
         GOTO Step_1_Fail
      END

      DECLARE @nRowRef INT
      DECLARE @cTrackNo1 NVARCHAR(20)
      DECLARE @cTrackNo2 NVARCHAR(20)
      DECLARE @cTrackNo3 NVARCHAR(20)
      SET @nRowRef = 0
      SET @cTrackNo1 = ''
      SET @cTrackNo2 = ''
      SET @cTrackNo3 = ''

      -- Get tracking no
      SELECT TOP 1 @cTrackNo1 = TrackingNo, @nRowRef = RowRef FROM dbo.CartonTrack WITH (NOLOCK) WHERE LabelNo = @cOrderKey AND RowRef > @nRowRef ORDER BY RowRef
      SELECT TOP 1 @cTrackNo2 = TrackingNo, @nRowRef = RowRef FROM dbo.CartonTrack WITH (NOLOCK) WHERE LabelNo = @cOrderKey AND RowRef > @nRowRef ORDER BY RowRef
      SELECT TOP 1 @cTrackNo3 = TrackingNo, @nRowRef = RowRef FROM dbo.CartonTrack WITH (NOLOCK) WHERE LabelNo = @cOrderKey AND RowRef > @nRowRef ORDER BY RowRef

      -- Prep next screen var
      SET @cOutField01 = @cOrderKey
      SET @cOutField02 = @cTrackNo1
      SET @cOutField03 = @cTrackNo2
      SET @cOutField04 = @cTrackNo3
      SET @cOutField05 = CAST( @nTotalTrackNo AS NVARCHAR( 5))
      SET @cOutField06 = '' -- New total

      -- Go to next screen
      SET @nScn  = @nScn + 1
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
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOrderKey = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen 3751
   OrderKey  (Field01)
   TrackNo1  (Field02)
   TrackNo2  (Field03)
   TrackNo3  (Field04)
   Old total (Field05)
   New total (Field06, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @bSuccess INT
      DECLARE @cTransmitLogKey NVARCHAR(10)
      DECLARE @cShipperKey NVARCHAR(15)
      DECLARE @cUDF04 NVARCHAR(60)
      DECLARE @cQTY CHAR( 10)
      DECLARE @nQTY INT
      DECLARE @nRow INT
      DECLARE @i INT

      SET @bSuccess = 0
      SET @cShipperKey = ''
      SET @cUDF04 = ''

      -- Screen mapping
      SET @cQTY = @cInField06

      -- Check QTY
      IF rdt.rdtIsValidQty( @cQTY, 1) = 0 -- check for zero. false
      BEGIN
         SET @nErrNo = 85205
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Quit
      END
      SET @nQTY = CAST( @cQTY AS INT)

      -- Check total tracking no changed
      IF (SELECT COUNT(1) FROM CartonTrack WITH (NOLOCK) WHERE LabelNo = @cOrderKey) <> @nTotalTrackNo
      BEGIN
         SET @nErrNo = 85206
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNoChanged
         GOTO Quit
      END

      -- Check total tracking no changed
      IF (SELECT ISNULL( ContainerQTY, 0) FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey) <> @nTotalTrackNo
      BEGIN
         SET @nErrNo = 85207
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNoChanged
         GOTO Quit
      END

      -- Check QTY
      IF @nTotalTrackNo = @nQTY
      BEGIN
         SET @nErrNo = 85208
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Same QTY
         GOTO Quit
      END

      -- Get OrderInfo
      SELECT @cShipperKey = ShipperKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      IF @cShipperKey = ''
      BEGIN
         SET @nErrNo = 85209
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Shipper NotSet
         GOTO Quit
      END

      -- Get tracking no method
      SELECT @cUDF04 = UDF04 FROM dbo.CodeLkUp
      WHERE ListName = 'WSCourier'
         AND Short = @cShipperKey
         AND StorerKey = @cStorerKey
      IF @cUDF04 = ''
      BEGIN
         SET @nErrNo = 85210
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetMethodNoSet
         GOTO Quit
      END

      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_OrderTrackingNo -- For rollback or commit only our own transaction

      SET @bSuccess = 0 -- False

      -- Order have excess tracking no
      IF @nTotalTrackNo > @nQTY
      BEGIN
         SET @nRow = @nTotalTrackNo - @nQTY
         SET @i = 0
         
         WHILE @i < @nRow
         BEGIN
            -- Get tracking no
            SELECT TOP 1 @nRowRef = RowRef
            FROM CartonTrack
            WHERE LabelNo = @cOrderKey
            ORDER BY TrackingNo DESC
            
            -- Delete tracking no
            DELETE CartonTrack WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 85211
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL CtnTrkFail
               GOTO RollbackTran
            END
            SET @i = @i + 1
         END

         -- Update total tracking no
         UPDATE Orders SET
            ContainerQTY = @nQTY, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE OrderKey = @cOrderKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 85212
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Order Fail
            GOTO RollbackTran
         END

         IF @cUDF04 = 'O' -- Online
         BEGIN
            SELECT @b_success = 1  
            EXECUTE nspg_getkey  
               'TransmitlogKey3'  
               , 10  
               , @cTransmitLogKey OUTPUT  
               , @bSuccess        OUTPUT  
               , @nErrNo          OUTPUT  
               , @cErrMsg         OUTPUT
            IF @bSuccess <> 1      
            BEGIN      
               SET @nErrNo = 85213
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail       
               GOTO RollbackTran      
            END    
        
            -- Not using generic ispGenTransmitLog3, due to duplicate record
            INSERT INTO Transmitlog3 (TransmitLogKey, TableName, Key1, Key2, Key3, TransmitFlag, TransmitBatch)  
            VALUES (@cTransmitLogKey, 'WSCRIDREQ', @cOrderKey, @nTotalTrackNo, @cStorerkey, '0', '')  
            IF @@ERROR <> 0
            BEGIN      
               SET @nErrNo = 85214
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TR3 Fail       
               GOTO RollbackTran      
            END    
         END

         SET @bSuccess = 1
      END

      -- Order need extra tracking no
      IF @nTotalTrackNo < @nQTY
      BEGIN
         SET @nRow = @nQTY - @nTotalTrackNo

         -- Update total tracking no
         UPDATE Orders SET
            ContainerQTY = @nQTY, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE OrderKey = @cOrderKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 85215
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Order Fail
            GOTO RollbackTran
         END

         -- Get track no thru online method (IML)
         IF @cUDF04 = 'O' -- Online
         BEGIN
            SELECT @b_success = 1  
            EXECUTE nspg_getkey  
               'TransmitlogKey3'  
               , 10  
               , @cTransmitLogKey OUTPUT  
               , @bSuccess        OUTPUT  
               , @nErrNo          OUTPUT  
               , @cErrMsg         OUTPUT
            IF @bSuccess <> 1      
            BEGIN      
               SET @nErrNo = 85216
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail       
               GOTO RollbackTran      
            END    
        
            -- Not using generic ispGenTransmitLog3, due to duplicate record
            INSERT INTO Transmitlog3 (TransmitLogKey, TableName, Key1, Key2, Key3, TransmitFlag, TransmitBatch)  
            VALUES (@cTransmitLogKey, 'WSCRIDREQ', @cOrderKey, @nTotalTrackNo, @cStorerkey, '0', '')  
            IF @@ERROR <> 0
            BEGIN      
               SET @nErrNo = 85217
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TR3 Fail       
               GOTO RollbackTran      
            END    

            SET @bSuccess = 1
         END

         -- Get track no thru batch method (pre-generated)
         IF @cUDF04 <> 'O' -- not online
         BEGIN

            -- Auto get tracking no, base on Orders.ContainerQTY
            EXEC ispAsgnTNo2
                 @cOrderKey
               , '' -- LoadKey
               , @bSuccess OUTPUT
               , @nErrNo   OUTPUT
               , @cErrMsg  OUTPUT
            IF @bSuccess = 0 OR @nErrNo <> 0
               GOTO RollbackTran
            SET @bSuccess = 1
         END
      END

      IF @bSuccess = 1
         COMMIT TRAN rdtfnc_OrderTrackingNo -- Only commit change made here
      ELSE
      BEGIN
         RollbackTran:
         ROLLBACK TRAN rdtfnc_OrderTrackingNo -- Only rollback change made here
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '4', -- Move
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @cOrderKey   = @cOrderKey,
         @cRefNo1     = @nTotalTrackNo, 
         @nQTY        = @nQTY,
         --@cRefNo2     = @nQTY
         @nStep       = @nStep

      -- Go to message screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- OrderKey

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen = 3752
   TRACK NO UPDATED
   PRESS ENTER OR ESC
********************************************************************************/
Step_3:
BEGIN
   -- Prepare prev screen var
   SET @cOutField01 = '' --OrderKey
   
   -- Go to Order screen
   SET @nScn  = @nScn - 2
   SET @nStep = @nStep - 2
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

      V_OrderKey = @cOrderKey,
      --V_QTY      = @nTotalTrackNo, 
      
      V_Integer1 = @nTotalTrackNo,

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
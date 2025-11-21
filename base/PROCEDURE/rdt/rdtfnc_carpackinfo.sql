SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_CarPackInfo                                  */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Serial no capture by ext orderkey + sku                     */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 26-08-2020  1.0  Chermaine  WMS-14658 Created                        */
/* 08-04-2021  1.1  James      WMS-16024 Standarized use of TrackingNo  */
/*                             (james02)                                */
/* 20-04-2021  1.2  Chermaine  WMS-16798 Add screen (cc01)              */
/* 25-06-2021  1.3  Chermaine  WMS-17147 Add PalletID in step5          */
/*                             Add Op3 in st1 and Add scn6(cc02)        */
/* 10-11-2022  1.4  Ung        WMS-21153 Add check Orders.Status = 9    */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_CarPackInfo] (
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
   @nRowRef     INT,
   @cSQL        NVARCHAR( MAX),
   @cSQLParam   NVARCHAR( MAX)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @nFrStep       INT,
   @nFrSCN        INT,
   @cLangCode     NVARCHAR( 3),
   @cUserName     NVARCHAR( 10),
   @cPaperPrinter NVARCHAR( 10),
   @cPrinter      NVARCHAR( 10),
   @cDestination  NVARCHAR( 20),
   @cTruckNo      NVARCHAR( 10),
   @cTrackingNo   NVARCHAR( 20),
   @cMbolKey      NVARCHAR( 10),
   @cCartonType   NVARCHAR( 10),
   @cOrderKey     NVARCHAR( 10),
   @cPalletID     NVARCHAR( 20),
   @cOption       NVARCHAR(1),
   @cMenuOption   NVARCHAR(1),
   @nQty          INT,
   @nInputKey     INT,
   @nMenu         INT,
   @nQtyOrder     INT,
   @b_Success     INT,
   @bSuccess      INT,
   @fCartonWeight FLOAT,
   @fCube         FLOAT,
   @fSKUWeight    FLOAT,
   @cPickSlipNo   NVARCHAR(10),
   @cCountOnSFPallet    NVARCHAR(5),
   @cCountOnReturn      NVARCHAR(5),

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),

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
   @nFunc         = Func,
   @nScn          = Scn,
   @nStep         = Step,
   @nInputKey     = InputKey,
   @nMenu         = Menu,
   @cLangCode     = Lang_code,
   @cUserName     = UserName,

   @cStorerKey    = StorerKey,
   @cFacility     = Facility,
   @cPaperPrinter = Printer_Paper,
   @cPrinter      = Printer,

   @cDestination  = V_String1,
   @cTruckNo      = V_String2,
   @cTrackingNo   = V_String3,
   @cOrderKey     = V_String4,
   @cMbolKey      = V_String5,
   @cTrackingNo   = V_String6,
   @cCartonType   = V_String7,
   @cPalletID     = V_String8,
   @cMenuOption   = V_String9,

   @nQty          = V_Integer1,
   @nFrStep       = V_Integer2,
   @nFrSCN        = V_Integer3,

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

IF @nFunc = 1847 -- Pick Job capture
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = 1847
   IF @nStep = 1 GOTO Step_1   -- 5830 SL/LF Option
   IF @nStep = 2 GOTO Step_2   -- 5831 LF_PreSale_Destination
   IF @nStep = 3 GOTO Step_3   -- 5832 LF_PreSale_Tracking
   IF @nStep = 4 GOTO Step_4   -- 5833 Coninue?
   IF @nStep = 5 GOTO Step_5   -- 5834 SF_PreSale_Tracking
   IF @nStep = 6 GOTO Step_6   -- 5835 SF_Return
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1847. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 5830
   SET @nStep = 1
   SET @nQty = 0

   -- Prepare next screen var
   SET @cOutField01 = '' -- Destination
   SET @cOutField02 = '' -- TruckNo
   EXEC rdt.rdtSetFocusField @nMobile, 1    --Destination

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

END
GOTO Quit

/********************************************************************************
Step 1. Scn = 5830. SL/LF Option
   Option   (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cMenuOption = @cInField01

      -- Check blank
      IF @cMenuOption = ''
      BEGIN
         SET @nErrNo = 157711
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req
         GOTO Quit
      END

      -- Check option valid
      IF @cMenuOption NOT IN ('1', '2','3')
      BEGIN
         SET @nErrNo = 157712
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
         GOTO Quit
      END

     EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to SF_preSales
      IF @cMenuOption = '1'
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''

         SET @nScn  = @nScn + 4
         SET @nStep = @nStep + 4

         GOTO Quit
      END

      -- Go to LF_preSales
      IF @cMenuOption = '2' -- NO
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      -- Go to SF_Return
      IF @cMenuOption = '3' -- NO
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''

         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5

         GOTO Quit
      END
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
Step 2. Screen = 5831  LF_PreSale_Destination
   Destination  (Field01, input)
   TruckNo      (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDestination = @cInField01
      SET @cTruckNo = @cInField02

      -- Check blank
      IF @cDestination = ''
      BEGIN
         SET @nErrNo = 157701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DestinationReq
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- destination
         GOTO Quit
      END

      -- Check blank
      IF @cTruckNo = ''
      BEGIN
         SET @nErrNo = 157702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedVehicleNo
         SET @cOutField01 = @cDestination
         EXEC rdt.rdtSetFocusField @nMobile, 2  -- TruckNo
         GOTO Quit
      END

      -- Prep next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --back to step 1
      SET @cOutField01 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit


/********************************************************************************
Step 3. Screen = 5832  LF_PreSale_Tracking
   TrackingNo  (Field01,input)
   MBOLKey     (Field02,input)
   Total Qty   (Field03 )
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN

      -- Screen mapping
      SET @cTrackingNo = @cInField01
      SET @cMbolKey = @cInField02

      -- Check blank
      IF @cTrackingNo = '' AND @cMbolKey = ''
      BEGIN
         SET @nErrNo = 157703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Key Either One
         GOTO Quit
      END

      -- Check blank
      IF @cTrackingNo <> '' AND @cMbolKey <> ''
      BEGIN
         SET @nErrNo = 157708
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Key Either One
         GOTO Quit
      END

      IF @cTrackingNo <> ''
      BEGIN
       IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.ORDERS WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey)
         BEGIN
          SET @nErrNo = 157704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidTrackNo
            GOTO Quit
         END


         SELECT @nQtyOrder = COUNT(orderKey) FROM dbo.ORDERS WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey
         SELECT @cOrderKey = orderKey FROM dbo.ORDERS WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey

         IF NOT EXISTS (SELECT TOP 1 1 FROM rdt.rdtTruckPackInfo WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey)
         BEGIN
            INSERT INTO rdt.rdtTruckPackInfo (storerKey, Facility, Destination, VehicleNum, OrderKey, TrackingNo, QTY, AddDate, AddWho, Editdate, EditWho, CartonType, Type)
            VALUES(@cStorerKey, @cFacility, @cDestination, @cTruckNo, @cOrderKey, @cTrackingNo, 0, GETDATE(), SUSER_SNAME(), GETDATE(), SUSER_SNAME(), '', '2')

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 157705
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Fail
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 157721
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- TrackNo Exists
            GOTO Quit
         END
      END

      IF @cMbolKey <> ''
      BEGIN
       IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.ORDERS WITH (NOLOCK) WHERE mbolkey = @cMbolKey AND storerKey = @cStorerKey)
         BEGIN
          SET @nErrNo = 157709
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IvalidMbolKey
            GOTO Quit
         END

         SELECT @nQtyOrder = COUNT(orderKey) FROM dbo.ORDERS WITH (NOLOCK) WHERE MBOLKey = @cMbolKey AND storerKey = @cStorerKey

         SELECT
            @cOrderKey = O.orderKey,
            @cTrackingNo = O.TrackingNo
         FROM ORDERS O WITH (NOLOCK)
         JOIN MBOL M WITH (NOLOCK) ON (O.MBOLKey = M.MbolKey)
         WHERE storerKey = @cStorerKey
         AND M.MbolKey = @cMbolKey

         IF NOT EXISTS (SELECT TOP 1 1 FROM rdt.rdtTruckPackInfo WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey)
         BEGIN
            INSERT INTO rdt.rdtTruckPackInfo (storerKey, Facility, Destination, VehicleNum, OrderKey, TrackingNo, QTY, AddDate, AddWho, Editdate, EditWho, CartonType, Type)
            VALUES (@cStorerKey, @cFacility, @cDestination, @cTruckNo, @cOrderKey, @cTrackingNo, 0, GETDATE(), SUSER_SNAME(), GETDATE(), SUSER_SNAME(), '', '2' )

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 157710
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Fail
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 157722
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- TrackNo Exists
            GOTO Quit
         END
      END

      SET @nQty = @nQty + @nQtyOrder

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = @nQty
   END


   IF @nInputKey = 0 -- ESC
   BEGIN
      --go to continue screen
      SET @cOutField01 = ''

      SET @nFrStep = @nStep
      SET @nFrScn = @nScn
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 5833. Continue?
   Option       (field01, input)
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
         SET @nErrNo = 157706
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 157707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
         GOTO Quit
      END

      IF @cOption = '2' -- No
      BEGIN
         IF @cMenuOption IN ('1') --SF_PreSales-print handover report
         BEGIN
            DECLARE @tPrintLabelParam1 AS VariableTable
            INSERT INTO @tPrintLabelParam1 (Variable, Value) VALUES
                ( '@cPalletID',     @cPalletID)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPrinter, @cPaperPrinter,
               'ShipHO', -- Report type
               @tPrintLabelParam1,  -- Report params
               'rdtfnc_CarPackInfo',
               @nErrNo  OUTPUT,
               @cErrMsg  OUTPUT


            IF @nErrNo <> 0
               GOTO Quit

         END
         ELSE IF @cMenuOption IN ('3') --SF_return --print handover report
         BEGIN
            DECLARE @tPrintLabelParam3 AS VariableTable
            INSERT INTO @tPrintLabelParam3 (Variable, Value) VALUES
                ( '@cPalletID',     @cPalletID)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPrinter, @cPaperPrinter,
               'RtnShipHO', -- Report type
               @tPrintLabelParam3,  -- Report params
               'rdtfnc_CarPackInfo',
               @nErrNo  OUTPUT,
               @cErrMsg  OUTPUT


            IF @nErrNo <> 0
               GOTO Quit
         END

         -- back to 1st screen
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @nQty = 0

         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3

         GOTO Quit
      END

      IF @cOption = '1' -- YES
      BEGIN
         SET @cOutField01 = ''

         IF @nFrScn = 3
         BEGIN
         SET @cOutField02 = @nQty
         END
         ELSE
         BEGIN
         SET @cOutField02 = ''
         END

         SET @nScn = @nFrScn
         SET @nStep = @nFrStep

         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
    SET @nQty = 0
    EXEC rdt.rdtSetFocusField @nMobile, 1  -- destination
      --back to ucc screen
      SET @cOutField01 = ''
      IF @nFrScn = 3
      BEGIN
       SET @cOutField02 = @nQty
      END
      ELSE
      BEGIN
       SET @cOutField02 = ''
      END

      SET @nScn = @nFrScn
      SET @nStep = @nFrStep
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 5. Screen = 5834  SF_PreSale_Tracking
   PalletID    (Field01,input)
   CartonType  (Field02,input)
   TrackingNo  (Field03,input)
   Count       (Field04)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletID   = @cInField01
      SET @cCartonType = @cInField02
      SET @cTrackingNo = @cInField03

      -- Check blank
      IF @cPalletID = ''
      BEGIN
         SET @nErrNo = 157723
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletID Req
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- PalletID
         GOTO Step_5_Fail
      END

      -- Check blank
      IF @cCartonType = ''
      BEGIN
         SET @nErrNo = 157714
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonType Req
         EXEC rdt.rdtSetFocusField @nMobile, 2  -- CartonType
         GOTO Step_5_Fail
      END

      -- Check blank
      IF @cTrackingNo = ''
      BEGIN
         SET @nErrNo = 157713
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackingNo Req
         EXEC rdt.rdtSetFocusField @nMobile, 3  -- TrackingNo
         GOTO Step_5_Fail
      END

      IF @cTrackingNo <> ''
      BEGIN
         IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.ORDERS WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 157715
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidTrackNo
            GOTO Quit
         END

         IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.orders WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey AND BizUnit = 'PSF')
         BEGIN
            SET @nErrNo = 157716
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No SF_PreSales
            GOTO Quit
         END


         SELECT @cOrderKey = orderKey FROM dbo.ORDERS WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey
      END

      IF @cCartonType <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1
                        FROM packHeader PH WITH (NOLOCK)
                        JOIN dbo.CARTONIZATION C WITH (NOLOCK) ON (C.CartonizationGroup  = PH.CartonGroup)
                        WHERE StorerKey = @cStorerKey
                        AND OrderKey = @cOrderKey
                      AND C.CartonType = @cCartonType)
         BEGIN
            SET @nErrNo = 157717
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCtnType
            GOTO Step_5_Fail
         END
      END

      IF NOT EXISTS (SELECT TOP 1 1 FROM rdt.rdtTruckPackInfo WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey )
      BEGIN
         INSERT INTO rdt.rdtTruckPackInfo (storerKey, Facility, Destination, VehicleNum, OrderKey, TrackingNo,QTY, AddDate, AddWho, Editdate, EditWho, CartonType, TYPE, PalletID)
         VALUES(@cStorerKey, @cFacility, @cDestination, @cTruckNo, @cOrderKey, @cTrackingNo, 0, GETDATE(), SUSER_SNAME(), GETDATE(), SUSER_SNAME(), @cCartonType, '1', @cPalletID)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 157718
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Fail
            GOTO Step_5_Fail
         END

         -- Insert transmitlog2 here
         EXECUTE ispGenTransmitLog2
            @c_TableName      = 'WSCRSOCFMSF',
            @c_Key1           = @cOrderKey,
            @c_Key2           = '5',
            @c_Key3           = @cStorerkey,
            @c_TransmitBatch  = '',
            @b_Success        = @bSuccess   OUTPUT,
            @n_err            = @nErrNo     OUTPUT,
            @c_errmsg         = @cErrMsg    OUTPUT

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 157719
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins TL2 Err
            GOTO Step_5_Fail
         END

         --(cc02)
         SELECT
            @fCartonWeight = C.CartonWeight,
            @fCube = C.cube,
            @cPickSlipNo = PH.PickSlipNo
         FROM packHeader PH WITH (NOLOCK)
         JOIN dbo.CARTONIZATION C WITH (NOLOCK) ON (C.CartonizationGroup  = PH.CartonGroup)
         WHERE StorerKey = @cStorerKey
         AND PH.OrderKey = @cOrderKey
         AND C.CartonType = @cCartonType

         SELECT
            @fSKUWeight  = SUM(PD.QTY)*S.STDGROSSWGT
         FROM pickDetail PD WITH (NOLOCK)
         JOIN sku S WITH (NOLOCK) ON (PD.SKU = S.SKU AND PD.Storerkey = S.StorerKey)
         WHERE PD.OrderKey = @cOrderKey
         AND PD.StorerKey = @cStorerKey
         GROUP BY S.STDGROSSWGT

         SELECT
            @cCountOnSFPallet = COUNT(DISTINCT trackingNo)
         FROM rdt.rdtTruckPackInfo (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND PalletID = @cPalletID

         UPDATE PackInfo WITH (ROWLOCK) SET
            WEIGHT = @fCartonWeight + @fSKUWeight,
            CUBE = @fCube
         WHERE PickslipNo = @cPickSlipNo

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 157724
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Fail
            GOTO Step_5_Fail
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 157720
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNo Exists
         GOTO Quit
      END


      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cCartonType
      SET @cOutField03 = ''
      SET @cOutField04 = @cCountOnSFPallet
      EXEC rdt.rdtSetFocusField @nMobile, 3  -- TrackingNo

      GOTO Quit
   END


   IF @nInputKey = 0 -- ESC
   BEGIN
      --go to Continue? screen
      SET @cOutField01 = ''

      SET @nFrStep = @nStep
      SET @nFrScn = @nScn
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      GOTO Quit
   END


   Step_5_Fail:
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cCartonType
      SET @cOutField03 = @cTrackingNo
      SET @cOutField04 = @cCountOnSFPallet

END
GOTO Quit

/********************************************************************************
Step 6. Screen = 5835  SF_Return
   PalletID    (Field01,input)
   TrackingNo  (Field02,input)
   Count       (Field03)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletID   = @cInField01
      SET @cTrackingNo = @cInField02

      -- Check blank
      IF @cPalletID = ''
      BEGIN
         SET @nErrNo = 157725
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletID Req
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- PalletID
         GOTO Step_6_Fail
      END

      -- Check blank
      IF @cTrackingNo = ''
      BEGIN
         SET @nErrNo = 157726
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackingNo Req
         EXEC rdt.rdtSetFocusField @nMobile, 2  -- TrackingNo
         GOTO Step_6_Fail
      END

      IF @cTrackingNo <> ''
      BEGIN
         IF NOT EXISTS (SELECT TOP 1 1 FROM rdt.rdtTruckPackInfo WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 157727
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Pre Del
            GOTO Quit
         END
         ELSE
         BEGIN
            SELECT @cOrderKey = OrderKey FROM rdt.rdtTruckPackInfo WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey

            -- Get order info
            DECLARE @cStatus NVARCHAR( 10)
            SELECT @cStatus = Status FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

            -- Check order shipped
            IF @cStatus = '9'
            BEGIN
               SET @nErrNo = 157730
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Shipped
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               GOTO Quit
            END

            IF EXISTS (SELECT TOP 1 1 FROM rdt.rdtTruckPackInfo WITH (NOLOCK) WHERE TrackingNo = @cTrackingNo AND storerKey = @cStorerKey AND ReturnPalletID = @cPalletID )
            BEGIN
               SET @nErrNo = 157729
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNo Exists
               GOTO Quit
            END

            UPDATE rdt.rdtTruckPackInfo WITH (ROWLOCK) SET
               ReturnPalletID = @cPalletID,
               IsReturn = 'Y',
               EditWho = SUSER_SNAME(),
               Editdate = GETDATE()
            WHERE StorerKey = @cStorerKey
            AND TrackingNo = @cTrackingNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 157728
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Fail
               GOTO Quit
            END
         END
      END

      SELECT
         @cCountOnReturn = COUNT(DISTINCT trackingNo)
      FROM rdt.rdtTruckPackInfo (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ReturnPalletID = @cPalletID


      SET @cOutField01 = @cPalletID
      SET @cOutField02 = ''
      SET @cOutField03 = @cCountOnReturn
      EXEC rdt.rdtSetFocusField @nMobile, 2  -- TrackingNo

      GOTO Quit
   END


   IF @nInputKey = 0 -- ESC
   BEGIN
      --go to Continue? screen
      SET @cOutField01 = ''

      SET @nFrStep = @nStep
      SET @nFrScn = @nScn
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

      GOTO Quit

   END

   Step_6_Fail:
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cTrackingNo
      SET @cOutField03 = @cCountOnSFPallet

END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg   = @cErrMsg,
      Func     = @nFunc,
      Step     = @nStep,
      Scn      = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      Printer_Paper  = @cPaperPrinter,
      Printer   = @cPrinter,

      V_String1 = @cDestination,
      V_String2 = @cTruckNo,
      V_String3 = @cTrackingNo,
      V_String4 = @cOrderKey,
      V_String5 = @cMbolKey,
      V_String6 = @cTrackingNo,
      V_String7 = @cCartonType,
      V_String8 = @cPalletID,
      V_String9 = @cMenuOption,

      V_Integer1 = @nQty,
      V_Integer2 = @nFrStep,
      V_Integer3 = @nFrScn,

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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_ScanToTruck_POD                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Reset Scan To Truck                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2013-09-13 1.0  ChewKP   SOS#285903 Created                          */
/* 2016-09-30 1.1  Ung      Performance tuning                          */
/* 2018-11-14 1.2  TungGH   Performance                                 */
/************************************************************************/
CREATE PROC [RDT].[rdtfnc_ScanToTruck_POD] (
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
   @nTranCount    INT,
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

   @cLoadKey    NVARCHAR(10),
   @cOrderKey   NVARCHAR(10),
   @cMBOLKey    NVARCHAR(10),
   @cType       NVARCHAR( 1), 
   @cOption     NVARCHAR( 1),
   @cDoor       NVARCHAR(10),
   @cTruckNo    NVARCHAR(18),  
   @cTransporter NVARCHAR(20),
   @cExtendedUpdateSP NVARCHAR(20),
   @cByPassMBOLValidation NVARCHAR(1),
   

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

   @cLoadKey    = V_LoadKey,
   @cOrderKey   = V_OrderKey,
   

   @cMBOLKey    = V_String1,
   @cType       = V_String2, 
   @cDoor       = V_string3,
   @cTruckNo    = V_string4,
   @cTransporter = V_string5,
   
   
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
IF @nFunc = 924
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 924
   IF @nStep = 1 GOTO Step_1   -- Scn = 3660. MBOLKey, LoadKey, OrderKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 3661. Door
   IF @nStep = 3 GOTO Step_3   -- Scn = 3662. TruckNo
   IF @nStep = 4 GOTO Step_4   -- Scn = 3663. Transporter
   
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3660
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

   -- Prep next screen var
   SET @cOutField01 = '' -- MBOLKey
   SET @cOutField02 = '' -- LoadKey
   SET @cOutField03 = '' -- OrderKey
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 3660
   MBOLKEY   (Field01, input)
   LOADKEY   (Field02, input)
   ORDERKEY  (Field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cMBOLKey = @cInField01
      SET @cLoadKey = @cInField02
      SET @cOrderKey = @cInField03

      -- Check blank
      IF @cMBOLKey = '' AND @cLoadKey = '' AND @cOrderKey = ''
      BEGIN
         SET @nErrNo = 82701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Key either one
         GOTO Step_1_Fail
      END

      -- Get no field keyed-in
      DECLARE @i INT
      SELECT @i = 0, @cType = ''
      IF @cMBOLKey  <> '' SELECT @i = @i + 1, @cType = 'M'
      IF @cLoadKey  <> '' SELECT @i = @i + 1, @cType = 'L'
      IF @cOrderKey <> '' SELECT @i = @i + 1, @cType = 'O'

      IF @i = 0
      BEGIN
         SET @nErrNo = 82702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value needed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF @i > 1
      BEGIN
         SET @nErrNo = 82703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL/LOAD/ORD
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      DECLARE @cChkMBOLStatus NVARCHAR(10)
      SET @cChkMBOLStatus = ''

      -- MBOL
      IF @cType = 'M'
      BEGIN
         -- Check MBOL valid
         IF NOT EXISTS( SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey)
         BEGIN
            SET @nErrNo = 82704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad MBOLKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- MBOLKey
            GOTO Step_1_Fail
         END
      END

      -- Load
      IF @cType = 'L'
      BEGIN
         -- Check LoadKey valid
         IF NOT EXISTS( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
         BEGIN
            SET @nErrNo = 82705
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- LoadKey
            GOTO Step_1_Fail
         END
         
         -- Get MBOL info
         SET @cMBOLKey = ''
         SELECT TOP 1 @cMBOLKey = MD.MBOLKey
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON (LPD.OrderKey = MD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey
         
         -- Check populated to MBOL 
         IF @cMBOLKey = ''
         BEGIN
            SET @nErrNo = 82706
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Load Not MBOL
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- OrderKey
            GOTO Step_1_Fail
         END
      END

      -- Order
      IF @cType = 'O'
      BEGIN
         -- Check OrderKey valid
         IF NOT EXISTS( SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
         BEGIN
            SET @nErrNo = 82707
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- OrderKey
            GOTO Step_1_Fail
         END
         
         -- Get Load info
         SET @cLoadKey = ''
         SELECT TOP 1 @cLoadKey = LoadKey FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         -- Check populated to Load
         IF @cLoadKey = ''
         BEGIN
            SET @nErrNo = 82708
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNotYetLP
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- OrderKey
            GOTO Step_1_Fail
         END
         
         -- Get MBOL info
         SET @cMBOLKey = ''
         SELECT TOP 1 @cMBOLKey = MBOLKey FROM dbo.MBOLDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
         
         -- Check populated to MBOL 
         IF @cMBOLKey = ''
         BEGIN
            SET @nErrNo = 82709
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Not MBOL
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- OrderKey
            GOTO Step_1_Fail
         END

         -- Check order cancel
         IF EXISTS( SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND SOStatus = 'CANC')
         BEGIN
            SET @nErrNo = 82710
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- OrderKey
            GOTO Step_1_Fail
         END
      END

      -- Get MBOL info
      SELECT @cChkMBOLStatus = [Status] FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey
      
      
      SET @cByPassMBOLValidation = ''
      SET @cByPassMBOLValidation = rdt.RDTGetConfig( @nFunc, 'ByPassMBOLValidation', @cStorerKey) -- Parse in Function

      IF @cByPassMBOLValidation <> '1'
      BEGIN 
         IF @cChkMBOLStatus = '9'
         BEGIN    
            SET @nErrNo = 82711    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Mbol Shipped    
            GOTO Step_1_Fail    
         END
      END      
      



      -- Prep next screen var
      SET @cOutField01 = ''
     

      
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
      SET @cMBOLKey = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen 3661
   Door         (Field01, input)
   Truck No     (Field02, input)
   Transporter  (Field03, input)
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDoor        = ISNULL(@cInField01,'') 
      
      -- Check label
      IF @cDoor = ''
      BEGIN
         SET @nErrNo = 82712
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Door Req
         GOTO Step_2_Fail
      END
      
      
      -- Prepare current screen var
      SET @cOutField01 = @cDoor
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      
      -- Go to prev screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
      
      
      
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     
      -- Prepare prev screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      --IF @cMBOLKey  = 'M' EXEC rdt.rdtSetFocusField @nMobile, 1
      --IF @cLoadKey  = 'L' EXEC rdt.rdtSetFocusField @nMobile, 2
      --IF @cOrderKey = 'O' EXEC rdt.rdtSetFocusField @nMobile, 3

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cDoor = ''
      SET @cOutField01 = ''
      
      
   END
END
GOTO Quit

/********************************************************************************
Step 3. Screen 3662
   Door         (Field01)
   Truck No     (Field02, input)
   
   
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cTruckNo        = ISNULL(@cInField02,'') 
      
      -- Check label
      IF @cTruckNo = ''
      BEGIN
         SET @nErrNo = 82713
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TruckNo Req
         GOTO Step_3_Fail
      END
      
      
      -- Prepare current screen var
      SET @cOutField01 = @cDoor
      SET @cOutField02 = @cTruckNo
      SET @cOutField03 = ''
      
      -- Go to prev screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
      
      
      
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     
      -- Prepare prev screen var
      SET @cOutField01 = @cDoor
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cTruckNo = ''
      SET @cOutField02 = ''
      
      
   END
END
GOTO Quit

/********************************************************************************
Step 4. Screen 3663
   Door         (Field01)
   Truck No     (Field02)
   Transporter  (Field03, input)
   
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cTransporter        = ISNULL(@cInField03,'') 
      
      -- Check label
      IF @cTransporter = ''
      BEGIN
         SET @nErrNo = 82714
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Transporter Req
         GOTO Step_4_Fail
      END
      
      
      -- Extended update Customize SP to update according to User Requirement
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''
      
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cDoor, @cTruckNo, @cTransporter, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' + 
               '@cStorerKey   NVARCHAR( 15), ' + 
               '@cType        NVARCHAR( 1),  ' + 
               '@cMBOLKey     NVARCHAR( 10), ' +
               '@cLoadKey     NVARCHAR( 10), ' +
               '@cOrderKey    NVARCHAR( 10), ' +
               '@cDoor        NVARCHAR( 10), ' +
               '@cTruckNo     NVARCHAR( 18), ' +
               '@cTransporter NVARCHAR( 20), ' +
               '@nErrNo       INT OUTPUT,    ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cDoor, @cTruckNo, @cTransporter, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_4_Fail
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 82716
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExtUpdSPReq
         GOTO Step_4_Fail
      END
      
      
      -- Prepare current screen var
      SET @nErrNo = 82715
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PODCompleted
         
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      
      -- Go to prev screen
      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3
      
      
      
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     
      -- Prepare prev screen var
      SET @cOutField01 = @cDoor
      SET @cOutField02 = @cTruckNo
      SET @cOutField03 = ''

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cTransporter = ''
      SET @cOutField03  = ''
      
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

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,
      -- UserName   = @cUserName,
      Printer    = @cPrinter,
      
      V_LoadKey  = @cLoadKey,
      V_OrderKey = @cOrderKey,

      V_String1  = @cMBOLKey,
      V_String2  = @cType, 
      
      V_string3 =  @cDoor       ,
      V_string4 =  @cTruckNo    ,
      V_string5 =  @cTransporter,
      

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
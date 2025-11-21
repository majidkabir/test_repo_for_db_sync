SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: rdtfnc_TrackNoMBOL_Creation                              */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#206825 - TrackNo MBOL Creation                               */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2011-03-08 1.0  ChewKP   Created                                          */
/* 2011-06-14 1.1  James    SOS218111 - Check SOStatus <> 'HOLD' (james01)   */
/* 2011-05-08 1.2  ChewKP   SOS#222772 - Add Order Weight Screen (ChewKP01)  */
/* 2012-10-23 1.3  ChewKP   SOS#258906 - Additional Validation on SOStatus   */
/*                          (ChewKP02)                                       */
/* 2013-06-10 1.4  ChewKP   SOS#280650 - Capture Carton LabelNo (CheWKP03)   */
/* 2013-11-01 1.5  SPChin   SOS293491 - Bug Fixed                            */
/* 2014-02-26 1.6  ChewKP   SOS#303800 - Additional RDT.StorerConfig         */
/*                          DefaultCartonCount (ChewKP04)                    */
/* 2014-03-31 1.7  James    SOS305334 - Add ExtendedValidateSP (james02)     */
/* 2014-07-03 1.8  ChewKP   SOS#303800 - TraceORderWeight flag by SP         */  
/*                          (ChewKP05)                                       */   
/* 2014-07-23 1.9  ChewKP   SOS#313160 - Add PalletID Input Screen (ChewKP06)*/
/* 2014-09-02 2.0  Ung      SOS319578 Add weight range checking              */
/* 2014-11-14 2.1  James    Clear variable (james03)                         */
/* 2014-12-26 2.2  James    SOS329436 When ctn qty match label scanned then  */
/*                          go back to screen 1 (james04)                    */
/* 2015-03-01 2.3  ChewKP   SoS#333979 Add StorerConfig TrackOrderCube to    */
/*                          calculate cube information (ChewKP07)            */
/* 2015-04-22 2.4  ChewKP   SOS#339560 Add ExtendedUpSP on Step5 (ChewKP08)  */
/* 2015-09-23 2.5  ChewKP   Performance Tuning on MBOLLineNumber (ChewKP09)  */
/* 2015-09-28 2.5  ChewKP   SOS#353271 Adjust ExtendUpSP on Step5 (ChewKP09) */
/* 2015-09-29 2.6  ChewKP   SOS#353596 Get TrackNo from Orders.TrackingNo    */
/*                          (ChewKP10)                                       */
/* 2016-08-10 2.7  James    Trim space for weight (james05)                  */
/* 2016-09-30 2.8  Ung      Performance tuning                               */   
/* 2016-11-13 2.9  James    Add config to limit # of orders allow (james06)  */   
/* 2016-11-18 3.0  ChewKP   11/11 Bug Fix (ChewKP11)                         */
/* 2017-03-10 3.1  SPChin   IN00287088 - Disallow to ESC                     */
/* 2017-04-13 3.2  SPChin   IN00314294 - Bug Fixed                           */
/* 2017-08-24 3.3  ChewKP   WMS-2751 - Add Codelkup ORDSTSMAP to filter      */
/*                          SOStatus, Priority, DocType (ChewKP12)           */
/* 2017-11-14 3.4  Ung      Fix ShowPalletIDScreen                           */
/* 2018-01-12 3.5  Ung      WMS-3774 Change CartonDescription to Barcode     */
/* 2019-07-09 3.6  Ung      Fix MBOL shipped                                 */
/* 2019-08-20 3.7  James    WMS-10283 Add decode @ step 2 (james07)          */
/* 2020-03-11 3.8  James    WMS-12418 Change presale filter checking(james08)*/
/* 2020-01-04 3.9  James    WMS-15946 Add CartonTrack.TrackingNo as one of   */
/*                          tracking no lookup field (james09)               */
/* 2021-04-16 4.0  James    WMS-16024 Standarized use of TrackingNo (james10)*/
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_TrackNoMBOL_Creation](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
   @b_success           INT

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cPrinter_Paper      NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cOrderKey           NVARCHAR(10),
   @cTrackNo            NVARCHAR(20), -- (ChewKP06)
   @cMBOLKey            NVARCHAR(10),
   @cConsigneeKey       NVARCHAR(15),
   @cExternOrderkey     NVARCHAR(20),
   @cTrackRegExp        NVARCHAR(255),
   @nOrderCount         INT,
   @cLoadKey            NVARCHAR(10),
   @cOrderStatus        NVARCHAR(10),
   @cMBOLLineNumber     NVARCHAR(5),

   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),
   @cErrMsg5            NVARCHAR( 20),
   @cShipperKey         NVARCHAR( 15),
   @ErrMsgNextScreen    NVARCHAR(1),
   @cSkipOrderInfo      NVARCHAR(1),
   @cSOStatus           NVARCHAR(10),   -- (james01)
   @fOrderWeight        FLOAT,      -- (ChewKP01)
   @cTrackOrderWeight   NVARCHAR(30),    -- (ChewKP01)
   @cTrackCartonType    NVARCHAR(1),    -- (ChewKP03)
   @cCartonLabelNo      NVARCHAR(20),   -- (ChewKP03)
   @cUseSequence        INT,            -- (ChewKP03)
   @nLabelCount         INT,            -- (CheWKP03)
   @nDefaultCartonCount INT,            -- (CheWKP04)
   @nValid              INT,            -- (james02)
   @cExtendedValidateSP NVARCHAR( 20),  -- (james02)
   @cSQL                NVARCHAR(1000), -- (james02)
   @cSQLParam           NVARCHAR(1000), -- (james02)
   @nLabelScanned       INT,            -- (james02)
   @cPalletID           NVARCHAR(20),   -- (ChewKP06)
   @cShowPalletIDScreen NVARCHAR(1),    -- (ChewKP06) 
   @cExtendedUpdateSP   NVARCHAR(30),   -- (ChewKP06)
   @cTrackOrderWeightSP NVARCHAR(30),   -- (ChewKP05)   
   @cLabelScanned       INT,            -- (james04)
   @cTrackOrderCube     NVARCHAR(1),    -- (ChewKP07)
   @nCube               FLOAT,          -- (ChewKP07)
   @cNoOfOrdersAllowed  NVARCHAR( 5),   -- (james06)
   @cLabelCount         NVARCHAR( 5),   -- (ChewKP11) 
   @cCartonGroup        NVARCHAR(10),	 -- IN00314294
   @cDecodeSP           NVARCHAR( 20),
   @cBarcode            NVARCHAR( MAX),
   @cUserDefine01       NVARCHAR( 60),
   @cOrderWeight        NVARCHAR( 10),

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
   @cPrinter_Paper   = Printer_Paper,
   @cUserName        = UserName,

   @cOrderKey        = V_OrderKey,
   @cTrackNo         = V_String1,
   @cMBOLKey         = V_String2,
   @cShipperKey      = V_String3,
   @ErrMsgNextScreen = V_String4,
   @fOrderWeight     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,  -- (ChewKP01)
   @cDecodeSP        = V_String6,
   @cPalletID        = V_String7, -- (ChewKP06) 
   @cShowPalletIDScreen = V_String8, -- (ChewKP06) 
   @cExtendedUpdateSP   = V_String9, -- (ChewKP06)
   @cNoOfOrdersAllowed  = V_String10, -- (james06)

   @nLabelCount      = V_Integer1,

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

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1664
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1664
   IF @nStep = 1 GOTO Step_1   -- Scn = 2730 MBOLKEY
   IF @nStep = 2 GOTO Step_2   -- Scn = 2731 Track No
   IF @nStep = 3 GOTO Step_3   -- Scn = 2732 Display Information
   IF @nStep = 4 GOTO Step_4   -- Scn = 2733 Order Weight -- (ChewKP01)
   IF @nStep = 5 GOTO Step_5   -- Scn = 2734 Carton Label -- (ChewKP03)
   IF @nStep = 6 GOTO Step_6   -- Scn = 2735 Carton Label -- (ChewKP06)

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1664)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2730
   SET @nStep = 1
   
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
   BEGIN
        SET @cExtendedValidateSP = ''
   END
   
   SET @cShowPalletIDScreen = ''
   SET @cShowPalletIDScreen = rdt.RDTGetConfig( @nFunc, 'ShowPalletIDScreen', @cStorerKey)
   
   --(ChewKP06)
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
   IF @cExtendedUpdateSP = '0'      
   BEGIN    
        SET @cExtendedUpdateSP = ''    
   END

   -- (james06)
   SET @cNoOfOrdersAllowed = rdt.rdtGetConfig( @nFunc, 'NoOfOrdersAllowed', @cStorerKey)
   IF rdt.rdtIsValidQTY( @cNoOfOrdersAllowed, 0) = 0
      SET @cNoOfOrdersAllowed = '0'   

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   -- initialise all variable
   SET @cMBOLKey = ''
   SET @cTrackNo = ''
   SET @nLabelCount = 0 -- (ChewKP03)
   SET @cPalletID = '' -- (ChewKP06)

   -- Prep next screen var
   SET @cOutField01 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2730
   MBOLKey: (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cMBOLKey = ISNULL(RTRIM(@cInField01),'')

      SET @ErrMsgNextScreen = ''
      SET @ErrMsgNextScreen = rdt.RDTGetConfig( @nFunc, 'ErrMsgNextScreen', @cStorerkey)

      --When Lane is blank
      IF @cMBOLKey = ''
      BEGIN
         SET @nErrNo = 72541
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOLKey req
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_1_Fail
      END

      --Check if MBOL exits
      IF NOT EXISTS (SELECT 1 FROM dbo.MBOL WITH (NOLOCK)
                     WHERE MBOLKey = @cMBOLKey
                    )
      BEGIN
         SET @nErrNo =  72542
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv MBOLKey
          EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

          GOTO Step_1_Fail
      END

      --Check if MBOL status
      IF EXISTS (SELECT 1 FROM dbo.MBOL WITH (NOLOCK)
                     WHERE MBOLKey = @cMBOLKey
                     AND Status = '9')
      BEGIN
          SET @nErrNo =  72543
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
          EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

          GOTO Step_1_Fail
      END

      SET @nOrderCount = 0
      SELECT @nOrderCount = Count (Orderkey)
      FROM dbo.MBOLDetail WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey

      IF @cShowPalletIDScreen <> '1' 
      BEGIN
         SET @cPalletID = ''  -- (james03)         
         SET @cOutField01 = @cMBOLKey
         SET @cOutField02 = ISNULL(@nOrderCount,0)
         SET @cOutField03 = ''
   
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cMBOLKey
         SET @cOutField02 = ''
         SET @cOutField03 = ''
   
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5
      END
   
      -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
           @cActionType   = '1', -- Sign In
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerkey,
           @cRefNo1       = @cMBOLKey,
           @cRefNo2       = @cLoadKey,
           @cRefNo3       = @cOrderKey,
           @cRefNo4       = ''
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
       -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
           @cActionType   = '9', -- Sign Out
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerkey,
           @cRefNo1       = @cMBOLKey,
           @cRefNo2       = @cLoadKey,
           @cRefNo3       = @cOrderKey,
           @cRefNo4       = @cTrackNo

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''

      SET @cMBOLKey = ''




   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cMBOLKey = ''
      SET @cOutField01 = ''

    END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2731
   MBOLkey (Field01)
   Total Order Count (Field02)
   Track No (Field03, Input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cTrackNo = @cInField03
      
      

      IF ISNULL(@cTrackNo, '') = ''
      BEGIN
         SET @nErrNo = 72544
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNo req
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_2_Fail
      END

--      SET @cShipperKey = ''
--      SELECT @cShipperKey = ShipperKey
--      FROM dbo.ORDERS WITH (NOLOCK)
--      WHERE Orderkey = @cOrderkey
--      AND Storerkey = @cStorerkey
--
--
--
--      IF ISNULL(@cShipperKey,'') = ''
--      BEGIN
--         SET @nErrNo = 72550
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv ShipperKey
--         EXEC rdt.rdtSetFocusField @nMobile, 1
--
--         IF @ErrMsgNextScreen = '1'
--         BEGIN
--            --SET @nErrNo = 0
--            SET @cErrMsg1 = @nErrNo
--            SET @cErrMsg2 = @cErrMsg
--            SET @cErrMsg3 = ''
--            SET @cErrMsg4 = ''
--            SET @cErrMsg5 = ''
--            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
--               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
--            IF @nErrNo = 1
--            BEGIN
--               SET @cErrMsg1 = ''
--               SET @cErrMsg2 = ''
--               SET @cErrMsg3 = ''
--               SET @cErrMsg4 = ''
--               SET @cErrMsg5 = ''
--            END
--         END
--
--         GOTO Step_2_Fail
--      END
--
--      SET @cTrackRegExp = ''
--      SELECT @cTrackRegExp = Notes1 FROM dbo.Storer WITH (NOLOCK)
--      WHERE Storerkey = @cShipperKey
--
--
--
--      IF ISNULL(@cTrackRegExp,'') <> ''
--      BEGIN
--
--         IF rdt.rdtIsRegExMatch(ISNULL(RTRIM(@cTrackRegExp),''),ISNULL(RTRIM(@cTrackNo),'')) <> 1
--         BEGIN
--               SET @nErrNo = 72545
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv TrackNo
--               EXEC rdt.rdtSetFocusField @nMobile, 1
--
--               IF @ErrMsgNextScreen = '1'
--               BEGIN
--                  --SET @nErrNo = 0
--                  SET @cErrMsg1 = @nErrNo
--                  SET @cErrMsg2 = @cErrMsg
--                  SET @cErrMsg3 = ''
--                  SET @cErrMsg4 = ''
--                  SET @cErrMsg5 = ''
--                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
--                     @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
--                  IF @nErrNo = 1
--                  BEGIN
--                     SET @cErrMsg1 = ''
--                     SET @cErrMsg2 = ''
--                     SET @cErrMsg3 = ''
--                     SET @cErrMsg4 = ''
--                     SET @cErrMsg5 = ''
--                  END
--               END
--
--               GOTO Step_2_Fail
--         END
--      END

      -- Decode  
      -- Standard decode  
      IF @cDecodeSP = '1'  
      BEGIN  
         SET @cBarcode = @cTrackNo
         SET @cUserDefine01 = @cTrackNo

         EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,   
            @cUserDefine01 = @cUserDefine01  OUTPUT,   
            @nErrNo  = @nErrNo  OUTPUT,   
            @cErrMsg = @cErrMsg OUTPUT

         IF ISNULL( @cUserDefine01, '') <> ''
            SET @cTrackNo = @cUserDefine01
      END  
      ELSE  
      BEGIN
         IF @cDecodeSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cBarcode = @cTrackNo

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
                  ' @cMbolKey       OUTPUT, @cTrackNo       OUTPUT, @cOrderWeight   OUTPUT, @cCartonLabelNo OUTPUT, ' +
                  ' @cLabelCount    OUTPUT, @cLabelScanned  OUTPUT, @cPalletID      OUTPUT, ' +
                  ' @nErrNo         OUTPUT, @cErrMsg        OUTPUT'
               SET @cSQLParam =
                  ' @nMobile        INT,             ' +
                  ' @nFunc          INT,             ' +
                  ' @cLangCode      NVARCHAR( 3),    ' +
                  ' @nStep          INT,             ' +
                  ' @nInputKey      INT,             ' +
                  ' @cFacility      NVARCHAR( 5),    ' +
                  ' @cStorerKey     NVARCHAR( 15),   ' +
                  ' @cBarcode       NVARCHAR( MAX),  ' +
                  ' @cMbolKey       NVARCHAR( 10)  OUTPUT, ' +
                  ' @cTrackNo       NVARCHAR( 20)  OUTPUT, ' +
                  ' @cOrderWeight   NVARCHAR( 10)  OUTPUT, ' +
                  ' @cCartonLabelNo NVARCHAR( 20)  OUTPUT, ' +
                  ' @cLabelCount    NVARCHAR( 5)   OUTPUT, ' +
                  ' @cLabelScanned  NVARCHAR( 5)   OUTPUT, ' +
                  ' @cPalletID      NVARCHAR( 20)  OUTPUT, ' +
                  ' @nErrNo         INT            OUTPUT, ' +
                  ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, 
                  @cMbolKey       OUTPUT, @cTrackNo      OUTPUT, @cOrderWeight   OUTPUT, @cCartonLabelNo OUTPUT, 
                  @cLabelCount    OUTPUT, @cLabelScanned OUTPUT, @cPalletID      OUTPUT, 
                  @nErrNo        OUTPUT,  @cErrMsg       OUTPUT
            END
         END
      END

      SET @cOrderKey = ''
      SET @cOrderStatus = ''
      SET @cLoadKey = ''
      SET @cSOStatus = ''              -- (james01)

      SELECT @cOrderKey = Orderkey
             ,@cLoadKey = Loadkey
             ,@cExternOrderkey = ExternOrderkey
             ,@cConsigneeKey = ConsigneeKey
             ,@cOrderStatus = Status
             ,@cSOStatus = SOStatus    -- (james01)
      FROM dbo.Orders WITH (NOLOCK)
      --WHERE Userdefine04 = @cTrackNo
      WHERE TrackingNo = @cTrackNo  -- (james10)
      AND StorerKey = @cStorerKey   --SOS293491
      AND Facility = @cFacility     --SOS293491
      
      IF @@ROWCOUNT = 0 -- (ChewKP10) 
      BEGIN
         SELECT @cOrderKey = Orderkey
                ,@cLoadKey = Loadkey
                ,@cExternOrderkey = ExternOrderkey
                ,@cConsigneeKey = ConsigneeKey
                ,@cOrderStatus = Status
                ,@cSOStatus = SOStatus    -- (james01)
         FROM dbo.Orders WITH (NOLOCK)
         WHERE TrackingNo = @cTrackNo
         AND StorerKey = @cStorerKey   --SOS293491
         AND Facility = @cFacility     --SOS293491
      END

      IF @@ROWCOUNT = 0 -- (james09)
      BEGIN
         SELECT @cOrderKey = Orderkey
                ,@cLoadKey = Loadkey
                ,@cExternOrderkey = ExternOrderkey
                ,@cConsigneeKey = ConsigneeKey
                ,@cOrderStatus = Status
                ,@cSOStatus = SOStatus
         FROM dbo.CartonTrack CT WITH (NOLOCK)
         JOIN dbo.ORDERS O WITH (NOLOCK) ON ( CT.LabelNo = O.OrderKey)
         WHERE CT.TrackingNo = @cTrackNo 
         AND   O.StorerKey = @cStorerKey 
         AND   O.Facility = @cFacility 
      END

      IF ISNULL(@cOrderKey,'') = ''
      BEGIN
         SET @nErrNo = 72547
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv TrackNo
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_2_Fail
      END
      ELSE
      BEGIN 
         

         -- (james08)
         -- Commented this logic. LIT CONFIRMED only 1 storer use this logic and now they want switch to use new listname
         /*         
         -- (ChewKP12) 
         --DECLARE @tOrderCriteriaList TABLE (SOStatus NVARCHAR(10), Priority NVARCHAR(10), DocType NVARCHAR(1)) 
         
         --INSERT INTO @tOrderCriteriaList ( SOStatus, Priority, DocType ) 
         --SELECT Short, UDF02, UDF01 
         --FROM dbo.Codelkup WITH (NOLOCK) 
         --WHERE ListName = 'ORDSTSMAP'
         --AND StorerKey = @cStorerKey 
         
         --IF EXISTS ( SELECT 1
         --            FROM dbo.Orders WITH (NOLOCK)
         --            WHERE StorerKey = @cStorerKey
         --            AND OrderKey = @cOrderKey 
         --            AND SOStatus IN (SELECT SOStatus FROM @tOrderCriteriaList)
         --            AND Priority IN (SELECT Priority FROM @tOrderCriteriaList)
         --            AND DocType  IN (SELECT DocType FROM @tOrderCriteriaList) )
         */
         IF EXISTS ( SELECT 1 FROM dbo.ORDERS O WITH (NOLOCK)
                     WHERE O.StorerKey = @cStorerKey
                     AND   O.OrderKey = @cOrderKey 
                     AND   EXISTS ( SELECT 1 FROM dbo.CODELKUP CLK WITH (NOLOCK)
                                    WHERE CLK.LISTNAME = 'SOSTSBLOCK'
                                    AND   O.StorerKey = CLK.Storerkey
                                    AND   O.SOStatus = CLK.Code
                                    AND   CLK.code2 = @nFunc))
         BEGIN
            SET @nErrNo = 72565
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Criteria
            EXEC rdt.rdtSetFocusField @nMobile, 1

            IF @ErrMsgNextScreen = '1'
            BEGIN
            
               --SET @nErrNo = 0
               SET @cErrMsg1 = @nErrNo
               SET @cErrMsg2 = @cErrMsg
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                  @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
               END
            END

            GOTO Step_2_Fail
         END
                     
      END

      IF ISNULL(@cOrderStatus,'')  < '5'
      BEGIN
         SET @nErrNo = 72548
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Order
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_2_Fail
      END

      IF ISNULL(@cSOStatus,'')  = 'HOLD' -- (james01)
      BEGIN
         SET @nErrNo = 72551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order is HOLD
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_2_Fail
      END

      IF ISNULL(@cSOStatus,'')  = 'PENDPACK' -- (ChewKP02)
      BEGIN
         SET @nErrNo = 72554
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending Update
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_2_Fail
      END

      IF ISNULL(@cSOStatus,'')  = 'PENDCANC' -- (ChewKP02)
      BEGIN
         SET @nErrNo = 72555
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending CANC
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_2_Fail
      END

      IF ISNULL(@cSOStatus,'')  = 'CANC' -- (ChewKP02)
      BEGIN
         SET @nErrNo = 72556
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_2_Fail
      END

      -- (james06)
      -- Limit no of orders per mbol, 0 = no limit
      IF CAST( @cNoOfOrdersAllowed AS INT) > 0
      BEGIN
         SET @nOrderCount = 0
         SELECT @nOrderCount = Count (Orderkey)
         FROM dbo.MBOLDetail WITH (NOLOCK)
         WHERE MBOLKey = @cMBOLKey

         IF @cNoOfOrdersAllowed < @nOrderCount + 1
         BEGIN
            SET @nErrNo = 72564
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -->Allow #OfOrds
            EXEC rdt.rdtSetFocusField @nMobile, 1

            IF @ErrMsgNextScreen = '1'
            BEGIN
               --SET @nErrNo = 0
               SET @cErrMsg1 = @nErrNo
               SET @cErrMsg2 = @cErrMsg
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                  @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
               END
            END

            GOTO Step_2_Fail
         END
      END

      -- (james02)
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cMBOLKey, @cOrderKey, @cTrackNo, @nValid OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                 @cErrMsg1 OUTPUT, @cErrMsg2 OUTPUT, @cErrMsg3 OUTPUT, @cErrMsg4 OUTPUT, @cErrMsg5 OUTPUT ' 
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 18), ' +
               '@nValid          INT            OUTPUT,  ' +
               '@nErrNo          INT            OUTPUT,  ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT, ' + 
               '@cErrMsg1        NVARCHAR( 20)  OUTPUT, ' + 
               '@cErrMsg2        NVARCHAR( 20)  OUTPUT, ' + 
               '@cErrMsg3        NVARCHAR( 20)  OUTPUT, ' + 
               '@cErrMsg4        NVARCHAR( 20)  OUTPUT, ' + 
               '@cErrMsg5        NVARCHAR( 20)  OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cStorerKey, @cMBOLKey, @cOrderKey, @cTrackNo, @nValid OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cErrMsg1 OUTPUT, @cErrMsg2 OUTPUT, @cErrMsg3 OUTPUT, @cErrMsg4 OUTPUT, @cErrMsg5 OUTPUT

            IF @nValid = 0
            BEGIN
               IF ISNULL( @cErrMsg1, '') <> ''
               BEGIN
                  --SET @nErrNo = 0
                  SET @cErrMsg1 = @cErrMsg1
                  SET @cErrMsg2 = @cErrMsg2
                  SET @cErrMsg3 = @cErrMsg3
                  SET @cErrMsg4 = @cErrMsg4
                  SET @cErrMsg5 = @cErrMsg5
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                     @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
                  IF @nErrNo = 1
                  BEGIN
                     SET @cErrMsg1 = ''
                     SET @cErrMsg2 = ''
                     SET @cErrMsg3 = ''
                     SET @cErrMsg4 = ''
                     SET @cErrMsg5 = ''
                  END
               END
               ELSE
               BEGIN
                  SET @nErrNo = 72560
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv TrackNo
               END
               
               GOTO Step_2_Fail
            END
         END
      END

      -- MBOLDetail Insertion (Start) --
      
      -- If show pallet id screen not setup the set pallet id blank
      IF @cShowPalletIDScreen <> '1' -- (james03)
         SET @cPalletID = ''
      
      IF NOT EXISTS (SELECT 1 FROM dbo.MBOLDETAIL WITH (NOLOCK)
                           WHERE OrderKey = @cOrderKey)
      BEGIN
         -- Check MBOL shipped (temporary workaround, instead of changing ntrMBOLDetailAdd trigger)
         IF EXISTS( SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND Status = '9')
         BEGIN
             SET @nErrNo =  72566
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
            EXEC rdt.rdtSetFocusField @nMobile, 1

            IF @ErrMsgNextScreen = '1'
            BEGIN
               --SET @nErrNo = 0
               SET @cErrMsg1 = @nErrNo
               SET @cErrMsg2 = @cErrMsg
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                  @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
               END
            END

            GOTO Step_2_Fail
         END

         SET @cMBOLLineNumber = '00000' -- (ChewKP09) 

         BEGIN TRAN

         INSERT INTO dbo.MBOLDETAIL
        (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, EditWho, UserDefine01) -- (ChewKP06) 
         VALUES (@cMBOLKey, @cMBOLLineNumber, @cOrderKey, @cLoadKey, '*' + RTRIM(sUser_sName()), 'rdt.' + RTRIM(sUser_sName()) , @cPalletID ) -- (ChewKP06)

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72549
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsMBOLDetFail
            EXEC rdt.rdtSetFocusField @nMobile, 3

            IF @ErrMsgNextScreen = '1'
            BEGIN
               --SET @nErrNo = 0
               SET @cErrMsg1 = @nErrNo
               SET @cErrMsg2 = @cErrMsg
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                  @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
               END
            END

            GOTO Step_2_Fail
         END
         ELSE
         BEGIN
           COMMIT TRAN

            -- insert to Eventlog
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '3', -- Creating MBOLDetail
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerkey,
               @cRefNo1       = @cMBOLKey,
               @cRefNo2       = @cLoadKey,
               @cRefNo3       = @cOrderKey,
               @cRefNo4       = @cTrackNo
         END

--(ChewKP08)
--         SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
--         IF @cExtendedUpdateSP = '0'      
--         BEGIN    
--              SET @cExtendedUpdateSP = ''    
--         END

         -- Calling Extended Update -- (ChewKP06) 
         IF @cExtendedUpdateSP <> ''    
         BEGIN    
                 
             IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
             BEGIN    
                  
       
                SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                   ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cTrackNo, @cMBOLKey, @nStep, @cOrderKey, @cCartonLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                SET @cSQLParam =    
                   '@nMobile        INT, ' +    
                   '@nFunc          INT, ' +    
                   '@cLangCode      NVARCHAR( 3),  ' +    
                   '@cUserName      NVARCHAR( 18), ' +    
                   '@cFacility      NVARCHAR( 5),  ' +    
                   '@cStorerKey     NVARCHAR( 15), ' +    
                   '@cTrackNo       NVARCHAR( 20), ' +    
                   '@cMBOLKey       NVARCHAR( 10), ' +    
                   '@nStep          INT,           ' +    
                   '@cOrderkey      NVARCHAR( 10), ' +     
                   '@cCartonLabelNo NVARCHAR( 20), ' + -- (ChewKP08) 
                   '@nErrNo         INT           OUTPUT, ' +     
                   '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                       
             
                EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                   @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cTrackNo, @cMBOLKey, @nStep, @cOrderKey, @cCartonLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
             
                IF @nErrNo <> 0     
                BEGIN
                   
                   IF @ErrMsgNextScreen = '1'
                   BEGIN
                        --SET @nErrNo = 0
                        SET @cErrMsg1 = @nErrNo
                        SET @cErrMsg2 = @cErrMsg
                        SET @cErrMsg3 = ''
                        SET @cErrMsg4 = ''
                        SET @cErrMsg5 = ''
                        EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                           @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
                        IF @nErrNo = 1
                        BEGIN
                           SET @cErrMsg1 = ''
                           SET @cErrMsg2 = ''
                           SET @cErrMsg3 = ''
                           SET @cErrMsg4 = ''
                           SET @cErrMsg5 = ''
                        END
                   END
                   
                   GOTO Step_2_Fail    
                END       
             END    
         END 
         
      END
      ELSE
      BEGIN
               SET @nErrNo = 72546
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Exists
               EXEC rdt.rdtSetFocusField @nMobile, 1

               IF @ErrMsgNextScreen = '1'
               BEGIN
                  --SET @nErrNo = 0
                  SET @cErrMsg1 = @nErrNo
                  SET @cErrMsg2 = @cErrMsg
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                     @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
                  IF @nErrNo = 1
                  BEGIN
                     SET @cErrMsg1 = ''
                     SET @cErrMsg2 = ''
                     SET @cErrMsg3 = ''
                     SET @cErrMsg4 = ''
                     SET @cErrMsg5 = ''
                  END
               END

               GOTO Step_2_Fail
      END


      -- MBOLDetail Insertion (End) --
      SET @cSkipOrderInfo = ''
      SET @cSkipOrderInfo = rdt.RDTGetConfig( @nFunc, 'SkipOrderInfo', @cStorerkey)

      SET @cTrackOrderWeight = '' -- (ChewKP01)
      SET @cTrackOrderWeight = rdt.RDTGetConfig( @nFunc, 'TrackOrderWeight', @cStorerkey) -- (ChewKP01)
      
      -- (ChewKP05)  
      IF ISNULL(@cTrackOrderWeight,'') NOT IN ( '', '1', '0')   
      BEGIN  
          SET @cTrackOrderWeightSP = @cTrackOrderWeight  
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cTrackOrderWeightSP AND type = 'P')  
          BEGIN  
               
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cTrackOrderWeightSP) +  
                ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey, @cMBOLKey, @cTrackNo, @cTrackOrderWeight OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
             SET @cSQLParam =  
                '@nMobile        INT, ' +  
                '@nFunc          INT, ' +  
                '@cLangCode      NVARCHAR( 3),  ' +  
                '@cUserName      NVARCHAR( 18), ' +  
                '@cFacility      NVARCHAR( 5),  ' +  
                '@cStorerKey     NVARCHAR( 15), ' +  
                '@cOrderKey      NVARCHAR( 20), ' +  
                '@cMBOLKey       NVARCHAR( 20), ' +  
                '@cTrackNo       NVARCHAR( 20), ' +  
                '@cTrackOrderWeight NVARCHAR(1) OUTPUT , ' +  
                '@nErrNo         INT           OUTPUT, ' +   
                '@cErrMsg        NVARCHAR( 20) OUTPUT'  
                  
        
             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey, @cMBOLKey, @cTrackNo, @cTrackOrderWeight OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   
        
             IF @nErrNo <> 0   
                GOTO Step_2_Fail  
                  
          END  
      END  

      -- (ChewKP03)
      SET @cTrackCartonType = ''
      SET @cTrackCartonType = rdt.RDTGetConfig( @nFunc, 'TrackCartonType', @cStorerkey)



      -- (CheWKP03)
      IF @cTrackOrderWeight <> '1' AND @cTrackCartonType <> '1' -- (ChewKP01), -- (ChewKP03)
      BEGIN


         IF @cSkipOrderInfo <> '1'
         BEGIN
            SET @cOutField01 = @cMBOLKey
            SET @cOutField02 = @cTrackNo
            SET @cOutField03 = @cOrderkey
            SET @cOutField04 = @cExternOrderkey
            SET @cOutField05 = @cConsigneeKey

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO QUIT
         END
         ELSE IF @cSkipOrderInfo = '1'
         BEGIN
            SET @nOrderCount = 0
            SELECT @nOrderCount = Count (Orderkey)
            FROM dbo.MBOLDetail WITH (NOLOCK)
            WHERE MBOLKey = @cMBOLKey

            SET @cOutField02 = @nOrderCount
            SET @cOutField03 = ''
         END

      END
      ELSE
      BEGIN

         IF @cTrackOrderWeight = '1'
         BEGIN
            -- GOTO Order Weight Screen
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2

            SET @cOutField01 = ''

            GOTO QUIT
         END

         IF @cTrackCartonType = '1'
         BEGIN
            -- GOTO Order Weight Screen
            
            -- (ChewKP04)
            SET @nDefaultCartonCount = ''
            SET @nDefaultCartonCount = rdt.RDTGetConfig( @nFunc, 'DefaultCartonCount', @cStorerkey)
            
            IF ISNULL(@nDefaultCartonCount,0 ) = 0 
            BEGIN
               SET @nDefaultCartonCount = 0 
            END
      
            SET @nScn = @nScn + 3
            SET @nStep = @nStep + 3

            SET @nLabelCount = 0

            SELECT @nLabelScanned = 
                  CAST( ISNULL( CtnCnt1, '0') AS INT) + 
                  CAST( ISNULL( CtnCnt2, '0') AS INT) + 
                  CAST( ISNULL( CtnCnt3, '0') AS INT) + 
                  CAST( ISNULL( CtnCnt4, '0') AS INT) + 
                  CAST( ISNULL( CtnCnt5, '0') AS INT) + 
                  CAST( ISNULL( UserDefine01, '0') AS INT) + 
                  CAST( ISNULL( UserDefine02, '0') AS INT) + 
                  CAST( ISNULL( UserDefine03, '0') AS INT) + 
                  CAST( ISNULL( UserDefine04, '0') AS INT) + 
                  CAST( ISNULL( UserDefine05, '0') AS INT) + 
                  CAST( ISNULL( UserDefine09, '0') AS INT) + 
                  CAST( ISNULL( UserDefine10, '0') AS INT) 
            FROM dbo.MbolDetail WITH (NOLOCK) 
            WHERE MBOLKey = @cMBOLKey
            AND   OrderKey = @cOrderKey
         
            SET @cOutField01 = ''
            SET @cOutField02 = @nDefaultCartonCount
            SET @cOutField03 = ISNULL( @nLabelScanned, 0)

            GOTO QUIT
         END

      END



--      IF @cSkipOrderInfo <> '1' AND @cTrackOrderWeight <> '1' AND  @cTrackCartonType <> '1' -- (ChewKP01), -- (ChewKP03)
--      BEGIN
--         SET @cOutField01 = @cMBOLKey
--         SET @cOutField02 = @cTrackNo
--         SET @cOutField03 = @cOrderkey
--         SET @cOutField04 = @cExternOrderkey
--         SET @cOutField05 = @cConsigneeKey
--
--         SET @nScn = @nScn + 1
--         SET @nStep = @nStep + 1
--      END
--      ELSE IF @cSkipOrderInfo <> '1' AND @cTrackOrderWeight <> '1' AND  @cTrackCartonType = '1' -- (ChewKP01), -- (ChewKP03)
--      BEGIN
--         -- GOTO Order Weight Screen
--         SET @nScn = @nScn + 2
--         SET @nStep = @nStep + 2
--
--         SET @cOutField01 = ''
--
--      END
--      ELSE IF @cSkipOrderInfo <> '1' AND @cTrackOrderWeight = '1' AND  @cTrackCartonType <> '1' -- (ChewKP01), -- (ChewKP03)
--      BEGIN
--         -- GOTO Order Weight Screen
--         SET @nScn = @nScn + 2
--         SET @nStep = @nStep + 2
--
--         SET @cOutField01 = ''
--
--      END
--      ELSE IF @cSkipOrderInfo = '1' AND @cTrackOrderWeight <> '1' AND  @cTrackCartonType <> '1' -- (ChewKP01), -- (ChewKP03)
--      BEGIN
--
--         SET @nOrderCount = 0
--         SELECT @nOrderCount = Count (Orderkey)
--         FROM dbo.MBOLDetail WITH (NOLOCK)
--         WHERE MBOLKey = @cMBOLKey
--
--         SET @cOutField02 = @nOrderCount
--         SET @cOutField03 = ''
--      END
--      ELSE IF @cSkipOrderInfo = '1' AND @cTrackOrderWeight = '1' AND  @cTrackCartonType = '1' -- (ChewKP01), -- (ChewKP03)
--      BEGIN
--         -- GOTO Order Weight Screen
--         SET @nScn = @nScn + 2
--         SET @nStep = @nStep + 2
--
--         SET @cOutField01 = ''
--
--      END


   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      
      IF @cShowPalletIDScreen <> '1' -- (ChewKP06) 
      BEGIN
         SET @cOutField01 = '' -- @cMbolKey -- (ChewKP03)
         --SET @cOutField02 = ''
   
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cMbolKey
         SET @cOutField02 = ''
   
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4
      END
      
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN

      SET @cOutField03 = ''
   END

END
GOTO Quit



/********************************************************************************
Step 3. screen = 2732
   Success Message
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN



      SET @nOrderCount = 0
      SELECT @nOrderCount = Count (Orderkey)
      FROM dbo.MBOLDetail WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey

      SET @cOutField02 = @nOrderCount
      SET @cOutField03 = ''


      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

END
GOTO Quit


/********************************************************************************
Step 4. screen = 2733 -- (ChewKP01)
   OrderWeight: (Field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOrderWeight = LTRIM( ISNULL(@cInField01,0))  -- (james05)

      IF rdt.rdtIsValidQTY( @cOrderWeight, 21) = 0 OR LEN( @cOrderWeight) > 6
      BEGIN
               SET @nErrNo = 72552
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Weight
               EXEC rdt.rdtSetFocusField @nMobile, 1

               IF @ErrMsgNextScreen = '1'
               BEGIN
                  --SET @nErrNo = 0
                  SET @cErrMsg1 = @nErrNo
                  SET @cErrMsg2 = @cErrMsg
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                     @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
                  IF @nErrNo = 1
                  BEGIN
                     SET @cErrMsg1 = ''
                     SET @cErrMsg2 = ''
                     SET @cErrMsg3 = ''
                     SET @cErrMsg4 = ''
                     SET @cErrMsg5 = ''
                  END
               END

               GOTO Step_4_Fail
      END
      SET @fOrderWeight = CAST( @cOrderWeight AS FLOAT)

      -- Check weight range
      IF @fOrderWeight NOT BETWEEN 0 AND 99999
      BEGIN
         SET @nErrNo = 72563
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvWeightRange
         EXEC rdt.rdtSetFocusField @nMobile, 1
         
         IF @ErrMsgNextScreen = '1'
         BEGIN
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         
         GOTO Step_4_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.MBOLDETAIL WITH (NOLOCK)
                           WHERE OrderKey = @cOrderKey)
      BEGIN
         BEGIN TRAN

         UPDATE dbo.MBOLDetail WITH (ROWLOCK)
         SET Weight = @fOrderWeight
         WHERE MBOLKey  = @cMBOLKey
         AND   Orderkey = @cOrderKey

         IF @@Error <> 0
         BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72553
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd MBOLD Fail
               EXEC rdt.rdtSetFocusField @nMobile, 1

               IF @ErrMsgNextScreen = '1'
               BEGIN
                  --SET @nErrNo = 0
                  SET @cErrMsg1 = @nErrNo
                  SET @cErrMsg2 = @cErrMsg
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                     @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
                  IF @nErrNo = 1
                  BEGIN
                     SET @cErrMsg1 = ''
                     SET @cErrMsg2 = ''
                     SET @cErrMsg3 = ''
                     SET @cErrMsg4 = ''
                     SET @cErrMsg5 = ''
                  END
               END

               GOTO Step_4_Fail
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END

      END

      SET @nOrderCount = 0
      SELECT @nOrderCount = Count (Orderkey)
      FROM dbo.MBOLDetail WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey


      -- (ChewKP03)
      SET @cTrackCartonType = ''
      SET @cTrackCartonType = rdt.RDTGetConfig( @nFunc, 'TrackCartonType', @cStorerkey)

      IF @cTrackCartonType = '1'
      BEGIN
         -- (ChewKP04)
         SET @nDefaultCartonCount = ''
         SET @nDefaultCartonCount = rdt.RDTGetConfig( @nFunc, 'DefaultCartonCount', @cStorerkey)
         
         IF ISNULL(@nDefaultCartonCount,0 ) = 0 
         BEGIN
            SET @nDefaultCartonCount = 0 
         END
            
         --SET @nLabelCount = 0

         SELECT @nLabelScanned = 
               CAST( ISNULL( CtnCnt1, '0') AS INT) + 
               CAST( ISNULL( CtnCnt2, '0') AS INT) + 
               CAST( ISNULL( CtnCnt3, '0') AS INT) + 
               CAST( ISNULL( CtnCnt4, '0') AS INT) + 
               CAST( ISNULL( CtnCnt5, '0') AS INT) + 
               CAST( ISNULL( UserDefine01, '0') AS INT) + 
               CAST( ISNULL( UserDefine02, '0') AS INT) + 
               CAST( ISNULL( UserDefine03, '0') AS INT) + 
               CAST( ISNULL( UserDefine04, '0') AS INT) + 
               CAST( ISNULL( UserDefine05, '0') AS INT) + 
               CAST( ISNULL( UserDefine09, '0') AS INT) + 
               CAST( ISNULL( UserDefine10, '0') AS INT) 
         FROM dbo.MbolDetail WITH (NOLOCK) 
         WHERE MBOLKey = @cMBOLKey
         AND   OrderKey = @cOrderKey
            
         SET @cOutField01  = ''
         SET @cOutField02  = @nDefaultCartonCount
         SET @cOutField03  = ISNULL( @nLabelScanned, 0)

          -- Goto Carton Label Capture Screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO QUIT

      END
      ELSE
      BEGIN

         SET @cSkipOrderInfo = ''
         SET @cSkipOrderInfo = rdt.RDTGetConfig( @nFunc, 'SkipOrderInfo', @cStorerkey)

         IF @cSkipOrderInfo <> '1'
         BEGIN

            SET @cOutField01 = @cMBOLKey
            SET @cOutField02 = @cTrackNo
            SET @cOutField03 = @cOrderkey
            SET @cOutField04 = @cExternOrderkey
            SET @cOutField05 = @cConsigneeKey

            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1

            GOTO QUIT
         END
         ELSE
         BEGIN
            SET @cOutField01 = @cMBOLKey
            SET @cOutField02 = ISNULL(@nOrderCount,0)
            SET @cOutField03 = ''

            -- Back to TrackNo Screen
            SET @nScn  = @nScn -2
            SET @nStep = @nStep - 2

            GOTO QUIT
         END

      END






   END

	--IN00287088 Start 
   --IF @nInputKey = 0 -- ESC
   --BEGIN
   --   SET @nOrderCount = 0
   --   SELECT @nOrderCount = Count (Orderkey)
   --   FROM dbo.MBOLDetail WITH (NOLOCK)
   --   WHERE MBOLKey = @cMBOLKey
   --
   --
   --   SET @cOutField01 = @cMBOLKey
   --   SET @cOutField02 = ISNULL(@nOrderCount,0)
   --   SET @cOutField03 = ''
   --
   --   -- Back to TrackNo Screen
   --   SET @nScn  = @nScn -2
   --   SET @nStep = @nStep - 2
   --
   --
   --END
   --GOTO Quit
   --IN00287088 End

   Step_4_Fail:
   BEGIN
      SET @fOrderWeight = 0
      SET @cOutField01 = ''

    END
END
GOTO Quit



/********************************************************************************
Step 5. screen = 2733 -- (ChewKP03)
   Carton Label No: (Field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cCartonLabelNo = ISNULL(@cInField01,'')
      SET @cLabelCount    = ISNULL(@cInField02,0) -- (ChewKP04) -- (ChewKP11) 
      SET @cLabelScanned  = ISNULL( @cOutField03, 0) -- (james04)
      
      

      IF @cCartonLabelNo = ''
      BEGIN
         SET @nErrNo = 72557
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CtnLabelReq
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_5_Fail
      END

      IF NOT EXISTS( SELECT 1 
         FROM dbo.Cartonization C WITH (NOLOCK)
            JOIN dbo.Storer S WITH (NOLOCK) ON (S.CartonGroup = C.CartonizationGroup)
         WHERE S.StorerKey = @cStorerKey
            AND (C.CartonType = @cCartonLabelNo OR C.Barcode = @cCartonLabelNo))
      BEGIN
         SET @nErrNo = 72558
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CtnLabelNotCfg
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_5_Fail
      END
      
      -- (ChewKP11) 
      IF ISNULL( @cLabelCount , '' ) <> '' 
      BEGIN
         IF rdt.rdtIsValidQTY( LEFT( @cLabelCount, 5), 0) = 1 
            SET  @nLabelCount = LEFT( @cLabelCount, 5)
         ELSE
            SET @nLabelCount = 0 
         
      END
      ELSE 
      BEGIN
         SET @nLabelCount = 0 
      END
      
       -- Calling Extended Update -- (ChewKP08) 
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
              
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
          BEGIN    
               
      
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cTrackNo, @cMBOLKey, @nStep, @cOrderKey, @cCartonLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
             SET @cSQLParam =    
                '@nMobile        INT, ' +    
                '@nFunc          INT, ' +    
                '@cLangCode      NVARCHAR( 3),  ' +    
                '@cUserName      NVARCHAR( 18), ' +    
                '@cFacility      NVARCHAR( 5),  ' +    
                '@cStorerKey     NVARCHAR( 15), ' +    
                '@cTrackNo       NVARCHAR( 20), ' +    
                '@cMBOLKey       NVARCHAR( 10), ' +    
                '@nStep          INT,           ' +    
                '@cOrderkey      NVARCHAR( 10), ' +     
                '@cCartonLabelNo NVARCHAR( 20), ' + -- (ChewKP08) 
                '@nErrNo         INT           OUTPUT, ' +     
                '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                    
          
             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cTrackNo, @cMBOLKey, @nStep, @cOrderKey, @cCartonLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
          
             IF @nErrNo <> 0     
             BEGIN
                
                IF @ErrMsgNextScreen = '1'
                BEGIN
                     --SET @nErrNo = 0
                     SET @cErrMsg1 = @nErrNo
                     SET @cErrMsg2 = @cErrMsg
                     SET @cErrMsg3 = ''
                     SET @cErrMsg4 = ''
                     SET @cErrMsg5 = ''
                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                        @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
                     IF @nErrNo = 1
                     BEGIN
                        SET @cErrMsg1 = ''
                        SET @cErrMsg2 = ''
                        SET @cErrMsg3 = ''
                        SET @cErrMsg4 = ''
                        SET @cErrMsg5 = ''
                     END
                END
                
                GOTO Step_2_Fail    
             END       
          END    
      END 
         
      
      SET @cTrackOrderCube = ''
      SET @cTrackOrderCube = rdt.RDTGetConfig( @nFunc, 'TrackOrderCube', @cStorerkey) -- (ChewKP07)
      
      --IN00314294 Start
      SELECT @cCartonGroup = CartonGroup 
      FROM dbo.Storer WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
      --IN00314294 End
      		
      SET @nCube = 0 
      SELECT 
         @cUseSequence = UseSequence, 
         @nCube = Cube
      FROM dbo.Cartonization WITH (NOLOCK)
      WHERE (CartonType = @cCartonLabelNo OR Barcode = @cCartonLabelNo)
      AND CartonizationGroup = @cCartonGroup	--IN00314294

      IF @cUseSequence = '1'
      BEGIN
         
         UPDATE dbo.MBOLDetail
            SET CtnCnt1 = CtnCnt1 + 1
                ,Cube   = CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey

      END
      ELSE IF @cUseSequence = '2'
      BEGIN
         UPDATE dbo.MBOLDetail
            SET CtnCnt2 = CtnCnt2 + 1
            ,Cube    =  CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey

      END
      ELSE IF @cUseSequence = '3'
      BEGIN
         UPDATE dbo.MBOLDetail
            SET CtnCnt3 = CtnCnt3 + 1
               ,Cube    =  CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey
      END
      ELSE IF @cUseSequence = '4'
      BEGIN
         UPDATE dbo.MBOLDetail
            SET CtnCnt4 = CtnCnt4 + 1
                ,Cube    =  CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey
      END
      ELSE IF @cUseSequence = '5'
      BEGIN
         UPDATE dbo.MBOLDetail
            SET CtnCnt5 = CtnCnt5 + 1
                ,Cube    =  CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey
      END
      ELSE IF @cUseSequence = '6'
      BEGIN
         UPDATE dbo.MBOLDetail
            SET UserDefine01 = CAST(UserDefine01 AS INT) + 1
                ,Cube    =  CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey
      END
      ELSE IF @cUseSequence = '7'
      BEGIN
         UPDATE dbo.MBOLDetail
            SET UserDefine02 = CAST(UserDefine02 AS INT) + 1
                ,Cube    =  CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey

      END
      ELSE IF @cUseSequence = '8'
      BEGIN
         UPDATE dbo.MBOLDetail
            SET UserDefine03 = CAST(UserDefine03 AS INT) + 1
                ,Cube    =  CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube  ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey

      END
      ELSE IF @cUseSequence = '9'
      BEGIN
         UPDATE dbo.MBOLDetail
            SET UserDefine04 = CAST(UserDefine04 AS INT) + 1
                ,Cube    =  CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube  ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey

      END
      ELSE IF @cUseSequence = '10'
      BEGIN
         UPDATE dbo.MBOLDetail
            SET UserDefine05 = CAST(UserDefine05 AS INT) + 1
                ,Cube    =  CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube  ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey

      END
      ELSE IF @cUseSequence = '11'
      BEGIN
         UPDATE dbo.MBOLDetail
            SET UserDefine09 = CAST(UserDefine09 AS INT) + 1
                ,Cube    =  CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey

      END
      ELSE IF @cUseSequence = '12'
      BEGIN
         UPDATE dbo.MBOLDetail
            SET UserDefine10 = CAST(UserDefine10 AS INT) + 1
                ,Cube    =  CASE WHEN @cTrackOrderCube = '1' THEN @nCube + Cube  ELSE Cube END -- (ChewKP07)
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey

      END

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 72559
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdMBOLDetFail
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_5_Fail
      END

      
      --SET @nLabelCount = @nLabelCount + 1 -- (ChewKP04)

      IF @nLabelCount = 0 OR @nLabelCount > 1
      BEGIN
         SELECT @nLabelScanned = 
               CAST( ISNULL( CtnCnt1, '0') AS INT) + 
               CAST( ISNULL( CtnCnt2, '0') AS INT) + 
               CAST( ISNULL( CtnCnt3, '0') AS INT) + 
               CAST( ISNULL( CtnCnt4, '0') AS INT) + 
               CAST( ISNULL( CtnCnt5, '0') AS INT) + 
               CAST( ISNULL( UserDefine01, '0') AS INT) + 
               CAST( ISNULL( UserDefine02, '0') AS INT) + 
               CAST( ISNULL( UserDefine03, '0') AS INT) + 
               CAST( ISNULL( UserDefine04, '0') AS INT) + 
               CAST( ISNULL( UserDefine05, '0') AS INT) + 
               CAST( ISNULL( UserDefine09, '0') AS INT) + 
               CAST( ISNULL( UserDefine10, '0') AS INT) 
         FROM dbo.MbolDetail WITH (NOLOCK) 
         WHERE MBOLKey = @cMBOLKey
         AND   OrderKey = @cOrderKey

         IF @nLabelCount = @nLabelScanned --CAST( @cLabelScanned AS INT)  -- (james04)
         BEGIN
            SET @nOrderCount = 0
            SELECT @nOrderCount = Count (Orderkey)
            FROM dbo.MBOLDetail WITH (NOLOCK)
            WHERE MBOLKey = @cMBOLKey

            SET @cOutField01 = @cMBOLKey
            SET @cOutField02 = ISNULL(@nOrderCount,0)
            SET @cOutField03 = ''
      
            -- Back to TrackNo Screen
            SET @nScn  = @nScn - 3
            SET @nStep = @nStep - 3   
            
            GOTO Quit      
         END
      
         SET @cOutField01 = ''
         SET @cOutField02 = @nLabelCount
         SET @cOutField03 = ISNULL( @nLabelScanned, 0)
      END
      ELSE IF @nLabelCount = 1 
      BEGIN
         SET @nOrderCount = 0
         SELECT @nOrderCount = Count (Orderkey)
         FROM dbo.MBOLDetail WITH (NOLOCK)
         WHERE MBOLKey = @cMBOLKey

         SET @cOutField01 = @cMBOLKey
         SET @cOutField02 = ISNULL(@nOrderCount,0)
         SET @cOutField03 = ''
   
         -- Back to TrackNo Screen
         SET @nScn  = @nScn - 3
         SET @nStep = @nStep - 3         
      END




   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nOrderCount = 0
      SELECT @nOrderCount = Count (Orderkey)
      FROM dbo.MBOLDetail WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey


      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = ISNULL(@nOrderCount,0)
      SET @cOutField03 = ''

      -- Back to TrackNo Screen
      SET @nScn  = @nScn -3
      SET @nStep = @nStep - 3


   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOutField01 = ''

    END
END
GOTO Quit



/********************************************************************************
Step 6. screen = 2734 -- (ChewKP04)
   MBOLKey : (Field01)
   PalletID: (Field02, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletID = ISNULL(@cInField02,'')
      
      
      IF @cPalletID = ''
      BEGIN
         SET @nErrNo = 72561
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletIDReq
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_6_Fail
      END

      IF EXISTS ( SELECT 1 FROM dbo.MBOLDETAIL WITH (NOLOCK)
                      WHERE MBOLKey <> @cMBOLKey
                      AND PalletKey = @cPalletID  )
      BEGIN
         SET @nErrNo = 72562
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletIDExist
         EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @ErrMsgNextScreen = '1'
         BEGIN
            --SET @nErrNo = 0
            SET @cErrMsg1 = @nErrNo
            SET @cErrMsg2 = @cErrMsg
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         END

         GOTO Step_6_Fail
      END


      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = ISNULL(@nOrderCount,0)
      SET @cOutField03 = ''
   
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4       


   END

   IF @nInputKey = 0 -- ESC
   BEGIN

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      -- Back to TrackNo Screen
      SET @nScn  = @nScn - 5
      SET @nStep = @nStep - 5


   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cOutField02 = ''

    END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg,
       Func          = @nFunc,
       Step          = @nStep,
       Scn           = @nScn,

       StorerKey     = @cStorerKey,
       Facility      = @cFacility,
       Printer       = @cPrinter,
       Printer_Paper = @cPrinter_Paper,
       -- UserName      = @cUserName,

       V_OrderKey    = @cOrderKey,
       V_String1     = @cTrackNo,
       V_String2     = @cMBOLKey,
       V_String3     = @cShipperKey,
       V_String4     = @ErrMsgNextScreen,
       V_String5     = @fOrderWeight,
       V_String6     = @cDecodeSP,
       V_String7     = @cPalletID, -- (ChewKP06)
       V_String8     = @cShowPalletIDScreen, -- (ChewKP06) 
       V_String9     = @cExtendedUpdateSP, -- (ChewKP06) 
       V_String10    = @cNoOfOrdersAllowed, -- (james06)

       V_Integer1    = @nLabelCount,

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
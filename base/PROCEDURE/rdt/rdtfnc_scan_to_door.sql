SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Scan_To_Door                                      */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#173268 - Standard/Generic Scan To Door module                */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-05-17 1.0  Vicky    Created                                          */
/* 2012-04-14 1.1  Shong    Update AdditionalLoc for Door, standardise with  */
/*                          TITAN                                            */
/* 2012-04-21 1.2  Shong    Add SCAC Code validation to RDT Scan To Door     */
/*                          SOS#242325                                       */
/* 2012-05-07 1.3  Ung      SOS243691 Fix chk DropID.Status>5 to >=5 (ung01) */
/* 2012-05-15 1.4  ChewKP   SOS#239201 Reprint Carrier Label (ChewKP01)      */
/* 2012-07-11 1.5  ChewKP   SOS#248678 Check on UPS / FedEx (CheWKP02)       */
/* 2012-07-17 1.6  Ung      SOS248598 Add close truck screen. Support CBOL   */
/* 2012-09-20 1.7  ChewKP   SOS#252309 Remove by Pass Reprint (ChewKP03)     */
/* 2012-09-21 1.8  James    SOS#252309 Include Pallet QC check  (james01)    */
/* 2012-10-01 1.9  James    SOS#252309 Check if plt contain >1 mbol (james02)*/
/* 2013-01-02 2.0  Leong    SOS#265678 - Exclude shipped MBOLKey             */
/* 2015-02-09 2.1  James    SOS316783 - Add ExtendedValidateSP (james03)     */
/* 2015-04-21 2.2  James    SOS316783 - Add ExtendedUpdateSP (james04)       */
/* 2016-09-30 2.3  Ung      Performance tuning                               */
/* 2018-11-15 2.4  TungGH   Performance                                      */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_Scan_To_Door](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
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
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cDropID             NVARCHAR(20),
   @cDoor               NVARCHAR(20),
   @cActDoor            NVARCHAR(20),
   @cLoadkey            NVARCHAR(10),
   @cOrderkey           NVARCHAR(10),
   @cDropIDType         NVARCHAR(10),
   @cMBOLKey            NVARCHAR(10),
   @nCBOLKey            INT,
   @cMBOL_SCAC          NVARCHAR(30),
   @cSCAC_Validation    NVARCHAR(1),

   @nMBOLCnt            INT,
   @cCarrierLBL_Validation NVARCHAR(1), -- (ChewKP01)
   @cOption                NVARCHAR(1), -- (ChewKP01)
   @cErrMsg1               NVARCHAR(20), -- (ChewKP01)
   @cErrMsg2               NVARCHAR(20), -- (ChewKP01)
   @cErrMsg3               NVARCHAR(20), -- (ChewKP01)
   @cErrMsg4               NVARCHAR(20), -- (ChewKP01)
   @cErrMsg5               NVARCHAR(20), -- (ChewKP01)
   @cRSNCode               NVARCHAR(10), -- (ChewKP01)
   @c_AlertMessage         NVARCHAR(255),-- (ChewKP01)
   @c_NewLineChar          NVARCHAR(2),  -- (ChewKP01)
   @cSpecialHandling       NVARCHAR(1),   -- (ChewKP01)
   @cQC_Status             NVARCHAR(1),   -- (james01)
   @nCount                 INT,       -- (james01)
   @cExtendedValidateSP    NVARCHAR( 20),    -- (james03)
   @cSQL                   NVARCHAR(1000),   -- (james03)
   @cSQLParam              NVARCHAR(1000),   -- (james03)
   @cLastDropID            NVARCHAR( 20),    -- (james03)
   @cExtendedUpdateSP      NVARCHAR( 20),    -- (james03)

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
   @cUserName        = UserName,

   @cLoadkey         = V_Loadkey,
   @cOrderkey        = V_Orderkey,
   @cDropID          = V_String1,
   @cDoor            = V_String2,
   @cMBOLkey         = V_String3,
   @cLastDropID      = V_String5,
   
   @nCBOLKey         = V_Integer1,

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
IF @nFunc = 1642
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1642
   IF @nStep = 1 GOTO Step_1   -- Scn = 2330   Drop ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 2331   Door
   IF @nStep = 3 GOTO Step_3   -- Scn = 2332   Option : Reprint Carrier Label -- (ChewKP01)
   IF @nStep = 4 GOTO Step_4   -- Scn = 2333   Reason Code -- (ChewKP01)
   IF @nStep = 5 GOTO Step_5   -- Scn = 2334   Option : Close truck -- (ung02)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1642)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2330
   SET @nStep = 1

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
   SET @cDropID = ''
   SET @cDoor = ''
   SET @cMBOLKey = ''
   SET @nCBOLKey = 0
   SET @cLoadkey = ''
   SET @cOrderkey = ''
   SET @cLastDropID = ''

   -- Prep next screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2330
   DROP ID (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDropID = @cInField01

      --When PalletID is blank
      IF @cDropID = ''
      BEGIN
         SET @nErrNo = 69241
         SET @cErrMsg = rdt.rdtgetmessage( 69241, @cLangCode, 'DSP') --DROP ID req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      --DROP ID Not Exists
      IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cDropID)
      BEGIN
         SET @nErrNo = 69242
         SET @cErrMsg = rdt.rdtgetmessage( 69242, @cLangCode, 'DSP') --Invalid DROP ID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cDropID AND LabelPrinted <> 'Y')
      BEGIN
         SET @nErrNo = 69251
         SET @cErrMsg = rdt.rdtgetmessage( 69251, @cLangCode, 'DSP') --LabelNotPrinted
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cDropID AND Status = '9')
      BEGIN
         SET @nErrNo = 69252
         SET @cErrMsg = rdt.rdtgetmessage( 69252, @cLangCode, 'DSP') --DropIDLoadedToDoor
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK)
                     WHERE DropID = @cDropID
                     AND Status >= '5'
                     AND Status < '9') --(ung01)
      BEGIN
         SET @nErrNo = 69243
         SET @cErrMsg = rdt.rdtgetmessage( 69243, @cLangCode, 'DSP') --PalletNotClosed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Check if this pallet has been audit before (james01)
      IF EXISTS (SELECT 1 FROM rdt.rdtQCLog WITH (NOLOCK)
                 WHERE StorerKey = @cStorerkey
                 AND   PalletID = @cDropID
                 AND   TranType = 'P'
                 AND   Completed = 'Y')
      BEGIN
         SET @cQC_Status = ''
         SELECT TOP 1 @cQC_Status = [STATUS]
         FROM rdt.rdtQCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND   PalletID = @cDropID
         AND   TranType = 'P'
         AND   Completed = 'Y'
         ORDER BY ScanNo DESC

         IF ISNULL(@cQC_Status, '') = ''
         BEGIN
            SET @nErrNo = 69267
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLT Not Audit
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         IF ISNULL(@cQC_Status, '') = '1'
         BEGIN
            SET @nErrNo = 69268
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLT Audit Fail
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      END

      -- Check if all contain for the pallet belong to 1 mbol (james02)
      IF OBJECT_ID('tempdb..#tempmbol') IS NOT NULL
         DROP TABLE #tempmbol

      CREATE TABLE #tempmbol (MBOLKey NVARCHAR( 10))

      INSERT INTO #tempmbol (MBOLKey)
      SELECT MD.MBOLKey FROM dbo.MBOL M WITH (NOLOCK)   -- phase 2
      JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON MD.OrderKey = PD.OrderKey
      JOIN dbo.DropIDDetail dd WITH (NOLOCK) ON PD.CaseID = DD.ChildID
      JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
      WHERE M.Status <> '9' AND D.DropID = @cDropID -- SOS#265678
      GROUP BY MD.MBOLKey
      UNION ALL
      SELECT MD.MBOLKey FROM dbo.MBOL M WITH (NOLOCK)   -- phase 1
      JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON MD.OrderKey = PD.OrderKey
      JOIN dbo.DropID D WITH (NOLOCK) ON PD.DropID = D.DropID
      WHERE M.Status <> '9' AND D.Dropid = @cDropID -- SOS#265678
      GROUP BY MD.MBOLKey

      SELECT @nCount = count(1) FROM #tempmbol

      IF @nCount > 1
      BEGIN
         SET @nErrNo = 69269
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLT >1 MBOL
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      SELECT @cLoadkey = ISNULL(RTRIM(DP.Loadkey), '')
      FROM dbo.DROPID DP WITH (NOLOCK)
      WHERE  DP.DropID = @cDropID

      IF @cLoadkey = ''
      BEGIN
         SET @nErrNo = 69244
         SET @cErrMsg = rdt.rdtgetmessage( 69244, @cLangCode, 'DSP') --DropIDNoLoadkey
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Get MBOLkey
      -- Discrete or Conso Pack?
      SELECT TOP 1 @cOrderkey = ISNULL(RTRIM(PH.Orderkey), '')
      FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      WHERE PD.DropID = @cDropID
      AND   PH.Loadkey = @cLoadkey

      IF @cOrderKey <> '' -- Discrete
      BEGIN
         SELECT @cMBOLKey = ISNULL(RTRIM(MD.MBOLKey), '')
         FROM dbo.MBOLDETAIL MD WITH (NOLOCK)
         WHERE  MD.Orderkey = @cOrderKey
      END/*
      ELSE -- Conso
      BEGIN
        SET @nMBOLCnt = 0

        SELECT @nMBOLCnt = COUNT(DISTINCT MD.MBOLKey)
        FROM dbo.MBOLDETAIL MD WITH (NOLOCK)
        WHERE  MD.Loadkey = @cLoadkey

        IF @nMBOLCnt < 1
        BEGIN
             SET @nErrNo = 69245
             SET @cErrMsg = rdt.rdtgetmessage( 69245, @cLangCode, 'DSP') --LPInMultiMBOL
             EXEC rdt.rdtSetFocusField @nMobile, 1
             GOTO Step_1_Fail
        END
        ELSE
        BEGIN
           SELECT DISTINCT @cMBOLKey = ISNULL(RTRIM(MD.MBOLKey), '')
           FROM dbo.MBOLDETAIL MD WITH (NOLOCK)
           WHERE  MD.Loadkey = @cLoadkey
        END*/
      ELSE
      BEGIN
         -- Assumption/Facts??
         -- 1 pallet go to 1 mbol only
         -- SOS#265678 (Start)
         -- SELECT TOP 1
         --    @cMBOLKey = ISNULL(RTRIM(MD.MBOLKey), '')
         -- FROM dbo.MBOLDETAIL MD WITH (NOLOCK)
         -- WHERE  MD.Loadkey = @cLoadkey

         SELECT TOP 1 @cMBOLKey = ISNULL(RTRIM(M.MBOLKey), '')
         FROM dbo.MBOL M WITH (NOLOCK)
         JOIN dbo.MBOLDETAIL MD WITH (NOLOCK)
         ON (M.MBOLKey = MD.MBOLKey)
         WHERE M.Status <> '9'
           AND MD.Loadkey = @cLoadkey
         -- SOS#265678 (End)
      END

      IF @cMBOLKey = ''
      BEGIN
         SET @nErrNo = 69246
         SET @cErrMsg = rdt.rdtgetmessage( 69246, @cLangCode, 'DSP') --No MBOL
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND Status = '9')
      BEGIN
         SET @nErrNo = 69247
         SET @cErrMsg = rdt.rdtgetmessage( 69247, @cLangCode, 'DSP') --MBOL Shipped
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- SOS#242325
      SET @cSCAC_Validation = rdt.RDTGetConfig( @nFunc, 'SCAC_Validation', @cStorerkey)

      IF @cSCAC_Validation = '1'
      BEGIN
         SET @cMBOL_SCAC = ''
         SELECT @cMBOL_SCAC = ISNULL(M.Carrierkey,'')
         FROM dbo.MBOL M WITH (NOLOCK)
         WHERE M.MbolKey = @cMBOLKey

         --SOS#242325
         IF ISNULL(RTRIM(@cMBOL_SCAC), '') = '' OR ISNULL(RTRIM(@cMBOL_SCAC), '') = 'UNKN'
         BEGIN
            SET @nErrNo = 69254
            SET @cErrMsg = rdt.rdtgetmessage( 69254, @cLangCode, 'DSP') --BAD SCAC
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
         ELSE
         BEGIN
            IF EXISTS (SELECT 1
                       FROM dbo.MBOL M WITH (NOLOCK)
                       JOIN MBOLDETAIL MD WITH (NOLOCK) ON MD.MbolKey = M.MbolKey
                       JOIN ORDERS o WITH (NOLOCK) ON O.OrderKey = MD.OrderKey
                       WHERE M.MBOLKey = @cMBOLKey
                       AND   O.LoadKey = @cLoadkey
                       AND   (O.UserDefine02 <> @cMBOL_SCAC OR
                              O.UserDefine02 = 'UNKN'))
            BEGIN
               SET @nErrNo = 69255
               SET @cErrMsg = rdt.rdtgetmessage( 69255, @cLangCode, 'DSP') --WRONG SCAC
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_1_Fail
            END
         END
      END

      -- Get Door
      SELECT @nCBOLKey = ISNULL( CBOLKey, 0) FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey
      IF @nCBOLKey = 0
         SELECT @cDoor = RTRIM( ISNULL( PlaceOfLoading, '')) FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey
      ELSE
         SELECT @cDoor = RTRIM( ISNULL( Userdefine01, '')) FROM dbo.CBOL WITH (NOLOCK) WHERE CBOLKey = @nCBOLKey

      IF @cDoor = ''
      BEGIN
          SET @nErrNo = 69248
          SET @cErrMsg = rdt.rdtgetmessage( 69248, @cLangCode, 'DSP') --Door Not Assigned
          EXEC rdt.rdtSetFocusField @nMobile, 1
          GOTO Step_1_Fail
      END

      -- (ChewKP01)
      SET @cCarrierLBL_Validation = ''
      SET @cCarrierLBL_Validation = rdt.RDTGetConfig( @nFunc, 'CarrierLBL_Validation', @cStorerkey)

      IF @cCarrierLBL_Validation = '1'
      BEGIN
         -- Get SpecialHandling
         SET @cSpecialHandling = ''
         SELECT TOP 1 @cSpecialHandling =  ISNULL(RTRIM(O.SpecialHandling), '')
         FROM dbo.MBOLDetail MD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey
         WHERE MD.MBOLKey = @cMBOLKey

         --IF @cSpecialHandling IN ('X','U') -- (ChewKP02) --
         -- (ChewKP03)
         IF EXISTS ( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK)
                     WHERE LISTNAME = 'SCANTODOOR'
                     AND Code = @cSpecialHandling)
         BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK)
                           WHERE DropID = @cDropID
                           AND LabelPrinted = '' )
               BEGIN

                     --prepare next screen variable
                     SET @cOutField01 = @cDropID
                     SET @cOutField02 = ''

                     SET @nScn = @nScn + 2
                     SET @nStep = @nStep + 2

                     GOTO QUIT
               END

               IF EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
                                 INNER JOIN DropIDDetail DD WITH (NOLOCK) ON DD.ChildID = PD.LabelNo
                                 WHERE DD.DropID = @cDropID
                                   AND ISNULL(PD.UPC,'') = '' )
               BEGIN
-- (ChewKP03)
--                    SET @nErrNo = 69261
--                    SET @cErrMsg = rdt.rdtgetmessage( 69261, @cLangCode, 'DSP') --Invalid UPC
--                    EXEC rdt.rdtSetFocusField @nMobile, 1
--                    GOTO Step_1_Fail

                     -- (ChewKP03)
                     --prepare next screen variable
                     SET @cOutField01 = @cDropID
                     SET @cOutField02 = ''

                     SET @nScn = @nScn + 2
                     SET @nStep = @nStep + 2

                     GOTO QUIT
               END
         END



      END

      -- (james03)
      -- Extended validate
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> '' 
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nAfterStep, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cDropID         NVARCHAR( 20), ' +
               '@cMbolKey        NVARCHAR( 10), ' +
               '@cDoor           NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@cRSNCode        NVARCHAR( 10), ' +
               '@nAfterStep      INT,           ' + 
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nStep, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      SET @cLastDropID = @cDropID

      --prepare next screen variable
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cDoor

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF rdt.RDTGetConfig( @nFunc, 'ScanToDoorCloseTruck', @cStorerkey) = '1'
      BEGIN
         -- Go to close truck screen
         SET @cOutField01 = '' -- Option

         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4

         GOTO Quit
      END

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
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cDropID = ''
      SET @cOutField01 = ''
    END
END
GOTO Quit

/********************************************************************************
Step 2. (screen = 2331)
   DROP ID:    (Field01)
   DOOR:       (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cActDoor = @cInField03

      --When Door is blank
      IF @cActDoor = ''
      BEGIN
         SET @nErrNo = 69249
         SET @cErrMsg = rdt.rdtgetmessage( 69249, @cLangCode, 'DSP') --Door req
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END

      IF @cActDoor <> @cDoor
      BEGIN
         SET @nErrNo = 69250
         SET @cErrMsg = rdt.rdtgetmessage( 69250, @cLangCode, 'DSP') --Invalid Door
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END

      -- (james03)
      -- Extended validate
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> '' 
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nAfterStep, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cDropID         NVARCHAR( 20), ' +
               '@cMbolKey        NVARCHAR( 10), ' +
               '@cDoor           NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@cRSNCode        NVARCHAR( 10), ' +
               '@nAfterStep      INT,           ' + 
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nStep, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END

      BEGIN TRAN

      -- Update DropID Table
      UPDATE dbo.DROPID WITH (ROWLOCK)
        SET DropLoc = @cActDoor,
            AdditionalLoc = @cActDoor,
            Status = '9',
            EditDate = GETDATE(),
            EditWho = @cUserName
      WHERE Loadkey = @cLoadkey
      AND   DropID = @cDropID

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 69253
         SET @cErrMsg = rdt.rdtgetmessage( 69253, @cLangCode, 'DSP') --'Upd DropID Fail'
         ROLLBACK TRAN
         GOTO QUIT
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END

      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      IF ISNULL( @cExtendedUpdateSP, '') <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' + 
            '@cLangCode       NVARCHAR( 3),  ' +
            '@cDropID         NVARCHAR( 20), ' +
            '@cMbolKey        NVARCHAR( 10), ' +
            '@cDoor          NVARCHAR( 20), ' +
            '@cOption         NVARCHAR( 1),  ' +
            '@cRSNCode        NVARCHAR( 10), ' +
            '@nAfterStep      INT,           ' + 
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nStep,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

      END
      -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cToLocation   = @cActDoor,
         @cToID         = @cDropID,
         @cLoadkey      = @cLoadkey,
         @cOrderkey     = @cOrderkey,
         @cRefNo3       = 'Door',
         @nStep         = @nStep

      --prepare next screen variable
      SET @cDropID = ''
      SET @cOutField01 = ''

      -- Go back prev screen to scan next Drop ID
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare prev screen variable
      SET @cDropID = ''
      SET @cOutField01 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cActDoor = ''

      -- Reset this screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cDoor
      SET @cOutField03 = ''
      SET @cOutField04 = ''
  END
END
GOTO Quit



/********************************************************************************
Step 3. (screen = 2332)
   DROP ID:    (Field01)
   OPTION: (Field02, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption= ISNULL(@cInField02,'')

      --When Door is blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 69256
         SET @cErrMsg = rdt.rdtgetmessage( 69256, @cLangCode, 'DSP') --Option Req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_3_Fail
      END

      IF @cOption NOT IN ('1') -- (ChewKP03)
      BEGIN
         SET @nErrNo = 69257
         SET @cErrMsg = rdt.rdtgetmessage( 69257, @cLangCode, 'DSP') --Inv Option
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_3_Fail
      END

-- (ChewKP03)
--      IF @cOption = '1'
--      BEGIN
--
--         SET @cOutField01 = @cDropID
--         SET @cOutField02 = ''
--
--         -- Go to Reason Code Screen
--         SET @nScn = @nScn + 1
--         SET @nStep = @nStep + 1
--
--         GOTO QUIT
--      END

      IF @cOption = '1' -- (ChewKP03)
      BEGIN

            SET @nErrNo = 69258
            SET @cErrMsg1 = '69258'
            SET @cErrMsg2 = 'Reprint Label'
            SET @cErrMsg3 = 'Please Proceed To'
            SET @cErrMsg4 = 'Func: 1792'
            SET @cErrMsg5 = 'ReprintCarrierLBL'

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
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare prev screen variable
      SET @cDropID = ''
      SET @cOutField01 = ''

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
  END
END
GOTO Quit

/********************************************************************************
Step 4. (screen = 2333)
   DROP ID:    (Field01)
   ReasonCode: (Field02, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cRSNCode = ISNULL(@cInField02,'')

      --When Door is blank
      IF @cRSNCode = ''
      BEGIN
         SET @nErrNo = 69259
         SET @cErrMsg = rdt.rdtgetmessage( 69259, @cLangCode, 'DSP') --RSNCode Req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_4_Fail
      END

      SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)

      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' RDT Scan To Door Alert: ' + @c_NewLineChar
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DropID : ' + @cDropID  + @c_NewLineChar
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ReasonCode: ' + @cRSNCode + @c_NewLineChar
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' UserKey: ' + @cUserName + @c_NewLineChar

      -- Insert LOG Alert
      SELECT @b_Success = 1
      EXECUTE dbo.nspLogAlert
       @c_ModuleName   = 'rdtfnc_Scan_To_Door',
       @c_AlertMessage = @c_AlertMessage,
       @n_Severity     = 0,
       @b_success      = @b_Success OUTPUT,
       @n_err          = @nErrNo  OUTPUT,
       @c_errmsg       = @cErrMsg OUTPUT

      IF NOT @b_Success = 1
      BEGIN
         GOTO Step_4_Fail
      END

      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cDoor
      SET @cOutField03 = ''

      -- GOTO Door Screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare prev screen variable
      SET @cOutField01 = @cDropID
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''


      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
  END
END
GOTO Quit


/********************************************************************************
Step 5. (screen = 2332)
   CLOSE TRUCK?
   1=YES
   2=NO
   OPTION: (Field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption= ISNULL(@cInField01,'')

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 69262
         SET @cErrMsg = rdt.rdtgetmessage( 69256, @cLangCode, 'DSP') --Option Req
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1','2')
      BEGIN
         SET @nErrNo = 69263
         SET @cErrMsg = rdt.rdtgetmessage( 69257, @cLangCode, 'DSP') --Inv Option
         SET @cOutField01 = '' -- Option
         GOTO Quit
      END

      IF @cOption = '1' -- YES
      BEGIN
         IF @cDoor <> ''
         BEGIN
            -- Get DropID not yet scan to door
            DECLARE @nDropIDFound INT
            SET @nDropIDFound = 0 --False
            IF @nCBOLKey = 0
               SELECT TOP 1 @nDropIDFound = 1
               FROM dbo.DropID WITH (NOLOCK)
                  JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON (DropID.LoadKey = MD.LoadKey)
               WHERE DropID.Status < '9'
                  AND MD.MBOLKey = @cMBOLKey
            ELSE
               SELECT TOP 1 @nDropIDFound = 1
               FROM dbo.DropID WITH (NOLOCK)
                  JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON (DropID.LoadKey = MD.LoadKey)
                  JOIN dbo.MBOL WITH (NOLOCK) ON (MBOL.MBOLKey = MD.MBOLKey)
               WHERE DropID.Status < '9'
                  AND MBOL.CBOLKey = @nCBOLKey

            -- Check DropID not yet scan to door
            IF @nDropIDFound = 1 --True
            BEGIN
               SET @cErrMsg1 = rdt.rdtgetmessage( 69264, @cLangCode, 'DSP') -- There are pallets
               SET @cErrMsg2 = rdt.rdtgetmessage( 69265, @cLangCode, 'DSP') -- not scan to door.
               SET @cErrMsg3 = rdt.rdtgetmessage( 69266, @cLangCode, 'DSP') -- Cannot Close
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
               GOTO Quit
            END
            /*
            -- (james03)
            -- Extended validate
            SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
            IF @cExtendedValidateSP = '0'
               SET @cExtendedValidateSP = ''

            IF @cExtendedValidateSP <> '' 
            BEGIN

               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile         INT,       '     +
                     '@nFunc           INT,       '     +
                     '@cLangCode       NVARCHAR( 3),  ' +
                     '@nStep           INT,       '     + 
                     '@nInputKey       INT,       '     +
                     '@cDropID         NVARCHAR( 20), ' +
                     '@cMbolKey        NVARCHAR( 10), ' +
                     '@cDoor           NVARCHAR( 20), ' +
                     '@cOption         NVARCHAR( 1), '  +
                     '@cRSNCode        NVARCHAR( 10), ' +
                     '@nErrNo          INT OUTPUT,    ' +
                     '@cErrMsg         NVARCHAR( 20) OUTPUT'  

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cLastDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END*/
         END
         /*
         -- Back to menu
         SET @nFunc = @nMenu
         SET @nScn  = @nMenu
         SET @nStep = 0
         SET @cOutField01 = ''
         */
      END

      /*
      IF @cOption = '2' -- NO
      BEGIN
         -- Back to menu
         SET @nFunc = @nMenu
         SET @nScn  = @nMenu
         SET @nStep = 0
         SET @cOutField01 = ''
      END
      */

      -- (james03)
      -- Extended validate
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> '' 
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nAfterStep, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cDropID         NVARCHAR( 20), ' +
               '@cMbolKey        NVARCHAR( 10), ' +
               '@cDoor           NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@cRSNCode        NVARCHAR( 10), ' +
               '@nAfterStep      INT,           ' + 
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nStep, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      IF ISNULL( @cExtendedUpdateSP, '') <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' + 
            '@cLangCode       NVARCHAR( 3),  ' +
            '@cDropID         NVARCHAR( 20), ' +
            '@cMbolKey        NVARCHAR( 10), ' +
            '@cDoor          NVARCHAR( 20), ' +
            '@cOption         NVARCHAR( 1),  ' +
            '@cRSNCode        NVARCHAR( 10), ' +
            '@nAfterStep      INT,           ' + 
            '@nErrNo          INT           OUTPUT, ' + 
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cDropID, @cMbolKey, @cDoor, @cOption, @cRSNCode, @nStep,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

      END

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END

   IF @nInputKey = 0 -- ENTER
   BEGIN
      -- Back to DropID screen
      SET @cOutField01 = @cDropID
      SET @cOutField02 = ''

      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
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
       -- UserName      = @cUserName,

       V_Loadkey     = @cLoadkey,
       V_Orderkey    = @cOrderkey,
       V_String1     = @cDropID,
       V_String2     = @cDoor,
       V_String3     = @cMBOLKey,
       V_String5     = @cLastDropID,
       
       V_Integer1    = @nCBOLKey,

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
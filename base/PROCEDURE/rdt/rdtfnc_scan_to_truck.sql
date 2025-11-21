SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Scan_To_Truck                                     */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: RDT Scan To Truck - SOS#133340                                   */
/*          Related Module: RDT Case Picking                                 */
/*                          RDT GOH Picking                                  */
/*                          RDT GOH Settage                                  */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2009-04-06 1.0  Vicky    Created                                          */
/* 2009-06-17 1.0  Vicky    To Allow >1 person to process Load (Vicky01)     */
/* 2009-20-27 1.2  James    Add EditWho & EditDate when update (james01)     */
/* 2012-05-16 1.3  ChewKP   Begin Tran and Commit Tran issues (ChewKP01)     */
/* 2013-11-14 1.4  Leong    SOS# 294711 - Incorrect @nErrNo in @cErrMsg.     */
/* 2016-09-30 1.5  Ung      Performance tuning                               */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_Scan_To_Truck](
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
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cMBOLKey            NVARCHAR(10),
   @cLoadKey            NVARCHAR(10),
   @cRefNo              NVARCHAR(40),
   @cURNNo              NVARCHAR(40),
   @cOption             NVARCHAR(1),
   @cTotalCaseCnt       NVARCHAR(5),
   @cCaseCnt            NVARCHAR(5),
   @cDefaultOption      NVARCHAR(1),
   @cType               NVARCHAR(5),
   @cDataWindow         NVARCHAR(50),
   @cTargetDB           NVARCHAR(10),
   @cPickSlipNo         NVARCHAR(10),
   @cCntMBOLCase        NVARCHAR(5),
   @cTotalMBOLCase      NVARCHAR(5),

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
   @nStep            = Step,       @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
  @cPrinter         = Printer,
   @cUserName    = UserName,

   @cLoadKey         = V_LoadKey,
   @cMBOLKey         = V_String1,
  -- @cRefNo           = V_String2,
   @cTotalCaseCnt    = V_String3,
   @cCaseCnt         = V_String4,
   @cDefaultOption   = V_String5,
   @cOption          = V_String6,
   @cType            = V_String7,
  -- @cURNNo           = V_String8,
   @cCntMBOLCase     = V_String9,
   @cTotalMBOLCase   = V_String10,

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
IF @nFunc = 1625
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1625
   IF @nStep = 1 GOTO Step_1   -- Scn = 1990   MBOL#, LOAD#
   IF @nStep = 2 GOTO Step_2   -- Scn = 1991   URN No/CASE ID
   IF @nStep = 3 GOTO Step_3   -- Scn = 1992   Load Closed Option
   IF @nStep = 4 GOTO Step_4   -- Scn = 1992   Cases Remaining Msg
   IF @nStep = 5 GOTO Step_5   -- Scn = 1992   Over-Scanned Msg
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1900)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 1990
   SET @nStep = 1


   -- initialise all variable
   SET @cMBOLKey = ''
   SET @cLoadKey = ''
   SET @cCaseCnt = 0
   SET @cTotalCaseCnt = 0

   -- Prep next screen var
   SET @cOutField01 = ''  -- MBOL#
   SET @cOutField02 = ''  -- LOAD#
END
GOTO Quit

/********************************************************************************
Step 1. screen = 1990
   MBOL# (Field01, input)
   LOAD# (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cMBOLKey = @cInField01
      SET @cLoadKey = @cInField02

      --When MBOL# is blank
      IF @cMBOLKey = ''
      BEGIN
         SET @nErrNo = 66676
         SET @cErrMsg = rdt.rdtgetmessage( 66676, @cLangCode, 'DSP') --MOBL# req
         GOTO Step_1_MBOL_Fail
      END

      -- Check if MBOL# exists
      IF NOT EXISTS ( SELECT 1
         FROM dbo.MBOL WITH (NOLOCK)
         WHERE MBOLKey = @cMBOLKey)
      BEGIN
         SET @nErrNo = 66677
         SET @cErrMsg = rdt.rdtgetmessage( 66677, @cLangCode, 'DSP') --Invalid MBOL#
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- MBOL#
         GOTO Step_1_MBOL_Fail
      END

      -- Check if MBOL# has been shipped
      IF EXISTS ( SELECT 1
         FROM dbo.MBOL WITH (NOLOCK)
         WHERE MBOLKey = @cMBOLKey
         AND   Status = '9')
      BEGIN
         SET @nErrNo = 66678
         SET @cErrMsg = rdt.rdtgetmessage( 66678, @cLangCode, 'DSP') --MBOL Shipped
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- MBOL#
         GOTO Step_1_MBOL_Fail
      END

      --When LOAD# is blank
      IF @cLoadKey = ''
      BEGIN
         SET @nErrNo = 66679
         SET @cErrMsg = rdt.rdtgetmessage( 66679, @cLangCode, 'DSP') --LOAD# req
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOAD#
         GOTO Step_1_LOAD_Fail
      END

      -- Check if LOAD# exists
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOADPLAN WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey)
      BEGIN
         SET @nErrNo = 66680
         SET @cErrMsg = rdt.rdtgetmessage( 66680, @cLangCode, 'DSP') --Invalid LOAD#
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOAD#
         GOTO Step_1_LOAD_Fail
      END

      --check diff facility
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOADPLAN WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
           AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 66681
         SET @cErrMsg = rdt.rdtgetmessage( 66681, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LoadKey
         GOTO Step_1_LOAD_Fail
      END

      --check diff storer
      IF NOT EXISTS ( SELECT TOP 1 1
         FROM dbo.LOADPLANDETAIL LPD WITH (NOLOCK)
         JOIN dbo.ORDERS ORD WITH (NOLOCK) ON (ORD.Loadkey = LPD.Loadkey AND ORD.Orderkey = LPD.Orderkey)
         WHERE LPD.Loadkey = @cLoadKey
            AND ORD.Storerkey = @cStorerkey)
      BEGIN
         SET @nErrNo = 66682
         SET @cErrMsg = rdt.rdtgetmessage( 66682, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LoadKey
         GOTO Step_1_LOAD_Fail
      END

     -- check if Loadkey is populated to MBOL
      IF NOT EXISTS ( SELECT 1
      FROM dbo.MBOLDETAIL WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey
      AND   LoadKey = @cLoadKey)
      BEGIN
         SET @nErrNo = 66683
         SET @cErrMsg = rdt.rdtgetmessage( 66683, @cLangCode, 'DSP') --Wrong LOAD#
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Loadkey
         GOTO Step_1_LOAD_Fail
      END

--      -- Check If MBOL + LOAD is currently being processed by other user
--      IF EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
--                 WHERE MBOLKey = @cMBOLKey
--                 AND   LoadKey = @cLoadKey
--                 AND   AddWho <> @cUserName)
--      BEGIN
--         SET @nErrNo = 66693
--         SET @cErrMsg = rdt.rdtgetmessage( 66693, @cLangCode, 'DSP') --LOAD Processed
--         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Loadkey
--         GOTO Step_1_LOAD_Fail
--      END
--
      -- Check If MBOL + LOAD is already processed  (Status = 9)
      IF EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
                 WHERE MBOLKey = @cMBOLKey
                 AND   LoadKey = @cLoadKey
                 -- AND   AddWho = @cUserName
                 AND   Status = '9')
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
                 WHERE MBOLKey = @cMBOLKey
                 AND   LoadKey = @cLoadKey
                 -- AND   AddWho = @cUserName
                 AND   Status = '1')
        BEGIN
             SET @nErrNo = 66694
             SET @cErrMsg = rdt.rdtgetmessage( 66694, @cLangCode, 'DSP') --LOAD Processed
             EXEC rdt.rdtSetFocusField @nMobile, 2 -- Loadkey
             GOTO Step_1_LOAD_Fail
        END
      END

--      SELECT @cPickSlipNo = PickslipNo
--      FROM  dbo.PACKHEADER WITH (NOLOCK)
--      WHERE LoadKey = @cLoadKey

      SELECT @cPickSlipNo = PickHeaderKey
      FROM  dbo.PickHeader WITH (NOLOCK)
      WHERE ExternOrderKey = @cLoadKey

      SELECT @cType = ISNULL(RTRIM(CartonType), '')
      FROM dbo.PACKINFO WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      SELECT @cTotalMBOLCase = SUM(TTLCASE.TotalMBOLCase)
      FROM (
         SELECT TotalMBOLCase = MAX(PD.CartonNo)
         FROM dbo.PACKDETAIL PD WITH (NOLOCK)
         JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         JOIN dbo.PICKHEADER PCH WITH (NOLOCK) ON (PH.PickSlipNo = PCH.PickHeaderKey)
         JOIN dbo.MBOLDETAIL MBD WITH (NOLOCK) ON (PCH.ExternOrderkey = MBD.Loadkey)
         WHERE MBD.MBOLKey = @cMBOLKey
         GROUP BY PD.Pickslipno) AS TTLCASE

      -- To be Processed
      IF NOT EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
                     WHERE MBOLKey = @cMBOLKey
                     AND   LoadKey = @cLoadKey
                     -- AND   AddWho = @cUserName (Vicky01)
                     AND   Status = '1')
      BEGIN
          --BEGIN TRAN  -- (ChewKP01)

           IF @cType = 'GOH'
           BEGIN
                INSERT INTO RDT.RDTScanToTruck
                (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate, EditWho, EditDate) --james01
                SELECT @cMBOLKey, @cLoadKey, @cType, '', ISNULL(RTRIM(PIF.RefNo), ''), '1', @cUserName, GETDATE(), @cUserName, GETDATE()  --james01
                FROM dbo.PACKINFO PIF WITH (NOLOCK)
                WHERE PickSlipNo = @cPickSlipNo
           END
           ELSE
           BEGIN
                INSERT INTO RDT.RDTScanToTruck
                (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate, EditWho, EditDate) --james01
                SELECT DISTINCT @cMBOLKey, @cLoadKey, @cType, ISNULL(RTRIM(PD.CartonNo), ''), ISNULL(RTRIM(PIF.RefNo), ''), '1', @cUserName, GETDATE(), @cUserName, GETDATE()  --james01
                FROM dbo.PACKDETAIL PD WITH (NOLOCK)
                JOIN dbo.PACKINFO PIF WITH (NOLOCK) ON (PD.PickslipNo = PIF.PickSlipNo AND PD.CartonNo = PIF.CartonNo)
                WHERE PD.PickSlipNo = @cPickSlipNo
           END

           IF @@ERROR <> 0
           BEGIN
               SET @nErrNo = 66695
               SET @cErrMsg = rdt.rdtgetmessage( 66695, @cLangCode, 'DSP') --'LockInfoFail' -- SOS# 294711
               --ROLLBACK TRAN    -- (ChewKP01)
               GOTO Step_1_Fail
            END

            -- COMMIT TRAN  -- (ChewKP01)
      END

      SELECT @cTotalCaseCnt = CAST(COUNT(*) AS CHAR)
      FROM  RDT.RDTScanToTruck WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey
      AND   LoadKey = @cLoadKey
      -- AND   AddWho = @cUserName (Vicky01)

      SELECT @cCaseCnt = CAST(COUNT(*) AS CHAR)
      FROM  RDT.RDTScanToTruck WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey
      AND   LoadKey = @cLoadKey
      -- AND   AddWho = @cUserName (Vicky01)
      AND   Status = '9'

      --prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = RTRIM(@cCaseCnt) + '/' + RTRIM(@cTotalCaseCnt)

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- MBOLKey
      SET @cOutField02 = '' -- LAODKey

      SET @cCaseCnt = 0
      SET @cTotalCaseCnt = 0
   END
   GOTO Quit

   Step_1_MBOL_Fail:
   BEGIN
      SET @cMBOLkey = ''
      SET @cLoadkey = ''

      -- Reset this screen var
      SET @cOutField01 = ''  -- MBOLKey
      SET @cOutField02 = ''  -- LAODKey
  END

  Step_1_LOAD_Fail:
  BEGIN
      SET @cLoadkey = ''

      -- Reset this screen var
      SET @cOutField01 = @cMBOLkey
      SET @cOutField02 = ''  -- LAODKey
  END

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = @cMBOLkey  -- MBOLKey
      SET @cOutField02 = @cLoadkey  -- LAODKey
    END

END
GOTO Quit

/********************************************************************************
Step 2. (screen = 1991) URN No/CASE ID
   URN No/CASE ID: (Field01 input)
   # OF CASES: 99999/99999
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cRefNo = @cInField01

      --When URN / CASE ID is blank
      IF @cRefNo = ''
      BEGIN
         SET @nErrNo = 66684
         SET @cErrMsg = rdt.rdtgetmessage( 66684, @cLangCode, 'DSP') --URN/CASEID req
         GOTO Step_2_Fail
      END

      --Check If URN No/CASE ID exists
      IF @cType <> 'GOH'
      BEGIN
         IF NOT EXISTS ( SELECT 1
            FROM RDT.RDTScanToTruck WITH (NOLOCK)
            WHERE MBOLKey = @cMBOLKey
            AND   LoadKey = @cLoadKey
            --AND   AddWho = @cUserName
            AND   Status = '1'
            AND   RefNo = RTRIM(@cRefNo))
         BEGIN
            SET @nErrNo = 66685
            SET @cErrMsg = rdt.rdtgetmessage( 66685, @cLangCode, 'DSP') --Invld URN/CSID
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- URN No / CaseID
            GOTO Step_2_Fail
         END
         ELSE
         BEGIN
              SELECT @cURNNo = RTRIM(URNNo)
              FROM RDT.RDTScanToTruck WITH (NOLOCK)
              WHERE MBOLKey = @cMBOLKey
              AND   LoadKey = @cLoadKey
             -- AND   AddWho = @cUserName
              AND   Status = '1'
              AND   RefNo = RTRIM(@cRefNo)
         END
      END
      ELSE
      BEGIN

         IF NOT EXISTS ( SELECT 1
            FROM RDT.RDTScanToTruck WITH (NOLOCK)
            WHERE MBOLKey = @cMBOLKey
            AND   LoadKey = @cLoadKey
         --   AND   AddWho = @cUserName
            AND   Status = '1'
            AND   URNNo = RTRIM(@cRefNo))
         BEGIN
            SET @nErrNo = 66686
            SET @cErrMsg = rdt.rdtgetmessage( 66686, @cLangCode, 'DSP') --Invld URN/CSID -- SOS# 294711
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- URN No / CaseID
            GOTO Step_2_Fail
         END
      END

      IF @cType <> 'GOH'
      BEGIN
         -- Validate printer setup
         IF ISNULL(@cPrinter, '') = ''
         BEGIN
            SET @nErrNo = 66687
            SET @cErrMsg = rdt.rdtgetmessage( 66687, @cLangCode, 'DSP') --NoLoginPrinter -- SOS# 294711
            GOTO Step_2_Fail
         END

         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                @cTargetDB = ISNULL(RTRIM(TargetDB), '')
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND ReportType = 'URNLABEL'

         IF ISNULL(@cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 66688
            SET @cErrMsg = rdt.rdtgetmessage( 66688, @cLangCode, 'DSP') --DWNOTSetup -- SOS# 294711
            GOTO Step_2_Fail
         END

         IF ISNULL(@cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 66689
            SET @cErrMsg = rdt.rdtgetmessage( 66689, @cLangCode, 'DSP') --TgetDB Not Set -- SOS# 294711
            GOTO Step_2_Fail
         END

         IF EXISTS ( SELECT 1
                     FROM dbo.ORDERS ORDERS WITH (NOLOCK)
                     JOIN dbo.STORER STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
                     LEFT OUTER JOIN dbo.STORER CS WITH (NOLOCK) ON (ORDERS.ConsigneeKey = CS.StorerKey)
                     WHERE ORDERS.StorerKey = @cStorerKey
                     AND ORDERS.LoadKey = @cLoadKey
                     AND UPPER(ISNULL(RTRIM(CS.ConsigneeFor), '')) = 'M&S')
         BEGIN
            --BEGIN TRAN   -- (ChewKP01)

            -- Parameter & URN format to be consider after URN label FBR is done
            -- Call printing spooler
            INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Printer, NoOfCopy, Mobile, TargetDB)
            VALUES('PRINT_URNLABEL', 'URNLABEL', '0', @cDataWindow, 2, SUBSTRING(@cURNNo, 1, 30), SUBSTRING(@cURNNo, 31, 2), @cPrinter, 1, @nMobile, @cTargetDB)

            IF @@ERROR <> 0
            BEGIN
             --ROLLBACK TRAN      -- (ChewKP01)

             SET @nErrNo = 66690
             SET @cErrMsg = rdt.rdtgetmessage( 66690, @cLangCode, 'DSP') --'InsertPRTFail' -- SOS# 294711
             GOTO Step_2_Fail
            END
            -- COMMIT TRAN      -- (ChewKP01)
         END
      END

      -- Update URN record
      IF @cType <> 'GOH'
      BEGIN
         UPDATE RDT.RDTScanToTruck WITH (ROWLOCK)
              SET Status = '9',
                  EditWho = @cUserName,    --james01
                  EditDate = GETDATE()     --james01
         WHERE MBOLKey = @cMBOLKey
         AND   LoadKey = @cLoadKey
         --AND   AddWho = @cUserName
         AND   Status = '1'
         AND   RefNo = RTRIM(@cRefNo)
      END
      ELSE
      BEGIN
         UPDATE RDT.RDTScanToTruck WITH (ROWLOCK)
              SET Status = '9',
                  EditWho = @cUserName,    --james01
                  EditDate = GETDATE()     --james01
         WHERE MBOLKey = @cMBOLKey
         AND   LoadKey = @cLoadKey
         --AND   AddWho = @cUserName
         AND   Status = '1'
         AND   URNNo = RTRIM(@cRefNo)
      END

      SELECT @cTotalCaseCnt = CAST(COUNT(*) AS CHAR)
      FROM  RDT.RDTScanToTruck WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey
      AND   LoadKey = @cLoadKey
      --AND   Status = '1'
      -- AND   AddWho = @cUserName (Vicky01)

      SELECT @cCaseCnt = CAST(COUNT(*) AS CHAR)
      FROM  RDT.RDTScanToTruck WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey
      AND   LoadKey = @cLoadKey
      -- AND   AddWho = @cUserName (Vicky01)
      AND   Status = '9'

      IF CAST(@cCaseCnt as INT) = CAST(@cTotalCaseCnt AS INT)
      BEGIN
         --prepare next screen variable
         SET @cOutField01 = '1' -- Default Option = 1
         SET @cOutField02 = ''
         
         -- Go to Load Closed Screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE IF CAST(@cCaseCnt as INT) > CAST(@cTotalCaseCnt AS INT)
      BEGIN
         --prepare next screen variable
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         
         -- Go to Over-Scanned Screen
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
      END
      ELSE
      BEGIN
         --prepare next screen variable
         SET @cOutField01 = ''
         SET @cOutField02 = RTRIM(@cCaseCnt) + '/' + RTRIM(@cTotalCaseCnt)
         
         -- Loop same screen
         SET @nScn = @nScn
         SET @nStep = @nStep
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @cCaseCnt = CAST(COUNT(*) AS CHAR)
      FROM  RDT.RDTScanToTruck WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey
      AND   LoadKey = @cLoadKey
      -- AND   AddWho = @cUserName (Vicky01)
      AND   Status = '9'

      SELECT @cTotalCaseCnt = CAST(COUNT(*) AS CHAR)
      FROM  RDT.RDTScanToTruck WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey
      AND   LoadKey = @cLoadKey
      AND   Status = '0'
      -- AND   AddWho = @cUserName (Vicky01)

      IF CAST(@cCaseCnt as INT) < CAST(@cTotalCaseCnt AS INT)
      BEGIN
         --prepare next screen variable
         SET @cOutField01 = RTRIM(CAST(CAST(@cTotalCaseCnt AS INT) - CAST(@cCaseCnt as INT) AS CHAR)) + '/' + RTRIM(@cTotalCaseCnt)
         SET @cOutField02 = ''
      
         -- Go to Load Closed Screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
      ELSE
      BEGIN
         SET @cOutField01 = '' -- MBOLKey
         SET @cOutField02 = '' -- LAODKey
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- MBOL#
         
         SET @cCaseCnt = 0
         SET @cTotalCaseCnt = 0
         
         -- go to previous screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cRefNo = ''
      
      -- Reset this screen var
      SET @cOutField01 = ''  -- URN
      SET @cOutField02 = RTRIM(@cCaseCnt) + '/' + RTRIM(@cTotalCaseCnt)
   END
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 1992) LOAD CLOSED OPTION
   OPTION: (Field01 input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 66691
         SET @cErrMsg = rdt.rdtgetmessage( 66691, @cLangCode, 'DSP') --Option needed -- SOS# 294711
         GOTO Step_3_Fail
      END

      -- Validate option
      IF @cOption <> '1'
      BEGIN
         SET @nErrNo = 66692
         SET @cErrMsg = rdt.rdtgetmessage( 66692, @cLangCode, 'DSP') --Invalid option -- SOS# 294711
         GOTO Step_3_Fail
      END

      IF @cOption = '1'
      BEGIN
         SELECT @cCntMBOLCase = COUNT(*)
         FROM  RDT.RDTScanToTruck WITH (NOLOCK)
         WHERE MBOLKey = @cMBOLKey
         AND   Status = '9'

         IF @cCntMBOLCase = @cTotalMBOLCase
         BEGIN
            UPDATE dbo.MBOL WITH (ROWLOCK)
              SET DepotStatus = 'LOADED'
            WHERE MBOLKey = @cMBOLKey
         END
      END

      -- Get to Screen 1 to scan next load
      SET @cMBOLkey = ''
      SET @cLoadkey = ''
      SET @cPickSlipNo = ''
      SET @cType = ''
      SET @cCaseCnt = '0'
      SET @cTotalCaseCnt = '0'
      SET @cCntMBOLCase = '0'
      SET @cTotalMBOLCase = '0'

      -- Reset this screen var
      SET @cOutField01 = ''  -- MBOLKey
      SET @cOutField02 = ''  -- LAODKey

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField01 = '1' -- Default Option = '1'

      SET @nScn = @nScn
      SET @nStep = @nStep
   END
END
GOTO Quit

/********************************************************************************
Step 4. (screen = 1993) Cases Remaining Msg
********************************************************************************/
Step_4:
BEGIN
   IF  @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC
   BEGIN
          SET @cOutField01 = ''
          SET @cOutField02 = RTRIM(@cCaseCnt) + '/' + RTRIM(@cTotalCaseCnt)

          -- go to previous screen
          SET @nScn = @nScn - 2
          SET @nStep = @nStep - 2
   END
   GOTO Quit
END
GOTO Quit


/********************************************************************************
Step 5. (screen = 1994) Over-Scanned Msg
********************************************************************************/
Step_5:
BEGIN
   IF  @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC
   BEGIN
          SET @cOutField01 = ''
          SET @cOutField02 = RTRIM(@cCaseCnt) + '/' + RTRIM(@cTotalCaseCnt)

          -- go to previous screen
          SET @nScn = @nScn - 3
          SET @nStep = @nStep - 3
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
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg,
       Func          = @nFunc,
       Step          = @nStep,
       Scn           = @nScn,

       StorerKey     = @cStorerKey,
       Facility      = @cFacility,
       Printer       = @cPrinter,
       -- UserName      = @cUserName,

       V_LoadKey     = @cLoadKey,
       V_String1     = @cMBOLKey,
     --  V_String2     = @cRefNo,
       V_String3     = @cTotalCaseCnt,
       V_String4     = @cCaseCnt,
       V_String5     = @cDefaultOption,
       V_String6     = @cOption,
       V_String7     = @cType,
    --   V_String8     = @cURNNo,
       V_String9     = @cCntMBOLCase,
       V_String10    = @cTotalMBOLCase,

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
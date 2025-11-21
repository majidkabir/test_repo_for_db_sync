SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Close_PTS_Tote                                    */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#183249 - Close the last Tote of the PTS batch                */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-07-26 1.0  Vicky    Created                                          */
/* 2010-09-25 1.1  James    Not allow Store PPA tote to close tote (james01) */
/* 2010-10-19 1.2  James    Allow to reprint the manifest using diffent      */
/*                          func (only when tote is not closed) (james02)    */
/* 2010-10-25 1.3  Shong    Ignore Message02 (From Tote#) for Tote           */
/*                           Consolidation (SHONG01)                         */
/* 2010-11-02 1.4  Shong    ERROR#70578 For Consolidated Tote, allow to close*/
/*                          Tote (SHONG02)                                   */
/* 2010-12-29 1.5  James    Allow to reprint the manifest using diffent      */
/*                          func (regardless of orders status) (james03)     */
/* 2014-08-28 1.6  ChewKP   SOS#318380 -- Unity Enhancement (ChewKP01)       */
/* 2015-10-01 1.7  Audrey   SOS353851 - declare Toteno from 18 to 20 (ang01) */
/* 2016-09-30 1.8  Ung      Performance tuning                               */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_Close_PTS_Tote](
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

   @cToToteNo           NVARCHAR(20),   --ang01
   @cOption             NVARCHAR(1),
   @cReportType         NVARCHAR(10),
   @cPrintJobName       NVARCHAR(50),
   @cDataWindow         NVARCHAR(50),
   @cTargetDB           NVARCHAR(20),
   @nReprintOption      INT,        -- (james02)
   @cSQL                NVARCHAR(1000), -- (ChewKP01)
   @cSQLParam           NVARCHAR(1000), -- (ChewKP01)
   @cExtendedValidateSP NVARCHAR(30),   -- (ChewKP01)
   @cExtendedUpdateSP   NVARCHAR(30),   -- (ChewKP01)
   @cDeviceProfileLogKey NVARCHAR(10),  -- (ChewKP01)
   @cNewToteNo          NVARCHAR(20),   -- (ChewKP01)
   @cNewToteScn         NVARCHAR(1) ,   -- (ChewKP01)


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

   @cToToteNo        = V_String1,
   @cOption          = V_String2,
   @nReprintOption   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
   @cExtendedValidateSP = V_String4, -- (ChewKP01)
   @cExtendedUpdateSP   = V_String5, -- (ChewKP01)
   @cOption             = V_String6, -- (ChewKP01)
   @cDeviceProfileLogKey = V_String7, -- (ChewKP01)


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
IF @nFunc IN (1776, 1778, 1780, 1805)   -- (ChewKP01)
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1776
   IF @nStep = 1 GOTO Step_1   -- Scn = 2480 Tote No
   IF @nStep = 2 GOTO Step_2   -- Scn = 2481 Print Option
   IF @nStep = 3 GOTO Step_3   -- Scn = 2482 New ToteNo -- (ChewKP01)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1776)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2480
   SET @nStep = 1

   -- (ChewKP01)
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
   BEGIN
      SET @cExtendedValidateSP = ''
   END

   -- (ChewKP01)
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
   BEGIN
      SET @cExtendedUpdateSP = ''
   END

   -- (james02)
   SET @nReprintOption = 0

   IF @nFunc IN (1778, 1780)
   BEGIN
      SET @nReprintOption = 1
      SET @cOutField02 = 'REPRINT TOTE'
      SET @cOutField03 = 'MANIFEST/LABEL'
   END
   ELSE  IF @nFunc = 1776
   BEGIN
      SET @nReprintOption = 0
      SET @cOutField02 = 'CLOSE PTS TOTE'
      SET @cOutField03 = ''
   END
   ELSE IF @nFunc = 1805 -- (ChewKP01)
   BEGIN
      SET @nReprintOption = 0
      SET @cOutField02 = 'CLOSE TOTE'
      SET @cOutField03 = ''
   END

   -- initialise all variable
   SET @cToToteNo = ''
   SET @cOption = ''

   -- Prep next screen var
   SET @cOutField01 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2480
   Tote No: (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToToteNo = @cInField01

      --When Lane is blank
      IF @cToToteNo = ''
      BEGIN
         SET @nErrNo = 70566
         SET @cErrMsg = rdt.rdtgetmessage( 70566, @cLangCode, 'DSP') --Tote No req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END




      -- (ChewKP01)
      IF @cExtendedValidateSP <> ''
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN



            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToToteNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cToToteNo      NVARCHAR( 20), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'


            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToToteNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_1_Fail
            END

         END
      END
      ELSE
      BEGIN

         --Check if Tote No Exists
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE DropID = @cToToteNo)
         BEGIN
             SET @nErrNo = 70567
             SET @cErrMsg = rdt.rdtgetmessage( 70567, @cLangCode, 'DSP') --ToteNotExists
             EXEC rdt.rdtSetFocusField @nMobile, 1
             GOTO Step_1_Fail
         END

         -- (james02)
         IF @nReprintOption = 0
         BEGIN
            IF EXISTS(
               SELECT 1 FROM DROPID WITH (NOLOCK)
               WHERE DropID = @cToToteNo
               AND LabelPrinted = 'Y' AND ManifestPrinted='Y')
            BEGIN
                SET @nErrNo = 70585
                SET @cErrMsg = rdt.rdtgetmessage( 70585, @cLangCode, 'DSP') --LabelPrinted
                EXEC rdt.rdtSetFocusField @nMobile, 1
                GOTO Step_1_Fail
            END

            -- (james01)
            -- If exists dropid which is not shipped/canc and is store ppa tote
            -- not allow to close tote. it must use pts store sort module to pack and close
            -- Ignore Message02 (From Tote#) for Tote Consolidation
            IF EXISTS (SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                       JOIN dbo.PickDetail PD WITH (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
                       JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                       JOIN dbo.DROPID D WITH (NOLOCK) ON TD.DROPID = D.DROPID and O.LoadKey = D.LoadKey
                       WHERE TD.DropID = @cToToteNo
                          AND TD.PickMethod = 'PIECE'
                          AND O.StorerKey = @cStorerKey
                          AND O.Status NOT IN ('9', 'CANC')
                          AND TD.Message02=''  -- (SHONG01)
                          AND D.LabelPrinted <> 'Y')  -- (SHONG02)
            BEGIN
                SET @nErrNo = 70578
                SET @cErrMsg = rdt.rdtgetmessage( 70578, @cLangCode, 'DSP') --DO PTS 2 CLOSE
                EXEC rdt.rdtSetFocusField @nMobile, 1
                GOTO Step_1_Fail
            END
         END
      END

      --prepare next screen variable
      SET @cOutField01 = ''

      IF @nFunc IN (1778, 1780)
      BEGIN
         SET @cOutField02 = 'REPRINT TOTE'
         SET @cOutField03 = 'MANIFEST/LABEL'
         SET @cOutField04 = ''
         SET @cOutField05 = '1 = MANIFEST'
         SET @cOutField06 = '9 = LABEL'
         SET @cOutField07 = 'PRESS ESC TO GO BACK'
      END
      ELSE IF @nFunc IN (1776)
      BEGIN
         SET @cOutField02 = 'CLOSE PTS TOTE'
         SET @cOutField03 = 'PRINT LABEL AND'
         SET @cOutField04 = 'MANIFEST ??'
         SET @cOutField05 = '1 = YES'
         SET @cOutField06 = '9 = NO'
         SET @cOutField07 = ''
      END
      ELSE  IF @nFunc IN (1805)
      BEGIN
         SET @cOutField03 = 'CLOSE PTS TOTE ?'
         SET @cOutField05 = '1 = YES'
         SET @cOutField06 = '9 = NO'
         SET @cOutField07 = ''
      END


      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''

      SET @cToToteNo = ''
      SET @cOption = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cToToteNo = ''
      SET @cOption = ''

      SET @cOutField01 = ''
    END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2481
   Option (Field01)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 70568
         SET @cErrMsg = rdt.rdtgetmessage( 70568, @cLangCode, 'DSP') --Option req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_2_Fail
      END

      IF ISNULL(@cOption, '') <> '1' AND ISNULL(@cOption, '') <> '9'
      BEGIN
         SET @nErrNo = 70569
         SET @cErrMsg = rdt.rdtgetmessage( 70569, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_2_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- (ChewKP01)
         IF @cExtendedUpdateSP <> ''
         BEGIN

               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN

                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cToToteNo, @cOption, @cNewToteNo, @cNewToteScn OUTPUT, @cDeviceProfileLogKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile        INT, ' +
                     '@nFunc          INT, ' +
                     '@cLangCode      NVARCHAR( 3), ' +
                     '@cUserName      NVARCHAR( 18), ' +
                     '@cFacility      NVARCHAR( 5), ' +
                     '@cStorerKey     NVARCHAR( 15), ' +
                     '@nStep          INT, ' +
                     '@cToToteNo      NVARCHAR( 20), ' +
                     '@cOption        NVARCHAR(  1), ' +
                     '@cNewToteNo     NVARCHAR( 20), ' +
                     '@cNewToteScn    NVARCHAR(  1) OUTPUT, ' +
                     '@cDeviceProfileLogKey  NVARCHAR( 10) OUTPUT, ' +
                     '@nErrNo         INT           OUTPUT, ' +
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'


                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cToToteNo, @cOption, @cNewToteNo, @cNewToteScn OUTPUT, @cDeviceProfileLogKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO QUIT

                  IF @nFunc = 1805
                  BEGIN
                     IF @cNewToteScn = '1'
                     BEGIN
                        SET @cOutField01 = @cToToteNo
                        SET @cOutField02 = ''

                        SET @nScn = @nScn + 1
                        SET @nStep = @nStep + 1
                     END
                     ELSE
                     BEGIN
                         SET @cOutField02 = 'CLOSE PTS TOTE'
                         SET @cOutField03 = ''
                         SET @cToToteNo = ''
                         SET @cOption = ''

                         SET @cOutField01 = ''

                         SET @nScn = @nScn - 1
                         SET @nStep = @nStep - 1
                     END
                  END
                  ELSE
                  BEGIN
                     SET @cToToteNo = ''
                     SET @cOption = ''

                     SET @nScn = @nScn - 1
                     SET @nStep = @nStep - 1
                  END
               END
         END
         ELSE
         BEGIN
            -- Printing process
            IF ISNULL(@cPrinter, '') = ''
            BEGIN
                  SET @nErrNo = 70570
                  SET @cErrMsg = rdt.rdtgetmessage( 70570, @cLangCode, 'DSP') --NoLabelPrinter
                  GOTO Step_2_Fail
            END

            -- (james02)
            IF @nReprintOption = 0
            BEGIN
               IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo
                             AND LabelPrinted = 'Y')
               BEGIN
                  SET @cReportType = 'SORTLABEL'
                  SET @cPrintJobName = 'PRINT_SORTLABEL'

                  SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                         @cTargetDB = ISNULL(RTRIM(TargetDB), '')
                  FROM RDT.RDTReport WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   ReportType = @cReportType

                  IF ISNULL(@cDataWindow, '') = ''
                  BEGIN
                     SET @nErrNo = 70571
                     SET @cErrMsg = rdt.rdtgetmessage( 70571, @cLangCode, 'DSP') --DWNOTSetup
                     GOTO Step_2_Fail
                  END

                  IF ISNULL(@cTargetDB, '') = ''
                  BEGIN
                     SET @nErrNo = 70572
                     SET @cErrMsg = rdt.rdtgetmessage( 70572, @cLangCode, 'DSP') --TgetDBNotSet
                     GOTO Step_2_Fail
                  END

                  BEGIN TRAN

                  SET @nErrNo = 0
                  EXEC RDT.rdt_BuiltPrintJob
                     @nMobile,
                     @cStorerKey,
                     @cReportType,
                     @cPrintJobName,
                     @cDataWindow,
                     @cPrinter,
                     @cTargetDB,
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     @cStorerKey,
                     @cToToteNo

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 70573
                     SET @cErrMsg = rdt.rdtgetmessage( 70573, @cLangCode, 'DSP') --'InsertPRTFail'
                     ROLLBACK TRAN
                     GOTO Step_2_Fail
                  END
                  ELSE
                  BEGIN
                      UPDATE DROPID WITH (ROWLOCK)
                       SET LabelPrinted = 'Y'
                      WHERE DropID = @cToToteNo
                      IF @@ERROR <> 0
                      BEGIN
                        SET @nErrNo = 70584
                        SET @cErrMsg = rdt.rdtgetmessage( 70584, @cLangCode, 'DSP') --'UpdDropIdFailed'
                        ROLLBACK TRAN
                        GOTO Step_2_Fail
                      END

                      COMMIT TRAN
                  END
               END
            END


            -- (james02)
            IF @nReprintOption = 0
            BEGIN
               IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo
                             AND ManifestPrinted = 'Y')
               BEGIN
                  SET @cReportType = 'SORTMANFES'
                  SET @cPrintJobName = 'PRINT_SORTMANFES'

                  IF ISNULL(@cPrinter_Paper, '') = ''
                  BEGIN
                     SET @nErrNo = 70574
                     SET @cErrMsg = rdt.rdtgetmessage( 70574, @cLangCode, 'DSP') --NoPaperPrinter
                      GOTO Step_2_Fail
                  END

                  SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                         @cTargetDB = ISNULL(RTRIM(TargetDB), '')
                  FROM RDT.RDTReport WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   ReportType = @cReportType

                  IF ISNULL(@cDataWindow, '') = ''
                  BEGIN
                     SET @nErrNo = 70575
                     SET @cErrMsg = rdt.rdtgetmessage( 70575, @cLangCode, 'DSP') --DWNOTSetup
                     GOTO Step_2_Fail
                END

                  IF ISNULL(@cTargetDB, '') = ''
                  BEGIN
                     SET @nErrNo = 70576
                     SET @cErrMsg = rdt.rdtgetmessage( 70576, @cLangCode, 'DSP') --TgetDBNotSet
                     GOTO Step_2_Fail
                  END

                  BEGIN TRAN

                  SET @nErrNo = 0
                  EXEC RDT.rdt_BuiltPrintJob
                     @nMobile,
                     @cStorerKey,
                     @cReportType,
                     @cPrintJobName,
                     @cDataWindow,
                     @cPrinter_Paper,
                     @cTargetDB,
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     @cStorerKey,
                     @cToToteNo

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 70577
                     SET @cErrMsg = rdt.rdtgetmessage( 70577, @cLangCode, 'DSP') --'InsertPRTFail'
                     ROLLBACK TRAN
                     GOTO Step_2_Fail
                  END
                  ELSE
                  BEGIN
                      UPDATE DROPID WITH (ROWLOCK)
                       SET ManifestPrinted = 'Y'
                      WHERE DropID = @cToToteNo
                      IF @@ERROR <> 0
                      BEGIN
                        SET @nErrNo = 70586
                        SET @cErrMsg = rdt.rdtgetmessage( 70586, @cLangCode, 'DSP') --'UpdDropIdFailed'
                        ROLLBACK TRAN
                        GOTO Step_2_Fail
                      END

                     COMMIT TRAN
                  END
               END
            END
            ELSE
            BEGIN
               -- Only allow to reprint if tote is closed (james02)
               IF NOT EXISTS (SELECT 1 FROM DROPID WITH (NOLOCK)
                  WHERE DropID = @cToToteNo
                  AND   ManifestPrinted='Y' )
               BEGIN
                  SET @nErrNo = 70583
                  SET @cErrMsg = rdt.rdtgetmessage( 70583, @cLangCode, 'DSP') --CLOSE TOTE 1ST
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Step_2_Fail
               END

               IF @nFunc = 1778
               BEGIN
                  SET @cReportType = 'SORTMANFES'
                  SET @cPrintJobName = 'PRINT_SORTMANFES'
               END
               ELSE
               IF @nFunc = 1780  -- (james03)
               BEGIN
                  SET @cReportType = 'RPRTMANFES'
                  SET @cPrintJobName = 'PRINT_RPRTMANFES'
               END

               IF ISNULL(@cPrinter_Paper, '') = ''
               BEGIN
                  SET @nErrNo = 70579
                  SET @cErrMsg = rdt.rdtgetmessage( 70579, @cLangCode, 'DSP') --NoPaperPrinter
                   GOTO Step_2_Fail
               END

               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')
               FROM RDT.RDTReport WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReportType = @cReportType

               IF ISNULL(@cDataWindow, '') = ''
               BEGIN
                  SET @nErrNo = 70580
                  SET @cErrMsg = rdt.rdtgetmessage( 70580, @cLangCode, 'DSP') --DWNOTSetup
                  GOTO Step_2_Fail
               END

               IF ISNULL(@cTargetDB, '') = ''
               BEGIN
                  SET @nErrNo = 70581
                  SET @cErrMsg = rdt.rdtgetmessage( 70581, @cLangCode, 'DSP') --TgetDBNotSet
                  GOTO Step_2_Fail
               END

               BEGIN TRAN

               SET @nErrNo = 0
               EXEC RDT.rdt_BuiltPrintJob
                  @nMobile,
                  @cStorerKey,
                  @cReportType,
                  @cPrintJobName,
                  @cDataWindow,
                  @cPrinter_Paper,
                  @cTargetDB,
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT,
                  @cStorerKey,
                  @cToToteNo

               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 70582
                  SET @cErrMsg = rdt.rdtgetmessage( 70582, @cLangCode, 'DSP') --'InsertPRTFail'
                  ROLLBACK TRAN
                  GOTO Step_2_Fail
               END

               COMMIT TRAN
            END

            SET @cOutField01 = ''

            IF @nFunc IN (1778, 1780)
            BEGIN
               SET @cOutField02 = 'REPRINT TOTE'
               SET @cOutField03 = 'MANIFEST/LABEL'
            END
            ELSE
            BEGIN
               SET @cOutField02 = 'CLOSE PTS TOTE'
               SET @cOutField03 = ''
            END

            SET @cToToteNo = ''
            SET @cOption = ''

            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
         END

      END

      IF @cOption = '9'
      BEGIN
         -- (ChewKP01)
         IF @cExtendedUpdateSP <> ''
         BEGIN

               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN

                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cDropID, @cOption, @cNewToteNo, @cNewToteScn OUTPUT, @cDeviceProfileLogKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile        INT, ' +
                     '@nFunc          INT, ' +
                     '@cLangCode      NVARCHAR( 3), ' +
                     '@cUserName      NVARCHAR( 18), ' +
                     '@cFacility      NVARCHAR( 5), ' +
                     '@cStorerKey     NVARCHAR( 15), ' +
                     '@nStep          INT, ' +
                     '@cDropID        NVARCHAR( 20), ' +
                     '@cOption        NVARCHAR(  1), ' +
                     '@cNewToteNo     NVARCHAR( 20), ' +
                     '@cNewToteScn    NVARCHAR(  1) OUTPUT, ' +
                     '@cDeviceProfileLogKey  NVARCHAR( 10) OUTPUT, ' +
                     '@nErrNo         INT           OUTPUT, ' +
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'


                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cToToteNo, @cOption, @cNewToteNo, @cNewToteScn OUTPUT, @cDeviceProfileLogKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO QUIT

                  SET @cOutField03 = ''

                  SET @cToToteNo = ''
                  SET @cNewToteNo = ''
                  SET @cOption = ''

                  SET @nScn = @nScn - 1
                  SET @nStep = @nStep - 1
               END
         END
         ELSE
         BEGIN
            IF @nReprintOption = 1
            BEGIN
               IF @nFunc = 1778
               BEGIN
                  SET @cReportType = 'SORTLABEL'
           SET @cPrintJobName = 'PRINT_SORTLABEL'
               END
               ELSE
               IF @nFunc = 1780  -- (james03)
               BEGIN
                  SET @cReportType = 'RPRTLABEL'
                  SET @cPrintJobName = 'PRINT_RPRTLABEL'
               END

               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')
               FROM RDT.RDTReport WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReportType = @cReportType

               IF ISNULL(@cDataWindow, '') = ''
               BEGIN
                  SET @nErrNo = 70587
                  SET @cErrMsg = rdt.rdtgetmessage( 70587, @cLangCode, 'DSP') --DWNOTSetup
                  GOTO Step_2_Fail
               END

               IF ISNULL(@cTargetDB, '') = ''
               BEGIN
                  SET @nErrNo = 70588
                  SET @cErrMsg = rdt.rdtgetmessage( 70588, @cLangCode, 'DSP') --TgetDBNotSet
                  GOTO Step_2_Fail
               END

               BEGIN TRAN

               SET @nErrNo = 0
               EXEC RDT.rdt_BuiltPrintJob
                  @nMobile,
                  @cStorerKey,
                  @cReportType,
                  @cPrintJobName,
                  @cDataWindow,
                  @cPrinter,
                  @cTargetDB,
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT,
                  @cStorerKey,
                  @cToToteNo

               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 70589
                  SET @cErrMsg = rdt.rdtgetmessage( 70589, @cLangCode, 'DSP') --'InsertPRTFail'
                  ROLLBACK TRAN
                  GOTO Step_2_Fail
               END

               COMMIT TRAN
            END

            SET @cOutField01 = ''

            IF @nFunc IN (1778, 1780)
            BEGIN
               SET @cOutField02 = 'REPRINT TOTE'
               SET @cOutField03 = 'MANIFEST/LABEL'
            END
            ELSE
            BEGIN
               SET @cOutField02 = 'CLOSE PTS TOTE'
               SET @cOutField03 = ''
            END

            SET @cToToteNo = ''
            SET @cOption = ''

            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
         END
      END      -- @cOption = '9'
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''

      IF @nFunc IN (1778, 1780)
      BEGIN
         SET @cOutField02 = 'REPRINT TOTE'
         SET @cOutField03 = 'MANIFEST/LABEL'
      END
      ELSE IF @nFunc = 1776
      BEGIN
         SET @cOutField02 = 'CLOSE PTS TOTE'
         SET @cOutField03 = ''
      END
      ELSE IF @nFunc = 1805
      BEGIN
         SET @cOutField02 = 'CLOSE PTS TOTE'
         SET @cOutField03 = ''
      END

      SET @cToToteNo = ''
      SET @cOption = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOption = ''

      SET @cOutField01 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 3. screen = 2482
   Close Tote No : (Field01)
   New Tote No : (Field02, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cNewToteNo = ISNULL(RTRIM(@cInField02),'' )


      --When Lane is blank
      IF @cNewToteNo = ''
      BEGIN
         SET @nErrNo = 70590
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteNoReq
         GOTO Step_3_Fail
      END

      -- (ChewKP01)


      IF @cExtendedUpdateSP <> ''
      BEGIN

            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cDropID, @cOption, @cNewToteNo, @cNewToteScn OUTPUT, @cDeviceProfileLogKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3), ' +
                  '@cUserName      NVARCHAR( 18), ' +
                  '@cFacility      NVARCHAR( 5), ' +
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@nStep          INT, ' +
                  '@cDropID        NVARCHAR( 20), ' +
                  '@cOption        NVARCHAR(  1), ' +
                  '@cNewToteNo     NVARCHAR( 20), ' +
                  '@cNewToteScn    NVARCHAR(  1) OUTPUT, ' +
                  '@cDeviceProfileLogKey  NVARCHAR( 10) OUTPUT, ' +
                  '@nErrNo         INT           OUTPUT, ' +
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'


               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cToToteNo, @cOption, @cNewToteNo, @cNewToteScn OUTPUT, @cDeviceProfileLogKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO QUIT


            END
      END

      IF @nFunc IN (1778, 1780)
      BEGIN
         SET @cOutField02 = 'REPRINT TOTE'
         SET @cOutField03 = 'MANIFEST/LABEL'
      END
      ELSE IF @nFunc = 1776
      BEGIN
         SET @cOutField02 = 'CLOSE PTS TOTE'
         SET @cOutField03 = ''
      END
      ELSE IF @nFunc = 1805
      BEGIN
         SET @cOutField02 = 'CLOSE PTS TOTE'
         SET @cOutField03 = ''

         SET @nErrNo = 91752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NewToteOpen

      END

      SET @cOutField01 = ''

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END


--   IF @nInputKey = 0 -- ESC
--   BEGIN
--      -- Back to menu
--      SET @nFunc = @nMenu
--      SET @nScn  = @nMenu
--      SET @nStep = 0
--
--      SET @cOutField01 = ''
--
--      SET @cToToteNo = ''
--      SET @cOption = ''
--   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cNewToteNo = ''
      SET @cOutField02 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1
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

       V_String1     = @cToToteNo,
       V_String2     = @cOption,
       V_String3     = @nReprintOption,
       V_String4     = @cExtendedValidateSP,
       V_String5     = @cExtendedUpdateSP,
       V_String6     = @cOption,
       V_String7     = @cDeviceProfileLogKey,


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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PrtPltManifest                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Report/Label printing                                   */
/*          SOS93811 - Pick By Drop ID                                  */
/*          SOS93812 - Pick By Drop ID                                  */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2008-02-27 1.0  jwong    Created                                     */
/* 2008-06-03 1.1  jwong    Remove checking on picklsip type            */
/* 2008-06-03 1.2  jwong    Change the way to check validity storerkey  */
/* 2016-09-30 1.3  Ung      Performance tuning                          */  
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_PrtPltManifest] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,


   @cStorer         NVARCHAR( 15),
   @cPrinter        NVARCHAR( 10),
   @cUserName       NVARCHAR( 18),
   @cFacility       NVARCHAR( 5),
   @cDataWindow     NVARCHAR( 50), 
   @cTargetDB       NVARCHAR( 10), 
   @cPickSlipNo     NVARCHAR( 10),
   @cExternOrderKey NVARCHAR( 20),
      
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

-- Load RDT.RDTMobRec
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cStorer     = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,
   @cPrinter    = Printer, 

   @cExternOrderKey = V_String1,
   @cPickSlipNo     = V_String2,

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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 971
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 971
   IF @nStep = 1 GOTO Step_1   -- Scn = 1720. PSno
   IF @nStep = 2 GOTO Step_2   -- Scn = 1721. Option
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 515)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1720
   SET @nStep = 1

END
GOTO Quit

/********************************************************************************
Step 1. Screen = 1720
   PSNO (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = @cInField01

      -- Validate blank PickSlipNo
      IF @cPickSlipNo = '' OR @cPickSlipNo IS NULL
      BEGIN
         SET @nErrNo = 64001
         SET @cErrMsg = rdt.rdtgetmessage( 64001, @cLangCode,'DSP') -- PSNO required
         GOTO Step_1_Fail
      END

      DECLARE @cChkStorerKey  NVARCHAR( 15)
      DECLARE @nCnt           INT
      DECLARE @dScanInDate    DATETIME
      DECLARE @dScanOutDate   DATETIME

      -- Get pickheader info
      SELECT TOP 1
         @cExternOrderKey = ExternOrderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      -- Validate pickslipno
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 64002
         SET @cErrMsg = rdt.rdtgetmessage( 64002, @cLangCode,'DSP') -- Invalid PSNO
         GOTO Step_1_Fail
      END

      -- Get picking info
      SELECT TOP 1
         @dScanInDate = ScanInDate
      FROM dbo.PickingInfo WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      -- Validate pickslip not scan in
      IF @dScanInDate IS NULL
      BEGIN
         SET @nErrNo = 64005
         SET @cErrMsg = rdt.rdtgetmessage( 64005, @cLangCode,'DSP') -- PS not scan in
         GOTO Step_1_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.PickHeader PH WITH (NOLOCK) 
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON PH.OrderKey = PD.Orderkey
         WHERE PH.PickHeaderKey = @cPickSlipNo
            AND PD.STATUS < '5')
      BEGIN
         SET @nErrNo = 64006
         SET @cErrMsg = rdt.rdtgetmessage( 64006, @cLangCode,'DSP') -- PltNotFullPick
         GOTO Step_1_Fail
      END

      -- Prepare print screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' -- Option
      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- Go to print screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = '' -- PSNO
   END
END
GOTO Quit

/********************************************************************************
Step 2. Screen = 1721
   PSNO (field02)
   Option (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 1)

      -- Screen mapping
      SET @cOption = @cInField02
      
      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 64007
         SET @cErrMsg = rdt.rdtgetmessage( 64007, @cLangCode, 'DSP') --Option needed
         GOTO Step_2_Fail
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 64008
         SET @cErrMsg = rdt.rdtgetmessage( 64008, @cLangCode, 'DSP') --Invalid option
         GOTO Step_2_Fail
      END

      -- Validate printer setup
  		IF ISNULL(@cPrinter, '') = ''
		BEGIN			
	      SET @nErrNo = 64009
	      SET @cErrMsg = rdt.rdtgetmessage( 64009, @cLangCode, 'DSP') --NoLoginPrinter
	      GOTO Step_2_Fail
		END
		       
      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
             @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
	   FROM RDT.RDTReport WITH (NOLOCK) 
	   WHERE StorerKey = @cStorer
         AND ReportType = CASE WHEN @cOption = '1' THEN 'BATMNFEST' 
               ELSE 'LPLabel' END
	
      IF ISNULL(@cDataWindow, '') = ''
      BEGIN
         SET @nErrNo = 64010
         SET @cErrMsg = rdt.rdtgetmessage( 64010, @cLangCode, 'DSP') --DWNOTSetup
         GOTO Step_2_Fail
      END

      IF ISNULL(@cTargetDB, '') = ''
      BEGIN
         SET @nErrNo = 64011
         SET @cErrMsg = rdt.rdtgetmessage( 64011, @cLangCode, 'DSP') --TgetDB Not Set
         GOTO Step_2_Fail
      END

      BEGIN TRAN

      -- Call printing spooler
      INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Printer, NoOfCopy, Mobile, TargetDB)
      VALUES('PRINTPALLETMAN', 'PALLETMAN', '0', @cDataWindow, 1, @cExternOrderKey, @cPrinter, 1, @nMobile, @cTargetDB)

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN

         SET @nErrNo = 64012
         SET @cErrMsg = rdt.rdtgetmessage( 64012, @cLangCode, 'DSP') --'InsertPRTFail'
         GOTO Step_2_Fail
      END

      COMMIT TRAN

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
      
      SET @cOutField01 = ''   -- PSNO
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = @cPickSlipNo   -- PSNO
      SET @cOutField02 = ''   -- Option
      SET @cOption = ''
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

      StorerKey = @cStorer,
      Facility  = @cFacility,
      -- UserName  = @cUserName,
      Printer   = @cPrinter,    

      V_String1 = @cExternOrderKey,
      V_String2 = @cPickSlipNo,

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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END


GO
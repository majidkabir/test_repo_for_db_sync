SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_DynamicPick_CartonManifest                   */
/* Copyright      : IDS                                                 */
/* FBR: 85868                                                           */
/* Purpose: Print carton label                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 02-Jul-2008  1.0  James      Created                                 */
/* 30-Sep-2016  1.1  Ung        Performance tuning                      */
/* 07-Mar-2018  1.2  ChewKP     WMS-3767-Call rdt.rdtPrintJob (ChewKP01)*/
/* 31-Oct-2018  1.3  TungGH     Performance                             */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DynamicPick_CartonManifest](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF  

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cPrinter       NVARCHAR( 10),

   @cDataWindow    NVARCHAR( 50), 
   @cTargetDB      NVARCHAR( 10), 
   @cPickSlipNo      NVARCHAR( 10),
   @nCartonNo      INT,
   @cLabelNo       NVARCHAR( 20),

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

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer, 
      
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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE 
   @nStep_PrintManifest INT,  @nScn_PrintManifest INT

SELECT
   @nStep_PrintManifest = 1,  @nScn_PrintManifest = 1565


IF @nFunc = 911
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start        -- Menu. Func = 911
   IF @nStep = 1  GOTO Step_PrintManifest -- Scn = 1560. Print Carton Manifest
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 911
********************************************************************************/
Step_Start:
BEGIN

   -- Prepare next screen var
   SET @cOutField01 = '' -- Label No

   -- Go to ParentSKU screen
   SET @nScn = @nScn_PrintManifest
   SET @nStep = @nStep_PrintManifest
   GOTO Quit

   Step_Start_Fail:
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Label No
   END
END
GOTO Quit


/********************************************************************************
Scn = 1560. Print Label screen
   Label (field01, input)
********************************************************************************/
Step_PrintManifest:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
       SET @cLabelNo = @cInField01

		--if both input also blank
		IF ISNULL(@cLabelNo, '') = ''
		BEGIN			
	      SET @nErrNo = 65501
	      SET @cErrMsg = rdt.rdtgetmessage( 65501, @cLangCode, 'DSP') --Label needed
	      GOTO PrintManifest_Fail
		END

      IF NOT EXISTS (SELECT 1 FROM dbo.PACKDETAIL WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LabelNo = @cLabelNo)
		BEGIN			
	      SET @nErrNo = 65502
	      SET @cErrMsg = rdt.rdtgetmessage( 65502, @cLangCode, 'DSP') --Invalid Label
	      GOTO PrintManifest_Fail
		END

      --lookup for carton no
      SELECT @nCartonNo = CartonNo 
      FROM dbo.PACKDETAIL WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND LabelNo = @cLabelNo 

      --lookup pickslipno
      SELECT @cPickSlipNo = PickslipNo 
      FROM dbo.PACKDETAIL WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND CartonNo = @nCartonNo
         AND LabelNo  = @cLabelNo 

		IF ISNULL(@cPrinter, '') = ''
		BEGIN			
	      SET @nErrNo = 65503
	      SET @cErrMsg = rdt.rdtgetmessage( 65503, @cLangCode, 'DSP') --NoLoginPrinter
	      GOTO PrintManifest_Fail
		END
		       
      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
             @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
	   FROM RDT.RDTReport WITH (NOLOCK) 
	   WHERE StorerKey = @cStorerKey
	      AND ReportType = 'CTNMNFEST'
	
      IF ISNULL(@cDataWindow, '') = ''
      BEGIN
         SET @nErrNo = 65504
         SET @cErrMsg = rdt.rdtgetmessage( 65504, @cLangCode, 'DSP') --DWNOTSetup
         GOTO PrintManifest_Fail
      END

      IF ISNULL(@cTargetDB, '') = ''
      BEGIN
         SET @nErrNo = 65505
         SET @cErrMsg = rdt.rdtgetmessage( 65505, @cLangCode, 'DSP') --TgetDB Not Set
         GOTO PrintManifest_Fail
      END

      BEGIN TRAN

      -- Call printing spooler
      --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Printer, NoOfCopy, Mobile, TargetDB)
      --VALUES('PRINTCTNMNFEST', 'CTNMNFEST', '0', @cDataWindow, 3, @cPickSlipNo, @cLabelNo, @cLabelNo, @cPrinter, 1, @nMobile, @cTargetDB)

      EXEC RDT.rdt_BuiltPrintJob                     
                        @nMobile,                    
                        @cStorerKey,                    
                        'CTNMNFEST',                    
                        'PRINTCTNMNFEST',                    
                        @cDataWindow,                    
                        @cPrinter,                    
                        @cTargetDB,                    
                        @cLangCode,                    
                        @nErrNo  OUTPUT,                     
                        @cErrMsg OUTPUT,                    
                        @cPickSlipNo,
                        @cLabelNo,
                        @cLabelNo

      IF @nErrNo  <> 0
      BEGIN
         ROLLBACK TRAN

         SET @nErrNo = 65506
         SET @cErrMsg = rdt.rdtgetmessage( 65506, @cLangCode, 'DSP') --'InsertPRTFail'
         GOTO Quit
      END

      COMMIT TRAN

      --set focus on last scanned field

      SET @cOutField01 = ''

      SET @nScn = @nScn_PrintManifest
      SET @nStep = @nStep_PrintManifest

      GOTO Quit
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN  
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Label No
   END
   
   GOTO Quit

   PrintManifest_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = '' 
      SET @cOutField03 = ''
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
   END
 
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      -- UserName     = @cUserName,
      Printer      = @cPrinter,    
      
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


SET QUOTED_IDENTIFIER OFF

GO
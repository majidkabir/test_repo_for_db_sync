SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_DynamicPick_Carton_and_Manifest_Label        */
/* Copyright      : IDS                                                 */
/* FBR: 115145                                                          */
/* Purpose: Print carton & manifest label                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 03-Sep-2008  1.0  James      Created                                 */
/* 03-Nov-2008  1.1  James      SOS119238 Only allow UCC.Status = '3'   */
/*                              to be printed for FCP despatch label    */
/* 30-Sep-2016  1.2  Ung        Performance tuning                      */
/* 16-Jan-2018  1.3  ChewKP     WMS-3767-Call rdt.rdtPrintJob (ChewKP01)*/
/* 31-Oct-2018  1.4  TungGH     Performance                             */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DynamicPick_Carton_and_Manifest_Label](
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

   @cLoadKey       NVARCHAR( 10),
	@cLabelNo       NVARCHAR( 20),
	@cCongsinee     NVARCHAR( 15),
	@cCartonNo      NVARCHAR( 4),
   @cPickSlipNo    NVARCHAR( 10),
   @cDataWindowCtn NVARCHAR( 50), 
   @cDataWindowMan NVARCHAR( 50), 
   @cTargetDBCtn   NVARCHAR( 10), 
   @cTargetDBMan   NVARCHAR( 10), 
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
   @nStep_PrintLabel INT,  @nScn_PrintLabel INT

SELECT
   @nStep_PrintLabel = 1,  @nScn_PrintLabel = 1800


IF @nFunc = 1610
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start        -- Menu. Func = 1610
   IF @nStep = 1  GOTO Step_PrintLabel -- Scn = 1800. Print Carton Manifest Label
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 910
********************************************************************************/
Step_Start:
BEGIN

   -- Prepare next screen var
   SET @cOutField01 = '' -- Label No

   -- Go to ParentSKU screen
   SET @nScn = @nScn_PrintLabel
   SET @nStep = @nStep_PrintLabel
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
Scn = 1800. Print Label screen
   Label No    (field01, input)
   Consignee   (field03)
   CartonNo    (field04)
********************************************************************************/
Step_PrintLabel:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN

      SET @cLabelNo = @cInField01

		--if input blank
		IF ISNULL(@cLabelNo, '') = ''
		BEGIN			
	      SET @nErrNo = 65801
	      SET @cErrMsg = rdt.rdtgetmessage( 65801, @cLangCode, 'DSP') --Label needed
	      EXEC rdt.rdtSetFocusField @nMobile, 01
	      GOTO PrintLabel_Fail
		END

      
      IF NOT EXISTS (SELECT 1 FROM dbo.PACKDETAIL WITH (NOLOCK)
		   WHERE STORERKEY = @cStorerKey
				AND LABELNO = @cLabelNo)
		BEGIN			
	      SET @nErrNo = 65802
	      SET @cErrMsg = rdt.rdtgetmessage( 65802, @cLangCode, 'DSP') --Bad Label No
	      EXEC rdt.rdtSetFocusField @nMobile, 01
	      GOTO PrintLabel_Fail
		END

      -- SOS119238 Only allow UCC.Status = '3' to be printed for FCP despatch label (Start)
      IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LabelNo = @cLabelNo
            AND Refno <> '')
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.UCC U WITH (NOLOCK)
            JOIN dbo.PackDetail PD WITH (NOLOCK) ON (U.StorerKey = PD.StorerKey AND U.UCCNo = PD.Refno)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.LabelNo = @cLabelNo
               AND U.Status < '4')
         BEGIN
		      SET @nErrNo = 63509
		      SET @cErrMsg = rdt.rdtgetmessage( 63509, @cLangCode, 'DSP') --Bad UCC Status
		      EXEC rdt.rdtSetFocusField @nMobile, 01
		      GOTO PrintLabel_Fail
         END
      END
      -- (End)
            
      --lookup for carton no, pickslipno
      SELECT @cCartonNo = CartonNo, 
         @cPickSlipNo = PickslipNo 
      FROM dbo.PACKDETAIL WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND LabelNo = @cLabelNo 

      SELECT @cLoadKey = Loadkey 
      FROM dbo.PACKHEADER WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey
      	AND PickslipNo = @cPickSlipNo

      --lookup for consigneekey            	
      SELECT TOP 1 @cCongsinee = ConsigneeKey
      FROM dbo.LoadPlanDetail WITH (NOLOCK) 
      WHERE LoadKey = @cLoadKey          	

		IF ISNULL(@cPrinter, '') = ''
		BEGIN			
	      SET @nErrNo = 65803
	      SET @cErrMsg = rdt.rdtgetmessage( 65803, @cLangCode, 'DSP') --NoLoginPrinter
	      GOTO PrintLabel_Fail
		END
      -- Get carton lbl datawindow and target db
      SELECT @cDataWindowCtn = ISNULL(RTRIM(DataWindow), ''),
             @cTargetDBCtn = ISNULL(RTRIM(TargetDB), '') 
	   FROM RDT.RDTReport WITH (NOLOCK) 
	   WHERE StorerKey = @cStorerKey
	      AND ReportType = 'CARTONLBL'

      -- Get manifest lbl datawindow and target db
      SELECT @cDataWindowMan = ISNULL(RTRIM(DataWindow), ''),
             @cTargetDBMan = ISNULL(RTRIM(TargetDB), '') 
	   FROM RDT.RDTReport WITH (NOLOCK) 
	   WHERE StorerKey = @cStorerKey
	      AND ReportType = 'CTNMNFEST'

      -- If any datawindow not found, prompt error	
      IF ISNULL(@cDataWindowCtn, '') = '' OR ISNULL(@cDataWindowMan, '') = ''
      BEGIN
         SET @nErrNo = 65804
         SET @cErrMsg = rdt.rdtgetmessage( 65804, @cLangCode, 'DSP') --DWNOTSetup
         GOTO PrintLabel_Fail
      END

      -- If any target db not set, prompt error
      IF ISNULL(@cTargetDBCtn, '') = '' OR ISNULL(@cTargetDBMan, '') = ''
      BEGIN
         SET @nErrNo = 65805
         SET @cErrMsg = rdt.rdtgetmessage( 65805, @cLangCode, 'DSP') --TgetDB Not Set
         GOTO PrintLabel_Fail
      END

      BEGIN TRAN

      -- (ChewKP01) 
      -- Call printing spooler for carton label
      --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Parm4, Parm5, Printer, NoOfCopy, Mobile, TargetDB)
      --VALUES('PRINTCARTONLBL', 'CARTONLBL', '0', @cDataWindowCtn, 5, @cPickSlipNo, @cCartonNo, @cCartonNo, @cLabelNo, @cLabelNo, @cPrinter, 1, @nMobile, @cTargetDBCtn)

      EXEC RDT.rdt_BuiltPrintJob                     
            @nMobile,                    
            @cStorerKey,                    
            'CARTONLBL',                    
            'PRINTCARTONLBL',                    
            @cDataWindowCtn,                    
            @cPrinter,                    
            @cTargetDBCtn,                    
            @cLangCode,                    
            @nErrNo  OUTPUT,                     
            @cErrMsg OUTPUT,                    
            @cPickSlipNo,
            @cCartonNo,
            @cCartonNo,
            @cLabelNo,
            @cLabelNo
      
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN

         SET @nErrNo = 63506
         SET @cErrMsg = rdt.rdtgetmessage( 63506, @cLangCode, 'DSP') --'InsertPRTFail'
         GOTO Quit
      END
      
      -- Call printing spooler for carton manifest
      --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Printer, NoOfCopy, Mobile, TargetDB)
      --VALUES('PRINTCTNMNFEST', 'CTNMNFEST', '0', @cDataWindowMan, 3, @cPickSlipNo, @cLabelNo, @cLabelNo, @cPrinter, 1, @nMobile, @cTargetDBMan)
      
      
      EXEC RDT.rdt_BuiltPrintJob                     
            @nMobile,                    
            @cStorerKey,                    
            'CTNMNFEST',                    
            'PRINTCTNMNFEST',                    
            @cDataWindowMan,                    
            @cPrinter,                    
            @cTargetDBMan,                    
            @cLangCode,                    
            @nErrNo  OUTPUT,                     
            @cErrMsg OUTPUT,                    
            @cPickSlipNo,
            @cLabelNo,
            @cLabelNo
       

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN

         SET @nErrNo = 63507
         SET @cErrMsg = rdt.rdtgetmessage( 63507, @cLangCode, 'DSP') --'InsertPRTFail'
         GOTO Quit
      END

      COMMIT TRAN

      SET @cOutField01 = ''
      SET @cOutField02 = @cCongsinee
      SET @cOutField03 = @cCartonNo

      SET @nScn = @nScn_PrintLabel
      SET @nStep = @nStep_PrintLabel

      GOTO Quit
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN  
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Label No
      SET @cOutField02 = '' 
      SET @cOutField03 = ''
   END
   
   GOTO Quit

   PrintLabel_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = '' 
      SET @cOutField03 = ''
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
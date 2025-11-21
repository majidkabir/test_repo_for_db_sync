SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: URN Label Reprint SOS141998                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2009-07-10 1.0  James      Created                                   */
/* 2009-07-28 1.1  James      SOS143470 - Previously we take out the T  */
/*                            prefix from Dept and replaced with 0. For */
/*                            ex, T20 with 020. When user scan the label*/
/*                            again, the data cannot be found. Need to  */
/*                            replace the 0 with T again (james01)      */
/* 2016-09-30 1.2  Ung        Performance tuning                        */ 
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_Reprint_URNLabel] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE 
   @cOption     NVARCHAR( 1),
   @nCount      INT,
   @nRowCount   INT

-- RDT.RDTMobRec variable
DECLARE 
   @nFunc      INT,
   @nScn       INT,
   @nCurScn    INT,  -- Current screen variable
   @nStep      INT,
   @nCurStep   INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5), 
   @cPrinter   NVARCHAR( 10),
   @cUserName  NVARCHAR( 18),
   
   @cLoadKey            NVARCHAR( 10),
   @cMBOLKey            NVARCHAR( 10),
   @cPickSlipNo         NVARCHAR( 10),
   @cCaseID             NVARCHAR( 10),
   @cDataWindow         NVARCHAR( 50), 
   @cTargetDB           NVARCHAR( 10), 
   @cURNNo              NVARCHAR( 32),
   @cType               NVARCHAR( 5),

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
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer, 
   @cUserName  = UserName,
   
   @cPickSlipNo = V_PickSlipNo,
   @cLoadKey    = V_LoadKey,

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1626  -- Reprint URN Label
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Reprint URN Label
   IF @nStep = 1 GOTO Step_1   -- Scn = 2020. CASE ID, URN LABEL
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1626. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 2050
   SET @nStep = 1

   -- Initiate var
   SET @cCaseID = ''
   SET @cURNNo = ''

   -- Init screen
   SET @cOutField01 = '' -- Case ID
   SET @cOutField02 = '' -- URN Label
  
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 2050. 
   Case ID     (field01, input)
   URN Label   (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cCaseID = @cInField01
      SET @cURNNo = @cInField02

      -- Validate blank
      IF ISNULL(@cCaseID, '') = '' AND ISNULL(@cURNNo, '') = ''
      BEGIN
         SET @nErrNo = 67276
         SET @cErrMsg = rdt.rdtgetmessage( 67276, @cLangCode,'DSP') --PlsScanIn1Opt
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cCaseID = ''
         SET @cURNNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit         
      END

      -- Only scan in either one field
      IF ISNULL(@cCaseID, '') <> '' AND ISNULL(@cURNNo, '') <> ''
      BEGIN
         SET @nErrNo = 67277
         SET @cErrMsg = rdt.rdtgetmessage( 67277, @cLangCode,'DSP') --OnlyScanIn1Opt
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cCaseID = ''
         SET @cURNNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit         
      END

      IF ISNULL(@cCaseID, '') <> ''
      BEGIN
         SELECT @cPickSlipNo = PDtl.PickSlipNo, @cURNNo = PInfo.RefNo 
         FROM dbo.PackDetail PDtl WITH (NOLOCK)
         JOIN dbo.PackInfo PInfo WITH (NOLOCK)
            ON (PDTL.PickSlipno = PInfo.PickSlipNo AND PDtl.CartonNo = PInfo.CartonNo)
         WHERE PDtl.StorerKey = @cStorerKey
            AND PDtl.CartonNo = @cCaseID

         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 67278
            SET @cErrMsg = rdt.rdtgetmessage( 67278, @cLangCode,'DSP') --InvalidCaseID
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cCaseID = ''
            SET @cURNNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit         
         END

         IF ISNULL(@cURNNo, '') = ''
         BEGIN
            SET @nErrNo = 67279
            SET @cErrMsg = rdt.rdtgetmessage( 67279, @cLangCode,'DSP') --URN Not Found
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cCaseID = ''
            SET @cURNNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit         
         END
      END   -- End for ISNULL(@cCaseID, '') <> ''
      ELSE
      BEGIN -- ISNULL(@cURNNo, '') <> ''
         SET @cPickSlipNo = ''

         --(james01)
         IF ISNUMERIC(SUBSTRING(@cURNNo, 19, 1)) = 1
            SET @cURNNo = SUBSTRING(@cURNNo, 1, 18) + 'T' + SUBSTRING(@cURNNo, 20, 13)

         SELECT @cPickSlipNo = PDtl.PickSlipNo 
         FROM dbo.PackDetail PDtl WITH (NOLOCK)
         JOIN dbo.PackInfo PInfo WITH (NOLOCK)
            ON (PDTL.PickSlipno = PInfo.PickSlipNo AND PDtl.CartonNo = PInfo.CartonNo)
         WHERE PDtl.StorerKey = @cStorerKey
            AND PInfo.Refno = @cURNNo

         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 67280
            SET @cErrMsg = rdt.rdtgetmessage( 67280, @cLangCode,'DSP') --InvalidURNNo
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cCaseID = ''
            SET @cURNNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit         
         END
      END   -- End for isnull(@cURNNo, '') <> ''

      -- Validate printer setup
      IF ISNULL(@cPrinter, '') = ''
      BEGIN			
         SET @nErrNo = 67281
         SET @cErrMsg = rdt.rdtgetmessage( 67281, @cLangCode,'DSP') --NoLoginPrinter
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cCaseID = ''
         SET @cURNNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit         
      END
    		       
      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
         @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
      FROM RDT.RDTReport WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND ReportType = 'URNLABEL' 
                   	
      IF ISNULL(@cDataWindow, '') = ''
      BEGIN
         SET @nErrNo = 67282
         SET @cErrMsg = rdt.rdtgetmessage( 67282, @cLangCode,'DSP') --DWNOTSetup
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cCaseID = ''
         SET @cURNNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit         
      END

      IF ISNULL(@cTargetDB, '') = ''
      BEGIN
         SET @nErrNo = 67283
         SET @cErrMsg = rdt.rdtgetmessage( 67283, @cLangCode,'DSP') --TgetDB Not Set
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cCaseID = ''
         SET @cURNNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit         
      END

      -- Get LoadKey
      SELECT @cLoadKey = ExternOrderKey FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      -- Get MbolKey
      SELECT @cMBOLKey = MBOLKey FROM dbo.Orders WITH (NOLOCK)
      WHERE LoadKey = @cLoadKey

      -- Get Carton Type
      SELECT @cType = ISNULL(RTRIM(CartonType), '')
      FROM dbo.PACKINFO WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      IF ISNULL(@cLoadKey, '') = ''
      BEGIN
         SET @nErrNo = 67284
         SET @cErrMsg = rdt.rdtgetmessage( 67284, @cLangCode,'DSP') --LOADNotFound
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cCaseID = ''
         SET @cURNNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit         
      END

      IF ISNULL(@cMBOLKey, '') = ''
      BEGIN
         SET @nErrNo = 67285
         SET @cErrMsg = rdt.rdtgetmessage( 67285, @cLangCode,'DSP') --MBOLNotFound
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cCaseID = ''
         SET @cURNNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit         
      END

--      IF EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
--         WHERE MBOLKey = @cMBOLKey
--            AND LoadKey = @cLoadKey
--            AND Refno = @cCaseID)
--      BEGIN
--         SET @nErrNo = 67286
--         SET @cErrMsg = rdt.rdtgetmessage( 67286, @cLangCode,'DSP') --CaseScanned
--         SET @cOutField01 = ''
--         SET @cOutField02 = ''
--         SET @cCaseID = ''
--         SET @cURNNo = ''
--         EXEC rdt.rdtSetFocusField @nMobile, 1
--         GOTO Quit         
--      END

      BEGIN TRAN

      IF NOT EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
         WHERE MBOLKey = @cMBOLKey
            AND LoadKey = @cLoadKey
            AND Refno = @cCaseID)
      BEGIN
         INSERT INTO RDT.RDTScanToTruck
         (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate)
         VALUES
         (@cMBOLKey, @cLoadKey, @cType, @cCaseID, @cURNNo, '1', @cUserName, GETDATE())

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN

            SET @nErrNo = 67287
            SET @cErrMsg = rdt.rdtgetmessage( 67287, @cLangCode,'DSP') --InsertRecFail
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cCaseID = ''
            SET @cURNNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit         
         END
      END

      IF EXISTS (SELECT 1 
      FROM dbo.ORDERS ORDERS WITH (NOLOCK)
      JOIN dbo.STORER STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
      LEFT OUTER JOIN dbo.STORER CS WITH (NOLOCK) ON (ORDERS.ConsigneeKey = CS.StorerKey)
      WHERE ORDERS.StorerKey = @cStorerKey
         AND ORDERS.LoadKey = @cLoadKey
         AND UPPER(ISNULL(RTRIM(CS.ConsigneeFor), '')) = 'M&S')
      BEGIN
         -- Call printing spooler
         INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Printer, NoOfCopy, Mobile, TargetDB)
         VALUES('PRINT_URNLABEL', 'URNLABEL', '0', @cDataWindow, 2, SUBSTRING(@cURNNo, 1, 30), SUBSTRING(@cURNNo, 31, 2), @cPrinter, 1, @nMobile, @cTargetDB) 

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN

            SET @nErrNo = 67288
            SET @cErrMsg = rdt.rdtgetmessage( 67288, @cLangCode,'DSP') --InsertPRTFail
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cCaseID = ''
            SET @cURNNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit         
         END
      END

      COMMIT TRAN

      GOTO Quit
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
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
      EditDate     = GETDATE(), 
      ErrMsg       = @cErrMsg, 
      Func         = @nFunc,
      Step         = @nStep,
      Scn          = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility, 
      Printer      = @cPrinter,    
      -- UserName     = @cUserName,

      V_PickSlipNo = @cPickSlipNo,
      V_LoadKey    = @cLoadKey,
      
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
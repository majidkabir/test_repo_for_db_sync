SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: RDT Scan To Pallet (Reprint) SOS164062                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2010-03-17 1.0  James      Created                                   */
/* 2016-09-30 1.1  Ung        Performance tuning                        */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_Scan_To_Pallet_Reprint] (
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
   
   @nError     INT,
   @b_success  INT,
   @n_err      INT,     
   @c_errmsg   NVARCHAR( 250), 

   @cPalletKey          NVARCHAR( 30), 
   @cPalletKey1         NVARCHAR( 15), 
   @cPalletKey2         NVARCHAR( 15), 
   @cCaseID             NVARCHAR( 20),
   @cDataWindow         NVARCHAR( 50),
   @cTargetDB           NVARCHAR( 10),
   @cSKU                NVARCHAR( 20),
   @cLOC                NVARCHAR( 10),
   @cConsigneeKey       NVARCHAR( 15),
   @cPalletLineNumber   NVARCHAR( 5),
   @nQty                INT,
   @nTotalCases         INT,

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
   
   @nQTY        = V_QTY,
   @cSKU        = V_SKU,
   @cLOC        = V_LOC,

   @cPalletKey1         = V_String1,
   @cPalletKey2         = V_String2,
   @cCaseID             = V_String3,  

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

IF @nFunc = 1639  -- RDT Scan To Pallet (Reprint)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   --  Menu
   IF @nStep = 1 GOTO Step_1   -- Scn = 2270. Pallet#
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1638. Menu
********************************************************************************/
Step_0:
BEGIN
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   -- Set the entry point
   SET @nScn = 2270
   SET @nStep = 1

   -- Initiate var
   SET @cPalletKey = ''

   -- Init screen
   SET @cOutField01 = '' -- PalletKey

END
GOTO Quit

/********************************************************************************
Step 1. Scn = 2270. 
   PalletKey     (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

         --screen mapping
      SET @cPalletKey = @cInField01
      
      -- Validate blank
      IF ISNULL(@cPalletKey, '') = ''
      BEGIN
         SET @nErrNo = 68991
         SET @cErrMsg = rdt.rdtgetmessage( 68991, @cLangCode,'DSP') --PLT# required
         GOTO Step_1_Fail
      END

      -- Check if Palletkey exists in PalletDetail table
      IF NOT EXISTS (SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK) 
         WHERE PalletKey = @cPalletKey
            AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 68992
         SET @cErrMsg = rdt.rdtgetmessage( 68992, @cLangCode,'DSP') --Invalid PLT# 
         GOTO Step_1_Fail
      END
 
	   IF ISNULL(@cPrinter, '') = ''
	   BEGIN			
         SET @nErrNo = 68993
         SET @cErrMsg = rdt.rdtgetmessage( 68993, @cLangCode, 'DSP') --NoLoginPrinter
         GOTO Step_1_Fail
	   END
   		       
      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
             @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
      FROM RDT.RDTReport WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND ReportType = 'PACKLIST'
   	
      IF ISNULL(@cDataWindow, '') = ''
      BEGIN
         SET @nErrNo = 68994
         SET @cErrMsg = rdt.rdtgetmessage( 68994, @cLangCode, 'DSP') --DWNOTSetup
         GOTO Step_1_Fail
      END

      IF ISNULL(@cTargetDB, '') = ''
      BEGIN
         SET @nErrNo = 68995
         SET @cErrMsg = rdt.rdtgetmessage( 68995, @cLangCode, 'DSP') --TgetDB Not Set
         GOTO Step_1_Fail
      END

      BEGIN TRAN

      -- Call printing spooler
      INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Printer, NoOfCopy, Mobile, TargetDB)
      VALUES('PRINTPACKLIST', 'PACKLIST', '0', @cDataWindow, 2, @cStorerKey, @cPalletKey, @cPrinter, 1, @nMobile, @cTargetDB)

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 68996
         SET @cErrMsg = rdt.rdtgetmessage( 68996, @cLangCode, 'DSP') --'InsertPRTFail'
         GOTO Step_1_Fail
      END

      COMMIT TRAN

      SET @cPalletKey1 = SUBSTRING(RTRIM(@cPalletKey), 1, 15)
      SET @cPalletKey2 = SUBSTRING(RTRIM(@cPalletKey), 16, 15)

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '14', -- Activity tracking
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cRefNo1       = @cPalletKey1,
         @cRefNo2       = @cPalletKey2

      -- Prepare next screen var
      SET @cOutField01 = ''
      SET @cPalletKey = ''

      -- Stay in same screen
      SET @nScn = @nScn
      SET @nStep = @nStep
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      -- EventLog 
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   SET @cOutField01 = ''
   SET @cPalletKey = ''

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

      V_QTY        = @nQTY,
      V_SKU        = @cSKU,
      V_LOC        = @cLOC,
      
      V_String1    = @cPalletKey1,
      V_String2    = @cPalletKey2,
      V_String3    = @cCaseID,

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
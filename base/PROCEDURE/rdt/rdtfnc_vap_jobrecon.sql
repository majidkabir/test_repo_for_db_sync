SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: WorkOrder Operation (Job Reconciliation)                          */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2015-11-26 1.1  James      SOS315942 Created                               */
/* 2016-09-30 1.1  Ung        Performance tuning                              */  
/* 2018-11-21 1.2  Gan        Performance tuning                              */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_VAP_JobRecon] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
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
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5), 
   @cPrinter            NVARCHAR( 20), 
   @cPrinter_Paper      NVARCHAR( 10),
   @cUserName           NVARCHAR( 18),

   @cReconType          NVARCHAR( 20),
   @cWorkOrderKey       NVARCHAR( 10),
   @cJobKey             NVARCHAR( 10),
   @cJobLineNo          NVARCHAR( 5),
   @cQty                NVARCHAR( 7),
   @cReasonCode         NVARCHAR( 10),
   @cSKU                NVARCHAR( 20),
   @cJobReconLineNumber NVARCHAR( 5),
   @cWastageUOM         NVARCHAR( 10),
   @cRejectUOM          NVARCHAR( 10),
   @cWastageReason      NVARCHAR( 10),
   @cRejectReason       NVARCHAR( 10),
   @cPackKey            NVARCHAR( 10),
   @nQty                INT,
   @nTranCount          INT,
   @bsuccess            INT,
   @nQtyWastage         INT,
   @nQtyReject          INT,
   
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
   @cUserName  = UserName,
   @cPrinter   = Printer, 
   @cPrinter_Paper = Printer_Paper,
   @cSKU       = V_SKU, 

   @cReconType          = V_String1,
   @cWorkOrderKey       = V_String2,
   @cJobKey             = V_String3,
   @cJobLineNo          = V_String4, 
   
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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15
FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

Declare @n_debug INT
SET @n_debug = 0

IF @nFunc = 1155  -- VAP Uncasing
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- VAP Job Recon
   IF @nStep = 1 GOTO Step_1   -- Scn = 4450. Reconciliation Type 
   IF @nStep = 2 GOTO Step_2   -- Scn = 4451. WorkOrder#, Job#, JobLine#
	IF @nStep = 3 GOTO Step_3   -- Scn = 4452. JobLine#, SKU, Qty, Reason
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1155. Menu
********************************************************************************/
Step_0:
BEGIN
   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

      -- Initialize Variable 
      SET @cReconType = ''
      SET @cWorkOrderKey  = ''  
      SET @cJobKey         = ''  
      SET @cJobLineNo     = ''  

      -- Init screen
      SET @cOutField01 = '' 
   
      -- Set the entry point
      SET @nScn = 4450
      SET @nStep = 1
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 4450. 
   WORKSTATION    (Field01, input)
   JOB ID         (Field02, input)
   WORKORDER #    (Field03, input)
   
********************************************************************************/
Step_1:
BEGIN
	IF @nInputKey = 1 
   BEGIN
	   SET @cReconType = ISNULL(RTRIM(@cInField01),'')

      IF @cReconType = ''
		BEGIN
		   SET @nErrNo = 58851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value Require
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
	   END

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, 1

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

	IF @nInputKey = 0 
   BEGIN
      -- EventLog - Sign In Function
       EXEC RDT.rdt_STD_EventLog
        @cActionType = '9', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep
        
      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
	GOTO Quit

   STEP_1_FAIL:
   BEGIN
      SET @cReconType = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 4451. 
   WORKSTATION    (Field01, input)
   JOB ID         (Field02, input)
   WORKORDER #    (Field03, input)
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cWorkOrderKey = ISNULL(RTRIM(@cInField01),'')
	   SET @cJobKey = ISNULL(RTRIM(@cInField02),'')
      SET @cJobLineNo = ISNULL(RTRIM(@cInField03),'')

      IF @cWorkOrderKey = '' OR @cJobKey = '' OR @cJobLineNo = ''
		BEGIN
		   SET @nErrNo = 58852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value Require
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
	   END

      SELECT @cSKU = SKU
      FROM dbo.WorkOrderJobOperation WOJO WITH (NOLOCK)
      JOIN dbo.WorkOrderJob WOJ WITH (NOLOCK) ON (WOJO.JobKey = WOJ.JobKey)
      WHERE WOJ.WorkOrderKey = @cWorkOrderKey
      AND   WOJO.JobKey = @cJobKey
      AND   WOJO.JobLine = @cJobLineNo

	   IF ISNULL( @cSKU, '') = ''
	   BEGIN
	      SET @nErrNo = 58853
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Record found!
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = @cWorkOrderKey
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cJobLineNo
         GOTO Quit
	   END 
	   
		-- Prepare Next Screen Variable
      SET @cOutField01 = @cWorkOrderKey
      SET @cOutField02 = @cJobKey
      SET @cOutField03 = @cJobLineNo
      SET @cOutField04 = @cSKU
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      
		-- GOTO Next Screen
		SET @nScn = @nScn + 1
	   SET @nStep = @nStep + 1
	    
	   EXEC rdt.rdtSetFocusField @nMobile, 5 
	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
      SET @cReconType = ''
      SET @cOutField01 = ''
      
		-- GOTO Prev Screen
		SET @nScn = @nScn - 1
	   SET @nStep = @nStep - 1
   END
	GOTO Quit

   STEP_2_FAIL:

END 
GOTO QUIT

/********************************************************************************
Step 3. Scn = 4452. 
   WORKSTATION    (Field01, display)
   JOB ID         (Field02, display)
   WORKORDER #    (Field03, display)
   DESCRIPTION    (Field04, display)
   SKU            (Field05, display)
   OPTION         (Field06, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cQty = ISNULL(RTRIM(@cInField05),'')
      SET @cReasonCode = ISNULL(RTRIM(@cInField06),'')

      IF @cQty = ''
	   BEGIN
	      SET @nErrNo = 58854
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qty required
         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Quit
	   END 

      IF rdt.rdtIsValidQty( @cQty, 1)  = 0
	   BEGIN
	      SET @nErrNo = 58855
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Quit
	   END 
      ELSE
         SET @nQty = CAST( @cQty AS NVARCHAR( 7))

      IF @cReasonCode = ''
	   BEGIN
	      SET @nErrNo = 58856
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason required
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
	   END 

      IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                      WHERE ListName = @cReconType
                      AND   Description = @cReasonCode)
	   BEGIN
	      SET @nErrNo = 58857
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Reason
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
	   END 

      SELECT @cJobReconLineNumber = SUBSTRING(LTrim(STR(CONVERT(int, ISNULL(MAX(JobReconLineNumber), '0')) + 1 + 100000)),2,5)
      FROM dbo.WORKORDERJOBRECON WITH (NOLOCK)
      WHERE JobKey = @cJobKey

      IF @cJobReconLineNumber = ''
      BEGIN
         SET @nErrNo = 58858
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetLine#Fail'
         GOTO Quit
      END

      SET @cWastageUOM = ''
      SET @nQtyWastage = 0
      SET @cWastageReason = ''
      SET @cRejectUOM = ''
      SET @nQtyReject = 0
      SET @cRejectReason = ''

      SELECT @cPackKey = PackKey
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      IF @cReconType like '%WASTAGE%'
      BEGIN
         SET @cWastageUOM = ''
         SET @nQtyWastage = @nQty
         SET @cWastageReason = @cReasonCode
      END
      ELSE
      BEGIN
         SET @cRejectUOM = ''
         SET @nQtyReject = @nQty
         SET @cRejectReason = @cReasonCode
      END

      INSERT INTO dbo.WORKORDERJOBRECON 
         (JobKey, JobReconLineNumber, WorkOrderkey, Storerkey, SKU, 
          NonInvSku, Packkey, UOM, QtyReserved, 
          WastageUOM, QtyWastage, WastageReason, 
          RejectUOM, QtyReject, RejectReason, 
          AddWho, AddDate) 
       VALUES
         (@cJobKey, @cJobReconLineNumber, @cWorkOrderkey, @cStorerKey, @cSKU,
          '', @cPackKey, '', 0,
          @cWastageUOM, @nQtyWastage, @cWastageReason, 
          @cRejectUOM, @nQtyReject, @cRejectReason, 
          @cUserName, GETDATE())

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58859
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Ins Recon fail'
         GOTO Quit
      END

      -- Initialize Variable 
      SET @cReconType = ''

      -- Init screen
      SET @cOutField01 = '' 
   
      -- Set the entry point
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, 1

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
	GOTO Quit

   STEP_3_FAIL:

END 
GOTO QUIT

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

      StorerKey = @cStorerKey,
      Facility  = @cFacility, 
      Printer   = @cPrinter, 
      -- UserName  = @cUserName,
		InputKey  =	@nInputKey,
		Printer_Paper   = @cPrinter_Paper,
      V_SKU     = @cSKU,

      V_String1 = @cReconType,      
      V_String2 = @cWorkOrderKey,
      V_String3 = @cJobKey,
      V_String4 = @cJobLineNo,

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
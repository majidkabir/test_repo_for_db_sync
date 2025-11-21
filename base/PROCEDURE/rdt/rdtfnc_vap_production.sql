SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: WorkOrder Operation (Production)                                  */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2015-11-26 1.1  James      SOS315942 Created                               */
/* 2016-09-30 1.2  Ung        Performance tuning                              */ 
/* 2018-10-26 1.3  TungGH     Performance                                     */ 
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_VAP_Production] (
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
   
   @cWorkStation        NVARCHAR( 20),
   @cJobID              NVARCHAR( 20),
   @cSelectedJobKey     NVARCHAR( 20),
   @cID                 NVARCHAR( 20),
	@cJobStatus          NVARCHAR( 20),
	@cWorkOrderName      NVARCHAR( 100),
	@cWorkRoutingDescr   NVARCHAR( 160), 
   @cTDStatus           NVARCHAR( 10),
   @cTaskDetailKey      NVARCHAR( 10),
   @cInLoc              NVARCHAR( 20),
   @cOutLoc             NVARCHAR( 20),
   @cSKU                NVARCHAR( 20),
   @cSKUDescr           NVARCHAR( 60),
   @cUserKey            NVARCHAR( 18),
	@cLottable01         NVARCHAR( 18),
	@cLottable02         NVARCHAR( 18),
	@cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
	@dLottable05         DATETIME,
   @cLottable06         NVARCHAR( 30),
   @cLottable07         NVARCHAR( 30),
   @cLottable08         NVARCHAR( 30),
   @cLottable09         NVARCHAR( 30),
   @cLottable10         NVARCHAR( 30),
   @cLottable11         NVARCHAR( 30),
   @cLottable12         NVARCHAR( 30),
   @dLottable13         DATETIME,
   @dLottable14         DATETIME,
   @dLottable15         DATETIME,
	
   @cOrderKey           NVARCHAR(10),
   @cOrderLineNumber    NVARCHAR(5),
	@cWkOrdReqOutputsKey NVARCHAR(10),

   @cJobLineNo          NVARCHAR( 5),  
   @cSSCC               NVARCHAR( 20),
   @cQty                NVARCHAR( 5),
   @cStartTime          NVARCHAR( 20),
   @cEndTime            NVARCHAR( 20),
   @cStorerGroup        NVARCHAR( 20),
   @cChkStorerKey       NVARCHAR( 20),
   @cJobKey             NVARCHAR( 10),
   @cWorkOrderKey       NVARCHAR( 10),
   @cStatusMsg          NVARCHAR( 255),
   @nWorkOutPutQtyComplete INT,
   @nNoOfAssignWorkers     INT,
   @nRecCount              INT,
   @nQty                   INT,
   @nMultiStorer           INT,
   @nWorkQtyRemain         INT,
   @nTranCount             INT,
   @nWorkQty               INT,
   @nWorkQtyCompleted      INT, 

   @cErrMsg1            NVARCHAR( 20), 
   @cErrMsg2            NVARCHAR( 20), 
   @cErrMsg3            NVARCHAR( 20), 
   @cErrMsg4            NVARCHAR( 20), 
   @cErrMsg5            NVARCHAR( 20), 
   
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
  
   @cTaskDetailKey   = V_TaskDetailKey,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cOrderKey        = V_OrderKey,
   @cID              = V_ID, 
   
   @cJobKey             = V_String1,
   @cWorkOrderKey       = V_String2,
   @cWorkStation        = V_String3, 
   @cWorkOrderKey       = V_String4,
   @cWorkOrderName      = V_String5,
   @cInLoc              = V_String6,
   @cOutLoc             = V_String7,
   @cStartTime          = V_String9,
   @cEndTime            = V_String10,     
   @cOrderLineNumber    = V_String12,
   @cWkOrdReqOutputsKey = V_String13,
   @cJobStatus          = V_String14,
   @cTDStatus           = V_String15,
   @cJobLineNo          = V_String16, 
   
   @nWorkQtyRemain      = V_Integer1,
   @nNoOfAssignWorkers  = V_Integer2,     
   
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

IF @nFunc = 1152  -- VAP Uncasing
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- VAP Uncasing
   IF @nStep = 1 GOTO Step_1   -- Scn = 4420. Work Station
	IF @nStep = 2 GOTO Step_2   -- Scn = 4421. Select/Rotate Job
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 734. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get storer configure
   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1

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
      SET @cLottable01   = ''
      SET @cLottable02   = ''
      SET @cLottable03   = ''
   
      SET @cTaskDetailKey = ''
      SET @cSKU           = ''
      SET @cSKUDescr      = ''
      SET @cOrderKey      = ''
   
      SET @cJobKey         = ''  
      SET @cWorkOrderKey  = ''  
      SET @cWorkStation     = ''  
      SET @cWorkOrderKey    = ''  
      SET @cWorkOrderName   = ''  
      SET @cInLoc           = ''  
      SET @cOutLoc          = ''  
                       
      SET @nWorkQtyRemain     = 0
      SET @cOrderLineNumber   = ''
      SET @cWkOrdReqOutputsKey = ''
      SET @cJobStatus         = ''

      -- Init screen
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
   
      EXEC rdt.rdtSetFocusField @nMobile, 1
	
      -- Set the entry point
      SET @nScn = 4420
      SET @nStep = 1
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 4400. 
   WORKSTATION    (Field01, input)
   JOB ID         (Field02, input)
   WORKORDER #    (Field03, input)
   
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cWorkStation    = ISNULL(RTRIM(@cInField01),'')
	   SET @cJobKey        = ISNULL(RTRIM(@cInField02),'')
	   SET @cWorkOrderKey = ISNULL(RTRIM(@cInField03),'')

		IF @cWorkStation = ''
		BEGIN
		   SET @nErrNo = 58701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidWorkStation
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
         GOTO Quit
      END

	   IF NOT EXISTS ( SELECT 1 FROM dbo.WorkStation WITH (NOLOCK) 
                        WHERE WorkStation = @cWorkStation ) 
		BEGIN
		   SET @nErrNo = 58702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidWorkStation
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField02 = ''
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
         GOTO Quit
	   END
      	   
      IF ISNULL( @cJobKey, '') = '' AND ISNULL( @cWorkOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '58703 PLS KEY IN'
         SET @cErrMsg2 = 'EITHER JOB ID'
         SET @cErrMsg3 = 'OR WORKORDER #.'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END

         SET @cOutField01 = @cWorkStation
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      IF ISNULL( @cJobKey, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE JobKey = @cJobKey)
         BEGIN
            SET @nErrNo = 58704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Job ID

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = ''
            SET @cOutField03 = @cWorkOrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                     WHERE JobKey = @cJobKey
                     GROUP BY JobKey
                     HAVING COUNT( DISTINCT WorkOrderKey) > 1) 
            AND ISNULL( @cWorkOrderKey, '') = ''
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58705 THE JOB ID'
            SET @cErrMsg2 = 'CONTAIN > 1'
            SET @cErrMsg3 = 'WORKORDER #.'
            SET @cErrMsg4 = 'PLS KEY IN BOTH'
            SET @cErrMsg5 = 'VALUE TO PROCEED.'
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

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = @cJobKey
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END

         IF ISNULL( @cWorkOrderKey, '') = ''
            SELECT TOP 1 @cWorkOrderKey = WorkOrderKey 
            FROM dbo.WorkOrderJob WITH (NOLOCK) 
            WHERE JobKey = @cJobKey

         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE JobKey = @cJobKey
                         AND   WorkOrderKey = @cWorkOrderKey)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58706 INVALID'
            SET @cErrMsg2 = 'JOB ID + WORKORDER #'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = @cJobKey
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END
      END

      IF ISNULL( @cWorkOrderKey, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE WorkOrderKey = @cWorkOrderKey)
         BEGIN
            SET @nErrNo = 58707
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv WORKORDER#

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = @cJobKey
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                     WHERE WorkStation = @cWorkStation
                     AND   WorkOrderKey = @cWorkOrderKey
                     GROUP BY WorkOrderKey
                     HAVING COUNT( DISTINCT JobKey) > 1) 
            AND ISNULL( @cJobKey, '') = ''
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58708 WORKORDER #'
            SET @cErrMsg2 = 'CONTAIN > 1'
            SET @cErrMsg3 = 'JOB ID.'
            SET @cErrMsg4 = 'PLS KEY IN BOTH'
            SET @cErrMsg5 = 'VALUE TO PROCEED.'
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

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = ''
            SET @cOutField03 = @cWorkOrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         IF ISNULL( @cJobKey, '') = ''
            SELECT TOP 1 @cJobKey = JobKey 
            FROM dbo.WorkOrderJob WITH (NOLOCK) 
            WHERE WorkOrderKey = @cWorkOrderKey

         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE JobKey = @cJobKey
                         AND   WorkOrderKey = @cWorkOrderKey)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58709 INVALID'
            SET @cErrMsg2 = 'JOB ID + WORKORDER #'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = ''
            SET @cOutField03 = @cWorkOrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END

      IF EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK)
                  WHERE WorkStation = @cWorkStation
                  AND   WorkOrderKey = @cWorkOrderKey
                  AND   JobKey = @cJobKey
                  AND   Start_Production IS NOT NULL)
	   BEGIN
	      SET @nErrNo = 58710
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Job started
         SET @cOutField01 = @cWorkStation
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
         GOTO Quit
	   END 

      -- WorkOrderJobDetail -- 
      UPDATE dbo.WorkOrderJob WITH (ROWLOCK) SET 
         Start_Production = GETDATE(), 
         EditWho = @cUserName,
         EditDate = GETDATE(),
         TrafficCop = NULL
      WHERE WorkStation = @cWorkStation
      AND   WorkOrderKey = @cWorkOrderKey
      AND   JobKey = @cJobKey
      AND   Start_Production IS NULL

      IF @@ERROR <> 0
      BEGIN
	      SET @nErrNo = 58711
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Begin prod fail
         SET @cOutField01 = @cWorkStation
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
         GOTO Quit
      END

	   SET @cWorkOrderName    = ''
	   SET @cWorkRoutingDescr = ''
	   SET @nWorkQtyRemain    = 0
      SET @cTDStatus = ''
      SET @cWkOrdReqOutputsKey = ''
      SET @cOrderKey = ''
      SET @cOrderLineNumber = ''
      SET @cUserKey = ''
      SET @cJobLineNo = ''
	   SET @cTaskDetailKey = ''
      SET @nRecCount = 0

      SELECT TOP 1 @cWorkOrderName     = WJ.WorkOrderName
             , @cWorkRoutingDescr  = WR.Descr
             , @nWorkQtyRemain     = (WRO.Qty - WRO.QtyCompleted)
             , @cTDStatus          = CL.Description
             , @cTaskDetailKey     = TD.TaskDetailKey
             , @cWkOrdReqOutputsKey = WRO.WkOrdReqOutputsKey
             , @cOrderKey          = TD.OrderKey
             , @cOrderLineNumber   = TD.OrderLineNumber
             , @cUserKey           = TD.UserKey
             , @cJobLineNo         = Right(RTRIM(TD.SourceKey),5)   
             , @nWorkQtyCompleted  = WJD.QtyCompleted
             , @nWorkQty           = WRO.Qty
             , @nWorkQtyRemain     = (WRO.Qty - WRO.QtyCompleted)
             , @cStatusMsg         = TD.StatusMsg
	   FROM dbo.TaskDetail TD WITH (NOLOCK) 
	   INNER JOIN dbo.CodeLKup CL WITH (NOLOCK) ON CL.Code = TD.Status
	   INNER JOIN dbo.WorkOrderJOB WJ WITH (NOLOCK) ON LEFT(RTRIM(TD.SOURCEKEY),10) = WJ.JobKey
	   INNER JOIN dbo.WorkOrderJobDetail WJD WITH (NOLOCK) ON WJD.JobKey = WJ.JobKey 
	   INNER JOIN dbo.WorkOrderRouting WR WITH (NOLOCK) ON WJ.WorkOrderName = WR.WorkOrderName
	   INNER JOIN dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK) ON WRO.WorkOrderKey = WJ.WorkOrderKey
	   WHERE  TD.TaskType  = 'FG'
	      AND TD.Status    IN ('0','3')
	      AND WJ.Facility  = @cFacility
	      AND CL.ListName  = 'TMSTATUS'  
  	      AND WJ.JobKey    = @cJobKey
 	      AND WJ.WorkOrderKey = @cWorkOrderKey
  	      AND WJ.WorkStation  = @cWorkStation
  	   Order By CASE WHEN TD.UserKey = @cUserName THEN 0 ELSE 1 END
	          , TD.Priority   
	          , TD.TaskDetailKey
	          , WRO.WkOrdReqOutputsKey
   	   
	   SELECT @cSKU = WRO.SKU
		FROM dbo.WorkOrderRequestOutPuts WRO WITH (NOLOCK) 
   	INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = WRO.SKU AND SKU.StorerKEy = WRO.StorerKey
   	WHERE WRO.WorkOrderKey = @cWorkOrderKey

      SELECT @cInLoc = Location
      FROM dbo.WorkStationLoc WITH (NOLOCK)
      WHERE LocType = 'InLOC'
      AND WorkStation = @cWorkStation
         
   	SELECT @cOutLoc = Location
      FROM dbo.WorkStationLoc WITH (NOLOCK)
      WHERE LocType = 'OutLOC'
      AND WorkStation = @cWorkStation
            	
		-- Prepare Next Screen Variable
      SET @cOutField01 = @cWorkStation
      SET @cOutField02 = @cJobID
      SET @cOutField03 = @cWorkOrderKey
      SET @cOutField04 = SUBSTRING( @cStatusMsg, 1, 60)
      SET @cOutField05 = SUBSTRING( @cStatusMsg, 61, 60)
      SET @cOutField06 = SUBSTRING( @cStatusMsg, 121, 60)
      SET @cOutField07 = @nWorkQty
      SET @cOutField08 = @nWorkQtyCompleted
      SET @cOutField09 = @nWorkQtyRemain
      SET @cOutField10 = @cInLoc
      SET @cOutField11 = @cOutLoc
      
		-- GOTO Next Screen
		SET @nScn = @nScn + 1
	   SET @nStep = @nStep + 1
	    
	   EXEC rdt.rdtSetFocusField @nMobile, 10 
	END  -- Inputkey = 1

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
END 
GOTO QUIT

/********************************************************************************
Step 2. Scn = 4401. 
   WORKSTATION    (Field01, display)
   JOB ID         (Field02, display)
   WORKORDER #    (Field03, display)
   DESCRIPTION    (Field04, display)
   SKU            (Field05, display)
   OPTION         (Field06, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cInLoc  = ISNULL(RTRIM(@cInField10),'')
	   SET @cOutLoc = ISNULL(RTRIM(@cInField11),'')

		IF @cInLoc = ''
		BEGIN
		   SET @nErrNo = 58712
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InLoc Req
         EXEC rdt.rdtSetFocusField @nMobile, 14
         GOTO Step_2_Fail
	   END
	   
	   IF NOT EXISTS (SELECT 1 FROM dbo.Loc WITH (NOLOCK) Where Loc = @cInLoc ) 
	   BEGIN
	      SET @nErrNo = 58713
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid InLoc
         EXEC rdt.rdtSetFocusField @nMobile, 14
         GOTO Step_2_Fail
	   END
	   
	   IF @cOutLoc = ''
		BEGIN
		   	SET @nErrNo = 58714
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OutLoc Req
            EXEC rdt.rdtSetFocusField @nMobile, 14
            GOTO Step_2_Fail
	   END
	   
	   IF NOT EXISTS (SELECT 1 FROM dbo.Loc WITH (NOLOCK) Where Loc = @cOutLoc ) 
	   BEGIN
	      SET @nErrNo = 58715
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid OutLoc
         EXEC rdt.rdtSetFocusField @nMobile, 14
         GOTO Step_2_Fail
	   END

      -- WorkOrderJobDetail -- 
      UPDATE dbo.WorkOrderJob WITH (ROWLOCK) SET 
         End_Production = GETDATE(), 
         InLOC = @cInLoc,
         OutLOC = @cOutLoc,
         EditWho = @cUserName,
         EditDate = GETDATE(),
         TrafficCop = NULL
      WHERE WorkStation = @cWorkStation
      AND   WorkOrderKey = @cWorkOrderKey
      AND   JobKey = @cJobKey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58716
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd fail
         EXEC rdt.rdtSetFocusField @nMobile, 13
         GOTO Step_2_Fail
      END

      -- Init screen
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
   
      EXEC rdt.rdtSetFocusField @nMobile, 1
	
      -- Set the entry point
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
      -- Init screen
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
   
      EXEC rdt.rdtSetFocusField @nMobile, 1

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
	GOTO Quit

   STEP_2_FAIL:
   BEGIN
	   -- Prepare Next Screen Variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
   END
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
		
      V_TaskDetailKey = @cTaskDetailKey,
      V_SKU           = @cSKU,
      V_SKUDescr      = @cSKUDescr,
      V_OrderKey      = @cOrderKey,
      V_ID            = @cID,
      
      V_String1 = @cJobID,
      V_String2 = @cWorkOrderKey,
      V_String3 = @cWorkStation, 
      
      V_String4   = @cWorkOrderKey,
      V_String5   = @cWorkOrderName,
      V_String6   = @cInLoc,
      V_String7   = @cOutLoc,
      V_String8   = @cJobID,
      V_String9   = @cStartTime,
      V_String10  = @cEndTime,
         
      V_String12 =  @cOrderLineNumber,
      v_String13 =  @cWkOrdReqOutputsKey,
      V_String14 =  @cJobStatus,
      V_String15 =  @cTDStatus,
      V_String16 =  @cJobLineNo, 
      
      V_Integer1 =  @nWorkQtyRemain,
      V_Integer2 =  @nNoOfAssignWorkers,
      
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
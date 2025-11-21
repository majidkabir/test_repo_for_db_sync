SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: WorkOrder Operation (Uncasing)                                    */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2015-11-26 1.0  James      SOS315942 Created                               */
/* 2016-02-24 1.1  James      SOS363309 - Support multi WorkOrder tied to 1   */
/*                            Job Key (james01)                               */
/* 2016-09-30 1.2  Ung        Performance tuning                              */
/* 2018-11-21 1.3  TungGH     Performance                                     */  
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_VAP_Uncasing] (
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
   @nFunc                  INT,
   @nScn                   INT,
   @nStep                  INT,
   @cLangCode              NVARCHAR( 3),
   @nInputKey              INT,
   @nMenu                  INT,
                           
   @cStorerKey             NVARCHAR( 15),
   @cFacility              NVARCHAR( 5), 
   @cPrinter               NVARCHAR( 20), 
   @cUserName              NVARCHAR( 18),
                           
   @cWorkStation           NVARCHAR( 20),
   @cWorkOrderKey          NVARCHAR( 10),
   @cSelectedJobKey        NVARCHAR( 20),
   @cID                    NVARCHAR( 18),
   @cToID                  NVARCHAR( 18),
	@cJobStatus             NVARCHAR( 20),
	@cWorkOrderName         NVARCHAR( 100),
	@cWorkRoutingDescr      NVARCHAR( 160), 
   @cTDStatus              NVARCHAR( 10),
   @cTaskDetailKey         NVARCHAR( 10),
   @cInLoc                 NVARCHAR( 20),
   @cOutLoc                NVARCHAR( 20),
   @cSKU                   NVARCHAR( 20),
   @cSKUDescr              NVARCHAR( 60),
   @cUserKey               NVARCHAR( 18),
	@cLottable01            NVARCHAR( 18),
	@cLottable02            NVARCHAR( 18),
	@cLottable03            NVARCHAR( 18),
   @dLottable04            DATETIME,
	@dLottable05            DATETIME,
   @cLottable06            NVARCHAR( 30),
   @cLottable07            NVARCHAR( 30),
   @cLottable08            NVARCHAR( 30),
   @cLottable09            NVARCHAR( 30),
   @cLottable10            NVARCHAR( 30),
   @cLottable11            NVARCHAR( 30),
   @cLottable12            NVARCHAR( 30),
   @dLottable13            DATETIME,
   @dLottable14            DATETIME,
   @dLottable15            DATETIME,
	@dStartDate             DATETIME,
   @cOrderKey              NVARCHAR(10),
   @cOrderLineNumber       NVARCHAR(5),
	@cWkOrdReqOutputsKey    NVARCHAR(10),
   @cPrev_SKU              NVARCHAR(20),
                           
   @cJobLineNo             NVARCHAR( 5),  
   @cSSCC                  NVARCHAR( 20),
   @cQty                   NVARCHAR( 5),
   @cStartTime             NVARCHAR( 20),
   @cEndTime               NVARCHAR( 20),
   @cStorerGroup           NVARCHAR( 20),
   @cChkStorerKey          NVARCHAR( 20),
   @cJobKey                NVARCHAR( 10),
   @cLOT                   NVARCHAR( 10),
   @cFromLOC               NVARCHAR( 10),
   @cToLOC                 NVARCHAR( 10),
   @cVAPUncasingCfm_SP     NVARCHAR( 20),
   @cVAPUnCaseShowQty_SP   NVARCHAR( 20),
   @cSQLParms              NVARCHAR( MAX),
   @cSQLStatement          NVARCHAR( MAX),
   @cTtl_PltQty            NVARCHAR( 7),
   @cTtl_RemQty            NVARCHAR( 7),
   @nSKU_Qty               INT,
   @nRecCount              INT,
   @nQty                   INT,
   @nMultiStorer           INT,
   @nWorkQtyRemain         INT,
   @nTranCount             INT,
   @nTtl_Uncased           INT,
   @nTtl_2Uncase           INT,
   @nTtl_LotQty            INT,
   @nQty2UnCase            INT,
   @nTtl_JobQty            INT,
   @nTtl_PltUnCased        INT,
   @nTtl_PltQty            INT,
   @nNonReserved           INT,
   @nSKU_Count             INT,

   @cErrMsg1               NVARCHAR( 20),
   @cErrMsg2               NVARCHAR( 20),
   @cErrMsg3               NVARCHAR( 20),
   @cErrMsg4               NVARCHAR( 20),
   @cErrMsg5               NVARCHAR( 20),
   @cVAP_UncasingGetTask   NVARCHAR( 20),    -- (james01)
   
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

   @cStorerGroup  = StorerGroup, 
   @cStorerKey    = StorerKey,
   @cFacility     = Facility,
   @cUserName     = UserName,
   @cPrinter      = Printer, 
  
   @cTaskDetailKey   = V_TaskDetailKey,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cOrderKey        = V_OrderKey,
   @cID              = V_ID, 
   @cLOT             = V_Lot, 
      
   @cJobKey             = V_String1,
   @cWorkOrderKey       = V_String2,
   @cWorkStation        = V_String3, 
   @cJobKey             = V_String4,
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
   
   @nNonReserved        = V_Integer1,
   @nWorkQtyRemain      = V_Integer2,
   @nCount              = V_Integer3,    
   @nRecCount           = V_Integer4,    
   
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

IF @nFunc = 1151  -- VAP Uncasing
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- VAP Uncasing
   IF @nStep = 1 GOTO Step_1   -- Scn = 4400. Work Station
	IF @nStep = 2 GOTO Step_2   -- Scn = 4401. Select/Rotate Job
	IF @nStep = 3 GOTO Step_3   -- Scn = 4402. ID, Job ID, Work #
	IF @nStep = 4 GOTO Step_4   -- Scn = 4403. ID, Job ID, Work #, Qty
	IF @nStep = 5 GOTO Step_5   -- Scn = 4404. End Uncasing
	IF @nStep = 6 GOTO Step_6   -- Scn = 4405. ID, SKU, DESCR, Qty, Option
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
   
      SET @cJobKey          = ''  
      SET @cWorkOrderKey    = ''  
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
      SET @nScn = 4400
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
      SET @cWorkStation = @cInField01
	   SET @cJobKey = @cInField02
	   SET @cWorkOrderKey = @cInField03

       --Check blank
      IF ISNULL( @cWorkStation, '') = ''
      BEGIN
         SET @nErrNo = 58601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WrkStation req
         SET @cOutField01 = ''
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      --Check Exists
      IF NOT EXISTS (SELECT 1 
                     FROM dbo.WorkStation WITH (NOLOCK) 
                     WHERE WorkStation = @cWorkStation)
      BEGIN
         SET @nErrNo = 58602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv WrkStation
         SET @cOutField01 = ''
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit

      END

      IF ISNULL( @cJobKey, '') = '' AND ISNULL( @cWorkOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '58603 PLS KEY IN'
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
            SET @nErrNo = 58604
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Job ID

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = ''
            SET @cOutField03 = @cWorkOrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
         /*
         IF EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                     WHERE JobKey = @cJobKey
                     GROUP BY JobKey
                     HAVING COUNT( DISTINCT WorkOrderKey) > 1) 
            AND ISNULL( @cWorkOrderKey, '') = ''
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58605 THE JOB ID'
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
         */
         IF ISNULL( @cWorkOrderKey, '') = ''
            SELECT TOP 1 @cWorkOrderKey = WorkOrderKey 
            FROM dbo.WorkOrderJob WITH (NOLOCK) 
            WHERE JobKey = @cJobKey

         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE JobKey = @cJobKey
                         AND   WorkOrderKey = @cWorkOrderKey)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58606 INVALID'
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
            SET @nErrNo = 58607
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv WORKORDER#

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = @cJobKey
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END
         /*
         IF EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                     WHERE WorkStation = @cWorkStation
                     AND   WorkOrderKey = @cWorkOrderKey
                     GROUP BY WorkOrderKey
                     HAVING COUNT( DISTINCT JobKey) > 1) 
            AND ISNULL( @cJobKey, '') = ''
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58608 WORKORDER #'
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
         */
         IF ISNULL( @cJobKey, '') = ''
            SELECT TOP 1 @cJobKey = JobKey 
            FROM dbo.WorkOrderJob WITH (NOLOCK) 
            WHERE WorkOrderKey = @cWorkOrderKey

         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE JobKey = @cJobKey
                         AND   WorkOrderKey = @cWorkOrderKey)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58609 INVALID'
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

      SET @cVAP_UncasingGetTask = ''
      SET @cVAP_UncasingGetTask = rdt.RDTGetConfig( @nFunc, 'VAPUncasingGetTaskSP', @cStorerKey)

      IF @cVAP_UncasingGetTask NOT IN ('', '0')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cVAP_UncasingGetTask AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cVAP_UncasingGetTask) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cID, @cLOT,  ' + 
               ' @cWorkStation      OUTPUT, @cWorkOrderKey        OUTPUT, @cJobKey              OUTPUT, ' + 
               ' @cTaskDetailKey    OUTPUT, @cWorkOrderName       OUTPUT, @cWorkRoutingDescr    OUTPUT, ' +
               ' @nWorkQtyRemain    OUTPUT, @cTDStatus            OUTPUT, @cWkOrdReqOutputsKey  OUTPUT, ' + 
               ' @cOrderKey         OUTPUT, @cOrderLineNumber     OUTPUT, @cUserKey             OUTPUT, ' + 
               ' @cJobLineNo        OUTPUT, @nRecCount            OUTPUT, @cSKU                 OUTPUT, ' + 
               ' @nErrNo            OUTPUT, @cErrMsg              OUTPUT '

            SET @cSQLParms =
               '@nMobile               INT,                    ' +
               '@nFunc                 INT,                    ' +
               '@cLangCode             NVARCHAR( 3),           ' +
               '@nStep                 INT,                    ' +
               '@nInputKey             INT,                    ' +
               '@cStorerkey            NVARCHAR( 15),          ' +
               '@cID                   NVARCHAR( 18),          ' +
               '@cLOT                  NVARCHAR( 10),          ' +
               '@cWorkStation          NVARCHAR( 10)  OUTPUT,  ' +
               '@cWorkOrderKey         NVARCHAR( 10)  OUTPUT,  ' +
               '@cJobKey               NVARCHAR( 10)  OUTPUT,  ' +
               '@cTaskDetailKey        NVARCHAR( 10)  OUTPUT,  ' +
               '@cWorkOrderName        NVARCHAR( 100) OUTPUT,  ' +
               '@cWorkRoutingDescr     NVARCHAR( 160) OUTPUT,  ' +
               '@nWorkQtyRemain        INT            OUTPUT,  ' +
               '@cTDStatus             NVARCHAR( 10)  OUTPUT,  ' +
               '@cWkOrdReqOutputsKey   NVARCHAR( 10)  OUTPUT,  ' +
               '@cOrderKey             NVARCHAR( 10)  OUTPUT,  ' +
               '@cOrderLineNumber      NVARCHAR( 5)   OUTPUT,  ' +
               '@cUserKey              NVARCHAR( 18)  OUTPUT,  ' +
               '@cJobLineNo            NVARCHAR( 5)   OUTPUT,  ' +
               '@nRecCount             INT            OUTPUT,  ' +
               '@cSKU                  NVARCHAR( 20)  OUTPUT,  ' +
               '@nErrNo                INT            OUTPUT,  ' +
               '@cErrMsg               NVARCHAR( 20)  OUTPUT   ' 

            EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cID, @cLOT, 
               @cWorkStation      OUTPUT, @cWorkOrderKey        OUTPUT, @cJobKey              OUTPUT, 
               @cTaskDetailKey    OUTPUT, @cWorkOrderName       OUTPUT, @cWorkRoutingDescr    OUTPUT, 
               @nWorkQtyRemain    OUTPUT, @cTDStatus            OUTPUT, @cWkOrdReqOutputsKey  OUTPUT, 
               @cOrderKey         OUTPUT, @cOrderLineNumber     OUTPUT, @cUserKey             OUTPUT, 
               @cJobLineNo        OUTPUT, @nRecCount            OUTPUT, @cSKU                 OUTPUT, 
               @nErrNo            OUTPUT, @cErrMsg              OUTPUT 

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END
      ELSE
      BEGIN
         EXEC [RDT].[rdt_VAP_UnCasing_GetNextTask] 
            @nMobile             = @nMobile,                   
            @nFunc               = @nFunc,                     
            @nInputKey           = @nInputKey,                 
            @nStep               = @nStep,                     
            @cStorerKey          = @cStorerKey,
            @cID                 = '',
            @cWorkStation        = @cWorkStation         OUTPUT,
            @cWorkOrderKey       = @cWorkOrderKey        OUTPUT,
            @cJobKey             = @cJobKey              OUTPUT,
            @cTaskDetailKey      = @cTaskDetailKey       OUTPUT,
            @cWorkOrderName      = @cWorkOrderName       OUTPUT, 
            @cWorkRoutingDescr   = @cWorkRoutingDescr    OUTPUT, 
            @nWorkQtyRemain      = @nWorkQtyRemain       OUTPUT, 
            @cTDStatus           = @cTDStatus            OUTPUT,
            @cWkOrdReqOutputsKey = @cWkOrdReqOutputsKey  OUTPUT,
            @cOrderKey           = @cOrderKey            OUTPUT,
            @cOrderLineNumber    = @cOrderLineNumber     OUTPUT,
            @cUserKey            = @cUserKey             OUTPUT,
            @cJobLineNo          = @cJobLineNo           OUTPUT,
            @nRecCount           = @nRecCount            OUTPUT, 
            @cSKU                = @cSKU                 OUTPUT, 
            @cLOT                = ''
      END

	   IF @nRecCount = 0
	   BEGIN
	      SET @nErrNo = 58610
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task!
         GOTO Step_1_Fail
	   END 
	   
      SET @nCount = 1

		-- Prepare Next Screen Variable
      SET @cOutField01 = @cJobKey
      SET @cOutField02 = @cWorkOrderKey
      SET @cOutField03 = @cTDStatus
      SET @cOutField04 = @cWorkOrderName
      SET @cOutField05 = @nWorkQtyRemain
      SET @cOutField06 = SUBSTRING( @cWorkRoutingDescr, 1, 60)  
      SET @cOutField07 = @cSKU
      SET @cOutField08 = ''
      SET @cOutField09 = CAST( @nCount AS NVARCHAR( 2)) + '/' + CAST( @nRecCount AS NVARCHAR( 2))
      
		-- GOTO Next Screen
		SET @nScn = @nScn + 1
	   SET @nStep = @nStep + 1
	    
	   EXEC rdt.rdtSetFocusField @nMobile, 8 
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

   STEP_1_FAIL:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
   END
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
	   SET @cOption = ISNULL(RTRIM(@cInField08),'')

	   IF @cOption = ''
	   BEGIN
         SET @nRecCount = 0

      EXEC [RDT].[rdt_VAP_UnCasing_GetNextTask] 
         @nMobile             = @nMobile,                   
         @nFunc               = @nFunc,                     
         @nInputKey           = @nInputKey,                 
         @nStep               = @nStep,                     
         @cStorerKey          = @cStorerKey,
         @cID                 = '',
         @cWorkStation        = @cWorkStation         OUTPUT,
         @cWorkOrderKey       = @cWorkOrderKey        OUTPUT,
         @cJobKey             = @cJobKey              OUTPUT,
         @cTaskDetailKey      = @cTaskDetailKey       OUTPUT,
         @cWorkOrderName      = @cWorkOrderName       OUTPUT, 
         @cWorkRoutingDescr   = @cWorkRoutingDescr    OUTPUT, 
         @nWorkQtyRemain      = @nWorkQtyRemain       OUTPUT, 
         @cTDStatus           = @cTDStatus            OUTPUT,
         @cWkOrdReqOutputsKey = @cWkOrdReqOutputsKey  OUTPUT,
         @cOrderKey           = @cOrderKey            OUTPUT,
         @cOrderLineNumber    = @cOrderLineNumber     OUTPUT,
         @cUserKey            = @cUserKey             OUTPUT,
         @cJobLineNo          = @cJobLineNo           OUTPUT,
         @nRecCount           = @nRecCount            OUTPUT, 
         @cSKU                = @cSKU            OUTPUT, 
         @cLOT                = ''
   	   
	      IF @nRecCount = 0
	      BEGIN
	         SET @nErrNo = 58611
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task!
            GOTO Step_2_Fail
	      END 

         SET @nCount = @nCount + 1
      	      
	      -- Prepare Next Screen Variable
         SET @cOutField01 = @cJobKey
         SET @cOutField02 = @cWorkOrderKey
         SET @cOutField03 = @cTDStatus
         SET @cOutField04 = @cWorkOrderName
         SET @cOutField05 = @nWorkQtyRemain
         SET @cOutField06 = SUBSTRING( @cWorkRoutingDescr, 1, 60)  
         SET @cOutField07 = @cSKU
         SET @cOutField08 = ''
         SET @cOutField09 = CAST( @nCount AS NVARCHAR( 2)) + '/' + CAST( @nRecCount AS NVARCHAR( 2))

         EXEC rdt.rdtSetFocusField @nMobile, 8
         
	      GOTO QUIT
	   END
		ELSE
		BEGIN
		   IF @cOption <> '1'
		   BEGIN
		      SET @nErrNo = 58612
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
            EXEC rdt.rdtSetFocusField @nMobile, 9
            GOTO Step_2_Fail
		   END

   	   -- Prepare Next Screen Variable
   	   SET @cOutField01 = ''
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
          
   		-- GOTO Next Screen
   		SET @nScn = @nScn + 1
   	   SET @nStep = @nStep + 1   
   	   
   	   EXEC rdt.rdtSetFocusField @nMobile, 1
	   END
	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
      -- Temp only for easy testing
      IF @cUserName = 'JAMES'
      BEGIN
         -- Init screen
         SET @cOutField01 = @cWorkStation
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
      END
      ELSE
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
      END

      -- GOTO Previous Screen
		SET @nScn = @nScn - 1
	   SET @nStep = @nStep - 1
   END
	GOTO Quit

   STEP_2_FAIL:
   BEGIN
      SET @cOutField08 = ''
   END
END 
GOTO QUIT

/********************************************************************************
Step 3. Scn = 3272. 
   PALLET ID      (Field01, input)
   JOB ID         (Field02, input)   
   WORKORDERKEY   (Field03, input)   
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cID  = ISNULL(RTRIM(@cInField01), '')
      SET @cJobKey  = ISNULL(RTRIM(@cInField02), '')
      SET @cWorkOrderKey  = ISNULL(RTRIM(@cInField03), '')

      -- Validate blank
      IF ISNULL( @cID, '') = ''
      BEGIN
         SET @nErrNo = 58613
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pallet ID req'
         GOTO Step_3_Fail
      END

      SET @nNonReserved = 0
      IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJobMove WOJM WITH (NOLOCK) 
                      JOIN dbo.WorkOrderJob WOJ WITH (NOLOCK) ON WOJM.JobKey = WOJ.JobKey
                      WHERE WOJM.ID = @cID
                      AND   WOJM.JobKey = @cJobKey
                      AND   WOJM.Status = '0'
                      AND   WOJ.WorkOrderKey = @cWorkOrderKey
                      AND   WOJ.Facility = @cFacility
                      AND   WOJ.StorerKey = @cStorerKey)
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM LotxLocxID LLI WITH (NOLOCK) 
                         JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
                         WHERE LLI.StorerKey = @cStorerKey
                         AND   LLI.ID = @cID
                         AND   (LLI.Qty - LLI.Qtypicked) > 0
                         AND   LOC.Facility = @cFacility)
                         --AND   EXISTS ( SELECT 1 FROM dbo.CODELKUP CLK WITH (NOLOCK) 
                         --                   WHERE CLK.ListName = 'VAPRSVLOC'
                         --                   AND   CLK.CODE = LLI.LOC))
         BEGIN
            SET @nErrNo = 58614
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Plt ID'
            GOTO Step_3_Fail
         END
         ELSE
            SET @nNonReserved = 1
      END
      ELSE
         SET @nNonReserved = 0
/*
      IF @nNonReserved = 1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   ID = @cID
                     AND   ( Qty - QtyPicked) > 0
                     GROUP BY ID
                     HAVING COUNT( DISTINCT LOC) > 1)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58615 ID LOCATED'
            SET @cErrMsg2 = 'IN > 1 LOCATION !!!'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END

            GOTO Step_3_Fail
         END
      END
*/
      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- If ID or SKU having more than 1 storer then is multi storer else turn multi storer off
         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                     WHERE EXISTS (SELECT 1 FROM dbo.StorerGroup ST WITH (NOLOCK) WHERE LLI.StorerKey = ST.StorerKey AND StorerGroup = @cStorerKey)
                     AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - 
                           (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                     AND    LLI.ID = @cID
                     GROUP BY ID 
                     HAVING COUNT( DISTINCT StorerKey) > 1) 
         BEGIN
            IF NOT EXISTS ( SELECT 1 
                            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                            WHERE  LLI.ID = @cID
                            AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - 
                                  (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                            AND   EXISTS ( SELECT 1 FROM dbo.StorerGroup SG WITH (NOLOCK) 
                                           WHERE SG.StorerGroup = @cStorerGroup 
                                           AND SG.StorerKey = LLI.StorerKey))
            BEGIN
               SET @nErrNo = 58616
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
               GOTO Step_3_Fail
            END
            ELSE
            BEGIN
               SELECT TOP 1 @cChkStorerKey = StorerKey
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               WHERE  ID = @cID
               AND   (QTY - QTYAllocated - QTYPicked - 
                     (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0

               -- Set session storer
               SET @cStorerKey = @cChkStorerKey
               SET @nMultiStorer = 1
            END
         END
         ELSE
         BEGIN
            SELECT TOP 1 @cChkStorerKey = StorerKey
            FROM dbo.LOTxLOCxID LLI (NOLOCK)
            WHERE ID = @cID
               AND (QTY - QTYPicked - QtyAllocated - 
                   (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0

            -- Check storer not in storer group
            IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
            BEGIN
               SET @nErrNo = 58617
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
               GOTO Step_3_Fail
            END

            -- Set session storer
            SET @cStorerKey = @cChkStorerKey
            SET @nMultiStorer = 0
         END
      END

      -- Get ID info
      IF NOT EXISTS( SELECT 1
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END 
            AND ID = @cID
            AND (QTY - QTYPicked - QtyAllocated - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0)
      BEGIN
         SET @nErrNo = 58618
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid ID'
         GOTO Step_3_Fail
      END

      -- If 1 pallet > 1 SKU then need choose which SKU to uncase
      IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
                  WHERE StorerKey = @cStorerKey
                  AND   ID = @cID
                  AND   ( Qty - QtyPicked) > 0
                  AND   Facility = @cFacility
                  AND   EXISTS ( SELECT 1 FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
                                 JOIN dbo.WorkOrderJob WOJ WITH (NOLOCK) ON ( WRI.WorkOrderKey = WOJ.WorkOrderKey)
                                 WHERE WRI.SKU = LLI.SKU
                                 AND   WOJ.JobKey = @cJobKey)
                  GROUP BY ID
                  HAVING COUNT( DISTINCT LOT) > 1)
      BEGIN
         SET @cLOT = ''
         SET @nCount = 1

         EXEC [RDT].[rdt_VAP_UnCasing_GetNextTask] 
            @nMobile             = @nMobile,                   
            @nFunc               = @nFunc,                     
            @nInputKey           = @nInputKey,                 
            @nStep               = @nStep,                     
            @cStorerKey          = @cStorerKey,
            @cID                 = @cID,
            @cWorkStation        = @cWorkStation         OUTPUT,
            @cWorkOrderKey       = @cWorkOrderKey        OUTPUT,
            @cJobKey             = @cJobKey              OUTPUT,
            @cTaskDetailKey      = @cTaskDetailKey       OUTPUT,
            @cWorkOrderName      = @cWorkOrderName       OUTPUT, 
            @cWorkRoutingDescr   = @cWorkRoutingDescr    OUTPUT, 
            @nWorkQtyRemain      = @nWorkQtyRemain       OUTPUT, 
            @cTDStatus           = @cTDStatus            OUTPUT,
            @cWkOrdReqOutputsKey = @cWkOrdReqOutputsKey  OUTPUT,
            @cOrderKey           = @cOrderKey            OUTPUT,
            @cOrderLineNumber    = @cOrderLineNumber     OUTPUT,
            @cUserKey            = @cUserKey             OUTPUT,
            @cJobLineNo          = @cJobLineNo           OUTPUT,
            @nRecCount           = @nRecCount            OUTPUT,
            @cSKU                = @cSKU                 OUTPUT,
            @cLOT                = @cLOT                 OUTPUT

         IF ISNULL( @cSKU, '') = '' OR ISNULL( @cLOT, '') = ''
         BEGIN
            SET @nErrNo = 58619
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No More Record'
            GOTO Step_3_Fail
         END

         SELECT @cSKUDescr = DESCR
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         SELECT @cLottable01 = Lottable01,
                @cLottable02 = Lottable02,
                @cLottable03 = Lottable03
         FROM dbo.LotAttribute WITH (NOLOCK) 
         WHERE LOT = @cLOT

         SELECT @nSKU_Qty = ISNULL( SUM( Qty - QtyPicked), 0)
         FROM dbo.LotxLocxID WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ID = @cID
         AND   SKU = @cSKU
         AND   LOT = @cLOT

         SELECT @nTtl_PltUnCased = ISNULL( SUM( QTY), 0)
         FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
         WHERE WorkOrderKey = @cWorkOrderKey
         AND   ID = @cID
         AND   SKU = @cSKU
         AND   LOT = @cLOT
         AND   [Status] < '9'

   	   SET @cOutField01 = @cID
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField05 = @nSKU_Qty - @nTtl_PltUnCased
         SET @cOutField06 = @cLottable01
         SET @cOutField07 = @cLottable02
         SET @cOutField08 = @cLottable03
         SET @cOutField09 = ''      -- Option
         SET @cOutField10 = CAST( @nCount AS NVARCHAR( 2)) + '/' + CAST( @nRecCount AS NVARCHAR( 2))

         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3

         GOTO Quit
      END
      ELSE
      BEGIN
         SET @cSKU = ''
         SET @cLOT = ''

         -- Only 1 sku on the pallet
         SELECT TOP 1 @cSKU = SKU, @cLOT = LOT
         FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
         WHERE StorerKey = @cStorerKey
         AND   ID = @cID
         AND   ( Qty - QtyPicked) > 0
         AND   Facility = @cFacility
         AND   EXISTS ( SELECT 1 FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
                        JOIN dbo.WorkOrderJob WOJ WITH (NOLOCK) ON ( WRI.WorkOrderKey = WOJ.WorkOrderKey)
                        WHERE WRI.SKU = LLI.SKU
                        AND   WOJ.JobKey = @cJobKey)

         SET @cVAPUnCaseShowQty_SP = rdt.RDTGetConfig( @nFunc, 'VAPUnCaseShowQty_SP', @cStorerKey)
         IF ISNULL(@cVAPUnCaseShowQty_SP, '') NOT IN ('', '0')
         BEGIN
            SET @dStartDate = GETDATE()
            SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cVAPUnCaseShowQty_SP) +     
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, ' + 
               ' @cJobKey, @cWorkOrderKey, @cID, @cSKU, ' + 
               ' @cTtl_PltQty OUTPUT, @cTtl_RemQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

            SET @cSQLParms =    
               '@nMobile              INT,           ' +
               '@nFunc                INT,           ' +
               '@nStep                INT,           ' +
               '@nInputKey            INT,           ' +
               '@cLangCode            NVARCHAR( 3),  ' +
               '@cStorerkey           NVARCHAR( 15), ' +
               '@cJobKey              NVARCHAR( 10), ' +
               '@cWorkOrderKey        NVARCHAR( 10), ' +
               '@cID                  NVARCHAR( 18), ' +
               '@cSKU                 NVARCHAR( 20), ' +
               '@cTtl_PltQty          NVARCHAR( 7)  OUTPUT,  ' +
               '@cTtl_RemQty          NVARCHAR( 7)  OUTPUT,  ' +
               '@nErrNo               INT           OUTPUT,  ' +
               '@cErrMsg              NVARCHAR( 20) OUTPUT   ' 
               
            EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
               @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, 
               @cJobKey, @cWorkOrderKey, @cID, @cSKU, 
               @cTtl_PltQty OUTPUT, @cTtl_RemQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
         ELSE
		   BEGIN
		      SET @nErrNo = 58628
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY SP X SETUP
            GOTO Step_3_Fail
	      END

   	   SET @cOutField01 = @cID
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
         --SET @cOutField04 = CASE WHEN ( @nTtl_PltQty - @nTtl_PltUnCased) < 0 THEN '0' ELSE ( @nTtl_PltQty - @nTtl_PltUnCased) END
         --SET @cOutField05 = CASE WHEN ( @nTtl_JobQty - @nTtl_Uncased) < 0 THEN '0' ELSE ( @nTtl_JobQty - @nTtl_Uncased) END
         SET @cOutField04 = @cTtl_PltQty
         SET @cOutField05 = @cTtl_RemQty
         SET @cOutField06 = CONVERT(NVARCHAR, GETDATE(), 101) + ' ' + 
		                      CONVERT(NVARCHAR, DATEPART(hh, GETDATE())) + ':' + 
		                      RIGHT('0' + CONVERT(NVARCHAR, DATEPART(mi, GETDATE())), 2) 

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

	      EXEC rdt.rdtSetFocusField @nMobile, 5
      END
	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
      SET @cTaskDetailKey = ''
      SET @nCount = 1
      EXEC [RDT].[rdt_VAP_UnCasing_GetNextTask] 
         @nMobile             = @nMobile,                   
         @nFunc               = @nFunc,                     
         @nInputKey           = @nInputKey,                 
         @nStep               = @nStep,                     
         @cStorerKey          = @cStorerKey,
         @cID                 = '',
         @cWorkStation        = @cWorkStation         OUTPUT,
         @cWorkOrderKey       = @cWorkOrderKey        OUTPUT,
         @cJobKey             = @cJobKey              OUTPUT,
         @cTaskDetailKey      = @cTaskDetailKey       OUTPUT,
         @cWorkOrderName      = @cWorkOrderName       OUTPUT, 
         @cWorkRoutingDescr   = @cWorkRoutingDescr    OUTPUT, 
         @nWorkQtyRemain      = @nWorkQtyRemain       OUTPUT, 
         @cTDStatus           = @cTDStatus            OUTPUT,
         @cWkOrdReqOutputsKey = @cWkOrdReqOutputsKey  OUTPUT,
         @cOrderKey           = @cOrderKey            OUTPUT,
         @cOrderLineNumber    = @cOrderLineNumber     OUTPUT,
         @cUserKey            = @cUserKey             OUTPUT,
         @cJobLineNo          = @cJobLineNo           OUTPUT,
         @nRecCount           = @nRecCount            OUTPUT, 
         @cSKU                = @cSKU                 OUTPUT, 
         @cLOT                = ''

		-- Prepare Next Screen Variable
      SET @cOutField01 = @cJobKey
      SET @cOutField02 = @cWorkOrderKey
      SET @cOutField03 = @cTDStatus
      SET @cOutField04 = @cWorkOrderName
      SET @cOutField05 = @nWorkQtyRemain
      SET @cOutField06 = SUBSTRING( @cWorkRoutingDescr, 1, 60)  
      SET @cOutField07 = @cSKU
      SET @cOutField08 = ''
      SET @cOutField09 = CAST( @nCount AS NVARCHAR( 2)) + '/' + CAST( @nRecCount AS NVARCHAR( 2))
            
      -- GOTO Previous Screen
		SET @nScn = @nScn - 1
	   SET @nStep = @nStep - 1
   END
	GOTO Quit

   STEP_3_FAIL:
   BEGIN
      SET @cID = ''
      SET @cOutField01 = ''
      SET @cOutField02 = @cJobKey
      SET @cOutField03 = @cWorkOrderKey
      SET @cOutField04 = @cQty
      SET @cOutField05 = @cStartTime 
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO Quit      
   END
END 
GOTO QUIT

/********************************************************************************
Step 4. Scn = 3272. 
   PALLET ID      (Field01)
   JOB ID         (Field02)   
   WORKORDERKEY   (Field03)   
   QTY            (Field04, input)   
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
		SET @cQty = ISNULL(@cInField04, '') 
      SET @cStartTime = ISNULL(@cOutField05, '') 

      IF @cID = '' AND @cQty = ''
      BEGIN
         -- Prepare next screen variable
         SET @cOutField01 = ''
         SET @cOutField02 = CONVERT(NVARCHAR, GETDATE(), 101) + ' ' + 
		                      CONVERT(NVARCHAR, DATEPART(hh, GETDATE())) + ':' + 
		                      RIGHT('0' + CONVERT(NVARCHAR, DATEPART(mi, GETDATE())), 2) 

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END

		IF ISNULL( @cQty, '') = ''
		BEGIN
		   SET @nErrNo = 58620
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qty Req
         GOTO Step_4_Fail
	   END

      IF rdt.rdtIsValidQTY( @cQty, 1) = 0
		BEGIN
		   SET @nErrNo = 58621
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_4_Fail
	   END

      SET @nQty = CAST( @cQty AS INT)

      SELECT @nTtl_Uncased = ISNULL( SUM( QTY), 0)
      FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
      WHERE ID = @cID
      AND   JobKey = @cJobKey
      AND   WorkOrderKey = @cWorkOrderKey
      AND   [Status] < '9'

      SELECT @nTtl_2Uncase = ISNULL( SUM( Qty - QtyPicked), 0)
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ID = @cID

      IF @nTtl_2Uncase < ( @nQty + @nTtl_Uncased)
		BEGIN
		   SET @nErrNo = 58622
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Uncasing
         GOTO Step_4_Fail
	   END

      SET @cVAPUncasingCfm_SP = rdt.RDTGetConfig( @nFunc, 'VAPUncasingCfm_SP', @cStorerKey)
      IF @cVAPUncasingCfm_SP NOT IN ('', '0')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cVAPUncasingCfm_SP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @dStartDate = GETDATE()
            SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cVAPUncasingCfm_SP) +     
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, ' + 
               ' @cWorkStation, @cJobKey, @cWorkOrderKey, @cTaskDetailKey, @cID, @cSKU, ' + 
               ' @cLOT, @nQty, @dStartDate, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

            SET @cSQLParms =    
               '@nMobile              INT,           ' +
               '@nFunc                INT,           ' +
               '@nStep                INT,           ' +
               '@nInputKey            INT,           ' +
               '@cLangCode            NVARCHAR( 3),  ' +
               '@cStorerkey           NVARCHAR( 15), ' +
               '@cWorkStation         NVARCHAR( 20), ' +
               '@cJobKey              NVARCHAR( 10), ' +
               '@cWorkOrderKey        NVARCHAR( 10), ' +
               '@cTaskDetailKey       NVARCHAR( 10), ' +
               '@cID                  NVARCHAR( 18), ' +
               '@cSKU                 NVARCHAR( 20), ' +
               '@cLOT                 NVARCHAR( 10), ' +
               '@nQty                 INT,           ' +
               '@dStartDate           DATETIME,      ' +
               '@nErrNo               INT           OUTPUT,  ' +
               '@cErrMsg              NVARCHAR( 20) OUTPUT   ' 
                  
            EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
               @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, 
               @cWorkStation, @cJobKey, @cWorkOrderKey, @cTaskDetailKey, @cID, @cSKU, 
               @cLOT, @nQty, @dStartDate, @nErrNo OUTPUT, @cErrMsg OUTPUT  

            IF @nErrNo <> 0
               GOTO Step_4_Fail
         END
      END
      ELSE
		BEGIN
		   SET @nErrNo = 0
         EXEC rdt.rdt_VAPUnCasingConfirm 
            @nMobile        = @nMobile, 
            @nFunc          = @nFunc, 
            @nStep          = @nStep, 
            @nInputKey      = @nInputKey, 
            @cLangCode      = @cLangCode, 
            @cStorerkey     = @cStorerkey, 
            @cWorkStation   = @cWorkStation, 
            @cJobKey        = @cJobKey, 
            @cWorkOrderKey  = @cWorkOrderKey ,
            @cTaskDetailKey = @cTaskDetailKey,
            @cID            = @cID, 
            @cSKU           = @cSKU, 
            @cLOT           = @cLOT, 
            @nQty           = @nQty,          
            @dStartDate     = @dStartDate,    
            @nErrNo         = @nErrNo         OUTPUT, 
            @cErrMsg        = @cErrMsg        OUTPUT  

         IF @nErrNo <> 0
            GOTO Step_4_Fail
	   END

   	SET @cOutField01 = ''
      SET @cOutField02 = @cJobKey
      SET @cOutField03 = @cWorkOrderKey

      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  

	   EXEC rdt.rdtSetFocusField @nMobile, 1
	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
   	SET @cOutField01 = ''
      SET @cOutField02 = @cJobKey
      SET @cOutField03 = @cWorkOrderKey

      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  

	   EXEC rdt.rdtSetFocusField @nMobile, 1
   END
	GOTO Quit

   STEP_4_FAIL:
   BEGIN
      SELECT @nTtl_Uncased = ISNULL( SUM( QTY), 0)
      FROM dbo.WorkOrder_UnCasing U WITH (NOLOCK) 
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( U.SKU = SKU.SKU AND U.StorerKey = SKU.StorerKey)
      WHERE U.WorkOrderKey = @cWorkOrderKey
      AND   U.Status < '9'
      AND   SKU.BUSR3 = 'DGE-GEN'
      AND   SKU.StorerKey = @cStorerKey

      SELECT @nTtl_JobQty = ISNULL( SUM( Qty), 0)
      FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( WRI.SKU = SKU.SKU AND WRI.StorerKey = SKU.StorerKey)
      WHERE WRI.WorkOrderKey = @cWorkOrderKey
      AND   SKU.BUSR3 = 'DGE-GEN'
      AND   SKU.StorerKey = @cStorerKey

      SELECT @nTtl_PltUnCased = ISNULL( SUM( QTY), 0)
      FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderKey
      AND   ID = @cID
      AND   [Status] < '9'

      SELECT @nTtl_PltQty = ISNULL( SUM( QTY), 0) 
      FROM dbo.WorkOrderJobMove WITH (NOLOCK) 
      WHERE JobKey = @cJobKey 
      AND   ID = @cID
      AND   [Status] = '0'

   	SET @cOutField01 = @cID
      SET @cOutField02 = @cJobKey
      SET @cOutField03 = @cWorkOrderKey
      SET @cOutField04 = CASE WHEN ( @nTtl_PltQty - @nTtl_PltUnCased) < 0 THEN '0' ELSE ( @nTtl_PltQty - @nTtl_PltUnCased) END
      SET @cOutField05 = CASE WHEN ( @nTtl_JobQty - @nTtl_Uncased) < 0 THEN '0' ELSE ( @nTtl_JobQty - @nTtl_Uncased) END
      SET @cOutField06 = @cStartTime
      
	   EXEC rdt.rdtSetFocusField @nMobile, 5
   END
END 
GOTO QUIT

/********************************************************************************
Step 5. Scn = 4403. 
   PALLET ID   (Field01, input)
   SSCC        (Field02, input)
   QTY         (Field03, input)   
   START TIME  (Field04, display)      
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cID  = ISNULL(RTRIM(@cInField01),'')
      SET @cEndTime  = ISNULL(RTRIM(@cOutField02),'')
	   
      -- Validate blank
      IF ISNULL( @cID, '') = ''
      BEGIN
         SET @nErrNo = 58624
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pallet ID req'
         GOTO Step_5_Fail
      END

   	IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
                      WHERE ID = @cID
                      AND   StorerKey = @cStorerKey
                      AND   [Status] = '0')
      BEGIN
         SET @nErrNo = 58625
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ID not uncased'
         GOTO Step_5_Fail
      END

      UPDATE dbo.WorkOrder_UnCasing WITH (ROWLOCK) SET 
         EndDate = CAST( @cEndTime AS DATETIME)
      WHERE ID = @cID
      AND   StorerKey = @cStorerKey
      AND   [Status] < '9'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58626
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'End uncasing fail'
         GOTO Step_5_Fail
      END

		SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      
		EXEC rdt.rdtSetFocusField @nMobile, 1
		
		SET @nScn = @nScn - 4
	   SET @nStep = @nStep - 4
	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
		SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      
		EXEC rdt.rdtSetFocusField @nMobile, 1
		
		SET @nScn = @nScn - 4
	   SET @nStep = @nStep - 4
   END
	GOTO Quit

   STEP_5_FAIL:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = @cEndTime
   END
END 
GOTO QUIT

/********************************************************************************
Step 6. Scn = 4405. 
   PALLET ID   (Field01, display)
   SKU         (Field02, display)
   DESCR       (Field03, display)
   QTY         (Field04, display)   
   OPTION      (Field05, input)      
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cSKU = @cOutField02
	   SET @cOption = @cInField09

      IF ISNULL( @cOption, '') = ''
      BEGIN
         SET @cPrev_SKU = @cSKU

         -- Get next sku on the pallet
         EXEC [RDT].[rdt_VAP_UnCasing_GetNextTask] 
            @nMobile             = @nMobile,                   
            @nFunc               = @nFunc,                     
            @nInputKey           = @nInputKey,                 
            @nStep               = @nStep,                     
            @cStorerKey          = @cStorerKey,
            @cID                 = @cID,
            @cWorkStation        = @cWorkStation         OUTPUT,
            @cWorkOrderKey       = @cWorkOrderKey        OUTPUT,
            @cJobKey             = @cJobKey              OUTPUT,
            @cTaskDetailKey      = @cTaskDetailKey       OUTPUT,
            @cWorkOrderName      = @cWorkOrderName       OUTPUT, 
            @cWorkRoutingDescr   = @cWorkRoutingDescr    OUTPUT, 
            @nWorkQtyRemain      = @nWorkQtyRemain       OUTPUT, 
            @cTDStatus           = @cTDStatus            OUTPUT,
            @cWkOrdReqOutputsKey = @cWkOrdReqOutputsKey  OUTPUT,
            @cOrderKey           = @cOrderKey            OUTPUT,
            @cOrderLineNumber    = @cOrderLineNumber     OUTPUT,
            @cUserKey            = @cUserKey             OUTPUT,
            @cJobLineNo          = @cJobLineNo           OUTPUT,
            @nRecCount           = @nRecCount            OUTPUT,
            @cSKU                = @cSKU                 OUTPUT,
            @cLOT                = @cLOT                 OUTPUT

         IF ISNULL( @cSKU, '') = '' OR ISNULL( @cLOT, '') = ''
         BEGIN
            SET @cSKU = @cPrev_SKU
            SET @nErrNo = 58627
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No More Record'
            GOTO Step_6_Fail
         END
         ELSE
         BEGIN
            SET @nCount = @nCount + 1

            SELECT @cSKUDescr = DESCR
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   SKU = @cSKU

            SELECT @cLottable01 = Lottable01,
                   @cLottable02 = Lottable02,
                   @cLottable03 = Lottable03
            FROM dbo.LotAttribute WITH (NOLOCK) 
            WHERE LOT = @cLOT

            SELECT @nSKU_Qty = 0, @nTtl_PltUnCased = 0

            SELECT @nSKU_Qty = ISNULL( SUM( Qty - QtyPicked), 0)
            FROM dbo.LotxLocxID WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND   ID = @cID
            AND   SKU = @cSKU
            AND   LOT = @cLOT

            SELECT @nTtl_PltUnCased = ISNULL( SUM( QTY), 0)
            FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
            WHERE WorkOrderKey = @cWorkOrderKey
            AND   ID = @cID
            AND   SKU = @cSKU
            AND   LOT = @cLOT
            AND   [Status] < '9'

   	      SET @cOutField01 = @cID
            SET @cOutField02 = @cSKU
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
            SET @cOutField05 = @nSKU_Qty - @nTtl_PltUnCased
            SET @cOutField06 = @cLottable01
            SET @cOutField07 = @cLottable02
            SET @cOutField08 = @cLottable03
            SET @cOutField09 = ''      -- Option
            SET @cOutField10 = CAST( @nCount AS NVARCHAR( 2)) + '/' + CAST( @nRecCount AS NVARCHAR( 2))

            GOTO Quit
         END
      END

      -- Validate blank
      IF ISNULL( @cOption, '') <> '1'
      BEGIN
         SET @nErrNo = 58627
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_6_Fail
      END

      IF @cOption = '1'
      BEGIN
         /*
         SELECT @nTtl_Uncased = 0, @nTtl_JobQty = 0, 
                @nTtl_PltUnCased = 0, @nTtl_PltQty = 0

         SELECT @nTtl_Uncased = ISNULL( SUM( QTY), 0)
         FROM dbo.WorkOrder_UnCasing U WITH (NOLOCK) 
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( U.SKU = SKU.SKU AND U.StorerKey = SKU.StorerKey)
         WHERE U.WorkOrderKey = @cWorkOrderKey
         AND   U.Status < '9'
         AND   SKU.BUSR3 = 'DGE-GEN'
         AND   SKU.StorerKey = @cStorerKey

         SELECT @nTtl_JobQty = ISNULL( SUM( Qty), 0)
         FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( WRI.SKU = SKU.SKU AND WRI.StorerKey = SKU.StorerKey)
         WHERE WRI.WorkOrderKey = @cWorkOrderKey
         AND   SKU.BUSR3 = 'DGE-GEN'
         AND   SKU.StorerKey = @cStorerKey

         SELECT @nTtl_PltUnCased = ISNULL( SUM( QTY), 0)
         FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
         WHERE WorkOrderKey = @cWorkOrderKey
         AND   ID = @cID
         AND   [Status] < '9'

         SELECT @nTtl_PltQty = ISNULL( SUM( QTY), 0) 
         FROM dbo.WorkOrderJobMove WITH (NOLOCK) 
         WHERE JobKey = @cJobKey 
         AND   ID = @cID
         AND   [Status] = '0'
         */

         SET @cVAPUnCaseShowQty_SP = rdt.RDTGetConfig( @nFunc, 'VAPUnCaseShowQty_SP', @cStorerKey)
         IF ISNULL(@cVAPUnCaseShowQty_SP, '') NOT IN ('', '0')
         BEGIN
            SET @dStartDate = GETDATE()
            SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cVAPUnCaseShowQty_SP) +     
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, ' + 
               ' @cJobKey, @cWorkOrderKey, @cID, @cSKU, ' + 
               ' @cTtl_PltQty OUTPUT, @cTtl_RemQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

            SET @cSQLParms =    
               '@nMobile              INT,           ' +
               '@nFunc                INT,           ' +
               '@nStep                INT,           ' +
               '@nInputKey            INT,           ' +
               '@cLangCode            NVARCHAR( 3),  ' +
               '@cStorerkey           NVARCHAR( 15), ' +
               '@cJobKey              NVARCHAR( 10), ' +
               '@cWorkOrderKey        NVARCHAR( 10), ' +
               '@cID                  NVARCHAR( 18), ' +
               '@cSKU                 NVARCHAR( 20), ' +
               '@cTtl_PltQty          NVARCHAR( 7)  OUTPUT,  ' +
               '@cTtl_RemQty          NVARCHAR( 7)  OUTPUT,  ' +
               '@nErrNo               INT           OUTPUT,  ' +
               '@cErrMsg              NVARCHAR( 20) OUTPUT   ' 
               
            EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
               @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, 
               @cJobKey, @cWorkOrderKey, @cID, @cSKU, 
               @cTtl_PltQty OUTPUT, @cTtl_RemQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
         ELSE
		   BEGIN
		      SET @nErrNo = 58629
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY SP X SETUP
            GOTO Step_3_Fail
	      END

   	   SET @cOutField01 = @cID
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
         --SET @cOutField04 = CASE WHEN ( @nTtl_PltQty - @nTtl_PltUnCased) < 0 THEN '0' ELSE ( @nTtl_PltQty - @nTtl_PltUnCased) END
         --SET @cOutField05 = CASE WHEN ( @nTtl_JobQty - @nTtl_Uncased) < 0 THEN '0' ELSE ( @nTtl_JobQty - @nTtl_Uncased) END
         SET @cOutField04 = @cTtl_PltQty
         SET @cOutField05 = @cTtl_RemQty
         SET @cOutField06 = CONVERT(NVARCHAR, GETDATE(), 101) + ' ' + 
		                      CONVERT(NVARCHAR, DATEPART(hh, GETDATE())) + ':' + 
		                      RIGHT('0' + CONVERT(NVARCHAR, DATEPART(mi, GETDATE())), 2) 

         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2

	      EXEC rdt.rdtSetFocusField @nMobile, 5         
      END
	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
   	SET @cOutField01 = ''
      SET @cOutField02 = @cJobKey
      SET @cOutField03 = @cWorkOrderKey
      
		EXEC rdt.rdtSetFocusField @nMobile, 1
		
		SET @nScn = @nScn - 3
	   SET @nStep = @nStep - 3
   END
	GOTO Quit

   STEP_6_FAIL:
   BEGIN
      SET @cOption = ''
      SET @cOutField06 = ''
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

      StorerGroup = @cStorerGroup, 
      StorerKey   = @cStorerKey,
      Facility    = @cFacility, 
      Printer     = @cPrinter, 
      -- UserName    = @cUserName,
		InputKey    =	@nInputKey,
		
      V_TaskDetailKey = @cTaskDetailKey,
      V_SKU           = @cSKU,
      V_SKUDescr      = @cSKUDescr,
      V_OrderKey      = @cOrderKey,
      V_ID            = @cID,
      V_Lot           = @cLOT, 
         
      V_String1 = @cJobKey,
      V_String2 = @cWorkOrderKey,
      V_String3 = @cWorkStation, 
      
      V_String4   = @cJobKey,
      V_String5   = @cWorkOrderName,
      V_String6   = @cInLoc,
      V_String7   = @cOutLoc,
      V_String9   = @cStartTime,
      V_String10  = @cEndTime,
         
      V_String12 =  @cOrderLineNumber,
      v_String13 =  @cWkOrdReqOutputsKey,
      V_String14 =  @cJobStatus,
      V_String15 =  @cTDStatus,
      V_String16 =  @cJobLineNo, 
      
      V_Integer1 =  @nNonReserved,
      V_Integer2 =  @nWorkQtyRemain,
      V_Integer3 =  @nCount,     
      V_Integer4 =  @nRecCount, 

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
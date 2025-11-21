SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: WorkOrder Operation (Palletize)                                   */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2015-11-26 1.0  James      SOS315942 Created                               */
/* 2015-02-26 1.1  James      SOS362979 - SSCC generation (james01)           */
/*                            SOS364044 - Support palletize by UOM (james02)  */
/* 2016-09-30 1.2  Ung        Performance tuning                              */
/* 2018-11-21 1.3  TungGH     Performance                                     */  
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_VAP_Palletize] (
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
   @cJobKey             NVARCHAR( 10),
   @cWorkOrderKey       NVARCHAR( 10),
   @cID                 NVARCHAR( 20),
   @cToID               NVARCHAR( 18),
   @cSKU                NVARCHAR( 20),
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
   @cLottable04         NVARCHAR( 20),
   @cLottable05         NVARCHAR( 20),
   @cLottable13         NVARCHAR( 20),
   @cLottable14         NVARCHAR( 20),
   @cLottable15         NVARCHAR( 20),

   @cSSCC               NVARCHAR( 20),
   @cStartTime          NVARCHAR( 20),
   @cEndTime            NVARCHAR( 20),
   @cStorerGroup        NVARCHAR( 20),
   @cChkStorerKey       NVARCHAR( 20),
   @cQtyToComplete      NVARCHAR( 10),
   @cQtyRemain          NVARCHAR( 10),
   @cStatus             NVARCHAR( 10),
   @cPrintLabel         NVARCHAR( 10),
   @cEndPallet          NVARCHAR( 10),
   @cWorkOrderUdf01     NVARCHAR( 18),
   @cWorkOrderUdf04     NVARCHAR( 18),
   @cReportType         NVARCHAR( 10),
   @cPrintJobName       NVARCHAR( 50),
   @cDataWindow         NVARCHAR( 50),
   @cTargetDB           NVARCHAR( 20),
   @cLabelPrinter       NVARCHAR( 10),
   @cPaperPrinter       NVARCHAR( 10),
   @cPackKey            NVARCHAR( 10),
   @cOutputSKU          NVARCHAR( 20),
   @cOutputUOM          NVARCHAR( 10),
   @cLottableCode       NVARCHAR( 30),
   @nMorePage              INT,
   @nFromScn               INT,
   @nWorkOutPutQty         INT,
   @nRecCount              INT,
   @nQty                   INT,
   @nMultiStorer           INT,
   @nQtyRemaining          INT,
   @nQtyToComplete         INT,
   @nTtlCount              INT,
   @nTtl_PalletizedQty     INT,
   @nPUOM_Div              INT,
   @nMulti                 INT,
   @cStartDate             NVARCHAR( 20),
   @cVAP_PalletizeGetTask  NVARCHAR( 20),       -- (james02)
   @cExtendedValidateSP    NVARCHAR( 20),       -- (james02)
   @cSQL                   NVARCHAR( 2000),     -- (james02)
   @cSQLParam              NVARCHAR( 2000),     -- (james02)
   @cPUOM                  NVARCHAR( 1),        -- (james02)
   @cLOT                   NVARCHAR( 10),       -- (james02)
   @cPUOM_Desc             NCHAR( 5),           -- (james02)
   @cMUOM_Desc             NCHAR( 5),           -- (james02)
   @nPQTY                  INT,                 -- (james02)
   @nMQTY                  INT,                 -- (james02)
   @cPQty                  NVARCHAR( 7),        -- (james02)
   @cMQty                  NVARCHAR( 7),        -- (james02)
   @cExtendedUpdateSP      NVARCHAR( 20),       -- (james02)
   @dStartDate             DATETIME,            -- (james02)
   @cType                  NVARCHAR( 1),        -- (james02)
   @cExtendedDeleteSP      NVARCHAR( 20),       -- (james02)
   @cVAPPalletizeCfmSP     NVARCHAR( 20),       -- (james02)

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
   @cSKU       = V_SKU,
   @cToID      = V_ID, 
   @cPUOM      = V_UOM,
      
   @cStartDate          = V_String1,
   @cEndTime            = V_String2,
   @cWorkStation        = V_String3, 
   @cWorkOrderKey       = V_String4,  
   @cPackKey            = V_String8,
   @cOutputUOM          = V_String9,
   @cJobKey             = V_String10,
   @cStartTime          = V_String11,
   @cEndTime            = V_String12,
   @cMUOM_Desc          = V_String13,
   @cPUOM_Desc          = V_String14,     
   @cLottableCode       = V_String16,      
   @cWorkOrderUdf01     = V_String19, 
   @cWorkOrderUdf04     = V_String20, 
   
   @nTtlCount           = V_Integer1,
   @nQtyRemaining       = V_Integer2,     
   @nRecCount           = V_Integer3,
   @nMulti              = V_Integer4,
      
   @nPQTY               = V_PQTY,
   @nMQTY               = V_MQTY,
   @nPUOM_Div           = V_PUOM_Div,   
   @nFromScn            = V_FromScn,

   @cLottable01 = V_Lottable01, 
   @cLottable02 = V_Lottable02, 
   @cLottable03 = V_Lottable03, 
   @dLottable04 = V_Lottable04, 
   @dLottable05 = V_Lottable05, 
   @cLottable06 = V_Lottable06, 
   @cLottable07 = V_Lottable07, 
   @cLottable08 = V_Lottable08, 
   @cLottable09 = V_Lottable09, 
   @cLottable10 = V_Lottable10, 
   @cLottable11 = V_Lottable11, 
   @cLottable12 = V_Lottable12, 
   @dLottable13 = V_Lottable13, 
   @dLottable14 = V_Lottable14, 
   @dLottable15 = V_Lottable15, 
   
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

IF @nFunc = 1153  -- VAP Uncasing
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- VAP Uncasing
   IF @nStep = 1 GOTO Step_1   -- Scn = 4430. PALLET ID, START TIME
	IF @nStep = 2 GOTO Step_2   -- Scn = 4431. LOTTABLE, OPTION
   IF @nStep = 3 GOTO Step_3   -- Scn = 4432. LOTTABLE, QTY, PRINT LABEL, END PALLET
   IF @nStep = 4 GOTO Step_4   -- Scn = 4434. PALLET ID, END TIME
   IF @nStep = 5 GOTO Step_5   -- Scn = 4435. MESSAGE
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

   -- Get default UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

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
      SET @cID = ''  
	   SET @cToID = ''
      SET @cJobKey = ''
      SET @cWorkOrderKey = ''
      SET @cStartDate = CONVERT(NVARCHAR, GETDATE(), 101) + ' ' + 
		                  CONVERT(NVARCHAR, DATEPART(hh, GETDATE())) + ':' + 
		                  RIGHT('0' + CONVERT(NVARCHAR, DATEPART(mi, GETDATE())), 2) 

      SET @cLottable01 = ''
      SET @cLottable02 = '' 
      SET @cLottable03 = '' 
      SET @dLottable04 = NULL
      SET @dLottable05 = NULL 
      SET @cLottable06 = ''
      SET @cLottable07 = '' 
      SET @cLottable08 = '' 
      SET @cLottable09 = '' 
      SET @cLottable10 = '' 
      SET @cLottable11 = '' 
      SET @cLottable12 = '' 
      SET @dLottable13 = NULL
      SET @dLottable14 = NULL
      SET @dLottable15 = NULL

      -- Init screen
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = @cStartDate

      EXEC rdt.rdtSetFocusField @nMobile, 1
	
      -- Set the entry point
      SET @nScn = 4430
      SET @nStep = 1
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 4430. 
   PALLET ID    (Field01, input)
   START TIME   (Field02, display)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cToID = @cInField01
      SET @cJobKey = @cInField02
      SET @cWorkOrderKey = @cInField03

      IF ISNULL( @cToID, '') = ''
		BEGIN
		   SET @nErrNo = 58751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet id req
         SET @cOutField01 = ''
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
         SET @cOutField04 = @cStartDate 
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
	   END
      
      IF ISNULL( @cJobKey, '') = '' AND ISNULL( @cWorkOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '58753 PLS KEY IN'
         SET @cErrMsg2 = 'EITHER JOB ID'
         SET @cErrMsg3 = 'OR WORKORDER #.'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END

         SET @cOutField01 = @cToID
         SET @cOutField04 = @cStartDate 
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      IF ISNULL( @cJobKey, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE JobKey = @cJobKey)
         BEGIN
            SET @nErrNo = 58754
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Job ID

            SET @cOutField01 = @cToID
            SET @cOutField02 = ''
            SET @cOutField03 = @cWorkOrderKey
            SET @cOutField04 = @cStartDate 
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- If it is 1 job 1 workorder then get the workorderkey
         IF NOT EXISTS ( SELECT 1 
                         FROM dbo.WorkOrder_UnCasing WITH (NOLOCK)
                         WHERE JobKey = @cJobKey
                         GROUP BY JobKey
                         HAVING COUNT( DISTINCT WorkOrderKey) > 1)
            SELECT TOP 1 @cWorkOrderKey = WorkOrderKey 
            FROM dbo.WorkOrderJob WITH (NOLOCK) 
            WHERE JobKey = @cJobKey
         ELSE
            SET @cWorkOrderKey = ''
      END

      IF ISNULL( @cWorkOrderKey, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE WorkOrderKey = @cWorkOrderKey)
         BEGIN
            SET @nErrNo = 58757
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv WORKORDER#

            SET @cOutField01 = @cToID
            SET @cOutField02 = @cJobKey
            SET @cOutField03 = ''
            SET @cOutField04 = @cStartDate 
            EXEC rdt.rdtSetFocusField @nMobile, 3
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
            SET @cErrMsg1 = '58759 INVALID'
            SET @cErrMsg2 = 'JOB ID + WORKORDER #'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END

            SET @cOutField01 = @cToID
            SET @cOutField02 = ''
            SET @cOutField03 = @cWorkOrderKey
            SET @cOutField04 = @cStartDate 
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderRequestOutputs WITH (NOLOCK) 
                         WHERE WorkOrderKey = @cWorkOrderKey
                         AND   ( Qty - ISNULL( QtyCompleted, 0)) > 0)
		   BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58775'
            SET @cErrMsg2 = 'WORKORDER FINISHED'
            SET @cErrMsg3 = 'PALLETIZE !!'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
            END

            SET @cOutField01 = @cToID
            SET @cOutField02 = @cJobKey
            SET @cOutField03 = @cWorkOrderKey
            SET @cOutField04 = @cStartDate 
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
	      END
      END

      -- Check pallet to palletize must be a empty pallet or 
      -- a pallet that is left to continue palletize
      IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
                  WHERE ID = @cToID
                  AND   Facility = @cFacility
                  AND   ( Qty - QtyPicked) > 0)
         AND NOT EXISTS
                ( SELECT 1 FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
                  WHERE ID = @cID
                  AND   [Status] < '9')
		BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '58752'
         SET @cErrMsg2 = 'PALLET ALREADY HAS'
         SET @cErrMsg3 = 'INVENTORY ON IT!!!'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         -- Proceed
         SET @nErrNo = 0
	   END

      SET @nMulti = 0
      IF ISNULL( @cWorkOrderKey, '') = ''
      BEGIN
         IF EXISTS ( SELECT 1 
                     FROM dbo.WorkOrder_UnCasing WITH (NOLOCK)
                     WHERE JobKey = @cJobKey
                     GROUP BY JobKey
                     HAVING COUNT( DISTINCT WorkOrderKey) > 1)
            SET @nMulti = 1
      END

      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP NOT IN ('0', '')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cToID, @cJobKey, @cWorkOrderKey, ' +
            ' @cSKU, @nQtyToComplete, @cPrintLabel, @cEndPallet, @dStartDate, @cType, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile                   INT,           ' +
            '@nFunc                     INT,           ' +
            '@cLangCode                 NVARCHAR( 3),  ' +
            '@nStep                     INT,           ' +
            '@nInputKey                 INT,           ' +
            '@cStorerkey                NVARCHAR( 15), ' +
            '@cToID                     NVARCHAR( 18), ' +
            '@cJobKey                   NVARCHAR( 10), ' +
            '@cWorkOrderKey             NVARCHAR( 10), ' +
            '@cSKU                      NVARCHAR( 20), ' +
            '@nQtyToComplete            INT,           ' +
            '@cPrintLabel               NVARCHAR( 10), ' +
            '@cEndPallet                NVARCHAR( 10), ' +
            '@dStartDate                DATETIME,      ' +
            '@cType                     NVARCHAR( 1),  ' + 
            '@nErrNo                    INT           OUTPUT,  ' +
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cToID, @cJobKey, @cWorkOrderKey, 
            @cSKU, @nQtyToComplete, @cPrintLabel, @cEndPallet, @dStartDate, @cType, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT 

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
            GOTO Quit
         END
      END

      SELECT TOP 1
             @cWorkOrderUdf01 = Udf1,
             @cWorkOrderUdf04 = Udf4
      FROM dbo.WorkOrderRequest WOR WITH (NOLOCK) 
      JOIN dbo.WorkOrder_Uncasing U WITH (NOLOCK) ON ( WOR.WorkOrderKey = U.WorkOrderKey)
      WHERE U.JobKey = @cJobKey
      AND   U.WorkOrderKey = CASE WHEN @nMulti = 1 THEN U.WorkOrderKey ELSE @cWorkOrderKey END

      SET @nTtlCount = 0

      SET @cVAP_PalletizeGetTask = ''
      SET @cVAP_PalletizeGetTask = rdt.RDTGetConfig( @nFunc, 'VAPPalletizeGetTaskSP', @cStorerKey)

      IF @cVAP_PalletizeGetTask NOT IN ('', '0')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cVAP_PalletizeGetTask AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cVAP_PalletizeGetTask) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cID, @cJobKey, @cWorkOrderKey, ' + 
               ' @cSKU              OUTPUT, @cLOT                 OUTPUT, @nQtyRemaining        OUTPUT, ' + 
               ' @nTtlCount         OUTPUT, @cLottable01          OUTPUT, @cLottable02          OUTPUT, ' +
               ' @cLottable03       OUTPUT, @dLottable04          OUTPUT, @dLottable05          OUTPUT, ' + 
               ' @cLottable06       OUTPUT, @cLottable07          OUTPUT, @cLottable08          OUTPUT, ' + 
               ' @cLottable09       OUTPUT, @cLottable10          OUTPUT, @cLottable11          OUTPUT, ' + 
               ' @cLottable12       OUTPUT, @dLottable13          OUTPUT, @dLottable14          OUTPUT, ' + 
               ' @dLottable15       OUTPUT, @nErrNo               OUTPUT, @cErrMsg              OUTPUT  ' 

            SET @cSQLParam =
               '@nMobile             INT,             ' +
               '@nFunc               INT,             ' +
               '@cLangCode           NVARCHAR( 3),    ' +
               '@nInputKey           INT,             ' +
               '@nStep               INT,             ' +
               '@cStorerKey          NVARCHAR( 15),   ' +
               '@cID                 NVARCHAR( 18),   ' +
               '@cJobKey             NVARCHAR( 10),   ' +
               '@cWorkOrderKey       NVARCHAR( 10),   ' +
               '@cSKU                NVARCHAR( 20)    OUTPUT,     ' +
               '@cLOT                NVARCHAR( 10)    OUTPUT,     ' +
               '@nQtyRemaining       INT              OUTPUT,     ' +
               '@nTtlCount           INT              OUTPUT,     ' +
               '@cLottable01         NVARCHAR( 18)    OUTPUT,     ' +
               '@cLottable02         NVARCHAR( 18) 	OUTPUT,     ' +
               '@cLottable03         NVARCHAR( 18)    OUTPUT,     ' +
		         '@dLottable04         DATETIME         OUTPUT,     ' +
               '@dLottable05         DATETIME         OUTPUT,     ' +
               '@cLottable06         NVARCHAR( 30)    OUTPUT,     ' +
               '@cLottable07         NVARCHAR( 30)    OUTPUT,     ' +
               '@cLottable08         NVARCHAR( 30)    OUTPUT,     ' +
               '@cLottable09         NVARCHAR( 30) 	OUTPUT,     ' +
               '@cLottable10         NVARCHAR( 30)    OUTPUT,     ' +
               '@cLottable11         NVARCHAR( 30)    OUTPUT,     ' +
               '@cLottable12         NVARCHAR( 30)    OUTPUT,     ' +
               '@dLottable13         DATETIME         OUTPUT,     ' +
               '@dLottable14         DATETIME         OUTPUT,     ' +
               '@dLottable15         DATETIME         OUTPUT,     ' +
               '@nErrNo              INT              OUTPUT,     ' +
               '@cErrMsg             NVARCHAR( 20)    OUTPUT      ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cID, @cJobKey, @cWorkOrderKey, 
               @cSKU              OUTPUT, @cLOT                 OUTPUT, @nQtyRemaining        OUTPUT, 
               @nTtlCount         OUTPUT, @cLottable01          OUTPUT, @cLottable02          OUTPUT, 
               @cLottable03       OUTPUT, @dLottable04          OUTPUT, @dLottable05          OUTPUT, 
               @cLottable06       OUTPUT, @cLottable07          OUTPUT, @cLottable08          OUTPUT, 
               @cLottable09       OUTPUT, @cLottable10          OUTPUT, @cLottable11          OUTPUT, 
               @cLottable12       OUTPUT, @dLottable13          OUTPUT, @dLottable14          OUTPUT, 
               @dLottable15       OUTPUT, @nErrNo               OUTPUT, @cErrMsg              OUTPUT  

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END
      ELSE
      BEGIN
         EXEC [RDT].[rdt_VAP_Palletize_GetNextTask]
            @nMobile             = @nMobile,                   
            @nFunc               = @nFunc,   
            @cLangCode           = @cLangCode,
            @nInputKey           = @nInputKey,                 
            @nStep               = @nStep,                     
            @cStorerKey          = @cStorerKey,
            @cID                 = @cToID,
            @cJobKey             = @cJobKey,
            @cWorkOrderKey       = @cWorkOrderKey,
            @cSKU                = @cSKU           OUTPUT, 
            @cLOT                = @cLOT           OUTPUT, 
            @nQtyRemaining       = @nQtyRemaining  OUTPUT, 
            @nTtlCount           = @nTtlCount      OUTPUT, 
            @cLottable01         = @cLottable01    OUTPUT, 
            @cLottable02         = @cLottable02 	OUTPUT, 
            @cLottable03         = @cLottable03    OUTPUT, 
		      @dLottable04         = @dLottable04    OUTPUT, 
            @dLottable05         = @dLottable05    OUTPUT, 
            @cLottable06         = @cLottable06    OUTPUT, 
            @cLottable07         = @cLottable07    OUTPUT, 
            @cLottable08         = @cLottable08    OUTPUT, 
            @cLottable09         = @cLottable09 	OUTPUT, 
            @cLottable10         = @cLottable10    OUTPUT, 
            @cLottable11         = @cLottable11    OUTPUT, 
            @cLottable12         = @cLottable12    OUTPUT, 
            @dLottable13         = @dLottable13    OUTPUT, 
            @dLottable14         = @dLottable14    OUTPUT, 
            @dLottable15         = @dLottable15    OUTPUT, 
            @nErrNo              = @nErrNo         OUTPUT, 
            @cErrMsg             = @cErrMsg        OUTPUT    

         IF @nErrNo <> 0
            GOTO Step_1_Fail
      END
   	   
	   IF ISNULL( @cSKU, '') = ''
	   BEGIN
	      SET @nErrNo = 58610
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task!
         GOTO Step_1_Fail
	   END 

      SET @nRecCount = 1

      SELECT @cOutputSKU = WRO.SKU,
             @cOutputUOM = WRO.UOM,
             @cPackKey = WRO.PackKey,
             @nQtyRemaining = ISNULL( SUM ( WRO.Qty - WRO.QtyCompleted), 0)
      FROM dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK)
      WHERE WRO.WorkOrderKey IN 
         ( SELECT DISTINCT WorkOrderKey FROM dbo.WorkOrder_Uncasing WITH (NOLOCK) 
           WHERE JobKey = @cJobKey
           AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END)
      GROUP BY WRO.SKU, WRO.UOM, WRO.PackKey

      SELECT
            @cMUOM_Desc = Pack.PackUOM3,
            @cPUOM_Desc =
               CASE @cPUOM
                  WHEN '2' THEN Pack.PackUOM1 -- Case
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
               END,
            @nPUOM_Div = CAST( IsNULL( CASE
            WHEN PACKUOM1 = @cOutputUOM THEN CaseCNT 
            WHEN PACKUOM2 = @cOutputUOM THEN InnerPack 
            WHEN PACKUOM3 = @cOutputUOM THEN QTY 
            WHEN PACKUOM4 = @cOutputUOM THEN Pallet 
            WHEN PACKUOM8 = @cOutputUOM THEN OtherUnit1 
            WHEN PACKUOM9 = @cOutputUOM THEN OtherUnit2
            ELSE 0 END, 1) AS INT) 
      FROM dbo.Pack WITH (NOLOCK) 
      WHERE PackKey = @cPackKey 

      SELECT @nTtl_PalletizedQty = ISNULL( SUM( QTY), 0)
      FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
      WHERE JobKey = @cJobKey
      AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END
      AND   [Status] < '9'

      SET @cLottable04 = rdt.rdtFormatDate( @dLottable04)

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = ( @nQtyRemaining - @nTtl_PalletizedQty)
         SET @cOutField10 = '1:1' + SPACE( 10) + rdt.rdtRightAlign( CAST( @cMUOM_Desc AS NVARCHAR( 5)), 5)
      END
      ELSE
      BEGIN
         SET @nPQTY = ( @nQtyRemaining - @nTtl_PalletizedQty) / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY = ( @nQtyRemaining - @nTtl_PalletizedQty) % @nPUOM_Div -- Calc the remaining in master unit
         SET @cOutField10 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NVARCHAR( 5)) END + '    ' + 
                            rdt.rdtRightAlign( CAST( @cPUOM_Desc AS NVARCHAR( 5)), 5) + ' ' + rdt.rdtRightAlign( CAST( @cMUOM_Desc AS NVARCHAR( 5)), 5)
      END

		-- Prepare Next Screen Variable
      SET @cOutField01 = @cJobKey
      SET @cOutField02 = CASE WHEN @nMulti = 1 THEN 'MULTI' ELSE @cWorkOrderKey END
      SET @cOutField03 = @cToID
      SET @cOutField04 = @cLottable01
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = @cLottable04
      SET @cOutField08 = @cLottable07
      SET @cOutField09 = @cLottable08
      SET @cOutField11 = CASE WHEN @nPQTY = 0 THEN '' ELSE rdt.rdtRightAlign( CAST( @nPQTY AS NVARCHAR( 5)), 5) END -- PQTY
      SET @cOutField12 = rdt.rdtRightAlign( CAST( @nMQTY AS NVARCHAR( 5)), 5) -- MQTY
      SET @cOutField13 = ''
      SET @cOutField14 = RTRIM( CAST( @nRecCount AS NVARCHAR( 2))) + '/' + CAST( @nTtlCount AS NVARCHAR( 2))

      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''
         
		-- GOTO Next Screen
		SET @nScn = @nScn + 1
	   SET @nStep = @nStep + 1
	    
	   EXEC rdt.rdtSetFocusField @nMobile, 9 
	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
      SET @cExtendedDeleteSP = rdt.RDTGetConfig( @nFunc, 'ExtendedDeleteSP', @cStorerKey)
      IF @cExtendedDeleteSP NOT IN ('0', '') AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedDeleteSP AND type = 'P')
      BEGIN
          SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedDeleteSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cToID, @cJobKey, @cWorkOrderKey, ' +
            ' @cSKU, @nQtyToComplete, @cPrintLabel, @cEndPallet, @dStartDate, @cType, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile                   INT,           ' +
            '@nFunc                     INT,           ' +
            '@cLangCode                 NVARCHAR( 3),  ' +
            '@nStep                     INT,           ' +
            '@nInputKey                 INT,           ' +
            '@cStorerkey                NVARCHAR( 15), ' +
            '@cToID                     NVARCHAR( 18), ' +
            '@cJobKey                   NVARCHAR( 10), ' +
            '@cWorkOrderKey             NVARCHAR( 10), ' +
            '@cSKU                      NVARCHAR( 20), ' +
            '@nQtyToComplete            INT,           ' +
            '@cPrintLabel               NVARCHAR( 10), ' +
            '@cEndPallet                NVARCHAR( 10), ' +
            '@dStartDate                DATETIME,      ' +
            '@cType                     NVARCHAR( 1),  ' + 
            '@nErrNo                    INT           OUTPUT,  ' +
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cToID, @cJobKey, @cWorkOrderKey, 
               @cSKU, @nQtyToComplete, @cPrintLabel, @cEndPallet, @dStartDate, @cType, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
            GOTO Quit
         END
      END

      -- Clear variables
      SET @cID = ''  
	   SET @cToID = ''
      SET @cJobKey = ''
      SET @cWorkOrderKey = ''

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
   END
END 
GOTO QUIT

/********************************************************************************
Step 2. Scn = 4431. 
   LOTTABLE01-07  (Field01, display)
   QTY            (Field09, display)
   OPTION         (Field10, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cOption = ISNULL(RTRIM(@cInField13),'')

		IF @cOption = ''
		BEGIN
         SET @cVAP_PalletizeGetTask = ''
         SET @cVAP_PalletizeGetTask = rdt.RDTGetConfig( @nFunc, 'VAPPalletizeGetTaskSP', @cStorerKey)

         IF @cVAP_PalletizeGetTask NOT IN ('', '0')
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cVAP_PalletizeGetTask AND type = 'P')
            BEGIN
               SET @nErrNo = 0
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cVAP_PalletizeGetTask) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cID, @cJobKey, @cWorkOrderKey, ' + 
                  ' @cSKU              OUTPUT, @cLOT                 OUTPUT, @nQtyRemaining        OUTPUT, ' + 
                  ' @nTtlCount         OUTPUT, @cLottable01          OUTPUT, @cLottable02          OUTPUT, ' +
                  ' @cLottable03       OUTPUT, @dLottable04          OUTPUT, @dLottable05          OUTPUT, ' + 
                  ' @cLottable06       OUTPUT, @cLottable07          OUTPUT, @cLottable08          OUTPUT, ' + 
                  ' @cLottable09       OUTPUT, @cLottable10          OUTPUT, @cLottable11          OUTPUT, ' + 
                  ' @cLottable12       OUTPUT, @dLottable13          OUTPUT, @dLottable14          OUTPUT, ' + 
                  ' @dLottable15       OUTPUT, @nErrNo               OUTPUT, @cErrMsg              OUTPUT  ' 

               SET @cSQLParam =
                  '@nMobile             INT,             ' +
                  '@nFunc               INT,             ' +
                  '@cLangCode           NVARCHAR( 3),    ' +
                  '@nInputKey           INT,             ' +
                  '@nStep               INT,             ' +
                  '@cStorerKey          NVARCHAR( 15),   ' +
                  '@cID                 NVARCHAR( 18),   ' +
                  '@cJobKey             NVARCHAR( 10),   ' +
                  '@cWorkOrderKey       NVARCHAR( 10),   ' +
                  '@cSKU                NVARCHAR( 20)    OUTPUT,     ' +
                  '@cLOT                NVARCHAR( 10)    OUTPUT,     ' +
                  '@nQtyRemaining       INT              OUTPUT,     ' +
                  '@nTtlCount           INT              OUTPUT,     ' +
                  '@cLottable01         NVARCHAR( 18)    OUTPUT,     ' +
                  '@cLottable02         NVARCHAR( 18) 	OUTPUT,     ' +
                  '@cLottable03         NVARCHAR( 18)    OUTPUT,     ' +
		            '@dLottable04         DATETIME         OUTPUT,     ' +
                  '@dLottable05         DATETIME         OUTPUT,     ' +
                  '@cLottable06         NVARCHAR( 30)    OUTPUT,     ' +
                  '@cLottable07         NVARCHAR( 30)    OUTPUT,     ' +
                  '@cLottable08         NVARCHAR( 30)    OUTPUT,     ' +
                  '@cLottable09         NVARCHAR( 30) 	OUTPUT,     ' +
                  '@cLottable10         NVARCHAR( 30)    OUTPUT,     ' +
                  '@cLottable11         NVARCHAR( 30)    OUTPUT,     ' +
                  '@cLottable12         NVARCHAR( 30)    OUTPUT,     ' +
                  '@dLottable13         DATETIME         OUTPUT,     ' +
                  '@dLottable14         DATETIME         OUTPUT,     ' +
                  '@dLottable15         DATETIME         OUTPUT,     ' +
                  '@nErrNo              INT              OUTPUT,     ' +
                  '@cErrMsg             NVARCHAR( 20)    OUTPUT      ' 

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cID, @cJobKey, @cWorkOrderKey, 
                  @cSKU              OUTPUT, @cLOT                 OUTPUT, @nQtyRemaining        OUTPUT, 
                  @nTtlCount         OUTPUT, @cLottable01          OUTPUT, @cLottable02          OUTPUT, 
                  @cLottable03       OUTPUT, @dLottable04          OUTPUT, @dLottable05          OUTPUT, 
                  @cLottable06       OUTPUT, @cLottable07          OUTPUT, @cLottable08          OUTPUT, 
                  @cLottable09       OUTPUT, @cLottable10          OUTPUT, @cLottable11          OUTPUT, 
                  @cLottable12       OUTPUT, @dLottable13          OUTPUT, @dLottable14          OUTPUT, 
                  @dLottable15       OUTPUT, @nErrNo               OUTPUT, @cErrMsg              OUTPUT  

               IF @nErrNo <> 0
                  GOTO Step_1_Fail
            END
         END
         ELSE
         BEGIN
            EXEC [RDT].[rdt_VAP_Palletize_GetNextTask]
               @nMobile             = @nMobile,                   
               @nFunc               = @nFunc,   
               @cLangCode           = @cLangCode,
               @nInputKey           = @nInputKey,                 
               @nStep               = @nStep,                     
               @cStorerKey          = @cStorerKey,
               @cID                 = @cToID,
               @cJobKey             = @cJobKey,
               @cWorkOrderKey       = @cWorkOrderKey,
               @cSKU                = @cSKU           OUTPUT, 
               @cLOT                = @cLOT           OUTPUT, 
               @nQtyRemaining       = @nQtyRemaining  OUTPUT, 
               @nTtlCount           = @nTtlCount      OUTPUT, 
               @cLottable01         = @cLottable01    OUTPUT, 
               @cLottable02         = @cLottable02 	OUTPUT, 
               @cLottable03         = @cLottable03    OUTPUT, 
		         @dLottable04         = @dLottable04    OUTPUT, 
               @dLottable05         = @dLottable05    OUTPUT, 
               @cLottable06         = @cLottable06    OUTPUT, 
               @cLottable07         = @cLottable07    OUTPUT, 
               @cLottable08         = @cLottable08    OUTPUT, 
               @cLottable09         = @cLottable09 	OUTPUT, 
               @cLottable10         = @cLottable10    OUTPUT, 
               @cLottable11         = @cLottable11    OUTPUT, 
               @cLottable12         = @cLottable12    OUTPUT, 
               @dLottable13         = @dLottable13    OUTPUT, 
               @dLottable14         = @dLottable14    OUTPUT, 
               @dLottable15         = @dLottable15    OUTPUT, 
               @nErrNo              = @nErrNo         OUTPUT, 
               @cErrMsg             = @cErrMsg        OUTPUT    

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END

	      IF ISNULL( @cSKU, '') = ''
         BEGIN
		      SET @nErrNo = 58761
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
            GOTO Step_2_Fail
         END

         SELECT @nTtl_PalletizedQty = ISNULL( SUM( QTY), 0)
         FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
         WHERE JobKey = @cJobKey
         AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END
         AND   [Status] < '9'

         SET @cLottable04 = rdt.rdtFormatDate( @dLottable04)
         SET @nRecCount = @nRecCount + 1

		   -- Prepare Next Screen Variable
         SET @cOutField01 = @cID
         SET @cOutField02 = CASE WHEN @nMulti = 1 THEN 'MULTI' ELSE @cWorkOrderKey END
         SET @cOutField03 = @cToID
         SET @cOutField04 = @cLottable01
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
         SET @cOutField07 = @cLottable04
         SET @cOutField08 = @cLottable07
         SET @cOutField09 = @cLottable08
         SET @cOutField10 = ( @nQtyRemaining - @nTtl_PalletizedQty)/@nPUOM_Div
         SET @cOutField11 = ''
         SET @cOutField12 = RTRIM( CAST( @nRecCount AS NVARCHAR( 2))) + '/' + CAST( @nTtlCount AS NVARCHAR( 2))

         GOTO Quit
	   END

      IF @cOption NOT IN ('Y', 'N')
		BEGIN
		   SET @nErrNo = 58762
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Step_2_Fail
	   END

      IF @cOption = 'Y'
      BEGIN
         SELECT @nTtl_PalletizedQty = ISNULL( SUM( QTY), 0)
         FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
         WHERE JobKey = @cJobKey
         AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END
         AND   [Status] < '9'

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = ( @nQtyRemaining - @nTtl_PalletizedQty)
            SET @cFieldAttr07 = 'O' -- @nPQTY
            SET @cFieldAttr09 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = ( @nQtyRemaining - @nTtl_PalletizedQty) / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY = ( @nQtyRemaining - @nTtl_PalletizedQty) % @nPUOM_Div -- Calc the remaining in master unit
            SET @cFieldAttr07 = '' -- @nPQTY
            SET @cFieldAttr09 = '' -- @nPQTY
         END

         SET @cLottable04 = rdt.rdtFormatDate( @dLottable04)

         SET @cOutField01 = @cJobKey
         SET @cOutField02 = CASE WHEN @nMulti = 1 THEN 'MULTI' ELSE @cWorkOrderKey END
         SET @cOutField03 = @cToID
         SET @cOutField04 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
         SET @cOutField05 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
         SET @cOutField06 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
         SET @cOutField07 = CASE WHEN @nPQTY = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END -- PQTY
         SET @cOutField08 = CASE WHEN @nMQTY = 0 THEN '0' ELSE rdt.rdtRightAlign( CAST( @nMQTY AS NVARCHAR( 5)), 5) END -- MQTY
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField12 = ''

	      EXEC rdt.rdtSetFocusField @nMobile, 4

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
      -- Initialize Variable 
      SET @cID = ''  

      -- Temp only for easy testing
      IF @cUserName = 'JAMES'
      BEGIN
         -- Init screen
         SET @cOutField01 = @cToID
         SET @cOutField02 = @cJobKey
         SET @cOutField03 = @cWorkOrderKey
         SET @cOutField04 = @cStartDate 
      END
      ELSE
      BEGIN
         -- Init screen
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = @cStartDate 
      END

	   EXEC rdt.rdtSetFocusField @nMobile, 1

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
	GOTO Quit

   STEP_2_FAIL:
   BEGIN
	   -- Prepare Next Screen Variable
      SET @cOutField11 = ''
   END
END 
GOTO QUIT

/********************************************************************************
Step 3. Scn = 3272. 
   PALLET ID   (Field01, input)
   SSCC        (Field02, input)
   QTY         (Field03, input)   
   START TIME  (Field04, display)   
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- QtyToComplete
      SET @cPQty = @cInField09
      SET @cMQty = @cInField10
	   SET @cPrintLabel = @cInField11
	   SET @cEndPallet = @cInField12

      -- Screen mapping
      SET @cPQty = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END
      SET @cMQty = CASE WHEN @cFieldAttr10 = 'O' THEN @cOutField10 ELSE @cInField10 END


      SELECT @nTtl_PalletizedQty = ISNULL( SUM( QTY), 0)
      FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
      WHERE JobKey = @cJobKey
      AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END
      AND   [Status] < '9'

      IF @cPQty <> '' AND rdt.rdtIsValidQTY( @cPQty, 1) = 0
		BEGIN
         IF @cEndPallet <> 'Y' 
         BEGIN
		      SET @nErrNo = 58763
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
            SET @cOutField09 = ''
            SET @cOutField10 = ''
            SET @cOutField11 = @cPrintLabel
            SET @cOutField12 = @cEndPallet
            EXEC rdt.rdtSetFocusField @nMobile, 9
            GOTO Quit
         END
      END

      IF @cMQty <> '' AND rdt.rdtIsValidQTY( @cMQty, 1) = 0
		BEGIN
         IF @cEndPallet <> 'Y' 
         BEGIN
		      SET @nErrNo = 58775
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
            SET @cOutField09 = ''
            SET @cOutField10 = ''
            SET @cOutField11 = @cPrintLabel
            SET @cOutField12 = @cEndPallet
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO Quit
         END
      END

      SET @nMQty = CAST( @cMQty AS INT)

      SELECT @cSKU = WRO.SKU,
             @nWorkOutPutQty = ISNULL( SUM ( WRO.Qty - WRO.QtyCompleted), 0)
      FROM dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK)
      WHERE WRO.WorkOrderKey IN 
         ( SELECT DISTINCT WorkOrderKey FROM dbo.WorkOrder_Uncasing WITH (NOLOCK) 
           WHERE JobKey = @cJobKey
           AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END)
      GROUP BY WRO.SKU, WRO.UOM, WRO.PackKey

      -- Calc total QTY in master UOM
      SET @nQtyToComplete = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQty, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQtyToComplete = @nQtyToComplete + @nMQty
      insert into traceinfo (tracename, timein, col1, col2, COL3, STEP1, STEP2, STEP3) values 
      ('1153', getdate(), @cPQty, @nMQty, @nQtyToComplete, @cStorerKey, @cSKU, @cPUOM)
      --SET @nQtyToComplete = ISNULL( CAST ( @cQtyToComplete AS INT), 0) * @nPUOM_Div

      IF ( @nQtyToComplete + @nTtl_PalletizedQty) > @nWorkOutPutQty
		BEGIN
		   SET @nErrNo = 58764
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qty > Expected
         SET @cOutField09 = ''         
         SET @cOutField10 = ''
         SET @cOutField11 = @cPrintLabel
         SET @cOutField12 = @cEndPallet
         EXEC rdt.rdtSetFocusField @nMobile, 10
         GOTO Quit
      END

      IF ISNULL( @cPrintLabel, '') <> '' AND @cPrintLabel NOT IN ('Y', 'N')
		BEGIN
		   SET @nErrNo = 58765
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid print opt
         SET @cOutField09 = @cPQty         
         SET @cOutField10 = @cMQty
         SET @cOutField11 = ''
         SET @cOutField12 = @cEndPallet
         EXEC rdt.rdtSetFocusField @nMobile, 10
         GOTO Quit
      END

      IF ISNULL( @cEndPallet, '') <> '' AND @cEndPallet NOT IN ('Y', 'N')
		BEGIN
		   SET @nErrNo = 58766
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid print opt
         SET @cOutField09 = @cPQty         
         SET @cOutField10 = @cMQty
         SET @cOutField11 = @cPrintLabel
         SET @cOutField12 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 10
         GOTO Quit
      END

      IF ISNULL( @cPrintLabel, '') = 'Y'
      BEGIN
         SET @cReportType = 'FGPLTLABEL'
         SET @cPrintJobName = 'PRINT_FG_PALLETLABEL'
   
         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                  @cTargetDB = ISNULL(RTRIM(TargetDB), '')
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReportType = @cReportType

         SELECT   
            @cLabelPrinter = Printer,   
            @cPaperPrinter = Printer_Paper  
         FROM rdt.rdtMobRec WITH (NOLOCK)  
         WHERE Mobile = @nMobile  

         IF ISNULL(@cLabelPrinter, '') = ''
         BEGIN
            SET @nErrNo = 58770
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLblPrinter
            SET @cOutField09 = @cPQty         
            SET @cOutField10 = @cMQty
            SET @cOutField11 = ''
            SET @cOutField12 = @cEndPallet
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Quit
         END
            
         IF ISNULL(@cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 58771
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            SET @cOutField09 = @cPQty         
            SET @cOutField10 = @cMQty
            SET @cOutField11 = ''
            SET @cOutField12 = @cEndPallet
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Quit
         END

         IF ISNULL(@cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 58772
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            SET @cOutField09 = @cPQty         
            SET @cOutField10 = @cMQty
            SET @cOutField11 = ''
            SET @cOutField12 = @cEndPallet
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Quit
         END
      END

      SELECT @cSKU = SKU
      FROM dbo.WorkOrderRequestOutputs WITH (NOLOCK)
      WHERE WorkOrderKey = @cWorkOrderKey

      SELECT @cSKU = WRO.SKU
      FROM dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK)
      WHERE WRO.WorkOrderKey IN 
         ( SELECT DISTINCT WorkOrderKey FROM dbo.WorkOrder_Uncasing WITH (NOLOCK) 
           WHERE JobKey = @cJobKey
           AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END)

      SELECT @cLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      IF rdt.rdtIsValidDate(@cLottable04) = 1 --valid date
         SET @dLottable04 = CAST( @cLottable04 AS DATETIME)

      IF @nQtyToComplete > 0
      BEGIN
         SET @nErrNo = 0
         SET @cVAPPalletizeCfmSP = rdt.RDTGetConfig( @nFunc, 'VAPPalletizeCfm_SP', @cStorerKey)
         IF @cVAPPalletizeCfmSP NOT IN ('0', '') AND 
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cVAPPalletizeCfmSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cVAPPalletizeCfmSP) +
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, ' + 
               ' @cStorerkey, @cToID, @cJobKey, @cWorkOrderKey, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQtyToComplete, @cPrintLabel, @cEndPallet, @dStartDate, @cType, ' +
               ' @nErrNo	OUTPUT, @cErrMsg	OUTPUT '

            SET @cSQLParam =
               '@nMobile       	INT, ' + 
               '@nFunc         	INT, ' + 
               '@nStep         	INT, ' + 
               '@nInputKey     	INT, ' + 
               '@cLangCode     	NVARCHAR( 3),  ' +
               '@cStorerkey    	NVARCHAR( 15), ' + 
               '@cToID         	NVARCHAR( 18), ' +  
               '@cJobKey       	NVARCHAR( 10), ' + 
               '@cWorkOrderKey 	NVARCHAR( 10), ' + 
               '@cSKU          	NVARCHAR( 20), ' + 
               '@cLottable01   	NVARCHAR( 18), ' + 
               '@cLottable02   	NVARCHAR( 18), ' + 
               '@cLottable03   	NVARCHAR( 18), ' + 
               '@dLottable04   	DATETIME, '      + 
               '@dLottable05   	DATETIME, '      + 
               '@cLottable06   	NVARCHAR( 30), ' +
               '@cLottable07   	NVARCHAR( 30), ' +
               '@cLottable08   	NVARCHAR( 30), ' +
               '@cLottable09   	NVARCHAR( 30), ' +
               '@cLottable10   	NVARCHAR( 30), ' +
               '@cLottable11   	NVARCHAR( 30), ' +
               '@cLottable12   	NVARCHAR( 30), ' +
               '@dLottable13   	DATETIME, '      + 
               '@dLottable14   	DATETIME, '      + 
               '@dLottable15   	DATETIME, '      + 
               '@nQtyToComplete	INT, '           +    
               '@cPrintLabel   	NVARCHAR( 10), ' +  
               '@cEndPallet    	NVARCHAR( 10), ' +  
               '@dStartDate    	DATETIME, '      +  
               '@cType         	NVARCHAR( 1), '  + 
               '@nErrNo        	INT      		OUTPUT, ' + 
               '@cErrMsg       	NVARCHAR( 20)  OUTPUT  ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, 
                @cStorerkey, @cToID, @cJobKey, @cWorkOrderKey, @cSKU,
                @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                @nQtyToComplete, @cPrintLabel, @cEndPallet, @dStartDate, 'I',
                @nErrNo	OUTPUT, @cErrMsg	OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            EXEC rdt.rdt_VAP_Palletize_Confirm 
               @nMobile       = @nMobile,
               @nFunc         = @nFunc,
               @nStep         = @nStep,
               @nInputKey     = @nInputKey,
               @cLangCode     = @cLangCode,
               @cStorerkey    = @cStorerkey,
               @cToID         = @cToID, 
               @cJobKey       = @cJobKey,
               @cWorkOrderKey = @cWorkOrderKey,
               @cSKU          = @cSKU,
               @cLottable01   = @cLottable01,
               @cLottable02   = @cLottable02,
               @cLottable03   = @cLottable03,
               @dLottable04   = @dLottable04,
               @dLottable05   = NULL,
               @cLottable06   = '',
               @cLottable07   = @cWorkOrderUdf04,
               @cLottable08   = @cWorkOrderUdf01,
               @cLottable09   = '',
               @cLottable10   = '',
               @cLottable11   = '',
               @cLottable12   = '',
               @dLottable13   = NULL,
               @dLottable14   = NULL,
               @dLottable15   = NULL,
               @nQtyToComplete= @nQtyToComplete,   
               @cPrintLabel   = @cPrintLabel, 
               @cEndPallet    = @cEndPallet, 
               @dStartDate    = NULL, 
               @cType         = 'I',
               @nErrNo        = @nErrNo      OUTPUT, 
               @cErrMsg       = @cErrMsg     OUTPUT  

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP NOT IN ('0', '')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cToID, @cJobKey, @cWorkOrderKey, ' +
            ' @cSKU, @nQtyToComplete, @cPrintLabel, @cEndPallet, @dStartDate, @cType, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile                   INT,           ' +
            '@nFunc                     INT,           ' +
            '@cLangCode                 NVARCHAR( 3),  ' +
            '@nStep                     INT,           ' +
            '@nInputKey                 INT,           ' +
            '@cStorerkey                NVARCHAR( 15), ' +
            '@cToID                     NVARCHAR( 18), ' +
            '@cJobKey                   NVARCHAR( 10), ' +
            '@cWorkOrderKey             NVARCHAR( 10), ' +
            '@cSKU                      NVARCHAR( 20), ' +
            '@nQtyToComplete            INT,           ' +
            '@cPrintLabel               NVARCHAR( 10), ' +
            '@cEndPallet                NVARCHAR( 10), ' +
            '@dStartDate                DATETIME,      ' +
            '@cType                     NVARCHAR( 1),  ' + 
            '@nErrNo                    INT           OUTPUT,  ' +
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cToID, @cJobKey, @cWorkOrderKey, 
               @cSKU, @nQtyToComplete, @cPrintLabel, @cEndPallet, @dStartDate, @cType, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EXT UPD FAIL'
            GOTO Quit
         END
      END

      SELECT @nTtl_PalletizedQty = ISNULL( SUM( QTY), 0)
      FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
      WHERE JobKey = @cJobKey
      AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END
      AND   [Status] < '9'

      IF @cEndPallet = 'Y' OR ( @nTtl_PalletizedQty = @nWorkOutPutQty)
      BEGIN
         SELECT TOP 1 
            @cLottable01 = Lottable01, 
            @cLottable02 = Lottable02, 
            @cLottable03 = Lottable03, 
            @cLottable04 = Lottable04, 
            @cLottable07 = Lottable07, 
            @cLottable08 = Lottable08
         FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
         WHERE ID = @cToID
         AND   JobKey = @cJobKey
         AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END
         AND   [Status] = '3'

         SELECT @cWorkOrderUdf01 = Udf1,
                @cWorkOrderUdf04 = Udf4
         FROM dbo.WorkOrderRequest WITH (NOLOCK) 
         WHERE WorkOrderKey IN 
         ( SELECT DISTINCT WorkOrderKey FROM dbo.WorkOrder_Uncasing WITH (NOLOCK) 
           WHERE JobKey = @cJobKey
           AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END)

         SET @cLottable04 = rdt.rdtFormatDate( @dLottable04)

         -- Enable all the field
         SET @cFieldAttr01 = ''
         SET @cFieldAttr02 = ''
         SET @cFieldAttr03 = ''
         SET @cFieldAttr04 = ''
         SET @cFieldAttr05 = ''
         SET @cFieldAttr06 = ''
         SET @cFieldAttr07 = ''
         SET @cFieldAttr08 = ''

		   --Prepare Next Screen Variable
         SET @cOutField01 = @cToID
         SET @cOutField02 = @cLottable01
         SET @cOutField03 = @cLottable02
         SET @cOutField04 = @cLottable03
         SET @cOutField05 = @cLottable04
         SET @cOutField06 = @cWorkOrderUdf04
         SET @cOutField07 = @cWorkOrderUdf01
         SET @cOutField08 = CONVERT(NVARCHAR, GETDATE(), 101) + ' ' + 
		                        CONVERT(NVARCHAR, DATEPART(hh, GETDATE())) + ':' + 
		                        RIGHT('0' + CONVERT(NVARCHAR, DATEPART(mi, GETDATE())), 2) 
      
         EXEC rdt.rdtSetFocusField @nMobile, 2

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END
      ELSE
      BEGIN
         SELECT @cWorkOrderUdf01 = Udf1,
                @cWorkOrderUdf04 = Udf4
         FROM dbo.WorkOrderRequest WITH (NOLOCK) 
         WHERE WorkOrderKey IN 
         ( SELECT DISTINCT WorkOrderKey FROM dbo.WorkOrder_Uncasing WITH (NOLOCK) 
           WHERE JobKey = @cJobKey
           AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END)

         SET @nTtlCount = 0

         SET @cVAP_PalletizeGetTask = ''
         SET @cVAP_PalletizeGetTask = rdt.RDTGetConfig( @nFunc, 'VAPPalletizeGetTaskSP', @cStorerKey)

         IF @cVAP_PalletizeGetTask NOT IN ('', '0')
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cVAP_PalletizeGetTask AND type = 'P')
            BEGIN
               SET @nErrNo = 0
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cVAP_PalletizeGetTask) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cID, @cJobKey, @cWorkOrderKey, ' + 
                  ' @cSKU              OUTPUT, @cLOT                 OUTPUT, @nQtyRemaining        OUTPUT, ' + 
                  ' @nTtlCount         OUTPUT, @cLottable01          OUTPUT, @cLottable02          OUTPUT, ' +
                  ' @cLottable03       OUTPUT, @dLottable04          OUTPUT, @dLottable05          OUTPUT, ' + 
                  ' @cLottable06       OUTPUT, @cLottable07          OUTPUT, @cLottable08          OUTPUT, ' + 
                  ' @cLottable09       OUTPUT, @cLottable10          OUTPUT, @cLottable11          OUTPUT, ' + 
                  ' @cLottable12       OUTPUT, @dLottable13          OUTPUT, @dLottable14          OUTPUT, ' + 
                  ' @dLottable15       OUTPUT, @nErrNo               OUTPUT, @cErrMsg              OUTPUT  ' 

               SET @cSQLParam =
                  '@nMobile             INT,             ' +
                  '@nFunc               INT,             ' +
                  '@cLangCode           NVARCHAR( 3),    ' +
                  '@nInputKey           INT,             ' +
                  '@nStep               INT,             ' +
                  '@cStorerKey          NVARCHAR( 15),   ' +
                  '@cID                 NVARCHAR( 18),   ' +
                  '@cJobKey             NVARCHAR( 10),   ' +
                  '@cWorkOrderKey       NVARCHAR( 10),   ' +
                  '@cSKU                NVARCHAR( 20)    OUTPUT,     ' +
                  '@cLOT                NVARCHAR( 10)    OUTPUT,     ' +
                  '@nQtyRemaining       INT              OUTPUT,     ' +
                  '@nTtlCount           INT              OUTPUT,     ' +
                  '@cLottable01         NVARCHAR( 18)    OUTPUT,     ' +
                  '@cLottable02         NVARCHAR( 18) 	OUTPUT,     ' +
                  '@cLottable03         NVARCHAR( 18)    OUTPUT,     ' +
		            '@dLottable04         DATETIME         OUTPUT,     ' +
                  '@dLottable05         DATETIME         OUTPUT,     ' +
                  '@cLottable06         NVARCHAR( 30)    OUTPUT,     ' +
                  '@cLottable07         NVARCHAR( 30)    OUTPUT,     ' +
                  '@cLottable08         NVARCHAR( 30)    OUTPUT,     ' +
                  '@cLottable09         NVARCHAR( 30) 	OUTPUT,     ' +
                  '@cLottable10         NVARCHAR( 30)    OUTPUT,     ' +
                  '@cLottable11         NVARCHAR( 30)    OUTPUT,     ' +
                  '@cLottable12         NVARCHAR( 30)    OUTPUT,     ' +
                  '@dLottable13         DATETIME         OUTPUT,     ' +
                  '@dLottable14         DATETIME         OUTPUT,     ' +
                  '@dLottable15         DATETIME         OUTPUT,     ' +
                  '@nErrNo              INT              OUTPUT,     ' +
                  '@cErrMsg             NVARCHAR( 20)    OUTPUT      ' 

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cID, @cJobKey, @cWorkOrderKey, 
                  @cSKU              OUTPUT, @cLOT                 OUTPUT, @nQtyRemaining        OUTPUT, 
                  @nTtlCount         OUTPUT, @cLottable01          OUTPUT, @cLottable02          OUTPUT, 
                  @cLottable03       OUTPUT, @dLottable04          OUTPUT, @dLottable05          OUTPUT, 
                  @cLottable06       OUTPUT, @cLottable07          OUTPUT, @cLottable08          OUTPUT, 
                  @cLottable09       OUTPUT, @cLottable10          OUTPUT, @cLottable11          OUTPUT, 
                  @cLottable12       OUTPUT, @dLottable13          OUTPUT, @dLottable14          OUTPUT, 
                  @dLottable15       OUTPUT, @nErrNo               OUTPUT, @cErrMsg              OUTPUT  

               IF @nErrNo <> 0
               BEGIN
                  SET @cOutField09 = ''
                  SET @cOutField10 = ''
                  SET @cOutField11 = @cPrintLabel
                  SET @cOutField12 = @cEndPallet
                  EXEC rdt.rdtSetFocusField @nMobile, 9
                  GOTO Quit
               END
            END
         END
         ELSE
         BEGIN
            EXEC [RDT].[rdt_VAP_Palletize_GetNextTask]
               @nMobile             = @nMobile,                   
               @nFunc               = @nFunc,   
               @cLangCode           = @cLangCode,
               @nInputKey           = @nInputKey,                 
               @nStep               = @nStep,                     
               @cStorerKey          = @cStorerKey,
               @cID                 = @cToID,
               @cJobKey             = @cJobKey,
               @cWorkOrderKey       = @cWorkOrderKey,
               @cSKU                = @cSKU           OUTPUT, 
               @cLOT                = @cLOT           OUTPUT, 
               @nQtyRemaining       = @nQtyRemaining  OUTPUT, 
               @nTtlCount           = @nTtlCount      OUTPUT, 
               @cLottable01         = @cLottable01    OUTPUT, 
               @cLottable02         = @cLottable02 	OUTPUT, 
               @cLottable03         = @cLottable03    OUTPUT, 
		         @dLottable04         = @dLottable04    OUTPUT, 
               @dLottable05         = @dLottable05    OUTPUT, 
               @cLottable06         = @cLottable06    OUTPUT, 
               @cLottable07         = @cLottable07    OUTPUT, 
               @cLottable08         = @cLottable08    OUTPUT, 
               @cLottable09         = @cLottable09 	OUTPUT, 
               @cLottable10         = @cLottable10    OUTPUT, 
               @cLottable11         = @cLottable11    OUTPUT, 
               @cLottable12         = @cLottable12    OUTPUT, 
               @dLottable13         = @dLottable13    OUTPUT, 
               @dLottable14         = @dLottable14    OUTPUT, 
               @dLottable15         = @dLottable15    OUTPUT, 
               @nErrNo              = @nErrNo         OUTPUT, 
               @cErrMsg             = @cErrMsg        OUTPUT    

            IF @nErrNo <> 0
            BEGIN
               SET @cOutField09 = ''
               SET @cOutField10 = ''
               SET @cOutField11 = @cPrintLabel
               SET @cOutField12 = @cEndPallet
               EXEC rdt.rdtSetFocusField @nMobile, 9
               GOTO Quit
            END
         END
   	   
	      IF ISNULL( @cSKU, '') = ''
	      BEGIN
	         SET @nErrNo = 58776
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task!
            SET @cOutField09 = ''
            SET @cOutField10 = ''
            SET @cOutField11 = @cPrintLabel
            SET @cOutField12 = @cEndPallet
            EXEC rdt.rdtSetFocusField @nMobile, 9
            GOTO Quit
	      END 

         SET @nRecCount = 1

         SELECT @cOutputSKU = WRO.SKU,
                @cOutputUOM = WRO.UOM,
                @cPackKey = WRO.PackKey,
                @nQtyRemaining = ISNULL( SUM ( WRO.Qty - WRO.QtyCompleted), 0)
         FROM dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK)
         WHERE WRO.WorkOrderKey IN 
            ( SELECT DISTINCT WorkOrderKey FROM dbo.WorkOrder_Uncasing WITH (NOLOCK) 
              WHERE JobKey = @cJobKey
              AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END)
         GROUP BY WRO.SKU, WRO.UOM, WRO.PackKey
      
         SELECT
               @cMUOM_Desc = Pack.PackUOM3,
               @cPUOM_Desc =
                  CASE @cPUOM
                     WHEN '2' THEN Pack.PackUOM1 -- Case
                     WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                     WHEN '6' THEN Pack.PackUOM3 -- Master unit
                     WHEN '1' THEN Pack.PackUOM4 -- Pallet
                     WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                     WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
                  END,
               @nPUOM_Div = CAST( IsNULL( CASE
               WHEN PACKUOM1 = @cOutputUOM THEN CaseCNT 
               WHEN PACKUOM2 = @cOutputUOM THEN InnerPack 
               WHEN PACKUOM3 = @cOutputUOM THEN QTY 
               WHEN PACKUOM4 = @cOutputUOM THEN Pallet 
               WHEN PACKUOM8 = @cOutputUOM THEN OtherUnit1 
               WHEN PACKUOM9 = @cOutputUOM THEN OtherUnit2
               ELSE 0 END, 1) AS INT) 
         FROM dbo.Pack WITH (NOLOCK) 
         WHERE PackKey = @cPackKey 

         SELECT @nTtl_PalletizedQty = ISNULL( SUM( QTY), 0)
         FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
         WHERE JobKey = @cJobKey
         AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END
         AND   [Status] < '9'

         SET @cLottable04 = rdt.rdtFormatDate( @dLottable04)

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = ( @nQtyRemaining - @nTtl_PalletizedQty)
            SET @cOutField10 = '1:1' + SPACE( 10) + rdt.rdtRightAlign( CAST( @cMUOM_Desc AS NVARCHAR( 5)), 5)
         END
         ELSE
         BEGIN
            SET @nPQTY = ( @nQtyRemaining - @nTtl_PalletizedQty) / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY = ( @nQtyRemaining - @nTtl_PalletizedQty) % @nPUOM_Div -- Calc the remaining in master unit
            SET @cOutField10 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NVARCHAR( 5)) END + '    ' + 
                               rdt.rdtRightAlign( CAST( @cPUOM_Desc AS NVARCHAR( 5)), 5) + ' ' + rdt.rdtRightAlign( CAST( @cMUOM_Desc AS NVARCHAR( 5)), 5)
         END

		   -- Prepare Next Screen Variable
         SET @cOutField01 = @cJobKey
         SET @cOutField02 = CASE WHEN @nMulti = 1 THEN 'MULTI' ELSE @cWorkOrderKey END
         SET @cOutField03 = @cToID
         SET @cOutField04 = @cLottable01
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
         SET @cOutField07 = @cLottable04
         SET @cOutField08 = @cLottable07
         SET @cOutField09 = @cLottable08
         SET @cOutField11 = CASE WHEN @nPQTY = 0 THEN '' ELSE rdt.rdtRightAlign( CAST( @nPQTY AS NVARCHAR( 5)), 5) END -- PQTY
         SET @cOutField12 = rdt.rdtRightAlign( CAST( @nMQTY AS NVARCHAR( 5)), 5) -- MQTY
         SET @cOutField13 = ''
         SET @cOutField14 = RTRIM( CAST( @nRecCount AS NVARCHAR( 2))) + '/' + CAST( @nTtlCount AS NVARCHAR( 2))

         SET @cFieldAttr01 = ''
         SET @cFieldAttr02 = ''
         SET @cFieldAttr03 = ''
         SET @cFieldAttr04 = ''
         SET @cFieldAttr05 = ''
         SET @cFieldAttr06 = ''
         SET @cFieldAttr07 = ''
         SET @cFieldAttr08 = ''
         SET @cFieldAttr09 = ''
         SET @cFieldAttr10 = ''
         SET @cFieldAttr11 = ''
         SET @cFieldAttr12 = ''
         SET @cFieldAttr13 = ''
         SET @cFieldAttr14 = ''
         SET @cFieldAttr15 = ''

		   -- GOTO Next Screen
		   SET @nScn = @nScn - 1
	      SET @nStep = @nStep - 1
      END

	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
      SELECT @cOutputSKU = WRO.SKU,
             @cOutputUOM = WRO.UOM,
             @cPackKey = WRO.PackKey,
             @nQtyRemaining = ISNULL( SUM ( WRO.Qty - WRO.QtyCompleted), 0)
      FROM dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK)
      WHERE WRO.WorkOrderKey IN 
         ( SELECT DISTINCT WorkOrderKey FROM dbo.WorkOrder_Uncasing WITH (NOLOCK) 
           WHERE JobKey = @cJobKey
           AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END)
      GROUP BY WRO.SKU, WRO.UOM, WRO.PackKey

      SELECT @nTtl_PalletizedQty = ISNULL( SUM( QTY), 0)
      FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
      WHERE JobKey = @cJobKey
      AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END
      AND   [Status] < '9'

      SET @cLottable04 = rdt.rdtFormatDate( @dLottable04)

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = ( @nQtyRemaining - @nTtl_PalletizedQty)
         SET @cOutField10 = '1:1' + SPACE( 10) + rdt.rdtRightAlign( CAST( @cMUOM_Desc AS NVARCHAR( 5)), 5)
      END
      ELSE
      BEGIN
         SET @nPQTY = ( @nQtyRemaining - @nTtl_PalletizedQty) / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY = ( @nQtyRemaining - @nTtl_PalletizedQty) % @nPUOM_Div -- Calc the remaining in master unit
         SET @cOutField10 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NVARCHAR( 5)) END + '    ' + 
                            rdt.rdtRightAlign( CAST( @cPUOM_Desc AS NVARCHAR( 5)), 5) + ' ' + rdt.rdtRightAlign( CAST( @cMUOM_Desc AS NVARCHAR( 5)), 5)
      END

		-- Prepare Next Screen Variable
      SET @cOutField01 = @cJobKey
      SET @cOutField02 = CASE WHEN @nMulti = 1 THEN 'MULTI' ELSE @cWorkOrderKey END
      SET @cOutField03 = @cToID
      SET @cOutField04 = @cLottable01
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = @cLottable04
      SET @cOutField08 = @cLottable07
      SET @cOutField09 = @cLottable08
      SET @cOutField11 = CASE WHEN @nPQTY = 0 THEN '' ELSE rdt.rdtRightAlign( CAST( @nPQTY AS NVARCHAR( 5)), 5) END -- PQTY
      SET @cOutField12 = rdt.rdtRightAlign( CAST( @nMQTY AS NVARCHAR( 5)), 5) -- MQTY
      SET @cOutField13 = ''
      SET @cOutField14 = RTRIM( CAST( @nRecCount AS NVARCHAR( 2))) + '/' + CAST( @nTtlCount AS NVARCHAR( 2))

      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''
         

      -- GOTO Previous Screen
		SET @nScn = @nScn - 1
	   SET @nStep = @nStep - 1
      
   END
	GOTO Quit

   STEP_3_FAIL:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = @cStartTime 
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO Quit      
   END
END 
GOTO QUIT

/********************************************************************************
Step 4. Scn = 4443. 
   PALLET ID   (Field01, input)
   END TIME    (Field04, display)      
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cID = @cOutField01
      SET @cLottable01  = @cInField02
      SET @cLottable02  = @cInField03
      SET @cLottable03  = @cInField04
      SET @cLottable04  = @cInField05
      SET @cLottable07  = @cInField06
      SET @cLottable08  = @cInField07
      SET @cEndTime  = @cOutField08

      -- Validate blank
      IF ISNULL( @cID, '') = ''
      BEGIN
         SET @nErrNo = 58767
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pallet ID req'
         GOTO Step_4_Fail
      END

   	IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
                      WHERE ID = @cID
                      AND   StorerKey = @cStorerKey
                      AND   [Status] = '3')
      BEGIN
         SET @nErrNo = 58768
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pallet not in progress'
         GOTO Step_4_Fail
      END

      IF EXISTS ( SELECT 1 FROM dbo.SKU SKU WITH (NOLOCK) 
                  JOIN dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK) ON SKU.SKU = WRO.SKU
                  WHERE SKU.StorerKey = @cStorerKey
                  AND   ISNULL( SKU.Lottable04Label, '') <> ''
                  AND   WorkOrderKey IN 
                      ( SELECT DISTINCT WorkOrderKey FROM dbo.WorkOrder_Uncasing WITH (NOLOCK) 
                        WHERE JobKey = @cJobKey
                        AND   WorkOrderKey = CASE WHEN @nMulti = 1 THEN WorkOrderKey ELSE @cWorkOrderKey END))
      BEGIN
         IF RDT.rdtIsValidDate( @cLottable04) = 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 58769, @cLangCode, 'DSP') --'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Step_4_Fail
         END
      END
      ELSE
         SET @cLottable04 = NULL

      IF rdt.rdtIsValidDate(@cLottable04) = 1 --valid date
         SET @dLottable04 = CAST( @cLottable04 AS DATETIME)

      SET @cVAPPalletizeCfmSP = rdt.RDTGetConfig( @nFunc, 'VAPPalletizeCfm_SP', @cStorerKey)
      IF @cVAPPalletizeCfmSP NOT IN ('0', '') AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cVAPPalletizeCfmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cVAPPalletizeCfmSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, ' + 
            ' @cStorerkey, @cToID, @cJobKey, @cWorkOrderKey, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nQtyToComplete, @cPrintLabel, @cEndPallet, @dStartDate, @cType, ' +
            ' @nErrNo	OUTPUT, @cErrMsg	OUTPUT '

         SET @cSQLParam =
            '@nMobile       	INT, ' + 
            '@nFunc         	INT, ' + 
            '@nStep         	INT, ' + 
            '@nInputKey     	INT, ' + 
            '@cLangCode     	NVARCHAR( 3),  ' +
            '@cStorerkey    	NVARCHAR( 15), ' + 
            '@cToID         	NVARCHAR( 18), ' +  
            '@cJobKey       	NVARCHAR( 10), ' + 
            '@cWorkOrderKey 	NVARCHAR( 10), ' + 
            '@cSKU          	NVARCHAR( 20), ' + 
            '@cLottable01   	NVARCHAR( 18), ' + 
            '@cLottable02   	NVARCHAR( 18), ' + 
            '@cLottable03   	NVARCHAR( 18), ' + 
            '@dLottable04   	DATETIME, '      + 
            '@dLottable05   	DATETIME, '      + 
            '@cLottable06   	NVARCHAR( 30), ' +
            '@cLottable07   	NVARCHAR( 30), ' +
            '@cLottable08   	NVARCHAR( 30), ' +
            '@cLottable09   	NVARCHAR( 30), ' +
            '@cLottable10   	NVARCHAR( 30), ' +
            '@cLottable11   	NVARCHAR( 30), ' +
            '@cLottable12   	NVARCHAR( 30), ' +
            '@dLottable13   	DATETIME, '      + 
            '@dLottable14   	DATETIME, '      + 
            '@dLottable15   	DATETIME, '      + 
            '@nQtyToComplete	INT, '           +    
            '@cPrintLabel   	NVARCHAR( 10), ' +  
            '@cEndPallet    	NVARCHAR( 10), ' +  
            '@dStartDate    	DATETIME, '      +  
            '@cType         	NVARCHAR( 1), '  + 
            '@nErrNo        	INT      		OUTPUT, ' + 
            '@cErrMsg       	NVARCHAR( 20)  OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, 
               @cStorerkey, @cToID, @cJobKey, @cWorkOrderKey, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQtyToComplete, @cPrintLabel, @cEndPallet, @dStartDate, 'E',
               @nErrNo	OUTPUT, @cErrMsg	OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
            GOTO Step_4_Fail
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 0
         EXEC rdt.rdt_VAP_Palletize_Confirm 
            @nMobile       = @nMobile,
            @nFunc         = @nFunc,
            @nStep         = @nStep,
            @nInputKey     = @nInputKey,
            @cLangCode     = @cLangCode,
            @cStorerkey    = @cStorerkey,
            @cToID         = @cToID, 
            @cJobKey       = @cJobKey,
            @cWorkOrderKey = @cWorkOrderKey,
            @cSKU          = @cSKU,
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = NULL,
            @cLottable06   = '',
            @cLottable07   = @cLottable07,
            @cLottable08   = @cLottable08,
            @cLottable09   = '',
            @cLottable10   = '',
            @cLottable11   = '',
            @cLottable12   = '',
            @dLottable13   = NULL,
            @dLottable14   = NULL,
            @dLottable15   = NULL,
            @nQtyToComplete= @nQtyToComplete,   
            @cPrintLabel   = @cPrintLabel, 
            @cEndPallet    = @cEndPallet, 
            @dStartDate    = NULL, 
            @cType         = 'E',
            @nErrNo        = @nErrNo      OUTPUT, 
            @cErrMsg       = @cErrMsg     OUTPUT  

         IF @nErrNo <> 0
            GOTO Step_4_Fail
      END

		SET @cOutField01 = @cID
     
		EXEC rdt.rdtSetFocusField @nMobile, 1
		
		SET @nScn = @nScn + 1
	   SET @nStep = @nStep + 1

	END  -- Inputkey = 1

	IF @nInputKey = 0 
   BEGIN
		SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = CONVERT(NVARCHAR, GETDATE(), 101) + ' ' + 
		                   CONVERT(NVARCHAR, DATEPART(hh, GETDATE())) + ':' + 
		                   RIGHT('0' + CONVERT(NVARCHAR, DATEPART(mi, GETDATE())), 2) 
      
		EXEC rdt.rdtSetFocusField @nMobile, 1

		SET @nScn = @nScn - 3
	   SET @nStep = @nStep - 3
   END
	GOTO Quit

   STEP_4_FAIL:
   --BEGIN
   --   SET @cOutField01 = @cToID
   --   SET @cOutField02 = @cEndTime
   --END
END 
GOTO QUIT

/********************************************************************************
Step 5. Scn = 4434. 
   MESSAGE
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cStartTime = CONVERT(NVARCHAR, GETDATE(), 101) + ' ' + 
		                  CONVERT(NVARCHAR, DATEPART(hh, GETDATE())) + ':' + 
		                  RIGHT('0' + CONVERT(NVARCHAR, DATEPART(mi, GETDATE())), 2) 

		SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = @cStartTime
     
		EXEC rdt.rdtSetFocusField @nMobile, 1
		
		SET @nScn = @nScn - 4
	   SET @nStep = @nStep - 4
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

      StorerKey = @cStorerKey,
      Facility  = @cFacility, 
      Printer   = @cPrinter, 
      -- UserName  = @cUserName,
		InputKey  =	@nInputKey,
		Printer_Paper   = @cPrinter_Paper,
      
      V_UOM    = @cPUOM,
   		
      V_SKU           = @cSKU,
      V_ID            = @cToID,
      
      V_String1      = @cStartDate,
      V_String2      = @cEndTime,
      V_String3      = @cWorkStation, 
      
      V_String4      = @cWorkOrderKey,
           
      V_String8      = @cPackKey,

      V_String9      = @cOutputUOM,
      V_String10     = @cJobKey,
      V_String11     = @cStartTime,
      V_String12     = @cEndTime,
      V_String13     = @cMUOM_Desc,
      V_String14     = @cPUOM_Desc,     
      V_String16     = @cLottableCode, 
      V_String19     = @cWorkOrderUdf01, 
      V_String20     = @cWorkOrderUdf04,
      
      V_Integer1     = @nTtlCount,
      V_Integer2     = @nQtyRemaining,
      V_Integer3     = @nRecCount, 
      V_Integer4     = @nMulti,

      V_PQTY         = @nPQTY,
      V_MQTY         = @nMQTY,
      V_PUOM_Div     = @nPUOM_Div,
      V_FromScn      = @nFromScn,
      
      V_Lottable01   = @cLottable01, 
      V_Lottable02   = @cLottable02, 
      V_Lottable03   = @cLottable03, 
      V_Lottable04   = @dLottable04, 
      V_Lottable05   = @dLottable05, 
      V_Lottable06   = @cLottable06, 
      V_Lottable07   = @cLottable07, 
      V_Lottable08   = @cLottable08, 
      V_Lottable09   = @cLottable09, 
      V_Lottable10   = @cLottable10, 
      V_Lottable11   = @cLottable11, 
      V_Lottable12   = @cLottable12, 
      V_Lottable13   = @dLottable13, 
      V_Lottable14   = @dLottable14, 
      V_Lottable15   = @dLottable15, 

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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_VAP_StartProduction                               */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: WorkOrder Start Line                                             */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2016-05-12 1.0  James    SOS369251 - Created                              */
/* 2016-09-30 1.1  Ung      Performance tuning                               */  
/* 2018-10-17 1.2  Tung GH  Performance                                      */
/* 2021-05-13 1.3  James    WMS-16844 Add IQC workflow (james01)             */
/* 2021-07-28 1.4  James    Fix bug, wrong variable used (james02)           */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_VAP_StartProduction](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
-- Misc variable
DECLARE
   @b_success           INT

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nMenu               INT,
   @nInputKey           NVARCHAR( 3),
   @cPrinter            NVARCHAR( 10),
   @cUserName           NVARCHAR( 18),

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),

   @cWorkStation        NVARCHAR( 50),
   @cJobKey             NVARCHAR( 10),
   @cWorkOrderKey       NVARCHAR( 10),
   @cWorkStationStatus  NVARCHAR( 10),
   @cStatus             NVARCHAR( 10),
   @cReasonCode         NVARCHAR( 10),
   @cSubReasonCode      NVARCHAR( 10),
   @cNoOfUser           NVARCHAR( 5),
   @dStartDownTime      DATETIME, 
   @dEndDownTime        DATETIME, 
   @nAssignedUser       INT, 
   @cSQL                NVARCHAR( 1000), 
   @cSQLParam           NVARCHAR( 1000), 
   @cStorerGroup        NVARCHAR( 20),
   @cOption             NVARCHAR( 1),
   @nTranCount          INT,
   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),
   @cErrMsg5            NVARCHAR( 20),
   @cCustomerRefNo      NVARCHAR( 10),
   @cJobStatus          NVARCHAR( 10),
   @cSKU                NVARCHAR( 20),
   @cSKUDescr           NVARCHAR( 60),
   @cPackKey            NVARCHAR( 10),
   @cUOM                NVARCHAR( 10),
   @cPrefUOM            NVARCHAR( 1), 
   @cPUOM_Desc          NVARCHAR( 5),  
   @cMUOM_Desc          NVARCHAR( 5),  
   @nPUOM_Div           INT,           
   @cPQTY               NVARCHAR( 5),  
   @cMQTY               NVARCHAR( 5),  
   @cExp_PQTY           NVARCHAR( 5),  
   @cExp_MQTY           NVARCHAR( 5),     
   @cWorkOrderType      NVARCHAR( 10),
   @cRefNo              NVARCHAR( 10),
   
   @nActQTY             INT,           
   @nPQTY               INT,           
   @nMQTY               INT,
   @nExp_PQTY           INT,           
   @nExp_MQTY           INT,   
   @nQty                INT,
   @nExp_Qty            INT,
   @nNoOfUser           INT,
   @nExpQty             INT,
   @nQtyCompleted       INT,
   @nCmpQTY             INT,
   @nCmpPQTY            INT,
   @nCmpMQTY            INT,

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

   @cStorerGroup     = StorerGroup, 
   @cFacility        = Facility,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @cStorerKey       = V_StorerKey,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr, 
   @cUOM             = V_UOM,
   
   @nQTY             = V_QTY,
   @nPUOM_Div        = V_PUOM_Div,
         
   @cWorkStation     = V_String1,
   @cJobKey          = V_String2,
   @cWorkOrderKey    = V_String3,
   @cCustomerRefNo   = V_String4,
   @cPackKey         = V_String5, 
   @cPrefUOM         = V_String6, 
   @cMUOM_Desc       = V_String7, 
   @cPUOM_Desc       = V_String8, 
   @cWorkOrderType   = V_String9,
   @cOption          = V_String10,
    
   @nNoOfUser        = V_Integer1,
   
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

FROM   RDT.RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1156
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1150
   IF @nStep = 1 GOTO Step_1   -- Scn = 4360 WorkStation
   IF @nStep = 2 GOTO Step_2   -- Scn = 4361 WorkStation, #ofuser, reason, subreason...
   IF @nStep = 3 GOTO Step_3   -- Scn = 4362 WorkStation, #ofuser, reason, subreason...
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1150)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 4660
   SET @nStep = 1

   SELECT @cPrefUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
   JOIN RDT.rdtUser U WITH (NOLOCK) ON ( M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile
   
   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- initialise all variable
   SET @cWorkStation = ''
   SET @cJobKey = ''
   SET @cWorkOrderKey = ''
   SET @cOption = ''
   SET @cReasonCode = ''
   SET @cNoOfUser = ''

   -- Prep next screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''

   EXEC rdt.rdtSetFocusField @nMobile, 1

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
END
GOTO Quit

/********************************************************************************
Step 1. screen = 4660
   WorkStation    (Field01, input)
   Job ID         (Field02, input)
   WorkOrder #    (Field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWorkStation = @cInField01
      SET @cJobKey = @cInField02
      SET @cWorkOrderKey = @cInField03

      --Check blank
      IF ISNULL( @cWorkStation, '') = ''
      BEGIN
         SET @nErrNo = 100551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WrkStation req
         GOTO Step_1a_Fail
      END

      --Check Exists
      IF NOT EXISTS (SELECT 1 
                     FROM dbo.WorkStation WITH (NOLOCK) 
                     WHERE WorkStation = @cWorkStation)
      BEGIN
         SET @nErrNo = 100552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv WrkStation
         GOTO Step_1a_Fail
      END

      IF ISNULL( @cJobKey, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE JobKey = @cJobKey)
         BEGIN
            SET @nErrNo = 100553
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Job ID
            GOTO Step_1b_Fail
         END
      END
      
      IF ISNULL( @cWorkOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 100554
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WORKORDER# req
         GOTO Step_1c_Fail
      END

      --SELECT @cRefNo = Refno 
      --FROM dbo.InventoryQC WITH (NOLOCK) 
      --WHERE StorerKey = @cStorerKey
      --AND   QC_Key = @cWorkOrderKey
      --AND   FinalizeFlag <> 'Y'

      SET @cRefNo = @cWorkOrderKey
      
      If LEFT( @cRefNo, 1) = 'Q' 
         SET @cWorkOrderType = 'IQC'
      ELSE
         SET @cWorkOrderType = 'KIT'
      
      IF @cWorkOrderType = 'KIT'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.Kit WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerKey
                         AND   KITKey = @cWorkOrderKey
                         AND   [Status] < '9')
         BEGIN
            SET @nErrNo = 100555
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv WORKORDER#
            GOTO Step_1c_Fail
         END

         SELECT @nExpQty = ExpectedQty
         FROM dbo.KITDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   KITKey = @cWorkOrderKey
         AND   [Type] = 'T'

         SELECT @cCustomerRefNo = CustomerRefNo
         FROM dbo.Kit WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   KITKey = @cWorkOrderKey
         AND   [Status] < '9'

         SELECT @cSKU = SKU,
                @nExpQty = ExpectedQty
         FROM dbo.KITDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   KITKey = @cWorkOrderKey
         AND   [Status] < '9'
         AND   [Type] = 'T'
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.InventoryQC WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerKey
                         AND   Refno = @cWorkOrderKey
                         AND   FinalizeFlag = 'Y')
         BEGIN
            SET @nErrNo = 100577
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv WORKORDER#
            GOTO Step_1c_Fail
         END

         SELECT @cCustomerRefNo = QC_Key
         FROM dbo.InventoryQC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   Refno = @cWorkOrderKey
         AND   FinalizeFlag = 'Y'

         SELECT @nExpQty = ISNULL( SUM( Qty), 0)
         FROM dbo.InventoryQCDetail QCD WITH (NOLOCK)
         JOIN dbo.InventoryQC QC WITH (NOLOCK) ON ( QCD.QC_Key = QC.QC_Key)
         WHERE QC.StorerKey = @cStorerKey
         AND   QC.Refno = @cWorkOrderKey
         AND   QC.FinalizeFlag = 'Y'

         SELECT TOP 1 @cSKU = SKU
         FROM dbo.InventoryQCDetail QCD WITH (NOLOCK)
         JOIN dbo.InventoryQC QC WITH (NOLOCK) ON ( QCD.QC_Key = QC.QC_Key)
         WHERE QC.StorerKey = @cStorerKey
         AND   QC.Refno = @cWorkOrderKey
         AND   QC.FinalizeFlag = 'Y'
         ORDER BY 1
      END

      SELECT @nQtyCompleted = ISNULL( SUM( QtyCompleted), 0) 
      FROM dbo.WorkOrderJob WOJ WITH (NOLOCK) 
      JOIN dbo.WorkStation WS WITH (NOLOCK) ON 
         ( WOJ.WorkStation = WS.WorkStation AND WorkMethod <> 'PRE')
      WHERE WOJ.WorkOrderKey = @cWorkOrderKey
         
      IF @nExpQty <= @nQtyCompleted
      BEGIN
         SET @nErrNo = 100575
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Wrk completed'
         GOTO Quit
      END

      SET @nExpQty = @nExpQty - @nQtyCompleted

      SELECT @cSKUDescr = Descr,
             @cPackKey = PackKey
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      -- Get Pack info
      SELECT
         @cMUOM_Desc = Pack.PackUOM3,
         @cPUOM_Desc =
            CASE @cPrefUOM
               WHEN '2' THEN Pack.PackUOM1 -- Case
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack
               WHEN '6' THEN Pack.PackUOM3 -- Master unit
               WHEN '1' THEN Pack.PackUOM4 -- Pallet
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
            END,
            @nPUOM_Div = CAST( IsNULL(
            CASE @cPrefUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cSKU

      --prepare next screen variable
      SET @cOutField01 = @cWorkStation
      SET @cOutField02 = CASE WHEN @cWorkOrderType = 'IQC' THEN @cWorkOrderKey ELSE @cCustomerRefNo END
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)

      -- Convert to prefer UOM QTY
      IF @cPrefUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
      END

      IF @cPUOM_Desc = ''
      BEGIN
         SET @nMQTY = @nExpQty
         SET @cOutField06 = '1:1'   -- @nPUOM_Div
         SET @cOutField07 = ''      -- @cPUOM_Desc
         SET @cOutField09 = ''      -- @nPQTY
         SET @cFieldAttr09 = 'O'
      END
      ELSE
      BEGIN
         SET @nPQTY = @nExpQty / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY = @nExpQty % @nPUOM_Div -- Calc the remaining in master unit
      
         SET @cOutField06 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 5))
         SET @cOutField07 = @cPUOM_Desc
         SET @cOutField09 = @nPQTY
      END
      SET @cOutField08 = @cMUOM_Desc   -- @cMUOM_Desc
      SET @cOutField10 = @nMQTY        -- @nMQTY
      SET @cOutField11 = ''            -- Status

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''

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

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   Step_1a_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = @cJobKey
      SET @cOutField03 = @cWorkOrderKey
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO Quit
   END

   Step_1b_Fail:
   BEGIN
      SET @cOutField01 = @cWorkStation
      SET @cOutField02 = ''
      SET @cOutField03 = @cWorkOrderKey
      EXEC rdt.rdtSetFocusField @nMobile, 2
      GOTO Quit
   END

   Step_1c_Fail:
   BEGIN
      SET @cOutField01 = @cWorkStation
      SET @cOutField02 = @cJobKey
      SET @cOutField03 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 3
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 2. (screen = 4661)
   WorkStation       (Field01)
   Customer Ref#     (Field02)
   SKU               (Field03)
   Qty               (Field04)
   Change Status     (Field05, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField11

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 100556
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option req'
         GOTO Step_2_Fail
      END

      IF @cOption NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 100557
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_2_Fail
      END

      SET @cJobStatus = ''
      SELECT @cJobStatus = JobStatus
      FROM dbo.WorkOrderJob WITH (NOLOCK) 
      WHERE WorkStation = @cWorkStation
      AND   WorkOrderKey = @cWorkOrderKey

      -- job complete. cannot proceed no matter what is the status
      IF @cJobStatus = '9'
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 100567, @cLangCode, 'DSP'), 7, 14) --WORKORDER
         SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 100568, @cLangCode, 'DSP'), 7, 14) --COMPLETED

         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END

         GOTO Step_2_Fail         
      END

      -- if job not started then cannot proceed with end or pause
      IF @cOption IN ( '2', '3') 
      BEGIN
         IF @cJobStatus = '' 
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 100569, @cLangCode, 'DSP'), 7, 14) --WORKORDER
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 100570, @cLangCode, 'DSP'), 7, 14) --NOT ACTIVE

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END

            GOTO Step_2_Fail
         END

         -- Job is paused at the moment
         IF @cJobStatus = '5'
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 100573, @cLangCode, 'DSP'), 7, 14) --WORKORDER
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 100574, @cLangCode, 'DSP'), 7, 14) --IS PAUSED

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END

            GOTO Step_2_Fail
         END   -- Jobstatus = '5'
      END

      IF ISNULL( @cJobKey, '') = ''
         SELECT TOP 1 
            @cJobKey = JobKey, 
            @nNoOfUser = NoOfAssignedWorker
         FROM dbo.WORKORDERJOB WITH (NOLOCK) 
         WHERE WorkStation = @cWorkStation
         AND   WorkOrderKey = @cWorkOrderKey
         AND   JobStatus < '9'

      IF @cWorkOrderType = 'KIT'
         SELECT @nExpQty = ExpectedQty
         FROM dbo.KITDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   KITKey = @cWorkOrderKey
         AND   [Status] < '9'
         AND   [Type] = 'T'
      ELSE
         SELECT @nExpQty = ISNULL( SUM( Qty), 0)
         FROM dbo.InventoryQCDetail QCD WITH (NOLOCK)
         JOIN dbo.InventoryQC QC WITH (NOLOCK) ON ( QCD.QC_Key = QC.QC_Key)
         WHERE QC.StorerKey = @cStorerKey
         AND   QC.Refno = @cWorkOrderKey
         AND   QC.FinalizeFlag = 'Y'
               
      IF @cOption = '1' -- Set something to active
      BEGIN
         -- Job not exists, create new 1 
         IF ISNULL( @cJobStatus, '') = '' 
         BEGIN
            -- Reset the disabled field         
            SET @cFieldAttr08 = ''
            SET @cFieldAttr09 = ''

            -- Job not exists, create new 1 
            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = CASE WHEN @cWorkOrderType = 'IQC' THEN @cWorkOrderKey ELSE @cCustomerRefNo END

            -- Convert to prefer UOM QTY
            IF @cPrefUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
            END

            IF @cPUOM_Desc = ''
            BEGIN
               SET @nMQTY = @nExpQty
               SET @cOutField03 = '1:1'   -- @nPUOM_Div
               SET @cOutField04 = ''      -- @cPUOM_Desc
               SET @cOutField06 = ''      -- @nPQTY               
               SET @cOutField08 = ''      -- @nPQTY
               SET @cFieldAttr08 = 'O'
            END
            ELSE
            BEGIN
               SET @nPQTY = @nExpQty / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY = @nExpQty % @nPUOM_Div -- Calc the remaining in master unit

               SET @cOutField03 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 5))
               SET @cOutField04 = @cPUOM_Desc
               SET @cOutField06 = @nPQTY
               SET @cOutField08 = ''      -- @nPQTY
            END
            SET @cOutField05 = @cMUOM_Desc   -- @cMUOM_Desc
            SET @cOutField07 = @nMQTY        -- @nMQTY
            SET @cOutField09 = ''            -- @nMQTY

            SET @cOutField10 = ''
            SET @cOutField11 = ''            -- Reason

            SET @cFieldAttr08 = 'O'               
            SET @cFieldAttr09 = 'O'               
            SET @cFieldAttr11 = 'O'               
            
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Quit
         END      -- JobStatus = ''

         -- Job exists, check job status
         IF @cJobStatus = '1'
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 100558, @cLangCode, 'DSP'), 7, 14) --WORKORDER
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 100559, @cLangCode, 'DSP'), 7, 14) --ALREADY ACTIVE

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END

            GOTO Step_2_Fail
         END      -- Jobstatus = '1'

         -- Job exists and was paused at the moment
         IF ISNULL( @cJobStatus, '') = '5'
         BEGIN
            -- Reset the disabled field         
            SET @cFieldAttr08 = ''
            SET @cFieldAttr09 = ''

            -- Job not exists, create new 1 
            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = CASE WHEN @cWorkOrderType = 'IQC' THEN @cWorkOrderKey ELSE @cCustomerRefNo END

            SELECT @nCmpQty = ISNULL( SUM( QtyCompleted), 0)
            FROM dbo.WorkOrderJob WITH (NOLOCK) 
            WHERE WorkStation = @cWorkStation
            AND   WorkOrderKey = @cWorkOrderKey
            AND   JobKey = @cJobKey
            AND   JobStatus < '9'

            -- Convert to prefer UOM QTY
            IF @cPrefUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
            END

            IF @cPUOM_Desc = ''
            BEGIN
               SET @nMQTY = @nExpQty
               SET @nCmpMQTY = @nCmpQty
               SET @cOutField03 = '1:1'   -- @nPUOM_Div
               SET @cOutField04 = ''      -- @cPUOM_Desc
               SET @cOutField06 = ''      -- @nPQTY               
               SET @cOutField08 = ''      -- @nPQTY
               SET @cFieldAttr08 = 'O'
            END
            ELSE
            BEGIN
               SET @nPQTY = @nExpQty / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY = @nExpQty % @nPUOM_Div -- Calc the remaining in master unit
               SET @nCmpPQTY = @nCmpQty / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nCmpMQTY = @nCmpQty % @nPUOM_Div -- Calc the remaining in master unit

               SET @cOutField03 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 5))
               SET @cOutField04 = @cPUOM_Desc
               SET @cOutField06 = @nPQTY         -- @nPQTY
               
               SET @cOutField08 = @nCmpPQTY      -- @nPQTY
            END
            SET @cOutField05 = @cMUOM_Desc   -- @cMUOM_Desc
            SET @cOutField07 = @nMQTY        -- @nMQTY
            SET @cOutField09 = @nCmpMQTY        -- @nMQTY

            SET @cOutField10 = ''            -- # of user
            SET @cOutField11 = ''            -- Reason

            SET @cFieldAttr08 = 'O'               
            SET @cFieldAttr09 = 'O'               
            SET @cFieldAttr11 = 'O'               
            
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Quit
         END      -- JobStatus = ''
      END      -- @cOption = 1

      IF @cOption = '2'      
      BEGIN
         -- Job started and ready to pause/end
         IF @cJobStatus = '1'
         BEGIN
            -- Reset the disabled field
            SET @cFieldAttr08 = ''
            SET @cFieldAttr09 = ''

            SELECT @nQTY = SUM( QtyRemaining)
            FROM dbo.WORKORDERJOB WITH (NOLOCK) 
            WHERE WorkStation = @cWorkStation
            AND   JobKey = @cJobKey
            AND   WorkOrderKey = @cWorkOrderKey
            AND   JobStatus < '9'
               
            -- Job not exists, create new 1 
            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = CASE WHEN @cWorkOrderType = 'IQC' THEN @cWorkOrderKey ELSE @cCustomerRefNo END

            -- Convert to prefer UOM QTY
            IF @cPrefUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
            END

            IF @cPUOM_Desc = ''
            BEGIN
               SET @nMQTY = @nQTY
               SET @cOutField03 = '1:1'   -- @nPUOM_Div
               SET @cOutField04 = ''      -- @cPUOM_Desc
               SET @cOutField06 = ''      -- @nPQTY               
               SET @cOutField08 = ''      -- @nPQTY
               SET @cFieldAttr08 = 'O'
            END
            ELSE
            BEGIN
               SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit

               SET @cOutField03 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 5))
               SET @cOutField04 = @cPUOM_Desc
               SET @cOutField06 = @nPQTY
               SET @cOutField08 = ''      -- @nPQTY
            END
            SET @cOutField05 = @cMUOM_Desc   -- @cMUOM_Desc
            SET @cOutField07 = @nMQTY        -- @nMQTY
            SET @cOutField09 = ''            -- @nMQTY

            SET @cOutField10 = @nNoOfUser
            SET @cOutField11 = ''            -- Reason
            
            SET @cFieldAttr10 = 'O'               
            SET @cFieldAttr11 = 'O'               
            
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Quit
         END   -- Jobstatus = '1'
      END      -- @cOption = 2
      
      IF @cOption = '3'
      BEGIN
         IF @cJobStatus = '1' 
         BEGIN
            -- Reset the disabled field         
            SET @cFieldAttr08 = ''
            SET @cFieldAttr09 = ''

            -- Job not exists, create new 1 
            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = CASE WHEN @cWorkOrderType = 'IQC' THEN @cWorkOrderKey ELSE @cCustomerRefNo END

            SELECT @nCmpQty = ISNULL( SUM( QtyCompleted), 0)
            FROM dbo.WorkOrderJob WITH (NOLOCK) 
            WHERE WorkStation = @cWorkStation
            AND   WorkOrderKey = @cWorkOrderKey
            AND   JobKey = @cJobKey
            AND   JobStatus < '9'

            SET @nExpQty = @nExpQty - @nCmpQty

            -- Convert to prefer UOM QTY
            IF @cPrefUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
            END

            IF @cPUOM_Desc = ''
            BEGIN
               SET @nMQTY = @nExpQty
               SET @nCmpMQTY = @nCmpQty
               SET @cOutField03 = '1:1'   -- @nPUOM_Div
               SET @cOutField04 = ''      -- @cPUOM_Desc
               SET @cOutField06 = ''      -- @nPQTY               
               SET @cOutField08 = ''      -- @nPQTY
               SET @cFieldAttr08 = 'O'
            END
            ELSE
            BEGIN
               SET @nPQTY = @nExpQty / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY = @nExpQty % @nPUOM_Div -- Calc the remaining in master unit
               SET @nCmpPQTY = @nCmpQty / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nCmpMQTY = @nCmpQty % @nPUOM_Div -- Calc the remaining in master unit

               SET @cOutField03 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 5))
               SET @cOutField04 = @cPUOM_Desc
               SET @cOutField06 = @nPQTY         -- @nPQTY
               
               SET @cOutField08 = @nCmpPQTY      -- @nPQTY
            END
            SET @cOutField05 = @cMUOM_Desc   -- @cMUOM_Desc
            SET @cOutField07 = @nMQTY        -- @nMQTY
            SET @cOutField09 = @nCmpMQTY     -- @nMQTY

            SET @cOutField10 = ''            -- # of user

--            SET @cFieldAttr08 = 'O'               
--            SET @cFieldAttr09 = 'O'               
            SET @cFieldAttr10 = 'O'
            
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Quit
         END   -- Jobstatus = ''      
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare prev screen variable
      SET @cWorkStation = ''
      SET @cJobKey = ''
      SET @cWorkOrderKey = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

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
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOption = ''

      -- Reset this screen var
      SET @cOutField11 = ''
  END
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 4362)
   WorkStation       (Field01)
   Customer Ref#     (Field02)
   Exp Qty           (Field03)
   Cmp Qty           (Field04, input)
   # of User         (Field05, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cNoOfUser = @cInField10
      SET @cReasonCode = @cInField11

      IF @cOption = '3'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.TaskmanagerReason WITH (NOLOCK) 
                         WHERE TaskManagerReasonKey = @cReasonCode) OR 
         ISNULL( @cReasonCode, '') = ''
         BEGIN
            SET @nErrNo = 100576
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv reason'
            SET @cReasonCode = ''
            EXEC rdt.rdtSetFocusField @nMobile, 11 -- Reason
            GOTO Quit
         END
                         
      END

      IF @cOption = '1'
      BEGIN
         IF ISNULL(@cNoOfUser, '') = '' SET @cNoOfUser = '0' -- Blank taken as zero      
         
         -- Validate # of user
         IF RDT.rdtIsValidQTY( @cNoOfUser, 1) = 0
         BEGIN
            SET @nErrNo = 100562
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv no of user'
            SET @cNoOfUser = ''
            EXEC rdt.rdtSetFocusField @nMobile, 10 -- # of user
            GOTO Quit
         END
         ELSE
            SET @nNoOfUser = CAST( @cNoOfUser AS INT)

         IF ISNULL( @cJobKey, '') = ''
            SELECT TOP 1 @cJobKey = JobKey
            FROM dbo.WORKORDERJOB WITH (NOLOCK) 
            WHERE WorkStation = @cWorkStation
            AND   WorkOrderKey = @cWorkOrderKey
            AND   JobStatus < '9'

         SELECT @cJobStatus = JobStatus
         FROM dbo.WorkOrderJob WITH (NOLOCK) 
         WHERE WorkStation = @cWorkStation
         AND   WorkOrderKey = @cWorkOrderKey
         AND   JobKey = @cJobKey
         AND   JobStatus < '9'

         IF @cJobStatus = '5' AND @cFieldAttr10 = ''
            SET @nExp_QTY = 0
         ELSE
         BEGIN
            -- Validate exp qty
            IF ISNULL(@cPUOM_Desc, '') <> ''
            BEGIN
               SET @cExp_PQTY = IsNULL( @cOutField06, '')
            END

            SET @cExp_MQTY = IsNULL( @cOutField07, '')

            IF ISNULL(@cExp_PQTY, '') = '' SET @cExp_PQTY = '0' -- Blank taken as zero
            IF ISNULL(@cExp_MQTY, '') = '' SET @cExp_MQTY = '0' -- Blank taken as zero

            -- Calc total QTY in master UOM
            SET @nExp_PQTY = CAST( @cExp_PQTY AS INT)
            SET @nExp_MQTY = CAST( @cExp_MQTY AS INT)
            SET @nExp_QTY = 0

            SET @nExp_QTY = ISNULL(rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nExp_PQTY, @cPrefUOM, 6), 0) -- Convert to QTY in master UOM
            SET @nExp_QTY = @nExp_QTY + @nExp_MQTY
         END

         -- Activate the job
         SET @nErrNo = 0
         EXEC rdt.rdt_VAP_StartProduction 
            @nMobile          = @nMobile,
            @nFunc            = @nFunc,
            @nStep            = @nStep,
            @nInputKey        = @nInputKey,
            @cLangCode        = @cLangCode,
            @cStorerkey       = @cStorerkey,
            @cWorkStation     = @cWorkStation,
            @cJobKey          = @cJobKey,
            @cWorkOrderKey    = @cWorkOrderKey,
            @cSKU             = @cSKU,
            @nQty             = @nExp_Qty,
            @nNoOfUser        = @nNoOfUser,
            @cOption          = @cOption,
            @cReasonCode      = @cReasonCode,
            @cWorkOrderType   = @cWorkOrderType,
            @nErrNo           = @nErrNo      OUTPUT, 
            @cErrMsg          = @cErrMsg     OUTPUT  

         IF @nErrNo <> 0
            GOTO Step_2_Fail         
      END
      ELSE
      BEGIN
         IF ISNULL(@cPUOM_Desc, '') <> ''
         BEGIN
            SET @cPQTY = IsNULL( @cInField08, '')
         END

         SET @cMQTY = IsNULL( @cInField09, '')

         IF ISNULL(@cPQTY, '') = '' SET @cPQTY = '0' -- Blank taken as zero
         IF ISNULL(@cMQTY, '') = '' SET @cMQTY = '0' -- Blank taken as zero

         -- Validate PQTY
         IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
         BEGIN
            SET @nErrNo = 100563
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 08 -- PQTY
            GOTO Quit
         END

         -- Validate MQTY
         IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
         BEGIN
            SET @nErrNo = 100564
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 09 -- MQTY
            GOTO Quit
         END

         -- Calc total QTY in master UOM
         SET @nPQTY = CAST( @cPQTY AS INT)
         SET @nMQTY = CAST( @cMQTY AS INT)
         SET @nQTY = 0

         SET @nQTY = ISNULL(rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nPQTY, @cPrefUOM, 6), 0) -- Convert to QTY in master UOM
         SET @nQTY = @nQTY + @nMQTY

         IF @nQTY <= 0 AND 
         NOT EXISTS ( SELECT 1 FROM dbo.WorkStation WITH (NOLOCK)
                      WHERE WorkStation = @cWorkStation
                      AND   WorkMethod = 'PRE')
         BEGIN
            SET @nErrNo = 100565
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid qty'
            EXEC rdt.rdtSetFocusField @nMobile, 08 -- PQTY
            GOTO Quit
         END

         SELECT @nExpQty = ExpectedQty
         FROM dbo.KITDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   KITKey = @cWorkOrderKey
         AND   [Status] < '9'
         AND   [Type] = 'T'

         SELECT @nQtyCompleted = ISNULL( SUM( QtyCompleted), 0) 
         FROM dbo.WorkOrderJob WOJ WITH (NOLOCK) 
         JOIN dbo.WorkStation WS WITH (NOLOCK) ON 
            ( WOJ.WorkStation = WS.WorkStation AND WorkMethod <> 'PRE')
         WHERE WOJ.WorkOrderKey = @cWorkOrderKey

         IF @nExpQty < ( @nQTY + @nQtyCompleted)
         BEGIN
            SET @nErrNo = 100566
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Qty > exp qty'
            EXEC rdt.rdtSetFocusField @nMobile, 08 -- PQTY
            GOTO Quit
         END

         -- Activate the job
         SET @nErrNo = 0
         EXEC rdt.rdt_VAP_StartProduction 
            @nMobile          = @nMobile,
            @nFunc            = @nFunc,
            @nStep            = @nStep,
            @nInputKey        = @nInputKey,
            @cLangCode        = @cLangCode,
            @cStorerkey       = @cStorerkey,
            @cWorkStation     = @cWorkStation,
            @cJobKey          = @cJobKey,
            @cWorkOrderKey    = @cWorkOrderKey,
            @cSKU             = @cSKU,
            @nQty             = @nQty,
            @nNoOfUser        = @nNoOfUser,
            @cOption          = @cOption,
            @cReasonCode      = @cReasonCode,
            @cWorkOrderType   = @cWorkOrderType,
            @nErrNo           = @nErrNo      OUTPUT, 
            @cErrMsg          = @cErrMsg     OUTPUT  

         IF @nErrNo <> 0
            GOTO Step_2_Fail         
      END
      
      -- initialise all variable
      SET @cWorkStation = ''
      SET @cJobKey = ''
      SET @cWorkOrderKey = ''

      -- Prep next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1

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

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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

      SELECT @cSKU = SKU,
             @nQty = ExpectedQty
      FROM dbo.KITDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   KITKey = @cWorkOrderKey
      AND   [Status] < '9'
      AND   [Type] = 'T'

      SELECT @cSKUDescr = Descr,
             @cPackKey = PackKey
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      -- Get Pack info
      SELECT
         @cMUOM_Desc = Pack.PackUOM3,
         @cPUOM_Desc =
            CASE @cPrefUOM
               WHEN '2' THEN Pack.PackUOM1 -- Case
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack
               WHEN '6' THEN Pack.PackUOM3 -- Master unit
               WHEN '1' THEN Pack.PackUOM4 -- Pallet
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
            END,
            @nPUOM_Div = CAST( IsNULL(
            CASE @cPrefUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cSKU

      --prepare next screen variable
      SET @cOutField01 = @cWorkStation
      SET @cOutField02 = CASE WHEN @cWorkOrderType = 'IQC' THEN @cWorkOrderKey ELSE @cCustomerRefNo END
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)

      -- Convert to prefer UOM QTY
      IF @cPrefUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
      END

      IF @cPUOM_Desc = ''
      BEGIN
         SET @nMQTY = @nQTY
         SET @cOutField06 = '1:1'   -- @nPUOM_Div
         SET @cOutField07 = ''      -- @cPUOM_Desc
         SET @cOutField09 = ''      -- @nPQTY
         SET @cFieldAttr09 = 'O'
      END
      ELSE
      BEGIN
         SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit

         SET @cOutField06 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 5))
         SET @cOutField07 = @cPUOM_Desc
         SET @cOutField09 = @nPQTY
      END
      SET @cOutField08 = @cMUOM_Desc   -- @cMUOM_Desc
      SET @cOutField10 = @nMQTY        -- @nMQTY
      SET @cOutField11 = ''            -- Status

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
END
/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate      = GETDATE(), 
      ErrMsg        = @cErrMsg,
      Func          = @nFunc,
      Step          = @nStep,
      Scn           = @nScn,

      Facility      = @cFacility,
      Printer       = @cPrinter,
      -- UserName      = @cUserName,

      V_StorerKey   = @cStorerKey, 
      V_SKU         = @cSKU,
      V_SKUDescr    = @cSKUDescr, 
      V_UOM         = @cUOM,
      
      V_QTY         = @nQTY,
      V_PUOM_Div    = @nPUOM_Div,
      
      V_String1     = @cWorkStation,
      V_String2     = @cJobKey,
      V_String3     = @cWorkOrderKey,
      V_String4     = @cCustomerRefNo, 
      V_String6     = @cPrefUOM,
      V_String5     = @cPackKey, 
      V_String7     = @cMUOM_Desc, 
      V_String8     = @cPUOM_Desc,  
      V_String9     = @cWorkOrderType,
      V_String10    = @cOption,
      
      V_Integer1    = @nNoOfUser,

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